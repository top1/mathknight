class_name QuickTapInputMethod
extends "res://scenes/ui/input_methods/InputMethodBase.gd"
## Quick Tap input method (Anvil Rhythm Tapper).
## Rapidly increments counter on every tap. Idle pause auto-submits the answer!

@onready var count_label: Label = $CenterArea/CountDisplay/CountLabel
@onready var count_display: PanelContainer = $CenterArea/CountDisplay
@onready var prompt_label: Label = $HeaderBar/PromptLabel
@onready var reset_btn: Button = $HeaderBar/ResetBtn
@onready var plus5_btn: Button = $HeaderBar/Plus5Btn
@onready var submit_btn: Button = $HeaderBar/SubmitBtn
@onready var commit_timer: Timer = $CommitTimer
@onready var progress_bar: ProgressBar = $CenterArea/CommitProgressBar

var current_count: int = 0
var tap_streak: int = 0
var last_tap_time_msec: int = 0
var commit_delay: float = 0.75
const DEBOUNCE_MS: int = 40


func _ready() -> void:
	if commit_timer:
		commit_timer.timeout.connect(_on_commit_timeout)
	if reset_btn:
		reset_btn.pressed.connect(func(): if not is_in_countdown(): _on_reset_pressed())
	if plus5_btn:
		plus5_btn.pressed.connect(func(): if not is_in_countdown(): _increment_count(5))
	if submit_btn:
		submit_btn.pressed.connect(func(): if not is_in_countdown(): _on_submit_pressed())
	if progress_bar:
		progress_bar.max_value = commit_delay
		progress_bar.value = 0.0


func _process(_delta: float) -> void:
	if commit_timer and not commit_timer.is_stopped() and progress_bar:
		progress_bar.value = commit_timer.time_left
	elif progress_bar:
		progress_bar.value = 0.0


func on_problem_presented(problem: RefCounted) -> void:
	super.on_problem_presented(problem)
	current_count = 0
	tap_streak = 0
	last_tap_time_msec = 0

	var diff = 0
	if current_config and "input_difficulty" in current_config:
		diff = current_config.get("input_difficulty")

	match diff:
		1: commit_delay = 0.52 # Medium
		2: commit_delay = 0.35 # Hard (furious fast rhythm!)
		_: commit_delay = 0.75 # Easy

	if progress_bar:
		progress_bar.max_value = commit_delay

	if commit_timer:
		commit_timer.stop()
	_update_display()
	if prompt_label:
		prompt_label.text = "👆 TIPPE SCHNELL (PAUSE = SCHLAG!):"


func _is_in_bounds(local_pos: Vector2) -> bool:
	var effective_size: Vector2 = size if (size.x > 0.0 and size.y > 0.0) else Vector2(640.0, 142.0)
	return Rect2(Vector2.ZERO, effective_size).has_point(local_pos)


func _input(event: InputEvent) -> void:
	if not is_active or not visible or is_in_countdown():
		return

	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		var local_pos: Vector2 = event.position - global_position
		if _is_in_bounds(local_pos):
			# Ignore clicks in header bar button area (top 32px)
			if local_pos.y < 32.0:
				return
			
			var now_msec: int = Time.get_ticks_msec()
			if now_msec - last_tap_time_msec < DEBOUNCE_MS:
				return
			last_tap_time_msec = now_msec
			
			_increment_count(1)


func _increment_count(amount: int) -> void:
	current_count += amount
	tap_streak += 1
	_update_display()
	_play_tap_juice()

	# Start or restart idle commit timer
	if commit_timer:
		commit_timer.start(commit_delay)


func _play_tap_juice() -> void:
	if is_inside_tree() and get_tree().root.has_node("AudioManager"):
		var pitch = clamp(1.0 + (current_count * 0.03), 0.8, 2.0)
		get_node("/root/AudioManager").play_sfx("click", pitch)

	if count_display:
		count_display.pivot_offset = count_display.size / 2.0
		var tween: Tween = create_tween()
		if tween:
			tween.tween_property(count_display, "scale", Vector2(1.25, 1.25), 0.03).set_trans(Tween.TRANS_BACK)
			tween.tween_property(count_display, "scale", Vector2.ONE, 0.06).set_trans(Tween.TRANS_SINE)


func _update_display() -> void:
	if not count_label:
		return
	if current_count == 0:
		count_label.text = "0"
		count_label.modulate = Color(0.6, 0.6, 0.7)
	else:
		count_label.text = str(current_count)
		count_label.modulate = Color(1.0, 0.9, 0.2)


func _on_commit_timeout() -> void:
	if current_count > 0:
		_commit_answer()


func _commit_answer() -> void:
	var final_val = current_count
	current_count = 0
	_update_display()
	submit_answer(final_val, "quick_tap", {"taps": tap_streak})


func _on_submit_pressed() -> void:
	if commit_timer:
		commit_timer.stop()
	if current_count > 0:
		_commit_answer()


func _on_reset_pressed() -> void:
	current_count = 0
	if commit_timer:
		commit_timer.stop()
	_update_display()


func play_correct_feedback() -> void:
	if count_label:
		count_label.modulate = Color(0.3, 1.0, 0.4)


func play_wrong_feedback() -> void:
	if count_label:
		count_label.modulate = Color(1.0, 0.3, 0.3)
	if count_display:
		var tween: Tween = create_tween()
		if tween:
			tween.tween_property(count_display, "position:x", count_display.position.x + 8.0, 0.05)
			tween.tween_property(count_display, "position:x", count_display.position.x - 8.0, 0.05)
			tween.tween_property(count_display, "position:x", count_display.position.x, 0.05)
