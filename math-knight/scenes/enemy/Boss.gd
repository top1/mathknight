class_name BossEnemy
extends Node2D

signal boss_phase_cleared(phase: int)
signal boss_fully_defeated()

@export var boss_name: String = "Mathe-König"
@export var total_phases: int = 3
@export var current_phase: int = 1
@export var phase_hp: float = 100.0
@export var speed: float = 50.0
@export var attack_damage: float = 10.0
@export var attack_interval: float = 2.5

@onready var sprite: Sprite2D = $Sprite
@onready var boss_label: Label = $BossLabel
@onready var attack_timer: Timer = $AttackTimer
@onready var ascii_entity: AsciiEntity = $AsciiEntity

var current_hp: float = 0.0
var max_phase_hp: float = 0.0
var time_elapsed: float = 0.0
var original_scale: Vector2
var original_pos: Vector2

var is_enraged: bool = false
var enrage_timer: Timer

func _ready() -> void:
	if ascii_entity:
		ascii_entity.entity_type = "boss"
		ascii_entity.facing_direction = 1.0
	if has_node("/root/SpriteManager"):
		var b_tex = get_node("/root/SpriteManager").get_boss_texture()
		if b_tex and sprite:
			sprite.texture = b_tex
	original_scale = sprite.scale
	original_pos = position
	queue_redraw()
	
func setup(b_name: String, phases: int, hp_per_phase: float, spd: float, dmg: float, interval: float) -> void:
	boss_name = b_name
	total_phases = phases
	current_phase = 1
	max_phase_hp = hp_per_phase
	current_hp = max_phase_hp
	speed = spd
	attack_damage = dmg
	attack_interval = interval
	
	position = Vector2(200, 0)
	
	if total_phases >= 5:
		sprite.modulate = Color(1.0, 0.8, 0.2) # Gold + red tint for final boss
	else:
		sprite.modulate = Color(1.0, 0.5, 0.5) # Red tint for mini-boss
	
	if attack_timer:
		attack_timer.wait_time = attack_interval
		attack_timer.start()

func take_hit(damage: float) -> void:
	current_hp -= damage
	if ascii_entity:
		ascii_entity.play_hurt()
	
	if current_hp <= 0:
		advance_phase()
	else:
		# Hit effect
		var tween = create_tween()
		var orig_color = sprite.modulate
		sprite.modulate = Color(1, 0, 0, 1)
		tween.tween_property(sprite, "modulate", orig_color, 0.2)

func advance_phase() -> void:
	emit_signal("boss_phase_cleared", current_phase)
	if EventBus.has_user_signal("boss_phase_changed"):
		EventBus.emit_signal("boss_phase_changed", current_phase)
		
	if current_phase >= total_phases:
		die()
		return
		
	current_phase += 1
	current_hp = max_phase_hp
	
	# Increase stats
	speed *= 1.2
	attack_damage *= 1.2
	
	# Flash and shake
	var tween = create_tween()
	var orig_color = sprite.modulate
	tween.tween_property(sprite, "modulate", Color(2, 2, 2, 1), 0.1)
	tween.tween_property(sprite, "modulate", orig_color, 0.1)
	tween.tween_property(sprite, "scale", original_scale * 1.2, 0.1)
	tween.tween_property(sprite, "scale", original_scale, 0.1)

func die() -> void:
	if attack_timer:
		attack_timer.stop()
	boss_fully_defeated.emit()

	if ascii_entity:
		ascii_entity.trigger_splatter()
		var timer = get_tree().create_timer(1.5)
		timer.timeout.connect(queue_free)
	else:
		var tween = create_tween().set_parallel(true)
		tween.tween_property(self, "rotation", PI * 4, 1.0)
		tween.tween_property(self, "scale", Vector2.ZERO, 1.0)
		tween.tween_property(self, "modulate:a", 0.0, 1.0)
		tween.chain().tween_callback(queue_free)

func start_enrage_timer(seconds: float) -> void:
	enrage_timer = Timer.new()
	enrage_timer.wait_time = seconds
	enrage_timer.one_shot = true
	enrage_timer.timeout.connect(_on_enrage_timeout)
	add_child(enrage_timer)
	enrage_timer.start()

func _on_enrage_timeout() -> void:
	is_enraged = true
	speed *= 2.0
	attack_damage *= 2.0
	sprite.modulate = Color(1.0, 0.3, 0.3, 1.0) # More red
	if EventBus.has_user_signal("boss_enraged"):
		EventBus.emit_signal("boss_enraged")

func _on_attack_timer_timeout() -> void:
	if EventBus.has_user_signal("enemy_attacks_knight"):
		EventBus.emit_signal("enemy_attacks_knight", attack_damage)
		
	# Lunge animation
	var tween = create_tween()
	tween.tween_property(sprite, "position", Vector2(-20, 0), 0.1)
	tween.tween_property(sprite, "position", Vector2(0, 0), 0.2)

func _process(delta: float) -> void:
	time_elapsed += delta
	# Slow breathing scale pulse + floating
	sprite.scale = original_scale + Vector2(sin(time_elapsed * 2.0) * 0.05, cos(time_elapsed * 2.0) * 0.05)
	sprite.position.y = sin(time_elapsed * 1.5) * 5.0
	queue_redraw()

func _draw() -> void:
	# A procedural crown/helmet drawn above the sprite
	var crown_offset = Vector2(0, -60) + sprite.position
	var crown_points = PackedVector2Array([
		crown_offset + Vector2(-15, 0), 
		crown_offset + Vector2(-10, -15), 
		crown_offset + Vector2(-5, -5),
		crown_offset + Vector2(0, -20), 
		crown_offset + Vector2(5, -5), 
		crown_offset + Vector2(10, -15), 
		crown_offset + Vector2(15, 0)
	])
	var crown_color = Color(1.0, 0.84, 0.0) # Gold
	var colors = PackedColorArray()
	for i in range(crown_points.size()):
		colors.append(crown_color)
		
	draw_polygon(crown_points, colors)
	
	var poly_pts = PackedVector2Array()
	for pt in crown_points:
		poly_pts.append(pt)
	poly_pts.append(crown_points[0]) # Close the loop
	
	draw_polyline(poly_pts, Color(0, 0, 0, 1), 2.0)
