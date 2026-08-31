class_name ChestReward
extends Control
## Post-run Chest opening mini-game screen.
## Players solve challenging math problems (unlimited time, 1 attempt) to open collected chests.

const CosmeticDB = preload("res://scripts/resources/CosmeticDatabase.gd")

@onready var chest_container: HBoxContainer = $MarginContainer/MainLayout/ChestArea
@onready var challenge_panel: PanelContainer = $MarginContainer/MainLayout/ChallengePanel
@onready var chest_title_label: Label = $MarginContainer/MainLayout/ChallengePanel/VBox/ChestTitle
@onready var problem_label: Label = $MarginContainer/MainLayout/ChallengePanel/VBox/ProblemLabel
@onready var hint_label: Label = $MarginContainer/MainLayout/ChallengePanel/VBox/HintLabel
@onready var choice_row: HBoxContainer = $MarginContainer/MainLayout/ChallengePanel/VBox/ChoiceRow
@onready var result_label: Label = $MarginContainer/MainLayout/ChallengePanel/VBox/ResultLabel
@onready var continue_btn: Button = $MarginContainer/MainLayout/Footer/ContinueBtn

var _chests: Array[Dictionary] = []
var _active_chest_idx: int = -1
var _active_problem: MathProblem = null

func _ready() -> void:
	challenge_panel.visible = false
	continue_btn.pressed.connect(_on_continue_pressed)

	if has_node("/root/RunManager"):
		var rm = get_node("/root/RunManager")
		_chests = rm.run_chests.duplicate()
	
	if _chests.is_empty():
		# Add a default bonus chest if player finished without drops for testing
		_chests.append({"quality": "bronze", "opened": false})

	_render_chests()

func _render_chests() -> void:
	for child in chest_container.get_children():
		child.queue_free()

	for i in range(_chests.size()):
		var chest = _chests[i]
		var card = _create_chest_card(chest, i)
		chest_container.add_child(card)

func _create_chest_card(chest: Dictionary, index: int) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(130, 140)

	var q = chest.get("quality", "bronze")
	var color = _get_quality_color(q)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.10, 0.18, 0.95)
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	# Chest icon (pixel art)
	var chest_tex = SpriteManager.get_chest_texture(q)
	if chest.get("opened", false):
		chest_tex = SpriteManager.get_sprite("chest_open")
	
	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(48, 48)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.texture = chest_tex
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	vbox.add_child(icon)

	# Name
	var name_lbl = Label.new()
	name_lbl.text = _get_quality_name(q) + " Truhe"
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_color_override("font_color", color)
	name_lbl.add_theme_font_size_override("font_size", 9)
	vbox.add_child(name_lbl)

	# Open Button
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(0, 26)
	btn.add_theme_font_size_override("font_size", 8)

	if chest.get("opened", false):
		btn.text = "Geöffnet ✓"
		btn.disabled = true
	elif chest.get("failed", false):
		btn.text = "Zerbrochen ✗"
		btn.disabled = true
		panel.modulate = Color(0.5, 0.5, 0.5, 0.6)
	else:
		btn.text = "Öffnen ➔"
		btn.pressed.connect(func(): _start_chest_challenge(index))

	vbox.add_child(btn)
	return panel

func _get_quality_name(q: String) -> String:
	match q:
		"bronze": return "Bronze"
		"silver": return "Silber"
		"gold": return "Gold"
		"legendary": return "Legendäre"
		_: return "Bronze"

func _get_quality_color(q: String) -> Color:
	match q:
		"bronze": return Color(0.8, 0.5, 0.2)
		"silver": return Color(0.75, 0.8, 0.9)
		"gold": return Color(1.0, 0.85, 0.2)
		"legendary": return Color(0.8, 0.3, 1.0)
		_: return Color(0.8, 0.5, 0.2)

func _start_chest_challenge(index: int) -> void:
	_active_chest_idx = index
	var chest = _chests[index]
	var q = chest.get("quality", "bronze")
	
	challenge_panel.visible = true
	result_label.text = ""
	chest_title_label.text = "📦 " + _get_quality_name(q).to_upper() + "-TRUHE KNACKEN"
	chest_title_label.add_theme_color_override("font_color", _get_quality_color(q))

	# Generate a challenging math problem
	var config = MathConfig.new()
	config.difficulty = MathConfig.Difficulty.HARD
	config.game_mode = MathConfig.GameMode.TASK_TO_RESULT
	config.operation = MathConfig.Operation.MIXED
	config.num_choices = 4

	match q:
		"bronze":
			config.min_operand = 10
			config.max_operand = 40
			config.max_result = 80
		"silver":
			config.min_operand = 15
			config.max_operand = 60
			config.max_result = 120
		"gold":
			config.min_operand = 20
			config.max_operand = 100
			config.max_result = 200
		"legendary":
			config.min_operand = 30
			config.max_operand = 150
			config.max_result = 300

	if has_node("/root/MathEngine"):
		_active_problem = get_node("/root/MathEngine").generate_problem(config)
	else:
		var me_script = load("res://scripts/autoload/MathEngine.gd")
		var me = me_script.new()
		_active_problem = me.generate_problem(config)
		me.free()

	if _active_problem:
		problem_label.text = _active_problem.question_text + " = ?"

	# Build choice buttons
	for child in choice_row.get_children():
		child.queue_free()

	for choice in _active_problem.choices:
		var btn = Button.new()
		btn.text = str(choice)
		btn.custom_minimum_size = Vector2(70, 38)
		btn.add_theme_font_size_override("font_size", 12)
		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = Color(0.2, 0.16, 0.3)
		btn_style.border_color = Color(0.6, 0.5, 0.8)
		btn_style.set_border_width_all(1)
		btn_style.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", btn_style)
		btn.pressed.connect(func(): _evaluate_answer(choice, btn))
		choice_row.add_child(btn)

func _evaluate_answer(selected: int, clicked_btn: Button) -> void:
	for child in choice_row.get_children():
		if child is Button: child.disabled = true

	if selected == _active_problem.correct_answer:
		# CORRECT! Open chest
		clicked_btn.modulate = Color(0.3, 1.5, 0.5)
		_chests[_active_chest_idx]["opened"] = true
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx("chest_open")
		_award_chest_loot(_chests[_active_chest_idx])
	else:
		# WRONG! Chest breaks
		clicked_btn.modulate = Color(2.0, 0.3, 0.3)
		_chests[_active_chest_idx]["failed"] = true
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx("chest_break")
		result_label.text = "❌ Falsch! Richtige Antwort war: " + str(_active_problem.correct_answer) + " — Die Truhe zerbricht!"
		result_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		_render_chests()

func _award_chest_loot(chest: Dictionary) -> void:
	var q = chest.get("quality", "bronze")
	var reward_text = ""

	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		match q:
			"bronze":
				var gold = randi_range(15, 30)
				sm.total_gold_earned += gold
				reward_text = "🎉 Belohnung: 🪙 " + str(gold) + " Gold!"
			"silver":
				if randf() < 0.5:
					sm.add_diamonds(1)
					reward_text = "🎉 Belohnung: 💎 1 Diamant!"
				else:
					var gold = randi_range(40, 70)
					sm.total_gold_earned += gold
					reward_text = "🎉 Belohnung: 🪙 " + str(gold) + " Gold!"
			"gold":
				var unl_item = CosmeticDB.get_random_item_by_rarity(CosmeticDB.Rarity.RARE)
				sm.unlock_cosmetic(unl_item.id)
				reward_text = "🎉 SELTENE KOSMETIK: " + unl_item.name + " (" + unl_item.rarity_name + ")!"
			"legendary":
				var leg_item = CosmeticDB.get_random_item_by_rarity(CosmeticDB.Rarity.LEGENDARY)
				sm.unlock_cosmetic(leg_item.id)
				sm.add_diamonds(2)
				reward_text = "👑 LEGENDÄR: " + leg_item.name + " + 💎 2 Diamanten!"

	result_label.text = reward_text
	result_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.6))
	_render_chests()

func _on_continue_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/TitleScreen.tscn")
