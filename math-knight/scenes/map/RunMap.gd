extends Control
class_name RunMap
## Roguelike run map screen.
## Displays an interactive non-linear RPG fantasy overworld map,
## manages branch progression, permanent merchant outposts, and hero stat access.

const MapNodeClass = preload("res://scenes/map/MapNode.tscn")

@onready var map_container: Control = $MapContainer
@onready var popup: NodeInfoPopup = $NodeInfoPopup
@onready var gold_label: Label = $HeaderBar/HBox/GoldLabel
@onready var hp_label: Label = $HeaderBar/HBox/HPLabel
@onready var diamond_label: Label = $HeaderBar/HBox/DiamondLabel
@onready var shop_button: Button = $HeaderBar/HBox/ShopButton
@onready var hero_button: Button = $HeaderBar/HBox/HeroButton
@onready var surrender_button: Button = $HeaderBar/HBox/SurrenderButton

var _map_data: Array = []
var _node_instances: Dictionary = {}
var _font: Font
var _t: float = 0.0

func _ready() -> void:
	if ResourceLoader.exists("res://assets/fonts/Silkscreen-Bold.ttf"):
		_font = load("res://assets/fonts/Silkscreen-Bold.ttf")
	else:
		_font = ThemeDB.fallback_font

	surrender_button.pressed.connect(_on_surrender_pressed)
	shop_button.pressed.connect(_on_shop_pressed)
	hero_button.pressed.connect(_on_hero_pressed)
	popup.confirmed.connect(_on_node_confirmed)
	
	_setup_button_styles()
	
	# Initialize from RunManager
	if has_node("/root/RunManager"):
		var rm = get_node("/root/RunManager")
		if not rm.is_run_active:
			rm.start_new_run()
		
		# Convert RunManager map format to display format
		_map_data = _convert_run_manager_map(rm)
		
		# Check if returning from combat
		if rm.pending_combat_result:
			rm.pending_combat_result = false
			rm.complete_current_node()
			_sync_states_from_run_manager(rm)
	else:
		# Standalone fallback
		_map_data = _generate_fallback_map()
	
	_update_header()
	_render_map()

	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_music("map")

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _setup_button_styles() -> void:
	# Shop Button Style (Merchant Emerald)
	var shop_style = StyleBoxFlat.new()
	shop_style.bg_color = Color(0.15, 0.38, 0.22, 0.95)
	shop_style.border_color = Color(0.4, 0.85, 0.45)
	shop_style.set_border_width_all(1)
	shop_style.set_corner_radius_all(5)
	shop_button.add_theme_stylebox_override("normal", shop_style)
	
	var shop_hover = shop_style.duplicate()
	shop_hover.bg_color = Color(0.22, 0.52, 0.30)
	shop_button.add_theme_stylebox_override("hover", shop_hover)
	shop_button.add_theme_stylebox_override("pressed", shop_hover)

	# Hero Button Style (Royal Purple/Gold)
	var hero_style = StyleBoxFlat.new()
	hero_style.bg_color = Color(0.32, 0.18, 0.45, 0.95)
	hero_style.border_color = Color(0.9, 0.75, 0.3)
	hero_style.set_border_width_all(1)
	hero_style.set_corner_radius_all(5)
	hero_button.add_theme_stylebox_override("normal", hero_style)
	
	var hero_hover = hero_style.duplicate()
	hero_hover.bg_color = Color(0.45, 0.25, 0.62)
	hero_button.add_theme_stylebox_override("hover", hero_hover)
	hero_button.add_theme_stylebox_override("pressed", hero_hover)

	# Surrender Button Style (Subtle Dark)
	var surr_style = StyleBoxFlat.new()
	surr_style.bg_color = Color(0.22, 0.15, 0.18, 0.85)
	surr_style.border_color = Color(0.55, 0.35, 0.4)
	surr_style.set_border_width_all(1)
	surr_style.set_corner_radius_all(5)
	surrender_button.add_theme_stylebox_override("normal", surr_style)

func _convert_run_manager_map(rm) -> Array:
	var tiers: Array = []
	for tier_idx in range(rm.run_map.size()):
		var tier_nodes: Array = []
		for node_data in rm.run_map[tier_idx]:
			var display_node: Dictionary = node_data.duplicate()
			display_node["state"] = rm.get_node_state(node_data.id)
			tier_nodes.append(display_node)
		tiers.append(tier_nodes)
	return tiers

func _sync_states_from_run_manager(rm) -> void:
	for tier in _map_data:
		for node in tier:
			node["state"] = rm.get_node_state(node["id"])

func _update_header() -> void:
	var gold: int = 0
	var hp: int = 10
	var max_hp: int = 10
	var diamonds: int = 0
	var hero_lv: int = 1
	var stat_pts: int = 0
	
	if has_node("/root/RunManager"):
		var rm = get_node("/root/RunManager")
		gold = rm.run_gold
		hp = int(rm.knight_run_hp)
		max_hp = int(rm.knight_run_max_hp)
	
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		diamonds = sm.diamonds
		hero_lv = sm.knight_level
		stat_pts = sm.knight_stat_points
	
	gold_label.text = "🪙 " + str(gold)
	hp_label.text = "❤ " + str(hp) + "/" + str(max_hp)
	diamond_label.text = "💎 " + str(diamonds)
	
	if stat_pts > 0:
		hero_button.text = "⬆️ HELD (! " + str(stat_pts) + " Pkt)"
		hero_button.add_theme_color_override("font_color", Color(1.0, 0.95, 0.3))
	else:
		hero_button.text = "⬆️ HELD (Lv. " + str(hero_lv) + ")"
		hero_button.add_theme_color_override("font_color", Color(0.9, 0.85, 0.95))

func _generate_fallback_map() -> Array:
	var tiers = []
	var t1 = [
		_create_node_data(101, 0, "combat", 0, 15, [201, 202]),
		_create_node_data(102, 0, "combat", 0, 15, [202]),
		_create_node_data(103, 0, "elite", 1, 30, [202, 203])
	]
	tiers.append(t1)
	
	var t2 = [
		_create_node_data(201, 1, "boss", 1, 45, [301]),
		_create_node_data(202, 1, "combat", 1, 20, [301, 302, 303]),
		_create_node_data(203, 1, "rest", 1, 0, [303])
	]
	tiers.append(t2)
	
	var t3 = [
		_create_node_data(301, 2, "combat", 2, 25, [401]),
		_create_node_data(302, 2, "elite", 2, 45, [401]),
		_create_node_data(303, 2, "rest", 1, 0, [401])
	]
	tiers.append(t3)
	
	var t4 = [
		_create_node_data(401, 3, "boss", 2, 100, [])
	]
	t4[0]["math_operation"] = 4
	tiers.append(t4)
	
	for node in tiers[0]:
		node["state"] = "available"
		
	return tiers

func _create_node_data(id: int, tier: int, type: String, difficulty: int, gold: int, connections: Array) -> Dictionary:
	var op: int = 0
	var mode: int = 0
	match tier:
		0:
			op = 0 if randf() < 0.75 else 1
			mode = 0
		1:
			op = 0 if randf() < 0.5 else 1
			mode = 0 if randf() < 0.8 else 1
		2:
			op = randi() % 3
			mode = randi() % 3
		_:
			op = 4
			mode = randi() % 3

	var is_boss = type == "boss"
	var is_mini = is_boss and tier < 3
	var boss_name = ""
	var boss_phases = 0
	if is_boss:
		boss_phases = 3 if is_mini else 5
		boss_name = "Orc-Kriegsherr" if is_mini else "Mathe-Drache"

	return {
		"id": id,
		"tier": tier,
		"type": type,
		"math_mode": mode,
		"math_operation": op,
		"math_difficulty": difficulty,
		"reward_gold": gold,
		"reward_chest_chance": 0.5 if type == "elite" else (1.0 if is_boss else 0.0),
		"enemy_count": 3 if type == "combat" else (5 if type == "elite" else 1),
		"boss_phases": boss_phases,
		"boss_name": boss_name,
		"is_mini_boss": is_mini,
		"connections": connections,
		"state": "locked"
	}

func _render_map() -> void:
	for child in map_container.get_children():
		child.queue_free()
	_node_instances.clear()
	
	# Y coordinates from bottom (Akt 1) to top (Akt 4 Boss)
	var y_positions = [266, 194, 122, 50]
	
	for tier_idx in range(_map_data.size()):
		var tier_nodes = _map_data[tier_idx]
		var y = y_positions[tier_idx]
		var count = tier_nodes.size()
		
		for i in range(count):
			var node_data = tier_nodes[i]
			var x = 320.0
			
			if count == 1:
				x = 320.0
			elif count == 2:
				x = 230.0 + i * 180.0
			elif count == 3:
				# Add subtle organic curvature offset based on index & tier
				var offset_curve = sin(tier_idx * 1.5 + i) * 14.0
				x = 160.0 + i * 160.0 + offset_curve
			elif count >= 4:
				x = 110.0 + i * 140.0
				
			var inst: MapNode = MapNodeClass.instantiate()
			inst.position = Vector2(x - 40.0, y)
			inst.set_data(node_data, node_data["state"])
			inst.node_tapped.connect(_on_node_tapped)
			map_container.add_child(inst)
			_node_instances[node_data["id"]] = inst
	
	queue_redraw()

func _draw() -> void:
	if not _font:
		_font = ThemeDB.fallback_font

	# Draw cyber circuit & glowing math glyph connections between nodes
	for tier in _map_data:
		for node in tier:
			if not _node_instances.has(node["id"]): continue
			var inst1 = _node_instances[node["id"]]
			var p1 = inst1.position + Vector2(40, 24) # Node pin center
			var state1 = node["state"]
			
			for conn_id in node.get("connections", []):
				if not _node_instances.has(conn_id): continue
				var inst2 = _node_instances[conn_id]
				var p2 = inst2.position + Vector2(40, 24)
				var state2 = _get_node_state_by_id(conn_id)
				
				# Path styling based on accessibility
				var is_active_path = (state1 == "completed" and (state2 == "available" or state2 == "current" or state2 == "completed"))
				var is_traveled = (state1 == "completed" and state2 == "completed")
				
				if is_traveled:
					# Solid Neon Circuit (Emerald/Cyan completed trail)
					_draw_cyber_path(p1, p2, Color(0.2, 0.9, 0.6, 0.85), Color(0.1, 0.4, 0.25, 0.4), 2.5, true)
				elif is_active_path:
					# Glowing Golden/Cyan Trail with animated traveling pulses
					_draw_cyber_path(p1, p2, Color(1.0, 0.88, 0.3, 0.95), Color(0.2, 0.85, 1.0, 0.5), 3.0, true)
				else:
					# Dim Cyber Dashed Trail (Locked)
					_draw_cyber_path(p1, p2, Color(0.3, 0.25, 0.45, 0.35), Color(0.1, 0.08, 0.2, 0.2), 1.5, false)

func _get_node_state_by_id(target_id: int) -> String:
	for tier in _map_data:
		for node in tier:
			if node["id"] == target_id:
				return node["state"]
	return "locked"

func _draw_cyber_path(from: Vector2, to: Vector2, fg_color: Color, aura_color: Color, width: float, is_active: bool) -> void:
	# Subtle curved bezier control point
	var mid = (from + to) * 0.5
	var normal = Vector2(-(to.y - from.y), to.x - from.x).normalized()
	var ctrl = mid + normal * 12.0
	
	var points = PackedVector2Array()
	var steps = 18
	for s in range(steps + 1):
		var t = float(s) / float(steps)
		var p = (1.0 - t) * (1.0 - t) * from + 2.0 * (1.0 - t) * t * ctrl + t * t * to
		points.append(p)
	
	if is_active:
		# Multi-layer outer neon aura glow
		for i in range(points.size() - 1):
			draw_line(points[i], points[i+1], aura_color, width + 3.0, true)
			draw_line(points[i], points[i+1], fg_color, width, true)
			
		# Animated traveling glyph packet along curve
		var pulse_t = fmod(_t * 0.65, 1.0)
		var p_pulse = (1.0 - pulse_t) * (1.0 - pulse_t) * from + 2.0 * (1.0 - pulse_t) * pulse_t * ctrl + pulse_t * pulse_t * to
		draw_circle(p_pulse, 4.5, Color(1.0, 1.0, 1.0, 0.95))
		draw_circle(p_pulse, 8.0, Color(fg_color.r, fg_color.g, fg_color.b, 0.45))
		
		var syms = ["+", "*", "~", "1", "0"]
		var sym_idx = int(_t * 4.0) % syms.size()
		draw_string(_font, p_pulse + Vector2(-3, 3), syms[sym_idx], HORIZONTAL_ALIGNMENT_CENTER, -1, 8, Color.WHITE)
	else:
		# Dashed/dotted circuit
		var drawing = true
		var current_len = 0.0
		var dash_len = 5.0
		for i in range(points.size() - 1):
			var seg_len = points[i].distance_to(points[i+1])
			if drawing:
				draw_line(points[i], points[i+1], fg_color, width, true)
			current_len += seg_len
			if current_len >= dash_len:
				current_len = 0.0
				drawing = !drawing


func _on_node_tapped(node_data: Dictionary) -> void:
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("click")
	if node_data["state"] in ["available", "current"]:
		popup.show_popup(node_data)
	elif node_data["state"] == "completed":
		# Can still view info of completed locations
		popup.show_popup(node_data)

func _on_node_confirmed(node_data: Dictionary) -> void:
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("click")
	var id = node_data["id"]
	if _node_instances.has(id):
		var inst = _node_instances[id]
		node_data["state"] = "current"
		inst.set_data(node_data, "current")
	queue_redraw()
	
	# Register selection with RunManager
	if has_node("/root/RunManager"):
		var rm = get_node("/root/RunManager")
		rm.select_node(id)
	
	if node_data["type"] in ["combat", "elite", "boss"]:
		if has_node("/root/RunManager"):
			var rm = get_node("/root/RunManager")
			var config = rm.get_math_config_for_node(node_data)
			if has_node("/root/MathEngine"):
				get_node("/root/MathEngine").set_difficulty(config)
			rm.pending_combat_result = true
		
		get_tree().change_scene_to_file("res://scenes/main/Main.tscn")
	elif node_data["type"] == "shop":
		# Legacy shop node support: now acts as merchant camp without skipping combat level
		get_tree().change_scene_to_file("res://scenes/shop/ShopScreen.tscn")
	elif node_data["type"] == "rest":
		# Heal knight at Campfire
		if has_node("/root/RunManager"):
			var rm = get_node("/root/RunManager")
			rm.heal_knight_percent(0.4)
		_update_header()
		_complete_current_node()

func _complete_current_node() -> void:
	if has_node("/root/RunManager"):
		var rm = get_node("/root/RunManager")
		rm.complete_current_node()
		_sync_states_from_run_manager(rm)
	else:
		# Fallback local state management
		for tier in _map_data:
			for node in tier:
				if node["state"] == "current":
					node["state"] = "completed"
					if _node_instances.has(node["id"]):
						_node_instances[node["id"]].set_data(node, "completed")
					for conn_id in node.get("connections", []):
						for t in _map_data:
							for n in t:
								if n["id"] == conn_id and n["state"] == "locked":
									n["state"] = "available"
									if _node_instances.has(conn_id):
										_node_instances[conn_id].set_data(n, "available")
	
	for tier in _map_data:
		for node in tier:
			if _node_instances.has(node["id"]):
				if has_node("/root/RunManager"):
					node["state"] = get_node("/root/RunManager").get_node_state(node["id"])
				_node_instances[node["id"]].set_data(node, node["state"])
	
	_update_header()
	queue_redraw()

func _on_shop_pressed() -> void:
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("click")
	# Enter Merchant Camp directly (does NOT consume progression node)
	get_tree().change_scene_to_file("res://scenes/shop/ShopScreen.tscn")

func _on_hero_pressed() -> void:
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("click")
	get_tree().change_scene_to_file("res://scenes/menu/LevelUpScreen.tscn")

func _on_surrender_pressed() -> void:
	if has_node("/root/RunManager"):
		var rm = get_node("/root/RunManager")
		rm.end_run(false)
	get_tree().change_scene_to_file("res://scenes/menu/TitleScreen.tscn")
