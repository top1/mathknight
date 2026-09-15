class_name SoldierCluster
extends Node2D

signal count_animation_finished(final_count: int)
signal march_finished
signal castle_attack_finished

var soldier_count: int = 0
var target_count: int = 0
var cluster_radius: float = 40.0

var count_label: Label
var _idle_tween: Tween
var _count_tween: Tween
var _march_tween: Tween

# Represents an individual soldier shape for _draw()
class SoldierData:
	var target_pos: Vector2
	var current_pos: Vector2
	var velocity: Vector2 = Vector2.ZERO
	var scale: float = 1.0
	var color: Color = Color(0.2, 0.5, 1.0)
	var active: bool = true
	var is_dying: bool = false
	var phase_offset: float = 0.0

# Visual attack impact slash & spark effect
class ImpactEffect:
	var pos: Vector2
	var lifetime: float = 0.25
	var time: float = 0.0
	var color: Color = Color(1.0, 0.9, 0.3)
	var slash_angle: float = 0.0
	var size: float = 14.0

var _impact_effects: Array[ImpactEffect] = []
var is_attacking_castle: bool = false
var _last_hit_sfx_time: int = 0

var _soldiers: Array[SoldierData] = []
var _displayed_count: float = 0.0:
	set(val):
		_displayed_count = val
		if count_label:
			count_label.text = str(roundi(_displayed_count))

# Physics and alive animation state
var is_marching: bool = false
var has_corridor_bounds: bool = false
var corridor_y_top: float = -999.0
var corridor_y_bottom: float = 999.0
var _time: float = 0.0

# Gate barrier line segments — soldiers cannot cross these
# Each entry: { "p1": Vector2, "p2": Vector2, "normal": Vector2 }
# p1, p2 are in world space; normal points toward the OPEN/allowed side
var barrier_segments: Array = []

# Left boundary wall (start lane stop) — soldiers cannot cross to the left of this
var min_world_x: float = 45.0
# Right boundary wall (castle gate threshold) — soldiers cannot cross to the right of this
var max_world_x: float = 9999.0


func set_min_x(val: float) -> void:
	min_world_x = val


func set_max_x(val: float) -> void:
	max_world_x = val


func clear_max_x() -> void:
	max_world_x = 9999.0


func _ready() -> void:
	_create_count_label()
	set_count_instant(1)
	animate_idle()


func set_corridor_bounds(top_y: float, bot_y: float) -> void:
	var changed: bool = not has_corridor_bounds or absf(corridor_y_top - top_y) > 2.0 or absf(corridor_y_bottom - bot_y) > 2.0
	has_corridor_bounds = true
	corridor_y_top = top_y
	corridor_y_bottom = bot_y
	if changed and soldier_count > 0:
		_update_soldiers_array(soldier_count)


func clear_corridor_bounds() -> void:
	if has_corridor_bounds:
		has_corridor_bounds = false
		if soldier_count > 0:
			_update_soldiers_array(soldier_count)


## Set gate barrier line segments that soldiers cannot cross.
## Each segment: { "p1": Vector2, "p2": Vector2, "normal": Vector2 }
## p1/p2 in world space. Normal points toward the OPEN (allowed) side.
func set_barrier_segments(segments: Array) -> void:
	barrier_segments = segments


func clear_barrier_segments() -> void:
	barrier_segments.clear()


func _get_soldier_size(total: int) -> float:
	if total > 380:
		return 2.0
	if total > 200:
		return 2.6
	if total > 80:
		return 3.4
	if total > 30:
		return 4.2
	return 5.2


func _process(delta: float) -> void:
	_time += delta

	# Update active impact effects
	if not _impact_effects.is_empty():
		var eff_i: int = _impact_effects.size() - 1
		while eff_i >= 0:
			_impact_effects[eff_i].time += delta
			if _impact_effects[eff_i].time >= _impact_effects[eff_i].lifetime:
				_impact_effects.remove_at(eff_i)
			eff_i -= 1
		queue_redraw()

	if is_attacking_castle:
		# During castle assault, individual soldiers are driven by attack lunges
		queue_redraw()
		return

	var total_count: int = _soldiers.size()
	var sz: float = _get_soldier_size(total_count)
	var sep_dist: float = sz * 1.85

	# Precompute local corridor bounds (world -> local Y offset)
	var local_top: float = -999.0
	var local_bot: float = 999.0
	if has_corridor_bounds:
		local_top = corridor_y_top - global_position.y
		local_bot = corridor_y_bottom - global_position.y

	var min_y_seen: float = 0.0

	# 1. Individual alive movement, spring attraction, and wall forces
	for s in _soldiers:
		if not s.active:
			continue

		var alive_off: Vector2
		if is_marching:
			var stride_phase: float = _time * 13.0 + s.phase_offset
			alive_off = Vector2(
				cos(stride_phase * 0.7) * 1.8,
				absf(sin(stride_phase)) * -2.6 + 0.8
			)
		else:
			alive_off = Vector2(
				cos(_time * 2.2 + s.phase_offset) * 1.1,
				sin(_time * 3.6 + s.phase_offset) * 1.2
			)

		# Center cohesion: pull toward local origin (cluster center)
		# Wall forces handle corridor containment separately
		var to_center: Vector2 = -s.current_pos
		var dist_center: float = to_center.length()
		if dist_center > 0.05:
			var dir_center: Vector2 = to_center / dist_center
			var magnet_strength: float = clampf(dist_center * 3.2, 10.0, 65.0)
			s.velocity += dir_center * (magnet_strength * delta)

		# Anti-clumping near center
		var min_core_radius: float = sz * 0.75
		if dist_center < min_core_radius and dist_center > 0.001:
			var push_out: Vector2 = (s.current_pos / dist_center) * (min_core_radius - dist_center) * 30.0
			s.velocity += push_out * delta

		# Spring toward target position
		var desired_pos: Vector2 = s.target_pos + alive_off
		var to_desired: Vector2 = desired_pos - s.current_pos
		s.velocity += to_desired * (65.0 * delta)

		# Soft wall repulsion forces (push soldiers AWAY from walls before they reach them)
		if has_corridor_bounds:
			var wall_margin: float = sz * 3.0  # Start pushing when this close
			var dist_to_top: float = s.current_pos.y - local_top
			var dist_to_bot: float = local_bot - s.current_pos.y
			if dist_to_top < wall_margin and dist_to_top > -sz:
				var push_strength: float = (wall_margin - dist_to_top) / wall_margin
				s.velocity.y += push_strength * push_strength * 200.0 * delta
			if dist_to_bot < wall_margin and dist_to_bot > -sz:
				var push_strength: float = (wall_margin - dist_to_bot) / wall_margin
				s.velocity.y -= push_strength * push_strength * 200.0 * delta

		# Soft left wall repulsion (start chamber back wall / start lane stop)
		var world_x: float = global_position.x + s.current_pos.x
		var dist_to_left: float = world_x - min_world_x
		var left_margin: float = sz * 3.0
		if dist_to_left < left_margin and dist_to_left > -sz * 2.0:
			var push_strength: float = clampf((left_margin - dist_to_left) / left_margin, 0.0, 1.0)
			s.velocity.x += push_strength * push_strength * 220.0 * delta

		# Soft right wall repulsion (castle gate threshold)
		if max_world_x < 9000.0:
			var dist_to_right: float = max_world_x - world_x
			var right_margin: float = sz * 3.0
			if dist_to_right < right_margin and dist_to_right > -sz * 2.0:
				var push_strength: float = clampf((right_margin - dist_to_right) / right_margin, 0.0, 1.0)
				s.velocity.x -= push_strength * push_strength * 240.0 * delta

		s.velocity *= exp(-11.0 * delta)
		s.velocity = s.velocity.limit_length(120.0)
		s.current_pos += s.velocity * delta

		if s.current_pos.y < min_y_seen:
			min_y_seen = s.current_pos.y

	# 2. Spatial Grid Partitioning for O(N) neighbor collision (2 passes)
	var cell_size: float = maxf(sep_dist * 1.75, 10.0)
	var sep_dist_sq: float = sep_dist * sep_dist

	for _pass in range(2):
		var grid: Dictionary = {}
		for i in range(total_count):
			var s: SoldierData = _soldiers[i]
			if not s.active or s.is_dying:
				continue
			var cx: int = int(floor(s.current_pos.x / cell_size))
			var cy: int = int(floor(s.current_pos.y / cell_size))
			var key: Vector2i = Vector2i(cx, cy)
			if not grid.has(key):
				grid[key] = [i]
			else:
				(grid[key] as Array).append(i)

		for i in range(total_count):
			var s1: SoldierData = _soldiers[i]
			if not s1.active or s1.is_dying:
				continue
			var cx: int = int(floor(s1.current_pos.x / cell_size))
			var cy: int = int(floor(s1.current_pos.y / cell_size))
			for ox in [-1, 0, 1]:
				for oy in [-1, 0, 1]:
					var nkey: Vector2i = Vector2i(cx + ox, cy + oy)
					if not grid.has(nkey):
						continue
					var bucket: Array = grid[nkey]
					for j in bucket:
						if j <= i:
							continue
						var s2: SoldierData = _soldiers[j]
						var diff: Vector2 = s1.current_pos - s2.current_pos
						var dist_sq: float = diff.length_squared()
						if dist_sq < sep_dist_sq and dist_sq > 0.0001:
							var dist: float = sqrt(dist_sq)
							var overlap: float = sep_dist - dist
							var norm: Vector2 = diff / dist
							var push: Vector2 = norm * overlap * 0.45
							s1.current_pos += push
							s2.current_pos -= push
							s1.velocity += push * 8.0
							s2.velocity -= push * 8.0

	# 3. Gate barrier line segment collision (physical gate barriers)
	if not barrier_segments.is_empty():
		var soldier_radius: float = sz * 0.7
		var barrier_radius: float = 4.0 + soldier_radius # beam half-width + soldier radius
		var influence_margin: float = sz * 2.0 # soft repulsion zone near gate arm

		for s in _soldiers:
			if not s.active or s.is_dying:
				continue
			var world_pos: Vector2 = global_position + s.current_pos
			for barrier in barrier_segments:
				var p1: Vector2 = barrier["p1"]
				var p2: Vector2 = barrier["p2"]
				var b_normal: Vector2 = barrier["normal"]
				var seg: Vector2 = p2 - p1
				var seg_len_sq: float = seg.length_squared()
				if seg_len_sq < 0.01:
					continue

				# Closest point on line segment
				var t: float = clampf((world_pos - p1).dot(seg) / seg_len_sq, 0.0, 1.0)
				var closest: Vector2 = p1 + t * seg
				var diff: Vector2 = world_pos - closest
				var dist: float = diff.length()

				# ONLY affect soldiers within proximity of this barrier segment!
				if dist > barrier_radius + influence_margin:
					continue

				# Check whether the soldier is on the open side (normal direction) or blocked side
				var side: float = diff.dot(b_normal)

				if side >= 0.0:
					# On open side: soft repulsion & hard barrier collision
					if dist < barrier_radius:
						var penetration: float = barrier_radius - dist
						s.current_pos += b_normal * penetration
						# Redirect velocity to slide along barrier into the open corridor
						var vel_normal: float = s.velocity.dot(b_normal)
						if vel_normal < 0.0:
							s.velocity -= b_normal * vel_normal
					elif dist < barrier_radius + influence_margin:
						# Soft repulsion: gently funnel toward open lane
						var factor: float = (barrier_radius + influence_margin - dist) / influence_margin
						s.velocity += b_normal * (factor * factor * 140.0 * delta)
				else:
					# On the blocked/wrong side of the gate arm: push firmly to the open side
					var push_back: float = barrier_radius + absf(side)
					s.current_pos += b_normal * push_back
					var vel_normal: float = s.velocity.dot(b_normal)
					if vel_normal < 0.0:
						s.velocity -= b_normal * vel_normal

	if has_corridor_bounds:
		var wall_pad: float = sz * 0.5
		var hard_top: float = local_top + wall_pad
		var hard_bot: float = local_bot - wall_pad
		for s in _soldiers:
			if not s.active or s.is_dying:
				continue
			if s.current_pos.y < hard_top:
				s.current_pos.y = hard_top
				s.velocity.y = maxf(s.velocity.y, 0.0)
				# Also clamp target so spring doesn't fight the wall
				s.target_pos.y = maxf(s.target_pos.y, hard_top)
			elif s.current_pos.y > hard_bot:
				s.current_pos.y = hard_bot
				s.velocity.y = minf(s.velocity.y, 0.0)
				s.target_pos.y = minf(s.target_pos.y, hard_bot)

	# 4. HARD CLAMP left & right boundary walls (zero soldiers can leak past)
	var hard_min_x: float = min_world_x + sz * 0.5
	var hard_max_x: float = max_world_x - sz * 0.5
	for s in _soldiers:
		if not s.active or s.is_dying:
			continue
		var world_x: float = global_position.x + s.current_pos.x
		if world_x < hard_min_x:
			s.current_pos.x = hard_min_x - global_position.x
			s.velocity.x = maxf(s.velocity.x, 0.0)
			s.target_pos.x = maxf(s.target_pos.x, hard_min_x - global_position.x)
		elif world_x > hard_max_x:
			s.current_pos.x = hard_max_x - global_position.x
			s.velocity.x = minf(s.velocity.x, 0.0)
			s.target_pos.x = minf(s.target_pos.x, hard_max_x - global_position.x)

	# 5. Keep count label cleanly positioned above the swarm
	if count_label:
		var target_label_y: float = minf(-35.0, min_y_seen - 24.0)
		if has_corridor_bounds:
			target_label_y = minf(target_label_y, local_top - 24.0)
		count_label.position.y = lerpf(count_label.position.y, target_label_y, 0.2)

	queue_redraw()


func _create_count_label() -> void:
	count_label = Label.new()
	count_label.position = Vector2(-45, -45)
	count_label.size = Vector2(90, 24)
	count_label.pivot_offset = Vector2(45, 12)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	count_label.add_theme_font_size_override("font_size", 16)
	count_label.add_theme_color_override("font_color", Color.WHITE)
	count_label.add_theme_color_override("font_outline_color", Color(0.08, 0.08, 0.12))
	count_label.add_theme_constant_override("outline_size", 4)

	# High-contrast pill stylebox behind the count label
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.16, 0.90)
	style.border_color = Color(0.35, 0.65, 1.0, 0.95)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	count_label.add_theme_stylebox_override("normal", style)

	add_child(count_label)


func set_count_instant(count: int) -> void:
	is_attacking_castle = false
	_impact_effects.clear()
	if count_label:
		count_label.visible = true
	soldier_count = count
	target_count = count
	_displayed_count = count
	_update_soldiers_array(count)

	for i in range(_soldiers.size()):
		if i < count:
			_soldiers[i].current_pos = _soldiers[i].target_pos
			_soldiers[i].scale = 1.0
			_soldiers[i].color = Color(0.2, 0.5, 1.0)
			_soldiers[i].active = true
		else:
			_soldiers[i].active = false

	queue_redraw()


func set_count_animated(new_count: int, duration: float = 0.8) -> void:
	is_attacking_castle = false
	_impact_effects.clear()
	if count_label:
		count_label.visible = true
	target_count = new_count
	var is_growing: bool = new_count > soldier_count

	if _count_tween and _count_tween.is_valid():
		_count_tween.kill()

	_count_tween = create_tween()
	_count_tween.set_parallel(true)

	# Animate the label number
	_count_tween.tween_property(self, "_displayed_count", float(new_count), duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Bounce the label
	if count_label:
		var label_tw := create_tween()
		label_tw.tween_property(count_label, "scale", Vector2(1.35, 1.35), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		label_tw.tween_property(count_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_update_soldiers_array(max(soldier_count, new_count))

	if is_growing:
		play_grow_particles()
		if _has_audio_manager():
			var am = get_node("/root/AudioManager")
			if am.has_method("play_sfx"):
				am.play_sfx("levelup")

		for i in range(soldier_count, new_count):
			var s: SoldierData = _soldiers[i]
			s.active = true
			s.is_dying = false
			s.color = Color(0.2, 0.5, 1.0)
			s.scale = 0.0

			var delay: float = randf_range(0.0, duration * 0.5)
			var seq := create_tween()
			seq.tween_interval(delay)
			seq.tween_property(s, "scale", 1.2, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			seq.tween_property(s, "scale", 1.0, 0.1).set_trans(Tween.TRANS_SINE)
			seq.tween_method(_request_redraw_dummy, 0.0, 1.0, 0.3 + delay)
	else:
		play_shrink_particles()
		if _has_audio_manager():
			var am = get_node("/root/AudioManager")
			if am.has_method("play_sfx"):
				am.play_sfx("wrong")

		for i in range(new_count, soldier_count):
			var s: SoldierData = _soldiers[i]
			s.is_dying = true
			var delay: float = randf_range(0.0, duration * 0.3)

			var seq := create_tween()
			seq.tween_interval(delay)
			seq.tween_property(s, "color", Color(1.0, 0.2, 0.2), 0.1)
			seq.tween_property(s, "scale", 0.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			seq.tween_callback(func(): s.active = false)
			seq.tween_method(_request_redraw_dummy, 0.0, 1.0, 0.4 + delay)

	soldier_count = new_count
	_count_tween.chain().tween_callback(func(): count_animation_finished.emit(soldier_count))


func _request_redraw_dummy(_val: float) -> void:
	queue_redraw()


func _update_soldiers_array(count: int) -> void:
	var positions: Array[Vector2] = _calculate_positions(count)

	while _soldiers.size() < count:
		var new_s := SoldierData.new()
		new_s.phase_offset = float(_soldiers.size()) * 1.6180339887
		_soldiers.append(new_s)

	for i in range(count):
		_soldiers[i].target_pos = positions[i]
		_soldiers[i].phase_offset = float(i) * 1.6180339887


func _calculate_positions(count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if count <= 0:
		return positions

	if count == 1:
		positions.append(Vector2.ZERO)
		return positions

	var sz: float = _get_soldier_size(count)
	var spacing: float = sz * 1.82

	# In a corridor, softly adapt the circular phyllotaxis cluster into an
	# organic oval so soldiers naturally fit inside the lane without fighting the walls
	var y_scale: float = 1.0
	var x_scale: float = 1.0
	if has_corridor_bounds:
		var ch_half_h: float = (corridor_y_bottom - corridor_y_top) * 0.5 - 6.0
		var max_expected_r: float = spacing * sqrt(float(count + 0.6))
		if max_expected_r > ch_half_h and ch_half_h > 8.0:
			y_scale = clampf(ch_half_h / max_expected_r, 0.35, 1.0)
			x_scale = clampf(1.0 / sqrt(y_scale), 1.0, 1.6)

	# Organic phyllotaxis spiral (smooth swarm, no rigid lines or grids)
	var golden_angle: float = 2.3999632297
	for i in range(count):
		var radius: float = spacing * sqrt(float(i + 0.6))
		var theta: float = float(i) * golden_angle
		positions.append(Vector2(cos(theta) * radius * x_scale, sin(theta) * radius * y_scale))

	return positions


func animate_idle() -> void:
	if _idle_tween and _idle_tween.is_valid():
		_idle_tween.kill()

	_idle_tween = create_tween().set_loops()
	_idle_tween.tween_property(self, "scale", Vector2(1.03, 1.03), 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_tween.tween_property(self, "scale", Vector2(0.97, 0.97), 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func animate_march_to(target_pos: Vector2, duration: float = 0.8) -> void:
	if _march_tween and _march_tween.is_valid():
		_march_tween.kill()

	is_marching = true
	_march_tween = create_tween()
	_march_tween.tween_property(self, "global_position", target_pos, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_march_tween.tween_callback(func():
		is_marching = false
		march_finished.emit()
	)


func _draw() -> void:
	# 1. Draw active attack slash & spark effects (drawn even if all soldiers have breached)
	for eff in _impact_effects:
		var progress: float = clampf(eff.time / eff.lifetime, 0.0, 1.0)
		var alpha: float = 1.0 - progress
		var current_size: float = eff.size * (1.0 + progress * 0.4)

		var dir := Vector2.RIGHT.rotated(eff.slash_angle)
		var slash_col := Color(eff.color.r, eff.color.g, eff.color.b, alpha)
		var white_core := Color(1.0, 1.0, 1.0, alpha)

		# Glow slash line
		draw_line(eff.pos - dir * current_size, eff.pos + dir * current_size, slash_col, 3.5)
		# Core sharp blade line
		draw_line(eff.pos - dir * (current_size * 0.75), eff.pos + dir * (current_size * 0.75), white_core, 1.5)

		# Spark burst (4-point star cross)
		var spark_len: float = current_size * 0.55 * (1.0 - progress)
		draw_line(eff.pos - Vector2(spark_len, 0), eff.pos + Vector2(spark_len, 0), white_core, 1.5)
		draw_line(eff.pos - Vector2(0, spark_len), eff.pos + Vector2(0, spark_len), white_core, 1.5)

		# Expanding shockwave ring
		draw_arc(eff.pos, current_size * 0.75, 0, TAU, 12, Color(eff.color.r, eff.color.g, eff.color.b, alpha * 0.6), 1.5)

	var total_active: int = 0
	for s in _soldiers:
		if s.active and not s.is_dying:
			total_active += 1

	if total_active == 0:
		return

	# Dynamic sizing based on army scale
	var sz: float = _get_soldier_size(total_active)

	var shadow_col := Color(0.04, 0.04, 0.08, 0.35)
	var silver_helmet := Color(0.85, 0.88, 0.95)
	var outline_col := Color(0.08, 0.10, 0.16, 0.6)

	for s in _soldiers:
		if not s.active:
			continue

		var soldier_sz: float = sz * s.scale
		if soldier_sz < 0.2:
			continue

		var p: Vector2 = s.current_pos

		# 1. Soft drop shadow under feet
		draw_circle(p + Vector2(0.5, soldier_sz * 0.65), soldier_sz * 0.75, shadow_col)

		# 2. Detailed Knight Token
		if soldier_sz >= 3.2:
			# Stylized shield pentagon body
			var points := PackedVector2Array([
				p + Vector2(0, -soldier_sz * 1.2),
				p + Vector2(soldier_sz, -soldier_sz * 0.4),
				p + Vector2(soldier_sz * 0.85, soldier_sz * 0.9),
				p + Vector2(-soldier_sz * 0.85, soldier_sz * 0.9),
				p + Vector2(-soldier_sz, -soldier_sz * 0.4)
			])
			draw_polygon(points, PackedColorArray([s.color]))
			points.append(points[0])
			draw_polyline(points, outline_col, 1.0, true)

			# Silver Helmet with eye slit
			draw_circle(p + Vector2(0, -soldier_sz * 0.35), soldier_sz * 0.42, silver_helmet)
			draw_line(
				p + Vector2(-soldier_sz * 0.22, -soldier_sz * 0.35),
				p + Vector2(soldier_sz * 0.22, -soldier_sz * 0.35),
				Color(0.12, 0.12, 0.18),
				1.0
			)
		else:
			# Compact round knight token for huge swarms (200-500+ soldiers)
			draw_circle(p, soldier_sz, s.color)
			draw_circle(p + Vector2(0, -soldier_sz * 0.25), soldier_sz * 0.45, silver_helmet)


## Juicy Castle Siege Attack: Every soldier charges the castle door, strikes with spark/slash effects,
## causes the castle to recoil, and breaches inside (disappears).
func animate_castle_attack(castle_sprite: Node2D) -> void:
	is_attacking_castle = true
	is_marching = false
	if _idle_tween and _idle_tween.is_valid():
		_idle_tween.kill()

	# Collect all currently active soldiers
	var attacking_soldiers: Array[SoldierData] = []
	for s in _soldiers:
		if s.active and not s.is_dying:
			attacking_soldiers.append(s)

	if attacking_soldiers.is_empty():
		is_attacking_castle = false
		castle_attack_finished.emit.call_deferred()
		return

	# Sort soldiers so those closest to the castle gate charge first (front-to-back charge)
	attacking_soldiers.sort_custom(func(a: SoldierData, b: SoldierData):
		return a.current_pos.x > b.current_pos.x
	)

	var N: int = attacking_soldiers.size()
	# Door threshold: precisely at the outer entrance of the castle gate (-14px from center)
	var gate_threshold_world_x: float = castle_sprite.global_position.x - 14.0
	var gate_door_x_local: float = to_local(Vector2(gate_threshold_world_x, 0.0)).x
	var gate_center_y_local: float = to_local(castle_sprite.global_position + Vector2(0.0, 6.0)).y

	# Dynamic assault duration: feels fast, punchy, and rhythmic (0.7s - 1.2s total)
	var total_assault_time: float = clampf(0.5 + float(N) * 0.003, 0.7, 1.2)
	var stagger_step: float = (total_assault_time - 0.2) / float(maxi(N, 1))

	# Spawn gate spark particle emitter on the castle
	var spark_emitter: CPUParticles2D = CPUParticles2D.new()
	spark_emitter.emitting = true
	spark_emitter.one_shot = false
	spark_emitter.explosiveness = 0.4
	spark_emitter.lifetime = 0.35
	spark_emitter.amount = 18
	spark_emitter.spread = 150.0
	spark_emitter.direction = Vector2(-1, 0) # Spray sparks back out into courtyard
	spark_emitter.initial_velocity_min = 60.0
	spark_emitter.initial_velocity_max = 130.0
	spark_emitter.scale_amount_min = 2.0
	spark_emitter.scale_amount_max = 3.5
	spark_emitter.gravity = Vector2(0, 140)
	spark_emitter.color = Color(1.0, 0.85, 0.25)
	spark_emitter.position = Vector2(-10, 6)
	castle_sprite.add_child(spark_emitter)

	var orig_castle_pos: Vector2 = castle_sprite.position
	var remaining_count: int = N
	var completed_counter: Array = [0] # Tracks completed soldier attacks

	for i in range(N):
		var s: SoldierData = attacking_soldiers[i]
		var delay: float = float(i) * stagger_step
		var lunge_dur: float = randf_range(0.10, 0.15)
		var start_pos: Vector2 = s.current_pos
		var target_pos: Vector2 = Vector2(gate_door_x_local, gate_center_y_local + randf_range(-7, 7))
		var windup_pos: Vector2 = start_pos + Vector2(randf_range(-6, -3), randf_range(-2, 2))

		var tw: Tween = create_tween()
		if delay > 0.0:
			tw.tween_interval(delay)

		# 1. Quick windup (step back)
		tw.tween_method(func(t: float):
			s.current_pos = start_pos.lerp(windup_pos, t)
		, 0.0, 1.0, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

		# 2. Explosive lunge into gate with stretch — STRICTLY clamped to door threshold!
		tw.tween_method(func(t: float):
			var cur_pos: Vector2 = windup_pos.lerp(target_pos, t)
			cur_pos.x = minf(cur_pos.x, gate_door_x_local)
			s.current_pos = cur_pos
			s.scale = 1.0 + sin(t * PI) * 0.4
		, 0.0, 1.0, lunge_dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)

		# 3. Strike impact right at the door surface & disappear!
		tw.tween_callback(func():
			completed_counter[0] += 1
			var is_last: bool = (completed_counter[0] >= N)

			# Disappear IMMEDIATELY right at the door threshold — no soldier can ever go through!
			s.active = false
			s.scale = 0.0
			remaining_count -= 1
			if count_label:
				count_label.text = str(maxi(remaining_count, 0))

			# Impact visual (slashes & spark cross)
			_spawn_impact_visual(target_pos)
			_play_hit_sfx()

			# Castle shake/recoil
			var recoil_x: float = randf_range(1.5, 3.5)
			var recoil_y: float = randf_range(-2.0, 2.0)
			castle_sprite.position = orig_castle_pos + Vector2(recoil_x, recoil_y)
			var bounce_tw := create_tween()
			bounce_tw.tween_property(castle_sprite, "position", orig_castle_pos, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

			# Flash castle shield / gate
			for child in castle_sprite.get_children():
				if child.has_method("flash_hit"):
					child.flash_hit()

			# Screen shake on impacts
			if (i % 8 == 0 or is_last) and has_node("/root/EventBus"):
				get_node("/root/EventBus").screen_shake_requested.emit(0.06)

			# Comic popup ("POW!", "CLANG!", "SLASH!", "BAM!")
			if (i % 14 == 0 or is_last) and JuiceManager:
				var comic_tags: Array = ["POW!", "CLANG!", "SLASH!", "BAM!"]
				var tag: String = comic_tags.pick_random()
				var popup_pos: Vector2 = global_position + target_pos + Vector2(randf_range(-12, 12), randf_range(-22, -8))
				JuiceManager.spawn_comic_popup(get_parent(), tag, popup_pos)

			queue_redraw()

			# Finale when all soldiers have breached
			if is_last:
				spark_emitter.emitting = false
				var emitter_cleanup := create_tween()
				emitter_cleanup.tween_callback(spark_emitter.queue_free).set_delay(0.5)
				castle_sprite.position = orig_castle_pos
				if count_label:
					count_label.visible = false
				if has_node("/root/EventBus"):
					get_node("/root/EventBus").screen_shake_requested.emit(0.25)
				_spawn_castle_breach_burst(castle_sprite)
				is_attacking_castle = false
				castle_attack_finished.emit()
		)


func _spawn_impact_visual(pos: Vector2) -> void:
	var effect := ImpactEffect.new()
	effect.pos = pos
	effect.slash_angle = randf_range(-0.8, 0.8)
	effect.size = randf_range(12.0, 18.0)
	effect.color = Color(1.0, randf_range(0.75, 0.95), randf_range(0.1, 0.35))
	_impact_effects.append(effect)


func _play_hit_sfx() -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_hit_sfx_time >= 40:
		_last_hit_sfx_time = now
		if has_node("/root/AudioManager"):
			var am: Node = get_node("/root/AudioManager")
			if am.has_method("play_sfx"):
				am.play_sfx("sword_slash", randf_range(1.0, 1.35))


func _spawn_castle_breach_burst(castle_sprite: Node2D) -> void:
	# Trigger breach on castle graphics (doors swing open, golden rays emerge)
	for child in castle_sprite.get_children():
		if child.has_method("breach"):
			child.breach()

	# 1. Crunchy gate breach sound
	if has_node("/root/AudioManager"):
		var am: Node = get_node("/root/AudioManager")
		if am.has_method("play_sfx"):
			am.play_sfx("chest_break")

	# 2. Golden breach sparks
	var burst := CPUParticles2D.new()
	burst.emitting = true
	burst.one_shot = true
	burst.explosiveness = 0.95
	burst.lifetime = 0.75
	burst.amount = 40
	burst.spread = 180.0
	burst.initial_velocity_min = 90.0
	burst.initial_velocity_max = 190.0
	burst.scale_amount_min = 2.5
	burst.scale_amount_max = 5.0
	burst.gravity = Vector2(0, 160)
	burst.color = Color(1.0, 0.88, 0.3)
	burst.position = Vector2(-10, 6)
	castle_sprite.add_child(burst)

	# 3. Wooden door debris splinters flying backward into courtyard
	var debris := CPUParticles2D.new()
	debris.emitting = true
	debris.one_shot = true
	debris.explosiveness = 0.95
	debris.lifetime = 0.85
	debris.amount = 18
	debris.direction = Vector2(-1, -0.3)
	debris.spread = 70.0
	debris.initial_velocity_min = 70.0
	debris.initial_velocity_max = 160.0
	debris.angular_velocity_min = 200.0
	debris.angular_velocity_max = 600.0
	debris.scale_amount_min = 3.0
	debris.scale_amount_max = 5.5
	debris.gravity = Vector2(0, 260)
	debris.color = Color(0.42, 0.26, 0.14)
	debris.position = Vector2(-10, 6)
	castle_sprite.add_child(debris)

	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_callback(func():
		burst.queue_free()
		debris.queue_free()
	)


func play_grow_particles() -> void:
	JuiceManager.squash_and_stretch(self, Vector2(1.25, 0.8), 0.2)


func play_shrink_particles() -> void:
	JuiceManager.hit_stop(get_tree(), 0.05)


func _has_audio_manager() -> bool:
	return has_node("/root/AudioManager")
