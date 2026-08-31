class_name AsciiLoadingSpinner
extends Control
## Circular ASCII Math Glyph Loading Spinner with multi-layer neon glow.
## Replaces static bitmap spinners with animated cyber-math characters.

@export var radius: float = 14.0
@export var symbol_count: int = 8
@export var spin_speed: float = 3.5
@export var core_color: Color = Color(0.3, 0.9, 1.0, 1.0)
@export var halo_color: Color = Color(0.1, 0.5, 1.0, 0.4)

var _font: Font
var _t: float = 0.0
var _symbols: Array[String] = []
var _mutate_timers: Array[float] = []

const MATH_CHARS: Array[String] = [
	"0", "1", "7", "+", "-", "×", "÷", "=", "%", "#", "*", "<", ">", "!"
]

func _ready() -> void:
	custom_minimum_size = Vector2(radius * 2.5, radius * 2.5)
	if ResourceLoader.exists("res://assets/fonts/Silkscreen-Bold.ttf"):
		_font = load("res://assets/fonts/Silkscreen-Bold.ttf")
	else:
		_font = ThemeDB.fallback_font
		
	_symbols.resize(symbol_count)
	_mutate_timers.resize(symbol_count)
	for i in range(symbol_count):
		_symbols[i] = MATH_CHARS[randi() % MATH_CHARS.size()]
		_mutate_timers[i] = randf_range(0.08, 0.3)

func _process(delta: float) -> void:
	_t += delta
	for i in range(symbol_count):
		_mutate_timers[i] -= delta
		if _mutate_timers[i] <= 0.0:
			_mutate_timers[i] = randf_range(0.08, 0.3)
			_symbols[i] = MATH_CHARS[randi() % MATH_CHARS.size()]
	queue_redraw()

func _draw() -> void:
	var center = size * 0.5
	if not _font:
		return
		
	# Draw center soft aura
	draw_circle(center, radius * 0.7, Color(core_color.r, core_color.g, core_color.b, 0.12 + sin(_t * 4.0) * 0.05))
	
	# Current active scanner angle
	var scan_angle = fmod(_t * spin_speed, TAU)
	
	for i in range(symbol_count):
		var angle = (float(i) / float(symbol_count)) * TAU
		var pos = center + Vector2(cos(angle), sin(angle)) * radius
		
		# Distance to current scan line along circle
		var diff = angle - scan_angle
		while diff < -PI: diff += TAU
		while diff > PI: diff -= TAU
		var intensity = max(0.2, 1.0 - abs(diff) / 1.8)
		
		var sym = _symbols[i]
		var sym_size = 9 if intensity > 0.7 else 8
		
		# Halo glow
		if intensity > 0.5:
			draw_circle(pos, 6.0 * intensity, Color(halo_color.r, halo_color.g, halo_color.b, halo_color.a * intensity))
			draw_string(_font, pos + Vector2(-3.5, 3.5), sym, HORIZONTAL_ALIGNMENT_CENTER, -1, sym_size + 1, Color(core_color.r, core_color.g, core_color.b, intensity * 0.4))
		
		# Core glyph
		var glyph_col = Color.WHITE if intensity > 0.85 else Color(core_color.r, core_color.g, core_color.b, intensity)
		draw_string(_font, pos + Vector2(-3.5, 3.5), sym, HORIZONTAL_ALIGNMENT_CENTER, -1, sym_size, glyph_col)
