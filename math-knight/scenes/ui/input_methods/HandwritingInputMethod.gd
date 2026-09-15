class_name HandwritingInputMethod
extends "res://scenes/ui/input_methods/InputMethodBase.gd"
## Dr. Kawashima-style handwriting recognition input method.
## Captures finger/mouse strokes and classifies digits via PointCloudRecognizer.
## Features spatial multi-digit segmentation (draw 12 side-by-side or sequentially),
## generous debounce timing with visual progress bar, and 1 vs 7 disambiguation.

const PointCloudRecognizerClass = preload("res://scenes/ui/input_methods/recognition/PointCloudRecognizer.gd")

@onready var draw_surface: Control = $DrawSurface
@onready var buffer_label: Label = $HeaderBox/BufferLabel
@onready var prompt_label: Label = $HeaderBox/PromptLabel
@onready var clear_btn: Button = $HeaderBox/ClearBtn
@onready var backspace_btn: Button = $HeaderBox/BackspaceBtn
@onready var submit_btn: Button = $HeaderBox/SubmitBtn
@onready var debounce_timer: Timer = $DebounceTimer
@onready var timer_bar: ProgressBar = $TimerBar
@onready var feedback_panel: PanelContainer = $FeedbackPanel
@onready var feedback_label: Label = $FeedbackPanel/FeedbackLabel

var recognizer = null
var strokes: Array[PackedVector2Array] = []
var strokes_times: Array = []
var current_stroke: PackedVector2Array = []
var current_stroke_times: Array = []
var is_drawing: bool = false
var digit_buffer: String = ""
var expected_digits_count: int = 1

## Google ML Kit Android plugin bridge
var ml_kit_plugin: Object = null
var is_ml_kit_available: bool = false

var stroke_color: Color = Color(0.3, 0.95, 1.0, 0.9)
var stroke_width: float = 6.0

var debounce_duration: float = 0.75


func _ready() -> void:
	recognizer = PointCloudRecognizerClass.new()
	_init_ml_kit()
	if debounce_timer:
		debounce_timer.timeout.connect(_on_debounce_timeout)
	if clear_btn:
		clear_btn.pressed.connect(_on_clear_pressed)
	if backspace_btn:
		backspace_btn.pressed.connect(_on_backspace_pressed)
	if submit_btn:
		submit_btn.pressed.connect(_on_submit_pressed)
	if feedback_panel:
		feedback_panel.modulate.a = 0.0
	if timer_bar:
		timer_bar.value = 0.0
	if draw_surface and not draw_surface.is_connected("draw", Callable(self, "_on_draw_surface_draw")):
		draw_surface.draw.connect(_on_draw_surface_draw)


func _init_ml_kit() -> void:
	if Engine.has_singleton("MathKnightMLKit"):
		ml_kit_plugin = Engine.get_singleton("MathKnightMLKit")
		if ml_kit_plugin:
			is_ml_kit_available = true
			if not ml_kit_plugin.is_connected("ink_recognized", Callable(self, "_on_ml_kit_ink_recognized")):
				ml_kit_plugin.connect("ink_recognized", Callable(self, "_on_ml_kit_ink_recognized"))
			if not ml_kit_plugin.is_connected("model_status_changed", Callable(self, "_on_ml_kit_model_status")):
				ml_kit_plugin.connect("model_status_changed", Callable(self, "_on_ml_kit_model_status"))
			ml_kit_plugin.initializeModel("de")
			print("HandwritingInputMethod: Connected to MathKnightMLKit native plugin.")
	else:
		print("HandwritingInputMethod: MathKnightMLKit not active (desktop/fallback mode).")


func _process(_delta: float) -> void:
	if timer_bar and debounce_timer:
		if debounce_timer.time_left > 0.0:
			timer_bar.value = debounce_timer.time_left / max(debounce_duration, 0.01)
		else:
			timer_bar.value = 0.0


func on_problem_presented(problem: RefCounted) -> void:
	super.on_problem_presented(problem)
	digit_buffer = ""
	_clear_canvas()

	var diff = 0
	if current_config and "input_difficulty" in current_config:
		diff = current_config.get("input_difficulty")

	match diff:
		1: debounce_duration = 0.45 # Medium
		2: debounce_duration = 0.28 # Hard (fast recognition window!)
		_: debounce_duration = 0.75 # Easy (relaxed drawing time)

	if current_problem:
		var target_ans: int = abs(current_problem.get("correct_answer")) if "correct_answer" in current_problem else 0
		expected_digits_count = max(str(target_ans).length(), 1)
	else:
		expected_digits_count = 1

	_update_buffer_display()
	if prompt_label:
		if expected_digits_count > 1:
			prompt_label.text = "✍️ ZEICHNE DIE %d STELLEN (ODER NEBENEINANDER):" % expected_digits_count
		else:
			prompt_label.text = "✍️ ZEICHNE DIE ZAHL:"


func _to_local_pos(screen_pos: Vector2) -> Vector2:
	return to_local_pos(screen_pos, draw_surface)


func _is_in_bounds(local_pos: Vector2) -> bool:
	var target_size = draw_surface.size if (draw_surface and draw_surface.size.x > 0.0 and draw_surface.size.y > 0.0) else size
	if target_size.x <= 0.0 or target_size.y <= 0.0:
		target_size = Vector2(640.0, 142.0)
	return Rect2(Vector2.ZERO, target_size).has_point(local_pos)


func _input(event: InputEvent) -> void:
	if not is_active or not visible or is_in_countdown():
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var local_pos: Vector2 = _to_local_pos(event.position)
		var in_bounds: bool = _is_in_bounds(local_pos)

		if event.pressed:
			if in_bounds:
				is_drawing = true
				if debounce_timer:
					debounce_timer.stop()
				current_stroke = PackedVector2Array([local_pos])
				current_stroke_times = [Time.get_ticks_msec()]
				strokes.append(current_stroke)
				strokes_times.append(current_stroke_times)
				if draw_surface:
					draw_surface.queue_redraw()
		else:
			if is_drawing:
				is_drawing = false
				if debounce_timer:
					debounce_timer.start(debounce_duration)

	elif event is InputEventMouseMotion:
		if is_drawing and current_stroke.size() > 0:
			var local_pos: Vector2 = _to_local_pos(event.position)
			if local_pos.distance_squared_to(current_stroke[-1]) > 9.0: # 3px smoothing
				current_stroke.append(local_pos)
				current_stroke_times.append(Time.get_ticks_msec())
				strokes[-1] = current_stroke
				strokes_times[-1] = current_stroke_times
				if draw_surface:
					draw_surface.queue_redraw()

	elif event is InputEventScreenTouch:
		var local_pos: Vector2 = _to_local_pos(event.position)
		var in_bounds: bool = _is_in_bounds(local_pos)

		if event.pressed:
			if in_bounds:
				is_drawing = true
				if debounce_timer:
					debounce_timer.stop()
				current_stroke = PackedVector2Array([local_pos])
				current_stroke_times = [Time.get_ticks_msec()]
				strokes.append(current_stroke)
				strokes_times.append(current_stroke_times)
				if draw_surface:
					draw_surface.queue_redraw()
		else:
			if is_drawing:
				is_drawing = false
				if debounce_timer:
					debounce_timer.start(debounce_duration)

	elif event is InputEventScreenDrag:
		if is_drawing and current_stroke.size() > 0:
			var local_pos: Vector2 = _to_local_pos(event.position)
			if local_pos.distance_squared_to(current_stroke[-1]) > 9.0:
				current_stroke.append(local_pos)
				current_stroke_times.append(Time.get_ticks_msec())
				strokes[-1] = current_stroke
				strokes_times[-1] = current_stroke_times
				if draw_surface:
					draw_surface.queue_redraw()


func _on_draw_surface_draw() -> void:
	for stroke in strokes:
		if stroke.size() > 1:
			# Draw glowing shadow underneath
			draw_surface.draw_polyline(stroke, Color(0.1, 0.4, 0.8, 0.35), stroke_width + 4.0, true)
			# Draw main bright stroke
			draw_surface.draw_polyline(stroke, stroke_color, stroke_width, true)
			for pt in stroke:
				draw_surface.draw_circle(pt, stroke_width * 0.5, stroke_color)
		elif stroke.size() == 1:
			draw_surface.draw_circle(stroke[0], stroke_width * 0.7, stroke_color)


func _on_debounce_timeout() -> void:
	if strokes.is_empty():
		return

	if is_ml_kit_available and ml_kit_plugin != null and ml_kit_plugin.isModelReady():
		var stroke_json: String = _serialize_strokes_to_json()
		ml_kit_plugin.recognizeStrokes(stroke_json)
	else:
		_recognize_with_fallback()


func _recognize_with_fallback() -> void:
	var results: Array[Dictionary] = recognizer.recognize_segmented(strokes)
	var recognized_str: String = ""
	var any_valid: bool = false

	for res in results:
		var digit: int = res.digit
		var conf: float = res.confidence
		if digit >= 0 and conf >= 0.45:
			recognized_str += str(digit)
			any_valid = true

	if any_valid and not recognized_str.is_empty():
		_on_digits_recognized(recognized_str)
	else:
		_show_feedback("?", Color(1.0, 0.4, 0.4))
		_clear_canvas()


func _on_ml_kit_ink_recognized(text: String, _score: float) -> void:
	var recognized_str: String = text.strip_edges()
	if not recognized_str.is_empty():
		_on_digits_recognized(recognized_str)
	else:
		_show_feedback("?", Color(1.0, 0.4, 0.4))
		_clear_canvas()


func _on_ml_kit_model_status(status: String) -> void:
	print("HandwritingInputMethod: ML Kit model status: ", status)
	if status == "downloading" and prompt_label:
		prompt_label.text = "✍️ LADE SCHRIFTERKENNUNG..."
	elif status == "ready" and prompt_label:
		prompt_label.text = "✍️ ZEICHNE DIE ZAHL:"


func _serialize_strokes_to_json() -> String:
	var root_arr: Array = []
	for s_idx in range(strokes.size()):
		var s = strokes[s_idx]
		var times = strokes_times[s_idx] if s_idx < strokes_times.size() else []
		var stroke_points: Array = []
		for p_idx in range(s.size()):
			var pt = s[p_idx]
			var t = times[p_idx] if p_idx < times.size() else Time.get_ticks_msec()
			stroke_points.append({"x": pt.x, "y": pt.y, "t": t})
		root_arr.append(stroke_points)
	return JSON.stringify(root_arr)


func _on_digits_recognized(digits_text: String) -> void:
	_show_feedback(digits_text, Color(0.3, 1.0, 0.5))
	digit_buffer += digits_text
	_update_buffer_display()
	_clear_canvas()

	if is_inside_tree() and get_tree().root.has_node("AudioManager"):
		get_node("/root/AudioManager").play_sfx("click", 1.3)

	# If we have gathered enough digits, auto-commit
	if digit_buffer.length() >= expected_digits_count:
		var tween: Tween = create_tween()
		if tween:
			tween.tween_interval(0.12)
			tween.tween_callback(_commit_buffer)
		else:
			_commit_buffer()


func _commit_buffer() -> void:
	if digit_buffer.is_empty():
		return

	var final_val: int = int(digit_buffer)
	digit_buffer = ""
	_update_buffer_display()
	submit_answer(final_val, "handwriting", {"strokes_count": strokes.size()})


func _on_submit_pressed() -> void:
	if digit_buffer.is_empty() and not strokes.is_empty():
		# Try recognize immediately
		_on_debounce_timeout()
	if not digit_buffer.is_empty():
		_commit_buffer()


func _on_backspace_pressed() -> void:
	if not digit_buffer.is_empty():
		digit_buffer = digit_buffer.substr(0, digit_buffer.length() - 1)
		_update_buffer_display()
	_clear_canvas()
	if is_inside_tree() and get_tree().root.has_node("AudioManager"):
		get_node("/root/AudioManager").play_sfx("click", 0.8)


func _on_clear_pressed() -> void:
	digit_buffer = ""
	_clear_canvas()
	_update_buffer_display()
	if is_inside_tree() and get_tree().root.has_node("AudioManager"):
		get_node("/root/AudioManager").play_sfx("click", 0.7)


func _clear_canvas() -> void:
	strokes.clear()
	strokes_times.clear()
	current_stroke.clear()
	current_stroke_times.clear()
	if draw_surface:
		draw_surface.queue_redraw()
	if debounce_timer:
		debounce_timer.stop()
	if timer_bar:
		timer_bar.value = 0.0


func _update_buffer_display() -> void:
	if not buffer_label:
		return

	if digit_buffer.is_empty():
		if expected_digits_count == 2:
			buffer_label.text = "[ _ _ ]"
		elif expected_digits_count == 3:
			buffer_label.text = "[ _ _ _ ]"
		else:
			buffer_label.text = "[ ? ]"
		buffer_label.modulate = Color(0.7, 0.7, 0.8)
	else:
		# Format partial slots
		var display_text = digit_buffer
		var remaining = expected_digits_count - digit_buffer.length()
		for i in range(remaining):
			display_text += " _"
		buffer_label.text = "[ " + display_text + " ]"
		buffer_label.modulate = Color(1.0, 0.9, 0.3)


func _show_feedback(text: String, col: Color) -> void:
	if not feedback_panel or not feedback_label:
		return
	feedback_label.text = text
	feedback_label.modulate = col
	feedback_panel.modulate.a = 1.0
	feedback_panel.scale = Vector2(1.3, 1.3)

	var tween: Tween = create_tween()
	if tween:
		tween.tween_property(feedback_panel, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK)
		tween.tween_property(feedback_panel, "modulate:a", 0.0, 0.25).set_delay(0.2)


func play_correct_feedback() -> void:
	stroke_color = Color(0.4, 1.0, 0.5)
	if draw_surface:
		draw_surface.queue_redraw()


func play_wrong_feedback() -> void:
	stroke_color = Color(1.0, 0.3, 0.3)
	if draw_surface:
		draw_surface.queue_redraw()
	var tween: Tween = create_tween()
	if tween:
		tween.tween_property(self, "position:x", position.x + 6.0, 0.05)
		tween.tween_property(self, "position:x", position.x - 6.0, 0.05)
		tween.tween_property(self, "position:x", position.x, 0.05)
		tween.tween_callback(func(): stroke_color = Color(0.3, 0.95, 1.0, 0.9))
