class_name AudioPanel
extends VBoxContainer
## Audio tracks, fades, mute/solo, cues and scratch-narration status.

signal track_changed(track_id: String, field: String, value: Variant)
signal seek_requested(time: float)
signal play_toggle_requested
signal status_message(text: String)

var project = null
var manager: StudioAudioManager = null
var selected_track_id := ""
var current_time := 0.0
var playing := false
var _updating := false
var _tracks_box: VBoxContainer
var _detail_box: VBoxContainer
var _cue_box: VBoxContainer
var _play_btn: Button
var _device_label: Label
var _time_label: Label
var _master_check: CheckBox

func _ready() -> void:
	add_theme_constant_override("separation", 0)
	var head := MarginContainer.new()
	head.add_theme_constant_override("margin_left", 10)
	head.add_theme_constant_override("margin_right", 10)
	head.add_theme_constant_override("margin_top", 6)
	head.add_theme_constant_override("margin_bottom", 5)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	head.add_child(hb)
	add_child(head)
	hb.add_child(EditorTheme.heading("Audio", 11, Color("#E8EDF3")))
	_play_btn = Button.new()
	_play_btn.text = "▶ Preview"
	_play_btn.custom_minimum_size = Vector2(86, 27)
	_play_btn.pressed.connect(func(): play_toggle_requested.emit())
	hb.add_child(_play_btn)
	var stop := Button.new()
	stop.text = "■"
	stop.tooltip_text = "Return to the start of the episode"
	stop.custom_minimum_size = Vector2(30, 27)
	stop.pressed.connect(func(): seek_requested.emit(0.0))
	hb.add_child(stop)
	_master_check = CheckBox.new()
	_master_check.text = "Mute all"
	_master_check.toggled.connect(func(on):
		if _updating: return
		if manager != null:
			manager.set_master_muted(on)
		status_message.emit("Preview muted." if on else "Preview unmuted.")
	)
	hb.add_child(_master_check)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(sp)
	_time_label = Label.new()
	_time_label.text = "0.00s"
	_time_label.add_theme_font_size_override("font_size", 11)
	_time_label.add_theme_color_override("font_color", Color("#FFB59E"))
	hb.add_child(_time_label)
	_device_label = Label.new()
	_device_label.text = "AUDIO"
	_device_label.add_theme_font_size_override("font_size", 9)
	_device_label.add_theme_color_override("font_color", Color("#66717F"))
	hb.add_child(_device_label)

	var warn := PanelContainer.new()
	warn.add_theme_stylebox_override("panel", EditorTheme.padded(Color("#2B2116"), 0, 10, 5, Color("#5A4526"), 1))
	var wl := Label.new()
	wl.text = "SCRATCH NARRATION GUIDE — synthetic espeak-ng voice, not a finished voice-over. Replace before publication. Burmese voice/subtitles intentionally pending review."
	wl.add_theme_font_size_override("font_size", 10)
	wl.add_theme_color_override("font_color", Color("#E9C46A"))
	wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warn.add_child(wl)
	add_child(warn)

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 700
	add_child(split)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(left)
	var lhead := MarginContainer.new()
	lhead.add_theme_constant_override("margin_left", 10)
	lhead.add_theme_constant_override("margin_top", 6)
	lhead.add_child(EditorTheme.heading("Tracks · click to inspect", 9, Color("#8B98A8")))
	left.add_child(lhead)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	_tracks_box = VBoxContainer.new()
	_tracks_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tracks_box.add_theme_constant_override("separation", 1)
	scroll.add_child(_tracks_box)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(310, 0)
	split.add_child(right)
	var dscroll := ScrollContainer.new()
	dscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(dscroll)
	_detail_box = VBoxContainer.new()
	_detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_box.add_theme_constant_override("separation", 6)
	dscroll.add_child(_detail_box)
	var cue_head := MarginContainer.new()
	cue_head.add_theme_constant_override("margin_left", 4)
	cue_head.add_theme_constant_override("margin_top", 8)
	cue_head.add_child(EditorTheme.heading("Cue sheet", 9, Color("#8B98A8")))
	right.add_child(cue_head)
	var cscroll := ScrollContainer.new()
	cscroll.custom_minimum_size = Vector2(0, 116)
	cscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(cscroll)
	_cue_box = VBoxContainer.new()
	_cue_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cscroll.add_child(_cue_box)

func setup(p_project, p_manager: StudioAudioManager) -> void:
	project = p_project
	manager = p_manager
	refresh()
	if manager != null:
		_device_label.text = "DUMMY DRIVER" if not manager.device_available else manager.device_name.to_upper()
		_device_label.add_theme_color_override("font_color", Color("#E9C46A") if not manager.device_available else Color("#72CE9B"))

func refresh() -> void:
	if project == null:
		return
	_updating = true
	var tracks: Array = project.storyboard.get("audio", {}).get("tracks", [])
	for c in _tracks_box.get_children():
		c.queue_free()
	for c in _detail_box.get_children():
		c.queue_free()
	for c in _cue_box.get_children():
		c.queue_free()
	if selected_track_id.is_empty() and not tracks.is_empty():
		selected_track_id = str(tracks[0].get("id", ""))
	for tr in tracks:
		if not tr is Dictionary:
			continue
		_build_track_row(tr)
	_build_detail()
	_build_cues(tracks)
	_play_btn.text = "■ Pause" if playing else "▶ Preview"
	_time_label.text = "%.2fs" % current_time
	_device_label.text = "DUMMY DRIVER · SILENT PREVIEW" if (manager != null and not manager.device_available) else (manager.device_name.to_upper() if manager != null else "AUDIO")
	_device_label.add_theme_color_override("font_color", Color("#E9C46A") if (manager != null and not manager.device_available) else Color("#72CE9B"))
	_updating = false

func update_time(t: float, is_playing: bool) -> void:
	current_time = t
	playing = is_playing
	if _time_label != null:
		_time_label.text = "%.2fs" % t
	if _play_btn != null:
		_play_btn.text = "■ Pause" if is_playing else "▶ Preview"

func _build_track_row(tr: Dictionary) -> void:
	var id := str(tr.get("id", ""))
	var sel := id == selected_track_id
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", EditorTheme.padded(Color("#1D242C") if sel else Color.TRANSPARENT, 0))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 5)
	row.add_child(h)
	_tracks_box.add_child(row)
	var mute := Button.new()
	mute.text = "M"
	mute.toggle_mode = true
	mute.button_pressed = bool(tr.get("mute", false))
	mute.tooltip_text = "Mute this track"
	mute.custom_minimum_size = Vector2(24, 23)
	mute.add_theme_font_size_override("font_size", 10)
	mute.toggled.connect(func(on):
		if _updating: return
		track_changed.emit(id, "mute", on)
	)
	h.add_child(mute)
	var solo := Button.new()
	solo.text = "S"
	solo.toggle_mode = true
	solo.button_pressed = bool(tr.get("solo", false))
	solo.tooltip_text = "Solo this track (others are muted in preview and export)"
	solo.custom_minimum_size = Vector2(24, 23)
	solo.add_theme_font_size_override("font_size", 10)
	solo.toggled.connect(func(on):
		if _updating: return
		track_changed.emit(id, "solo", on)
	)
	h.add_child(solo)
	var dot := ColorRect.new()
	dot.color = _type_color(str(tr.get("type", "")))
	dot.custom_minimum_size = Vector2(3, 22)
	h.add_child(dot)
	var name_btn := Button.new()
	name_btn.text = str(tr.get("name", id))
	name_btn.flat = true
	name_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_btn.add_theme_font_size_override("font_size", 11)
	name_btn.add_theme_color_override("font_color", Color("#E8EDF3") if sel else Color("#B8C4D2"))
	name_btn.tooltip_text = "%s\n%s" % [str(tr.get("file", "")), str(tr.get("type", ""))]
	name_btn.pressed.connect(func():
		selected_track_id = id
		refresh()
	)
	h.add_child(name_btn)
	var start := Label.new()
	start.text = "%.2fs" % float(tr.get("start", 0.0))
	start.custom_minimum_size = Vector2(48, 0)
	start.add_theme_font_size_override("font_size", 10)
	start.add_theme_color_override("font_color", Color("#8B98A8"))
	h.add_child(start)
	var dur := Label.new()
	dur.text = "%.2fs" % float(tr.get("duration", 0.0))
	dur.custom_minimum_size = Vector2(48, 0)
	dur.add_theme_font_size_override("font_size", 10)
	dur.add_theme_color_override("font_color", Color("#66717F"))
	h.add_child(dur)
	var gain := HSlider.new()
	gain.min_value = 0.0
	gain.max_value = 1.5
	gain.step = 0.01
	gain.value = float(tr.get("gain", 1.0))
	gain.custom_minimum_size = Vector2(96, 22)
	gain.tooltip_text = "Linear gain"
	gain.value_changed.connect(func(v):
		if _updating: return
		track_changed.emit(id, "gain", v)
	)
	h.add_child(gain)
	var gl := Label.new()
	gl.text = "%d%%" % int(round(float(tr.get("gain", 1.0)) * 100.0))
	gl.custom_minimum_size = Vector2(36, 0)
	gl.add_theme_font_size_override("font_size", 9)
	gl.add_theme_color_override("font_color", Color("#66717F"))
	h.add_child(gl)

func _build_detail() -> void:
	_detail_box.add_child(EditorTheme.heading("Track detail", 9, Color("#8B98A8")))
	var tracks: Array = project.storyboard.get("audio", {}).get("tracks", [])
	var tr: Dictionary = {}
	for t in tracks:
		if t is Dictionary and str(t.get("id", "")) == selected_track_id:
			tr = t
			break
	if tr.is_empty():
		var l := Label.new()
		l.text = "Select a track."
		l.add_theme_font_size_override("font_size", 10)
		l.add_theme_color_override("font_color", Color("#66717F"))
		_detail_box.add_child(l)
		return
	var title := Label.new()
	title.text = str(tr.get("name", selected_track_id))
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color("#E8EDF3"))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_box.add_child(title)
	var file := Label.new()
	file.text = str(tr.get("file", ""))
	file.add_theme_font_size_override("font_size", 9)
	file.add_theme_color_override("font_color", Color("#66717F"))
	file.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_detail_box.add_child(file)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 5)
	_detail_box.add_child(grid)
	var id := selected_track_id
	var start := _spin(float(tr.get("start", 0.0)), 0.01, 0.0, 60.0, "s")
	_grid_field(grid, "Start", start)
	start.value_changed.connect(func(v): track_changed.emit(id, "start", v))
	var dur := _spin(float(tr.get("duration", 0.0)), 0.01, 0.0, 60.0, "s")
	_grid_field(grid, "Duration", dur)
	dur.value_changed.connect(func(v): track_changed.emit(id, "duration", v))
	var gain := _spin(float(tr.get("gain", 1.0)), 0.01, 0.0, 2.0)
	_grid_field(grid, "Gain", gain)
	gain.value_changed.connect(func(v): track_changed.emit(id, "gain", v))
	var fi := _spin(float(tr.get("fade_in", 0.0)), 0.01, 0.0, 5.0, "s")
	_grid_field(grid, "Fade in", fi)
	fi.value_changed.connect(func(v): track_changed.emit(id, "fade_in", v))
	var fo := _spin(float(tr.get("fade_out", 0.0)), 0.01, 0.0, 5.0, "s")
	_grid_field(grid, "Fade out", fo)
	fo.value_changed.connect(func(v): track_changed.emit(id, "fade_out", v))
	var mute := CheckBox.new()
	mute.text = "Mute"
	mute.button_pressed = bool(tr.get("mute", false))
	_grid_field(grid, "State", mute)
	mute.toggled.connect(func(on): track_changed.emit(id, "mute", on))
	var solo := CheckBox.new()
	solo.text = "Solo"
	solo.button_pressed = bool(tr.get("solo", false))
	_grid_field(grid, " ", solo)
	solo.toggled.connect(func(on): track_changed.emit(id, "solo", on))
	var hint := Label.new()
	hint.text = "Fades are applied per sample in the export mix; the preview follows them live."
	hint.add_theme_font_size_override("font_size", 9)
	hint.add_theme_color_override("font_color", Color("#66717F"))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_box.add_child(hint)
	if selected_track_id.begins_with("narration"):
		var note := Label.new()
		note.text = "Synthetic scratch guide. Check pronunciation and pacing before using this cut publicly."
		note.add_theme_font_size_override("font_size", 9)
		note.add_theme_color_override("font_color", Color("#E9C46A"))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail_box.add_child(note)

func _build_cues(tracks: Array) -> void:
	var cues: Array = []
	for tr in tracks:
		if not tr is Dictionary:
			continue
		for c in tr.get("cues", []):
			if c is Dictionary:
				cues.append({"time": float(c.get("time", 0.0)), "label": str(c.get("label", "")), "type": str(tr.get("type", "sfx")), "source": str(tr.get("name", ""))})
	for sc in project.storyboard.get("scenes", []):
		if sc is Dictionary:
			for c in sc.get("cues", []):
				if c is Dictionary:
					cues.append({"time": float(c.get("time", 0.0)), "label": str(c.get("label", "")), "type": str(c.get("type", "cue")), "source": str(sc.get("name", ""))})
	cues.sort_custom(func(a, b): return a["time"] < b["time"])
	if cues.is_empty():
		var l := Label.new()
		l.text = "No cues configured."
		l.add_theme_font_size_override("font_size", 9)
		l.add_theme_color_override("font_color", Color("#66717F"))
		_cue_box.add_child(l)
		return
	for c in cues:
		var row := Button.new()
		row.flat = true
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.text = "%05.2fs  %s  ·  %s" % [c["time"], c["label"], c["source"]]
		row.add_theme_font_size_override("font_size", 9)
		row.add_theme_color_override("font_color", Color("#B8C4D2"))
		row.tooltip_text = "Jump to cue"
		var t: float = c["time"]
		row.pressed.connect(func(): seek_requested.emit(t))
		_cue_box.add_child(row)

func _grid_field(grid: GridContainer, label_text: String, control: Control) -> void:
	var l := Label.new()
	l.text = label_text
	l.custom_minimum_size = Vector2(66, 0)
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", Color("#8B98A8"))
	grid.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(control)

func _spin(value: float, step: float, minv: float, maxv: float, suffix: String = "") -> SpinBox:
	var s := SpinBox.new()
	s.min_value = minv
	s.max_value = maxv
	s.step = step
	s.suffix = suffix
	s.allow_greater = true
	s.custom_minimum_size = Vector2(0, 24)
	s.set_value_no_signal(value)
	return s

func set_time(t: float, is_playing: bool) -> void:
	update_time(t, is_playing)

static func _type_color(t: String) -> Color:
	match t:
		"music": return Color("#B79CED")
		"narration": return Color("#62AEDA")
		"sfx": return Color("#E9C46A")
		_: return Color("#8B98A8")
