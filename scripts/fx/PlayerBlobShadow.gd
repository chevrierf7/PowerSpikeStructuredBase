class_name PlayerBlobShadow
extends MeshInstance3D

var opacity := 0.42
var size_x := 2.35
var size_y := 1.12
var shadow_color := Color(0.22, 0.11, 0.04, 1.0)
var follow_light_direction := true
var light_yaw_degrees := -38.0
var offset_distance := 0.04

var _material := ShaderMaterial.new()

func _ready() -> void:
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	mesh = quad
	_material.shader = load("res://materials/fx/BlobShadow.gdshader")
	material_override = _material
	add_to_group("blob_shadows")
	apply_settings({
		"enabled": true,
		"opacity": opacity,
		"size_x": size_x,
		"size_y": size_y,
		"color": shadow_color,
		"angle": light_yaw_degrees,
		"offset_distance": offset_distance,
		"follow_light_direction": follow_light_direction
	})

func apply_settings(settings: Dictionary) -> void:
	visible = bool(settings.get("enabled", true))
	opacity = float(settings.get("opacity", opacity))
	size_x = float(settings.get("size_x", size_x))
	size_y = float(settings.get("size_y", size_y))
	var color_value: Variant = settings.get("color", shadow_color)
	if color_value is Color:
		shadow_color = color_value
	follow_light_direction = bool(settings.get("follow_light_direction", follow_light_direction))
	light_yaw_degrees = float(settings.get("angle", light_yaw_degrees))
	offset_distance = float(settings.get("offset_distance", offset_distance))
	scale = Vector3(size_x, size_y, 1.0)
	_material.set_shader_parameter("shadow_color", Color(shadow_color.r, shadow_color.g, shadow_color.b, 1.0))
	_material.set_shader_parameter("opacity", opacity)

func update_shadow(world_position: Vector3, facing_yaw_degrees: float) -> void:
	var shadow_yaw: float = light_yaw_degrees if follow_light_direction else facing_yaw_degrees
	var yaw_radians := deg_to_rad(shadow_yaw)
	var offset := Vector3(cos(yaw_radians), 0.0, sin(yaw_radians)) * offset_distance
	global_position = Vector3(world_position.x + offset.x, GameConfig.COURT_EFFECT_Y, world_position.z + offset.z)
	global_rotation_degrees = Vector3(-90.0, 0.0, shadow_yaw)
