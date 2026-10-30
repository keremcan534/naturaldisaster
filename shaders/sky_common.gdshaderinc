// The sky as a function of direction, shared by the sky itself and by everything
// that reflects it (water, glass, puddles). Values come from the weather as global
// uniforms; the night sky, aurora and rainbow cost nothing while they are off.
// The including shader must declare `uniform sampler2D noise`.

global uniform vec4 sky_top;
global uniform vec4 sky_horizon;
global uniform vec4 sea_haze;
// Direction toward the sun (the moon at night), and its color times energy.
global uniform vec3 sun_dir;
global uniform vec4 sun_color;
global uniform float cloud_cover;
global uniform vec4 cloud_light;
global uniform vec4 cloud_dark;
// 0..1: night (the light disk is the moon), stars, aurora and rainbow strength.
global uniform float night;
global uniform float stars;
global uniform float aurora;
global uniform float rainbow;

float sky_hash(vec3 p) {
	p = fract(p * vec3(443.897, 441.423, 437.195));
	p += dot(p, p.yzx + 19.19);
	return fract((p.x + p.y) * p.z);
}

float sky_cloud_noise(vec2 uv) {
	float n = texture(noise, uv * 0.11).r * 0.55;
	n += texture(noise, uv * 0.33 + vec2(0.31, 0.17)).r * 0.3;
	n += texture(noise, uv * 1.1 + vec2(0.71, 0.53)).r * 0.15;
	return n;
}

// Point stars on a grid of cells around the viewer, twinkling, plus a faint band
// of the Milky Way.
vec3 sky_stars(vec3 d, float time) {
	vec3 p = d * 230.0;
	vec3 cell = floor(p);
	float h = sky_hash(cell);
	vec3 col = vec3(0.0);
	if (h > 0.99) {
		float r = length(fract(p) - 0.5);
		float bright = (h - 0.99) / 0.01;
		float twinkle = 0.75 + 0.25 * sin(time * (1.5 + bright * 6.0) + h * 300.0);
		vec3 star_color = mix(vec3(0.75, 0.85, 1.0), vec3(1.0, 0.9, 0.75), fract(h * 97.0));
		col += star_color * smoothstep(0.32, 0.0, r) * (0.8 + bright * 3.5) * twinkle;
	}
	vec3 band_normal = normalize(vec3(0.35, 0.55, 0.76));
	float band = exp(-pow(dot(d, band_normal), 2.0) * 22.0);
	float dust = texture(noise, d.xz / (d.y + 1.2) * 1.6).r;
	col += vec3(0.55, 0.6, 0.85) * band * smoothstep(0.3, 0.8, dust) * 0.25;
	return col * smoothstep(0.0, 0.15, d.y);
}

// Curtains of light: two arcs across the northern sky, each drawn as a few
// stacked layers of a wavy band with vertical rays.
vec3 sky_aurora(vec3 d, float time) {
	if (d.y < 0.03) {
		return vec3(0.0);
	}
	vec3 col = vec3(0.0);
	for (int i = 0; i < 7; i++) {
		float layer = float(i) / 7.0;
		vec2 p = d.xz / (d.y + 0.15) * (0.5 + layer * 0.1);
		float wave = sin(p.x * 0.8 + time * 0.12 + sin(p.x * 0.33 - time * 0.07) * 2.5) * 0.5;
		float band = exp(-pow((p.y + 0.9 - wave) * 4.5, 2.0)) + exp(-pow((p.y + 0.15 - wave * 0.7) * 5.5, 2.0)) * 0.6;
		float rays = texture(noise, vec2(p.x * 1.4 + time * 0.015 + layer * 0.21, layer * 0.5)).r;
		float a = band * smoothstep(0.35, 0.75, rays);
		vec3 c = mix(vec3(0.12, 1.0, 0.45), vec3(0.6, 0.22, 1.0), layer * layer);
		col += c * a * (1.0 - layer * 0.65);
	}
	return col * 0.22 * smoothstep(0.03, 0.3, d.y);
}


// Primary bow (42 degrees around the antisolar point, red outside) and a faint
// secondary bow with its colors reversed. The center sits just below the horizon
// so the arc stands up even when the sun is high.
vec3 sky_rainbow(vec3 d) {
	vec3 anti = normalize(vec3(-sun_dir.x, min(-sun_dir.y, -0.12), -sun_dir.z));
	float angle = degrees(acos(clamp(dot(d, anti), -1.0, 1.0)));
	vec3 col = vec3(0.0);
	float x = (angle - 40.2) / 2.4;
	if (x > 0.0 && x < 1.0) {
		vec3 hue = clamp(abs(fract(vec3(0.75 * (1.0 - x)) + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
		col += hue * sin(x * 3.1416) * 0.55;
	}
	float x2 = (angle - 50.5) / 3.2;
	if (x2 > 0.0 && x2 < 1.0) {
		vec3 hue = clamp(abs(fract(vec3(0.75 * x2) + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
		col += hue * sin(x2 * 3.1416) * 0.2;
	}
	// The sky inside the primary bow is a little brighter.
	col += vec3(0.05) * smoothstep(40.5, 30.0, angle);
	return col * smoothstep(0.0, 0.06, d.y);
}

// sun_disk: draw the sun or moon itself (the sky does; reflections add their own
// highlight).
vec3 sky_color(vec3 d, float time, bool sun_disk) {
	float mu = dot(d, sun_dir);
	vec3 sun = sun_color.rgb;
	if (d.y <= 0.0) {
		return mix(sky_horizon.rgb, sea_haze.rgb, smoothstep(0.0, 0.2, -d.y));
	}
	float h = d.y;
	vec3 col = mix(sky_horizon.rgb, sky_top.rgb, pow(h, 0.45));
	// Glow around the sun, stronger and wider when it is low (more air to scatter in).
	float low = 1.0 - smoothstep(0.0, 0.5, sun_dir.y);
	col += sun * (pow(max(mu, 0.0), 5.0 - low * 3.0) * (0.12 + low * 0.25) + pow(max(mu, 0.0), 90.0) * 0.4) * (1.0 - night * 0.8);

	if (night > 0.01) {
		col += sky_stars(d, time) * stars * (1.0 - cloud_cover * 0.9);
	}
	if (aurora > 0.01) {
		col += sky_aurora(d, time) * aurora;
	}
	if (sun_disk) {
		if (night > 0.5) {
			// The moon: a pale disk with darker seas and a soft halo.
			float disk = smoothstep(0.99955, 0.99975, mu);
			vec3 local = d - sun_dir;
			float seas = texture(noise, local.xz * 35.0 + 0.3).r;
			col += vec3(0.95, 0.95, 0.9) * disk * mix(0.55, 1.1, smoothstep(0.35, 0.65, seas)) * 2.5;
			col += vec3(0.5, 0.6, 0.8) * pow(max(mu, 0.0), 400.0) * 0.6;
		} else {
			col += sun * smoothstep(0.9993, 0.99965, mu) * 14.0;
		}
	}

	// A flat cloud layer: the projection squeezes clouds toward the horizon.
	vec2 uv = d.xz / (h + 0.1) + vec2(time * 0.006, time * 0.002);
	float n = sky_cloud_noise(uv);
	float cover = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.28, n) * smoothstep(0.0, 0.12, h);
	if (cover > 0.001) {
		// Light through the cloud: denser toward the sun means more shadow on this side.
		vec2 to_sun = normalize(sun_dir.xz + vec2(0.0001)) * 0.9;
		float lit = clamp(0.6 + (n - sky_cloud_noise(uv + to_sun)) * 4.0, 0.0, 1.0);
		float thick = smoothstep(0.45, 0.95, n);
		vec3 cc = mix(cloud_dark.rgb, cloud_light.rgb, lit * (1.0 - thick * cloud_cover * 0.6));
		// Silver lining on thin cloud edges near the sun.
		cc += sun * pow(max(mu, 0.0), 8.0) * (1.0 - thick) * 0.8 * (1.0 - night);
		col = mix(col, cc, cover);
	}
	if (rainbow > 0.01) {
		col += sky_rainbow(d) * rainbow * (1.0 - cover * 0.7);
	}
	return col;
}
