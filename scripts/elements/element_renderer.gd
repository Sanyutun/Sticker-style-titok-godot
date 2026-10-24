class_name ElementRenderer
extends Node2D
## Base class for every reusable visual element. Renderers are pure views of
## data + evaluated state; they never own animation progression.

const ProjectData = preload("res://scripts/project/project_data.gd")

static var _font_cache: Dictionary = {}
static var _texture_cache: Dictionary = {}

var data: Dictionary = {}
var project = null
var state: Dictionary = {}
var last_time: float = 0.0

var base_size := Vector2(200, 120)
var width: float = 200.0
var height: float = 120.0
var opacity: float = 1.0
var rotation_deg: float = 0.0
var scale_xy := Vector2.ONE
var element_hidden: bool = false

func configure(p, d: Dictionary) -> void:
	project = p
	data = d
	base_size = Vector2(float(d.get("width", 200.0)), float(d.get("height", 120.0)))
	width = base_size.x
	height = base_size.y
	z_index = int(d.get("z", 0))
	name = str(d.get("id", "element"))
	rotation_deg = float(d.get("rotation", 0.0))
	opacity = float(d.get("opacity", 1.0))
	var sc = d.get("scale", [1.0, 1.0])
	if sc is Array and sc.size() >= 2:
		scale_xy = Vector2(float(sc[0]), float(sc[1]))
	element_hidden = bool(d.get("hidden", false))
	_setup()

## Subclasses load textures/fonts here.
func _setup() -> void:
	pass

func apply_state(new_state: Dictionary, time: float) -> void:
	state = new_state if new_state != null else {}
	last_time = time
	var p = state.get("position", null)
	if p is Array and p.size() >= 2:
		position = Vector2(float(p[0]), float(p[1]))
	elif p is Vector2:
		position = p
	else:
		position = Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))
	var sc = state.get("scale", null)
	if sc is Array and sc.size() >= 2:
		scale_xy = Vector2(float(sc[0]), float(sc[1]))
	elif sc is float or sc is int:
		scale_xy = Vector2(float(sc), float(sc))
	else:
		var bsc = data.get("scale", [1.0, 1.0])
		scale_xy = Vector2(float(bsc[0]), float(bsc[1])) if bsc is Array and bsc.size() >= 2 else Vector2.ONE
	scale = scale_xy
	rotation_deg = float(state.get("rotation", data.get("rotation", 0.0)))
	rotation = deg_to_rad(rotation_deg)
	opacity = clampf(float(state.get("opacity", data.get("opacity", 1.0))), 0.0, 1.0)
	element_hidden = bool(data.get("hidden", false))
	width = maxf(0.01, float(state.get("width", data.get("width", base_size.x))))
	height = maxf(0.01, float(state.get("height", data.get("height", base_size.y))))
	modulate.a = opacity
	visible = (not element_hidden) and opacity > 0.002
	_apply_state()
	queue_redraw()

func _apply_state() -> void:
	pass

func get_size() -> Vector2:
	return Vector2(width, height)

func get_local_rect() -> Rect2:
	return Rect2(-width * 0.5, -height * 0.5, width, height)

func prop(name: String, fallback: Variant = null) -> Variant:
	if state.has(name):
		return state[name]
	return data.get(name, fallback)

func num(name: String, fallback: float = 0.0) -> float:
	var v = prop(name, fallback)
	if v is float or v is int:
		return float(v)
	return fallback

func vec(name: String, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	var v = prop(name, null)
	if v is Array and v.size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	if v is Vector2:
		return v
	return fallback

func color_prop(name: String, fallback: Color = Color.WHITE) -> Color:
	var v = prop(name, null)
	if v is Color:
		return v
	if v is String and v.begins_with("#"):
		return Color.from_string(v, fallback)
	return fallback

func palette(key: String, fallback: Color = Color.WHITE) -> Color:
	if project != null:
		return project.palette_color(key, fallback)
	return fallback

func style_value(key: String, fallback: Variant = null) -> Variant:
	if project != null:
		return project.style_value(key, fallback)
	return fallback

static func load_texture_cached(abs_path: String) -> Texture2D:
	if abs_path.is_empty():
		return null
	if _texture_cache.has(abs_path):
		return _texture_cache[abs_path]
	if not FileAccess.file_exists(abs_path):
		return null
	var img := Image.new()
	var err := img.load(abs_path)
	if err != OK:
		return null
	var tex := ImageTexture.create_from_image(img)
	_texture_cache[abs_path] = tex
	return tex

func load_texture(path: String) -> Texture2D:
	if project == null:
		return null
	return load_texture_cached(project.resolve_asset(path))

static func font_cached(path: String) -> FontFile:
	if path.is_empty():
		return null
	if _font_cache.has(path):
		return _font_cache[path]
	var f := ProjectData.load_font(path)
	if f != null:
		_font_cache[path] = f
	return f

func load_font(path: String) -> FontFile:
	return font_cached(path)

func has_cjk(s: String) -> bool:
	for i in range(s.length()):
		var c := s.unicode_at(i)
		if (c >= 0x3400 and c <= 0x9FFF) or (c >= 0xF900 and c <= 0xFAFF):
			return true
	return false

func has_myanmar(s: String) -> bool:
	for i in range(s.length()):
		var c := s.unicode_at(i)
		if c >= 0x1000 and c <= 0x109F:
			return true
	return false

func get_effective_font(text: String, weight: String = "regular") -> Font:
	var explicit := str(data.get("font", ""))
	if not explicit.is_empty():
		var f := load_font(explicit)
		if f != null:
			return f
	if has_myanmar(text):
		var my := str(style_value("font_myanmar", ""))
		if not my.is_empty():
			var fm := load_font(my)
			if fm != null:
				return fm
	if has_cjk(text):
		var cjk := str(style_value("font_cjk", ""))
		if not cjk.is_empty():
			var fc := load_font(cjk)
			if fc != null:
				return fc
	var path := str(style_value("font_bold" if weight == "bold" else "font_regular", ""))
	var font := load_font(path)
	if font != null:
		return font
	return ThemeDB.fallback_font

func draw_missing_asset(center: Vector2 = Vector2.ZERO) -> void:
	var r := Rect2(center - Vector2(width, height) * 0.35, Vector2(width, height) * 0.7)
	draw_rect(r, Color("#3A2528"), true)
	draw_rect(r, Color("#FF5A36"), false, 3.0)
	draw_line(r.position, r.end, Color("#FF5A36"), 2.0)
	draw_line(Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), Color("#FF5A36"), 2.0)
	var font := ThemeDB.fallback_font
	draw_string(font, center + Vector2(-width * 0.30, 6), "MISSING ASSET", HORIZONTAL_ALIGNMENT_LEFT, width * 0.6, 22, Color("#FFD7CE"))
