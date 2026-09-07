extends Control
class_name LumberYard

## The Lumber Yard mini-game.
## Teaches division and fractions through physical log segmentation.
## Features the interactive Line-Stretch snapping tool and physics wood stacking.

@onready var prompt_label: Label = $MainBox/PromptLabel
@onready var req_label: Label = $MainBox/ReqLabel
@onready var log_display: Control = $MainBox/SawbenchArea/LogDisplay
@onready var log_rect: ColorRect = $MainBox/SawbenchArea/LogDisplay/LogWood
@onready var cut_markers_container: Control = $MainBox/SawbenchArea/LogDisplay/CutMarkers
@onready var slider: HSlider = $MainBox/StretchToolArea/StretchSlider
@onready var slider_val_label: Label = $MainBox/StretchToolArea/ValueLabel
@onready var saw_btn: Button = $MainBox/SawbenchArea/SawBtn
@onready var saw_visual: Label = $MainBox/SawbenchArea/SawVisual
@onready var rack_container: HBoxContainer = $MainBox/StorageArea/RackSlots
@onready var wood_counter_label: Label = $TopBar/WoodLabel
@onready var back_btn: Button = $TopBar/BackBtn
@onready var sawdust_particles: CPUParticles2D = $Sawdust

var current_log_length: int = 12
var required_segment_size: int = 3
var current_selected_size: int = 1

var _shift_logs_cleared: int = 0
var _shift_total_logs: int = 5
var _is_cutting_active: bool = false


func _ready() -> void:
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)
	if saw_btn:
		saw_btn.pressed.connect(_on_saw_pressed)
	if slider:
		slider.value_changed.connect(_on_slider_value_changed)

	_update_wood_display()
	start_new_log()


func start_new_log() -> void:
	_is_cutting_active = true

	# Pick random clean division problem:
	# e.g., sizes 2..6, multiples from 2 to 6
	var divisors = [2, 3, 4, 5, 6]
	required_segment_size = divisors.pick_random()
	var piece_count = randi_range(2, 5)
	current_log_length = required_segment_size * piece_count

	if prompt_label:
		prompt_label.text = "STAMM-LÄNGE: %d METER" % current_log_length

	if req_label:
		req_label.text = "LAGER-ANFORDERUNG: Balken der Länge %d Meter!\n(%d ÷ %d = ? Stücke)" % [required_segment_size, current_log_length, required_segment_size]

	if slider:
		slider.min_value = 1
		slider.max_value = current_log_length
		slider.step = 1
		slider.value = 1
		current_selected_size = 1

	_update_slider_label()
	_render_cut_markers()
	_setup_storage_rack(piece_count)


func _update_slider_label() -> void:
	var pieces = current_log_length / current_selected_size if current_selected_size > 0 else 0
	var remainder = current_log_length % current_selected_size if current_selected_size > 0 else 0
	var cuts_needed = max(0, pieces - 1)

	if slider_val_label:
		if remainder == 0:
			slider_val_label.text = "Schnitt-Länge: %dm  ➜  %d Stücke (%d Schnitte)" % [current_selected_size, pieces, cuts_needed]
		else:
			slider_val_label.text = "Schnitt-Länge: %dm  ➜  %d Stücke (Rest: %dm)" % [current_selected_size, pieces, remainder]


func _on_slider_value_changed(value: float) -> void:
	current_selected_size = int(value)
	_update_slider_label()
	_render_cut_markers()

	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("click", 1.5, 0.3)


func _render_cut_markers() -> void:
	if not cut_markers_container or not log_rect:
		return

	for c in cut_markers_container.get_children():
		c.queue_free()

	var total_w = log_rect.size.x
	if current_log_length <= 0 or current_selected_size <= 0:
		return

	var unit_w = total_w / float(current_log_length)
	var cuts = int(current_log_length / current_selected_size)

	for i in range(1, cuts):
		var cut_x = float(i * current_selected_size) * unit_w
		var line = ColorRect.new()
		line.color = Color(1.0, 0.25, 0.2, 0.85)
		line.size = Vector2(2, log_rect.size.y + 6)
		line.position = Vector2(cut_x - 1, -3)
		cut_markers_container.add_child(line)


func _setup_storage_rack(slots: int) -> void:
	if not rack_container:
		return
	for c in rack_container.get_children():
		c.queue_free()

	for i in range(slots):
		var slot = Panel.new()
		slot.custom_minimum_size = Vector2(40, 30)
		var lbl = Label.new()
		lbl.text = "📦"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.set_anchors_preset(PRESET_FULL_RECT)
		slot.add_child(lbl)
		rack_container.add_child(slot)


func _on_saw_pressed() -> void:
	if not _is_cutting_active:
		return

	_is_cutting_active = false
	var is_correct = (current_selected_size == required_segment_size)

	# Trigger giant waterwheel saw slice animation!
	if saw_visual:
		var tw = create_tween()
		tw.tween_property(saw_visual, "position:y", 35.0, 0.12).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(saw_visual, "position:y", -10.0, 0.25).set_trans(Tween.TRANS_BACK)

	if sawdust_particles:
		sawdust_particles.emitting = true

	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("sword_slash", 0.6, 1.8) # deep saw buzz

	var timer = get_tree().create_timer(0.4)
	timer.timeout.connect(func(): _evaluate_cut(is_correct))


func _evaluate_cut(is_correct: bool) -> void:
	if is_correct:
		# CORRECT DIVISION!
		var pieces = current_log_length / required_segment_size
		JuiceManager.spawn_comic_popup(self, "DIVIDED!", saw_btn.global_position + Vector2(0, -40), "blitz")
		JuiceManager.hit_stop(get_tree(), 0.066, 0.05)

		# Animate wood slots stacking into shed
		if rack_container:
			var slots = rack_container.get_children()
			for i in range(slots.size()):
				var s = slots[i]
				var tw = create_tween()
				tw.tween_property(s, "modulate", Color(0.4, 1.5, 0.4), 0.15).set_delay(float(i) * 0.1)
				tw.tween_property(s, "scale", Vector2(1.15, 1.15), 0.1).set_delay(float(i) * 0.1)
				tw.tween_property(s, "scale", Vector2(1.0, 1.0), 0.1).set_delay(float(i) * 0.1 + 0.1)

		# Award wood & gold
		var wood_earned = pieces
		var gold_earned = pieces * 3
		if has_node("/root/SaveManager"):
			var sm = get_node("/root/SaveManager")
			sm.add_wood(wood_earned)
			sm.add_gold(gold_earned)
		if has_node("/root/EventBus"):
			get_node("/root/EventBus").lumber_cut_completed.emit(wood_earned)
		_update_wood_display()

		_shift_logs_cleared += 1

		var next_timer = get_tree().create_timer(1.2)
		next_timer.timeout.connect(start_new_log)
	else:
		# INCORRECT DIVISION
		JuiceManager.spawn_comic_popup(self, "PASST NICHT!", saw_btn.global_position + Vector2(0, -40), "defeat")
		if log_rect:
			var tw = create_tween()
			tw.tween_property(log_rect, "modulate", Color(2.0, 0.4, 0.4), 0.1)
			tw.tween_property(log_rect, "modulate", Color.WHITE, 0.2)

		_is_cutting_active = true


func _update_wood_display() -> void:
	if not wood_counter_label:
		return
	var total_wood = 0
	var total_gold = 0
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		total_wood = sm.wood
		total_gold = sm.gold
	wood_counter_label.text = "🪵 %d Holz  |  🪙 %d Gold" % [total_wood, total_gold]


func _on_back_pressed() -> void:
	if ResourceLoader.exists("res://scenes/village/VillageHub.tscn"):
		get_tree().change_scene_to_file("res://scenes/village/VillageHub.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/menu/TitleScreen.tscn")