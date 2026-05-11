extends Node3D

var match_state := MatchState.new()
var player: PlayerCharacter
var opponent: PlayerCharacter
var shuttle: Shuttle
var landing_marker: MeshInstance3D
var ai_target_marker: MeshInstance3D
var camera := Camera3D.new()
var hud: GameHud
var hit_sfx: HitSfx
var render_tuning_panel: Node
var shot_debug_label: Label
var hit_feedback_manager: HitFeedbackManager
var shot_state_machines: Dictionary = {}
var pending_shots: Dictionary = {}
var service_lock_positions: Dictionary = {}
var camera_pulse_until := -10.0
var camera_pulse_intensity := 0.0
var last_hit_feedback_text := ""
var last_hit_feedback_until := -10.0
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
	"height": 0.001
}
var landing_marker_requested_visible := false
var landing_marker_started_at := -10.0
var shuttle_service_attached := false
var service_adjustment_mode_active := false
var service_adjustment_server_side := ""
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
var game_started := false
var game_paused := false
var free_camera_active := false
var free_camera_mouse_look := false
var free_camera_angles := Vector2.ZERO
var free_camera_speed := 5.0
var free_camera_turn_speed := 72.0
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
var player_service_unlocked_at := 0.0
var player_profile: PlayerProfile
var opponent_profile: PlayerProfile
const GYM_SCENE := "res://scenes/environment/Gym_JP_A.tscn"
const COURT_SCENE := "res://scenes/court/Court.tscn"
const RENDER_TUNING_SCENE := "res://scenes/debug/RenderTuningPanel.tscn"
const RACKET_IMPACT_FX_SCENE := "res://scenes/fx/RacketImpactFX.tscn"
const LEGACY_PROJECT_USER_DIR := "Power Spike Structured Base"
const LEGACY_MIGRATION_KEY := "legacy_migrated_from"

func _ready() -> void:
	randomize()
	add_to_group("anime_fx_receivers")
	add_to_group("service_shuttle_receivers")
	add_to_group("hitbox_debug_receivers")
	_ensure_runtime_input_actions()
	_load_camera_presets()
	_build_world()
	_setup_shot_runtime()
	_reset_for_serve()
	game_paused = true
	_set_character_animations_paused(true)
	_update_hud()
	hud.show_main_menu()

func _process(delta: float) -> void:
	_update_landing_marker_visual()
	if game_paused:
		_update_free_camera_keyboard_look(delta)
		_update_free_camera(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and (key.keycode == KEY_P or key.keycode == KEY_ESCAPE):
			if game_started:
				_toggle_pause()
			get_viewport().set_input_as_handled()
	elif game_paused and event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_RIGHT:
			if free_camera_active and mouse_button.pressed:
				free_camera_mouse_look = not free_camera_mouse_look
			elif not free_camera_active:
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
	_ensure_shuttle_instance()
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
	_update_service_shuttle_follow()
	_update_shot_runtime(delta)
	shuttle.update_flight(delta)
	_update_player_head_look()
	_update_reception_state()
	_update_landing_resolution()
	_update_camera(delta)
	_update_ai()
	_update_player_ai()
	_update_shot_debug_overlay()
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

func _shuttle_is_valid() -> bool:
	return shuttle != null and is_instance_valid(shuttle) and not shuttle.is_queued_for_deletion()

func _ensure_shuttle_instance() -> void:
	if _shuttle_is_valid():
		return
	shuttle = Shuttle.new()
	add_child(shuttle)
	shuttle.landed.connect(_on_shuttle_landed)
	shuttle.net_fault.connect(_on_shuttle_net_fault)
	shuttle_service_attached = false

func _build_world() -> void:
	_add_visual_gym()
	_add_gameplay_court()
	player = PlayerCharacter.new()
	player.display_name = "Kai"
	player.accent_color = Color(0.1, 0.2, 1.0)
	var default_vroid_profile := load(GameConfig.DEFAULT_VROID_AVATAR_PROFILE)
	if default_vroid_profile is VroidAvatarProfile:
		player.vroid_avatar_profile = default_vroid_profile as VroidAvatarProfile
	player.use_deepmotion_jump_smash = true
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
	player.use_head_look = false
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
	if default_vroid_profile is VroidAvatarProfile:
		opponent.vroid_avatar_profile = default_vroid_profile as VroidAvatarProfile
	opponent.use_deepmotion_jump_smash = true
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
	opponent.use_head_look = false
	opponent.court_forward_x = -1.0
	opponent.court_right_z = -1.0
	opponent.racket_side_z = -1.0
	opponent.turn_speed = 3.5
	opponent.lock_visual_yaw = true
	opponent.visual_yaw_offset = 0.0
	opponent.lock_root_bone = false
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
	hud.start_game.connect(_start_game)
	hud.resume_requested.connect(_resume_game)
	hud.free_camera_requested.connect(_show_free_camera_pause)
	hud.main_menu_requested.connect(_return_to_main_menu)
	hud.quit_requested.connect(_quit_game)
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
	hud.sfx_volume_changed.connect(_set_sfx_volume)
	hud.set_hitbox_debug(show_debug_hit_zones)
	hud.set_player_ai(player_ai_enabled)
	hud.set_difficulty(String(_difficulty_profile()["label"]))
	hud.set_graphics_mode("Render")
	hud.set_camera_slot(camera_preset_slot, active_camera_settings)
	hit_sfx = HitSfx.new()
	add_child(hit_sfx)
	hit_sfx.set_sfx_volume(hud.get_sfx_volume())
	hit_feedback_manager = HitFeedbackManager.new()
	add_child(hit_feedback_manager)
	_build_shot_debug_overlay()
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

func _build_shot_debug_overlay() -> void:
	shot_debug_label = Label.new()
	shot_debug_label.name = "ShotRuntimeDebug"
	shot_debug_label.visible = true
	shot_debug_label.position = Vector2(18.0, 188.0)
	shot_debug_label.add_theme_font_size_override("font_size", 13)
	shot_debug_label.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0, 0.92))
	shot_debug_label.add_theme_color_override("font_outline_color", Color(0.02, 0.025, 0.03, 0.92))
	shot_debug_label.add_theme_constant_override("outline_size", 3)
	hud.add_child(shot_debug_label)
	_update_shot_debug_overlay()

func _update_shot_debug_overlay() -> void:
	if shot_debug_label == null:
		return
	var side: String = "player"
	if shot_state_machines.has("opponent"):
		var opponent_machine: PlayerShotStateMachine = shot_state_machines["opponent"] as PlayerShotStateMachine
		if opponent_machine != null and opponent_machine.active_shot != null:
			side = "opponent"
	var machine: PlayerShotStateMachine = shot_state_machines.get(side, null) as PlayerShotStateMachine
	var feedback_line: String = last_hit_feedback_text if _now() < last_hit_feedback_until else ""
	if machine == null or machine.active_shot == null:
		shot_debug_label.text = "Shot state: Idle\nShot: -\nImpact: -\nRecovery: -%s" % [("\n" + feedback_line) if feedback_line != "" else ""]
		return
	var shot_data: ShotData = machine.active_shot
	var service_line := _service_attach_debug_line(side)
	shot_debug_label.text = "Side: %s\nShot state: %s\nShot: %s\nImpact: %.2fs\nRecovery: %.2fs%s%s" % [
		side,
		String(machine.state_name()),
		String(shot_data.shot_id),
		shot_data.impact_time,
		shot_data.recovery_time,
		("\n" + feedback_line) if feedback_line != "" else "",
		service_line
	]

func _service_attach_debug_line(side: String) -> String:
	if not pending_shots.has(side):
		return ""
	var pending: Dictionary = pending_shots[side]
	if not GameConfig.is_service_kind(String(pending.get("kind", ""))) or bool(pending.get("impacted", false)):
		return ""
	var holder: PlayerCharacter = player if side == "player" else opponent
	if holder == null or shuttle == null:
		return "\nService attach: missing"
	var anchor := holder.get_service_shuttle_anchor()
	var parent_name := String(shuttle.get_parent().name) if shuttle.get_parent() != null else "none"
	var distance := shuttle.global_position.distance_to(anchor.global_position) if anchor != null else -1.0
	return "\nService attach v2: parent=%s dist=%.3f local=%s adj=%s anim=%s" % [parent_name, distance, str(shuttle.position), str(service_adjustment_mode_active), holder.current_real_animation_debug()]

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
	if not game_started:
		return
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
	if _player_service_is_locked():
		status_text = "Prepare-toi"
		_update_hud()
		return
	_start_rally_from_server("player", "serve_lob")

func _setup_shot_runtime() -> void:
	shot_state_machines = {
		"player": PlayerShotStateMachine.new(),
		"opponent": PlayerShotStateMachine.new()
	}
	for side in shot_state_machines.keys():
		var machine: PlayerShotStateMachine = shot_state_machines[side] as PlayerShotStateMachine
		machine.shot_impact.connect(on_shot_impact.bind(String(side)))
		machine.recovery_start.connect(on_recovery_start.bind(String(side)))
		machine.recovery_end.connect(on_recovery_end.bind(String(side)))

func try_hit(kind: String) -> void:
	if not game_started:
		return
	if player.is_hitting:
		status_text = "Frappe en cours"
		_update_hud()
		return
	if not match_state.rally_active:
		if match_state.match_over or match_state.set_over:
			return
		if match_state.server_side == "player":
			if _player_service_is_locked():
				status_text = "Prepare-toi"
				_update_hud()
				return
			_start_rally_from_server("player", _service_kind_from_shot(kind))
		else:
			status_text = "Service adverse"
			ai_serve_time = _now() + 0.8
			_update_hud()
		return
	if match_state.turn_side != "player" or match_state.match_over:
		return
	if not _player_can_hit(kind):
		_play_miss_sfx()
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
	_ensure_shuttle_instance()
	var server: PlayerCharacter = player if side == "player" else opponent
	_attach_shuttle_to_service_hand(server)
	_hit_from_side(side, service_kind)

func _player_service_is_locked() -> bool:
	return player_service_unlocked_at > 0.0 and _now() < player_service_unlocked_at

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
	var profile: Dictionary = GameConfig.shot_profile(kind)
	profile = profile.duplicate()
	if service_fault_type == "net" or _should_force_net_fault(side, kind):
		profile["net_fault"] = true
	var backhand: bool = _should_use_backhand(hitter, kind)
	_queue_shot_runtime(side, kind, hitter, backhand, target, profile, service_fault_type, float(recovery_profile["swing_recovery_time"]))

func _queue_shot_runtime(side: String, kind: String, hitter: PlayerCharacter, backhand: bool, target: Vector3, profile: Dictionary, service_fault_type: String, recovery_time: float) -> void:
	var shot_data: ShotData = ShotDatabase.data_for_gameplay_kind(kind, backhand).duplicate() as ShotData
	shot_data.recovery_time = max(shot_data.recovery_time, recovery_time)
	if GameConfig.is_service_kind(kind):
		service_lock_positions[side] = hitter.position
	pending_shots[side] = {
		"side": side,
		"kind": kind,
		"hitter": hitter,
		"target": target,
		"profile": profile,
		"service_fault_type": service_fault_type,
		"shot_data": shot_data,
		"impacted": false
	}
	landing_will_be_out = false
	hitter.play_hit(kind, backhand, shot_data.total_lock_time(), shot_data.animation_name)
	var machine: PlayerShotStateMachine = shot_state_machines.get(side, null) as PlayerShotStateMachine
	if machine != null:
		machine.start_shot(shot_data)

func _update_shot_runtime(delta: float) -> void:
	for side in shot_state_machines.keys():
		var machine: PlayerShotStateMachine = shot_state_machines[side] as PlayerShotStateMachine
		if machine == null:
			continue
		_apply_pre_impact_reposition(String(side), delta)
		machine.update(delta)

func _apply_pre_impact_reposition(side: String, delta: float) -> void:
	if not pending_shots.has(side):
		return
	var pending: Dictionary = pending_shots[side]
	if bool(pending.get("impacted", false)):
		return
	var hitter: PlayerCharacter = pending["hitter"] as PlayerCharacter
	var shot_data: ShotData = pending["shot_data"] as ShotData
	if hitter == null or shot_data == null:
		return
	if GameConfig.is_service_kind(String(pending.get("kind", ""))):
		return
	var flat_delta: Vector3 = shuttle.global_position - hitter.global_position
	flat_delta.y = 0.0
	var distance: float = flat_delta.length()
	if distance <= 0.08:
		return
	var max_step: float = hitter.speed * shot_data.move_speed_scale * 0.18 * delta
	var step: Vector3 = flat_delta.normalized() * min(distance, max_step)
	hitter.position += step
	if side == "player":
		_clamp_player()
	else:
		opponent.position = _clamp_opponent_court_position(opponent.position)

func on_shot_impact(shot_data: ShotData, side: String) -> void:
	if not pending_shots.has(side):
		return
	var pending: Dictionary = pending_shots[side]
	pending["impacted"] = true
	pending_shots[side] = pending
	service_lock_positions.erase(side)
	_launch_pending_shot(pending, shot_data)

func on_recovery_start(_shot_data: ShotData, _side: String) -> void:
	pass

func on_recovery_end(_shot_data: ShotData, side: String) -> void:
	pending_shots.erase(side)

func _launch_pending_shot(pending: Dictionary, shot_data: ShotData) -> void:
	var side: String = String(pending["side"])
	var kind: String = String(pending["kind"])
	var target: Vector3 = pending["target"]
	var profile: Dictionary = pending["profile"]
	var service_fault_type: String = String(pending["service_fault_type"])
	shuttle.apply_shot_visual_settings(_shuttle_visual_settings_for_shot(kind))
	if GameConfig.is_service_kind(kind):
		_detach_shuttle_from_service_hand()
	var contact_position: Vector3 = shuttle.global_position
	var predicted: Vector3 = shuttle.launch(target, float(profile["duration"]), float(profile["apex"]), profile)
	shuttle.velocity += Vector3(shot_data.shuttle_spin.x, shot_data.shuttle_spin.y, shot_data.shuttle_spin.z) * 0.02
	if service_fault_type == "technique":
		_play_miss_sfx()
	elif hit_feedback_manager != null:
		hit_feedback_manager.play_hit_feedback(shot_data, contact_position, side)
	else:
		play_impact_sound(String(shot_data.shot_id), shot_data.feedback_intensity, side, "fallback")
		play_impact_flash(contact_position, shot_data.feedback_intensity * shot_data.impact_flash_scale, String(shot_data.shot_id))
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

func play_impact_flash(position: Vector3, intensity: float, shot_id: String) -> void:
	var direction: Vector3 = shuttle.velocity.normalized()
	if direction.length() <= 0.01:
		direction = Vector3.RIGHT if String(match_state.last_hitter_side) == "player" else Vector3.LEFT
	spawn_racket_impact_fx(position, direction, _gameplay_kind_from_shot_id(shot_id), intensity)

func play_impact_sound(shot_id: String, _intensity: float, _hitter_side: String, _sound_variant: String = "default") -> void:
	if hit_sfx == null:
		return
	hit_sfx.play_shot(_gameplay_kind_from_shot_id(shot_id))

func boost_shuttle_trail(duration: float, intensity: float) -> void:
	if shuttle != null and shuttle.has_method("boost_trail"):
		shuttle.call("boost_trail", duration, intensity)

func apply_camera_pulse(intensity: float, _impact_position: Vector3, _hitter_side: String) -> void:
	camera_pulse_intensity = max(camera_pulse_intensity, clamp(intensity, 0.0, 2.0))
	camera_pulse_until = _now() + lerp(0.06, 0.16, clamp(camera_pulse_intensity, 0.0, 1.0))

func show_hit_feedback_debug(shot_id: String, hit_stop_duration: float, feedback_intensity: float) -> void:
	last_hit_feedback_text = "Feedback: %s | stop %.3fs | %.2f" % [shot_id, hit_stop_duration, feedback_intensity]
	last_hit_feedback_until = _now() + 0.65

func _gameplay_kind_from_shot_id(shot_id: String) -> String:
	match shot_id:
		"smash_forehand":
			return "smash"
		"drive_forehand":
			return "drive"
		"net_shot":
			return "drop"
		"defense_block":
			return "drive"
		_:
			return "lob"

func apply_anime_fx_settings(settings: Dictionary) -> void:
	anime_fx_settings = settings.duplicate()

func apply_landing_marker_settings(settings: Dictionary) -> void:
	landing_marker_settings = settings.duplicate()
	_apply_landing_marker_material()
	_update_landing_marker_visual()

func _set_sfx_volume(value: float) -> void:
	if hit_sfx != null:
		hit_sfx.set_sfx_volume(value)

func _play_miss_sfx() -> void:
	if hit_sfx != null:
		hit_sfx.play_miss()

func spawn_racket_impact_fx(racket_position: Vector3, hit_direction: Vector3, shot_kind: String, intensity: float = 1.0) -> void:
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
		fx.call("setup", direction, _scaled_impact_settings(_racket_impact_settings_for_shot(shot_kind), intensity))

func _scaled_impact_settings(settings: Dictionary, intensity: float) -> Dictionary:
	var scaled: Dictionary = settings.duplicate(true)
	var safe_intensity: float = clamp(intensity, 0.0, 2.0)
	scaled["scale"] = float(scaled.get("scale", 1.0)) * lerp(0.78, 1.22, min(safe_intensity, 1.0))
	scaled["opacity"] = clamp(float(scaled.get("opacity", 0.9)) * lerp(0.75, 1.15, min(safe_intensity, 1.0)), 0.0, 1.0)
	scaled["duration"] = max(0.06, float(scaled.get("duration", 0.15)) * lerp(0.82, 1.10, min(safe_intensity, 1.0)))
	return scaled

func _racket_impact_settings_for_shot(shot_kind: String) -> Dictionary:
	var settings := anime_fx_settings.duplicate()
	match shot_kind:
		"smash":
			settings.merge({
				"scale": 1.08,
				"opacity": 0.82,
				"duration": 0.13,
				"color": Color(1.0, 0.34, 0.10, 1.0),
				"flash_color": Color(1.0, 0.80, 0.34, 1.0),
				"stroke_count": 14,
				"length_min": 0.34,
				"length_max": 0.76,
				"width_min": 0.030,
				"width_max": 0.062,
				"flash_radius": 0.14
			}, true)
		"drive", "serve_drive":
			settings.merge({
				"scale": 0.96,
				"opacity": 0.76,
				"duration": 0.12,
				"color": Color(1.0, 0.78, 0.18, 1.0),
				"flash_color": Color(1.0, 0.95, 0.62, 1.0),
				"stroke_count": 10,
				"length_min": 0.28,
				"length_max": 0.62,
				"width_min": 0.022,
				"width_max": 0.048,
				"flash_radius": 0.11
			}, true)
		"drop", "serve_short":
			settings.merge({
				"scale": 0.72,
				"opacity": 0.64,
				"duration": 0.12,
				"color": Color(0.48, 1.0, 0.66, 1.0),
				"flash_color": Color(0.86, 1.0, 0.86, 1.0),
				"stroke_count": 6,
				"length_min": 0.18,
				"length_max": 0.38,
				"width_min": 0.020,
				"width_max": 0.040,
				"flash_radius": 0.09
			}, true)
		"lob", "serve_lob":
			settings.merge({
				"scale": 0.86,
				"opacity": 0.62,
				"duration": 0.16,
				"color": Color(0.44, 0.74, 1.0, 1.0),
				"flash_color": Color(0.84, 0.94, 1.0, 1.0),
				"stroke_count": 8,
				"length_min": 0.24,
				"length_max": 0.58,
				"width_min": 0.020,
				"width_max": 0.048,
				"flash_radius": 0.10
			}, true)
	return settings

func _shuttle_visual_settings_for_shot(shot_kind: String) -> Dictionary:
	match shot_kind:
		"smash":
			return {
				"speed_lines": {
					"enabled": true,
					"opacity": 0.98,
					"main_length": 1.42,
					"width": 0.040,
					"color": Color(1.0, 0.38, 0.12, 1.0)
				}
			}
		"drive", "serve_drive":
			return {
				"speed_lines": {
					"enabled": true,
					"opacity": 0.86,
					"main_length": 1.10,
					"width": 0.032,
					"color": Color(1.0, 0.88, 0.22, 1.0)
				}
			}
		"drop", "serve_short":
			return {
				"speed_lines": {
					"enabled": true,
					"opacity": 0.68,
					"main_length": 0.54,
					"width": 0.024,
					"color": Color(0.44, 1.0, 0.62, 1.0)
				}
			}
		"lob", "serve_lob":
			return {
				"speed_lines": {
					"enabled": true,
					"opacity": 0.68,
					"main_length": 0.94,
					"width": 0.026,
					"color": Color(0.54, 0.82, 1.0, 1.0)
				}
			}
	return {
		"speed_lines": {
			"enabled": true,
			"opacity": 0.76,
			"main_length": 0.96,
			"width": 0.028,
			"color": Color(1.0, 0.94, 0.55, 1.0)
		}
	}

func _racket_contact_position(hitter: PlayerCharacter) -> Vector3:
	var forward := Vector3(hitter.court_forward_x * 0.58, 1.18, hitter.racket_side_z * 0.34)
	return hitter.global_position + forward

func _show_landing_marker(predicted: Vector3) -> void:
	landing_marker.position = Vector3(predicted.x, _landing_marker_y(), predicted.z)
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
	var marker_size: float = lerp(size_start, size_end, t)
	landing_marker.scale = Vector3(marker_size, 1.0, marker_size)
	landing_marker.position.y = _landing_marker_y()

func _landing_marker_y() -> float:
	var height_offset: float = clampf(float(landing_marker_settings.get("height", 0.001)), 0.0, 0.002)
	return GameConfig.COURT_VISUAL_SURFACE_TOP_Y + height_offset

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
	if _service_is_waiting_for_impact():
		_hold_player_during_service("player")
		return
	var input: Vector2 = _physical_input() + hud.move_vector
	if camera_mode == "behind":
		input = Vector2(-input.y, input.x)
	player.move_on_court(input, delta)
	_clamp_player()

func _update_player_ai_movement(delta: float) -> void:
	if _service_is_waiting_for_impact():
		_hold_player_during_service("player")
		return
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
	if _service_is_waiting_for_impact():
		player.force_face_yaw(PI * 0.5, delta)
		opponent.force_face_yaw(-PI * 0.5, delta)
		return
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
	if _service_is_waiting_for_impact():
		_hold_player_during_service("opponent")
		return
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

func _hold_player_during_service(side: String) -> void:
	var character := player if side == "player" else opponent
	var lock_position: Vector3 = service_lock_positions.get(side, character.position)
	character.hold_at_position(lock_position)

func _service_is_waiting_for_impact() -> bool:
	return _service_pending_side() != ""

func _service_pending_side() -> String:
	for pending in pending_shots.values():
		if not (pending is Dictionary):
			continue
		var kind := String((pending as Dictionary).get("kind", ""))
		if GameConfig.is_service_kind(kind) and not bool((pending as Dictionary).get("impacted", false)):
			return String((pending as Dictionary).get("side", ""))
	return ""

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
					status_text = "%s en retard" % _side_name("opponent")
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
	return AIDecisionMaker.choose_opponent_shot(_difficulty_profile())

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
	return AIDecisionMaker.apply_difficulty_error(kind, target, match_state.active_half_width(), _difficulty_profile())

func _service_fault_type(side: String, kind: String) -> String:
	if side == "player" and not player_ai_enabled:
		return ""
	return AIDecisionMaker.service_fault_type(kind, _difficulty_profile())

func _make_service_target_out(side: String, target: Vector3) -> Vector3:
	return AIDecisionMaker.make_service_target_out(side, target, match_state.service_long_limit(), match_state.active_half_width())

func _should_force_net_fault(side: String, kind: String) -> bool:
	if side == "player" and not player_ai_enabled:
		return false
	return AIDecisionMaker.should_force_net_fault(kind, _difficulty_profile())

func _choose_player_ai_shot() -> String:
	return AIDecisionMaker.choose_player_ai_shot()

func _choose_player_ai_service_kind() -> String:
	return AIDecisionMaker.choose_player_ai_service_kind()

func _choose_player_ai_return_shot() -> String:
	return AIDecisionMaker.choose_player_ai_return_shot(match_state.last_shot_kind)

func _choose_ai_service_kind() -> String:
	return AIDecisionMaker.choose_opponent_service_kind(_player_receiver_aggressiveness())

func _choose_ai_return_shot() -> String:
	return AIDecisionMaker.choose_opponent_return_shot(match_state.last_shot_kind, opponent_receiver_aggressiveness)

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
	_show_landing_marker(Vector3(shuttle.global_position.x, GameConfig.COURT_VISUAL_SURFACE_TOP_Y, shuttle.global_position.z))
	opponent_has_reception_target = false
	player_has_reception_target = false
	ai_target_marker.visible = false
	hud.set_timing("")
	landing_winner = match_state.shuttle_landing_side if landing_will_be_out else match_state.last_hitter_side
	landing_reason = "Faute service" if landing_will_be_out and GameConfig.is_service_kind(match_state.last_shot_kind) else ("Faute dehors" if landing_will_be_out else "Point")
	status_text = landing_reason
	landing_pending = true
	landing_resolve_time = _now() + 1.0
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
	landing_resolve_time = _now() + 1.0
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
		status_text = "%s %s" % [landing_reason, _side_name(landing_winner)]
	_reset_for_serve()
	_update_hud()
	if match_state.server_side == "opponent" and not match_state.set_over and not match_state.match_over:
		ai_serve_time = _now() + 1.2
	if player_ai_enabled and match_state.server_side == "player" and not match_state.set_over and not match_state.match_over:
		player_ai_serve_time = _now() + 1.0

func _record_ai_match_point() -> void:
	var saved := StatsRecorder.record_point({
		"timestamp": Time.get_datetime_string_from_system(),
		"difficulty": String(_difficulty_profile()["label"]),
		"mode": match_state.mode,
		"server": rally_start_server,
		"service": rally_start_service_kind,
		"winner": landing_winner,
		"reason": landing_reason,
		"hits": match_state.rally_count,
		"duration_s": "%.2f" % max(_now() - rally_start_time, 0.0),
		"last_hitter": match_state.last_hitter_side,
		"last_shot": match_state.last_shot_kind,
		"score_kai_before": match_state.player_score,
		"score_mina_before": match_state.opponent_score,
		"sets_kai": match_state.player_sets,
		"sets_mina": match_state.opponent_sets
	})
	if not saved:
		status_text = "Stats non enregistrees"

func _reset_for_serve() -> void:
	_detach_shuttle_from_service_hand()
	_ensure_shuttle_instance()
	player.finish_hit()
	opponent.finish_hit()
	pending_shots.clear()
	service_lock_positions.clear()
	for side in shot_state_machines.keys():
		var machine: PlayerShotStateMachine = shot_state_machines[side] as PlayerShotStateMachine
		if machine != null:
			machine.force_idle()
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
	if match_state.rally_active:
		return
	_ensure_shuttle_instance()
	var holder: PlayerCharacter = player if match_state.server_side == "player" else opponent
	_attach_shuttle_to_service_hand(holder)

func _update_service_shuttle_follow() -> void:
	var side := _service_pending_side()
	if side == "":
		return
	var holder: PlayerCharacter = player if side == "player" else opponent
	_attach_shuttle_to_service_hand(holder)

func _attach_shuttle_to_service_hand(holder: PlayerCharacter) -> void:
	if holder == null:
		return
	_ensure_shuttle_instance()
	var anchor := holder.get_service_shuttle_anchor()
	if anchor == null:
		return
	holder.apply_service_shuttle_attachment_settings(_service_settings_for_holder(holder))
	if shuttle.get_parent() != anchor:
		shuttle.reparent(anchor, false)
	shuttle_service_attached = true
	shuttle.set_service_hold_position(Vector3.ZERO)
	shuttle.scale = Vector3.ONE

func _detach_shuttle_from_service_hand() -> void:
	if not _shuttle_is_valid():
		shuttle_service_attached = false
		return
	if not shuttle_service_attached:
		return
	shuttle.reparent(self, true)
	shuttle_service_attached = false

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

func apply_service_racket_settings(settings: Dictionary) -> void:
	var player_racket_settings := _service_racket_settings_for_side(settings, "kai")
	if player != null:
		player.apply_racket_attachment_settings(player_racket_settings)
	if opponent != null:
		opponent.apply_racket_attachment_settings(player_racket_settings)

func apply_service_adjustment_mode(settings: Dictionary) -> void:
	if not bool(settings.get("enabled", false)):
		if service_adjustment_mode_active:
			service_adjustment_mode_active = false
			service_adjustment_server_side = ""
			_detach_shuttle_from_service_hand()
			game_paused = false
			_set_character_animations_paused(false)
			status_text = "Reprise"
			_update_hud()
		return
	_ensure_shuttle_instance()
	var setup_required := not service_adjustment_mode_active or service_adjustment_server_side != match_state.server_side
	if setup_required:
		service_adjustment_mode_active = true
		service_adjustment_server_side = match_state.server_side
		_detach_shuttle_from_service_hand()
	if setup_required and match_state.rally_active:
		match_state.rally_active = false
		pending_shots.clear()
		service_lock_positions.clear()
		for side in shot_state_machines.keys():
			var machine: PlayerShotStateMachine = shot_state_machines[side] as PlayerShotStateMachine
			if machine != null:
				machine.force_idle()
		player_ai_action_time = -1.0
		ai_serve_time = -1.0
		player_ai_serve_time = -1.0
		shuttle.in_flight = false
	if setup_required and player != null:
		player.position = match_state.pre_serve_position_for_side("player")
		player.velocity = Vector3.ZERO
		player.finish_hit()
	if setup_required and opponent != null:
		opponent.position = match_state.pre_serve_position_for_side("opponent")
		opponent.velocity = Vector3.ZERO
		opponent.finish_hit()
	game_paused = true
	free_camera_active = false
	free_camera_mouse_look = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var holder: PlayerCharacter = player if match_state.server_side == "player" else opponent
	if holder != null:
		_attach_shuttle_to_service_hand(holder)
		holder.preview_service_pose(float(settings.get("time", 1.0)))
	_attach_shuttle_to_service_hand(holder)
	_set_character_animations_paused(true)
	status_text = "Reglage service"
	_update_hud()

func _service_racket_settings_for_side(settings: Dictionary, prefix: String) -> Dictionary:
	return {
		"grip_rot_x": float(settings.get("%s_racket_grip_rot_x" % prefix, 0.0)),
		"grip_rot_y": float(settings.get("%s_racket_grip_rot_y" % prefix, 0.0)),
		"grip_rot_z": float(settings.get("%s_racket_grip_rot_z" % prefix, 90.0)),
		"offset_x": float(settings.get("%s_racket_offset_x" % prefix, 0.07)),
		"offset_y": float(settings.get("%s_racket_offset_y" % prefix, -0.11)),
		"offset_z": float(settings.get("%s_racket_offset_z" % prefix, -0.03)),
		"offset_rot_x": float(settings.get("%s_racket_offset_rot_x" % prefix, 5.0)),
		"offset_rot_y": float(settings.get("%s_racket_offset_rot_y" % prefix, 10.0)),
		"offset_rot_z": float(settings.get("%s_racket_offset_rot_z" % prefix, 0.0))
	}

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
		status_text = "Service " + _side_name("opponent")
		ai_serve_time = _now() + 0.9
		_update_hud()

func _ensure_player_ai_service_pending() -> void:
	if not player_ai_enabled or match_state.match_over or match_state.set_over or match_state.rally_active:
		return
	if match_state.server_side == "player" and player_ai_serve_time < 0.0:
		status_text = "Service %s IA" % _side_name("player")
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
	return _point_inside_character_hit_zone(character, shuttle.global_position, reach_bonus, vertical_reach)

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
	player.set_head_look_target(shuttle.global_position, false)
	opponent.set_head_look_target(shuttle.global_position, false)
	return
	var shuttle_target := shuttle.global_position
	var head_look_active: bool = (match_state.rally_active or shuttle.in_flight) and _head_look_target_is_valid(shuttle_target)
	if not head_look_active:
		player.set_head_look_target(shuttle_target, false)
		opponent.set_head_look_target(shuttle_target, false)
		return
	var aimed_point: Vector3 = landing_marker.global_position + Vector3(0.0, 0.28, 0.0)
	var player_target: Vector3 = shuttle_target
	var opponent_target: Vector3 = shuttle_target
	if match_state.last_hitter_side == "player" and player.is_hitting:
		player_target = aimed_point
	if match_state.last_hitter_side == "opponent" and opponent.is_hitting:
		opponent_target = aimed_point
	player.set_head_look_target(player_target, _character_can_track_head_target(player, player_target))
	opponent.set_head_look_target(opponent_target, _character_can_track_head_target(opponent, opponent_target))

func _head_look_target_is_valid(target: Vector3) -> bool:
	return target.y > GameConfig.CHARACTER_GROUND_Y + 0.34

func _character_can_track_head_target(character: PlayerCharacter, target: Vector3) -> bool:
	if character == null:
		return false
	if not _head_look_target_is_valid(target):
		return false
	var direction := target - character.global_position
	var horizontal_distance := Vector2(direction.x, direction.z).length()
	if horizontal_distance > 10.5:
		return false
	var forward_amount: float = direction.x * character.court_forward_x
	return forward_amount > -0.55

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

func _start_game(menu_settings: Dictionary) -> void:
	match_state = MatchState.new()
	match_state.mode = String(menu_settings.get("mode", "singles"))
	player_ai_enabled = bool(menu_settings.get("player_ai_enabled", false))
	difficulty_level = String(menu_settings.get("difficulty", difficulty_level))
	_apply_selected_profiles()
	var start_camera_slot: int = int(menu_settings.get("camera_slot", 0))
	player_ai_action_time = -1.0
	player_ai_serve_time = -1.0
	ai_serve_time = -1.0
	next_ai_action_time = -1.0
	game_started = true
	game_paused = false
	service_adjustment_mode_active = false
	service_adjustment_server_side = ""
	free_camera_active = false
	player_service_unlocked_at = _now() + 2.0
	free_camera_mouse_look = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_set_character_animations_paused(false)
	status_text = "Pret a servir"
	hud.hide_menus()
	hud.setup_profiles(player_profile, opponent_profile)
	hud.set_player_ai(player_ai_enabled)
	hud.set_difficulty(String(_difficulty_profile()["label"]))
	_reset_for_serve()
	_select_camera_preset(start_camera_slot)
	_update_hud()
	if player_ai_enabled and match_state.server_side == "player":
		player_ai_serve_time = player_service_unlocked_at

func _apply_selected_profiles() -> void:
	var selection := get_node_or_null("/root/GameSelection")
	if selection != null:
		player_profile = selection.get_player_1()
		opponent_profile = selection.get_player_2()
	if player_profile == null:
		player_profile = load("res://data/players/kai.tres")
	if opponent_profile == null:
		opponent_profile = load("res://data/players/mina.tres")
	_restore_render_materials_before_profile()
	if player != null:
		player.apply_profile(player_profile)
	if opponent != null:
		opponent.apply_profile(opponent_profile)
	_reapply_render_tuning_deferred()

func _restore_render_materials_before_profile() -> void:
	if render_tuning_panel != null and render_tuning_panel.has_method("restore_original_materials"):
		render_tuning_panel.call("restore_original_materials")

func _reapply_render_tuning_deferred() -> void:
	await get_tree().process_frame
	if render_tuning_panel != null and render_tuning_panel.has_method("_resolve_targets"):
		render_tuning_panel.call("_resolve_targets")
	if render_tuning_panel != null and render_tuning_panel.has_method("_apply_all"):
		render_tuning_panel.call("_apply_all")

func _resume_game() -> void:
	if not game_started:
		return
	service_adjustment_mode_active = false
	service_adjustment_server_side = ""
	_detach_shuttle_from_service_hand()
	game_paused = false
	free_camera_active = false
	free_camera_mouse_look = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_set_character_animations_paused(false)
	status_text = "Reprise"
	hud.hide_menus()
	_update_hud()

func _show_free_camera_pause() -> void:
	if not game_started:
		return
	game_paused = true
	free_camera_active = true
	free_camera_mouse_look = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	free_camera_angles = Vector2(camera.rotation_degrees.x, camera.rotation_degrees.y)
	_set_character_animations_paused(true)
	status_text = "Pause - camera libre"
	hud.set_pause_visible(false)
	_update_hud()

func _return_to_main_menu() -> void:
	game_started = false
	game_paused = true
	service_adjustment_mode_active = false
	service_adjustment_server_side = ""
	free_camera_active = false
	free_camera_mouse_look = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	match_state = MatchState.new()
	status_text = "Pret a servir"
	_set_character_animations_paused(true)
	_reset_for_serve()
	hud.show_main_menu()
	_update_hud()

func _quit_game() -> void:
	get_tree().quit()

func _toggle_pause() -> void:
	game_paused = not game_paused
	free_camera_active = false
	free_camera_mouse_look = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_set_character_animations_paused(game_paused)
	if game_paused:
		free_camera_angles = Vector2(camera.rotation_degrees.x, camera.rotation_degrees.y)
		status_text = "Pause - camera libre"
	else:
		status_text = "Reprise"
	if hud != null:
		if game_paused:
			hud.set_pause_visible(true)
		else:
			hud.hide_menus()
	_update_hud()

func _set_character_animations_paused(paused: bool) -> void:
	if player != null:
		player.set_animation_paused(paused)
	if opponent != null:
		opponent.set_animation_paused(paused)

func _toggle_hitbox_debug() -> void:
	show_debug_hit_zones = not show_debug_hit_zones
	hud.set_hitbox_debug(show_debug_hit_zones)

func apply_hitbox_debug_settings(settings: Dictionary) -> void:
	show_debug_hit_zones = bool(settings.get("enabled", show_debug_hit_zones))
	if hud != null:
		hud.set_hitbox_debug(show_debug_hit_zones)

func _toggle_player_ai() -> void:
	player_ai_enabled = not player_ai_enabled
	player_ai_action_time = -1.0
	player_ai_serve_time = -1.0
	hud.move_vector = Vector2.ZERO
	hud.aim_vector = Vector2.ZERO
	hud.set_player_ai(player_ai_enabled)
	status_text = "%s IA" % _side_name("player") if player_ai_enabled else "%s joueur" % _side_name("player")
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
	GameCameraController.update_free_camera(camera, delta, free_camera_speed)

func _update_free_camera_keyboard_look(delta: float) -> void:
	if not free_camera_active:
		return
	var yaw_input := 0.0
	var pitch_input := 0.0
	if Input.is_key_pressed(KEY_KP_4):
		yaw_input += 1.0
	if Input.is_key_pressed(KEY_KP_6):
		yaw_input -= 1.0
	if Input.is_key_pressed(KEY_KP_8):
		pitch_input += 1.0
	if Input.is_key_pressed(KEY_KP_2):
		pitch_input -= 1.0
	if absf(yaw_input) < 0.01 and absf(pitch_input) < 0.01:
		return
	free_camera_angles.x = clampf(free_camera_angles.x + pitch_input * free_camera_turn_speed * delta, -86.0, 86.0)
	free_camera_angles.y += yaw_input * free_camera_turn_speed * delta
	camera.rotation_degrees = Vector3(free_camera_angles.x, free_camera_angles.y, 0.0)

func _update_camera(delta: float) -> void:
	if game_paused:
		return
	GameCameraController.update_follow_camera(
		camera,
		player.position,
		shuttle.global_position,
		camera_mode,
		active_camera_settings,
		match_state.active_half_width(),
		delta
	)
	_apply_camera_pulse_offset()

func _apply_camera_pulse_offset() -> void:
	var now: float = _now()
	if now > camera_pulse_until or camera_pulse_intensity <= 0.001:
		camera_pulse_intensity = 0.0
		return
	var remaining: float = clamp((camera_pulse_until - now) / 0.16, 0.0, 1.0)
	var amplitude: float = 0.018 * camera_pulse_intensity * remaining
	camera.position += Vector3(randf_range(-amplitude, amplitude), randf_range(-amplitude * 0.45, amplitude * 0.45), 0.0)

func _clamp_camera_position(value: Vector3) -> Vector3:
	return GameCameraController.clamp_position(value)

func _default_camera_presets() -> Array:
	return CameraPresetStore.default_presets()

func _load_camera_presets() -> void:
	var camera_load_path := camera_settings_path
	var legacy_path := _legacy_user_file_path("camera_presets.cfg")
	var migrated_from := ""
	if FileAccess.file_exists(camera_settings_path):
		var current_config := ConfigFile.new()
		current_config.load(camera_settings_path)
		if legacy_path != "" and String(current_config.get_value("meta", LEGACY_MIGRATION_KEY, "")) != LEGACY_PROJECT_USER_DIR:
			camera_load_path = legacy_path
			migrated_from = LEGACY_PROJECT_USER_DIR
	elif legacy_path != "":
		camera_load_path = legacy_path
		migrated_from = LEGACY_PROJECT_USER_DIR
	camera_presets = CameraPresetStore.load_presets(camera_load_path)
	camera_preset_slot = 0
	camera_preset_slot = clamp(camera_preset_slot, 0, camera_presets.size() - 1)
	active_camera_settings = (camera_presets[camera_preset_slot] as Dictionary).duplicate()
	if camera_load_path != camera_settings_path:
		_write_camera_presets(migrated_from)

func _write_camera_presets(migrated_from := "") -> void:
	if migrated_from == "" and FileAccess.file_exists(camera_settings_path):
		var config := ConfigFile.new()
		if config.load(camera_settings_path) == OK:
			migrated_from = String(config.get_value("meta", LEGACY_MIGRATION_KEY, ""))
	CameraPresetStore.save_presets(camera_settings_path, camera_preset_slot, camera_presets, migrated_from)

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
	return CameraPresetStore.normalized(settings)

func _legacy_user_file_path(file_name: String) -> String:
	var current_dir := ProjectSettings.globalize_path("user://")
	if current_dir == "":
		return ""
	var legacy_path := current_dir.get_base_dir().path_join(LEGACY_PROJECT_USER_DIR).path_join(file_name)
	return legacy_path if FileAccess.file_exists(legacy_path) else ""

func _make_landing_marker() -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = "LandingMarker"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.24
	mesh.bottom_radius = 0.24
	mesh.height = 0.008
	node.mesh = mesh
	node.position.y = _landing_marker_y()
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
	var who: String = _side_name(side)
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
	var rally: String = "Rally %d" % match_state.rally_count if match_state.rally_active else ("Service " + _side_name(match_state.server_side))
	var server_name: String = _side_name(match_state.server_side)
	var point_winner_name: String = ""
	if not landing_pending and status_text.begins_with("Point"):
		point_winner_name = _side_name(landing_winner) if landing_winner != "" else ""
	hud.update_match(match_state.mode, status_text, rally, match_state.player_score, match_state.player_sets, match_state.opponent_score, match_state.opponent_sets, server_name, point_winner_name)

func _side_name(side: String) -> String:
	var profile := player_profile if side == "player" else opponent_profile
	if profile != null:
		return profile.safe_name()
	return "Kai" if side == "player" else "Mina"

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
