class_name Test3DStickmanKnight
extends Control

## ═══════════════════════════════════════════════════════════════════════════
## Test3DStickmanKnight — 3D Shader Matrix Inspection Studio
##
## Compares:
##   LEFT:  Legacy 2D Polygon Entity
##   RIGHT: New 3D Stickman/Monster Rig in SHADER MATRIX Mode
## ═══════════════════════════════════════════════════════════════════════════

const AsciiEntityScript = preload("res://scripts/utils/AsciiEntity.gd")
const Ascii3DRendererScript = preload("res://scenes/knight/3d/Ascii3DRenderer.gd")

var legacy_entity: Node2D
var new_3d_entity: Ascii3DRenderer

var _timer: float = 0.0
var _turntable_active: bool = false
var _status_label: Label
var _current_archetype: String = "knight"

var _capture_step: int = 0


func _ready() -> void:
	# 1. Dark Theme Background
	var bg = ColorRect.new()
	bg.color = Color("#060a12")
	bg.size = Vector2(640, 360)
	add_child(bg)

	# 2. Arena Divider Line
	var divider = Line2D.new()
	divider.add_point(Vector2(320, 10))
	divider.add_point(Vector2(320, 350))
	divider.default_color = Color("#1e293b")
	divider.width = 1.0
	add_child(divider)

	# 3. Studio Header Banner
	var banner = Label.new()
	banner.text = "MATH KNIGHT — 3D SHADER MATRIX & MONSTER STUDIO"
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.size = Vector2(640, 24)
	banner.position = Vector2(0, 8)
	banner.add_theme_color_override("font_color", Color("#ffd600"))
	banner.add_theme_font_size_override("font_size", 10)
	add_child(banner)

	# 4. Side Headers
	var label_legacy = Label.new()
	label_legacy.text = "[ LEGACY 2D MESH ]\nFlat 2D Polygons"
	label_legacy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_legacy.size = Vector2(320, 32)
	label_legacy.position = Vector2(0, 30)
	label_legacy.add_theme_color_override("font_color", Color("#78909c"))
	label_legacy.add_theme_font_size_override("font_size", 9)
	add_child(label_legacy)

	var label_new = Label.new()
	label_new.text = "[ 3D SHADER MATRIX ]\nKinematic 3D Rig • Real-Time CRT Rasterizer"
	label_new.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_new.size = Vector2(320, 32)
	label_new.position = Vector2(320, 30)
	label_new.add_theme_color_override("font_color", Color("#00e5ff"))
	label_new.add_theme_font_size_override("font_size", 9)
	add_child(label_new)

	# 5. Entity Archetype Selection Bar
	var arch_bar = HBoxContainer.new()
	arch_bar.position = Vector2(10, 60)
	arch_bar.size = Vector2(620, 22)
	arch_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	arch_bar.add_theme_constant_override("separation", 6)
	add_child(arch_bar)

	var archetypes = ["knight", "goblin", "skeleton", "slime", "boss"]
	for a in archetypes:
		var btn = Button.new()
		btn.text = "🛡 %s" % a.to_upper()
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 8)
		btn.pressed.connect(func(): _set_archetype(a))
		arch_bar.add_child(btn)

	# 6. Mode & Action Bar
	var bar = HBoxContainer.new()
	bar.position = Vector2(10, 85)
	bar.size = Vector2(620, 22)
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 6)
	add_child(bar)

	var btn_slash = Button.new()
	btn_slash.text = "⚔ [Space] Attack/Slash"
	btn_slash.focus_mode = Control.FOCUS_NONE
	btn_slash.add_theme_font_size_override("font_size", 8)
	btn_slash.pressed.connect(_trigger_attack)
	bar.add_child(btn_slash)

	var btn_walk = Button.new()
	btn_walk.text = "🚶 [W] Walk"
	btn_walk.focus_mode = Control.FOCUS_NONE
	btn_walk.add_theme_font_size_override("font_size", 8)
	btn_walk.pressed.connect(_trigger_walk)
	bar.add_child(btn_walk)

	var btn_idle = Button.new()
	btn_idle.text = "🛡 [I] Idle"
	btn_idle.focus_mode = Control.FOCUS_NONE
	btn_idle.add_theme_font_size_override("font_size", 8)
	btn_idle.pressed.connect(_trigger_idle)
	bar.add_child(btn_idle)

	var btn_turntable = Button.new()
	btn_turntable.text = "🔄 [T] Turntable"
	btn_turntable.focus_mode = Control.FOCUS_NONE
	btn_turntable.add_theme_font_size_override("font_size", 8)
	btn_turntable.pressed.connect(func(): _turntable_active = not _turntable_active)
	bar.add_child(btn_turntable)

	# 7. Dais Platforms
	var dais_left = ColorRect.new()
	dais_left.color = Color("#0f2137")
	dais_left.size = Vector2(140, 14)
	dais_left.position = Vector2(90, 270)
	add_child(dais_left)

	var dais_right = ColorRect.new()
	dais_right.color = Color("#0f2137")
	dais_right.size = Vector2(140, 14)
	dais_right.position = Vector2(410, 270)
	add_child(dais_right)

	# 8. Instantiate Legacy 2D Entity (Left)
	legacy_entity = AsciiEntityScript.new()
	legacy_entity.entity_type = "knight"
	legacy_entity.facing_direction = 1.0
	legacy_entity.position = Vector2(160, 220)
	add_child(legacy_entity)
	if legacy_entity.renderer_3d:
		legacy_entity.renderer_3d.visible = false

	# 9. Instantiate 3D Shader Matrix Entity (Right)
	new_3d_entity = Ascii3DRendererScript.new()
	new_3d_entity.entity_type = "knight"
	new_3d_entity.facing_direction = 1.0
	new_3d_entity.render_mode = Ascii3DRenderer.RenderMode.SHADER_MATRIX
	new_3d_entity.position = Vector2(480, 215)
	add_child(new_3d_entity)

	# 10. Footer Status
	_status_label = Label.new()
	_status_label.text = "ACTIVE: KNIGHT (SHADER MATRIX)  •  PRESS [SPACE] TO ATTACK"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.size = Vector2(640, 24)
	_status_label.position = Vector2(0, 328)
	_status_label.add_theme_color_override("font_color", Color("#00e5ff"))
	_status_label.add_theme_font_size_override("font_size", 9)
	add_child(_status_label)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE: _trigger_attack()
			KEY_W: _trigger_walk()
			KEY_I: _trigger_idle()
			KEY_T: _turntable_active = not _turntable_active
			KEY_1: _set_archetype("knight")
			KEY_2: _set_archetype("goblin")
			KEY_3: _set_archetype("skeleton")
			KEY_4: _set_archetype("slime")
			KEY_5: _set_archetype("boss")


func _set_archetype(arch: String) -> void:
	_current_archetype = arch
	if legacy_entity:
		legacy_entity.entity_type = arch
		if legacy_entity.renderer_3d:
			legacy_entity.renderer_3d.visible = false
	if new_3d_entity:
		new_3d_entity.entity_type = arch
	_status_label.text = "ACTIVE ARCHETYPE: %s (3D SHADER MATRIX)" % arch.to_upper()


func _trigger_attack() -> void:
	if legacy_entity and legacy_entity.has_method("play_slash"):
		legacy_entity.play_slash()
	if new_3d_entity:
		new_3d_entity.play_attack()


func _trigger_walk() -> void:
	if legacy_entity and legacy_entity.has_method("play_walk"):
		legacy_entity.play_walk()
	if new_3d_entity:
		new_3d_entity.play_walk()


func _trigger_idle() -> void:
	if legacy_entity and legacy_entity.has_method("play_idle"):
		legacy_entity.play_idle()
	if new_3d_entity:
		new_3d_entity.play_idle()


func _process(delta: float) -> void:
	_timer += delta

	# Automated capture timeline for user walkthrough
	if _timer >= 0.6 and _capture_step == 0:
		_capture_step = 1
		_capture_screenshot("c:/MathKnight/preview_knight_matrix.png")
		_trigger_attack() # Trigger the overhauled slash!

	elif _timer >= 0.74 and _capture_step == 1:
		_capture_step = 2
		# Capture peak dynamic cleave at midpoint of slash arc!
		_capture_screenshot("c:/MathKnight/preview_slash_arc.png")
		_set_archetype("goblin")

	elif _timer >= 1.5 and _capture_step == 2:
		_capture_step = 3
		_capture_screenshot("c:/MathKnight/preview_goblin_matrix.png")
		_set_archetype("skeleton")

	elif _timer >= 2.3 and _capture_step == 3:
		_capture_step = 4
		_capture_screenshot("c:/MathKnight/preview_skeleton_matrix.png")
		_set_archetype("slime")

	elif _timer >= 3.1 and _capture_step == 4:
		_capture_step = 5
		_capture_screenshot("c:/MathKnight/preview_slime_matrix.png")
		_set_archetype("boss")

	elif _timer >= 3.9 and _capture_step == 5:
		_capture_step = 6
		_capture_screenshot("c:/MathKnight/preview_boss_matrix.png")
		_set_archetype("knight")

	# Turntable rotation
	if _turntable_active:
		var rot_yaw = sin(_timer * 1.8) * 0.95
		if new_3d_entity:
			new_3d_entity.turntable_yaw = rot_yaw
		if legacy_entity:
			legacy_entity.rotation_yaw = rot_yaw


func _capture_screenshot(target_path: String) -> void:
	var vp = get_viewport()
	if not vp:
		return
	var img = vp.get_texture().get_image()
	if img:
		img.save_png(target_path)
		print("Saved screenshot to %s" % target_path)
