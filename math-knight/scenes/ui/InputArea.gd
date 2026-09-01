extends Control

var bubble_scene: PackedScene = preload("res://scenes/ui/NumberBubble.tscn")
var active_bubbles: Array[Area2D] = []
var current_choices: Array[int] = []
var bubble_area: Rect2
var min_bubble_spacing: float = 68.0

# Equation Builder state (Mode 2 & 3)
var _current_math_problem: MathProblem = null
var _first_operand: int = -1
var _first_bubble: Area2D = null
var _second_operand: int = -1
var _second_bubble: Area2D = null
var _first_operand_is_prefilled: bool = false
var _second_operand_is_prefilled: bool = false
var _current_op_symbol: String = "+"
var _current_target_result: int = 0

var active_custom_method: InputMethodBase = null

@onready var header_bar: ColorRect = $HeaderBar
@onready var formula_bar: Label = $HeaderBar/FormulaBar
@onready var center_operator_bar: HBoxContainer = $HeaderBar/CenterOperatorBar
@onready var op_btn_add: Button = $HeaderBar/CenterOperatorBar/OpBtnAdd
@onready var op_btn_sub: Button = $HeaderBar/CenterOperatorBar/OpBtnSub
@onready var op_btn_mul: Button = $HeaderBar/CenterOperatorBar/OpBtnMul
@onready var op_btn_div: Button = $HeaderBar/CenterOperatorBar/OpBtnDiv
@onready var zone_left_bg: ColorRect = $ZoneLeftBg
@onready var zone_right_bg: ColorRect = $ZoneRightBg
@onready var center_divider: ColorRect = $CenterDivider
@onready var bubble_container: Control = $BubbleContainer
@onready var swipe_trail: Line2D = get_node_or_null("SwipeTrail")
@onready var slice_detector: Node2D = get_node_or_null("SliceDetector")


func _ready() -> void:
	call_deferred("_update_bubble_area")
	_setup_active_input_method()
	EventBus.problem_presented.connect(_on_problem_presented)
	EventBus.answer_correct.connect(func(_p, _c): if active_custom_method: active_custom_method.on_answer_evaluated(true))
	EventBus.answer_wrong.connect(func(_p): if active_custom_method: active_custom_method.on_answer_evaluated(false))

	op_btn_add.pressed.connect(func(): _set_active_operator("+"))
	op_btn_sub.pressed.connect(func(): _set_active_operator("-"))
	op_btn_mul.pressed.connect(func(): _set_active_operator("×"))
	op_btn_div.pressed.connect(func(): _set_active_operator("÷"))


func _setup_active_input_method() -> void:
	var cfg = MathEngine.current_config
	if not cfg or cfg.input_type == MathConfig.InputType.BUBBLES or cfg.input_type == MathConfig.InputType.BUBBLES_MOVING or cfg.input_type == MathConfig.InputType.BUBBLES_LIVING:
		return

	var method_scene: PackedScene = null
	match cfg.input_type:
		MathConfig.InputType.HANDWRITING:
			method_scene = load("res://scenes/ui/input_methods/HandwritingInputMethod.tscn")
		MathConfig.InputType.QUICK_TAP:
			method_scene = load("res://scenes/ui/input_methods/QuickTapInputMethod.tscn")
		MathConfig.InputType.HOLD_STRETCH:
			method_scene = load("res://scenes/ui/input_methods/HoldStretchInputMethod.tscn")
		MathConfig.InputType.TIMING_BAR:
			method_scene = load("res://scenes/ui/input_methods/TimingBarInputMethod.tscn")
		MathConfig.InputType.NUMBER_WHEEL:
			method_scene = load("res://scenes/ui/input_methods/NumberWheelInputMethod.tscn")
		MathConfig.InputType.KEYPAD:
			method_scene = load("res://scenes/ui/input_methods/KeypadInputMethod.tscn")

	if method_scene:
		# Hide bubble elements
		bubble_container.visible = false
		header_bar.visible = false
		zone_left_bg.visible = false
		zone_right_bg.visible = false
		center_divider.visible = false
		if slice_detector:
			slice_detector.visible = false
			slice_detector.set_process_input(false)
		if swipe_trail:
			swipe_trail.visible = false

		active_custom_method = method_scene.instantiate()
		active_custom_method.setup(cfg)
		active_custom_method.answer_submitted.connect(_on_custom_method_answer_submitted)
		add_child(active_custom_method)


func _configure_bubble_motion(bubble: NumberBubble, min_x: float, max_x: float) -> void:
	var cfg = MathEngine.current_config
	if not cfg or not is_instance_valid(bubble):
		return

	var b_min = Vector2(min_x, 24.0)
	var b_max = Vector2(max_x, 118.0)

	# Determine effective bubble mode based on input_type & difficulty
	var mode_type = "static"
	if cfg.input_type == MathConfig.InputType.BUBBLES_MOVING:
		mode_type = "moving"
	elif cfg.input_type == MathConfig.InputType.BUBBLES_LIVING:
		mode_type = "living"
	elif cfg.input_type == MathConfig.InputType.BUBBLES:
		# Input Difficulty progression: Easy -> Static, Medium -> Moving, Hard -> Living!
		match cfg.input_difficulty:
			MathConfig.InputDifficulty.EASY: mode_type = "static"
			MathConfig.InputDifficulty.MEDIUM: mode_type = "moving"
			MathConfig.InputDifficulty.HARD: mode_type = "living"

	var speed_mult: float = 1.0 + (float(GameManager.current_stage - 1) * 0.08)

	if mode_type == "moving":
		bubble.setup_motion("moving", b_min, b_max, 0.0, speed_mult)
	elif mode_type == "living":
		var life = randf_range(6.0, 11.0) if cfg.difficulty == MathConfig.Difficulty.HARD else randf_range(8.0, 14.0)
		bubble.setup_motion("living", b_min, b_max, life, speed_mult * 1.15)
		if not bubble.naturally_expired.is_connected(_on_bubble_naturally_expired):
			bubble.naturally_expired.connect(_on_bubble_naturally_expired)


func _on_bubble_naturally_expired(bubble: Area2D) -> void:
	if active_bubbles.has(bubble):
		active_bubbles.erase(bubble)

	if _current_math_problem:
		_ensure_problem_solvable(_current_math_problem)

		var cfg = MathEngine.current_config
		if cfg and cfg.input_type == MathConfig.InputType.BUBBLES_LIVING:
			var target_count = 6 if cfg.game_mode == MathConfig.GameMode.TASK_TO_RESULT else 8
			if active_bubbles.size() < target_count:
				var rand_val = randi_range(cfg.min_operand, cfg.max_result)
				var zone_type = "left" if randf() < 0.5 else "right"
				var min_x = 36.0 if (zone_type == "left" or cfg.game_mode == MathConfig.GameMode.TASK_TO_RESULT) else 360.0
				var max_x = 280.0 if (zone_type == "left" and cfg.game_mode != MathConfig.GameMode.TASK_TO_RESULT) else 604.0
				_spawn_replenished_bubble(rand_val, zone_type, min_x, max_x)


func _on_custom_method_answer_submitted(value: int, method_name: String, _extra: Dictionary) -> void:
	EventBus.answer_selected.emit(value, method_name, null, Vector2.ZERO)


func _update_bubble_area() -> void:
	if bubble_container:
		bubble_area = Rect2(Vector2.ZERO, bubble_container.size)
	else:
		bubble_area = Rect2(Vector2.ZERO, Vector2(640.0, 112.0))


func _on_problem_presented(problem: RefCounted) -> void:
	var math_prob: MathProblem = problem as MathProblem
	if not math_prob:
		return

	if active_custom_method:
		active_custom_method.on_problem_presented(math_prob)
		return

	_current_math_problem = math_prob
	var mode = MathEngine.current_config.game_mode
	if mode == MathConfig.GameMode.RESULT_TO_EQUATION or mode == MathConfig.GameMode.MULTI_OP_EQUATION:
		center_operator_bar.visible = (mode == MathConfig.GameMode.MULTI_OP_EQUATION)
		formula_bar.visible = true
		_current_op_symbol = math_prob.operator_symbol
		_current_target_result = math_prob.correct_answer
		_update_operator_buttons_visibility(mode)
		_reset_formula_display()
	else:
		center_operator_bar.visible = false
		formula_bar.visible = false
		zone_left_bg.visible = false
		zone_right_bg.visible = false
		center_divider.visible = false

	# Guarantee that the needed bubble(s) exist on screen right now!
	_ensure_problem_solvable(math_prob)


func _clean_active_bubbles() -> void:
	var valid: Array[Area2D] = []
	for b in active_bubbles:
		if is_instance_valid(b) and b.is_alive and not b._is_splatting:
			valid.append(b)
	active_bubbles = valid


func _ensure_problem_solvable(math_prob: MathProblem) -> void:
	_clean_active_bubbles()
	var mode = MathEngine.current_config.game_mode

	if mode == MathConfig.GameMode.TASK_TO_RESULT:
		# Mode 1: Check if math_prob.correct_answer is currently on screen
		var has_answer: bool = false
		for b in active_bubbles:
			if b.value == math_prob.correct_answer:
				has_answer = true
				break

		if not has_answer:
			var pos := _find_free_bubble_position(40.0, 600.0, 24.0, 88.0)
			var zone_type: String = "left" if randf() < 0.5 else "right"
			var bubble: NumberBubble = bubble_scene.instantiate() as NumberBubble
			bubble_container.add_child(bubble)
			bubble.setup(math_prob.correct_answer, pos, zone_type, GameManager.current_stage)
			_configure_bubble_motion(bubble, 40.0, 600.0)
			bubble.selected.connect(_on_bubble_selected)
			active_bubbles.append(bubble)
			# Pop-in entrance animation
			bubble.scale = Vector2(0.1, 0.1)
			var tween := create_tween()
			tween.tween_property(bubble, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	elif mode == MathConfig.GameMode.RESULT_TO_EQUATION or mode == MathConfig.GameMode.MULTI_OP_EQUATION:
		# Mode 2 & 3: Check operands
		if math_prob.given_operand_index == 0:
			# Operand A is given, user needs operand B on Right
			var has_b: bool = false
			for b in active_bubbles:
				if b.zone == "right" and b.value == math_prob.operand_b:
					has_b = true
					break
			if not has_b:
				_spawn_replenished_bubble(math_prob.operand_b, "right", 360.0, 604.0)

		elif math_prob.given_operand_index == 1:
			# Operand B is given, user needs operand A on Left
			var has_a: bool = false
			for b in active_bubbles:
				if b.zone == "left" and b.value == math_prob.operand_a:
					has_a = true
					break
			if not has_a:
				_spawn_replenished_bubble(math_prob.operand_a, "left", 36.0, 280.0)

		else:
			# Completely open: check if ANY active pair solves it
			var has_solvable_pair: bool = false
			for b1 in active_bubbles:
				for b2 in active_bubbles:
					if b1 != b2:
						if _evaluate_operation(b1.value, b2.value, math_prob.operator_symbol) == math_prob.correct_answer:
							has_solvable_pair = true
							break
				if has_solvable_pair:
					break

			if not has_solvable_pair:
				var has_a: bool = false
				var has_b: bool = false
				for b in active_bubbles:
					if b.zone == "left" and b.value == math_prob.operand_a:
						has_a = true
					if b.zone == "right" and b.value == math_prob.operand_b:
						has_b = true
				if not has_a:
					_spawn_replenished_bubble(math_prob.operand_a, "left", 36.0, 280.0)
				if not has_b:
					_spawn_replenished_bubble(math_prob.operand_b, "right", 360.0, 604.0)


func _spawn_replenished_bubble(val: int, zone_name: String, min_x: float, max_x: float) -> void:
	var pos := _find_free_bubble_position(min_x, max_x, 24.0, 88.0)
	var bubble: NumberBubble = bubble_scene.instantiate() as NumberBubble
	bubble_container.add_child(bubble)
	bubble.setup(val, pos, zone_name, GameManager.current_stage)
	_configure_bubble_motion(bubble, min_x, max_x)
	bubble.selected.connect(_on_bubble_selected)
	active_bubbles.append(bubble)
	bubble.scale = Vector2(0.1, 0.1)
	var tween := create_tween()
	tween.tween_property(bubble, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _find_free_bubble_position(min_x: float, max_x: float, min_y: float = 24.0, max_y: float = 88.0) -> Vector2:
	var best_pos := Vector2(randf_range(min_x, max_x), randf_range(min_y, max_y))
	var best_dist: float = 0.0
	for attempt in range(50):
		var pos := Vector2(randf_range(min_x, max_x), randf_range(min_y, max_y))
		var min_d: float = 9999.0
		for b in active_bubbles:
			if is_instance_valid(b):
				var d: float = b.position.distance_to(pos)
				if d < min_d:
					min_d = d
		if min_d >= min_bubble_spacing:
			return pos
		if min_d > best_dist:
			best_dist = min_d
			best_pos = pos
	return best_pos


func show_choices(choices: Array[int]) -> void:
	if active_custom_method:
		active_custom_method.on_set_started(GameManager.current_stage, choices)
		return

	clear_bubbles()
	_update_bubble_area()
	current_choices = choices
	
	var mode = MathEngine.current_config.game_mode
	var is_equation_mode: bool = (mode == MathConfig.GameMode.RESULT_TO_EQUATION or mode == MathConfig.GameMode.MULTI_OP_EQUATION)
	center_operator_bar.visible = (mode == MathConfig.GameMode.MULTI_OP_EQUATION)
	formula_bar.visible = is_equation_mode
	zone_left_bg.visible = is_equation_mode
	zone_right_bg.visible = is_equation_mode
	center_divider.visible = is_equation_mode
	
	_update_operator_buttons_visibility(mode)
	_reset_formula_display()
	
	if is_equation_mode and choices.size() >= 4:
		# Two-Zone Zahlenschmiede layout: Left (Cyan / Operand A) vs Right (Purple / Operand B)
		var half: int = choices.size() / 2
		var left_choices: Array[int] = choices.slice(0, half)
		var right_choices: Array[int] = choices.slice(half)
		
		var left_positions: Array[Vector2] = _calculate_zoned_positions(left_choices.size(), 36.0, 280.0, 24.0, 88.0)
		for i in range(left_choices.size()):
			var bubble: NumberBubble = bubble_scene.instantiate() as NumberBubble
			bubble_container.add_child(bubble)
			bubble.setup(left_choices[i], left_positions[i], "left", GameManager.current_stage)
			_configure_bubble_motion(bubble, 36.0, 280.0)
			bubble.selected.connect(_on_bubble_selected)
			active_bubbles.append(bubble)
			
		var right_positions: Array[Vector2] = _calculate_zoned_positions(right_choices.size(), 360.0, 604.0, 24.0, 88.0)
		for i in range(right_choices.size()):
			var bubble: NumberBubble = bubble_scene.instantiate() as NumberBubble
			bubble_container.add_child(bubble)
			bubble.setup(right_choices[i], right_positions[i], "right", GameManager.current_stage)
			_configure_bubble_motion(bubble, 360.0, 604.0)
			bubble.selected.connect(_on_bubble_selected)
			active_bubbles.append(bubble)
	else:
		# Single playfield layout (Mode 1 / Rechen-Schlag)
		var positions: Array[Vector2] = _calculate_zoned_positions(choices.size(), 40.0, 600.0, 24.0, 88.0)
		for i in range(choices.size()):
			var bubble: NumberBubble = bubble_scene.instantiate() as NumberBubble
			bubble_container.add_child(bubble)
			var zone_type: String = "left" if (i % 2 == 0) else "right"
			bubble.setup(choices[i], positions[i], zone_type, GameManager.current_stage)
			_configure_bubble_motion(bubble, 40.0, 600.0)
			bubble.selected.connect(_on_bubble_selected)
			active_bubbles.append(bubble)


func _calculate_zoned_positions(count: int, min_x: float, max_x: float, min_y: float = 24.0, max_y: float = 88.0) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	
	for i in range(count):
		var pos: Vector2 = Vector2.ZERO
		var best_pos: Vector2 = Vector2.ZERO
		var best_dist: float = 0.0
		var found_valid: bool = false
		
		for attempt in range(100):
			pos = Vector2(
				randf_range(min_x, max_x),
				randf_range(min_y, max_y)
			)
			var min_dist: float = 9999.0
			for p in positions:
				var d: float = p.distance_to(pos)
				if d < min_dist:
					min_dist = d
			
			if min_dist >= min_bubble_spacing:
				positions.append(pos)
				found_valid = true
				break
			elif min_dist > best_dist:
				best_dist = min_dist
				best_pos = pos
				
		if not found_valid:
			positions.append(best_pos if best_pos != Vector2.ZERO else pos)
		
	return positions


func _update_operator_buttons_visibility(mode) -> void:
	if mode == MathConfig.GameMode.MULTI_OP_EQUATION:
		center_operator_bar.visible = true
		op_btn_add.visible = true
		op_btn_sub.visible = true
		op_btn_mul.visible = true
		op_btn_div.visible = true
	else:
		center_operator_bar.visible = false
	_highlight_active_operator()


func _set_active_operator(op: String) -> void:
	_current_op_symbol = op
	_highlight_active_operator()
	_update_formula_label()


func _highlight_active_operator() -> void:
	_style_op_btn(op_btn_add, _current_op_symbol == "+")
	_style_op_btn(op_btn_sub, _current_op_symbol == "-")
	_style_op_btn(op_btn_mul, _current_op_symbol == "×" or _current_op_symbol == "x")
	_style_op_btn(op_btn_div, _current_op_symbol == "÷" or _current_op_symbol == "/")


func _style_op_btn(btn: Button, is_active: bool) -> void:
	if is_active:
		btn.modulate = Color(1.8, 1.4, 0.4)
	else:
		btn.modulate = Color(0.7, 0.7, 0.75)


func clear_bubbles() -> void:
	for bubble in active_bubbles:
		if is_instance_valid(bubble):
			bubble.queue_free()
	active_bubbles.clear()
	_first_operand = -1
	_first_bubble = null


func _reset_formula_display() -> void:
	_first_bubble = null
	_second_bubble = null
	_first_operand = -1
	_second_operand = -1
	_first_operand_is_prefilled = false
	_second_operand_is_prefilled = false

	if _current_math_problem != null:
		if MathEngine.current_config.game_mode == MathConfig.GameMode.RESULT_TO_EQUATION:
			if _current_math_problem.given_operand_index == 0:
				_first_operand = _current_math_problem.operand_a
				_first_operand_is_prefilled = true
			elif _current_math_problem.given_operand_index == 1:
				_second_operand_is_prefilled = true

	_update_formula_label()


func _update_formula_label() -> void:
	if _current_math_problem != null and _current_math_problem.is_three_operand and _current_math_problem.given_operand_index == -2:
		var op1 = _current_op_symbol
		var op2 = _current_math_problem.operator_symbol_2 if _current_math_problem.operator_symbol_2 != "" else "+"
		var a_str = "[ " + str(_first_operand) + " ]" if _first_operand != -1 else "▶ [ ? ] ◀"
		var b_str = "[ " + str(_second_operand) + " ]" if _second_operand != -1 else ("[ ? ]" if _first_operand == -1 else "▶ [ ? ] ◀")
		var c_str = "[ ? ]" if (_first_operand == -1 or _second_operand == -1) else "▶ [ ? ] ◀"
		formula_bar.text = "%s  %s  %s  %s  %s  =  %d" % [a_str, op1, b_str, op2, c_str, _current_target_result]
		return

	if _first_operand_is_prefilled:
		formula_bar.text = "[ " + str(_first_operand) + " ]  " + _current_op_symbol + "  ▶ [ ? ] ◀  =  " + str(_current_target_result)
	elif _second_operand_is_prefilled and _current_math_problem != null:
		if _first_operand != -1:
			formula_bar.text = "[ " + str(_first_operand) + " ]  " + _current_op_symbol + "  [ " + str(_current_math_problem.operand_b) + " ]  =  " + str(_current_target_result)
		else:
			formula_bar.text = "▶ [ ? ] ◀  " + _current_op_symbol + "  [ " + str(_current_math_problem.operand_b) + " ]  =  " + str(_current_target_result)
	else:
		if _first_operand != -1:
			formula_bar.text = "[ " + str(_first_operand) + " ]  " + _current_op_symbol + "  ▶ [ ? ] ◀  =  " + str(_current_target_result)
		else:
			formula_bar.text = "▶ [ ? ] ◀  " + _current_op_symbol + "  [ ? ]  =  " + str(_current_target_result)


func _on_bubble_selected(value: int, method: String, bubble: Area2D, slice_dir: Vector2) -> void:
	if has_node("/root/GameManager") and get_node("/root/GameManager").is_in_countdown:
		return

	var mode = MathEngine.current_config.game_mode
	if mode == MathConfig.GameMode.RESULT_TO_EQUATION or (mode == MathConfig.GameMode.MULTI_OP_EQUATION and _current_math_problem != null and _current_math_problem.given_operand_index == -2):
		_handle_equation_selection(value, method, bubble, slice_dir)
	else:
		EventBus.answer_selected.emit(value, method, bubble, slice_dir)


func _handle_equation_selection(value: int, method: String, bubble: Area2D, slice_dir: Vector2) -> void:
	# CASE 0: 3-OPERAND CHAIN SELECTION (Meister-Kette Type B)
	if _current_math_problem != null and _current_math_problem.is_three_operand and _current_math_problem.given_operand_index == -2:
		if _first_operand == -1:
			_first_operand = value
			_first_bubble = bubble
			_update_formula_label()
			if is_instance_valid(bubble):
				var tween: Tween = create_tween()
				tween.tween_property(bubble, "scale", Vector2(1.25, 1.25), 0.08)
				tween.tween_property(bubble, "scale", Vector2.ONE, 0.1)
		elif _second_operand == -1:
			if bubble == _first_bubble:
				return
			_second_operand = value
			_second_bubble = bubble
			_update_formula_label()
			if is_instance_valid(bubble):
				var tween: Tween = create_tween()
				tween.tween_property(bubble, "scale", Vector2(1.25, 1.25), 0.08)
				tween.tween_property(bubble, "scale", Vector2.ONE, 0.1)
		else:
			var third_operand: int = value
			var third_bubble: Area2D = bubble
			if third_bubble == _first_bubble or third_bubble == _second_bubble:
				return

			var op1 = _current_op_symbol
			var op2 = _current_math_problem.operator_symbol_2 if _current_math_problem.operator_symbol_2 != "" else "+"
			var calculated_result: int = _evaluate_three_operation(_first_operand, _second_operand, third_operand, op1, op2)

			if calculated_result == _current_target_result:
				formula_bar.text = "[ %d ] %s [ %d ] %s [ %d ] = %d ✓" % [_first_operand, op1, _second_operand, op2, third_operand, _current_target_result]
				if is_instance_valid(_first_bubble) and _first_bubble.has_method("pop_and_slice"):
					_first_bubble.pop_and_slice(slice_dir)
				if is_instance_valid(_second_bubble) and _second_bubble.has_method("pop_and_slice"):
					_second_bubble.pop_and_slice(slice_dir)
				if is_instance_valid(third_bubble) and third_bubble.has_method("pop_and_slice"):
					third_bubble.pop_and_slice(slice_dir)

				EventBus.answer_selected.emit(_current_target_result, method, null, slice_dir)
				_first_operand = -1
				_second_operand = -1
				_first_bubble = null
				_second_bubble = null
			else:
				formula_bar.text = "[ %d ] %s [ %d ] %s [ %d ] ≠ %d ✗" % [_first_operand, op1, _second_operand, op2, third_operand, _current_target_result]
				if is_instance_valid(_first_bubble) and _first_bubble.has_method("play_wrong_anim"):
					_first_bubble.play_wrong_anim()
				if is_instance_valid(_second_bubble) and _second_bubble.has_method("play_wrong_anim"):
					_second_bubble.play_wrong_anim()
				if is_instance_valid(third_bubble) and third_bubble.has_method("play_wrong_anim"):
					third_bubble.play_wrong_anim()

				EventBus.answer_selected.emit(-999, method, null, slice_dir)
				_first_operand = -1
				_second_operand = -1
				_first_bubble = null
				_second_bubble = null
				var timer: SceneTreeTimer = get_tree().create_timer(0.45)
				timer.timeout.connect(_reset_formula_display)
		return

	# CASE 1: Operand A was prefilled — user picks operand B
	if _first_operand_is_prefilled:
		var operand_a: int = _first_operand
		var operand_b: int = value
		var calculated_result: int = _evaluate_operation(operand_a, operand_b, _current_op_symbol)
		
		if calculated_result == _current_target_result:
			formula_bar.text = "[ " + str(operand_a) + " ]  " + _current_op_symbol + "  [ " + str(operand_b) + " ]  =  " + str(_current_target_result) + "  ✓"
			if is_instance_valid(bubble):
				if method == "swipe" and bubble.has_method("pop_and_slice"):
					bubble.pop_and_slice(slice_dir)
				elif bubble.has_method("pop_and_tap"):
					bubble.pop_and_tap()

			EventBus.answer_selected.emit(_current_target_result, method, null, slice_dir)
		else:
			formula_bar.text = "[ " + str(operand_a) + " ]  " + _current_op_symbol + "  [ " + str(operand_b) + " ]  ≠  " + str(_current_target_result) + "  ✗"
			if is_instance_valid(bubble) and bubble.has_method("play_wrong_anim"):
				bubble.play_wrong_anim()
			EventBus.answer_selected.emit(-999, method, null, slice_dir)
			var timer: SceneTreeTimer = get_tree().create_timer(0.45)
			timer.timeout.connect(_reset_formula_display)
		return

	# CASE 2: Operand B was prefilled — user picks operand A
	if _second_operand_is_prefilled and _current_math_problem != null:
		var operand_a: int = value
		var operand_b: int = _current_math_problem.operand_b
		var calculated_result: int = _evaluate_operation(operand_a, operand_b, _current_op_symbol)
		
		if calculated_result == _current_target_result:
			formula_bar.text = "[ " + str(operand_a) + " ]  " + _current_op_symbol + "  [ " + str(operand_b) + " ]  =  " + str(_current_target_result) + "  ✓"
			if is_instance_valid(bubble):
				if method == "swipe" and bubble.has_method("pop_and_slice"):
					bubble.pop_and_slice(slice_dir)
				elif bubble.has_method("pop_and_tap"):
					bubble.pop_and_tap()

			EventBus.answer_selected.emit(_current_target_result, method, null, slice_dir)
		else:
			formula_bar.text = "[ " + str(operand_a) + " ]  " + _current_op_symbol + "  [ " + str(operand_b) + " ]  ≠  " + str(_current_target_result) + "  ✗"
			if is_instance_valid(bubble) and bubble.has_method("play_wrong_anim"):
				bubble.play_wrong_anim()
			EventBus.answer_selected.emit(-999, method, null, slice_dir)
			var timer: SceneTreeTimer = get_tree().create_timer(0.45)
			timer.timeout.connect(_reset_formula_display)
		return

	# CASE 3: Completely open equation — user picks both operands sequentially
	if _first_operand == -1:
		_first_operand = value
		_first_bubble = bubble
		formula_bar.text = "[ " + str(_first_operand) + " ]  " + _current_op_symbol + "  ▶ [ ? ] ◀  =  " + str(_current_target_result)
		
		if is_instance_valid(bubble):
			var tween: Tween = create_tween()
			tween.tween_property(bubble, "scale", Vector2(1.25, 1.25), 0.08)
			tween.tween_property(bubble, "scale", Vector2.ONE, 0.1)
	else:
		var second_operand: int = value
		var second_bubble: Area2D = bubble
		
		if second_bubble == _first_bubble:
			return

		var calculated_result: int = _evaluate_operation(_first_operand, second_operand, _current_op_symbol)
		
		if calculated_result == _current_target_result:
			formula_bar.text = "[ " + str(_first_operand) + " ]  " + _current_op_symbol + "  [ " + str(second_operand) + " ]  =  " + str(_current_target_result) + "  ✓"
			
			if is_instance_valid(_first_bubble) and _first_bubble.has_method("pop_and_slice"):
				_first_bubble.pop_and_slice(slice_dir)
			if is_instance_valid(second_bubble) and second_bubble.has_method("pop_and_slice"):
				second_bubble.pop_and_slice(slice_dir)

			EventBus.answer_selected.emit(_current_target_result, method, null, slice_dir)
			_first_operand = -1
			_first_bubble = null
		else:
			formula_bar.text = "[ " + str(_first_operand) + " ]  " + _current_op_symbol + "  [ " + str(second_operand) + " ]  ≠  " + str(_current_target_result) + "  ✗"
			if is_instance_valid(_first_bubble) and _first_bubble.has_method("play_wrong_anim"):
				_first_bubble.play_wrong_anim()
			if is_instance_valid(second_bubble) and second_bubble.has_method("play_wrong_anim"):
				second_bubble.play_wrong_anim()

			EventBus.answer_selected.emit(-999, method, null, slice_dir)
			_first_operand = -1
			_first_bubble = null
			var timer: SceneTreeTimer = get_tree().create_timer(0.45)
			timer.timeout.connect(_reset_formula_display)


func _evaluate_operation(a: int, b: int, op: String) -> int:
	match op:
		"+": return a + b
		"-": return a - b
		"×", "x", "*": return a * b
		"÷", "/": return (a / b) if b != 0 else -9999
		_: return a + b


func _evaluate_three_operation(a: int, b: int, c: int, op1: String, op2: String) -> int:
	if op1 in ["×", "x", "*"]:
		var ab = a * b
		match op2:
			"+": return ab + c
			"-": return ab - c
			_: return ab + c
	elif op1 in ["÷", "/"]:
		var ab = int(a / max(b, 1))
		match op2:
			"+": return ab + c
			"-": return ab - c
			_: return ab + c
	else:
		if op2 in ["×", "x", "*"]:
			var bc = b * c
			match op1:
				"+": return a + bc
				"-": return a - bc
				_: return a + bc
		elif op2 in ["÷", "/"]:
			var bc = int(b / max(c, 1))
			match op1:
				"+": return a + bc
				"-": return a - bc
				_: return a + bc
		else:
			var ab = (a + b) if op1 == "+" else (a - b)
			return (ab + c) if op2 == "+" else (ab - c)
