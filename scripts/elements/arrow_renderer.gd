class_name ArrowRenderer
extends ElementRenderer

var label: Label
var label_text: String = ""

func _setup() -> void:
	label = Label.new()
	label.name = "ArrowLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(label)
	_apply_state()

func _apply_state() -> void:
	if label == null:
		return
	label_text = str(prop("label", data.get("label", "")))
	label.text = label_text
	label.visible = not label_text.is_empty()
	if label.visible:
		var font := get_effective_font(label_text, str(data.get("label_weight", "bold")))
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", int(float(data.get("label_size", 30))))
		label.add_theme_color_override("font_color", color_prop("label_color", palette("text", Color("#263746"))))
		var lw := float(data.get("label_width", maxf(180.0, width * 0.6)))
		var lh := float(data.get("label_height", maxf(50.0, height * 0.4)))
		var off := _pair(data.get("label_offset", [0.0, -0.32]))
		label.size = Vector2(lw, lh)
		label.position = Vector2(off.x * width - lw * 0.5, off.y * height - lh * 0.5)
	queue_redraw()

func _pair(v: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if v is Array and v.size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	return fallback

func _draw() -> void:
	var p0 := _pair(data.get("from", [-0.4, 0.2])) * Vector2(width, height)
	var p3 := _pair(data.get("to", [0.4, -0.2])) * Vector2(width, height)
	var bend := float(data.get("bend", 0.0))
	var mid := (p0 + p3) * 0.5
	var dir := (p3 - p0)
	if dir.length() < 0.001:
		return
	var normal := Vector2(-dir.y, dir.x).normalized()
	var ctrl := mid + normal * bend * dir.length()
	var progress := clampf(num("progress", 1.0), 0.0, 1.0)
	var stroke := float(data.get("stroke", 5.0))
	var col := color_prop("color", palette("accent", Color("#FF5A36")))
	var seeded := int(absf(float(str(data.get("id", "arrow")).hash())))
	var pts := PackedVector2Array()
	var segments := 56
	for i in range(segments + 1):
		var t := float(i) / float(segments)
		var q := p0.lerp(ctrl, t).lerp(ctrl.lerp(p3, t), t)
		if bool(data.get("hand_drawn", false)):
			q += normal * sin(t * 15.0 + float(seeded % 31)) * 2.2
		pts.append(q)
	var upto := maxi(2, int(round(progress * segments)) + 1)
	var shown := PackedVector2Array()
	for i in range(mini(upto, pts.size())):
		shown.append(pts[i])
	if shown.size() == 0:
		return
	if bool(data.get("double_stroke", false)):
		var alt := PackedVector2Array()
		for p in shown:
			alt.append(p + normal * 2.0)
		draw_polyline(alt, Color(col, 0.28), maxf(1.0, stroke * 0.45), true)
	draw_polyline(shown, col, stroke, true)
	if bool(data.get("head", true)) and shown.size() >= 2:
		var tip := shown[shown.size() - 1]
		var prev := shown[maxi(0, shown.size() - 5)]
		var tangent := (tip - prev).normalized()
		if tangent == Vector2.ZERO:
			tangent = dir.normalized()
		var head_len := float(data.get("head_size", 22.0))
		if bool(data.get("hand_drawn", false)):
			head_len *= 1.05
		var a := tip - tangent.rotated(0.48) * head_len
		var b := tip - tangent.rotated(-0.48) * head_len
		draw_line(tip, a, col, maxf(2.0, stroke * 0.9), true)
		draw_line(tip, b, col, maxf(2.0, stroke * 0.9), true)
	if bool(data.get("start_dot", false)):
		draw_circle(p0, maxf(3.0, stroke * 0.9), col)
