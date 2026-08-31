extends Node
## RunManager singleton — manages the active roguelike run state.
## Tracks gold, chests, artifacts, map structure, and current position.

# === Run State ===
var is_run_active: bool = false
var run_gold: int = 0
var run_chests: Array[Dictionary] = []  # Collected chests to open after run
var run_artifacts: Array[Dictionary] = []  # Active artifacts for this run
var run_score: int = 0
var run_sets_flawless: int = 0

# === Map State ===
var run_map: Array = []  # Array of tiers, each tier is Array of node Dictionaries
var current_tier: int = -1
var current_node_id: int = -1
var completed_node_ids: Array[int] = []
var available_node_ids: Array[int] = []
var pending_combat_result: bool = false  # True when returning from combat

# === Knight Run Stats (base + artifacts) ===
var knight_run_max_hp: float = 10.0
var knight_run_hp: float = 10.0
var knight_run_attack: float = 1.0
var knight_run_armor: float = 0.0
var knight_run_dodge: float = 0.0

# === Node ID counter ===
var _next_node_id: int = 0


func _ready() -> void:
	EventBus.gold_earned.connect(_on_gold_earned)
	EventBus.chest_collected.connect(_on_chest_collected)
	EventBus.flawless_set_achieved.connect(_on_flawless_set)


# === Run Lifecycle ===

func start_new_run() -> void:
	is_run_active = true
	run_gold = 0
	run_chests.clear()
	run_artifacts.clear()
	run_score = 0
	run_sets_flawless = 0
	current_tier = -1
	current_node_id = -1
	completed_node_ids.clear()
	available_node_ids.clear()
	pending_combat_result = false
	_next_node_id = 0

	# Initialize knight run stats from SaveManager
	if has_node("/root/SaveManager"):
		var sm: Node = get_node("/root/SaveManager")
		knight_run_max_hp = sm.get_max_hp()
		knight_run_hp = knight_run_max_hp
		knight_run_attack = sm.get_attack_power()
		knight_run_armor = sm.get_armor()
		knight_run_dodge = sm.get_dodge_chance()
	else:
		knight_run_max_hp = 10.0
		knight_run_hp = 10.0
		knight_run_attack = 1.0
		knight_run_armor = 0.0
		knight_run_dodge = 0.0

	# Generate the map
	generate_map()

	# Make tier 1 nodes available
	if run_map.size() > 0:
		for node_data in run_map[0]:
			available_node_ids.append(node_data.id)

	if has_node("/root/SaveManager"):
		get_node("/root/SaveManager").total_runs_started += 1

	EventBus.run_started.emit()


func end_run(is_victory: bool) -> Dictionary:
	is_run_active = false

	var stats: Dictionary = {
		"is_victory": is_victory,
		"score": run_score,
		"gold": run_gold,
		"chests": run_chests.duplicate(),
		"flawless_sets": run_sets_flawless,
		"nodes_completed": completed_node_ids.size(),
		"tier_reached": current_tier + 1,
		"artifacts_used": run_artifacts.size()
	}

	# Award diamonds for run completion
	var diamond_reward: int = 0
	if is_victory:
		diamond_reward = randi_range(3, 5)
	elif current_tier >= 2:
		diamond_reward = 1  # At least got to tier 3

	if diamond_reward > 0 and has_node("/root/SaveManager"):
		get_node("/root/SaveManager").add_diamonds(diamond_reward)
	stats["diamonds_earned"] = diamond_reward

	# Add XP
	var xp_reward: int = 10 * completed_node_ids.size()
	if is_victory:
		xp_reward += 50
	if has_node("/root/SaveManager"):
		var sm: Node = get_node("/root/SaveManager")
		sm.add_xp(xp_reward)
		sm.total_gold_earned += run_gold
		if is_victory:
			sm.total_runs_completed += 1
		sm.add_highscore(stats)
	stats["xp_earned"] = xp_reward

	EventBus.run_ended.emit(stats)
	return stats


# === Map Generation ===

func generate_map() -> void:
	run_map.clear()
	_next_node_id = 0

	# Tier 1 (Akt 1: Goblin-Auen): 3 nodes (combat, combat, elite)
	var tier_1: Array[Dictionary] = []
	tier_1.append(_create_node("combat", 0, MathConfig.Difficulty.EASY))
	tier_1.append(_create_node("combat", 0, MathConfig.Difficulty.EASY))
	tier_1.append(_create_node("elite", 0, MathConfig.Difficulty.MEDIUM))
	_shuffle_tier_positions(tier_1)
	run_map.append(tier_1)

	# Tier 2 (Akt 2: Schattenwald): 3 nodes (mini-boss, combat, rest/elite)
	var tier_2: Array[Dictionary] = []
	tier_2.append(_create_node("boss", 1, MathConfig.Difficulty.MEDIUM, true))  # Mini-Boss
	tier_2.append(_create_node("combat", 1, MathConfig.Difficulty.MEDIUM))
	if randf() < 0.5:
		tier_2.append(_create_node("elite", 1, MathConfig.Difficulty.MEDIUM))
	else:
		tier_2.append(_create_node("rest", 1, MathConfig.Difficulty.EASY))
	_shuffle_tier_positions(tier_2)
	run_map.append(tier_2)

	# Tier 3 (Akt 3: Drachenzacken): 3 nodes (combat, elite, rest)
	var tier_3: Array[Dictionary] = []
	tier_3.append(_create_node("combat", 2, MathConfig.Difficulty.HARD))
	tier_3.append(_create_node("elite", 2, MathConfig.Difficulty.HARD))
	tier_3.append(_create_node("rest", 2, MathConfig.Difficulty.EASY))
	_shuffle_tier_positions(tier_3)
	run_map.append(tier_3)

	# Tier 4 (Akt 4: Titanenfeste): 1 node (FINAL BOSS)
	var tier_4: Array[Dictionary] = []
	tier_4.append(_create_node("boss", 3, MathConfig.Difficulty.HARD, false))  # Final Boss
	run_map.append(tier_4)

	# Generate connections between tiers
	_generate_connections()

	EventBus.map_generated.emit(run_map)


func _create_node(type: String, tier: int, difficulty: MathConfig.Difficulty, is_mini_boss: bool = false) -> Dictionary:
	var id: int = _next_node_id
	_next_node_id += 1

	# Determine math mode & operation by tier:
	# Tier 0 (Section 1): Addition & Subtraction only, TASK_TO_RESULT only
	# Tier 1 (Section 2): Addition & Subtraction, TASK_TO_RESULT or simple RESULT_TO_EQUATION
	# Tier 2 (Section 3): Addition, Subtraction, Multiplication (+, -, ×)
	# Tier 3 (Section 4 / Boss): Multiplication, Division, Mixed (+, -, ×, ÷)
	var math_mode: int = MathConfig.GameMode.TASK_TO_RESULT
	var math_op: int = MathConfig.Operation.ADDITION

	match tier:
		0:
			# Section 1: 75% Addition, 25% Subtraction. Only simple task-to-result.
			math_op = MathConfig.Operation.ADDITION if randf() < 0.75 else MathConfig.Operation.SUBTRACTION
			math_mode = MathConfig.GameMode.TASK_TO_RESULT
		1:
			# Section 2: Addition (50%) or Subtraction (50%). 80% TASK_TO_RESULT, 20% RESULT_TO_EQUATION
			math_op = MathConfig.Operation.ADDITION if randf() < 0.5 else MathConfig.Operation.SUBTRACTION
			math_mode = MathConfig.GameMode.TASK_TO_RESULT if randf() < 0.8 else MathConfig.GameMode.RESULT_TO_EQUATION
		2:
			# Section 3: Addition, Subtraction, or Multiplication
			var ops: Array = [
				MathConfig.Operation.ADDITION,
				MathConfig.Operation.SUBTRACTION,
				MathConfig.Operation.MULTIPLICATION
			]
			math_op = ops.pick_random()
			var modes: Array = [
				MathConfig.GameMode.TASK_TO_RESULT,
				MathConfig.GameMode.RESULT_TO_EQUATION,
				MathConfig.GameMode.MULTI_OP_EQUATION
			]
			math_mode = modes.pick_random()
		_:
			# Section 4 / Boss: Multiplication, Division, or Mixed
			var ops: Array = [
				MathConfig.Operation.MULTIPLICATION,
				MathConfig.Operation.DIVISION,
				MathConfig.Operation.MIXED
			]
			math_op = ops.pick_random()
			var modes: Array = [
				MathConfig.GameMode.TASK_TO_RESULT,
				MathConfig.GameMode.RESULT_TO_EQUATION,
				MathConfig.GameMode.MULTI_OP_EQUATION
			]
			math_mode = modes.pick_random()

	# Final Boss always uses MIXED
	if type == "boss" and not is_mini_boss:
		math_op = MathConfig.Operation.MIXED

	# Determine rewards
	var reward_gold: int = 0
	var reward_chest_chance: float = 0.0
	var enemy_count: int = 0
	var boss_phases: int = 0
	var boss_name: String = ""

	match type:
		"combat":
			reward_gold = randi_range(10, 20)
			reward_chest_chance = 0.0
			enemy_count = randi_range(3, 5) + tier
		"elite":
			reward_gold = randi_range(25, 40)
			reward_chest_chance = 0.5
			enemy_count = randi_range(4, 6) + tier
		"boss":
			if is_mini_boss:
				reward_gold = 30
				reward_chest_chance = 1.0
				boss_phases = 3
				boss_name = _pick_random_boss_name(false)
				enemy_count = 5
			else:
				reward_gold = 50
				reward_chest_chance = 1.0  # Actually drops 2 chests
				boss_phases = 5
				boss_name = _pick_random_boss_name(true)
				enemy_count = 6
		"shop":
			reward_gold = 0
			reward_chest_chance = 0.0
		"rest":
			reward_gold = 0
			reward_chest_chance = 0.0

	# Apply wisdom gold multiplier
	if reward_gold > 0 and has_node("/root/SaveManager"):
		reward_gold = int(float(reward_gold) * get_node("/root/SaveManager").get_gold_multiplier())

	return {
		"id": id,
		"type": type,
		"tier": tier,
		"math_mode": math_mode,
		"math_operation": math_op,
		"math_difficulty": difficulty,
		"reward_gold": reward_gold,
		"reward_chest_chance": reward_chest_chance,
		"enemy_count": enemy_count,
		"boss_phases": boss_phases,
		"boss_name": boss_name,
		"is_mini_boss": is_mini_boss,
		"connections": []  # IDs of nodes this connects to in next tier
	}


func _pick_random_boss_name(is_final: bool) -> String:
	if is_final:
		var names: Array[String] = [
			"Mathe-Drache", "Zahlen-Titan", "Rechen-Dämon",
			"Arithmetik-Lord", "Gleichungs-König"
		]
		return names.pick_random()
	else:
		var names: Array[String] = [
			"Orc-Kriegsherr", "Goblin-Häuptling", "Skelett-Ritter",
			"Dunkler Magier", "Troll-Champion"
		]
		return names.pick_random()


func _shuffle_tier_positions(tier: Array[Dictionary]) -> void:
	# Assign position indices for visual layout
	var indices: Array[int] = []
	for i in range(tier.size()):
		indices.append(i)
	indices.shuffle()
	for i in range(tier.size()):
		tier[i]["position_index"] = indices[i]


func _generate_connections() -> void:
	for tier_idx in range(run_map.size() - 1):
		var current_tier_nodes: Array = run_map[tier_idx]
		var next_tier_nodes: Array = run_map[tier_idx + 1]

		if next_tier_nodes.size() == 1:
			# All nodes connect to the single node (final boss)
			for node in current_tier_nodes:
				node.connections = [next_tier_nodes[0].id]
		else:
			# Each node connects to 1-2 nodes in next tier
			# Ensure every next-tier node has at least one incoming connection
			var next_ids: Array[int] = []
			for n in next_tier_nodes:
				next_ids.append(n.id)

			for i in range(current_tier_nodes.size()):
				var node: Dictionary = current_tier_nodes[i]
				var conns: Array[int] = []

				# Always connect to the nearest positional node
				var my_pos: int = node.get("position_index", i)
				var best_idx: int = clampi(my_pos, 0, next_tier_nodes.size() - 1)
				conns.append(next_tier_nodes[best_idx].id)

				# 60% chance to also connect to an adjacent node
				if randf() < 0.6:
					var alt_idx: int = best_idx + (1 if randf() < 0.5 else -1)
					alt_idx = clampi(alt_idx, 0, next_tier_nodes.size() - 1)
					if next_tier_nodes[alt_idx].id not in conns:
						conns.append(next_tier_nodes[alt_idx].id)

				node.connections = conns

			# Verify all next-tier nodes have at least one incoming connection
			for next_node in next_tier_nodes:
				var has_incoming: bool = false
				for node in current_tier_nodes:
					if next_node.id in node.connections:
						has_incoming = true
						break
				if not has_incoming:
					# Connect a random current-tier node to this orphan
					var random_node: Dictionary = current_tier_nodes.pick_random()
					random_node.connections.append(next_node.id)


# === Node Interaction ===

func select_node(node_id: int) -> Dictionary:
	var node_data: Dictionary = get_node_by_id(node_id)
	if node_data.is_empty():
		return {}

	current_node_id = node_id
	current_tier = node_data.tier
	EventBus.map_node_selected.emit(node_data)
	EventBus.run_node_entered.emit(node_data)
	return node_data


func complete_current_node() -> void:
	if current_node_id < 0:
		return

	var node_data: Dictionary = get_node_by_id(current_node_id)
	completed_node_ids.append(current_node_id)

	# Award gold
	if node_data.reward_gold > 0:
		add_run_gold(node_data.reward_gold, "Knoten-Belohnung")

	# Award direct XP to knight
	var xp_gain: int = 20
	if node_data.type == "elite":
		xp_gain = 40
	elif node_data.type == "boss":
		xp_gain = 60 if node_data.get("is_mini_boss", false) else 150
	elif node_data.type == "rest":
		xp_gain = 10
	
	if has_node("/root/SaveManager"):
		get_node("/root/SaveManager").add_xp(xp_gain)

	# Check chest drop
	_check_chest_drop(node_data)

	# Update available nodes for next tier
	_update_available_nodes()

	EventBus.map_node_completed.emit(node_data)
	EventBus.run_node_exited.emit(node_data)

	# Check if this was the final boss
	if node_data.type == "boss" and not node_data.get("is_mini_boss", false):
		end_run(true)


func _check_chest_drop(node_data: Dictionary) -> void:
	var chest_chance: float = node_data.get("reward_chest_chance", 0.0)

	if node_data.type == "boss":
		if node_data.get("is_mini_boss", false):
			# Mini-boss: 1 guaranteed chest (Silver or Gold)
			var quality: String = "silver" if randf() < 0.7 else "gold"
			_add_chest(quality)
		else:
			# Final boss: 2 guaranteed chests (Gold or Legendary)
			for i in range(2):
				var quality: String = "gold" if randf() < 0.7 else "legendary"
				_add_chest(quality)
	elif chest_chance > 0.0 and randf() < chest_chance:
		# Elite or other: random chest
		var quality: String = "bronze" if randf() < 0.6 else "silver"
		_add_chest(quality)


func _add_chest(quality: String) -> void:
	var chest: Dictionary = {
		"quality": quality,
		"opened": false,
		"contents": _generate_chest_contents(quality)
	}
	run_chests.append(chest)
	EventBus.chest_collected.emit(chest)


func _generate_chest_contents(quality: String) -> Dictionary:
	# Generate what's inside the chest (revealed only after solving the math challenge)
	match quality:
		"bronze":
			if randf() < 0.7:
				return {"type": "gold", "amount": randi_range(10, 20)}
			else:
				return {"type": "cosmetic", "rarity": "common"}
		"silver":
			var roll: float = randf()
			if roll < 0.4:
				return {"type": "gold", "amount": randi_range(30, 50)}
			elif roll < 0.7:
				return {"type": "cosmetic", "rarity": "uncommon"}
			else:
				return {"type": "artifact", "rarity": "common"}
		"gold":
			var roll: float = randf()
			if roll < 0.3:
				return {"type": "cosmetic", "rarity": "rare"}
			elif roll < 0.6:
				return {"type": "artifact", "rarity": "rare"}
			else:
				return {"type": "diamonds", "amount": 1}
		"legendary":
			if randf() < 0.6:
				return {"type": "cosmetic", "rarity": "legendary"}
			else:
				return {"type": "diamonds", "amount": randi_range(2, 3)}
		_:
			return {"type": "gold", "amount": 10}


func _update_available_nodes() -> void:
	available_node_ids.clear()

	if current_tier < 0 or current_tier >= run_map.size() - 1:
		return

	# Find what nodes the completed node connects to
	var current_node: Dictionary = get_node_by_id(current_node_id)
	for next_id in current_node.get("connections", []):
		if next_id not in completed_node_ids and next_id not in available_node_ids:
			available_node_ids.append(next_id)


# === Gold Management ===

func add_run_gold(amount: int, reason: String = "") -> void:
	run_gold += amount
	EventBus.gold_earned.emit(amount, reason)
	EventBus.gold_changed.emit(run_gold)


func spend_run_gold(amount: int) -> bool:
	if run_gold < amount:
		return false
	run_gold -= amount
	EventBus.gold_changed.emit(run_gold)
	return true


# === HP Management ===

func heal_knight(amount: float) -> void:
	knight_run_hp = minf(knight_run_hp + amount, knight_run_max_hp)


func heal_knight_percent(percent: float) -> void:
	var heal_amount: float = knight_run_max_hp * percent
	heal_knight(heal_amount)


func apply_damage(amount: float) -> void:
	var actual: float = maxf(0.5, amount - knight_run_armor)
	if randf() < knight_run_dodge:
		return  # Dodged!
	knight_run_hp = maxf(0.0, knight_run_hp - actual)


# === Artifact Management ===

func add_artifact(artifact: Dictionary) -> void:
	run_artifacts.append(artifact)
	_recalculate_artifact_bonuses()
	EventBus.artifact_acquired.emit(artifact.get("id", "unknown"))


func _recalculate_artifact_bonuses() -> void:
	# Reset to base stats
	if has_node("/root/SaveManager"):
		var sm: Node = get_node("/root/SaveManager")
		knight_run_max_hp = sm.get_max_hp()
		knight_run_attack = sm.get_attack_power()
		knight_run_armor = sm.get_armor()
		knight_run_dodge = sm.get_dodge_chance()

	# Apply artifact bonuses
	for artifact in run_artifacts:
		match artifact.get("effect_type", ""):
			"hp_boost":
				knight_run_max_hp += artifact.get("value", 0.0)
				knight_run_hp = minf(knight_run_hp, knight_run_max_hp)
			"attack_boost":
				knight_run_attack += artifact.get("value", 0.0)
			"armor_boost":
				knight_run_armor += artifact.get("value", 0.0)
			"dodge_boost":
				knight_run_dodge += artifact.get("value", 0.0)


# === Utility ===

func get_node_by_id(node_id: int) -> Dictionary:
	for tier in run_map:
		for node_data in tier:
			if node_data.id == node_id:
				return node_data
	return {}


func is_node_available(node_id: int) -> bool:
	return node_id in available_node_ids


func is_node_completed(node_id: int) -> bool:
	return node_id in completed_node_ids


func get_current_node() -> Dictionary:
	return get_node_by_id(current_node_id)


func get_node_state(node_id: int) -> String:
	if node_id == current_node_id:
		return "current"
	elif node_id in completed_node_ids:
		return "completed"
	elif node_id in available_node_ids:
		return "available"
	else:
		return "locked"


func get_math_config_for_node(node_data: Dictionary) -> MathConfig:
	return MathConfig.create_config(
		node_data.get("math_mode", MathConfig.GameMode.TASK_TO_RESULT),
		node_data.get("math_operation", MathConfig.Operation.ADDITION),
		node_data.get("math_difficulty", MathConfig.Difficulty.EASY)
	)


func get_difficulty_stars(node_data: Dictionary) -> String:
	match node_data.get("math_difficulty", MathConfig.Difficulty.EASY):
		MathConfig.Difficulty.EASY:
			return "★☆☆"
		MathConfig.Difficulty.MEDIUM:
			return "★★☆"
		MathConfig.Difficulty.HARD:
			return "★★★"
		_:
			return "★☆☆"


func get_operation_name(node_data: Dictionary) -> String:
	match node_data.get("math_operation", MathConfig.Operation.ADDITION):
		MathConfig.Operation.ADDITION:
			return "Addition"
		MathConfig.Operation.SUBTRACTION:
			return "Subtraktion"
		MathConfig.Operation.MULTIPLICATION:
			return "Multiplikation"
		MathConfig.Operation.DIVISION:
			return "Division"
		MathConfig.Operation.MIXED:
			return "Gemischt"
		_:
			return "Addition"


func get_mode_name(node_data: Dictionary) -> String:
	match node_data.get("math_mode", MathConfig.GameMode.TASK_TO_RESULT):
		MathConfig.GameMode.TASK_TO_RESULT:
			return "Rechen-Schlag"
		MathConfig.GameMode.RESULT_TO_EQUATION:
			return "Zahlen-Schmiede"
		MathConfig.GameMode.MULTI_OP_EQUATION:
			return "Meister-Kette"
		_:
			return "Rechen-Schlag"


func get_node_type_name(type: String) -> String:
	match type:
		"combat": return "Kampf"
		"elite": return "Elite-Kampf"
		"boss": return "Boss-Kampf"
		"shop": return "Händler"
		"rest": return "Rast"
		_: return "Unbekannt"


# === Signal Handlers ===

func _on_gold_earned(amount: int, _reason: String) -> void:
	if not is_run_active:
		return
	# Gold is already tracked via add_run_gold, this catches external gold sources


func _on_chest_collected(_chest_data: Dictionary) -> void:
	pass  # Already handled in _add_chest


func _on_flawless_set(_set_number: int) -> void:
	if not is_run_active:
		return
	run_sets_flawless += 1
	# 25% chance for bronze chest on flawless
	if randf() < 0.25:
		_add_chest("bronze")
