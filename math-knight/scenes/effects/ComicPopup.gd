extends Node2D
class_name ComicPopup

## Floating comic-style onomatopoeia banner ("POW!", "CLANG!", "WHOOSH!", "BLITZ!").
## Provides juicy comic-book feedback for attacks, criticals, dodges, and defeats.

@onready var label: Label = $Label
@onready var particles: CPUParticles2D = $Particles

var _text: String = "POW!"
var _color: Color = Color("#ffd700")
var _outline_color: Color = Color("#181425")
var _archetype: String = "attack"


func setup(tag: String, pos: Vector2, archetype: String = "attack") -> void:
	_text = tag
	position = pos
	_archetype = archetype

	match archetype:
		"blitz":
			_color = Color("#00ffff")
			_outline_color = Color("#051e3e")
		"crit", "krrrang":
			_color = Color("#ff2a6d")
			_outline_color = Color("#2b0938")
		"cleave":
			_color = Color("#ff7700")
			_outline_color = Color("#3a1005")
		"dodge", "whoosh":
			_color = Color("#a6e3e9")
			_outline_color = Color("#112d4e")
		"block", "clang":
			_color = Color("#f4e04d")
			_outline_color = Color("#222831")
		"defeat", "poof":
			_color = Color("#b388ff")
			_outline_color = Color("#1f1435")
		_: # Standard attack: "pow", "thwack"
			_color = Color("#ffe033")
			_outline_color = Color("#2c1810")

	call_deferred("_start_animation")


func _start_animation() -> void:
	if label:
		label.text = _text
		label.add_theme_color_override("font_color", _color)
		label.add_theme_color_override("font_outline_color", _outline_color)

	if particles:
		particles.color = _color
		particles.emitting = true

	# Randomize slight comic tilt angle
	rotation = randf_range(-0.18, 0.18)
	scale = Vector2(0.2, 0.2)

	var drift_x: float = randf_range(-20.0, 20.0)
	var tween: Tween = create_tween().set_parallel(true)

	# 1. Comic explosive pop
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.07) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.14).set_delay(0.07) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# 2. Float upward with gentle drift
	tween.tween_property(self, "position:y", position.y - 45.0, 0.65) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:x", position.x + drift_x, 0.65) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# 3. Fade out
	tween.tween_property(self, "modulate:a", 0.0, 0.25).set_delay(0.35)

	tween.chain().tween_callback(queue_free)
