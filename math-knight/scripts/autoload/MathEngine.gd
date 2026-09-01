extends Node
## MathEngine autoload — handles math problem generation for all modes, operations, and difficulties.
## Supports 2-operand and 3-operand equations, result frequency capping, and Zahlenschmiede pre-filled slots.

var current_config: MathConfig


func _ready() -> void:
	current_config = MathConfig.create_config(MathConfig.GameMode.TASK_TO_RESULT, MathConfig.Operation.ADDITION, MathConfig.Difficulty.EASY)


func set_difficulty(config: MathConfig) -> void:
	current_config = config


func generate_problem(config: MathConfig = null) -> MathProblem:
	var cfg: MathConfig = config if config else current_config
	var problem: MathProblem
	
	if cfg.game_mode == MathConfig.GameMode.MULTI_OP_EQUATION:
		problem = _generate_multi_op(cfg)
	else:
		var chosen_op: MathConfig.Operation = cfg.operation
		if chosen_op == MathConfig.Operation.MIXED:
			var ops: Array[MathConfig.Operation] = [
				MathConfig.Operation.ADDITION,
				MathConfig.Operation.SUBTRACTION,
				MathConfig.Operation.MULTIPLICATION,
				MathConfig.Operation.DIVISION
			]
			chosen_op = ops.pick_random()

		match chosen_op:
			MathConfig.Operation.ADDITION:
				problem = _generate_addition(cfg)
			MathConfig.Operation.SUBTRACTION:
				problem = _generate_subtraction(cfg)
			MathConfig.Operation.MULTIPLICATION:
				problem = _generate_multiplication(cfg)
			MathConfig.Operation.DIVISION:
				problem = _generate_division(cfg)
			_:
				problem = _generate_addition(cfg)

		if cfg.game_mode == MathConfig.GameMode.RESULT_TO_EQUATION:
			problem.question_text = "?" + problem.operator_symbol + "?=" + str(problem.correct_answer)

	problem.choices = _generate_smart_distractors(problem.correct_answer, problem.operand_a, problem.operand_b, cfg.num_choices)
	problem.choices.shuffle()
	return problem


func generate_set(set_size: int = 5, total_bubbles: int = 8, config: MathConfig = null) -> Dictionary:
	var cfg: MathConfig = config if config else current_config
	var effective_set_size: int = max(set_size, 1)
	var problems: Array[MathProblem] = []
	var pool: Array[int] = []
	var pool_left: Array[int] = []
	var pool_right: Array[int] = []
	var result_counts: Dictionary = {}
	var seen_signatures: Dictionary = {}

	# 1. Generate problems with result-frequency capping (max 2x same result in a 5-block)
	for i in range(effective_set_size):
		var best_problem: MathProblem = null
		var found: bool = false
		
		for attempt in range(60):
			var p: MathProblem = generate_problem(cfg)
			var sig: String = "%d%s%d" % [p.operand_a, p.operator_symbol, p.operand_b]
			if p.is_three_operand:
				sig += "%s%d" % [p.operator_symbol_2, p.operand_c]
			
			var count: int = result_counts.get(p.correct_answer, 0)
			if count < 2 and not seen_signatures.has(sig):
				best_problem = p
				seen_signatures[sig] = true
				result_counts[p.correct_answer] = count + 1
				found = true
				break
			elif best_problem == null:
				best_problem = p

		if not found and best_problem != null:
			result_counts[best_problem.correct_answer] = result_counts.get(best_problem.correct_answer, 0) + 1

		if best_problem == null:
			best_problem = generate_problem(cfg)

		problems.append(best_problem)

	# 2. Game Mode specific set configuration
	if cfg.game_mode == MathConfig.GameMode.RESULT_TO_EQUATION:
		_configure_zahlenschmiede_set(problems, cfg)
	elif cfg.game_mode == MathConfig.GameMode.MULTI_OP_EQUATION:
		_configure_meisterkette_set(problems, cfg)

	var max_val: int = max(cfg.max_result, cfg.max_operand)
	if max_val < 1:
		max_val = 20

	# 3. Build Bubble Pools
	if cfg.game_mode == MathConfig.GameMode.RESULT_TO_EQUATION:
		for p in problems:
			if p.is_completely_open():
				if not pool_left.has(p.operand_a):
					pool_left.append(p.operand_a)
				if not pool_right.has(p.operand_b):
					pool_right.append(p.operand_b)
			elif p.given_operand_index == 0:
				if not pool_right.has(p.operand_b):
					pool_right.append(p.operand_b)
			elif p.given_operand_index == 1:
				if not pool_left.has(p.operand_a):
					pool_left.append(p.operand_a)

		# Ensure Left and Right pools have all required operands plus distractors
		var target_side_count: int = max(4, max(pool_left.size(), pool_right.size()) + 1)
		var left_attempts: int = 0
		while pool_left.size() < target_side_count and left_attempts < 40:
			left_attempts += 1
			var base_val: int = pool_left.pick_random() if not pool_left.is_empty() else randi_range(cfg.min_operand, max_val)
			var distractor: int = clamp(base_val + (randi_range(1, 3) if randf() > 0.5 else -randi_range(1, 3)), 1, max_val + 5)
			if not pool_left.has(distractor):
				pool_left.append(distractor)

		var right_attempts: int = 0
		while pool_right.size() < target_side_count and right_attempts < 40:
			right_attempts += 1
			var base_val: int = pool_right.pick_random() if not pool_right.is_empty() else randi_range(cfg.min_operand, max_val)
			var distractor: int = clamp(base_val + (randi_range(1, 3) if randf() > 0.5 else -randi_range(1, 3)), 1, max_val + 5)
			if not pool_right.has(distractor):
				pool_right.append(distractor)

		pool_left.shuffle()
		pool_right.shuffle()

		# Combined flat pool for backwards compatibility
		for val in pool_left:
			pool.append(val)
		for val in pool_right:
			pool.append(val)
	else:
		# Mode 1 (Rechen-Schlag) & Mode 3 (Meister-Kette)
		# Ensure EVERY problem's required answers/operands are in the pool
		for p in problems:
			if p.is_three_operand and p.given_operand_index == -2: # Type B 3-part chain
				if not pool.has(p.operand_a): pool.append(p.operand_a)
				if not pool.has(p.operand_b): pool.append(p.operand_b)
				if not pool.has(p.operand_c): pool.append(p.operand_c)
			else:
				if not pool.has(p.correct_answer): pool.append(p.correct_answer)

		var target_pool_size: int = max(effective_set_size + 4, 8)
		var dist_attempts: int = 0
		while pool.size() < target_pool_size and dist_attempts < 50:
			dist_attempts += 1
			var base_val: int = pool.pick_random() if not pool.is_empty() else randi_range(cfg.min_operand, max_val)
			var distractor: int = clamp(base_val + (randi_range(1, 3) if randf() > 0.5 else -randi_range(1, 3)), 1, max_val + 10)
			if not pool.has(distractor):
				pool.append(distractor)

		pool.shuffle()

	return {
		"problems": problems,
		"bubble_pool": pool,
		"bubble_pool_left": pool_left,
		"bubble_pool_right": pool_right
	}


func _configure_meisterkette_set(problems: Array[MathProblem], cfg: MathConfig) -> void:
	var total: int = problems.size()
	var is_bubble_input = (cfg.input_type == MathConfig.InputType.BUBBLES or cfg.input_type == MathConfig.InputType.BUBBLES_MOVING or cfg.input_type == MathConfig.InputType.BUBBLES_LIVING)

	for i in range(total):
		var p: MathProblem = problems[i]
		if is_bubble_input and i % 2 == 1:
			# Type B: 3-operand chain building (? + ? + ? = 18)
			p.given_operand_index = -2 # special marker for 3-part chain
			p.question_text = "?%s?%s?=%d" % [p.operator_symbol, p.operator_symbol_2, p.correct_answer]
		else:
			# Type A: Enemy shows long equation, player calculates & enters result
			p.given_operand_index = -1
			p.question_text = "%d%s%d%s%d" % [p.operand_a, p.operator_symbol, p.operand_b, p.operator_symbol_2, p.operand_c]


func _configure_zahlenschmiede_set(problems: Array[MathProblem], _cfg: MathConfig) -> void:
	var total: int = problems.size()
	# Option C: exactly 3 out of 5 (60%) prefilled, 2 out of 5 (40%) completely open
	var num_prefilled: int = int(round(float(total) * 0.6))
	var num_open: int = total - num_prefilled

	var open_slots: Array[bool] = []
	for i in range(total):
		open_slots.append(i < num_open)
	open_slots.shuffle()

	for i in range(total):
		var p: MathProblem = problems[i]
		if open_slots[i]:
			p.given_operand_index = -1
			p.question_text = "?" + p.operator_symbol + "?=" + str(p.correct_answer)
		else:
			# Randomly choose operand A (0) or operand B (1) as pre-given
			var given_idx: int = 0 if randf() < 0.5 else 1
			p.given_operand_index = given_idx
			if given_idx == 0:
				p.question_text = str(p.operand_a) + p.operator_symbol + "?=" + str(p.correct_answer)
			else:
				p.question_text = "?" + p.operator_symbol + str(p.operand_b) + "=" + str(p.correct_answer)


func _generate_multi_op(cfg: MathConfig) -> MathProblem:
	var problem: MathProblem = MathProblem.new()
	problem.is_three_operand = true

	var chosen_op = cfg.operation
	if chosen_op == MathConfig.Operation.MIXED:
		var ops = [MathConfig.Operation.ADDITION, MathConfig.Operation.SUBTRACTION, MathConfig.Operation.MULTIPLICATION, MathConfig.Operation.DIVISION]
		chosen_op = ops.pick_random()

	match chosen_op:
		MathConfig.Operation.ADDITION:
			problem.operator_symbol = "+"
			problem.operator_symbol_2 = "+"
			var max_num = 6 if cfg.difficulty == MathConfig.Difficulty.EASY else (12 if cfg.difficulty == MathConfig.Difficulty.MEDIUM else 20)
			problem.operand_a = randi_range(cfg.min_operand, max_num)
			problem.operand_b = randi_range(cfg.min_operand, max_num)
			problem.operand_c = randi_range(cfg.min_operand, max_num)
			problem.correct_answer = problem.operand_a + problem.operand_b + problem.operand_c

		MathConfig.Operation.SUBTRACTION:
			if randf() < 0.5:
				problem.operator_symbol = "-"
				problem.operator_symbol_2 = "-"
				var b = randi_range(2, 6 if cfg.difficulty == MathConfig.Difficulty.EASY else 12)
				var c = randi_range(1, 5 if cfg.difficulty == MathConfig.Difficulty.EASY else 10)
				var rem = randi_range(2, 10 if cfg.difficulty == MathConfig.Difficulty.EASY else 20)
				problem.operand_a = b + c + rem
				problem.operand_b = b
				problem.operand_c = c
				problem.correct_answer = rem
			else:
				problem.operator_symbol = "+"
				problem.operator_symbol_2 = "-"
				var a = randi_range(3, 8 if cfg.difficulty == MathConfig.Difficulty.EASY else 15)
				var b = randi_range(3, 8 if cfg.difficulty == MathConfig.Difficulty.EASY else 15)
				var c = randi_range(2, min(a + b - 1, 6 if cfg.difficulty == MathConfig.Difficulty.EASY else 12))
				problem.operand_a = a
				problem.operand_b = b
				problem.operand_c = c
				problem.correct_answer = a + b - c

		MathConfig.Operation.MULTIPLICATION:
			problem.operator_symbol = "×"
			problem.operator_symbol_2 = "+" if randf() < 0.6 else "-"
			var a = randi_range(2, 4 if cfg.difficulty == MathConfig.Difficulty.EASY else (6 if cfg.difficulty == MathConfig.Difficulty.MEDIUM else 9))
			var b = randi_range(2, 4 if cfg.difficulty == MathConfig.Difficulty.EASY else (6 if cfg.difficulty == MathConfig.Difficulty.MEDIUM else 9))
			var prod = a * b
			if problem.operator_symbol_2 == "+":
				var c = randi_range(1, 6 if cfg.difficulty == MathConfig.Difficulty.EASY else 15)
				problem.operand_a = a
				problem.operand_b = b
				problem.operand_c = c
				problem.correct_answer = prod + c
			else:
				var c = randi_range(1, min(prod - 1, 6 if cfg.difficulty == MathConfig.Difficulty.EASY else 12))
				problem.operand_a = a
				problem.operand_b = b
				problem.operand_c = c
				problem.correct_answer = prod - c

		MathConfig.Operation.DIVISION:
			problem.operator_symbol = "÷"
			problem.operator_symbol_2 = "+"
			var divisor = randi_range(2, 5 if cfg.difficulty == MathConfig.Difficulty.EASY else 8)
			var quotient = randi_range(2, 5 if cfg.difficulty == MathConfig.Difficulty.EASY else 8)
			var c = randi_range(1, 6 if cfg.difficulty == MathConfig.Difficulty.EASY else 12)
			problem.operand_a = divisor * quotient
			problem.operand_b = divisor
			problem.operand_c = c
			problem.correct_answer = quotient + c

		_:
			problem.operator_symbol = "+"
			problem.operator_symbol_2 = "+"
			problem.operand_a = randi_range(1, 5)
			problem.operand_b = randi_range(1, 5)
			problem.operand_c = randi_range(1, 5)
			problem.correct_answer = problem.operand_a + problem.operand_b + problem.operand_c

	problem.question_text = "%d%s%d%s%d" % [problem.operand_a, problem.operator_symbol, problem.operand_b, problem.operator_symbol_2, problem.operand_c]
	return problem


func _generate_addition(cfg: MathConfig) -> MathProblem:
	var problem: MathProblem = MathProblem.new()
	problem.operator_symbol = "+"
	
	if cfg.difficulty == MathConfig.Difficulty.HARD and randf() < 0.55:
		# 3-operand addition: a + b + c
		problem.is_three_operand = true
		problem.operator_symbol_2 = "+"
		var max_part: int = max(5, cfg.max_result / 3)
		problem.operand_a = randi_range(cfg.min_operand, max_part)
		problem.operand_b = randi_range(cfg.min_operand, max_part)
		problem.operand_c = randi_range(cfg.min_operand, max_part)
		problem.correct_answer = problem.operand_a + problem.operand_b + problem.operand_c
		problem.question_text = str(problem.operand_a) + "+" + str(problem.operand_b) + "+" + str(problem.operand_c)
	else:
		var attempts: int = 0
		while attempts < 100:
			problem.operand_a = randi_range(cfg.min_operand, cfg.max_operand)
			problem.operand_b = randi_range(cfg.min_operand, cfg.max_operand)
			problem.correct_answer = problem.operand_a + problem.operand_b
			if problem.correct_answer <= cfg.max_result:
				# On medium/hard, favor non-trivial sums
				if cfg.difficulty != MathConfig.Difficulty.EASY and problem.operand_a == problem.operand_b and randf() < 0.5:
					attempts += 1
					continue
				break
			attempts += 1
		problem.question_text = str(problem.operand_a) + "+" + str(problem.operand_b)
			
	return problem


func _generate_subtraction(cfg: MathConfig) -> MathProblem:
	var problem: MathProblem = MathProblem.new()
	problem.operator_symbol = "-"
	
	if cfg.difficulty == MathConfig.Difficulty.HARD and randf() < 0.55:
		problem.is_three_operand = true
		if randf() < 0.5:
			# a - b - c
			problem.operator_symbol_2 = "-"
			var a: int = randi_range(30, cfg.max_result)
			var b: int = randi_range(5, max(6, a / 2))
			var c: int = randi_range(3, max(4, (a - b) - 5))
			problem.operand_a = a
			problem.operand_b = b
			problem.operand_c = c
			problem.correct_answer = a - b - c
			problem.question_text = str(a) + "-" + str(b) + "-" + str(c)
		else:
			# a + b - c
			problem.operator_symbol = "+"
			problem.operator_symbol_2 = "-"
			var a: int = randi_range(15, max(16, cfg.max_operand / 2))
			var b: int = randi_range(15, max(16, cfg.max_operand / 2))
			var c: int = randi_range(10, max(11, (a + b) - 10))
			problem.operand_a = a
			problem.operand_b = b
			problem.operand_c = c
			problem.correct_answer = a + b - c
			problem.question_text = str(a) + "+" + str(b) + "-" + str(c)
	else:
		var a: int = randi_range(cfg.min_operand, cfg.max_operand)
		var b: int = randi_range(cfg.min_operand, cfg.max_operand)
		if a < b:
			var temp: int = a
			a = b
			b = temp
		
		# Prevent trivial a - a = 0 or a - 0 = a
		if a == b:
			if a < cfg.max_operand:
				a += randi_range(1, 4)
			else:
				b = max(1, b - randi_range(1, 4))
		
		problem.operand_a = a
		problem.operand_b = b
		problem.correct_answer = a - b
		problem.question_text = str(a) + "-" + str(b)
		
	return problem


func _generate_multiplication(cfg: MathConfig) -> MathProblem:
	var problem: MathProblem = MathProblem.new()
	problem.operator_symbol = "×"
	
	var attempts: int = 0
	while attempts < 100:
		if cfg.difficulty == MathConfig.Difficulty.EASY:
			# Small 1x1: 2, 3, 4, 5 tables
			var bases: Array[int] = [2, 3, 4, 5]
			problem.operand_a = bases.pick_random()
			problem.operand_b = randi_range(2, 5)
		elif cfg.difficulty == MathConfig.Difficulty.MEDIUM:
			# Full 1x1: 2..10 tables
			problem.operand_a = randi_range(2, 10)
			problem.operand_b = randi_range(2, 10)
		else:
			# Hard: 11..16 × 2..9 or challenging 1x1 squares up to 12×12
			if randf() < 0.6:
				problem.operand_a = randi_range(11, 16)
				problem.operand_b = randi_range(2, 9)
			else:
				problem.operand_a = randi_range(6, 12)
				problem.operand_b = randi_range(6, 12)

		problem.correct_answer = problem.operand_a * problem.operand_b
		if problem.correct_answer <= cfg.max_result:
			break
		attempts += 1
		
	problem.question_text = str(problem.operand_a) + "×" + str(problem.operand_b)
	return problem


func _generate_division(cfg: MathConfig) -> MathProblem:
	var problem: MathProblem = MathProblem.new()
	problem.operator_symbol = "÷"
	
	var divisor: int
	var quotient: int

	if cfg.difficulty == MathConfig.Difficulty.EASY:
		divisor = randi_range(2, 5)
		quotient = randi_range(1, 5)
	elif cfg.difficulty == MathConfig.Difficulty.MEDIUM:
		divisor = randi_range(2, 10)
		quotient = randi_range(2, 10)
	else:
		if randf() < 0.6:
			divisor = randi_range(3, 12)
			quotient = randi_range(4, 15)
		else:
			divisor = randi_range(4, 16)
			quotient = randi_range(3, 10)

	var dividend: int = divisor * quotient
	problem.operand_a = dividend
	problem.operand_b = divisor
	problem.correct_answer = quotient
	problem.question_text = str(problem.operand_a) + "÷" + str(problem.operand_b)
	return problem


func _generate_smart_distractors(answer: int, a: int, b: int, count: int) -> Array[int]:
	var choices: Array[int] = [answer]
	var dict: Dictionary = {answer: true}
	
	var possible: Array[int] = [
		answer + 1, answer - 1,
		answer + 2, answer - 2,
		answer + 10, answer - 10,
		a, b,
		a + 1, b + 1
	]
	
	if answer > 9:
		var s: String = str(answer)
		s = s.reverse()
		possible.append(s.to_int())
		
	possible.shuffle()
	
	for p in possible:
		if choices.size() >= count:
			break
		if p >= 1 and not dict.has(p):
			choices.append(p)
			dict[p] = true
			
	while choices.size() < count:
		var r: int = answer + randi_range(-5, 5)
		if r >= 1 and not dict.has(r):
			choices.append(r)
			dict[r] = true
			
	return choices
