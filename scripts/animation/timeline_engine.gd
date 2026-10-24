class_name TimelineEngine
extends RefCounted
## Central deterministic evaluator.
##
##   state = engine.evaluate_at_time(t)
##
## Same project data + same t always yields the same state. No wall clock,
## no random numbers, no tween accumulation, no frame-count state.

const AnimationTrack = preload("res://scripts/animation/animation_track.gd")
const KeyframeData = preload("res://scripts/animation/keyframe_data.gd")

const CAMERA_ID := "@camera"

const ANIMATABLE_PROPERTIES := [
	"position", "scale", "rotation", "opacity", "width", "height",
	"color", "fill", "outline_width", "reveal", "value", "progress",
	"text_size", "tracking", "blur", "splash", "bulge", "water_level",
	"flow", "needle", "label_opacity",
]

var fps: int = 30
var duration: float = 10.0
var canvas_size := Vector2(6000, 3000)
var background_color := Color("#E9EEF2")

var tracks: Dictionary = {} # "element_id::property" -> AnimationTrack
var track_order: Array = []
var camera_defaults: Dictionary = {
	"position": [0.0, 0.0],
	"zoom": 1.0,
	"rotation": 0.0,
}
var scenes: Array = []

func setup_from_project(project) -> void:
	fps = maxi(1, int(project.episode.get("fps", 30)))
	duration = maxf(0.01, float(project.episode.get("duration_seconds", 10.0)))
	var cs = project.episode.get("canvas", {})
	canvas_size = Vector2(float(cs.get("width", 6000)), float(cs.get("height", 3000)))
	background_color = Color.from_string(str(project.episode.get("background_color", "#E9EEF2")), Color("#E9EEF2"))
	scenes = (project.storyboard.get("scenes", []) as Array).duplicate(true)
	camera_defaults = {
		"position": [0.0, 0.0],
		"zoom": 1.0,
		"rotation": 0.0,
	}
	var cam = project.storyboard.get("camera", {})
	if cam is Dictionary:
		for k in camera_defaults.keys():
			if cam.has(k):
				camera_defaults[k] = cam[k]
	load_tracks(project.storyboard.get("tracks", []))

func load_tracks(raw: Array) -> void:
	tracks.clear()
	track_order.clear()
	for td in raw:
		if not td is Dictionary:
			continue
		var tr := AnimationTrack.from_dict(td)
		if tr.element_id.is_empty() or tr.property.is_empty():
			continue
		var key := _key(tr.element_id, tr.property)
		if not tracks.has(key):
			track_order.append(key)
		tracks[key] = tr
		if tr.kind == "auto":
			tr.kind = _infer_kind(tr)

func _infer_kind(track: AnimationTrack) -> String:
	if track.keys.is_empty():
		return "auto"
	var v = track.keys[0].value
	if v is Array:
		if v.size() >= 3:
			return "color"
		return "vector"
	if typeof(v) == TYPE_STRING and str(v).begins_with("#"):
		return "color"
	if v is float or v is int:
		return "number"
	return "auto"

func _key(element_id: String, property: String) -> String:
	return element_id + "::" + property

func has_track(element_id: String, property: String) -> bool:
	return tracks.has(_key(element_id, property))

func get_track(element_id: String, property: String) -> AnimationTrack:
	return tracks.get(_key(element_id, property), null)

func get_tracks_for(element_id: String) -> Array:
	var out: Array = []
	for key in track_order:
		var tr: AnimationTrack = tracks[key]
		if tr.element_id == element_id:
			out.append(tr)
	return out

func ensure_track(element_id: String, property: String) -> AnimationTrack:
	var key := _key(element_id, property)
	if tracks.has(key):
		return tracks[key]
	var tr := AnimationTrack.new(element_id, property)
	tracks[key] = tr
	track_order.append(key)
	return tr

func remove_track(element_id: String, property: String) -> void:
	var key := _key(element_id, property)
	tracks.erase(key)
	track_order.erase(key)

func remove_tracks_for(element_id: String) -> void:
	for key in track_order.duplicate():
		var tr: AnimationTrack = tracks[key]
		if tr.element_id == element_id:
			tracks.erase(key)
			track_order.erase(key)

func all_tracks() -> Array:
	var out: Array = []
	for key in track_order:
		if tracks.has(key):
			out.append(tracks[key])
	return out

## Serialize tracks back into storyboard JSON.
func export_tracks_array() -> Array:
	var out: Array = []
	for key in track_order:
		if tracks.has(key):
			var tr: AnimationTrack = tracks[key]
			if not tr.keys.is_empty():
				out.append(tr.to_dict())
	return out

func frame_count() -> int:
	return maxi(1, int(round(duration * float(fps))))

func max_frame() -> int:
	return frame_count() - 1

func max_time() -> float:
	return float(max_frame()) / float(fps)

func time_for_frame(frame: int) -> float:
	return clampf(float(frame), 0.0, float(max_frame())) / float(fps)

func frame_for_time(time: float) -> int:
	return clampi(int(round(time * float(fps))), 0, max_frame())

func quantize_time(time: float) -> float:
	return time_for_frame(frame_for_time(time))

func evaluate_at_time(time: float) -> Dictionary:
	time = clampf(time, 0.0, duration)
	var elements: Dictionary = {}
	for key in track_order:
		if not tracks.has(key):
			continue
		var tr: AnimationTrack = tracks[key]
		if tr.element_id == CAMERA_ID:
			continue
		if not elements.has(tr.element_id):
			elements[tr.element_id] = {}
		var val = tr.value_at(time)
		if val != null:
			elements[tr.element_id][tr.property] = val
	return {
		"time": time,
		"frame": int(floor(time * float(fps) + 0.0001)),
		"elements": elements,
		"camera": evaluate_camera(time),
		"scene": scene_at(time),
	}

func evaluate_camera(time: float) -> Dictionary:
	var cam := {
		"position": _vec2(camera_defaults.get("position", [0.0, 0.0])),
		"zoom": float(camera_defaults.get("zoom", 1.0)),
		"rotation": float(camera_defaults.get("rotation", 0.0)),
	}
	for prop in ["position", "zoom", "rotation"]:
		var tr := get_track(CAMERA_ID, prop)
		if tr != null:
			var v = tr.value_at(time)
			if v != null:
				if prop == "position":
					cam.position = _vec2(v)
				else:
					cam[prop] = float(v)
	return cam

func _vec2(v: Variant) -> Vector2:
	if v is Array and v.size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	if v is Vector2:
		return v
	return Vector2.ZERO

func evaluate_property(element_id: String, property: String, time: float, fallback: Variant = null) -> Variant:
	var tr := get_track(element_id, property)
	if tr == null:
		return fallback
	var v = tr.value_at(time)
	return fallback if v == null else v

func scene_at(time: float) -> Dictionary:
	for s in scenes:
		if time >= float(s.get("start", 0.0)) and time < float(s.get("end", duration)):
			return s
	if not scenes.is_empty() and time >= float(scenes[scenes.size()-1].get("end", duration)):
		return scenes[scenes.size()-1]
	return {}

func scene_by_id(id: String) -> Dictionary:
	for s in scenes:
		if str(s.get("id", "")) == id:
			return s
	return {}

func camera_key_positions() -> Array:
	var out: Array = []
	var tr := get_track(CAMERA_ID, "position")
	if tr != null:
		for k in tr.keys:
			out.append({"time": k.time, "position": _vec2(k.value)})
	return out

## Deterministic hash used for decorative particle placement. Never uses
## randf(), so exports are repeatable.
static func hash01(seed_value: int, index: int) -> float:
	var x := int(seed_value) * 374761393 + int(index) * 668265263
	x = (x ^ (x >> 13)) * 1274126177
	x = x ^ (x >> 16)
	return float(x & 0x7fffffff) / float(0x7fffffff)
