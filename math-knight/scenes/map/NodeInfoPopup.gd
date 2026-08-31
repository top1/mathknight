extends Control
class_name NodeInfoPopup

signal confirmed(node_data: Dictionary)
signal canceled

@onready var title_label = $Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var combat_info = $Panel/MarginContainer/VBoxContainer/CombatInfo
@onready var op_label = $Panel/MarginContainer/VBoxContainer/CombatInfo/RechenartLabel
@onready var challenge_label = $Panel/MarginContainer/VBoxContainer/CombatInfo/ChallengeLabel
@onready var diff_label = $Panel/MarginContainer/VBoxContainer/CombatInfo/DifficultyLabel
@onready var example_label = $Panel/MarginContainer/VBoxContainer/CombatInfo/ExamplePanel/Margin/ExampleLabel
@onready var enemy_label = $Panel/MarginContainer/VBoxContainer/CombatInfo/StatsRow/EnemyLabel
@onready var reward_label = $Panel/MarginContainer/VBoxContainer/CombatInfo/StatsRow/RewardLabel

@onready var non_combat_info = $Panel/MarginContainer/VBoxContainer/NonCombatInfo
@onready var non_combat_desc_label = $Panel/MarginContainer/VBoxContainer/NonCombatInfo/NonCombatDescLabel

@onready var confirm_button = $Panel/MarginContainer/VBoxContainer/HBoxContainer/ConfirmButton
@onready var cancel_button = $Panel/MarginContainer/VBoxContainer/HBoxContainer/CancelButton

var _current_node_data: Dictionary

func _ready() -> void:
	confirm_button.pressed.connect(_on_confirm_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	hide()

func show_popup(node_data: Dictionary) -> void:
	_current_node_data = node_data
	
	var type = node_data.get("type", "combat")
	var is_combat = type in ["combat", "elite", "boss"]
	
	# Title
	match type:
		"combat":
			title_label.text = "⚔ KAMPF"
			title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3))
		"elite":
			title_label.text = "💀 ELITE-KAMPF"
			title_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
		"boss":
			var boss_name = node_data.get("boss_name", "")
			if boss_name != "":
				title_label.text = "👹 BOSS: " + boss_name.to_upper()
			else:
				title_label.text = "👹 BOSS-KAMPF"
			title_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		"shop":
			title_label.text = "🏪 HÄNDLER"
			title_label.add_theme_color_override("font_color", Color(0.4, 0.95, 0.5))
		"rest":
			title_label.text = "⛺ RASTPLATZ"
			title_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
		_:
			title_label.text = "⚔ KAMPF"
			title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3))
	
	if is_combat:
		combat_info.show()
		non_combat_info.hide()
		
		# 1. Rechenart
		var op = node_data.get("math_operation", 0)
		var op_name = ""
		var op_symbol = ""
		match op:
			0:
				op_name = "Addition"
				op_symbol = "(+)"
			1:
				op_name = "Subtraktion"
				op_symbol = "(-)"
			2:
				op_name = "Multiplikation"
				op_symbol = "(×)"
			3:
				op_name = "Division"
				op_symbol = "(÷)"
			4:
				op_name = "Gemischt"
				op_symbol = "(+ - × ÷)"
			_:
				op_name = "Addition"
				op_symbol = "(+)"
		op_label.text = "Rechenart: " + op_name + " " + op_symbol
		
		# 2. Challenge / Modus
		var mode_val = node_data.get("math_mode", 0)
		var mode_name = ""
		var mode_hint = ""
		var example_str = ""
		
		match mode_val:
			0: # TASK_TO_RESULT
				mode_name = "Rechen-Schlag"
				mode_hint = "Ergebnis lösen"
				match op:
					0: example_str = "z.B.  7 + 8 = ?"
					1: example_str = "z.B.  15 - 6 = ?"
					2: example_str = "z.B.  4 × 6 = ?"
					3: example_str = "z.B.  24 ÷ 4 = ?"
					_: example_str = "z.B.  8 + 5 = ?"
			1: # RESULT_TO_EQUATION
				mode_name = "Zahlen-Schmiede"
				mode_hint = "Rechnung finden"
				match op:
					0: example_str = "z.B.  ? = 14  ➔  (8 + 6)"
					1: example_str = "z.B.  ? = 9   ➔  (15 - 6)"
					2: example_str = "z.B.  ? = 24  ➔  (4 × 6)"
					3: example_str = "z.B.  ? = 6   ➔  (24 ÷ 4)"
					_: example_str = "z.B.  ? = 12  ➔  (7 + 5)"
			2: # MULTI_OP_EQUATION
				mode_name = "Meister-Kette"
				mode_hint = "Kettenrechnung"
				match op:
					0: example_str = "z.B.  3 + 4 + 5 = ?"
					1: example_str = "z.B.  12 - 3 - 2 = ?"
					_: example_str = "z.B.  2 × 3 + 4 = ?"
			_:
				mode_name = "Rechen-Schlag"
				mode_hint = "Ergebnis lösen"
				example_str = "z.B.  7 + 8 = ?"
				
		challenge_label.text = "Challenge: " + mode_name + " (" + mode_hint + ")"
		example_label.text = "Vorschau:  " + example_str
		
		# 3. Schwierigkeit
		var diff = node_data.get("math_difficulty", 0)
		var diff_str = ""
		match diff:
			0: diff_str = "Leicht ★☆☆ (Zahlenraum 1–10)"
			1: diff_str = "Mittel ★★☆ (Zahlenraum 1–20)"
			2: diff_str = "Schwer ★★★ (Zahlenraum 1–50)"
			_: diff_str = "Leicht ★☆☆ (Zahlenraum 1–10)"
		diff_label.text = "Stufe: " + diff_str
		
		# 4. Gegner
		var enemy_count = node_data.get("enemy_count", 3)
		if type == "boss":
			var phases = node_data.get("boss_phases", 3)
			enemy_label.text = "👹 " + str(phases) + " Phasen"
		else:
			enemy_label.text = "👾 " + str(enemy_count) + " Gegner"
			
		# 5. Belohnung
		var reward_gold = node_data.get("reward_gold", 0)
		var reward_text = "🪙 " + str(reward_gold) + " Gold"
		if node_data.get("reward_chest_chance", 0.0) > 0:
			reward_text += " + 📦 Truhe"
		reward_label.text = reward_text
		
		confirm_button.text = "Kämpfen!"
	else:
		combat_info.hide()
		non_combat_info.show()
		
		if type == "shop":
			non_combat_desc_label.text = "🏪 Händler\n\nKaufe Tränke, Buffs und neue Ausrüstung für Gold!"
			confirm_button.text = "Einkaufen"
		elif type == "rest":
			non_combat_desc_label.text = "⛺ Rastplatz am Lagerfeuer\n\nRuhe dich aus und regeneriere +40% deiner maximalen LP."
			confirm_button.text = "Rasten (+40% ❤)"
		else:
			non_combat_desc_label.text = "Ort betreten"
			confirm_button.text = "Betreten"
	
	show()

func _on_confirm_pressed() -> void:
	hide()
	confirmed.emit(_current_node_data)

func _on_cancel_pressed() -> void:
	hide()
	canceled.emit()

