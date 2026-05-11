extends SceneTree

const DEFAULT_MODEL_PATH := "res://characters/player/vroid/godot/test_shuttle_rush_perso.glb"

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var model_path := OS.get_environment("CODEX_AVATAR_PATH")
	if model_path == "":
		model_path = DEFAULT_MODEL_PATH
	print("AVATAR_AUDIT model=%s" % model_path)
	var packed := load(model_path)
	if not (packed is PackedScene):
		push_error("Model is not a PackedScene: %s" % model_path)
		quit(1)
		return
	var root := (packed as PackedScene).instantiate()
	get_root().add_child(root)
	await process_frame
	if OS.get_environment("CODEX_AUDIT_TREE") == "1":
		_print_tree(root, 0)
	var skeletons := []
	var animation_players := []
	_collect_nodes(root, skeletons, animation_players)
	print("AVATAR_AUDIT skeleton_count=%d animation_player_count=%d" % [skeletons.size(), animation_players.size()])
	for skeleton in skeletons:
		_print_skeleton(skeleton as Skeleton3D)
	for player in animation_players:
		_print_animation_player(player as AnimationPlayer)
	quit()


func _collect_nodes(node: Node, skeletons: Array, animation_players: Array) -> void:
	if node is Skeleton3D:
		skeletons.append(node)
	if node is AnimationPlayer:
		animation_players.append(node)
	for child in node.get_children():
		_collect_nodes(child, skeletons, animation_players)


func _print_tree(node: Node, depth: int) -> void:
	if depth > 4:
		return
	var prefix := ""
	for index in range(depth):
		prefix += "  "
	print("AVATAR_AUDIT tree=%s%s type=%s" % [prefix, node.name, node.get_class()])
	for child in node.get_children():
		_print_tree(child, depth + 1)


func _print_skeleton(skeleton: Skeleton3D) -> void:
	if skeleton == null:
		return
	var first_bones := PackedStringArray()
	for index in range(min(skeleton.get_bone_count(), 32)):
		first_bones.append(skeleton.get_bone_name(index))
	print("AVATAR_AUDIT skeleton=%s bones=%d first_bones=%s" % [skeleton.name, skeleton.get_bone_count(), str(first_bones)])
	if OS.get_environment("CODEX_AUDIT_ALL_BONES") == "1":
		var all_bones := PackedStringArray()
		for index in range(skeleton.get_bone_count()):
			all_bones.append(skeleton.get_bone_name(index))
		print("AVATAR_AUDIT all_bones=%s" % str(all_bones))
	print("AVATAR_AUDIT hands right=%s left=%s head=%s hips=%s" % [
		_find_bone_name(skeleton, ["J_Bip_R_Hand", "RightHand", "rightHand", "Hand_R", "hand_r", "Right wrist_061"]),
		_find_bone_name(skeleton, ["J_Bip_L_Hand", "LeftHand", "leftHand", "Hand_L", "hand_l", "Left wrist_033"]),
		_find_bone_name(skeleton, ["J_Bip_C_Head", "Head", "head", "Head_05"]),
		_find_bone_name(skeleton, ["J_Bip_C_Hips", "Hips", "hips", "Root", "root"])
	])


func _print_animation_player(player: AnimationPlayer) -> void:
	if player == null:
		return
	var names := player.get_animation_list()
	print("AVATAR_AUDIT animation_player=%s animations=%s" % [player.name, str(names)])
	for animation_name in names:
		var animation := player.get_animation(animation_name)
		if animation != null:
			print("AVATAR_AUDIT clip=%s length=%.3f tracks=%d" % [String(animation_name), animation.length, animation.get_track_count()])
			_print_animation_tracks(animation)
	var library_names := player.get_animation_library_list()
	print("AVATAR_AUDIT animation_libraries=%s" % str(library_names))
	for library_name in library_names:
		var library := player.get_animation_library(library_name)
		if library == null:
			continue
		var library_clip_names := library.get_animation_list()
		print("AVATAR_AUDIT library=%s clips=%s" % [String(library_name), str(library_clip_names)])
		for clip_name in library_clip_names:
			var animation := library.get_animation(clip_name)
			if animation != null:
				print("AVATAR_AUDIT library_clip=%s/%s length=%.3f tracks=%d" % [
					String(library_name),
					String(clip_name),
					animation.length,
					animation.get_track_count()
				])
				_print_animation_tracks(animation)


func _print_animation_tracks(animation: Animation) -> void:
	if OS.get_environment("CODEX_AUDIT_TRACKS") != "1":
		return
	for track_index in range(min(animation.get_track_count(), 24)):
		print("AVATAR_AUDIT track=%d type=%d path=%s keys=%d" % [
			track_index,
			animation.track_get_type(track_index),
			str(animation.track_get_path(track_index)),
			animation.track_get_key_count(track_index)
		])


func _find_bone_name(skeleton: Skeleton3D, candidates: Array[String]) -> String:
	for candidate in candidates:
		var bone := skeleton.find_bone(candidate)
		if bone >= 0:
			return skeleton.get_bone_name(bone)
	for index in range(skeleton.get_bone_count()):
		var lower_name := skeleton.get_bone_name(index).to_lower()
		for candidate in candidates:
			var lower_candidate := candidate.to_lower()
			if lower_name.contains(lower_candidate) or lower_candidate.contains(lower_name):
				return skeleton.get_bone_name(index)
	return "-"
