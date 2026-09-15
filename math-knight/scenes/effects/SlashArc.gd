extends Node2D

var slash_color: Color = Color(0.3, 1.0, 1.0, 1.0)
var arc_radius: float = 52.0
var weapon_type: String = "sword_iron"
var _slash_texture: Texture2D = null


func setup(pos: Vector2, rot: float = 0.0, col: Color = Color(0.3, 1.0, 1.0), weapon_id: String = "") -> void:
	position = pos
	rotation = rot
	weapon_type = weapon_id
	if weapon_type.is_empty() and is_inside_tree() and has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		weapon_type = sm.equipped_cosmetics.get("sword", "sword_iron")

	if ResourceLoader.exists("res://assets/sprites/effects/slash_arc.png"):
		_slash_texture = load("res://assets/sprites/effects/slash_arc.png")

	match weapon_type:
		"sword_flame":
			slash_color = Color(1.0, 0.45, 0.1)
		"sword_frost":
			slash_color = Color(0.2, 0.85, 1.0)
		"sword_gold":
			slash_color = Color(1.0, 0.88, 0.25)
		"sword_lightsaber":
			slash_color = Color(0.1, 1.0, 0.85)
		"sword_pan":
			slash_color = Color(1.0, 0.9, 0.5)
		_:
			slash_color = col

	scale = Vector2(0.4, 0.4)

	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.8, 1.8), 0.18) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.18) \
		.set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)


func _draw() -> void:
	if _slash_texture:
		var w := 96.0
		var h := 96.0
		var rect := Rect2(-w * 0.5, -h * 0.5, w, h)
		draw_texture_rect(_slash_texture, rect, false, slash_color)
	else:
		var outer_points: PackedVector2Array = []
		var count: int = 16
		for i in range(count):
			var t: float = float(i) / float(count - 1)
			var angle: float = deg_to_rad(-85.0 + (t * 170.0))
			outer_points.append(Vector2(-cos(angle) * arc_radius, sin(angle) * arc_radius * 0.82))
		draw_polyline(outer_points, slash_color, 8.0, true)
		draw_polyline(outer_points, Color.WHITE, 3.5, true)
