extends Line2D

var max_points: int = 24
var min_point_distance: float = 5.0
var point_lifetime: float = 0.16
var _point_times: Array[float] = []
var _is_active: bool = false

var weapon_type: String = "sword_iron"
var trail_particles: Array = []
var trail_runes: Array = []
var font: Font

const MC: Array[String] = ["1", "0", "7", "+", "-", "×", "÷", "=", "!", "*", "#", "★", "⚡", "◇"]

func _ready() -> void:
	clear_points()
	_point_times.clear()
	top_level = true
	font = load("res://assets/fonts/Silkscreen-Bold.ttf")
	if not font:
		font = ThemeDB.fallback_font
	_update_weapon_style()


func _update_weapon_style() -> void:
	if is_inside_tree() and has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		weapon_type = sm.equipped_cosmetics.get("sword", "sword_iron")

	match weapon_type:
		"sword_flame":
			default_color = Color(1.0, 0.45, 0.1, 1.0)
			point_lifetime = 0.18
		"sword_frost":
			default_color = Color(0.2, 0.85, 1.0, 1.0)
			point_lifetime = 0.18
		"sword_gold":
			default_color = Color("#ffd700")
			point_lifetime = 0.14
		"sword_lightsaber":
			default_color = Color(0.0, 1.0, 0.85, 1.0)
			point_lifetime = 0.32
		"sword_pan":
			default_color = Color(1.0, 0.9, 0.5, 1.0)
			point_lifetime = 0.16
		_:
			default_color = Color(0.0, 0.95, 1.0, 1.0)
			point_lifetime = 0.16


func start_stroke(pos: Vector2) -> void:
	_update_weapon_style()
	_is_active = true
	clear_points()
	_point_times.clear()
	add_trail_point(pos)


func add_trail_point(pos: Vector2) -> void:
	if not _is_active:
		return
		
	if get_point_count() > 0:
		var last_pos: Vector2 = get_point_position(get_point_count() - 1)
		if last_pos.distance_to(pos) < min_point_distance:
			return
			
	add_point(pos)
	_point_times.append(Time.get_ticks_msec() / 1000.0)
	
	while get_point_count() > max_points:
		remove_point(0)
		_point_times.pop_front()

	# Emit weapon particles and runes along swipe stroke
	_emit_stroke_effects(pos)


func _emit_stroke_effects(pos: Vector2) -> void:
	# 1. Trailing glowing ASCII rune along cut
	if randf() < 0.55:
		var rune_col: Color = default_color if randf() > 0.3 else Color.WHITE
		trail_runes.append({
			"p": pos + Vector2(randf_range(-4, 4), randf_range(-4, 4)),
			"c": MC[randi() % MC.size()],
			"col": rune_col,
			"a": 0.95,
			"decay": 5.5,
			"size": randi_range(7, 9),
			"v": Vector2(randf_range(-8, 8), randf_range(-8, 8))
		})

	# 2. Weapon elemental particles along swipe path
	match weapon_type:
		"sword_flame":
			# Rising smoke puff
			if randf() < 0.6:
				trail_particles.append({
					"p": pos + Vector2(randf_range(-5, 5), randf_range(-5, 5)),
					"v": Vector2(randf_range(-12, 12), randf_range(-35, -15)),
					"c": ["~", "o", "°", "·"][randi() % 4],
					"col": Color(0.25, 0.22, 0.25, 0.8),
					"a": 0.8,
					"decay": 3.8,
					"size": randi_range(8, 12),
				})
			# Fire embers
			trail_particles.append({
				"p": pos,
				"v": Vector2(randf_range(-20, 20), randf_range(-45, -15)),
				"c": ["*", "+", "1", "7"][randi() % 4],
				"col": [Color("#ff3d00"), Color("#ff9100"), Color("#ffd600")][randi() % 3],
				"a": 1.0,
				"decay": 4.5,
				"size": randi_range(6, 8),
			})

		"sword_frost":
			trail_particles.append({
				"p": pos + Vector2(randf_range(-4, 4), randf_range(-4, 4)),
				"v": Vector2(randf_range(-10, 10), randf_range(5, 20)),
				"c": ["◇", "*", "+", "·"][randi() % 4],
				"col": [Color("#e0f7fa"), Color("#00e5ff"), Color.WHITE][randi() % 3],
				"a": 0.9,
				"decay": 4.0,
				"size": randi_range(6, 8),
			})

		"sword_lightsaber":
			trail_particles.append({
				"p": pos + Vector2(randf_range(-4, 4), randf_range(-4, 4)),
				"v": Vector2(randf_range(-25, 25), randf_range(-25, 25)),
				"c": ["⚡", "\\", "/", "|", "*"][randi() % 5],
				"col": [Color("#00e5ff"), Color("#69f0ae"), Color.WHITE][randi() % 3],
				"a": 1.0,
				"decay": 6.5,
				"size": randi_range(7, 10),
			})

		"sword_gold":
			trail_particles.append({
				"p": pos + Vector2(randf_range(-4, 4), randf_range(-4, 4)),
				"v": Vector2(randf_range(-15, 15), randf_range(-15, 15)),
				"c": ["★", "✦", "*", "7"][randi() % 4],
				"col": [Color("#ffd700"), Color("#fff59d"), Color.WHITE][randi() % 3],
				"a": 1.0,
				"decay": 4.2,
				"size": randi_range(7, 10),
			})

		"sword_pan":
			trail_particles.append({
				"p": pos + Vector2(randf_range(-4, 4), randf_range(-4, 4)),
				"v": Vector2(randf_range(-12, 12), randf_range(-30, -10)),
				"c": ["o", "O", "♨", "*"][randi() % 4],
				"col": [Color("#ffe082"), Color("#ff8a65"), Color(0.4, 0.4, 0.45)][randi() % 3],
				"a": 0.85,
				"decay": 4.0,
				"size": randi_range(8, 11),
			})

		_: # sword_iron
			if randf() < 0.4:
				trail_particles.append({
					"p": pos,
					"v": Vector2(randf_range(-25, 25), randf_range(-25, 25)),
					"c": ["·", "*", "/"][randi() % 3],
					"col": [Color("#80d8ff"), Color.WHITE][randi() % 2],
					"a": 0.9,
					"decay": 6.0,
					"size": randi_range(6, 8),
				})


func end_stroke() -> void:
	_is_active = false


func _process(delta: float) -> void:
	var current_time: float = Time.get_ticks_msec() / 1000.0
	var i: int = 0
	while i < get_point_count():
		if current_time - _point_times[i] > point_lifetime:
			remove_point(0)
			_point_times.pop_front()
		else:
			break

	# Update runes
	var r_idx: int = trail_runes.size() - 1
	while r_idx >= 0:
		var r = trail_runes[r_idx]
		r.a -= delta * float(r.decay)
		r.p += Vector2(r.v) * delta
		if r.a <= 0.01:
			trail_runes.remove_at(r_idx)
		r_idx -= 1

	# Update particles
	var p_idx: int = trail_particles.size() - 1
	while p_idx >= 0:
		var p = trail_particles[p_idx]
		p.a -= delta * float(p.decay)
		p.p += Vector2(p.v) * delta
		if p.a <= 0.01:
			trail_particles.remove_at(p_idx)
		p_idx -= 1

	queue_redraw()


func _draw() -> void:
	# 1. Weapon Particles
	if font:
		for p in trail_particles:
			var col: Color = Color(p.col, p.a)
			draw_char(font, p.p, p.c, p.size, col)

	# 2. Glowing Math Runes
	if font:
		for r in trail_runes:
			var aura_c: Color = Color(default_color, float(r.a) * 0.4)
			draw_char(font, Vector2(r.p) + Vector2(-1, 1), r.c, r.size + 1, aura_c)
			draw_char(font, r.p, r.c, r.size, Color(r.col, r.a))

	# 3. Triple layered glow on stroke points if active
	if get_point_count() >= 2:
		var pts: PackedVector2Array = points
		var aura_col = Color(default_color.r, default_color.g, default_color.b, 0.35)
		draw_polyline(pts, aura_col, 14.0, true)
		draw_polyline(pts, default_color, 7.0, true)
		draw_polyline(pts, Color.WHITE, 2.8, true)

