class_name AIDecisionMaker
extends RefCounted

static func choose_opponent_shot(difficulty_profile: Dictionary) -> String:
	var roll: float = randf()
	var smash_bias: float = float(difficulty_profile["smash_bias"])
	if roll < 0.46 - smash_bias:
		return "lob"
	if roll < 0.78 - smash_bias * 0.5:
		return "drop"
	return "smash"

static func choose_player_ai_shot() -> String:
	var roll: float = randf()
	if roll < 0.46:
		return "lob"
	if roll < 0.78:
		return "drop"
	return "smash"

static func choose_player_ai_service_kind() -> String:
	var roll: float = randf()
	if roll < 0.54:
		return "serve_short"
	if roll < 0.84:
		return "serve_lob"
	return "serve_drive"

static func choose_player_ai_return_shot(service_type: String) -> String:
	if service_type == "serve_short":
		var roll_short: float = randf()
		return "drop" if roll_short < 0.42 else ("drive" if roll_short < 0.68 else "lob")
	if service_type == "serve_lob":
		var roll_long: float = randf()
		return "lob" if roll_long < 0.42 else ("drop" if roll_long < 0.72 else "smash")
	return "lob" if randf() < 0.62 else "drop"

static func choose_opponent_service_kind(receiver_aggressiveness: float) -> String:
	if receiver_aggressiveness > 0.75 and randf() < 0.62:
		return "serve_drive"
	if receiver_aggressiveness < 0.35 and randf() < 0.70:
		return "serve_short"
	var roll: float = randf()
	if roll < 0.55:
		return "serve_short"
	if roll < 0.85:
		return "serve_lob"
	return "serve_drive"

static func choose_opponent_return_shot(service_type: String, receiver_aggressiveness: float) -> String:
	var reaction_time: float = randf_range(0.24, 0.58)
	if service_type == "serve_short":
		var roll_short: float = randf()
		if receiver_aggressiveness > 0.68:
			return "drop" if roll_short < 0.52 else ("drive" if roll_short < 0.86 else "lob")
		return "drop" if roll_short < 0.36 else ("drive" if roll_short < 0.60 else "lob")
	if service_type == "serve_lob":
		var roll_long: float = randf()
		return "lob" if roll_long < 0.40 else ("drop" if roll_long < 0.70 else "smash")
	if reaction_time > 0.45 or receiver_aggressiveness > 0.74:
		return "lob" if randf() < 0.70 else "drop"
	var roll_flick: float = randf()
	return "lob" if roll_flick < 0.35 else ("smash" if roll_flick < 0.70 else "drop")

static func apply_difficulty_error(kind: String, target: Vector3, active_half_width: float, difficulty_profile: Dictionary) -> Vector3:
	if GameConfig.is_service_kind(kind):
		return target
	if randf() > float(difficulty_profile["out_error_chance"]):
		return target
	var miss: Vector3 = target
	var lane_sign: float = 1.0 if miss.z >= 0.0 else -1.0
	if randf() < 0.55:
		miss.z = lane_sign * (active_half_width + randf_range(0.16, 0.55))
	else:
		var depth_sign: float = 1.0 if miss.x >= 0.0 else -1.0
		miss.x = depth_sign * (GameConfig.COURT_LENGTH * 0.5 + randf_range(0.12, 0.45))
	return miss

static func service_fault_type(kind: String, difficulty_profile: Dictionary) -> String:
	if not GameConfig.is_service_kind(kind):
		return ""
	if randf() > float(difficulty_profile["service_fault_chance"]):
		return ""
	var roll: float = randf()
	if roll < float(difficulty_profile["service_net_fault_share"]):
		return "net"
	if roll < float(difficulty_profile["service_net_fault_share"]) + float(difficulty_profile["service_out_fault_share"]):
		return "out"
	return "technique"

static func make_service_target_out(side: String, target: Vector3, service_long_limit: float, active_half_width: float) -> Vector3:
	var miss: Vector3 = target
	var depth_sign: float = 1.0 if side == "player" else -1.0
	if randf() < 0.65:
		miss.x = depth_sign * (service_long_limit + randf_range(0.18, 0.55))
	else:
		var lane_sign: float = 1.0 if miss.z >= 0.0 else -1.0
		miss.z = lane_sign * (active_half_width + randf_range(0.16, 0.45))
	return miss

static func should_force_net_fault(kind: String, difficulty_profile: Dictionary) -> bool:
	if GameConfig.is_service_kind(kind):
		return false
	if kind == "lob" or kind == "serve_lob":
		return false
	var chance: float = float(difficulty_profile["net_fault_chance"])
	if kind == "smash" or kind == "drive" or kind == "serve_drive":
		chance *= 1.25
	return randf() < chance
