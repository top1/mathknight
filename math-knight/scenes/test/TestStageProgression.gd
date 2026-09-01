extends Node
## TestStageProgression — Runs full suite of tests with all Autoloads active.

func _ready() -> void:
	print("\n==========================================")
	print(">>> RUNNING MATHKNIGHT STAGE SYSTEM TEST <<<")
	print("==========================================\n")

	assert(has_node("/root/RunManager"), "RunManager autoload must exist")
	assert(has_node("/root/GameManager"), "GameManager autoload must exist")
	assert(has_node("/root/EventBus"), "EventBus autoload must exist")
	assert(has_node("/root/SaveManager"), "SaveManager autoload must exist")

	var rm: Node = get_node("/root/RunManager")

	# 1. Test Run Initialization
	rm.start_new_run()
	assert(rm.is_run_active == true, "Run should be active after start_new_run")
	assert(rm.current_stage_index == 0, "Stage index should start at 0 (Stage 1)")
	print("[PASS] Run Initialization verified.")

	# 2. Test Stages 1 to 10 choice generation
	for stage_idx in range(10):
		var choices = rm.generate_stage_choices(stage_idx)
		assert(choices.size() == 3, "Each stage must generate exactly 3 choices! Got: %d on Stage %d" % [choices.size(), stage_idx + 1])

		print("\n--- STAGE %d CHOICES ---" % (stage_idx + 1))
		for i in range(choices.size()):
			var c = choices[i]
			assert(c.has("title"), "Choice must have title")
			assert(c.has("math_operation"), "Choice must have math_operation")
			assert(c.has("math_difficulty"), "Choice must have math_difficulty")
			assert(c.has("input_type"), "Choice must have input_type")
			assert(c.has("input_difficulty"), "Choice must have input_difficulty")
			assert(c.reward_gold > 0, "Reward gold must be > 0")

			var op_name = rm.get_operation_name(c)
			var in_name = rm.get_input_type_name(c.input_type)
			var in_diff = rm.get_input_difficulty_name(c.input_difficulty)
			var diff_stars = rm.get_difficulty_stars(c)
			print("  Choice [%d]: %s | Op: %s | Diff: %s | In: %s (%s) | 🪙 +%d Gold" % [
				i, c.title, op_name, diff_stars, in_name, in_diff, c.reward_gold
			])

		# Select choice
		var chosen = rm.select_stage_choice(stage_idx % 3)
		assert(not chosen.is_empty(), "Selected choice should not be empty")

		var cfg = rm.get_math_config_for_stage(chosen)
		assert(cfg != null, "MathConfig must be generated successfully")

		# Complete stage
		var prev_gold = rm.run_gold
		rm.complete_current_stage()
		assert(rm.run_gold >= prev_gold, "Gold should increase or stay same after completing stage")
		print("  [COMPLETED] Stage %d finished! Total Run Gold: %d, Chests: %d" % [stage_idx + 1, rm.run_gold, rm.run_chests.size()])

	# 3. Test Final Boss Stage (Stage 11)
	print("\n--- TESTING FINAL BOSS STAGE (Stage 11) ---")
	var boss_choices = rm.generate_stage_choices(10)
	assert(boss_choices.size() == 1, "Boss stage should have 1 final boss choice")
	var boss_c = boss_choices[0]
	assert(boss_c.type == "boss", "Boss choice type must be 'boss'")
	print("Boss Choice: %s | Phases: %d | Gold: %d" % [boss_c.title, boss_c.boss_phases, boss_c.reward_gold])

	rm.select_stage_choice(0)
	rm.complete_current_stage()
	print("Boss defeated! Run status: is_run_active = %s" % str(rm.is_run_active))

	# 4. Test Scene Instantiation
	print("\n--- TESTING SCENE INSTANTIATION ---")
	var stage_select_scene = load("res://scenes/stage/StageSelectScreen.tscn")
	assert(stage_select_scene != null, "StageSelectScreen.tscn must load")
	var stage_select_instance = stage_select_scene.instantiate()
	assert(stage_select_instance != null, "StageSelectScreen.tscn must instantiate")
	stage_select_instance.free()
	print("[PASS] StageSelectScreen.tscn loaded and instantiated.")

	var stage_hub_scene = load("res://scenes/stage/StageRewardHub.tscn")
	assert(stage_hub_scene != null, "StageRewardHub.tscn must load")
	var stage_hub_instance = stage_hub_scene.instantiate()
	assert(stage_hub_instance != null, "StageRewardHub.tscn must instantiate")
	stage_hub_instance.free()
	print("[PASS] StageRewardHub.tscn loaded and instantiated.")

	print("\n==========================================")
	print(">>> ALL 10 STAGES + BOSS TESTS PASSED! <<<")
	print("==========================================\n")

	get_tree().quit(0)
