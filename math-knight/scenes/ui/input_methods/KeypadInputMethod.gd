class_name KeypadInputMethod
extends "res://scenes/ui/input_methods/InputMethodBase.gd"
## Runic 10-Key Numpad input method.
## Fast direct button input for speedruns, touch screens, and large numbers.

@onready var prompt_label: Label = $HeaderBar/PromptLabel
@onready var buffer_label: Label = $HeaderBar/BufferLabel
@onready var grid_container: GridContainer = $GridContainer

var digit_buffer: String = ""


func _ready() -> void:
	for btn in grid_container.get_children():
		if btn is Button:
			var btn_text: String = btn.text
			btn.pressed.connect(_on_key_pressed.bind(btn_text))


func on_problem_presented(problem: RefCounted) -> void:
	super.on_problem_presented(problem)
	digit_buffer = ""
	_update_display()
	if prompt_label:
		prompt_label.text = "🔢 TASTENFELD EINGABE:"


func _unhandled_input(event: InputEvent) -> void:
	if not is_active or is_in_countdown():
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var keycode = event.keycode
		if keycode >= KEY_0 and keycode <= KEY_9:
			_on_key_pressed(str(keycode - KEY_0))
		elif keycode >= KEY_KP_0 and keycode <= KEY_KP_9:
			_on_key_pressed(str(keycode - KEY_KP_0))
		elif keycode == KEY_BACKSPACE or keycode == KEY_DELETE or keycode == KEY_C:
			_on_key_pressed("C")
		elif keycode == KEY_ENTER or keycode == KEY_KP_ENTER or keycode == KEY_SPACE:
			_on_key_pressed("OK")


func _on_key_pressed(key_text: String) -> void:
	if not is_active or is_in_countdown():
		return

	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("click", 1.1)

	if key_text.contains("C") or key_text.contains("↺"):
		digit_buffer = ""
		_update_display()
	elif key_text.contains("OK") or key_text.contains("⚔"):
		_commit_answer()
	else:
		# Extract digit characters only
		var digits_only: String = ""
		for ch in key_text:
			if ch in "0123456789":
				digits_only += ch
		
		if not digits_only.is_empty():
			digit_buffer += digits_only
			_update_display()

			if current_problem:
				var target_len = str(abs(current_problem.correct_answer)).length()
				if digit_buffer.length() >= target_len:
					_commit_answer()


func _commit_answer() -> void:
	if digit_buffer.is_empty():
		return
	var final_val = int(digit_buffer)
	digit_buffer = ""
	_update_display()
	submit_answer(final_val, "keypad", {})


func _update_display() -> void:
	if not buffer_label:
		return
	if digit_buffer.is_empty():
		buffer_label.text = "[ ? ]"
	else:
		buffer_label.text = "[ " + digit_buffer + " ]"


func play_correct_feedback() -> void:
	if buffer_label:
		buffer_label.modulate = Color(0.3, 1.0, 0.4)


func play_wrong_feedback() -> void:
	if buffer_label:
		buffer_label.modulate = Color(1.0, 0.3, 0.3)
		var tween = create_tween()
		if tween:
			tween.tween_interval(0.3)
			tween.tween_callback(func():
				if buffer_label:
					buffer_label.modulate = Color(1.0, 0.9, 0.3)
			)

