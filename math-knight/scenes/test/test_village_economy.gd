extends SceneTree

func _init() -> void:
	print('--- TEST: Village Economy Systems ---')
	
	var sm_script = load('res://scripts/autoload/SaveManager.gd')
	var sm = sm_script.new()
	
	sm.reset_all_data()
	
	# 1. Base capacity check
	assert(sm.get_base_villager_capacity() == 10, 'Base capacity should be 10')
	assert(sm.get_max_villagers() == 10, 'Max villagers with 0 huts should be 10')
	assert(sm.get_max_huts() == 0, 'Level 1 knight should have 0 max huts')
	print('✓ Test 1: Level 1 base capacity passed.')
	
	# 2. Level up to Level 2 allows huts
	sm.knight_level = 2
	assert(sm.get_max_huts() == 1, 'Level 2 knight should have 1 max hut')
	var cost = sm.get_hut_cost()
	assert(cost.wood == 20 and cost.gold == 10, 'First hut costs 20 wood, 10 gold')
	assert(!sm.can_build_hut(), 'Cannot build hut without resources')
	
	sm.add_wood(50)
	sm.add_gold(50)
	assert(sm.can_build_hut(), 'Can build hut with sufficient resources')
	
	var built = sm.build_hut()
	assert(built, 'Hut building succeeded')
	assert(sm.hut_count == 1, 'Hut count should be 1')
	assert(sm.get_max_villagers() == 15, 'Max villagers with 1 hut should be 15')
	assert(!sm.can_build_hut(), 'Cannot build beyond max huts')
	print('✓ Test 2: Hut building and capacity scaling passed.')
	
	# 3. Attracting villagers with bread
	assert(sm.villagers == 0, 'Starts with 0 villagers')
	var attracted = sm.try_attract_villagers()
	assert(attracted == 0, 'No villagers attracted without bread')
	
	sm.add_bread(10)
	attracted = sm.try_attract_villagers()
	assert(attracted == 3, 'Up to 3 villagers attracted at once')
	assert(sm.villagers == 3, 'Villagers should now be 3')
	assert(sm.bread == 7, '3 bread consumed for 3 villagers')
	print('✓ Test 3: Villager attraction with bread passed.')
	
	# 4. Tax collection with cooldown
	assert(sm.can_collect_taxes(), 'Can collect taxes')
	var tax = sm.collect_taxes()
	assert(tax == 9, '3 villagers * 3 gold = 9 gold')
	assert(sm.bread == 4, '3 bread eaten for taxes')
	assert(!sm.can_collect_taxes(), 'Cannot collect taxes during cooldown')
	assert(sm.get_tax_cooldown_remaining() > 0.0, 'Cooldown timer is active')
	print('✓ Test 4: Tax collection and cooldown passed.')
	
	# 5. Weapon forging and soldier recruitment
	assert(sm.weapons_stock == 0, 'No weapons initially')
	sm.add_weapons(2)
	assert(sm.weapons_stock == 2, 'Weapons stock updated to 2')
	
	assert(sm.soldiers == 0, '0 soldiers initially')
	assert(sm.can_recruit_soldier(), 'Can recruit')
	
	var recruited = sm.recruit_soldier()
	assert(recruited, 'Recruitment succeeded')
	assert(sm.soldiers == 1, 'Soldiers now 1')
	assert(sm.villagers == 2, 'Villagers reduced by 1')
	assert(sm.weapons_stock == 1, 'Weapons reduced by 1')
	print('✓ Test 5: Soldier recruitment passed.')
	
	# 6. Permanent soldier bonus
	sm.add_soldiers(5)
	assert(sm.soldiers == 6, 'Soldiers permanently increased')
	print('✓ Test 6: Permanent soldier bonus passed.')
	
	# 7. Save & Load
	sm.save_data()
	sm.load_data()
	assert(sm.hut_count == 1, 'Loaded hut count matches')
	assert(sm.villagers == 2, 'Loaded villagers match')
	assert(sm.soldiers == 6, 'Loaded soldiers match')
	assert(sm.weapons_stock == 1, 'Loaded weapons match')
	print('✓ Test 7: Persistence and save/load passed.')
	
	sm.free()
	print('\n=== ALL VILLAGE ECONOMY TESTS PASSED! ===')
	quit(0)
