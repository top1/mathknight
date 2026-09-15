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
var bread: int = 0
var weapon_affix: String = "" # "flame", "frost", "greed", "storm"
var forge_level: int = 1
var lumber_level: int = 1
var bakery_level: int = 1

# === Village Economy ===
var hut_count: int = 0              # Gebaute Hütten
var villagers: int = 0              # Aktuelle Dorfbewohner
var soldiers: int = 0               # Permanente Soldaten (wachsend!)
var weapons_stock: int = 0          # Waffen aus der Schmiede
var last_tax_time_msec: int = 0     # Timestamp letzte Steuereinnahme (5 Min Cooldown)


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


func add_bread(amount: int) -> void:
	if amount <= 0:
		return
	bread += amount
	save_data()
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").bread_changed.emit(bread)


func spend_bread(amount: int) -> bool:
	if amount <= 0:
		return true
	if bread >= amount:
		bread -= amount
		save_data()
		if has_node("/root/EventBus"):
			get_node("/root/EventBus").bread_changed.emit(bread)
		return true
	return false


func set_weapon_affix(affix: String) -> void:
	weapon_affix = affix
	save_data()


const MAX_BUILDING_LEVEL: int = 3

func get_building_level(building: String) -> int:
	match building.to_lower():
		"forge": return forge_level
		"lumber": return lumber_level
		"bakery": return bakery_level
		_: return 1

func get_building_upgrade_cost(building: String) -> Dictionary:
	var cur_level: int = get_building_level(building)
	if cur_level >= MAX_BUILDING_LEVEL:
		return {"gold": 0, "wood": 0, "maxed": true}
	
	if building.to_lower() == "forge":
		if cur_level == 1:
			return {"gold": 100, "wood": 50, "maxed": false}
		else:
			return {"gold": 300, "wood": 150, "maxed": false}
	elif building.to_lower() == "lumber":
		if cur_level == 1:
			return {"gold": 80, "wood": 30, "maxed": false}
		else:
			return {"gold": 250, "wood": 100, "maxed": false}
	elif building.to_lower() == "bakery":
		if cur_level == 1:
			return {"gold": 70, "wood": 40, "maxed": false}
		else:
			return {"gold": 220, "wood": 120, "maxed": false}
	return {"gold": 999, "wood": 999, "maxed": false}

func can_upgrade_building(building: String) -> bool:
	var cost: Dictionary = get_building_upgrade_cost(building)
	if cost.get("maxed", false):
		return false
	return gold >= cost.get("gold", 0) and wood >= cost.get("wood", 0)

func upgrade_building(building: String) -> bool:
	if not can_upgrade_building(building):
		return false
	var cost: Dictionary = get_building_upgrade_cost(building)
	gold -= cost.get("gold", 0)
	wood -= cost.get("wood", 0)
	match building.to_lower():
		"forge":
			forge_level += 1
		"lumber":
			lumber_level += 1
		"bakery":
			bakery_level += 1
	save_data()
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").gold_changed.emit(gold)
	return true


# =========================================================================
# VILLAGE ECONOMY — Hütten, Bewohner, Steuern, Waffen, Soldaten
# =========================================================================

const TAX_COOLDOWN_MSEC: int = 300_000  # 5 Minuten in Millisekunden
const TAX_GOLD_PER_VILLAGER: int = 3
const VILLAGERS_PER_HUT: int = 5
const BASE_VILLAGER_CAPACITY: int = 10  # Burg-Basiskapazität
const SOLDIER_RECRUIT_GOLD_COST: int = 5

## Max Hütten basierend auf Ritter-Level
func get_max_huts() -> int:
	if knight_level < 2:
		return 0
	elif knight_level < 5:
		return 1
	elif knight_level < 8:
		return 2
	elif knight_level < 10:
		return 3
	elif knight_level < 15:
		return 4
	elif knight_level < 20:
		return 5
	elif knight_level < 25:
		return 6
	elif knight_level < 30:
		return 8
	else:
		return 10


## Max Bewohner: Burg-Basis + Hütten * 5
func get_max_villagers() -> int:
	return BASE_VILLAGER_CAPACITY + hut_count * VILLAGERS_PER_HUT


## Kosten für die nächste Hütte (steigende Kosten)
func get_hut_cost() -> Dictionary:
	return {
		"wood": 20 + hut_count * 10,
		"gold": 10 + hut_count * 5
	}


## Kann eine Hütte gebaut werden?
func can_build_hut() -> bool:
	if hut_count >= get_max_huts():
		return false
	var cost: Dictionary = get_hut_cost()
	return wood >= cost["wood"] and gold >= cost["gold"]


## Hütte bauen
func build_hut() -> bool:
	if not can_build_hut():
		return false
	var cost: Dictionary = get_hut_cost()
	wood -= cost["wood"]
	gold -= cost["gold"]
	hut_count += 1
	save_data()
	if has_node("/root/EventBus"):
		var bus = get_node("/root/EventBus")
		bus.hut_built.emit(hut_count)
		bus.gold_changed.emit(gold)
	return true


## Bewohner automatisch anlocken wenn Platz + Brot vorhanden
## Gibt Anzahl neue Bewohner zurück
func try_attract_villagers() -> int:
	var max_v: int = get_max_villagers()
	var free_slots: int = max_v - villagers
	if free_slots <= 0 or bread <= 0:
		return 0
	# Pro Einzug: 1 Brot verbraucht
	var can_attract: int = mini(free_slots, bread)
	# Maximal 3 auf einmal (damit es sich nach und nach füllt)
	can_attract = mini(can_attract, 3)
	bread -= can_attract
	villagers += can_attract
	save_data()
	if has_node("/root/EventBus"):
		var bus = get_node("/root/EventBus")
		bus.villager_arrived.emit(villagers)
		bus.villagers_changed.emit(villagers)
		bus.bread_changed.emit(bread)
	return can_attract


## Können Steuern kassiert werden? (Cooldown + Bewohner + Brot)
func can_collect_taxes() -> bool:
	if villagers <= 0:
		return false
	if bread < villagers:
		return false
	var now: int = Time.get_ticks_msec()
	return (now - last_tax_time_msec) >= TAX_COOLDOWN_MSEC


## Verbleibende Cooldown-Zeit in Sekunden
func get_tax_cooldown_remaining() -> float:
	var now: int = Time.get_ticks_msec()
	var elapsed: int = now - last_tax_time_msec
	if elapsed >= TAX_COOLDOWN_MSEC:
		return 0.0
	return float(TAX_COOLDOWN_MSEC - elapsed) / 1000.0


## Steuern kassieren: Brot verbrauchen, Gold generieren
func collect_taxes() -> int:
	if not can_collect_taxes():
		return 0
	var fed: int = mini(villagers, bread)
	bread -= fed
	var tax_gold: int = fed * TAX_GOLD_PER_VILLAGER
	gold += tax_gold
	total_gold_earned += tax_gold
	last_tax_time_msec = Time.get_ticks_msec()
	save_data()
	if has_node("/root/EventBus"):
		var bus = get_node("/root/EventBus")
		bus.taxes_collected.emit(tax_gold, fed)
		bus.gold_changed.emit(gold)
		bus.bread_changed.emit(bread)
	return tax_gold


## Waffen aus der Schmiede hinzufügen
func add_weapons(amount: int) -> void:
	if amount <= 0:
		return
	weapons_stock += amount
	save_data()
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").weapons_changed.emit(weapons_stock)


## Kann ein Soldat rekrutiert werden?
func can_recruit_soldier() -> bool:
	return villagers >= 1 and weapons_stock >= 1 and gold >= SOLDIER_RECRUIT_GOLD_COST


## Soldat rekrutieren: 1 Bewohner + 1 Waffe + 5 Gold → 1 Soldat
func recruit_soldier() -> bool:
	if not can_recruit_soldier():
		return false
	villagers -= 1
	weapons_stock -= 1
	gold -= SOLDIER_RECRUIT_GOLD_COST
	soldiers += 1
	save_data()
	if has_node("/root/EventBus"):
		var bus = get_node("/root/EventBus")
		bus.soldier_recruited.emit(soldiers)
		bus.soldiers_changed.emit(soldiers)
		bus.villagers_changed.emit(villagers)
		bus.weapons_changed.emit(weapons_stock)
		bus.gold_changed.emit(gold)
	return true


## Soldaten direkt hinzufügen (z.B. Siege-Reward)
func add_soldiers(amount: int) -> void:
	if amount <= 0:
		return
	soldiers += amount
	save_data()
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").soldiers_changed.emit(soldiers)


# Knight permanent stats
var knight_level: int = 1
var knight_xp: int = 0
var knight_stat_points: int = 0
var knight_stats: Dictionary = {
	"strength": 0,     # +Attack damage
	"endurance": 0,    # +Max HP
	"defense": 0,      # +Armor
	"agility": 0,      # +Dodge chance
	"wisdom": 0,       # +Gold drop rate, +Chest quality
	"focus": 0,        # +Crit chance (+3% per point)
	"crafting": 0      # +Forge & Lumber quality bonus (+5% per point)
}

# Royal Mastery Badges & Arena Tracking
var mastery_badges: Array[String] = []
var arena_last_played_date: String = ""
var best_arena_wave: int = 0

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
var master_muted: bool = false
var sfx_enabled: bool = true
var music_enabled: bool = true
var render_mode_3d_shader: bool = true


func _ready() -> void:
	load_data()


# === XP & Level System (1 - 50) ===

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
	40000, # Level 25
	47000, # Level 26
	55000, # Level 27
	64000, # Level 28
	74000, # Level 29
	85000, # Level 30
	97000, # Level 31
	110000, # Level 32
	124000, # Level 33
	139000, # Level 34
	155000, # Level 35
	172000, # Level 36
	190000, # Level 37
	209000, # Level 38
	229000, # Level 39
	250000, # Level 40
	272000, # Level 41
	295000, # Level 42
	319000, # Level 43
	344000, # Level 44
	370000, # Level 45
	397000, # Level 46
	425000, # Level 47
	454000, # Level 48
	484000, # Level 49
	515000  # Level 50 (max)
]

const MAX_LEVEL: int = 50
const MAX_STAT_LEVEL: int = 10


func add_xp(amount: int) -> void:
	if knight_level >= MAX_LEVEL:
		return
	knight_xp += amount
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").knight_xp_gained.emit(amount)

	while knight_level < MAX_LEVEL and knight_xp >= xp_for_next_level():
		knight_level += 1
		knight_stat_points += 1
		if has_node("/root/EventBus"):
			get_node("/root/EventBus").knight_leveled_up.emit(knight_level)

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
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").knight_stat_upgraded.emit(stat_name, knight_stats[stat_name])
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

func get_crit_chance() -> float:
	return 0.05 + (float(knight_stats.get("focus", 0)) * 0.03)

func get_crafting_bonus() -> float:
	return float(knight_stats.get("crafting", 0)) * 0.05

func award_mastery_badge(badge_id: String) -> void:
	if not mastery_badges.has(badge_id):
		mastery_badges.append(badge_id)
		save_data()


# === Diamonds ===

func add_diamonds(amount: int) -> void:
	diamonds += amount
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").diamonds_earned.emit(amount)
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
		if has_node("/root/EventBus"):
			get_node("/root/EventBus").cosmetic_unlocked.emit(cosmetic_id)
		save_data()


func equip_cosmetic(cosmetic_id: String, slot: String) -> void:
	if cosmetic_id in unlocked_cosmetics and equipped_cosmetics.has(slot):
		equipped_cosmetics[slot] = cosmetic_id
		if has_node("/root/EventBus"):
			get_node("/root/EventBus").cosmetic_equipped.emit(cosmetic_id, slot)
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


# === Curriculum Progression (L1 to L6) ===

var highest_unlocked_curriculum: int = 1
var curriculum_progress: Dictionary = {
	"L1": {"stars": 0, "mastered": false, "problems_solved": 0},
	"L2": {"stars": 0, "mastered": false, "problems_solved": 0},
	"L3": {"stars": 0, "mastered": false, "problems_solved": 0},
	"L4": {"stars": 0, "mastered": false, "problems_solved": 0},
	"L5": {"stars": 0, "mastered": false, "problems_solved": 0},
	"L6": {"stars": 0, "mastered": false, "problems_solved": 0}
}


func get_curriculum_progress(level_key: String) -> Dictionary:
	return curriculum_progress.get(level_key, {"stars": 0, "mastered": false, "problems_solved": 0})


func record_curriculum_success(level_idx: int, stars_earned: int = 3) -> void:
	var key = "L%d" % level_idx
	if not curriculum_progress.has(key):
		curriculum_progress[key] = {"stars": 0, "mastered": false, "problems_solved": 0}
	var entry = curriculum_progress[key]
	entry["problems_solved"] = entry.get("problems_solved", 0) + 1
	entry["stars"] = max(entry.get("stars", 0), stars_earned)
	if entry["stars"] >= 3:
		entry["mastered"] = true
		if level_idx >= highest_unlocked_curriculum and level_idx < 6:
			highest_unlocked_curriculum = level_idx + 1
	save_data()


# === Save / Load ===

func save_data() -> void:
	var data: Dictionary = {
		"version": 3,
		"diamonds": diamonds,
		"gold": gold,
		"wood": wood,
		"bread": bread,
		"weapon_affix": weapon_affix,
		"forge_level": forge_level,
		"lumber_level": lumber_level,
		"bakery_level": bakery_level,
		# Village Economy
		"hut_count": hut_count,
		"villagers": villagers,
		"soldiers": soldiers,
		"weapons_stock": weapons_stock,
		"last_tax_time_msec": last_tax_time_msec,
		# Stats & tracking
		"mastery_badges": mastery_badges,
		"arena_last_played_date": arena_last_played_date,
		"best_arena_wave": best_arena_wave,
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
		"master_muted": master_muted,
		"sfx_enabled": sfx_enabled,
		"music_enabled": music_enabled,
		"render_mode_3d_shader": render_mode_3d_shader,
		"highest_unlocked_curriculum": highest_unlocked_curriculum,
		"curriculum_progress": curriculum_progress
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
	bread = d.get("bread", 0)
	weapon_affix = str(d.get("weapon_affix", ""))
	forge_level = d.get("forge_level", 1)
	lumber_level = d.get("lumber_level", 1)
	bakery_level = d.get("bakery_level", 1)
	# Village Economy (v3 migration: defaults to 0 for v2 saves)
	hut_count = int(d.get("hut_count", 0))
	villagers = int(d.get("villagers", 0))
	soldiers = int(d.get("soldiers", 0))
	weapons_stock = int(d.get("weapons_stock", 0))
	last_tax_time_msec = int(d.get("last_tax_time_msec", 0))
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

	if d.has("mastery_badges") and d["mastery_badges"] is Array:
		mastery_badges.clear()
		for b in d["mastery_badges"]:
			mastery_badges.append(str(b))

	arena_last_played_date = str(d.get("arena_last_played_date", ""))
	best_arena_wave = int(d.get("best_arena_wave", 0))

	tutorial_tips_enabled = d.get("tutorial_tips_enabled", true)
	master_muted = d.get("master_muted", false)
	sfx_enabled = d.get("sfx_enabled", true)
	music_enabled = d.get("music_enabled", true)
	render_mode_3d_shader = d.get("render_mode_3d_shader", true)
	highest_unlocked_curriculum = int(d.get("highest_unlocked_curriculum", 1))

	if d.has("curriculum_progress") and d["curriculum_progress"] is Dictionary:
		for key in d["curriculum_progress"]:
			curriculum_progress[key] = d["curriculum_progress"][key]


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
	# Village Economy reset
	hut_count = 0
	villagers = 0
	soldiers = 0
	weapons_stock = 0
	last_tax_time_msec = 0
	total_gold_earned = 0
	total_runs_completed = 0
	total_runs_started = 0
	knight_level = 1
	knight_xp = 0
	knight_stat_points = 0
	knight_stats = {"strength": 0, "endurance": 0, "defense": 0, "agility": 0, "wisdom": 0, "focus": 0, "crafting": 0}
	mastery_badges.clear()
	arena_last_played_date = ""
	best_arena_wave = 0
	unlocked_cosmetics.clear()
	equipped_cosmetics = {"sword": "", "helmet": "", "hat": "", "victory_anim": ""}
	best_scores.clear()
	tutorial_tips_enabled = true
	sfx_enabled = true
	music_enabled = true
	save_data()
