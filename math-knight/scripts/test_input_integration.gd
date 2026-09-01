extends SceneTree

const InputMethodBaseScript = preload("res://scenes/ui/input_methods/InputMethodBase.gd")
const MathProblemScript = preload("res://scripts/resources/MathProblem.gd")
const MathConfigScript = preload("res://scripts/resources/MathConfig.gd")

func _init() -> void:
	print("=== RUNNING INPUT METHODS UNIT & INTEGRATION TEST ===")
	
	var problem = MathProblemScript.new()
	problem.operand_a = 7
	problem.operand_b = 5
	problem.operator_symbol = "+"
	problem.correct_answer = 12
	var c: Array[int] = [12, 10, 14, 15]
	problem.choices = c
	
	var methods = [
		{"name": "Handwriting", "scene": "res://scenes/ui/input_methods/HandwritingInputMethod.tscn"},
		{"name": "QuickTap", "scene": "res://scenes/ui/input_methods/QuickTapInputMethod.tscn"},
		{"name": "HoldStretch", "scene": "res://scenes/ui/input_methods/HoldStretchInputMethod.tscn"},
		{"name": "TimingBar", "scene": "res://scenes/ui/input_methods/TimingBarInputMethod.tscn"},
		{"name": "NumberWheel", "scene": "res://scenes/ui/input_methods/NumberWheelInputMethod.tscn"},
		{"name": "Keypad", "scene": "res://scenes/ui/input_methods/KeypadInputMethod.tscn"}
	]
	
	for m in methods:
		var scene_res: PackedScene = load(m.scene)
		assert(scene_res != null, "Scene %s should load" % m.name)
		var instance = scene_res.instantiate()
		assert(instance != null, "Instance should not be null")
		root.add_child(instance)
		
		# Test problem presentation
		instance.on_problem_presented(problem)
		assert(instance.is_active, "%s should be active" % m.name)
		
		# Test mouse input event simulation on handwriting
		if m.name == "Handwriting":
			var mouse_down = InputEventMouseButton.new()
			mouse_down.button_index = MOUSE_BUTTON_LEFT
			mouse_down.pressed = true
			mouse_down.position = Vector2(320, 70)
			instance._input(mouse_down)
			assert(instance.is_drawing, "Handwriting should be drawing on mouse down")
			
			var mouse_move = InputEventMouseMotion.new()
			mouse_move.position = Vector2(320, 100)
			instance._input(mouse_move)
			assert(instance.current_stroke.size() >= 2, "Handwriting should have stroke points on mouse move")
			
			var mouse_up = InputEventMouseButton.new()
			mouse_up.button_index = MOUSE_BUTTON_LEFT
			mouse_up.pressed = false
			mouse_up.position = Vector2(320, 100)
			instance._input(mouse_up)
			assert(not instance.is_drawing, "Handwriting should stop drawing on mouse up")

		# Test mouse tap on QuickTap
		if m.name == "QuickTap":
			var tap_event = InputEventMouseButton.new()
			tap_event.button_index = MOUSE_BUTTON_LEFT
			tap_event.pressed = true
			tap_event.position = Vector2(320, 70)
			instance._input(tap_event)
			assert(instance.current_count == 1, "QuickTap should increment count to 1 on mouse click")
			
			# Simulate next human tap (>40ms later)
			instance.last_tap_time_msec = 0
			instance._input(tap_event)
			assert(instance.current_count == 2, "QuickTap should increment count to 2 on second mouse click")
		
		# Test mouse input event simulation on HoldStretch
		if m.name == "HoldStretch":
			var mouse_down = InputEventMouseButton.new()
			mouse_down.button_index = MOUSE_BUTTON_LEFT
			mouse_down.pressed = true
			mouse_down.position = Vector2(320, 70)
			instance._input(mouse_down)
			assert(instance.is_holding, "HoldStretch should be holding on mouse down")
			
			var mouse_move = InputEventMouseMotion.new()
			mouse_move.position = Vector2(400, 120)
			instance._input(mouse_move)
			assert(instance.calculated_val > 0, "HoldStretch should calculate value on drag")
			
			var mouse_up = InputEventMouseButton.new()
			mouse_up.button_index = MOUSE_BUTTON_LEFT
			mouse_up.pressed = false
			mouse_up.position = Vector2(400, 120)
			instance._input(mouse_up)
			assert(not instance.is_holding, "HoldStretch should release on mouse up")
		
		# Test answer emission signal via dictionary closure capture
		var result = {"val": -1, "method": ""}
		instance.answer_submitted.connect(func(val: int, method_name: String, _extra: Dictionary):
			result["val"] = val
			result["method"] = method_name
		)
		
		instance.submit_answer(12, m.name)
		assert(result["val"] == 12, "%s should submit 12" % m.name)
		
		# Test feedback hooks
		instance.on_answer_evaluated(true)
		instance.on_answer_evaluated(false)
		
		instance.clean_up()
		instance.queue_free()
		print("  -> %s InputMethod: PASSED" % m.name)
	
	print("=== ALL INPUT METHOD INTEGRATION TESTS PASSED SUCCESSFULLY! ===")
	quit(0)
