class_name AsciiEntity
extends Node2D
## ═══════════════════════════════════════════════════════════════════════════
## AsciiEntity — Clean Cartoon Character Renderer for Math Knight
##
## Replaces legacy procedural ASCII/3D stickmen with clean, hand-drawn
## cartoon sprites, smooth squash-and-stretch tweens, and combat juice.
## ═══════════════════════════════════════════════════════════════════════════

signal splatter_finished

# ---------------------------------------------------------------------------
#  EXPORTS & CONFIG
# ---------------------------------------------------------------------------
var renderer_3d = null # Compatibility stub for legacy scripts

@export_enum("knight", "goblin", "skeleton", "slime", "boss", "orc") var entity_type: String = "knight":
	set(val):
		entity_type = val
		if is_inside_tree():
			_update_entity_visuals()

@export var facing_direction: float = 1.0: # 1.0 = Facing Right, -1.0 = Facing Left
	set(val):
		facing_direction = val
		if is_inside_tree():
			_update_facing()

@export var rotation_yaw: float = 0.0:
	set(val):
		rotation_yaw = val
		# Slight tilt for pseudo-3D feel in wardrobe
		if _sprite_node:
			_sprite_node.rotation = sin(val) * 0.15

@export var rotation_pitch: float = 0.0
@export var equation_text: String = "":
	set(val):
		equation_text = val
		if is_inside_tree():
			_rebuild_equation()

@export var is_hovered: bool = false:
	set(val):
		is_hovered = val
		if is_inside_tree():
			_update_hover()

@export var is_focused: bool = true
@export var is_elite: bool = false:
	set(val):
		is_elite = val
		if is_inside_tree():
			_apply_elite_style()

# Cosmetic Equipment
@export var equipped_sword: String = "sword_iron":
	set(val):
		equipped_sword = val
		if is_inside_tree():
			_update_entity_visuals()

@export var equipped_helmet: String = "helm_knight":
	set(val):
		equipped_helmet = val
		if is_inside_tree():
			_update_entity_visuals()

@export var equipped_hat: String = "hat_none":
	set(val):
		equipped_hat = val
		if is_inside_tree():
			_update_entity_visuals()

@export var equipped_shield: String = "shield_knight"

# Internal nodes
var _sprite_node: AnimatedSprite2D = null
var _static_sprite: Sprite2D = null
var _equation_label: Label = null
var _equation_bg: NinePatchRect = null
var _idle_tween: Tween = null
var _is_animating: bool = false
var _cartoon_font: Font = null


func _ready() -> void:
	if ResourceLoader.exists("res://assets/fonts/LilitaOne-Regular.ttf"):
		_cartoon_font = load("res://assets/fonts/LilitaOne-Regular.ttf")
	elif ResourceLoader.exists("res://assets/fonts/Fredoka-Bold.ttf"):
		_cartoon_font = load("res://assets/fonts/Fredoka-Bold.ttf")
	else:
		_cartoon_font = ThemeDB.fallback_font

	_setup_nodes()
	_update_entity_visuals()
	_update_facing()
	_rebuild_equation()
	play_idle()


func _setup_nodes() -> void:
	if not _sprite_node:
		_sprite_node = AnimatedSprite2D.new()
		_sprite_node.name = "CharacterSprite"
		_sprite_node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		add_child(_sprite_node)

	if not _static_sprite:
		_static_sprite = Sprite2D.new()
		_static_sprite.name = "StaticSprite"
		_static_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		_static_sprite.visible = false
		add_child(_static_sprite)

	if not _equation_label:
		_equation_label = Label.new()
		_equation_label.name = "EquationBadge"
		_equation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_equation_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if _cartoon_font:
			_equation_label.add_theme_font_override("font", _cartoon_font)
		_equation_label.add_theme_font_size_override("font_size", 13)
		_equation_label.add_theme_color_override("font_color", Color("#ffffff"))
		_equation_label.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.15, 0.95))
		_equation_label.add_theme_constant_override("outline_size", 4)
		_equation_label.position = Vector2(-40, -65)
		_equation_label.size = Vector2(80, 24)
		add_child(_equation_label)


func _update_entity_visuals() -> void:
	if not _sprite_node or not is_inside_tree():
		return

	match entity_type:
		"knight":
			_static_sprite.visible = false
			_sprite_node.visible = true
			var sm = get_node_or_null("/root/SpriteManager")
			if sm:
				var equipped: Dictionary = {
					"sword": equipped_sword,
					"hat": equipped_hat,
					"helmet": equipped_helmet
				}
				var frames: SpriteFrames = sm.get_knight_sprite_frames_for_cosmetics(equipped)
				if frames:
					_sprite_node.sprite_frames = frames
					if not _sprite_node.is_playing() or _sprite_node.animation == "idle":
						_sprite_node.play("idle")
			_sprite_node.scale = Vector2(1.0, 1.0)
			_sprite_node.modulate = Color.WHITE

		"boss":
			_sprite_node.visible = false
			_static_sprite.visible = true
			var sm = get_node_or_null("/root/SpriteManager")
			if sm:
				_static_sprite.texture = sm.get_boss_texture()
			_static_sprite.scale = Vector2(1.0, 1.0)
			_static_sprite.position = Vector2(0, -10)
			_static_sprite.modulate = Color.WHITE

		"goblin", "skeleton", "slime", "orc", _:
			_sprite_node.visible = false
			_static_sprite.visible = true
			var sm = get_node_or_null("/root/SpriteManager")
			if sm:
				_static_sprite.texture = sm.get_enemy_texture()
			_static_sprite.scale = Vector2(0.9, 0.9)
			_static_sprite.position = Vector2(0, 0)
			
			# Visual variant tints for standard enemy types
			match entity_type:
				"slime":
					_static_sprite.modulate = Color(0.7, 1.3, 0.8) # Lime green
					_static_sprite.scale = Vector2(0.75, 0.65) # Squat
				"skeleton":
					_static_sprite.modulate = Color(0.9, 0.95, 1.1) # Pale bone
				"goblin":
					_static_sprite.modulate = Color(0.85, 1.15, 0.7) # Bright green goblin
				_:
					_static_sprite.modulate = Color.WHITE

	_apply_elite_style()
	_update_facing()


func _update_facing() -> void:
	var flip: bool = (facing_direction > 0.0)
	if _sprite_node:
		_sprite_node.flip_h = flip
	if _static_sprite:
		_static_sprite.flip_h = flip


func _update_hover() -> void:
	if is_hovered:
		modulate = Color(1.15, 1.15, 1.15)
	else:
		modulate = Color.WHITE


func _apply_elite_style() -> void:
	if is_elite and is_inside_tree():
		if entity_type == "boss":
			scale = Vector2(1.15, 1.15)
		else:
			scale = Vector2(1.25, 1.25)
		if _static_sprite and entity_type != "boss":
			_static_sprite.modulate = Color(1.3, 0.7, 0.7) # Fierce red elite aura


func apply_cosmetics(equipped: Dictionary) -> void:
	equipped_sword = equipped.get("sword", "sword_iron")
	equipped_helmet = equipped.get("helmet", "helm_knight")
	equipped_hat = equipped.get("hat", "hat_none")
	_update_entity_visuals()


func set_equation(eq_text: String, col: Color = Color.WHITE) -> void:
	equation_text = eq_text
	_rebuild_equation()
	if _equation_label:
		_equation_label.add_theme_color_override("font_color", col)


func _rebuild_equation() -> void:
	if not _equation_label:
		return
	_equation_label.text = equation_text
	_equation_label.visible = (equation_text != "")


# ---------------------------------------------------------------------------
#  ANIMATION API
# ---------------------------------------------------------------------------
func play_idle() -> void:
	if _sprite_node and _sprite_node.visible:
		_sprite_node.play("idle")

	# Gentle breathing bob
	if _idle_tween and _idle_tween.is_valid():
		_idle_tween.kill()
	_idle_tween = create_tween().set_loops()
	var target = _sprite_node if _sprite_node.visible else _static_sprite
	if target:
		_idle_tween.tween_property(target, "scale:y", target.scale.y * 1.04, 0.7) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_idle_tween.tween_property(target, "scale:y", target.scale.y * 0.98, 0.7) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func play_walk() -> void:
	# Bouncy walking trot
	var target = _sprite_node if _sprite_node.visible else _static_sprite
	if not target:
		return
	var tw := create_tween()
	tw.tween_property(target, "position:y", -6.0, 0.12).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(target, "position:y", 0.0, 0.12).set_trans(Tween.TRANS_QUAD)


func play_attack() -> void:
	if _sprite_node and _sprite_node.visible:
		_sprite_node.play("attack")
	else:
		# Punchy forward strike for static sprites
		var target = _static_sprite
		if target:
			var dir = 1.0 if facing_direction >= 0 else -1.0
			var tw := create_tween()
			tw.tween_property(target, "position:x", 16.0 * dir, 0.08)
			tw.tween_property(target, "position:x", 0.0, 0.14).set_trans(Tween.TRANS_BOUNCE)


func play_windup() -> void:
	if _sprite_node and _sprite_node.visible:
		_sprite_node.play("windup")
	else:
		var target = _static_sprite
		if target:
			var tw := create_tween()
			tw.tween_property(target, "scale", target.scale * Vector2(0.9, 1.15), 0.12)


func play_slash() -> void:
	if _sprite_node and _sprite_node.visible:
		_sprite_node.play("slash")
	else:
		var target = _static_sprite
		if target:
			var tw := create_tween()
			tw.tween_property(target, "scale", target.scale * Vector2(1.2, 0.8), 0.06)
			tw.tween_property(target, "scale", target.scale, 0.12)


func play_hurt() -> void:
	var target = _sprite_node if _sprite_node.visible else _static_sprite
	if target:
		var tw := create_tween()
		tw.tween_property(target, "modulate", Color(3.0, 2.0, 2.0), 0.06)
		tw.parallel().tween_property(target, "scale:x", target.scale.x * 0.85, 0.06)
		tw.tween_property(target, "modulate", Color.WHITE, 0.12)
		tw.parallel().tween_property(target, "scale:x", target.scale.x, 0.12)


func play_splatter() -> void:
	# Cartoon pop defeat animation
	if _idle_tween and _idle_tween.is_valid():
		_idle_tween.kill()

	var target = _sprite_node if _sprite_node.visible else _static_sprite
	if target:
		var tw := create_tween()
		tw.tween_property(target, "scale", target.scale * 1.3, 0.08)
		tw.tween_property(target, "scale", Vector2.ZERO, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(target, "modulate:a", 0.0, 0.18)
		tw.tween_callback(func():
			splatter_finished.emit()
		)
	else:
		splatter_finished.emit()


func play_victory() -> void:
	var target = _sprite_node if _sprite_node.visible else _static_sprite
	if target:
		var tw := create_tween()
		tw.tween_property(target, "position:y", -14.0, 0.15).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(target, "position:y", 0.0, 0.15).set_trans(Tween.TRANS_BOUNCE)


func trigger_victory_animation(_anim_name: String = "") -> void:
	play_victory()
