extends Node

const OUTPUT_PATH := "res://codex_captures/godot_vroid_player_smash_capture.png"
const RECOVERY_OUTPUT_PATH := "res://codex_captures/godot_vroid_player_smash_recovery_capture.png"
const SMASH_IMPACT_TIME := 1.83


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := _build_scene()
	get_tree().root.add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	var player := scene.get_node_or_null("VroidPlayerSmashCharacter") as PlayerCharacter
	if player == null:
		for child in scene.get_children():
			if child is PlayerCharacter:
				player = child as PlayerCharacter
				break
	if OS.get_environment("CODEX_CAPTURE_IDLE") == "1":
		for frame in 30:
			await get_tree().process_frame
		await _save_capture("res://codex_captures/godot_vroid_player_idle_capture.png")
		return
	if player != null:
		player.play_hit("smash", false, 3.0, &"jump_smash")
	if OS.get_environment("CODEX_CAPTURE_AFTER_RECOVERY") == "1":
		await get_tree().create_timer(3.25).timeout
		await _save_capture(RECOVERY_OUTPUT_PATH)
		return
	for frame in 4:
		await get_tree().process_frame
	if player != null:
		var real_animation_player := player.get("real_animation_player") as AnimationPlayer
		if real_animation_player != null:
			real_animation_player.seek(SMASH_IMPACT_TIME, true)
			real_animation_player.speed_scale = 0.0
	for frame in 30:
		await get_tree().process_frame
	await _save_capture(OUTPUT_PATH)


func _save_capture(output_path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_tree().root.get_texture().get_image()
	if image == null:
		push_error("No viewport image available for player smash capture.")
		get_tree().quit(1)
		return
	var error := image.save_png(output_path)
	if error != OK:
		push_error("Could not save player smash capture to %s: %s" % [output_path, error])
		get_tree().quit(1)
		return
	print("Saved viewport capture: %s" % output_path)
	get_tree().quit()


func _build_scene() -> Node3D:
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
	var profile_path := OS.get_environment("CODEX_VROID_PROFILE")
	if profile_path.is_empty():
		profile_path = GameConfig.DEFAULT_VROID_AVATAR_PROFILE
	var vroid_profile := load(profile_path)
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
	player.debug_animation_import = true
	player.lock_visual_yaw = false
	player.visual_yaw_offset = 0.0
	player.position = Vector3(-3.25, 0.0, 0.95)
	player.rotation_degrees.y = -82.0
	scene.add_child(player)
	var player_profile_path := OS.get_environment("CODEX_PLAYER_PROFILE")
	if not player_profile_path.is_empty():
		var player_profile := load(player_profile_path)
		if player_profile is PlayerProfile:
			player.apply_profile(player_profile as PlayerProfile)
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


func _add_scene_or_builder(parent: Node, scene_path: String, fallback: Node) -> void:
	if ResourceLoader.exists(scene_path):
		var resource := load(scene_path)
		if resource is PackedScene:
			parent.add_child((resource as PackedScene).instantiate())
			return
	parent.add_child(fallback)
