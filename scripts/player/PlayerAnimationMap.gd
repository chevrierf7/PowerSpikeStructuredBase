class_name PlayerAnimationMap
extends RefCounted

static func movement_state_from_input(input: Vector2, court_forward_x: float, court_right_z: float) -> String:
	var forward_amount: float = input.x * court_forward_x
	var right_amount: float = input.y * court_right_z
	if abs(right_amount) > abs(forward_amount) + 0.15:
		return "move_right" if right_amount > 0.0 else "move_left"
	if abs(forward_amount) > 0.1:
		return "move_forward" if forward_amount > 0.0 else "move_backward"
	return "run"

static func hit_state_from_kind(kind: String, backhand: bool = false) -> String:
	if backhand:
		match kind:
			"drop":
				return "backhand_high_drop"
			"smash", "lob":
				return "backhand_high_clear"
			"drive", "serve_drive":
				return "backhand_drive"
			_:
				return "backhand_high_clear"
	match kind:
		"serve_short":
			return "serve_short"
		"serve_drive":
			return "serve_drive"
		"serve_lob":
			return "serve_long"
		"drop":
			return "forehand_high_drop"
		"smash":
			return "forehand_high_smash"
		"drive":
			return "forehand_drive"
		"backhand_drop":
			return "backhand_high_drop"
		"backhand_clear":
			return "backhand_high_clear"
		"backhand_drive":
			return "backhand_drive"
		_:
			return "forehand_high_clear"

static func build_animation_names(animations: PackedStringArray) -> Dictionary:
	var names := {
		"idle": _pick_animation(animations, ["idle", "idle_wait", "attente", "stand", "wait"]),
		"run": _pick_animation(animations, ["run", "running", "walk", "move_forward"]),
		"move_forward": _pick_animation(animations, ["move_forward", "running", "run"]),
		"move_backward": _pick_animation(animations, ["move_backward", "run", "running"]),
		"move_left": _pick_animation(animations, ["move_left", "run", "running"]),
		"move_right": _pick_animation(animations, ["move_right", "run", "running"]),
		"serve_short": _pick_animation(animations, ["serve_short", "service court", "hit"]),
		"serve_long": _pick_animation(animations, ["serve_long", "service long", "hit"]),
		"forehand_low_drop_block": _pick_animation(animations, ["forehand_low_drop_block", "amorti", "drop", "hit"]),
		"forehand_low_lift_clear": _pick_animation(animations, ["forehand_low_lift_clear", "lift", "clear", "hit"]),
		"forehand_drive": _pick_animation(animations, ["forehand_drive", "drive", "tendu", "hit"]),
		"forehand_high_drop": _pick_animation(animations, ["forehand_high_drop", "amorti", "drop", "hit"]),
		"forehand_high_clear": _pick_animation(animations, ["forehand_high_clear", "degage", "clear", "hit", "coup"]),
		"forehand_high_smash": _pick_animation(animations, ["forehand_high_smash", "smash", "tendu"]),
		"jump_smash": _pick_animation(animations, ["jump_smash", "jump smash", "smash saute", "smash"]),
		"backhand_low_drop_block": _pick_animation(animations, ["backhand_low_drop_block", "backhand", "revers", "hit"]),
		"backhand_low_lift": _pick_animation(animations, ["backhand_low_lift", "backhand", "revers", "hit"]),
		"backhand_drive": _pick_animation(animations, ["backhand_drive", "backhand", "revers", "hit"]),
		"backhand_high_drop": _pick_animation(animations, ["backhand_high_drop", "backhand", "revers", "hit"]),
		"backhand_high_clear": _pick_animation(animations, ["backhand_high_clear", "backhand", "revers", "hit"]),
	}
	names["idle_ready"] = names["idle"]
	names["move_side"] = names["move_right"] if not String(names["move_right"]).is_empty() else names["move_left"]
	names["clear_forehand"] = names["forehand_high_clear"]
	names["smash_forehand"] = names["forehand_high_smash"]
	names["drive_forehand"] = names["forehand_drive"]
	names["net_shot"] = names["forehand_high_drop"]
	names["lift_forehand"] = names["forehand_low_lift_clear"]
	names["defense_block"] = names["forehand_low_drop_block"]
	names["recovery"] = names["idle"]
	if String(names["idle"]).is_empty():
		names["idle"] = animations[0]
	for state in names.keys():
		if String(names[state]).is_empty():
			names[state] = names["idle"]
	return names

static func _pick_animation(animations: PackedStringArray, keywords: Array[String]) -> String:
	for keyword in keywords:
		for animation_name in animations:
			if String(animation_name).to_lower().contains(keyword):
				return String(animation_name)
	return ""
