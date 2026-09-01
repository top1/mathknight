class_name AsciiEntity
extends Node2D
## ═══════════════════════════════════════════════════════════════════════════
## AsciiEntity — Universal Modular Cyber-ASCII Character Renderer for Math Knight
##
## Features:
##   • 100% Pure ASCII numbers & math symbols for all entities
##   • Customizable Weapons: Flame, Frost, Gold, Plasma Lightsaber, Pan, Iron
##   • Custom Headwear: Viking Horns, Royal Crown, Wizard Hat, Jester Cap,
##     Propeller Beanie, Deal-With-It Sunglasses
##   • Special Victory Animations: Confetti Rain, Royal Fireworks, Thunder Bolt
##   • Fixed glowing eyes with procedural blinking
##   • Slime hopping with floor trail + ground equation
##   • Splatter death physics
## ═══════════════════════════════════════════════════════════════════════════

signal splatter_finished

# ---------------------------------------------------------------------------
#  CONSTANTS
# ---------------------------------------------------------------------------
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
#  EXPORTS & CONFIG
# ---------------------------------------------------------------------------
@export_enum("knight", "goblin", "skeleton", "slime", "boss") var entity_type: String = "knight":
	set(val):
		entity_type = val
		if is_inside_tree():
			_build_entity()

@export var facing_direction: float = 1.0 # 1.0 = Facing Right, -1.0 = Facing Left
@export var rotation_yaw: float = 0.0 # Free 3D turntable yaw in radians (0 to TAU)
@export var rotation_pitch: float = 0.0 # 3D tilt pitch in radians (-0.4 to 0.4)
@export var equation_text: String = "":
	set(val):
		equation_text = val
		if is_inside_tree():
			_rebuild_equation()

@export var is_hovered: bool = false
@export var is_elite: bool = false:
	set(val):
		is_elite = val
		if is_inside_tree():
			_apply_elite_style()

# Cosmetic Equipment
@export var equipped_sword: String = "sword_iron":
	set(val):
		equipped_sword = val
		if is_inside_tree():
			_update_cosmetic_styles()

@export var equipped_helmet: String = "helm_knight":
	set(val):
		equipped_helmet = val
		if is_inside_tree():
			_update_cosmetic_styles()

@export var equipped_hat: String = "hat_none":
	set(val):
		equipped_hat = val
		if is_inside_tree():
			_update_cosmetic_styles()

@export var equipped_anim: String = "anim_confetti"

# ---------------------------------------------------------------------------
#  STATE
# ---------------------------------------------------------------------------
var font: Font
var polys: Array = []
var slots: Array = []
var base_color: Color = Color("#29b6f6")
var glow_color: Color = Color("#4fc3f7")
var eq_color: Color = Color("#ffd600")
var part_colors: Dictionary = {}

var eyes: Dictionary = {}
var eq_center: Vector2 = Vector2.ZERO
var scale_mod: Vector2 = Vector2.ONE
var offset_mod: Vector2 = Vector2.ZERO
var rot_mod: float = 0.0

var _t: float = 0.0
var _anim_state: String = "idle"
var _slime_hop_t: float = 0.0
var _was_slime_airborne: bool = false
var _propeller_rot: float = 0.0
var _is_splatting: bool = false
var _splat_t: float = 0.0

# Slime Floor Droplets
var slime_droplets: Array = []

# Special Victory Effects & Particles
var victory_particles: Array = []
var lightning_bolts: Array = []

# Knight Pure ASCII Sword State
var has_sword: bool = false
var sword_slots: Array = []
var sword_trail_chars: Array = []
var slash_glyph_arcs: Array = []

# Character Ghost Shadow / Afterimage & Elemental Particles
var character_ghosts: Array = []
var elemental_particles: Array = []
var _last_sword_tip: Vector2 = Vector2.ZERO
var _last_hand_pos: Vector2 = Vector2.ZERO
var _last_body_offset: Vector2 = Vector2.ZERO

# Sword Theme Colors
var sword_core_color: Color = Color.WHITE
var sword_aura_color: Color = Color(0.2, 0.85, 1.0)
var sword_guard_color: Color = Color("#ffd600")
var sword_trail_color: Color = Color("#00ffff")

enum AttackState { IDLE, WINDUP, SLASH, RECOVER, SPECIAL }
var _atk_state: AttackState = AttackState.IDLE
var _atk_timer: float = 0.0
var _arm_angle_upper: float = -0.9
var _arm_angle_lower: float = 0.4
var _sword_angle: float = -1.2
var _special_anim_name: String = ""

# ---------------------------------------------------------------------------
#  LIFECYCLE
# ---------------------------------------------------------------------------
func _ready() -> void:
	font = load("res://assets/fonts/Silkscreen-Bold.ttf")
	if not font:
		font = ThemeDB.fallback_font
	_build_entity()
	_load_saved_cosmetics()


func _process(delta: float) -> void:
	_t += delta
	_propeller_rot += delta * 18.0
	_update_blinking(delta)
	_update_slime_droplets(delta)
	_update_victory_particles(delta)
	_update_lightning_bolts(delta)
	_update_character_ghosts(delta)
	_update_elemental_particles(delta)

	if has_sword:
		_update_sword_animation(delta)
		_update_sword_slots(delta)
		_update_sword_trail(delta)
		_update_slash_arcs(delta)

	if _is_splatting:
		_tick_splatter(delta)
	else:
		_tick_animation(delta)

	queue_redraw()


func _draw() -> void:
	# 1. Slime floor droplets (underneath entity)
	if entity_type == "slime" or not slime_droplets.is_empty():
		_draw_slime_droplets()

	# 2. Character Ghost Echo Shadows ("Verblassender Schatten der Zeichen")
	_draw_character_ghosts()

	# 3. Elemental smoke/vapor particles underneath entity
	_draw_elemental_particles(false)

	# 4. Pure ASCII sword trail (underneath entity)
	if has_sword:
		_draw_sword_trail()

	# 5. Entity Body (Polygons + Scattered Characters + Equation + Eyes)
	_draw_entity_body()

	# 6. Headwear Cosmetics (Viking Horns, Royal Crown, Wizard Hat, Propeller, Shades)
	if entity_type == "knight" and not _is_splatting:
		_draw_headwear()

	# 7. Pure ASCII Arm & Sword (on top)
	if has_sword and not _is_splatting:
		_draw_ascii_arm_and_sword()

	# 8. Elemental embers/sparks on top of blade
	_draw_elemental_particles(true)

	# 9. Slash Arc Effects & Victory Special FX
	if has_sword:
		_draw_slash_arcs()
	_draw_victory_effects()

# ---------------------------------------------------------------------------
#  COSMETIC SYSTEM INTEGRATION
# ---------------------------------------------------------------------------
func _load_saved_cosmetics() -> void:
	if entity_type != "knight":
		return
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		var eq = sm.equipped_cosmetics
		apply_cosmetics(eq)


func apply_cosmetics(eq: Dictionary) -> void:
	if eq.has("sword"):
		equipped_sword = eq["sword"]
	if eq.has("helmet"):
		equipped_helmet = eq["helmet"]
	if eq.has("hat"):
		equipped_hat = eq["hat"]
	if eq.has("victory_anim"):
		equipped_anim = eq["victory_anim"]
	_update_cosmetic_styles()


func _update_cosmetic_styles() -> void:
	if entity_type != "knight":
		return

	# Configure Sword Styles
	match equipped_sword:
		"sword_flame":
			sword_core_color = Color(1.0, 0.9, 0.3)
			sword_aura_color = Color(1.0, 0.35, 0.05)
			sword_guard_color = Color(1.0, 0.2, 0.0)
			sword_trail_color = Color(1.0, 0.45, 0.1)

		"sword_frost":
			sword_core_color = Color(0.9, 1.0, 1.0)
			sword_aura_color = Color(0.1, 0.75, 1.0)
			sword_guard_color = Color(0.4, 0.9, 1.0)
			sword_trail_color = Color(0.3, 0.85, 1.0)

		"sword_gold":
			sword_core_color = Color("#ffe066") # Clear bright noble gold
			sword_aura_color = Color("#ffca28") # Sharp gold accent
			sword_guard_color = Color("#ffa000") # Burnished gold
			sword_trail_color = Color("#ffd54f")

		"sword_lightsaber":
			sword_core_color = Color.WHITE
			sword_aura_color = Color(0.0, 1.0, 0.8) # Vibrant pure neon plasma
			sword_guard_color = Color(0.2, 0.2, 0.3)
			sword_trail_color = Color(0.0, 1.0, 0.85)

		"sword_pan":
			sword_core_color = Color(0.75, 0.75, 0.8)
			sword_aura_color = Color(0.4, 0.4, 0.5)
			sword_guard_color = Color(0.3, 0.3, 0.35)
			sword_trail_color = Color(0.8, 0.8, 0.9)

		_: # sword_iron
			sword_core_color = Color.WHITE
			sword_aura_color = Color(0.2, 0.85, 1.0)
			sword_guard_color = Color("#ffd600")
			sword_trail_color = Color("#00ffff")

# ---------------------------------------------------------------------------
#  ENTITY BUILDER
# ---------------------------------------------------------------------------
func _build_entity() -> void:
	slots.clear()
	sword_slots.clear()
	sword_trail_chars.clear()
	slash_glyph_arcs.clear()
	slime_droplets.clear()
	part_colors.clear()
	_is_splatting = false
	_splat_t = 0.0
	_t = randf() * TAU
	_slime_hop_t = randf() * 2.0
	_was_slime_airborne = false

	match entity_type:
		"knight":
			polys = _knight_polys()
			base_color = Color("#29b6f6")
			glow_color = Color("#4fc3f7")
			eq_color = Color("#ffd600")
			part_colors = {
				0: Color("#80deea"), # Titanium / Cyan-Silver Head
				1: Color("#29b6f6"), # Steel Chestplate & Shoulders
				2: Color("#1e88e5"), # Left Leg Greave
				3: Color("#1e88e5"), # Right Leg Greave
				4: Color("#5c6bc0"), # Shoulder/Arm
				5: Color("#9c27b0")  # Royal Purple Cape
			}
			has_sword = true
			eyes = {
				"positions": [Vector2(-3.5, -48.0), Vector2(2.5, -48.0)],
				"color": Color("#00ffff"),
				"size": 1.5,
				"style": "visor_glow",
				"blink_timer": randf_range(2.5, 4.0),
				"blink_progress": 0.0,
				"is_blinking": false,
			}
			_init_sword_slots()
			_update_cosmetic_styles()

		"goblin":
			polys = _goblin_polys()
			base_color = Color("#43a047")
			glow_color = Color("#66bb6a")
			eq_color = Color("#ffd600")
			has_sword = false
			eyes = {
				"positions": [Vector2(-5.5, -12), Vector2(5.5, -12)],
				"color": Color("#ffb300"),
				"size": 2.5,
				"style": "round_glow",
				"blink_timer": randf_range(2.0, 3.8),
				"blink_progress": 0.0,
				"is_blinking": false,
			}

		"skeleton":
			polys = _skeleton_polys()
			base_color = Color("#7e57c2")
			glow_color = Color("#b39ddb")
			eq_color = Color("#ffeb3b")
			has_sword = false
			eyes = {
				"positions": [Vector2(-4.5, -37), Vector2(4.5, -37)],
				"color": Color("#00e5ff"),
				"size": 2.2,
				"style": "flame_glow",
				"blink_timer": randf_range(3.0, 5.0),
				"blink_progress": 0.0,
				"is_blinking": false,
			}

		"slime":
			polys = _slime_polys()
			base_color = Color("#64dd17")
			glow_color = Color("#b2ff59")
			eq_color = Color("#ffeb3b")
			has_sword = false
			eyes = {
				"positions": [Vector2(-7.0, 10), Vector2(7.0, 10)],
				"color": Color("#aeea00"),
				"size": 3.0,
				"style": "squish_glow",
				"blink_timer": randf_range(1.8, 3.2),
				"blink_progress": 0.0,
				"is_blinking": false,
			}

		"boss":
			polys = _boss_polys()
			base_color = Color("#c62828")
			glow_color = Color("#ef5350")
			eq_color = Color("#ffd600")
			has_sword = false
			eyes = {
				"positions": [Vector2(-7.0, -50), Vector2(7.0, -50)],
				"color": Color("#ff1744"),
				"size": 3.2,
				"style": "boss_glow",
				"blink_timer": randf_range(3.5, 5.5),
				"blink_progress": 0.0,
				"is_blinking": false,
			}

	if is_elite:
		_apply_elite_style()

	_fill_body_slots()


func _apply_elite_style() -> void:
	if is_elite:
		base_color = Color("#ab47bc")
		glow_color = Color("#e1bee7")
		eq_color = Color("#ffd600")


func set_equation(text: String, color: Color = Color("#ffd600")) -> void:
	equation_text = text
	eq_color = color
	_rebuild_equation()


func _rebuild_equation() -> void:
	var i: int = slots.size() - 1
	while i >= 0:
		if slots[i].eq:
			slots.remove_at(i)
		i -= 1
	_insert_equation_slots()

# ---------------------------------------------------------------------------
#  POLYGONS
# ---------------------------------------------------------------------------
func _knight_polys() -> Array:
	return [
		# 0. Heroic Knight Head & Hair (Crisp Oval/Jaw with Crown)
		PackedVector2Array([
			Vector2(-8, -58), Vector2(0, -60), Vector2(8, -58),
			Vector2(11, -48), Vector2(8, -42), Vector2(4, -36),
			Vector2(-4, -36), Vector2(-8, -42), Vector2(-11, -48)]),
		# 1. Torso & Neck & Breastplate (Distinct separation below neck)
		PackedVector2Array([
			Vector2(-4, -36), Vector2(4, -36), Vector2(18, -31),
			Vector2(16, 8), Vector2(-16, 8), Vector2(-18, -31)]),
		# 2. Left Leg
		PackedVector2Array([
			Vector2(-14, 8), Vector2(-3, 8),
			Vector2(-3, 36), Vector2(-14, 36)]),
		# 3. Right Leg
		PackedVector2Array([
			Vector2(3, 8), Vector2(14, 8),
			Vector2(14, 36), Vector2(3, 36)]),
		# 4. Left Arm / Shoulder
		PackedVector2Array([
			Vector2(-26, -28), Vector2(-18, -28),
			Vector2(-18, 4), Vector2(-26, 4)]),
		# 5. Cape / Umhang
		PackedVector2Array([
			Vector2(-16, -30), Vector2(-10, -30),
			Vector2(-6, 28), Vector2(-26, 22), Vector2(-28, -2)]),
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
#  SLOT FILLING
# ---------------------------------------------------------------------------
func _fill_body_slots() -> void:
	slots.clear()

	for pi in range(polys.size()):
		var poly: PackedVector2Array = polys[pi]
		var rect := _poly_rect(poly)
		
		# Structured grid for Knight Head
		var step_x: float = SP.x
		var step_y: float = SP.y
		if entity_type == "knight" and pi == 0:
			step_x = 3.4
			step_y = 3.6

		var y: float = rect.position.y
		while y < rect.end.y:
			var x: float = rect.position.x
			while x < rect.end.x:
				var p := Vector2(
					x + randf_range(-1.0, 1.0),
					y + randf_range(-1.0, 1.0))

				if Geometry2D.is_point_in_polygon(p, poly):
					var slot_color: Color = base_color
					if part_colors.has(pi):
						slot_color = part_colors[pi]

					var glyph_char: String = MC[randi() % MC.size()]
					var slot_alpha: float = randf_range(0.45, 0.95)
					var z_coord: float = 0.0

					if entity_type == "knight":
						if pi == 0:
							# Keep eye zone completely clear and open
							if p.y >= -51.0 and p.y <= -45.0 and abs(p.x) <= 5.5:
								x += step_x
								continue

							# Check if top crown or temple hair
							var is_hair_strand: bool = (p.y <= -50.0) or (abs(p.x) >= 7.0 and p.y <= -42.0)
							
							if is_hair_strand:
								# Golden Brown Hair Strands & Bangs on Crown
								var hair_glyphs: Array[String] = ["~", ")", "(", "S", "s", "3", "8", "/", "\\", "1"]
								glyph_char = hair_glyphs[randi() % hair_glyphs.size()]
								var hair_shades: Array[Color] = [
									Color("#5d4037"), # Chestnut
									Color("#795548"),
									Color("#a66d28"), # Golden Brown
									Color("#cb8e36"), # Warm Caramel
									Color("#dc9f40"), # Amber
									Color("#eab248"), # Golden
									Color("#f7c65c")  # Honey highlight
								]
								slot_color = hair_shades[randi() % hair_shades.size()]
								slot_alpha = randf_range(0.80, 1.0)
							else:
								# Structured Face & Jaw Glyphs
								var head_glyphs: Array[String] = ["0", "1", "8", "B", "M", "H", "X", "=", "+", "#", "O"]
								glyph_char = head_glyphs[randi() % head_glyphs.size()]
								var head_shades: Array[Color] = [
									Color("#e0f7fa"), # Light Titanium Cyan
									Color("#b2ebf2"),
									Color("#80deea"),
									Color("#4dd0e1"),
									Color("#26c6da"),
									Color("#00bcd4")
								]
								slot_color = head_shades[randi() % head_shades.size()]
								slot_alpha = randf_range(0.75, 1.0)
							
							# 3D Dome curvature for head
							var dist_from_center: float = clampf(abs(p.x) / 10.0, 0.0, 1.0)
							var dome_rad: float = sqrt(maxf(0.0, 1.0 - dist_from_center * dist_from_center)) * 6.5
							z_coord = dome_rad if randf() < 0.65 else -dome_rad

						elif pi == 5:
							# Royal Purple Cape with multi-tone depth
							var purple_shades: Array[Color] = [
								Color("#3b0b59"), Color("#4a148c"), Color("#6a1b9a"),
								Color("#7b1fa2"), Color("#8e24aa"), Color("#9c27b0"),
								Color("#ab47bc"), Color("#ba68c8"), Color("#ce93d8")
							]
							slot_color = purple_shades[randi() % purple_shades.size()]
							z_coord = -6.0
						elif pi == 1:
							# Steel Chestplate
							z_coord = 2.0

					slots.append({
						"p": p,
						"z": z_coord,
						"c": glyph_char,
						"col": slot_color,
						"base_col": slot_color,
						"a": slot_alpha,
						"ph": randf() * TAU,
						"fcd": randf_range(0.06, 0.45),
						"eq": false,
						"pi": pi,
						"v": Vector2.ZERO,
						"g": 0.0,
						"r": 0.0,
						"rs": 0.0,
					})
				x += step_x
			y += step_y

	_insert_equation_slots()


func _insert_equation_slots() -> void:
	if equation_text.is_empty():
		return

	var ctr := _centroid()
	var is_slime: bool = (entity_type == "slime")

	if is_slime:
		ctr = Vector2(0, 14)
	else:
		ctr.y += 2.0

	eq_center = ctr

	var eq: String = equation_text
	var char_positions: Array = []
	var total_w: float = 0.0

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
				total_w += 8.0
			else:
				total_w += 10.5
		i += 1

	var start_x: float = ctr.x - total_w * 0.5
	for cp in char_positions:
		if not cp.is_space:
			slots.append({
				"p": Vector2(start_x + float(cp.offset_x), ctr.y),
				"c": cp.c,
				"col": eq_color,
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
#  ANIMATION & MOVEMENT
# ---------------------------------------------------------------------------
func _tick_animation(delta: float) -> void:
	match entity_type:
		"slime":
			_slime_hop_t += delta * 2.8
			var hop_period: float = 1.25
			var cycle: float = fmod(_slime_hop_t, hop_period)
			var ground_time: float = 0.32

			if cycle < ground_time:
				# Grounded squash & launch anticipation
				var ground_p: float = cycle / ground_time
				# Impact squash right on landing, easing into spring coil
				var squash: float = sin(ground_p * PI)
				scale_mod = Vector2(1.0 + squash * 0.34, 1.0 - squash * 0.34)
				offset_mod = Vector2(0, squash * 2.5)

				if _was_slime_airborne:
					_was_slime_airborne = false
					_spawn_slime_landing_puddle()
			else:
				# High dynamic airborne leap!
				_was_slime_airborne = true
				var air_p: float = (cycle - ground_time) / (hop_period - ground_time)
				var hop_arc: float = sin(air_p * PI)
				var hop_y: float = hop_arc * 28.0 # Dynamic high jump (28px)
				offset_mod = Vector2(0, -hop_y)

				# Elastic vertical stretch during launch & descent
				var stretch_x: float = lerp(1.15, 0.74, hop_arc)
				var stretch_y: float = lerp(0.85, 1.34, hop_arc)
				scale_mod = Vector2(stretch_x, stretch_y)

		"goblin":
			var trot_y: float = abs(sin(_t * 6.5)) * 3.5
			var tilt_x: float = sin(_t * 6.5) * 2.0
			offset_mod = Vector2(tilt_x, -trot_y)
			rot_mod = sin(_t * 6.5) * 0.06
			scale_mod = Vector2(1.0 + sin(_t * 13.0) * 0.03, 1.0 - sin(_t * 13.0) * 0.03)

		"skeleton":
			var sway_x: float = sin(_t * 4.2) * 3.0
			var march_y: float = abs(cos(_t * 4.2)) * 3.2
			offset_mod = Vector2(sway_x, -march_y)
			rot_mod = sin(_t * 4.2) * 0.05
			scale_mod = Vector2.ONE

		"boss":
			var stomp_y: float = abs(sin(_t * 2.2)) * 2.0
			var pulse: float = 1.0 + sin(_t * 2.0) * 0.03
			offset_mod = Vector2(0, -stomp_y)
			scale_mod = Vector2(pulse, pulse)

		"knight":
			var breath_y: float = sin(_t * 2.2) * 2.5
			offset_mod = Vector2(0, breath_y)
			scale_mod = Vector2.ONE

	# Character scanline sweep
	var scan_y: float = sin(_t * 2.5) * 35.0
	for s in slots:
		if s.eq:
			continue

		s.fcd -= delta
		if s.fcd <= 0.0:
			var rate: float = 1.0 if not is_hovered else 0.4
			s.fcd = randf_range(0.06, 0.45) * rate

			if randf() < 0.45:
				s.c = MC[randi() % MC.size()]

			if randf() < 0.12:
				s.a = 1.0
				s.col = Color.WHITE
			else:
				var restore_col: Color = base_color
				if s.has("base_col"):
					restore_col = s.base_col
				elif part_colors.has(s.pi):
					restore_col = part_colors[s.pi]
				s.col = restore_col
				s.a = randf_range(0.45, 0.95)

		var dist_scan: float = abs(float(s.p.y) - scan_y)
		if dist_scan < 10.0:
			s.a = min(1.0, float(s.a) + (1.0 - dist_scan / 10.0) * 0.35)


func _update_blinking(delta: float) -> void:
	if eyes.is_empty():
		return
	if eyes.is_blinking:
		eyes.blink_progress += delta * 12.0
		if eyes.blink_progress >= 1.0:
			eyes.is_blinking = false
			eyes.blink_progress = 0.0
			eyes.blink_timer = randf_range(2.5, 5.0)
	else:
		eyes.blink_timer -= delta
		if eyes.blink_timer <= 0.0:
			eyes.is_blinking = true
			eyes.blink_progress = 0.0

# ---------------------------------------------------------------------------
#  KNIGHT PURE ASCII SWORD & ARM
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


func play_windup() -> void:
	_atk_state = AttackState.WINDUP
	_atk_timer = 0.0


func play_slash() -> void:
	_atk_state = AttackState.SLASH
	_atk_timer = 0.0
	_trigger_slash_burst()


func play_special_anim(anim_name: String) -> void:
	_special_anim_name = anim_name
	_atk_state = AttackState.SPECIAL
	_atk_timer = 0.0

	match anim_name:
		"anim_confetti":
			# Rain colorful math symbols
			for i in range(35):
				victory_particles.append({
					"p": Vector2(randf_range(-40, 40), -70),
					"v": Vector2(randf_range(-50, 50), randf_range(-80, -20)),
					"g": randf_range(160, 280),
					"c": MC[randi() % MC.size()],
					"col": [Color("#ff4081"), Color("#00e676"), Color("#ffd600"), Color("#00e5ff")][randi() % 4],
					"a": 1.0,
					"life": 1.8,
					"max_life": 1.8,
				})

		"anim_fireworks":
			# Rocket launch and explosion
			for i in range(3):
				var rocket_x = randf_range(-30, 30)
				get_tree().create_timer(float(i) * 0.18).timeout.connect(func():
					_spawn_firework_burst(Vector2(rocket_x, -90 + float(i) * 15))
				)

		"anim_thunder":
			# Cyan-white lightning strike from sky onto sword
			var strike_tip = _get_sword_tip()
			_spawn_lightning_strike(strike_tip)


func _spawn_firework_burst(pos: Vector2) -> void:
	for j in range(24):
		var ang = randf() * TAU
		var spd = randf_range(60.0, 160.0)
		victory_particles.append({
			"p": pos,
			"v": Vector2(cos(ang), sin(ang)) * spd,
			"g": 80.0,
			"c": ["*", "+", "!", "9", "7", "★"][randi() % 6],
			"col": [Color("#ffd600"), Color("#ff1744"), Color("#00e5ff"), Color.WHITE][randi() % 4],
			"a": 1.0,
			"life": 1.4,
			"max_life": 1.4,
		})


func _spawn_lightning_strike(target_p: Vector2) -> void:
	var pts: PackedVector2Array = []
	var curr = Vector2(target_p.x + randf_range(-15, 15), -140)
	pts.append(curr)
	while curr.y < target_p.y:
		curr += Vector2(randf_range(-14, 14), randf_range(12, 22))
		pts.append(curr)
	pts.append(target_p)

	lightning_bolts.append({
		"points": pts,
		"life": 0.28,
		"max_life": 0.28,
	})


var sword_arc_ribbon: Array = []
var sword_number_ghosts: Array = []
var _last_ghost_sample_tip: Vector2 = Vector2.ZERO

var _swing_blend: float = 0.0
var _swing_angle: float = 0.0

func _update_sword_animation(delta: float) -> void:
	_atk_timer += delta

	match _atk_state:
		AttackState.IDLE:
			var idle_breath: float = sin(_t * 2.2) * 0.04
			_arm_angle_upper = 0.35 + idle_breath
			_arm_angle_lower = -0.55 - idle_breath * 0.5
			_sword_angle = -0.35 + idle_breath * 0.4
			_swing_blend = move_toward(_swing_blend, 0.0, delta * 8.0)

		AttackState.WINDUP:
			_swing_blend = move_toward(_swing_blend, 1.0, delta * 12.0)
			var p: float = clamp(_atk_timer / 0.11, 0.0, 1.0)
			var ep: float = ease(p, 0.5) # Smooth anticipation pull-back
			_swing_angle = lerp(-0.35, -2.2, ep)
			_sample_sword_number_ghosts(false)

		AttackState.SLASH:
			_swing_blend = 1.0
			# Smooth, powerful, perfectly circular uniform arc (0.12s)
			var p: float = clamp(_atk_timer / 0.12, 0.0, 1.0)
			var ep: float = sin(p * (PI * 0.5)) # Strong smooth forward acceleration curve
			_swing_angle = lerp(-2.2, 0.75, ep)

			_sample_sword_number_ghosts(true)
			_sample_tip_trace()

			if _atk_timer >= 0.12:
				_atk_state = AttackState.RECOVER
				_atk_timer = 0.0

		AttackState.RECOVER:
			var p: float = clamp(_atk_timer / 0.13, 0.0, 1.0)
			var ep: float = ease(p, 0.4) # Smooth follow-through returning to ready stance
			_swing_angle = lerp(0.75, -0.35, ep)
			_swing_blend = lerp(1.0, 0.0, ep)
			_sample_sword_number_ghosts(false)

			if _atk_timer >= 0.13:
				_atk_state = AttackState.IDLE
				_atk_timer = 0.0
				_swing_blend = 0.0

		AttackState.SPECIAL:
			# Sword flourish & triumphant pose
			var p: float = clamp(_atk_timer / 0.85, 0.0, 1.0)
			_swing_blend = 1.0
			_swing_angle = lerp(-0.35, -2.4, sin(p * PI))
			_sample_sword_number_ghosts(false)

			if _atk_timer >= 0.85:
				_atk_state = AttackState.IDLE
				_atk_timer = 0.0
				_swing_blend = 0.0


func _sample_tip_trace() -> void:
	if equipped_sword != "sword_lightsaber":
		return
	var tip := _get_sword_tip()
	sword_arc_ribbon.append({
		"tip": tip,
		"a": 1.0,
		"life": 0.16,
		"max_life": 0.16
	})


var _last_ghost_hand: Vector2 = Vector2.ZERO

func _sample_sword_number_ghosts(force: bool = false) -> void:
	if not has_sword or not font:
		return
	# Ghosting trail is exclusive to the Plasma Lightsaber
	if equipped_sword != "sword_lightsaber":
		return

	var tip := _get_sword_tip()
	var hand := _get_hand_pos()
	var dist: float = (_last_ghost_sample_tip - tip).length()

	# When idle/not moving, avoid spam
	if not force and dist < 2.5:
		return

	# If first sample
	if _last_ghost_sample_tip == Vector2.ZERO:
		_last_ghost_sample_tip = tip
		_last_ghost_hand = hand

	var max_life: float = 0.85

	# Subdivide movement into smooth interpolated steps (10x denser coverage with zero gaps)
	var steps: int = clamp(int(dist / 3.5), 1, 8) if (force or dist > 4.0) else 1

	for st in range(1, steps + 1):
		var frac: float = float(st) / float(steps)
		var h: Vector2 = _last_ghost_hand.lerp(hand, frac)
		var t: Vector2 = _last_ghost_sample_tip.lerp(tip, frac)

		var blade_vec := t - h
		var blade_len := blade_vec.length()
		var blade_dir := blade_vec.normalized()
		var blade_norm := Vector2(-blade_dir.y, blade_dir.x)

		for s in sword_slots:
			var p: Vector2 = Vector2.ZERO
			if s.type == "blade":
				p = h + blade_dir * (blade_len * float(s.t_pos))
			elif s.type == "guard":
				p = h + blade_dir * (blade_len * float(s.t_pos)) + blade_norm * float(s.offset_side)
			elif s.type == "pommel":
				p = h + blade_dir * (blade_len * float(s.t_pos))

			var ghost_col: Color = Color.WHITE
			var drift: Vector2 = blade_norm * randf_range(-5.0, 5.0) + Vector2(randf_range(-2.0, 2.0), randf_range(-4.0, -1.0))

			sword_number_ghosts.append({
				"p": p,
				"c": s.c,
				"size": 8,
				"col": ghost_col,
				"a": 0.95,
				"life": max_life,
				"max_life": max_life,
				"v": drift,
				"glow": true
			})

	_last_ghost_sample_tip = tip
	_last_ghost_hand = hand


func _get_shoulder_pos() -> Vector2:
	var bob_y: float = offset_mod.y
	return Vector2(2 * facing_direction, -12 + bob_y)


func _get_elbow_pos() -> Vector2:
	var shoulder := _get_shoulder_pos()
	var hand := _get_hand_pos()
	if _swing_blend > 0.001:
		var ang := _swing_angle if facing_direction > 0 else (PI - _swing_angle)
		var swing_norm := Vector2(-sin(ang), cos(ang)) * (4.0 * facing_direction)
		return shoulder.lerp(hand, 0.5) + swing_norm
	else:
		var upper_len: float = 16.0
		var ang := _arm_angle_upper if facing_direction > 0 else (PI - _arm_angle_upper)
		return shoulder + Vector2(cos(ang), sin(ang)) * upper_len


func _get_hand_pos() -> Vector2:
	var shoulder := _get_shoulder_pos()
	var upper_len: float = 16.0
	var lower_len: float = 15.0
	var ang_u := _arm_angle_upper if facing_direction > 0 else (PI - _arm_angle_upper)
	var elbow_idle := shoulder + Vector2(cos(ang_u), sin(ang_u)) * upper_len

	var total_angle: float = _arm_angle_upper + _arm_angle_lower
	if facing_direction < 0:
		total_angle = PI - total_angle
	var idle_hand := elbow_idle + Vector2(cos(total_angle), sin(total_angle)) * lower_len

	if _swing_blend <= 0.001:
		return idle_hand

	# Uniform radial reach (22px) during swing for perfect circular symmetry
	var ang := _swing_angle if facing_direction > 0 else (PI - _swing_angle)
	var swing_hand := shoulder + Vector2(cos(ang), sin(ang)) * 22.0
	return idle_hand.lerp(swing_hand, _swing_blend)


func _get_sword_tip() -> Vector2:
	var hand := _get_hand_pos()
	var blade_len: float = 48.0
	if _swing_blend > 0.001:
		var ang := _swing_angle if facing_direction > 0 else (PI - _swing_angle)
		var idle_ang := _sword_angle if facing_direction > 0 else (PI - _sword_angle)
		var final_ang: float = lerp_angle(idle_ang, ang, _swing_blend)
		return hand + Vector2(cos(final_ang), sin(final_ang)) * blade_len
	else:
		var ang := _sword_angle if facing_direction > 0 else (PI - _sword_angle)
		return hand + Vector2(cos(ang), sin(ang)) * blade_len


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

	# Continuous weapon-specific particle emissions along the blade
	_emit_elemental_blade_particles(delta)


# ---------------------------------------------------------------------------
#  ELEMENTAL WEAPON PARTICLES (Smoke, Burning Embers, Frost Mist, Plasma Lightning, Gold Stars, Pan Sizzle)
# ---------------------------------------------------------------------------
func _emit_elemental_blade_particles(delta: float) -> void:
	var hand := _get_hand_pos()
	var tip := _get_sword_tip()
	var blade_vec := tip - hand
	var blade_len := blade_vec.length()
	var blade_dir := blade_vec.normalized()
	var is_slashing: bool = (_atk_state == AttackState.SLASH or _atk_state == AttackState.WINDUP)

	match equipped_sword:
		"sword_flame":
			# 1. Rising dark smoke puffs drifting upwards (intensified)
			var smoke_count: int = 3 if is_slashing else 1
			for i in range(smoke_count):
				if randf() < (0.95 if is_slashing else 0.65):
					var t_pos: float = randf_range(0.1, 1.0)
					var p: Vector2 = hand + blade_dir * (blade_len * t_pos) + Vector2(randf_range(-5, 5), randf_range(-5, 5))
					elemental_particles.append({
						"p": p,
						"v": Vector2(randf_range(-18, 18), randf_range(-45, -20)),
						"g": -16.0, # rises swiftly like hot dark smoke
						"c": ["~", "o", "°", "·", "≈", "░"][randi() % 6],
						"col": [Color(0.25, 0.22, 0.26, 0.8), Color(0.38, 0.25, 0.22, 0.8), Color(0.15, 0.15, 0.18, 0.85)][randi() % 3],
						"a": 0.85,
						"life": randf_range(0.35, 0.68),
						"max_life": 0.68,
						"size": randi_range(7, 11),
						"on_top": false,
						"rot": 0.0,
						"rot_spd": randf_range(-3.0, 3.0),
					})

			# 2. Glowing intense fire flame embers popping off blade (intensified)
			var ember_count: int = 6 if is_slashing else 3
			for i in range(ember_count):
				if randf() < (0.9 if is_slashing else 0.75):
					var t_pos: float = randf_range(0.15, 1.0)
					var p: Vector2 = hand + blade_dir * (blade_len * t_pos) + Vector2(randf_range(-4, 4), randf_range(-4, 4))
					elemental_particles.append({
						"p": p,
						"v": Vector2(randf_range(-35, 35), randf_range(-65, -25)),
						"g": -28.0,
						"c": ["*", "+", "·", "^", "1", "7", "x"][randi() % 7],
						"col": [Color("#ff1744"), Color("#ff5722"), Color("#ff9100"), Color("#ffd600"), Color.WHITE][randi() % 5],
						"a": 1.0,
						"life": randf_range(0.28, 0.52),
						"max_life": 0.52,
						"size": randi_range(6, 9),
						"on_top": true,
						"rot": 0.0,
						"rot_spd": randf_range(-6.0, 6.0),
					})

		"sword_frost":
			# Freezing cold vapor mist & ice crystals (intensified)
			var frost_count: int = 5 if is_slashing else 2
			for i in range(frost_count):
				if randf() < (0.9 if is_slashing else 0.7):
					var t_pos: float = randf_range(0.1, 1.0)
					var p: Vector2 = hand + blade_dir * (blade_len * t_pos) + Vector2(randf_range(-4, 4), randf_range(-4, 4))
					elemental_particles.append({
						"p": p,
						"v": Vector2(randf_range(-18, 18), randf_range(8, 35)), # icy vapor falls gently
						"g": 24.0,
						"c": ["◇", "*", "+", "·", "x", "1", "0"][randi() % 7],
						"col": [Color("#e0f7fa"), Color("#80deea"), Color("#00e5ff"), Color("#26c6da"), Color.WHITE][randi() % 5],
						"a": 0.95,
						"life": randf_range(0.35, 0.62),
						"max_life": 0.62,
						"size": randi_range(6, 9),
						"on_top": randf() > 0.3,
						"rot": 0.0,
						"rot_spd": randf_range(-5.0, 5.0),
					})

		"sword_lightsaber":
			# Electric plasma sparks & crackles along the blade
			var spark_count: int = 4 if is_slashing else 1
			for i in range(spark_count):
				if randf() < 0.65:
					var t_pos: float = randf_range(0.1, 1.0)
					var p: Vector2 = hand + blade_dir * (blade_len * t_pos) + Vector2(randf_range(-5, 5), randf_range(-5, 5))
					var crackle_dir: Vector2 = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
					elemental_particles.append({
						"p": p,
						"v": crackle_dir * randf_range(30.0, 110.0),
						"g": 0.0,
						"c": ["\\", "/", "|", "-", "*", "⚡"][randi() % 6],
						"col": [Color("#00e5ff"), Color("#1de9b6"), Color("#69f0ae"), Color.WHITE][randi() % 4],
						"a": 1.0,
						"life": randf_range(0.12, 0.28),
						"max_life": 0.28,
						"size": randi_range(6, 9),
						"on_top": true,
						"rot": randf() * TAU,
						"rot_spd": randf_range(-12.0, 12.0),
					})

		"sword_gold":
			# Pure, clean, clear metallic gold blade - no glowing, burning, or haze
			pass

		"sword_pan":
			# Sizzling food/grease puffs and comical cooking sparks
			if randf() < (0.75 if is_slashing else 0.35):
				var p: Vector2 = hand + blade_dir * 28.0 + Vector2(randf_range(-6, 6), randf_range(-6, 6))
				elemental_particles.append({
					"p": p,
					"v": Vector2(randf_range(-18, 18), randf_range(-45, -15)),
					"g": -16.0,
					"c": ["o", "O", "°", "~", "♨"][randi() % 5],
					"col": [Color(0.85, 0.75, 0.65, 0.8), Color(1.0, 0.85, 0.4, 0.9), Color(0.9, 0.4, 0.2, 0.85)][randi() % 3],
					"a": 0.85,
					"life": randf_range(0.3, 0.55),
					"max_life": 0.55,
					"size": randi_range(7, 11),
					"on_top": true,
					"rot": 0.0,
					"rot_spd": randf_range(-4.0, 4.0),
				})

		_: # sword_iron
			# Sharp metallic cut friction sparks
			if is_slashing or randf() < 0.2:
				var t_pos: float = randf_range(0.3, 1.0)
				var p: Vector2 = hand + blade_dir * (blade_len * t_pos)
				elemental_particles.append({
					"p": p,
					"v": Vector2(randf_range(-35, 35), randf_range(-35, 20)),
					"g": 90.0,
					"c": ["·", "*", "/", "\\"][randi() % 4],
					"col": [Color("#00e5ff"), Color("#80d8ff"), Color.WHITE][randi() % 3],
					"a": 0.9,
					"life": randf_range(0.15, 0.3),
					"max_life": 0.3,
					"size": randi_range(6, 8),
					"on_top": true,
					"rot": 0.0,
					"rot_spd": 0.0,
				})


func _update_elemental_particles(delta: float) -> void:
	var i: int = elemental_particles.size() - 1
	while i >= 0:
		var p = elemental_particles[i]
		p.life -= delta
		p.v.y += float(p.g) * delta
		p.p += Vector2(p.v) * delta
		p.rot += float(p.rot_spd) * delta
		var life_ratio: float = max(0.0, float(p.life) / float(p.max_life))
		p.a = life_ratio * 0.95

		if p.life <= 0.0 or p.a <= 0.01:
			elemental_particles.remove_at(i)
		i -= 1

	if elemental_particles.size() > 120:
		elemental_particles.resize(120)


func _draw_elemental_particles(draw_on_top: bool) -> void:
	for p in elemental_particles:
		if bool(p.on_top) != draw_on_top:
			continue
		var col: Color = Color(p.col, p.a)
		draw_char(font, p.p, p.c, p.size, col)


func _transform_slot_pos(local_p: Vector2) -> Vector2:
	var scale_m: Vector2 = Vector2(scale_mod.x * facing_direction, scale_mod.y)
	return (local_p * scale_m).rotated(rot_mod) + offset_mod


# ---------------------------------------------------------------------------
#  CHARACTER GHOST ECHO / AFTERIMAGE SYSTEM ("Verblassender Schatten der Zeichen")
# ---------------------------------------------------------------------------
func _capture_character_ghosts() -> void:
	if not font or _is_splatting:
		return

	# 1. Capture Eyes & Visor Glow
	if eyes.has("positions"):
		var eye_col: Color = eyes.get("color", Color.CYAN)
		for ep in eyes.positions:
			var wp = _to_head_world(ep, offset_mod, Vector2(scale_mod.x * facing_direction, scale_mod.y), rot_mod)
			character_ghosts.append({
				"p": wp,
				"c": "•",
				"size": 8,
				"col": eye_col,
				"a": 0.7,
				"decay": 4.5,
				"v": Vector2(0, -2)
			})

	# 2. Capture Equation Characters if active
	if not equation_text.is_empty() and (_atk_state == AttackState.SLASH or randf() < 0.25):
		for s in slots:
			if s.eq:
				var p = _transform_slot_pos(s.p)
				character_ghosts.append({
					"p": p,
					"c": s.c,
					"size": 8,
					"col": eq_color,
					"a": 0.55,
					"decay": 4.0,
					"v": Vector2(randf_range(-3, 3), randf_range(-3, 3))
				})


func _update_character_ghosts(delta: float) -> void:
	# Trigger ghost captures during body movement
	var body_moved: float = (_last_body_offset - offset_mod).length()
	if body_moved > 1.2 or _atk_state == AttackState.WINDUP:
		_capture_character_ghosts()

	_last_body_offset = offset_mod

	# Decay & update active character ghost shadows
	var i: int = character_ghosts.size() - 1
	while i >= 0:
		var g = character_ghosts[i]
		g.a -= delta * float(g.decay)
		g.p += Vector2(g.v) * delta
		g.v = Vector2(g.v) * 0.94

		if g.a <= 0.01:
			character_ghosts.remove_at(i)
		i -= 1

	if character_ghosts.size() > 140:
		character_ghosts.resize(140)


func _draw_character_ghosts() -> void:
	for g in character_ghosts:
		var col := Color(g.col, g.a)
		draw_char(font, g.p, g.c, g.size, col)


# ---------------------------------------------------------------------------
#  SWORD TRAIL & SLASH ATTACK
# ---------------------------------------------------------------------------
func _emit_sword_trail(is_slash: bool) -> void:
	var hand := _get_hand_pos()
	var tip := _get_sword_tip()
	var blade_vec := tip - hand
	var blade_len := blade_vec.length()
	var blade_dir := blade_vec.normalized()

	var count: int = 8 if is_slash else 2
	for i in range(count):
		var t_pos: float = randf_range(0.2, 1.0)
		var p: Vector2 = hand + blade_dir * (blade_len * t_pos)
		var drift: Vector2 = Vector2(randf_range(-14, 14), randf_range(-14, 14))
		if is_slash:
			drift += Vector2(-blade_dir.y, blade_dir.x) * randf_range(-30.0, -10.0)

		var char_col: Color = sword_trail_color if randf() > 0.3 else sword_core_color
		sword_trail_chars.append({
			"p": p,
			"c": MC[randi() % MC.size()],
			"col": char_col,
			"a": 0.95 if is_slash else 0.45,
			"decay": 4.2 if is_slash else 5.5,
			"v": drift,
			"size": 8 if randf() > 0.25 else 7,
		})


func _update_sword_trail(delta: float) -> void:
	# 1. Update lingering ghost copies of sword numbers & digits (Entstehungsdecay)
	var g_idx: int = sword_number_ghosts.size() - 1
	while g_idx >= 0:
		var g = sword_number_ghosts[g_idx]
		g.life -= delta
		var ratio: float = clamp(float(g.life) / float(g.max_life), 0.0, 1.0)
		g.a = pow(ratio, 1.1) # Smooth chronological fade: origin dissolves first
		g.p += Vector2(g.v) * delta # Gentle micro-motion
		g.v = Vector2(g.v) * 0.95

		if g.life <= 0.0 or g.a <= 0.01:
			sword_number_ghosts.remove_at(g_idx)
		g_idx -= 1

	if sword_number_ghosts.size() > 400:
		sword_number_ghosts.resize(400)

	# 2. Update tip trace curve
	var r_idx: int = sword_arc_ribbon.size() - 1
	while r_idx >= 0:
		sword_arc_ribbon[r_idx].life -= delta
		sword_arc_ribbon[r_idx].a = max(0.0, float(sword_arc_ribbon[r_idx].life) / float(sword_arc_ribbon[r_idx].max_life))
		if sword_arc_ribbon[r_idx].life <= 0.0:
			sword_arc_ribbon.remove_at(r_idx)
		r_idx -= 1

	if sword_arc_ribbon.size() > 16:
		sword_arc_ribbon.resize(16)

	# 3. Update trailing sparks/glyphs (disabled for gold/lightsaber)
	var i: int = sword_trail_chars.size() - 1
	while i >= 0:
		sword_trail_chars[i].a -= delta * float(sword_trail_chars[i].decay)
		sword_trail_chars[i].p += Vector2(sword_trail_chars[i].v) * delta
		sword_trail_chars[i].v = Vector2(sword_trail_chars[i].v) * 0.92

		if randf() < 0.1:
			sword_trail_chars[i].c = MC[randi() % MC.size()]

		if sword_trail_chars[i].a <= 0.01:
			sword_trail_chars.remove_at(i)
		i -= 1

	if sword_trail_chars.size() > 60:
		sword_trail_chars.resize(60)


func _draw_sword_trail() -> void:
	# 1. Draw lingering ghost numbers & characters at their exact world positions
	for g in sword_number_ghosts:
		var a: float = float(g.a)
		if g.get("glow", false):
			# Soft neon cyan halo behind ghost numbers
			draw_char(font, g.p, g.c, 9, Color(0.0, 1.0, 0.85, a * 0.35))
		draw_char(font, g.p, g.c, g.size, Color(g.col, a))

	# 2. Smooth, thin, elegant cutting trace curve along blade tip path
	if sword_arc_ribbon.size() >= 2 and equipped_sword != "sword_gold":
		var tip_pts: PackedVector2Array = []
		for r in sword_arc_ribbon:
			tip_pts.append(r.tip)
		var avg_a: float = sword_arc_ribbon.back().a
		var aura_col = Color(sword_aura_color.r, sword_aura_color.g, sword_aura_color.b, avg_a * 0.4)
		var edge_col = Color(1.0, 1.0, 1.0, avg_a * 0.85)

		draw_polyline(tip_pts, aura_col, 5.0, true)
		draw_polyline(tip_pts, edge_col, 1.8, true)


func _trigger_slash_burst() -> void:
	var hand := _get_hand_pos()
	var glyph_count: int = 24
	var center: Vector2 = hand + Vector2(24 * facing_direction, -4)
	var radius: float = 54.0

	var arc_glyphs: Array = []
	for i in range(glyph_count):
		var frac: float = float(i) / float(glyph_count - 1)
		var angle: float = lerp(-PI * 0.82, PI * 0.52, frac)
		if facing_direction < 0:
			angle = PI - angle
		var pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius
		arc_glyphs.append({
			"p": pos,
			"c": MC[randi() % MC.size()],
			"col": sword_core_color if randf() > 0.3 else sword_aura_color,
			"a": 1.0,
			"vel": Vector2(cos(angle), sin(angle)) * randf_range(70.0, 190.0),
		})

	slash_glyph_arcs.append({
		"glyphs": arc_glyphs,
		"life": 0.32,
		"max_life": 0.32,
	})

	# Secondary elemental burst particles
	if equipped_sword != "sword_gold":
		for k in range(12):
			var ang = randf() * TAU
			elemental_particles.append({
				"p": center + Vector2(cos(ang), sin(ang)) * randf_range(10.0, 35.0),
				"v": Vector2(cos(ang), sin(ang)) * randf_range(80.0, 220.0),
				"g": 40.0 if equipped_sword != "sword_flame" else -30.0,
				"c": ["*", "+", "!", "⚡", "★", "◇"][randi() % 6],
				"col": sword_trail_color if randf() > 0.3 else Color.WHITE,
				"a": 1.0,
				"life": randf_range(0.28, 0.48),
				"max_life": 0.48,
				"size": randi_range(7, 10),
				"on_top": true,
				"rot": randf() * TAU,
				"rot_spd": randf_range(-10.0, 10.0),
			})


func _update_slash_arcs(delta: float) -> void:
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


func _draw_slash_arcs() -> void:
	for arc in slash_glyph_arcs:
		for g in arc.glyphs:
			var col := Color(g.col, g.a)
			draw_char(font, Vector2(g.p) + Vector2(-1, 1), g.c, 10, Color(sword_aura_color, float(g.a) * 0.45))
			draw_char(font, g.p, g.c, 8, col)


func _draw_ascii_arm_and_sword() -> void:
	var shoulder := _get_shoulder_pos()
	var elbow := _get_elbow_pos()
	var hand := _get_hand_pos()
	var tip := _get_sword_tip()

	var blade_vec := tip - hand
	var blade_len := blade_vec.length()
	var blade_dir := blade_vec.normalized()
	var blade_norm := Vector2(-blade_dir.y, blade_dir.x)

	# ── 1. Cyber Arm ──
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

	draw_char(font, hand + Vector2(-2, 2), "#", 8, sword_guard_color)

	# ── 2. Sword / Weapon Styling ──
	if equipped_sword == "sword_pan":
		# Frying Pan shape in ASCII with prominent circular rim
		# 1. Sturdy iron handle
		for i in range(5):
			var t_pos: float = float(i) / 4.0
			var p: Vector2 = hand + blade_dir * (18.0 * t_pos)
			draw_char(font, p, "=", 8, sword_guard_color)
		draw_char(font, hand + blade_dir * 18.0, "#", 8, Color.WHITE)

		# 2. Big Round Cast-Iron Pan (radius = 13px)
		var pan_center := hand + blade_dir * 30.0
		var pan_rad: float = 13.0

		# Dark iron pan basin underlay
		var pan_poly := PackedVector2Array()
		for k in range(16 + 1):
			var ang = (float(k) / 16.0) * TAU
			pan_poly.append(pan_center + Vector2(cos(ang) * pan_rad, sin(ang) * pan_rad))
		draw_colored_polygon(pan_poly, Color(0.12, 0.12, 0.16, 0.95))

		# 3. Outer circular rim
		var rim_symbols: Array[String] = [")", "-", "(", "-", ")", "o", "(", "O", ")", "-", "(", "-", ")", "0", "(", "o"]
		for k in range(16):
			var ang = (float(k) / 16.0) * TAU
			var rp = pan_center + Vector2(cos(ang) * pan_rad, sin(ang) * pan_rad)
			var rim_char = rim_symbols[k % rim_symbols.size()]
			draw_char(font, rp + Vector2(-1, 1), rim_char, 8, Color(0.2, 0.2, 0.25, 0.5))
			draw_char(font, rp, rim_char, 8, Color(0.85, 0.85, 0.9, 0.95))

		# 4. Sizzling golden egg yolk / butter in pan center
		draw_char(font, pan_center + Vector2(-3, 0), "0", 11, Color("#ffd54f"))
		draw_char(font, pan_center + Vector2(2, -2), "•", 7, Color.WHITE)
	else:
		# Slender Blade of numbers with multi-layer aura bloom
		for s in sword_slots:
			var p: Vector2 = Vector2.ZERO
			if s.type == "blade":
				p = hand + blade_dir * (blade_len * float(s.t_pos)) + Vector2(s.jitter)
			elif s.type == "guard":
				p = hand + blade_dir * (blade_len * float(s.t_pos)) + blade_norm * float(s.offset_side) + Vector2(s.jitter)
			elif s.type == "pommel":
				p = hand + blade_dir * (blade_len * float(s.t_pos)) + Vector2(s.jitter)

			if equipped_sword == "sword_gold":
				# Crisp, clear, noble royal gold blade (no burning or blurry glow)
				draw_char(font, p + Vector2(-1, 1), s.c, 8, Color(0.12, 0.08, 0.02, 0.85))
				var gold_col = sword_core_color if s.type == "blade" else sword_guard_color
				draw_char(font, p, s.c, 8, Color(gold_col, s.a))
			else:
				# Multi-layered aura bloom glow
				draw_char(font, p + Vector2(-1.5, 1.5), s.c, 10, Color(sword_aura_color, float(s.a) * 0.4))
				draw_char(font, p + Vector2(1.5, -1.5), s.c, 10, Color(sword_aura_color, float(s.a) * 0.4))

				var core_col: Color = sword_core_color
				if s.type == "guard" or s.type == "pommel":
					core_col = sword_guard_color
				draw_char(font, p, s.c, 8, Color(core_col, s.a))

		var tip_char: String = "!" if randf() > 0.5 else "7"
		var tip_col = sword_core_color if equipped_sword != "sword_gold" else Color("#fff176")
		draw_char(font, tip + Vector2(-2, 2), tip_char, 9, tip_col)

# ---------------------------------------------------------------------------
#  HEADWEAR DRAWING (Helmets & Hats)
# ---------------------------------------------------------------------------
func _draw_headwear() -> void:
	var pos: Vector2 = offset_mod
	var scale_m: Vector2 = Vector2(scale_mod.x * facing_direction, scale_mod.y)
	var rot_m: float = rot_mod

	# ── Helmet Overrides ──
	match equipped_helmet:
		"helm_viking":
			# Viking Horns - seamlessly anchored to the helmet sides at y = -50
			var horn_col = Color("#ffd54f")
			var horn_tip_col = Color("#ffffff")
			var horn_pts_l = [
				{"p": Vector2(-8, -50), "c": "\\", "s": 9, "col": horn_col},
				{"p": Vector2(-12, -55), "c": "\\", "s": 8, "col": horn_col},
				{"p": Vector2(-15, -60), "c": "^", "s": 8, "col": horn_tip_col},
			]
			var horn_pts_r = [
				{"p": Vector2(8, -50), "c": "/", "s": 9, "col": horn_col},
				{"p": Vector2(12, -55), "c": "/", "s": 8, "col": horn_col},
				{"p": Vector2(15, -60), "c": "^", "s": 8, "col": horn_tip_col},
			]
			for hp in horn_pts_l:
				var wp = _to_head_world(hp.p, pos, scale_m, rot_m)
				var ch = hp.c if facing_direction > 0 else ( "/" if hp.c == "\\" else ( "\\" if hp.c == "/" else hp.c ) )
				draw_char(font, wp, ch, hp.s, hp.col)
			for hp in horn_pts_r:
				var wp = _to_head_world(hp.p, pos, scale_m, rot_m)
				var ch = hp.c if facing_direction > 0 else ( "\\" if hp.c == "/" else ( "/" if hp.c == "\\" else hp.c ) )
				draw_char(font, wp, ch, hp.s, hp.col)

		"helm_crown":
			# Royal Gold 3-Pointed Crown - securely seated on helmet top (y = -54)
			var crown_gold = Color("#ffd700")
			var ruby_red = Color("#ff1744")
			var sapphire_blue = Color("#00e5ff")

			# Base band
			for x_off in [-7.0, 0.0, 7.0]:
				var wp_band = _to_head_world(Vector2(x_off, -53.5), pos, scale_m, rot_m)
				draw_char(font, wp_band, "=", 8, crown_gold)

			# 3 Crown Spikes
			var wp_left = _to_head_world(Vector2(-7, -59), pos, scale_m, rot_m)
			var wp_mid = _to_head_world(Vector2(0, -62), pos, scale_m, rot_m)
			var wp_right = _to_head_world(Vector2(7, -59), pos, scale_m, rot_m)

			draw_char(font, wp_left, "W", 8, crown_gold)
			draw_char(font, wp_mid, "M", 9, crown_gold)
			draw_char(font, wp_right, "W", 8, crown_gold)

			# Crown jewels
			var jewel_mid = _to_head_world(Vector2(0, -55), pos, scale_m, rot_m)
			var jewel_l = _to_head_world(Vector2(-6, -54.5), pos, scale_m, rot_m)
			var jewel_r = _to_head_world(Vector2(6, -54.5), pos, scale_m, rot_m)

			draw_circle(jewel_mid, 1.5, ruby_red)
			draw_circle(jewel_l, 1.2, sapphire_blue)
			draw_circle(jewel_r, 1.2, sapphire_blue)

	# ── Hat Overrides ──
	match equipped_hat:
		"hat_wizard":
			# Wizard Hat - broad brim on helmet top (y = -54), tall cone with magic star
			var hat_purp = Color("#7e57c2")
			var hat_light = Color("#b39ddb")
			var star_gold = Color("#ffd600")

			# Brim
			for bx in [-10.0, -5.0, 0.0, 5.0, 10.0]:
				var wp_b = _to_head_world(Vector2(bx, -54), pos, scale_m, rot_m)
				draw_char(font, wp_b, "=", 9, hat_purp)

			# Cone tiers
			var wp_c1 = _to_head_world(Vector2(-4, -59), pos, scale_m, rot_m)
			var wp_c2 = _to_head_world(Vector2(4, -59), pos, scale_m, rot_m)
			var ch_c1 = "/" if facing_direction > 0 else "\\"
			var ch_c2 = "\\" if facing_direction > 0 else "/"
			draw_char(font, wp_c1, ch_c1, 9, hat_purp)
			draw_char(font, wp_c2, ch_c2, 9, hat_purp)

			var wp_tip = _to_head_world(Vector2(0, -65), pos, scale_m, rot_m)
			draw_char(font, wp_tip, "^", 10, hat_light)

			# Glowing magic star on tip
			var star_p = _to_head_world(Vector2(3, -71), pos, scale_m, rot_m)
			draw_char(font, star_p, "*", 9, star_gold)

		"hat_jester":
			# 2-pointed bouncy jester cap
			var col_l = Color("#ff4081") # pink
			var col_r = Color("#00e676") # green
			var bell_col = Color("#ffd600") # gold
			var bob = sin(_t * 7.0) * 2.0

			# Cap rim
			for bx in [-6.0, 0.0, 6.0]:
				var wp_b = _to_head_world(Vector2(bx, -54), pos, scale_m, rot_m)
				draw_char(font, wp_b, "-", 8, Color("#ffeb3b"))

			# Left horn droop + bell
			var wp_jl = _to_head_world(Vector2(-10, -58 + bob), pos, scale_m, rot_m)
			var wp_jl_bell = _to_head_world(Vector2(-15, -53 + bob), pos, scale_m, rot_m)
			var ch_jl = "(" if facing_direction > 0 else ")"
			draw_char(font, wp_jl, ch_jl, 9, col_l)
			draw_char(font, wp_jl_bell, "o", 7, bell_col)

			# Right horn droop + bell
			var wp_jr = _to_head_world(Vector2(10, -58 - bob), pos, scale_m, rot_m)
			var wp_jr_bell = _to_head_world(Vector2(15, -53 - bob), pos, scale_m, rot_m)
			var ch_jr = ")" if facing_direction > 0 else "("
			draw_char(font, wp_jr, ch_jr, 9, col_r)
			draw_char(font, wp_jr_bell, "o", 7, bell_col)

		"hat_propeller":
			# Propeller beanie cap fitted snugly on helmet with rotating propeller
			var cap_red = Color("#e53935")
			var cap_blue = Color("#1e88e5")
			var prop_col = Color("#ffd600")

			# Beanie dome
			var wp_d1 = _to_head_world(Vector2(-5, -55), pos, scale_m, rot_m)
			var wp_d2 = _to_head_world(Vector2(0, -56), pos, scale_m, rot_m)
			var wp_d3 = _to_head_world(Vector2(5, -55), pos, scale_m, rot_m)
			draw_char(font, wp_d1, "n", 8, cap_red)
			draw_char(font, wp_d2, "n", 8, cap_blue)
			draw_char(font, wp_d3, "n", 8, cap_red)

			# Spindle pin
			var wp_pin = _to_head_world(Vector2(0, -60), pos, scale_m, rot_m)
			draw_char(font, wp_pin, "|", 7, Color.WHITE)

			# Rotating Propeller blade
			var prop_frames: Array[String] = ["-", "\\", "|", "/"]
			var frame_idx: int = int(_propeller_rot) % 4
			var wp_prop = _to_head_world(Vector2(0, -63), pos, scale_m, rot_m)
			draw_char(font, wp_prop, prop_frames[frame_idx], 11, prop_col)

		"hat_sunglasses":
			# Deal-With-It sunglasses directly over the visor slit (y = -41.0)
			var shade_col = Color(0.08, 0.08, 0.12)
			var glint_col = Color.WHITE

			var wp_l = _to_head_world(Vector2(-3.0, -41.0), pos, scale_m, rot_m)
			var wp_bridge = _to_head_world(Vector2(0.0, -41.5), pos, scale_m, rot_m)
			var wp_r = _to_head_world(Vector2(3.0, -41.0), pos, scale_m, rot_m)

			# Lenses & bridge
			draw_char(font, wp_l, "#", 8, shade_col)
			draw_char(font, wp_bridge, "-", 7, shade_col)
			draw_char(font, wp_r, "#", 8, shade_col)

			# White deal-with-it pixel glint
			var glint_p1 = _to_head_world(Vector2(-4.0, -42.0), pos, scale_m, rot_m)
			var glint_p2 = _to_head_world(Vector2(2.0, -42.0), pos, scale_m, rot_m)
			draw_circle(glint_p1, 1.0, glint_col)
			draw_circle(glint_p2, 1.0, glint_col)


func _to_head_world(local_p: Vector2, pos: Vector2, scale_m: Vector2, rot_m: float) -> Vector2:
	return (local_p * scale_m).rotated(rot_m) + pos

# ---------------------------------------------------------------------------
#  SPECIAL VICTORY EFFECTS
# ---------------------------------------------------------------------------
func _update_victory_particles(delta: float) -> void:
	var i: int = victory_particles.size() - 1
	while i >= 0:
		victory_particles[i].life -= delta
		victory_particles[i].p += Vector2(victory_particles[i].v) * delta
		victory_particles[i].v.y += float(victory_particles[i].g) * delta
		victory_particles[i].a = max(0.0, float(victory_particles[i].life) / float(victory_particles[i].max_life))
		if victory_particles[i].life <= 0.0:
			victory_particles.remove_at(i)
		i -= 1


func _update_lightning_bolts(delta: float) -> void:
	var i: int = lightning_bolts.size() - 1
	while i >= 0:
		lightning_bolts[i].life -= delta
		if lightning_bolts[i].life <= 0.0:
			lightning_bolts.remove_at(i)
		i -= 1


func _draw_victory_effects() -> void:
	# Draw victory particles (confetti, fireworks sparks)
	for p in victory_particles:
		var c := Color(p.col, p.a)
		draw_char(font, p.p, p.c, 8, c)

	# Draw thunder lightning bolt
	for bolt in lightning_bolts:
		var pts: PackedVector2Array = bolt.points
		var a: float = bolt.life / bolt.max_life
		# Outer glow
		draw_polyline(pts, Color(0.1, 0.85, 1.0, a * 0.7), 6.0)
		# Pure white razor lightning core
		draw_polyline(pts, Color(1.0, 1.0, 1.0, a * 0.95), 2.2)

# ---------------------------------------------------------------------------
#  SLIME FLOOR DROPLETS & BEAUTIFUL STATIONARY FOOTPRINT PUDDLES
# ---------------------------------------------------------------------------
func _spawn_slime_landing_puddle() -> void:
	var puddle_center := global_position + Vector2(0, 34)
	var puddle_chars: Array[String] = ["~", "≈", "=", "░", "▒", "o", "0", "•", "%"]
	var puddle_colors: Array[Color] = [
		Color("#76ff03"), # Neon Lime
		Color("#64dd17"), # Toxic Acid Green
		Color("#b2ff59"), # Mint Glow
		Color("#aeea00"), # Fluorescent Green
		Color("#33691e")  # Deep Slime Base
	]

	# 1. Main elliptical footprint puddle core
	var core_count: int = randi_range(6, 9)
	for i in range(core_count):
		var offset_x: float = randf_range(-18.0, 18.0)
		var offset_y: float = randf_range(-3.0, 3.5)
		slime_droplets.append({
			"global_p": puddle_center + Vector2(offset_x, offset_y),
			"c": puddle_chars[randi() % puddle_chars.size()],
			"col": puddle_colors[randi() % puddle_colors.size()],
			"size": randi_range(7, 10),
			"a": randf_range(0.85, 1.0),
			"life": randf_range(2.8, 3.5),
			"max_life": 3.5,
			"is_splash": false,
		})

	# 2. Touchdown outward splash beads
	var splash_count: int = randi_range(2, 4)
	for i in range(splash_count):
		var side: float = -1.0 if randf() < 0.5 else 1.0
		var splash_x: float = side * randf_range(18.0, 28.0)
		var splash_y: float = randf_range(-2.0, 3.0)
		slime_droplets.append({
			"global_p": puddle_center + Vector2(splash_x, splash_y),
			"c": ["•", ".", "o", "*"][randi() % 4],
			"col": Color("#76ff03"),
			"size": 6,
			"a": randf_range(0.7, 0.9),
			"life": randf_range(2.0, 2.8),
			"max_life": 2.8,
			"is_splash": true,
		})


func _spawn_slime_droplet(world_pos: Vector2) -> void:
	var chars: Array[String] = ["~", ".", "o", "1", "0"]
	slime_droplets.append({
		"global_p": world_pos + Vector2(randf_range(-3, 3), randf_range(-1, 2)),
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
		# Smooth quadratic fade out
		d.a = progress * progress * 0.95
		if d.life <= 0.0:
			slime_droplets.remove_at(i)
		i -= 1


func _draw_slime_droplets() -> void:
	for d in slime_droplets:
		if d.a <= 0.01:
			continue
		var local_p: Vector2 = to_local(d.global_p)
		var alpha: float = float(d.a)
		var c := Color(d.col, alpha)

		# Luminous gooey underglow puddle disc
		var glow_rad: float = 4.5 if not d.get("is_splash", false) else 2.5
		draw_circle(local_p + Vector2(2, -2), glow_rad, Color(0.4, 0.95, 0.05, alpha * 0.22))
		draw_circle(local_p + Vector2(2, -2), glow_rad * 0.5, Color(0.7, 1.0, 0.2, alpha * 0.35))

		# Dark contrast shadow underneath character
		draw_char(font, local_p + Vector2(-1, 1), d.c, d.size, Color(0, 0, 0, alpha * 0.85))
		# Main luminous ASCII glyph
		draw_char(font, local_p, d.c, d.size, c)

# ---------------------------------------------------------------------------
#  SPLATTER EXPLOSION
# ---------------------------------------------------------------------------
func trigger_splatter() -> void:
	_is_splatting = true
	_splat_t = 0.0
	var ctr := _centroid()

	for s in slots:
		var dir: Vector2 = Vector2(s.p) - ctr
		if dir.length() < 0.1:
			dir = Vector2(randf_range(-1, 1), randf_range(-1, 1))
		dir = dir.normalized()

		var spd: float = randf_range(90.0, 280.0)
		if s.eq:
			spd *= 1.6
			s.col = eq_color

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


func _tick_splatter(delta: float) -> void:
	_splat_t += delta
	var any_visible: bool = false

	for s in slots:
		s.v.y += float(s.g) * delta
		s.p += Vector2(s.v) * delta
		s.r += float(s.rs) * delta
		s.a -= delta * 0.65
		s.a = max(0.0, float(s.a))

		if s.a > 0.01:
			any_visible = true
			if randf() < 0.12:
				s.c = MC[randi() % MC.size()]

	if _splat_t > 2.5 or not any_visible:
		splatter_finished.emit()

# ---------------------------------------------------------------------------
#  DRAWING ENTITY BODY
# ---------------------------------------------------------------------------
func _draw_entity_body() -> void:
	var pos: Vector2 = offset_mod
	var scale_m: Vector2 = Vector2(scale_mod.x * facing_direction, scale_mod.y)
	var rot_m: float = rot_mod

	# 1. Polygon Silhouette Underlay (0.05 alpha)
	if not _is_splatting:
		for pi in range(polys.size()):
			var poly: PackedVector2Array = polys[pi]
			var wp := PackedVector2Array()
			for pt in poly:
				var transformed_pt := (pt * scale_m).rotated(rot_m) + pos
				wp.append(transformed_pt)
			var fill_col: Color = base_color
			if part_colors.has(pi):
				fill_col = part_colors[pi]
			draw_colored_polygon(wp, Color(fill_col, 0.06))

	# 2. Scattered Body Characters (3D Manikin Projected & Depth Sorted for Knight)
	if entity_type == "knight" and not _is_splatting:
		var current_yaw: float = rotation_yaw
		if abs(current_yaw) < 0.0001:
			current_yaw = 0.0 if facing_direction > 0 else PI
		current_yaw += sin(_t * 2.2) * 0.04

		var cos_yaw: float = cos(current_yaw)
		var sin_yaw: float = sin(current_yaw)
		var cos_pitch: float = cos(rotation_pitch)
		var sin_pitch: float = sin(rotation_pitch)
		var dist_cam: float = 260.0

		var render_list: Array = []
		for s in slots:
			if s.eq or s.a < 0.01:
				continue

			var p3: Vector3 = Vector3(s.p.x, s.p.y, s.get("z", 0.0))

			if s.pi == 5:
				# 3D Purple Cape Wave Kinematics
				var v: float = clamp((s.p.y - (-34.0)) / 62.0, 0.0, 1.0)
				var u: float = clamp((s.p.x - (-30.0)) / 22.0, 0.0, 1.0)
				var wave_x: float = cos(_t * 3.5 - v * 2.0 + u * 0.6) * (2.5 + v * 7.5) * facing_direction
				var wave_z: float = -6.0 + sin(_t * 4.2 - v * 2.4 + u * 0.8) * (3.5 + v * 9.5)
				var wave_y: float = sin(_t * 2.8 - v * 1.4) * 1.8

				# Attack Wind Drag & Cape Flaring in 3D
				if _swing_blend > 0.01:
					wave_x += -14.0 * facing_direction * _swing_blend * v
					wave_z += sin(_atk_timer * PI / 0.12) * 8.0 * v

				p3.x += wave_x
				p3.y += wave_y
				p3.z = wave_z
			elif s.pi == 0:
				# Head Breathing Motion
				p3.y += sin(_t * 2.2) * 0.8

			# 3D Yaw & Pitch Transformation
			var x1: float = p3.x * cos_yaw + p3.z * sin_yaw
			var z1: float = -p3.x * sin_yaw + p3.z * cos_yaw
			var y1: float = p3.y

			var x2: float = x1
			var y2: float = y1 * cos_pitch - z1 * sin_pitch
			var z2: float = y1 * sin_pitch + z1 * cos_pitch

			var persp: float = dist_cam / maxf(30.0, dist_cam + z2)
			var screen_p: Vector2 = Vector2(x2 * persp * scale_mod.x, y2 * persp * scale_mod.y).rotated(rot_m) + pos
			screen_p += Vector2(
				sin(_t * 1.6 + float(s.ph)) * 0.6,
				cos(_t * 1.3 + float(s.ph) * 0.7) * 0.5
			)

			render_list.append({
				"screen_p": screen_p,
				"depth": z2,
				"c": s.c,
				"col": s.col,
				"a": s.a,
				"pi": s.pi
			})

		# Depth Sort (Back-to-Front)
		render_list.sort_custom(func(a, b): return a.depth < b.depth)

		for item in render_list:
			# Depth lighting modulation: +18% brightness for foreground, subtle shadow for background
			var depth_factor: float = clamp((item.depth + 18.0) / 36.0, 0.65, 1.3)
			var final_col: Color = Color(
				clampf(item.col.r * depth_factor, 0.0, 1.0),
				clampf(item.col.g * depth_factor, 0.0, 1.0),
				clampf(item.col.b * depth_factor, 0.0, 1.0),
				item.a
			)
			draw_char(font, item.screen_p, item.c, BFS, final_col)
	else:
		# Standard 2D rendering for other entities or splatter mode
		for s in slots:
			if s.eq or s.a < 0.01:
				continue

			var cp: Vector2
			if _is_splatting:
				cp = Vector2(s.p)
			else:
				var base_local: Vector2 = Vector2(s.p) * scale_m
				base_local = base_local.rotated(rot_m)
				cp = base_local + pos
				cp += Vector2(
					sin(_t * 1.6 + float(s.ph)) * 1.6,
					cos(_t * 1.3 + float(s.ph) * 0.7) * 1.2)
				if s.pi == 5 and part_colors.has(5):
					cp.x += sin(_t * 2.0 + float(s.p.y) * 0.12) * 3.5 * facing_direction

			var draw_col := Color(s.col, s.a)
			draw_char(font, cp, s.c, BFS, draw_col)

	# 3. Foreground Math Calculation
	var eq_alpha_pulse: float = 0.92 + sin(_t * 3.5) * 0.08
	var is_slime: bool = (entity_type == "slime")

	for s in slots:
		if not s.eq:
			continue
		if s.a < 0.01:
			continue

		var cp: Vector2
		if _is_splatting:
			cp = Vector2(s.p)
		else:
			var base_local: Vector2 = Vector2(s.p) * scale_m
			base_local = base_local.rotated(rot_m)
			cp = base_local + pos + Vector2(0, sin(_t * 2.8) * 1.0)

		var draw_col := Color(eq_color, eq_alpha_pulse)

		if is_slime and not _is_splatting:
			draw_circle(cp + Vector2(4, -4), 14.0, Color(0.39, 0.86, 0.09, 0.06))

		draw_char(font, cp + Vector2(-1.2, 1.2), s.c, EFS + 2, Color(0, 0, 0, 0.95))
		draw_char(font, cp, s.c, EFS + 2, Color(eq_color.r, eq_color.g, eq_color.b, 0.4))
		draw_char(font, cp, s.c, EFS, draw_col)

	# 4. Fixed Glowing Eyes
	if not _is_splatting and not eyes.is_empty():
		_draw_eyes(pos, scale_m, rot_m)


func _draw_eyes(entity_anchor: Vector2, scale_m: Vector2, rot_m: float) -> void:
	if entity_type == "knight" and equipped_hat == "hat_sunglasses":
		return # Sunglasses are drawn over eyes

	var eye_col: Color = eyes.color
	var sz: float = eyes.size
	var is_blink: bool = eyes.is_blinking
	var bp: float = eyes.blink_progress

	var v_scale: float = 1.0
	if is_blink:
		v_scale = abs(cos(bp * PI))
		v_scale = max(0.08, v_scale)

	for ep in eyes.positions:
		var local_p: Vector2 = (Vector2(ep.x * facing_direction, ep.y) * scale_mod).rotated(rot_m)
		var eye_world_pos: Vector2 = entity_anchor + local_p

		draw_circle(eye_world_pos, sz * 2.4, Color(eye_col.r, eye_col.g, eye_col.b, 0.22))
		draw_circle(eye_world_pos, sz * 1.3, Color(eye_col.r, eye_col.g, eye_col.b, 0.45))

		if v_scale < 0.35:
			draw_line(eye_world_pos + Vector2(-sz * 1.1, 0), eye_world_pos + Vector2(sz * 1.1, 0), Color.WHITE, 1.0)
		else:
			if eyes.style == "visor_glow":
				var r := Rect2(eye_world_pos - Vector2(sz * 0.9, sz * 0.55 * v_scale), Vector2(sz * 1.8, sz * 1.1 * v_scale))
				draw_rect(r, eye_col)
				draw_rect(Rect2(eye_world_pos - Vector2(sz * 0.45, sz * 0.25 * v_scale), Vector2(sz * 0.9, sz * 0.5 * v_scale)), Color.WHITE)
			else:
				var pts := PackedVector2Array()
				var segs: int = 10
				for i in range(segs + 1):
					var ang: float = (float(i) / float(segs)) * TAU
					pts.append(eye_world_pos + Vector2(cos(ang) * sz, sin(ang) * sz * v_scale))
				draw_colored_polygon(pts, eye_col)
				draw_circle(eye_world_pos + Vector2(sz * 0.2, -sz * 0.2 * v_scale), sz * 0.4 * v_scale, Color.WHITE)

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


func _centroid() -> Vector2:
	var s := Vector2.ZERO
	var n: int = 0
	for poly in polys:
		for p in poly:
			s += p
			n += 1
	return s / float(max(n, 1))
