import os
import bpy

BASE = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SOURCE_GLB = os.path.join(BASE, "characters", "player", "anime_model_boy_rigged.glb")
OUT_GLB = os.path.join(BASE, "characters", "player", "anime_model_boy_rigged_animated.glb")
ANIM_DIR = os.path.join(BASE, "characters", "player", "animations")

ANIMATIONS = [
    ("idle", "idle_wait.fbx"),
    ("idle_alt", "idle.fbx"),
    ("move_forward", "move_forward.fbx"),
    ("move_backward", "move_backward.fbx"),
    ("move_left", "move_left.fbx"),
    ("move_right", "move_right.fbx"),
    ("serve_short", "serve_short.fbx"),
    ("serve_long", "serve_long.fbx"),
    ("forehand_low_drop_block", "forehand_low_drop_block.fbx"),
    ("forehand_low_lift_clear", "forehand_low_lift_clear.fbx"),
    ("forehand_drive", "forehand_drive.fbx"),
    ("forehand_high_drop", "forehand_high_drop.fbx"),
    ("forehand_high_clear", "forehand_high_clear.fbx"),
    ("forehand_high_smash", "smashJeuBad.fbx"),
    ("forehand_tense_hit", "forehand_tense_hit.fbx"),
    ("backhand_low_drop_block", "backhand_low_drop_block.fbx"),
    ("backhand_low_lift", "backhand_low_lift.fbx"),
    ("backhand_drive", "backhand_drive.fbx"),
    ("backhand_high_drop", "backhand_high_drop.fbx"),
    ("backhand_high_clear", "backhand_high_clear.fbx"),
]

SMASH_JEU_BAD_BONE_MAP = {
    "root": "_rootJoint",
    "Hips": "Hips_01",
    "Spine": "Spine_02",
    "Spine1": "Chest_03",
    "Spine2": "Chest_03",
    "Neck": "Neck_08",
    "Head": "Head_09",
    "LeftShoulder": "Left shoulder_035",
    "LeftArm": "Left arm_036",
    "LeftForeArm": "Left elbow_039",
    "LeftHand": "Left wrist_040",
    "RightShoulder": "Right shoulder_056",
    "RightArm": "Right arm_057",
    "RightForeArm": "Right elbow_060",
    "RightHand": "Right wrist_061",
    "LeftUpLeg": "Left leg_077",
    "LeftLeg": "Left knee_081",
    "LeftFoot": "Left ankle_082",
    "LeftToeBase": "Left toe_083",
    "RightUpLeg": "Right leg_084",
    "RightLeg": "Right knee_088",
    "RightFoot": "Right ankle_089",
    "RightToeBase": "Right toe_090",
    "LeftHandThumb1": "Thumb0_L_053",
    "LeftHandThumb2": "Thumb1_L_054",
    "LeftHandThumb3": "Thumb2_L_055",
    "LeftHandIndex1": "IndexFinger1_L_041",
    "LeftHandIndex2": "IndexFinger2_L_042",
    "LeftHandIndex3": "IndexFinger3_L_043",
    "LeftHandMiddle1": "MiddleFinger1_L_047",
    "LeftHandMiddle2": "MiddleFinger2_L_048",
    "LeftHandMiddle3": "MiddleFinger3_L_049",
    "LeftHandRing1": "RingFinger1_L_050",
    "LeftHandRing2": "RingFinger2_L_051",
    "LeftHandRing3": "RingFinger3_L_052",
    "LeftHandPinky1": "LittleFinger1_L_044",
    "LeftHandPinky2": "LittleFinger2_L_045",
    "LeftHandPinky3": "LittleFinger3_L_046",
    "RightHandThumb1": "Thumb0_R_074",
    "RightHandThumb2": "Thumb1_R_075",
    "RightHandThumb3": "Thumb2_R_076",
    "RightHandIndex1": "IndexFinger1_R_062",
    "RightHandIndex2": "IndexFinger2_R_063",
    "RightHandIndex3": "IndexFinger3_R_064",
    "RightHandMiddle1": "MiddleFinger1_R_068",
    "RightHandMiddle2": "MiddleFinger2_R_069",
    "RightHandMiddle3": "MiddleFinger3_R_070",
    "RightHandRing1": "RingFinger1_R_071",
    "RightHandRing2": "RingFinger2_R_072",
    "RightHandRing3": "RingFinger3_R_073",
    "RightHandPinky1": "LittleFinger1_R_065",
    "RightHandPinky2": "LittleFinger2_R_066",
    "RightHandPinky3": "LittleFinger3_R_067",
}

BONE_REMAPS = {
    "smashJeuBad.fbx": SMASH_JEU_BAD_BONE_MAP,
}

LOCKED_TRANSLATION_BONES = {
    "smashJeuBad.fbx": {"_rootJoint", "Hips_01"},
}

LOCKED_ROTATION_BONES = {
    "smashJeuBad.fbx": {"_rootJoint", "Hips_01", "Spine_02", "Chest_03"},
}


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def find_armature(objects):
    return next((obj for obj in objects if obj.type == "ARMATURE"), None)


def strip_object_motion(action):
    """Keep skeletal pose curves, remove imported armature object motion.

    Mixamo/FBX clips often include location/rotation/scale curves on the
    armature object itself. In-game the CharacterBody already controls the
    player transform, so those curves fight with gameplay rotation and cause
    visible jitter or double-turning.
    """
    if hasattr(action, "fcurves"):
        for fcurve in list(action.fcurves):
            if not fcurve.data_path.startswith("pose.bones"):
                action.fcurves.remove(fcurve)
        return

    # Blender 5.x layered actions store curves inside channel bags.
    for layer in getattr(action, "layers", []):
        for strip in getattr(layer, "strips", []):
            for bag in getattr(strip, "channelbags", []):
                for fcurve in list(bag.fcurves):
                    if not fcurve.data_path.startswith("pose.bones"):
                        bag.fcurves.remove(fcurve)


def remap_action_bones(action, bone_map, target_bones):
    if not bone_map:
        return

    def remap_fcurves(fcurves):
        for fcurve in list(fcurves):
            path = fcurve.data_path
            prefix = 'pose.bones["'
            if not path.startswith(prefix):
                continue
            source_bone = path[len(prefix):].split('"]', 1)[0]
            target_bone = bone_map.get(source_bone, source_bone)
            if target_bone not in target_bones:
                fcurves.remove(fcurve)
                continue
            if target_bone != source_bone:
                fcurve.data_path = path.replace(f'{prefix}{source_bone}"]', f'{prefix}{target_bone}"]', 1)

    if hasattr(action, "fcurves"):
        remap_fcurves(action.fcurves)
        return

    for layer in getattr(action, "layers", []):
        for strip in getattr(layer, "strips", []):
            for bag in getattr(strip, "channelbags", []):
                remap_fcurves(bag.fcurves)


def remove_bone_translation(action, locked_bones):
    if not locked_bones:
        return

    def clean_fcurves(fcurves):
        for fcurve in list(fcurves):
            path = fcurve.data_path
            prefix = 'pose.bones["'
            if not path.startswith(prefix) or not path.endswith('"].location'):
                continue
            bone_name = path[len(prefix):].split('"]', 1)[0]
            if bone_name in locked_bones:
                fcurves.remove(fcurve)

    if hasattr(action, "fcurves"):
        clean_fcurves(action.fcurves)
        return

    for layer in getattr(action, "layers", []):
        for strip in getattr(layer, "strips", []):
            for bag in getattr(strip, "channelbags", []):
                clean_fcurves(bag.fcurves)


def remove_bone_rotation(action, locked_bones):
    if not locked_bones:
        return

    def clean_fcurves(fcurves):
        for fcurve in list(fcurves):
            path = fcurve.data_path
            prefix = 'pose.bones["'
            if not path.startswith(prefix) or not path.endswith('"].rotation_quaternion'):
                continue
            bone_name = path[len(prefix):].split('"]', 1)[0]
            if bone_name in locked_bones:
                fcurves.remove(fcurve)

    if hasattr(action, "fcurves"):
        clean_fcurves(action.fcurves)
        return

    for layer in getattr(action, "layers", []):
        for strip in getattr(layer, "strips", []):
            for bag in getattr(strip, "channelbags", []):
                clean_fcurves(bag.fcurves)


clear_scene()
bpy.ops.import_scene.gltf(filepath=SOURCE_GLB)
target_armature = find_armature(bpy.context.scene.objects)
if target_armature is None:
    raise RuntimeError(f"No armature found in {SOURCE_GLB}")
target_bones = {bone.name for bone in target_armature.data.bones}

created = []
for animation_name, filename in ANIMATIONS:
    fbx_path = os.path.join(ANIM_DIR, filename)
    if not os.path.exists(fbx_path):
        print(f"Missing animation: {fbx_path}")
        continue

    before_objects = set(bpy.context.scene.objects)
    before_actions = set(bpy.data.actions)
    bpy.ops.import_scene.fbx(filepath=fbx_path)
    imported_objects = [obj for obj in bpy.context.scene.objects if obj not in before_objects]
    imported_armature = find_armature(imported_objects)
    action = imported_armature.animation_data.action if imported_armature and imported_armature.animation_data else None
    if action is None:
        new_actions = [action for action in bpy.data.actions if action not in before_actions]
        action = max(new_actions, key=lambda item: len(getattr(item, "fcurves", [])), default=None)
    if action is None:
        print(f"No action found for {animation_name}")
    else:
        action_copy = action.copy()
        action_copy.name = animation_name
        strip_object_motion(action_copy)
        remap_action_bones(action_copy, BONE_REMAPS.get(filename, {}), target_bones)
        remove_bone_translation(action_copy, LOCKED_TRANSLATION_BONES.get(filename, set()))
        remove_bone_rotation(action_copy, LOCKED_ROTATION_BONES.get(filename, set()))
        target_armature.animation_data_create()
        target_armature.animation_data.action = action_copy
        track = target_armature.animation_data.nla_tracks.new()
        track.name = animation_name
        strip = track.strips.new(animation_name, int(action_copy.frame_range[0]), action_copy)
        strip.name = animation_name
        created.append(animation_name)

    for obj in imported_objects:
        bpy.data.objects.remove(obj, do_unlink=True)

for obj in bpy.context.scene.objects:
    obj.select_set(True)

bpy.ops.export_scene.gltf(
    filepath=OUT_GLB,
    export_format="GLB",
    export_animations=True,
    export_animation_mode="NLA_TRACKS",
    export_frame_range=False,
    export_yup=True,
)

print("Created animations:", created)
print("Exported:", OUT_GLB)
