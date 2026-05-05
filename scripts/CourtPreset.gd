class_name CourtPreset
extends RefCounted

const JP_WOOD_CLASSIC := "JP_Wood_Classic"
const JP_BLUE_COURT := "JP_Blue_Court"
const JP_GREEN_COURT := "JP_Green_Court"
const JP_ORANGE_ARCADE := "JP_Orange_Arcade"

static func court(preset_name: String = JP_ORANGE_ARCADE) -> Dictionary:
	match preset_name:
		JP_WOOD_CLASSIC:
			return {
				"surround": Color(0.76, 0.56, 0.34),
				"surface": Color(0.70, 0.45, 0.22),
				"line": Color(0.93, 0.94, 0.88),
				"net_post": Color(0.78, 0.82, 0.84),
				"net_band": Color(0.98, 0.98, 0.94),
				"net_cord": Color(0.92, 0.94, 0.96, 0.38)
			}
		JP_BLUE_COURT:
			return {
				"surround": Color(0.18, 0.42, 0.52),
				"surface": Color(0.08, 0.32, 0.62),
				"line": Color(0.94, 0.95, 0.89),
				"net_post": Color(0.80, 0.84, 0.86),
				"net_band": Color(0.98, 0.98, 0.94),
				"net_cord": Color(0.90, 0.93, 0.96, 0.38)
			}
		JP_GREEN_COURT:
			return {
				"surround": Color(0.18, 0.36, 0.30),
				"surface": Color(0.08, 0.46, 0.32),
				"line": Color(0.94, 0.95, 0.89),
				"net_post": Color(0.80, 0.84, 0.82),
				"net_band": Color(0.98, 0.98, 0.94),
				"net_cord": Color(0.90, 0.94, 0.92, 0.38)
			}
		_:
			return {
				"surround": Color(0.18, 0.35, 0.43),
				"surface": Color(0.78, 0.42, 0.18),
				"line": Color(0.95, 0.95, 0.88),
				"net_post": Color(0.82, 0.85, 0.86),
				"net_band": Color(0.98, 0.98, 0.94),
				"net_cord": Color(0.86, 0.90, 0.93, 0.34)
			}

static func gym(preset_name: String = JP_WOOD_CLASSIC) -> Dictionary:
	match preset_name:
		JP_BLUE_COURT:
			return { "floor": Color(0.74, 0.55, 0.35), "wood": Color(0.42, 0.27, 0.16), "wall": Color(0.70, 0.72, 0.68), "ceiling": Color(0.08, 0.09, 0.10), "light": 1.25 }
		JP_GREEN_COURT:
			return { "floor": Color(0.72, 0.54, 0.34), "wood": Color(0.38, 0.26, 0.16), "wall": Color(0.70, 0.73, 0.69), "ceiling": Color(0.07, 0.085, 0.085), "light": 1.20 }
		JP_ORANGE_ARCADE:
			return { "floor": Color(0.76, 0.56, 0.34), "wood": Color(0.34, 0.20, 0.10), "wall": Color(0.84, 0.82, 0.76), "ceiling": Color(0.055, 0.06, 0.07), "light": 1.12 }
		_:
			return { "floor": Color(0.76, 0.58, 0.37), "wood": Color(0.34, 0.21, 0.12), "wall": Color(0.84, 0.83, 0.78), "ceiling": Color(0.055, 0.06, 0.07), "light": 1.05 }

static func material(color: Color, roughness: float = 0.82) -> Material:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
	return mat
