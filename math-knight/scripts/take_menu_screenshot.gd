extends SceneTree

var _frames: int = 0
var _inv_instance: Node

func _init() -> void:
	print("Starting cosmetic screenshot capture...")
	var scene_res = load("res://scenes/menu/CosmeticInventory.tscn")
	if scene_res:
		_inv_instance = scene_res.instantiate()
		root.add_child(_inv_instance)
	else:
		print("Failed to load CosmeticInventory scene")
		quit(1)

func _process(delta: float) -> bool:
	_frames += 1
	if _frames >= 40:
		var image = root.get_viewport().get_texture().get_image()
		if image:
			var err = image.save_png("c:/MathKnight/cosmetic_preview_new.png")
			print("Saved screenshot to c:/MathKnight/cosmetic_preview_new.png, status: ", err)
		quit(0)
		return true
	return false
