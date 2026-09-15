extends Area2D
class_name NumberBubble
## ═══════════════════════════════════════════════════════════════════════════
## NumberBubble — Cartoon Style Math Orb
##
## Clean, high-legibility cartoon bubble using rendered cartoon textures
## and crisp typography suitable for 6-10 year olds.
## ═══════════════════════════════════════════════════════════════════════════

signal selected(value: int, method: String, bubble: Area2D, slice_dir: Vector2)
signal naturally_expired(bubble: Area2D)

# ---------------------------------------------------------------------------
#  CONFIG & STATE
# ---------------------------------------------------------------------------
static var global_font_override: Font = null
static var global_font_size_1_digit: int = 20
static var global_font_size_2_digit: int = 18
static var global_font_size_3_digit: int = 15
static var global_outline_thickness: int = 2
static var global_text_color: Color = Color.WHITE
static var global_shadow_color: Color = Color(0.1, 0.1, 0.15, 0.95)

@export var value: int = 0:
	set(val):
		value = val
		_target_val_str = str(value)
		_display_val_str = _target_val_str
		if is_inside_tree():
			_update_texture()
			queue_redraw()

var bubble_radius: float = 28.0
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
var _target_val_str: String = "0"
var _display_val_str: String = "0"

var cartoon_font: Font
var bubble_texture: Texture2D = null

# Splatter / Pop animation
var _is_splatting: bool = false
var _splat_t: float = 0.0
var splat_particles: Array = []

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# ---------------------------------------------------------------------------
#  LIFECYCLE
# ---------------------------------------------------------------------------
func _ready() -> void:
	if ResourceLoader.exists("res://assets/fonts/LilitaOne-Regular.ttf"):
		cartoon_font = load("res://assets/fonts/LilitaOne-Regular.ttf")
	elif ResourceLoader.exists("res://assets/fonts/Fredoka-Bold.ttf"):
		cartoon_font = load("res://assets/fonts/Fredoka-Bold.ttf")
	else:
		cartoon_font = ThemeDB.fallback_font

	phase_offset_x = randf_range(0.0, TAU)
	phase_offset_y = randf_range(0.0, TAU)
	_time = randf() * TAU

	_target_val_str = str(value)
	_display_val_str = _target_val_str
	_update_texture()

	# Spawn pop tween
	scale = Vector2(0.3, 0.3)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func setup(val: int, pos: Vector2, p_zone: String = "neutral", stage_num: int = 1) -> void:
	value = val
	_target_val_str = str(value)
	_display_val_str = _target_val_str
	base_position = pos
	position = base_position
	set_zone(p_zone)
	_configure_movement(stage_num)


func set_zone(p_zone: String) -> void:
	zone = p_zone
	_update_texture()


func _update_texture() -> void:
	var path: String
	if zone == "bonus" or zone == "target":
		path = "res://assets/sprites/bubbles/bubble_gold.png"
	elif abs(value) % 2 == 0:
		# Blue for all even numbers
		path = "res://assets/sprites/bubbles/bubble_cyan.png"
	else:
		# Purple for uneven / odd numbers
		path = "res://assets/sprites/bubbles/bubble_purple.png"

	if ResourceLoader.exists(path):
		bubble_texture = load(path)


func _configure_movement(stage: int) -> void:
	var progress: float = clamp(float(stage - 1) / 11.0, 0.0, 1.0)
	float_speed = lerp(0.8, 1.4, progress) * randf_range(0.9, 1.1)
	var base_amp: float = lerp(1.8, 3.2, progress)
	float_amplitude = base_amp * randf_range(0.85, 1.15)
	float_amplitude_x = base_amp * randf_range(0.75, 1.25)
	float_freq_x = randf_range(0.6, 1.0)
	float_freq_y = randf_range(0.8, 1.2)


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


func play_wrong_anim() -> void:
	_is_in_wrong_anim = true
	_display_val_str = "?"
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(self, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BOUNCE)
	tween.tween_interval(0.4)
	tween.tween_callback(func():
		_is_in_wrong_anim = false
		_display_val_str = _target_val_str
		queue_redraw()
	)


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
#  PROCESS & MOTION
# ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	if _is_splatting:
		_tick_splatter(delta)
		queue_redraw()
		return

	if not is_alive:
		return

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

	queue_redraw()


# ---------------------------------------------------------------------------
#  DRAWING
# ---------------------------------------------------------------------------
func _draw() -> void:
	if _is_splatting:
		_draw_splatter()
		return

	var current_rad: float = bubble_radius
	if is_hovered:
		current_rad *= 1.15

	# 1. Bubble Sprite
	if bubble_texture:
		var rect := Rect2(-current_rad, -current_rad, current_rad * 2.0, current_rad * 2.0)
		var draw_col := Color.WHITE
		if _is_in_wrong_anim:
			draw_col = Color(1.0, 0.4, 0.4)
		elif is_expiring:
			draw_col.a = 0.5 + sin(_time * 12.0) * 0.4
		draw_texture_rect(bubble_texture, rect, false, draw_col)
	else:
		draw_circle(Vector2.ZERO, current_rad, Color(0.2, 0.7, 0.9, 0.8))

	# 2. Centered Value Text
	var active_font: Font = global_font_override if global_font_override else cartoon_font
	if not active_font:
		active_font = ThemeDB.fallback_font

	var font_sz: int = global_font_size_1_digit
	if _display_val_str.length() >= 3:
		font_sz = global_font_size_3_digit
	elif _display_val_str.length() == 2:
		font_sz = global_font_size_2_digit

	var val_size: Vector2 = active_font.get_string_size(_display_val_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_sz)
	var text_pos: Vector2 = Vector2(-val_size.x * 0.5, val_size.y * 0.35)

	var cur_text_col: Color = Color("#ff2244") if _is_in_wrong_anim else global_text_color
	var cur_shadow_col: Color = global_shadow_color

	# Thick cartoon outline
	for dx in [-2, -1, 0, 1, 2]:
		for dy in [-2, -1, 0, 1, 2]:
			if dx == 0 and dy == 0:
				continue
			draw_string(active_font, text_pos + Vector2(dx, dy), _display_val_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_sz, cur_shadow_col)

	# Main Text
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
	_trigger_pop(slice_dir)


func pop_and_tap() -> void:
	if _is_splatting:
		return
	is_alive = false
	_trigger_pop(Vector2(randf_range(-0.5, 0.5), -1.0).normalized())


func _trigger_pop(slice_dir: Vector2) -> void:
	_is_splatting = true
	_splat_t = 0.0
	splat_particles.clear()

	# Create sparkling burst particles
	var particle_count := 12
	for i in range(particle_count):
		var ang := randf() * TAU
		var spd := randf_range(60.0, 180.0)
		var vel := Vector2(cos(ang), sin(ang)) * spd + slice_dir * 80.0
		splat_particles.append({
			"p": Vector2.ZERO,
			"v": vel,
			"col": Color(1.0, 0.9, 0.3, 1.0) if randf() > 0.4 else Color(0.4, 0.9, 1.0, 1.0),
			"r": randf_range(3.0, 6.0),
			"a": 1.0
		})

	# Scale pop tween
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.3, 1.3), 0.08)
	tw.tween_property(self, "scale", Vector2.ZERO, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)


func _tick_splatter(delta: float) -> void:
	_splat_t += delta
	for p in splat_particles:
		p.p += p.v * delta
		p.v.y += 180.0 * delta # Gravity
		p.a = clamp(1.0 - (_splat_t / 0.35), 0.0, 1.0)

	if _splat_t >= 0.35:
		queue_free()


func _draw_splatter() -> void:
	for p in splat_particles:
		var c: Color = p.col
		c.a = p.a
		draw_circle(p.p, p.r * p.a, c)
