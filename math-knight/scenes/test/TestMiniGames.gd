extends Node
## TestMiniGames — Automated verification suite for Forge & Lumber Yard mini-games and affixes.

func _ready() -> void:
	print("\n========================================================")
	print("🧪 RUNNING PHASE 2 MINI-GAMES & AFFIX VERIFICATION SUITE")
	print("========================================================\n")

	var passed: int = 0
	var total: int = 0

	# Test 1: Blacksmith Forge Instantiation & Ingot Math
	total += 1
	var forge_scene = load("res://scenes/forge/BlacksmithForge.tscn")
	var forge = forge_scene.instantiate()
	add_child(forge)

	if forge._current_problem != null and forge._ingot_buttons.size() == 4:
		print("  ✅ PASS: Blacksmith Forge initialized problem and 4 candidate ingots: " + forge._current_problem.question_text)
		passed += 1
	else:
		printerr("  ❌ FAIL: Blacksmith Forge failed to initialize ingots")

	# Test 2: Ingot selection and quality points accumulation
	total += 1
	var correct_ans = forge._current_problem.correct_answer
	var target_btn: Button = null
	for b in forge._ingot_buttons:
		if b.text == str(correct_ans):
			target_btn = b
			break

	if target_btn != null:
		forge._current_beat = 3
		forge._beat_timer = 0.05 # On beat!
		forge._on_ingot_pressed(correct_ans, target_btn)
		if forge._quality_points >= 3:
			print("  ✅ PASS: Rhythmic ingot strike awarded quality points: " + str(forge._quality_points))
			passed += 1
		else:
			printerr("  ❌ FAIL: Quality points not awarded properly: " + str(forge._quality_points))
	else:
		printerr("  ❌ FAIL: Could not find correct answer ingot button")

	# Test 3: Weapon Affix Storage in SaveManager
	total += 1
	var sm = get_node("/root/SaveManager")
	sm.set_weapon_affix("flame")
	if sm.weapon_affix == "flame":
		print("  ✅ PASS: Weapon affix persisted in SaveManager: " + sm.weapon_affix)
		passed += 1
	else:
		printerr("  ❌ FAIL: SaveManager weapon_affix failed to set: " + sm.weapon_affix)

	# Test 4: Knight Attack Strike incorporates active weapon affix
	total += 1
	var knight_scene = load("res://scenes/knight/Knight.tscn")
	var knight = knight_scene.instantiate()
	add_child(knight)
	var strike = knight.calculate_attack_strike(2.0, 0, 1)
	if strike.get("affix", "") == "flame" and strike.get("tag", "") == "FLAME-STRIKE!":
		print("  ✅ PASS: Knight attack strike activates equipped flame affix: " + strike.tag)
		passed += 1
	else:
		printerr("  ❌ FAIL: Strike did not activate flame affix: " + str(strike))

	# Test 5: Lumber Yard Instantiation & Division Setup
	total += 1
	var lumber_scene = load("res://scenes/lumber/LumberYard.tscn")
	var lumber = lumber_scene.instantiate()
	add_child(lumber)

	if lumber.current_log_length > 0 and lumber.required_segment_size > 0:
		var expected_pieces = lumber.current_log_length / lumber.required_segment_size
		print("  ✅ PASS: Lumber Yard division configured: %dm log into %dm beams = %d pieces" % [lumber.current_log_length, lumber.required_segment_size, expected_pieces])
		passed += 1
	else:
		printerr("  ❌ FAIL: Lumber yard failed setup")

	# Test 6: Lumber Yard Cut Evaluation & Wood/Gold Awarding
	total += 1
	var initial_wood = sm.wood
	var initial_gold = sm.gold
	lumber.current_selected_size = lumber.required_segment_size
	lumber._evaluate_cut(true)
	if sm.wood > initial_wood and sm.gold > initial_gold:
		print("  ✅ PASS: Successful log cut awarded wood and gold to SaveManager (Wood: %d, Gold: %d)" % [sm.wood, sm.gold])
		passed += 1
	else:
		printerr("  ❌ FAIL: Lumber yard did not award wood/gold")

	print("\n--------------------------------------------------------")
	print("📊 RESULTS: " + str(passed) + " / " + str(total) + " TESTS PASSED")
	print("========================================================\n")

	forge.queue_free()
	knight.queue_free()
	lumber.queue_free()

	if passed == total:
		print("🎉 ALL PHASE 2 TESTS PASSED SUCCESSFULLY!")
		get_tree().quit(0)
	else:
		printerr("⚠️ SOME TESTS FAILED!")
		get_tree().quit(1)