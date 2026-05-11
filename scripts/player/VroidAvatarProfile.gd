class_name VroidAvatarProfile
extends Resource

@export var id := ""
@export var display_name := ""
@export_file("*.glb", "*.gltf", "*.vrm") var avatar_scene := ""
@export var avatar_rotation_degrees := Vector3.ZERO
@export var visual_yaw_offset_degrees := 0.0
@export var player_side_yaw_offset_degrees := 0.0
@export var opponent_side_yaw_offset_degrees := 0.0
@export var deepmotion_root_yaw_offset_degrees := 0.0
@export var deepmotion_service_root_yaw_offset_degrees := 0.0
@export var deepmotion_service_visual_yaw_offset_degrees := 0.0
@export var deepmotion_service_speed_scale := 1.0
@export var visual_scale := 1.08
@export var hand_grip_rotation := Vector3(0.0, 0.0, 90.0)
@export var racket_offset_position := Vector3(0.07, -0.11, -0.03)
@export var racket_offset_rotation := Vector3(5.0, 10.0, 0.0)
@export_file("*.glb", "*.gltf") var jump_smash_animation_scene := ""
@export_file("*.glb", "*.gltf") var service_animation_scene := ""


func safe_name() -> String:
	return display_name if display_name != "" else id.capitalize()
