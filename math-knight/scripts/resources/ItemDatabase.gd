class_name ItemDatabase
extends RefCounted
## Database of all shop items, potions, and run artifacts in MathKnight.
## Items cost run Gold and last for the current run.

enum ItemType { POTION, ARTIFACT, WEAPON_UPGRADE }

static var _items: Dictionary = {
	# === POTIONS ===
	"potion_heal": {
		"id": "potion_heal",
		"name": "Heiltrank",
		"type": "potion",
		"type_enum": ItemType.POTION,
		"cost_gold": 15,
		"icon": "potion_red",
		"desc": "Stellt sofort 5 Lebenspunkte wieder her.",
		"effect_type": "heal_flat",
		"value": 5.0
	},
	"potion_max_hp": {
		"id": "potion_max_hp",
		"name": "Lebenselixier",
		"type": "potion",
		"type_enum": ItemType.POTION,
		"cost_gold": 25,
		"icon": "potion_green",
		"desc": "Erhöht maximale HP um +4 für diesen Run.",
		"effect_type": "hp_boost",
		"value": 4.0
	},
	"potion_shield": {
		"id": "potion_shield",
		"name": "Schutz-Balsam",
		"type": "potion",
		"type_enum": ItemType.POTION,
		"cost_gold": 20,
		"icon": "shield",
		"desc": "+0.5 Rüstung für den gesamten Run.",
		"effect_type": "armor_boost",
		"value": 0.5
	},

	# === ARTIFACTS ===
	"art_compass": {
		"id": "art_compass",
		"name": "Goldener Kompass",
		"type": "artifact",
		"type_enum": ItemType.ARTIFACT,
		"cost_gold": 30,
		"icon": "compass",
		"desc": "Erhöht alle erhaltenen Goldmünzen um +30%.",
		"effect_type": "gold_boost",
		"value": 0.3
	},
	"art_sharp_stone": {
		"id": "art_sharp_stone",
		"name": "Schleifstein des Meisters",
		"type": "artifact",
		"type_enum": ItemType.ARTIFACT,
		"cost_gold": 35,
		"icon": "stone",
		"desc": "Erhöht den Ritterschaden um +0.8 (effektiv gegen Bosse!).",
		"effect_type": "attack_boost",
		"value": 0.8
	},
	"art_swift_boots": {
		"id": "art_swift_boots",
		"name": "Flügelschuhe",
		"type": "artifact",
		"type_enum": ItemType.ARTIFACT,
		"cost_gold": 25,
		"icon": "boots",
		"desc": "+10% Chance, feindlichen Angriffen auszuweichen.",
		"effect_type": "dodge_boost",
		"value": 0.10
	},
	"art_combo_gem": {
		"id": "art_combo_gem",
		"name": "Kristall des Fokus",
		"type": "artifact",
		"type_enum": ItemType.ARTIFACT,
		"cost_gold": 30,
		"icon": "gem",
		"desc": "Verdoppelt den Punktebonus durch Combos.",
		"effect_type": "combo_boost",
		"value": 2.0
	}
}

static func get_all_items() -> Dictionary:
	return _items

static func get_item(id: String) -> Dictionary:
	return _items.get(id, {})

static func get_random_shop_selection(count: int = 3) -> Array[Dictionary]:
	var keys = _items.keys()
	keys.shuffle()
	var selected: Array[Dictionary] = []
	for i in range(mini(count, keys.size())):
		selected.append(_items[keys[i]])
	return selected
