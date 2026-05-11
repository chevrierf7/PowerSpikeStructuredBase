class_name PlayerCard
extends Button

signal profile_selected(profile: PlayerProfile)

var profile: PlayerProfile
var selected := false
var portrait_rect := TextureRect.new()
var color_strip := ColorRect.new()
var name_label := Label.new()
var style_label := Label.new()
var selected_label := Label.new()

func _ready() -> void:
	custom_minimum_size = Vector2(188, 126)
	size = custom_minimum_size
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	pressed.connect(_on_pressed)
	_build()
	_refresh()

func set_profile(value: PlayerProfile) -> void:
	profile = value
	if is_node_ready():
		_refresh()

func set_selected_state(value: bool) -> void:
	selected = value
	if is_node_ready():
		_refresh()

func _build() -> void:
	color_strip.name = "ColorStrip"
	color_strip.anchor_left = 0.0
	color_strip.anchor_top = 0.0
	color_strip.anchor_right = 0.0
	color_strip.anchor_bottom = 1.0
	color_strip.offset_left = 0.0
	color_strip.offset_top = 0.0
	color_strip.offset_right = 12.0
	color_strip.offset_bottom = 0.0
	color_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(color_strip)
	portrait_rect.name = "Portrait"
	portrait_rect.position = Vector2(22, 18)
	portrait_rect.size = Vector2(52, 52)
	portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(portrait_rect)
	name_label.name = "Name"
	name_label.position = Vector2(82, 20)
	name_label.size = Vector2(96, 34)
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(name_label)
	style_label.name = "Style"
	style_label.position = Vector2(82, 56)
	style_label.size = Vector2(96, 24)
	style_label.add_theme_font_size_override("font_size", 12)
	style_label.add_theme_color_override("font_color", Color(0.72, 0.92, 1.0))
	style_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(style_label)
	selected_label.name = "Selected"
	selected_label.position = Vector2(20, 88)
	selected_label.size = Vector2(148, 24)
	selected_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selected_label.add_theme_font_size_override("font_size", 13)
	selected_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(selected_label)

func _refresh() -> void:
	var primary := Color(0.22, 0.78, 1.0, 1.0)
	var secondary := Color(0.02, 0.05, 0.10, 0.92)
	var accent := Color(1.0, 0.90, 0.25, 1.0)
	var label := "PLAYER"
	var style := "balanced"
	var portrait: Texture2D = null
	if profile != null:
		primary = profile.color_primary
		secondary = profile.color_secondary
		accent = profile.color_accent
		label = profile.safe_name()
		style = profile.play_style
		portrait = profile.portrait
	color_strip.color = primary
	name_label.text = label.to_upper()
	style_label.text = style.to_upper()
	portrait_rect.texture = portrait
	portrait_rect.modulate = primary if portrait == null else Color.WHITE
	selected_label.text = "SÉLECTIONNÉ" if selected else ""
	selected_label.add_theme_color_override("font_color", accent)
	add_theme_stylebox_override("normal", _card_style(secondary, primary, 2 if selected else 1, 4 if selected else 1))
	add_theme_stylebox_override("hover", _card_style(secondary.lightened(0.12), primary.lightened(0.25), 2, 7))
	add_theme_stylebox_override("pressed", _card_style(secondary.darkened(0.10), primary, 2, 2))

func _card_style(fill: Color, border: Color, border_width: int, shadow_size: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(border.r, border.g, border.b, 0.34)
	style.shadow_size = shadow_size
	style.shadow_offset = Vector2(0, 4)
	return style

func _on_pressed() -> void:
	if profile != null:
		profile_selected.emit(profile)
