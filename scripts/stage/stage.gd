class_name CompositionStage
extends Node2D
## The shared composition renderer used by both the editor preview and the
## export frame renderer. It is a pure function of project data + timestamp.

const TimelineEngine = preload("res://scripts/animation/timeline_engine.gd")
const EditorCameraController = preload("res://scripts/camera/camera_controller.gd")
const CameraPath = preload("res://scripts/camera/camera_path.gd")
const SubtitleOverlay = preload("res://scripts/stage/subtitle_overlay.gd")

const StickerRenderer = preload("res://scripts/elements/sticker_renderer.gd")
const TextRenderer = preload("res://scripts/elements/text_renderer.gd")
const ShapeRenderer = preload("res://scripts/elements/shape_renderer.gd")
const ArrowRenderer = preload("res://scripts/elements/arrow_renderer.gd")
const ChartRenderer = preload("res://scripts/elements/chart_renderer.gd")
const CharacterRenderer = preload("res://scripts/elements/character_renderer.gd")
const BloodVesselRenderer = preload("res://scripts/elements/blood_vessel_renderer.gd")
const PressureGaugeRenderer = preload("res://scripts/elements/pressure_gauge_renderer.gd")

var project = null
var engine = null
var frame_size := Vector2(1920, 1080)
var world: Node2D
var camera := EditorCameraController.new()
var guides: Node2D
var subtitles = null
var element_nodes: Dictionary = {}
var current_time: float = 0.0
var current_camera: Dictionary = {}
var selected_id: String = ""
var editor_mode: bool = true
var show_guides: bool = true
var show_camera_path: bool = true
var show_grid: bool = false
var show_safe_area: bool = true
var show_subtitles: bool = true
var subtitle_language: String = "en"
var preview_scale: float = 1.0
var _viewport_size := Vector2(1920, 1080)
var _font_default: Font = ThemeDB.fallback_font
var _font_small: Font = ThemeDB.fallback_font
var _status_line: String = ""

func _ready() -> void:
	set_process(false)

func build(p_project, p_engine = null) -> void:
	project = p_project
	engine = p_engine if p_engine != null else TimelineEngine.new()
	if p_engine == null:
		engine.setup_from_project(project)
	frame_size = Vector2(float(project.episode.get("width", 1920)), float(project.episode.get("height", 1080)))
	subtitle_language = str(project.episode.get("localization", {}).get("default_language", "en"))
	for child in get_children():
		remove_child(child)
		child.free()
	element_nodes.clear()
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	camera.setup(world, frame_size)
	guides = Node2D.new()
	guides.name = "EditorGuides"
	guides.z_index = 4090
	add_child(guides)
	guides.draw.connect(_draw_guides)
	var font_bold := ElementRenderer.font_cached(str(project.style_value("font_bold", "")))
	_font_default = font_bold if font_bold != null else ThemeDB.fallback_font
	_font_small = ElementRenderer.font_cached(str(project.style_value("font_regular", "")))
	if _font_small == null:
		_font_small = ThemeDB.fallback_font
	subtitles = SubtitleOverlay.new()
	subtitles.name = "Subtitles"
	subtitles.z_index = 4080
	add_child(subtitles)
	subtitles.setup(frame_size, _font_default, float(project.style_value("safe_margin_px", 72.0)))
	var elements: Array = project.storyboard.get("elements", []).duplicate()
	elements.sort_custom(func(a, b):
		var za := int(a.get("z", 0))
		var zb := int(b.get("z", 0))
		if za == zb:
			return project.storyboard["elements"].find(a) < project.storyboard["elements"].find(b)
		return za < zb)
	for elem in elements:
		if not elem is Dictionary:
			continue
		var node = _create_renderer(str(elem.get("type", "shape")))
		node.configure(project, elem)
		node.z_index = int(elem.get("z", 0))
		world.add_child(node)
		element_nodes[str(elem.get("id", ""))] = node
	set_viewport_size(_viewport_size)
	update_subtitles(0.0)
	evaluate(0.0)
	queue_redraw()

func _create_renderer(type: String):
	match type:
		"sticker":
			return StickerRenderer.new()
		"text":
			return TextRenderer.new()
		"shape":
			return ShapeRenderer.new()
		"arrow":
			return ArrowRenderer.new()
		"chart":
			return ChartRenderer.new()
		"character":
			return CharacterRenderer.new()
		"blood_vessel":
			return BloodVesselRenderer.new()
		"pressure_gauge":
			return PressureGaugeRenderer.new()
		_:
			return ShapeRenderer.new()

func set_viewport_size(size: Vector2) -> void:
	_viewport_size = size
	preview_scale = size.x / maxf(1.0, frame_size.x)
	scale = Vector2(size.x / maxf(1.0, frame_size.x), size.y / maxf(1.0, frame_size.y))
	queue_redraw()
	if guides != null:
		guides.queue_redraw()

func set_preview_scale_uniform(s: float) -> void:
	scale = Vector2(s, s)

func evaluate(time: float) -> void:
	if engine == null:
		return
	current_time = time
	var result: Dictionary = engine.evaluate_at_time(time)
	current_camera = result["camera"]
	camera.apply(current_camera)
	var states: Dictionary = result["elements"]
	for id in element_nodes.keys():
		var node = element_nodes[id]
		var element_state: Dictionary = states.get(id, {})
		node.apply_state(element_state, time)
	update_subtitles(time)
	if guides != null:
		guides.queue_redraw()

func update_subtitles(time: float) -> void:
	if subtitles == null or project == null:
		return
	var burn := bool(project.storyboard.get("burn_subtitles", true))
	var active := ""
	var subs = project.storyboard.get("subtitles", {}).get(subtitle_language, [])
	if subs is Array:
		for s in subs:
			if s is Dictionary:
				var st := float(s.get("start", 0.0))
				var en := float(s.get("end", 0.0))
				if time + 0.0001 >= st and time < en:
					active = str(s.get("text", ""))
					break
	subtitles.visible = burn and show_subtitles and not active.is_empty()
	if subtitles.visible:
		subtitles.set_subtitle(active, project.palette_color("accent", Color("#FF5A36")))

func set_selected(id: String) -> void:
	selected_id = id
	if guides != null:
		guides.queue_redraw()

func set_editor_mode(on: bool) -> void:
	editor_mode = on
	if guides != null:
		guides.visible = on
	if subtitles != null:
		subtitles.visible = subtitles.visible and (on or bool(project.storyboard.get("burn_subtitles", true)))
	queue_redraw()

func set_overlays(enabled: bool, camera_path: bool = true, grid: bool = false, safe_area: bool = true) -> void:
	show_guides = enabled
	show_camera_path = camera_path
	show_grid = grid
	show_safe_area = safe_area
	queue_redraw()
	if guides != null:
		guides.queue_redraw()

func pick_element(frame_pos: Vector2) -> String:
	if camera == null:
		return ""
	var world_pos := camera.frame_to_world(frame_pos)
	var ids := element_nodes.keys()
	# Higher z wins; iterate reverse z order.
	var ordered: Array = []
	for id in ids:
		ordered.append(id)
	ordered.sort_custom(func(a, b):
		var na = element_nodes[a]
		var nb = element_nodes[b]
		return na.z_index > nb.z_index)
	for id in ordered:
		var node = element_nodes[id]
		if node == null or not node.visible:
			continue
		var local: Vector2 = node.transform.affine_inverse() * world_pos
		if node.get_local_rect().has_point(local):
			return id
	return ""

func frame_rect_for_element(id: String) -> Rect2:
	if not element_nodes.has(id):
		return Rect2()
	var node = element_nodes[id]
	var r: Rect2 = node.get_local_rect()
	var pts := [
		r.position,
		Vector2(r.end.x, r.position.y),
		r.end,
		Vector2(r.position.x, r.end.y),
	]
	var minv := Vector2(INF, INF)
	var maxv := Vector2(-INF, -INF)
	for p in pts:
		var wp: Vector2 = node.transform * p
		var fp := camera.world_to_frame(wp)
		minv = Vector2(minf(minv.x, fp.x), minf(minv.y, fp.y))
		maxv = Vector2(maxf(maxv.x, fp.x), maxf(maxv.y, fp.y))
	return Rect2(minv, maxv - minv)

func element_world_position(id: String) -> Vector2:
	if not element_nodes.has(id):
		return Vector2.ZERO
	return element_nodes[id].position

func world_delta_from_frame_delta(delta: Vector2) -> Vector2:
	return delta.rotated(-camera.current_rotation) / maxf(0.001, camera.current_zoom)

func get_element_node(id: String):
	return element_nodes.get(id, null)

func _draw() -> void:
	var bg: Color = project.palette_color("secondary", Color("#E9EEF2")) if project == null else Color.from_string(str(project.episode.get("background_color", "#E9EEF2")), Color("#E9EEF2"))
	if bg.a < 0.999:
		_draw_checkerboard()
	draw_rect(Rect2(Vector2.ZERO, frame_size), bg, true)

func _draw_checkerboard() -> void:
	var size := 48.0
	var cols := int(ceil(frame_size.x / size))
	var rows := int(ceil(frame_size.y / size))
	for y in range(rows):
		for x in range(cols):
			var c := Color("#D9DEE3") if (x + y) % 2 == 0 else Color("#C9D0D6")
			draw_rect(Rect2(x * size, y * size, size, size), c, true)

func _draw_guides() -> void:
	if not editor_mode or not show_guides:
		return
	var inv_scale := 1.0 / maxf(0.001, scale.x)
	var w := 1.6 * inv_scale
	var accent: Color = project.palette_color("accent", Color("#FF5A36"))
	var primary: Color = project.palette_color("primary", Color("#334B60"))
	var text_col: Color = project.palette_color("text", Color("#263746"))
	# frame border
	guides.draw_rect(Rect2(0, 0, frame_size.x, frame_size.y), Color(accent, 0.55), false, w * 1.3)
	# safe area
	if show_safe_area:
		var m := float(project.style_value("safe_margin_px", 72.0))
		var safe := Rect2(m, m, frame_size.x - m * 2.0, frame_size.y - m * 2.0)
		guides.draw_rect(safe, Color(1, 1, 1, 0.30), false, w)
		guides.draw_line(Vector2(frame_size.x * 0.5, 0), Vector2(frame_size.x * 0.5, frame_size.y), Color(1, 1, 1, 0.12), w)
		guides.draw_line(Vector2(0, frame_size.y * 0.5), Vector2(frame_size.x, frame_size.y * 0.5), Color(1, 1, 1, 0.12), w)
		# rule of thirds
		for i in [1, 2]:
			guides.draw_line(Vector2(frame_size.x * i / 3.0, 0), Vector2(frame_size.x * i / 3.0, frame_size.y), Color(1, 1, 1, 0.055), w)
			guides.draw_line(Vector2(0, frame_size.y * i / 3.0), Vector2(frame_size.x, frame_size.y * i / 3.0), Color(1, 1, 1, 0.055), w)
	if show_grid:
		var step := 120.0
		var gx := 0.0
		while gx <= frame_size.x:
			guides.draw_line(Vector2(gx, 0), Vector2(gx, frame_size.y), Color(primary, 0.055), w)
			gx += step
		var gy := 0.0
		while gy <= frame_size.y:
			guides.draw_line(Vector2(0, gy), Vector2(frame_size.x, gy), Color(primary, 0.055), w)
			gy += step
	# camera path (world path projected through the current camera)
	if show_camera_path and engine != null:
		var samples: Array = CameraPath.sample(engine, 0.0, engine.max_time(), 140)
		var pts := PackedVector2Array()
		for s in samples:
			pts.append(camera.world_to_frame(s["position"]))
		if pts.size() >= 2:
			guides.draw_polyline(pts, Color(accent, 0.55), 2.0 * inv_scale, true)
		for kp in CameraPath.keyframes(engine):
			var fp := camera.world_to_frame(kp["position"])
			guides.draw_circle(fp, 5.0 * inv_scale, Color(accent, 0.9))
			guides.draw_circle(fp, 9.0 * inv_scale, Color(accent, 0.25))
	# selection
	if not selected_id.is_empty() and element_nodes.has(selected_id):
		var r := frame_rect_for_element(selected_id)
		guides.draw_rect(r.grow(2.0), accent, false, 2.0 * inv_scale)
		var h := 7.0 * inv_scale
		for c in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
			guides.draw_rect(Rect2(c - Vector2(h, h) * 0.5, Vector2(h, h)), accent, true)
		var elem: Dictionary = project.element_by_id(selected_id)
		var tag := str(elem.get("name", selected_id)) + "  ·  " + str(elem.get("type", ""))
		var tw := maxf(90.0, _font_small.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 18 * inv_scale).x + 18.0 * inv_scale)
		var tag_y := r.position.y - 30.0 * inv_scale
		if tag_y < 8.0:
			tag_y = r.end.y + 6.0 * inv_scale
		guides.draw_rect(Rect2(r.position.x, tag_y, tw, 24.0 * inv_scale), Color(primary, 0.88), true)
		guides.draw_string(_font_small, Vector2(r.position.x + 9.0 * inv_scale, tag_y + 17.0 * inv_scale), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 18 * inv_scale, Color.WHITE)
	# current scene label (bottom-left)
	var scene: Dictionary = engine.scene_at(current_time) if engine != null else {}
	var line := "%s  ·  frame %d  ·  %.2fs" % [str(scene.get("name", "—")), engine.frame_for_time(current_time) if engine != null else 0, current_time]
	if not _status_line.is_empty():
		line = _status_line + "  ·  " + line
	var fs := 19.0 * inv_scale
	var text_w := _font_small.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 26.0 * inv_scale
	guides.draw_rect(Rect2(24.0 * inv_scale, frame_size.y - 48.0 * inv_scale, text_w, 30.0 * inv_scale), Color(0.06, 0.09, 0.11, 0.72), true)
	guides.draw_string(_font_small, Vector2(36.0 * inv_scale, frame_size.y - 27.0 * inv_scale), line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.86))
	# missing assets warning
	var missing: Array = project.missing_assets()
	if not missing.is_empty():
		var msg := "⚠ %d MISSING ASSET%s" % [missing.size(), "" if missing.size() == 1 else "S"]
		var mw := _font_small.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 26.0 * inv_scale
		guides.draw_rect(Rect2(frame_size.x - mw - 24.0 * inv_scale, 24.0 * inv_scale, mw, 30.0 * inv_scale), Color(0.62, 0.16, 0.11, 0.9), true)
		guides.draw_string(_font_small, Vector2(frame_size.x - mw - 12.0 * inv_scale, 45.0 * inv_scale), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)

func set_status_line(text: String) -> void:
	_status_line = text
	if guides != null:
		guides.queue_redraw()
