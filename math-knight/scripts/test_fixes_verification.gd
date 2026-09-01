extends SceneTree

const MathProblemScript = preload("res://scripts/resources/MathProblem.gd")
const MathConfigScript = preload("res://scripts/resources/MathConfig.gd")

func _init() -> void:
	print("\n========================================================")
	print("🧪 RUNNING COMPREHENSIVE VERIFICATION FOR ALL 5 FIXES")
	print("========================================================\n")
	
	test_keypad_input()
	test_timing_bar_randomization()
	test_hold_stretch_fixes()
	test_chest_lockpicking()
	
	print("\n========================================================")
	print("🎉 ALL 5 FIXES & FEATURES VERIFIED SUCCESSFULLY!")
	print("========================================================\n")
	quit(0)


func test_keypad_input() -> void:
	print("--- TEST 1: Keypad Touch Input & Digit Buffering ---")
	var keypad_scene = load("res://scenes/ui/input_methods/KeypadInputMethod.tscn")
	var keypad = keypad_scene.instantiate()
	root.add_child(keypad)
	
	var prob = MathProblemScript.new()
	prob.correct_answer = 42
	keypad.on_problem_presented(prob)
	
	var submitted_answer: int = -999
	keypad.answer_submitted.connect(func(ans, _method, _extra): submitted_answer = ans)
	
	# Press "4"
	var btn4 = keypad.get_node("GridContainer/Btn4") as Button
	assert(btn4 != null, "Btn4 must exist")
	keypad._on_key_pressed(btn4.text)
	assert(keypad.digit_buffer == "4", "Buffer should be '4' after pressing 4, got: " + keypad.digit_buffer)
	
	# Press "2" (should auto-commit 42 because length of abs(42) is 2)
	var btn2 = keypad.get_node("GridContainer/Btn2") as Button
	keypad._on_key_pressed(btn2.text)
	assert(submitted_answer == 42, "Submitted answer should be 42, got: " + str(submitted_answer))
	
	# Test Clear button
	keypad.digit_buffer = "7"
	var btn_clear = keypad.get_node("GridContainer/BtnClear") as Button
	keypad._on_key_pressed(btn_clear.text)
	assert(keypad.digit_buffer == "", "Buffer should be empty after clear, got: " + keypad.digit_buffer)
	
	# Test OK button
	keypad.digit_buffer = "9"
	var btn_ok = keypad.get_node("GridContainer/BtnOK") as Button
	keypad._on_key_pressed(btn_ok.text)
	assert(submitted_answer == 9, "Submitted answer should be 9 after OK, got: " + str(submitted_answer))
	
	keypad.queue_free()
	print("  [PASS] Keypad button connections, digit buffering, clear, and OK work perfectly!")


func test_timing_bar_randomization() -> void:
	print("\n--- TEST 2: Timing Bar Answer Position Randomization ---")
	var timing_scene = load("res://scenes/ui/input_methods/TimingBarInputMethod.tscn")
	var timing = timing_scene.instantiate()
	root.add_child(timing)
	
	var index_counts: Dictionary = {}
	var total_runs = 60
	
	for i in range(total_runs):
		var prob = MathProblemScript.new()
		prob.correct_answer = randi_range(10, 50)
		timing.on_problem_presented(prob)
		
		var ans_idx = timing.numbers_pool.find(prob.correct_answer)
		assert(ans_idx != -1, "Correct answer must be present in timing bar candidates")
		index_counts[ans_idx] = index_counts.get(ans_idx, 0) + 1
	
	print("  Distribution of answer positions over %d runs:" % total_runs)
	for idx in index_counts.keys():
		print("    Slot Index %d: %d times (%.1f%%)" % [idx, index_counts[idx], (float(index_counts[idx])/total_runs)*100.0])
	
	assert(index_counts.keys().size() >= 3, "Answer should appear at varied slots, got only %d distinct slots" % index_counts.keys().size())
	
	timing.queue_free()
	print("  [PASS] Timing bar correct answer is well randomized across notches and not fixed in the center!")


func test_hold_stretch_fixes() -> void:
	print("\n--- TEST 3: Hold & Stretch (Snap to Grid, Hidden Result, Locked Dimension) ---")
	var hs_scene = load("res://scenes/ui/input_methods/HoldStretchInputMethod.tscn")
	var hs = hs_scene.instantiate()
	root.add_child(hs)
	
	# Test 1: Completely open 2D equation (no fixed dimension)
	var prob_open = MathProblemScript.new()
	prob_open.operator_symbol = "+"
	prob_open.correct_answer = 12
	prob_open.given_operand_index = -1
	
	var cfg = MathConfigScript.new()
	cfg.game_mode = MathConfigScript.GameMode.RESULT_TO_EQUATION
	hs.setup(cfg)
	hs.on_problem_presented(prob_open)
	
	assert(hs.is_2d_mode == true, "HoldStretch should be in 2D mode for RESULT_TO_EQUATION")
	assert(hs.locked_dimension == -1, "Locked dimension should be -1 for open problem")
	
	# Simulate drag
	hs.is_holding = true
	hs.anchor_pos = Vector2(100, 100)
	hs.current_pos = Vector2(100 + (3 * hs.STEP_X), 100 + (4 * hs.STEP_Y))
	hs._update_stretch_values()
	
	assert(hs.val_x == 3, "val_x should snap to 3")
	assert(hs.val_y == 4, "val_y should snap to 4")
	assert(hs.calculated_val == 7, "calculated_val should be 7")
	
	var label_text = hs.value_label.text
	print("  Open equation label preview: '%s'" % label_text)
	assert(not label_text.contains("= 7") and not label_text.contains("=7"), "Label must not show calculated result (= 7)")
	assert(label_text.contains("[ 3 ]") and label_text.contains("[ 4 ]"), "Label should show operands [ 3 ] and [ 4 ]")
	
	# Test 2: Fixed Operand A (given_operand_index == 0, e.g. 5 + x = 12)
	var prob_fixed_a = MathProblemScript.new()
	prob_fixed_a.operand_a = 5
	prob_fixed_a.operand_b = 7
	prob_fixed_a.operator_symbol = "+"
	prob_fixed_a.correct_answer = 12
	prob_fixed_a.given_operand_index = 0
	
	hs.on_problem_presented(prob_fixed_a)
	assert(hs.locked_dimension == 0, "Dimension X should be locked when given_operand_index == 0")
	assert(hs.locked_val_x == 5, "locked_val_x should be 5")
	
	hs.is_holding = true
	hs.anchor_pos = Vector2(100, 100)
	hs.current_pos = Vector2(100 + (10 * hs.STEP_X), 100 + (7 * hs.STEP_Y))
	hs._update_stretch_values()
	
	assert(hs.val_x == 5, "val_x must remain locked to 5 despite dragging X to 10")
	assert(hs.val_y == 7, "val_y should be 7 from Y drag")
	assert(hs.calculated_val == 12, "calculated_val should be 5 + 7 = 12")
	
	var locked_label = hs.value_label.text
	print("  Fixed operand label preview: '%s'" % locked_label)
	assert(not locked_label.contains("= 12"), "Label must not show calculated result (= 12)")
	assert(locked_label.contains("[ 5 🔒 ]") or locked_label.contains("5"), "Label should show locked component 5")
	
	hs.queue_free()
	print("  [PASS] Hold & Stretch integer snapping, hidden result display, and dimension locking verified!")


func test_chest_lockpicking() -> void:
	print("\n--- TEST 4: Lock-Picking Chest Minigame ---")
	var chest_scene = load("res://scenes/ui/ChestReward.tscn")
	var chest_screen = chest_scene.instantiate()
	root.add_child(chest_screen)
	
	# Verify pin scaling
	assert(chest_screen._get_pins_for_quality("bronze") == 2, "Bronze chest should have 2 pins")
	assert(chest_screen._get_pins_for_quality("silver") == 3, "Silver chest should have 3 pins")
	assert(chest_screen._get_pins_for_quality("gold") == 4, "Gold chest should have 4 pins")
	assert(chest_screen._get_pins_for_quality("legendary") == 5, "Legendary chest should have 5 pins")
	
	# Start challenge on a Silver chest (3 pins)
	var test_chests: Array[Dictionary] = [{"quality": "silver", "opened": false, "failed": false}]
	chest_screen._chests = test_chests
	chest_screen._start_chest_challenge(0)
	
	assert(chest_screen._is_lockpicking == true, "Lockpicking should be active")
	assert(chest_screen._total_pins == 3, "Total pins should be 3 for silver")
	assert(chest_screen._current_pin_idx == 0, "Current pin should start at 0")
	assert(chest_screen._pin_panels.size() == 3, "Should have 3 pin panels rendered")
	
	# Pin 1 solve
	var dummy_btn = Button.new()
	var ans1 = chest_screen._active_problem.correct_answer
	chest_screen._evaluate_pin_answer(ans1, dummy_btn)
	assert(chest_screen._current_pin_idx == 1, "Pin index should advance to 1 after solving pin 1")
	
	# Pin 2 solve
	chest_screen._present_pin_problem()
	var ans2 = chest_screen._active_problem.correct_answer
	chest_screen._evaluate_pin_answer(ans2, dummy_btn)
	assert(chest_screen._current_pin_idx == 2, "Pin index should advance to 2 after solving pin 2")
	
	# Pin 3 solve (final pin -> opens chest!)
	chest_screen._present_pin_problem()
	var ans3 = chest_screen._active_problem.correct_answer
	chest_screen._evaluate_pin_answer(ans3, dummy_btn)
	
	assert(chest_screen._is_lockpicking == false, "Lockpicking should end upon solving all pins")
	assert(chest_screen._chests[0]["opened"] == true, "Chest should be marked opened")
	assert(chest_screen.result_label.text.contains("SCHLOSS GEKNACKT"), "Result label should announce lock picked")
	
	dummy_btn.free()
	chest_screen.queue_free()
	print("  [PASS] Lock-Picking Minigame pins progression, scaling, and reward unlock verified!")



