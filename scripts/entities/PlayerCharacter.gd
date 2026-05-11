class_name PlayerCharacter
extends CharacterBody3D

const VroidAnimationBridge := preload("res://scripts/player/VroidDeepMotionAnimationBridge.gd")
const VROID_READY_POSE_DEGREES := {
	"J_Bip_C_Chest": Vector3(3.0, 0.0, 0.0),
	"J_Bip_C_UpperChest": Vector3(4.0, 0.0, 0.0),
	"J_Bip_R_Shoulder": Vector3(0.0, 0.0, 4.0),
	"J_Bip_R_UpperArm": Vector3(4.0, -6.0, 58.0),
	"J_Bip_R_LowerArm": Vector3(-10.0, 0.0, 18.0),
	"J_Bip_R_Hand": Vector3(-4.0, 4.0, 12.0),
	"J_Bip_L_Shoulder": Vector3(0.0, 0.0, -4.0),
	"J_Bip_L_UpperArm": Vector3(-4.0, 6.0, -58.0),
	"J_Bip_L_LowerArm": Vector3(10.0, 0.0, -18.0),
	"J_Bip_L_Hand": Vector3(4.0, -4.0, -12.0),
	"J_Bip_R_UpperLeg": Vector3(-2.0, 1.0, -2.0),
	"J_Bip_R_LowerLeg": Vector3(5.0, 0.0, 0.0),
	"J_Bip_L_UpperLeg": Vector3(2.0, -1.0, 2.0),
	"J_Bip_L_LowerLeg": Vector3(5.0, 0.0, 0.0),
}

@export var display_name := "Kai"
@export var accent_color := Color(0.1, 0.2, 1.0)
@export var speed := 5.6
@export var acceleration := 18.0
@export var braking := 24.0
@export var close_control_distance := 0.85
@export var burst_distance := 2.30
@export var burst_speed_bonus := 0.18
@export var reach := 1.65
@export var vroid_avatar_profile: VroidAvatarProfile
@export var use_deepmotion_jump_smash := false
@export var deepmotion_jump_smash_scene := GameConfig.DEEPMOTION_JUMP_SMASH_SCENE
@export var deepmotion_service_scene := ""
@export var turn_speed := 8.0
@export var use_directional_movement_animations := false
@export var use_movement_animation := true
@export var movement_animation_state := "run"
@export var visual_scale := 1.08
@export var visual_ground_offset := GameConfig.PLAYER_VISUAL_GROUND_OFFSET
@export var lock_visual_yaw := true
@export var visual_yaw_offset := 0.0
@export var lock_root_bone := false
@export var use_head_look := true
@export var court_forward_x := 1.0
@export var court_right_z := 1.0
@export var racket_side_z := 1.0
@export var arrive_radius := 0.12
@export var show_hit_zone_debug := false
@export var hit_reach_forward := 1.90
@export var hit_reach_backward := 0.70
@export var hit_reach_racket_side := 1.35
@export var hit_reach_backhand_side := 0.85
@export var hit_reach_height := 3.05
@export var debug_animation_import := false

var is_hitting := false
var current_state := ""
var hit_animation_state := ""
var animation_player: AnimationPlayer = null
var real_animation_player: AnimationPlayer = null
var animation_names := {}
var real_animation_names := {}
var real_animation_players := {}
var hit_token := 0
var skeleton: Skeleton3D = null
var root_bone_index := -1
var service_shuttle_anchor: Node3D = null
var hit_zone: Area3D
var hit_zone_debug: MeshInstance3D
var locomotion_state := "idle"
var locomotion_state_changed_at := 0.0
var head_bone_index := -1
var head_base_rotation := Quaternion.IDENTITY
var head_look_yaw := 0.0
var head_look_pitch := 0.0
var head_look_target := Vector3.ZERO
var has_head_look_target := false
var active_profile: PlayerProfile
var imported_avatar_scene := GameConfig.VROID_AVATAR_SCENE
var avatar_rotation_degrees := Vector3.ZERO
var avatar_player_side_yaw_offset_degrees := 0.0
var avatar_opponent_side_yaw_offset_degrees := 0.0
var deepmotion_root_yaw_offset_degrees := 0.0
var deepmotion_service_root_yaw_offset_degrees := 0.0
var deepmotion_service_visual_yaw_offset := 0.0
var deepmotion_service_speed_scale := 1.0
var racket_hand_grip_rotation := Vector3(0.0, 0.0, 90.0)
var racket_offset_position := Vector3(0.07, -0.11, -0.03)
var racket_offset_rotation := Vector3(5.0, 10.0, 0.0)

@onready var visual_pivot := Node3D.new()

func _ready() -> void:
	add_to_group("players")
	name = display_name
	floor_snap_length = 0.0
	_apply_vroid_avatar_profile()
	_add_body()
	visual_pivot.name = "PlayerVisualPivot"
	visual_pivot.position.y = visual_ground_offset
	visual_pivot.scale = Vector3.ONE * visual_scale
	add_child(visual_pivot)
	_add_imported_avatar()
	_add_markers()
	_add_hit_zone()
	if active_profile != null:
		apply_profile(active_profile)
	set_state("idle")

func apply_profile(profile: PlayerProfile) -> void:
	active_profile = profile
	if profile == null:
		return
	if profile.vroid_avatar_profile != null:
		set_vroid_avatar_profile(profile.vroid_avatar_profile)
	display_name = profile.safe_name()
	name = display_name
	accent_color = profile.color_primary
	_apply_profile_materials()

func set_vroid_avatar_profile(profile: VroidAvatarProfile) -> void:
	if profile == null:
		return
	var previous_profile := vroid_avatar_profile
	var previous_scene := vroid_avatar_profile.avatar_scene if vroid_avatar_profile != null else ""
	vroid_avatar_profile = profile
	use_deepmotion_jump_smash = true
	lock_root_bone = false
	_apply_vroid_avatar_profile()
	if not is_node_ready() or visual_pivot == null:
		return
	visual_pivot.scale = Vector3.ONE * visual_scale
	if previous_profile != vroid_avatar_profile or previous_scene != imported_avatar_scene or skeleton == null:
		_rebuild_imported_avatar()

func move_on_court(input: Vector2, delta: float) -> void:
	if input.length() > 1.0:
		input = input.normalized()
	if is_hitting:
		velocity.x = move_toward(velocity.x, 0.0, speed * delta * 8.0)
		velocity.z = move_toward(velocity.z, 0.0, speed * delta * 8.0)
	else:
		var desired_velocity := Vector3(input.x, 0.0, input.y) * speed
		_apply_ground_velocity(desired_velocity, delta)
	move_and_slide()
	if is_hitting:
		set_state(hit_animation_state)
	elif input.length() > 0.1:
		var proposed_state: String = _movement_state_from_input(input) if use_directional_movement_animations else (movement_animation_state if use_movement_animation else "idle")
		set_state(_stable_locomotion_state(proposed_state))
	else:
		set_state(_stable_locomotion_state("idle"))
	_stabilize_visual_pose()

func move_towards(target: Vector3, delta: float) -> void:
	if is_hitting:
		velocity.x = move_toward(velocity.x, 0.0, speed * delta * 8.0)
		velocity.z = move_toward(velocity.z, 0.0, speed * delta * 8.0)
		move_and_slide()
		set_state(hit_animation_state)
		return
	var direction := target - position
	direction.y = 0.0
	if direction.length() <= arrive_radius:
		_apply_ground_velocity(Vector3.ZERO, delta)
	else:
		var desired_speed: float = _profiled_speed_for_distance(direction.length(), speed)
		_apply_ground_velocity(direction.normalized() * desired_speed, delta)
	move_and_slide()
	var move_state: String = _movement_state_from_input(Vector2(velocity.x, velocity.z)) if use_directional_movement_animations else (movement_animation_state if use_movement_animation else "idle")
	var proposed_state: String = move_state if velocity.length() > 0.1 else "idle"
	set_state(_stable_locomotion_state(proposed_state))
	_stabilize_visual_pose()

func recover_towards(target: Vector3, delta: float, speed_scale: float) -> void:
	var direction := target - position
	direction.y = 0.0
	if direction.length() <= arrive_radius:
		_apply_ground_velocity(Vector3.ZERO, delta)
	else:
		var desired_speed: float = _profiled_speed_for_distance(direction.length(), speed * speed_scale)
		_apply_ground_velocity(direction.normalized() * desired_speed, delta)
	move_and_slide()
	if is_hitting:
		set_state(hit_animation_state)
	else:
		var move_state: String = _movement_state_from_input(Vector2(velocity.x, velocity.z)) if use_directional_movement_animations else (movement_animation_state if use_movement_animation else "idle")
		var proposed_state: String = move_state if velocity.length() > 0.1 else "idle"
		set_state(_stable_locomotion_state(proposed_state))
	_stabilize_visual_pose()

func hold_at_position(target: Vector3) -> void:
	velocity = Vector3.ZERO
	position.x = target.x
	position.z = target.z
	move_and_slide()
	if is_hitting:
		set_state(hit_animation_state)
	else:
		set_state(_stable_locomotion_state("idle"))
	_stabilize_visual_pose()

func _stable_locomotion_state(proposed_state: String) -> String:
	if proposed_state == locomotion_state:
		return locomotion_state
	var now: float = Time.get_ticks_msec() / 1000.0
	var minimum_hold: float = 0.14
	if proposed_state == "idle":
		minimum_hold = 0.08
	if now - locomotion_state_changed_at < minimum_hold:
		return locomotion_state
	locomotion_state = proposed_state
	locomotion_state_changed_at = now
	return locomotion_state

func _apply_ground_velocity(desired_velocity: Vector3, delta: float) -> void:
	var rate: float = acceleration
	if desired_velocity.length() < velocity.length() or desired_velocity.length() < 0.05:
		rate = braking
	velocity.x = move_toward(velocity.x, desired_velocity.x, rate * delta)
	velocity.z = move_toward(velocity.z, desired_velocity.z, rate * delta)

func _profiled_speed_for_distance(distance: float, base_speed: float) -> float:
	var brake_factor: float = clamp(distance / max(close_control_distance, 0.01), 0.18, 1.0)
	var burst_factor: float = 1.0
	if distance > burst_distance:
		burst_factor += burst_speed_bonus
	return base_speed * brake_factor * burst_factor

func face_towards(target: Vector3, delta: float) -> void:
	if is_hitting:
		return
	var direction := target - global_position
	direction.y = 0.0
	if direction.length() < 0.55:
		return
	var target_yaw: float = atan2(direction.x, direction.z)
	rotation.y = rotate_toward(rotation.y, target_yaw, turn_speed * delta)
	rotation.x = 0.0
	rotation.z = 0.0

func face_yaw(target_yaw: float, delta: float) -> void:
	if is_hitting:
		return
	rotation.y = rotate_toward(rotation.y, target_yaw, turn_speed * delta)
	rotation.x = 0.0
	rotation.z = 0.0

func force_face_yaw(target_yaw: float, delta: float) -> void:
	rotation.y = target_yaw
	rotation.x = 0.0
	rotation.z = 0.0

func play_hit(kind: String, backhand: bool = false, recovery_time: float = 0.55, animation_override: StringName = &"") -> void:
	hit_token += 1
	is_hitting = true
	hit_animation_state = String(animation_override)
	if kind.begins_with("serve"):
		hit_animation_state = _hit_state_from_kind(kind, backhand)
	elif hit_animation_state.is_empty():
		hit_animation_state = _hit_state_from_kind(kind, backhand)
	_debug_animation_log("play_hit kind=%s backhand=%s requested_animation=%s recovery=%.2f" % [kind, str(backhand), hit_animation_state, recovery_time])
	set_state(hit_animation_state)
	_finish_hit_after_delay(hit_token, recovery_time)

func finish_hit() -> void:
	hit_token += 1
	is_hitting = false
	hit_animation_state = ""
	_reset_real_animation_pose_if_needed()
	set_state("idle")

func _finish_hit_after_delay(token: int, recovery_time: float) -> void:
	await get_tree().create_timer(max(recovery_time, 0.12)).timeout
	if token == hit_token and is_hitting:
		finish_hit()

func set_state(state: String) -> void:
	if current_state == state:
		if state == "idle":
			_apply_vroid_ready_pose_if_needed()
		_stabilize_visual_pose()
		return
	current_state = state
	if state == "jump_smash":
		_debug_animation_log("set_state jump_smash real_names=%s avatar_names=%s" % [str(real_animation_names.keys()), str(animation_names.keys())])
	if _play_real_animation_for_state(state):
		_stabilize_visual_pose()
		return
	if real_animation_player != null and real_animation_player.is_playing():
		real_animation_player.stop()
		_reset_real_animation_pose_if_needed()
	if animation_player == null or not animation_names.has(state):
		if state == "jump_smash":
			_debug_animation_alert("jump_smash demande mais aucun clip avatar disponible dans animation_names.")
		_stabilize_visual_pose()
		return
	var animation_name := String(animation_names[state])
	if animation_player.has_animation(animation_name):
		animation_player.play(animation_name)
		if state == "idle":
			_apply_vroid_ready_pose_if_needed()
		if state == "jump_smash":
			_debug_animation_log("avatar play(%s) called on %s current=%s" % [animation_name, animation_player.name, String(animation_player.current_animation)])
	else:
		if state == "jump_smash":
			_debug_animation_alert("jump_smash demande, animation_names mappe vers %s mais le clip est absent. Available=%s" % [animation_name, str(animation_player.get_animation_list())])
	_stabilize_visual_pose()

func _play_real_animation_for_state(state: String) -> bool:
	var state_player := real_animation_players.get(state, real_animation_player) as AnimationPlayer
	if state_player == null:
		if state == "jump_smash":
			_debug_animation_alert("jump_smash demande mais real_animation_player est null.")
		return false
	if not real_animation_names.has(state):
		if state == "jump_smash":
			_debug_animation_alert("jump_smash demande mais aucun vrai clip n'a ete enregistre. Real available=%s" % [str(state_player.get_animation_list())])
		return false
	var animation_name := String(real_animation_names[state])
	if animation_name.is_empty() or not state_player.has_animation(animation_name):
		if state == "jump_smash":
			_debug_animation_alert("jump_smash vrai clip mappe vers %s mais absent du player. Real available=%s" % [animation_name, str(state_player.get_animation_list())])
		return false
	if animation_player != null and animation_player != state_player and animation_player.is_playing():
		animation_player.stop()
	for player in real_animation_players.values():
		if player is AnimationPlayer and player != state_player and (player as AnimationPlayer).is_playing():
			(player as AnimationPlayer).stop()
	state_player.speed_scale = _real_animation_speed_scale_for_state(state)
	state_player.play(animation_name)
	if state == "jump_smash":
		_debug_animation_log("real play(%s) called on %s current=%s assigned=%s" % [animation_name, state_player.name, String(state_player.current_animation), str(state_player.assigned_animation)])
	return true

func _reset_real_animation_pose_if_needed() -> void:
	if vroid_avatar_profile == null or skeleton == null:
		return
	if real_animation_player != null:
		real_animation_player.stop()
	for player in real_animation_players.values():
		if player is AnimationPlayer:
			(player as AnimationPlayer).stop()
	if skeleton.has_method("reset_bone_poses"):
		skeleton.call("reset_bone_poses")
	elif skeleton.has_method("reset_bone_pose"):
		for bone_index in range(skeleton.get_bone_count()):
			skeleton.call("reset_bone_pose", bone_index)
	if head_bone_index >= 0:
		head_base_rotation = skeleton.get_bone_pose_rotation(head_bone_index)
	head_look_yaw = 0.0
	head_look_pitch = 0.0

func _real_animation_speed_scale_for_state(state: String) -> float:
	if state.begins_with("serve"):
		return max(deepmotion_service_speed_scale, 0.1)
	return 1.0

func _apply_vroid_ready_pose_if_needed() -> void:
	if vroid_avatar_profile == null or skeleton == null or is_hitting:
		return
	for bone_name in VROID_READY_POSE_DEGREES.keys():
		var bone_index := skeleton.find_bone(String(bone_name))
		if bone_index < 0:
			continue
		var degrees := VROID_READY_POSE_DEGREES[bone_name] as Vector3
		var radians := Vector3(deg_to_rad(degrees.x), deg_to_rad(degrees.y), deg_to_rad(degrees.z))
		skeleton.set_bone_pose_rotation(bone_index, Basis.from_euler(radians).get_rotation_quaternion())
	if head_bone_index >= 0:
		head_base_rotation = skeleton.get_bone_pose_rotation(head_bone_index)

func _apply_vroid_avatar_profile() -> void:
	if vroid_avatar_profile == null:
		return
	if not vroid_avatar_profile.avatar_scene.is_empty():
		imported_avatar_scene = vroid_avatar_profile.avatar_scene
	avatar_rotation_degrees = vroid_avatar_profile.avatar_rotation_degrees
	visual_yaw_offset = deg_to_rad(vroid_avatar_profile.visual_yaw_offset_degrees)
	avatar_player_side_yaw_offset_degrees = vroid_avatar_profile.player_side_yaw_offset_degrees
	avatar_opponent_side_yaw_offset_degrees = vroid_avatar_profile.opponent_side_yaw_offset_degrees
	deepmotion_root_yaw_offset_degrees = vroid_avatar_profile.deepmotion_root_yaw_offset_degrees
	deepmotion_service_root_yaw_offset_degrees = vroid_avatar_profile.deepmotion_service_root_yaw_offset_degrees
	deepmotion_service_visual_yaw_offset = deg_to_rad(vroid_avatar_profile.deepmotion_service_visual_yaw_offset_degrees)
	deepmotion_service_speed_scale = vroid_avatar_profile.deepmotion_service_speed_scale
	visual_scale = vroid_avatar_profile.visual_scale
	racket_hand_grip_rotation = vroid_avatar_profile.hand_grip_rotation
	racket_offset_position = vroid_avatar_profile.racket_offset_position
	racket_offset_rotation = vroid_avatar_profile.racket_offset_rotation
	if not vroid_avatar_profile.jump_smash_animation_scene.is_empty():
		deepmotion_jump_smash_scene = vroid_avatar_profile.jump_smash_animation_scene
	if not vroid_avatar_profile.service_animation_scene.is_empty():
		deepmotion_service_scene = vroid_avatar_profile.service_animation_scene

func _process(_delta: float) -> void:
	_stabilize_visual_pose()
	_update_hit_zone_debug()

func set_head_look_target(target: Vector3, enabled: bool) -> void:
	head_look_target = target
	has_head_look_target = enabled

func _stabilize_visual_pose() -> void:
	if not lock_visual_yaw:
		_stabilize_root_bone()
		_update_head_look()
		return
	visual_pivot.rotation.x = 0.0
	visual_pivot.rotation.y = visual_yaw_offset + _state_visual_yaw_offset()
	visual_pivot.rotation.z = 0.0
	_stabilize_root_bone()
	_update_head_look()

func _state_visual_yaw_offset() -> float:
	return deepmotion_service_visual_yaw_offset if current_state.begins_with("serve") else 0.0

func _stabilize_root_bone() -> void:
	if not lock_root_bone or skeleton == null or root_bone_index < 0:
		return
	skeleton.set_bone_pose_position(root_bone_index, Vector3.ZERO)
	skeleton.set_bone_pose_rotation(root_bone_index, Quaternion.IDENTITY)
	skeleton.set_bone_pose_scale(root_bone_index, Vector3.ONE)

func _update_head_look() -> void:
	if not use_head_look or skeleton == null or head_bone_index < 0:
		return
	var target_yaw := 0.0
	var target_pitch := 0.0
	if has_head_look_target:
		var direction := head_look_target - global_position
		direction.y -= 1.58
		var horizontal_distance := Vector2(direction.x, direction.z).length()
		var forward_amount: float = direction.x * court_forward_x
		if direction.length() > 0.15 and horizontal_distance <= 10.5 and forward_amount > -0.55:
			var lateral_amount: float = direction.z
			target_yaw = clamp(atan2(lateral_amount, max(forward_amount, 0.55)), -0.58, 0.58)
			target_pitch = clamp(atan2(direction.y, max(horizontal_distance, 0.35)), -0.34, 0.62)
	head_look_yaw = lerp(head_look_yaw, target_yaw, 0.14)
	head_look_pitch = lerp(head_look_pitch, target_pitch, 0.16)
	var look_rotation := Quaternion(Vector3.UP, head_look_yaw) * Quaternion(Vector3.RIGHT, -head_look_pitch)
	skeleton.set_bone_pose_rotation(head_bone_index, head_base_rotation * look_rotation)

func _movement_state_from_input(input: Vector2) -> String:
	return PlayerAnimationMap.movement_state_from_input(input, court_forward_x, court_right_z)

func _hit_state_from_kind(kind: String, backhand: bool = false) -> String:
	return PlayerAnimationMap.hit_state_from_kind(kind, backhand)

func _add_body() -> void:
	var body := CollisionShape3D.new()
	body.name = "PlayerBody"
	body.position = Vector3(0, 0.91, 0)
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.72
	body.shape = capsule
	add_child(body)

func _add_markers() -> void:
	var socket := Marker3D.new()
	socket.name = "RacketSocket"
	socket.position = Vector3(0.22, 0.95, 0.34)
	socket.rotation_degrees = Vector3(0, 0, 12)
	add_child(socket)
	var hit_point := Marker3D.new()
	hit_point.name = "HitPoint"
	hit_point.position = Vector3(0.56, 1.12, 0.34)
	add_child(hit_point)

func _add_hit_zone() -> void:
	hit_zone = Area3D.new()
	hit_zone.name = "Area3D_HitZone"
	hit_zone.top_level = true
	add_child(hit_zone)
	var shape_node := CollisionShape3D.new()
	shape_node.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = Vector3(hit_reach_forward + hit_reach_backward, hit_reach_height, hit_reach_racket_side + hit_reach_backhand_side)
	shape_node.shape = shape
	hit_zone.add_child(shape_node)
	hit_zone_debug = MeshInstance3D.new()
	hit_zone_debug.name = "HitZoneDebugBlueBox"
	var mesh := BoxMesh.new()
	mesh.size = shape.size
	hit_zone_debug.mesh = mesh
	hit_zone_debug.position = Vector3(0.0, 0.0, 0.0)
	hit_zone_debug.material_override = GameConfig.material(Color(0.0, 0.35, 1.0, 0.22))
	hit_zone_debug.visible = false
	hit_zone.add_child(hit_zone_debug)
	_sync_hit_zone()

func _update_hit_zone_debug() -> void:
	if hit_zone_debug == null:
		return
	_sync_hit_zone()
	hit_zone_debug.visible = show_hit_zone_debug

func _sync_hit_zone() -> void:
	if hit_zone == null:
		return
	var forward_center: float = (hit_reach_forward - hit_reach_backward) * 0.5 * court_forward_x
	var side_center: float = (hit_reach_racket_side - hit_reach_backhand_side) * 0.5 * racket_side_z
	hit_zone.global_position = global_position + Vector3(forward_center, GameConfig.CHARACTER_GROUND_Y + hit_reach_height * 0.5, side_center)
	hit_zone.global_rotation = Vector3.ZERO

func _add_imported_avatar() -> void:
	var scene := load(imported_avatar_scene)
	if not (scene is PackedScene):
		push_error("Profil VRoid invalide ou scene manquante: %s" % imported_avatar_scene)
		return
	var avatar := (scene as PackedScene).instantiate()
	avatar.name = "AnimeBoy"
	avatar.rotation_degrees = avatar_rotation_degrees
	avatar.rotation_degrees.y += avatar_player_side_yaw_offset_degrees if court_forward_x > 0.0 else avatar_opponent_side_yaw_offset_degrees
	visual_pivot.add_child(avatar)
	skeleton = _find_first_skeleton(avatar)
	root_bone_index = _find_root_bone(skeleton)
	head_bone_index = _find_head_bone(skeleton)
	if head_bone_index >= 0:
		head_base_rotation = skeleton.get_bone_pose_rotation(head_bone_index)
	AnimeVisuals.clear_surface_overrides(avatar)
	AnimeVisuals.clear_overlays(avatar)
	AnimeVisuals.apply_cast_shadow(avatar, true)
	_add_racket_to_right_hand(avatar)
	_setup_animation(avatar)
	_setup_deepmotion_jump_smash(avatar)
	_setup_deepmotion_service(avatar)

func _rebuild_imported_avatar() -> void:
	for child in visual_pivot.get_children():
		child.queue_free()
	await get_tree().process_frame
	skeleton = null
	root_bone_index = -1
	head_bone_index = -1
	head_base_rotation = Quaternion.IDENTITY
	real_animation_player = null
	real_animation_names.clear()
	real_animation_players.clear()
	_add_imported_avatar()
	_apply_profile_materials()
	current_state = ""
	set_state("idle")

func _setup_deepmotion_jump_smash(avatar: Node) -> void:
	if not use_deepmotion_jump_smash or not ResourceLoader.exists(deepmotion_jump_smash_scene):
		return
	var player := VroidAnimationBridge.attach_first_animation_from_scene(avatar, deepmotion_jump_smash_scene, "deepmotion_jump_smash", deepmotion_root_yaw_offset_degrees)
	if player == null:
		_debug_animation_alert("DeepMotion jump_smash non charge depuis %s." % deepmotion_jump_smash_scene)
		return
	real_animation_player = player
	real_animation_names["jump_smash"] = "deepmotion_jump_smash"
	real_animation_names["forehand_high_smash"] = "deepmotion_jump_smash"
	real_animation_names["smash_forehand"] = "deepmotion_jump_smash"
	real_animation_players["jump_smash"] = player
	real_animation_players["forehand_high_smash"] = player
	real_animation_players["smash_forehand"] = player
	_debug_animation_log("DeepMotion jump_smash attache au personnage VRoid.")

func _setup_deepmotion_service(avatar: Node) -> void:
	if deepmotion_service_scene.is_empty() or not ResourceLoader.exists(deepmotion_service_scene):
		return
	var player := VroidAnimationBridge.attach_first_animation_from_scene(avatar, deepmotion_service_scene, "deepmotion_service", deepmotion_service_root_yaw_offset_degrees)
	if player == null:
		_debug_animation_alert("DeepMotion service non charge depuis %s." % deepmotion_service_scene)
		return
	real_animation_player = player
	real_animation_names["serve_short"] = "deepmotion_service"
	real_animation_names["serve_long"] = "deepmotion_service"
	real_animation_names["serve_drive"] = "deepmotion_service"
	real_animation_players["serve_short"] = player
	real_animation_players["serve_long"] = player
	real_animation_players["serve_drive"] = player
	_debug_animation_log("DeepMotion service attache au personnage VRoid.")

func _setup_animation(model_root: Node) -> void:
	real_animation_player = _find_first_animation_player(model_root)
	animation_player = real_animation_player
	if real_animation_player == null:
		_debug_animation_alert("Aucun AnimationPlayer trouve dans le personnage importe.")
		return
	var animations := real_animation_player.get_animation_list()
	_debug_animation_log("match AnimationPlayer=%s available=%s" % [real_animation_player.name, str(animations)])
	if animations.is_empty():
		_debug_animation_alert("AnimationPlayer du personnage trouve, mais aucune animation disponible.")
		return
	animation_names = PlayerAnimationMap.build_animation_names(animations)
	_set_loop(String(animation_names["idle"]), true)
	_set_loop(String(animation_names["run"]), true)
	_set_loop(String(animation_names["move_forward"]), true)
	_set_loop(String(animation_names["move_backward"]), true)
	_set_loop(String(animation_names["move_left"]), true)
	_set_loop(String(animation_names["move_right"]), true)
	for state in animation_names.keys():
		if not String(state).begins_with("move") and state != "idle" and state != "run":
			_set_loop(String(animation_names[state]), false)
	animation_player.animation_finished.connect(_on_animation_finished)

func _debug_animation_log(message: String) -> void:
	if debug_animation_import:
		print("[AnimationImportDebug:%s] %s" % [name, message])

func _debug_animation_alert(message: String) -> void:
	if debug_animation_import:
		push_warning("[AnimationImportDebug:%s] %s" % [name, message])
		print("[AnimationImportDebug:%s][ALERT] %s" % [name, message])

func _set_loop(animation_name: String, should_loop: bool) -> void:
	if animation_name.is_empty() or animation_player == null or not animation_player.has_animation(animation_name):
		return
	var animation := animation_player.get_animation(animation_name)
	animation.loop_mode = Animation.LOOP_LINEAR if should_loop else Animation.LOOP_NONE

func _on_animation_finished(animation_name: StringName) -> void:
	var finished := String(animation_name)
	if not is_hitting:
		return
	for state in animation_names.keys():
		if state != "idle" and state != "run" and not String(state).begins_with("move") and finished == String(animation_names[state]):
			finish_hit()
			return

func set_animation_paused(paused: bool) -> void:
	if animation_player != null:
		animation_player.speed_scale = 0.0 if paused else 1.0
	for player in real_animation_players.values():
		if player is AnimationPlayer:
			(player as AnimationPlayer).speed_scale = 0.0 if paused else 1.0

func preview_service_pose(time_seconds: float) -> void:
	is_hitting = true
	hit_animation_state = "serve_short"
	set_state("serve_short")
	var service_player := real_animation_players.get("serve_short", real_animation_player) as AnimationPlayer
	if service_player == null:
		return
	var animation_name := "deepmotion_service"
	if not service_player.has_animation(animation_name):
		animation_name = String(real_animation_names.get("serve_short", ""))
	if animation_name.is_empty() or not service_player.has_animation(animation_name):
		return
	for player in real_animation_players.values():
		if player is AnimationPlayer and player != service_player:
			(player as AnimationPlayer).stop()
	if animation_player != null and animation_player != service_player:
		animation_player.stop()
	var animation: Animation = service_player.get_animation(animation_name)
	var animation_length: float = animation.length if animation != null else max(time_seconds, 0.0)
	var pose_time: float = clamp(time_seconds, 0.0, animation_length)
	service_player.speed_scale = 1.0
	service_player.play(animation_name)
	service_player.seek(pose_time, true)
	service_player.advance(0.0)
	if skeleton != null and skeleton.has_method("force_update_all_bone_transforms"):
		skeleton.call("force_update_all_bone_transforms")
	service_player.speed_scale = 0.0

func apply_racket_attachment_settings(settings: Dictionary) -> void:
	racket_hand_grip_rotation = Vector3(
		float(settings.get("grip_rot_x", racket_hand_grip_rotation.x)),
		float(settings.get("grip_rot_y", racket_hand_grip_rotation.y)),
		float(settings.get("grip_rot_z", racket_hand_grip_rotation.z))
	)
	racket_offset_position = Vector3(
		float(settings.get("offset_x", racket_offset_position.x)),
		float(settings.get("offset_y", racket_offset_position.y)),
		float(settings.get("offset_z", racket_offset_position.z))
	)
	racket_offset_rotation = Vector3(
		float(settings.get("offset_rot_x", racket_offset_rotation.x)),
		float(settings.get("offset_rot_y", racket_offset_rotation.y)),
		float(settings.get("offset_rot_z", racket_offset_rotation.z))
	)
	var hand_grip := _find_node_by_name(visual_pivot, "HandGrip") as Node3D
	if hand_grip != null:
		hand_grip.rotation_degrees = racket_hand_grip_rotation
	var offset := _find_node_by_name(visual_pivot, "RacketOffset") as Node3D
	if offset != null:
		offset.position = racket_offset_position
		offset.rotation_degrees = racket_offset_rotation

func current_real_animation_debug() -> String:
	for player in real_animation_players.values():
		if player is AnimationPlayer:
			var current_player := player as AnimationPlayer
			if current_player.is_playing() or not String(current_player.current_animation).is_empty():
				return "%s:%s x%.2f" % [current_player.name, String(current_player.current_animation), current_player.speed_scale]
	if animation_player != null:
		return "%s:%s x%.2f" % [animation_player.name, String(animation_player.current_animation), animation_player.speed_scale]
	return "none"

func _find_node_by_name(root: Node, node_name: String) -> Node:
	if root == null:
		return null
	if root.name == node_name:
		return root
	for child in root.get_children():
		var found := _find_node_by_name(child, node_name)
		if found != null:
			return found
	return null

func get_service_shuttle_anchor() -> Node3D:
	if service_shuttle_anchor != null and is_instance_valid(service_shuttle_anchor) and service_shuttle_anchor.is_inside_tree():
		return service_shuttle_anchor
	if skeleton != null:
		var hand_bone := _find_left_hand_bone(skeleton)
		if hand_bone >= 0:
			var attachment := BoneAttachment3D.new()
			attachment.name = "FreeHandServiceAttachment"
			attachment.bone_name = skeleton.get_bone_name(hand_bone)
			attachment.bone_idx = hand_bone
			skeleton.add_child(attachment)
			var hand_grip := Node3D.new()
			hand_grip.name = "ServiceShuttleGrip"
			attachment.add_child(hand_grip)
			var offset := Node3D.new()
			offset.name = "ServiceShuttleOffset"
			offset.position = Vector3.ZERO
			offset.rotation_degrees = Vector3.ZERO
			hand_grip.add_child(offset)
			service_shuttle_anchor = offset
			return service_shuttle_anchor
	return null

func apply_service_shuttle_attachment_settings(settings: Dictionary) -> void:
	var anchor := get_service_shuttle_anchor()
	if anchor == null:
		return
	anchor.position = Vector3(
		float(settings.get("forward", anchor.position.x)),
		float(settings.get("height", anchor.position.y)),
		float(settings.get("lateral", anchor.position.z))
	)
	anchor.rotation_degrees = Vector3(
		float(settings.get("rot_x", anchor.rotation_degrees.x)),
		float(settings.get("rot_y", anchor.rotation_degrees.y)),
		float(settings.get("rot_z", anchor.rotation_degrees.z))
	)

func _add_racket_to_right_hand(model_root: Node) -> void:
	if not ResourceLoader.exists(GameConfig.RACKET_MODEL_SCENE):
		push_warning("Modele de raquette introuvable: %s" % GameConfig.RACKET_MODEL_SCENE)
		return
	var skeleton := _find_first_skeleton(model_root)
	if skeleton == null:
		push_warning("Raquette non attachee: aucun squelette VRoid trouve.")
		return
	var hand_bone := _find_right_hand_bone(skeleton)
	if hand_bone < 0:
		push_warning("Raquette non attachee: os de main droite VRoid introuvable.")
		return
	var attachment := BoneAttachment3D.new()
	attachment.name = "RightHandAttachment"
	attachment.bone_name = skeleton.get_bone_name(hand_bone)
	attachment.bone_idx = hand_bone
	skeleton.add_child(attachment)
	var hand_grip := Node3D.new()
	hand_grip.name = "HandGrip"
	hand_grip.rotation_degrees = racket_hand_grip_rotation
	attachment.add_child(hand_grip)
	var offset := Node3D.new()
	offset.name = "RacketOffset"
	offset.position = racket_offset_position
	offset.rotation_degrees = racket_offset_rotation
	hand_grip.add_child(offset)
	var racket_scene := load(GameConfig.RACKET_MODEL_SCENE)
	if racket_scene is PackedScene:
		var racket := (racket_scene as PackedScene).instantiate()
		offset.add_child(racket)
		AnimeVisuals.clear_overlays(racket)
		AnimeVisuals.clear_surface_overrides(racket)
		AnimeVisuals.apply_cast_shadow(racket, false)

func _apply_profile_materials() -> void:
	if active_profile == null or visual_pivot == null:
		return
	var racket_material: Material = active_profile.racket_material if active_profile.racket_material != null else GameConfig.material(active_profile.color_accent)
	if vroid_avatar_profile != null:
		_apply_profile_racket_material_recursive(visual_pivot, racket_material)
		return
	var outfit_material: Material = active_profile.outfit_material if active_profile.outfit_material != null else GameConfig.material(active_profile.color_primary.lerp(Color.WHITE, 0.18))
	var trim_material: Material = GameConfig.material(active_profile.color_secondary.lerp(active_profile.color_accent, 0.35))
	_apply_profile_materials_recursive(visual_pivot, outfit_material, trim_material, racket_material)

func _apply_profile_racket_material_recursive(node: Node, racket_material: Material) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		var lower_name := mesh.name.to_lower()
		if lower_name.contains("racket") or lower_name.contains("frame") or lower_name.contains("handle"):
			mesh.material_override = racket_material
	for child in node.get_children():
		_apply_profile_racket_material_recursive(child, racket_material)

func _apply_profile_materials_recursive(node: Node, outfit_material: Material, trim_material: Material, racket_material: Material) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		var lower_name := mesh.name.to_lower()
		if lower_name.contains("shadow") or lower_name.contains("hitzone"):
			pass
		elif lower_name.contains("racket") or lower_name.contains("frame") or lower_name.contains("handle"):
			mesh.material_override = racket_material
		elif _is_profile_outfit_mesh(lower_name):
			mesh.material_override = outfit_material
		elif _is_profile_trim_mesh(lower_name):
			mesh.material_override = trim_material
		else:
			mesh.material_override = null
	for child in node.get_children():
		_apply_profile_materials_recursive(child, outfit_material, trim_material, racket_material)

func _is_profile_outfit_mesh(lower_name: String) -> bool:
	return (
		lower_name.contains("torso")
		or lower_name.contains("shirt")
		or lower_name.contains("jersey")
		or lower_name.contains("uniform")
		or lower_name.contains("jacket")
		or lower_name.contains("short")
		or lower_name.contains("shoe")
	)

func _is_profile_trim_mesh(lower_name: String) -> bool:
	return (
		lower_name.contains("stripe")
		or lower_name.contains("trim")
		or lower_name.contains("band")
		or lower_name.contains("accent")
	)

func _find_first_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_first_animation_player(child)
		if found != null:
			return found
	return null

func _find_first_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_first_skeleton(child)
		if found != null:
			return found
	return null

func _find_right_hand_bone(skeleton: Skeleton3D) -> int:
	for candidate in ["J_Bip_R_Hand"]:
		var bone := skeleton.find_bone(candidate)
		if bone >= 0:
			return bone
	for i in range(skeleton.get_bone_count()):
		var bone_name := skeleton.get_bone_name(i).to_lower()
		if bone_name.contains("j_bip_r") and bone_name.contains("hand"):
			return i
	return -1

func _find_left_hand_bone(skeleton: Skeleton3D) -> int:
	for candidate in ["J_Bip_L_Hand"]:
		var bone := skeleton.find_bone(candidate)
		if bone >= 0:
			return bone
	for i in range(skeleton.get_bone_count()):
		var bone_name := skeleton.get_bone_name(i).to_lower()
		if bone_name.contains("j_bip_l") and bone_name.contains("hand"):
			return i
	return -1

func _find_left_service_shuttle_bone(skeleton: Skeleton3D) -> int:
	for candidate in ["J_Bip_L_Middle1", "J_Bip_L_Index1", "J_Bip_L_Ring1", "J_Bip_L_Thumb3", "J_Bip_L_Hand"]:
		var bone := skeleton.find_bone(candidate)
		if bone >= 0:
			return bone
	return _find_left_hand_bone(skeleton)

func _find_root_bone(found_skeleton: Skeleton3D) -> int:
	if found_skeleton == null:
		return -1
	for candidate in ["J_Bip_C_Hips"]:
		var bone: int = found_skeleton.find_bone(candidate)
		if bone >= 0:
			return bone
	return 0 if found_skeleton.get_bone_count() > 0 else -1

func _find_head_bone(found_skeleton: Skeleton3D) -> int:
	if found_skeleton == null:
		return -1
	for candidate in ["J_Bip_C_Head"]:
		var bone: int = found_skeleton.find_bone(candidate)
		if bone >= 0:
			return bone
	for i in range(found_skeleton.get_bone_count()):
		var bone_name := found_skeleton.get_bone_name(i).to_lower()
		if bone_name.contains("j_bip_c") and bone_name.contains("head"):
			return i
	return -1
