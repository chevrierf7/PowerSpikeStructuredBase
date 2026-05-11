shader_type spatial;
render_mode diffuse_toon, specular_toon;

uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D albedo_texture : source_color;
uniform bool use_texture = false;
uniform float shade_strength = 0.12;

void fragment() {
	vec4 base = albedo_color;
	if (use_texture) {
		base *= texture(albedo_texture, UV);
	}
	ALBEDO = base.rgb;
	ALPHA = base.a;
	ROUGHNESS = 0.86;
}

void light() {
	float ndotl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float soft_band = smoothstep(0.20, 0.74, ndotl);
	float shade = mix(1.0 - shade_strength, 1.0, soft_band);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * shade;
}
