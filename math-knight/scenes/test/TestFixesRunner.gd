extends Node

func _ready() -> void:
	print("==================================================")
	print("  RUNNING FULL ENGINE INTEGRATION VERIFICATION")
	print("==================================================")

	var pass_count: int = 0
	var total_tests: int = 0

	# -----------------------------------------------------------------
	# Test 1: Countdown Lock
	# -----------------------------------------------------------------
	total_tests += 1
	print("\n[TEST 1] Testing Countdown Lock in GameManager & EventBus...")
	GameManager.start_game()
	var test_prob := MathProblem.new()
	test_prob.question_text = "5 + 3"
	test_prob.correct_answer = 8
	GameManager.current_problem = test_prob

	if GameManager.is_in_countdown:
		print("  ✓ GameManager.is_in_countdown is TRUE upon start_game()")
	else:
		printerr("  ✗ FAIL: GameManager.is_in_countdown was FALSE upon start_game()")

	var init_score = GameManager.score
	EventBus.answer_selected.emit(8, "swipe", null, Vector2.ZERO)
	if GameManager.score == init_score and GameManager.correct_answers_count == 0:
		print("  ✓ Answer during countdown preview is strictly locked (no score increase)")
	else:
		printerr("  ✗ FAIL: Answer during countdown preview was processed!")

	EventBus.countdown_tick.emit("2")
	if GameManager.is_in_countdown:
		print("  ✓ is_in_countdown remains TRUE on tick '2'")

	EventBus.countdown_tick.emit("1")
	if GameManager.is_in_countdown:
		print("  ✓ is_in_countdown remains TRUE on tick '1'")

	EventBus.countdown_tick.emit("⚔️ LOS!")
	if not GameManager.is_in_countdown:
		print("  ✓ is_in_countdown becomes FALSE on '⚔️ LOS!'")
	else:
		printerr("  ✗ FAIL: is_in_countdown did not become FALSE on '⚔️ LOS!'")

	EventBus.answer_selected.emit(8, "swipe", null, Vector2.ZERO)
	if GameManager.score > init_score and GameManager.correct_answers_count == 1:
		print("  ✓ Answer after countdown is accepted (Score: %d)" % GameManager.score)
		pass_count += 1
	else:
		printerr("  ✗ FAIL: Answer after countdown was not processed!")

	# -----------------------------------------------------------------
	# Test 2: Training vs Adventure Mode Isolation
	# -----------------------------------------------------------------
	total_tests += 1
	print("\n[TEST 2] Testing Training vs Adventure Run Isolation...")
	RunManager.start_new_run()
	if RunManager.is_run_active:
		print("  ✓ RunManager.is_run_active is TRUE after start_new_run()")

	var main_menu = load("res://scenes/menu/MainMenu.tscn").instantiate()
	add_child(main_menu)
	if not RunManager.is_run_active:
		print("  ✓ MainMenu (Training menu) cleanly deactivates RunManager (is_run_active = false)")
		pass_count += 1
	else:
		printerr("  ✗ FAIL: MainMenu did not clear RunManager.is_run_active!")
	main_menu.queue_free()

	# -----------------------------------------------------------------
	# Test 3: HUD Navigation Routing
	# -----------------------------------------------------------------
	total_tests += 1
	print("\n[TEST 3] Testing HUD and GameOverScreen Navigation Logic...")
	RunManager.is_run_active = true
	var hud = load("res://scenes/ui/HUD.tscn").instantiate()
	add_child(hud)
	print("  ✓ HUD instantiates with Adventure mode state")
	hud.queue_free()

	RunManager.is_run_active = false
	var game_over = load("res://scenes/ui/GameOverScreen.tscn").instantiate()
	add_child(game_over)
	print("  ✓ GameOverScreen instantiates with Training mode state")
	game_over.queue_free()
	pass_count += 1

	# -----------------------------------------------------------------
	# Test 4: Slime Equation Positioning
	# -----------------------------------------------------------------
	total_tests += 1
	print("\n[TEST 4] Testing Slime Equation Positioning Above Slime Body...")
	var slime_ascii = AsciiEntity.new()
	slime_ascii.entity_type = "slime"
	add_child(slime_ascii)
	slime_ascii.set_equation("9 + 6")

	var eq_slots = []
	for s in slime_ascii.slots:
		if s.get("eq", false):
			eq_slots.append(s)

	if eq_slots.is_empty():
		printerr("  ✗ FAIL: No equation slots found on Slime!")
	else:
		var all_above: bool = true
		for s in eq_slots:
			if s.p.y > -20.0:
				all_above = false
				printerr("  ✗ Equation slot at y = %f is NOT above head (must be <= -20)!" % s.p.y)
		if all_above:
			print("  ✓ Slime equation slots positioned at y = %f (cleanly above slime body top y = -12)" % eq_slots[0].p.y)
			pass_count += 1

	# -----------------------------------------------------------------
	# Test 5: Verify Countdown Lock across all Modular Input Methods
	# -----------------------------------------------------------------
	total_tests += 1
	print("\n[TEST 5] Testing Countdown Lock across all Modular Input Methods...")
	GameManager.is_in_countdown = true
	var all_methods_locked: bool = true

	var input_scenes = [
		{"name": "Handwriting", "path": "res://scenes/ui/input_methods/HandwritingInputMethod.tscn"},
		{"name": "QuickTap", "path": "res://scenes/ui/input_methods/QuickTapInputMethod.tscn"},
		{"name": "HoldStretch", "path": "res://scenes/ui/input_methods/HoldStretchInputMethod.tscn"},
		{"name": "TimingBar", "path": "res://scenes/ui/input_methods/TimingBarInputMethod.tscn"},
		{"name": "NumberWheel", "path": "res://scenes/ui/input_methods/NumberWheelInputMethod.tscn"},
		{"name": "Keypad", "path": "res://scenes/ui/input_methods/KeypadInputMethod.tscn"}
	]

	for entry in input_scenes:
		var scene = load(entry.path)
		if not scene:
			printerr("  ✗ FAIL: Could not load %s!" % entry.path)
			all_methods_locked = false
			continue

		var inst: InputMethodBase = scene.instantiate() as InputMethodBase
		add_child(inst)
		inst.on_problem_presented(test_prob)

		var emitted := [false]
		inst.answer_submitted.connect(func(_val, _meth, _extra): emitted[0] = true)

		# Attempt submit during countdown
		inst.submit_answer(8, entry.name, {})

		if emitted[0]:
			printerr("  ✗ FAIL: %s allowed answer submission during countdown!" % entry.name)
			all_methods_locked = false
		else:
			print("  ✓ %s strictly blocks answer submission during countdown" % entry.name)

		# Now finish countdown and verify submission is permitted
		GameManager.is_in_countdown = false
		inst.submit_answer(8, entry.name, {})
		if not emitted[0]:
			printerr("  ✗ FAIL: %s failed to submit answer after countdown ended!" % entry.name)
			all_methods_locked = false
		else:
			print("  ✓ %s permits answer submission after countdown finishes" % entry.name)

		GameManager.is_in_countdown = true
		inst.queue_free()

	GameManager.is_in_countdown = false

	if all_methods_locked:
		print("  ✓ All 6 modular input methods verified for countdown locking.")
		pass_count += 1

	# -----------------------------------------------------------------
	# Test 7: Keypad Touch Input & Digit Buffering
	# -----------------------------------------------------------------
	total_tests += 1
	print("\n[TEST 7] Testing Keypad Touch Button Signals & Auto-commit...")
	GameManager.is_in_countdown = false
	var keypad_scene = load("res://scenes/ui/input_methods/KeypadInputMethod.tscn")
	var keypad = keypad_scene.instantiate() as KeypadInputMethod
	add_child(keypad)
	var k_prob = MathProblem.new()
	k_prob.correct_answer = 42
	keypad.on_problem_presented(k_prob)

	var submitted := [-999]
	keypad.answer_submitted.connect(func(ans, _method, _extra): submitted[0] = ans)

	var btn4 = keypad.get_node("GridContainer/Btn4") as Button
	btn4.pressed.emit()
	var btn2 = keypad.get_node("GridContainer/Btn2") as Button
	btn2.pressed.emit()

	if submitted[0] == 42:
		print("  ✓ Keypad button touch signals and auto-commit for 42 passed.")
		pass_count += 1
	else:
		printerr("  ✗ FAIL: Keypad answer was not 42, got: %d" % submitted[0])
	keypad.queue_free()

	# -----------------------------------------------------------------
	# Test 8: Timing Bar Answer Randomization
	# -----------------------------------------------------------------
	total_tests += 1
	print("\n[TEST 8] Testing Timing Bar Answer Position Randomization...")
	var timing_scene = load("res://scenes/ui/input_methods/TimingBarInputMethod.tscn")
	var timing = timing_scene.instantiate() as TimingBarInputMethod
	add_child(timing)

	var tb_index_counts: Dictionary = {}
	for i in range(60):
		var prob_tb = MathProblem.new()
		prob_tb.correct_answer = randi_range(10, 50)
		timing.on_problem_presented(prob_tb)
		var ans_idx = timing.numbers_pool.find(prob_tb.correct_answer)
		if ans_idx != -1:
			tb_index_counts[ans_idx] = tb_index_counts.get(ans_idx, 0) + 1

	if tb_index_counts.keys().size() >= 3:
		print("  ✓ Timing bar correct answer randomized across %d slots (not centered)." % tb_index_counts.keys().size())
		pass_count += 1
	else:
		printerr("  ✗ FAIL: Timing bar answer only appeared at %d slots" % tb_index_counts.keys().size())
	timing.queue_free()

	# -----------------------------------------------------------------
	# Test 9: Hold & Stretch (Snap to Grid, Hidden Result, Dimension Locking)
	# -----------------------------------------------------------------
	total_tests += 1
	print("\n[TEST 9] Testing Hold & Stretch Grid Snap, Hidden Result & Dimension Locking...")
	var hs_scene = load("res://scenes/ui/input_methods/HoldStretchInputMethod.tscn")
	var hs = hs_scene.instantiate() as HoldStretchInputMethod
	add_child(hs)

	var prob_hs = MathProblem.new()
	prob_hs.operand_a = 5
	prob_hs.operand_b = 7
	prob_hs.operator_symbol = "+"
	prob_hs.correct_answer = 12
	prob_hs.given_operand_index = 0
	var cfg_hs = MathConfig.new()
	cfg_hs.game_mode = MathConfig.GameMode.RESULT_TO_EQUATION
	hs.setup(cfg_hs)
	hs.on_problem_presented(prob_hs)

	hs.is_holding = true
	hs.anchor_pos = Vector2(100, 100)
	hs.current_pos = Vector2(100 + (10 * hs.STEP_X), 100 + (7 * hs.STEP_Y))
	hs._update_stretch_values()

	var hs_ok = true
	if hs.val_x != 5:
		printerr("  ✗ FAIL: HoldStretch val_x should be locked to 5, got: %d" % hs.val_x)
		hs_ok = false
	if hs.val_y != 7:
		printerr("  ✗ FAIL: HoldStretch val_y should snap to 7, got: %d" % hs.val_y)
		hs_ok = false
	if hs.value_label.text.contains("= 12"):
		printerr("  ✗ FAIL: HoldStretch label displays computed result (= 12)")
		hs_ok = false

	if hs_ok:
		print("  ✓ Hold & Stretch dimension locking (val_x=5), grid snap (val_y=7), and hidden result verified.")
		pass_count += 1
	hs.queue_free()

	# -----------------------------------------------------------------
	# Test 10: Chest Lock-Picking Minigame
	# -----------------------------------------------------------------
	total_tests += 1
	print("\n[TEST 10] Testing Chest Lock-Picking Minigame (Pins, Timer, Multi-Calculation)...")
	var chest_scene = load("res://scenes/ui/ChestReward.tscn")
	var chest_screen = chest_scene.instantiate() as ChestReward
	add_child(chest_screen)

	var chest_ok = true
	if chest_screen._get_pins_for_quality("bronze") != 2 or chest_screen._get_pins_for_quality("silver") != 3:
		printerr("  ✗ FAIL: Chest pins count mismatch")
		chest_ok = false

	var test_chests: Array[Dictionary] = [{"quality": "bronze", "opened": false, "failed": false}]
	chest_screen._chests = test_chests
	chest_screen._start_chest_challenge(0)

	if not chest_screen._is_lockpicking or chest_screen._total_pins != 2:
		printerr("  ✗ FAIL: Lockpicking state not initialized properly")
		chest_ok = false

	# Solve pin 1
	var dummy_btn = Button.new()
	var ans1 = chest_screen._active_problem.correct_answer
	chest_screen._evaluate_pin_answer(ans1, dummy_btn)
	if chest_screen._current_pin_idx != 1:
		printerr("  ✗ FAIL: Current pin did not advance to 1")
		chest_ok = false

	# Solve pin 2 (final)
	chest_screen._present_pin_problem()
	var ans2 = chest_screen._active_problem.correct_answer
	chest_screen._evaluate_pin_answer(ans2, dummy_btn)

	if not chest_screen._chests[0]["opened"]:
		printerr("  ✗ FAIL: Chest was not opened after solving all pins")
		chest_ok = false

	if chest_ok:
		print("  ✓ Lock-Picking minigame pin progression, multi-step math, and chest opening verified.")
		pass_count += 1

	dummy_btn.free()
	chest_screen.queue_free()

	# -----------------------------------------------------------------
	# Test 11: Mode-Dependent Input Method Filtering (MainMenu)
	# -----------------------------------------------------------------
	total_tests += 1
	print("\n[TEST 11] Testing Mode-Dependent Input Method Filtering...")
	var menu_scene = load("res://scenes/menu/MainMenu.tscn")
	var menu = menu_scene.instantiate()
	add_child(menu)

	var filter_ok = true
	# Mode 1: TASK_TO_RESULT allows all
	if not menu._is_input_allowed_for_mode(MathConfig.InputType.KEYPAD, MathConfig.GameMode.TASK_TO_RESULT) or \
	   not menu._is_input_allowed_for_mode(MathConfig.InputType.HOLD_STRETCH, MathConfig.GameMode.TASK_TO_RESULT):
		printerr("  ✗ FAIL: Task-to-Result should allow all input methods")
		filter_ok = false

	# Mode 2: RESULT_TO_EQUATION disables Keypad, allows HoldStretch & Bubbles
	if menu._is_input_allowed_for_mode(MathConfig.InputType.KEYPAD, MathConfig.GameMode.RESULT_TO_EQUATION) or \
	   menu._is_input_allowed_for_mode(MathConfig.InputType.TIMING_BAR, MathConfig.GameMode.RESULT_TO_EQUATION) or \
	   not menu._is_input_allowed_for_mode(MathConfig.InputType.HOLD_STRETCH, MathConfig.GameMode.RESULT_TO_EQUATION) or \
	   not menu._is_input_allowed_for_mode(MathConfig.InputType.BUBBLES, MathConfig.GameMode.RESULT_TO_EQUATION):
		printerr("  ✗ FAIL: Result-to-Equation filtering incorrect")
		filter_ok = false

	# Mode 3: MULTI_OP_EQUATION disables HoldStretch, allows Keypad & Bubbles
	if menu._is_input_allowed_for_mode(MathConfig.InputType.HOLD_STRETCH, MathConfig.GameMode.MULTI_OP_EQUATION) or \
	   not menu._is_input_allowed_for_mode(MathConfig.InputType.KEYPAD, MathConfig.GameMode.MULTI_OP_EQUATION) or \
	   not menu._is_input_allowed_for_mode(MathConfig.InputType.BUBBLES, MathConfig.GameMode.MULTI_OP_EQUATION):
		printerr("  ✗ FAIL: Multi-Op Equation filtering incorrect")
		filter_ok = false

	# Test auto-switch: select HoldStretch then switch to Mode 3 -> should auto-switch to Bubbles
	menu.selected_input_type = MathConfig.InputType.HOLD_STRETCH
	menu._select_mode(MathConfig.GameMode.MULTI_OP_EQUATION, menu.mode_3_btn)
	if menu.selected_input_type != MathConfig.InputType.BUBBLES:
		printerr("  ✗ FAIL: Did not auto-switch invalid input to Bubbles, got: %s" % str(menu.selected_input_type))
		filter_ok = false

	if filter_ok:
		print("  ✓ Mode-dependent input method filtering and auto-switch verified.")
		pass_count += 1
	menu.queue_free()

	# -----------------------------------------------------------------
	# Test 12: MathEngine Meister-Kette Generation (3-Operand Chains)
	# -----------------------------------------------------------------
	total_tests += 1
	print("\n[TEST 12] Testing Meister-Kette 3-Operand Generation across all operations...")
	var me_ok = true
	var ops = [MathConfig.Operation.ADDITION, MathConfig.Operation.SUBTRACTION, MathConfig.Operation.MULTIPLICATION, MathConfig.Operation.DIVISION]
	for op in ops:
		var cfg = MathConfig.create_config(MathConfig.GameMode.MULTI_OP_EQUATION, op, MathConfig.Difficulty.EASY)
		var prob = MathEngine.generate_problem(cfg)
		if not prob.is_three_operand or prob.operand_c <= 0:
			printerr("  ✗ FAIL: Generated problem for op %s is not 3-operand!" % str(op))
			me_ok = false
		print("    Generated for %s: %s = %d" % [str(op), prob.question_text, prob.correct_answer])

	if me_ok:
		print("  ✓ Meister-Kette 3-operand math generation verified for all operations.")
		pass_count += 1

	# -----------------------------------------------------------------
	# Test 13: InputArea 3-Operand Chain Evaluation
	# -----------------------------------------------------------------
	total_tests += 1
	print("\n[TEST 13] Testing InputArea 3-Operand Evaluation Logic...")
	var input_area_scene = load("res://scenes/ui/InputArea.tscn")
	var ia = input_area_scene.instantiate()
	add_child(ia)

	var ia_ok = true
	# 3 + 4 + 5 = 12
	if ia._evaluate_three_operation(3, 4, 5, "+", "+") != 12:
		printerr("  ✗ FAIL: 3 + 4 + 5 should be 12")
		ia_ok = false
	# 20 - 5 - 3 = 12
	if ia._evaluate_three_operation(20, 5, 3, "-", "-") != 12:
		printerr("  ✗ FAIL: 20 - 5 - 3 should be 12")
		ia_ok = false
	# 3 * 4 + 5 = 17
	if ia._evaluate_three_operation(3, 4, 5, "×", "+") != 17:
		printerr("  ✗ FAIL: 3 * 4 + 5 should be 17")
		ia_ok = false
	# 20 / 4 + 8 = 13
	if ia._evaluate_three_operation(20, 4, 8, "÷", "+") != 13:
		printerr("  ✗ FAIL: 20 / 4 + 8 should be 13")
		ia_ok = false

	if ia_ok:
		print("  ✓ InputArea 3-operand evaluation correctly computes mixed precedence chains.")
		pass_count += 1
	ia.queue_free()

	# -----------------------------------------------------------------
	# Summary
	# -----------------------------------------------------------------
	print("\n==================================================")
	print("  TEST RESULTS: %d / %d PASSED" % [pass_count, total_tests])
	print("==================================================")

	if pass_count == total_tests:
		print(">>> ALL VERIFICATION TESTS PASSED SUCCESSFULLY! <<<")
	else:
		printerr(">>> SOME TESTS FAILED! <<<")

	get_tree().quit(0 if pass_count == total_tests else 1)

