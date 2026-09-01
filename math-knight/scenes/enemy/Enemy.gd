extends Node2D
class_name Enemy
## An enemy character (Grumpy Orc) that walks from the left toward the knight.
## When reaching the knight, stays and attacks repeatedly.
## Displays a math problem on its badge.

@export var speed: float = 40.0
@export var hp: float = 1.0
@export var attack_damage: float = 1.0
@export var attack_interval: float = 2.0

var problem: MathProblem
var problem_text: String = ""
var answer_value: int = 0
var target_x: float = 500.0
var state: String = "queued"  # queued, walking, attacking, hurt, defeated
var _base_y: float = 0.0
var _walk_time: float = 0.0

# === Elite Enemy Support ===
var is_elite: bool = false
var problems_list: Array[MathProblem] = []
var current_problem_idx: int = 0
var total_problems_count: int = 1

signal enemy_reached_knight(enemy: Node2D)
signal enemy_defeated(enemy: Node2D)

@onready var attack_timer: Timer = $AttackTimer
@onready var shield_label: Label = $ShieldLabel
@onready var sprite: Sprite2D = $Sprite
@onready var ascii_entity: AsciiEntity = $AsciiEntity

var enemy_type_name: String = "goblin"


func _ready() -> void:
	_base_y = position.y
	if shield_label and problem_text != "":
		_update_label_display()
	_start_idle_anim()


func setup(prob: MathProblem, spd: float, dmg: float = 1.0, interval: float = 2.0, chosen_type: String = "") -> void:
	is_elite = false
	problem = prob
	problems_list = [prob]
	current_problem_idx = 0
	total_problems_count = 1
	problem_text = prob.question_text
	answer_value = prob.correct_answer
	speed = spd
	hp = 1.0
	attack_damage = dmg
	attack_interval = interval

	# Pick enemy type if not specified (goblin, skeleton, slime)
	if chosen_type != "":
		enemy_type_name = chosen_type
	elif enemy_type_name == "goblin" and randf() < 0.65:
		var types: Array[String] = ["goblin", "skeleton", "slime"]
		enemy_type_name = types[randi() % types.size()]

	if is_inside_tree():
		_apply_ascii_config()
		_update_label_display()


func setup_elite(probs: Array[MathProblem], spd: float, dmg: float = 1.5, interval: float = 1.8, chosen_type: String = "") -> void:
	is_elite = true
	problems_list = probs
	current_problem_idx = 0
	total_problems_count = probs.size()
	problem = probs[0]
	problem_text = problem.question_text
	answer_value = problem.correct_answer
	speed = spd
	hp = float(total_problems_count)
	attack_damage = dmg
	attack_interval = interval
	scale = Vector2(1.28, 1.28)

	if chosen_type != "":
		enemy_type_name = chosen_type
	else:
		var types: Array[String] = ["goblin", "skeleton", "slime"]
		enemy_type_name = types[randi() % types.size()]

	if is_inside_tree():
		_apply_ascii_config()
		_update_label_display()


func _apply_ascii_config() -> void:
	if ascii_entity:
		ascii_entity.entity_type = enemy_type_name
		ascii_entity.is_elite = is_elite
		ascii_entity.facing_direction = 1.0


func _update_label_display() -> void:
	_apply_ascii_config()
	if ascii_entity:
		var display_eq: String = problem_text
		if is_elite:
			var pips = ""
			for i in range(total_problems_count):
				pips += "◆" if i >= current_problem_idx else "◇"
			display_eq = pips + " " + problem_text
		ascii_entity.set_equation(display_eq, Color("#ffd600") if not is_elite else Color("#ffd600"))

	if shield_label:
		if is_elite:
			var pips = ""
			for i in range(total_problems_count):
				pips += "◆" if i >= current_problem_idx else "◇"
			shield_label.text = pips + "\n" + problem_text
		else:
			shield_label.text = problem_text
		_adjust_label_size()


func _adjust_label_size() -> void:
	if not shield_label:
		return
	if problem_text.length() > 10:
		shield_label.add_theme_font_size_override("font_size", 9)
	elif problem_text.length() > 7:
		shield_label.add_theme_font_size_override("font_size", 10)
	elif problem_text.length() > 5:
		shield_label.add_theme_font_size_override("font_size", 12)
	else:
		shield_label.add_theme_font_size_override("font_size", 14)


func set_focus(is_focused: bool) -> void:
	var target_mod: Color
	if is_focused:
		target_mod = Color(1.15, 0.85, 1.3, 1.0) if is_elite else Color.WHITE
		if shield_label:
			shield_label.modulate = Color(1.2, 1.2, 1.0, 1.0)
	else:
		target_mod = Color(0.55, 0.55, 0.65, 0.6)
		if shield_label:
			shield_label.modulate = Color(0.7, 0.7, 0.7, 0.6)

	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate", target_mod, 0.2)


func activate() -> void:
	state = "walking"
	set_focus(true)


func _process(delta: float) -> void:
	match state:
		"walking":
			_walk_time += delta
			position.x += speed * delta
			if enemy_type_name == "slime":
				position.y = _base_y
			else:
				position.y = _base_y + sin(_walk_time * 8.0) * 1.5

			if position.x >= target_x:
				position.x = target_x
				position.y = _base_y
				_start_attacking()

		"queued":
			_walk_time += delta
			if enemy_type_name == "slime":
				position.y = _base_y
			else:
				position.y = _base_y + sin(_walk_time * 2.0) * 1.0


func _start_attacking() -> void:
	state = "attacking"
	attack_timer.wait_time = attack_interval
	attack_timer.start()
	enemy_reached_knight.emit(self)


func _on_attack_timer_timeout() -> void:
	if state != "attacking" or GameManager.state == GameManager.GameState.GAME_OVER:
		return

	EventBus.enemy_attacks_knight.emit(attack_damage)

	var tween: Tween = create_tween()
	tween.tween_property(self, "position:x", position.x + 14.0, 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:x", target_x, 0.15) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func take_hit(damage: float) -> void:
	if state == "defeated":
		return

	# If Elite enemy has more problems remaining, advance to next problem!
	if is_elite and current_problem_idx + 1 < total_problems_count:
		current_problem_idx += 1
		hp -= 1.0
		problem = problems_list[current_problem_idx]
		problem_text = problem.question_text
		answer_value = problem.correct_answer

		_update_label_display()
		GameManager.current_problem = problem
		EventBus.problem_presented.emit(problem)

		# Visual hit flash & knockback
		modulate = Color(3.0, 3.0, 3.0)
		var flash_tween: Tween = create_tween()
		flash_tween.tween_property(self, "modulate", Color(1.15, 0.85, 1.3), 0.15)

		var knockback_tween: Tween = create_tween()
		knockback_tween.tween_property(self, "position:x", position.x - 20.0, 0.06)
		knockback_tween.tween_property(self, "position:x", position.x, 0.12)
		return

	# Final hit (or standard enemy)
	hp -= damage

	modulate = Color(3.0, 3.0, 3.0)
	var flash_tween: Tween = create_tween()
	flash_tween.tween_property(self, "modulate", Color.WHITE, 0.1)

	var knockback_tween: Tween = create_tween()
	knockback_tween.tween_property(self, "position:x", position.x - 15.0, 0.05)
	knockback_tween.tween_property(self, "position:x", position.x, 0.1)

	if hp <= 0.0:
		defeat()
	else:
		state = "hurt"
		var resume_tween: Tween = create_tween()
		resume_tween.tween_interval(0.2)
		resume_tween.tween_callback(func():
			if state == "hurt":
				if position.x >= target_x - 5.0:
					state = "attacking"
					attack_timer.start()
				else:
					state = "walking"
		)


func defeat() -> void:
	state = "defeated"
	attack_timer.stop()
	enemy_defeated.emit(self)

	# Trigger numerical ASCII splatter explosion!
	if ascii_entity:
		ascii_entity.trigger_splatter()
		# Wait for splatter particles to expand & fade
		var timer = get_tree().create_timer(1.2)
		timer.timeout.connect(queue_free)
	else:
		var tween: Tween = create_tween().set_parallel(true)
		tween.tween_property(self, "scale", Vector2.ZERO, 0.3) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_property(self, "position:y", position.y - 20.0, 0.3)
		tween.tween_property(self, "modulate:a", 0.0, 0.25)
		tween.chain().tween_callback(queue_free)


func _start_idle_anim() -> void:
	_walk_time = randf_range(0.0, TAU)
