// Flames on burning pieces: a MultiMesh of quads that stay upright and turn
// toward the camera. Each instance's custom data holds a random seed, its
// strength and its size; the shape licks upward through scrolling noise,
// white-yellow at the root, orange, then red at the ragged tips.
shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded, shadows_disabled, fog_disabled;

uniform sampler2D noise : filter_linear_mipmap, repeat_enable;

varying float seed;
varying float power;

void vertex() {
	seed = INSTANCE_CUSTOM.x;
	power = INSTANCE_CUSTOM.y;
	float size = INSTANCE_CUSTOM.z;
	vec3 right = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z) + vec3(0.0001));
	vec3 center = MODEL_MATRIX[3].xyz;
	vec3 world = center + right * VERTEX.x * size + vec3(0.0, (VERTEX.y + 0.5) * size * 1.7, 0.0);
	VERTEX = (inverse(MODEL_MATRIX) * vec4(world, 1.0)).xyz;
}

void fragment() {
	float h = 1.0 - UV.y;
	float x = (UV.x - 0.5) * 2.0;
	float n = texture(noise, vec2(UV.x * 0.7 + seed, UV.y * 0.5 + TIME * 1.5 + seed)).r;
	float n2 = texture(noise, vec2(UV.x * 1.6 - seed, UV.y * 1.2 + TIME * 2.4)).r;
	float width = (1.0 - h) * 0.85 + 0.1;
	float shape = 1.0 - smoothstep(width * 0.55, width, abs(x + (n - 0.5) * 0.6 * h));
	float body = shape * smoothstep(0.0, 0.1, h) * (1.0 - smoothstep(0.45 + n2 * 0.45, 1.0, h + (n - 0.5) * 0.35));
	vec3 col = mix(vec3(0.9, 0.12, 0.02), vec3(1.0, 0.55, 0.08), smoothstep(0.75, 0.2, h));
	col = mix(col, vec3(1.0, 0.92, 0.6), smoothstep(0.5, 1.0, shape) * smoothstep(0.45, 0.05, h));
	ALBEDO = col * 1.6;
	ALPHA = clamp(body * power, 0.0, 1.0);
}
