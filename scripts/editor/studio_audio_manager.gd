class_name StudioAudioManager
extends Node
## Realtime preview mixer for the editor. Export uses the deterministic
## offline mixer in scripts/export/audio_mixer.gd instead of this class.

var project = null
var tracks: Array = []
var players: Dictionary = {} # track id -> AudioStreamPlayer
var streams: Dictionary = {} # absolute path -> AudioStreamWAV
var current_time := 0.0
var playing := false
var master_muted := false
var any_solo := false
var device_available := true
var device_name := ""
var last_error := ""

func _ready() -> void:
	device_name = AudioServer.get_output_device()
	var list := AudioServer.get_output_device_list()
	device_available = list.size() > 0 and device_name.to_lower() != "dummy"
	if not device_available:
		last_error = "Audio device unavailable (Godot dummy driver). Preview is silent; offline export still mixes audio."

func setup(p_project) -> void:
	stop_all()
	project = p_project
	tracks = project.storyboard.get("audio", {}).get("tracks", [])
	players.clear()
	streams.clear()
	any_solo = false
	for tr in tracks:
		if tr is Dictionary and bool(tr.get("solo", false)) and not bool(tr.get("mute", false)):
			any_solo = true

func set_master_muted(on: bool) -> void:
	master_muted = on
	if master_muted:
		for p in players.values():
			if is_instance_valid(p):
				p.stop()
		players.clear()

func seek(time: float, keep_playing: bool = false) -> void:
	current_time = time
	stop_all()
	playing = keep_playing
	if keep_playing:
		update(time, true, true)

func toggle_play(time: float, on: bool) -> void:
	current_time = time
	playing = on
	if not on:
		stop_all()
	else:
		update(time, true, true)

func stop_all() -> void:
	for id in players.keys():
		var p = players[id]
		if is_instance_valid(p):
			p.stop()
			p.queue_free()
	players.clear()

func update(time: float, is_playing: bool, force: bool = false) -> void:
	current_time = time
	playing = is_playing
	if not is_playing or master_muted:
		return
	any_solo = false
	for tr in tracks:
		if tr is Dictionary and bool(tr.get("solo", false)) and not bool(tr.get("mute", false)):
			any_solo = true
	for tr in tracks:
		if not tr is Dictionary:
			continue
		var id := str(tr.get("id", ""))
		var audible := _is_audible(tr)
		var st := float(tr.get("start", 0.0))
		var dur := float(tr.get("duration", 0.0))
		var inside := time + 0.0001 >= st and time < st + dur
		if not audible or not inside:
			if players.has(id):
				var old = players[id]
				if is_instance_valid(old):
					old.stop()
					old.queue_free()
				players.erase(id)
			continue
		var vol := _gain_at(tr, time)
		if vol <= 0.0001:
			continue
		var p = players.get(id, null)
		if p == null or not is_instance_valid(p):
			var stream := _stream_for(str(tr.get("file", "")))
			if stream == null:
				continue
			p = AudioStreamPlayer.new()
			p.name = "Audio_" + id
			p.stream = stream
			p.volume_db = linear_to_db(vol)
			add_child(p)
			players[id] = p
			p.play(maxf(0.0, time - st))
		else:
			p.volume_db = linear_to_db(vol)
			if force or absf(p.get_playback_position() - maxf(0.0, time - st)) > 0.25:
				p.seek(maxf(0.0, time - st))
			if not p.playing:
				p.play(maxf(0.0, time - st))

func _is_audible(tr: Dictionary) -> bool:
	if bool(tr.get("mute", false)):
		return false
	if any_solo and not bool(tr.get("solo", false)):
		return false
	return true

func _gain_at(tr: Dictionary, time: float) -> float:
	var st := float(tr.get("start", 0.0))
	var dur := float(tr.get("duration", 0.0))
	var elapsed := time - st
	var remaining := st + dur - time
	var env := 1.0
	var fi := float(tr.get("fade_in", 0.0))
	var fo := float(tr.get("fade_out", 0.0))
	if fi > 0.0001 and elapsed < fi:
		env *= clampf(elapsed / fi, 0.0, 1.0)
	if fo > 0.0001 and remaining < fo:
		env *= clampf(remaining / fo, 0.0, 1.0)
	return maxf(0.0, float(tr.get("gain", 1.0)) * env)

func _stream_for(path: String) -> AudioStreamWAV:
	if path.is_empty():
		return null
	var abs_path: String = str(project.resolve_asset(path))
	if abs_path.is_empty():
		return null
	if streams.has(abs_path):
		return streams[abs_path]
	if not FileAccess.file_exists(abs_path):
		last_error = "Missing audio: " + abs_path
		return null
	var s := AudioStreamWAV.load_from_file(abs_path)
	if s == null:
		last_error = "Unsupported audio stream: " + abs_path
		return null
	s.loop_mode = AudioStreamWAV.LOOP_DISABLED
	streams[abs_path] = s
	return s

func active_track_count() -> int:
	return players.size()

func status_text() -> String:
	if not device_available:
		return "AUDIO DEVICE: dummy · preview silent (export unaffected)"
	return "AUDIO DEVICE: %s · %d player(s)" % [device_name, players.size()]
