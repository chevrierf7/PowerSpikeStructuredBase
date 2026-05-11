class_name Shuttle
extends MeshInstance3D

signal landed(predicted_position: Vector3)
signal net_fault

var velocity := Vector3.ZERO
var in_flight := false
var target := Vector3.ZERO
var guidance_target := Vector3.ZERO
var flight_started_at := 0.0
var flight_duration := 1.0
var drag := 0.972
var gravity := 8.6
var guidance := 0.18
var ground_bounce_active := false
var ground_bounce_count := 0
var ground_bounce_energy := 0.34
var ground_bounce_horizontal_damping := 0.58
var ground_bounce_min_vertical_speed := 0.55
var ground_bounce_max_count := 3
var net_reaction_active := false
var net_reaction_horizontal_damping := 0.22
var net_reaction_drop_speed := 0.85
var net_reaction_tumble_speed := 11.0
var shuttle_model: Node3D = null
var last_position := Vector3.ZERO
var net_fault_checked := false
var force_net_fault := false
var speed_lines: ShuttleSpeedLines = null
var impact_marker: MeshInstance3D = null
var impact_started_at := -10.0
var impact_enabled := true
var impact_delay := 0.0
var impact_duration := 0.18
var impact_size_start := 0.38
var impact_size_end := 1.38
var impact_color := Color(1.0, 0.82, 0.18, 0.52)
var default_model_rotation_degrees := Vector3(90.0, 0.0, 0.0)
var service_hold_rotation_degrees := Vector3.ZERO
const IMPORTED_MODEL_SCALE := 1.6875
const FALLBACK_RADIUS := 0.0675
const FALLBACK_HEIGHT := 0.135
const GROUND_VISUAL_CLEARANCE := 0.045

func apply_shot_visual_settings(settings: Dictionary) -> void:
	if speed_lines != null:
		speed_lines.apply_settings(settings.get("speed_lines", {}))

func boost_trail(duration: float, intensity: float) -> void:
	if speed_lines != null and speed_lines.has_method("boost"):
		speed_lines.call("boost", duration, intensity)

func set_service_hold_rotation(rotation_degrees_value: Vector3) -> void:
	service_hold_rotation_degrees = rotation_degrees_value
	_apply_visual_rotation(default_model_rotation_degrees + service_hold_rotation_degrees)

func set_service_hold_position(hold_position: Vector3) -> void:
	position = hold_position
	rotation_degrees = Vector3.ZERO
	velocity = Vector3.ZERO
	in_flight = false
	ground_bounce_active = false
	ground_bounce_count = 0
	net_reaction_active = false
	if speed_lines != null:
		speed_lines.clear_lines()
	_apply_visual_rotation(default_model_rotation_degrees + service_hold_rotation_degrees)
	_update_visual_helpers()

func apply_impact_circle_settings(settings: Dictionary) -> void:
	impact_enabled = bool(settings.get("enabled", impact_enabled))
	impact_delay = float(settings.get("delay", impact_delay))
	impact_duration = float(settings.get("duration", impact_duration))
	impact_size_start = float(settings.get("size_start", impact_size_start))
	impact_size_end = float(settings.get("size_end", impact_size_end))
	var color_value: Variant = settings.get("color", impact_color)
	if color_value is Color:
		impact_color = color_value
	if impact_marker != null:
		impact_marker.material_override = GameConfig.material(impact_color)

func _ready() -> void:
	add_to_group("shuttle")
	_add_visual_helpers()
	if ResourceLoader.exists(GameConfig.SHUTTLE_SCENE):
		var scene := load(GameConfig.SHUTTLE_SCENE)
		if scene is PackedScene:
			shuttle_model = (scene as PackedScene).instantiate() as Node3D
			shuttle_model.name = "ShuttleModel"
			shuttle_model.scale = Vector3.ONE * IMPORTED_MODEL_SCALE
			_apply_visual_rotation(default_model_rotation_degrees + service_hold_rotation_degrees)
			add_child(shuttle_model)
			return
	_add_fallback_mesh()

func launch(to_target: Vector3, duration: float, apex: float, profile: Dictionary) -> Vector3:
	drag = float(profile["drag"])
	gravity = float(profile["gravity"])
	guidance = float(profile["guidance"])
	force_net_fault = bool(profile.get("net_fault", false))
	var start: Vector3 = position
	var launch_velocity: Vector3 = _calculate_launch_velocity(start, to_target, duration, drag, gravity)
	launch_velocity.y = _ensure_net_clearance(start, to_target, duration, launch_velocity.y, gravity, apex)
	var predicted: Vector3 = _predict_landing(start, launch_velocity, to_target, duration, drag, gravity, guidance)
	velocity = launch_velocity
	target = predicted
	guidance_target = to_target
	flight_duration = duration
	flight_started_at = Time.get_ticks_msec() / 1000.0
	last_position = position
	net_fault_checked = sign(position.x) == sign(to_target.x)
	in_flight = true
	ground_bounce_active = false
	ground_bounce_count = 0
	net_reaction_active = false
	impact_started_at = Time.get_ticks_msec() / 1000.0
	_update_visual_helpers()
	_orient_to_velocity()
	return predicted

func update_flight(delta: float) -> void:
	if ground_bounce_active:
		_update_ground_bounce(delta)
		return
	if net_reaction_active:
		_update_net_reaction(delta)
		return
	if not in_flight:
		return
	var drag_frame: float = pow(drag, delta * 60.0)
	velocity.x *= drag_frame
	velocity.z *= drag_frame
	velocity.y *= drag_frame * pow(0.985, delta * 60.0)
	velocity.y -= gravity * delta
	_apply_guidance(delta)
	last_position = position
	position += velocity * delta
	_update_visual_helpers()
	_check_net_fault()
	if velocity.length() < 0.4:
		velocity *= 0.92
	_orient_to_velocity()
	if position.y <= _ground_contact_y():
		position.y = _ground_contact_y()
		in_flight = false
		_start_ground_bounce()
		_update_visual_helpers()
		landed.emit(target)

func _check_net_fault() -> void:
	if net_fault_checked:
		return
	if sign(last_position.x) == sign(position.x):
		return
	var crossing_ratio: float = abs(last_position.x) / max(abs(position.x - last_position.x), 0.001)
	var crossing_y: float = lerp(last_position.y, position.y, crossing_ratio)
	net_fault_checked = true
	if crossing_y <= GameConfig.NET_CENTER_HEIGHT + 0.05:
		in_flight = false
		ground_bounce_active = false
		ground_bounce_count = 0
		position.x = 0.0
		position.y = crossing_y
		_start_net_reaction()
		if speed_lines != null:
			speed_lines.clear_lines()
		net_fault.emit()

func _start_net_reaction() -> void:
	velocity.x = -velocity.x * net_reaction_horizontal_damping
	velocity.z *= net_reaction_horizontal_damping
	velocity.y = min(velocity.y, -net_reaction_drop_speed)
	net_reaction_active = true

func _update_net_reaction(delta: float) -> void:
	var drag_frame: float = pow(drag, delta * 60.0)
	velocity.x *= drag_frame * 0.92
	velocity.z *= drag_frame * 0.92
	velocity.y -= gravity * delta
	position += velocity * delta
	rotate_object_local(Vector3.RIGHT, net_reaction_tumble_speed * delta)
	if position.y <= _ground_contact_y():
		position.y = _ground_contact_y()
		net_reaction_active = false
		_start_ground_bounce()
	_update_visual_helpers()

func _start_ground_bounce() -> void:
	var impact_vertical_speed: float = abs(velocity.y)
	velocity.y = impact_vertical_speed * ground_bounce_energy
	velocity.x *= ground_bounce_horizontal_damping
	velocity.z *= ground_bounce_horizontal_damping
	ground_bounce_count = 1
	ground_bounce_active = velocity.y >= ground_bounce_min_vertical_speed
	if not ground_bounce_active:
		velocity = Vector3.ZERO

func _update_ground_bounce(delta: float) -> void:
	var drag_frame: float = pow(drag, delta * 60.0)
	velocity.x *= drag_frame * 0.985
	velocity.z *= drag_frame * 0.985
	velocity.y -= gravity * delta
	position += velocity * delta
	if position.y <= _ground_contact_y():
		position.y = _ground_contact_y()
		if ground_bounce_count >= ground_bounce_max_count or abs(velocity.y) < ground_bounce_min_vertical_speed:
			ground_bounce_active = false
			ground_bounce_count = 0
			velocity = Vector3.ZERO
		else:
			velocity.y = abs(velocity.y) * ground_bounce_energy
			velocity.x *= ground_bounce_horizontal_damping
			velocity.z *= ground_bounce_horizontal_damping
			ground_bounce_count += 1
	_update_visual_helpers()
	if ground_bounce_active:
		_orient_to_velocity()

func _add_fallback_mesh() -> void:
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = FALLBACK_RADIUS
	sphere.height = FALLBACK_HEIGHT
	mesh = sphere
	material_override = AnimeVisuals.toon_material(Color(1.0, 0.98, 0.82))

func _add_visual_helpers() -> void:
	speed_lines = ShuttleSpeedLines.new()
	speed_lines.name = "ShuttleSpeedLines"
	add_child(speed_lines)

	impact_marker = MeshInstance3D.new()
	impact_marker.name = "ShuttleImpactFlash"
	impact_marker.top_level = true
	var impact_mesh := CylinderMesh.new()
	impact_mesh.top_radius = 0.46
	impact_mesh.bottom_radius = 0.46
	impact_mesh.height = 0.014
	impact_marker.mesh = impact_mesh
	impact_marker.material_override = GameConfig.material(impact_color)
	impact_marker.visible = false
	add_child(impact_marker)

func _update_visual_helpers() -> void:
	if impact_marker != null:
		var impact_age: float = Time.get_ticks_msec() / 1000.0 - impact_started_at
		var visible_age: float = impact_age - impact_delay
		impact_marker.visible = impact_enabled and visible_age >= 0.0 and visible_age <= impact_duration
		if impact_marker.visible:
			impact_marker.global_position = Vector3(global_position.x, GameConfig.COURT_MARKER_Y, global_position.z)
			var impact_t: float = clampf(visible_age / max(impact_duration, 0.01), 0.0, 1.0)
			var impact_size: float = lerp(impact_size_start, impact_size_end, impact_t)
			impact_marker.scale = Vector3(impact_size, 1.0, impact_size)
	if speed_lines != null and in_flight:
		speed_lines.update_speed_lines(global_position, velocity)
	elif speed_lines != null:
		speed_lines.clear_lines()

func _orient_to_velocity() -> void:
	if velocity.length() <= 0.05:
		return
	_apply_visual_rotation(default_model_rotation_degrees)
	var direction: Vector3 = velocity.normalized()
	var up_axis := Vector3.UP
	if abs(direction.dot(up_axis)) > 0.96:
		up_axis = Vector3.FORWARD
	look_at(position + direction, up_axis)

func _apply_visual_rotation(rotation_degrees_value: Vector3) -> void:
	if shuttle_model != null:
		shuttle_model.rotation_degrees = rotation_degrees_value
	else:
		rotation_degrees = rotation_degrees_value

func flight_phase() -> float:
	return clampf((Time.get_ticks_msec() / 1000.0 - flight_started_at) / max(flight_duration, 0.001), 0.0, 1.0)

func _apply_guidance(delta: float) -> void:
	var remaining: float = max(flight_duration - (Time.get_ticks_msec() / 1000.0 - flight_started_at), 0.08)
	var desired_velocity: Vector3 = (guidance_target - position) / remaining
	var blend: float = clampf(guidance * delta, 0.0, 0.08)
	velocity.x = lerp(velocity.x, desired_velocity.x, blend)
	velocity.z = lerp(velocity.z, desired_velocity.z, blend)
	if position.y < GameConfig.NET_CENTER_HEIGHT + 0.5 and sign(position.x) != sign(guidance_target.x):
		velocity.y = max(velocity.y, desired_velocity.y * 0.35)

func _calculate_launch_velocity(start: Vector3, to_target: Vector3, duration: float, shot_drag: float, shot_gravity: float) -> Vector3:
	var steps: int = max(12, int(ceil(duration * 60.0)))
	var dt: float = duration / float(steps)
	var zero_end: Vector3 = _simulate_end(start, Vector3.ZERO, shot_drag, shot_gravity, dt, steps)
	var x_end: Vector3 = _simulate_end(start, Vector3(1, 0, 0), shot_drag, shot_gravity, dt, steps)
	var y_end: Vector3 = _simulate_end(start, Vector3(0, 1, 0), shot_drag, shot_gravity, dt, steps)
	var z_end: Vector3 = _simulate_end(start, Vector3(0, 0, 1), shot_drag, shot_gravity, dt, steps)
	return Vector3(
		(to_target.x - zero_end.x) / _response_scale(x_end.x - zero_end.x),
		(to_target.y - zero_end.y) / _response_scale(y_end.y - zero_end.y),
		(to_target.z - zero_end.z) / _response_scale(z_end.z - zero_end.z)
	)

func _simulate_end(start: Vector3, start_velocity: Vector3, shot_drag: float, shot_gravity: float, dt: float, steps: int) -> Vector3:
	var pos: Vector3 = start
	var vel: Vector3 = start_velocity
	for i in range(steps):
		var drag_frame: float = pow(shot_drag, dt * 60.0)
		vel.x *= drag_frame
		vel.z *= drag_frame
		vel.y *= drag_frame * pow(0.985, dt * 60.0)
		vel.y -= shot_gravity * dt
		pos += vel * dt
	return pos

func _predict_landing(start: Vector3, start_velocity: Vector3, to_target: Vector3, duration: float, shot_drag: float, shot_gravity: float, shot_guidance: float) -> Vector3:
	var pos: Vector3 = start
	var vel: Vector3 = start_velocity
	var elapsed: float = 0.0
	var dt: float = 1.0 / 120.0
	while elapsed < 4.5:
		var drag_frame: float = pow(shot_drag, dt * 60.0)
		vel.x *= drag_frame
		vel.z *= drag_frame
		vel.y *= drag_frame * pow(0.985, dt * 60.0)
		vel.y -= shot_gravity * dt
		var remaining: float = max(duration - elapsed, 0.08)
		var desired_velocity: Vector3 = (to_target - pos) / remaining
		var blend: float = clampf(shot_guidance * dt, 0.0, 0.08)
		vel.x = lerp(vel.x, desired_velocity.x, blend)
		vel.z = lerp(vel.z, desired_velocity.z, blend)
		if pos.y < GameConfig.NET_CENTER_HEIGHT + 0.5 and sign(pos.x) != sign(to_target.x):
			vel.y = max(vel.y, desired_velocity.y * 0.35)
		pos += vel * dt
		elapsed += dt
		if pos.y <= _ground_contact_y() and elapsed > 0.08:
			return Vector3(pos.x, GameConfig.COURT_VISUAL_SURFACE_TOP_Y, pos.z)
	return Vector3(pos.x, GameConfig.COURT_VISUAL_SURFACE_TOP_Y, pos.z)

func _ensure_net_clearance(start: Vector3, to_target: Vector3, duration: float, vertical_velocity: float, shot_gravity: float, apex: float) -> float:
	if sign(start.x) == sign(to_target.x):
		return vertical_velocity
	if force_net_fault:
		return vertical_velocity - 1.8
	var horizontal_total: float = abs(to_target.x - start.x)
	if horizontal_total <= 0.01:
		return vertical_velocity
	var t_at_net: float = clampf(abs(start.x) / horizontal_total, 0.0, 1.0) * duration
	var min_height: float = _net_clearance() + max(apex - GameConfig.NET_CENTER_HEIGHT, 0.0) * 0.1
	var corrected_velocity: float = vertical_velocity
	for i in range(4):
		var current_height: float = _simulate_vertical_at_time(start.y, corrected_velocity, shot_gravity, t_at_net)
		if current_height >= min_height:
			return corrected_velocity
		corrected_velocity += (min_height - current_height) / max(t_at_net, 0.05)
	return corrected_velocity

func _simulate_vertical_at_time(start_y: float, vertical_velocity: float, shot_gravity: float, target_time: float) -> float:
	var pos_y: float = start_y
	var vel_y: float = vertical_velocity
	var elapsed: float = 0.0
	var dt: float = 1.0 / 120.0
	while elapsed < target_time:
		var step: float = min(dt, target_time - elapsed)
		var drag_frame: float = pow(drag, step * 60.0)
		vel_y *= drag_frame * pow(0.985, step * 60.0)
		vel_y -= shot_gravity * step
		pos_y += vel_y * step
		elapsed += step
	return pos_y

func _net_clearance() -> float:
	return GameConfig.NET_CENTER_HEIGHT + 0.28

func _ground_contact_y() -> float:
	return GameConfig.COURT_VISUAL_SURFACE_TOP_Y + GROUND_VISUAL_CLEARANCE

func _response_scale(value: float) -> float:
	if abs(value) >= 0.001:
		return value
	return 0.001 if value >= 0.0 else -0.001
