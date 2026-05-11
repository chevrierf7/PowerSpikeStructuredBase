extends Node

const DEFAULT_PLAYER_1 := "res://data/players/kai.tres"
const DEFAULT_PLAYER_2 := "res://data/players/akiro.tres"

var player_1_profile: PlayerProfile
var player_2_profile: PlayerProfile
var match_mode := "singles"
var is_ai_match := false

func _ready() -> void:
	_ensure_fallbacks()

func set_player_1(profile: PlayerProfile) -> void:
	player_1_profile = _fallback_profile(profile, DEFAULT_PLAYER_1)

func set_player_2(profile: PlayerProfile) -> void:
	player_2_profile = _fallback_profile(profile, DEFAULT_PLAYER_2)

func set_players(p1: PlayerProfile, p2: PlayerProfile) -> void:
	set_player_1(p1)
	set_player_2(p2)

func get_player_1() -> PlayerProfile:
	_ensure_fallbacks()
	return player_1_profile

func get_player_2() -> PlayerProfile:
	_ensure_fallbacks()
	return player_2_profile

func _ensure_fallbacks() -> void:
	player_1_profile = _fallback_profile(player_1_profile, DEFAULT_PLAYER_1)
	player_2_profile = _fallback_profile(player_2_profile, DEFAULT_PLAYER_2)

func _fallback_profile(profile: PlayerProfile, path: String) -> PlayerProfile:
	if profile != null:
		return profile
	var loaded := load(path)
	if loaded is PlayerProfile:
		return loaded
	return PlayerProfile.new()
