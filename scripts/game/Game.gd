extends Node3D

var match_state := MatchState.new()
var player: PlayerCharacter
var opponent: PlayerCharacter
var shuttle: Shuttle
var landing_marker: MeshInstance3D
var ai_target_marker: MeshInstance3D
var camera := Camera3D.new()
var hud: GameHud
var render_tuning_panel: Node
var anime_fx_settings := {
	"enabled": true,
	"scale": 1.0,
	"opacity": 0.90,
	"duration": 0.15,
	"color": Color(0.10, 0.105, 0.11, 1.0),
	"billboard_enabled": true
}
var landing_marker_settings := {
	"enabled": true,
	"delay": 0.0,
	"duration": 0.20,
	"opacity": 0.78,
	"size_start": 0.70,
	"size_end": 1.0,
	"color": Color(0.98, 0.82, 0.18, 1.0),
	"height": 0.08
}
var landing_marker_requested_visible := false
var landing_marker_started_at := -10.0
var shuttle_service_attached := false
var service_shuttle_hold_settings := {}
var service_shuttle_hold_settings_by_side := {
	"player": {
		"forward": 0.0,
		"lateral": 0.0,
		"height": 0.0,
		"rot_x": 0.0,
		"rot_y": 0.0,
		"rot_z": 0.0
	},
	"opponent": {
		"forward": 0.0,
		"lateral": 0.0,
		"height": 0.0,
		"rot_x": 0.0,
		"rot_y": 0.0,
		"rot_z": 0.0
	}
}
var service_shuttle_hold_default_settings := {
	"forward": 0.0,
	"lateral": 0.0,
	"height": 0.0,
	"rot_x": 0.0,
	"rot_y": 0.0,
	"rot_z": 0.0
}

var status_text := "Pret a servir"
var camera_mode := "court"
var game_paused := false
var free_camera_mouse_look := false
var free_camera_angles := Vector2.ZERO
var free_camera_speed := 5.0
var camera_preset_slot := 0
var court_camera_preset_slot := 0
var camera_presets := []
var active_camera_settings := {}
var camera_settings_path := "user://camera_presets.cfg"
var current_aim_vector := Vector2.ZERO
var last_aim_vector := Vector2.ZERO
var last_aim_time := -10.0
var landing_will_be_out := false
var landing_pending := false
var landing_winner := ""
var landing_reason := ""
var landing_resolve_time := -1.0
var next_ai_action_time := -1.0
var ai_serve_time := -1.0
var opponent_reception_target := Vector3.ZERO
var opponent_has_reception_target := false
var opponent_recovery_target := Vector3.ZERO
var opponent_has_recovery_target := false
var opponent_recovery_urgency := 0.82
var opponent_recovery_unlocked_at := 0.0
var show_debug_hit_zones := false
var opponent_receiver_aggressiveness := 0.58
var difficulty_level := "club"
var player_ai_enabled := true
var player_ai_action_time := -1.0
var player_ai_serve_time := -1.0
var player_reception_target := Vector3.ZERO
var player_has_reception_target := false
var player_recovery_target := Vector3.ZERO
var player_has_recovery_target := false
var player_recovery_urgency := 0.82
var player_recovery_unlocked_at := 0.0
var rally_start_time := 0.0
var rally_start_server := ""
var rally_start_service_kind := ""
var stats_file_path := "user://ai_match_stats.csv"
var project_stats_file_path := "C:/Users/aho7/Documents/Codex/PowerSpikeStructuredBase/stats/ai_match_stats.csv"
const GYM_SCENE := "res://scenes/environment/Gym_JP_A.tscn"
const COURT_SCENE := "res://scenes/court/Court.tscn"
const RENDER_TUNING_SCENE := "res://scenes/debug/RenderTuningPanel.tscn"
const RACKET_IMPACT_FX_SCENE := "res://scenes/fx/RacketImpactFX.tscn"
const CAMERA_ROOM_X_LIMIT := 10.35
const CAMERA_ROOM_Z_LIMIT := 7.05
const CAMERA_ROOM_Y_MIN := 0.08
const CAMERA_ROOM_Y_MAX := 6.55

func _ready() -> void:
	randomize()
	add_to_group("anime_fx_receivers")
	add_to_group("service_shuttle_receivers")
	_ensure_runtime_input_actions()
	_load_camera_presets()
	_build_world()
	_reset_for_serve()
	_update_hud()

func _process(delta: float) -> void:
	_update_landing_marker_visual()
	if game_paused:
		_update_free_camera(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and (key.keycode == KEY_P or key.keycode == KEY_ESCAPE):
			_toggle_pause()
			get_viewport().set_input_as_handled()
	elif game_paused and event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_RIGHT:
			free_camera_mouse_look = mouse_button.pressed
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if free_camera_mouse_look else Input.MOUSE_MODE_VISIBLE
			get_viewport().set_input_as_handled()
	elif game_paused and free_camera_mouse_look and event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		free_camera_angles.x = clamp(free_camera_angles.x - motion.relative.y * 0.12, -86.0, 86.0)
		free_camera_angles.y -= motion.relative.x * 0.12
		camera.rotation_degrees = Vector3(free_camera_angles.x, free_camera_angles.y, 0.0)
		get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	if game_paused:
		return
	_update_pre_service_shuttle_hold()
	_ensure_ai_service_pending()
	_ensure_player_ai_service_pending()
	_update_aim_state()
	if player_ai_enabled:
		_update_player_ai_movement(delta)
	else:
		_move_player(delta)
	_update_opponent(delta)
	player.show_hit_zone_debug = show_debug_hit_zones
	opponent.show_hit_zone_debug = show_debug_hit_zones and match_state.rally_active and match_state.turn_side == "opponent" and shuttle.in_flight
	_update_body_orientation(delta)
	shuttle.update_flight(delta)
	_update_player_head_look()
	_update_reception_state()
	_update_landing_resolution()
	_update_camera(delta)
	_update_ai()
	_update_player_ai()
	if Input.is_action_just_pressed("serve"):
		try_serve()
	if Input.is_action_just_pressed("shot_lob"):
		try_hit("lob")
	if Input.is_action_just_pressed("shot_drop"):
		try_hit("drop")
	if Input.is_action_just_pressed("shot_smash"):
		try_hit("smash")
	if Input.is_action_just_pressed("toggle_match_mode"):
		_toggle_match_mode()
	if Input.is_action_just_pressed("toggle_camera"):
		_toggle_camera()

func _build_world() -> void:
	_add_visual_gym()
	_add_gameplay_court()
	player = PlayerCharacter.new()
	player.display_name = "Kai"
	player.accent_color = Color(0.1, 0.2, 1.0)
	player.speed = 6.4
	player.acceleration = 20.0
	player.braking = 26.0
	player.burst_speed_bonus = 0.16
	player.reach = 1.65
	player.hit_reach_forward = 1.90
	player.hit_reach_backward = 0.70
	player.hit_reach_racket_side = 1.35
	player.hit_reach_backhand_side = 0.85
	player.hit_reach_height = 3.05
	player.use_directional_movement_animations = true
	player.court_forward_x = 1.0
	player.court_right_z = 1.0
	player.racket_side_z = 1.0
	player.lock_visual_yaw = true
	player.visual_yaw_offset = 0.0
	player.lock_root_bone = false
	add_child(player)
	opponent = PlayerCharacter.new()
	opponent.display_name = "Mina"
	opponent.accent_color = Color(0.95, 0.1, 0.65)
	opponent.speed = 3.85
	opponent.acceleration = 15.0
	opponent.braking = 21.0
	opponent.burst_speed_bonus = 0.14
	opponent.reach = 1.65
	opponent.hit_reach_forward = 1.90
	opponent.hit_reach_backward = 0.70
	opponent.hit_reach_racket_side = 1.35
	opponent.hit_reach_backhand_side = 0.85
	opponent.hit_reach_height = 3.05
	opponent.use_directional_movement_animations = true
	opponent.use_movement_animation = true
	opponent.court_forward_x = -1.0
	opponent.court_right_z = -1.0
	opponent.racket_side_z = -1.0
	opponent.turn_speed = 3.5
	opponent.lock_visual_yaw = true
	opponent.visual_yaw_offset = 0.0
	opponent.lock_root_bone = true
	opponent.arrive_radius = 0.24
	add_child(opponent)
	shuttle = Shuttle.new()
	add_child(shuttle)
	shuttle.landed.connect(_on_shuttle_landed)
	shuttle.net_fault.connect(_on_shuttle_net_fault)
	landing_marker = _make_landing_marker()
	add_child(landing_marker)
	ai_target_marker = _make_ai_target_marker()
	add_child(ai_target_marker)
	_build_camera()
	hud = GameHud.new()
	add_child(hud)
	hud.serve_pressed.connect(try_serve)
	hud.lob_pressed.connect(func() -> void: try_hit("lob"))
	hud.drop_pressed.connect(func() -> void: try_hit("drop"))
	hud.smash_pressed.connect(func() -> void: try_hit("smash"))
	hud.hitbox_toggled.connect(_toggle_hitbox_debug)
	hud.player_ai_toggled.connect(_toggle_player_ai)
	hud.difficulty_toggled.connect(_toggle_difficulty)
	hud.graphics_toggled.connect(_toggle_graphics_mode)
	hud.camera_preset_selected.connect(_select_camera_preset)
	hud.camera_preview_changed.connect(_preview_camera_settings)
	hud.camera_preset_saved.connect(_save_camera_preset)
	hud.set_hitbox_debug(show_debug_hit_zones)
	hud.set_player_ai(player_ai_enabled)
	hud.set_difficulty(String(_difficulty_profile()["label"]))
	hud.set_graphics_mode("Render")
	hud.set_camera_slot(camera_preset_slot, active_camera_settings)
	_add_render_tuning_panel()

func _ensure_runtime_input_actions() -> void:
	_add_key_action("pause_game", KEY_P)
	_add_key_action("pause_game", KEY_ESCAPE)

func _add_key_action(action_name: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey and (event as InputEventKey).keycode == keycode:
			return
	var key := InputEventKey.new()
	key.keycode = keycode
	InputMap.action_add_event(action_name, key)

func _add_visual_gym() -> void:
	if ResourceLoader.exists(GYM_SCENE):
		var scene := load(GYM_SCENE)
		if scene is PackedScene:
			add_child((scene as PackedScene).instantiate())
			return
	var gym := GymBuilder.new()
	gym.name = "Gym_A"
	add_child(gym)

func _add_gameplay_court() -> void:
	if ResourceLoader.exists(COURT_SCENE):
		var scene := load(COURT_SCENE)
		if scene is PackedScene:
			add_child((scene as PackedScene).instantiate())
			return
	var court := CourtBuilder.new()
	court.name = "Court"
	add_child(court)

func try_serve() -> void:
	if match_state.match_over:
		return
	if match_state.set_over:
		match_state.start_next_set()
		status_text = "Nouveau set"
		_reset_for_serve()
		_update_hud()
		return
	if match_state.rally_active:
		return
	if match_state.server_side != "player":
		status_text = "Service adverse"
		ai_serve_time = _now() + 0.8
		_update_hud()
		return
	_start_rally_from_server("player", "serve_lob")

func try_hit(kind: String) -> void:
	if player.is_hitting:
		status_text = "Frappe en cours"
		_update_hud()
		return
	if not match_state.rally_active:
		if match_state.match_over or match_state.set_over:
			return
		if match_state.server_side == "player":
			_start_rally_from_server("player", _service_kind_from_shot(kind))
		else:
			status_text = "Service adverse"
			ai_serve_time = _now() + 0.8
			_update_hud()
		return
	if match_state.turn_side != "player" or match_state.match_over:
		return
	if not _player_can_hit(kind):
		_update_hud()
		return
	_hit_from_side("player", kind)

func _start_rally_from_server(side: String, service_kind: String) -> void:
	match_state.rally_active = true
	match_state.rally_count = 1
	match_state.turn_side = side
	rally_start_time = _now()
	rally_start_server = side
	rally_start_service_kind = service_kind
	_detach_shuttle_from_service_hand()
	_hit_from_side(side, service_kind)

func _hit_from_side(side: String, kind: String) -> void:
	var hitter: PlayerCharacter = player if side == "player" else opponent
	if hitter.is_hitting:
		return
	match_state.last_hitter_side = side
	match_state.last_shot_kind = kind
	match_state.shuttle_landing_side = "opponent" if side == "player" else "player"
	match_state.turn_side = match_state.shuttle_landing_side
	if not GameConfig.is_service_kind(kind):
		match_state.rally_count += 1
	var target: Vector3 = _keep_target_playable(_select_target(side, kind), match_state.shuttle_landing_side, kind)
	var service_fault_type: String = _service_fault_type(side, kind)
	if service_fault_type == "out":
		target = _make_service_target_out(side, target)
	elif service_fault_type == "technique":
		target = _make_service_target_out(side, target)
	target = _apply_ai_difficulty_error(side, kind, target)
	var shot_quality: float = _estimate_shot_quality(kind, target)
	var recovery_profile: Dictionary = GameConfig.recovery_profile(kind, shot_quality)
	hitter.play_hit(kind, _should_use_backhand(hitter, kind), float(recovery_profile["swing_recovery_time"]))
	var profile: Dictionary = GameConfig.shot_profile(kind)
	profile = profile.duplicate()
	if service_fault_type == "net" or _should_force_net_fault(side, kind):
		profile["net_fault"] = true
	var contact_position: Vector3 = shuttle.global_position
	var predicted: Vector3 = shuttle.launch(target, float(profile["duration"]), float(profile["apex"]), profile)
	var hit_direction: Vector3 = shuttle.velocity.normalized()
	spawn_racket_impact_fx(contact_position, hit_direction)
	_show_landing_marker(predicted)
	if match_state.shuttle_landing_side == "opponent":
		opponent_reception_target = _opponent_chase_target_from_landing(predicted)
		opponent_has_reception_target = true
		ai_target_marker.visible = false
	else:
		player_reception_target = _player_chase_target_from_landing(predicted)
		player_has_reception_target = true
		opponent_has_reception_target = false
		ai_target_marker.visible = false
	if side == "opponent":
		opponent_recovery_target = _calculate_opponent_recovery_position(kind, target)
		opponent_has_recovery_target = true
	if side == "player" and player_ai_enabled:
		player_recovery_target = _calculate_player_recovery_position(kind, target)
		player_has_recovery_target = true
	landing_will_be_out = match_state.is_out(predicted, match_state.shuttle_landing_side, kind)
	status_text = _shot_label(side, kind)
	if match_state.turn_side == "opponent":
		next_ai_action_time = _now() + max(0.42, shuttle.flight_duration * 0.74)
	if match_state.turn_side == "player" and player_ai_enabled:
		player_ai_action_time = _now() + max(0.42, shuttle.flight_duration * 0.74)
	_update_hud()

func apply_anime_fx_settings(settings: Dictionary) -> void:
	anime_fx_settings = settings.duplicate()

func apply_landing_marker_settings(settings: Dictionary) -> void:
	landing_marker_settings = settings.duplicate()
	_apply_landing_marker_material()
	_update_landing_marker_visual()

func spawn_racket_impact_fx(racket_position: Vector3, hit_direction: Vector3) -> void:
	if not bool(anime_fx_settings.get("enabled", true)):
		return
	if hit_direction.length() <= 0.01:
		return
	if not ResourceLoader.exists(RACKET_IMPACT_FX_SCENE):
		return
	var scene := load(RACKET_IMPACT_FX_SCENE)
	if not (scene is PackedScene):
		return
	var fx := (scene as PackedScene).instantiate() as Node3D
	var direction: Vector3 = hit_direction.normalized()
	fx.global_position = racket_position + direction * 0.14
	add_child(fx)
	if fx.has_method("setup"):
		fx.call("setup", direction, anime_fx_settings)

func _racket_contact_position(hitter: PlayerCharacter) -> Vector3:
	var forward := Vector3(hitter.court_forward_x * 0.58, 1.18, hitter.racket_side_z * 0.34)
	return hitter.global_position + forward

func _show_landing_marker(predicted: Vector3) -> void:
	landing_marker.position = Vector3(predicted.x, float(landing_marker_settings.get("height", 0.08)), predicted.z)
	landing_marker_requested_visible = true
	landing_marker_started_at = _now()
	_apply_landing_marker_material()
	_update_landing_marker_visual()

func _hide_landing_marker() -> void:
	landing_marker_requested_visible = false
	if landing_marker != null:
		landing_marker.visible = false

func _update_landing_marker_visual() -> void:
	if landing_marker == null:
		return
	if not landing_marker_requested_visible:
		landing_marker.visible = false
		return
	var enabled: bool = bool(landing_marker_settings.get("enabled", true))
	var delay: float = float(landing_marker_settings.get("delay", 0.0))
	var duration: float = float(landing_marker_settings.get("duration", 0.20))
	var age: float = _now() - landing_marker_started_at
	var visible_age: float = age - delay
	landing_marker.visible = enabled and visible_age >= 0.0
	if not landing_marker.visible:
		return
	var t: float = clamp(visible_age / max(duration, 0.01), 0.0, 1.0)
	var size_start: float = float(landing_marker_settings.get("size_start", 0.70))
	var size_end: float = float(landing_marker_settings.get("size_end", 1.0))
	landing_marker.scale = Vector3.ONE * lerp(size_start, size_end, t)
	landing_marker.position.y = float(landing_marker_settings.get("height", 0.08))

func _apply_landing_marker_material() -> void:
	if landing_marker == null:
		return
	var color_value: Variant = landing_marker_settings.get("color", Color(0.98, 0.82, 0.18, 1.0))
	var color := Color(0.98, 0.82, 0.18, 1.0)
	if color_value is Color:
		color = color_value
	color.a = float(landing_marker_settings.get("opacity", 0.78))
	landing_marker.material_override = GameConfig.material(color)

func _should_use_backhand(hitter: PlayerCharacter, kind: String) -> bool:
	if GameConfig.is_service_kind(kind):
		return false
	var lateral_to_racket_side: float = (shuttle.global_position.z - hitter.global_position.z) * hitter.racket_side_z
	return lateral_to_racket_side < -0.12

func _select_target(side: String, kind: String) -> Vector3:
	var attacking_positive: bool = side == "player"
	var source: PlayerCharacter = player if side == "player" else opponent
	var lane: float = _sample_impact_lane(source.position.z, side, kind)
	var x: float = _sample_impact_depth(side, kind)
	if kind == "drop":
		x = _sample_short_depth(attacking_positive, side)
	elif kind == "smash":
		x = _sample_smash_depth(attacking_positive, side)
	elif GameConfig.is_service_kind(kind):
		x = match_state.service_target_x(attacking_positive, kind)
		lane = match_state.service_target_lane(side)
	if side == "player" and not GameConfig.is_service_kind(kind):
		var aimed: Vector3 = _apply_player_aim(Vector3(x, GameConfig.FLOOR_Y, lane), kind, attacking_positive)
		x = aimed.x
		lane = aimed.z
	if not GameConfig.is_service_kind(kind):
		x = _clamp_depth_inside(x, attacking_positive, 0.38)
		lane = _clamp_lane_inside(lane, 0.32)
	return Vector3(x, GameConfig.FLOOR_Y, _clamp_lane_inside(lane, 0.32))

func _sample_impact_lane(source_lane: float, side: String, kind: String) -> float:
	var half_width: float = match_state.active_half_width()
	var roll: float = randf()
	var lane: float = source_lane
	if roll < 0.22:
		var side_sign: float = 1.0 if randf() < 0.5 else -1.0
		lane = side_sign * randf_range(half_width - 0.70, half_width - 0.28)
	elif roll < 0.42:
		lane = randf_range(-0.55, 0.55)
	else:
		var spread: float = 1.15 if side == "player" else 0.85
		lane += randf_range(-spread, spread)
	if kind == "smash":
		lane += randf_range(-0.45, 0.45)
	return _clamp_lane_inside(lane, 0.28)

func _sample_impact_depth(side: String, kind: String) -> float:
	var attacking_positive: bool = side == "player"
	var roll: float = randf()
	var depth: float
	if roll < 0.22:
		depth = randf_range(GameConfig.COURT_LENGTH * 0.5 - 1.25, GameConfig.COURT_LENGTH * 0.5 - 0.38)
	elif roll < 0.42:
		depth = randf_range(GameConfig.SIDE_MARGIN + 0.55, 2.45)
	else:
		depth = randf_range(3.0, GameConfig.COURT_LENGTH * 0.5 - 1.15)
	return depth if attacking_positive else -depth

func _sample_short_depth(attacking_positive: bool, side: String) -> float:
	var easy_for_player: bool = side == "opponent"
	var near_net_max: float = 2.35 if easy_for_player else 1.75
	var depth: float = randf_range(GameConfig.SIDE_MARGIN + 0.55, near_net_max)
	return depth if attacking_positive else -depth

func _sample_smash_depth(attacking_positive: bool, side: String) -> float:
	var easy_for_player: bool = side == "opponent"
	var depth: float = randf_range(2.15, 3.35 if easy_for_player else 4.05)
	return depth if attacking_positive else -depth

func _clamp_lane_inside(lane: float, margin: float) -> float:
	return clamp(lane, -match_state.active_half_width() + margin, match_state.active_half_width() - margin)

func _clamp_depth_inside(x: float, attacking_positive: bool, margin: float) -> float:
	return clamp(x, GameConfig.SIDE_MARGIN + margin, GameConfig.COURT_LENGTH * 0.5 - margin) if attacking_positive else clamp(x, -GameConfig.COURT_LENGTH * 0.5 + margin, -GameConfig.SIDE_MARGIN - margin)

func _apply_player_aim(base_target: Vector3, kind: String, attacking_positive: bool) -> Vector3:
	var target: Vector3 = base_target
	if current_aim_vector.length() < 0.18:
		return target
	var direction: float = 1.0 if attacking_positive else -1.0
	var depth: float = current_aim_vector.x * direction
	var lane: float = current_aim_vector.y
	var diagonal_boost: float = 1.28 if abs(depth) > 0.35 and abs(lane) > 0.35 else 1.0
	if depth > 0.25:
		target.x += (1.85 if kind == "lob" else 1.18) * diagonal_boost
	elif depth < -0.25:
		target.x -= (1.75 if kind == "drop" else 1.18) * diagonal_boost
	target.z += lane * 2.65 * diagonal_boost
	target.x = _clamp_depth_inside(target.x, attacking_positive, 0.38)
	target.z = _clamp_lane_inside(target.z, 0.32)
	return target

func _keep_target_playable(target: Vector3, receiving_side: String, kind: String) -> Vector3:
	var safe_target: Vector3 = target
	var width_margin: float = 0.32
	safe_target.z = clamp(safe_target.z, -match_state.active_half_width() + width_margin, match_state.active_half_width() - width_margin)
	if GameConfig.is_service_kind(kind):
		var min_depth: float = GameConfig.SHORT_SERVICE_DISTANCE + 0.12
		var max_depth: float = GameConfig.SHORT_SERVICE_DISTANCE + 0.62
		if kind == "serve_drive":
			min_depth = match_state.service_long_limit() - 1.80
			max_depth = match_state.service_long_limit() - 1.05
		elif kind == "serve_lob":
			min_depth = match_state.service_long_limit() - 1.15
			max_depth = match_state.service_long_limit() - 0.35
		var depth: float = clamp(abs(safe_target.x), min_depth, max_depth)
		safe_target.x = -depth if receiving_side == "player" else depth
	else:
		var min_x: float = GameConfig.SIDE_MARGIN + 0.38
		var max_x: float = GameConfig.COURT_LENGTH * 0.5 - 0.38
		var depth_x: float = clamp(abs(safe_target.x), min_x, max_x)
		safe_target.x = -depth_x if receiving_side == "player" else depth_x
	return safe_target

func _move_player(delta: float) -> void:
	if not match_state.rally_active:
		player.move_towards(match_state.pre_serve_position_for_side("player"), delta)
		return
	var input: Vector2 = _physical_input() + hud.move_vector
	if camera_mode == "behind":
		input = Vector2(-input.y, input.x)
	player.move_on_court(input, delta)
	_clamp_player()

func _update_player_ai_movement(delta: float) -> void:
	if player.is_hitting:
		if player_has_recovery_target and match_state.rally_active and match_state.last_hitter_side == "player" and _now() >= player_recovery_unlocked_at:
			player.recover_towards(_clamp_player_court_position(player_recovery_target), delta, 0.44 * player_recovery_urgency)
		else:
			player.move_towards(player.position, delta)
		return
	var target: Vector3 = _player_base_position()
	if not match_state.rally_active:
		target = match_state.pre_serve_position_for_side("player")
	elif match_state.shuttle_landing_side == "player":
		if shuttle.flight_phase() >= GameConfig.AI_REACTION_PHASE:
			target = player_reception_target if player_has_reception_target else _player_chase_target_from_landing(shuttle.target)
	elif player_has_recovery_target:
		player.recover_towards(_clamp_player_court_position(player_recovery_target), delta, 0.76 * player_recovery_urgency)
		_clamp_player()
		return
	player.move_towards(target, delta)
	_clamp_player()

func _player_chase_target_from_landing(landing: Vector3) -> Vector3:
	return Vector3(
		clamp(landing.x + 0.65, -GameConfig.COURT_LENGTH * 0.5 - GameConfig.PLAYER_RUNOFF, -0.35),
		player.position.y,
		clamp(landing.z, -match_state.movement_half_width(), match_state.movement_half_width())
	)

func _update_body_orientation(delta: float) -> void:
	if match_state.rally_active:
		player.face_yaw(PI * 0.5, delta)
		opponent.face_yaw(-PI * 0.5, delta)
		return
	player.face_towards(_pre_service_look_target("player"), delta)
	opponent.face_towards(_pre_service_look_target("opponent"), delta)

func _pre_service_look_target(side: String) -> Vector3:
	var x: float
	var z: float
	if side == match_state.server_side:
		x = match_state.service_target_x(side == "player", "serve_short")
		z = match_state.service_receiver_lane(side)
	else:
		var server: PlayerCharacter = player if match_state.server_side == "player" else opponent
		x = server.global_position.x
		z = server.global_position.z
	return Vector3(x, GameConfig.CHARACTER_GROUND_Y, z)

func _update_opponent(delta: float) -> void:
	if opponent.is_hitting:
		if opponent_has_recovery_target and match_state.rally_active and match_state.last_hitter_side == "opponent" and _now() >= opponent_recovery_unlocked_at:
			opponent.recover_towards(_clamp_opponent_court_position(opponent_recovery_target), delta, 0.44 * opponent_recovery_urgency)
		else:
			opponent.move_towards(opponent.position, delta)
		return
	var target: Vector3 = _opponent_base_position()
	if not match_state.rally_active:
		target = match_state.pre_serve_position_for_side("opponent")
	elif match_state.shuttle_landing_side == "opponent":
		if shuttle.flight_phase() >= GameConfig.AI_REACTION_PHASE:
			target = opponent_reception_target if opponent_has_reception_target else _opponent_chase_target_from_landing(shuttle.target)
	elif opponent_has_recovery_target:
		opponent.recover_towards(_clamp_opponent_court_position(opponent_recovery_target), delta, 0.76 * opponent_recovery_urgency)
		return
	opponent.move_towards(target, delta)

func _opponent_chase_target_from_landing(landing: Vector3) -> Vector3:
	return Vector3(
		clamp(landing.x - 0.65, 0.35, GameConfig.COURT_LENGTH * 0.5 + GameConfig.PLAYER_RUNOFF),
		opponent.position.y,
		clamp(landing.z, -match_state.movement_half_width(), match_state.movement_half_width())
	)

func _calculate_opponent_recovery_position(shot_type: String, target: Vector3) -> Vector3:
	var shot_quality: float = _estimate_shot_quality(shot_type, target)
	var pressure_state: String = _opponent_pressure_state(shot_type, shot_quality, target)
	var recovery_profile: Dictionary = GameConfig.recovery_profile(shot_type, shot_quality)
	opponent_recovery_urgency = float(recovery_profile["urgency_factor"])
	opponent_recovery_unlocked_at = _now() + float(recovery_profile["swing_recovery_time"])
	var recovery := Vector3(3.75, opponent.position.y, 0.0)
	match _recovery_shot_family(shot_type):
		"clear":
			recovery.x += 0.35
		"smash":
			recovery.x -= 0.35
		"drop", "net":
			recovery.x -= 0.55
		"lob":
			recovery.x += 0.70
		"drive":
			recovery.x -= 0.05
	recovery.x += float(recovery_profile["base_offset"])
	if shot_quality < 0.40:
		recovery.x += 0.45
	elif shot_quality > 0.76 and pressure_state == "attack":
		recovery.x -= 0.15
	match pressure_state:
		"defense":
			recovery.x += 0.35
		"attack":
			recovery.x -= 0.20
	var direction_offset: float = _opponent_recovery_lane_offset(target)
	recovery.z += direction_offset
	recovery.z += randf_range(-0.16, 0.16)
	recovery.x += randf_range(-0.10, 0.10)
	return _clamp_opponent_court_position(recovery)

func _calculate_player_recovery_position(shot_type: String, target: Vector3) -> Vector3:
	var shot_quality: float = _estimate_shot_quality(shot_type, target)
	var pressure_state: String = _opponent_pressure_state(shot_type, shot_quality, target)
	var recovery_profile: Dictionary = GameConfig.recovery_profile(shot_type, shot_quality)
	player_recovery_urgency = float(recovery_profile["urgency_factor"])
	player_recovery_unlocked_at = _now() + float(recovery_profile["swing_recovery_time"])
	var recovery := Vector3(-3.75, player.position.y, 0.0)
	match _recovery_shot_family(shot_type):
		"clear":
			recovery.x -= 0.35
		"smash":
			recovery.x += 0.35
		"drop", "net":
			recovery.x += 0.55
		"lob":
			recovery.x -= 0.70
		"drive":
			recovery.x += 0.05
	recovery.x -= float(recovery_profile["base_offset"])
	if shot_quality < 0.40:
		recovery.x -= 0.45
	elif shot_quality > 0.76 and pressure_state == "attack":
		recovery.x += 0.15
	match pressure_state:
		"defense":
			recovery.x -= 0.35
		"attack":
			recovery.x += 0.20
	var direction_offset: float = _player_recovery_lane_offset(target)
	recovery.z += direction_offset
	recovery.z += randf_range(-0.16, 0.16)
	recovery.x += randf_range(-0.10, 0.10)
	return _clamp_player_court_position(recovery)

func _recovery_shot_family(shot_type: String) -> String:
	match shot_type:
		"drop":
			return "drop"
		"smash":
			return "smash"
		"serve_short":
			return "net"
		"serve_drive", "drive":
			return "drive"
		"lob", "serve_lob":
			return "clear"
		_:
			return "clear"

func _estimate_shot_quality(shot_type: String, target: Vector3) -> float:
	var half_width: float = match_state.active_half_width()
	var sideline_pressure: float = clamp(abs(target.z) / max(half_width, 0.01), 0.0, 1.0)
	var depth_pressure: float = clamp((abs(target.x) - 2.0) / (GameConfig.COURT_LENGTH * 0.5 - 2.0), 0.0, 1.0)
	var quality: float = 0.55
	match _recovery_shot_family(shot_type):
		"clear", "lob":
			quality = lerp(0.42, 0.88, depth_pressure)
		"smash":
			quality = lerp(0.48, 0.86, sideline_pressure)
		"drop", "net":
			var net_pressure: float = 1.0 - clamp((abs(target.x) - GameConfig.SIDE_MARGIN) / 2.4, 0.0, 1.0)
			quality = lerp(0.40, 0.86, max(net_pressure, sideline_pressure * 0.75))
		"drive":
			quality = lerp(0.45, 0.78, sideline_pressure)
	return clamp(quality + randf_range(-0.12, 0.10), 0.0, 1.0)

func _opponent_pressure_state(shot_type: String, shot_quality: float, target: Vector3) -> String:
	if shot_quality < 0.38:
		return "defense"
	if _recovery_shot_family(shot_type) in ["smash", "drop", "net"] and shot_quality > 0.58:
		return "attack"
	if _recovery_shot_family(shot_type) == "clear" and abs(target.x) < GameConfig.COURT_LENGTH * 0.5 - 1.0:
		return "defense"
	return "neutral"

func _opponent_recovery_lane_offset(target: Vector3) -> float:
	var shot_delta_z: float = target.z - opponent.position.z
	var target_side: float = sign(target.z)
	var current_side: float = sign(opponent.position.z)
	var offset: float = clamp(target.z * 0.22, -0.58, 0.58)
	if abs(shot_delta_z) > 1.20 and target_side != 0.0 and target_side != current_side:
		offset += target_side * 0.34
	elif abs(target.z) > 1.10:
		offset += target_side * 0.18
	return clamp(offset, -0.85, 0.85)

func _player_recovery_lane_offset(target: Vector3) -> float:
	var shot_delta_z: float = target.z - player.position.z
	var target_side: float = sign(target.z)
	var current_side: float = sign(player.position.z)
	var offset: float = clamp(target.z * 0.22, -0.58, 0.58)
	if abs(shot_delta_z) > 1.20 and target_side != 0.0 and target_side != current_side:
		offset += target_side * 0.34
	elif abs(target.z) > 1.10:
		offset += target_side * 0.18
	return clamp(offset, -0.85, 0.85)

func _clamp_opponent_court_position(position: Vector3) -> Vector3:
	return Vector3(
		clamp(position.x, GameConfig.SIDE_MARGIN + 0.35, GameConfig.COURT_LENGTH * 0.5 + GameConfig.PLAYER_RUNOFF),
		opponent.position.y,
		clamp(position.z, -match_state.movement_half_width() + 0.35, match_state.movement_half_width() - 0.35)
	)

func _clamp_player_court_position(position: Vector3) -> Vector3:
	return Vector3(
		clamp(position.x, -GameConfig.COURT_LENGTH * 0.5 - GameConfig.PLAYER_RUNOFF, -GameConfig.SIDE_MARGIN - 0.35),
		player.position.y,
		clamp(position.z, -match_state.movement_half_width() + 0.35, match_state.movement_half_width() - 0.35)
	)

func _update_ai() -> void:
	if ai_serve_time > 0.0 and _now() >= ai_serve_time:
		ai_serve_time = -1.0
		opponent.finish_hit()
		_start_rally_from_server("opponent", _choose_ai_service_kind())
	if next_ai_action_time > 0.0 and _now() >= next_ai_action_time:
		next_ai_action_time = -1.0
		if match_state.rally_active and match_state.turn_side == "opponent" and not landing_will_be_out:
			if _character_can_intercept(opponent, _ai_reach_bonus(opponent), _ai_vertical_reach()):
				_hit_from_side("opponent", _choose_ai_return_shot() if GameConfig.is_service_kind(match_state.last_shot_kind) else _choose_ai_shot())
			else:
				var phase: float = shuttle.flight_phase()
				if phase < 0.96 and shuttle.in_flight:
					next_ai_action_time = _now() + 0.08
				else:
					status_text = "Mina en retard"
					_update_hud()

func _update_player_ai() -> void:
	if not player_ai_enabled:
		return
	if player_ai_serve_time > 0.0 and _now() >= player_ai_serve_time:
		player_ai_serve_time = -1.0
		player.finish_hit()
		_start_rally_from_server("player", _choose_player_ai_service_kind())
	if player_ai_action_time > 0.0 and _now() >= player_ai_action_time:
		player_ai_action_time = -1.0
		if match_state.rally_active and match_state.turn_side == "player" and not landing_will_be_out:
			if _character_can_intercept(player, _ai_reach_bonus(player), _ai_vertical_reach()):
				var kind: String = _choose_player_ai_return_shot() if GameConfig.is_service_kind(match_state.last_shot_kind) else _choose_player_ai_shot()
				_hit_from_side("player", kind)
			else:
				var phase: float = shuttle.flight_phase()
				if phase < 0.96 and shuttle.in_flight:
					player_ai_action_time = _now() + 0.08

func _choose_ai_shot() -> String:
	var roll: float = randf()
	var smash_bias: float = float(_difficulty_profile()["smash_bias"])
	if roll < 0.46 - smash_bias:
		return "lob"
	if roll < 0.78 - smash_bias * 0.5:
		return "drop"
	return "smash"

func _ai_reach_bonus(character: PlayerCharacter) -> float:
	var phase: float = shuttle.flight_phase()
	var distance_to_shuttle: float = character.global_position.distance_to(shuttle.global_position)
	var profile: Dictionary = _difficulty_profile()
	var bonus: float = 0.08 + float(profile["reach_bias"])
	if phase > 0.82:
		bonus -= float(profile["late_penalty"])
	if distance_to_shuttle > 2.3:
		bonus -= float(profile["late_penalty"])
	return clamp(bonus, -0.08, 0.16)

func _ai_vertical_reach() -> float:
	return float(_difficulty_profile()["vertical_reach"])

func _difficulty_profile() -> Dictionary:
	return GameConfig.difficulty_profile(difficulty_level)

func _apply_ai_difficulty_error(side: String, kind: String, target: Vector3) -> Vector3:
	if side == "player" and not player_ai_enabled:
		return target
	if GameConfig.is_service_kind(kind):
		return target
	var profile: Dictionary = _difficulty_profile()
	if randf() > float(profile["out_error_chance"]):
		return target
	var miss: Vector3 = target
	var lane_sign: float = 1.0 if miss.z >= 0.0 else -1.0
	if randf() < 0.55:
		miss.z = lane_sign * (match_state.active_half_width() + randf_range(0.16, 0.55))
	else:
		var depth_sign: float = 1.0 if miss.x >= 0.0 else -1.0
		miss.x = depth_sign * (GameConfig.COURT_LENGTH * 0.5 + randf_range(0.12, 0.45))
	return miss

func _service_fault_type(side: String, kind: String) -> String:
	if not GameConfig.is_service_kind(kind):
		return ""
	if side == "player" and not player_ai_enabled:
		return ""
	var profile: Dictionary = _difficulty_profile()
	if randf() > float(profile["service_fault_chance"]):
		return ""
	var roll: float = randf()
	if roll < float(profile["service_net_fault_share"]):
		return "net"
	if roll < float(profile["service_net_fault_share"]) + float(profile["service_out_fault_share"]):
		return "out"
	return "technique"

func _make_service_target_out(side: String, target: Vector3) -> Vector3:
	var miss: Vector3 = target
	var depth_sign: float = 1.0 if side == "player" else -1.0
	if randf() < 0.65:
		miss.x = depth_sign * (match_state.service_long_limit() + randf_range(0.18, 0.55))
	else:
		var lane_sign: float = 1.0 if miss.z >= 0.0 else -1.0
		miss.z = lane_sign * (match_state.active_half_width() + randf_range(0.16, 0.45))
	return miss

func _should_force_net_fault(side: String, kind: String) -> bool:
	if GameConfig.is_service_kind(kind):
		return false
	if side == "player" and not player_ai_enabled:
		return false
	if kind == "lob" or kind == "serve_lob":
		return false
	var profile: Dictionary = _difficulty_profile()
	var chance: float = float(profile["net_fault_chance"])
	if kind == "smash" or kind == "drive" or kind == "serve_drive":
		chance *= 1.25
	return randf() < chance

func _choose_player_ai_shot() -> String:
	var roll: float = randf()
	if roll < 0.46:
		return "lob"
	if roll < 0.78:
		return "drop"
	return "smash"

func _choose_player_ai_service_kind() -> String:
	var roll: float = randf()
	if roll < 0.54:
		return "serve_short"
	if roll < 0.84:
		return "serve_lob"
	return "serve_drive"

func _choose_player_ai_return_shot() -> String:
	var service_type: String = match_state.last_shot_kind
	if service_type == "serve_short":
		var roll_short: float = randf()
		return "drop" if roll_short < 0.42 else ("drive" if roll_short < 0.68 else "lob")
	if service_type == "serve_lob":
		var roll_long: float = randf()
		return "lob" if roll_long < 0.42 else ("drop" if roll_long < 0.72 else "smash")
	return "lob" if randf() < 0.62 else "drop"

func _choose_ai_service_kind() -> String:
	var receiver_aggressiveness: float = _player_receiver_aggressiveness()
	if receiver_aggressiveness > 0.75 and randf() < 0.62:
		return "serve_drive"
	if receiver_aggressiveness < 0.35 and randf() < 0.70:
		return "serve_short"
	var roll: float = randf()
	if roll < 0.55:
		return "serve_short"
	if roll < 0.85:
		return "serve_lob"
	return "serve_drive"

func _choose_ai_return_shot() -> String:
	var service_type: String = match_state.last_shot_kind
	var receiver_aggressiveness: float = opponent_receiver_aggressiveness
	var reaction_time: float = randf_range(0.24, 0.58)
	if service_type == "serve_short":
		var roll_short: float = randf()
		if receiver_aggressiveness > 0.68:
			return "drop" if roll_short < 0.52 else ("drive" if roll_short < 0.86 else "lob")
		return "drop" if roll_short < 0.36 else ("drive" if roll_short < 0.60 else "lob")
	if service_type == "serve_lob":
		var roll_long: float = randf()
		return "lob" if roll_long < 0.40 else ("drop" if roll_long < 0.70 else "smash")
	if reaction_time > 0.45 or receiver_aggressiveness > 0.74:
		return "lob" if randf() < 0.70 else "drop"
	var roll_flick: float = randf()
	return "lob" if roll_flick < 0.35 else ("smash" if roll_flick < 0.70 else "drop")

func _player_receiver_aggressiveness() -> float:
	if match_state.server_side != "opponent":
		return 0.50
	var distance_from_net: float = abs(player.position.x)
	var neutral_line: float = GameConfig.SHORT_SERVICE_DISTANCE + 0.38
	var value: float = 0.62 - (distance_from_net - neutral_line) * 0.38
	return clamp(value, 0.0, 1.0)

func _on_shuttle_landed(_predicted_position: Vector3) -> void:
	if not match_state.rally_active or landing_pending:
		return
	opponent_has_reception_target = false
	player_has_reception_target = false
	ai_target_marker.visible = false
	hud.set_timing("")
	landing_winner = match_state.shuttle_landing_side if landing_will_be_out else match_state.last_hitter_side
	landing_reason = "Faute service" if landing_will_be_out and GameConfig.is_service_kind(match_state.last_shot_kind) else ("Faute dehors" if landing_will_be_out else "Point")
	status_text = landing_reason
	landing_pending = true
	landing_resolve_time = _now() + 0.45
	_update_hud()

func _on_shuttle_net_fault() -> void:
	if not match_state.rally_active or landing_pending:
		return
	opponent_has_reception_target = false
	player_has_reception_target = false
	ai_target_marker.visible = false
	hud.set_timing("")
	landing_winner = match_state.shuttle_landing_side
	landing_reason = "Faute service" if GameConfig.is_service_kind(match_state.last_shot_kind) else "Faute filet"
	status_text = landing_reason
	landing_pending = true
	landing_resolve_time = _now() + 0.35
	_update_hud()

func _update_landing_resolution() -> void:
	if not landing_pending or _now() < landing_resolve_time:
		return
	landing_pending = false
	_hide_landing_marker()
	_record_ai_match_point()
	var set_winner: String = match_state.award_point(landing_winner)
	if set_winner != "":
		status_text = "Match gagne" if match_state.match_over and set_winner == "player" else ("Match perdu" if match_state.match_over else "Set termine")
	else:
		status_text = "%s %s" % [landing_reason, "Kai" if landing_winner == "player" else "Mina"]
	_reset_for_serve()
	_update_hud()
	if match_state.server_side == "opponent" and not match_state.set_over and not match_state.match_over:
		ai_serve_time = _now() + 1.2
	if player_ai_enabled and match_state.server_side == "player" and not match_state.set_over and not match_state.match_over:
		player_ai_serve_time = _now() + 1.0

func _record_ai_match_point() -> void:
	_store_stats_line(stats_file_path)
	_store_stats_line(project_stats_file_path)

func _store_stats_line(path: String) -> void:
	if path == project_stats_file_path:
		DirAccess.make_dir_recursive_absolute("C:/Users/aho7/Documents/Codex/PowerSpikeStructuredBase/stats")
	var needs_header: bool = not FileAccess.file_exists(path)
	var file := FileAccess.open(path, FileAccess.WRITE if needs_header else FileAccess.READ_WRITE)
	if file == null:
		status_text = "Stats non enregistrees"
		return
	file.seek_end()
	if needs_header:
		file.store_csv_line([
			"timestamp",
			"difficulty",
			"mode",
			"server",
			"service",
			"winner",
			"reason",
			"hits",
			"duration_s",
			"last_hitter",
			"last_shot",
			"score_kai_before",
			"score_mina_before",
			"sets_kai",
			"sets_mina"
		])
	file.store_csv_line([
		Time.get_datetime_string_from_system(),
		String(_difficulty_profile()["label"]),
		match_state.mode,
		rally_start_server,
		rally_start_service_kind,
		landing_winner,
		landing_reason,
		str(match_state.rally_count),
		"%.2f" % max(_now() - rally_start_time, 0.0),
		match_state.last_hitter_side,
		match_state.last_shot_kind,
		str(match_state.player_score),
		str(match_state.opponent_score),
		str(match_state.player_sets),
		str(match_state.opponent_sets)
	])
	file.close()

func _reset_for_serve() -> void:
	player.finish_hit()
	opponent.finish_hit()
	opponent_has_reception_target = false
	opponent_has_recovery_target = false
	player_has_reception_target = false
	player_ai_action_time = -1.0
	opponent_receiver_aggressiveness = randf_range(0.46, 0.74)
	ai_target_marker.visible = false
	player.position = match_state.pre_serve_position_for_side("player")
	opponent.position = match_state.pre_serve_position_for_side("opponent")
	var holder: PlayerCharacter = player if match_state.server_side == "player" else opponent
	_attach_shuttle_to_service_hand(holder)
	_hide_landing_marker()
	landing_pending = false
	hud.set_timing("")

func _update_pre_service_shuttle_hold() -> void:
	if match_state.rally_active or shuttle == null:
		return
	var holder: PlayerCharacter = player if match_state.server_side == "player" else opponent
	_attach_shuttle_to_service_hand(holder)

func _attach_shuttle_to_service_hand(holder: PlayerCharacter) -> void:
	if holder == null or shuttle == null:
		return
	var anchor := holder.get_service_shuttle_anchor()
	if anchor == null:
		shuttle.set_service_hold_position(_service_shuttle_hold_position(holder))
		return
	if shuttle.get_parent() != self:
		var world_transform := shuttle.global_transform
		if shuttle.get_parent() != null:
			shuttle.get_parent().remove_child(shuttle)
		add_child(shuttle)
		shuttle.global_transform = world_transform
	shuttle_service_attached = true
	var settings := _service_settings_for_holder(holder)
	var local_offset := Vector3(
		float(settings["forward"]),
		float(settings["height"]),
		float(settings["lateral"])
	)
	if shuttle.has_method("set_service_hold_rotation"):
		shuttle.call("set_service_hold_rotation", Vector3(
			float(settings["rot_x"]),
			float(settings["rot_y"]),
			float(settings["rot_z"])
		))
	shuttle.set_service_hold_position(anchor.global_transform * local_offset)
	shuttle.scale = Vector3.ONE

func _detach_shuttle_from_service_hand() -> void:
	if shuttle == null or not shuttle_service_attached:
		return
	shuttle_service_attached = false

func _service_shuttle_hold_position(holder: PlayerCharacter) -> Vector3:
	var settings := _service_settings_for_holder(holder)
	var forward_offset: float = holder.court_forward_x * float(settings["forward"])
	var free_hand_offset: float = -holder.racket_side_z * float(settings["lateral"])
	var height_offset: float = float(settings["height"])
	return holder.global_position + Vector3(forward_offset, height_offset, free_hand_offset)

func apply_service_shuttle_hold_settings(settings: Dictionary) -> void:
	for side in ["player", "opponent"]:
		var current := _service_settings_for_side(side).duplicate()
		var prefix := "kai_" if side == "player" else "mina_"
		current["forward"] = clamp(float(settings.get(prefix + "forward", settings.get("forward", current["forward"]))), -0.35, 0.35)
		current["lateral"] = clamp(float(settings.get(prefix + "lateral", settings.get("lateral", current["lateral"]))), -0.35, 0.35)
		current["height"] = clamp(float(settings.get(prefix + "height", settings.get("height", current["height"]))), -0.35, 0.35)
		current["rot_x"] = float(settings.get(prefix + "rot_x", settings.get("rot_x", current["rot_x"])))
		current["rot_y"] = float(settings.get(prefix + "rot_y", settings.get("rot_y", current["rot_y"])))
		current["rot_z"] = float(settings.get(prefix + "rot_z", settings.get("rot_z", current["rot_z"])))
		service_shuttle_hold_settings_by_side[side] = current
	_update_pre_service_shuttle_hold()

func _service_settings_for_holder(holder: PlayerCharacter) -> Dictionary:
	return _service_settings_for_side("opponent" if holder == opponent else "player")

func _service_settings_for_side(side: String) -> Dictionary:
	if service_shuttle_hold_settings_by_side.has(side):
		return service_shuttle_hold_settings_by_side[side]
	return service_shuttle_hold_default_settings

func _ensure_ai_service_pending() -> void:
	if match_state.match_over or match_state.set_over or match_state.rally_active:
		return
	if match_state.server_side == "opponent" and ai_serve_time < 0.0:
		status_text = "Service Mina"
		ai_serve_time = _now() + 0.9
		_update_hud()

func _ensure_player_ai_service_pending() -> void:
	if not player_ai_enabled or match_state.match_over or match_state.set_over or match_state.rally_active:
		return
	if match_state.server_side == "player" and player_ai_serve_time < 0.0:
		status_text = "Service Kai IA"
		player_ai_serve_time = _now() + 0.9
		_update_hud()

func _player_can_hit(kind: String) -> bool:
	if landing_will_be_out:
		status_text = "Laisse sortir"
		return false
	var phase: float = shuttle.flight_phase()
	if phase < 0.22:
		status_text = "Trop tot"
		return false
	var reach_bonus: float = 0.75 if kind == "lob" else 0.45
	if not _character_can_intercept(player, reach_bonus, 3.35):
		status_text = "Replace-toi"
		return false
	if phase > 1.05:
		status_text = "Trop tard"
		return false
	return true

func _character_can_intercept(character: PlayerCharacter, reach_bonus: float, vertical_reach: float) -> bool:
	return _point_inside_character_hit_zone(character, shuttle.position, reach_bonus, vertical_reach)

func _point_inside_character_hit_zone(character: PlayerCharacter, point: Vector3, reach_bonus: float, vertical_reach: float) -> bool:
	var forward: float = (point.x - character.global_position.x) * character.court_forward_x
	var lateral_to_racket_side: float = (point.z - character.global_position.z) * character.racket_side_z
	var min_y: float = GameConfig.FLOOR_Y
	var max_y: float = GameConfig.CHARACTER_GROUND_Y + min(character.hit_reach_height + reach_bonus * 0.25, vertical_reach)
	return (
		forward >= -character.hit_reach_backward
		and forward <= character.hit_reach_forward + reach_bonus
		and lateral_to_racket_side >= -character.hit_reach_backhand_side - reach_bonus * 0.20
		and lateral_to_racket_side <= character.hit_reach_racket_side + reach_bonus * 0.35
		and point.y >= min_y
		and point.y <= max_y
	)

func _update_player_head_look() -> void:
	var head_look_active: bool = match_state.rally_active or shuttle.in_flight
	if not head_look_active:
		player.set_head_look_target(shuttle.global_position, false)
		opponent.set_head_look_target(shuttle.global_position, false)
		return
	var aimed_point: Vector3 = landing_marker.global_position + Vector3(0.0, 0.28, 0.0)
	var player_target: Vector3 = shuttle.global_position
	var opponent_target: Vector3 = shuttle.global_position
	if match_state.last_hitter_side == "player" and player.is_hitting:
		player_target = aimed_point
	if match_state.last_hitter_side == "opponent" and opponent.is_hitting:
		opponent_target = aimed_point
	player.set_head_look_target(player_target, true)
	opponent.set_head_look_target(opponent_target, true)

func _update_reception_state() -> void:
	if not match_state.rally_active or not shuttle.in_flight or match_state.turn_side != "player":
		hud.set_timing("")
		return
	var phase: float = shuttle.flight_phase()
	if phase >= 0.22 and phase <= 1.05 and _character_can_intercept(player, 0.35, 3.35):
		hud.set_timing("FRAPPE")
	elif phase < 0.22:
		hud.set_timing("Prepare-toi")
	else:
		hud.set_timing("Trop loin")

func _update_aim_state() -> void:
	var aim: Vector2 = hud.aim_vector
	if aim.length() <= 0.18:
		aim = _physical_input()
	if camera_mode == "behind":
		aim = Vector2(-aim.y, aim.x)
	if aim.length() > 1.0:
		aim = aim.normalized()
	if aim.length() > 0.18:
		last_aim_vector = aim
		last_aim_time = _now()
	current_aim_vector = last_aim_vector if _now() - last_aim_time <= GameConfig.AIM_HOLD_TIME else Vector2.ZERO
	hud.set_aim_label(_describe_aim(current_aim_vector))

func _physical_input() -> Vector2:
	return Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)

func _clamp_player() -> void:
	if match_state.rally_active:
		player.position.x = clamp(player.position.x, -GameConfig.COURT_LENGTH * 0.5 - GameConfig.PLAYER_RUNOFF, -0.35)
		player.position.z = clamp(player.position.z, -match_state.movement_half_width(), match_state.movement_half_width())
		return
	var lane: float = match_state.pre_serve_lane_for_side("player")
	var x_min: float = -GameConfig.COURT_LENGTH * 0.5 + 0.4
	var x_max: float = -GameConfig.SHORT_SERVICE_DISTANCE - 0.15
	if match_state.server_side != "player":
		x_min = -match_state.service_long_limit() + 0.15
	player.position.x = clamp(player.position.x, x_min, x_max)
	player.position.z = clamp(player.position.z, match_state.lane_min(lane), match_state.lane_max(lane))

func _opponent_base_position() -> Vector3:
	if opponent_has_recovery_target and match_state.rally_active and match_state.last_hitter_side == "opponent":
		return _clamp_opponent_court_position(opponent_recovery_target)
	var base_x: float = 4.0
	if match_state.rally_active and match_state.last_hitter_side == "opponent":
		base_x = 3.25
	elif match_state.rally_active:
		base_x = 4.25
	var score_lane: float = 0.45 if match_state.opponent_score % 2 == 0 else -0.45
	var player_pull: float = -player.position.z * 0.28
	var rally_pull: float = clamp(shuttle.target.z * 0.22, -0.55, 0.55) if match_state.rally_active else 0.0
	var z: float = clamp(score_lane + player_pull + rally_pull, -match_state.movement_half_width() + 0.45, match_state.movement_half_width() - 0.45)
	return Vector3(base_x, opponent.position.y, z)

func _player_base_position() -> Vector3:
	var base_x: float = -4.0
	if match_state.rally_active and match_state.last_hitter_side == "player":
		base_x = -3.25
	elif match_state.rally_active:
		base_x = -4.25
	var score_lane: float = 0.45 if match_state.player_score % 2 == 0 else -0.45
	var opponent_pull: float = -opponent.position.z * 0.22
	var rally_pull: float = clamp(shuttle.target.z * 0.20, -0.50, 0.50) if match_state.rally_active else 0.0
	var z: float = clamp(score_lane + opponent_pull + rally_pull, -match_state.movement_half_width() + 0.45, match_state.movement_half_width() - 0.45)
	return Vector3(base_x, player.position.y, z)

func _toggle_match_mode() -> void:
	if match_state.rally_active:
		status_text = "Mode apres le point"
	else:
		match_state.toggle_mode()
		status_text = "Mode double" if match_state.mode == "doubles" else "Mode simple"
		_reset_for_serve()
	_update_hud()

func _toggle_camera() -> void:
	camera_mode = "behind" if camera_mode == "court" else "court"
	if camera_mode == "behind":
		_select_camera_preset(3)
		status_text = "Camera dos joueur"
	else:
		_select_camera_preset(court_camera_preset_slot)
		status_text = "Camera terrain"
	_update_hud()

func _toggle_pause() -> void:
	game_paused = not game_paused
	free_camera_mouse_look = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_set_character_animations_paused(game_paused)
	if game_paused:
		free_camera_angles = Vector2(camera.rotation_degrees.x, camera.rotation_degrees.y)
		status_text = "Pause - camera libre"
	else:
		status_text = "Reprise"
	if hud != null:
		hud.set_pause_visible(game_paused)
	_update_hud()

func _set_character_animations_paused(paused: bool) -> void:
	if player != null:
		player.set_animation_paused(paused)
	if opponent != null:
		opponent.set_animation_paused(paused)

func _toggle_hitbox_debug() -> void:
	show_debug_hit_zones = not show_debug_hit_zones
	hud.set_hitbox_debug(show_debug_hit_zones)

func _toggle_player_ai() -> void:
	player_ai_enabled = not player_ai_enabled
	player_ai_action_time = -1.0
	player_ai_serve_time = -1.0
	hud.move_vector = Vector2.ZERO
	hud.aim_vector = Vector2.ZERO
	hud.set_player_ai(player_ai_enabled)
	status_text = "Kai IA" if player_ai_enabled else "Kai joueur"
	_update_hud()

func _toggle_difficulty() -> void:
	match difficulty_level:
		"loisir":
			difficulty_level = "club"
		"club":
			difficulty_level = "elite"
		_:
			difficulty_level = "loisir"
	hud.set_difficulty(String(_difficulty_profile()["label"]))
	status_text = "Niveau " + String(_difficulty_profile()["label"])
	_update_hud()

func _toggle_graphics_mode() -> void:
	if render_tuning_panel != null and render_tuning_panel.has_method("toggle"):
		render_tuning_panel.call("toggle")

func _add_render_tuning_panel() -> void:
	if ResourceLoader.exists(RENDER_TUNING_SCENE):
		var scene := load(RENDER_TUNING_SCENE)
		if scene is PackedScene:
			var panel: Node = (scene as PackedScene).instantiate() as Node
			if panel != null:
				render_tuning_panel = panel
				add_child(render_tuning_panel)

func _build_camera() -> void:
	add_child(camera)
	camera.position = Vector3(0, float(active_camera_settings["height"]), float(active_camera_settings["distance"]))
	camera.rotation_degrees = Vector3(-48, 0, 0)
	camera.fov = float(active_camera_settings["fov"])
	camera.current = true
	var light := DirectionalLight3D.new()
	add_child(light)
	light.rotation_degrees = Vector3(-55, -30, 0)

func _update_free_camera(delta: float) -> void:
	var move := Vector3.ZERO
	var basis := camera.global_transform.basis
	move += -basis.z * (Input.get_action_strength("move_up") - Input.get_action_strength("move_down"))
	move += basis.x * (Input.get_action_strength("move_right") - Input.get_action_strength("move_left"))
	if Input.is_key_pressed(KEY_SPACE):
		move.y += 1.0
	if Input.is_key_pressed(KEY_CTRL):
		move.y -= 1.0
	var speed := free_camera_speed * (2.2 if Input.is_key_pressed(KEY_SHIFT) else 1.0)
	if move.length() > 0.01:
		camera.position += move.normalized() * speed * delta
		camera.position = _clamp_camera_position(camera.position)

func _update_camera(delta: float) -> void:
	if game_paused:
		return
	var shuttle_focus: float = clamp(shuttle.position.y * 0.42, 0.0, 2.2)
	var side_offset: float = float(active_camera_settings["side"])
	var vertical_follow: float = float(active_camera_settings["follow_y"])
	var camera_z_follow: float = float(active_camera_settings["follow_side"])
	var look_z_follow: float = float(active_camera_settings["look_z"])
	var camera_x_follow: float = float(active_camera_settings["follow_x"])
	var look_x_follow: float = float(active_camera_settings["look_x"])
	var followed_height: float = shuttle_focus * vertical_follow
	var followed_camera_x: float = side_offset + shuttle.position.x * camera_x_follow
	var followed_look_x: float = side_offset + shuttle.position.x * look_x_follow
	var followed_camera_z: float = float(active_camera_settings["distance"]) + shuttle.position.z * camera_z_follow
	var followed_look_z: float = shuttle.position.z * look_z_follow
	var target_position: Vector3 = Vector3(followed_camera_x, float(active_camera_settings["height"]) + followed_height * 0.35, followed_camera_z)
	var look_at_point: Vector3 = Vector3(followed_look_x, float(active_camera_settings["focus"]) + followed_height, followed_look_z)
	var target_fov: float = float(active_camera_settings["fov"])
	var follow_speed: float = float(active_camera_settings["follow"])
	if camera_mode == "behind":
		var behind_distance: float = float(active_camera_settings["distance"])
		var behind_height: float = float(active_camera_settings["height"])
		var lateral_offset: float = float(active_camera_settings["side"])
		var behind_camera_x: float = player.position.x - behind_distance + shuttle.position.x * camera_x_follow
		var behind_camera_z: float = player.position.z + lateral_offset + (shuttle.position.z - player.position.z) * camera_z_follow
		var behind_look_x: float = player.position.x + float(active_camera_settings["focus"]) + (shuttle.position.x - player.position.x) * look_x_follow
		var behind_look_z: float = player.position.z + (shuttle.position.z - player.position.z) * look_z_follow
		target_position = Vector3(behind_camera_x, behind_height + followed_height * 0.35, behind_camera_z)
		target_position.z = clamp(target_position.z, -match_state.active_half_width() + 0.8, match_state.active_half_width() - 0.8)
		look_at_point = Vector3(behind_look_x, float(active_camera_settings["focus"]) + followed_height, behind_look_z)
	target_position = _clamp_camera_position(target_position)
	if follow_speed <= 0.0:
		return
	camera.position = camera.position.lerp(target_position, min(delta * follow_speed, 1.0))
	camera.position = _clamp_camera_position(camera.position)
	camera.fov = lerp(camera.fov, target_fov, min(delta * 5.0, 1.0))
	camera.look_at(look_at_point, Vector3.UP)

func _clamp_camera_position(value: Vector3) -> Vector3:
	return Vector3(
		clamp(value.x, -CAMERA_ROOM_X_LIMIT, CAMERA_ROOM_X_LIMIT),
		clamp(value.y, CAMERA_ROOM_Y_MIN, CAMERA_ROOM_Y_MAX),
		clamp(value.z, -CAMERA_ROOM_Z_LIMIT, CAMERA_ROOM_Z_LIMIT)
	)

func _default_camera_presets() -> Array:
	return [
		{ "distance": 6.9, "height": 7.8, "focus": 0.45, "follow": 6.0, "follow_y": 1.0, "follow_side": 0.0, "look_z": 0.18, "follow_x": 0.0, "look_x": 0.0, "side": 0.0, "fov": 58.0 },
		{ "distance": 8.2, "height": 8.6, "focus": 0.65, "follow": 5.2, "follow_y": 0.8, "follow_side": 0.15, "look_z": 0.12, "follow_x": 0.08, "look_x": 0.18, "side": 0.0, "fov": 54.0 },
		{ "distance": 5.4, "height": 6.7, "focus": 0.35, "follow": 7.4, "follow_y": 1.0, "follow_side": 0.25, "look_z": 0.30, "follow_x": 0.12, "look_x": 0.25, "side": 0.0, "fov": 62.0 },
		{ "distance": 5.7, "height": 3.35, "focus": 1.15, "follow": 6.0, "follow_y": 0.55, "follow_side": 0.28, "look_z": 0.28, "follow_x": 0.0, "look_x": 0.12, "side": 0.0, "fov": 50.0 },
	]

func _load_camera_presets() -> void:
	camera_presets = _default_camera_presets()
	var config := ConfigFile.new()
	if config.load(camera_settings_path) == OK:
		for i in range(camera_presets.size()):
			var section := "camera_%d" % [i + 1]
			var preset: Dictionary = camera_presets[i].duplicate()
			for key in preset.keys():
				preset[key] = float(config.get_value(section, key, preset[key]))
			camera_presets[i] = preset
	camera_preset_slot = 0
	camera_preset_slot = clamp(camera_preset_slot, 0, camera_presets.size() - 1)
	active_camera_settings = (camera_presets[camera_preset_slot] as Dictionary).duplicate()

func _write_camera_presets() -> void:
	var config := ConfigFile.new()
	config.set_value("camera", "selected", camera_preset_slot)
	for i in range(camera_presets.size()):
		var section := "camera_%d" % [i + 1]
		var preset: Dictionary = camera_presets[i]
		for key in preset.keys():
			config.set_value(section, key, preset[key])
	config.save(camera_settings_path)

func _select_camera_preset(slot: int) -> void:
	if slot < 0 or slot >= camera_presets.size():
		return
	camera_preset_slot = slot
	if slot >= 3:
		camera_mode = "behind"
	else:
		camera_mode = "court"
		court_camera_preset_slot = slot
	active_camera_settings = (camera_presets[camera_preset_slot] as Dictionary).duplicate()
	if hud != null:
		hud.set_camera_slot(camera_preset_slot, active_camera_settings)
	status_text = "Camera dos joueur" if camera_mode == "behind" else "Camera %d" % [camera_preset_slot + 1]
	_update_hud()

func _preview_camera_settings(settings: Dictionary) -> void:
	active_camera_settings = _normalized_camera_settings(settings)

func _save_camera_preset(slot: int, settings: Dictionary) -> void:
	if slot < 0 or slot >= camera_presets.size():
		return
	camera_preset_slot = slot
	if slot >= 3:
		camera_mode = "behind"
	else:
		camera_mode = "court"
		court_camera_preset_slot = slot
	active_camera_settings = _normalized_camera_settings(settings)
	camera_presets[camera_preset_slot] = active_camera_settings.duplicate()
	_write_camera_presets()
	if hud != null:
		hud.set_camera_slot(camera_preset_slot, active_camera_settings)
	status_text = "Camera dos validee" if camera_mode == "behind" else "Camera %d validee" % [camera_preset_slot + 1]
	_update_hud()

func _normalized_camera_settings(settings: Dictionary) -> Dictionary:
	var defaults: Dictionary = _default_camera_presets()[0]
	return {
		"distance": clamp(float(settings.get("distance", defaults["distance"])), 4.0, 11.0),
		"height": clamp(float(settings.get("height", defaults["height"])), 0.15, 10.5),
		"focus": clamp(float(settings.get("focus", defaults["focus"])), 0.1, 2.4),
		"follow": clamp(float(settings.get("follow", defaults["follow"])), 0.0, 12.0),
		"follow_y": clamp(float(settings.get("follow_y", defaults["follow_y"])), 0.0, 1.0),
		"follow_side": clamp(float(settings.get("follow_side", defaults["follow_side"])), 0.0, 1.0),
		"look_z": clamp(float(settings.get("look_z", settings.get("follow_side", defaults["look_z"]))), 0.0, 1.0),
		"follow_x": clamp(float(settings.get("follow_x", defaults["follow_x"])), 0.0, 1.0),
		"look_x": clamp(float(settings.get("look_x", settings.get("follow_x", defaults["look_x"]))), 0.0, 1.0),
		"side": clamp(float(settings.get("side", defaults["side"])), -3.0, 3.0),
		"fov": clamp(float(settings.get("fov", defaults["fov"])), 38.0, 74.0),
	}

func _make_landing_marker() -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = "LandingMarker"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.24
	mesh.bottom_radius = 0.24
	mesh.height = 0.025
	node.mesh = mesh
	node.material_override = GameConfig.material(Color(0.98, 0.82, 0.18))
	return node

func _make_ai_target_marker() -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = "AiTargetMarkerBlueBox"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.45, 0.08, 0.45)
	node.mesh = mesh
	node.position.y = GameConfig.FLOOR_Y + 0.06
	node.material_override = GameConfig.material(Color(0.1, 0.35, 1.0, 0.78))
	node.visible = false
	return node

func _service_kind_from_shot(kind: String) -> String:
	match kind:
		"drop":
			return "serve_short"
		"smash":
			return "serve_drive"
		_:
			return "serve_lob"

func _shot_label(side: String, kind: String) -> String:
	var who: String = "Kai" if side == "player" else "Mina"
	match kind:
		"serve_short":
			return "Service court %s" % who
		"serve_drive":
			return "Service tendu %s" % who
		"serve_lob":
			return "Service lobe %s" % who
		"drop":
			return "Amorti %s" % who
		"smash":
			return "Smash %s" % who
		"drive":
			return "Drive %s" % who
		_:
			return "Lob %s" % who

func _describe_aim(aim: Vector2) -> String:
	if aim.length() < 0.22:
		return "centre"
	var depth: String = ""
	if aim.x > 0.35:
		depth = "long"
	elif aim.x < -0.35:
		depth = "court"
	var lane: String = ""
	if aim.y < -0.35:
		lane = "haut"
	elif aim.y > 0.35:
		lane = "bas"
	if depth == "":
		return lane if lane != "" else "centre"
	if lane == "":
		return depth
	return "%s %s" % [depth, lane]

func _update_hud() -> void:
	var rally: String = "Rally %d" % match_state.rally_count if match_state.rally_active else ("Service Kai" if match_state.server_side == "player" else "Service Mina")
	hud.update_match(match_state.mode, status_text, rally, match_state.player_score, match_state.player_sets, match_state.opponent_score, match_state.opponent_sets)

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
