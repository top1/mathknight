class_name SiegeGateLevel
extends Resource
## Data resource defining a Siege Gate Maze (Castle Attack) level.
## The maze is structured as a sequence of stages forming a branching DAG.
## Each stage contains one or more branches (levers).
## Each branch has an entry Y position and a list of path choices (operations + exit Y).

@export var level_name: String = "Belagerung"
@export var starting_soldiers: int = 12
@export var castle_defense_value: int = 40
@export var hint_text: String = ""
@export var star_3_threshold: float = 0.90
@export var star_2_threshold: float = 0.70
@export var star_1_threshold: float = 0.50

## Stages array.
## Each stage is a Dictionary:
## {
##   "branches": [
##     {
##       "entry_y": 0.5, # normalized 0.0 - 1.0 within maze vertical area
##       "choices": [
##         {
##           "label": "×2",
##           "exit_y": 0.25,
##           "operations": [{"op": "mul", "value": 2}]
##         },
##         ...
##       ]
##     }
##   ]
## }
@export var stages: Array = []


## Apply operations list to a number
static func apply_operations(input: int, operations: Array) -> int:
	var result: int = input
	for op_dict: Variant in operations:
		var d: Dictionary = op_dict as Dictionary
		var op_type: String = d.get("op", "add")
		var op_value: int = int(d.get("value", 0))
		match op_type:
			"add":
				result += op_value
			"sub":
				result -= op_value
			"mul":
				result *= op_value
			"div":
				if op_value != 0:
					result = int(float(result) / float(op_value))
		result = maxi(result, 0)
	return result


## Calculate the optimal (maximum) army size across all reachable paths.
func calculate_optimal() -> int:
	if stages.is_empty():
		return starting_soldiers
	return _explore_stage(starting_soldiers, 0, 0)


func _explore_stage(current_value: int, stage_idx: int, branch_idx: int) -> int:
	if stage_idx >= stages.size():
		return current_value

	var stage_dict: Dictionary = stages[stage_idx] as Dictionary
	var branches: Array = stage_dict.get("branches", [])
	if branch_idx >= branches.size():
		return current_value

	var branch: Dictionary = branches[branch_idx] as Dictionary
	var choices: Array = branch.get("choices", [])
	var best: int = 0

	for choice_idx in range(choices.size()):
		var choice: Dictionary = choices[choice_idx] as Dictionary
		var ops: Array = choice.get("operations", [])
		var next_val: int = SiegeGateLevel.apply_operations(current_value, ops)

		# Determine which branch in the next stage corresponds to this choice's exit_y
		var next_branch_idx: int = _find_matching_next_branch(stage_idx + 1, choice.get("exit_y", 0.5))
		var outcome: int = _explore_stage(next_val, stage_idx + 1, next_branch_idx)
		best = maxi(best, outcome)

	return best


## Collect all reachable final army values
func calculate_all_outcomes() -> Array[int]:
	var outcomes: Array[int] = []
	if stages.is_empty():
		outcomes.append(starting_soldiers)
		return outcomes
	_collect_stage_outcomes(starting_soldiers, 0, 0, outcomes)
	return outcomes


func _collect_stage_outcomes(current_value: int, stage_idx: int, branch_idx: int, results: Array[int]) -> void:
	if stage_idx >= stages.size():
		results.append(current_value)
		return

	var stage_dict: Dictionary = stages[stage_idx] as Dictionary
	var branches: Array = stage_dict.get("branches", [])
	if branch_idx >= branches.size():
		results.append(current_value)
		return

	var branch: Dictionary = branches[branch_idx] as Dictionary
	var choices: Array = branch.get("choices", [])

	for choice in choices:
		var ops: Array = choice.get("operations", [])
		var next_val: int = SiegeGateLevel.apply_operations(current_value, ops)
		var next_branch_idx: int = _find_matching_next_branch(stage_idx + 1, choice.get("exit_y", 0.5))
		_collect_stage_outcomes(next_val, stage_idx + 1, next_branch_idx, results)


func _find_matching_next_branch(next_stage_idx: int, exit_y: float) -> int:
	if next_stage_idx >= stages.size():
		return 0
	var next_stage: Dictionary = stages[next_stage_idx] as Dictionary
	var branches: Array = next_stage.get("branches", [])
	if branches.is_empty():
		return 0

	var best_idx: int = 0
	var min_dist: float = 999.0
	for b_i in range(branches.size()):
		var b: Dictionary = branches[b_i] as Dictionary
		var entry_y: float = float(b.get("entry_y", 0.5))
		var dist: float = absf(entry_y - exit_y)
		if dist < min_dist:
			min_dist = dist
			best_idx = b_i
	return best_idx


## Format an operation list into a display string (e.g., "×2", "+10", "-5 ×2")
static func format_operations(operations: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for op_dict: Variant in operations:
		var d: Dictionary = op_dict as Dictionary
		var op_type: String = d.get("op", "add")
		var op_value: int = int(d.get("value", 0))
		match op_type:
			"add":
				parts.append("+" + str(op_value))
			"sub":
				parts.append("-" + str(op_value))
			"mul":
				parts.append("×" + str(op_value))
			"div":
				parts.append("÷" + str(op_value))
	return " ".join(parts)


static func is_beneficial(operations: Array, test_value: int = 10) -> bool:
	return SiegeGateLevel.apply_operations(test_value, operations) > test_value


## Create a level from a Dictionary (parsed from JSON).
static func from_dict(data: Dictionary) -> SiegeGateLevel:
	var level := SiegeGateLevel.new()
	level.level_name = data.get("level_name", "Belagerung")
	level.starting_soldiers = int(data.get("starting_soldiers", 12))
	level.castle_defense_value = int(data.get("castle_defense_value", 40))
	level.hint_text = data.get("hint_text", "")
	level.star_3_threshold = float(data.get("star_3_threshold", 0.90))
	level.star_2_threshold = float(data.get("star_2_threshold", 0.70))
	level.star_1_threshold = float(data.get("star_1_threshold", 0.50))
	level.stages = data.get("stages", [])
	return level
