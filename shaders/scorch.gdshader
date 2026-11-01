// Burn marks on the ground (explosions, meteors, lightning): one MultiMesh of
// flat quads; INSTANCE_CUSTOM.r is a seed, so every mark has its own shape.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D noise : filter_linear_mipmap, repeat_enable;

varying float seed;

void vertex() {
	seed = INSTANCE_CUSTOM.r;
}

void fragment() {
	vec2 c = UV - 0.5;
	float r = length(c) * 2.0;
	float n = texture(noise, UV * 0.9 + vec2(seed * 7.3, seed * 3.1)).r;
	float ragged = r + (n - 0.5) * 0.55;
	float alpha = 1.0 - smoothstep(0.55, 1.0, ragged);
	// Black soot in the middle, brown charring toward the edge, a few cinders.
	vec3 soot = mix(vec3(0.015, 0.012, 0.01), vec3(0.16, 0.11, 0.07), smoothstep(0.1, 0.95, ragged));
	ALBEDO = soot;
	ROUGHNESS = 1.0;
	ALPHA = alpha * 0.9;
}
