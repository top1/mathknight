extends Control
## Main Menu controller for MathKnight.
## Manages mode, operation, and difficulty selection with a rich fantasy RPG interface.

var selected_mode: MathConfig.GameMode = MathConfig.GameMode.TASK_TO_RESULT
var selected_operation: MathConfig.Operation = MathConfig.Operation.ADDITION
var selected_difficulty: MathConfig.Difficulty = MathConfig.Difficulty.EASY

# Node references
@onready var back_btn: Button = $MarginContainer/MainLayout/HeaderBar/BackBtn
@onready var lab_btn: Button = $MarginContainer/MainLayout/HeaderBar/LabBtn
@onready var mode_1_btn: Button = $MarginContainer/MainLayout/ModeSection/ModeContainer/Mode1Btn
@onready var mode_2_btn: Button = $MarginContainer/MainLayout/ModeSection/ModeContainer/Mode2Btn
@onready var mode_3_btn: Button = $MarginContainer/MainLayout/ModeSection/ModeContainer/Mode3Btn

@onready var op_add_btn: Button = $MarginContainer/MainLayout/ConfigGrid/OpSection/OpContainer/OpAddBtn
@onready var op_sub_btn: Button = $MarginContainer/MainLayout/ConfigGrid/OpSection/OpContainer/OpSubBtn
@onready var op_mul_btn: Button = $MarginContainer/MainLayout/ConfigGrid/OpSection/OpContainer/OpMulBtn
@onready var op_div_btn: Button = $MarginContainer/MainLayout/ConfigGrid/OpSection/OpContainer/OpDivBtn
@onready var op_mix_btn: Button = $MarginContainer/MainLayout/ConfigGrid/OpSection/OpContainer/OpMixBtn

@onready var diff_easy_btn: Button = $MarginContainer/MainLayout/ConfigGrid/DiffSection/DiffContainer/DiffEasyBtn
@onready var diff_med_btn: Button = $MarginContainer/MainLayout/ConfigGrid/DiffSection/DiffContainer/DiffMedBtn
@onready var diff_hard_btn: Button = $MarginContainer/MainLayout/ConfigGrid/DiffSection/DiffContainer/DiffHardBtn

@onready var info_panel: PanelContainer = $MarginContainer/MainLayout/InfoPanel
@onready var info_label: Label = $MarginContainer/MainLayout/InfoPanel/InfoLabel
@onready var start_btn: Button = $MarginContainer/MainLayout/ActionRow/StartBtn

var _start_pulse_tween: Tween

func _ready() -> void:
	_setup_styles()
	_connect_signals()
	_update_all_visuals()
	_start_button_pulse()
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_music("menu")

func _setup_styles() -> void:
	# Back & Lab Button Style
	var back_style = StyleBoxFlat.new()
	back_style.bg_color = Color(0.18, 0.14, 0.24, 0.9)
	back_style.border_color = Color(0.45, 0.38, 0.55)
	back_style.set_border_width_all(1)
	back_style.set_corner_radius_all(4)
	back_btn.add_theme_stylebox_override("normal", back_style)
	if lab_btn:
		lab_btn.add_theme_stylebox_override("normal", back_style)

	# Info Panel Style
	var info_style: StyleBoxFlat = StyleBoxFlat.new()
	info_style.bg_color = Color(0.10, 0.08, 0.16, 0.9)
	info_style.border_color = Color(0.55, 0.45, 0.25, 0.8)
	info_style.set_border_width_all(1)
	info_style.set_corner_radius_all(4)
	info_style.content_margin_left = 8
	info_style.content_margin_right = 8
	info_style.content_margin_top = 4
	info_style.content_margin_bottom = 4
	info_panel.add_theme_stylebox_override("panel", info_style)

	# Start Button Style - Gold Banner Champion Style
	var start_normal: StyleBoxFlat = StyleBoxFlat.new()
	start_normal.bg_color = Color(0.95, 0.72, 0.15)
	start_normal.border_color = Color(1.0, 0.9, 0.5)
	start_normal.set_border_width_all(2)
	start_normal.set_corner_radius_all(6)
	start_normal.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	start_normal.shadow_size = 4
	start_normal.shadow_offset = Vector2(0, 2)

	var start_hover: StyleBoxFlat = start_normal.duplicate()
	start_hover.bg_color = Color(1.0, 0.82, 0.25)
	start_hover.border_color = Color(1.0, 1.0, 0.7)

	var start_pressed: StyleBoxFlat = start_normal.duplicate()
	start_pressed.bg_color = Color(0.8, 0.58, 0.1)
	start_pressed.border_color = Color(0.8, 0.7, 0.3)
	start_pressed.shadow_size = 1
	start_pressed.shadow_offset = Vector2(0, 1)

	start_btn.add_theme_stylebox_override("normal", start_normal)
	start_btn.add_theme_stylebox_override("hover", start_hover)
	start_btn.add_theme_stylebox_override("pressed", start_pressed)
	start_btn.add_theme_stylebox_override("focus", start_hover)

func _connect_signals() -> void:
	back_btn.pressed.connect(func():
		if has_node("/root/AudioManager"): get_node("/root/AudioManager").play_sfx("click")
		get_tree().change_scene_to_file("res://scenes/menu/TitleScreen.tscn")
	)
	if lab_btn:
		lab_btn.pressed.connect(func():
			if has_node("/root/AudioManager"): get_node("/root/AudioManager").play_sfx("click")
			get_tree().change_scene_to_file("res://scenes/test/BubbleTuningLab.tscn")
		)
		_add_button_hover_juice(lab_btn)

	# Back button juice
	_add_button_hover_juice(back_btn)
	_add_button_hover_juice(mode_1_btn)
	_add_button_hover_juice(mode_2_btn)
	_add_button_hover_juice(mode_3_btn)
	_add_button_hover_juice(op_add_btn)
	_add_button_hover_juice(op_sub_btn)
	_add_button_hover_juice(op_mul_btn)
	_add_button_hover_juice(op_div_btn)
	_add_button_hover_juice(op_mix_btn)
	_add_button_hover_juice(diff_easy_btn)
	_add_button_hover_juice(diff_med_btn)
	_add_button_hover_juice(diff_hard_btn)
	_add_button_hover_juice(start_btn)

	# Modes
	mode_1_btn.pressed.connect(func(): _select_mode(MathConfig.GameMode.TASK_TO_RESULT, mode_1_btn))
	mode_2_btn.pressed.connect(func(): _select_mode(MathConfig.GameMode.RESULT_TO_EQUATION, mode_2_btn))
	mode_3_btn.pressed.connect(func(): _select_mode(MathConfig.GameMode.MULTI_OP_EQUATION, mode_3_btn))

	# Operations
	op_add_btn.pressed.connect(func(): _select_op(MathConfig.Operation.ADDITION, op_add_btn))
	op_sub_btn.pressed.connect(func(): _select_op(MathConfig.Operation.SUBTRACTION, op_sub_btn))
	op_mul_btn.pressed.connect(func(): _select_op(MathConfig.Operation.MULTIPLICATION, op_mul_btn))
	op_div_btn.pressed.connect(func(): _select_op(MathConfig.Operation.DIVISION, op_div_btn))
	op_mix_btn.pressed.connect(func(): _select_op(MathConfig.Operation.MIXED, op_mix_btn))

	# Difficulties
	diff_easy_btn.pressed.connect(func(): _select_diff(MathConfig.Difficulty.EASY, diff_easy_btn))
	diff_med_btn.pressed.connect(func(): _select_diff(MathConfig.Difficulty.MEDIUM, diff_med_btn))
	diff_hard_btn.pressed.connect(func(): _select_diff(MathConfig.Difficulty.HARD, diff_hard_btn))

	# Start Button
	start_btn.pressed.connect(_on_start_pressed)

func _add_button_hover_juice(btn: Button) -> void:
	if not btn:
		return
	btn.pivot_offset = btn.size / 2.0
	btn.mouse_entered.connect(func():
		btn.pivot_offset = btn.size / 2.0
		var t = btn.create_tween()
		t.tween_property(btn, "scale", Vector2(1.04, 1.04), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)
	btn.mouse_exited.connect(func():
		btn.pivot_offset = btn.size / 2.0
		var t = btn.create_tween()
		t.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	)

func _select_mode(mode: MathConfig.GameMode, btn: Button) -> void:
	selected_mode = mode
	_play_click_anim(btn)
	_update_all_visuals()

func _select_op(op: MathConfig.Operation, btn: Button) -> void:
	selected_operation = op
	_play_click_anim(btn)
	_update_all_visuals()

func _select_diff(diff: MathConfig.Difficulty, btn: Button) -> void:
	selected_difficulty = diff
	_play_click_anim(btn)
	_update_all_visuals()

func _play_click_anim(node: Control) -> void:
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("click")
	var t: Tween = create_tween()
	t.tween_property(node, "scale", Vector2(0.96, 0.96), 0.05).set_trans(Tween.TRANS_SINE)
	t.tween_property(node, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _update_all_visuals() -> void:
	# Mode Cards styling
	_style_card(mode_1_btn, selected_mode == MathConfig.GameMode.TASK_TO_RESULT)
	_style_card(mode_2_btn, selected_mode == MathConfig.GameMode.RESULT_TO_EQUATION)
	_style_card(mode_3_btn, selected_mode == MathConfig.GameMode.MULTI_OP_EQUATION)

	# Operation Chips styling
	_style_chip(op_add_btn, selected_operation == MathConfig.Operation.ADDITION, Color(0.2, 0.5, 0.85))
	_style_chip(op_sub_btn, selected_operation == MathConfig.Operation.SUBTRACTION, Color(0.85, 0.45, 0.2))
	_style_chip(op_mul_btn, selected_operation == MathConfig.Operation.MULTIPLICATION, Color(0.7, 0.3, 0.85))
	_style_chip(op_div_btn, selected_operation == MathConfig.Operation.DIVISION, Color(0.2, 0.75, 0.55))
	_style_chip(op_mix_btn, selected_operation == MathConfig.Operation.MIXED, Color(0.95, 0.75, 0.2))

	# Difficulty Chips styling
	_style_chip(diff_easy_btn, selected_difficulty == MathConfig.Difficulty.EASY, Color(0.25, 0.75, 0.4))
	_style_chip(diff_med_btn, selected_difficulty == MathConfig.Difficulty.MEDIUM, Color(0.95, 0.7, 0.2))
	_style_chip(diff_hard_btn, selected_difficulty == MathConfig.Difficulty.HARD, Color(0.9, 0.25, 0.25))

	# Info Text update
	_update_info_text()

func _style_card(btn: Button, is_selected: bool) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.set_corner_radius_all(6)
	if is_selected:
		style.bg_color = Color(0.25, 0.18, 0.36, 0.95)
		style.border_color = Color(1.0, 0.85, 0.3)
		style.set_border_width_all(2)
		style.shadow_color = Color(1.0, 0.8, 0.2, 0.25)
		style.shadow_size = 4
	else:
		style.bg_color = Color(0.11, 0.09, 0.17, 0.8)
		style.border_color = Color(0.3, 0.27, 0.4, 0.6)
		style.set_border_width_all(1)
		style.shadow_size = 0

	var style_hover: StyleBoxFlat = style.duplicate()
	if not is_selected:
		style_hover.bg_color = Color(0.16, 0.13, 0.24, 0.9)
		style_hover.border_color = Color(0.55, 0.5, 0.7)

	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("focus", style_hover)

func _style_chip(btn: Button, is_selected: bool, accent_color: Color) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.set_corner_radius_all(4)
	if is_selected:
		style.bg_color = Color(accent_color.r * 0.45, accent_color.g * 0.45, accent_color.b * 0.45, 0.95)
		style.border_color = accent_color
		style.set_border_width_all(2)
		style.shadow_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.3)
		style.shadow_size = 4
		btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	else:
		style.bg_color = Color(0.12, 0.10, 0.18, 0.75)
		style.border_color = Color(0.28, 0.25, 0.35, 0.5)
		style.set_border_width_all(1)
		style.shadow_size = 0
		btn.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))

	var style_hover: StyleBoxFlat = style.duplicate()
	if not is_selected:
		style_hover.bg_color = Color(0.18, 0.15, 0.26, 0.85)
		style_hover.border_color = accent_color.lerp(Color.WHITE, 0.3)

	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("focus", style_hover)

func _update_info_text() -> void:
	var config: MathConfig = MathConfig.create_config(selected_mode, selected_operation, selected_difficulty)
	var mode_name: String = ""
	match selected_mode:
		MathConfig.GameMode.TASK_TO_RESULT: mode_name = "Rechen-Schlag"
		MathConfig.GameMode.RESULT_TO_EQUATION: mode_name = "Zahlen-Schmiede"
		MathConfig.GameMode.MULTI_OP_EQUATION: mode_name = "Meister-Kette"

	var op_name: String = ""
	match selected_operation:
		MathConfig.Operation.ADDITION: op_name = "Addition (+)"
		MathConfig.Operation.SUBTRACTION: op_name = "Subtraktion (-)"
		MathConfig.Operation.MULTIPLICATION: op_name = "Multiplikation (x)"
		MathConfig.Operation.DIVISION: op_name = "Division (/)"
		MathConfig.Operation.MIXED: op_name = "Gemischt (Mix)"

	var diff_name: String = ""
	match selected_difficulty:
		MathConfig.Difficulty.EASY: diff_name = "Leicht [★]"
		MathConfig.Difficulty.MEDIUM: diff_name = "Mittel [★★]"
		MathConfig.Difficulty.HARD: diff_name = "Schwer [★★★]"

	info_label.text = "%s | %s | %s (Operanden: %d–%d, Max-Ergebnis: %d)" % [
		mode_name, op_name, diff_name, config.min_operand, config.max_operand, config.max_result
	]

func _start_button_pulse() -> void:
	if _start_pulse_tween:
		_start_pulse_tween.kill()

	_start_pulse_tween = create_tween().set_loops()
	_start_pulse_tween.tween_property(start_btn, "scale", Vector2(1.03, 1.03), 0.7) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_start_pulse_tween.tween_property(start_btn, "scale", Vector2(1.0, 1.0), 0.7) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_start_pressed() -> void:
	var config: MathConfig = MathConfig.create_config(selected_mode, selected_operation, selected_difficulty)
	if has_node("/root/MathEngine"):
		get_node("/root/MathEngine").set_difficulty(config)

	if _start_pulse_tween:
		_start_pulse_tween.kill()

	var tween: Tween = create_tween()
	tween.tween_property(start_btn, "scale", Vector2(0.92, 0.92), 0.08)
	tween.tween_property(self, "modulate:a", 0.0, 0.22)
	tween.tween_callback(func():
		get_tree().change_scene_to_file("res://scenes/main/Main.tscn")
	)
