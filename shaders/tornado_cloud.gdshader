// The rotating wall cloud over a tornado: a flat disk whose noise is sampled in
// polar coordinates turning faster near the middle, so spiral bands wind inward.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform vec3 color : source_color = vec3(0.2, 0.21, 0.24);
uniform float opacity = 0.9;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float turn = atan(p.y, p.x) + TIME * 0.35 / (0.2 + r) + r * 3.0;
	vec2 q = vec2(cos(turn), sin(turn)) * r;
	float n = texture(noise, q * 1.3 + vec2(0.5)).r * 0.6 + texture(noise, q * 3.1 + vec2(0.2, TIME * 0.01)).r * 0.4;
	// Dense over the funnel, ragged toward the rim.
	float a = smoothstep(1.0, 0.45, r) * mix(smoothstep(0.25, 0.7, n), 1.0, smoothstep(0.35, 0.0, r));
	ALBEDO = color * mix(0.65, 1.1, n) * mix(0.7, 1.0, r);
	ALPHA = a * opacity;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
