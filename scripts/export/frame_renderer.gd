class_name FrameRenderer
extends Node
## Deterministic offline frame renderer. Uses the same CompositionStage as the
## editor preview, but at full output resolution with editor chrome disabled.

const STAGE_SCENE = preload("res://scenes/stage/composition_stage.tscn")

var viewport: SubViewport
var stage = null
var project = null
var engine = null
var output_size := Vector2i(1920, 1080)

func setup(p_project, p_engine, size: Vector2i, include_subtitles: bool = true) -> void:
	project = p_project
	engine = p_engine
	output_size = size
	viewport = SubViewport.new()
	viewport.name = "ExportViewport"
	viewport.size = size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	viewport.disable_3d = true
	viewport.msaa_2d = Viewport.MSAA_2X
	add_child(viewport)
	stage = STAGE_SCENE.instantiate()
	viewport.add_child(stage)
	stage.build(project, engine)
	stage.set_viewport_size(Vector2(size))
	stage.set_editor_mode(false)
	stage.set_overlays(false, false, false, false)
	stage.show_subtitles = include_subtitles

func render_frame(time: float, path: String) -> bool:
	if stage == null:
		return false
	stage.evaluate(time)
	await RenderingServer.frame_post_draw
	var img := viewport.get_texture().get_image()
	if img == null or img.is_empty():
		return false
	if img.get_width() != output_size.x or img.get_height() != output_size.y:
		img.resize(output_size.x, output_size.y, Image.INTERPOLATE_LANCZOS)
	return img.save_png(path) == OK

func render_to_image(time: float) -> Image:
	if stage == null:
		return null
	stage.evaluate(time)
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()
