extends Node3D

const APPROVED_DIR := "res://assets/animations/deepmotion/approved"
const PROFILE_DIR := "res://data/animations/deepmotion"
const DEFAULT_AVATAR_PROFILE := "res://data/players/akiro.tres"
const PREVIEW_CLIP := "deepmotion_jump_smash"

var player: PlayerCharacter
var current_source_path := ""
var current_saved_scene_path := ""
var root_yaw_offset_degrees := 0.0
var status_label := Label.new()
var file_label := Label.new()
var yaw_label := Label.new()
var file_dialog := FileDialog.new()
var name_edit := LineEdit.new()
var replay_timer := Timer.new()


func _ready() -> void:
	_build_world()
	_build_ui()
	replay_timer.one_shot = true
	replay_timer.timeout.connect(_replay)
	add_child(replay_timer)
	get_viewport().files_dropped.connect(_on_files_dropped)
	_update_labels("Depose un .glb DeepMotion ou clique Ouvrir.")
	_load_startup_animation.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_O:
				file_dialog.popup_centered_ratio(0.72)
			KEY_SPACE:
				_replay()
			KEY_Q:
				_adjust_yaw(-15.0)
			KEY_E:
				_adjust_yaw(15.0)
			KEY_A:
				_adjust_yaw(-90.0)
			KEY_D:
				_adjust_yaw(90.0)
			KEY_S:
				_save_current_animation()


func _build_world() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.015, 0.018, 0.026)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.80, 0.90)
	environment.ambient_light_energy = 0.75
	world.environment = environment
	add_child(world)
	_add_scene_or_builder("res://scenes/environment/Gym_JP_A.tscn", GymBuilder.new())
	_add_scene_or_builder("res://scenes/court/Court.tscn", CourtBuilder.new())
	player = PlayerCharacter.new()
	player.name = "AnimationLabPlayer"
	player.display_name = "AnimationLabPlayer"
	player.position = Vector3(-2.8, 0.0, 0.45)
	player.rotation_degrees.y = -82.0
	player.lock_visual_yaw = false
	player.use_deepmotion_jump_smash = true
	var profile := load(DEFAULT_AVATAR_PROFILE)
	if profile is PlayerProfile:
		var player_profile := profile as PlayerProfile
		if player_profile.vroid_avatar_profile != null:
			player.vroid_avatar_profile = player_profile.vroid_avatar_profile
	add_child(player)
	var shuttle := Shuttle.new()
	shuttle.position = Vector3(-1.9, 2.4, 0.3)
	add_child(shuttle)
	var camera := Camera3D.new()
	camera.current = true
	camera.fov = 42.0
	add_child(camera)
	camera.look_at_from_position(Vector3(-5.65, 2.9, -3.8), Vector3(-2.6, 1.4, 0.45), Vector3.UP)
	var light := DirectionalLight3D.new()
	light.light_energy = 0.95
	light.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	add_child(light)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := Panel.new()
	panel.position = Vector2(18, 18)
	panel.size = Vector2(460, 218)
	layer.add_child(panel)
	var title := Label.new()
	title.text = "Atelier animations DeepMotion"
	title.position = Vector2(16, 12)
	title.size = Vector2(420, 26)
	title.add_theme_font_size_override("font_size", 22)
	panel.add_child(title)
	file_label.position = Vector2(16, 44)
	file_label.size = Vector2(424, 24)
	panel.add_child(file_label)
	yaw_label.position = Vector2(16, 70)
	yaw_label.size = Vector2(424, 24)
	panel.add_child(yaw_label)
	status_label.position = Vector2(16, 96)
	status_label.size = Vector2(424, 44)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(status_label)
	name_edit.position = Vector2(16, 148)
	name_edit.size = Vector2(212, 32)
	name_edit.placeholder_text = "nom sauvegarde"
	panel.add_child(name_edit)
	var open_button := _button("Ouvrir GLB", Vector2(244, 146), _open_file_dialog)
	panel.add_child(open_button)
	var replay_button := _button("Rejouer", Vector2(344, 146), _replay)
	panel.add_child(replay_button)
	var yaw_minus := _button("-90", Vector2(16, 184), func() -> void: _adjust_yaw(-90.0))
	panel.add_child(yaw_minus)
	var yaw_small_minus := _button("-15", Vector2(78, 184), func() -> void: _adjust_yaw(-15.0))
	panel.add_child(yaw_small_minus)
	var yaw_small_plus := _button("+15", Vector2(140, 184), func() -> void: _adjust_yaw(15.0))
	panel.add_child(yaw_small_plus)
	var yaw_plus := _button("+90", Vector2(202, 184), func() -> void: _adjust_yaw(90.0))
	panel.add_child(yaw_plus)
	var save_button := _button("Valider", Vector2(306, 184), _save_current_animation)
	save_button.size = Vector2(120, 28)
	panel.add_child(save_button)
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = PackedStringArray(["*.glb ; GLB", "*.gltf ; GLTF"])
	file_dialog.file_selected.connect(_load_animation_file)
	layer.add_child(file_dialog)


func _button(text: String, pos: Vector2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = pos
	button.size = Vector2(84, 28)
	button.pressed.connect(callback)
	return button


func _open_file_dialog() -> void:
	file_dialog.popup_centered_ratio(0.72)


func _on_files_dropped(files: PackedStringArray) -> void:
	for path in files:
		if path.to_lower().ends_with(".glb") or path.to_lower().ends_with(".gltf"):
			_load_animation_file(path)
			return
	_update_labels("Aucun .glb/.gltf trouve dans le depot.")


func _load_animation_file(path: String) -> void:
	current_source_path = path
	current_saved_scene_path = _ensure_scene_inside_project(path)
	if current_saved_scene_path.is_empty():
		_update_labels("Impossible de copier ou charger ce fichier.")
		return
	if name_edit.text.strip_edges().is_empty():
		name_edit.text = _slug_from_path(path)
	_rebuild_player_with_animation()


func _load_startup_animation() -> void:
	var startup_path := OS.get_environment("CODEX_LAB_ANIMATION")
	if startup_path.is_empty():
		return
	var yaw_text := OS.get_environment("CODEX_LAB_YAW")
	if not yaw_text.is_empty():
		root_yaw_offset_degrees = float(yaw_text)
	_load_animation_file(startup_path)
	var capture_path := OS.get_environment("CODEX_LAB_CAPTURE")
	if capture_path.is_empty():
		return
	var capture_time_text := OS.get_environment("CODEX_LAB_CAPTURE_TIME")
	if not capture_time_text.is_empty():
		await get_tree().create_timer(0.2).timeout
		_seek_preview(float(capture_time_text))
	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	var image := get_tree().root.get_texture().get_image()
	if image != null:
		var error := image.save_png(capture_path)
		print("Animation lab capture: %s (%s)" % [capture_path, error])
	get_tree().quit()


func _ensure_scene_inside_project(path: String) -> String:
	if path.begins_with("res://"):
		return path
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(APPROVED_DIR))
	var target_path := "%s/%s" % [ProjectSettings.globalize_path(APPROVED_DIR), path.get_file()]
	var error := DirAccess.copy_absolute(path, target_path)
	if error != OK:
		push_warning("Copie impossible: %s -> %s (%s)" % [path, target_path, error])
		return ""
	return ProjectSettings.localize_path(target_path)


func _rebuild_player_with_animation() -> void:
	var profile_resource := load(DEFAULT_AVATAR_PROFILE)
	if not (profile_resource is PlayerProfile):
		_update_labels("Profil AKIRO introuvable.")
		return
	var player_profile := profile_resource as PlayerProfile
	if player_profile.vroid_avatar_profile == null:
		_update_labels("Profil VRoid AKIRO introuvable.")
		return
	var avatar_profile := player_profile.vroid_avatar_profile.duplicate(true) as VroidAvatarProfile
	avatar_profile.jump_smash_animation_scene = current_saved_scene_path
	avatar_profile.deepmotion_root_yaw_offset_degrees = root_yaw_offset_degrees
	player.set_vroid_avatar_profile(avatar_profile)
	_replay_after_rebuild.call_deferred()
	_update_labels("Animation chargee. Ajuste l'orientation puis valide.")


func _replay_after_rebuild() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_replay()


func _replay() -> void:
	if player == null or current_saved_scene_path.is_empty():
		return
	var real_player := player.real_animation_player
	if real_player != null and real_player.has_animation(PREVIEW_CLIP):
		var animation := real_player.get_animation(PREVIEW_CLIP)
		if animation != null:
			animation.loop_mode = Animation.LOOP_NONE
		if player.animation_player != null and player.animation_player != real_player:
			player.animation_player.stop()
		player.is_hitting = true
		player.current_state = "animation_lab_preview"
		real_player.stop()
		real_player.speed_scale = 0.82
		real_player.play(PREVIEW_CLIP)
		real_player.seek(0.0, true)
		var length := animation.length if animation != null else 2.7
		replay_timer.start(max(length / max(real_player.speed_scale, 0.1) + 0.45, 1.0))
		_update_labels("Lecture en boucle. Ajuste l'orientation puis valide.")
		return
	player.finish_hit()
	await get_tree().process_frame
	player.play_hit("smash", false, 3.0, &"jump_smash")


func _seek_preview(time_seconds: float) -> void:
	if player == null:
		return
	var real_player := player.real_animation_player
	if real_player == null or not real_player.has_animation(PREVIEW_CLIP):
		return
	real_player.play(PREVIEW_CLIP)
	real_player.seek(max(time_seconds, 0.0), true)
	real_player.speed_scale = 0.0


func _adjust_yaw(delta_degrees: float) -> void:
	root_yaw_offset_degrees = wrapf(root_yaw_offset_degrees + delta_degrees, -180.0, 180.0)
	if not current_saved_scene_path.is_empty():
		_rebuild_player_with_animation()
	else:
		_update_labels("Orientation preparee. Charge une animation.")


func _save_current_animation() -> void:
	if current_saved_scene_path.is_empty():
		_update_labels("Charge une animation avant de valider.")
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PROFILE_DIR))
	var id := _slug_from_text(name_edit.text)
	if id.is_empty():
		id = _slug_from_path(current_saved_scene_path)
	var profile := DeepMotionAnimationProfile.new()
	profile.id = id
	profile.display_name = id.capitalize()
	profile.animation_scene = current_saved_scene_path
	profile.root_yaw_offset_degrees = root_yaw_offset_degrees
	profile.approved_for_game = true
	var save_path := "%s/%s.tres" % [PROFILE_DIR, id]
	var error := ResourceSaver.save(profile, save_path)
	if error == OK:
		_update_labels("Sauvegarde OK: %s" % save_path)
	else:
		_update_labels("Sauvegarde impossible: %s" % error)


func _update_labels(status: String) -> void:
	file_label.text = "Fichier: %s" % (current_saved_scene_path if not current_saved_scene_path.is_empty() else "-")
	yaw_label.text = "Correction animation: %.0f deg" % root_yaw_offset_degrees
	status_label.text = status


func _slug_from_path(path: String) -> String:
	return _slug_from_text(path.get_file().get_basename())


func _slug_from_text(text: String) -> String:
	var slug := text.strip_edges().to_lower()
	for character in [" ", ".", "-", "__"]:
		slug = slug.replace(character, "_")
	var cleaned := ""
	for index in slug.length():
		var c := slug[index]
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == "_":
			cleaned += c
	while cleaned.contains("__"):
		cleaned = cleaned.replace("__", "_")
	while cleaned.begins_with("_"):
		cleaned = cleaned.trim_prefix("_")
	while cleaned.ends_with("_"):
		cleaned = cleaned.trim_suffix("_")
	return cleaned


func _add_scene_or_builder(scene_path: String, fallback: Node) -> void:
	if ResourceLoader.exists(scene_path):
		var resource := load(scene_path)
		if resource is PackedScene:
			add_child((resource as PackedScene).instantiate())
			return
	add_child(fallback)
