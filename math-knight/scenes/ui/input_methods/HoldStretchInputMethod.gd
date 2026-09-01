class_name HoldStretchInputMethod
extends "res://scenes/ui/input_methods/InputMethodBase.gd"
## 2D Multi-Axis Hold & Stretch input method.
## Supports 2D Area / Matrix calculation (X * Y, X + Y) and 1D Slingshot stretch with integer grid snapping.

@onready var draw_canvas: Control = $DrawCanvas
@onready var prompt_label: Label = $HeaderBar/PromptLabel
@onready var mode_toggle_btn: Button = $HeaderBar/ModeToggleBtn
@onready var value_popup: PanelContainer = $ValuePopup
@onready var value_label: Label = $ValuePopup/ValueLabel

var is_holding: bool = false
var anchor_pos: Vector2 = Vector2.ZERO
var current_pos: Vector2 = Vector2.ZERO

var val_x: int = 1
var val_y: int = 1
var calculated_val: int = 0
var current_op_symbol: String = "×"
var is_2d_mode: bool = false

## Locked dimension for fixed component problems: -1 = none, 0 = X locked (operand A), 1 = Y locked (operand B)
var locked_dimension: int = -1
var locked_val_x: int = 0
var locked_val_y: int = 0

const STEP_X: float = 24.0
const STEP_Y: float = 20.0
const PIXELS_PER_UNIT_1D: float = 14.0
const MAX_VAL: int = 150


func _ready() -> void:
	if value_popup:
		value_popup.visible = false
	if mode_toggle_btn:
		mode_toggle_btn.pressed.connect(_on_mode_toggle_pressed)
		_update_mode_button_text()


func on_problem_presented(problem: RefCounted) -> void:
	super.on_problem_presented(problem)
	is_holding = false
	val_x = 1
	val_y = 1
	calculated_val = 0
	locked_dimension = -1
	locked_val_x = 0
	locked_val_y = 0

	# 2D Mode ONLY for equation-building modes where player provides operands
	var is_equation_mode: bool = false
	if current_config and "game_mode" in current_config:
		var mode = current_config.get("game_mode")
		is_equation_mode = (mode == 1 or mode == 2) # RESULT_TO_EQUATION or MULTI_OP_EQUATION
	elif is_inside_tree() and get_tree().root.has_node("MathEngine"):
		var me = get_node("/root/MathEngine")
		if me.current_config:
			var mode = me.current_config.game_mode
			is_equation_mode = (mode == 1 or mode == 2)
	
	is_2d_mode = is_equation_mode

	if current_problem:
		var prob_op = current_problem.get("operator_symbol")
		current_op_symbol = str(prob_op) if prob_op != null and str(prob_op) != "" else "×"

		# Check for fixed / pre-given operand
		var given_idx_val = current_problem.get("given_operand_index")
		var given_idx: int = int(given_idx_val) if given_idx_val != null else -1
		if given_idx == 0:
			locked_dimension = 0
			var op_a = current_problem.get("operand_a")
			locked_val_x = int(op_a) if op_a != null else 1
			val_x = locked_val_x
		elif given_idx == 1:
			locked_dimension = 1
			var op_b = current_problem.get("operand_b")
			locked_val_y = int(op_b) if op_b != null else 1
			val_y = locked_val_y

	if value_popup:
		value_popup.visible = false
	if draw_canvas:
		draw_canvas.queue_redraw()
	_update_mode_button_text()
	_update_prompt_text()


func _on_mode_toggle_pressed() -> void:
	is_2d_mode = not is_2d_mode
	_update_mode_button_text()
	_update_prompt_text()
	if is_inside_tree() and get_tree().root.has_node("AudioManager"):
		get_node("/root/AudioManager").play_sfx("click", 1.2)


func _update_mode_button_text() -> void:
	if mode_toggle_btn:
		mode_toggle_btn.text = "📐 2D Matrix" if is_2d_mode else "🏹 1D Sehne"


func _update_prompt_text() -> void:
	if prompt_label:
		if is_2d_mode:
			if locked_dimension == 0:
				prompt_label.text = "📐 X = %d (FEST) — ZIEHE Y FÜR DAS ERGEBNIS:" % locked_val_x
			elif locked_dimension == 1:
				prompt_label.text = "📐 Y = %d (FEST) — ZIEHE X FÜR DAS ERGEBNIS:" % locked_val_y
			else:
				prompt_label.text = "📐 2D-ZIEHEN (X %s Y — OHNE ERGEBNIS-ANZEIGE):" % current_op_symbol
		else:
			prompt_label.text = "🏹 1D-ZIEHEN (LOSLASSEN = FEUER!):"


func _is_in_bounds(local_pos: Vector2) -> bool:
	var effective_size: Vector2 = size if (size.x > 0.0 and size.y > 0.0) else Vector2(640.0, 142.0)
	return Rect2(Vector2.ZERO, effective_size).has_point(local_pos)


func _input(event: InputEvent) -> void:
	if not is_active or not visible or is_in_countdown():
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var local_pos: Vector2 = event.position - global_position
		var in_bounds: bool = _is_in_bounds(local_pos)

		if event.pressed:
			if in_bounds:
				is_holding = true
				anchor_pos = local_pos
				current_pos = local_pos
				_update_stretch_values()
				if value_popup:
					value_popup.visible = true
				if draw_canvas:
					draw_canvas.queue_redraw()
				if is_inside_tree() and get_tree().root.has_node("AudioManager"):
					get_node("/root/AudioManager").play_sfx("click", 0.9)
		else:
			if is_holding:
				is_holding = false
				if value_popup:
					value_popup.visible = false
				if draw_canvas:
					draw_canvas.queue_redraw()
				_fire_stretch_answer()

	elif event is InputEventMouseMotion:
		if is_holding:
			var local_pos: Vector2 = event.position - global_position
			current_pos = local_pos
			_update_stretch_values()
			if draw_canvas:
				draw_canvas.queue_redraw()

	elif event is InputEventScreenTouch:
		var local_pos: Vector2 = event.position - global_position
		var in_bounds: bool = _is_in_bounds(local_pos)

		if event.pressed:
			if in_bounds:
				is_holding = true
				anchor_pos = local_pos
				current_pos = local_pos
				_update_stretch_values()
				if value_popup:
					value_popup.visible = true
				if draw_canvas:
					draw_canvas.queue_redraw()
				if is_inside_tree() and get_tree().root.has_node("AudioManager"):
					get_node("/root/AudioManager").play_sfx("click", 0.9)
		else:
			if is_holding:
				is_holding = false
				if value_popup:
					value_popup.visible = false
				if draw_canvas:
					draw_canvas.queue_redraw()
				_fire_stretch_answer()

	elif event is InputEventScreenDrag:
		if is_holding:
			var local_pos: Vector2 = event.position - global_position
			current_pos = local_pos
			_update_stretch_values()
			if draw_canvas:
				draw_canvas.queue_redraw()


func _update_stretch_values() -> void:
	var prev_val = calculated_val

	if is_2d_mode:
		var dx: float = abs(current_pos.x - anchor_pos.x)
		var dy: float = abs(current_pos.y - anchor_pos.y)

		# Dimension X
		if locked_dimension == 0:
			val_x = max(1, locked_val_x)
		else:
			val_x = int(clamp(round(dx / STEP_X), 1, 15))

		# Dimension Y
		if locked_dimension == 1:
			val_y = max(1, locked_val_y)
		else:
			val_y = int(clamp(round(dy / STEP_Y), 1, 15))

		# Calculate internal math result (NEVER shown in label as per requirements!)
		match current_op_symbol:
			"+":
				calculated_val = val_x + val_y
			"-":
				var big = max(val_x, val_y)
				var small = min(val_x, val_y)
				calculated_val = big - small
			"×", "x", "*":
				calculated_val = val_x * val_y
			"÷", "/":
				calculated_val = int(val_x / max(val_y, 1))
			_:
				calculated_val = val_x + val_y

		# Display ONLY the operands (x + y or x * y), NEVER the calculation result
		if value_label:
			var x_str = "[ %d 🔒 ]" % val_x if locked_dimension == 0 else "[ %d ]" % val_x
			var y_str = "[ %d 🔒 ]" % val_y if locked_dimension == 1 else "[ %d ]" % val_y
			value_label.text = "%s %s %s" % [x_str, current_op_symbol, y_str]

	else:
		var dist: float = anchor_pos.distance_to(current_pos)
		calculated_val = int(clamp(round(dist / PIXELS_PER_UNIT_1D), 1, MAX_VAL))
		
		if value_label:
			value_label.text = "[ %d ]" % calculated_val

	if value_popup:
		# Position popup near the snapped current pos
		value_popup.global_position = global_position + current_pos + Vector2(-60, -45)

	if calculated_val != prev_val:
		if value_popup:
			value_popup.pivot_offset = value_popup.size / 2.0
			var tween: Tween = create_tween()
			tween.tween_property(value_popup, "scale", Vector2(1.15, 1.15), 0.03)
			tween.tween_property(value_popup, "scale", Vector2.ONE, 0.05)
		if is_inside_tree() and get_tree().root.has_node("AudioManager"):
			var pitch = clamp(1.0 + (calculated_val * 0.02), 0.8, 2.2)
			get_node("/root/AudioManager").play_sfx("click", pitch)


func _on_draw_canvas_draw() -> void:
	if not is_holding:
		return

	if is_2d_mode:
		var is_multiplication: bool = (current_op_symbol in ["×", "x", "*"])
		var width: float = float(val_x) * STEP_X
		var height: float = float(val_y) * STEP_Y

		var sign_x: float = -1.0 if current_pos.x < anchor_pos.x else 1.0
		var sign_y: float = -1.0 if current_pos.y < anchor_pos.y else 1.0

		var min_x: float = anchor_pos.x if sign_x > 0 else anchor_pos.x - width
		var max_x: float = anchor_pos.x + width if sign_x > 0 else anchor_pos.x
		var min_y: float = anchor_pos.y if sign_y > 0 else anchor_pos.y - height
		var max_y: float = anchor_pos.y + height if sign_y > 0 else anchor_pos.y

		var default_font = ThemeDB.fallback_font

		if is_multiplication:
			# --- MULTIPLICATION (×): 2D Area / Matrix Grid (Rechteck / Fläche) ---
			var rect: Rect2 = Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))

			var fill_color = Color(0.2, 0.6, 1.0, 0.22)
			if locked_dimension != -1:
				fill_color = Color(0.3, 0.7, 0.9, 0.25)
			draw_canvas.draw_rect(rect, fill_color, true)

			var outline_color = Color(0.4, 0.85, 1.0, 0.9)
			if locked_dimension != -1:
				outline_color = Color(1.0, 0.85, 0.3, 0.95)
			draw_canvas.draw_rect(rect, outline_color, false, 2.5)

			# Internal grid subdivision lines
			if val_x > 1 and rect.size.x > 10.0:
				var step_w: float = rect.size.x / float(val_x)
				for i in range(1, val_x):
					var gx: float = min_x + (float(i) * step_w)
					var line_col = Color(1.0, 0.8, 0.2, 0.4) if locked_dimension == 0 else Color(0.3, 0.7, 1.0, 0.35)
					draw_canvas.draw_line(Vector2(gx, min_y), Vector2(gx, max_y), line_col, 1.0)

			if val_y > 1 and rect.size.y > 10.0:
				var step_h: float = rect.size.y / float(val_y)
				for j in range(1, val_y):
					var gy: float = min_y + (float(j) * step_h)
					var line_col = Color(1.0, 0.8, 0.2, 0.4) if locked_dimension == 1 else Color(0.3, 0.7, 1.0, 0.35)
					draw_canvas.draw_line(Vector2(min_x, gy), Vector2(max_x, gy), line_col, 1.0)

			# Anchors
			var snapped_corner = Vector2(anchor_pos.x + (sign_x * width), anchor_pos.y + (sign_y * height))
			draw_canvas.draw_circle(anchor_pos, 5.0, Color(0.3, 1.0, 0.6, 0.9))
			draw_canvas.draw_circle(snapped_corner, 6.0, Color(1.0, 0.9, 0.2, 0.9))
		else:
			# --- ADDITION (+), SUBTRACTION (-), DIVISION (÷): Two Component Lines with Operator in Junction ---
			var corner_x = Vector2(anchor_pos.x + (sign_x * width), anchor_pos.y)
			var end_corner = Vector2(anchor_pos.x + (sign_x * width), anchor_pos.y + (sign_y * height))

			# Colors
			var col_x = Color(1.0, 0.85, 0.3, 0.95) if locked_dimension == 0 else Color(0.2, 0.8, 1.0, 0.9)
			var col_y = Color(1.0, 0.85, 0.3, 0.95) if locked_dimension == 1 else Color(1.0, 0.6, 0.25, 0.9)

			# 1. Horizontal segment (X dimension)
			draw_canvas.draw_line(anchor_pos, corner_x, col_x, 3.5, true)
			# X Notches / Ticks
			for i in range(1, val_x + 1):
				var tx = anchor_pos.x + (sign_x * float(i) * STEP_X)
				draw_canvas.draw_line(Vector2(tx, anchor_pos.y - 4), Vector2(tx, anchor_pos.y + 4), col_x, 1.5)

			# 2. Vertical segment (Y dimension)
			draw_canvas.draw_line(corner_x, end_corner, col_y, 3.5, true)
			# Y Notches / Ticks
			for j in range(1, val_y + 1):
				var ty = anchor_pos.y + (sign_y * float(j) * STEP_Y)
				draw_canvas.draw_line(Vector2(corner_x.x - 4, ty), Vector2(corner_x.x + 4, ty), col_y, 1.5)

			# 3. Origin & End anchor dots
			draw_canvas.draw_circle(anchor_pos, 6.0, Color(0.3, 1.0, 0.6, 0.9))
			draw_canvas.draw_circle(end_corner, 6.5, Color(1.0, 0.9, 0.2, 0.9))

			# 4. Operator Badge at Junction Corner (corner_x)
			draw_canvas.draw_circle(corner_x, 12.0, Color(0.1, 0.08, 0.18, 0.95))
			draw_canvas.draw_arc(corner_x, 12.0, 0, TAU, 24, Color(1.0, 0.85, 0.3, 0.95), 2.0)
			if default_font:
				draw_canvas.draw_string(default_font, corner_x + Vector2(-5, 5), current_op_symbol, HORIZONTAL_ALIGNMENT_CENTER, 10, 14, Color(1.0, 0.95, 0.5))

			# 5. Length values along the lines
			if default_font:
				# X Value label centered above horizontal line
				var mid_x_pos = Vector2((anchor_pos.x + corner_x.x) * 0.5, anchor_pos.y - 8.0)
				var x_label = "%d 🔒" % val_x if locked_dimension == 0 else "%d" % val_x
				draw_canvas.draw_string(default_font, mid_x_pos + Vector2(-12, 0), x_label, HORIZONTAL_ALIGNMENT_CENTER, 24, 12, col_x)

				# Y Value label centered beside vertical line
				var mid_y_pos = Vector2(corner_x.x + (12.0 * sign_x), (corner_x.y + end_corner.y) * 0.5 + 4.0)
				var y_label = "%d 🔒" % val_y if locked_dimension == 1 else "%d" % val_y
				draw_canvas.draw_string(default_font, mid_y_pos + Vector2(-12, 0), y_label, HORIZONTAL_ALIGNMENT_CENTER, 24, 12, col_y)
	else:
		# 1D Elastic Line with integer unit snap
		var snapped_dist: float = float(calculated_val) * PIXELS_PER_UNIT_1D
		var dir: Vector2 = (current_pos - anchor_pos).normalized() if current_pos != anchor_pos else Vector2.RIGHT
		var snapped_end_pos: Vector2 = anchor_pos + (dir * snapped_dist)

		draw_canvas.draw_circle(anchor_pos, 8.0, Color(0.2, 0.8, 1.0, 0.5))
		draw_canvas.draw_circle(anchor_pos, 4.0, Color(1.0, 1.0, 1.0, 0.9))

		var line_color = Color(1.0, 0.8, 0.2, 0.85).lerp(Color(1.0, 0.3, 0.2, 0.9), clamp(float(calculated_val) / 30.0, 0.0, 1.0))
		draw_canvas.draw_line(anchor_pos, snapped_end_pos, line_color, 4.0, true)
		draw_canvas.draw_circle(snapped_end_pos, 7.0, Color(1.0, 0.9, 0.3, 0.9))


func _fire_stretch_answer() -> void:
	if calculated_val <= 0:
		return

	var final_val = calculated_val
	calculated_val = 0

	if is_inside_tree() and get_tree().root.has_node("AudioManager"):
		get_node("/root/AudioManager").play_sfx("sword_slash", 1.4)

	submit_answer(final_val, "hold_stretch_2d" if is_2d_mode else "hold_stretch_1d", {
		"val_x": val_x,
		"val_y": val_y,
		"is_2d": is_2d_mode
	})


func play_correct_feedback() -> void:
	pass


func play_wrong_feedback() -> void:
	var tween: Tween = create_tween()
	if tween:
		tween.tween_property(self, "position:x", position.x + 6.0, 0.05)
		tween.tween_property(self, "position:x", position.x - 6.0, 0.05)
		tween.tween_property(self, "position:x", position.x, 0.05)

