extends Control
class_name BlacksmithForge

## The Blacksmith's Forge mini-game.
## 4/4 musical rhythm anvil hammer, furnace calculations with glowing runic ingots,
## and weapon affix forging (Flame, Frost, Greed, Storm).

@onready var furnace_label: Label = $MainBox/FurnaceArea/EquationLabel
@onready var rhythm_label: Label = $MainBox/FurnaceArea/RhythmLabel
@onready var beat_indicators: HBoxContainer = $MainBox/FurnaceArea/BeatIndicators
@onready var ingots_container: HBoxContainer = $MainBox/AnvilArea/IngotsContainer
@onready var hammer_icon: Label = $MainBox/AnvilArea/HammerVisual
@onready var sparks_particles: CPUParticles2D = $Sparks
@onready var quality_progress: ProgressBar = $MainBox/QualityBox/QualityBar
@onready var quality_label: Label = $MainBox/QualityBox/QualityLabel
@onready var result_panel: Panel = $ResultPanel
@onready var result_title: Label = $ResultPanel/VBox/Title
@onready var result_desc: Label = $ResultPanel/VBox/Desc
@onready var back_btn: Button = $TopBar/BackBtn

# 120 BPM: Beat = 0.5s, 4 beats per bar
const BPM: float = 120.0
const BEAT_DURATION: float = 60.0 / BPM # 0.5s
const HIT_TOLERANCE: float = 0.18 # seconds window around beat 4

var _current_beat: int = 0 # 0, 1, 2, 3 (beat 4 is index 3)
var _beat_timer: float = 0.0
var _strikes_total: int = 8
var _current_strike_idx: int = 0
var _quality_points: int = 0

var _current_problem: MathProblem = null
var _ingot_buttons: Array[Button] = []
var _is_forging_active: bool = false
var _has_hit_this_measure: bool = false


func _ready() -> void:
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)

	if result_panel:
		result_panel.visible = false
		var close_btn = result_panel.get_node_or_null("VBox/ClaimBtn")
		if close_btn:
			close_btn.pressed.connect(_on_back_pressed)

	start_forging_session()


func start_forging_session() -> void:
	_is_forging_active = true
	_current_beat = 0
	_beat_timer = 0.0
	_current_strike_idx = 0
	_quality_points = 0
	_has_hit_this_measure = false

	if result_panel:
		result_panel.visible = false

	_update_quality_display()
	_generate_forge_problem()


func _generate_forge_problem() -> void:
	if not has_node("/root/MathEngine"):
		return
	var me = get_node("/root/MathEngine")
	# Forge features multiplication and addition calculations
	_current_problem = me.generate_problem()

	if furnace_label:
		furnace_label.text = _current_problem.question_text + " = ?"

	# Build 4 candidate answers (1 correct + 3 distractors)
	var correct = _current_problem.correct_answer
	var candidates: Array[int] = [correct]

	var offsets = [-2, -1, 1, 2, 10, -10]
	offsets.shuffle()
	for off in offsets:
		var cand = max(1, correct + off)
		if not candidates.has(cand):
			candidates.append(cand)
		if candidates.size() >= 4:
			break

	while candidates.size() < 4:
		candidates.append(candidates.size() + correct + 3)

	candidates.shuffle()
	_setup_ingot_buttons(candidates)


func _setup_ingot_buttons(candidates: Array[int]) -> void:
	for child in ingots_container.get_children():
		child.queue_free()
	_ingot_buttons.clear()

	for val in candidates:
		var btn = Button.new()
		btn.text = str(val)
		btn.custom_minimum_size = Vector2(75, 45)
		btn.add_theme_font_size_override("font_size", 16)
		btn.add_theme_color_override("font_color", Color("#ffd700"))
		btn.pressed.connect(_on_ingot_pressed.bind(val, btn))
		ingots_container.add_child(btn)
		_ingot_buttons.append(btn)


func _process(delta: float) -> void:
	if not _is_forging_active:
		return

	_beat_timer += delta
	if _beat_timer >= BEAT_DURATION:
		_beat_timer -= BEAT_DURATION
		_advance_beat()


func _advance_beat() -> void:
	_current_beat = (_current_beat + 1) % 4
	_update_beat_indicators()

	if _current_beat == 3:
		# Beat 4: Downbeat! Anvil CLANG!
		_has_hit_this_measure = false
		if hammer_icon:
			var tw = create_tween()
			tw.tween_property(hammer_icon, "position:y", 22.0, 0.08).set_trans(Tween.TRANS_BACK)
			tw.tween_property(hammer_icon, "position:y", 0.0, 0.2).set_trans(Tween.TRANS_SINE)

		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx("click", 0.8, 1.0)
	else:
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx("click", 1.4, 0.4)


func _update_beat_indicators() -> void:
	if not beat_indicators:
		return
	var dots = beat_indicators.get_children()
	for i in range(dots.size()):
		var dot = dots[i] as Label
		if i == _current_beat:
			dot.modulate = Color(1.5, 1.2, 0.2) if i == 3 else Color(0.3, 1.2, 1.5)
			dot.scale = Vector2(1.3, 1.3)
		else:
			dot.modulate = Color(0.4, 0.4, 0.5, 0.5)
			dot.scale = Vector2(1.0, 1.0)


func _on_ingot_pressed(val: int, btn: Button) -> void:
	if not _is_forging_active or _current_problem == null:
		return

	var is_correct = (val == _current_problem.correct_answer)
	# Check rhythm timing: is it close to beat 4 downbeat?
	# Beat 4 downbeat occurs when _current_beat == 3 and _beat_timer is near 0, OR _current_beat == 2 and _beat_timer is near end
	var is_on_beat: bool = false
	if _current_beat == 3 and (_beat_timer <= HIT_TOLERANCE or _beat_timer >= BEAT_DURATION - HIT_TOLERANCE):
		is_on_beat = true
	elif _current_beat == 2 and (_beat_timer >= BEAT_DURATION - HIT_TOLERANCE):
		is_on_beat = true

	if is_correct:
		if is_on_beat:
			# PERFECT RHYTHM STRIKE!
			_quality_points += 3
			JuiceManager.spawn_comic_popup(self, "CLANG!", btn.global_position + Vector2(0, -30), "block")
			if sparks_particles:
				sparks_particles.global_position = btn.global_position
				sparks_particles.emitting = true
			if has_node("/root/AudioManager"):
				get_node("/root/AudioManager").play_sfx("sword_slash", 1.2, 1.5)
			JuiceManager.hit_stop(get_tree(), 0.066, 0.05)
		else:
			# Off-beat strike
			_quality_points += 1
			JuiceManager.spawn_comic_popup(self, "GUT!", btn.global_position + Vector2(0, -30), "attack")
			if has_node("/root/AudioManager"):
				get_node("/root/AudioManager").play_sfx("sword_slash", 0.9, 1.0)

		btn.modulate = Color(0.2, 1.5, 0.2)
		_current_strike_idx += 1
		_update_quality_display()

		if _current_strike_idx >= _strikes_total:
			_trigger_quenching_phase()
		else:
			_generate_forge_problem()
	else:
		# WRONG ANSWER
		_quality_points = max(0, _quality_points - 1)
		JuiceManager.spawn_comic_popup(self, "DANEBEN!", btn.global_position + Vector2(0, -30), "defeat")
		btn.modulate = Color(2.0, 0.3, 0.3)
		_update_quality_display()


func _update_quality_display() -> void:
	var pct = clamp(float(_quality_points) / 18.0 * 100.0, 0.0, 100.0)
	if quality_progress:
		quality_progress.value = pct
	if quality_label:
		quality_label.text = "Qualität: %d Punkte (%d/%d Schläge)" % [_quality_points, _current_strike_idx, _strikes_total]


func _trigger_quenching_phase() -> void:
	_is_forging_active = false
	if furnace_label:
		furnace_label.text = "💨 ZISCH! KLINGE WIRD ABGESCHRECKT..."

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

	if _quality_points >= 18:
		stars = "★★★★★ LEGENDÄR!"
		affix = "storm"
		affix_name = "⚡ Sturm-Schlag (Kettenblitze)"
		bonus_gold = 35
	elif _quality_points >= 13:
		stars = "★★★★ MEISTERWERK!"
		affix = ["flame", "frost"].pick_random()
		affix_name = "🔥 Flammen-Schneide (Brand-Schaden)" if affix == "flame" else "❄️ Frost-Kälte (Gegner-Verlangsamung)"
		bonus_gold = 20
	elif _quality_points >= 8:
		stars = "★★★ FEIN!"
		affix = "greed"
		affix_name = "💰 Gier-Klinge (+25% Gold)"
		bonus_gold = 10
	elif _quality_points >= 4:
		stars = "★★ SOLIDE"
		bonus_gold = 5
	else:
		stars = "★ EINFACH"

	# Save weapon affix
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		if affix != "":
			sm.set_weapon_affix(affix)
		if bonus_gold > 0:
			sm.add_gold(bonus_gold)

	if result_title:
		result_title.text = "SCHWERT GESCHMIEDET!\n" + stars
	if result_desc:
		result_desc.text = "Verzauberung: " + affix_name + "\nGold-Belohnung: +" + str(bonus_gold) + " 🪙"

	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("levelup", 1.0, 1.0)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/TitleScreen.tscn")