extends Node2D

var _frame_count: int = 0

@onready var full_vp: SubViewport = $FullViewport
@onready var fg_vp: SubViewport = $FgViewport
@onready var bg_vp: SubViewport = $BgViewport

func _process(_delta: float) -> void:
	_frame_count += 1
	if _frame_count == 30:
		_save_icons()

func _save_icons() -> void:
	print("Capturing in-game viewports for icons...")
	
	# Full Icon (512x512)
	var full_img = full_vp.get_texture().get_image()
	if full_img:
		full_img.save_png("res://icon.png")
		print("Saved res://icon.png (512x512)")
		
		var icon_192 = full_img.duplicate()
		icon_192.resize(192, 192, Image.INTERPOLATE_LANCZOS)
		icon_192.save_png("res://assets/icons/android/android_icon_192.png")
		print("Saved res://assets/icons/android/android_icon_192.png (192x192)")

	# Foreground (432x432)
	var fg_img = fg_vp.get_texture().get_image()
	if fg_img:
		fg_img.save_png("res://assets/icons/android/android_adaptive_fg.png")
		print("Saved res://assets/icons/android/android_adaptive_fg.png (432x432)")

	# Background (432x432)
	var bg_img = bg_vp.get_texture().get_image()
	if bg_img:
		bg_img.save_png("res://assets/icons/android/android_adaptive_bg.png")
		print("Saved res://assets/icons/android/android_adaptive_bg.png (432x432)")

	# Adaptive Monochrome (432x432)
	if fg_img:
		var mono_img = fg_img.duplicate()
		for y in range(mono_img.get_height()):
			for x in range(mono_img.get_width()):
				var c = mono_img.get_pixel(x, y)
				if c.a > 0.1:
					mono_img.set_pixel(x, y, Color(1.0, 1.0, 1.0, c.a))
				else:
					mono_img.set_pixel(x, y, Color(0, 0, 0, 0))
		mono_img.save_png("res://assets/icons/android/android_adaptive_monochrome.png")
		print("Saved res://assets/icons/android/android_adaptive_monochrome.png (432x432)")

	print("Icon capture completed successfully!")
	get_tree().quit()
