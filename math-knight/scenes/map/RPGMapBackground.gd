extends Control
class_name RPGMapBackground
## Cartoon fantasy treasure map background for Math Knight.

var _parchment_texture: Texture2D = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists("res://assets/sprites/map/map_parchment_bg.png"):
		_parchment_texture = load("res://assets/sprites/map/map_parchment_bg.png")
	queue_redraw()


func _draw() -> void:
	var w: float = size.x if size.x > 0 else 640.0
	var h: float = size.y if size.y > 0 else 360.0

	if _parchment_texture:
		draw_texture_rect(_parchment_texture, Rect2(0, 0, w, h), false)
	else:
		draw_rect(Rect2(0, 0, w, h), Color("#f0e8d0"))
