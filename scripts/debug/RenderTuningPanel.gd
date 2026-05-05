extends CanvasLayer

const CONFIG_PATH := "user://render_tuning.json"
const SOFT_CEL_SHADER_PATH := "res://materials/anime/SoftCelShading.gdshader"
const OUTLINE_MATERIAL_PATH := "res://materials/anime/AnimeOutlineMaterial.tres"

var root_panel: Panel
var sections: Dictionary = {}
var controls: Dictionary = {}
var defaults: Dictionary = {}
var material_defaults: Dictionary = {}
var texture_defaults: Dictionary = {}
var original_materials: Dictionary = {}
var loading_values: bool = false
var soft_cel_shader: Shader
var outline_material_template: ShaderMaterial
var env_node: WorldEnvironment
var main_light: DirectionalLight3D
var fill_light: DirectionalLight3D
var save_status: Label
var shadow_probe_root: Node3D
var shadow_probe_disabled_lights: Array[Light3D] = []
var shadow_probe_env_energy: float = -1.0
var light_plan_panel: Panel
var light_plan_header: Control
var light_plan_minimized: bool = false
var light_plan_dragging: bool = false
var light_plan_drag_offset: Vector2 = Vector2.ZERO
var ceiling_light_map: CeilingLightMap
var selected_ceiling_light: int = 0
var selected_light_title: Label
var selected_light_control_keys: Array[String] = []

func _ready() -> void:
	visible = false
	soft_cel_shader = load(SOFT_CEL_SHADER_PATH) as Shader
	outline_material_template = load(OUTLINE_MATERIAL_PATH) as ShaderMaterial
	_resolve_targets()
	_capture_defaults()
	_build_ui()
	if not _load_preset():
		reset_to_defaults()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.keycode == KEY_F9:
			toggle()
			get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	_restore_shadow_probe_scene()

func toggle() -> void:
	visible = not visible
	if visible:
		_resolve_targets()
		layer = 80

func apply_default_anime_preset() -> void:
	reset_to_defaults()

func reset_to_defaults() -> void:
	loading_values = true
	for key in defaults.keys():
		_set_control_value(String(key), defaults[key])
	loading_values = false
	_apply_all()
	if save_status != null:
		save_status.text = "Defaults"

func apply_anime_shadow_preset() -> void:
	var preset := {
		"realistic_shadows_enabled": true,
		"dynamic_character_shadows_enabled": true,
		"main_shadow": false,
		"main_rot_x": -82.0,
		"main_rot_y": -18.0,
		"main_rot_z": 0.0,
		"realistic_shadow_blur": 2.2,
		"realistic_shadow_bias": 0.006,
		"realistic_shadow_normal_bias": 0.28,
		"gym_shadow_energy": 0.34,
		"gym_shadow_opacity": 0.95,
		"gym_shadow_rot_x": -72.0,
		"gym_shadow_rot_y": -34.0,
		"gym_shadow_rot_z": 0.0,
		"gym_shadow_r": 1.0,
		"gym_shadow_g": 0.88,
		"gym_shadow_b": 0.70,
		"realistic_main_energy": 0.35,
		"realistic_fill_energy": 0.30,
		"ceiling_light_1_enabled": true,
		"ceiling_light_1_x": -2.2,
		"ceiling_light_1_z": -3.05,
		"ceiling_light_1_target_x": 0.25,
		"ceiling_light_1_target_z": -0.55,
		"ceiling_light_1_energy": 8.2,
		"ceiling_light_2_enabled": true,
		"ceiling_light_2_x": 2.2,
		"ceiling_light_2_z": 3.05,
		"ceiling_light_2_target_x": -0.25,
		"ceiling_light_2_target_z": 0.55,
		"ceiling_light_2_energy": 5.4,
		"ceiling_light_3_enabled": false,
		"ceiling_light_3_x": -2.2,
		"ceiling_light_3_z": 3.05,
		"ceiling_light_3_target_x": 0.25,
		"ceiling_light_3_target_z": 0.55,
		"ceiling_light_3_energy": 0.0,
		"ceiling_light_4_enabled": false,
		"ceiling_light_4_x": 2.2,
		"ceiling_light_4_z": -3.05,
		"ceiling_light_4_target_x": -0.25,
		"ceiling_light_4_target_z": -0.55,
		"ceiling_light_4_energy": 0.0,
		"ceiling_light_height": 6.35,
		"ceiling_light_range": 13.0,
		"ceiling_light_angle": 58.0,
		"ceiling_light_blur": 1.8,
		"ceiling_light_bias": 0.003,
		"ceiling_light_normal_bias": 0.12,
		"gym_fill_enabled": true,
		"gym_fill_energy": 1.35,
		"gym_fill_angle": 72.0,
		"env_ambient_energy": 0.30,
		"fill_enabled": true,
		"main_enabled": true,
		"character_roughness": 0.90,
		"character_specular": 0.06,
		"skin_brightness": 1.08,
		"hair_brightness": 1.03,
		"clothes_brightness": 1.08,
		"toon_strength": 0.22,
		"shadow_threshold": 0.42,
		"shadow_softness": 0.38,
		"min_shadow_brightness": 0.62,
		"max_light_brightness": 1.06,
		"outline_enabled": false,
		"outline_thickness": 0.35,
		"outline_opacity": 0.45,
		"outline_r": 0.10,
		"outline_g": 0.11,
		"outline_b": 0.12
	}
	_apply_preset_values(preset, "Preset ombres anime")

func apply_reference_anime_gym_preset() -> void:
	var preset := {
		"env_ambient_energy": 0.18,
		"env_exposure": 0.92,
		"env_saturation": 1.08,
		"env_contrast": 1.28,
		"main_enabled": true,
		"main_energy": 0.22,
		"main_shadow": false,
		"fill_enabled": true,
		"fill_energy": 0.13,
		"realistic_shadows_enabled": true,
		"dynamic_character_shadows_enabled": true,
		"realistic_main_energy": 0.22,
		"realistic_fill_energy": 0.13,
		"gym_shadow_energy": 0.34,
		"gym_shadow_opacity": 0.95,
		"gym_shadow_rot_x": -72.0,
		"gym_shadow_rot_y": -34.0,
		"gym_shadow_rot_z": 0.0,
		"gym_shadow_r": 1.0,
		"gym_shadow_g": 0.88,
		"gym_shadow_b": 0.70,
		"ceiling_lights_enabled": true,
		"ceiling_light_height": 6.45,
		"ceiling_light_range": 14.0,
		"ceiling_light_angle": 62.0,
		"ceiling_light_blur": 2.2,
		"ceiling_light_bias": 0.004,
		"ceiling_light_normal_bias": 0.14,
		"ceiling_light_1_enabled": true,
		"ceiling_light_1_x": -4.2,
		"ceiling_light_1_z": -3.25,
		"ceiling_light_1_target_x": -0.45,
		"ceiling_light_1_target_z": -0.50,
		"ceiling_light_1_energy": 6.0,
		"ceiling_light_2_enabled": true,
		"ceiling_light_2_x": 4.2,
		"ceiling_light_2_z": -3.25,
		"ceiling_light_2_target_x": 0.45,
		"ceiling_light_2_target_z": -0.50,
		"ceiling_light_2_energy": 5.2,
		"ceiling_light_3_enabled": true,
		"ceiling_light_3_x": -4.2,
		"ceiling_light_3_z": 3.25,
		"ceiling_light_3_target_x": -0.45,
		"ceiling_light_3_target_z": 0.50,
		"ceiling_light_3_energy": 4.6,
		"ceiling_light_4_enabled": true,
		"ceiling_light_4_x": 4.2,
		"ceiling_light_4_z": 3.25,
		"ceiling_light_4_target_x": 0.45,
		"ceiling_light_4_target_z": 0.50,
		"ceiling_light_4_energy": 4.8,
		"gym_fill_enabled": true,
		"gym_fill_energy": 0.95,
		"gym_fill_angle": 82.0,
		"court_brightness": 0.94,
		"blue_border_brightness": 0.90,
		"wall_brightness": 0.86,
		"parquet_brightness": 0.72,
		"parquet_warmth": 0.18,
		"parquet_roughness": 0.68,
		"parquet_specular": 0.15,
		"parquet_uv_scale": 8.0,
		"side_wall_texture_height": 7.0,
		"wood_brightness": 0.88,
		"curtain_brightness": 0.92
	}
	_apply_preset_values(preset, "Preset reference anime gym")

func _apply_preset_values(preset: Dictionary, status: String) -> void:
	loading_values = true
	for key in preset.keys():
		_set_control_value(String(key), preset[key])
	loading_values = false
	_apply_all()
	if save_status != null:
		save_status.text = status

func _resolve_targets() -> void:
	env_node = _first_in_group("render_environment") as WorldEnvironment
	main_light = _first_in_group("main_light") as DirectionalLight3D
	fill_light = _first_in_group("fill_light") as DirectionalLight3D

func _first_in_group(group_name: String) -> Node:
	var nodes: Array[Node] = get_tree().get_nodes_in_group(group_name)
	if nodes.is_empty():
		return null
	return nodes[0]

func _capture_defaults() -> void:
	defaults = {
		"env_ambient_energy": 0.24,
		"env_ambient_r": 0.68,
		"env_ambient_g": 0.67,
		"env_ambient_b": 0.62,
		"env_exposure": 0.94,
		"env_glow": true,
		"env_glow_intensity": 0.12,
		"env_saturation": 1.03,
		"env_contrast": 1.22,
		"aa_msaa": 2,
		"aa_fxaa": true,
		"aa_taa": false,
		"aa_render_scale": 0,
		"main_enabled": true,
		"main_energy": 0.26,
		"main_r": 1.0,
		"main_g": 0.96,
		"main_b": 0.88,
		"main_rot_x": -82.0,
		"main_rot_y": -18.0,
		"main_rot_z": 0.0,
		"main_shadow": false,
		"main_bias": 0.035,
		"main_normal_bias": 1.3,
		"main_blur": 4.0,
		"fill_enabled": true,
		"fill_energy": 0.16,
		"fill_r": 0.72,
		"fill_g": 0.78,
		"fill_b": 1.0,
		"fill_rot_x": -38.0,
		"fill_rot_y": 145.0,
		"fill_rot_z": 0.0,
		"player_brightness": 1.0,
		"skin_brightness": 1.0,
		"hair_brightness": 1.0,
		"clothes_brightness": 1.0,
		"character_roughness": 0.85,
		"character_specular": 0.10,
		"dynamic_character_shadows_enabled": true,
		"realistic_shadows_enabled": true,
		"realistic_shadow_blur": 2.2,
		"realistic_shadow_bias": 0.006,
		"realistic_shadow_normal_bias": 0.28,
		"gym_shadow_energy": 0.34,
		"gym_shadow_opacity": 0.95,
		"gym_shadow_rot_x": -72.0,
		"gym_shadow_rot_y": -34.0,
		"gym_shadow_rot_z": 0.0,
		"gym_shadow_r": 1.0,
		"gym_shadow_g": 0.88,
		"gym_shadow_b": 0.70,
		"realistic_main_energy": 0.26,
		"realistic_fill_energy": 0.16,
		"ceiling_lights_enabled": true,
		"ceiling_light_1_enabled": true,
		"ceiling_light_1_x": -2.2,
		"ceiling_light_1_z": -3.05,
		"ceiling_light_1_target_x": 0.25,
		"ceiling_light_1_target_z": -0.55,
		"ceiling_light_1_energy": 6.6,
		"ceiling_light_2_enabled": true,
		"ceiling_light_2_x": 2.2,
		"ceiling_light_2_z": 3.05,
		"ceiling_light_2_target_x": -0.25,
		"ceiling_light_2_target_z": 0.55,
		"ceiling_light_2_energy": 4.8,
		"ceiling_light_3_enabled": false,
		"ceiling_light_3_x": -2.2,
		"ceiling_light_3_z": 3.05,
		"ceiling_light_3_target_x": 0.25,
		"ceiling_light_3_target_z": 0.55,
		"ceiling_light_3_energy": 0.0,
		"ceiling_light_4_enabled": false,
		"ceiling_light_4_x": 2.2,
		"ceiling_light_4_z": -3.05,
		"ceiling_light_4_target_x": -0.25,
		"ceiling_light_4_target_z": -0.55,
		"ceiling_light_4_energy": 0.0,
		"ceiling_light_height": 6.35,
		"ceiling_light_range": 13.0,
		"ceiling_light_angle": 58.0,
		"ceiling_light_blur": 1.8,
		"ceiling_light_bias": 0.003,
		"ceiling_light_normal_bias": 0.12,
		"gym_fill_enabled": true,
		"gym_fill_energy": 0.85,
		"gym_fill_angle": 72.0,
		"real_shadow_defaults_version": 7.0,
		"shuttle_speed_lines_enabled": true,
		"shuttle_speed_lines_opacity": 0.65,
		"shuttle_speed_lines_length_main": 0.80,
		"shuttle_speed_lines_width": 0.025,
		"shuttle_speed_lines_r": 1.0,
		"shuttle_speed_lines_g": 0.94,
		"shuttle_speed_lines_b": 0.55,
		"racket_impact_fx_enabled": true,
		"racket_impact_fx_scale": 1.35,
		"racket_impact_fx_opacity": 0.90,
		"racket_impact_fx_duration": 0.15,
		"racket_impact_fx_r": 0.10,
		"racket_impact_fx_g": 0.105,
		"racket_impact_fx_b": 0.11,
		"racket_impact_fx_billboard_enabled": true,
		"trail_enabled": true,
		"trail_opacity": 0.56,
		"trail_length": 18.0,
		"trail_r": 1.0,
		"trail_g": 0.92,
		"trail_b": 0.36,
		"kai_service_shuttle_forward": 0.0,
		"kai_service_shuttle_lateral": 0.0,
		"kai_service_shuttle_height": 0.0,
		"kai_service_shuttle_rot_x": 0.0,
		"kai_service_shuttle_rot_y": 0.0,
		"kai_service_shuttle_rot_z": 0.0,
		"mina_service_shuttle_forward": 0.0,
		"mina_service_shuttle_lateral": 0.0,
		"mina_service_shuttle_height": 0.0,
		"mina_service_shuttle_rot_x": 0.0,
		"mina_service_shuttle_rot_y": 0.0,
		"mina_service_shuttle_rot_z": 0.0,
		"impact_enabled": true,
		"impact_delay": 0.0,
		"impact_duration": 0.18,
		"impact_opacity": 0.52,
		"impact_size_start": 0.38,
		"impact_size_end": 1.38,
		"impact_r": 1.0,
		"impact_g": 0.82,
		"impact_b": 0.18,
		"landing_marker_enabled": true,
		"landing_marker_delay": 0.0,
		"landing_marker_duration": 0.20,
		"landing_marker_opacity": 0.78,
		"landing_marker_size_start": 0.70,
		"landing_marker_size_end": 1.0,
		"landing_marker_r": 0.98,
		"landing_marker_g": 0.82,
		"landing_marker_b": 0.18,
		"landing_marker_height": 0.08,
		"court_brightness": 1.0,
		"court_saturation": 1.0,
		"line_brightness": 1.0,
		"blue_border_brightness": 1.0,
		"wall_brightness": 1.0,
		"parquet_brightness": 0.72,
		"parquet_warmth": 0.18,
		"parquet_roughness": 0.68,
		"parquet_specular": 0.15,
		"parquet_uv_scale": 8.0,
		"side_wall_texture_height": 7.0,
		"wood_brightness": 1.0,
		"curtain_brightness": 1.0
		,
		"cel_shading_enabled": false,
		"apply_to_characters": true,
		"apply_to_court": false,
		"apply_to_gym": false,
		"apply_to_racket": false,
		"toon_strength": 0.35,
		"shadow_steps": 2.0,
		"shadow_threshold": 0.45,
		"shadow_softness": 0.25,
		"min_shadow_brightness": 0.55,
		"max_light_brightness": 1.05,
		"outline_enabled": false,
		"outline_apply_to_characters": true,
		"outline_apply_to_racket": false,
		"outline_apply_to_shuttle": false,
		"outline_apply_to_gym": false,
		"outline_thickness": 0.7,
		"outline_r": 0.12,
		"outline_g": 0.13,
		"outline_b": 0.14,
		"outline_opacity": 0.75,
		"outline_depth_bias": 0.005,
		"outline_use_screen_size": true
	}

func _build_ui() -> void:
	root_panel = Panel.new()
	root_panel.anchor_left = 0.0
	root_panel.anchor_top = 0.0
	root_panel.anchor_right = 0.0
	root_panel.anchor_bottom = 1.0
	root_panel.offset_left = 16.0
	root_panel.offset_top = 70.0
	root_panel.offset_right = 410.0
	root_panel.offset_bottom = -18.0
	root_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.06, 0.065, 0.075, 0.92), Color(1, 1, 1, 0.18), 8))
	add_child(root_panel)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 8.0
	scroll.offset_top = 8.0
	scroll.offset_right = -8.0
	scroll.offset_bottom = -8.0
	root_panel.add_child(scroll)

	var content := VBoxContainer.new()
	content.custom_minimum_size = Vector2(360, 3300)
	scroll.add_child(content)

	var title := Label.new()
	title.text = "Render Tuning  (F9)"
	title.add_theme_font_size_override("font_size", 20)
	content.add_child(title)

	var row := HBoxContainer.new()
	content.add_child(row)
	_add_button(row, "Reset valeurs defaut", reset_to_defaults)
	_add_button(row, "Preset ombres anime", apply_anime_shadow_preset)
	_add_button(row, "Preset reference", apply_reference_anime_gym_preset)
	_add_button(row, "Plan lumieres", _toggle_light_plan_panel)
	_add_button(row, "Test ombre terrain", _toggle_shadow_probe)
	_add_button(row, "Diagnostic rendu", _show_render_diagnostic)
	_add_button(row, "Sauver selection", _save_preset)
	_add_button(row, "Recharger", _load_preset)
	save_status = Label.new()
	save_status.text = ""
	content.add_child(save_status)
	_build_light_plan_panel()

	# Rendering backend options that are safe to tune live.
	_add_section(content, "Image Quality", [
		_option("aa_msaa", "MSAA", ["Off", "x2", "x4", "x8"]),
		_check("aa_fxaa", "FXAA"),
		_check("aa_taa", "TAA"),
		_option("aa_render_scale", "Render scale", ["1.0", "1.25", "1.5"])
	])
	_add_section(content, "Environment & Post", [
		_slider("env_ambient_energy", "Ambient energy", 0.0, 1.5, 0.01),
		_slider("env_ambient_r", "Ambient R", 0.0, 1.0, 0.01),
		_slider("env_ambient_g", "Ambient G", 0.0, 1.0, 0.01),
		_slider("env_ambient_b", "Ambient B", 0.0, 1.0, 0.01),
		_slider("env_exposure", "Exposure", 0.3, 2.0, 0.01),
		_check("env_glow", "Glow"),
		_slider("env_glow_intensity", "Glow intensity", 0.0, 1.0, 0.01),
		_slider("env_saturation", "Saturation", 0.0, 2.0, 0.01),
		_slider("env_contrast", "Contrast", 0.5, 2.0, 0.01)
	])
	# Scene light controls. Gameplay never reads these values.
	_add_section(content, "Lighting", [
		_check("main_enabled", "Main enabled"),
		_slider("main_energy", "Main energy", 0.0, 5.0, 0.01),
		_slider("main_r", "Main R", 0.0, 1.0, 0.01),
		_slider("main_g", "Main G", 0.0, 1.0, 0.01),
		_slider("main_b", "Main B", 0.0, 1.0, 0.01),
		_slider("main_rot_x", "Main rot X", -180, 180, 1),
		_slider("main_rot_y", "Main rot Y", -180, 180, 1),
		_slider("main_rot_z", "Main rot Z", -180, 180, 1),
		_check("main_shadow", "Main shadow"),
		_slider("main_bias", "Shadow bias", 0.0, 0.2, 0.001),
		_slider("main_normal_bias", "Normal bias", 0.0, 5.0, 0.01),
		_slider("main_blur", "Shadow blur", 0.0, 10.0, 0.1),
		_check("fill_enabled", "Fill enabled"),
		_slider("fill_energy", "Fill energy", 0.0, 2.0, 0.01),
		_slider("fill_r", "Fill R", 0.0, 1.0, 0.01),
		_slider("fill_g", "Fill G", 0.0, 1.0, 0.01),
		_slider("fill_b", "Fill B", 0.0, 1.0, 0.01),
		_slider("fill_rot_x", "Fill rot X", -180, 180, 1),
		_slider("fill_rot_y", "Fill rot Y", -180, 180, 1),
		_slider("fill_rot_z", "Fill rot Z", -180, 180, 1)
	])
	_add_section(content, "Character Materials", [
		_slider("player_brightness", "Albedo multiplier", 0.3, 2.0, 0.01),
		_slider("skin_brightness", "Skin brightness", 0.5, 1.5, 0.01),
		_slider("hair_brightness", "Hair brightness", 0.5, 1.5, 0.01),
		_slider("clothes_brightness", "Clothes brightness", 0.5, 1.5, 0.01),
		_slider("character_roughness", "Character roughness", 0.0, 1.0, 0.01),
		_slider("character_specular", "Character specular", 0.0, 1.0, 0.01)
	])
	# Character shadow tuning is visual-only and applied through groups.
	_add_section(content, "Character Shadows", [
		_check("realistic_shadows_enabled", "Realistic shadows enabled"),
		_check("dynamic_character_shadows_enabled", "Dynamic character shadows"),
		_slider("realistic_shadow_blur", "Shadow softness", 0.0, 12.0, 0.1),
		_slider("realistic_shadow_bias", "Shadow bias", 0.0, 0.2, 0.001),
		_slider("realistic_shadow_normal_bias", "Normal bias", 0.0, 5.0, 0.01),
		_slider("gym_shadow_energy", "Gym shadow energy", 0.0, 2.0, 0.01),
		_slider("gym_shadow_opacity", "Gym shadow opacity", 0.0, 1.0, 0.01),
		_slider("gym_shadow_rot_x", "Gym shadow rot X", -180.0, 180.0, 1.0),
		_slider("gym_shadow_rot_y", "Gym shadow rot Y", -180.0, 180.0, 1.0),
		_slider("gym_shadow_rot_z", "Gym shadow rot Z", -180.0, 180.0, 1.0),
		_slider("gym_shadow_r", "Gym shadow R", 0.0, 1.0, 0.01),
		_slider("gym_shadow_g", "Gym shadow G", 0.0, 1.0, 0.01),
		_slider("gym_shadow_b", "Gym shadow B", 0.0, 1.0, 0.01),
		_slider("realistic_main_energy", "Main light energy", 0.0, 4.0, 0.01),
		_slider("realistic_fill_energy", "Fill light energy", 0.0, 2.0, 0.01)
	])
	_add_section(content, "Cel Shading", [
		_check("cel_shading_enabled", "Cel shading enabled"),
		_check("apply_to_characters", "Apply to characters"),
		_check("apply_to_court", "Apply to court"),
		_check("apply_to_gym", "Apply to gym"),
		_check("apply_to_racket", "Apply to racket"),
		_slider("toon_strength", "Toon strength", 0.0, 1.0, 0.01),
		_slider("shadow_steps", "Shadow steps", 1.0, 4.0, 1.0),
		_slider("shadow_threshold", "Shadow threshold", 0.0, 1.0, 0.01),
		_slider("shadow_softness", "Shadow softness", 0.0, 1.0, 0.01),
		_slider("min_shadow_brightness", "Min shadow brightness", 0.2, 0.8, 0.01),
		_slider("max_light_brightness", "Max light brightness", 0.8, 1.3, 0.01)
	])
	_add_section(content, "Outline", [
		_check("outline_enabled", "Outline enabled"),
		_check("outline_apply_to_characters", "Apply to characters"),
		_check("outline_apply_to_racket", "Apply to racket"),
		_check("outline_apply_to_shuttle", "Apply to shuttle"),
		_check("outline_apply_to_gym", "Apply to gym"),
		_slider("outline_thickness", "Outline thickness", 0.0, 3.0, 0.01),
		_slider("outline_r", "Outline R", 0.0, 1.0, 0.01),
		_slider("outline_g", "Outline G", 0.0, 1.0, 0.01),
		_slider("outline_b", "Outline B", 0.0, 1.0, 0.01),
		_slider("outline_opacity", "Outline opacity", 0.0, 1.0, 0.01),
		_slider("outline_depth_bias", "Outline depth bias", 0.0, 0.05, 0.001),
		_check("outline_use_screen_size", "Use screen size")
	])
	# Shuttle service placement and manga FX; flight physics stay in Shuttle.gd.
	_add_section(content, "Shuttle & Hit FX", [
		_check("shuttle_speed_lines_enabled", "Speed lines enabled"),
		_slider("shuttle_speed_lines_opacity", "Speed lines opacity", 0.0, 1.0, 0.01),
		_slider("shuttle_speed_lines_length_main", "Main line length", 0.1, 1.8, 0.01),
		_slider("shuttle_speed_lines_width", "Speed line width", 0.005, 0.08, 0.001),
		_slider("shuttle_speed_lines_r", "Speed R", 0.0, 1.0, 0.01),
		_slider("shuttle_speed_lines_g", "Speed G", 0.0, 1.0, 0.01),
		_slider("shuttle_speed_lines_b", "Speed B", 0.0, 1.0, 0.01),
		_check("racket_impact_fx_enabled", "Impact FX enabled"),
		_slider("racket_impact_fx_scale", "Impact scale", 0.2, 4.0, 0.01),
		_slider("racket_impact_fx_opacity", "Impact opacity", 0.0, 1.0, 0.01),
		_slider("racket_impact_fx_duration", "Impact duration", 0.05, 0.35, 0.01),
		_slider("racket_impact_fx_r", "Impact R", 0.0, 1.0, 0.01),
		_slider("racket_impact_fx_g", "Impact G", 0.0, 1.0, 0.01),
		_slider("racket_impact_fx_b", "Impact B", 0.0, 1.0, 0.01),
		_check("racket_impact_fx_billboard_enabled", "Impact billboard"),
		_check("trail_enabled", "Trail enabled"),
		_slider("trail_opacity", "Trail opacity", 0.0, 1.0, 0.01),
		_slider("trail_length", "Trail length", 2.0, 36.0, 1.0),
		_slider("trail_r", "Trail R", 0.0, 1.0, 0.01),
		_slider("trail_g", "Trail G", 0.0, 1.0, 0.01),
		_slider("trail_b", "Trail B", 0.0, 1.0, 0.01),
		_slider("kai_service_shuttle_forward", "Kai service forward", -0.35, 0.35, 0.005),
		_slider("kai_service_shuttle_lateral", "Kai service side", -0.35, 0.35, 0.005),
		_slider("kai_service_shuttle_height", "Kai service height", -0.35, 0.35, 0.005),
		_slider("kai_service_shuttle_rot_x", "Kai service rot X", -180.0, 180.0, 1.0),
		_slider("kai_service_shuttle_rot_y", "Kai service rot Y", -180.0, 180.0, 1.0),
		_slider("kai_service_shuttle_rot_z", "Kai service rot Z", -180.0, 180.0, 1.0),
		_slider("mina_service_shuttle_forward", "Mina service forward", -0.35, 0.35, 0.005),
		_slider("mina_service_shuttle_lateral", "Mina service side", -0.35, 0.35, 0.005),
		_slider("mina_service_shuttle_height", "Mina service height", -0.35, 0.35, 0.005),
		_slider("mina_service_shuttle_rot_x", "Mina service rot X", -180.0, 180.0, 1.0),
		_slider("mina_service_shuttle_rot_y", "Mina service rot Y", -180.0, 180.0, 1.0),
		_slider("mina_service_shuttle_rot_z", "Mina service rot Z", -180.0, 180.0, 1.0),
		_check("impact_enabled", "Impact circle enabled"),
		_slider("impact_delay", "Impact delay", 0.0, 0.6, 0.01),
		_slider("impact_duration", "Impact duration", 0.03, 1.0, 0.01),
		_slider("impact_opacity", "Impact opacity", 0.0, 1.0, 0.01),
		_slider("impact_size_start", "Impact size start", 0.05, 3.0, 0.01),
		_slider("impact_size_end", "Impact size end", 0.05, 4.0, 0.01),
		_slider("impact_r", "Impact R", 0.0, 1.0, 0.01),
		_slider("impact_g", "Impact G", 0.0, 1.0, 0.01),
		_slider("impact_b", "Impact B", 0.0, 1.0, 0.01),
		_check("landing_marker_enabled", "Landing circle enabled"),
		_slider("landing_marker_delay", "Landing delay", 0.0, 1.2, 0.01),
		_slider("landing_marker_duration", "Landing anim duration", 0.03, 1.5, 0.01),
		_slider("landing_marker_opacity", "Landing opacity", 0.0, 1.0, 0.01),
		_slider("landing_marker_size_start", "Landing size start", 0.05, 4.0, 0.01),
		_slider("landing_marker_size_end", "Landing size end", 0.05, 5.0, 0.01),
		_slider("landing_marker_r", "Landing R", 0.0, 1.0, 0.01),
		_slider("landing_marker_g", "Landing G", 0.0, 1.0, 0.01),
		_slider("landing_marker_b", "Landing B", 0.0, 1.0, 0.01),
		_slider("landing_marker_height", "Landing height", 0.02, 0.25, 0.001)
	])
	_add_section(content, "Court", [
		_slider("court_brightness", "Court brightness", 0.3, 2.0, 0.01),
		_slider("court_saturation", "Court saturation", 0.0, 2.0, 0.01),
		_slider("line_brightness", "Line brightness", 0.3, 2.0, 0.01),
		_slider("blue_border_brightness", "Blue border", 0.3, 2.0, 0.01)
	])
	_add_section(content, "Gym", [
		_slider("wall_brightness", "Wall brightness", 0.3, 2.0, 0.01),
		_slider("parquet_brightness", "Parquet brightness", 0.25, 1.25, 0.01),
		_slider("parquet_warmth", "Parquet warmth", 0.0, 1.0, 0.01),
		_slider("parquet_roughness", "Parquet roughness", 0.0, 1.0, 0.01),
		_slider("parquet_specular", "Parquet specular", 0.0, 1.0, 0.01),
		_slider("parquet_uv_scale", "Parquet tile scale", 2.0, 16.0, 0.5),
		_slider("side_wall_texture_height", "Side wall height", 2.0, 7.0, 0.05),
		_slider("wood_brightness", "Wood brightness", 0.3, 2.0, 0.01),
		_slider("curtain_brightness", "Curtain brightness", 0.3, 2.0, 0.01)
	])

func _build_light_plan_panel() -> void:
	light_plan_panel = Panel.new()
	light_plan_panel.visible = false
	light_plan_panel.position = Vector2(900.0, 86.0)
	light_plan_panel.size = Vector2(360.0, 600.0)
	light_plan_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.055, 0.058, 0.066, 0.96), Color(1, 1, 1, 0.22), 8))
	add_child(light_plan_panel)

	light_plan_header = Control.new()
	light_plan_header.position = Vector2.ZERO
	light_plan_header.size = Vector2(360.0, 42.0)
	light_plan_header.mouse_filter = Control.MOUSE_FILTER_STOP
	light_plan_header.gui_input.connect(_on_light_plan_header_input)
	light_plan_panel.add_child(light_plan_header)

	var title := Label.new()
	title.text = "Plan lumieres plafond"
	title.position = Vector2(18.0, 14.0)
	title.add_theme_font_size_override("font_size", 16)
	light_plan_header.add_child(title)

	var minimize_button := Button.new()
	minimize_button.text = "-"
	minimize_button.position = Vector2(258.0, 8.0)
	minimize_button.size = Vector2(38.0, 28.0)
	minimize_button.pressed.connect(_toggle_light_plan_minimized)
	light_plan_header.add_child(minimize_button)

	var close_button := Button.new()
	close_button.text = "Fermer"
	close_button.position = Vector2(300.0, 8.0)
	close_button.size = Vector2(52.0, 28.0)
	close_button.pressed.connect(func() -> void: light_plan_panel.visible = false)
	light_plan_header.add_child(close_button)

	ceiling_light_map = CeilingLightMap.new()
	ceiling_light_map.position = Vector2(12.0, 48.0)
	ceiling_light_map.size = Vector2(336.0, 235.0)
	ceiling_light_map.light_selected.connect(_select_ceiling_light)
	ceiling_light_map.light_moved.connect(_move_ceiling_light_from_map)
	light_plan_panel.add_child(ceiling_light_map)

	var buttons := HBoxContainer.new()
	buttons.position = Vector2(12.0, 290.0)
	buttons.size = Vector2(336.0, 32.0)
	light_plan_panel.add_child(buttons)
	for i in range(4):
		var button := Button.new()
		button.text = str(i + 1)
		button.custom_minimum_size = Vector2(78.0, 28.0)
		button.pressed.connect(_select_ceiling_light.bind(i))
		buttons.add_child(button)

	var settings_scroll := ScrollContainer.new()
	settings_scroll.position = Vector2(12.0, 330.0)
	settings_scroll.size = Vector2(336.0, 252.0)
	light_plan_panel.add_child(settings_scroll)
	var settings := VBoxContainer.new()
	settings.custom_minimum_size = Vector2(312.0, 900.0)
	settings_scroll.add_child(settings)
	settings.add_child(_check("ceiling_lights_enabled", "Activer groupe"))
	settings.add_child(_slider("ceiling_light_height", "Hauteur globale", 3.5, 7.0, 0.05))
	settings.add_child(_slider("ceiling_light_range", "Range globale", 4.0, 18.0, 0.1))
	settings.add_child(_slider("ceiling_light_angle", "Angle global", 20.0, 85.0, 1.0))
	settings.add_child(_slider("ceiling_light_blur", "Flou ombre", 0.0, 8.0, 0.1))
	selected_light_title = Label.new()
	selected_light_title.add_theme_font_size_override("font_size", 16)
	settings.add_child(selected_light_title)
	for i in range(4):
		var light_box := VBoxContainer.new()
		light_box.name = "LightControls%d" % (i + 1)
		light_box.add_child(_check(_light_key(i, "enabled"), "Active"))
		light_box.add_child(_slider(_light_key(i, "energy"), "Energie", 0.0, 12.0, 0.01))
		light_box.add_child(_slider(_light_key(i, "x"), "Position X", -10.5, 10.5, 0.05))
		light_box.add_child(_slider(_light_key(i, "z"), "Position Z", -7.2, 7.2, 0.05))
		light_box.add_child(_slider(_light_key(i, "target_x"), "Cible X", -6.7, 6.7, 0.05))
		light_box.add_child(_slider(_light_key(i, "target_z"), "Cible Z", -3.05, 3.05, 0.05))
		settings.add_child(light_box)
	_sync_light_map()
	_select_ceiling_light(0)

func _toggle_light_plan_panel() -> void:
	if light_plan_panel == null:
		return
	light_plan_panel.visible = not light_plan_panel.visible
	if light_plan_panel.visible:
		_sync_light_map()
		_select_ceiling_light(selected_ceiling_light)

func _select_ceiling_light(index: int) -> void:
	selected_ceiling_light = clamp(index, 0, 3)
	if ceiling_light_map != null:
		ceiling_light_map.set_selected(selected_ceiling_light)
	if selected_light_title != null:
		selected_light_title.text = "Lumiere %d" % (selected_ceiling_light + 1)
	var settings := selected_light_title.get_parent()
	if settings != null:
		for child in settings.get_children():
			if child is VBoxContainer and String(child.name).begins_with("LightControls"):
				child.visible = String(child.name) == "LightControls%d" % (selected_ceiling_light + 1)

func _toggle_light_plan_minimized() -> void:
	light_plan_minimized = not light_plan_minimized
	if light_plan_panel == null:
		return
	light_plan_panel.size = Vector2(360.0, 340.0) if light_plan_minimized else Vector2(360.0, 600.0)
	for child in light_plan_panel.get_children():
		if child != light_plan_header and child != ceiling_light_map:
			(child as CanvasItem).visible = not light_plan_minimized

func _on_light_plan_header_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			light_plan_dragging = mouse.pressed
			light_plan_drag_offset = mouse.global_position - light_plan_panel.global_position
	elif event is InputEventMouseMotion and light_plan_dragging:
		var motion := event as InputEventMouseMotion
		light_plan_panel.global_position = motion.global_position - light_plan_drag_offset

func _move_ceiling_light_from_map(index: int, world_x: float, world_z: float) -> void:
	loading_values = true
	_set_control_value(_light_key(index, "x"), world_x)
	_set_control_value(_light_key(index, "z"), world_z)
	loading_values = false
	_apply_all()
	_select_ceiling_light(index)

func _sync_light_map() -> void:
	if ceiling_light_map == null:
		return
	for i in range(4):
		ceiling_light_map.set_light(i, float(_value(_light_key(i, "x"))), float(_value(_light_key(i, "z"))), bool(_value(_light_key(i, "enabled"))))
	ceiling_light_map.set_selected(selected_ceiling_light)

func _light_key(index: int, suffix: String) -> String:
	return "ceiling_light_%d_%s" % [index + 1, suffix]

func _add_section(parent: Control, title: String, items: Array) -> void:
	var button := Button.new()
	button.text = title
	parent.add_child(button)
	var box := VBoxContainer.new()
	box.visible = title in ["Image Quality", "Environment & Post", "Lighting", "Character Shadows"]
	parent.add_child(box)
	sections[title] = box
	button.pressed.connect(func() -> void: box.visible = not box.visible)
	for item in items:
		box.add_child(item as Control)

func _slider(key: String, label_text: String, minimum: float, maximum: float, step: float) -> Control:
	var box := VBoxContainer.new()
	var top := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value_label := Label.new()
	value_label.text = ""
	value_label.custom_minimum_size = Vector2(64, 0)
	top.add_child(label)
	top.add_child(value_label)
	box.add_child(top)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = float(defaults[key])
	box.add_child(slider)
	controls[key] = { "type": "slider", "node": slider, "label": value_label }
	slider.value_changed.connect(func(value: float) -> void:
		value_label.text = "%.3f" % value
		if not loading_values:
			_apply_all()
	)
	value_label.text = "%.3f" % slider.value
	return box

func _check(key: String, label_text: String) -> Control:
	var check := CheckBox.new()
	check.text = label_text
	check.button_pressed = bool(defaults[key])
	controls[key] = { "type": "check", "node": check }
	check.toggled.connect(func(_value: bool) -> void:
		if not loading_values:
			_apply_all()
	)
	return check

func _option(key: String, label_text: String, options: Array[String]) -> Control:
	var box := VBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	box.add_child(label)
	var option := OptionButton.new()
	for item in options:
		option.add_item(item)
	option.selected = int(defaults[key])
	box.add_child(option)
	controls[key] = { "type": "option", "node": option }
	option.item_selected.connect(func(_index: int) -> void:
		if not loading_values:
			_apply_all()
	)
	return box

func _add_button(parent: Control, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)

func _toggle_shadow_probe() -> void:
	if is_instance_valid(shadow_probe_root):
		shadow_probe_root.queue_free()
		shadow_probe_root = null
		_restore_shadow_probe_scene()
		if save_status != null:
			save_status.text = "Test ombre retire"
		return
	var root_3d := _find_3d_root()
	if root_3d == null:
		if save_status != null:
			save_status.text = "Scene 3D introuvable"
		return
	shadow_probe_root = Node3D.new()
	shadow_probe_root.name = "ShadowReceiverProbe"
	root_3d.add_child(shadow_probe_root)
	_prepare_shadow_probe_scene()
	var plate := MeshInstance3D.new()
	plate.name = "ShadowReceiverPlate"
	var plate_mesh := BoxMesh.new()
	plate_mesh.size = Vector3(3.2, 0.035, 3.2)
	plate.mesh = plate_mesh
	plate.global_position = Vector3(0.0, GameConfig.FLOOR_Y + 0.038, 0.0)
	plate.layers = 1
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var plate_mat := StandardMaterial3D.new()
	plate_mat.albedo_color = Color(0.72, 0.72, 0.68, 1.0)
	plate_mat.roughness = 0.86
	plate_mat.disable_receive_shadows = false
	plate.material_override = plate_mat
	shadow_probe_root.add_child(plate)
	var cube := MeshInstance3D.new()
	cube.name = "ShadowCasterCube"
	var cube_mesh := BoxMesh.new()
	cube_mesh.size = Vector3(1.25, 1.25, 1.25)
	cube.mesh = cube_mesh
	cube.global_position = Vector3(0.0, 1.05, 0.0)
	cube.layers = 1
	cube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	var cube_mat := StandardMaterial3D.new()
	cube_mat.albedo_color = Color(1.0, 0.0, 0.85, 1.0)
	cube_mat.roughness = 0.75
	cube_mat.disable_receive_shadows = false
	cube.material_override = cube_mat
	shadow_probe_root.add_child(cube)
	var light := SpotLight3D.new()
	light.name = "ShadowProbeSpotLight"
	light.global_position = Vector3(-3.8, 4.8, -3.0)
	light.look_at(Vector3(0.0, GameConfig.FLOOR_Y, 0.0), Vector3.UP)
	light.light_energy = 10.0
	light.light_bake_mode = Light3D.BAKE_DYNAMIC
	light.light_cull_mask = 1
	light.spot_range = 8.0
	light.spot_angle = 38.0
	light.shadow_enabled = true
	_set_node_property(light, "shadow_blur", 0.2)
	_set_node_property(light, "shadow_bias", 0.002)
	_set_node_property(light, "shadow_normal_bias", 0.05)
	_set_node_property(light, "shadow_opacity", 1.0)
	shadow_probe_root.add_child(light)
	if save_status != null:
		save_status.text = "Mode test actif | %s" % _render_diagnostic_text()

func _show_render_diagnostic() -> void:
	if save_status != null:
		save_status.text = _render_diagnostic_text()

func _render_diagnostic_text() -> String:
	var method := "inconnu"
	var driver := "inconnu"
	if RenderingServer.has_method("get_current_rendering_method"):
		method = str(RenderingServer.call("get_current_rendering_method"))
	if RenderingServer.has_method("get_current_rendering_driver_name"):
		driver = str(RenderingServer.call("get_current_rendering_driver_name"))
	return "Renderer: %s | Driver: %s" % [method, driver]

func _prepare_shadow_probe_scene() -> void:
	shadow_probe_disabled_lights.clear()
	if env_node != null and env_node.environment != null:
		shadow_probe_env_energy = env_node.environment.ambient_light_energy
		env_node.environment.ambient_light_energy = max(shadow_probe_env_energy, 0.22)

func _disable_lights_recursive(node: Node) -> void:
	if node is Light3D and not node.is_ancestor_of(shadow_probe_root):
		var light := node as Light3D
		if light.visible:
			shadow_probe_disabled_lights.append(light)
			light.visible = false
	for child in node.get_children():
		_disable_lights_recursive(child)

func _restore_shadow_probe_scene() -> void:
	for light in shadow_probe_disabled_lights:
		if is_instance_valid(light):
			light.visible = true
	shadow_probe_disabled_lights.clear()
	if env_node != null and env_node.environment != null and shadow_probe_env_energy >= 0.0:
		env_node.environment.ambient_light_energy = shadow_probe_env_energy
	shadow_probe_env_energy = -1.0

func _find_3d_root() -> Node3D:
	var node := get_parent()
	while node != null:
		if node is Node3D:
			return node as Node3D
		node = node.get_parent()
	return get_tree().current_scene as Node3D

func _set_control_value(key: String, value: Variant) -> void:
	if not controls.has(key):
		return
	var entry: Dictionary = controls[key]
	if String(entry["type"]) == "slider":
		var slider := entry["node"] as HSlider
		var label := entry["label"] as Label
		if not is_instance_valid(slider) or not is_instance_valid(label):
			return
		slider.value = float(value)
		label.text = "%.3f" % slider.value
	elif String(entry["type"]) == "check":
		var check := entry["node"] as CheckBox
		if not is_instance_valid(check):
			return
		check.button_pressed = bool(value)
	else:
		var option := entry["node"] as OptionButton
		if not is_instance_valid(option):
			return
		option.selected = int(value)

func _value(key: String) -> Variant:
	if not controls.has(key):
		return defaults[key]
	var entry: Dictionary = controls[key]
	if String(entry["type"]) == "slider":
		var slider := entry["node"] as HSlider
		if is_instance_valid(slider):
			return slider.value
		return defaults[key]
	if String(entry["type"]) == "check":
		var check := entry["node"] as CheckBox
		if is_instance_valid(check):
			return check.button_pressed
		return defaults[key]
	var option := entry["node"] as OptionButton
	if is_instance_valid(option):
		return option.selected
	return defaults[key]

func _apply_all() -> void:
	restore_original_materials()
	_apply_environment()
	_apply_anti_aliasing()
	_apply_lights()
	_apply_realistic_shadows()
	_apply_anime_fx()
	_apply_shuttle()
	_apply_player_materials()
	_apply_material_groups()
	if bool(_value("cel_shading_enabled")):
		apply_cel_shading_settings(_cel_shading_settings())
	if bool(_value("outline_enabled")):
		apply_outline_settings(_outline_settings())

func _apply_environment() -> void:
	if env_node == null or env_node.environment == null:
		return
	var env := env_node.environment
	env.ambient_light_energy = float(_value("env_ambient_energy"))
	env.ambient_light_color = Color(float(_value("env_ambient_r")), float(_value("env_ambient_g")), float(_value("env_ambient_b")))
	env.tonemap_exposure = float(_value("env_exposure"))
	env.glow_enabled = bool(_value("env_glow"))
	env.glow_intensity = float(_value("env_glow_intensity"))
	env.adjustment_enabled = true
	env.adjustment_saturation = float(_value("env_saturation"))
	env.adjustment_contrast = float(_value("env_contrast"))

func _apply_anti_aliasing() -> void:
	var viewport := get_viewport()
	var msaa_values := [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_8X]
	var msaa_index: int = clamp(int(_value("aa_msaa")), 0, msaa_values.size() - 1)
	viewport.msaa_3d = msaa_values[msaa_index]
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if bool(_value("aa_fxaa")) else Viewport.SCREEN_SPACE_AA_DISABLED
	_set_node_property(viewport, "use_taa", bool(_value("aa_taa")))
	var scale_values := [1.0, 1.25, 1.5]
	var scale_index: int = clamp(int(_value("aa_render_scale")), 0, scale_values.size() - 1)
	_set_node_property(viewport, "scaling_3d_scale", scale_values[scale_index])

func _apply_lights() -> void:
	if main_light != null:
		main_light.visible = bool(_value("main_enabled"))
		main_light.light_energy = float(_value("main_energy"))
		main_light.light_color = Color(float(_value("main_r")), float(_value("main_g")), float(_value("main_b")))
		main_light.rotation_degrees = Vector3(float(_value("main_rot_x")), float(_value("main_rot_y")), float(_value("main_rot_z")))
		main_light.shadow_enabled = bool(_value("main_shadow"))
		_set_node_property(main_light, "shadow_bias", float(_value("main_bias")))
		_set_node_property(main_light, "shadow_normal_bias", float(_value("main_normal_bias")))
		_set_node_property(main_light, "shadow_blur", float(_value("main_blur")))
	if fill_light != null:
		fill_light.visible = bool(_value("fill_enabled"))
		fill_light.light_energy = float(_value("fill_energy"))
		fill_light.light_color = Color(float(_value("fill_r")), float(_value("fill_g")), float(_value("fill_b")))
		fill_light.rotation_degrees = Vector3(float(_value("fill_rot_x")), float(_value("fill_rot_y")), float(_value("fill_rot_z")))
		fill_light.shadow_enabled = false
	_apply_ceiling_shadow_lights()

func _apply_realistic_shadows() -> void:
	if not bool(_value("realistic_shadows_enabled")):
		return
	_set_control_value("dynamic_character_shadows_enabled", true)
	_set_control_value("main_shadow", false)
	_set_control_value("main_blur", float(_value("realistic_shadow_blur")))
	_set_control_value("main_bias", float(_value("realistic_shadow_bias")))
	_set_control_value("main_normal_bias", float(_value("realistic_shadow_normal_bias")))
	_set_control_value("main_energy", float(_value("realistic_main_energy")))
	_set_control_value("fill_enabled", true)
	_set_control_value("fill_energy", float(_value("realistic_fill_energy")))
	if main_light != null:
		main_light.shadow_enabled = false
		main_light.light_energy = float(_value("realistic_main_energy"))
		_set_node_property(main_light, "shadow_blur", float(_value("realistic_shadow_blur")))
		_set_node_property(main_light, "shadow_bias", float(_value("realistic_shadow_bias")))
		_set_node_property(main_light, "shadow_normal_bias", float(_value("realistic_shadow_normal_bias")))
	if fill_light != null:
		fill_light.visible = true
		fill_light.light_energy = float(_value("realistic_fill_energy"))
		fill_light.shadow_enabled = false
	_apply_ceiling_shadow_lights()

func _apply_ceiling_shadow_lights() -> void:
	var index := 0
	var light_nodes := get_tree().get_nodes_in_group("ceiling_shadow_lights")
	light_nodes.sort_custom(func(a: Node, b: Node) -> bool: return String(a.name) < String(b.name))
	for node in light_nodes:
		if node is Light3D:
			if index >= 4:
				continue
			var light := node as Light3D
			var enabled := bool(_value("ceiling_lights_enabled")) and bool(_value(_light_key(index, "enabled")))
			light.visible = enabled
			light.light_energy = float(_value(_light_key(index, "energy")))
			light.shadow_enabled = enabled
			if light is SpotLight3D:
				var spot := light as SpotLight3D
				spot.spot_range = float(_value("ceiling_light_range"))
				spot.spot_angle = float(_value("ceiling_light_angle"))
				spot.global_position = Vector3(float(_value(_light_key(index, "x"))), float(_value("ceiling_light_height")), float(_value(_light_key(index, "z"))))
				spot.look_at(Vector3(float(_value(_light_key(index, "target_x"))), GameConfig.FLOOR_Y, float(_value(_light_key(index, "target_z")))), Vector3.UP)
			_set_node_property(light, "shadow_blur", float(_value("realistic_shadow_blur")))
			_set_node_property(light, "shadow_bias", float(_value("realistic_shadow_bias")))
			_set_node_property(light, "shadow_normal_bias", float(_value("realistic_shadow_normal_bias")))
			_set_node_property(light, "shadow_opacity", 1.0)
			index += 1
	for node in get_tree().get_nodes_in_group("gym_fill_lights"):
		if node is Light3D:
			var fill := node as Light3D
			fill.visible = bool(_value("gym_fill_enabled"))
			fill.light_energy = float(_value("gym_fill_energy"))
			fill.shadow_enabled = false
			fill.light_cull_mask = 2
			if fill is SpotLight3D:
				(fill as SpotLight3D).spot_angle = float(_value("gym_fill_angle"))
			elif fill is OmniLight3D:
				(fill as OmniLight3D).omni_range = 12.0
				(fill as OmniLight3D).omni_attenuation = 0.42
	_sync_light_map()

func _apply_anime_fx() -> void:
	var dynamic_shadows := bool(_value("dynamic_character_shadows_enabled")) or bool(_value("realistic_shadows_enabled"))
	for player_node in get_tree().get_nodes_in_group("players"):
		_apply_cast_shadow_recursive(player_node, dynamic_shadows)
	for node in get_tree().get_nodes_in_group("interior_shadow_props"):
		if node is GeometryInstance3D:
			var prop := node as GeometryInstance3D
			prop.layers = 3
			prop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED if dynamic_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for node in get_tree().get_nodes_in_group("gym_shadow_lights"):
		if node is Light3D:
			var light := node as Light3D
			light.visible = dynamic_shadows
			light.shadow_enabled = dynamic_shadows
			light.light_cull_mask = 2
			light.light_energy = float(_value("gym_shadow_energy"))
			light.light_color = Color(float(_value("gym_shadow_r")), float(_value("gym_shadow_g")), float(_value("gym_shadow_b")))
			light.rotation_degrees = Vector3(float(_value("gym_shadow_rot_x")), float(_value("gym_shadow_rot_y")), float(_value("gym_shadow_rot_z")))
			_set_node_property(light, "shadow_blur", float(_value("realistic_shadow_blur")))
			_set_node_property(light, "shadow_bias", float(_value("realistic_shadow_bias")))
			_set_node_property(light, "shadow_normal_bias", float(_value("realistic_shadow_normal_bias")))
			_set_node_property(light, "shadow_opacity", float(_value("gym_shadow_opacity")))
	for node in get_tree().get_nodes_in_group("shuttle_speed_lines"):
		if node.has_method("apply_settings"):
			node.call("apply_settings", _shuttle_speed_lines_settings())
	for node in get_tree().get_nodes_in_group("anime_fx_receivers"):
		if node.has_method("apply_anime_fx_settings"):
			node.call("apply_anime_fx_settings", _racket_impact_fx_settings())
		if node.has_method("apply_landing_marker_settings"):
			node.call("apply_landing_marker_settings", _landing_marker_settings())
	for node in get_tree().get_nodes_in_group("service_shuttle_receivers"):
		if node.has_method("apply_service_shuttle_hold_settings"):
			node.call("apply_service_shuttle_hold_settings", _service_shuttle_hold_settings())
	if main_light != null and dynamic_shadows:
		main_light.shadow_enabled = true

func _shuttle_speed_lines_settings() -> Dictionary:
	return {
		"enabled": bool(_value("shuttle_speed_lines_enabled")),
		"opacity": float(_value("shuttle_speed_lines_opacity")),
		"main_length": float(_value("shuttle_speed_lines_length_main")),
		"width": float(_value("shuttle_speed_lines_width")),
		"color": Color(float(_value("shuttle_speed_lines_r")), float(_value("shuttle_speed_lines_g")), float(_value("shuttle_speed_lines_b")), 1.0)
	}

func _racket_impact_fx_settings() -> Dictionary:
	return {
		"enabled": bool(_value("racket_impact_fx_enabled")),
		"scale": float(_value("racket_impact_fx_scale")),
		"opacity": float(_value("racket_impact_fx_opacity")),
		"duration": float(_value("racket_impact_fx_duration")),
		"color": Color(float(_value("racket_impact_fx_r")), float(_value("racket_impact_fx_g")), float(_value("racket_impact_fx_b")), 1.0),
		"billboard_enabled": bool(_value("racket_impact_fx_billboard_enabled"))
	}

func _landing_marker_settings() -> Dictionary:
	return {
		"enabled": bool(_value("landing_marker_enabled")),
		"delay": float(_value("landing_marker_delay")),
		"duration": float(_value("landing_marker_duration")),
		"opacity": float(_value("landing_marker_opacity")),
		"size_start": float(_value("landing_marker_size_start")),
		"size_end": float(_value("landing_marker_size_end")),
		"color": Color(float(_value("landing_marker_r")), float(_value("landing_marker_g")), float(_value("landing_marker_b")), 1.0),
		"height": float(_value("landing_marker_height"))
	}

func _apply_cast_shadow_recursive(node: Node, enabled: bool) -> void:
	if node is GeometryInstance3D and not _is_racket_related(node) and not node.is_in_group("blob_shadows"):
		var geometry := node as GeometryInstance3D
		geometry.layers = 1
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED if enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_apply_cast_shadow_recursive(child, enabled)

func _apply_shuttle() -> void:
	for node in get_tree().get_nodes_in_group("shuttle"):
		if node.has_node("ShuttleTrail"):
			var trail := node.get_node("ShuttleTrail") as MeshInstance3D
			trail.visible = bool(_value("trail_enabled"))
			trail.material_override = GameConfig.material(Color(float(_value("trail_r")), float(_value("trail_g")), float(_value("trail_b")), float(_value("trail_opacity"))))
		if node.has_node("ShuttleImpactFlash"):
			var impact := node.get_node("ShuttleImpactFlash") as MeshInstance3D
			impact.material_override = GameConfig.material(Color(float(_value("impact_r")), float(_value("impact_g")), float(_value("impact_b")), float(_value("impact_opacity"))))
		if node.has_method("apply_impact_circle_settings"):
			node.call("apply_impact_circle_settings", _impact_circle_settings())
		if node.has_method("set_trail_limit"):
			node.call("set_trail_limit", int(float(_value("trail_length"))))

func _impact_circle_settings() -> Dictionary:
	return {
		"enabled": bool(_value("impact_enabled")),
		"delay": float(_value("impact_delay")),
		"duration": float(_value("impact_duration")),
		"size_start": float(_value("impact_size_start")),
		"size_end": float(_value("impact_size_end")),
		"color": Color(float(_value("impact_r")), float(_value("impact_g")), float(_value("impact_b")), float(_value("impact_opacity")))
	}

func _service_shuttle_hold_settings() -> Dictionary:
	return {
		"kai_forward": float(_value("kai_service_shuttle_forward")),
		"kai_lateral": float(_value("kai_service_shuttle_lateral")),
		"kai_height": float(_value("kai_service_shuttle_height")),
		"kai_rot_x": float(_value("kai_service_shuttle_rot_x")),
		"kai_rot_y": float(_value("kai_service_shuttle_rot_y")),
		"kai_rot_z": float(_value("kai_service_shuttle_rot_z")),
		"mina_forward": float(_value("mina_service_shuttle_forward")),
		"mina_lateral": float(_value("mina_service_shuttle_lateral")),
		"mina_height": float(_value("mina_service_shuttle_height")),
		"mina_rot_x": float(_value("mina_service_shuttle_rot_x")),
		"mina_rot_y": float(_value("mina_service_shuttle_rot_y")),
		"mina_rot_z": float(_value("mina_service_shuttle_rot_z"))
	}

func _apply_material_groups() -> void:
	_apply_named_materials("court", {
		"Surface": float(_value("court_brightness")),
		"CourtLine": float(_value("line_brightness")),
		"Surround": float(_value("blue_border_brightness"))
	})
	_apply_named_materials("gym", {
		"ShortWallUpper": float(_value("wall_brightness")),
		"SideWallUpper": float(_value("wall_brightness")),
		"ShortWallWood": float(_value("wood_brightness")),
		"SideWallWood": float(_value("wood_brightness")),
		"SideCurtainNorth": float(_value("curtain_brightness")),
		"SideCurtainSouth": float(_value("curtain_brightness"))
	})
	_apply_parquet_material()
	_apply_side_wall_texture_height()

func _apply_parquet_material() -> void:
	for node in get_tree().get_nodes_in_group("gym"):
		if not (node is MeshInstance3D) or node.name != "JPWoodFloor":
			continue
		var mesh_node := node as MeshInstance3D
		var mat := _material_for_node(mesh_node)
		if mat == null:
			continue
		var brightness := float(_value("parquet_brightness"))
		var warmth := float(_value("parquet_warmth"))
		var green: float = lerpf(1.0, 0.82, warmth)
		var blue: float = lerpf(1.0, 0.58, warmth)
		mat.albedo_color = Color(
			clamp(brightness, 0.0, 1.0),
			clamp(brightness * green, 0.0, 1.0),
			clamp(brightness * blue, 0.0, 1.0),
			1.0
		)
		mat.roughness = float(_value("parquet_roughness"))
		mat.metallic = 0.0
		mat.metallic_specular = float(_value("parquet_specular"))
		mat.texture_repeat = 1
		var tile_scale := float(_value("parquet_uv_scale"))
		mat.uv1_scale = Vector3(tile_scale, tile_scale, 1.0)
		mesh_node.material_override = mat

func _apply_side_wall_texture_height() -> void:
	var height: float = float(_value("side_wall_texture_height"))
	for node in get_tree().get_nodes_in_group("gym"):
		if not (node is MeshInstance3D):
			continue
		if node.name != "LeftWallTexturePanel" and node.name != "RightWallTexturePanel":
			continue
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh is PlaneMesh:
			var plane := mesh_node.mesh as PlaneMesh
			plane.size = Vector2(14.75, height)
		mesh_node.position.y = height * 0.5

func _apply_named_materials(group_name: String, multipliers: Dictionary) -> void:
	for node in get_tree().get_nodes_in_group(group_name):
		if not (node is MeshInstance3D):
			continue
		var mesh_node := node as MeshInstance3D
		if not multipliers.has(mesh_node.name):
			continue
		var mat := _material_for_node(mesh_node)
		if mat == null:
			continue
		var base_color := _default_color_for_node(mesh_node)
		var saturation := float(_value("court_saturation")) if group_name == "court" else 1.0
		var adjusted := _adjust_color(base_color, float(multipliers[mesh_node.name]), saturation)
		mat.albedo_color = adjusted
		mesh_node.material_override = mat

func _apply_player_materials() -> void:
	for player_node in get_tree().get_nodes_in_group("players"):
		_apply_player_material_recursive(player_node)

func apply_cel_shading_settings(settings: Dictionary) -> void:
	if soft_cel_shader == null:
		return
	var targets := _cel_shading_targets(settings)
	for node in targets:
		if node is MeshInstance3D:
			_apply_soft_cel_to_mesh(node as MeshInstance3D, settings)

func apply_outline_settings(settings: Dictionary) -> void:
	if outline_material_template == null:
		return
	var targets := _outline_targets(settings)
	for node in targets:
		if node is MeshInstance3D:
			_apply_outline_to_mesh(node as MeshInstance3D, settings)

func reset_outline_defaults() -> void:
	for key in ["outline_enabled", "outline_apply_to_characters", "outline_apply_to_racket", "outline_apply_to_shuttle", "outline_apply_to_gym", "outline_thickness", "outline_r", "outline_g", "outline_b", "outline_opacity", "outline_depth_bias", "outline_use_screen_size"]:
		_set_control_value(String(key), defaults[key])
	_apply_all()

func apply_character_material_settings(settings: Dictionary) -> void:
	for player_node in get_tree().get_nodes_in_group("players"):
		_apply_player_material_recursive(player_node)

func restore_original_materials() -> void:
	for key in original_materials.keys():
		var instance_id := int(String(key))
		var node := instance_from_id(instance_id)
		if node is MeshInstance3D:
			var stored: Dictionary = original_materials[key]
			(node as MeshInstance3D).material_override = stored["material_override"] as Material
			(node as MeshInstance3D).material_overlay = stored["material_overlay"] as Material
	original_materials.clear()

func _cel_shading_settings() -> Dictionary:
	return {
		"apply_to_characters": bool(_value("apply_to_characters")),
		"apply_to_court": bool(_value("apply_to_court")),
		"apply_to_gym": bool(_value("apply_to_gym")),
		"apply_to_racket": bool(_value("apply_to_racket")),
		"toon_strength": float(_value("toon_strength")),
		"shadow_steps": int(float(_value("shadow_steps"))),
		"shadow_threshold": float(_value("shadow_threshold")),
		"shadow_softness": float(_value("shadow_softness")),
		"min_shadow_brightness": float(_value("min_shadow_brightness")),
		"max_light_brightness": float(_value("max_light_brightness"))
	}

func _outline_settings() -> Dictionary:
	return {
		"apply_to_characters": bool(_value("outline_apply_to_characters")),
		"apply_to_racket": bool(_value("outline_apply_to_racket")),
		"apply_to_shuttle": bool(_value("outline_apply_to_shuttle")),
		"apply_to_gym": bool(_value("outline_apply_to_gym")),
		"outline_thickness": float(_value("outline_thickness")),
		"outline_color": Color(float(_value("outline_r")), float(_value("outline_g")), float(_value("outline_b")), float(_value("outline_opacity"))),
		"outline_opacity": float(_value("outline_opacity")),
		"outline_depth_bias": float(_value("outline_depth_bias")),
		"outline_use_screen_size": bool(_value("outline_use_screen_size"))
	}

func _cel_shading_targets(settings: Dictionary) -> Array:
	var targets: Array = []
	if bool(settings["apply_to_characters"]):
		for player_node in get_tree().get_nodes_in_group("players"):
			_collect_cel_meshes(player_node, targets, bool(settings["apply_to_racket"]))
	if bool(settings["apply_to_court"]):
		for node in get_tree().get_nodes_in_group("court"):
			if node is MeshInstance3D:
				targets.append(node)
	if bool(settings["apply_to_gym"]):
		for node in get_tree().get_nodes_in_group("gym"):
			if node is MeshInstance3D:
				targets.append(node)
	return targets

func _outline_targets(settings: Dictionary) -> Array:
	var targets: Array = []
	if bool(settings["apply_to_characters"]):
		for player_node in get_tree().get_nodes_in_group("players"):
			_collect_cel_meshes(player_node, targets, bool(settings["apply_to_racket"]))
	if bool(settings["apply_to_shuttle"]):
		for shuttle_node in get_tree().get_nodes_in_group("shuttle"):
			_collect_outline_meshes(shuttle_node, targets)
	if bool(settings["apply_to_gym"]):
		for node in get_tree().get_nodes_in_group("gym"):
			if node is MeshInstance3D and not String(node.name).to_lower().contains("net"):
				targets.append(node)
	return targets

func _collect_cel_meshes(node: Node, targets: Array, include_racket: bool) -> void:
	if node is MeshInstance3D and not node.is_in_group("blob_shadows"):
		var is_racket := _is_racket_related(node)
		if include_racket or not is_racket:
			targets.append(node)
	for child in node.get_children():
		_collect_cel_meshes(child, targets, include_racket)

func _collect_outline_meshes(node: Node, targets: Array) -> void:
	if node is MeshInstance3D and not node.is_in_group("blob_shadows"):
		targets.append(node)
	for child in node.get_children():
		_collect_outline_meshes(child, targets)

func _apply_soft_cel_to_mesh(mesh_node: MeshInstance3D, settings: Dictionary) -> void:
	var key: String = str(mesh_node.get_instance_id())
	if not original_materials.has(key):
		original_materials[key] = {
			"material_override": mesh_node.material_override,
			"material_overlay": mesh_node.material_overlay
		}
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = soft_cel_shader
	mat.set_shader_parameter("albedo_color", _default_color_for_node(mesh_node))
	var albedo_texture: Texture2D = _default_texture_for_node(mesh_node)
	mat.set_shader_parameter("use_albedo_texture", albedo_texture != null)
	if albedo_texture != null:
		mat.set_shader_parameter("albedo_texture", albedo_texture)
	mat.set_shader_parameter("toon_strength", float(settings["toon_strength"]))
	mat.set_shader_parameter("shadow_steps", float(settings["shadow_steps"]))
	mat.set_shader_parameter("shadow_threshold", float(settings["shadow_threshold"]))
	mat.set_shader_parameter("shadow_softness", float(settings["shadow_softness"]))
	mat.set_shader_parameter("min_shadow_brightness", float(settings["min_shadow_brightness"]))
	mat.set_shader_parameter("max_light_brightness", float(settings["max_light_brightness"]))
	mesh_node.material_override = mat
	mesh_node.material_overlay = null

func _apply_outline_to_mesh(mesh_node: MeshInstance3D, settings: Dictionary) -> void:
	var key: String = str(mesh_node.get_instance_id())
	if not original_materials.has(key):
		original_materials[key] = {
			"material_override": mesh_node.material_override,
			"material_overlay": mesh_node.material_overlay
		}
	var mat: ShaderMaterial = outline_material_template.duplicate() as ShaderMaterial
	mat.set_shader_parameter("outline_color", settings["outline_color"])
	mat.set_shader_parameter("outline_thickness", float(settings["outline_thickness"]))
	mat.set_shader_parameter("outline_opacity", float(settings["outline_opacity"]))
	mat.set_shader_parameter("outline_depth_bias", float(settings["outline_depth_bias"]))
	mat.set_shader_parameter("outline_use_screen_size", bool(settings["outline_use_screen_size"]))
	mesh_node.material_overlay = mat

func _apply_player_material_recursive(node: Node) -> void:
	if node is MeshInstance3D and not _is_racket_related(node) and not node.is_in_group("blob_shadows"):
		var mesh_node: MeshInstance3D = node as MeshInstance3D
		var mat: StandardMaterial3D = _material_for_node(mesh_node)
		if mat != null:
			var base_color: Color = _default_color_for_node(mesh_node)
			var multiplier: float = float(_value("player_brightness"))
			var lower_name: String = mesh_node.name.to_lower()
			if lower_name.contains("skin") or lower_name.contains("head") or lower_name.contains("arm") or lower_name.contains("leg"):
				multiplier *= float(_value("skin_brightness"))
			elif lower_name.contains("hair"):
				multiplier *= float(_value("hair_brightness"))
			else:
				multiplier *= float(_value("clothes_brightness"))
			mat.albedo_color = _adjust_color(base_color, multiplier, 1.0)
			mat.roughness = float(_value("character_roughness"))
			mat.metallic = 0.0
			mat.set("specular_mode", BaseMaterial3D.SPECULAR_SCHLICK_GGX)
			mat.set("specular", float(_value("character_specular")))
			mesh_node.material_override = mat
	for child in node.get_children():
		_apply_player_material_recursive(child)

func _material_for_node(mesh_node: MeshInstance3D) -> StandardMaterial3D:
	if mesh_node.material_override is StandardMaterial3D:
		return mesh_node.material_override as StandardMaterial3D
	var active: Material = mesh_node.get_active_material(0)
	if active is StandardMaterial3D:
		var copy: StandardMaterial3D = (active as StandardMaterial3D).duplicate() as StandardMaterial3D
		mesh_node.material_override = copy
		return copy
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mesh_node.material_override = mat
	return mat

func _default_color_for_node(mesh_node: MeshInstance3D) -> Color:
	var key: String = str(mesh_node.get_instance_id())
	if not material_defaults.has(key):
		var color: Color = Color.WHITE
		if mesh_node.material_override is BaseMaterial3D:
			color = (mesh_node.material_override as BaseMaterial3D).albedo_color
		elif mesh_node.get_active_material(0) is BaseMaterial3D:
			color = (mesh_node.get_active_material(0) as BaseMaterial3D).albedo_color
		elif mesh_node.material_override is ShaderMaterial:
			var shader_color: Variant = (mesh_node.material_override as ShaderMaterial).get_shader_parameter("albedo_color")
			if shader_color is Color:
				color = shader_color
		material_defaults[key] = color
	return material_defaults[key]

func _default_texture_for_node(mesh_node: MeshInstance3D) -> Texture2D:
	var key: String = str(mesh_node.get_instance_id())
	if not texture_defaults.has(key):
		var texture: Texture2D = null
		var material: Material = _active_source_material(mesh_node)
		if material is BaseMaterial3D:
			texture = (material as BaseMaterial3D).albedo_texture
		elif material is ShaderMaterial:
			var shader_texture: Variant = (material as ShaderMaterial).get_shader_parameter("albedo_texture")
			if shader_texture is Texture2D:
				texture = shader_texture
		texture_defaults[key] = texture
	return texture_defaults[key] as Texture2D

func _active_source_material(mesh_node: MeshInstance3D) -> Material:
	if mesh_node.material_override != null:
		return mesh_node.material_override
	var active: Material = mesh_node.get_active_material(0)
	if active != null:
		return active
	return null

func _scale_color(color: Color, multiplier: float) -> Color:
	return Color(clamp(color.r * multiplier, 0.0, 1.0), clamp(color.g * multiplier, 0.0, 1.0), clamp(color.b * multiplier, 0.0, 1.0), color.a)

func _adjust_color(color: Color, brightness: float, saturation: float) -> Color:
	var grey: float = color.r * 0.299 + color.g * 0.587 + color.b * 0.114
	var saturated: Color = Color(grey, grey, grey, color.a).lerp(color, saturation)
	return _scale_color(saturated, brightness)

func _is_racket_related(node: Node) -> bool:
	var current: Node = node
	while current != null:
		var lower_name: String = current.name.to_lower()
		if lower_name.contains("racket") or lower_name.contains("raquette"):
			return true
		current = current.get_parent()
	return false

func _set_node_property(node: Object, property_name: String, value: Variant) -> void:
	for property in node.get_property_list():
		if String(property["name"]) == property_name:
			node.set(property_name, value)
			return

func _save_preset() -> void:
	var data: Dictionary = {}
	for key in controls.keys():
		data[key] = _value(String(key))
	data["real_shadow_defaults_version"] = defaults["real_shadow_defaults_version"]
	var json := JSON.stringify(data, "\t")
	var file := FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(json)
		file.close()
		save_status.text = "Selection sauvegardee"

func _load_preset() -> bool:
	if not FileAccess.file_exists(CONFIG_PATH):
		return false
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		return false
	var data: Dictionary = parsed as Dictionary
	var shadow_version: float = 0.0
	if data.has("real_shadow_defaults_version"):
		shadow_version = float(data["real_shadow_defaults_version"])
	if shadow_version < float(defaults["real_shadow_defaults_version"]):
		var shadow_keys: Array[String] = [
			"env_ambient_energy",
			"main_enabled",
			"main_energy",
			"main_shadow",
			"fill_enabled",
			"fill_energy",
			"realistic_shadows_enabled",
			"dynamic_character_shadows_enabled",
			"ceiling_lights_enabled",
			"realistic_shadow_blur",
			"realistic_shadow_bias",
			"realistic_shadow_normal_bias",
			"gym_shadow_energy",
			"gym_shadow_opacity",
			"gym_shadow_rot_x",
			"gym_shadow_rot_y",
			"gym_shadow_rot_z",
			"gym_shadow_r",
			"gym_shadow_g",
			"gym_shadow_b",
			"realistic_main_energy",
			"realistic_fill_energy",
			"ceiling_light_1_enabled",
			"ceiling_light_1_x",
			"ceiling_light_1_z",
			"ceiling_light_1_target_x",
			"ceiling_light_1_target_z",
			"ceiling_light_1_energy",
			"ceiling_light_2_enabled",
			"ceiling_light_2_x",
			"ceiling_light_2_z",
			"ceiling_light_2_target_x",
			"ceiling_light_2_target_z",
			"ceiling_light_2_energy",
			"ceiling_light_3_enabled",
			"ceiling_light_3_x",
			"ceiling_light_3_z",
			"ceiling_light_3_target_x",
			"ceiling_light_3_target_z",
			"ceiling_light_3_energy",
			"ceiling_light_4_enabled",
			"ceiling_light_4_x",
			"ceiling_light_4_z",
			"ceiling_light_4_target_x",
			"ceiling_light_4_target_z",
			"ceiling_light_4_energy",
			"ceiling_light_height",
			"ceiling_light_range",
			"ceiling_light_angle",
			"ceiling_light_blur",
			"ceiling_light_bias",
			"ceiling_light_normal_bias",
			"gym_fill_enabled",
			"gym_fill_energy",
			"gym_fill_angle",
			"real_shadow_defaults_version"
		]
		for shadow_key in shadow_keys:
			if defaults.has(shadow_key):
				data[shadow_key] = defaults[shadow_key]
	loading_values = true
	for key in defaults.keys():
		var value: Variant = data.get(key, defaults[key])
		_set_control_value(String(key), value)
	loading_values = false
	_apply_all()
	if save_status != null:
		save_status.text = "Loaded preset"
	return true

func _panel_style(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style
