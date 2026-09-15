class_name AsciiLoadingSpinner
extends Control
## Clean cartoon spinning loading indicator for Math Knight.

@export var radius: float = 16.0
@export var spin_speed: float = 4.0
@export var core_color: Color = Color("#f0b830") # Gold

var _t: float = 0.0
var _coin_texture: Texture2D = null


func _ready() -> void:
	custom_minimum_size = Vector2(radius * 2.5, radius * 2.5)
	if ResourceLoader.exists("res://assets/sprites/effects/coin_gold.png"):
		_coin_texture = load("res://assets/sprites/effects/coin_gold.png")


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	if _coin_texture:
		# Draw rotating bouncing coin
		var s := 1.0 + sin(_t * 6.0) * 0.15
		var w := 28.0 * s
		var h := 28.0 * s
		var rect := Rect2(center.x - w * 0.5, center.y - h * 0.5, w, h)
		draw_texture_rect(_coin_texture, rect, false)
	else:
		# 6 clean dots orbiting
		var dot_count := 6
		for i in range(dot_count):
			var angle := (float(i) / float(dot_count)) * TAU + _t * spin_speed
			var pos := center + Vector2(cos(angle), sin(angle)) * radius
			var a := float(i + 1) / float(dot_count)
			draw_circle(pos, 3.5, Color(core_color.r, core_color.g, core_color.b, a))
