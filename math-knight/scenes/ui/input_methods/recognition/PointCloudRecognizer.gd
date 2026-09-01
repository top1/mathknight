class_name PointCloudRecognizer
extends RefCounted
## Pure GDScript implementation of the $P Point-Cloud Recognizer with
## German/European digit variations, 1 vs 7 disambiguation heuristics,
## and multi-digit horizontal spatial segmentation.

const NUM_POINTS: int = 32
const BOX_SIZE: float = 100.0

class Point:
	var x: float
	var y: float
	var stroke_id: int
	
	func _init(p_x: float, p_y: float, p_stroke_id: int = 0) -> void:
		x = p_x
		y = p_y
		stroke_id = p_stroke_id
	
	func to_vec() -> Vector2:
		return Vector2(x, y)

class Template:
	var name: String
	var digit: int
	var points: Array[Point]
	var orig_aspect: float ## width / height ratio
	
	func _init(p_name: String, p_digit: int, p_points: Array[Point], p_aspect: float = 1.0) -> void:
		name = p_name
		digit = p_digit
		points = p_points
		orig_aspect = p_aspect

var templates: Array[Template] = []


func _init() -> void:
	_init_default_templates()


static func normalize_strokes(raw_strokes: Array) -> Array[Point]:
	var raw_points: Array[Point] = []
	for stroke_idx in range(raw_strokes.size()):
		var stroke = raw_strokes[stroke_idx]
		if stroke is PackedVector2Array:
			for vec in stroke:
				raw_points.append(Point.new(vec.x, vec.y, stroke_idx))
		elif stroke is Array:
			for vec in stroke:
				if vec is Vector2:
					raw_points.append(Point.new(vec.x, vec.y, stroke_idx))

	if raw_points.is_empty():
		return []

	# 1. Resample to NUM_POINTS
	var resampled: Array[Point] = _resample(raw_points, NUM_POINTS)
	# 2. Scale to 100x100 box
	var scaled: Array[Point] = _scale(resampled, BOX_SIZE)
	# 3. Translate centroid to origin (0, 0)
	var translated: Array[Point] = _translate_to_origin(scaled)
	return translated


static func _path_length(points: Array[Point]) -> float:
	var d: float = 0.0
	for i in range(1, points.size()):
		if points[i].stroke_id == points[i - 1].stroke_id:
			d += points[i].to_vec().distance_to(points[i - 1].to_vec())
	return d


static func _resample(points: Array[Point], n: int) -> Array[Point]:
	if points.size() <= 1:
		var single_res: Array[Point] = []
		for i in range(n):
			single_res.append(Point.new(points[0].x, points[0].y, points[0].stroke_id))
		return single_res

	var total_len: float = _path_length(points)
	var interval: float = total_len / float(n - 1) if total_len > 0.0 else 1.0
	var D: float = 0.0
	var new_points: Array[Point] = [Point.new(points[0].x, points[0].y, points[0].stroke_id)]
	
	var i: int = 1
	var num_pts: int = points.size()
	while i < num_pts:
		if points[i].stroke_id == points[i - 1].stroke_id:
			var p1: Vector2 = points[i - 1].to_vec()
			var p2: Vector2 = points[i].to_vec()
			var d: float = p1.distance_to(p2)
			if (D + d) >= interval and d > 0.0:
				var t: float = (interval - D) / d
				var q: Vector2 = p1.lerp(p2, t)
				var q_pt: Point = Point.new(q.x, q.y, points[i].stroke_id)
				new_points.append(q_pt)
				points.insert(i, q_pt)
				num_pts += 1
				D = 0.0
			else:
				D += d
		i += 1

	while new_points.size() < n:
		var last: Point = points[-1]
		new_points.append(Point.new(last.x, last.y, last.stroke_id))

	if new_points.size() > n:
		new_points.resize(n)

	return new_points


static func _scale(points: Array[Point], box_size: float) -> Array[Point]:
	var min_x: float = INF
	var max_x: float = -INF
	var min_y: float = INF
	var max_y: float = -INF

	for p in points:
		min_x = min(min_x, p.x)
		max_x = max(max_x, p.x)
		min_y = min(min_y, p.y)
		max_y = max(max_y, p.y)

	var width: float = max(max_x - min_x, 1.0)
	var height: float = max(max_y - min_y, 1.0)
	var scale_factor: float = max(width, height)

	var scaled: Array[Point] = []
	for p in points:
		var nx: float = ((p.x - min_x) / scale_factor) * box_size
		var ny: float = ((p.y - min_y) / scale_factor) * box_size
		scaled.append(Point.new(nx, ny, p.stroke_id))
	return scaled


static func _translate_to_origin(points: Array[Point]) -> Array[Point]:
	var cx: float = 0.0
	var cy: float = 0.0
	for p in points:
		cx += p.x
		cy += p.y
	cx /= float(points.size())
	cy /= float(points.size())

	var translated: Array[Point] = []
	for p in points:
		translated.append(Point.new(p.x - cx, p.y - cy, p.stroke_id))
	return translated


static func _greedy_cloud_match(points1: Array[Point], points2: Array[Point]) -> float:
	var n: int = points1.size()
	var total_dist: float = 0.0
	
	# 1. points1 -> points2 closest
	for i in range(n):
		var min_d: float = INF
		var p1: Vector2 = points1[i].to_vec()
		for j in range(n):
			var d: float = p1.distance_to(points2[j].to_vec())
			if d < min_d:
				min_d = d
		total_dist += min_d

	# 2. points2 -> points1 closest
	for j in range(n):
		var min_d: float = INF
		var p2: Vector2 = points2[j].to_vec()
		for i in range(n):
			var d: float = p2.distance_to(points1[i].to_vec())
			if d < min_d:
				min_d = d
		total_dist += min_d

	return total_dist / (2.0 * float(n))


## Calculates raw stroke metrics (bounding box, aspect ratio, top-bar existence)
static func _get_raw_stroke_metrics(raw_strokes: Array) -> Dictionary:
	var min_x: float = INF
	var max_x: float = -INF
	var min_y: float = INF
	var max_y: float = -INF
	var all_pts: Array[Vector2] = []

	for stroke in raw_strokes:
		if stroke is PackedVector2Array or stroke is Array:
			for pt in stroke:
				if pt is Vector2:
					all_pts.append(pt)
					min_x = min(min_x, pt.x)
					max_x = max(max_x, pt.x)
					min_y = min(min_y, pt.y)
					max_y = max(max_y, pt.y)

	if all_pts.is_empty():
		return {"width": 0.0, "height": 0.0, "aspect": 0.0, "has_top_bar": false, "is_tall_line": false}

	var w: float = max_x - min_x
	var h: float = max_y - min_y
	var aspect: float = w / max(h, 1.0)
	var is_tall_line: bool = aspect < 0.32

	# Detect if the top 30% has a prominent horizontal stroke (top bar of 7)
	var has_top_bar: bool = false
	var top_thresh = min_y + (h * 0.30)
	var top_pts_x: Array[float] = []
	for pt in all_pts:
		if pt.y <= top_thresh:
			top_pts_x.append(pt.x)
	if top_pts_x.size() >= 3:
		var top_w = top_pts_x.max() - top_pts_x.min()
		if top_w >= w * 0.45 and top_w > 12.0:
			has_top_bar = true

	return {
		"min_x": min_x,
		"max_x": max_x,
		"min_y": min_y,
		"max_y": max_y,
		"width": w,
		"height": h,
		"aspect": aspect,
		"has_top_bar": has_top_bar,
		"is_tall_line": is_tall_line
	}


func recognize(raw_strokes: Array) -> Dictionary:
	if raw_strokes.is_empty():
		return {"digit": -1, "confidence": 0.0, "name": "empty"}

	var metrics: Dictionary = _get_raw_stroke_metrics(raw_strokes)
	var candidate_points: Array[Point] = normalize_strokes(raw_strokes)
	if candidate_points.is_empty():
		return {"digit": -1, "confidence": 0.0, "name": "invalid"}

	var best_dist: float = INF
	var best_template: Template = null

	for tmpl in templates:
		var dist: float = _greedy_cloud_match(candidate_points, tmpl.points)

		# Geometric Heuristics Disambiguation:
		# 1 vs 7 rules:
		if tmpl.digit == 7:
			if metrics.is_tall_line:
				# Extremely narrow vertical stroke cannot be 7!
				dist += 40.0
			elif not metrics.has_top_bar and metrics.aspect < 0.45:
				# No top bar and narrow aspect ratio
				dist += 25.0
		elif tmpl.digit == 1:
			if metrics.is_tall_line:
				# Strongly favor 1 for straight vertical strokes
				dist -= 8.0
			elif metrics.has_top_bar and metrics.aspect > 0.6:
				# Wide stroke with a clear top bar is not 1!
				dist += 30.0

		if dist < best_dist:
			best_dist = dist
			best_template = tmpl

	if best_template == null:
		return {"digit": -1, "confidence": 0.0, "name": "none"}

	var max_possible_dist: float = BOX_SIZE * 0.75
	var confidence: float = clamp(1.0 - (best_dist / max_possible_dist), 0.0, 1.0)

	return {
		"digit": best_template.digit,
		"confidence": confidence,
		"name": best_template.name,
		"distance": best_dist
	}


## Segments multiple strokes on the canvas into 1 or 2 distinct digits based on horizontal spatial distribution
func recognize_segmented(raw_strokes: Array) -> Array[Dictionary]:
	if raw_strokes.is_empty():
		return []

	if raw_strokes.size() == 1:
		return [recognize(raw_strokes)]

	# Compute bounding box per stroke
	var stroke_boxes: Array[Dictionary] = []
	for stroke in raw_strokes:
		var min_x = INF
		var max_x = -INF
		for pt in stroke:
			min_x = min(min_x, pt.x)
			max_x = max(max_x, pt.x)
		var center_x = (min_x + max_x) * 0.5
		stroke_boxes.append({"min_x": min_x, "max_x": max_x, "center_x": center_x, "stroke": stroke})

	# Sort strokes from left to right
	stroke_boxes.sort_custom(func(a, b): return a.center_x < b.center_x)

	# Find largest horizontal gap between consecutive stroke clusters
	var max_gap: float = 0.0
	var split_idx: int = -1

	for i in range(stroke_boxes.size() - 1):
		var gap = stroke_boxes[i + 1].min_x - stroke_boxes[i].max_x
		var center_dist = stroke_boxes[i + 1].center_x - stroke_boxes[i].center_x
		if gap > 10.0 or center_dist > 40.0:
			if center_dist > max_gap:
				max_gap = center_dist
				split_idx = i

	if split_idx != -1:
		var left_strokes: Array = []
		var right_strokes: Array = []
		for i in range(stroke_boxes.size()):
			if i <= split_idx:
				left_strokes.append(stroke_boxes[i].stroke)
			else:
				right_strokes.append(stroke_boxes[i].stroke)

		var res_left = recognize(left_strokes)
		var res_right = recognize(right_strokes)
		return [res_left, res_right]

	return [recognize(raw_strokes)]


func _add_raw_template(name: String, digit: int, raw_strokes: Array, aspect: float = 1.0) -> void:
	templates.append(Template.new(name, digit, normalize_strokes(raw_strokes), aspect))


func _init_default_templates() -> void:
	# Digit 0: Circle / Oval
	var stroke_0: PackedVector2Array = []
	for deg in range(0, 360, 15):
		var rad: float = deg_to_rad(float(deg))
		stroke_0.append(Vector2(50.0 + 35.0 * cos(rad), 50.0 + 45.0 * sin(rad)))
	_add_raw_template("0_circle", 0, [stroke_0], 0.8)

	# === DIGIT 1 (Various handwriting forms) ===
	# Digit 1: Simple vertical line down |
	var stroke_1_simple: PackedVector2Array = [Vector2(50, 10), Vector2(50, 50), Vector2(50, 90)]
	_add_raw_template("1_simple", 1, [stroke_1_simple], 0.1)

	# Digit 1: Slanted line
	var stroke_1_slanted: PackedVector2Array = [Vector2(55, 10), Vector2(45, 90)]
	_add_raw_template("1_slanted", 1, [stroke_1_slanted], 0.2)

	# Digit 1: German / European 1 (Tick up-right, then vertical down)
	var stroke_1_german: PackedVector2Array = [
		Vector2(25, 45), Vector2(35, 30), Vector2(50, 15),
		Vector2(50, 45), Vector2(50, 75), Vector2(50, 90)
	]
	_add_raw_template("1_german", 1, [stroke_1_german], 0.4)

	# Digit 1: Serif + base line (2-stroke)
	var stroke_1_base_1: PackedVector2Array = [Vector2(30, 35), Vector2(50, 15), Vector2(50, 90)]
	var stroke_1_base_2: PackedVector2Array = [Vector2(30, 90), Vector2(70, 90)]
	_add_raw_template("1_with_base", 1, [stroke_1_base_1, stroke_1_base_2], 0.5)

	# Digit 2: Standard 2
	var stroke_2: PackedVector2Array = [
		Vector2(25, 30), Vector2(40, 15), Vector2(70, 15), Vector2(75, 35),
		Vector2(50, 65), Vector2(25, 90), Vector2(75, 90)
	]
	_add_raw_template("2_standard", 2, [stroke_2], 0.75)

	# Digit 3: Top arc + bottom arc
	var stroke_3: PackedVector2Array = [
		Vector2(25, 20), Vector2(70, 20), Vector2(45, 48),
		Vector2(75, 60), Vector2(70, 85), Vector2(25, 85)
	]
	_add_raw_template("3_standard", 3, [stroke_3], 0.7)

	# Digit 4: 2-stroke standard
	var stroke_4a_1: PackedVector2Array = [Vector2(65, 15), Vector2(25, 60), Vector2(80, 60)]
	var stroke_4a_2: PackedVector2Array = [Vector2(65, 35), Vector2(65, 90)]
	_add_raw_template("4_twostroke", 4, [stroke_4a_1, stroke_4a_2], 0.8)

	# Digit 4: 1-stroke
	var stroke_4b: PackedVector2Array = [
		Vector2(65, 15), Vector2(25, 60), Vector2(80, 60), Vector2(65, 40), Vector2(65, 90)
	]
	_add_raw_template("4_onestroke", 4, [stroke_4b], 0.8)

	# Digit 5: 1-stroke
	var stroke_5a: PackedVector2Array = [
		Vector2(75, 20), Vector2(30, 20), Vector2(25, 50),
		Vector2(65, 45), Vector2(75, 70), Vector2(50, 90), Vector2(25, 85)
	]
	_add_raw_template("5_onestroke", 5, [stroke_5a], 0.7)

	# Digit 5: 2-stroke
	var stroke_5b_1: PackedVector2Array = [Vector2(30, 20), Vector2(25, 50), Vector2(70, 45), Vector2(75, 75), Vector2(40, 90)]
	var stroke_5b_2: PackedVector2Array = [Vector2(30, 20), Vector2(75, 20)]
	_add_raw_template("5_twostroke", 5, [stroke_5b_1, stroke_5b_2], 0.7)

	# Digit 6: Standard
	var stroke_6: PackedVector2Array = [
		Vector2(65, 20), Vector2(35, 40), Vector2(25, 70), Vector2(45, 90),
		Vector2(75, 75), Vector2(65, 55), Vector2(35, 55), Vector2(25, 70)
	]
	_add_raw_template("6_standard", 6, [stroke_6], 0.75)

	# === DIGIT 7 (Standard, German Crossed, Hooked) ===
	# Digit 7: Simple top bar + diagonal stem
	var stroke_7a: PackedVector2Array = [
		Vector2(20, 15), Vector2(50, 15), Vector2(80, 15),
		Vector2(65, 45), Vector2(50, 70), Vector2(40, 90)
	]
	_add_raw_template("7_simple", 7, [stroke_7a], 0.8)

	# Digit 7: Slanted stem
	var stroke_7_slanted: PackedVector2Array = [
		Vector2(25, 20), Vector2(75, 20), Vector2(35, 90)
	]
	_add_raw_template("7_slanted", 7, [stroke_7_slanted], 0.75)

	# Digit 7: German Crossed 7 (2-stroke with middle crossbar)
	var stroke_7_crossed_1: PackedVector2Array = [Vector2(20, 15), Vector2(80, 15), Vector2(40, 90)]
	var stroke_7_crossed_2: PackedVector2Array = [Vector2(30, 52), Vector2(60, 52)]
	_add_raw_template("7_crossed", 7, [stroke_7_crossed_1, stroke_7_crossed_2], 0.8)

	# Digit 7: German Crossed 7 (1-stroke continuous with loop/strike)
	var stroke_7_crossed_1s: PackedVector2Array = [
		Vector2(20, 15), Vector2(80, 15), Vector2(50, 52), Vector2(30, 52), Vector2(65, 52), Vector2(40, 90)
	]
	_add_raw_template("7_crossed_1s", 7, [stroke_7_crossed_1s], 0.8)

	# Digit 8: Standard
	var stroke_8: PackedVector2Array = [
		Vector2(50, 50), Vector2(30, 30), Vector2(50, 15), Vector2(70, 30),
		Vector2(50, 50), Vector2(30, 70), Vector2(50, 90), Vector2(70, 70), Vector2(50, 50)
	]
	_add_raw_template("8_standard", 8, [stroke_8], 0.7)

	# Digit 9: Standard
	var stroke_9: PackedVector2Array = [
		Vector2(70, 50), Vector2(40, 50), Vector2(30, 30), Vector2(50, 15),
		Vector2(70, 30), Vector2(70, 90)
	]
	_add_raw_template("9_standard", 9, [stroke_9], 0.7)
