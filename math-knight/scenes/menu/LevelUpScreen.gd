class_name LevelUpScreen
extends Control
## RPG Stat upgrade interface for distributing knight skill points.
## Shows detailed active values, live calculation previews, and allows
## seamless returning to either TitleScreen or active RunMap.

@onready var title_label: Label = $MarginContainer/MainLayout/Header/TitleLabel
@onready var points_label: Label = $MarginContainer/MainLayout/Header/PointsBadge/PointsLabel
@onready var stats_container: VBoxContainer = $MarginContainer/MainLayout/FrameWrapper/ScrollContainer/StatList
@onready var close_btn: Button = $MarginContainer/MainLayout/Footer/CloseBtn

const STAT_INFOS = [
	{
		"id": "strength",
		"name": "STÄRKE",
		"desc": "+0.5 Ritterschaden (Mehr Schlagkraft gegen Gegner & Bosse)",
		"icon_path": "res://assets/sprites/ui/icon_strength.png",
		"icon_color": Color(1.0, 0.45, 0.35)
	},
	{
		"id": "endurance",
		"name": "AUSDAUER",
		"desc": "+3 Maximale Lebenspunkte (Erhöht Überlebenschance)",
		"icon_path": "res://assets/sprites/ui/icon_endurance.png",
		"icon_color": Color(1.0, 0.35, 0.45)
	},
	{
		"id": "defense",
		"name": "VERTEIDIGUNG",
		"desc": "+0.3 Rüstung (Verringert jeden feindlichen Trefferschaden)",
		"icon_path": "res://assets/sprites/ui/icon_defense.png",
		"icon_color": Color(0.4, 0.75, 1.0)
	},
	{
		"id": "agility",
		"name": "GESCHICK",
		"desc": "+6% Ausweichchance (Weiche Angriffen komplett aus)",
		"icon_path": "res://assets/sprites/ui/icon_agility.png",
		"icon_color": Color(0.3, 0.95, 0.65)
	},
	{
		"id": "wisdom",
		"name": "WEISHEIT",
		"desc": "+15% Gold-Bonus bei allen Drops & seltenere Truhen",
		"icon_path": "res://assets/sprites/ui/icon_wisdom.png",
		"icon_color": Color(0.9, 0.6, 1.0)
	}
]

func _ready() -> void:
	close_btn.pressed.connect(_on_close_pressed)
	_setup_styles()
	_render_stats()
	_update_header()

func _setup_styles() -> void:
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.18, 0.14, 0.24, 0.9)
	btn_style.border_color = Color(0.55, 0.45, 0.25)
	btn_style.set_border_width_all(1)
	btn_style.set_corner_radius_all(4)
	close_btn.add_theme_stylebox_override("normal", btn_style)

func _update_header() -> void:
	var lv = 1
	var pts = 0
	var xp = 0
	var xp_next = 100
	
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		lv = sm.knight_level
		pts = sm.knight_stat_points
		xp = sm.knight_xp
		xp_next = sm.xp_for_next_level()
		
	title_label.text = "⬆️ RITTER-AUFSTIEG (STUFE " + str(lv) + " - " + str(xp) + "/" + str(xp_next) + " XP)"
	
	if pts > 0:
		points_label.text = "★ " + str(pts) + " Talentpunkte verfügbar!"
		points_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	else:
		points_label.text = "0 Punkte verfügbar"
		points_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))

func _render_stats() -> void:
	for child in stats_container.get_children():
		child.queue_free()

	for info in STAT_INFOS:
		var row = _create_stat_row(info)
		stats_container.add_child(row)

func _create_stat_row(info: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 44)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.10, 0.18, 0.92)
	style.border_color = info.icon_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)

	# Pixel-Art Stat Icon
	var icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(28, 28)
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists(info.icon_path):
		icon_rect.texture = load(info.icon_path)
	hbox.add_child(icon_rect)

	# Name + Desc
	var text_box = VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 1)

	var name_lbl = Label.new()
	name_lbl.text = info.name
	name_lbl.add_theme_color_override("font_color", info.icon_color)
	name_lbl.add_theme_font_size_override("font_size", 10)
	text_box.add_child(name_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = info.desc
	desc_lbl.add_theme_color_override("font_color", Color(0.78, 0.78, 0.88))
	desc_lbl.add_theme_font_size_override("font_size", 7)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_box.add_child(desc_lbl)
	hbox.add_child(text_box)

	# Current calculated stat value preview
	var cur_val = 0
	var stat_summary = ""
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		cur_val = sm.knight_stats.get(info.id, 0)
		match info.id:
			"strength":
				stat_summary = "%.1f DMG" % sm.get_attack_power()
			"endurance":
				stat_summary = "%d HP" % int(sm.get_max_hp())
			"defense":
				stat_summary = "%.1f Rüst" % sm.get_armor()
			"agility":
				stat_summary = "%d%% Ausw" % int(sm.get_dodge_chance() * 100.0)
			"wisdom":
				stat_summary = "+%d%% Gold" % int((sm.get_gold_multiplier() - 1.0) * 100.0)

	var stat_val_lbl = Label.new()
	stat_val_lbl.text = "[" + stat_summary + "]"
	stat_val_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	stat_val_lbl.add_theme_font_size_override("font_size", 9)
	hbox.add_child(stat_val_lbl)

	# Level pips (e.g. ★ ★ ★ ☆ ☆)
	var pips_label = Label.new()
	var pip_str = ""
	for i in range(5):
		pip_str += "★ " if i < cur_val else "☆ "
	pips_label.text = pip_str
	pips_label.add_theme_color_override("font_color", info.icon_color)
	pips_label.add_theme_font_size_override("font_size", 10)
	hbox.add_child(pips_label)

	# Upgrade Button
	var up_btn = Button.new()
	up_btn.text = "+ Punkt"
	up_btn.custom_minimum_size = Vector2(75, 28)
	up_btn.add_theme_font_size_override("font_size", 9)
	
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.25, 0.45, 0.3) if cur_val < 5 else Color(0.2, 0.2, 0.25)
	btn_style.set_corner_radius_all(4)
	up_btn.add_theme_stylebox_override("normal", btn_style)
	
	var pts = 0
	if has_node("/root/SaveManager"):
		pts = get_node("/root/SaveManager").knight_stat_points
	up_btn.disabled = (pts <= 0 or cur_val >= 5)

	up_btn.pressed.connect(func():
		if has_node("/root/SaveManager"):
			var sm = get_node("/root/SaveManager")
			if sm.upgrade_stat(info.id):
				if has_node("/root/AudioManager"):
					get_node("/root/AudioManager").play_sfx("coin", 1.2)
				_update_header()
				_render_stats()
	)
	hbox.add_child(up_btn)

	return panel

func _on_close_pressed() -> void:
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("click")
	if has_node("/root/RunManager") and get_node("/root/RunManager").is_run_active:
		get_tree().change_scene_to_file("res://scenes/stage/StageSelectScreen.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/menu/TitleScreen.tscn")
