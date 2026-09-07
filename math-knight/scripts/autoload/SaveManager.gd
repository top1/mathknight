extends Node
## SaveManager singleton — persistent storage for all player data across runs.
## Handles currencies, cosmetics, knight stats, highscores, and settings.

const SAVE_PATH: String = "user://mathknight_save.json"

# === Persistent Player Data ===
var diamonds: int = 0
var gold: int = 0
var total_gold_earned: int = 0
var total_runs_completed: int = 0
var total_runs_started: int = 0


func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	gold += amount
	total_gold_earned += amount
	save_data()
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").gold_changed.emit(gold)


func spend_gold(amount: int) -> bool:
	if amount <= 0:
		return true
	if gold >= amount:
		gold -= amount
		save_data()
		if has_node("/root/EventBus"):
			get_node("/root/EventBus").gold_changed.emit(gold)
		return true
	return false


var wood: int = 0
var weapon_affix: String = "" # "flame", "frost", "greed", "storm"
var forge_level: int = 1
var lumber_level: int = 1


func add_wood(amount: int) -> void:
	if amount <= 0:
		return
	wood += amount
	save_data()


func spend_wood(amount: int) -> bool:
	if amount <= 0:
		return true
	if wood >= amount:
		wood -= amount
		save_data()
		return true
	return false


func set_weapon_affix(affix: String) -> void:
	weapon_affix = affix
	save_data()


# Knight permanent stats
var knight_level: int = 1
var knight_xp: int = 0
var knight_stat_points: int = 0
var knight_stats: Dictionary = {
	"strength": 0,     # +Attack damage
	"endurance": 0,    # +Max HP
	"defense": 0,      # +Armor
	"agility": 0,      # +Dodge chance
	"wisdom": 0        # +Gold drop rate, +Chest quality
}

# Cosmetics
var unlocked_cosmetics: Array[String] = []
var equipped_cosmetics: Dictionary = {
	"sword": "",
	"helmet": "",
	"hat": "",
	"victory_anim": ""
}

# Highscores (top 10)
var best_scores: Array[Dictionary] = []

signal render_mode_changed(is_3d: bool)

# Settings
var tutorial_tips_enabled: bool = true
var sfx_enabled: bool = true
var music_enabled: bool = true
var render_mode_3d_shader: bool = true


func _ready() -> void:
	load_data()


# === XP & Level System ===

const XP_PER_LEVEL: Array[int] = [
	0,     # Level 1 (start)
	50,    # Level 2
	120,   # Level 3
	220,   # Level 4
	350,   # Level 5
	520,   # Level 6
	730,   # Level 7
	1000,  # Level 8
	1350,  # Level 9
	1800,  # Level 10
	2350,  # Level 11
	3000,  # Level 12
	3800,  # Level 13
	4800,  # Level 14
	6000,  # Level 15
	7500,  # Level 16
	9300,  # Level 17
	11500, # Level 18
	14000, # Level 19
	17000, # Level 20
	20500, # Level 21
	24500, # Level 22
	29000, # Level 23
	34000, # Level 24
	40000  # Level 25 (max)
]

const MAX_LEVEL: int = 25
const MAX_STAT_LEVEL: int = 5


func add_xp(amount: int) -> void:
	if knight_level >= MAX_LEVEL:
		return
	knight_xp += amount
	EventBus.knight_xp_gained.emit(amount)

	while knight_level < MAX_LEVEL and knight_xp >= xp_for_next_level():
		knight_level += 1
		knight_stat_points += 1
		EventBus.knight_leveled_up.emit(knight_level)

	save_data()


func xp_for_next_level() -> int:
	if knight_level >= MAX_LEVEL:
		return 999999
	return XP_PER_LEVEL[knight_level]


func xp_progress_ratio() -> float:
	if knight_level >= MAX_LEVEL:
		return 1.0
	var current_threshold: int = XP_PER_LEVEL[knight_level - 1] if knight_level > 1 else 0
	var next_threshold: int = XP_PER_LEVEL[knight_level]
	var range_size: int = next_threshold - current_threshold
	if range_size <= 0:
		return 1.0
	return float(knight_xp - current_threshold) / float(range_size)


func upgrade_stat(stat_name: String) -> bool:
	if knight_stat_points <= 0:
		return false
	if not knight_stats.has(stat_name):
		return false
	if knight_stats[stat_name] >= MAX_STAT_LEVEL:
		return false

	knight_stats[stat_name] += 1
	knight_stat_points -= 1
	EventBus.knight_stat_upgraded.emit(stat_name, knight_stats[stat_name])
	save_data()
	return true


# === Calculated Knight Stats (base + stat bonuses) ===

func get_max_hp() -> float:
	return 10.0 + float(knight_stats.get("endurance", 0)) * 3.0

func get_attack_power() -> float:
	return 1.0 + float(knight_stats.get("strength", 0)) * 0.5

func get_armor() -> float:
	return float(knight_stats.get("defense", 0)) * 0.3

func get_dodge_chance() -> float:
	return float(knight_stats.get("agility", 0)) * 0.06

func get_gold_multiplier() -> float:
	return 1.0 + float(knight_stats.get("wisdom", 0)) * 0.15

func get_chest_quality_bonus() -> int:
	return knight_stats.get("wisdom", 0)


# === Diamonds ===

func add_diamonds(amount: int) -> void:
	diamonds += amount
	EventBus.diamonds_earned.emit(amount)
	save_data()


func spend_diamonds(amount: int) -> bool:
	if diamonds < amount:
		return false
	diamonds -= amount
	save_data()
	return true


# === Cosmetics ===

func unlock_cosmetic(cosmetic_id: String) -> void:
	if cosmetic_id not in unlocked_cosmetics:
		unlocked_cosmetics.append(cosmetic_id)
		EventBus.cosmetic_unlocked.emit(cosmetic_id)
		save_data()


func equip_cosmetic(cosmetic_id: String, slot: String) -> void:
	if cosmetic_id in unlocked_cosmetics and equipped_cosmetics.has(slot):
		equipped_cosmetics[slot] = cosmetic_id
		EventBus.cosmetic_equipped.emit(cosmetic_id, slot)
		save_data()


func unequip_cosmetic(slot: String) -> void:
	if equipped_cosmetics.has(slot):
		equipped_cosmetics[slot] = ""
		save_data()


func is_cosmetic_unlocked(cosmetic_id: String) -> bool:
	return cosmetic_id in unlocked_cosmetics


# === Highscores ===

func add_highscore(stats: Dictionary) -> bool:
	best_scores.append(stats)
	best_scores.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.get("score", 0) > b.get("score", 0)
	)
	if best_scores.size() > 10:
		best_scores.resize(10)
	save_data()
	return best_scores.has(stats)


func get_best_score() -> int:
	if best_scores.is_empty():
		return 0
	return best_scores[0].get("score", 0)


# === Save / Load ===

func save_data() -> void:
	var data: Dictionary = {
		"version": 2,
		"diamonds": diamonds,
		"gold": gold,
		"wood": wood,
		"weapon_affix": weapon_affix,
		"forge_level": forge_level,
		"lumber_level": lumber_level,
		"total_gold_earned": total_gold_earned,
		"total_runs_completed": total_runs_completed,
		"total_runs_started": total_runs_started,
		"knight_level": knight_level,
		"knight_xp": knight_xp,
		"knight_stat_points": knight_stat_points,
		"knight_stats": knight_stats,
		"unlocked_cosmetics": unlocked_cosmetics,
		"equipped_cosmetics": equipped_cosmetics,
		"best_scores": best_scores,
		"tutorial_tips_enabled": tutorial_tips_enabled,
		"sfx_enabled": sfx_enabled,
		"music_enabled": music_enabled,
		"render_mode_3d_shader": render_mode_3d_shader
	}

	var json_string: String = JSON.stringify(data, "\t")
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()


func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return

	var json_string: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var error: Error = json.parse(json_string)
	if error != OK:
		push_warning("SaveManager: Failed to parse save file: " + json.get_error_message())
		return

	var data: Variant = json.data
	if not data is Dictionary:
		return

	var d: Dictionary = data as Dictionary

	diamonds = d.get("diamonds", 0)
	gold = d.get("gold", 0)
	wood = d.get("wood", 0)
	weapon_affix = str(d.get("weapon_affix", ""))
	forge_level = d.get("forge_level", 1)
	lumber_level = d.get("lumber_level", 1)
	total_gold_earned = d.get("total_gold_earned", 0)
	total_runs_completed = d.get("total_runs_completed", 0)
	total_runs_started = d.get("total_runs_started", 0)
	knight_level = d.get("knight_level", 1)
	knight_xp = d.get("knight_xp", 0)
	knight_stat_points = d.get("knight_stat_points", 0)

	if d.has("knight_stats") and d["knight_stats"] is Dictionary:
		for key in d["knight_stats"]:
			if knight_stats.has(key):
				knight_stats[key] = int(d["knight_stats"][key])

	if d.has("unlocked_cosmetics") and d["unlocked_cosmetics"] is Array:
		unlocked_cosmetics.clear()
		for item in d["unlocked_cosmetics"]:
			unlocked_cosmetics.append(str(item))

	if d.has("equipped_cosmetics") and d["equipped_cosmetics"] is Dictionary:
		for key in d["equipped_cosmetics"]:
			if equipped_cosmetics.has(key):
				equipped_cosmetics[key] = str(d["equipped_cosmetics"][key])

	if d.has("best_scores") and d["best_scores"] is Array:
		best_scores.clear()
		for entry in d["best_scores"]:
			if entry is Dictionary:
				best_scores.append(entry)

	tutorial_tips_enabled = d.get("tutorial_tips_enabled", true)
	sfx_enabled = d.get("sfx_enabled", true)
	music_enabled = d.get("music_enabled", true)
	render_mode_3d_shader = d.get("render_mode_3d_shader", true)


func set_render_mode_3d_shader(enabled: bool) -> void:
	if render_mode_3d_shader != enabled:
		render_mode_3d_shader = enabled
		save_data()
		render_mode_changed.emit(render_mode_3d_shader)


func toggle_render_mode_3d_shader() -> bool:
	set_render_mode_3d_shader(!render_mode_3d_shader)
	return render_mode_3d_shader


func reset_all_data() -> void:
	diamonds = 0
	gold = 0
	wood = 0
	weapon_affix = ""
	forge_level = 1
	lumber_level = 1
	total_gold_earned = 0
	total_runs_completed = 0
	total_runs_started = 0
	knight_level = 1
	knight_xp = 0
	knight_stat_points = 0
	knight_stats = {"strength": 0, "endurance": 0, "defense": 0, "agility": 0, "wisdom": 0}
	unlocked_cosmetics.clear()
	equipped_cosmetics = {"sword": "", "helmet": "", "hat": "", "victory_anim": ""}
	best_scores.clear()
	tutorial_tips_enabled = true
	sfx_enabled = true
	music_enabled = true
	save_data()
