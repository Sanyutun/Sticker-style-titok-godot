class_name StoryboardPanel
extends VBoxContainer
## Scene cards, subtitle review, narration and localization status.

signal jump_requested(time: float)
signal scene_field_changed(scene_id: String, field: String, value: Variant)
signal subtitle_changed(lang: String, index: int, field: String, value: Variant)
signal subtitle_add_requested(lang: String, start: float, end: float)
signal subtitle_delete_requested(lang: String, index: int)
signal validate_requested
signal status_message(text: String)

var project = null
var current_time := 0.0
var _updating := false
var _body: VBoxContainer
var _sub_lang := "en"
var _sub_box: VBoxContainer
var _lang_option: OptionButton

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
	hb.add_child(EditorTheme.heading("Storyboard", 11, Color("#E8EDF3")))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(sp)
	var val := Button.new()
	val.text = "Validate project"
	val.custom_minimum_size = Vector2(104, 27)
	val.pressed.connect(func(): validate_requested.emit())
	hb.add_child(val)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 8)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 12)
	margin.add_child(_body)
	scroll.add_child(margin)

func setup(p_project) -> void:
	project = p_project
	refresh()

func set_time(t: float) -> void:
	current_time = t

func refresh() -> void:
	if project == null:
		return
	_updating = true
	for c in _body.get_children():
		c.queue_free()
	_build_summary()
	_build_scenes()
	_build_localization()
	_build_subtitles()
	_updating = false

func _build_summary() -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", EditorTheme.padded(Color("#1D242C"), 5, 12, 9, Color("#303A46"), 1))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	card.add_child(h)
	_body.add_child(card)
	var scenes: Array = project.storyboard.get("scenes", [])
	var total := 0.0
	var complete := 0
	for s in scenes:
		if s is Dictionary:
			total += maxf(0.0, float(s.get("end", 0.0)) - float(s.get("start", 0.0)))
			if not str(s.get("purpose", "")).strip_edges().is_empty() and not (s.get("cues", []) as Array).is_empty():
				complete += 1
	_stat(h, "SCENES", str(scenes.size()))
	_stat(h, "RUNTIME", "%.2fs · %d frames" % [float(project.episode.get("duration_seconds", 10.0)), project.frame_count()])
	_stat(h, "COVERAGE", "%.2fs" % total)
	_stat(h, "SCENE CHECKS", "%d / %d" % [complete, scenes.size()])
	_stat(h, "SUBTITLES", "%d EN · %d MY" % [
		(project.storyboard.get("subtitles", {}).get("en", []) as Array).size(),
		(project.storyboard.get("subtitles", {}).get("my", []) as Array).size(),
	])

func _stat(parent: HBoxContainer, key: String, value: String) -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	var kl := Label.new()
	kl.text = key
	kl.add_theme_font_size_override("font_size", 8)
	kl.add_theme_color_override("font_color", Color("#66717F"))
	v.add_child(kl)
	var vl := Label.new()
	vl.text = value
	vl.add_theme_font_size_override("font_size", 13)
	vl.add_theme_color_override("font_color", Color("#E8EDF3"))
	v.add_child(vl)
	parent.add_child(v)

func _build_scenes() -> void:
	var scenes: Array = project.storyboard.get("scenes", [])
	_body.add_child(EditorTheme.heading("Scene cards", 9, Color("#8B98A8")))
	for i in range(scenes.size()):
		var s: Dictionary = scenes[i]
		var card := PanelContainer.new()
		var active := current_time >= float(s.get("start", 0.0)) and current_time < float(s.get("end", 999.0))
		card.add_theme_stylebox_override("panel", EditorTheme.padded(Color("#1B222A") if not active else Color("#23211D"), 4, 0, 0, Color(1, 0.42, 0.27, 0.55) if active else Color("#2B333D"), 1))
		_body.add_child(card)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		card.add_child(h)
		var idx := Label.new()
		idx.text = "%02d" % (i + 1)
		idx.custom_minimum_size = Vector2(30, 0)
		idx.add_theme_font_size_override("font_size", 20)
		idx.add_theme_color_override("font_color", _scene_color(i))
		h.add_child(idx)
		var content := VBoxContainer.new()
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_theme_constant_override("separation", 3)
		h.add_child(content)
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 8)
		content.add_child(top)
		var name := Label.new()
		name.text = str(s.get("name", "Scene"))
		name.add_theme_font_size_override("font_size", 13)
		name.add_theme_color_override("font_color", Color("#E8EDF3"))
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(name)
		var time := Label.new()
		time.text = "%.2f – %.2fs  ·  %.2fs" % [float(s.get("start", 0.0)), float(s.get("end", 0.0)), float(s.get("end", 0.0)) - float(s.get("start", 0.0))]
		time.add_theme_font_size_override("font_size", 10)
		time.add_theme_color_override("font_color", Color("#8B98A8"))
		top.add_child(time)
		var jump := Button.new()
		jump.text = "Jump"
		jump.custom_minimum_size = Vector2(48, 22)
		jump.add_theme_font_size_override("font_size", 10)
		var st := float(s.get("start", 0.0))
		jump.pressed.connect(func(): jump_requested.emit(st))
		top.add_child(jump)

		var purpose := LineEdit.new()
		purpose.text = str(s.get("purpose", ""))
		purpose.placeholder_text = "Scene purpose"
		purpose.add_theme_font_size_override("font_size", 10)
		purpose.custom_minimum_size = Vector2(0, 24)
		content.add_child(purpose)
		var sc_id := str(s.get("id", ""))
		purpose.text_changed.connect(func(t):
			if _updating: return
			scene_field_changed.emit(sc_id, "purpose", t)
		)
		var meta := HBoxContainer.new()
		meta.add_theme_constant_override("separation", 8)
		content.add_child(meta)
		var cam = s.get("camera_target", [])
		var cam_txt := "camera %s, %s" % [str(cam[0]) if cam is Array and cam.size() > 0 else "—", str(cam[1]) if cam is Array and cam.size() > 1 else "—"]
		var ml := Label.new()
		ml.text = "%s  ·  narration: %s" % [cam_txt, str(s.get("narration", "en")).to_upper()]
		ml.add_theme_font_size_override("font_size", 9)
		ml.add_theme_color_override("font_color", Color("#66717F"))
		meta.add_child(ml)
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		meta.add_child(sp)
		var cues: Array = s.get("cues", [])
		if cues.is_empty():
			var none := Label.new()
			none.text = "no cues"
			none.add_theme_font_size_override("font_size", 9)
			none.add_theme_color_override("font_color", Color("#E9C46A"))
			meta.add_child(none)
		else:
			for c in cues:
				if c is Dictionary:
					var chip := Label.new()
					chip.text = " %05.2fs · %s " % [float(c.get("time", 0.0)), str(c.get("label", ""))]
					chip.add_theme_font_size_override("font_size", 9)
					chip.add_theme_color_override("font_color", Color("#C9D3DF"))
					var cp := PanelContainer.new()
					cp.add_theme_stylebox_override("panel", EditorTheme.padded(Color("#2A3038"), 10, 5, 1))
					cp.add_child(chip)
					meta.add_child(cp)

func _build_localization() -> void:
	_body.add_child(EditorTheme.heading("Narration & localization", 9, Color("#8B98A8")))
	var loc: Dictionary = project.episode.get("localization", {})
	var narr: Dictionary = loc.get("narration", {})
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", EditorTheme.padded(Color("#1B222A"), 5, 12, 9, Color("#303A46"), 1))
	_body.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	card.add_child(v)
	var en_label := Label.new()
	en_label.text = "ENGLISH NARRATION — SCRATCH GUIDE"
	en_label.add_theme_font_size_override("font_size", 8)
	en_label.add_theme_color_override("font_color", Color("#E9C46A"))
	v.add_child(en_label)
	var en := Label.new()
	en.text = str(narr.get("en", ""))
	en.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	en.add_theme_font_size_override("font_size", 11)
	en.add_theme_color_override("font_color", Color("#C9D3DF"))
	v.add_child(en)
	var my_label := Label.new()
	my_label.text = "BURMESE — %s" % str(project.storyboard.get("subtitles", {}).get("my_status", "needs_localization")).replace("_", " ").to_upper()
	my_label.add_theme_font_size_override("font_size", 8)
	my_label.add_theme_color_override("font_color", Color("#FF9B8A"))
	v.add_child(my_label)
	var my := Label.new()
	var my_text := str(narr.get("my", ""))
	my.text = my_text if not my_text.strip_edges().is_empty() else "No Burmese narration or subtitles are included. Translation and clinical review are required before localization. Nothing was machine-translated for this cut."
	my.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	my.add_theme_font_size_override("font_size", 10)
	my.add_theme_color_override("font_color", Color("#8B98A8"))
	v.add_child(my)
	var note := Label.new()
	note.text = str(loc.get("notes", {}).get("en", ""))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 9)
	note.add_theme_color_override("font_color", Color("#66717F"))
	v.add_child(note)

func _build_subtitles() -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	head.add_child(EditorTheme.heading("Subtitles", 9, Color("#8B98A8")))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	_lang_option = OptionButton.new()
	_lang_option.add_item("English", 0)
	_lang_option.add_item("Burmese (pending)", 1)
	_lang_option.select(0 if _sub_lang == "en" else 1)
	_lang_option.custom_minimum_size = Vector2(132, 25)
	_lang_option.item_selected.connect(func(i):
		_sub_lang = "en" if i == 0 else "my"
		refresh()
	)
	head.add_child(_lang_option)
	var add := Button.new()
	add.text = "+ Add"
	add.custom_minimum_size = Vector2(54, 25)
	add.pressed.connect(func():
		subtitle_add_requested.emit(_sub_lang, current_time, minf(float(project.episode.get("duration_seconds", 10.0)), current_time + 2.0))
	)
	head.add_child(add)
	_body.add_child(head)

	_sub_box = VBoxContainer.new()
	_sub_box.add_theme_constant_override("separation", 4)
	_body.add_child(_sub_box)
	var subs: Array = project.storyboard.get("subtitles", {}).get(_sub_lang, [])
	if _sub_lang == "my" and subs.is_empty():
		var warn := PanelContainer.new()
		warn.add_theme_stylebox_override("panel", EditorTheme.padded(Color("#2B2116"), 4, 10, 8, Color("#5A4526"), 1))
		var wl := Label.new()
		wl.text = "Burmese subtitles are intentionally empty. Do not publish without a reviewed translation. The interface accepts Myanmar script but no unreviewed copy is pre-filled."
		wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		wl.add_theme_font_size_override("font_size", 10)
		wl.add_theme_color_override("font_color", Color("#E9C46A"))
		warn.add_child(wl)
		_body.add_child(warn)
		return
	if subs.is_empty():
		var empty := Label.new()
		empty.text = "No subtitles in this language."
		empty.add_theme_font_size_override("font_size", 10)
		empty.add_theme_color_override("font_color", Color("#66717F"))
		_sub_box.add_child(empty)
		return
	for i in range(subs.size()):
		var s: Dictionary = subs[i]
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", EditorTheme.padded(Color("#181E25"), 3, 6, 4, Color("#28303A"), 1))
		_sub_box.add_child(row)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 5)
		row.add_child(h)
		var start := _spin(float(s.get("start", 0.0)), 0.01, 0.0, 60.0)
		start.custom_minimum_size = Vector2(72, 24)
		start.prefix = "in "
		h.add_child(start)
		var end := _spin(float(s.get("end", 0.0)), 0.01, 0.0, 60.0)
		end.custom_minimum_size = Vector2(72, 24)
		end.prefix = "out "
		h.add_child(end)
		var text := LineEdit.new()
		text.text = str(s.get("text", ""))
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_theme_font_size_override("font_size", 11)
		if _sub_lang == "my":
			var myfont := ProjectData.load_font(str(project.episode.get("style", {}).get("font_myanmar", "")))
			if myfont != null:
				text.add_theme_font_override("font", myfont)
		h.add_child(text)
		var del := Button.new()
		del.text = "×"
		del.custom_minimum_size = Vector2(24, 24)
		del.add_theme_color_override("font_color", Color("#FF9B8A"))
		del.pressed.connect(func(): subtitle_delete_requested.emit(_sub_lang, i))
		h.add_child(del)
		var lang := _sub_lang
		start.value_changed.connect(func(v):
			if _updating: return
			subtitle_changed.emit(lang, i, "start", v)
		)
		end.value_changed.connect(func(v):
			if _updating: return
			subtitle_changed.emit(lang, i, "end", v)
		)
		text.text_changed.connect(func(t):
			if _updating: return
			subtitle_changed.emit(lang, i, "text", t)
		)

func _spin(value: float, step: float, minv: float, maxv: float) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = minv
	s.max_value = maxv
	s.step = step
	s.allow_greater = true
	s.set_value_no_signal(value)
	return s

func _scene_color(i: int) -> Color:
	return [Color("#FF6A45"), Color("#62AEDA"), Color("#72CE9B"), Color("#E9C46A"), Color("#B79CED"), Color("#E76F8A")][i % 6]
