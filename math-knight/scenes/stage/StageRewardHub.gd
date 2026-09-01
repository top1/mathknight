class_name StageRewardHub
extends Control
## StageRewardHub — Intermission hub after clearing a stage.
## Integrates Merchant Shop, Chest Opening Chamber, and Knight Stats,
## before advancing to the next stage selection.

const ItemDB = preload("res://scripts/resources/ItemDatabase.gd")
const CosmeticDB = preload("res://scripts/resources/CosmeticDatabase.gd")

@onready var bg: MenuBackground = $MenuBackground
@onready var stage_title: Label = $MarginContainer/MainLayout/Header/StageTitle
@onready var hp_label: Label = $MarginContainer/MainLayout/TopBar/HPBadge/HPContainer/HPLabel
@onready var gold_label: Label = $MarginContainer/MainLayout/TopBar/GoldBadge/GoldContainer/GoldLabel
@onready var diamond_label: Label = $MarginContainer/MainLayout/TopBar/DiamondBadge/DiamondContainer/DiamondLabel

@onready var tab_shop_btn: Button = $MarginContainer/MainLayout/TabButtons/ShopTabBtn
@onready var tab_chest_btn: Button = $MarginContainer/MainLayout/TabButtons/ChestTabBtn
@onready var tab_stats_btn: Button = $MarginContainer/MainLayout/TabButtons/StatsTabBtn

@onready var shop_panel: Control = $MarginContainer/MainLayout/ContentPanels/ShopPanel
@onready var shop_items_container: HBoxContainer = $MarginContainer/MainLayout/ContentPanels/ShopPanel/Scroll/ItemContainer
@onready var merchant_dialogue: Label = $MarginContainer/MainLayout/ContentPanels/ShopPanel/MerchantSpeech/DialogueLabel

@onready var chest_panel: Control = $MarginContainer/MainLayout/ContentPanels/ChestPanel
@onready var chest_container: HBoxContainer = $MarginContainer/MainLayout/ContentPanels/ChestPanel/Scroll/ChestContainer
@onready var chest_challenge_box: PanelContainer = $MarginContainer/MainLayout/ContentPanels/ChestPanel/ChallengeBox
@onready var chest_challenge_title: Label = $MarginContainer/MainLayout/ContentPanels/ChestPanel/ChallengeBox/VBox/Title
@onready var chest_pins_row: HBoxContainer = $MarginContainer/MainLayout/ContentPanels/ChestPanel/ChallengeBox/VBox/PinsRow
@onready var chest_timer_bar: ProgressBar = $MarginContainer/MainLayout/ContentPanels/ChestPanel/ChallengeBox/VBox/TimerBar
@onready var chest_problem_label: Label = $MarginContainer/MainLayout/ContentPanels/ChestPanel/ChallengeBox/VBox/ProblemLabel
@onready var chest_choices_row: HBoxContainer = $MarginContainer/MainLayout/ContentPanels/ChestPanel/ChallengeBox/VBox/ChoiceRow
@onready var chest_result_label: Label = $MarginContainer/MainLayout/ContentPanels/ChestPanel/ChallengeBox/VBox/ResultLabel

@onready var stats_panel: Control = $MarginContainer/MainLayout/ContentPanels/StatsPanel
@onready var stat_hp_lbl: Label = $MarginContainer/MainLayout/ContentPanels/StatsPanel/StatsGrid/StatHP
@onready var stat_atk_lbl: Label = $MarginContainer/MainLayout/ContentPanels/StatsPanel/StatsGrid/StatAtk
@onready var stat_arm_lbl: Label = $MarginContainer/MainLayout/ContentPanels/StatsPanel/StatsGrid/StatArm
@onready var stat_ddg_lbl: Label = $MarginContainer/MainLayout/ContentPanels/StatsPanel/StatsGrid/StatDdg
@onready var artifacts_list_lbl: Label = $MarginContainer/MainLayout/ContentPanels/StatsPanel/ArtifactsPanel/ArtifactsLabel

@onready var next_stage_btn: Button = $MarginContainer/MainLayout/Footer/NextStageBtn

var _current_tab: String = "shop"
var _shop_items: Array[Dictionary] = []
var _active_chest_idx: int = -1
var _active_chest_problem: MathProblem = null

# Lock Picking State
var _chest_total_pins: int = 3
var _chest_current_pin: int = 0
var _chest_time_limit: float = 7.0
var _chest_time_left: float = 0.0
var _is_chest_lockpicking: bool = false
var _chest_pin_panels: Array[PanelContainer] = []


func _ready() -> void:
	if not has_node("/root/RunManager"):
		return

	var rm: Node = get_node("/root/RunManager")
	var stg_num: int = rm.current_stage_index + 1
	var is_boss_upcoming: bool = (stg_num >= RunManager.FINAL_BOSS_STAGE)

	if is_boss_upcoming:
		stage_title.text = "★ ALLGEMEINES RÜSTLAGER: DER ENDBOSS NAHT! ★"
		stage_title.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		next_stage_btn.text = "ZUM EPISCHEN ENDBOSS ➔"
	else:
		stage_title.text = "★ RASTLAGER NACH STUFE %d ★" % stg_num
		next_stage_btn.text = "NÄCHSTE STUFE WÄHLEN ➔"

	_setup_signals()
	_update_header_stats()
	_populate_shop()
	_populate_chests()
	_update_stats_display()
	_switch_tab("shop")

	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_music("shop")


func _setup_signals() -> void:
	tab_shop_btn.pressed.connect(func(): _switch_tab("shop"))
	tab_chest_btn.pressed.connect(func(): _switch_tab("chest"))
	tab_stats_btn.pressed.connect(func(): _switch_tab("stats"))
	next_stage_btn.pressed.connect(_on_next_stage_pressed)

	_add_hover_juice(tab_shop_btn)
	_add_hover_juice(tab_chest_btn)
	_add_hover_juice(tab_stats_btn)
	_add_hover_juice(next_stage_btn)


func _update_header_stats() -> void:
	var rm: Node = get_node("/root/RunManager")
	hp_label.text = "%d / %d" % [int(rm.knight_run_hp), int(rm.knight_run_max_hp)]
	gold_label.text = "%d" % rm.run_gold

	var diamonds: int = 0
	if has_node("/root/SaveManager"):
		diamonds = get_node("/root/SaveManager").diamonds
	diamond_label.text = "%d" % diamonds


func _switch_tab(tab_name: String) -> void:
	_current_tab = tab_name
	shop_panel.visible = (tab_name == "shop")
	chest_panel.visible = (tab_name == "chest")
	stats_panel.visible = (tab_name == "stats")

	_style_tab_button(tab_shop_btn, tab_name == "shop")
	_style_tab_button(tab_chest_btn, tab_name == "chest")
	_style_tab_button(tab_stats_btn, tab_name == "stats")

	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("click")


func _style_tab_button(btn: Button, is_active: bool) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.set_corner_radius_all(4)
	if is_active:
		style.bg_color = Color(0.24, 0.18, 0.36, 0.95)
		style.border_color = Color(1.0, 0.85, 0.35)
		style.set_border_width_all(2)
		btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
	else:
		style.bg_color = Color(0.1, 0.08, 0.16, 0.8)
		style.border_color = Color(0.35, 0.3, 0.45, 0.6)
		style.set_border_width_all(1)
		btn.add_theme_color_override("font_color", Color(0.75, 0.75, 0.85))

	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)


# === Merchant / Shop System ===

func _populate_shop() -> void:
	for child in shop_items_container.get_children():
		child.queue_free()

	_shop_items = ItemDB.get_random_shop_selection(4)
	for item in _shop_items:
		var card: PanelContainer = _create_shop_card(item)
		shop_items_container.add_child(card)


func _create_shop_card(item: Dictionary) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(135, 170)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.09, 0.19, 0.95)
	style.border_color = Color(0.85, 0.7, 0.3)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var name_lbl: Label = Label.new()
	name_lbl.text = item.get("name", "Item")
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.45))
	name_lbl.add_theme_font_size_override("font_size", 9)
	vbox.add_child(name_lbl)

	# Icon
	var icon_rect: TextureRect = TextureRect.new()
	var icon_name: String = item.get("icon", "")
	if has_node("/root/SpriteManager"):
		icon_rect.texture = get_node("/root/SpriteManager").get_item_icon(icon_name)
	icon_rect.custom_minimum_size = Vector2(32, 32)
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	vbox.add_child(icon_rect)

	# Desc
	var desc_lbl: Label = Label.new()
	desc_lbl.text = item.get("desc", "")
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	desc_lbl.add_theme_font_size_override("font_size", 7)
	vbox.add_child(desc_lbl)

	# Buy Button
	var buy_btn: Button = Button.new()
	var cost: int = item.get("cost_gold", 25)
	buy_btn.text = "🪙 %d Kaufen" % cost
	buy_btn.custom_minimum_size = Vector2(0, 24)
	buy_btn.add_theme_font_size_override("font_size", 8)

	var btn_style: StyleBoxFlat = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.85, 0.65, 0.15)
	btn_style.set_corner_radius_all(4)
	buy_btn.add_theme_stylebox_override("normal", btn_style)
	buy_btn.add_theme_color_override("font_color", Color(0.1, 0.05, 0.0))

	buy_btn.pressed.connect(func(): _buy_item(item, buy_btn, panel))
	vbox.add_child(buy_btn)

	return panel


func _buy_item(item: Dictionary, btn: Button, panel: PanelContainer) -> void:
	var rm: Node = get_node("/root/RunManager")
	var cost: int = item.get("cost_gold", 25)

	if rm.spend_run_gold(cost):
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx("coin", 1.2)
		btn.disabled = true
		btn.text = "Gekauft ✓"
		panel.modulate = Color(0.6, 0.6, 0.6, 0.7)
		_update_header_stats()

		# Apply effect
		if item.get("type") == "potion":
			if item.get("effect_type") == "heal_flat":
				rm.heal_knight(item.get("value", 6.0))
			elif item.get("effect_type") == "hp_boost":
				rm.knight_run_max_hp += item.get("value", 4.0)
				rm.knight_run_hp += item.get("value", 4.0)
			elif item.get("effect_type") == "armor_boost":
				rm.knight_run_armor += item.get("value", 0.5)
		else:
			rm.add_artifact(item)

		merchant_dialogue.text = "»Ein exzellenter Kauf, edler Ritter! Das wird dir im Kampf helfen!«"
		_update_stats_display()
		_update_header_stats()
	else:
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx("wrong", 1.1)
		merchant_dialogue.text = "»Dafür reichen deine Goldmünzen leider noch nicht ganz aus...«"


# === Chest Opening System ===

func _populate_chests() -> void:
	for child in chest_container.get_children():
		child.queue_free()

	chest_challenge_box.visible = false

	var rm: Node = get_node("/root/RunManager")
	var chests: Array[Dictionary] = rm.run_chests

	if chests.is_empty():
		var empty_lbl: Label = Label.new()
		empty_lbl.text = "Keine Truhen im Inventar.\n(Schließe Elite- oder Tempo-Stufen ab, um Truhen zu erbeuten!)"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		empty_lbl.add_theme_font_size_override("font_size", 9)
		chest_container.add_child(empty_lbl)
		return

	for i in range(chests.size()):
		var chest: Dictionary = chests[i]
		var card: PanelContainer = _create_chest_card(chest, i)
		chest_container.add_child(card)


func _create_chest_card(chest: Dictionary, index: int) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(110, 130)

	var q: String = chest.get("quality", "bronze")
	var color: Color = Color(0.8, 0.5, 0.2)
	match q:
		"silver": color = Color(0.75, 0.85, 1.0)
		"gold": color = Color(1.0, 0.85, 0.2)
		"legendary": color = Color(0.9, 0.35, 1.0)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.16, 0.95)
	style.border_color = color
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	panel.add_child(vbox)

	var name_lbl: Label = Label.new()
	name_lbl.text = q.capitalize() + "-Truhe"
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_color_override("font_color", color)
	name_lbl.add_theme_font_size_override("font_size", 8)
	vbox.add_child(name_lbl)

	var chest_icon: TextureRect = TextureRect.new()
	if has_node("/root/SpriteManager"):
		var sm = get_node("/root/SpriteManager")
		chest_icon.texture = sm.get_sprite("chest_open") if chest.get("opened", false) else sm.get_chest_texture(q)
	chest_icon.custom_minimum_size = Vector2(36, 36)
	chest_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chest_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	vbox.add_child(chest_icon)

	var open_btn: Button = Button.new()
	open_btn.custom_minimum_size = Vector2(0, 22)
	open_btn.add_theme_font_size_override("font_size", 8)

	if chest.get("opened", false):
		open_btn.text = "Geöffnet ✓"
		open_btn.disabled = true
	elif chest.get("failed", false):
		open_btn.text = "Zerbrochen ✗"
		open_btn.disabled = true
		panel.modulate = Color(0.5, 0.5, 0.5, 0.6)
	else:
		open_btn.text = "Knacken ➔"
		open_btn.pressed.connect(func(): _start_chest_math_challenge(index))

	vbox.add_child(open_btn)
	return panel


func _process(delta: float) -> void:
	if not _is_chest_lockpicking:
		return

	_chest_time_left -= delta
	if chest_timer_bar:
		chest_timer_bar.value = max(0.0, _chest_time_left / _chest_time_limit)
		var ratio = _chest_time_left / _chest_time_limit
		if ratio > 0.5:
			chest_timer_bar.modulate = Color(0.3, 0.9, 1.0)
		elif ratio > 0.25:
			chest_timer_bar.modulate = Color(1.0, 0.8, 0.2)
		else:
			chest_timer_bar.modulate = Color(1.0, 0.3, 0.3)

	if _chest_time_left <= 0.0:
		_on_chest_lockpick_timeout()


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


func _start_chest_math_challenge(index: int) -> void:
	_active_chest_idx = index
	var rm: Node = get_node("/root/RunManager")
	var chest: Dictionary = rm.run_chests[index]
	var q: String = chest.get("quality", "bronze")

	_chest_total_pins = _get_pins_for_quality(q)
	_chest_time_limit = _get_time_for_quality(q)
	_chest_current_pin = 0
	_is_chest_lockpicking = true

	chest_challenge_box.visible = true
	chest_result_label.text = ""
	chest_challenge_title.text = "🔓 %s-TRUHE KNACKEN (%d STIFTE / PINS)" % [q.to_upper(), _chest_total_pins]

	_setup_hub_pins_ui()
	_present_hub_pin_problem()


func _setup_hub_pins_ui() -> void:
	for child in chest_pins_row.get_children():
		child.queue_free()
	_chest_pin_panels.clear()

	for i in range(_chest_total_pins):
		var pin_p = PanelContainer.new()
		pin_p.custom_minimum_size = Vector2(54, 22)
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
		lbl.add_theme_font_size_override("font_size", 7)
		lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
		pin_p.add_child(lbl)

		chest_pins_row.add_child(pin_p)
		_chest_pin_panels.append(pin_p)


func _update_hub_pins_display() -> void:
	for i in range(_chest_pin_panels.size()):
		var p = _chest_pin_panels[i]
		var lbl = p.get_child(0) as Label
		var style = StyleBoxFlat.new()
		style.set_corner_radius_all(4)
		style.set_border_width_all(1)

		if i < _chest_current_pin:
			style.bg_color = Color(0.1, 0.35, 0.15)
			style.border_color = Color(0.3, 1.0, 0.4)
			lbl.text = "🔓 Pin %d ✓" % (i + 1)
			lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
		elif i == _chest_current_pin:
			style.bg_color = Color(0.3, 0.25, 0.1)
			style.border_color = Color(1.0, 0.85, 0.2)
			lbl.text = "⚡ Pin %d" % (i + 1)
			lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
		else:
			style.bg_color = Color(0.15, 0.15, 0.22)
			style.border_color = Color(0.4, 0.4, 0.5)
			lbl.text = "🔒 Pin %d" % (i + 1)
			lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))

		p.add_theme_stylebox_override("panel", style)


func _present_hub_pin_problem() -> void:
	_update_hub_pins_display()
	_chest_time_left = _chest_time_limit
	if chest_timer_bar:
		chest_timer_bar.value = 1.0

	var rm: Node = get_node("/root/RunManager")
	var chest: Dictionary = rm.run_chests[_active_chest_idx]
	var q: String = chest.get("quality", "bronze")

	var cfg: MathConfig = MathConfig.new()
	cfg.difficulty = MathConfig.Difficulty.HARD
	cfg.game_mode = MathConfig.GameMode.TASK_TO_RESULT
	cfg.operation = MathConfig.Operation.MIXED
	cfg.num_choices = 4

	match q:
		"bronze":
			cfg.min_operand = 5
			cfg.max_operand = 25
			cfg.max_result = 50
		"silver":
			cfg.min_operand = 10
			cfg.max_operand = 40
			cfg.max_result = 80
		"gold":
			cfg.min_operand = 15
			cfg.max_operand = 60
			cfg.max_result = 120
		"legendary":
			cfg.min_operand = 20
			cfg.max_operand = 90
			cfg.max_result = 200

	if has_node("/root/MathEngine"):
		_active_chest_problem = get_node("/root/MathEngine").generate_problem(cfg)

	if _active_chest_problem:
		chest_problem_label.text = "%s = ?" % _active_chest_problem.question_text

	for child in chest_choices_row.get_children():
		child.queue_free()

	for choice in _active_chest_problem.choices:
		var btn: Button = Button.new()
		btn.text = str(choice)
		btn.custom_minimum_size = Vector2(65, 32)
		btn.add_theme_font_size_override("font_size", 11)

		var btn_style: StyleBoxFlat = StyleBoxFlat.new()
		btn_style.bg_color = Color(0.18, 0.14, 0.28)
		btn_style.border_color = Color(0.6, 0.5, 0.8)
		btn_style.set_border_width_all(1)
		btn_style.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", btn_style)

		btn.pressed.connect(func(): _evaluate_chest_answer(choice, btn))
		chest_choices_row.add_child(btn)


func _evaluate_chest_answer(selected_val: int, clicked_btn: Button) -> void:
	if not _is_chest_lockpicking:
		return

	if selected_val == _active_chest_problem.correct_answer:
		clicked_btn.modulate = Color(0.3, 2.0, 0.5)
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx("click", 1.4 + (_chest_current_pin * 0.15))

		_chest_current_pin += 1
		if _chest_current_pin >= _chest_total_pins:
			_on_hub_chest_success()
		else:
			if is_inside_tree() and get_tree():
				var t = get_tree().create_timer(0.2)
				t.timeout.connect(_present_hub_pin_problem)
			else:
				_present_hub_pin_problem()
	else:
		clicked_btn.modulate = Color(2.0, 0.3, 0.3)
		_chest_time_left -= 2.5 # Time penalty
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx("wrong", 0.9)
		if _chest_time_left <= 0.0:
			_on_chest_lockpick_timeout()


func _on_chest_lockpick_timeout() -> void:
	_is_chest_lockpicking = false
	for child in chest_choices_row.get_children():
		if child is Button:
			child.disabled = true

	var rm: Node = get_node("/root/RunManager")
	rm.run_chests[_active_chest_idx]["failed"] = true
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("chest_break")
	chest_result_label.text = "❌ DIETRICH GEBROCHEN! Die Truhe ist blockiert & zerbricht!"
	chest_result_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	_populate_chests()


func _on_hub_chest_success() -> void:
	_is_chest_lockpicking = false
	_update_hub_pins_display()
	for child in chest_choices_row.get_children():
		if child is Button:
			child.disabled = true

	var rm: Node = get_node("/root/RunManager")
	rm.run_chests[_active_chest_idx]["opened"] = true
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("chest_open")
	_award_chest_loot(rm.run_chests[_active_chest_idx])


func _award_chest_loot(chest: Dictionary) -> void:
	var q: String = chest.get("quality", "bronze")
	var rm: Node = get_node("/root/RunManager")
	var reward_text: String = ""

	match q:
		"bronze":
			var gold: int = randi_range(20, 40)
			rm.add_run_gold(gold, "Bronze-Truhe")
			reward_text = "🎉 SCHLOSS GEKNACKT! 🪙 %d Gold!" % gold
		"silver":
			if randf() < 0.5:
				if has_node("/root/SaveManager"):
					get_node("/root/SaveManager").add_diamonds(1)
				reward_text = "🎉 SCHLOSS GEKNACKT! 💎 1 Diamant!"
			else:
				var gold: int = randi_range(50, 90)
				rm.add_run_gold(gold, "Silber-Truhe")
				reward_text = "🎉 SCHLOSS GEKNACKT! 🪙 %d Gold!" % gold
		"gold":
			var item: Dictionary = CosmeticDB.get_random_item_by_rarity(CosmeticDB.Rarity.RARE)
			if has_node("/root/SaveManager"):
				get_node("/root/SaveManager").unlock_cosmetic(item.id)
			reward_text = "🎉 SCHLOSS GEKNACKT! SELTEN: %s (%s)!" % [item.name, item.rarity_name]
		"legendary":
			var leg_item: Dictionary = CosmeticDB.get_random_item_by_rarity(CosmeticDB.Rarity.LEGENDARY)
			if has_node("/root/SaveManager"):
				get_node("/root/SaveManager").unlock_cosmetic(leg_item.id)
				get_node("/root/SaveManager").add_diamonds(2)
			reward_text = "👑 MEISTER-DIEB! %s + 💎 2 Diamanten!" % leg_item.name

	chest_result_label.text = reward_text
	chest_result_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.6))
	_populate_chests()
	_update_header_stats()


# === Knight Stats Overview ===

func _update_stats_display() -> void:
	var rm: Node = get_node("/root/RunManager")
	stat_hp_lbl.text = "Max HP: %d" % int(rm.knight_run_max_hp)
	stat_atk_lbl.text = "Angriff: %.1f" % rm.knight_run_attack
	stat_arm_lbl.text = "Rüstung: %.1f" % rm.knight_run_armor
	stat_ddg_lbl.text = "Ausweichen: %d%%" % int(rm.knight_run_dodge * 100.0)

	if rm.run_artifacts.is_empty():
		artifacts_list_lbl.text = "Keine aktiven Artefakte."
	else:
		var art_str: String = ""
		for art in rm.run_artifacts:
			art_str += "• " + art.get("name", "Artefakt") + ": " + art.get("desc", "") + "\n"
		artifacts_list_lbl.text = art_str


# === Navigation ===

func _add_hover_juice(btn: Button) -> void:
	btn.pivot_offset = btn.size / 2.0
	btn.mouse_entered.connect(func():
		var t: Tween = btn.create_tween()
		t.tween_property(btn, "scale", Vector2(1.04, 1.04), 0.1).set_trans(Tween.TRANS_SINE)
	)
	btn.mouse_exited.connect(func():
		var t: Tween = btn.create_tween()
		t.tween_property(btn, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_SINE)
	)


func _on_next_stage_pressed() -> void:
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("click")

	var rm: Node = get_node("/root/RunManager")
	rm.advance_to_next_stage_choices()

	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.22)
	tween.tween_callback(func():
		get_tree().change_scene_to_file("res://scenes/stage/StageSelectScreen.tscn")
	)
