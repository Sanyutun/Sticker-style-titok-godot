class_name TextRenderer
extends ElementRenderer

var label: Label
var current_text: String = ""
var bg_style: String = "none"
var font_missing: bool = false

func _setup() -> void:
	label = Label.new()
	label.name = "Text"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = false
	label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	add_child(label)
	_apply_state()

func _apply_state() -> void:
	if label == null:
		return
	var raw_text := str(prop("text", data.get("text", "")))
	if project != null:
		raw_text = raw_text.replace("{{brand_name}}", str(project.episode.get("brand_name", "")))
		raw_text = raw_text.replace("{{project_name}}", str(project.episode.get("project_name", "")))
		raw_text = raw_text.replace("{{topic}}", str(project.episode.get("topic", "")))
	if data.get("uppercase", false):
		raw_text = raw_text.to_upper()
	if bool(data.get("count_up", false)) and (state.has("value") or data.has("value")):
		var v := num("value", float(data.get("value", 0.0)))
		var fmt := str(data.get("format", "{v}"))
		var num_text := fmt.replace("{v}", _format_number(v)).replace("{value}", _format_number(v))
		raw_text = num_text
	current_text = raw_text
	label.text = raw_text
	var font := get_effective_font(raw_text, str(data.get("font_weight", "regular")))
	font_missing = font == ThemeDB.fallback_font and not str(data.get("font", "")).is_empty()
	label.add_theme_font_override("font", font)
	var fs := int(num("text_size", float(data.get("font_size", 64.0))))
	label.add_theme_font_size_override("font_size", maxi(4, fs))
	label.add_theme_color_override("font_color", color_prop("color", palette("text", Color("#263746"))))
	label.add_theme_constant_override("line_spacing", int(data.get("line_spacing", 0)))
	label.add_theme_constant_override("outline_size", int(data.get("text_outline", 0)))
	label.add_theme_color_override("font_outline_color", color_prop("text_outline_color", palette("secondary", Color.WHITE)))
	if bool(data.get("text_shadow", false)):
		label.add_theme_constant_override("shadow_offset_x", int(data.get("text_shadow_x", 3)))
		label.add_theme_constant_override("shadow_offset_y", int(data.get("text_shadow_y", 4)))
		label.add_theme_color_override("font_shadow_color", color_prop("text_shadow_color", Color(0, 0, 0, 0.25)))
	var align := str(data.get("align", "left"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if align == "left" else (HORIZONTAL_ALIGNMENT_CENTER if align == "center" else HORIZONTAL_ALIGNMENT_RIGHT)
	var valign := str(data.get("valign", "center"))
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP if valign == "top" else (VERTICAL_ALIGNMENT_BOTTOM if valign == "bottom" else VERTICAL_ALIGNMENT_CENTER)
	label.position = Vector2(-width * 0.5, -height * 0.5)
	label.size = Vector2(width, height)
	var reveal := clampf(num("reveal", 1.0), 0.0, 1.0)
	label.visible_characters = int(round(float(label.text.length()) * reveal)) if reveal < 0.9999 else -1
	bg_style = str(data.get("bg_style", "none"))
	queue_redraw()

func _format_number(v: float) -> String:
	if bool(data.get("count_integer", false)):
		return str(int(round(v)))
	var decimals := int(data.get("decimals", 0))
	return ("%." + str(decimals) + "f") % v

func _draw() -> void:
	if bg_style == "none":
		return
	var rect := Rect2(-width * 0.5, -height * 0.5, width, height)
	var bg := color_prop("bg_color", palette("accent", Color("#FF5A36")))
	var border := color_prop("bg_border", Color(0, 0, 0, 0))
	var bw := float(data.get("bg_border_width", 0))
	if bg_style == "circle":
		var radius := minf(width, height) * 0.5
		draw_circle(Vector2.ZERO, radius, bg)
		if bw > 0:
			draw_arc(Vector2.ZERO, radius - bw * 0.5, 0, TAU, 96, border, bw, true)
	elif bg_style == "pill":
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg
		sb.corner_radius_top_left = int(height * 0.5)
		sb.corner_radius_top_right = int(height * 0.5)
		sb.corner_radius_bottom_left = int(height * 0.5)
		sb.corner_radius_bottom_right = int(height * 0.5)
		if bw > 0:
			sb.border_color = border
			sb.set_border_width_all(int(bw))
		draw_style_box(sb, rect)
	elif bg_style == "underline":
		var bar_h := maxf(6.0, height * 0.055)
		draw_rect(Rect2(rect.position.x, rect.end.y - bar_h, width, bar_h), bg, true)
	else:
		var radius := int(data.get("bg_radius", 0))
		var sb2 := StyleBoxFlat.new()
		sb2.bg_color = bg
		sb2.corner_radius_top_left = radius
		sb2.corner_radius_top_right = radius
		sb2.corner_radius_bottom_left = radius
		sb2.corner_radius_bottom_right = radius
		if bw > 0:
			sb2.border_color = border
			sb2.set_border_width_all(int(bw))
		draw_style_box(sb2, rect)
