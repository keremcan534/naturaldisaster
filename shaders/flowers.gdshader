// Wild flowers among the grass: a stem and a flat head (petals take the
// instance color, the middle is yellow). They sway with the grass.
shader_type spatial;
render_mode cull_disabled, world_vertex_coords;

global uniform float wind;
global uniform vec3 player_pos;

uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform float fade_end = 34.0;

varying vec3 petal;

void vertex() {
	petal = COLOR.rgb;
	float height = clamp(UV.y, 0.0, 1.0);
	float gust = texture(noise, VERTEX.xz * 0.025 - vec2(TIME * 0.09, TIME * 0.04)).r;
	float sway = (gust * 1.6 - 0.5) * wind + sin(TIME * 2.0 + VERTEX.x) * 0.06;
	VERTEX.xz += normalize(vec2(1.0, 0.4)) * sway * height * 0.12;
	vec2 away = VERTEX.xz - player_pos.xz;
	float near = (1.0 - smoothstep(0.25, 1.0, length(away))) * step(abs(player_pos.y - VERTEX.y), 1.5);
	VERTEX.xz += normalize(away + vec2(0.0001)) * near * height * 0.2;
	float shrink = 1.0 - smoothstep(fade_end - 8.0, fade_end, distance(VERTEX, INV_VIEW_MATRIX[3].xyz));
	VERTEX.y -= (1.0 - shrink) * height * 0.4;
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	if (UV.y < 0.95) {
		ALBEDO = vec3(0.2, 0.38, 0.12);
	} else if (UV.x > 0.5) {
		ALBEDO = vec3(0.95, 0.75, 0.15);
	} else {
		ALBEDO = petal;
	}
	ROUGHNESS = 0.7;
	SPECULAR = 0.2;
}
