class_name ShotData
extends Resource

@export var shot_id: StringName = &""
@export var animation_name: StringName = &""
@export_range(0.0, 2.0, 0.01) var impact_time: float = 0.25
@export_range(0.0, 3.0, 0.01) var recovery_time: float = 0.45
@export_range(0.1, 2.0, 0.01) var move_speed_scale: float = 0.55
@export_range(0.0, 30.0, 0.1) var shuttle_speed: float = 12.0
@export_range(0.0, 8.0, 0.01) var shuttle_arc: float = 2.0
@export var shuttle_spin: Vector3 = Vector3.ZERO
@export var can_jump: bool = false
@export var is_attack: bool = false
@export_range(0.0, 0.12, 0.001) var hit_stop_duration: float = 0.018
@export_range(0.0, 2.0, 0.01) var feedback_intensity: float = 0.55
@export_range(0.0, 2.0, 0.01) var camera_pulse: float = 0.35
@export_range(0.0, 0.6, 0.01) var trail_boost: float = 0.15
@export_range(0.1, 2.5, 0.01) var impact_flash_scale: float = 1.0

func total_lock_time() -> float:
	return max(impact_time + recovery_time, 0.12)
