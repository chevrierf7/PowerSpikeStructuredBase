extends Node3D

@export var avatar_scene_path := GameConfig.VROID_AVATAR_SCENE

var avatar_root: Node3D
var skeleton: Skeleton3D

func _ready() -> void:
	_load_avatar()
	_print_avatar_summary()


func _load_avatar() -> void:
	var scene := load(avatar_scene_path)
	if not (scene is PackedScene):
		push_error("TestVroidAvatar: impossible de charger %s" % avatar_scene_path)
		return
	avatar_root = (scene as PackedScene).instantiate() as Node3D
	if avatar_root == null:
		push_error("TestVroidAvatar: la scene VRoid n'est pas un Node3D.")
		return
	avatar_root.name = "VroidAvatar"
	add_child(avatar_root)
	skeleton = _find_first_skeleton(avatar_root)


func _print_avatar_summary() -> void:
	if skeleton == null:
		push_warning("TestVroidAvatar: aucun Skeleton3D trouve.")
		return
	print("TestVroidAvatar skeleton=%s bones=%d right_hand=%s left_hand=%s head=%s hips=%s" % [
		skeleton.name,
		skeleton.get_bone_count(),
		_find_bone_name(["J_Bip_R_Hand", "RightHand", "Hand_R"]),
		_find_bone_name(["J_Bip_L_Hand", "LeftHand", "Hand_L"]),
		_find_bone_name(["J_Bip_C_Head", "Head"]),
		_find_bone_name(["J_Bip_C_Hips", "Hips", "Root"])
	])


func _find_first_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_first_skeleton(child)
		if found != null:
			return found
	return null


func _find_bone_name(candidates: Array[String]) -> String:
	if skeleton == null:
		return "-"
	for candidate in candidates:
		var bone := skeleton.find_bone(candidate)
		if bone >= 0:
			return skeleton.get_bone_name(bone)
	return "-"
