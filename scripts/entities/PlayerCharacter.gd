class_name PlayerCharacter
extends CharacterBody3D

@export var display_name := "Kai"
@export var accent_color := Color(0.1, 0.2, 1.0)
@export var speed := 5.6
@export var acceleration := 18.0
@export var braking := 24.0
@export var close_control_distance := 0.85
@export var burst_distance := 2.30
@export var burst_speed_bonus := 0.18
@export var reach := 1.65
@export var use_imported_model := true
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

var is_hitting := false
var current_state := ""
var hit_animation_state := ""
var animation_player: AnimationPlayer = null
var animation_names := {}
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

@onready var visual_pivot := Node3D.new()

func _ready() -> void:
	add_to_group("players")
	name = display_name
	floor_snap_length = 0.0
	_add_body()
	visual_pivot.name = "PlayerVisualPivot"
	visual_pivot.position.y = visual_ground_offset
	visual_pivot.scale = Vector3.ONE * visual_scale
	add_child(visual_pivot)
	if use_imported_model and ResourceLoader.exists(GameConfig.PLAYER_AVATAR_SCENE):
		_add_imported_avatar()
	else:
		_build_readable_player()
	_add_markers()
	_add_hit_zone()
	set_state("idle")

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

func play_hit(kind: String, backhand: bool = false, recovery_time: float = 0.55) -> void:
	hit_token += 1
	is_hitting = true
	hit_animation_state = _hit_state_from_kind(kind, backhand)
	set_state(hit_animation_state)
	_finish_hit_after_delay(hit_token, recovery_time)

func finish_hit() -> void:
	hit_token += 1
	is_hitting = false
	hit_animation_state = ""
	set_state("idle")

func _finish_hit_after_delay(token: int, recovery_time: float) -> void:
	await get_tree().create_timer(max(recovery_time, 0.12)).timeout
	if token == hit_token and is_hitting:
		finish_hit()

func set_state(state: String) -> void:
	if current_state == state:
		_stabilize_visual_pose()
		return
	current_state = state
	if animation_player == null or not animation_names.has(state):
		_stabilize_visual_pose()
		return
	var animation_name := String(animation_names[state])
	if animation_player.has_animation(animation_name):
		animation_player.play(animation_name)
	_stabilize_visual_pose()

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
	visual_pivot.rotation.y = visual_yaw_offset
	visual_pivot.rotation.z = 0.0
	_stabilize_root_bone()
	_update_head_look()

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
		if direction.length() > 0.15:
			var forward_amount: float = direction.x * court_forward_x
			var lateral_amount: float = direction.z
			target_yaw = clamp(atan2(lateral_amount, max(forward_amount, 0.35)), -0.72, 0.72)
			target_pitch = clamp(atan2(direction.y, max(Vector2(direction.x, direction.z).length(), 0.25)), -0.58, 0.82)
	head_look_yaw = lerp(head_look_yaw, target_yaw, 0.18)
	head_look_pitch = lerp(head_look_pitch, target_pitch, 0.24)
	var look_rotation := Quaternion(Vector3.UP, head_look_yaw) * Quaternion(Vector3.RIGHT, -head_look_pitch)
	skeleton.set_bone_pose_rotation(head_bone_index, head_base_rotation * look_rotation)

func _movement_state_from_input(input: Vector2) -> String:
	var forward_amount: float = input.x * court_forward_x
	var right_amount: float = input.y * court_right_z
	if abs(right_amount) > abs(forward_amount) + 0.15:
		return "move_right" if right_amount > 0.0 else "move_left"
	if abs(forward_amount) > 0.1:
		return "move_forward" if forward_amount > 0.0 else "move_backward"
	return "run"

func _hit_state_from_kind(kind: String, backhand: bool = false) -> String:
	if backhand:
		match kind:
			"drop":
				return "backhand_high_drop"
			"smash", "lob":
				return "backhand_high_clear"
			"drive", "serve_drive":
				return "backhand_drive"
			_:
				return "backhand_high_clear"
	match kind:
		"serve_short":
			return "serve_short"
		"serve_drive":
			return "forehand_drive"
		"serve_lob":
			return "serve_long"
		"drop":
			return "forehand_high_drop"
		"smash":
			return "forehand_high_smash"
		"drive":
			return "forehand_drive"
		"backhand_drop":
			return "backhand_high_drop"
		"backhand_clear":
			return "backhand_high_clear"
		"backhand_drive":
			return "backhand_drive"
		_:
			return "forehand_high_clear"

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
	var scene := load(GameConfig.PLAYER_AVATAR_SCENE)
	if not (scene is PackedScene):
		_build_readable_player()
		return
	var avatar := (scene as PackedScene).instantiate()
	avatar.name = "AnimeBoy"
	avatar.rotation_degrees = Vector3(90.0, 0.0, 0.0)
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

func _setup_animation(model_root: Node) -> void:
	animation_player = _find_first_animation_player(model_root)
	if animation_player == null:
		return
	var animations := animation_player.get_animation_list()
	if animations.is_empty():
		return
	animation_names = {
		"idle": _pick_animation(animations, ["idle", "idle_wait", "attente", "stand", "wait"]),
		"run": _pick_animation(animations, ["run", "running", "walk", "move_forward"]),
		"move_forward": _pick_animation(animations, ["move_forward", "running", "run"]),
		"move_backward": _pick_animation(animations, ["move_backward", "run", "running"]),
		"move_left": _pick_animation(animations, ["move_left", "run", "running"]),
		"move_right": _pick_animation(animations, ["move_right", "run", "running"]),
		"serve_short": _pick_animation(animations, ["serve_short", "service court", "hit"]),
		"serve_long": _pick_animation(animations, ["serve_long", "service long", "hit"]),
		"forehand_low_drop_block": _pick_animation(animations, ["forehand_low_drop_block", "amorti", "drop", "hit"]),
		"forehand_low_lift_clear": _pick_animation(animations, ["forehand_low_lift_clear", "lift", "clear", "hit"]),
		"forehand_drive": _pick_animation(animations, ["forehand_drive", "drive", "tendu", "hit"]),
		"forehand_high_drop": _pick_animation(animations, ["forehand_high_drop", "amorti", "drop", "hit"]),
		"forehand_high_clear": _pick_animation(animations, ["forehand_high_clear", "degage", "clear", "hit", "coup"]),
		"forehand_high_smash": _pick_animation(animations, ["forehand_high_smash", "smash", "tendu"]),
		"backhand_low_drop_block": _pick_animation(animations, ["backhand_low_drop_block", "backhand", "revers", "hit"]),
		"backhand_low_lift": _pick_animation(animations, ["backhand_low_lift", "backhand", "revers", "hit"]),
		"backhand_drive": _pick_animation(animations, ["backhand_drive", "backhand", "revers", "hit"]),
		"backhand_high_drop": _pick_animation(animations, ["backhand_high_drop", "backhand", "revers", "hit"]),
		"backhand_high_clear": _pick_animation(animations, ["backhand_high_clear", "backhand", "revers", "hit"]),
	}
	if String(animation_names["idle"]).is_empty():
		animation_names["idle"] = animations[0]
	for state in animation_names.keys():
		if String(animation_names[state]).is_empty():
			animation_names[state] = animation_names["idle"]
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

func get_service_shuttle_anchor() -> Node3D:
	if service_shuttle_anchor != null and is_instance_valid(service_shuttle_anchor):
		return service_shuttle_anchor
	if skeleton != null:
		var hand_bone := _find_left_hand_bone(skeleton)
		if hand_bone >= 0:
			var attachment := BoneAttachment3D.new()
			attachment.name = "LeftHandServiceAttachment"
			attachment.bone_name = skeleton.get_bone_name(hand_bone)
			attachment.bone_idx = hand_bone
			skeleton.add_child(attachment)
			service_shuttle_anchor = Node3D.new()
			service_shuttle_anchor.name = "ServiceShuttleAnchor"
			attachment.add_child(service_shuttle_anchor)
			return service_shuttle_anchor
	service_shuttle_anchor = Node3D.new()
	service_shuttle_anchor.name = "ServiceShuttleAnchor"
	service_shuttle_anchor.position = Vector3(0.20, 1.02, -0.36 * racket_side_z)
	visual_pivot.add_child(service_shuttle_anchor)
	return service_shuttle_anchor

func _add_racket_to_right_hand(model_root: Node) -> void:
	if not ResourceLoader.exists(GameConfig.RACKET_MODEL_SCENE):
		_add_runtime_racket(visual_pivot)
		return
	var skeleton := _find_first_skeleton(model_root)
	if skeleton == null:
		_add_runtime_racket(visual_pivot)
		return
	var hand_bone := _find_right_hand_bone(skeleton)
	if hand_bone < 0:
		_add_runtime_racket(visual_pivot)
		return
	var attachment := BoneAttachment3D.new()
	attachment.name = "RightHandAttachment"
	attachment.bone_name = skeleton.get_bone_name(hand_bone)
	attachment.bone_idx = hand_bone
	skeleton.add_child(attachment)
	var hand_grip := Node3D.new()
	hand_grip.name = "HandGrip"
	hand_grip.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	attachment.add_child(hand_grip)
	var offset := Node3D.new()
	offset.name = "RacketOffset"
	offset.position = Vector3(0.07, -0.11, -0.03)
	offset.rotation_degrees = Vector3(5.0, 10.0, 0.0)
	hand_grip.add_child(offset)
	var racket_scene := load(GameConfig.RACKET_MODEL_SCENE)
	if racket_scene is PackedScene:
		var racket := (racket_scene as PackedScene).instantiate()
		offset.add_child(racket)
		AnimeVisuals.clear_overlays(racket)
		AnimeVisuals.clear_surface_overrides(racket)
		AnimeVisuals.apply_cast_shadow(racket, false)

func _add_runtime_racket(root: Node3D) -> void:
	var racket := Node3D.new()
	racket.name = "RuntimeRacket"
	racket.position = Vector3(0.31, 0.83, 0.48)
	racket.rotation_degrees = Vector3(0, 0, 12)
	root.add_child(racket)
	_add_part(racket, "Handle", "box", Vector3(0, -0.17, 0), Vector3(0.045, 0.34, 0.045), Color(0.13, 0.08, 0.04))
	_add_part(racket, "FrameTop", "box", Vector3(0, 0.11, 0), Vector3(0.26, 0.035, 0.035), Color(0.92, 0.93, 0.95))
	_add_part(racket, "FrameLeft", "box", Vector3(0, 0.02, -0.13), Vector3(0.035, 0.22, 0.035), Color(0.92, 0.93, 0.95))
	_add_part(racket, "FrameRight", "box", Vector3(0, 0.02, 0.13), Vector3(0.035, 0.22, 0.035), Color(0.92, 0.93, 0.95))

func _build_readable_player() -> void:
	var skin := Color(1.0, 0.76, 0.56)
	var trim := Color(0.95, 0.97, 1.0)
	var hair := Color(0.04, 0.05, 0.08)
	_add_part(visual_pivot, "GroundShadow", "cylinder", Vector3(0, 0.012, 0), Vector3(0.42, 0.014, 0.42), Color(0.02, 0.024, 0.03, 0.18), Vector3(90, 0, 0))
	_add_part(visual_pivot, "Torso", "capsule", Vector3(0, 0.96, 0), Vector3(0.22, 0.56, 0.22), accent_color)
	_add_part(visual_pivot, "ChestStripe", "box", Vector3(0.22, 1.01, 0), Vector3(0.026, 0.36, 0.20), trim)
	_add_part(visual_pivot, "Head", "sphere", Vector3(0.02, 1.47, 0), Vector3(0.20, 0.22, 0.20), skin)
	_add_part(visual_pivot, "HairCap", "sphere", Vector3(-0.015, 1.56, 0), Vector3(0.205, 0.11, 0.205), hair)
	_add_part(visual_pivot, "LeftArm", "capsule", Vector3(0.04, 1.05, -0.32), Vector3(0.10, 0.74, 0.10), skin, Vector3(13, 0, -8))
	_add_part(visual_pivot, "RightArm", "capsule", Vector3(0.12, 1.03, 0.34), Vector3(0.10, 0.78, 0.10), skin, Vector3(-16, 0, 13))
	_add_part(visual_pivot, "LeftLeg", "capsule", Vector3(0.00, 0.27, -0.12), Vector3(0.12, 0.62, 0.12), skin)
	_add_part(visual_pivot, "RightLeg", "capsule", Vector3(0.02, 0.27, 0.12), Vector3(0.12, 0.62, 0.12), skin)
	_add_runtime_racket(visual_pivot)

func _add_part(root: Node3D, part_name: String, shape: String, pos: Vector3, size: Vector3, color: Color, rotation := Vector3.ZERO) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = part_name
	match shape:
		"sphere":
			var sphere := SphereMesh.new()
			sphere.radius = size.x
			sphere.height = size.y * 2.0
			part.mesh = sphere
		"capsule":
			var capsule := CapsuleMesh.new()
			capsule.radius = size.x
			capsule.height = size.y
			part.mesh = capsule
		"cylinder":
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = size.x
			cylinder.bottom_radius = size.z
			cylinder.height = size.y
			part.mesh = cylinder
		_:
			var box := BoxMesh.new()
			box.size = size
			part.mesh = box
	part.position = pos
	part.rotation_degrees = rotation
	part.material_override = GameConfig.material(color)
	part.material_overlay = null
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	root.add_child(part)
	return part

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
	for candidate in ["mixamorig:RightHand", "RightHand", "Hand_R", "hand_r", "Right wrist_061"]:
		var bone := skeleton.find_bone(candidate)
		if bone >= 0:
			return bone
	for i in range(skeleton.get_bone_count()):
		var bone_name := skeleton.get_bone_name(i).to_lower()
		if bone_name.contains("right") and (bone_name.contains("hand") or bone_name.contains("wrist")):
			return i
	return -1

func _find_left_hand_bone(skeleton: Skeleton3D) -> int:
	for candidate in ["mixamorig:LeftHand", "LeftHand", "Hand_L", "hand_l", "Left wrist_033"]:
		var bone := skeleton.find_bone(candidate)
		if bone >= 0:
			return bone
	for i in range(skeleton.get_bone_count()):
		var bone_name := skeleton.get_bone_name(i).to_lower()
		if bone_name.contains("left") and (bone_name.contains("hand") or bone_name.contains("wrist")):
			return i
	return -1

func _find_root_bone(found_skeleton: Skeleton3D) -> int:
	if found_skeleton == null:
		return -1
	for candidate in ["_rootJoint", "Root", "root", "Armature", "Hips_01"]:
		var bone: int = found_skeleton.find_bone(candidate)
		if bone >= 0:
			return bone
	return 0 if found_skeleton.get_bone_count() > 0 else -1

func _find_head_bone(found_skeleton: Skeleton3D) -> int:
	if found_skeleton == null:
		return -1
	for candidate in ["mixamorig:Head", "Head", "head", "Head_05", "Bip001 Head"]:
		var bone: int = found_skeleton.find_bone(candidate)
		if bone >= 0:
			return bone
	for i in range(found_skeleton.get_bone_count()):
		var bone_name := found_skeleton.get_bone_name(i).to_lower()
		if bone_name.contains("head") or bone_name.contains("tete"):
			return i
	return -1

func _pick_animation(animations: PackedStringArray, keywords: Array[String]) -> String:
	for keyword in keywords:
		for animation_name in animations:
			if String(animation_name).to_lower().contains(keyword):
				return String(animation_name)
	return ""
