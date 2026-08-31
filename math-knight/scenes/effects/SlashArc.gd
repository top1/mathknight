extends Node2D

var slash_color: Color = Color(0.3, 1.0, 1.0, 1.0)
var arc_radius: float = 52.0
var weapon_type: String = "sword_iron"
var arc_particles: Array = []
var arc_glyphs: Array = []
var font: Font

const MC: Array[String] = ["1", "0", "7", "+", "-", "×", "÷", "=", "!", "*", "#", "★", "⚡", "◇"]

func setup(pos: Vector2, rot: float = 0.0, col: Color = Color(0.3, 1.0, 1.0), weapon_id: String = "") -> void:
	position = pos
	rotation = rot
	weapon_type = weapon_id
	if weapon_type.is_empty() and is_inside_tree() and has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		weapon_type = sm.equipped_cosmetics.get("sword", "sword_iron")

	font = load("res://assets/fonts/Silkscreen-Bold.ttf")
	if not font:
		font = ThemeDB.fallback_font

	# Set color per weapon if default or custom provided
	match weapon_type:
		"sword_flame":
			slash_color = Color(1.0, 0.4, 0.05) if col == Color(0.3, 1.0, 1.0) else col
		"sword_frost":
			slash_color = Color(0.2, 0.85, 1.0) if col == Color(0.3, 1.0, 1.0) else col
		"sword_gold":
			slash_color = Color(1.0, 0.85, 0.2) if col == Color(0.3, 1.0, 1.0) else col
		"sword_lightsaber":
			slash_color = Color(0.1, 1.0, 0.8) if col == Color(0.3, 1.0, 1.0) else col
		"sword_pan":
			slash_color = Color(1.0, 0.9, 0.5) if col == Color(0.3, 1.0, 1.0) else col
		_:
			slash_color = col

	scale = Vector2(0.35, 0.35)

	# Generate arc runes and weapon particles
	_generate_arc_effects()

	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.85, 1.85), 0.20) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.20) \
		.set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)


func _generate_arc_effects() -> void:
	arc_glyphs.clear()
	arc_particles.clear()
	var count: int = 12

	for i in range(count):
		var t: float = float(i) / float(count - 1)
		var angle: float = deg_to_rad(-85.0 + (t * 170.0))
		var pt: Vector2 = Vector2(-cos(angle) * arc_radius, sin(angle) * arc_radius * 0.82)
		var out_dir: Vector2 = pt.normalized()

		# Runes along the blade
		arc_glyphs.append({
			"p": pt,
			"c": MC[randi() % MC.size()],
			"v": out_dir * randf_range(20.0, 60.0),
			"size": randi_range(7, 9),
			"col": Color.WHITE if randf() > 0.4 else slash_color
		})

		# Weapon-specific elemental debris
		match weapon_type:
			"sword_flame":
				# Smoke puffs
				arc_particles.append({
					"p": pt + Vector2(randf_range(-6, 6), randf_range(-6, 6)),
					"v": out_dir * randf_range(30, 90) + Vector2(0, -35),
					"c": ["~", "o", "°", "·"][randi() % 4],
					"col": Color(0.25, 0.2, 0.22, 0.8),
					"size": randi_range(8, 12),
				})
				# Fire embers
				arc_particles.append({
					"p": pt,
					"v": out_dir * randf_range(50, 140) + Vector2(0, -25),
					"c": ["*", "+", "1", "7"][randi() % 4],
					"col": [Color("#ff3d00"), Color("#ffab00"), Color.WHITE][randi() % 3],
					"size": randi_range(6, 8),
				})

			"sword_frost":
				arc_particles.append({
					"p": pt,
					"v": out_dir * randf_range(40, 120) + Vector2(0, 15),
					"c": ["◇", "*", "+", "·"][randi() % 4],
					"col": [Color("#e0f7fa"), Color("#00e5ff"), Color.WHITE][randi() % 3],
					"size": randi_range(6, 8),
				})

			"sword_lightsaber":
				arc_particles.append({
					"p": pt,
					"v": Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(60, 160),
					"c": ["⚡", "\\", "/", "|", "*"][randi() % 5],
					"col": [Color("#00e5ff"), Color("#69f0ae"), Color.WHITE][randi() % 3],
					"size": randi_range(7, 10),
				})

			"sword_gold":
				arc_particles.append({
					"p": pt,
					"v": out_dir * randf_range(40, 110),
					"c": ["★", "✦", "*", "7"][randi() % 4],
					"col": [Color("#ffd700"), Color("#fff59d"), Color.WHITE][randi() % 3],
					"size": randi_range(7, 10),
				})

			"sword_pan":
				arc_particles.append({
					"p": pt,
					"v": out_dir * randf_range(40, 100) + Vector2(0, -20),
					"c": ["o", "O", "♨", "*"][randi() % 4],
					"col": [Color("#ffe082"), Color("#ff8a65"), Color(0.4, 0.4, 0.45)][randi() % 3],
					"size": randi_range(8, 12),
				})

			_: # sword_iron
				arc_particles.append({
					"p": pt,
					"v": out_dir * randf_range(50, 130),
					"c": ["·", "*", "/"][randi() % 3],
					"col": [Color("#80d8ff"), Color.WHITE][randi() % 2],
					"size": randi_range(6, 8),
				})


func _process(delta: float) -> void:
	for g in arc_glyphs:
		g.p += Vector2(g.v) * delta
	for p in arc_particles:
		p.p += Vector2(p.v) * delta
	queue_redraw()


func _draw() -> void:
	var outer_points: PackedVector2Array = []
	var count: int = 20

	for i in range(count):
		var t: float = float(i) / float(count - 1)
		var angle: float = deg_to_rad(-85.0 + (t * 170.0))
		outer_points.append(Vector2(-cos(angle) * arc_radius, sin(angle) * arc_radius * 0.82))

	# 1. Weapon Debris & Smoke Particles
	if font:
		for p in arc_particles:
			draw_char(font, p.p, p.c, p.size, p.col)

	# 2. Triple-layer intense luminous neon polyline
	var aura_col = Color(slash_color.r, slash_color.g, slash_color.b, 0.4)
	draw_polyline(outer_points, aura_col, 16.0, true)
	draw_polyline(outer_points, slash_color, 8.5, true)
	draw_polyline(outer_points, Color.WHITE, 3.8, true)

	# 3. Glowing Math Runes along cut
	if font:
		for g in arc_glyphs:
			draw_char(font, Vector2(g.p) + Vector2(-1, 1), g.c, g.size + 1, aura_col)
			draw_char(font, g.p, g.c, g.size, g.col)

