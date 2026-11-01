// Tornado funnel layer: a lathe mesh (UV.x around, UV.y up the funnel) drawn as
// a soft volume. The axis sways and trails behind (lean), streaks of dust spiral
// upward, and the layer is thickest where you look through its middle. Used twice:
// a dense dark core and a wide, faint dusty sheath with a skirt at the ground.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform vec3 color_low : source_color = vec3(0.38, 0.33, 0.28);
uniform vec3 color_high : source_color = vec3(0.42, 0.44, 0.48);
uniform float density = 0.8;
// Turns of the streak pattern per second at the ground (slower higher up).
uniform float spin = 0.9;
// Top offset (m) relative to the base: the funnel trails its cloud.
uniform vec2 lean = vec2(0.0);
uniform float wobble = 1.0;

varying float height_t;

void vertex() {
	float t = UV.y;
	height_t = t;
	// The whole ring shifts, so the axis bends like a rope.
	vec2 sway = vec2(sin(t * 4.0 + TIME * 0.8) + 0.35 * sin(t * 9.0 - TIME * 1.3),
			cos(t * 3.0 + TIME * 0.6) + 0.3 * cos(t * 7.0 + TIME * 1.1)) * wobble * t;
	VERTEX.xz += lean * t * t + sway;
}

void fragment() {
	float t = height_t;
	vec2 q = vec2(UV.x * 4.0 + TIME * spin * (1.3 - t * 0.7) + t * 2.5, t * 3.0 - TIME * 0.35);
	float n = texture(noise, q * vec2(1.0, 0.6)).r;
	float n2 = texture(noise, q * vec2(2.0, 1.4) + vec2(0.37, TIME * 0.15)).r;
	float streak = smoothstep(0.3, 0.85, n * 0.65 + n2 * 0.5);
	// Thick in the middle of the view, thin at the silhouette: reads as a volume.
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float a = density * mix(0.45, 1.0, streak) * pow(facing, 0.35);
	a *= smoothstep(0.0, 0.05, t) * (1.0 - smoothstep(0.8, 1.0, t));
	vec3 col = mix(color_low, color_high, smoothstep(0.05, 0.7, t)) * mix(0.7, 1.15, streak);
	ALBEDO = col;
	ALPHA = clamp(a, 0.0, 1.0);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
