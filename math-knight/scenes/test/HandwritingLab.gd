class_name HandwritingLab
extends Control
## ═══════════════════════════════════════════════════════════════════════════
## HandwritingLab — Interaktives Test- & Diagnose-Labor für Schrifterkennung
##
## Unterstützt:
##   • Natives Google ML Kit (Digital Ink Recognition) auf Android Geräten
##   • $P Point-Cloud Recognizer als nahtloses Fallback auf Desktop / Editor
##   • Live-Canvas mit Touch- & Maus-Eingabe, Undo, Clear und visuellen Hilfslinien
##   • Ziffern-Trainingsmodus (Ziel 0–9 mit Sofort-Feedback Richtig/Falsch)
##   • Latenz- & Konfidenz-Messung
##   • Raw-JSON Stroke-Inspektor
## ═══════════════════════════════════════════════════════════════════════════

const PointCloudRecognizerClass = preload("res://scenes/ui/input_methods/recognition/PointCloudRecognizer.gd")

# Nodes
@onready var back_btn: Button = $VBox/TopBar/BackBtn
@onready var title_label: Label = $VBox/TopBar/TitleLabel
@onready var backend_badge: Label = $VBox/TopBar/BackendBadge

@onready var canvas_panel: PanelContainer = $VBox/MainHBox/LeftCol/CanvasPanel
@onready var draw_surface: Control = $VBox/MainHBox/LeftCol/CanvasPanel/DrawSurface
@onready var debounce_bar: ProgressBar = $VBox/MainHBox/LeftCol/DebounceBar
@onready var btn_clear: Button = $VBox/MainHBox/LeftCol/CanvasBtnRow/BtnClear
@onready var btn_undo: Button = $VBox/MainHBox/LeftCol/CanvasBtnRow/BtnUndo
@onready var btn_recognize: Button = $VBox/MainHBox/LeftCol/CanvasBtnRow/BtnRecognize
@onready var chk_auto_debounce: CheckBox = $VBox/MainHBox/LeftCol/CanvasBtnRow/ChkAutoDebounce

@onready var result_display: Label = $VBox/MainHBox/RightCol/ResultPanel/VBox/ResultDisplay
@onready var status_info_label: Label = $VBox/MainHBox/RightCol/ResultPanel/VBox/StatusInfoLabel
@onready var verdict_badge: Label = $VBox/MainHBox/RightCol/ResultPanel/VBox/VerdictBadge

@onready var target_grid: GridContainer = $VBox/MainHBox/RightCol/TargetSection/TargetGrid
@onready var target_label: Label = $VBox/MainHBox/RightCol/TargetSection/TargetHeader/TargetLabel
@onready var score_label: Label = $VBox/MainHBox/RightCol/TargetSection/TargetHeader/ScoreLabel

@onready var sld_debounce: HSlider = $VBox/MainHBox/RightCol/SettingsSection/DebounceRow/DebounceSlider
@onready var lbl_debounce_val: Label = $VBox/MainHBox/RightCol/SettingsSection/DebounceRow/DebounceVal
@onready var btn_toggle_json: Button = $VBox/MainHBox/RightCol/SettingsSection/BtnToggleJson
@onready var json_readout: TextEdit = $VBox/MainHBox/RightCol/JsonReadout

@onready var debounce_timer: Timer = $DebounceTimer

# Handwriting State
var recognizer: PointCloudRecognizer = null
var ml_kit_plugin: Object = null
var is_ml_kit_available: bool = false
var ml_kit_model_status: String = "unknown"

var strokes: Array[PackedVector2Array] = []
var strokes_times: Array = []
var current_stroke: PackedVector2Array = []
var current_stroke_times: Array = []
var is_drawing: bool = false

var stroke_color: Color = Color("#38bdf8")
var stroke_width: float = 6.0
var debounce_duration: float = 0.65
var auto_debounce_enabled: bool = true

# Diagnostic & Target Challenge State
var recognition_start_time_usec: int = 0
var target_digit: int = -1 # -1 = Free Mode
var total_tests: int = 0
var correct_tests: int = 0
var last_recognized_text: String = ""

func _ready() -> void:
	recognizer = PointCloudRecognizerClass.new()
	_init_ml_kit()
	_setup_ui_signals()
	_setup_target_buttons()
	_update_backend_badge()
	_update_target_display()
	
	if draw_surface and not draw_surface.is_connected("draw", Callable(self, "_on_draw_surface_draw")):
		draw_surface.draw.connect(_on_draw_surface_draw)
		
	_clear_canvas()
	
	if json_readout:
		json_readout.visible = false

func _init_ml_kit() -> void:
	if Engine.has_singleton("MathKnightMLKit"):
		ml_kit_plugin = Engine.get_singleton("MathKnightMLKit")
		if ml_kit_plugin:
			is_ml_kit_available = true
			if not ml_kit_plugin.is_connected("ink_recognized", Callable(self, "_on_ml_kit_ink_recognized")):
				ml_kit_plugin.connect("ink_recognized", Callable(self, "_on_ml_kit_ink_recognized"))
			if not ml_kit_plugin.is_connected("model_status_changed", Callable(self, "_on_ml_kit_model_status")):
				ml_kit_plugin.connect("model_status_changed", Callable(self, "_on_ml_kit_model_status"))
			
			ml_kit_plugin.initializeModel("de")
			ml_kit_model_status = "initialisiert"
			print("HandwritingLab: Verbunden mit nativem MathKnightMLKit Plugin.")
	else:
		is_ml_kit_available = false
		ml_kit_model_status = "PC/Desktop Modus (PointCloud Recognizer)"
		print("HandwritingLab: MathKnightMLKit nicht verfügbar -> PointCloud Fallback aktiv.")

func _setup_ui_signals() -> void:
	if back_btn:
		back_btn.pressed.connect(func():
			get_tree().change_scene_to_file("res://scenes/menu/TitleScreen.tscn")
		)
	if btn_clear:
		btn_clear.pressed.connect(_clear_canvas)
	if btn_undo:
		btn_undo.pressed.connect(_undo_stroke)
	if btn_recognize:
		btn_recognize.pressed.connect(_trigger_recognition)
	if chk_auto_debounce:
		chk_auto_debounce.toggled.connect(func(toggled: bool):
			auto_debounce_enabled = toggled
			if not toggled and debounce_timer:
				debounce_timer.stop()
				debounce_bar.value = 0.0
		)
	if sld_debounce:
		sld_debounce.value = debounce_duration
		sld_debounce.value_changed.connect(func(v: float):
			debounce_duration = v
			if lbl_debounce_val:
				lbl_debounce_val.text = "%.2fs" % v
		)
		if lbl_debounce_val:
			lbl_debounce_val.text = "%.2fs" % debounce_duration

	if btn_toggle_json:
		btn_toggle_json.pressed.connect(func():
			if json_readout:
				json_readout.visible = not json_readout.visible
				btn_toggle_json.text = "Raw JSON: " + ("AN" if json_readout.visible else "AUS")
		)

	if debounce_timer:
		debounce_timer.timeout.connect(_trigger_recognition)

func _setup_target_buttons() -> void:
	if not target_grid:
		return
		
	# Clear existing children
	for ch in target_grid.get_children():
		ch.queue_free()

	# Buttons 0..9
	for i in range(10):
		var btn = Button.new()
		btn.text = str(i)
		btn.custom_minimum_size = Vector2(24, 24)
		btn.add_theme_font_size_override("font_size", 10)
		btn.pressed.connect(func():
			target_digit = i
			_update_target_display()
			_clear_canvas()
		)
		target_grid.add_child(btn)

	# Free Mode Button
	var btn_free = Button.new()
	btn_free.text = "Frei"
	btn_free.custom_minimum_size = Vector2(36, 24)
	btn_free.add_theme_font_size_override("font_size", 9)
	btn_free.pressed.connect(func():
		target_digit = -1
		_update_target_display()
		_clear_canvas()
	)
	target_grid.add_child(btn_free)

func _update_target_display() -> void:
	if target_label:
		if target_digit >= 0:
			target_label.text = "🎯 Ziel-Zahl: %d" % target_digit
		else:
			target_label.text = "🎯 Modus: Frei zeichnen"
	
	if score_label:
		if total_tests > 0:
			var pct = int((float(correct_tests) / float(total_tests)) * 100.0)
			score_label.text = "%d/%d (%d%%)" % [correct_tests, total_tests, pct]
		else:
			score_label.text = "0/0"

func _update_backend_badge() -> void:
	if not backend_badge:
		return
	if is_ml_kit_available:
		backend_badge.text = " 🤖 Google ML Kit (Android / 'de') "
		backend_badge.modulate = Color("#4ade80")
	else:
		backend_badge.text = " 💻 PointCloud Recognizer (PC) "
		backend_badge.modulate = Color("#38bdf8")

func _process(_delta: float) -> void:
	if debounce_bar and debounce_timer and auto_debounce_enabled:
		if debounce_timer.time_left > 0.0:
			debounce_bar.value = debounce_timer.time_left / max(debounce_duration, 0.01)
		else:
			debounce_bar.value = 0.0

func _to_local_canvas(screen_pos: Vector2) -> Vector2:
	if draw_surface and draw_surface.is_inside_tree():
		return draw_surface.get_screen_transform().affine_inverse() * screen_pos
	return screen_pos

func _is_pos_inside_canvas(screen_pos: Vector2) -> bool:
	if not draw_surface:
		return false
	var loc = _to_local_canvas(screen_pos)
	return Rect2(Vector2.ZERO, draw_surface.size).has_point(loc)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _is_pos_inside_canvas(event.position):
				is_drawing = true
				if debounce_timer:
					debounce_timer.stop()
				var loc = _to_local_canvas(event.position)
				current_stroke = PackedVector2Array([loc])
				current_stroke_times = [Time.get_ticks_msec()]
				strokes.append(current_stroke)
				strokes_times.append(current_stroke_times)
				draw_surface.queue_redraw()
		else:
			if is_drawing:
				is_drawing = false
				if auto_debounce_enabled and debounce_timer:
					debounce_timer.start(debounce_duration)

	elif event is InputEventMouseMotion:
		if is_drawing and current_stroke.size() > 0:
			var loc = _to_local_canvas(event.position)
			if loc.distance_squared_to(current_stroke[-1]) > 6.0: # ~2.5px
				current_stroke.append(loc)
				current_stroke_times.append(Time.get_ticks_msec())
				strokes[-1] = current_stroke
				strokes_times[-1] = current_stroke_times
				draw_surface.queue_redraw()

	elif event is InputEventScreenTouch:
		if event.pressed:
			if _is_pos_inside_canvas(event.position):
				is_drawing = true
				if debounce_timer:
					debounce_timer.stop()
				var loc = _to_local_canvas(event.position)
				current_stroke = PackedVector2Array([loc])
				current_stroke_times = [Time.get_ticks_msec()]
				strokes.append(current_stroke)
				strokes_times.append(current_stroke_times)
				draw_surface.queue_redraw()
		else:
			if is_drawing:
				is_drawing = false
				if auto_debounce_enabled and debounce_timer:
					debounce_timer.start(debounce_duration)

	elif event is InputEventScreenDrag:
		if is_drawing and current_stroke.size() > 0:
			var loc = _to_local_canvas(event.position)
			if loc.distance_squared_to(current_stroke[-1]) > 6.0:
				current_stroke.append(loc)
				current_stroke_times.append(Time.get_ticks_msec())
				strokes[-1] = current_stroke
				strokes_times[-1] = current_stroke_times
				draw_surface.queue_redraw()

func _on_draw_surface_draw() -> void:
	if not draw_surface:
		return
	var rect = draw_surface.get_rect()

	# Draw guide lines
	var mid_y = rect.size.y * 0.5
	var baseline_y = rect.size.y * 0.82
	var guide_col = Color(0.3, 0.4, 0.6, 0.22)
	var baseline_col = Color(0.38, 0.65, 0.95, 0.35)
	
	draw_surface.draw_line(Vector2(12, mid_y), Vector2(rect.size.x - 12, mid_y), guide_col, 1.5)
	draw_surface.draw_line(Vector2(12, baseline_y), Vector2(rect.size.x - 12, baseline_y), baseline_col, 2.0)

	# Draw strokes
	for stroke in strokes:
		if stroke.size() > 1:
			# Glow layer
			draw_surface.draw_polyline(stroke, Color(0.1, 0.5, 0.9, 0.35), stroke_width + 4.0, true)
			# Main stroke
			draw_surface.draw_polyline(stroke, stroke_color, stroke_width, true)
			# Round caps & joints
			for pt in stroke:
				draw_surface.draw_circle(pt, stroke_width * 0.5, stroke_color)
		elif stroke.size() == 1:
			draw_surface.draw_circle(stroke[0], stroke_width * 0.7, stroke_color)

func _clear_canvas() -> void:
	strokes.clear()
	strokes_times.clear()
	current_stroke = []
	current_stroke_times = []
	is_drawing = false
	if debounce_timer:
		debounce_timer.stop()
	if debounce_bar:
		debounce_bar.value = 0.0
	if draw_surface:
		draw_surface.queue_redraw()
	_update_stroke_metrics()

func _undo_stroke() -> void:
	if strokes.size() > 0:
		strokes.pop_back()
		strokes_times.pop_back()
		if draw_surface:
			draw_surface.queue_redraw()
		_update_stroke_metrics()

func _trigger_recognition() -> void:
	if strokes.is_empty():
		return
	
	recognition_start_time_usec = Time.get_ticks_usec()

	# Update JSON viewer
	var json_str = _serialize_strokes_to_json()
	if json_readout:
		json_readout.text = json_str

	if is_ml_kit_available and ml_kit_plugin != null and ml_kit_plugin.isModelReady():
		status_info_label.text = "Sende an Google ML Kit..."
		ml_kit_plugin.recognizeStrokes(json_str)
	else:
		_recognize_with_fallback()

func _recognize_with_fallback() -> void:
	var results: Array[Dictionary] = recognizer.recognize_segmented(strokes)
	var elapsed_ms = (Time.get_ticks_usec() - recognition_start_time_usec) / 1000.0
	var recognized_str: String = ""
	var top_conf: float = 0.0

	for res in results:
		var digit: int = res.digit
		var conf: float = res.confidence
		if digit >= 0 and conf >= 0.40:
			recognized_str += str(digit)
			if conf > top_conf:
				top_conf = conf

	if recognized_str.is_empty():
		_display_verdict("?", 0.0, elapsed_ms, "Keine Ziffer sicher erkannt")
	else:
		_display_verdict(recognized_str, top_conf, elapsed_ms, "PointCloud Segmentierung")

func _on_ml_kit_ink_recognized(text: String, score: float) -> void:
	var elapsed_ms = (Time.get_ticks_usec() - recognition_start_time_usec) / 1000.0
	var cleaned = text.strip_edges()
	if cleaned.is_empty():
		_display_verdict("?", 0.0, elapsed_ms, "ML Kit: Keine Ziffer erkannt")
	else:
		_display_verdict(cleaned, score, elapsed_ms, "Google ML Kit (Android)")

func _on_ml_kit_model_status(status: String) -> void:
	ml_kit_model_status = status
	print("HandwritingLab: ML Kit Status -> ", status)
	if status_info_label:
		status_info_label.text = "Modell-Status: " + status

func _display_verdict(recognized: String, score: float, elapsed_ms: float, details: String) -> void:
	last_recognized_text = recognized
	if result_display:
		result_display.text = recognized
		# Little pulse animation
		var tw = create_tween()
		result_display.scale = Vector2(1.3, 1.3)
		tw.tween_property(result_display, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if status_info_label:
		var score_txt = ("Conf: %.0f%%" % (score * 100.0)) if score > 0.0 else ""
		status_info_label.text = "⚡ %.1f ms | %s | %s" % [elapsed_ms, score_txt, details]

	# Target Challenge evaluation
	if target_digit >= 0:
		total_tests += 1
		var is_correct = (recognized == str(target_digit))
		if is_correct:
			correct_tests += 1
			if verdict_badge:
				verdict_badge.text = "✓ RICHTIG!"
				verdict_badge.modulate = Color("#4ade80")
		else:
			if verdict_badge:
				verdict_badge.text = "✗ FALSCH (Ziel war %d)" % target_digit
				verdict_badge.modulate = Color("#f87171")
		_update_target_display()
	else:
		if verdict_badge:
			verdict_badge.text = "ERKANNT: " + recognized
			verdict_badge.modulate = Color("#38bdf8")

	_update_stroke_metrics()

func _update_stroke_metrics() -> void:
	var total_pts: int = 0
	for s in strokes:
		total_pts += s.size()
	if btn_clear:
		btn_clear.text = "🗑️ Leeren (%d Striche, %d Pkt)" % [strokes.size(), total_pts]

func _serialize_strokes_to_json() -> String:
	var root_arr: Array = []
	for s_idx in range(strokes.size()):
		var s = strokes[s_idx]
		var times = strokes_times[s_idx] if s_idx < strokes_times.size() else []
		var stroke_points: Array = []
		for p_idx in range(s.size()):
			var pt = s[p_idx]
			var t = times[p_idx] if p_idx < times.size() else Time.get_ticks_msec()
			stroke_points.append({"x": pt.x, "y": pt.y, "t": t})
		root_arr.append(stroke_points)
	return JSON.stringify(root_arr)
