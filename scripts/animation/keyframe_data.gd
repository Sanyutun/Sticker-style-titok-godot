class_name KeyframeData
extends RefCounted
## A single editable keyframe. Easing describes the segment that ARRIVES at
## this keyframe (the outgoing easing of the previous keyframe is ignored).

var time: float = 0.0
var value: Variant = 0.0
var easing: String = "cubic_in_out"
var interpolation: String = "auto" # auto | linear | step | smooth
var bezier: Array = [] # optional [x1,y1,x2,y2] for custom_bezier

func _init(p_time: float = 0.0, p_value: Variant = 0.0, p_easing: String = "cubic_in_out") -> void:
	time = p_time
	value = p_value
	easing = p_easing

func duplicate_key() -> KeyframeData:
	var k := KeyframeData.new(time, _deep_copy(value), easing)
	k.interpolation = interpolation
	k.bezier = bezier.duplicate()
	return k

func to_dict() -> Dictionary:
	var d := {
		"time": snappedf(time, 0.000001),
		"value": value,
	}
	if easing != "linear":
		d["easing"] = easing
	if interpolation != "auto":
		d["interpolation"] = interpolation
	if easing == "custom_bezier" and bezier.size() >= 4:
		d["bezier"] = bezier
	return d

static func from_dict(d: Dictionary) -> KeyframeData:
	var k := KeyframeData.new()
	k.time = float(d.get("time", d.get("t", 0.0)))
	k.value = _deep_copy(d.get("value", d.get("v", 0.0)))
	k.easing = str(d.get("easing", "cubic_in_out"))
	k.interpolation = str(d.get("interpolation", "auto"))
	if d.has("bezier") and d["bezier"] is Array:
		k.bezier = d["bezier"].duplicate()
	return k

static func _deep_copy(v: Variant) -> Variant:
	if v is Array:
		return v.duplicate(true)
	if v is Dictionary:
		return v.duplicate(true)
	return v
