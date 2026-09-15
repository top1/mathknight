class_name SiegeGateMaze
extends Control
## Siege Gate Maze — "Castle Attack" pre-battle puzzle mode.
## The player navigates their army through a branching gate/sluice labyrinth from left to right.
## At each junction, levers toggle between path choices applying math operations.
## Goal: maximize army size to exceed the castle's defense value.

# === Signals ===
signal puzzle_completed(final_count: int, castle_defense: int, is_victory: bool, stars: int)

# === Level Data ===
var level_data: SiegeGateLevel
var current_soldier_count: int = 0

# Track lever selections per stage and branch: chosen_choices[stage_idx][branch_idx] = choice_idx
var chosen_choices: Array[Array] = []

# === Layout Constants ===
const MARGIN_LEFT: float = 45.0
const MARGIN_RIGHT: float = 80.0
const MAZE_Y_TOP: float = 40.0
const MAZE_Y_BOTTOM: float = 310.0
const VIEWPORT_W: float = 640.0
const VIEWPORT_H: float = 360.0
const ARM_DX: float = 38.0

# === State ===
enum Phase { SETUP, PLANNING, MARCHING, RESULT }
var current_phase: Phase = Phase.SETUP

# === Nodes & References ===
var army_cluster: SoldierCluster
var stage_levers: Array[Array] = []  # [stage_idx][branch_idx] = GateLever
var stage_gates: Array[Array] = []   # [stage_idx][branch_idx][choice_idx] = OperationGate
var stage_lines: Array[Array] = []   # kept for backward-compatibility with tests
var exit_lines: Array[Line2D] = []
var castle_sprite: Node2D
var march_button: Button
var result_overlay: Control
var result_panel: PanelContainer
var celebration_container: Control
var result_title_label: Label
var result_count_label: Label
var result_optimal_label: Label
var result_stars_container: HBoxContainer
var result_reward_label: Label
var result_continue_btn: Button
var result_village_btn: Button
var current_level_index: int = 0
var total_levels_count: int = 4
var back_button: Button
var hint_label: Label
var background: ColorRect
var maze_board: Node2D
var game_layer: Node2D
var hud_layer: Control
var result_layer: CanvasLayer

# Debug Panel references
var debug_toggle_btn: Button
var debug_panel: PanelContainer
var debug_count_label: Label
var debug_defense_label: Label

# Layout data per stage
var stage_x_positions: Array[float] = []
# Channel info per stage: stage_channels[s] = Array of Dictionaries { "y_top": f, "y_bot": f, "y_center": f, "exit_y": f }
var stage_channels: Array[Array] = []
# Incoming bounds for each branch: branch_incoming_bounds[s][b] = { "y_min": f, "y_max": f }
var branch_incoming_bounds: Array[Array] = []
var _last_click_time_msec: int = 0
var _last_click_pos: Vector2 = Vector2(-9999, -9999)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not background:
		_build_ui_skeleton()

	# Auto-load sketch level if run standalone (F6 in editor)
	if get_tree().current_scene == self:
		load_level_by_index(0)


func _exit_tree() -> void:
	DisplayServer.cursor_set_shape(DisplayServer.CURSOR_ARROW)


func _process(_delta: float) -> void:
	_update_army_corridor_bounds_during_march()
	if is_instance_valid(maze_board):
		maze_board.queue_redraw()
	queue_redraw()


func _update_army_corridor_bounds_during_march() -> void:
	if not is_instance_valid(army_cluster) or current_phase != Phase.MARCHING:
		return
	var army_x: float = army_cluster.global_position.x
	var castle_x: float = VIEWPORT_W - MARGIN_RIGHT + 15.0

	# If in start chamber
	if stage_x_positions.is_empty() or army_x < stage_x_positions[0] - 10.0:
		army_cluster.set_corridor_bounds(MAZE_Y_TOP, MAZE_Y_BOTTOM)
		return

	# Find active stage and channel for current army X position
	for s_i in range(stage_x_positions.size()):
		var cur_x: float = stage_x_positions[s_i]
		var next_x: float = stage_x_positions[s_i + 1] if (s_i + 1 < stage_x_positions.size()) else castle_x
		if army_x >= cur_x - 10.0 and army_x <= next_x + 5.0:
			var branch_idx: int = _get_active_branch_for_stage(s_i)
			if s_i < chosen_choices.size() and branch_idx < chosen_choices[s_i].size():
				var c_idx: int = chosen_choices[s_i][branch_idx]
				if level_data and s_i < level_data.stages.size():
					var stage_dict: Dictionary = level_data.stages[s_i] as Dictionary
					var branches: Array = stage_dict.get("branches", [])
					if branch_idx < branches.size():
						var choices: Array = (branches[branch_idx] as Dictionary).get("choices", [])
						if c_idx < choices.size():
							var ey: float = float((choices[c_idx] as Dictionary).get("exit_y", 0.5))
							var ch: Dictionary = _get_channel_for_exit_y(s_i, ey)
							# In final approach to castle (courtyard), interpolate bounds along the diagonal funnel
							var plaza_x: float = castle_x - 95.0
							if s_i + 1 >= stage_x_positions.size() and army_x >= plaza_x:
								var t_plaza: float = clampf((army_x - plaza_x) / (castle_x - plaza_x), 0.0, 1.0)
								var gate_mid_y: float = (MAZE_Y_TOP + MAZE_Y_BOTTOM) / 2.0
								var funnel_top: float = lerpf(ch["y_top"], gate_mid_y - 20.0, t_plaza)
								var funnel_bot: float = lerpf(ch["y_bot"], gate_mid_y + 20.0, t_plaza)
								army_cluster.set_corridor_bounds(funnel_top, funnel_bot)
							else:
								army_cluster.set_corridor_bounds(ch["y_top"], ch["y_bot"])
							return


## Load and display a level from a SiegeGateLevel resource.
func load_level(data: SiegeGateLevel) -> void:
	if not background:
		_build_ui_skeleton()

	level_data = data
	var player_soldiers: int = 0
	if has_node("/root/SaveManager"):
		player_soldiers = get_node("/root/SaveManager").soldiers
	current_soldier_count = maxi(player_soldiers, 5)

	# Initialize choice tracking
	chosen_choices.clear()
	for s_i in range(data.stages.size()):
		var stage_dict: Dictionary = data.stages[s_i] as Dictionary
		var branches: Array = stage_dict.get("branches", [])
		var branch_choices: Array = []
		for b_i in range(branches.size()):
			branch_choices.append(0)
		chosen_choices.append(branch_choices)

	_clear_maze()
	_calculate_layout()
	_build_maze_graph()
	_build_army()
	_build_castle()
	_update_path_highlights()
	_update_march_barriers()

	current_phase = Phase.PLANNING

	if march_button:
		march_button.visible = true
		march_button.disabled = false

	if back_button:
		back_button.disabled = false

	if hint_label and not data.hint_text.is_empty():
		hint_label.text = data.hint_text
		hint_label.visible = true

	# Emit EventBus signal
	if is_inside_tree() and has_node("/root/EventBus"):
		get_node("/root/EventBus").siege_gate_started.emit({
			"level_name": data.level_name,
			"starting_soldiers": data.starting_soldiers,
			"castle_defense": data.castle_defense_value
		})

	# Play BGM
	if is_inside_tree() and has_node("/root/AudioManager"):
		var am: Node = get_node("/root/AudioManager")
		if am.has_method("play_music"):
			am.play_music("puzzle")


## Load a level by index from the siege_levels.json file.
func load_level_by_index(index: int) -> void:
	var json_path := "res://assets/siege_levels.json"
	if not FileAccess.file_exists(json_path):
		push_error("SiegeGateMaze: siege_levels.json not found!")
		return

	var file := FileAccess.open(json_path, FileAccess.READ)
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()

	if err != OK:
		push_error("SiegeGateMaze: Failed to parse siege_levels.json")
		return

	var data: Dictionary = json.data
	var levels: Array = data.get("levels", [])
	total_levels_count = levels.size()
	if index < 0 or index >= levels.size():
		push_error("SiegeGateMaze: Level index %d out of range" % index)
		return

	current_level_index = index
	var level := SiegeGateLevel.from_dict(levels[index])
	load_level(level)


# =========================================================================
# UI SKELETON
# =========================================================================

func _build_ui_skeleton() -> void:
	background = ColorRect.new()
	background.name = "Background"
	background.color = Color(0.06, 0.06, 0.09, 1.0)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	maze_board = Node2D.new()
	maze_board.name = "MazeBoard"
	maze_board.z_index = 0
	add_child(maze_board)
	maze_board.draw.connect(_draw_maze_board)

	game_layer = Node2D.new()
	game_layer.name = "GameLayer"
	game_layer.z_index = 5
	add_child(game_layer)

	hud_layer = Control.new()
	hud_layer.name = "HUDLayer"
	hud_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.z_index = 20
	add_child(hud_layer)

	back_button = Button.new()
	back_button.text = "← Zurück"
	back_button.position = Vector2(8, 6)
	back_button.custom_minimum_size = Vector2(80, 24)
	back_button.pressed.connect(_on_back_pressed)
	hud_layer.add_child(back_button)

	hint_label = Label.new()
	hint_label.position = Vector2(100, 6)
	hint_label.size = Vector2(440, 24)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 12)
	hint_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.9))
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_label.visible = false
	hud_layer.add_child(hint_label)

	march_button = Button.new()
	march_button.text = "⚔️ MARSCH!"
	march_button.position = Vector2(250, 324)
	march_button.custom_minimum_size = Vector2(140, 30)
	march_button.add_theme_font_size_override("font_size", 14)
	march_button.pressed.connect(_on_march_pressed)
	march_button.visible = false
	hud_layer.add_child(march_button)

	_build_debug_ui()
	_build_result_overlay()


func _build_result_overlay() -> void:
	result_layer = CanvasLayer.new()
	result_layer.name = "ResultLayer"
	result_layer.layer = 100
	add_child(result_layer)

	result_overlay = Control.new()
	result_overlay.name = "ResultOverlay"
	result_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_overlay.visible = false
	result_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	result_layer.add_child(result_overlay)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.02, 0.05, 0.88)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	result_overlay.add_child(backdrop)

	celebration_container = Control.new()
	celebration_container.name = "CelebrationContainer"
	celebration_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	celebration_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_overlay.add_child(celebration_container)

	result_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.18, 0.98)
	style.border_color = Color(0.8, 0.6, 0.2)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	result_panel.add_theme_stylebox_override("panel", style)
	result_panel.position = Vector2(145, 45)
	result_panel.custom_minimum_size = Vector2(350, 270)
	result_panel.pivot_offset = Vector2(175, 135)
	result_overlay.add_child(result_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	result_panel.add_child(vbox)

	result_title_label = Label.new()
	result_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_title_label.add_theme_font_size_override("font_size", 20)
	result_title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	result_title_label.add_theme_color_override("font_outline_color", Color.BLACK)
	result_title_label.add_theme_constant_override("outline_size", 4)
	vbox.add_child(result_title_label)

	result_count_label = Label.new()
	result_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_count_label.add_theme_font_size_override("font_size", 14)
	result_count_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(result_count_label)

	result_optimal_label = Label.new()
	result_optimal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_optimal_label.add_theme_font_size_override("font_size", 12)
	result_optimal_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9))
	vbox.add_child(result_optimal_label)

	result_stars_container = HBoxContainer.new()
	result_stars_container.alignment = BoxContainer.ALIGNMENT_CENTER
	result_stars_container.add_theme_constant_override("separation", 6)
	vbox.add_child(result_stars_container)

	result_reward_label = Label.new()
	result_reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_reward_label.add_theme_font_size_override("font_size", 12)
	result_reward_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2))
	vbox.add_child(result_reward_label)

	var btn_hbox := HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_hbox)

	result_continue_btn = Button.new()
	result_continue_btn.text = "Weiter"
	result_continue_btn.custom_minimum_size = Vector2(130, 32)
	result_continue_btn.pressed.connect(_on_result_continue)
	btn_hbox.add_child(result_continue_btn)

	result_village_btn = Button.new()
	result_village_btn.text = "Zum Dorf 🏰"
	result_village_btn.custom_minimum_size = Vector2(110, 32)
	result_village_btn.pressed.connect(_on_result_village)
	btn_hbox.add_child(result_village_btn)


func _build_debug_ui() -> void:
	debug_toggle_btn = Button.new()
	debug_toggle_btn.name = "DebugToggleBtn"
	debug_toggle_btn.text = "🛠️ Debug"
	debug_toggle_btn.position = Vector2(548, 6)
	debug_toggle_btn.custom_minimum_size = Vector2(84, 24)
	debug_toggle_btn.add_theme_font_size_override("font_size", 11)
	debug_toggle_btn.pressed.connect(debug_toggle_panel)
	hud_layer.add_child(debug_toggle_btn)

	debug_panel = PanelContainer.new()
	debug_panel.name = "DebugPanel"
	debug_panel.position = Vector2(405, 34)
	debug_panel.custom_minimum_size = Vector2(228, 275)
	debug_panel.visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.16, 0.96)
	style.border_color = Color(0.35, 0.65, 1.0, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	debug_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	debug_panel.add_child(vbox)

	var title := Label.new()
	title.text = "🛠️ ARMEE & PHYSIK DEBUG"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	vbox.add_child(title)

	# Current Soldier Count Label
	debug_count_label = Label.new()
	debug_count_label.text = "Soldaten: %d" % current_soldier_count
	debug_count_label.add_theme_font_size_override("font_size", 11)
	debug_count_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	vbox.add_child(debug_count_label)

	# Presets Row
	var p_hbox := HBoxContainer.new()
	p_hbox.add_theme_constant_override("separation", 3)
	for val in [12, 50, 100, 250, 500]:
		var btn := Button.new()
		btn.text = str(val)
		btn.custom_minimum_size = Vector2(38, 20)
		btn.add_theme_font_size_override("font_size", 10)
		btn.pressed.connect(debug_set_soldier_count.bind(val))
		p_hbox.add_child(btn)
	vbox.add_child(p_hbox)

	# Deltas Row
	var d_hbox := HBoxContainer.new()
	d_hbox.add_theme_constant_override("separation", 3)
	var deltas := [
		["-10", -10],
		["+10", 10],
		["+50", 50],
		["+100", 100],
		["×2", "mul2"],
		["÷2", "div2"]
	]
	for d_info in deltas:
		var btn := Button.new()
		btn.text = str(d_info[0])
		btn.custom_minimum_size = Vector2(30, 20)
		btn.add_theme_font_size_override("font_size", 10)
		if d_info[1] is String:
			if d_info[1] == "mul2":
				btn.pressed.connect(debug_multiply_soldier_count.bind(2.0))
			else:
				btn.pressed.connect(debug_multiply_soldier_count.bind(0.5))
		else:
			btn.pressed.connect(debug_add_soldier_count.bind(d_info[1]))
		d_hbox.add_child(btn)
	vbox.add_child(d_hbox)

	# Castle Defense Section
	debug_defense_label = Label.new()
	debug_defense_label.text = "Burg-Def: %d" % (level_data.castle_defense_value if level_data else 40)
	debug_defense_label.add_theme_font_size_override("font_size", 11)
	debug_defense_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	vbox.add_child(debug_defense_label)

	var def_hbox := HBoxContainer.new()
	def_hbox.add_theme_constant_override("separation", 3)
	for def_val in [40, 150, 300, 600]:
		var btn := Button.new()
		btn.text = str(def_val)
		btn.custom_minimum_size = Vector2(48, 20)
		btn.add_theme_font_size_override("font_size", 10)
		btn.pressed.connect(debug_set_castle_defense.bind(def_val))
		def_hbox.add_child(btn)
	vbox.add_child(def_hbox)

	# Actions Row
	var act_hbox := HBoxContainer.new()
	act_hbox.add_theme_constant_override("separation", 4)
	var march_btn := Button.new()
	march_btn.text = "⚔️ Test-Marsch"
	march_btn.custom_minimum_size = Vector2(105, 24)
	march_btn.add_theme_font_size_override("font_size", 10)
	march_btn.pressed.connect(_on_march_pressed)
	act_hbox.add_child(march_btn)

	var reset_btn := Button.new()
	reset_btn.text = "🔄 Reset"
	reset_btn.custom_minimum_size = Vector2(95, 24)
	reset_btn.add_theme_font_size_override("font_size", 10)
	reset_btn.pressed.connect(debug_reset_army)
	act_hbox.add_child(reset_btn)
	vbox.add_child(act_hbox)

	# Keybindings help
	var keys_label := Label.new()
	keys_label.text = "Tasten:\n1-5 = 12..500 Soldaten\n+/- = ±10 | * / = ×2 / ÷2\nR = Reset | F1 / D = Menü"
	keys_label.add_theme_font_size_override("font_size", 9)
	keys_label.add_theme_color_override("font_color", Color(0.65, 0.70, 0.82))
	vbox.add_child(keys_label)

	hud_layer.add_child(debug_panel)


func debug_toggle_panel() -> void:
	if debug_panel:
		debug_panel.visible = not debug_panel.visible
		_update_debug_ui()


func debug_set_soldier_count(count: int) -> void:
	current_soldier_count = maxi(count, 1)
	if is_instance_valid(army_cluster):
		army_cluster.set_count_instant(current_soldier_count)
	_update_debug_ui()


func debug_add_soldier_count(delta: int) -> void:
	debug_set_soldier_count(current_soldier_count + delta)


func debug_multiply_soldier_count(factor: float) -> void:
	debug_set_soldier_count(int(roundf(float(current_soldier_count) * factor)))


func debug_set_castle_defense(def: int) -> void:
	if level_data:
		level_data.castle_defense_value = def
	if is_instance_valid(castle_sprite):
		for child in castle_sprite.get_children():
			if child is CastleDraw:
				child.defense_value = def
				child.queue_redraw()
	_update_debug_ui()


func debug_reset_army() -> void:
	if is_instance_valid(army_cluster):
		var start_y: float = (MAZE_Y_TOP + MAZE_Y_BOTTOM) / 2.0
		army_cluster.global_position = Vector2(MARGIN_LEFT + 45.0, start_y)
		army_cluster.set_min_x(MARGIN_LEFT)
		army_cluster.clear_max_x()
		army_cluster.set_corridor_bounds(MAZE_Y_TOP, MAZE_Y_BOTTOM)
		army_cluster.set_count_instant(current_soldier_count)
	if is_instance_valid(castle_sprite):
		for child in castle_sprite.get_children():
			if child is CastleDraw:
				child.is_breached = false
				child.gate_open_ratio = 0.0
				child.queue_redraw()
	current_phase = Phase.PLANNING
	if march_button:
		march_button.visible = true
		march_button.disabled = false
	if result_overlay:
		result_overlay.visible = false
	if is_instance_valid(celebration_container):
		for c in celebration_container.get_children():
			c.queue_free()
	_update_path_highlights()
	_update_march_barriers()
	_update_debug_ui()


func _update_debug_ui() -> void:
	if is_instance_valid(debug_count_label):
		debug_count_label.text = "Soldaten: %d" % current_soldier_count
	if is_instance_valid(debug_defense_label) and level_data:
		debug_defense_label.text = "Burg-Def: %d" % level_data.castle_defense_value


# =========================================================================
# LAYOUT & GRAPH BUILDING
# =========================================================================

func _calculate_layout() -> void:
	if not level_data:
		return

	stage_x_positions.clear()
	stage_channels.clear()
	branch_incoming_bounds.clear()

	var num_stages: int = level_data.stages.size()
	var castle_x: float = VIEWPORT_W - MARGIN_RIGHT + 15.0
	var usable_width: float = castle_x - MARGIN_LEFT
	var stage_spacing: float = usable_width / float(num_stages + 1)
	var total_height: float = MAZE_Y_BOTTOM - MAZE_Y_TOP

	# 1. Stage column X positions
	for s_i in range(num_stages):
		var x: float = MARGIN_LEFT + stage_spacing * (float(s_i) + 0.85)
		stage_x_positions.append(x)

	# 2. Compute channel bounds per stage
	for s_i in range(num_stages):
		var stage_dict: Dictionary = level_data.stages[s_i] as Dictionary
		var branches: Array = stage_dict.get("branches", [])

		# Collect all unique exit_y in this stage
		var exit_ys: Array[float] = []
		for b in branches:
			var choices: Array = b.get("choices", [])
			for c in choices:
				var ey: float = float(c.get("exit_y", 0.5))
				var already := false
				for existing in exit_ys:
					if absf(existing - ey) < 0.02:
						already = true
						break
				if not already:
					exit_ys.append(ey)
		exit_ys.sort()

		var num_ch := maxi(exit_ys.size(), 1)
		var ch_list: Array = []
		for k in range(num_ch):
			var ch_top: float = MAZE_Y_TOP + (float(k) / float(num_ch)) * total_height
			var ch_bot: float = MAZE_Y_TOP + (float(k + 1) / float(num_ch)) * total_height
			ch_list.append({
				"y_top": ch_top,
				"y_bot": ch_bot,
				"y_center": (ch_top + ch_bot) / 2.0,
				"exit_y": exit_ys[k] if k < exit_ys.size() else 0.5
			})
		stage_channels.append(ch_list)

	# 3. Compute incoming bounds for branches
	for s_i in range(num_stages):
		var stage_dict: Dictionary = level_data.stages[s_i] as Dictionary
		var branches: Array = stage_dict.get("branches", [])
		var s_bounds: Array = []

		for b_i in range(branches.size()):
			var branch: Dictionary = branches[b_i] as Dictionary
			var entry_y_norm: float = float(branch.get("entry_y", 0.5))

			if s_i == 0:
				# Stage 0 receives from start area
				s_bounds.append({
					"y_min": MAZE_Y_TOP,
					"y_max": MAZE_Y_BOTTOM
				})
			else:
				# Find matching channel in previous stage
				var prev_channels: Array = stage_channels[s_i - 1]
				var best_k := 0
				var min_dist := 999.0
				for k in range(prev_channels.size()):
					var ch_info: Dictionary = prev_channels[k]
					var dist: float = absf(ch_info["exit_y"] - entry_y_norm)
					if dist < min_dist:
						min_dist = dist
						best_k = k
				var matched_ch: Dictionary = prev_channels[best_k]
				s_bounds.append({
					"y_min": matched_ch["y_top"],
					"y_max": matched_ch["y_bot"]
				})

		branch_incoming_bounds.append(s_bounds)


func _norm_to_y(norm: float) -> float:
	return MAZE_Y_TOP + (MAZE_Y_BOTTOM - MAZE_Y_TOP) * norm


func _get_choice_dividing_y(stage_idx: int, branch_idx: int) -> float:
	if not level_data or stage_idx >= level_data.stages.size():
		return (MAZE_Y_TOP + MAZE_Y_BOTTOM) / 2.0
	var stage_dict: Dictionary = level_data.stages[stage_idx] as Dictionary
	var branches: Array = stage_dict.get("branches", [])
	if branch_idx >= branches.size():
		return (MAZE_Y_TOP + MAZE_Y_BOTTOM) / 2.0
	var branch: Dictionary = branches[branch_idx] as Dictionary
	var choices: Array = branch.get("choices", [])
	if choices.size() >= 2:
		var c0: Dictionary = choices[0] as Dictionary
		var c1: Dictionary = choices[1] as Dictionary
		var ch0 := _get_channel_for_exit_y(stage_idx, float(c0.get("exit_y", 0.5)))
		var ch1 := _get_channel_for_exit_y(stage_idx, float(c1.get("exit_y", 0.5)))
		if ch0["y_bot"] <= ch1["y_top"]:
			return (ch0["y_bot"] + ch1["y_top"]) / 2.0
		elif ch1["y_bot"] <= ch0["y_top"]:
			return (ch1["y_bot"] + ch0["y_top"]) / 2.0
	if stage_idx < branch_incoming_bounds.size() and branch_idx < branch_incoming_bounds[stage_idx].size():
		var in_bounds: Dictionary = branch_incoming_bounds[stage_idx][branch_idx]
		return (in_bounds["y_min"] + in_bounds["y_max"]) / 2.0
	return (MAZE_Y_TOP + MAZE_Y_BOTTOM) / 2.0


func _get_active_branch_for_stage(stage_idx: int) -> int:
	if not level_data or stage_idx <= 0:
		return 0
	var cur_b: int = 0
	for s in range(stage_idx):
		if s >= chosen_choices.size() or cur_b >= chosen_choices[s].size():
			return 0
		var c_idx: int = chosen_choices[s][cur_b]
		var stage_dict: Dictionary = level_data.stages[s] as Dictionary
		var branches: Array = stage_dict.get("branches", [])
		if cur_b >= branches.size():
			return 0
		var branch: Dictionary = branches[cur_b] as Dictionary
		var choices: Array = branch.get("choices", [])
		if c_idx >= choices.size():
			return 0
		var ey: float = float(choices[c_idx].get("exit_y", 0.5))
		cur_b = level_data._find_matching_next_branch(s + 1, ey)
	return cur_b


func _clear_maze() -> void:
	for s in stage_levers:
		for lever in s:
			if is_instance_valid(lever):
				lever.queue_free()
	stage_levers.clear()

	for s in stage_gates:
		for b in s:
			for g in b:
				if is_instance_valid(g):
					g.queue_free()
	stage_gates.clear()

	for s in stage_lines:
		for b in s:
			for line in b:
				if is_instance_valid(line):
					line.queue_free()
	stage_lines.clear()

	for line in exit_lines:
		if is_instance_valid(line):
			line.queue_free()
	exit_lines.clear()

	if is_instance_valid(army_cluster):
		army_cluster.queue_free()
		army_cluster = null

	if is_instance_valid(castle_sprite):
		castle_sprite.queue_free()
		castle_sprite = null


func _build_maze_graph() -> void:
	if not level_data:
		return

	var num_stages: int = level_data.stages.size()
	var castle_x: float = VIEWPORT_W - MARGIN_RIGHT + 15.0

	for s_i in range(num_stages):
		var stage_dict: Dictionary = level_data.stages[s_i] as Dictionary
		var branches: Array = stage_dict.get("branches", [])

		var s_levers: Array = []
		var s_gates: Array = []
		var s_lines: Array = []

		var current_x: float = stage_x_positions[s_i]
		var next_x: float = stage_x_positions[s_i + 1] if (s_i + 1 < num_stages) else castle_x
		var mid_x: float = (current_x + next_x) / 2.0

		for b_i in range(branches.size()):
			var branch: Dictionary = branches[b_i] as Dictionary
			var choices: Array = branch.get("choices", [])
			var in_bounds: Dictionary = branch_incoming_bounds[s_i][b_i]
			var pivot_y: float = _get_choice_dividing_y(s_i, b_i)

			# 1. Create GateLever
			var lever := GateLever.new()
			if game_layer:
				game_layer.add_child(lever)
			else:
				add_child(lever)

			# Gate barrier arm target offsets:
			# Choice 0 (Upper): arm reaches down to close incoming lower wall
			# Choice 1 (Lower): arm reaches up to close incoming upper wall
			var arm_offsets: Array[Vector2] = []
			if choices.size() >= 2:
				arm_offsets.append(Vector2(-ARM_DX, in_bounds["y_max"] - pivot_y))
				arm_offsets.append(Vector2(-ARM_DX, in_bounds["y_min"] - pivot_y))
			else:
				arm_offsets.append(Vector2(-ARM_DX, 0.0))

			# Colors per branch for visual variety (e.g. orange vs purple as in sketch)
			if b_i == 0:
				lever.gate_color = Color(0.92, 0.55, 0.18) # Amber / Orange
			else:
				lever.gate_color = Color(0.78, 0.38, 0.95) # Violet / Purple

			lever.setup(s_i * 100 + b_i, choices.size(), [])
			lever.setup_arm_offsets(arm_offsets, chosen_choices[s_i][b_i])
			lever.position = Vector2(current_x, pivot_y)
			lever.lever_switched.connect(_on_branch_lever_switched.bind(s_i, b_i))
			s_levers.append(lever)

			# 2. Create OperationGates placed inside the corridor lanes
			var b_gates: Array = []
			var b_lines: Array = []

			for c_i in range(choices.size()):
				var choice: Dictionary = choices[c_i] as Dictionary
				var exit_y_norm: float = float(choice.get("exit_y", 0.5))
				var ops: Array = choice.get("operations", [])

				var typed_ops: Array[Dictionary] = []
				for op in ops:
					typed_ops.append(op as Dictionary)

				# Find channel Y center for this choice
				var ch_y_center := _get_channel_center_for_exit_y(s_i, exit_y_norm)

				var dummy_line := Line2D.new()
				dummy_line.visible = false
				if game_layer:
					game_layer.add_child(dummy_line)
				else:
					add_child(dummy_line)
				b_lines.append(dummy_line)

				var gate := OperationGate.new()
				if game_layer:
					game_layer.add_child(gate)
				else:
					add_child(gate)
				gate.stage_idx = s_i
				gate.branch_idx = b_i
				gate.choice_idx = c_i
				gate.setup(typed_ops, s_i * 100 + b_i * 10 + c_i)
				gate.position = Vector2(mid_x, ch_y_center)
				b_gates.append(gate)

			s_gates.append(b_gates)
			s_lines.append(b_lines)

		stage_levers.append(s_levers)
		stage_gates.append(s_gates)
		stage_lines.append(s_lines)


func _get_channel_center_for_exit_y(stage_idx: int, exit_y: float) -> float:
	if stage_idx >= stage_channels.size():
		return _norm_to_y(exit_y)
	var channels: Array = stage_channels[stage_idx]
	var best_k := 0
	var min_dist := 999.0
	for k in range(channels.size()):
		var d: float = absf(channels[k]["exit_y"] - exit_y)
		if d < min_dist:
			min_dist = d
			best_k = k
	return channels[best_k]["y_center"]


func _build_army() -> void:
	army_cluster = SoldierCluster.new()
	if game_layer:
		game_layer.add_child(army_cluster)
	else:
		add_child(army_cluster)
	var start_y: float = (MAZE_Y_TOP + MAZE_Y_BOTTOM) / 2.0
	army_cluster.position = Vector2(MARGIN_LEFT + 45.0, start_y)
	army_cluster.set_min_x(MARGIN_LEFT)
	army_cluster.set_corridor_bounds(MAZE_Y_TOP, MAZE_Y_BOTTOM)
	army_cluster.set_count_instant(current_soldier_count)


func _build_castle() -> void:
	castle_sprite = Node2D.new()
	var castle_x: float = VIEWPORT_W - MARGIN_RIGHT + 20.0
	var castle_y: float = (MAZE_Y_TOP + MAZE_Y_BOTTOM) / 2.0
	castle_sprite.position = Vector2(castle_x, castle_y)
	if game_layer:
		game_layer.add_child(castle_sprite)
	else:
		add_child(castle_sprite)

	var castle_draw := CastleDraw.new()
	castle_draw.defense_value = level_data.castle_defense_value
	castle_sprite.add_child(castle_draw)


# =========================================================================
# DRAWING: LANES, 3D BARRIER DIVIDING WALLS, ACTIVE ROUTE & BORDERS
# =========================================================================

func _draw_maze_board() -> void:
	if not level_data or stage_x_positions.is_empty() or not is_instance_valid(maze_board):
		return

	var castle_x: float = VIEWPORT_W - MARGIN_RIGHT + 15.0
	var total_h: float = MAZE_Y_BOTTOM - MAZE_Y_TOP
	var maze_rect := Rect2(MARGIN_LEFT, MAZE_Y_TOP, castle_x - MARGIN_LEFT, total_h)
	var num_stages: int = level_data.stages.size()

	# 1. Base Dark Floor for the whole labyrinth
	maze_board.draw_rect(maze_rect, Color(0.08, 0.09, 0.12, 1.0))

	# 2. Draw Start Chamber Floor (from MARGIN_LEFT to Stage 0)
	var x_0: float = stage_x_positions[0]
	var start_rect := Rect2(MARGIN_LEFT, MAZE_Y_TOP, x_0 - MARGIN_LEFT, total_h)
	maze_board.draw_rect(start_rect, Color(0.11, 0.12, 0.17, 1.0))
	for y_tile in range(int(MAZE_Y_TOP) + 20, int(MAZE_Y_BOTTOM), 24):
		maze_board.draw_line(Vector2(MARGIN_LEFT, float(y_tile)), Vector2(x_0, float(y_tile)), Color(0.14, 0.15, 0.20, 0.6), 1.0)

	# 3. Draw All Channel Floors for each Stage
	for s_i in range(num_stages):
		var cur_x: float = stage_x_positions[s_i]
		var next_x: float = stage_x_positions[s_i + 1] if (s_i + 1 < num_stages) else castle_x
		var channels: Array = stage_channels[s_i]
		for k in range(channels.size()):
			var ch: Dictionary = channels[k]
			var ch_rect := Rect2(cur_x, ch["y_top"], next_x - cur_x, ch["y_bot"] - ch["y_top"])
			var ch_color := Color(0.12, 0.13, 0.18, 1.0) if (k % 2 == 0) else Color(0.09, 0.10, 0.14, 1.0)
			maze_board.draw_rect(ch_rect, ch_color)
			# Subtle dashed center-line for each lane
			var y_c: float = ch["y_center"]
			var dash_step := 16.0
			var x_pos := cur_x + 8.0
			while x_pos < next_x - 8.0:
				maze_board.draw_line(Vector2(x_pos, y_c), Vector2(minf(x_pos + 8.0, next_x - 8.0), y_c), Color(0.17, 0.18, 0.24, 0.5), 1.0)
				x_pos += dash_step

	# 4. Draw Active Route Corridor (highlighted polygon)
	_draw_active_corridor(castle_x)

	# 5. Draw Directional Chevrons along active path
	_draw_active_path_chevrons(castle_x)

	# 6. Draw Blocked Barrier Indicators at closed branch entries
	_draw_blocked_barrier_indicators()

	# 7. Draw 3D Stone Barrier Dividing Walls between channels
	for s_i in range(num_stages):
		var cur_x: float = stage_x_positions[s_i]
		var next_x: float = stage_x_positions[s_i + 1] if (s_i + 1 < num_stages) else castle_x
		var wall_end_x: float = (next_x - 95.0) if (s_i + 1 >= num_stages) else next_x
		var channels: Array = stage_channels[s_i]
		for k in range(1, channels.size()):
			var y_div: float = channels[k]["y_top"]
			# Deep drop shadow
			maze_board.draw_rect(Rect2(cur_x, y_div, wall_end_x - cur_x, 5.0), Color(0.04, 0.04, 0.06, 0.8))
			# Main stone wall body (8px thick)
			maze_board.draw_rect(Rect2(cur_x, y_div - 4.0, wall_end_x - cur_x, 7.0), Color(0.26, 0.28, 0.36, 1.0))
			# Top edge bright stone highlight
			maze_board.draw_line(Vector2(cur_x, y_div - 4.0), Vector2(wall_end_x, y_div - 4.0), Color(0.52, 0.55, 0.68, 1.0), 1.5)
			# Bottom edge dark shadow
			maze_board.draw_line(Vector2(cur_x, y_div + 3.0), Vector2(wall_end_x, y_div + 3.0), Color(0.12, 0.13, 0.18, 1.0), 1.0)
			# Vertical stone mortar hash marks
			var tick_x := cur_x + 22.0
			while tick_x < wall_end_x - 12.0:
				maze_board.draw_line(Vector2(tick_x, y_div - 4.0), Vector2(tick_x, y_div + 3.0), Color(0.16, 0.18, 0.24, 0.8), 1.0)
				tick_x += 24.0
			# End pillar posts
			maze_board.draw_circle(Vector2(cur_x, y_div), 5.5, Color(0.32, 0.35, 0.45, 1.0))
			maze_board.draw_circle(Vector2(cur_x, y_div), 2.5, Color(0.60, 0.64, 0.76, 1.0))
			maze_board.draw_circle(Vector2(wall_end_x, y_div), 5.5, Color(0.32, 0.35, 0.45, 1.0))
			maze_board.draw_circle(Vector2(wall_end_x, y_div), 2.5, Color(0.60, 0.64, 0.76, 1.0))

	# 8. Draw Fortress Outer Perimeter Wall and Battlements
	maze_board.draw_rect(Rect2(maze_rect.position - Vector2(2, 2), maze_rect.size + Vector2(4, 4)), Color(0.02, 0.02, 0.04, 0.9), false, 2.0)
	maze_board.draw_rect(maze_rect, Color(0.28, 0.30, 0.39, 1.0), false, 7.0)
	maze_board.draw_rect(maze_rect, Color(0.50, 0.54, 0.66, 1.0), false, 1.5)

	# Top and bottom wall battlements (crenellations)
	for b_x in range(int(MARGIN_LEFT) + 4, int(castle_x) - 10, 18):
		maze_board.draw_rect(Rect2(float(b_x), MAZE_Y_TOP - 7.0, 7.0, 5.0), Color(0.35, 0.38, 0.48, 1.0))
		maze_board.draw_rect(Rect2(float(b_x), MAZE_Y_BOTTOM + 2.0, 7.0, 5.0), Color(0.22, 0.24, 0.32, 1.0))

	# 4 Corner Fort Towers
	var corners := [
		Vector2(MARGIN_LEFT, MAZE_Y_TOP),
		Vector2(castle_x, MAZE_Y_TOP),
		Vector2(MARGIN_LEFT, MAZE_Y_BOTTOM),
		Vector2(castle_x, MAZE_Y_BOTTOM)
	]
	for c_pos in corners:
		maze_board.draw_circle(c_pos, 7.0, Color(0.34, 0.36, 0.46, 1.0))
		maze_board.draw_circle(c_pos, 3.5, Color(0.55, 0.58, 0.70, 1.0))


func get_active_corridor_polygon() -> PackedVector2Array:
	var num_stages: int = level_data.stages.size()
	if num_stages == 0 or chosen_choices.is_empty():
		return PackedVector2Array()

	var castle_x: float = VIEWPORT_W - MARGIN_RIGHT + 15.0
	var top_pts: PackedVector2Array = PackedVector2Array()
	var bot_pts: PackedVector2Array = PackedVector2Array()

	# --- Start Chamber (Column -1) ---
	var x_start: float = MARGIN_LEFT
	var x_0: float = stage_x_positions[0]
	var c_0: int = chosen_choices[0][0] if chosen_choices[0].size() > 0 else 0
	var pivot_y_0: float = _get_choice_dividing_y(0, 0)

	top_pts.append(Vector2(x_start, MAZE_Y_TOP))
	bot_pts.append(Vector2(x_start, MAZE_Y_BOTTOM))

	if c_0 == 0:
		# Upper path open: gate closes lower path
		top_pts.append(Vector2(x_0, MAZE_Y_TOP))
		bot_pts.append(Vector2(x_0 - ARM_DX, MAZE_Y_BOTTOM))
		bot_pts.append(Vector2(x_0, pivot_y_0))
	else:
		# Lower path open: gate closes upper path
		top_pts.append(Vector2(x_0 - ARM_DX, MAZE_Y_TOP))
		top_pts.append(Vector2(x_0, pivot_y_0))
		bot_pts.append(Vector2(x_0, MAZE_Y_BOTTOM))

	# --- Trace Through Stages ---
	var cur_branch := 0
	for s_i in range(num_stages):
		var stage_dict: Dictionary = level_data.stages[s_i] as Dictionary
		var branches: Array = stage_dict.get("branches", [])
		if cur_branch >= branches.size():
			break

		var branch: Dictionary = branches[cur_branch] as Dictionary
		var choices: Array = branch.get("choices", [])
		var c_idx: int = chosen_choices[s_i][cur_branch] if cur_branch < chosen_choices[s_i].size() else 0
		if c_idx >= choices.size():
			c_idx = 0

		var choice: Dictionary = choices[c_idx] as Dictionary
		var exit_y_norm: float = float(choice.get("exit_y", 0.5))

		# Find channel bounds for this choice
		var cur_ch := _get_channel_for_exit_y(s_i, exit_y_norm)
		var next_x: float = stage_x_positions[s_i + 1] if (s_i + 1 < num_stages) else castle_x

		if s_i + 1 < num_stages:
			var next_branch_idx := level_data._find_matching_next_branch(s_i + 1, exit_y_norm)
			var next_c_idx: int = chosen_choices[s_i + 1][next_branch_idx] if next_branch_idx < chosen_choices[s_i + 1].size() else 0
			var next_pivot_y: float = _get_choice_dividing_y(s_i + 1, next_branch_idx)

			if next_c_idx == 0:
				# Next stage chooses upper: gate closes lower path
				top_pts.append(Vector2(next_x, cur_ch["y_top"]))
				bot_pts.append(Vector2(next_x - ARM_DX, cur_ch["y_bot"]))
				bot_pts.append(Vector2(next_x, next_pivot_y))
			else:
				# Next stage chooses lower: gate closes upper path
				top_pts.append(Vector2(next_x - ARM_DX, cur_ch["y_top"]))
				top_pts.append(Vector2(next_x, next_pivot_y))
				bot_pts.append(Vector2(next_x, cur_ch["y_bot"]))

			cur_branch = next_branch_idx
		else:
			# Final stage connects straight to castle through open courtyard (opens earlier)
			var plaza_x: float = castle_x - 95.0
			var gate_mid_y: float = (MAZE_Y_TOP + MAZE_Y_BOTTOM) / 2.0
			top_pts.append(Vector2(plaza_x, cur_ch["y_top"]))
			top_pts.append(Vector2(castle_x, gate_mid_y - 20.0))
			bot_pts.append(Vector2(plaza_x, cur_ch["y_bot"]))
			bot_pts.append(Vector2(castle_x, gate_mid_y + 20.0))

	# Assemble complete closed polygon
	var poly_pts: PackedVector2Array = PackedVector2Array()
	for pt in top_pts:
		poly_pts.append(pt)
	for i in range(bot_pts.size() - 1, -1, -1):
		poly_pts.append(bot_pts[i])

	return poly_pts


func _draw_active_corridor(_castle_x: float) -> void:
	if not level_data or chosen_choices.is_empty() or not is_instance_valid(maze_board):
		return

	var poly_pts: PackedVector2Array = get_active_corridor_polygon()
	if poly_pts.size() >= 3:
		# Clean stone grey active corridor
		maze_board.draw_polygon(poly_pts, PackedColorArray([Color(0.70, 0.70, 0.76, 1.0)]))
		var outline_pts := poly_pts.duplicate()
		outline_pts.append(poly_pts[0])
		maze_board.draw_polyline(outline_pts, Color(0.85, 0.85, 0.92, 0.9), 2.0, true)


func _draw_active_path_chevrons(castle_x: float) -> void:
	if not level_data or chosen_choices.is_empty() or not is_instance_valid(maze_board):
		return
	var num_stages: int = level_data.stages.size()
	var cur_branch := 0

	# 1. Start chamber chevron
	var x_0: float = stage_x_positions[0]
	var mid_start_x := (MARGIN_LEFT + x_0) / 2.0 + 20.0
	var mid_start_y := (MAZE_Y_TOP + MAZE_Y_BOTTOM) / 2.0
	_draw_chevron(mid_start_x, mid_start_y)

	# 2. Stage chevrons
	for s_i in range(num_stages):
		var stage_dict: Dictionary = level_data.stages[s_i] as Dictionary
		var branches: Array = stage_dict.get("branches", [])
		if cur_branch >= branches.size():
			break
		var branch: Dictionary = branches[cur_branch] as Dictionary
		var choices: Array = branch.get("choices", [])
		var c_idx: int = chosen_choices[s_i][cur_branch] if cur_branch < chosen_choices[s_i].size() else 0
		if c_idx >= choices.size():
			c_idx = 0
		var choice: Dictionary = choices[c_idx] as Dictionary
		var exit_y_norm: float = float(choice.get("exit_y", 0.5))
		var ch_y_center := _get_channel_center_for_exit_y(s_i, exit_y_norm)
		var cur_x: float = stage_x_positions[s_i]
		var next_x: float = stage_x_positions[s_i + 1] if (s_i + 1 < num_stages) else castle_x

		var c1_x := cur_x + (next_x - cur_x) * 0.25
		var c2_x := cur_x + (next_x - cur_x) * 0.75
		_draw_chevron(c1_x, ch_y_center)
		_draw_chevron(c2_x, ch_y_center)

		if s_i + 1 < num_stages:
			cur_branch = level_data._find_matching_next_branch(s_i + 1, exit_y_norm)


func _draw_chevron(cx: float, cy: float) -> void:
	var sz := 5.0
	var col := Color(0.38, 0.40, 0.50, 0.8)
	var pts := PackedVector2Array([
		Vector2(cx - sz, cy - sz),
		Vector2(cx + sz * 0.5, cy),
		Vector2(cx - sz, cy + sz)
	])
	maze_board.draw_polyline(pts, col, 2.5, true)


func _draw_blocked_barrier_indicators() -> void:
	if not level_data or chosen_choices.is_empty() or not is_instance_valid(maze_board):
		return
	var num_stages: int = level_data.stages.size()
	for s_i in range(num_stages):
		var stage_dict: Dictionary = level_data.stages[s_i] as Dictionary
		var branches: Array = stage_dict.get("branches", [])
		var cur_x: float = stage_x_positions[s_i]

		for b_i in range(branches.size()):
			var branch: Dictionary = branches[b_i] as Dictionary
			var choices: Array = branch.get("choices", [])
			var chosen_c: int = chosen_choices[s_i][b_i] if b_i < chosen_choices[s_i].size() else 0

			for c_i in range(choices.size()):
				if c_i != chosen_c:
					var choice: Dictionary = choices[c_i] as Dictionary
					var exit_y_norm: float = float(choice.get("exit_y", 0.5))
					var ch_info := _get_channel_for_exit_y(s_i, exit_y_norm)
					var blk_top: float = ch_info["y_top"]
					var blk_bot: float = ch_info["y_bot"]
					var blk_rect := Rect2(cur_x, blk_top, 24.0, blk_bot - blk_top)

					maze_board.draw_rect(blk_rect, Color(0.55, 0.12, 0.12, 0.20))
					var mid_y := (blk_top + blk_bot) / 2.0
					var cross_x := cur_x + 10.0
					maze_board.draw_line(Vector2(cross_x - 5, mid_y - 5), Vector2(cross_x + 5, mid_y + 5), Color(0.85, 0.2, 0.2, 0.6), 2.0)
					maze_board.draw_line(Vector2(cross_x - 5, mid_y + 5), Vector2(cross_x + 5, mid_y - 5), Color(0.85, 0.2, 0.2, 0.6), 2.0)


func _get_channel_for_exit_y(stage_idx: int, exit_y: float) -> Dictionary:
	if stage_idx < stage_channels.size():
		var channels: Array = stage_channels[stage_idx]
		var best_k := 0
		var min_dist := 999.0
		for k in range(channels.size()):
			var d: float = absf(channels[k]["exit_y"] - exit_y)
			if d < min_dist:
				min_dist = d
				best_k = k
		return channels[best_k]
	return { "y_top": MAZE_Y_TOP, "y_bot": MAZE_Y_BOTTOM, "y_center": (MAZE_Y_TOP + MAZE_Y_BOTTOM) / 2.0 }


# =========================================================================
# INTERACTION & HIGHLIGHTS
# =========================================================================

func _on_branch_lever_switched(gate_id_from_lever: int, new_choice_idx: int, stage_idx: int, branch_idx: int) -> void:
	if current_phase != Phase.PLANNING:
		return

	if stage_idx < chosen_choices.size() and branch_idx < chosen_choices[stage_idx].size():
		chosen_choices[stage_idx][branch_idx] = new_choice_idx

	_update_path_highlights()
	if is_instance_valid(maze_board):
		maze_board.queue_redraw()
	queue_redraw()

	if is_inside_tree() and has_node("/root/EventBus"):
		get_node("/root/EventBus").siege_gate_lever_switched.emit(gate_id_from_lever, new_choice_idx)


func _get_event_coords(event: InputEvent) -> Vector2:
	if "position" in event:
		return event.position
	return get_global_mouse_position() if (is_inside_tree() and get_viewport()) else Vector2.ZERO


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var pos: Vector2 = _get_event_coords(event)
		if (is_instance_valid(back_button) and back_button.visible and back_button.get_global_rect().has_point(pos)) \
		   or (is_instance_valid(march_button) and march_button.visible and march_button.get_global_rect().has_point(pos)) \
		   or (is_instance_valid(debug_toggle_btn) and debug_toggle_btn.visible and debug_toggle_btn.get_global_rect().has_point(pos)) \
		   or (is_instance_valid(debug_panel) and debug_panel.visible and debug_panel.get_global_rect().has_point(pos)):
			return
	_handle_interaction_input(event)


func _unhandled_input(event: InputEvent) -> void:
	if get_viewport() and get_viewport().is_input_handled():
		return
	_handle_interaction_input(event)


func _handle_interaction_input(event: InputEvent) -> void:
	# Debug hotkeys (available in any phase)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1 or event.keycode == KEY_D:
			debug_toggle_panel()
			if get_viewport():
				get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_1:
			debug_set_soldier_count(12)
			return
		elif event.keycode == KEY_2:
			debug_set_soldier_count(50)
			return
		elif event.keycode == KEY_3:
			debug_set_soldier_count(100)
			return
		elif event.keycode == KEY_4:
			debug_set_soldier_count(250)
			return
		elif event.keycode == KEY_5:
			debug_set_soldier_count(500)
			return
		elif event.keycode == KEY_PLUS or event.keycode == KEY_EQUAL:
			debug_add_soldier_count(10)
			return
		elif event.keycode == KEY_MINUS:
			debug_add_soldier_count(-10)
			return
		elif event.keycode == KEY_ASTERISK:
			debug_multiply_soldier_count(2.0)
			return
		elif event.keycode == KEY_SLASH:
			debug_multiply_soldier_count(0.5)
			return
		elif event.keycode == KEY_R:
			debug_reset_army()
			return

	if current_phase != Phase.PLANNING:
		return

	var is_click: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	var click_pos: Vector2 = _get_event_coords(event)

	if is_click:
		var now_msec: int = Time.get_ticks_msec()
		# Debounce duplicate events dispatched for the exact same tap/click
		if now_msec - _last_click_time_msec < 50 and click_pos.distance_squared_to(_last_click_pos) < 16.0:
			if get_viewport():
				get_viewport().set_input_as_handled()
			return
		_last_click_time_msec = now_msec
		_last_click_pos = click_pos

		# Determine active branch for each stage to prioritize the active route
		var active_branches: Array[int] = []
		for s_i in range(level_data.stages.size()):
			active_branches.append(_get_active_branch_for_stage(s_i))

		# 1. Check all GateLevers (prioritize active branch levers first)
		for s_i in range(stage_levers.size()):
			var act_b: int = active_branches[s_i] if s_i < active_branches.size() else 0
			var branch_order: Array[int] = [act_b]
			for b_i in range(stage_levers[s_i].size()):
				if b_i != act_b:
					branch_order.append(b_i)

			for b_i in branch_order:
				if b_i < stage_levers[s_i].size():
					var lever: GateLever = stage_levers[s_i][b_i]
					if is_instance_valid(lever) and lever.hit_test(click_pos):
						_toggle_branch_lever(s_i, b_i)
						if get_viewport():
							get_viewport().set_input_as_handled()
						return

		# 2. Check all OperationGates (clicking a math badge switches or toggles choice!)
		for s_i in range(stage_gates.size()):
			var act_b: int = active_branches[s_i] if s_i < active_branches.size() else 0
			var branch_order: Array[int] = [act_b]
			for b_i in range(stage_gates[s_i].size()):
				if b_i != act_b:
					branch_order.append(b_i)

			for b_i in branch_order:
				if b_i < stage_gates[s_i].size():
					for c_i in range(stage_gates[s_i][b_i].size()):
						var gate: OperationGate = stage_gates[s_i][b_i][c_i]
						if is_instance_valid(gate) and gate.hit_test(click_pos):
							_select_or_toggle_choice(s_i, b_i, c_i)
							if get_viewport():
								get_viewport().set_input_as_handled()
							return

		# 3. Check if clicked inside a channel of a stage to select that path
		for s_i in range(stage_x_positions.size()):
			var cur_x: float = stage_x_positions[s_i]
			var start_ch_x: float = MARGIN_LEFT if s_i == 0 else (cur_x - 45.0)
			var next_x: float = stage_x_positions[s_i + 1] if (s_i + 1 < stage_x_positions.size()) else (VIEWPORT_W - MARGIN_RIGHT + 15.0)
			if click_pos.x >= start_ch_x and click_pos.x <= next_x:
				if s_i < stage_channels.size():
					var channels: Array = stage_channels[s_i]
					for k in range(channels.size()):
						var ch: Dictionary = channels[k]
						if click_pos.y >= ch["y_top"] and click_pos.y <= ch["y_bot"]:
							_select_choice_for_channel(s_i, ch["exit_y"])
							if get_viewport():
								get_viewport().set_input_as_handled()
							return

	elif event is InputEventMouseMotion:
		var mouse_pos: Vector2 = _get_event_coords(event)
		var hovered_any := false

		# Check levers
		for s_i in range(stage_levers.size()):
			for b_i in range(stage_levers[s_i].size()):
				var lever: GateLever = stage_levers[s_i][b_i]
				if is_instance_valid(lever):
					var is_h := lever.hit_test(mouse_pos)
					lever.set_hovered(is_h)
					if is_h:
						hovered_any = true

		# Check operation gates
		for s_i in range(stage_gates.size()):
			for b_i in range(stage_gates[s_i].size()):
				for c_i in range(stage_gates[s_i][b_i].size()):
					var gate: OperationGate = stage_gates[s_i][b_i][c_i]
					if is_instance_valid(gate):
						var is_h := gate.hit_test(mouse_pos)
						gate.set_hovered(is_h)
						if is_h:
							hovered_any = true

		if hovered_any:
			DisplayServer.cursor_set_shape(DisplayServer.CURSOR_POINTING_HAND)
		else:
			DisplayServer.cursor_set_shape(DisplayServer.CURSOR_ARROW)


func _toggle_branch_lever(stage_idx: int, branch_idx: int) -> void:
	if not level_data or stage_idx >= level_data.stages.size():
		return
	var stage_dict: Dictionary = level_data.stages[stage_idx] as Dictionary
	var branches: Array = stage_dict.get("branches", [])
	if branch_idx >= branches.size():
		return
	var branch: Dictionary = branches[branch_idx] as Dictionary
	var choices: Array = branch.get("choices", [])
	if choices.size() <= 1:
		return

	var cur_c: int = chosen_choices[stage_idx][branch_idx]
	var next_c: int = (cur_c + 1) % choices.size()
	_set_choice(stage_idx, branch_idx, next_c)


func _select_or_toggle_choice(stage_idx: int, branch_idx: int, choice_idx: int) -> void:
	if not level_data or stage_idx >= level_data.stages.size():
		return
	var stage_dict: Dictionary = level_data.stages[stage_idx] as Dictionary
	var branches: Array = stage_dict.get("branches", [])
	if branch_idx >= branches.size():
		return
	var branch: Dictionary = branches[branch_idx] as Dictionary
	var choices: Array = branch.get("choices", [])
	var num_choices: int = choices.size()
	if num_choices <= 0:
		return

	var current_c: int = chosen_choices[stage_idx][branch_idx]
	var target_c: int = choice_idx
	if current_c == choice_idx and num_choices > 1:
		target_c = (current_c + 1) % num_choices
	_set_choice(stage_idx, branch_idx, target_c)


## Set a specific choice for a branch. If already set to target_c, does not move.
func _set_choice(stage_idx: int, branch_idx: int, target_c: int) -> void:
	if not level_data or stage_idx >= level_data.stages.size():
		return

	var stage_dict: Dictionary = level_data.stages[stage_idx] as Dictionary
	var branches: Array = stage_dict.get("branches", [])
	if branch_idx >= branches.size():
		return
	var branch: Dictionary = branches[branch_idx] as Dictionary
	var choices: Array = branch.get("choices", [])
	if choices.is_empty():
		return

	var current_c: int = chosen_choices[stage_idx][branch_idx]
	if current_c == target_c:
		# Already open to this lane! Do not move, as requested by user.
		return

	# Ensure the active route from stage 0 leads to this branch
	_ensure_route_leads_to_branch(stage_idx, branch_idx)

	chosen_choices[stage_idx][branch_idx] = target_c

	if stage_idx < stage_levers.size() and branch_idx < stage_levers[stage_idx].size():
		var lever: GateLever = stage_levers[stage_idx][branch_idx]
		if is_instance_valid(lever):
			lever.set_path(target_c, true)
			if is_inside_tree() and has_node("/root/EventBus"):
				get_node("/root/EventBus").siege_gate_lever_switched.emit(lever.gate_id, target_c)

	_update_path_highlights()
	_update_march_barriers()
	if is_instance_valid(maze_board):
		maze_board.queue_redraw()
	queue_redraw()


func _ensure_route_leads_to_branch(target_stage: int, target_branch: int) -> void:
	if not level_data or target_stage <= 0:
		return

	var cur_stage: int = target_stage
	var cur_branch: int = target_branch

	while cur_stage > 0:
		var prev_stage: int = cur_stage - 1
		var prev_stage_dict: Dictionary = level_data.stages[prev_stage] as Dictionary
		var prev_branches: Array = prev_stage_dict.get("branches", [])
		var found := false

		var act_b_prev := _get_active_branch_for_stage(prev_stage)
		var check_branches: Array[int] = [act_b_prev]
		for b_i in range(prev_branches.size()):
			if b_i != act_b_prev:
				check_branches.append(b_i)

		for b_i in check_branches:
			if b_i < prev_branches.size():
				var b_dict: Dictionary = prev_branches[b_i] as Dictionary
				var b_choices: Array = b_dict.get("choices", [])
				for c_i in range(b_choices.size()):
					var c_dict: Dictionary = b_choices[c_i] as Dictionary
					var ey: float = float(c_dict.get("exit_y", 0.5))
					if level_data._find_matching_next_branch(cur_stage, ey) == cur_branch:
						chosen_choices[prev_stage][b_i] = c_i
						if prev_stage < stage_levers.size() and b_i < stage_levers[prev_stage].size():
							var lever: GateLever = stage_levers[prev_stage][b_i]
							if is_instance_valid(lever):
								lever.set_path(c_i, true)
						cur_branch = b_i
						found = true
						break
			if found:
				break

		cur_stage -= 1


func _select_choice_for_channel(stage_idx: int, exit_y: float) -> void:
	if not level_data or stage_idx >= level_data.stages.size():
		return
	var stage_dict: Dictionary = level_data.stages[stage_idx] as Dictionary
	var branches: Array = stage_dict.get("branches", [])
	var active_b := _get_active_branch_for_stage(stage_idx)

	# Priority 1: Check active branch first
	if active_b < branches.size():
		var branch: Dictionary = branches[active_b] as Dictionary
		var choices: Array = branch.get("choices", [])
		for c_i in range(choices.size()):
			var choice: Dictionary = choices[c_i] as Dictionary
			var ey: float = float(choice.get("exit_y", 0.5))
			if absf(ey - exit_y) < 0.05:
				_set_choice(stage_idx, active_b, c_i)
				return

	# Priority 2: Fallback to any other branch
	for b_i in range(branches.size()):
		if b_i == active_b:
			continue
		var branch: Dictionary = branches[b_i] as Dictionary
		var choices: Array = branch.get("choices", [])
		for c_i in range(choices.size()):
			var choice: Dictionary = choices[c_i] as Dictionary
			var ey: float = float(choice.get("exit_y", 0.5))
			if absf(ey - exit_y) < 0.05:
				_set_choice(stage_idx, b_i, c_i)
				return


## Update visual line and gate highlights based on active route from the start
func _update_path_highlights() -> void:
	if not level_data:
		return

	# First dim all gates
	for s_i in range(stage_gates.size()):
		for b_i in range(stage_gates[s_i].size()):
			for c_i in range(stage_gates[s_i][b_i].size()):
				var gate: OperationGate = stage_gates[s_i][b_i][c_i]
				gate.set_highlighted(false)

	# Now trace active route starting from stage 0 branch 0
	var current_branch: int = 0
	for s_i in range(level_data.stages.size()):
		if current_branch >= chosen_choices[s_i].size():
			break

		var choice_idx: int = chosen_choices[s_i][current_branch]
		if current_branch < stage_gates[s_i].size() and choice_idx < stage_gates[s_i][current_branch].size():
			var gate: OperationGate = stage_gates[s_i][current_branch][choice_idx]
			gate.set_highlighted(true)

		# Find next stage branch based on choice exit_y
		var stage_dict: Dictionary = level_data.stages[s_i] as Dictionary
		var branches: Array = stage_dict.get("branches", [])
		var branch: Dictionary = branches[current_branch] as Dictionary
		var choices: Array = branch.get("choices", [])
		if choice_idx < choices.size():
			var exit_y: float = float(choices[choice_idx].get("exit_y", 0.5))
			current_branch = level_data._find_matching_next_branch(s_i + 1, exit_y)

	queue_redraw()


# =========================================================================
# MARCH SEQUENCE
# =========================================================================

func _on_march_pressed() -> void:
	if current_phase != Phase.PLANNING:
		return

	DisplayServer.cursor_set_shape(DisplayServer.CURSOR_ARROW)
	current_phase = Phase.MARCHING
	if march_button:
		march_button.visible = false

	# Prevent orphaning coroutines: lock back button during march
	if back_button:
		back_button.disabled = true

	# Lock all levers
	for s in stage_levers:
		for lever in s:
			lever.lock()

	_execute_march_sequence()


## Build barrier segments from all active corridor boundaries (including diagonal funnel walls)
## and all gate lever arms, passing them to the army cluster for physical collision.
func _update_march_barriers() -> void:
	if not is_instance_valid(army_cluster) or not level_data:
		return

	var poly_pts: PackedVector2Array = get_active_corridor_polygon()
	if poly_pts.size() < 3:
		return

	var castle_x: float = VIEWPORT_W - MARGIN_RIGHT + 15.0
	var segments: Array = []
	var n_pts: int = poly_pts.size()

	# 1. Add all outer boundary segments of the active corridor polygon
	# This automatically provides collision for:
	# - Diagonal courtyard funnel walls into the castle (top and bottom in all lanes)
	# - Channel divider walls and stage transitions
	# - Start chamber outer walls
	for i in range(n_pts):
		var p1: Vector2 = poly_pts[i]
		var p2: Vector2 = poly_pts[(i + 1) % n_pts]

		# Skip the castle gate door entrance so the army can march inside
		if absf(p1.x - castle_x) < 2.0 and absf(p2.x - castle_x) < 2.0:
			continue

		var seg: Vector2 = p2 - p1
		var seg_len: float = seg.length()
		if seg_len < 1.0:
			continue

		var dir: Vector2 = seg / seg_len
		# Clockwise polygon inward normal points into the corridor interior
		var normal: Vector2 = Vector2(-dir.y, dir.x).normalized()
		segments.append({
			"p1": p1,
			"p2": p2,
			"normal": normal
		})

	# 2. Add physical gate barrier arms
	for s_i in range(stage_levers.size()):
		for b_i in range(stage_levers[s_i].size()):
			var lever: GateLever = stage_levers[s_i][b_i]
			if not is_instance_valid(lever):
				continue
			if lever.arm_offsets.size() < 2:
				continue

			var pivot: Vector2 = lever.global_position
			var arm_end: Vector2 = pivot + lever._current_arm_offset
			var choice_idx: int = lever.current_path
			var seg_dir: Vector2 = (arm_end - pivot).normalized()
			var perp: Vector2 = Vector2(-seg_dir.y, seg_dir.x)

			if choice_idx == 0:
				if perp.y > 0:
					perp = -perp
			else:
				if perp.y < 0:
					perp = -perp

			segments.append({
				"p1": pivot,
				"p2": arm_end,
				"normal": perp.normalized()
			})

	army_cluster.set_barrier_segments(segments)


func _execute_march_sequence() -> void:
	var current_count: int = current_soldier_count
	var current_branch: int = 0

	# Build barrier segments from all gate levers
	_update_march_barriers()

	for s_i in range(level_data.stages.size()):
		var lever: GateLever = stage_levers[s_i][current_branch]
		var choice_idx: int = chosen_choices[s_i][current_branch]
		var gate: OperationGate = stage_gates[s_i][current_branch][choice_idx]

		var stage_dict: Dictionary = level_data.stages[s_i] as Dictionary
		var branches: Array = stage_dict.get("branches", [])
		var branch: Dictionary = branches[current_branch] as Dictionary
		var choices: Array = branch.get("choices", [])
		var choice: Dictionary = choices[choice_idx] as Dictionary
		var exit_y_norm: float = float(choice.get("exit_y", 0.5))
		var ch_y_center := _get_channel_center_for_exit_y(s_i, exit_y_norm)
		var cur_ch := _get_channel_for_exit_y(s_i, exit_y_norm)
		if is_instance_valid(army_cluster):
			army_cluster.set_corridor_bounds(cur_ch["y_top"], cur_ch["y_bot"])

		# 1. March army through the open gate into the active channel corridor
		var enter_corridor_pos := Vector2(stage_x_positions[s_i] + 15.0, ch_y_center)
		army_cluster.animate_march_to(enter_corridor_pos, 1.1)
		await army_cluster.march_finished

		# 2. March along the channel to the OperationGate
		army_cluster.animate_march_to(gate.position, 1.2)
		await army_cluster.march_finished

		# 3. Apply math operation
		var ops: Array = choice.get("operations", [])
		var old_count: int = current_count
		current_count = SiegeGateLevel.apply_operations(current_count, ops)

		# 4. Gate activation juice & particles
		gate.play_activate_animation()

		# Screen shake on significant change
		var change_ratio: float = abs(float(current_count - old_count)) / float(maxi(old_count, 1))
		if change_ratio >= 0.4 and has_node("/root/EventBus"):
			get_node("/root/EventBus").screen_shake_requested.emit(0.15 + change_ratio * 0.1)

		# 5. Stand at the math operation and let the count change happen
		army_cluster.set_count_animated(current_count, 1.2)
		await army_cluster.count_animation_finished

		var op_label: String = SiegeGateLevel.format_operations(ops)
		if has_node("/root/EventBus"):
			get_node("/root/EventBus").siege_gate_operation_applied.emit(op_label, old_count, current_count)

		# Advance to next branch based on choice exit_y
		current_branch = level_data._find_matching_next_branch(s_i + 1, exit_y_norm)

	# 6. Final march into the castle (funnel directly into castle gate, clear barriers)
	if is_instance_valid(army_cluster):
		var gate_mid_y: float = (MAZE_Y_TOP + MAZE_Y_BOTTOM) / 2.0
		var last_stage_idx: int = maxi(level_data.stages.size() - 1, 0)
		var last_b: int = _get_active_branch_for_stage(last_stage_idx)
		var last_c: int = chosen_choices[last_stage_idx][last_b] if last_stage_idx < chosen_choices.size() and last_b < chosen_choices[last_stage_idx].size() else 0
		var stage_dict: Dictionary = level_data.stages[last_stage_idx] as Dictionary
		var branches: Array = stage_dict.get("branches", [])
		var last_ey: float = 0.5
		if last_b < branches.size():
			var choices: Array = (branches[last_b] as Dictionary).get("choices", [])
			if last_c < choices.size():
				last_ey = float((choices[last_c] as Dictionary).get("exit_y", 0.5))
		var last_ch: Dictionary = _get_channel_for_exit_y(last_stage_idx, last_ey)
		var top_b: float = minf(last_ch["y_top"], gate_mid_y - 25.0)
		var bot_b: float = maxf(last_ch["y_bot"], gate_mid_y + 25.0)
		army_cluster.set_corridor_bounds(top_b, bot_b)
	# Stop army in the courtyard plaza, cleanly in front of the castle gate
	var castle_door_world_x: float = castle_sprite.position.x - 16.0
	army_cluster.set_max_x(castle_door_world_x)
	var march_stop_x: float = castle_sprite.position.x - 65.0
	var gate_mid_y: float = (MAZE_Y_TOP + MAZE_Y_BOTTOM) / 2.0
	var castle_pos: Vector2 = Vector2(march_stop_x, gate_mid_y)
	army_cluster.animate_march_to(castle_pos, 1.5)
	await army_cluster.march_finished

	# Juicy castle assault: all soldiers attack and breach
	if is_instance_valid(army_cluster) and is_instance_valid(castle_sprite):
		army_cluster.animate_castle_attack(castle_sprite)
		await army_cluster.castle_attack_finished

	await get_tree().create_timer(0.3).timeout

	current_soldier_count = current_count
	_show_result()


# =========================================================================
# RESULT
# =========================================================================

func _show_result() -> void:
	current_phase = Phase.RESULT
	DisplayServer.cursor_set_shape(DisplayServer.CURSOR_ARROW)
	if back_button:
		back_button.disabled = false

	if is_instance_valid(army_cluster):
		army_cluster.clear_barrier_segments()
		army_cluster.clear_max_x()

	var final_count: int = current_soldier_count
	var defense: int = level_data.castle_defense_value
	var is_victory: bool = final_count >= defense
	var optimal: int = level_data.calculate_optimal()
	var optimality_pct: float = float(final_count) / float(maxi(optimal, 1))

	var stars: int = 0
	if optimality_pct >= level_data.star_3_threshold:
		stars = 3
	elif optimality_pct >= level_data.star_2_threshold:
		stars = 2
	elif optimality_pct >= level_data.star_1_threshold:
		stars = 1

	var popup_parent: Node = result_overlay if is_instance_valid(result_overlay) else self
	if is_victory:
		result_title_label.text = "🏰 BURG EROBERT! 🏰"
		result_title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
		result_title_label.pivot_offset = Vector2(160, 15)
		result_title_label.scale = Vector2(1.25, 0.8)
		var title_tw := create_tween()
		title_tw.tween_property(result_title_label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		JuiceManager.spawn_comic_popup(popup_parent, "SIEG! ★", Vector2(320, 36), "flawless")
		_spawn_victory_confetti()
		_spawn_victory_fireworks()
		if is_inside_tree() and has_node("/root/EventBus"):
			get_node("/root/EventBus").screen_shake_requested.emit(0.2)

		var gold_reward: int = 50 + stars * 25
		var xp_reward: int = 30 + stars * 15
		var diamond_reward: int = 1 if stars >= 3 else 0
		var soldiers_bonus: int = 3 + (stars - 1) * 2 if stars >= 1 else 0 # 1★=3, 2★=5, 3★=8
		var wood_reward: int = 10 * stars
		var bread_reward: int = 5 * stars

		if is_inside_tree() and has_node("/root/SaveManager"):
			var sm: Node = get_node("/root/SaveManager")
			sm.add_gold(gold_reward)
			sm.add_xp(xp_reward)
			if diamond_reward > 0:
				sm.add_diamonds(diamond_reward)
			sm.add_soldiers(soldiers_bonus)
			sm.add_wood(wood_reward)
			sm.add_bread(bread_reward)

		# Use the Ultra-Juicy SiegeRewardScreen
		# Stop BGM first so it doesn't overlap with the victory jingle
		if is_inside_tree() and has_node("/root/AudioManager"):
			get_node("/root/AudioManager").stop_music(0.8)
		var reward_screen := SiegeRewardScreen.new()
		add_child(reward_screen)
		reward_screen.next_level_requested.connect(func():
			reward_screen.queue_free()
			_on_result_continue()
		)
		reward_screen.village_requested.connect(func():
			reward_screen.queue_free()
			_on_result_village()
		)
		reward_screen.show_rewards({
			"stars": stars,
			"soldiers_bonus": soldiers_bonus,
			"gold": gold_reward,
			"wood": wood_reward,
			"bread": bread_reward,
			"castle_name": level_data.level_name if level_data else "Eroberte Festung"
		})

		if is_inside_tree() and has_node("/root/EventBus"):
			get_node("/root/EventBus").siege_gate_completed.emit(final_count, defense, is_victory, optimality_pct)
		puzzle_completed.emit(final_count, defense, is_victory, stars)
		return
	else:
		result_title_label.text = "⚔️ ABGEWEHRT! ⚔️"
		result_title_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		JuiceManager.spawn_comic_popup(popup_parent, "NIEDERLAGE!", Vector2(320, 36), "defeat")
		if is_instance_valid(result_reward_label):
			result_reward_label.text = "Tipp: Wähle Hebel für optimale Faktoren!"
			result_reward_label.visible = true

	result_count_label.text = "Deine Armee: %d   |   Burg-Verteidigung: %d" % [final_count, defense]
	result_optimal_label.text = "Optimal möglich: %d Soldaten (%d%%)" % [optimal, int(optimality_pct * 100.0)]

	# Star display with sequential high-energy drop & slam
	for c in result_stars_container.get_children():
		c.queue_free()
	for i in range(3):
		var star_label := Label.new()
		star_label.add_theme_font_size_override("font_size", 28)
		star_label.pivot_offset = Vector2(14, 14)
		if i < stars:
			star_label.text = "★"
			star_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
		else:
			star_label.text = "☆"
			star_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		result_stars_container.add_child(star_label)

	result_continue_btn.text = "Erneut versuchen 🔄"

	result_overlay.visible = true
	result_overlay.modulate.a = 0.0
	var fade_tw := create_tween()
	fade_tw.tween_property(result_overlay, "modulate:a", 1.0, 0.25)

	# Bouncy pop-in for the defeat panel
	if is_instance_valid(result_panel):
		result_panel.scale = Vector2(0.15, 0.15)
		var pop_tw := create_tween()
		pop_tw.tween_property(result_panel, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if is_inside_tree() and has_node("/root/EventBus"):
		get_node("/root/EventBus").siege_gate_completed.emit(final_count, defense, is_victory, optimality_pct)

	if is_inside_tree() and has_node("/root/AudioManager"):
		var am: Node = get_node("/root/AudioManager")
		if am.has_method("play_sfx"):
			am.play_sfx("wrong")
			am.play_sfx("wrong")

	puzzle_completed.emit(final_count, defense, is_victory, stars)


func _spawn_victory_confetti() -> void:
	if not is_instance_valid(celebration_container):
		return

	var confetti_colors: Array[Color] = [
		Color(1.0, 0.85, 0.15),  # Gold
		Color(1.0, 0.25, 0.4),   # Ruby
		Color(0.2, 0.7, 1.0),    # Cyan / Sky
		Color(0.25, 0.95, 0.45), # Emerald
		Color(0.85, 0.35, 1.0),  # Royal Violet
		Color(1.0, 0.55, 0.15)   # Amber / Orange
	]

	# Left cannon at bottom-left
	_create_cannon_emitter(Vector2(50, 355), Vector2(0.65, -1.0), confetti_colors)
	# Right cannon at bottom-right
	_create_cannon_emitter(Vector2(590, 355), Vector2(-0.65, -1.0), confetti_colors)
	# Sky rain across top
	_create_sky_shower_emitter(confetti_colors)


func _create_cannon_emitter(origin: Vector2, shoot_dir: Vector2, colors: Array[Color]) -> void:
	for c in colors:
		var emitter := CPUParticles2D.new()
		emitter.position = origin
		emitter.emitting = true
		emitter.one_shot = true
		emitter.explosiveness = 0.85
		emitter.lifetime = 2.4
		emitter.amount = 16
		emitter.spread = 32.0
		emitter.direction = shoot_dir
		emitter.initial_velocity_min = 250.0
		emitter.initial_velocity_max = 420.0
		emitter.angular_velocity_min = 180.0
		emitter.angular_velocity_max = 540.0
		emitter.scale_amount_min = 3.5
		emitter.scale_amount_max = 6.5
		emitter.gravity = Vector2(0, 220)
		emitter.color = c
		celebration_container.add_child(emitter)
		var tw := create_tween()
		tw.tween_callback(emitter.queue_free).set_delay(3.0)


func _create_sky_shower_emitter(colors: Array[Color]) -> void:
	for c in colors:
		var emitter := CPUParticles2D.new()
		emitter.position = Vector2(randf_range(120, 520), -10)
		emitter.emitting = true
		emitter.one_shot = true
		emitter.explosiveness = 0.6
		emitter.lifetime = 3.0
		emitter.amount = 12
		emitter.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		emitter.emission_rect_extents = Vector2(180, 5)
		emitter.direction = Vector2(0, 1)
		emitter.spread = 45.0
		emitter.initial_velocity_min = 40.0
		emitter.initial_velocity_max = 110.0
		emitter.angular_velocity_min = 120.0
		emitter.angular_velocity_max = 360.0
		emitter.scale_amount_min = 3.0
		emitter.scale_amount_max = 5.5
		emitter.gravity = Vector2(0, 95)
		emitter.color = c
		celebration_container.add_child(emitter)
		var tw := create_tween()
		tw.tween_callback(emitter.queue_free).set_delay(3.5)


func _spawn_victory_fireworks() -> void:
	var fireworks_data: Array = [
		{ "pos": Vector2(160, 90), "delay": 0.1, "color": Color(1.0, 0.85, 0.2) },
		{ "pos": Vector2(480, 85), "delay": 0.35, "color": Color(0.3, 0.8, 1.0) },
		{ "pos": Vector2(320, 55), "delay": 0.65, "color": Color(1.0, 0.3, 0.85) }
	]

	for fw in fireworks_data:
		var tw := create_tween()
		tw.tween_interval(fw["delay"])
		tw.tween_callback(func():
			if not is_instance_valid(celebration_container):
				return
			var burst := CPUParticles2D.new()
			burst.position = fw["pos"]
			burst.emitting = true
			burst.one_shot = true
			burst.explosiveness = 1.0
			burst.lifetime = 0.7
			burst.amount = 35
			burst.spread = 180.0
			burst.initial_velocity_min = 80.0
			burst.initial_velocity_max = 160.0
			burst.scale_amount_min = 2.5
			burst.scale_amount_max = 5.0
			burst.gravity = Vector2(0, 80)
			burst.color = fw["color"]
			celebration_container.add_child(burst)

			if has_node("/root/AudioManager"):
				var am: Node = get_node("/root/AudioManager")
				if am.has_method("play_sfx"):
					am.play_sfx("coin", randf_range(1.3, 1.6))

			var clean_tw := create_tween()
			clean_tw.tween_callback(burst.queue_free).set_delay(1.0)
		)


func _spawn_star_spark(parent: Node, pos: Vector2) -> void:
	var spark := CPUParticles2D.new()
	spark.position = pos
	spark.emitting = true
	spark.one_shot = true
	spark.explosiveness = 0.95
	spark.lifetime = 0.45
	spark.amount = 20
	spark.spread = 180.0
	spark.initial_velocity_min = 50.0
	spark.initial_velocity_max = 110.0
	spark.scale_amount_min = 2.0
	spark.scale_amount_max = 4.0
	spark.gravity = Vector2.ZERO
	spark.color = Color(1.0, 0.92, 0.3)
	parent.add_child(spark)
	var tw := create_tween()
	tw.tween_callback(spark.queue_free).set_delay(0.6)


func _on_result_continue() -> void:
	result_overlay.visible = false
	if is_instance_valid(celebration_container):
		for c in celebration_container.get_children():
			c.queue_free()
	var is_victory: bool = current_soldier_count >= level_data.castle_defense_value
	if is_victory:
		if current_level_index + 1 < total_levels_count:
			load_level_by_index(current_level_index + 1)
		else:
			load_level_by_index(0)
	else:
		load_level(level_data)


func _on_result_village() -> void:
	result_overlay.visible = false
	if is_instance_valid(celebration_container):
		for c in celebration_container.get_children():
			c.queue_free()
	get_tree().change_scene_to_file("res://scenes/village/VillageHub.tscn")


func _on_back_pressed() -> void:
	if has_node("/root/RunManager"):
		var rm: Node = get_node("/root/RunManager")
		if rm.is_run_active and ResourceLoader.exists("res://scenes/map/RunMap.tscn"):
			get_tree().change_scene_to_file("res://scenes/map/RunMap.tscn")
			return

	if ResourceLoader.exists("res://scenes/village/VillageHub.tscn"):
		get_tree().change_scene_to_file("res://scenes/village/VillageHub.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/menu/TitleScreen.tscn")


func _navigate_forward() -> void:
	if has_node("/root/RunManager"):
		var rm: Node = get_node("/root/RunManager")
		rm.set("siege_army_size", current_soldier_count)

	if ResourceLoader.exists("res://scenes/arena/Arena.tscn"):
		get_tree().change_scene_to_file("res://scenes/arena/Arena.tscn")
	elif ResourceLoader.exists("res://scenes/main/Main.tscn"):
		get_tree().change_scene_to_file("res://scenes/main/Main.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/menu/TitleScreen.tscn")


# =========================================================================
# CASTLE VECTOR DRAWING HELPER
# =========================================================================

class CastleDraw extends Node2D:
	var defense_value: int = 40
	var flash_intensity: float = 0.0
	var is_breached: bool = false
	var gate_open_ratio: float = 0.0
	var sunburst_angle: float = 0.0

	func flash_hit() -> void:
		flash_intensity = 1.0
		var tw := create_tween()
		tw.tween_property(self, "flash_intensity", 0.0, 0.12)
		tw.tween_callback(queue_redraw)
		queue_redraw()

	func breach() -> void:
		is_breached = true
		var tw := create_tween()
		tw.tween_property(self, "gate_open_ratio", 1.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var ray_tw := create_tween().set_loops()
		ray_tw.tween_method(func(ang: float):
			sunburst_angle = ang
			queue_redraw()
		, 0.0, TAU, 5.0)
		queue_redraw()

	func _draw() -> void:
		# Castle body
		var body_col := Color(0.35, 0.28, 0.2).lerp(Color(0.65, 0.48, 0.35), flash_intensity * 0.4)
		draw_rect(Rect2(-20, -16, 40, 32), body_col)
		draw_rect(Rect2(-20, -16, 40, 32), Color(0.2, 0.15, 0.1), false, 2.0)

		# Battlements
		for i in range(5):
			var bx: float = -18.0 + float(i) * 9.0
			draw_rect(Rect2(bx, -24, 6, 9), Color(0.45, 0.35, 0.25))

		# Heavy Gate / Open Doorway
		if is_breached and gate_open_ratio > 0.0:
			# Glowing golden interior behind open gates
			draw_rect(Rect2(-7, 0, 14, 16), Color(1.0, 0.9, 0.45))
			draw_arc(Vector2(0, 0), 7.0, PI, TAU, 16, Color(1.0, 0.95, 0.6), 2.0)

			# Sunburst beams shining outward into the courtyard
			var ray_len: float = 24.0 * gate_open_ratio
			for r in range(6):
				var ang: float = sunburst_angle + float(r) * (TAU / 6.0)
				var ray_dir := Vector2(-absf(cos(ang)), sin(ang) * 0.7)
				draw_line(Vector2(-7, 8), Vector2(-7, 8) + ray_dir * ray_len, Color(1.0, 0.85, 0.2, 0.4 * gate_open_ratio), 2.0)

			# Split gate doors swinging open
			var open_slide: float = gate_open_ratio * 5.0
			draw_rect(Rect2(-7 - open_slide, 0, 7, 16), Color(0.25, 0.16, 0.1))
			draw_rect(Rect2(open_slide, 0, 7, 16), Color(0.25, 0.16, 0.1))
		else:
			var gate_col := Color(0.15, 0.1, 0.08).lerp(Color(0.9, 0.5, 0.15), flash_intensity * 0.7)
			draw_rect(Rect2(-7, 0, 14, 16), gate_col)
			draw_arc(Vector2(0, 0), 7.0, PI, TAU, 16, Color(0.25, 0.18, 0.12), 2.0)

		# Defense Shield Icon / Conquered Golden Crown
		if is_breached:
			var crown_gold := Color(1.0, 0.85, 0.2)
			draw_circle(Vector2(0, 28), 6.0, crown_gold)
			draw_line(Vector2(-8, 36), Vector2(8, 36), crown_gold, 2.0)
			draw_line(Vector2(-6, 24), Vector2(0, 20), Color(1.0, 1.0, 0.6), 2.0)
			draw_line(Vector2(6, 24), Vector2(0, 20), Color(1.0, 1.0, 0.6), 2.0)
			draw_string(
				ThemeDB.fallback_font,
				Vector2(-15, 48),
				"SIEG!",
				HORIZONTAL_ALIGNMENT_CENTER, 30, 9,
				Color(1.0, 0.9, 0.2)
			)
		else:
			var shield_pts := PackedVector2Array([
				Vector2(-10, 24),
				Vector2(10, 24),
				Vector2(10, 34),
				Vector2(0, 42),
				Vector2(-10, 34)
			])
			var shield_col := Color(0.8, 0.2, 0.2).lerp(Color(1.0, 0.95, 0.4), flash_intensity)
			draw_polygon(shield_pts, PackedColorArray([shield_col]))
			draw_polyline(shield_pts, Color(1.0, 0.8, 0.8).lerp(Color.WHITE, flash_intensity), 1.5 + flash_intensity * 1.5, true)

			# Defense value text
			draw_string(
				ThemeDB.fallback_font,
				Vector2(-10, 36),
				str(defense_value),
				HORIZONTAL_ALIGNMENT_CENTER, 20, 11,
				Color.WHITE
			)

