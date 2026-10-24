class_name BloodVesselRenderer
extends ElementRenderer
## Simplified, explicitly illustrative vessel cutaway. Moving cells are
## computed from timestamp + fixed hash, never from frame count.

const TimelineEngine = preload("res://scripts/animation/timeline_engine.gd")
const SEGMENTS := 84

func _path_point(t: float, amp: float) -> Vector2:
	var x := (-0.5 + t) * width
	var y := sin(t * TAU * 1.15 + 0.4) * height * 0.075 * amp + sin(t * TAU * 2.4) * height * 0.018 * amp
	return Vector2(x, y)

func _path_tangent(t: float, amp: float) -> Vector2:
	var eps := 0.002
	var a := _path_point(t - eps, amp)
	var b := _path_point(t + eps, amp)
	return (b - a).normalized()

func _radius(t: float, bulge: float, base_r: float) -> float:
	var bump := exp(-pow((t - 0.52) / 0.20, 2.0))
	return base_r * (1.0 + bulge * 0.55 * bump)

func _tube_polygon(extra: float, amp: float, bulge: float, base_r: float, t_end: float = 1.0) -> PackedVector2Array:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var count := int(SEGMENTS * t_end)
	for i in range(count + 1):
		var t := float(i) / float(SEGMENTS)
		var p := _path_point(t, amp)
		var n := Vector2(-_path_tangent(t, amp).y, _path_tangent(t, amp).x)
		var r := _radius(t, bulge, base_r) + extra
		left.append(p + n * r)
		right.append(p - n * r)
	var out := PackedVector2Array()
	out.append_array(left)
	for i in range(right.size() - 1, -1, -1):
		out.append(right[i])
	return out

func _draw() -> void:
	var flow := num("flow", float(data.get("flow", 0.0)))
	var bulge := clampf(num("bulge", float(data.get("bulge", 0.0))), -0.4, 0.8)
	var progress := clampf(num("progress", 1.0), 0.02, 1.0)
	var amp := 1.0
	var base_r := height * 0.23
	var wall := maxf(8.0, height * 0.075)
	var wall_col := color_prop("wall_color", palette("blood", Color("#C84C4C")))
	var wall_dark := wall_col.darkened(0.18)
	var lumen_col := color_prop("lumen_color", Color("#F5D9D5"))
	var outline_col := color_prop("outline_color", palette("secondary", Color("#F6F3EC")))
	# shadow
	var shadow_poly := _tube_polygon(wall * 0.5, amp, bulge, base_r, progress)
	for i in range(shadow_poly.size()):
		shadow_poly[i] += Vector2(0, 12)
	draw_colored_polygon(shadow_poly, Color(0.13, 0.17, 0.20, 0.13))
	# outer silhouette / white rim
	draw_colored_polygon(_tube_polygon(wall + 6.0, amp, bulge, base_r, progress), outline_col)
	draw_colored_polygon(_tube_polygon(wall, amp, bulge, base_r, progress), wall_col)
	# inner wall shading
	var inner := _tube_polygon(0.0, amp, bulge, base_r, progress)
	draw_colored_polygon(inner, wall_dark)
	var lumen_small := _tube_polygon(-wall * 0.35, amp, bulge, base_r, progress)
	draw_colored_polygon(lumen_small, lumen_col)
	# lighter upper wall highlight
	var highlight := PackedVector2Array()
	var highlight2 := PackedVector2Array()
	var count := int(SEGMENTS * progress)
	for i in range(count + 1):
		var t := float(i) / float(SEGMENTS)
		var p := _path_point(t, amp)
		var tan := _path_tangent(t, amp)
		var n := Vector2(-tan.y, tan.x)
		var r := _radius(t, bulge, base_r)
		highlight.append(p + n * (r - wall * 0.12))
		highlight2.append(p + n * (r - wall * 0.45))
	draw_polyline(highlight, Color(1, 1, 1, 0.30), 3.0, true)
	draw_polyline(highlight2, Color(wall_dark, 0.50), 2.0, true)
	# blood cells, deterministic
	var cell_count := int(data.get("cell_count", 19))
	var seed := int(absf(float(str(data.get("id", "vessel")).hash())))
	var speed := float(data.get("flow_speed", 0.085))
	for i in range(cell_count):
		var phase := TimelineEngine.hash01(seed, i * 7 + 1)
		var lane := TimelineEngine.hash01(seed, i * 7 + 2) * 2.0 - 1.0
		var speed_var := 0.8 + TimelineEngine.hash01(seed, i * 7 + 3) * 0.4
		var t := fposmod(flow * speed * speed_var + phase, 1.0)
		if t > progress:
			continue
		var p := _path_point(t, amp)
		var tan := _path_tangent(t, amp)
		var n := Vector2(-tan.y, tan.x)
		var r := _radius(t, bulge, base_r) - wall * 0.55
		var pos := p + n * lane * r * 0.62
		var rot := tan.angle()
		var cell_r := (8.0 + TimelineEngine.hash01(seed, i * 7 + 4) * 4.0) * (height / 520.0)
		_draw_cell(pos, rot, cell_r, Color("#B53E3E"), Color("#8F2C2C"))
	# plasma specks
	for i in range(26):
		var t2 := fposmod(flow * speed * 1.3 + TimelineEngine.hash01(seed, i * 11 + 40), 1.0)
		if t2 > progress:
			continue
		var pp := _path_point(t2, amp)
		var tt := _path_tangent(t2, amp)
		var nn := Vector2(-tt.y, tt.x)
		var rr := _radius(t2, bulge, base_r) - wall * 0.52
		var lane2 := TimelineEngine.hash01(seed, i * 11 + 41) * 2.0 - 1.0
		var pos2 := pp + nn * lane2 * rr * 0.8
		draw_circle(pos2, 2.4, Color(1, 1, 1, 0.45))

func _draw_cell(pos: Vector2, rot: float, r: float, col: Color, edge: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(24):
		var a := TAU * float(i) / 24.0
		var v := Vector2(cos(a) * r * 1.35, sin(a) * r)
		pts.append(pos + v.rotated(rot))
	draw_colored_polygon(pts, col)
	pts.append(pts[0])
	draw_polyline(pts, edge, 2.0, true)
	# biconcave highlight
	draw_circle(pos + Vector2(-r * 0.3, 0).rotated(rot), r * 0.45, Color(1, 1, 1, 0.18))
