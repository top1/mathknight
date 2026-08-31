@tool
extends SceneTree

func _init() -> void:
	print("--- STARTING BUBBLE FIXES & MATH SOLVABILITY VERIFICATION ---")
	var success := true

	var MathEngineScript = load("res://scripts/autoload/MathEngine.gd")
	var math_engine = MathEngineScript.new()
	root.add_child(math_engine)

	# Test 1: MathEngine generate_set for Mode 1, Mode 2, Mode 3 across various sizes
	var modes = [MathConfig.GameMode.TASK_TO_RESULT, MathConfig.GameMode.RESULT_TO_EQUATION, MathConfig.GameMode.MULTI_OP_EQUATION]
	var diffs = [MathConfig.Difficulty.EASY, MathConfig.Difficulty.MEDIUM, MathConfig.Difficulty.HARD]

	for mode in modes:
		for diff in diffs:
			var cfg = MathConfig.create_config(mode, MathConfig.Operation.ADDITION, diff)
			# Test with 3, 5, 8, 10 problems (stages 1 to 12)
			for set_size in [3, 5, 8, 10]:
				var set_data = math_engine.generate_set(set_size, set_size + 4, cfg)
				var problems: Array = set_data.problems
				var pool: Array = set_data.bubble_pool
				if problems.size() != set_size:
					print("FAIL: Problem count mismatch! Expected ", set_size, " got ", problems.size())
					success = false
				
				if mode == MathConfig.GameMode.TASK_TO_RESULT:
					for p in problems:
						if not pool.has(p.correct_answer):
							print("FAIL: Pool missing answer for problem: ", p.question_text, " ans: ", p.correct_answer, " in pool: ", pool)
							success = false

	print("✓ MathEngine.generate_set tested across all modes, difficulties, and wave sizes (3 to 10).")

	# Test 2: Verify NumberBubble scene instantiation and font loading
	var bubble_scene = load("res://scenes/ui/NumberBubble.tscn")
	if not bubble_scene:
		print("FAIL: Could not load NumberBubble.tscn")
		success = false
	else:
		var b = bubble_scene.instantiate()
		root.add_child(b)
		b.setup(49, Vector2(100, 100), "left", 1)
		if b._display_val_str != "49":
			print("FAIL: Bubble display string mismatch: ", b._display_val_str)
			success = false
		b.queue_free()
		print("✓ NumberBubble scene instantiated and setup cleanly with stable digits.")

	# Test 3: Verify BubbleTuningLab scene loads
	var lab_scene = load("res://scenes/test/BubbleTuningLab.tscn")
	if not lab_scene:
		print("FAIL: Could not load BubbleTuningLab.tscn")
		success = false
	else:
		var lab = lab_scene.instantiate()
		root.add_child(lab)
		print("✓ BubbleTuningLab instantiated and initialized successfully.")
		lab.queue_free()

	# Test 4: Verify InputArea solvability guarantee
	var input_area_scene = load("res://scenes/ui/InputArea.tscn")
	if not input_area_scene:
		print("FAIL: Could not load InputArea.tscn")
		success = false
	else:
		var ia = input_area_scene.instantiate()
		root.add_child(ia)
		# Initialize with choices that DO NOT include answer 42
		ia.show_choices([1, 2, 3, 4])
		# Now present problem needing 42
		var prob = MathProblem.new()
		prob.operand_a = 40
		prob.operand_b = 2
		prob.correct_answer = 42
		prob.question_text = "40+2"
		ia._on_problem_presented(prob)
		
		# Check if 42 is now present in active_bubbles
		var found_42 = false
		for b in ia.active_bubbles:
			if is_instance_valid(b) and b.value == 42:
				found_42 = true
				break
		if not found_42:
			print("FAIL: InputArea failed to replenish missing answer 42!")
			success = false
		else:
			print("✓ InputArea guaranteed solvability check successfully replenished missing answer 42.")
		ia.queue_free()

	math_engine.queue_free()

	if success:
		print("=== ALL VERIFICATION TESTS PASSED SUCCESSFULLY! ===")
	else:
		print("=== SOME TESTS FAILED! ===")

	quit(0 if success else 1)
