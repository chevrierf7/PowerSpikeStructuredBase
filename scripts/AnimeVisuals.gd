class_name AnimeVisuals
extends RefCounted

const OUTLINE_MATERIAL := "res://materials/anime/AnimeOutlineMaterial.tres"

static func toon_material(color: Color, shade_strength: float = 0.28) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://materials/anime/AnimeToon.gdshader")
	mat.set_shader_parameter("albedo_color", color)
	mat.set_shader_parameter("shade_strength", shade_strength)
	return mat

static func toon_from_material(source: Material, shade_strength: float = 0.12) -> ShaderMaterial:
	var color := Color.WHITE
	var texture: Texture2D = null
	if source is BaseMaterial3D:
		var base := source as BaseMaterial3D
		color = base.albedo_color
		texture = base.albedo_texture
	var mat := toon_material(color, shade_strength)
	if texture != null:
		mat.set_shader_parameter("albedo_texture", texture)
		mat.set_shader_parameter("use_texture", true)
	return mat

static func outline_material(width: float = 0.007, color: Color = Color(0.10, 0.11, 0.12, 1.0)) -> ShaderMaterial:
	var mat := load(OUTLINE_MATERIAL) as ShaderMaterial
	var copy := mat.duplicate() as ShaderMaterial
	copy.set_shader_parameter("outline_width", width)
	copy.set_shader_parameter("outline_color", color)
	return copy

static func apply_outline(root: Node, width: float = 0.025) -> void:
	var outline := outline_material(width)
	_apply_outline_recursive(root, outline)

static func apply_character_toon(root: Node) -> void:
	_apply_character_toon_recursive(root)

static func apply_cast_shadow(root: Node, enabled: bool = true) -> void:
	_apply_cast_shadow_recursive(root, enabled)

static func clear_overlays(root: Node) -> void:
	_clear_overlays_recursive(root)

static func clear_surface_overrides(root: Node) -> void:
	_clear_surface_overrides_recursive(root)

static func _apply_outline_recursive(node: Node, outline: Material) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		if mesh_node.material_overlay == null:
			mesh_node.material_overlay = outline
	for child in node.get_children():
		_apply_outline_recursive(child, outline)

static func _apply_character_toon_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		var mesh := mesh_node.mesh
		if mesh != null:
			for i in range(mesh.get_surface_count()):
				var source := mesh_node.get_surface_override_material(i)
				if source == null:
					source = mesh.surface_get_material(i)
				mesh_node.set_surface_override_material(i, toon_from_material(source, 0.12))
	for child in node.get_children():
		_apply_character_toon_recursive(child)

static func _apply_cast_shadow_recursive(node: Node, enabled: bool) -> void:
	if node is GeometryInstance3D:
		var geometry := node as GeometryInstance3D
		geometry.layers = 1
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED if enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_apply_cast_shadow_recursive(child, enabled)

static func _clear_overlays_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		mesh_node.material_overlay = null
	for child in node.get_children():
		_clear_overlays_recursive(child)

static func _clear_surface_overrides_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		var mesh := mesh_node.mesh
		if mesh != null:
			for i in range(mesh.get_surface_count()):
				mesh_node.set_surface_override_material(i, null)
	for child in node.get_children():
		_clear_surface_overrides_recursive(child)
