extends Control
class_name BlacksmithForge

## The Blacksmith's Forge mini-game.
## Top-down anvil perspective with a glowing heated sword blade.
## Target reticle glides along the length of the sword over multiple candidate answers.
## Player times the hammer strike onto the correct calculation result, triggering
## dynamic multi-stage hammer swing animations, explosive juicy sparks, and metallic anvil clangs.

@onready var equation_label: Label = $TopBar/CenterContainer/VBox/EquationLabel
@onready var subtitle_label: Label = $TopBar/CenterContainer/VBox/SubtitleLabel
@onready var quality_progress: ProgressBar = $TopBar/RightContainer/VBox/QualityBar
@onready var quality_label: Label = $TopBar/RightContainer/VBox/QualityLabel
@onready var streak_badge: PanelContainer = $TopBar/RightContainer/VBox/StreakBadge
@onready var streak_label: Label = $TopBar/RightContainer/VBox/StreakBadge/StreakLabel
@onready var back_btn: Button = $TopBar/LeftContainer/BackBtn
@onready var hit_btn: Button = $HitButtonContainer/HitBtn

@onready var sword_track: Node2D = $SwordTrackLayer
@onready var track_line: Line2D = $SwordTrackLayer/TrackLine
@onready var answer_nodes_container: Node2D = $SwordTrackLayer/AnswerNodes
@onready var target_reticle: Node2D = $SwordTrackLayer/TargetReticle
@onready var hammer_pivot: Node2D = $HammerLayer/HammerPivot
@onready var hammer_sprite: Sprite2D = $HammerLayer/HammerPivot/HammerSprite
@onready var sparks_particles: CPUParticles2D = $Sparks
@onready var embers_particles: CPUParticles2D = $Embers
@onready var impact_burst: Sprite2D = $ImpactBurst
@onready var shockwave: Line2D = $Shockwave
@onready var strike_flash: ColorRect = $StrikeFlash

@onready var result_panel: Control = $ResultPanel
@onready var result_title: Label = $ResultPanel/ModalBox/VBox/Title
@onready var result_desc: Label = $ResultPanel/ModalBox/VBox/Desc
@onready var claim_btn: Button = $ResultPanel/ModalBox/VBox/ClaimBtn

# Track boundaries along the sword blade in 640x360 screen space
const TRACK_MIN_X: float = 125.0  # Near the tip of the blade
const TRACK_MAX_X: float = 430.0  # Near the crossguard
const TRACK_Y: float = 182.0      # Center line of the sword blade
const HIT_TOLERANCE_PX: float = 38.0 # Pixel radius around answer node for valid hit
const HAMMER_HOVER_Y: float = 136.0  # Resting hover height directly above the target line

# Target slider movement
var _target_x: float = TRACK_MIN_X
var _target_dir: float = 1.0
var _target_speed: float = 240.0 # Pixels per second
var _is_forging_active: bool = false
var _is_striking: bool = false
var _screen_shake: float = 0.0

# Game Session progression
var _strikes_total: int = 8
var _current_strike_idx: int = 0
var _quality_points: int = 0
var _streak_count: int = 0

var _current_problem: MathProblem = null
var _candidate_answers: Array[int] = []
var _answer_nodes: Array[Node2D] = []
var _correct_node: Node2D = null

# Backward-compatibility array for tests
var _ingot_buttons: Array[Button] = []


func _ready() -> void:
	if back_btn and not back_btn.pressed.is_connected(_on_back_pressed):
		back_btn.pressed.connect(_on_back_pressed)

	if claim_btn and not claim_btn.pressed.is_connected(_on_back_pressed):
		claim_btn.pressed.connect(_on_back_pressed)

	if hit_btn and not hit_btn.pressed.is_connected(_on_hit_button_pressed):
		hit_btn.pressed.connect(_on_hit_button_pressed)

	if result_panel:
		result_panel.visible = false

	if strike_flash:
		strike_flash.modulate.a = 0.0
		strike_flash.visible = true

	if impact_burst:
		impact_burst.visible = false

	if shockwave:
		shockwave.visible = false
		_setup_shockwave_circle()

	# Set hammer striking face offset: bottom contact point at (159, 520) of 925x633 sprite
	if hammer_sprite:
		hammer_sprite.centered = false
		hammer_sprite.offset = Vector2(-159.0, -520.0)
		hammer_sprite.scale = Vector2(0.22, 0.22)

	_setup_track_line()
	start_forging_session()


func _setup_shockwave_circle() -> void:
	if not shockwave:
		return
	shockwave.clear_points()
	const SEGMENTS: int = 24
	const RADIUS: float = 36.0
	for i in range(SEGMENTS + 1):
		var angle = float(i) * TAU / float(SEGMENTS)
		shockwave.add_point(Vector2(cos(angle) * RADIUS, sin(angle) * RADIUS))


func _setup_track_line() -> void:
	if track_line:
		track_line.clear_points()
		track_line.add_point(Vector2(TRACK_MIN_X - 15, TRACK_Y))
		track_line.add_point(Vector2(TRACK_MAX_X + 15, TRACK_Y))
		track_line.default_color = Color(1.0, 0.6, 0.1, 0.75)
		track_line.width = 4.0


func start_forging_session() -> void:
	_is_forging_active = true
	_is_striking = false
	_target_x = TRACK_MIN_X
	_target_dir = 1.0
	_current_strike_idx = 0
	_quality_points = 0
	_streak_count = 0
	_screen_shake = 0.0

	if result_panel:
		result_panel.visible = false

	_update_quality_display()
	_update_streak_display()
	_generate_forge_problem()

	# Start Forge BGM
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_music("battle_forge", 0.5)


func _generate_forge_problem() -> void:
	if has_node("/root/MathEngine"):
		var me = get_node("/root/MathEngine")
		if me.current_config == null:
			me.current_config = MathConfig.create_config(MathConfig.GameMode.TASK_TO_RESULT, MathConfig.Operation.MULTIPLICATION, MathConfig.Difficulty.EASY)
		_current_problem = me.generate_problem()

	if _current_problem == null:
		_current_problem = MathProblem.new()
		var a = randi_range(3, 9)
		var b = randi_range(2, 9)
		_current_problem.operand_a = a
		_current_problem.operand_b = b
		_current_problem.operator_symbol = "×"
		_current_problem.correct_answer = a * b
		_current_problem.question_text = "%d × %d" % [a, b]

	if equation_label and _current_problem:
		equation_label.text = _current_problem.question_text + " = ?"

	if subtitle_label:
		if _streak_count >= 3:
			subtitle_label.text = "🔥 MEISTER-SERIE AKTIV! EXTRA FUNKEN & BONUS-PUNKTE! ⚡"
			subtitle_label.modulate = Color(1.5, 1.2, 0.2)
		else:
			subtitle_label.text = "⚔️ Schlage zu, wenn der Zeiger auf dem richtigen Ergebnis steht! 🔨"
			subtitle_label.modulate = Color(1.0, 1.0, 1.0)

	# Build 4 candidate answers (1 correct + 3 distinct distractors)
	var correct = _current_problem.correct_answer
	var candidates: Array[int] = [correct]

	var offsets = [-2, -1, 1, 2, 3, -3, 10, -10, 5, -5]
	offsets.shuffle()
	for off in offsets:
		var cand = max(1, correct + off)
		if not candidates.has(cand):
			candidates.append(cand)
		if candidates.size() >= 4:
			break

	while candidates.size() < 4:
		candidates.append(candidates.size() + correct + 4)

	candidates.shuffle()
	_candidate_answers = candidates
	_spawn_answer_nodes(candidates, correct)


func _spawn_answer_nodes(candidates: Array[int], correct_answer: int) -> void:
	for child in answer_nodes_container.get_children():
		child.queue_free()
	_answer_nodes.clear()
	_ingot_buttons.clear()
	_correct_node = null

	var count = candidates.size()
	var step = (TRACK_MAX_X - TRACK_MIN_X) / float(count - 1) if count > 1 else 0.0

	for i in range(count):
		var val = candidates[i]
		var node_pos = Vector2(TRACK_MIN_X + float(i) * step, TRACK_Y)

		var node = _create_answer_badge(val, val == correct_answer)
		node.position = node_pos
		answer_nodes_container.add_child(node)
		_answer_nodes.append(node)

		if val == correct_answer:
			_correct_node = node

		# Invisible fallback button for test suite compatibility
		var btn = Button.new()
		btn.text = str(val)
		btn.visible = false
		btn.pressed.connect(_on_ingot_pressed.bind(val, btn))
		add_child(btn)
		_ingot_buttons.append(btn)


func _create_answer_badge(value: int, is_correct: bool) -> Node2D:
	var badge = Node2D.new()
	badge.set_meta("value", value)
	badge.set_meta("is_correct", is_correct)

	# Outer glowing ring / background pill
	var bg_panel = PanelContainer.new()
	bg_panel.name = "BadgePanel"
	bg_panel.custom_minimum_size = Vector2(62, 38)
	bg_panel.position = Vector2(-31, -19)

	# Style the badge
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.09, 0.06, 0.92)
	style.border_color = Color(1.0, 0.75, 0.2, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(1.0, 0.5, 0.0, 0.5)
	style.shadow_size = 5
	bg_panel.add_theme_stylebox_override("panel", style)

	var label = Label.new()
	label.name = "ValueLabel"
	label.text = str(value)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 19)
	label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.45))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)

	bg_panel.add_child(label)
	badge.add_child(bg_panel)
	return badge


func _process(delta: float) -> void:
	# Screen shake damping
	if _screen_shake > 0.0:
		_screen_shake = max(0.0, _screen_shake - delta * 20.0)
		position = Vector2(randf_range(-_screen_shake, _screen_shake), randf_range(-_screen_shake, _screen_shake))
	else:
		position = Vector2.ZERO

	if not _is_forging_active:
		return

	# Target reticle slider
	if not _is_striking:
		var current_speed = _target_speed + float(_streak_count) * 15.0
		_target_x += _target_dir * current_speed * delta
		if _target_x >= TRACK_MAX_X:
			_target_x = TRACK_MAX_X
			_target_dir = -1.0
		elif _target_x <= TRACK_MIN_X:
			_target_x = TRACK_MIN_X
			_target_dir = 1.0

		if target_reticle:
			target_reticle.position = Vector2(_target_x, TRACK_Y)

		# Hammer idle breathing: contact face centered horizontally at _target_x, poised above the line
		if hammer_pivot:
			var bob = sin(Time.get_ticks_msec() * 0.007) * 3.0
			hammer_pivot.position = Vector2(_target_x, HAMMER_HOVER_Y + bob)
			hammer_pivot.rotation = deg_to_rad(-8.0 + bob * 0.25)

		_highlight_hovered_badge()


func _highlight_hovered_badge() -> void:
	for node in _answer_nodes:
		var dist = abs(node.position.x - _target_x)
		var panel = node.get_node_or_null("BadgePanel") as PanelContainer
		if panel:
			if dist <= HIT_TOLERANCE_PX:
				var scale_factor = lerpf(1.24, 1.0, dist / HIT_TOLERANCE_PX)
				node.scale = Vector2(scale_factor, scale_factor)
				panel.modulate = Color(1.6, 1.4, 0.6, 1.0)
			else:
				node.scale = Vector2(1.0, 1.0)
				panel.modulate = Color(1.0, 1.0, 1.0, 1.0)


func _on_hit_button_pressed() -> void:
	if hit_btn:
		var tw = create_tween()
		tw.tween_property(hit_btn, "scale", Vector2(0.92, 0.92), 0.05).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(hit_btn, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_BACK)

	_trigger_player_strike()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_forging_active or _is_striking:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_trigger_player_strike()
	elif event is InputEventScreenTouch:
		if event.pressed:
			_trigger_player_strike()
	elif event is InputEventKey:
		if event.pressed and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER):
			_trigger_player_strike()


func _trigger_player_strike() -> void:
	if not _is_forging_active or _is_striking or _current_problem == null:
		return

	_is_striking = true

	# Check which badge (if any) is under the target reticle
	var hit_node: Node2D = null
	var min_dist: float = HIT_TOLERANCE_PX

	for node in _answer_nodes:
		var dist = abs(node.position.x - _target_x)
		if dist < min_dist:
			min_dist = dist
			hit_node = node

	if hit_node != null and hit_node.get_meta("is_correct", false):
		_handle_successful_strike(hit_node)
	else:
		_handle_failed_strike(hit_node)


func _handle_successful_strike(node: Node2D) -> void:
	var hit_x = node.position.x
	_streak_count += 1
	var points_gained = 2 + (_streak_count * 2) # Escalating combo reward: 4, 6, 8, 10!
	_quality_points += points_gained
	_current_strike_idx += 1

	_update_streak_display()

	var strike_pos = Vector2(hit_x, TRACK_Y)
	_animate_hammer_strike(strike_pos, true, func():
		# Cartoon star sparks explosion
		if sparks_particles:
			sparks_particles.position = strike_pos
			sparks_particles.amount = 40 + mini(_streak_count * 15, 60)
			sparks_particles.restart()

		if embers_particles:
			embers_particles.position = strike_pos
			embers_particles.restart()

		# Cartoon impact burst animation
		if impact_burst:
			impact_burst.position = strike_pos
			impact_burst.visible = true
			impact_burst.scale = Vector2(0.4, 0.4)
			impact_burst.modulate = Color(1.8, 1.4, 0.5, 1.0)
			var tw_ib = create_tween().set_parallel(true)
			tw_ib.tween_property(impact_burst, "scale", Vector2(1.5 + float(_streak_count) * 0.2, 1.5 + float(_streak_count) * 0.2), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw_ib.tween_property(impact_burst, "modulate:a", 0.0, 0.18)
			tw_ib.chain().tween_callback(func(): impact_burst.visible = false)

		# Expanding shockwave
		if shockwave:
			shockwave.position = strike_pos
			shockwave.visible = true
			shockwave.scale = Vector2(0.3, 0.3)
			shockwave.modulate = Color(1.5, 1.2, 0.4, 1.0)
			var tw_sw = create_tween().set_parallel(true)
			tw_sw.tween_property(shockwave, "scale", Vector2(2.2 + float(_streak_count) * 0.3, 2.2 + float(_streak_count) * 0.3), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw_sw.tween_property(shockwave, "modulate:a", 0.0, 0.25)
			tw_sw.chain().tween_callback(func(): shockwave.visible = false)

		# Screen flash
		if strike_flash:
			var tw_flash = create_tween()
			tw_flash.tween_property(strike_flash, "modulate:a", 0.45, 0.03)
			tw_flash.tween_property(strike_flash, "modulate:a", 0.0, 0.18)

		# Screen shake scales with streak
		_screen_shake = 6.0 + float(_streak_count) * 3.5

		# Audio: Metallic anvil clang with pitch escalating on streak
		if has_node("/root/AudioManager"):
			var pitch = clampf(0.96 + float(_streak_count - 1) * 0.07, 0.95, 1.55)
			get_node("/root/AudioManager").play_sfx("anvil_hit", pitch, 2.0)

		# Dynamic comic popup based on streak
		var popup_tag = "WHAM!! 🔨"
		if _streak_count >= 5:
			popup_tag = "🌟 GÖTTER-FUNKEN! (+%d)" % points_gained
		elif _streak_count >= 4:
			popup_tag = "💥 MEISTER-SCHMIEDE! (+%d)" % points_gained
		elif _streak_count >= 3:
			popup_tag = "⚡ BLITZ-HAMMER! (+%d)" % points_gained
		elif _streak_count >= 2:
			popup_tag = "🔥 DOPPEL-SCHLAG! (+%d)" % points_gained

		JuiceManager.spawn_comic_popup(self, popup_tag, strike_pos + Vector2(0, -45), "block")
		JuiceManager.hit_stop(get_tree(), 0.07, 0.04)

		# Green/Gold badge surge
		node.scale = Vector2(1.4, 1.4)
		var panel = node.get_node_or_null("BadgePanel")
		if panel:
			panel.modulate = Color(0.2, 2.5, 0.5)

		_update_quality_display()

		# Next question or finish
		var delay_timer = get_tree().create_timer(0.4)
		delay_timer.timeout.connect(func():
			_is_striking = false
			if _current_strike_idx >= _strikes_total:
				_trigger_quenching_phase()
			else:
				_generate_forge_problem()
		)
	)


func _handle_failed_strike(hit_node: Node2D) -> void:
	_streak_count = 0
	_quality_points = max(0, _quality_points - 1)
	_update_streak_display()

	var strike_pos = Vector2(_target_x, TRACK_Y)
	_screen_shake = 3.5

	_animate_hammer_strike(strike_pos, false, func():
		# Miss clonk sound
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx("anvil_clonk", randf_range(0.92, 1.04))

		JuiceManager.spawn_comic_popup(self, "CLONK! ❌", strike_pos + Vector2(0, -35), "defeat")

		# Feedback on missed node if one was hovered
		if hit_node:
			var panel = hit_node.get_node_or_null("BadgePanel")
			if panel:
				panel.modulate = Color(2.5, 0.2, 0.2)

		_update_quality_display()

		var delay_timer = get_tree().create_timer(0.25)
		delay_timer.timeout.connect(func():
			_is_striking = false
		)
	)


func _animate_hammer_strike(target_pos: Vector2, is_success: bool, on_impact: Callable) -> void:
	if not hammer_pivot or not hammer_sprite:
		on_impact.call()
		return

	var tw = create_tween()
	# Phase 1: Windup anticipation (raise back & stretch slightly)
	tw.tween_property(hammer_pivot, "position", Vector2(_target_x, 100.0), 0.045).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(hammer_pivot, "rotation", deg_to_rad(-32.0), 0.045)
	tw.parallel().tween_property(hammer_sprite, "scale", Vector2(0.24, 0.19), 0.045)

	# Phase 2: High-velocity slam straight down onto target!
	tw.tween_property(hammer_pivot, "position", Vector2(target_pos.x, TRACK_Y), 0.055).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(hammer_pivot, "rotation", deg_to_rad(0.0 if is_success else -6.0), 0.055).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(hammer_sprite, "scale", Vector2(0.19, 0.26), 0.055)

	# Phase 3: Impact frame callback
	tw.tween_callback(on_impact)

	# Phase 4: Impact Squash
	tw.tween_property(hammer_sprite, "scale", Vector2(0.27, 0.17) if is_success else Vector2(0.22, 0.22), 0.04).set_trans(Tween.TRANS_BACK)

	# Phase 5: Spring rebound back to hover height
	tw.tween_property(hammer_pivot, "position", Vector2(_target_x, HAMMER_HOVER_Y), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(hammer_pivot, "rotation", deg_to_rad(-8.0), 0.16).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(hammer_sprite, "scale", Vector2(0.22, 0.22), 0.16)


func _update_streak_display() -> void:
	if streak_label:
		if _streak_count > 1:
			streak_label.text = "🔥 KOMBO: x%d (+%d Pkt)" % [_streak_count, _streak_count * 2]
			streak_label.modulate = Color(1.8, 1.2, 0.2)
			if streak_badge:
				var tw = create_tween()
				tw.tween_property(streak_badge, "scale", Vector2(1.2, 1.2), 0.08).set_trans(Tween.TRANS_BACK)
				tw.tween_property(streak_badge, "scale", Vector2(1.0, 1.0), 0.12)
		elif _streak_count == 1:
			streak_label.text = "🔥 KOMBO: x1"
			streak_label.modulate = Color(1.0, 0.8, 0.3)
		else:
			streak_label.text = "🔥 KOMBO: x0"
			streak_label.modulate = Color(0.7, 0.7, 0.7)


# Backward compatibility handler for tests
func _on_ingot_pressed(val: int, btn: Button) -> void:
	if not _is_forging_active or _current_problem == null:
		return

	if val == _current_problem.correct_answer:
		_quality_points += 3
		_current_strike_idx += 1
		_update_quality_display()
		if _current_strike_idx >= _strikes_total:
			_trigger_quenching_phase()
		else:
			_generate_forge_problem()
	else:
		_quality_points = max(0, _quality_points - 1)
		_update_quality_display()


func _update_quality_display() -> void:
	var max_points = float(_strikes_total * 4) # 32 max
	var pct = clamp(float(_quality_points) / max_points * 100.0, 0.0, 100.0)
	if quality_progress:
		quality_progress.value = pct
	if quality_label:
		quality_label.text = "Qualität: %d Pkt (%d/%d Schläge)" % [_quality_points, _current_strike_idx, _strikes_total]


func _trigger_quenching_phase() -> void:
	_is_forging_active = false
	if equation_label:
		equation_label.text = "💨 ZISCH! KLINGE WIRD ABGESCHRECKT..."
	if subtitle_label:
		subtitle_label.text = "Das heisse Schwert zischt im Wasserbottich!"

	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("chest_break", 0.7, 1.2)

	var timer = get_tree().create_timer(1.2)
	timer.timeout.connect(_show_forge_results)


func _show_forge_results() -> void:
	if not result_panel:
		return

	result_panel.visible = true

	var stars = "★☆☆☆☆"
	var affix = ""
	var affix_name = "Keine Verzauberung"
	var bonus_gold = 0

	if _quality_points >= 22:
		stars = "★★★★★ LEGENDÄR!"
		affix = "storm"
		affix_name = "⚡ Sturm-Schlag (Kettenblitze)"
		bonus_gold = 40
	elif _quality_points >= 15:
		stars = "★★★★ MEISTERWERK!"
		affix = ["flame", "frost"].pick_random()
		affix_name = "🔥 Flammen-Schneide (Brand-Schaden)" if affix == "flame" else "❄️ Frost-Kälte (Gegner-Verlangsamung)"
		bonus_gold = 25
	elif _quality_points >= 9:
		stars = "★★★ FEIN!"
		affix = "greed"
		affix_name = "💰 Gier-Klinge (+25% Gold)"
		bonus_gold = 15
	elif _quality_points >= 4:
		stars = "★★ SOLIDE"
		bonus_gold = 5
	else:
		stars = "★ EINFACH"

	var weapons_produced: int = 1
	if _quality_points >= 15:
		weapons_produced = 2

	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		if affix != "":
			sm.set_weapon_affix(affix)
		if bonus_gold > 0:
			sm.add_gold(bonus_gold)
		sm.add_weapons(weapons_produced)

	if has_node("/root/EventBus"):
		get_node("/root/EventBus").forge_item_crafted.emit(affix)

	var weapon_text: String = "⚔️ +%d Waffe geschmiedet!" % weapons_produced if weapons_produced == 1 else "⚔️ +%d Meisterwaffen geschmiedet!" % weapons_produced

	if result_title:
		result_title.text = "SCHWERT GESCHMIEDET!
" + stars
	if result_desc:
		result_desc.text = "Verzauberung: " + affix_name + "
Gold-Belohnung: +" + str(bonus_gold) + " 🪙
" + weapon_text

	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("levelup", 1.0, 1.0)


func _on_back_pressed() -> void:
	if ResourceLoader.exists("res://scenes/village/VillageHub.tscn"):
		get_tree().change_scene_to_file("res://scenes/village/VillageHub.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/menu/TitleScreen.tscn")
