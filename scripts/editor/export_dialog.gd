class_name ExportDialog
extends Window
## Export settings, progress and verification summary.

signal export_requested(options: Dictionary)
signal cancel_requested
signal revalidate_requested

var project = null
var running := false
var output_edit: LineEdit
var frames_edit: LineEdit
var crf_spin: SpinBox
var preset_opt: OptionButton
var bitrate_spin: SpinBox
var audio_check: CheckBox
var subs_check: CheckBox
var clean_check: CheckBox
var start_btn: Button
var cancel_btn: Button
var close_btn: Button
var progress_bar: ProgressBar
var phase_label: Label
var status_label: Label
var log_text: RichTextLabel
var summary_box: VBoxContainer
var checks_box: VBoxContainer
var _options: Dictionary = {}

func _ready() -> void:
	title = "Export episode"
	size = Vector2i(820, 700)
	min_size = Vector2i(720, 600)
	transient = true
	exclusive = false
	close_requested.connect(func():
		if running:
			status_label.text = "Export running — cancel first, or wait for it to finish."
			status_label.add_theme_color_override("font_color", Color("#E9C46A"))
		else:
			hide()
	)
	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 20)
	root.add_theme_constant_override("margin_right", 20)
	root.add_theme_constant_override("margin_top", 16)
	root.add_theme_constant_override("margin_bottom", 16)
	add_child(root)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 9)
	root.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	var title_lbl := Label.new()
	title_lbl.text = "EXPORT"
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", Color("#E8EDF3"))
	head.add_child(title_lbl)
	var sub := Label.new()
	sub.text = "Deterministic PNG frames → offline mix → H.264/AAC · −14 LUFS"
	sub.add_theme_font_size_override("font_size", 10)
	sub.add_theme_color_override("font_color", Color("#8B98A8"))
	head.add_child(sub)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var val := Button.new()
	val.text = "Revalidate"
	val.custom_minimum_size = Vector2(84, 28)
	val.pressed.connect(func(): revalidate_requested.emit())
	head.add_child(val)

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 470
	v.add_child(split)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	split.add_child(left)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(300, 0)
	right.add_theme_constant_override("separation", 6)
	split.add_child(right)

	left.add_child(EditorTheme.heading("Output", 9, Color("#8B98A8")))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	left.add_child(grid)
	output_edit = LineEdit.new()
	output_edit.custom_minimum_size = Vector2(0, 27)
	output_edit.tooltip_text = "Absolute path, or res:// path inside the project"
	_field(grid, "Video file", output_edit)
	frames_edit = LineEdit.new()
	frames_edit.custom_minimum_size = Vector2(0, 27)
	frames_edit.tooltip_text = "PNG sequence is written here. Existing frame_*.png files are cleared."
	_field(grid, "Frames dir", frames_edit)

	left.add_child(EditorTheme.heading("Encoding", 9, Color("#8B98A8")))
	var grid2 := GridContainer.new()
	grid2.columns = 2
	grid2.add_theme_constant_override("h_separation", 8)
	grid2.add_theme_constant_override("v_separation", 6)
	left.add_child(grid2)
	crf_spin = SpinBox.new()
	crf_spin.min_value = 10
	crf_spin.max_value = 32
	crf_spin.step = 1
	crf_spin.value = 18
	crf_spin.custom_minimum_size = Vector2(0, 26)
	_field(grid2, "H.264 CRF", crf_spin)
	preset_opt = OptionButton.new()
	for p in ["ultrafast", "superfast", "veryfast", "faster", "fast", "medium", "slow", "slower"]:
		preset_opt.add_item(p)
	preset_opt.select(5)
	_field(grid2, "Preset", preset_opt)
	bitrate_spin = SpinBox.new()
	bitrate_spin.min_value = 96
	bitrate_spin.max_value = 320
	bitrate_spin.step = 16
	bitrate_spin.value = 192
	bitrate_spin.suffix = " kbps"
	_field(grid2, "AAC bitrate", bitrate_spin)

	var opts := VBoxContainer.new()
	opts.add_theme_constant_override("separation", 3)
	left.add_child(opts)
	audio_check = CheckBox.new()
	audio_check.text = "Include mixed audio (48 kHz stereo)"
	audio_check.button_pressed = true
	opts.add_child(audio_check)
	subs_check = CheckBox.new()
	subs_check.text = "Burn English subtitles"
	subs_check.button_pressed = true
	opts.add_child(subs_check)
	clean_check = CheckBox.new()
	clean_check.text = "Delete PNG frames after a successful export"
	clean_check.button_pressed = false
	opts.add_child(clean_check)

	var fixed := PanelContainer.new()
	fixed.add_theme_stylebox_override("panel", EditorTheme.padded(Color("#181E25"), 4, 10, 8, Color("#28303A"), 1))
	left.add_child(fixed)
	var fv := VBoxContainer.new()
	fv.add_theme_constant_override("separation", 2)
	fixed.add_child(fv)
	var fl1 := Label.new()
	fl1.text = "FIXED OUTPUT FORMAT"
	fl1.add_theme_font_size_override("font_size", 8)
	fl1.add_theme_color_override("font_color", Color("#66717F"))
	fv.add_child(fl1)
	var fl2 := Label.new()
	fl2.text = "H.264 High · yuv420p · 30 fps · AAC-LC 48 kHz stereo\nTwo-pass loudness normalisation to −14 LUFS / true peak ≤ −1 dBTP"
	fl2.add_theme_font_size_override("font_size", 10)
	fl2.add_theme_color_override("font_color", Color("#C9D3DF"))
	fl2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fv.add_child(fl2)

	right.add_child(EditorTheme.heading("Preflight", 9, Color("#8B98A8")))
	summary_box = VBoxContainer.new()
	summary_box.add_theme_constant_override("separation", 2)
	right.add_child(summary_box)
	checks_box = VBoxContainer.new()
	checks_box.add_theme_constant_override("separation", 1)
	right.add_child(checks_box)

	right.add_child(EditorTheme.heading("Progress", 9, Color("#8B98A8")))
	phase_label = Label.new()
	phase_label.text = "Ready"
	phase_label.add_theme_font_size_override("font_size", 11)
	phase_label.add_theme_color_override("font_color", Color("#C9D3DF"))
	right.add_child(phase_label)
	progress_bar = ProgressBar.new()
	progress_bar.min_value = 0
	progress_bar.max_value = 100
	progress_bar.value = 0
	progress_bar.custom_minimum_size = Vector2(0, 20)
	progress_bar.show_percentage = true
	right.add_child(progress_bar)
	status_label = Label.new()
	status_label.text = ""
	status_label.add_theme_font_size_override("font_size", 10)
	status_label.add_theme_color_override("font_color", Color("#8B98A8"))
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(status_label)

	var log_panel := PanelContainer.new()
	log_panel.add_theme_stylebox_override("panel", EditorTheme.padded(Color("#0E1217"), 4, 8, 6, Color("#252C35"), 1))
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(log_panel)
	log_text = RichTextLabel.new()
	log_text.bbcode_enabled = false
	log_text.scroll_following = true
	log_text.add_theme_font_size_override("normal_font_size", 9)
	log_text.add_theme_color_override("default_color", Color("#9AA7B6"))
	log_text.custom_minimum_size = Vector2(0, 140)
	log_panel.add_child(log_text)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	v.add_child(bar)
	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(sp2)
	start_btn = Button.new()
	start_btn.text = "Start export"
	start_btn.custom_minimum_size = Vector2(120, 32)
	start_btn.pressed.connect(_on_start)
	bar.add_child(start_btn)
	cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(80, 32)
	cancel_btn.disabled = true
	cancel_btn.pressed.connect(func(): cancel_requested.emit())
	bar.add_child(cancel_btn)
	close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(72, 32)
	close_btn.pressed.connect(func():
		if not running:
			hide()
	)
	bar.add_child(close_btn)

func open_for(p_project, validation: Dictionary = {}) -> void:
	project = p_project
	var ex: Dictionary = project.episode.get("export", {})
	if output_edit.text.strip_edges().is_empty():
		output_edit.text = str(ex.get("video_path", "res://output/video.mp4"))
	if frames_edit.text.strip_edges().is_empty():
		frames_edit.text = str(ex.get("frames_dir", "res://output/frames"))
	crf_spin.value = int(ex.get("crf", 18))
	var preset := str(ex.get("preset", "medium"))
	var pi := 5
	for i in range(preset_opt.item_count):
		if preset_opt.get_item_text(i) == preset:
			pi = i
	preset_opt.select(pi)
	bitrate_spin.value = int(ex.get("audio_bitrate_kbps", 192))
	running = false
	start_btn.disabled = false
	cancel_btn.disabled = true
	progress_bar.value = 0
	phase_label.text = "Ready"
	status_label.text = ""
	log_text.clear()
	if validation.is_empty():
		validation = project.validate()
	_show_validation(validation)
	popup_centered()

func revalidate(validation: Dictionary) -> void:
	_show_validation(validation)

func _show_validation(validation: Dictionary) -> void:
	for c in summary_box.get_children():
		c.queue_free()
	for c in checks_box.get_children():
		c.queue_free()
	var errs: Array = validation.get("errors", [])
	var warns: Array = validation.get("warnings", [])
	var err_row := HBoxContainer.new()
	var ed := Label.new()
	ed.text = "%d error%s" % [errs.size(), "" if errs.size() == 1 else "s"]
	ed.add_theme_font_size_override("font_size", 10)
	ed.add_theme_color_override("font_color", Color("#FF9B8A") if errs.size() > 0 else Color("#72CE9B"))
	err_row.add_child(ed)
	var wd := Label.new()
	wd.text = "  ·  %d warning%s" % [warns.size(), "" if warns.size() == 1 else "s"]
	wd.add_theme_font_size_override("font_size", 10)
	wd.add_theme_color_override("font_color", Color("#E9C46A") if warns.size() > 0 else Color("#66717F"))
	err_row.add_child(wd)
	summary_box.add_child(err_row)
	var count := 0
	for e in errs:
		_validation_line("ERROR  " + str(e), Color("#FF9B8A"))
		count += 1
		if count >= 4:
			break
	for w in warns:
		if count >= 7:
			break
		_validation_line("WARN  " + str(w), Color("#E9C46A"))
		count += 1
	if count == 0:
		_validation_line("Project validates. Burmese localization warning may still apply to this cut.", Color("#72CE9B"))

func _validation_line(text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 9)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	checks_box.add_child(l)

func _field(grid: GridContainer, label_text: String, control: Control) -> void:
	var l := Label.new()
	l.text = label_text
	l.custom_minimum_size = Vector2(78, 0)
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", Color("#8B98A8"))
	grid.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(control)

func _on_start() -> void:
	if running:
		return
	if output_edit.text.strip_edges().is_empty():
		status_label.text = "Set an output path."
		return
	_options = {
		"video_path": output_edit.text.strip_edges(),
		"frames_dir": frames_edit.text.strip_edges(),
		"crf": int(crf_spin.value),
		"preset": preset_opt.get_item_text(preset_opt.selected),
		"audio_bitrate": int(bitrate_spin.value),
		"include_audio": audio_check.button_pressed,
		"include_subtitles": subs_check.button_pressed,
		"clean_frames": clean_check.button_pressed,
	}
	set_running(true)
	append_log("Starting export…")
	export_requested.emit(_options)

func set_running(on: bool) -> void:
	running = on
	start_btn.disabled = on
	cancel_btn.disabled = not on
	close_btn.disabled = on
	progress_bar.value = 0
	phase_label.text = "Preparing…" if on else "Ready"
	status_label.text = ""
	if on:
		log_text.clear()

func set_progress(phase: String, current: int, total: int, message: String) -> void:
	phase_label.text = message
	if total <= 0:
		progress_bar.value = 0
	else:
		progress_bar.value = float(current) / float(total) * 100.0
	if phase == "encode" or phase == "verify" or phase == "measure":
		progress_bar.value = 0.0
	summary_box.visible = false

func append_log(text: String) -> void:
	if log_text == null:
		return
	log_text.add_text(text + "\n")
	log_text.scroll_to_line(maxi(0, log_text.get_line_count() - 1))

func show_report(report: Dictionary) -> void:
	set_running(false)
	summary_box.visible = true
	var ok := bool(report.get("ok", false))
	status_label.text = ("EXPORT PASSED · %s" % _fmt_bytes(int(report.get("size_bytes", 0)))) if ok else ("EXPORT FAILED · " + str(report.get("error", "see checks")))
	status_label.add_theme_color_override("font_color", Color("#72CE9B") if ok else Color("#FF9B8A"))
	phase_label.text = "Complete" if ok else "Failed"
	progress_bar.value = 100.0 if ok else 0.0
	for c in checks_box.get_children():
		c.queue_free()
	for check in report.get("checks", []):
		if check is Dictionary:
			var passed := bool(check.get("ok", false))
			_validation_line(("PASS  " if passed else "FAIL  ") + str(check.get("label", "")) + "  ·  " + str(check.get("detail", "")), Color("#72CE9B") if passed else Color("#FF9B8A"))
	var probe: Dictionary = report.get("probe", {})
	var v: Dictionary = probe.get("video", {})
	var a: Dictionary = probe.get("audio", {})
	if not v.is_empty():
		append_log("Verified: %s×%s %s, %s frames, %.2fs" % [v.get("width", "?"), v.get("height", "?"), v.get("codec_name", "?"), v.get("nb_read_frames", "?"), float(v.get("duration", 0.0))])
	if not a.is_empty():
		append_log("Audio: %s, %s Hz, %s ch" % [a.get("codec_name", "?"), a.get("sample_rate", "?"), a.get("channels", "?")])
	var loud: Dictionary = report.get("loudness_output", {})
	if not loud.is_empty():
		append_log("Loudness: %s LUFS, true peak %s dBTP" % [loud.get("input_i", "?"), loud.get("input_tp", "?")])
	if not ok:
		for check in report.get("checks", []):
			if check is Dictionary and not bool(check.get("ok", false)) and str(check.get("severity", "")) == "error":
				append_log("Check failed: %s (%s)" % [check.get("label", ""), check.get("detail", "")])

func _fmt_bytes(b: int) -> String:
	return "%.1f MB" % (float(b) / (1024.0 * 1024.0))
