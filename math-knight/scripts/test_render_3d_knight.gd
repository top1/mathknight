extends SceneTree

func _init() -> void:
	print("Starting 3D Manikin ASCII Knight Visual Render Test...")
	var root_node = Control.new()
	root_node.custom_minimum_size = Vector2(640, 360)
	root_node.size = Vector2(640, 360)
	root.add_child(root_node)
	
	# Background
	var bg = ColorRect.new()
	bg.color = Color("#0d1117")
	bg.size = Vector2(640, 360)
	root_node.add_child(bg)
	
	# 1. Idle Knight (Facing Right)
	var knight1 = AsciiEntity.new()
	knight1.entity_type = "knight"
	knight1.facing_direction = 1.0
	knight1.position = Vector2(180, 180)
	knight1.scale = Vector2(2.0, 2.0)
	root_node.add_child(knight1)
	
	# 2. Windup / Slashing Knight (Facing Right)
	var knight2 = AsciiEntity.new()
	knight2.entity_type = "knight"
	knight2.facing_direction = 1.0
	knight2.position = Vector2(440, 180)
	knight2.scale = Vector2(2.0, 2.0)
	knight2.equipped_sword = "sword_flame"
	root_node.add_child(knight2)
	knight2.play_slash()
	
	# Wait a few frames for rendering
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	
	var img = root.get_viewport().get_texture().get_image()
	img.save_png("c:/MathKnight/preview_ascii_3d_knight.png")
	print("Saved c:/MathKnight/preview_ascii_3d_knight.png successfully!")
	quit(0)
