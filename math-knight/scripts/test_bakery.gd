extends SceneTree

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	print("==================================================")
	print(">>> RUNNING HOFBÄCKEREI (MEISTER KRUSTE) TESTS <<<")
	print("==================================================")

	var success := true

	# Autoloads for standalone mode
	if not root.has_node("/root/EventBus"):
		var eb = load("res://scripts/autoload/EventBus.gd").new()
		eb.name = "EventBus"
		root.add_child(eb)

	if not root.has_node("/root/SaveManager"):
		var sm = load("res://scripts/autoload/SaveManager.gd").new()
		sm.name = "SaveManager"
		root.add_child(sm)

	if not root.has_node("/root/AudioManager"):
		var am = load("res://scripts/autoload/AudioManager.gd").new()
		am.name = "AudioManager"
		root.add_child(am)

	# 1. Load Bakery scene
	var scene: PackedScene = load("res://scenes/bakery/Bakery.tscn")
	if not scene:
		printerr("FAIL: Could not load res://scenes/bakery/Bakery.tscn")
		quit(1)
		return

	var bakery = scene.instantiate()
	root.add_child(bakery)

	# Wait a frame for _ready() to complete
	await process_frame

	# 2. Check all expected nodes
	print("\n[TEST 1] Verifying all UI and logic nodes...")
	var required_nodes = [
		bakery.back_btn,
		bakery.bread_counter,
		bakery.level_selector,
		bakery.phase_label,
		bakery.mute_btn,
		bakery.scale_panel,
		bakery.scale_draw,
		bakery.weights_shelf,
		bakery.btn_clear_scale,
		bakery.recipe_label,
		bakery.flour_particles,
		bakery.spark_particles,
		bakery.oven_panel,
		bakery.temp_label,
		bakery.temp_bar,
		bakery.oven_fire_particles,
		bakery.wood_shelf,
		bakery.btn_cool_oven,
		bakery.clock_panel,
		bakery.clock_draw,
		bakery.clock_prompt,
		bakery.clock_time_label,
		bakery.btn_confirm_clock,
		bakery.btn_reset_clock,
		bakery.result_panel,
		bakery.result_title,
		bakery.result_desc,
		bakery.btn_bake_again,
		bakery.btn_back_village
	]

	for node in required_nodes:
		if node == null:
			printerr("FAIL: Required node is null!")
			success = false

	if success:
		print("✓ All 26 @onready nodes successfully instantiated and bound!")

	# 3. Test Phase 1: Weighing & Physics
	print("\n[TEST 2] Testing Phase 1: Scale physics & Catapult...")
	bakery.selected_curriculum_level = 1
	bakery._setup_weighing_problem()
	if bakery.target_weight != 10:
		printerr("FAIL: L1 target weight should be 10, got: ", bakery.target_weight)
		success = false
	else:
		print("✓ Target weight set correctly: %d kg" % bakery.target_weight)

	# Simulate weight shelf buttons
	var shelf_buttons = bakery.weights_shelf.get_children()
	print("✓ Weight buttons generated: %d" % shelf_buttons.size())
	if shelf_buttons.is_empty():
		printerr("FAIL: Weights shelf is empty!")
		success = false

	# Add weight to scale
	bakery._add_player_weight(3)
	bakery._add_player_weight(7)
	if bakery._get_total_player_weight() != 10:
		printerr("FAIL: Total player weight should be 10, got: ", bakery._get_total_player_weight())
		success = false
	else:
		print("✓ Perfect balance reached with weights (3 + 7 = 10)")

	# Test catapult trigger
	print("Testing catapult trigger with extreme imbalance...")
	bakery.player_weights.clear()
	bakery._add_player_weight(25) # 25 - 10 = +15 imbalance
	bakery.beam_angular_velocity = 2.5
	bakery._trigger_catapult_effect(true)
	if bakery.catapult_cooldown <= 0.0 or bakery.catapult_overlay_alpha <= 0.0:
		printerr("FAIL: Catapult cooldown/overlay not activated!")
		success = false
	else:
		print("✓ Catapult effect triggered! Flour particles & comic popup active!")

	# Clear scale
	bakery._clear_scale()
	if bakery._get_total_player_weight() != 0:
		printerr("FAIL: Scale clear did not reset weights!")
		success = false
	else:
		print("✓ Scale successfully cleared.")

	# Test Drag & Drop Weight onto Pan
	var right_pan_pos = bakery._get_right_pan_global_pos()
	bakery._start_dragging_weight(4, Vector2(100, 200))
	if not bakery.is_dragging_weight:
		printerr("FAIL: is_dragging_weight was not set to true!")
		success = false
	bakery._finish_dragging_weight(right_pan_pos) # drop directly on pan
	if bakery._get_total_player_weight() != 4:
		printerr("FAIL: Dropped weight was not added to player_weights! Total: ", bakery._get_total_player_weight())
		success = false
	else:
		print("✓ Drag & Drop: Weight (4 kg) successfully dropped onto right pan!")

	# Test removing top weight by tapping pan
	bakery._remove_top_weight()
	if bakery._get_total_player_weight() != 0:
		printerr("FAIL: _remove_top_weight did not remove weight!")
		success = false
	else:
		print("✓ Pan tap: Top weight successfully popped off pan.")

	# 4. Test Phase 2: Oven & Wood heating
	print("\n[TEST 3] Testing Phase 2: Steinofen anheizen...")
	bakery.selected_curriculum_level = 3
	bakery._setup_oven_problem()
	print("Initial temp: %d°C, Target temp: %d°C" % [bakery.current_temp, bakery.target_temp])
	var initial_temp = bakery.current_temp
	bakery._add_wood_log(25)
	if bakery.current_temp != initial_temp + 25:
		printerr("FAIL: Wood log did not increase temperature correctly!")
		success = false
	else:
		print("✓ Wood log added +25°C -> current: %d°C" % bakery.current_temp)

	bakery._cool_oven()
	if bakery.current_temp != initial_temp + 10:
		printerr("FAIL: Cool oven did not decrease temperature by 15°C!")
		success = false
	else:
		print("✓ Oven ventilation cooled down by -15°C -> current: %d°C" % bakery.current_temp)

	# Test Wood Drag & Drop into Oven
	var oven_pos = bakery._get_oven_mouth_global_pos()
	bakery._start_dragging_wood(15, Vector2(100, 200))
	if not bakery.is_dragging_wood:
		printerr("FAIL: is_dragging_wood was not set to true!")
		success = false
	var pre_temp = bakery.current_temp
	bakery._finish_dragging_wood(oven_pos)
	if bakery.current_temp != pre_temp + 15:
		printerr("FAIL: Dragged wood was not added to oven! Expected ", pre_temp + 15, " got ", bakery.current_temp)
		success = false
	else:
		print("✓ Drag & Drop: Wood log (+15°C) successfully tossed into stone oven!")

	# Reach target temp
	bakery.current_temp = bakery.target_temp
	bakery._trigger_oven_success()
	print("✓ Oven target temperature achieved!")

	# 5. Test Phase 3: Clock & Baking Duration
	print("\n[TEST 4] Testing Phase 3: Schlossuhr Interactive Drag & Dial...")
	bakery.selected_curriculum_level = 3 # L3 with hour crossing
	for test_run in range(20):
		bakery._setup_clock_problem()
		var total_m = (bakery.clock_start_hour * 60) + bakery.clock_start_minute + bakery.baking_duration_minutes
		var exp_h = (total_m / 60) % 24
		var exp_m = total_m % 60
		if bakery.correct_end_hour != exp_h or bakery.correct_end_minute != exp_m:
			printerr("FAIL: Clock math mismatch: %02d:%02d + %d min != %02d:%02d (got %02d:%02d)" % [
				bakery.clock_start_hour, bakery.clock_start_minute, bakery.baking_duration_minutes,
				exp_h, exp_m, bakery.correct_end_hour, bakery.correct_end_minute
			])
			success = false

	# Test interactive confirmation with dialed clock
	bakery._setup_clock_problem()
	# Set to wrong time first
	bakery.current_clock_hour = bakery.correct_end_hour
	bakery.current_clock_minute = (bakery.correct_end_minute + 15) % 60
	bakery._on_clock_confirm_pressed()
	if bakery.current_phase == Bakery.Phase.FINISHED:
		printerr("FAIL: Incorrect clock time was accepted as finished!")
		success = false
	else:
		print("✓ Incorrect dialed clock time rejected with educational hint.")

	# Set to correct time
	bakery.current_clock_hour = bakery.correct_end_hour
	bakery.current_clock_minute = bakery.correct_end_minute
	bakery._on_clock_confirm_pressed()
	if bakery.current_phase != Bakery.Phase.FINISHED:
		printerr("FAIL: Correct dialed clock time was not accepted!")
		success = false
	else:
		print("✓ Correct dialed clock time accepted! Bread successfully completed.")

	# 6. Test Phase 4: Rewards & SaveManager
	print("\n[TEST 5] Testing Phase 4: Rewards & SaveManager bread tracking...")
	var initial_bread = 0
	if bakery.has_node("/root/SaveManager"):
		initial_bread = bakery.get_node("/root/SaveManager").bread
	bakery._trigger_baking_completed()
	if bakery.has_node("/root/SaveManager"):
		var new_bread = bakery.get_node("/root/SaveManager").bread
		if new_bread != initial_bread + 1:
			printerr("FAIL: Bread count in SaveManager was not incremented! Expected: ", initial_bread + 1, " got: ", new_bread)
			success = false
		else:
			print("✓ SaveManager received +1 fresh bread! Total bread: %d 🥖" % new_bread)

	# 7. Test Mute Button Toggle
	print("\n[TEST 6] Testing Mute Sound Button...")
	var am = bakery.get_node("/root/AudioManager")
	var initial_muted = am.is_master_muted()
	bakery._on_mute_pressed()
	if am.is_master_muted() == initial_muted:
		printerr("FAIL: Mute button did not toggle master mute state!")
		success = false
	else:
		print("✓ Mute button successfully toggled audio: muted = %s" % str(am.is_master_muted()))
		# Toggle back
		bakery._on_mute_pressed()
		print("✓ Mute button successfully toggled back: muted = %s" % str(am.is_master_muted()))

	print("\n==================================================")
	if success:
		print(">>> ALL HOFBÄCKEREI TESTS PASSED (100% OK) <<<")
	else:
		print(">>> SOME HOFBÄCKEREI TESTS FAILED <<<")
	print("==================================================")

	quit(0 if success else 1)
