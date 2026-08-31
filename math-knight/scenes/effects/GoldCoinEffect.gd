extends Node2D
class_name GoldCoinEffect

var coins: Array[Dictionary] = []
var target_pos: Vector2 = Vector2(580, 15)
var finished_coins: int = 0
var total_coins: int = 0

static func spawn_coins(parent: Node, start_pos: Vector2, amount: int) -> GoldCoinEffect:
	var scene = load("uid://cdg3k8m2n8q4z") as PackedScene
	var effect: GoldCoinEffect
	if scene:
		effect = scene.instantiate()
	else:
		effect = GoldCoinEffect.new()
	parent.add_child(effect)
	effect.setup(start_pos, amount)
	return effect

func setup(start_pos: Vector2, amount: int, in_target_pos: Vector2 = Vector2(580, 15)):
	global_position = Vector2.ZERO # Operate in global space relative to parent
	target_pos = in_target_pos
	total_coins = mini(amount, 10)
	
	if total_coins == 0:
		queue_free()
		return
		
	for i in range(total_coins):
		var coin = {
			"pos": start_pos,
			"scale": 0.0,
			"trail": []
		}
		coins.append(coin)
		
		# Delay each coin
		var delay = i * 0.1
		
		# Pop out target
		var pop_pos = start_pos + Vector2(randf_range(-40, 40), randf_range(-60, -20))
		
		var coin_tween = create_tween()
		coin_tween.tween_interval(delay)
		# Pop phase
		coin_tween.tween_property(coin, "pos", pop_pos, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		coin_tween.parallel().tween_property(coin, "scale", 1.0, 0.2)
		
		# Wait slightly at peak
		coin_tween.tween_interval(0.1)
		
		# Fly phase
		coin_tween.tween_property(coin, "pos", target_pos, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		
		coin_tween.tween_callback(func(): _on_coin_reached_target(coin))
		
func _process(_delta):
	# Update trails
	for coin in coins:
		if coin.scale > 0:
			coin.trail.push_front(coin.pos)
			if coin.trail.size() > 5:
				coin.trail.pop_back()
	queue_redraw()

func _on_coin_reached_target(coin: Dictionary):
	coin.scale = 0.0 # hide
	coin.trail.clear()
	finished_coins += 1
	if finished_coins >= total_coins:
		queue_free()

func _draw():
	for coin in coins:
		if coin.scale <= 0.0:
			continue
			
		# Draw trail
		if coin.trail.size() > 1:
			var pts = PackedVector2Array(coin.trail)
			draw_polyline(pts, Color(1.0, 0.9, 0.4, 0.5), 2.0, true)
			
		# Draw coin
		var r = 6.0 * coin.scale
		draw_circle(coin.pos, r, Color(0.2, 0.1, 0.0))
		draw_circle(coin.pos, r * 0.8, Color(0.9, 0.7, 0.1))
		draw_circle(coin.pos, r * 0.5, Color(1.0, 0.9, 0.4))
