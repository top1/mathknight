extends CPUParticles2D

var weapon_type: String = "sword_iron"
var impact_particles: Array = []
var font: Font

func _ready() -> void:
	if weapon_type.is_empty() and is_inside_tree() and has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		weapon_type = sm.equipped_cosmetics.get("sword", "sword_iron")

	font = load("res://assets/fonts/Silkscreen-Bold.ttf")
	if not font:
		font = ThemeDB.fallback_font

	_apply_weapon_style()
	_spawn_ascii_impact_sparks()

	emitting = true
	var timer: SceneTreeTimer = get_tree().create_timer(lifetime + 0.3)
	timer.timeout.connect(queue_free)


func setup(weapon_id: String) -> void:
	weapon_type = weapon_id
	if is_inside_tree():
		_apply_weapon_style()
		_spawn_ascii_impact_sparks()


func _apply_weapon_style() -> void:
	var grad: Gradient = Gradient.new()
	match weapon_type:
		"sword_flame":
			grad.colors = PackedColorArray([Color(1.0, 1.0, 0.8), Color(1.0, 0.5, 0.0), Color(0.8, 0.1, 0.0), Color(0.1, 0.1, 0.1, 0.0)])
			amount = 36
			initial_velocity_min = 120.0
			initial_velocity_max = 300.0

		"sword_frost":
			grad.colors = PackedColorArray([Color(1.0, 1.0, 1.0), Color(0.4, 0.9, 1.0), Color(0.1, 0.4, 0.9), Color(0.0, 0.1, 0.4, 0.0)])
			amount = 32
			initial_velocity_min = 90.0
			initial_velocity_max = 240.0

		"sword_lightsaber":
			grad.colors = PackedColorArray([Color(1.0, 1.0, 1.0), Color(0.2, 1.0, 0.8), Color(0.0, 0.7, 0.9), Color(0.0, 0.0, 0.0, 0.0)])
			amount = 40
			initial_velocity_min = 140.0
			initial_velocity_max = 340.0

		"sword_gold":
			grad.colors = PackedColorArray([Color(1.0, 1.0, 0.9), Color(1.0, 0.85, 0.2), Color(0.9, 0.6, 0.1), Color(0.3, 0.2, 0.0, 0.0)])
			amount = 34
			initial_velocity_min = 100.0
			initial_velocity_max = 260.0

		"sword_pan":
			grad.colors = PackedColorArray([Color(1.0, 1.0, 0.7), Color(1.0, 0.75, 0.3), Color(0.6, 0.5, 0.4), Color(0.1, 0.1, 0.1, 0.0)])
			amount = 26
			initial_velocity_min = 80.0
			initial_velocity_max = 220.0

		_: # sword_iron
			grad.colors = PackedColorArray([Color(1.0, 1.0, 1.0), Color(0.5, 0.9, 1.0), Color(0.2, 0.4, 0.8), Color(0.0, 0.0, 0.0, 0.0)])
			amount = 28
			initial_velocity_min = 100.0
			initial_velocity_max = 260.0

	color_ramp = grad


func _spawn_ascii_impact_sparks() -> void:
	impact_particles.clear()
	var symbols: Array[String] = []
	var col_pool: Array[Color] = []

	match weapon_type:
		"sword_flame":
			symbols = ["*", "+", "!", "~", "o", "°"]
			col_pool = [Color("#ff3d00"), Color("#ffab00"), Color("#ffd600"), Color(0.3, 0.25, 0.25)]
		"sword_frost":
			symbols = ["◇", "*", "+", "x", "·"]
			col_pool = [Color("#e0f7fa"), Color("#80deea"), Color("#00e5ff"), Color.WHITE]
		"sword_lightsaber":
			symbols = ["⚡", "\\", "/", "|", "*", "!"]
			col_pool = [Color("#00e5ff"), Color("#69f0ae"), Color("#1de9b6"), Color.WHITE]
		"sword_gold":
			symbols = ["★", "✦", "*", "7", "9", "·"]
			col_pool = [Color("#ffd700"), Color("#ffeb3b"), Color("#fff59d"), Color.WHITE]
		"sword_pan":
			symbols = ["o", "O", "♨", "*", "!"]
			col_pool = [Color("#ffe082"), Color("#ff8a65"), Color(0.5, 0.5, 0.5)]
		_:
			symbols = ["·", "*", "/", "\\", "!"]
			col_pool = [Color("#80d8ff"), Color("#00e5ff"), Color.WHITE]

	for i in range(16):
		var ang = randf() * TAU
		var spd = randf_range(80.0, 240.0)
		impact_particles.append({
			"p": Vector2.ZERO,
			"v": Vector2(cos(ang), sin(ang)) * spd,
			"g": 120.0 if weapon_type != "sword_flame" else -40.0,
			"c": symbols[randi() % symbols.size()],
			"col": col_pool[randi() % col_pool.size()],
			"a": 1.0,
			"decay": randf_range(3.0, 5.5),
			"size": randi_range(7, 10),
		})


func _process(delta: float) -> void:
	var i: int = impact_particles.size() - 1
	while i >= 0:
		var p = impact_particles[i]
		p.v.y += float(p.g) * delta
		p.p += Vector2(p.v) * delta
		p.a -= delta * float(p.decay)
		if p.a <= 0.01:
			impact_particles.remove_at(i)
		i -= 1

	queue_redraw()


func _draw() -> void:
	if font:
		for p in impact_particles:
			var col: Color = Color(p.col, p.a)
			draw_char(font, p.p, p.c, p.size, col)

