extends CanvasLayer

@onready var hp_label: Label = $MarginContainer/TopBar/HPBadge/HPContainer/HPLabel
@onready var hp_badge: PanelContainer = $MarginContainer/TopBar/HPBadge
@onready var stage_label: Label = $MarginContainer/TopBar/StageBadge/StageLabel
@onready var stage_badge: PanelContainer = $MarginContainer/TopBar/StageBadge
@onready var score_label: Label = $MarginContainer/TopBar/ScoreBadge/ScoreLabel
@onready var score_badge: PanelContainer = $MarginContainer/TopBar/ScoreBadge
@onready var combo_label: Label = $MarginContainer/TopBar/ComboLabel
@onready var menu_btn: Button = $MarginContainer/TopBar/MenuBtn
@onready var countdown_label: Label = $CountdownContainer/CountdownLabel

var _countdown_tween: Tween


func _ready() -> void:
	_setup_styles()
	EventBus.knight_damaged.connect(_on_knight_damaged)
	EventBus.score_changed.connect(update_score)
	EventBus.combo_changed.connect(update_combo)
	EventBus.stage_changed.connect(update_stage)
	EventBus.countdown_tick.connect(_on_countdown_tick)
	if menu_btn:
		menu_btn.pressed.connect(_on_menu_pressed)
	update_combo(0)
	update_stage(GameManager.current_stage, GameManager.TOTAL_STAGES)


func _setup_styles() -> void:
	# Badge Style (HP & Score & Stage)
	var badge_style: StyleBoxFlat = StyleBoxFlat.new()
	badge_style.bg_color = Color(0.12, 0.10, 0.18, 0.85)
	badge_style.border_color = Color(0.4, 0.35, 0.5, 0.7)
	badge_style.set_border_width_all(1)
	badge_style.set_corner_radius_all(4)
	badge_style.content_margin_left = 8
	badge_style.content_margin_right = 8
	badge_style.content_margin_top = 2
	badge_style.content_margin_bottom = 2

	hp_badge.add_theme_stylebox_override("panel", badge_style)
	stage_badge.add_theme_stylebox_override("panel", badge_style)
	score_badge.add_theme_stylebox_override("panel", badge_style)

	# Menu Button Style
	var btn_style: StyleBoxFlat = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.18, 0.15, 0.25, 0.9)
	btn_style.border_color = Color(0.6, 0.5, 0.3)
	btn_style.set_border_width_all(1)
	btn_style.set_corner_radius_all(4)
	btn_style.content_margin_left = 6
	btn_style.content_margin_right = 6

	var btn_hover: StyleBoxFlat = btn_style.duplicate()
	btn_hover.bg_color = Color(0.28, 0.22, 0.38, 0.95)
	btn_hover.border_color = Color(0.9, 0.8, 0.4)

	menu_btn.add_theme_stylebox_override("normal", btn_style)
	menu_btn.add_theme_stylebox_override("hover", btn_hover)
	menu_btn.add_theme_stylebox_override("pressed", btn_style)
	menu_btn.add_theme_stylebox_override("focus", btn_hover)


func update_hp(current: float, max_hp: float) -> void:
	hp_label.text = "%d / %d" % [int(current), int(max_hp)]


func _on_knight_damaged(current: float, max_hp: float) -> void:
	update_hp(current, max_hp)
	var t: Tween = create_tween()
	hp_badge.modulate = Color(2.0, 0.6, 0.6)
	t.tween_property(hp_badge, "modulate", Color.WHITE, 0.25)


func update_score(score: int) -> void:
	score_label.text = "Punkte: %d" % score


func update_stage(stage: int, total_stages: int) -> void:
	if stage_label:
		if total_stages <= 5:
			stage_label.text = "Welle: %d / %d" % [stage, total_stages]
		else:
			stage_label.text = "Stufe: %d / %d" % [stage, total_stages]
		var t: Tween = create_tween()
		stage_badge.scale = Vector2(1.15, 1.15)
		t.tween_property(stage_badge, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func update_combo(count: int) -> void:
	if count <= 1:
		combo_label.text = ""
		combo_label.visible = false
	else:
		combo_label.text = "COMBO x%d!" % count
		combo_label.visible = true
		
		var tween: Tween = create_tween()
		combo_label.scale = Vector2(1.4, 1.4)
		tween.tween_property(combo_label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/MainMenu.tscn")


func _on_countdown_tick(count_text: String) -> void:
	if not countdown_label:
		return

	if _countdown_tween and _countdown_tween.is_valid():
		_countdown_tween.kill()

	countdown_label.text = count_text
	countdown_label.visible = true

	if count_text.begins_with("⚔️") or count_text.contains("LOS"):
		countdown_label.add_theme_font_size_override("font_size", 22)
		countdown_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.85))
	else:
		countdown_label.add_theme_font_size_override("font_size", 36)
		countdown_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.4))

	# Pure static size shift: 0 rotation, 0 drift, 0 particles
	countdown_label.rotation = 0.0
	countdown_label.scale = Vector2(1.5, 1.5)
	countdown_label.modulate.a = 1.0

	_countdown_tween = create_tween()
	# 1. Shrink smoothly to 1.0
	_countdown_tween.tween_property(countdown_label, "scale", Vector2.ONE, 0.15) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 2. Hold completely static
	_countdown_tween.tween_interval(0.55)
	# 3. Fade out
	_countdown_tween.tween_property(countdown_label, "modulate:a", 0.0, 0.22) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_countdown_tween.tween_callback(func(): countdown_label.visible = false)
