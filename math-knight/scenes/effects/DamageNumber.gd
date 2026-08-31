extends Node2D

var value_text: String = ""
var color: Color = Color.GOLD

@onready var label: Label = $Label
@onready var sparkles: CPUParticles2D = $Sparkles


func setup(text: String, pos: Vector2, col: Color = Color.GOLD) -> void:
	value_text = text
	position = pos
	color = col
	call_deferred("_start_animation")


func _start_animation() -> void:
	if label:
		label.text = value_text
		label.add_theme_color_override("font_color", color)
		if value_text.length() > 6:
			label.add_theme_font_size_override("font_size", 20)
		else:
			label.add_theme_font_size_override("font_size", 28)

	if sparkles:
		sparkles.emitting = true

	# Punchy explosive scale bounce + float up and drift
	scale = Vector2(0.2, 0.2)
	rotation = randf_range(-0.15, 0.15)
	
	var drift_x: float = randf_range(-25.0, 25.0)
	var tween: Tween = create_tween().set_parallel(true)
	
	# 1. Scale explosion to 1.6 then settle to 1.0
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.08) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.18).set_delay(0.08) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# 2. Float upwards with horizontal drift
	tween.tween_property(self, "position:y", position.y - 55.0, 0.75) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:x", position.x + drift_x, 0.75) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# 3. Fade out
	tween.tween_property(self, "modulate:a", 0.0, 0.35).set_delay(0.40)
	
	tween.chain().tween_callback(queue_free)
