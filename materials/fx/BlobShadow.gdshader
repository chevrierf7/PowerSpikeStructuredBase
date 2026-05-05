shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled;

uniform vec4 shadow_color : source_color = vec4(0.12, 0.075, 0.045, 0.30);
uniform float opacity : hint_range(0.0, 1.0) = 0.30;

void fragment() {
	vec2 centered_uv = UV * 2.0 - vec2(1.0);
	float radius = length(centered_uv);
	float core = smoothstep(0.70, 0.05, radius);
	float feather = smoothstep(1.0, 0.35, radius) * 0.65;
	float alpha = max(core, feather) * opacity;
	ALBEDO = shadow_color.rgb;
	ALPHA = alpha * shadow_color.a;
}
