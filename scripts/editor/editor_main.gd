extends Control
## BodyFrame Motion Studio — editor shell.
##
## Owns the project document, the deterministic timeline engine, selection,
## undo history, playback transport and all dock wiring. Panels are views:
## they report intent, this controller mutates the document and decides when
## to rebuild the composition or re-evaluate the current frame.

const ExportManagerScript = preload("res://scripts/export/export_manager.gd")
const DEFAULT_PROJECT_DIR := "res://projects/salt_hypertension"
const VERSION := "1.0"

var project = null
var engine = null
var undo: UndoStack = UndoStack.new()

var current_time := 0.0
var playing := false
var loop_playback := true
var selection := ""
var dirty := false
var export_running := false

var preview: PreviewCanvas
var timeline: TimelinePanel
var inspector: InspectorPanel
var project_panel: ProjectPanel
var assets_panel: AssetsPanel
var storyboard_panel: StoryboardPanel
var audio_panel: AudioPanel
var audio_manager: StudioAudioManager
var export_dialog: ExportDialog
var export_manager = null

var _state_before: Dictionary = {}
var _coalesce_key := ""
var _coalesce_ms := 0
var _last_validation: Dictionary = {}

var _import_snapshot: Dictionary = {}
var _drag_snapshot: Dictionary = {}
var _drag_undo_done := false
var _drag_id := ""
var _drag_start := Vector2.ZERO
var _drag_moved := false

var _project_label: Label
var _time_label: Label
var _frame_label: Label
var _scene_label: Label
var _zoom_label: Label
var _status_label: Label
var _validation_label: Label
var _info_label: Label
var _play_btn: Button
var _undo_btn: Button
var _redo_btn: Button
var _loop_check: CheckBox

var _show_guides := true
var _show_path := true
var _show_grid := false
var _show_safe := false
var _show_subs := true

var _file_dialog: FileDialog
var _new_dialog: ConfirmationDialog
var _new_name: LineEdit
var _new_path: LineEdit
var _new_brand: LineEdit
var _new_topic: LineEdit
var _validation_dialog: AcceptDialog
var _message_dialog: AcceptDialog
var _help_dialog: AcceptDialog

func _ready() -> void:
	theme = EditorTheme.make()
	name = "BodyFrameMotionStudio"
	_build_ui()
	_build_dialogs()
	audio_manager = StudioAudioManager.new()
	audio_manager.name = "StudioAudio"
	add_child(audio_manager)
	set_process(true)
	_load_startup()

# ---------------------------------------------------------------------------
# UI construction
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.name = "StudioShell"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	root.add_child(_build_toolbar())

	var main_split := VSplitContainer.new()
	main_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_split.split_offset = 548
	main_split.add_theme_constant_override("separation", 4)
	main_split.resized.connect(func():
		if main_split.size.y > 200:
			main_split.split_offset = maxi(210, int(main_split.size.y) - 352)
	)
	root.add_child(main_split)

	var upper := HSplitContainer.new()
	upper.name = "Upper"
	upper.split_offset = 302
	main_split.add_child(upper)
	upper.resized.connect(func():
		if upper.size.x > 200:
			upper.split_offset = clampi(302, 220, int(upper.size.x) - 430)
	)

	# Left dock ---------------------------------------------------------
	var left_tabs := TabContainer.new()
	left_tabs.name = "LeftDock"
	left_tabs.custom_minimum_size = Vector2(270, 0)
	left_tabs.clip_tabs = false
	upper.add_child(left_tabs)
	project_panel = ProjectPanel.new()
	project_panel.name = "Elements"
	left_tabs.add_child(project_panel)
	assets_panel = AssetsPanel.new()
	assets_panel.name = "Assets"
	left_tabs.add_child(assets_panel)
	storyboard_panel = StoryboardPanel.new()
	storyboard_panel.name = "Storyboard"
	left_tabs.add_child(storyboard_panel)
	left_tabs.set_tab_title(0, "Elements")
	left_tabs.set_tab_title(1, "Assets")
	left_tabs.set_tab_title(2, "Storyboard")

	# Centre: preview + right inspector --------------------------------
	var inner := HSplitContainer.new()
	inner.name = "CentreDock"
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.split_offset = 900
	upper.add_child(inner)
	inner.resized.connect(func():
		if inner.size.x > 200:
			inner.split_offset = maxi(360, int(inner.size.x) - 356)
	)

	var preview_panel := PanelContainer.new()
	preview_panel.add_theme_stylebox_override("panel", EditorTheme.flat(Color("#0D1015"), 0, Color("#252C35"), 1))
	inner.add_child(preview_panel)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 0)
	preview_panel.add_child(pv)
	pv.add_child(_build_preview_header())
	preview = PreviewCanvas.new()
	preview.name = "Preview"
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pv.add_child(preview)

	var insp_panel := PanelContainer.new()
	insp_panel.custom_minimum_size = Vector2(340, 0)
	insp_panel.add_theme_stylebox_override("panel", EditorTheme.flat(EditorTheme.PANEL, 0, Color("#252C35"), 1))
	inner.add_child(insp_panel)
	var iv := VBoxContainer.new()
	iv.add_theme_constant_override("separation", 0)
	insp_panel.add_child(iv)
	var ihead := MarginContainer.new()
	ihead.add_theme_constant_override("margin_left", 12)
	ihead.add_theme_constant_override("margin_right", 10)
	ihead.add_theme_constant_override("margin_top", 8)
	ihead.add_theme_constant_override("margin_bottom", 7)
	var ih := HBoxContainer.new()
	ihead.add_child(ih)
	ih.add_child(EditorTheme.heading("Inspector", 11, Color("#E8EDF3")))
	var isp := Control.new()
	isp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ih.add_child(isp)
	var idl := Label.new()
	idl.text = "SELECTION"
	idl.add_theme_font_size_override("font_size", 9)
	idl.add_theme_color_override("font_color", Color("#5C6674"))
	ih.add_child(idl)
	iv.add_child(ihead)
	var isep := EditorTheme.separator()
	iv.add_child(isep)
	inspector = InspectorPanel.new()
	inspector.size_flags_vertical = Control.SIZE_EXPAND_FILL
	iv.add_child(inspector)

	# Bottom dock -------------------------------------------------------
	var bottom_tabs := TabContainer.new()
	bottom_tabs.name = "BottomDock"
	bottom_tabs.custom_minimum_size = Vector2(0, 230)
	main_split.add_child(bottom_tabs)
	timeline = TimelinePanel.new()
	timeline.name = "Timeline"
	bottom_tabs.add_child(timeline)
	audio_panel = AudioPanel.new()
	audio_panel.name = "Audio"
	bottom_tabs.add_child(audio_panel)
	bottom_tabs.set_tab_title(0, "Timeline")
	bottom_tabs.set_tab_title(1, "Audio · Cues · Fades")

	root.add_child(_build_status_bar())
	_connect_panels()

func _build_toolbar() -> Control:
	var panel := PanelContainer.new()
	panel.name = "Toolbar"
	panel.custom_minimum_size = Vector2(0, 50)
	panel.add_theme_stylebox_override("panel", EditorTheme.padded(Color("#171C23"), 0, 12, 6, Color("#2A323D"), 1))
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	panel.add_child(bar)

	var brand_box := VBoxContainer.new()
	brand_box.add_theme_constant_override("separation", 0)
	brand_box.custom_minimum_size = Vector2(116, 0)
	var brand := Label.new()
	brand.text = "BODYFRAME"
	brand.add_theme_font_size_override("font_size", 15)
	brand.add_theme_color_override("font_color", EditorTheme.ACCENT)
	brand_box.add_child(brand)
	var sub := Label.new()
	sub.text = "MOTION STUDIO  ·  " + VERSION
	sub.add_theme_font_size_override("font_size", 8)
	sub.add_theme_color_override("font_color", Color("#6B7684"))
	brand_box.add_child(sub)
	bar.add_child(brand_box)
	bar.add_child(_vsep())

	bar.add_child(_tool_button("New", "Create a new episode project", _new_project))
	bar.add_child(_tool_button("Open", "Open a project folder", _open_project))
	bar.add_child(_tool_button("Save", "Save episode.json and storyboard.json (Ctrl+S)", _on_save_pressed))
	bar.add_child(_vsep())

	_undo_btn = _tool_button("Undo", "Undo the last document edit (Ctrl+Z)", _undo_last)
	_redo_btn = _tool_button("Redo", "Redo (Ctrl+Shift+Z)", _redo_last)
	bar.add_child(_undo_btn)
	bar.add_child(_redo_btn)
	bar.add_child(_vsep())

	bar.add_child(_tool_button("|<", "Jump to the first frame", _go_start, 34))
	bar.add_child(_tool_button("<", "Previous frame (Left arrow)", func(): _step_frames(-1), 34))
	_play_btn = Button.new()
	_play_btn.text = "PLAY"
	_play_btn.tooltip_text = "Play / pause (Space)"
	_play_btn.custom_minimum_size = Vector2(68, 32)
	_play_btn.add_theme_color_override("font_color", EditorTheme.TEXT)
	_play_btn.pressed.connect(_toggle_play)
	bar.add_child(_play_btn)
	bar.add_child(_tool_button(">", "Next frame (Right arrow)", func(): _step_frames(1), 34))
	bar.add_child(_tool_button(">|", "Jump to the last frame", _go_end, 34))

	var readout := VBoxContainer.new()
	readout.add_theme_constant_override("separation", 0)
	readout.custom_minimum_size = Vector2(118, 0)
	_time_label = Label.new()
	_time_label.text = "00:00.00"
	_time_label.add_theme_font_size_override("font_size", 17)
	_time_label.add_theme_color_override("font_color", Color("#FFC7B8"))
	readout.add_child(_time_label)
	_frame_label = Label.new()
	_frame_label.text = "f 000 / 300"
	_frame_label.add_theme_font_size_override("font_size", 9)
	_frame_label.add_theme_color_override("font_color", Color("#7C8897"))
	readout.add_child(_frame_label)
	bar.add_child(readout)

	_loop_check = CheckBox.new()
	_loop_check.text = "Loop"
	_loop_check.button_pressed = true
	_loop_check.tooltip_text = "Loop preview playback"
	_loop_check.toggled.connect(func(on): loop_playback = on)
	bar.add_child(_loop_check)

	bar.add_child(_vsep())

	_project_label = Label.new()
	_project_label.text = "No project"
	_project_label.add_theme_font_size_override("font_size", 12)
	_project_label.add_theme_color_override("font_color", Color("#C9D3DF"))
	_project_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_project_label.clip_text = true
	_project_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(_project_label)

	bar.add_child(_tool_button("Validate", "Run project + font validation", _on_validate_pressed))
	var export_btn := Button.new()
	export_btn.text = "EXPORT MP4"
	export_btn.tooltip_text = "Render frames and encode H.264/AAC with FFmpeg"
	export_btn.custom_minimum_size = Vector2(108, 32)
	export_btn.add_theme_stylebox_override("normal", EditorTheme.padded(Color("#FF6A45"), 4, 12, 6))
	export_btn.add_theme_stylebox_override("hover", EditorTheme.padded(Color("#FF8262"), 4, 12, 6))
	export_btn.add_theme_stylebox_override("pressed", EditorTheme.padded(Color("#D9552F"), 4, 12, 6))
	export_btn.add_theme_color_override("font_color", Color("#1C0F0A"))
	export_btn.add_theme_color_override("font_hover_color", Color("#1C0F0A"))
	export_btn.pressed.connect(_open_export)
	bar.add_child(export_btn)
	bar.add_child(_tool_button("?", "Keyboard shortcuts and workflow", _show_help, 30))
	return panel

func _build_preview_header() -> Control:
	var head := PanelContainer.new()
	head.add_theme_stylebox_override("panel", EditorTheme.padded(Color("#151A20"), 0, 10, 4, Color("#232A33"), 1))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	head.add_child(h)
	h.add_child(EditorTheme.heading("Preview", 10, Color("#E8EDF3")))
	_scene_label = Label.new()
	_scene_label.text = "—"
	_scene_label.add_theme_font_size_override("font_size", 9)
	_scene_label.add_theme_color_override("font_color", EditorTheme.ACCENT)
	_scene_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scene_label.clip_text = true
	h.add_child(_scene_label)
	h.add_child(_overlay_check("Guides", _show_guides, func(on): _show_guides = on; _apply_overlays()))
	h.add_child(_overlay_check("Path", _show_path, func(on): _show_path = on; _apply_overlays()))
	h.add_child(_overlay_check("Grid", _show_grid, func(on): _show_grid = on; _apply_overlays()))
	h.add_child(_overlay_check("Safe", _show_safe, func(on): _show_safe = on; _apply_overlays()))
	h.add_child(_overlay_check("Subs", _show_subs, func(on): _show_subs = on; _apply_overlays()))
	h.add_child(_vsep())
	h.add_child(_tool_button("−", "Zoom out", func(): preview.set_view_zoom(preview.view_zoom / 1.2), 28))
	_zoom_label = Label.new()
	_zoom_label.text = "FIT"
	_zoom_label.custom_minimum_size = Vector2(46, 0)
	_zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zoom_label.add_theme_font_size_override("font_size", 9)
	_zoom_label.add_theme_color_override("font_color", Color("#8B98A8"))
	h.add_child(_zoom_label)
	h.add_child(_tool_button("+", "Zoom in", func(): preview.set_view_zoom(preview.view_zoom * 1.2), 28))
	h.add_child(_tool_button("Fit", "Fit the frame in the preview", func(): preview.reset_view(), 34))
	return head

func _build_status_bar() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 26)
	panel.add_theme_stylebox_override("panel", EditorTheme.padded(Color("#141920"), 0, 10, 3, Color("#2A323D"), 1))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	panel.add_child(h)
	_status_label = Label.new()
	_status_label.text = "Ready."
	_status_label.add_theme_font_size_override("font_size", 10)
	_status_label.add_theme_color_override("font_color", Color("#9AA7B6"))
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.clip_text = true
	h.add_child(_status_label)
	_validation_label = Label.new()
	_validation_label.add_theme_font_size_override("font_size", 10)
	_validation_label.add_theme_color_override("font_color", Color("#66717F"))
	h.add_child(_validation_label)
	_info_label = Label.new()
	_info_label.add_theme_font_size_override("font_size", 9)
	_info_label.add_theme_color_override("font_color", Color("#66717F"))
	h.add_child(_info_label)
	return panel

func _build_dialogs() -> void:
	export_dialog = ExportDialog.new()
	export_dialog.title = "Export Video"
	add_child(export_dialog)
	export_dialog.visible = false
	export_dialog.export_requested.connect(_on_export_requested)
	export_dialog.cancel_requested.connect(_on_export_cancel)
	export_dialog.revalidate_requested.connect(func(): export_dialog.revalidate(project.validate()))

	_file_dialog = FileDialog.new()
	_file_dialog.title = "Open project folder"
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.use_native_dialog = false
	_file_dialog.current_dir = ProjectSettings.globalize_path("res://projects")
	_file_dialog.dir_selected.connect(_on_open_dir_selected)
	add_child(_file_dialog)
	_file_dialog.visible = false

	_new_dialog = ConfirmationDialog.new()
	_new_dialog.title = "New Episode Project"
	_new_dialog.ok_button_text = "Create Project"
	_new_dialog.cancel_button_text = "Cancel"
	_new_dialog.min_size = Vector2i(560, 300)
	var nv := VBoxContainer.new()
	nv.add_theme_constant_override("separation", 8)
	var intro := Label.new()
	intro.text = "Creates episode.json + storyboard.json in the chosen folder. Sample content is never hard-coded in the engine."
	intro.add_theme_font_size_override("font_size", 10)
	intro.add_theme_color_override("font_color", Color("#8B98A8"))
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nv.add_child(intro)
	_new_name = _dialog_line(nv, "Episode name", "New Health Explainer")
	_new_path = _dialog_line(nv, "Project folder", "res://projects/new_episode")
	_new_brand = _dialog_line(nv, "Brand", "BodyFrame")
	_new_topic = _dialog_line(nv, "Topic (optional)", "")
	_new_dialog.add_child(nv)
	_new_dialog.confirmed.connect(_on_new_confirmed)
	add_child(_new_dialog)
	_new_dialog.visible = false

	_validation_dialog = AcceptDialog.new()
	_validation_dialog.title = "Project Validation"
	_validation_dialog.min_size = Vector2i(760, 460)
	if _validation_dialog.get_label() != null:
		_validation_dialog.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_validation_dialog.get_label().custom_minimum_size = Vector2(720, 0)
	add_child(_validation_dialog)
	_validation_dialog.visible = false

	_message_dialog = AcceptDialog.new()
	_message_dialog.title = "BodyFrame Motion Studio"
	_message_dialog.min_size = Vector2i(560, 220)
	if _message_dialog.get_label() != null:
		_message_dialog.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_message_dialog)
	_message_dialog.visible = false

	_help_dialog = AcceptDialog.new()
	_help_dialog.title = "Workflow & Shortcuts"
	_help_dialog.min_size = Vector2i(700, 500)
	if _help_dialog.get_label() != null:
		_help_dialog.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_help_dialog)
	_help_dialog.visible = false

func _dialog_line(parent: VBoxContainer, caption: String, value: String) -> LineEdit:
	var l := Label.new()
	l.text = caption
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", Color("#8B98A8"))
	parent.add_child(l)
	var e := LineEdit.new()
	e.text = value
	e.custom_minimum_size = Vector2(0, 30)
	parent.add_child(e)
	return e

func _tool_button(text: String, tip: String, cb: Callable, width: int = 0) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	if width > 0:
		b.custom_minimum_size = Vector2(width, 32)
	b.pressed.connect(cb)
	return b

func _overlay_check(text: String, on: bool, cb: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = on
	c.focus_mode = Control.FOCUS_NONE
	c.add_theme_font_size_override("font_size", 10)
	c.toggled.connect(cb)
	return c

func _vsep() -> Control:
	var c := ColorRect.new()
	c.color = Color("#2A323D")
	c.custom_minimum_size = Vector2(1, 26)
	return c

func _connect_panels() -> void:
	preview.element_pressed.connect(_on_preview_pressed)
	preview.element_dragged.connect(_on_preview_dragged)
	preview.element_released.connect(_on_preview_released)
	preview.background_pressed.connect(func(): _select_element(""))
	preview.view_changed.connect(func(z): _zoom_label.text = ("FIT" if absf(z - 1.0) < 0.001 else "%d%%" % int(round(z * 100.0))))

	timeline.time_changed.connect(_on_timeline_time)
	timeline.element_selected.connect(func(id): _select_element("" if id == "@camera" else id))
	timeline.key_add_requested.connect(_on_timeline_key_add)
	timeline.key_delete_requested.connect(_on_timeline_key_delete)
	timeline.key_drag_started.connect(_on_key_drag_started)
	timeline.key_drag_moved.connect(_on_key_drag_moved)
	timeline.key_drag_finished.connect(_on_key_drag_finished)
	timeline.status_message.connect(_status)

	inspector.element_field_changed.connect(_on_element_field_changed)
	inspector.camera_key_requested.connect(_on_camera_key_requested)
	inspector.key_add_requested.connect(_on_inspector_key_add)
	inspector.track_deleted.connect(_on_track_deleted)
	inspector.key_all_requested.connect(_on_key_all_requested)
	inspector.scene_changed.connect(_on_scene_changed)
	inspector.status_message.connect(_status)

	project_panel.element_selected.connect(_select_element)
	project_panel.scene_selected.connect(_on_scene_jump)
	project_panel.add_requested.connect(_on_add_element)
	project_panel.duplicate_requested.connect(_on_duplicate_element)
	project_panel.delete_requested.connect(_on_delete_element)
	project_panel.reorder_requested.connect(_on_reorder_element)
	project_panel.status_message.connect(_status)

	assets_panel.sticker_requested.connect(_on_sticker_requested)
	assets_panel.audio_requested.connect(_on_audio_requested)
	assets_panel.import_started.connect(func(): _import_snapshot = _snapshot_state())
	assets_panel.project_changed.connect(_on_asset_project_changed)
	assets_panel.status_message.connect(_status)

	storyboard_panel.jump_requested.connect(func(t): _pause(); _set_time(t))
	storyboard_panel.scene_field_changed.connect(_on_scene_field_changed)
	storyboard_panel.subtitle_changed.connect(_on_subtitle_changed)
	storyboard_panel.subtitle_add_requested.connect(_on_subtitle_add)
	storyboard_panel.subtitle_delete_requested.connect(_on_subtitle_delete)
	storyboard_panel.validate_requested.connect(_on_validate_pressed)
	storyboard_panel.status_message.connect(_status)

	audio_panel.track_changed.connect(_on_audio_track_changed)
	audio_panel.seek_requested.connect(_on_audio_seek)
	audio_panel.play_toggle_requested.connect(_toggle_play)
	audio_panel.status_message.connect(_status)

# ---------------------------------------------------------------------------
# Project lifecycle
# ---------------------------------------------------------------------------

func _load_startup() -> void:
	var requested := _startup_project_arg()
	var path := requested if not requested.is_empty() else DEFAULT_PROJECT_DIR
	var p := ProjectData.new()
	if p.load_from_dir(path):
		_apply_project(p)
		return
	var joined := "\n".join(p.errors)
	push_warning("Could not open %s: %s" % [path, joined])
	_message_dialog.dialog_text = "Could not open the project at %s.\n\n%s\n\nA blank project will be created instead." % [path, joined]
	_message_dialog.popup_centered()
	var fallback := ProjectData.new_project("res://projects/untitled_episode", "Untitled Episode", "BodyFrame", "Health explainer")
	_apply_project(fallback)
	dirty = true
	_update_title()

func _startup_project_arg() -> String:
	var args := OS.get_cmdline_args()
	args.append_array(OS.get_cmdline_user_args())
	for i in range(args.size()):
		var a := str(args[i])
		if a == "--project" and i + 1 < args.size():
			return str(args[i + 1])
		if a.begins_with("--project="):
			return a.substr("--project=".length())
	return ""

func _apply_project(p) -> void:
	project = p
	engine = TimelineEngine.new()
	engine.setup_from_project(project)
	selection = ""
	current_time = 0.0
	playing = false
	dirty = false
	undo.clear()
	_coalesce_key = ""
	_coalesce_ms = 0
	_state_before = _snapshot_state()
	preview.build(project, engine)
	preview.set_selected("")
	_apply_overlays()
	timeline.setup(project, engine, "")
	project_panel.setup(project)
	assets_panel.setup(project)
	storyboard_panel.setup(project)
	audio_manager.setup(project)
	audio_panel.setup(project, audio_manager)
	inspector.build(project, engine, "", 0.0)
	_set_time(0.0)
	_last_validation = project.validate()
	_update_validation_badge()
	_update_title()
	_update_undo_buttons()
	_update_transport_ui()
	_info_label.text = "%d×%d · %d fps · %d frames · %.2fs · canvas %s×%s" % [
		int(project.episode.get("width", 1920)), int(project.episode.get("height", 1080)),
		int(project.episode.get("fps", 30)), engine.frame_count(),
		float(project.episode.get("duration_seconds", 10.0)),
		int(project.episode.get("canvas", {}).get("width", 6000)), int(project.episode.get("canvas", {}).get("height", 3000)),
	]
	_status("Loaded %s — %d elements, %d tracks, %d audio tracks" % [
		project.project_dir.get_file(), project.storyboard.get("elements", []).size(),
		engine.all_tracks().size(), project.storyboard.get("audio", {}).get("tracks", []).size(),
	])

func _on_save_pressed() -> void:
	_save_project(false)

func _save_project(silent: bool) -> bool:
	if project == null:
		return false
	if project.project_dir.is_empty():
		_show_message("Save failed", "This project has no folder. Use New to create one.")
		return false
	_sync_tracks()
	if not project.save():
		_show_message("Save failed", "\n".join(project.errors))
		_status("Save failed — see dialog.", EditorTheme.RED)
		return false
	dirty = false
	_update_title()
	_update_validation_badge()
	if not silent:
		_status("Saved episode.json + storyboard.json to %s" % project.project_dir, EditorTheme.GREEN)
	return true

func _sync_tracks() -> void:
	if project == null or engine == null:
		return
	project.storyboard["tracks"] = engine.export_tracks_array()

func _snapshot_state() -> Dictionary:
	if project == null:
		return {}
	return {
		"episode": project.episode.duplicate(true),
		"storyboard": project.storyboard.duplicate(true),
	}

func _update_title() -> void:
	if project == null:
		return
	var nm := str(project.episode.get("project_name", "Untitled"))
	var dot := "  ●" if dirty else ""
	if _project_label != null:
		_project_label.text = nm + dot
	var title := "BodyFrame Motion Studio — %s%s" % [nm, dot]
	if get_window() != null:
		get_window().title = title

func _new_project() -> void:
	if export_running:
		_status("Wait for the export to finish before creating a project.", EditorTheme.RED)
		return
	_new_path.text = _unique_project_path("res://projects/new_episode")
	_new_dialog.popup_centered(Vector2i(580, 320))

func _unique_project_path(base: String) -> String:
	var candidate := base
	var n := 2
	while DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(candidate)):
		candidate = "%s_%d" % [base, n]
		n += 1
	return candidate

func _on_new_confirmed() -> void:
	var nm := _new_name.text.strip_edges()
	var path := _new_path.text.strip_edges()
	if nm.is_empty():
		_show_message("Project name required", "Give the new episode a name.")
		return
	if path.is_empty():
		path = "res://projects/untitled_episode"
	var p := ProjectData.new_project(path, nm, _new_brand.text.strip_edges(), _new_topic.text.strip_edges())
	_apply_project(p)
	_status("Created %s" % path, EditorTheme.GREEN)

func _open_project() -> void:
	if export_running:
		_status("Wait for the export to finish before opening another project.", EditorTheme.RED)
		return
	_file_dialog.current_dir = ProjectSettings.globalize_path("res://projects")
	_file_dialog.popup_centered(Vector2i(880, 620))

func _on_open_dir_selected(dir_path: String) -> void:
	_apply_project_from_disk(dir_path)

func _apply_project_from_disk(dir_path: String) -> void:
	var p := ProjectData.new()
	if not p.load_from_dir(dir_path):
		_show_message("Could not open project", "\n".join(p.errors))
		_status("Open failed — see dialog.", EditorTheme.RED)
		return
	_apply_project(p)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if project != null and dirty:
			_save_project(true)
		get_tree().quit()

func _show_message(title: String, text: String) -> void:
	_message_dialog.title = title
	_message_dialog.dialog_text = text
	_message_dialog.popup_centered()

func _show_help() -> void:
	_help_dialog.dialog_text = """BODYFRAME MOTION STUDIO — QUICK WORKFLOW

1. Select an element in Elements (left) or click it in the preview.
2. Move the playhead on the Timeline, then edit values in the Inspector.
3. Press "+ Key" in the Animation section, or double-click a track row.
4. Drag keyframes horizontally to retime them. Del removes the selected key.
5. Camera keys live on @camera tracks; select nothing to see camera controls.
6. Audio tab: mute/solo, gain, fades and cues. Offline export always mixes
   from project data, so preview silence on a dummy device is harmless.
7. Validate, then EXPORT MP4. Frames render through the same deterministic
   composition stage used by the preview.

SHORTCUTS
  Space            Play / pause
  Left / Right     Previous / next frame
  Shift+Left/Right 10 frames
  Home / End       First / last frame
  Ctrl+S           Save project
  Ctrl+Z           Undo
  Ctrl+Shift+Z/Y   Redo
  Ctrl+D           Duplicate selected element
  Delete           Delete selected keyframe, else selected element

DETERMINISM
  evaluate_at_time(t) uses only project JSON + t. Nothing accumulates.
  Export writes a PNG sequence, mixes audio offline, then calls FFmpeg.
"""
	_help_dialog.popup_centered(Vector2i(720, 540))

# ---------------------------------------------------------------------------
# Undo / redo
# ---------------------------------------------------------------------------

func _coalesce_check(key: String) -> bool:
	var now := Time.get_ticks_msec()
	if key.is_empty():
		_coalesce_key = ""
		return false
	if key == _coalesce_key and now - _coalesce_ms < 1500:
		_coalesce_ms = now
		return true
	_coalesce_key = key
	_coalesce_ms = now
	return false

## Snapshot before a mutation that will happen after this call.
func _begin_edit(description: String, coalesce_key: String = "") -> void:
	if not _coalesce_check(coalesce_key):
		undo.push_snapshot(_state_before, description)

## Snapshot for a mutation a panel has already applied to shared data.
func _commit_edit(description: String, coalesce_key: String = "") -> void:
	if not _coalesce_check(coalesce_key):
		undo.push_snapshot(_state_before, description)
	_end_edit()

func _end_edit() -> void:
	_state_before = _snapshot_state()
	dirty = true
	_update_undo_buttons()
	_update_title()

func _undo_last() -> void:
	if not undo.can_undo():
		return
	var entry: Dictionary = undo.undo(project.episode, project.storyboard)
	if entry.is_empty():
		return
	_restore_snapshot(entry, "Undo")
	_status("Undo: %s" % undo.redo_description(), EditorTheme.YELLOW)

func _redo_last() -> void:
	if not undo.can_redo():
		return
	var entry: Dictionary = undo.redo(project.episode, project.storyboard)
	if entry.is_empty():
		return
	_restore_snapshot(entry, "Redo")
	_status("Redo: %s" % undo.undo_description(), EditorTheme.YELLOW)

func _restore_snapshot(entry: Dictionary, verb: String) -> void:
	_pause()
	project.episode = entry.get("episode", {}).duplicate(true)
	project.storyboard = entry.get("storyboard", {}).duplicate(true)
	engine.setup_from_project(project)
	scene_refresh()
	preview.build(project, engine)
	_apply_overlays()
	var keep := selection
	if not keep.is_empty() and project.element_by_id(keep).is_empty():
		keep = ""
	selection = keep
	preview.set_selected(selection)
	timeline.setup(project, engine, selection)
	project_panel.setup(project)
	project_panel.set_selected(selection)
	storyboard_panel.setup(project)
	audio_manager.setup(project)
	audio_panel.setup(project, audio_manager)
	inspector.build(project, engine, selection, current_time)
	_set_time(current_time)
	_state_before = _snapshot_state()
	_coalesce_key = ""
	dirty = true
	_last_validation = project.validate()
	_update_validation_badge()
	_update_undo_buttons()
	_update_title()

func _update_undo_buttons() -> void:
	if _undo_btn != null:
		_undo_btn.disabled = not undo.can_undo()
		_undo_btn.tooltip_text = "Undo: " + undo.undo_description() if undo.can_undo() else "Nothing to undo"
	if _redo_btn != null:
		_redo_btn.disabled = not undo.can_redo()
		_redo_btn.tooltip_text = "Redo: " + undo.redo_description() if undo.can_redo() else "Nothing to redo"

# ---------------------------------------------------------------------------
# Simulation / transport
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not playing or engine == null:
		return
	var dur := float(engine.duration)
	var t := current_time + minf(delta, 0.1)
	if t >= dur - 0.00001:
		if loop_playback:
			t = fmod(t, dur)
		else:
			t = dur
			_set_time(t)
			_pause()
			_status("Reached the end of the episode.")
			return
	_set_time(t)
	if audio_manager != null:
		audio_manager.update(current_time, true)

func _set_time(t: float) -> void:
	if engine == null:
		return
	current_time = clampf(t, 0.0, float(engine.duration))
	if preview != null:
		preview.set_time(current_time)
	if timeline != null:
		timeline.set_time(current_time)
	if audio_panel != null:
		audio_panel.update_time(current_time, playing)
	_update_transport_ui()

func _on_timeline_time(t: float) -> void:
	if playing:
		_pause()
	_set_time(t)
	if audio_manager != null:
		audio_manager.seek(current_time, false)

func _toggle_play() -> void:
	if export_running or project == null:
		return
	if playing:
		_pause()
		return
	if current_time >= float(engine.duration) - 0.0001:
		_set_time(0.0)
	playing = true
	if audio_manager != null:
		audio_manager.toggle_play(current_time, true)
	_status("Playing — evaluated from project data each frame.")
	_update_transport_ui()

func _pause() -> void:
	if not playing:
		return
	playing = false
	if audio_manager != null:
		audio_manager.toggle_play(current_time, false)
	_update_transport_ui()

func _step_frames(n: int) -> void:
	if engine == null:
		return
	if playing:
		_pause()
	var f: int = int(engine.frame_for_time(current_time)) + n
	f = clampi(f, 0, engine.max_frame())
	_set_time(engine.time_for_frame(f))
	if audio_manager != null:
		audio_manager.seek(current_time, false)

func _go_start() -> void:
	_pause()
	_set_time(0.0)
	if audio_manager != null:
		audio_manager.seek(0.0, false)

func _go_end() -> void:
	_pause()
	_set_time(float(engine.duration))
	if audio_manager != null:
		audio_manager.seek(current_time, false)

func _update_transport_ui() -> void:
	if engine == null:
		return
	var frames: int = int(engine.frame_count())
	var maxf: int = int(engine.max_frame())
	var frame: int = int(engine.frame_for_time(current_time)) if current_time < float(engine.duration) else maxf
	if _time_label != null:
		var mins := int(floor(current_time / 60.0))
		var secs := fmod(current_time, 60.0)
		_time_label.text = "%02d:%05.2f" % [mins, secs]
	if _frame_label != null:
		_frame_label.text = "f %03d / %d" % [frame, frames]
	if _play_btn != null:
		_play_btn.text = "PAUSE" if playing else "PLAY"
		_play_btn.add_theme_color_override("font_color", EditorTheme.ACCENT if playing else EditorTheme.TEXT)
	if _scene_label != null:
		var scn: Dictionary = engine.scene_at(current_time)
		var idx := 0
		var scenes: Array = engine.scenes
		for i in range(scenes.size()):
			if scenes[i] == scn:
				idx = i
				break
		_scene_label.text = "SCENE %02d  ·  %s" % [idx + 1, str(scn.get("name", "—")).to_upper()]

func _apply_overlays() -> void:
	if preview == null or preview.stage == null:
		return
	preview.set_overlays(_show_guides, _show_path, _show_grid, _show_safe)
	preview.stage.show_subtitles = _show_subs
	preview.set_time(current_time)

func _status(text: String, color: Color = Color("#9AA7B6")) -> void:
	if _status_label == null:
		return
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", color)

# ---------------------------------------------------------------------------
# Selection
# ---------------------------------------------------------------------------

func _select_element(id: String) -> void:
	if project == null:
		return
	if not id.is_empty() and project.element_by_id(id).is_empty():
		id = ""
	selection = id
	if preview != null:
		preview.set_selected(id)
	if timeline != null:
		timeline.set_selected(id)
	if project_panel != null:
		project_panel.set_selected(id)
	if inspector != null:
		inspector.build(project, engine, id, current_time)
	if not id.is_empty():
		var elem: Dictionary = project.element_by_id(id)
		_status("Selected %s · %s" % [str(elem.get("name", id)), str(elem.get("type", ""))])

func _on_scene_jump(_scene_id: String, start: float) -> void:
	_pause()
	_set_time(start)

# ---------------------------------------------------------------------------
# Preview direct manipulation
# ---------------------------------------------------------------------------

func _on_preview_pressed(id: String) -> void:
	_select_element(id)
	_drag_id = id
	_drag_moved = false
	_drag_undo_done = false
	_drag_snapshot = _snapshot_state()
	var elem: Dictionary = project.element_by_id(id)
	_drag_start = Vector2(float(elem.get("x", 0.0)), float(elem.get("y", 0.0)))
	if engine.has_track(id, "position"):
		_status("Position is animated on '%s' — retime its motion keys instead of dragging." % id, EditorTheme.YELLOW)

func _on_preview_dragged(id: String, world_delta: Vector2) -> void:
	if project == null or id.is_empty():
		return
	var elem: Dictionary = project.element_by_id(id)
	if elem.is_empty():
		return
	if engine.has_track(id, "position"):
		return
	if not _drag_undo_done:
		undo.push_snapshot(_drag_snapshot, "Move " + str(elem.get("name", id)))
		_drag_undo_done = true
	elem["x"] = _drag_start.x + world_delta.x
	elem["y"] = _drag_start.y + world_delta.y
	_drag_moved = true
	_state_before = _snapshot_state()
	dirty = true
	_update_title()
	preview.set_time(current_time)
	_status("Move %s → %.0f, %.0f" % [str(elem.get("name", id)), float(elem["x"]), float(elem["y"])])

func _on_preview_released(id: String) -> void:
	if _drag_moved:
		_update_undo_buttons()
		inspector.build(project, engine, selection, current_time)
		_status("Moved %s. Snap: use the inspector for exact values." % id)
	_drag_id = ""
	_drag_moved = false
	_drag_undo_done = false

# ---------------------------------------------------------------------------
# Inspector edits
# ---------------------------------------------------------------------------

func _on_element_field_changed(id: String, field: String, value: Variant, structural: bool) -> void:
	if project == null:
		return
	# The inspector has already written the value into the element dictionary.
	_commit_edit("Edit %s · %s" % [str(project.element_by_id(id).get("name", id)), field], id + "|" + field)
	if field == "name":
		if project_panel != null:
			project_panel.update_element_label(id, str(value))
	if structural:
		_rebuild_stage()
		timeline.refresh()
		project_panel.refresh()
		project_panel.set_selected(selection)
		storyboard_panel.refresh()
	else:
		preview.set_time(current_time)
		if field == "hidden" or field == "z":
			timeline.refresh()
	if field in ["hidden", "z", "locked"]:
		project_panel.refresh()
		project_panel.set_selected(selection)
	_status("Edited %s · %s" % [str(project.element_by_id(id).get("name", id)), field])

func _rebuild_stage() -> void:
	if preview == null:
		return
	preview.build(project, engine)
	preview.set_selected(selection)
	_apply_overlays()
	preview.set_time(current_time)

func _on_camera_key_requested(property: String, value: Variant) -> void:
	if engine == null:
		return
	_begin_edit("Camera key · " + property, "@camera|" + property)
	_add_key("@camera", property, current_time, value)
	_end_edit()
	timeline.refresh()
	preview.set_time(current_time)
	_status("Camera %s key at %.2fs (f%d)" % [property, current_time, engine.frame_for_time(current_time)], EditorTheme.GREEN)

func _on_inspector_key_add(element_id: String, property: String) -> void:
	_add_key_for(element_id, property, current_time, true)

func _on_timeline_key_add(element_id: String, property: String, time: float) -> void:
	if playing:
		_pause()
	_set_time(time)
	_add_key_for(element_id, property, time, false)

func _add_key_for(element_id: String, property: String, time: float, rebuild_inspector: bool) -> void:
	_begin_edit("Add key · %s · %s" % [element_id, property], "key|" + element_id + "|" + property)
	_add_key(element_id, property, time, null)
	_end_edit()
	timeline.refresh()
	preview.set_time(current_time)
	if rebuild_inspector:
		inspector.build(project, engine, selection, current_time)
	_status("Key set · %s · %s @ %.2fs" % [element_id, property, time], EditorTheme.GREEN)

func _add_key(element_id: String, property: String, time: float, value: Variant) -> AnimationTrack:
	var tr: AnimationTrack = engine.get_track(element_id, property)
	if tr == null:
		tr = engine.ensure_track(element_id, property)
	var v = value if value != null else _property_value(element_id, property, time)
	for k in tr.keys.duplicate():
		if absf(float(k.time) - time) < 0.0006:
			tr.keys.erase(k)
	var easing := "cubic_in_out"
	if element_id == TimelineEngine.CAMERA_ID:
		easing = str(project.episode.get("camera", {}).get("default_easing", "cubic_in_out"))
	var kd := KeyframeData.new(time, _json_value(v), easing)
	tr.keys.append(kd)
	tr._sort()
	if tr.kind == "auto" or tr.kind.is_empty():
		tr.kind = _kind_for_value(v)
	return tr

func _on_timeline_key_delete() -> void:
	_begin_edit("Delete keyframe")
	var removed: bool = timeline.delete_selected_key()
	if removed:
		_end_edit()
		timeline.refresh()
		preview.set_time(current_time)
		inspector.build(project, engine, selection, current_time)
		_status("Deleted keyframe.", EditorTheme.YELLOW)
	else:
		_coalesce_key = ""

func _on_key_drag_started() -> void:
	_drag_snapshot = _snapshot_state()
	_drag_undo_done = true

func _on_key_drag_moved() -> void:
	preview.set_time(current_time)

func _on_key_drag_finished() -> void:
	undo.push_snapshot(_drag_snapshot, "Move keyframe")
	_state_before = _snapshot_state()
	_coalesce_key = ""
	dirty = true
	_update_undo_buttons()
	_update_title()
	timeline.refresh()
	preview.set_time(current_time)

func _on_track_deleted(element_id: String, property: String) -> void:
	_begin_edit("Delete track · %s · %s" % [element_id, property])
	engine.remove_track(element_id, property)
	_end_edit()
	timeline.refresh()
	preview.set_time(current_time)
	inspector.build(project, engine, selection, current_time)
	_status("Removed the %s track from %s." % [property, element_id], EditorTheme.YELLOW)

func _on_key_all_requested(element_id: String) -> void:
	var props := ["position", "scale", "rotation", "opacity"]
	_begin_edit("Key transform + opacity · " + element_id, "keyall|" + element_id)
	for p in props:
		_add_key(element_id, p, current_time, null)
	_end_edit()
	timeline.refresh()
	preview.set_time(current_time)
	inspector.build(project, engine, selection, current_time)
	_status("Keyed transform + opacity at %.2fs." % current_time, EditorTheme.GREEN)

func _on_scene_changed(element_id: String, scene_id: String) -> void:
	_begin_edit("Assign scene · " + element_id)
	var elem: Dictionary = project.element_by_id(element_id)
	if elem.is_empty():
		_coalesce_key = ""
		return
	elem["scene"] = scene_id
	_end_edit()
	project_panel.refresh()
	project_panel.set_selected(selection)
	timeline.refresh()
	_status("Moved %s to scene %s." % [element_id, scene_id])

func _property_value(element_id: String, property: String, time: float):
	if element_id == TimelineEngine.CAMERA_ID:
		var cam: Dictionary = engine.evaluate_camera(time)
		match property:
			"position":
				var cp: Vector2 = cam.get("position", Vector2.ZERO)
				return [cp.x, cp.y]
			_:
				return float(cam.get(property, 0.0))
	var state: Dictionary = engine.evaluate_at_time(time).get("elements", {})
	var st: Dictionary = state.get(element_id, {})
	if st.has(property):
		return _json_value(st[property])
	var e: Dictionary = project.element_by_id(element_id)
	match property:
		"position":
			return [float(e.get("x", 0.0)), float(e.get("y", 0.0))]
		"scale":
			var sc = e.get("scale", [1.0, 1.0])
			return sc if sc is Array else [1.0, 1.0]
		"rotation":
			return float(e.get("rotation", 0.0))
		"opacity":
			return float(e.get("opacity", 1.0))
		"width":
			return float(e.get("width", 100.0))
		"height":
			return float(e.get("height", 100.0))
		"text_size":
			return float(e.get("font_size", 64.0))
		"outline_width":
			return float(e.get("outline_width", 10.0))
		"label_opacity":
			return float(e.get("label_opacity", 1.0))
		"color":
			return str(e.get("color", project.palette_color("text", Color("#263746")).to_html(false)))
		"fill":
			return str(e.get("fill", project.palette_color("accent", Color("#FF5A36")).to_html(false)))
		_:
			return e.get(property, 0.0)

func _kind_for_value(v: Variant) -> String:
	if v is Array:
		return "color" if v.size() >= 3 else "vector"
	if v is Color:
		return "color"
	if v is String and str(v).begins_with("#"):
		return "color"
	if v is float or v is int:
		return "number"
	return "auto"

func _json_value(v: Variant) -> Variant:
	if v is Vector2:
		return [v.x, v.y]
	if v is Color:
		return "#" + (v as Color).to_html(false)
	if v is Array:
		var out: Array = []
		for item in v:
			out.append(_json_value(item))
		return out
	return v

# ---------------------------------------------------------------------------
# Element CRUD
# ---------------------------------------------------------------------------

func _element_center() -> Vector2:
	if preview != null and preview.stage != null:
		var cam: Dictionary = preview.stage.current_camera
		return cam.get("position", Vector2(3000, 1500))
	return Vector2(3000, 1500)

func _next_z() -> int:
	var maxz := -100
	for e in project.storyboard.get("elements", []):
		if e is Dictionary:
			maxz = maxi(maxz, int(e.get("z", 0)))
	return maxz + 1

func _scene_id_at(t: float) -> String:
	var scn: Dictionary = engine.scene_at(t)
	return str(scn.get("id", "scene_01"))

func _unique_id(base: String) -> String:
	var clean := base.to_snake_case()
	if clean.is_empty():
		clean = "element"
	var candidate := clean
	var n := 2
	var used := {}
	for e in project.storyboard.get("elements", []):
		if e is Dictionary:
			used[str(e.get("id", ""))] = true
	while used.has(candidate):
		candidate = "%s_%d" % [clean, n]
		n += 1
	return candidate

func _on_add_element(type: String) -> void:
	if project == null:
		return
	_begin_edit("Add " + type + " element")
	var elem := _make_element(type)
	project.add_element(elem)
	_end_edit()
	_rebuild_stage()
	timeline.refresh()
	project_panel.refresh()
	storyboard_panel.refresh()
	_select_element(str(elem["id"]))
	_status("Added %s. Adjust it in the Inspector, then key it." % str(elem["id"]), EditorTheme.GREEN)

func _make_element(type: String) -> Dictionary:
	var centre := _element_center()
	var palette: Dictionary = project.episode.get("palette", {})
	var z := _next_z()
	var id := _unique_id(type)
	var base := {
		"id": id, "type": type, "name": "New " + type.replace("_", " "),
		"scene": _scene_id_at(current_time),
		"x": centre.x, "y": centre.y, "width": 420.0, "height": 240.0,
		"rotation": 0.0, "scale": [1.0, 1.0], "opacity": 1.0, "z": z,
		"locked": false, "hidden": false,
	}
	var text_col := str(palette.get("text", "#263746"))
	var accent := str(palette.get("accent", "#FF5A36"))
	match type:
		"text":
			base["width"] = 900.0
			base["height"] = 200.0
			base.merge({
				"text": "NEW HEADLINE", "font_size": 76, "font_weight": "bold",
				"color": text_col, "align": "center", "valign": "center",
			}, true)
		"shape":
			base["width"] = 360.0
			base["height"] = 360.0
			base.merge({"shape": "ellipse", "fill": accent, "border_color": "#FFFFFF", "border_width": 6, "shadow": true}, true)
		"sticker":
			base["width"] = 420.0
			base["height"] = 420.0
			base.merge({"asset": "", "outline_width": 12}, true)
		"arrow":
			base["width"] = 460.0
			base["height"] = 260.0
			base.merge({
				"from": [0.35, 0.3], "to": [-0.2, -0.3], "bend": -0.08,
				"label": "LABEL", "label_offset": [0.05, 0.47], "label_size": 20,
				"label_width": 260, "label_height": 40, "stroke": 4, "head_size": 18,
				"hand_drawn": true, "color": accent,
			}, true)
		"chart":
			base["width"] = 500.0
			base["height"] = 360.0
			base.merge({
				"chart_type": "bar", "title": "CHART TITLE",
				"values": [["A", 45], ["B", 72]], "max_value": 100,
				"show_values": true, "axes": true, "caption": "",
				"label_size": 21, "title_size": 24, "caption_size": 15,
			}, true)
		"character":
			base["width"] = 360.0
			base["height"] = 600.0
			base.merge({"mode": "torso", "water_level": 0.0, "sodium_count": 6, "label": "SIMPLIFIED BODY", "label_size": 19}, true)
		"blood_vessel":
			base["width"] = 900.0
			base["height"] = 440.0
			base.merge({"flow": 0.0, "bulge": 0.0, "flow_speed": 0.085, "cell_count": 18}, true)
		"pressure_gauge":
			base["width"] = 480.0
			base["height"] = 520.0
			base.merge({"value": 0.4, "title": "", "caption": "ILLUSTRATIVE INDICATOR", "card": true}, true)
	return base

func _on_duplicate_element() -> void:
	if selection.is_empty():
		_status("Select an element to duplicate.", EditorTheme.YELLOW)
		return
	var src: Dictionary = project.element_by_id(selection)
	if src.is_empty():
		return
	_begin_edit("Duplicate " + selection)
	var copy: Dictionary = src.duplicate(true)
	var new_id := _unique_id(selection + "_copy")
	copy["id"] = new_id
	copy["name"] = str(src.get("name", selection)) + " copy"
	copy["x"] = float(src.get("x", 0.0)) + 80.0
	copy["y"] = float(src.get("y", 0.0)) + 80.0
	copy["z"] = _next_z()
	project.add_element(copy)
	for tr in engine.get_tracks_for(selection):
		var nt: AnimationTrack = engine.ensure_track(new_id, tr.property)
		nt.kind = tr.kind
		nt.muted = tr.muted
		for k in tr.keys:
			nt.keys.append(k.duplicate_key())
		nt._sort()
	_end_edit()
	_rebuild_stage()
	timeline.refresh()
	project_panel.refresh()
	_select_element(new_id)
	_status("Duplicated as %s (animation copied)." % new_id, EditorTheme.GREEN)

func _on_delete_element() -> void:
	if selection.is_empty():
		_status("Select an element to delete.", EditorTheme.YELLOW)
		return
	var elem: Dictionary = project.element_by_id(selection)
	if elem.is_empty():
		return
	var nm := str(elem.get("name", selection))
	_begin_edit("Delete " + nm)
	engine.remove_tracks_for(selection)
	project.remove_element(selection)
	_end_edit()
	selection = ""
	_rebuild_stage()
	timeline.refresh()
	project_panel.refresh()
	storyboard_panel.refresh()
	_select_element("")
	_status("Deleted %s." % nm, EditorTheme.YELLOW)

func _on_reorder_element(delta: int) -> void:
	if selection.is_empty():
		return
	var elem: Dictionary = project.element_by_id(selection)
	if elem.is_empty():
		return
	_begin_edit("Reorder " + selection)
	elem["z"] = int(elem.get("z", 0)) + delta
	_end_edit()
	_rebuild_stage()
	project_panel.refresh()
	project_panel.set_selected(selection)
	inspector.build(project, engine, selection, current_time)
	_status("z-index → %d" % int(elem["z"]))

# ---------------------------------------------------------------------------
# Assets
# ---------------------------------------------------------------------------

func _on_sticker_requested(asset_path: String) -> void:
	if project == null:
		return
	if asset_path.is_empty():
		return
	_begin_edit("Add sticker · " + asset_path.get_file())
	var id := _unique_id(asset_path.get_file().get_basename())
	var centre := _element_center()
	var w := 420.0
	var h := 420.0
	var abs_path: String = str(project.resolve_asset(asset_path))
	if FileAccess.file_exists(abs_path):
		var img := Image.load_from_file(abs_path)
		if img != null and img.get_width() > 0:
			var s := minf(520.0 / float(img.get_width()), 520.0 / float(img.get_height()))
			w = float(img.get_width()) * maxf(0.05, s)
			h = float(img.get_height()) * maxf(0.05, s)
	var elem := {
		"id": id, "type": "sticker", "name": asset_path.get_file().get_basename().replace("_", " ").capitalize(),
		"scene": _scene_id_at(current_time), "x": centre.x, "y": centre.y,
		"width": w, "height": h, "rotation": 0.0, "scale": [1.0, 1.0],
		"opacity": 1.0, "z": _next_z(), "locked": false, "hidden": false,
		"asset": asset_path, "outline_width": int(project.style_value("sticker_outline_px", 10)),
	}
	project.add_element(elem)
	_end_edit()
	_rebuild_stage()
	timeline.refresh()
	project_panel.refresh()
	_select_element(id)
	_status("Added sticker %s." % asset_path.get_file(), EditorTheme.GREEN)

func _on_audio_requested(asset_path: String) -> void:
	if project == null or asset_path.is_empty():
		return
	_begin_edit("Add audio · " + asset_path.get_file())
	var abs_path: String = str(project.resolve_asset(asset_path))
	var length := 5.0
	if FileAccess.file_exists(abs_path):
		var stream := AudioStreamWAV.load_from_file(abs_path)
		if stream != null and stream.get_length() > 0.0:
			length = stream.get_length()
	var remaining := maxf(0.25, float(engine.duration) - current_time)
	length = minf(length, remaining)
	var base := asset_path.get_file().get_basename()
	var kind := "sfx"
	var low := base.to_lower()
	if low.contains("music") or low.contains("bed") or low.contains("theme"):
		kind = "music"
	elif low.contains("narration") or low.contains("voice") or low.contains("vo"):
		kind = "narration"
	var tracks: Array = project.storyboard.get("audio", {}).get("tracks", [])
	var used := {}
	for t in tracks:
		if t is Dictionary:
			used[str(t.get("id", ""))] = true
	var id := base.to_snake_case()
	var n := 2
	while used.has(id):
		id = "%s_%d" % [base.to_snake_case(), n]
		n += 1
	tracks.append({
		"id": id, "name": base.replace("_", " ").capitalize(), "type": kind,
		"file": asset_path, "start": engine.quantize_time(current_time),
		"duration": snappedf(length, 0.001), "gain": 0.8,
		"fade_in": 0.0, "fade_out": 0.0, "mute": false, "solo": false,
		"cues": [],
	})
	project.storyboard["audio"]["tracks"] = tracks
	_end_edit()
	audio_manager.setup(project)
	audio_panel.setup(project, audio_manager)
	_status("Added audio '%s' at %.2fs (%.2fs)." % [id, current_time, length], EditorTheme.GREEN)

func _on_asset_project_changed(description: String) -> void:
	if not _import_snapshot.is_empty():
		undo.push_snapshot(_import_snapshot, description)
		_import_snapshot = {}
	_state_before = _snapshot_state()
	_coalesce_key = ""
	dirty = true
	_update_undo_buttons()
	_update_title()
	_last_validation = project.validate()
	_update_validation_badge()
	_status(description + " · add creator/license metadata before publishing.", EditorTheme.YELLOW)

# ---------------------------------------------------------------------------
# Storyboard / subtitles
# ---------------------------------------------------------------------------

func _on_scene_field_changed(scene_id: String, field: String, value: Variant) -> void:
	_begin_edit("Scene %s · %s" % [scene_id, field], "scene|" + scene_id + "|" + field)
	var found := false
	for s in project.storyboard.get("scenes", []):
		if s is Dictionary and str(s.get("id", "")) == scene_id:
			s[field] = value
			found = true
			break
	if not found:
		_coalesce_key = ""
		return
	_end_edit()
	scene_refresh()
	timeline.refresh()
	_status("Scene %s · %s updated." % [scene_id, field])

func scene_refresh() -> void:
	if engine != null and project != null:
		engine.scenes = (project.storyboard.get("scenes", []) as Array).duplicate(true)

func _subs_for(lang: String) -> Array:
	var subs = project.storyboard.get("subtitles", {})
	if not subs is Dictionary:
		subs = {}
		project.storyboard["subtitles"] = subs
	if not subs.get(lang) is Array:
		subs[lang] = []
	return subs[lang]

func _on_subtitle_changed(lang: String, index: int, field: String, value: Variant) -> void:
	var arr := _subs_for(lang)
	if index < 0 or index >= arr.size() or not arr[index] is Dictionary:
		return
	_begin_edit("Subtitle %s · %s" % [lang, field], "sub|" + lang + "|%d|" % index + field)
	arr[index][field] = value
	_end_edit()
	preview.set_time(current_time)
	_status("Subtitle %s [%d] updated." % [lang, index + 1])

func _on_subtitle_add(lang: String, start: float, end: float) -> void:
	var arr := _subs_for(lang)
	_begin_edit("Add %s subtitle" % lang)
	var s := maxf(0.0, start)
	var e := minf(float(engine.duration), maxf(s + 0.2, end))
	arr.append({"start": snappedf(s, 0.001), "end": snappedf(e, 0.001), "text": ""})
	arr.sort_custom(func(a, b): return float(a.get("start", 0.0)) < float(b.get("start", 0.0)))
	_end_edit()
	storyboard_panel.refresh()
	preview.set_time(current_time)
	_status("Added a %s subtitle at %.2fs — type the text." % [lang, s], EditorTheme.GREEN)

func _on_subtitle_delete(lang: String, index: int) -> void:
	var arr := _subs_for(lang)
	if index < 0 or index >= arr.size():
		return
	_begin_edit("Delete %s subtitle" % lang)
	arr.remove_at(index)
	_end_edit()
	storyboard_panel.refresh()
	preview.set_time(current_time)
	_status("Deleted %s subtitle %d." % [lang, index + 1], EditorTheme.YELLOW)

# ---------------------------------------------------------------------------
# Audio panel
# ---------------------------------------------------------------------------

func _find_audio_track(id: String) -> Dictionary:
	for t in project.storyboard.get("audio", {}).get("tracks", []):
		if t is Dictionary and str(t.get("id", "")) == id:
			return t
	return {}

func _on_audio_track_changed(id: String, field: String, value: Variant) -> void:
	var tr := _find_audio_track(id)
	if tr.is_empty():
		return
	_begin_edit("Audio %s · %s" % [id, field], "audio|" + id + "|" + field)
	tr[field] = value
	_end_edit()
	if field in ["mute", "solo"]:
		audio_panel.refresh()
	if audio_manager != null:
		audio_manager.any_solo = false
		for t in project.storyboard.get("audio", {}).get("tracks", []):
			if t is Dictionary and bool(t.get("solo", false)) and not bool(t.get("mute", false)):
				audio_manager.any_solo = true
		audio_manager.update(current_time, playing, true)
	_status("Audio %s · %s updated." % [id, field])

func _on_audio_seek(t: float) -> void:
	_pause()
	_set_time(t)
	if audio_manager != null:
		audio_manager.seek(current_time, false)

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

func _on_validate_pressed() -> void:
	if project == null:
		return
	_last_validation = project.validate()
	_update_validation_badge()
	var errs: Array = _last_validation.get("errors", [])
	var warns: Array = _last_validation.get("warnings", [])
	var lines: Array = []
	lines.append("ERRORS (%d)" % errs.size())
	if errs.is_empty():
		lines.append("  None. The project can be rendered.")
	else:
		for e in errs:
			lines.append("  • " + str(e))
	lines.append("")
	lines.append("WARNINGS (%d)" % warns.size())
	if warns.is_empty():
		lines.append("  None.")
	else:
		for w in warns:
			lines.append("  • " + str(w))
	lines.append("")
	lines.append("Fonts:")
	for f in project.validate_fonts():
		if f is Dictionary:
			lines.append(("  ✓ " if bool(f.get("ok", false)) else "  ✗ ") + str(f.get("path", "")) + ("  — " + str(f.get("message", "")) if not bool(f.get("ok", false)) else ""))
	lines.append("")
	lines.append("Output: %d×%d · %d fps · %d frames · %.3fs · canvas %d×%d" % [
		int(project.episode.get("width", 1920)), int(project.episode.get("height", 1080)),
		int(project.episode.get("fps", 30)), engine.frame_count(),
		float(project.episode.get("duration_seconds", 10.0)),
		int(project.episode.get("canvas", {}).get("width", 6000)), int(project.episode.get("canvas", {}).get("height", 3000)),
	])
	_validation_dialog.dialog_text = "\n".join(lines)
	_validation_dialog.popup_centered(Vector2i(780, 540))
	if errs.is_empty():
		_status("Validation passed with %d warning(s)." % warns.size(), EditorTheme.GREEN)
	else:
		_status("Validation failed: %d error(s)." % errs.size(), EditorTheme.RED)

func _update_validation_badge() -> void:
	if _validation_label == null or project == null:
		return
	var errs: int = _last_validation.get("errors", []).size()
	var warns: int = _last_validation.get("warnings", []).size()
	if errs > 0:
		_validation_label.text = "VALIDATION  %d error%s · %d warning%s" % [errs, "" if errs == 1 else "s", warns, "" if warns == 1 else "s"]
		_validation_label.add_theme_color_override("font_color", Color("#FF9B8A"))
	elif warns > 0:
		_validation_label.text = "VALIDATION  clean · %d warning%s" % [warns, "" if warns == 1 else "s"]
		_validation_label.add_theme_color_override("font_color", EditorTheme.YELLOW)
	else:
		_validation_label.text = "VALIDATION  clean"
		_validation_label.add_theme_color_override("font_color", EditorTheme.GREEN)

# ---------------------------------------------------------------------------
# Export
# ---------------------------------------------------------------------------

func _open_export() -> void:
	if export_running:
		_status("An export is already running.", EditorTheme.YELLOW)
		return
	_pause()
	_save_project(true)
	_last_validation = project.validate()
	_update_validation_badge()
	export_dialog.open_for(project, _last_validation)

func _on_export_requested(options: Dictionary) -> void:
	if export_running:
		return
	if project == null:
		export_dialog.show_report({"ok": false, "error": "No project loaded."})
		return
	_pause()
	_sync_tracks()
	if not _save_project(true):
		export_dialog.show_report({"ok": false, "error": "Could not save the project before export."})
		return
	_last_validation = project.validate()
	_update_validation_badge()
	if not _last_validation.get("errors", []).is_empty():
		export_dialog.show_report({
			"ok": false,
			"error": "Validation errors must be fixed before export.",
			"checks": [],
		})
		return
	export_running = true
	_status("Export started — rendering %d frames through the deterministic stage." % engine.frame_count())
	export_manager = ExportManagerScript.new()
	export_manager.name = "OfflineExport"
	add_child(export_manager)
	export_manager.progress.connect(_on_export_progress)
	export_manager.log_message.connect(func(text): export_dialog.append_log(text))
	var report: Dictionary = await export_manager.export_project(project, engine, options)
	_on_export_finished(report)

func _on_export_progress(phase: String, current: int, total: int, message: String) -> void:
	export_dialog.set_progress(phase, current, total, message)
	if phase in ["render", "audio", "encode", "verify"]:
		_status(message)

func _on_export_cancel() -> void:
	if export_manager != null:
		export_manager.cancel()
		_status("Cancelling export after the current step…", EditorTheme.YELLOW)

func _on_export_finished(report: Dictionary) -> void:
	export_running = false
	export_dialog.show_report(report)
	if bool(report.get("ok", false)):
		_status("Export passed: %s · %.1f MB · %.1fs" % [
			str(report.get("settings", {}).get("video_path", "")),
			float(report.get("size_bytes", 0)) / (1024.0 * 1024.0),
			float(report.get("elapsed_seconds", 0.0)),
		], EditorTheme.GREEN)
	else:
		_status("Export failed: " + str(report.get("error", "see checks")), EditorTheme.RED)
	if export_manager != null:
		export_manager.queue_free()
		export_manager = null

# ---------------------------------------------------------------------------
# Keyboard
# ---------------------------------------------------------------------------

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k := event as InputEventKey
	var ctrl := k.ctrl_pressed or k.meta_pressed
	var shift := k.shift_pressed
	if ctrl and k.keycode == KEY_S:
		_on_save_pressed()
		get_viewport().set_input_as_handled()
		return
	if ctrl and k.keycode == KEY_Z:
		if shift:
			_redo_last()
		else:
			_undo_last()
		get_viewport().set_input_as_handled()
		return
	if ctrl and k.keycode == KEY_Y:
		_redo_last()
		get_viewport().set_input_as_handled()
		return
	if ctrl and k.keycode == KEY_D:
		_on_duplicate_element()
		get_viewport().set_input_as_handled()
		return
	if ctrl:
		return
	match k.keycode:
		KEY_SPACE:
			_toggle_play()
			get_viewport().set_input_as_handled()
		KEY_LEFT:
			_step_frames(-10 if shift else -1)
			get_viewport().set_input_as_handled()
		KEY_RIGHT:
			_step_frames(10 if shift else 1)
			get_viewport().set_input_as_handled()
		KEY_HOME:
			_go_start()
			get_viewport().set_input_as_handled()
		KEY_END:
			_go_end()
			get_viewport().set_input_as_handled()
		KEY_DELETE, KEY_BACKSPACE:
			if timeline != null and timeline.has_key_selection():
				_on_timeline_key_delete()
			elif not selection.is_empty():
				_on_delete_element()
			get_viewport().set_input_as_handled()
