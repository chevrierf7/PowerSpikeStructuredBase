class_name GameConfig
extends RefCounted

const COURT_LENGTH := 13.40
const COURT_WIDTH := 6.10
const SINGLES_WIDTH := 5.18
const SHORT_SERVICE_DISTANCE := 1.98
const DOUBLES_LONG_SERVICE_DISTANCE := 5.94
const NET_HEIGHT := 1.55
const NET_CENTER_HEIGHT := 1.524
const NET_BOTTOM_HEIGHT := 0.78
const LINE_WIDTH := 0.060
const GYM_FLOOR_TOP_Y := -0.035
const COURT_VISUAL_SURFACE_TOP_Y := GYM_FLOOR_TOP_Y
const COURT_LINE_VISUAL_HEIGHT := 0.008
const COURT_LINE_VISUAL_GAP := 0.002
const COURT_LINE_CENTER_Y := COURT_VISUAL_SURFACE_TOP_Y + COURT_LINE_VISUAL_GAP + COURT_LINE_VISUAL_HEIGHT * 0.5
const COURT_EFFECT_Y := COURT_VISUAL_SURFACE_TOP_Y + COURT_LINE_VISUAL_GAP + COURT_LINE_VISUAL_HEIGHT + 0.004
const COURT_MARKER_Y := COURT_VISUAL_SURFACE_TOP_Y + 0.001
const SIDE_MARGIN := 0.35
const PLAYER_RUNOFF := 0.50
const FLOOR_Y := COURT_EFFECT_Y
const CHARACTER_GROUND_Y := COURT_EFFECT_Y
const PLAYER_VISUAL_FOOT_CORRECTION := 0.0
const PLAYER_VISUAL_GROUND_OFFSET := COURT_EFFECT_Y - CHARACTER_GROUND_Y - PLAYER_VISUAL_FOOT_CORRECTION
const MATCH_POINT := 21
const MATCH_CAP := 30
const AIM_HOLD_TIME := 0.75
const AI_REACTION_PHASE := 0.28
const JOYSTICK_RADIUS := 72.0
const AIM_PAD_RADIUS := 58.0

const VROID_AVATAR_SCENE := "res://characters/player/vroid/godot/test_shuttle_rush_perso.glb"
const DEFAULT_VROID_AVATAR_PROFILE := "res://data/vroid_avatars/test_shuttle_rush_perso.tres"
const DEEPMOTION_JUMP_SMASH_SCENE := "res://assets/animations/deepmotion/approved/smash.glb"
const RACKET_MODEL_SCENE := "res://characters/player/raquette01.glb"
const SHUTTLE_SCENE := "res://characters/shuttle/Volantbadminton.glb"

static func shot_profile(kind: String) -> Dictionary:
	match kind:
		"drive":
			return { "duration": 0.72, "apex": 1.95, "drag": 0.985, "gravity": 9.2, "guidance": 0.16 }
		"drop":
			return { "duration": 1.0, "apex": 1.85, "drag": 0.955, "gravity": 9.8, "guidance": 0.22 }
		"smash":
			return { "duration": 0.56, "apex": 2.0, "drag": 0.982, "gravity": 10.5, "guidance": 0.14 }
		"serve_short":
			return { "duration": 0.86, "apex": 1.82, "drag": 0.955, "gravity": 9.8, "guidance": 0.24 }
		"serve_drive":
			return { "duration": 0.84, "apex": 2.15, "drag": 0.974, "gravity": 10.2, "guidance": 0.24 }
		"serve_lob":
			return { "duration": 2.0, "apex": 4.4, "drag": 0.972, "gravity": 8.6, "guidance": 0.19 }
		_:
			return { "duration": 1.65, "apex": 4.2, "drag": 0.972, "gravity": 8.6, "guidance": 0.18 }

static func is_service_kind(kind: String) -> bool:
	return kind.begins_with("serve")

static func recovery_profile(kind: String, shot_quality: float = 0.60) -> Dictionary:
	var weak_bonus: float = clamp(0.55 - shot_quality, 0.0, 0.35)
	match kind:
		"smash":
			return { "swing_recovery_time": 0.95, "urgency_factor": 1.24 + weak_bonus, "base_offset": -0.35 }
		"drop":
			return { "swing_recovery_time": 0.34, "urgency_factor": 1.14 + weak_bonus, "base_offset": -0.48 }
		"drive", "serve_drive":
			return { "swing_recovery_time": 0.26, "urgency_factor": 1.32 + weak_bonus, "base_offset": -0.06 }
		"serve_short":
			return { "swing_recovery_time": 0.30, "urgency_factor": 1.08 + weak_bonus, "base_offset": -0.42 }
		"serve_lob":
			return { "swing_recovery_time": 0.46, "urgency_factor": 0.82 + weak_bonus * 0.5, "base_offset": 0.35 }
		"lob":
			return { "swing_recovery_time": 0.48, "urgency_factor": 0.88 + weak_bonus * 0.6, "base_offset": 0.42 }
		_:
			return { "swing_recovery_time": 0.44, "urgency_factor": 0.92 + weak_bonus * 0.6, "base_offset": 0.30 }

static func difficulty_profile(level: String) -> Dictionary:
	match level:
		"loisir":
			return {
				"label": "Loisir",
				"reach_bias": -0.35,
				"vertical_reach": 2.88,
				"net_fault_chance": 0.120,
				"out_error_chance": 0.160,
				"service_fault_chance": 0.115,
				"service_net_fault_share": 0.62,
				"service_out_fault_share": 0.30,
				"late_penalty": 0.35,
				"smash_bias": 0.10
			}
		"elite":
			return {
				"label": "Elite",
				"reach_bias": -0.02,
				"vertical_reach": 3.18,
				"net_fault_chance": 0.045,
				"out_error_chance": 0.060,
				"service_fault_chance": 0.020,
				"service_net_fault_share": 0.40,
				"service_out_fault_share": 0.58,
				"late_penalty": 0.14,
				"smash_bias": 0.01
			}
		_:
			return {
				"label": "Club",
				"reach_bias": -0.18,
				"vertical_reach": 3.02,
				"net_fault_chance": 0.075,
				"out_error_chance": 0.110,
				"service_fault_chance": 0.055,
				"service_net_fault_share": 0.52,
				"service_out_fault_share": 0.43,
				"late_penalty": 0.24,
				"smash_bias": 0.06
			}

static func material(color: Color) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.86
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.disable_receive_shadows = false
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
	return mat
