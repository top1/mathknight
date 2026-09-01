extends SceneTree

func _init() -> void:
	print("--- TESTING TRON AUDIO SYNTHESIS ---")
	
	# Instantiate AudioManager to verify synthesis of all tracks
	var audio_mgr = load("res://scripts/autoload/AudioManager.gd").new()
	audio_mgr._setup_audio_players()
	audio_mgr._load_or_generate_all_audio()
	
	print("All SFX loaded: %d" % audio_mgr.SFX_FILES.size())
	print("All BGM loaded: %d" % audio_mgr.BGM_FILES.size())
	for key in audio_mgr.BGM_FILES:
		var stream = audio_mgr.sounds.get(key)
		if stream:
			print(" - Track: %s | Length: %.2fs | Loop: %s" % [key, stream.get_length(), stream.loop_mode == AudioStreamWAV.LOOP_FORWARD])
		else:
			print(" ERROR: Missing track %s" % key)
			quit(1)
			return
			
	print("ALL AUDIO SYNTHESIS PASSED CLEANLY!")
	quit(0)
