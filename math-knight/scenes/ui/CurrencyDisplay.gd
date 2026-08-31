extends HBoxContainer
class_name CurrencyDisplay

@onready var gold_badge = $GoldBadge
@onready var diamond_badge = $DiamondBadge
@onready var gold_label = $GoldBadge/GoldRow/GoldLabel
@onready var diamond_label = $DiamondBadge/DiamondRow/DiamondLabel
@onready var gold_icon = $GoldBadge/GoldRow/GoldIcon
@onready var diamond_icon = $DiamondBadge/DiamondRow/DiamondIcon

func _ready():
	# Connect signals if EventBus exists
	if ClassDB.class_exists("EventBus") or Engine.has_singleton("EventBus"):
		var event_bus = get_node_or_null("/root/EventBus")
		if event_bus:
			if event_bus.has_signal("gold_changed"):
				event_bus.gold_changed.connect(_on_gold_changed)
			if event_bus.has_signal("diamonds_earned"):
				event_bus.diamonds_earned.connect(_on_diamonds_earned)
	
	setup_badges()
	
	gold_icon.draw.connect(_draw_gold_icon)
	diamond_icon.draw.connect(_draw_diamond_icon)

func setup_badges():
	var style_gold = StyleBoxFlat.new()
	style_gold.bg_color = Color(0.1, 0.05, 0.15, 0.9)
	style_gold.border_width_left = 2
	style_gold.border_width_top = 2
	style_gold.border_width_right = 2
	style_gold.border_width_bottom = 2
	style_gold.border_color = Color(0.9, 0.7, 0.1, 1)
	style_gold.corner_radius_top_left = 6
	style_gold.corner_radius_top_right = 6
	style_gold.corner_radius_bottom_left = 6
	style_gold.corner_radius_bottom_right = 6
	gold_badge.add_theme_stylebox_override("panel", style_gold)

	var style_diamond = style_gold.duplicate()
	style_diamond.border_color = Color(0.1, 0.8, 0.9, 1)
	diamond_badge.add_theme_stylebox_override("panel", style_diamond)
	
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	diamond_label.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0))

func update_gold(amount: int):
	gold_label.text = str(amount)
	bounce_node(gold_label)

func update_diamonds(amount: int):
	diamond_label.text = str(amount)
	bounce_node(diamond_label)

func _on_gold_changed(amount: int):
	update_gold(amount)

func _on_diamonds_earned(amount: int):
	update_diamonds(amount)

func bounce_node(node: Control):
	node.pivot_offset = node.size / 2.0
	var tween = create_tween()
	tween.tween_property(node, "scale", Vector2(1.5, 1.5), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _draw_gold_icon():
	var center = gold_icon.size / 2.0
	gold_icon.draw_circle(center, 6, Color(0.2, 0.1, 0.0))
	gold_icon.draw_circle(center, 5, Color(0.9, 0.7, 0.1))
	gold_icon.draw_circle(center, 3, Color(1.0, 0.9, 0.4))

func _draw_diamond_icon():
	var center = diamond_icon.size / 2.0
	var pts = PackedVector2Array([
		center + Vector2(0, -6),
		center + Vector2(5, 0),
		center + Vector2(0, 6),
		center + Vector2(-5, 0)
	])
	diamond_icon.draw_polygon(pts, PackedColorArray([Color(0.2, 0.8, 1.0)]))
	var inner_pts = PackedVector2Array([
		center + Vector2(0, -4),
		center + Vector2(3, 0),
		center + Vector2(0, 4),
		center + Vector2(-3, 0)
	])
	diamond_icon.draw_polygon(inner_pts, PackedColorArray([Color(0.6, 0.9, 1.0)]))
