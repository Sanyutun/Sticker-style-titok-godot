class_name AudioMixer
extends RefCounted
## Deterministic offline audio mix. Reads PCM WAVs, applies track offsets,
## trim, linear gain, fade in/out, mute and solo, then writes a 48 kHz stereo
## 16-bit WAV for FFmpeg. No realtime capture is involved.

const TARGET_RATE := 48000

static func mix(project, out_path: String, sample_rate: int = TARGET_RATE) -> Dictionary:
	var report := {
		"ok": false,
		"path": out_path,
		"sample_rate": sample_rate,
		"channels": 2,
		"tracks_total": 0,
		"tracks_mixed": 0,
		"soloed": [],
		"muted": [],
		"warnings": [],
		"errors": [],
	}
	var duration := maxf(0.01, float(project.episode.get("duration_seconds", 10.0)))
	var total_frames := int(round(duration * float(sample_rate)))
	var buffer := PackedFloat32Array()
	buffer.resize(total_frames * 2)
	var tracks: Array = project.storyboard.get("audio", {}).get("tracks", [])
	report["tracks_total"] = tracks.size()
	var any_solo := false
	for tr in tracks:
		if tr is Dictionary and bool(tr.get("solo", false)) and not bool(tr.get("mute", false)):
			any_solo = true
	var mixed := 0
	for tr in tracks:
		if not tr is Dictionary:
			continue
		var id := str(tr.get("id", "audio_%d" % mixed))
		if bool(tr.get("mute", false)):
			report["muted"].append(id)
			continue
		if any_solo and not bool(tr.get("solo", false)):
			continue
		if any_solo and bool(tr.get("solo", false)):
			report["soloed"].append(id)
		var file := str(tr.get("file", ""))
		var abs_path: String = str(project.resolve_asset(file))
		if abs_path.is_empty() or not FileAccess.file_exists(abs_path):
			report["warnings"].append("Missing audio for %s: %s" % [id, file])
			continue
		var wav := read_wav(abs_path)
		if wav.is_empty():
			report["warnings"].append("Unsupported WAV for %s: %s" % [id, file])
			continue
		var wav_rate := int(wav["rate"])
		var wav_frames: int = int(wav["frames"])
		var wav_samples: PackedFloat32Array = wav["samples"]
		var start_t := clampf(float(tr.get("start", 0.0)), 0.0, duration)
		var track_dur := float(tr.get("duration", float(wav_frames) / float(wav_rate)))
		var usable := minf(track_dur, duration - start_t)
		if usable <= 0.0:
			continue
		var start_frame := int(round(start_t * float(sample_rate)))
		var n_frames := int(round(usable * float(sample_rate)))
		n_frames = mini(n_frames, total_frames - start_frame)
		if n_frames <= 0:
			continue
		var gain := float(tr.get("gain", 1.0))
		var fi := maxf(0.0, float(tr.get("fade_in", 0.0)))
		var fo := maxf(0.0, float(tr.get("fade_out", 0.0)))
		var fi_n := int(round(fi * float(sample_rate)))
		var fo_n := int(round(fo * float(sample_rate)))
		for i in range(n_frames):
			var src_pos := float(i) * float(wav_rate) / float(sample_rate)
			var si := int(src_pos)
			if si >= wav_frames - 1:
				break
			var frac := src_pos - float(si)
			var env := 1.0
			if fi_n > 0 and i < fi_n:
				env = float(i) / float(fi_n)
			if fo_n > 0 and i >= n_frames - fo_n:
				env = minf(env, float(n_frames - i) / float(fo_n))
			var g := gain * maxf(0.0, env)
			var dst := (start_frame + i) * 2
			var l := wav_samples[si * 2] * (1.0 - frac) + wav_samples[(si + 1) * 2] * frac
			var r := wav_samples[si * 2 + 1] * (1.0 - frac) + wav_samples[(si + 1) * 2 + 1] * frac
			buffer[dst] += l * g
			buffer[dst + 1] += r * g
		mixed += 1
	report["tracks_mixed"] = mixed
	# peak / RMS, then conservative pre-limiter to guarantee no integer clipping
	var peak := 0.0
	var sumsq := 0.0
	for v in buffer:
		var a := absf(v)
		if a > peak:
			peak = a
		sumsq += v * v
	var scale := 1.0
	if peak > 0.999:
		scale = 0.985 / peak
		for i in range(buffer.size()):
			buffer[i] *= scale
		peak = 0.985
	var rms := sqrt(sumsq / maxf(1.0, float(buffer.size())))
	report["peak_dbfs"] = 20.0 * log(maxf(1e-12, peak)) / log(10.0)
	report["rms_dbfs"] = 20.0 * log(maxf(1e-12, rms)) / log(10.0)
	report["pre_limiter_scale"] = scale
	report["frames"] = total_frames
	report["duration_seconds"] = float(total_frames) / float(sample_rate)
	if mixed == 0:
		report["errors"].append("No audible audio tracks were mixed.")
	var wav_err := write_wav(out_path, buffer, sample_rate)
	if wav_err != OK:
		report["errors"].append("Could not write mix WAV (error %d)" % wav_err)
		return report
	report["bytes"] = FileAccess.get_file_as_bytes(out_path).size() if FileAccess.file_exists(out_path) else 0
	report["ok"] = mixed > 0 and wav_err == OK
	return report

static func read_wav(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var length := f.get_length()
	if length < 44:
		return {}
	if f.get_buffer(4).get_string_from_ascii() != "RIFF":
		return {}
	f.seek(8)
	if f.get_buffer(4).get_string_from_ascii() != "WAVE":
		return {}
	var fmt_tag := 0
	var channels := 0
	var rate := 0
	var bits := 0
	var block_align := 0
	var data := PackedByteArray()
	while f.get_position() + 8 <= length:
		var id := f.get_buffer(4).get_string_from_ascii()
		var size := f.get_32()
		var body_start := f.get_position()
		if id == "fmt ":
			fmt_tag = f.get_16()
			channels = f.get_16()
			rate = f.get_32()
			var byte_rate := f.get_32()
			block_align = f.get_16()
			bits = f.get_16()
			if fmt_tag == 0xFFFE and size >= 26:
				f.seek(body_start + 24)
				fmt_tag = f.get_16()
		elif id == "data":
			data = f.get_buffer(mini(size, length - body_start))
		var next := body_start + size
		if size % 2 == 1:
			next += 1
		if next <= body_start:
			break
		f.seek(mini(next, length))
	f.close()
	if data.is_empty() or channels <= 0 or rate <= 0 or bits <= 0:
		return {}
	if block_align <= 0:
		block_align = channels * bits / 8
	var frames := data.size() / block_align
	if frames <= 0:
		return {}
	var out := PackedFloat32Array()
	out.resize(frames * 2)
	var bytes_per_sample := bits / 8
	if fmt_tag == 3 and bits == 32:
		for i in range(frames):
			var base := i * block_align
			var l := data.decode_float(base)
			var r := data.decode_float(base + 4) if channels >= 2 else l
			out[i * 2] = l
			out[i * 2 + 1] = r
	elif fmt_tag == 1 and bits == 16:
		for i in range(frames):
			var base := i * block_align
			var l := float(data.decode_s16(base)) / 32768.0
			var r := float(data.decode_s16(base + 2)) / 32768.0 if channels >= 2 else l
			out[i * 2] = l
			out[i * 2 + 1] = r
	elif fmt_tag == 1 and bits == 24:
		for i in range(frames):
			var base := i * block_align
			var l := _s24(data, base) / 8388608.0
			var r := _s24(data, base + 3) / 8388608.0 if channels >= 2 else l
			out[i * 2] = l
			out[i * 2 + 1] = r
	elif fmt_tag == 1 and bits == 32:
		for i in range(frames):
			var base := i * block_align
			var l := float(data.decode_s32(base)) / 2147483648.0
			var r := float(data.decode_s32(base + 4)) / 2147483648.0 if channels >= 2 else l
			out[i * 2] = l
			out[i * 2 + 1] = r
	elif fmt_tag == 1 and bits == 8:
		for i in range(frames):
			var base := i * block_align
			var l := (float(data[base]) - 128.0) / 128.0
			var r := (float(data[base + 1]) - 128.0) / 128.0 if channels >= 2 else l
			out[i * 2] = l
			out[i * 2 + 1] = r
	else:
		return {}
	if rate != TARGET_RATE:
		var resampled := _resample(out, frames, rate, TARGET_RATE)
		out = resampled["samples"]
		frames = resampled["frames"]
		rate = TARGET_RATE
	return {"rate": rate, "channels": 2, "frames": frames, "samples": out, "bits": bits, "source_channels": channels}

static func _s24(data: PackedByteArray, off: int) -> int:
	var v := int(data[off]) | (int(data[off + 1]) << 8) | (int(data[off + 2]) << 16)
	if v & 0x800000 != 0:
		v -= 0x1000000
	return v

static func _resample(src: PackedFloat32Array, frames: int, from_rate: int, to_rate: int) -> Dictionary:
	var out_frames := int(round(float(frames) * float(to_rate) / float(from_rate)))
	var out := PackedFloat32Array()
	out.resize(out_frames * 2)
	for i in range(out_frames):
		var pos := float(i) * float(from_rate) / float(to_rate)
		var i0 := int(pos)
		var i1 := mini(i0 + 1, frames - 1)
		var t := pos - float(i0)
		out[i * 2] = lerpf(src[i0 * 2], src[i1 * 2], t)
		out[i * 2 + 1] = lerpf(src[i0 * 2 + 1], src[i1 * 2 + 1], t)
	return {"samples": out, "frames": out_frames}

static func write_wav(path: String, samples: PackedFloat32Array, rate: int) -> int:
	var dir := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		var mk := DirAccess.make_dir_recursive_absolute(dir)
		if mk != OK:
			return mk
	var sp := StreamPeerBuffer.new()
	sp.big_endian = false
	var data_bytes := samples.size() * 2
	var riff_size := 36 + data_bytes
	sp.put_data("RIFF".to_ascii_buffer())
	sp.put_32(riff_size)
	sp.put_data("WAVE".to_ascii_buffer())
	sp.put_data("fmt ".to_ascii_buffer())
	sp.put_32(16)
	sp.put_16(1)
	sp.put_16(2)
	sp.put_32(rate)
	sp.put_32(rate * 4)
	sp.put_16(4)
	sp.put_16(16)
	sp.put_data("data".to_ascii_buffer())
	sp.put_32(data_bytes)
	for v in samples:
		var iv := int(round(clampf(v, -1.0, 1.0) * 32767.0))
		sp.put_16(iv)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_buffer(sp.data_array)
	f.close()
	return OK

static func wav_duration(path: String) -> float:
	var w := read_wav(path)
	if w.is_empty():
		return 0.0
	return float(w["frames"]) / float(w["rate"])
