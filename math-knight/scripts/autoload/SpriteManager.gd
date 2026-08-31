extends Node
## SpriteManager - Central visual asset loader and cosmetic sprite manager.
## Handles dynamic loading of transparent pixel art sprites and SpriteFrames
## for all weapons, cosmetics, items, chests, enemies, and bosses.

const SPRITE_MAP: Dictionary = {
	# Base & Weapons
	"knight_base": "res://assets/sprites/knight_comic/Idle/rotations/west.png",
	"sword_iron": "res://assets/sprites/knight_comic/Idle/rotations/west.png",
	"sword_flame": "res://assets/sprites/knight_comic/Flame_Sword/rotations/west.png",
	"sword_frost": "res://assets/sprites/knight_comic/Frost_Sword/rotations/west.png",
	"sword_gold": "res://assets/sprites/knight_comic/Golden_Sword/rotations/west.png",
	"sword_lightsaber": "res://assets/sprites/knight_comic/Lightsaber/rotations/west.png",
	"sword_pan": "res://assets/sprites/knight_comic/Frying_Pan/rotations/west.png",

	# Helmets & Hats
	"helm_knight": "res://assets/sprites/knight_comic/Idle/rotations/west.png",
	"helm_viking": "res://assets/sprites/knight_comic/Viking_Helmet/rotations/west.png",
	"helm_crown": "res://assets/sprites/knight_comic/King_Crown/rotations/west.png",
	"hat_none": "res://assets/sprites/knight_comic/Idle/rotations/west.png",
	"hat_wizard": "res://assets/sprites/knight_comic/Wizard_Hat/rotations/west.png",
	"hat_jester": "res://assets/sprites/knight_comic/Jester_Hat/rotations/west.png",
	"hat_propeller": "res://assets/sprites/knight_comic/Propeller_Hat/rotations/west.png",
	"hat_sunglasses": "res://assets/sprites/knight_comic/Sunglasses/rotations/west.png",

	# Bosses & Enemies
	"boss_math_king": "res://assets/sprites/boss/boss_math_king.png",
	"enemy_orc": "res://assets/sprites/orc/Idle/rotations/west.png",

	# Chests
	"chest_treasure": "res://assets/sprites/chests/chest_treasure.png",
	"chest_bronze": "res://assets/sprites/chests/chest_bronze.png",
	"chest_silver": "res://assets/sprites/chests/chest_silver.png",
	"chest_gold": "res://assets/sprites/chests/chest_gold.png",
	"chest_legendary": "res://assets/sprites/chests/chest_legendary.png",
	"chest_open": "res://assets/sprites/chests/chest_open.png",

	# Items & Potions
	"potion_red": "res://assets/sprites/items/potion_red.png",
	"potion_green": "res://assets/sprites/items/potion_green.png",
	"shield": "res://assets/sprites/items/shield.png",
	"compass": "res://assets/sprites/items/compass.png",
	"stone": "res://assets/sprites/items/stone.png",
	"boots": "res://assets/sprites/items/boots.png",
	"gem": "res://assets/sprites/items/gem.png"
}

var _texture_cache: Dictionary = {}
var _frames_cache: Dictionary = {}


func _ready() -> void:
	preload_sprites()


func preload_sprites() -> void:
	for key in SPRITE_MAP.keys():
		get_sprite(key)


## Returns a Texture2D for the requested sprite key
func get_sprite(key: String) -> Texture2D:
	if _texture_cache.has(key):
		return _texture_cache[key]

	var path: String = SPRITE_MAP.get(key, "")
	if path.is_empty():
		return _get_fallback_texture(key)

	if ResourceLoader.exists(path):
		var tex = load(path)
		if tex:
			_texture_cache[key] = tex
			return tex

	return _get_fallback_texture(key)


## Resolves the cosmetic state folder for equipped cosmetics
func resolve_cosmetic_state(equipped: Dictionary) -> String:
	var sword = equipped.get("sword", "sword_iron")
	var hat = equipped.get("hat", "hat_none")
	var helmet = equipped.get("helmet", "helm_knight")

	# Priority 1: Special Weapons (they have custom attack & idle animations)
	match sword:
		"sword_flame": return "Flame_Sword"
		"sword_frost": return "Frost_Sword"
		"sword_gold": return "Golden_Sword"
		"sword_lightsaber": return "Lightsaber"
		"sword_pan": return "Frying_Pan"

	# Priority 2: Special Hats
	match hat:
		"hat_wizard": return "Wizard_Hat"
		"hat_jester": return "Jester_Hat"
		"hat_propeller": return "Propeller_Hat"
		"hat_sunglasses": return "Sunglasses"

	# Priority 3: Special Helmets
	match helmet:
		"helm_viking": return "Viking_Helmet"
		"helm_crown": return "King_Crown"

	return "Idle"


## Builds and returns full AnimatedSprite2D SpriteFrames for equipped cosmetic state
func get_knight_sprite_frames_for_cosmetics(equipped: Dictionary) -> SpriteFrames:
	var state_name = resolve_cosmetic_state(equipped)
	return get_knight_sprite_frames(state_name)


## Constructs SpriteFrames with idle (4f), windup (9f), slash (9f), attack (17f) for a state folder
func get_knight_sprite_frames(state_folder: String) -> SpriteFrames:
	if _frames_cache.has(state_folder):
		return _frames_cache[state_folder]

	var frames: SpriteFrames = SpriteFrames.new()
	var base_path = "res://assets/sprites/knight_comic/" + state_folder

	# Fallback to Idle if state folder is missing
	if not DirAccess.dir_exists_absolute("res://assets/sprites/knight_comic/" + state_folder):
		base_path = "res://assets/sprites/knight_comic/Idle"

	# 1. Idle animation (4 frames west)
	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	frames.set_animation_speed("idle", 6.0)
	for i in range(4):
		var p = base_path + "/animations/idle/west/frame_00" + str(i) + ".png"
		var fb = "res://assets/sprites/knight_comic/Idle/animations/idle/west/frame_00" + str(i) + ".png"
		var tex = _load_texture_robust(p, fb)
		if tex:
			frames.add_frame("idle", tex)

	# 2. Windup animation (frames 0..3 pull-back ready stance)
	frames.add_animation("windup")
	frames.set_animation_loop("windup", false)
	frames.set_animation_speed("windup", 24.0)
	for i in range(4):
		var p = base_path + "/animations/sword_attack/west/frame_00" + str(i) + ".png"
		var fb = "res://assets/sprites/knight_comic/Idle/animations/sword_attack/west/frame_00" + str(i) + ".png"
		var tex = _load_texture_robust(p, fb)
		if tex:
			frames.add_frame("windup", tex)

	# 3. Slash animation (frames 3..8 powerful fast forward swing)
	frames.add_animation("slash")
	frames.set_animation_loop("slash", false)
	frames.set_animation_speed("slash", 36.0)
	for i in range(3, 9):
		var p = base_path + "/animations/sword_attack/west/frame_00" + str(i) + ".png"
		var fb = "res://assets/sprites/knight_comic/Idle/animations/sword_attack/west/frame_00" + str(i) + ".png"
		var tex = _load_texture_robust(p, fb)
		if tex:
			frames.add_frame("slash", tex)

	# 4. Attack combo animation (0..8 full swing)
	frames.add_animation("attack")
	frames.set_animation_loop("attack", false)
	frames.set_animation_speed("attack", 32.0)
	for i in range(9):
		var p = base_path + "/animations/sword_attack/west/frame_00" + str(i) + ".png"
		var fb = "res://assets/sprites/knight_comic/Idle/animations/sword_attack/west/frame_00" + str(i) + ".png"
		var tex = _load_texture_robust(p, fb)
		if tex:
			frames.add_frame("attack", tex)

	_frames_cache[state_folder] = frames
	return frames


func _load_texture_robust(path: String, fallback_path: String = "") -> Texture2D:
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			return res

	if FileAccess.file_exists(path):
		var img = Image.load_from_file(path)
		if img and not img.is_empty():
			return ImageTexture.create_from_image(img)

	if not fallback_path.is_empty():
		if ResourceLoader.exists(fallback_path):
			var res = load(fallback_path)
			if res is Texture2D:
				return res
		if FileAccess.file_exists(fallback_path):
			var img = Image.load_from_file(fallback_path)
			if img and not img.is_empty():
				return ImageTexture.create_from_image(img)

	return null


func _get_fallback_texture(key: String) -> Texture2D:
	if key.begins_with("boss"):
		var bp = "res://assets/sprites/boss/boss_math_king.png"
		if ResourceLoader.exists(bp):
			return load(bp)
	if key.begins_with("enemy"):
		var p = "res://assets/sprites/orc/Idle/rotations/west.png"
		if ResourceLoader.exists(p):
			return load(p)
	var kp = "res://assets/sprites/knight_comic/Idle/rotations/west.png"
	if ResourceLoader.exists(kp):
		return load(kp)
	return null


## Resolves active Knight texture based on equipped cosmetics dictionary
func get_equipped_knight_texture() -> Texture2D:
	var equipped: Dictionary = {}
	if has_node("/root/SaveManager"):
		equipped = get_node("/root/SaveManager").equipped_cosmetics

	return get_knight_texture_for_cosmetics(equipped)


func get_knight_texture_for_cosmetics(equipped: Dictionary) -> Texture2D:
	var state_name = resolve_cosmetic_state(equipped)
	var path = "res://assets/sprites/knight_comic/" + state_name + "/rotations/west.png"
	if ResourceLoader.exists(path):
		return load(path)
	return get_sprite("knight_base")


## Helper for previewing a specific cosmetic item on the Knight
func get_cosmetic_preview_texture(item_id: String, _slot: String) -> Texture2D:
	if SPRITE_MAP.has(item_id):
		return get_sprite(item_id)
	return get_sprite("knight_base")


func get_boss_texture() -> Texture2D:
	return get_sprite("boss_math_king")


func get_enemy_texture() -> Texture2D:
	return get_sprite("enemy_orc")


func get_chest_texture(quality: String = "gold") -> Texture2D:
	var key = "chest_" + quality
	if SPRITE_MAP.has(key):
		return get_sprite(key)
	return get_sprite("chest_treasure")


func get_item_icon(icon_name: String) -> Texture2D:
	if SPRITE_MAP.has(icon_name):
		return get_sprite(icon_name)
	return null
