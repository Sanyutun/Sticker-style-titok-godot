class_name UndoStack
extends RefCounted
## Snapshot-based undo/redo. Project JSON is small (<300 KB) and snapshots make
## every edit path safe, including structural changes and timeline edits.

const MAX_DEPTH := 120

var _undo: Array = [] # [{episode, storyboard, description}]
var _redo: Array = []
var _last_desc := ""
var _last_time_ms := 0
var _last_coalesce := ""

func clear() -> void:
	_undo.clear()
	_redo.clear()
	_last_desc = ""
	_last_coalesce = ""

func can_undo() -> bool:
	return not _undo.is_empty()

func can_redo() -> bool:
	return not _redo.is_empty()

func undo_description() -> String:
	return str(_undo.back().get("description", "")) if not _undo.is_empty() else ""

func redo_description() -> String:
	return str(_redo.back().get("description", "")) if not _redo.is_empty() else ""

## Capture the state *before* a mutation. Consecutive edits that share a
## coalesce key (e.g. typing in one text field) collapse into one undo entry.
func push(episode: Dictionary, storyboard: Dictionary, description: String, coalesce_key: String = "") -> void:
	var now := Time.get_ticks_msec()
	if not coalesce_key.is_empty() and coalesce_key == _last_coalesce and now - _last_time_ms < 1200 and not _undo.is_empty():
		_last_time_ms = now
		_last_desc = description
		return
	var snap := {
		"episode": episode.duplicate(true),
		"storyboard": storyboard.duplicate(true),
		"description": description,
	}
	_undo.append(snap)
	if _undo.size() > MAX_DEPTH:
		_undo.pop_front()
	_redo.clear()
	_last_desc = description
	_last_coalesce = coalesce_key
	_last_time_ms = now

## Push an exact pre-recorded snapshot (used by drag operations).
func push_snapshot(snapshot: Dictionary, description: String) -> void:
	if snapshot.is_empty():
		return
	_undo.append({
		"episode": snapshot.get("episode", {}).duplicate(true),
		"storyboard": snapshot.get("storyboard", {}).duplicate(true),
		"description": description,
	})
	if _undo.size() > MAX_DEPTH:
		_undo.pop_front()
	_redo.clear()
	_last_coalesce = ""
	_last_desc = description
	_last_time_ms = Time.get_ticks_msec()

func undo(current_episode: Dictionary, current_storyboard: Dictionary) -> Dictionary:
	if _undo.is_empty():
		return {}
	var entry: Dictionary = _undo.pop_back()
	_redo.append({
		"episode": current_episode.duplicate(true),
		"storyboard": current_storyboard.duplicate(true),
		"description": str(entry.get("description", "")),
	})
	_last_coalesce = ""
	return entry

func redo(current_episode: Dictionary, current_storyboard: Dictionary) -> Dictionary:
	if _redo.is_empty():
		return {}
	var entry: Dictionary = _redo.pop_back()
	_undo.append({
		"episode": current_episode.duplicate(true),
		"storyboard": current_storyboard.duplicate(true),
		"description": str(entry.get("description", "")),
	})
	_last_coalesce = ""
	return entry
