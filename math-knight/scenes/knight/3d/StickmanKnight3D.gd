class_name StickmanKnight3D
extends Node3D

## ═══════════════════════════════════════════════════════════════════════════
## StickmanKnight3D — True 3D Stickman Knight with Physical Cloth Cape
##
## Coordinate System Ground Truth (Camera at (0, 1.15, +3.2) looking at -Z):
##   • +Z = FRONT (Facing Viewer / Camera)
##   • -Z = BACK  (Away from Camera)
##   • +X = Screen RIGHT
##   • -X = Screen LEFT (Towards Enemy)
##   • +Y = UP, -Y = DOWN
##
## Anatomy:
##   • Face & Chestplate: STRICTLY at +Z (facing camera)
##   • Sword: Held in hands at +Z = +0.22 (IN FRONT of chest), pointing UP-LEFT
##   • Cape: REAL 3D ArrayMesh anchored at -Z = -0.12 (BEHIND shoulders), hanging in -Z
## ═══════════════════════════════════════════════════════════════════════════

signal slash_impact

@export var facing_direction: float = 1.0 # 1.0 = Default (Facing Left toward Enemy), -1.0 = Facing Right
@export var turntable_yaw: float = 0.0
@export var turntable_pitch: float = 0.0

@export var equipped_sword: String = "sword_iron":
	set(val):
		equipped_sword = val
		_apply_sword_material()

@export var equipped_helmet: String = "helm_knight":
	set(val):
		equipped_helmet = val
		_apply_helmet_style()

# Materials
var mat_armor: StandardMaterial3D
var mat_emblem: StandardMaterial3D
var mat_joints: StandardMaterial3D
var mat_visor_eye: StandardMaterial3D
var mat_cape: StandardMaterial3D
var mat_sword_blade: StandardMaterial3D
var mat_sword_guard: StandardMaterial3D
var mat_sword_grip: StandardMaterial3D

# Rig Nodes
var root_pivot: Node3D
var pelvis: Node3D
var torso: Node3D
var chest: Node3D
var chest_emblem: MeshInstance3D
var neck: Node3D
var head: Node3D
var helmet_node: Node3D
var visor_mesh: MeshInstance3D
var eye_left_mesh: MeshInstance3D
var eye_right_mesh: MeshInstance3D
var crest_mesh: MeshInstance3D

# Limbs
var shoulder_left: Node3D
var arm_left: Node3D
var forearm_left: Node3D
var hand_left: Node3D

var shoulder_right: Node3D
var arm_right: Node3D
var forearm_right: Node3D
var hand_right: Node3D

var hip_left: Node3D
var leg_left: Node3D
var shin_left: Node3D
var foot_left: Node3D

var hip_right: Node3D
var leg_right: Node3D
var shin_right: Node3D
var foot_right: Node3D

# Weapon & Cape
var sword_pivot: Node3D
var sword_blade_mesh: MeshInstance3D
var cape_mesh_instance: MeshInstance3D

# Cape Cloth Physics Grid (6 columns x 8 rows)
const CAPE_COLS: int = 6
const CAPE_ROWS: int = 8
const CAPE_WIDTH: float = 0.76
const CAPE_LENGTH: float = 1.15
var cape_pts: Array = []
var cape_prev: Array = []

# Animation State Machine
enum AnimState { IDLE, WINDUP, SLASH, RECOVER, HURT, VICTORY }
var current_anim: AnimState = AnimState.IDLE
var _anim_t: float = 0.0
var _clock: float = 0.0
var _impact_triggered: bool = false


func _ready() -> void:
	_init_materials()
	_build_rig()
	_init_cape()
	_apply_sword_material()
	_apply_helmet_style()


func _process(delta: float) -> void:
	_clock += delta
	_update_turntable(delta)
	_update_animation(delta)
	_simulate_cape(delta)
	_update_cape_3d_mesh()


# ---------------------------------------------------------------------------
#  MATERIALS
# ---------------------------------------------------------------------------
func _init_materials() -> void:
	mat_armor = StandardMaterial3D.new()
	mat_armor.albedo_color = Color("#29b6f6")
	mat_armor.metallic = 0.75
	mat_armor.roughness = 0.30
	mat_armor.emission_enabled = true
	mat_armor.emission = Color("#0288d1")
	mat_armor.emission_energy_multiplier = 0.35

	mat_emblem = StandardMaterial3D.new()
	mat_emblem.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_emblem.albedo_color = Color("#00ffff")

	mat_joints = StandardMaterial3D.new()
	mat_joints.albedo_color = Color("#1e293b")
	mat_joints.metallic = 0.50
	mat_joints.roughness = 0.50

	mat_visor_eye = StandardMaterial3D.new()
	mat_visor_eye.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_visor_eye.albedo_color = Color.WHITE

	# Double-sided shaded cloth cape material
	mat_cape = StandardMaterial3D.new()
	mat_cape.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat_cape.albedo_color = Color("#7b1fa2")
	mat_cape.roughness = 0.65
	mat_cape.emission_enabled = true
	mat_cape.emission = Color("#4a148c")
	mat_cape.emission_energy_multiplier = 0.40

	mat_sword_blade = StandardMaterial3D.new()
	mat_sword_blade.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat_sword_blade.albedo_color = Color("#e0f7fa")
	mat_sword_blade.metallic = 0.98
	mat_sword_blade.roughness = 0.08
	mat_sword_blade.emission_enabled = true
	mat_sword_blade.emission = Color("#00e5ff")
	mat_sword_blade.emission_energy_multiplier = 2.5

	mat_sword_guard = StandardMaterial3D.new()
	mat_sword_guard.albedo_color = Color("#ffd600")
	mat_sword_guard.metallic = 0.92
	mat_sword_guard.emission_enabled = true
	mat_sword_guard.emission = Color("#ff8f00")
	mat_sword_guard.emission_energy_multiplier = 0.5

	mat_sword_grip = StandardMaterial3D.new()
	mat_sword_grip.albedo_color = Color("#37474f")


# ---------------------------------------------------------------------------
#  RIG CONSTRUCTION (Unmistakable Front Facing Camera +Z)
# ---------------------------------------------------------------------------
func _build_rig() -> void:
	root_pivot = Node3D.new()
	root_pivot.name = "RootPivot"
	add_child(root_pivot)

	# 1. Pelvis & Belt (Fills lower torso / hips)
	pelvis = Node3D.new()
	pelvis.name = "Pelvis"
	pelvis.position = Vector3(0, 0.90, 0)
	root_pivot.add_child(pelvis)
	_create_joint_sphere(pelvis, 0.13, mat_joints)
	# Armored Belt & Faulds Plate
	_create_box_mesh(pelvis, Vector3(0, 0.04, 0.0), Vector3(0.38, 0.14, 0.22), mat_armor)
	_create_box_mesh(pelvis, Vector3(0, 0.06, 0.01), Vector3(0.40, 0.06, 0.24), mat_sword_guard) # Golden belt trim!

	# 2. Torso (Abdomen / Cuirass - Fills middle body gap!)
	torso = Node3D.new()
	torso.name = "Torso"
	torso.position = Vector3(0, 0.16, 0)
	pelvis.add_child(torso)
	# Armored Abdominal Plate
	_create_box_mesh(torso, Vector3(0, 0.07, 0.0), Vector3(0.35, 0.18, 0.21), mat_armor)
	_create_cylinder_mesh(torso, Vector3(0, 0.07, 0), 0.10, 0.18, mat_joints)

	# 3. Chest (Front is at +Z = +0.11, Back is at -Z = -0.11)
	chest = Node3D.new()
	chest.name = "Chest"
	chest.position = Vector3(0, 0.24, 0)
	torso.add_child(chest)

	# Main chestplate box
	_create_box_mesh(chest, Vector3(0, 0.08, 0.0), Vector3(0.42, 0.26, 0.22), mat_armor)

	# Pauldrons (Shoulder guards)
	_create_box_mesh(chest, Vector3(-0.25, 0.15, 0.0), Vector3(0.16, 0.12, 0.18), mat_armor)
	_create_box_mesh(chest, Vector3(0.25, 0.15, 0.0), Vector3(0.16, 0.12, 0.18), mat_armor)

	# Front Chestplate Glowing Emblem (Facing +Z towards Camera!)
	chest_emblem = MeshInstance3D.new()
	var emblem_box = BoxMesh.new()
	emblem_box.size = Vector3(0.16, 0.16, 0.03)
	chest_emblem.mesh = emblem_box
	chest_emblem.position = Vector3(0, 0.08, 0.12) # PROTRUDES ON FRONT FACE (+Z)
	chest_emblem.material_override = mat_emblem
	chest.add_child(chest_emblem)

	# 4. Neck & Head
	neck = Node3D.new()
	neck.name = "Neck"
	neck.position = Vector3(0, 0.22, 0)
	chest.add_child(neck)
	_create_cylinder_mesh(neck, Vector3(0, 0.05, 0), 0.07, 0.10, mat_joints)

	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.16, 0)
	neck.add_child(head)

	# Helmet Dome (Head Center)
	helmet_node = Node3D.new()
	helmet_node.name = "Helmet"
	head.add_child(helmet_node)
	_create_joint_sphere(helmet_node, 0.18, mat_armor, Vector3(0, 0.02, 0.0))

	# Helmet Visor Slit (On FRONT face at +Z = +0.14)
	visor_mesh = MeshInstance3D.new()
	var visor_box = BoxMesh.new()
	visor_box.size = Vector3(0.22, 0.05, 0.06)
	visor_mesh.mesh = visor_box
	visor_mesh.position = Vector3(0, 0.02, 0.14) # STRICTLY ON FRONT FACE
	visor_mesh.material_override = mat_joints
	helmet_node.add_child(visor_mesh)

	# Glowing White Visor Eyes (On FRONT face at +Z = +0.17)
	eye_left_mesh = MeshInstance3D.new()
	var eye_box_l = BoxMesh.new()
	eye_box_l.size = Vector3(0.045, 0.03, 0.02)
	eye_left_mesh.mesh = eye_box_l
	eye_left_mesh.position = Vector3(-0.055, 0.02, 0.17)
	eye_left_mesh.material_override = mat_visor_eye
	helmet_node.add_child(eye_left_mesh)

	eye_right_mesh = MeshInstance3D.new()
	var eye_box_r = BoxMesh.new()
	eye_box_r.size = Vector3(0.045, 0.03, 0.02)
	eye_right_mesh.mesh = eye_box_r
	eye_right_mesh.position = Vector3(0.055, 0.02, 0.17)
	eye_right_mesh.material_override = mat_visor_eye
	helmet_node.add_child(eye_right_mesh)

	# Golden Crest Plume (Top of helmet)
	crest_mesh = MeshInstance3D.new()
	var crest_box = BoxMesh.new()
	crest_box.size = Vector3(0.035, 0.16, 0.32)
	crest_mesh.mesh = crest_box
	crest_mesh.position = Vector3(0, 0.20, -0.02)
	crest_mesh.material_override = mat_sword_guard
	helmet_node.add_child(crest_mesh)

	# 5. FORWARD LEFT ARM (Holds Sword in FRONT at +Z!)
	shoulder_left = Node3D.new()
	shoulder_left.name = "ShoulderL"
	shoulder_left.position = Vector3(-0.25, 0.14, 0.0)
	chest.add_child(shoulder_left)
	_create_joint_sphere(shoulder_left, 0.085, mat_joints)

	arm_left = Node3D.new()
	arm_left.name = "ArmL"
	shoulder_left.add_child(arm_left)
	_create_cylinder_mesh(arm_left, Vector3(0, -0.14, 0), 0.07, 0.28, mat_armor)

	forearm_left = Node3D.new()
	forearm_left.name = "ForearmL"
	forearm_left.position = Vector3(0, -0.28, 0)
	arm_left.add_child(forearm_left)
	_create_joint_sphere(forearm_left, 0.075, mat_joints)
	_create_cylinder_mesh(forearm_left, Vector3(0, -0.12, 0), 0.06, 0.24, mat_armor)

	hand_left = Node3D.new()
	hand_left.name = "HandL"
	hand_left.position = Vector3(0, -0.24, 0)
	forearm_left.add_child(hand_left)
	_create_joint_sphere(hand_left, 0.07, mat_sword_guard) # Golden gauntlet!

	# Sword attached directly to Forward Hand at +Z (IN FRONT OF CHEST!)
	sword_pivot = Node3D.new()
	sword_pivot.name = "SwordPivot"
	sword_pivot.position = Vector3(0, 0, 0.02)
	hand_left.add_child(sword_pivot)
	_build_sword(sword_pivot)

	# 6. BACK RIGHT ARM (Natural combat ready guard)
	shoulder_right = Node3D.new()
	shoulder_right.name = "ShoulderR"
	shoulder_right.position = Vector3(0.25, 0.14, 0.0)
	chest.add_child(shoulder_right)
	_create_joint_sphere(shoulder_right, 0.085, mat_joints)

	arm_right = Node3D.new()
	arm_right.name = "ArmR"
	shoulder_right.add_child(arm_right)
	_create_cylinder_mesh(arm_right, Vector3(0, -0.14, 0), 0.07, 0.28, mat_armor)

	forearm_right = Node3D.new()
	forearm_right.name = "ForearmR"
	forearm_right.position = Vector3(0, -0.28, 0)
	arm_right.add_child(forearm_right)
	_create_joint_sphere(forearm_right, 0.075, mat_joints)
	_create_cylinder_mesh(forearm_right, Vector3(0, -0.12, 0), 0.06, 0.24, mat_armor)

	hand_right = Node3D.new()
	hand_right.name = "HandR"
	hand_right.position = Vector3(0, -0.24, 0)
	forearm_right.add_child(hand_right)
	_create_joint_sphere(hand_right, 0.07, mat_sword_guard) # Golden gauntlet!

	# 7. LEGS
	hip_left = Node3D.new()
	hip_left.name = "HipL"
	hip_left.position = Vector3(-0.14, -0.04, 0.0)
	pelvis.add_child(hip_left)
	_create_joint_sphere(hip_left, 0.08, mat_joints)

	leg_left = Node3D.new()
	leg_left.name = "ThighL"
	hip_left.add_child(leg_left)
	_create_cylinder_mesh(leg_left, Vector3(0, -0.20, 0), 0.08, 0.40, mat_armor)

	shin_left = Node3D.new()
	shin_left.name = "ShinL"
	shin_left.position = Vector3(0, -0.40, 0)
	leg_left.add_child(shin_left)
	_create_joint_sphere(shin_left, 0.075, mat_joints)
	_create_cylinder_mesh(shin_left, Vector3(0, -0.20, 0), 0.07, 0.40, mat_armor)

	foot_left = Node3D.new()
	foot_left.name = "FootL"
	foot_left.position = Vector3(0, -0.40, 0)
	shin_left.add_child(foot_left)
	_create_box_mesh(foot_left, Vector3(0, -0.04, 0.06), Vector3(0.12, 0.07, 0.20), mat_joints)

	hip_right = Node3D.new()
	hip_right.name = "HipR"
	hip_right.position = Vector3(0.14, -0.04, 0.0)
	pelvis.add_child(hip_right)
	_create_joint_sphere(hip_right, 0.08, mat_joints)

	leg_right = Node3D.new()
	leg_right.name = "ThighR"
	hip_right.add_child(leg_right)
	_create_cylinder_mesh(leg_right, Vector3(0, -0.20, 0), 0.08, 0.40, mat_armor)

	shin_right = Node3D.new()
	shin_right.name = "ShinR"
	shin_right.position = Vector3(0, -0.40, 0)
	leg_right.add_child(shin_right)
	_create_joint_sphere(shin_right, 0.075, mat_joints)
	_create_cylinder_mesh(shin_right, Vector3(0, -0.20, 0), 0.07, 0.40, mat_armor)

	foot_right = Node3D.new()
	foot_right.name = "FootR"
	foot_right.position = Vector3(0, -0.40, 0)
	shin_right.add_child(foot_right)
	_create_box_mesh(foot_right, Vector3(0, -0.04, 0.06), Vector3(0.12, 0.07, 0.20), mat_joints)


# ---------------------------------------------------------------------------
#  SWORD
# ---------------------------------------------------------------------------
func _build_sword(parent: Node3D) -> void:
	_create_joint_sphere(parent, 0.06, mat_sword_guard, Vector3(0, -0.08, 0))
	_create_cylinder_mesh(parent, Vector3(0, 0.06, 0), 0.03, 0.20, mat_sword_grip)
	_create_box_mesh(parent, Vector3(0, 0.18, 0), Vector3(0.40, 0.06, 0.06), mat_sword_guard)

	sword_blade_mesh = MeshInstance3D.new()
	sword_blade_mesh.name = "SwordBlade"
	var blade_box = BoxMesh.new()
	blade_box.size = Vector3(0.11, 1.15, 0.03)
	sword_blade_mesh.mesh = blade_box
	sword_blade_mesh.position = Vector3(0, 0.76, 0)
	sword_blade_mesh.material_override = mat_sword_blade
	parent.add_child(sword_blade_mesh)


# ---------------------------------------------------------------------------
#  REAL PHYSICAL 3D CAPE MESH (Deep in -Z, strictly behind the body)
# ---------------------------------------------------------------------------
func _init_cape() -> void:
	cape_pts.clear()
	cape_prev.clear()

	var step_x = CAPE_WIDTH / float(CAPE_COLS - 1)
	var step_y = CAPE_LENGTH / float(CAPE_ROWS - 1)

	for r in range(CAPE_ROWS):
		var row_pts: Array = []
		var row_prev: Array = []
		for c in range(CAPE_COLS):
			var x = (c - (CAPE_COLS - 1) * 0.5) * step_x * 0.7 + 0.10
			var y = 1.35 - r * step_y
			var z = -0.22 - r * 0.03 # STRICTLY IN -Z (BEHIND BODY)
			row_pts.append(Vector3(x, y, z))
			row_prev.append(Vector3(x, y, z))
		cape_pts.append(row_pts)
		cape_prev.append(row_prev)

	cape_mesh_instance = MeshInstance3D.new()
	cape_mesh_instance.name = "PhysicalCapeMesh"
	cape_mesh_instance.material_override = mat_cape
	root_pivot.add_child(cape_mesh_instance)


func _simulate_cape(delta: float) -> void:
	if cape_pts.is_empty():
		return

	# Top row anchored strictly at the BACK of shoulders in local space
	# Chest center is at Z=0. Back is at -Z.
	var chest_world = chest.global_position
	var back_dir = -chest.global_transform.basis.z * 0.22 # DEEP in -Z!
	var right_dir = chest.global_transform.basis.x

	var step_x = CAPE_WIDTH / float(CAPE_COLS - 1)
	for c in range(CAPE_COLS):
		var offset_x = (c - (CAPE_COLS - 1) * 0.5) * step_x * 0.65
		var anchor_pos = chest_world + back_dir + right_dir * offset_x
		cape_pts[0][c] = root_pivot.to_local(anchor_pos)

	# Wind blows towards the RIGHT (+X) and slightly BACK (-Z)
	var wind_dir = Vector3(
		0.40 + sin(_clock * 2.5) * 0.15,
		-0.10,
		-0.35 + sin(_clock * 3.2) * 0.15
	)

	if current_anim == AnimState.SLASH:
		wind_dir.x += 1.4
		wind_dir.z -= 0.6

	# Verlet cloth relaxation
	for r in range(1, CAPE_ROWS):
		var row_weight: float = float(r) / float(CAPE_ROWS - 1)
		for c in range(CAPE_COLS):
			var curr: Vector3 = cape_pts[r][c]
			var prev: Vector3 = cape_prev[r][c]
			var vel: Vector3 = (curr - prev) * 0.82

			var wave_z = sin(_clock * 4.0 - r * 0.8 + c * 0.5) * 0.012 * row_weight
			var wave_x = cos(_clock * 3.0 - r * 0.6) * 0.010 * row_weight

			var gravity = Vector3(0, -3.5 * delta * row_weight, 0)
			var wind_force = wind_dir * delta * (0.8 + row_weight * 1.4)

			var next_pos: Vector3 = curr + vel + gravity + wind_force + Vector3(wave_x, 0, wave_z)
			cape_prev[r][c] = curr
			cape_pts[r][c] = next_pos

	# Distance constraints
	var step_y = CAPE_LENGTH / float(CAPE_ROWS - 1)
	for iter in range(2):
		for r in range(1, CAPE_ROWS):
			for c in range(CAPE_COLS):
				var p_above: Vector3 = cape_pts[r - 1][c]
				var p_curr: Vector3 = cape_pts[r][c]
				var diff = p_curr - p_above
				var dist = diff.length()
				if dist > 0.0001:
					var correction = diff * ((dist - step_y) / dist) * 0.75
					cape_pts[r][c] -= correction


func _update_cape_3d_mesh() -> void:
	if not cape_mesh_instance or cape_pts.is_empty():
		return

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(mat_cape)

	for r in range(CAPE_ROWS - 1):
		for c in range(CAPE_COLS - 1):
			var v00 = cape_pts[r][c]
			var v10 = cape_pts[r][c + 1]
			var v11 = cape_pts[r + 1][c + 1]
			var v01 = cape_pts[r + 1][c]

			var uv00 = Vector2(float(c) / float(CAPE_COLS - 1), float(r) / float(CAPE_ROWS - 1))
			var uv10 = Vector2(float(c + 1) / float(CAPE_COLS - 1), float(r) / float(CAPE_ROWS - 1))
			var uv11 = Vector2(float(c + 1) / float(CAPE_COLS - 1), float(r + 1) / float(CAPE_ROWS - 1))
			var uv01 = Vector2(float(c) / float(CAPE_COLS - 1), float(r + 1) / float(CAPE_ROWS - 1))

			# Triangle 1
			st.set_uv(uv00); st.add_vertex(v00)
			st.set_uv(uv10); st.add_vertex(v10)
			st.set_uv(uv01); st.add_vertex(v01)

			# Triangle 2
			st.set_uv(uv10); st.add_vertex(v10)
			st.set_uv(uv11); st.add_vertex(v11)
			st.set_uv(uv01); st.add_vertex(v01)

	st.generate_normals()
	cape_mesh_instance.mesh = st.commit()


# ---------------------------------------------------------------------------
#  ANIMATION POSES (Facing Camera, Sword in front-left, Cape behind)
# ---------------------------------------------------------------------------
func _update_animation(delta: float) -> void:
	_anim_t += delta

	match current_anim:
		AnimState.IDLE:
			_pose_idle(delta)
		AnimState.WINDUP:
			_pose_windup(delta)
		AnimState.SLASH:
			_pose_slash(delta)
		AnimState.RECOVER:
			_pose_recover(delta)
		AnimState.HURT:
			_pose_hurt(delta)
		AnimState.VICTORY:
			_pose_victory(delta)


func _pose_idle(_delta: float) -> void:
	var breath = sin(_clock * 2.4)
	var sway = cos(_clock * 1.6)

	# Torso & Chest: Facing viewer (+Z), angled 15 degrees toward enemy (-X)
	torso.position.y = 0.15 + breath * 0.015
	torso.rotation_degrees = Vector3(breath * 1.2, -15.0 + sway * 1.2, 0)
	chest.rotation_degrees = Vector3(breath * 1.0, -4.0, 0)

	# Head: Faces camera & enemy alertly!
	head.rotation_degrees = Vector3(-breath * 1.0, -20.0 - sway * 1.5, 0)

	# Legs: Balanced stance
	hip_left.rotation_degrees = Vector3(5.0, -10.0, -5.0)
	shin_left.rotation_degrees = Vector3(-5.0, 0, 0)
	hip_right.rotation_degrees = Vector3(-3.0, 10.0, 6.0)
	shin_right.rotation_degrees = Vector3(5.0, 0, 0)

	# FORWARD LEFT ARM: Holds sword hilt in front of chest (+Z)
	shoulder_left.rotation_degrees = Vector3(-12.0 + breath * 1.2, -10.0, -8.0)
	arm_left.rotation_degrees = Vector3(-20.0, 0, 0)
	forearm_left.rotation_degrees = Vector3(-55.0, 0, 0)

	# SWORD: Blade points UP-LEFT towards enemy in front of chest!
	sword_pivot.rotation_degrees = Vector3(72.0 + breath * 1.8, -10.0, 30.0)

	# BACK RIGHT ARM: Clean heroic off-hand combat guard (ready fist at waist)
	shoulder_right.rotation_degrees = Vector3(5.0 + breath * 1.0, 5.0, 10.0)
	arm_right.rotation_degrees = Vector3(-15.0, 0, 0)
	forearm_right.rotation_degrees = Vector3(-70.0, -15.0, 0)


func _pose_windup(_delta: float) -> void:
	var p = clampf(_anim_t / 0.16, 0.0, 1.0)
	var ease_p = ease(p, -2.0)

	# 1. Torso anchored (NO translation slide!)
	torso.position.x = 0.0
	pelvis.position.y = lerpf(0.90, 0.87, ease_p)

	# 2. Coiled back stance: weight shifts to back foot
	hip_left.rotation_degrees = Vector3(lerpf(5.0, 12.0, ease_p), -10.0, -5.0)
	shin_left.rotation_degrees = Vector3(lerpf(-5.0, -12.0, ease_p), 0, 0)
	hip_right.rotation_degrees = Vector3(lerpf(-3.0, -18.0, ease_p), 12.0, 6.0)
	shin_right.rotation_degrees = Vector3(lerpf(5.0, 20.0, ease_p), 0, 0)

	# 3. Torso & Chest coil back to store elastic energy
	torso.rotation_degrees = Vector3(lerpf(0.0, -6.0, ease_p), lerpf(-15.0, 20.0, ease_p), 0)
	chest.rotation_degrees = Vector3(lerpf(0.0, -4.0, ease_p), lerpf(-4.0, 16.0, ease_p), 0)
	head.rotation_degrees = Vector3(0, lerpf(-20.0, -32.0, ease_p), 0)

	# 4. Sword raised high overhead / over right shoulder in high guard
	shoulder_left.rotation_degrees = Vector3(lerpf(-12.0, -65.0, ease_p), lerpf(-10.0, 25.0, ease_p), lerpf(-8.0, 20.0, ease_p))
	arm_left.rotation_degrees = Vector3(lerpf(-20.0, -45.0, ease_p), 0, 0)
	forearm_left.rotation_degrees = Vector3(lerpf(-55.0, -75.0, ease_p), 0, 0)
	sword_pivot.rotation_degrees = Vector3(lerpf(72.0, 115.0, ease_p), lerpf(-10.0, 18.0, ease_p), lerpf(30.0, -18.0, ease_p))

	# 5. Right arm raised for counter-balance
	shoulder_right.rotation_degrees = Vector3(lerpf(5.0, -15.0, ease_p), lerpf(5.0, -15.0, ease_p), 10.0)
	arm_right.rotation_degrees = Vector3(lerpf(-15.0, -25.0, ease_p), 0, 0)
	forearm_right.rotation_degrees = Vector3(lerpf(-70.0, -80.0, ease_p), -15.0, 0)


func _pose_slash(_delta: float) -> void:
	var duration: float = 0.28
	var p = clampf(_anim_t / duration, 0.0, 1.0)
	# Fast explosive acceleration in first 40%, smooth follow-through in remaining 60%
	var swing_p = ease(p, 0.40)

	# 1. Torso strictly anchored (ZERO translation sliding!)
	torso.position.x = 0.0

	# 2. Dynamic Combat Lunge: Pelvis drops, front knee drives forward
	pelvis.position.y = lerpf(0.87, 0.79, swing_p)
	hip_left.rotation_degrees = Vector3(lerpf(12.0, -25.0, swing_p), -10.0, -5.0)
	shin_left.rotation_degrees = Vector3(lerpf(-12.0, 42.0, swing_p), 0, 0) # Deep front knee bend!
	hip_right.rotation_degrees = Vector3(lerpf(-18.0, 20.0, swing_p), 12.0, 6.0)
	shin_right.rotation_degrees = Vector3(lerpf(20.0, 5.0, swing_p), 0, 0) # Back leg extends

	# 3. Explosive Torso Torque driving the slash forward-left
	torso.rotation_degrees = Vector3(lerpf(-6.0, 14.0, swing_p), lerpf(20.0, -34.0, swing_p), 0)
	chest.rotation_degrees = Vector3(lerpf(-4.0, 10.0, swing_p), lerpf(16.0, -20.0, swing_p), 0)
	head.rotation_degrees = Vector3(0, lerpf(-32.0, -20.0, swing_p), 0)

	# 4. Wide Diagonal Cleave Arc from High-Right to Low-Left across enemy
	shoulder_left.rotation_degrees = Vector3(lerpf(-65.0, -32.0, swing_p), lerpf(25.0, -22.0, swing_p), lerpf(20.0, -10.0, swing_p))
	arm_left.rotation_degrees = Vector3(lerpf(-45.0, -22.0, swing_p), 0, 0)
	forearm_left.rotation_degrees = Vector3(lerpf(-75.0, -40.0, swing_p), 0, 0) # Forearm reaches forward-left
	sword_pivot.rotation_degrees = Vector3(lerpf(115.0, 22.0, swing_p), lerpf(18.0, -20.0, swing_p), lerpf(-18.0, 52.0, swing_p))

	# 5. Right arm swings back for athletic balance
	shoulder_right.rotation_degrees = Vector3(lerpf(-15.0, -25.0, swing_p), lerpf(-15.0, 30.0, swing_p), 10.0)
	arm_right.rotation_degrees = Vector3(lerpf(-25.0, -10.0, swing_p), 0, 0)
	forearm_right.rotation_degrees = Vector3(lerpf(-80.0, -40.0, swing_p), 0, 0)

	# 6. Strike Impact triggered at peak velocity
	if p >= 0.40 and not _impact_triggered:
		_impact_triggered = true
		slash_impact.emit()

	if p >= 1.0:
		play_recover()


func _pose_recover(_delta: float) -> void:
	var duration: float = 0.16
	var p = clampf(_anim_t / duration, 0.0, 1.0)
	var ease_p = ease(p, 2.0)

	torso.position.x = 0.0
	pelvis.position.y = lerpf(0.77, 0.90, ease_p)

	hip_left.rotation_degrees = hip_left.rotation_degrees.lerp(Vector3(5.0, -10.0, -5.0), ease_p)
	shin_left.rotation_degrees = shin_left.rotation_degrees.lerp(Vector3(-5.0, 0, 0), ease_p)
	hip_right.rotation_degrees = hip_right.rotation_degrees.lerp(Vector3(-3.0, 10.0, 6.0), ease_p)
	shin_right.rotation_degrees = shin_right.rotation_degrees.lerp(Vector3(5.0, 0, 0), ease_p)

	torso.rotation_degrees = torso.rotation_degrees.lerp(Vector3(0, -15.0, 0), ease_p)
	chest.rotation_degrees = chest.rotation_degrees.lerp(Vector3(0, -4.0, 0), ease_p)
	head.rotation_degrees = head.rotation_degrees.lerp(Vector3(0, -20.0, 0), ease_p)

	shoulder_left.rotation_degrees = shoulder_left.rotation_degrees.lerp(Vector3(-12.0, -10.0, -8.0), ease_p)
	arm_left.rotation_degrees = arm_left.rotation_degrees.lerp(Vector3(-20.0, 0, 0), ease_p)
	forearm_left.rotation_degrees = forearm_left.rotation_degrees.lerp(Vector3(-55.0, 0, 0), ease_p)
	sword_pivot.rotation_degrees = sword_pivot.rotation_degrees.lerp(Vector3(72.0, -10.0, 30.0), ease_p)

	shoulder_right.rotation_degrees = shoulder_right.rotation_degrees.lerp(Vector3(5.0, 5.0, 10.0), ease_p)
	arm_right.rotation_degrees = arm_right.rotation_degrees.lerp(Vector3(-15.0, 0, 0), ease_p)
	forearm_right.rotation_degrees = forearm_right.rotation_degrees.lerp(Vector3(-70.0, -15.0, 0), ease_p)

	if p >= 1.0:
		current_anim = AnimState.IDLE
		_anim_t = 0.0


func _pose_hurt(_delta: float) -> void:
	var p = clampf(_anim_t / 0.22, 0.0, 1.0)
	var recoil = sin(p * PI)

	torso.position.x = 0.18 * recoil
	torso.rotation_degrees = Vector3(-12.0 * recoil, -8.0, 0)
	head.rotation_degrees = Vector3(16.0 * recoil, -12.0, 0)

	if p >= 1.0:
		current_anim = AnimState.IDLE
		_anim_t = 0.0


func _pose_victory(_delta: float) -> void:
	var p = clampf(_anim_t / 0.35, 0.0, 1.0)
	var ease_p = ease(p, -2.0)

	torso.rotation_degrees = Vector3(-4.0 * ease_p, 0, 0)
	head.rotation_degrees = Vector3(16.0 * ease_p, 0, 0)
	shoulder_left.rotation_degrees = Vector3(-105.0 * ease_p, -15.0, 12.0)
	sword_pivot.rotation_degrees = Vector3(12.0 * ease_p, 0, 0)


func play_idle() -> void:
	current_anim = AnimState.IDLE
	_anim_t = 0.0

func play_windup() -> void:
	current_anim = AnimState.WINDUP
	_anim_t = 0.0

func play_slash() -> void:
	current_anim = AnimState.SLASH
	_anim_t = 0.0
	_impact_triggered = false

func play_recover() -> void:
	current_anim = AnimState.RECOVER
	_anim_t = 0.0

func play_hurt() -> void:
	current_anim = AnimState.HURT
	_anim_t = 0.0

func play_victory() -> void:
	current_anim = AnimState.VICTORY
	_anim_t = 0.0


func _update_turntable(_delta: float) -> void:
	if not root_pivot:
		return
	# facing_direction <= 0 means Knight in battle faces LEFT (0 deg base yaw)
	# facing_direction > 0 means Knight faces RIGHT (PI base yaw)
	var base_yaw: float = 0.0 if facing_direction <= 0 else PI
	root_pivot.rotation = Vector3(turntable_pitch, turntable_yaw + base_yaw, 0)
	root_pivot.scale = Vector3.ONE


func apply_cosmetics(dict: Dictionary) -> void:
	if dict.has("sword"):
		equipped_sword = dict["sword"]
	if dict.has("helmet"):
		equipped_helmet = dict["helmet"]


func _apply_sword_material() -> void:
	if not mat_sword_blade:
		return
	match equipped_sword:
		"sword_flame":
			mat_sword_blade.albedo_color = Color("#ff7043")
			mat_sword_blade.emission = Color("#ff3d00")
			mat_sword_blade.emission_energy_multiplier = 3.0
			mat_sword_guard.albedo_color = Color("#d84315")
		"sword_frost":
			mat_sword_blade.albedo_color = Color("#e0f7fa")
			mat_sword_blade.emission = Color("#00e5ff")
			mat_sword_blade.emission_energy_multiplier = 2.5
			mat_sword_guard.albedo_color = Color("#00acc1")
		"sword_gold":
			mat_sword_blade.albedo_color = Color("#fff59d")
			mat_sword_blade.emission = Color("#ffd600")
			mat_sword_blade.emission_energy_multiplier = 2.0
			mat_sword_guard.albedo_color = Color("#ffb300")
		"sword_lightsaber":
			mat_sword_blade.albedo_color = Color.WHITE
			mat_sword_blade.emission = Color("#00ffcc")
			mat_sword_blade.emission_energy_multiplier = 4.0
			mat_sword_guard.albedo_color = Color("#37474f")
		"sword_pan":
			mat_sword_blade.albedo_color = Color("#78909c")
			mat_sword_blade.emission = Color.BLACK
			mat_sword_blade.emission_energy_multiplier = 0.0
			mat_sword_guard.albedo_color = Color("#455a64")
		_:
			mat_sword_blade.albedo_color = Color("#e0f7fa")
			mat_sword_blade.emission = Color("#00b0ff")
			mat_sword_blade.emission_energy_multiplier = 1.6
			mat_sword_guard.albedo_color = Color("#ffd600")


func _apply_helmet_style() -> void:
	if not visor_mesh:
		return
	match equipped_helmet:
		"helm_dark":
			mat_armor.albedo_color = Color("#37474f")
			mat_visor_eye.albedo_color = Color("#ff1744")
		"helm_gold":
			mat_armor.albedo_color = Color("#ffd54f")
			mat_visor_eye.albedo_color = Color("#00e5ff")
		_:
			mat_armor.albedo_color = Color("#29b6f6")
			mat_visor_eye.albedo_color = Color.WHITE


# ---------------------------------------------------------------------------
#  WIREFRAME EXPORTS
# ---------------------------------------------------------------------------
func get_bone_lines() -> Array:
	var lines: Array = []

	# Torso Spine (Cyan)
	lines.append({"a": pelvis.global_position, "b": torso.global_position, "col": Color("#00e5ff")})
	lines.append({"a": torso.global_position, "b": chest.global_position, "col": Color("#00e5ff")})
	lines.append({"a": chest.global_position, "b": neck.global_position, "col": Color("#00e5ff")})
	lines.append({"a": neck.global_position, "b": head.global_position, "col": Color("#80deea")})

	# Shoulders
	lines.append({"a": chest.global_position, "b": shoulder_left.global_position, "col": Color("#ffd600")})
	lines.append({"a": chest.global_position, "b": shoulder_right.global_position, "col": Color("#ffd600")})

	# Left Arm (Forward Hand holding sword)
	lines.append({"a": shoulder_left.global_position, "b": forearm_left.global_position, "col": Color("#ffeb3b")})
	lines.append({"a": forearm_left.global_position, "b": hand_left.global_position, "col": Color("#fff59d")})

	# Right Arm (Back Hand supporting sword grip in front)
	lines.append({"a": shoulder_right.global_position, "b": forearm_right.global_position, "col": Color("#ffeb3b")})
	lines.append({"a": forearm_right.global_position, "b": hand_right.global_position, "col": Color("#fff59d")})

	# Sword (Pointing UP-LEFT towards enemy!)
	var pommel_pos = sword_pivot.to_global(Vector3(0, -0.08, 0))
	var guard_l = sword_pivot.to_global(Vector3(-0.20, 0.18, 0))
	var guard_r = sword_pivot.to_global(Vector3(0.20, 0.18, 0))
	var tip_pos = sword_pivot.to_global(Vector3(0, 1.35, 0))
	lines.append({"a": pommel_pos, "b": sword_pivot.to_global(Vector3(0, 0.18, 0)), "col": Color("#78909c")})
	lines.append({"a": guard_l, "b": guard_r, "col": Color("#ffd600")})
	lines.append({"a": sword_pivot.to_global(Vector3(0, 0.18, 0)), "b": tip_pos, "col": Color.WHITE})

	# Legs
	lines.append({"a": pelvis.global_position, "b": hip_left.global_position, "col": Color("#29b6f6")})
	lines.append({"a": hip_left.global_position, "b": shin_left.global_position, "col": Color("#1e88e5")})
	lines.append({"a": shin_left.global_position, "b": foot_left.global_position, "col": Color("#1565c0")})

	lines.append({"a": pelvis.global_position, "b": hip_right.global_position, "col": Color("#29b6f6")})
	lines.append({"a": hip_right.global_position, "b": shin_right.global_position, "col": Color("#1e88e5")})
	lines.append({"a": shin_right.global_position, "b": foot_right.global_position, "col": Color("#1565c0")})

	# Visor Eyes slit across face facing camera!
	lines.append({"a": eye_left_mesh.global_position, "b": eye_right_mesh.global_position, "col": Color("#00ffff")})

	return lines


func get_cape_lines() -> Array:
	var lines: Array = []
	for r in range(CAPE_ROWS):
		for c in range(CAPE_COLS):
			var p_curr = root_pivot.to_global(cape_pts[r][c])
			if c < CAPE_COLS - 1:
				var p_right = root_pivot.to_global(cape_pts[r][c + 1])
				lines.append({"a": p_curr, "b": p_right, "col": Color("#ab47bc", 0.55)})
			if r < CAPE_ROWS - 1:
				var p_down = root_pivot.to_global(cape_pts[r + 1][c])
				lines.append({"a": p_curr, "b": p_down, "col": Color("#ab47bc", 0.55)})
	return lines


func get_joint_points() -> Array:
	return [
		{"pos": head.global_position, "col": Color("#00ffff"), "radius": 7.0},
		{"pos": eye_left_mesh.global_position, "col": Color.WHITE, "radius": 2.5},
		{"pos": eye_right_mesh.global_position, "col": Color.WHITE, "radius": 2.5},
		{"pos": chest_emblem.global_position, "col": Color("#00ffff"), "radius": 4.5},
		{"pos": chest.global_position, "col": Color("#ffd600"), "radius": 6.0},
		{"pos": torso.global_position, "col": Color("#00e5ff"), "radius": 5.0},
		{"pos": pelvis.global_position, "col": Color("#00e5ff"), "radius": 5.0},
		{"pos": shoulder_left.global_position, "col": Color("#ffd600"), "radius": 4.5},
		{"pos": shoulder_right.global_position, "col": Color("#ffd600"), "radius": 4.5},
		{"pos": forearm_left.global_position, "col": Color("#ffeb3b"), "radius": 4.0},
		{"pos": forearm_right.global_position, "col": Color("#ffeb3b"), "radius": 4.0},
		{"pos": hand_left.global_position, "col": Color("#fff59d"), "radius": 4.0},
		{"pos": hand_right.global_position, "col": Color("#fff59d"), "radius": 4.0},
		{"pos": hip_left.global_position, "col": Color("#29b6f6"), "radius": 4.5},
		{"pos": hip_right.global_position, "col": Color("#29b6f6"), "radius": 4.5},
		{"pos": shin_left.global_position, "col": Color("#1e88e5"), "radius": 4.0},
		{"pos": shin_right.global_position, "col": Color("#1e88e5"), "radius": 4.0},
		{"pos": foot_left.global_position, "col": Color("#1565c0"), "radius": 3.5},
		{"pos": foot_right.global_position, "col": Color("#1565c0"), "radius": 3.5},
		{"pos": sword_pivot.to_global(Vector3(0, 1.35, 0)), "col": Color.WHITE, "radius": 4.0},
	]


# Helpers
func _create_joint_sphere(parent: Node3D, radius: float, mat: Material, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	mi.mesh = sphere
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _create_cylinder_mesh(parent: Node3D, pos: Vector3, radius: float, height: float, mat: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height
	cyl.radial_segments = 10
	mi.mesh = cyl
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _create_box_mesh(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi
