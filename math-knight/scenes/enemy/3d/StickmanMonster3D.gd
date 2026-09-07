class_name StickmanMonster3D
extends Node3D

## ═══════════════════════════════════════════════════════════════════════════
## StickmanMonster3D — True 3D Monster Rig for Math Knight
##
## Supports 4 Enemy Types:
##   • "goblin"   — Hunched green brute with spiked armor & heavy brute club
##   • "skeleton" — Bony undead skeleton with skull, broadsword & shield
##   • "slime"    — Squash-and-stretch gelatinous dome with inner math nucleus
##   • "boss"     — Massive armored warlord with horned crown, runic greatsword & cape
##
## Coordinate System Ground Truth:
##   • Monsters spawn on the RIGHT (+X) and face LEFT (-X) towards the Knight!
##   • Facing direction: +1.0 = Facing Left (Default), -1.0 = Facing Right
##   • +Z = Front (Facing Camera), -Z = Back
## ═══════════════════════════════════════════════════════════════════════════

signal attack_impact

@export_enum("goblin", "skeleton", "slime", "boss") var monster_type: String = "goblin":
	set(val):
		monster_type = val
		if is_inside_tree():
			_rebuild_monster()

@export var is_elite: bool = false:
	set(val):
		is_elite = val
		_apply_elite_style()

@export var facing_direction: float = 1.0: # 1.0 = Facing Left towards Knight
	set(val):
		facing_direction = val
		if root_pivot:
			root_pivot.rotation_degrees.y = 0.0 if facing_direction >= 0 else 180.0

# Animation States
enum AnimState { IDLE, WALK, ATTACK, HURT, DEFEATED }
var current_anim: AnimState = AnimState.IDLE
var _anim_t: float = 0.0
var _clock: float = 0.0
var _impact_triggered: bool = false

# Rig Hierarchy
var root_pivot: Node3D
var pelvis: Node3D
var torso: Node3D
var chest: Node3D
var neck: Node3D
var head: Node3D
var weapon_pivot: Node3D
var shield_pivot: Node3D

var shoulder_l: Node3D
var arm_l: Node3D
var forearm_l: Node3D
var hand_l: Node3D

var shoulder_r: Node3D
var arm_r: Node3D
var forearm_r: Node3D
var hand_r: Node3D

var hip_l: Node3D
var leg_l: Node3D
var shin_l: Node3D
var foot_l: Node3D

var hip_r: Node3D
var leg_r: Node3D
var shin_r: Node3D
var foot_r: Node3D

# Slime specific
var slime_blob: MeshInstance3D
var slime_nucleus: MeshInstance3D
var slime_eye_l: MeshInstance3D
var slime_eye_r: MeshInstance3D

# Boss specific
var boss_cape_mesh: MeshInstance3D
var cape_pts: Array = []
var cape_prev: Array = []

# Shared Materials
var mat_skin: StandardMaterial3D
var mat_armor: StandardMaterial3D
var mat_bone: StandardMaterial3D
var mat_metal: StandardMaterial3D
var mat_wood: StandardMaterial3D
var mat_gold: StandardMaterial3D
var mat_eye: StandardMaterial3D
var mat_weapon_glow: StandardMaterial3D
var mat_cape: StandardMaterial3D


func _ready() -> void:
	_init_materials()
	_rebuild_monster()


func _process(delta: float) -> void:
	_clock += delta
	_update_animation(delta)


# ---------------------------------------------------------------------------
#  MATERIALS
# ---------------------------------------------------------------------------
func _init_materials() -> void:
	mat_skin = StandardMaterial3D.new()
	mat_skin.albedo_color = Color("#43a047") # Goblin green
	mat_skin.roughness = 0.65

	mat_armor = StandardMaterial3D.new()
	mat_armor.albedo_color = Color("#37474f") # Dark rusted iron
	mat_armor.metallic = 0.8
	mat_armor.roughness = 0.35

	mat_bone = StandardMaterial3D.new()
	mat_bone.albedo_color = Color("#eceff1") # Bleached bone
	mat_bone.roughness = 0.55

	mat_metal = StandardMaterial3D.new()
	mat_metal.albedo_color = Color("#78909c")
	mat_metal.metallic = 0.9
	mat_metal.roughness = 0.2

	mat_wood = StandardMaterial3D.new()
	mat_wood.albedo_color = Color("#4e342e")
	mat_wood.roughness = 0.8

	mat_gold = StandardMaterial3D.new()
	mat_gold.albedo_color = Color("#ffd600")
	mat_gold.metallic = 0.95
	mat_gold.emission_enabled = true
	mat_gold.emission = Color("#ff8f00")
	mat_gold.emission_energy_multiplier = 0.4

	mat_eye = StandardMaterial3D.new()
	mat_eye.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_eye.albedo_color = Color("#ff1744") # Burning red/orange

	mat_weapon_glow = StandardMaterial3D.new()
	mat_weapon_glow.albedo_color = Color("#ff5722")
	mat_weapon_glow.emission_enabled = true
	mat_weapon_glow.emission = Color("#ff3d00")
	mat_weapon_glow.emission_energy_multiplier = 2.0

	mat_cape = StandardMaterial3D.new()
	mat_cape.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat_cape.albedo_color = Color("#880e4f") # Warlord crimson
	mat_cape.roughness = 0.7


func _apply_elite_style() -> void:
	if not is_inside_tree() or not root_pivot:
		return
	var s: float = 1.22 if is_elite else 1.0
	root_pivot.scale = Vector3(s, s, s)
	if is_elite:
		mat_eye.albedo_color = Color("#ff007f") # Hot neon pink


# ---------------------------------------------------------------------------
#  MONSTER BUILDERS
# ---------------------------------------------------------------------------
func _rebuild_monster() -> void:
	for c in get_children():
		c.queue_free()

	root_pivot = Node3D.new()
	root_pivot.name = "RootPivot"
	# Facing direction: rotation instead of negative scale prevents backface culling
	root_pivot.rotation_degrees.y = 0.0 if facing_direction >= 0 else 180.0
	root_pivot.scale = Vector3.ONE
	add_child(root_pivot)

	match monster_type:
		"slime":
			_build_slime()
		"skeleton":
			_build_skeleton()
		"boss":
			_build_boss()
		_:
			_build_goblin()

	_apply_elite_style()


# ── 1. GOBLIN / ORC BRUTE ─────────────────────────────────────────────────
func _build_goblin() -> void:
	# Hunched, wide, brutish physique
	pelvis = Node3D.new()
	pelvis.name = "Pelvis"
	pelvis.position = Vector3(0, 0.78, 0)
	root_pivot.add_child(pelvis)
	_create_joint_sphere(pelvis, 0.16, mat_armor)
	_create_box_mesh(pelvis, Vector3(0, 0.04, 0), Vector3(0.42, 0.16, 0.28), mat_armor)

	torso = Node3D.new()
	torso.name = "Torso"
	torso.position = Vector3(0, 0.14, 0)
	pelvis.add_child(torso)
	_create_box_mesh(torso, Vector3(0, 0.08, 0.04), Vector3(0.46, 0.22, 0.26), mat_skin)

	chest = Node3D.new()
	chest.name = "Chest"
	chest.position = Vector3(0, 0.22, 0.04) # Hunched forward
	torso.add_child(chest)
	# Heavy spiked iron breastplate
	_create_box_mesh(chest, Vector3(0, 0.10, 0.02), Vector3(0.52, 0.28, 0.30), mat_armor)
	_create_box_mesh(chest, Vector3(-0.30, 0.18, 0), Vector3(0.20, 0.16, 0.22), mat_armor) # Spiked pauldrons
	_create_box_mesh(chest, Vector3(0.30, 0.18, 0), Vector3(0.20, 0.16, 0.22), mat_armor)

	neck = Node3D.new()
	neck.name = "Neck"
	neck.position = Vector3(0, 0.20, 0.08)
	chest.add_child(neck)

	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.14, 0.06)
	neck.add_child(head)
	_create_joint_sphere(head, 0.20, mat_skin)
	# Goblin Helmet & Spiked Ears
	_create_box_mesh(head, Vector3(0, 0.08, 0), Vector3(0.36, 0.16, 0.32), mat_armor)
	_create_box_mesh(head, Vector3(-0.24, 0.02, -0.02), Vector3(0.16, 0.08, 0.06), mat_skin) # Big pointed ears
	_create_box_mesh(head, Vector3(0.24, 0.02, -0.02), Vector3(0.16, 0.08, 0.06), mat_skin)
	# Glowing Yellow/Red Beast Eyes
	mat_eye.albedo_color = Color("#ffeb3b") if not is_elite else Color("#ff0055")
	_create_box_mesh(head, Vector3(-0.07, 0.02, 0.18), Vector3(0.045, 0.03, 0.02), mat_eye)
	_create_box_mesh(head, Vector3(0.07, 0.02, 0.18), Vector3(0.045, 0.03, 0.02), mat_eye)

	# Limbs: Muscular, heavy arms
	shoulder_l = Node3D.new(); shoulder_l.position = Vector3(-0.30, 0.14, 0); chest.add_child(shoulder_l)
	arm_l = Node3D.new(); shoulder_l.add_child(arm_l)
	_create_cylinder_mesh(arm_l, Vector3(0, -0.14, 0), 0.085, 0.28, mat_skin)
	forearm_l = Node3D.new(); forearm_l.position = Vector3(0, -0.28, 0); arm_l.add_child(forearm_l)
	_create_cylinder_mesh(forearm_l, Vector3(0, -0.12, 0), 0.075, 0.24, mat_skin)
	hand_l = Node3D.new(); hand_l.position = Vector3(0, -0.24, 0); forearm_l.add_child(hand_l)
	_create_joint_sphere(hand_l, 0.08, mat_armor)

	# Left hand holds Goblin Cleaver / Spiked Club
	weapon_pivot = Node3D.new(); weapon_pivot.position = Vector3(0, 0, 0.04); hand_l.add_child(weapon_pivot)
	_build_goblin_club(weapon_pivot)

	shoulder_r = Node3D.new(); shoulder_r.position = Vector3(0.30, 0.14, 0); chest.add_child(shoulder_r)
	arm_r = Node3D.new(); shoulder_r.add_child(arm_r)
	_create_cylinder_mesh(arm_r, Vector3(0, -0.14, 0), 0.085, 0.28, mat_skin)
	forearm_r = Node3D.new(); forearm_r.position = Vector3(0, -0.28, 0); arm_r.add_child(forearm_r)
	_create_cylinder_mesh(forearm_r, Vector3(0, -0.12, 0), 0.075, 0.24, mat_skin)
	hand_r = Node3D.new(); hand_r.position = Vector3(0, -0.24, 0); forearm_r.add_child(hand_r)
	_create_joint_sphere(hand_r, 0.08, mat_armor)

	# Legs: Thick, bent outward
	hip_l = Node3D.new(); hip_l.position = Vector3(-0.16, -0.06, 0); pelvis.add_child(hip_l)
	leg_l = Node3D.new(); hip_l.add_child(leg_l)
	_create_cylinder_mesh(leg_l, Vector3(0, -0.18, 0), 0.09, 0.36, mat_skin)
	shin_l = Node3D.new(); shin_l.position = Vector3(0, -0.36, 0); leg_l.add_child(shin_l)
	_create_cylinder_mesh(shin_l, Vector3(0, -0.16, 0), 0.08, 0.32, mat_armor)
	foot_l = Node3D.new(); foot_l.position = Vector3(0, -0.32, 0); shin_l.add_child(foot_l)
	_create_box_mesh(foot_l, Vector3(0, -0.04, 0.06), Vector3(0.14, 0.08, 0.22), mat_armor)

	hip_r = Node3D.new(); hip_r.position = Vector3(0.16, -0.06, 0); pelvis.add_child(hip_r)
	leg_r = Node3D.new(); hip_r.add_child(leg_r)
	_create_cylinder_mesh(leg_r, Vector3(0, -0.18, 0), 0.09, 0.36, mat_skin)
	shin_r = Node3D.new(); shin_r.position = Vector3(0, -0.36, 0); leg_r.add_child(shin_r)
	_create_cylinder_mesh(shin_r, Vector3(0, -0.16, 0), 0.08, 0.32, mat_armor)
	foot_r = Node3D.new(); foot_r.position = Vector3(0, -0.32, 0); shin_r.add_child(foot_r)
	_create_box_mesh(foot_r, Vector3(0, -0.04, 0.06), Vector3(0.14, 0.08, 0.22), mat_armor)


func _build_goblin_club(parent: Node3D) -> void:
	_create_cylinder_mesh(parent, Vector3(0, 0.15, 0), 0.04, 0.40, mat_wood)
	# Spiked Iron Head
	_create_box_mesh(parent, Vector3(0, 0.45, 0), Vector3(0.18, 0.30, 0.18), mat_armor)
	_create_box_mesh(parent, Vector3(-0.11, 0.45, 0), Vector3(0.06, 0.06, 0.06), mat_metal)
	_create_box_mesh(parent, Vector3(0.11, 0.45, 0), Vector3(0.06, 0.06, 0.06), mat_metal)


# ── 2. SKELETON ────────────────────────────────────────────────────────────
func _build_skeleton() -> void:
	pelvis = Node3D.new(); pelvis.name = "Pelvis"; pelvis.position = Vector3(0, 0.88, 0); root_pivot.add_child(pelvis)
	_create_joint_sphere(pelvis, 0.11, mat_bone)
	_create_box_mesh(pelvis, Vector3(0, 0.02, 0), Vector3(0.32, 0.10, 0.18), mat_bone)

	torso = Node3D.new(); torso.name = "Torso"; torso.position = Vector3(0, 0.15, 0); pelvis.add_child(torso)
	_create_cylinder_mesh(torso, Vector3(0, 0.08, 0), 0.05, 0.20, mat_bone) # Thin vertebrae

	chest = Node3D.new(); chest.name = "Chest"; chest.position = Vector3(0, 0.24, 0); torso.add_child(chest)
	# Ribcage box with bone ridges
	_create_box_mesh(chest, Vector3(0, 0.08, 0), Vector3(0.38, 0.22, 0.20), mat_bone)

	neck = Node3D.new(); neck.name = "Neck"; neck.position = Vector3(0, 0.20, 0); chest.add_child(neck)
	_create_cylinder_mesh(neck, Vector3(0, 0.04, 0), 0.04, 0.10, mat_bone)

	head = Node3D.new(); head.name = "Head"; head.position = Vector3(0, 0.16, 0); neck.add_child(head)
	# Skull Head
	_create_joint_sphere(head, 0.17, mat_bone)
	_create_box_mesh(head, Vector3(0, -0.08, 0.06), Vector3(0.18, 0.10, 0.14), mat_bone) # Jaw
	# Glowing Cyan Eye Sockets
	mat_eye.albedo_color = Color("#00e5ff")
	_create_box_mesh(head, Vector3(-0.06, 0.02, 0.15), Vector3(0.04, 0.03, 0.02), mat_eye)
	_create_box_mesh(head, Vector3(0.06, 0.02, 0.15), Vector3(0.04, 0.03, 0.02), mat_eye)

	# Bony Limbs
	shoulder_l = Node3D.new(); shoulder_l.position = Vector3(-0.24, 0.12, 0); chest.add_child(shoulder_l)
	arm_l = Node3D.new(); shoulder_l.add_child(arm_l)
	_create_cylinder_mesh(arm_l, Vector3(0, -0.14, 0), 0.045, 0.28, mat_bone)
	forearm_l = Node3D.new(); forearm_l.position = Vector3(0, -0.28, 0); arm_l.add_child(forearm_l)
	_create_cylinder_mesh(forearm_l, Vector3(0, -0.12, 0), 0.04, 0.24, mat_bone)
	hand_l = Node3D.new(); hand_l.position = Vector3(0, -0.24, 0); forearm_l.add_child(hand_l)
	_create_joint_sphere(hand_l, 0.05, mat_bone)

	# Rusty Broadsword in hand
	weapon_pivot = Node3D.new(); weapon_pivot.position = Vector3(0, 0, 0.02); hand_l.add_child(weapon_pivot)
	_build_skeleton_sword(weapon_pivot)

	shoulder_r = Node3D.new(); shoulder_r.position = Vector3(0.24, 0.12, 0); chest.add_child(shoulder_r)
	arm_r = Node3D.new(); shoulder_r.add_child(arm_r)
	_create_cylinder_mesh(arm_r, Vector3(0, -0.14, 0), 0.045, 0.28, mat_bone)
	forearm_r = Node3D.new(); forearm_r.position = Vector3(0, -0.28, 0); arm_r.add_child(forearm_r)
	_create_cylinder_mesh(forearm_r, Vector3(0, -0.12, 0), 0.04, 0.24, mat_bone)
	hand_r = Node3D.new(); hand_r.position = Vector3(0, -0.24, 0); forearm_r.add_child(hand_r)
	_create_joint_sphere(hand_r, 0.05, mat_bone)

	# Bone Buckler Shield in right hand
	shield_pivot = Node3D.new(); shield_pivot.position = Vector3(0, 0, 0.04); hand_r.add_child(shield_pivot)
	_create_cylinder_mesh(shield_pivot, Vector3(0, 0, 0), 0.18, 0.04, mat_bone)

	# Bony Legs
	hip_l = Node3D.new(); hip_l.position = Vector3(-0.13, -0.04, 0); pelvis.add_child(hip_l)
	leg_l = Node3D.new(); hip_l.add_child(leg_l)
	_create_cylinder_mesh(leg_l, Vector3(0, -0.18, 0), 0.05, 0.38, mat_bone)
	shin_l = Node3D.new(); shin_l.position = Vector3(0, -0.38, 0); leg_l.add_child(shin_l)
	_create_cylinder_mesh(shin_l, Vector3(0, -0.18, 0), 0.045, 0.38, mat_bone)
	foot_l = Node3D.new(); foot_l.position = Vector3(0, -0.38, 0); shin_l.add_child(foot_l)
	_create_box_mesh(foot_l, Vector3(0, -0.03, 0.05), Vector3(0.08, 0.05, 0.18), mat_bone)

	hip_r = Node3D.new(); hip_r.position = Vector3(0.13, -0.04, 0); pelvis.add_child(hip_r)
	leg_r = Node3D.new(); hip_r.add_child(leg_r)
	_create_cylinder_mesh(leg_r, Vector3(0, -0.18, 0), 0.05, 0.38, mat_bone)
	shin_r = Node3D.new(); shin_r.position = Vector3(0, -0.38, 0); leg_r.add_child(shin_r)
	_create_cylinder_mesh(shin_r, Vector3(0, -0.18, 0), 0.045, 0.38, mat_bone)
	foot_r = Node3D.new(); foot_r.position = Vector3(0, -0.38, 0); shin_r.add_child(foot_r)
	_create_box_mesh(foot_r, Vector3(0, -0.03, 0.05), Vector3(0.08, 0.05, 0.18), mat_bone)


func _build_skeleton_sword(parent: Node3D) -> void:
	_create_cylinder_mesh(parent, Vector3(0, 0.06, 0), 0.025, 0.18, mat_wood)
	_create_box_mesh(parent, Vector3(0, 0.15, 0), Vector3(0.28, 0.04, 0.04), mat_armor)
	_create_box_mesh(parent, Vector3(0, 0.55, 0), Vector3(0.08, 0.80, 0.02), mat_metal)


# ── 3. SLIME ───────────────────────────────────────────────────────────────
func _build_slime() -> void:
	pelvis = Node3D.new(); pelvis.name = "Pelvis"; pelvis.position = Vector3(0, 0.425, 0); root_pivot.add_child(pelvis)

	var mat_slime = StandardMaterial3D.new()
	mat_slime.albedo_color = Color("#00e676") if not is_elite else Color("#ab47bc") # Opaque & vibrant!
	mat_slime.roughness = 0.12
	mat_slime.metallic = 0.25
	mat_slime.emission_enabled = true
	mat_slime.emission = Color("#00c853") if not is_elite else Color("#8e24aa")
	mat_slime.emission_energy_multiplier = 0.85

	slime_blob = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.58
	sphere.height = 0.85
	slime_blob.mesh = sphere
	slime_blob.material_override = mat_slime
	pelvis.add_child(slime_blob)

	# Inner Floating Math Nucleus
	slime_nucleus = MeshInstance3D.new()
	var cube = BoxMesh.new()
	cube.size = Vector3(0.22, 0.22, 0.22)
	slime_nucleus.mesh = cube
	slime_nucleus.material_override = mat_weapon_glow
	pelvis.add_child(slime_nucleus)

	# Cute / Menacing Visor Eyes
	mat_eye.albedo_color = Color.WHITE
	slime_eye_l = _create_joint_sphere(pelvis, 0.095, mat_eye, Vector3(-0.16, 0.12, 0.46))
	slime_eye_r = _create_joint_sphere(pelvis, 0.095, mat_eye, Vector3(0.16, 0.12, 0.46))


# ── 4. BOSS (MATHE-KÖNIG / WARLORD) ────────────────────────────────────────
func _build_boss() -> void:
	_build_goblin() # Base humanoid rig
	root_pivot.scale = Vector3(1.35, 1.35, 1.35)
	root_pivot.rotation_degrees.y = 0.0 if facing_direction >= 0 else 180.0

	# Dragon Horned Crown Helmet
	_create_box_mesh(head, Vector3(0, 0.24, 0), Vector3(0.40, 0.18, 0.36), mat_gold)
	_create_box_mesh(head, Vector3(-0.24, 0.32, 0), Vector3(0.06, 0.22, 0.06), mat_gold) # Horns
	_create_box_mesh(head, Vector3(0.24, 0.32, 0), Vector3(0.06, 0.22, 0.06), mat_gold)

	# Massive Runic Greatsword
	for c in weapon_pivot.get_children():
		c.queue_free()
	_build_boss_greatsword(weapon_pivot)

	# Royal Crimson Cape with Golden Clasps
	_build_boss_cape()


func _build_boss_greatsword(parent: Node3D) -> void:
	_create_cylinder_mesh(parent, Vector3(0, 0.12, 0), 0.04, 0.35, mat_armor)
	_create_box_mesh(parent, Vector3(0, 0.30, 0), Vector3(0.55, 0.08, 0.08), mat_gold)
	# Massive blade with runic glow
	_create_box_mesh(parent, Vector3(0, 1.05, 0), Vector3(0.16, 1.45, 0.04), mat_metal)
	_create_box_mesh(parent, Vector3(0, 1.05, 0.02), Vector3(0.06, 1.30, 0.02), mat_weapon_glow)


func _build_boss_cape() -> void:
	var cape_root = Node3D.new()
	cape_root.name = "BossCape"
	cape_root.position = Vector3(0, 0.12, -0.16)
	chest.add_child(cape_root)

	# Golden Pauldron Mantle Clasps
	_create_box_mesh(cape_root, Vector3(-0.28, 0.06, 0.02), Vector3(0.14, 0.08, 0.16), mat_gold)
	_create_box_mesh(cape_root, Vector3(0.28, 0.06, 0.02), Vector3(0.14, 0.08, 0.16), mat_gold)

	# Main Royal Crimson Cape (firmly behind back in -Z)
	_create_box_mesh(cape_root, Vector3(0, -0.42, -0.04), Vector3(0.72, 0.85, 0.04), mat_cape)
	# Lower Tattered Wings
	_create_box_mesh(cape_root, Vector3(-0.18, -0.88, -0.05), Vector3(0.26, 0.22, 0.04), mat_cape)
	_create_box_mesh(cape_root, Vector3(0.18, -0.88, -0.05), Vector3(0.26, 0.22, 0.04), mat_cape)
	_create_box_mesh(cape_root, Vector3(0, -0.84, -0.05), Vector3(0.22, 0.18, 0.04), mat_gold)


# ---------------------------------------------------------------------------
#  ANIMATION SYSTEM
# ---------------------------------------------------------------------------
func _update_animation(delta: float) -> void:
	_anim_t += delta

	if monster_type == "slime":
		_animate_slime(delta)
		return

	match current_anim:
		AnimState.IDLE:
			_pose_idle(delta)
		AnimState.WALK:
			_pose_walk(delta)
		AnimState.ATTACK:
			_pose_attack(delta)
		AnimState.HURT:
			_pose_hurt(delta)
		AnimState.DEFEATED:
			_pose_defeated(delta)


func _pose_idle(_delta: float) -> void:
	var breath = sin(_clock * 2.2)
	var sway = cos(_clock * 1.4)

	pelvis.position.y = 0.78 + breath * 0.015
	torso.rotation_degrees = Vector3(breath * 1.5, 12.0 + sway * 1.0, 0)
	chest.rotation_degrees = Vector3(breath * 1.2, 4.0, 0)
	head.rotation_degrees = Vector3(-breath * 1.0, 15.0 - sway * 1.2, 0)

	# Legs balanced
	hip_l.rotation_degrees = Vector3(-4.0, 8.0, 5.0)
	shin_l.rotation_degrees = Vector3(6.0, 0, 0)
	hip_r.rotation_degrees = Vector3(6.0, -8.0, -5.0)
	shin_r.rotation_degrees = Vector3(-4.0, 0, 0)

	# Weapon Arm (Left Hand) raised ready
	shoulder_l.rotation_degrees = Vector3(-15.0 + breath * 1.5, 12.0, 8.0)
	arm_l.rotation_degrees = Vector3(-25.0, 0, 0)
	forearm_l.rotation_degrees = Vector3(-55.0, 0, 0)
	weapon_pivot.rotation_degrees = Vector3(65.0 + breath * 1.5, 10.0, -25.0)

	# Off-hand / Shield Arm
	shoulder_r.rotation_degrees = Vector3(5.0 + breath * 1.0, -5.0, -10.0)
	arm_r.rotation_degrees = Vector3(-15.0, 0, 0)
	forearm_r.rotation_degrees = Vector3(-65.0, 15.0, 0)


func _pose_walk(_delta: float) -> void:
	var step_cycle = sin(_clock * 5.0)
	var step_cos = cos(_clock * 5.0)

	pelvis.position.y = 0.78 + abs(step_cycle) * 0.04
	torso.rotation_degrees = Vector3(8.0, 12.0 + step_cycle * 8.0, 0) # Leans forward into march

	# Alternating leg march
	hip_l.rotation_degrees = Vector3(step_cycle * 28.0, 5.0, 0)
	shin_l.rotation_degrees = Vector3(maxf(0.0, -step_cycle * 35.0), 0, 0)
	hip_r.rotation_degrees = Vector3(-step_cycle * 28.0, -5.0, 0)
	shin_r.rotation_degrees = Vector3(maxf(0.0, step_cycle * 35.0), 0, 0)

	# Arms swing opposite to legs
	shoulder_l.rotation_degrees = Vector3(-15.0 - step_cycle * 18.0, 10.0, 0)
	forearm_l.rotation_degrees = Vector3(-55.0, 0, 0)
	shoulder_r.rotation_degrees = Vector3(5.0 + step_cycle * 18.0, -5.0, 0)
	forearm_r.rotation_degrees = Vector3(-65.0, 0, 0)


func _pose_attack(_delta: float) -> void:
	var duration: float = 0.30
	var p = clampf(_anim_t / duration, 0.0, 1.0)
	var swing_p = ease(p, 0.35)

	# Violent overhead smash / thrust towards knight
	pelvis.position.y = lerpf(0.78, 0.70, swing_p)
	torso.rotation_degrees = Vector3(lerpf(-10.0, 25.0, swing_p), lerpf(-15.0, 25.0, swing_p), 0)

	shoulder_l.rotation_degrees = Vector3(lerpf(-75.0, 30.0, swing_p), 15.0, 10.0)
	arm_l.rotation_degrees = Vector3(lerpf(-45.0, -15.0, swing_p), 0, 0)
	forearm_l.rotation_degrees = Vector3(lerpf(-80.0, -20.0, swing_p), 0, 0)
	weapon_pivot.rotation_degrees = Vector3(lerpf(120.0, -45.0, swing_p), 15.0, -35.0)

	if p >= 0.45 and not _impact_triggered:
		_impact_triggered = true
		attack_impact.emit()

	if p >= 1.0:
		current_anim = AnimState.IDLE
		_anim_t = 0.0


func _pose_hurt(_delta: float) -> void:
	var p = clampf(_anim_t / 0.20, 0.0, 1.0)
	var recoil = sin(p * PI)

	torso.rotation_degrees = Vector3(-18.0 * recoil, 10.0, 0)
	head.rotation_degrees = Vector3(20.0 * recoil, 0, 0)
	shoulder_l.rotation_degrees = Vector3(-35.0 * recoil, 20.0, 20.0)

	if p >= 1.0:
		current_anim = AnimState.IDLE
		_anim_t = 0.0


func _pose_defeated(_delta: float) -> void:
	var p = clampf(_anim_t / 0.35, 0.0, 1.0)
	var ease_p = ease(p, 2.0)

	pelvis.position.y = lerpf(0.78, 0.20, ease_p)
	root_pivot.rotation_degrees.z = lerpf(0.0, 75.0, ease_p) # Collapses sideways
	root_pivot.scale = Vector3(1.0, 1.0, 1.0).lerp(Vector3(0.05, 0.05, 0.05), ease_p)


# ── Slime squash & stretch ────────────────────────────────────────────────
func _animate_slime(_delta: float) -> void:
	if not slime_blob:
		return

	match current_anim:
		AnimState.IDLE:
			var w = sin(_clock * 3.5)
			pelvis.position.y = 0.45 + w * 0.04
			slime_blob.scale = Vector3(1.0 + w * 0.08, 1.0 - w * 0.12, 1.0 + w * 0.08)
			slime_nucleus.rotation_degrees = Vector3(_clock * 45.0, _clock * 60.0, 0)
		AnimState.WALK:
			var hop = abs(sin(_clock * 5.0))
			pelvis.position.y = 0.38 + hop * 0.45 # High, bouncy leaps!
			var squish = sin(_clock * 5.0)
			slime_blob.scale = Vector3(1.0 - squish * 0.20, 1.0 + squish * 0.30, 1.0 - squish * 0.20)
		AnimState.ATTACK:
			var p = clampf(_anim_t / 0.28, 0.0, 1.0)
			var lunge = sin(p * PI)
			pelvis.position.x = -lunge * 0.50 # Lunges towards knight!
			slime_blob.scale = Vector3(1.0 + lunge * 0.35, 1.0 - lunge * 0.30, 1.0 + lunge * 0.35)
			if p >= 0.5 and not _impact_triggered:
				_impact_triggered = true
				attack_impact.emit()
			if p >= 1.0:
				current_anim = AnimState.IDLE
				_anim_t = 0.0
		AnimState.HURT:
			var p = clampf(_anim_t / 0.18, 0.0, 1.0)
			var flat = sin(p * PI)
			slime_blob.scale = Vector3(1.0 + flat * 0.45, 1.0 - flat * 0.50, 1.0 + flat * 0.45)
			if p >= 1.0:
				current_anim = AnimState.IDLE
				_anim_t = 0.0
		AnimState.DEFEATED:
			var p = clampf(_anim_t / 0.25, 0.0, 1.0)
			slime_blob.scale = Vector3(1.0, 1.0, 1.0).lerp(Vector3(0.01, 0.01, 0.01), p)


# Public animation triggers
func play_idle() -> void:
	current_anim = AnimState.IDLE
	_anim_t = 0.0

func play_walk() -> void:
	current_anim = AnimState.WALK
	_anim_t = 0.0

func play_attack() -> void:
	current_anim = AnimState.ATTACK
	_anim_t = 0.0
	_impact_triggered = false

func play_hurt() -> void:
	current_anim = AnimState.HURT
	_anim_t = 0.0

func play_defeated() -> void:
	current_anim = AnimState.DEFEATED
	_anim_t = 0.0


# Helpers
func _create_joint_sphere(parent: Node3D, radius: float, mat: Material, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = radius; sphere.height = radius * 2.0; sphere.radial_segments = 12; sphere.rings = 6
	mi.mesh = sphere; mi.position = pos; mi.material_override = mat
	parent.add_child(mi)
	return mi

func _create_cylinder_mesh(parent: Node3D, pos: Vector3, radius: float, height: float, mat: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = radius; cyl.bottom_radius = radius; cyl.height = height; cyl.radial_segments = 10
	mi.mesh = cyl; mi.position = pos; mi.material_override = mat
	parent.add_child(mi)
	return mi

func _create_box_mesh(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = size; mi.mesh = box; mi.position = pos; mi.material_override = mat
	parent.add_child(mi)
	return mi
