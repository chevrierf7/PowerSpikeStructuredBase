class_name GameCameraController
extends RefCounted

const ROOM_X_LIMIT := 10.35
const ROOM_Z_LIMIT := 7.05
const ROOM_Y_MIN := 0.08
const ROOM_Y_MAX := 6.55

static func update_free_camera(camera: Camera3D, delta: float, free_camera_speed: float) -> void:
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
		camera.position = clamp_position(camera.position)

static func update_follow_camera(
	camera: Camera3D,
	player_position: Vector3,
	shuttle_position: Vector3,
	camera_mode: String,
	settings: Dictionary,
	active_half_width: float,
	delta: float
) -> void:
	var shuttle_focus: float = clamp(shuttle_position.y * 0.42, 0.0, 2.2)
	var side_offset: float = float(settings["side"])
	var vertical_follow: float = float(settings["follow_y"])
	var camera_z_follow: float = float(settings["follow_side"])
	var look_z_follow: float = float(settings["look_z"])
	var camera_x_follow: float = float(settings["follow_x"])
	var look_x_follow: float = float(settings["look_x"])
	var followed_height: float = shuttle_focus * vertical_follow
	var followed_camera_x: float = side_offset + shuttle_position.x * camera_x_follow
	var followed_look_x: float = side_offset + shuttle_position.x * look_x_follow
	var followed_camera_z: float = float(settings["distance"]) + shuttle_position.z * camera_z_follow
	var followed_look_z: float = shuttle_position.z * look_z_follow
	var target_position: Vector3 = Vector3(followed_camera_x, float(settings["height"]) + followed_height * 0.35, followed_camera_z)
	var look_at_point: Vector3 = Vector3(followed_look_x, float(settings["focus"]) + followed_height, followed_look_z)
	var target_fov: float = float(settings["fov"])
	var follow_speed: float = float(settings["follow"])
	if camera_mode == "behind":
		var behind_distance: float = float(settings["distance"])
		var behind_height: float = float(settings["height"])
		var lateral_offset: float = float(settings["side"])
		var behind_camera_x: float = player_position.x - behind_distance + shuttle_position.x * camera_x_follow
		var behind_camera_z: float = player_position.z + lateral_offset + (shuttle_position.z - player_position.z) * camera_z_follow
		var behind_look_x: float = player_position.x + float(settings["focus"]) + (shuttle_position.x - player_position.x) * look_x_follow
		var behind_look_z: float = player_position.z + (shuttle_position.z - player_position.z) * look_z_follow
		target_position = Vector3(behind_camera_x, behind_height + followed_height * 0.35, behind_camera_z)
		target_position.z = clamp(target_position.z, -active_half_width + 0.8, active_half_width - 0.8)
		look_at_point = Vector3(behind_look_x, float(settings["focus"]) + followed_height, behind_look_z)
	target_position = clamp_position(target_position)
	if follow_speed <= 0.0:
		return
	camera.position = camera.position.lerp(target_position, min(delta * follow_speed, 1.0))
	camera.position = clamp_position(camera.position)
	camera.fov = lerp(camera.fov, target_fov, min(delta * 5.0, 1.0))
	camera.look_at(look_at_point, Vector3.UP)

static func clamp_position(value: Vector3) -> Vector3:
	return Vector3(
		clamp(value.x, -ROOM_X_LIMIT, ROOM_X_LIMIT),
		clamp(value.y, ROOM_Y_MIN, ROOM_Y_MAX),
		clamp(value.z, -ROOM_Z_LIMIT, ROOM_Z_LIMIT)
	)
