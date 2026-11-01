// Drops of water on the camera lens: rain while out in the open, and streaks
// running down right after coming up out of water. Two layers of drops (big and
// small) in grid cells; each lives a moment, slides a little and fades.
// Include with LITE defined for the cheap version (no refraction).

#ifndef LITE
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
#endif
// 0..1 rain on the lens, 0..1 just out of the water.
uniform float amount = 0.0;
uniform float splash = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Returns (offset.xy, coverage) for one layer of drops.
vec3 drops(vec2 uv, float cells, float speed, float chance, float seed) {
	vec2 g = uv * cells;
	g.y -= TIME * speed;
	vec2 cell = floor(g);
	vec2 f = fract(g) - 0.5;
	float h = hash(cell + seed);
	float life = fract(TIME * (0.25 + h * 0.35) + h * 7.0);
	float present = step(1.0 - chance, hash(cell + seed + 19.7 + floor(TIME * (0.25 + h * 0.35) + h * 7.0)));
	vec2 center = vec2(hash(cell + seed + 1.7) - 0.5, hash(cell + seed + 4.3) - 0.5) * 0.5;
	// Drops sag downward as they age: a short tail above them.
	vec2 d = f - center - vec2(0.0, life * 0.15);
	d.y *= mix(1.0, 0.55, step(0.0, -d.y) * life);
	float radius = 0.22 * (1.0 - life * 0.4);
	float cover = smoothstep(radius, radius * 0.55, length(d)) * present * (1.0 - life * life);
	return vec3(d * cover, cover);
}

void fragment() {
	vec2 aspect = vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	vec2 uv = SCREEN_UV * aspect;
	vec3 a = drops(uv, 7.0, 0.02, amount * 0.55 + splash * 0.9, 0.0);
	vec3 b = drops(uv, 15.0, 0.05 + splash * 0.4, amount * 0.6 + splash, 31.0);
	vec2 offset = (a.xy / 7.0 + b.xy / 15.0) * 1.6;
	float cover = clamp(a.z + b.z, 0.0, 1.0);
	// A soft film over everything right after surfacing.
	float film = splash * 0.35;
#ifdef LITE
	COLOR = vec4(vec3(0.85, 0.9, 0.95), cover * 0.22 + film * 0.3);
#else
	vec3 behind = textureLod(screen, SCREEN_UV - offset / aspect, film * 2.5).rgb;
	// The lit rim of each drop.
	behind += vec3(0.08) * smoothstep(0.3, 0.9, cover) * (1.0 - smoothstep(0.9, 1.0, cover));
	COLOR = vec4(behind, max(cover, film));
#endif
}
