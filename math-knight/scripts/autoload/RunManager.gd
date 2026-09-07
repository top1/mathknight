extends Node
## RunManager singleton — manages the active roguelike run state in MathKnight.
## Supports 10 progressive combat stages + 1 epic Final Boss (Stage 11),
## 3-card dynamic stage choices, post-stage Merchant / Chest Hub, and run statistics.

const TOTAL_REGULAR_STAGES: int = 10
const FINAL_BOSS_STAGE: int = 11

# === Run State ===
var is_run_active: bool = false
var run_gold: int = 0
var run_chests: Array[Dictionary] = []  # Collected chests to open in Hub / post-run
var run_artifacts: Array[Dictionary] = []  # Active artifacts for this run
var run_score: int = 0
var run_sets_flawless: int = 0
var stages_completed_count: int = 0

# Current stage progression (0 = Stage 1 ... 9 = Stage 10, 10 = Stage 11 Boss)
var current_stage_index: int = 0
var current_stage_choices: Array[Dictionary] = []
var current_stage_data: Dictionary = {}
var pending_combat_result: bool = false

# === Knight Run Stats (base + artifacts) ===
var knight_run_max_hp: float = 10.0
var knight_run_hp: float = 10.0
var knight_run_attack: float = 1.0
var knight_run_armor: float = 0.0
var knight_run_dodge: float = 0.0


func _get_bus() -> Node:
	if has_node("/root/EventBus"):
		return get_node("/root/EventBus")
	return null


func _emit_bus(sig_name: String, arg1 = null, arg2 = null) -> void:
	var bus: Node = _get_bus()
	if bus and (bus.has_signal(sig_name) or bus.has_user_signal(sig_name)):
		if arg2 != null:
			bus.emit_signal(sig_name, arg1, arg2)
		elif arg1 != null:
			bus.emit_signal(sig_name, arg1)
		else:
			bus.emit_signal(sig_name)


func _ready() -> void:
	var bus: Node = _get_bus()
	if bus:
		if bus.has_signal("gold_earned"): bus.gold_earned.connect(_on_gold_earned)
		if bus.has_signal("chest_collected"): bus.chest_collected.connect(_on_chest_collected)
		if bus.has_signal("flawless_set_achieved"): bus.flawless_set_achieved.connect(_on_flawless_set)


# === Run Lifecycle ===

func start_new_run() -> void:
	is_run_active = true
	run_gold = 0
	run_chests.clear()
	run_artifacts.clear()
	run_score = 0
	run_sets_flawless = 0
	stages_completed_count = 0
	current_stage_index = 0
	current_stage_data = {}
	pending_combat_result = false

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

	# Generate the 3 choices for Stage 1
	generate_stage_choices(0)

	if has_node("/root/SaveManager"):
		get_node("/root/SaveManager").total_runs_started += 1

	_emit_bus("run_started")


func end_run(is_victory: bool) -> Dictionary:
	is_run_active = false

	var stats: Dictionary = {
		"is_victory": is_victory,
		"score": run_score,
		"gold": run_gold,
		"chests": run_chests.duplicate(),
		"flawless_sets": run_sets_flawless,
		"nodes_completed": stages_completed_count,
		"stages_completed": stages_completed_count,
		"tier_reached": current_stage_index + 1,
		"current_stage": current_stage_index + 1,
		"total_stages": FINAL_BOSS_STAGE,
		"artifacts_used": run_artifacts.size()
	}

	# Award diamonds for run completion
	var diamond_reward: int = 0
	if is_victory:
		diamond_reward = randi_range(4, 7)
	elif stages_completed_count >= 5:
		diamond_reward = randi_range(1, 2)

	if diamond_reward > 0 and has_node("/root/SaveManager"):
		get_node("/root/SaveManager").add_diamonds(diamond_reward)
	stats["diamonds_earned"] = diamond_reward

	# Add XP
	var xp_reward: int = 15 * stages_completed_count
	if is_victory:
		xp_reward += 100
	if has_node("/root/SaveManager"):
		var sm: Node = get_node("/root/SaveManager")
		sm.add_xp(xp_reward)
		sm.add_gold(run_gold)
		if is_victory:
			sm.total_runs_completed += 1
		sm.add_highscore(stats)
	stats["xp_earned"] = xp_reward

	_emit_bus("run_ended", stats)
	return stats


# === 3-Choice Stage Generation ===

func generate_stage_choices(stage_idx: int) -> Array[Dictionary]:
	current_stage_index = stage_idx
	current_stage_choices.clear()

	# If we are at the final boss stage (Stage 11)
	if stage_idx >= TOTAL_REGULAR_STAGES:
		var boss_choice = _create_boss_stage_choice()
		current_stage_choices = [boss_choice]
		return current_stage_choices

	var ops_pool: Array[int] = _get_available_operations_for_stage(stage_idx)
	var input_types_pool: Array[int] = [
		MathConfig.InputType.BUBBLES,
		MathConfig.InputType.BUBBLES_MOVING,
		MathConfig.InputType.BUBBLES_LIVING,
		MathConfig.InputType.QUICK_TAP,
		MathConfig.InputType.HOLD_STRETCH,
		MathConfig.InputType.HANDWRITING,
		MathConfig.InputType.KEYPAD,
		MathConfig.InputType.TIMING_BAR,
		MathConfig.InputType.NUMBER_WHEEL
	]

	# Choice 1: The Balanced Path (Standard Combat)
	var c1_op: int = ops_pool.pick_random()
	var c1_math_diff: int = MathConfig.Difficulty.EASY if stage_idx < 4 else (MathConfig.Difficulty.MEDIUM if stage_idx < 8 else MathConfig.Difficulty.HARD)
	var c1_input_type: int = [MathConfig.InputType.BUBBLES, MathConfig.InputType.BUBBLES_MOVING, MathConfig.InputType.QUICK_TAP].pick_random()
	var c1_input_diff: int = MathConfig.InputDifficulty.EASY if stage_idx < 5 else MathConfig.InputDifficulty.MEDIUM
	var c1 = _build_choice_dict(stage_idx, "combat", "⚔️ Vorhut-Scharmützel", c1_op, c1_math_diff, c1_input_type, c1_input_diff, "standard")
	current_stage_choices.append(c1)

	# Choice 2: The Agility / Speed Path (Input Focused)
	var c2_op: int = ops_pool.pick_random()
	var c2_math_diff: int = MathConfig.Difficulty.EASY if stage_idx < 3 else MathConfig.Difficulty.MEDIUM
	var c2_input_type: int = [MathConfig.InputType.BUBBLES_LIVING, MathConfig.InputType.QUICK_TAP, MathConfig.InputType.TIMING_BAR, MathConfig.InputType.HOLD_STRETCH, MathConfig.InputType.NUMBER_WHEEL].pick_random()
	var c2_input_diff: int = MathConfig.InputDifficulty.MEDIUM if stage_idx < 6 else MathConfig.InputDifficulty.HARD
	var c2 = _build_choice_dict(stage_idx, "speed", "⚡ Tempo-Prüfung", c2_op, c2_math_diff, c2_input_type, c2_input_diff, "speed")
	current_stage_choices.append(c2)

	# Choice 3: The Arcane / Elite Path (High Math Challenge & Big Rewards)
	var c3_op: int = ops_pool.pick_random()
	if MathConfig.Operation.MIXED in ops_pool and randf() < 0.6:
		c3_op = MathConfig.Operation.MIXED
	elif MathConfig.Operation.MULTIPLICATION in ops_pool and randf() < 0.5:
		c3_op = MathConfig.Operation.MULTIPLICATION

	var c3_math_diff: int = MathConfig.Difficulty.MEDIUM if stage_idx < 4 else MathConfig.Difficulty.HARD
	var c3_input_type: int = input_types_pool.pick_random()
	var c3_input_diff: int = MathConfig.InputDifficulty.MEDIUM if stage_idx < 5 else MathConfig.InputDifficulty.HARD
	var c3 = _build_choice_dict(stage_idx, "elite", "🛡️ Arkanes Elite-Tor", c3_op, c3_math_diff, c3_input_type, c3_input_diff, "elite")
	current_stage_choices.append(c3)

	return current_stage_choices


func _get_available_operations_for_stage(stage_idx: int) -> Array[int]:
	var ops: Array[int] = []
	if stage_idx <= 2:
		ops = [MathConfig.Operation.ADDITION, MathConfig.Operation.SUBTRACTION]
	elif stage_idx <= 5:
		ops = [MathConfig.Operation.ADDITION, MathConfig.Operation.SUBTRACTION, MathConfig.Operation.MULTIPLICATION]
	elif stage_idx <= 7:
		ops = [MathConfig.Operation.ADDITION, MathConfig.Operation.SUBTRACTION, MathConfig.Operation.MULTIPLICATION, MathConfig.Operation.DIVISION]
	else:
		ops = [MathConfig.Operation.MULTIPLICATION, MathConfig.Operation.DIVISION, MathConfig.Operation.MIXED, MathConfig.Operation.ADDITION]
	return ops


func _build_choice_dict(stage_idx: int, type: String, title: String, op: int, math_diff: int, input_type: int, input_diff: int, archetype: String) -> Dictionary:
	var math_mode: int = MathConfig.GameMode.TASK_TO_RESULT
	if stage_idx >= 3 and randf() < 0.35:
		math_mode = MathConfig.GameMode.RESULT_TO_EQUATION
	elif stage_idx >= 6 and randf() < 0.3:
		math_mode = MathConfig.GameMode.MULTI_OP_EQUATION

	var base_gold: int = 18 + (stage_idx * 6)

	var diff_mult: float = 1.0
	match math_diff:
		MathConfig.Difficulty.EASY: diff_mult = 1.0
		MathConfig.Difficulty.MEDIUM: diff_mult = 1.35
		MathConfig.Difficulty.HARD: diff_mult = 1.75

	match input_diff:
		MathConfig.InputDifficulty.EASY: diff_mult *= 1.0
		MathConfig.InputDifficulty.MEDIUM: diff_mult *= 1.2
		MathConfig.InputDifficulty.HARD: diff_mult *= 1.5

	if archetype == "elite":
		diff_mult *= 1.3
	elif archetype == "speed":
		diff_mult *= 1.15

	var reward_gold: int = int(float(base_gold) * diff_mult)
	if has_node("/root/SaveManager"):
		reward_gold = int(float(reward_gold) * get_node("/root/SaveManager").get_gold_multiplier())

	var chest_chance: float = 0.0
	var guaranteed_chest: String = ""
	var diamond_chance: float = 0.0

	if archetype == "elite":
		if stage_idx >= 7 or math_diff == MathConfig.Difficulty.HARD:
			guaranteed_chest = "gold"
			diamond_chance = 0.4
		elif stage_idx >= 3:
			guaranteed_chest = "silver"
			diamond_chance = 0.2
		else:
			guaranteed_chest = "bronze"
			chest_chance = 1.0
	elif archetype == "speed":
		chest_chance = 0.45
		guaranteed_chest = "silver" if stage_idx >= 5 else "bronze"
	else:
		chest_chance = 0.25 if stage_idx >= 3 else 0.15
		guaranteed_chest = "bronze"

	var modifier_tags: Array[String] = []
	if archetype == "speed":
		modifier_tags.append("⚡ Tempo-Bonus (+25% Gold)")
	elif archetype == "elite":
		modifier_tags.append("🛡️ Starke Monster (+XP)")
		if guaranteed_chest != "":
			modifier_tags.append("📦 Garantiert " + guaranteed_chest.capitalize() + "-Truhe")
	if diamond_chance > 0.0:
		modifier_tags.append("💎 Chance auf Diamant")

	var enemy_count: int = 3 + (stage_idx / 3)
	if archetype == "elite":
		enemy_count += 1

	return {
		"id": stage_idx * 10 + current_stage_choices.size(),
		"type": type,
		"stage_number": stage_idx + 1,
		"title": title,
		"math_mode": math_mode,
		"math_operation": op,
		"math_difficulty": math_diff,
		"input_type": input_type,
		"input_difficulty": input_diff,
		"reward_gold": reward_gold,
		"reward_chest_chance": chest_chance,
		"guaranteed_chest": guaranteed_chest,
		"diamond_chance": diamond_chance,
		"enemy_count": enemy_count,
		"modifiers": modifier_tags,
		"archetype": archetype
	}


func _create_boss_stage_choice() -> Dictionary:
	return {
		"id": 999,
		"type": "boss",
		"stage_number": FINAL_BOSS_STAGE,
		"title": "👑 DER ZAHLEN-TITAN (ENDBOSS)",
		"math_mode": MathConfig.GameMode.TASK_TO_RESULT,
		"math_operation": MathConfig.Operation.MIXED,
		"math_difficulty": MathConfig.Difficulty.HARD,
		"input_type": MathConfig.InputType.BUBBLES_LIVING,
		"input_difficulty": MathConfig.InputDifficulty.HARD,
		"reward_gold": 150,
		"reward_chest_chance": 1.0,
		"guaranteed_chest": "legendary",
		"diamond_chance": 1.0,
		"enemy_count": 6,
		"boss_phases": 5,
		"boss_name": "Zahlen-Titan Kronos",
		"is_mini_boss": false,
		"modifiers": ["👑 5 Boss-Phasen", "📦 2x Legendäre Truhen", "💎 Garantiert Diamanten"]
	}


# === Stage Selection & Completion ===

func select_stage_choice(choice_index: int) -> Dictionary:
	if choice_index < 0 or choice_index >= current_stage_choices.size():
		return {}

	current_stage_data = current_stage_choices[choice_index]
	_emit_bus("map_node_selected", current_stage_data)
	_emit_bus("run_node_entered", current_stage_data)
	return current_stage_data


func complete_current_stage() -> void:
	if current_stage_data.is_empty():
		return

	stages_completed_count += 1
	var is_boss: bool = (current_stage_data.get("type", "") == "boss")

	# Award Gold
	var gold_earned: int = current_stage_data.get("reward_gold", 20)
	if gold_earned > 0:
		add_run_gold(gold_earned, "Stufen-Belohnung")

	# Award Direct XP
	var xp_gain: int = 25 + (current_stage_index * 10)
	if is_boss:
		xp_gain = 200
	if has_node("/root/SaveManager"):
		get_node("/root/SaveManager").add_xp(xp_gain)

	# Award Chests
	var guaranteed_chest = current_stage_data.get("guaranteed_chest", "")
	var chest_chance = current_stage_data.get("reward_chest_chance", 0.0)
	var diamond_chance = current_stage_data.get("diamond_chance", 0.0)

	if is_boss:
		_add_chest("gold")
		_add_chest("legendary")
		if has_node("/root/SaveManager"):
			get_node("/root/SaveManager").add_diamonds(randi_range(3, 5))
	elif guaranteed_chest != "":
		_add_chest(guaranteed_chest)
	elif chest_chance > 0.0 and randf() < chest_chance:
		_add_chest("bronze" if randf() < 0.6 else "silver")

	if diamond_chance > 0.0 and randf() < diamond_chance:
		if has_node("/root/SaveManager"):
			get_node("/root/SaveManager").add_diamonds(1)

	_emit_bus("map_node_completed", current_stage_data)
	_emit_bus("run_node_exited", current_stage_data)

	if is_boss:
		end_run(true)


func advance_to_next_stage_choices() -> Array[Dictionary]:
	current_stage_index += 1
	return generate_stage_choices(current_stage_index)


# === Chest Management ===

func _add_chest(quality: String) -> void:
	var chest: Dictionary = {
		"quality": quality,
		"opened": false,
		"failed": false,
		"contents": _generate_chest_contents(quality)
	}
	run_chests.append(chest)
	_emit_bus("chest_collected", chest)


func _generate_chest_contents(quality: String) -> Dictionary:
	match quality:
		"bronze":
			if randf() < 0.7:
				return {"type": "gold", "amount": randi_range(15, 30)}
			else:
				return {"type": "cosmetic", "rarity": "common"}
		"silver":
			var roll: float = randf()
			if roll < 0.45:
				return {"type": "gold", "amount": randi_range(40, 75)}
			elif roll < 0.75:
				return {"type": "cosmetic", "rarity": "uncommon"}
			else:
				return {"type": "diamonds", "amount": 1}
		"gold":
			var roll: float = randf()
			if roll < 0.35:
				return {"type": "cosmetic", "rarity": "rare"}
			elif roll < 0.65:
				return {"type": "artifact", "rarity": "rare"}
			else:
				return {"type": "diamonds", "amount": randi_range(1, 2)}
		"legendary":
			if randf() < 0.6:
				return {"type": "cosmetic", "rarity": "legendary"}
			else:
				return {"type": "diamonds", "amount": randi_range(2, 4)}
		_:
			return {"type": "gold", "amount": 20}


# === Gold Management ===

func add_run_gold(amount: int, reason: String = "") -> void:
	run_gold += amount
	_emit_bus("gold_earned", amount, reason)
	_emit_bus("gold_changed", run_gold)


func spend_run_gold(amount: int) -> bool:
	if run_gold < amount:
		return false
	run_gold -= amount
	_emit_bus("gold_changed", run_gold)
	return true


# === HP Management ===

func heal_knight(amount: float) -> void:
	knight_run_hp = minf(knight_run_hp + amount, knight_run_max_hp)
	_emit_bus("knight_damaged", knight_run_hp, knight_run_max_hp)


func heal_knight_percent(percent: float) -> void:
	var heal_amount: float = knight_run_max_hp * percent
	heal_knight(heal_amount)


func apply_damage(amount: float) -> void:
	var actual: float = maxf(0.5, amount - knight_run_armor)
	if randf() < knight_run_dodge:
		return  # Dodged!
	knight_run_hp = maxf(0.0, knight_run_hp - actual)
	_emit_bus("knight_damaged", knight_run_hp, knight_run_max_hp)


# === Artifact Management ===

func add_artifact(artifact: Dictionary) -> void:
	run_artifacts.append(artifact)
	_recalculate_artifact_bonuses()
	_emit_bus("artifact_acquired", artifact.get("id", "unknown"))


func _recalculate_artifact_bonuses() -> void:
	if has_node("/root/SaveManager"):
		var sm: Node = get_node("/root/SaveManager")
		knight_run_max_hp = sm.get_max_hp()
		knight_run_attack = sm.get_attack_power()
		knight_run_armor = sm.get_armor()
		knight_run_dodge = sm.get_dodge_chance()

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


# === Helpers for UI & MathConfig ===

func get_current_stage_data() -> Dictionary:
	return current_stage_data


func get_current_node() -> Dictionary:
	return current_stage_data


func get_math_config_for_stage(stage_data: Dictionary) -> MathConfig:
	return MathConfig.create_config(
		stage_data.get("math_mode", MathConfig.GameMode.TASK_TO_RESULT),
		stage_data.get("math_operation", MathConfig.Operation.ADDITION),
		stage_data.get("math_difficulty", MathConfig.Difficulty.EASY),
		stage_data.get("input_type", MathConfig.InputType.BUBBLES),
		stage_data.get("input_difficulty", MathConfig.InputDifficulty.EASY)
	)


func get_math_config_for_node(node_data: Dictionary) -> MathConfig:
	return get_math_config_for_stage(node_data)


func get_difficulty_stars(stage_data: Dictionary) -> String:
	match stage_data.get("math_difficulty", MathConfig.Difficulty.EASY):
		MathConfig.Difficulty.EASY: return "★☆☆"
		MathConfig.Difficulty.MEDIUM: return "★★☆"
		MathConfig.Difficulty.HARD: return "★★★"
		_: return "★☆☆"


func get_operation_name(stage_data: Dictionary) -> String:
	match stage_data.get("math_operation", MathConfig.Operation.ADDITION):
		MathConfig.Operation.ADDITION: return "Addition (+)"
		MathConfig.Operation.SUBTRACTION: return "Subtraktion (-)"
		MathConfig.Operation.MULTIPLICATION: return "Multiplikation (×)"
		MathConfig.Operation.DIVISION: return "Division (÷)"
		MathConfig.Operation.MIXED: return "Gemischt (+ - × ÷)"
		_: return "Addition (+)"


func get_operation_symbol(stage_data: Dictionary) -> String:
	match stage_data.get("math_operation", MathConfig.Operation.ADDITION):
		MathConfig.Operation.ADDITION: return "+"
		MathConfig.Operation.SUBTRACTION: return "−"
		MathConfig.Operation.MULTIPLICATION: return "×"
		MathConfig.Operation.DIVISION: return "÷"
		MathConfig.Operation.MIXED: return "±×"
		_: return "+"


func get_mode_name(stage_data: Dictionary) -> String:
	match stage_data.get("math_mode", MathConfig.GameMode.TASK_TO_RESULT):
		MathConfig.GameMode.TASK_TO_RESULT: return "Rechen-Schlag"
		MathConfig.GameMode.RESULT_TO_EQUATION: return "Zahlen-Schmiede"
		MathConfig.GameMode.MULTI_OP_EQUATION: return "Meister-Kette"
		_: return "Rechen-Schlag"


func get_input_type_name(input_type: int) -> String:
	match input_type:
		MathConfig.InputType.BUBBLES: return "🫧 Statische Blasen"
		MathConfig.InputType.BUBBLES_MOVING: return "🌊 Wellen-Blasen"
		MathConfig.InputType.BUBBLES_LIVING: return "🌱 Living Blasen"
		MathConfig.InputType.HANDWRITING: return "✍️ Handschrift"
		MathConfig.InputType.QUICK_TAP: return "⚡ Quick-Tap"
		MathConfig.InputType.HOLD_STRETCH: return "🏹 Spannen & Zielen"
		MathConfig.InputType.TIMING_BAR: return "⏱️ Timing-Balken"
		MathConfig.InputType.NUMBER_WHEEL: return "🎡 Zahlen-Rad"
		MathConfig.InputType.KEYPAD: return "🔢 Ziffern-Block"
		_: return "🫧 Blasen"


func get_input_difficulty_name(input_diff: int) -> String:
	match input_diff:
		MathConfig.InputDifficulty.EASY: return "Entspannt"
		MathConfig.InputDifficulty.MEDIUM: return "Flott"
		MathConfig.InputDifficulty.HARD: return "Extrem"
		_: return "Normal"


# === Signal Handlers ===

func _on_gold_earned(_amount: int, _reason: String) -> void:
	pass


func _on_chest_collected(_chest_data: Dictionary) -> void:
	pass


func _on_flawless_set(_set_number: int) -> void:
	if not is_run_active:
		return
	run_sets_flawless += 1
	if randf() < 0.35:
		_add_chest("bronze")
