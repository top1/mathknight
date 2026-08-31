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
	if _frames == 10:
		if _inv_instance and _inv_instance.has_method("_select_item"):
			var pan_item = CosmeticDatabase.get_item("sword_pan")
			_inv_instance._select_item(pan_item)
	if _frames >= 40:
		var image = root.get_viewport().get_texture().get_image()
		if image:
			var err = image.save_png("c:/MathKnight/cosmetic_pan_preview.png")
			print("Saved screenshot to c:/MathKnight/cosmetic_pan_preview.png, status: ", err)
		quit(0)
		return true
	return false
