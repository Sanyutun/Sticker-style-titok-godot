extends Node
## Captures the editor shell for visual review under Xvfb.

func _ready() -> void:
	var ed = load("res://scenes/editor/main_editor.tscn").instantiate()
	add_child(ed)
	for i in range(12):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("/tmp/opencode/editor_shot.png")
	print("EDITOR SHOT ", img.get_width(), "x", img.get_height())
	get_tree().quit()
