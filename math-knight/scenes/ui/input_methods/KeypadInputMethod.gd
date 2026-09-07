class_name KeypadInputMethod
extends "res://scenes/ui/input_methods/InputMethodBase.gd"
## Runic 10-Key Numpad input method.
## Fast direct button input for speedruns, touch screens, and large numbers.

@onready var prompt_label: Label = $HeaderBar/PromptLabel
@onready var buffer_label: Label = $HeaderBar/BufferLabel
@onready var undo_btn: Button = get_node_or_null("HeaderBar/UndoBtn")
@onready var grid_container: GridContainer = $GridContainer

var digit_buffer: String = ""


func _ready() -> void:
	for btn in grid_container.get_children():
		if btn is Button:
			var btn_text: String = btn.text
			btn.pressed.connect(_on_key_pressed.bind(btn_text))

	if undo_btn:
		undo_btn.pressed.connect(_on_undo_pressed)
		_setup_undo_button_style()


func _setup_undo_button_style() -> void:
	if not undo_btn:
		return
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.22, 0.14, 0.32, 0.95)
	normal_style.border_color = Color(0.9, 0.7, 0.25)
	normal_style.set_border_width_all(1)
	normal_style.set_corner_radius_all(4)
	normal_style.content_margin_left = 6
	normal_style.content_margin_right = 6

	var hover_style = normal_style.duplicate()
	hover_style.bg_color = Color(0.38, 0.22, 0.52, 1.0)
	hover_style.border_color = Color(1.0, 0.95, 0.5)

	var pressed_style = normal_style.duplicate()
	pressed_style.bg_color = Color(0.14, 0.08, 0.22, 1.0)

	undo_btn.add_theme_stylebox_override("normal", normal_style)
	undo_btn.add_theme_stylebox_override("hover", hover_style)
	undo_btn.add_theme_stylebox_override("pressed", pressed_style)
	undo_btn.add_theme_stylebox_override("focus", hover_style)
	undo_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


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
		elif keycode == KEY_BACKSPACE or keycode == KEY_DELETE:
			_on_undo_pressed()
		elif keycode == KEY_C or keycode == KEY_ESCAPE:
			_on_clear_pressed()
		elif keycode == KEY_ENTER or keycode == KEY_KP_ENTER or keycode == KEY_SPACE:
			_on_key_pressed("OK")


func _on_undo_pressed() -> void:
	if not is_active or is_in_countdown():
		return
	if not digit_buffer.is_empty():
		digit_buffer = digit_buffer.substr(0, digit_buffer.length() - 1)
		_update_display()
		if is_inside_tree() and has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx("click", 0.9)


func _on_clear_pressed() -> void:
	if not is_active or is_in_countdown():
		return
	digit_buffer = ""
	_update_display()
	if is_inside_tree() and has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("click", 0.8)


func _on_key_pressed(key_text: String) -> void:
	if not is_active or is_in_countdown():
		return

	if is_inside_tree() and has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("click", 1.1)

	if key_text.contains("⌫"):
		_on_undo_pressed()
	elif key_text.contains("C") or key_text.contains("↺"):
		_on_clear_pressed()
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

	if undo_btn:
		undo_btn.visible = not digit_buffer.is_empty()
		if undo_btn.visible and is_inside_tree():
			undo_btn.scale = Vector2(0.85, 0.85)
			var t = create_tween()
			if t:
				t.tween_property(undo_btn, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func play_correct_feedback() -> void:
	if buffer_label:
		buffer_label.modulate = Color(0.3, 1.0, 0.4)


func play_wrong_feedback() -> void:
	if buffer_label:
		buffer_label.modulate = Color(1.0, 0.3, 0.3)
		if is_inside_tree():
			var tween = create_tween()
			if tween:
				tween.tween_interval(0.3)
				tween.tween_callback(func():
					if buffer_label:
						buffer_label.modulate = Color(1.0, 0.9, 0.3)
				)

