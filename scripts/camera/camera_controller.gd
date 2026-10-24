class_name EditorCameraController
extends RefCounted
## Maps the project camera state onto the composition world. The frame size is
## the project's output resolution, independent of preview resolution.

var frame_size := Vector2(1920, 1080)
var world: Node2D
var current_position := Vector2.ZERO
var current_zoom := 1.0
var current_rotation := 0.0

func setup(p_world: Node2D, p_frame_size: Vector2) -> void:
	world = p_world
	frame_size = p_frame_size

func apply(cam: Dictionary) -> void:
	if world == null:
		return
	current_position = cam.get("position", Vector2.ZERO)
	current_zoom = maxf(0.02, float(cam.get("zoom", 1.0)))
	current_rotation = deg_to_rad(float(cam.get("rotation", 0.0)))
	var center := frame_size * 0.5
	world.position = center - (current_position * current_zoom).rotated(current_rotation)
	world.rotation = current_rotation
	world.scale = Vector2(current_zoom, current_zoom)

func world_to_frame(p: Vector2) -> Vector2:
	var center := frame_size * 0.5
	return center + (p - current_position).rotated(current_rotation) * current_zoom

func frame_to_world(p: Vector2) -> Vector2:
	var center := frame_size * 0.5
	return current_position + (p - center).rotated(-current_rotation) / current_zoom

func visible_world_rect() -> Rect2:
	var corners := [
		frame_to_world(Vector2.ZERO),
		frame_to_world(Vector2(frame_size.x, 0)),
		frame_to_world(frame_size),
		frame_to_world(Vector2(0, frame_size.y)),
	]
	var minv: Vector2 = corners[0]
	var maxv: Vector2 = corners[0]
	for c in corners:
		minv = Vector2(minf(minv.x, c.x), minf(minv.y, c.y))
		maxv = Vector2(maxf(maxv.x, c.x), maxf(maxv.y, c.y))
	return Rect2(minv, maxv - minv)
