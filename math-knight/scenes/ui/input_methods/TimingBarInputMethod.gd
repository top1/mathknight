class_name TimingBarInputMethod
extends "res://scenes/ui/input_methods/InputMethodBase.gd"
## Timing Bar input method (Oscillating Precision Blade).
## A blade sweeps across discrete number notches; click/tap to stop it on the correct number!

@onready var prompt_label: Label = $HeaderBar/PromptLabel
@onready var track_panel: ColorRect = $TrackArea/TrackPanel
@onready var blade_indicator: ColorRect = $TrackArea/BladeIndicator
@onready var notches_container: Control = $TrackArea/NotchesContainer
@onready var tap_button: Button = $TapButton

var numbers_pool: Array[int] = []
var notch_positions: Array[Vector2] = []
var blade_progress: float = 0.0
var sweep_speed: float = 1.1 # cycles per second
var is_moving: bool = true
var time_elapsed: float = 0.0


func _ready() -> void:
	if tap_button:
		tap_button.pressed.connect(_on_tap_pressed)


func on_problem_presented(problem: RefCounted) -> void:
	super.on_problem_presented(problem)
	is_moving = true
	time_elapsed = 0.0

	var diff = 0
	if current_config and "input_difficulty" in current_config:
		diff = current_config.get("input_difficulty")

	match diff:
		1: sweep_speed = 1.45 # Medium (steady reaction)
		2: sweep_speed = 2.1 # Hard (brisk precision)
		_: sweep_speed = 0.9 # Easy (relaxed, easy to time)

	if prompt_label:
		prompt_label.text = "⏱️ TIMING-SCHLAG (STOPPE DIE KLINGE!):"
	_setup_notches()


func _setup_notches() -> void:
	if not notches_container:
		return
	for child in notches_container.get_children():
		child.queue_free()

	numbers_pool.clear()
	notch_positions.clear()

	if not current_problem:
		return

	# Build 5 to 7 candidate numbers including correct answer, with randomized answer position
	var ans: int = int(current_problem.get("correct_answer")) if current_problem.get("correct_answer") != null else 0
	var notch_count: int = 6
	
	# Determine a random target index for the correct answer
	var target_idx: int = randi_range(0, notch_count - 1)
	
	# If answer is very small, clamp target_idx so minimum candidate is at least 0
	if ans - target_idx < 0:
		target_idx = ans
		
	var start_val: int = max(0, ans - target_idx)
	var raw_candidates: Array[int] = []
	for i in range(notch_count):
		raw_candidates.append(start_val + i)
		
	# Ensure correct answer is in the candidates list
	if not raw_candidates.has(ans):
		raw_candidates.append(ans)
		raw_candidates.sort()

	numbers_pool = raw_candidates

	var track_w: float = 560.0
	var track_start_x: float = 40.0
	var count: int = numbers_pool.size()

	for i in range(count):
		var ratio = float(i) / float(max(count - 1, 1))
		var pos_x = track_start_x + (ratio * track_w)
		notch_positions.append(Vector2(pos_x, 40.0))

		# Create UI notch label
		var notch_box = PanelContainer.new()
		notch_box.position = Vector2(pos_x - 22.0, 16.0)
		notch_box.custom_minimum_size = Vector2(44.0, 32.0)
		notch_box.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var lbl = Label.new()
		lbl.text = str(numbers_pool[i])
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_override("font", preload("res://assets/fonts/PressStart2P-Regular.ttf"))
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
		notch_box.add_child(lbl)

		notches_container.add_child(notch_box)


func _is_in_bounds(local_pos: Vector2) -> bool:
	var effective_size: Vector2 = size if (size.x > 0.0 and size.y > 0.0) else Vector2(640.0, 142.0)
	return Rect2(Vector2.ZERO, effective_size).has_point(local_pos)


func _input(event: InputEvent) -> void:
	if not is_active or not visible or is_in_countdown():
		return

	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		var local_pos = event.position - global_position
		if _is_in_bounds(local_pos):
			_on_tap_pressed()


func _process(delta: float) -> void:
	if not is_active or not is_moving or is_in_countdown():
		return

	time_elapsed += delta * sweep_speed
	# Ping-pong 0.0 to 1.0 back and forth
	blade_progress = pingpong(time_elapsed, 1.0)

	if blade_indicator:
		var track_w: float = 560.0
		var track_start_x: float = 40.0
		blade_indicator.position.x = track_start_x + (blade_progress * track_w) - (blade_indicator.size.x / 2.0)


func _on_tap_pressed() -> void:
	if not is_active or not is_moving or is_in_countdown():
		return

	is_moving = false
	var chosen_val = _get_closest_number()

	if is_inside_tree() and get_tree().root.has_node("AudioManager"):
		get_node("/root/AudioManager").play_sfx("click", 1.4)

	submit_answer(chosen_val, "timing_bar", {"progress": blade_progress})


func _get_closest_number() -> int:
	if numbers_pool.is_empty() or notch_positions.is_empty():
		return 0

	var track_w: float = 560.0
	var track_start_x: float = 40.0
	var current_blade_x = track_start_x + (blade_progress * track_w)

	var closest_idx: int = 0
	var min_dist: float = INF

	for i in range(notch_positions.size()):
		var d = abs(notch_positions[i].x - current_blade_x)
		if d < min_dist:
			min_dist = d
			closest_idx = i

	return numbers_pool[closest_idx]


func play_correct_feedback() -> void:
	if blade_indicator:
		blade_indicator.color = Color(0.3, 1.0, 0.5)

	if is_inside_tree() and get_tree().root.has_node("AudioManager"):
		get_node("/root/AudioManager").play_sfx("sword_slash", 1.25)


func play_wrong_feedback() -> void:
	if blade_indicator:
		blade_indicator.color = Color(1.0, 0.25, 0.25)
	
	if is_inside_tree() and get_tree().root.has_node("AudioManager"):
		get_node("/root/AudioManager").play_sfx("wrong", 0.95)

	var tween: Tween = create_tween()
	if tween:
		tween.tween_property(self, "position:x", position.x + 6.0, 0.05)
		tween.tween_property(self, "position:x", position.x - 6.0, 0.05)
		tween.tween_property(self, "position:x", position.x, 0.05)
		tween.tween_interval(0.35)
		tween.tween_callback(func():
			if blade_indicator:
				blade_indicator.color = Color(0.3, 0.9, 1.0)
			is_moving = true
		)
