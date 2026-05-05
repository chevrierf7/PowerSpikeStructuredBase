class_name MatchState
extends RefCounted

var mode := "singles"
var rally_active := false
var turn_side := "player"
var server_side := "player"
var last_hitter_side := "player"
var last_shot_kind := ""
var shuttle_landing_side := ""
var rally_count := 0
var player_score := 0
var opponent_score := 0
var player_sets := 0
var opponent_sets := 0
var set_over := false
var match_over := false

func active_half_width() -> float:
	return (GameConfig.COURT_WIDTH if mode == "doubles" else GameConfig.SINGLES_WIDTH) * 0.5

func movement_half_width() -> float:
	return GameConfig.COURT_WIDTH * 0.5 + GameConfig.PLAYER_RUNOFF

func toggle_mode() -> void:
	mode = "doubles" if mode == "singles" else "singles"

func service_long_limit() -> float:
	return GameConfig.DOUBLES_LONG_SERVICE_DISTANCE if mode == "doubles" else GameConfig.COURT_LENGTH * 0.5

func service_target_x(attacking_positive: bool, kind: String) -> float:
	var long_limit: float = service_long_limit()
	var distance: float = long_limit - 0.72
	if kind == "serve_short":
		distance = GameConfig.SHORT_SERVICE_DISTANCE + 0.22
	elif kind == "serve_drive":
		distance = long_limit - 1.40
	return distance if attacking_positive else -distance

func service_server_lane(side: String) -> float:
	var score: int = player_score if side == "player" else opponent_score
	return _service_lane_from_score(score)

func service_receiver_lane(server: String) -> float:
	var score: int = player_score if server == "player" else opponent_score
	return -_service_lane_from_score(score)

func service_target_lane(side: String) -> float:
	var target_lane: float = service_receiver_lane(side) + randf_range(-0.14, 0.14)
	return clamp(target_lane, -active_half_width() + 0.55, active_half_width() - 0.55)

func pre_serve_lane_for_side(side: String) -> float:
	if side == server_side:
		return service_server_lane(side)
	return service_receiver_lane(server_side)

func pre_serve_position_for_side(side: String) -> Vector3:
	var lane: float = pre_serve_lane_for_side(side)
	var side_sign: float = -1.0 if side == "player" else 1.0
	var distance: float = GameConfig.SHORT_SERVICE_DISTANCE + 0.72
	if side != server_side:
		distance = GameConfig.SHORT_SERVICE_DISTANCE + 0.38
	return Vector3(side_sign * distance, GameConfig.CHARACTER_GROUND_Y, clamp(lane, lane_min(lane), lane_max(lane)))

func service_zone_name_for_side(side: String) -> String:
	return "service_right" if service_server_lane(side) > 0.0 else "service_left"

func receive_zone_name_for_server(side: String) -> String:
	return "receive_right" if service_receiver_lane(side) > 0.0 else "receive_left"

func _service_lane_from_score(score: int) -> float:
	var lane_sign: float = 1.0 if score % 2 == 0 else -1.0
	return lane_sign * min(0.62, active_half_width() * 0.30)

func lane_min(lane: float) -> float:
	return 0.12 if lane > 0.0 else -active_half_width() + 0.25

func lane_max(lane: float) -> float:
	return active_half_width() - 0.25 if lane > 0.0 else -0.12

func is_out(target: Vector3, receiving_side: String, kind: String) -> bool:
	var tolerance: float = 0.18
	var inside_z: bool = abs(target.z) <= active_half_width() + tolerance
	if GameConfig.is_service_kind(kind):
		var distance_from_net: float = abs(target.x)
		var inside_service_depth: bool = distance_from_net >= GameConfig.SHORT_SERVICE_DISTANCE - tolerance and distance_from_net <= service_long_limit() + tolerance
		var on_receiver_side: bool = target.x <= -GameConfig.SIDE_MARGIN if receiving_side == "player" else target.x >= GameConfig.SIDE_MARGIN
		var diagonal_ok: bool = is_correct_service_diagonal(target, last_hitter_side)
		return not (on_receiver_side and inside_service_depth and inside_z and diagonal_ok)
	var inside_x: bool = target.x <= -GameConfig.SIDE_MARGIN if receiving_side == "player" else target.x >= GameConfig.SIDE_MARGIN
	return not (inside_x and inside_z)

func is_correct_service_diagonal(target: Vector3, server: String) -> bool:
	var server_lane: float = service_server_lane(server)
	if abs(target.z) < 0.12:
		return false
	return sign(target.z) == -sign(server_lane)

func award_point(winner: String) -> String:
	rally_active = false
	turn_side = winner
	server_side = winner
	if winner == "player":
		player_score += 1
	else:
		opponent_score += 1
	var set_winner: String = get_set_winner()
	if set_winner != "":
		set_over = true
		if set_winner == "player":
			player_sets += 1
		else:
			opponent_sets += 1
		match_over = player_sets >= 2 or opponent_sets >= 2
		return set_winner
	return ""

func start_next_set() -> void:
	player_score = 0
	opponent_score = 0
	rally_count = 0
	set_over = false
	server_side = "player" if (player_sets + opponent_sets) % 2 == 0 else "opponent"
	turn_side = server_side

func get_set_winner() -> String:
	var high: int = max(player_score, opponent_score)
	var low: int = min(player_score, opponent_score)
	if (high >= GameConfig.MATCH_POINT and high - low >= 2) or high == GameConfig.MATCH_CAP:
		return "player" if player_score > opponent_score else "opponent"
	return ""
