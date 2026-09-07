extends Control

# Captures actual in-game TitleScreen screenshot and exports app icons

var _timer: float = 0.0
var _captured: bool = false

func _ready() -> void:
	# Instantiate TitleScreen
	var title_scene = load("res://scenes/menu/TitleScreen.tscn").instantiate()
	add_child(title_scene)

func _process(delta: float) -> void:
	_timer += delta
	# Wait 1.5 seconds so title finishes decode animation and knight rotates nicely
	if _timer >= 1.5 and not _captured:
		_captured = true
		_capture()

func _capture() -> void:
	print("Capturing title screen screenshot...")
	var vp = get_viewport()
	var img = vp.get_texture().get_image()
	if not img:
		print("Error: Could not get viewport image!")
		get_tree().quit(1)
		return
	
	# Save full title screen screenshot
	img.save_png("res://screenshot_titlescreen.png")
	print("Saved res://screenshot_titlescreen.png (", img.get_width(), "x", img.get_height(), ")")

	# The game viewport is 640x360
	# Let's create the app icon (512x512) centered around the Knight Dais & Title or a beautifully cropped view
	# The Knight Dais on TitleScreen is around x: 40..210, y: 110..310
	# Let's crop a square around the Knight Dais (x: 20..220, y: 100..300) -> 200x200
	var knight_crop = Image.create(200, 200, false, Image.FORMAT_RGBA8)
	knight_crop.blit_rect(img, Rect2i(20, 105, 200, 200), Vector2i.ZERO)
	
	# 512x512 icon
	var icon_512 = knight_crop.duplicate()
	icon_512.resize(512, 512, Image.INTERPOLATE_LANCZOS)
	icon_512.save_png("res://icon.png")
	print("Saved res://icon.png")

	# 192x192 legacy icon
	var icon_192 = knight_crop.duplicate()
	icon_192.resize(192, 192, Image.INTERPOLATE_LANCZOS)
	icon_192.save_png("res://assets/icons/android/android_icon_192.png")
	print("Saved res://assets/icons/android/android_icon_192.png")

	# Adaptive background (432x432)
	# Crop menu background without text or center
	var bg_crop = Image.create(360, 360, false, Image.FORMAT_RGBA8)
	bg_crop.blit_rect(img, Rect2i(0, 0, 360, 360), Vector2i.ZERO)
	var bg_432 = bg_crop.duplicate()
	bg_432.resize(432, 432, Image.INTERPOLATE_LANCZOS)
	bg_432.save_png("res://assets/icons/android/android_adaptive_bg.png")
	print("Saved res://assets/icons/android/android_adaptive_bg.png")

	# Adaptive foreground (432x432)
	var fg_432 = knight_crop.duplicate()
	fg_432.resize(432, 432, Image.INTERPOLATE_LANCZOS)
	fg_432.save_png("res://assets/icons/android/android_adaptive_fg.png")
	print("Saved res://assets/icons/android/android_adaptive_fg.png")

	# Adaptive monochrome (432x432)
	var mono_432 = fg_432.duplicate()
	for y in range(mono_432.get_height()):
		for x in range(mono_432.get_width()):
			var c = mono_432.get_pixel(x, y)
			var lum = c.r * 0.299 + c.g * 0.587 + c.b * 0.114
			if lum > 0.18:
				mono_432.set_pixel(x, y, Color(1.0, 1.0, 1.0, 1.0))
			else:
				mono_432.set_pixel(x, y, Color(0, 0, 0, 0))
	mono_432.save_png("res://assets/icons/android/android_adaptive_monochrome.png")
	print("Saved res://assets/icons/android/android_adaptive_monochrome.png")

	print("Done capturing screenshot icons!")
	get_tree().quit()
