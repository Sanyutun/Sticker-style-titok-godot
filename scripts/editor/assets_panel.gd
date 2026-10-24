class_name AssetsPanel
extends VBoxContainer
## Project asset browser with original-asset credits and import workflow.

signal sticker_requested(asset_path: String)
signal audio_requested(asset_path: String)
signal import_started
signal project_changed(description: String)
signal status_message(text: String)

var project = null
var selected_path := ""
var _updating := false
var list: ItemList
var detail_box: VBoxContainer
var preview: TextureRect
var import_dialog: FileDialog
var _icons: Dictionary = {}
var _entries: Array = []

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
	hb.add_child(EditorTheme.heading("Assets", 11, Color("#E8EDF3")))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(sp)
	var imp := Button.new()
	imp.text = "Import image…"
	imp.custom_minimum_size = Vector2(102, 27)
	imp.pressed.connect(func(): import_dialog.popup_centered_ratio(0.62))
	hb.add_child(imp)
	var scan := Button.new()
	scan.text = "Rescan"
	scan.custom_minimum_size = Vector2(60, 27)
	scan.pressed.connect(func(): refresh())
	hb.add_child(scan)

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 360
	add_child(split)
	list = ItemList.new()
	list.custom_minimum_size = Vector2(300, 0)
	list.icon_mode = ItemList.ICON_MODE_TOP
	list.fixed_icon_size = Vector2i(72, 58)
	list.max_text_lines = 2
	list.add_theme_font_size_override("font_size", 10)
	list.item_selected.connect(_on_selected)
	list.item_activated.connect(func(i): _on_activated(i))
	split.add_child(list)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(scroll)
	detail_box = VBoxContainer.new()
	detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_box.add_theme_constant_override("separation", 8)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_child(detail_box)
	scroll.add_child(margin)

	preview = TextureRect.new()
	preview.custom_minimum_size = Vector2(320, 190)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	detail_box.add_child(preview)

	import_dialog = FileDialog.new()
	import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	import_dialog.access = FileDialog.ACCESS_FILESYSTEM
	import_dialog.title = "Import image into project"
	import_dialog.filters = PackedStringArray(["*.png ; PNG image", "*.jpg, *.jpeg ; JPEG image", "*.webp ; WebP image", "*.svg ; SVG vector"])
	import_dialog.file_selected.connect(_import_file)
	add_child(import_dialog)

func setup(p_project) -> void:
	project = p_project
	refresh()

func refresh() -> void:
	_updating = true
	_entries.clear()
	list.clear()
	_icons.clear()
	if project == null:
		_updating = false
		return
	var project_abs := ProjectData.globalize_path(project.project_dir)
	var seen := {}
	_scan_dir(project_abs.path_join("assets"), "assets")
	_scan_dir(project_abs.path_join("audio"), "audio")
	# Also include any files referenced by the storyboard that live elsewhere.
	for e in project.storyboard.get("elements", []):
		if e is Dictionary and str(e.get("type", "")) == "sticker":
			var a := str(e.get("asset", ""))
			if not a.is_empty() and not seen.has(a):
				_add_entry(a, "referenced image", "")
	for at in project.storyboard.get("audio", {}).get("tracks", []):
		if at is Dictionary:
			var f := str(at.get("file", ""))
			if not f.is_empty() and not seen.has(f):
				_add_entry(f, "referenced audio", "")
	for e in _entries:
		var label := str(e.get("name", ""))
		var icon: Texture2D = _icon_for(e)
		list.add_item(label, icon)
		var i := list.item_count - 1
		list.set_item_metadata(i, str(e.get("path", "")))
		list.set_item_tooltip(i, "%s\n%s" % [str(e.get("path", "")), str(e.get("kind", ""))])
	if not selected_path.is_empty():
		for i in range(list.item_count):
			if str(list.get_item_metadata(i)) == selected_path:
				list.select(i)
				break
	_updating = false
	if list.item_count > 0 and list.get_selected_items().is_empty():
		selected_path = str(list.get_item_metadata(0))
		list.select(0)
	_build_detail()

func _scan_dir(abs_dir: String, kind: String) -> void:
	if not DirAccess.dir_exists_absolute(abs_dir):
		return
	var da := DirAccess.open(abs_dir)
	if da == null:
		return
	da.list_dir_begin()
	var f: String = da.get_next()
	while f != "":
		if not da.current_is_dir() and not f.ends_with(".import") and not f.ends_with(".uid"):
			var rel: String = kind + "/" + f
			_add_entry(rel, kind, abs_dir.path_join(f))
		f = da.get_next()
	da.list_dir_end()

func _add_entry(rel: String, kind: String, abs_path: String = "") -> void:
	for e in _entries:
		if str(e.get("path", "")) == rel:
			return
	var abs := abs_path
	if abs.is_empty():
		abs = ProjectData.globalize_path(project.project_dir.path_join(rel))
	var ext := rel.get_extension().to_lower()
	var entry := {"path": rel, "name": rel.get_file(), "kind": kind, "abs": abs, "ext": ext}
	if ext in ["png", "jpg", "jpeg", "webp", "svg"]:
		entry["kind"] = "image"
	elif ext in ["wav", "ogg", "mp3"]:
		entry["kind"] = "audio"
	if FileAccess.file_exists(abs):
		entry["size"] = FileAccess.get_file_as_bytes(abs).size()
	_entries.append(entry)

func _icon_for(entry: Dictionary) -> Texture2D:
	var path := str(entry.get("path", ""))
	if _icons.has(path):
		return _icons[path]
	var tex: Texture2D = null
	if str(entry.get("kind", "")) == "image":
		var img := Image.new()
		if img.load(str(entry.get("abs", ""))) == OK:
			var w := img.get_width()
			var h := img.get_height()
			var target := 72
			var scale := minf(float(target) / maxf(1.0, w), float(target - 10) / maxf(1.0, h))
			img.resize(maxi(1, int(w * scale)), maxi(1, int(h * scale)), Image.INTERPOLATE_LANCZOS)
			tex = ImageTexture.create_from_image(img)
	if tex == null:
		var img2 := Image.create(56, 56, false, Image.FORMAT_RGBA8)
		var col := Color("#62AEDA") if str(entry.get("kind", "")) == "audio" else Color("#5C6674")
		img2.fill(Color(0, 0, 0, 0))
		img2.fill_rect(Rect2i(8, 8, 40, 40), Color(col, 0.22))
		if str(entry.get("kind", "")) == "audio":
			for i in range(12):
				var h := 6 + int(abs(sin(float(i) * 1.7)) * 22.0)
				img2.fill_rect(Rect2i(10 + i * 3, 28 - h / 2, 2, h), col)
		else:
			img2.fill_rect(Rect2i(21, 12, 14, 4), col)
			img2.fill_rect(Rect2i(21, 20, 10, 4), col)
		tex = ImageTexture.create_from_image(img2)
	_icons[path] = tex
	return tex

func _on_selected(index: int) -> void:
	if _updating or index < 0:
		return
	selected_path = str(list.get_item_metadata(index))
	_build_detail()

func _on_activated(index: int) -> void:
	_on_selected(index)

func _find_entry(path: String) -> Dictionary:
	for e in _entries:
		if str(e.get("path", "")) == path:
			return e
	return {}

func _metadata_for(path: String) -> Dictionary:
	for a in project.episode.get("assets", []):
		if a is Dictionary and str(a.get("path", "")) == path:
			return a
	return {}

func _build_detail() -> void:
	for c in detail_box.get_children():
		if c != preview:
			c.queue_free()
	if preview == null:
		return
	var entry := _find_entry(selected_path)
	if entry.is_empty():
		preview.texture = null
		var l := Label.new()
		l.text = "No asset selected.\n\nDrop original artwork into the project's assets/ folder or use Import image."
		l.add_theme_color_override("font_color", Color("#8B98A8"))
		l.add_theme_font_size_override("font_size", 10)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail_box.add_child(l)
		return
	var kind := str(entry.get("kind", ""))
	if kind == "image":
		var img := Image.new()
		if img.load(str(entry.get("abs", ""))) == OK:
			var tex := ImageTexture.create_from_image(img)
			preview.texture = tex
			preview.custom_minimum_size = Vector2(320, clampf(320.0 * float(img.get_height()) / maxf(1.0, float(img.get_width())), 120.0, 260.0))
			var meta := _metadata_for(selected_path)
			var dims := "%d × %d px" % [img.get_width(), img.get_height()]
			_add_kv("Path", selected_path)
			_add_kv("Kind", "Image · " + dims)
			_add_kv("Size", _fmt_size(int(entry.get("size", 0))))
			if not meta.is_empty():
				_add_kv("Source", str(meta.get("source", "")))
				_add_kv("Creator", str(meta.get("creator", "")))
				_add_kv("License", str(meta.get("license", "")))
				_add_kv("Attribution", str(meta.get("attribution", "")))
				if not str(meta.get("modifications", "")).is_empty():
					_add_kv("Modified", str(meta.get("modifications", "")))
			else:
				var warn := Label.new()
				warn.text = "No credits entry for this asset. Add source, creator and license before publishing."
				warn.add_theme_color_override("font_color", Color("#E9C46A"))
				warn.add_theme_font_size_override("font_size", 10)
				warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				detail_box.add_child(warn)
			var add := Button.new()
			add.text = "Add sticker to current scene"
			add.custom_minimum_size = Vector2(0, 30)
			add.pressed.connect(func(): sticker_requested.emit(selected_path))
			detail_box.add_child(add)
			var copy := Button.new()
			copy.text = "Copy path"
			copy.pressed.connect(func():
				DisplayServer.clipboard_set(selected_path)
				status_message.emit("Asset path copied.")
			)
			detail_box.add_child(copy)
		else:
			preview.texture = null
			_add_kv("Path", selected_path)
			_add_kv("Status", "File missing or unreadable.")
	elif kind == "audio":
		preview.texture = null
		preview.custom_minimum_size = Vector2(320, 96)
		_add_kv("Path", selected_path)
		_add_kv("Kind", "Audio")
		_add_kv("Size", _fmt_size(int(entry.get("size", 0))))
		var add := Button.new()
		add.text = "Add audio track at playhead"
		add.custom_minimum_size = Vector2(0, 30)
		add.pressed.connect(func(): audio_requested.emit(selected_path))
		detail_box.add_child(add)
	else:
		preview.texture = null
		_add_kv("Path", selected_path)
		_add_kv("Kind", kind.capitalize())
		_add_kv("Size", _fmt_size(int(entry.get("size", 0))))

func _add_kv(k: String, v: String) -> void:
	if v.strip_edges().is_empty():
		return
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	var kl := Label.new()
	kl.text = k.to_upper()
	kl.add_theme_font_size_override("font_size", 8)
	kl.add_theme_color_override("font_color", Color("#66717F"))
	row.add_child(kl)
	var vl := Label.new()
	vl.text = v
	vl.add_theme_font_size_override("font_size", 11)
	vl.add_theme_color_override("font_color", Color("#C9D3DF"))
	vl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(vl)
	detail_box.add_child(row)

func _fmt_size(bytes: int) -> String:
	if bytes > 1024 * 1024:
		return "%.1f MB" % (float(bytes) / (1024.0 * 1024.0))
	if bytes > 1024:
		return "%.1f KB" % (float(bytes) / 1024.0)
	return "%d B" % bytes

func _import_file(path: String) -> void:
	if project == null:
		return
	import_started.emit()
	var ext := path.get_extension().to_lower()
	var base := path.get_file().get_basename().to_snake_case()
	if base.is_empty():
		base = "imported"
	var target_dir := ProjectData.globalize_path(project.project_dir).path_join("assets")
	DirAccess.make_dir_recursive_absolute(target_dir)
	var target := target_dir.path_join(base + "." + ext)
	var n := 2
	while FileAccess.file_exists(target):
		target = target_dir.path_join("%s_%d.%s" % [base, n, ext])
		n += 1
	var err := DirAccess.copy_absolute(path, target)
	if err != OK:
		status_message.emit("Import failed (error %d)." % err)
		return
	var rel := "assets/" + target.get_file()
	project.episode["assets"].append({
		"name": target.get_file(),
		"path": rel,
		"source": "User-imported file — verify original source",
		"creator": "Unknown — add before publication",
		"license": "Unknown — review before publication",
		"attribution": "Pending review",
		"modifications": "Copied into project without alteration",
	})
	project_changed.emit("Imported asset %s" % rel)
	refresh()
	status_message.emit("Imported %s. Add a creator/license entry before publishing." % rel)

func navigate_to(path: String) -> void:
	selected_path = path
	refresh()
