extends Node2D
## ═══════════════════════════════════════════════════════════════════════════
## ASCII Entity Prototype v5 — Full Body Density & Distinct Enemy Animations
##
## Improvements:
##   • Full body character density restored (no empty cutouts - looks full & rich)
##   • Slime calculation placed on the ground below the slime
##   • Slime hopping animation with squash/stretch & glowing slime floor droplets
##   • Goblin mischievous bouncing trot & head tilt
##   • Skeleton rhythmic clattering march & ribcage sway
##   • Boss intimidating heavy ground pulse & horn flame breathing
##   • Knight refined ready stance & cape flow
##   • 100% Pure ASCII sword, arm, trail, and splatter physics
##
## Controls:
##   SPACE / Click Knight → Attack Strike (ZUSCHLAGEN!)
##   Click Enemy → Knight dashes, slashes & splatters enemy
##   R → Respawn all entities      ESC → Quit
## ═══════════════════════════════════════════════════════════════════════════

# ---------------------------------------------------------------------------
#  CONSTANTS
# ---------------------------------------------------------------------------
const VP := Vector2(640, 360)
const SP := Vector2(6, 8)
const BFS := 8
const EFS := 14

const MC: Array[String] = [
	"0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
	"+", "-", "×", "÷", "=", "%", "#", "<", ">", "!", "?"
]

const SWORD_CHARS: Array[String] = [
	"1", "0", "7", "|", "/", "!", "+", "X", "=", "I", "T", "#"
]

# ---------------------------------------------------------------------------
#  STATE
# ---------------------------------------------------------------------------
var font: Font
var entities: Array = []
var _bg: Array = []
var slime_droplets: Array = []       # Slime floor trail particles
var _t: float = 0.0
var _info_alpha: float = 1.0

# Pure ASCII Sword & Arm State
var knight_ref: Dictionary = {}
var sword_slots: Array = []
var sword_trail_chars: Array = []
var slash_glyph_arcs: Array = []

enum KnightAttackState { IDLE, WINDUP, SLASH, RECOVER }
var knight_atk_state: KnightAttackState = KnightAttackState.IDLE
var knight_atk_timer: float = 0.0
var knight_arm_angle_upper: float = 0.35
var knight_arm_angle_lower: float = -0.55
var knight_sword_angle: float = -0.35
var knight_target_enemy_pos: Vector2 = Vector2.ZERO
var knight_is_dashing: bool = false
var knight_orig_pos: Vector2 = Vector2(85, 195)
var knight_current_pos: Vector2 = Vector2(85, 195)

# ---------------------------------------------------------------------------
#  LIFECYCLE
# ---------------------------------------------------------------------------
func _ready() -> void:
	font = load("res://assets/fonts/Silkscreen-Bold.ttf")
	if not font:
		font = ThemeDB.fallback_font
	_init_bg()
	_init_sword_slots()
	_spawn_entities()


func _process(delta: float) -> void:
	_t += delta
	_info_alpha = max(0.0, _info_alpha - delta * 0.05)
	_update_bg(delta)
	_update_knight_sword_animation(delta)
	_update_sword_slots(delta)
	_update_sword_trail_chars(delta)
	_update_slash_glyph_arcs(delta)
	_update_slime_droplets(delta)

	for e in entities:
		if not e.alive:
			continue
		e.t += delta
		_update_blinking(e, delta)

		if e.splatting:
			_tick_splatter(e, delta)
		else:
			_tick_anim(e, delta)

	queue_redraw()


func _draw() -> void:
	_draw_background()
	_draw_bg_rain()

	# Slime floor droplets
	_draw_slime_droplets()

	# 1. Pure ASCII ghost sword trail
	_draw_sword_trail_chars()

	# 2. Draw entities
	for e in entities:
		if e.alive:
			_draw_entity(e)

	# 3. Draw Knight's Pure ASCII Arm & White Numbers Sword
	if knight_ref.has("alive") and knight_ref.alive:
		_draw_ascii_arm_and_sword()

	# 4. Draw slash impact math glyph arcs
	_draw_slash_glyph_arcs()

	_draw_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_click(event.position)
	if event is InputEventMouseMotion:
		_handle_hover(event.position)
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE:
				_trigger_knight_strike()
			KEY_R:
				_spawn_entities()
			KEY_ESCAPE:
				get_tree().quit()

# ---------------------------------------------------------------------------
#  BACKGROUND
# ---------------------------------------------------------------------------
func _init_bg() -> void:
	_bg.clear()
	for i in range(60):
		_bg.append({
			"p": Vector2(randf_range(0, VP.x), randf_range(-60, VP.y)),
			"c": MC[randi() % MC.size()],
			"sp": randf_range(12, 42),
			"a": randf_range(0.03, 0.12),
			"dx": randf_range(-0.4, 0.4),
			"ci": randi() % 3,
		})


func _update_bg(delta: float) -> void:
	for b in _bg:
		b.p.y += b.sp * delta
		b.p.x += b.dx
		if b.p.y > VP.y + 10:
			b.p.y = randf_range(-30, -10)
			b.p.x = randf_range(0, VP.x)
			b.c = MC[randi() % MC.size()]


func _draw_background() -> void:
	draw_rect(Rect2(Vector2.ZERO, VP), Color("#06050b"))
	for i in range(3):
		var r: float = 190.0 - float(i) * 50.0
		var a: float = 0.025 + float(i) * 0.008
		draw_circle(VP * 0.5, r, Color(0.15, 0.08, 0.28, a))


func _draw_bg_rain() -> void:
	var cols = [Color(0.16, 0.71, 0.96), Color(0.97, 0.77, 0.16), Color(0.6, 0.6, 0.7)]
	for b in _bg:
		var c := Color(cols[b.ci], b.a)
		draw_char(font, b.p, b.c, 7, c)

# ---------------------------------------------------------------------------
#  PURE ASCII SWORD SLOTS
# ---------------------------------------------------------------------------
func _init_sword_slots() -> void:
	sword_slots.clear()
	var blade_slot_count: int = 14
	for i in range(blade_slot_count):
		sword_slots.append({
			"t_pos": float(i) / float(blade_slot_count - 1),
			"c": SWORD_CHARS[randi() % SWORD_CHARS.size()],
			"a": 1.0,
			"fcd": randf_range(0.04, 0.12),
			"jitter": Vector2.ZERO,
			"type": "blade",
		})

	for i in [-1.0, 1.0]:
		sword_slots.append({
			"t_pos": 0.08,
			"offset_side": i * 6.5,
			"c": "=",
			"a": 0.95,
			"fcd": randf_range(0.08, 0.2),
			"jitter": Vector2.ZERO,
			"type": "guard",
		})

	sword_slots.append({
		"t_pos": -0.12,
		"offset_side": 0.0,
		"c": "0",
		"a": 0.85,
		"fcd": 0.3,
		"jitter": Vector2.ZERO,
		"type": "pommel",
	})


func _update_sword_slots(delta: float) -> void:
	for s in sword_slots:
		s.fcd -= delta
		if s.fcd <= 0.0:
			s.fcd = randf_range(0.04, 0.11)
			if s.type == "blade":
				s.c = SWORD_CHARS[randi() % SWORD_CHARS.size()]
				s.jitter = Vector2(randf_range(-1.2, 1.2), randf_range(-1.2, 1.2))
				s.a = randf_range(0.9, 1.0)
			elif s.type == "guard":
				s.c = "=" if randf() > 0.4 else "+"
				s.jitter = Vector2(randf_range(-0.8, 0.8), randf_range(-0.8, 0.8))

# ---------------------------------------------------------------------------
#  ENTITY FACTORY & EYES DEFINITION
# ---------------------------------------------------------------------------
func _spawn_entities() -> void:
	entities.clear()
	sword_trail_chars.clear()
	slash_glyph_arcs.clear()
	slime_droplets.clear()

	# ── Knight (Player) ─────────────────────────────────────────
	var knight = _make_entity(
		knight_orig_pos, _knight_polys(),
		Color("#29b6f6"), Color("#4fc3f7"), Color("#ffd600"),
		"", "RITTER", "knight"
	)
	knight.part_c = { 4: Color("#5c6bc0"), 5: Color("#0288d1") }
	knight.eyes = {
		"positions": [Vector2(-3.0, -41.0), Vector2(3.0, -41.0)],
		"color": Color("#00ffff"),
		"size": 1.4,
		"style": "visor_glow",
		"blink_timer": randf_range(2.5, 4.0),
		"blink_progress": 0.0,
		"is_blinking": false,
	}
	_fill_slots(knight)
	entities.append(knight)
	knight_ref = knight
	knight_current_pos = knight_orig_pos

	# ── Goblin ──────────────────────────────────────────────────
	var goblin = _make_entity(
		Vector2(210, 210), _goblin_polys(),
		Color("#43a047"), Color("#66bb6a"), Color("#ffd600"),
		"3 + 4", "GOBLIN", "goblin"
	)
	goblin.eyes = {
		"positions": [Vector2(-5.5, -12), Vector2(5.5, -12)],
		"color": Color("#ffb300"),
		"size": 2.5,
		"style": "round_glow",
		"blink_timer": randf_range(2.0, 3.8),
		"blink_progress": 0.0,
		"is_blinking": false,
	}
	_fill_slots(goblin)
	entities.append(goblin)

	# ── Skeleton ────────────────────────────────────────────────
	var skel = _make_entity(
		Vector2(330, 200), _skeleton_polys(),
		Color("#7e57c2"), Color("#b39ddb"), Color("#ffeb3b"),
		"12 - 7", "SKELETT", "skeleton"
	)
	skel.eyes = {
		"positions": [Vector2(-4.5, -37), Vector2(4.5, -37)],
		"color": Color("#00e5ff"),
		"size": 2.2,
		"style": "flame_glow",
		"blink_timer": randf_range(3.0, 5.0),
		"blink_progress": 0.0,
		"is_blinking": false,
	}
	_fill_slots(skel)
	entities.append(skel)

	# ── Slime ───────────────────────────────────────────────────
	var slime = _make_entity(
		Vector2(445, 206), _slime_polys(),
		Color("#64dd17"), Color("#b2ff59"), Color("#ffeb3b"),
		"8 × 3", "SCHLEIM", "slime"
	)
	slime.eyes = {
		"positions": [Vector2(-7.0, 10), Vector2(7.0, 10)],
		"color": Color("#aeea00"),
		"size": 3.0,
		"style": "squish_glow",
		"blink_timer": randf_range(1.8, 3.2),
		"blink_progress": 0.0,
		"is_blinking": false,
	}
	_fill_slots(slime)
	entities.append(slime)

	# ── Boss ────────────────────────────────────────────────────
	var boss = _make_entity(
		Vector2(565, 185), _boss_polys(),
		Color("#c62828"), Color("#ef5350"), Color("#ffd600"),
		"15 ÷ 3", "BOSS", "boss"
	)
	boss.eyes = {
		"positions": [Vector2(-7.0, -50), Vector2(7.0, -50)],
		"color": Color("#ff1744"),
		"size": 3.2,
		"style": "boss_glow",
		"blink_timer": randf_range(3.5, 5.5),
		"blink_progress": 0.0,
		"is_blinking": false,
	}
	_fill_slots(boss)
	entities.append(boss)


func _make_entity(pos: Vector2, polys: Array, base_c: Color,
		glow_c: Color, eq_c: Color, eq: String, nm: String, anim_type: String) -> Dictionary:
	return {
		"pos": pos, "polys": polys,
		"base_c": base_c, "glow_c": glow_c, "eq_c": eq_c,
		"equation": eq, "name": nm, "anim_type": anim_type,
		"part_c": {}, "slots": [], "alive": true, "splatting": false,
		"splat_t": 0.0, "t": randf() * TAU, "hover": false,
		"eyes": {},
		"eq_layout": [],
		"eq_center": Vector2.ZERO,
		"scale_mod": Vector2.ONE,
		"offset_mod": Vector2.ZERO,
		"rot_mod": 0.0,
		"slime_hop_t": randf() * 2.0,
	}

# ---------------------------------------------------------------------------
#  POLYGON DEFINITIONS
# ---------------------------------------------------------------------------
func _knight_polys() -> Array:
	return [
		# 0 — Helmet
		PackedVector2Array([
			Vector2(-8, -54), Vector2(8, -54), Vector2(12, -46),
			Vector2(12, -38), Vector2(-12, -38), Vector2(-12, -46)]),
		# 1 — Torso
		PackedVector2Array([
			Vector2(-20, -38), Vector2(20, -38),
			Vector2(18, 8), Vector2(-18, 8)]),
		# 2 — Left leg
		PackedVector2Array([
			Vector2(-16, 8), Vector2(-4, 8),
			Vector2(-4, 36), Vector2(-16, 36)]),
		# 3 — Right leg
		PackedVector2Array([
			Vector2(4, 8), Vector2(16, 8),
			Vector2(16, 36), Vector2(4, 36)]),
		# 4 — Shield
		PackedVector2Array([
			Vector2(-28, -22), Vector2(-18, -22),
			Vector2(-18, 6), Vector2(-28, 6)]),
		# 5 — Cape
		PackedVector2Array([
			Vector2(-18, -34), Vector2(-12, -34),
			Vector2(-8, 28), Vector2(-28, 22), Vector2(-30, -2)]),
	]


func _goblin_polys() -> Array:
	return [
		PackedVector2Array([
			Vector2(-10, -20), Vector2(10, -20), Vector2(13, -12),
			Vector2(13, -4), Vector2(-13, -4), Vector2(-13, -12)]),
		PackedVector2Array([
			Vector2(-16, -4), Vector2(16, -4),
			Vector2(18, 22), Vector2(-18, 22)]),
		PackedVector2Array([
			Vector2(-12, 22), Vector2(-3, 22),
			Vector2(-3, 36), Vector2(-12, 36)]),
		PackedVector2Array([
			Vector2(3, 22), Vector2(12, 22),
			Vector2(12, 36), Vector2(3, 36)]),
	]


func _skeleton_polys() -> Array:
	return [
		PackedVector2Array([
			Vector2(-9, -46), Vector2(9, -46), Vector2(11, -36),
			Vector2(7, -28), Vector2(-7, -28), Vector2(-11, -36)]),
		PackedVector2Array([
			Vector2(-11, -28), Vector2(11, -28),
			Vector2(9, 4), Vector2(-9, 4)]),
		PackedVector2Array([
			Vector2(-7, 4), Vector2(7, 4),
			Vector2(6, 12), Vector2(-6, 12)]),
		PackedVector2Array([
			Vector2(-7, 12), Vector2(-2, 12),
			Vector2(-2, 38), Vector2(-7, 38)]),
		PackedVector2Array([
			Vector2(2, 12), Vector2(7, 12),
			Vector2(7, 38), Vector2(2, 38)]),
	]


func _slime_polys() -> Array:
	return [
		PackedVector2Array([
			Vector2(0, -12), Vector2(14, -8), Vector2(24, 2),
			Vector2(28, 14), Vector2(24, 26), Vector2(14, 34),
			Vector2(0, 36), Vector2(-14, 34), Vector2(-24, 26),
			Vector2(-28, 14), Vector2(-24, 2), Vector2(-14, -8)]),
	]


func _boss_polys() -> Array:
	return [
		PackedVector2Array([
			Vector2(-14, -58), Vector2(14, -58),
			Vector2(16, -42), Vector2(-16, -42)]),
		PackedVector2Array([
			Vector2(-16, -58), Vector2(-11, -58),
			Vector2(-9, -72), Vector2(-18, -66)]),
		PackedVector2Array([
			Vector2(11, -58), Vector2(16, -58),
			Vector2(18, -66), Vector2(9, -72)]),
		PackedVector2Array([
			Vector2(-24, -42), Vector2(24, -42),
			Vector2(26, 14), Vector2(-26, 14)]),
		PackedVector2Array([
			Vector2(-20, 14), Vector2(-6, 14),
			Vector2(-6, 40), Vector2(-20, 40)]),
		PackedVector2Array([
			Vector2(6, 14), Vector2(20, 14),
			Vector2(20, 40), Vector2(6, 40)]),
		PackedVector2Array([
			Vector2(-32, -32), Vector2(-24, -32),
			Vector2(-24, 10), Vector2(-32, 10)]),
		PackedVector2Array([
			Vector2(24, -32), Vector2(32, -32),
			Vector2(32, 10), Vector2(24, 10)]),
	]

# ---------------------------------------------------------------------------
#  SLOT POPULATION (Full Rich Density Restored!)
# ---------------------------------------------------------------------------
func _fill_slots(e: Dictionary) -> void:
	e.slots = []

	for pi in range(e.polys.size()):
		var poly: PackedVector2Array = e.polys[pi]
		var rect := _poly_rect(poly)
		var y: float = rect.position.y
		while y < rect.end.y:
			var x: float = rect.position.x
			while x < rect.end.x:
				var p := Vector2(
					x + randf_range(-2.0, 2.0),
					y + randf_range(-2.0, 2.0))

				if Geometry2D.is_point_in_polygon(p, poly):
					if randf() < 0.05:
						x += SP.x
						continue
					var slot_color: Color = e.base_c
					if e.part_c.has(pi):
						slot_color = e.part_c[pi]
					e.slots.append({
						"p": p,
						"c": MC[randi() % MC.size()],
						"col": slot_color,
						"a": randf_range(0.35, 0.85),
						"ph": randf() * TAU,
						"fcd": randf_range(0.06, 0.45),
						"eq": false,
						"pi": pi,
						"v": Vector2.ZERO,
						"g": 0.0,
						"r": 0.0,
						"rs": 0.0,
					})
				x += SP.x
			y += SP.y

	# Calculate and insert foreground equation slots
	_insert_equation_slots(e)


func _insert_equation_slots(e: Dictionary) -> void:
	if e.equation.is_empty():
		return

	var ctr := _centroid(e)
	var is_slime: bool = (e.anim_type == "slime")

	if is_slime:
		ctr = Vector2(0, 14)
	else:
		ctr.y += 2.0

	e.eq_center = ctr

	var eq: String = e.equation
	var char_positions: Array = []
	var total_w: float = 0.0

	# Token-aware kerning: multi-digit numbers stay tightly together
	var i: int = 0
	while i < eq.length():
		var ch: String = eq[i]
		if ch == " ":
			total_w += 4.5
			char_positions.append({ "c": " ", "offset_x": total_w, "is_space": true })
		else:
			var is_digit: bool = (ch >= "0" and ch <= "9")
			var next_is_digit: bool = false
			if i + 1 < eq.length():
				var next_ch: String = eq[i + 1]
				next_is_digit = (next_ch >= "0" and next_ch <= "9")

			char_positions.append({ "c": ch, "offset_x": total_w, "is_space": false })

			if is_digit and next_is_digit:
				total_w += 8.0 # Tight kerning for 2-digit numbers
			else:
				total_w += 10.5
		i += 1

	var start_x: float = ctr.x - total_w * 0.5
	for cp in char_positions:
		if not cp.is_space:
			e.slots.append({
				"p": Vector2(start_x + float(cp.offset_x), ctr.y),
				"c": cp.c,
				"col": e.eq_c,
				"a": 1.0,
				"ph": randf() * TAU,
				"fcd": 999.0,
				"eq": true,
				"pi": -1,
				"v": Vector2.ZERO,
				"g": 0.0,
				"r": 0.0,
				"rs": 0.0,
			})

# ---------------------------------------------------------------------------
#  DISTINCT ENEMY MOVEMENT ANIMATIONS (Slime hop, Goblin trot, Skeleton clatter, Boss pulse)
# ---------------------------------------------------------------------------
func _tick_anim(e: Dictionary, delta: float) -> void:
	var anim_type: String = e.anim_type

	match anim_type:
		"slime":
			e.slime_hop_t += delta * 2.8
			var hop_period: float = 1.25
			var cycle: float = fmod(float(e.slime_hop_t), hop_period)
			var ground_time: float = 0.32

			if cycle < ground_time:
				var ground_p: float = cycle / ground_time
				var squash: float = sin(ground_p * PI)
				e.scale_mod = Vector2(1.0 + squash * 0.34, 1.0 - squash * 0.34)
				e.offset_mod = Vector2(0, squash * 2.5)

				if e.has("was_airborne") and e.was_airborne:
					e.was_airborne = false
					_spawn_slime_landing_puddle(e.pos)
			else:
				e.was_airborne = true
				var air_p: float = (cycle - ground_time) / (hop_period - ground_time)
				var hop_arc: float = sin(air_p * PI)
				var hop_y: float = hop_arc * 28.0
				e.offset_mod = Vector2(0, -hop_y)

				var stretch_x: float = lerp(1.15, 0.74, hop_arc)
				var stretch_y: float = lerp(0.85, 1.34, hop_arc)
				e.scale_mod = Vector2(stretch_x, stretch_y)

				if randf() < 0.12:
					_spawn_slime_droplet(e.pos + Vector2(randf_range(-6, 6), 34 - hop_y * 0.5))

		"goblin":
			var trot_y: float = abs(sin(float(e.t) * 6.5)) * 3.5
			var tilt_x: float = sin(float(e.t) * 6.5) * 2.0
			e.offset_mod = Vector2(tilt_x, -trot_y)
			e.rot_mod = sin(float(e.t) * 6.5) * 0.06
			e.scale_mod = Vector2(1.0 + sin(float(e.t) * 13.0) * 0.03, 1.0 - sin(float(e.t) * 13.0) * 0.03)

		"skeleton":
			# Rhythmic clattering march & ribcage sway
			var sway_x: float = sin(float(e.t) * 4.2) * 3.0
			var march_y: float = abs(cos(float(e.t) * 4.2)) * 3.2
			e.offset_mod = Vector2(sway_x, -march_y)
			e.rot_mod = sin(float(e.t) * 4.2) * 0.05
			e.scale_mod = Vector2.ONE

		"boss":
			# Intimidating heavy ground stomp & horn flame pulse
			var stomp_y: float = sin(float(e.t) * 2.2) * 2.0
			var pulse: float = 1.0 + sin(float(e.t) * 2.0) * 0.05
			e.offset_mod = Vector2(0, stomp_y)
			e.scale_mod = Vector2(pulse, pulse)

		"knight":
			# Knight ready breathing
			var breath_y: float = sin(float(e.t) * 2.2) * 3.0
			e.offset_mod = Vector2(0, breath_y)
			e.scale_mod = Vector2.ONE

	# Scan-line character flicker
	var scan_y: float = sin(float(e.t) * 2.5) * 35.0
	for s in e.slots:
		if s.eq:
			continue

		s.fcd -= delta
		if s.fcd <= 0.0:
			var rate: float = 1.0 if not e.hover else 0.4
			s.fcd = randf_range(0.06, 0.45) * rate

			if randf() < 0.45:
				s.c = MC[randi() % MC.size()]

			if randf() < 0.12:
				s.a = 1.0
				s.col = Color.WHITE
			else:
				s.col = e.base_c if not e.part_c.has(s.pi) else e.part_c[s.pi]
				s.a = randf_range(0.35, 0.85)

		var dist_scan: float = abs(float(s.p.y) - scan_y)
		if dist_scan < 10.0:
			s.a = min(1.0, float(s.a) + (1.0 - dist_scan / 10.0) * 0.35)

# ---------------------------------------------------------------------------
#  SLIME FLOOR DROPLETS (Spuren am Boden)
# ---------------------------------------------------------------------------
func _spawn_slime_landing_puddle(base_pos: Vector2) -> void:
	var puddle_center := base_pos + Vector2(0, 34)
	var puddle_chars: Array[String] = ["~", "≈", "=", "░", "▒", "o", "0", "•", "%"]
	var puddle_colors: Array[Color] = [
		Color("#76ff03"), Color("#64dd17"), Color("#b2ff59"), Color("#aeea00"), Color("#33691e")
	]

	var core_count: int = randi_range(6, 9)
	for i in range(core_count):
		var offset_x: float = randf_range(-18.0, 18.0)
		var offset_y: float = randf_range(-3.0, 3.5)
		slime_droplets.append({
			"p": puddle_center + Vector2(offset_x, offset_y),
			"c": puddle_chars[randi() % puddle_chars.size()],
			"col": puddle_colors[randi() % puddle_colors.size()],
			"size": randi_range(7, 10),
			"a": randf_range(0.85, 1.0),
			"life": randf_range(2.8, 3.5),
			"max_life": 3.5,
			"is_splash": false,
		})

	var splash_count: int = randi_range(2, 4)
	for i in range(splash_count):
		var side: float = -1.0 if randf() < 0.5 else 1.0
		var splash_x: float = side * randf_range(18.0, 28.0)
		var splash_y: float = randf_range(-2.0, 3.0)
		slime_droplets.append({
			"p": puddle_center + Vector2(splash_x, splash_y),
			"c": ["•", ".", "o", "*"][randi() % 4],
			"col": Color("#76ff03"),
			"size": 6,
			"a": randf_range(0.7, 0.9),
			"life": randf_range(2.0, 2.8),
			"max_life": 2.8,
			"is_splash": true,
		})


func _spawn_slime_droplet(pos: Vector2) -> void:
	var chars: Array[String] = ["~", ".", "o", "1", "0"]
	slime_droplets.append({
		"p": pos + Vector2(randf_range(-3, 3), randf_range(-1, 2)),
		"c": chars[randi() % chars.size()],
		"col": Color("#64dd17"),
		"size": 7,
		"a": randf_range(0.65, 0.85),
		"life": randf_range(1.6, 2.4),
		"max_life": 2.4,
		"is_splash": true,
	})


func _update_slime_droplets(delta: float) -> void:
	var i: int = slime_droplets.size() - 1
	while i >= 0:
		var d = slime_droplets[i]
		d.life -= delta
		var progress: float = clamp(d.life / d.max_life, 0.0, 1.0)
		d.a = progress * progress * 0.95
		if d.life <= 0.0:
			slime_droplets.remove_at(i)
		i -= 1


func _draw_slime_droplets() -> void:
	for d in slime_droplets:
		if d.a <= 0.01:
			continue
		var alpha: float = float(d.a)
		var c := Color(d.col, alpha)
		var glow_rad: float = 4.5 if not d.get("is_splash", false) else 2.5
		draw_circle(d.p + Vector2(2, -2), glow_rad, Color(0.4, 0.95, 0.05, alpha * 0.22))
		draw_circle(d.p + Vector2(2, -2), glow_rad * 0.5, Color(0.7, 1.0, 0.2, alpha * 0.35))
		draw_char(font, d.p + Vector2(-1, 1), d.c, d.get("size", 7), Color(0, 0, 0, alpha * 0.85))
		draw_char(font, d.p, d.c, d.get("size", 7), c)

# ---------------------------------------------------------------------------
#  BLINKING SYSTEM
# ---------------------------------------------------------------------------
func _update_blinking(e: Dictionary, delta: float) -> void:
	if not e.has("eyes") or e.eyes.is_empty():
		return
	var ey: Dictionary = e.eyes
	if ey.is_blinking:
		ey.blink_progress += delta * 12.0
		if ey.blink_progress >= 1.0:
			ey.is_blinking = false
			ey.blink_progress = 0.0
			ey.blink_timer = randf_range(2.5, 5.0)
	else:
		ey.blink_timer -= delta
		if ey.blink_timer <= 0.0:
			ey.is_blinking = true
			ey.blink_progress = 0.0

# ---------------------------------------------------------------------------
#  KNIGHT COMBAT & SKELETON
# ---------------------------------------------------------------------------
func _trigger_knight_strike(target_pos: Vector2 = Vector2.ZERO) -> void:
	if knight_atk_state != KnightAttackState.IDLE:
		return
	knight_atk_state = KnightAttackState.WINDUP
	knight_atk_timer = 0.0
	if target_pos != Vector2.ZERO:
		knight_target_enemy_pos = target_pos
		knight_is_dashing = true
	else:
		knight_is_dashing = false


func _update_knight_sword_animation(delta: float) -> void:
	if not knight_ref.has("alive") or not knight_ref.alive:
		return

	knight_atk_timer += delta

	match knight_atk_state:
		KnightAttackState.IDLE:
			var idle_breath: float = sin(_t * 2.2) * 0.04
			knight_arm_angle_upper = 0.35 + idle_breath
			knight_arm_angle_lower = -0.55 - idle_breath * 0.5
			knight_sword_angle = -0.35 + idle_breath * 0.4
			knight_current_pos = knight_current_pos.lerp(knight_orig_pos, delta * 8.0)

		KnightAttackState.WINDUP:
			var p: float = clamp(knight_atk_timer / 0.14, 0.0, 1.0)
			knight_arm_angle_upper = lerp(0.35, -2.4, p)
			knight_arm_angle_lower = lerp(-0.55, -0.6, p)
			knight_sword_angle = lerp(-0.35, -2.8, p)

			if knight_atk_timer >= 0.14:
				knight_atk_state = KnightAttackState.SLASH
				knight_atk_timer = 0.0
				_on_slash_trigger()

		KnightAttackState.SLASH:
			var p: float = clamp(knight_atk_timer / 0.10, 0.0, 1.0)
			var ep: float = ease(p, -2.5)
			knight_arm_angle_upper = lerp(-2.4, 0.8, ep)
			knight_arm_angle_lower = lerp(-0.6, 1.2, ep)
			knight_sword_angle = lerp(-2.8, 1.3, ep)

			if knight_is_dashing:
				knight_current_pos = knight_current_pos.lerp(knight_target_enemy_pos + Vector2(-45, 0), delta * 20.0)

			_emit_sword_trail_particles(true)

			if knight_atk_timer >= 0.10:
				knight_atk_state = KnightAttackState.RECOVER
				knight_atk_timer = 0.0

		KnightAttackState.RECOVER:
			var p: float = clamp(knight_atk_timer / 0.22, 0.0, 1.0)
			var ep: float = ease(p, 0.5)
			knight_arm_angle_upper = lerp(0.8, 0.35, ep)
			knight_arm_angle_lower = lerp(1.2, -0.55, ep)
			knight_sword_angle = lerp(1.3, -0.35, ep)
			knight_current_pos = knight_current_pos.lerp(knight_orig_pos, delta * 12.0)

			if knight_atk_timer >= 0.22:
				knight_atk_state = KnightAttackState.IDLE
				knight_atk_timer = 0.0
				knight_is_dashing = false

	if knight_atk_state != KnightAttackState.SLASH and randf() < 0.35:
		_emit_sword_trail_particles(false)

	if knight_ref.has("pos"):
		knight_ref.pos = knight_current_pos


func _on_slash_trigger() -> void:
	var hand := _get_knight_hand_pos()
	var glyph_count: int = 16
	var center: Vector2 = hand + Vector2(20, -5)
	var radius: float = 48.0

	var arc_glyphs: Array = []
	for i in range(glyph_count):
		var frac: float = float(i) / float(glyph_count - 1)
		var angle: float = lerp(-PI * 0.75, PI * 0.45, frac)
		var pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius
		arc_glyphs.append({
			"p": pos,
			"c": MC[randi() % MC.size()],
			"col": Color.WHITE if randf() > 0.3 else Color("#00ffff"),
			"a": 1.0,
			"vel": Vector2(cos(angle), sin(angle)) * randf_range(40.0, 120.0),
		})

	slash_glyph_arcs.append({
		"glyphs": arc_glyphs,
		"life": 0.24,
		"max_life": 0.24,
	})


func _get_knight_shoulder_pos() -> Vector2:
	var bob_y: float = sin(float(knight_ref.t) * 2.2) * 3.0 if knight_ref.has("t") else 0.0
	return knight_current_pos + Vector2(2, -12 + bob_y)


func _get_knight_elbow_pos() -> Vector2:
	var shoulder := _get_knight_shoulder_pos()
	var upper_len: float = 16.0
	return shoulder + Vector2(cos(knight_arm_angle_upper), sin(knight_arm_angle_upper)) * upper_len


func _get_knight_hand_pos() -> Vector2:
	var elbow := _get_knight_elbow_pos()
	var lower_len: float = 15.0
	var total_angle: float = knight_arm_angle_upper + knight_arm_angle_lower
	return elbow + Vector2(cos(total_angle), sin(total_angle)) * lower_len


func _get_knight_sword_tip() -> Vector2:
	var hand := _get_knight_hand_pos()
	var blade_len: float = 48.0
	return hand + Vector2(cos(knight_sword_angle), sin(knight_sword_angle)) * blade_len

# ---------------------------------------------------------------------------
#  ASCII SWORD TRAIL
# ---------------------------------------------------------------------------
func _emit_sword_trail_particles(is_slash: bool) -> void:
	var hand := _get_knight_hand_pos()
	var tip := _get_knight_sword_tip()
	var blade_vec := tip - hand
	var blade_len := blade_vec.length()
	var blade_dir := blade_vec.normalized()

	var count: int = 8 if is_slash else 2
	for i in range(count):
		var t_pos: float = randf_range(0.2, 1.0)
		var p: Vector2 = hand + blade_dir * (blade_len * t_pos)
		var drift: Vector2 = Vector2(randf_range(-15, 15), randf_range(-15, 15))
		if is_slash:
			drift += Vector2(-blade_dir.y, blade_dir.x) * randf_range(-35.0, -10.0)

		sword_trail_chars.append({
			"p": p,
			"c": MC[randi() % MC.size()],
			"col": Color.WHITE if randf() > 0.4 else Color("#00ffff"),
			"a": 0.95 if is_slash else 0.45,
			"decay": 4.5 if is_slash else 6.0,
			"v": drift,
			"size": 8 if randf() > 0.3 else 7,
		})


func _update_sword_trail_chars(delta: float) -> void:
	var i: int = sword_trail_chars.size() - 1
	while i >= 0:
		sword_trail_chars[i].a -= delta * float(sword_trail_chars[i].decay)
		sword_trail_chars[i].p += Vector2(sword_trail_chars[i].v) * delta
		sword_trail_chars[i].v = Vector2(sword_trail_chars[i].v) * 0.92

		if randf() < 0.1:
			sword_trail_chars[i].c = "0" if randf() > 0.5 else "1"

		if sword_trail_chars[i].a <= 0.01:
			sword_trail_chars.remove_at(i)
		i -= 1

	if sword_trail_chars.size() > 80:
		sword_trail_chars.resize(80)


func _draw_sword_trail_chars() -> void:
	for tc in sword_trail_chars:
		var c := Color(tc.col, tc.a)
		draw_char(font, tc.p, tc.c, tc.size, c)

# ---------------------------------------------------------------------------
#  SLASH GLYPH ARCS
# ---------------------------------------------------------------------------
func _update_slash_glyph_arcs(delta: float) -> void:
	var i: int = slash_glyph_arcs.size() - 1
	while i >= 0:
		slash_glyph_arcs[i].life -= delta
		var p: float = max(0.0, float(slash_glyph_arcs[i].life) / float(slash_glyph_arcs[i].max_life))
		for g in slash_glyph_arcs[i].glyphs:
			g.a = p
			g.p += Vector2(g.vel) * delta
			if randf() < 0.15:
				g.c = MC[randi() % MC.size()]

		if slash_glyph_arcs[i].life <= 0.0:
			slash_glyph_arcs.remove_at(i)
		i -= 1


func _draw_slash_glyph_arcs() -> void:
	for arc in slash_glyph_arcs:
		for g in arc.glyphs:
			var col := Color(g.col, g.a)
			draw_char(font, Vector2(g.p) + Vector2(-1, 1), g.c, 9, Color(0.2, 0.9, 1.0, float(g.a) * 0.35))
			draw_char(font, g.p, g.c, 8, col)

# ---------------------------------------------------------------------------
#  DRAW PURE ASCII ARM & WHITE ENERGY SWORD
# ---------------------------------------------------------------------------
func _draw_ascii_arm_and_sword() -> void:
	var shoulder := _get_knight_shoulder_pos()
	var elbow := _get_knight_elbow_pos()
	var hand := _get_knight_hand_pos()
	var tip := _get_knight_sword_tip()

	var blade_vec := tip - hand
	var blade_len := blade_vec.length()
	var blade_dir := blade_vec.normalized()
	var blade_norm := Vector2(-blade_dir.y, blade_dir.x)

	var upper_syms: Array[String] = ["1", "0", "+", "7"]
	for i in range(upper_syms.size()):
		var t_pos: float = (float(i) + 0.5) / float(upper_syms.size())
		var p: Vector2 = shoulder.lerp(elbow, t_pos) + Vector2(randf_range(-0.8, 0.8), randf_range(-0.8, 0.8))
		draw_char(font, p, upper_syms[i], 7, Color("#29b6f6"))

	draw_char(font, elbow + Vector2(-2, 2), "X", 8, Color.WHITE)

	var lower_syms: Array[String] = ["0", "1", "=", "-"]
	for i in range(lower_syms.size()):
		var t_pos: float = (float(i) + 0.5) / float(lower_syms.size())
		var p: Vector2 = elbow.lerp(hand, t_pos) + Vector2(randf_range(-0.8, 0.8), randf_range(-0.8, 0.8))
		draw_char(font, p, lower_syms[i], 7, Color("#4fc3f7"))

	draw_char(font, hand + Vector2(-2, 2), "#", 8, Color("#ffd600"))

	for s in sword_slots:
		var p: Vector2 = Vector2.ZERO
		if s.type == "blade":
			p = hand + blade_dir * (blade_len * float(s.t_pos)) + Vector2(s.jitter)
		elif s.type == "guard":
			p = hand + blade_dir * (blade_len * float(s.t_pos)) + blade_norm * float(s.offset_side) + Vector2(s.jitter)
		elif s.type == "pommel":
			p = hand + blade_dir * (blade_len * float(s.t_pos)) + Vector2(s.jitter)

		draw_char(font, p + Vector2(-1, 1), s.c, 9, Color(0.2, 0.85, 1.0, float(s.a) * 0.35))
		draw_char(font, p + Vector2(1, -1), s.c, 9, Color(0.2, 0.85, 1.0, float(s.a) * 0.35))

		var core_col: Color = Color.WHITE
		if s.type == "guard" or s.type == "pommel":
			core_col = Color("#ffd600")
		draw_char(font, p, s.c, 8, Color(core_col, s.a))

	var tip_char: String = "!" if randf() > 0.5 else "7"
	draw_char(font, tip + Vector2(-2, 2), tip_char, 9, Color.WHITE)

# ---------------------------------------------------------------------------
#  SPLATTER DEATH
# ---------------------------------------------------------------------------
func _start_splatter(e: Dictionary) -> void:
	e.splatting = true
	e.splat_t = 0.0
	var ctr := _centroid(e)

	for s in e.slots:
		var dir: Vector2 = Vector2(s.p) - ctr
		if dir.length() < 0.1:
			dir = Vector2(randf_range(-1, 1), randf_range(-1, 1))
		dir = dir.normalized()

		var spd: float = randf_range(90.0, 280.0)
		if s.eq:
			spd *= 1.6
			s.col = e.eq_c

		var roll: float = randf()
		if roll < 0.25:
			s.v = Vector2(dir.x * spd * 1.6, randf_range(-120.0, -30.0))
		elif roll < 0.45:
			s.v = Vector2(randf_range(-25.0, 25.0), randf_range(20.0, 60.0))
			s.g = randf_range(250.0, 550.0)
		else:
			s.v = dir * spd + Vector2(0, randf_range(-90.0, -20.0))

		if s.g == 0.0:
			s.g = randf_range(120.0, 350.0)
		s.rs = randf_range(-10.0, 10.0)


func _tick_splatter(e: Dictionary, delta: float) -> void:
	e.splat_t += delta
	var any_visible: bool = false

	for s in e.slots:
		s.v.y += float(s.g) * delta
		s.p += Vector2(s.v) * delta
		s.r += float(s.rs) * delta
		s.a -= delta * 0.65
		s.a = max(0.0, float(s.a))

		if s.a > 0.01:
			any_visible = true
			if randf() < 0.12:
				s.c = MC[randi() % MC.size()]

	if e.splat_t > 2.5 or not any_visible:
		e.alive = false

# ---------------------------------------------------------------------------
#  DRAWING ENTITIES
# ---------------------------------------------------------------------------
func _draw_entity(e: Dictionary) -> void:
	var pos: Vector2 = e.pos + Vector2(e.offset_mod)
	var scale_m: Vector2 = Vector2(e.scale_mod)
	var rot_m: float = float(e.rot_mod)

	# ─── 1. Polygon underlay silhouette (0.05 alpha) ───
	if not e.splatting:
		for pi in range(e.polys.size()):
			var poly: PackedVector2Array = e.polys[pi]
			var wp := PackedVector2Array()
			for pt in poly:
				var transformed_pt := (pt * scale_m).rotated(rot_m) + pos
				wp.append(transformed_pt)
			var fill_col: Color = e.base_c
			if e.part_c.has(pi):
				fill_col = e.part_c[pi]
			draw_colored_polygon(wp, Color(fill_col, 0.05))

	# ─── 2. Loosely Scattered Body Characters (Full Density!) ───
	for s in e.slots:
		if s.eq:
			continue
		if s.a < 0.01:
			continue

		var cp: Vector2
		if e.splatting:
			cp = Vector2(s.p) + e.pos
		else:
			var base_local: Vector2 = Vector2(s.p) * scale_m
			base_local = base_local.rotated(rot_m)
			cp = base_local + pos
			cp += Vector2(
				sin(_t * 1.6 + float(s.ph)) * 1.6,
				cos(_t * 1.3 + float(s.ph) * 0.7) * 1.2)
			if s.pi == 5 and e.part_c.has(5):
				cp.x += sin(_t * 2.0 + float(s.p.y) * 0.12) * 3.5

		var draw_col := Color(s.col, s.a)
		draw_char(font, cp, s.c, BFS, draw_col)

	# ─── 3. EQUATION RENDERING (High Contrast Foreground, Solid Token Block) ───
	var eq_alpha_pulse: float = 0.92 + sin(_t * 3.5) * 0.08
	var is_slime: bool = (e.anim_type == "slime")

	for s in e.slots:
		if not s.eq:
			continue
		if s.a < 0.01:
			continue

		var cp: Vector2
		if e.splatting:
			cp = Vector2(s.p) + e.pos
		else:
			var base_local: Vector2 = Vector2(s.p) * scale_m
			base_local = base_local.rotated(rot_m)
			cp = base_local + pos + Vector2(0, sin(_t * 2.8) * 1.0)

		var eq_col: Color = e.eq_c
		var draw_col := Color(eq_col, eq_alpha_pulse)

		# Ground floor aura plate for slime calculation
		if is_slime and not e.splatting:
			draw_circle(cp + Vector2(4, -4), 14.0, Color(0.39, 0.86, 0.09, 0.06))

		# Drop shadow and glow halo
		draw_char(font, cp + Vector2(-1.2, 1.2), s.c, EFS + 2, Color(0, 0, 0, 0.95))
		draw_char(font, cp, s.c, EFS + 2, Color(eq_col.r, eq_col.g, eq_col.b, 0.4))
		draw_char(font, cp, s.c, EFS, draw_col)

	# ─── 4. FIXED GLOWING EYES WITH BLINKING ───
	if not e.splatting and e.has("eyes") and not e.eyes.is_empty():
		_draw_entity_eyes(e, pos, scale_m, rot_m)

	# ─── 5. Entity label ───
	if not e.splatting:
		var label_y: float = 999.0
		for poly in e.polys:
			for pt in poly:
				if pt.y < label_y:
					label_y = pt.y
		var lp: Vector2 = pos + Vector2(-18, label_y * scale_m.y - 10)
		draw_string(font, lp, e.name, HORIZONTAL_ALIGNMENT_LEFT, 80, 6, Color(e.glow_c, 0.7))

	# ─── 6. Hover glow ───
	if e.hover and not e.splatting:
		var ctr: Vector2 = (_centroid(e) * scale_m).rotated(rot_m) + pos
		draw_circle(ctr, 38.0, Color(e.glow_c, 0.06))


func _draw_entity_eyes(e: Dictionary, entity_anchor: Vector2, scale_m: Vector2, rot_m: float) -> void:
	var ey: Dictionary = e.eyes
	var eye_col: Color = ey.color
	var sz: float = ey.size
	var is_blink: bool = ey.is_blinking
	var bp: float = ey.blink_progress

	var v_scale: float = 1.0
	if is_blink:
		v_scale = abs(cos(bp * PI))
		v_scale = max(0.08, v_scale)

	for ep in ey.positions:
		var local_p: Vector2 = (Vector2(ep) * scale_m).rotated(rot_m)
		var eye_world_pos: Vector2 = entity_anchor + local_p

		draw_circle(eye_world_pos, sz * 2.8, Color(eye_col.r, eye_col.g, eye_col.b, 0.22))
		draw_circle(eye_world_pos, sz * 1.6, Color(eye_col.r, eye_col.g, eye_col.b, 0.45))

		if v_scale < 0.35:
			draw_line(eye_world_pos + Vector2(-sz * 1.3, 0), eye_world_pos + Vector2(sz * 1.3, 0), Color.WHITE, 1.2)
		else:
			if ey.style == "visor_glow":
				var r := Rect2(eye_world_pos - Vector2(sz * 1.1, sz * 0.7 * v_scale), Vector2(sz * 2.2, sz * 1.4 * v_scale))
				draw_rect(r, eye_col)
				draw_rect(Rect2(eye_world_pos - Vector2(sz * 0.6, sz * 0.35 * v_scale), Vector2(sz * 1.2, sz * 0.7 * v_scale)), Color.WHITE)
			else:
				var pts := PackedVector2Array()
				var segs: int = 10
				for i in range(segs + 1):
					var ang: float = (float(i) / float(segs)) * TAU
					pts.append(eye_world_pos + Vector2(cos(ang) * sz, sin(ang) * sz * v_scale))
				draw_colored_polygon(pts, eye_col)
				draw_circle(eye_world_pos + Vector2(sz * 0.2, -sz * 0.2 * v_scale), sz * 0.4 * v_scale, Color.WHITE)


func _draw_ui() -> void:
	draw_string(font, Vector2(16, 18), "MATH KNIGHT — PURE ASCII CYBER PROTOTYPE", HORIZONTAL_ALIGNMENT_LEFT,
		-1, 9, Color("#f7c52a"))
	draw_string(font, Vector2(16, 30), "Full Density • Slime Floor Math & Trail • Custom Enemy Motions • Zuschlagen!",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(0.6, 0.6, 0.7, 0.7))

	if _info_alpha > 0.01:
		var ic := Color(0.7, 0.85, 1.0, _info_alpha * 0.85)
		draw_string(font, Vector2(VP.x * 0.5 - 145, VP.y - 14),
			"SPACE / Click Knight = STRIKE (Zuschlagen)  |  Click Enemy = Slash & Splatter  |  R = Respawn",
			HORIZONTAL_ALIGNMENT_LEFT, 450, 5, ic)

	var dead: int = 0
	for e in entities:
		if not e.alive:
			dead += 1
	if dead > 0:
		var all_dead: bool = true
		for e in entities:
			if e.alive and e.name != "RITTER":
				all_dead = false
				break
		if all_dead:
			var pulse: float = 0.6 + sin(_t * 4.0) * 0.4
			draw_string(font, Vector2(VP.x * 0.5 - 70, VP.y * 0.5),
				"ALLE GEGNER BESIEGT!",
				HORIZONTAL_ALIGNMENT_LEFT, 200, 8, Color(1.0, 0.85, 0.2, pulse))
			draw_string(font, Vector2(VP.x * 0.5 - 45, VP.y * 0.5 + 14),
				"Druecke R fuer Respawn",
				HORIZONTAL_ALIGNMENT_LEFT, 150, 6, Color(0.7, 0.8, 1.0, pulse * 0.7))

# ---------------------------------------------------------------------------
#  INPUT HANDLING
# ---------------------------------------------------------------------------
func _handle_click(mpos: Vector2) -> void:
	if knight_ref.has("alive") and knight_ref.alive:
		if _point_in_entity(knight_ref, mpos):
			_trigger_knight_strike()
			return

	for i in range(entities.size() - 1, 0, -1):
		var e: Dictionary = entities[i]
		if not e.alive or e.splatting:
			continue
		if _point_in_entity(e, mpos):
			_trigger_knight_strike(e.pos)
			_start_splatter(e)
			return

	_trigger_knight_strike()


func _handle_hover(mpos: Vector2) -> void:
	for e in entities:
		if not e.alive or e.splatting:
			e.hover = false
			continue
		e.hover = _point_in_entity(e, mpos)


func _point_in_entity(e: Dictionary, mpos: Vector2) -> bool:
	var local: Vector2 = mpos - Vector2(e.pos)
	for poly in e.polys:
		if Geometry2D.is_point_in_polygon(local, poly):
			return true
	var ctr: Vector2 = _centroid(e)
	return local.distance_to(ctr) < 35.0

# ---------------------------------------------------------------------------
#  UTILITY
# ---------------------------------------------------------------------------
func _poly_rect(poly: PackedVector2Array) -> Rect2:
	if poly.is_empty():
		return Rect2()
	var mn: Vector2 = poly[0]
	var mx: Vector2 = poly[0]
	for p in poly:
		mn.x = min(mn.x, p.x)
		mn.y = min(mn.y, p.y)
		mx.x = max(mx.x, p.x)
		mx.y = max(mx.y, p.y)
	return Rect2(mn, mx - mn)


func _centroid(e: Dictionary) -> Vector2:
	var s := Vector2.ZERO
	var n: int = 0
	for poly in e.polys:
		for p in poly:
			s += p
			n += 1
	return s / float(max(n, 1))
