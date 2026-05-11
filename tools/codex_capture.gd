extends SceneTree

const MAIN_SCENE := "res://scenes/main.tscn"
const RetargetMap := preload("res://scripts/player/VroidDeepMotionRetargetMap.gd")
const AnimationBridge := preload("res://scripts/player/VroidDeepMotionAnimationBridge.gd")
const RacketAttachment := preload("res://scripts/player/VroidRacketAttachment.gd")
const MENU_OUTPUT_PATH := "res://codex_captures/godot_menu_capture.png"
const MATCH_OUTPUT_PATH := "res://codex_captures/godot_match_capture.png"
const AVATAR_OUTPUT_PATH := "res://codex_captures/godot_avatar_capture.png"
const RETARGET_OUTPUT_PATH := "res://codex_captures/godot_retarget_capture.png"
const DEEPMOTION_OUTPUT_PATH := "res://codex_captures/godot_deepmotion_capture.png"
const BRIDGED_OUTPUT_PATH := "res://codex_captures/godot_vroid_deepmotion_capture.png"
const SMASH_OUTPUT_PATH := "res://codex_captures/godot_vroid_smash_capture.png"
const SMASH_COURT_OUTPUT_PATH := "res://codex_captures/godot_vroid_smash_court_capture.png"
const PLAYER_SMASH_OUTPUT_PATH := "res://codex_captures/godot_vroid_player_smash_capture.png"
const SMASH_SEQUENCE_DIR := "res://codex_captures/vroid_smash_sequence"
const DEEPMOTION_PREVIEW_SCENE := "res://assets/animations/deepmotion/approved/service.glb"
const SMASH_PREVIEW_SCENE := "res://assets/animations/deepmotion/approved/smash.glb"
const MENU_WARMUP_FRAMES := 90
const MATCH_WARMUP_FRAMES := 120
const SMASH_SEQUENCE_FRAMES := 54
const SMASH_SEQUENCE_DURATION := 2.7
const SMASH_IMPACT_TIME := 1.83

func _initialize() -> void:
	_run_capture.call_deferred()


func _run_capture() -> void:
	var options := _parse_options()
	var mode := String(options.get("mode", "menu"))
	var output_path := String(options.get("output", _default_output_path(mode)))
	if mode == "vroid_deepmotion":
		var bridged_scene := _build_vroid_deepmotion_preview_scene()
		root.add_child(bridged_scene)
		for frame in MATCH_WARMUP_FRAMES:
			await process_frame
		await _save_viewport(output_path)
		return
	if mode == "vroid_smash":
		var smash_scene := _build_vroid_smash_preview_scene()
		root.add_child(smash_scene)
		for frame in MATCH_WARMUP_FRAMES:
			await process_frame
		await _save_viewport(output_path)
		return
	if mode == "vroid_smash_sequence":
		await _save_vroid_smash_sequence()
		return
	if mode == "vroid_smash_court":
		var smash_court_scene := _build_vroid_smash_court_scene()
		root.add_child(smash_court_scene)
		for frame in MATCH_WARMUP_FRAMES:
			await process_frame
		await _save_viewport(output_path)
		return
	if mode == "deepmotion":
		var deepmotion_scene := _build_deepmotion_preview_scene()
		root.add_child(deepmotion_scene)
		for frame in MATCH_WARMUP_FRAMES:
			await process_frame
		await _save_viewport(output_path)
		return
	if mode == "retarget":
		var retarget_scene := _build_retarget_preview_scene()
		root.add_child(retarget_scene)
		for frame in MATCH_WARMUP_FRAMES:
			await process_frame
		await _save_viewport(output_path)
		return
	if mode == "avatar":
		var avatar_scene := _build_avatar_preview_scene()
		root.add_child(avatar_scene)
		for frame in MATCH_WARMUP_FRAMES:
			await process_frame
		await _save_viewport(output_path)
		return
	if mode == "match":
		var match_scene := _build_match_preview_scene()
		root.add_child(match_scene)
		for frame in MATCH_WARMUP_FRAMES:
			await process_frame
		await _save_viewport(output_path)
		return
	if mode == "live_match":
		await _save_live_match_capture(output_path)
		return
	if mode == "vroid_player_smash":
		var player_smash_scene := _build_vroid_player_smash_scene()
		root.add_child(player_smash_scene)
		await _prepare_vroid_player_smash_capture(player_smash_scene)
		for frame in 30:
			await process_frame
		await _save_viewport(output_path)
		return
	var packed_scene := load(MAIN_SCENE) as PackedScene
	if packed_scene == null:
		push_error("Could not load capture scene: %s" % MAIN_SCENE)
		quit(1)
		return

	var scene := packed_scene.instantiate()
	root.add_child(scene)

	if mode == "match":
		await _prepare_match_capture(scene)
		for frame in MATCH_WARMUP_FRAMES:
			await process_frame
	else:
		for frame in MENU_WARMUP_FRAMES:
			await process_frame

	await RenderingServer.frame_post_draw

	await _save_viewport(output_path)


func _save_viewport(output_path: String) -> void:
	var image := root.get_texture().get_image()
	var error := image.save_png(output_path)
	if error != OK:
		push_error("Could not save capture to %s: %s" % [output_path, error])
		quit(1)
		return

	print("Saved viewport capture: %s" % output_path)
	quit()


func _build_match_preview_scene() -> Node3D:
	var scene := Node3D.new()
	scene.name = "CodexMatchPreview"
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.015, 0.018, 0.026)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.80, 0.90)
	environment.ambient_light_energy = 0.75
	world.environment = environment
	scene.add_child(world)
	_add_scene_or_builder(scene, "res://scenes/environment/Gym_JP_A.tscn", GymBuilder.new())
	_add_scene_or_builder(scene, "res://scenes/court/Court.tscn", CourtBuilder.new())
	var player := PlayerCharacter.new()
	player.display_name = "Kai"
	player.accent_color = Color(0.1, 0.2, 1.0)
	var vroid_profile := load(GameConfig.DEFAULT_VROID_AVATAR_PROFILE)
	var player_profile_path := OS.get_environment("CODEX_PLAYER_PROFILE")
	if not player_profile_path.is_empty():
		var player_profile := load(player_profile_path)
		if player_profile is PlayerProfile:
			var profile := player_profile as PlayerProfile
			player.display_name = profile.safe_name()
			player.accent_color = profile.color_primary
			if profile.vroid_avatar_profile != null:
				vroid_profile = profile.vroid_avatar_profile
	if vroid_profile is VroidAvatarProfile:
		var profile := (vroid_profile as VroidAvatarProfile).duplicate() as VroidAvatarProfile
		var rotation_override := OS.get_environment("CODEX_AVATAR_ROTATION")
		if not rotation_override.is_empty():
			var values := rotation_override.split(",", false)
			if values.size() == 3:
				profile.avatar_rotation_degrees = Vector3(float(values[0]), float(values[1]), float(values[2]))
		player.vroid_avatar_profile = profile
	else:
		player.imported_avatar_scene = GameConfig.VROID_AVATAR_SCENE
	player.use_deepmotion_jump_smash = true
	player.position = Vector3(-3.4, 0.0, 1.15)
	player.rotation_degrees.y = -90.0
	scene.add_child(player)
	var opponent := PlayerCharacter.new()
	opponent.display_name = "Mina"
	opponent.accent_color = Color(0.95, 0.1, 0.65)
	var opponent_profile_path := OS.get_environment("CODEX_OPPONENT_PROFILE")
	if not opponent_profile_path.is_empty():
		var opponent_profile := load(opponent_profile_path)
		if opponent_profile is PlayerProfile:
			var profile := opponent_profile as PlayerProfile
			opponent.display_name = profile.safe_name()
			opponent.accent_color = profile.color_primary
			if profile.vroid_avatar_profile != null:
				opponent.vroid_avatar_profile = profile.vroid_avatar_profile
				opponent.use_deepmotion_jump_smash = true
	opponent.position = Vector3(3.4, 0.0, -1.15)
	opponent.rotation_degrees.y = 90.0
	opponent.court_forward_x = -1.0
	opponent.court_right_z = -1.0
	opponent.racket_side_z = -1.0
	scene.add_child(opponent)
	var shuttle := Shuttle.new()
	shuttle.position = Vector3(-2.6, 1.65, 0.72)
	scene.add_child(shuttle)
	var camera := Camera3D.new()
	camera.name = "CodexCaptureCamera"
	camera.current = true
	camera.fov = 48.0
	camera.position = Vector3(-8.8, 5.0, 7.2)
	scene.add_child(camera)
	camera.look_at_from_position(camera.position, Vector3(0.0, 1.0, 0.0), Vector3.UP)
	var light := DirectionalLight3D.new()
	light.name = "CodexCaptureKeyLight"
	light.light_energy = 0.85
	light.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	scene.add_child(light)
	return scene


func _build_retarget_preview_scene() -> Node3D:
	var scene := _build_avatar_preview_scene()
	scene.name = "CodexRetargetPreview"
	var avatar := scene.get_node_or_null("VroidAvatar") as Node3D
	if avatar != null:
		avatar.rotation_degrees.y = -18.0
		var skeleton := _find_first_skeleton(avatar)
		if skeleton != null:
			RetargetMap.apply_probe_pose(skeleton)
	var shuttle := Shuttle.new()
	shuttle.position = Vector3(0.58, 1.72, 0.82)
	scene.add_child(shuttle)
	var racket_resource := load("res://characters/player/raquette01.glb")
	if racket_resource is PackedScene:
		var racket := (racket_resource as PackedScene).instantiate() as Node3D
		racket.name = "RetargetProbeRacket"
		racket.position = Vector3(0.46, 1.54, 0.46)
		racket.rotation_degrees = Vector3(80.0, 12.0, -36.0)
		racket.scale = Vector3.ONE * 0.82
		scene.add_child(racket)
	var camera := scene.get_node_or_null("CodexAvatarCamera") as Camera3D
	if camera != null:
		camera.fov = 36.0
		camera.look_at_from_position(Vector3(0.25, 1.42, 3.55), Vector3(0.05, 1.28, 0.0), Vector3.UP)
	return scene


func _build_deepmotion_preview_scene() -> Node3D:
	var scene := _build_preview_base_scene("CodexDeepMotionPreview")
	var resource := load(DEEPMOTION_PREVIEW_SCENE)
	if resource is PackedScene:
		var actor := (resource as PackedScene).instantiate() as Node3D
		actor.name = "DeepMotionVroidActor"
		actor.rotation_degrees.y = 18.0
		scene.add_child(actor)
		var player := _find_first_animation_player(actor)
		if player != null:
			var names := player.get_animation_list()
			if names.size() > 0:
				var clip_name := String(names[0])
				player.play(clip_name)
				player.seek(0.42, true)
	scene.add_child(_build_preview_floor())
	var camera := Camera3D.new()
	camera.name = "CodexDeepMotionCamera"
	camera.current = true
	camera.fov = 36.0
	scene.add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 1.38, 3.45), Vector3(0.0, 1.2, 0.0), Vector3.UP)
	var key := DirectionalLight3D.new()
	key.light_energy = 1.6
	key.rotation_degrees = Vector3(-42.0, 28.0, 0.0)
	scene.add_child(key)
	return scene


func _build_vroid_deepmotion_preview_scene() -> Node3D:
	var scene := _build_avatar_preview_scene()
	scene.name = "CodexVroidDeepMotionPreview"
	var avatar := scene.get_node_or_null("VroidAvatar") as Node3D
	if avatar != null:
		avatar.rotation_degrees.y = 18.0
		var player := AnimationBridge.attach_first_animation_from_scene(avatar, DEEPMOTION_PREVIEW_SCENE, "deepmotion_running_turn")
		if player != null:
			player.play("deepmotion_running_turn")
			player.seek(0.42, true)
	var camera := scene.get_node_or_null("CodexAvatarCamera") as Camera3D
	if camera != null:
		camera.fov = 36.0
		camera.look_at_from_position(Vector3(0.0, 1.38, 3.45), Vector3(0.0, 1.2, 0.0), Vector3.UP)
	return scene


func _build_vroid_smash_preview_scene(seek_time: float = 1.28) -> Node3D:
	var scene := _build_avatar_preview_scene()
	scene.name = "CodexVroidSmashPreview"
	var avatar := scene.get_node_or_null("VroidAvatar") as Node3D
	if avatar != null:
		avatar.rotation_degrees.y = -12.0
		RacketAttachment.attach_to_right_hand(avatar)
		var player := AnimationBridge.attach_first_animation_from_scene(avatar, SMASH_PREVIEW_SCENE, "deepmotion_jump_smash")
		if player != null:
			player.play("deepmotion_jump_smash")
			player.seek(seek_time, true)
			player.speed_scale = 0.0
	var camera := scene.get_node_or_null("CodexAvatarCamera") as Camera3D
	if camera != null:
		camera.fov = 35.0
		camera.look_at_from_position(Vector3(0.18, 1.48, 3.75), Vector3(0.0, 1.25, 0.0), Vector3.UP)
	var shuttle := Shuttle.new()
	shuttle.position = Vector3(0.68, 1.96, 0.58)
	scene.add_child(shuttle)
	return scene


func _build_vroid_smash_court_scene() -> Node3D:
	var scene := Node3D.new()
	scene.name = "CodexVroidSmashCourtPreview"
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.015, 0.018, 0.026)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.80, 0.90)
	environment.ambient_light_energy = 0.75
	world.environment = environment
	scene.add_child(world)
	_add_scene_or_builder(scene, "res://scenes/environment/Gym_JP_A.tscn", GymBuilder.new())
	_add_scene_or_builder(scene, "res://scenes/court/Court.tscn", CourtBuilder.new())
	var avatar_resource := load(GameConfig.VROID_AVATAR_SCENE)
	if avatar_resource is PackedScene:
		var avatar := (avatar_resource as PackedScene).instantiate() as Node3D
		avatar.name = "VroidSmashCourtAvatar"
		avatar.position = Vector3(-3.25, GameConfig.CHARACTER_GROUND_Y, 0.95)
		avatar.rotation_degrees.y = -82.0
		avatar.scale = Vector3.ONE * 1.08
		scene.add_child(avatar)
		RacketAttachment.attach_to_right_hand(avatar)
		var player := AnimationBridge.attach_first_animation_from_scene(avatar, SMASH_PREVIEW_SCENE, "deepmotion_jump_smash")
		if player != null:
			player.play("deepmotion_jump_smash")
			player.seek(SMASH_IMPACT_TIME, true)
			player.speed_scale = 0.0
	var shuttle := Shuttle.new()
	shuttle.position = Vector3(-2.28, 2.46, 0.46)
	scene.add_child(shuttle)
	var camera := Camera3D.new()
	camera.name = "CodexVroidSmashCourtCamera"
	camera.current = true
	camera.fov = 42.0
	scene.add_child(camera)
	camera.look_at_from_position(Vector3(-5.65, 2.85, -3.85), Vector3(-3.0, 1.55, 0.55), Vector3.UP)
	var light := DirectionalLight3D.new()
	light.name = "CodexVroidSmashCourtKeyLight"
	light.light_energy = 0.95
	light.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	scene.add_child(light)
	return scene


func _build_vroid_player_smash_scene() -> Node3D:
	var scene := Node3D.new()
	scene.name = "CodexVroidPlayerSmashPreview"
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.015, 0.018, 0.026)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.80, 0.90)
	environment.ambient_light_energy = 0.75
	world.environment = environment
	scene.add_child(world)
	_add_scene_or_builder(scene, "res://scenes/environment/Gym_JP_A.tscn", GymBuilder.new())
	_add_scene_or_builder(scene, "res://scenes/court/Court.tscn", CourtBuilder.new())
	var player := PlayerCharacter.new()
	player.name = "VroidPlayerSmashCharacter"
	player.display_name = "VroidPlayerSmashCharacter"
	var vroid_profile := load(GameConfig.DEFAULT_VROID_AVATAR_PROFILE)
	if vroid_profile is VroidAvatarProfile:
		player.vroid_avatar_profile = vroid_profile as VroidAvatarProfile
	else:
		player.imported_avatar_scene = GameConfig.VROID_AVATAR_SCENE
	player.use_deepmotion_jump_smash = true
	player.debug_animation_import = true
	player.lock_visual_yaw = false
	player.visual_yaw_offset = 0.0
	player.position = Vector3(-3.25, 0.0, 0.95)
	player.rotation_degrees.y = -82.0
	scene.add_child(player)
	var shuttle := Shuttle.new()
	shuttle.name = "SmashImpactShuttle"
	shuttle.position = Vector3(-2.28, 2.46, 0.46)
	scene.add_child(shuttle)
	var camera := Camera3D.new()
	camera.name = "CodexVroidPlayerSmashCamera"
	camera.current = true
	camera.fov = 42.0
	scene.add_child(camera)
	camera.look_at_from_position(Vector3(-5.65, 2.85, -3.85), Vector3(-3.0, 1.55, 0.55), Vector3.UP)
	var light := DirectionalLight3D.new()
	light.name = "CodexVroidPlayerSmashKeyLight"
	light.light_energy = 0.95
	light.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	scene.add_child(light)
	return scene


func _prepare_vroid_player_smash_capture(scene: Node) -> void:
	for frame in 45:
		await process_frame
	var player := scene.get_node_or_null("VroidPlayerSmashCharacter")
	if player == null:
		return
	player.play_hit("smash", false, 3.0, &"jump_smash")
	for frame in 4:
		await process_frame
	var real_animation_player := player.get("real_animation_player") as AnimationPlayer
	if real_animation_player != null:
		real_animation_player.seek(SMASH_IMPACT_TIME, true)
		real_animation_player.speed_scale = 0.0


func _save_vroid_smash_sequence() -> void:
	var scene := _build_vroid_smash_preview_scene(0.0)
	root.add_child(scene)
	var player := _find_first_animation_player(scene)
	if player == null:
		push_error("Could not find smash AnimationPlayer for sequence.")
		quit(1)
		return
	_prepare_sequence_dir(SMASH_SEQUENCE_DIR)
	for frame_index in SMASH_SEQUENCE_FRAMES:
		var time := (float(frame_index) / float(SMASH_SEQUENCE_FRAMES - 1)) * SMASH_SEQUENCE_DURATION
		player.seek(time, true)
		for wait_frame in 2:
			await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var frame_path := "%s/frame_%03d.png" % [SMASH_SEQUENCE_DIR, frame_index]
		var error := image.save_png(frame_path)
		if error != OK:
			push_error("Could not save smash sequence frame to %s: %s" % [frame_path, error])
			quit(1)
			return
	print("Saved smash sequence: %s frames=%d" % [SMASH_SEQUENCE_DIR, SMASH_SEQUENCE_FRAMES])
	quit()


func _prepare_sequence_dir(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".png"):
			dir.remove(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()


func _build_avatar_preview_scene() -> Node3D:
	var scene := _build_preview_base_scene("CodexAvatarPreview")
	var avatar_resource := load(GameConfig.VROID_AVATAR_SCENE)
	if avatar_resource is PackedScene:
		var avatar := (avatar_resource as PackedScene).instantiate()
		avatar.name = "VroidAvatar"
		scene.add_child(avatar)
	scene.add_child(_build_preview_floor())
	var camera := Camera3D.new()
	camera.name = "CodexAvatarCamera"
	camera.current = true
	camera.fov = 42.0
	scene.add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 1.35, 3.2), Vector3(0.0, 1.25, 0.0), Vector3.UP)
	var key := DirectionalLight3D.new()
	key.light_energy = 1.6
	key.rotation_degrees = Vector3(-42.0, 28.0, 0.0)
	scene.add_child(key)
	return scene


func _build_preview_base_scene(scene_name: String) -> Node3D:
	var scene := Node3D.new()
	scene.name = scene_name
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.045, 0.052, 0.065)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.86, 0.90, 0.95)
	environment.ambient_light_energy = 0.82
	world.environment = environment
	scene.add_child(world)
	return scene


func _build_preview_floor() -> MeshInstance3D:
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "PreviewFloor"
	var plane := PlaneMesh.new()
	plane.size = Vector2(3.0, 3.0)
	floor_mesh.mesh = plane
	floor_mesh.material_override = GameConfig.material(Color(0.16, 0.18, 0.22))
	return floor_mesh


func _add_scene_or_builder(parent: Node, scene_path: String, fallback: Node) -> void:
	if ResourceLoader.exists(scene_path):
		var resource := load(scene_path)
		if resource is PackedScene:
			parent.add_child((resource as PackedScene).instantiate())
			return
	parent.add_child(fallback)


func _default_output_path(mode: String) -> String:
	match mode:
		"match":
			return MATCH_OUTPUT_PATH
		"avatar":
			return AVATAR_OUTPUT_PATH
		"retarget":
			return RETARGET_OUTPUT_PATH
		"deepmotion":
			return DEEPMOTION_OUTPUT_PATH
		"vroid_deepmotion":
			return BRIDGED_OUTPUT_PATH
		"vroid_smash":
			return SMASH_OUTPUT_PATH
		"vroid_smash_court":
			return SMASH_COURT_OUTPUT_PATH
		"vroid_player_smash":
			return PLAYER_SMASH_OUTPUT_PATH
		_:
			return MENU_OUTPUT_PATH


func _find_first_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var skeleton := _find_first_skeleton(child)
		if skeleton != null:
			return skeleton
	return null


func _find_first_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var player := _find_first_animation_player(child)
		if player != null:
			return player
	return null


func _prepare_match_capture(scene: Node) -> void:
	for frame in 30:
		await process_frame
	var hud := scene.get("hud") as Node
	if hud == null:
		return
	var main_menu := hud.get("main_menu_overlay") as CanvasItem
	if main_menu != null:
		main_menu.visible = false
	var pause_menu := hud.get("pause_menu_overlay") as CanvasItem
	if pause_menu != null:
		pause_menu.visible = false
	var pause_label := hud.get("pause_label") as CanvasItem
	if pause_label != null:
		pause_label.visible = false


func _save_live_match_capture(output_path: String) -> void:
	var selection := root.get_node_or_null("GameSelection")
	if selection != null:
		var p1_path := OS.get_environment("CODEX_PLAYER_PROFILE")
		var p2_path := OS.get_environment("CODEX_OPPONENT_PROFILE")
		var p1 := load(p1_path) if not p1_path.is_empty() else load("res://data/players/mina.tres")
		var p2 := load(p2_path) if not p2_path.is_empty() else load("res://data/players/akiro.tres")
		if p1 is PlayerProfile and p2 is PlayerProfile:
			selection.call("set_players", p1, p2)
			selection.set("is_ai_match", true)
	var packed_scene := load(MAIN_SCENE) as PackedScene
	if packed_scene == null:
		push_error("Could not load live match scene: %s" % MAIN_SCENE)
		quit(1)
		return
	var scene := packed_scene.instantiate()
	root.add_child(scene)
	for frame in 20:
		await process_frame
	if scene.has_method("_start_game"):
		scene.call("_start_game", {
			"mode": "singles",
			"camera_slot": 0,
			"difficulty": "normal",
			"player_ai_enabled": false
		})
	for frame in MATCH_WARMUP_FRAMES:
		await process_frame
	await _save_viewport(output_path)


func _parse_options() -> Dictionary:
	var options := {}
	var env_mode := OS.get_environment("CODEX_CAPTURE_MODE")
	if env_mode != "":
		options["mode"] = env_mode
	var env_output := OS.get_environment("CODEX_CAPTURE_OUTPUT")
	if env_output != "":
		options["output"] = env_output
	for arg in OS.get_cmdline_user_args():
		var pair := String(arg).split("=", false, 1)
		if pair.size() == 2:
			options[pair[0].strip_edges()] = pair[1].strip_edges()
	return options
