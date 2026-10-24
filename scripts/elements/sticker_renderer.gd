class_name StickerRenderer
extends ElementRenderer
## Photographic/illustration cutout with alpha-aware white sticker outline and
## soft shadow. The outline follows the image silhouette, not its rectangle.

static var _shader: Shader = null

var sprite: Sprite2D
var texture: Texture2D
var missing: bool = false

func _setup() -> void:
	if _shader == null:
		_shader = load("res://resources/sticker_outline.gdshader")
	sprite = Sprite2D.new()
	sprite.name = "Cutout"
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	sprite.material = mat
	add_child(sprite)
	_reload_texture()
	_apply_state()

func _reload_texture() -> void:
	texture = load_texture(str(data.get("asset", "")))
	missing = texture == null
	sprite.texture = texture
	sprite.visible = not missing

func _apply_state() -> void:
	if sprite == null:
		return
	if sprite.texture == null:
		sprite.visible = false
		return
	sprite.visible = not missing
	var tex_size := sprite.texture.get_size()
	sprite.scale = Vector2(width / maxf(1.0, tex_size.x), height / maxf(1.0, tex_size.y))
	sprite.flip_h = bool(data.get("flip_h", false))
	var mat := sprite.material as ShaderMaterial
	if mat == null:
		return
	var outline_px := num("outline_width", float(style_value("sticker_outline_px", 10.0)))
	var outline_color := color_prop("outline_color", Color.from_string(str(style_value("sticker_outline_color", "#FFFFFF")), Color.WHITE))
	var shadow_on := bool(style_value("shadow_enabled", true)) and bool(data.get("shadow", true))
	var shadow_alpha := float(style_value("shadow_alpha", 0.20))
	var shadow_color := color_prop("shadow_color", Color.from_string(str(style_value("shadow_color", "#263746")), Color("#263746")))
	var world_scale_x := maxf(0.001, absf(scale_xy.x))
	var world_scale_y := maxf(0.001, absf(scale_xy.y))
	var outline_uv := Vector2(outline_px / maxf(1.0, width * world_scale_x), outline_px / maxf(1.0, height * world_scale_y))
	var offset := Vector2(float(style_value("shadow_offset_x", 0.0)), float(style_value("shadow_offset_y", 8.0)))
	var shadow_uv := -Vector2(offset.x / maxf(1.0, width * world_scale_x), offset.y / maxf(1.0, height * world_scale_y))
	mat.set_shader_parameter("outline_uv", outline_uv)
	mat.set_shader_parameter("outline_color", outline_color)
	mat.set_shader_parameter("outline_enabled", 1.0 if outline_px > 0.0 else 0.0)
	mat.set_shader_parameter("shadow_enabled", 1.0 if shadow_on else 0.0)
	mat.set_shader_parameter("shadow_color", Color(shadow_color.r, shadow_color.g, shadow_color.b, shadow_alpha))
	mat.set_shader_parameter("shadow_offset_uv", shadow_uv)
	mat.set_shader_parameter("shadow_softness", clampf(float(style_value("shadow_blur_px", 12.0)) / maxf(2.0, outline_px), 0.4, 3.0))

func _draw() -> void:
	if missing:
		draw_missing_asset()
