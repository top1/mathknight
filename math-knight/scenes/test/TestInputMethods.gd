extends Node2D

func _ready() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("=== RUNNING FULL GAMEPLAY & INPUT METHODS INTEGRATION TEST ===")
	
	var main_scene: PackedScene = load("res://scenes/main/Main.tscn")
	assert(main_scene != null, "Main.tscn should load")
	
	var input_types = [
		MathConfig.InputType.BUBBLES,
		MathConfig.InputType.HANDWRITING,
		MathConfig.InputType.QUICK_TAP,
		MathConfig.InputType.HOLD_STRETCH,
		MathConfig.InputType.TIMING_BAR,
		MathConfig.InputType.NUMBER_WHEEL,
		MathConfig.InputType.KEYPAD
	]
	
	var input_names = ["BUBBLES", "HANDWRITING", "QUICK_TAP", "HOLD_STRETCH", "TIMING_BAR", "NUMBER_WHEEL", "KEYPAD"]
	
	for i in range(input_types.size()):
		var inp = input_types[i]
		var inp_name = input_names[i]
		var cfg = MathConfig.create_config(MathConfig.GameMode.TASK_TO_RESULT, MathConfig.Operation.ADDITION, MathConfig.Difficulty.EASY, inp)
		MathEngine.set_difficulty(cfg)
		
		print("Testing InputType: %s" % inp_name)
		var main_instance = main_scene.instantiate()
		add_child(main_instance)
		
		# Generate and present a problem
		var prob = MathEngine.generate_problem(cfg)
		EventBus.problem_presented.emit(prob)
		
		# Ensure input area is initialized
		var input_area = main_instance.get_node("InputAreaContainer/InputArea")
		assert(input_area != null, "InputArea should exist")
		
		if inp != MathConfig.InputType.BUBBLES:
			assert(input_area.active_custom_method != null, "Active custom method should be instantiated")
		
		# Simulate submitting an answer
		EventBus.answer_selected.emit(prob.correct_answer, "test", null, Vector2.ZERO)
		
		main_instance.queue_free()
		print("  -> %s Passed!" % inp_name)
	
	print("=== ALL INPUT METHOD INTEGRATION TESTS PASSED SUCCESSFULLY! ===")
	get_tree().quit(0)
