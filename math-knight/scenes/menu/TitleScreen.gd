class_name TitleScreen
extends Control

@onready var title_banner: TextureRect = $MainContainer/VBox/TitleSection/TitleBanner
@onready var subtitle_label: Label = $MainContainer/VBox/TitleSection/SubtitleLabel
@onready var title_section: VBoxContainer = $MainContainer/VBox/TitleSection
@onready var knight_section: Control = $MainContainer/VBox/ContentRow/KnightSection
@onready var knight_dais: Control = $MainContainer/VBox/ContentRow/KnightSection/KnightDais
@onready var ascii_knight: AsciiEntity = $MainContainer/VBox/ContentRow/KnightSection/KnightDais/AsciiKnight
@onready var pedestal: Control = $MainContainer/VBox/ContentRow/KnightSection/KnightDais/Pedestal
@onready var village_btn: Button = $MainContainer/VBox/ContentRow/ButtonSection/VillageBtn
@onready var settings_btn: Button = $MainContainer/VBox/ContentRow/ButtonSection/SettingsBtn
@onready var level_badge: Label = $MainContainer/VBox/TopBar/LevelBadge
@onready var diamond_label: Label = $MainContainer/VBox/TopBar/DiamondLabel
@onready var mute_btn: Button = $MainContainer/VBox/TopBar/MuteBtn

var buttons: Array[Button] = []
var _cartoon_font: Font = null


func _ready() -> void:
	buttons = [village_btn, settings_btn]

	if ResourceLoader.exists("res://assets/fonts/LilitaOne-Regular.ttf"):
		_cartoon_font = load("res://assets/fonts/LilitaOne-Regular.ttf")
	elif ResourceLoader.exists("res://assets/fonts/Montserrat-ExtraBold.ttf"):
		_cartoon_font = load("res://assets/fonts/Montserrat-ExtraBold.ttf")
	elif ResourceLoader.exists("res://assets/fonts/Fredoka-Bold.ttf"):
		_cartoon_font = load("res://assets/fonts/Fredoka-Bold.ttf")
	else:
		_cartoon_font = ThemeDB.fallback_font

	_setup_styles()
	_setup_signals()
	_setup_button_juice()
	_update_header()

	if ascii_knight:
		ascii_knight.facing_direction = 1.0 # Face right toward menu
		if has_node("/root/SaveManager"):
			var sm = get_node("/root/SaveManager")
			ascii_knight.apply_cosmetics(sm.equipped_cosmetics)

	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_music("title")

	# Wait for layout to settle
	await get_tree().process_frame

	for btn in buttons:
		if btn:
			btn.scale = Vector2(0.9, 0.9)
			btn.pivot_offset = btn.size * 0.5
			btn.modulate.a = 0.0

	_play_entrance_animation()
	_play_pedestal_bobbing()


func _setup_styles() -> void:
	# Broad text buttons (bolder, wider font, centered)
	_style_broad_text_button(village_btn, 34, "ZUM DORF", Color("#fffbeb"))
	_style_broad_text_button(settings_btn, 22, "Einstellungen", Color("#f8fafc"))

	# Top labels - clean floating text, NO button look
	_style_top_label(level_badge, Color("#fcd34d"), 13)
	_style_top_label(diamond_label, Color("#38bdf8"), 13)
	_style_mute_btn(mute_btn)


func _style_broad_text_button(btn: Button, font_sz: int, text_str: String, default_color: Color) -> void:
	if not btn:
		return
	if _cartoon_font:
		btn.add_theme_font_override("font", _cartoon_font)
	btn.flat = true
	var empty_sb = StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty_sb)
	btn.add_theme_stylebox_override("hover", empty_sb)
	btn.add_theme_stylebox_override("pressed", empty_sb)
	btn.add_theme_stylebox_override("focus", empty_sb)

	btn.add_theme_font_size_override("font_size", font_sz)
	btn.add_theme_color_override("font_color", default_color)
	btn.add_theme_color_override("font_hover_color", Color("#fbbf24")) # Bright warm gold
	btn.add_theme_color_override("font_pressed_color", Color("#f59e0b"))
	btn.add_theme_constant_override("outline_size", 8)
	btn.add_theme_color_override("font_outline_color", Color(0.10, 0.07, 0.04, 0.98))
	btn.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.7))
	btn.add_theme_constant_override("shadow_offset_y", 3)
	btn.add_theme_constant_override("shadow_offset_x", 0)
	btn.add_theme_constant_override("letter_spacing", 2)
	btn.text = text_str


func _style_top_label(lbl: Label, text_col: Color, font_sz: int) -> void:
	if not lbl:
		return
	if _cartoon_font:
		lbl.add_theme_font_override("font", _cartoon_font)
	var empty_sb = StyleBoxEmpty.new()
	lbl.add_theme_stylebox_override("normal", empty_sb)
	lbl.add_theme_font_size_override("font_size", font_sz)
	lbl.add_theme_color_override("font_color", text_col)
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.05, 0.9))


func _style_mute_btn(btn: Button) -> void:
	if not btn:
		return
	if _cartoon_font:
		btn.add_theme_font_override("font", _cartoon_font)
	btn.flat = true
	var empty_sb = StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty_sb)
	btn.add_theme_stylebox_override("hover", empty_sb)
	btn.add_theme_stylebox_override("pressed", empty_sb)
	btn.add_theme_stylebox_override("focus", empty_sb)
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_constant_override("outline_size", 4)
	btn.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.05, 0.9))

func _setup_button_juice() -> void:
	for btn in buttons:
		if not btn:
			continue
		btn.pivot_offset = btn.size * 0.5
		btn.mouse_entered.connect(func():
			btn.pivot_offset = btn.size * 0.5
			var tw := btn.create_tween()
			tw.tween_property(btn, "scale", Vector2(1.03, 1.03), 0.1).set_trans(Tween.TRANS_SINE)
			if has_node("/root/AudioManager"):
				get_node("/root/AudioManager").play_sfx("click")
		)
		btn.mouse_exited.connect(func():
			btn.pivot_offset = btn.size * 0.5
			var tw := btn.create_tween()
			tw.tween_property(btn, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_SINE)
		)


func _setup_signals() -> void:
	if village_btn:
		village_btn.pressed.connect(func():
			if has_node("/root/AudioManager"): get_node("/root/AudioManager").play_sfx("click")
			get_tree().change_scene_to_file("res://scenes/village/VillageHub.tscn")
		)
	if settings_btn:
		settings_btn.pressed.connect(func():
			if has_node("/root/AudioManager"): get_node("/root/AudioManager").play_sfx("click")
			get_tree().change_scene_to_file("res://scenes/menu/MainMenu.tscn")
		)

	if mute_btn:
		_update_mute_btn_visual()
		mute_btn.pressed.connect(_on_mute_btn_pressed)
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").sound_mute_toggled.connect(func(_m): _update_mute_btn_visual())

	if knight_dais:
		knight_dais.gui_input.connect(_on_knight_dais_gui_input)


func _update_mute_btn_visual() -> void:
	if not mute_btn:
		return
	var is_muted := false
	if has_node("/root/AudioManager"):
		is_muted = get_node("/root/AudioManager").is_master_muted()
	mute_btn.text = "🔇 AUS" if is_muted else "🔊 TON"
	mute_btn.add_theme_color_override("font_color", Color("#f87171") if is_muted else Color("#4ade80"))


func _on_mute_btn_pressed() -> void:
	if has_node("/root/AudioManager"):
		var am = get_node("/root/AudioManager")
		var was_muted = am.is_master_muted()
		var _new_muted = am.toggle_mute()
		if was_muted:
			am.play_sfx("click")
		_update_mute_btn_visual()


func _on_knight_dais_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if ascii_knight:
			ascii_knight.play_slash()
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx("sword_slash")


func _update_header() -> void:
	var lv: int = 1
	var diamonds: int = 0
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		lv = sm.knight_level
		diamonds = sm.diamonds

	if level_badge:
		level_badge.text = "Lv. " + str(lv)
	if diamond_label:
		diamond_label.text = "💎 " + str(diamonds)


func _play_entrance_animation() -> void:
	# Title banner is static: no bounce, no pulsing loop
	if title_banner:
		title_banner.scale = Vector2.ONE

	# Broad text buttons pop & fade in
	var btn_tween := create_tween().set_parallel(true)
	var delay := 0.0
	for btn in buttons:
		if btn:
			btn_tween.tween_property(btn, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
			btn_tween.tween_property(btn, "modulate:a", 1.0, 0.25).set_delay(delay)
			delay += 0.08


func _play_pedestal_bobbing() -> void:
	if knight_dais:
		var orig_y = knight_dais.position.y
		var tween := create_tween().set_loops()
		tween.tween_property(knight_dais, "position:y", orig_y - 3.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(knight_dais, "position:y", orig_y, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
