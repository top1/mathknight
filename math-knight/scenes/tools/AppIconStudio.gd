extends Node2D

var _frame: int = 0

@onready var vp_main: SubViewport = $MainViewport
@onready var vp_fg: SubViewport = $FgViewport
@onready var vp_bg: SubViewport = $BgViewport

func _process(_delta: float) -> void:
	_frame += 1
	# Allow 45 frames so particles, matrix columns, and knight animations are fully active
	if _frame == 45:
		_capture_all_icons()

func _capture_all_icons() -> void:
	print("--- Exporting App Icons from Engine Screenshot ---")
	
	# 1. Main 512x512 Icon
	var img_main: Image = vp_main.get_texture().get_image()
	if img_main:
		img_main.save_png("res://icon.png")
		print("Successfully saved res://icon.png (512x512)")
		
		# 2. Legacy Android 192x192 Icon
		var img_192: Image = img_main.duplicate()
		img_192.resize(192, 192, Image.INTERPOLATE_LANCZOS)
		img_192.save_png("res://assets/icons/android/android_icon_192.png")
		print("Successfully saved res://assets/icons/android/android_icon_192.png (192x192)")

	# 3. Adaptive Foreground 432x432
	var img_fg: Image = vp_fg.get_texture().get_image()
	if img_fg:
		img_fg.save_png("res://assets/icons/android/android_adaptive_fg.png")
		print("Successfully saved res://assets/icons/android/android_adaptive_fg.png (432x432)")

	# 4. Adaptive Background 432x432
	var img_bg: Image = vp_bg.get_texture().get_image()
	if img_bg:
		img_bg.save_png("res://assets/icons/android/android_adaptive_bg.png")
		print("Successfully saved res://assets/icons/android/android_adaptive_bg.png (432x432)")

	# 5. Adaptive Monochrome 432x432
	if img_fg:
		var img_mono: Image = img_fg.duplicate()
		for y in range(img_mono.get_height()):
			for x in range(img_mono.get_width()):
				var px = img_mono.get_pixel(x, y)
				if px.a > 0.12:
					img_mono.set_pixel(x, y, Color(1.0, 1.0, 1.0, px.a))
				else:
					img_mono.set_pixel(x, y, Color(0, 0, 0, 0))
		img_mono.save_png("res://assets/icons/android/android_adaptive_monochrome.png")
		print("Successfully saved res://assets/icons/android/android_adaptive_monochrome.png (432x432)")

	print("--- All icon assets created and replaced! ---")
	get_tree().quit()
