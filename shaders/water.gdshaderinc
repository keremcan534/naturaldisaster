// Shared water surface. Defines pick the shape:
//   SEA      long Gerstner swells (height from the weather), foam lapping at the island
//   TSUNAMI  a breaking wave front moving along local +X (see tsunami.gd)
//   CLEAR    see-through (floods)
//   (none)   a pool: calm, with a tiled floor seen through the water
// The look is mostly what water really shows: the sky (with its clouds) mirrored
// by a fresnel term, a sharp sun glint, and a dark body that turns turquoise where
// light passes through crests or the water is shallow.

global uniform float wave_height;
global uniform float island_half;

uniform vec3 deep_color : source_color = vec3(0.01, 0.06, 0.1);
uniform vec3 shallow_color : source_color = vec3(0.05, 0.42, 0.42);
// How mirror-like the surface is (mud and snow barely reflect) and the color
// of its foam.
uniform float reflectivity = 1.0;
uniform vec3 foam_color : source_color = vec3(0.9, 0.93, 0.94);
uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform float ripple_strength = 1.0;
uniform vec2 flow = vec2(0.0);
uniform float alpha = 0.85;

#include "res://shaders/sky_common.gdshaderinc"

#ifdef TSUNAMI
uniform float front = 0.0;
uniform float level = 0.0;
uniform float crest_height = 6.0;
uniform float crest_depth = 6.0;
// How far the breaking lip leans out over the face.
uniform float lip_size = 2.2;
uniform float bottom = -3.0;
// Mesh extent: the water sinks back into the sea toward its sides and back end.
uniform float side_half = 60.0;
uniform float back = -60.0;
#endif

varying vec3 world_pos;
varying vec3 world_normal;
// 0..1: breaking water (crests, the wave lip).
varying float foam_amount;
// Distance (m) from the island's edge, and how high this point rides in its swell.
varying float shore;
varying float crest;

#ifdef SEA
vec3 gerstner(vec2 p, vec2 dir, float wavelength, float steep, inout vec3 tangent, inout vec3 binormal) {
	float k = 6.2832 / wavelength;
	float c = sqrt(9.8 / k);
	vec2 d = normalize(dir);
	float f = k * (dot(d, p) - c * TIME);
	float a = steep / k;
	tangent += vec3(-d.x * d.x * steep * sin(f), d.x * steep * cos(f), -d.x * d.y * steep * sin(f));
	binormal += vec3(-d.x * d.y * steep * sin(f), d.y * steep * cos(f), -d.y * d.y * steep * sin(f));
	return vec3(d.x * a * cos(f), a * sin(f), d.y * a * cos(f));
}
#endif

#ifdef TSUNAMI
// Surface height at distance s along the travel direction.
float wave_profile(float s) {
	float behind = front - s;
	if (behind < 0.0) {
		return mix(crest_height, bottom, smoothstep(0.0, 4.5, -behind));
	}
	float bump = exp(-pow(max(behind - 1.0, 0.0) / (crest_depth * 0.7), 2.0));
	return mix(level, crest_height, bump);
}
#endif

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	foam_amount = 0.0;
	crest = 0.0;
	world_normal = vec3(0.0, 1.0, 0.0);
	shore = length(max(abs(wp.xz) - vec2(island_half), vec2(0.0)));
#ifdef SEA
	// Swells fade out far away (the mesh gets coarse there) and calm near the cliffs.
	float fade = (1.0 - smoothstep(120.0, 380.0, length(wp.xz))) * mix(0.35, 1.0, smoothstep(0.0, 12.0, shore));
	float steep = clamp(wave_height, 0.0, 1.5) * fade;
	vec3 t = vec3(1.0, 0.0, 0.0);
	vec3 b = vec3(0.0, 0.0, 1.0);
	vec3 offset = gerstner(wp.xz, vec2(1.0, 0.35), 34.0, 0.16 * steep, t, b);
	offset += gerstner(wp.xz, vec2(-0.4, 1.0), 21.0, 0.13 * steep, t, b);
	offset += gerstner(wp.xz, vec2(0.75, -0.6), 13.0, 0.1 * steep, t, b);
	offset += gerstner(wp.xz, vec2(-0.9, -0.2), 7.5, 0.07 * steep, t, b);
	wp += offset;
	world_normal = normalize(cross(b, t));
	crest = clamp(offset.y / max(wave_height * 0.9, 0.05), -1.0, 1.0);
	// Whitecaps only once the sea gets rough.
	foam_amount = smoothstep(0.6, 1.0, crest) * smoothstep(0.8, 1.3, wave_height);
	VERTEX = (inverse(MODEL_MATRIX) * vec4(wp, 1.0)).xyz;
#endif
#ifdef TSUNAMI
	float s = VERTEX.x;
	float h = wave_profile(s);
	float slope = (wave_profile(s + 0.3) - wave_profile(s - 0.3)) / 0.6;
	float behind = front - s;
	// The lip leans forward over the face.
	float lip = smoothstep(crest_height - lip_size * 1.15, crest_height, h) * step(-1.5, behind) * step(behind, 2.0);
	float edge = (1.0 - smoothstep(side_half - 18.0, side_half, abs(VERTEX.z))) * smoothstep(back, back + 18.0, s);
	VERTEX.x += lip * lip_size * edge;
	VERTEX.y = mix(bottom, h, edge);
	world_normal = normalize((MODEL_MATRIX * vec4(-slope, 1.0, 0.0, 0.0)).xyz);
	crest = smoothstep(level, crest_height, h);
	foam_amount = smoothstep(0.75, 1.0, crest) + smoothstep(0.6, 1.6, abs(slope)) * 0.6;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
#endif
	world_pos = wp;
}

// Small ripples: a few travelling sines (clean, like real wind ripples) broken up
// by noise. Returns the surface slope (d height / dx, dz).
vec2 ripple_slope(vec2 p) {
	vec2 q = p - flow * TIME;
	vec2 slope = vec2(0.0);
	vec2 dirs[4] = vec2[](vec2(0.8, 0.6), vec2(-0.6, 0.8), vec2(0.96, -0.28), vec2(-0.3, -0.95));
	float lengths[4] = float[](3.1, 2.3, 1.7, 1.15);
	for (int i = 0; i < 4; i++) {
		float k = 6.2832 / lengths[i];
		float phase = k * dot(dirs[i], q) - sqrt(9.8 * k) * TIME;
		slope += dirs[i] * cos(phase) * k * 0.012;
	}
	// Noise breaks the sines up; skipped on low quality.
	if (quality > 0.5) {
		float e = 0.25;
		float n0 = texture(noise, q * 0.05 + vec2(TIME * 0.01, TIME * 0.006)).r;
		float nx = texture(noise, (q + vec2(e, 0.0)) * 0.05 + vec2(TIME * 0.01, TIME * 0.006)).r;
		float nz = texture(noise, (q + vec2(0.0, e)) * 0.05 + vec2(TIME * 0.01, TIME * 0.006)).r;
		slope += vec2(nx - n0, nz - n0) / e * 0.6;
	}
	return slope;
}

void fragment() {
	vec3 cam = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float dist = length(world_pos - cam);
	vec2 p = world_pos.xz;
#ifdef TSUNAMI
	// The steep face would smear ripples into streaks; let height vary them too.
	p += vec2(world_pos.y * 1.3);
#endif
	// Ripples fade with distance, where they would only alias into sparkles.
	float near = 1.0 - smoothstep(20.0, 140.0, dist);
	vec2 slope = ripple_slope(p) * ripple_strength * near;
	vec3 n = normalize(world_normal + vec3(-slope.x, 0.0, -slope.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);

	vec3 view_dir = normalize(world_pos - cam);
	vec3 r = reflect(view_dir, n);
	r.y = abs(r.y);
	float cos_v = clamp(dot(-view_dir, n), 0.0, 1.0);
	float fresnel = (0.02 + 0.98 * pow(1.0 - cos_v, 5.0)) * reflectivity;
	vec3 sky = sky_reflection(r, TIME);

	// Sun glint: a tight hot core and a softer sheen around it.
	float sun_dot = max(dot(r, sun_dir), 0.0);
	vec3 glint = sun_color.rgb * (pow(sun_dot, 900.0) * 30.0 + pow(sun_dot, 80.0) * 0.5);

	// The water's own color: deep blue-green, turquoise in the shallows and where
	// light shines through the thin top of a crest.
	float shallow = 1.0 - smoothstep(1.0, 28.0, shore);
	vec3 body = mix(deep_color, shallow_color, shallow * 0.75);
	float through = max(crest, 0.0) * (0.4 + 0.6 * max(dot(view_dir, sun_dir) * -1.0 + 0.3, 0.0));
	body += shallow_color * through * 0.35;
#if !defined(SEA) && !defined(TSUNAMI)
	// Pool: light tiles under clear water, wobbling with the surface.
	vec2 tile = (p + slope * 0.6) * 2.0;
	float grout = smoothstep(0.0, 0.06, min(fract(tile.x), fract(tile.y)));
	body = mix(shallow_color * 0.55, shallow_color * 1.25, grout);
	fresnel *= 0.8;
#endif

	// Foam: whitecaps and, on the sea, lines lapping onto the island.
	float bubbles = texture(noise, p * 0.35 + vec2(TIME * 0.03, 0.0)).r * 0.6 + texture(noise, p * 1.3 - vec2(0.0, TIME * 0.05)).r * 0.4;
	float foam = smoothstep(0.55, 0.85, foam_amount * 0.7 + bubbles * 0.5) * step(0.02, foam_amount);
#ifdef SEA
	float lap = sin(shore * 1.4 - TIME * 1.6 + bubbles * 3.0) * 0.5 + 0.5;
	float shore_foam = (1.0 - smoothstep(0.0, 6.0, shore)) * smoothstep(0.35, 0.75, lap * 0.6 + bubbles * 0.6);
	foam = max(foam, shore_foam * 0.9);
#endif

	ALBEDO = mix(body * (1.0 - fresnel), foam_color, foam);
	EMISSION = (sky * fresnel + glint) * (1.0 - foam);
	ROUGHNESS = mix(0.25, 0.9, foam);
	SPECULAR = 0.0;
#ifdef CLEAR
	ALPHA = mix(alpha, 1.0, max(fresnel, foam));
#endif
}
