class_name AsciiPedestal
extends Control
## ═══════════════════════════════════════════════════════════════════════════
## AsciiPedestal — Cyber-ASCII Obsidian Pedestal with Crimson Rune Accents
##
## Features:
##   • Dark obsidian black base with pure ASCII geometry
##   • Glowing crimson / dark red mathematical rune boundary
##   • Rotating center magic circle in red/amber ASCII
##   • Floating ruby embers & binary motes
## ═══════════════════════════════════════════════════════════════════════════

# ---------------------------------------------------------------------------
#  CONSTANTS
# ---------------------------------------------------------------------------
const MC: Array[String] = [
	"0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
	"+", "-", "×", "÷", "=", "%", "#", "<", ">", "!", "?"
]

const RIM_CHARS: Array[String] = [
	"=", "-", "#", "+", "1", "0", "X", "~", ":"
]

# ---------------------------------------------------------------------------
#  CONFIG & STATE
# ---------------------------------------------------------------------------
@export var radius_x: float = 46.0
@export var radius_y: float = 14.0
@export var base_height: float = 10.0
@export var primary_color: Color = Color("#ff1744") # Crimson red
@export var obsidian_color: Color = Color(0.04, 0.02, 0.05, 0.95)

var font: Font
var _time: float = 0.0

var rim_slots: Array = []
var skirt_slots: Array = []
var float_motes: Array = []

# ---------------------------------------------------------------------------
#  LIFECYCLE
# ---------------------------------------------------------------------------
func _ready() -> void:
	font = load("res://assets/fonts/Silkscreen-Bold.ttf")
	if not font:
		font = ThemeDB.fallback_font

	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_init_slots()


func _init_slots() -> void:
	rim_slots.clear()
	skirt_slots.clear()

	# 1. Outer rim of mathematical glyphs
	var count: int = 24
	for i in range(count):
		var ang = (float(i) / float(count)) * TAU
		rim_slots.append({
			"ang": ang,
			"c": RIM_CHARS[randi() % RIM_CHARS.size()],
			"a": randf_range(0.4, 0.9),
			"fcd": randf_range(0.1, 0.4),
		})

	# 2. Lower cylinder base skirt (3D depth)
	var skirt_count: int = 14
	for i in range(skirt_count):
		var frac = float(i) / float(skirt_count - 1)
		var ang = lerp(0.0, PI, frac) # Front half only
		skirt_slots.append({
			"ang": ang,
			"c": ["|", "1", "0", ":", "!"][randi() % 5],
			"a": randf_range(0.3, 0.7),
			"fcd": randf_range(0.1, 0.4),
		})


func _process(delta: float) -> void:
	_time += delta

	# Update rim glyphs flicker
	for s in rim_slots:
		s.fcd -= delta
		if s.fcd <= 0.0:
			s.fcd = randf_range(0.08, 0.35)
			if randf() < 0.3:
				s.c = RIM_CHARS[randi() % RIM_CHARS.size()]
				s.a = randf_range(0.4, 0.95)

	for s in skirt_slots:
		s.fcd -= delta
		if s.fcd <= 0.0:
			s.fcd = randf_range(0.1, 0.45)
			if randf() < 0.25:
				s.c = ["|", "1", "0", ":", "!"][randi() % 5]

	# Spawn floating ruby binary motes
	if randf() < 0.2:
		var ang = randf() * TAU
		var r_mult = randf_range(0.2, 0.9)
		float_motes.append({
			"p": Vector2(cos(ang) * radius_x * r_mult, sin(ang) * radius_y * r_mult),
			"v": Vector2(randf_range(-4, 4), randf_range(-14, -26)),
			"c": ["0", "1", "+", "*", "·"][randi() % 5],
			"col": primary_color if randf() > 0.35 else Color("#ff5252"),
			"a": randf_range(0.7, 1.0),
			"life": 1.4,
			"max_life": 1.4,
		})

	# Update motes
	var i: int = float_motes.size() - 1
	while i >= 0:
		float_motes[i].life -= delta
		float_motes[i].p += Vector2(float_motes[i].v) * delta
		float_motes[i].a = max(0.0, float(float_motes[i].life) / float(float_motes[i].max_life) * 0.8)
		if float_motes[i].life <= 0.0:
			float_motes.remove_at(i)
		i -= 1

	queue_redraw()


func _draw() -> void:
	var center := size * 0.5

	# ── 1. Lower Cylinder Skirt (3D Bevel Base) ──
	var skirt_poly := PackedVector2Array()
	var segs: int = 24
	for k in range(segs + 1):
		var ang = (float(k) / float(segs)) * PI
		skirt_poly.append(center + Vector2(cos(ang) * radius_x, sin(ang) * radius_y + base_height))
	for k in range(segs, -1, -1):
		var ang = (float(k) / float(segs)) * PI
		skirt_poly.append(center + Vector2(cos(ang) * radius_x, sin(ang) * radius_y))

	# Dark obsidian skirt fill
	draw_colored_polygon(skirt_poly, Color(0.02, 0.01, 0.03, 0.98))

	# Skirt vertical ASCII pillars
	for s in skirt_slots:
		var p_top = center + Vector2(cos(float(s.ang)) * radius_x, sin(float(s.ang)) * radius_y)
		var p_mid = p_top + Vector2(0, base_height * 0.6)
		draw_char(font, p_mid, s.c, 7, Color(primary_color.r * 0.6, primary_color.g * 0.2, primary_color.b * 0.2, float(s.a) * 0.6))

	# ── 2. Top Obsidian Platform ──
	var top_pts := PackedVector2Array()
	for k in range(32 + 1):
		var ang = (float(k) / 32.0) * TAU
		top_pts.append(center + Vector2(cos(ang) * radius_x, sin(ang) * radius_y))

	draw_colored_polygon(top_pts, obsidian_color)

	# ── 3. Outer Crimson / Red ASCII Rim ──
	for s in rim_slots:
		var ang: float = float(s.ang)
		var p = center + Vector2(cos(ang) * radius_x, sin(ang) * radius_y)

		var col := Color(primary_color, s.a)
		if randf() < 0.08:
			col = Color.WHITE

		# Subtle bloom underlay
		draw_char(font, p + Vector2(-1, 1), s.c, 7, Color(primary_color.r, primary_color.g, primary_color.b, float(s.a) * 0.25))
		draw_char(font, p, s.c, 7, col)

	# ── 4. Floating Ruby Binary Motes ──
	for m in float_motes:
		var c := Color(m.col, m.a)
		draw_char(font, center + Vector2(m.p), m.c, 6, c)
