class_name PressureGaugeRenderer
extends ElementRenderer
## Illustration-only pressure dial. It deliberately shows no medical units in
## the sample episode; the needle is an explanatory indicator, not a reading.

func _draw() -> void:
	var hw := width * 0.5
	var hh := height * 0.5
	var card := color_prop("card_color", palette("secondary", Color("#F6F3EC")))
	var card_border := color_prop("card_border", Color(1, 1, 1, 0.0))
	var text_col := color_prop("text_color", palette("text", Color("#263746")))
	var muted := color_prop("muted_color", palette("muted", Color("#7A8C99")))
	var accent := color_prop("color", palette("accent", Color("#FF5A36")))
	var primary := color_prop("dial_color", palette("primary", Color("#334B60")))
	var font := get_effective_font("PRESSURE", "bold")
	var regular := get_effective_font("", "regular")
	var radius := minf(width * 0.42, height * 0.42)
	var center := Vector2(0, hh - radius * 0.90)
	# shadow and card
	if bool(data.get("card", true)):
		var off := Vector2(0, 11)
		for i in range(3):
			var sr := Rect2(-hw + 10 + i, -hh + 10 + i, width - 20, height - 20)
			sr.position += off * (0.4 + i * 0.4)
			draw_style_box(_round_rect(sr, 26, Color(0.12, 0.16, 0.19, 0.05)), sr)
		# actual draw
		var sb := StyleBoxFlat.new()
		sb.bg_color = card
		sb.set_corner_radius_all(26)
		if card_border.a > 0:
			sb.border_color = card_border
			sb.set_border_width_all(2)
		draw_style_box(sb, Rect2(-hw + 10, -hh + 10, width - 20, height - 20))
	# dial track
	var start_a := deg_to_rad(135.0)
	var sweep := deg_to_rad(270.0)
	draw_arc(center, radius, start_a, start_a + sweep, 96, Color(primary, 0.16), maxf(14.0, radius * 0.12), true)
	draw_arc(center, radius, start_a + sweep * 0.62, start_a + sweep, 48, Color(accent, 0.75), maxf(14.0, radius * 0.12), true)
	# ticks
	for i in range(28):
		var f := float(i) / 27.0
		var a := start_a + sweep * f
		var major := i % 3 == 0
		var r1 := radius - (22.0 if major else 14.0)
		var r2 := radius + (10.0 if major else 4.0)
		var col := Color(text_col, 0.62 if major else 0.28)
		draw_line(center + Vector2(cos(a), sin(a)) * r1, center + Vector2(cos(a), sin(a)) * r2, col, 3.0 if major else 1.5, true)
	# labels
	draw_string(regular, center + Vector2(-radius, radius * 0.57), str(data.get("low_label", "LOWER")), HORIZONTAL_ALIGNMENT_LEFT, radius, int(maxf(12, radius * 0.11)), Color(muted, 0.9))
	draw_string(regular, center + Vector2(0, radius * 0.57), str(data.get("high_label", "HIGHER")), HORIZONTAL_ALIGNMENT_RIGHT, radius, int(maxf(12, radius * 0.11)), Color(accent, 0.95))
	var value := clampf(num("value", float(data.get("value", 0.5))), 0.0, 1.0)
	var needle_a := start_a + sweep * value
	var needle_len := radius * 0.82
	var tip := center + Vector2(cos(needle_a), sin(needle_a)) * needle_len
	var tail := center - Vector2(cos(needle_a), sin(needle_a)) * radius * 0.14
	draw_line(tail, tip, Color(text_col, 0.90), maxf(5.0, radius * 0.035), true)
	draw_circle(tip, maxf(5.0, radius * 0.04), accent)
	draw_circle(center, radius * 0.075, text_col)
	draw_circle(center, radius * 0.035, card)
	# title / caption
	var title := str(data.get("title", "PRESSURE"))
	draw_string(font, Vector2(-hw + 34, -hh + 54), title.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, width - 68, int(data.get("title_size", 30)), text_col)
	var caption := str(data.get("caption", "ILLUSTRATIVE"))
	if not caption.is_empty():
		draw_string(regular, Vector2(-hw + 34, hh - 34), caption.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, width - 68, int(data.get("caption_size", 17)), muted)
	if bool(data.get("show_value", false)):
		var txt := str(int(round(value * float(data.get("max_value", 100.0)))))
		draw_string(font, Vector2(-hw + 34, hh - 40), txt, HORIZONTAL_ALIGNMENT_RIGHT, width - 68, int(data.get("value_size", 42)), text_color_for_value(accent, text_col, value))

func text_color_for_value(accent: Color, text_col: Color, value: float) -> Color:
	return accent if value > 0.62 else text_col

func _round_rect(rect: Rect2, radius: int, col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	return sb
