// Flowing lava: a dark crust broken by bright, slowly moving cracks.
shader_type spatial;

uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform float energy = 3.0;
uniform vec2 flow = vec2(0.0, 0.6);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz - flow * TIME;
	float a = texture(noise, p * 0.06).r;
	float b = texture(noise, p * 0.17 + vec2(TIME * 0.03, 0.0)).r;
	float heat = smoothstep(0.42, 0.62, a * 0.6 + b * 0.4);
	vec3 hot = mix(vec3(1.0, 0.25, 0.02), vec3(1.0, 0.75, 0.2), heat * heat);
	ALBEDO = mix(vec3(0.08, 0.04, 0.03), hot, heat);
	EMISSION = hot * heat * energy;
	ROUGHNESS = mix(0.9, 0.4, heat);
}
