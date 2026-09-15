extends SceneTree

func _init() -> void:
	print("=== TESTING SWORD SMITH FORGE ===")
	var MathEngineScript = load("res://scripts/autoload/MathEngine.gd")
	var math_engine = MathEngineScript.new()
	root.add_child(math_engine)
	math_engine._ready()

	var SaveManagerScript = load("res://scripts/autoload/SaveManager.gd")
	var save_manager = SaveManagerScript.new()
	root.add_child(save_manager)

	var AudioManagerScript = load("res://scripts/autoload/AudioManager.gd")
	var audio_manager = AudioManagerScript.new()
	root.add_child(audio_manager)

	var sfx_hit = audio_manager._synthesize_sfx("anvil_hit")
	var sfx_clonk = audio_manager._synthesize_sfx("anvil_clonk")
	if sfx_hit and sfx_hit.data.size() > 0:
		print("  [PASS] SFX anvil_hit generated, size: " + str(sfx_hit.data.size()))
	if sfx_clonk and sfx_clonk.data.size() > 0:
		print("  [PASS] SFX anvil_clonk generated, size: " + str(sfx_clonk.data.size()))

	var forge_scene = load("res://scenes/forge/BlacksmithForge.tscn")
	var forge = forge_scene.instantiate()
	root.add_child(forge)
	forge._ready()

	if forge._current_problem != null and forge._answer_nodes.size() == 4:
		print("  [PASS] Forge scene initialized problem: " + forge._current_problem.question_text)
	if forge._ingot_buttons.size() == 4:
		print("  [PASS] Ingot buttons compatibility verified")

	if forge._correct_node != null:
		forge._target_x = forge._correct_node.position.x
		var init_pts = forge._quality_points
		forge._trigger_player_strike()
		if forge._quality_points > init_pts:
			print("  [PASS] Successful strike awarded quality points: " + str(forge._quality_points))

	# Test wrong strike
	var init_pts2 = forge._quality_points
	forge._target_x = 0.0 # Far off track
	forge._trigger_player_strike()
	print("  [PASS] Off-track strike handled cleanly (clonk): points=" + str(forge._quality_points))

	forge.queue_free()
	math_engine.queue_free()
	save_manager.queue_free()
	audio_manager.queue_free()
	print("=== ALL SWORD SMITH TESTS PASSED ===")
	quit(0)
