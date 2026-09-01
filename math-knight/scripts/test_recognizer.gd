extends SceneTree

const PointCloudRecognizerScript = preload("res://scenes/ui/input_methods/recognition/PointCloudRecognizer.gd")

func _init() -> void:
	print("--- TESTING PointCloudRecognizer (1 vs 7 & Multi-digit) ---")
	var rec = PointCloudRecognizerScript.new()
	
	# 1. Straight line 1
	var stroke_1_straight = [Vector2(50, 15), Vector2(50, 85)]
	var res_1a = rec.recognize([stroke_1_straight])
	print("Recognized straight 1: digit=%d (conf=%.2f, tmpl=%s)" % [res_1a.digit, res_1a.confidence, res_1a.name])
	assert(res_1a.digit == 1, "Straight line must be 1")
	
	# 2. German 1 with tick
	var stroke_1_german = [Vector2(30, 45), Vector2(50, 15), Vector2(50, 85)]
	var res_1b = rec.recognize([stroke_1_german])
	print("Recognized German 1: digit=%d (conf=%.2f, tmpl=%s)" % [res_1b.digit, res_1b.confidence, res_1b.name])
	assert(res_1b.digit == 1, "German tick must be 1")
	
	# 3. Simple 7 (horizontal top bar + diagonal stem)
	var stroke_7_simple = [Vector2(20, 20), Vector2(80, 20), Vector2(40, 90)]
	var res_7a = rec.recognize([stroke_7_simple])
	print("Recognized simple 7: digit=%d (conf=%.2f, tmpl=%s)" % [res_7a.digit, res_7a.confidence, res_7a.name])
	assert(res_7a.digit == 7, "Simple 7 must be 7")
	
	# 4. German crossed 7 (2-stroke)
	var stroke_7_c1 = [Vector2(20, 20), Vector2(80, 20), Vector2(40, 90)]
	var stroke_7_c2 = [Vector2(30, 55), Vector2(65, 55)]
	var res_7b = rec.recognize([stroke_7_c1, stroke_7_c2])
	print("Recognized German crossed 7: digit=%d (conf=%.2f, tmpl=%s)" % [res_7b.digit, res_7b.confidence, res_7b.name])
	assert(res_7b.digit == 7, "German crossed 7 must be 7")
	
	# 5. Multi-digit spatial recognition: "1" on left, "2" on right
	var stroke_multi_1 = [Vector2(100, 20), Vector2(100, 80)] # digit 1
	var stroke_multi_2 = [
		Vector2(220, 30), Vector2(240, 15), Vector2(260, 15),
		Vector2(265, 35), Vector2(230, 80), Vector2(270, 80)
	] # digit 2
	var multi_res = rec.recognize_segmented([stroke_multi_1, stroke_multi_2])
	print("Multi-digit recognition count: %d" % multi_res.size())
	assert(multi_res.size() == 2, "Should find 2 digits")
	print("  -> Digit 1: %d" % multi_res[0].digit)
	print("  -> Digit 2: %d" % multi_res[1].digit)
	assert(multi_res[0].digit == 1, "First digit should be 1")
	assert(multi_res[1].digit == 2, "Second digit should be 2")
	
	print("--- ALL POINT CLOUD TESTS PASSED WITH 100% ACCURACY! ---")
	quit(0)
