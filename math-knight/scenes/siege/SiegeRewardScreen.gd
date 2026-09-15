class_name SiegeRewardScreen
extends Control

signal next_level_requested()
signal village_requested()
signal rewards_dismissed()

var _backdrop: ColorRect
var _panel: PanelContainer
var _panel_inner: Control
var _title: Label
var _subtitle: Label
var _stars_container: HBoxContainer
var _rewards_container: VBoxContainer
var _btn_container: HBoxContainer
var _btn_next: Button
var _btn_village: Button

var _gold_label: Label
var _wood_label: Label
var _bread_label: Label
var _soldiers_label: Label

var _confetti: CPUParticles2D

var _shake_tween: Tween
var _current_data: Dictionary

# Values used for count-up animations
var _current_gold: int = 0
var _current_wood: int = 0
var _current_bread: int = 0

func _init() -> void:
	name = "SiegeRewardScreen"
	# Use FULL_RECT so the node itself covers the parent properly
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()

# The CanvasLayer that owns all visible UI — ensures full-screen coverage on Android
var _canvas_layer: CanvasLayer
# Root control inside the CanvasLayer
var _canvas_root: Control

func _build_ui() -> void:
	# ── CanvasLayer wrapper (layer 110 = above game + result overlay at 100) ──
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 110
	add_child(_canvas_layer)

	_canvas_root = Control.new()
	_canvas_root.set_anchors_preset(PRESET_FULL_RECT)
	_canvas_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas_layer.add_child(_canvas_root)

	# 1. Dark Backdrop (full-screen, blocks input so nothing below is clickable)
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.02, 0.02, 0.05, 0.0) # Will fade to 0.92
	_backdrop.set_anchors_preset(PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas_root.add_child(_backdrop)

	# 2. Centre container — always centres its child regardless of screen size
	var center_container := CenterContainer.new()
	center_container.set_anchors_preset(PRESET_FULL_RECT)
	center_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas_root.add_child(center_container)

	# 3. Main Panel
	_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.18, 0.98)
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.border_color = Color(0.8, 0.6, 0.2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	_panel.add_theme_stylebox_override("panel", style)

	_panel.custom_minimum_size = Vector2(400, 300)
	# pivot_offset at half the minimum size so scale animation expands from centre
	_panel.pivot_offset = Vector2(200, 150)
	_panel.scale = Vector2.ZERO # Starts hidden
	center_container.add_child(_panel)
	
	# Inner layout for the panel
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	_panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)
	
	# Title
	_title = Label.new()
	_title.text = "BURG EROBERT!"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 24)
	_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_title.add_theme_constant_override("outline_size", 4)
	_title.modulate = Color(1, 1, 1, 0) # Starts hidden
	vbox.add_child(_title)
	
	# Subtitle
	_subtitle = Label.new()
	_subtitle.text = ""
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_size_override("font_size", 14)
	_subtitle.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_subtitle.modulate = Color(1, 1, 1, 0)
	vbox.add_child(_subtitle)
	
	# Stars Container
	_stars_container = HBoxContainer.new()
	_stars_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_stars_container.add_theme_constant_override("separation", 8)
	vbox.add_child(_stars_container)
	
	# Rewards Container
	_rewards_container = VBoxContainer.new()
	_rewards_container.add_theme_constant_override("separation", 8)
	vbox.add_child(_rewards_container)
	
	# Spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)
	
	# Buttons Container
	_btn_container = HBoxContainer.new()
	_btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_btn_container.add_theme_constant_override("separation", 16)
	_btn_container.modulate = Color(1, 1, 1, 0) # Starts hidden
	vbox.add_child(_btn_container)
	
	_btn_next = Button.new()
	_btn_next.text = "Nächste Burg →"
	_btn_next.pressed.connect(func(): next_level_requested.emit())
	_btn_container.add_child(_btn_next)
	
	_btn_village = Button.new()
	_btn_village.text = "Zum Dorf 🏰"
	_btn_village.pressed.connect(func(): village_requested.emit())
	_btn_container.add_child(_btn_village)
	
	# Confetti Particles
	_confetti = CPUParticles2D.new()
	_confetti.position = Vector2(320, 0) # Top center of 640x360
	_confetti.emitting = false
	_confetti.amount = 100
	_confetti.lifetime = 2.0
	_confetti.one_shot = true
	_confetti.explosiveness = 0.8
	_confetti.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_confetti.emission_rect_extents = Vector2(320, 10)
	_confetti.direction = Vector2(0, 1)
	_confetti.spread = 45.0
	_confetti.gravity = Vector2(0, 200)
	_confetti.initial_velocity_min = 50.0
	_confetti.initial_velocity_max = 150.0
	
	var colors = PackedColorArray([Color(1, 0.8, 0.2), Color(1, 0.5, 0.1), Color(0.9, 0.9, 0.2)])
	# In a real project, we would use a color ramp or random colors.
	_confetti.color = Color(1, 0.8, 0.2) 
	_canvas_root.add_child(_confetti)

func _create_reward_row(icon_text: String, start_text: String) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	row.modulate = Color(1, 1, 1, 0)
	row.position.x = 100 # Starts off-center for slide-in
	
	var icon = Label.new()
	icon.text = icon_text
	icon.add_theme_font_size_override("font_size", 20)
	row.add_child(icon)
	
	var value_label = Label.new()
	value_label.text = start_text
	value_label.add_theme_font_size_override("font_size", 18)
	value_label.custom_minimum_size.x = 150
	row.add_child(value_label)
	
	_rewards_container.add_child(row)
	return row

func show_rewards(data: Dictionary) -> void:
	_current_data = data
	_subtitle.text = data.get("castle_name", "Unbekannte Burg")
	
	_play_jingle("victory")
	
	# Clear old nodes
	for child in _stars_container.get_children():
		child.queue_free()
	for child in _rewards_container.get_children():
		child.queue_free()
		
	# Setup Stars
	var total_stars = clamp(data.get("stars", 0), 0, 3)
	for i in range(3):
		var star = Label.new()
		star.text = "⭐" if i < total_stars else "☆"
		star.add_theme_font_size_override("font_size", 28)
		star.pivot_offset = Vector2(14, 14)
		star.scale = Vector2.ZERO
		_stars_container.add_child(star)
		
	# Setup Reward Rows
	var gold_row = _create_reward_row("🪙", "0")
	_gold_label = gold_row.get_child(1)
	
	var wood_row = _create_reward_row("🪵", "0")
	_wood_label = wood_row.get_child(1)
	
	var bread_row = _create_reward_row("🥖", "0")
	_bread_label = bread_row.get_child(1)
	
	var soldiers_row = _create_reward_row("⚔️", "NEUE REKRUTEN! +0")
	_soldiers_label = soldiers_row.get_child(1)
	
	# Start Animation Sequence
	_animate_sequence()

func _animate_sequence() -> void:
	var t = create_tween()
	
	# 1. Dark backdrop fade in
	t.tween_property(_backdrop, "color", Color(0.02, 0.02, 0.05, 0.92), 0.5)
	
	# 2. Main panel scale in
	t.parallel().tween_property(_panel, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Title crashes in
	_title.position.y -= 50
	t.tween_property(_title, "modulate", Color.WHITE, 0.3)
	t.parallel().tween_property(_title, "position:y", _title.position.y + 50, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	
	# 3. Subtitle fade in
	t.tween_property(_subtitle, "modulate", Color.WHITE, 0.3)
	
	# 4. Star rating
	t.tween_callback(_start_screen_shake)
	for i in range(_stars_container.get_child_count()):
		var star = _stars_container.get_child(i)
		t.tween_property(star, "scale", Vector2(1.5, 1.5), 0.15)
		t.tween_property(star, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_SPRING)
		t.tween_interval(0.15) # Wait before next star
		
	# 5. Reward chests cascade
	var rows = _rewards_container.get_children()
	for i in range(rows.size()):
		var row = rows[i]
		# "coin" is a real SFX; for the final soldiers row play the victory jingle
		if i < 3:
			t.tween_callback(func(): _play_sfx("coin"))
		t.tween_property(row, "modulate", Color.WHITE, 0.2)
		t.parallel().tween_property(row, "position:x", 0.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_callback(_start_count_up.bind(i))
		t.tween_interval(0.5)
		
	# Confetti & Buttons
	t.tween_callback(func(): _confetti.emitting = true)
	t.tween_property(_btn_container, "modulate", Color.WHITE, 0.4)
	
func _start_count_up(index: int) -> void:
	var t = create_tween()
	var dur = 0.6
	
	if index == 0:
		t.tween_method(func(val): _gold_label.text = str(val), 0, _current_data.get("gold", 0), dur)
	elif index == 1:
		t.tween_method(func(val): _wood_label.text = str(val), 0, _current_data.get("wood", 0), dur)
	elif index == 2:
		t.tween_method(func(val): _bread_label.text = str(val), 0, _current_data.get("bread", 0), dur)
	elif index == 3:
		t.tween_method(func(val): _soldiers_label.text = "NEUE REKRUTEN! +" + str(val), 0, _current_data.get("soldiers_bonus", 0), dur)
		
	var row = _rewards_container.get_child(index)
	var rt = create_tween()
	rt.tween_property(row, "scale", Vector2(1.1, 1.1), 0.1)
	rt.tween_property(row, "scale", Vector2.ONE, 0.2)

func _start_screen_shake() -> void:
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
		
	_shake_tween = create_tween()
	var base_pos = _panel.position
	
	for i in range(5):
		var offset = Vector2(randf_range(-5, 5), randf_range(-5, 5))
		_shake_tween.tween_property(_panel, "position", base_pos + offset, 0.05)
		_shake_tween.tween_property(_panel, "position", base_pos, 0.05)

func _play_sfx(sfx_name: String) -> void:
	if has_node("/root/AudioManager"):
		var am = get_node("/root/AudioManager")
		if am.has_method("play_sfx"):
			am.play_sfx(sfx_name)

func _play_jingle(jingle_name: String) -> void:
	if has_node("/root/AudioManager"):
		var am = get_node("/root/AudioManager")
		if am.has_method("play_jingle"):
			am.play_jingle(jingle_name)
