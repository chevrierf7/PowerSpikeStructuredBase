# VRoid + DeepMotion Character Pipeline

## Decision

Shuttle Rush uses VRoid characters as the player avatar source and DeepMotion as the animation source.

The character and animation pipeline is now VRoid avatars plus DeepMotion animation sources. Legacy character rigs are not part of the runtime path anymore.

## Current Verified Baseline

Main VRoid source:

`res://characters/player/vroid/source/Test_Shuttle_rush_perso.vrm`

Godot-importable copy:

`res://characters/player/vroid/godot/test_shuttle_rush_perso.glb`

The `.glb` copy is the same VRM payload renamed for Godot's glTF importer. Godot successfully imports it and extracts the embedded textures.

Audit result:

- Skeleton count: 1
- Bone count: 124
- Hips: `J_Bip_C_Hips`
- Head: `J_Bip_C_Head`
- Right hand: `J_Bip_R_Hand`
- Left hand: `J_Bip_L_Hand`
- AnimationPlayer: none in the avatar source, expected for a clean VRoid character.

## Current Bridge Result

The working bridge is now used by the match player:

- Approved smash animation: `res://assets/animations/deepmotion/approved/smash.glb`.
- Approved service animation: `res://assets/animations/deepmotion/approved/service.glb`.
- `VroidDeepMotionAnimationBridge` copies the first usable clip onto the active VRoid avatar.
- Track paths are remapped onto the active `Skeleton3D`.
- Racket attachment uses `J_Bip_R_Hand`.
- Service shuttle attachment uses the free-hand anchor `FreeHandServiceAttachment/ServiceShuttleGrip/ServiceShuttleOffset`.

The source clip name can come from the exporter. The runtime bridge does not depend on that name; it copies the first usable clip onto the active VRoid avatar.

## DeepMotion Animation Rule

DeepMotion clips are accepted only after they work on the VRoid avatar in Godot.
If a clip uses a standard humanoid skeleton (`Hips`, `Spine`, `RightHand`, etc.), it must pass through the retarget mapping step before it can drive the VRoid avatar.

## Runtime Rule

Gameplay remains driven by `ShotData.animation_name`, `impact_time`, and recovery timing.

Animation files must adapt to the gameplay contract. Importing a DeepMotion clip must not silently change shuttle trajectory, impact timing, scoring, or player movement rules.

## Folder Layout

| Folder | Purpose |
|---|---|
| `res://characters/player/vroid/source/` | Original `.vrm` files exported from VRoid. |
| `res://characters/player/vroid/godot/` | Godot-importable `.glb` copies and extracted textures. |
| `res://assets/animations/deepmotion/approved/` | DeepMotion clips validated enough to be used by gameplay or previews. |

## Integration Order

1. Import a new DeepMotion `.glb`.
2. Test it on one VRoid avatar in the animation lab.
3. Adjust orientation, speed, and anchor offsets.
4. Move it to `res://assets/animations/deepmotion/approved/`.
5. Reference it from the relevant `VroidAvatarProfile`.

## Definition Of Done For First Real Clip

A first DeepMotion clip is accepted when:

- it plays on the VRoid avatar in Godot;
- feet stay near the floor unless the animation intentionally jumps;
- racket hand is stable enough for racket attachment;
- the animation can be triggered by the existing gameplay state machine;
- the clip is referenced by a `VroidAvatarProfile`.
