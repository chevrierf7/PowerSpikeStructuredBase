class_name CeilingLightMap
extends Control

signal light_moved(index: int, world_x: float, world_z: float)
signal light_selected(index: int)

const GYM_LENGTH := 22.0
const GYM_WIDTH := 15.2
const COURT_LENGTH := 13.40
const COURT_WIDTH := 6.10

var light_points: Array[Vector2] = [
	Vector2(-2.2, -3.05),
	Vector2(2.2, 3.05),
	Vector2(-2.2, 3.05),
	Vector2(2.2, -3.05)
]
var light_enabled: Array[bool] = [true, true, false, false]
var selected_index := 0
var dragging_index := -1

func _ready() -> void:
	custom_minimum_size = Vector2(430.0, 330.0)
	mouse_filter = Control.MOUSE_FILTER_STOP

func set_light(index: int, world_x: float, world_z: float, enabled: bool) -> void:
	if index < 0 or index >= light_points.size():
		return
	light_points[index] = Vector2(world_x, world_z)
	light_enabled[index] = enabled
	queue_redraw()

func set_selected(index: int) -> void:
	selected_index = clamp(index, 0, light_points.size() - 1)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			if mouse.pressed:
				dragging_index = _nearest_light(mouse.position)
				if dragging_index >= 0:
					selected_index = dragging_index
					light_selected.emit(selected_index)
					_move_selected_to(mouse.position)
			else:
				dragging_index = -1
	elif event is InputEventMouseMotion and dragging_index >= 0:
		var motion := event as InputEventMouseMotion
		_move_selected_to(motion.position)

func _move_selected_to(local_position: Vector2) -> void:
	var world: Vector2 = _screen_to_world(local_position)
	world.x = clamp(world.x, -GYM_LENGTH * 0.5, GYM_LENGTH * 0.5)
	world.y = clamp(world.y, -GYM_WIDTH * 0.5, GYM_WIDTH * 0.5)
	light_points[dragging_index] = world
	light_moved.emit(dragging_index, world.x, world.y)
	queue_redraw()

func _nearest_light(local_position: Vector2) -> int:
	var best_index: int = -1
	var best_distance: float = 99999.0
	for i in range(light_points.size()):
		var point: Vector2 = _world_to_screen(light_points[i])
		var distance: float = point.distance_to(local_position)
		if distance < best_distance and distance <= 26.0:
			best_index = i
			best_distance = distance
	return best_index

func _draw() -> void:
	var map_rect: Rect2 = _map_rect()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.055, 0.058, 0.064, 0.96), true)
	draw_rect(map_rect, Color(0.90, 0.88, 0.82, 1.0), true)
	for i in range(12):
		var t: float = float(i) / 11.0
		var x: float = lerp(map_rect.position.x, map_rect.end.x, t)
		draw_line(Vector2(x, map_rect.position.y), Vector2(x, map_rect.end.y), Color(0.18, 0.21, 0.23, 0.18), 1.0)
	for i in range(8):
		var t: float = float(i) / 7.0
		var y: float = lerp(map_rect.position.y, map_rect.end.y, t)
		draw_line(Vector2(map_rect.position.x, y), Vector2(map_rect.end.x, y), Color(0.18, 0.21, 0.23, 0.18), 1.0)
	draw_rect(map_rect, Color(0.0, 0.55, 0.82, 1.0), false, 3.0)
	_draw_court(map_rect)
	for i in range(light_points.size()):
		_draw_light(i)

func _draw_court(_map_rect: Rect2) -> void:
	var a: Vector2 = _world_to_screen(Vector2(-COURT_LENGTH * 0.5, -COURT_WIDTH * 0.5))
	var b: Vector2 = _world_to_screen(Vector2(COURT_LENGTH * 0.5, COURT_WIDTH * 0.5))
	var court_rect: Rect2 = Rect2(a, b - a).abs()
	draw_rect(court_rect, Color(1.0, 0.46, 0.10, 0.20), true)
	draw_rect(court_rect, Color(1.0, 0.46, 0.10, 1.0), false, 3.0)
	var net_x: float = _world_to_screen(Vector2(0.0, 0.0)).x
	draw_line(Vector2(net_x, court_rect.position.y), Vector2(net_x, court_rect.end.y), Color(1.0, 0.46, 0.10, 1.0), 3.0)
	for x in [-4.72, -1.98, 1.98, 4.72]:
		var sx: float = _world_to_screen(Vector2(float(x), 0.0)).x
		draw_line(Vector2(sx, court_rect.position.y), Vector2(sx, court_rect.end.y), Color(1.0, 0.46, 0.10, 0.9), 2.0)
	for z in [-COURT_WIDTH * 0.5, -2.59, 0.0, 2.59, COURT_WIDTH * 0.5]:
		var sy: float = _world_to_screen(Vector2(0.0, float(z))).y
		draw_line(Vector2(court_rect.position.x, sy), Vector2(court_rect.end.x, sy), Color(1.0, 0.46, 0.10, 0.9), 2.0)

func _draw_light(index: int) -> void:
	var point: Vector2 = _world_to_screen(light_points[index])
	var color: Color = Color(1.0, 0.82, 0.22, 1.0) if light_enabled[index] else Color(0.45, 0.45, 0.45, 1.0)
	var radius: float = 11.0 if index == selected_index else 8.0
	draw_circle(point, radius + 4.0, Color(0.08, 0.07, 0.04, 0.45))
	draw_circle(point, radius, color)
	draw_arc(point, radius + 5.0, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.90) if index == selected_index else Color(0.20, 0.20, 0.20, 0.7), 2.0)
	draw_string(get_theme_default_font(), point + Vector2(14.0, -10.0), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15.0, Color(0.06, 0.06, 0.06, 1.0))

func _map_rect() -> Rect2:
	var margin: float = 18.0
	var available: Vector2 = size - Vector2(margin * 2.0, margin * 2.0)
	var scale: float = min(available.x / GYM_LENGTH, available.y / GYM_WIDTH)
	var rect_size: Vector2 = Vector2(GYM_LENGTH, GYM_WIDTH) * scale
	return Rect2((size - rect_size) * 0.5, rect_size)

func _world_to_screen(world: Vector2) -> Vector2:
	var rect: Rect2 = _map_rect()
	var x: float = rect.position.x + (world.x / GYM_LENGTH + 0.5) * rect.size.x
	var y: float = rect.position.y + (world.y / GYM_WIDTH + 0.5) * rect.size.y
	return Vector2(x, y)

func _screen_to_world(local_position: Vector2) -> Vector2:
	var rect: Rect2 = _map_rect()
	var x: float = ((local_position.x - rect.position.x) / rect.size.x - 0.5) * GYM_LENGTH
	var z: float = ((local_position.y - rect.position.y) / rect.size.y - 0.5) * GYM_WIDTH
	return Vector2(x, z)
