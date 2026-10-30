// Grass tufts (one MultiMesh per map). Blades bend with gusts that roll across the
// map; the weather sets how hard. Far tufts shrink away to save fill rate.
shader_type spatial;
render_mode cull_disabled, world_vertex_coords;

global uniform float wind;

uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform vec3 root_color : source_color = vec3(0.16, 0.28, 0.1);
uniform vec3 tip_color : source_color = vec3(0.45, 0.58, 0.26);
uniform float fade_start = 28.0;
uniform float fade_end = 42.0;

varying float tip;
varying vec3 world_pos;

void vertex() {
	tip = clamp(UV.y, 0.0, 1.0);
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	float gust = texture(noise, VERTEX.xz * 0.025 - vec2(TIME * 0.09, TIME * 0.04)).r;
	vec2 dir = normalize(vec2(1.0, 0.4));
	float sway = (gust * 1.6 - 0.5) * wind + sin(TIME * 2.3 + VERTEX.x * 0.7 + VERTEX.z * 0.4) * 0.08;
	float bend = tip * tip;
	VERTEX.xz += dir * sway * bend * 0.45;
	VERTEX.y -= abs(sway) * bend * 0.12;
	float shrink = 1.0 - smoothstep(fade_start, fade_end, distance(VERTEX, cam));
	VERTEX.y = mix(VERTEX.y - tip * 0.6, VERTEX.y, shrink);
	NORMAL = vec3(0.0, 1.0, 0.0);
	world_pos = VERTEX;
}

void fragment() {
	float patch = texture(noise, world_pos.xz * 0.012).r;
	vec3 col = mix(root_color, tip_color * mix(0.8, 1.15, patch), tip);
	ALBEDO = col;
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
}
