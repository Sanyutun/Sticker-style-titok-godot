class_name ChartRenderer
extends ElementRenderer

func _draw() -> void:
	var chart_type := str(data.get("chart_type", "bar"))
	var font := get_effective_font(str(data.get("title", "")), str(data.get("font_weight", "bold")))
	var regular := get_effective_font("", "regular")
	var text_col := color_prop("text_color", palette("text", Color("#263746")))
	var muted := color_prop("muted_color", palette("muted", Color("#7A8C99")))
	var accent := color_prop("color", palette("accent", Color("#FF5A36")))
	var primary := color_prop("bar_color", palette("primary", Color("#334B60")))
	var reveal := clampf(num("progress", 1.0), 0.0, 1.0)
	var title := str(data.get("title", ""))
	var caption := str(data.get("caption", ""))
	var hw := width * 0.5
	var hh := height * 0.5
	var top := -hh
	if not title.is_empty():
		draw_string(font, Vector2(-hw, top + 30), title.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, width, int(data.get("title_size", 28)), text_col)
		top += 46
	if chart_type == "counter":
		var v := num("value", float(data.get("value", 0.0)))
		var txt := str(data.get("format", "{v}")).replace("{v}", _fmt(v)).replace("{value}", _fmt(v))
		var fs := int(data.get("value_size", 120))
		draw_string(font, Vector2(-hw, top + fs), txt, HORIZONTAL_ALIGNMENT_CENTER, width, fs, text_col)
		if not caption.is_empty():
			draw_string(regular, Vector2(-hw, -hh + height - 20), caption.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, width, int(data.get("caption_size", 20)), muted)
		return
	if chart_type == "progress":
		var value := clampf(num("value", float(data.get("value", 0.0))), 0.0, 1.0) * reveal
		var bar_h := minf(54.0, height * 0.24)
		var bar_rect := Rect2(-hw, -bar_h * 0.5, width, bar_h)
		draw_rect(bar_rect, color_prop("track_color", Color(primary, 0.13)), true)
		draw_rect(Rect2(-hw, -bar_h * 0.5, width * value, bar_h), accent, true)
		var label := str(data.get("label", ""))
		if not label.is_empty():
			draw_string(font, Vector2(-hw, -bar_h * 0.5 - 16), label.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, width * 0.7, int(data.get("label_size", 26)), text_col)
		if bool(data.get("show_percent", true)):
			var pct := "%d%%" % int(round(value * 100.0))
			draw_string(font, Vector2(hw - 180, -bar_h * 0.5 - 16), pct, HORIZONTAL_ALIGNMENT_RIGHT, 180, int(data.get("label_size", 26)), accent)
		if not caption.is_empty():
			draw_string(regular, Vector2(-hw, bar_h * 0.5 + 34), caption.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, width, int(data.get("caption_size", 18)), muted)
		return

	# Horizontal bar chart
	var vals = data.get("values", [])
	if not vals is Array or vals.is_empty():
		return
	var max_val := float(data.get("max_value", 100.0))
	for v in vals:
		if v is Array and v.size() >= 2:
			max_val = maxf(max_val, absf(float(v[1])))
	max_val = maxf(0.0001, max_val)
	var label_w := width * float(data.get("label_width_ratio", 0.34))
	var bar_area := width - label_w - 90.0
	var row_h := minf(52.0, (height - (48 if not title.is_empty() else 0) - 52) / maxf(1.0, vals.size()))
	var y := top + 20
	var colors := [primary, accent, palette("water", Color("#7FB9D8")), palette("blood", Color("#C84C4C"))]
	var idx := 0
	for v in vals:
		var label := str(v[0])
		var value := float(v[1]) if v.size() >= 2 else 0.0
		var frac := clampf(value / max_val, 0.0, 1.0) * reveal
		draw_string(regular, Vector2(-hw, y + row_h * 0.55), label, HORIZONTAL_ALIGNMENT_LEFT, label_w - 10, int(data.get("label_size", 24)), text_col)
		var bar_x := -hw + label_w
		draw_rect(Rect2(bar_x, y + 8, bar_area, row_h - 18), Color(primary, 0.10), true)
		draw_rect(Rect2(bar_x, y + 8, bar_area * frac, row_h - 18), colors[idx % colors.size()], true)
		if bool(data.get("show_values", true)) and reveal > 0.8:
			var unit := str(data.get("unit", ""))
			var vt := _fmt(value) + unit
			draw_string(font, Vector2(bar_x + bar_area + 12, y + row_h * 0.55), vt, HORIZONTAL_ALIGNMENT_RIGHT, 78, int(data.get("value_size", 22)), text_col)
		y += row_h
		idx += 1
	if bool(data.get("axes", true)):
		draw_line(Vector2(-hw + label_w, y + 4), Vector2(-hw + label_w + bar_area, y + 4), Color(primary, 0.35), 1.5, true)
	if not caption.is_empty():
		draw_string(regular, Vector2(-hw, hh - 6), caption.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, width, int(data.get("caption_size", 18)), muted)

func _fmt(v: float) -> String:
	var decimals := int(data.get("decimals", 0))
	return ("%." + str(decimals) + "f") % v

func _process(_delta: float) -> void:
	# Charts with moving values need redraws; queue_redraw is driven by stage
	# evaluation, but keeping a redraw here is harmless and avoids stale text.
	pass
