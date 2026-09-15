extends SceneTree
## Interactive Runtime Simulation Test for Siege Gate Maze.
## Tests:
## 1. Lever toggling and path highlights
## 2. March sequence execution with live tweens
## 3. Victory on optimal path (+10 -> -8x3 = 42 >= 40)
## 4. Signal emission
## Run: & "C:\GoDot\Godot_v4.5.1-stable_win64_console.exe" --headless --path "c:\MathKnight\math-knight" -s "res://scripts/test_siege_gate_interactive.gd"


func _init() -> void:
	print("\n" + "=".repeat(60))
	print("  SIEGE GATE MAZE — RUNTIME SIMULATION TEST")
	print("=".repeat(60))

	_run_simulation()


func _run_simulation() -> void:
	# Load scene
	var scene: PackedScene = load("res://scenes/siege/SiegeGateMaze.tscn")
	var maze: SiegeGateMaze = scene.instantiate()
	root.add_child(maze)

	# Load sketch level (Level 0)
	maze.load_level_by_index(0)
	print("  Loaded Level: %s" % maze.level_data.level_name)

	# In Level 0:
	# Stage 0: 1 lever. Choice 0 = x2, Choice 1 = +10.
	# Stage 1: Lever 0 (top) has Choice 0 = -5x2, Choice 1 = +20/3.
	#          Lever 1 (bottom) has Choice 0 = +20/3, Choice 1 = -8x3.

	# Switch Stage 0 lever to Choice 1 (+10)
	print("  Toggling Stage 0 lever to Choice 1 (+10)...")
	var stage0_lever: GateLever = maze.stage_levers[0][0]
	stage0_lever.set_path(1, false)
	maze._on_branch_lever_switched(0, 1, 0, 0)

	# Switch Stage 1 Lever 1 (bottom) to Choice 1 (-8x3)
	print("  Toggling Stage 1 bottom lever to Choice 1 (-8 x3)...")
	var stage1_bot_lever: GateLever = maze.stage_levers[1][1]
	stage1_bot_lever.set_path(1, false)
	maze._on_branch_lever_switched(101, 1, 1, 1)

	# Start March!
	print("  Starting March sequence (animated across channels)...")
	maze._on_march_pressed()

	# Await puzzle completion signal
	var results: Array = await maze.puzzle_completed
	var count: int = results[0]
	var defense: int = results[1]
	var is_victory: bool = results[2]
	var stars: int = results[3]

	print("\n  --- SIMULATION RESULTS ---")
	print("  Final soldiers: %d (expected 42)" % count)
	print("  Castle defense: %d" % defense)
	print("  Victory achieved: %s" % str(is_victory))
	print("  Stars awarded: %d" % stars)

	if count == 42 and is_victory and stars == 3:
		print("  🎉 PERFECT: Optimal path (+10 -> -8x3 = 42) conquered the castle with 3 stars!\n")
		maze.queue_free()
		quit(0)
	else:
		print("  ❌ FAILED: Unexpected outcome")
		maze.queue_free()
		quit(1)
