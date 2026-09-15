class_name Ascii3DRenderer
extends Node2D
## Simplified compatibility wrapper rendering cartoon sprites.

signal slash_impact

enum RenderMode {
	SOFT_ASCII = 0,
	WIREFRAME = 1,
	OVERLAY = 2,
	SOLID_3D = 3,
	SHADER_MATRIX = 4
}

@export var render_mode: RenderMode = RenderMode.SOLID_3D
@export var facing_direction: float = 1.0:
	set(val):
		facing_direction = val
		if _entity: _entity.facing_direction = val

@export var turntable_yaw: float = 0.0:
	set(val):
		turntable_yaw = val
		if _entity: _entity.rotation_yaw = val

@export var turntable_pitch: float = 0.0
@export var rotation_yaw: float:
	get: return turntable_yaw
	set(val): turntable_yaw = val

@export var rotation_pitch: float:
	get: return turntable_pitch
	set(val): turntable_pitch = val

@export var entity_type: String = "knight":
	set(val):
		entity_type = val
		if _entity: _entity.entity_type = val

@export var is_elite: bool = false:
	set(val):
		is_elite = val
		if _entity: _entity.is_elite = val

var _entity: AsciiEntity = null


func _ready() -> void:
	if not _entity:
		_entity = AsciiEntity.new()
		_entity.name = "Entity"
		_entity.entity_type = entity_type
		_entity.facing_direction = facing_direction
		_entity.is_elite = is_elite
		add_child(_entity)


func play_idle() -> void:
	if _entity: _entity.play_idle()

func play_walk() -> void:
	if _entity: _entity.play_walk()

func play_attack() -> void:
	if _entity: _entity.play_attack()

func play_windup() -> void:
	if _entity: _entity.play_windup()

func play_slash() -> void:
	if _entity: _entity.play_slash()

func play_hurt() -> void:
	if _entity: _entity.play_hurt()

func play_splatter() -> void:
	if _entity: _entity.play_splatter()

func play_victory() -> void:
	if _entity: _entity.play_victory()

func trigger_victory_animation(anim: String = "") -> void:
	if _entity: _entity.trigger_victory_animation(anim)
