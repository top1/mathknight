extends SceneTree

var _frames: int = 0
var _title_inst: Control

func _init() -> void:
	print("Starting TitleScreen capture facing right with distinct head...")
	var scene_res = load("res://scenes/menu/TitleScreen.tscn")
	if scene_res:
		_title_inst = scene_res.instantiate()
		root.add_child(_title_inst)
	else:
		print("Failed to load TitleScreen scene")
		quit(1)

func _process(delta: float) -> bool:
	_frames += 1
	if _frames == 10:
		if _title_inst:
			_title_inst._current_dir_index = 0 # East
			_title_inst._update_knight_direction()
	if _frames >= 30:
		var image = root.get_viewport().get_texture().get_image()
		if image:
			var err = image.save_png("c:/MathKnight/title_preview_distinct_head_right.png")
			print("Saved screenshot to c:/MathKnight/title_preview_distinct_head_right.png, status: ", err)
		quit(0)
		return true
	return false
