class_name BossHPBar
extends Control

@export var boss_name: String = "Boss"
@export var total_phases: int = 3
@export var current_phase: int = 1
@export var current_hp: float = 100.0
@export var max_phase_hp: float = 100.0

@onready var name_label: Label = $BossNameLabel

var time_elapsed: float = 0.0
var particles: Array[Dictionary] = []

func _ready() -> void:
	custom_minimum_size = Vector2(0, 35)

func _process(delta: float) -> void:
	time_elapsed += delta
	if current_phase == total_phases:
		queue_redraw()
	
	# Update particles
	var alive_particles: Array[Dictionary] = []
	for p in particles:
		p.pos += p.vel * delta
		p.vel.y += 200 * delta # Gravity
		p.life -= delta
		if p.life > 0:
			alive_particles.append(p)
	particles = alive_particles
	
	if particles.size() > 0:
		queue_redraw()

func setup(b_name: String, phases: int, hp_per_phase: float) -> void:
	boss_name = b_name
	if name_label:
		name_label.text = boss_name
	total_phases = phases
	current_phase = 1
	max_phase_hp = hp_per_phase
	current_hp = max_phase_hp
	queue_redraw()

func update_hp(phase: int, hp: float, max_hp: float) -> void:
	current_phase = phase
	current_hp = hp
	max_phase_hp = max_hp
	queue_redraw()

func on_phase_break(phase: int) -> void:
	# Spawn shatter particles
	for i in range(20):
		particles.append({
			"pos": Vector2(size.x / 2, size.y / 2),
			"vel": Vector2(randf_range(-150, 150), randf_range(-50, 50)),
			"color": _get_phase_color(phase),
			"life": randf_range(0.5, 1.0)
		})
	queue_redraw()

func show_bar() -> void:
	visible = true
	var tween = create_tween()
	modulate = Color(1, 1, 1, 0)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.5)

func hide_bar() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.5)
	tween.tween_callback(func(): visible = false)

func _get_phase_color(phase: int) -> Color:
	if phase == 1:
		return Color.GREEN
	elif phase == 2:
		return Color.YELLOW
	elif phase == 3:
		return Color.ORANGE
	else:
		return Color.RED

func _draw() -> void:
	var rect = Rect2(10, 20, size.x - 20, 10)
	
	# Background
	draw_rect(rect, Color(0.1, 0.1, 0.1, 1.0))
	
	# Border
	draw_rect(rect, Color(0.8, 0.6, 0.1, 1.0), false, 2.0)
	
	var segment_width = rect.size.x / total_phases
	
	# Fill logic
	for i in range(total_phases):
		var phase_index = i + 1
		var seg_rect = Rect2(rect.position.x + i * segment_width, rect.position.y, segment_width, rect.size.y)
		
		if phase_index < current_phase:
			# Empty
			pass
		elif phase_index == current_phase:
			# Partially filled
			var fill_width = segment_width * max(0.0, current_hp / max_phase_hp)
			var fill_rect = Rect2(seg_rect.position.x, seg_rect.position.y, fill_width, seg_rect.size.y)
			var phase_color = _get_phase_color(phase_index)
			if phase_index == total_phases:
				# Pulsing red
				phase_color = Color(1.0, 0.0, 0.0, 1.0).lerp(Color(0.5, 0.0, 0.0, 1.0), (sin(time_elapsed * 10.0) + 1.0) / 2.0)
			draw_rect(fill_rect, phase_color)
		else:
			# Full
			draw_rect(seg_rect, _get_phase_color(phase_index))
			
	# Draw dividers
	for i in range(1, total_phases):
		var x_pos = rect.position.x + i * segment_width
		draw_line(Vector2(x_pos, rect.position.y), Vector2(x_pos, rect.position.y + rect.size.y), Color(0, 0, 0, 1), 1.0)
		
	# Draw particles
	for p in particles:
		draw_rect(Rect2(p.pos, Vector2(3, 3)), p.color)
