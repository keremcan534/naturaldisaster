// Grass tufts (one MultiMesh per map). Blades bend with gusts that roll across the
// map (the weather sets how hard) and away from the player's legs; each tuft has
// its own shade of green, tips glow when the sun is behind them, rain darkens
// them, and far tufts shrink away to save fill rate.
shader_type spatial;
render_mode cull_disabled, world_vertex_coords;

global uniform float wind;
global uniform float wetness;
global uniform vec3 player_pos;
global uniform vec3 sun_dir;
global uniform vec4 sun_color;

uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform vec3 root_color : source_color = vec3(0.16, 0.28, 0.1);
uniform vec3 tip_color : source_color = vec3(0.45, 0.58, 0.26);
uniform float fade_start = 28.0;
uniform float fade_end = 42.0;

varying float tip;
varying float variety;
varying vec3 world_pos;

void vertex() {
	tip = clamp(UV.y, 0.0, 1.0);
	vec3 root = MODEL_MATRIX[3].xyz;
	variety = fract(sin(dot(root.xz, vec2(12.9898, 78.233))) * 43758.5453);
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	float bend = tip * tip;

	float gust = texture(noise, VERTEX.xz * 0.025 - vec2(TIME * 0.09, TIME * 0.04)).r;
	vec2 dir = normalize(vec2(1.0, 0.4));
	float sway = (gust * 1.6 - 0.5) * wind + sin(TIME * 2.3 + VERTEX.x * 0.7 + VERTEX.z * 0.4) * 0.08;
	VERTEX.xz += dir * sway * bend * 0.45;
	VERTEX.y -= abs(sway) * bend * 0.12;

	// Pushed aside where the player walks.
	vec2 away = VERTEX.xz - player_pos.xz;
	float near = (1.0 - smoothstep(0.25, 1.2, length(away))) * step(abs(player_pos.y - root.y), 1.2);
	VERTEX.xz += normalize(away + vec2(0.0001)) * near * bend * 0.4;
	VERTEX.y -= near * bend * 0.2;

	float shrink = 1.0 - smoothstep(fade_start, fade_end, distance(VERTEX, cam));
	VERTEX.y = mix(VERTEX.y - tip * 0.6, VERTEX.y, shrink);
	NORMAL = vec3(0.0, 1.0, 0.0);
	world_pos = VERTEX;
}

void fragment() {
	float patch = texture(noise, world_pos.xz * 0.012).r;
	// Each tuft leans yellow, mid or blue-green.
	vec3 shade = mix(vec3(1.18, 1.1, 0.72), vec3(0.82, 1.0, 1.05), variety);
	vec3 col = mix(root_color, tip_color * shade * mix(0.8, 1.15, patch), tip);
	col *= mix(1.0, 0.72, wetness);
	ALBEDO = col;
	ROUGHNESS = mix(0.85, 0.45, wetness);
	SPECULAR = 0.2;
	// Light shining through thin blades when looking toward the sun.
	vec3 cam = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float back = pow(max(dot(normalize(world_pos - cam), sun_dir), 0.0), 4.0);
	EMISSION = tip_color * shade * sun_color.rgb * back * tip * 0.45;
}
