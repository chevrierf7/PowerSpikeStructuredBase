class_name ShuttleSpeedLines
extends MeshInstance3D

var speed_lines_enabled := true
var opacity := 0.65
var main_length := 0.80
var line_width := 0.025
var line_color := Color(1.0, 0.94, 0.55, 1.0)

var _mesh := ImmediateMesh.new()
var _material := StandardMaterial3D.new()
var _points: Array[Vector3] = []
var _last_position := Vector3.ZERO
var _has_last_position := false
var _boost_until := -10.0
var _boost_intensity := 0.0
const MAX_POINTS := 18
const MIN_VISIBLE_SPEED := 1.2
const MAX_REFERENCE_SPEED := 14.0

func _ready() -> void:
	top_level = true
	mesh = _mesh
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.no_depth_test = true
	_material.vertex_color_use_as_albedo = true
	_material.albedo_color = Color(line_color.r, line_color.g, line_color.b, opacity)
	material_override = _material
	add_to_group("shuttle_speed_lines")

func apply_settings(settings: Dictionary) -> void:
	speed_lines_enabled = bool(settings.get("enabled", speed_lines_enabled))
	opacity = float(settings.get("opacity", opacity))
	main_length = float(settings.get("main_length", main_length))
	line_width = float(settings.get("width", line_width))
	var color_value: Variant = settings.get("color", line_color)
	if color_value is Color:
		line_color = color_value
	_material.albedo_color = Color(line_color.r, line_color.g, line_color.b, opacity)
	visible = speed_lines_enabled

func boost(duration: float, intensity: float) -> void:
	_boost_until = Time.get_ticks_msec() / 1000.0 + max(duration, 0.0)
	_boost_intensity = max(_boost_intensity, clamp(intensity, 0.0, 2.0))

func clear_lines() -> void:
	_mesh.clear_surfaces()
	_points.clear()
	_has_last_position = false
	visible = false

func update_speed_lines(world_position: Vector3, velocity: Vector3) -> void:
	_mesh.clear_surfaces()
	var speed: float = velocity.length()
	visible = speed_lines_enabled and speed > MIN_VISIBLE_SPEED
	if not visible:
		clear_lines()
		return
	if not _has_last_position or world_position.distance_to(_last_position) > 2.4:
		_points.clear()
	_points.push_front(world_position)
	while _points.size() > MAX_POINTS:
		_points.pop_back()
	_last_position = world_position
	_has_last_position = true
	if _points.size() < 2:
		return
	global_transform = Transform3D.IDENTITY
	var speed_factor: float = clamp((speed - MIN_VISIBLE_SPEED) / (MAX_REFERENCE_SPEED - MIN_VISIBLE_SPEED), 0.0, 1.0)
	var boost_factor: float = _active_boost_factor()
	var length_scale: float = lerp(0.55, 1.55, speed_factor) * (1.0 + boost_factor * 0.34)
	var width_scale: float = lerp(0.70, 1.25, speed_factor) * (1.0 + boost_factor * 0.18)
	var opacity_scale: float = min(1.35, lerp(0.45, 1.0, speed_factor) * (1.0 + boost_factor * 0.30))
	var direction: Vector3 = velocity.normalized()
	if _points.size() >= 2:
		_points[0] = world_position - direction * 0.08
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_curved_line(main_length * length_scale, line_width * width_scale, 0.0, opacity_scale)
	_mesh.surface_end()

func _add_curved_line(target_length: float, width: float, offset: float, alpha_scale: float) -> void:
	var accumulated := 0.0
	for i in range(_points.size() - 1):
		var start: Vector3 = _points[i]
		var next: Vector3 = _points[i + 1]
		var segment_length: float = start.distance_to(next)
		if segment_length <= 0.001:
			continue
		var remaining: float = target_length - accumulated
		if remaining <= 0.0:
			break
		var end: Vector3 = next
		if segment_length > remaining:
			end = start.lerp(next, remaining / segment_length)
			segment_length = remaining
		var t0: float = clamp(accumulated / max(target_length, 0.001), 0.0, 1.0)
		var t1: float = clamp((accumulated + segment_length) / max(target_length, 0.001), 0.0, 1.0)
		_add_segment(start, end, width, offset, alpha_scale, t0, t1)
		accumulated += segment_length

func _active_boost_factor() -> float:
	var now: float = Time.get_ticks_msec() / 1000.0
	if now > _boost_until:
		_boost_intensity = 0.0
		return 0.0
	return clamp(_boost_intensity, 0.0, 2.0)

func _add_segment(start: Vector3, end: Vector3, width: float, offset: float, alpha_scale: float, t0: float, t1: float) -> void:
	var direction: Vector3 = (start - end).normalized()
	var side: Vector3 = direction.cross(Vector3.UP)
	if side.length() < 0.05:
		side = Vector3.RIGHT
	side = side.normalized()
	var start_width: Vector3 = side * width * lerp(1.0, 0.35, t0)
	var end_width: Vector3 = side * width * lerp(1.0, 0.35, t1)
	var start_center: Vector3 = start + side * offset
	var end_center: Vector3 = end + side * offset
	var color_start: Color = Color(line_color.r, line_color.g, line_color.b, opacity * alpha_scale * (1.0 - t0))
	var color_end: Color = Color(line_color.r, line_color.g, line_color.b, opacity * alpha_scale * (1.0 - t1))
	_mesh.surface_set_color(color_start)
	_mesh.surface_add_vertex(start_center - start_width)
	_mesh.surface_add_vertex(start_center + start_width)
	_mesh.surface_set_color(color_end)
	_mesh.surface_add_vertex(end_center + end_width)
	_mesh.surface_set_color(color_start)
	_mesh.surface_add_vertex(start_center - start_width)
	_mesh.surface_set_color(color_end)
	_mesh.surface_add_vertex(end_center + end_width)
	_mesh.surface_add_vertex(end_center - end_width)
