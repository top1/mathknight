extends Control
class_name MapNode
## A single location node on the roguelike run map.
## Designed with pure ASCII-glow aesthetics, multi-layer neon blooms,
## pulsing beacon rings, and clear tactical feedback.

signal node_tapped(node_data: Dictionary)

var node_data: Dictionary = {}
var state: String = "locked" # locked, available, current, completed
var _pulse_tween: Tween
var _hovered: bool = false
var _t: float = 0.0
var _font: Font

func _ready() -> void:
	custom_minimum_size = Vector2(80, 80)
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	if ResourceLoader.exists("res://assets/fonts/Silkscreen-Bold.ttf"):
		_font = load("res://assets/fonts/Silkscreen-Bold.ttf")
	else:
		_font = ThemeDB.fallback_font
	
	if state == "available" or state == "current":
		_start_pulse()

func set_data(data: Dictionary, initial_state: String) -> void:
	node_data = data
	state = initial_state
	if is_inside_tree():
		if state == "available" or state == "current":
			_start_pulse()
		else:
			_stop_pulse()
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	if state == "available" or state == "current" or _hovered:
		queue_redraw()

func _start_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(self, "scale", Vector2(1.06, 1.06), 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _stop_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
		_pulse_tween = null
	scale = Vector2.ONE

func _on_mouse_entered() -> void:
	_hovered = true
	if state == "available" or state == "current":
		modulate = Color(1.2, 1.2, 1.1)
	queue_redraw()

func _on_mouse_exited() -> void:
	_hovered = false
	modulate = Color.WHITE
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		if state == "available" or state == "current" or state == "completed":
			node_tapped.emit(node_data)
			get_viewport().set_input_as_handled()

func _draw() -> void:
	if not _font:
		_font = ThemeDB.fallback_font

	pivot_offset = Vector2(size.x * 0.5, 24.0)
	var center = Vector2(size.x * 0.5, 24.0)
	var radius = 20.0
	
	var type = node_data.get("type", "combat")
	var is_boss = (type == "boss")
	if is_boss:
		radius = 24.0
	
	# Determine theme colors based on type and state
	var alpha = 1.0
	var ring_color = Color(0.2, 0.4, 0.6)
	var glow_color = Color.TRANSPARENT
	var core_icon_col = Color.WHITE
	var aura_icon_col = Color(0.2, 0.85, 1.0)
	
	match type:
		"combat":
			ring_color = Color(0.25, 0.7, 0.95)
			aura_icon_col = Color(0.2, 0.75, 1.0)
		"elite":
			ring_color = Color(0.95, 0.25, 0.35)
			aura_icon_col = Color(1.0, 0.2, 0.3)
		"boss":
			ring_color = Color(1.0, 0.8, 0.2)
			aura_icon_col = Color(1.0, 0.75, 0.1)
		"shop":
			ring_color = Color(0.25, 0.95, 0.55)
			aura_icon_col = Color(0.2, 0.9, 0.5)
		"rest":
			ring_color = Color(0.3, 0.85, 0.95)
			aura_icon_col = Color(1.0, 0.6, 0.1)
		_:
			ring_color = Color(0.5, 0.5, 0.6)
			aura_icon_col = Color(0.5, 0.5, 0.6)
			
	if state == "locked":
		alpha = 0.45
		ring_color = ring_color.darkened(0.6)
		aura_icon_col = aura_icon_col.darkened(0.5)
		core_icon_col = Color(0.5, 0.5, 0.6)
	elif state == "completed":
		alpha = 0.65
		ring_color = Color(0.2, 0.65, 0.4)
		aura_icon_col = Color(0.2, 0.6, 0.35)
		core_icon_col = Color(0.55, 0.85, 0.65)
	elif state == "available":
		alpha = 1.0
		var pulse_a = 0.35 + sin(_t * 4.0) * 0.12
		ring_color = Color(1.0, 0.85, 0.3)
		glow_color = Color(1.0, 0.85, 0.25, pulse_a)
	elif state == "current":
		alpha = 1.0
		var pulse_a = 0.45 + sin(_t * 5.0) * 0.15
		ring_color = Color(0.2, 0.95, 1.0)
		glow_color = Color(0.2, 0.85, 1.0, pulse_a)
	
	ring_color.a = alpha
	aura_icon_col.a = alpha
	core_icon_col.a = alpha
	
	# 1. Multi-layer Beacon Glow
	if glow_color.a > 0.0:
		draw_circle(center, radius + 8.0, Color(glow_color.r, glow_color.g, glow_color.b, glow_color.a * 0.4))
		draw_circle(center, radius + 4.0, glow_color)
	
	# 2. Dark Cyber Disc Background
	draw_circle(center + Vector2(0, 2), radius + 2.0, Color(0, 0, 0, 0.6 * alpha))
	draw_circle(center, radius, Color(0.06, 0.05, 0.11, 0.92 * alpha))
	
	# 3. Outer Neon Perimeter Ring
	draw_arc(center, radius, 0, TAU, 28, Color(ring_color.r, ring_color.g, ring_color.b, 0.4 * alpha), 2.5, true)
	draw_arc(center, radius, 0, TAU, 28, ring_color, 1.2, true)
	
	# Inner decorative tick marks
	for k in range(4):
		var tick_ang = k * (PI * 0.5) + (_t * 0.2 if (state == "available" or state == "current") else 0.0)
		var t_pos = center + Vector2(cos(tick_ang), sin(tick_ang)) * (radius - 2.0)
		draw_circle(t_pos, 1.2, ring_color)
	
	# 4. Pure ASCII Glow Icon
	_draw_ascii_icon(center, type, core_icon_col, aura_icon_col, is_boss, alpha)
	
	# 5. Completed Stamp / Cyber Checkmark
	if state == "completed":
		draw_circle(center, radius * 0.75, Color(0.04, 0.12, 0.06, 0.75))
		draw_line(center + Vector2(-6, 1), center + Vector2(-1, 6), Color(0.3, 1.0, 0.5, 0.9), 2.4, true)
		draw_line(center + Vector2(-1, 6), center + Vector2(8, -5), Color(0.3, 1.0, 0.5, 0.9), 2.4, true)
	
	# 6. Text Ribbon Banner under the node
	var font_size = 9
	var text_y1 = 51.0
	var text_y2 = 63.0
	
	var banner_w = size.x - 4
	var banner_rect = Rect2(2, text_y1 - 10, banner_w, 24)
	
	# Cyber Banner fill & border
	draw_rect(banner_rect, Color(0.05, 0.04, 0.10, 0.88 * alpha), true)
	draw_rect(banner_rect, Color(ring_color.r, ring_color.g, ring_color.b, 0.5 * alpha), false, 1.0)
	
	if type in ["combat", "elite", "boss"]:
		var diff = node_data.get("math_difficulty", 0)
		var stars = "★☆☆"
		match diff:
			0: stars = "★☆☆"
			1: stars = "★★☆"
			2: stars = "★★★"
			
		var op = node_data.get("math_operation", 0)
		var op_sym = "+"
		match op:
			0: op_sym = "+"
			1: op_sym = "-"
			2: op_sym = "×"
			3: op_sym = "÷"
			4: op_sym = "Mix"
			
		var star_color = Color(1.0, 0.88, 0.3, alpha) if (state == "available" or state == "current") else Color(0.65, 0.65, 0.7, alpha)
		var line1_text = stars + " [" + op_sym + "]"
		draw_string(_font, Vector2(0, text_y1), line1_text, HORIZONTAL_ALIGNMENT_CENTER, int(size.x), font_size, star_color)
		
		var reward_gold = node_data.get("reward_gold", 0)
		var reward_text = "🪙" + str(reward_gold)
		if node_data.get("reward_chest_chance", 0.0) > 0:
			reward_text += " 📦"
		draw_string(_font, Vector2(0, text_y2), reward_text, HORIZONTAL_ALIGNMENT_CENTER, int(size.x), 8, Color(0.9, 0.95, 1.0, alpha))
	elif type == "shop":
		draw_string(_font, Vector2(0, text_y1), "Händler", HORIZONTAL_ALIGNMENT_CENTER, int(size.x), font_size, Color(0.4, 0.95, 0.6, alpha))
		draw_string(_font, Vector2(0, text_y2), "Markt", HORIZONTAL_ALIGNMENT_CENTER, int(size.x), 8, Color(0.8, 0.95, 0.85, alpha))
	elif type == "rest":
		draw_string(_font, Vector2(0, text_y1), "Rast", HORIZONTAL_ALIGNMENT_CENTER, int(size.x), font_size, Color(0.4, 0.9, 1.0, alpha))
		draw_string(_font, Vector2(0, text_y2), "+40% ❤", HORIZONTAL_ALIGNMENT_CENTER, int(size.x), 8, Color(0.8, 0.9, 1.0, alpha))

const NODE_ICONS: Dictionary = {
	"combat": "res://assets/sprites/map/map_node_combat.png",
	"elite": "res://assets/sprites/map/map_node_elite.png",
	"boss": "res://assets/sprites/map/map_node_boss.png",
	"shop": "res://assets/sprites/map/map_node_shop.png",
	"rest": "res://assets/sprites/map/map_node_rest.png",
	"treasure": "res://assets/sprites/map/map_node_treasure.png",
}

func _draw_ascii_icon(center: Vector2, type: String, _core_col: Color, _aura_col: Color, is_boss: bool, alpha: float) -> void:
	var path: String = NODE_ICONS.get(type, NODE_ICONS["combat"])
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		if tex:
			var icon_sz: float = 44.0 if is_boss else 38.0
			var rect := Rect2(center.x - icon_sz * 0.5, center.y - icon_sz * 0.5, icon_sz, icon_sz)
			draw_texture_rect(tex, rect, false, Color(1, 1, 1, alpha))
			return

func _render_ascii_glyph_group(items: Array, core_col: Color, aura_col: Color) -> void:
	# Aura Bloom pass
	for item in items:
		var p: Vector2 = item["p"]
		var c: String = item["c"]
		var sz: int = item["sz"]
		draw_string(_font, p + Vector2(-sz * 0.35 - 1, sz * 0.35 + 1), c, HORIZONTAL_ALIGNMENT_CENTER, -1, sz + 1, Color(aura_col.r, aura_col.g, aura_col.b, aura_col.a * 0.4))
		draw_string(_font, p + Vector2(-sz * 0.35 + 1, sz * 0.35 - 1), c, HORIZONTAL_ALIGNMENT_CENTER, -1, sz + 1, Color(aura_col.r, aura_col.g, aura_col.b, aura_col.a * 0.4))
	
	# Crisp Core glyph pass
	for item in items:
		var p: Vector2 = item["p"]
		var c: String = item["c"]
		var sz: int = item["sz"]
		draw_string(_font, p + Vector2(-sz * 0.35, sz * 0.35), c, HORIZONTAL_ALIGNMENT_CENTER, -1, sz, core_col)
