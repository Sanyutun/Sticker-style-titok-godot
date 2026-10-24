extends Node
const ProjectData = preload("res://scripts/project/project_data.gd")
const TimelineEngine = preload("res://scripts/animation/timeline_engine.gd")
func _ready() -> void:
	var pd = ProjectData.new()
	var ok = pd.load_from_dir("res://projects/salt_hypertension")
	print("LOAD ", ok, " ERRORS ", pd.errors, " WARN ", pd.warnings)
	var eng = TimelineEngine.new(); eng.setup_from_project(pd)
	print("frames ", eng.frame_count(), " max_time ", eng.max_time())
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.disable_3d = true
	add_child(vp)
	var stage = load("res://scenes/stage/composition_stage.tscn").instantiate()
	vp.add_child(stage)
	stage.build(pd, eng)
	stage.set_editor_mode(false)
	stage.set_viewport_size(Vector2(1280, 720))
	stage.show_subtitles = false
	var times = [7.5, 7.8, 8.1, 8.25, 8.35, 8.45, 8.6, 8.8]
	await get_tree().process_frame
	for t in times:
		stage.evaluate(t)
		await RenderingServer.frame_post_draw
		await get_tree().process_frame
		var img = vp.get_texture().get_image()
		var path = "/tmp/opencode/stills/frame_%05.2f.png" % t
		img.save_png(path)
		print("saved ", path, " ", img.get_width(), "x", img.get_height())
	get_tree().quit()
