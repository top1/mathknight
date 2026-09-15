class_name OperationGate extends Node2D

signal operation_applied(old_count: int, new_count: int)

var operations: Array[Dictionary]
var display_text: String
var is_beneficial: bool
var gate_index: int = 0
var stage_idx: int = 0
var branch_idx: int = 0
var choice_idx: int = 0
var _is_hovered: bool = false

var panel_container: PanelContainer
var hbox: HBoxContainer
var pulse_tween: Tween

const FONT_PATH = "res://assets/fonts/Silkscreen-Regular.ttf"

func _ready() -> void:
	if not panel_container:
		_create_visuals()
	if not operations.is_empty():
		setup(operations, gate_index)

func _create_visuals() -> void:
	panel_container = PanelContainer.new()
	panel_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.85)
	style.set_corner_radius_all(6)
	style.set_border_width_all(1)
	style.border_color = Color(0.4, 0.4, 0.5, 0.7)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	panel_container.add_theme_stylebox_override("panel", style)
	
	hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 6)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_container.add_child(hbox)
	
	add_child(panel_container)
	_build_labels()

func _build_labels() -> void:
	if not hbox:
		return
	for c in hbox.get_children():
		c.queue_free()

	var font = null
	if ResourceLoader.exists(FONT_PATH):
		font = load(FONT_PATH)

	for op in operations:
		var op_type = op.get("op", "")
		var val = op.get("value", 0)
		var val_str = str(int(val))

		var prefix = ""
		var is_pos = true
		match op_type:
			"add":
				prefix = "+"
				is_pos = true
			"sub":
				prefix = "-"
				is_pos = false
			"mul":
				prefix = "×"
				is_pos = true
			"div":
				prefix = "÷"
				is_pos = false

		var lbl = Label.new()
		lbl.text = prefix + val_str
		if font:
			lbl.add_theme_font_override("font", font)
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_constant_override("outline_size", 4)
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)

		if is_pos:
			lbl.add_theme_color_override("font_color", Color(0.15, 0.88, 0.25)) # Bright Green
		else:
			lbl.add_theme_color_override("font_color", Color(0.95, 0.25, 0.2))  # Bright Red

		hbox.add_child(lbl)

	panel_container.reset_size()
	panel_container.position = -panel_container.get_minimum_size() / 2.0

func setup(ops: Array[Dictionary], index: int = 0) -> void:
	operations = ops
	gate_index = index
	display_text = OperationGate.format_operation(ops)
	is_beneficial = OperationGate.is_ops_beneficial(ops)
	
	if not panel_container:
		_create_visuals()
	else:
		_build_labels()

func hit_test(world_pos: Vector2) -> bool:
	if not panel_container:
		return false
	var local_pos: Vector2 = to_local(world_pos)
	var sz: Vector2 = panel_container.size if panel_container.size.x > 0 else panel_container.get_minimum_size()
	# Generous clickable area around the math badge
	var rect := Rect2(panel_container.position - Vector2(25, 20), sz + Vector2(50, 40))
	return rect.has_point(local_pos)

func set_hovered(hovered: bool) -> void:
	if _is_hovered == hovered:
		return
	_is_hovered = hovered
	if not panel_container:
		return
	var target_scale := Vector2(1.2, 1.2) if hovered else Vector2.ONE
	var tw := create_tween()
	tw.tween_property(panel_container, "scale", target_scale, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func apply_operations(input_count: int) -> int:
	var result: int = input_count
	for op in operations:
		var val = op.get("value", 0)
		match op.get("op", ""):
			"add":
				result += int(val)
			"sub":
				result -= int(val)
			"mul":
				result = int(floor(result * float(val)))
			"div":
				if int(val) != 0:
					result = int(floor(result / float(val)))
	
	result = max(0, result)
	operation_applied.emit(input_count, result)
	return result

func play_activate_animation() -> void:
	if pulse_tween and pulse_tween.is_valid():
		pulse_tween.kill()
		
	pulse_tween = create_tween()
	
	panel_container.scale = Vector2.ONE
	panel_container.pivot_offset = panel_container.size / 2.0
	pulse_tween.tween_property(panel_container, "scale", Vector2(1.5, 1.5), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pulse_tween.tween_property(panel_container, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	var original_modulate = panel_container.modulate
	pulse_tween.parallel().tween_property(panel_container, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.1)
	pulse_tween.parallel().tween_property(panel_container, "modulate", original_modulate, 0.3).set_delay(0.1)
	
	_spawn_particles()

func _spawn_particles() -> void:
	var particles = CPUParticles2D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.lifetime = 0.6
	particles.amount = 15
	particles.spread = 180.0
	particles.initial_velocity_min = 50.0
	particles.initial_velocity_max = 100.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.gravity = Vector2(0, 98)
	
	if is_beneficial:
		particles.color = Color(1.0, 0.8, 0.2) # Golden
	else:
		particles.color = Color(0.9, 0.2, 0.1) # Red
		
	add_child(particles)
	particles.emitting = true
	
	var t = create_tween()
	t.tween_callback(particles.queue_free).set_delay(1.0)

func set_highlighted(active: bool) -> void:
	if pulse_tween and pulse_tween.is_valid():
		pulse_tween.kill()
		
	if not panel_container:
		_create_visuals()
		
	if active:
		modulate.a = 1.0
		pulse_tween = create_tween().set_loops()
		pulse_tween.tween_property(panel_container, "scale", Vector2(1.05, 1.05), 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse_tween.tween_property(panel_container, "scale", Vector2.ONE, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		modulate.a = 0.4
		if panel_container:
			panel_container.scale = Vector2.ONE

func get_result_text(input_count: int) -> String:
	var result = apply_operations(input_count)
	return str(input_count) + " -> " + str(result)

static func format_operation(ops: Array[Dictionary]) -> String:
	var texts: PackedStringArray = []
	for op in ops:
		var val = op.get("value", 0)
		var val_str = str(int(val))
		match op.get("op", ""):
			"add":
				texts.append("+" + val_str)
			"sub":
				texts.append("-" + val_str)
			"mul":
				texts.append("×" + val_str)
			"div":
				texts.append("÷" + val_str)
	return " ".join(texts)

static func is_ops_beneficial(ops: Array[Dictionary], test_value: int = 10) -> bool:
	var result: float = test_value
	for op in ops:
		var val = op.get("value", 0)
		match op.get("op", ""):
			"add":
				result += float(val)
			"sub":
				result -= float(val)
			"mul":
				result *= float(val)
			"div":
				if float(val) != 0.0:
					result /= float(val)
	return result > test_value

