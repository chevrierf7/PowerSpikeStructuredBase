class_name StatsRecorder
extends RefCounted

const USER_STATS_PATH := "user://ai_match_stats.csv"
const PROJECT_STATS_PATH := "res://stats/ai_match_stats.csv"

static func record_point(row: Dictionary) -> bool:
	var user_saved := _store_stats_line(USER_STATS_PATH, row)
	var project_saved := _store_stats_line(PROJECT_STATS_PATH, row)
	return user_saved or project_saved

static func _store_stats_line(path: String, row: Dictionary) -> bool:
	if path.begins_with("res://"):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var needs_header: bool = not FileAccess.file_exists(path)
	var file := FileAccess.open(path, FileAccess.WRITE if needs_header else FileAccess.READ_WRITE)
	if file == null:
		return false
	file.seek_end()
	if needs_header:
		file.store_csv_line([
			"timestamp",
			"difficulty",
			"mode",
			"server",
			"service",
			"winner",
			"reason",
			"hits",
			"duration_s",
			"last_hitter",
			"last_shot",
			"score_kai_before",
			"score_mina_before",
			"sets_kai",
			"sets_mina"
		])
	file.store_csv_line([
		String(row.get("timestamp", "")),
		String(row.get("difficulty", "")),
		String(row.get("mode", "")),
		String(row.get("server", "")),
		String(row.get("service", "")),
		String(row.get("winner", "")),
		String(row.get("reason", "")),
		str(row.get("hits", 0)),
		String(row.get("duration_s", "")),
		String(row.get("last_hitter", "")),
		String(row.get("last_shot", "")),
		str(row.get("score_kai_before", 0)),
		str(row.get("score_mina_before", 0)),
		str(row.get("sets_kai", 0)),
		str(row.get("sets_mina", 0))
	])
	file.close()
	return true
