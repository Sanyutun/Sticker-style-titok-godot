class_name ShapeRenderer
extends ElementRenderer

func _apply_state() -> void:
	pass

func _draw() -> void:
	var shape := str(data.get("shape", "rect"))
	var fill := color_prop("fill", color_prop("color", palette("primary")))
	var border := color_prop("border_color", Color(0, 0, 0, 0))
	var bw := num("border_width", 0.0)
	var shadow_on := bool(data.get("shadow", false)) and bool(style_value("shadow_enabled", true))
	if shadow_on:
		var off := Vector2(float(style_value("shadow_offset_x", 0.0)), float(style_value("shadow_offset_y", 8.0)))
		var sc := Color(palette("text", Color.BLACK), float(style_value("shadow_alpha", 0.2)) * 0.65)
		for i in range(3):
			var soft := off + Vector2(i - 1, i - 1) * 2.0
			_draw_shape(shape, sc, Color(0, 0, 0, 0), 0.0, soft, 0.0)
	_draw_shape(shape, fill, border, bw, Vector2.ZERO, num("progress", 1.0))

func _draw_shape(shape: String, fill: Color, border: Color, bw: float, offset: Vector2, progress: float) -> void:
	var hw := width * 0.5
	var hh := height * 0.5
	var rect := Rect2(Vector2(-hw, -hh) + offset, Vector2(width, height))
	match shape:
		"rect", "rounded_rect":
			var radius := int(data.get("radius", 0))
			if shape == "rounded_rect" and radius <= 0:
				radius = int(minf(width, height) * 0.08)
			if radius > 0:
				var sb := StyleBoxFlat.new()
				sb.bg_color = fill
				sb.corner_radius_top_left = radius
				sb.corner_radius_top_right = radius
				sb.corner_radius_bottom_left = radius
				sb.corner_radius_bottom_right = radius
				if bw > 0:
					sb.border_color = border
					sb.set_border_width_all(int(bw))
				draw_style_box(sb, rect)
			else:
				draw_rect(rect, fill, true)
				if bw > 0:
					draw_rect(rect, border, false, bw)
		"circle", "ellipse":
			var pts := PackedVector2Array()
			for i in range(72):
				var a := TAU * float(i) / 72.0
				pts.append(offset + Vector2(cos(a) * hw, sin(a) * hh))
			if fill.a > 0.001:
				draw_colored_polygon(pts, fill)
			if bw > 0:
				var pts2 := pts.duplicate()
				pts2.append(pts[0])
				draw_polyline(pts2, border, bw, true)
		"line":
			var a := Vector2(-hw, 0) + offset
			var b := Vector2(hw, 0) + offset
			var e := a.lerp(b, clampf(progress, 0.0, 1.0))
			if bw <= 0:
				bw = 4.0
			draw_line(a, e, fill, bw, true)
		"polygon", "path":
			var raw = data.get("points", [])
			if raw is Array and raw.size() >= 2:
				var pts3 := PackedVector2Array()
				for p in raw:
					if p is Array and p.size() >= 2:
						pts3.append(offset + Vector2(float(p[0]) * width, float(p[1]) * height))
				if shape == "polygon":
					if fill.a > 0.001:
						draw_colored_polygon(pts3, fill)
					if bw > 0:
						var closed := pts3.duplicate()
						closed.append(pts3[0])
						draw_polyline(closed, border, bw, true)
				else:
					var count := maxi(2, int(ceil(clampf(progress, 0.0, 1.0) * (pts3.size() - 1))) + 1)
					var cut := PackedVector2Array()
					for i in range(mini(count, pts3.size())):
						cut.append(pts3[i])
					if cut.size() >= 2:
						draw_polyline(cut, fill, maxf(2.0, bw), true)
		_:
			draw_rect(rect, fill, true)
