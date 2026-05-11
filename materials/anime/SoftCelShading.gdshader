shader_type spatial;
render_mode specular_disabled;

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color;
uniform bool use_albedo_texture = false;
uniform float toon_strength : hint_range(0.0, 1.0) = 0.85;
uniform float shadow_steps : hint_range(1.0, 5.0) = 2.0;
uniform float shadow_threshold : hint_range(0.0, 1.0) = 0.45;
uniform float shadow_softness : hint_range(0.0, 1.0) = 0.06;
uniform float min_shadow_brightness : hint_range(0.0, 0.9) = 0.34;
uniform float max_light_brightness : hint_range(0.8, 1.6) = 1.18;

void fragment() {
	vec3 base = albedo_color.rgb;
	if (use_albedo_texture) {
		base *= texture(albedo_texture, UV).rgb;
	}
	ALBEDO = base;
	ROUGHNESS = 0.88;
}

void light() {
	float ndotl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float soft = max(shadow_softness, 0.001);
	float smooth_light = smoothstep(shadow_threshold - soft, shadow_threshold + soft, ndotl);
	float steps = max(shadow_steps, 1.0);
	float stepped = floor(smooth_light * steps) / max(steps - 1.0, 1.0);
	float anime_light = mix(smooth_light, stepped, toon_strength);
	float brightness = mix(min_shadow_brightness, max_light_brightness, anime_light);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * brightness;
}
