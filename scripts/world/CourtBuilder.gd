class_name CourtBuilder
extends Node3D

@export var line_material: StandardMaterial3D
@export var net_post_material: StandardMaterial3D
@export var net_band_material: StandardMaterial3D
@export var net_cord_material: StandardMaterial3D
@export var preset_name := CourtPreset.JP_ORANGE_ARCADE

func _ready() -> void:
	add_to_group("court")
	build()

func build() -> void:
	_build_lines()
	_build_net()

func _build_lines() -> void:
	var half_length := GameConfig.COURT_LENGTH * 0.5
	var half_width := GameConfig.COURT_WIDTH * 0.5
	var half_singles_width := GameConfig.SINGLES_WIDTH * 0.5
	_add_line(Vector3(0, 0.05, -half_width), Vector3(GameConfig.COURT_LENGTH, GameConfig.LINE_WIDTH, GameConfig.LINE_WIDTH))
	_add_line(Vector3(0, 0.05, half_width), Vector3(GameConfig.COURT_LENGTH, GameConfig.LINE_WIDTH, GameConfig.LINE_WIDTH))
	_add_line(Vector3(-half_length, 0.05, 0), Vector3(GameConfig.LINE_WIDTH, GameConfig.LINE_WIDTH, GameConfig.COURT_WIDTH))
	_add_line(Vector3(half_length, 0.05, 0), Vector3(GameConfig.LINE_WIDTH, GameConfig.LINE_WIDTH, GameConfig.COURT_WIDTH))
	_add_line(Vector3(0, 0.055, -half_singles_width), Vector3(GameConfig.COURT_LENGTH, GameConfig.LINE_WIDTH, GameConfig.LINE_WIDTH))
	_add_line(Vector3(0, 0.055, half_singles_width), Vector3(GameConfig.COURT_LENGTH, GameConfig.LINE_WIDTH, GameConfig.LINE_WIDTH))
	_add_line(Vector3(-GameConfig.SHORT_SERVICE_DISTANCE, 0.055, 0), Vector3(GameConfig.LINE_WIDTH, GameConfig.LINE_WIDTH, GameConfig.COURT_WIDTH))
	_add_line(Vector3(GameConfig.SHORT_SERVICE_DISTANCE, 0.055, 0), Vector3(GameConfig.LINE_WIDTH, GameConfig.LINE_WIDTH, GameConfig.COURT_WIDTH))
	_add_line(Vector3(-GameConfig.DOUBLES_LONG_SERVICE_DISTANCE, 0.055, 0), Vector3(GameConfig.LINE_WIDTH, GameConfig.LINE_WIDTH, GameConfig.COURT_WIDTH))
	_add_line(Vector3(GameConfig.DOUBLES_LONG_SERVICE_DISTANCE, 0.055, 0), Vector3(GameConfig.LINE_WIDTH, GameConfig.LINE_WIDTH, GameConfig.COURT_WIDTH))
	var service_center := (GameConfig.SHORT_SERVICE_DISTANCE + half_length) * 0.5
	var service_length := half_length - GameConfig.SHORT_SERVICE_DISTANCE
	_add_line(Vector3(-service_center, 0.06, 0), Vector3(service_length, GameConfig.LINE_WIDTH, GameConfig.LINE_WIDTH))
	_add_line(Vector3(service_center, 0.06, 0), Vector3(service_length, GameConfig.LINE_WIDTH, GameConfig.LINE_WIDTH))

func _build_net() -> void:
	var band_height := 0.07
	var mesh_top := GameConfig.NET_CENTER_HEIGHT - band_height
	var mesh_height := mesh_top - GameConfig.NET_BOTTOM_HEIGHT
	var mesh_center_y := GameConfig.NET_BOTTOM_HEIGHT + mesh_height * 0.5
	var half_width := GameConfig.COURT_WIDTH * 0.5
	var preset := CourtPreset.court(preset_name)
	var post_mat := _mat(net_post_material, preset["net_post"])
	var band_mat := _mat(net_band_material, preset["net_band"])
	var cord_mat := _mat(net_cord_material, preset["net_cord"])
	for z in [-half_width - 0.13, half_width + 0.13]:
		_add_box("NetPost", Vector3(0, GameConfig.NET_HEIGHT * 0.5, z), Vector3(0.08, GameConfig.NET_HEIGHT, 0.08), post_mat)
		_add_box("NetPostBase", Vector3(0, 0.045, z), Vector3(0.34, 0.09, 0.26), post_mat)
	_add_box("NetBand", Vector3(0, GameConfig.NET_CENTER_HEIGHT - band_height * 0.5, 0), Vector3(0.045, band_height, GameConfig.COURT_WIDTH + 0.35), band_mat)
	_add_box("NetBottomCord", Vector3(0, GameConfig.NET_BOTTOM_HEIGHT, 0), Vector3(0.018, 0.014, GameConfig.COURT_WIDTH + 0.22), cord_mat)
	for i in range(10):
		var z := -half_width + (GameConfig.COURT_WIDTH / 9.0) * i
		_add_box("NetVerticalCord%d" % i, Vector3(0, mesh_center_y, z), Vector3(0.018, mesh_height, 0.012), cord_mat)
	for i in range(4):
		var y := GameConfig.NET_BOTTOM_HEIGHT + (mesh_height / 3.0) * i
		_add_box("NetHorizontalCord%d" % i, Vector3(0, y, 0), Vector3(0.018, 0.012, GameConfig.COURT_WIDTH), cord_mat)

func _add_line(pos: Vector3, size: Vector3) -> void:
	var preset := CourtPreset.court(preset_name)
	var painted_pos := Vector3(pos.x, GameConfig.COURT_LINE_CENTER_Y, pos.z)
	var painted_size := Vector3(size.x, GameConfig.COURT_LINE_VISUAL_HEIGHT, size.z)
	var line := _add_box("CourtLine", painted_pos, painted_size, _mat(line_material, preset["line"]))
	line.visible = false
	line.add_to_group("court_lines")

func _add_box(node_name: String, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.name = node_name
	node.mesh = mesh
	node.position = pos
	node.layers = 1
	node.material_override = mat
	if node_name.begins_with("Net"):
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
		node.add_to_group("interior_shadow_props")
	else:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_to_group("court")
	add_child(node)
	return node

func _mat(source: StandardMaterial3D, color: Color) -> Material:
	if source != null:
		var copy := source.duplicate() as StandardMaterial3D
		copy.disable_receive_shadows = false
		return copy
	var mat := GameConfig.material(color)
	mat.disable_receive_shadows = false
	return mat
