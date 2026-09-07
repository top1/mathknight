extends Node
## GameManager singleton — manages game state, score, combos, multi-slice chains,
## difficulty progression, detailed run statistics, persistent high scores,
## and gold/currency drops for the roguelike system.

enum GameState { READY, PLAYING, PAUSED, GAME_OVER, VICTORY, TITLE_SCREEN, MAP, SHOP, CHEST_OPENING }

const TOTAL_STAGES: int = 11
const SAVE_PATH: String = "user://mathknight_data.cfg"

const STAGE_CONFIGS: Array[Dictionary] = [
	{"enemies": 3, "pool": 8, "speed": 36.0, "damage": 1.0, "interval": 2.2},
	{"enemies": 3, "pool": 8, "speed": 38.0, "damage": 1.0, "interval": 2.1},
	{"enemies": 4, "pool": 9, "speed": 40.0, "damage": 1.0, "interval": 2.0},
	{"enemies": 4, "pool": 9, "speed": 43.0, "damage": 1.1, "interval": 1.9},
	{"enemies": 5, "pool": 10, "speed": 46.0, "damage": 1.2, "interval": 1.8},
	{"enemies": 5, "pool": 10, "speed": 49.0, "damage": 1.2, "interval": 1.7},
	{"enemies": 6, "pool": 12, "speed": 52.0, "damage": 1.3, "interval": 1.6},
	{"enemies": 6, "pool": 12, "speed": 55.0, "damage": 1.4, "interval": 1.5},
	{"enemies": 7, "pool": 14, "speed": 58.0, "damage": 1.5, "interval": 1.4},
	{"enemies": 8, "pool": 16, "speed": 61.0, "damage": 1.6, "interval": 1.35},
	{"enemies": 9, "pool": 18, "speed": 64.0, "damage": 1.8, "interval": 1.3},
	{"enemies": 10, "pool": 20, "speed": 68.0, "damage": 2.0, "interval": 1.2},
]

# === Gold Drop Configuration ===
const GOLD_COMBO_3: int = 1
const GOLD_COMBO_5: int = 3
const GOLD_COMBO_10: int = 5
const GOLD_FLAWLESS_SET: int = 10

var state: GameState = GameState.READY
var score: int = 0
var combo: int = 0
var wave: int = 1
var current_stroke_chain: int = 0
var current_problem: MathProblem = null
var current_stage: int = 1

# Run statistics
var _run_start_msec: int = 0
var _problem_start_msec: int = 0
var last_answer_time_sec: float = 2.0
var fastest_answer_time: float = 999.0
var total_answer_time: float = 0.0
var correct_answers_count: int = 0
var wrong_answers_count: int = 0
var max_combo: int = 0
var total_enemies_defeated: int = 0
var total_run_time_sec: float = 0.0
var is_victory: bool = false
var is_new_highscore: bool = false

# Set tracking for flawless detection
var _current_set_errors: int = 0
var _current_set_number: int = 0

# Boss mode tracking
var is_boss_fight: bool = false
var boss_node_data: Dictionary = {}
var is_in_countdown: bool = false


func _ready() -> void:
	EventBus.problem_presented.connect(_on_problem_presented)
	EventBus.answer_selected.connect(_on_answer_selected)
	EventBus.stroke_ended.connect(_on_stroke_ended)
	EventBus.enemy_defeated.connect(_on_enemy_defeated)
	EventBus.enemy_reached_knight.connect(_on_enemy_reached_knight)
	EventBus.knight_died.connect(_on_knight_died)
	EventBus.set_started.connect(_on_set_started)
	EventBus.set_cleared.connect(_on_set_cleared)
	EventBus.countdown_tick.connect(_on_countdown_tick)


func get_stage_config(stage_num: int) -> Dictionary:
	var idx: int = clamp(stage_num - 1, 0, STAGE_CONFIGS.size() - 1)
	return STAGE_CONFIGS[idx]


func start_game() -> void:
	state = GameState.PLAYING
	is_in_countdown = true
	score = 0
	combo = 0
	wave = 1
	current_stage = 1
	current_stroke_chain = 0
	_current_set_errors = 0
	_current_set_number = 0
	is_boss_fight = false
	boss_node_data = {}

	_run_start_msec = Time.get_ticks_msec()
	_problem_start_msec = Time.get_ticks_msec()
	fastest_answer_time = 999.0
	total_answer_time = 0.0
	correct_answers_count = 0
	wrong_answers_count = 0
	max_combo = 0
	total_enemies_defeated = 0
	total_run_time_sec = 0.0
	is_victory = false
	is_new_highscore = false

	EventBus.game_state_changed.emit("PLAYING")
	EventBus.stage_changed.emit(current_stage, TOTAL_STAGES)


## Start a boss fight with the given node data from RunManager
func start_boss_fight(node_data: Dictionary) -> void:
	is_boss_fight = true
	boss_node_data = node_data
	start_game()
	EventBus.boss_spawned.emit(node_data)


func pause_game() -> void:
	if state == GameState.PLAYING:
		state = GameState.PAUSED
		get_tree().paused = true
		EventBus.game_state_changed.emit("PAUSED")


func resume_game() -> void:
	if state == GameState.PAUSED:
		state = GameState.PLAYING
		get_tree().paused = false
		EventBus.game_state_changed.emit("PLAYING")


func end_game() -> void:
	if state == GameState.GAME_OVER or state == GameState.VICTORY:
		return
	is_in_countdown = false
	state = GameState.GAME_OVER
	is_victory = false
	_finalize_run_stats()
	EventBus.game_state_changed.emit("GAME_OVER")


func trigger_victory() -> void:
	if state == GameState.GAME_OVER or state == GameState.VICTORY:
		return
	state = GameState.VICTORY
	is_victory = true
	_finalize_run_stats()
	EventBus.game_won.emit(get_run_statistics())


func _finalize_run_stats() -> void:
	total_run_time_sec = float(Time.get_ticks_msec() - _run_start_msec) / 1000.0
	var prev_high = get_high_score()
	if score > prev_high:
		is_new_highscore = true
		save_high_score(score)
	else:
		is_new_highscore = false

	# Update RunManager score
	if has_node("/root/RunManager"):
		var rm: Node = get_node("/root/RunManager")
		if rm.is_run_active:
			rm.run_score += score


func get_run_statistics() -> Dictionary:
	var avg_time: float = 0.0
	if correct_answers_count > 0:
		avg_time = total_answer_time / float(correct_answers_count)

	var total_answers: int = correct_answers_count + wrong_answers_count
	var accuracy_pct: float = 0.0
	if total_answers > 0:
		accuracy_pct = (float(correct_answers_count) / float(total_answers)) * 100.0

	var best_speed: float = fastest_answer_time if fastest_answer_time < 900.0 else 0.0

	return {
		"is_victory": is_victory,
		"score": score,
		"high_score": max(score, get_high_score()),
		"is_new_highscore": is_new_highscore,
		"current_stage": current_stage,
		"total_stages": TOTAL_STAGES,
		"fastest_answer_time": best_speed,
		"average_answer_time": avg_time,
		"accuracy": accuracy_pct,
		"correct_count": correct_answers_count,
		"wrong_count": wrong_answers_count,
		"max_combo": max_combo,
		"enemies_defeated": total_enemies_defeated,
		"run_time_sec": total_run_time_sec
	}


func get_high_score() -> int:
	var config: ConfigFile = ConfigFile.new()
	var err: Error = config.load(SAVE_PATH)
	if err == OK:
		return config.get_value("highscore", "best_score", 0)
	return 0


func save_high_score(new_score: int) -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(SAVE_PATH)
	var current_best: int = config.get_value("highscore", "best_score", 0)
	if new_score > current_best:
		config.set_value("highscore", "best_score", new_score)
		config.save(SAVE_PATH)


func _on_problem_presented(_problem: RefCounted) -> void:
	_problem_start_msec = Time.get_ticks_msec()


func _on_stroke_ended() -> void:
	current_stroke_chain = 0


func _on_set_started(set_number: int, _bubble_pool: Array[int]) -> void:
	_current_set_number = set_number
	_current_set_errors = 0
	is_in_countdown = true


func _on_countdown_tick(count_text: String) -> void:
	if count_text.begins_with("⚔️") or count_text.contains("LOS"):
		is_in_countdown = false
	else:
		is_in_countdown = true


func _on_set_cleared(set_number: int) -> void:
	# Check for flawless set
	if _current_set_errors == 0:
		EventBus.flawless_set_achieved.emit(set_number)
		# Drop gold for flawless
		_drop_gold(GOLD_FLAWLESS_SET, "Perfektes Set!")


func _on_answer_selected(value: int, method: String, bubble: Area2D, slice_dir: Vector2) -> void:
	if state != GameState.PLAYING or is_in_countdown:
		return
	if current_problem == null:
		return

	if value == current_problem.correct_answer:
		# CORRECT ANSWER!
		var elapsed_sec: float = float(Time.get_ticks_msec() - _problem_start_msec) / 1000.0
		last_answer_time_sec = elapsed_sec
		if elapsed_sec >= 0.05 and elapsed_sec < fastest_answer_time:
			fastest_answer_time = elapsed_sec
		total_answer_time += elapsed_sec
		correct_answers_count += 1

		current_stroke_chain += 1
		combo += 1
		if combo > max_combo:
			max_combo = combo

		# Multiplier grows with chain stroke and combo
		var chain_multiplier: int = current_stroke_chain
		var points: int = (15 + (combo * 5)) * chain_multiplier
		score += points

		EventBus.score_changed.emit(score)
		EventBus.combo_changed.emit(combo)

		# === Gold Drop Logic ===
		_check_combo_gold_drop(combo)

		# Pop bubble smoothly
		if is_instance_valid(bubble):
			if method == "swipe" and bubble.has_method("pop_and_slice"):
				bubble.pop_and_slice(slice_dir)
			elif bubble.has_method("pop_and_tap"):
				bubble.pop_and_tap()

		EventBus.answer_correct.emit(current_problem, current_stroke_chain)
	else:
		# WRONG ANSWER!
		wrong_answers_count += 1
		_current_set_errors += 1
		current_stroke_chain = 0
		combo = 0
		EventBus.combo_changed.emit(0)

		if is_instance_valid(bubble) and bubble.has_method("play_wrong_anim"):
			bubble.play_wrong_anim()

		EventBus.enemy_attacks_knight.emit(1.0)
		EventBus.answer_wrong.emit(current_problem)


func _check_combo_gold_drop(current_combo: int) -> void:
	if current_combo >= 10:
		_drop_gold(GOLD_COMBO_10, "Combo x" + str(current_combo))
	elif current_combo >= 5:
		_drop_gold(GOLD_COMBO_5, "Combo x" + str(current_combo))
	elif current_combo >= 3:
		_drop_gold(GOLD_COMBO_3, "Combo x" + str(current_combo))


func _drop_gold(amount: int, reason: String) -> void:
	# Apply wisdom multiplier if SaveManager exists
	var final_amount: int = amount
	if has_node("/root/SaveManager"):
		final_amount = int(float(amount) * get_node("/root/SaveManager").get_gold_multiplier())

	# Add to RunManager if in a run
	if has_node("/root/RunManager"):
		var rm: Node = get_node("/root/RunManager")
		if rm.is_run_active:
			rm.add_run_gold(final_amount, reason)
			return

	# Fallback: just emit the signal
	EventBus.gold_earned.emit(final_amount, reason)


func _on_enemy_defeated(_enemy: Node2D) -> void:
	total_enemies_defeated += 1


func _on_enemy_reached_knight(_enemy: Node2D) -> void:
	combo = 0
	EventBus.combo_changed.emit(combo)


func _on_knight_died() -> void:
	end_game()
