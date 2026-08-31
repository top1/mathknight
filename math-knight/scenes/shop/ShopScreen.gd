class_name ShopScreen
extends Control
## Shop Screen for MathKnight roguelike runs.
## Displays merchant items for purchase with run Gold.

const ItemDB = preload("res://scripts/resources/ItemDatabase.gd")

@onready var gold_label: Label = $MarginContainer/MainLayout/Header/GoldBadge/GoldContainer/GoldLabel
@onready var item_cards_container: HBoxContainer = $MarginContainer/MainLayout/CardContainer
@onready var leave_btn: Button = $MarginContainer/MainLayout/Footer/LeaveBtn
@onready var merchant_dialogue: Label = $MarginContainer/MainLayout/MerchantPanel/DialogueLabel

var _current_items: Array[Dictionary] = []

func _ready() -> void:
	_setup_styles()
	leave_btn.pressed.connect(_on_leave_pressed)
	
	_populate_shop()
	_update_gold_display()

	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_music("shop")

func _setup_styles() -> void:
	# Gold Badge style
	var gold_style = StyleBoxFlat.new()
	gold_style.bg_color = Color(0.12, 0.10, 0.18, 0.9)
	gold_style.border_color = Color(1.0, 0.85, 0.3)
	gold_style.set_border_width_all(1)
	gold_style.set_corner_radius_all(6)
	gold_style.content_margin_left = 10
	gold_style.content_margin_right = 10
	$MarginContainer/MainLayout/Header/GoldBadge.add_theme_stylebox_override("panel", gold_style)

	# Leave button style
	var leave_style = StyleBoxFlat.new()
	leave_style.bg_color = Color(0.22, 0.18, 0.32)
	leave_style.border_color = Color(0.6, 0.5, 0.7)
	leave_style.set_border_width_all(2)
	leave_style.set_corner_radius_all(6)
	leave_btn.add_theme_stylebox_override("normal", leave_style)

func _update_gold_display() -> void:
	var current_gold = 0
	if has_node("/root/RunManager"):
		current_gold = get_node("/root/RunManager").run_gold
	gold_label.text = "🪙 " + str(current_gold)

func _populate_shop() -> void:
	for child in item_cards_container.get_children():
		child.queue_free()

	_current_items = ItemDB.get_random_shop_selection(3)

	for item in _current_items:
		var card = _create_item_card(item)
		item_cards_container.add_child(card)

func _create_item_card(item: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(170, 190)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.10, 0.20, 0.95)
	style.border_color = Color(0.85, 0.75, 0.35)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	# Name
	var name_label = Label.new()
	name_label.text = item.get("name", "Item")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	name_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(name_label)

	# Icon
	var icon_name = item.get("icon", "")
	var icon_tex = SpriteManager.get_item_icon(icon_name)
	if icon_tex:
		var icon_rect = TextureRect.new()
		icon_rect.texture = icon_tex
		icon_rect.custom_minimum_size = Vector2(36, 36)
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		vbox.add_child(icon_rect)

	# Type Tag
	var type_label = Label.new()
	var type_str = "Trank" if item.get("type") == "potion" else "Artefakt"
	type_label.text = "[" + type_str + "]"
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	type_label.add_theme_font_size_override("font_size", 8)
	vbox.add_child(type_label)

	# Description
	var desc_label = Label.new()
	desc_label.text = item.get("desc", "")
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.88))
	desc_label.add_theme_font_size_override("font_size", 8)
	vbox.add_child(desc_label)

	# Price & Buy button
	var buy_btn = Button.new()
	var cost = item.get("cost_gold", 20)
	buy_btn.text = "🪙 " + str(cost) + " Kaufen"
	buy_btn.custom_minimum_size = Vector2(0, 32)
	
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.9, 0.65, 0.15)
	btn_style.set_corner_radius_all(4)
	buy_btn.add_theme_stylebox_override("normal", btn_style)
	buy_btn.add_theme_color_override("font_color", Color(0.1, 0.05, 0.0))
	buy_btn.add_theme_font_size_override("font_size", 10)

	buy_btn.pressed.connect(func(): _buy_item(item, buy_btn, panel))
	vbox.add_child(buy_btn)

	return panel

func _buy_item(item: Dictionary, btn: Button, panel: PanelContainer) -> void:
	if not has_node("/root/RunManager"):
		return
	var rm = get_node("/root/RunManager")
	var cost = item.get("cost_gold", 20)

	if rm.spend_run_gold(cost):
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx("coin", 1.2)
		btn.disabled = true
		btn.text = "Gekauft ✓"
		panel.modulate = Color(0.6, 0.6, 0.6, 0.7)
		_update_gold_display()
		
		# Apply item effect
		if item.get("type") == "potion":
			if item.get("effect_type") == "heal_flat":
				rm.heal_knight(item.get("value", 5.0))
			elif item.get("effect_type") == "hp_boost":
				rm.knight_run_max_hp += item.get("value", 4.0)
				rm.knight_run_hp += item.get("value", 4.0)
			elif item.get("effect_type") == "armor_boost":
				rm.knight_run_armor += item.get("value", 0.5)
		else:
			rm.add_artifact(item)

		merchant_dialogue.text = "»Ein feiner Handel, tapferer Rechner! Möge es dir nützen!«"
	else:
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx("wrong", 1.1)
		merchant_dialogue.text = "»Dafür reichen deine Goldmünzen leider nicht aus...«"
		var t = create_tween()
		btn.modulate = Color(2.0, 0.5, 0.5)
		t.tween_property(btn, "modulate", Color.WHITE, 0.3)

func _on_leave_pressed() -> void:
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("click")
	get_tree().change_scene_to_file("res://scenes/map/RunMap.tscn")
