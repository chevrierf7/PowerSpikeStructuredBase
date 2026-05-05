class_name GameHud
extends CanvasLayer

signal serve_pressed
signal lob_pressed
signal drop_pressed
signal smash_pressed
signal start_game(settings: Dictionary)
signal resume_requested
signal free_camera_requested
signal main_menu_requested
signal quit_requested
signal hitbox_toggled
signal player_ai_toggled
signal difficulty_toggled
signal graphics_toggled
signal camera_preset_selected(slot: int)
signal camera_preview_changed(settings: Dictionary)
signal camera_preset_saved(slot: int, settings: Dictionary)

var move_vector := Vector2.ZERO
var aim_vector := Vector2.ZERO

var score_label := Label.new()
var status_label := Label.new()
var pause_label := Label.new()
var main_menu_overlay := Control.new()
var pause_menu_overlay := Control.new()
var player_control_option := OptionButton.new()
var difficulty_option := OptionButton.new()
var match_mode_option := OptionButton.new()
var start_camera_option := OptionButton.new()
var timing_label := Label.new()
var aim_label := Label.new()
var hint_label := Label.new()
var hitbox_button := Button.new()
var player_ai_button := Button.new()
var difficulty_button := Button.new()
var graphics_button := Button.new()
var debug_panel_button := Button.new()
var debug_panel := Panel.new()
var camera_button := Button.new()
var controls_visibility_button := Button.new()
var camera_panel := Panel.new()
var camera_scroll := ScrollContainer.new()
var camera_content := Control.new()
var camera_slot_buttons: Array[Button] = []
var camera_sliders := {}
var selected_camera_slot := 0
var updating_camera_controls := false
var joystick_area := Control.new()
var joystick_base := Panel.new()
var joystick_knob := Panel.new()
var action_panel := Control.new()
var aim_area := Control.new()
var aim_base := Panel.new()
var aim_knob := Panel.new()
var joystick_touch_id := -1
var aim_touch_id := -1
var joystick_center := Vector2.ZERO
var aim_pad_center := Vector2.ZERO
var game_controls_visible := false
var match_setup_settings_path := "user://match_setup.cfg"

func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	_build_labels(root)
	_build_debug_controls(root)
	_build_mobile_controls(root)
	_build_main_menu(root)
	_build_pause_menu(root)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and joystick_area.get_global_rect().has_point(touch.position):
			joystick_touch_id = touch.index
			_update_joystick(touch.position)
			get_viewport().set_input_as_handled()
		elif touch.pressed and aim_area.get_global_rect().has_point(touch.position):
			aim_touch_id = touch.index
			_update_aim_pad(touch.position)
			get_viewport().set_input_as_handled()
		elif not touch.pressed and touch.index == joystick_touch_id:
			_reset_joystick()
			get_viewport().set_input_as_handled()
		elif not touch.pressed and touch.index == aim_touch_id:
			_reset_aim_pad()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == joystick_touch_id:
			_update_joystick(drag.position)
			get_viewport().set_input_as_handled()
		elif drag.index == aim_touch_id:
			_update_aim_pad(drag.position)
			get_viewport().set_input_as_handled()

func update_match(mode: String, status: String, rally: String, player_score: int, player_sets: int, opponent_score: int, opponent_sets: int) -> void:
	var mode_name: String = "Double" if mode == "doubles" else "Simple"
	score_label.text = "%s | Kai %d (%d)  -  Mina %d (%d)" % [mode_name, player_score, player_sets, opponent_score, opponent_sets]
	status_label.text = "%s | %s" % [status, rally]

func set_timing(text: String) -> void:
	timing_label.text = ""

func set_aim_label(text: String) -> void:
	aim_label.text = ""

func set_pause_visible(enabled: bool) -> void:
	pause_label.visible = enabled
	pause_menu_overlay.visible = enabled

func show_main_menu() -> void:
	main_menu_overlay.visible = true
	pause_menu_overlay.visible = false
	joystick_area.visible = false
	action_panel.visible = false
	camera_panel.visible = false
	debug_panel.visible = false

func hide_menus() -> void:
	main_menu_overlay.visible = false
	pause_menu_overlay.visible = false
	pause_label.visible = false
	joystick_area.visible = game_controls_visible
	action_panel.visible = game_controls_visible

func _build_labels(root: Control) -> void:
	score_label.position = Vector2(24, 18)
	score_label.add_theme_font_size_override("font_size", 26)
	score_label.add_theme_color_override("font_color", Color(1.0, 0.98, 0.90))
	score_label.add_theme_color_override("font_shadow_color", Color(0.03, 0.035, 0.04, 0.85))
	score_label.add_theme_constant_override("shadow_offset_x", 2)
	score_label.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(score_label)
	status_label.position = Vector2(24, 54)
	status_label.add_theme_font_size_override("font_size", 18)
	status_label.add_theme_color_override("font_color", Color(0.95, 0.96, 0.90))
	status_label.add_theme_color_override("font_shadow_color", Color(0.03, 0.035, 0.04, 0.85))
	status_label.add_theme_constant_override("shadow_offset_x", 2)
	status_label.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(status_label)
	pause_label.anchor_left = 0.5
	pause_label.anchor_top = 0.0
	pause_label.anchor_right = 0.5
	pause_label.anchor_bottom = 0.0
	pause_label.offset_left = -170.0
	pause_label.offset_top = 18.0
	pause_label.offset_right = 170.0
	pause_label.offset_bottom = 74.0
	pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_label.text = "PAUSE - camera libre"
	pause_label.visible = false
	pause_label.add_theme_font_size_override("font_size", 24)
	pause_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.72))
	pause_label.add_theme_color_override("font_shadow_color", Color(0.02, 0.02, 0.025, 0.92))
	pause_label.add_theme_constant_override("shadow_offset_x", 2)
	pause_label.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(pause_label)
	timing_label.position = Vector2(24, 86)
	timing_label.add_theme_font_size_override("font_size", 24)
	timing_label.visible = false
	root.add_child(timing_label)
	aim_label.position = Vector2(24, 120)
	aim_label.add_theme_font_size_override("font_size", 16)
	root.add_child(aim_label)
	hint_label.position = Vector2(24, 144)
	hint_label.text = ""
	hint_label.add_theme_font_size_override("font_size", 14)
	root.add_child(hint_label)

func _build_main_menu(root: Control) -> void:
	main_menu_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(main_menu_overlay)
	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.02, 0.025, 0.028, 0.72)
	main_menu_overlay.add_child(backdrop)
	var panel := Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -210.0
	panel.offset_top = -262.0
	panel.offset_right = 210.0
	panel.offset_bottom = 286.0
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.07, 0.08, 0.09, 0.94), Color(1, 1, 1, 0.18), 8))
	main_menu_overlay.add_child(panel)
	var title := Label.new()
	title.text = "Power Spike"
	title.position = Vector2(34, 30)
	title.size = Vector2(352, 46)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1.0, 0.93, 0.70))
	panel.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Badminton arcade"
	subtitle.position = Vector2(34, 78)
	subtitle.size = Vector2(352, 28)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 17)
	subtitle.add_theme_color_override("font_color", Color(0.86, 0.90, 0.88))
	panel.add_child(subtitle)
	_add_menu_option(panel, "Kai", player_control_option, Vector2(52, 126), ["Joueur", "IA"])
	_add_menu_option(panel, "Niveau", difficulty_option, Vector2(52, 184), ["Loisir", "Club", "Elite"])
	difficulty_option.select(1)
	_add_menu_option(panel, "Mode", match_mode_option, Vector2(52, 242), ["Simple", "Double"])
	_add_menu_option(panel, "Camera", start_camera_option, Vector2(52, 300), ["Terrain", "Dos joueur"])
	_load_match_setup_settings()
	panel.add_child(_menu_button("Lancer match", Vector2(88, 360), func() -> void:
		var settings := get_main_menu_settings()
		_save_match_setup_settings(settings)
		start_game.emit(settings)
	))
	panel.add_child(_menu_button("Options", Vector2(88, 416), func() -> void:
		debug_panel.visible = true
		debug_panel.move_to_front()
	))
	panel.add_child(_menu_button("Quitter", Vector2(88, 472), func() -> void: quit_requested.emit()))

func get_main_menu_settings() -> Dictionary:
	return {
		"player_ai_enabled": player_control_option.selected == 1,
		"difficulty": ["loisir", "club", "elite"][difficulty_option.selected],
		"mode": "doubles" if match_mode_option.selected == 1 else "singles",
		"camera_slot": 3 if start_camera_option.selected == 1 else 0
	}

func _load_match_setup_settings() -> void:
	var config := ConfigFile.new()
	if config.load(match_setup_settings_path) != OK:
		return
	player_control_option.select(1 if bool(config.get_value("match", "player_ai_enabled", false)) else 0)
	var difficulty := String(config.get_value("match", "difficulty", "club"))
	difficulty_option.select({"loisir": 0, "club": 1, "elite": 2}.get(difficulty, 1))
	var mode := String(config.get_value("match", "mode", "singles"))
	match_mode_option.select(1 if mode == "doubles" else 0)
	var camera_slot := int(config.get_value("match", "camera_slot", 0))
	start_camera_option.select(1 if camera_slot == 3 else 0)

func _save_match_setup_settings(settings: Dictionary) -> void:
	var config := ConfigFile.new()
	config.set_value("match", "player_ai_enabled", bool(settings.get("player_ai_enabled", false)))
	config.set_value("match", "difficulty", String(settings.get("difficulty", "club")))
	config.set_value("match", "mode", String(settings.get("mode", "singles")))
	config.set_value("match", "camera_slot", int(settings.get("camera_slot", 0)))
	config.save(match_setup_settings_path)

func _add_menu_option(root: Control, label_text: String, option: OptionButton, pos: Vector2, items: Array[String]) -> void:
	var label := Label.new()
	label.text = label_text
	label.position = pos
	label.size = Vector2(120, 26)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.86, 0.90, 0.88))
	root.add_child(label)
	option.position = pos + Vector2(118, -6)
	option.size = Vector2(174, 34)
	option.add_theme_font_size_override("font_size", 15)
	option.add_theme_stylebox_override("normal", _button_style(Color(0.12, 0.14, 0.16, 0.96)))
	for item in items:
		option.add_item(item)
	root.add_child(option)

func _build_pause_menu(root: Control) -> void:
	pause_menu_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_menu_overlay.visible = false
	root.add_child(pause_menu_overlay)
	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.02, 0.025, 0.028, 0.46)
	pause_menu_overlay.add_child(backdrop)
	var panel := Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -190.0
	panel.offset_top = -148.0
	panel.offset_right = 190.0
	panel.offset_bottom = 148.0
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.07, 0.08, 0.09, 0.94), Color(1, 1, 1, 0.18), 8))
	pause_menu_overlay.add_child(panel)
	var title := Label.new()
	title.text = "Pause"
	title.position = Vector2(38, 26)
	title.size = Vector2(304, 38)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.93, 0.70))
	panel.add_child(title)
	panel.add_child(_menu_button("Reprendre", Vector2(78, 82), func() -> void: resume_requested.emit()))
	panel.add_child(_menu_button("Camera libre", Vector2(78, 138), func() -> void: free_camera_requested.emit()))
	panel.add_child(_menu_button("Menu principal", Vector2(78, 194), func() -> void: main_menu_requested.emit()))
	panel.add_child(_menu_button("Quitter", Vector2(78, 250), func() -> void: quit_requested.emit()))

func _menu_button(text: String, pos: Vector2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = pos
	button.size = Vector2(244, 42)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_stylebox_override("normal", _button_style(Color(0.12, 0.14, 0.16, 0.96)))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.17, 0.22, 0.25, 0.98)))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.22, 0.29, 0.32, 1.0)))
	button.pressed.connect(callback)
	return button

func set_hitbox_debug(enabled: bool) -> void:
	hitbox_button.text = "Hitbox ON" if enabled else "Hitbox OFF"

func set_player_ai(enabled: bool) -> void:
	player_ai_button.text = "Kai IA" if enabled else "Kai joueur"

func set_difficulty(label: String) -> void:
	difficulty_button.text = "Niveau " + label

func set_graphics_mode(label: String) -> void:
	graphics_button.text = label

func _build_debug_controls(root: Control) -> void:
	debug_panel_button.anchor_left = 1.0
	debug_panel_button.anchor_top = 0.0
	debug_panel_button.anchor_right = 1.0
	debug_panel_button.anchor_bottom = 0.0
	debug_panel_button.offset_left = -138.0
	debug_panel_button.offset_top = 18.0
	debug_panel_button.offset_right = -18.0
	debug_panel_button.offset_bottom = 54.0
	debug_panel_button.text = "Options"
	debug_panel_button.add_theme_font_size_override("font_size", 14)
	debug_panel_button.add_theme_stylebox_override("normal", _button_style(Color(0.11, 0.12, 0.14, 0.78)))
	debug_panel_button.add_theme_stylebox_override("pressed", _button_style(Color(0.22, 0.29, 0.36, 0.94)))
	debug_panel_button.pressed.connect(_toggle_debug_panel)
	root.add_child(debug_panel_button)

	debug_panel.anchor_left = 1.0
	debug_panel.anchor_top = 0.0
	debug_panel.anchor_right = 1.0
	debug_panel.anchor_bottom = 0.0
	debug_panel.offset_left = -150.0
	debug_panel.offset_top = 60.0
	debug_panel.offset_right = -18.0
	debug_panel.offset_bottom = 298.0
	debug_panel.visible = false
	debug_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.09, 0.10, 0.86), Color(1, 1, 1, 0.18), 8))
	root.add_child(debug_panel)

	hitbox_button.position = Vector2(8, 8)
	hitbox_button.size = Vector2(116, 32)
	hitbox_button.text = "Hitbox OFF"
	hitbox_button.add_theme_font_size_override("font_size", 14)
	hitbox_button.add_theme_stylebox_override("normal", _button_style(Color(0.11, 0.12, 0.14, 0.78)))
	hitbox_button.add_theme_stylebox_override("pressed", _button_style(Color(0.22, 0.29, 0.36, 0.94)))
	hitbox_button.pressed.connect(func() -> void: hitbox_toggled.emit())
	debug_panel.add_child(hitbox_button)
	player_ai_button.position = Vector2(8, 46)
	player_ai_button.size = Vector2(116, 32)
	player_ai_button.text = "Kai joueur"
	player_ai_button.add_theme_font_size_override("font_size", 14)
	player_ai_button.add_theme_stylebox_override("normal", _button_style(Color(0.11, 0.12, 0.14, 0.78)))
	player_ai_button.add_theme_stylebox_override("pressed", _button_style(Color(0.22, 0.29, 0.36, 0.94)))
	player_ai_button.pressed.connect(func() -> void: player_ai_toggled.emit())
	debug_panel.add_child(player_ai_button)
	difficulty_button.position = Vector2(8, 84)
	difficulty_button.size = Vector2(116, 32)
	difficulty_button.text = "Niveau Club"
	difficulty_button.add_theme_font_size_override("font_size", 14)
	difficulty_button.add_theme_stylebox_override("normal", _button_style(Color(0.11, 0.12, 0.14, 0.78)))
	difficulty_button.add_theme_stylebox_override("pressed", _button_style(Color(0.22, 0.29, 0.36, 0.94)))
	difficulty_button.pressed.connect(func() -> void: difficulty_toggled.emit())
	debug_panel.add_child(difficulty_button)

	graphics_button.position = Vector2(8, 122)
	graphics_button.size = Vector2(116, 32)
	graphics_button.text = "Render"
	graphics_button.add_theme_font_size_override("font_size", 14)
	graphics_button.add_theme_stylebox_override("normal", _button_style(Color(0.11, 0.12, 0.14, 0.78)))
	graphics_button.add_theme_stylebox_override("pressed", _button_style(Color(0.22, 0.29, 0.36, 0.94)))
	graphics_button.pressed.connect(func() -> void: graphics_toggled.emit())
	debug_panel.add_child(graphics_button)

	camera_button.position = Vector2(8, 160)
	camera_button.size = Vector2(116, 32)
	camera_button.text = "Camera"
	camera_button.add_theme_font_size_override("font_size", 14)
	camera_button.add_theme_stylebox_override("normal", _button_style(Color(0.11, 0.12, 0.14, 0.78)))
	camera_button.add_theme_stylebox_override("pressed", _button_style(Color(0.22, 0.29, 0.36, 0.94)))
	camera_button.pressed.connect(_toggle_camera_panel)
	debug_panel.add_child(camera_button)

	controls_visibility_button.position = Vector2(8, 198)
	controls_visibility_button.size = Vector2(116, 32)
	controls_visibility_button.text = "Masquer"
	controls_visibility_button.add_theme_font_size_override("font_size", 14)
	controls_visibility_button.add_theme_stylebox_override("normal", _button_style(Color(0.11, 0.12, 0.14, 0.78)))
	controls_visibility_button.add_theme_stylebox_override("pressed", _button_style(Color(0.22, 0.29, 0.36, 0.94)))
	controls_visibility_button.pressed.connect(_toggle_game_controls)
	debug_panel.add_child(controls_visibility_button)
	_build_camera_panel(root)

func _build_camera_panel(root: Control) -> void:
	camera_panel.anchor_left = 1.0
	camera_panel.anchor_top = 0.0
	camera_panel.anchor_right = 1.0
	camera_panel.anchor_bottom = 1.0
	camera_panel.offset_left = -338.0
	camera_panel.offset_top = 188.0
	camera_panel.offset_right = -18.0
	camera_panel.offset_bottom = -18.0
	camera_panel.visible = false
	camera_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.09, 0.10, 0.90), Color(1, 1, 1, 0.20), 8))
	root.add_child(camera_panel)

	camera_scroll.anchor_left = 0.0
	camera_scroll.anchor_top = 0.0
	camera_scroll.anchor_right = 1.0
	camera_scroll.anchor_bottom = 1.0
	camera_scroll.offset_left = 0.0
	camera_scroll.offset_top = 0.0
	camera_scroll.offset_right = 0.0
	camera_scroll.offset_bottom = 0.0
	camera_panel.add_child(camera_scroll)

	camera_content.custom_minimum_size = Vector2(318, 650)
	camera_scroll.add_child(camera_content)

	var title := Label.new()
	title.text = "Reglage camera"
	title.position = Vector2(18, 14)
	title.add_theme_font_size_override("font_size", 18)
	camera_content.add_child(title)

	for i in range(4):
		var slot_button := Button.new()
		slot_button.text = _camera_slot_label(i)
		slot_button.position = Vector2(18 + i * 72, 48)
		slot_button.size = Vector2(66, 34)
		slot_button.add_theme_font_size_override("font_size", 13)
		slot_button.add_theme_stylebox_override("normal", _button_style(Color(0.14, 0.15, 0.17, 0.90)))
		slot_button.add_theme_stylebox_override("pressed", _button_style(Color(0.25, 0.31, 0.38, 0.96)))
		slot_button.pressed.connect(_select_camera_slot.bind(i))
		camera_slot_buttons.append(slot_button)
		camera_content.add_child(slot_button)

	_add_camera_slider("distance", "Distance", 4.0, 11.0, 0.1, 6.9, 94.0)
	_add_camera_slider("height", "Hauteur", 0.15, 10.5, 0.05, 7.8, 142.0)
	_add_camera_slider("focus", "Inclinaison", 0.1, 2.4, 0.05, 0.45, 190.0)
	_add_camera_slider("follow_y", "Suivi haut/bas", 0.0, 1.0, 0.05, 1.0, 238.0)
	_add_camera_slider("follow_side", "Suivi lateral volant", 0.0, 1.0, 0.05, 0.0, 286.0)
	_add_camera_slider("look_z", "Regard volant Z", 0.0, 1.0, 0.05, 0.18, 334.0)
	_add_camera_slider("follow_x", "Suivi longitudinal", 0.0, 1.0, 0.05, 0.0, 382.0)
	_add_camera_slider("look_x", "Regard volant X", 0.0, 1.0, 0.05, 0.0, 430.0)
	_add_camera_slider("side", "Decalage longitudinal", -3.0, 3.0, 0.1, 0.0, 478.0)
	_add_camera_slider("follow", "Vitesse", 0.0, 12.0, 0.1, 6.0, 526.0)
	_add_camera_slider("fov", "FOV", 38.0, 74.0, 1.0, 58.0, 574.0)

	var save_button := Button.new()
	save_button.text = "Valider"
	save_button.position = Vector2(18, 604)
	save_button.size = Vector2(92, 30)
	save_button.add_theme_font_size_override("font_size", 13)
	save_button.add_theme_stylebox_override("normal", _button_style(Color(0.10, 0.32, 0.22, 0.96)))
	save_button.pressed.connect(func() -> void: camera_preset_saved.emit(selected_camera_slot, get_camera_settings()))
	camera_content.add_child(save_button)

	var reset_button := Button.new()
	reset_button.text = "Annuler"
	reset_button.position = Vector2(118, 604)
	reset_button.size = Vector2(92, 30)
	reset_button.add_theme_font_size_override("font_size", 13)
	reset_button.add_theme_stylebox_override("normal", _button_style(Color(0.18, 0.18, 0.20, 0.96)))
	reset_button.pressed.connect(func() -> void:
		camera_panel.visible = false
		camera_preset_selected.emit(selected_camera_slot)
	)
	camera_content.add_child(reset_button)

	var close_button := Button.new()
	close_button.text = "Fermer"
	close_button.position = Vector2(218, 604)
	close_button.size = Vector2(84, 30)
	close_button.add_theme_font_size_override("font_size", 13)
	close_button.add_theme_stylebox_override("normal", _button_style(Color(0.18, 0.18, 0.20, 0.96)))
	close_button.pressed.connect(func() -> void: camera_panel.visible = false)
	camera_content.add_child(close_button)

func _add_camera_slider(key: String, label_text: String, minimum: float, maximum: float, step: float, default_value: float, y: float) -> void:
	var label := Label.new()
	label.text = label_text
	label.position = Vector2(18, y)
	label.add_theme_font_size_override("font_size", 13)
	camera_content.add_child(label)

	var value_label := Label.new()
	value_label.text = str(default_value)
	value_label.position = Vector2(244, y)
	value_label.size = Vector2(58, 20)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 13)
	camera_content.add_child(value_label)

	var slider := HSlider.new()
	slider.position = Vector2(18, y + 20)
	slider.size = Vector2(284, 18)
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = default_value
	slider.value_changed.connect(func(value: float) -> void:
		value_label.text = "%.2f" % value
		if not updating_camera_controls:
			camera_preview_changed.emit(get_camera_settings())
	)
	camera_sliders[key] = { "slider": slider, "value_label": value_label }
	camera_content.add_child(slider)

func _toggle_camera_panel() -> void:
	camera_panel.visible = not camera_panel.visible
	if camera_panel.visible:
		debug_panel.visible = false
		camera_panel.move_to_front()

func _toggle_debug_panel() -> void:
	debug_panel.visible = not debug_panel.visible

func _toggle_game_controls() -> void:
	game_controls_visible = not game_controls_visible
	joystick_area.visible = game_controls_visible
	action_panel.visible = game_controls_visible
	controls_visibility_button.text = "Masquer" if game_controls_visible else "Afficher"

func _select_camera_slot(slot: int) -> void:
	selected_camera_slot = slot
	_update_camera_slot_buttons()
	camera_preset_selected.emit(slot)

func _update_camera_slot_buttons() -> void:
	for i in range(camera_slot_buttons.size()):
		camera_slot_buttons[i].text = "%s%s" % [_camera_slot_label(i), " *" if i == selected_camera_slot else ""]

func _camera_slot_label(slot: int) -> String:
	return "Dos" if slot == 3 else "Cam %d" % [slot + 1]

func set_camera_slot(slot: int, settings: Dictionary) -> void:
	selected_camera_slot = slot
	_update_camera_slot_buttons()
	updating_camera_controls = true
	for key in camera_sliders.keys():
		if settings.has(key):
			var entry: Dictionary = camera_sliders[key]
			var slider := entry["slider"] as HSlider
			var value_label := entry["value_label"] as Label
			slider.value = float(settings[key])
			value_label.text = "%.2f" % float(settings[key])
	updating_camera_controls = false

func get_camera_settings() -> Dictionary:
	var settings := {}
	for key in camera_sliders.keys():
		var entry: Dictionary = camera_sliders[key]
		var slider := entry["slider"] as HSlider
		settings[key] = float(slider.value)
	return settings

func _build_mobile_controls(root: Control) -> void:
	joystick_area.anchor_left = 0.0
	joystick_area.anchor_top = 1.0
	joystick_area.anchor_right = 0.0
	joystick_area.anchor_bottom = 1.0
	joystick_area.offset_left = 20.0
	joystick_area.offset_top = -210.0
	joystick_area.offset_right = 220.0
	joystick_area.offset_bottom = -10.0
	root.add_child(joystick_area)
	joystick_base.size = Vector2(150, 150)
	joystick_base.position = Vector2(25, 25)
	joystick_base.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.09, 0.10, 0.62), Color(1, 1, 1, 0.18), 75))
	joystick_area.add_child(joystick_base)
	joystick_knob.size = Vector2(64, 64)
	joystick_knob.position = Vector2(68, 68)
	joystick_knob.add_theme_stylebox_override("panel", _panel_style(Color(0.95, 0.96, 1.0, 0.32), Color(1, 1, 1, 0.5), 32))
	joystick_area.add_child(joystick_knob)
	joystick_center = joystick_area.global_position + Vector2(100, 100)

	action_panel.anchor_left = 1.0
	action_panel.anchor_top = 1.0
	action_panel.anchor_right = 1.0
	action_panel.anchor_bottom = 1.0
	action_panel.offset_left = -390.0
	action_panel.offset_top = -190.0
	action_panel.offset_right = -20.0
	action_panel.offset_bottom = -10.0
	root.add_child(action_panel)
	_build_aim_pad(action_panel)
	_add_touch_button(action_panel, "Serve", Vector2(145, 104), Vector2(96, 58), func() -> void: serve_pressed.emit())
	_add_touch_button(action_panel, "Lob", Vector2(145, 36), Vector2(96, 58), func() -> void: lob_pressed.emit())
	_add_touch_button(action_panel, "Amorti", Vector2(256, 72), Vector2(96, 58), func() -> void: drop_pressed.emit())
	_add_touch_button(action_panel, "Smash", Vector2(256, 4), Vector2(112, 58), func() -> void: smash_pressed.emit())
	joystick_area.visible = game_controls_visible
	action_panel.visible = game_controls_visible
	controls_visibility_button.text = "Masquer" if game_controls_visible else "Afficher"

func _build_aim_pad(root: Control) -> void:
	aim_area.position = Vector2(0, 22)
	aim_area.size = Vector2(132, 132)
	root.add_child(aim_area)
	aim_base.size = Vector2(124, 124)
	aim_base.position = Vector2(4, 4)
	aim_base.add_theme_stylebox_override("panel", _panel_style(Color(0.12, 0.10, 0.08, 0.62), Color(1.0, 0.86, 0.32, 0.28), 62))
	aim_area.add_child(aim_base)
	aim_knob.size = Vector2(50, 50)
	aim_knob.position = Vector2(41, 41)
	aim_knob.add_theme_stylebox_override("panel", _panel_style(Color(0.98, 0.82, 0.18, 0.44), Color(1.0, 0.95, 0.55, 0.7), 25))
	aim_area.add_child(aim_knob)
	aim_pad_center = aim_area.global_position + Vector2(66, 66)

func _add_touch_button(root: Control, text: String, pos: Vector2, size: Vector2, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.position = pos
	button.size = size
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_stylebox_override("normal", _button_style(Color(0.11, 0.12, 0.14, 0.88)))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.24, 0.30, 0.38, 0.96)))
	button.pressed.connect(callback)
	root.add_child(button)

func _update_joystick(pointer_position: Vector2) -> void:
	var local_vector := pointer_position - joystick_center
	if local_vector.length() > GameConfig.JOYSTICK_RADIUS:
		local_vector = local_vector.normalized() * GameConfig.JOYSTICK_RADIUS
	move_vector = local_vector / GameConfig.JOYSTICK_RADIUS
	joystick_knob.position = Vector2(68, 68) + local_vector

func _reset_joystick() -> void:
	joystick_touch_id = -1
	move_vector = Vector2.ZERO
	joystick_knob.position = Vector2(68, 68)

func _update_aim_pad(pointer_position: Vector2) -> void:
	var local_vector := pointer_position - aim_pad_center
	if local_vector.length() > GameConfig.AIM_PAD_RADIUS:
		local_vector = local_vector.normalized() * GameConfig.AIM_PAD_RADIUS
	aim_vector = local_vector / GameConfig.AIM_PAD_RADIUS
	aim_knob.position = Vector2(41, 41) + local_vector

func _reset_aim_pad() -> void:
	aim_touch_id = -1
	aim_vector = Vector2.ZERO
	aim_knob.position = Vector2(41, 41)

func _panel_style(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	return style

func _button_style(fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = Color(1, 1, 1, 0.16)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	return style
