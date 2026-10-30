// Flat ground surfaces (grass, plaza, paths, roads, cliffs). Detail is sampled in
// world space at two scales so large areas don't show an obvious repeat.
shader_type spatial;

uniform vec3 tint : source_color = vec3(0.4, 0.6, 0.3);
uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform float scale = 0.12;
uniform float contrast = 0.35;
uniform float roughness_value = 0.9;
// Cliff sides: sample along the wall instead of from above.
uniform bool vertical = false;
// Roads: x is the width, y the length (meters); UV.x runs across, UV.y along.
uniform vec2 road_size = vec2(0.0);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float line(float dist, float half_width) {
	float aa = fwidth(dist) + 0.001;
	return 1.0 - smoothstep(half_width - aa, half_width + aa, dist);
}

void fragment() {
	vec2 p = vertical ? vec2(world_pos.x + world_pos.z, world_pos.y * 1.6) : world_pos.xz;
	float fine = texture(noise, p * scale).r;
	float broad = texture(noise, p * scale * 0.11 + vec2(0.37, 0.71)).r;
	float d = fine * 0.55 + broad * 0.45;
	vec3 col = tint * (1.0 + (d - 0.5) * 2.0 * contrast);
	float rough = roughness_value;
	if (road_size.x > 0.0) {
		float across = abs(UV.x - 0.5) * road_size.x;
		float along = UV.y * road_size.y;
		float dash = line(across, 0.08) * step(fract(along / 4.0), 0.55);
		float edge = line(abs(across - (road_size.x * 0.5 - 0.45)), 0.07);
		float paint = max(dash, edge) * mix(0.75, 0.95, fine);
		col = mix(col, vec3(0.86, 0.85, 0.8), paint);
		rough = mix(rough, 0.6, paint);
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.3;
}
