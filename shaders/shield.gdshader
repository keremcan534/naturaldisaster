shader_type spatial;
// The shield power-up: a see-through bubble, bright at its rim, with bands of
// light running up it. Unshaded, no depth writes; cheap enough for every level.
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform vec3 tint : source_color = vec3(0.3, 0.7, 1.0);

varying float height;

void vertex() {
	height = VERTEX.y;
}

void fragment() {
	float rim = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	rim = rim * rim;
	float band = smoothstep(0.85, 1.0, sin(height * 9.0 - TIME * 4.0));
	ALBEDO = tint * (rim * 1.4 + band * 0.25 + 0.04);
}
