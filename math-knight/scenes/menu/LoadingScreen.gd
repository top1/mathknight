class_name LoadingScreen
extends Control
## Cyber-ASCII Glow Loading & Transition Screen
## Features digital math matrix rain, animated ASCII Knight figure,
## glowing ASCII glyph spinner, and smooth scene transitions.

@onready var tip_label: Label = $MarginContainer/MainLayout/TipPanel/TipLabel
@onready var progress_bar: ProgressBar = $MarginContainer/MainLayout/ProgressContainer/ProgressBar
@onready var status_label: Label = $MarginContainer/MainLayout/ProgressContainer/StatusLabel
@onready var ascii_spinner: AsciiLoadingSpinner = $MarginContainer/MainLayout/ProgressContainer/AsciiSpinner
@onready var ascii_knight: AsciiEntity = $CenterContainer/KnightAnchor/AsciiKnight

var target_scene_path: String = "res://scenes/map/RunMap.tscn"
var _progress: float = 0.0
var _is_loaded: bool = false

const TIPS = [
	"TIPP: Schnelle richtige Antworten erhöhen deinen Multiplikator und Gold-Drop!",
	"TIPP: Bosse haben Schilde - kombiniere Addition und Multiplikation für maximale Durchschlagskraft!",
	"TIPP: Rüste in der Rüstkammer mächtige Schwerter und Helme aus, um deinen Stil anzupassen.",
	"TIPP: Verteile deine Talentpunkte nach jedem Levelaufstieg für mehr Schaden, Leben und Rüstung!",
	"TIPP: Geschick erhöht deine Chance, tödlichen Monster-Angriffen komplett auszuweichen.",
	"TIPP: Kettenrechnungen in der Meister-Kette erfordern kühlen Kopf - plane zwei Schritte voraus!"
]

func _ready() -> void:
	randomize()
	if tip_label:
		tip_label.text = TIPS[randi() % TIPS.size()]
	
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("click")
		
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if gm.has_method("get_target_scene"):
			var p = gm.get_target_scene()
			if p != "":
				target_scene_path = p

	_setup_styles()
	_start_loading()

func _setup_styles() -> void:
	if progress_bar:
		# Custom dark background + glowing cyan progress fill
		var bg_sb = StyleBoxFlat.new()
		bg_sb.bg_color = Color(0.06, 0.08, 0.14, 0.85)
		bg_sb.border_color = Color(0.18, 0.45, 0.65, 0.6)
		bg_sb.set_border_width_all(1)
		bg_sb.set_corner_radius_all(4)
		progress_bar.add_theme_stylebox_override("background", bg_sb)
		
		var fill_sb = StyleBoxFlat.new()
		fill_sb.bg_color = Color(0.2, 0.85, 1.0, 0.95)
		fill_sb.border_color = Color(0.8, 1.0, 1.0, 0.9)
		fill_sb.set_border_width_all(1)
		fill_sb.set_corner_radius_all(4)
		progress_bar.add_theme_stylebox_override("fill", fill_sb)

func _start_loading() -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Animate progress bar smoothly
	tween.tween_property(self, "_progress", 100.0, 1.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Finish callback
	tween.chain().tween_callback(_on_loading_complete)

func _process(_delta: float) -> void:
	if progress_bar:
		progress_bar.value = _progress
	if status_label:
		status_label.text = "Lade Dungeon... %d%%" % int(_progress)

func _on_loading_complete() -> void:
	if ascii_knight:
		ascii_knight.play_slash()
		
	var fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.35)
	fade_tween.tween_callback(func():
		get_tree().change_scene_to_file(target_scene_path)
	)
