class_name StageSelectScreen
extends Control
## StageSelectScreen — Presents 3 dynamic portal cards before each combat stage.
## Features matrix code rain background, cyber-ASCII card styling,
## glitch cipher decoders on hover, and smooth animated portal transitions.

@onready var bg: MenuBackground = $MenuBackground
@onready var stage_badge: Label = $MarginContainer/MainLayout/TopBar/StageBadge/StageLabel
@onready var hp_label: Label = $MarginContainer/MainLayout/TopBar/HPBadge/HPContainer/HPLabel
@onready var gold_label: Label = $MarginContainer/MainLayout/TopBar/GoldBadge/GoldContainer/GoldLabel
@onready var diamond_label: Label = $MarginContainer/MainLayout/TopBar/DiamondBadge/DiamondContainer/DiamondLabel
@onready var cards_container: HBoxContainer = $MarginContainer/MainLayout/CardsArea/CardsContainer
@onready var title_label: Label = $MarginContainer/MainLayout/Header/TitleLabel
@onready var subtitle_label: Label = $MarginContainer/MainLayout/Header/SubtitleLabel
@onready var rest_hub_btn: Button = $MarginContainer/MainLayout/TopBar/RestHubBtn

var _card_panels: Array[Control] = []
var _is_transitioning: bool = false

const CIPHER_CHARS: Array[String] = ["0", "1", "+", "-", "*", "/", "%", "=", "#", "X", "<", ">", "!", "?"]


func _ready() -> void:
	if not has_node("/root/RunManager"):
		return

	var rm: Node = get_node("/root/RunManager")
	if not rm.is_run_active:
		rm.start_new_run()

	_setup_top_bar()
	_render_cards()
	_play_entrance_animation()

	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_music("map")


func _setup_top_bar() -> void:
	var rm: Node = get_node("/root/RunManager")
	var stg_num: int = rm.current_stage_index + 1
	var is_boss: bool = (stg_num >= RunManager.FINAL_BOSS_STAGE)

	if is_boss:
		stage_badge.text = "👑 STUFE %d: DER ENDBOSS" % stg_num
		stage_badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		title_label.text = "DAS FINALE MATHE-PORTAL"
		subtitle_label.text = "Besiege den Zahlen-Titan Kronos und sichere dir ewigen Ruhm!"
	else:
		stage_badge.text = "⚔️ STUFE %d / %d" % [stg_num, RunManager.TOTAL_REGULAR_STAGES]
		title_label.text = "WÄHLE DEIN PORTAL"
		subtitle_label.text = "Wähle Rechenart, Tempo und Belohnung für die nächste Prüfung"

	# Knight HP
	hp_label.text = "%d / %d" % [int(rm.knight_run_hp), int(rm.knight_run_max_hp)]
	gold_label.text = "%d" % rm.run_gold

	var diamonds: int = 0
	if has_node("/root/SaveManager"):
		diamonds = get_node("/root/SaveManager").diamonds
	diamond_label.text = "%d" % diamonds

	if rest_hub_btn:
		rest_hub_btn.pressed.connect(_on_rest_hub_pressed)
		_add_hover_juice(rest_hub_btn)


func _render_cards() -> void:
	for child in cards_container.get_children():
		child.queue_free()
	_card_panels.clear()

	var rm: Node = get_node("/root/RunManager")
	var choices: Array[Dictionary] = rm.current_stage_choices
	if choices.is_empty():
		choices = rm.generate_stage_choices(rm.current_stage_index)

	for i in range(choices.size()):
		var choice_data: Dictionary = choices[i]
		var card_panel: PanelContainer = _create_choice_card(choice_data, i)
		cards_container.add_child(card_panel)
		_card_panels.append(card_panel)


func _create_choice_card(data: Dictionary, index: int) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(185, 235)
	panel.pivot_offset = Vector2(92, 117)

	var archetype: String = data.get("archetype", "standard")
	var is_boss: bool = (data.get("type", "") == "boss")

	# Accent colors based on archetype
	var accent_color: Color = Color(0.25, 0.75, 1.0) # Standard Cyan
	var bg_color: Color = Color(0.08, 0.07, 0.14, 0.92)
	var glow_color: Color = Color(0.2, 0.6, 0.9, 0.3)

	match archetype:
		"speed":
			accent_color = Color(1.0, 0.8, 0.2) # Gold / Lightning
			glow_color = Color(1.0, 0.75, 0.1, 0.35)
		"elite":
			accent_color = Color(0.85, 0.35, 1.0) # Violet / Arcane
			glow_color = Color(0.8, 0.25, 0.95, 0.4)
		"boss":
			accent_color = Color(1.0, 0.3, 0.3) # Crimson / Titan
			glow_color = Color(1.0, 0.2, 0.2, 0.5)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = accent_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.shadow_color = glow_color
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 3)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	panel.add_child(vbox)

	# 1. Header Archetype Badge
	var header_badge: Label = Label.new()
	header_badge.text = data.get("title", "Portaltür")
	header_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_badge.add_theme_color_override("font_color", accent_color.lerp(Color.WHITE, 0.3))
	header_badge.add_theme_font_size_override("font_size", 10)
	vbox.add_child(header_badge)

	# 2. Big Math Symbol & Operation
	var rm: Node = get_node("/root/RunManager")
	var symbol_label: Label = Label.new()
	symbol_label.text = rm.get_operation_symbol(data)
	symbol_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	symbol_label.add_theme_font_size_override("font_size", 24)
	symbol_label.add_theme_color_override("font_color", accent_color)
	vbox.add_child(symbol_label)

	# 3. Mode & Operation Name
	var op_label: Label = Label.new()
	op_label.text = rm.get_operation_name(data)
	op_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	op_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	op_label.add_theme_font_size_override("font_size", 9)
	vbox.add_child(op_label)

	var mode_label: Label = Label.new()
	mode_label.text = "Modus: " + rm.get_mode_name(data)
	mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_label.add_theme_color_override("font_color", Color(0.65, 0.7, 0.85))
	mode_label.add_theme_font_size_override("font_size", 8)
	vbox.add_child(mode_label)

	# 4. Difficulty Stars & Input Info
	var diff_box: HBoxContainer = HBoxContainer.new()
	diff_box.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(diff_box)

	var math_diff_lbl: Label = Label.new()
	math_diff_lbl.text = "Mathe: " + rm.get_difficulty_stars(data)
	math_diff_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	math_diff_lbl.add_theme_font_size_override("font_size", 8)
	diff_box.add_child(math_diff_lbl)

	var input_lbl: Label = Label.new()
	var in_type_name: String = rm.get_input_type_name(data.get("input_type", 0))
	var in_diff_name: String = rm.get_input_difficulty_name(data.get("input_difficulty", 0))
	input_lbl.text = "Input: %s (%s)" % [in_type_name, in_diff_name]
	input_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	input_lbl.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9))
	input_lbl.add_theme_font_size_override("font_size", 8)
	vbox.add_child(input_lbl)

	# 5. Rewards Box
	var reward_panel: PanelContainer = PanelContainer.new()
	var rew_style: StyleBoxFlat = StyleBoxFlat.new()
	rew_style.bg_color = Color(0.05, 0.04, 0.09, 0.7)
	rew_style.border_color = accent_color * 0.6
	rew_style.set_border_width_all(1)
	rew_style.set_corner_radius_all(4)
	rew_style.content_margin_left = 6
	rew_style.content_margin_right = 6
	rew_style.content_margin_top = 4
	rew_style.content_margin_bottom = 4
	reward_panel.add_theme_stylebox_override("panel", rew_style)
	vbox.add_child(reward_panel)

	var rew_vbox: VBoxContainer = VBoxContainer.new()
	rew_vbox.add_theme_constant_override("separation", 2)
	reward_panel.add_child(rew_vbox)

	var gold_reward_lbl: Label = Label.new()
	gold_reward_lbl.text = "🪙 +%d Gold" % data.get("reward_gold", 20)
	gold_reward_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.35))
	gold_reward_lbl.add_theme_font_size_override("font_size", 8)
	rew_vbox.add_child(gold_reward_lbl)

	var mods: Array = data.get("modifiers", [])
	for m in mods:
		var mod_lbl: Label = Label.new()
		mod_lbl.text = str(m)
		mod_lbl.add_theme_color_override("font_color", accent_color.lerp(Color.WHITE, 0.4))
		mod_lbl.add_theme_font_size_override("font_size", 7)
		rew_vbox.add_child(mod_lbl)

	# Spacer
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# 6. Action Button
	var choose_btn: Button = Button.new()
	choose_btn.text = "PORTAL BETRETEN ➔" if not is_boss else "ENDBOSS KÄMPFEN ⚔️"
	choose_btn.custom_minimum_size = Vector2(0, 28)
	choose_btn.add_theme_font_size_override("font_size", 9)

	var btn_style: StyleBoxFlat = StyleBoxFlat.new()
	btn_style.bg_color = Color(accent_color.r * 0.35, accent_color.g * 0.35, accent_color.b * 0.35, 0.95)
	btn_style.border_color = accent_color
	btn_style.set_border_width_all(1)
	btn_style.set_corner_radius_all(4)
	choose_btn.add_theme_stylebox_override("normal", btn_style)
	choose_btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))

	var btn_hover: StyleBoxFlat = btn_style.duplicate()
	btn_hover.bg_color = Color(accent_color.r * 0.6, accent_color.g * 0.6, accent_color.b * 0.6, 1.0)
	choose_btn.add_theme_stylebox_override("hover", btn_hover)
	choose_btn.add_theme_stylebox_override("pressed", btn_hover)

	choose_btn.pressed.connect(func(): _on_card_selected(index, panel, choose_btn))
	vbox.add_child(choose_btn)

	# Attach hover animations & text scramble
	_attach_card_juice(panel, header_badge, data.get("title", ""), accent_color)

	return panel


func _attach_card_juice(panel: Control, title_lbl: Label, default_title: String, accent_color: Color) -> void:
	panel.mouse_entered.connect(func():
		if _is_transitioning:
			return
		var tween: Tween = create_tween().set_parallel(true)
		tween.tween_property(panel, "scale", Vector2(1.035, 1.035), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(panel, "position:y", -5.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

		_trigger_cipher_scramble(title_lbl, default_title, accent_color)
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx("click", 1.1)
	)

	panel.mouse_exited.connect(func():
		if _is_transitioning:
			return
		var tween: Tween = create_tween().set_parallel(true)
		tween.tween_property(panel, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(panel, "position:y", 0.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		title_lbl.text = default_title
	)


func _trigger_cipher_scramble(lbl: Label, original_text: String, col: Color) -> void:
	var tween: Tween = create_tween()
	var steps: int = 5
	for s in range(steps):
		tween.tween_callback(func():
			if not is_instance_valid(lbl):
				return
			if s == steps - 1:
				lbl.text = original_text
				lbl.add_theme_color_override("font_color", col.lerp(Color.WHITE, 0.3))
			else:
				var scrambled: String = ""
				for i in range(original_text.length()):
					var ch: String = original_text[i]
					if ch == " " or ch == "⚔" or ch == "⚡" or ch == "🛡" or ch == "👑":
						scrambled += ch
					else:
						scrambled += CIPHER_CHARS[randi() % CIPHER_CHARS.size()]
				lbl.text = scrambled
		)
		tween.tween_interval(0.04)


func _add_hover_juice(btn: Button) -> void:
	btn.pivot_offset = btn.size / 2.0
	btn.mouse_entered.connect(func():
		var t: Tween = btn.create_tween()
		t.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.1).set_trans(Tween.TRANS_SINE)
	)
	btn.mouse_exited.connect(func():
		var t: Tween = btn.create_tween()
		t.tween_property(btn, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_SINE)
	)


func _play_entrance_animation() -> void:
	var delay: float = 0.0
	for card in _card_panels:
		card.scale = Vector2(0.8, 0.8)
		card.modulate.a = 0.0
		var tween: Tween = create_tween().set_parallel(true)
		tween.tween_property(card, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
		tween.tween_property(card, "modulate:a", 1.0, 0.25).set_delay(delay)
		delay += 0.08


func _on_card_selected(index: int, selected_panel: PanelContainer, _btn: Button) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true

	var rm: Node = get_node("/root/RunManager")
	var chosen_data: Dictionary = rm.select_stage_choice(index)

	# Configure MathEngine with selected stage configuration
	if has_node("/root/MathEngine"):
		var cfg: MathConfig = rm.get_math_config_for_stage(chosen_data)
		get_node("/root/MathEngine").set_difficulty(cfg)

	# Audio & Shake Juice
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").screen_shake_requested.emit(0.45)
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("sword_slash", 1.1)

	# Visual selection animation: Flash & Zoom selected card, fade others
	var tween: Tween = create_tween().set_parallel(true)
	for p in _card_panels:
		if p == selected_panel:
			tween.tween_property(p, "scale", Vector2(1.12, 1.12), 0.2).set_trans(Tween.TRANS_BACK)
			p.modulate = Color(2.0, 2.0, 2.0)
			var flash_tween: Tween = create_tween()
			flash_tween.tween_property(p, "modulate", Color.WHITE, 0.2)
		else:
			tween.tween_property(p, "modulate:a", 0.0, 0.2)

	# Fade out and transition to Combat Main scene
	tween.chain().tween_interval(0.15)
	tween.chain().tween_property(self, "modulate:a", 0.0, 0.25)
	tween.chain().tween_callback(func():
		get_tree().change_scene_to_file("res://scenes/main/Main.tscn")
	)


func _on_rest_hub_pressed() -> void:
	if _is_transitioning:
		return
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("click")
	get_tree().change_scene_to_file("res://scenes/stage/StageRewardHub.tscn")
