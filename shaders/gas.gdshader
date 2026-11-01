// A heavy toxic cloud filling the island up to "top": a box drawn from both
// sides, so standing inside it tints everything; thicker near the ground,
// swirling slowly, with a ragged upper surface.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, unshaded;

uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform float top = 1.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz * 0.04 + vec2(TIME * 0.01, TIME * 0.006);
	float n = texture(noise, p).r * 0.6 + texture(noise, p * 3.0 - vec2(TIME * 0.02, 0.0)).r * 0.4;
	float depth = clamp(1.0 - world_pos.y / max(top, 0.01), 0.0, 1.0);
	ALBEDO = mix(vec3(0.42, 0.62, 0.12), vec3(0.62, 0.78, 0.25), n);
	ALPHA = clamp(0.22 + depth * 0.25 + (n - 0.5) * 0.25, 0.05, 0.6);
}
