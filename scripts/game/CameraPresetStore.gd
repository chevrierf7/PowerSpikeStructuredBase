class_name CameraPresetStore
extends RefCounted

static func default_presets() -> Array:
	return [
		{ "distance": 6.9, "height": 7.8, "focus": 0.45, "follow": 6.0, "follow_y": 1.0, "follow_side": 0.0, "look_z": 0.18, "follow_x": 0.0, "look_x": 0.0, "side": 0.0, "fov": 58.0 },
		{ "distance": 8.2, "height": 8.6, "focus": 0.65, "follow": 5.2, "follow_y": 0.8, "follow_side": 0.15, "look_z": 0.12, "follow_x": 0.08, "look_x": 0.18, "side": 0.0, "fov": 54.0 },
		{ "distance": 5.4, "height": 6.7, "focus": 0.35, "follow": 7.4, "follow_y": 1.0, "follow_side": 0.25, "look_z": 0.30, "follow_x": 0.12, "look_x": 0.25, "side": 0.0, "fov": 62.0 },
		{ "distance": 5.7, "height": 3.35, "focus": 1.15, "follow": 6.0, "follow_y": 0.55, "follow_side": 0.28, "look_z": 0.28, "follow_x": 0.0, "look_x": 0.12, "side": 0.0, "fov": 50.0 },
	]

static func load_presets(path: String) -> Array:
	var presets := default_presets()
	var config := ConfigFile.new()
	if config.load(path) == OK:
		for i in range(presets.size()):
			var section := "camera_%d" % [i + 1]
			var preset: Dictionary = presets[i].duplicate()
			for key in preset.keys():
				preset[key] = float(config.get_value(section, key, preset[key]))
			presets[i] = preset
	return presets

static func save_presets(path: String, selected_slot: int, presets: Array) -> void:
	var config := ConfigFile.new()
	config.set_value("camera", "selected", selected_slot)
	for i in range(presets.size()):
		var section := "camera_%d" % [i + 1]
		var preset: Dictionary = presets[i]
		for key in preset.keys():
			config.set_value(section, key, preset[key])
	config.save(path)

static func normalized(settings: Dictionary) -> Dictionary:
	var defaults: Dictionary = default_presets()[0]
	return {
		"distance": clamp(float(settings.get("distance", defaults["distance"])), 4.0, 11.0),
		"height": clamp(float(settings.get("height", defaults["height"])), 0.15, 10.5),
		"focus": clamp(float(settings.get("focus", defaults["focus"])), 0.1, 2.4),
		"follow": clamp(float(settings.get("follow", defaults["follow"])), 0.0, 12.0),
		"follow_y": clamp(float(settings.get("follow_y", defaults["follow_y"])), 0.0, 1.0),
		"follow_side": clamp(float(settings.get("follow_side", defaults["follow_side"])), 0.0, 1.0),
		"look_z": clamp(float(settings.get("look_z", settings.get("follow_side", defaults["look_z"]))), 0.0, 1.0),
		"follow_x": clamp(float(settings.get("follow_x", defaults["follow_x"])), 0.0, 1.0),
		"look_x": clamp(float(settings.get("look_x", settings.get("follow_x", defaults["look_x"]))), 0.0, 1.0),
		"side": clamp(float(settings.get("side", defaults["side"])), -3.0, 3.0),
		"fov": clamp(float(settings.get("fov", defaults["fov"])), 38.0, 74.0),
	}
