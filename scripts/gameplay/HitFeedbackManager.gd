class_name HitFeedbackManager
extends Node

@export_range(0.0, 0.12, 0.001) var hit_stop_duration: float = 0.018
@export_range(0.0, 2.0, 0.01) var hit_flash_intensity: float = 0.55
@export_range(0.0, 2.0, 0.01) var camera_shake_intensity: float = 0.35
@export var sound_variant: String = "default"
@export_range(0.0, 0.6, 0.01) var trail_boost_duration: float = 0.15
@export var hit_stop_time_scale: float = 0.10
@export var hit_stop_enabled: bool = true

var hit_stop_active: bool = false
var hit_stop_restore_token: int = 0
var strongest_hit_stop_until: float = 0.0
var last_time_scale_before_hit_stop: float = 1.0

func _exit_tree() -> void:
	if hit_stop_active:
		Engine.time_scale = last_time_scale_before_hit_stop

func play_hit_feedback(shot_data: ShotData, impact_position: Vector3, hitter_side: String) -> void:
	if shot_data == null:
		return
	var settings: Dictionary = _settings_for_shot(shot_data)
	var intensity: float = float(settings["feedback_intensity"])
	_call_game_method("play_impact_sound", [String(shot_data.shot_id), intensity, hitter_side, String(settings["sound_variant"])])
	_call_game_method("play_impact_flash", [impact_position, intensity * float(settings["impact_flash_scale"]), String(shot_data.shot_id)])
	_call_game_method("boost_shuttle_trail", [float(settings["trail_boost_duration"]), intensity])
	_call_game_method("apply_camera_pulse", [float(settings["camera_shake_intensity"]), impact_position, hitter_side])
	_call_game_method("show_hit_feedback_debug", [String(shot_data.shot_id), float(settings["hit_stop_duration"]), intensity])
	_play_hit_stop(float(settings["hit_stop_duration"]))

func _settings_for_shot(shot_data: ShotData) -> Dictionary:
	var shot_id: String = String(shot_data.shot_id)
	var settings: Dictionary = {
		"hit_stop_duration": shot_data.hit_stop_duration if shot_data.hit_stop_duration >= 0.0 else hit_stop_duration,
		"feedback_intensity": max(shot_data.feedback_intensity, hit_flash_intensity),
		"camera_shake_intensity": max(shot_data.camera_pulse, camera_shake_intensity),
		"sound_variant": sound_variant,
		"trail_boost_duration": max(shot_data.trail_boost, trail_boost_duration),
		"impact_flash_scale": max(shot_data.impact_flash_scale, 0.1)
	}
	match shot_id:
		"jump_smash":
			settings.merge({ "hit_stop_duration": max(float(settings["hit_stop_duration"]), 0.050), "feedback_intensity": max(float(settings["feedback_intensity"]), 1.10), "camera_shake_intensity": max(float(settings["camera_shake_intensity"]), 1.10), "trail_boost_duration": max(float(settings["trail_boost_duration"]), 0.28), "sound_variant": "smash" }, true)
		"smash_forehand":
			settings.merge({ "hit_stop_duration": max(float(settings["hit_stop_duration"]), 0.045), "feedback_intensity": max(float(settings["feedback_intensity"]), 1.0), "camera_shake_intensity": max(float(settings["camera_shake_intensity"]), 1.0), "trail_boost_duration": max(float(settings["trail_boost_duration"]), 0.25), "sound_variant": "smash" }, true)
		"drive_forehand":
			settings.merge({ "hit_stop_duration": max(float(settings["hit_stop_duration"]), 0.025), "feedback_intensity": max(float(settings["feedback_intensity"]), 0.72), "camera_shake_intensity": max(float(settings["camera_shake_intensity"]), 0.62), "trail_boost_duration": max(float(settings["trail_boost_duration"]), 0.18), "sound_variant": "drive" }, true)
		"clear_forehand":
			settings.merge({ "hit_stop_duration": max(float(settings["hit_stop_duration"]), 0.018), "feedback_intensity": max(float(settings["feedback_intensity"]), 0.55), "camera_shake_intensity": max(float(settings["camera_shake_intensity"]), 0.34), "trail_boost_duration": max(float(settings["trail_boost_duration"]), 0.15), "sound_variant": "clear" }, true)
		"net_shot":
			settings.merge({ "hit_stop_duration": min(max(float(settings["hit_stop_duration"]), 0.006), 0.010), "feedback_intensity": min(max(float(settings["feedback_intensity"]), 0.30), 0.45), "camera_shake_intensity": min(max(float(settings["camera_shake_intensity"]), 0.12), 0.22), "trail_boost_duration": max(float(settings["trail_boost_duration"]), 0.08), "sound_variant": "net" }, true)
		"defense_block":
			settings.merge({ "hit_stop_duration": max(float(settings["hit_stop_duration"]), 0.020), "feedback_intensity": max(float(settings["feedback_intensity"]), 0.62), "camera_shake_intensity": max(float(settings["camera_shake_intensity"]), 0.48), "trail_boost_duration": max(float(settings["trail_boost_duration"]), 0.12), "sound_variant": "defense" }, true)
	return settings

func _play_hit_stop(duration: float) -> void:
	if not hit_stop_enabled or duration <= 0.001:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if hit_stop_active and now < strongest_hit_stop_until:
		return
	hit_stop_active = true
	hit_stop_restore_token += 1
	var token: int = hit_stop_restore_token
	var previous_scale: float = Engine.time_scale
	last_time_scale_before_hit_stop = previous_scale
	strongest_hit_stop_until = now + duration
	Engine.time_scale = min(previous_scale, hit_stop_time_scale)
	_restore_hit_stop_after(duration, previous_scale, token)

func _restore_hit_stop_after(duration: float, previous_scale: float, token: int) -> void:
	await get_tree().create_timer(duration, true, false, true).timeout
	if token != hit_stop_restore_token:
		return
	Engine.time_scale = previous_scale
	hit_stop_active = false

func _call_game_method(method_name: String, args: Array) -> void:
	var game_node: Node = get_parent()
	if game_node != null and game_node.has_method(method_name):
		game_node.callv(method_name, args)
