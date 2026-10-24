extends SceneTree
func _initialize():
	var paths = [
		"res://scripts/animation/easing_library.gd",
		"res://scripts/animation/keyframe_data.gd",
		"res://scripts/animation/animation_track.gd",
		"res://scripts/animation/animation_evaluator.gd",
		"res://scripts/animation/timeline_engine.gd",
		"res://scripts/project/project_data.gd",
		"res://scripts/camera/camera_controller.gd",
		"res://scripts/camera/camera_path.gd",
		"res://scripts/elements/element_renderer.gd",
		"res://scripts/elements/sticker_renderer.gd",
		"res://scripts/elements/text_renderer.gd",
		"res://scripts/elements/shape_renderer.gd",
		"res://scripts/elements/arrow_renderer.gd",
		"res://scripts/elements/chart_renderer.gd",
		"res://scripts/elements/character_renderer.gd",
		"res://scripts/elements/blood_vessel_renderer.gd",
		"res://scripts/elements/pressure_gauge_renderer.gd",
		"res://scripts/stage/stage.gd",
		"res://scripts/stage/subtitle_overlay.gd",
	]
	for p in paths:
		var s = load(p)
		print(("OK " if s != null else "FAIL ") + p)
	var pd = load("res://scripts/project/project_data.gd").new()
	pd.episode = pd.default_episode("Test", "Brand", "Topic")
	pd.storyboard = pd.default_storyboard()
	pd._normalize_storyboard()
	pd._validate_internal()
	print("errors=", pd.errors)
	print("warnings=", pd.warnings)
	var eng = load("res://scripts/animation/timeline_engine.gd").new()
	eng.setup_from_project(pd)
	print("frames=", eng.frame_count(), " max=", eng.max_time())
	var x = load("res://scenes/stage/composition_stage.tscn").instantiate()
	root.add_child(x)
	x.build(pd, eng)
	x.evaluate(1.0)
	print("stage elements=", x.element_nodes.size())
	quit()
