extends SceneTree

func _init():
	print("--- Running Menu Verification Tests ---")
	var test_scenes = [
		"res://scenes/menu/TitleScreen.tscn",
		"res://scenes/menu/LoadingScreen.tscn",
		"res://scenes/menu/MainMenu.tscn",
		"res://scenes/menu/CosmeticInventory.tscn",
		"res://scenes/menu/LevelUpScreen.tscn",
		"res://scenes/shop/ShopScreen.tscn",
		"res://scenes/ui/ChestReward.tscn",
		"res://scenes/ui/HUD.tscn",
		"res://scenes/ui/GameOverScreen.tscn",
		"res://scenes/enemy/Enemy.tscn",
		"res://scenes/map/RunMap.tscn",
		"res://scenes/test/BubbleTuningLab.tscn",
		"res://scenes/main/Main.tscn"
	]
	
	var pass_count = 0
	for path in test_scenes:
		var scene_res = load(path)
		if scene_res == null:
			printerr("FAILED to load scene: ", path)
			continue
		var instance = scene_res.instantiate()
		if instance == null:
			printerr("FAILED to instantiate scene: ", path)
			continue
		root.add_child(instance)
		print("SUCCESS: Instantiated ", path, " (Root node: ", instance.name, ")")
		pass_count += 1
		instance.queue_free()
		
	print("Verification Summary: %d/%d scenes passed successfully!" % [pass_count, test_scenes.size()])
	quit(0 if pass_count == test_scenes.size() else 1)
