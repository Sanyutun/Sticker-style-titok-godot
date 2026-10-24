class_name InspectorPanel
extends VBoxContainer
## Selection inspector. Editing writes to the project data and notifies the
## editor; the editor owns undo snapshots and stage rebuilds.

signal element_field_changed(element_id: String, field: String, value: Variant, structural: bool)
signal camera_key_requested(property: String, value: Variant)
signal key_add_requested(element_id: String, property: String)
signal track_deleted(element_id: String, property: String)
signal key_all_requested(element_id: String)
signal scene_changed(element_id: String, scene_id: String)
signal status_message(text: String)

const ANIMATABLE := [
	"position", "scale", "rotation", "opacity", "reveal", "progress",
	"width", "height", "value", "water_level", "flow", "bulge", "needle",
	"text_size", "outline_width", "label_opacity",
]

var project = null
var engine = null
var selected_id := ""
var current_time := 0.0
var _content: VBoxContainer
var _prop_option: OptionButton
var _updating := false

func _ready() -> void:
	add_theme_constant_override("separation", 0)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	scroll.add_child(_content)

func build(p_project, p_engine, p_selected: String, p_time: float) -> void:
	project = p_project
	engine = p_engine
	selected_id = p_selected
	current_time = p_time
	_updating = true
	for c in _content.get_children():
		c.queue_free()
	if selected_id.is_empty():
		_build_camera()
	else:
		var elem: Dictionary = project.element_by_id(selected_id)
		if elem.is_empty():
			_build_camera()
		else:
			_build_element(elem)
	_updating = false

func set_time(t: float) -> void:
	current_time = t

func _heading(text: String, accent: Color = Color("#FF6A45")) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	var bar := ColorRect.new()
	bar.color = accent
	bar.custom_minimum_size = Vector2(3, 14)
	row.add_child(bar)
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", Color("#9AA7B6"))
	row.add_child(l)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	return row

func _section(text: String, accent: Color = Color("#FF6A45")) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(_heading(text, accent))
	_content.add_child(box)
	return box

func _grid(parent: VBoxContainer) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 5)
	parent.add_child(g)
	return g

func _label(text: String, tip: String = "") -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(76, 0)
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", Color("#8B98A8"))
	if not tip.is_empty():
		l.tooltip_text = tip
	return l

func _field(grid: GridContainer, label_text: String, control: Control, tip: String = "") -> void:
	grid.add_child(_label(label_text, tip))
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(control)

func _spin(value: float, step: float = 1.0, minv: float = -100000.0, maxv: float = 100000.0, suffix: String = "") -> SpinBox:
	var s := SpinBox.new()
	s.min_value = minv
	s.max_value = maxv
	s.step = step
	s.allow_greater = true
	s.allow_lesser = true
	s.suffix = suffix
	s.custom_minimum_size = Vector2(0, 26)
	s.set_value_no_signal(value)
	return s

func _pair_row(x: SpinBox, y: SpinBox, labels: Array = ["X", "Y"]) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.add_child(x)
	var mid := Label.new()
	mid.text = labels[1] if labels.size() > 1 else "Y"
	mid.add_theme_font_size_override("font_size", 9)
	mid.add_theme_color_override("font_color", Color("#5C6674"))
	h.add_child(mid)
	h.add_child(y)
	return h

func _build_element(elem: Dictionary) -> void:
	var type := str(elem.get("type", "shape"))
	# header ------------------------------------------------------------
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	var badge := Label.new()
	badge.text = type.to_upper()
	badge.add_theme_font_size_override("font_size", 9)
	badge.add_theme_color_override("font_color", type_color(type))
	var bpanel := PanelContainer.new()
	bpanel.add_theme_stylebox_override("panel", EditorTheme.padded(Color(type_color(type), 0.12), 3, 6, 2, Color(type_color(type), 0.35), 1))
	bpanel.add_child(badge)
	header.add_child(bpanel)
	var name_edit := LineEdit.new()
	name_edit.text = str(elem.get("name", selected_id))
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.tooltip_text = "Element name (editor only)"
	name_edit.text_changed.connect(func(txt):
		if _updating: return
		elem["name"] = txt
		element_field_changed.emit(selected_id, "name", txt, false)
	)
	header.add_child(name_edit)
	_content.add_child(header)

	var idrow := HBoxContainer.new()
	idrow.add_theme_constant_override("separation", 6)
	var idl := Label.new()
	idl.text = "ID  " + str(elem.get("id", ""))
	idl.add_theme_font_size_override("font_size", 10)
	idl.add_theme_color_override("font_color", Color("#5C6674"))
	idl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	idrow.add_child(idl)
	var scene_opt := OptionButton.new()
	scene_opt.custom_minimum_size = Vector2(126, 24)
	var idx := 0
	var scenes: Array = project.storyboard.get("scenes", [])
	for i in range(scenes.size()):
		var s: Dictionary = scenes[i]
		scene_opt.add_item(str(s.get("name", s.get("id", "scene"))), i)
		if str(s.get("id", "")) == str(elem.get("scene", "")):
			idx = i
	scene_opt.select(idx)
	scene_opt.item_selected.connect(func(i2):
		if _updating: return
		scene_changed.emit(selected_id, str(scenes[i2].get("id", "")))
	)
	idrow.add_child(scene_opt)
	_content.add_child(idrow)

	# transform ---------------------------------------------------------
	var tg := _section("Transform")
	var grid := _grid(tg)
	var px := _spin(float(elem.get("x", 0.0)))
	var py := _spin(float(elem.get("y", 0.0)))
	_field(grid, "Position", _pair_row(px, py, ["X", "Y"]), "World position on the 6000×3000 canvas")
	px.value_changed.connect(func(v): _set_num(elem, "x", v))
	py.value_changed.connect(func(v): _set_num(elem, "y", v))
	var pw := _spin(float(elem.get("width", 100.0)), 1.0, 1.0, 20000.0)
	var ph := _spin(float(elem.get("height", 100.0)), 1.0, 1.0, 20000.0)
	_field(grid, "Size", _pair_row(pw, ph, ["W", "H"]))
	pw.value_changed.connect(func(v): _set_num(elem, "width", v))
	ph.value_changed.connect(func(v): _set_num(elem, "height", v))
	var prot := _spin(float(elem.get("rotation", 0.0)), 0.5, -1440.0, 1440.0, "°")
	_field(grid, "Rotation", prot)
	prot.value_changed.connect(func(v): _set_num(elem, "rotation", v))
	var pop := HSlider.new()
	pop.min_value = 0.0
	pop.max_value = 1.0
	pop.step = 0.01
	pop.value = float(elem.get("opacity", 1.0))
	pop.custom_minimum_size = Vector2(0, 26)
	pop.tooltip_text = "Base opacity. Opacity tracks override this while animating."
	_field(grid, "Opacity", pop)
	pop.value_changed.connect(func(v): _set_num(elem, "opacity", v))
	var pz := _spin(float(elem.get("z", 0)), 1.0, -100.0, 500.0)
	_field(grid, "Z index", pz, "Higher draws in front")
	pz.value_changed.connect(func(v): _set_num(elem, "z", int(v), true))
	var sx := _spin(float(elem.get("scale", [1, 1])[0]), 0.01, -20.0, 20.0)
	var sy := _spin(float(elem.get("scale", [1, 1])[1]), 0.01, -20.0, 20.0)
	_field(grid, "Scale", _pair_row(sx, sy, ["X", "Y"]))
	sx.value_changed.connect(func(v): _set_scale(elem, 0, v))
	sy.value_changed.connect(func(v): _set_scale(elem, 1, v))
	var hidden := CheckBox.new()
	hidden.text = "Hide in render"
	hidden.button_pressed = bool(elem.get("hidden", false))
	_field(grid, "Visibility", hidden)
	hidden.toggled.connect(func(on):
		if _updating: return
		elem["hidden"] = on
		element_field_changed.emit(selected_id, "hidden", on, true)
	)

	# type-specific -----------------------------------------------------
	match type:
		"text": _build_text(elem)
		"shape": _build_shape(elem)
		"sticker": _build_sticker(elem)
		"arrow": _build_arrow(elem)
		"chart": _build_chart(elem)
		"character": _build_character(elem)
		"blood_vessel": _build_vessel(elem)
		"pressure_gauge": _build_gauge(elem)
	_build_animation(elem)

func _build_text(elem: Dictionary) -> void:
	var box := _section("Text", Color("#62AEDA"))
	var text := TextEdit.new()
	text.text = str(elem.get("text", ""))
	text.custom_minimum_size = Vector2(0, 64)
	text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	text.scroll_fit_content_height = false
	text.tooltip_text = "Supports {{brand_name}}, {{project_name}}, {{topic}}"
	box.add_child(text)
	text.text_changed.connect(func():
		if _updating: return
		elem["text"] = text.text
		element_field_changed.emit(selected_id, "text", text.text, false)
	)
	var grid := _grid(box)
	var fs := _spin(float(elem.get("font_size", 64.0)), 1.0, 4.0, 600.0)
	_field(grid, "Font size", fs)
	fs.value_changed.connect(func(v): _set_num(elem, "font_size", int(v)))
	var weight := OptionButton.new()
	weight.add_item("Regular", 0)
	weight.add_item("Bold", 1)
	weight.select(1 if str(elem.get("font_weight", "regular")) == "bold" else 0)
	_field(grid, "Weight", weight)
	weight.item_selected.connect(func(i):
		if _updating: return
		elem["font_weight"] = "bold" if i == 1 else "regular"
		element_field_changed.emit(selected_id, "font_weight", elem["font_weight"], false)
	)
	var align := OptionButton.new()
	for a in ["left", "center", "right"]:
		align.add_item(a.capitalize())
		if str(elem.get("align", "left")) == a:
			align.select(align.item_count - 1)
	_field(grid, "Align", align)
	align.item_selected.connect(func(i):
		if _updating: return
		elem["align"] = ["left", "center", "right"][i]
		element_field_changed.emit(selected_id, "align", elem["align"], false)
	)
	var valign := OptionButton.new()
	for a in ["top", "center", "bottom"]:
		valign.add_item(a.capitalize())
		if str(elem.get("valign", "center")) == a:
			valign.select(valign.item_count - 1)
	_field(grid, "V-align", valign)
	valign.item_selected.connect(func(i):
		if _updating: return
		elem["valign"] = ["top", "center", "bottom"][i]
		element_field_changed.emit(selected_id, "valign", elem["valign"], false)
	)
	var color := ColorPickerButton.new()
	color.color = Color.from_string(str(elem.get("color", "#263746")), Color("#263746"))
	color.custom_minimum_size = Vector2(0, 26)
	color.edit_alpha = false
	_field(grid, "Colour", color)
	color.color_changed.connect(func(c):
		if _updating: return
		elem["color"] = c.to_html(false)
		element_field_changed.emit(selected_id, "color", c.to_html(false), false)
	)
	var uppercase := CheckBox.new()
	uppercase.text = "Uppercase"
	uppercase.button_pressed = bool(elem.get("uppercase", false))
	_field(grid, "Case", uppercase)
	uppercase.toggled.connect(func(on):
		if _updating: return
		elem["uppercase"] = on
		element_field_changed.emit(selected_id, "uppercase", on, false)
	)
	var bg := OptionButton.new()
	var bgs := ["none", "circle", "pill", "underline", "box"]
	for b in bgs:
		bg.add_item(b.capitalize())
		if str(elem.get("bg_style", "none")) == b:
			bg.select(bg.item_count - 1)
	_field(grid, "Badge", bg)
	bg.item_selected.connect(func(i):
		if _updating: return
		elem["bg_style"] = bgs[i]
		element_field_changed.emit(selected_id, "bg_style", bgs[i], false)
	)
	if str(elem.get("bg_style", "none")) != "none":
		var bgc := ColorPickerButton.new()
		bgc.color = Color.from_string(str(elem.get("bg_color", "#FF5A36")), Color("#FF5A36"))
		bgc.custom_minimum_size = Vector2(0, 26)
		bgc.edit_alpha = false
		_field(grid, "Badge fill", bgc)
		bgc.color_changed.connect(func(c):
			if _updating: return
			elem["bg_color"] = c.to_html(false)
			element_field_changed.emit(selected_id, "bg_color", c.to_html(false), false)
		)

func _build_shape(elem: Dictionary) -> void:
	var box := _section("Shape", Color("#72CE9B"))
	var grid := _grid(box)
	var shapes := ["rect", "rounded_rect", "ellipse", "line", "polygon", "path"]
	var opt := OptionButton.new()
	for s in shapes:
		opt.add_item(s.capitalize())
		if str(elem.get("shape", "rect")) == s:
			opt.select(opt.item_count - 1)
	_field(grid, "Type", opt)
	opt.item_selected.connect(func(i):
		if _updating: return
		elem["shape"] = shapes[i]
		element_field_changed.emit(selected_id, "shape", shapes[i], true)
	)
	var col := ColorPickerButton.new()
	col.color = Color.from_string(str(elem.get("fill", "#334B60")), Color("#334B60"))
	col.custom_minimum_size = Vector2(0, 26)
	col.edit_alpha = false
	_field(grid, "Fill", col)
	col.color_changed.connect(func(c):
		if _updating: return
		elem["fill"] = c.to_html(false)
		element_field_changed.emit(selected_id, "fill", c.to_html(false), false)
	)
	var bc := ColorPickerButton.new()
	bc.color = Color.from_string(str(elem.get("border_color", "#FFFFFF")), Color("#FFFFFF"))
	bc.custom_minimum_size = Vector2(0, 26)
	bc.edit_alpha = false
	_field(grid, "Border", bc)
	bc.color_changed.connect(func(c):
		if _updating: return
		elem["border_color"] = c.to_html(false)
		element_field_changed.emit(selected_id, "border_color", c.to_html(false), false)
	)
	var bw := _spin(float(elem.get("border_width", 0.0)), 0.5, 0.0, 80.0)
	_field(grid, "Border px", bw)
	bw.value_changed.connect(func(v): _set_num(elem, "border_width", v))
	var rad := _spin(float(elem.get("radius", 0.0)), 1.0, 0.0, 500.0)
	_field(grid, "Radius", rad)
	rad.value_changed.connect(func(v): _set_num(elem, "radius", int(v)))
	var shadow := CheckBox.new()
	shadow.text = "Soft shadow"
	shadow.button_pressed = bool(elem.get("shadow", false))
	_field(grid, "Shadow", shadow)
	shadow.toggled.connect(func(on):
		if _updating: return
		elem["shadow"] = on
		element_field_changed.emit(selected_id, "shadow", on, true)
	)

func _build_sticker(elem: Dictionary) -> void:
	var box := _section("Sticker", Color("#FF6A45"))
	var grid := _grid(box)
	var asset := LineEdit.new()
	asset.text = str(elem.get("asset", ""))
	asset.editable = false
	asset.tooltip_text = "Use the Assets tab to add other artwork"
	_field(grid, "Asset", asset)
	var ow := _spin(float(elem.get("outline_width", 10.0)), 0.5, 0.0, 60.0)
	_field(grid, "Outline px", ow, "Alpha-aware white outline")
	ow.value_changed.connect(func(v): _set_num(elem, "outline_width", v))
	var flip := CheckBox.new()
	flip.text = "Flip horizontally"
	flip.button_pressed = bool(elem.get("flip_h", false))
	_field(grid, "Flip", flip)
	flip.toggled.connect(func(on):
		if _updating: return
		elem["flip_h"] = on
		element_field_changed.emit(selected_id, "flip_h", on, false)
	)
	var shadow := CheckBox.new()
	shadow.text = "Soft shadow"
	shadow.button_pressed = bool(elem.get("shadow", true))
	_field(grid, "Shadow", shadow)
	shadow.toggled.connect(func(on):
		if _updating: return
		elem["shadow"] = on
		element_field_changed.emit(selected_id, "shadow", on, false)
	)

func _build_arrow(elem: Dictionary) -> void:
	var box := _section("Arrow", Color("#E9C46A"))
	var grid := _grid(box)
	var label := LineEdit.new()
	label.text = str(elem.get("label", ""))
	_field(grid, "Label", label)
	label.text_changed.connect(func(t):
		if _updating: return
		elem["label"] = t
		element_field_changed.emit(selected_id, "label", t, false)
	)
	var col := ColorPickerButton.new()
	col.color = Color.from_string(str(elem.get("color", "#FF5A36")), Color("#FF5A36"))
	col.custom_minimum_size = Vector2(0, 26)
	col.edit_alpha = false
	_field(grid, "Colour", col)
	col.color_changed.connect(func(c):
		if _updating: return
		elem["color"] = c.to_html(false)
		element_field_changed.emit(selected_id, "color", c.to_html(false), false)
	)
	var stroke := _spin(float(elem.get("stroke", 4.0)), 0.5, 0.5, 30.0)
	_field(grid, "Stroke", stroke)
	stroke.value_changed.connect(func(v): _set_num(elem, "stroke", v))
	var bend := _spin(float(elem.get("bend", 0.0)), 0.01, -1.0, 1.0)
	_field(grid, "Bend", bend)
	bend.value_changed.connect(func(v): _set_num(elem, "bend", v))
	var hs := _spin(float(elem.get("head_size", 20.0)), 1.0, 4.0, 80.0)
	_field(grid, "Head", hs)
	hs.value_changed.connect(func(v): _set_num(elem, "head_size", v))

func _build_chart(elem: Dictionary) -> void:
	var box := _section("Chart", Color("#62AEDA"))
	var grid := _grid(box)
	var types := ["bar", "progress", "counter"]
	var opt := OptionButton.new()
	for t in types:
		opt.add_item(t.capitalize())
		if str(elem.get("chart_type", "bar")) == t:
			opt.select(opt.item_count - 1)
	_field(grid, "Type", opt)
	opt.item_selected.connect(func(i):
		if _updating: return
		elem["chart_type"] = types[i]
		element_field_changed.emit(selected_id, "chart_type", types[i], true)
	)
	var title := LineEdit.new()
	title.text = str(elem.get("title", ""))
	_field(grid, "Title", title)
	title.text_changed.connect(func(t):
		if _updating: return
		elem["title"] = t
		element_field_changed.emit(selected_id, "title", t, false)
	)
	var caption := LineEdit.new()
	caption.text = str(elem.get("caption", ""))
	_field(grid, "Caption", caption)
	caption.text_changed.connect(func(t):
		if _updating: return
		elem["caption"] = t
		element_field_changed.emit(selected_id, "caption", t, false)
	)
	var maxv := _spin(float(elem.get("max_value", 100.0)), 1.0, 0.0, 100000.0)
	_field(grid, "Max value", maxv)
	maxv.value_changed.connect(func(v): _set_num(elem, "max_value", v))
	var vals := TextEdit.new()
	vals.custom_minimum_size = Vector2(0, 48)
	var lines: Array = []
	for v in elem.get("values", []):
		if v is Array and v.size() >= 2:
			lines.append("%s: %s" % [str(v[0]), str(v[1])])
	vals.text = "\n".join(lines)
	vals.tooltip_text = "One row per bar: label: value"
	_field(grid, "Values", vals)
	vals.text_changed.connect(func():
		if _updating: return
		var out: Array = []
		for line in vals.text.split("\n"):
			var bits: PackedStringArray = line.split(":", false, 1)
			if bits.size() >= 2 and bits[1].strip_edges().is_valid_float():
				out.append([bits[0].strip_edges(), float(bits[1])])
		elem["values"] = out
		element_field_changed.emit(selected_id, "values", out, false)
	)

func _build_character(elem: Dictionary) -> void:
	var box := _section("Character", Color("#B79CED"))
	var grid := _grid(box)
	var mode := OptionButton.new()
	mode.add_item("Full figure", 0)
	mode.add_item("Torso cutaway", 1)
	mode.select(1 if str(elem.get("mode", "torso")) == "torso" else 0)
	_field(grid, "Mode", mode)
	mode.item_selected.connect(func(i):
		if _updating: return
		elem["mode"] = "torso" if i == 1 else "full"
		element_field_changed.emit(selected_id, "mode", elem["mode"], true)
	)
	var wl := HSlider.new()
	wl.min_value = 0.0
	wl.max_value = 1.0
	wl.step = 0.01
	wl.value = float(elem.get("water_level", 0.0))
	wl.custom_minimum_size = Vector2(0, 26)
	_field(grid, "Water level", wl)
	wl.value_changed.connect(func(v): _set_num(elem, "water_level", v))
	var sc := _spin(float(elem.get("sodium_count", 8)), 1.0, 0, 80)
	_field(grid, "Na+ count", sc)
	sc.value_changed.connect(func(v): _set_num(elem, "sodium_count", int(v), true))
	var label := LineEdit.new()
	label.text = str(elem.get("label", ""))
	_field(grid, "Label", label)
	label.text_changed.connect(func(t):
		if _updating: return
		elem["label"] = t
		element_field_changed.emit(selected_id, "label", t, false)
	)

func _build_vessel(elem: Dictionary) -> void:
	var box := _section("Vessel", Color("#E76F8A"))
	var grid := _grid(box)
	var flow := _spin(float(elem.get("flow", 0.0)), 0.1, 0.0, 10000.0)
	_field(grid, "Flow", flow, "Deterministic cell travel offset")
	flow.value_changed.connect(func(v): _set_num(elem, "flow", v))
	var bulge := HSlider.new()
	bulge.min_value = 0.0
	bulge.max_value = 0.8
	bulge.step = 0.01
	bulge.value = float(elem.get("bulge", 0.0))
	bulge.custom_minimum_size = Vector2(0, 26)
	_field(grid, "Bulge", bulge)
	bulge.value_changed.connect(func(v): _set_num(elem, "bulge", v))
	var cells := _spin(float(elem.get("cell_count", 20)), 1.0, 1, 80)
	_field(grid, "Cells", cells)
	cells.value_changed.connect(func(v): _set_num(elem, "cell_count", int(v), true))

func _build_gauge(elem: Dictionary) -> void:
	var box := _section("Gauge", Color("#FF6A45"))
	var grid := _grid(box)
	var value := HSlider.new()
	value.min_value = 0.0
	value.max_value = 1.0
	value.step = 0.01
	value.value = float(elem.get("value", 0.5))
	value.custom_minimum_size = Vector2(0, 26)
	_field(grid, "Needle", value)
	value.value_changed.connect(func(v): _set_num(elem, "value", v))
	var caption := LineEdit.new()
	caption.text = str(elem.get("caption", ""))
	_field(grid, "Caption", caption)
	caption.text_changed.connect(func(t):
		if _updating: return
		elem["caption"] = t
		element_field_changed.emit(selected_id, "caption", t, false)
	)
	var card := CheckBox.new()
	card.text = "Card background"
	card.button_pressed = bool(elem.get("card", true))
	_field(grid, "Card", card)
	card.toggled.connect(func(on):
		if _updating: return
		elem["card"] = on
		element_field_changed.emit(selected_id, "card", on, true)
	)
	var title := LineEdit.new()
	title.text = str(elem.get("title", ""))
	_field(grid, "Title", title)
	title.text_changed.connect(func(t):
		if _updating: return
		elem["title"] = t
		element_field_changed.emit(selected_id, "title", t, false)
	)

func _build_animation(elem: Dictionary) -> void:
	var box := _section("Animation", Color("#E9C46A"))
	var tracks: Array = engine.get_tracks_for(selected_id)
	var count_row := HBoxContainer.new()
	var summary := Label.new()
	summary.text = "%d animated property%s · playhead %.2fs (frame %d)" % [tracks.size(), "" if tracks.size() == 1 else "s", current_time, engine.frame_for_time(current_time)]
	summary.add_theme_font_size_override("font_size", 10)
	summary.add_theme_color_override("font_color", Color("#8B98A8"))
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count_row.add_child(summary)
	box.add_child(count_row)

	var addrow := HBoxContainer.new()
	_prop_option = OptionButton.new()
	_prop_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prop_option.custom_minimum_size = Vector2(0, 26)
	var used := {}
	for tr in tracks:
		used[tr.property] = true
	var animatable: Array = elem.get("animatable", ANIMATABLE)
	for p in animatable:
		_prop_option.add_item(str(p) + ("  •" if used.has(p) else ""))
		_prop_option.set_item_metadata(_prop_option.item_count - 1, str(p))
	addrow.add_child(_prop_option)
	var addbtn := Button.new()
	addbtn.text = "+ Key"
	addbtn.custom_minimum_size = Vector2(54, 26)
	addbtn.pressed.connect(func():
		var idx := _prop_option.selected
		if idx >= 0:
			key_add_requested.emit(selected_id, str(_prop_option.get_item_metadata(idx)))
	)
	addrow.add_child(addbtn)
	box.add_child(addrow)

	if not tracks.is_empty():
		var keyall := Button.new()
		keyall.text = "Key current transform + opacity at playhead"
		keyall.add_theme_font_size_override("font_size", 10)
		keyall.pressed.connect(func(): key_all_requested.emit(selected_id))
		box.add_child(keyall)
		for tr in tracks:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 4)
			var dot := ColorRect.new()
			dot.color = Color("#E9C46A")
			dot.custom_minimum_size = Vector2(3, 16)
			row.add_child(dot)
			var nm := Label.new()
			nm.text = tr.property
			nm.add_theme_font_size_override("font_size", 11)
			nm.add_theme_color_override("font_color", Color("#C9D3DF"))
			nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(nm)
			var kc := Label.new()
			kc.text = "%d keys" % tr.keys.size()
			kc.add_theme_font_size_override("font_size", 9)
			kc.add_theme_color_override("font_color", Color("#66717F"))
			row.add_child(kc)
			var go := Button.new()
			go.text = "◎"
			go.tooltip_text = "Jump to first keyframe"
			go.custom_minimum_size = Vector2(24, 20)
			go.add_theme_font_size_override("font_size", 10)
			go.pressed.connect(func():
				if not tr.keys.is_empty():
					status_message.emit("First %s key at %.2fs" % [tr.property, tr.keys[0].time])
			)
			row.add_child(go)
			var del := Button.new()
			del.text = "×"
			del.tooltip_text = "Delete this track"
			del.custom_minimum_size = Vector2(22, 20)
			del.add_theme_color_override("font_color", Color("#FF9B8A"))
			del.pressed.connect(func(): track_deleted.emit(selected_id, tr.property))
			row.add_child(del)
			box.add_child(row)

func _build_camera() -> void:
	var header := HBoxContainer.new()
	var title := Label.new()
	title.text = "CAMERA"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color("#E8EDF3"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var tag := Label.new()
	tag.text = "KEYFRAMED"
	tag.add_theme_font_size_override("font_size", 9)
	tag.add_theme_color_override("font_color", Color("#FFB59E"))
	var tp := PanelContainer.new()
	tp.add_theme_stylebox_override("panel", EditorTheme.padded(Color("#3A1C15"), 3, 6, 2, Color(1, 0.42, 0.27, 0.35), 1))
	tp.add_child(tag)
	header.add_child(tp)
	_content.add_child(header)
	var sub := Label.new()
	sub.text = "Nothing selected. Camera animation lives on @camera tracks."
	sub.add_theme_font_size_override("font_size", 10)
	sub.add_theme_color_override("font_color", Color("#66717F"))
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(sub)

	var cam: Dictionary = engine.evaluate_camera(current_time)
	var pos: Vector2 = cam.get("position", Vector2.ZERO)
	var grid := _grid(_section("Camera at playhead", Color("#62AEDA")))
	var px := _spin(pos.x, 1.0)
	var py := _spin(pos.y, 1.0)
	_field(grid, "Position", _pair_row(px, py))
	px.value_changed.connect(func(v): camera_key_requested.emit("position", [v, py.value]))
	py.value_changed.connect(func(v): camera_key_requested.emit("position", [px.value, v]))
	var zoom := _spin(float(cam.get("zoom", 1.0)), 0.01, 0.1, 8.0)
	_field(grid, "Zoom", zoom)
	zoom.value_changed.connect(func(v): camera_key_requested.emit("zoom", v))
	var rot := _spin(float(cam.get("rotation", 0.0)), 0.1, -45.0, 45.0, "°")
	_field(grid, "Rotation", rot)
	rot.value_changed.connect(func(v): camera_key_requested.emit("rotation", v))

	var keyrow := HBoxContainer.new()
	for p in ["position", "zoom", "rotation"]:
		var b := Button.new()
		b.text = "Key " + p
		b.add_theme_font_size_override("font_size", 10)
		b.pressed.connect(func(): key_add_requested.emit("@camera", p))
		keyrow.add_child(b)
	_content.add_child(keyrow)

	var box := _section("Camera tracks", Color("#E9C46A"))
	var tracks: Array = engine.get_tracks_for("@camera")
	if tracks.is_empty():
		box.add_child(_muted_label("No camera keys. The camera uses the storyboard default."))
	for tr in tracks:
		var row := HBoxContainer.new()
		var nm := Label.new()
		nm.text = tr.property
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.add_theme_font_size_override("font_size", 11)
		row.add_child(nm)
		var kc := Label.new()
		kc.text = "%d keys" % tr.keys.size()
		kc.add_theme_font_size_override("font_size", 9)
		kc.add_theme_color_override("font_color", Color("#66717F"))
		row.add_child(kc)
		var del := Button.new()
		del.text = "×"
		del.custom_minimum_size = Vector2(22, 20)
		del.add_theme_color_override("font_color", Color("#FF9B8A"))
		del.pressed.connect(func(): track_deleted.emit("@camera", tr.property))
		row.add_child(del)
		box.add_child(row)

	var info := _section("Project", Color("#72CE9B"))
	var meta := _muted_label("%s\n%s\n%s · %d×%d · %d fps · %.2fs" % [
		str(project.episode.get("project_name", "")),
		str(project.episode.get("topic", "")),
		str(project.episode.get("brand_name", "")),
		int(project.episode.get("width", 1920)), int(project.episode.get("height", 1080)),
		int(project.episode.get("fps", 30)), float(project.episode.get("duration_seconds", 10.0)),
	])
	info.add_child(meta)
	var canvas := _muted_label("Canvas %d×%d · scene %s" % [
		int(project.episode.get("canvas", {}).get("width", 6000)),
		int(project.episode.get("canvas", {}).get("height", 3000)),
		str(engine.scene_at(current_time).get("name", "—")),
	])
	info.add_child(canvas)

func _muted_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", Color("#8B98A8"))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _set_num(elem: Dictionary, field: String, v: Variant, structural: bool = false) -> void:
	if _updating:
		return
	elem[field] = v
	element_field_changed.emit(selected_id, field, v, structural)

func _set_scale(elem: Dictionary, axis: int, v: float) -> void:
	if _updating:
		return
	var sc = elem.get("scale", [1.0, 1.0])
	if not sc is Array or sc.size() < 2:
		sc = [1.0, 1.0]
	sc[axis] = v
	elem["scale"] = sc
	element_field_changed.emit(selected_id, "scale", sc, false)

static func type_color(type: String) -> Color:
	match type:
		"text": return Color("#62AEDA")
		"shape": return Color("#72CE9B")
		"sticker": return Color("#FF6A45")
		"arrow": return Color("#E9C46A")
		"chart": return Color("#B79CED")
		"character": return Color("#E76F8A")
		"blood_vessel": return Color("#E76F8A")
		"pressure_gauge": return Color("#FF6A45")
		_: return Color("#8B98A8")
