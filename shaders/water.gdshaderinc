// Shared water surface. Defines pick the shape:
//   SEA      long Gerstner swells (height from the weather) and foam at the island's shore
//   TSUNAMI  a breaking wave front moving along local +X (see tsunami.gd)
//   CLEAR    see-through (floods)
// Two scrolling noise layers add small ripples; fresnel blends toward the sky.

global uniform vec4 sky_top;
global uniform vec4 sky_horizon;
global uniform vec4 sea_haze;
global uniform float wave_height;
global uniform float island_half;

uniform vec3 deep_color : source_color = vec3(0.02, 0.1, 0.16);
uniform vec3 shallow_color : source_color = vec3(0.05, 0.36, 0.4);
uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform float ripple_scale = 0.06;
uniform float ripple_strength = 0.35;
uniform vec2 flow = vec2(0.0);
uniform float alpha = 0.85;

#ifdef TSUNAMI
uniform float front = 0.0;
uniform float level = 0.0;
uniform float crest_height = 6.0;
uniform float crest_depth = 6.0;
uniform float bottom = -3.0;
// Mesh extent: the water sinks back into the sea toward its sides and back end.
uniform float side_half = 60.0;
uniform float back = -60.0;
#endif

varying vec3 world_pos;
varying vec3 world_normal;
// 0..1: how much of this point is breaking water (crests, shore).
varying float foam_amount;
varying float shallow;

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
	world_normal = vec3(0.0, 1.0, 0.0);
	vec2 to_island = max(abs(wp.xz) - vec2(island_half), vec2(0.0));
	float shore = length(to_island);
	shallow = 1.0 - smoothstep(2.0, 30.0, shore);
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
	foam_amount = smoothstep(0.55, 1.1, offset.y / max(wave_height, 0.05)) * 0.45 * smoothstep(0.6, 1.2, wave_height);
	foam_amount = max(foam_amount, 1.0 - smoothstep(0.0, 3.0, shore));
	VERTEX = (inverse(MODEL_MATRIX) * vec4(wp, 1.0)).xyz;
#endif
#ifdef TSUNAMI
	float s = VERTEX.x;
	float h = wave_profile(s);
	float slope = (wave_profile(s + 0.3) - wave_profile(s - 0.3)) / 0.6;
	float behind = front - s;
	// The lip leans forward over the face.
	float lip = smoothstep(crest_height - 2.5, crest_height, h) * step(-1.5, behind) * step(behind, 2.0);
	float edge = (1.0 - smoothstep(side_half - 18.0, side_half, abs(VERTEX.z))) * smoothstep(back, back + 18.0, s);
	VERTEX.x += lip * 2.2 * edge;
	VERTEX.y = mix(bottom, h, edge);
	world_normal = normalize((MODEL_MATRIX * vec4(-slope, 1.0, 0.0, 0.0)).xyz);
	foam_amount = smoothstep(level + 1.0, crest_height, h) + smoothstep(0.4, 1.5, abs(slope)) * 0.5;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
#endif
	world_pos = wp;
}

float ripples(vec2 p) {
	vec2 q = p - flow * TIME;
	float a = texture(noise, q * ripple_scale + vec2(TIME * 0.012, TIME * 0.007)).r;
	float b = texture(noise, q * ripple_scale * 2.3 - vec2(TIME * 0.009, -TIME * 0.014)).r;
	return a * 0.6 + b * 0.4;
}

void fragment() {
	float e = 0.3;
	vec2 p = world_pos.xz;
#ifdef TSUNAMI
	// The steep face would smear the ripples into streaks; let height vary them too.
	p += vec2(world_pos.y * 1.3);
#endif
	float h = ripples(p);
	// Ripples fade with distance, where they would only alias into sparkles.
	float near = 1.0 - smoothstep(25.0, 160.0, length(world_pos - (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz));
	vec2 slope = vec2(h - ripples(p + vec2(e, 0.0)), h - ripples(p + vec2(0.0, e))) * ripple_strength * near / e * 4.0;
	vec3 n = normalize(world_normal + vec3(slope.x, 0.0, slope.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = 0.04 + 0.96 * pow(1.0 - facing, 5.0);

	vec3 view_world = normalize((INV_VIEW_MATRIX * vec4(-VIEW, 0.0)).xyz);
	vec3 r = reflect(view_world, n);
	vec3 sky = mix(sky_horizon.rgb, sky_top.rgb, pow(clamp(r.y, 0.0, 1.0), 0.5));
	vec3 body = mix(deep_color, shallow_color, shallow * 0.8 + smoothstep(0.45, 0.8, h) * 0.2);

	float foam_noise = texture(noise, p * 0.35 + vec2(TIME * 0.03, 0.0)).r * 0.6 + texture(noise, p * 1.1 - vec2(0.0, TIME * 0.05)).r * 0.4;
	float foam = smoothstep(0.6, 0.8, foam_amount * 0.75 + foam_noise * 0.55) * smoothstep(0.02, 0.2, foam_amount);

	vec3 col = mix(body, sky, fresnel * 0.85);
	col = mix(col, vec3(0.92, 0.95, 0.96), foam);
	ALBEDO = col * 0.75;
	// The reflected sky is light the water sends back by itself, not lit by the sun.
	EMISSION = sky * fresnel * 0.35 * (1.0 - foam);
	ROUGHNESS = mix(0.04, 0.8, foam);
	SPECULAR = 0.7;
#ifdef CLEAR
	ALPHA = mix(alpha, 1.0, max(fresnel, foam));
#endif
}
