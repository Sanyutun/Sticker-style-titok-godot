class_name AnimationTrack
extends RefCounted
## One animatable property belonging to one element (or the camera).

const KeyframeData = preload("res://scripts/animation/keyframe_data.gd")
const AnimationEvaluator = preload("res://scripts/animation/animation_evaluator.gd")

var element_id: String = ""
var property: String = ""
var keys: Array = [] # Array[KeyframeData]
var kind: String = "auto" # auto | number | vector | color
var muted: bool = false

func _init(p_element: String = "", p_property: String = "") -> void:
	element_id = p_element
	property = p_property

func value_at(time: float) -> Variant:
	if muted:
		return null
	_sort()
	return AnimationEvaluator.evaluate_track(self, time)

func duration() -> float:
	if keys.is_empty():
		return 0.0
	_sort()
	return keys[keys.size() - 1].time

func add_key(key: KeyframeData) -> KeyframeData:
	for i in range(keys.size()):
		if absf(keys[i].time - key.time) < 0.0005:
			keys[i] = key
			_sort()
			return key
	keys.append(key)
	_sort()
	return key

func set_key_at(time: float, value: Variant, easing: String = "cubic_in_out") -> KeyframeData:
	var key := KeyframeData.new(time, value, easing)
	return add_key(key)

func remove_key_at(time: float, tolerance: float = 0.0005) -> bool:
	for i in range(keys.size() - 1, -1, -1):
		if absf(keys[i].time - time) <= tolerance:
			keys.remove_at(i)
			return true
	return false

func key_at(time: float, tolerance: float = 0.0005) -> KeyframeData:
	for key in keys:
		if absf(key.time - time) <= tolerance:
			return key
	return null

func nearest_key(time: float) -> KeyframeData:
	if keys.is_empty():
		return null
	var best: KeyframeData = keys[0]
	for key in keys:
		if absf(key.time - time) < absf(best.time - time):
			best = key
	return best

func move_key(key: KeyframeData, new_time: float) -> void:
	key.time = maxf(0.0, new_time)
	_sort()

func _sort() -> void:
	keys.sort_custom(func(a, b): return a.time < b.time)

func to_dict() -> Dictionary:
	_sort()
	var arr: Array = []
	for key in keys:
		arr.append(key.to_dict())
	return {
		"element_id": element_id,
		"property": property,
		"kind": kind,
		"keys": arr,
	}

static func from_dict(d: Dictionary) -> AnimationTrack:
	var t := AnimationTrack.new(str(d.get("element_id", "")), str(d.get("property", "")))
	t.kind = str(d.get("kind", "auto"))
	t.muted = bool(d.get("muted", false))
	var arr = d.get("keys", d.get("keyframes", []))
	if arr is Array:
		for kd in arr:
			if kd is Dictionary:
				t.keys.append(KeyframeData.from_dict(kd))
	t._sort()
	return t
