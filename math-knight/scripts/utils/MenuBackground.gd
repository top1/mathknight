class_name MenuBackground
extends Control
## Dynamic Mathematical & Binary Matrix Digital Rain background.
## Features cascading streams of binary, numbers, operators, glowing lead characters,
## real-time glyph mutations, and ambient magical floating particles.

@export_enum("default", "loading", "map") var variant: String = "default":
	set(val):
		variant = val
		if is_inside_tree():
			_init_matrix_columns()
			_init_ambient_particles()

@export var theme_color: Color = Color(0.2, 0.85, 0.75, 1.0) # Cyber Cyan / Emerald default
@export var matrix_font_size: int = 11
@export var column_spacing: int = 22

var _font: Font
var _columns: Array = []
var _ambient_particles: Array = []
var _last_size: Vector2 = Vector2.ZERO

const MATH_CHARS: Array[String] = [
	"0", "1", "0", "1", "1", "0", # Higher binary weight
	"2", "3", "4", "5", "6", "7", "8", "9",
	"+", "-", "*", "/", "=", "%", "#", "^", "<", ">", "~", "&", "|", "X"
]

func _ready() -> void:
	# Try to load Silkscreen or PressStart font for crisp pixel matrix rendering
	if ResourceLoader.exists("res://assets/fonts/Silkscreen-Bold.ttf"):
		_font = load("res://assets/fonts/Silkscreen-Bold.ttf")
	elif ResourceLoader.exists("res://assets/fonts/PressStart2P-Regular.ttf"):
		_font = load("res://assets/fonts/PressStart2P-Regular.ttf")
	else:
		_font = get_theme_default_font()
		
	_init_matrix_columns()
	_init_ambient_particles()


func _init_matrix_columns() -> void:
	var vp_size: Vector2 = size
	if vp_size.x <= 0 or vp_size.y <= 0:
		vp_size = get_viewport_rect().size
	if vp_size == Vector2.ZERO:
		vp_size = Vector2(640, 360)
	
	_last_size = vp_size
	_columns.clear()
	
	var actual_spacing = column_spacing
	if variant == "loading":
		actual_spacing = 26
	elif variant == "map":
		actual_spacing = 30
		
	var col_count: int = int(vp_size.x / actual_spacing) + 2
	for i in range(col_count):
		_columns.append(_create_column(i * actual_spacing, vp_size.y, true))


func _create_column(col_x: float, max_y: float, random_initial_y: bool = false) -> Dictionary:
	var length: int = randi_range(8, 20)
	if variant == "map":
		length = randi_range(6, 14)
	elif variant == "loading":
		length = randi_range(8, 16)
		
	var chars: Array[String] = []
	for j in range(length):
		chars.append(MATH_CHARS[randi() % MATH_CHARS.size()])
		
	var start_y: float
	if random_initial_y:
		start_y = randf_range(-max_y * 0.5, max_y * 1.2)
	else:
		start_y = randf_range(-180.0, -20.0)
		
	# Subtle color variations (Cyan, Cyber-Gold, Emerald, Neon Violet)
	var col_type: int = randi() % 5
	var lead_col: Color
	var trail_col: Color
	
	match col_type:
		0, 1: # High-tech Cyber Cyan / Aqua
			lead_col = Color(0.85, 1.0, 1.0, 1.0)
			trail_col = Color(0.2, 0.75, 0.95, 0.75)
		2, 3: # Royal Arcane Gold
			lead_col = Color(1.0, 0.98, 0.8, 1.0)
			trail_col = Color(0.95, 0.72, 0.22, 0.75)
		_: # Neon Emerald Matrix
			lead_col = Color(0.8, 1.0, 0.85, 1.0)
			trail_col = Color(0.2, 0.95, 0.5, 0.75)
			
	var speed_min = 55.0
	var speed_max = 140.0
	var brightness_min = 0.65
	var brightness_max = 1.0
	
	if variant == "loading":
		speed_min = 45.0
		speed_max = 110.0
		brightness_min = 0.7
		brightness_max = 1.0
	elif variant == "map":
		speed_min = 25.0
		speed_max = 70.0
		brightness_min = 0.35
		brightness_max = 0.65
	
	return {
		"x": col_x,
		"y": start_y,
		"speed": randf_range(speed_min, speed_max),
		"length": length,
		"chars": chars,
		"mutate_timer": randf_range(0.04, 0.12),
		"mutate_interval": randf_range(0.05, 0.12),
		"lead_color": lead_col,
		"trail_color": trail_col,
		"char_spacing": randf_range(13.0, 16.0),
		"brightness": randf_range(brightness_min, brightness_max),
		"depth_scale": randf_range(0.8, 1.05)
	}


func _init_ambient_particles() -> void:
	_ambient_particles.clear()
	var vp_size: Vector2 = size
	if vp_size.x <= 0 or vp_size.y <= 0:
		vp_size = get_viewport_rect().size
	if vp_size == Vector2.ZERO:
		vp_size = Vector2(640, 360)
		
	var p_count = 24
	if variant == "map":
		p_count = 14
	elif variant == "loading":
		p_count = 20
		
	for i in range(p_count):
		_ambient_particles.append({
			"x": randf_range(0.0, vp_size.x),
			"y": randf_range(0.0, vp_size.y),
			"speed_y": randf_range(-12.0, -32.0),
			"speed_x": randf_range(-8.0, 8.0),
			"radius": randf_range(1.2, 3.2),
			"alpha": randf_range(0.2, 0.6) * (0.6 if variant == "map" else 1.0),
			"pulse_speed": randf_range(1.5, 3.5),
			"color": Color(0.95, 0.8, 0.35) if randf() < 0.5 else Color(0.3, 0.8, 1.0)
		})


func _process(delta: float) -> void:
	var vp_size: Vector2 = size
	if vp_size.x <= 0 or vp_size.y <= 0:
		vp_size = get_viewport_rect().size
	if vp_size == Vector2.ZERO:
		vp_size = Vector2(640, 360)
		
	# Re-init if window size resized significantly
	if abs(vp_size.x - _last_size.x) > 40 or abs(vp_size.y - _last_size.y) > 40:
		_init_matrix_columns()
		_init_ambient_particles()

	# Update matrix streams
	for col in _columns:
		col["y"] += col["speed"] * delta
		
		# Mutate characters randomly in the stream
		col["mutate_timer"] -= delta
		if col["mutate_timer"] <= 0:
			col["mutate_timer"] = col["mutate_interval"]
			var chars: Array = col["chars"]
			if not chars.is_empty():
				var rand_idx: int = randi() % chars.size()
				chars[rand_idx] = MATH_CHARS[randi() % MATH_CHARS.size()]
		
		# Reset column when it passes below bottom
		var total_height: float = col["length"] * col["char_spacing"]
		if col["y"] - total_height > vp_size.y + 30.0:
			var new_col = _create_column(col["x"], vp_size.y, false)
			for k in new_col:
				col[k] = new_col[k]

	# Update ambient glowing dust
	var t: float = Time.get_ticks_msec() * 0.001
	for p in _ambient_particles:
		p["y"] += p["speed_y"] * delta
		p["x"] += sin(t * p["pulse_speed"] + p["radius"]) * p["speed_x"] * delta
		if p["y"] < -10.0:
			p["y"] = vp_size.y + 10.0
			p["x"] = randf_range(0.0, vp_size.x)
			
	queue_redraw()


func _draw() -> void:
	var s: Vector2 = size
	if s.x <= 0 or s.y <= 0:
		s = get_viewport_rect().size
	if s == Vector2.ZERO:
		s = Vector2(640, 360)

	# 1. Dark Cyber-Fantasy Gradient Background
	# Deep Midnight Obsidian (#06050b) to Dark Royal Violet (#110b22)
	var bg_colors: PackedColorArray = PackedColorArray([
		Color(0.04, 0.03, 0.07, 1.0),
		Color(0.05, 0.04, 0.09, 1.0),
		Color(0.09, 0.06, 0.16, 1.0),
		Color(0.12, 0.08, 0.20, 1.0)
	])
	var bg_points: PackedVector2Array = PackedVector2Array([
		Vector2(0, 0),
		Vector2(s.x, 0),
		Vector2(s.x, s.y),
		Vector2(0, s.y)
	])
	draw_polygon(bg_points, bg_colors)

	# Ambient center glow
	var center: Vector2 = s * 0.5
	draw_circle(center, s.y * 0.65, Color(0.2, 0.12, 0.35, 0.15))
	draw_circle(center, s.y * 0.35, Color(0.1, 0.4, 0.6, 0.08))

	if not _font:
		return

	# 2. Draw Mathematical Matrix Rain
	for col in _columns:
		var x: float = col["x"]
		var head_y: float = col["y"]
		var chars: Array = col["chars"]
		var char_count: int = chars.size()
		var spacing: float = col["char_spacing"]
		var lead_col: Color = col["lead_color"]
		var trail_col: Color = col["trail_color"]
		var brightness: float = col["brightness"]
		var f_size: int = int(matrix_font_size * col["depth_scale"])

		for j in range(char_count):
			var char_y: float = head_y - (j * spacing)
			if char_y < -15.0 or char_y > s.y + 15.0:
				continue
				
			var ch: String = chars[j]
			var char_pos: Vector2 = Vector2(x, char_y)
			
			if j == 0:
				# --- Head character (Glowing Luminous Pulse) ---
				var glow_a: float = brightness * 0.95
				var head_c: Color = Color(lead_col.r, lead_col.g, lead_col.b, glow_a)
				
				# Head soft bloom halo
				draw_circle(char_pos + Vector2(4, -4), 8.0, Color(lead_col.r, lead_col.g, lead_col.b, 0.25 * brightness))
				# Crisp head character
				draw_string(_font, char_pos, ch, HORIZONTAL_ALIGNMENT_CENTER, -1, f_size + 1, head_c)
			else:
				# --- Trailing characters with smooth fade-out ---
				var fade_ratio: float = 1.0 - (float(j) / float(char_count))
				var alpha: float = (fade_ratio * fade_ratio) * 0.55 * brightness
				
				# First few trailing chars have higher opacity
				if j < 3:
					alpha = lerp(0.85, alpha, float(j) / 3.0)
					
				var c: Color = Color(trail_col.r, trail_col.g, trail_col.b, alpha)
				draw_string(_font, char_pos, ch, HORIZONTAL_ALIGNMENT_CENTER, -1, f_size, c)

	# 3. Draw Ambient Floating Golden / Cyan Stardust
	for p in _ambient_particles:
		var pos: Vector2 = Vector2(p["x"], p["y"])
		var pulse: float = sin(Time.get_ticks_msec() * 0.003 * p["pulse_speed"]) * 0.3 + 0.7
		var a: float = p["alpha"] * pulse
		var col: Color = p["color"]
		
		# Inner bright core
		draw_circle(pos, p["radius"], Color(col.r, col.g, col.b, a))
		# Outer soft glow halo
		draw_circle(pos, p["radius"] * 2.4, Color(col.r, col.g, col.b, a * 0.25))
