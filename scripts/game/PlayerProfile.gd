class_name PlayerProfile
extends Resource

@export var id := ""
@export var display_name := ""
@export var portrait: Texture2D
@export var color_primary := Color(0.22, 0.78, 1.0, 1.0)
@export var color_secondary := Color(0.05, 0.12, 0.20, 1.0)
@export var color_accent := Color(1.0, 0.90, 0.25, 1.0)
@export var outfit_material: Material
@export var racket_material: Material
@export var vroid_avatar_profile: VroidAvatarProfile
@export var banner_texture: Texture2D
@export var ai_style := "balanced"
@export var play_style := "balanced"

func safe_name() -> String:
	return display_name if display_name != "" else id.capitalize()
