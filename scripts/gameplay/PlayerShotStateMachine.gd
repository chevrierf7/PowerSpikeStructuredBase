class_name PlayerShotStateMachine
extends RefCounted

signal state_changed(state_name: StringName)
signal shot_impact(shot_data: ShotData)
signal recovery_start(shot_data: ShotData)
signal recovery_end(shot_data: ShotData)

enum State {
	IDLE,
	MOVE,
	PREPARE_SHOT,
	SWING,
	IMPACT,
	RECOVERY,
	REPOSITION
}

var state: State = State.IDLE
var active_shot: ShotData = null
var elapsed: float = 0.0
var impact_sent: bool = false
var recovery_sent: bool = false

func start_shot(shot_data: ShotData) -> void:
	active_shot = shot_data
	elapsed = 0.0
	impact_sent = false
	recovery_sent = false
	_set_state(State.PREPARE_SHOT)

func update(delta: float) -> void:
	if active_shot == null:
		return
	elapsed += delta
	if state == State.PREPARE_SHOT and elapsed > 0.04:
		_set_state(State.SWING)
	if not impact_sent and elapsed >= active_shot.impact_time:
		impact_sent = true
		_set_state(State.IMPACT)
		shot_impact.emit(active_shot)
	if impact_sent and not recovery_sent:
		recovery_sent = true
		_set_state(State.RECOVERY)
		recovery_start.emit(active_shot)
	if elapsed >= active_shot.total_lock_time():
		_set_state(State.REPOSITION)
		recovery_end.emit(active_shot)
		active_shot = null
		_set_state(State.IDLE)

func force_idle() -> void:
	active_shot = null
	elapsed = 0.0
	impact_sent = false
	recovery_sent = false
	_set_state(State.IDLE)

func is_busy() -> bool:
	return active_shot != null

func state_name() -> StringName:
	match state:
		State.IDLE:
			return &"Idle"
		State.MOVE:
			return &"Move"
		State.PREPARE_SHOT:
			return &"PrepareShot"
		State.SWING:
			return &"Swing"
		State.IMPACT:
			return &"Impact"
		State.RECOVERY:
			return &"Recovery"
		State.REPOSITION:
			return &"Reposition"
	return &"Idle"

func _set_state(next_state: State) -> void:
	if state == next_state:
		return
	state = next_state
	state_changed.emit(state_name())
