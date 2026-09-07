extends SceneTree

const MathProblemScript = preload("res://scripts/resources/MathProblem.gd")

func _init() -> void:
	print("\n========================================================")
	print("🧪 RUNNING COMBAT & RPG OVERHAUL VERIFICATION SUITE")
	print("========================================================\n")

	# Ensure Autoload singletons are available in headless standalone mode
	if not root.has_node("/root/EventBus"):
		var eb = load("res://scripts/autoload/EventBus.gd").new()
		eb.name = "EventBus"
		root.add_child(eb)

	if not root.has_node("/root/SaveManager"):
		var sm_node = load("res://scripts/autoload/SaveManager.gd").new()
		sm_node.name = "SaveManager"
		root.add_child(sm_node)

	if not root.has_node("/root/RunManager"):
		var rm_node = load("res://scripts/autoload/RunManager.gd").new()
		rm_node.name = "RunManager"
		root.add_child(rm_node)

	if not root.has_node("/root/GameManager"):
		var gm_node = load("res://scripts/autoload/GameManager.gd").new()
		gm_node.name = "GameManager"
		root.add_child(gm_node)

	if not root.has_node("/root/MathEngine"):
		var me_node = load("res://scripts/autoload/MathEngine.gd").new()
		me_node.name = "MathEngine"
		root.add_child(me_node)

	var passed: int = 0
	var total: int = 0

	# Test 1: Knight strike calculations (Speed bonus, combo bonus, crits)
	total += 1
	var knight_scene = load("res://scenes/knight/Knight.tscn")
	var knight = knight_scene.instantiate()
	root.add_child(knight)
	knight.attack_power = 2.0

	# Blitz speed (<1.5s)
	var blitz_strike = knight.calculate_attack_strike(1.2, 0, 1)
	if blitz_strike.damage > 3.0 and blitz_strike.speed_tier == "blitz":
		print("  ✅ PASS: Blitz speed strike calculates bonus damage: " + str(blitz_strike.damage))
		passed += 1
	else:
		printerr("  ❌ FAIL: Blitz strike unexpected: " + str(blitz_strike))

	# Combo multiplier test (streak = 5 -> +60%)
	total += 1
	var combo_strike = knight.calculate_attack_strike(4.0, 5, 1)
	if combo_strike.combo_multiplier >= 1.5:
		print("  ✅ PASS: Combo streak scales damage multiplier: " + str(combo_strike.combo_multiplier) + "x")
		passed += 1
	else:
		printerr("  ❌ FAIL: Combo multiplier calculation failed: " + str(combo_strike))

	# Test 2: Armor damage reduction and Dodge
	total += 1
	knight.current_hp = 10.0
	knight.armor = 2.0
	knight.dodge_chance = 0.0
	knight.take_damage(4.0) # 4.0 - 2.0 armor = 2.0 actual damage
	if is_equal_approx(knight.current_hp, 8.0):
		print("  ✅ PASS: Armor mitigation properly reduced damage from 4.0 to 2.0")
		passed += 1
	else:
		printerr("  ❌ FAIL: Armor mitigation failed, current_hp: " + str(knight.current_hp))

	total += 1
	knight.dodge_chance = 1.0 # 100% dodge
	knight.take_damage(10.0)
	if is_equal_approx(knight.current_hp, 8.0): # HP unchanged!
		print("  ✅ PASS: Dodge chance 1.0 completely evaded all incoming damage")
		passed += 1
	else:
		printerr("  ❌ FAIL: Dodge evasion failed, current_hp: " + str(knight.current_hp))

	# Test 3: Enemy archetype HP scaling and multi-hit
	total += 1
	var enemy_scene = load("res://scenes/enemy/Enemy.tscn")
	var goblin = enemy_scene.instantiate()
	root.add_child(goblin)
	var prob1 = MathProblemScript.new()
	prob1.question_text = "5 + 3 = ?"
	prob1.correct_answer = 8
	goblin.setup(prob1, 40.0, 1.0, 2.0, "goblin", 1)
	if goblin.max_hp >= 2.0 and is_equal_approx(goblin.hp, goblin.max_hp):
		print("  ✅ PASS: Goblin initialized with scaled HP pool: " + str(goblin.hp) + " HP")
		passed += 1
	else:
		printerr("  ❌ FAIL: Goblin HP pool incorrect: " + str(goblin.hp))

	total += 1
	# Goblin takes partial hit (1.0 dmg)
	goblin.take_hit(1.0)
	if goblin.hp > 0.0 and goblin.state == "hurt":
		print("  ✅ PASS: Enemy survived partial damage, remaining HP: " + str(goblin.hp))
		passed += 1
	else:
		printerr("  ❌ FAIL: Enemy should have survived partial hit: " + str(goblin.hp))

	# Test 4: Comic Popup creation
	total += 1
	var comic_popup_scene = load("res://scenes/effects/ComicPopup.tscn")
	var popup = comic_popup_scene.instantiate()
	root.add_child(popup)
	popup.setup("BLITZ!", Vector2(100, 100), "blitz")
	if popup._text == "BLITZ!" and popup._archetype == "blitz":
		print("  ✅ PASS: Comic onomatopoeia popup instantiated and configured successfully")
		passed += 1
	else:
		printerr("  ❌ FAIL: ComicPopup configuration failed")

	# Test 5: Safe Run Defeat Loop (100% gold and XP retention)
	total += 1
	var sm = root.get_node("/root/SaveManager")
	var rm = root.get_node("/root/RunManager")
	var initial_gold = sm.gold
	var initial_xp = sm.knight_xp

	rm.start_new_run()
	rm.add_run_gold(45, "Test combat")
	rm.end_run(false) # DEFEAT / Honorable retreat

	if sm.gold == initial_gold + 45 and sm.knight_xp >= initial_xp:
		print("  ✅ PASS: 100% of collected run gold and XP retained on defeat (Safe Run Loop)")
		passed += 1
	else:
		printerr("  ❌ FAIL: SaveManager did not retain run rewards. Gold: " + str(sm.gold) + ", Expected: " + str(initial_gold + 45))

	print("\n--------------------------------------------------------")
	print("📊 RESULTS: " + str(passed) + " / " + str(total) + " TESTS PASSED")
	print("========================================================\n")

	knight.queue_free()
	goblin.queue_free()
	popup.queue_free()

	if passed == total:
		print("🎉 ALL TESTS PASSED SUCCESSFULLY!")
		quit(0)
	else:
		printerr("⚠️ SOME TESTS FAILED!")
		quit(1)
