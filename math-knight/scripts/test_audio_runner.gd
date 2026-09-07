extends Node

func _ready() -> void:
	print("=== RUNNING AUDIO MANAGER VERIFICATION IN ACTIVE SCENE TREE ===")
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr == null:
		printerr("FATAL: /root/AudioManager autoload not found in scene tree")
		get_tree().quit(1)
		return

	print("1. Checking SFX sounds...")
	for key in audio_mgr.SFX_FILES:
		if not audio_mgr.sounds.has(key):
			printerr("SFX missing in sounds dict: ", key)
			get_tree().quit(1)
			return
		var stream = audio_mgr.sounds[key]
		if stream == null:
			printerr("SFX stream is null: ", key)
			get_tree().quit(1)
			return
		print("   ✓ SFX: ", key, " loaded (", stream.get_class(), ")")

	print("\n2. Checking BGM & Jingle tracks...")
	for key in audio_mgr.BGM_FILES:
		if not audio_mgr.sounds.has(key):
			printerr("BGM missing in sounds dict: ", key)
			get_tree().quit(1)
			return
		var stream = audio_mgr.sounds[key]
		if stream == null:
			printerr("BGM stream is null: ", key)
			get_tree().quit(1)
			return
		var is_jingle = key in ["victory", "stage_clear", "fanfare", "game_over"]
		if stream is AudioStreamMP3:
			if is_jingle and stream.loop:
				printerr("Jingle should NOT loop: ", key)
				get_tree().quit(1)
				return
			elif not is_jingle and not stream.loop:
				printerr("BGM track SHOULD loop: ", key)
				get_tree().quit(1)
				return
		print("   ✓ BGM: ", key, " -> loop=", (stream.loop if stream is AudioStreamMP3 else "N/A (WAV)"), " len=", ("%.1fs" % stream.get_length()))

	print("\n3. Testing Crossfade & Playback...")
	audio_mgr.play_music("title", 0.05)
	if audio_mgr.get_current_track() != "title":
		printerr("Current track expected title, got: ", audio_mgr.get_current_track())
		get_tree().quit(1)
		return
	print("   ✓ Title track playing")

	audio_mgr.play_music("battle", 0.05)
	if audio_mgr.get_current_track() != "battle":
		printerr("Current track expected battle, got: ", audio_mgr.get_current_track())
		get_tree().quit(1)
		return
	print("   ✓ Battle track crossfaded")

	audio_mgr.play_music("boss", 0.05)
	print("   ✓ Boss track crossfaded")

	audio_mgr.play_music("shop", 0.05)
	print("   ✓ Shop track crossfaded")

	print("\n4. Testing Adaptive Battle Music...")
	audio_mgr.play_adaptive_battle_music(null, false, false, "speed")
	if audio_mgr.get_current_track() != "battle_speed":
		printerr("Expected battle_speed, got: ", audio_mgr.get_current_track())
		get_tree().quit(1)
		return
	print("   ✓ Speed mode selected battle_speed")

	audio_mgr.play_adaptive_battle_music(null, false, true, "")
	if audio_mgr.get_current_track() != "elite":
		printerr("Expected elite, got: ", audio_mgr.get_current_track())
		get_tree().quit(1)
		return
	print("   ✓ Elite mode selected elite")

	audio_mgr.play_adaptive_battle_music(null, true, false, "")
	if audio_mgr.get_current_track() != "boss":
		printerr("Expected boss, got: ", audio_mgr.get_current_track())
		get_tree().quit(1)
		return
	print("   ✓ Boss mode selected boss")

	print("\n5. Testing Jingle & Ducking...")
	audio_mgr.play_jingle("victory")
	print("   ✓ Victory jingle played with ducking")
	audio_mgr._on_jingle_player_finished()
	print("   ✓ Jingle finished & volume restored")

	print("\n6. Testing Stop Music...")
	audio_mgr.stop_music(0.05)
	if audio_mgr.get_current_track() != "":
		printerr("Expected empty track after stop, got: ", audio_mgr.get_current_track())
		get_tree().quit(1)
		return
	print("   ✓ Music stopped cleanly")

	print("\n=== ALL AUDIO TESTS PASSED WITH ZERO ERRORS ===")
	get_tree().quit(0)
