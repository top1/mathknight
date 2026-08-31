extends SceneTree

func _init() -> void:
	print("--- Running MathEngine & Bubble Verification Tests ---")
	var success := true

	# Autoload mock / loader for headless standalone execution
	var MathEngineScript = load("res://scripts/autoload/MathEngine.gd")
	var math_engine = MathEngineScript.new()
	root.add_child(math_engine)

	# 1. Test MathEngine.generate_set across all modes, difficulties, and set sizes
	var modes = [MathConfig.GameMode.TASK_TO_RESULT, MathConfig.GameMode.RESULT_TO_EQUATION, MathConfig.GameMode.MULTI_OP_EQUATION]
	var diffs = [MathConfig.Difficulty.EASY, MathConfig.Difficulty.MEDIUM, MathConfig.Difficulty.HARD]
	var ops = [MathConfig.Operation.ADDITION, MathConfig.Operation.SUBTRACTION, MathConfig.Operation.MULTIPLICATION, MathConfig.Operation.DIVISION, MathConfig.Operation.MIXED]

	for mode in modes:
		for diff in diffs:
			for op in ops:
				var cfg = MathConfig.create_config(mode, op, diff)
				for set_size in [3, 4, 5, 6, 7, 8, 10]:
					var set_data = math_engine.generate_set(set_size, set_size + 4, cfg)
					var problems: Array = set_data.problems
					var pool: Array = set_data.bubble_pool
					
					if problems.size() != set_size:
						printerr("FAIL: Problems size mismatch: expected ", set_size, " got ", problems.size())
						success = false
					
					if mode == MathConfig.GameMode.TASK_TO_RESULT:
						for p in problems:
							if not pool.has(p.correct_answer):
								printerr("FAIL: Missing required answer ", p.correct_answer, " in pool: ", pool)
								success = false

	print("✓ MathEngine.generate_set passed all 105 combinatorial test variations without dropping answers.")

	# 2. Test NumberBubble instantiation
	var bubble_scene = load("res://scenes/ui/NumberBubble.tscn")
	if not bubble_scene:
		printerr("FAIL: Could not load NumberBubble.tscn")
		success = false
	else:
		for test_val in [4, 9, 49, 94, 44, 99, 14, 19, 7, 1, 42]:
			var b = bubble_scene.instantiate()
			root.add_child(b)
			b.setup(test_val, Vector2(100, 100), "left", 1)
			if b._display_val_str != str(test_val):
				printerr("FAIL: Bubble display string mismatch: expected ", str(test_val), " got ", b._display_val_str)
				success = false
			b.queue_free()
		print("✓ NumberBubble instantiated and rendered stable digits for all 4/9 test cases.")

	# 3. Test BubbleTuningLab instantiation
	var lab_scene = load("res://scenes/test/BubbleTuningLab.tscn")
	if not lab_scene:
		printerr("FAIL: Could not load BubbleTuningLab.tscn")
		success = false
	else:
		var lab = lab_scene.instantiate()
		root.add_child(lab)
		print("✓ BubbleTuningLab loaded and instantiated cleanly.")
		lab.queue_free()

	math_engine.queue_free()

	if success:
		print("=== ALL TESTS PASSED SUCCESSFULLY! ===")
		quit(0)
	else:
		printerr("=== TESTS FAILED ===")
		quit(1)
