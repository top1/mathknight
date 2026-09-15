extends Node
## AudioManager singleton for MathKnight.
## Manages SFX pool, BGM crossfading, procedural audio synthesis, adaptive track selection, and event connections.
## Features a high-octane, super-harmonic TRON / Cyberpunk synthesizer engine.

# Audio file paths
const AUDIO_DIR: String = "res://assets/audio/"

const SFX_FILES: Dictionary = {
	"bubble_pop": "res://assets/audio/sfx_bubble_pop.wav",
	"sword_slash": "res://assets/audio/sfx_sword_slash.wav",
	"correct": "res://assets/audio/sfx_correct.wav",
	"wrong": "res://assets/audio/sfx_wrong.wav",
	"coin": "res://assets/audio/sfx_coin.wav",
	"diamond": "res://assets/audio/sfx_diamond.wav",
	"click": "res://assets/audio/sfx_click.wav",
	"levelup": "res://assets/audio/sfx_levelup.wav",
	"chest_open": "res://assets/audio/sfx_chest_open.wav",
	"chest_break": "res://assets/audio/sfx_chest_break.wav",
	"anvil_hit": "res://assets/audio/sfx_anvil_hit.wav",
	"anvil_clonk": "res://assets/audio/sfx_anvil_clonk.wav"
}

const BGM_FILES: Dictionary = {
	# Menu & Exploration (MENUE1 & MENU2)
	"title": "res://assets/audio/MENUE1_Tomes_and_Tally.mp3",
	"menu": "res://assets/audio/MENUE1_Tomes_and_Tally.mp3",
	"menu1": "res://assets/audio/MENUE1_Tomes_and_Tally.mp3",
	"stage_select": "res://assets/audio/MENUE1_Tomes_and_Tally.mp3",
	
	"map": "res://assets/audio/MENU2_Sunlight_on_Parchment.mp3",
	"menu2": "res://assets/audio/MENU2_Sunlight_on_Parchment.mp3",
	"menu_tavern": "res://assets/audio/MENU2_Sunlight_on_Parchment.mp3",
	"shop": "res://assets/audio/MENU2_Sunlight_on_Parchment.mp3",
	
	# Action 1 (Courtyard skirmishes & standard combat)
	"battle": "res://assets/audio/ACTION1_A_Gambit_in_the_Courtyard.mp3",
	"action1": "res://assets/audio/ACTION1_A_Gambit_in_the_Courtyard.mp3",
	"battle_skirmish": "res://assets/audio/ACTION1_A_Gambit_in_the_Courtyard.mp3",
	"battle_addition": "res://assets/audio/ACTION1_A_Gambit_in_the_Courtyard.mp3",
	"battle_subtraction": "res://assets/audio/ACTION1_A_Gambit_in_the_Courtyard.mp3",
	"battle_multiplication": "res://assets/audio/ACTION1_A_Gambit_in_the_Courtyard.mp3",
	
	# Action 2 (The Fencing Master's Gambit: boss, elite, speed, high stakes)
	"action2": "res://assets/audio/ACTION2_The_Fencing_Master_s_Gambit.mp3",
	"boss": "res://assets/audio/ACTION2_The_Fencing_Master_s_Gambit.mp3",
	"elite": "res://assets/audio/ACTION2_The_Fencing_Master_s_Gambit.mp3",
	"battle_speed": "res://assets/audio/ACTION2_The_Fencing_Master_s_Gambit.mp3",
	"battle_mixed": "res://assets/audio/ACTION2_The_Fencing_Master_s_Gambit.mp3",
	
	# Crafting & Smithing (Blacksmith Forge & Result-to-Equation)
	"crafting": "res://assets/audio/CRAFTING_SMITHING_Steel_Beneath_The_Hearth.mp3",
	"smithing": "res://assets/audio/CRAFTING_SMITHING_Steel_Beneath_The_Hearth.mp3",
	"battle_forge": "res://assets/audio/CRAFTING_SMITHING_Steel_Beneath_The_Hearth.mp3",
	"forge": "res://assets/audio/CRAFTING_SMITHING_Steel_Beneath_The_Hearth.mp3",
	
	# Puzzle (The Scholar's Gambit: chain calculation, siege gate, puzzle modes)
	"puzzle": "res://assets/audio/PUZZLE_The_Scholar_s_Gambit.mp3",
	"battle_chain": "res://assets/audio/PUZZLE_The_Scholar_s_Gambit.mp3",
	"battle_division": "res://assets/audio/PUZZLE_The_Scholar_s_Gambit.mp3",
	
	# Castle Town, Village Hub, Workshops & Success (CASTLE_TOWN_SUCCESS)
	"village": "res://assets/audio/CASTLE_TOWN_SUCCESS_The_Lathe_s_Morning.mp3",
	"town": "res://assets/audio/CASTLE_TOWN_SUCCESS_The_Lathe_s_Morning.mp3",
	"castle_town": "res://assets/audio/CASTLE_TOWN_SUCCESS_The_Lathe_s_Morning.mp3",
	"castle": "res://assets/audio/CASTLE_TOWN_SUCCESS_The_Lathe_s_Morning.mp3",
	"lumber": "res://assets/audio/CASTLE_TOWN_SUCCESS_The_Lathe_s_Morning.mp3",
	"bakery": "res://assets/audio/CASTLE_TOWN_SUCCESS_The_Lathe_s_Morning.mp3",
	"success": "res://assets/audio/CASTLE_TOWN_SUCCESS_The_Lathe_s_Morning.mp3",
	
	# Jingles
	"victory": "res://assets/audio/jingle_victory.wav",
	"stage_clear": "res://assets/audio/jingle_stage_clear.wav",
	"fanfare": "res://assets/audio/jingle_victory.wav",
	"game_over": "res://assets/audio/jingle_game_over.wav"
}

# Volume settings
var master_volume: float = 1.0
var music_volume: float = 0.75
var sfx_volume: float = 0.9
var music_enabled: bool = true
var sfx_enabled: bool = true

# Sound library (holds AudioStream resources)
var sounds: Dictionary = {}

# Player nodes
var _music_player_a: AudioStreamPlayer
var _music_player_b: AudioStreamPlayer
var _active_music_player: AudioStreamPlayer
var _jingle_player: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
const SFX_POOL_SIZE: int = 12
var _sfx_pool_index: int = 0

var _current_track_name: String = ""
var _music_crossfade_tween: Tween
var _is_ducked_for_jingle: bool = false
var _last_finished_time: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_audio_players()
	_load_or_generate_all_audio()
	_connect_event_bus()
	_sync_with_save_manager()


func _setup_audio_players() -> void:
	# Music Player A
	_music_player_a = AudioStreamPlayer.new()
	_music_player_a.name = "MusicPlayerA"
	_music_player_a.bus = "Master"
	_music_player_a.finished.connect(func(): _on_music_player_finished(_music_player_a))
	add_child(_music_player_a)

	# Music Player B (for crossfading)
	_music_player_b = AudioStreamPlayer.new()
	_music_player_b.name = "MusicPlayerB"
	_music_player_b.bus = "Master"
	_music_player_b.finished.connect(func(): _on_music_player_finished(_music_player_b))
	add_child(_music_player_b)

	_active_music_player = _music_player_a

	# Jingle Player (for victory fanfares / stingers)
	_jingle_player = AudioStreamPlayer.new()
	_jingle_player.name = "JinglePlayer"
	_jingle_player.bus = "Master"
	_jingle_player.finished.connect(_on_jingle_player_finished)
	add_child(_jingle_player)

	# Polyphonic SFX Pool
	for i in range(SFX_POOL_SIZE):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.name = "SFXPlayer_" + str(i)
		p.bus = "Master"
		add_child(p)
		_sfx_pool.append(p)


func _on_music_player_finished(player: AudioStreamPlayer) -> void:
	# Loop safety fallback: if non-looping stream finishes, safely replay with throttle guard
	if player != _active_music_player or not music_enabled or _current_track_name == "":
		return
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	if now - _last_finished_time < 0.25:
		return
	_last_finished_time = now

	if player.stream and player.stream.get_length() > 0.1:
		player.call_deferred("play")


func _sync_with_save_manager() -> void:
	if not is_inside_tree() or not has_node("/root/SaveManager"):
		return
	var sm = get_node("/root/SaveManager")
	if "sfx_enabled" in sm:
		sfx_enabled = sm.sfx_enabled
	if "music_enabled" in sm:
		music_enabled = sm.music_enabled
	else:
		sm.set("music_enabled", true)
	if "master_muted" in sm:
		set_master_muted(sm.master_muted)


func _connect_event_bus() -> void:
	if not is_inside_tree() or not has_node("/root/EventBus"):
		return
	var eb = get_node("/root/EventBus")

	# Problem & Input
	eb.answer_selected.connect(_on_answer_selected)
	eb.answer_correct.connect(_on_answer_correct)
	eb.answer_wrong.connect(_on_answer_wrong)

	# Knight actions & damage
	if eb.has_signal("knight_attack_triggered"):
		eb.knight_attack_triggered.connect(_on_knight_attack_triggered)
	if eb.has_signal("enemy_attacks_knight"):
		eb.enemy_attacks_knight.connect(_on_enemy_attacks_knight)
	if eb.has_signal("knight_died"):
		eb.knight_died.connect(_on_knight_died)
	if eb.has_signal("knight_leveled_up"):
		eb.knight_leveled_up.connect(_on_knight_leveled_up)
	if eb.has_signal("knight_stat_upgraded"):
		eb.knight_stat_upgraded.connect(func(_stat, _val): play_sfx("levelup", 1.25, -1.0))

	# Rewards & Items
	if eb.has_signal("gold_earned"):
		eb.gold_earned.connect(_on_gold_earned)
	if eb.has_signal("diamonds_earned"):
		eb.diamonds_earned.connect(_on_diamonds_earned)
	if eb.has_signal("artifact_acquired"):
		eb.artifact_acquired.connect(func(_id): play_sfx("diamond", 1.1, 1.0))
	if eb.has_signal("chest_collected"):
		eb.chest_collected.connect(func(_d): play_sfx("chest_open", 1.1, -2.0))
	if eb.has_signal("chest_opened"):
		eb.chest_opened.connect(func(_d): play_sfx("chest_open", 1.0, 0.0))
	if eb.has_signal("flawless_set_achieved"):
		eb.flawless_set_achieved.connect(func(_n): play_sfx("levelup", 1.2, 1.0))

	# Game State / Boss / Run
	if eb.has_signal("game_won"):
		eb.game_won.connect(_on_game_won)
	if eb.has_signal("boss_spawned"):
		eb.boss_spawned.connect(func(_d): play_music("boss"))
	if eb.has_signal("boss_defeated"):
		eb.boss_defeated.connect(func(_d): play_jingle("victory"))
	if eb.has_signal("run_node_entered"):
		eb.run_node_entered.connect(_on_run_node_entered)


# === Event Handlers ===

func _on_answer_selected(_value: int, _method: String, _bubble: Area2D, _slice_dir: Vector2) -> void:
	play_sfx("bubble_pop", randf_range(0.95, 1.1))


func _on_answer_correct(_problem: RefCounted, chain_count: int = 1) -> void:
	var pitch: float = clampf(1.0 + float(chain_count - 1) * 0.08, 1.0, 1.6)
	play_sfx("correct", pitch)


func _on_answer_wrong(_problem: RefCounted) -> void:
	play_sfx("wrong", randf_range(0.95, 1.05))


func _on_knight_attack_triggered(_attack_type: String) -> void:
	play_sfx("sword_slash", randf_range(0.9, 1.15))


func _on_enemy_attacks_knight(_damage: float) -> void:
	play_sfx("wrong", 0.75, -2.0)


func _on_knight_died() -> void:
	stop_music(0.5)
	play_jingle("game_over")


func _on_knight_leveled_up(_new_level: int) -> void:
	play_sfx("levelup", 1.0, 2.0)


func _on_gold_earned(_amount: int, _reason: String = "") -> void:
	play_sfx("coin", randf_range(0.95, 1.1))


func _on_diamonds_earned(_amount: int) -> void:
	play_sfx("diamond", randf_range(0.98, 1.06), 2.0)


func _on_game_won(_stats: Dictionary) -> void:
	play_jingle("victory")


func _on_run_node_entered(node_data: Dictionary) -> void:
	var node_type: String = node_data.get("type", "combat")
	match node_type:
		"boss":
			play_music("boss")
		"elite":
			play_music("elite")
		"shop":
			play_music("shop")
		"rest":
			play_music("menu_tavern")
		_:
			play_adaptive_battle_music()


# === Public Playback API ===

func play_sfx(sound_name: String, pitch_scale: float = 1.0, volume_db: float = 0.0) -> AudioStreamPlayer:
	if not sfx_enabled or not is_inside_tree():
		return null
	if not sounds.has(sound_name):
		push_warning("AudioManager: SFX '%s' not found!" % sound_name)
		return null

	var stream: AudioStream = sounds[sound_name]
	if not stream:
		return null

	var player: AudioStreamPlayer = _sfx_pool[_sfx_pool_index]
	_sfx_pool_index = (_sfx_pool_index + 1) % SFX_POOL_SIZE

	player.stop()
	player.stream = stream
	player.pitch_scale = pitch_scale
	var base_db: float = linear_to_db(sfx_volume * master_volume)
	player.volume_db = base_db + volume_db
	player.play()
	return player


func play_music(track_name: String, fade_duration: float = 0.6) -> void:
	# Normalize aliases
	if track_name == "tavern":
		track_name = "menu_tavern"

	if _current_track_name == track_name and _active_music_player != null and _active_music_player.playing:
		return

	_current_track_name = track_name

	if not music_enabled or not is_inside_tree():
		return

	if not sounds.has(track_name):
		# Fallback aliases
		if track_name.begins_with("battle"):
			track_name = "battle"
		elif track_name.begins_with("menu"):
			track_name = "menu"

	if not sounds.has(track_name):
		push_warning("AudioManager: Music track '%s' not found!" % track_name)
		return

	var next_stream: AudioStream = sounds[track_name]
	if not next_stream:
		return

	# Choose incoming player
	var incoming_player: AudioStreamPlayer = _music_player_b if _active_music_player == _music_player_a else _music_player_a
	var outgoing_player: AudioStreamPlayer = _active_music_player

	incoming_player.stream = next_stream
	var target_volume_db: float = linear_to_db(music_volume * master_volume)
	if _is_ducked_for_jingle:
		target_volume_db = -22.0
	incoming_player.volume_db = -60.0
	incoming_player.play()

	if _music_crossfade_tween and _music_crossfade_tween.is_valid():
		_music_crossfade_tween.kill()

	_music_crossfade_tween = create_tween().set_parallel(true)
	_music_crossfade_tween.tween_property(incoming_player, "volume_db", target_volume_db, fade_duration)
	if outgoing_player and outgoing_player.playing:
		_music_crossfade_tween.tween_property(outgoing_player, "volume_db", -60.0, fade_duration)
		_music_crossfade_tween.chain().tween_callback(outgoing_player.stop)

	_active_music_player = incoming_player


func play_adaptive_battle_music(config: RefCounted = null, is_boss: bool = false, is_elite: bool = false, archetype: String = "") -> void:
	if is_boss:
		play_music("boss")
		return
	if is_elite or archetype == "elite":
		play_music("elite")
		return
	if archetype == "speed":
		play_music("battle_speed")
		return

	# If RunManager is active, check current stage data if not explicitly provided
	if has_node("/root/RunManager"):
		var rm = get_node("/root/RunManager")
		if rm and rm.is_run_active and rm.current_stage_data is Dictionary:
			var stg_type = rm.current_stage_data.get("type", "")
			var stg_arch = rm.current_stage_data.get("archetype", "")
			if stg_type == "boss":
				play_music("boss")
				return
			if stg_type == "elite" or stg_arch == "elite":
				play_music("elite")
				return
			if stg_type == "speed" or stg_arch == "speed":
				play_music("battle_speed")
				return

	if config == null and has_node("/root/MathEngine"):
		config = get_node("/root/MathEngine").current_config

	if config != null:
		var mode_val = config.get("game_mode")
		var op_val = config.get("operation")

		# GameMode check
		if mode_val == MathConfig.GameMode.RESULT_TO_EQUATION:
			play_music("battle_forge")
			return
		elif mode_val == MathConfig.GameMode.MULTI_OP_EQUATION:
			play_music("battle_chain")
			return

		# Operation check
		match op_val:
			MathConfig.Operation.ADDITION:
				play_music("battle_addition")
				return
			MathConfig.Operation.SUBTRACTION:
				play_music("battle_subtraction")
				return
			MathConfig.Operation.MULTIPLICATION:
				play_music("battle_multiplication")
				return
			MathConfig.Operation.DIVISION:
				play_music("battle_division")
				return
			MathConfig.Operation.MIXED:
				play_music("battle_mixed")
				return

	play_music("battle")


func stop_music(fade_duration: float = 0.8) -> void:
	_current_track_name = ""
	if _music_crossfade_tween and _music_crossfade_tween.is_valid():
		_music_crossfade_tween.kill()

	if not is_inside_tree() or fade_duration <= 0.0 or (not _music_player_a.playing and not _music_player_b.playing):
		if _music_player_a: _music_player_a.stop()
		if _music_player_b: _music_player_b.stop()
		return

	_music_crossfade_tween = create_tween().set_parallel(true)
	if _music_player_a.playing:
		_music_crossfade_tween.tween_property(_music_player_a, "volume_db", -60.0, fade_duration)
		_music_crossfade_tween.chain().tween_callback(_music_player_a.stop)
	if _music_player_b.playing:
		_music_crossfade_tween.tween_property(_music_player_b, "volume_db", -60.0, fade_duration)
		_music_crossfade_tween.chain().tween_callback(_music_player_b.stop)


func play_jingle(jingle_name: String) -> void:
	if not is_inside_tree() or not sounds.has(jingle_name):
		return
	var stream: AudioStream = sounds[jingle_name]
	if not stream:
		return

	# Temporarily duck music cleanly if active player is playing
	_is_ducked_for_jingle = true
	if _music_player_a.playing or _music_player_b.playing:
		var duck_tween: Tween = create_tween().set_parallel(true)
		if _music_player_a.playing:
			duck_tween.tween_property(_music_player_a, "volume_db", -22.0, 0.25)
		if _music_player_b.playing:
			duck_tween.tween_property(_music_player_b, "volume_db", -22.0, 0.25)

	_jingle_player.stop()
	_jingle_player.stream = stream
	_jingle_player.volume_db = linear_to_db(music_volume * master_volume) + 2.0
	_jingle_player.play()


func _on_jingle_player_finished() -> void:
	_is_ducked_for_jingle = false
	if not is_inside_tree():
		return
	if (_music_player_a and _music_player_a.playing) or (_music_player_b and _music_player_b.playing):
		var restore_tween: Tween = create_tween().set_parallel(true)
		var target_vol: float = linear_to_db(music_volume * master_volume)
		if _music_player_a and _music_player_a.playing:
			restore_tween.tween_property(_music_player_a, "volume_db", target_vol, 0.8)
		if _music_player_b and _music_player_b.playing:
			restore_tween.tween_property(_music_player_b, "volume_db", target_vol, 0.8)


func set_music_enabled(p_enabled: bool) -> void:
	music_enabled = p_enabled
	if has_node("/root/SaveManager"):
		get_node("/root/SaveManager").set("music_enabled", music_enabled)
	if not music_enabled:
		stop_music(0.3)
	elif _current_track_name != "":
		play_music(_current_track_name, 0.5)


func set_sfx_enabled(p_enabled: bool) -> void:
	sfx_enabled = p_enabled
	if has_node("/root/SaveManager"):
		get_node("/root/SaveManager").sfx_enabled = sfx_enabled


func is_music_enabled() -> bool:
	return music_enabled


func is_sfx_enabled() -> bool:
	return sfx_enabled


func get_current_track() -> String:
	return _current_track_name


func toggle_mute() -> bool:
	var new_state: bool = not is_master_muted()
	set_master_muted(new_state)
	return new_state


func is_master_muted() -> bool:
	var bus_idx: int = AudioServer.get_bus_index("Master")
	return AudioServer.is_bus_mute(bus_idx)


func set_master_muted(muted: bool) -> void:
	var bus_idx: int = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus_idx, muted)
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		sm.set("master_muted", muted)
		if sm.has_method("save_data"):
			sm.save_data()
	if has_node("/root/EventBus"):
		var eb = get_node("/root/EventBus")
		if eb.has_signal("sound_mute_toggled"):
			eb.sound_mute_toggled.emit(muted)


# === Audio Loading & Procedural Synthesis Engine ===

func _load_or_generate_all_audio() -> void:
	# 1. SFX: Load from disk first, fallback to in-memory synthesis without disk writes
	for key in SFX_FILES:
		var file_path: String = SFX_FILES[key]
		var stream: AudioStream = null
		if ResourceLoader.exists(file_path):
			stream = load(file_path) as AudioStream
		if not stream:
			stream = _synthesize_sfx(key)
		sounds[key] = stream

	# 2. BGM & Jingles: Load high-quality audio files from disk (MP3 / WAV)
	for key in BGM_FILES:
		var file_path: String = BGM_FILES[key]
		var stream: AudioStream = null
		if ResourceLoader.exists(file_path):
			stream = load(file_path) as AudioStream

		if stream is AudioStreamMP3:
			# Non-looping for fanfares/jingles, looping for background music
			var is_jingle: bool = (key in ["victory", "stage_clear", "fanfare", "game_over"])
			stream.loop = not is_jingle
			stream.loop_offset = 0.0
		elif stream is AudioStreamWAV:
			var is_jingle: bool = (key in ["victory", "stage_clear", "fanfare", "game_over"])
			if is_jingle:
				stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
		elif not stream:
			# In-memory synthesis fallback if file is missing
			stream = _synthesize_bgm(key)

		sounds[key] = stream


func _synthesize_sfx(sfx_key: String) -> AudioStreamWAV:
	match sfx_key:
		"bubble_pop": return _synth_bubble_pop()
		"sword_slash": return _synth_sword_slash()
		"correct": return _synth_correct()
		"wrong": return _synth_wrong()
		"coin": return _synth_coin()
		"diamond": return _synth_diamond()
		"click": return _synth_click()
		"levelup": return _synth_levelup()
		"chest_open": return _synth_chest_open()
		"chest_break": return _synth_chest_break()
		"anvil_hit": return _synth_anvil_hit()
		"anvil_clonk": return _synth_anvil_clonk()
		_: return _synth_click()


func _synthesize_bgm(bgm_key: String) -> AudioStreamWAV:
	match bgm_key:
		"title": return _synth_bgm_title()
		"menu", "menu_tavern": return _synth_bgm_menu()
		"shop": return _synth_bgm_shop()
		"map": return _synth_bgm_map()
		"battle": return _synth_bgm_battle()
		"battle_addition": return _synth_bgm_addition()
		"battle_subtraction": return _synth_bgm_subtraction()
		"battle_multiplication": return _synth_bgm_multiplication()
		"battle_division": return _synth_bgm_division()
		"battle_mixed": return _synth_bgm_mixed()
		"battle_forge": return _synth_bgm_forge()
		"battle_chain": return _synth_bgm_chain()
		"elite": return _synth_bgm_elite()
		"boss": return _synth_bgm_boss()
		"victory": return _synth_jingle_victory()
		"stage_clear": return _synth_jingle_stage_clear()
		"game_over": return _synth_jingle_game_over()
		_: return _synth_bgm_menu()


# --- Procedural Synthesis Engine ---

const SAMPLE_RATE: int = 22050


func _create_wav_stream(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	else:
		wav.loop_mode = AudioStreamWAV.LOOP_DISABLED
		wav.loop_begin = 0
		wav.loop_end = 0

	var byte_data: PackedByteArray = PackedByteArray()
	byte_data.resize(samples.size() * 2)

	for i in range(samples.size()):
		var clamped: float = clampf(samples[i], -1.0, 1.0)
		var val_16: int = int(clamped * 32767.0)
		byte_data.encode_s16(i * 2, val_16)

	wav.data = byte_data
	return wav


func _save_wav_file(path: String, wav_stream: AudioStreamWAV) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return

	var raw_data: PackedByteArray = wav_stream.data
	var data_size: int = raw_data.size()
	var chunk_size: int = 36 + data_size
	var channels: int = 1 if not wav_stream.stereo else 2
	var byte_rate: int = SAMPLE_RATE * channels * 2
	var block_align: int = channels * 2

	# RIFF Header
	file.store_string("RIFF")
	file.store_32(chunk_size)
	file.store_string("WAVE")

	# fmt subchunk
	file.store_string("fmt ")
	file.store_32(16)
	file.store_16(1)
	file.store_16(channels)
	file.store_32(SAMPLE_RATE)
	file.store_32(byte_rate)
	file.store_16(block_align)
	file.store_16(16)

	# data subchunk
	file.store_string("data")
	file.store_32(data_size)
	file.store_buffer(raw_data)
	file.close()


# --- Sound Effect Synthesizers (Cyber / Laser / Neon Styling) ---

func _synth_bubble_pop() -> AudioStreamWAV:
	var duration: float = 0.12
	var num_samples: int = int(duration * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(num_samples)
	var phase: float = 0.0
	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var progress: float = t / duration
		var freq: float = lerpf(1250.0, 180.0, progress * progress)
		phase += freq * (TAU / SAMPLE_RATE)
		var env: float = exp(-t * 36.0)
		var laser_chirp: float = sin(phase) + 0.3 * sin(phase * 2.0)
		var click: float = (randf_range(-1.0, 1.0) * 0.4) if (i < 30) else 0.0
		samples[i] = (laser_chirp + click) * env * 0.88
	return _create_wav_stream(samples, false)


func _synth_sword_slash() -> AudioStreamWAV:
	var duration: float = 0.22
	var num_samples: int = int(duration * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(num_samples)
	var noise_filter: float = 0.0
	var phase: float = 0.0
	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var progress: float = t / duration
		var freq: float = lerpf(720.0, 120.0, progress)
		phase += freq * (TAU / SAMPLE_RATE)
		var plasma_tone: float = (fmod(phase, 1.0) * 2.0 - 1.0) * 0.45
		var white_noise: float = randf_range(-1.0, 1.0)
		var filter_coeff: float = lerpf(0.65, 0.12, progress)
		noise_filter = noise_filter + filter_coeff * (white_noise - noise_filter)
		var env: float = (t / 0.02) if t < 0.02 else exp(-(t - 0.02) * 14.0)
		samples[i] = (plasma_tone + noise_filter * 0.8) * env * 0.85
	return _create_wav_stream(samples, false)


func _synth_correct() -> AudioStreamWAV:
	var duration: float = 0.48
	var num_samples: int = int(duration * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(num_samples)
	# Sparkling major 9th cyber chime (C6, E6, G6, B6)
	var freqs: Array[float] = [1046.50, 1318.51, 1567.98, 1975.53]
	var offsets: Array[float] = [0.0, 0.06, 0.12, 0.18]
	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var total_sample: float = 0.0
		for n in range(freqs.size()):
			var note_t: float = t - offsets[n]
			if note_t >= 0.0:
				var f: float = freqs[n]
				var env: float = exp(-note_t * 8.5)
				var bell: float = sin(note_t * f * TAU) + 0.35 * sin(note_t * f * 2.76 * TAU) + 0.18 * sin(note_t * f * 4.2 * TAU)
				total_sample += bell * env * 0.28
		samples[i] = total_sample
	return _create_wav_stream(samples, false)


func _synth_wrong() -> AudioStreamWAV:
	var duration: float = 0.32
	var num_samples: int = int(duration * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(num_samples)
	var phase1: float = 0.0
	var phase2: float = 0.0
	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var f1: float = lerpf(140.0, 80.0, t / duration)
		var f2: float = lerpf(148.0, 84.0, t / duration)
		phase1 += f1 * (TAU / SAMPLE_RATE)
		phase2 += f2 * (TAU / SAMPLE_RATE)
		var saw1: float = fmod(phase1, 1.0) * 2.0 - 1.0
		var saw2: float = fmod(phase2, 1.0) * 2.0 - 1.0
		var env: float = 1.0 if t < 0.18 else exp(-(t - 0.18) * 18.0)
		samples[i] = (saw1 * 0.35 + saw2 * 0.35) * env
	return _create_wav_stream(samples, false)


func _synth_coin() -> AudioStreamWAV:
	var duration: float = 0.28
	var num_samples: int = int(duration * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(num_samples)
	var phase: float = 0.0
	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var f: float = 1174.66 if t < 0.05 else 1760.0 # D6 -> A6
		phase += f * (TAU / SAMPLE_RATE)
		var note_t: float = t if t < 0.05 else (t - 0.05)
		var env: float = exp(-note_t * 12.0)
		var neon_coin: float = sin(phase) + 0.3 * sin(phase * 2.0) + 0.15 * sin(phase * 3.0)
		samples[i] = neon_coin * env * 0.55
	return _create_wav_stream(samples, false)


func _synth_diamond() -> AudioStreamWAV:
	var duration: float = 0.65
	var num_samples: int = int(duration * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(num_samples)
	var freqs: Array[float] = [1318.51, 1567.98, 1975.53, 2637.02] # E6 -> G6 -> B6 -> E7
	var offsets: Array[float] = [0.0, 0.07, 0.14, 0.21]
	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var total_sample: float = 0.0
		for n in range(freqs.size()):
			var note_t: float = t - offsets[n]
			if note_t >= 0.0:
				var f: float = freqs[n]
				var vibrato: float = sin(note_t * 14.0) * 5.0
				var env: float = exp(-note_t * 6.5)
				var bell: float = sin(note_t * (f + vibrato) * TAU) + 0.35 * sin(note_t * f * 2.0 * TAU) + 0.15 * sin(note_t * f * 3.0 * TAU)
				total_sample += bell * env * 0.26
		samples[i] = total_sample
	return _create_wav_stream(samples, false)


func _synth_click() -> AudioStreamWAV:
	var duration: float = 0.035
	var num_samples: int = int(duration * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(num_samples)
	var phase: float = 0.0
	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var f: float = lerpf(2400.0, 800.0, t / duration)
		phase += f * (TAU / SAMPLE_RATE)
		var env: float = exp(-t * 110.0)
		samples[i] = (sin(phase) + (randf_range(-1.0, 1.0) * 0.2)) * env * 0.85
	return _create_wav_stream(samples, false)


func _synth_levelup() -> AudioStreamWAV:
	var duration: float = 1.15
	var num_samples: int = int(duration * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(num_samples)
	var notes: Array[float] = [523.25, 659.25, 783.99, 1046.50]
	var step_dur: float = 0.14
	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var total_sample: float = 0.0
		var note_idx: int = mini(int(t / step_dur), 3)
		if t < step_dur * 4.0:
			var note_t: float = t - float(note_idx) * step_dur
			var f: float = notes[note_idx]
			var env: float = exp(-note_t * 5.0)
			var saw_a: float = fmod(note_t * f * 0.995, 1.0) * 2.0 - 1.0
			var saw_b: float = fmod(note_t * f * 1.005, 1.0) * 2.0 - 1.0
			total_sample = (saw_a + saw_b) * 0.5 * env * 0.42
		else:
			var chord_t: float = t - step_dur * 4.0
			var env: float = exp(-chord_t * 2.2)
			for f in notes:
				var saw: float = fmod(chord_t * f, 1.0) * 2.0 - 1.0
				var sin_layer: float = sin(chord_t * f * TAU)
				total_sample += (saw * 0.4 + sin_layer * 0.6) * env * 0.14
		samples[i] = total_sample
	return _create_wav_stream(samples, false)


func _synth_chest_open() -> AudioStreamWAV:
	var duration: float = 0.65
	var num_samples: int = int(duration * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(num_samples)
	var phase_chirp: float = 0.0
	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var total_sample: float = 0.0
		if t < 0.22:
			var f: float = lerpf(300.0, 950.0, t / 0.22)
			phase_chirp += f * (TAU / SAMPLE_RATE)
			total_sample = sin(phase_chirp) * exp(-t * 7.0) * 0.45
		else:
			var chime_t: float = t - 0.22
			var chime_f: float = 1567.98
			var env: float = exp(-chime_t * 5.5)
			total_sample = (sin(chime_t * chime_f * TAU) + 0.4 * sin(chime_t * chime_f * 2.0 * TAU)) * env * 0.45
		samples[i] = total_sample
	return _create_wav_stream(samples, false)


func _synth_chest_break() -> AudioStreamWAV:
	var duration: float = 0.42
	var num_samples: int = int(duration * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(num_samples)
	var phase_thud: float = 0.0
	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var f_thud: float = lerpf(160.0, 35.0, t / duration)
		phase_thud += f_thud * (TAU / SAMPLE_RATE)
		var thud: float = sin(phase_thud) * exp(-t * 14.0) * 0.65
		var glitch: float = (randf_range(-1.0, 1.0) * exp(-t * 20.0) * 0.45) if (t < 0.15) else 0.0
		samples[i] = thud + glitch
	return _create_wav_stream(samples, false)


func _synth_anvil_hit() -> AudioStreamWAV:
	var duration: float = 0.55
	var num_samples: int = int(duration * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(num_samples)
	# Metallic ring frequencies (inharmonic steel resonance)
	var harmonics: Array[float] = [1280.0, 2450.0, 3820.0, 5600.0]
	var decays: Array[float] = [8.0, 14.0, 22.0, 32.0]
	var phase_body: float = 0.0
	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		# Deep punch transient
		var f_body: float = lerpf(240.0, 85.0, clampf(t / 0.1, 0.0, 1.0))
		phase_body += f_body * (TAU / SAMPLE_RATE)
		var punch: float = sin(phase_body) * exp(-t * 26.0) * 0.55

		# Bright metallic click/strike transient in first 10ms
		var click: float = (randf_range(-1.0, 1.0) * exp(-t * 120.0) * 0.6) if t < 0.03 else 0.0

		# Metallic ringing bells
		var ring: float = 0.0
		for h in range(harmonics.size()):
			var bell: float = sin(t * harmonics[h] * TAU)
			ring += bell * exp(-t * decays[h]) * (0.35 / float(h + 1))

		samples[i] = clampf(punch + click + ring, -1.0, 1.0) * 0.9
	return _create_wav_stream(samples, false)


func _synth_anvil_clonk() -> AudioStreamWAV:
	var duration: float = 0.22
	var num_samples: int = int(duration * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(num_samples)
	var phase: float = 0.0
	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var f: float = lerpf(180.0, 55.0, t / duration)
		phase += f * (TAU / SAMPLE_RATE)
		var thud: float = (sin(phase) + 0.4 * sin(phase * 2.3)) * exp(-t * 22.0) * 0.75
		var noise: float = (randf_range(-1.0, 1.0) * exp(-t * 40.0) * 0.35) if t < 0.05 else 0.0
		samples[i] = clampf(thud + noise, -1.0, 1.0) * 0.85
	return _create_wav_stream(samples, false)


# ==============================================================================
# --- TRON & SYNTHWAVE BGM SYNTHESIS ENGINE (DRIVING, SUPER-HARMONIC, ADDICTIVE) ---
# ==============================================================================

# 1. BGM Title: "The Grid Ascendant" (32 beats - 124 BPM, ~15.48s loop)
# Epic Daft Punk / TRON: Legacy synthwave anthem with rolling 16th cyber-bass, pumping supersaw chords, and soaring lead.
func _synth_bgm_title() -> AudioStreamWAV:
	var bpm: float = 124.0
	var beat_dur: float = 60.0 / bpm
	var total_beats: int = 32
	var duration: float = float(total_beats) * beat_dur
	var num_samples: int = int(duration * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(num_samples)

	# 8 bars: Dm9 -> Bbmaj7 -> Fmaj7 -> Cadd9 -> Dm9 -> Gm7 -> Bbmaj9 -> A7sus4
	var chords: Array = [
		[146.83, 220.00, 261.63, 329.63, 349.23], # Dm9
		[116.54, 233.08, 293.66, 349.23, 440.00], # Bbmaj7
		[174.61, 261.63, 329.63, 349.23, 392.00], # Fmaj7
		[130.81, 196.00, 261.63, 293.66, 329.63], # Cadd9
		[146.83, 220.00, 261.63, 329.63, 349.23], # Dm9
		[98.00,  196.00, 233.08, 293.66, 349.23], # Gm7
		[116.54, 233.08, 293.66, 349.23, 440.00], # Bbmaj9
		[110.00, 220.00, 293.66, 329.63, 440.00]  # A7sus4
	]
	var lead_melody: Array[float] = [
		587.33, 659.25, 698.46, 880.00,
		698.46, 587.33, 523.25, 587.33,
		659.25, 783.99, 880.00, 1046.50,
		880.00, 783.99, 659.25, 587.33,
		587.33, 698.46, 880.00, 1046.50,
		880.00, 698.46, 783.99, 880.00,
		698.46, 880.00, 1046.50, 1174.66,
		1046.50, 880.00, 783.99, 587.33
	]

	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var current_beat: float = t / beat_dur
		var bar_idx: int = mini(int(current_beat / 4.0), 7)
		var chord: Array = chords[bar_idx]
		var total_sample: float = 0.0

		var beat_frac: float = fmod(current_beat, 1.0)
		var sidechain: float = clampf(1.0 - 0.65 * exp(-beat_frac * 10.0), 0.2, 1.0)

		# 1. Pumping Lush Supersaw Pad (4-Voice Chords)
		var pad_sample: float = 0.0
		for voice_idx in range(chord.size()):
			var f: float = chord[voice_idx]
			var saw_a: float = fmod(t * f * 0.995, 1.0) * 2.0 - 1.0
			var saw_b: float = fmod(t * f * 1.005, 1.0) * 2.0 - 1.0
			pad_sample += (saw_a + saw_b) * 0.5
		total_sample += pad_sample * (0.28 / float(chord.size())) * sidechain

		# 2. Rolling 16th Cyber-Bass (Alternating Octaves)
		var sixteenth_idx: int = int(current_beat * 4.0) % 4
		var bass_root: float = chord[0]
		var bass_f: float = (bass_root * 2.0) if (sixteenth_idx == 2 or sixteenth_idx == 3) else bass_root
		var bass_t: float = fmod(t, beat_dur * 0.25)
		var bass_saw: float = fmod(bass_t * bass_f, 1.0) * 2.0 - 1.0
		var bass_sub: float = sin(bass_t * bass_root * TAU)
		var bass_env: float = exp(-bass_t * 14.0)
		total_sample += (bass_saw * 0.35 + bass_sub * 0.45) * bass_env * 0.42

		# 3. Cascading 16th Neon Arpeggiator
		var arp_f: float = chord[sixteenth_idx % chord.size()] * 2.0
		var arp_t: float = fmod(t, beat_dur * 0.25)
		var arp_wave: float = sin(arp_t * arp_f * TAU) + 0.3 * sin(arp_t * arp_f * 2.0 * TAU)
		total_sample += arp_wave * exp(-arp_t * 16.0) * 0.20

		# 4. Soaring TRON Lead Synth
		var beat_idx: int = mini(int(current_beat), 31)
		var lead_f: float = lead_melody[beat_idx]
		var lead_t: float = fmod(t, beat_dur)
		var vibrato: float = sin(lead_t * 6.0 * TAU) * 3.5
		var lead_env: float = sin(clampf(lead_t / beat_dur, 0.0, 1.0) * PI)
		var lead_saw: float = fmod(lead_t * (lead_f + vibrato), 1.0) * 2.0 - 1.0
		var lead_sin: float = sin(lead_t * (lead_f + vibrato) * TAU)
		total_sample += (lead_saw * 0.3 + lead_sin * 0.7) * lead_env * 0.30

		# 5. Driving TRON Drum Machine (Punchy Sub Kick, Neon Snare on 2 & 4, 16th Hats)
		if beat_frac < 0.22:
			var kt: float = beat_frac * beat_dur
			var kf: float = lerpf(165.0, 42.0, clampf(kt / 0.07, 0.0, 1.0))
			total_sample += sin(kt * kf * TAU) * exp(-kt * 18.0) * 0.52

		var beat_num: int = int(current_beat) % 4
		if (beat_num == 1 or beat_num == 3) and beat_frac < 0.22:
			var st: float = beat_frac * beat_dur
			var snare: float = (randf_range(-1.0, 1.0) * 0.5 + sin(st * 220.0 * TAU) * 0.35) * exp(-st * 26.0)
			total_sample += snare * 0.38

		var sixteenth_f: float = fmod(current_beat * 4.0, 1.0)
		if sixteenth_f < 0.08:
			var ht: float = sixteenth_f * (beat_dur * 0.25)
			var hat_accent: float = 0.28 if (sixteenth_idx == 2) else 0.16
			total_sample += randf_range(-1.0, 1.0) * exp(-ht * 85.0) * hat_accent

		samples[i] = total_sample * 0.82

	return _create_wav_stream(samples, true)


# 2. BGM Menu: "Neon Outpost / End of Line Lounge" (32 beats - 114 BPM, ~16.84s loop)
# Smooth, addictive French-Touch / Cyber-Lounge with warm electric chords and groovy rolling bass.
func _synth_bgm_menu() -> AudioStreamWAV:
	var bpm: float = 114.0
	var beat_dur: float = 60.0 / bpm
	var total_beats: int = 32
	var duration: float = float(total_beats) * beat_dur
	var num_samples: int = int(duration * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(num_samples)

	# 8 bars: Am9 -> Fmaj9 -> Dm7 -> Em7 -> Am9 -> Fmaj7 -> Gsus4 -> E7#9
	var chords: Array = [
		[110.00, 220.00, 261.63, 329.63, 493.88], # Am9
		[87.31,  174.61, 261.63, 329.63, 392.00], # Fmaj9
		[146.83, 220.00, 261.63, 349.23, 440.00], # Dm7
		[82.41,  164.81, 246.94, 329.63, 392.00], # Em7
		[110.00, 220.00, 261.63, 329.63, 493.88], # Am9
		[87.31,  174.61, 220.00, 261.63, 329.63], # Fmaj7
		[98.00,  196.00, 261.63, 293.66, 392.00], # Gsus4
		[82.41,  164.81, 207.65, 311.13, 392.00]  # E7#9
	]
	var lead_melody: Array[float] = [
		440.00, 493.88, 523.25, 659.25,
		587.33, 523.25, 493.88, 440.00,
		587.33, 659.25, 698.46, 880.00,
		783.99, 659.25, 523.25, 493.88,
		523.25, 659.25, 880.00, 987.77,
		880.00, 698.46, 659.25, 587.33,
		659.25, 783.99, 880.00, 1046.50,
		987.77, 880.00, 659.25, 440.00
	]

	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var current_beat: float = t / beat_dur
		var bar_idx: int = mini(int(current_beat / 4.0), 7)
		var chord: Array = chords[bar_idx]
		var total_sample: float = 0.0

		var beat_frac: float = fmod(current_beat, 1.0)
		var sidechain: float = clampf(1.0 - 0.55 * exp(-beat_frac * 8.0), 0.3, 1.0)

		# 1. Warm Rhodes/Synth Chord Pad
		var pad_sample: float = 0.0
		for voice_idx in range(chord.size()):
			var f: float = chord[voice_idx]
			var voice: float = sin(t * f * TAU) + 0.3 * sin(t * f * 2.0 * TAU) + 0.15 * sin(t * f * 3.0 * TAU)
			pad_sample += voice
		total_sample += pad_sample * (0.28 / float(chord.size())) * sidechain

		# 2. Funky Bouncing Cyber-Bass
		var bass_t: float = fmod(t, beat_dur * 0.5)
		var bass_subbeat: int = int(current_beat * 2.0) % 8
		var bass_note: float = chord[0] * (2.0 if (bass_subbeat == 3 or bass_subbeat == 6) else 1.0)
		var bass: float = (sin(bass_t * bass_note * TAU) + 0.4 * (fmod(bass_t * bass_note, 1.0) * 2.0 - 1.0)) * exp(-bass_t * 9.0)
		total_sample += bass * 0.38

		# 3. Sparkling Crystal Arpeggio (8th-note Plucks)
		var arp_idx: int = int(current_beat * 2.0) % 4
		var arp_f: float = chord[arp_idx] * 2.0
		var arp_t: float = fmod(t, beat_dur * 0.5)
		var arp: float = (sin(arp_t * arp_f * TAU) + 0.3 * sin(arp_t * arp_f * 2.7 * TAU)) * exp(-arp_t * 11.0)
		total_sample += arp * 0.22

		# 4. Smooth Neon Flute/Lead
		var beat_idx: int = mini(int(current_beat), 31)
		var lead_f: float = lead_melody[beat_idx]
		var lead_t: float = fmod(t, beat_dur)
		var vibrato: float = sin(lead_t * 5.5 * TAU) * 3.0
		var lead_env: float = sin(clampf(lead_t / beat_dur, 0.0, 1.0) * PI)
		var flute: float = (sin(lead_t * (lead_f + vibrato) * TAU) + 0.25 * sin(lead_t * lead_f * 2.0 * TAU)) * lead_env
		total_sample += flute * 0.26

		# 5. Chill Lounge Drums
		if beat_frac < 0.20:
			var kt: float = beat_frac * beat_dur
			total_sample += sin(kt * lerpf(140.0, 40.0, kt / 0.09) * TAU) * exp(-kt * 16.0) * 0.44

		var beat_num: int = int(current_beat) % 4
		if (beat_num == 1 or beat_num == 3) and beat_frac < 0.18:
			var st: float = beat_frac * beat_dur
			total_sample += (randf_range(-1.0, 1.0) * 0.4 + sin(st * 240.0 * TAU) * 0.3) * exp(-st * 24.0) * 0.32

		var sixteenth_f: float = fmod(current_beat * 4.0, 1.0)
		if sixteenth_f < 0.06:
			var ht: float = sixteenth_f * (beat_dur * 0.25)
			total_sample += randf_range(-1.0, 1.0) * exp(-ht * 90.0) * 0.14

		samples[i] = total_sample * 0.82

	return _create_wav_stream(samples, true)


# 3. BGM Shop: "Cyber Matrix Bazaar" (32 beats - 118 BPM, ~16.27s loop)
# Funky, upbeat electro-disco Tron track with slap synth bass, staccato disco chords, and sparkling FM plucks.
func _synth_bgm_shop() -> AudioStreamWAV:
	var bpm: float = 118.0
	var beat_dur: float = 60.0 / bpm
	var total_beats: int = 32
	var duration: float = float(total_beats) * beat_dur
	var num_samples: int = int(duration * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(num_samples)

	# 8 bars: Cmaj9 -> Em7 -> Fmaj7 -> G7sus4 -> Am7 -> Dm7 -> G7 -> Cmaj7
	var chords: Array = [
		[130.81, 196.00, 246.94, 293.66, 329.63], # Cmaj9
		[82.41,  164.81, 246.94, 293.66, 329.63], # Em7
		[87.31,  174.61, 220.00, 261.63, 329.63], # Fmaj7
		[98.00,  196.00, 261.63, 293.66, 349.23], # G7sus4
		[110.00, 220.00, 261.63, 329.63, 392.00], # Am7
		[146.83, 220.00, 261.63, 349.23, 440.00], # Dm7
		[98.00,  196.00, 246.94, 293.66, 349.23], # G7
		[130.81, 196.00, 246.94, 261.63, 329.63]  # Cmaj7
	]
	var shop_melody: Array[float] = [
		523.25, 493.88, 392.00, 329.63,
		392.00, 440.00, 523.25, 659.25,
		493.88, 392.00, 329.63, 293.66,
		392.00, 440.00, 493.88, 523.25,
		440.00, 523.25, 659.25, 587.33,
		523.25, 440.00, 349.23, 392.00,
		440.00, 493.88, 587.33, 659.25,
		587.33, 523.25, 440.00, 523.25
	]

	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var current_beat: float = t / beat_dur
		var bar_idx: int = mini(int(current_beat / 4.0), 7)
		var chord: Array = chords[bar_idx]
		var total_sample: float = 0.0

		var beat_frac: float = fmod(current_beat, 1.0)
		var sidechain: float = clampf(1.0 - 0.60 * exp(-beat_frac * 9.0), 0.25, 1.0)

		# 1. Staccato Disco/Synth Chords (Off-beat stabs on .5)
		var subbeat_f: float = fmod(current_beat, 0.5)
		if int(current_beat * 2.0) % 2 == 1 and subbeat_f < 0.22:
			var stab_t: float = subbeat_f * (beat_dur * 0.5)
			var chord_stab: float = 0.0
			for voice_idx in range(1, chord.size()):
				var f: float = chord[voice_idx]
				chord_stab += (fmod(stab_t * f, 1.0) * 2.0 - 1.0) * 0.35 + sin(stab_t * f * TAU) * 0.65
			total_sample += chord_stab * (0.28 / float(chord.size() - 1)) * exp(-stab_t * 12.0)

		# 2. Slap-Synth Cyber Bass
		var bass_t: float = fmod(t, beat_dur * 0.5)
		var bass_f: float = chord[0]
		var slap: float = (sin(bass_t * bass_f * TAU) + 0.5 * (fmod(bass_t * bass_f * 2.0, 1.0) * 2.0 - 1.0)) * exp(-bass_t * 11.0)
		total_sample += slap * 0.36

		# 3. Shimmering FM Crystal Plucks (16th notes)
		var sixteenth: int = int(current_beat * 4.0) % 4
		var pluck_f: float = chord[sixteenth % chord.size()] * 2.0
		var pluck_t: float = fmod(t, beat_dur * 0.25)
		var fm_bell: float = sin(pluck_t * pluck_f * TAU + sin(pluck_t * pluck_f * 2.0 * TAU) * 1.5) * exp(-pluck_t * 14.0)
		total_sample += fm_bell * 0.22 * sidechain

		# 4. Catchy Vocaloid/Synth Lead
		var beat_idx: int = mini(int(current_beat), 31)
		var lead_f: float = shop_melody[beat_idx]
		var lead_t: float = fmod(t, beat_dur)
		var lead_wave: float = sin(lead_t * lead_f * TAU) + 0.3 * (1.0 if fmod(lead_t * lead_f, 1.0) < 0.5 else -1.0)
		total_sample += lead_wave * exp(-lead_t * 4.0) * 0.26

		# 5. Upbeat Drums
		if beat_frac < 0.20:
			var kt: float = beat_frac * beat_dur
			total_sample += sin(kt * lerpf(160.0, 45.0, kt / 0.08) * TAU) * exp(-kt * 18.0) * 0.48

		var beat_num: int = int(current_beat) % 4
		if (beat_num == 1 or beat_num == 3) and beat_frac < 0.20:
			var st: float = beat_frac * beat_dur
			total_sample += (randf_range(-1.0, 1.0) * 0.6 + sin(st * 230.0 * TAU) * 0.35) * exp(-st * 25.0) * 0.36

		samples[i] = total_sample * 0.82

	return _create_wav_stream(samples, true)


# 4. BGM Map: "Sector Grid / Tactical Navigation" (32 beats - 122 BPM, ~15.74s loop)
# Atmospheric, driving synthwave with pulsing bass, clockwork laser ticks, and tension-building arpeggios.
func _synth_bgm_map() -> AudioStreamWAV:
	var bpm: float = 122.0
	var beat_dur: float = 60.0 / bpm
	var total_beats: int = 32
	var duration: float = float(total_beats) * beat_dur
	var num_samples: int = int(duration * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(num_samples)

	# 8 bars: Em9 -> Cmaj7 -> G/B -> Dadd9 -> Em9 -> Am7 -> Cmaj7 -> Bm7
	var chords: Array = [
		[82.41,  164.81, 246.94, 293.66, 329.63], # Em9
		[130.81, 196.00, 246.94, 261.63, 329.63], # Cmaj7
		[123.47, 196.00, 246.94, 293.66, 392.00], # G/B
		[146.83, 220.00, 261.63, 293.66, 369.99], # Dadd9
		[82.41,  164.81, 246.94, 293.66, 329.63], # Em9
		[110.00, 220.00, 261.63, 329.63, 440.00], # Am7
		[130.81, 196.00, 246.94, 261.63, 329.63], # Cmaj7
		[123.47, 185.00, 246.94, 293.66, 369.99]  # Bm7
	]
	var map_melody: Array[float] = [
		329.63, 392.00, 493.88, 587.33,
		523.25, 493.88, 392.00, 329.63,
		392.00, 493.88, 587.33, 739.99,
		587.33, 493.88, 440.00, 369.99,
		493.88, 587.33, 659.25, 880.00,
		698.46, 659.25, 523.25, 440.00,
		523.25, 659.25, 783.99, 987.77,
		739.99, 587.33, 493.88, 329.63
	]

	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var current_beat: float = t / beat_dur
		var bar_idx: int = mini(int(current_beat / 4.0), 7)
		var chord: Array = chords[bar_idx]
		var total_sample: float = 0.0

		var beat_frac: float = fmod(current_beat, 1.0)
		var sidechain: float = clampf(1.0 - 0.50 * exp(-beat_frac * 8.0), 0.35, 1.0)

		# 1. Pulsing 8th-note Cyber Bass
		var bass_t: float = fmod(t, beat_dur * 0.5)
		var bass_f: float = chord[0]
		var bass_saw: float = fmod(bass_t * bass_f, 1.0) * 2.0 - 1.0
		var bass_sub: float = sin(bass_t * bass_f * TAU)
		total_sample += (bass_saw * 0.3 + bass_sub * 0.6) * exp(-bass_t * 8.0) * 0.40

		# 2. Tension Arpeggios (16th notes)
		var sixteenth: int = int(current_beat * 4.0) % 4
		var arp_f: float = chord[sixteenth % chord.size()] * 2.0
		var arp_t: float = fmod(t, beat_dur * 0.25)
		var arp: float = sin(arp_t * arp_f * TAU) * exp(-arp_t * 14.0)
		total_sample += arp * 0.22 * sidechain

		# 3. Ethereal Neon Lead
		var beat_idx: int = mini(int(current_beat), 31)
		var lead_f: float = map_melody[beat_idx]
		var lead_t: float = fmod(t, beat_dur)
		var vibrato: float = sin(lead_t * 5.0 * TAU) * 2.5
		var lead_env: float = sin(clampf(lead_t / beat_dur, 0.0, 1.0) * PI)
		var lead: float = (sin(lead_t * (lead_f + vibrato) * TAU) + 0.3 * sin(lead_t * lead_f * 2.0 * TAU)) * lead_env
		total_sample += lead * 0.28

		# 4. Tactical Percussion (Sub kick on 1 & 3, clockwork laser ticks)
		var beat_num: int = int(current_beat) % 4
		if (beat_num == 0 or beat_num == 2) and beat_frac < 0.20:
			var kt: float = beat_frac * beat_dur
			total_sample += sin(kt * lerpf(150.0, 42.0, kt / 0.08) * TAU) * exp(-kt * 18.0) * 0.44

		if beat_num == 3 and beat_frac < 0.18:
			var st: float = beat_frac * beat_dur
			total_sample += randf_range(-1.0, 1.0) * exp(-st * 30.0) * 0.24

		var sixteenth_f: float = fmod(current_beat * 4.0, 1.0)
		if sixteenth_f < 0.05:
			var tt: float = sixteenth_f * (beat_dur * 0.25)
			total_sample += sin(tt * 2800.0 * TAU) * exp(-tt * 120.0) * 0.18

		samples[i] = total_sample * 0.82

	return _create_wav_stream(samples, true)


# 5. BGM Addition: "Radiant Lightcycle / Solar Grid" (32 beats - 134 BPM, ~14.33s loop)
# Euphoric, uplifting driving synthwave with 4-on-the-floor kick, rolling octave bass, and singing supersaw leads.
func _synth_bgm_addition() -> AudioStreamWAV:
	var bpm: float = 134.0
	var beat_dur: float = 60.0 / bpm
	var total_beats: int = 32
	var duration: float = float(total_beats) * beat_dur
	var num_samples: int = int(duration * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(num_samples)

	# 8 bars: Cadd9 -> G/B -> Am7 -> Fmaj7 -> C/E -> Gsus4 -> Fmaj7 -> C
	var chords: Array = [
		[130.81, 196.00, 261.63, 293.66, 329.63], # Cadd9
		[123.47, 196.00, 246.94, 293.66, 392.00], # G/B
		[110.00, 220.00, 261.63, 329.63, 440.00], # Am7
		[87.31,  174.61, 220.00, 261.63, 329.63], # Fmaj7
		[82.41,  164.81, 261.63, 329.63, 392.00], # C/E
		[98.00,  196.00, 261.63, 293.66, 392.00], # Gsus4
		[87.31,  174.61, 220.00, 261.63, 329.63], # Fmaj7
		[130.81, 196.00, 261.63, 329.63, 523.25]  # C
	]
	var lead_melody: Array[float] = [
		523.25, 659.25, 783.99, 1046.50,
		783.99, 659.25, 587.33, 493.88,
		440.00, 523.25, 659.25, 880.00,
		698.46, 783.99, 880.00, 1046.50,
		1046.50, 783.99, 659.25, 523.25,
		587.33, 659.25, 783.99, 880.00,
		698.46, 587.33, 523.25, 440.00,
		523.25, 659.25, 783.99, 1046.50
	]

	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var current_beat: float = t / beat_dur
		var bar_idx: int = mini(int(current_beat / 4.0), 7)
		var chord: Array = chords[bar_idx]
		var total_sample: float = 0.0

		var beat_frac: float = fmod(current_beat, 1.0)
		var sidechain: float = clampf(1.0 - 0.65 * exp(-beat_frac * 10.0), 0.2, 1.0)

		# 1. Pumping Supersaw Chords
		var pad_sample: float = 0.0
		for voice_idx in range(1, chord.size()):
			var f: float = chord[voice_idx]
			var saw_a: float = fmod(t * f * 0.996, 1.0) * 2.0 - 1.0
			var saw_b: float = fmod(t * f * 1.004, 1.0) * 2.0 - 1.0
			pad_sample += (saw_a + saw_b) * 0.5
		total_sample += pad_sample * (0.28 / float(chord.size() - 1)) * sidechain

		# 2. Galloping 16th Bassline
		var sixteenth: int = int(current_beat * 4.0) % 4
		var bass_f: float = (chord[0] * 2.0) if (sixteenth == 1 or sixteenth == 2) else chord[0]
		var bass_t: float = fmod(t, beat_dur * 0.25)
		var bass: float = (fmod(bass_t * bass_f, 1.0) * 2.0 - 1.0) * 0.4 + sin(bass_t * chord[0] * TAU) * 0.6
		total_sample += bass * exp(-bass_t * 14.0) * 0.40

		# 3. 16th Cascading Lightcycle Arp
		var arp_f: float = chord[sixteenth % chord.size()] * 2.0
		var arp_t: float = fmod(t, beat_dur * 0.25)
		var arp: float = sin(arp_t * arp_f * TAU) + 0.35 * sin(arp_t * arp_f * 2.0 * TAU)
		total_sample += arp * exp(-arp_t * 16.0) * 0.22

		# 4. Triumphant Supersaw Lead
		var beat_idx: int = mini(int(current_beat), 31)
		var lead_f: float = lead_melody[beat_idx]
		var lead_t: float = fmod(t, beat_dur)
		var lead_env: float = sin(clampf(lead_t / beat_dur, 0.0, 1.0) * PI)
		var lead_saw: float = fmod(lead_t * lead_f, 1.0) * 2.0 - 1.0
		var lead_sin: float = sin(lead_t * lead_f * TAU)
		total_sample += (lead_saw * 0.35 + lead_sin * 0.65) * lead_env * 0.32

		# 5. Driving 4-on-the-Floor Drums
		if beat_frac < 0.22:
			var kt: float = beat_frac * beat_dur
			total_sample += sin(kt * lerpf(165.0, 42.0, kt / 0.07) * TAU) * exp(-kt * 18.0) * 0.52

		var beat_num: int = int(current_beat) % 4
		if (beat_num == 1 or beat_num == 3) and beat_frac < 0.22:
			var st: float = beat_frac * beat_dur
			total_sample += (randf_range(-1.0, 1.0) * 0.6 + sin(st * 220.0 * TAU) * 0.35) * exp(-st * 26.0) * 0.38

		var sixteenth_f: float = fmod(current_beat * 4.0, 1.0)
		if sixteenth_f < 0.08:
			var ht: float = sixteenth_f * (beat_dur * 0.25)
			var hat_accent: float = 0.28 if (sixteenth == 2) else 0.16
			total_sample += randf_range(-1.0, 1.0) * exp(-ht * 85.0) * hat_accent

		samples[i] = total_sample * 0.82

	return _create_wav_stream(samples, true)


# 6. BGM Subtraction: "Shadow Protocol / Cyber Blade" (32 beats - 130 BPM, ~14.77s loop)
# Dark aggressive cyberpunk electro battle music in D minor with biting saw bass and razor-sharp stabs.
func _synth_bgm_subtraction() -> AudioStreamWAV:
	var bpm: float = 130.0
	var beat_dur: float = 60.0 / bpm
	var total_beats: int = 32
	var duration: float = float(total_beats) * beat_dur
	var num_samples: int = int(duration * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(num_samples)

	# 8 bars: Dm -> Bb -> Gm7 -> A7 -> Dm -> F -> C -> A7sus4
	var chords: Array = [
		[146.83, 220.00, 293.66, 349.23], # Dm
		[116.54, 233.08, 293.66, 349.23], # Bb
		[98.00,  196.00, 233.08, 293.66], # Gm7
		[110.00, 220.00, 277.18, 329.63], # A7
		[146.83, 220.00, 293.66, 349.23], # Dm
		[174.61, 261.63, 349.23, 440.00], # F
		[130.81, 196.00, 261.63, 329.63], # C
		[110.00, 220.00, 293.66, 329.63]  # A7sus4
	]
	var lead_melody: Array[float] = [
		587.33, 523.25, 440.00, 493.88,
		466.16, 523.25, 587.33, 698.46,
		392.00, 466.16, 587.33, 523.25,
		440.00, 554.37, 659.25, 440.00,
		587.33, 698.46, 880.00, 698.46,
		698.46, 783.99, 880.00, 1046.50,
		783.99, 659.25, 587.33, 523.25,
		554.37, 440.00, 493.88, 587.33
	]

	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var current_beat: float = t / beat_dur
		var bar_idx: int = mini(int(current_beat / 4.0), 7)
		var chord: Array = chords[bar_idx]
		var total_sample: float = 0.0

		var beat_frac: float = fmod(current_beat, 1.0)
		var sidechain: float = clampf(1.0 - 0.65 * exp(-beat_frac * 10.0), 0.2, 1.0)

		# 1. Dark Detuned Saw Bass
		var bass_t: float = fmod(t, beat_dur * 0.5)
		var bass_f: float = chord[0]
		var saw_a: float = fmod(bass_t * bass_f * 0.993, 1.0) * 2.0 - 1.0
		var saw_b: float = fmod(bass_t * bass_f * 1.007, 1.0) * 2.0 - 1.0
		var bass_sub: float = sin(bass_t * bass_f * TAU)
		total_sample += ((saw_a + saw_b) * 0.35 + bass_sub * 0.5) * exp(-bass_t * 8.0) * 0.42

		# 2. Razor Sharp Stabs on off-beats
		var subbeat: int = int(current_beat * 2.0) % 2
		if subbeat == 1 and fmod(current_beat, 0.5) < 0.18:
			var stab_t: float = fmod(current_beat, 0.5) * (beat_dur * 0.5)
			var chord_sample: float = 0.0
			for voice_idx in range(chord.size()):
				var f: float = chord[voice_idx]
				chord_sample += (fmod(stab_t * f, 1.0) * 2.0 - 1.0)
			total_sample += chord_sample * (0.30 / float(chord.size())) * exp(-stab_t * 14.0)

		# 3. Cyber Blade Saw Lead
		var beat_idx: int = mini(int(current_beat), 31)
		var lead_f: float = lead_melody[beat_idx]
		var lead_t: float = fmod(t, beat_dur)
		var saw_lead: float = fmod(lead_t * lead_f, 1.0) * 2.0 - 1.0
		var sin_lead: float = sin(lead_t * lead_f * TAU)
		total_sample += (saw_lead * 0.45 + sin_lead * 0.55) * sin(clampf(lead_t / beat_dur, 0.0, 1.0) * PI) * 0.32

		# 4. Punchy Industrial Drums
		if beat_frac < 0.22:
			var kt: float = beat_frac * beat_dur
			total_sample += sin(kt * lerpf(170.0, 40.0, kt / 0.07) * TAU) * exp(-kt * 19.0) * 0.52

		var beat_num: int = int(current_beat) % 4
		if (beat_num == 1 or beat_num == 3) and beat_frac < 0.22:
			var st: float = beat_frac * beat_dur
			total_sample += (randf_range(-1.0, 1.0) * 0.65 + sin(st * 240.0 * TAU) * 0.3) * exp(-st * 27.0) * 0.40

		var sixteenth_f: float = fmod(current_beat * 4.0, 1.0)
		if sixteenth_f < 0.07:
			var ht: float = sixteenth_f * (beat_dur * 0.25)
			total_sample += randf_range(-1.0, 1.0) * exp(-ht * 90.0) * 0.20

		samples[i] = total_sample * 0.82

	return _create_wav_stream(samples, true)


# 7. BGM Multiplication: "Hyperdrive Accelerator" (32 beats - 142 BPM, ~13.52s loop)
# Fast kinetic Outrun synth-rush in E minor with galloping 16th bassline and soaring dual leads.
func _synth_bgm_multiplication() -> AudioStreamWAV:
	var bpm: float = 142.0
	var beat_dur: float = 60.0 / bpm
	var total_beats: int = 32
	var duration: float = float(total_beats) * beat_dur
	var num_samples: int = int(duration * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(num_samples)

	# 8 bars: Em -> Cmaj7 -> G -> D -> Em -> Am7 -> D -> B7
	var chords: Array = [
		[82.41,  164.81, 196.00, 246.94, 329.63], # Em
		[130.81, 164.81, 196.00, 246.94, 261.63], # Cmaj7
		[98.00,  196.00, 246.94, 293.66, 392.00], # G
		[146.83, 220.00, 293.66, 369.99, 440.00], # D
		[82.41,  164.81, 196.00, 246.94, 329.63], # Em
		[110.00, 220.00, 261.63, 329.63, 440.00], # Am7
		[146.83, 220.00, 293.66, 369.99, 440.00], # D
		[123.47, 155.56, 185.00, 246.94, 369.99]  # B7
	]
	var lead_melody: Array[float] = [
		659.25, 783.99, 987.77, 1318.51,
		523.25, 659.25, 783.99, 1046.50,
		783.99, 987.77, 1174.66, 1567.98,
		587.33, 739.99, 880.00, 1174.66,
		659.25, 880.00, 987.77, 1318.51,
		880.00, 1046.50, 1318.51, 1046.50,
		1174.66, 987.77, 880.00, 739.99,
		659.25, 783.99, 880.00, 987.77
	]

	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var current_beat: float = t / beat_dur
		var bar_idx: int = mini(int(current_beat / 4.0), 7)
		var chord: Array = chords[bar_idx]
		var total_sample: float = 0.0

		var beat_frac: float = fmod(current_beat, 1.0)
		var sidechain: float = clampf(1.0 - 0.65 * exp(-beat_frac * 11.0), 0.2, 1.0)

		# 1. 16th-note Galloping Outrun Bass
		var sixteenth: int = int(current_beat * 4.0) % 4
		var bass_f: float = (chord[0] * 2.0) if (sixteenth == 1 or sixteenth == 2) else chord[0]
		var bass_t: float = fmod(t, beat_dur * 0.25)
		var bass: float = (fmod(bass_t * bass_f, 1.0) * 2.0 - 1.0) * 0.4 + sin(bass_t * chord[0] * TAU) * 0.6
		total_sample += bass * exp(-bass_t * 15.0) * 0.42

		# 2. Pumping Pad Chords
		var pad_sample: float = 0.0
		for voice_idx in range(1, chord.size()):
			var f: float = chord[voice_idx]
			pad_sample += (fmod(t * f, 1.0) * 2.0 - 1.0)
		total_sample += pad_sample * (0.24 / float(chord.size() - 1)) * sidechain

		# 3. Soaring Hyperdrive Dual Lead
		var beat_idx: int = mini(int(current_beat), 31)
		var lead_f: float = lead_melody[beat_idx]
		var lead_t: float = fmod(t, beat_dur)
		var saw_lead_1: float = fmod(lead_t * lead_f, 1.0) * 2.0 - 1.0
		var saw_lead_2: float = fmod(lead_t * (lead_f * 1.5), 1.0) * 2.0 - 1.0 # 5th harmony
		var sin_lead: float = sin(lead_t * lead_f * TAU)
		total_sample += (saw_lead_1 * 0.4 + saw_lead_2 * 0.2 + sin_lead * 0.4) * exp(-lead_t * 3.5) * 0.32

		# 4. Double-Kick Driving Drums
		var double_kick_f: float = fmod(current_beat, 0.5)
		if double_kick_f < 0.18:
			var kt: float = double_kick_f * (beat_dur * 0.5)
			total_sample += sin(kt * lerpf(165.0, 42.0, kt / 0.07) * TAU) * exp(-kt * 20.0) * 0.48

		var beat_num: int = int(current_beat) % 4
		if (beat_num == 1 or beat_num == 3) and beat_frac < 0.20:
			var st: float = beat_frac * beat_dur
			total_sample += (randf_range(-1.0, 1.0) * 0.65 + sin(st * 230.0 * TAU) * 0.35) * exp(-st * 26.0) * 0.38

		samples[i] = total_sample * 0.82

	return _create_wav_stream(samples, true)


# 8. BGM Division: "Quantum Logic / Laser Matrix" (32 beats - 128 BPM, ~15.0s loop)
# Hypnotic precision synthwave with crystal FM chimes, intricate polyrhythmic arps, and clean sub-bass.
func _synth_bgm_division() -> AudioStreamWAV:
	var bpm: float = 128.0
	var beat_dur: float = 60.0 / bpm
	var total_beats: int = 32
	var duration: float = float(total_beats) * beat_dur
	var num_samples: int = int(duration * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(num_samples)

	# 8 bars: Bm9 -> Gmaj7 -> Dmaj7 -> F#m7 -> Em9 -> Bm7 -> Gmaj7 -> F#7
	var chords: Array = [
		[123.47, 185.00, 246.94, 293.66, 369.99], # Bm9
		[98.00,  196.00, 246.94, 293.66, 392.00], # Gmaj7
		[146.83, 220.00, 293.66, 369.99, 440.00], # Dmaj7
		[92.50,  185.00, 220.00, 277.18, 369.99], # F#m7
		[82.41,  164.81, 246.94, 293.66, 329.63], # Em9
		[123.47, 185.00, 246.94, 293.66, 369.99], # Bm7
		[98.00,  196.00, 246.94, 293.66, 392.00], # Gmaj7
		[92.50,  185.00, 233.08, 277.18, 369.99]  # F#7
	]

	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var current_beat: float = t / beat_dur
		var bar_idx: int = mini(int(current_beat / 4.0), 7)
		var chord: Array = chords[bar_idx]
		var total_sample: float = 0.0

		var beat_frac: float = fmod(current_beat, 1.0)
		var sidechain: float = clampf(1.0 - 0.55 * exp(-beat_frac * 9.0), 0.25, 1.0)

		# 1. FM Crystal Glass Chimes (Polyrhythm: 3 notes per 2 beats)
		var poly_idx: int = int(current_beat * 1.5) % chord.size()
		var chime_f: float = chord[poly_idx] * 2.0
		var chime_t: float = fmod(t, beat_dur / 1.5)
		var fm_mod: float = sin(chime_t * chime_f * 2.76 * TAU) * 2.0
		var crystal: float = sin(chime_t * (chime_f + fm_mod) * TAU) * exp(-chime_t * 6.5)
		total_sample += crystal * 0.30 * sidechain

		# 2. Precision Laser Arpeggio (16th notes)
		var sixteenth: int = int(current_beat * 4.0) % 4
		var arp_f: float = chord[sixteenth % chord.size()] * 2.0
		var arp_t: float = fmod(t, beat_dur * 0.25)
		var arp: float = sin(arp_t * arp_f * TAU) * exp(-arp_t * 18.0)
		total_sample += arp * 0.22

		# 3. Deep Clean Resonant Sub-Bass
		var bass_t: float = fmod(t, beat_dur)
		var bass_f: float = chord[0]
		var sub_bass: float = sin(bass_t * bass_f * TAU) * exp(-bass_t * 4.5)
		total_sample += sub_bass * 0.42

		# 4. Precision Cyber Percussion
		if beat_frac < 0.20:
			var kt: float = beat_frac * beat_dur
			total_sample += sin(kt * lerpf(160.0, 40.0, kt / 0.08) * TAU) * exp(-kt * 18.0) * 0.45

		var beat_num: int = int(current_beat) % 4
		if (beat_num == 1 or beat_num == 3) and beat_frac < 0.18:
			var st: float = beat_frac * beat_dur
			total_sample += randf_range(-1.0, 1.0) * exp(-st * 28.0) * 0.30

		samples[i] = total_sample * 0.82

	return _create_wav_stream(samples, true)


# 9. BGM Mixed / Battle: "Tron Symphonic Duel" (32 beats - 136 BPM, ~14.12s loop)
# Master multi-layered cyber anthem combining sweeping harmonic progressions, rolling bass, and soaring leads.
func _synth_bgm_mixed() -> AudioStreamWAV:
	var bpm: float = 136.0
	var beat_dur: float = 60.0 / bpm
	var total_beats: int = 32
	var duration: float = float(total_beats) * beat_dur
	var num_samples: int = int(duration * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(num_samples)

	# 8 bars: Am9 -> Fmaj7 -> Dm7 -> G -> Cmaj7 -> Fmaj7 -> Bm7b5 -> E7
	var chords: Array = [
		[110.00, 220.00, 261.63, 329.63, 493.88], # Am9
		[87.31,  174.61, 220.00, 261.63, 329.63], # Fmaj7
		[146.83, 220.00, 261.63, 349.23, 440.00], # Dm7
		[98.00,  196.00, 246.94, 293.66, 392.00], # G
		[130.81, 196.00, 246.94, 261.63, 329.63], # Cmaj7
		[87.31,  174.61, 220.00, 261.63, 349.23], # Fmaj7
		[123.47, 174.61, 220.00, 293.66, 369.99], # Bm7b5
		[82.41,  164.81, 207.65, 246.94, 329.63]  # E7
	]
	var lead_melody: Array[float] = [
		440.0, 523.25, 659.25, 880.0,
		698.46, 880.0, 1046.50, 880.0,
		587.33, 698.46, 880.0, 698.46,
		659.25, 830.61, 987.77, 659.25,
		880.0, 1046.50, 1318.51, 1046.50,
		1046.50, 783.99, 659.25, 783.99,
		783.99, 659.25, 587.33, 493.88,
		659.25, 830.61, 987.77, 880.00
	]

	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var current_beat: float = t / beat_dur
		var bar_idx: int = mini(int(current_beat / 4.0), 7)
		var chord: Array = chords[bar_idx]
		var total_sample: float = 0.0

		var beat_frac: float = fmod(current_beat, 1.0)
		var sidechain: float = clampf(1.0 - 0.65 * exp(-beat_frac * 10.0), 0.2, 1.0)

		# 1. Pumping Supersaw Chords
		var pad_sample: float = 0.0
		for voice_idx in range(1, chord.size()):
			var f: float = chord[voice_idx]
			var saw_a: float = fmod(t * f * 0.995, 1.0) * 2.0 - 1.0
			var saw_b: float = fmod(t * f * 1.005, 1.0) * 2.0 - 1.0
			pad_sample += (saw_a + saw_b) * 0.5
		total_sample += pad_sample * (0.28 / float(chord.size() - 1)) * sidechain

		# 2. Rolling 16th Bassline
		var sixteenth: int = int(current_beat * 4.0) % 4
		var bass_f: float = (chord[0] * 2.0) if (sixteenth == 2 or sixteenth == 3) else chord[0]
		var bass_t: float = fmod(t, beat_dur * 0.25)
		var bass: float = (fmod(bass_t * bass_f, 1.0) * 2.0 - 1.0) * 0.35 + sin(bass_t * chord[0] * TAU) * 0.65
		total_sample += bass * exp(-bass_t * 14.0) * 0.40

		# 3. 16th Cascading Arpeggiator
		var arp_f: float = chord[sixteenth % chord.size()] * 2.0
		var arp_t: float = fmod(t, beat_dur * 0.25)
		var arp: float = sin(arp_t * arp_f * TAU) + 0.3 * sin(arp_t * arp_f * 2.0 * TAU)
		total_sample += arp * exp(-arp_t * 16.0) * 0.22

		# 4. Heroic Symphonic Lead
		var beat_idx: int = mini(int(current_beat), 31)
		var lead_f: float = lead_melody[beat_idx]
		var lead_t: float = fmod(t, beat_dur)
		var lead_saw: float = fmod(lead_t * lead_f, 1.0) * 2.0 - 1.0
		var lead_sin: float = sin(lead_t * lead_f * TAU)
		total_sample += (lead_saw * 0.35 + lead_sin * 0.65) * sin(clampf(lead_t / beat_dur, 0.0, 1.0) * PI) * 0.32

		# 5. Punchy 4-on-the-Floor TRON Beat
		if beat_frac < 0.22:
			var kt: float = beat_frac * beat_dur
			total_sample += sin(kt * lerpf(165.0, 42.0, kt / 0.07) * TAU) * exp(-kt * 18.0) * 0.52

		var beat_num: int = int(current_beat) % 4
		if (beat_num == 1 or beat_num == 3) and beat_frac < 0.22:
			var st: float = beat_frac * beat_dur
			total_sample += (randf_range(-1.0, 1.0) * 0.6 + sin(st * 220.0 * TAU) * 0.35) * exp(-st * 26.0) * 0.38

		var sixteenth_f: float = fmod(current_beat * 4.0, 1.0)
		if sixteenth_f < 0.08:
			var ht: float = sixteenth_f * (beat_dur * 0.25)
			var hat_accent: float = 0.28 if (sixteenth == 2) else 0.16
			total_sample += randf_range(-1.0, 1.0) * exp(-ht * 85.0) * hat_accent

		samples[i] = total_sample * 0.82

	return _create_wav_stream(samples, true)


func _synth_bgm_battle() -> AudioStreamWAV:
	return _synth_bgm_mixed()


# 10. BGM Forge: "Neon Cyber-Foundry" (32 beats - 128 BPM, ~15.0s loop)
# Industrial electro with resonant metallic anvil clangs, grinding saw bass, and heavy steam kicks.
func _synth_bgm_forge() -> AudioStreamWAV:
	var bpm: float = 128.0
	var beat_dur: float = 60.0 / bpm
	var total_beats: int = 32
	var duration: float = float(total_beats) * beat_dur
	var num_samples: int = int(duration * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(num_samples)

	# 8 bars: Em -> D/F# -> G -> A -> C -> B7 -> Em -> B7
	var chords: Array = [
		[82.41,  164.81, 196.00, 246.94],
		[92.50,  146.83, 185.00, 220.00],
		[98.00,  196.00, 246.94, 293.66],
		[110.00, 220.00, 277.18, 329.63],
		[130.81, 164.81, 196.00, 261.63],
		[123.47, 155.56, 185.00, 246.94],
		[82.41,  164.81, 196.00, 246.94],
		[123.47, 155.56, 185.00, 246.94]
	]

	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var current_beat: float = t / beat_dur
		var bar_idx: int = mini(int(current_beat / 4.0), 7)
		var chord: Array = chords[bar_idx]
		var total_sample: float = 0.0

		var beat_int: int = int(current_beat) % 4
		var beat_frac: float = fmod(current_beat, 1.0)

		# 1. Metallic Anvil Synth Clang on beats 2 & 4
		if (beat_int == 1 or beat_int == 3) and beat_frac < 0.24:
			var at: float = beat_frac * beat_dur
			var clang: float = (sin(at * 1250.0 * TAU) + 0.5 * sin(at * 2840.0 * TAU) + 0.3 * sin(at * 3920.0 * TAU)) * exp(-at * 16.0)
			total_sample += clang * 0.44

		# 2. Grinding Saw Bass
		var bass_t: float = fmod(t, beat_dur * 0.5)
		var bass_f: float = chord[0]
		var saw: float = fmod(bass_t * bass_f, 1.0) * 2.0 - 1.0
		total_sample += saw * exp(-bass_t * 9.0) * 0.36

		# 3. Heavy Steam Kick on 1 & 3
		if (beat_int == 0 or beat_int == 2) and beat_frac < 0.24:
			var kt: float = beat_frac * beat_dur
			total_sample += sin(kt * lerpf(160.0, 36.0, kt / 0.12) * TAU) * exp(-kt * 16.0) * 0.54

		samples[i] = total_sample * 0.82

	return _create_wav_stream(samples, true)


# 11. BGM Chain: "Infinite Combo Stream" (32 beats - 140 BPM, ~13.71s loop)
# Relentless Outrun / Eurobeat cyber track with pumping bass, euphoric chord stabs, and cascading 16th arp fireworks.
func _synth_bgm_chain() -> AudioStreamWAV:
	var bpm: float = 140.0
	var beat_dur: float = 60.0 / bpm
	var total_beats: int = 32
	var duration: float = float(total_beats) * beat_dur
	var num_samples: int = int(duration * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(num_samples)

	# 8 bars: Fmaj7 -> G -> Am7 -> C -> Fmaj7 -> G -> Em7 -> Am
	var chords: Array = [
		[87.31,  174.61, 220.00, 261.63, 349.23],
		[98.00,  196.00, 246.94, 293.66, 392.00],
		[110.00, 220.00, 261.63, 329.63, 440.00],
		[130.81, 196.00, 261.63, 329.63, 523.25],
		[87.31,  174.61, 220.00, 261.63, 349.23],
		[98.00,  196.00, 246.94, 293.66, 392.00],
		[82.41,  164.81, 196.00, 246.94, 329.63],
		[110.00, 220.00, 261.63, 329.63, 440.00]
	]

	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var current_beat: float = t / beat_dur
		var bar_idx: int = mini(int(current_beat / 4.0), 7)
		var chord: Array = chords[bar_idx]
		var total_sample: float = 0.0

		var beat_frac: float = fmod(current_beat, 1.0)
		var sidechain: float = clampf(1.0 - 0.65 * exp(-beat_frac * 10.0), 0.2, 1.0)

		# 1. Cascading 16th Arpeggiator Sweep
		var sixteenth: int = int(current_beat * 4.0) % 4
		var arp_f: float = chord[sixteenth % chord.size()] * 2.0
		var arp_t: float = fmod(t, beat_dur * 0.25)
		var arp: float = (fmod(arp_t * arp_f, 1.0) * 2.0 - 1.0) * 0.4 + sin(arp_t * arp_f * TAU) * 0.6
		total_sample += arp * exp(-arp_t * 16.0) * 0.30

		# 2. Four-on-the-Floor Kick Drum
		if beat_frac < 0.20:
			var kt: float = beat_frac * beat_dur
			total_sample += sin(kt * lerpf(165.0, 45.0, kt / 0.07) * TAU) * exp(-kt * 20.0) * 0.52

		# 3. Euphoric Chord Stabs
		var stab_t: float = fmod(t, beat_dur)
		var stab: float = (sin(stab_t * chord[1] * TAU) + sin(stab_t * chord[2] * TAU) + sin(stab_t * chord[3] * TAU)) * exp(-stab_t * 7.0)
		total_sample += stab * 0.26 * sidechain

		samples[i] = total_sample * 0.82

	return _create_wav_stream(samples, true)


# 12. BGM Elite: "Derezzer Protocol" (32 beats - 144 BPM, ~13.33s loop)
# Fast, dark electro encounter in G minor with razor-sharp saw stabs and intense rhythm.
func _synth_bgm_elite() -> AudioStreamWAV:
	var bpm: float = 144.0
	var beat_dur: float = 60.0 / bpm
	var total_beats: int = 32
	var duration: float = float(total_beats) * beat_dur
	var num_samples: int = int(duration * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(num_samples)

	# 8 bars: Gm -> Eb -> F -> D7 -> Gm -> Cm -> D7 -> G5
	var chords: Array = [
		[98.00,  196.00, 233.08, 293.66],
		[77.78,  155.56, 196.00, 233.08],
		[87.31,  174.61, 220.00, 261.63],
		[73.42,  146.83, 185.00, 220.00],
		[98.00,  196.00, 233.08, 293.66],
		[65.41,  130.81, 155.56, 196.00],
		[73.42,  146.83, 185.00, 220.00],
		[98.00,  196.00, 293.66, 392.00]
	]

	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var current_beat: float = t / beat_dur
		var bar_idx: int = mini(int(current_beat / 4.0), 7)
		var chord: Array = chords[bar_idx]
		var total_sample: float = 0.0

		# 1. Fast Saw Stabs
		var stab_t: float = fmod(t, beat_dur * 0.5)
		var saw_f: float = chord[1]
		var saw: float = fmod(stab_t * saw_f, 1.0) * 2.0 - 1.0
		total_sample += saw * exp(-stab_t * 12.0) * 0.38

		# 2. Driving Fast Kick
		var beat_f: float = fmod(current_beat, 0.5)
		if beat_f < 0.16:
			var kt: float = beat_f * (beat_dur * 0.5)
			total_sample += sin(kt * lerpf(165.0, 42.0, kt / 0.07) * TAU) * exp(-kt * 22.0) * 0.48

		samples[i] = total_sample * 0.82

	return _create_wav_stream(samples, true)


# 13. BGM Boss: "Master Control / Dragon Core" (32 beats - 150 BPM, ~12.80s loop)
# Colossal, climactic boss fight with thunderous sub-kicks, ominous cyber brass horns, and frantic 3-octave arpeggios.
func _synth_bgm_boss() -> AudioStreamWAV:
	var bpm: float = 150.0
	var beat_dur: float = 60.0 / bpm
	var total_beats: int = 32
	var duration: float = float(total_beats) * beat_dur
	var num_samples: int = int(duration * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(num_samples)

	# 8 bars: Em -> C -> D -> B7 -> Em -> Am -> B7 -> Em
	var boss_chords: Array = [
		[82.41,  164.81, 196.00, 246.94], # Em
		[65.41,  130.81, 164.81, 196.00], # C
		[73.42,  146.83, 185.00, 220.00], # D
		[61.74,  123.47, 155.56, 185.00], # B7
		[82.41,  164.81, 196.00, 246.94], # Em
		[110.00, 220.00, 261.63, 329.63], # Am
		[61.74,  123.47, 155.56, 185.00], # B7
		[82.41,  164.81, 196.00, 246.94]  # Em
	]

	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var current_beat: float = t / beat_dur
		var bar_idx: int = mini(int(current_beat / 4.0), 7)
		var chord: Array = boss_chords[bar_idx]
		var total_sample: float = 0.0

		# 1. Brassy Cyber Horn Stabs
		var stab_t: float = fmod(t, beat_dur * 0.5)
		var stab_env: float = exp(-stab_t * 10.0)
		for f in chord:
			var brass: float = sin(stab_t * f * 2.0 * TAU) + 0.5 * sin(stab_t * f * 4.0 * TAU) + 0.3 * (fmod(stab_t * f * 2.0, 1.0) * 2.0 - 1.0)
			total_sample += brass * stab_env * 0.12

		# 2. Frantic 16th Arpeggiator Sweeps
		var sixteenth: int = int(current_beat * 4.0) % 4
		var arp_f: float = chord[sixteenth % chord.size()] * 2.0
		var arp_t: float = fmod(t, beat_dur * 0.25)
		var arp: float = sin(arp_t * arp_f * TAU) * exp(-arp_t * 16.0)
		total_sample += arp * 0.24

		# 3. Colossal Sub-Kick Impact
		var beat_frac: float = fmod(current_beat, 1.0)
		if beat_frac < 0.24:
			var kt: float = beat_frac * beat_dur
			var sub_kick: float = sin(kt * lerpf(175.0, 35.0, kt / 0.12) * TAU) * exp(-kt * 16.0)
			total_sample += sub_kick * 0.58

		if (bar_idx == 3 or bar_idx == 7) and int(current_beat) % 2 == 1 and beat_frac < 0.18:
			var tom_t: float = beat_frac * beat_dur
			total_sample += sin(tom_t * 190.0 * TAU) * exp(-tom_t * 22.0) * 0.38

		samples[i] = total_sample * 0.82

	return _create_wav_stream(samples, true)


# 14. Victory Fanfare: "Grid Liberated" (3.6s)
# Ascending neon supersaw fanfare with shimmering crystal chimes and triumphant finish.
func _synth_jingle_victory() -> AudioStreamWAV:
	var duration: float = 3.6
	var num_samples: int = int(duration * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(num_samples)

	var fanfare_notes: Array[float] = [293.66, 369.99, 440.00, 587.33, 739.99, 880.00] # D4 -> F#4 -> A4 -> D5 -> F#5 -> A5
	var fanfare_times: Array[float] = [0.0, 0.18, 0.36, 0.54, 0.72, 0.95]
	var fanfare_durations: Array[float] = [0.18, 0.18, 0.18, 0.18, 0.23, 2.6]

	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var total_sample: float = 0.0

		for n in range(fanfare_notes.size()):
			var start_t: float = fanfare_times[n]
			var note_dur: float = fanfare_durations[n]
			if t >= start_t and t < start_t + note_dur:
				var note_t: float = t - start_t
				var f: float = fanfare_notes[n]
				var env: float = (note_t / 0.03) if note_t < 0.03 else exp(-(note_t - 0.03) * (1.6 if n == 5 else 3.5))
				var saw_a: float = fmod(note_t * f * 0.995, 1.0) * 2.0 - 1.0
				var saw_b: float = fmod(note_t * f * 1.005, 1.0) * 2.0 - 1.0
				var sin_v: float = sin(note_t * f * TAU)
				total_sample += ((saw_a + saw_b) * 0.4 + sin_v * 0.6) * env * 0.42

		if t >= 0.95:
			var chime_t: float = t - 0.95
			var chime_f: float = 2349.32
			var shimmer: float = sin(chime_t * chime_f * TAU) * exp(-chime_t * 2.8) * 0.22
			total_sample += shimmer

		samples[i] = total_sample * 0.82

	return _create_wav_stream(samples, false)


# 15. Stage Clear: "Grid Clear" (1.8s)
func _synth_jingle_stage_clear() -> AudioStreamWAV:
	var duration: float = 1.8
	var num_samples: int = int(duration * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(num_samples)

	var notes: Array[float] = [523.25, 659.25, 783.99, 1046.50]
	var step_dur: float = 0.12

	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var total_sample: float = 0.0
		var note_idx: int = mini(int(t / step_dur), 3)

		if t < step_dur * 4.0:
			var note_t: float = t - float(note_idx) * step_dur
			var f: float = notes[note_idx]
			var env: float = exp(-note_t * 6.0)
			total_sample = (sin(note_t * f * TAU) + 0.35 * (fmod(note_t * f, 1.0) * 2.0 - 1.0)) * env * 0.45
		else:
			var hold_t: float = t - step_dur * 4.0
			var env: float = exp(-hold_t * 2.2)
			total_sample = sin(hold_t * 1046.50 * TAU) * env * 0.35 + sin(hold_t * 2093.0 * TAU) * env * 0.15

		samples[i] = total_sample * 0.82

	return _create_wav_stream(samples, false)


# 16. Game Over: "Derezzed / Signal Lost" (2.5s)
func _synth_jingle_game_over() -> AudioStreamWAV:
	var duration: float = 2.5
	var num_samples: int = int(duration * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(num_samples)

	var notes: Array[float] = [440.0, 349.23, 293.66, 146.83]
	var times: Array[float] = [0.0, 0.45, 0.9, 1.4]
	var durs: Array[float] = [0.45, 0.45, 0.5, 1.1]

	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var total_sample: float = 0.0

		for n in range(notes.size()):
			var start_t: float = times[n]
			var dur: float = durs[n]
			if t >= start_t and t < start_t + dur:
				var note_t: float = t - start_t
				var f: float = notes[n]
				var env: float = sin(clampf(note_t / dur, 0.0, 1.0) * PI)
				var saw: float = fmod(note_t * f, 1.0) * 2.0 - 1.0
				var sin_v: float = sin(note_t * f * TAU)
				total_sample += (saw * 0.35 + sin_v * 0.65) * env * 0.38

		samples[i] = total_sample * 0.82

	return _create_wav_stream(samples, false)
