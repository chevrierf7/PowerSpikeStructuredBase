shader_type spatial;
render_mode unshaded, cull_front, depth_draw_always, blend_mix;

uniform vec4 outline_color : source_color = vec4(0.12, 0.13, 0.14, 0.75);
uniform float outline_thickness : hint_range(0.0, 3.0) = 0.7;
uniform float outline_opacity : hint_range(0.0, 1.0) = 0.75;
uniform float outline_depth_bias : hint_range(0.0, 0.05) = 0.005;
uniform bool outline_use_screen_size = true;

void vertex() {
	float scale = outline_use_screen_size ? 0.018 : 0.012;
	VERTEX += NORMAL * outline_thickness * scale;
	VERTEX += normalize(VERTEX) * outline_depth_bias;
}

void fragment() {
	ALBEDO = outline_color.rgb;
	ALPHA = outline_color.a * outline_opacity;
}
