class_name GymBuilder
extends Node3D

@export var outer_floor_material: StandardMaterial3D
@export var wall_material: StandardMaterial3D
@export var upper_wall_material: StandardMaterial3D
@export var back_wall_texture_material: StandardMaterial3D
@export var left_wall_texture_material: StandardMaterial3D
@export var front_wall_texture_material: StandardMaterial3D
@export var right_side_wall_texture_material: StandardMaterial3D
@export var ceiling_material: StandardMaterial3D
@export var bench_material: StandardMaterial3D
@export var panel_material: StandardMaterial3D
@export var curtain_material: StandardMaterial3D
@export var preset_name := CourtPreset.JP_WOOD_CLASSIC

func _ready() -> void:
	add_to_group("gym")
	build()

func build() -> void:
	_build_environment_light()
	_build_room()
	_build_lighting()
	_build_benches()
	_build_decor_panels()

func _build_environment_light() -> void:
	var world := WorldEnvironment.new()
	world.name = "GymWorldEnvironment"
	world.add_to_group("render_environment")
	var env := load("res://materials/anime/WorldEnvironment_Anime.tres")
	if env is Environment:
		world.environment = env
	add_child(world)

func _build_room() -> void:
	var gym := CourtPreset.gym(preset_name)
	var floor_mat := _mat(outer_floor_material, gym["floor"])
	var ceiling_mat := _mat(ceiling_material, gym["ceiling"])
	var floor := _add_box("JPWoodFloor", Vector3(0, -0.055, 0), Vector3(22.0, 0.04, 15.2), floor_mat)
	floor.layers = 3
	for z in [-4.6, -1.6, 1.6, 4.6]:
		_add_box("FloorPlankLine", Vector3(0, -0.029, z), Vector3(22.0, 0.008, 0.025), CourtPreset.material(Color(0.50, 0.34, 0.20, 0.42)))
	for x in [-10.9, 10.9]:
		_add_box("ShortWallWood", Vector3(x, 0.85, 0), Vector3(0.18, 1.7, 15.2), _wall_mat(wall_material, gym["wood"]))
		_add_box("ShortWallUpper", Vector3(x, 3.45, 0), Vector3(0.18, 3.5, 15.2), _wall_mat(upper_wall_material, gym["wall"]))
	_add_back_wall_texture_panel()
	_add_left_wall_texture_panel()
	_add_front_wall_texture_panel()
	_add_right_side_wall_texture_panel()
	for z in [-7.5, 7.5]:
		_add_box("SideWallWood", Vector3(0, 0.85, z), Vector3(22.0, 1.7, 0.18), _wall_mat(wall_material, gym["wood"]))
		_add_box("SideWallUpper", Vector3(0, 3.45, z), Vector3(22.0, 3.5, 0.18), _wall_mat(upper_wall_material, gym["wall"]))
	_add_box("DarkCeiling", Vector3(0, 7.0, 0), Vector3(22.0, 0.16, 15.2), ceiling_mat)
	for x in [-8.0, -4.0, 0.0, 4.0, 8.0]:
		_add_box("CeilingBeamX", Vector3(x, 6.84, 0), Vector3(0.18, 0.28, 15.2), CourtPreset.material(Color(0.035, 0.04, 0.05)))
	for z in [-5.0, 0.0, 5.0]:
		_add_box("CeilingBeamZ", Vector3(0, 6.82, z), Vector3(22.0, 0.22, 0.16), CourtPreset.material(Color(0.035, 0.04, 0.05)))

func _add_back_wall_texture_panel() -> void:
	if back_wall_texture_material == null:
		return
	var panel := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(22.0, 7.00)
	panel.name = "BackWallTexturePanel"
	panel.mesh = mesh
	panel.position = Vector3(0.0, 3.50, 7.39)
	panel.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	panel.material_override = back_wall_texture_material.duplicate() as StandardMaterial3D
	panel.layers = 2
	panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	panel.add_to_group("gym")
	add_child(panel)

func _add_left_wall_texture_panel() -> void:
	if left_wall_texture_material == null:
		return
	var panel := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(14.75, 7.00)
	panel.name = "LeftWallTexturePanel"
	panel.mesh = mesh
	panel.position = Vector3(-10.70, 3.50, -0.12)
	panel.rotation_degrees = Vector3(90.0, 90.0, 0.0)
	panel.material_override = left_wall_texture_material.duplicate() as StandardMaterial3D
	panel.layers = 2
	panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	panel.add_to_group("gym")
	add_child(panel)

func _add_front_wall_texture_panel() -> void:
	if front_wall_texture_material == null:
		return
	var panel := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(22.0, 7.00)
	panel.name = "FrontWallTexturePanel"
	panel.mesh = mesh
	panel.position = Vector3(0.0, 3.50, -7.39)
	panel.rotation_degrees = Vector3(90.0, 180.0, 0.0)
	panel.material_override = front_wall_texture_material.duplicate() as StandardMaterial3D
	panel.layers = 2
	panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	panel.add_to_group("gym")
	add_child(panel)

func _add_right_side_wall_texture_panel() -> void:
	if right_side_wall_texture_material == null:
		return
	var panel := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(14.75, 7.00)
	panel.name = "RightWallTexturePanel"
	panel.mesh = mesh
	panel.position = Vector3(10.70, 3.50, -0.12)
	panel.rotation_degrees = Vector3(90.0, -90.0, 0.0)
	panel.material_override = right_side_wall_texture_material.duplicate() as StandardMaterial3D
	panel.layers = 2
	panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	panel.add_to_group("gym")
	add_child(panel)

func _build_lighting() -> void:
	var gym := CourtPreset.gym(preset_name)
	var key_light := DirectionalLight3D.new()
	key_light.name = "AnimeCourtKeyLight"
	key_light.add_to_group("main_light")
	key_light.rotation_degrees = Vector3(-82.0, -18.0, 0.0)
	key_light.light_energy = 0.26
	key_light.shadow_enabled = false
	key_light.light_bake_mode = Light3D.BAKE_DYNAMIC
	key_light.light_cull_mask = 1
	key_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	_set_light_property(key_light, "shadow_blur", 2.2)
	_set_light_property(key_light, "shadow_bias", 0.006)
	_set_light_property(key_light, "shadow_normal_bias", 0.28)
	_set_light_property(key_light, "shadow_opacity", 1.0)
	add_child(key_light)
	_add_ceiling_shadow_spot("CourtShadowKey1", Vector3(-2.2, 6.35, -3.05), Vector3(0.25, 0.08, -0.55), 8.2, 58.0, true)
	_add_ceiling_shadow_spot("CourtShadowKey2", Vector3(2.2, 6.35, 3.05), Vector3(-0.25, 0.08, 0.55), 5.4, 58.0, true)
	_add_ceiling_shadow_spot("CourtShadowKey3", Vector3(-2.2, 6.35, 3.05), Vector3(0.25, 0.08, 0.55), 0.0, 58.0, false)
	_add_ceiling_shadow_spot("CourtShadowKey4", Vector3(2.2, 6.35, -3.05), Vector3(-0.25, 0.08, -0.55), 0.0, 58.0, false)
	_add_wall_fill_light("NorthWallFill", Vector3(0.0, 3.2, -6.75), Vector3(0.0, 2.4, -1.6), 1.35)
	_add_wall_fill_light("SouthWallFill", Vector3(0.0, 3.2, 6.75), Vector3(0.0, 2.4, 1.6), 1.35)
	_add_wall_fill_light("WestWallFill", Vector3(-9.8, 3.2, 0.0), Vector3(-4.6, 2.4, 0.0), 1.10)
	_add_wall_fill_light("EastWallFill", Vector3(9.8, 3.2, 0.0), Vector3(4.6, 2.4, 0.0), 1.10)
	var gym_shadow_light := DirectionalLight3D.new()
	gym_shadow_light.name = "GymPropShadowLight"
	gym_shadow_light.add_to_group("gym_shadow_lights")
	gym_shadow_light.rotation_degrees = Vector3(-72.0, -34.0, 0.0)
	gym_shadow_light.light_energy = 0.34
	gym_shadow_light.light_color = Color(1.0, 0.88, 0.70)
	gym_shadow_light.light_cull_mask = 2
	gym_shadow_light.shadow_enabled = true
	gym_shadow_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	_set_light_property(gym_shadow_light, "shadow_blur", 2.2)
	_set_light_property(gym_shadow_light, "shadow_bias", 0.008)
	_set_light_property(gym_shadow_light, "shadow_normal_bias", 0.28)
	_set_light_property(gym_shadow_light, "shadow_opacity", 0.95)
	add_child(gym_shadow_light)
	var fill_light := DirectionalLight3D.new()
	fill_light.name = "AnimeFillLight"
	fill_light.add_to_group("fill_light")
	fill_light.rotation_degrees = Vector3(-38.0, 145.0, 0.0)
	fill_light.light_energy = 0.16
	fill_light.shadow_enabled = false
	fill_light.light_cull_mask = 1
	add_child(fill_light)
	for x in [-5.5, 0.0, 5.5]:
		for z in [-3.4, 3.4]:
			var light := OmniLight3D.new()
			light.name = "JPGymNeonLight"
			light.position = Vector3(x, 6.45, z)
			light.light_energy = float(gym["light"]) * 0.28
			light.omni_range = 8.0
			light.light_cull_mask = 2
			light.shadow_enabled = false
			add_child(light)
			_add_box("NeonPanel", Vector3(x, 6.72, z), Vector3(2.4, 0.045, 0.28), CourtPreset.material(Color(0.88, 0.92, 0.86, 0.92), 0.35))

func _add_ceiling_shadow_spot(light_name: String, origin: Vector3, target: Vector3, energy: float, angle: float, enabled: bool) -> void:
	var spot := SpotLight3D.new()
	spot.name = light_name
	spot.add_to_group("ceiling_shadow_lights")
	spot.position = origin
	spot.look_at(target, Vector3.UP)
	spot.light_energy = energy
	spot.light_color = Color(1.0, 0.90, 0.74)
	spot.light_bake_mode = Light3D.BAKE_DYNAMIC
	spot.light_cull_mask = 1
	spot.spot_range = 13.0
	spot.spot_angle = angle
	spot.spot_attenuation = 0.48
	spot.visible = enabled
	spot.shadow_enabled = enabled
	_set_light_property(spot, "shadow_blur", 1.8)
	_set_light_property(spot, "shadow_bias", 0.003)
	_set_light_property(spot, "shadow_normal_bias", 0.12)
	_set_light_property(spot, "shadow_opacity", 1.0)
	add_child(spot)

func _add_wall_fill_light(light_name: String, origin: Vector3, target: Vector3, energy: float) -> void:
	var light := OmniLight3D.new()
	light.name = light_name
	light.add_to_group("gym_fill_lights")
	light.position = origin
	light.light_energy = energy
	light.light_color = Color(1.0, 0.86, 0.66)
	light.light_bake_mode = Light3D.BAKE_DYNAMIC
	light.light_cull_mask = 2
	light.omni_range = origin.distance_to(target) + 5.0
	light.omni_attenuation = 0.42
	light.shadow_enabled = false
	add_child(light)

func _build_benches() -> void:
	for z in [-6.35, 6.35]:
		for x in [-3.8, 3.8]:
			_add_shadow_prop_box("BenchSeat", Vector3(x, 0.34, z), Vector3(2.2, 0.14, 0.42), _mat(bench_material, Color(0.28, 0.22, 0.16)))
			_add_shadow_prop_box("BenchLegA", Vector3(x - 0.75, 0.17, z), Vector3(0.12, 0.34, 0.12), _mat(bench_material, Color(0.12, 0.13, 0.14)))
			_add_shadow_prop_box("BenchLegB", Vector3(x + 0.75, 0.17, z), Vector3(0.12, 0.34, 0.12), _mat(bench_material, Color(0.12, 0.13, 0.14)))

func _build_decor_panels() -> void:
	for z in [-2.3, 0.0, 2.3]:
		_add_box("WallBanner", Vector3(-10.78, 3.35, z), Vector3(0.035, 1.1, 1.35), _mat(panel_material, Color(0.86, 0.82, 0.68)))
	_add_box("JPBannerMark", Vector3(-10.75, 3.35, 0.0), Vector3(0.04, 0.62, 0.62), CourtPreset.material(Color(0.66, 0.08, 0.08, 0.95)))
	_add_box("LowStage", Vector3(10.15, 0.18, 0.0), Vector3(1.2, 0.36, 3.2), CourtPreset.material(Color(0.30, 0.20, 0.12)))

func _add_box(node_name: String, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.name = node_name
	node.mesh = mesh
	node.position = pos
	node.layers = 2
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_to_group("gym")
	add_child(node)
	return node

func _add_shadow_prop_box(node_name: String, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var node := _add_box(node_name, pos, size, mat)
	node.layers = 3
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	node.add_to_group("interior_shadow_props")
	return node

func _mat(source: StandardMaterial3D, color: Color) -> Material:
	if source != null:
		return source.duplicate() as StandardMaterial3D
	return GameConfig.material(color)

func _wall_mat(source: StandardMaterial3D, color: Color) -> StandardMaterial3D:
	var mat: StandardMaterial3D
	if source != null:
		mat = source.duplicate() as StandardMaterial3D
	else:
		mat = GameConfig.material(color)
	mat.albedo_color = color
	mat.roughness = 0.92
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.06
	mat.disable_receive_shadows = false
	return mat

func _set_light_property(light: Light3D, property_name: String, value: Variant) -> void:
	for property in light.get_property_list():
		if String(property["name"]) == property_name:
			light.set(property_name, value)
			return
