extends Control
class_name RPGMapBackground
## Custom procedural / vector drawing of a fantasy RPG parchment overworld map.
## Includes antique paper shading, decorative compass rose, mountain ridges,
## forest clusters, winding river, coastline, and region markers.

@export var parchment_color: Color = Color(0.89, 0.81, 0.67, 1.0) # Aged parchment
@export var border_color: Color = Color(0.38, 0.26, 0.16, 0.85)   # Antique sepia ink
@export var ink_dim: Color = Color(0.48, 0.35, 0.22, 0.45)        # Soft sepia for terrain

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _draw() -> void:
	var w = size.x
	var h = size.y
	if w <= 0 or h <= 0:
		w = 640.0
		h = 360.0
	
	# 1. Base parchment parchment fill
	draw_rect(Rect2(0, 0, w, h), parchment_color)
	
	# Subtle texture gradients / shaded regions
	_draw_parchment_vignette(w, h)
	
	# 2. Antique grid lines (nautical / cartographic rhumb lines)
	_draw_cartography_lines(w, h)
	
	# 3. Terrain illustrations (River, Mountains, Forests)
	_draw_winding_river(w, h)
	_draw_mountain_ranges(w, h)
	_draw_forest_clusters(w, h)
	
	# 4. Region separators and Act banners
	_draw_act_regions(w, h)
	
	# 5. Decorative Compass Rose (Windrose)
	_draw_compass_rose(Vector2(w - 60, 68), 24.0)
	
	# 6. Antique ornate border frame
	_draw_antique_border(w, h)

func _draw_parchment_vignette(w: float, h: float) -> void:
	# Draw darker aged stains on the edges
	var corner_tint = Color(0.72, 0.60, 0.44, 0.35)
	
	# Top vignette
	draw_rect(Rect2(0, 0, w, 40), Color(0.45, 0.32, 0.18, 0.25))
	# Bottom vignette
	draw_rect(Rect2(0, h - 30, w, 30), Color(0.45, 0.32, 0.18, 0.25))
	# Side corners
	draw_circle(Vector2(0, 0), 120.0, corner_tint)
	draw_circle(Vector2(w, 0), 120.0, corner_tint)
	draw_circle(Vector2(0, h), 120.0, corner_tint)
	draw_circle(Vector2(w, h), 120.0, corner_tint)

func _draw_cartography_lines(w: float, h: float) -> void:
	var line_col = Color(0.65, 0.52, 0.38, 0.18)
	var center = Vector2(w * 0.5, h * 0.5)
	
	# Faint navigation lines radiating from center
	for i in range(8):
		var angle = i * (PI / 4.0)
		var dir = Vector2(cos(angle), sin(angle))
		draw_line(center, center + dir * 400.0, line_col, 1.0)

func _draw_winding_river(w: float, h: float) -> void:
	var river_color = Color(0.45, 0.65, 0.75, 0.4)
	var river_bank = Color(0.38, 0.48, 0.55, 0.3)
	
	# A winding river flowing from top-left mountains to bottom-right sea
	var points = PackedVector2Array([
		Vector2(20, 110),
		Vector2(60, 130),
		Vector2(85, 175),
		Vector2(70, 220),
		Vector2(95, 270),
		Vector2(80, 340)
	])
	
	for i in range(points.size() - 1):
		draw_line(points[i], points[i+1], river_bank, 6.0, true)
		draw_line(points[i], points[i+1], river_color, 4.0, true)

func _draw_mountain_ranges(w: float, h: float) -> void:
	# Left Mountains (Act 1 / 2 background)
	_draw_single_mountain(Vector2(35, 80), 18, 22)
	_draw_single_mountain(Vector2(55, 75), 24, 28)
	_draw_single_mountain(Vector2(78, 85), 16, 20)
	
	# Right Mountains (Act 3 / Boss peaks)
	_draw_single_mountain(Vector2(w - 90, 140), 20, 26)
	_draw_single_mountain(Vector2(w - 65, 130), 28, 34)
	_draw_single_mountain(Vector2(w - 40, 145), 18, 22)
	_draw_single_mountain(Vector2(w - 75, 220), 22, 28)
	_draw_single_mountain(Vector2(w - 45, 230), 17, 20)

func _draw_single_mountain(pos: Vector2, half_w: float, height: float) -> void:
	var peak = pos + Vector2(0, -height)
	var left = pos + Vector2(-half_w, 0)
	var right = pos + Vector2(half_w, 0)
	
	# Shaded left face
	var left_poly = PackedVector2Array([peak, left, pos])
	draw_polygon(left_poly, PackedColorArray([ink_dim, ink_dim, ink_dim]))
	
	# Ridge outline
	draw_line(peak, left, border_color, 1.2, true)
	draw_line(peak, right, border_color, 1.2, true)
	draw_line(left, right, border_color, 0.8, true)
	# Center ridge
	draw_line(peak, pos + Vector2(half_w * 0.15, 0), border_color, 1.0, true)

func _draw_forest_clusters(w: float, h: float) -> void:
	# Forest icons near lower left and top middle
	_draw_tree_cluster(Vector2(110, 310), 3)
	_draw_tree_cluster(Vector2(w - 110, 320), 4)
	_draw_tree_cluster(Vector2(130, 90), 3)

func _draw_tree_cluster(pos: Vector2, count: int) -> void:
	var tree_col = Color(0.25, 0.42, 0.28, 0.55)
	for i in range(count):
		var offset = Vector2((i - 1) * 10.0, (i % 2) * 5.0)
		var p = pos + offset
		# Tree triangle
		var tree_poly = PackedVector2Array([
			p + Vector2(0, -12),
			p + Vector2(-6, 0),
			p + Vector2(6, 0)
		])
		draw_polygon(tree_poly, PackedColorArray([tree_col, tree_col, tree_col]))
		draw_line(p + Vector2(0, -12), p + Vector2(-6, 0), border_color, 0.8)
		draw_line(p + Vector2(0, -12), p + Vector2(6, 0), border_color, 0.8)
		# Trunk
		draw_line(p, p + Vector2(0, 3), border_color, 1.2)

func _draw_act_regions(w: float, h: float) -> void:
	var font = ThemeDB.fallback_font
	var font_size = 9
	var sepia_text = Color(0.42, 0.30, 0.18, 0.65)
	
	# Act tier indicator labels along the left side
	var act_info = [
		{"name": "AKT I: GOBLIN-AUEN", "y": 272},
		{"name": "AKT II: SCHATTENWALD", "y": 198},
		{"name": "AKT III: DRACHENZACKEN", "y": 128},
		{"name": "AKT IV: TITANENFESTE", "y": 56}
	]
	
	for act in act_info:
		# Draw horizontal faint dashed tier divider
		var y_val = act["y"] + 16.0
		if act["name"] != "AKT IV: TITANENFESTE":
			_draw_dashed_line(Vector2(30, y_val), Vector2(w - 30, y_val), Color(0.45, 0.35, 0.25, 0.2), 1.0, 6.0)
		
		# Draw small region banner on the far left
		draw_string(font, Vector2(28, act["y"] - 14), act["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, sepia_text)

func _draw_compass_rose(center: Vector2, radius: float) -> void:
	var col_dark = Color(0.35, 0.24, 0.14, 0.75)
	var col_light = Color(0.78, 0.68, 0.52, 0.75)
	var col_gold = Color(0.75, 0.55, 0.15, 0.85)
	
	# Outer ring
	draw_arc(center, radius, 0, TAU, 32, col_dark, 1.2, true)
	draw_arc(center, radius * 0.75, 0, TAU, 32, col_dark, 0.8, true)
	
	# 4 Cardinal points (North, South, East, West)
	var dirs = [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]
	for i in range(4):
		var fwd = dirs[i]
		var right = Vector2(-fwd.y, fwd.x)
		var tip = center + fwd * (radius * 1.2)
		var base_r = center + right * (radius * 0.3)
		var base_l = center - right * (radius * 0.3)
		
		# Half dark, half light
		var poly_r = PackedVector2Array([center, tip, base_r])
		var poly_l = PackedVector2Array([center, tip, base_l])
		draw_polygon(poly_r, PackedColorArray([col_dark, col_dark, col_dark]))
		draw_polygon(poly_l, PackedColorArray([col_light, col_light, col_light]))
	
	# Center golden pip
	draw_circle(center, 3.0, col_gold)
	
	# North "N" mark
	var font = ThemeDB.fallback_font
	draw_string(font, center + Vector2(-4, -radius * 1.3), "N", HORIZONTAL_ALIGNMENT_CENTER, -1, 9, col_dark)

func _draw_antique_border(w: float, h: float) -> void:
	# Double rectangular antique parchment border
	var m1 = 8.0
	var m2 = 12.0
	draw_rect(Rect2(m1, m1, w - 2*m1, h - 2*m1), border_color, false, 2.0)
	draw_rect(Rect2(m2, m2, w - 2*m2, h - 2*m2), Color(border_color.r, border_color.g, border_color.b, 0.4), false, 1.0)
	
	# Corner ornamental brackets
	var c_len = 16.0
	var corners = [
		Vector2(m1, m1), Vector2(w - m1, m1),
		Vector2(m1, h - m1), Vector2(w - m1, h - m1)
	]
	var signs = [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]
	
	for i in range(4):
		var c = corners[i]
		var s = signs[i]
		draw_line(c, c + Vector2(s.x * c_len, 0), border_color, 3.0)
		draw_line(c, c + Vector2(0, s.y * c_len), border_color, 3.0)
		draw_circle(c + s * 4.0, 2.0, Color(0.75, 0.55, 0.15, 0.9))

func _draw_dashed_line(from: Vector2, to: Vector2, color: Color, width: float, dash_len: float) -> void:
	var length = from.distance_to(to)
	var dir = (to - from).normalized()
	var pos = from
	var drawn = 0.0
	var drawing = true
	
	while drawn < length:
		var step = min(dash_len, length - drawn)
		if drawing:
			draw_line(pos, pos + dir * step, color, width, true)
		pos += dir * step
		drawn += step
		drawing = !drawing
