class_name VroidDeepMotionRetargetMap
extends RefCounted

const BONE_MAP := {
	"Hips": "J_Bip_C_Hips",
	"Spine": "J_Bip_C_Spine",
	"Spine1": "J_Bip_C_Chest",
	"Spine2": "J_Bip_C_UpperChest",
	"Neck": "J_Bip_C_Neck",
	"Head": "J_Bip_C_Head",
	"LeftShoulder": "J_Bip_L_Shoulder",
	"LeftArm": "J_Bip_L_UpperArm",
	"LeftForeArm": "J_Bip_L_LowerArm",
	"LeftHand": "J_Bip_L_Hand",
	"RightShoulder": "J_Bip_R_Shoulder",
	"RightArm": "J_Bip_R_UpperArm",
	"RightForeArm": "J_Bip_R_LowerArm",
	"RightHand": "J_Bip_R_Hand",
	"LeftUpLeg": "J_Bip_L_UpperLeg",
	"LeftLeg": "J_Bip_L_LowerLeg",
	"LeftFoot": "J_Bip_L_Foot",
	"LeftToeBase": "J_Bip_L_ToeBase",
	"RightUpLeg": "J_Bip_R_UpperLeg",
	"RightLeg": "J_Bip_R_LowerLeg",
	"RightFoot": "J_Bip_R_Foot",
	"RightToeBase": "J_Bip_R_ToeBase",
}

const PROBE_POSE_DEGREES := {
	"J_Bip_C_Hips": Vector3(0.0, -8.0, -5.0),
	"J_Bip_C_Spine": Vector3(4.0, -10.0, 0.0),
	"J_Bip_C_Chest": Vector3(8.0, -18.0, 2.0),
	"J_Bip_C_UpperChest": Vector3(4.0, -12.0, 0.0),
	"J_Bip_C_Head": Vector3(-3.0, 8.0, 0.0),
	"J_Bip_R_Shoulder": Vector3(0.0, 0.0, -18.0),
	"J_Bip_R_UpperArm": Vector3(-82.0, -18.0, -42.0),
	"J_Bip_R_LowerArm": Vector3(-48.0, 4.0, -16.0),
	"J_Bip_R_Hand": Vector3(-18.0, 4.0, -28.0),
	"J_Bip_L_Shoulder": Vector3(0.0, 0.0, 12.0),
	"J_Bip_L_UpperArm": Vector3(22.0, 18.0, 34.0),
	"J_Bip_L_LowerArm": Vector3(22.0, -8.0, 16.0),
	"J_Bip_L_Hand": Vector3(4.0, -4.0, 12.0),
	"J_Bip_R_UpperLeg": Vector3(-8.0, 2.0, -4.0),
	"J_Bip_R_LowerLeg": Vector3(10.0, 0.0, 0.0),
	"J_Bip_L_UpperLeg": Vector3(8.0, -2.0, 4.0),
	"J_Bip_L_LowerLeg": Vector3(4.0, 0.0, 0.0),
}


static func vroid_bone_for_deepmotion(deepmotion_bone_name: String) -> String:
	if BONE_MAP.has(deepmotion_bone_name):
		return String(BONE_MAP[deepmotion_bone_name])
	var finger_name := _vroid_finger_bone_for_deepmotion(deepmotion_bone_name)
	if not finger_name.is_empty():
		return finger_name
	return ""


static func _vroid_finger_bone_for_deepmotion(deepmotion_bone_name: String) -> String:
	var side := ""
	var rest := deepmotion_bone_name
	if rest.begins_with("LeftHand"):
		side = "L"
		rest = rest.trim_prefix("LeftHand")
	elif rest.begins_with("RightHand"):
		side = "R"
		rest = rest.trim_prefix("RightHand")
	if side.is_empty():
		return ""
	for source_name in ["Thumb", "Index", "Middle", "Ring", "Pinky"]:
		if not rest.begins_with(source_name):
			continue
		var joint := rest.trim_prefix(source_name)
		if joint.is_valid_int():
			var target_name: String = "Little" if source_name == "Pinky" else source_name
			return "J_Bip_%s_%s%s" % [side, target_name, joint]
	return ""


static func apply_probe_pose(skeleton: Skeleton3D) -> int:
	var applied_count := 0
	for bone_name in PROBE_POSE_DEGREES.keys():
		var bone_index := skeleton.find_bone(String(bone_name))
		if bone_index < 0:
			continue
		var degrees := PROBE_POSE_DEGREES[bone_name] as Vector3
		var radians := Vector3(deg_to_rad(degrees.x), deg_to_rad(degrees.y), deg_to_rad(degrees.z))
		skeleton.set_bone_pose_rotation(bone_index, Basis.from_euler(radians).get_rotation_quaternion())
		applied_count += 1
	return applied_count
