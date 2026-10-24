class_name CharacterRenderer
extends ElementRenderer

const TimelineEngine = preload("res://scripts/animation/timeline_engine.gd")

func _draw() -> void:
	var mode := str(data.get("mode", "full"))
	var skin := color_prop("skin", Color("#F2C9A8"))
	var shirt := color_prop("shirt", palette("primary", Color("#334B60")))
	var hair := color_prop("hair", Color("#27323A"))
	var outline := color_prop("outline", palette("text", Color("#263746")))
	if mode == "torso":
		_draw_torso(skin, shirt, outline)
	else:
		_draw_full(skin, shirt, hair, outline)

func _draw_torso(skin: Color, shirt: Color, outline: Color) -> void:
	var hw := width * 0.5
	var hh := height * 0.5
	var head_r := minf(width * 0.13, height * 0.11)
	var body_w := minf(width * 0.62, height * 0.52)
	var body_top := -hh + head_r * 2.0 + 22.0
	var body_h := height - (body_top + hh)
	var body_rect := Rect2(-body_w * 0.5, body_top, body_w, body_h)
	draw_circle(Vector2(0, -hh + head_r + 4), head_r, skin)
	draw_arc(Vector2(0, -hh + head_r + 4), head_r, 0, TAU, 48, outline, 3.0, true)
	var body_sb := StyleBoxFlat.new()
	body_sb.bg_color = Color("#F7F4EC")
	body_sb.border_color = outline
	body_sb.set_border_width_all(5)
	body_sb.corner_radius_top_left = int(body_w * 0.34)
	body_sb.corner_radius_top_right = int(body_w * 0.34)
	body_sb.corner_radius_bottom_left = int(body_w * 0.18)
	body_sb.corner_radius_bottom_right = int(body_w * 0.18)
	draw_style_box(body_sb, body_rect)
	var level := clampf(num("water_level", float(data.get("water_level", 0.0))), 0.0, 1.0)
	if level > 0.001:
		var water_h := body_h * level
		var water_rect := Rect2(body_rect.position.x + 13, body_rect.end.y - water_h, body_w - 26, water_h - 10)
		var wsb := StyleBoxFlat.new()
		wsb.bg_color = Color(palette("water", Color("#7FB9D8")), 0.78)
		wsb.corner_radius_top_left = 24
		wsb.corner_radius_top_right = 24
		wsb.corner_radius_bottom_left = int(body_w * 0.14)
		wsb.corner_radius_bottom_right = int(body_w * 0.14)
		draw_style_box(wsb, water_rect)
		var wave := PackedVector2Array()
		for i in range(33):
			var x := water_rect.position.x + water_rect.size.x * float(i) / 32.0
			var y := water_rect.position.y + sin(float(i) * 0.55 + last_time * 2.2) * 4.0
			wave.append(Vector2(x, y))
		draw_polyline(wave, Color(1, 1, 1, 0.55), 2.5, true)
	var count := int(data.get("sodium_count", 8))
	var seed := int(absf(float(str(data.get("id", "body")).hash())))
	for i in range(count):
		var fx := TimelineEngine.hash01(seed, i * 3 + 1)
		var fy := TimelineEngine.hash01(seed, i * 3 + 2)
		var pos := Vector2(body_rect.position.x + 34 + fx * (body_w - 68), body_rect.position.y + 30 + fy * (body_h - 60))
		var pop := clampf((level - fy * 0.6) * 8.0, 0.0, 1.0)
		if pop > 0.0:
			draw_circle(pos, 9.0 * pop, Color(palette("accent", Color("#FF5A36")), 0.8))
			draw_circle(pos, 4.5 * pop, Color(1, 1, 1, 0.9))
	var label := str(data.get("label", ""))
	if not label.is_empty():
		var font := get_effective_font(label, "bold")
		draw_string(font, Vector2(-hw, hh - 8), label.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, width, int(data.get("label_size", 22)), Color(outline, 0.75))

func _draw_full(skin: Color, shirt: Color, hair: Color, outline: Color) -> void:
	var hw := width * 0.5
	var hh := height * 0.5
	var head_r := minf(width, height) * 0.15
	var head_pos := Vector2(0, -hh + head_r + 4)
	# shadow
	draw_set_transform(Vector2(0, hh - 6), 0, Vector2(1.0, 0.25))
	draw_circle(Vector2.ZERO, width * 0.20, Color(0, 0, 0, 0.12))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# legs
	var hip_y := hh - height * 0.28
	draw_line(Vector2(-width * 0.10, hip_y), Vector2(-width * 0.13, hh - 4), Color("#3A4A56"), maxf(8.0, width * 0.055), true)
	draw_line(Vector2(width * 0.10, hip_y), Vector2(width * 0.13, hh - 4), Color("#3A4A56"), maxf(8.0, width * 0.055), true)
	# torso
	var torso := Rect2(-width * 0.18, head_pos.y + head_r * 0.9, width * 0.36, height * 0.46)
	var sb := StyleBoxFlat.new()
	sb.bg_color = shirt
	sb.corner_radius_top_left = int(width * 0.10)
	sb.corner_radius_top_right = int(width * 0.10)
	sb.corner_radius_bottom_left = int(width * 0.06)
	sb.corner_radius_bottom_right = int(width * 0.06)
	draw_style_box(sb, torso)
	# arms
	var shoulder := torso.position.y + torso.size.y * 0.16
	draw_line(Vector2(torso.position.x + 6, shoulder), Vector2(torso.position.x - width * 0.13, shoulder + height * 0.22), skin, maxf(7.0, width * 0.042), true)
	draw_line(Vector2(torso.end.x - 6, shoulder), Vector2(torso.end.x + width * 0.13, shoulder + height * 0.22), skin, maxf(7.0, width * 0.042), true)
	# neck + head
	draw_rect(Rect2(-width * 0.045, head_pos.y + head_r * 0.7, width * 0.09, head_r * 0.7), skin, true)
	draw_circle(head_pos, head_r, skin)
	draw_arc(head_pos, head_r, 0, TAU, 48, outline, 3.0, true)
	# hair
	draw_arc(head_pos, head_r * 0.98, PI * 0.9, PI * 2.1, 32, hair, maxf(6.0, head_r * 0.5), true)
	# face
	var eye_y := head_pos.y - head_r * 0.05
	var eye_dx := head_r * 0.38
	draw_circle(head_pos + Vector2(-eye_dx, eye_y), maxf(2.0, head_r * 0.10), outline)
	draw_circle(head_pos + Vector2(eye_dx, eye_y), maxf(2.0, head_r * 0.10), outline)
	var expression := str(data.get("expression", "neutral"))
	var mouth_y := head_pos.y + head_r * 0.38
	if expression == "concerned":
		draw_arc(head_pos + Vector2(0, mouth_y + 5), head_r * 0.24, PI * 1.15, PI * 1.85, 16, outline, 2.5, true)
	elif expression == "smile":
		draw_arc(head_pos + Vector2(0, mouth_y - 4), head_r * 0.24, PI * 0.15, PI * 0.85, 16, outline, 2.5, true)
	else:
		draw_line(head_pos + Vector2(-head_r * 0.20, mouth_y), head_pos + Vector2(head_r * 0.20, mouth_y), outline, 2.5, true)
