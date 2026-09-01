extends Control
## ═══════════════════════════════════════════════════════════════════════════
## BubbleTuningLab — Interactive Visual Playground for Bubble & Font Tuning
##
## Allows real-time live adjustment of:
##   • Font (PressStart2P vs Silkscreen-Bold vs Silkscreen-Regular)
##   • Font sizes (1-digit, 2-digit, 3-digit)
##   • Outline / Boldness thickness (0 = None, 1 = 4-way, 2 = 8-way, 3 = Heavy)
##   • Shadow offsets (X & Y)
##   • Exclusion zone factor
##   • Bubble radius
##   • Text color presets
##   • Live slicing and custom number input
## ═══════════════════════════════════════════════════════════════════════════

var bubble_scene: PackedScene = preload("res://scenes/ui/NumberBubble.tscn")
var trail_scene: PackedScene = preload("res://scenes/effects/SwipeTrail.tscn")
var slice_detector_script = preload("res://scenes/ui/SliceDetector.gd")

var font_press_start: Font
var font_silkscreen_bold: Font
var font_silkscreen_reg: Font

var active_bubbles: Array[NumberBubble] = []
var hero_bubble: NumberBubble = null

# UI Controls
@onready var bubble_container: Control = $LivePreviewArea/BubbleContainer
@onready var hero_bubble_pos: Marker2D = $LivePreviewArea/HeroBubblePos

@onready var opt_font: OptionButton = $ControlPanel/ScrollContainer/VBox/FontSection/OptFont
@onready var sld_size_1: HSlider = $ControlPanel/ScrollContainer/VBox/Size1Section/HSlider
@onready var lbl_size_1: Label = $ControlPanel/ScrollContainer/VBox/Size1Section/ValLabel
@onready var sld_size_2: HSlider = $ControlPanel/ScrollContainer/VBox/Size2Section/HSlider
@onready var lbl_size_2: Label = $ControlPanel/ScrollContainer/VBox/Size2Section/ValLabel
@onready var sld_size_3: HSlider = $ControlPanel/ScrollContainer/VBox/Size3Section/HSlider
@onready var lbl_size_3: Label = $ControlPanel/ScrollContainer/VBox/Size3Section/ValLabel

@onready var sld_outline: HSlider = $ControlPanel/ScrollContainer/VBox/OutlineSection/HSlider
@onready var lbl_outline: Label = $ControlPanel/ScrollContainer/VBox/OutlineSection/ValLabel
@onready var sld_shadow_x: HSlider = $ControlPanel/ScrollContainer/VBox/ShadowXSection/HSlider
@onready var lbl_shadow_x: Label = $ControlPanel/ScrollContainer/VBox/ShadowXSection/ValLabel
@onready var sld_shadow_y: HSlider = $ControlPanel/ScrollContainer/VBox/ShadowYSection/HSlider
@onready var lbl_shadow_y: Label = $ControlPanel/ScrollContainer/VBox/ShadowYSection/ValLabel

@onready var sld_exclusion: HSlider = $ControlPanel/ScrollContainer/VBox/ExclusionSection/HSlider
@onready var lbl_exclusion: Label = $ControlPanel/ScrollContainer/VBox/ExclusionSection/ValLabel
@onready var sld_radius: HSlider = $ControlPanel/ScrollContainer/VBox/RadiusSection/HSlider
@onready var lbl_radius: Label = $ControlPanel/ScrollContainer/VBox/RadiusSection/ValLabel

@onready var line_edit_custom: LineEdit = $ControlPanel/ScrollContainer/VBox/CustomInputSection/LineEdit
@onready var btn_respawn: Button = $ControlPanel/ScrollContainer/VBox/ActionButtons/BtnRespawn
@onready var btn_reset: Button = $ControlPanel/ScrollContainer/VBox/ActionButtons/BtnReset
@onready var btn_back: Button = $ControlPanel/ScrollContainer/VBox/ActionButtons/BtnBack

@onready var btn_col_yellow: Button = $ControlPanel/ScrollContainer/VBox/ColorSection/BtnYellow
@onready var btn_col_white: Button = $ControlPanel/ScrollContainer/VBox/ColorSection/BtnWhite
@onready var btn_col_amber: Button = $ControlPanel/ScrollContainer/VBox/ColorSection/BtnAmber
@onready var btn_col_cyan: Button = $ControlPanel/ScrollContainer/VBox/ColorSection/BtnCyan

@onready var code_readout: TextEdit = $ControlPanel/ScrollContainer/VBox/CodeSection/CodeReadout


func _ready() -> void:
	# Load font resources
	font_press_start = load("res://assets/fonts/PressStart2P-Regular.ttf")
	font_silkscreen_bold = load("res://assets/fonts/Silkscreen-Bold.ttf")
	font_silkscreen_reg = load("res://assets/fonts/Silkscreen-Regular.ttf")

	# Setup SliceDetector & SwipeTrail in preview area
	var trail = trail_scene.instantiate()
	$LivePreviewArea.add_child(trail)

	var detector: Node2D = Node2D.new()
	detector.set_script(slice_detector_script)
	detector.set("_trail", trail)
	$LivePreviewArea.add_child(detector)

	_setup_ui_options()
	_connect_events()
	_sync_ui_from_globals()
	_respawn_all_bubbles()
	_update_code_readout()


func _setup_ui_options() -> void:
	opt_font.clear()
	opt_font.add_item("PressStart2P (Original Pixel)", 0)
	opt_font.add_item("Silkscreen Bold (Clean Retro)", 1)
	opt_font.add_item("Silkscreen Regular", 2)
	opt_font.select(0)


func _connect_events() -> void:
	opt_font.item_selected.connect(_on_font_changed)
	
	sld_size_1.value_changed.connect(func(v):
		NumberBubble.global_font_size_1_digit = int(v)
		lbl_size_1.text = str(int(v)) + " px"
		_refresh_bubbles()
		_update_code_readout()
	)
	sld_size_2.value_changed.connect(func(v):
		NumberBubble.global_font_size_2_digit = int(v)
		lbl_size_2.text = str(int(v)) + " px"
		_refresh_bubbles()
		_update_code_readout()
	)
	sld_size_3.value_changed.connect(func(v):
		NumberBubble.global_font_size_3_digit = int(v)
		lbl_size_3.text = str(int(v)) + " px"
		_refresh_bubbles()
		_update_code_readout()
	)
	sld_outline.value_changed.connect(func(v):
		NumberBubble.global_outline_thickness = int(v)
		var names = ["0 (Aus)", "1 (4-fach)", "2 (8-fach Stark)", "3 (Extra Fetter Rand)"]
		lbl_outline.text = names[clamp(int(v), 0, names.size() - 1)]
		_refresh_bubbles()
		_update_code_readout()
	)
	sld_shadow_x.value_changed.connect(func(v):
		NumberBubble.global_shadow_offset.x = v
		lbl_shadow_x.text = str(snapped(v, 0.5)) + " px"
		_refresh_bubbles()
		_update_code_readout()
	)
	sld_shadow_y.value_changed.connect(func(v):
		NumberBubble.global_shadow_offset.y = v
		lbl_shadow_y.text = str(snapped(v, 0.5)) + " px"
		_refresh_bubbles()
		_update_code_readout()
	)
	sld_exclusion.value_changed.connect(func(v):
		NumberBubble.global_exclusion_factor = v
		lbl_exclusion.text = str(snapped(v, 0.05)) + "x"
		_rebuild_all_spheres()
		_update_code_readout()
	)
	sld_radius.value_changed.connect(func(v):
		for b in active_bubbles:
			if is_instance_valid(b):
				b.bubble_radius = v
				b._build_dense_sphere()
				b.queue_redraw()
		if hero_bubble and is_instance_valid(hero_bubble):
			hero_bubble.bubble_radius = v * 1.3
			hero_bubble._build_dense_sphere()
			hero_bubble.queue_redraw()
		lbl_radius.text = str(int(v)) + " px"
		_update_code_readout()
	)

	btn_col_yellow.pressed.connect(func():
		NumberBubble.global_text_color = Color("#fff176")
		_refresh_bubbles()
		_update_code_readout()
	)
	btn_col_white.pressed.connect(func():
		NumberBubble.global_text_color = Color("#ffffff")
		_refresh_bubbles()
		_update_code_readout()
	)
	btn_col_amber.pressed.connect(func():
		NumberBubble.global_text_color = Color("#ffd54f")
		_refresh_bubbles()
		_update_code_readout()
	)
	btn_col_cyan.pressed.connect(func():
		NumberBubble.global_text_color = Color("#00e5ff")
		_refresh_bubbles()
		_update_code_readout()
	)

	line_edit_custom.text_changed.connect(func(txt):
		if hero_bubble and is_instance_valid(hero_bubble):
			var val = txt.to_int() if txt.is_valid_int() else 49
			hero_bubble.value = val
			hero_bubble._target_val_str = txt if txt != "" else "49"
			hero_bubble._display_val_str = hero_bubble._target_val_str
			hero_bubble._build_dense_sphere()
			hero_bubble.queue_redraw()
	)

	btn_respawn.pressed.connect(_respawn_all_bubbles)
	btn_reset.pressed.connect(_reset_defaults)
	btn_back.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/menu/MainMenu.tscn")
	)


func _on_font_changed(idx: int) -> void:
	match idx:
		0: NumberBubble.global_font_override = font_press_start
		1: NumberBubble.global_font_override = font_silkscreen_bold
		2: NumberBubble.global_font_override = font_silkscreen_reg
	_refresh_bubbles()
	_update_code_readout()


func _sync_ui_from_globals() -> void:
	sld_size_1.value = NumberBubble.global_font_size_1_digit
	lbl_size_1.text = str(NumberBubble.global_font_size_1_digit) + " px"
	
	sld_size_2.value = NumberBubble.global_font_size_2_digit
	lbl_size_2.text = str(NumberBubble.global_font_size_2_digit) + " px"
	
	sld_size_3.value = NumberBubble.global_font_size_3_digit
	lbl_size_3.text = str(NumberBubble.global_font_size_3_digit) + " px"
	
	sld_outline.value = NumberBubble.global_outline_thickness
	var names = ["0 (Aus)", "1 (4-fach)", "2 (8-fach Stark)", "3 (Extra Fetter Rand)"]
	lbl_outline.text = names[clamp(NumberBubble.global_outline_thickness, 0, names.size() - 1)]
	
	sld_shadow_x.value = NumberBubble.global_shadow_offset.x
	lbl_shadow_x.text = str(NumberBubble.global_shadow_offset.x) + " px"
	
	sld_shadow_y.value = NumberBubble.global_shadow_offset.y
	lbl_shadow_y.text = str(NumberBubble.global_shadow_offset.y) + " px"
	
	sld_exclusion.value = NumberBubble.global_exclusion_factor
	lbl_exclusion.text = str(NumberBubble.global_exclusion_factor) + "x"
	
	sld_radius.value = 26
	lbl_radius.text = "26 px"


func _reset_defaults() -> void:
	NumberBubble.global_font_override = font_press_start
	NumberBubble.global_font_size_1_digit = 16
	NumberBubble.global_font_size_2_digit = 16
	NumberBubble.global_font_size_3_digit = 12
	NumberBubble.global_outline_thickness = 1
	NumberBubble.global_shadow_offset = Vector2(1.0, 1.0)
	NumberBubble.global_exclusion_factor = 1.15
	NumberBubble.global_text_color = Color("#fff176")
	opt_font.select(0)
	_sync_ui_from_globals()
	_respawn_all_bubbles()
	_update_code_readout()


func _respawn_all_bubbles() -> void:
	for b in active_bubbles:
		if is_instance_valid(b):
			b.queue_free()
	active_bubbles.clear()

	if hero_bubble and is_instance_valid(hero_bubble):
		hero_bubble.queue_free()

	# Key test values: 4, 9, 49, 94, 44, 99, 14, 19, 7, 42
	var test_values = [4, 9, 49, 94, 44, 99, 14, 19, 7, 42]
	var cols = 5
	var start_x = 42.0
	var start_y = 50.0
	var spacing_x = 72.0
	var spacing_y = 66.0

	for i in range(test_values.size()):
		var val = test_values[i]
		var col = i % cols
		var row = i / cols
		var pos = Vector2(start_x + col * spacing_x, start_y + row * spacing_y)
		var bubble: NumberBubble = bubble_scene.instantiate() as NumberBubble
		bubble_container.add_child(bubble)
		var zone = "left" if (i % 2 == 0) else "right"
		bubble.setup(val, pos, zone, 1)
		active_bubbles.append(bubble)

	# Hero Custom Bubble in the center-bottom
	hero_bubble = bubble_scene.instantiate() as NumberBubble
	bubble_container.add_child(hero_bubble)
	var custom_val = line_edit_custom.text.to_int() if line_edit_custom.text.is_valid_int() else 49
	hero_bubble.setup(custom_val, hero_bubble_pos.position, "left", 1)
	hero_bubble.bubble_radius = sld_radius.value * 1.3
	hero_bubble._build_dense_sphere()


func _refresh_bubbles() -> void:
	for b in active_bubbles:
		if is_instance_valid(b):
			b.text_color = NumberBubble.global_text_color
			b.queue_redraw()
	if hero_bubble and is_instance_valid(hero_bubble):
		hero_bubble.text_color = NumberBubble.global_text_color
		hero_bubble.queue_redraw()


func _rebuild_all_spheres() -> void:
	for b in active_bubbles:
		if is_instance_valid(b):
			b._build_dense_sphere()
			b.queue_redraw()
	if hero_bubble and is_instance_valid(hero_bubble):
		hero_bubble._build_dense_sphere()
		hero_bubble.queue_redraw()


func _update_code_readout() -> void:
	var font_name = "PressStart2P-Regular.ttf"
	if NumberBubble.global_font_override == font_silkscreen_bold:
		font_name = "Silkscreen-Bold.ttf"
	elif NumberBubble.global_font_override == font_silkscreen_reg:
		font_name = "Silkscreen-Regular.ttf"

	var txt = "# === AKTUELL EINGESTELLTE WERTE ===\n"
	txt += "Font: " + font_name + "\n"
	txt += "1-Digit Size: " + str(NumberBubble.global_font_size_1_digit) + "px\n"
	txt += "2-Digit Size: " + str(NumberBubble.global_font_size_2_digit) + "px\n"
	txt += "3-Digit Size: " + str(NumberBubble.global_font_size_3_digit) + "px\n"
	txt += "Outline Thickness: " + str(NumberBubble.global_outline_thickness) + "\n"
	txt += "Shadow Offset: " + str(NumberBubble.global_shadow_offset) + "\n"
	txt += "Exclusion Factor: " + str(NumberBubble.global_exclusion_factor) + "\n"
	txt += "Text Color: " + NumberBubble.global_text_color.to_html() + "\n"
	code_readout.text = txt
