extends SceneTree

var _frames: int = 0

func _init() -> void:
	print("Starting TitleScreen capture with Silver Gray Helmet & Clear Eyes...")
	var scene_res = load("res://scenes/menu/TitleScreen.tscn")
	if scene_res:
		var inst = scene_res.instantiate()
		root.add_child(inst)
	else:
		print("Failed to load TitleScreen scene")
		quit(1)

func _process(delta: float) -> bool:
	_frames += 1
	if _frames >= 30:
		var image = root.get_viewport().get_texture().get_image()
		if image:
			var err = image.save_png("c:/MathKnight/title_preview_silver_helmet.png")
			print("Saved screenshot to c:/MathKnight/title_preview_silver_helmet.png, status: ", err)
		quit(0)
		return true
	return false
