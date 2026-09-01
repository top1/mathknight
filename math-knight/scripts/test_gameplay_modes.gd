extends SceneTree

func _init() -> void:
	print("=== RUNNING FULL GAMEPLAY & INPUT METHODS INTEGRATION TEST ===")
	
	var main_scene: PackedScene = load("res://scenes/main/Main.tscn")
	assert(main_scene != null, "Main.tscn should load")
	
	var math_config_script = load("res://scripts/resources/MathConfig.gd")
	var math_engine = root.get_node("/root/MathEngine")
	var event_bus = root.get_node("/root/EventBus")
	
	var input_types = [
		math_config_script.InputType.BUBBLES,
		math_config_script.InputType.HANDWRITING,
		math_config_script.InputType.QUICK_TAP,
		math_config_script.InputType.HOLD_STRETCH,
		math_config_script.InputType.TIMING_BAR,
		math_config_script.InputType.NUMBER_WHEEL,
		math_config_script.InputType.KEYPAD
	]
	
	var input_names = ["BUBBLES", "HANDWRITING", "QUICK_TAP", "HOLD_STRETCH", "TIMING_BAR", "NUMBER_WHEEL", "KEYPAD"]
	
	for i in range(input_types.size()):
		var inp = input_types[i]
		var inp_name = input_names[i]
		var cfg = math_config_script.create_config(math_config_script.GameMode.TASK_TO_RESULT, math_config_script.Operation.ADDITION, math_config_script.Difficulty.EASY, inp)
		math_engine.set_difficulty(cfg)
		
		print("Testing InputType: %s" % inp_name)
		var main_instance = main_scene.instantiate()
		root.add_child(main_instance)
		
		# Generate and present a problem
		var prob = math_engine.generate_problem(cfg)
		event_bus.problem_presented.emit(prob)
		
		# Ensure input area is initialized
		var input_area = main_instance.get_node("InputAreaContainer/InputArea")
		assert(input_area != null, "InputArea should exist")
		
		if inp != math_config_script.InputType.BUBBLES:
			assert(input_area.active_custom_method != null, "Active custom method should be instantiated")
		
		# Simulate submitting an answer
		event_bus.answer_selected.emit(prob.correct_answer, "test", null, Vector2.ZERO)
		
		main_instance.queue_free()
		print("  -> Passed!")
	
	print("=== ALL INPUT METHOD INTEGRATION TESTS PASSED SUCCESSFULLY! ===")
	quit(0)
