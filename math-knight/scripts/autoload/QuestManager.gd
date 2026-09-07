extends Node
## QuestManager singleton — manages 3 daily quests + 1 weekly quest.
## Tracks problem solving, monster slays, forge crafting, and lumber precision.

const SAVE_PATH: String = "user://mathknight_quests.json"

var current_day: String = ""
var current_week: String = ""
var active_quests: Array[Dictionary] = []

signal quest_updated(quest_id: String, current: int, target: int)
signal quest_completed(quest_id: String)

func _ready() -> void:
	load_quest_data()
	_verify_quest_rotation()
	_connect_event_bus()

func _connect_event_bus() -> void:
	if not has_node("/root/EventBus"):
		return
	var bus = get_node("/root/EventBus")
	bus.answer_correct.connect(_on_answer_correct)
	bus.enemy_defeated.connect(_on_enemy_defeated)
	bus.forge_item_crafted.connect(_on_forge_crafted)
	bus.lumber_cut_completed.connect(_on_lumber_cut)

func _get_current_day_stamp() -> String:
	return Time.get_date_string_from_system()

func _get_current_week_stamp() -> String:
	var dt = Time.get_datetime_dict_from_system()
	var year = dt.get("year", 2026)
	var month = dt.get("month", 1)
	var day = dt.get("day", 1)
	var approx_week = (month - 1) * 4 + int(day / 7)
	return "%d-W%d" % [year, approx_week]

func _verify_quest_rotation() -> void:
	var today = _get_current_day_stamp()
	var this_week = _get_current_week_stamp()
	
	var needs_save = false
	
	if current_day != today:
		current_day = today
		_regenerate_daily_quests()
		needs_save = true
		
	if current_week != this_week:
		current_week = this_week
		_regenerate_weekly_quest()
		needs_save = true
		
	if needs_save:
		save_quest_data()

func _regenerate_daily_quests() -> void:
	# Keep weekly quests, remove old daily quests
	var preserved_quests: Array[Dictionary] = []
	for q in active_quests:
		if q.get("type", "") == "weekly":
			preserved_quests.append(q)
	active_quests = preserved_quests
	
	# Quest 1: Math calculation prowess
	active_quests.append({
		"id": "daily_math_" + current_day,
		"type": "daily",
		"category": "math",
		"title": "Kopfrechen-Kunde",
		"desc": "Löse 15 Rechenaufgaben fehlerfrei",
		"current": 0,
		"target": 15,
		"reward_gold": 50,
		"reward_wood": 0,
		"reward_xp": 30,
		"reward_diamonds": 0,
		"completed": false,
		"claimed": false
	})
	
	# Quest 2: Monster slaying
	active_quests.append({
		"id": "daily_slay_" + current_day,
		"type": "daily",
		"category": "defeat",
		"title": "Monsterjagd",
		"desc": "Besiege 8 Ungeheuer im Kerker",
		"current": 0,
		"target": 8,
		"reward_gold": 60,
		"reward_wood": 10,
		"reward_xp": 35,
		"reward_diamonds": 0,
		"completed": false,
		"claimed": false
	})
	
	# Quest 3: Village craftsmanship (random forge or lumber)
	var village_variant = randi() % 2
	if village_variant == 0:
		active_quests.append({
			"id": "daily_forge_" + current_day,
			"type": "daily",
			"category": "forge",
			"title": "Klingenschmied",
			"desc": "Schmiede 1 magische Klinge bei Brok",
			"current": 0,
			"target": 1,
			"reward_gold": 40,
			"reward_wood": 20,
			"reward_xp": 25,
			"reward_diamonds": 0,
			"completed": false,
			"claimed": false
		})
	else:
		active_quests.append({
			"id": "daily_lumber_" + current_day,
			"type": "daily",
			"category": "lumber",
			"title": "Holzhacker",
			"desc": "Führe 3 Präzisionsschnitte im Sägewerk durch",
			"current": 0,
			"target": 3,
			"reward_gold": 35,
			"reward_wood": 25,
			"reward_xp": 25,
			"reward_diamonds": 0,
			"completed": false,
			"claimed": false
		})

func _regenerate_weekly_quest() -> void:
	# Remove old weekly quests
	var preserved_quests: Array[Dictionary] = []
	for q in active_quests:
		if q.get("type", "") != "weekly":
			preserved_quests.append(q)
	active_quests = preserved_quests
	
	active_quests.append({
		"id": "weekly_grand_" + current_week,
		"type": "weekly",
		"category": "math",
		"title": "Große Rechen-Meisterschaft",
		"desc": "Löse 50 Rechenaufgaben in dieser Woche",
		"current": 0,
		"target": 50,
		"reward_gold": 250,
		"reward_wood": 100,
		"reward_xp": 120,
		"reward_diamonds": 5,
		"completed": false,
		"claimed": false
	})

func add_progress(category: String, amount: int = 1) -> void:
	var any_changed = false
	for q in active_quests:
		if q.get("category", "") == category and not q.get("completed", false):
			q["current"] = clampi(q.get("current", 0) + amount, 0, q.get("target", 1))
			quest_updated.emit(q.get("id", ""), q["current"], q.get("target", 1))
			any_changed = true
			if q["current"] >= q.get("target", 1):
				q["completed"] = true
				quest_completed.emit(q.get("id", ""))
				if has_node("/root/EventBus"):
					get_node("/root/EventBus").quest_completed.emit(q.get("id", ""))
				
	if any_changed:
		save_quest_data()

func claim_reward(quest_id: String) -> bool:
	for q in active_quests:
		if q.get("id", "") == quest_id:
			if q.get("completed", false) and not q.get("claimed", false):
				q["claimed"] = true
				var gold = q.get("reward_gold", 0)
				var wood = q.get("reward_wood", 0)
				var xp = q.get("reward_xp", 0)
				var diamonds = q.get("reward_diamonds", 0)
				
				if has_node("/root/SaveManager"):
					var sm = get_node("/root/SaveManager")
					if gold > 0: sm.add_gold(gold)
					if wood > 0: sm.add_wood(wood)
					if xp > 0: sm.add_xp(xp)
					if diamonds > 0: sm.add_diamonds(diamonds)
					
				if has_node("/root/EventBus"):
					get_node("/root/EventBus").quest_reward_claimed.emit(quest_id)
				save_quest_data()
				return true
	return false

func _on_answer_correct(_problem: RefCounted, _chain: int) -> void:
	add_progress("math", 1)

func _on_enemy_defeated(_enemy: Node2D) -> void:
	add_progress("defeat", 1)

func _on_forge_crafted(_affix: String) -> void:
	add_progress("forge", 1)

func _on_lumber_cut(_wood: int) -> void:
	add_progress("lumber", 1)

func save_quest_data() -> void:
	var data = {
		"current_day": current_day,
		"current_week": current_week,
		"active_quests": active_quests
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

func load_quest_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var text = file.get_as_text()
	file.close()
	var json = JSON.new()
	if json.parse(text) == OK and json.data is Dictionary:
		var d = json.data as Dictionary
		current_day = str(d.get("current_day", ""))
		current_week = str(d.get("current_week", ""))
		if d.has("active_quests") and d["active_quests"] is Array:
			active_quests.clear()
			for q in d["active_quests"]:
				if q is Dictionary:
					active_quests.append(q)
