shader_type spatial;
render_mode unshaded, blend_mul, depth_draw_never, depth_test_disabled, cull_disabled;

uniform vec4 shadow_color : source_color = vec4(0.20, 0.10, 0.035, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.35;
uniform float softness : hint_range(0.01, 1.0) = 0.34;

void fragment() {
	vec2 centered_uv = UV * 2.0 - vec2(1.0);
	float radius = length(centered_uv);
	float alpha = smoothstep(1.0, softness, radius) * opacity;
	ALBEDO = mix(vec3(1.0), shadow_color.rgb, alpha * shadow_color.a);
	ALPHA = 1.0;
}
