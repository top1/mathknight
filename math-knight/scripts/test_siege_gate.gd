extends SceneTree
## Headless test for the Siege Gate Maze (Castle Attack) system.
## Tests DAG branching level data, operation calculations, optimal path finding, and scene instantiation.
## Run: & "C:\GoDot\Godot_v4.5.1-stable_win64_console.exe" --headless --path "c:\MathKnight\math-knight" -s "res://scripts/test_siege_gate.gd"

var _pass_count: int = 0
var _fail_count: int = 0


func _init() -> void:
	print("\n" + "=".repeat(60))
	print("  SIEGE GATE MAZE — REVIEWED & FIXED TEST SUITE")
	print("=".repeat(60))

	_test_apply_operations()
	_test_sketch_level_dag()
	_test_format_operations()
	_test_is_beneficial()
	_test_json_loading_all_levels()
	_test_scene_instantiation()

	print("\n" + "-".repeat(60))
	print("  FINAL RESULTS: %d passed, %d failed" % [_pass_count, _fail_count])
	print("-".repeat(60) + "\n")

	quit(0 if _fail_count == 0 else 1)


func _assert_eq(actual: Variant, expected: Variant, desc: String) -> void:
	if actual == expected:
		_pass_count += 1
		print("  ✅ PASS: %s" % desc)
	else:
		_fail_count += 1
		print("  ❌ FAIL: %s — expected '%s', got '%s'" % [desc, str(expected), str(actual)])


func _assert_true(condition: bool, desc: String) -> void:
	if condition:
		_pass_count += 1
		print("  ✅ PASS: %s" % desc)
	else:
		_fail_count += 1
		print("  ❌ FAIL: %s — condition was false" % desc)


# === Test: apply_operations ===

func _test_apply_operations() -> void:
	print("\n--- Test: apply_operations ---")

	# ×2
	var result: int = SiegeGateLevel.apply_operations(12, [{"op": "mul", "value": 2}])
	_assert_eq(result, 24, "12 × 2 = 24")

	# +10
	result = SiegeGateLevel.apply_operations(12, [{"op": "add", "value": 10}])
	_assert_eq(result, 22, "12 + 10 = 22")

	# -5 then ×2
	result = SiegeGateLevel.apply_operations(24, [{"op": "sub", "value": 5}, {"op": "mul", "value": 2}])
	_assert_eq(result, 38, "(24 - 5) × 2 = 38")

	# +20 then ÷3
	result = SiegeGateLevel.apply_operations(24, [{"op": "add", "value": 20}, {"op": "div", "value": 3}])
	_assert_eq(result, 14, "(24 + 20) ÷ 3 = 14 (floor)")

	# -8 then ×3
	result = SiegeGateLevel.apply_operations(22, [{"op": "sub", "value": 8}, {"op": "mul", "value": 3}])
	_assert_eq(result, 42, "(22 - 8) × 3 = 42")

	# Clamped to 0
	result = SiegeGateLevel.apply_operations(5, [{"op": "sub", "value": 20}])
	_assert_eq(result, 0, "5 - 20 = 0 (clamped)")

	# Div zero protection
	result = SiegeGateLevel.apply_operations(10, [{"op": "div", "value": 0}])
	_assert_eq(result, 10, "10 ÷ 0 = 10 (safe)")


# === Test: Sketch DAG Level Verification ===

func _test_sketch_level_dag() -> void:
	print("\n--- Test: Sketch DAG Level (The User's Exact Problem) ---")

	var json_file := FileAccess.open("res://assets/siege_levels.json", FileAccess.READ)
	_assert_true(json_file != null, "Open siege_levels.json")
	var json := JSON.new()
	json.parse(json_file.get_as_text())
	json_file.close()

	var levels: Array = json.data.get("levels", [])
	var level1: SiegeGateLevel = SiegeGateLevel.from_dict(levels[0])

	_assert_eq(level1.level_name, "Waldburg-Belagerung", "Level 1 name")
	_assert_eq(level1.starting_soldiers, 12, "Starting soldiers = 12")
	_assert_eq(level1.castle_defense_value, 40, "Castle defense = 40")

	# Test all outcomes in the branching graph
	var outcomes: Array[int] = level1.calculate_all_outcomes()
	_assert_eq(outcomes.size(), 4, "4 reachable leaf paths in the DAG (not 6 disconnected combinations)")

	# Reachable paths according to user prompt and sketch:
	# 1. Top -> Top:   12 -> x2 (24) -> -5 x2 = 38 (LOSE: 38 < 40)
	# 2. Top -> Mid:   12 -> x2 (24) -> +20 /3 = 14 (LOSE: 14 < 40)
	# 3. Bot -> Mid:   12 -> +10 (22) -> +20 /3 = 14 (LOSE: 14 < 40)
	# 4. Bot -> Bot:   12 -> +10 (22) -> -8 x3 = 42 (WIN: 42 >= 40)
	_assert_true(outcomes.has(38), "Outcome 38 reachable (Top -> Top)")
	_assert_true(outcomes.has(14), "Outcome 14 reachable (Top -> Mid and Bot -> Mid)")
	_assert_true(outcomes.has(42), "Outcome 42 reachable (Bot -> Bot)")
	_assert_true(not outcomes.has(48), "Outcome 48 NOT reachable (cannot jump from Top x2 to Bot -8x3!)")

	# Optimal calculation
	var optimal: int = level1.calculate_optimal()
	_assert_eq(optimal, 42, "Optimal score = 42 (beats castle defense 40!)")


# === Test: format_operations ===

func _test_format_operations() -> void:
	print("\n--- Test: format_operations ---")

	_assert_eq(SiegeGateLevel.format_operations([{"op": "mul", "value": 2}]), "×2", "Format ×2")
	_assert_eq(SiegeGateLevel.format_operations([{"op": "add", "value": 10}]), "+10", "Format +10")
	_assert_eq(SiegeGateLevel.format_operations([{"op": "sub", "value": 5}, {"op": "mul", "value": 2}]), "-5 ×2", "Format -5 ×2")
	_assert_eq(SiegeGateLevel.format_operations([{"op": "add", "value": 20}, {"op": "div", "value": 3}]), "+20 ÷3", "Format +20 ÷3")


# === Test: is_beneficial ===

func _test_is_beneficial() -> void:
	print("\n--- Test: is_beneficial ---")

	_assert_true(SiegeGateLevel.is_beneficial([{"op": "mul", "value": 2}]), "×2 beneficial")
	_assert_true(SiegeGateLevel.is_beneficial([{"op": "add", "value": 10}]), "+10 beneficial")
	_assert_true(not SiegeGateLevel.is_beneficial([{"op": "sub", "value": 5}]), "-5 not beneficial")
	_assert_true(not SiegeGateLevel.is_beneficial([{"op": "div", "value": 3}]), "÷3 not beneficial")


# === Test: JSON Loading All Levels ===

func _test_json_loading_all_levels() -> void:
	print("\n--- Test: JSON Loading All Levels ---")

	var json_file := FileAccess.open("res://assets/siege_levels.json", FileAccess.READ)
	var json := JSON.new()
	json.parse(json_file.get_as_text())
	json_file.close()

	var levels: Array = json.data.get("levels", [])
	_assert_eq(levels.size(), 4, "Total 4 curated levels")

	for i in range(levels.size()):
		var lvl: SiegeGateLevel = SiegeGateLevel.from_dict(levels[i])
		var opt: int = lvl.calculate_optimal()
		print("  Level %d '%s': start=%d, defense=%d, optimal=%d" % [
			i + 1, lvl.level_name, lvl.starting_soldiers, lvl.castle_defense_value, opt
		])
		_assert_true(opt >= lvl.castle_defense_value, "Level %d has a winning path (optimal >= defense)" % (i + 1))


# === Test: Scene Instantiation ===

func _test_scene_instantiation() -> void:
	print("\n--- Test: Scene Instantiation ---")

	var scene: PackedScene = load("res://scenes/siege/SiegeGateMaze.tscn")
	_assert_true(scene != null, "SiegeGateMaze.tscn loads successfully")

	var instance: Node = scene.instantiate()
	_assert_true(instance != null, "SiegeGateMaze instances successfully")

	var maze: SiegeGateMaze = instance as SiegeGateMaze
	root.add_child(maze)
	_assert_eq(maze.mouse_filter, Control.MOUSE_FILTER_IGNORE, "Mouse filter is MOUSE_FILTER_IGNORE")
	maze.load_level_by_index(0)

	_assert_eq(maze.stage_levers.size(), 2, "Maze has 2 lever stages")
	_assert_eq(maze.stage_levers[0].size(), 1, "Stage 0 has 1 lever")
	_assert_eq(maze.stage_levers[1].size(), 2, "Stage 1 has 2 levers (matches sketch!)")
	_assert_true(is_instance_valid(maze.army_cluster), "ArmyCluster created")
	_assert_true(is_instance_valid(maze.castle_sprite), "CastleSprite created")

	maze.queue_free()
