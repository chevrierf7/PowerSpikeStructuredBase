class_name PlayerSelectScreen
extends Control

signal selection_confirmed(settings: Dictionary)
signal cancelled

const PLAYER_CARD_SCENE := preload("res://scenes/ui/PlayerCard.tscn")
const PLAYER_PATHS := [
	"res://data/players/kai.tres",
	"res://data/players/mina.tres",
	"res://data/players/akiro.tres",
	"res://data/players/kaede.tres",
	"res://data/players/shiro.tres",
	"res://data/players/mei.tres",
	"res://data/players/taro.tres",
	"res://data/players/sora.tres",
	"res://data/players/kenta.tres",
	"res://data/players/riku.tres"
]

var profiles: Array[PlayerProfile] = []
var cards: Array[PlayerCard] = []
var selected_p1: PlayerProfile
var selected_p2: PlayerProfile
var selecting_player_1 := true
var match_settings := {}
var title_label := Label.new()
var hint_label := Label.new()
var launch_button := Button.new()
var ai_toggle := Button.new()
var ai_match := true

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_profiles()
	_build()
	_select_defaults()
	_refresh_cards()

func setup(settings: Dictionary) -> void:
	match_settings = settings.duplicate()
	ai_match = bool(settings.get("is_ai_match", true))
	if is_node_ready():
		_refresh_header()

func _load_profiles() -> void:
	profiles.clear()
	for path in PLAYER_PATHS:
		var loaded := load(path)
		if loaded is PlayerProfile:
			profiles.append(loaded)

func _build() -> void:
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.012, 0.035, 0.90)
	add_child(shade)
	var panel := Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -525.0
	panel.offset_top = -316.0
	panel.offset_right = 525.0
	panel.offset_bottom = 316.0
	panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(panel)
	title_label.position = Vector2(34, 24)
	title_label.size = Vector2(720, 42)
	title_label.text = "SÉLECTION JOUEURS"
	title_label.add_theme_font_size_override("font_size", 34)
	title_label.add_theme_color_override("font_color", Color(0.90, 0.98, 1.0))
	panel.add_child(title_label)
	hint_label.position = Vector2(36, 68)
	hint_label.size = Vector2(810, 30)
	hint_label.add_theme_font_size_override("font_size", 18)
	hint_label.add_theme_color_override("font_color", Color(0.72, 0.90, 1.0))
	panel.add_child(hint_label)
	var grid := GridContainer.new()
	grid.name = "PlayersGrid"
	grid.columns = 5
	grid.position = Vector2(34, 118)
	grid.size = Vector2(982, 278)
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 12)
	panel.add_child(grid)
	for profile in profiles:
		var card := PLAYER_CARD_SCENE.instantiate() as PlayerCard
		card.set_profile(profile)
		card.profile_selected.connect(_on_profile_selected)
		cards.append(card)
		grid.add_child(card)
	ai_toggle = _make_button("ADVERSAIRE IA", Vector2(34, 442), Vector2(210, 44), _toggle_ai_match)
	panel.add_child(ai_toggle)
	var back_button := _make_button("RETOUR", Vector2(594, 442), Vector2(170, 44), func() -> void: cancelled.emit())
	panel.add_child(back_button)
	launch_button = _make_button("LANCER MATCH", Vector2(784, 432), Vector2(232, 58), _confirm_selection)
	launch_button.add_theme_font_size_override("font_size", 22)
	panel.add_child(launch_button)
	_refresh_header()

func _select_defaults() -> void:
	selected_p1 = profiles[0] if profiles.size() > 0 else null
	selected_p2 = profiles[1] if profiles.size() > 1 else selected_p1

func _on_profile_selected(profile: PlayerProfile) -> void:
	if selecting_player_1:
		selected_p1 = profile
		if selected_p2 == selected_p1:
			selected_p2 = _first_profile_except(selected_p1)
		selecting_player_1 = false
	else:
		if profile != selected_p1:
			selected_p2 = profile
		selecting_player_1 = true
	_refresh_cards()

func _first_profile_except(profile: PlayerProfile) -> PlayerProfile:
	for candidate in profiles:
		if candidate != profile:
			return candidate
	return profile

func _toggle_ai_match() -> void:
	ai_match = not ai_match
	_refresh_header()

func _confirm_selection() -> void:
	var selection := get_node_or_null("/root/GameSelection")
	if selection != null:
		selection.set_players(selected_p1, selected_p2)
		selection.match_mode = String(match_settings.get("mode", "singles"))
		selection.is_ai_match = ai_match
	selection_confirmed.emit(match_settings)

func _refresh_cards() -> void:
	for card in cards:
		card.set_selected_state(card.profile == selected_p1 or card.profile == selected_p2)
	_refresh_header()

func _refresh_header() -> void:
	var p1_name := selected_p1.safe_name() if selected_p1 != null else "Kai"
	var p2_name := selected_p2.safe_name() if selected_p2 != null else "Mina"
	hint_label.text = "J1: %s  /  J2: %s  /  Prochain choix: %s" % [p1_name, p2_name, "Joueur 1" if selecting_player_1 else "Joueur 2"]
	ai_toggle.text = "ADVERSAIRE IA: ON" if ai_match else "ADVERSAIRE IA: OFF"

func _make_button(text: String, pos: Vector2, size_value: Vector2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = pos
	button.size = size_value
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_stylebox_override("normal", _button_style(Color(0.025, 0.050, 0.085, 0.92), Color(0.30, 0.78, 1.0, 0.44), 2))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.035, 0.090, 0.145, 0.98), Color(0.55, 0.95, 1.0, 0.82), 6))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.015, 0.032, 0.065, 1.0), Color(0.28, 0.72, 1.0, 0.62), 1))
	button.pressed.connect(callback)
	return button

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.010, 0.030, 0.065, 0.92)
	style.border_color = Color(0.34, 0.86, 1.0, 0.72)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0.0, 0.12, 0.22, 0.55)
	style.shadow_size = 22
	style.shadow_offset = Vector2(0, 8)
	return style

func _button_style(fill: Color, border: Color, shadow: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.shadow_color = Color(0.20, 0.82, 1.0, 0.32)
	style.shadow_size = shadow
	return style
