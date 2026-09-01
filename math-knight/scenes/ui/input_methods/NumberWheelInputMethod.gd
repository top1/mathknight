class_name NumberWheelInputMethod
extends "res://scenes/ui/input_methods/InputMethodBase.gd"
## Enhanced Number Wheel / Rotary Dial input method.
## Smooth swipe rotation, direct number tapping, magnetic notch snapping, and clean strike execution.

@onready var wheel_canvas: Control = $WheelArea/WheelCanvas
@onready var wheel_disc: Control = $WheelArea/WheelDisc
@onready var pointer_arrow: Label = $WheelArea/PointerArrow
@onready var prompt_label: Label = $HeaderBar/PromptLabel
@onready var buffer_label: Label = $HeaderBar/BufferLabel
@onready var submit_btn: Button = $HeaderBar/SubmitBtn

var current_angle: float = 0.0 # in radians
var angular_velocity: float = 0.0
var is_dragging: bool = false
var has_moved_during_drag: bool = false
var touch_start_pos: Vector2 = Vector2.ZERO
var last_touch_pos: Vector2 = Vector2.ZERO

var last_notch_index: int = -1
var numbers_pool: Array[int] = []
var displayed_texts: Array[String] = []
var digit_labels: Array[Label] = []
var digit_buttons: Array[Button] = []

const RADIUS: float = 52.0
const TOTAL_NOTCHES: int = 10

var _glitch_timer: float = 0.0
var _active_tween: Tween = null


func _ready() -> void:
	if submit_btn:
		submit_btn.visible = true
		_style_submit_button()
		submit_btn.pressed.connect(_on_strike_pressed)

	if wheel_canvas:
		wheel_canvas.draw.connect(_on_wheel_canvas_draw)

	_setup_wheel_labels()


func _style_submit_button() -> void:
	if not submit_btn:
		return
	var style = StyleBoxFlat.new()
	style.set_corner_radius_all(4)
	style.bg_color = Color(0.85, 0.6, 0.15, 0.95)
	style.border_color = Color(1.0, 0.9, 0.4)
	style.set_border_width_all(2)
	style.shadow_color = Color(1.0, 0.7, 0.1, 0.4)
	style.shadow_size = 4

	var style_hover = style.duplicate()
	style_hover.bg_color = Color(1.0, 0.75, 0.25, 1.0)
	style_hover.border_color = Color(1.0, 1.0, 0.7)

	submit_btn.add_theme_stylebox_override("normal", style)
	submit_btn.add_theme_stylebox_override("hover", style_hover)
	submit_btn.add_theme_stylebox_override("pressed", style)
	submit_btn.add_theme_stylebox_override("focus", style_hover)
	submit_btn.add_theme_color_override("font_color", Color(0.12, 0.08, 0.02))


func on_problem_presented(problem: RefCounted) -> void:
	super.on_problem_presented(problem)
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
	angular_velocity = 0.0
	current_angle = 0.0
	is_dragging = false
	has_moved_during_drag = false
	_setup_numbers_pool()
	_update_buffer_display()
	if prompt_label:
		prompt_label.text = "🎡 DREHE DAS RAD (LOSLASSEN = SCHLAG!):"
	if wheel_canvas:
		wheel_canvas.queue_redraw()


func _setup_numbers_pool() -> void:
	numbers_pool.clear()
	displayed_texts.clear()

	var ans: int = current_problem.correct_answer if (current_problem and "correct_answer" in current_problem) else 5
	var raw_list: Array[int] = [ans]

	# Gather neighbors around the answer
	for offset in [-4, -3, -2, -1, 1, 2, 3, 4, 5]:
		var candidate = ans + offset
		if candidate >= 0 and not raw_list.has(candidate):
			raw_list.append(candidate)

	raw_list.sort()
	while raw_list.size() < TOTAL_NOTCHES:
		raw_list.append(raw_list.size())

	numbers_pool = raw_list.slice(0, TOTAL_NOTCHES)

	# Difficulty Gaps & Glitches based on input_difficulty
	var diff = 0
	if current_config and "input_difficulty" in current_config:
		diff = current_config.get("input_difficulty")

	for i in range(numbers_pool.size()):
		var val = numbers_pool[i]
		if diff == 1: # Medium
			if val != ans and randf() < 0.25:
				displayed_texts.append("?")
			else:
				displayed_texts.append(str(val))
		elif diff == 2: # Hard
			if val != ans and randf() < 0.45:
				displayed_texts.append("?" if randf() < 0.6 else "#")
			else:
				displayed_texts.append(str(val))
		else: # Easy
			displayed_texts.append(str(val))

	_setup_wheel_labels()


func _setup_wheel_labels() -> void:
	if not wheel_disc:
		return
	var font = preload("res://assets/fonts/PressStart2P-Regular.ttf")
	digit_labels.clear()

	for child in wheel_disc.get_children():
		child.queue_free()

	for i in range(numbers_pool.size()):
		var lbl = Label.new()
		lbl.text = displayed_texts[i] if i < displayed_texts.size() else str(numbers_pool[i])
		lbl.add_theme_font_override("font", font)
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.custom_minimum_size = Vector2(28, 22)
		lbl.pivot_offset = Vector2(14, 11)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wheel_disc.add_child(lbl)
		digit_labels.append(lbl)

	_update_labels_position()
	if wheel_canvas:
		wheel_canvas.queue_redraw()


func _is_in_bounds(local_pos: Vector2) -> bool:
	var effective_size: Vector2 = size if (size.x > 0.0 and size.y > 0.0) else Vector2(640.0, 142.0)
	return Rect2(Vector2.ZERO, effective_size).has_point(local_pos)


func _unhandled_key_input(event: InputEvent) -> void:
	if not is_active or not visible or is_in_countdown():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_LEFT or event.keycode == KEY_A:
			_step_wheel(-1)
		elif event.keycode == KEY_RIGHT or event.keycode == KEY_D:
			_step_wheel(1)
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
			_on_strike_pressed()


func _step_wheel(direction: int) -> void:
	var count = max(numbers_pool.size(), 1)
	var step = TAU / float(count)
	var target = current_angle + (float(direction) * step)
	_animate_to_angle(target)


func _animate_to_angle(target: float) -> void:
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = create_tween()
	_active_tween.tween_property(self, "current_angle", target, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_active_tween.tween_callback(func():
		_update_labels_position()
		_check_ratchet_sound()
	)


func _input(event: InputEvent) -> void:
	if not is_active or not visible or is_in_countdown():
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var local_pos = event.position - global_position
		var in_bounds = _is_in_bounds(local_pos)

		if event.pressed:
			if in_bounds:
				if _active_tween and _active_tween.is_valid():
					_active_tween.kill()
				is_dragging = true
				has_moved_during_drag = false
				angular_velocity = 0.0
				touch_start_pos = local_pos
				last_touch_pos = local_pos
		else:
			if is_dragging:
				is_dragging = false
				_handle_drag_end(local_pos)

	elif event is InputEventMouseMotion:
		if is_dragging:
			var local_pos = event.position - global_position
			var delta_x = local_pos.x - last_touch_pos.x
			if abs(local_pos.x - touch_start_pos.x) > 4.0 or abs(local_pos.y - touch_start_pos.y) > 4.0:
				has_moved_during_drag = true

			current_angle -= delta_x * 0.012
			angular_velocity = -delta_x * 18.0
			last_touch_pos = local_pos
			_update_labels_position()
			_check_ratchet_sound()

	elif event is InputEventScreenTouch:
		var local_pos = event.position - global_position
		var in_bounds = _is_in_bounds(local_pos)

		if event.pressed:
			if in_bounds:
				if _active_tween and _active_tween.is_valid():
					_active_tween.kill()
				is_dragging = true
				has_moved_during_drag = false
				angular_velocity = 0.0
				touch_start_pos = local_pos
				last_touch_pos = local_pos
		else:
			if is_dragging:
				is_dragging = false
				_handle_drag_end(local_pos)

	elif event is InputEventScreenDrag:
		if is_dragging:
			var local_pos = event.position - global_position
			var delta_x = local_pos.x - last_touch_pos.x
			if abs(local_pos.x - touch_start_pos.x) > 4.0 or abs(local_pos.y - touch_start_pos.y) > 4.0:
				has_moved_during_drag = true

			current_angle -= delta_x * 0.012
			angular_velocity = -delta_x * 18.0
			last_touch_pos = local_pos
			_update_labels_position()
			_check_ratchet_sound()


func _handle_drag_end(local_pos: Vector2) -> void:
	if not is_active or is_in_countdown():
		return

	# Quick tap on a specific number around the wheel: snap directly to it and strike!
	if not has_moved_during_drag and wheel_disc:
		var wheel_center_global = wheel_disc.global_position
		var touch_global = global_position + local_pos
		var dist_to_center = touch_global.distance_to(wheel_center_global)

		if dist_to_center > 22.0:
			var tapped_angle = (touch_global - wheel_center_global).angle() + (PI * 0.5)
			var count = max(numbers_pool.size(), 1)
			var step = TAU / float(count)
			var notch_offset = wrapf(tapped_angle, 0.0, TAU)
			var tapped_idx = int(round((TAU - (current_angle - notch_offset)) / step)) % count

			if tapped_idx >= 0 and tapped_idx < count:
				var desired_angle = -(float(tapped_idx) * step)
				var delta = wrapf(desired_angle - current_angle, -PI, PI)
				current_angle = current_angle + delta
				_update_labels_position()
				_on_strike_pressed()
				return

	# Normal drag release: snap to nearest notch & immediately strike!
	var count = max(numbers_pool.size(), 1)
	var step = TAU / float(count)
	var target_angle = round(current_angle / step) * step
	current_angle = target_angle
	_update_labels_position()
	_on_strike_pressed()


func _snap_to_index(target_index: int) -> void:
	var count = max(numbers_pool.size(), 1)
	var step = TAU / float(count)
	var desired_angle = -(float(target_index) * step)
	var delta = wrapf(desired_angle - current_angle, -PI, PI)
	_animate_to_angle(current_angle + delta)


func _snap_to_nearest() -> void:
	var count = max(numbers_pool.size(), 1)
	var step = TAU / float(count)
	var target_angle = round(current_angle / step) * step
	_animate_to_angle(target_angle)


func _process(delta: float) -> void:
	if not is_dragging and abs(angular_velocity) > 0.05:
		current_angle += angular_velocity * delta
		angular_velocity = lerp(angular_velocity, 0.0, delta * 8.0)
		_update_labels_position()
		_check_ratchet_sound()
		if abs(angular_velocity) <= 0.05:
			angular_velocity = 0.0
			_snap_to_nearest()

	# Live glitch flicker on hard difficulty
	if current_config and current_config.get("difficulty") == 2:
		_glitch_timer += delta
		if _glitch_timer >= 0.12:
			_glitch_timer = 0.0
			_flicker_glitch_labels()


func _flicker_glitch_labels() -> void:
	var glitch_glyphs = ["%", "$", "#", "?", "!", "0", "9"]
	for i in range(digit_labels.size()):
		if displayed_texts[i] == "?" or displayed_texts[i] == "#":
			digit_labels[i].text = glitch_glyphs[randi() % glitch_glyphs.size()]


func _update_labels_position() -> void:
	var count = max(numbers_pool.size(), 1)
	var step = TAU / float(count)
	var selected_idx = get_selected_index()

	for i in range(digit_labels.size()):
		var angle = (float(i) * step) + current_angle - (PI * 0.5) # Top is indicator
		var pos = Vector2(cos(angle) * RADIUS, sin(angle) * RADIUS)
		digit_labels[i].position = pos - Vector2(14, 11)

		if i == selected_idx:
			digit_labels[i].scale = Vector2(1.35, 1.35)
			digit_labels[i].add_theme_color_override("font_color", Color(1.0, 0.95, 0.3))
			digit_labels[i].z_index = 2
		else:
			digit_labels[i].scale = Vector2.ONE
			digit_labels[i].add_theme_color_override("font_color", Color(0.65, 0.65, 0.8))
			digit_labels[i].z_index = 1
	
	_update_buffer_display()
	if wheel_canvas:
		wheel_canvas.queue_redraw()


func _on_wheel_canvas_draw() -> void:
	if not wheel_canvas:
		return
	var center = Vector2.ZERO

	# 1. Outer Dark Rim
	wheel_canvas.draw_circle(center, RADIUS + 16.0, Color(0.12, 0.09, 0.2, 0.85))
	wheel_canvas.draw_arc(center, RADIUS + 16.0, 0, TAU, 48, Color(0.3, 0.25, 0.45, 0.6), 2.0, true)

	# 2. Golden Inner Track
	wheel_canvas.draw_circle(center, RADIUS + 2.0, Color(0.18, 0.14, 0.28, 0.9))
	wheel_canvas.draw_arc(center, RADIUS + 2.0, 0, TAU, 48, Color(0.85, 0.65, 0.2, 0.4), 1.5, true)

	# 3. Top Active Notch Spotlight
	var top_slot_center = Vector2(0, -RADIUS)
	wheel_canvas.draw_circle(top_slot_center, 16.0, Color(1.0, 0.85, 0.25, 0.22))
	wheel_canvas.draw_arc(top_slot_center, 16.0, 0, TAU, 32, Color(1.0, 0.9, 0.4, 0.8), 2.0, true)

	# 4. Center Golden Hub
	wheel_canvas.draw_circle(center, 18.0, Color(0.24, 0.18, 0.35, 0.95))
	wheel_canvas.draw_arc(center, 18.0, 0, TAU, 32, Color(1.0, 0.85, 0.3, 0.85), 2.0, true)
	wheel_canvas.draw_circle(center, 6.0, Color(1.0, 0.85, 0.3, 0.9))


func _check_ratchet_sound() -> void:
	var active_idx = get_selected_index()
	if active_idx != last_notch_index:
		last_notch_index = active_idx
		if is_inside_tree() and get_tree().root.has_node("AudioManager"):
			get_node("/root/AudioManager").play_sfx("click", 1.4)


func get_selected_index() -> int:
	var count = max(numbers_pool.size(), 1)
	var step = TAU / float(count)
	var offset_angle = wrapf(current_angle, 0.0, TAU)
	var notch = int(round((TAU - offset_angle) / step)) % count
	return notch


func get_selected_value() -> int:
	var idx = get_selected_index()
	if idx >= 0 and idx < numbers_pool.size():
		return numbers_pool[idx]
	return 0


func _on_strike_pressed() -> void:
	if not is_active or is_in_countdown():
		return

	var chosen_val = get_selected_value()
	_update_buffer_display()

	if submit_btn:
		var t = create_tween()
		t.tween_property(submit_btn, "scale", Vector2(0.92, 0.92), 0.05)
		t.tween_property(submit_btn, "scale", Vector2.ONE, 0.1)

	if is_inside_tree() and get_tree().root.has_node("AudioManager"):
		get_node("/root/AudioManager").play_sfx("click", 1.6)

	submit_answer(chosen_val, "number_wheel", {"value": chosen_val})


func _update_buffer_display() -> void:
	if not buffer_label:
		return
	var val = get_selected_value()
	buffer_label.text = "[ " + str(val) + " ]"


func play_correct_feedback() -> void:
	if pointer_arrow:
		pointer_arrow.modulate = Color(0.3, 1.0, 0.4)
	if is_inside_tree() and get_tree().root.has_node("AudioManager"):
		get_node("/root/AudioManager").play_sfx("sword_slash", 1.2)


func play_wrong_feedback() -> void:
	if pointer_arrow:
		pointer_arrow.modulate = Color(1.0, 0.25, 0.25)
	if is_inside_tree() and get_tree().root.has_node("AudioManager"):
		get_node("/root/AudioManager").play_sfx("wrong", 0.95)

	var tween: Tween = create_tween()
	if tween:
		tween.tween_property(self, "position:x", position.x + 6.0, 0.04)
		tween.tween_property(self, "position:x", position.x - 6.0, 0.04)
		tween.tween_property(self, "position:x", position.x, 0.04)
		tween.tween_interval(0.3)
		tween.tween_callback(func():
			if pointer_arrow:
				pointer_arrow.modulate = Color(1.0, 0.9, 0.3)
		)
