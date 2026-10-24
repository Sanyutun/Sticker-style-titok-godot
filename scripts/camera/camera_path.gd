class_name CameraPath
extends RefCounted
## Sampling helper for the optional camera-path overlay. The actual camera
## transform always comes from TimelineEngine.evaluate_camera().

static func sample(engine, from_time: float, to_time: float, steps: int = 120) -> Array:
	var out: Array = []
	if engine == null:
		return out
	var t0 := minf(from_time, to_time)
	var t1 := maxf(from_time, to_time)
	for i in range(steps + 1):
		var t := lerpf(t0, t1, float(i) / float(steps))
		var cam: Dictionary = engine.evaluate_camera(t)
		out.append({"time": t, "position": cam.position, "zoom": cam.zoom})
	return out

static func keyframes(engine) -> Array:
	if engine == null:
		return []
	return engine.camera_key_positions()
