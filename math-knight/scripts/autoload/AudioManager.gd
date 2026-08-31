extends Node
## AudioManager singleton for MathKnight.
## Manages SFX pool, BGM crossfading, procedural audio synthesis, adaptive track selection, and event connections.

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
	"chest_break": "res://assets/audio/sfx_chest_break.wav"
}

const BGM_FILES: Dictionary = {
	# Menu & Exploration
	"title": "res://assets/audio/bgm_title.wav",
	"menu": "res://assets/audio/bgm_menu.wav",
	"menu_tavern": "res://assets/audio/bgm_menu.wav",
	"shop": "res://assets/audio/bgm_shop.wav",
	"map": "res://assets/audio/bgm_map.wav",
	
	# Operation-Specific Battles
	"battle": "res://assets/audio/bgm_battle.wav",
	"battle_addition": "res://assets/audio/bgm_addition.wav",
	"battle_subtraction": "res://assets/audio/bgm_subtraction.wav",
	"battle_multiplication": "res://assets/audio/bgm_multiplication.wav",
	"battle_division": "res://assets/audio/bgm_division.wav",
	"battle_mixed": "res://assets/audio/bgm_mixed.wav",
	
	# Game Mode Battles
	"battle_forge": "res://assets/audio/bgm_forge.wav",
	"battle_chain": "res://assets/audio/bgm_chain.wav",
	
	# Encounters
	"elite": "res://assets/audio/bgm_elite.wav",
	"boss": "res://assets/audio/bgm_boss.wav",
	
	# Jingles
	"victory": "res://assets/audio/jingle_victory.wav",
	"stage_clear": "res://assets/audio/jingle_stage_clear.wav",
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
	add_child(_jingle_player)

	# Polyphonic SFX Pool
	for i in range(SFX_POOL_SIZE):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.name = "SFXPlayer_" + str(i)
		p.bus = "Master"
		add_child(p)
		_sfx_pool.append(p)


func _on_music_player_finished(player: AudioStreamPlayer) -> void:
	# Loop safety fallback: if non-looping stream finishes, safely replay on next frame
	if player == _active_music_player and music_enabled and _current_track_name != "":
		player.call_deferred("play")


func _sync_with_save_manager() -> void:
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		if "sfx_enabled" in sm:
			sfx_enabled = sm.sfx_enabled
		if "music_enabled" in sm:
			music_enabled = sm.music_enabled
		else:
			sm.set("music_enabled", true)


func _connect_event_bus() -> void:
	if not has_node("/root/EventBus"):
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
	if not sfx_enabled:
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

	if not music_enabled:
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
	incoming_player.volume_db = -60.0
	incoming_player.play()

	if _music_crossfade_tween and _music_crossfade_tween.is_valid():
		_music_crossfade_tween.kill()

	_music_crossfade_tween = create_tween().set_parallel(true)
	_music_crossfade_tween.tween_property(incoming_player, "volume_db", target_volume_db, fade_duration)
	if outgoing_player.playing:
		_music_crossfade_tween.tween_property(outgoing_player, "volume_db", -60.0, fade_duration)
		_music_crossfade_tween.chain().tween_callback(outgoing_player.stop)

	_active_music_player = incoming_player


func play_adaptive_battle_music(config: RefCounted = null, is_boss: bool = false, is_elite: bool = false) -> void:
	if is_boss:
		play_music("boss")
		return
	if is_elite:
		play_music("elite")
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

	if fade_duration <= 0.0:
		_music_player_a.stop()
		_music_player_b.stop()
		return

	_music_crossfade_tween = create_tween().set_parallel(true)
	if _music_player_a.playing:
		_music_crossfade_tween.tween_property(_music_player_a, "volume_db", -60.0, fade_duration)
		_music_crossfade_tween.chain().tween_callback(_music_player_a.stop)
	if _music_player_b.playing:
		_music_crossfade_tween.tween_property(_music_player_b, "volume_db", -60.0, fade_duration)
		_music_crossfade_tween.chain().tween_callback(_music_player_b.stop)


func play_jingle(jingle_name: String) -> void:
	if not sounds.has(jingle_name):
		return
	var stream: AudioStream = sounds[jingle_name]
	if not stream:
		return

	# Temporarily duck music cleanly
	_is_ducked_for_jingle = true
	var duck_tween: Tween = create_tween().set_parallel(true)
	if _music_player_a.playing:
		duck_tween.tween_property(_music_player_a, "volume_db", -22.0, 0.25)
	if _music_player_b.playing:
		duck_tween.tween_property(_music_player_b, "volume_db", -22.0, 0.25)

	_jingle_player.stream = stream
	_jingle_player.volume_db = linear_to_db(music_volume * master_volume) + 2.0
	_jingle_player.play()

	# Restore music volume cleanly once jingle finishes
	var callable: Callable = func():
		_is_ducked_for_jingle = false
		var restore_tween: Tween = create_tween().set_parallel(true)
		var target_vol: float = linear_to_db(music_volume * master_volume)
		if _music_player_a.playing:
			restore_tween.tween_property(_music_player_a, "volume_db", target_vol, 0.8)
		if _music_player_b.playing:
			restore_tween.tween_property(_music_player_b, "volume_db", target_vol, 0.8)

	_jingle_player.finished.connect(callable, CONNECT_ONE_SHOT)


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


# === Audio Loading & Procedural Synthesis Engine ===

func _load_or_generate_all_audio() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/audio/")

	# 1. SFX: Generate in-memory stream directly so it never depends on .import flags
	for key in SFX_FILES:
		var file_path: String = SFX_FILES[key]
		var stream: AudioStream = _synthesize_sfx(key)
		if stream is AudioStreamWAV:
			_save_wav_file(file_path, stream as AudioStreamWAV)
		sounds[key] = stream

	# 2. BGM & Jingles: Generate full in-memory AudioStreamWAV with precise sample loop bounds
	for key in BGM_FILES:
		var file_path: String = BGM_FILES[key]
		var stream: AudioStreamWAV = _synthesize_bgm(key)
		if stream:
			_save_wav_file(file_path, stream)
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
	if FileAccess.file_exists(path):
		return # File already exists, avoid rewriting on every boot
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


# --- SFX Synthesizers ---

func _synth_bubble_pop() -> AudioStreamWAV:
	var duration: float = 0.12
	var num_samples: int = int(duration * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(num_samples)
	var phase: float = 0.0
	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var progress: float = t / duration
		var freq: float = lerpf(950.0, 240.0, progress * progress)
		phase += freq * (TAU / SAMPLE_RATE)
		var env: float = exp(-t * 32.0)
		var pop_click: float = (randf_range(-1.0, 1.0) * 0.35) if (i < 40) else 0.0
		samples[i] = (sin(phase) + pop_click) * env * 0.9
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
		var freq: float = lerpf(580.0, 140.0, progress)
		phase += freq * (TAU / SAMPLE_RATE)
		var body: float = sin(phase) * 0.45
		var white_noise: float = randf_range(-1.0, 1.0)
		var filter_coeff: float = lerpf(0.55, 0.15, progress)
		noise_filter = noise_filter + filter_coeff * (white_noise - noise_filter)
		var env: float = (t / 0.025) if t < 0.025 else (1.0 - ((t - 0.025) / (duration - 0.025)))
		samples[i] = (body + noise_filter * 0.7) * env * 0.85
	return _create_wav_stream(samples, false)


func _synth_correct() -> AudioStreamWAV:
	var duration: float = 0.48
	var num_samples: int = int(duration * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(num_samples)
	var freqs: Array[float] = [783.99, 987.77, 1318.51] # G5, B5, E6
	var offsets: Array[float] = [0.0, 0.07, 0.14]
	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var total_sample: float = 0.0
		for n in range(freqs.size()):
			var note_t: float = t - offsets[n]
			if note_t >= 0.0:
				var f: float = freqs[n]
				var env: float = exp(-note_t * 9.5)
				var bell: float = sin(note_t * f * TAU) + 0.35 * sin(note_t * f * 2.76 * TAU) + 0.15 * sin(note_t * f * 4.2 * TAU)
				total_sample += bell * env * 0.35
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
		var f1: float = lerpf(135.0, 90.0, t / duration)
		var f2: float = lerpf(142.0, 94.0, t / duration)
		phase1 += f1 * (TAU / SAMPLE_RATE)
		phase2 += f2 * (TAU / SAMPLE_RATE)
		var wave1: float = 1.0 if (sin(phase1) > 0.0) else -1.0
		var wave2: float = 1.0 if (sin(phase2) > 0.0) else -1.0
		var env: float = 1.0 if t < 0.2 else (1.0 - (t - 0.2) / 0.12)
		samples[i] = (wave1 * 0.35 + wave2 * 0.35) * env
	return _create_wav_stream(samples, false)


func _synth_coin() -> AudioStreamWAV:
	var duration: float = 0.28
	var num_samples: int = int(duration * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(num_samples)
	var phase: float = 0.0
	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var f: float = 987.77 if t < 0.06 else 1318.51
		phase += f * (TAU / SAMPLE_RATE)
		var note_t: float = t if t < 0.06 else (t - 0.06)
		var env: float = exp(-note_t * 11.0)
		var chime: float = sin(phase) + 0.2 * sin(phase * 2.0)
		samples[i] = chime * env * 0.55
	return _create_wav_stream(samples, false)


func _synth_diamond() -> AudioStreamWAV:
	var duration: float = 0.65
	var num_samples: int = int(duration * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(num_samples)
	var freqs: Array[float] = [1174.66, 1479.98, 1760.00, 2349.32]
	var offsets: Array[float] = [0.0, 0.08, 0.16, 0.24]
	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var total_sample: float = 0.0
		for n in range(freqs.size()):
			var note_t: float = t - offsets[n]
			if note_t >= 0.0:
				var f: float = freqs[n]
				var vibrato: float = sin(note_t * 12.0) * 4.0
				var env: float = exp(-note_t * 7.0)
				var bell: float = sin(note_t * (f + vibrato) * TAU) + 0.3 * sin(note_t * f * 2.0 * TAU)
				total_sample += bell * env * 0.28
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
		var f: float = lerpf(1800.0, 600.0, t / duration)
		phase += f * (TAU / SAMPLE_RATE)
		var env: float = exp(-t * 90.0)
		samples[i] = sin(phase) * env * 0.8
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
			var brass: float = sin(t * f * TAU) + 0.4 * sin(t * f * 2.0 * TAU) + 0.2 * sin(t * f * 3.0 * TAU)
			total_sample = brass * env * 0.45
		else:
			var chord_t: float = t - step_dur * 4.0
			var env: float = exp(-chord_t * 2.5)
			for f in notes:
				var brass: float = sin(chord_t * f * TAU) + 0.3 * sin(chord_t * f * 2.0 * TAU)
				total_sample += brass * env * 0.16
		samples[i] = total_sample
	return _create_wav_stream(samples, false)


func _synth_chest_open() -> AudioStreamWAV:
	var duration: float = 0.65
	var num_samples: int = int(duration * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(num_samples)
	var phase_creak: float = 0.0
	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var total_sample: float = 0.0
		if t < 0.25:
			var f: float = lerpf(220.0, 480.0, t / 0.25)
			var mod: float = sin(t * 70.0 * TAU) * 60.0
			phase_creak += (f + mod) * (TAU / SAMPLE_RATE)
			total_sample = sin(phase_creak) * exp(-t * 8.0) * 0.5
		else:
			var chime_t: float = t - 0.25
			var chime_f: float = 1318.51
			var env: float = exp(-chime_t * 6.0)
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
		var f_thud: float = lerpf(120.0, 40.0, t / duration)
		phase_thud += f_thud * (TAU / SAMPLE_RATE)
		var thud: float = sin(phase_thud) * exp(-t * 12.0) * 0.6
		var crackle: float = (randf_range(-1.0, 1.0) * exp(-t * 18.0) * 0.5) if (t < 0.18) else 0.0
		samples[i] = thud + crackle
	return _create_wav_stream(samples, false)


# --- BGM Synthesizers (Full 32-Beat Multi-Phrase Loop Compositions) ---

# 1. BGM Title: Epic Royal Theme (32 beats - 95 BPM, ~20.2s loop)
func _synth_bgm_title() -> AudioStreamWAV:
	var bpm: float = 95.0
	var beat_dur: float = 60.0 / bpm
	var total_beats: int = 32
	var duration: float = float(total_beats) * beat_dur
	var num_samples: int = int(duration * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(num_samples)

	# 8 bars: D -> G -> A -> D -> Bm -> G -> Em -> A
	var chords: Array = [
		[146.83, 220.0, 293.66, 369.99], # D
		[196.00, 246.94, 293.66, 392.00], # G
		[220.00, 277.18, 329.63, 440.00], # A
		[146.83, 220.0, 293.66, 587.33], # D
		[123.47, 185.00, 246.94, 293.66], # Bm
		[196.00, 246.94, 293.66, 392.00], # G
		[164.81, 196.00, 246.94, 329.63], # Em
		[220.00, 277.18, 329.63, 440.00]  # A
	]
	var lead_melody: Array[float] = [
		293.66, 369.99, 440.00, 587.33,
		392.00, 493.88, 587.33, 493.88,
		440.00, 554.37, 659.25, 554.37,
		587.33, 739.99, 880.00, 587.33,
		493.88, 587.33, 739.99, 587.33,
		392.00, 493.88, 587.33, 739.99,
		659.25, 587.33, 493.88, 440.00,
		554.37, 659.25, 739.99, 587.33
	]

	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var current_beat: float = t / beat_dur
		var bar_idx: int = mini(int(current_beat / 4.0), 7)
		var chord: Array = chords[bar_idx]
		var total_sample: float = 0.0

		# Harp Arpeggio (16th notes)
		var sixteenth_idx: int = int(current_beat * 4.0) % 4
		var harp_freq: float = chord[sixteenth_idx]
		var harp_t: float = fmod(t, beat_dur * 0.25)
		var harp_env: float = exp(-harp_t * 8.5)
		var harp: float = (sin(harp_t * harp_freq * TAU) + 0.3 * sin(harp_t * harp_freq * 2.0 * TAU)) * harp_env
		total_sample += harp * 0.30

		# Majestic Brass Lead
		var beat_idx: int = mini(int(current_beat), 31)
		var lead_freq: float = lead_melody[beat_idx]
		var lead_t: float = fmod(t, beat_dur)
		var vibrato: float = sin(lead_t * 5.0 * TAU) * 2.5
		var lead_env: float = sin(clampf(lead_t / beat_dur, 0.0, 1.0) * PI)
		var brass: float = (sin(lead_t * (lead_freq + vibrato) * TAU) + 0.45 * sin(lead_t * lead_freq * 2.0 * TAU) + 0.25 * sin(lead_t * lead_freq * 3.0 * TAU)) * lead_env
		total_sample += brass * 0.32

		# Timpani / March Snare
		var beat_frac: float = fmod(current_beat, 1.0)
		var beat_num: int = int(current_beat) % 4
		if beat_num == 0 and beat_frac < 0.25:
			var drum_t: float = beat_frac * beat_dur
			var timp_f: float = lerpf(120.0, 50.0, drum_t / 0.2)
			total_sample += sin(drum_t * timp_f * TAU) * exp(-drum_t * 12.0) * 0.45

		samples[i] = total_sample * 0.85

	return _create_wav_stream(samples, true)


# 2. BGM Menu: Tavern Lute & Flute (32 beats - 105 BPM, ~18.3s loop)
func _synth_bgm_menu() -> AudioStreamWAV:
	var bpm: float = 105.0
	var beat_dur: float = 60.0 / bpm
	var total_beats: int = 32
	var duration: float = float(total_beats) * beat_dur
	var num_samples: int = int(duration * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(num_samples)

	# 8 bars: Am -> F -> C -> G -> Dm -> Am -> F -> E7
	var chord_triads: Array = [
		[220.0, 261.63, 329.63, 440.0],  # Am
		[174.61, 220.0, 261.63, 349.23], # F
		[261.63, 329.63, 392.0, 523.25],  # C
		[196.0, 246.94, 293.66, 392.0],  # G
		[146.83, 174.61, 220.0, 293.66], # Dm
		[220.0, 261.63, 329.63, 440.0],  # Am
		[174.61, 220.0, 261.63, 349.23], # F
		[164.81, 207.65, 246.94, 329.63] # E7
	]
	var flute_melody: Array[float] = [
		440.0, 523.25, 659.25, 523.25,
		440.0, 349.23, 392.0, 440.0,
		523.25, 659.25, 783.99, 659.25,
		587.33, 493.88, 523.25, 440.0,
		587.33, 698.46, 880.00, 698.46,
		659.25, 523.25, 440.00, 523.25,
		698.46, 659.25, 523.25, 440.00,
		493.88, 523.25, 587.33, 440.00
	]

	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var current_beat: float = t / beat_dur
		var bar_idx: int = mini(int(current_beat / 4.0), 7)
		var chord: Array = chord_triads[bar_idx]
		var total_sample: float = 0.0

		# Lute Arpeggio
		var sub_beat: int = int(current_beat * 2.0) % 8
		var lute_freq: float = chord[sub_beat % 4]
		var lute_t: float = fmod(t, beat_dur * 0.5)
		var lute_env: float = exp(-lute_t * 6.5)
		var lute: float = (sin(lute_t * lute_freq * TAU) + 0.35 * sin(lute_t * lute_freq * 2.0 * TAU) + 0.15 * sin(lute_t * lute_freq * 3.0 * TAU)) * lute_env
		total_sample += lute * 0.32

		# Flute Melody
		var beat_idx: int = mini(int(current_beat), 31)
		var flute_freq: float = flute_melody[beat_idx]
		var flute_t: float = fmod(t, beat_dur)
		var vibrato: float = sin(flute_t * 5.5 * TAU) * 3.0
		var flute_env: float = sin(clampf(flute_t / beat_dur, 0.0, 1.0) * PI)
		var flute: float = (sin(flute_t * (flute_freq + vibrato) * TAU) + 0.2 * sin(flute_t * flute_freq * 2.0 * TAU)) * flute_env
		total_sample += flute * 0.28

		# Tambourine
		var beat_fraction: float = fmod(current_beat, 1.0)
		var beat_num: int = int(current_beat) % 4
		if (beat_num == 1 or beat_num == 3) and beat_fraction < 0.15:
			var drum_t: float = beat_fraction * beat_dur
			var tamb: float = (randf_range(-1.0, 1.0) * 0.4 + sin(drum_t * 300.0 * TAU) * 0.3) * exp(-drum_t * 25.0)
			total_sample += tamb * 0.2

		samples[i] = total_sample * 0.85

	return _create_wav_stream(samples, true)


# 3. BGM Shop: Whimsical Merchant & Mystic Items (32 beats - 110 BPM, ~17.5s loop)
func _synth_bgm_shop() -> AudioStreamWAV:
	var bpm: float = 110.0
	var beat_dur: float = 60.0 / bpm
	var total_beats: int = 32
	var duration: float = float(total_beats) * beat_dur
	var num_samples: int = int(duration * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(num_samples)

	# 8 bars: Cmaj7 -> Fmaj7 -> Em7 -> G -> Am7 -> Dm7 -> G7 -> Cmaj7
	var chords: Array = [
		[261.63, 329.63, 392.00, 493.88], # Cmaj7
		[174.61, 220.00, 261.63, 329.63], # Fmaj7
		[164.81, 196.00, 246.94, 293.66], # Em7
		[196.00, 246.94, 293.66, 392.00], # G
		[220.00, 261.63, 329.63, 392.00], # Am7
		[146.83, 174.61, 220.00, 261.63], # Dm7
		[196.00, 246.94, 293.66, 349.23], # G7
		[261.63, 329.63, 392.00, 523.25]  # C
	]
	var shop_melody: Array[float] = [
		523.25, 493.88, 392.00, 329.63,
		349.23, 440.00, 523.25, 659.25,
		493.88, 392.00, 329.63, 293.66,
		392.00, 440.00, 493.88, 523.25,
		440.00, 523.25, 659.25, 587.33,
		523.25, 440.00, 349.23, 392.00,
		440.00, 493.88, 587.33, 493.88,
		523.25, 659.25, 783.99, 523.25
	]

	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var current_beat: float = t / beat_dur
		var bar_idx: int = mini(int(current_beat / 4.0), 7)
		var chord: Array = chords[bar_idx]
		var total_sample: float = 0.0

		# Pizzicato Harp / Pluck
		var sub_beat: int = int(current_beat * 2.0) % 4
		var harp_f: float = chord[sub_beat]
		var harp_t: float = fmod(t, beat_dur * 0.5)
		var harp: float = (sin(harp_t * harp_f * TAU) + 0.4 * sin(harp_t * harp_f * 2.0 * TAU)) * exp(-harp_t * 11.0)
		total_sample += harp * 0.32

		# Whimsical Bell Lead
		var beat_idx: int = mini(int(current_beat), 31)
		var bell_f: float = shop_melody[beat_idx]
		var bell_t: float = fmod(t, beat_dur)
		var bell: float = (sin(bell_t * bell_f * TAU) + 0.3 * sin(bell_t * bell_f * 3.0 * TAU)) * exp(-bell_t * 4.5)
		total_sample += bell * 0.28

		# Soft Shaker
		var sixteenth_f: float = fmod(current_beat * 4.0, 1.0)
		if sixteenth_f < 0.1:
			var shaker_t: float = sixteenth_f * (beat_dur * 0.25)
			total_sample += randf_range(-1.0, 1.0) * exp(-shaker_t * 80.0) * 0.12

		samples[i] = total_sample * 0.85

	return _create_wav_stream(samples, true)


# 4. BGM Map: Adventurous Tactical Path (32 beats - 110 BPM, ~17.5s loop)
func _synth_bgm_map() -> AudioStreamWAV:
	var bpm: float = 110.0
	var beat_dur: float = 60.0 / bpm
	var total_beats: int = 32
	var duration: float = float(total_beats) * beat_dur
	var num_samples: int = int(duration * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(num_samples)

	# 8 bars: Em -> G -> D -> C -> Am -> Em -> C -> B7
	var chords: Array = [
		[164.81, 196.00, 246.94, 329.63], # Em
		[196.00, 246.94, 293.66, 392.00], # G
		[146.83, 220.00, 293.66, 369.99], # D
		[130.81, 164.81, 196.00, 261.63], # C
		[220.00, 261.63, 329.63, 440.00], # Am
		[164.81, 196.00, 246.94, 329.63], # Em
		[130.81, 164.81, 196.00, 261.63], # C
		[123.47, 155.56, 185.00, 246.94]  # B7
	]
	var map_melody: Array[float] = [
		329.63, 392.00, 493.88, 392.00,
		392.00, 493.88, 587.33, 493.88,
		369.99, 440.00, 587.33, 440.00,
		261.63, 329.63, 392.00, 329.63,
		440.00, 523.25, 659.25, 523.25,
		493.88, 392.00, 329.63, 246.94,
		261.63, 329.63, 392.00, 493.88,
		466.16, 369.99, 246.94, 329.63
	]

	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var current_beat: float = t / beat_dur
		var bar_idx: int = mini(int(current_beat / 4.0), 7)
		var chord: Array = chords[bar_idx]
		var total_sample: float = 0.0

		# Rhythmic Cello/Bass Staccato
		var bass_t: float = fmod(t, beat_dur * 0.5)
		var bass_f: float = chord[0]
		var bass: float = (sin(bass_t * bass_f * TAU) + 0.35 * sin(bass_t * bass_f * 2.0 * TAU)) * exp(-bass_t * 7.5)
		total_sample += bass * 0.35

		# Explorer Flute Motif
		var beat_idx: int = mini(int(current_beat), 31)
		var flute_f: float = map_melody[beat_idx]
		var flute_t: float = fmod(t, beat_dur)
		var vibrato: float = sin(flute_t * 5.0 * TAU) * 2.0
		var flute_env: float = sin(clampf(flute_t / beat_dur, 0.0, 1.0) * PI)
		var flute: float = (sin(flute_t * (flute_f + vibrato) * TAU) + 0.2 * sin(flute_t * flute_f * 2.0 * TAU)) * flute_env
		total_sample += flute * 0.28

		# Marching drum pulse on 1 and 3
		var beat_num: int = int(current_beat) % 4
		var beat_f: float = fmod(current_beat, 1.0)
		if (beat_num == 0 or beat_num == 2) and beat_f < 0.18:
			var drum_t: float = beat_f * beat_dur
			total_sample += sin(drum_t * 130.0 * TAU) * exp(-drum_t * 18.0) * 0.35

		samples[i] = total_sample * 0.85

	return _create_wav_stream(samples, true)


# 5. BGM Addition: Sonnenritter-Marsch (32 beats - 130 BPM, ~14.8s loop)
func _synth_bgm_addition() -> AudioStreamWAV:
	var bpm: float = 130.0
	var beat_dur: float = 60.0 / bpm
	var total_beats: int = 32
	var duration: float = float(total_beats) * beat_dur
	var num_samples: int = int(duration * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(num_samples)

	# 8 bars: C -> G -> Am -> F -> C -> G -> F -> C
	var bass_notes: Array[float] = [130.81, 98.00, 110.00, 87.31, 130.81, 98.00, 87.31, 130.81]
	var lead_notes: Array[float] = [
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
		var total_sample: float = 0.0

		# 16th-note Chiptune Bass
		var bass_t: float = fmod(t, beat_dur * 0.25)
		var bass_f: float = bass_notes[bar_idx]
		var bass_wave: float = 1.0 if (sin(bass_t * bass_f * TAU) > 0.0) else -1.0
		total_sample += bass_wave * exp(-bass_t * 14.0) * 0.25

		# Bright Sun Knight Brass Lead
		var beat_idx: int = mini(int(current_beat), 31)
		var lead_f: float = lead_notes[beat_idx]
		var lead_t: float = fmod(t, beat_dur)
		var lead_env: float = sin(clampf(lead_t / beat_dur, 0.0, 1.0) * PI)
		var brass: float = (sin(lead_t * lead_f * TAU) + 0.4 * sin(lead_t * lead_f * 2.0 * TAU) + 0.2 * sin(lead_t * lead_f * 3.0 * TAU)) * lead_env
		total_sample += brass * 0.32

		# Upbeat Drums
		var beat_f: float = fmod(current_beat, 1.0)
		var beat_int: int = int(current_beat) % 4
		if (beat_int == 0 or beat_int == 2) and beat_f < 0.2:
			var kick_t: float = beat_f * beat_dur
			total_sample += sin(kick_t * lerpf(140.0, 45.0, kick_t / 0.15) * TAU) * exp(-kick_t * 22.0) * 0.45
		if (beat_int == 1 or beat_int == 3) and beat_f < 0.2:
			var snare_t: float = beat_f * beat_dur
			total_sample += (randf_range(-1.0, 1.0) * 0.6 + sin(snare_t * 220.0 * TAU) * 0.4) * exp(-snare_t * 20.0) * 0.4

		samples[i] = total_sample * 0.85

	return _create_wav_stream(samples, true)


# 6. BGM Subtraction: Schatten-Klinge (32 beats - 125 BPM, ~15.4s loop)
func _synth_bgm_subtraction() -> AudioStreamWAV:
	var bpm: float = 125.0
	var beat_dur: float = 60.0 / bpm
	var total_beats: int = 32
	var duration: float = float(total_beats) * beat_dur
	var num_samples: int = int(duration * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(num_samples)

	# 8 bars: Dm -> Bb -> Gm -> A -> Dm -> F -> C -> A
	var bass_roots: Array[float] = [146.83, 116.54, 98.00, 110.00, 146.83, 174.61, 130.81, 110.00]
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
		var total_sample: float = 0.0

		# Synth Bass Pulse
		var bass_t: float = fmod(t, beat_dur * 0.5)
		var bass_f: float = bass_roots[bar_idx]
		var bass: float = (sin(bass_t * bass_f * TAU) + 0.5 * sin(bass_t * bass_f * 2.0 * TAU)) * exp(-bass_t * 7.0)
		total_sample += bass * 0.38

		# Shadow Blade Saw Lead
		var beat_idx: int = mini(int(current_beat), 31)
		var lead_f: float = lead_melody[beat_idx]
		var lead_t: float = fmod(t, beat_dur)
		var saw: float = fmod(lead_t * lead_f, 1.0) * 2.0 - 1.0
		total_sample += saw * sin(clampf(lead_t / beat_dur, 0.0, 1.0) * PI) * 0.25

		# Crisp Hi-hat & Snare
		var beat_f: float = fmod(current_beat, 1.0)
		if (int(current_beat) % 2 == 1) and beat_f < 0.18:
			var snare_t: float = beat_f * beat_dur
			total_sample += randf_range(-1.0, 1.0) * exp(-snare_t * 24.0) * 0.35

		samples[i] = total_sample * 0.85

	return _create_wav_stream(samples, true)


# 7. BGM Multiplication: Wirbelsturm-Duell (32 beats - 142 BPM, ~13.5s loop)
func _synth_bgm_multiplication() -> AudioStreamWAV:
	var bpm: float = 142.0
	var beat_dur: float = 60.0 / bpm
	var total_beats: int = 32
	var duration: float = float(total_beats) * beat_dur
	var num_samples: int = int(duration * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(num_samples)

	# 8 bars: Em -> C -> G -> D -> Em -> Am -> D -> B7
	var chords: Array = [
		[164.81, 196.00, 246.94, 329.63], # Em
		[130.81, 164.81, 196.00, 261.63], # C
		[196.00, 246.94, 293.66, 392.00], # G
		[146.83, 220.00, 293.66, 369.99], # D
		[164.81, 196.00, 246.94, 329.63], # Em
		[220.00, 261.63, 329.63, 440.00], # Am
		[146.83, 220.00, 293.66, 369.99], # D
		[123.47, 155.56, 185.00, 246.94]  # B7
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

		# Fast Galloping Bass Arpeggio (16th notes)
		var sixteenth: int = int(current_beat * 4.0) % 4
		var arp_f: float = chord[sixteenth]
		var arp_t: float = fmod(t, beat_dur * 0.25)
		var arp: float = sin(arp_t * arp_f * TAU) * exp(-arp_t * 14.0)
		total_sample += arp * 0.35

		# Soaring Whirlwind Lead
		var beat_idx: int = mini(int(current_beat), 31)
		var lead_f: float = lead_melody[beat_idx]
		var lead_t: float = fmod(t, beat_dur)
		var lead_saw: float = fmod(lead_t * lead_f, 1.0) * 2.0 - 1.0
		var lead_sin: float = sin(lead_t * lead_f * TAU)
		total_sample += (lead_saw * 0.4 + lead_sin * 0.6) * exp(-lead_t * 3.5) * 0.32

		# Double Kick Driving Drums
		var beat_f: float = fmod(current_beat, 0.5)
		if beat_f < 0.15:
			var kick_t: float = beat_f * (beat_dur * 0.5)
			total_sample += sin(kick_t * 120.0 * TAU) * exp(-kick_t * 22.0) * 0.42

		samples[i] = total_sample * 0.85

	return _create_wav_stream(samples, true)


# 8. BGM Division: Kristall-Präzision (32 beats - 120 BPM, ~16.0s loop)
func _synth_bgm_division() -> AudioStreamWAV:
	var bpm: float = 120.0
	var beat_dur: float = 60.0 / bpm
	var total_beats: int = 32
	var duration: float = float(total_beats) * beat_dur
	var num_samples: int = int(duration * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(num_samples)

	# 8 bars: Bm -> G -> D -> A -> Em -> Bm -> G -> F#7
	var chords: Array = [
		[246.94, 293.66, 369.99, 493.88], # Bm
		[196.00, 246.94, 293.66, 392.00], # G
		[146.83, 220.00, 293.66, 369.99], # D
		[220.00, 277.18, 329.63, 440.00], # A
		[164.81, 196.00, 246.94, 329.63], # Em
		[246.94, 293.66, 369.99, 493.88], # Bm
		[196.00, 246.94, 293.66, 392.00], # G
		[185.00, 233.08, 277.18, 369.99]  # F#7
	]

	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var current_beat: float = t / beat_dur
		var bar_idx: int = mini(int(current_beat / 4.0), 7)
		var chord: Array = chords[bar_idx]
		var total_sample: float = 0.0

		# Crystal Bell Polyrhythm
		var note_idx: int = int(current_beat * 3.0) % 4
		var bell_f: float = chord[note_idx] * 2.0
		var bell_t: float = fmod(t, beat_dur / 3.0)
		var bell: float = (sin(bell_t * bell_f * TAU) + 0.3 * sin(bell_t * bell_f * 2.7 * TAU)) * exp(-bell_t * 8.0)
		total_sample += bell * 0.35

		# Clockwork Tick Percussion
		var tick_f: float = fmod(current_beat * 2.0, 1.0)
		if tick_f < 0.08:
			var tick_t: float = tick_f * (beat_dur * 0.5)
			total_sample += sin(tick_t * 1800.0 * TAU) * exp(-tick_t * 70.0) * 0.2

		# Deep Precision Sub-Bass
		var bass_t: float = fmod(t, beat_dur)
		var bass_f: float = chord[0] * 0.5
		total_sample += sin(bass_t * bass_f * TAU) * exp(-bass_t * 5.0) * 0.35

		samples[i] = total_sample * 0.85

	return _create_wav_stream(samples, true)


# 9. BGM Mixed: Ritter-Symphonie (32 beats - 136 BPM, ~14.1s loop)
func _synth_bgm_mixed() -> AudioStreamWAV:
	var bpm: float = 136.0
	var beat_dur: float = 60.0 / bpm
	var total_beats: int = 32
	var duration: float = float(total_beats) * beat_dur
	var num_samples: int = int(duration * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(num_samples)

	# 8 bars: Am -> F -> Dm -> E7 -> Am -> C -> G -> E7
	var chords: Array = [
		[220.0, 261.63, 329.63, 440.0],
		[174.61, 220.0, 261.63, 349.23],
		[146.83, 174.61, 220.0, 293.66],
		[164.81, 207.65, 246.94, 329.63],
		[220.0, 261.63, 329.63, 440.0],
		[261.63, 329.63, 392.0, 523.25],
		[196.0, 246.94, 293.66, 392.0],
		[164.81, 207.65, 246.94, 329.63]
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

		# 16th-note Chiptune Arpeggios
		var sixteenth: int = int(current_beat * 4.0) % 4
		var arp_f: float = chord[sixteenth]
		var arp_t: float = fmod(t, beat_dur * 0.25)
		var arp: float = (1.0 if sin(arp_t * arp_f * TAU) > 0.0 else -1.0) * exp(-arp_t * 14.0)
		total_sample += arp * 0.25

		# Heroic Symphonic Lead
		var beat_idx: int = mini(int(current_beat), 31)
		var lead_f: float = lead_melody[beat_idx]
		var lead_t: float = fmod(t, beat_dur)
		var brass: float = (sin(lead_t * lead_f * TAU) + 0.4 * sin(lead_t * lead_f * 2.0 * TAU)) * exp(-lead_t * 3.5)
		total_sample += brass * 0.32

		# Heavy Kick & Snare
		var beat_f: float = fmod(current_beat, 1.0)
		var beat_int: int = int(current_beat) % 4
		if (beat_int == 0 or beat_int == 2) and beat_f < 0.2:
			var kick_t: float = beat_f * beat_dur
			total_sample += sin(kick_t * lerpf(150.0, 40.0, kick_t / 0.15) * TAU) * exp(-kick_t * 22.0) * 0.45
		if (beat_int == 1 or beat_int == 3) and beat_f < 0.2:
			var snare_t: float = beat_f * beat_dur
			total_sample += (randf_range(-1.0, 1.0) * 0.7 + sin(snare_t * 220.0 * TAU) * 0.3) * exp(-snare_t * 20.0) * 0.4

		samples[i] = total_sample * 0.85

	return _create_wav_stream(samples, true)


# 10. BGM Forge: Zahlen-Schmiede (32 beats - 126 BPM, ~15.2s loop)
func _synth_bgm_forge() -> AudioStreamWAV:
	var bpm: float = 126.0
	var beat_dur: float = 60.0 / bpm
	var total_beats: int = 32
	var duration: float = float(total_beats) * beat_dur
	var num_samples: int = int(duration * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(num_samples)

	# 8 bars: Em -> D -> C -> B7 -> Em -> G -> A -> B7
	var chords: Array = [
		[164.81, 196.00, 246.94],
		[146.83, 185.00, 220.00],
		[130.81, 164.81, 196.00],
		[123.47, 155.56, 185.00],
		[164.81, 196.00, 246.94],
		[196.00, 246.94, 293.66],
		[220.00, 277.18, 329.63],
		[123.47, 155.56, 185.00]
	]

	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var current_beat: float = t / beat_dur
		var bar_idx: int = mini(int(current_beat / 4.0), 7)
		var chord: Array = chords[bar_idx]
		var total_sample: float = 0.0

		# Metallic Anvil Strike on beats 2 & 4
		var beat_int: int = int(current_beat) % 4
		var beat_f: float = fmod(current_beat, 1.0)
		if (beat_int == 1 or beat_int == 3) and beat_f < 0.22:
			var anvil_t: float = beat_f * beat_dur
			var anvil_clang: float = (sin(anvil_t * 1200.0 * TAU) + 0.5 * sin(anvil_t * 2760.0 * TAU) + 0.3 * sin(anvil_t * 3920.0 * TAU)) * exp(-anvil_t * 15.0)
			total_sample += anvil_clang * 0.4

		# Industrial Saw Bass
		var bass_t: float = fmod(t, beat_dur * 0.5)
		var bass_f: float = chord[0]
		var saw: float = fmod(bass_t * bass_f, 1.0) * 2.0 - 1.0
		total_sample += saw * exp(-bass_t * 9.0) * 0.3

		# Heavy Steam Kick on 1 & 3
		if (beat_int == 0 or beat_int == 2) and beat_f < 0.25:
			var kick_t: float = beat_f * beat_dur
			total_sample += sin(kick_t * lerpf(120.0, 35.0, kick_t / 0.2) * TAU) * exp(-kick_t * 16.0) * 0.5

		samples[i] = total_sample * 0.85

	return _create_wav_stream(samples, true)


# 11. BGM Chain: Meister-Kette (32 beats - 140 BPM, ~13.7s loop)
func _synth_bgm_chain() -> AudioStreamWAV:
	var bpm: float = 140.0
	var beat_dur: float = 60.0 / bpm
	var total_beats: int = 32
	var duration: float = float(total_beats) * beat_dur
	var num_samples: int = int(duration * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(num_samples)

	# 8 bars: F -> G -> Am -> C -> F -> G -> Em -> Am
	var chords: Array = [
		[174.61, 220.0, 261.63, 349.23],
		[196.0, 246.94, 293.66, 392.0],
		[220.0, 261.63, 329.63, 440.0],
		[261.63, 329.63, 392.0, 523.25],
		[174.61, 220.0, 261.63, 349.23],
		[196.0, 246.94, 293.66, 392.0],
		[164.81, 196.0, 246.94, 329.63],
		[220.0, 261.63, 329.63, 440.0]
	]

	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var current_beat: float = t / beat_dur
		var bar_idx: int = mini(int(current_beat / 4.0), 7)
		var chord: Array = chords[bar_idx]
		var total_sample: float = 0.0

		# Fast 16th Arpeggiator Sweep
		var sixteenth: int = int(current_beat * 4.0) % 4
		var arp_f: float = chord[sixteenth] * 2.0
		var arp_t: float = fmod(t, beat_dur * 0.25)
		var arp: float = sin(arp_t * arp_f * TAU) * exp(-arp_t * 16.0)
		total_sample += arp * 0.32

		# Four-on-the-Floor Kick Drum
		var beat_f: float = fmod(current_beat, 1.0)
		if beat_f < 0.18:
			var kick_t: float = beat_f * beat_dur
			total_sample += sin(kick_t * lerpf(160.0, 45.0, kick_t / 0.15) * TAU) * exp(-kick_t * 22.0) * 0.48

		# High-energy synth chord stab
		var stab_t: float = fmod(t, beat_dur)
		var stab: float = (sin(stab_t * chord[1] * TAU) + sin(stab_t * chord[2] * TAU)) * exp(-stab_t * 6.0)
		total_sample += stab * 0.22

		samples[i] = total_sample * 0.85

	return _create_wav_stream(samples, true)


# 12. BGM Elite: Elite-Herausforderung (32 beats - 145 BPM, ~13.2s loop)
func _synth_bgm_elite() -> AudioStreamWAV:
	var bpm: float = 145.0
	var beat_dur: float = 60.0 / bpm
	var total_beats: int = 32
	var duration: float = float(total_beats) * beat_dur
	var num_samples: int = int(duration * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(num_samples)

	# 8 bars: Gm -> Eb -> F -> D -> Gm -> Cm -> D -> G
	var chords: Array = [
		[196.00, 233.08, 293.66],
		[155.56, 196.00, 233.08],
		[174.61, 220.00, 261.63],
		[146.83, 185.00, 220.00],
		[196.00, 233.08, 293.66],
		[130.81, 155.56, 196.00],
		[146.83, 185.00, 220.00],
		[196.00, 246.94, 293.66]
	]

	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var current_beat: float = t / beat_dur
		var bar_idx: int = mini(int(current_beat / 4.0), 7)
		var chord: Array = chords[bar_idx]
		var total_sample: float = 0.0

		# Fast Saw Stabs
		var stab_t: float = fmod(t, beat_dur * 0.5)
		var saw_f: float = chord[0] * 2.0
		var saw: float = fmod(stab_t * saw_f, 1.0) * 2.0 - 1.0
		total_sample += saw * exp(-stab_t * 12.0) * 0.35

		# Heavy Fast Percussion
		var beat_f: float = fmod(current_beat, 0.5)
		if beat_f < 0.15:
			var kick_t: float = beat_f * (beat_dur * 0.5)
			total_sample += sin(kick_t * 130.0 * TAU) * exp(-kick_t * 22.0) * 0.45

		samples[i] = total_sample * 0.85

	return _create_wav_stream(samples, true)


# 13. BGM Battle (Default / Legacy - 136 BPM)
func _synth_bgm_battle() -> AudioStreamWAV:
	return _synth_bgm_mixed()


# 14. BGM Boss: Drachen-Zorn (32 beats - 150 BPM, ~12.8s loop)
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
		[164.81, 196.0, 246.94], # Em
		[130.81, 164.81, 196.0], # C
		[146.83, 185.0, 220.0],  # D
		[123.47, 155.56, 185.0], # B7
		[164.81, 196.0, 246.94], # Em
		[220.00, 261.63, 329.63],# Am
		[123.47, 155.56, 185.0], # B7
		[164.81, 196.0, 246.94]  # Em
	]

	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var current_beat: float = t / beat_dur
		var bar_idx: int = mini(int(current_beat / 4.0), 7)
		var chord: Array = boss_chords[bar_idx]
		var total_sample: float = 0.0

		# Staccato Brass Stabs
		var stab_t: float = fmod(t, beat_dur * 0.5)
		var stab_env: float = exp(-stab_t * 12.0)
		for f in chord:
			var brass: float = sin(stab_t * f * 2.0 * TAU) + 0.5 * sin(stab_t * f * 4.0 * TAU)
			total_sample += brass * stab_env * 0.12

		# Fast Arp
		var sixteenth_idx: int = int(current_beat * 4.0) % 4
		var arp_f: float = chord[sixteenth_idx % chord.size()] * 2.0
		var arp_t: float = fmod(t, beat_dur * 0.25)
		var arp_wave: float = sin(arp_t * arp_f * TAU)
		total_sample += arp_wave * exp(-arp_t * 16.0) * 0.2

		# Heavy War Drum / Taiko Pattern
		var beat_fraction: float = fmod(current_beat, 1.0)
		if beat_fraction < 0.22:
			var drum_t: float = beat_fraction * beat_dur
			var drum_f: float = lerpf(110.0, 35.0, drum_t / 0.18)
			var sub_kick: float = sin(drum_t * drum_f * TAU) * exp(-drum_t * 16.0)
			total_sample += sub_kick * 0.55

		if (bar_idx == 3 or bar_idx == 7) and int(current_beat) % 2 == 1 and beat_fraction < 0.15:
			var tom_t: float = beat_fraction * beat_dur
			total_sample += sin(tom_t * 180.0 * TAU) * exp(-tom_t * 20.0) * 0.35

		samples[i] = total_sample * 0.85

	return _create_wav_stream(samples, true)


# 15. Victory Fanfare (Celebratory brass fanfare with chimes)
func _synth_jingle_victory() -> AudioStreamWAV:
	var duration: float = 3.6
	var num_samples: int = int(duration * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(num_samples)

	var fanfare_notes: Array[float] = [392.0, 523.25, 659.25, 783.99, 1046.50]
	var fanfare_times: Array[float] = [0.0, 0.22, 0.44, 0.66, 1.0]
	var fanfare_durations: Array[float] = [0.2, 0.2, 0.2, 0.32, 2.5]

	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var total_sample: float = 0.0

		for n in range(fanfare_notes.size()):
			var start_t: float = fanfare_times[n]
			var note_dur: float = fanfare_durations[n]
			if t >= start_t and t < start_t + note_dur:
				var note_t: float = t - start_t
				var f: float = fanfare_notes[n]
				var env: float = (note_t / 0.04) if note_t < 0.04 else exp(-(note_t - 0.04) * (1.8 if n == 4 else 3.5))
				var brass: float = sin(note_t * f * TAU) + 0.45 * sin(note_t * f * 2.0 * TAU) + 0.25 * sin(note_t * f * 3.0 * TAU)
				total_sample += brass * env * 0.4

		if t >= 1.0:
			var chime_t: float = t - 1.0
			var chime_f: float = 2093.0
			var shimmer: float = sin(chime_t * chime_f * TAU) * exp(-chime_t * 3.0) * 0.2
			total_sample += shimmer

		samples[i] = total_sample * 0.85

	return _create_wav_stream(samples, false)


# 16. Stage Clear Flourish (Short rewarding 1.8s jingle)
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
			total_sample = (sin(note_t * f * TAU) + 0.3 * sin(note_t * f * 2.0 * TAU)) * env * 0.45
		else:
			var hold_t: float = t - step_dur * 4.0
			var env: float = exp(-hold_t * 2.5)
			total_sample = sin(hold_t * 1046.50 * TAU) * env * 0.35 + sin(hold_t * 2093.0 * TAU) * env * 0.15

		samples[i] = total_sample * 0.85

	return _create_wav_stream(samples, false)


# 17. Game Over Lament (Respectful knight's rest horn - 2.5s)
func _synth_jingle_game_over() -> AudioStreamWAV:
	var duration: float = 2.5
	var num_samples: int = int(duration * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(num_samples)

	var notes: Array[float] = [440.0, 349.23, 293.66, 146.83] # A4 -> F4 -> D4 -> D3
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
				var horn: float = sin(note_t * f * TAU) + 0.35 * sin(note_t * f * 2.0 * TAU) + 0.15 * sin(note_t * f * 3.0 * TAU)
				total_sample += horn * env * 0.4

		samples[i] = total_sample * 0.85

	return _create_wav_stream(samples, false)
