class_name InputMethodBase
extends Control
## Base class for all modular input methods in MathKnight.
## Manages problem presentation, answer submission, and visual feedback hooks.

signal answer_submitted(value: int, method: String, extra_data: Dictionary)

var current_problem: RefCounted = null
var current_config: Resource = null
var is_active: bool = false


func setup(config: Resource) -> void:
	current_config = config


func on_problem_presented(problem: RefCounted) -> void:
	current_problem = problem
	is_active = true


func on_set_started(_set_num: int, _pool: Array[int]) -> void:
	pass


func on_answer_evaluated(is_correct: bool) -> void:
	if is_correct:
		play_correct_feedback()
	else:
		play_wrong_feedback()


func play_correct_feedback() -> void:
	pass


func play_wrong_feedback() -> void:
	pass


func is_in_countdown() -> bool:
	if is_inside_tree() and get_tree().root.has_node("GameManager"):
		return get_node("/root/GameManager").is_in_countdown
	return false


func submit_answer(value: int, method_name: String = "custom", extra_data: Dictionary = {}) -> void:
	if not is_active or is_in_countdown():
		return
	answer_submitted.emit(value, method_name, extra_data)


func clean_up() -> void:
	is_active = false
