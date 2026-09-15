class_name GateLever
extends Node2D

## Emitted when the player switches the lever to a new path.
signal lever_switched(gate_id: int, selected_path: int)

# Core properties
var gate_id: int = -1
var num_paths: int = 2
var current_path: int = 0
var path_angles: Array[float] = []
var arm_offsets: Array[Vector2] = []
var is_locked: bool = false
var is_interactive: bool = true
var gate_color: Color = Color(0.92, 0.55, 0.18) # Sturdy orange/bronze gate barrier

# Visual state
var _current_arm_offset: Vector2 = Vector2(-35, 30)
var _target_arm_offset: Vector2 = Vector2(-35, 30)
var _lever_angle: float = 0.0
var _pulse_scale: float = 1.0
var _hover_scale: float = 1.0
var _pivot_scale: Vector2 = Vector2.ONE

# Rendering constants
const PIVOT_RADIUS: float = 7.0
const GATE_WIDTH: float = 6.0

# Node references
var _area: Area2D
var _collision_shape: CollisionShape2D
var _pulse_tween: Tween
var _move_tween: Tween

func _ready() -> void:
	_area = Area2D.new()
	add_child(_area)
	
	_collision_shape = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 45.0
	_collision_shape.shape = shape
	_area.add_child(_collision_shape)
	
	# Area2D input_event removed to prevent double-toggle with SiegeGateMaze input handling
	_area.mouse_entered.connect(_on_area_mouse_entered)
	_area.mouse_exited.connect(_on_area_mouse_exited)
	
	_start_pulse_animation()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var total_scale: float = _pulse_scale * _hover_scale
	if is_locked:
		total_scale = 1.0

	# 1. Draw rotation guide arc between choices if we have arm offsets
	if arm_offsets.size() >= 2:
		var a1 = atan2(arm_offsets[0].y, arm_offsets[0].x)
		var a2 = atan2(arm_offsets[1].y, arm_offsets[1].x)
		var arc_radius = minf(arm_offsets[0].length(), arm_offsets[1].length()) * 0.55
		var min_a = minf(a1, a2)
		var max_a = maxf(a1, a2)
		if max_a - min_a > PI:
			# Arc crosses PI / -PI boundary
			draw_arc(Vector2.ZERO, arc_radius, max_a, min_a + TAU, 24, Color(0.5, 0.5, 0.6, 0.45), 1.5)
		else:
			draw_arc(Vector2.ZERO, arc_radius, min_a, max_a, 24, Color(0.5, 0.5, 0.6, 0.45), 1.5)

	# 2. Draw Gate Barrier Beam from pivot to current arm offset
	var arm_end = _current_arm_offset * total_scale
	var arm_len = arm_end.length()
	if arm_len > 1.0:
		var bar_col = gate_color
		if is_locked:
			bar_col = Color(0.4, 0.4, 0.45)

		# Shadow/border
		draw_line(Vector2.ZERO, arm_end, Color(0.08, 0.08, 0.12, 0.8), GATE_WIDTH + 3.0, true)
		# Main barrier body
		draw_line(Vector2.ZERO, arm_end, bar_col, GATE_WIDTH, true)
		# Highlight ridge
		draw_line(Vector2.ZERO, arm_end, bar_col.lightened(0.3), GATE_WIDTH * 0.35, true)
		# End cap stopper
		draw_circle(arm_end, GATE_WIDTH * 0.7, bar_col.darkened(0.2))
		draw_circle(arm_end, GATE_WIDTH * 0.4, Color.WHITE)

	# 3. Draw Pivot Hinge (with squash & stretch)
	var pivot_col = Color(0.25, 0.25, 0.32)
	var ring_col = Color(0.9, 0.9, 0.95)
	if is_locked:
		pivot_col = Color(0.2, 0.2, 0.2)
		ring_col = Color(0.5, 0.5, 0.5)

	draw_circle(Vector2.ZERO, PIVOT_RADIUS * total_scale * _pivot_scale.x, pivot_col)
	draw_arc(Vector2.ZERO, PIVOT_RADIUS * total_scale * _pivot_scale.x, 0, TAU, 32, ring_col, 2.0)
	draw_circle(Vector2.ZERO, (PIVOT_RADIUS * 0.4) * total_scale, Color(0.85, 0.85, 0.9))

func setup(id: int, paths: int, angles: Array[float]) -> void:
	gate_id = id
	num_paths = paths
	path_angles = angles
	if path_angles.size() > 0:
		_lever_angle = path_angles[current_path]

## Configure the gate barrier arm target offsets for each choice
func setup_arm_offsets(offsets: Array[Vector2], initial_choice: int = 0) -> void:
	arm_offsets = offsets
	num_paths = offsets.size()
	current_path = initial_choice
	if current_path < arm_offsets.size():
		_current_arm_offset = arm_offsets[current_path]
		_target_arm_offset = arm_offsets[current_path]

func set_path(index: int, animate: bool = true) -> void:
	if index < 0 or index >= num_paths:
		return
		
	current_path = index

	if arm_offsets.size() > current_path:
		_target_arm_offset = arm_offsets[current_path]
	elif path_angles.size() > current_path:
		var target_angle: float = path_angles[current_path]
		_target_arm_offset = Vector2(cos(target_angle), sin(target_angle)) * 30.0

	if animate:
		if _move_tween and _move_tween.is_valid():
			_move_tween.kill()

		_move_tween = create_tween().set_parallel(true)
		
		# Rotate/move gate barrier
		_move_tween.tween_property(self, "_current_arm_offset", _target_arm_offset, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
		# Pivot squash
		_move_tween.tween_property(self, "_pivot_scale", Vector2(1.3, 0.7), 0.06)
		_move_tween.chain().tween_property(self, "_pivot_scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		
		if is_inside_tree() and has_node("/root/AudioManager"):
			var audio_manager = get_node("/root/AudioManager")
			if audio_manager.has_method("play_sfx"):
				audio_manager.play_sfx("click")
	else:
		_current_arm_offset = _target_arm_offset

func lock() -> void:
	is_locked = true
	is_interactive = false
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_scale = 1.0
	_hover_scale = 1.0
	queue_redraw()

func get_selected_path() -> int:
	return current_path

func toggle() -> void:
	if is_locked or not is_interactive or num_paths <= 1:
		return
	var next_path: int = (current_path + 1) % num_paths
	set_path(next_path, true)
	lever_switched.emit(gate_id, current_path)

func hit_test(world_pos: Vector2) -> bool:
	if is_locked or not is_interactive:
		return false
	var local_pos: Vector2 = to_local(world_pos)

	# 1. Broad Bounding Box early rejection
	# Gates swing between arm_offsets (reaching x = -ARM_DX to 0, and y between min and max offsets)
	var min_arm_x: float = -90.0
	var max_arm_x: float = 60.0
	var min_arm_y: float = -50.0
	var max_arm_y: float = 50.0
	for off in arm_offsets:
		min_arm_x = minf(min_arm_x, off.x - 35.0)
		max_arm_x = maxf(max_arm_x, off.x + 35.0)
		min_arm_y = minf(min_arm_y, off.y - 35.0)
		max_arm_y = maxf(max_arm_y, off.y + 35.0)

	var gate_box := Rect2(min_arm_x, min_arm_y, max_arm_x - min_arm_x, max_arm_y - min_arm_y)
	if not gate_box.has_point(local_pos):
		return false

	# 2. Pivot circle hit test (comfortable 36px radius)
	if local_pos.length_squared() <= 36.0 * 36.0:
		return true

	# 3. Current arm segment hit test (generous 32px width along the beam)
	if _dist_to_segment_sq(local_pos, Vector2.ZERO, _current_arm_offset) <= 32.0 * 32.0:
		return true

	# 4. Target / alternative arm positions and end caps
	for off in arm_offsets:
		if local_pos.distance_squared_to(off) <= 30.0 * 30.0:
			return true
		if _dist_to_segment_sq(local_pos, Vector2.ZERO, off) <= 26.0 * 26.0:
			return true

	# 5. Guide arc hit test
	if arm_offsets.size() >= 2:
		var arc_radius: float = minf(arm_offsets[0].length(), arm_offsets[1].length()) * 0.55
		var dist_to_arc: float = absf(local_pos.length() - arc_radius)
		if dist_to_arc <= 28.0:
			var ang: float = atan2(local_pos.y, local_pos.x)
			var a1: float = atan2(arm_offsets[0].y, arm_offsets[0].x)
			var a2: float = atan2(arm_offsets[1].y, arm_offsets[1].x)
			var min_a: float = minf(a1, a2)
			var max_a: float = maxf(a1, a2)
			if max_a - min_a > PI:
				if ang >= max_a or ang <= min_a:
					return true
			else:
				if ang >= min_a - 0.35 and ang <= max_a + 0.35:
					return true

	return false

func _dist_to_segment_sq(p: Vector2, a: Vector2, b: Vector2) -> float:
	var l2: float = a.distance_squared_to(b)
	if l2 == 0.0:
		return p.distance_squared_to(a)
	var t: float = clampf((p - a).dot(b - a) / l2, 0.0, 1.0)
	var projection: Vector2 = a + t * (b - a)
	return p.distance_squared_to(projection)

func set_hovered(hovered: bool) -> void:
	if is_locked or not is_interactive:
		return
	var target_scale: float = 1.15 if hovered else 1.0
	if absf(_hover_scale - target_scale) > 0.02:
		var tween := create_tween()
		tween.tween_property(self, "_hover_scale", target_scale, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _start_pulse_animation() -> void:
	if is_locked:
		return
		
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
		
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(self, "_pulse_scale", 1.04, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(self, "_pulse_scale", 0.96, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if is_locked or not is_interactive or num_paths <= 1:
		return
		
	var is_click: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	var is_touch: bool = event is InputEventScreenTouch and event.pressed
	if is_click or is_touch:
		toggle()

func _on_area_mouse_entered() -> void:
	set_hovered(true)

func _on_area_mouse_exited() -> void:
	set_hovered(false)

