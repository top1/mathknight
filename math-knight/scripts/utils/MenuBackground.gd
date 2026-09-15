class_name MenuBackground
extends Control
## Cartoon medieval kingdom scenery background for Math Knight menus.

@export_enum("default", "loading", "map") var variant: String = "default"
@export var theme_color: Color = Color.WHITE

var _bg_texture: Texture2D = null
var _t: float = 0.0
var _sparkles: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists("res://assets/sprites/ui/menu_background.png"):
		_bg_texture = load("res://assets/sprites/ui/menu_background.png")

	# Ambient golden sparkles
	for i in range(12):
		_sparkles.append({
			"pos": Vector2(randf() * 640.0, randf() * 360.0),
			"spd": randf_range(10.0, 25.0),
			"sz": randf_range(1.5, 3.0),
			"ph": randf() * TAU
		})


func _process(delta: float) -> void:
	_t += delta
	for s in _sparkles:
		s.pos.y -= s.spd * delta
		s.pos.x += sin(_t * 1.5 + s.ph) * 8.0 * delta
		if s.pos.y < -10.0:
			s.pos.y = 370.0
			s.pos.x = randf() * 640.0
	queue_redraw()


func _draw() -> void:
	var w: float = size.x if size.x > 0 else 640.0
	var h: float = size.y if size.y > 0 else 360.0

	if _bg_texture:
		draw_texture_rect(_bg_texture, Rect2(0, 0, w, h), false)
	else:
		draw_rect(Rect2(0, 0, w, h), Color("#3b7dd8"))

	# Soft ambient golden dust
	for s in _sparkles:
		var a: float = 0.3 + sin(_t * 2.0 + s.ph) * 0.2
		draw_circle(s.pos, s.sz, Color(1.0, 0.9, 0.4, a))
