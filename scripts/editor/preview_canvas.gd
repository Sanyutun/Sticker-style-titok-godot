class_name PreviewCanvas
extends Control
## Interactive preview surface. The composition itself is rendered by the
## shared CompositionStage inside a SubViewport; this control only handles
## display, fit/zoom/pan, selection and direct element dragging.

signal element_pressed(id: String)
signal element_dragged(id: String, world_delta: Vector2)
signal element_released(id: String)
signal background_pressed()
signal view_changed(zoom: float)

const STAGE_SCENE = preload("res://scenes/stage/composition_stage.tscn")
const PREVIEW_W := 1280
const PREVIEW_H := 720

var subviewport: SubViewport
var stage = null
var project = null
var engine = null
var frame_size := Vector2(1920, 1080)

var view_zoom := 1.0
var view_pan := Vector2.ZERO
var _fit_scale := 1.0
var _auto_fit := true
var _panning := false
var _pan_start := Vector2.ZERO
var _pan_origin := Vector2.ZERO
var _drag_id := ""
var _drag_start_frame := Vector2.ZERO
var _drag_start_world := Vector2.ZERO
var _drag_moved := false
var _drag_accum := Vector2.ZERO

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_CLICK
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	subviewport = SubViewport.new()
	subviewport.name = "PreviewViewport"
	subviewport.size = Vector2i(PREVIEW_W, PREVIEW_H)
	subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	subviewport.transparent_bg = false
	subviewport.disable_3d = true
	subviewport.msaa_2d = Viewport.MSAA_2X
	add_child(subviewport)
	stage = STAGE_SCENE.instantiate()
	subviewport.add_child(stage)
	resized.connect(_on_resized)
	set_process(false)

func build(p_project, p_engine) -> void:
	project = p_project
	engine = p_engine
	frame_size = Vector2(float(project.episode.get("width", 1920)), float(project.episode.get("height", 1080)))
	stage.build(project, engine)
	stage.set_viewport_size(Vector2(PREVIEW_W, PREVIEW_H))
	stage.set_editor_mode(true)
	stage.set_overlays(false, false, false, false)
	_auto_fit = true
	view_zoom = 1.0
	view_pan = Vector2.ZERO
	subviewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	queue_redraw()

func set_time(time: float) -> void:
	if stage == null:
		return
	stage.evaluate(time)
	_redraw_once()

func set_live(live: bool) -> void:
	if subviewport == null:
		return
	subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if live else SubViewport.UPDATE_ONCE

func set_selected(id: String) -> void:
	if stage != null:
		stage.set_selected(id)
	_redraw_once()

func set_overlays(enabled: bool, camera_path: bool = false, grid: bool = false, safe_area: bool = false) -> void:
	if stage == null:
		return
	stage.set_overlays(enabled, camera_path, grid, safe_area)
	_redraw_once()

func set_editor_guides_visible(on: bool) -> void:
	if stage == null:
		return
	stage.set_editor_mode(true)
	stage.show_guides = on
	stage.show_camera_path = on and stage.show_camera_path
	if stage.guides != null:
		stage.guides.visible = on
		stage.guides.queue_redraw()
	_redraw_once()

func _redraw_once() -> void:
	if subviewport != null and subviewport.render_target_update_mode != SubViewport.UPDATE_ALWAYS:
		subviewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	queue_redraw()

func reset_view() -> void:
	_auto_fit = true
	view_zoom = 1.0
	view_pan = Vector2.ZERO
	view_changed.emit(view_zoom)
	queue_redraw()

func set_view_zoom(z: float) -> void:
	view_zoom = clampf(z, 0.2, 8.0)
	_auto_fit = false
	view_changed.emit(view_zoom)
	queue_redraw()

func texture_rect() -> Rect2:
	if subviewport == null:
		return Rect2()
	var tex_size := Vector2(PREVIEW_W, PREVIEW_H)
	var fs := minf(size.x / tex_size.x, size.y / tex_size.y)
	if fs <= 0.0:
		return Rect2()
	_fit_scale = fs
	var s := fs * view_zoom
	return Rect2(size * 0.5 + view_pan - tex_size * s * 0.5, tex_size * s)

func _on_resized() -> void:
	queue_redraw()

func _draw() -> void:
	var bg := Color("#0B0D11")
	draw_rect(Rect2(Vector2.ZERO, size), bg, true)
	# subtle dotted working area
	var step := 32.0
	var dot := Color(1, 1, 1, 0.035)
	var y := 16.0
	while y < size.y:
		var x := 16.0
		while x < size.x:
			draw_circle(Vector2(x, y), 1.0, dot)
			x += step
		y += step
	if subviewport == null:
		return
	var r := texture_rect()
	if r.size.x <= 1.0:
		return
	draw_rect(r.grow(8.0), Color(0, 0, 0, 0.38), true)
	draw_texture_rect(subviewport.get_texture(), r, false)
	draw_rect(r, Color("#3B4552"), false, 1.0)
	# scene / camera badge
	var scene_name := ""
	var cam_txt := ""
	if engine != null:
		var scn: Dictionary = engine.scene_at(stage.current_time if stage != null else 0.0)
		scene_name = str(scn.get("name", ""))
		if stage != null:
			var cam: Dictionary = stage.current_camera
			cam_txt = "%.0f, %.0f  ·  %.0f%%" % [float(cam.get("position", Vector2.ZERO).x), float(cam.get("position", Vector2.ZERO).y), float(cam.get("zoom", 1.0)) * 100.0]
	var font := ThemeDB.fallback_font
	var badge := "  %s  " % scene_name.to_upper()
	var tw := font.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	if not scene_name.is_empty():
		draw_rect(Rect2(12, 12, tw + 4, 24), Color(0.06, 0.07, 0.09, 0.82), true)
		draw_rect(Rect2(12, 12, 3, 24), Color("#FF6A45"), true)
		draw_string(font, Vector2(20, 28), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#DCE4EE"))
	if not cam_txt.is_empty():
		var ct := "CAM " + cam_txt
		var cw := font.get_string_size(ct, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		var cr := Rect2(size.x - cw - 26, size.y - 32, cw + 14, 20)
		draw_rect(cr, Color(0.06, 0.07, 0.09, 0.72), true)
		draw_string(font, Vector2(cr.position.x + 7, cr.position.y + 14), ct, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#9AA7B6"))
	if not _auto_fit:
		var zt := "%d%%" % int(round(view_zoom * 100.0))
		draw_rect(Rect2(size.x - 62, 12, 50, 22), Color(0.06, 0.07, 0.09, 0.78), true)
		draw_string(font, Vector2(size.x - 55, 28), zt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#E8EDF3"))

func _pick(frame_pos: Vector2) -> String:
	if stage == null:
		return ""
	return stage.pick_element(frame_pos)

func _to_frame(local_pos: Vector2) -> Vector2:
	var r := texture_rect()
	if r.size.x <= 0.0:
		return Vector2.ZERO
	var uv := (local_pos - r.position) / r.size
	return Vector2(uv.x * frame_size.x, uv.y * frame_size.y)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_at(mb.position, 1.14)
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_at(mb.position, 1.0 / 1.14)
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			if mb.pressed:
				_panning = true
				_pan_start = mb.position
				_pan_origin = view_pan
				mouse_default_cursor_shape = Control.CURSOR_DRAG
			else:
				_panning = false
				mouse_default_cursor_shape = Control.CURSOR_ARROW
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if mb.alt_pressed:
					_panning = true
					_pan_start = mb.position
					_pan_origin = view_pan
					accept_event()
					return
				var fp := _to_frame(mb.position)
				var id := _pick(fp)
				if id.is_empty():
					background_pressed.emit()
				else:
					_drag_id = id
					_drag_start_frame = fp
					_drag_start_world = stage.element_world_position(id)
					_drag_accum = Vector2.ZERO
					_drag_moved = false
					element_pressed.emit(id)
				accept_event()
			else:
				if _drag_id != "":
					if _drag_moved:
						element_released.emit(_drag_id)
					_drag_id = ""
					_drag_moved = false
				accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			background_pressed.emit()
			accept_event()
			return
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _panning:
			view_pan = _pan_origin + (mm.position - _pan_start)
			_auto_fit = false
			queue_redraw()
			accept_event()
			return
		if _drag_id != "" and (mm.button_mask & MOUSE_BUTTON_MASK_LEFT):
			var fp := _to_frame(mm.position)
			# delta in output-frame pixels, rotated/scaled back into world space.
			var frame_delta := Vector2(
				(fp.x - _drag_start_frame.x) * (frame_size.x / 1920.0),
				(fp.y - _drag_start_frame.y) * (frame_size.y / 1080.0)
			)
			var world_delta: Vector2 = stage.world_delta_from_frame_delta(frame_delta)
			if world_delta.length() > 1.5:
				_drag_moved = true
			_drag_accum = world_delta
			element_dragged.emit(_drag_id, world_delta)
			accept_event()

func _zoom_at(local_pos: Vector2, factor: float) -> void:
	var old_r := texture_rect()
	if old_r.size.x <= 0.0:
		return
	var old_s := old_r.size.x / float(PREVIEW_W)
	var u := (local_pos - old_r.position) / old_s
	view_zoom = clampf(view_zoom * factor, 0.2, 8.0)
	_auto_fit = false
	var new_s := (_fit_scale * view_zoom)
	var new_pos := local_pos - u * new_s
	view_pan = new_pos - size * 0.5 + Vector2(PREVIEW_W, PREVIEW_H) * new_s * 0.5
	view_changed.emit(view_zoom)
	queue_redraw()

func get_drag_world_start() -> Vector2:
	return _drag_start_world

func get_drag_accum() -> Vector2:
	return _drag_accum
