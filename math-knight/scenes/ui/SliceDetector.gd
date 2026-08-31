extends Node2D

@export var collision_mask: int = 2
@export var min_slice_speed: float = 120.0
@export var _trail: Line2D

var _last_position: Vector2
var _last_time: float
var _is_touching: bool = false
var _touch_index: int = -1
var _sliced_rids: Array[RID] = []
var _sliced_nodes: Array[Node2D] = []
var _touch_start_time: float = 0.0
var _touch_start_pos: Vector2

signal object_sliced(target: Node2D, slice_point: Vector2, slice_normal: Vector2)


func _get_world_pos(screen_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_pos


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var pos: Vector2 = _get_world_pos(event.position)
		if event.is_pressed():
			_is_touching = true
			_touch_index = event.index
			_last_position = pos
			_last_time = Time.get_ticks_msec() / 1000.0
			_touch_start_time = _last_time
			_touch_start_pos = pos
			_sliced_rids.clear()
			_sliced_nodes.clear()
			if _trail:
				_trail.start_stroke(pos)
		elif event.index == _touch_index or _touch_index == -1:
			_is_touching = false
			_touch_index = -1
			if _trail:
				_trail.end_stroke()
			if has_node("/root/EventBus"):
				get_node("/root/EventBus").stroke_ended.emit()
			
			var current_time: float = Time.get_ticks_msec() / 1000.0
			if current_time - _touch_start_time < 0.35 and _touch_start_pos.distance_to(pos) < 30.0:
				_check_tap(pos)
				
	elif event is InputEventScreenDrag:
		if _is_touching and (event.index == _touch_index or _touch_index == -1):
			var pos: Vector2 = _get_world_pos(event.position)
			var current_time: float = Time.get_ticks_msec() / 1000.0
			var dt: float = current_time - _last_time
			
			if _trail:
				_trail.add_trail_point(pos)
			
			if dt > 0.0:
				var speed: float = _last_position.distance_to(pos) / dt
				if speed >= min_slice_speed:
					_perform_slice_cast(_last_position, pos)
					
			_last_position = pos
			_last_time = current_time

	elif event is InputEventMouseButton:
		var pos: Vector2 = _get_world_pos(event.position)
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_pressed():
				_is_touching = true
				_last_position = pos
				_last_time = Time.get_ticks_msec() / 1000.0
				_touch_start_time = _last_time
				_touch_start_pos = pos
				_sliced_rids.clear()
				_sliced_nodes.clear()
				if _trail:
					_trail.start_stroke(pos)
			else:
				_is_touching = false
				if _trail:
					_trail.end_stroke()
				if has_node("/root/EventBus"):
					get_node("/root/EventBus").stroke_ended.emit()
				
				var current_time: float = Time.get_ticks_msec() / 1000.0
				if current_time - _touch_start_time < 0.35 and _touch_start_pos.distance_to(pos) < 30.0:
					_check_tap(pos)

	elif event is InputEventMouseMotion:
		if _is_touching:
			var pos: Vector2 = _get_world_pos(event.position)
			var current_time: float = Time.get_ticks_msec() / 1000.0
			var dt: float = current_time - _last_time
			
			if _trail:
				_trail.add_trail_point(pos)
			
			if dt > 0.0:
				var speed: float = _last_position.distance_to(pos) / dt
				if speed >= min_slice_speed:
					_perform_slice_cast(_last_position, pos)
					
			_last_position = pos
			_last_time = current_time


func _perform_slice_cast(from: Vector2, to: Vector2) -> void:
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to, collision_mask, _sliced_rids)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	
	var result: Dictionary = space_state.intersect_ray(query)
	
	if not result.is_empty() and result.has("collider"):
		var collider: Object = result.collider
		var target: Node2D = collider as Node2D
		if target and not _sliced_nodes.has(target):
			_sliced_nodes.append(target)
			if collider is CollisionObject2D:
				_sliced_rids.append((collider as CollisionObject2D).get_rid())
			if target.has_method("on_sliced"):
				var dir: Vector2 = (to - from).normalized()
				var normal: Vector2 = Vector2(-dir.y, dir.x)
				target.on_sliced(result.position, normal, dir)
				object_sliced.emit(target, result.position, normal)


func _check_tap(pos: Vector2) -> void:
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
	query.position = pos
	query.collision_mask = collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = false
	
	var results: Array[Dictionary] = space_state.intersect_point(query)
	for res in results:
		var collider: Object = res.collider
		var target: Node2D = collider as Node2D
		if target and target.has_method("on_tapped"):
			target.on_tapped()
			break
