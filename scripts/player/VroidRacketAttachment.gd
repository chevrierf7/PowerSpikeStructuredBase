class_name VroidRacketAttachment
extends RefCounted


static func attach_to_right_hand(model_root: Node) -> Node3D:
	var skeleton := _find_first_skeleton(model_root)
	if skeleton == null:
		return null
	var hand_bone := _find_right_hand_bone(skeleton)
	if hand_bone < 0:
		return null
	var attachment := BoneAttachment3D.new()
	attachment.name = "RightHandRacketAttachment"
	attachment.bone_name = skeleton.get_bone_name(hand_bone)
	attachment.bone_idx = hand_bone
	skeleton.add_child(attachment)
	var hand_grip := Node3D.new()
	hand_grip.name = "HandGrip"
	hand_grip.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	attachment.add_child(hand_grip)
	var offset := Node3D.new()
	offset.name = "RacketOffset"
	offset.position = Vector3(0.07, -0.11, -0.03)
	offset.rotation_degrees = Vector3(5.0, 10.0, 0.0)
	hand_grip.add_child(offset)
	var racket_scene := load(GameConfig.RACKET_MODEL_SCENE)
	if racket_scene is PackedScene:
		var racket := (racket_scene as PackedScene).instantiate() as Node3D
		racket.name = "AttachedRacket"
		offset.add_child(racket)
		return racket
	return null


static func _find_first_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_first_skeleton(child)
		if found != null:
			return found
	return null


static func _find_right_hand_bone(skeleton: Skeleton3D) -> int:
	for candidate in ["J_Bip_R_Hand"]:
		var bone := skeleton.find_bone(candidate)
		if bone >= 0:
			return bone
	for index in range(skeleton.get_bone_count()):
		var bone_name := skeleton.get_bone_name(index).to_lower()
		if bone_name.contains("j_bip_r") and bone_name.contains("hand"):
			return index
	return -1
