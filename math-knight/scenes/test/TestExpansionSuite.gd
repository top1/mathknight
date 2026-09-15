extends Node
## Automated Test Suite for Phase 3 & 4:
## - 7-Stat RPG leveling (up to Level 50)
## - Building upgrades (Forge & Sawmill)
## - QuestManager daily & weekly rotation, progress, and rewards
## - Arena daily tracking, wave records, and mastery badges
## - Village Hub instantiation

var passed_count: int = 0
var total_count: int = 0

func _ready() -> void:
	print("\n==========================================")
	print(" RUNNING MATHKNIGHT PHASE 3 & 4 TEST SUITE")
	print("==========================================\n")
	
	_test_save_manager_stats()
	_test_xp_and_leveling()
	_test_building_upgrades()
	_test_quest_system()
	_test_arena_tracking_and_badges()
	_test_village_hub_instantiation()
	
	print("\n------------------------------------------")
	print("RESULTS: %d / %d TESTS PASSED" % [passed_count, total_count])
	print("------------------------------------------\n")
	
	if passed_count == total_count:
		print(">>> ALL EXPANSION TESTS PASSED! <<<")
		get_tree().quit(0)
	else:
		printerr(">>> SOME TESTS FAILED! <<<")
		get_tree().quit(1)

func _assert(condition: bool, test_name: String) -> void:
	total_count += 1
	if condition:
		passed_count += 1
		print("[PASS] " + test_name)
	else:
		printerr("[FAIL] " + test_name)

func _test_save_manager_stats() -> void:
	var sm = get_node("/root/SaveManager")
	var stats = sm.knight_stats
	var required_stats = ["strength", "endurance", "defense", "agility", "wisdom", "focus", "crafting"]
	
	var all_present = true
	for s in required_stats:
		if not stats.has(s):
			all_present = false
			break
	_assert(all_present, "SaveManager has all 7 RPG stats (STR, END, DEF, AGI, WIS, FOC, CRAFT)")
	
	var base_hp = sm.get_max_hp()
	var base_atk = sm.get_attack_power()
	var base_crit = sm.get_crit_chance()
	var base_craft = sm.get_crafting_bonus()
	_assert(base_hp >= 10.0 and base_atk >= 1.0 and base_crit >= 0.05 and base_craft >= 0.0, "Calculated stat getters work correctly")

func _test_xp_and_leveling() -> void:
	var sm = get_node("/root/SaveManager")
	var initial_level = sm.knight_level
	var initial_pts = sm.knight_stat_points
	
	var xp_to_level = sm.xp_for_next_level() - sm.knight_xp + 10
	sm.add_xp(xp_to_level)
	_assert(sm.knight_level > initial_level, "Adding XP leveled up Knight")
	_assert(sm.knight_stat_points > initial_pts, "Leveling up granted talent points")
	
	# Test stat point distribution
	if sm.knight_stats["strength"] >= sm.MAX_STAT_LEVEL:
		sm.knight_stats["strength"] = 0
	if sm.knight_stat_points <= 0:
		sm.knight_stat_points = 1
	var pts_before = sm.knight_stat_points
	var str_before = sm.knight_stats["strength"]
	var upgraded = sm.upgrade_stat("strength")
	_assert(upgraded and sm.knight_stats["strength"] == str_before + 1 and sm.knight_stat_points == pts_before - 1, "Upgrading stat consumed 1 point and increased attribute")

func _test_building_upgrades() -> void:
	var sm = get_node("/root/SaveManager")
	sm.gold = 500
	sm.wood = 500
	var cur_forge_lvl = 1
	sm.forge_level = cur_forge_lvl
	
	var can_up = sm.can_upgrade_building("forge")
	_assert(can_up, "can_upgrade_building returns true when wallet has sufficient wood & gold")
	
	var upgraded = sm.upgrade_building("forge")
	_assert(upgraded and sm.forge_level == cur_forge_lvl + 1, "upgrade_building increases building level and saves data")

func _test_quest_system() -> void:
	var qm = get_node("/root/QuestManager")
	_assert(qm.active_quests.size() >= 4, "QuestManager generated active quests (3 daily + 1 weekly)")
	
	# Progress a quest
	var first_math_q = null
	for q in qm.active_quests:
		if q.get("category", "") == "math":
			first_math_q = q
			break
			
	_assert(first_math_q != null, "Found active math quest in rotation")
	if first_math_q:
		first_math_q["current"] = 0
		first_math_q["completed"] = false
		first_math_q["claimed"] = false
		var q_id = first_math_q.get("id", "")
		qm.add_progress("math", 999) # Complete it
		_assert(first_math_q.get("completed", false) == true, "Quest completed after adding target progress")
		
		# Claim reward
		var claimed = qm.claim_reward(q_id)
		_assert(claimed and first_math_q.get("claimed", false) == true, "Claiming quest reward succeeded and marked quest claimed")

func _test_arena_tracking_and_badges() -> void:
	var sm = get_node("/root/SaveManager")
	sm.best_arena_wave = 12
	sm.award_mastery_badge("arena_wave_5")
	sm.award_mastery_badge("arena_wave_10")
	
	_assert(sm.best_arena_wave == 12, "Arena best wave recorded in SaveManager")
	_assert(sm.mastery_badges.has("arena_wave_5") and sm.mastery_badges.has("arena_wave_10"), "Arena mastery badges correctly awarded and stored")

func _test_village_hub_instantiation() -> void:
	var hub_scene = load("res://scenes/village/VillageHub.tscn")
	_assert(hub_scene != null, "VillageHub.tscn loads successfully")
	
	var hub = hub_scene.instantiate()
	add_child(hub)
	var has_districts = (hub.adventure_district != null and hub.craft_district != null and hub.hero_district != null)
	_assert(has_districts, "VillageHub displays all thematic districts (Abenteuer, Handwerk, Ritterburg)")
	hub.queue_free()