class_name ProjectPanel
extends VBoxContainer
## Elements and scenes navigator.

signal element_selected(id: String)
signal scene_selected(id: String, start: float)
signal add_requested(type: String)
signal duplicate_requested
signal delete_requested
signal reorder_requested(delta: int)
signal status_message(text: String)

const TYPE_ORDER := ["text", "shape", "sticker", "arrow", "chart", "character", "blood_vessel", "pressure_gauge"]

var project = null
var selected_id := ""
var search: LineEdit
var type_filter: OptionButton
var list: ItemList
var scene_list: ItemList
var count_label: Label
var add_menu: MenuButton
var _updating := false
var _icons: Dictionary = {}

func _ready() -> void:
	add_theme_constant_override("separation", 6)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 8)
	pad.add_theme_constant_override("margin_right", 8)
	pad.add_theme_constant_override("margin_top", 8)
	pad.add_theme_constant_override("margin_bottom", 4)
	var top := VBoxContainer.new()
	top.add_theme_constant_override("separation", 5)
	pad.add_child(top)
	add_child(pad)

	var head := HBoxContainer.new()
	head.add_child(EditorTheme.heading("Elements", 10, Color("#E8EDF3")))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	count_label = Label.new()
	count_label.text = "0"
	count_label.add_theme_font_size_override("font_size", 10)
	count_label.add_theme_color_override("font_color", Color("#66717F"))
	head.add_child(count_label)
	top.add_child(head)

	search = LineEdit.new()
	search.placeholder_text = "Search elements…"
	search.custom_minimum_size = Vector2(0, 27)
	search.text_changed.connect(func(_t): _populate())
	top.add_child(search)

	type_filter = OptionButton.new()
	type_filter.add_item("All types", 0)
	for i in range(TYPE_ORDER.size()):
		type_filter.add_item(TYPE_ORDER[i].capitalize(), i + 1)
	type_filter.custom_minimum_size = Vector2(0, 27)
	type_filter.item_selected.connect(func(_i): _populate())
	top.add_child(type_filter)

	list = ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.custom_minimum_size = Vector2(0, 160)
	list.fixed_icon_size = Vector2i(8, 8)
	list.icon_mode = ItemList.ICON_MODE_LEFT
	list.allow_reselect = true
	list.item_selected.connect(_on_item_selected)
	list.item_activated.connect(_on_item_selected)
	list.add_theme_font_size_override("font_size", 12)
	add_child(list)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 4)
	var pad2 := MarginContainer.new()
	pad2.add_theme_constant_override("margin_left", 8)
	pad2.add_theme_constant_override("margin_right", 8)
	pad2.add_theme_constant_override("margin_bottom", 6)
	pad2.add_child(buttons)
	add_child(pad2)

	add_menu = MenuButton.new()
	add_menu.text = "+ Add"
	add_menu.tooltip_text = "Add a reusable visual element at the camera centre"
	add_menu.custom_minimum_size = Vector2(64, 27)
	var pop := add_menu.get_popup()
	for i in range(TYPE_ORDER.size()):
		pop.add_item(TYPE_ORDER[i].replace("_", " ").capitalize(), i)
	pop.id_pressed.connect(func(id): add_requested.emit(TYPE_ORDER[id]))
	buttons.add_child(add_menu)

	var dup := Button.new()
	dup.text = "Duplicate"
	dup.custom_minimum_size = Vector2(76, 27)
	dup.pressed.connect(func(): duplicate_requested.emit())
	buttons.add_child(dup)

	var del := Button.new()
	del.text = "Delete"
	del.custom_minimum_size = Vector2(56, 27)
	del.add_theme_color_override("font_color", Color("#FF9B8A"))
	del.pressed.connect(func(): delete_requested.emit())
	buttons.add_child(del)

	var up := Button.new()
	up.text = "↑"
	up.tooltip_text = "Bring forward (raise z-index)"
	up.custom_minimum_size = Vector2(28, 27)
	up.pressed.connect(func(): reorder_requested.emit(1))
	buttons.add_child(up)
	var down := Button.new()
	down.text = "↓"
	down.tooltip_text = "Send backward (lower z-index)"
	down.custom_minimum_size = Vector2(28, 27)
	down.pressed.connect(func(): reorder_requested.emit(-1))
	buttons.add_child(down)

	# scenes ------------------------------------------------------------
	var sep := EditorTheme.separator()
	sep.custom_minimum_size = Vector2(0, 1)
	add_child(sep)
	var pad3 := MarginContainer.new()
	pad3.add_theme_constant_override("margin_left", 8)
	pad3.add_theme_constant_override("margin_right", 8)
	pad3.add_theme_constant_override("margin_top", 8)
	pad3.add_theme_constant_override("margin_bottom", 8)
	var scene_box := VBoxContainer.new()
	scene_box.add_theme_constant_override("separation", 5)
	pad3.add_child(scene_box)
	add_child(pad3)
	var shead := HBoxContainer.new()
	shead.add_child(EditorTheme.heading("Scenes", 10, Color("#E8EDF3")))
	scene_box.add_child(shead)
	scene_list = ItemList.new()
	scene_list.custom_minimum_size = Vector2(0, 154)
	scene_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scene_list.add_theme_font_size_override("font_size", 11)
	scene_list.item_selected.connect(func(i):
		if _updating or project == null:
			return
		var scenes: Array = project.storyboard.get("scenes", [])
		if i >= 0 and i < scenes.size():
			var s: Dictionary = scenes[i]
			scene_selected.emit(str(s.get("id", "")), float(s.get("start", 0.0)))
	)
	scene_box.add_child(scene_list)

func setup(p_project) -> void:
	project = p_project
	refresh()

func refresh() -> void:
	if project == null:
		return
	_updating = true
	_populate()
	var scenes: Array = project.storyboard.get("scenes", [])
	scene_list.clear()
	for i in range(scenes.size()):
		var s: Dictionary = scenes[i]
		var line := "%02d  %s" % [i + 1, str(s.get("name", "Scene"))]
		scene_list.add_item(line)
		scene_list.set_item_metadata(i, str(s.get("id", "")))
		scene_list.set_item_tooltip(i, "%s — %.2f–%.2fs\n%s" % [str(s.get("name", "")), float(s.get("start", 0.0)), float(s.get("end", 0.0)), str(s.get("purpose", ""))])
		var col := Color("#8B98A8")
		scene_list.set_item_custom_fg_color(i, col)
	_updating = false

func update_element_label(id: String, new_name: String) -> void:
	for i in range(list.item_count):
		if str(list.get_item_metadata(i)) == id:
			list.set_item_text(i, new_name)
			return

func set_selected(id: String) -> void:
	selected_id = id
	_updating = true
	for i in range(list.item_count):
		if str(list.get_item_metadata(i)) == id:
			list.select(i)
			list.ensure_current_is_visible()
			break
	if id.is_empty():
		list.deselect_all()
	_updating = false

func _populate() -> void:
	if project == null:
		return
	var was := selected_id
	list.clear()
	var q := search.text.strip_edges().to_lower()
	var wanted_type := ""
	var fi := type_filter.selected - 1
	if fi >= 0 and fi < TYPE_ORDER.size():
		wanted_type = TYPE_ORDER[fi]
	var elements: Array = project.storyboard.get("elements", [])
	var shown := 0
	for i in range(elements.size()):
		var e: Dictionary = elements[i]
		if not wanted_type.is_empty() and str(e.get("type", "")) != wanted_type:
			continue
		var hay := (str(e.get("name", "")) + " " + str(e.get("id", "")) + " " + str(e.get("type", ""))).to_lower()
		if not q.is_empty() and not hay.contains(q):
			continue
		var id := str(e.get("id", ""))
		var type := str(e.get("type", ""))
		var label := "%s" % str(e.get("name", id))
		if bool(e.get("hidden", false)):
			label += "  (hidden)"
		list.add_item(label, _type_icon(type))
		list.set_item_metadata(list.item_count - 1, id)
		list.set_item_tooltip(list.item_count - 1, "%s · %s · %s" % [id, type, str(e.get("scene", ""))])
		if id == was:
			list.select(list.item_count - 1)
		shown += 1
	count_label.text = "%d / %d" % [shown, elements.size()]

func _type_icon(type: String) -> Texture2D:
	if _icons.has(type):
		return _icons[type]
	var col := InspectorPanel.type_color(type)
	var img := Image.create(10, 10, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	if type == "text":
		img.fill_rect(Rect2i(1, 2, 8, 2), col)
		img.fill_rect(Rect2i(1, 6, 6, 2), col)
	elif type == "shape":
		img.fill_rect(Rect2i(1, 1, 8, 8), col)
	elif type == "sticker":
		img.fill_rect(Rect2i(2, 2, 6, 6), col)
	elif type == "arrow":
		for y in range(10):
			img.set_pixel(clampi(y, 0, 9), y, col)
			img.set_pixel(clampi(y + 1, 0, 9), y, col)
	elif type == "chart":
		img.fill_rect(Rect2i(1, 6, 2, 3), col)
		img.fill_rect(Rect2i(4, 3, 2, 6), col)
		img.fill_rect(Rect2i(7, 1, 2, 8), col)
	elif type == "character":
		img.fill_rect(Rect2i(3, 1, 4, 3), col)
		img.fill_rect(Rect2i(2, 5, 6, 4), col)
	elif type == "blood_vessel":
		img.fill_rect(Rect2i(0, 3, 10, 2), col)
		img.fill_rect(Rect2i(0, 6, 10, 2), col.darkened(0.2))
	else:
		img.fill_rect(Rect2i(1, 1, 8, 8), col)
	var tex := ImageTexture.create_from_image(img)
	_icons[type] = tex
	return tex

func _on_item_selected(index: int) -> void:
	if _updating:
		return
	if index < 0 or index >= list.item_count:
		return
	var id := str(list.get_item_metadata(index))
	if id.is_empty():
		return
	selected_id = id
	element_selected.emit(id)

func select_scene(scene_id: String) -> void:
	if project == null:
		return
	var scenes: Array = project.storyboard.get("scenes", [])
	_updating = true
	for i in range(scenes.size()):
		if str(scenes[i].get("id", "")) == scene_id:
			scene_list.select(i)
			scene_list.ensure_current_is_visible()
			break
	_updating = false
