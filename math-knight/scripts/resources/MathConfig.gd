class_name MathConfig
extends Resource

enum GameMode { TASK_TO_RESULT, RESULT_TO_EQUATION, MULTI_OP_EQUATION }
enum Operation { ADDITION, SUBTRACTION, MULTIPLICATION, DIVISION, MIXED }
enum Difficulty { EASY, MEDIUM, HARD }
enum InputDifficulty { EASY, MEDIUM, HARD }
enum InputType {
	BUBBLES,
	BUBBLES_MOVING,
	BUBBLES_LIVING,
	HANDWRITING,
	QUICK_TAP,
	HOLD_STRETCH,
	TIMING_BAR,
	NUMBER_WHEEL,
	KEYPAD
}

@export var game_mode: GameMode = GameMode.TASK_TO_RESULT
@export var operation: Operation = Operation.ADDITION
@export var difficulty: Difficulty = Difficulty.EASY
@export var input_difficulty: InputDifficulty = InputDifficulty.EASY
@export var input_type: InputType = InputType.BUBBLES

@export var min_operand: int = 1
@export var max_operand: int = 9
@export var max_result: int = 9
@export var num_choices: int = 4
@export var set_size: int = 5
@export var bubble_pool_size: int = 10
@export var allow_negative_results: bool = false
@export var distractor_strategy: String = "smart"

static func create_config(p_mode: GameMode, p_op: Operation, p_diff: Difficulty, p_input: InputType = InputType.BUBBLES, p_input_diff: InputDifficulty = InputDifficulty.EASY) -> MathConfig:
	var cfg: MathConfig = MathConfig.new()
	cfg.game_mode = p_mode
	cfg.operation = p_op
	cfg.difficulty = p_diff
	cfg.input_type = p_input
	cfg.input_difficulty = p_input_diff
	cfg.num_choices = 4
	cfg.set_size = 5
	cfg.bubble_pool_size = 12 if p_mode == GameMode.MULTI_OP_EQUATION else 10

	match p_diff:
		Difficulty.EASY:
			cfg.min_operand = 1
			cfg.max_operand = 10
			cfg.max_result = 20
			if p_op == Operation.SUBTRACTION:
				cfg.min_operand = 1
				cfg.max_operand = 10
				cfg.max_result = 10
			elif p_op == Operation.MULTIPLICATION:
				cfg.min_operand = 2
				cfg.max_operand = 5
				cfg.max_result = 25
			elif p_op == Operation.DIVISION:
				cfg.min_operand = 2
				cfg.max_operand = 5
				cfg.max_result = 5
			elif p_mode == GameMode.MULTI_OP_EQUATION:
				cfg.min_operand = 1
				cfg.max_operand = 10
				cfg.max_result = 20

		Difficulty.MEDIUM:
			cfg.min_operand = 5
			cfg.max_operand = 40
			cfg.max_result = 80
			if p_op == Operation.SUBTRACTION:
				cfg.min_operand = 4
				cfg.max_operand = 50
				cfg.max_result = 50
			elif p_op == Operation.MULTIPLICATION:
				cfg.min_operand = 2
				cfg.max_operand = 10
				cfg.max_result = 100
			elif p_op == Operation.DIVISION:
				cfg.min_operand = 2
				cfg.max_operand = 10
				cfg.max_result = 10
			elif p_mode == GameMode.MULTI_OP_EQUATION:
				cfg.min_operand = 2
				cfg.max_operand = 20
				cfg.max_result = 50

		Difficulty.HARD:
			cfg.min_operand = 15
			cfg.max_operand = 75
			cfg.max_result = 120
			if p_op == Operation.SUBTRACTION:
				cfg.min_operand = 12
				cfg.max_operand = 100
				cfg.max_result = 100
			elif p_op == Operation.MULTIPLICATION:
				cfg.min_operand = 2
				cfg.max_operand = 16
				cfg.max_result = 144
			elif p_op == Operation.DIVISION:
				cfg.min_operand = 3
				cfg.max_operand = 16
				cfg.max_result = 16
			elif p_mode == GameMode.MULTI_OP_EQUATION:
				cfg.min_operand = 3
				cfg.max_operand = 30
				cfg.max_result = 100

	return cfg
