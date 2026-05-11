extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://characters/shuttle/Volantbadminton.glb")
	var root := (scene as PackedScene).instantiate() as Node3D
	get_root().add_child(root)
	await process_frame
	var bounds := _bounds_for(root, root)
	print("bounds pos=", bounds.position, " size=", bounds.size, " center=", bounds.get_center())
	root.free()
	quit()

func _bounds_for(root: Node3D, node: Node) -> AABB:
	var has_bounds := false
	var bounds := AABB()
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		var local_aabb := mesh_node.get_aabb()
		var transform_to_root := root.global_transform.affine_inverse() * mesh_node.global_transform
		bounds = _transform_aabb(transform_to_root, local_aabb)
		has_bounds = true
	for child in node.get_children():
		if child is Node:
			var child_bounds := _bounds_for(root, child)
			if child_bounds.size != Vector3.ZERO:
				if has_bounds:
					bounds = bounds.merge(child_bounds)
				else:
					bounds = child_bounds
					has_bounds = true
	return bounds

func _transform_aabb(transform: Transform3D, box: AABB) -> AABB:
	var points := [
		box.position,
		box.position + Vector3(box.size.x, 0, 0),
		box.position + Vector3(0, box.size.y, 0),
		box.position + Vector3(0, 0, box.size.z),
		box.position + Vector3(box.size.x, box.size.y, 0),
		box.position + Vector3(box.size.x, 0, box.size.z),
		box.position + Vector3(0, box.size.y, box.size.z),
		box.position + box.size
	]
	var result := AABB(transform * points[0], Vector3.ZERO)
	for point in points:
		result = result.expand(transform * point)
	return result
