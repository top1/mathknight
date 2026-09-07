class_name JuiceManager
extends RefCounted

static var _hit_stop_id: int = 0

static func hit_stop(tree: SceneTree, duration: float = 0.066, scale: float = 0.05) -> void:
	_hit_stop_id += 1
	var current_id: int = _hit_stop_id
	Engine.time_scale = scale
	await tree.create_timer(duration, true, false, true).timeout
	if current_id == _hit_stop_id:
		Engine.time_scale = 1.0


## 4 frames (~0.066s) of impact freeze for sword strikes
static func hit_stop_4_frames(tree: SceneTree) -> void:
	await hit_stop(tree, 0.066, 0.04)


## Spawns a floating comic onomatopoeia popup ("POW!", "BLITZ!", "WHOOSH!", "CLANG!")
static func spawn_comic_popup(parent: Node, tag: String, pos: Vector2, archetype: String = "attack") -> void:
	if not parent or not parent.is_inside_tree():
		return
	var scene: PackedScene = load("res://scenes/effects/ComicPopup.tscn")
	if scene:
		var popup = scene.instantiate()
		parent.add_child(popup)
		popup.setup(tag, pos, archetype)

static func start_cinematic_slowmo(tree: SceneTree, duration: float = 0.45, slow_scale: float = 0.3) -> void:
	_hit_stop_id += 1
	var current_id: int = _hit_stop_id
	Engine.time_scale = slow_scale
	await tree.create_timer(duration, true, false, true).timeout
	if current_id == _hit_stop_id:
		Engine.time_scale = 1.0

static func flash_white(node: CanvasItem, duration: float = 0.12) -> void:
	if not node.material is ShaderMaterial:
		return
	var mat: ShaderMaterial = node.material as ShaderMaterial
	mat.set_shader_parameter("flash_modifier", 1.0)
	var tween: Tween = node.create_tween()
	tween.tween_method(
		func(val: float): mat.set_shader_parameter("flash_modifier", val),
		1.0, 0.0, duration
	)

static func squash_and_stretch(node: Node2D, squash: Vector2 = Vector2(1.3, 0.7), duration: float = 0.15) -> void:
	var tween: Tween = node.create_tween()
	var original_scale: Vector2 = node.scale
	node.scale = original_scale * squash
	tween.tween_property(node, "scale", original_scale, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

static func float_up_and_fade(node: Node2D, distance: float = 40.0, duration: float = 0.8) -> void:
	var tween: Tween = node.create_tween().set_parallel(true)
	tween.tween_property(node, "position:y", node.position.y - distance, duration).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "modulate:a", 0.0, duration).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(node.queue_free)
