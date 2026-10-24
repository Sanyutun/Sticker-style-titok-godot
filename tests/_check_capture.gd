extends SceneTree
func _init() -> void:
	var out := []
	var code := OS.execute("ffmpeg", ["-hide_banner", "-nostats", "-i", "projects/salt_hypertension/audio/music_bed.wav", "-af", "loudnorm=I=-14:TP=-1.5:print_format=json", "-f", "null", "-"], out, true)
	print("CODE ", code, " LINES ", out.size())
	var text := "\n".join(out)
	var pos := text.rfind("{")
	print("JSONPOS ", pos, " TAIL ", text.substr(maxi(0, pos), 400))
	quit()
