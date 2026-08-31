class_name CosmeticInventory
extends Control
## Inventory and equipment manager for unlockable cosmetic items.
## Tracks Swords, Helmets, Hats, and Victory Animations with live Knight preview.

const CosmeticDB = preload("res://scripts/resources/CosmeticDatabase.gd")

@onready var diamond_label: Label = $MarginContainer/MainLayout/Header/DiamondBadge/DiamondLabel
@onready var ascii_knight: AsciiEntity = $MarginContainer/MainLayout/Body/PreviewFrame/PreviewPanel/KnightArea/AsciiKnight
@onready var item_grid: GridContainer = $MarginContainer/MainLayout/Body/RightPanel/Scroll/ItemGrid
@onready var back_btn: Button = $MarginContainer/MainLayout/Header/BackBtn
@onready var sword_tab: Button = $MarginContainer/MainLayout/Body/RightPanel/TabBar/SwordTab
@onready var helm_tab: Button = $MarginContainer/MainLayout/Body/RightPanel/TabBar/HelmTab
@onready var hat_tab: Button = $MarginContainer/MainLayout/Body/RightPanel/TabBar/HatTab
@onready var anim_tab: Button = $MarginContainer/MainLayout/Body/RightPanel/TabBar/AnimTab
@onready var item_title: Label = $MarginContainer/MainLayout/Body/PreviewFrame/PreviewPanel/ItemTitle
@onready var item_rarity: Label = $MarginContainer/MainLayout/Body/PreviewFrame/PreviewPanel/ItemRarity
@onready var item_desc: Label = $MarginContainer/MainLayout/Body/PreviewFrame/PreviewPanel/ItemDesc
@onready var action_btn: Button = $MarginContainer/MainLayout/Body/PreviewFrame/PreviewPanel/ActionBtn

var _active_slot: String = "sword"
var _selected_item: Dictionary = {}

func _ready() -> void:
	_setup_styles()
	_connect_signals()
	_select_tab("sword", sword_tab)
	_update_diamond_display()

	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_music("shop")

func _setup_styles() -> void:
	# Diamond badge style
	var dia_style = StyleBoxFlat.new()
	dia_style.bg_color = Color(0.1, 0.12, 0.22, 0.9)
	dia_style.border_color = Color(0.3, 0.8, 1.0)
	dia_style.set_border_width_all(1)
	dia_style.set_corner_radius_all(4)
	dia_style.content_margin_left = 8
	dia_style.content_margin_right = 8
	$MarginContainer/MainLayout/Header/DiamondBadge.add_theme_stylebox_override("panel", dia_style)

	# Action button style
	var act_style = StyleBoxFlat.new()
	act_style.bg_color = Color(0.9, 0.7, 0.2)
	act_style.border_color = Color(1.0, 0.9, 0.5)
	act_style.set_border_width_all(2)
	act_style.set_corner_radius_all(6)
	act_style.content_margin_left = 6
	act_style.content_margin_right = 6
	action_btn.add_theme_stylebox_override("normal", act_style)

func _connect_signals() -> void:
	back_btn.pressed.connect(func():
		if has_node("/root/AudioManager"): get_node("/root/AudioManager").play_sfx("click")
		get_tree().change_scene_to_file("res://scenes/menu/TitleScreen.tscn")
	)
	sword_tab.pressed.connect(func(): _select_tab("sword", sword_tab))
	helm_tab.pressed.connect(func(): _select_tab("helmet", helm_tab))
	hat_tab.pressed.connect(func(): _select_tab("hat", hat_tab))
	anim_tab.pressed.connect(func(): _select_tab("victory_anim", anim_tab))
	action_btn.pressed.connect(_on_action_pressed)

func _update_diamond_display() -> void:
	var count = 0
	if has_node("/root/SaveManager"):
		count = get_node("/root/SaveManager").diamonds
	diamond_label.text = "💎 " + str(count)

func _select_tab(slot: String, active_btn: Button) -> void:
	_active_slot = slot
	
	# Highlight active tab
	for tab in [sword_tab, helm_tab, hat_tab, anim_tab]:
		var style = StyleBoxFlat.new()
		style.set_corner_radius_all(4)
		if tab == active_btn:
			style.bg_color = Color(0.3, 0.22, 0.45, 0.95)
			style.border_color = Color(1.0, 0.85, 0.3)
			style.set_border_width_all(2)
		else:
			style.bg_color = Color(0.12, 0.1, 0.18, 0.7)
			style.border_color = Color(0.3, 0.25, 0.4)
			style.set_border_width_all(1)
		tab.add_theme_stylebox_override("normal", style)

	_populate_items()

func _populate_items() -> void:
	for child in item_grid.get_children():
		child.queue_free()

	var items = CosmeticDB.get_items_by_slot(_active_slot)
	var first_item: Dictionary = {}

	for item in items:
		if first_item.is_empty():
			first_item = item
		var btn = _create_item_button(item)
		item_grid.add_child(btn)

	if not first_item.is_empty():
		_select_item(first_item)

func _create_item_button(item: Dictionary) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(90, 54)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	var is_unlocked = item.get("unlocked_by_default", false)
	if has_node("/root/SaveManager"):
		if get_node("/root/SaveManager").is_cosmetic_unlocked(item.id):
			is_unlocked = true

	var is_equipped = false
	if has_node("/root/SaveManager"):
		is_equipped = get_node("/root/SaveManager").equipped_cosmetics.get(_active_slot) == item.id

	var label_text = item.name
	if is_equipped:
		label_text += "\n[Aktiv ✓]"
	elif not is_unlocked:
		label_text += "\n🔒 💎" + str(item.cost_diamonds)

	btn.text = label_text
	btn.add_theme_font_size_override("font_size", 7)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.11, 0.20, 0.95) if is_equipped else Color(0.10, 0.08, 0.15, 0.85)
	style.border_color = Color(1.0, 0.85, 0.3) if is_equipped else item.get("rarity_color", Color.GRAY)
	style.set_border_width_all(2 if is_equipped else 1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", style)

	btn.pressed.connect(func():
		if has_node("/root/AudioManager"): get_node("/root/AudioManager").play_sfx("click")
		_select_item(item)
	)
	return btn

func _select_item(item: Dictionary) -> void:
	_selected_item = item
	item_title.text = item.name
	item_rarity.text = "✦ " + item.rarity_name.to_upper() + " ✦"
	item_rarity.add_theme_color_override("font_color", item.rarity_color)
	item_desc.text = item.get("desc", "")

	# Live ASCII Knight Cosmetic Preview!
	if ascii_knight:
		match _active_slot:
			"sword":
				ascii_knight.equipped_sword = item.id
				ascii_knight.play_slash() # Live sword slash preview!
			"helmet":
				ascii_knight.equipped_helmet = item.id
			"hat":
				ascii_knight.equipped_hat = item.id
			"victory_anim":
				ascii_knight.play_special_anim(item.id) # Live victory animation preview!

	var is_unlocked = item.get("unlocked_by_default", false)
	if has_node("/root/SaveManager"):
		if get_node("/root/SaveManager").is_cosmetic_unlocked(item.id):
			is_unlocked = true

	var is_equipped = false
	if has_node("/root/SaveManager"):
		is_equipped = get_node("/root/SaveManager").equipped_cosmetics.get(_active_slot) == item.id

	if is_equipped:
		action_btn.text = "Ausgerüstet ✓"
		action_btn.disabled = true
	elif is_unlocked:
		action_btn.text = "Ausrüsten"
		action_btn.disabled = false
	else:
		action_btn.text = "Freischalten (💎 " + str(item.cost_diamonds) + ")"
		action_btn.disabled = false

func _on_action_pressed() -> void:
	if _selected_item.is_empty() or not has_node("/root/SaveManager"):
		return
	var sm = get_node("/root/SaveManager")
	var is_unlocked = sm.is_cosmetic_unlocked(_selected_item.id) or _selected_item.get("unlocked_by_default", false)

	if is_unlocked:
		# Equip
		sm.equip_cosmetic(_selected_item.id, _active_slot)
		if has_node("/root/AudioManager"): get_node("/root/AudioManager").play_sfx("click")
		_select_tab(_active_slot, _get_active_tab_button())
		_select_item(_selected_item)
	else:
		# Buy with diamonds
		var cost = _selected_item.get("cost_diamonds", 5)
		if sm.spend_diamonds(cost):
			sm.unlock_cosmetic(_selected_item.id)
			sm.equip_cosmetic(_selected_item.id, _active_slot)
			if has_node("/root/AudioManager"): get_node("/root/AudioManager").play_sfx("coin", 1.2)
			_update_diamond_display()
			_select_tab(_active_slot, _get_active_tab_button())
			_select_item(_selected_item)
		else:
			# Not enough diamonds
			var t = create_tween()
			action_btn.modulate = Color(2.0, 0.4, 0.4)
			t.tween_property(action_btn, "modulate", Color.WHITE, 0.3)

func _get_active_tab_button() -> Button:
	match _active_slot:
		"sword": return sword_tab
		"helmet": return helm_tab
		"hat": return hat_tab
		"victory_anim": return anim_tab
		_: return sword_tab
