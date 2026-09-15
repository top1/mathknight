class_name Arena
extends Control
## Arena — Royal Tournament & Endless Wave Gauntlet.
## Players face escalating waves of arena gladiators with 1 official daily entry.
## Failure is gentle: 100% gold and XP retained, highscores and badges recorded.

# UI Nodes
@onready var lobby_panel: Control = $LobbyPanel
@onready var battle_panel: Control = $BattlePanel
@onready var results_panel: Control = $ResultsPanel

# Lobby controls
@onready var lobby_status_label: Label = $LobbyPanel/VBox/StatusLabel
@onready var lobby_record_label: Label = $LobbyPanel/VBox/RecordLabel
@onready var lobby_start_btn: Button = $LobbyPanel/VBox/Buttons/StartBtn
@onready var lobby_back_btn: Button = $LobbyPanel/VBox/Buttons/BackBtn
@onready var badges_hbox: HBoxContainer = $LobbyPanel/VBox/BadgesHBox

# Battle controls
@onready var wave_label: Label = $BattlePanel/TopBar/WaveLabel
@onready var hp_label: Label = $BattlePanel/TopBar/HPLabel
@onready var score_label: Label = $BattlePanel/TopBar/ScoreLabel
@onready var problem_label: Label = $BattlePanel/InputArea/VBox/ProblemLabel
@onready var choice_grid: GridContainer = $BattlePanel/InputArea/VBox/ChoiceGrid
@onready var arena_enemies_node: Node2D = $BattlePanel/Battlefield/Enemies
@onready var knight_visual: Node2D = $BattlePanel/Battlefield/KnightVisual
@onready var retreat_btn: Button = $BattlePanel/TopBar/RetreatBtn

# Results controls
@onready var result_title_label: Label = $ResultsPanel/VBox/ResultTitle
@onready var result_wave_label: Label = $ResultsPanel/VBox/ResultWave
@onready var result_rewards_label: Label = $ResultsPanel/VBox/ResultRewards
@onready var result_badges_label: Label = $ResultsPanel/VBox/ResultBadges
@onready var result_hub_btn: Button = $ResultsPanel/VBox/HubBtn

# Arena Game State
var current_wave: int = 1
var arena_gold_earned: int = 0
var arena_xp_earned: int = 0
var current_problem: MathProblem = null
var is_official_tournament: bool = true
var is_in_battle: bool = false
var wave_enemies_remaining: int = 0
var problem_start_time: float = 0.0
var combo_streak: int = 0

# Knight stats in Arena
var knight_max_hp: float = 10.0
var knight_hp: float = 10.0
var knight_atk: float = 1.0
var knight_armor: float = 0.0
var knight_dodge: float = 0.0

const BADGE_DEFINITIONS = [
	{"id": "arena_wave_5", "name": "🥉 Bronze Gladiator", "wave": 5},
	{"id": "arena_wave_10", "name": "🥈 Silber Champion", "wave": 10},
	{"id": "arena_wave_15", "name": "🥇 Gold Bezwinger", "wave": 15},
	{"id": "arena_wave_25", "name": "👑 Königliche Legende", "wave": 25}
]

func _ready() -> void:
	if lobby_start_btn: lobby_start_btn.pressed.connect(_on_start_pressed)
	if lobby_back_btn: lobby_back_btn.pressed.connect(_on_back_pressed)
	if retreat_btn: retreat_btn.pressed.connect(_on_retreat_pressed)
	if result_hub_btn: result_hub_btn.pressed.connect(_on_back_pressed)
	
	_show_lobby()

func _show_lobby() -> void:
	is_in_battle = false
	if lobby_panel: lobby_panel.visible = true
	if battle_panel: battle_panel.visible = false
	if results_panel: results_panel.visible = false
	
	_update_lobby_ui()

func _update_lobby_ui() -> void:
	var today = Time.get_date_string_from_system()
	var played_today = false
	var best_wave = 0
	
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		played_today = (sm.arena_last_played_date == today)
		best_wave = sm.best_arena_wave
		
	if lobby_status_label:
		if played_today:
			lobby_status_label.text = "✓ Heutiges Turnier bereits absolviert!\n(Übungsläufe jederzeit möglich)"
			lobby_status_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
			is_official_tournament = false
		else:
			lobby_status_label.text = "★ Heutiger königlicher Wettkampf: OFFEN! ★\n(Dein bester Versuch des Tages wird gewertet)"
			lobby_status_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
			is_official_tournament = true
			
	if lobby_record_label:
		lobby_record_label.text = "Beste Welle aller Zeiten: Welle %d" % best_wave
		
	if lobby_start_btn:
		lobby_start_btn.text = "⚔️ TURNIER STARTEN" if is_official_tournament else "⚔️ ÜBUNGS-KAMPF STARTEN"
		
	_render_badges()

func _render_badges() -> void:
	if not badges_hbox:
		return
	for c in badges_hbox.get_children():
		c.queue_free()
		
	var unlocked_badges: Array[String] = []
	if has_node("/root/SaveManager"):
		unlocked_badges = get_node("/root/SaveManager").mastery_badges
		
	for b in BADGE_DEFINITIONS:
		var has_badge = unlocked_badges.has(b.id)
		var p = PanelContainer.new()
		var st = StyleBoxFlat.new()
		st.bg_color = Color(0.2, 0.18, 0.1, 0.85) if has_badge else Color(0.12, 0.12, 0.14, 0.6)
		st.border_color = Color(1.0, 0.8, 0.2) if has_badge else Color(0.3, 0.3, 0.35)
		st.set_border_width_all(1)
		st.set_corner_radius_all(4)
		st.content_margin_left = 6
		st.content_margin_right = 6
		st.content_margin_top = 4
		st.content_margin_bottom = 4
		p.add_theme_stylebox_override("panel", st)
		
		var l = Label.new()
		l.text = b.name if has_badge else ("🔒 " + b.name.split(" ")[1])
		l.add_theme_color_override("font_color", Color.WHITE if has_badge else Color(0.5, 0.5, 0.5))
		p.add_child(l)
		badges_hbox.add_child(p)

func _on_start_pressed() -> void:
	_start_arena_match()

func _start_arena_match() -> void:
	current_wave = 1
	arena_gold_earned = 0
	arena_xp_earned = 0
	combo_streak = 0
	is_in_battle = true
	
	if lobby_panel: lobby_panel.visible = false
	if battle_panel: battle_panel.visible = true
	if results_panel: results_panel.visible = false
	
	# Load knight stats
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		knight_max_hp = sm.get_max_hp()
		knight_hp = knight_max_hp
		knight_atk = sm.get_attack_power()
		knight_armor = sm.get_armor()
		knight_dodge = sm.get_dodge_chance()
	else:
		knight_max_hp = 10.0
		knight_hp = 10.0
		knight_atk = 1.0
		knight_armor = 0.0
		knight_dodge = 0.0
		
	_update_battle_hud()
	_start_wave(current_wave)

func _start_wave(wave_num: int) -> void:
	current_wave = wave_num
	_update_battle_hud()
	
	JuiceManager.spawn_comic_popup(self, "WELLE " + str(wave_num) + "!", Vector2(320, 100), "blitz")
	
	# Clear old enemies
	if arena_enemies_node:
		for child in arena_enemies_node.get_children():
			child.queue_free()
			
	# Spawn wave enemies
	wave_enemies_remaining = 1 + int(wave_num / 3)
	_spawn_wave_enemies(wave_enemies_remaining, wave_num)
	
	# Generate math problem
	_next_problem()

func _spawn_wave_enemies(count: int, wave_num: int) -> void:
	if not arena_enemies_node:
		return
	var enemy_scene = load("res://scenes/enemy/Enemy.tscn")
	if not enemy_scene:
		return
		
	for i in range(count):
		var enemy = enemy_scene.instantiate()
		arena_enemies_node.add_child(enemy)
		enemy.position = Vector2(480 + (i * 45), 18)
		# Scale enemy HP and speed with wave
		var base_hp = 2.0 + float(wave_num) * 0.8
		enemy.max_hp = base_hp
		enemy.hp = base_hp
		enemy.speed = minf(60.0, 20.0 + float(wave_num) * 1.5)
		if enemy.has_method("update_hearts_display"):
			enemy.update_hearts_display()

func _next_problem() -> void:
	# Build math config based on current wave
	var diff = MathConfig.Difficulty.EASY
	var op = MathConfig.Operation.ADDITION
	
	if current_wave >= 12:
		diff = MathConfig.Difficulty.HARD
		op = MathConfig.Operation.MIXED
	elif current_wave >= 7:
		diff = MathConfig.Difficulty.MEDIUM
		op = [MathConfig.Operation.MULTIPLICATION, MathConfig.Operation.DIVISION].pick_random()
	elif current_wave >= 4:
		diff = MathConfig.Difficulty.MEDIUM
		op = [MathConfig.Operation.ADDITION, MathConfig.Operation.SUBTRACTION].pick_random()
	else:
		diff = MathConfig.Difficulty.EASY
		op = MathConfig.Operation.ADDITION
		
	var cfg = MathConfig.create_config(MathConfig.GameMode.TASK_TO_RESULT, op, diff)
	if has_node("/root/MathEngine"):
		current_problem = get_node("/root/MathEngine").generate_problem(cfg)
	else:
		current_problem = MathProblem.new()
		current_problem.operand_a = randi_range(1, 9)
		current_problem.operand_b = randi_range(1, 9)
		current_problem.correct_answer = current_problem.operand_a + current_problem.operand_b
		current_problem.question_text = "%d + %d = ?" % [current_problem.operand_a, current_problem.operand_b]
		current_problem.choices = [current_problem.correct_answer, current_problem.correct_answer + 1, current_problem.correct_answer - 1, current_problem.correct_answer + 2]
		current_problem.choices.shuffle()
		
	problem_start_time = Time.get_ticks_msec() / 1000.0
	
	if problem_label:
		problem_label.text = current_problem.question_text
		
	_render_choices(current_problem.choices)

func _render_choices(choices: Array[int]) -> void:
	if not choice_grid:
		return
	for c in choice_grid.get_children():
		c.queue_free()
		
	for val in choices:
		var btn = Button.new()
		btn.text = str(val)
		btn.custom_minimum_size = Vector2(80, 48)
		btn.add_theme_font_size_override("font_size", 20)
		btn.pressed.connect(func(): _on_answer_submitted(val, btn))
		choice_grid.add_child(btn)

func _on_answer_submitted(selected_val: int, btn: Button) -> void:
	if not is_in_battle or current_problem == null:
		return
		
	var elapsed = (Time.get_ticks_msec() / 1000.0) - problem_start_time
	var is_correct = (selected_val == current_problem.correct_answer)
	
	if is_correct:
		combo_streak += 1
		var is_blitz = (elapsed < 1.5)
		var dmg = knight_atk * (1.5 if is_blitz else 1.0) * (1.0 + float(combo_streak) * 0.1)
		
		# Popup & hit
		var popup_tag = "BLITZ! ⚡" if is_blitz else ("POW! x" + str(combo_streak))
		JuiceManager.spawn_comic_popup(self, popup_tag, btn.global_position + Vector2(20, -30), "blitz" if is_blitz else "attack")
		
		# Animate Knight attack
		if knight_visual:
			var tw = create_tween()
			tw.tween_property(knight_visual, "position:x", 120.0, 0.08)
			tw.tween_property(knight_visual, "position:x", 80.0, 0.15)
			
		_damage_front_enemy(dmg)
		
		if has_node("/root/EventBus"):
			get_node("/root/EventBus").answer_correct.emit(current_problem, combo_streak)
	else:
		combo_streak = 0
		JuiceManager.spawn_comic_popup(self, "DANEBEN!", btn.global_position + Vector2(20, -30), "defeat")
		if has_node("/root/EventBus"):
			get_node("/root/EventBus").answer_wrong.emit(current_problem)
			
		# Wrong answer penalty: front enemy counter-attacks!
		_enemy_counter_attack()

func _damage_front_enemy(dmg: float) -> void:
	if not arena_enemies_node:
		return
	var enemies = arena_enemies_node.get_children()
	if enemies.is_empty():
		return
		
	var target = enemies[0]
	if target.has_method("take_hit"):
		target.take_hit(dmg)
		if target.hp <= 0:
			_on_enemy_slain(target)
		else:
			_next_problem()
	else:
		target.queue_free()
		_on_enemy_slain(target)

func _on_enemy_slain(enemy: Node) -> void:
	JuiceManager.spawn_comic_popup(self, "BEZWUNGEN!", enemy.global_position + Vector2(0, -20), "cleave")
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").enemy_defeated.emit(enemy)
		
	wave_enemies_remaining -= 1
	if wave_enemies_remaining <= 0:
		# Wave Cleared!
		_on_wave_cleared()
	else:
		_next_problem()

func _on_wave_cleared() -> void:
	var wave_gold = 10 + current_wave * 2
	var wave_xp = 15 + current_wave * 3
	arena_gold_earned += wave_gold
	arena_xp_earned += wave_xp
	
	# Slight heal
	knight_hp = minf(knight_max_hp, knight_hp + 2.0)
	_update_battle_hud()
	
	JuiceManager.spawn_comic_popup(self, "WELLE MEISTERT! +%d🪙" % wave_gold, Vector2(320, 110), "flawless")
	
	var tw = get_tree().create_timer(1.2)
	tw.timeout.connect(func():
		if is_in_battle:
			_start_wave(current_wave + 1)
	)

func _enemy_counter_attack() -> void:
	var raw_damage = 2.0 + float(current_wave) * 0.4
	
	# Agility dodge roll
	if randf() < knight_dodge:
		JuiceManager.spawn_comic_popup(self, "WHOOSH! (DODGE)", Vector2(80, 140), "dodge")
		return
		
	# Armor mitigation
	var final_damage = maxf(1.0, raw_damage - knight_armor)
	knight_hp = maxf(0.0, knight_hp - final_damage)
	_update_battle_hud()
	
	JuiceManager.spawn_comic_popup(self, "-%d HP" % int(final_damage), Vector2(80, 140), "defeat")
	
	if knight_hp <= 0.0:
		_end_arena_match(false)
	else:
		_next_problem()

func _update_battle_hud() -> void:
	if wave_label:
		wave_label.text = "★ WELLE %d ★" % current_wave
	if hp_label:
		hp_label.text = "❤️ %d / %d" % [int(knight_hp), int(knight_max_hp)]
	if score_label:
		score_label.text = "🪙 +%d | ⬆️ +%d XP" % [arena_gold_earned, arena_xp_earned]

func _on_retreat_pressed() -> void:
	_end_arena_match(true)

func _end_arena_match(is_voluntary: bool) -> void:
	is_in_battle = false
	if battle_panel: battle_panel.visible = false
	if results_panel: results_panel.visible = true
	
	# Save earned gold & XP
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		if arena_gold_earned > 0: sm.add_gold(arena_gold_earned)
		if arena_xp_earned > 0: sm.add_xp(arena_xp_earned)
		
		# Record date & highscore
		if is_official_tournament:
			sm.arena_last_played_date = Time.get_date_string_from_system()
			
		if current_wave > sm.best_arena_wave:
			sm.best_arena_wave = current_wave
			
		# Check badges
		var new_badges: Array[String] = []
		for b in BADGE_DEFINITIONS:
			if current_wave >= b.wave and not sm.mastery_badges.has(b.id):
				sm.award_mastery_badge(b.id)
				new_badges.append(b.name)
				
		sm.save_data()
		
		if result_badges_label:
			if new_badges.is_empty():
				result_badges_label.text = ""
			else:
				result_badges_label.text = "🎉 NEUE MEISTER-ABZEICHEN:\n" + "\n".join(new_badges)
				
	if result_title_label:
		result_title_label.text = "EHRENVOLLER ABZUG!" if is_voluntary else "EHRENVOLL GEKÄMPFT!"
	if result_wave_label:
		result_wave_label.text = "Erreichte Welle: Welle %d" % current_wave
	if result_rewards_label:
		result_rewards_label.text = "Belohnungen gesichert:\n+%d 🪙 Gold   |   +%d ⬆️ XP" % [arena_gold_earned, arena_xp_earned]

func _on_back_pressed() -> void:
	if ResourceLoader.exists("res://scenes/village/VillageHub.tscn"):
		get_tree().change_scene_to_file("res://scenes/village/VillageHub.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/menu/TitleScreen.tscn")
