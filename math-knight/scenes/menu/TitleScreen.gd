class_name TitleScreen
extends Control

@onready var title_label: Label = $MainContainer/VBox/TitleSection/TitleLabel
@onready var subtitle_label: Label = $MainContainer/VBox/TitleSection/SubtitleLabel
@onready var title_section: VBoxContainer = $MainContainer/VBox/TitleSection
@onready var knight_section: Control = $MainContainer/VBox/ContentRow/KnightSection
@onready var knight_dais: Control = $MainContainer/VBox/ContentRow/KnightSection/KnightDais
@onready var ascii_knight: AsciiEntity = $MainContainer/VBox/ContentRow/KnightSection/KnightDais/AsciiKnight
@onready var pedestal: Control = $MainContainer/VBox/ContentRow/KnightSection/KnightDais/Pedestal
@onready var new_game_btn: Button = $MainContainer/VBox/ContentRow/ButtonSection/NewGameBtn
@onready var training_btn: Button = $MainContainer/VBox/ContentRow/ButtonSection/TrainingBtn
@onready var equip_btn: Button = $MainContainer/VBox/ContentRow/ButtonSection/BottomRow/EquipBtn
@onready var settings_btn: Button = $MainContainer/VBox/ContentRow/ButtonSection/BottomRow/SettingsBtn
@onready var forge_btn: Button = $MainContainer/VBox/ContentRow/ButtonSection/MiniGamesRow/ForgeBtn
@onready var lumber_btn: Button = $MainContainer/VBox/ContentRow/ButtonSection/MiniGamesRow/LumberBtn
@onready var level_badge: Label = $MainContainer/VBox/TopBar/LevelBadge
@onready var diamond_label: Label = $MainContainer/VBox/TopBar/DiamondLabel

var buttons: Array[Button] = []

# 360° Rotation system (South -> West -> North -> East)
var _rotation_directions: Array[String] = ["south", "west", "north", "east"]
var _current_dir_index: int = 0
var _rotation_timer: float = 0.0
var _rotation_interval: float = 0.85 # seconds per direction
var _rotation_textures: Dictionary = {}

var _is_dragging: bool = false
var _drag_start_x: float = 0.0

# --- Binary & Math Title State ---
const TARGET_TITLE: String = "MATH KNIGHT"
const BASE_SUBTITLE: String = "ARITHMETISCHES RITTER-ABENTEUER"
const CIPHER_CHARS: Array[String] = [
	"0", "1", "0", "1", "1", "0",
	"+", "-", "*", "/", "%", "=", "#", "X", "<", ">",
	"7", "4", "2", "8", "9", "3", "!", "?"
]

# Button text & color mapping
var _btn_config: Dictionary = {
	"new_game": {"text": "⚔ NEUES SPIEL", "color": Color("#f7c52a"), "size": 13},
	"training": {"text": "⚡ TRAINING", "color": Color("#29b6f6"), "size": 11},
	"forge": {"text": "🔨 SCHMIEDE", "color": Color("#ff9800"), "size": 9},
	"lumber": {"text": "🪓 HOLZPLATZ", "color": Color("#8bc34a"), "size": 9},
	"equip": {"text": "🎒 AUSRÜSTUNG", "color": Color("#ab47bc"), "size": 9},
	"settings": {"text": "⬆ HELD & TALENTE", "color": Color("#26a69a"), "size": 9}
}

var _decoded_indices: Array[bool] = []
var _is_decoding: bool = false
var _decode_progress: float = 0.0
var _title_orig_pos: Vector2 = Vector2.ZERO
var _rune_angle: float = 0.0

# Subtle Title Jitter & Flicker Timers
var _flicker_timer: float = 0.0
var _flicker_interval: float = 0.10 # Gentle, readable character morphing
var _burst_glitch_timer: float = 0.0
var _burst_glitch_duration: float = 0.0
var _subtitle_binary_timer: float = 0.0
var _is_hovering_title: bool = false

# Visual nodes
var _rune_ring_node: Control
var _title_settings: LabelSettings
var _button_glitch_tweens: Dictionary = {}

func _ready() -> void:
	buttons = [new_game_btn, training_btn, forge_btn, lumber_btn, equip_btn, settings_btn]
	
	_decoded_indices.resize(TARGET_TITLE.length())
	_decoded_indices.fill(false)
	
	if title_label and title_label.label_settings:
		_title_settings = title_label.label_settings.duplicate()
		title_label.label_settings = _title_settings
		
	_setup_rune_ring()
	_load_rotation_textures()
	_setup_styles()
	_setup_signals()
	_setup_button_juice()
	_update_header()
	_update_knight_direction()
	
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_music("title")
	
	# Wait for layout to finish so positions are valid
	await get_tree().process_frame
	
	# Initial state for animations
	if title_label:
		_title_orig_pos = title_label.position
		title_label.scale = Vector2.ZERO
		title_label.pivot_offset = title_label.size / 2.0
		title_label.mouse_filter = Control.MOUSE_FILTER_STOP
		title_label.gui_input.connect(_on_title_gui_input)
		title_label.mouse_entered.connect(_on_title_mouse_entered)
		title_label.mouse_exited.connect(_on_title_mouse_exited)
		
	if subtitle_label:
		subtitle_label.modulate.a = 0.0
	
	for btn in buttons:
		if btn:
			btn.set_meta("orig_x", btn.position.x)
			btn.position.x += 240
			btn.modulate.a = 0.0
		
	# Start entrance animations & cipher scramble
	if ascii_knight and has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		ascii_knight.apply_cosmetics(sm.equipped_cosmetics)

	_play_entrance_animation()
	_play_pedestal_bobbing()
	_start_title_cipher()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3:
			if has_node("/root/SaveManager"):
				get_node("/root/SaveManager").toggle_render_mode_3d_shader()


func _setup_rune_ring() -> void:
	pass


func _on_draw_rune_ring() -> void:
	pass


func _load_rotation_textures() -> void:
	var state_dir = "Idle"
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		var equipped_sword = sm.equipped_cosmetics.get("sword", "sword_basic")
		match equipped_sword:
			"sword_flame": state_dir = "Flame_Sword"
			"sword_pan": state_dir = "Frying_Pan"
			"sword_lightsaber": state_dir = "Lightsaber"
			_: state_dir = "Idle"

	for d in _rotation_directions:
		var path = "res://assets/sprites/knight_comic/%s/rotations/%s.png" % [state_dir, d]
		if not ResourceLoader.exists(path):
			path = "res://assets/sprites/knight_comic/Idle/rotations/%s.png" % d
		if ResourceLoader.exists(path):
			_rotation_textures[d] = load(path)


func _process(delta: float) -> void:
	# Knight Auto-Rotation
	if not _is_dragging:
		_rotation_timer += delta
		if _rotation_timer >= _rotation_interval:
			_rotation_timer = 0.0
			_current_dir_index = (_current_dir_index + 1) % _rotation_directions.size()
			_update_knight_direction()

	# Rotating Rune Ring
	_rune_angle += delta * 1.2
	if _rune_ring_node:
		_rune_ring_node.queue_redraw()

	var t: float = Time.get_ticks_msec() * 0.001

	# --- Title Movement & Gentle Positional Shake ---
	if title_label:
		title_label.pivot_offset = title_label.size / 2.0
		var float_y: float = sin(t * 2.8) * 3.0
		var breath_s: float = 1.0 + sin(t * 1.8) * 0.025
		
		var jitter_offset: Vector2 = Vector2.ZERO
		if _burst_glitch_duration > 0.0 or _is_hovering_title:
			jitter_offset = Vector2(randf_range(-2.6, 2.6), randf_range(-1.6, 1.6))
			breath_s += randf_range(-0.04, 0.04)
			if randf() < 0.25:
				title_label.modulate.a = randf_range(0.85, 1.0)
			else:
				title_label.modulate.a = 1.0
		elif randf() < 0.08:
			jitter_offset = Vector2(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5))
			title_label.modulate.a = 1.0
		else:
			title_label.modulate.a = 1.0
			
		title_label.position = _title_orig_pos + Vector2(0, float_y) + jitter_offset
		if not _is_decoding:
			title_label.scale = Vector2(breath_s, breath_s)

	# --- Character Flicker / Jitter ---
	_flicker_timer += delta
	var current_flicker_interval = 0.05 if (_burst_glitch_duration > 0.0 or _is_hovering_title) else _flicker_interval
	if _flicker_timer >= current_flicker_interval:
		_flicker_timer = 0.0
		if not _is_decoding:
			_update_live_title_jitter()

	# --- Burst Glitch Management (Occurs every 3.0 - 5.0 seconds) ---
	if _burst_glitch_duration > 0.0:
		_burst_glitch_duration -= delta
	else:
		_burst_glitch_timer += delta
		if _burst_glitch_timer >= randf_range(3.0, 5.0):
			_burst_glitch_timer = 0.0
			_burst_glitch_duration = randf_range(0.24, 0.38)

	# --- Subtitle Binary Stream Ticker ---
	_subtitle_binary_timer += delta
	var current_subtitle_interval = 0.06 if (_burst_glitch_duration > 0.0) else 0.15
	if _subtitle_binary_timer >= current_subtitle_interval:
		_subtitle_binary_timer = 0.0
		_update_subtitle_ticker()

	# Handle Initial/On-demand Decoding Scramble
	if _is_decoding:
		_update_cipher_decode(delta)


func _update_live_title_jitter() -> void:
	if not title_label:
		return
		
	var is_burst: bool = (_burst_glitch_duration > 0.0) or _is_hovering_title
	var glitch_count: int = randi_range(2, 3) if is_burst else (1 if randf() < 0.4 else 0)
	
	if glitch_count == 0:
		title_label.text = TARGET_TITLE
		if _title_settings:
			_title_settings.font_color = Color(1.0, 0.90, 0.28, 1.0)
			_title_settings.shadow_color = Color(0, 0, 0, 0.95)
			_title_settings.shadow_offset = Vector2(3, 3)
		return

	var chars: PackedStringArray = []
	for i in range(TARGET_TITLE.length()):
		chars.append(TARGET_TITLE[i])
		
	for g in range(glitch_count):
		var idx: int = randi() % TARGET_TITLE.length()
		if TARGET_TITLE[idx] != " ":
			chars[idx] = CIPHER_CHARS[randi() % CIPHER_CHARS.size()]
			
	var result_str: String = "".join(chars)
	title_label.text = result_str
	
	# Warm gold / amber styling with punchy glitch strobe flashes
	if _title_settings:
		if is_burst:
			var strobe_mode = randi() % 3
			match strobe_mode:
				0:
					_title_settings.font_color = Color(1.0, 1.0, 1.0, 1.0)
					_title_settings.shadow_color = Color(0.95, 0.6, 0.1, 0.95)
					_title_settings.shadow_offset = Vector2(randf_range(1.0, 4.5), randf_range(1.0, 4.5))
				1:
					_title_settings.font_color = Color(1.0, 0.96, 0.5, 1.0)
					_title_settings.shadow_color = Color(0.85, 0.45, 0.0, 0.95)
					_title_settings.shadow_offset = Vector2(randf_range(2.0, 4.0), randf_range(2.0, 4.0))
				2:
					# Subtle rare cyan glint without harsh saturation
					_title_settings.font_color = Color(0.8, 0.98, 1.0, 1.0)
					_title_settings.shadow_color = Color(0.1, 0.5, 0.7, 0.85)
					_title_settings.shadow_offset = Vector2(randf_range(1.5, 3.5), randf_range(1.5, 3.5))
		else:
			_title_settings.font_color = Color(1.0, 0.90, 0.28, 1.0)
			_title_settings.shadow_color = Color(0, 0, 0, 0.95)
			_title_settings.shadow_offset = Vector2(3, 3)


func _update_subtitle_ticker() -> void:
	if not subtitle_label:
		return
	var bin1: String = ""
	var bin2: String = ""
	for i in range(4):
		bin1 += "1" if randf() > 0.5 else "0"
		bin2 += "1" if randf() > 0.5 else "0"
	subtitle_label.text = "[ %s ] %s [ %s ]" % [bin1, BASE_SUBTITLE, bin2]


func _start_title_cipher() -> void:
	_is_decoding = true
	_decode_progress = 0.0
	_decoded_indices.fill(false)


func _update_cipher_decode(delta: float) -> void:
	_decode_progress += delta * 2.2
	var chars_to_lock: int = int(_decode_progress * TARGET_TITLE.length())
	
	for i in range(min(chars_to_lock, TARGET_TITLE.length())):
		_decoded_indices[i] = true

	var display_str: String = ""
	for i in range(TARGET_TITLE.length()):
		if TARGET_TITLE[i] == " ":
			display_str += " "
		elif _decoded_indices[i]:
			display_str += TARGET_TITLE[i]
		else:
			display_str += CIPHER_CHARS[randi() % CIPHER_CHARS.size()]

	if title_label:
		title_label.text = display_str

	if chars_to_lock >= TARGET_TITLE.length():
		_is_decoding = false
		if title_label:
			title_label.text = TARGET_TITLE


func _on_title_mouse_entered() -> void:
	_is_hovering_title = true
	_burst_glitch_duration = 0.6


func _on_title_mouse_exited() -> void:
	_is_hovering_title = false


func _on_title_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx("click")
		_start_title_cipher()
		_burst_glitch_duration = 0.8
		var tween = create_tween()
		tween.tween_property(title_label, "scale", Vector2(1.2, 1.2), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(title_label, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)



func _setup_styles() -> void:
	# Cyber-Fantasy Pixel Buttons
	_style_cyber_button(new_game_btn, _btn_config["new_game"]["color"], _btn_config["new_game"]["size"], _btn_config["new_game"]["text"])
	_style_cyber_button(training_btn, _btn_config["training"]["color"], _btn_config["training"]["size"], _btn_config["training"]["text"])
	_style_cyber_button(equip_btn, _btn_config["equip"]["color"], _btn_config["equip"]["size"], _btn_config["equip"]["text"])
	_style_cyber_button(settings_btn, _btn_config["settings"]["color"], _btn_config["settings"]["size"], _btn_config["settings"]["text"])
	
	# Top bar badges
	_style_top_badge(level_badge, Color(1.0, 0.88, 0.35))
	_style_top_badge(diamond_label, Color(0.35, 0.9, 1.0))


func _style_cyber_button(btn: Button, accent_color: Color, font_sz: int, default_text: String) -> void:
	if not btn:
		return
		
	var silk_font = load("res://assets/fonts/Silkscreen-Bold.ttf")
	if silk_font:
		btn.add_theme_font_override("font", silk_font)
		
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.07, 0.05, 0.13, 0.88)
	style_normal.corner_radius_top_left = 6
	style_normal.corner_radius_top_right = 6
	style_normal.corner_radius_bottom_right = 6
	style_normal.corner_radius_bottom_left = 6
	style_normal.border_width_left = 2
	style_normal.border_width_top = 2
	style_normal.border_width_right = 2
	style_normal.border_width_bottom = 4
	style_normal.border_color = accent_color
	style_normal.shadow_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.28)
	style_normal.shadow_size = 5
	style_normal.shadow_offset = Vector2(0, 2)
	
	var style_hover = style_normal.duplicate()
	style_hover.bg_color = Color(accent_color.r * 0.22, accent_color.g * 0.22, accent_color.b * 0.22, 0.95)
	style_hover.border_color = accent_color.lerp(Color.WHITE, 0.45)
	style_hover.shadow_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.6)
	style_hover.shadow_size = 8
	style_hover.shadow_offset = Vector2(0, 3)
	
	var style_pressed = style_normal.duplicate()
	style_pressed.bg_color = Color(accent_color.r * 0.15, accent_color.g * 0.15, accent_color.b * 0.15, 0.98)
	style_pressed.border_width_top = 3
	style_pressed.border_width_bottom = 1
	style_pressed.shadow_size = 1
	style_pressed.shadow_offset = Vector2(0, 1)
	
	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	btn.add_theme_stylebox_override("focus", style_hover)
	
	btn.add_theme_font_size_override("font_size", font_sz)
	btn.add_theme_constant_override("outline_size", 2)
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	btn.add_theme_color_override("font_color", accent_color.lerp(Color.WHITE, 0.75))
	btn.text = default_text


func _style_top_badge(lbl: Label, accent_color: Color) -> void:
	if not lbl:
		return
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.12, 0.85)
	style.border_color = accent_color * 0.8
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	lbl.add_theme_stylebox_override("normal", style)


func _trigger_button_text_glitch(btn: Button, target_text: String, accent_color: Color) -> void:
	if not btn:
		return
		
	if _button_glitch_tweens.has(btn) and is_instance_valid(_button_glitch_tweens[btn]):
		_button_glitch_tweens[btn].kill()
		
	var tween = create_tween()
	_button_glitch_tweens[btn] = tween
	
	var total_steps: int = 7 # Duration ~ 0.28s total
	for step in range(total_steps):
		tween.tween_callback(func():
			if not is_instance_valid(btn):
				return
			if step == total_steps - 1:
				btn.text = target_text
				btn.add_theme_color_override("font_color", accent_color.lerp(Color.WHITE, 0.75))
			else:
				var scrambled = ""
				var lock_count = int((float(step) / float(total_steps - 1)) * target_text.length())
				for i in range(target_text.length()):
					var ch = target_text[i]
					if ch == " " or ch == "⚔" or ch == "⚡" or ch == "🎒" or ch == "⬆":
						scrambled += ch
					elif i < lock_count:
						scrambled += ch
					else:
						scrambled += CIPHER_CHARS[randi() % CIPHER_CHARS.size()]
				btn.text = scrambled
				btn.add_theme_color_override("font_color", Color.WHITE if randf() < 0.5 else accent_color.lerp(Color.WHITE, 0.9))
		)
		tween.tween_interval(0.04)


func _setup_button_juice() -> void:
	_attach_button_behavior(new_game_btn, _btn_config["new_game"]["text"], _btn_config["new_game"]["color"])
	_attach_button_behavior(training_btn, _btn_config["training"]["text"], _btn_config["training"]["color"])
	_attach_button_behavior(forge_btn, _btn_config["forge"]["text"], _btn_config["forge"]["color"])
	_attach_button_behavior(lumber_btn, _btn_config["lumber"]["text"], _btn_config["lumber"]["color"])
	_attach_button_behavior(equip_btn, _btn_config["equip"]["text"], _btn_config["equip"]["color"])
	_attach_button_behavior(settings_btn, _btn_config["settings"]["text"], _btn_config["settings"]["color"])


func _attach_button_behavior(btn: Button, default_text: String, accent_color: Color) -> void:
	if not btn:
		return
	btn.pivot_offset = btn.size / 2.0
	
	btn.mouse_entered.connect(func():
		btn.pivot_offset = btn.size / 2.0
		var tween = btn.create_tween()
		tween.tween_property(btn, "scale", Vector2(1.03, 1.03), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
		# Trigger glitch / cipher text scramble on hover
		_trigger_button_text_glitch(btn, default_text, accent_color)
		
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx("click")
	)
	
	btn.mouse_exited.connect(func():
		btn.pivot_offset = btn.size / 2.0
		var tween = btn.create_tween()
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		btn.text = default_text
		btn.add_theme_color_override("font_color", accent_color.lerp(Color.WHITE, 0.75))
	)
	
	btn.button_down.connect(func():
		btn.pivot_offset = btn.size / 2.0
		var tween = btn.create_tween()
		tween.tween_property(btn, "scale", Vector2(0.97, 0.97), 0.05)
	)
	
	btn.button_up.connect(func():
		btn.pivot_offset = btn.size / 2.0
		var tween = btn.create_tween()
		tween.tween_property(btn, "scale", Vector2(1.03, 1.03), 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	)


func _setup_signals() -> void:
	if new_game_btn:
		new_game_btn.pressed.connect(func():
			if has_node("/root/AudioManager"): get_node("/root/AudioManager").play_sfx("click")
			_on_new_game_pressed()
		)
	if training_btn:
		training_btn.pressed.connect(func():
			if has_node("/root/AudioManager"): get_node("/root/AudioManager").play_sfx("click")
			_on_training_pressed()
		)
	if forge_btn:
		forge_btn.pressed.connect(func():
			if has_node("/root/AudioManager"): get_node("/root/AudioManager").play_sfx("click")
			get_tree().change_scene_to_file("res://scenes/forge/BlacksmithForge.tscn")
		)
	if lumber_btn:
		lumber_btn.pressed.connect(func():
			if has_node("/root/AudioManager"): get_node("/root/AudioManager").play_sfx("click")
			get_tree().change_scene_to_file("res://scenes/lumber/LumberYard.tscn")
		)
	if equip_btn:
		equip_btn.pressed.connect(func():
			if has_node("/root/AudioManager"): get_node("/root/AudioManager").play_sfx("click")
			get_tree().change_scene_to_file("res://scenes/menu/CosmeticInventory.tscn")
		)
	if settings_btn:
		settings_btn.pressed.connect(func():
			if has_node("/root/AudioManager"): get_node("/root/AudioManager").play_sfx("click")
			get_tree().change_scene_to_file("res://scenes/menu/LevelUpScreen.tscn")
		)
	if level_badge:
		level_badge.mouse_filter = Control.MOUSE_FILTER_STOP
		level_badge.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				if has_node("/root/AudioManager"): get_node("/root/AudioManager").play_sfx("click")
				get_tree().change_scene_to_file("res://scenes/menu/LevelUpScreen.tscn")
		)

	# Interactive Touch / Drag Rotation on Knight
	if knight_dais:
		knight_dais.gui_input.connect(_on_knight_dais_gui_input)


func _on_knight_dais_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_is_dragging = true
				_drag_start_x = event.position.x
				if ascii_knight:
					ascii_knight.play_slash()
				if has_node("/root/AudioManager"):
					get_node("/root/AudioManager").play_sfx("sword_slash")
			else:
				_is_dragging = false
	elif event is InputEventMouseMotion and _is_dragging:
		var diff_x = event.position.x - _drag_start_x
		if abs(diff_x) > 28.0:
			if diff_x > 0:
				_current_dir_index = (_current_dir_index - 1 + _rotation_directions.size()) % _rotation_directions.size()
			else:
				_current_dir_index = (_current_dir_index + 1) % _rotation_directions.size()
			_update_knight_direction()
			_drag_start_x = event.position.x


func _update_knight_direction() -> void:
	if ascii_knight:
		# Flip facing direction based on rotation cycle
		var dir_name = _rotation_directions[_current_dir_index]
		if dir_name == "east":
			ascii_knight.facing_direction = 1.0
			ascii_knight.rotation_yaw = 0.0
		elif dir_name == "west":
			ascii_knight.facing_direction = -1.0
			ascii_knight.rotation_yaw = 0.0
		elif dir_name == "south":
			ascii_knight.facing_direction = -1.0
			ascii_knight.rotation_yaw = 0.0
		elif dir_name == "north":
			ascii_knight.facing_direction = 1.0
			ascii_knight.rotation_yaw = 0.0
		ascii_knight.rotation_pitch = 0.0


func _update_header() -> void:
	var lv: int = 1
	var diamonds: int = 0
	var pts: int = 0
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		lv = sm.knight_level
		diamonds = sm.diamonds
		pts = sm.knight_stat_points
	
	if level_badge:
		level_badge.text = "Lv. " + str(lv)
	if diamond_label:
		diamond_label.text = "💎 " + str(diamonds)
		var tween = create_tween().set_loops()
		diamond_label.pivot_offset = diamond_label.size / 2.0
		tween.tween_property(diamond_label, "scale", Vector2(1.08, 1.08), 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(diamond_label, "scale", Vector2(1.0, 1.0), 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	if settings_btn:
		if pts > 0:
			var pts_txt = "⬆ HELD (! " + str(pts) + " Pkt)"
			_btn_config["settings"]["text"] = pts_txt
			settings_btn.text = pts_txt
			settings_btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.3))
		else:
			var normal_txt = "⬆ HELD & TALENTE"
			_btn_config["settings"]["text"] = normal_txt
			settings_btn.text = normal_txt
			settings_btn.add_theme_color_override("font_color", Color("#26a69a").lerp(Color.WHITE, 0.75))


func _play_entrance_animation() -> void:
	var tween = create_tween()
	tween.set_parallel(false)
	
	# Title pop & bounce
	if title_label:
		tween.tween_property(title_label, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	if subtitle_label:
		tween.tween_property(subtitle_label, "modulate:a", 1.0, 0.25)
	
	# Button slide in
	var btn_tween = create_tween()
	btn_tween.set_parallel(true)
	var delay = 0.0
	for btn in buttons:
		if btn and btn.has_meta("orig_x"):
			var orig_x = btn.get_meta("orig_x")
			btn_tween.tween_property(btn, "position:x", orig_x, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
			btn_tween.tween_property(btn, "modulate:a", 1.0, 0.2).set_delay(delay)
			delay += 0.06
		
	# New game button subtle ambient gold glow pulse
	if new_game_btn:
		var pulse_tween = create_tween().set_loops()
		new_game_btn.pivot_offset = new_game_btn.size / 2.0
		pulse_tween.tween_property(new_game_btn, "scale", Vector2(1.02, 1.02), 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse_tween.tween_property(new_game_btn, "scale", Vector2(1.0, 1.0), 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _play_pedestal_bobbing() -> void:
	if knight_dais:
		var orig_y = knight_dais.position.y
		var tween = create_tween().set_loops()
		tween.tween_property(knight_dais, "position:y", orig_y - 4.0, 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(knight_dais, "position:y", orig_y, 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_new_game_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/LoadingScreen.tscn")


func _on_training_pressed() -> void:
	if has_node("/root/RunManager"):
		var rm = get_node("/root/RunManager")
		if rm.is_run_active:
			rm.end_run(false)
		rm.is_run_active = false
	get_tree().change_scene_to_file("res://scenes/menu/MainMenu.tscn")
