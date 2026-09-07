extends Node2D
class_name Knight
## The player's knight character. Stands on the right side, attacks enemies.
## Has HP, armor, dodge, and attack stats. Features juicy speed dash, afterimages/ghost shadows, and sword attack animations.

@export var max_hp: float = 10.0
@export var current_hp: float = 10.0
@export var attack_power: float = 1.0
@export var armor: float = 0.0
@export var dodge_chance: float = 0.0 # 0.0 to 1.0
@export var level: int = 1
@export var xp: int = 0

var state: String = "idle"
var _base_position: Vector2
var _idle_tween: Tween

@onready var hit_flash_timer: Timer = $HitFlashTimer
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var ascii_entity: AsciiEntity = $AsciiEntity


func _ready() -> void:
	# Load RPG stats from SaveManager & RunManager
	if has_node("/root/RunManager"):
		var rm = get_node("/root/RunManager")
		max_hp = rm.knight_run_max_hp
		current_hp = rm.knight_run_hp
		attack_power = rm.knight_run_attack
		armor = rm.knight_run_armor
		dodge_chance = rm.knight_run_dodge
	elif has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		max_hp = sm.get_max_hp()
		current_hp = max_hp
		attack_power = sm.get_attack_power()
		armor = sm.get_armor()
		dodge_chance = sm.get_dodge_chance()
	else:
		current_hp = max_hp

	_base_position = position
	if sprite:
		sprite.play("idle")
		sprite.animation_finished.connect(_on_animation_finished)

	_apply_cosmetics()
	_start_idle_bobbing()


func _apply_cosmetics() -> void:
	var equipped: Dictionary = {}
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		equipped = sm.equipped_cosmetics

	if ascii_entity:
		ascii_entity.apply_cosmetics(equipped)

	# Dynamically load weapon/cosmetic animation frames
	if has_node("/root/SpriteManager"):
		var sm_node = get_node("/root/SpriteManager")
		var frames: SpriteFrames = sm_node.get_knight_sprite_frames_for_cosmetics(equipped)
		if frames and sprite:
			sprite.sprite_frames = frames
			sprite.play("idle")

	# Subtle aura tint overlay
	var equipped_sword = equipped.get("sword", "")
	match equipped_sword:
		"sword_lightsaber":
			modulate = Color(1.0, 1.1, 1.2)
		"sword_flame":
			modulate = Color(1.15, 1.0, 0.95)
		"sword_frost":
			modulate = Color(0.95, 1.05, 1.2)
		"sword_gold":
			modulate = Color(1.15, 1.1, 0.95)
		_:
			modulate = Color.WHITE


func _start_idle_bobbing() -> void:
	if _idle_tween and _idle_tween.is_valid():
		_idle_tween.kill()
	_idle_tween = create_tween().set_loops()
	_idle_tween.tween_property(self, "position:y", _base_position.y - 2.0, 0.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_tween.tween_property(self, "position:y", _base_position.y + 2.0, 0.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


@export var crit_chance: float = 0.08 # 8% base crit chance


## Computes RPG attack damage based on base ATK, answer speed, combo streak, and critical rolls
func calculate_attack_strike(answer_time_sec: float, combo_streak: int, chain_count: int = 1) -> Dictionary:
	var base_dmg: float = attack_power
	
	# Speed multiplier: fast answers reward juicy bonus damage!
	var speed_mult: float = 1.0
	var speed_tier: String = "normal"
	if answer_time_sec > 0.0:
		if answer_time_sec <= 1.5:
			speed_mult = 1.75
			speed_tier = "blitz"
		elif answer_time_sec <= 3.0:
			speed_mult = 1.35
			speed_tier = "fast"
		elif answer_time_sec <= 6.0:
			speed_mult = 1.0
			speed_tier = "normal"
		else:
			speed_mult = 0.85
			speed_tier = "slow"
	
	# Combo bonus: +12% damage per combo streak point (max +120%)
	var combo_mult: float = 1.0 + minf(float(combo_streak) * 0.12, 1.2)
	
	# Chain count multiplier from multi-slice swipes
	var chain_mult: float = maxf(1.0, float(chain_count))
	
	# Critical hit check
	var is_crit: bool = (randf() < crit_chance) or (combo_streak >= 10 and randf() < 0.35)
	var crit_mult: float = 2.0 if is_crit else 1.0
	
	var total_damage: float = maxf(1.0, base_dmg * speed_mult * combo_mult * chain_mult * crit_mult)
	
	# Determine comic onomatopoeia banner tag
	var onomatopoeia: String = "POW!"
	var archetype: String = "attack"
	# Check for elemental weapon affix from SaveManager
	var affix: String = ""
	if has_node("/root/SaveManager"):
		affix = get_node("/root/SaveManager").weapon_affix

	if is_crit:
		onomatopoeia = "KRRRANG!"
		archetype = "crit"
	elif affix == "flame":
		onomatopoeia = "FLAME-STRIKE!"
		archetype = "cleave"
	elif affix == "frost":
		onomatopoeia = "FROST-CHILL!"
		archetype = "blitz"
	elif affix == "greed":
		onomatopoeia = "GREED-SLASH!"
		archetype = "attack"
	elif affix == "storm":
		onomatopoeia = "STORM-ZAP!"
		archetype = "crit"
	elif speed_tier == "blitz":
		onomatopoeia = "BLITZ!"
		archetype = "blitz"
	elif chain_count >= 2:
		onomatopoeia = "CLEAVE!"
		archetype = "cleave"
	elif combo_streak >= 5:
		onomatopoeia = "THWACK!"
		archetype = "cleave"
	else:
		onomatopoeia = ["POW!", "THWACK!", "WHAM!"][randi() % 3]
		archetype = "attack"
		
	return {
		"damage": total_damage,
		"is_crit": is_crit,
		"speed_tier": speed_tier,
		"speed_multiplier": speed_mult,
		"combo_multiplier": combo_mult,
		"chain_multiplier": chain_mult,
		"tag": onomatopoeia,
		"archetype": archetype,
		"affix": affix
	}


func take_damage(amount: float) -> void:
	if state == "dead":
		return
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if gm.state == gm.GameState.GAME_OVER:
			return

	# Agility Dodge Check: completely evades damage
	if randf() < dodge_chance:
		JuiceManager.spawn_comic_popup(get_parent(), "WHOOSH!", global_position + Vector2(0, -35), "whoosh")
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx("sword_slash", 1.8, 0.6)
		var dodge_tween: Tween = create_tween()
		dodge_tween.tween_property(self, "position:x", _base_position.x + 18.0, 0.1).set_trans(Tween.TRANS_BACK)
		dodge_tween.tween_property(self, "position:x", _base_position.x, 0.15).set_trans(Tween.TRANS_SINE)
		return

	# Armor Mitigation: reduces damage, minimum 1.0
	var actual_damage: float = maxf(1.0, amount - armor)
	current_hp -= actual_damage

	# Hit flash & feedback
	modulate = Color(3.0, 3.0, 3.0)
	hit_flash_timer.start()

	JuiceManager.spawn_comic_popup(get_parent(), "OUCH!", global_position + Vector2(0, -30), "defeat")
	if has_node("/root/EventBus"):
		var eb = get_node("/root/EventBus")
		eb.knight_damaged.emit(current_hp, max_hp)
		eb.screen_shake_requested.emit(0.4)

	if current_hp <= 0.0:
		current_hp = 0.0
		_honorable_retreat()
	else:
		state = "hurt"


func _honorable_retreat() -> void:
	state = "dead"
	if _idle_tween and _idle_tween.is_valid():
		_idle_tween.kill()
	
	# Gentle respectful retreat: kneel down slightly and fade out
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "position:y", _base_position.y + 12.0, 0.45) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation_degrees", 8.0, 0.45)
	tween.tween_property(self, "modulate:a", 0.4, 0.6)
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").knight_died.emit()


func _on_hit_flash_timer_timeout() -> void:
	modulate = Color.WHITE
	if state == "hurt":
		state = "idle"


## Spawns a transient translucent speed shadow / afterimage
func spawn_ghost_shadow(tint: Color = Color(0.3, 0.75, 1.0, 0.65)) -> void:
	if not sprite or not is_inside_tree():
		return

	var ghost: Sprite2D = Sprite2D.new()
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var frames: SpriteFrames = sprite.sprite_frames
	if frames and frames.has_animation(sprite.animation):
		ghost.texture = frames.get_frame_texture(sprite.animation, sprite.frame)
	
	ghost.global_position = sprite.global_position
	ghost.scale = global_scale * sprite.scale
	ghost.rotation = global_rotation + sprite.rotation
	ghost.offset = sprite.offset
	ghost.modulate = tint
	ghost.z_index = z_index - 1
	get_parent().add_child(ghost)

	var tween: Tween = ghost.create_tween().set_parallel(true)
	tween.tween_property(ghost, "modulate:a", 0.0, 0.22) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(ghost, "scale", ghost.scale * 1.08, 0.22) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(ghost.queue_free)


func _get_weapon_ghost_color() -> Color:
	var equipped_sword: String = "sword_iron"
	if has_node("/root/SaveManager"):
		equipped_sword = get_node("/root/SaveManager").equipped_cosmetics.get("sword", "sword_iron")
	match equipped_sword:
		"sword_flame": return Color(1.0, 0.45, 0.1, 0.85)
		"sword_frost": return Color(0.2, 0.85, 1.0, 0.85)
		"sword_lightsaber": return Color(0.0, 1.0, 0.8, 0.9)
		"sword_gold": return Color(1.0, 0.85, 0.2, 0.9)
		"sword_pan": return Color(1.0, 0.8, 0.4, 0.75)
		_: return Color(0.2, 0.85, 1.0, 0.75)


func _create_ghost_trail(duration: float, tint: Color, count: int = 5) -> void:
	for i in range(count):
		var delay: float = (duration / float(max(1, count))) * float(i)
		get_tree().create_timer(delay).timeout.connect(func():
			if is_instance_valid(self) and state != "dead":
				spawn_ghost_shadow(tint)
		)
## Fast rush forward to the enemy, lightning slash attack on impact, then dash back
func rush_attack(target_enemy_x: float, on_impact: Callable = Callable()) -> void:
	if state == "dead":
		return
	state = "rush_attack"

	if _idle_tween and _idle_tween.is_valid():
		_idle_tween.kill()

	# 1. Windup stance while rushing forward
	if ascii_entity:
		ascii_entity.play_windup()
	if sprite:
		sprite.play("windup")

	var rush_dest_x: float = maxf(180.0, target_enemy_x + 36.0)
	var rush_duration: float = 0.11
	var impact_duration: float = 0.13
	var return_duration: float = 0.14

	# Spawn weapon-themed speed shadows during dash forward
	var weapon_tint = _get_weapon_ghost_color()
	_create_ghost_trail(rush_duration, weapon_tint, 6)

	var tween: Tween = create_tween()
	# Dash forward with stretch
	tween.tween_property(self, "position:x", rush_dest_x, rush_duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "scale", Vector2(1.22, 0.88), rush_duration * 0.6)
	tween.parallel().tween_property(self, "scale", Vector2.ONE, rush_duration * 0.4)

	# 2. At enemy: unleash the lightning slash swing & trigger impact callback!
	tween.tween_callback(func():
		if ascii_entity and state != "dead":
			ascii_entity.play_slash()
		if sprite and state != "dead":
			sprite.play("slash")
		if on_impact.is_valid():
			on_impact.call()
		
		# Juice: punchy squash on strike impact
		var hit_tween = create_tween()
		hit_tween.tween_property(self, "scale", Vector2(1.28, 0.78), 0.04)
		hit_tween.tween_property(self, "scale", Vector2.ONE, 0.09)
	)
	tween.tween_interval(impact_duration)

	# 3. Dash back to base position with trailing shadows
	tween.tween_callback(func():
		_create_ghost_trail(return_duration, Color(weapon_tint.r * 0.8, weapon_tint.g * 0.8, weapon_tint.b * 0.8, 0.5), 4)
	)
	tween.tween_property(self, "position", _base_position, return_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "scale", Vector2(0.9, 1.1), return_duration * 0.4)
	tween.parallel().tween_property(self, "scale", Vector2.ONE, return_duration * 0.6)

	tween.tween_callback(_on_attack_finished)


## Cinematic combo multi-slash with high leap arc, gold aura, and double afterimages
func multi_slash_attack(target_enemy_x: float, _chain_count: int, on_impact: Callable = Callable()) -> void:
	if state == "dead":
		return
	state = "slash_attack"

	if _idle_tween and _idle_tween.is_valid():
		_idle_tween.kill()

	# 1. Windup high during leap
	if ascii_entity:
		ascii_entity.play_windup()
	if sprite:
		sprite.play("windup")

	# Glow golden aura
	modulate = Color(2.5, 2.0, 0.6)
	var leap_x: float = maxf(180.0, target_enemy_x + 28.0)
	var leap_duration: float = 0.14
	var strike_duration: float = 0.16
	var return_duration: float = 0.14

	var weapon_tint = _get_weapon_ghost_color()
	_create_ghost_trail(leap_duration, weapon_tint, 7)

	var tween: Tween = create_tween()
	# 1. Cinematic leap arc into the enemy position
	tween.tween_property(self, "position", Vector2(leap_x, _base_position.y - 28.0), leap_duration * 0.6) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", Vector2(leap_x, _base_position.y), leap_duration * 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "scale", Vector2(1.25, 0.8), 0.08)

	# 2. Strike down with heavy slash & trigger impact
	tween.tween_callback(func():
		if ascii_entity and state != "dead":
			ascii_entity.play_slash()
		if sprite and state != "dead":
			sprite.play("slash")
		if on_impact.is_valid():
			on_impact.call()
		
		var hit_tween = create_tween()
		hit_tween.tween_property(self, "scale", Vector2(1.35, 0.72), 0.04)
		hit_tween.tween_property(self, "scale", Vector2.ONE, 0.10)
	)
	tween.tween_interval(strike_duration)
	tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.08)

	# 3. Quick dash back to base position
	tween.tween_callback(func():
		_create_ghost_trail(return_duration, Color(1.0, 0.7, 0.2, 0.5), 5)
	)
	tween.tween_property(self, "position", _base_position, return_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate", Color.WHITE, return_duration)
	tween.parallel().tween_property(self, "scale", Vector2.ONE, return_duration)

	tween.tween_callback(_on_attack_finished)


func slash_attack() -> void:
	rush_attack(_base_position.x - 100.0)


func stab_attack() -> void:
	rush_attack(_base_position.x - 100.0)


func _on_animation_finished() -> void:
	if state != "dead" and sprite and (sprite.animation == "slash" or sprite.animation == "attack" or sprite.animation == "windup"):
		if state == "idle":
			sprite.play("idle")


func _on_attack_finished() -> void:
	if state != "dead":
		state = "idle"
		position = _base_position
		scale = Vector2.ONE
		modulate = Color.WHITE
		if sprite and sprite.animation != "idle" and (not sprite.is_playing() or sprite.animation == "slash"):
			sprite.play("idle")
		_start_idle_bobbing()
