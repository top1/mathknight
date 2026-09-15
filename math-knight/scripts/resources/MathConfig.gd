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

## Didactic Curriculum Levels (GDD Progression L1..L6)
enum CurriculumLevel {
	NONE,
	L1_BASIS_10,             ## 1-10: Addition, Subtraction, Verliebte Zahlen, Verdoppeln/Halbieren
	L2_BIS_20_OHNE_UEBERGANG,## 1-20: Addition & Subtraktion OHNE Zehnerübergang (12+5, 17-4)
	L3_ZEHNERUEBERGANG_ZEIT, ## Zehnerübergang (8+7, 15-9) & Uhrzeiten
	L4_HUNDERTER_SCHRITTE,   ## Bis 100: Schrittweises Zählen & Rechnen (+5, -5, +10, -10)
	L5_EINMALEINS,           ## Kleines 1x1 (1x1 bis 10x10) & wiederholte Addition
	L6_DIVISION              ## Division als Umkehrung des 1x1
}

## Didactic Subtypes for targeted practice
enum CurriculumSubtype {
	STANDARD,            ## Mixed practice matching the level
	VERLIEBTE_ZAHLEN,    ## Pairs that sum to 10, or 10 - a = b (L1)
	VERDOPPELN_HALBIEREN,## *2 / /2 (L1)
	OHNE_UEBERGANG,      ## No decade crossing (L2)
	MIT_UEBERGANG,       ## With decade crossing (L3)
	UHRZEIT_ZEITSPANNE,  ## Clock & time elapsed calculations (L3)
	SCHRITTWEISE_5_10,   ## Jumps of 5 and 10 (L4)
	REIHEN_TRAINING,     ## Specific 1x1 table (e.g. 7er-Reihe) (L5)
	UMKEHRAUFGABEN       ## 3*4=12 -> 12/3=? (L6)
}

## Environment & Gameplay context
enum GameContext {
	COMBAT,     ## Normal combat: timer runs, combos, enemy attacks
	TRAINING,   ## Trainingsplatz: NO time pressure, friendly hints, unlimited retries
	MINIGAME,   ## Specific village profession station (Baker, Blacksmith, etc.)
	ASSESSMENT  ## Diagnostic placement test
}

@export var game_mode: GameMode = GameMode.TASK_TO_RESULT
@export var operation: Operation = Operation.ADDITION
@export var difficulty: Difficulty = Difficulty.EASY
@export var input_difficulty: InputDifficulty = InputDifficulty.EASY
@export var input_type: InputType = InputType.BUBBLES

## Curriculum settings
@export var curriculum_level: CurriculumLevel = CurriculumLevel.NONE
@export var curriculum_subtype: CurriculumSubtype = CurriculumSubtype.STANDARD
@export var game_context: GameContext = GameContext.COMBAT
@export var target_times_table: int = 0  ## 1..10 for specific 1x1 table practice

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
			# Addition (default): keep operands ≤5 so results stay ≤10
			cfg.min_operand = 1
			cfg.max_operand = 5
			cfg.max_result = 10
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
				cfg.max_operand = 5
				cfg.max_result = 10

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


static func create_curriculum_config(
	p_level: CurriculumLevel,
	p_subtype: CurriculumSubtype = CurriculumSubtype.STANDARD,
	p_context: GameContext = GameContext.TRAINING,
	p_mode: GameMode = GameMode.TASK_TO_RESULT,
	p_input: InputType = InputType.BUBBLES
) -> MathConfig:
	var cfg: MathConfig = MathConfig.new()
	cfg.curriculum_level = p_level
	cfg.curriculum_subtype = p_subtype
	cfg.game_context = p_context
	cfg.game_mode = p_mode
	cfg.input_type = p_input
	cfg.num_choices = 4
	cfg.set_size = 5
	cfg.bubble_pool_size = 12 if p_mode == GameMode.MULTI_OP_EQUATION else 10

	match p_level:
		CurriculumLevel.L1_BASIS_10:
			cfg.difficulty = Difficulty.EASY
			cfg.min_operand = 1
			cfg.max_operand = 9
			cfg.max_result = 10
			if p_subtype == CurriculumSubtype.VERLIEBTE_ZAHLEN:
				cfg.operation = Operation.ADDITION
			elif p_subtype == CurriculumSubtype.VERDOPPELN_HALBIEREN:
				cfg.operation = Operation.ADDITION
			else:
				cfg.operation = Operation.MIXED

		CurriculumLevel.L2_BIS_20_OHNE_UEBERGANG:
			cfg.difficulty = Difficulty.EASY
			cfg.min_operand = 1
			cfg.max_operand = 19
			cfg.max_result = 20
			cfg.operation = Operation.MIXED

		CurriculumLevel.L3_ZEHNERUEBERGANG_ZEIT:
			cfg.difficulty = Difficulty.MEDIUM
			cfg.min_operand = 2
			cfg.max_operand = 18
			cfg.max_result = 20
			cfg.operation = Operation.MIXED

		CurriculumLevel.L4_HUNDERTER_SCHRITTE:
			cfg.difficulty = Difficulty.MEDIUM
			cfg.min_operand = 1
			cfg.max_operand = 99
			cfg.max_result = 100
			cfg.operation = Operation.MIXED

		CurriculumLevel.L5_EINMALEINS:
			cfg.difficulty = Difficulty.MEDIUM
			cfg.min_operand = 1
			cfg.max_operand = 10
			cfg.max_result = 100
			cfg.operation = Operation.MULTIPLICATION

		CurriculumLevel.L6_DIVISION:
			cfg.difficulty = Difficulty.MEDIUM
			cfg.min_operand = 1
			cfg.max_operand = 10
			cfg.max_result = 100
			cfg.operation = Operation.DIVISION

		_:
			cfg.difficulty = Difficulty.EASY
			cfg.min_operand = 1
			cfg.max_operand = 10
			cfg.max_result = 20
			cfg.operation = Operation.ADDITION

	return cfg
