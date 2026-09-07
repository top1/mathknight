class_name Ascii3DRenderer
extends Node2D

## ═══════════════════════════════════════════════════════════════════════════
## Ascii3DRenderer — Unified 3D Stickman & Living Dynamic ASCII Canvas
##
## Modes:
##   0: SOFT_ASCII      — Living, fluid Silkscreen-Bold ASCII matrix
##   1: WIREFRAME       — 3D skeletal sticks & joints with cape behind
##   2: OVERLAY         — Wireframe + Living ASCII mapped together
##   3: SOLID_3D        — Raw lit 3D meshes (PBR armor, 3D cape, glowing visor)
##   4: SHADER_MATRIX   — Screen-space CRT matrix shader
## ═══════════════════════════════════════════════════════════════════════════

signal slash_impact

enum RenderMode {
	SOFT_ASCII = 0,
	WIREFRAME = 1,
	OVERLAY = 2,
	SOLID_3D = 3,
	SHADER_MATRIX = 4
}

@export var render_mode: RenderMode = RenderMode.SHADER_MATRIX:
	set(val):
		render_mode = val
		_update_display_mode()
		queue_redraw()

@export var facing_direction: float = 1.0:
	set(val):
		facing_direction = val
		if stickman:
			stickman.facing_direction = val
		queue_redraw()

@export var turntable_yaw: float = 0.0:
	set(val):
		turntable_yaw = val
		if stickman:
			stickman.turntable_yaw = val
		queue_redraw()

@export var turntable_pitch: float = 0.0:
	set(val):
		turntable_pitch = val
		if stickman:
			stickman.turntable_pitch = val
		queue_redraw()

# Aliases for drop-in AsciiEntity compatibility
@export var rotation_yaw: float:
	get: return turntable_yaw
	set(val): turntable_yaw = val

@export var rotation_pitch: float:
	get: return turntable_pitch
	set(val): turntable_pitch = val

const StickmanKnight3DScript = preload("res://scenes/knight/3d/StickmanKnight3D.gd")
const StickmanMonster3DScript = preload("res://scenes/enemy/3d/StickmanMonster3D.gd")

@export var entity_type: String = "knight":
	set(val):
		entity_type = val
		if is_inside_tree():
			_rebuild_stickman()

@export var is_elite: bool = false:
	set(val):
		is_elite = val
		if stickman and "is_elite" in stickman:
			stickman.is_elite = val

# Nodes
var viewport: SubViewport
var camera: Camera3D
var stickman: Node3D
var display_rect: TextureRect
var shader_mat: ShaderMaterial
var font: Font

const VIEWPORT_W: int = 300
const VIEWPORT_H: int = 300

var _t: float = 0.0

# Glyph Pools
const MATH_CHARS: Array[String] = [
	"0", "1", "0", "1", "1", "0",
	"2", "3", "4", "5", "6", "7", "8", "9",
	"+", "-", "*", "/", "=", "%", "#", "^", "<", ">", "~", "X"
]
const CAPE_CHARS: Array[String] = ["@", "%", "8", "#", "3", "0", "X", "*", "=", "+"]
const SWORD_CHARS: Array[String] = ["1", "0", "7", "|", "/", "!", "+", "X", "=", "I"]

var _slots: Array = []
var _is_blinking: bool = false
var _blink_timer: float = 3.2


func _ready() -> void:
	font = load("res://assets/fonts/Silkscreen-Bold.ttf")
	if not font:
		font = ThemeDB.fallback_font

	_setup_subviewport()
	_setup_texture_display()

	if stickman and stickman.has_signal("slash_impact"):
		stickman.slash_impact.connect(func(): slash_impact.emit())
	elif stickman and stickman.has_signal("attack_impact"):
		stickman.attack_impact.connect(func(): slash_impact.emit())

	_init_slots()
	_update_display_mode()


func _setup_subviewport() -> void:
	viewport = SubViewport.new()
	viewport.name = "SubViewport3D"
	viewport.own_world_3d = true # Isolated 3D world for each entity!
	viewport.size = Vector2i(VIEWPORT_W, VIEWPORT_H)
	viewport.transparent_bg = true
	viewport.handle_input_locally = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = SubViewport.MSAA_2X
	add_child(viewport)

	# Camera looking directly at origin from +Z
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.45
	camera.position = Vector3(0, 1.15, 3.2)
	camera.current = true
	viewport.add_child(camera)
	camera.look_at(Vector3(0, 1.15, 0), Vector3.UP)

	# 3D Lighting
	var key_light = DirectionalLight3D.new()
	key_light.name = "KeyLight"
	key_light.rotation_degrees = Vector3(-30, 35, 0)
	key_light.light_energy = 1.5
	viewport.add_child(key_light)

	var fill_light = DirectionalLight3D.new()
	fill_light.name = "FillLight"
	fill_light.rotation_degrees = Vector3(20, -145, 0)
	fill_light.light_energy = 0.6
	viewport.add_child(fill_light)

	_rebuild_stickman()


func _rebuild_stickman() -> void:
	if not viewport:
		return
	if stickman and is_instance_valid(stickman):
		stickman.queue_free()
		stickman = null

	if entity_type == "knight":
		stickman = StickmanKnight3DScript.new()
		stickman.name = "StickmanKnight3D"
		stickman.facing_direction = facing_direction
		stickman.turntable_yaw = turntable_yaw
		stickman.turntable_pitch = turntable_pitch
		stickman.slash_impact.connect(func(): slash_impact.emit())
		viewport.add_child(stickman)
	else:
		stickman = StickmanMonster3DScript.new()
		stickman.name = "StickmanMonster3D"
		stickman.monster_type = entity_type
		stickman.is_elite = is_elite
		stickman.facing_direction = facing_direction
		stickman.attack_impact.connect(func(): slash_impact.emit())
		viewport.add_child(stickman)


func _setup_texture_display() -> void:
	display_rect = TextureRect.new()
	display_rect.name = "TextureDisplay"
	display_rect.texture = viewport.get_texture()
	display_rect.custom_minimum_size = Vector2(VIEWPORT_W, VIEWPORT_H)
	display_rect.size = Vector2(VIEWPORT_W, VIEWPORT_H)
	# 35% reduction in size to perfectly match classic 2D ASCII proportions
	display_rect.scale = Vector2(0.65, 0.65)
	# Precisely anchors 3D feet to the arena ground platform surface (Y=190)
	display_rect.position = Vector2(-62, -93)
	add_child(display_rect)

	var shader = load("res://shaders/ascii_rasterizer.gdshader")
	if shader:
		shader_mat = ShaderMaterial.new()
		shader_mat.shader = shader
		shader_mat.set_shader_parameter("cell_size", Vector2(4.0, 4.5))
		shader_mat.set_shader_parameter("brightness_mult", 1.4)
		shader_mat.set_shader_parameter("edge_strength", 1.8)
		shader_mat.set_shader_parameter("bloom_leak", 0.12)


func _update_display_mode() -> void:
	if not display_rect:
		return

	match render_mode:
		RenderMode.SOLID_3D:
			display_rect.visible = true
			display_rect.material = null # Raw lit 3D mesh
		RenderMode.SHADER_MATRIX:
			display_rect.visible = true
			display_rect.material = shader_mat # Shader pixel matrix
		_:
			display_rect.visible = false
			display_rect.material = null


# ---------------------------------------------------------------------------
#  VOLUMETRIC SLOTS
# ---------------------------------------------------------------------------
func _init_slots() -> void:
	_slots.clear()

	# 1. Cape Cloth Mesh (6 cols x 8 rows = 48 slots in the DEEP BACKGROUND)
	var purple_palette = [
		Color("#3b0b59"), Color("#4a148c"), Color("#6a1b9a"),
		Color("#7b1fa2"), Color("#8e24aa"), Color("#9c27b0")
	]
	for r in range(8):
		for c in range(6):
			_slots.append({
				"kind": "cape",
				"grid_r": r,
				"grid_c": c,
				"jitter": Vector3(randf_range(-0.02, 0.02), randf_range(-0.02, 0.02), 0),
				"char": CAPE_CHARS[(r * 6 + c) % CAPE_CHARS.size()],
				"base_col": purple_palette[r % purple_palette.size()],
				"curr_col": purple_palette[r % purple_palette.size()],
				"base_alpha": randf_range(0.65, 0.95),
				"alpha": 0.8,
				"fcd": randf_range(0.06, 0.28),
				"phase": randf() * TAU * 10.0,
				"size": [7, 8, 9][(r + c) % 3],
				"depth_bias": 2.5 # SORTS TO BACKGROUND
			})

	# 2. Torso & Chestplate (36 slots)
	var cyan_palette = [
		Color("#e0f7fa"), Color("#b2ebf2"), Color("#80deea"),
		Color("#4dd0e1"), Color("#26c6da"), Color("#00bcd4"),
		Color("#29b6f6"), Color("#0288d1")
	]
	for i in range(36):
		var ang = randf() * TAU
		var rx = randf_range(0.02, 0.20)
		var ry = randf_range(-0.12, 0.12)
		_slots.append({
			"kind": "torso",
			"offset": Vector3(cos(ang) * rx, ry + 0.08, randf_range(0.02, 0.12)),
			"jitter": Vector3.ZERO,
			"char": MATH_CHARS[i % MATH_CHARS.size()],
			"base_col": cyan_palette[i % cyan_palette.size()],
			"curr_col": cyan_palette[i % cyan_palette.size()],
			"base_alpha": randf_range(0.70, 1.0),
			"alpha": 0.85,
			"fcd": randf_range(0.05, 0.22),
			"phase": randf() * TAU * 10.0,
			"size": [8, 9, 10][i % 3],
			"depth_bias": -0.4
		})

	# 2b. ABDOMEN & WAIST (32 slots filling the middle body gap!)
	for i in range(32):
		var rx = randf_range(-0.16, 0.16)
		var ry = randf_range(-0.08, 0.08)
		var rz = randf_range(0.02, 0.12)
		_slots.append({
			"kind": "abdomen",
			"offset": Vector3(rx, ry + 0.07, rz),
			"jitter": Vector3.ZERO,
			"char": MATH_CHARS[(i * 3) % MATH_CHARS.size()],
			"base_col": cyan_palette[i % cyan_palette.size()],
			"curr_col": cyan_palette[i % cyan_palette.size()],
			"base_alpha": randf_range(0.75, 1.0),
			"alpha": 0.88,
			"fcd": randf_range(0.05, 0.22),
			"phase": randf() * TAU * 10.0,
			"size": [8, 9, 10][i % 3],
			"depth_bias": -0.4
		})

	# 2c. BELT & PELVIS (32 slots with golden belt accents!)
	var belt_palette = [Color("#ffd600"), Color("#ffca28"), Color("#0288d1"), Color("#29b6f6"), Color("#00e5ff")]
	for i in range(32):
		var rx = randf_range(-0.18, 0.18)
		var ry = randf_range(-0.07, 0.07)
		var rz = randf_range(0.02, 0.13)
		var is_belt = (i < 14)
		_slots.append({
			"kind": "pelvis",
			"offset": Vector3(rx, ry + 0.03, rz),
			"jitter": Vector3.ZERO,
			"char": ["=", "#", "[", "]", "8", "0", "X", "+", "~"][i % 9],
			"base_col": belt_palette[i % belt_palette.size()] if is_belt else cyan_palette[i % cyan_palette.size()],
			"curr_col": belt_palette[i % belt_palette.size()] if is_belt else cyan_palette[i % cyan_palette.size()],
			"base_alpha": randf_range(0.80, 1.0),
			"alpha": 0.90,
			"fcd": randf_range(0.05, 0.22),
			"phase": randf() * TAU * 10.0,
			"size": [8, 9, 10][i % 3],
			"depth_bias": -0.35
		})

	# 3. Head & Visor Eyes
	for i in range(20):
		var ang = (float(i) / 20.0) * TAU
		var phi = randf_range(-0.4, 0.8)
		_slots.append({
			"kind": "head",
			"offset": Vector3(cos(ang) * 0.16 * cos(phi), sin(phi) * 0.16 + 0.02, sin(ang) * 0.16 * cos(phi)),
			"jitter": Vector3.ZERO,
			"char": ["0", "1", "8", "B", "M", "H", "X", "=", "+", "#"][i % 10],
			"base_col": cyan_palette[i % cyan_palette.size()],
			"curr_col": cyan_palette[i % cyan_palette.size()],
			"base_alpha": randf_range(0.75, 1.0),
			"alpha": 0.9,
			"fcd": randf_range(0.05, 0.20),
			"phase": randf() * TAU * 10.0,
			"size": [8, 9, 10][i % 3],
			"depth_bias": -0.3
		})

	# Glowing Visor Eyes (Strictly on Front Face)
	for side in [-0.055, 0.055]:
		_slots.append({
			"kind": "eye_outer",
			"offset": Vector3(side, 0.02, 0.17),
			"jitter": Vector3.ZERO,
			"char": "O",
			"base_col": Color("#00ffff"),
			"curr_col": Color("#00ffff"),
			"base_alpha": 1.0,
			"alpha": 1.0,
			"fcd": 999.0,
			"phase": 0.0,
			"size": 11,
			"depth_bias": -1.5
		})
		_slots.append({
			"kind": "eye_inner",
			"offset": Vector3(side, 0.02, 0.18),
			"jitter": Vector3.ZERO,
			"char": "o",
			"base_col": Color.WHITE,
			"curr_col": Color.WHITE,
			"base_alpha": 1.0,
			"alpha": 1.0,
			"fcd": 999.0,
			"phase": 0.0,
			"size": 7,
			"depth_bias": -1.6
		})

	# 4. Arms
	for i in range(7):
		var t = (float(i) + 0.5) / 7.0
		_slots.append({
			"kind": "arm_l_upper", "t": t, "jitter": Vector3.ZERO,
			"char": ["1", "0", "+", "7"][i % 4], "base_col": Color("#29b6f6"), "curr_col": Color("#29b6f6"),
			"base_alpha": 0.85, "alpha": 0.85, "fcd": randf_range(0.06, 0.25), "phase": randf() * TAU * 10.0,
			"size": 7, "depth_bias": -0.2
		})
		_slots.append({
			"kind": "arm_l_lower", "t": t, "jitter": Vector3.ZERO,
			"char": ["0", "1", "=", "-"][i % 4], "base_col": Color("#4fc3f7"), "curr_col": Color("#4fc3f7"),
			"base_alpha": 0.85, "alpha": 0.85, "fcd": randf_range(0.06, 0.25), "phase": randf() * TAU * 10.0,
			"size": 7, "depth_bias": -0.2
		})
		_slots.append({
			"kind": "arm_r_upper", "t": t, "jitter": Vector3.ZERO,
			"char": ["1", "0", "+", "7"][i % 4], "base_col": Color("#29b6f6"), "curr_col": Color("#29b6f6"),
			"base_alpha": 0.85, "alpha": 0.85, "fcd": randf_range(0.06, 0.25), "phase": randf() * TAU * 10.0,
			"size": 7, "depth_bias": -0.2
		})
		_slots.append({
			"kind": "arm_r_lower", "t": t, "jitter": Vector3.ZERO,
			"char": ["0", "1", "=", "-"][i % 4], "base_col": Color("#4fc3f7"), "curr_col": Color("#4fc3f7"),
			"base_alpha": 0.85, "alpha": 0.85, "fcd": randf_range(0.06, 0.25), "phase": randf() * TAU * 10.0,
			"size": 7, "depth_bias": -0.2
		})

	# 5. Sword (Front-Left, pointing UP-LEFT towards enemy!)
	for i in range(6):
		var t = float(i - 2.5) * 0.06
		_slots.append({
			"kind": "sword_guard", "offset": Vector3(t, 0.18, 0), "jitter": Vector3.ZERO,
			"char": ["=", "#", "X"][i % 3], "base_col": Color("#ffd600"), "curr_col": Color("#ffd600"),
			"base_alpha": 1.0, "alpha": 1.0, "fcd": randf_range(0.08, 0.30), "phase": randf() * TAU * 10.0,
			"size": 9, "depth_bias": -1.2
		})

	for i in range(20):
		var t = float(i) / 19.0
		var is_aura = (i % 2 == 1)
		var x_off = (0.03 if i % 4 == 1 else -0.03) if is_aura else 0.0
		_slots.append({
			"kind": "sword_blade", "offset": Vector3(x_off, 0.22 + t * 1.15, 0), "jitter": Vector3.ZERO,
			"char": SWORD_CHARS[i % SWORD_CHARS.size()],
			"base_col": Color("#00e5ff") if is_aura else Color.WHITE,
			"curr_col": Color("#00e5ff") if is_aura else Color.WHITE,
			"base_alpha": 0.65 if is_aura else 1.0, "alpha": 1.0,
			"fcd": randf_range(0.04, 0.16), "phase": randf() * TAU * 10.0,
			"size": 10 if is_aura else 9, "depth_bias": -1.4
		})

	# 6. Legs
	for i in range(7):
		var t = (float(i) + 0.5) / 7.0
		_slots.append({
			"kind": "leg_l_upper", "t": t, "jitter": Vector3.ZERO,
			"char": ["1", "|", "/", "!"][i % 4], "base_col": Color("#1e88e5"), "curr_col": Color("#1e88e5"),
			"base_alpha": 0.85, "alpha": 0.85, "fcd": randf_range(0.06, 0.26), "phase": randf() * TAU * 10.0,
			"size": 8, "depth_bias": 0.0
		})
		_slots.append({
			"kind": "leg_l_lower", "t": t, "jitter": Vector3.ZERO,
			"char": ["1", "/", "\\", "I"][i % 4], "base_col": Color("#1565c0"), "curr_col": Color("#1565c0"),
			"base_alpha": 0.85, "alpha": 0.85, "fcd": randf_range(0.06, 0.26), "phase": randf() * TAU * 10.0,
			"size": 8, "depth_bias": 0.0
		})
		_slots.append({
			"kind": "leg_r_upper", "t": t, "jitter": Vector3.ZERO,
			"char": ["1", "|", "/", "!"][i % 4], "base_col": Color("#1e88e5"), "curr_col": Color("#1e88e5"),
			"base_alpha": 0.85, "alpha": 0.85, "fcd": randf_range(0.06, 0.26), "phase": randf() * TAU * 10.0,
			"size": 8, "depth_bias": 0.0
		})
		_slots.append({
			"kind": "leg_r_lower", "t": t, "jitter": Vector3.ZERO,
			"char": ["1", "/", "\\", "I"][i % 4], "base_col": Color("#1565c0"), "curr_col": Color("#1565c0"),
			"base_alpha": 0.85, "alpha": 0.85, "fcd": randf_range(0.06, 0.26), "phase": randf() * TAU * 10.0,
			"size": 8, "depth_bias": 0.0
		})


# ---------------------------------------------------------------------------
#  PROCESS: FLICKER & DRIFT
# ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	_t += delta

	_blink_timer -= delta
	if _blink_timer <= 0.0:
		if _is_blinking:
			_is_blinking = false
			_blink_timer = randf_range(2.8, 5.0)
		else:
			_is_blinking = true
			_blink_timer = 0.12

	for s in _slots:
		if s.kind == "eye_outer":
			s.char = "-" if _is_blinking else "O"
			continue
		if s.kind == "eye_inner":
			s.char = "" if _is_blinking else "o"
			continue

		s.fcd -= delta
		if s.fcd <= 0.0:
			s.fcd = randf_range(0.05, 0.18)
			if randf() < 0.50:
				match s.kind:
					"cape": s.char = CAPE_CHARS[randi() % CAPE_CHARS.size()]
					"sword_blade": s.char = SWORD_CHARS[randi() % SWORD_CHARS.size()]
					_: s.char = MATH_CHARS[randi() % MATH_CHARS.size()]

			if randf() < 0.12:
				s.curr_col = Color.WHITE
				s.alpha = 1.0
			else:
				s.curr_col = s.base_col
				var pulse = sin(_t * 4.2 + s.phase) * 0.25
				s.alpha = clampf(s.base_alpha + pulse, 0.25, 1.0)

	queue_redraw()


# ---------------------------------------------------------------------------
#  DRAW
# ---------------------------------------------------------------------------
func _draw() -> void:
	if not camera or not stickman:
		return

	# SOLID_3D and SHADER_MATRIX use SubViewport rendering directly
	if render_mode == RenderMode.SOLID_3D or render_mode == RenderMode.SHADER_MATRIX:
		return

	var vp_offset = Vector2(-VIEWPORT_W * 0.5, -VIEWPORT_H * 0.5)

	if render_mode == RenderMode.WIREFRAME:
		_draw_wireframe(vp_offset)
		return

	if render_mode == RenderMode.OVERLAY:
		_draw_wireframe(vp_offset)

	_draw_living_ascii(vp_offset)


func _draw_wireframe(vp_offset: Vector2) -> void:
	# 1. CAPE LINES FIRST (In the deep background)
	var cape_lines = stickman.get_cape_lines()
	for l in cape_lines:
		var p1 = camera.unproject_position(l.a) + vp_offset
		var p2 = camera.unproject_position(l.b) + vp_offset
		draw_line(p1, p2, l.col, 1.4, true)

	# 2. SKELETAL BONES ON TOP OF CAPE
	var lines = stickman.get_bone_lines()
	for l in lines:
		var p1 = camera.unproject_position(l.a) + vp_offset
		var p2 = camera.unproject_position(l.b) + vp_offset
		draw_line(p1, p2, l.col, 2.5, true)

	# 3. JOINTS ON TOP
	var joints = stickman.get_joint_points()
	for j in joints:
		var p = camera.unproject_position(j.pos) + vp_offset
		draw_circle(p, j.radius, j.col)
		draw_arc(p, j.radius + 1.2, 0, TAU, 16, Color.WHITE, 1.0, true)


func _draw_living_ascii(vp_offset: Vector2) -> void:
	# 1. Soft cape underlay
	_draw_cape_underlay(vp_offset)

	# 2. Solid dark body underlay (fills core silhouette and middle body!)
	_draw_body_underlay(vp_offset)

	# 3. Project and sort slots
	var projected: Array = []
	var cam_pos = camera.global_position
	var scan_y: float = sin(_t * 2.8) * 45.0

	for s in _slots:
		var gp: Vector3 = _get_slot_global_position(s)
		var screen_p = camera.unproject_position(gp) + vp_offset
		var depth = cam_pos.distance_to(gp) + s.get("depth_bias", 0.0)

		var drift_x = sin(_t * 3.5 + s.phase) * 1.5 + sin(_t * 7.2 + s.phase * 2.0) * 0.6
		var drift_y = cos(_t * 2.8 + s.phase * 1.3) * 1.2 + cos(_t * 6.0 + s.phase) * 0.5
		screen_p += Vector2(drift_x, drift_y)

		var dist_scan = abs(screen_p.y - scan_y)
		var scan_boost = (1.0 - dist_scan / 14.0) * 0.35 if dist_scan < 14.0 else 0.0

		projected.append({
			"p": screen_p, "depth": depth, "char": s.char, "col": s.curr_col,
			"alpha": minf(1.0, s.alpha + scan_boost), "size": s.size, "kind": s.kind
		})

	# Sort back-to-front (larger depth distance drawn first)
	projected.sort_custom(func(a, b): return a.depth > b.depth)

	for p in projected:
		if p.char.is_empty():
			continue
		var col = p.col
		col.a = p.alpha

		if p.kind == "eye_outer":
			draw_circle(p.p, 3.5, Color(0, 1, 1, 0.45))
		elif p.kind == "eye_inner":
			draw_circle(p.p, 1.8, Color.WHITE)

		draw_string(
			font,
			p.p + Vector2(-p.size * 0.35, p.size * 0.35),
			p.char,
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			p.size,
			col
		)


func _get_slot_global_position(s: Dictionary) -> Vector3:
	match s.kind:
		"cape":
			if stickman.cape_pts.size() > s.grid_r and stickman.cape_pts[s.grid_r].size() > s.grid_c:
				return stickman.root_pivot.to_global(stickman.cape_pts[s.grid_r][s.grid_c])
			return stickman.chest.global_position
		"torso":
			return stickman.chest.to_global(s.offset)
		"abdomen":
			return stickman.torso.to_global(s.offset)
		"pelvis":
			return stickman.pelvis.to_global(s.offset)
		"head", "eye_outer", "eye_inner":
			return stickman.head.to_global(s.offset)
		"arm_l_upper":
			return stickman.shoulder_left.global_position.lerp(stickman.forearm_left.global_position, s.t)
		"arm_l_lower":
			return stickman.forearm_left.global_position.lerp(stickman.hand_left.global_position, s.t)
		"arm_r_upper":
			return stickman.shoulder_right.global_position.lerp(stickman.forearm_right.global_position, s.t)
		"arm_r_lower":
			return stickman.forearm_right.global_position.lerp(stickman.hand_right.global_position, s.t)
		"sword_guard", "sword_blade":
			return stickman.sword_pivot.to_global(s.offset)
		"leg_l_upper":
			return stickman.hip_left.global_position.lerp(stickman.shin_left.global_position, s.t)
		"leg_l_lower":
			return stickman.shin_left.global_position.lerp(stickman.foot_left.global_position, s.t)
		"leg_r_upper":
			return stickman.hip_right.global_position.lerp(stickman.shin_right.global_position, s.t)
		"leg_r_lower":
			return stickman.shin_right.global_position.lerp(stickman.foot_right.global_position, s.t)
		_:
			return stickman.chest.global_position


func _draw_cape_underlay(vp_offset: Vector2) -> void:
	if not stickman or stickman.cape_pts.is_empty():
		return
	var col_cape = Color("#4a148c", 0.18)
	var colors = PackedColorArray([col_cape, col_cape, col_cape])
	var empty_uvs = PackedVector2Array()

	for r in range(stickman.CAPE_ROWS - 1):
		for c in range(stickman.CAPE_COLS - 1):
			var p00 = camera.unproject_position(stickman.root_pivot.to_global(stickman.cape_pts[r][c])) + vp_offset
			var p10 = camera.unproject_position(stickman.root_pivot.to_global(stickman.cape_pts[r][c + 1])) + vp_offset
			var p11 = camera.unproject_position(stickman.root_pivot.to_global(stickman.cape_pts[r + 1][c + 1])) + vp_offset
			var p01 = camera.unproject_position(stickman.root_pivot.to_global(stickman.cape_pts[r + 1][c])) + vp_offset

			draw_primitive(PackedVector2Array([p00, p10, p01]), colors, empty_uvs)
			draw_primitive(PackedVector2Array([p10, p11, p01]), colors, empty_uvs)


func _draw_body_underlay(vp_offset: Vector2) -> void:
	if not stickman:
		return
	# Solid dark silhouette polygon across chest, abdomen, and pelvis (fills core and middle body gap!)
	var p_chest_tl = camera.unproject_position(stickman.chest.to_global(Vector3(-0.25, 0.22, 0.05))) + vp_offset
	var p_chest_tr = camera.unproject_position(stickman.chest.to_global(Vector3(0.25, 0.22, 0.05))) + vp_offset
	var p_waist_r = camera.unproject_position(stickman.torso.to_global(Vector3(0.20, 0.02, 0.05))) + vp_offset
	var p_hip_r = camera.unproject_position(stickman.pelvis.to_global(Vector3(0.21, -0.10, 0.05))) + vp_offset
	var p_hip_l = camera.unproject_position(stickman.pelvis.to_global(Vector3(-0.21, -0.10, 0.05))) + vp_offset
	var p_waist_l = camera.unproject_position(stickman.torso.to_global(Vector3(-0.20, 0.02, 0.05))) + vp_offset

	var poly = PackedVector2Array([p_chest_tl, p_chest_tr, p_waist_r, p_hip_r, p_hip_l, p_waist_l])
	draw_colored_polygon(poly, Color("#081426", 0.85))


func play_idle() -> void:
	if stickman: stickman.play_idle()

func play_windup() -> void:
	if stickman: stickman.play_windup()

func play_slash() -> void:
	if stickman:
		if stickman.has_method("play_slash"): stickman.play_slash()
		elif stickman.has_method("play_attack"): stickman.play_attack()

func play_attack() -> void:
	if stickman:
		if stickman.has_method("play_attack"): stickman.play_attack()
		elif stickman.has_method("play_slash"): stickman.play_slash()

func play_walk() -> void:
	if stickman and stickman.has_method("play_walk"): stickman.play_walk()

func play_hurt() -> void:
	if stickman and stickman.has_method("play_hurt"): stickman.play_hurt()

func play_defeated() -> void:
	if stickman and stickman.has_method("play_defeated"): stickman.play_defeated()

func take_hit(_damage: float = 1.0) -> void:
	play_hurt()

func play_victory() -> void:
	if stickman and stickman.has_method("play_victory"): stickman.play_victory()

func apply_cosmetics(cosmetics: Dictionary) -> void:
	if stickman and stickman.has_method("apply_cosmetics"): stickman.apply_cosmetics(cosmetics)
