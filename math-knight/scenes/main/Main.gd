extends Node2D
## Main scene controller — coordinates all game systems through EventBus signals.

@onready var camera: Camera2D = $Camera2D
@onready var knight: Node2D = $BattleArea/Knight
@onready var enemy_queue: Node2D = $BattleArea/EnemyQueue
@onready var input_area: Control = $InputAreaContainer/InputArea
@onready var hud: CanvasLayer = $HUD
@onready var game_over_screen: CanvasLayer = $GameOverScreen

var _hit_effect_scene: PackedScene = preload("res://scenes/effects/HitEffect.tscn")
var _damage_number_scene: PackedScene = preload("res://scenes/effects/DamageNumber.tscn")
var _slash_arc_scene: PackedScene = preload("res://scenes/effects/SlashArc.tscn")
var _last_input_method: String = "swipe"
var _game_over_handled: bool = false


func _ready() -> void:
	EventBus.answer_selected.connect(_on_answer_selected)
	EventBus.answer_correct.connect(_on_answer_correct)
	EventBus.answer_wrong.connect(_on_answer_wrong)
	EventBus.enemy_defeated.connect(_on_enemy_defeated)
	EventBus.enemy_attacks_knight.connect(_on_enemy_attacks_knight)
	EventBus.knight_died.connect(_on_game_over)
	EventBus.game_won.connect(_on_game_won)
	EventBus.set_started.connect(_on_set_started)
	EventBus.set_cleared.connect(_on_set_cleared)
	EventBus.countdown_tick.connect(_on_countdown_tick)
	EventBus.score_changed.connect(_on_score_changed)

	if has_node("/root/RunManager"):
		var rm: Node = get_node("/root/RunManager")
		if rm.is_run_active and not rm.current_stage_data.is_empty():
			var cfg: MathConfig = rm.get_math_config_for_stage(rm.current_stage_data)
			if has_node("/root/MathEngine"):
				get_node("/root/MathEngine").set_difficulty(cfg)
			if knight:
				knight.max_hp = rm.knight_run_max_hp
				knight.current_hp = rm.knight_run_hp
				knight.attack_power = rm.knight_run_attack
				knight.armor = rm.knight_run_armor
				knight.dodge_chance = rm.knight_run_dodge

	GameManager.start_game()
	enemy_queue.initialize(knight.position.x)

	if has_node("/root/AudioManager"):
		var rm = get_node("/root/RunManager") if has_node("/root/RunManager") else null
		if rm and rm.is_run_active and rm.current_stage_data.get("type", "") == "boss":
			get_node("/root/AudioManager").play_music("boss")
		else:
			get_node("/root/AudioManager").play_adaptive_battle_music()


func _on_set_started(_set_num: int, bubble_pool: Array[int]) -> void:
	input_area.show_choices(bubble_pool)


func _on_countdown_tick(count_text: String) -> void:
	if count_text.begins_with("⚔️"):
		EventBus.screen_shake_requested.emit(0.25)


func _on_set_cleared(set_num: int) -> void:
	_spawn_damage_number(Vector2(320.0, 100.0), "★ WELLE " + str(set_num) + " GEMEISTERT! ★", Color(1.0, 0.85, 0.2))
	EventBus.screen_shake_requested.emit(0.4)


func _on_answer_selected(_value: int, method: String, _bubble: Area2D, _slice_dir: Vector2) -> void:
	_last_input_method = method


func _on_answer_correct(_problem: RefCounted, chain_count: int = 1) -> void:
	var front_enemy: Node2D = enemy_queue.get_front_enemy()
	var enemy_pos: Vector2 = front_enemy.global_position if (front_enemy and is_instance_valid(front_enemy)) else Vector2(480, 170)

	# Calculate RPG attack damage with speed, combo, and crit multipliers
	var answer_time: float = GameManager.last_answer_time_sec if ("last_answer_time_sec" in GameManager) else 2.0
	var combo_streak: int = GameManager.combo if ("combo" in GameManager) else 0
	var strike_data: Dictionary = knight.calculate_attack_strike(answer_time, combo_streak, chain_count)
	var final_damage: float = strike_data.get("damage", knight.attack_power * chain_count)
	var comic_tag: String = strike_data.get("tag", "POW!")
	var comic_archetype: String = strike_data.get("archetype", "attack")

	var on_hit_impact: Callable = func():
		if front_enemy and is_instance_valid(front_enemy):
			front_enemy.take_hit(final_damage)

		# Comic onomatopoeia popup burst ("POW!", "BLITZ!", "CLEAVE!", "KRRRANG!")
		JuiceManager.spawn_comic_popup(self, comic_tag, enemy_pos + Vector2(0, -35), comic_archetype)

		if chain_count >= 2:
			# Spawn X-Cut double slash arcs on impact
			_spawn_slash_arc(enemy_pos, -0.4, Color(0.3, 1.0, 1.0))
			_spawn_slash_arc(enemy_pos, 0.8, Color(1.0, 0.9, 0.3))
			_spawn_hit_effect(enemy_pos)
			_spawn_damage_number(enemy_pos + Vector2(0, -25), "⚡ " + str(int(final_damage)) + " ⚡", Color(0.2, 1.0, 1.0))
			JuiceManager.start_cinematic_slowmo(get_tree(), 0.35, 0.3)
			EventBus.screen_shake_requested.emit(0.65)
			if has_node("/root/AudioManager"):
				get_node("/root/AudioManager").play_sfx("sword_slash", 1.15, 2.0)
		else:
			# Snappy single slash impact
			_spawn_slash_arc(enemy_pos, -0.25, Color(0.3, 1.0, 1.0))
			_spawn_hit_effect(enemy_pos)
			_spawn_damage_number(enemy_pos, str(int(final_damage)), Color(1.0, 0.88, 0.2))
			# 4-frame (~66ms) hitstop impact freeze
			JuiceManager.hit_stop(get_tree(), 0.066, 0.04)
			var shake_impulse: float = 0.55 if strike_data.get("is_crit", false) else 0.38
			EventBus.screen_shake_requested.emit(shake_impulse)
			if has_node("/root/AudioManager"):
				get_node("/root/AudioManager").play_sfx("sword_slash", randf_range(1.0, 1.2), 1.0)

	if chain_count >= 2:
		# Multi-slash cross leap combo with slow-mo!
		knight.multi_slash_attack(enemy_pos.x, chain_count, on_hit_impact)
	else:
		# Fast rush attack to enemy with speed shadow trail!
		knight.rush_attack(enemy_pos.x, on_hit_impact)


func _on_answer_wrong(_problem: RefCounted) -> void:
	EventBus.screen_shake_requested.emit(0.38)
	knight.modulate = Color(2.5, 0.3, 0.3)
	var tween: Tween = create_tween()
	tween.tween_property(knight, "modulate", Color.WHITE, 0.35)
	_spawn_damage_number(knight.global_position + Vector2(0, -35), "-1 HP!", Color(1.0, 0.25, 0.25))


func _on_enemy_defeated(_enemy: Node2D) -> void:
	pass


func _on_enemy_attacks_knight(damage: float) -> void:
	if GameManager.state == GameManager.GameState.GAME_OVER or (knight and knight.state == "dead"):
		return

	knight.take_damage(damage)
	_spawn_damage_number(knight.global_position + Vector2(0, -40), str(int(damage)), Color(1.0, 0.2, 0.2))
	EventBus.screen_shake_requested.emit(0.3)

	if knight.current_hp <= 0:
		EventBus.knight_died.emit()


func _on_score_changed(_score: int) -> void:
	pass


func _on_game_over() -> void:
	if _game_over_handled:
		return
	_game_over_handled = true
	
	if GameManager.state != GameManager.GameState.GAME_OVER and GameManager.state != GameManager.GameState.VICTORY:
		GameManager.end_game()
	
	# Small delay so death animation / fall completes before showing end screen
	var timer: SceneTreeTimer = get_tree().create_timer(0.4)
	timer.timeout.connect(func():
		game_over_screen.show_game_over(GameManager.score)
	)


func _on_game_won(stats: Dictionary) -> void:
	_spawn_damage_number(Vector2(320.0, 90.0), "👑 SIEG! GLORREICHER SIEG! 👑", Color(0.3, 1.0, 0.85))
	EventBus.screen_shake_requested.emit(0.6)

	# Check if we're in a roguelike run
	if has_node("/root/RunManager") and get_node("/root/RunManager").is_run_active:
		var rm: Node = get_node("/root/RunManager")
		rm.pending_combat_result = false
		var is_final_boss: bool = (rm.current_stage_index >= RunManager.TOTAL_REGULAR_STAGES)

		# Save current knight hp back to run manager
		if knight:
			rm.knight_run_hp = maxf(1.0, knight.current_hp)

		rm.complete_current_stage()

		if is_final_boss:
			# Final boss defeated! Go to final chest opening & victory screen
			var timer: SceneTreeTimer = get_tree().create_timer(1.8)
			timer.timeout.connect(func():
				get_tree().change_scene_to_file("res://scenes/ui/ChestReward.tscn")
			)
		else:
			# Stage cleared -> Go to Merchant / Chest Hub
			var timer: SceneTreeTimer = get_tree().create_timer(1.5)
			timer.timeout.connect(func():
				get_tree().change_scene_to_file("res://scenes/stage/StageRewardHub.tscn")
			)
	else:
		game_over_screen.show_victory(stats)


func _spawn_slash_arc(pos: Vector2, rot: float = 0.0, col: Color = Color(0.3, 1.0, 1.0)) -> void:
	var arc: Node2D = _slash_arc_scene.instantiate() as Node2D
	add_child(arc)
	var sword_id: String = ""
	if has_node("/root/SaveManager"):
		sword_id = get_node("/root/SaveManager").equipped_cosmetics.get("sword", "sword_iron")
	if arc.has_method("setup"):
		arc.setup(pos, rot, col, sword_id)


func _spawn_hit_effect(pos: Vector2) -> void:
	var effect: CPUParticles2D = _hit_effect_scene.instantiate() as CPUParticles2D
	var sword_id: String = ""
	if has_node("/root/SaveManager"):
		sword_id = get_node("/root/SaveManager").equipped_cosmetics.get("sword", "sword_iron")
	if effect.has_method("setup"):
		effect.setup(sword_id)
	add_child(effect)
	effect.global_position = pos
	effect.emitting = true


func _spawn_damage_number(pos: Vector2, text: String, color: Color = Color.GOLD) -> void:
	var dmg_num: Node2D = _damage_number_scene.instantiate() as Node2D
	add_child(dmg_num)
	if dmg_num.has_method("setup"):
		dmg_num.setup(text, pos, color)
