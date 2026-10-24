class_name AnimationEvaluator
extends RefCounted
## Deterministic interpolation of one animation track. Contains no state and
## no dependence on frame count, wall-clock time, or randomness.

const EasingLibrary = preload("res://scripts/animation/easing_library.gd")

## Return the interpolated value of `track` at `time`. `track` is expected to
## expose `keys`, `property`, `kind`, and sorted `KeyframeData` entries.
static func evaluate_track(track: AnimationTrack, time: float) -> Variant:
	if track == null or track.keys.is_empty():
		return null
	var keys := track.keys
	if time <= keys[0].time:
		return _copy_value(keys[0].value)
	if time >= keys[keys.size() - 1].time:
		return _copy_value(keys[keys.size() - 1].value)

	# Binary search for the segment without any accumulated state.
	var lo := 0
	var hi := keys.size() - 1
	while lo + 1 < hi:
		var mid := (lo + hi) >> 1
		if keys[mid].time <= time:
			lo = mid
		else:
			hi = mid
	var a: KeyframeData = keys[lo]
	var b: KeyframeData = keys[hi]
	if b.time <= a.time:
		return _copy_value(b.value)
	if b.interpolation == "step":
		return _copy_value(a.value)
	var t := (time - a.time) / (b.time - a.time)
	var eased := EasingLibrary.apply(b.easing, t, b.bezier)
	return interpolate_value(a.value, b.value, eased, track.property)

static func interpolate_value(a: Variant, b: Variant, t: float, property: String = "") -> Variant:
	if a is Array and b is Array:
		var out: Array = []
		var count: int = max(a.size(), b.size())
		for i in range(count):
			if i >= a.size():
				out.append(b[i])
			elif i >= b.size():
				out.append(a[i])
			elif property == "color" or (typeof(a[i]) == TYPE_STRING and str(a[i]).begins_with("#")):
				var ca := Color.from_string(str(a[i]), Color.WHITE)
				var cb := Color.from_string(str(b[i]), Color.WHITE)
				out.append(ca.lerp(cb, t).to_html(true))
			elif (a[i] is float or a[i] is int) and (b[i] is float or b[i] is int):
				out.append(lerpf(float(a[i]), float(b[i]), t))
			else:
				out.append(a[i] if t < 0.5 else b[i])
		return out
	if typeof(a) == TYPE_STRING and typeof(b) == TYPE_STRING and (property == "color" or str(a).begins_with("#")):
		return Color.from_string(str(a), Color.WHITE).lerp(Color.from_string(str(b), Color.WHITE), t).to_html(true)
	if (a is float or a is int) and (b is float or b is int):
		return lerpf(float(a), float(b), t)
	if a is Color and b is Color:
		return a.lerp(b, t)
	if typeof(a) == typeof(b):
		return a if t < 0.5 else b
	return b

static func _copy_value(v: Variant) -> Variant:
	if v is Array:
		return v.duplicate(true)
	if v is Dictionary:
		return v.duplicate(true)
	return v
