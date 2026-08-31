class_name CosmeticDatabase
extends RefCounted
## Database of all unlockable cosmetic items in MathKnight.
## Items are permanently saved in SaveManager.

enum Slot { SWORD, HELMET, HAT, VICTORY_ANIM }
enum Rarity { COMMON, UNCOMMON, RARE, LEGENDARY }

static var _items: Dictionary = {
	# === SWORDS ===
	"sword_iron": {
		"id": "sword_iron",
		"name": "Eisernes Ritterschwert",
		"slot": "sword",
		"slot_enum": Slot.SWORD,
		"rarity": Rarity.COMMON,
		"rarity_name": "Gewöhnlich",
		"rarity_color": Color(0.7, 0.7, 0.75),
		"cost_diamonds": 0,
		"unlocked_by_default": true,
		"desc": "Das treue Standardschwert eines jeden Ritters.",
		"color": Color(0.85, 0.85, 0.9)
	},
	"sword_flame": {
		"id": "sword_flame",
		"name": "Flammenklinge",
		"slot": "sword",
		"slot_enum": Slot.SWORD,
		"rarity": Rarity.RARE,
		"rarity_name": "Selten",
		"rarity_color": Color(1.0, 0.45, 0.15),
		"cost_diamonds": 5,
		"unlocked_by_default": false,
		"desc": "Glüht vor feuriger Rechenpower.",
		"color": Color(1.0, 0.35, 0.1)
	},
	"sword_frost": {
		"id": "sword_frost",
		"name": "Frost-Klinge",
		"slot": "sword",
		"slot_enum": Slot.SWORD,
		"rarity": Rarity.UNCOMMON,
		"rarity_name": "Ungewöhnlich",
		"rarity_color": Color(0.2, 0.8, 1.0),
		"cost_diamonds": 3,
		"unlocked_by_default": false,
		"desc": "Kühlt selbst die heißesten Matheaufgaben ab.",
		"color": Color(0.3, 0.85, 1.0)
	},
	"sword_gold": {
		"id": "sword_gold",
		"name": "Goldene Königs-Klinge",
		"slot": "sword",
		"slot_enum": Slot.SWORD,
		"rarity": Rarity.LEGENDARY,
		"rarity_name": "Legendär",
		"rarity_color": Color(1.0, 0.85, 0.2),
		"cost_diamonds": 12,
		"unlocked_by_default": false,
		"desc": "Aus purem Gold geschmiedet für wahre Rechenmeister.",
		"color": Color(1.0, 0.85, 0.2)
	},
	"sword_lightsaber": {
		"id": "sword_lightsaber",
		"name": "Plasma-Lichtschwert",
		"slot": "sword",
		"slot_enum": Slot.SWORD,
		"rarity": Rarity.LEGENDARY,
		"rarity_name": "Legendär",
		"rarity_color": Color(0.2, 1.0, 0.85),
		"cost_diamonds": 15,
		"unlocked_by_default": false,
		"desc": "Möge die Rechenkraft mit dir sein! Summt bei jedem Schwung.",
		"color": Color(0.2, 1.0, 0.9)
	},
	"sword_pan": {
		"id": "sword_pan",
		"name": "Ritter-Bratpfanne",
		"slot": "sword",
		"slot_enum": Slot.SWORD,
		"rarity": Rarity.UNCOMMON,
		"rarity_name": "Ungewöhnlich",
		"rarity_color": Color(0.2, 0.8, 1.0),
		"cost_diamonds": 3,
		"unlocked_by_default": false,
		"desc": "Bratet selbst die zähesten Mathe-Gegner gar!",
		"color": Color(0.6, 0.6, 0.7)
	},

	# === HELMETS ===
	"helm_knight": {
		"id": "helm_knight",
		"name": "Standard Visierhelm",
		"slot": "helmet",
		"slot_enum": Slot.HELMET,
		"rarity": Rarity.COMMON,
		"rarity_name": "Gewöhnlich",
		"rarity_color": Color(0.7, 0.7, 0.75),
		"cost_diamonds": 0,
		"unlocked_by_default": true,
		"desc": "Solider Kopfschutz aus gehärtetem Stahl.",
		"color": Color(0.75, 0.75, 0.8)
	},
	"helm_viking": {
		"id": "helm_viking",
		"name": "Wikinger-Hörnerhelm",
		"slot": "helmet",
		"slot_enum": Slot.HELMET,
		"rarity": Rarity.UNCOMMON,
		"rarity_name": "Ungewöhnlich",
		"rarity_color": Color(0.2, 0.8, 1.0),
		"cost_diamonds": 4,
		"unlocked_by_default": false,
		"desc": "Furchteinflößende Hörner des Nordens.",
		"color": Color(0.85, 0.65, 0.4)
	},
	"helm_crown": {
		"id": "helm_crown",
		"name": "Königskrone",
		"slot": "helmet",
		"slot_enum": Slot.HELMET,
		"rarity": Rarity.LEGENDARY,
		"rarity_name": "Legendär",
		"rarity_color": Color(1.0, 0.85, 0.2),
		"cost_diamonds": 10,
		"unlocked_by_default": false,
		"desc": "Mit Rubinen und Saphiren besetzt.",
		"color": Color(1.0, 0.82, 0.2)
	},

	# === HATS ===
	"hat_none": {
		"id": "hat_none",
		"name": "Kein Hut",
		"slot": "hat",
		"slot_enum": Slot.HAT,
		"rarity": Rarity.COMMON,
		"rarity_name": "Gewöhnlich",
		"rarity_color": Color(0.7, 0.7, 0.75),
		"cost_diamonds": 0,
		"unlocked_by_default": true,
		"desc": "Freier Blick auf den Helm.",
		"color": Color.WHITE
	},
	"hat_wizard": {
		"id": "hat_wizard",
		"name": "Zaubererhut",
		"slot": "hat",
		"slot_enum": Slot.HAT,
		"rarity": Rarity.RARE,
		"rarity_name": "Selten",
		"rarity_color": Color(1.0, 0.45, 0.15),
		"cost_diamonds": 6,
		"unlocked_by_default": false,
		"desc": "Verleiht dem Ritter arithmetische Magie.",
		"color": Color(0.4, 0.2, 0.8)
	},
	"hat_jester": {
		"id": "hat_jester",
		"name": "Narrenkappe",
		"slot": "hat",
		"slot_enum": Slot.HAT,
		"rarity": Rarity.UNCOMMON,
		"rarity_name": "Ungewöhnlich",
		"rarity_color": Color(0.2, 0.8, 1.0),
		"cost_diamonds": 4,
		"unlocked_by_default": false,
		"desc": "Klingelt bei jeder gelösten Gleichung.",
		"color": Color(0.9, 0.3, 0.5)
	},
	"hat_propeller": {
		"id": "hat_propeller",
		"name": "Propellermütze",
		"slot": "hat",
		"slot_enum": Slot.HAT,
		"rarity": Rarity.RARE,
		"rarity_name": "Selten",
		"rarity_color": Color(1.0, 0.45, 0.15),
		"cost_diamonds": 6,
		"unlocked_by_default": false,
		"desc": "Dreht sich im Wind und hebt die Rechenstimmung.",
		"color": Color(1.0, 0.8, 0.1)
	},
	"hat_sunglasses": {
		"id": "hat_sunglasses",
		"name": "Deal-With-It Brille",
		"slot": "hat",
		"slot_enum": Slot.HAT,
		"rarity": Rarity.LEGENDARY,
		"rarity_name": "Legendär",
		"rarity_color": Color(1.0, 0.85, 0.2),
		"cost_diamonds": 10,
		"unlocked_by_default": false,
		"desc": "Coole 8-Bit Pixel-Sonnenbrille für lässige Mathe-Cracks.",
		"color": Color(0.1, 0.1, 0.1)
	},

	# === VICTORY ANIMATIONS ===
	"anim_confetti": {
		"id": "anim_confetti",
		"name": "Konfetti-Regen",
		"slot": "victory_anim",
		"slot_enum": Slot.VICTORY_ANIM,
		"rarity": Rarity.COMMON,
		"rarity_name": "Gewöhnlich",
		"rarity_color": Color(0.7, 0.7, 0.75),
		"cost_diamonds": 0,
		"unlocked_by_default": true,
		"desc": "Bunte Konfetti-Explosion beim Sieg.",
		"color": Color(0.3, 1.0, 0.5)
	},
	"anim_fireworks": {
		"id": "anim_fireworks",
		"name": "Königliches Feuerwerk",
		"slot": "victory_anim",
		"slot_enum": Slot.VICTORY_ANIM,
		"rarity": Rarity.RARE,
		"rarity_name": "Selten",
		"rarity_color": Color(1.0, 0.45, 0.15),
		"cost_diamonds": 7,
		"unlocked_by_default": false,
		"desc": "Erhellt den Nachthimmel mit leuchtenden Raketen.",
		"color": Color(1.0, 0.8, 0.2)
	},
	"anim_thunder": {
		"id": "anim_thunder",
		"name": "Donnerschlag der Götter",
		"slot": "victory_anim",
		"slot_enum": Slot.VICTORY_ANIM,
		"rarity": Rarity.LEGENDARY,
		"rarity_name": "Legendär",
		"rarity_color": Color(1.0, 0.85, 0.2),
		"cost_diamonds": 15,
		"unlocked_by_default": false,
		"desc": "Mächtige Blitze zucken bei deinem Triumph.",
		"color": Color(0.4, 0.9, 1.0)
	}
}

static func get_all_items() -> Dictionary:
	return _items

static func get_item(id: String) -> Dictionary:
	return _items.get(id, {})

static func get_items_by_slot(slot: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in _items.values():
		if item.get("slot", "") == slot:
			result.append(item)
	return result

static func get_random_item_by_rarity(rarity: Rarity) -> Dictionary:
	var pool: Array[Dictionary] = []
	for item in _items.values():
		if item.get("rarity", Rarity.COMMON) == rarity and not item.get("unlocked_by_default", false):
			pool.append(item)
	if pool.is_empty():
		return _items["sword_frost"]
	return pool.pick_random()
