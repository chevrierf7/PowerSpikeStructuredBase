class_name HitSfx
extends Node

const BUS_NAME := "SFX"
const DEFAULT_KIND := "drive"
const POOL_SIZE := 8
const MIN_REPEAT_GAP := 0.045
const BASE_VOLUME_DB := -1.5

var streams := {}
var sound_gain := {
	"clear": 1.125,
	"service": 0.75
}
var players: Array[AudioStreamPlayer] = []
var next_player_index := 0
var last_played_at := {}

func _ready() -> void:
	_ensure_sfx_bus()
	_load_streams()
	for i in range(POOL_SIZE):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = BUS_NAME
		add_child(player)
		players.append(player)

func set_sfx_volume(value: float) -> void:
	_ensure_sfx_bus()
	var bus_index: int = AudioServer.get_bus_index(BUS_NAME)
	if bus_index < 0:
		return
	var linear_volume: float = clamp(value, 0.0, 1.0)
	AudioServer.set_bus_mute(bus_index, linear_volume <= 0.001)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(max(linear_volume, 0.001)))

func play_shot(kind: String) -> void:
	_play_kind(_sound_key_for_kind(kind))

func play_miss() -> void:
	_play_kind("miss")

func _play_kind(key: String) -> void:
	if players.is_empty():
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - float(last_played_at.get(key, -10.0)) < MIN_REPEAT_GAP:
		return
	last_played_at[key] = now
	var stream: AudioStream = streams.get(key, null) as AudioStream
	if stream == null:
		stream = streams.get(DEFAULT_KIND, null) as AudioStream
	if stream == null:
		return
	var player: AudioStreamPlayer = players[next_player_index]
	next_player_index = (next_player_index + 1) % players.size()
	player.stream = stream
	player.pitch_scale = randf_range(0.96, 1.04)
	var gain: float = float(sound_gain.get(key, 1.0))
	player.volume_db = BASE_VOLUME_DB + linear_to_db(gain * randf_range(0.92, 1.08))
	player.play()

func _load_streams() -> void:
	_try_load_stream("drop", "res://assets/sound/amortie.mp3")
	_try_load_stream("clear", "res://assets/sound/amortie.mp3")
	_try_load_stream("drive", "res://assets/sound/tendu.mp3")
	_try_load_stream("smash", "res://assets/sound/smatch.mp3")
	_try_load_stream("service", "res://assets/sound/service.mp3")
	_try_load_stream("miss", "res://assets/sound/rater.mp3")

func _try_load_stream(key: String, path: String) -> void:
	var loaded: Resource = load(path)
	if loaded is AudioStream:
		streams[key] = loaded

func _sound_key_for_kind(kind: String) -> String:
	match kind:
		"serve_short":
			return "drop"
		"serve_lob":
			return "clear"
		"serve_drive":
			return "drive"
		"drop":
			return "drop"
		"lob":
			return "clear"
		"drive":
			return "drive"
		"smash":
			return "smash"
		_:
			return DEFAULT_KIND

func _ensure_sfx_bus() -> void:
	if AudioServer.get_bus_index(BUS_NAME) >= 0:
		return
	AudioServer.add_bus()
	var bus_index: int = AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(bus_index, BUS_NAME)
	AudioServer.set_bus_send(bus_index, "Master")
