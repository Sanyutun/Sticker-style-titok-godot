class_name TimelinePanel
extends VBoxContainer
## Toolbar + canvas wrapper for the timeline dock.

signal time_changed(t: float)
signal element_selected(id: String)
signal key_selection_changed(has_selection: bool)
signal key_drag_started
signal key_drag_moved
signal key_drag_finished
signal key_add_requested(element_id: String, property: String, time: float)
signal key_delete_requested
signal status_message(text: String)

var canvas: TimelineCanvas
var filter_option: OptionButton
var add_button: Button
var delete_button: Button
var selection_label: Label
var hint_label: Label

func _ready() -> void:
	add_theme_constant_override("separation", 0)
	var bar := HBoxContainer.new()
	bar.custom_minimum_size = Vector2(0, 38)
	bar.add_theme_constant_override("separation", 6)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 10)
	pad.add_theme_constant_override("margin_right", 10)
	pad.add_theme_constant_override("margin_top", 5)
	pad.add_theme_constant_override("margin_bottom", 5)
	pad.add_child(bar)
	add_child(pad)

	var title := EditorTheme.heading("Timeline", 11, Color("#E8EDF3"))
	title.custom_minimum_size = Vector2(68, 0)
	bar.add_child(title)

	filter_option = OptionButton.new()
	filter_option.add_item("Selected", 0)
	filter_option.add_item("Camera", 1)
	filter_option.add_item("All tracks", 2)
	filter_option.custom_minimum_size = Vector2(124, 28)
	filter_option.item_selected.connect(func(idx):
		canvas.set_filter(["selected", "camera", "all"][idx])
		_update_hint()
	)
	bar.add_child(filter_option)

	add_button = Button.new()
	add_button.text = "+ Key"
	add_button.tooltip_text = "Add a keyframe for the selected track at the playhead"
	add_button.custom_minimum_size = Vector2(64, 28)
	add_button.pressed.connect(func():
		if canvas.selected_key_info()["track"] != null:
			canvas.add_key_at_playhead()
		else:
			status_message.emit("Select a track row first, or double-click a row to key its current value.")
	)
	bar.add_child(add_button)

	delete_button = Button.new()
	delete_button.text = "Delete key"
	delete_button.tooltip_text = "Delete the selected keyframe (Del)"
	delete_button.custom_minimum_size = Vector2(88, 28)
	delete_button.disabled = true
	delete_button.pressed.connect(func():
		if canvas.selected_key_info().get("key", null) != null:
			key_delete_requested.emit()
	)
	bar.add_child(delete_button)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)

	selection_label = Label.new()
	selection_label.text = "No track selected"
	selection_label.add_theme_font_size_override("font_size", 11)
	selection_label.add_theme_color_override("font_color", Color("#8B98A8"))
	bar.add_child(selection_label)

	hint_label = Label.new()
	hint_label.text = "  ·  double-click a row to key it"
	hint_label.add_theme_font_size_override("font_size", 10)
	hint_label.add_theme_color_override("font_color", Color("#5C6674"))
	bar.add_child(hint_label)

	canvas = TimelineCanvas.new()
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.time_changed.connect(func(t): time_changed.emit(t))
	canvas.element_selected.connect(func(id): element_selected.emit(id))
	canvas.key_selection_changed.connect(_on_key_selection)
	canvas.key_drag_started.connect(func(): key_drag_started.emit())
	canvas.key_drag_moved.connect(func(): key_drag_moved.emit())
	canvas.key_drag_finished.connect(func(): key_drag_finished.emit())
	canvas.key_add_requested.connect(func(e, p, t): key_add_requested.emit(e, p, t))
	canvas.status_message.connect(func(s): status_message.emit(s))
	add_child(canvas)

func setup(project, engine, selected_id: String = "") -> void:
	if canvas == null:
		return
	canvas.setup(project, engine)
	canvas.set_selected(selected_id)
	_update_hint()

func set_selected(id: String) -> void:
	if canvas != null:
		canvas.set_selected(id)
	_update_hint()

func set_time(t: float) -> void:
	if canvas != null:
		canvas.set_time(t)

func refresh() -> void:
	if canvas != null:
		canvas.refresh()
	_update_hint()

func selected_key_info() -> Dictionary:
	return canvas.selected_key_info() if canvas != null else {}

func has_key_selection() -> bool:
	if canvas == null:
		return false
	var info: Dictionary = canvas.selected_key_info()
	return info.get("key", null) != null

func delete_selected_key() -> bool:
	return canvas.delete_selected_key() if canvas != null else false

func _on_key_selection(has: bool) -> void:
	delete_button.disabled = not has
	var info: Dictionary = canvas.selected_key_info()
	if has and info.get("track") != null and info.get("key") != null:
		var tr = info["track"]
		var k = info["key"]
		selection_label.text = "%s · %s  @ %.2fs" % [tr.element_id, tr.property, k.time]
		selection_label.add_theme_color_override("font_color", Color("#FFB59E"))
	else:
		selection_label.text = "No key selected"
		selection_label.add_theme_color_override("font_color", Color("#8B98A8"))
	key_selection_changed.emit(has)

func _update_hint() -> void:
	if canvas == null or hint_label == null:
		return
	match canvas.filter_mode:
		"all":
			hint_label.text = "  ·  %d tracks shown" % canvas.rows.size()
		"camera":
			hint_label.text = "  ·  camera tracks"
		_:
			hint_label.text = "  ·  %d track(s) for selection" % canvas.rows.size()
