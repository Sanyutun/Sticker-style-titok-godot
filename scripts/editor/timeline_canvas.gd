class_name TimelineCanvas
extends Control
## Custom-drawn timeline: scene bands, ruler, track rows, keyframes and
## playhead. All edits are frame-snapped and reported to the editor.

signal time_changed(t: float)
signal element_selected(id: String)
signal key_selection_changed(has_selection: bool)
signal key_drag_started
signal key_drag_moved
signal key_drag_finished
signal key_add_requested(element_id: String, property: String, time: float)
signal status_message(text: String)

const RULER_H := 42.0
const ROW_H := 24.0
const NAME_W := 238.0
const TOP_PAD := 6.0
const SCENE_COLORS := [
	Color("#FF6A45"), Color("#62AEDA"), Color("#72CE9B"),
	Color("#E9C46A"), Color("#B79CED"), Color("#E76F8A"),
]

var project = null
var engine = null
var selected_id := ""
var filter_mode := "selected" # selected | camera | all
var current_time := 0.0
var rows: Array = []
var scroll_y := 0.0
var hover_row := -1
var sel_row := -1
var sel_track = null
var sel_key = null
var _drag_key := false
var _drag_started := false
var _scrubbing := false
var _last_key_x := 0.0
var _font := ThemeDB.fallback_font

func _ready() -> void:
	custom_minimum_size = Vector2(400, 220)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_CLICK
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_font = ThemeDB.fallback_font
	resized.connect(func():
		scroll_y = clampf(scroll_y, 0.0, _max_scroll())
		queue_redraw()
	)

func setup(p_project, p_engine) -> void:
	project = p_project
	engine = p_engine
	refresh()

func set_time(t: float, redraw: bool = true) -> void:
	current_time = clampf(t, 0.0, float(engine.duration) if engine != null else 10.0)
	if redraw:
		queue_redraw()

func set_selected(id: String) -> void:
	var changed := id != selected_id
	selected_id = id
	refresh()
	if changed:
		_ensure_selected_visible()

func set_filter(mode: String) -> void:
	filter_mode = mode
	refresh()

func refresh() -> void:
	rows.clear()
	sel_row = -1
	if engine == null:
		queue_redraw()
		return
	var wanted: Array = []
	if filter_mode == "all":
		wanted = engine.all_tracks()
	elif filter_mode == "camera":
		wanted = engine.get_tracks_for("@camera")
	else:
		var target := selected_id if not selected_id.is_empty() else "@camera"
		wanted = engine.get_tracks_for(target)
	for tr in wanted:
		if tr == null:
			continue
		var label: String = str(tr.property)
		if filter_mode == "all":
			var eid := str(tr.element_id)
			if eid == "@camera":
				label = "CAMERA · " + tr.property
			else:
				label = eid + " · " + tr.property
		rows.append({"element_id": tr.element_id, "property": tr.property, "track": tr, "label": label})
	# preserve key selection if still present
	if sel_track != null and sel_key != null:
		var found := false
		for i in range(rows.size()):
			if rows[i]["track"] == sel_track:
				sel_row = i
				if not sel_track.keys.has(sel_key):
					sel_key = null
					key_selection_changed.emit(false)
				found = true
				break
		if not found:
			sel_track = null
			sel_key = null
			key_selection_changed.emit(false)
	_ensure_selected_visible()
	queue_redraw()
	if project != null:
		pass

func _ensure_selected_visible() -> void:
	if sel_row < 0:
		return
	var y := sel_row * ROW_H - scroll_y
	var view_h := size.y - RULER_H - TOP_PAD
	if y < 0:
		scroll_y = sel_row * ROW_H
	elif y + ROW_H > view_h:
		scroll_y = sel_row * ROW_H + ROW_H - view_h
	scroll_y = clampf(scroll_y, 0.0, _max_scroll())

func _max_scroll() -> float:
	var content := rows.size() * ROW_H
	var view_h := maxf(40.0, size.y - RULER_H - TOP_PAD)
	return maxf(0.0, content - view_h)

func _track_y(i: int) -> float:
	return RULER_H + TOP_PAD + i * ROW_H - scroll_y

func _time_x(t: float) -> float:
	var x0 := NAME_W + 14.0
	var x1 := maxf(x0 + 40.0, size.x - 18.0)
	var dur := maxf(0.01, float(engine.duration) if engine != null else 10.0)
	return x0 + clampf(t / dur, 0.0, 1.0) * (x1 - x0)

func _time_at(x: float) -> float:
	var x0 := NAME_W + 14.0
	var x1 := maxf(x0 + 40.0, size.x - 18.0)
	var dur := maxf(0.01, float(engine.duration) if engine != null else 10.0)
	return clampf((x - x0) / maxf(1.0, x1 - x0), 0.0, 1.0) * dur

func _row_at(y: float) -> int:
	if y < RULER_H + TOP_PAD:
		return -1
	var local := y - RULER_H - TOP_PAD + scroll_y
	var i := int(floor(local / ROW_H))
	return i if i >= 0 and i < rows.size() else -1

func _key_under(mouse: Vector2) -> Dictionary:
	var i := _row_at(mouse.y)
	if i < 0:
		return {}
	var row: Dictionary = rows[i]
	var tr = row["track"]
	for k in tr.keys:
		var kx := _time_x(k.time)
		if absf(kx - mouse.x) <= 7.0:
			return {"row": i, "track": tr, "key": k}
	return {}

func _gui_input(event: InputEvent) -> void:
	if engine == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			scroll_y = clampf(scroll_y - ROW_H * 3.0, 0.0, _max_scroll())
			queue_redraw()
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			scroll_y = clampf(scroll_y + ROW_H * 3.0, 0.0, _max_scroll())
			queue_redraw()
			accept_event()
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			if mb.double_click and mb.position.y >= RULER_H + TOP_PAD:
				var dbl_row := _row_at(mb.position.y)
				if dbl_row >= 0 and _key_under(mb.position).is_empty():
					var drow: Dictionary = rows[dbl_row]
					key_add_requested.emit(str(drow["element_id"]), str(drow["property"]), engine.quantize_time(_time_at(mb.position.x)))
					accept_event()
					return
			if mb.position.y < RULER_H:
				_scrubbing = true
				current_time = engine.quantize_time(_time_at(mb.position.x))
				time_changed.emit(current_time)
				queue_redraw()
				accept_event()
				return
			var hit := _key_under(mb.position)
			if not hit.is_empty():
				sel_row = int(hit["row"])
				sel_track = hit["track"]
				sel_key = hit["key"]
				key_selection_changed.emit(true)
				_drag_key = true
				_drag_started = false
				_last_key_x = mb.position.x
				queue_redraw()
				accept_event()
				return
			var i := _row_at(mb.position.y)
			if i >= 0:
				sel_row = i
				var row: Dictionary = rows[i]
				element_selected.emit(str(row["element_id"]))
				current_time = engine.quantize_time(_time_at(mb.position.x))
				time_changed.emit(current_time)
				queue_redraw()
			else:
				background_clicked()
			accept_event()
		else:
			if _scrubbing:
				_scrubbing = false
				accept_event()
			elif _drag_key:
				_drag_key = false
				if _drag_started:
					key_drag_finished.emit()
				_drag_started = false
				accept_event()
		return
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _scrubbing:
			current_time = engine.quantize_time(_time_at(mm.position.x))
			time_changed.emit(current_time)
			queue_redraw()
			accept_event()
			return
		if _drag_key and sel_key != null and sel_track != null:
			if not _drag_started and absf(mm.position.x - _last_key_x) > 2.0:
				_drag_started = true
				key_drag_started.emit()
			if _drag_started:
				var t: float = engine.quantize_time(_time_at(mm.position.x))
				sel_key.time = clampf(t, 0.0, float(engine.duration))
				sel_track._sort()
				key_drag_moved.emit()
				status_message.emit("Keyframe %s → %.2fs (frame %d)" % [sel_track.property, sel_key.time, engine.frame_for_time(sel_key.time)])
				queue_redraw()
			accept_event()
			return
		var old_hover := hover_row
		hover_row = _row_at(mm.position.y)
		if hover_row != old_hover:
			queue_redraw()

func background_clicked() -> void:
	sel_track = null
	sel_key = null
	sel_row = -1
	key_selection_changed.emit(false)
	queue_redraw()

func _draw() -> void:
	if engine == null:
		return
	var dur := float(engine.duration)
	var x0 := NAME_W + 14.0
	var x1 := maxf(x0 + 40.0, size.x - 18.0)
	var total_w := size.x
	# backgrounds -------------------------------------------------------
	draw_rect(Rect2(0, 0, size.x, RULER_H), Color("#151A20"), true)
	draw_rect(Rect2(0, RULER_H, NAME_W, size.y - RULER_H), Color("#161B21"), true)
	draw_rect(Rect2(NAME_W, RULER_H, size.x - NAME_W, size.y - RULER_H), Color("#101419"), true)
	draw_line(Vector2(NAME_W, 0), Vector2(NAME_W, size.y), Color("#303A46"), 1.0)
	draw_line(Vector2(0, RULER_H), Vector2(size.x, RULER_H), Color("#303A46"), 1.0)
	# scene bands -------------------------------------------------------
	var scenes: Array = engine.scenes
	for i in range(scenes.size()):
		var s: Dictionary = scenes[i]
		var st := float(s.get("start", 0.0))
		var en := float(s.get("end", dur))
		var sx := _time_x(st)
		var ex := _time_x(en)
		var col: Color = SCENE_COLORS[i % SCENE_COLORS.size()]
		draw_rect(Rect2(sx, 0, maxf(1.0, ex - sx), 18), Color(col, 0.30), true)
		draw_rect(Rect2(sx, 17, maxf(1.0, ex - sx), 1.5), Color(col, 0.95), true)
		var label := str(s.get("name", "")).to_upper()
		if ex - sx > 58:
			var tw := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
			if tw < ex - sx - 8:
				draw_string(_font, Vector2(sx + 5, 13), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(col, 0.95))
	# ruler ticks -------------------------------------------------------
	var sec := 0.0
	while sec <= dur + 0.001:
		var tx := _time_x(sec)
		draw_line(Vector2(tx, 20), Vector2(tx, RULER_H - 3), Color(1, 1, 1, 0.22), 1.0)
		var lab := ("%ds" % int(sec)) if absf(sec - round(sec)) < 0.001 else ("%.1fs" % sec)
		draw_string(_font, Vector2(tx + 4, RULER_H - 7), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#8B98A8"))
		var half := sec + 0.5
		if half < dur:
			var hx := _time_x(half)
			draw_line(Vector2(hx, RULER_H - 9), Vector2(hx, RULER_H - 3), Color(1, 1, 1, 0.14), 1.0)
		sec += 1.0
	# frame ticks if roomy
	var px_per_sec := (x1 - x0) / maxf(0.001, dur)
	if px_per_sec > 420.0:
		var f := 0
		while f <= engine.frame_count():
			var fx := _time_x(engine.time_for_frame(f))
			draw_line(Vector2(fx, RULER_H - 4), Vector2(fx, RULER_H), Color(1, 1, 1, 0.10), 1.0)
			f += 1
	# column heading ----------------------------------------------------
	draw_string(_font, Vector2(12, RULER_H + 18), "TRACKS", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("#66717F"))
	draw_string(_font, Vector2(NAME_W - 74, RULER_H + 18), "KEYFRAMES", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("#66717F"))
	# rows --------------------------------------------------------------
	var view_top := RULER_H + TOP_PAD
	var view_bottom := size.y
	for i in range(rows.size()):
		var y := _track_y(i)
		if y + ROW_H < view_top or y > view_bottom:
			continue
		if y < view_top:
			continue
		var row: Dictionary = rows[i]
		var tr = row["track"]
		var selected_row := i == sel_row
		var bg := Color("#151A20") if i % 2 == 0 else Color("#12171D")
		if i == hover_row:
			bg = Color("#1B222B")
		if selected_row:
			bg = Color("#23221F")
		draw_rect(Rect2(0, y, size.x, ROW_H), bg, true)
		if selected_row:
			draw_rect(Rect2(0, y, 3, ROW_H), Color("#FF6A45"), true)
		draw_line(Vector2(0, y + ROW_H), Vector2(size.x, y + ROW_H), Color(1, 1, 1, 0.035), 1.0)
		# label
		var fg := Color("#C9D3DF") if selected_row else Color("#9AA7B6")
		var element_col := Color("#FF6A45") if tr.element_id == "@camera" else Color("#62AEDA")
		draw_circle(Vector2(13, y + ROW_H * 0.5), 2.5, element_col)
		var label := str(row["label"])
		var maxw := NAME_W - 30
		label = _elide(label, maxw, _font, 11)
		draw_string(_font, Vector2(22, y + ROW_H * 0.5 + 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, fg)
		var count_txt := str(tr.keys.size())
		draw_string(_font, Vector2(NAME_W - 20, y + ROW_H * 0.5 + 4), count_txt, HORIZONTAL_ALIGNMENT_RIGHT, 0, 10, Color("#66717F"))
		# keyframes
		for k in tr.keys:
			var kx := _time_x(k.time)
			if kx < NAME_W + 2 or kx > size.x - 4:
				continue
			var ky := y + ROW_H * 0.5
			var is_sel: bool = (sel_key == k and sel_track == tr)
			_draw_diamond(Vector2(kx, ky), 4.2 if is_sel else 3.4, Color("#FFB59E") if is_sel else Color("#E8EDF3"), is_sel)
	# playhead ----------------------------------------------------------
	var px := _time_x(current_time)
	draw_line(Vector2(px, 0), Vector2(px, size.y), Color("#FF6A45"), 1.8)
	draw_rect(Rect2(px - 5, 0, 10, 8), Color("#FF6A45"), true)
	var frame: int = int(engine.frame_for_time(current_time))
	var bubble := "%05.2fs  f%03d" % [current_time, frame]
	var bw := _font.get_string_size(bubble, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	var bx := clampf(px + 8, 4, size.x - bw - 22)
	draw_rect(Rect2(bx, RULER_H - 18, bw + 14, 18), Color("#3A1C15"), true)
	draw_rect(Rect2(bx, RULER_H - 18, 2, 18), Color("#FF6A45"), true)
	draw_string(_font, Vector2(bx + 8, RULER_H - 5), bubble, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#FFC7B8"))
	# scrollbar ---------------------------------------------------------
	var maxs := _max_scroll()
	if maxs > 0.0:
		var track_h := maxf(20.0, size.y - RULER_H - TOP_PAD)
		var thumb_h := maxf(24.0, track_h * (track_h / (track_h + maxs)))
		var ty := RULER_H + TOP_PAD + (track_h - thumb_h) * (scroll_y / maxs)
		draw_rect(Rect2(size.x - 5, ty, 3, thumb_h), Color(1, 1, 1, 0.18), true)
	# empty state -------------------------------------------------------
	if rows.is_empty():
		var msg := "No tracks for this selection. Add a keyframe in the Inspector."
		var mw := _font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_string(_font, Vector2(NAME_W + (size.x - NAME_W - mw) * 0.5, RULER_H + 44), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#66717F"))

func _draw_diamond(c: Vector2, r: float, col: Color, filled: bool) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	if filled:
		draw_colored_polygon(pts, col)
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color("#111419"), 1.0, true)
	else:
		draw_colored_polygon(pts, Color("#161B21"))
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), col, 1.2, true)

func _elide(text: String, max_width: float, font: Font, fs: int) -> String:
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= max_width:
		return text
	var lo := 0
	var hi := text.length()
	while lo < hi:
		var mid := (lo + hi + 1) >> 1
		var candidate := text.substr(0, mid) + "…"
		if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= max_width:
			lo = mid
		else:
			hi = mid - 1
	return text.substr(0, maxi(1, lo)) + "…"

func add_key_at_playhead() -> void:
	if sel_row < 0 or sel_row >= rows.size():
		return
	var row: Dictionary = rows[sel_row]
	key_add_requested.emit(str(row["element_id"]), str(row["property"]), engine.quantize_time(current_time))

func selected_key_info() -> Dictionary:
	return {"track": sel_track, "key": sel_key, "row": sel_row}

func delete_selected_key() -> bool:
	if sel_key == null or sel_track == null:
		return false
	sel_track.keys.erase(sel_key)
	sel_track._sort()
	sel_key = null
	key_selection_changed.emit(false)
	queue_redraw()
	return true

func select_track_row(index: int) -> void:
	if index < 0 or index >= rows.size():
		return
	sel_row = index
	sel_track = rows[index]["track"]
	sel_key = null
	key_selection_changed.emit(false)
	_ensure_selected_visible()
	queue_redraw()

func step_zoom() -> void:
	pass
