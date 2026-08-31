extends Node2D
class_name EnemyQueue
## Manages enemy sets, countdown preview, and queue behavior.
## Enemies gather tightly on the LEFT side of the battlefield.
## A 3-second countdown preview allows players to view the field and bubbles before enemies charge.

@export var set_size: int = 5
@export var bubble_pool_size: int = 10
@export var enemy_scene: PackedScene = preload("res://scenes/enemy/Enemy.tscn")
@export var knight_x: float = 540.0
@export var queue_slot_spacing: float = 36.0
@export var front_slot_x: float = 200.0

var current_set_number: int = 1
## Active enemies in current set, ordered from rightmost (index 0) to leftmost (index N-1)
var enemies_in_set: Array[Enemy] = []
var _is_in_countdown: bool = false

@onready var enemies_container: Node2D = $Enemies


var current_total_waves: int = 3

func _ready() -> void:
	EventBus.knight_died.connect(_on_knight_died)


func _on_knight_died() -> void:
	_is_in_countdown = false
	for enemy in enemies_in_set:
		if is_instance_valid(enemy):
			if enemy.attack_timer:
				enemy.attack_timer.stop()
			enemy.state = "idle"


func initialize(knight_position_x: float) -> void:
	knight_x = knight_position_x
	current_set_number = 1
	start_new_set()


func start_new_set() -> void:
	_is_in_countdown = true

	for enemy in enemies_in_set:
		if is_instance_valid(enemy):
			enemy.queue_free()
	enemies_in_set.clear()

	# Determine configuration from RunManager or fallback to stage progression
	var active_set_size: int = 4
	var active_pool_size: int = 12
	var stage_cfg: Dictionary = GameManager.get_stage_config(current_set_number)
	var total_waves: int = 3
	var is_elite_wave: bool = false
	var is_elite_node: bool = false

	if has_node("/root/RunManager"):
		var rm = get_node("/root/RunManager")
		if rm.is_run_active and not rm.get_current_node().is_empty():
			var node_data: Dictionary = rm.get_current_node()
			var is_boss_node: bool = (node_data.get("type", "") == "boss")
			is_elite_node = (node_data.get("type", "") == "elite")
			
			if is_boss_node:
				total_waves = 1
				is_elite_wave = true
				active_set_size = node_data.get("enemy_count", 5)
				if active_set_size <= 0:
					active_set_size = 5
			else:
				# 3-5 waves per level based on tier and node type
				total_waves = 4 if is_elite_node else 3
				if node_data.get("tier", 0) >= 2:
					total_waves = 5 if is_elite_node else 4

				# Elite wave triggers on final wave (or wave 2+ in elite nodes)
				if is_elite_node and current_set_number >= 2:
					is_elite_wave = true
				elif current_set_number == total_waves:
					is_elite_wave = true

				active_set_size = node_data.get("enemy_count", 4)
				if active_set_size <= 0:
					active_set_size = 4

			active_pool_size = max(active_set_size + 4, 12)

			# Use node's difficulty for speed/damage
			match node_data.get("math_difficulty", 0):
				0:  # EASY
					stage_cfg = {"enemies": active_set_size, "pool": active_pool_size, "speed": 38.0, "damage": 1.0, "interval": 2.1}
				1:  # MEDIUM
					stage_cfg = {"enemies": active_set_size, "pool": active_pool_size, "speed": 48.0, "damage": 1.2, "interval": 1.8}
				2:  # HARD
					stage_cfg = {"enemies": active_set_size, "pool": active_pool_size, "speed": 58.0, "damage": 1.5, "interval": 1.5}
	else:
		active_set_size = stage_cfg.enemies
		active_pool_size = stage_cfg.pool
		total_waves = GameManager.TOTAL_STAGES

	current_total_waves = total_waves
	GameManager.current_stage = current_set_number
	EventBus.stage_changed.emit(current_set_number, current_total_waves)

	# 2. Generate math problems and bubble pool for the entire set
	# If Elite wave, we need extra problems for the Elite enemy (2-3 tasks)
	var extra_problems_count: int = 2 if is_elite_wave else 0
	var total_problems_to_gen: int = active_set_size + extra_problems_count
	var set_data: Dictionary = MathEngine.generate_set(total_problems_to_gen, active_pool_size + extra_problems_count)
	var problems: Array = set_data.problems
	var bubble_pool: Array = set_data.bubble_pool

	# 3. Tell InputArea to show the new bubble pool immediately for the player to preview
	var int_pool: Array[int] = []
	for val in bubble_pool:
		int_pool.append(int(val))
	EventBus.set_started.emit(current_set_number, int_pool)

	# 4. Spawn enemies in formation on the LEFT
	var prob_idx: int = 0
	for i in range(active_set_size):
		var enemy: Enemy = enemy_scene.instantiate() as Enemy
		enemies_container.add_child(enemy)

		var enemy_spd: float = randf_range(stage_cfg.speed * 0.95, stage_cfg.speed * 1.05)

		var available_types: Array[String] = ["goblin", "skeleton", "slime"]
		var chosen_type: String = available_types[i % available_types.size()]

		# Spawn Elite enemy if this is an elite wave and it's the front or middle enemy
		if is_elite_wave and i == 0:
			# Elite enemy gets 2-3 math problems to defeat!
			var elite_tasks_count: int = 3 if is_elite_node else 2
			var elite_probs: Array[MathProblem] = []
			for p in range(elite_tasks_count):
				if prob_idx < problems.size():
					elite_probs.append(problems[prob_idx] as MathProblem)
					prob_idx += 1
				else:
					elite_probs.append(MathEngine.generate_problem())
			enemy.setup_elite(elite_probs, enemy_spd * 0.85, stage_cfg.damage * 1.4, stage_cfg.interval * 0.9, chosen_type)
		else:
			var prob: MathProblem = problems[prob_idx] as MathProblem if prob_idx < problems.size() else MathEngine.generate_problem()
			prob_idx += 1
			enemy.setup(prob, enemy_spd, stage_cfg.damage, stage_cfg.interval, chosen_type)

		enemy.target_x = knight_x - 50.0
		enemy.enemy_defeated.connect(_on_enemy_defeated)
		enemy.enemy_reached_knight.connect(_on_enemy_reached_knight)

		var slot_x: float = front_slot_x - (float(i) * queue_slot_spacing)
		enemy.position = Vector2(slot_x, 0.0)

		enemies_in_set.append(enemy)

	# 5. Set active problem for the front enemy
	update_active_problem()

	# 6. Start 3-second preview countdown
	_run_countdown_sequence()


func _run_countdown_sequence() -> void:
	EventBus.countdown_tick.emit("3")
	
	var t1: SceneTreeTimer = get_tree().create_timer(1.0)
	t1.timeout.connect(func():
		EventBus.countdown_tick.emit("2")
		var t2: SceneTreeTimer = get_tree().create_timer(1.0)
		t2.timeout.connect(func():
			EventBus.countdown_tick.emit("1")
			var t3: SceneTreeTimer = get_tree().create_timer(1.0)
			t3.timeout.connect(func():
				_is_in_countdown = false
				EventBus.countdown_tick.emit("⚔️ LOS!")
				# Activate the front enemy after countdown!
				if not enemies_in_set.is_empty():
					enemies_in_set[0].activate()
			)
		)
	)


func get_front_enemy() -> Enemy:
	if enemies_in_set.is_empty():
		return null
	var front: Enemy = enemies_in_set[0]
	if is_instance_valid(front) and front.state != "defeated":
		return front
	return null


func update_active_problem() -> void:
	var front: Enemy = get_front_enemy()
	if front and is_instance_valid(front) and front.problem:
		GameManager.current_problem = front.problem
		EventBus.problem_presented.emit(front.problem)
	_update_queue_focus()


func _update_queue_focus() -> void:
	for i in range(enemies_in_set.size()):
		var enemy: Enemy = enemies_in_set[i]
		if is_instance_valid(enemy) and enemy.has_method("set_focus"):
			enemy.set_focus(i == 0)


func _on_enemy_defeated(enemy: Node2D) -> void:
	enemies_in_set.erase(enemy)
	EventBus.enemy_defeated.emit(enemy)

	if enemies_in_set.is_empty():
		EventBus.set_cleared.emit(current_set_number)
		if current_set_number >= current_total_waves:
			# VICTORY ACHIEVED! Node or Run cleared!
			var timer: SceneTreeTimer = get_tree().create_timer(0.8)
			timer.timeout.connect(func(): GameManager.trigger_victory())
		else:
			current_set_number += 1
			var timer: SceneTreeTimer = get_tree().create_timer(1.0)
			timer.timeout.connect(start_new_set)
	else:
		_advance_queue()
		if not enemies_in_set.is_empty() and not _is_in_countdown:
			enemies_in_set[0].activate()
		update_active_problem()


func _on_enemy_reached_knight(_enemy: Node2D) -> void:
	EventBus.enemy_reached_knight.emit(_enemy)


func _advance_queue() -> void:
	for i in range(enemies_in_set.size()):
		var enemy: Enemy = enemies_in_set[i]
		if not is_instance_valid(enemy):
			continue
		if enemy.state == "queued":
			var target_slot_x: float = front_slot_x - (float(i) * queue_slot_spacing)
			var tween: Tween = create_tween()
			tween.tween_property(enemy, "position:x", target_slot_x, 0.28) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_update_queue_focus()
