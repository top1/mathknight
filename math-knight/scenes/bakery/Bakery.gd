class_name Bakery
extends Control
## ═══════════════════════════════════════════════════════════════════════════
## Bakery — Die königliche Hofbäckerei (Meister Kruste)
##
## Ein dreistufiges, haptisches und didaktisches Minispiel:
##   1. Physik-Balkenwaage:
##      - ECHTE historische Messing-Apothekergewichte mit Halteknauf und Gravur
##      - Echter Mehlsack mit Kordel auf der linken Waagschale
##      - Frei hängende Schalen, Drehmoment- & Dämpfungsphysik
##      - Lustiger KATAPULT-Effekt bei starkem Ungleichgewicht (Mehl-Explosion!)
##      - KEIN automatisches Vorrechnen der Spielerschale!
##   2. Steinofen & Kaminholz:
##      - ECHTE gespaltene Holzscheite (Birke, Fichte, Buche, Eiche) mit Rinde,
##        Jahresringen, Holzmaserung und eingebranntem Brandzeichen
##      - Per Drag & Drop direkt in die Glut des Steinofens werfen (oder antippen)
##      - Steinofen mit glühendem Kohlebett und brennenden Holzscheiten
##   3. Schlossuhr:
##      - Interaktives Drehen des Zeigers im 5-Minuten-Takt mit Glockenschlag
##   4. Königsbrot:
##      - Knuspriges Ergebnis, Brot-Gutschrift im SaveManager, Gold & XP
## ═══════════════════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════════════════
# INNER CLASSES FOR TACTILE WOOD & WEIGHT CONTROLS
# ═══════════════════════════════════════════════════════════════════════════

class WeightShelfItem extends Control:
	var weight_val: int = 1
	var is_hovered: bool = false
	var is_pressed: bool = false
	signal drag_started(val: int, pos: Vector2)
	
	func _init(w: int) -> void:
		weight_val = w
		var mass = float(clamp(w, 1, 30))
		custom_minimum_size = Vector2(max(56.0, 38.0 + sqrt(mass) * 8.0), 64.0)
		mouse_filter = Control.MOUSE_FILTER_STOP
		
		mouse_entered.connect(func():
			is_hovered = true
			queue_redraw()
		)
		mouse_exited.connect(func():
			is_hovered = false
			is_pressed = false
			queue_redraw()
		)
		
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_pressed = true
				queue_redraw()
				drag_started.emit(weight_val, event.global_position)
			else:
				is_pressed = false
				queue_redraw()
		elif event is InputEventScreenTouch:
			if event.pressed:
				is_pressed = true
				queue_redraw()
				drag_started.emit(weight_val, event.position)
			else:
				is_pressed = false
				queue_redraw()
				
	func _draw() -> void:
		var groove_rect = Rect2(4, size.y - 8, size.x - 8, 6)
		draw_rect(groove_rect, Color("#3f1d0b"))
		draw_rect(Rect2(6, size.y - 7, size.x - 12, 4), Color("#1c0a02"))
		Bakery.draw_brass_weight_static(self, Vector2(size.x * 0.5, size.y - 7), weight_val, is_hovered, is_pressed, 1.0)


class WoodShelfItem extends Control:
	var temp_val: int = 10
	var is_hovered: bool = false
	var is_pressed: bool = false
	signal drag_started(val: int, pos: Vector2)
	
	func _init(v: int) -> void:
		temp_val = v
		var vf = float(clamp(v, 5, 50))
		custom_minimum_size = Vector2(max(74.0, 56.0 + sqrt(vf) * 7.5), 56.0)
		mouse_filter = Control.MOUSE_FILTER_STOP
		
		mouse_entered.connect(func():
			is_hovered = true
			queue_redraw()
		)
		mouse_exited.connect(func():
			is_hovered = false
			is_pressed = false
			queue_redraw()
		)
		
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_pressed = true
				queue_redraw()
				drag_started.emit(temp_val, event.global_position)
			else:
				is_pressed = false
				queue_redraw()
		elif event is InputEventScreenTouch:
			if event.pressed:
				is_pressed = true
				queue_redraw()
				drag_started.emit(temp_val, event.position)
			else:
				is_pressed = false
				queue_redraw()
				
	func _draw() -> void:
		var cy = size.y - 6
		draw_line(Vector2(size.x * 0.22, cy), Vector2(size.x * 0.22, cy - 8), Color("#27272a"), 2.0)
		draw_line(Vector2(size.x * 0.78, cy), Vector2(size.x * 0.78, cy - 8), Color("#27272a"), 2.0)
		draw_line(Vector2(size.x * 0.16, cy), Vector2(size.x * 0.84, cy), Color("#18181b"), 2.5)
		Bakery.draw_firewood_log_static(self, Vector2(size.x * 0.5, size.y * 0.5 - 2), temp_val, is_hovered, is_pressed, 1.0)


# ═══════════════════════════════════════════════════════════════════════════
# STATIC VECTOR RENDERING: ECHTE GEWICHTE, ECHTES HOLZ, MEHLSACK
# ═══════════════════════════════════════════════════════════════════════════

static func draw_brass_weight_static(canvas: CanvasItem, center_base: Vector2, weight_val: int, is_hovered: bool = false, is_pressed: bool = false, scale_factor: float = 1.0) -> void:
	var mass: float = float(clamp(weight_val, 1, 30))
	var bw: float = (18.0 + sqrt(mass) * 6.5) * scale_factor
	var tw: float = bw * 0.58
	var bh: float = (15.0 + sqrt(mass) * 5.0) * scale_factor
	var kr: float = (3.4 + sqrt(mass) * 1.2) * scale_factor
	var base_lip_h: float = 3.0 * scale_factor
	
	var lift_y: float = -4.0 if is_hovered else (2.0 if is_pressed else 0.0)
	var c_base: Vector2 = center_base + Vector2(0, lift_y)
	
	# 1. Contact shadow
	canvas.draw_circle(center_base + Vector2(0, 2.5 * scale_factor), bw * 0.52, Color(0, 0, 0, 0.4))
	
	# 2. Golden halo on hover or drag
	if is_hovered:
		canvas.draw_circle(c_base - Vector2(0, bh * 0.5), bw * 0.75, Color(1.0, 0.85, 0.2, 0.25))
		
	# 3. Base beveled rim
	var lip_rect = Rect2(c_base.x - bw * 0.5, c_base.y - base_lip_h, bw, base_lip_h)
	canvas.draw_rect(lip_rect, Color("#b45309"))
	canvas.draw_line(c_base + Vector2(-bw * 0.5, 0), c_base + Vector2(bw * 0.5, 0), Color("#451a03"), 1.2 * scale_factor)
	canvas.draw_line(c_base + Vector2(-bw * 0.5, -base_lip_h), c_base + Vector2(bw * 0.5, -base_lip_h), Color("#fef08a"), 1.0 * scale_factor)
	
	# 4. Tapered bell body
	var p1 = c_base + Vector2(-bw * 0.48, -base_lip_h)
	var p2 = c_base + Vector2(bw * 0.48, -base_lip_h)
	var p3 = c_base + Vector2(tw * 0.5, -bh)
	var p4 = c_base + Vector2(-tw * 0.5, -bh)
	
	canvas.draw_colored_polygon(PackedVector2Array([p1, p2, p3, p4]), Color("#d97706"))
	
	# Left shadow
	var s_p2 = p1.lerp(p2, 0.24)
	var s_p3 = p4.lerp(p3, 0.24)
	canvas.draw_colored_polygon(PackedVector2Array([p1, s_p2, s_p3, p4]), Color(0.47, 0.21, 0.06, 0.6))
	
	# Specular shine streak
	var sh_p1 = p1.lerp(p2, 0.30)
	var sh_p2 = p1.lerp(p2, 0.48)
	var sh_p3 = p4.lerp(p3, 0.48)
	var sh_p4 = p4.lerp(p3, 0.30)
	canvas.draw_colored_polygon(PackedVector2Array([sh_p1, sh_p2, sh_p3, sh_p4]), Color(0.99, 0.94, 0.54, 0.65))
	
	# Right shade
	var r_p1 = p1.lerp(p2, 0.68)
	var r_p4 = p4.lerp(p3, 0.68)
	canvas.draw_colored_polygon(PackedVector2Array([r_p1, p2, p3, r_p4]), Color(0.47, 0.21, 0.06, 0.68))
	
	# Outline
	canvas.draw_polyline(PackedVector2Array([p1, p4, p3, p2, p1]), Color("#78350f"), 1.2 * scale_factor)
	
	# 5. Collar ring
	var collar_h: float = 2.8 * scale_factor
	var collar_w: float = tw * 1.15
	var col_rect = Rect2(c_base.x - collar_w * 0.5, c_base.y - bh - collar_h, collar_w, collar_h)
	canvas.draw_rect(col_rect, Color("#f59e0b"))
	canvas.draw_line(col_rect.position, col_rect.position + Vector2(collar_w, 0), Color("#fef9c3"), 1.0)
	canvas.draw_line(col_rect.position + Vector2(0, collar_h), col_rect.position + Vector2(collar_w, collar_h), Color("#78350f"), 1.0)
	
	# 6. Top Knob
	var knob_c: Vector2 = c_base - Vector2(0, bh + collar_h + kr + 1.0 * scale_factor)
	canvas.draw_rect(Rect2(knob_c.x - kr * 0.35, knob_c.y, kr * 0.7, kr + collar_h), Color("#92400e"))
	canvas.draw_circle(knob_c, kr, Color("#d97706"))
	canvas.draw_arc(knob_c, max(1.0, kr - 0.8), 0, PI, 14, Color("#451a03"), 1.5 * scale_factor)
	canvas.draw_arc(knob_c, max(1.0, kr - 0.8), PI, TAU, 14, Color("#fde047"), 1.2 * scale_factor)
	canvas.draw_circle(knob_c + Vector2(-kr * 0.35, -kr * 0.35), max(1.0, kr * 0.3), Color("#fffbeb"))
	
	# 7. Engraved nominal weight text
	var stamp_y = c_base.y - bh * 0.46
	var font_size = clamp(int(7.0 + sqrt(mass) * 1.6 * scale_factor), 7, 12)
	var txt = "%d kg" % weight_val
	canvas.draw_string(ThemeDB.fallback_font, Vector2(c_base.x - bw * 0.5, stamp_y + 1), txt, HORIZONTAL_ALIGNMENT_CENTER, bw, font_size, Color("#451a03"))
	canvas.draw_string(ThemeDB.fallback_font, Vector2(c_base.x - bw * 0.5, stamp_y + 3), txt, HORIZONTAL_ALIGNMENT_CENTER, bw, font_size, Color(1, 0.95, 0.6, 0.5))
	canvas.draw_string(ThemeDB.fallback_font, Vector2(c_base.x - bw * 0.5, stamp_y + 2), txt, HORIZONTAL_ALIGNMENT_CENTER, bw, font_size, Color("#fffbeb"))


static func draw_firewood_log_static(canvas: CanvasItem, center_pos: Vector2, temp_val: int, is_hovered: bool = false, is_pressed: bool = false, scale_factor: float = 1.0) -> void:
	var v: float = float(clamp(temp_val, 5, 50))
	var lw: float = (56.0 + sqrt(v) * 6.0) * scale_factor
	var lh: float = (22.0 + sqrt(v) * 2.5) * scale_factor
	var end_rx: float = lh * 0.42
	var end_ry: float = lh * 0.48
	
	var lift_y: float = -3.0 if is_hovered else (2.0 if is_pressed else 0.0)
	var c_pos: Vector2 = center_pos + Vector2(0, lift_y)
	
	# 1. Contact shadow
	canvas.draw_circle(center_pos + Vector2(0, lh * 0.5 + 3.0 * scale_factor), lw * 0.45, Color(0, 0, 0, 0.38))
	
	# 2. Glowing aura
	if is_hovered:
		canvas.draw_circle(c_pos, lw * 0.52, Color(1.0, 0.5, 0.1, 0.28))
		
	# 3. Wood Species Palette
	var is_birch = (temp_val == 5)
	var bark_col: Color
	var wood_col: Color
	var grain_col: Color
	
	if is_birch:
		bark_col = Color("#e2e8f0")
		wood_col = Color("#fef08a")
		grain_col = Color("#ca8a04")
	elif temp_val <= 15:
		bark_col = Color("#3f1d0b")
		wood_col = Color("#fde047")
		grain_col = Color("#b45309")
	elif temp_val <= 30:
		bark_col = Color("#44403c")
		wood_col = Color("#fed7aa")
		grain_col = Color("#c2410c")
	else:
		bark_col = Color("#1c0d02")
		wood_col = Color("#fde68a")
		grain_col = Color("#78350f")
		
	var end_c = Vector2(c_pos.x - lw * 0.40, c_pos.y)
	var right_x = c_pos.x + lw * 0.46
	
	# 4. Split wood flank (Top face)
	var sp_tl = Vector2(end_c.x, end_c.y - end_ry)
	var sp_tr = Vector2(right_x, c_pos.y - lh * 0.40)
	var sp_br = Vector2(right_x, c_pos.y + lh * 0.12)
	var sp_bl = Vector2(end_c.x, end_c.y + end_ry * 0.15)
	
	canvas.draw_colored_polygon(PackedVector2Array([sp_tl, sp_tr, sp_br, sp_bl]), wood_col)
	
	for i in range(3):
		var t_f = float(i + 1) / 4.0
		var g_start = sp_tl.lerp(sp_bl, t_f)
		var g_end = sp_tr.lerp(sp_br, t_f)
		canvas.draw_line(g_start, g_end, Color(grain_col, 0.4), 1.0 * scale_factor)
		
	# 5. Bark flank (Bottom curve)
	var bk_tl = sp_bl
	var bk_tr = sp_br
	var bk_br = Vector2(right_x - 3 * scale_factor, c_pos.y + lh * 0.48)
	var bk_bl = Vector2(end_c.x, end_c.y + end_ry)
	
	canvas.draw_colored_polygon(PackedVector2Array([bk_tl, bk_tr, bk_br, bk_bl]), bark_col)
	
	if is_birch:
		for l_ratio in [0.25, 0.5, 0.75]:
			var lx = lerp(end_c.x + 8, right_x - 8, l_ratio)
			var ly = lerp(bk_tl.y, bk_bl.y, 0.5)
			canvas.draw_line(Vector2(lx - 4, ly), Vector2(lx + 4, ly), Color("#0f172a"), 1.2 * scale_factor)
	else:
		canvas.draw_line(bk_tl.lerp(bk_bl, 0.5), bk_tr.lerp(bk_br, 0.5), Color("#1c0b03", 0.5), 1.2 * scale_factor)
		
	canvas.draw_polyline(PackedVector2Array([sp_tl, sp_tr, bk_br, bk_bl, sp_tl]), Color("#271206"), 1.2 * scale_factor)
	
	# 6. End-grain cut section
	var end_pts = PackedVector2Array()
	var segs = 18
	for i in range(segs):
		var a = float(i) / float(segs) * TAU
		end_pts.append(end_c + Vector2(cos(a) * end_rx, sin(a) * end_ry))
	canvas.draw_colored_polygon(end_pts, wood_col)
	canvas.draw_polyline(end_pts, Color("#1c0b03"), 1.5 * scale_factor)
	
	canvas.draw_arc(end_c, end_rx * 0.35, 0, TAU, 12, Color(grain_col, 0.55), 1.0 * scale_factor)
	canvas.draw_arc(end_c, end_rx * 0.68, 0, TAU, 14, Color(grain_col, 0.55), 1.0 * scale_factor)
	canvas.draw_circle(end_c, 1.2 * scale_factor, Color("#451a03"))
	canvas.draw_line(end_c, end_c + Vector2(end_rx * 0.75, end_ry * 0.3), Color("#3f1d0b"), 1.0 * scale_factor)
	
	# 7. Right charred tip with embers
	canvas.draw_circle(Vector2(right_x - 2, c_pos.y - 2), 2.2 * scale_factor, Color("#f97316"))
	canvas.draw_circle(Vector2(right_x - 1, c_pos.y + 3), 1.5 * scale_factor, Color("#facc15"))
	
	# 8. Branded Temperature Marking
	var stamp_pos = Vector2(c_pos.x + lw * 0.08, c_pos.y - lh * 0.1)
	var font_size = clamp(int(8.0 + sqrt(v) * 1.5 * scale_factor), 9, 13)
	var txt = "+%d°C" % temp_val
	canvas.draw_string(ThemeDB.fallback_font, stamp_pos + Vector2(-lw * 0.25, font_size * 0.35 + 1), txt, HORIZONTAL_ALIGNMENT_CENTER, lw * 0.5, font_size, Color("#ea580c"))
	canvas.draw_string(ThemeDB.fallback_font, stamp_pos + Vector2(-lw * 0.25, font_size * 0.35), txt, HORIZONTAL_ALIGNMENT_CENTER, lw * 0.5, font_size, Color("#1c0a02"))


static func draw_flour_sack_static(canvas: CanvasItem, center_base: Vector2, weight_val: int, ingredient_name: String, scale_factor: float = 1.15) -> void:
	var sw = 48.0 * scale_factor
	var sh = 38.0 * scale_factor
	var c_base = center_base
	
	# Shadow under sack
	canvas.draw_circle(c_base + Vector2(0, 2), sw * 0.52, Color(0, 0, 0, 0.35))
	
	# Plump canvas burlap sack
	var sack_pts = PackedVector2Array([
		c_base + Vector2(-sw * 0.45, 0),
		c_base + Vector2(sw * 0.45, 0),
		c_base + Vector2(sw * 0.5, -sh * 0.5),
		c_base + Vector2(sw * 0.38, -sh * 0.85),
		c_base + Vector2(sw * 0.15, -sh * 0.88),
		c_base + Vector2(sw * 0.22, -sh),
		c_base + Vector2(-sw * 0.22, -sh),
		c_base + Vector2(-sw * 0.15, -sh * 0.88),
		c_base + Vector2(-sw * 0.38, -sh * 0.85),
		c_base + Vector2(-sw * 0.5, -sh * 0.5)
	])
	canvas.draw_colored_polygon(sack_pts, Color("#f3f4f6"))
	canvas.draw_polyline(sack_pts, Color("#9ca3af"), 1.2 * scale_factor)
	
	# Tied rope cord
	canvas.draw_line(c_base + Vector2(-sw * 0.16, -sh * 0.88), c_base + Vector2(sw * 0.16, -sh * 0.88), Color("#b45309"), 2.5 * scale_factor)
	
	# Weight label & ingredient name
	var font_size = clamp(int(10.0 * scale_factor), 9, 13)
	canvas.draw_string(ThemeDB.fallback_font, Vector2(c_base.x - sw * 0.5, c_base.y - sh * 0.35), "%d kg" % weight_val, HORIZONTAL_ALIGNMENT_CENTER, sw, font_size, Color("#1f2937"))
	canvas.draw_string(ThemeDB.fallback_font, Vector2(c_base.x - 65, c_base.y + 14), ingredient_name, HORIZONTAL_ALIGNMENT_CENTER, 130, 8, Color("#9ca3af"))


static func draw_scale_pan_static(canvas: CanvasItem, p_tip: Vector2, p_pan: Vector2, width: float, brass_col: Color) -> void:
	# 1. 3D Hanging Chains (left, right, and center-rear with depth)
	var chain_col = Color(0.65, 0.65, 0.65, 0.65)
	var rear_chain_col = Color(0.45, 0.45, 0.45, 0.4)
	
	# Rear center chain
	canvas.draw_line(p_tip, p_pan + Vector2(0, -3.0), rear_chain_col, 1.2)
	# Left & right outer chains
	canvas.draw_line(p_tip, p_pan + Vector2(-width * 0.46, 0), chain_col, 1.6)
	canvas.draw_line(p_tip, p_pan + Vector2(width * 0.46, 0), chain_col, 1.6)
	
	# Suspension rings at pan rim
	canvas.draw_circle(p_pan + Vector2(-width * 0.46, 0), 2.5, Color("#d97706"))
	canvas.draw_circle(p_pan + Vector2(width * 0.46, 0), 2.5, Color("#d97706"))
	canvas.draw_circle(p_tip, 3.0, Color("#d97706"))

	# 2. Shallow brass dish (curved under-body)
	var half_w = width * 0.5
	var dish_depth = 11.0
	var segs = 20
	var dish_pts = PackedVector2Array()
	dish_pts.append(p_pan + Vector2(-half_w, 0))
	for s in range(segs + 1):
		var t = float(s) / float(segs)
		var ang = PI * t
		var x = -half_w + (width * t)
		var y = sin(ang) * dish_depth
		dish_pts.append(p_pan + Vector2(x, y))
	dish_pts.append(p_pan + Vector2(half_w, 0))
	
	# Shaded dish body
	canvas.draw_colored_polygon(dish_pts, Color("#b45309"))
	canvas.draw_polyline(dish_pts, Color("#78350f"), 1.5)
	
	# Specular sheen on dish bottom
	canvas.draw_arc(p_pan + Vector2(0, 4), half_w * 0.7, deg_to_rad(30), deg_to_rad(150), 16, Color(1.0, 0.95, 0.6, 0.35), 1.5)

	# 3. Polished brass rim with upper highlight
	canvas.draw_line(p_pan + Vector2(-half_w, 0), p_pan + Vector2(half_w, 0), brass_col, 3.5)
	canvas.draw_line(p_pan + Vector2(-half_w + 3, -1.0), p_pan + Vector2(half_w - 3, -1.0), Color("#fef08a"), 1.2)
	canvas.draw_line(p_pan + Vector2(-half_w, 1.5), p_pan + Vector2(half_w, 1.5), Color("#78350f"), 1.0)


enum Phase {
	WEIGHING,
	HEATING,
	TIMING,
	FINISHED
}

# UI Nodes
@onready var back_btn: Button = $TopBar/BackBtn
@onready var bread_counter: Label = $TopBar/BreadLabel
@onready var level_selector: OptionButton = $TopBar/LevelSelector
@onready var phase_label: Label = $TopBar/PhaseLabel
@onready var mute_btn: Button = $TopBar/MuteBtn

# Phase 1: Scale Nodes
@onready var scale_panel: Control = $MainArea/ScaleArea
@onready var scale_draw: Control = $MainArea/ScaleArea/ScaleDrawArea
@onready var weights_shelf: HBoxContainer = $MainArea/ScaleArea/WeightsShelf
@onready var btn_clear_scale: Button = $MainArea/ScaleArea/BtnClearScale
@onready var recipe_label: Label = $MainArea/ScaleArea/RecipeLabel
@onready var flour_particles: CPUParticles2D = $MainArea/ScaleArea/FlourExplosion
@onready var spark_particles: CPUParticles2D = $MainArea/ScaleArea/SuccessSparkles

# Phase 2: Oven Nodes
@onready var oven_panel: Control = $MainArea/OvenArea
@onready var oven_visual: Panel = $MainArea/OvenArea/OvenVisual
@onready var oven_interior_draw: Control = $MainArea/OvenArea/OvenVisual/OvenOpening/OvenInteriorDrawArea
@onready var oven_overlay: Control = $MainArea/OvenArea/OvenOverlay
@onready var temp_label: Label = $MainArea/OvenArea/TempBox/TempLabel
@onready var temp_bar: ProgressBar = $MainArea/OvenArea/TempBox/TempBar
@onready var oven_fire_particles: CPUParticles2D = $MainArea/OvenArea/OvenVisual/FireParticles
@onready var wood_shelf: HBoxContainer = $MainArea/OvenArea/WoodShelf
@onready var btn_cool_oven: Button = $MainArea/OvenArea/BtnCoolOven

# Phase 3: Clock Nodes
@onready var clock_panel: Control = $MainArea/ClockArea
@onready var clock_draw: Control = $MainArea/ClockArea/ClockDrawArea
@onready var clock_prompt: Label = $MainArea/ClockArea/ClockPrompt
@onready var clock_time_label: Label = $MainArea/ClockArea/ClockTimeBox/ClockTimeLabel
@onready var btn_confirm_clock: Button = $MainArea/ClockArea/ClockControls/BtnConfirmClock
@onready var btn_reset_clock: Button = $MainArea/ClockArea/ClockControls/BtnResetClock
var clock_choices: Node = null

# Phase 4: Result Nodes
@onready var result_panel: PanelContainer = $ResultPanel
@onready var result_title: Label = $ResultPanel/VBox/ResultTitle
@onready var result_desc: Label = $ResultPanel/VBox/ResultDesc
@onready var btn_bake_again: Button = $ResultPanel/VBox/BtnRow/BtnBakeAgain
@onready var btn_back_village: Button = $ResultPanel/VBox/BtnRow/BtnBackVillage

# Drag & Drop Weights State
var is_dragging_weight: bool = false
var dragged_weight_value: int = 0
var drag_weight_screen_pos: Vector2 = Vector2.ZERO
var drag_weight_origin: Vector2 = Vector2.ZERO

# Drag & Drop Wood State
var is_dragging_wood: bool = false
var dragged_wood_value: int = 0
var drag_wood_screen_pos: Vector2 = Vector2.ZERO
var drag_wood_origin: Vector2 = Vector2.ZERO

# Interactive Clock Drag State
var current_clock_hour: int = 8
var current_clock_minute: int = 0
var is_dragging_clock: bool = false

# Game State
var current_phase: Phase = Phase.WEIGHING
var selected_curriculum_level: int = 1

# --- Phase 1: Scale Physics State ---
var target_ingredient_name: String = "Königliches Feinmehl"
var target_weight: int = 10
var player_weights: Array[int] = []

var beam_angle: float = 0.0
var beam_angular_velocity: float = 0.0
const MAX_ANGLE: float = deg_to_rad(19.0)
const BEAM_HALF_LENGTH: float = 160.0
const CHAIN_LENGTH: float = 50.0
const PAN_WIDTH: float = 136.0

var scale_pivot_pos: Vector2 = Vector2(320.0, 102.0)
var balance_timer: float = 0.0
var catapult_cooldown: float = 0.0
var catapult_overlay_alpha: float = 0.0

# --- Phase 2: Oven State ---
var current_temp: int = 100
var target_temp: int = 180
var wood_logs: Array[int] = [5, 10, 20]

# --- Phase 3: Clock State ---
var clock_start_hour: int = 8
var clock_start_minute: int = 0
var baking_duration_minutes: int = 45
var correct_end_hour: int = 8
var correct_end_minute: int = 45
var clock_anim_minute: float = 0.0

func _ready() -> void:
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)
	if btn_clear_scale:
		btn_clear_scale.pressed.connect(_clear_scale)
	if btn_cool_oven:
		btn_cool_oven.pressed.connect(_cool_oven)
	if btn_bake_again:
		btn_bake_again.pressed.connect(_start_new_baking_session)
	if btn_back_village:
		btn_back_village.pressed.connect(_on_back_pressed)
	if mute_btn:
		_update_mute_btn()
		mute_btn.pressed.connect(_on_mute_pressed)
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").sound_mute_toggled.connect(func(_m): _update_mute_btn())
		
	if scale_draw:
		scale_draw.draw.connect(_on_scale_draw)
	if oven_interior_draw:
		oven_interior_draw.draw.connect(_on_oven_interior_draw)
	if oven_overlay:
		oven_overlay.draw.connect(_on_oven_overlay_draw)
	if clock_draw:
		clock_draw.draw.connect(_on_clock_draw)
	if btn_confirm_clock:
		btn_confirm_clock.pressed.connect(_on_clock_confirm_pressed)
	if btn_reset_clock:
		btn_reset_clock.pressed.connect(_reset_clock_to_start)

	_setup_level_selector()
	_update_bread_display()
	_start_new_baking_session()
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_music("village")

func _update_mute_btn() -> void:
	if not mute_btn:
		return
	var is_muted = false
	if has_node("/root/AudioManager"):
		is_muted = get_node("/root/AudioManager").is_master_muted()
	mute_btn.text = "🔇" if is_muted else "🔊"
	mute_btn.modulate = Color(0.9, 0.4, 0.4) if is_muted else Color(1, 1, 1)

func _on_mute_pressed() -> void:
	if has_node("/root/AudioManager"):
		var am = get_node("/root/AudioManager")
		var was_muted = am.is_master_muted()
		var new_muted = am.toggle_mute()
		if was_muted:
			am.play_sfx("click")
		_update_mute_btn()

func _on_back_pressed() -> void:
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("click")
	get_tree().change_scene_to_file("res://scenes/village/VillageHub.tscn" if ResourceLoader.exists("res://scenes/village/VillageHub.tscn") else "res://scenes/menu/TitleScreen.tscn")

func _setup_level_selector() -> void:
	if not level_selector:
		return
	level_selector.clear()
	level_selector.add_item("Stufe L1: Basis 10 (Verliebt)", 1)
	level_selector.add_item("Stufe L2: Bis 20 (Ohne Übergang)", 2)
	level_selector.add_item("Stufe L3: Zehnerübergang & Uhrzeit", 3)
	level_selector.add_item("Stufe L4: Hunderterraum (±5/10/20)", 4)
	level_selector.add_item("Stufe L5: Einmaleins Mengen", 5)
	level_selector.add_item("Stufe L6: Division Teigteilen", 6)
	
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		selected_curriculum_level = clamp(sm.highest_unlocked_curriculum, 1, 6)
	level_selector.select(selected_curriculum_level - 1)
	level_selector.item_selected.connect(func(idx: int):
		selected_curriculum_level = idx + 1
		_start_new_baking_session()
	)

func _update_bread_display() -> void:
	if bread_counter and has_node("/root/SaveManager"):
		bread_counter.text = "🥖 %d" % get_node("/root/SaveManager").bread

func _start_new_baking_session() -> void:
	if result_panel:
		result_panel.visible = false
	current_phase = Phase.WEIGHING
	_setup_phase_visibility()
	_setup_weighing_problem()

func _setup_phase_visibility() -> void:
	if scale_panel: scale_panel.visible = (current_phase == Phase.WEIGHING)
	if oven_panel: oven_panel.visible = (current_phase == Phase.HEATING)
	if clock_panel: clock_panel.visible = (current_phase == Phase.TIMING)
	if result_panel and current_phase != Phase.FINISHED: result_panel.visible = false

	if phase_label:
		match current_phase:
			Phase.WEIGHING: phase_label.text = "1. ZUTATEN ABWIEGEN (BALKENWAAGE)"
			Phase.HEATING: phase_label.text = "2. STEINOFEN ANHEIZEN (HOLZSCHÜTTEN)"
			Phase.TIMING: phase_label.text = "3. SCHLOSSUHR: BACKZEIT EINSTELLEN"
			Phase.FINISHED: phase_label.text = "4. KÖNIGSBROT FERTIG!"

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 1: BALKENWAAGE & PHYSIK
# ═══════════════════════════════════════════════════════════════════════════

func _setup_weighing_problem() -> void:
	player_weights.clear()
	beam_angle = 0.0
	beam_angular_velocity = 0.0
	balance_timer = 0.0
	catapult_cooldown = 0.0

	var ingredients = [
		"Königliches Feinmehl",
		"Feen-Kristallzucker",
		"Goldene Bäckershefe",
		"Drachen-Kakaopulver",
		"Mondstaub-Salz"
	]
	target_ingredient_name = ingredients.pick_random()

	# Determine target weight based on curriculum
	match selected_curriculum_level:
		1: # L1: Verliebte Zahlen zur 10 oder Verdoppeln/Halbieren (1..10)
			target_weight = 10
		2: # L2: Bis 20 ohne Zehnerübergang (12, 14, 15, 16, 17, 18)
			target_weight = [12, 14, 15, 16, 17, 18].pick_random()
		3: # L3: Mit Zehnerübergang (11, 13, 15, 17)
			target_weight = [11, 13, 15, 17].pick_random()
		4: # L4: Hunderterraum (25, 30, 40, 50)
			target_weight = [25, 30, 40, 50].pick_random()
		5: # L5: Multiplikation (3 Brote à 4kg = 12kg)
			target_weight = [12, 16, 18, 20, 24].pick_random()
		_:
			target_weight = [14, 18, 21, 24, 28].pick_random()

	if recipe_label:
		match selected_curriculum_level:
			1:
				recipe_label.text = "📜 REZEPT: Wiege genau 10 kg %s ab!\n(Finde die passende Kombination auf der rechten Schale)" % target_ingredient_name
			5:
				recipe_label.text = "📜 REZEPT: 3 Meisterbrote à 4 kg = %d kg %s abwiegen!" % [target_weight, target_ingredient_name]
			_:
				recipe_label.text = "📜 REZEPT: Wiege genau %d kg %s ab!" % [target_weight, target_ingredient_name]

	_setup_weights_shelf()
	if scale_draw:
		scale_draw.queue_redraw()

func _setup_weights_shelf() -> void:
	if not weights_shelf:
		return
	for ch in weights_shelf.get_children():
		ch.queue_free()

	# Available weight denominations
	var options: Array[int] = []
	match selected_curriculum_level:
		1: options = [1, 2, 3, 4, 5, 7]
		2: options = [1, 2, 4, 5, 10]
		3: options = [2, 3, 5, 7, 8, 10]
		4: options = [5, 10, 15, 20, 25]
		_: options = [2, 3, 4, 6, 8, 10]

	for w in options:
		var item = WeightShelfItem.new(w)
		item.drag_started.connect(_start_dragging_weight)
		weights_shelf.add_child(item)

func _start_dragging_weight(w: int, global_pos: Vector2) -> void:
	is_dragging_weight = true
	dragged_weight_value = w
	drag_weight_screen_pos = global_pos
	drag_weight_origin = global_pos
	if scale_draw:
		scale_draw.queue_redraw()

func _finish_dragging_weight(release_pos: Vector2) -> void:
	if not is_dragging_weight:
		return
	is_dragging_weight = false
	var target_pos = _get_right_pan_global_pos()
	var dist = release_pos.distance_to(target_pos)
	var traveled = release_pos.distance_to(drag_weight_origin)
	
	# Dropped on right pan, or tapped on shelf
	if dist <= 120.0 or traveled < 16.0:
		_add_player_weight(dragged_weight_value)
	
	if scale_draw:
		scale_draw.queue_redraw()

func _remove_top_weight() -> void:
	if player_weights.size() > 0:
		var removed = player_weights.pop_back()
		beam_angular_velocity -= 1.6
		var target_pos = _get_right_pan_global_pos()
		JuiceManager.spawn_comic_popup(self, "-%d kg 💨" % removed, target_pos + Vector2(0, -30), "block")
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx("click", 0.9, 0.4)
		if scale_draw:
			scale_draw.queue_redraw()

func _get_right_pan_global_pos() -> Vector2:
	var beam_vec = Vector2(BEAM_HALF_LENGTH, 0).rotated(beam_angle)
	var p_right_tip = scale_pivot_pos + beam_vec
	var p_right_pan = p_right_tip + Vector2(0, CHAIN_LENGTH)
	if scale_draw and scale_draw.is_inside_tree():
		return scale_draw.get_global_transform() * p_right_pan
	return p_right_pan

func _add_player_weight(w: int) -> void:
	player_weights.append(w)
	beam_angular_velocity += 1.8 # Kick impulse
	var target_pos = _get_right_pan_global_pos()
	JuiceManager.spawn_comic_popup(self, "+%d kg" % w, target_pos + Vector2(0, -30), "attack")
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("click", 1.2, 0.6)
	if scale_draw:
		scale_draw.queue_redraw()

func _clear_scale() -> void:
	if player_weights.size() > 0:
		player_weights.clear()
		beam_angular_velocity -= 2.0
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx("click", 0.9, 0.4)
		if scale_draw:
			scale_draw.queue_redraw()

func _get_total_player_weight() -> int:
	var s = 0
	for w in player_weights:
		s += w
	return s

func _process(delta: float) -> void:
	if catapult_cooldown > 0.0:
		catapult_cooldown -= delta
	if catapult_overlay_alpha > 0.0:
		catapult_overlay_alpha = max(0.0, catapult_overlay_alpha - delta * 0.8)
		if scale_draw:
			scale_draw.queue_redraw()

	if current_phase == Phase.WEIGHING:
		_process_scale_physics(delta)
	elif current_phase == Phase.HEATING:
		if oven_interior_draw:
			oven_interior_draw.queue_redraw()
	elif current_phase == Phase.TIMING:
		if clock_draw:
			clock_draw.queue_redraw()

func _process_scale_physics(delta: float) -> void:
	var total_right = _get_total_player_weight()
	var delta_w = float(total_right - target_weight)

	# Realistic torque & spring simulation
	# Torque proportional to weight difference
	var torque = clamp(delta_w * 0.45, -3.5, 3.5)
	var spring_k = 2.4
	var damping_d = 3.6

	var angular_accel = torque - (spring_k * beam_angle) - (damping_d * beam_angular_velocity)
	beam_angular_velocity += angular_accel * delta
	beam_angle += beam_angular_velocity * delta

	# Bumper collision at limits
	if abs(beam_angle) > MAX_ANGLE:
		beam_angle = clamp(beam_angle, -MAX_ANGLE, MAX_ANGLE)
		
		# Extreme imbalance or slam -> TRIGGER FUNNY CATAPULT EFFECT!
		if abs(delta_w) >= 6 and catapult_cooldown <= 0.0 and abs(beam_angular_velocity) > 1.2:
			_trigger_catapult_effect(delta_w > 0)
			
		beam_angular_velocity = -beam_angular_velocity * 0.3 # Bounce back

	# Check Perfect Balance (delta_w == 0 and settled near center)
	if delta_w == 0 and abs(beam_angle) < deg_to_rad(2.0):
		balance_timer += delta
		if balance_timer >= 0.45:
			_trigger_scale_success()
	else:
		balance_timer = 0.0

	if scale_draw:
		scale_draw.queue_redraw()

func _trigger_catapult_effect(heavy_right: bool) -> void:
	catapult_cooldown = 1.6
	catapult_overlay_alpha = 0.85

	# Calculate launching pan position
	var sign_dir = 1.0 if heavy_right else -1.0
	var launch_pan_x = scale_pivot_pos.x - (sign_dir * BEAM_HALF_LENGTH)
	var launch_pos = Vector2(launch_pan_x, scale_pivot_pos.y)
	var global_launch = scale_draw.get_global_transform() * launch_pos if (scale_draw and scale_draw.is_inside_tree()) else launch_pos

	if flour_particles:
		flour_particles.global_position = global_launch
		flour_particles.emitting = true

	JuiceManager.spawn_comic_popup(self, "KATAPULT! 💨", global_launch + Vector2(0, -30), "defeat")
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("sword_slash", 1.8, 1.2)
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").screen_shake_requested.emit(0.2)

func _trigger_scale_success() -> void:
	current_phase = Phase.HEATING
	var global_pivot = scale_draw.get_global_transform() * scale_pivot_pos if (scale_draw and scale_draw.is_inside_tree()) else scale_pivot_pos
	if spark_particles:
		spark_particles.global_position = global_pivot
		spark_particles.emitting = true
		
	JuiceManager.spawn_comic_popup(self, "PERFEKT ABGEWOGEN! ✨", global_pivot + Vector2(0, -40), "flawless")
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("levelup", 1.2, 1.0)
		
	# Short delay then show Oven Phase
	var tw = create_tween()
	tw.tween_interval(0.65)
	tw.tween_callback(func():
		_setup_phase_visibility()
		_setup_oven_problem()
	)

func _on_scale_draw() -> void:
	if not scale_draw:
		return

	# Draw Catapult Flour Smudge Overlay if active
	if catapult_overlay_alpha > 0.01:
		scale_draw.draw_circle(Vector2(scale_pivot_pos.x - 60, scale_pivot_pos.y - 20), 45.0, Color(1, 1, 1, catapult_overlay_alpha * 0.35))
		scale_draw.draw_circle(Vector2(scale_pivot_pos.x - 40, scale_pivot_pos.y - 10), 30.0, Color(0.95, 0.95, 1, catapult_overlay_alpha * 0.45))
		scale_draw.draw_string(ThemeDB.fallback_font, Vector2(scale_pivot_pos.x - 90, scale_pivot_pos.y - 25), "*PUFF! MEHLWOLKE!*", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(1, 1, 1, catapult_overlay_alpha))

	# 1. Central Pillar (Fulcrum)
	var pillar_col = Color("#374151")
	var brass_col = Color("#f59e0b")
	var needle_col = Color("#ef4444")
	var balanced_col = Color("#22c55e")

	# Base & Pillar
	scale_draw.draw_rect(Rect2(scale_pivot_pos.x - 36, scale_pivot_pos.y + 70, 72, 12), pillar_col, true)
	scale_draw.draw_rect(Rect2(scale_pivot_pos.x - 8, scale_pivot_pos.y - 6, 16, 80), pillar_col, true)
	scale_draw.draw_circle(scale_pivot_pos, 10.0, brass_col)

	# 2. Rotating Beam
	var beam_vec = Vector2(BEAM_HALF_LENGTH, 0).rotated(beam_angle)
	var p_left_tip = scale_pivot_pos - beam_vec
	var p_right_tip = scale_pivot_pos + beam_vec

	scale_draw.draw_line(p_left_tip, p_right_tip, brass_col, 5.0)

	# 3. Needle / Pointer (points upward perpendicular to beam)
	var needle_vec = Vector2(0, -32).rotated(beam_angle)
	var needle_tip = scale_pivot_pos + needle_vec
	var is_balanced = (_get_total_player_weight() == target_weight and abs(beam_angle) < deg_to_rad(3.0))
	scale_draw.draw_line(scale_pivot_pos, needle_tip, balanced_col if is_balanced else needle_col, 2.5)

	# Center balance arc guide
	scale_draw.draw_arc(scale_pivot_pos, 32.0, deg_to_rad(-105), deg_to_rad(-75), 12, Color(0.3, 0.8, 0.4, 0.4), 3.0)
	scale_draw.draw_line(scale_pivot_pos + Vector2(0, -28), scale_pivot_pos + Vector2(0, -36), balanced_col, 2.0)

	# 4. Left Pan (Target Ingredient)
	var p_left_pan = p_left_tip + Vector2(0, CHAIN_LENGTH)
	Bakery.draw_scale_pan_static(scale_draw, p_left_tip, p_left_pan, PAN_WIDTH, brass_col)
	Bakery.draw_flour_sack_static(scale_draw, p_left_pan + Vector2(0, -2), target_weight, target_ingredient_name, 1.15)

	# 5. Right Pan (Player Weights)
	var p_right_pan = p_right_tip + Vector2(0, CHAIN_LENGTH)
	Bakery.draw_scale_pan_static(scale_draw, p_right_tip, p_right_pan, PAN_WIDTH, brass_col)

	# Drop Target Halo when dragging a weight
	if is_dragging_weight:
		var pulse = 0.6 + sin(Time.get_ticks_msec() * 0.009) * 0.35
		scale_draw.draw_arc(p_right_pan + Vector2(0, -18), PAN_WIDTH * 0.48, 0, TAU, 32, Color(1.0, 0.85, 0.2, pulse), 2.8)
		scale_draw.draw_string(ThemeDB.fallback_font, p_right_pan + Vector2(-60, -60), "⬇ HIER ABLEGEN", HORIZONTAL_ALIGNMENT_CENTER, 120, 9, Color(1.0, 0.85, 0.2, pulse))

	# Draw realistic brass weights on right pan (arranged nebeneinander / side-by-side!)
	var n_weights = player_weights.size()
	if n_weights <= 5:
		# All weights in a single row, perfectly distributed side-by-side across the wide pan
		var spacing = clamp(116.0 / float(max(n_weights, 1)), 26.0, 38.0)
		for i in range(n_weights):
			var w = player_weights[i]
			var x_offset = (i - (n_weights - 1) * 0.5) * spacing
			var pos = p_right_pan + Vector2(x_offset, -2.0)
			Bakery.draw_brass_weight_static(scale_draw, pos, w, false, false, 0.85)
	else:
		# Two rows if more than 5 weights
		var row1_count = min(n_weights, 5)
		var row2_count = n_weights - row1_count
		var spacing1 = 116.0 / float(row1_count)
		for i in range(row1_count):
			var w = player_weights[i]
			var x_offset = (i - (row1_count - 1) * 0.5) * spacing1
			var pos = p_right_pan + Vector2(x_offset, -2.0)
			Bakery.draw_brass_weight_static(scale_draw, pos, w, false, false, 0.82)
		var spacing2 = clamp(96.0 / float(max(row2_count, 1)), 22.0, 32.0)
		for j in range(row2_count):
			var w = player_weights[row1_count + j]
			var x_offset = (j - (row2_count - 1) * 0.5) * spacing2
			var pos = p_right_pan + Vector2(x_offset, -18.0)
			Bakery.draw_brass_weight_static(scale_draw, pos, w, false, false, 0.78)

	# If currently dragging, draw realistic brass weight following finger
	if is_dragging_weight:
		var local_drag = scale_draw.get_global_transform().affine_inverse() * drag_weight_screen_pos
		Bakery.draw_brass_weight_static(scale_draw, local_drag + Vector2(0, 10), dragged_weight_value, true, true, 1.1)

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 2: STEINOFEN & HOLZSCHEITE
# ═══════════════════════════════════════════════════════════════════════════

func _setup_oven_problem() -> void:
	current_temp = 100
	match selected_curriculum_level:
		1:
			target_temp = 120 # Need +20°
			wood_logs = [5, 10, 20]
		2:
			target_temp = 150 # Need +50°
			wood_logs = [5, 10, 20]
		3:
			target_temp = 180 # Need +80°
			wood_logs = [5, 15, 25, 40]
		4: # L4: Steps of ±5, ±10, ±20
			target_temp = 200 # Need +100°
			wood_logs = [10, 20, 50]
		_:
			target_temp = 180
			wood_logs = [10, 20, 30]

	_update_temp_display()
	_setup_wood_shelf()

func _update_temp_display() -> void:
	if temp_label:
		temp_label.text = "OFENTEMPERATUR: %d°C / ZIEL: %d°C" % [current_temp, target_temp]
	if temp_bar:
		temp_bar.min_value = 100
		temp_bar.max_value = target_temp + 30
		temp_bar.value = current_temp

	# Fire particle scale
	if oven_fire_particles:
		var ratio = clamp(float(current_temp - 100) / max(float(target_temp - 100), 1.0), 0.2, 1.5)
		oven_fire_particles.scale_amount_min = 2.0 * ratio
		oven_fire_particles.scale_amount_max = 5.0 * ratio
		oven_fire_particles.emitting = true

func _setup_wood_shelf() -> void:
	if not wood_shelf:
		return
	for ch in wood_shelf.get_children():
		ch.queue_free()

	for log_val in wood_logs:
		var item = WoodShelfItem.new(log_val)
		item.drag_started.connect(_start_dragging_wood)
		wood_shelf.add_child(item)

func _start_dragging_wood(val: int, global_pos: Vector2) -> void:
	is_dragging_wood = true
	dragged_wood_value = val
	drag_wood_screen_pos = global_pos
	drag_wood_origin = global_pos
	if oven_overlay:
		oven_overlay.queue_redraw()

func _finish_dragging_wood(release_pos: Vector2) -> void:
	if not is_dragging_wood:
		return
	is_dragging_wood = false
	var target_pos = _get_oven_mouth_global_pos()
	var dist = release_pos.distance_to(target_pos)
	var traveled = release_pos.distance_to(drag_wood_origin)
	
	# Dropped into oven mouth or tapped on shelf
	if dist <= 130.0 or traveled < 16.0:
		_add_wood_log(dragged_wood_value)
		
	if oven_overlay:
		oven_overlay.queue_redraw()

func _get_oven_mouth_global_pos() -> Vector2:
	if oven_visual and oven_visual.is_inside_tree():
		return oven_visual.get_global_transform() * (oven_visual.size * 0.5)
	return Vector2(320.0, 125.0)

func _on_oven_interior_draw() -> void:
	if not oven_interior_draw:
		return
	var w = oven_interior_draw.size.x
	var h = oven_interior_draw.size.y
	if w <= 0.0 or h <= 0.0:
		return
		
	# 1. Dark arched oven cavity background
	var bg_rect = Rect2(0, 0, w, h)
	oven_interior_draw.draw_rect(bg_rect, Color("#180c06"))
	
	# 2. Glowing ember bed (Glutbett) with heat-based pulsation
	var pulse = sin(Time.get_ticks_msec() * 0.005) * 0.15 + 0.85
	var heat_ratio = clamp(float(current_temp - 100) / max(float(target_temp - 100), 1.0), 0.2, 1.4)
	
	# Deep red bottom glow
	var bed_h = h * 0.52
	oven_interior_draw.draw_rect(Rect2(0, h - bed_h, w, bed_h), Color(0.6 * heat_ratio, 0.1, 0.02, 0.7 * pulse))
	
	# Bright orange/yellow core embers
	var ember_pts = PackedVector2Array([
		Vector2(w * 0.08, h),
		Vector2(w * 0.24, h - bed_h * 0.75 * pulse),
		Vector2(w * 0.50, h - bed_h * 0.92 * pulse),
		Vector2(w * 0.76, h - bed_h * 0.72 * pulse),
		Vector2(w * 0.92, h)
	])
	oven_interior_draw.draw_colored_polygon(ember_pts, Color(0.95 * heat_ratio, 0.38 * pulse, 0.05, 0.75))
	
	# Hot white-yellow focal coals
	oven_interior_draw.draw_circle(Vector2(w * 0.42, h - 12), 10.0 * pulse, Color(1.0, 0.85, 0.3, 0.65 * pulse))
	oven_interior_draw.draw_circle(Vector2(w * 0.58, h - 10), 8.0 * pulse, Color(1.0, 0.75, 0.2, 0.65 * pulse))

	# 3. Burning split firewood logs resting inside the coal bed
	# Back log (tilted)
	var log1_c = Vector2(w * 0.35, h - 14)
	oven_interior_draw.draw_line(log1_c + Vector2(-22, 6), log1_c + Vector2(22, -6), Color("#271206"), 7.0)
	oven_interior_draw.draw_line(log1_c + Vector2(-20, 5), log1_c + Vector2(20, -5), Color("#ea580c"), 3.0)
	# Front log (horizontal)
	var log2_c = Vector2(w * 0.62, h - 11)
	oven_interior_draw.draw_line(log2_c + Vector2(-25, 0), log2_c + Vector2(25, 0), Color("#1c0a02"), 8.0)
	oven_interior_draw.draw_line(log2_c + Vector2(-23, 0), log2_c + Vector2(23, 0), Color("#f97316"), 3.5)
	oven_interior_draw.draw_circle(log2_c + Vector2(22, 0), 3.5, Color("#facc15"))

func _on_oven_overlay_draw() -> void:
	if not oven_overlay:
		return
	if is_dragging_wood:
		var mouth_pos = _get_oven_mouth_global_pos()
		var local_mouth = oven_overlay.get_global_transform().affine_inverse() * mouth_pos
		var pulse = 0.65 + sin(Time.get_ticks_msec() * 0.01) * 0.35
		
		# Fiery target halo over the stone oven
		oven_overlay.draw_arc(local_mouth, 52.0, 0, TAU, 32, Color(1.0, 0.45, 0.1, pulse), 3.5)
		oven_overlay.draw_arc(local_mouth, 46.0, 0, TAU, 28, Color(1.0, 0.8, 0.2, pulse * 0.7), 1.5)
		oven_overlay.draw_string(ThemeDB.fallback_font, local_mouth + Vector2(-75, -60), "⬇ IN DEN OFEN WERFEN 🔥", HORIZONTAL_ALIGNMENT_CENTER, 150, 10, Color(1.0, 0.85, 0.25, pulse))
		
		# Floating dragged firewood log with bark, grain, and temperature brand
		var local_drag = oven_overlay.get_global_transform().affine_inverse() * drag_wood_screen_pos
		Bakery.draw_firewood_log_static(oven_overlay, local_drag, dragged_wood_value, true, true, 1.2)

func _add_wood_log(val: int) -> void:
	current_temp += val
	_update_temp_display()
	
	JuiceManager.spawn_comic_popup(self, "+%d°C 🔥" % val, Vector2(320, 150), "attack")
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("sword_slash", 1.5, 0.8)

	if current_temp == target_temp:
		_trigger_oven_success()
	elif current_temp > target_temp:
		JuiceManager.spawn_comic_popup(self, "ZU HEISS! 💨", Vector2(320, 110), "defeat")
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx("wrong", 0.9, 0.4)

func _cool_oven() -> void:
	if current_temp > 100:
		current_temp = max(100, current_temp - 15)
		_update_temp_display()
		JuiceManager.spawn_comic_popup(self, "LÜFTEN: -15°C ❄️", Vector2(320, 110), "block")
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx("click", 0.7, 0.5)

func _trigger_oven_success() -> void:
	current_phase = Phase.TIMING
	JuiceManager.spawn_comic_popup(self, "HITZE PERFEKT! 🔥", Vector2(320, 120), "flawless")
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("levelup", 1.1, 1.0)
		
	var tw = create_tween()
	tw.tween_interval(0.65)
	tw.tween_callback(func():
		_setup_phase_visibility()
		_setup_clock_problem()
	)

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 3: SCHLOSSUHR & BACKZEIT
# ═══════════════════════════════════════════════════════════════════════════

func _setup_clock_problem() -> void:
	clock_start_hour = randi_range(7, 10)
	
	match selected_curriculum_level:
		1:
			clock_start_minute = 0
			baking_duration_minutes = [10, 20, 30].pick_random()
		2: # Without hour crossing
			clock_start_minute = 10
			baking_duration_minutes = [15, 20, 25].pick_random()
		3: # WITH hour crossing (Didactic L3 focus!)
			clock_start_minute = [35, 40, 45, 50].pick_random()
			baking_duration_minutes = [25, 30, 35, 40].pick_random()
		_:
			clock_start_minute = [15, 30, 45].pick_random()
			baking_duration_minutes = [30, 45, 60].pick_random()

	var total_minutes = (clock_start_hour * 60) + clock_start_minute + baking_duration_minutes
	correct_end_hour = (total_minutes / 60) % 24
	correct_end_minute = total_minutes % 60

	current_clock_hour = clock_start_hour
	current_clock_minute = clock_start_minute

	if clock_prompt:
		clock_prompt.text = "⏰ REZEPT: Das Brot kommt um %02d:%02d Uhr in den Ofen.\nBackdauer: %d Minuten!\n➜ Drehe den roten Zeiger mit dem Finger auf die fertige Zeit!" % [
			clock_start_hour, clock_start_minute, baking_duration_minutes
		]

	_update_clock_display()
	if clock_draw:
		clock_draw.queue_redraw()

func _update_clock_display() -> void:
	if clock_time_label:
		clock_time_label.text = "⏰ EINGESTELLT: %02d:%02d UHR" % [current_clock_hour, current_clock_minute]

func _reset_clock_to_start() -> void:
	current_clock_hour = clock_start_hour
	current_clock_minute = clock_start_minute
	_update_clock_display()
	if clock_draw:
		clock_draw.queue_redraw()
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("click", 1.0, -2.0)

func _get_clock_global_center() -> Vector2:
	var center = Vector2(90, 90)
	if clock_draw and clock_draw.is_inside_tree():
		return clock_draw.get_global_transform() * center
	return center

func _update_clock_from_touch(touch_pos: Vector2) -> void:
	var center = _get_clock_global_center()
	var diff = touch_pos - center
	if diff.length() < 12.0:
		return
		
	var angle_rad = atan2(diff.y, diff.x)
	var deg = rad_to_deg(angle_rad) + 90.0
	if deg < 0.0:
		deg += 360.0
	var raw_minutes = (deg / 360.0) * 60.0
	var snapped = int(round(raw_minutes / 5.0)) * 5
	if snapped >= 60:
		snapped = 0
		
	# Check clockwise rotation crossing 12 o'clock
	if current_clock_minute >= 45 and snapped <= 15:
		current_clock_hour = (current_clock_hour + 1) % 24
	# Check counter-clockwise rotation crossing 12 o'clock
	elif current_clock_minute <= 15 and snapped >= 45:
		current_clock_hour = (current_clock_hour - 1 + 24) % 24
		
	if snapped != current_clock_minute:
		current_clock_minute = snapped
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx("click", 1.4, -6.0)
		_update_clock_display()
		if clock_draw:
			clock_draw.queue_redraw()

func _on_clock_confirm_pressed() -> void:
	var total_dialed = (current_clock_hour * 60) + current_clock_minute
	var total_target = (correct_end_hour * 60) + correct_end_minute
	var diff = total_dialed - total_target
	var clock_center = _get_clock_global_center()
	
	if diff == 0:
		JuiceManager.spawn_comic_popup(self, "DING-DONG! 🔔", clock_center + Vector2(0, -60), "flawless")
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx("levelup", 1.2, 1.0)
		_trigger_baking_completed()
	elif diff < 0:
		# Too early
		var missing = abs(diff)
		JuiceManager.spawn_comic_popup(self, "NOCH %d MINUTEN! ⏳" % missing, clock_center + Vector2(0, -60), "defeat")
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx("wrong", 0.9, 0.5)
	else:
		# Too late
		var over = diff
		JuiceManager.spawn_comic_popup(self, "ZU SPÄT (+%d MIN)! 💨" % over, clock_center + Vector2(0, -60), "defeat")
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx("wrong", 0.8, 0.5)

func _on_clock_draw() -> void:
	if not clock_draw:
		return
	var center = Vector2(90, 90)
	var radius = 72.0

	# Antique Clock Frame
	clock_draw.draw_circle(center, radius + 8.0, Color("#451a03"))
	clock_draw.draw_circle(center, radius + 4.0, Color("#d97706"))
	clock_draw.draw_circle(center, radius, Color("#fef3c7"))
	clock_draw.draw_arc(center, radius - 14.0, 0, TAU, 32, Color(0.7, 0.6, 0.4, 0.35), 1.0)

	# Hour numbers 12, 3, 6, 9
	clock_draw.draw_string(ThemeDB.fallback_font, center + Vector2(-15, -radius + 20), "12", HORIZONTAL_ALIGNMENT_CENTER, 30, 10, Color("#78350f"))
	clock_draw.draw_string(ThemeDB.fallback_font, center + Vector2(radius - 22, 4), "3", HORIZONTAL_ALIGNMENT_CENTER, 20, 10, Color("#78350f"))
	clock_draw.draw_string(ThemeDB.fallback_font, center + Vector2(-10, radius - 8), "6", HORIZONTAL_ALIGNMENT_CENTER, 20, 10, Color("#78350f"))
	clock_draw.draw_string(ThemeDB.fallback_font, center + Vector2(-radius + 4, 4), "9", HORIZONTAL_ALIGNMENT_CENTER, 20, 10, Color("#78350f"))

	# Hour ticks
	for i in range(12):
		var angle = deg_to_rad(i * 30.0 - 90.0)
		var tick_outer = center + Vector2(radius - 3.0, 0).rotated(angle)
		var tick_inner = center + Vector2(radius - 8.0, 0).rotated(angle)
		clock_draw.draw_line(tick_inner, tick_outer, Color("#92400e"), 2.0)

	# Blue Hour Hand (tracks current_clock_hour + minutes)
	var h_angle = deg_to_rad(((current_clock_hour % 12) + (float(current_clock_minute) / 60.0)) * 30.0 - 90.0)
	var h_tip = center + Vector2(radius * 0.52, 0).rotated(h_angle)
	clock_draw.draw_line(center, h_tip, Color("#1e3a8a"), 5.0)
	clock_draw.draw_line(center, h_tip, Color("#60a5fa"), 2.0)

	# Red Minute Hand (rotatable by player)
	var m_angle = deg_to_rad(float(current_clock_minute) * 6.0 - 90.0)
	var m_tip = center + Vector2(radius * 0.82, 0).rotated(m_angle)
	clock_draw.draw_line(center, m_tip, Color("#991b1b"), 3.5)
	clock_draw.draw_line(center, m_tip, Color("#ef4444"), 2.0)
	
	# Grab-Knob at minute hand tip (invites touch)
	clock_draw.draw_circle(m_tip, 9.0, Color("#ef4444"))
	clock_draw.draw_circle(m_tip, 6.0, Color("#fde047"))
	clock_draw.draw_circle(m_tip, 2.5, Color("#ffffff"))

	# Center brass pin
	clock_draw.draw_circle(center, 7.0, Color("#92400e"))
	clock_draw.draw_circle(center, 4.0, Color("#f59e0b"))

func _input(event: InputEvent) -> void:
	if current_phase == Phase.WEIGHING:
		if is_dragging_weight:
			if event is InputEventMouseMotion or event is InputEventScreenDrag:
				drag_weight_screen_pos = event.position
				if scale_draw:
					scale_draw.queue_redraw()
			elif (event is InputEventMouseButton and not event.pressed) or (event is InputEventScreenTouch and not event.pressed):
				_finish_dragging_weight(event.position)
		elif (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
			# Tap right pan directly to remove top weight
			var r_pan = _get_right_pan_global_pos()
			if event.position.distance_to(r_pan) < 70.0:
				_remove_top_weight()
				
	elif current_phase == Phase.HEATING:
		if is_dragging_wood:
			if event is InputEventMouseMotion or event is InputEventScreenDrag:
				drag_wood_screen_pos = event.position
				if oven_overlay:
					oven_overlay.queue_redraw()
			elif (event is InputEventMouseButton and not event.pressed) or (event is InputEventScreenTouch and not event.pressed):
				_finish_dragging_wood(event.position)

	elif current_phase == Phase.TIMING:
		var clock_center = _get_clock_global_center()
		if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT) or event is InputEventScreenTouch:
			if event.pressed:
				if event.position.distance_to(clock_center) < 115.0:
					is_dragging_clock = true
					_update_clock_from_touch(event.position)
			else:
				is_dragging_clock = false
		elif event is InputEventMouseMotion or event is InputEventScreenDrag:
			if is_dragging_clock:
				_update_clock_from_touch(event.position)

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 4: ERGEBNIS & WIRTSCHAFTS-BELOHNUNG
# ═══════════════════════════════════════════════════════════════════════════

func _trigger_baking_completed() -> void:
	current_phase = Phase.FINISHED
	_setup_phase_visibility()

	# Rewards in SaveManager
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		sm.add_bread(1)
		sm.add_gold(25)
		sm.add_xp(40)
		_update_bread_display()

	if result_panel:
		result_panel.visible = true
	if result_title:
		result_title.text = "🥖 KÖNIGSBROT GEBACKEN!"
	if result_desc:
		result_desc.text = "Du hast das Mehl exakt abgewogen, den Ofen auf %d°C vorgeheizt und die Zeit perfekt berechnet!\n\nBelohnung:\n+1 Frisches Königsbrot 🥖\n+25 Gold 🪙\n+40 Ritter-XP ★" % target_temp
