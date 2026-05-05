class_name PlayerProjectedShadow
extends Node3D

var enabled := true
var opacity := 0.36
var shadow_color := Color(0.20, 0.10, 0.035, 1.0)
var shadow_angle := -38.0
var offset_distance := 0.12
var size_multiplier := 1.0

var _parts: Array[MeshInstance3D] = []
var _materials: Array[ShaderMaterial] = []
var _alpha_scales: Array[float] = []

func _ready() -> void:
	top_level = true
	add_to_group("projected_player_shadows")
	_build_shadow()
	apply_settings({
		"enabled": enabled,
		"opacity": opacity,
		"color": shadow_color,
		"angle": shadow_angle,
		"offset_distance": offset_distance,
		"size": size_multiplier
	})

func apply_settings(settings: Dictionary) -> void:
	enabled = bool(settings.get("enabled", enabled))
	opacity = float(settings.get("opacity", opacity))
	var color_value: Variant = settings.get("color", shadow_color)
	if color_value is Color:
		shadow_color = color_value
	shadow_angle = float(settings.get("angle", shadow_angle))
	offset_distance = float(settings.get("offset_distance", offset_distance))
	size_multiplier = float(settings.get("size", size_multiplier))
	visible = enabled
	for material in _materials:
		var index := _materials.find(material)
		var alpha_scale := 1.0
		if index >= 0 and index < _alpha_scales.size():
			alpha_scale = _alpha_scales[index]
		material.set_shader_parameter("shadow_color", shadow_color)
		material.set_shader_parameter("opacity", opacity * alpha_scale)
	scale = Vector3.ONE * size_multiplier

func update_shadow(world_position: Vector3, facing_yaw_degrees: float) -> void:
	var yaw_radians := deg_to_rad(shadow_angle)
	var offset := Vector3(cos(yaw_radians), 0.0, sin(yaw_radians)) * offset_distance
	global_position = Vector3(world_position.x + offset.x, GameConfig.COURT_EFFECT_Y + 0.002, world_position.z + offset.z)
	global_rotation_degrees = Vector3(0.0, facing_yaw_degrees + shadow_angle * 0.22, 0.0)

func _build_shadow() -> void:
	_add_ellipse("TorsoShadow", Vector3(0.00, 0.0, 0.10), Vector2(0.50, 0.86), 0.00, 1.0)
	_add_ellipse("HeadShadow", Vector3(-0.02, 0.0, 0.58), Vector2(0.34, 0.30), 0.00, 0.72)
	_add_ellipse("LeftLegShadow", Vector3(-0.20, 0.0, -0.48), Vector2(0.22, 0.76), -10.0, 0.82)
	_add_ellipse("RightLegShadow", Vector3(0.22, 0.0, -0.44), Vector2(0.22, 0.80), 12.0, 0.82)
	_add_ellipse("LeftArmShadow", Vector3(-0.42, 0.0, 0.08), Vector2(0.16, 0.62), -32.0, 0.64)
	_add_ellipse("RightArmShadow", Vector3(0.46, 0.0, 0.02), Vector2(0.16, 0.68), 34.0, 0.64)
	_add_ellipse("RacketShadow", Vector3(0.76, 0.0, 0.08), Vector2(0.28, 0.36), 34.0, 0.45)

func _add_ellipse(part_name: String, local_position: Vector3, part_size: Vector2, yaw_degrees: float, alpha_scale: float) -> void:
	var part := MeshInstance3D.new()
	part.name = part_name
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	part.mesh = quad
	part.position = local_position
	part.rotation_degrees = Vector3(-90.0, yaw_degrees, 0.0)
	part.scale = Vector3(part_size.x, part_size.y, 1.0)
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = load("res://materials/fx/ProjectedPlayerShadow.gdshader")
	material.set_shader_parameter("shadow_color", shadow_color)
	material.set_shader_parameter("opacity", opacity * alpha_scale)
	material.set_shader_parameter("softness", 0.24)
	part.material_override = material
	add_child(part)
	_parts.append(part)
	_materials.append(material)
	_alpha_scales.append(alpha_scale)
