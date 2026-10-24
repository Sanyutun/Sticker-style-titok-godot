class_name ExportManager
extends Node
## Orchestrates the deterministic export: PNG frame render → offline audio mix
## → FFmpeg H.264/AAC with two-pass loudness normalisation → ffprobe checks.

signal progress(phase: String, current: int, total: int, message: String)
signal log_message(text: String)
signal finished(report: Dictionary)

const FrameRenderer = preload("res://scripts/export/frame_renderer.gd")
const AudioMixer = preload("res://scripts/export/audio_mixer.gd")

var cancelled := false
var last_report: Dictionary = {}

func cancel() -> void:
	cancelled = true
	log_message.emit("Cancellation requested — finishing the current step.")

func export_project(project, engine, options: Dictionary = {}) -> Dictionary:
	cancelled = false
	var started := Time.get_unix_time_from_system()
	var report := {
		"schema_version": 1,
		"started_utc": Time.get_datetime_string_from_system(true),
		"project": str(project.episode.get("project_name", "")),
		"project_dir": project.project_dir,
		"options": options.duplicate(true),
		"checks": [],
		"logs": [],
		"ok": false,
	}
	last_report = report
	var validation: Dictionary = project.validate()
	report["validation"] = {"errors": validation.errors, "warnings": validation.warnings}
	if not validation.errors.is_empty():
		report["error"] = "Project validation failed: " + "; ".join(validation.errors)
		_finish(report)
		return report
	# Resolve settings -------------------------------------------------
	var ex: Dictionary = project.episode.get("export", {})
	var fps := maxi(1, int(project.episode.get("fps", 30)))
	var frame_count: int = engine.frame_count()
	var width := int(project.episode.get("width", 1920))
	var height := int(project.episode.get("height", 1080))
	var duration := float(project.episode.get("duration_seconds", 10.0))
	var video_path := _abs_path(str(options.get("video_path", ex.get("video_path", "output/video.mp4"))), project)
	var frames_dir := _abs_path(str(options.get("frames_dir", ex.get("frames_dir", "output/frames"))), project)
	var crf := int(options.get("crf", ex.get("crf", 18)))
	var preset := str(options.get("preset", ex.get("preset", "medium")))
	var audio_bitrate := int(options.get("audio_bitrate", ex.get("audio_bitrate_kbps", 192)))
	var include_audio := bool(options.get("include_audio", true))
	var include_subtitles := bool(options.get("include_subtitles", true))
	var clean_frames_after := bool(options.get("clean_frames", false))
	var ffmpeg := str(options.get("ffmpeg", "ffmpeg"))
	var ffprobe := str(options.get("ffprobe", "ffprobe"))
	var mix_path := video_path.get_base_dir().path_join("audio_mix.wav")
	var report_path := video_path.get_base_dir().path_join("export_report.json")
	report["settings"] = {
		"video_path": video_path, "frames_dir": frames_dir, "mix_path": mix_path,
		"report_path": report_path, "fps": fps, "frame_count": frame_count,
		"width": width, "height": height, "duration_seconds": duration,
		"crf": crf, "preset": preset, "audio_bitrate_kbps": audio_bitrate,
		"include_audio": include_audio, "include_subtitles": include_subtitles,
		"loudness_target_lufs": -14.0, "true_peak_target_dbtp": -1.5,
		"loudnorm_requested_tp": -1.5,
	}
	_mkdir(video_path.get_base_dir())
	_mkdir(frames_dir)
	_clean_frames(frames_dir)
	_log("Project: %s" % report["project"])
	_log("Output: %s" % video_path)
	_log("Frames: %d @ %d fps · %d×%d · %.3fs" % [frame_count, fps, width, height, duration])
	# Render -----------------------------------------------------------
	var renderer := FrameRenderer.new()
	renderer.name = "OfflineFrameRenderer"
	add_child(renderer)
	renderer.setup(project, engine, Vector2i(width, height), include_subtitles)
	await get_tree().process_frame
	await get_tree().process_frame
	var render_started := Time.get_ticks_msec()
	var failed_frame := -1
	for f in range(frame_count):
		if cancelled:
			break
		var t: float = engine.time_for_frame(f)
		var path := frames_dir.path_join("frame_%05d.png" % f)
		var ok: bool = await renderer.render_frame(t, path)
		if not ok:
			failed_frame = f
			break
		if f % 3 == 0 or f == frame_count - 1:
			progress.emit("render", f + 1, frame_count, "Rendering frame %d / %d" % [f + 1, frame_count])
	report["render"] = {
		"frames_requested": frame_count,
		"frames_rendered": (failed_frame if failed_frame >= 0 else frame_count) if not cancelled else 0,
		"seconds": (Time.get_ticks_msec() - render_started) / 1000.0,
		"failed_frame": failed_frame,
	}
	renderer.queue_free()
	if cancelled:
		report["cancelled"] = true
		report["error"] = "Cancelled during frame rendering."
		_finish(report)
		return report
	if failed_frame >= 0:
		report["error"] = "Frame %d failed to render." % failed_frame
		_finish(report)
		return report
	_log("Rendered %d frames in %.1fs" % [frame_count, report["render"]["seconds"]])
	# Audio ------------------------------------------------------------
	var audio_report := {}
	if include_audio:
		progress.emit("audio", 0, 1, "Mixing audio offline…")
		audio_report = AudioMixer.mix(project, mix_path, 48000)
		report["audio_mix"] = audio_report
		for w in audio_report.get("warnings", []):
			_log("Audio warning: " + str(w))
		if not bool(audio_report.get("ok", false)):
			for e in audio_report.get("errors", []):
				_log("Audio error: " + str(e))
			if FileAccess.file_exists(mix_path):
				include_audio = false
				_log("Continuing without audio because the mix failed.")
			else:
				report["error"] = "Audio mix failed."
				_finish(report)
				return report
		else:
			_log("Audio mix: %d tracks · peak %.1f dBFS · %.2fs" % [int(audio_report.get("tracks_mixed", 0)), float(audio_report.get("peak_dbfs", -99.0)), float(audio_report.get("duration_seconds", 0.0))])
	# Loudness first pass ---------------------------------------------
	var measured := {}
	if include_audio:
		progress.emit("measure", 0, 1, "Measuring loudness (pass 1)…")
		var m := _run([ffmpeg, "-hide_banner", "-nostats", "-i", mix_path, "-af", "loudnorm=I=-14.0:TP=-1.5:LRA=11.0:print_format=json", "-f", "null", "-"])
		measured = _extract_json(m.get("output", ""))
		if measured.is_empty():
			_log("Loudness measurement parse failed; using single-pass loudnorm.")
		else:
			_log("Loudness in: %s LUFS, %s dBTP, LRA %s" % [measured.get("input_i", "?"), measured.get("input_tp", "?"), measured.get("input_lra", "?")])
		report["loudness_pass1"] = measured
	# Encode -----------------------------------------------------------
	progress.emit("encode", 0, 1, "Encoding H.264 / AAC…")
	_log("Encoding H.264/AAC with FFmpeg…")
	var args := PackedStringArray([
		"-y", "-hide_banner", "-loglevel", "error", "-nostats",
		"-framerate", str(fps), "-start_number", "0",
		"-i", frames_dir.path_join("frame_%05d.png"),
	])
	if include_audio:
		args.append_array(["-i", mix_path])
	args.append_array(["-map", "0:v:0"])
	if include_audio:
		args.append_array(["-map", "1:a:0"])
	args.append_array([
		"-frames:v", str(frame_count),
		"-c:v", "libx264", "-preset", preset, "-crf", str(crf),
		"-pix_fmt", "yuv420p", "-profile:v", "high", "-level", "4.2",
	])
	if include_audio:
		var af := "loudnorm=I=-14.0:TP=-1.5:LRA=11.0"
		if not measured.is_empty():
			af += ":measured_I=%s:measured_TP=%s:measured_LRA=%s:measured_thresh=%s:offset=%s:linear=true" % [
				_str(measured.get("input_i", "-14")), _str(measured.get("input_tp", "-1.5")),
				_str(measured.get("input_lra", "11")), _str(measured.get("input_thresh", "-24")),
				_str(measured.get("target_offset", "0")),
			]
		args.append_array(["-af", af, "-c:a", "aac", "-b:a", "%dk" % audio_bitrate, "-ar", "48000", "-ac", "2"])
	args.append_array(["-movflags", "+faststart", "-t", "%.6f" % duration, video_path])
	var enc := _run(args)
	report["encode"] = {
		"command": _display_cmd([ffmpeg] + Array(args)),
		"exit_code": enc.get("code", -1),
		"output_tail": _tail(str(enc.get("output", "")), 2400),
		"include_audio": include_audio,
		"two_pass": not measured.is_empty(),
	}
	if int(enc.get("code", -1)) != 0:
		_log("FFmpeg failed:\n" + _tail(str(enc.get("output", "")), 1800))
		report["error"] = "FFmpeg encode failed (exit %d)." % int(enc.get("code", -1))
		_finish(report)
		return report
	if not FileAccess.file_exists(video_path):
		report["error"] = "FFmpeg reported success but the output file is missing."
		_finish(report)
		return report
	progress.emit("verify", 0, 1, "Verifying output…")
	_log("Encode finished. Probing output…")
	# Verify -----------------------------------------------------------
	var probe := _probe(ffprobe, video_path)
	report["probe"] = probe
	var out_loud := {}
	if include_audio:
		var lm := _run([ffmpeg, "-hide_banner", "-nostats", "-i", video_path, "-map", "0:a:0", "-af", "loudnorm=print_format=json", "-f", "null", "-"])
		out_loud = _extract_json(str(lm.get("output", "")))
		report["loudness_output"] = out_loud
	report["size_bytes"] = FileAccess.get_file_as_bytes(video_path).size() if FileAccess.file_exists(video_path) else 0
	report["sha256"] = _sha256(video_path)
	report["checks"] = _build_checks(probe, out_loud, include_audio, frame_count, width, height, fps, duration)
	var errors := 0
	for c in report["checks"]:
		if not bool(c.get("ok", false)) and str(c.get("severity", "error")) == "error":
			errors += 1
	report["ok"] = errors == 0
	report["finished_utc"] = Time.get_datetime_string_from_system(true)
	report["elapsed_seconds"] = Time.get_unix_time_from_system() - started
	# Write report -----------------------------------------------------
	var fa := FileAccess.open(report_path, FileAccess.WRITE)
	if fa != null:
		fa.store_string(JSON.stringify(report, "  ", false) + "\n")
		fa.close()
	_log("Report: " + report_path)
	if clean_frames_after and report["ok"]:
		_clean_frames(frames_dir)
		_log("Cleaned rendered frames.")
	_finish(report)
	return report

func _finish(report: Dictionary) -> void:
	last_report = report
	if not report.has("finished_utc"):
		report["finished_utc"] = Time.get_datetime_string_from_system(true)
	finished.emit(report)

func _build_checks(probe: Dictionary, loud: Dictionary, has_audio: bool, frame_count: int, width: int, height: int, fps: int, duration: float) -> Array:
	var checks: Array = []
	var v: Dictionary = probe.get("video", {})
	var a: Dictionary = probe.get("audio", {})
	_add_check(checks, "video_stream", "H.264 video stream present", not v.is_empty(), str(v.get("codec_name", "missing")), "error")
	_add_check(checks, "video_codec", "Video codec is H.264", str(v.get("codec_name", "")) == "h264", str(v.get("codec_name", "?")), "error")
	_add_check(checks, "resolution", "Resolution is %d×%d" % [width, height], int(v.get("width", 0)) == width and int(v.get("height", 0)) == height, "%s×%s" % [v.get("width", "?"), v.get("height", "?")], "error")
	_add_check(checks, "pix_fmt", "Pixel format is yuv420p", str(v.get("pix_fmt", "")) == "yuv420p", str(v.get("pix_fmt", "?")), "error")
	var vfps := _fps_value(str(v.get("avg_frame_rate", v.get("r_frame_rate", "0/1"))))
	_add_check(checks, "fps", "Frame rate is %d fps" % fps, absf(vfps - float(fps)) < 0.01, "%.3f" % vfps, "error")
	var frames := int(v.get("nb_read_frames", v.get("nb_frames", 0)))
	_add_check(checks, "frames", "Exactly %d frames" % frame_count, frames == frame_count, str(frames), "error")
	var vdur := float(v.get("duration", probe.get("format", {}).get("duration", 0.0)))
	_add_check(checks, "duration", "Duration is %.3fs (±0.05s)" % duration, absf(vdur - duration) <= 0.05, "%.3fs" % vdur, "error")
	if has_audio:
		_add_check(checks, "audio_stream", "AAC audio stream present", not a.is_empty(), str(a.get("codec_name", "missing")), "error")
		_add_check(checks, "audio_codec", "Audio codec is AAC", str(a.get("codec_name", "")) == "aac", str(a.get("codec_name", "?")), "error")
		_add_check(checks, "sample_rate", "Audio is 48 kHz", int(a.get("sample_rate", 0)) == 48000, str(a.get("sample_rate", "?")), "error")
		_add_check(checks, "channels", "Audio is stereo", int(a.get("channels", 0)) == 2, str(a.get("channels", "?")), "error")
		var li := _float_or(str(loud.get("input_i", "")), -99.0)
		var tp := _float_or(str(loud.get("input_tp", "")), -99.0)
		_add_check(checks, "loudness", "Integrated loudness −14 LUFS ±1.0", absf(li + 14.0) <= 1.0, "%.2f LUFS" % li, "error")
		_add_check(checks, "true_peak", "True peak ≤ −1.0 dBTP", tp <= -1.0, "%.2f dBTP" % tp, "error")
		_add_check(checks, "lra", "Loudness range is plausible (≤ 20 LU)", _float_or(str(loud.get("input_lra", "")), 0.0) <= 20.0, "%s LU" % str(loud.get("input_lra", "?")), "warn")
	else:
		_add_check(checks, "audio_stream", "No audio requested", a.is_empty(), "audio present" if not a.is_empty() else "none", "warn")
	_add_check(checks, "file_size", "Output file has content", int(probe.get("size_bytes", 0)) > 100000, "%d bytes" % int(probe.get("size_bytes", 0)), "error")
	return checks

func _add_check(arr: Array, id: String, label: String, ok: bool, detail: String, severity: String) -> void:
	arr.append({"id": id, "label": label, "ok": ok, "detail": detail, "severity": severity})

func _probe(ffprobe: String, path: String) -> Dictionary:
	var args := [
		ffprobe, "-v", "error", "-count_frames",
		"-show_entries", "stream=index,codec_type,codec_name,width,height,pix_fmt,r_frame_rate,avg_frame_rate,nb_read_frames,nb_frames,sample_rate,channels,channel_layout,duration,bit_rate,profile",
		"-show_entries", "format=duration,size,bit_rate,format_name",
		"-of", "json", path,
	]
	var r := _run(args)
	var text := str(r.get("output", ""))
	var data = JSON.parse_string(text)
	var out := {"raw": text, "size_bytes": FileAccess.get_file_as_bytes(path).size() if FileAccess.file_exists(path) else 0}
	if data is Dictionary:
		out["format"] = data.get("format", {})
		var v := {}
		var a := {}
		for s in data.get("streams", []):
			if s is Dictionary and str(s.get("codec_type", "")) == "video" and v.is_empty():
				v = s
			elif s is Dictionary and str(s.get("codec_type", "")) == "audio" and a.is_empty():
				a = s
		out["video"] = v
		out["audio"] = a
	return out

func _extract_json(text: String) -> Dictionary:
	var start := text.rfind("{")
	if start < 0:
		return {}
	var end := text.find("}", start)
	if end < 0:
		return {}
	var data = JSON.parse_string(text.substr(start, end - start + 1))
	return data if data is Dictionary else {}

func _run(args: Array) -> Dictionary:
	if args.is_empty():
		return {"code": -1, "output": "empty command"}
	var cmd := str(args[0])
	var rest := PackedStringArray()
	for i in range(1, args.size()):
		rest.append(str(args[i]))
	var out: Array = []
	var code := OS.execute(cmd, rest, out, true)
	return {"code": code, "output": "\n".join(out)}

func _abs_path(path: String, project) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	if path.is_absolute_path():
		return path
	return ProjectSettings.globalize_path(project.project_dir.path_join(path))

func _mkdir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		DirAccess.make_dir_recursive_absolute(path)

func _clean_frames(dir: String) -> void:
	var da := DirAccess.open(dir)
	if da == null:
		return
	da.list_dir_begin()
	var f: String = da.get_next()
	while f != "":
		if not da.current_is_dir() and f.begins_with("frame_") and f.ends_with(".png"):
			da.remove(f)
		f = da.get_next()
	da.list_dir_end()

func _sha256(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	while not f.eof_reached():
		var chunk := f.get_buffer(1024 * 1024)
		if chunk.size() > 0:
			ctx.update(chunk)
	f.close()
	return ctx.finish().hex_encode()

func _fps_value(s: String) -> float:
	var parts := s.split("/")
	if parts.size() == 2 and float(parts[1]) != 0.0:
		return float(parts[0]) / float(parts[1])
	return float(s) if s.is_valid_float() else 0.0

func _float_or(s: String, fallback: float) -> float:
	return float(s) if s.is_valid_float() else fallback

func _str(v) -> String:
	return str(v)

func _log(text: String) -> void:
	report_log(text)
	log_message.emit(text)

func report_log(text: String) -> void:
	# kept as a method so the CLI can print without connecting signals
	if last_report.has("logs"):
		last_report["logs"].append(text)
	print(text)

func _tail(text: String, n: int) -> String:
	return text.substr(maxi(0, text.length() - n))

func _display_cmd(args: Array) -> String:
	var parts: Array = []
	for a in args:
		var s := str(a)
		if s.contains(" ") or s.contains(":"):
			parts.append("\"" + s + "\"")
		else:
			parts.append(s)
	return " ".join(parts)
