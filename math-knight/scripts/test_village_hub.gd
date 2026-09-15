extends SceneTree

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	print("==================================================")
	print(">>> RUNNING REDESIGNED VILLAGE HUB TEST SUITE <<<")
	print("==================================================")

	var success := true

	# 1. Setup autoload singletons if missing
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

	if not root.has_node("/root/RunManager"):
		var rm = load("res://scripts/autoload/RunManager.gd").new()
		rm.name = "RunManager"
		root.add_child(rm)

	# 2. Instantiate VillageHub scene
	var scene: PackedScene = load("res://scenes/village/VillageHub.tscn")
	if not scene:
		printerr("FAIL: Could not load res://scenes/village/VillageHub.tscn")
		quit(1)
		return

	var hub = scene.instantiate()
	root.add_child(hub)
	await process_frame

	print("\n[TEST 1] Verifying all district nodes and zero scrollbar existence...")
	if not hub.tab_adventure_btn or not hub.tab_craft_btn or not hub.tab_hero_btn:
		printerr("FAIL: Tab buttons not properly mapped!")
		success = false
	else:
		print("✓ All 3 District Tab buttons found.")

	if not hub.adventure_district or not hub.craft_district or not hub.hero_district:
		printerr("FAIL: District containers not found!")
		success = false
	else:
		print("✓ All 3 District containers found.")

	# Check for absence of ScrollContainer
	var scroll_containers = []
	_find_scroll_containers(hub, scroll_containers)
	if scroll_containers.size() > 0:
		printerr("FAIL: ScrollContainer found in tree! Expected 0 scrollbars.")
		success = false
	else:
		print("✓ CONFIRMED: Zero ScrollContainers in VillageHub! 100% Scrollbar-free.")

	print("\n[TEST 2] Verifying Card Populations across all 3 districts...")
	if hub.adventure_district.get_child_count() != 4:
		printerr("FAIL: Expected 4 adventure cards, got %d" % hub.adventure_district.get_child_count())
		success = false
	else:
		print("✓ Adventure District contains 4 cards (Verlies, Burg-Angriff, Arena, Anschlagtafel).")

	if hub.craft_district.get_child_count() != 4:
		printerr("FAIL: Expected 4 craft cards, got %d" % hub.craft_district.get_child_count())
		success = false
	else:
		print("✓ Craft District contains 4 cards (Schmiede, Sägewerk, Bäckerei, Dorfleben).")

	if hub.hero_district.get_child_count() != 3:
		printerr("FAIL: Expected 3 hero cards, got %d" % hub.hero_district.get_child_count())
		success = false
	else:
		print("✓ Hero District contains 3 cards (Profil/XP, 7 Attribute, Königsgarderobe).")

	print("\n[TEST 3] Testing District Switching & Page Indicators...")
	hub.switch_district(1, false)
	if hub.current_district != 1 or not hub.craft_district.visible or hub.adventure_district.visible:
		printerr("FAIL: Craft district did not become visible on switch!")
		success = false
	else:
		print("✓ Switched to Craft district (Index 1) successfully: %s" % hub.page_indicator_label.text)

	hub.switch_district(2, false)
	if hub.current_district != 2 or not hub.hero_district.visible or hub.craft_district.visible:
		printerr("FAIL: Hero district did not become visible on switch!")
		success = false
	else:
		print("✓ Switched to Hero district (Index 2) successfully: %s" % hub.page_indicator_label.text)

	hub.switch_district(0, false)
	if hub.current_district != 0 or not hub.adventure_district.visible:
		printerr("FAIL: Adventure district did not return to visible!")
		success = false
	else:
		print("✓ Cycled back to Adventure district (Index 0): %s" % hub.page_indicator_label.text)

	print("\n[TEST 4] Testing Touch Swipe Evaluation...")
	# Simulate left swipe (drag left, i.e. delta.x = -80) -> should go to next district (1)
	hub._evaluate_swipe(Vector2(-80, 5))
	if hub.current_district != 1:
		printerr("FAIL: Left swipe did not advance to district 1!")
		success = false
	else:
		print("✓ Left swipe correctly advanced to district 1.")

	# Simulate right swipe (drag right, i.e. delta.x = 80) -> should go to prev district (0)
	hub._evaluate_swipe(Vector2(80, -2))
	if hub.current_district != 0:
		printerr("FAIL: Right swipe did not go back to district 0!")
		success = false
	else:
		print("✓ Right swipe correctly returned to district 0.")

	print("\n[TEST 5] Testing TopBar Mute Button...")
	var initial_muted = root.get_node("AudioManager").is_master_muted()
	hub._on_mute_pressed()
	if root.get_node("AudioManager").is_master_muted() == initial_muted:
		printerr("FAIL: Mute button did not toggle master mute state!")
		success = false
	else:
		print("✓ Mute button toggled state to: %s" % hub.mute_btn.text)
	# Toggle back
	hub._on_mute_pressed()

	print("\n==================================================")
	if success:
		print(">>> ALL VILLAGE HUB TESTS PASSED (100%) <<<")
		print("==================================================")
		quit(0)
	else:
		printerr(">>> SOME TESTS FAILED <<<")
		print("==================================================")
		quit(1)

func _find_scroll_containers(node: Node, result: Array) -> void:
	if node is ScrollContainer:
		result.append(node)
	for c in node.get_children():
		_find_scroll_containers(c, result)
