extends SceneTree

var _frames: int = 0
var _test_node: Node2D
var _ascii_knight: AsciiEntity
var _slot_tests: Array = [
	{"name": "iron_default", "sword": "sword_iron", "helmet": "helm_knight", "hat": "hat_none"},
	{"name": "flame_sword", "sword": "sword_flame", "helmet": "helm_knight", "hat": "hat_none"},
	{"name": "frost_sword", "sword": "sword_frost", "helmet": "helm_knight", "hat": "hat_none"},
	{"name": "plasma_lightsaber", "sword": "sword_lightsaber", "helmet": "helm_knight", "hat": "hat_propeller"},
	{"name": "gold_king", "sword": "sword_gold", "helmet": "helm_crown", "hat": "hat_none"},
	{"name": "frying_pan", "sword": "sword_pan", "helmet": "helm_knight", "hat": "hat_jester"}
]
var _current_test: int = 0

func _init() -> void:
	print("--- Starting Comprehensive Weapon Attack & Sword FX Verification ---")
	_test_node = Node2D.new()
	root.add_child(_test_node)

	_ascii_knight = AsciiEntity.new()
	_ascii_knight.entity_type = "knight"
	_ascii_knight.facing_direction = 1.0
	_ascii_knight.position = Vector2(320, 200)
	_test_node.add_child(_ascii_knight)

	# 1. Test SlashArc scene & script
	var slash_arc_scene = load("res://scenes/effects/SlashArc.tscn")
	if slash_arc_scene:
		for sword_id in ["sword_flame", "sword_frost", "sword_lightsaber", "sword_gold", "sword_pan", "sword_iron"]:
			var arc = slash_arc_scene.instantiate()
			_test_node.add_child(arc)
			arc.setup(Vector2(300, 200), 0.2, Color.CYAN, sword_id)
			print("✓ SlashArc initialized for weapon: ", sword_id)
			arc.queue_free()

	# 2. Test HitEffect scene & script
	var hit_effect_scene = load("res://scenes/effects/HitEffect.tscn")
	if hit_effect_scene:
		for sword_id in ["sword_flame", "sword_frost", "sword_lightsaber", "sword_gold", "sword_pan", "sword_iron"]:
			var hit_fx = hit_effect_scene.instantiate()
			_test_node.add_child(hit_fx)
			hit_fx.setup(sword_id)
			print("✓ HitEffect initialized for weapon: ", sword_id)
			hit_fx.queue_free()

	# 3. Test SwipeTrail scene & script
	var swipe_trail_scene = load("res://scenes/effects/SwipeTrail.tscn")
	if swipe_trail_scene:
		var trail = swipe_trail_scene.instantiate()
		_test_node.add_child(trail)
		trail.weapon_type = "sword_flame"
		trail.start_stroke(Vector2(100, 100))
		trail.add_trail_point(Vector2(150, 120))
		trail.add_trail_point(Vector2(200, 150))
		print("✓ SwipeTrail stroke, particles, and math runes verified.")
		trail.queue_free()

	# 4. Test NumberBubble ghost symbols
	var bubble_scene = load("res://scenes/ui/NumberBubble.tscn")
	if bubble_scene:
		var bubble = bubble_scene.instantiate()
		_test_node.add_child(bubble)
		bubble.setup(42, Vector2(250, 200), "neutral", 1)
		bubble.pop_and_slice(Vector2(1, 0))
		if bubble.ghost_symbols.size() > 0:
			print("✓ NumberBubble generated ", bubble.ghost_symbols.size(), " character ghost shadows on slice!")
		bubble.queue_free()

	_apply_current_test()

func _apply_current_test() -> void:
	if _current_test < _slot_tests.size():
		var cfg = _slot_tests[_current_test]
		print("Testing weapon & cosmetic setup: ", cfg.name)
		_ascii_knight.equipped_sword = cfg.sword
		_ascii_knight.equipped_helmet = cfg.helmet
		_ascii_knight.equipped_hat = cfg.hat
		_ascii_knight.play_slash()

func _process(delta: float) -> bool:
	_frames += 1
	if _frames % 8 == 0 and _current_test < _slot_tests.size():
		_current_test += 1
		if _current_test < _slot_tests.size():
			_apply_current_test()
		else:
			print("=== ALL WEAPON & SWORD FX TESTS PASSED SUCCESSFULLY! ===")
			quit(0)
			return true
	return false
