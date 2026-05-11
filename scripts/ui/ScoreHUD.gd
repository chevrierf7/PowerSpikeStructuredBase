class_name ScoreHUD
extends Control

var player1_panel: PanelContainer
var player2_panel: PanelContainer
var player1_name_label: Label
var player2_name_label: Label
var player1_score_label: Label
var player2_score_label: Label
var player1_sets_label: Label
var player2_sets_label: Label
var player1_service_label: Label
var player2_service_label: Label
var mode_label: Label
var center_label: Label
var point_label: Label
var service_label: Label
var point_tween: Tween
var flash_tween: Tween
var entry_tween: Tween
var last_point_signature: String = ""
var last_player1_score: int = -1
var last_player2_score: int = -1
var last_server_name: String = ""
var current_server_name: String = ""
var player1_accent := BLUE_ACCENT
var player2_accent := ORANGE_ACCENT
var energy_phase: float = 0.0
var point_flash_strength: float = 0.0
var point_flash_side: int = 0
var hud_settings: Dictionary = {}

const BLUE_ACCENT := Color(0.22, 0.78, 1.0, 1.0)
const ORANGE_ACCENT := Color(1.0, 0.72, 0.16, 1.0)
const BASE_WIDTH := 920.0
const TOP_HEIGHT := 122.0
const INFO_Y := 128.0
const INFO_HEIGHT := 42.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_settings = default_hud_settings()
	_build()
	_update_layout()
	get_viewport().size_changed.connect(_update_layout)
	modulate.a = 0.0
	entry_tween = create_tween()
	entry_tween.tween_property(self, "modulate:a", _hud_value("opacity"), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	energy_phase = fmod(energy_phase + delta, 10.0)
	if center_label != null:
		var pulse: float = 1.0 + sin(energy_phase * 5.0) * 0.035
		center_label.scale = Vector2.ONE * pulse
	queue_redraw()

func default_hud_settings() -> Dictionary:
	return {
		"scale": 0.92,
		"offset_x": 0.0,
		"offset_y": 0.0,
		"opacity": 1.0,
		"panel_darkness": 0.88,
		"glow": 1.0,
		"details": 0.75,
		"noise": 0.55,
		"score_size": 86.0,
		"name_size": 36.0,
		"sets_size": 18.0,
		"service_size": 24.0,
		"service_y": 0.0,
		"center_size": 44.0,
		"point_x": 0.0,
		"point_y": 0.0,
		"point_width": 318.0,
		"point_height": 42.0,
		"point_text_size": 32.0,
		"point_opacity": 1.0
	}

func apply_hud_settings(settings: Dictionary) -> void:
	var defaults: Dictionary = default_hud_settings()
	for key in defaults.keys():
		hud_settings[key] = settings.get(key, defaults[key])
	modulate.a = _hud_value("opacity")
	if player1_score_label != null:
		player1_score_label.add_theme_font_size_override("font_size", int(round(_hud_value("score_size"))))
	if player2_score_label != null:
		player2_score_label.add_theme_font_size_override("font_size", int(round(_hud_value("score_size"))))
	if player1_name_label != null:
		player1_name_label.add_theme_font_size_override("font_size", int(round(_hud_value("name_size"))))
	if player2_name_label != null:
		player2_name_label.add_theme_font_size_override("font_size", int(round(_hud_value("name_size"))))
	if player1_sets_label != null:
		player1_sets_label.add_theme_font_size_override("font_size", int(round(_hud_value("sets_size"))))
	if player2_sets_label != null:
		player2_sets_label.add_theme_font_size_override("font_size", int(round(_hud_value("sets_size"))))
	if service_label != null:
		service_label.add_theme_font_size_override("font_size", int(round(_hud_value("service_size"))))
	if center_label != null:
		center_label.add_theme_font_size_override("font_size", int(round(_hud_value("center_size"))))
	if point_label != null:
		point_label.add_theme_font_size_override("font_size", int(round(_hud_value("point_text_size"))))
		point_label.custom_minimum_size = Vector2(_hud_value("point_width"), _hud_value("point_height"))
	_update_layout()
	queue_redraw()

func setup_profiles(p1_profile: PlayerProfile, p2_profile: PlayerProfile) -> void:
	player1_accent = p1_profile.color_primary if p1_profile != null else BLUE_ACCENT
	player2_accent = p2_profile.color_primary if p2_profile != null else ORANGE_ACCENT
	if player1_sets_label != null and p1_profile != null:
		player1_sets_label.add_theme_color_override("font_color", p1_profile.color_accent)
	if player2_sets_label != null and p2_profile != null:
		player2_sets_label.add_theme_color_override("font_color", p2_profile.color_accent)
	queue_redraw()

func _hud_value(key: String) -> float:
	if hud_settings.is_empty():
		hud_settings = default_hud_settings()
	var defaults: Dictionary = default_hud_settings()
	return float(hud_settings.get(key, defaults[key]))

func update_score(
	player1_name: String,
	player1_score: int,
	player1_sets: int,
	player2_name: String,
	player2_score: int,
	player2_sets: int,
	server_name: String,
	point_winner_name: String
) -> void:
	player1_name_label.text = player1_name.to_upper()
	player2_name_label.text = player2_name.to_upper()
	player1_score_label.text = str(player1_score)
	player2_score_label.text = str(player2_score)
	player1_sets_label.text = "SETS / %d" % player1_sets
	player2_sets_label.text = "SETS / %d" % player2_sets
	mode_label.text = "SIMPLE"
	var server_changed: bool = last_server_name != "" and server_name != last_server_name
	current_server_name = server_name
	service_label.text = "SERVICE " + server_name.to_upper()
	var player1_serves: bool = server_name == player1_name
	var player2_serves: bool = server_name == player2_name
	player1_service_label.visible = false
	player2_service_label.visible = false
	_apply_player_style(player1_panel, player1_name_label, player1_score_label, player1_serves, false)
	_apply_player_style(player2_panel, player2_name_label, player2_score_label, player2_serves, true)
	var point_signature: String = "%s:%d:%d:%d:%d" % [point_winner_name, player1_score, player1_sets, player2_score, player2_sets]
	if point_winner_name != "" and point_signature != last_point_signature:
		_play_point_flash(point_winner_name)
	last_point_signature = point_signature
	if last_player1_score >= 0 and player1_score != last_player1_score:
		_pulse_score(player1_score_label, false)
	if last_player2_score >= 0 and player2_score != last_player2_score:
		_pulse_score(player2_score_label, true)
	if server_changed:
		_pulse_service(player2_serves)
	last_server_name = server_name
	last_player1_score = player1_score
	last_player2_score = player2_score
	_update_layout()
	queue_redraw()

func _build() -> void:
	var stack := VBoxContainer.new()
	stack.name = "ScoreHudStack"
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 8)
	add_child(stack)

	var main_panel := PanelContainer.new()
	main_panel.name = "ScorePanel"
	main_panel.add_theme_stylebox_override("panel", _panel_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 2))
	stack.add_child(main_panel)

	var main_margin := MarginContainer.new()
	main_margin.add_theme_constant_override("margin_left", 18)
	main_margin.add_theme_constant_override("margin_right", 18)
	main_margin.add_theme_constant_override("margin_top", 0)
	main_margin.add_theme_constant_override("margin_bottom", 0)
	main_panel.add_child(main_margin)

	var main_box := VBoxContainer.new()
	main_box.add_theme_constant_override("separation", 0)
	main_margin.add_child(main_box)

	mode_label = _make_label("SIMPLE", 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	main_box.add_child(mode_label)

	var score_row := HBoxContainer.new()
	score_row.alignment = BoxContainer.ALIGNMENT_CENTER
	score_row.add_theme_constant_override("separation", 12)
	main_box.add_child(score_row)

	player1_panel = _make_player_panel(false)
	score_row.add_child(player1_panel)
	center_label = _make_label("VS", 44, Color(0.96, 1.0, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	center_label.custom_minimum_size = Vector2(112, 92)
	center_label.pivot_offset = Vector2(56, 46)
	score_row.add_child(center_label)
	player2_panel = _make_player_panel(true)
	score_row.add_child(player2_panel)

	var info_row := HBoxContainer.new()
	info_row.alignment = BoxContainer.ALIGNMENT_CENTER
	info_row.add_theme_constant_override("separation", 14)
	stack.add_child(info_row)

	point_label = _make_label("", int(round(_hud_value("point_text_size"))), ORANGE_ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	point_label.custom_minimum_size = Vector2(336, INFO_HEIGHT)
	point_label.modulate.a = 0.0
	point_label.add_theme_stylebox_override("normal", _panel_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 2))
	info_row.add_child(point_label)

	service_label = _make_label("SERVICE", 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	service_label.custom_minimum_size = Vector2(336, INFO_HEIGHT)
	service_label.add_theme_stylebox_override("normal", _panel_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 2))
	info_row.add_child(service_label)

func _make_player_panel(right_side: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(382, 96)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 2))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)
	var name_box := VBoxContainer.new()
	name_box.custom_minimum_size = Vector2(190, 80)
	name_box.alignment = BoxContainer.ALIGNMENT_CENTER
	var name_label := _make_label("", 36, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT if not right_side else HORIZONTAL_ALIGNMENT_RIGHT)
	var sets_label := _make_label("SETS / 0", 18, Color(0.70, 0.88, 1.0), HORIZONTAL_ALIGNMENT_LEFT if not right_side else HORIZONTAL_ALIGNMENT_RIGHT)
	var service_badge := _make_label("SERVICE", 13, ORANGE_ACCENT, HORIZONTAL_ALIGNMENT_LEFT if not right_side else HORIZONTAL_ALIGNMENT_RIGHT)
	service_badge.visible = false
	name_box.add_child(name_label)
	name_box.add_child(sets_label)
	name_box.add_child(service_badge)
	var score_label := _make_label("0", 86, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	score_label.custom_minimum_size = Vector2(120, 86)
	score_label.pivot_offset = Vector2(60, 43)
	if right_side:
		row.add_child(score_label)
		row.add_child(name_box)
		player2_name_label = name_label
		player2_sets_label = sets_label
		player2_service_label = service_badge
		player2_score_label = score_label
	else:
		row.add_child(name_box)
		row.add_child(score_label)
		player1_name_label = name_label
		player1_sets_label = sets_label
		player1_service_label = service_badge
		player1_score_label = score_label
	return panel

func _apply_player_style(panel: PanelContainer, name_label: Label, score_label: Label, active_service: bool, right_side: bool) -> void:
	var accent: Color = player2_accent if right_side else player1_accent
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 2))
	name_label.add_theme_color_override("font_color", accent if active_service else Color.WHITE)
	score_label.add_theme_color_override("font_color", Color.WHITE)
	score_label.add_theme_color_override("font_outline_color", accent if active_service else Color(0.02, 0.04, 0.06, 0.95))
	queue_redraw()

func _pulse_score(score_label: Label, right_side: bool) -> void:
	var accent: Color = player2_accent if right_side else player1_accent
	score_label.scale = Vector2.ONE * 1.18
	score_label.modulate = Color(1.0, 1.0, 1.0, 1.0).lerp(accent, 0.35)
	var tween: Tween = create_tween()
	tween.tween_property(score_label, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(score_label, "modulate", Color.WHITE, 0.22)

func _pulse_service(right_side: bool) -> void:
	var accent: Color = player2_accent if right_side else player1_accent
	service_label.pivot_offset = service_label.size * 0.5
	service_label.scale = Vector2.ONE * 1.08
	service_label.modulate = Color.WHITE.lerp(accent, 0.38)
	var tween: Tween = create_tween()
	tween.tween_property(service_label, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(service_label, "modulate", Color.WHITE, 0.20)

func _play_point_flash(point_winner_name: String) -> void:
	if point_tween != null:
		point_tween.kill()
	if flash_tween != null:
		flash_tween.kill()
	point_label.text = "POINT " + point_winner_name.to_upper() + " !"
	point_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	point_tween = create_tween()
	point_tween.tween_property(point_label, "modulate:a", 1.0, 0.10)
	point_tween.tween_interval(0.85)
	point_tween.tween_property(point_label, "modulate:a", 0.0, 0.45)
	var right_side: bool = point_winner_name == player2_name_label.text.capitalize()
	var target_panel: PanelContainer = player2_panel if right_side else player1_panel
	point_flash_side = 1 if right_side else -1
	point_flash_strength = 1.0
	target_panel.modulate = Color(1.35, 1.25, 0.82, 1.0)
	flash_tween = create_tween()
	flash_tween.tween_property(target_panel, "modulate", Color.WHITE, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	flash_tween.parallel().tween_property(self, "point_flash_strength", 0.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	queue_redraw()

func _update_layout() -> void:
	if get_child_count() == 0:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var stack: VBoxContainer = get_child(0) as VBoxContainer
	var width: float = minf(viewport_size.x - 72.0, 1180.0)
	var scale_value: float = clampf(width / BASE_WIDTH, 0.34, 1.0) * _hud_value("scale")
	stack.scale = Vector2.ONE * scale_value
	stack.size = Vector2(BASE_WIDTH, 180.0)
	stack.position = Vector2((viewport_size.x - stack.size.x * scale_value) * 0.5 + _hud_value("offset_x"), maxf(12.0, viewport_size.y * 0.025) + _hud_value("offset_y"))
	player1_panel.pivot_offset = Vector2(191, 56)
	player2_panel.pivot_offset = Vector2(191, 56)
	player1_panel.rotation_degrees = -1.2
	player2_panel.rotation_degrees = 1.2
	queue_redraw()

func _draw() -> void:
	if get_child_count() == 0:
		return
	var stack: VBoxContainer = get_child(0) as VBoxContainer
	var origin: Vector2 = stack.position
	var s: float = stack.scale.x
	_draw_main_arcade_plate(origin, s)
	_draw_info_capsules(origin, s)
	_draw_point_flash(origin, s)

func _draw_main_arcade_plate(origin: Vector2, s: float) -> void:
	var left_rect: Rect2 = Rect2(origin + Vector2(0, 26) * s, Vector2(406, 96) * s)
	var right_rect: Rect2 = Rect2(origin + Vector2(514, 26) * s, Vector2(406, 96) * s)
	var center: Vector2 = _center_label_screen_center(origin, s)
	_draw_cut_panel(left_rect, player1_accent, false, current_server_name == player1_name_label.text.capitalize())
	_draw_cut_panel(right_rect, player2_accent, true, current_server_name == player2_name_label.text.capitalize())
	_draw_center_emblem(center, s)
	var bar_points: PackedVector2Array = PackedVector2Array([
		origin + Vector2(96, 0) * s,
		origin + Vector2(BASE_WIDTH - 96, 0) * s,
		origin + Vector2(BASE_WIDTH - 124, 28) * s,
		origin + Vector2(124, 28) * s
	])
	draw_polyline(_closed_points(bar_points), Color(0.82, 0.94, 1.0, 0.75), 2.0 * s, true)
	_draw_tech_marks(origin + Vector2(150, 9) * s, 220.0 * s, player1_accent, false)
	_draw_tech_marks(origin + Vector2(BASE_WIDTH - 370, 9) * s, 220.0 * s, player2_accent, true)
	_draw_speed_lines(left_rect, player1_accent, false)
	_draw_speed_lines(right_rect, player2_accent, true)
	_draw_score_burst(left_rect, player1_accent, false)
	_draw_score_burst(right_rect, player2_accent, true)

func _draw_cut_panel(rect: Rect2, accent: Color, mirror: bool, service_side: bool) -> void:
	var cut: float = 34.0 * rect.size.y / 112.0
	var points: PackedVector2Array
	if mirror:
		points = PackedVector2Array([
			Vector2(rect.position.x + cut, rect.position.y),
			Vector2(rect.end.x, rect.position.y),
			Vector2(rect.end.x - cut * 0.35, rect.end.y),
			Vector2(rect.position.x, rect.end.y),
			Vector2(rect.position.x + cut * 0.65, rect.position.y + rect.size.y * 0.52)
		])
	else:
		points = PackedVector2Array([
			rect.position,
			Vector2(rect.end.x - cut, rect.position.y),
			Vector2(rect.end.x, rect.position.y + rect.size.y * 0.52),
			Vector2(rect.end.x - cut * 0.65, rect.end.y),
			Vector2(rect.position.x + cut * 0.35, rect.end.y)
		])
	var panel_alpha: float = _hud_value("panel_darkness")
	var detail_alpha: float = _hud_value("details")
	var bg: Color = Color(0.008, 0.018, 0.034, panel_alpha)
	if service_side:
		bg = Color(0.075, 0.045, 0.006, panel_alpha) if mirror else Color(0.012, 0.032, 0.048, panel_alpha)
	draw_colored_polygon(points, bg)
	draw_polyline(_closed_points(points), accent, 3.0, true)
	draw_polyline(_offset_points(points, Vector2(0, 4)), Color(1.0, 1.0, 1.0, 0.20 * detail_alpha), 1.0, true)
	for i in range(10):
		var stripe_x: float = rect.position.x + (float(i) * 29.0 + (12.0 if mirror else 0.0)) * rect.size.x / 406.0
		var alpha: float = 0.08 + float(i % 3) * 0.025
		draw_line(Vector2(stripe_x, rect.position.y + 14), Vector2(stripe_x + (34.0 if mirror else -34.0), rect.end.y - 12), Color(accent.r, accent.g, accent.b, alpha * detail_alpha), 2.0, true)
	var glow_alpha: float = (0.18 + sin(energy_phase * 4.0) * 0.06) * _hud_value("glow")
	draw_polyline(_closed_points(points), Color(accent.r, accent.g, accent.b, glow_alpha), 8.0, true)
	_draw_noise(rect, accent)

func _draw_center_emblem(center: Vector2, s: float) -> void:
	var pulse: float = 1.0 + sin(energy_phase * 5.0) * 0.06
	var r: float = 38.0 * s * pulse
	var diamond: PackedVector2Array = PackedVector2Array([
		center + Vector2(0, -r),
		center + Vector2(r, 0),
		center + Vector2(0, r),
		center + Vector2(-r, 0)
	])
	draw_polyline(_closed_points(diamond), Color(0.82, 0.96, 1.0, 0.90), 2.5 * s, true)
	draw_polyline(_closed_points(diamond), Color(0.22, 0.78, 1.0, 0.28), 8.0 * s, true)

func _center_label_screen_center(origin: Vector2, s: float) -> Vector2:
	if center_label == null:
		return origin + Vector2(BASE_WIDTH * 0.5, 76) * s
	var label_rect: Rect2 = center_label.get_global_rect()
	if label_rect.size.x <= 1.0 or label_rect.size.y <= 1.0:
		return origin + Vector2(BASE_WIDTH * 0.5, 76) * s
	return label_rect.get_center()

func _draw_info_capsules(origin: Vector2, s: float) -> void:
	var y_offset: float = _hud_value("service_y")
	var point_rect: Rect2 = Rect2(origin + Vector2(96 + _hud_value("point_x"), INFO_Y + y_offset + _hud_value("point_y")) * s, Vector2(_hud_value("point_width"), _hud_value("point_height")) * s)
	var service_rect: Rect2 = Rect2(origin + Vector2(BASE_WIDTH - 414, INFO_Y + y_offset) * s, Vector2(318, INFO_HEIGHT) * s)
	_draw_capsule(point_rect, player1_accent, false)
	_draw_capsule(service_rect, player2_accent, true)

func _draw_point_flash(origin: Vector2, s: float) -> void:
	if point_flash_strength <= 0.01:
		return
	var accent: Color = player2_accent if point_flash_side > 0 else player1_accent
	var panel_x: float = 514.0 if point_flash_side > 0 else 0.0
	var flash_rect: Rect2 = Rect2(origin + Vector2(panel_x, 22) * s, Vector2(406, 112) * s)
	var alpha: float = 0.22 * point_flash_strength
	draw_rect(flash_rect.grow(10.0 * s), Color(accent.r, accent.g, accent.b, alpha), true)
	for i in range(7):
		var y: float = flash_rect.position.y + 12.0 * s + float(i) * 14.0 * s
		var length: float = (90.0 + float(i % 3) * 28.0) * s * point_flash_strength
		var start_x: float = flash_rect.end.x - length if point_flash_side > 0 else flash_rect.position.x + length
		var end_x: float = flash_rect.end.x + 18.0 * s if point_flash_side > 0 else flash_rect.position.x - 18.0 * s
		draw_line(Vector2(start_x, y), Vector2(end_x, y + 4.0 * s), Color(1.0, 1.0, 1.0, alpha + 0.06), 2.0 * s, true)

func _draw_capsule(rect: Rect2, accent: Color, mirror: bool) -> void:
	var cut: float = 30.0 * rect.size.y / INFO_HEIGHT
	var points: PackedVector2Array
	if mirror:
		points = PackedVector2Array([Vector2(rect.position.x + cut, rect.position.y), rect.end - Vector2(0, rect.size.y), rect.end - Vector2(cut, 0), Vector2(rect.position.x, rect.end.y), Vector2(rect.position.x + cut * 0.5, rect.position.y + rect.size.y * 0.5)])
	else:
		points = PackedVector2Array([rect.position, Vector2(rect.end.x - cut, rect.position.y), Vector2(rect.end.x, rect.position.y + rect.size.y * 0.5), Vector2(rect.end.x - cut * 0.5, rect.end.y), Vector2(rect.position.x + cut, rect.end.y)])
	var capsule_alpha: float = _hud_value("panel_darkness") * 0.86
	if accent == player1_accent:
		capsule_alpha *= _hud_value("point_opacity")
	draw_colored_polygon(points, Color(0.008, 0.012, 0.020, capsule_alpha))
	draw_polyline(_closed_points(points), accent, 2.0, true)
	draw_polyline(_closed_points(points), Color(accent.r, accent.g, accent.b, 0.24 * _hud_value("glow")), 7.0, true)

func _draw_speed_lines(rect: Rect2, accent: Color, mirror: bool) -> void:
	for i in range(8):
		var y: float = rect.position.y + 16.0 + float(i) * 10.0
		var x1: float = rect.position.x + (22.0 + float(i % 4) * 22.0 if not mirror else rect.size.x - 28.0 - float(i % 4) * 22.0)
		var len: float = 58.0 + float(i % 3) * 16.0
		var x2: float = x1 + (-len if not mirror else len)
		draw_line(Vector2(x1, y), Vector2(x2, y + 5.0), Color(accent.r, accent.g, accent.b, 0.18 * _hud_value("details")), 2.0, true)

func _draw_score_burst(rect: Rect2, accent: Color, mirror: bool) -> void:
	var center_x: float = rect.end.x - 96.0 if not mirror else rect.position.x + 96.0
	var center: Vector2 = Vector2(center_x, rect.position.y + rect.size.y * 0.52)
	for i in range(11):
		var angle: float = -1.15 + float(i) * 0.23
		var direction: float = -1.0 if not mirror else 1.0
		var start: Vector2 = center + Vector2(cos(angle) * 24.0 * direction, sin(angle) * 18.0)
		var end: Vector2 = center + Vector2(cos(angle) * 72.0 * direction, sin(angle) * 52.0)
		draw_line(start, end, Color(accent.r, accent.g, accent.b, 0.12 * _hud_value("details")), 2.0, true)

func _draw_noise(rect: Rect2, accent: Color) -> void:
	for i in range(18):
		var x: float = rect.position.x + fmod(float(i * 37), rect.size.x)
		var y: float = rect.position.y + fmod(float(i * 19), rect.size.y)
		var radius: float = 1.0 + float(i % 3) * 0.45
		draw_circle(Vector2(x, y), radius, Color(accent.r, accent.g, accent.b, 0.055 * _hud_value("noise")))

func _draw_tech_marks(origin: Vector2, line_width: float, accent: Color, mirror: bool) -> void:
	for i in range(9):
		var x: float = origin.x + (line_width - float(i) * 16.0 if mirror else float(i) * 16.0)
		draw_line(Vector2(x, origin.y), Vector2(x + (10.0 if mirror else -10.0), origin.y + 18.0), Color(accent.r, accent.g, accent.b, 0.34 * _hud_value("details")), 2.0, true)
	for i in range(14):
		var dot_x: float = origin.x + float(i * 13)
		draw_circle(Vector2(dot_x, origin.y + 105.0 + sin(float(i) + energy_phase * 2.0) * 2.0), 1.2, Color(accent.r, accent.g, accent.b, 0.22 * _hud_value("details")))

func _draw_shuttle_icon(center: Vector2, scale_value: float, color: Color) -> void:
	var head_radius: float = 8.0 * scale_value
	draw_circle(center + Vector2(-12, 10) * scale_value, head_radius, color)
	for i in range(5):
		var angle: float = -0.95 + float(i) * 0.22
		var base: Vector2 = center + Vector2(-4, 2) * scale_value
		var tip: Vector2 = center + Vector2(cos(angle) * 34.0, sin(angle) * 34.0 - 8.0) * scale_value
		draw_line(base, tip, Color(color.r, color.g, color.b, 0.92), 3.0 * scale_value, true)
		draw_circle(tip, 2.0 * scale_value, Color(color.r, color.g, color.b, 0.75))

func _offset_points(points: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var shifted: PackedVector2Array = PackedVector2Array()
	for i in range(points.size()):
		shifted.append(points[i] + offset)
	return shifted

func _closed_points(points: PackedVector2Array) -> PackedVector2Array:
	var closed: PackedVector2Array = PackedVector2Array(points)
	if points.size() > 0:
		closed.append(points[0])
	return closed

func _make_label(text: String, font_size: int, color: Color, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_color_override("font_outline_color", Color(0.01, 0.015, 0.02, 0.95))
	return label

func _panel_style(bg: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style
