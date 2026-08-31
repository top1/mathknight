extends SceneTree

var _frames: int = 0

func _init() -> void:
	print("Starting 3D Free Rotation & Dense Helmet TitleScreen capture...")
	var scene_res = load("res://scenes/menu/TitleScreen.tscn")
	if scene_res:
		var inst = scene_res.instantiate()
		root.add_child(inst)
	else:
		print("Failed to load TitleScreen scene")
		quit(1)

func _process(delta: float) -> bool:
	_frames += 1
	if _frames >= 35:
		var image = root.get_viewport().get_texture().get_image()
		if image:
			var err = image.save_png("c:/MathKnight/title_preview_3d_turntable.png")
			print("Saved screenshot to c:/MathKnight/title_preview_3d_turntable.png, status: ", err)
		quit(0)
		return true
	return false
