class_name VillageHub
extends Control
## VillageHub — The central medieval town square of MathKnight.
## Organized into 3 scrollbar-free thematic districts with touch swipe and tab navigation:
## 1. Abenteuer (Dungeon Gate, Royal Arena, Quest Board)
## 2. Handwerk (Blacksmith Forge, Royal Bakery, Timber Sawmill)
## 3. Ritterburg (Sir Solv-a-Lot Profile, Permanent Stats, Royal Wardrobe)

# Top bar nodes
@onready var top_bar_panel: PanelContainer = %TopBarPanel
@onready var knight_badge: PanelContainer = %KnightBadge
@onready var knight_title_label: Label = %KnightTitleLabel
@onready var talent_badge_btn: Button = %TalentBadgeBtn
@onready var gold_badge: PanelContainer = %GoldBadge
@onready var gold_label: Label = %GoldLabel
@onready var wood_badge: PanelContainer = %WoodBadge
@onready var wood_label: Label = %WoodLabel
@onready var bread_badge: PanelContainer = %BreadBadge
@onready var bread_label: Label = %BreadLabel
@onready var diamond_badge: PanelContainer = %DiamondBadge
@onready var diamond_label: Label = %DiamondLabel
@onready var mute_btn: Button = %MuteBtn

# Dynamic Village badges
var villagers_badge: PanelContainer
var villagers_label: Label
var soldiers_badge: PanelContainer
var soldiers_label: Label
var tax_status_label: Label

# Tab bar buttons
@onready var tab_adventure_btn: Button = %TabAdventureBtn
@onready var tab_craft_btn: Button = %TabCraftBtn
@onready var tab_hero_btn: Button = %TabHeroBtn

# District containers
@onready var district_container: Control = $Margin/MainVBox/DistrictContainer
@onready var adventure_district: HBoxContainer = %AdventureDistrict
@onready var craft_district: HBoxContainer = %CraftDistrict
@onready var hero_district: HBoxContainer = %HeroDistrict

# Bottom bar nodes
@onready var bottom_bar_panel: PanelContainer = %BottomBarPanel
@onready var main_menu_btn: Button = %MainMenuBtn
@onready var page_indicator_label: Label = %PageIndicatorLabel
@onready var nav_prev_btn: Button = %NavPrevBtn
@onready var nav_next_btn: Button = %NavNextBtn

# Current district state: 0 = Adventure, 1 = Craft, 2 = Hero
var current_district: int = 0

# Touch & Mouse swipe detection
var _touch_start_pos: Vector2 = Vector2.ZERO
var _is_swiping: bool = false
const MIN_SWIPE_DISTANCE: float = 45.0

func _ready() -> void:
	if main_menu_btn:
		main_menu_btn.pressed.connect(_on_main_menu_pressed)
	if talent_badge_btn:
		talent_badge_btn.pressed.connect(_on_hero_hall_pressed)
	if mute_btn:
		mute_btn.pressed.connect(_on_mute_pressed)
		_update_mute_btn()
		
	if tab_adventure_btn:
		tab_adventure_btn.pressed.connect(func(): switch_district(0))
	if tab_craft_btn:
		tab_craft_btn.pressed.connect(func(): switch_district(1))
	if tab_hero_btn:
		tab_hero_btn.pressed.connect(func(): switch_district(2))
		
	if nav_prev_btn:
		nav_prev_btn.pressed.connect(func(): switch_district(current_district - 1))
	if nav_next_btn:
		nav_next_btn.pressed.connect(func(): switch_district(current_district + 1))
		
	if has_node("/root/EventBus"):
		var bus = get_node("/root/EventBus")
		if bus.has_signal("gold_changed"): bus.gold_changed.connect(func(_g): _update_top_bar())
		if bus.has_signal("bread_changed"): bus.bread_changed.connect(func(_b): _update_top_bar())
		if bus.has_signal("knight_leveled_up"): bus.knight_leveled_up.connect(func(_l): _update_top_bar())
		if bus.has_signal("knight_stat_upgraded"): bus.knight_stat_upgraded.connect(func(_s, _v): _update_top_bar())
		if bus.has_signal("sound_mute_toggled"): bus.sound_mute_toggled.connect(func(_m): _update_mute_btn())
		# Economy signals
		if bus.has_signal("villagers_changed"): bus.villagers_changed.connect(func(_v): _update_top_bar())
		if bus.has_signal("soldiers_changed"): bus.soldiers_changed.connect(func(_s): _update_top_bar())
		if bus.has_signal("weapons_changed"): bus.weapons_changed.connect(func(_w): _update_top_bar())
		if bus.has_signal("hut_built"): bus.hut_built.connect(func(_h): _update_top_bar(); _render_craft_district())
		if bus.has_signal("taxes_collected"): bus.taxes_collected.connect(func(_g, _f): _update_top_bar())
		
	# Try attracting villagers when entering village
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		var new_folks = sm.try_attract_villagers()
		if new_folks > 0:
			JuiceManager.spawn_comic_popup(self, "+%d BEWOHNER! 🎉" % new_folks, Vector2(320, 180), "flawless")
		
	_setup_wood_bars_and_capsules()
	_update_top_bar()
	_render_all_districts()
	switch_district(0, false)
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_music("village")

func _setup_wood_bars_and_capsules() -> void:
	# Top bar wood beam
	if top_bar_panel:
		var tb = StyleBoxFlat.new()
		tb.bg_color = Color("#241209")
		tb.border_color = Color("#4a2412")
		tb.border_width_top = 2
		tb.border_width_left = 1
		tb.border_width_right = 1
		tb.border_width_bottom = 3
		tb.set_corner_radius_all(6)
		tb.content_margin_left = 10
		tb.content_margin_right = 10
		tb.content_margin_top = 4
		tb.content_margin_bottom = 4
		top_bar_panel.add_theme_stylebox_override("panel", tb)

	# Bottom bar wood beam
	if bottom_bar_panel:
		var bb = StyleBoxFlat.new()
		bb.bg_color = Color("#241209")
		bb.border_color = Color("#4a2412")
		bb.border_width_top = 2
		bb.border_width_left = 1
		bb.border_width_right = 1
		bb.border_width_bottom = 2
		bb.set_corner_radius_all(6)
		bb.content_margin_left = 10
		bb.content_margin_right = 10
		bb.content_margin_top = 4
		bb.content_margin_bottom = 4
		bottom_bar_panel.add_theme_stylebox_override("panel", bb)

	# Knight badge pill
	if knight_badge:
		_apply_capsule_style(knight_badge, Color("#5c3418"))

	# Resource badges pills
	if gold_badge: _apply_capsule_style(gold_badge, Color("#854d0e"))
	if wood_badge: _apply_capsule_style(wood_badge, Color("#5c381e"))
	if bread_badge: _apply_capsule_style(bread_badge, Color("#854d0e"))
	if diamond_badge: _apply_capsule_style(diamond_badge, Color("#0369a1"))

	# Create Villagers and Soldiers capsules dynamically in WalletHBox
	var wallet_box = top_bar_panel.get_node_or_null("TopBar/WalletHBox")
	if wallet_box and not villagers_badge:
		villagers_badge = PanelContainer.new()
		_apply_capsule_style(villagers_badge, Color("#15803d"))
		villagers_label = Label.new()
		villagers_label.add_theme_font_size_override("font_size", 11)
		villagers_label.add_theme_color_override("font_color", Color("#86efac"))
		villagers_label.text = "👤 0/10"
		villagers_badge.add_child(villagers_label)
		wallet_box.add_child(villagers_badge)

	if wallet_box and not soldiers_badge:
		soldiers_badge = PanelContainer.new()
		_apply_capsule_style(soldiers_badge, Color("#b91c1c"))
		soldiers_label = Label.new()
		soldiers_label.add_theme_font_size_override("font_size", 11)
		soldiers_label.add_theme_color_override("font_color", Color("#fca5a5"))
		soldiers_label.text = "⚔️ 0"
		soldiers_badge.add_child(soldiers_label)
		wallet_box.add_child(soldiers_badge)

	# 3D navigation buttons in bottom bar
	if main_menu_btn:
		_style_3d_pixel_button(main_menu_btn, Color("#5c2e14"), Color("#1f0902"), 3.0)
	if nav_prev_btn:
		_style_3d_pixel_button(nav_prev_btn, Color("#452312"), Color("#1f0902"), 3.0)
	if nav_next_btn:
		_style_3d_pixel_button(nav_next_btn, Color("#452312"), Color("#1f0902"), 3.0)
	if mute_btn:
		_style_3d_pixel_button(mute_btn, Color("#2b140a"), Color("#180c05"), 2.0)

func _apply_capsule_style(panel: PanelContainer, border_col: Color) -> void:
	var s = StyleBoxFlat.new()
	s.bg_color = Color("#170b05")
	s.border_color = border_col
	s.set_border_width_all(1)
	s.set_corner_radius_all(12)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	panel.add_theme_stylebox_override("panel", s)

func _style_3d_pixel_button(btn: Button, base_color: Color, shadow_color: Color = Color("#230c03"), bevel_height: float = 4.0) -> void:
	var bh = int(bevel_height)
	
	# Normal state
	var s_norm = StyleBoxFlat.new()
	s_norm.bg_color = base_color
	s_norm.border_color = shadow_color
	s_norm.border_width_top = 1
	s_norm.border_width_left = 1
	s_norm.border_width_right = 2
	s_norm.border_width_bottom = bh
	s_norm.set_corner_radius_all(4)
	s_norm.content_margin_top = 3
	s_norm.content_margin_bottom = 3 + bh
	s_norm.content_margin_left = 10
	s_norm.content_margin_right = 10
	
	# Hover state
	var s_hov = StyleBoxFlat.new()
	s_hov.bg_color = base_color.lightened(0.12)
	s_hov.border_color = shadow_color
	s_hov.border_width_top = 1
	s_hov.border_width_left = 1
	s_hov.border_width_right = 2
	s_hov.border_width_bottom = bh
	s_hov.set_corner_radius_all(4)
	s_hov.content_margin_top = 3
	s_hov.content_margin_bottom = 3 + bh
	s_hov.content_margin_left = 10
	s_hov.content_margin_right = 10
	
	# Pressed state (einfedern in den Schatten!)
	var s_press = StyleBoxFlat.new()
	s_press.bg_color = base_color.darkened(0.08)
	s_press.border_color = shadow_color
	s_press.border_width_top = bh
	s_press.border_width_left = 1
	s_press.border_width_right = 2
	s_press.border_width_bottom = 1
	s_press.set_corner_radius_all(4)
	s_press.content_margin_top = 3 + bh
	s_press.content_margin_bottom = 4
	s_press.content_margin_left = 10
	s_press.content_margin_right = 10

	# Disabled state
	var s_dis = StyleBoxFlat.new()
	s_dis.bg_color = Color("#1e110a")
	s_dis.border_color = Color("#140904")
	s_dis.set_border_width_all(1)
	s_dis.border_width_bottom = 2
	s_dis.set_corner_radius_all(4)
	s_dis.content_margin_top = 3
	s_dis.content_margin_bottom = 5
	s_dis.content_margin_left = 10
	s_dis.content_margin_right = 10

	btn.add_theme_stylebox_override("normal", s_norm)
	btn.add_theme_stylebox_override("hover", s_hov)
	btn.add_theme_stylebox_override("pressed", s_press)
	btn.add_theme_stylebox_override("disabled", s_dis)
	btn.add_theme_color_override("font_color", Color("#f4eedb"))
	btn.add_theme_color_override("font_hover_color", Color("#fffbeb"))
	btn.add_theme_color_override("font_pressed_color", Color("#fed7aa"))
	btn.add_theme_color_override("font_disabled_color", Color("#78716c"))

func _create_3d_pixel_button(btn_text: String, action_cb: Callable, base_color: Color = Color("#b45309"), custom_height: float = 32.0, font_size: int = 12) -> Button:
	var btn = Button.new()
	btn.text = btn_text
	btn.custom_minimum_size = Vector2(0, custom_height)
	btn.add_theme_font_size_override("font_size", font_size)
	_style_3d_pixel_button(btn, base_color, Color("#1f0902"), 4.0)
	btn.pressed.connect(action_cb)
	return btn

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_start_pos = event.position
			_is_swiping = true
		else:
			if _is_swiping:
				_is_swiping = false
				_evaluate_swipe(event.position - _touch_start_pos)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_touch_start_pos = event.position
				_is_swiping = true
			else:
				if _is_swiping:
					_is_swiping = false
					_evaluate_swipe(event.position - _touch_start_pos)

func _evaluate_swipe(delta: Vector2) -> void:
	if abs(delta.x) > MIN_SWIPE_DISTANCE and abs(delta.x) > abs(delta.y) * 1.3:
		if delta.x < 0:
			switch_district(current_district + 1)
		else:
			switch_district(current_district - 1)

func switch_district(new_idx: int, play_sound: bool = true) -> void:
	current_district = posmod(new_idx, 3)
	
	if play_sound and has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("click")
		
	if adventure_district:
		adventure_district.visible = (current_district == 0)
	if craft_district:
		craft_district.visible = (current_district == 1)
	if hero_district:
		hero_district.visible = (current_district == 2)
		
	var active_container: Control = null
	match current_district:
		0: active_container = adventure_district
		1: active_container = craft_district
		2: active_container = hero_district
		
	if active_container:
		active_container.modulate.a = 0.0
		var tw = create_tween()
		tw.tween_property(active_container, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
	_update_tab_buttons_visual()
	_update_page_indicator()

func _update_tab_buttons_visual() -> void:
	var tabs = [
		{"btn": tab_adventure_btn, "active_color": Color("#c2410c"), "label": "⚔️ ABENTEUER"},
		{"btn": tab_craft_btn, "active_color": Color("#d97706"), "label": "🛠️ HANDWERK"},
		{"btn": tab_hero_btn, "active_color": Color("#0284c7"), "label": "🛡️ RITTERBURG"}
	]
	
	for i in range(tabs.size()):
		var b: Button = tabs[i]["btn"]
		if not b:
			continue
		var is_act = (i == current_district)
		var style = StyleBoxFlat.new()
		# Hanging bookmark tab: flat on top, rounded on bottom!
		style.corner_radius_top_left = 0
		style.corner_radius_top_right = 0
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		style.content_margin_top = 5
		style.content_margin_bottom = 8
		style.content_margin_left = 12
		style.content_margin_right = 12
		
		if is_act:
			# Helles Holz / Gold mit Schatten
			style.bg_color = Color("#b45309")
			style.border_color = Color("#fde047")
			style.border_width_left = 2
			style.border_width_right = 2
			style.border_width_bottom = 3
			style.border_width_top = 0
			style.shadow_color = Color(0, 0, 0, 0.45)
			style.shadow_size = 4
			style.shadow_offset = Vector2(0, 3)
			b.add_theme_color_override("font_color", Color("#fffbeb"))
			b.add_theme_font_size_override("font_size", 12)
		else:
			# Inaktiv: Dunkles Holz
			style.bg_color = Color("#221008")
			style.border_color = Color("#3d1e10")
			style.border_width_left = 1
			style.border_width_right = 1
			style.border_width_bottom = 1
			style.border_width_top = 0
			style.shadow_size = 0
			b.add_theme_color_override("font_color", Color("#a38c75"))
			b.add_theme_font_size_override("font_size", 11)
			
		b.add_theme_stylebox_override("normal", style)
		b.add_theme_stylebox_override("hover", style)
		b.add_theme_stylebox_override("pressed", style)

func _update_page_indicator() -> void:
	if not page_indicator_label:
		return
	match current_district:
		0: page_indicator_label.text = "●  ○  ○   (Abenteuer 1/3)"
		1: page_indicator_label.text = "○  ●  ○   (Handwerk 2/3)"
		2: page_indicator_label.text = "○  ○  ●   (Ritterburg 3/3)"

func _update_mute_btn() -> void:
	if not mute_btn:
		return
	var is_muted = false
	if has_node("/root/AudioManager"):
		is_muted = get_node("/root/AudioManager").is_master_muted()
	mute_btn.text = "🔇" if is_muted else "🔊"
	mute_btn.add_theme_color_override("font_color", Color("#ef4444") if is_muted else Color("#4ade80"))

func _on_mute_pressed() -> void:
	if has_node("/root/AudioManager"):
		var am = get_node("/root/AudioManager")
		var was_muted = am.is_master_muted()
		var new_muted = am.toggle_mute()
		if was_muted:
			am.play_sfx("click")
		_update_mute_btn()

func _update_top_bar() -> void:
	var lv = 1
	var gold = 0
	var wood = 0
	var bread = 0
	var diamonds = 0
	var pts = 0
	var villager_count = 0
	var max_v = 10
	var soldier_count = 0
	
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		lv = sm.knight_level
		gold = sm.gold
		wood = sm.wood
		bread = sm.bread
		diamonds = sm.diamonds
		pts = sm.knight_stat_points
		villager_count = sm.villagers
		max_v = sm.get_max_villagers()
		soldier_count = sm.soldiers
		
	if knight_title_label:
		knight_title_label.text = "Sir Solv-a-Lot (Stufe %d)" % lv
	if gold_label:
		gold_label.text = "🪙 %d" % gold
	if wood_label:
		wood_label.text = "🪵 %d" % wood
	if bread_label:
		bread_label.text = "🥖 %d" % bread
	if diamond_label:
		diamond_label.text = "💎 %d" % diamonds
	if villagers_label:
		villagers_label.text = "👤 %d/%d" % [villager_count, max_v]
	if soldiers_label:
		soldiers_label.text = "⚔️ %d" % soldier_count
		
	if talent_badge_btn:
		if pts > 0:
			talent_badge_btn.visible = true
			talent_badge_btn.text = "★ %d Punkte!" % pts
			_style_3d_pixel_button(talent_badge_btn, Color("#d97706"), Color("#1f0902"), 2.5)
		else:
			talent_badge_btn.visible = false

func _render_all_districts() -> void:
	_render_adventure_district()
	_render_craft_district()
	_render_hero_district()

func _render_adventure_district() -> void:
	if not adventure_district:
		return
	for c in adventure_district.get_children():
		c.queue_free()
		
	var sm = get_node_or_null("/root/SaveManager")

	# 1. Dungeon Gate
	var dungeon_card = _create_district_card(
		"🏰",
		"TOR ZUM VERLIES",
		"Haupthalle",
		"Wage dich in die Tiefen des Zahlen-Verlieses! Löse Rechenrätsel im Takt und erobere Schätze.",
		Color("#c2410c"),
		"START",
		_on_dungeon_pressed
	)
	adventure_district.add_child(dungeon_card)
	
	# 2. Castle Attack / Siege Gate Maze
	var cur_soldiers = sm.soldiers if sm else 0
	var weapons = sm.weapons_stock if sm else 0
	var can_recruit = sm.can_recruit_soldier() if sm else false
	var recruit_cost_text = "REKRUTIEREN (1👤 1⚔️ 5🪙)"
	if not can_recruit:
		if (sm and sm.weapons_stock <= 0):
			recruit_cost_text = "Keine Waffen! (Schmiede)"
		elif (sm and sm.villagers <= 0):
			recruit_cost_text = "Keine Bewohner! (Brot/Hütte)"
		elif (sm and sm.gold < 5):
			recruit_cost_text = "Braucht 5🪙 Gold"
	
	var siege_card = _create_district_card(
		"🏹",
		"BURG-ANGRIFF",
		"%d Soldaten bereit" % cur_soldiers,
		"Führe deine Armee durch magische Schleusen-Tore! Waffen: %d | Rekrutiere Soldaten für gewaltige Siege." % weapons,
		Color("#dc2626"),
		"ANGRIFF",
		_on_siege_pressed,
		{
			"cost_text": recruit_cost_text,
			"can_upgrade": can_recruit,
			"upgrade_cb": func(): _on_recruit_soldier_pressed()
		}
	)
	adventure_district.add_child(siege_card)
	
	# 3. The Royal Arena
	var arena_status = "Heute offen!"
	if sm and sm.arena_last_played_date == Time.get_date_string_from_system():
		arena_status = "Heute gemeistert ✓"
	var arena_card = _create_district_card(
		"⚔️",
		"KÖNIGS-ARENA",
		arena_status,
		"Tritt vor König und Volk in der Arena an! Stelle dich endlosen Wellen kniffliger Mathe-Kämpfe.",
		Color("#7c3aed"),
		"KÄMPFEN",
		_on_arena_pressed
	)
	adventure_district.add_child(arena_card)
	
	# 3. Quest Board
	var quest_card = _create_district_card(
		"📜",
		"ANSCHLAGTAFEL",
		"Königliche Dekrete",
		"Tägliche und wöchentliche Aufträge der Krone für extra Goldmünzen, Holz und Belohnungen.",
		Color("#d97706"),
		"AUFTRÄGE",
		_on_quest_board_pressed
	)
	adventure_district.add_child(quest_card)

func _render_craft_district() -> void:
	if not craft_district:
		return
	for c in craft_district.get_children():
		c.queue_free()
		
	var sm = get_node_or_null("/root/SaveManager")
	
	# 1. Forge
	var forge_lvl = sm.forge_level if sm else 1
	var forge_can_up = sm.can_upgrade_building("forge") if sm else false
	var forge_cost = sm.get_building_upgrade_cost("forge") if sm else {"maxed": false, "gold": 100, "wood": 50}
	var forge_cost_text = "Maximalstufe ⭐" if forge_cost.get("maxed", false) else "AUSBAU (%d🪵 %d🪙)" % [forge_cost.wood, forge_cost.gold]
	
	var forge_card = _create_district_card(
		"🔨",
		"BROKS SCHMIEDE",
		"Stufe %d / 3" % forge_lvl,
		"Schmiede mächtige Klingen im 120-BPM Rhythmus-Feuer! Trainiert das 1x1 der Multiplikation.",
		Color("#ea580c"),
		"SCHMIEDEN",
		_on_forge_pressed,
		{
			"cost_text": forge_cost_text,
			"can_upgrade": forge_can_up,
			"upgrade_cb": func(): _on_upgrade_building("forge")
		}
	)
	craft_district.add_child(forge_card)
	
	# 2. Bakery
	var bakery_lvl = sm.bakery_level if sm else 1
	var bakery_can_up = sm.can_upgrade_building("bakery") if sm else false
	var bakery_cost = sm.get_building_upgrade_cost("bakery") if sm else {"maxed": false, "gold": 70, "wood": 40}
	var bakery_cost_text = "Maximalstufe ⭐" if bakery_cost.get("maxed", false) else "AUSBAU (%d🪵 %d🪙)" % [bakery_cost.wood, bakery_cost.gold]
	
	var bakery_card = _create_district_card(
		"🥖",
		"HOFBÄCKEREI",
		"Stufe %d / 3" % bakery_lvl,
		"Zutaten auf der Katapult-Waage wiegen und im Steinofen backen (Addition, Gewichte & Uhrzeit)!",
		Color("#d97706"),
		"BACKEN",
		_on_bakery_pressed,
		{
			"cost_text": bakery_cost_text,
			"can_upgrade": bakery_can_up,
			"upgrade_cb": func(): _on_upgrade_building("bakery")
		}
	)
	craft_district.add_child(bakery_card)
	
	# 3. Lumber Yard
	var lumber_lvl = sm.lumber_level if sm else 1
	var lumber_can_up = sm.can_upgrade_building("lumber") if sm else false
	var lumber_cost = sm.get_building_upgrade_cost("lumber") if sm else {"maxed": false, "gold": 80, "wood": 30}
	var lumber_cost_text = "Maximalstufe ⭐" if lumber_cost.get("maxed", false) else "AUSBAU (%d🪵 %d🪙)" % [lumber_cost.wood, lumber_cost.gold]
	
	var lumber_card = _create_district_card(
		"🪓",
		"TIMS SÄGEWERK",
		"Stufe %d / 3" % lumber_lvl,
		"Zerteile dicke Baumstämme mit scharfer Divisions-Präzision! Liefert wertvolles Bauholz.",
		Color("#16a34a"),
		"SÄGEN",
		_on_lumber_pressed,
		{
			"cost_text": lumber_cost_text,
			"can_upgrade": lumber_can_up,
			"upgrade_cb": func(): _on_upgrade_building("lumber")
		}
	)
	craft_district.add_child(lumber_card)

	# 4. Dorfverwaltung (Hütten & Steuern)
	var huts = sm.hut_count if sm else 0
	var max_huts = sm.get_max_huts() if sm else 0
	var hut_cost = sm.get_hut_cost() if sm else {"wood": 20, "gold": 10}
	var can_hut = sm.can_build_hut() if sm else false
	var hut_badge_text = "Hütten: %d/%d" % [huts, max_huts]
	if max_huts == 0:
		hut_badge_text = "Hütten ab Stufe 2!"
	var hut_cost_text = "Max. Hütten ⭐" if (huts >= max_huts and max_huts > 0) else ("HÜTTE BAUEN (%d🪵 %d🪙)" % [hut_cost["wood"], hut_cost["gold"]])
	if max_huts == 0:
		hut_cost_text = "Erst ab Ritter-Stufe 2"
	
	var village_card = _create_district_card(
		"🏠",
		"DORFVERWALTUNG",
		hut_badge_text,
		"Baue Holzhütten (+5 Bewohner je Hütte). Bewohner essen Brot und zahlen alle 5 Min. Gold-Steuern!",
		Color("#15803d"),
		_get_tax_button_text(),
		_on_collect_taxes_pressed,
		{
			"cost_text": hut_cost_text,
			"can_upgrade": can_hut,
			"upgrade_cb": func(): _on_build_hut_pressed()
		}
	)
	craft_district.add_child(village_card)

func _render_hero_district() -> void:
	if not hero_district:
		return
	for c in hero_district.get_children():
		c.queue_free()
		
	var sm = get_node_or_null("/root/SaveManager")
	var lv = sm.knight_level if sm else 1
	var xp = sm.knight_xp if sm else 0
	var pts = sm.knight_stat_points if sm else 0
	var stats = sm.knight_stats if (sm and sm.knight_stats) else {}
	var affix = sm.weapon_affix if sm else ""
	
	var next_xp = 50
	if sm and SaveManager.XP_PER_LEVEL.size() > lv:
		next_xp = SaveManager.XP_PER_LEVEL[lv]
	else:
		next_xp = 9999
		
	# Card 1: Hero Profile & XP
	var profile_card = PanelContainer.new()
	profile_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	profile_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_apply_card_style(profile_card, Color("#0284c7"))
	
	var vbox1 = VBoxContainer.new()
	vbox1.add_theme_constant_override("separation", 6)
	profile_card.add_child(vbox1)
	
	var h1 = HBoxContainer.new()
	var ico1 = Label.new()
	ico1.text = "🛡️"
	ico1.add_theme_font_size_override("font_size", 22)
	h1.add_child(ico1)
	
	var t_vbox1 = VBoxContainer.new()
	t_vbox1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var t1 = Label.new()
	t1.text = "SIR SOLV-A-LOT"
	t1.add_theme_font_size_override("font_size", 12)
	t1.add_theme_color_override("font_color", Color("#fde68a"))
	t_vbox1.add_child(t1)
	var st1 = Label.new()
	st1.text = "Ritter der Stufe %d" % lv
	st1.add_theme_font_size_override("font_size", 10)
	st1.add_theme_color_override("font_color", Color("#fed7aa"))
	t_vbox1.add_child(st1)
	h1.add_child(t_vbox1)
	vbox1.add_child(h1)
	
	var xp_lbl = Label.new()
	xp_lbl.text = "Erfahrung: %d / %d XP" % [xp, next_xp]
	xp_lbl.add_theme_font_size_override("font_size", 10)
	xp_lbl.add_theme_color_override("font_color", Color("#f4eedb"))
	vbox1.add_child(xp_lbl)
	
	var pbar = ProgressBar.new()
	pbar.custom_minimum_size = Vector2(0, 10)
	pbar.max_value = max(1, next_xp)
	pbar.value = xp
	pbar.show_percentage = false
	vbox1.add_child(pbar)
	
	var sp1 = Control.new()
	sp1.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox1.add_child(sp1)
	
	var pts_lbl = Label.new()
	pts_lbl.text = "★ %d Punkte verfügbar!" % pts if pts > 0 else "Keine freien Punkte"
	pts_lbl.add_theme_font_size_override("font_size", 10)
	pts_lbl.add_theme_color_override("font_color", Color("#fde047") if pts > 0 else Color("#78716c"))
	vbox1.add_child(pts_lbl)
	
	var train_btn = _create_3d_pixel_button("TRAINIEREN", _on_hero_hall_pressed, Color("#0284c7"), 32.0, 11)
	vbox1.add_child(train_btn)
	
	hero_district.add_child(profile_card)
	
	# Card 2: 7 Knight Attributes
	var stats_card = PanelContainer.new()
	stats_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_apply_card_style(stats_card, Color("#7c3aed"))
	
	var vbox2 = VBoxContainer.new()
	vbox2.add_theme_constant_override("separation", 4)
	stats_card.add_child(vbox2)
	
	var st_title = Label.new()
	st_title.text = "⚔️ KAMPF-ATTRIBUTE"
	st_title.add_theme_font_size_override("font_size", 12)
	st_title.add_theme_color_override("font_color", Color("#fde68a"))
	vbox2.add_child(st_title)
	
	var stat_items = [
		{"name": "⚔️ Angriff", "val": "+%d" % stats.get("strength", 0)},
		{"name": "🛡️ Abwehr", "val": "+%d" % stats.get("defense", 0)},
		{"name": "💖 Ausdauer", "val": "+%d LP" % (stats.get("endurance", 0) * 10)},
		{"name": "⚡ Agilität", "val": "+%d%%" % (stats.get("agility", 0) * 2)},
		{"name": "🧠 Weisheit", "val": "+%d%%" % (stats.get("wisdom", 0) * 5)},
		{"name": "🎯 Fokus", "val": "+%d%%" % (stats.get("focus", 0) * 3)},
		{"name": "🔨 Handwerk", "val": "+%d%%" % (stats.get("crafting", 0) * 5)}
	]
	
	for s in stat_items:
		var row = HBoxContainer.new()
		var n_lbl = Label.new()
		n_lbl.text = s.name
		n_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n_lbl.add_theme_font_size_override("font_size", 9)
		n_lbl.add_theme_color_override("font_color", Color("#f4eedb"))
		row.add_child(n_lbl)
		
		var v_lbl = Label.new()
		v_lbl.text = s.val
		v_lbl.add_theme_font_size_override("font_size", 9)
		v_lbl.add_theme_color_override("font_color", Color("#4ade80"))
		row.add_child(v_lbl)
		vbox2.add_child(row)
		
	var sp2 = Control.new()
	sp2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox2.add_child(sp2)
	
	hero_district.add_child(stats_card)
	
	# Card 3: Wardrobe & Equipment
	var wardrobe_card = PanelContainer.new()
	wardrobe_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wardrobe_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_apply_card_style(wardrobe_card, Color("#c026d3"))
	
	var vbox3 = VBoxContainer.new()
	vbox3.add_theme_constant_override("separation", 6)
	wardrobe_card.add_child(vbox3)
	
	var h3 = HBoxContainer.new()
	var ico3 = Label.new()
	ico3.text = "👑"
	ico3.add_theme_font_size_override("font_size", 22)
	h3.add_child(ico3)
	
	var t_vbox3 = VBoxContainer.new()
	t_vbox3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var t3 = Label.new()
	t3.text = "KÖNIGSGARDEROBE"
	t3.add_theme_font_size_override("font_size", 12)
	t3.add_theme_color_override("font_color", Color("#fde68a"))
	t_vbox3.add_child(t3)
	var st3 = Label.new()
	st3.text = "Ausrüstung & Schmuck"
	st3.add_theme_font_size_override("font_size", 10)
	st3.add_theme_color_override("font_color", Color("#fed7aa"))
	t_vbox3.add_child(st3)
	h3.add_child(t_vbox3)
	vbox3.add_child(h3)
	
	var desc3 = Label.new()
	desc3.text = "Rüste Helme, Rüstungen und magische Elementar-Affixe für deine Waffen aus."
	desc3.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc3.add_theme_font_size_override("font_size", 10)
	desc3.add_theme_color_override("font_color", Color("#f4eedb"))
	desc3.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox3.add_child(desc3)
	
	var affix_text = "Waffen-Affix: " + (affix.to_upper() if affix != "" else "Standard (Kein)")
	var affix_lbl = Label.new()
	affix_lbl.text = affix_text
	affix_lbl.add_theme_font_size_override("font_size", 10)
	affix_lbl.add_theme_color_override("font_color", Color("#fde047"))
	vbox3.add_child(affix_lbl)
	
	var inv_btn = _create_3d_pixel_button("GARDEROBE", _on_cosmetics_pressed, Color("#c026d3"), 32.0, 11)
	vbox3.add_child(inv_btn)
	
	hero_district.add_child(wardrobe_card)

func _create_district_card(icon_str: String, title: String, badge_str: String, desc: String, accent_color: Color, action_text: String, action_cb: Callable, upgrade_data: Variant = null) -> PanelContainer:
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_apply_card_style(card, accent_color)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)
	
	# Header with Icon, Title and Subtitle
	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(header_hbox)
	
	var ico = Label.new()
	ico.text = icon_str
	ico.add_theme_font_size_override("font_size", 22)
	header_hbox.add_child(ico)
	
	var title_vbox = VBoxContainer.new()
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title_vbox)
	
	var t = Label.new()
	t.text = title
	t.add_theme_color_override("font_color", Color("#fde68a"))
	t.add_theme_font_size_override("font_size", 12)
	title_vbox.add_child(t)
	
	var b = Label.new()
	b.text = badge_str
	b.add_theme_color_override("font_color", Color("#fed7aa"))
	b.add_theme_font_size_override("font_size", 9)
	title_vbox.add_child(b)
	
	# Description text
	var d = Label.new()
	d.text = desc
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.add_theme_color_override("font_color", Color("#f4eedb"))
	d.add_theme_font_size_override("font_size", 9)
	d.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(d)
	
	# Buttons row
	if upgrade_data != null:
		var up_btn = Button.new()
		up_btn.text = upgrade_data.get("cost_text", "Ausbau")
		up_btn.disabled = not upgrade_data.get("can_upgrade", false)
		up_btn.custom_minimum_size = Vector2(0, 24)
		up_btn.add_theme_font_size_override("font_size", 9)
		_style_3d_pixel_button(up_btn, Color("#78350f"), Color("#1f0902"), 3.0)
		if upgrade_data.has("upgrade_cb"):
			up_btn.pressed.connect(upgrade_data["upgrade_cb"])
		vbox.add_child(up_btn)
		
	var enter_btn = _create_3d_pixel_button(action_text, action_cb, accent_color, 32.0, 11)
	vbox.add_child(enter_btn)
	
	return card

func _apply_card_style(panel: PanelContainer, border_col: Color) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#1a0e08")
	style.border_color = border_col.lerp(Color("#452312"), 0.35)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 3)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

func _on_upgrade_building(building: String) -> void:
	if not has_node("/root/SaveManager"):
		return
	var sm = get_node("/root/SaveManager")
	var success = sm.upgrade_building(building)
	if success:
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx("levelup", 1.0, 1.0)
		JuiceManager.spawn_comic_popup(self, "GEBÄUDE AUSGEBAUT! ★", Vector2(320, 180), "flawless")
		_update_top_bar()
		_render_craft_district()

func _on_dungeon_pressed() -> void:
	if has_node("/root/RunManager"):
		get_node("/root/RunManager").start_new_run()
	get_tree().change_scene_to_file("res://scenes/stage/StageSelectScreen.tscn")

func _on_siege_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/siege/SiegeGateMaze.tscn")

func _on_forge_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/forge/BlacksmithForge.tscn")

func _on_lumber_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/lumber/LumberYard.tscn")

func _on_bakery_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/bakery/Bakery.tscn")

func _on_quest_board_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/quests/QuestBoard.tscn")

func _on_arena_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/arena/Arena.tscn")

func _on_hero_hall_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/LevelUpScreen.tscn")

func _on_cosmetics_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/CosmeticInventory.tscn")

func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/TitleScreen.tscn")

func _get_tax_button_text() -> String:
	if not has_node("/root/SaveManager"):
		return "STEUERN"
	var sm = get_node("/root/SaveManager")
	var cooldown = sm.get_tax_cooldown_remaining()
	if cooldown > 0:
		var mins = int(cooldown) / 60
		var secs = int(cooldown) % 60
		return "⏳ %d:%02d" % [mins, secs]
	elif sm.villagers <= 0:
		return "Keine Bürger"
	elif sm.bread < sm.villagers:
		return "Braucht Brot!"
	return "💰 STEUERN (+%d🪙)" % (sm.villagers * SaveManager.TAX_GOLD_PER_VILLAGER)

func _on_build_hut_pressed() -> void:
	if not has_node("/root/SaveManager"):
		return
	var sm = get_node("/root/SaveManager")
	var ok = sm.build_hut()
	if ok:
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx("chest_break")
		JuiceManager.spawn_comic_popup(self, "HÜTTE ERBAUT! 🏠", Vector2(320, 180), "flawless")
		_update_top_bar()
		_render_craft_district()

func _on_collect_taxes_pressed() -> void:
	if not has_node("/root/SaveManager"):
		return
	var sm = get_node("/root/SaveManager")
	if not sm.can_collect_taxes():
		var cd = sm.get_tax_cooldown_remaining()
		if cd > 0:
			JuiceManager.spawn_comic_popup(self, "Bewohner sind noch satt!", Vector2(320, 180), "info")
		elif sm.villagers <= 0:
			JuiceManager.spawn_comic_popup(self, "Keine Bewohner im Dorf!", Vector2(320, 180), "info")
		elif sm.bread < sm.villagers:
			JuiceManager.spawn_comic_popup(self, "Nicht genug Brot für alle!", Vector2(320, 180), "info")
		return
	var gold_gain = sm.collect_taxes()
	if gold_gain > 0:
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx("coin")
		JuiceManager.spawn_comic_popup(self, "+%d GOLD STEUERN! 💰" % gold_gain, Vector2(320, 180), "flawless")
		_update_top_bar()
		_render_craft_district()

func _on_recruit_soldier_pressed() -> void:
	if not has_node("/root/SaveManager"):
		return
	var sm = get_node("/root/SaveManager")
	var ok = sm.recruit_soldier()
	if ok:
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx("fanfare")
		JuiceManager.spawn_comic_popup(self, "SOLDAT REKRUTIERT! ⚔️", Vector2(320, 180), "flawless")
		_update_top_bar()
		_render_adventure_district()