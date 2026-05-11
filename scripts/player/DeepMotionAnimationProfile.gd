class_name DeepMotionAnimationProfile
extends Resource

@export var id := ""
@export var display_name := ""
@export_file("*.glb", "*.gltf") var animation_scene := ""
@export var root_yaw_offset_degrees := 0.0
@export var approved_for_game := false


func safe_name() -> String:
	return display_name if display_name != "" else id.capitalize()
