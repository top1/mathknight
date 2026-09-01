class_name ChestReward
extends Control
## Post-run Chest opening Lock-Picking mini-game screen.
## Players solve multiple math problems under time pressure (lock picking) to open chests.

const CosmeticDB = preload("res://scripts/resources/CosmeticDatabase.gd")

@onready var chest_container: HBoxContainer = $MarginContainer/MainLayout/ChestArea
@onready var challenge_panel: PanelContainer = $MarginContainer/MainLayout/ChallengePanel
@onready var chest_title_label: Label = $MarginContainer/MainLayout/ChallengePanel/VBox/ChestTitle
@onready var pins_row: HBoxContainer = $MarginContainer/MainLayout/ChallengePanel/VBox/PinsRow
@onready var timer_bar: ProgressBar = $MarginContainer/MainLayout/ChallengePanel/VBox/TimerBar
@onready var problem_label: Label = $MarginContainer/MainLayout/ChallengePanel/VBox/ProblemLabel
@onready var hint_label: Label = $MarginContainer/MainLayout/ChallengePanel/VBox/HintLabel
@onready var choice_row: HBoxContainer = $MarginContainer/MainLayout/ChallengePanel/VBox/ChoiceRow
@onready var result_label: Label = $MarginContainer/MainLayout/ChallengePanel/VBox/ResultLabel
@onready var continue_btn: Button = $MarginContainer/MainLayout/Footer/ContinueBtn

var _chests: Array[Dictionary] = []
var _active_chest_idx: int = -1
var _active_problem: MathProblem = null

# Lock Picking state
var _total_pins: int = 3
var _current_pin_idx: int = 0
var _time_limit_per_pin: float = 7.0
var _time_left: float = 0.0
var _is_lockpicking: bool = false
var _pin_panels: Array[PanelContainer] = []


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


func _process(delta: float) -> void:
	if not _is_lockpicking:
		return

	_time_left -= delta
	if timer_bar:
		timer_bar.value = max(0.0, _time_left / _time_limit_per_pin)
		# Shift color as timer gets lower
		var ratio = _time_left / _time_limit_per_pin
		if ratio > 0.5:
			timer_bar.modulate = Color(0.3, 0.9, 1.0)
		elif ratio > 0.25:
			timer_bar.modulate = Color(1.0, 0.8, 0.2)
		else:
			timer_bar.modulate = Color(1.0, 0.3, 0.3)

	if _time_left <= 0.0:
		_on_lockpick_timeout()


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

	# Chest icon
	var chest_tex: Texture2D = null
	if has_node("/root/SpriteManager"):
		var sm = get_node("/root/SpriteManager")
		chest_tex = sm.get_chest_texture(q)
		if chest.get("opened", false):
			chest_tex = sm.get_sprite("chest_open")
	
	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(48, 48)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.texture = chest_tex
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	vbox.add_child(icon)

	# Name & Pins info
	var name_lbl = Label.new()
	var pins_count = _get_pins_for_quality(q)
	name_lbl.text = "%s Truhe\n(%d Pins)" % [_get_quality_name(q), pins_count]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_color_override("font_color", color)
	name_lbl.add_theme_font_size_override("font_size", 8)
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
		btn.text = "Knacken ➔"
		btn.pressed.connect(func(): _start_chest_challenge(index))

	vbox.add_child(btn)
	return panel


func _get_pins_for_quality(q: String) -> int:
	match q:
		"bronze": return 2
		"silver": return 3
		"gold": return 4
		"legendary": return 5
		_: return 2


func _get_time_for_quality(q: String) -> float:
	match q:
		"bronze": return 8.0
		"silver": return 7.0
		"gold": return 6.0
		"legendary": return 5.0
		_: return 7.0


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
	
	_total_pins = _get_pins_for_quality(q)
	_time_limit_per_pin = _get_time_for_quality(q)
	_current_pin_idx = 0
	_is_lockpicking = true

	challenge_panel.visible = true
	result_label.text = ""
	chest_title_label.text = "🔓 %s-TRUHE KNACKEN (%d STIFTE / PINS)" % [_get_quality_name(q).to_upper(), _total_pins]
	chest_title_label.add_theme_color_override("font_color", _get_quality_color(q))

	_setup_pins_ui()
	_present_pin_problem()


func _setup_pins_ui() -> void:
	for child in pins_row.get_children():
		child.queue_free()
	_pin_panels.clear()

	for i in range(_total_pins):
		var pin_p = PanelContainer.new()
		pin_p.custom_minimum_size = Vector2(58, 24)
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.15, 0.15, 0.22)
		style.border_color = Color(0.5, 0.5, 0.6)
		style.set_border_width_all(1)
		style.set_corner_radius_all(4)
		pin_p.add_theme_stylebox_override("panel", style)

		var lbl = Label.new()
		lbl.text = "🔒 Pin %d" % (i + 1)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_override("font", preload("res://assets/fonts/Silkscreen-Bold.ttf"))
		lbl.add_theme_font_size_override("font_size", 8)
		lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
		pin_p.add_child(lbl)

		pins_row.add_child(pin_p)
		_pin_panels.append(pin_p)


func _update_pins_display() -> void:
	for i in range(_pin_panels.size()):
		var p = _pin_panels[i]
		var lbl = p.get_child(0) as Label
		var style = StyleBoxFlat.new()
		style.set_corner_radius_all(4)
		style.set_border_width_all(1)

		if i < _current_pin_idx:
			# Solved Pin
			style.bg_color = Color(0.1, 0.35, 0.15)
			style.border_color = Color(0.3, 1.0, 0.4)
			lbl.text = "🔓 Pin %d ✓" % (i + 1)
			lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
		elif i == _current_pin_idx:
			# Active Pin
			style.bg_color = Color(0.3, 0.25, 0.1)
			style.border_color = Color(1.0, 0.85, 0.2)
			lbl.text = "⚡ Pin %d" % (i + 1)
			lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
		else:
			# Pending Pin
			style.bg_color = Color(0.15, 0.15, 0.22)
			style.border_color = Color(0.4, 0.4, 0.5)
			lbl.text = "🔒 Pin %d" % (i + 1)
			lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))

		p.add_theme_stylebox_override("panel", style)


func _present_pin_problem() -> void:
	_update_pins_display()
	_time_left = _time_limit_per_pin
	if timer_bar:
		timer_bar.value = 1.0

	var chest = _chests[_active_chest_idx]
	var q = chest.get("quality", "bronze")

	var config = MathConfig.new()
	config.difficulty = MathConfig.Difficulty.HARD
	config.game_mode = MathConfig.GameMode.TASK_TO_RESULT
	config.operation = MathConfig.Operation.MIXED
	config.num_choices = 4

	match q:
		"bronze":
			config.min_operand = 5
			config.max_operand = 25
			config.max_result = 50
		"silver":
			config.min_operand = 10
			config.max_operand = 40
			config.max_result = 80
		"gold":
			config.min_operand = 15
			config.max_operand = 60
			config.max_result = 120
		"legendary":
			config.min_operand = 20
			config.max_operand = 90
			config.max_result = 200

	if has_node("/root/MathEngine"):
		_active_problem = get_node("/root/MathEngine").generate_problem(config)
	else:
		var me_script = load("res://scripts/autoload/MathEngine.gd")
		var me = me_script.new()
		_active_problem = me.generate_problem(config)
		me.free()

	if _active_problem:
		problem_label.text = "%s = ?" % _active_problem.question_text

	# Build choice buttons
	for child in choice_row.get_children():
		child.queue_free()

	for choice in _active_problem.choices:
		var btn = Button.new()
		btn.text = str(choice)
		btn.custom_minimum_size = Vector2(70, 36)
		btn.add_theme_font_size_override("font_size", 11)
		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = Color(0.2, 0.16, 0.3)
		btn_style.border_color = Color(0.6, 0.5, 0.8)
		btn_style.set_border_width_all(1)
		btn_style.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", btn_style)
		btn.pressed.connect(func(): _evaluate_pin_answer(choice, btn))
		choice_row.add_child(btn)


func _evaluate_pin_answer(selected: int, clicked_btn: Button) -> void:
	if not _is_lockpicking:
		return

	if selected == _active_problem.correct_answer:
		# Correct pin!
		clicked_btn.modulate = Color(0.3, 1.8, 0.5)
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx("click", 1.4 + (_current_pin_idx * 0.15))
		
		_current_pin_idx += 1
		if _current_pin_idx >= _total_pins:
			_on_lockpick_success()
		else:
			# Move to next pin after brief pause
			if is_inside_tree() and get_tree():
				var t = get_tree().create_timer(0.2)
				t.timeout.connect(_present_pin_problem)
			else:
				_present_pin_problem()
	else:
		# Wrong answer! Lockpick penalty
		clicked_btn.modulate = Color(2.0, 0.3, 0.3)
		_time_left -= 2.5 # Time penalty
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx("wrong", 0.9)
		if _time_left <= 0.0:
			_on_lockpick_timeout()


func _on_lockpick_timeout() -> void:
	_is_lockpicking = false
	for child in choice_row.get_children():
		if child is Button: child.disabled = true

	_chests[_active_chest_idx]["failed"] = true
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("chest_break")

	result_label.text = "❌ DIETRICH GEBROCHEN! Die Truhe ist blockiert & zerbricht!"
	result_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	_render_chests()


func _on_lockpick_success() -> void:
	_is_lockpicking = false
	_update_pins_display()
	for child in choice_row.get_children():
		if child is Button: child.disabled = true

	_chests[_active_chest_idx]["opened"] = true
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("chest_open")
	_award_chest_loot(_chests[_active_chest_idx])


func _award_chest_loot(chest: Dictionary) -> void:
	var q = chest.get("quality", "bronze")
	var reward_text = "🎉 SCHLOSS GEKNACKT!"

	var gold = randi_range(20, 40)
	if q == "silver":
		gold = randi_range(50, 90)

	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		match q:
			"bronze":
				sm.total_gold_earned += gold
				reward_text = "🎉 SCHLOSS GEKNACKT! 🪙 %d Gold geborgen!" % gold
			"silver":
				if randf() < 0.5:
					sm.add_diamonds(1)
					reward_text = "🎉 SCHLOSS GEKNACKT! 💎 1 Diamant geborgen!"
				else:
					sm.total_gold_earned += gold
					reward_text = "🎉 SCHLOSS GEKNACKT! 🪙 %d Gold geborgen!" % gold
			"gold":
				var unl_item = CosmeticDB.get_random_item_by_rarity(CosmeticDB.Rarity.RARE)
				sm.unlock_cosmetic(unl_item.id)
				reward_text = "🎉 SCHLOSS GEKNACKT! SELTENE KOSMETIK: %s (%s)!" % [unl_item.name, unl_item.rarity_name]
			"legendary":
				var leg_item = CosmeticDB.get_random_item_by_rarity(CosmeticDB.Rarity.LEGENDARY)
				sm.unlock_cosmetic(leg_item.id)
				sm.add_diamonds(2)
				reward_text = "👑 MEISTER-DIEB! %s + 💎 2 Diamanten!" % leg_item.name
	else:
		match q:
			"bronze":
				reward_text = "🎉 SCHLOSS GEKNACKT! 🪙 %d Gold geborgen!" % gold
			"silver":
				reward_text = "🎉 SCHLOSS GEKNACKT! 💎 1 Diamant geborgen!"
			"gold":
				reward_text = "🎉 SCHLOSS GEKNACKT! SELTENE KOSMETIK geborgen!"
			"legendary":
				reward_text = "👑 MEISTER-DIEB! Legendäre Beute!"

	result_label.text = reward_text
	result_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.6))
	_render_chests()


func _on_continue_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/TitleScreen.tscn")

