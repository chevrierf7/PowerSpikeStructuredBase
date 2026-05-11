class_name ShotDatabase
extends RefCounted

const SHOT_DIR := "res://data/shots/"

static func data_for_gameplay_kind(kind: String, backhand: bool = false) -> ShotData:
	var shot_id: String = id_for_gameplay_kind(kind, backhand)
	return load_shot(shot_id)

static func id_for_gameplay_kind(kind: String, backhand: bool = false) -> String:
	if backhand:
		match kind:
			"serve_drive":
				return "serve_drive"
			"drive":
				return "drive_forehand"
			"smash":
				return "jump_smash"
			"serve_short":
				return "serve_short"
			"drop":
				return "net_shot"
			"serve_lob":
				return "serve_lob"
			"lob":
				return "clear_forehand"
	match kind:
		"smash":
			return "jump_smash"
		"serve_drive":
			return "serve_drive"
		"drive":
			return "drive_forehand"
		"serve_short":
			return "serve_short"
		"drop":
			return "net_shot"
		"lift":
			return "lift_forehand"
		"defense", "block":
			return "defense_block"
		"serve_lob":
			return "serve_lob"
		"lob":
			return "clear_forehand"
		_:
			return "clear_forehand"

static func load_shot(shot_id: String) -> ShotData:
	var path: String = "%s%s.tres" % [SHOT_DIR, shot_id]
	if ResourceLoader.exists(path):
		var resource: Resource = load(path)
		if resource is ShotData:
			return resource as ShotData
	var fallback: ShotData = ShotData.new()
	fallback.shot_id = StringName(shot_id)
	fallback.animation_name = StringName(shot_id)
	return fallback
