extends CanvasLayer
## End-Game Screen controller — handles both VICTORY and DEFEAT states,
## displaying final score, high score recognition, and full gameplay statistics.

@onready var panel_frame: PanelContainer = $CenterContainer/PanelFrame
@onready var game_over_label: Label = $CenterContainer/PanelFrame/VBoxContainer/GameOverLabel
@onready var sub_label: Label = $CenterContainer/PanelFrame/VBoxContainer/SubLabel
@onready var highscore_badge: Label = $CenterContainer/PanelFrame/VBoxContainer/HighscoreBadge
@onready var score_badge: PanelContainer = $CenterContainer/PanelFrame/VBoxContainer/ScoreBadge
@onready var score_label: Label = $CenterContainer/PanelFrame/VBoxContainer/ScoreBadge/ScoreLabel
@onready var stats_panel: PanelContainer = $CenterContainer/PanelFrame/VBoxContainer/StatsPanel
@onready var stat_speed_label: Label = $CenterContainer/PanelFrame/VBoxContainer/StatsPanel/StatsGrid/StatSpeedLabel
@onready var stat_avg_label: Label = $CenterContainer/PanelFrame/VBoxContainer/StatsPanel/StatsGrid/StatAvgLabel
@onready var stat_accuracy_label: Label = $CenterContainer/PanelFrame/VBoxContainer/StatsPanel/StatsGrid/StatAccuracyLabel
@onready var stat_combo_label: Label = $CenterContainer/PanelFrame/VBoxContainer/StatsPanel/StatsGrid/StatComboLabel
@onready var stat_stage_label: Label = $CenterContainer/PanelFrame/VBoxContainer/StatsPanel/StatsGrid/StatStageLabel
@onready var stat_time_label: Label = $CenterContainer/PanelFrame/VBoxContainer/StatsPanel/StatsGrid/StatTimeLabel
@onready var background: ColorRect = $Background
@onready var center: CenterContainer = $CenterContainer
@onready var retry_btn: Button = $CenterContainer/PanelFrame/VBoxContainer/ButtonContainer/RetryButton
@onready var menu_btn: Button = $CenterContainer/PanelFrame/VBoxContainer/ButtonContainer/MenuButton


func _ready() -> void:
	_setup_styles()
	_set_visibility(false)


func _setup_styles() -> void:
	# Main Frame Style
	var frame_style: StyleBoxFlat = StyleBoxFlat.new()
	frame_style.bg_color = Color(0.11, 0.08, 0.16, 0.95)
	frame_style.border_color = Color(0.75, 0.60, 0.25)
	frame_style.set_border_width_all(2)
	frame_style.set_corner_radius_all(8)
	frame_style.shadow_color = Color(0, 0, 0, 0.75)
	frame_style.shadow_size = 14
	frame_style.content_margin_left = 16
	frame_style.content_margin_right = 16
	frame_style.content_margin_top = 14
	frame_style.content_margin_bottom = 14
	panel_frame.add_theme_stylebox_override("panel", frame_style)

	# Score Badge Style
	var score_style: StyleBoxFlat = StyleBoxFlat.new()
	score_style.bg_color = Color(0.08, 0.06, 0.12, 0.9)
	score_style.border_color = Color(0.5, 0.42, 0.6, 0.6)
	score_style.set_border_width_all(1)
	score_style.set_corner_radius_all(4)
	score_style.content_margin_left = 14
	score_style.content_margin_right = 14
	score_style.content_margin_top = 4
	score_style.content_margin_bottom = 4
	score_badge.add_theme_stylebox_override("panel", score_style)

	# Stats Panel Style
	var stats_style: StyleBoxFlat = StyleBoxFlat.new()
	stats_style.bg_color = Color(0.07, 0.05, 0.11, 0.85)
	stats_style.border_color = Color(0.35, 0.30, 0.45, 0.5)
	stats_style.set_border_width_all(1)
	stats_style.set_corner_radius_all(4)
	stats_style.content_margin_left = 10
	stats_style.content_margin_right = 10
	stats_style.content_margin_top = 6
	stats_style.content_margin_bottom = 6
	stats_panel.add_theme_stylebox_override("panel", stats_style)

	# Retry Button (Gold Champion)
	var retry_normal: StyleBoxFlat = StyleBoxFlat.new()
	retry_normal.bg_color = Color(0.95, 0.75, 0.2)
	retry_normal.border_color = Color(1.0, 0.9, 0.5)
	retry_normal.set_border_width_all(2)
	retry_normal.set_corner_radius_all(5)
	var retry_hover: StyleBoxFlat = retry_normal.duplicate()
	retry_hover.bg_color = Color(1.0, 0.85, 0.3)

	retry_btn.add_theme_stylebox_override("normal", retry_normal)
	retry_btn.add_theme_stylebox_override("hover", retry_hover)
	retry_btn.add_theme_stylebox_override("pressed", retry_normal)
	retry_btn.add_theme_stylebox_override("focus", retry_hover)

	# Menu Button (Muted Slate)
	var menu_normal: StyleBoxFlat = StyleBoxFlat.new()
	menu_normal.bg_color = Color(0.2, 0.16, 0.28)
	menu_normal.border_color = Color(0.5, 0.45, 0.6)
	menu_normal.set_border_width_all(1)
	menu_normal.set_corner_radius_all(5)
	var menu_hover: StyleBoxFlat = menu_normal.duplicate()
	menu_hover.bg_color = Color(0.28, 0.22, 0.38)
	menu_hover.border_color = Color(0.8, 0.7, 0.9)

	menu_btn.add_theme_stylebox_override("normal", menu_normal)
	menu_btn.add_theme_stylebox_override("hover", menu_hover)
	menu_btn.add_theme_stylebox_override("pressed", menu_normal)
	menu_btn.add_theme_stylebox_override("focus", menu_hover)


func show_game_over(_final_score: int) -> void:
	var stats: Dictionary = GameManager.get_run_statistics()
	show_end_screen(stats)


func show_victory(stats: Dictionary) -> void:
	show_end_screen(stats)


func show_end_screen(stats: Dictionary) -> void:
	var is_victory: bool = stats.get("is_victory", false)
	var score: int = stats.get("score", 0)
	var is_new_high: bool = stats.get("is_new_highscore", false)
	var current_stg: int = stats.get("current_stage", 1)
	var total_stg: int = stats.get("total_stages", 12)
	var fastest_t: float = stats.get("fastest_answer_time", 0.0)
	var avg_t: float = stats.get("average_answer_time", 0.0)
	var accuracy: float = stats.get("accuracy", 100.0)
	var max_cmb: int = stats.get("max_combo", 0)
	var run_time: float = stats.get("run_time_sec", 0.0)

	if is_victory:
		game_over_label.text = "SIEG!"
		game_over_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.85))
		sub_label.text = "Alle 12 Stufen glorreich gemeistert!"
		sub_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
		retry_btn.text = "Nochmal Spielen"
	else:
		game_over_label.text = "NIEDERLAGE"
		game_over_label.add_theme_color_override("font_color", Color(0.95, 0.25, 0.25))
		sub_label.text = "Dein Ritter ist ehrenvoll gefallen"
		sub_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
		retry_btn.text = "Erneut Kämpfen"

	highscore_badge.visible = is_new_high
	score_label.text = "Punkte: %d (Highscore: %d)" % [score, stats.get("high_score", score)]

	# Stats Grid
	stat_speed_label.text = "⏱ Schnellste: %.2fs" % fastest_t if fastest_t > 0.0 else "⏱ Schnellste: --"
	stat_avg_label.text = "📊 Ø Zeit: %.2fs" % avg_t if avg_t > 0.0 else "📊 Ø Zeit: --"
	stat_accuracy_label.text = "🎯 Quote: %.1f%%" % accuracy
	stat_combo_label.text = "⚡ Max Combo: x%d" % max_cmb
	stat_stage_label.text = "🏆 Stufe: %d / %d" % [current_stg, total_stg]
	
	var minutes: int = int(run_time) / 60
	var seconds: int = int(run_time) % 60
	stat_time_label.text = "⏳ Zeit: %dm %02ds" % [minutes, seconds]

	_set_visibility(true)

	background.modulate.a = 0.0
	center.modulate.a = 0.0
	center.scale = Vector2(0.85, 0.85)

	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(background, "modulate:a", 1.0, 0.3)
	tween.tween_property(center, "modulate:a", 1.0, 0.35).set_delay(0.08)
	tween.tween_property(center, "scale", Vector2.ONE, 0.35).set_delay(0.08) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _set_visibility(is_visible: bool) -> void:
	background.visible = is_visible
	center.visible = is_visible


func _on_retry_button_pressed() -> void:
	if has_node("/root/RunManager"):
		var rm = get_node("/root/RunManager")
		if rm.is_run_active:
			rm.end_run(false)
			rm.start_new_run()
			get_tree().change_scene_to_file("res://scenes/map/RunMap.tscn")
			return

	get_tree().reload_current_scene()


func _on_menu_button_pressed() -> void:
	if has_node("/root/RunManager"):
		var rm = get_node("/root/RunManager")
		if rm.is_run_active:
			rm.end_run(false)
	get_tree().change_scene_to_file("res://scenes/menu/TitleScreen.tscn")

