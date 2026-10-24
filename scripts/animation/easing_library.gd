class_name EasingLibrary
extends RefCounted
## Analytical easing functions used by the deterministic timeline.
## Every function maps clamped normalized time 0..1 to 0..1 (with intentional
## overshoot for the "back"/"elastic" curves).

const NAMES := [
	"linear", "smoothstep", "ease_in", "ease_out", "cubic_in", "cubic_out",
	"cubic_in_out", "quart_in_out", "quint_in_out", "expo_out", "sine_in_out",
	"back_in", "back_out", "back_in_out", "elastic_out", "bounce_out",
	"custom_bezier",
]

static func apply(name: String, t: float, bezier: Array = []) -> float:
	t = clampf(t, 0.0, 1.0)
	match name:
		"linear":
			return t
		"smoothstep":
			return t * t * (3.0 - 2.0 * t)
		"ease_in", "sine_in":
			return 1.0 - cos(t * PI * 0.5)
		"ease_out", "sine_out":
			return sin(t * PI * 0.5)
		"cubic_in":
			return t * t * t
		"cubic_out":
			return 1.0 - pow(1.0 - t, 3.0)
		"cubic_in_out":
			if t < 0.5:
				return 4.0 * t * t * t
			return 1.0 - pow(-2.0 * t + 2.0, 3.0) * 0.5
		"quart_in_out":
			if t < 0.5:
				return 8.0 * t * t * t * t
			return 1.0 - pow(-2.0 * t + 2.0, 4.0) * 0.5
		"quint_in_out":
			if t < 0.5:
				return 16.0 * t * t * t * t * t
			return 1.0 - pow(-2.0 * t + 2.0, 5.0) * 0.5
		"expo_out":
			return 1.0 if t >= 1.0 else 1.0 - pow(2.0, -10.0 * t)
		"sine_in_out":
			return -(cos(PI * t) - 1.0) * 0.5
		"back_in":
			var c1 := 1.70158
			return (c1 + 1.0) * t * t * t - c1 * t * t
		"back_out":
			var c1 := 1.70158
			return 1.0 + (c1 + 1.0) * pow(t - 1.0, 3.0) + c1 * pow(t - 1.0, 2.0)
		"back_in_out":
			var c2 := 1.70158 * 1.525
			if t < 0.5:
				return (pow(2.0 * t, 2.0) * ((c2 + 1.0) * 2.0 * t - c2)) * 0.5
			return (pow(2.0 * t - 2.0, 2.0) * ((c2 + 1.0) * (t * 2.0 - 2.0) + c2) + 2.0) * 0.5
		"elastic_out":
			if t <= 0.0:
				return 0.0
			if t >= 1.0:
				return 1.0
			return pow(2.0, -10.0 * t) * sin((t * 10.0 - 0.75) * (2.0 * PI / 3.0)) + 1.0
		"bounce_out":
			return _bounce_out(t)
		"custom_bezier":
			if bezier.size() >= 4:
				return cubic_bezier(float(bezier[0]), float(bezier[1]), float(bezier[2]), float(bezier[3]), t)
			return t
		_:
			return t

static func _bounce_out(t: float) -> float:
	var n1 := 7.5625
	var d1 := 2.75
	if t < 1.0 / d1:
		return n1 * t * t
	elif t < 2.0 / d1:
		t -= 1.5 / d1
		return n1 * t * t + 0.75
	elif t < 2.5 / d1:
		t -= 2.25 / d1
		return n1 * t * t + 0.9375
	else:
		t -= 2.625 / d1
		return n1 * t * t + 0.984375

## Cubic-bezier easing identical to CSS timing functions. Solves x(u)=t
## analytically with bisection so it is frame-rate independent.
static func cubic_bezier(x1: float, y1: float, x2: float, y2: float, t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	var lo := 0.0
	var hi := 1.0
	var u := t
	for i in range(24):
		u = (lo + hi) * 0.5
		var x := _bezier_axis(u, x1, x2)
		if x < t:
			lo = u
		else:
			hi = u
	var y := _bezier_axis(u, y1, y2)
	return y

static func _bezier_axis(u: float, p1: float, p2: float) -> float:
	var inv := 1.0 - u
	return 3.0 * inv * inv * u * p1 + 3.0 * inv * u * u * p2 + u * u * u
