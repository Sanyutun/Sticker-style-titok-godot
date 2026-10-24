class_name ProjectData
extends RefCounted
## Versioned episode configuration + storyboard persistence, defaults and
## validation. The rendering engine never hard-codes sample-episode content.

const SCHEMA_VERSION := 1
const SUPPORTED_ELEMENT_TYPES := [
	"sticker", "text", "shape", "arrow", "chart", "character",
	"blood_vessel", "pressure_gauge",
]

var project_dir: String = ""
var episode: Dictionary = {}
var storyboard: Dictionary = {}
var errors: Array = []
var warnings: Array = []
var load_ok: bool = false

static func default_episode(project_name: String = "Untitled Episode", brand: String = "BodyFrame", topic: String = "") -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"project_name": project_name,
		"brand_name": brand,
		"topic": topic,
		"width": 1920,
		"height": 1080,
		"fps": 30,
		"duration_seconds": 10.0,
		"background_color": "#E9EEF2",
		"canvas": {"width": 6000, "height": 3000},
		"palette": {
			"primary": "#334B60",
			"secondary": "#F6F3EC",
			"accent": "#FF5A36",
			"blood": "#C84C4C",
			"text": "#263746",
			"muted": "#7A8C99",
			"water": "#7FB9D8",
			"paper": "#FFFFFF",
		},
		"style": {
			"preset_name": "Bold Outline Editorial Explainer",
			"sticker_outline_px": 10,
			"sticker_outline_color": "#FFFFFF",
			"shadow_enabled": true,
			"shadow_blur_px": 12,
			"shadow_offset_x": 0,
			"shadow_offset_y": 8,
			"shadow_color": "#263746",
			"shadow_alpha": 0.20,
			"font_regular": "res://resources/fonts/NotoSans-Regular.ttf",
			"font_bold": "res://resources/fonts/NotoSans-Bold.ttf",
			"font_myanmar": "res://resources/fonts/NotoSansMyanmar-Regular.ttf",
			"font_cjk": "",
			"safe_margin_px": 72,
			"motion_blur": false,
			"motion_blur_samples": 3,
			"motion_blur_shutter": 0.5,
		},
		"camera": {"mode": "keyframed", "default_easing": "cubic_in_out"},
		"audio": {"sample_rate": 48000, "integrated_loudness_lufs": -14.0, "true_peak_limit_dbtp": -1.0},
		"export": {
			"video_codec": "libx264",
			"pixel_format": "yuv420p",
			"crf": 18,
			"preset": "medium",
			"audio_codec": "aac",
			"audio_bitrate_kbps": 192,
			"video_path": "output/video.mp4",
			"frames_dir": "output/frames",
		},
		"localization": {
			"default_language": "en",
			"narration": {
				"en": "Too much sodium can make your body hold water. That can raise blood pressure. Over time, it can contribute to hypertension. Cutting back helps.",
				"my": "",
			},
			"notes": {
				"en": "Narration is a synthetic scratch guide track. Replace with a recorded voice before publication.",
				"my": "Burmese translation pending clinical and linguistic review.",
			},
		},
		"assets": [],
	}

static func default_storyboard() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"camera": {"position": [960.0, 540.0], "zoom": 1.0, "rotation": 0.0},
		"scenes": [
			{
				"id": "scene_01",
				"name": "Opening",
				"start": 0.0,
				"end": 10.0,
				"purpose": "Introduce the topic.",
				"camera_target": [960.0, 540.0],
				"narration": "en",
				"cues": [],
			}
		],
		"elements": [
			{
				"id": "title",
				"type": "text",
				"name": "Title",
				"scene": "scene_01",
				"x": 960.0, "y": 500.0, "width": 1400.0, "height": 200.0,
				"rotation": 0.0, "scale": [1.0, 1.0], "opacity": 1.0,
				"z": 10, "text": "NEW EPISODE", "font_size": 96, "font_weight": "bold",
				"color": "#263746", "align": "center", "valign": "center",
			}
		],
		"tracks": [],
		"audio": {"tracks": []},
		"subtitles": {"en": [], "my": [], "my_status": "needs_localization"},
		"camera_path_notes": "Set camera keyframes on the @camera tracks.",
	}

func _init() -> void:
	episode = default_episode()
	storyboard = default_storyboard()

func load_from_dir(dir_path: String) -> bool:
	errors.clear()
	warnings.clear()
	load_ok = false
	project_dir = dir_path.trim_suffix("/")
	if project_dir.ends_with("/episode.json"):
		project_dir = project_dir.get_base_dir()
	var ep_path := project_dir.path_join("episode.json")
	var sb_path := project_dir.path_join("storyboard.json")
	if not FileAccess.file_exists(ep_path):
		errors.append("episode.json not found in %s" % project_dir)
		return false
	var parsed = _read_json(ep_path, errors)
	if parsed == null:
		return false
	if not parsed is Dictionary:
		errors.append("episode.json root must be an object")
		return false
	episode = _merge_defaults(parsed, default_episode())
	if FileAccess.file_exists(sb_path):
		var parsed_sb = _read_json(sb_path, errors)
		if parsed_sb is Dictionary:
			storyboard = _merge_storyboard_defaults(parsed_sb)
		else:
			errors.append("storyboard.json could not be parsed")
			storyboard = default_storyboard()
	else:
		warnings.append("storyboard.json is missing; using an empty storyboard")
		storyboard = default_storyboard()
	_normalize_storyboard()
	_validate_internal()
	load_ok = errors.is_empty()
	return load_ok

func _read_json(path: String, err_array: Array):
	if not FileAccess.file_exists(path):
		err_array.append("File not found: %s" % path)
		return null
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		err_array.append("%s: JSON parse error on line %d: %s" % [path.get_file(), json.get_error_line(), json.get_error_message()])
		return null
	return json.data

func _merge_defaults(src: Dictionary, base: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	for k in src.keys():
		if out.has(k) and out[k] is Dictionary and src[k] is Dictionary:
			out[k] = _merge_defaults(src[k], out[k])
		else:
			out[k] = src[k]
	return out

func _merge_storyboard_defaults(src: Dictionary) -> Dictionary:
	var base := default_storyboard()
	var out := src.duplicate(true)
	for k in base.keys():
		if not out.has(k):
			out[k] = base[k]
	if not out.get("camera") is Dictionary:
		out["camera"] = base["camera"]
	return out

func _normalize_storyboard() -> void:
	if not storyboard.get("elements") is Array:
		errors.append("storyboard.elements must be an array")
		storyboard["elements"] = []
	if not storyboard.get("tracks") is Array:
		errors.append("storyboard.tracks must be an array")
		storyboard["tracks"] = []
	if not storyboard.get("scenes") is Array:
		storyboard["scenes"] = []
	if not storyboard.get("audio") is Dictionary:
		storyboard["audio"] = {"tracks": []}
	if not storyboard["audio"].get("tracks") is Array:
		storyboard["audio"]["tracks"] = []
	if not storyboard.get("subtitles") is Dictionary:
		storyboard["subtitles"] = {"en": [], "my": [], "my_status": "needs_localization"}
	for elem in storyboard["elements"]:
		if not elem is Dictionary:
			continue
		if not elem.has("id"):
			elem["id"] = "element_%d" % (randi() % 100000)
		if not elem.has("type"):
			elem["type"] = "shape"
		elem["x"] = float(elem.get("x", 0.0))
		elem["y"] = float(elem.get("y", 0.0))
		elem["width"] = float(elem.get("width", 200.0))
		elem["height"] = float(elem.get("height", 120.0))
		elem["rotation"] = float(elem.get("rotation", 0.0))
		elem["opacity"] = float(elem.get("opacity", 1.0))
		elem["z"] = int(elem.get("z", 0))
		if not elem.get("scale") is Array or elem["scale"].size() < 2:
			elem["scale"] = [1.0, 1.0]
	for track in storyboard["tracks"]:
		if track is Dictionary and track.get("keys") is Array:
			track["keys"].sort_custom(func(a, b): return float(a.get("time", 0.0)) < float(b.get("time", 0.0)))

func _validate_internal() -> void:
	var validation := validate()
	errors.append_array(validation.errors)
	warnings.append_array(validation.warnings)

func validate() -> Dictionary:
	var errs: Array = []
	var warns: Array = []
	var version := int(episode.get("schema_version", 0))
	if version == 0:
		errs.append("schema_version is missing")
	elif version > SCHEMA_VERSION:
		errs.append("Project schema version %d is newer than this studio supports (%d)." % [version, SCHEMA_VERSION])
	if str(episode.get("project_name", "")).strip_edges().is_empty():
		warns.append("project_name is empty")
	var w := int(episode.get("width", 0))
	var h := int(episode.get("height", 0))
	if w < 320 or h < 180:
		errs.append("Video dimensions must be at least 320×180")
	if w % 2 != 0 or h % 2 != 0:
		errs.append("Video dimensions must be even for H.264 yuv420p export")
	var fps := int(episode.get("fps", 0))
	if fps <= 0 or fps > 120:
		errs.append("fps must be between 1 and 120")
	var dur := float(episode.get("duration_seconds", 0.0))
	if dur <= 0.0:
		errs.append("duration_seconds must be greater than zero")
	elif absf(dur * fps - round(dur * fps)) > 0.001:
		warns.append("duration × fps is not an integer; the last frame may be partially held")
	var canvas: Dictionary = episode.get("canvas", {}) if episode.get("canvas") is Dictionary else {}
	var cw := float(canvas.get("width", 0))
	var ch := float(canvas.get("height", 0))
	if cw < w or ch < h:
		errs.append("Composition canvas must be at least as large as the video frame")
	if not _valid_color(str(episode.get("background_color", ""))):
		errs.append("background_color is not a valid hex color")
	var palette = episode.get("palette", {})
	if palette is Dictionary:
		for key in palette.keys():
			if not _valid_color(str(palette[key])):
				errs.append("palette.%s is not a valid hex color" % key)
	var seen_ids := {}
	var element_ids := {}
	for elem in storyboard.get("elements", []):
		if not elem is Dictionary:
			errs.append("storyboard.elements contains a non-object entry")
			continue
		var id := str(elem.get("id", ""))
		if id.is_empty():
			errs.append("Element without id")
			continue
		if seen_ids.has(id):
			errs.append("Duplicate element id: %s" % id)
		seen_ids[id] = true
		element_ids[id] = true
		var type := str(elem.get("type", ""))
		if not type in SUPPORTED_ELEMENT_TYPES:
			errs.append("Element %s has unknown type '%s'" % [id, type])
		if float(elem.get("width", 0)) <= 0 or float(elem.get("height", 0)) <= 0:
			warns.append("Element %s has a zero or negative size" % id)
		if type == "sticker":
			var asset := str(elem.get("asset", ""))
			if asset.is_empty():
				warns.append("Sticker %s has no asset" % id)
			elif not asset_exists(asset):
				errs.append("Missing sticker asset for %s: %s" % [id, asset])
		if type == "text":
			var font_path := str(elem.get("font", episode.get("style", {}).get("font_regular", "")))
			if not font_path.is_empty() and not asset_exists(font_path):
				errs.append("Missing font for %s: %s" % [id, font_path])
		if elem.has("font") and not asset_exists(str(elem["font"])):
			errs.append("Missing font for %s: %s" % [id, elem["font"]])
	var cam_ids := {TimelineEngine.CAMERA_ID: true}
	for elem_id in element_ids.keys():
		cam_ids[elem_id] = true
	var track_ids := {}
	for tr in storyboard.get("tracks", []):
		if not tr is Dictionary:
			errs.append("storyboard.tracks contains a non-object entry")
			continue
		var eid := str(tr.get("element_id", ""))
		var prop := str(tr.get("property", ""))
		if not cam_ids.has(eid):
			errs.append("Track targets missing element: %s" % eid)
		var tkey := eid + "|" + prop
		if track_ids.has(tkey):
			warns.append("Duplicate track for %s.%s (only the last is used)" % [eid, prop])
		track_ids[tkey] = true
		if prop.is_empty():
			errs.append("Track on %s has no property" % eid)
		var keys = tr.get("keys", [])
		if not keys is Array:
			errs.append("Track %s.%s has invalid keys" % [eid, prop])
			continue
		for k in keys:
			if not k is Dictionary:
				errs.append("Track %s.%s contains a non-object keyframe" % [eid, prop])
				continue
			var kt := float(k.get("time", -1.0))
			if kt < 0.0:
				errs.append("Track %s.%s has a negative keyframe time" % [eid, prop])
			if kt > dur + 0.5:
				warns.append("Track %s.%s keyframe at %.2fs is beyond the episode duration" % [eid, prop, kt])
			if not k.has("value"):
				errs.append("Track %s.%s has a keyframe without a value" % [eid, prop])
	# Audio
	var audio_tracks = storyboard.get("audio", {}).get("tracks", [])
	var has_narration := false
	var has_any_audio := false
	for at in audio_tracks:
		if not at is Dictionary:
			continue
		has_any_audio = true
		var file := str(at.get("file", ""))
		if str(at.get("type", "")) == "narration":
			has_narration = true
		if file.is_empty():
			warns.append("Audio track '%s' has no file" % str(at.get("name", "?")))
		elif not asset_exists(file):
			errs.append("Missing audio file for '%s': %s" % [str(at.get("name", "?")), file])
		var st := float(at.get("start", 0.0))
		var dur_t := float(at.get("duration", 0.0))
		if st + dur_t > dur + 0.5:
			warns.append("Audio '%s' extends past the end of the episode" % str(at.get("name", "?")))
	if not has_any_audio:
		warns.append("No audio tracks are configured; the export will contain no audio.")
	elif not has_narration:
		warns.append("No narration track is configured. Music/SFX only.")
	var my_narr := str(episode.get("localization", {}).get("narration", {}).get("my", ""))
	var my_subs = storyboard.get("subtitles", {}).get("my", [])
	if my_narr.strip_edges().is_empty() and (not my_subs is Array or my_subs.is_empty()):
		warns.append("Burmese narration/subtitles are pending localization and review.")
	# Font glyph checks (warning, not an error: fallback may still render)
	var font_report := validate_fonts()
	for item in font_report:
		if not item.ok:
			warns.append(item.message)
	return {"errors": errs, "warnings": warns}

func validate_fonts() -> Array:
	var out: Array = []
	var texts := {}
	var default_font := str(episode.get("style", {}).get("font_regular", ""))
	var bold_font := str(episode.get("style", {}).get("font_bold", ""))
	for elem in storyboard.get("elements", []):
		if elem is Dictionary and str(elem.get("type", "")) == "text":
			var path := str(elem.get("font", ""))
			if path.is_empty():
				path = bold_font if str(elem.get("font_weight", "regular")) == "bold" else default_font
			if not texts.has(path):
				texts[path] = ""
			texts[path] += str(elem.get("text", "")) + "\n"
	var loc = episode.get("localization", {})
	if loc is Dictionary:
		for lang in loc.get("narration", {}).keys():
			var path := default_font
			if lang == "my":
				path = str(episode.get("style", {}).get("font_myanmar", ""))
			if not path.is_empty():
				if not texts.has(path):
					texts[path] = ""
				texts[path] += str(loc["narration"][lang]) + "\n"
	for lang in storyboard.get("subtitles", {}).keys():
		var subs = storyboard["subtitles"][lang]
		if subs is Array:
			var path := default_font
			if lang == "my":
				path = str(episode.get("style", {}).get("font_myanmar", ""))
			if not path.is_empty():
				if not texts.has(path):
					texts[path] = ""
				for s in subs:
					if s is Dictionary:
						texts[path] += str(s.get("text", "")) + "\n"
	for path in texts.keys():
		if path.is_empty():
			continue
		var item := {"path": path, "ok": true, "message": "", "missing": []}
		if not asset_exists(path):
			item.ok = false
			item.message = "Font file missing: %s" % path
			out.append(item)
			continue
		var font := load_font(path)
		if font == null:
			item.ok = false
			item.message = "Font could not be loaded: %s" % path
			out.append(item)
			continue
		var missing := ""
		var checked := {}
		var scan_text := str(texts[path])
		for ci in range(scan_text.length()):
			var code := scan_text.unicode_at(ci)
			if code < 32 or checked.has(code):
				continue
			checked[code] = true
			if not font.has_char(code):
				missing += String.chr(code)
		if not missing.is_empty():
			item.ok = false
			item.missing = missing
			item.message = "Font %s lacks glyphs: %s" % [path.get_file(), missing.substr(0, 24)]
		out.append(item)
	return out

static func load_font(path: String) -> FontFile:
	var global_path := globalize_path(path)
	if not FileAccess.file_exists(global_path):
		return null
	var f := FontFile.new()
	var err := f.load_dynamic_font(global_path)
	if err != OK:
		return null
	return f

func missing_assets() -> Array:
	var missing: Array = []
	for elem in storyboard.get("elements", []):
		if not elem is Dictionary:
			continue
		if str(elem.get("type", "")) == "sticker":
			var a := str(elem.get("asset", ""))
			if not a.is_empty() and not asset_exists(a):
				missing.append({"kind": "image", "path": a, "element": str(elem.get("id", ""))})
		if elem.has("font") and not asset_exists(str(elem["font"])):
			missing.append({"kind": "font", "path": str(elem["font"]), "element": str(elem.get("id", ""))})
	for at in storyboard.get("audio", {}).get("tracks", []):
		if at is Dictionary:
			var f := str(at.get("file", ""))
			if not f.is_empty() and not asset_exists(f):
				missing.append({"kind": "audio", "path": f, "element": str(at.get("name", ""))})
	return missing

func save() -> bool:
	if project_dir.is_empty():
		errors.append("No project directory set")
		return false
	episode["schema_version"] = SCHEMA_VERSION
	storyboard["schema_version"] = SCHEMA_VERSION
	var ep_ok := _write_json(project_dir.path_join("episode.json"), episode)
	var sb_ok := _write_json(project_dir.path_join("storyboard.json"), storyboard)
	if not ep_ok or not sb_ok:
		return false
	return true

func _write_json(path: String, data: Dictionary) -> bool:
	var dir := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(globalize_path(dir)):
		var mk := DirAccess.make_dir_recursive_absolute(globalize_path(dir))
		if mk != OK:
			errors.append("Could not create directory: %s" % dir)
			return false
	var text := JSON.stringify(data, "  ", false)
	var fa := FileAccess.open(path, FileAccess.WRITE)
	if fa == null:
		errors.append("Could not write %s (error %d)" % [path, FileAccess.get_open_error()])
		return false
	fa.store_string(text + "\n")
	fa.close()
	return true

static func new_project(dir_path: String, project_name: String, brand: String = "BodyFrame", topic: String = "") -> ProjectData:
	var p := ProjectData.new()
	p.project_dir = dir_path.trim_suffix("/")
	p.episode = default_episode(project_name, brand, topic)
	p.storyboard = default_storyboard()
	p.storyboard["scenes"][0]["name"] = "Opening"
	var abs_dir := globalize_path(p.project_dir)
	DirAccess.make_dir_recursive_absolute(abs_dir)
	DirAccess.make_dir_recursive_absolute(abs_dir.path_join("assets"))
	DirAccess.make_dir_recursive_absolute(abs_dir.path_join("audio"))
	p.save()
	p.load_ok = true
	return p

func asset_exists(path: String) -> bool:
	if path.is_empty():
		return false
	if not (path.begins_with("res://") or path.begins_with("user://") or path.is_absolute_path()):
		return FileAccess.file_exists(globalize_path(project_dir.path_join(path)))
	return FileAccess.file_exists(globalize_path(path))

func resolve_asset(path: String) -> String:
	if path.is_empty():
		return ""
	if path.begins_with("res://") or path.begins_with("user://") or path.is_absolute_path():
		return globalize_path(path)
	return globalize_path(project_dir.path_join(path))

static func globalize_path(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	return path

static func _valid_color(s: String) -> bool:
	if s.is_empty() or not s.begins_with("#"):
		return false
	if s.length() not in [4, 7, 9]:
		return false
	return Color.from_string(s, Color(-1, -1, -1)) != Color(-1, -1, -1)

func fps() -> int:
	return maxi(1, int(episode.get("fps", 30)))

func duration() -> float:
	return maxf(0.01, float(episode.get("duration_seconds", 10.0)))

func frame_count() -> int:
	return int(round(duration() * fps()))

func palette_color(key: String, fallback: Color = Color.WHITE) -> Color:
	var pal = episode.get("palette", {})
	if pal is Dictionary and pal.has(key):
		return Color.from_string(str(pal[key]), fallback)
	return fallback

func style_value(key: String, fallback: Variant = null) -> Variant:
	var st = episode.get("style", {})
	if st is Dictionary:
		return st.get(key, fallback)
	return fallback

func element_by_id(id: String) -> Dictionary:
	for elem in storyboard.get("elements", []):
		if elem is Dictionary and str(elem.get("id", "")) == id:
			return elem
	return {}

func element_index(id: String) -> int:
	var elems = storyboard.get("elements", [])
	for i in range(elems.size()):
		if str(elems[i].get("id", "")) == id:
			return i
	return -1

func add_element(elem: Dictionary) -> void:
	if not storyboard.has("elements"):
		storyboard["elements"] = []
	storyboard["elements"].append(elem)

func remove_element(id: String) -> void:
	var idx := element_index(id)
	if idx >= 0:
		storyboard["elements"].remove_at(idx)

func scene_list() -> Array:
	return storyboard.get("scenes", [])
