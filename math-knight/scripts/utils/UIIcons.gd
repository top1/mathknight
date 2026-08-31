@tool
class_name UIIcon
extends Control
## Procedural vector icon renderer for MathKnight.
## Renders crisp, scalable game icons without relying on OS-dependent emoji fonts.

enum IconType {
	SWORD,
	FORGE,
	CROWN,
	HEART,
	STAR,
	HOME,
	ADD,
	SUB,
	MUL,
	DIV,
	MIX
}

@export var icon_type: IconType = IconType.SWORD:
	set(v):
		icon_type = v
		queue_redraw()

@export var icon_color: Color = Color.WHITE:
	set(v):
		icon_color = v
		queue_redraw()

@export var secondary_color: Color = Color(1.0, 0.85, 0.3):
	set(v):
		secondary_color = v
		queue_redraw()


func _draw() -> void:
	var s: Vector2 = size
	if s.x <= 0 or s.y <= 0:
		return

	var center: Vector2 = s * 0.5
	var min_dim: float = minf(s.x, s.y)
	var scale_factor: float = min_dim / 32.0

	match icon_type:
		IconType.SWORD:
			_draw_sword(center, scale_factor)
		IconType.FORGE:
			_draw_forge(center, scale_factor)
		IconType.CROWN:
			_draw_crown(center, scale_factor)
		IconType.HEART:
			_draw_heart(center, scale_factor)
		IconType.STAR:
			_draw_star(center, scale_factor)
		IconType.HOME:
			_draw_home(center, scale_factor)
		IconType.ADD:
			_draw_add(center, scale_factor)
		IconType.SUB:
			_draw_sub(center, scale_factor)
		IconType.MUL:
			_draw_mul(center, scale_factor)
		IconType.DIV:
			_draw_div(center, scale_factor)
		IconType.MIX:
			_draw_mix(center, scale_factor)


func _draw_sword(c: Vector2, sf: float) -> void:
	# Blade angled 45 degrees
	var tip: Vector2 = c + Vector2(10.0, -10.0) * sf
	var base: Vector2 = c + Vector2(-4.0, 4.0) * sf
	var hilt: Vector2 = c + Vector2(-9.0, 9.0) * sf
	var pommel: Vector2 = c + Vector2(-11.0, 11.0) * sf

	# Blade edge glow
	draw_line(base, tip, icon_color, 3.2 * sf, true)
	draw_line(base + Vector2(1, -1) * sf, tip, Color.WHITE, 1.2 * sf, true)

	# Crossguard
	var g1: Vector2 = base + Vector2(-5.0, -5.0) * sf
	var g2: Vector2 = base + Vector2(5.0, 5.0) * sf
	draw_line(g1, g2, secondary_color, 2.5 * sf, true)

	# Grip & Pommel
	draw_line(base, hilt, Color(0.35, 0.22, 0.15), 2.0 * sf, true)
	draw_circle(pommel, 2.2 * sf, secondary_color)


func _draw_forge(c: Vector2, sf: float) -> void:
	# Anvil base
	var base_rect: Rect2 = Rect2(c.x - 9.0 * sf, c.y + 4.0 * sf, 18.0 * sf, 4.0 * sf)
	draw_rect(base_rect, icon_color)
	# Anvil neck & horn
	var horn_pts: PackedVector2Array = PackedVector2Array([
		c + Vector2(-11.0, -2.0) * sf,
		c + Vector2(10.0, -2.0) * sf,
		c + Vector2(7.0, 4.0) * sf,
		c + Vector2(-6.0, 4.0) * sf
	])
	draw_colored_polygon(horn_pts, icon_color)
	# Hammer striking with sparks
	var hammer_pts: PackedVector2Array = PackedVector2Array([
		c + Vector2(-2.0, -10.0) * sf,
		c + Vector2(4.0, -8.0) * sf,
		c + Vector2(1.0, -3.0) * sf,
		c + Vector2(-5.0, -5.0) * sf
	])
	draw_colored_polygon(hammer_pts, secondary_color)
	# Spark dots
	draw_circle(c + Vector2(7.0, -6.0) * sf, 1.5 * sf, secondary_color)
	draw_circle(c + Vector2(10.0, -1.0) * sf, 1.2 * sf, Color(1.0, 0.95, 0.7))


func _draw_crown(c: Vector2, sf: float) -> void:
	# Golden royal crown
	var crown_pts: PackedVector2Array = PackedVector2Array([
		c + Vector2(-10.0, 6.0) * sf,
		c + Vector2(10.0, 6.0) * sf,
		c + Vector2(11.0, -4.0) * sf,
		c + Vector2(5.0, 0.0) * sf,
		c + Vector2(0.0, -8.0) * sf,
		c + Vector2(-5.0, 0.0) * sf,
		c + Vector2(-11.0, -4.0) * sf
	])
	draw_colored_polygon(crown_pts, secondary_color)
	# Jewels on peaks
	draw_circle(c + Vector2(0.0, -8.0) * sf, 2.0 * sf, Color(0.9, 0.2, 0.2)) # Ruby
	draw_circle(c + Vector2(-11.0, -4.0) * sf, 1.5 * sf, Color(0.2, 0.7, 0.9)) # Sapphire
	draw_circle(c + Vector2(11.0, -4.0) * sf, 1.5 * sf, Color(0.2, 0.7, 0.9)) # Sapphire
	# Crown band rim
	draw_line(c + Vector2(-10.0, 6.0) * sf, c + Vector2(10.0, 6.0) * sf, Color(0.65, 0.45, 0.1), 1.5 * sf)


func _draw_heart(c: Vector2, sf: float) -> void:
	# Dual-circle + triangle heart
	var r: float = 4.5 * sf
	var left_c: Vector2 = c + Vector2(-3.5 * sf, -2.0 * sf)
	var right_c: Vector2 = c + Vector2(3.5 * sf, -2.0 * sf)
	draw_circle(left_c, r, icon_color)
	draw_circle(right_c, r, icon_color)

	var bottom_pts: PackedVector2Array = PackedVector2Array([
		left_c + Vector2(-r * 0.95, 0.0),
		right_c + Vector2(r * 0.95, 0.0),
		c + Vector2(0.0, 9.0 * sf)
	])
	draw_colored_polygon(bottom_pts, icon_color)
	# Highlight shine
	draw_circle(left_c + Vector2(-1.5 * sf, -1.5 * sf), 1.5 * sf, Color(1.0, 0.7, 0.75, 0.8))


func _draw_star(c: Vector2, sf: float) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	var outer_r: float = 9.0 * sf
	var inner_r: float = 4.2 * sf
	for i in range(10):
		var angle: float = -PI / 2.0 + i * (PI / 5.0)
		var r: float = outer_r if i % 2 == 0 else inner_r
		pts.append(c + Vector2(cos(angle), sin(angle)) * r)
	draw_colored_polygon(pts, secondary_color)


func _draw_home(c: Vector2, sf: float) -> void:
	# Roof
	var roof_pts: PackedVector2Array = PackedVector2Array([
		c + Vector2(0.0, -9.0) * sf,
		c + Vector2(9.0, 0.0) * sf,
		c + Vector2(-9.0, 0.0) * sf
	])
	draw_colored_polygon(roof_pts, icon_color)
	# Base
	var house_rect: Rect2 = Rect2(c.x - 6.5 * sf, c.y, 13.0 * sf, 8.0 * sf)
	draw_rect(house_rect, icon_color)
	# Door
	var door_rect: Rect2 = Rect2(c.x - 2.5 * sf, c.y + 2.0 * sf, 5.0 * sf, 6.0 * sf)
	draw_rect(door_rect, Color(0.15, 0.12, 0.2))


func _draw_add(c: Vector2, sf: float) -> void:
	var len: float = 7.0 * sf
	var thick: float = 2.8 * sf
	draw_line(c + Vector2(-len, 0), c + Vector2(len, 0), icon_color, thick, true)
	draw_line(c + Vector2(0, -len), c + Vector2(0, len), icon_color, thick, true)


func _draw_sub(c: Vector2, sf: float) -> void:
	var len: float = 7.0 * sf
	var thick: float = 2.8 * sf
	draw_line(c + Vector2(-len, 0), c + Vector2(len, 0), icon_color, thick, true)


func _draw_mul(c: Vector2, sf: float) -> void:
	var len: float = 5.5 * sf
	var thick: float = 2.8 * sf
	draw_line(c + Vector2(-len, -len), c + Vector2(len, len), icon_color, thick, true)
	draw_line(c + Vector2(-len, len), c + Vector2(len, -len), icon_color, thick, true)


func _draw_div(c: Vector2, sf: float) -> void:
	var len: float = 7.0 * sf
	var thick: float = 2.4 * sf
	draw_line(c + Vector2(-len, 0), c + Vector2(len, 0), icon_color, thick, true)
	draw_circle(c + Vector2(0, -4.5 * sf), 1.8 * sf, icon_color)
	draw_circle(c + Vector2(0, 4.5 * sf), 1.8 * sf, icon_color)


func _draw_mix(c: Vector2, sf: float) -> void:
	# Crossed arrows / shuffle symbol
	var thick: float = 2.0 * sf
	draw_line(c + Vector2(-7.0, -4.0) * sf, c + Vector2(3.0, 4.0) * sf, icon_color, thick, true)
	draw_line(c + Vector2(-7.0, 4.0) * sf, c + Vector2(3.0, -4.0) * sf, secondary_color, thick, true)
	# Arrowheads
	draw_line(c + Vector2(3.0, 4.0) * sf, c + Vector2(7.0, 4.0) * sf, icon_color, thick, true)
	draw_line(c + Vector2(5.0, 1.0) * sf, c + Vector2(7.0, 4.0) * sf, icon_color, thick, true)
	draw_line(c + Vector2(3.0, -4.0) * sf, c + Vector2(7.0, -4.0) * sf, secondary_color, thick, true)
	draw_line(c + Vector2(5.0, -1.0) * sf, c + Vector2(7.0, -4.0) * sf, secondary_color, thick, true)
