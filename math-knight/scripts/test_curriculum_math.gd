extends SceneTree

func _init() -> void:
	print("==================================================")
	print(">>> RUNNING CURRICULUM MATH ENGINE VERIFICATION <<<")
	print("==================================================")

	var success := true
	var MathEngineScript = load("res://scripts/autoload/MathEngine.gd")
	var math_engine = MathEngineScript.new()
	root.add_child(math_engine)

	# --- TEST 1: Curriculum L1 (1-10, Verliebte Zahlen, Verdoppeln/Halbieren) ---
	print("\n[TEST 1] Curriculum L1: Basis 10...")
	var l1_subtypes = [
		MathConfig.CurriculumSubtype.STANDARD,
		MathConfig.CurriculumSubtype.VERLIEBTE_ZAHLEN,
		MathConfig.CurriculumSubtype.VERDOPPELN_HALBIEREN
	]
	for subtype in l1_subtypes:
		var cfg = MathConfig.create_curriculum_config(
			MathConfig.CurriculumLevel.L1_BASIS_10,
			subtype,
			MathConfig.GameContext.TRAINING
		)
		for i in range(30):
			var p: MathProblem = math_engine.generate_problem(cfg)
			if p.correct_answer < 1 or p.correct_answer > 10:
				printerr("FAIL L1: result out of range 1..10: ", p.correct_answer, " in ", p.question_text)
				success = false

			if subtype == MathConfig.CurriculumSubtype.VERLIEBTE_ZAHLEN:
				if p.operator_symbol == "+":
					if p.operand_a + p.operand_b != 10 or p.correct_answer != 10:
						printerr("FAIL L1 Verliebte Zahlen sum != 10: ", p.question_text)
						success = false
				elif p.operator_symbol == "-":
					if p.operand_a != 10 or p.operand_b + p.correct_answer != 10:
						printerr("FAIL L1 Verliebte Zahlen sub != 10: ", p.question_text)
						success = false

			elif subtype == MathConfig.CurriculumSubtype.VERDOPPELN_HALBIEREN:
				if p.operator_symbol == "+":
					if p.operand_a != p.operand_b or p.correct_answer != p.operand_a * 2:
						printerr("FAIL L1 Verdoppeln operands not equal: ", p.question_text)
						success = false
				elif p.operator_symbol == "÷":
					if p.operand_b != 2 or p.operand_a != p.correct_answer * 2:
						printerr("FAIL L1 Halbieren not /2: ", p.question_text)
						success = false
	print("✓ L1 Basis 10 passed all constraints (Verliebte Zahlen, Verdoppeln, Halbieren, Standard).")

	# --- TEST 2: Curriculum L2 (Bis 20 OHNE Zehnerübergang) ---
	print("\n[TEST 2] Curriculum L2: Bis 20 OHNE Zehnerübergang...")
	var cfg_l2 = MathConfig.create_curriculum_config(
		MathConfig.CurriculumLevel.L2_BIS_20_OHNE_UEBERGANG,
		MathConfig.CurriculumSubtype.OHNE_UEBERGANG,
		MathConfig.GameContext.TRAINING
	)
	for i in range(50):
		var p: MathProblem = math_engine.generate_problem(cfg_l2)
		if p.correct_answer < 10 or p.correct_answer > 20:
			printerr("FAIL L2: result out of expected range 10..20: ", p.correct_answer, " in ", p.question_text)
			success = false

		if p.operator_symbol == "+":
			var a = p.operand_a
			var b = p.operand_b
			var units_sum = (a % 10) + (b % 10)
			if units_sum >= 10:
				printerr("FAIL L2: addition crossed tens: ", p.question_text, " units_sum=", units_sum)
				success = false
		elif p.operator_symbol == "-":
			var a = p.operand_a
			var b = p.operand_b
			if (a % 10) < b:
				printerr("FAIL L2: subtraction crossed tens: ", p.question_text, " a_units=", a % 10, " b=", b)
				success = false
	print("✓ L2 Bis 20 passed (zero decade crossings in 50 trials).")

	# --- TEST 3: Curriculum L3 (MIT Zehnerübergang & Uhrzeit) ---
	print("\n[TEST 3] Curriculum L3: MIT Zehnerübergang & Uhrzeit...")
	var cfg_l3 = MathConfig.create_curriculum_config(
		MathConfig.CurriculumLevel.L3_ZEHNERUEBERGANG_ZEIT,
		MathConfig.CurriculumSubtype.MIT_UEBERGANG,
		MathConfig.GameContext.TRAINING
	)
	for i in range(50):
		var p: MathProblem = math_engine.generate_problem(cfg_l3)
		if p.operator_symbol == "+":
			if p.operand_a + p.operand_b <= 10:
				printerr("FAIL L3: addition did NOT cross tens: ", p.question_text, " sum=", p.correct_answer)
				success = false
		elif p.operator_symbol == "-":
			if (p.operand_a % 10) >= p.operand_b:
				printerr("FAIL L3: subtraction did NOT cross tens: ", p.question_text, " a_units=", p.operand_a % 10, " b=", p.operand_b)
				success = false

	# Test Clock/Time subtype
	var cfg_l3_time = MathConfig.create_curriculum_config(
		MathConfig.CurriculumLevel.L3_ZEHNERUEBERGANG_ZEIT,
		MathConfig.CurriculumSubtype.UHRZEIT_ZEITSPANNE,
		MathConfig.GameContext.MINIGAME
	)
	for i in range(20):
		var p = math_engine.generate_problem(cfg_l3_time)
		if not p.display_note.contains("min"):
			printerr("FAIL L3 Time: missing min in display_note: ", p.display_note)
			success = false
	print("✓ L3 Zehnerübergang & Uhrzeit passed (mandatory decade crossing verified).")

	# --- TEST 4: Curriculum L4 (Hunderterraum & Schrittweises Rechnen) ---
	print("\n[TEST 4] Curriculum L4: Hunderterraum & Schritte (±5, ±10, ±20)...")
	var cfg_l4 = MathConfig.create_curriculum_config(
		MathConfig.CurriculumLevel.L4_HUNDERTER_SCHRITTE,
		MathConfig.CurriculumSubtype.SCHRITTWEISE_5_10,
		MathConfig.GameContext.TRAINING
	)
	for i in range(50):
		var p: MathProblem = math_engine.generate_problem(cfg_l4)
		if p.correct_answer < 0 or p.correct_answer > 100:
			printerr("FAIL L4: result out of 0..100: ", p.correct_answer, " in ", p.question_text)
			success = false
		if not [5, 10, 20].has(p.operand_b):
			printerr("FAIL L4: step operand_b not 5, 10, or 20: ", p.operand_b, " in ", p.question_text)
			success = false
	print("✓ L4 Hunderterraum Schritte passed.")

	# --- TEST 5: Curriculum L5 (Einmaleins 1x1) ---
	print("\n[TEST 5] Curriculum L5: Einmaleins 1x1...")
	var cfg_l5 = MathConfig.create_curriculum_config(
		MathConfig.CurriculumLevel.L5_EINMALEINS,
		MathConfig.CurriculumSubtype.STANDARD,
		MathConfig.GameContext.TRAINING
	)
	for i in range(50):
		var p: MathProblem = math_engine.generate_problem(cfg_l5)
		if p.operand_a < 1 or p.operand_a > 10 or p.operand_b < 1 or p.operand_b > 10:
			printerr("FAIL L5: operands out of 1..10: ", p.question_text)
			success = false
		if p.correct_answer != p.operand_a * p.operand_b:
			printerr("FAIL L5: wrong product: ", p.question_text, " = ", p.correct_answer)
			success = false

	# Test specific times table target (e.g. 7er Reihe)
	cfg_l5.target_times_table = 7
	for i in range(20):
		var p: MathProblem = math_engine.generate_problem(cfg_l5)
		if p.operand_a != 7:
			printerr("FAIL L5: target times table != 7: got ", p.operand_a)
			success = false
	print("✓ L5 Einmaleins 1x1 and targeted table drill passed.")

	# --- TEST 6: Curriculum L6 (Division als Umkehrung) ---
	print("\n[TEST 6] Curriculum L6: Division als Umkehrung...")
	var cfg_l6 = MathConfig.create_curriculum_config(
		MathConfig.CurriculumLevel.L6_DIVISION,
		MathConfig.CurriculumSubtype.UMKEHRAUFGABEN,
		MathConfig.GameContext.TRAINING
	)
	for i in range(50):
		var p: MathProblem = math_engine.generate_problem(cfg_l6)
		if p.operand_b < 1 or p.operand_b > 10 or p.correct_answer < 1 or p.correct_answer > 10:
			printerr("FAIL L6: divisor or quotient out of 1..10: ", p.question_text)
			success = false
		if p.operand_a != p.operand_b * p.correct_answer:
			printerr("FAIL L6: dividend != divisor * quotient (remainder detected): ", p.question_text)
			success = false
		if not p.display_note.contains("Umkehraufgabe"):
			printerr("FAIL L6: missing Umkehraufgabe note: ", p.display_note)
			success = false
	print("✓ L6 Division Umkehrung passed (zero remainders, inverse notes present).")

	# --- TEST 7: Game Modes Compatibility (Result-to-Equation & Multi-Op in Curriculum) ---
	print("\n[TEST 7] Game Modes & Set Generation with Curriculum...")
	var cfg_schmiede = MathConfig.create_curriculum_config(
		MathConfig.CurriculumLevel.L1_BASIS_10,
		MathConfig.CurriculumSubtype.VERLIEBTE_ZAHLEN,
		MathConfig.GameContext.TRAINING,
		MathConfig.GameMode.RESULT_TO_EQUATION
	)
	var set_schmiede = math_engine.generate_set(5, 10, cfg_schmiede)
	if set_schmiede.problems.size() != 5:
		printerr("FAIL: Curriculum Zahlen-Schmiede set size != 5")
		success = false
	for p in set_schmiede.problems:
		if not p.question_text.contains("?"):
			printerr("FAIL: Zahlen-Schmiede missing ? slot: ", p.question_text)
			success = false

	# Test Multi-op in L2
	var cfg_multi = MathConfig.create_curriculum_config(
		MathConfig.CurriculumLevel.L2_BIS_20_OHNE_UEBERGANG,
		MathConfig.CurriculumSubtype.OHNE_UEBERGANG,
		MathConfig.GameContext.COMBAT,
		MathConfig.GameMode.MULTI_OP_EQUATION
	)
	var p_multi = math_engine.generate_problem(cfg_multi)
	if not p_multi.is_three_operand:
		printerr("FAIL: Curriculum Multi-Op problem not three operand")
		success = false
	print("✓ Game Modes (Zahlen-Schmiede & Multi-Op) with Curriculum passed.")

	# --- TEST 8: Backwards Compatibility (Legacy Configs) ---
	print("\n[TEST 8] Backwards Compatibility...")
	var legacy_cfg = MathConfig.create_config(MathConfig.GameMode.TASK_TO_RESULT, MathConfig.Operation.ADDITION, MathConfig.Difficulty.EASY)
	var legacy_set = math_engine.generate_set(5, 8, legacy_cfg)
	if legacy_set.problems.size() != 5:
		printerr("FAIL: Legacy set generation size mismatch")
		success = false
	for p in legacy_set.problems:
		if not legacy_set.bubble_pool.has(p.correct_answer):
			printerr("FAIL: Legacy pool missing answer ", p.correct_answer)
			success = false
	print("✓ Legacy configs continue to work seamlessly.")

	math_engine.queue_free()

	if success:
		print("\n==================================================")
		print(">>> ALL CURRICULUM MATH ENGINE TESTS PASSED! <<<")
		print("==================================================")
		quit(0)
	else:
		printerr("\n>>> CURRICULUM MATH ENGINE TESTS FAILED! <<<")
		quit(1)
