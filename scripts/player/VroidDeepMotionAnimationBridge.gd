class_name VroidDeepMotionAnimationBridge
extends RefCounted

const RetargetMap := preload("res://scripts/player/VroidDeepMotionRetargetMap.gd")


static func attach_first_animation_from_scene(target_avatar: Node, source_scene_path: String, target_clip_name: String, root_yaw_offset_degrees := 0.0) -> AnimationPlayer:
	var source_scene := load(source_scene_path)
	if not (source_scene is PackedScene):
		return null
	var source_root := (source_scene as PackedScene).instantiate()
	var source_player := _find_first_animation_player(source_root)
	if source_player == null:
		source_root.queue_free()
		return null
	var source_names := source_player.get_animation_list()
	if source_names.is_empty():
		source_root.queue_free()
		return null
	var source_animation := source_player.get_animation(String(source_names[0]))
	if source_animation == null:
		source_root.queue_free()
		return null
	var target_player := AnimationPlayer.new()
	target_player.name = "DeepMotionAnimationPlayer"
	target_player.root_node = NodePath("..")
	target_avatar.add_child(target_player)
	var library := AnimationLibrary.new()
	library.add_animation(target_clip_name, _copy_animation_for_plain_vroid(source_animation, root_yaw_offset_degrees))
	target_player.add_animation_library("", library)
	source_root.queue_free()
	return target_player


static func _copy_animation_for_plain_vroid(source_animation: Animation, root_yaw_offset_degrees := 0.0) -> Animation:
	var animation := source_animation.duplicate(true) as Animation
	var root_rotation_tracks: Array[int] = []
	for track_index in range(animation.get_track_count() - 1, -1, -1):
		var path := String(animation.track_get_path(track_index))
		if path == "VROID_Armature":
			animation.remove_track(track_index)
			continue
		if path == "Node":
			animation.track_set_path(track_index, NodePath("."))
			continue
		if path.begins_with("VROID_Armature/Skeleton3D"):
			animation.track_set_path(track_index, NodePath(path.replace("VROID_Armature/Skeleton3D", "Skeleton3D")))
			continue
		if path.contains("/Skeleton3D:"):
			var source_bone := path.get_slice(":", 1)
			var target_bone := RetargetMap.vroid_bone_for_deepmotion(source_bone)
			if target_bone.is_empty() and source_bone.begins_with("J_Bip_"):
				target_bone = source_bone
			if target_bone.is_empty():
				animation.remove_track(track_index)
				continue
			animation.track_set_path(track_index, NodePath("Skeleton3D:%s" % target_bone))
			if target_bone == "J_Bip_C_Hips" and animation.track_get_type(track_index) == Animation.TYPE_ROTATION_3D:
				root_rotation_tracks.append(track_index)
			continue
		if path.begins_with("RootNode/Skeleton3D:"):
			var source_bone := path.get_slice(":", 1)
			var target_bone := RetargetMap.vroid_bone_for_deepmotion(source_bone)
			if target_bone.is_empty():
				animation.remove_track(track_index)
				continue
			if animation.track_get_type(track_index) == Animation.TYPE_POSITION_3D:
				animation.remove_track(track_index)
				continue
			animation.track_set_path(track_index, NodePath("Skeleton3D:%s" % target_bone))
			if target_bone == "J_Bip_C_Hips" and animation.track_get_type(track_index) == Animation.TYPE_ROTATION_3D:
				root_rotation_tracks.append(track_index)
	if not is_zero_approx(root_yaw_offset_degrees):
		_apply_root_yaw_offset(animation, root_rotation_tracks, root_yaw_offset_degrees)
	return animation


static func _apply_root_yaw_offset(animation: Animation, track_indices: Array[int], yaw_degrees: float) -> void:
	var correction := Quaternion(Vector3.UP, deg_to_rad(yaw_degrees))
	for track_index in track_indices:
		for key_index in range(animation.track_get_key_count(track_index)):
			var value: Variant = animation.track_get_key_value(track_index, key_index)
			if value is Quaternion:
				animation.track_set_key_value(track_index, key_index, correction * (value as Quaternion))


static func _find_first_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var player := _find_first_animation_player(child)
		if player != null:
			return player
	return null
