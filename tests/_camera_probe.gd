extends SceneTree
const ProjectData = preload("res://scripts/project/project_data.gd")
const TimelineEngine = preload("res://scripts/animation/timeline_engine.gd")
func _init() -> void:
	var pd = ProjectData.new()
	pd.load_from_dir("res://projects/salt_hypertension")
	var eng = TimelineEngine.new(); eng.setup_from_project(pd)
	for t in [0.0, 0.5, 1.2, 1.6, 1.8, 1.95, 2.0, 2.18, 3.5, 4.02, 4.3, 4.45, 4.55, 6.6, 6.7, 7.2, 8.1, 8.4, 8.45, 9.0]:
		var cam = eng.evaluate_camera(t)
		var st = eng.evaluate_at_time(t)["elements"]
		var body = st.get("body", {})
		var hook = st.get("hook_text", {})
		print("t=%.2f cam=(%.0f,%.0f) z=%.3f scene=%s body_op=%s hook_op=%s" % [t, cam.position.x, cam.position.y, cam.zoom, eng.scene_at(t).get("name","?"), str(body.get("opacity","-")), str(hook.get("opacity","-"))])
	quit()
