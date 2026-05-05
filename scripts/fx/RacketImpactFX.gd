class_name RacketImpactFX
extends Node3D

var duration := 0.15
var opacity := 0.90
var fx_scale := 1.0
var fx_color := Color(0.10, 0.105, 0.11, 1.0)
var billboard_enabled := true
var started_at := 0.0
var impact_direction := Vector3.FORWARD
var _mesh_instance := MeshInstance3D.new()
var _flash_instance := MeshInstance3D.new()
var _mesh := ImmediateMesh.new()
var _flash_mesh := ImmediateMesh.new()
var _material := StandardMaterial3D.new()
var _flash_material := StandardMaterial3D.new()

func _ready() -> void:
	_mesh_instance.mesh = _mesh
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.no_depth_test = true
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh_instance.material_override = _material
	add_child(_mesh_instance)
	_flash_instance.mesh = _flash_mesh
	_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_material.no_depth_test = true
	_flash_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_flash_instance.material_override = _flash_material
	add_child(_flash_instance)
	started_at = Time.get_ticks_msec() / 1000.0

func setup(hit_direction: Vector3, settings: Dictionary) -> void:
	impact_direction = hit_direction.normalized()
	duration = float(settings.get("duration", duration))
	opacity = float(settings.get("opacity", opacity))
	fx_scale = float(settings.get("scale", fx_scale))
	var color_value: Variant = settings.get("color", fx_color)
	if color_value is Color:
		fx_color = color_value
	billboard_enabled = bool(settings.get("billboard_enabled", billboard_enabled))
	_draw_impact_mesh()
	_apply_directional_orientation()

func _process(_delta: float) -> void:
	var age: float = Time.get_ticks_msec() / 1000.0 - started_at
	var t: float = clamp(age / max(duration, 0.01), 0.0, 1.0)
	scale = Vector3.ONE * lerp(0.75, 1.55, t) * fx_scale
	_material.albedo_color = Color(fx_color.r, fx_color.g, fx_color.b, opacity * (1.0 - t))
	_flash_material.albedo_color = Color(1.0, 0.94, 0.66, opacity * 0.72 * (1.0 - t))
	if billboard_enabled and get_viewport().get_camera_3d() != null:
		look_at(get_viewport().get_camera_3d().global_position, Vector3.UP)
		_align_billboard_strokes()
	if age >= duration:
		queue_free()

func _apply_directional_orientation() -> void:
	if billboard_enabled:
		return
	if impact_direction.length() <= 0.01:
		return
	var up_axis := Vector3.UP
	if abs(impact_direction.dot(up_axis)) > 0.96:
		up_axis = Vector3.FORWARD
	look_at(global_position + impact_direction, up_axis)

func _align_billboard_strokes() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var camera_basis: Basis = camera.global_transform.basis
	var projected := Vector2(impact_direction.dot(camera_basis.x), -impact_direction.dot(camera_basis.y))
	if projected.length() <= 0.01:
		return
	var angle: float = projected.angle()
	_mesh_instance.rotation = Vector3(0.0, 0.0, angle)
	_flash_instance.rotation = Vector3(0.0, 0.0, angle)

func _draw_impact_mesh() -> void:
	_mesh.clear_surfaces()
	_flash_mesh.clear_surfaces()
	var base_angle: float = 0.0
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(14):
		var angle: float = base_angle + deg_to_rad(-105.0 + float(i) * 16.0 + randf_range(-7.0, 7.0))
		var line_length: float = randf_range(0.34, 0.82)
		var width: float = randf_range(0.030, 0.070)
		var inner: float = randf_range(0.055, 0.12)
		var dir: Vector3 = Vector3(cos(angle), sin(angle), 0.0).normalized()
		var side: Vector3 = Vector3(-dir.y, dir.x, 0.0) * width
		var a: Vector3 = dir * inner
		var b: Vector3 = dir * line_length
		_mesh.surface_add_vertex(a - side)
		_mesh.surface_add_vertex(a + side)
		_mesh.surface_add_vertex(b)
	_mesh.surface_end()
	_flash_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var radius: float = 0.16
	_flash_mesh.surface_add_vertex(Vector3(-radius, 0.0, 0.002))
	_flash_mesh.surface_add_vertex(Vector3(0.0, radius, 0.002))
	_flash_mesh.surface_add_vertex(Vector3(radius, 0.0, 0.002))
	_flash_mesh.surface_add_vertex(Vector3(-radius, 0.0, 0.002))
	_flash_mesh.surface_add_vertex(Vector3(radius, 0.0, 0.002))
	_flash_mesh.surface_add_vertex(Vector3(0.0, -radius, 0.002))
	_flash_mesh.surface_end()
