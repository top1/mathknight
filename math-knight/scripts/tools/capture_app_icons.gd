@tool
extends SceneTree

# Script to render and save crisp in-game screenshots for MathKnight icons

func _init() -> void:
	print("Starting icon generator...")
	var root_node = Node2D.new()
	root.add_child(root_node)

	# 1. Capture Full Icon (512x512)
	var full_vp = SubViewport.new()
	full_vp.size = Vector2i(512, 512)
	full_vp.transparent_bg = false
	full_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root_node.add_child(full_vp)

	var bg = MenuBackground.new()
	bg.size = Vector2(512, 512)
	bg.theme_color = Color(0.18, 0.75, 0.95, 0.85)
	full_vp.add_child(bg)

	# Add dark backing color rect
	var color_rect = ColorRect.new()
	color_rect.color = Color(0.04, 0.06, 0.1, 1.0)
	color_rect.size = Vector2(512, 512)
	color_rect.show_behind_parent = true
	bg.add_child(color_rect)

	# Pedestal
	var pedestal = AsciiPedestal.new()
	pedestal.position = Vector2(256, 390)
	full_vp.add_child(pedestal)

	# Knight
	var knight = AsciiEntity.new()
	knight.entity_type = "knight"
	knight.position = Vector2(256, 320)
	knight.scale = Vector2(2.4, 2.4)
	knight.facing_direction = 1.0
	full_vp.add_child(knight)

	# Title Banner in Icon
	var title_lbl = Label.new()
	title_lbl.text = "MATH KNIGHT"
	if ResourceLoader.exists("res://assets/fonts/PressStart2P-Regular.ttf"):
		title_lbl.add_theme_font_override("font", load("res://assets/fonts/PressStart2P-Regular.ttf"))
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.25))
	title_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	title_lbl.add_theme_constant_override("shadow_offset_x", 3)
	title_lbl.add_theme_constant_override("shadow_offset_y", 3)
	title_lbl.add_theme_constant_override("shadow_outline_size", 4)
	title_lbl.position = Vector2(0, 48)
	title_lbl.size = Vector2(512, 40)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	full_vp.add_child(title_lbl)

	# 2. Capture Adaptive Foreground (432x432)
	var fg_vp = SubViewport.new()
	fg_vp.size = Vector2i(432, 432)
	fg_vp.transparent_bg = true
	fg_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root_node.add_child(fg_vp)

	var fg_knight = AsciiEntity.new()
	fg_knight.entity_type = "knight"
	fg_knight.position = Vector2(216, 260)
	fg_knight.scale = Vector2(2.0, 2.0)
	fg_knight.facing_direction = 1.0
	fg_vp.add_child(fg_knight)

	# 3. Capture Adaptive Background (432x432)
	var bg_vp = SubViewport.new()
	bg_vp.size = Vector2i(432, 432)
	bg_vp.transparent_bg = false
	bg_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root_node.add_child(bg_vp)

	var bg_only = MenuBackground.new()
	bg_only.size = Vector2(432, 432)
	bg_only.theme_color = Color(0.18, 0.75, 0.95, 0.85)
	bg_vp.add_child(bg_only)

	var bg_rect = ColorRect.new()
	bg_rect.color = Color(0.04, 0.06, 0.1, 1.0)
	bg_rect.size = Vector2(432, 432)
	bg_rect.show_behind_parent = true
	bg_only.add_child(bg_rect)

	var bg_pedestal = AsciiPedestal.new()
	bg_pedestal.position = Vector2(216, 340)
	bg_vp.add_child(bg_pedestal)

	# Let frames process for rendering
	for i in range(15):
		await process_frame

	# Save images
	var full_img = full_vp.get_texture().get_image()
	full_img.save_png("res://icon.png")
	print("Saved res://icon.png")

	var icon_192 = full_img.duplicate()
	icon_192.resize(192, 192, Image.INTERPOLATE_LANCZOS)
	icon_192.save_png("res://assets/icons/android/android_icon_192.png")
	print("Saved res://assets/icons/android/android_icon_192.png")

	var fg_img = fg_vp.get_texture().get_image()
	fg_img.save_png("res://assets/icons/android/android_adaptive_fg.png")
	print("Saved res://assets/icons/android/android_adaptive_fg.png")

	var bg_img = bg_vp.get_texture().get_image()
	bg_img.save_png("res://assets/icons/android/android_adaptive_bg.png")
	print("Saved res://assets/icons/android/android_adaptive_bg.png")

	# Generate monochrome from fg_img
	var mono_img = fg_img.duplicate()
	for y in range(mono_img.get_height()):
		for x in range(mono_img.get_width()):
			var c = mono_img.get_pixel(x, y)
			if c.a > 0.05:
				mono_img.set_pixel(x, y, Color(1.0, 1.0, 1.0, c.a))
			else:
				mono_img.set_pixel(x, y, Color(0, 0, 0, 0))
	mono_img.save_png("res://assets/icons/android/android_adaptive_monochrome.png")
	print("Saved res://assets/icons/android/android_adaptive_monochrome.png")

	print("All icons successfully generated!")
	quit()
