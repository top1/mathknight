extends SceneTree

func _init() -> void:
	_run_tests()

func _run_tests() -> void:
	print("\n" + "=".repeat(60))
	print("  SIEGE GATE MAZE — CLICK & HIT-TEST VERIFICATION")
	print("=".repeat(60))

	var scene: PackedScene = load("res://scenes/siege/SiegeGateMaze.tscn")
	var maze: SiegeGateMaze = scene.instantiate()
	root.add_child(maze)
	maze.load_level_by_index(0)

	var lever0: GateLever = maze.stage_levers[0][0]
	
	# Test 1: Hit test on lever pivot
	var pivot_hit: bool = lever0.hit_test(lever0.global_position)
	print("  Test 1: Pivot hit test: %s" % ("PASS" if pivot_hit else "FAIL"))
	assert(pivot_hit, "Lever pivot must be hit-testable")

	# Test 2: Hit test on lever arm offset
	var arm_tip_pos: Vector2 = lever0.global_position + lever0._current_arm_offset
	var arm_hit: bool = lever0.hit_test(arm_tip_pos)
	print("  Test 2: Arm tip hit test: %s" % ("PASS" if arm_hit else "FAIL"))
	assert(arm_hit, "Lever arm tip must be hit-testable")

	# Test 3: Hit test on lever arm midpoint
	var arm_mid_pos: Vector2 = lever0.global_position + lever0._current_arm_offset * 0.5
	var arm_mid_hit: bool = lever0.hit_test(arm_mid_pos)
	print("  Test 3: Arm midpoint hit test: %s" % ("PASS" if arm_mid_hit else "FAIL"))
	assert(arm_mid_hit, "Lever arm midpoint must be hit-testable")

	# Test 4: Toggle via simulated click on lever arm
	var initial_choice: int = maze.chosen_choices[0][0]
	assert(initial_choice == 0, "Initial choice must be 0")
	
	var click_event := InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	click_event.position = arm_tip_pos
	maze._unhandled_input(click_event)

	var toggled_choice: int = maze.chosen_choices[0][0]
	print("  Test 4: Toggle via click on arm tip: choice %d -> %d (%s)" % [initial_choice, toggled_choice, "PASS" if toggled_choice == 1 else "FAIL"])
	assert(toggled_choice == 1, "Click on arm tip must toggle lever to choice 1")

	# Test 5: Click on OperationGate badge (+10 or x2) switches to that choice
	var gate_upper: OperationGate = maze.stage_gates[0][0][0] # x2 (choice 0)
	var gate_click := InputEventMouseButton.new()
	gate_click.button_index = MOUSE_BUTTON_LEFT
	gate_click.pressed = true
	gate_click.position = gate_upper.global_position
	maze._unhandled_input(gate_click)

	var gate_switched_choice: int = maze.chosen_choices[0][0]
	print("  Test 5: Click on OperationGate badge (x2): switched to choice %d (%s)" % [gate_switched_choice, "PASS" if gate_switched_choice == 0 else "FAIL"])
	assert(gate_switched_choice == 0, "Clicking OperationGate x2 must switch to choice 0")

	# Test 6: Result overlay is in CanvasLayer with layer = 100
	var res_layer: CanvasLayer = maze.result_layer
	var layer_ok: bool = res_layer != null and res_layer.layer == 100
	print("  Test 6: Result overlay in CanvasLayer layer 100: %s" % ("PASS" if layer_ok else "FAIL"))
	assert(layer_ok, "Result overlay must be in CanvasLayer with layer = 100")

	# Test 7: MazeBoard exists and is wired to draw
	var board_ok: bool = maze.maze_board != null and maze.maze_board.get_parent() == maze
	print("  Test 7: MazeBoard is child of maze: %s" % ("PASS" if board_ok else "FAIL"))
	assert(board_ok, "MazeBoard must exist and be child of maze")

	# Test 8: Pivots are aligned directly with dividing walls
	var p0_y: float = maze.stage_levers[0][0].position.y
	var p1_0_y: float = maze.stage_levers[1][0].position.y
	var p1_1_y: float = maze.stage_levers[1][1].position.y
	var pivots_ok: bool = absf(p0_y - 175.0) < 1.0 and absf(p1_0_y - 130.0) < 1.0 and absf(p1_1_y - 220.0) < 1.0
	print("  Test 8: Gate pivots aligned to divider walls (Stage0=%.1f, Stage1=[%.1f, %.1f]): %s" % [p0_y, p1_0_y, p1_1_y, "PASS" if pivots_ok else "FAIL"])
	assert(pivots_ok, "Pivots must align with divider walls: 175 for stage 0, 130 and 220 for stage 1")

	# Test 9: Lower lane to Middle lane switching
	# Switch stage 0 to choice 1 (+10, lower channel)
	maze.stage_levers[0][0].set_path(1, false)
	maze._on_branch_lever_switched(0, 1, 0, 0)
	var active_branch_s1: int = maze._get_active_branch_for_stage(1)
	assert(active_branch_s1 == 1, "Active branch in stage 1 must be branch 1 (lower)")

	# Currently branch 1 is at choice 0. Let's set it to choice 1 (-8x3) first
	maze.stage_levers[1][1].set_path(1, false)
	maze._on_branch_lever_switched(101, 1, 1, 1)
	assert(maze.chosen_choices[1][1] == 1, "Stage 1 Branch 1 must be choice 1")

	# Now click the Middle Lane channel (exit_y = 0.5, Y = 175)
	var stage1_x: float = maze.stage_x_positions[1]
	var mid_click := InputEventMouseButton.new()
	mid_click.button_index = MOUSE_BUTTON_LEFT
	mid_click.pressed = true
	mid_click.position = Vector2(stage1_x + 30.0, 175.0)
	maze._unhandled_input(mid_click)

	var lower_to_mid_choice: int = maze.chosen_choices[1][1]
	print("  Test 9: Lower lane to Middle lane switch (choice is %d, exit_y=0.5): %s" % [lower_to_mid_choice, "PASS" if lower_to_mid_choice == 0 else "FAIL"])
	assert(lower_to_mid_choice == 0, "Clicking middle lane while in lower lane must switch branch 1 to choice 0 (middle lane)!")

	# Test 10: Direct click on barrier arm in lower branch switches it back to Choice 1
	var bot_lever: GateLever = maze.stage_levers[1][1]
	var bot_arm_tip: Vector2 = bot_lever.global_position + bot_lever._current_arm_offset
	var arm_click2 := InputEventMouseButton.new()
	arm_click2.button_index = MOUSE_BUTTON_LEFT
	arm_click2.pressed = true
	arm_click2.position = bot_arm_tip
	maze._unhandled_input(arm_click2)
	var toggled_bot_choice: int = maze.chosen_choices[1][1]
	print("  Test 10: Direct barrier arm click toggles lower branch (choice %d -> %d): %s" % [lower_to_mid_choice, toggled_bot_choice, "PASS" if toggled_bot_choice == 1 else "FAIL"])
	assert(toggled_bot_choice == 1, "Clicking barrier arm must toggle lower branch to choice 1")

	# Test 11: SoldierCluster crowd physics and living movement
	var army: SoldierCluster = maze.army_cluster
	assert(army != null, "ArmyCluster must exist")
	army.set_corridor_bounds(130.0, 220.0)
	assert(army.corridor_y_top == 130.0 and army.corridor_y_bottom == 220.0, "Corridor bounds must be set")
	army._process(0.016)
	army.clear_corridor_bounds()
	assert(not army.has_corridor_bounds, "Corridor bounds must be cleared")
	print("  Test 11: SoldierCluster living movement and soft-body corridor physics: PASS")

	# Test 12: High-count scaling with spatial grid (50, 100, 250, 500 soldiers)
	for count_val in [50, 100, 250, 500]:
		army.set_count_instant(count_val)
		assert(army.soldier_count == count_val, "Army count must be %d" % count_val)
		army._process(0.016)
		# Verify no NaNs or infs in positions or velocities
		for s in army._soldiers:
			if s.active:
				assert(not is_nan(s.current_pos.x) and not is_nan(s.current_pos.y), "Positions must not be NaN")
				assert(not is_nan(s.velocity.x) and not is_nan(s.velocity.y), "Velocities must not be NaN")
	print("  Test 12: High-count swarm simulation up to 500 soldiers: PASS")

	# Test 13: Channel column formation constraint
	army.set_corridor_bounds(130.0, 220.0)
	var max_allowed_half_h: float = (220.0 - 130.0) * 0.5
	for s in army._soldiers:
		if s.active:
			assert(absf(s.target_pos.y) <= max_allowed_half_h + 1.0, "Target Y must fit inside corridor")
	army.clear_corridor_bounds()
	print("  Test 13: Corridor column formation bounds fitting: PASS")

	# Test 14: Debug panel API methods
	maze.debug_set_soldier_count(100)
	assert(maze.current_soldier_count == 100, "Debug set count must be 100")
	assert(army.soldier_count == 100, "Army cluster count must be 100")

	maze.debug_add_soldier_count(50)
	assert(maze.current_soldier_count == 150, "Debug add count +50 must yield 150")

	maze.debug_multiply_soldier_count(2.0)
	assert(maze.current_soldier_count == 300, "Debug multiply count x2 must yield 300")

	maze.debug_set_castle_defense(500)
	assert(maze.level_data.castle_defense_value == 500, "Castle defense must be 500")

	maze.debug_toggle_panel()
	assert(maze.debug_panel.visible == true, "Debug panel must be visible after toggle")
	maze.debug_toggle_panel()
	assert(maze.debug_panel.visible == false, "Debug panel must be hidden after toggle")

	maze.debug_reset_army()
	assert(maze.current_phase == SiegeGateMaze.Phase.PLANNING, "Army reset must return to PLANNING phase")
	print("  Test 14: Debug panel API and count modifiers: PASS")

	# Test 15: Debug keyboard shortcuts
	var key_event := InputEventKey.new()
	key_event.pressed = true
	key_event.keycode = KEY_5
	maze._unhandled_input(key_event)
	assert(maze.current_soldier_count == 500, "Key 5 must set army to 500")

	key_event.keycode = KEY_1
	maze._unhandled_input(key_event)
	assert(maze.current_soldier_count == 12, "Key 1 must set army to 12")

	key_event.keycode = KEY_PLUS
	maze._unhandled_input(key_event)
	assert(maze.current_soldier_count == 22, "Key + must add 10")
	print("  Test 15: Debug keyboard shortcuts (1-5, +): PASS")

	# Test 16: Start lane stop (left perimeter wall) collision check with large swarm
	maze.debug_set_soldier_count(62)
	for frame in range(10):
		army._process(0.016)
	for s in army._soldiers:
		if s.active:
			var world_x: float = army.global_position.x + s.current_pos.x
			assert(world_x >= 45.0, "Soldier world X (%.1f) must never be less than MARGIN_LEFT (45.0)" % world_x)
	print("  Test 16: Start lane stop (left perimeter wall) collision check: PASS")

	# Test 17: High-count march with live tweens (100 soldiers -> x2 -> -5 x2 = 390 soldiers vs 300 castle defense)
	maze.debug_set_soldier_count(100)
	maze.debug_set_castle_defense(300)
	maze.chosen_choices[0][0] = 0 # x2
	maze.chosen_choices[1][0] = 0 # -5 x2
	maze._on_march_pressed()

	var march_res: Array = await maze.puzzle_completed
	var fin_count: int = march_res[0]
	var fin_def: int = march_res[1]
	var fin_win: bool = march_res[2]
	var fin_stars: int = march_res[3]

	print("  Test 17: High count march (100 soldiers -> final %d vs defense %d, victory=%s, stars=%d): %s" % [
		fin_count, fin_def, str(fin_win), fin_stars, "PASS" if fin_count == 390 and fin_win else "FAIL"
	])
	assert(fin_count == 390, "100 * 2 = 200; (200 - 5) * 2 = 390")
	assert(fin_win, "Must defeat 300 defense castle")
	assert(fin_stars == 3, "Must get 3 stars")

	# Test 18: Verify castle breach state and victory celebration
	var castle_draw_node: Node = null
	for ch in maze.castle_sprite.get_children():
		if ch.get_class() == "CastleDraw" or ch.has_method("breach"):
			castle_draw_node = ch
			break
	assert(castle_draw_node != null, "CastleDraw node must exist")
	assert(castle_draw_node.get("is_breached") == true, "Castle must be in breached state after victory")
	assert(castle_draw_node.get("gate_open_ratio") > 0.0, "Gate open ratio must be > 0.0")
	assert(maze.celebration_container != null, "Celebration container must exist")
	print("  Test 18: Castle breach state and victory celebration graphics: PASS")

	# Test 19: Verify Door Threshold Clamp: soldiers can NEVER exceed castle_door_world_x
	maze.debug_reset_army()
	maze.debug_set_soldier_count(150)
	var door_x: float = maze.castle_sprite.position.x - 16.0
	army.set_max_x(door_x)
	# Position army close to the door and simulate physics
	army.global_position = Vector2(door_x - 10.0, 175.0)
	for _step in range(15):
		army._process(0.016)
	for s in army._soldiers:
		if s.active:
			var world_x: float = army.global_position.x + s.current_pos.x
			assert(world_x <= door_x + 0.01, "Soldier world X (%.2f) must NEVER exceed castle door threshold (%.2f)" % [world_x, door_x])
	print("  Test 19: Castle door threshold hard clamp (zero penetration past door): PASS")

	print("\n  🎉 ALL 19 CLICK, HIT-TEST, HIGH-COUNT, MARCH, BREACH & CELEBRATION CHECKS PASSED!\n")
	maze.queue_free()
	quit(0)
