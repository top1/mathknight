class_name VillageHub
extends Control
## VillageHub — The central comic medieval town square of MathKnight.
## Connects all subsystems: Dungeon Gate, Blacksmith Forge, Timber Sawmill,
## Royal Quest Board, Colosseum Arena, and the Hero Barracks.

# Header labels
@onready var knight_title_label: Label = $Margin/MainVBox/TopBar/KnightTitleLabel
@onready var gold_label: Label = $Margin/MainVBox/TopBar/WalletHBox/GoldLabel
@onready var wood_label: Label = $Margin/MainVBox/TopBar/WalletHBox/WoodLabel
@onready var diamond_label: Label = $Margin/MainVBox/TopBar/WalletHBox/DiamondLabel
@onready var talent_badge_btn: Button = $Margin/MainVBox/TopBar/TalentBadgeBtn

# Buildings container
@onready var buildings_grid: GridContainer = $Margin/MainVBox/Scroll/BuildingsGrid
@onready var main_menu_btn: Button = $Margin/MainVBox/BottomBar/MainMenuBtn

func _ready() -> void:
	if main_menu_btn:
		main_menu_btn.pressed.connect(_on_main_menu_pressed)
	if talent_badge_btn:
		talent_badge_btn.pressed.connect(_on_hero_hall_pressed)
		
	if has_node("/root/EventBus"):
		var bus = get_node("/root/EventBus")
		if bus.has_signal("gold_changed"): bus.gold_changed.connect(func(_g): _update_top_bar())
		if bus.has_signal("knight_leveled_up"): bus.knight_leveled_up.connect(func(_l): _update_top_bar())
		if bus.has_signal("knight_stat_upgraded"): bus.knight_stat_upgraded.connect(func(_s, _v): _update_top_bar())
		
	_update_top_bar()
	_render_buildings()

func _update_top_bar() -> void:
	var lv = 1
	var gold = 0
	var wood = 0
	var diamonds = 0
	var pts = 0
	
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		lv = sm.knight_level
		gold = sm.gold
		wood = sm.wood
		diamonds = sm.diamonds
		pts = sm.knight_stat_points
		
	if knight_title_label:
		knight_title_label.text = "🛡️ Sir Solv-a-Lot (Stufe %d)" % lv
	if gold_label:
		gold_label.text = "🪙 %d" % gold
	if wood_label:
		wood_label.text = "🪵 %d" % wood
	if diamond_label:
		diamond_label.text = "💎 %d" % diamonds
		
	if talent_badge_btn:
		if pts > 0:
			talent_badge_btn.visible = true
			talent_badge_btn.text = "★ %d Talentpunkte!" % pts
		else:
			talent_badge_btn.visible = false

func _render_buildings() -> void:
	if not buildings_grid:
		return
	for c in buildings_grid.get_children():
		c.queue_free()
		
	# 1. Dungeon Gate
	var dungeon_card = _create_building_card(
		"🏰 TOR ZUM VERLIES",
		"Stürze dich ins Abenteuer, bekämpfe Monster und sammle Schätze!",
		Color(0.8, 0.25, 0.25),
		"Ins Verlies aufbrechen ⚔️",
		_on_dungeon_pressed
	)
	buildings_grid.add_child(dungeon_card)
	
	# 2. Blacksmith Forge
	var forge_lvl = 1
	var forge_can_up = false
	var forge_cost_text = ""
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		forge_lvl = sm.forge_level
		forge_can_up = sm.can_upgrade_building("forge")
		var cost = sm.get_building_upgrade_cost("forge")
		if cost.get("maxed", false):
			forge_cost_text = "Maximalstufe"
		else:
			forge_cost_text = "Ausbau: %d🪵 %d🪙" % [cost.wood, cost.gold]
			
	var forge_card = _create_upgradeable_card(
		"🔨 BROKS SCHMIEDE",
		"Schmiede mächtige Klingen im 120-BPM Taktfeuer!",
		Color(0.9, 0.55, 0.2),
		"Stufe %d / 3" % forge_lvl,
		"Zur Schmiede 🔨",
		_on_forge_pressed,
		forge_cost_text,
		forge_can_up,
		func(): _on_upgrade_building("forge")
	)
	buildings_grid.add_child(forge_card)
	
	# 3. Lumber Yard
	var lumber_lvl = 1
	var lumber_can_up = false
	var lumber_cost_text = ""
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		lumber_lvl = sm.lumber_level
		lumber_can_up = sm.can_upgrade_building("lumber")
		var cost = sm.get_building_upgrade_cost("lumber")
		if cost.get("maxed", false):
			lumber_cost_text = "Maximalstufe"
		else:
			lumber_cost_text = "Ausbau: %d🪵 %d🪙" % [cost.wood, cost.gold]
			
	var lumber_card = _create_upgradeable_card(
		"🪓 TIMS SÄGEWERK",
		"Zerteile Baumstämme mit scharfer Divisions-Präzision!",
		Color(0.4, 0.75, 0.35),
		"Stufe %d / 3" % lumber_lvl,
		"Zum Sägewerk 🪓",
		_on_lumber_pressed,
		lumber_cost_text,
		lumber_can_up,
		func(): _on_upgrade_building("lumber")
	)
	buildings_grid.add_child(lumber_card)
	
	# 4. Quest Board
	var quest_card = _create_building_card(
		"📜 DIE ANSCHLAGTAFEL",
		"Tägliche und wöchentliche Aufträge der Krone.",
		Color(0.85, 0.7, 0.3),
		"Aufträge prüfen 📜",
		_on_quest_board_pressed
	)
	buildings_grid.add_child(quest_card)
	
	# 5. The Royal Arena
	var arena_status = "Heutiges Turnier offen!"
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		if sm.arena_last_played_date == Time.get_date_string_from_system():
			arena_status = "Heute absolviert ✓"
	var arena_card = _create_building_card(
		"⚔️ DIE KÖNIGS-ARENA",
		"Endlos-Wellen vor dem König! (%s)" % arena_status,
		Color(0.8, 0.4, 0.8),
		"Zur Arena ⚔️",
		_on_arena_pressed
	)
	buildings_grid.add_child(arena_card)
	
	# 6. Hero Hall
	var hero_card = _create_building_card(
		"🎒 DIE HELDENHALLE",
		"Trainiere deine 7 Ritter-Attribute und schalte Rüstungen frei.",
		Color(0.3, 0.65, 0.9),
		"Attribute & Talente ⬆️",
		_on_hero_hall_pressed
	)
	buildings_grid.add_child(hero_card)

func _create_building_card(title: String, desc: String, accent_color: Color, action_text: String, action_cb: Callable) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(280, 110)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.12, 0.18, 0.92)
	style.border_color = accent_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)
	
	var t = Label.new()
	t.text = title
	t.add_theme_color_override("font_color", accent_color)
	t.add_theme_font_size_override("font_size", 14)
	vbox.add_child(t)
	
	var d = Label.new()
	d.text = desc
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	d.add_theme_font_size_override("font_size", 10)
	d.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(d)
	
	var btn = Button.new()
	btn.text = action_text
	btn.custom_minimum_size = Vector2(0, 30)
	btn.pressed.connect(action_cb)
	vbox.add_child(btn)
	
	return card

func _create_upgradeable_card(title: String, desc: String, accent_color: Color, level_text: String, action_text: String, action_cb: Callable, cost_text: String, can_up: bool, upgrade_cb: Callable) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(280, 130)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.12, 0.18, 0.92)
	style.border_color = accent_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)
	
	var header_hbox = HBoxContainer.new()
	vbox.add_child(header_hbox)
	
	var t = Label.new()
	t.text = title
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.add_theme_color_override("font_color", accent_color)
	t.add_theme_font_size_override("font_size", 14)
	header_hbox.add_child(t)
	
	var lvl_lbl = Label.new()
	lvl_lbl.text = level_text
	lvl_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	lvl_lbl.add_theme_font_size_override("font_size", 11)
	header_hbox.add_child(lvl_lbl)
	
	var d = Label.new()
	d.text = desc
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	d.add_theme_font_size_override("font_size", 10)
	d.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(d)
	
	var btns_hbox = HBoxContainer.new()
	btns_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(btns_hbox)
	
	var enter_btn = Button.new()
	enter_btn.text = action_text
	enter_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enter_btn.custom_minimum_size = Vector2(0, 30)
	enter_btn.pressed.connect(action_cb)
	btns_hbox.add_child(enter_btn)
	
	if cost_text != "":
		var up_btn = Button.new()
		up_btn.text = cost_text
		up_btn.disabled = not can_up
		up_btn.custom_minimum_size = Vector2(0, 30)
		up_btn.pressed.connect(upgrade_cb)
		btns_hbox.add_child(up_btn)
		
	return card

func _on_upgrade_building(building: String) -> void:
	if not has_node("/root/SaveManager"):
		return
	var sm = get_node("/root/SaveManager")
	var success = sm.upgrade_building(building)
	if success:
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx("levelup", 1.0, 1.0)
		JuiceManager.spawn_comic_popup(self, "GEBÄUDE AUSGEBAUT!", Vector2(320, 180), "flawless")
		_update_top_bar()
		_render_buildings()

func _on_dungeon_pressed() -> void:
	if has_node("/root/RunManager"):
		get_node("/root/RunManager").start_new_run()
	get_tree().change_scene_to_file("res://scenes/main/Main.tscn")

func _on_forge_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/forge/BlacksmithForge.tscn")

func _on_lumber_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/lumber/LumberYard.tscn")

func _on_quest_board_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/quests/QuestBoard.tscn")

func _on_arena_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/arena/Arena.tscn")

func _on_hero_hall_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/LevelUpScreen.tscn")

func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/TitleScreen.tscn")