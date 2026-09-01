extends Area2D
class_name NumberBubble
## ═══════════════════════════════════════════════════════════════════════════
## NumberBubble — Pixel-Art Cyber-ASCII Math Orb
##
## Features:
##   • 8-Bit Pixel Font (PressStart2P) matching "MATH KNIGHT" Start Screen
##   • Full Cipher Decoding spawn animation (scrambling & unlocking digits)
##   • Live title-style multi-mode character jitter & burst glitching
##   • Densely packed sphere of flickering math symbols (~40+ glyphs)
##   • Tight exclusion zone around central pixel number
##   • 40+-particle physical splatter explosion on slice / tap
## ═══════════════════════════════════════════════════════════════════════════

signal selected(value: int, method: String, bubble: Area2D, slice_dir: Vector2)
signal naturally_expired(bubble: Area2D)

# ---------------------------------------------------------------------------
#  CONSTANTS
# ---------------------------------------------------------------------------
const MC: Array[String] = [
	"0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
	"+", "-", "×", "÷", "=", "%", "#", "<", ">", "!", "?"
]

# ---------------------------------------------------------------------------
#  CONFIG & STATE
# ---------------------------------------------------------------------------
# Shared / Tunable Bubble Visual Configuration (adjustable live in BubbleTuningLab)
static var global_font_override: Font = null
static var global_font_size_1_digit: int = 16
static var global_font_size_2_digit: int = 16
static var global_font_size_3_digit: int = 12
static var global_outline_thickness: int = 1 # 0 = none, 1 = 4-way, 2 = 8-way thick
static var global_shadow_offset: Vector2 = Vector2(1.0, 1.0)
static var global_exclusion_factor: float = 1.15
static var global_text_color: Color = Color("#fff176") # Bright electric yellow
static var global_shadow_color: Color = Color(0.02, 0.02, 0.06, 0.98)

var value: int = 0
var bubble_radius: float = 26.0
var base_position: Vector2
var float_offset: Vector2 = Vector2.ZERO
var float_speed: float = 1.0
var float_amplitude: float = 2.8
var float_amplitude_x: float = 2.8
var float_freq_x: float = 0.7
var float_freq_y: float = 1.0
var phase_offset_x: float = 0.0
var phase_offset_y: float = 0.0

# Motion & Living Ecosystem
var motion_mode: String = "static" # "static", "moving", "living"
var velocity: Vector2 = Vector2.ZERO
var bounds_min: Vector2 = Vector2(36.0, 24.0)
var bounds_max: Vector2 = Vector2(604.0, 118.0)
var lifespan: float = 0.0
var max_lifespan: float = 0.0
var is_expiring: bool = false

var _time: float = 0.0
var is_alive: bool = true
var _is_in_wrong_anim: bool = false
var is_hovered: bool = false

var zone: String = "neutral"
var main_color: Color = Color("#00e5ff")      # Cyan default
var aura_color: Color = Color(0.0, 0.9, 1.0, 0.12)
var text_color: Color = Color(1.0, 0.92, 0.35, 1.0)
var shadow_color: Color = Color(0.02, 0.02, 0.06, 0.98)

# Dense Sphere Characters
var sphere_slots: Array = []

var _target_val_str: String = "0"
var _display_val_str: String = "0"

var pixel_font: Font
var ascii_font: Font

# Splatter Burst Particles & Fading Ghost Characters
var _is_splatting: bool = false
var _splat_t: float = 0.0
var splat_particles: Array = []
var ghost_symbols: Array = []
var slice_cut_line: Dictionary = {}

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# ---------------------------------------------------------------------------
#  LIFECYCLE
# ---------------------------------------------------------------------------
func _ready() -> void:
	# Load authentic PressStart2P pixel font
	pixel_font = load("res://assets/fonts/PressStart2P-Regular.ttf")
	if not pixel_font:
		pixel_font = load("res://assets/fonts/Silkscreen-Bold.ttf")
	if not pixel_font:
		pixel_font = ThemeDB.fallback_font

	ascii_font = load("res://assets/fonts/Silkscreen-Bold.ttf")
	if not ascii_font:
		ascii_font = pixel_font

	phase_offset_x = randf_range(0.0, TAU)
	phase_offset_y = randf_range(0.0, TAU)
	_time = randf() * TAU

	_target_val_str = str(value)
	_display_val_str = _target_val_str
	_update_visuals()
	_build_dense_sphere()


func setup(val: int, pos: Vector2, p_zone: String = "neutral", stage_num: int = 1) -> void:
	value = val
	_target_val_str = str(value)
	_display_val_str = _target_val_str
	base_position = pos
	position = base_position
	set_zone(p_zone)
	_configure_movement(stage_num)
	_build_dense_sphere()


func set_zone(p_zone: String) -> void:
	zone = p_zone
	_update_visuals()


func _update_visuals() -> void:
	text_color = global_text_color
	shadow_color = global_shadow_color
	match zone:
		"left":
			main_color = Color("#00e5ff") # Electric Cyan
			aura_color = Color(0.0, 0.9, 1.0, 0.14)
		"right":
			main_color = Color("#d500f9") # Neon Purple
			aura_color = Color(0.83, 0.0, 0.97, 0.14)
		_:
			main_color = Color("#00e5ff")
			aura_color = Color(0.0, 0.9, 1.0, 0.14)


func _configure_movement(stage: int) -> void:
	var progress: float = clamp(float(stage - 1) / 11.0, 0.0, 1.0)
	float_speed = lerp(0.8, 1.4, progress) * randf_range(0.9, 1.1)
	var base_amp: float = lerp(1.8, 3.2, progress)
	float_amplitude = base_amp * randf_range(0.85, 1.15)
	float_amplitude_x = base_amp * randf_range(0.75, 1.25)
	float_freq_x = randf_range(0.6, 1.0)
	float_freq_y = randf_range(0.8, 1.2)


func play_wrong_anim() -> void:
	_is_in_wrong_anim = true
	_display_val_str = "?"
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(self, "scale", Vector2.ONE, 0.15)
	var shake_tween: Tween = create_tween()
	var base_x = position.x
	shake_tween.tween_property(self, "position:x", base_x - 6.0, 0.04)
	shake_tween.tween_property(self, "position:x", base_x + 6.0, 0.04)
	shake_tween.tween_property(self, "position:x", base_x - 3.0, 0.04)
	shake_tween.tween_property(self, "position:x", base_x + 3.0, 0.04)
	shake_tween.tween_property(self, "position:x", base_x, 0.04)
	var reset_timer := get_tree().create_timer(0.45)
	reset_timer.timeout.connect(func():
		_is_in_wrong_anim = false
		_display_val_str = _target_val_str
	)

# ---------------------------------------------------------------------------
#  CALM AMBIENT SPHERE OF MATHEMATICAL SYMBOLS
# ---------------------------------------------------------------------------
func _build_dense_sphere() -> void:
	sphere_slots.clear()
	var val_len = _target_val_str.length()
	# Wide clean exclusion zone to keep 4 and 9 100% visible and unobstructed
	var half_w: float = (float(val_len) * 7.5 + 4.0) * global_exclusion_factor
	var half_h: float = 9.5 * global_exclusion_factor

	var sp_x: float = 5.6
	var sp_y: float = 7.0
	var rad: float = bubble_radius

	var y: float = -rad
	while y <= rad:
		var x: float = -rad
		while x <= rad:
			var p := Vector2(x + randf_range(-0.8, 0.8), y + randf_range(-0.8, 0.8))
			var dist: float = p.length()

			if dist <= rad:
				var in_exclusion: bool = (abs(p.x) < half_w and abs(p.y) < half_h)
				if not in_exclusion:
					sphere_slots.append({
						"p": p,
						"c": MC[randi() % MC.size()],
						"col": main_color,
						"a": randf_range(0.3, 0.65),
						"ph": randf() * TAU,
						"spd": randf_range(0.8, 1.6)
					})
			x += sp_x
		y += sp_y


func _update_sphere_slots(delta: float) -> void:
	# Calm gentle pulsation for ambient characters
	for s in sphere_slots:
		s.ph += delta * float(s.spd)
		s.a = 0.35 + sin(float(s.ph)) * 0.22

func setup_motion(p_mode: String, p_min: Vector2, p_max: Vector2, p_lifespan: float = 0.0, speed_multiplier: float = 1.0) -> void:
	motion_mode = p_mode
	bounds_min = p_min
	bounds_max = p_max
	max_lifespan = p_lifespan
	lifespan = p_lifespan
	is_expiring = false

	if motion_mode == "moving" or motion_mode == "living":
		var angle: float = randf() * TAU
		var speed: float = randf_range(28.0, 56.0) * speed_multiplier
		velocity = Vector2(cos(angle), sin(angle)) * speed


func _expire_naturally() -> void:
	if not is_alive:
		return
	is_alive = false
	naturally_expired.emit(self)
	var tween: Tween = create_tween()
	if tween:
		tween.tween_property(self, "scale", Vector2(0.1, 0.1), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(self, "modulate:a", 0.0, 0.25)
		tween.tween_callback(queue_free)
	else:
		queue_free()


# ---------------------------------------------------------------------------
#  PROCESS & FLOATING
# ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	if _is_splatting:
		_tick_splatter(delta)
		queue_redraw()
		return

	if not is_alive:
		return

	# 1. Linear Drift & Bounce for Moving and Living modes
	if motion_mode == "moving" or motion_mode == "living":
		base_position += velocity * delta
		if base_position.x < bounds_min.x:
			base_position.x = bounds_min.x
			velocity.x = abs(velocity.x)
		elif base_position.x > bounds_max.x:
			base_position.x = bounds_max.x
			velocity.x = -abs(velocity.x)

		if base_position.y < bounds_min.y:
			base_position.y = bounds_min.y
			velocity.y = abs(velocity.y)
		elif base_position.y > bounds_max.y:
			base_position.y = bounds_max.y
			velocity.y = -abs(velocity.y)

	# 2. Living ecosystem lifecycle countdown
	if motion_mode == "living" and max_lifespan > 0.0 and not _is_splatting:
		lifespan -= delta
		if lifespan <= 1.5 and not is_expiring:
			is_expiring = true
		if lifespan <= 0.0:
			_expire_naturally()
			return

	_time += delta * float_speed
	var off_x: float = sin(_time * float_freq_x + phase_offset_x) * float_amplitude_x
	var off_y: float = cos(_time * float_freq_y + phase_offset_y) * float_amplitude
	float_offset = Vector2(off_x, off_y)
	position = base_position + float_offset

	_update_sphere_slots(delta)
	queue_redraw()

# ---------------------------------------------------------------------------
#  DRAWING PIXEL CYBER-ASCII BUBBLE
# ---------------------------------------------------------------------------
func _draw() -> void:
	if _is_splatting:
		_draw_splatter()
		return

	var current_rad: float = bubble_radius
	if is_hovered:
		current_rad *= 1.12

	var cur_main_col := main_color
	if _is_in_wrong_anim:
		cur_main_col = Color("#ff1744")

	# 1. Soft glowing energy background disk
	var pulse: float = 0.88 + sin(_time * 3.0) * 0.12
	draw_circle(Vector2.ZERO, current_rad * 1.06, Color(aura_color.r, aura_color.g, aura_color.b, aura_color.a * pulse))
	draw_circle(Vector2.ZERO, current_rad * 0.94, Color(0.03, 0.02, 0.07, 0.82))

	# 2. Calm living sphere characters (only outside the exclusion zone)
	for s in sphere_slots:
		var p: Vector2 = Vector2(s.p) + Vector2(
			sin(_time * 1.5 + float(s.ph)) * 0.8,
			cos(_time * 1.3 + float(s.ph)) * 0.6)

		var col: Color = s.col if not _is_in_wrong_anim else Color("#ff5252")
		var a: float = clamp(float(s.a), 0.15, 0.75)
		draw_char(ascii_font, p, s.c, 7, Color(col.r, col.g, col.b, a))

	# 3. Outer boundary cyber ring arc accents
	var arc_ang: float = _time * 1.4
	draw_arc(Vector2.ZERO, current_rad, arc_ang, arc_ang + PI * 0.42, 14, Color(cur_main_col, 0.8), 1.5)
	draw_arc(Vector2.ZERO, current_rad, arc_ang + PI, arc_ang + PI * 1.42, 14, Color(cur_main_col, 0.8), 1.5)

	# 4. Central Number (Stable, Calm, Ultra-Legible Pixel Font)
	var active_font: Font = global_font_override if global_font_override else pixel_font
	if not active_font:
		active_font = pixel_font

	var font_sz: int = global_font_size_1_digit
	if _display_val_str.length() >= 3:
		font_sz = global_font_size_3_digit
	elif _display_val_str.length() == 2:
		font_sz = global_font_size_2_digit

	var val_size: Vector2 = active_font.get_string_size(_display_val_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_sz)
	var text_pos: Vector2 = Vector2(-val_size.x * 0.5, val_size.y * 0.35)

	var cur_text_col: Color = Color("#ff1744") if _is_in_wrong_anim else global_text_color
	var cur_shadow_col: Color = global_shadow_color

	# High-contrast multi-directional pixel outline (makes 4 and 9 crisp and unmistakable)
	if global_outline_thickness >= 1:
		draw_string(active_font, text_pos + Vector2(-1, 0), _display_val_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_sz, cur_shadow_col)
		draw_string(active_font, text_pos + Vector2(1, 0), _display_val_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_sz, cur_shadow_col)
		draw_string(active_font, text_pos + Vector2(0, -1), _display_val_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_sz, cur_shadow_col)
		draw_string(active_font, text_pos + Vector2(0, 1), _display_val_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_sz, cur_shadow_col)

	if global_outline_thickness >= 2:
		draw_string(active_font, text_pos + Vector2(-1, -1), _display_val_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_sz, cur_shadow_col)
		draw_string(active_font, text_pos + Vector2(1, -1), _display_val_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_sz, cur_shadow_col)
		draw_string(active_font, text_pos + Vector2(-1, 1), _display_val_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_sz, cur_shadow_col)
		draw_string(active_font, text_pos + Vector2(1, 1), _display_val_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_sz, cur_shadow_col)

	# Crisp block drop shadow
	if global_shadow_offset != Vector2.ZERO:
		draw_string(active_font, text_pos + global_shadow_offset, _display_val_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_sz, cur_shadow_col)

	# Main Calm Pixel Value
	draw_string(active_font, text_pos, _display_val_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_sz, cur_text_col)

# ---------------------------------------------------------------------------
#  INTERACTION & INPUT
# ---------------------------------------------------------------------------
func on_sliced(_hit_pos: Vector2, _slice_normal: Vector2, slice_dir: Vector2) -> void:
	if not is_alive or _is_in_wrong_anim or _is_splatting:
		return
	selected.emit(value, "swipe", self, slice_dir)


func on_tapped() -> void:
	if not is_alive or _is_in_wrong_anim or _is_splatting:
		return
	selected.emit(value, "tap", self, Vector2.ZERO)


func pop_and_slice(slice_dir: Vector2 = Vector2.ZERO) -> void:
	if _is_splatting:
		return
	is_alive = false
	_trigger_bubble_splatter(slice_dir)


func pop_and_tap() -> void:
	if _is_splatting:
		return
	is_alive = false
	_trigger_bubble_splatter(Vector2(randf_range(-0.5, 0.5), -1.0).normalized())

# ---------------------------------------------------------------------------
#  MATHEMATICAL SPLATTER BURST (Explosion of all ~40+ dense symbols)
# ---------------------------------------------------------------------------
func _trigger_bubble_splatter(slice_dir: Vector2) -> void:
	_is_splatting = true
	_splat_t = 0.0
	splat_particles.clear()
	ghost_symbols.clear()

	if slice_dir != Vector2.ZERO:
		var norm := Vector2(-slice_dir.y, slice_dir.x)
		slice_cut_line = {
			"p0": -norm * 34.0,
			"p1": norm * 34.0,
			"a": 1.0,
		}

	# 1. Capture lingering character ghost shadows right where they were sliced!
	for s in sphere_slots:
		ghost_symbols.append({
			"p": s.p,
			"c": s.c,
			"col": main_color,
			"a": 0.7,
			"decay": 2.8,
			"size": 8,
			"is_pixel": false,
			"v": Vector2(randf_range(-6, 6), randf_range(-6, 6))
		})

	var val_str = str(value)
	for i in range(val_str.length()):
		ghost_symbols.append({
			"p": Vector2(float(i) * 8.0 - 4.0, 0),
			"c": val_str[i],
			"col": Color(1.0, 0.90, 0.28, 1.0),
			"a": 0.85,
			"decay": 2.4,
			"size": 13,
			"is_pixel": true,
			"v": Vector2(0, -4)
		})

	# 2. Explode all dense sphere symbols outward
	for s in sphere_slots:
		var dir := Vector2(s.p).normalized()
		if dir.length() < 0.1:
			dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()

		var spd: float = randf_range(80.0, 260.0)
		var vel: Vector2 = dir * spd + slice_dir * randf_range(70.0, 160.0)

		splat_particles.append({
			"p": s.p,
			"v": vel,
			"g": randf_range(220.0, 480.0),
			"c": s.c,
			"col": main_color if randf() > 0.3 else Color.WHITE,
			"a": 1.0,
			"rs": randf_range(-12.0, 12.0),
			"r": 0.0,
			"size": 8,
			"is_pixel": false,
		})

	# 3. Explode central pixel digits
	for i in range(val_str.length()):
		var char_spd = randf_range(130.0, 300.0)
		var char_dir = (Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() + slice_dir * 1.5).normalized()
		splat_particles.append({
			"p": Vector2(float(i) * 8.0 - 4.0, 0),
			"v": char_dir * char_spd,
			"g": 360.0,
			"c": val_str[i],
			"col": Color(1.0, 0.90, 0.28, 1.0),
			"a": 1.0,
			"rs": randf_range(-8.0, 8.0),
			"r": 0.0,
			"size": 13,
			"is_pixel": true,
		})

	# 4. Extra sparkling math fragments
	for k in range(14):
		var spark_ang = randf() * TAU
		splat_particles.append({
			"p": Vector2.ZERO,
			"v": Vector2(cos(spark_ang), sin(spark_ang)) * randf_range(70.0, 210.0),
			"g": randf_range(160.0, 340.0),
			"c": ["*", "+", "!", "1", "0", "%", "7"][randi() % 7],
			"col": Color.WHITE if randf() > 0.4 else main_color,
			"a": 1.0,
			"rs": randf_range(-10.0, 10.0),
			"r": 0.0,
			"size": 7,
			"is_pixel": false,
		})


func _tick_splatter(delta: float) -> void:
	_splat_t += delta
	var any_visible: bool = false

	if not slice_cut_line.is_empty():
		slice_cut_line.a -= delta * 5.0

	# Update lingering ghost character shadows
	for g in ghost_symbols:
		g.a -= delta * float(g.decay)
		g.p += Vector2(g.v) * delta
		g.v = Vector2(g.v) * 0.92
		if g.a > 0.01:
			any_visible = true

	# Update physical splatter particles
	for p in splat_particles:
		p.v.y += float(p.g) * delta
		p.p += Vector2(p.v) * delta
		p.r += float(p.rs) * delta
		p.a -= delta * 1.7
		p.a = max(0.0, float(p.a))

		if p.a > 0.01:
			any_visible = true
			if randf() < 0.1:
				p.c = MC[randi() % MC.size()]

	if _splat_t > 0.95 or not any_visible:
		queue_free()


func _draw_splatter() -> void:
	# 1. Fading Character Ghost Shadows ("Verblassender Schatten der Zeichen")
	for g in ghost_symbols:
		if g.a > 0.01:
			var gc := Color(g.col, g.a * 0.55)
			var gf: Font = pixel_font if g.is_pixel else ascii_font
			draw_char(gf, g.p + Vector2(-1, 1), g.c, g.size, Color(0, 0, 0, float(g.a) * 0.7))
			draw_char(gf, g.p, g.c, g.size, gc)

	# 2. Slice Cut Laser Line
	if not slice_cut_line.is_empty() and float(slice_cut_line.a) > 0.01:
		var a: float = slice_cut_line.a
		draw_line(slice_cut_line.p0, slice_cut_line.p1, Color(main_color.r, main_color.g, main_color.b, a * 0.75), 5.0)
		draw_line(slice_cut_line.p0, slice_cut_line.p1, Color(1.0, 1.0, 1.0, a * 0.98), 2.2)

	# 3. Splatter Flyaway Particles
	for p in splat_particles:
		var c := Color(p.col, p.a)
		var f: Font = pixel_font if p.is_pixel else ascii_font
		draw_char(f, p.p, p.c, p.size, c)
