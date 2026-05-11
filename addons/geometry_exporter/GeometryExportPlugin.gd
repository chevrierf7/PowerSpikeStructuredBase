@tool
extends EditorPlugin

const EXPORT_DIR := "res://exports_geometry"
const COURT_SCENE := "res://scenes/court/Court.tscn"
const GYM_SCENE := "res://scenes/environment/Gym_JP_A.tscn"
const CourtBuilderScript := preload("res://scripts/world/CourtBuilder.gd")
const GymBuilderScript := preload("res://scripts/world/GymBuilder.gd")

const COURT_NAMES := {
	"CourtLine": true
}

const NET_PREFIXES := ["Net"]

const GYM_NAMES := {
	"JPWoodFloor": true,
	"ShortWallWood": true,
	"ShortWallUpper": true,
	"SideWallWood": true,
	"SideWallUpper": true,
	"DarkCeiling": true,
	"CeilingBeamX": true,
	"CeilingBeamZ": true,
	"NeonPanel": true
}

const PROP_PREFIXES := [
	"Bench",
	"SideCurtain",
	"CurtainRod",
	"WallBanner",
	"JPBannerMark",
	"LowStage"
]

func _enter_tree() -> void:
	add_tool_menu_item("Export geometry to GLB", _export_geometry)

func _exit_tree() -> void:
	remove_tool_menu_item("Export geometry to GLB")

func _export_geometry() -> void:
	var result: Array[String] = export_all()
	for line in result:
		print(line)
	_show_result(result)

func _show_result(lines: Array[String]) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Export geometry to GLB"
	dialog.dialog_text = "\n".join(lines)
	get_editor_interface().get_base_control().add_child(dialog)
	dialog.popup_centered(Vector2i(620, 420))

func export_all() -> Array[String]:
	var messages: Array[String] = []
	_ensure_export_dir(messages)
	var staging := Node3D.new()
	staging.name = "GeometryExportStaging"
	get_editor_interface().get_base_control().add_child(staging)

	var court_root := CourtBuilderScript.new() as Node3D
	court_root.name = "Court"
	staging.add_child(court_root)
	_rebuild_generated_scene(court_root, messages)

	var gym_root := GymBuilderScript.new() as Node3D
	gym_root.name = "Gym_JP_A"
	staging.add_child(gym_root)
	_rebuild_generated_scene(gym_root, messages)

	var court_export := _make_export_root(staging, "court")
	_copy_matching_meshes(court_root, court_export, Callable(self, "_is_court_mesh"))
	_export_group(court_export, "court", messages)

	var net_export := _make_export_root(staging, "filet")
	_copy_matching_meshes(court_root, net_export, Callable(self, "_is_net_mesh"))
	_export_group(net_export, "filet", messages)

	var gym_export := _make_export_root(staging, "gymnase")
	_copy_matching_meshes(gym_root, gym_export, Callable(self, "_is_gym_mesh"))
	_export_group(gym_export, "gymnase", messages)

	var props_export := _make_export_root(staging, "props")
	_copy_matching_meshes(gym_root, props_export, Callable(self, "_is_prop_mesh"))
	_export_group(props_export, "props", messages)

	staging.queue_free()
	messages.append("Geometry export finished.")
	return messages

func _make_export_root(parent: Node, node_name: String) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	parent.add_child(root)
	return root

func _ensure_export_dir(messages: Array[String]) -> void:
	var absolute_dir := ProjectSettings.globalize_path(EXPORT_DIR)
	if DirAccess.dir_exists_absolute(absolute_dir):
		return
	var err := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if err == OK:
		messages.append("Created " + EXPORT_DIR)
	else:
		messages.append("Could not create " + EXPORT_DIR + " error=" + str(err))

func _rebuild_generated_scene(root: Node3D, messages: Array[String]) -> void:
	if root.has_method("build"):
		root.call("build")
	messages.append("Built " + root.name + " meshes=" + str(_count_meshes(root)))

func _count_meshes(node: Node) -> int:
	var count := 1 if node is MeshInstance3D else 0
	for child in node.get_children():
		count += _count_meshes(child)
	return count

func _copy_matching_meshes(source: Node, target: Node3D, predicate: Callable) -> void:
	if source == null or target == null:
		return
	if source is MeshInstance3D and bool(predicate.call(source)):
		var source_mesh := source as MeshInstance3D
		if source_mesh.visible and source_mesh.mesh != null:
			target.add_child(_clone_mesh_instance(source_mesh))
	for child in source.get_children():
		_copy_matching_meshes(child, target, predicate)

func _clone_mesh_instance(source: MeshInstance3D) -> MeshInstance3D:
	var clone := MeshInstance3D.new()
	clone.name = source.name
	clone.mesh = _bake_mesh(source.mesh)
	clone.material_override = source.material_override
	clone.global_transform = source.global_transform
	clone.visible = true
	clone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return clone

func _bake_mesh(source: Mesh) -> ArrayMesh:
	var baked := ArrayMesh.new()
	if source == null:
		return baked
	if source is PrimitiveMesh:
		var arrays := (source as PrimitiveMesh).get_mesh_arrays()
		if arrays.size() == Mesh.ARRAY_MAX:
			baked.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return baked
	for surface_index in range(source.get_surface_count()):
		if source.surface_get_primitive_type(surface_index) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arrays := source.surface_get_arrays(surface_index)
		if arrays.size() == Mesh.ARRAY_MAX:
			baked.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return baked

func _export_group(root: Node3D, group_name: String, messages: Array[String]) -> void:
	_export_glb(root, EXPORT_DIR + "/" + group_name + ".glb", messages)
	_export_stl(root, EXPORT_DIR + "/" + group_name + ".stl", messages)

func _export_glb(root: Node3D, path: String, messages: Array[String]) -> void:
	if root.get_child_count() == 0:
		messages.append("Skipped " + path + " because no mesh matched.")
		return
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var append_error := document.append_from_scene(root, state)
	if append_error != OK:
		messages.append("Failed building GLB for " + path + " error=" + str(append_error))
		return
	var write_error := document.write_to_filesystem(state, ProjectSettings.globalize_path(path))
	if write_error == OK:
		messages.append("Exported " + path + " meshes=" + str(root.get_child_count()))
	else:
		messages.append("Failed writing " + path + " error=" + str(write_error))

func _export_stl(root: Node3D, path: String, messages: Array[String]) -> void:
	if root.get_child_count() == 0:
		messages.append("Skipped " + path + " because no mesh matched.")
		return
	var file := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.WRITE)
	if file == null:
		messages.append("Failed opening " + path)
		return
	var solid_name := root.name.replace(" ", "_").replace("-", "_")
	file.store_line("solid " + solid_name)
	var triangle_count := _write_stl_node(root, file)
	file.store_line("endsolid " + solid_name)
	file.close()
	messages.append("Exported " + path + " triangles=" + str(triangle_count))

func _write_stl_node(node: Node, file: FileAccess) -> int:
	var count := 0
	if node is MeshInstance3D:
		count += _write_stl_mesh(node as MeshInstance3D, file)
	for child in node.get_children():
		count += _write_stl_node(child, file)
	return count

func _write_stl_mesh(mesh_node: MeshInstance3D, file: FileAccess) -> int:
	if not mesh_node.visible or mesh_node.mesh == null:
		return 0
	var written := 0
	for surface_index in range(mesh_node.mesh.get_surface_count()):
		var arrays := mesh_node.mesh.surface_get_arrays(surface_index)
		if arrays.size() != Mesh.ARRAY_MAX:
			continue
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			var vertex_index := 0
			while vertex_index + 2 < vertices.size():
				written += _write_stl_triangle_from_vertices(file, mesh_node.global_transform, vertices[vertex_index], vertices[vertex_index + 1], vertices[vertex_index + 2])
				vertex_index += 3
		else:
			var index := 0
			while index + 2 < indices.size():
				written += _write_stl_triangle_from_vertices(file, mesh_node.global_transform, vertices[indices[index]], vertices[indices[index + 1]], vertices[indices[index + 2]])
				index += 3
	return written

func _write_stl_triangle_from_vertices(file: FileAccess, transform: Transform3D, local_a: Vector3, local_b: Vector3, local_c: Vector3) -> int:
	var a := transform * local_a
	var b := transform * local_b
	var c := transform * local_c
	var normal := (b - a).cross(c - a).normalized()
	if normal.length_squared() <= 0.000001:
		return 0
	file.store_line("  facet normal %s %s %s" % [_stl_float(normal.x), _stl_float(normal.y), _stl_float(normal.z)])
	file.store_line("    outer loop")
	file.store_line("      vertex %s %s %s" % [_stl_float(a.x), _stl_float(a.y), _stl_float(a.z)])
	file.store_line("      vertex %s %s %s" % [_stl_float(b.x), _stl_float(b.y), _stl_float(b.z)])
	file.store_line("      vertex %s %s %s" % [_stl_float(c.x), _stl_float(c.y), _stl_float(c.z)])
	file.store_line("    endloop")
	file.store_line("  endfacet")
	return 1

func _stl_float(value: float) -> String:
	return "%.6f" % value

func _is_court_mesh(node: MeshInstance3D) -> bool:
	return COURT_NAMES.has(node.name)

func _is_net_mesh(node: MeshInstance3D) -> bool:
	for prefix in NET_PREFIXES:
		if node.name.begins_with(prefix):
			return true
	return false

func _is_gym_mesh(node: MeshInstance3D) -> bool:
	return GYM_NAMES.has(node.name)

func _is_prop_mesh(node: MeshInstance3D) -> bool:
	for prefix in PROP_PREFIXES:
		if node.name.begins_with(prefix):
			return true
	return false
