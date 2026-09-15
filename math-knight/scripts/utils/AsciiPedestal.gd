class_name AsciiPedestal
extends Control
## ═══════════════════════════════════════════════════════════════════════════
## Cartoon Pedestal — Medieval Stone & Gold Dais for Math Knight
## ═══════════════════════════════════════════════════════════════════════════

@export var radius_x: float = 46.0
@export var radius_y: float = 14.0
@export var base_height: float = 10.0

var _pedestal_texture: Texture2D = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists("res://assets/sprites/ui/knight_pedestal.png"):
		_pedestal_texture = load("res://assets/sprites/ui/knight_pedestal.png")
	queue_redraw()


func _draw() -> void:
	if _pedestal_texture:
		var rect := Rect2(0, 0, size.x, size.y)
		draw_texture_rect(_pedestal_texture, rect, false)
	else:
		draw_circle(size * 0.5, min(size.x, size.y) * 0.45, Color(0.25, 0.22, 0.2))
