// Flat ground surfaces (grass, plaza, paths, roads, cliffs). Detail is sampled in
// world space at two scales so large areas don't show an obvious repeat. Grass
// gets dirt patches and specks; rain darkens everything and fills puddles that
// mirror the sky, rippled by falling drops.
shader_type spatial;

global uniform float wetness;
// A sinkhole: center x, z and radius (see disasters/sinkhole.gd); 0 radius = none.
global uniform vec4 hole;
// Volcanic ash settled on everything, 0..1.
global uniform float ash_cover;
// 0..1: earthquake cracks across the ground (they stay until the next map).
global uniform float cracks;

uniform vec3 tint : source_color = vec3(0.4, 0.6, 0.3);
uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform float scale = 0.12;
uniform float contrast = 0.35;
uniform float roughness_value = 0.9;
// Cliff sides: sample along the wall instead of from above.
uniform bool vertical = false;
// Roads: x is the width, y the length (meters); UV.x runs across, UV.y along.
uniform vec2 road_size = vec2(0.0);
// Soft contact shadow around buildings, trees and cars: center.xy, half size.zw.
uniform vec4 shade_rects[16];
uniform int shade_count = 0;
// Grass ground: bare patches, clover tones and specks.
uniform bool grassy = false;
// How readily puddles form (roads hold more water).
uniform float puddles = 0.5;

#include "res://shaders/sky_common.gdshaderinc"

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Expanding rings where drops land, one per small cell; returns their slope.
vec2 rain_rings(vec2 p) {
	vec2 cell = floor(p * 2.0);
	vec2 local = fract(p * 2.0) - 0.5;
	float h = hash2(cell);
	float t = fract(TIME * 1.4 + h);
	vec2 center = (vec2(hash2(cell + 3.1), hash2(cell + 7.7)) - 0.5) * 0.5;
	vec2 offset = local - center;
	float dist = length(offset);
	float ring = smoothstep(0.035, 0.0, abs(dist - t * 0.4)) * (1.0 - t);
	return offset / max(dist, 0.001) * ring * 0.6;
}

float line(float dist, float half_width) {
	float aa = fwidth(dist) + 0.001;
	return 1.0 - smoothstep(half_width - aa, half_width + aa, dist);
}

void fragment() {
	if (hole.z > 0.0 && !vertical && distance(world_pos.xz, hole.xy) < hole.z) {
		discard;
	}
	vec2 p = vertical ? vec2(world_pos.x + world_pos.z, world_pos.y * 1.6) : world_pos.xz;
	float fine = texture(noise, p * scale).r;
	float broad = texture(noise, p * scale * 0.11 + vec2(0.37, 0.71)).r;
	float d = fine * 0.55 + broad * 0.45;
	vec3 col = tint * (1.0 + (d - 0.5) * 2.0 * contrast);
	float rough = roughness_value;
	if (grassy) {
		// Clover tones: some patches bluer and darker, some yellower.
		float tone = texture(noise, p * 0.045 + vec2(0.13, 0.41)).r;
		col *= mix(vec3(0.85, 0.95, 0.9), vec3(1.15, 1.08, 0.75), smoothstep(0.3, 0.7, tone));
		// Worn earth where the broad noise peaks.
		float bare = smoothstep(0.73, 0.8, broad + fine * 0.15);
		col = mix(col, vec3(0.32, 0.24, 0.16) * (0.8 + fine * 0.4), bare * 0.6);
		// Specks: tiny flowers, seeds and pebbles.
		float speck = quality > 0.5 ? texture(noise, p * 1.7).r : 0.5;
		col = mix(col, vec3(0.9, 0.85, 0.5), smoothstep(0.83, 0.86, speck) * 0.6);
		col *= mix(1.0, 0.7, smoothstep(0.15, 0.1, speck));
	}
	if (road_size.x > 0.0) {
		float across = abs(UV.x - 0.5) * road_size.x;
		float along = UV.y * road_size.y;
		float dash = line(across, 0.08) * step(fract(along / 4.0), 0.55);
		float edge = line(abs(across - (road_size.x * 0.5 - 0.45)), 0.07);
		float paint = max(dash, edge) * mix(0.75, 0.95, fine);
		col = mix(col, vec3(0.86, 0.85, 0.8), paint);
		rough = mix(rough, 0.6, paint);
	}
	if (!vertical && quality > 0.5) {
		for (int i = 0; i < shade_count; i++) {
			vec4 r = shade_rects[i];
			vec2 q = abs(world_pos.xz - r.xy) - r.zw;
			float dist = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0);
			col *= mix(0.5, 1.0, smoothstep(-0.3, 2.4, dist));
		}
	}
	if (wetness > 0.01 && !vertical) {
		// Wet: darker and glossier, and water pools in the low spots.
		col *= mix(1.0, 0.62, wetness);
		rough = mix(rough, 0.35, wetness);
		float low = texture(noise, p * 0.07 + vec2(0.71, 0.19)).r;
		// A few puddles on grass, more on roads.
		float fill = 0.8 - wetness * 0.1 - puddles * 0.1;
		float puddle = smoothstep(fill, fill + 0.04, low) * wetness;
		if (puddle > 0.01) {
			vec2 slope = rain_rings(p) * wetness;
			vec3 n = normalize(vec3(-slope.x, 1.0, -slope.y));
			vec3 cam = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
			vec3 view_dir = normalize(world_pos - cam);
			float fresnel = 0.05 + 0.95 * pow(1.0 - clamp(dot(-view_dir, n), 0.0, 1.0), 5.0);
			vec3 sky = sky_reflection(reflect(view_dir, n), TIME);
			col = mix(col, col * 0.5, puddle);
			EMISSION = sky * fresnel * puddle * 0.8;
			NORMAL = normalize(mix(NORMAL, (VIEW_MATRIX * vec4(n, 0.0)).xyz, puddle));
			rough = mix(rough, 0.03, puddle);
		}
	}
	if (cracks > 0.001 && !vertical) {
		// Cracks follow one contour line of a smooth noise (long winding lines),
		// made jagged by a finer one; they widen as the quake goes on.
		float wide = texture(noise, p * 0.021 + vec2(0.21, 0.67)).r;
		float jag = texture(noise, p * 0.33 + vec2(0.4, 0.9)).r - 0.5;
		float edge = abs(wide - 0.5 + jag * 0.035);
		float w = 0.002 + 0.007 * cracks;
		float crack = 1.0 - smoothstep(w * 0.4, w, edge);
		float rim = (1.0 - smoothstep(w, w * 2.2, edge)) * 0.35;
		col *= 1.0 - clamp(crack * 0.92 + rim, 0.0, 1.0) * smoothstep(0.0, 0.25, cracks);
	}
	ALBEDO = col;
	if (ash_cover > 0.001 && !vertical) {
		float drift = texture(noise, p * 0.05 + vec2(0.13, 0.57)).r;
		ALBEDO = mix(ALBEDO, vec3(0.42, 0.41, 0.4) * (0.85 + drift * 0.3), clamp(ash_cover * (0.7 + drift * 0.6), 0.0, 0.92));
	}
	ROUGHNESS = rough;
	SPECULAR = 0.3;
}
