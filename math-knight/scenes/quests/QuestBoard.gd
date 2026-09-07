class_name QuestBoard
extends Control
## QuestBoard — displays daily and weekly bounties on a medieval cork/wood notice board.
## Allows players to track objectives and claim rewards.

@onready var quest_container: VBoxContainer = $MarginContainer/MainVBox/ScrollContainer/QuestList
@onready var back_btn: Button = $MarginContainer/MainVBox/TopBar/BackBtn
@onready var header_label: Label = $MarginContainer/MainVBox/TopBar/HeaderLabel

func _ready() -> void:
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)
	
	if has_node("/root/QuestManager"):
		var qm = get_node("/root/QuestManager")
		qm.quest_updated.connect(_on_quest_updated)
		qm.quest_completed.connect(_on_quest_completed)
		
	_populate_quests()

func _populate_quests() -> void:
	if not quest_container:
		return
		
	# Clear existing children
	for child in quest_container.get_children():
		child.queue_free()
		
	if not has_node("/root/QuestManager"):
		return
		
	var qm = get_node("/root/QuestManager")
	var quests = qm.active_quests
	
	for quest in quests:
		var card = _create_quest_card(quest)
		quest_container.add_child(card)

func _create_quest_card(quest: Dictionary) -> PanelContainer:
	var card = PanelContainer.new()
	var style = StyleBoxFlat.new()
	var is_weekly = (quest.get("type", "") == "weekly")
	
	if is_weekly:
		style.bg_color = Color(0.2, 0.16, 0.28, 0.95)
		style.border_color = Color(0.85, 0.65, 0.2)
		style.set_border_width_all(2)
	else:
		style.bg_color = Color(0.14, 0.12, 0.18, 0.9)
		style.border_color = Color(0.45, 0.4, 0.35)
		style.set_border_width_all(1)
		
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", style)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	card.add_child(hbox)
	
	# Left: Info (Title, Desc, Progress)
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)
	
	# Header line: Badge + Title
	var title_hbox = HBoxContainer.new()
	title_hbox.add_theme_constant_override("separation", 8)
	info_vbox.add_child(title_hbox)
	
	var badge = Label.new()
	badge.text = "[WÖCHENTLICH]" if is_weekly else "[TÄGLICH]"
	badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3) if is_weekly else Color(0.5, 0.8, 1.0))
	title_hbox.add_child(badge)
	
	var title = Label.new()
	title.text = quest.get("title", "Auftrag")
	title.add_theme_color_override("font_color", Color.WHITE)
	title_hbox.add_child(title)
	
	var desc = Label.new()
	desc.text = quest.get("desc", "")
	desc.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	info_vbox.add_child(desc)
	
	# Progress bar
	var cur = quest.get("current", 0)
	var tgt = quest.get("target", 1)
	var prog_bar = ProgressBar.new()
	prog_bar.min_value = 0
	prog_bar.max_value = tgt
	prog_bar.value = cur
	prog_bar.custom_minimum_size = Vector2(180, 14)
	prog_bar.show_percentage = false
	info_vbox.add_child(prog_bar)
	
	var prog_label = Label.new()
	prog_label.text = "Fortschritt: %d / %d" % [cur, tgt]
	prog_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	info_vbox.add_child(prog_label)
	
	# Right: Rewards & Claim Button
	var right_vbox = VBoxContainer.new()
	right_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	right_vbox.custom_minimum_size = Vector2(160, 0)
	hbox.add_child(right_vbox)
	
	# Reward icons/text
	var rew_parts: Array[String] = []
	if quest.get("reward_gold", 0) > 0: rew_parts.append("+%d 🪙" % quest.get("reward_gold"))
	if quest.get("reward_wood", 0) > 0: rew_parts.append("+%d 🪵" % quest.get("reward_wood"))
	if quest.get("reward_xp", 0) > 0: rew_parts.append("+%d ⬆️XP" % quest.get("reward_xp"))
	if quest.get("reward_diamonds", 0) > 0: rew_parts.append("+%d 💎" % quest.get("reward_diamonds"))
	
	var rew_label = Label.new()
	rew_label.text = " ".join(rew_parts)
	rew_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rew_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	right_vbox.add_child(rew_label)
	
	# Action Button
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(140, 32)
	var q_id = quest.get("id", "")
	var completed = quest.get("completed", false)
	var claimed = quest.get("claimed", false)
	
	if claimed:
		btn.text = "Erhalten ✓"
		btn.disabled = true
	elif completed:
		btn.text = "Abholen! 🎁"
		btn.disabled = false
		btn.pressed.connect(func(): _on_claim_pressed(q_id, btn))
	else:
		btn.text = "In Arbeit..."
		btn.disabled = true
		
	right_vbox.add_child(btn)
	return card

func _on_claim_pressed(quest_id: String, btn: Button) -> void:
	if not has_node("/root/QuestManager"):
		return
	var qm = get_node("/root/QuestManager")
	var success = qm.claim_reward(quest_id)
	if success:
		btn.text = "Erhalten ✓"
		btn.disabled = true
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx("levelup", 1.0, 1.0)
		JuiceManager.spawn_comic_popup(self, "BELOHNUNG!", btn.global_position + Vector2(20, -20), "flawless")
		# Re-render to refresh wallet and status
		get_tree().create_timer(0.3).timeout.connect(_populate_quests)

func _on_quest_updated(_quest_id: String, _cur: int, _target: int) -> void:
	_populate_quests()

func _on_quest_completed(_quest_id: String) -> void:
	_populate_quests()

func _on_back_pressed() -> void:
	if ResourceLoader.exists("res://scenes/village/VillageHub.tscn"):
		get_tree().change_scene_to_file("res://scenes/village/VillageHub.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/menu/TitleScreen.tscn")