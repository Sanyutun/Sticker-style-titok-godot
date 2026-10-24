class_name SubtitleOverlay
extends Control
## Burned-in subtitle layer. Subtitles are project data, not hard-coded.

var label: Label
var bg_rect := Rect2()
var accent_color := Color("#FF5A36")
var bg_color := Color(0.07, 0.10, 0.13, 0.82)
var margin := 72.0

func setup(frame_size: Vector2, font: Font, p_margin: float) -> void:
	margin = p_margin
	position = Vector2.ZERO
	size = frame_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	label = Label.new()
	label.position = Vector2.ZERO
	label.size = size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 31)
	label.add_theme_color_override("font_color", Color("#FFFFFF"))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.45))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	var strip_w := minf(frame_size.x - margin * 2.0, 1560.0)
	var strip_h := 108.0
	bg_rect = Rect2((frame_size.x - strip_w) * 0.5, frame_size.y - margin - strip_h - 26.0, strip_w, strip_h)
	label.position = bg_rect.position + Vector2(26, 0)
	label.size = Vector2(bg_rect.size.x - 52, bg_rect.size.y)
	visible = false

func set_subtitle(text: String, p_accent: Color) -> void:
	accent_color = p_accent
	var clean := text.strip_edges()
	visible = not clean.is_empty()
	label.text = clean
	queue_redraw()

func _draw() -> void:
	if not visible:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.set_corner_radius_all(14)
	sb.shadow_color = Color(0.05, 0.07, 0.09, 0.18)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 4)
	draw_style_box(sb, bg_rect)
	draw_rect(Rect2(bg_rect.position.x + 1, bg_rect.position.y + 20, 5, bg_rect.size.y - 40), accent_color, true)
