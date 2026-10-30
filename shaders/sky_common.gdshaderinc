// The sky as a function of direction, shared by the sky itself and by everything
// that reflects it (water, glass). Values come from the weather as global uniforms.
// The including shader must declare `uniform sampler2D noise`.

global uniform vec4 sky_top;
global uniform vec4 sky_horizon;
global uniform vec4 sea_haze;
// Direction toward the sun, and its color times energy.
global uniform vec3 sun_dir;
global uniform vec4 sun_color;
global uniform float cloud_cover;
global uniform vec4 cloud_light;
global uniform vec4 cloud_dark;

float sky_cloud_noise(vec2 uv) {
	float n = texture(noise, uv * 0.11).r * 0.55;
	n += texture(noise, uv * 0.33 + vec2(0.31, 0.17)).r * 0.3;
	n += texture(noise, uv * 1.1 + vec2(0.71, 0.53)).r * 0.15;
	return n;
}

// sun_disk: draw the sun itself (the sky does; reflections add their own highlight).
vec3 sky_color(vec3 d, float time, bool sun_disk) {
	float mu = dot(d, sun_dir);
	vec3 sun = sun_color.rgb;
	if (d.y <= 0.0) {
		return mix(sky_horizon.rgb, sea_haze.rgb, smoothstep(0.0, 0.2, -d.y));
	}
	float h = d.y;
	vec3 col = mix(sky_horizon.rgb, sky_top.rgb, pow(h, 0.45));
	col += sun * (pow(max(mu, 0.0), 5.0) * 0.12 + pow(max(mu, 0.0), 90.0) * 0.4);
	if (sun_disk) {
		col += sun * smoothstep(0.9993, 0.99965, mu) * 14.0;
	}
	// A flat cloud layer: the projection squeezes clouds toward the horizon.
	vec2 uv = d.xz / (h + 0.1) + vec2(time * 0.006, time * 0.002);
	float n = sky_cloud_noise(uv);
	float cover = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.28, n) * smoothstep(0.0, 0.12, h);
	float thick = smoothstep(0.45, 0.95, n);
	vec3 cc = mix(cloud_light.rgb, cloud_dark.rgb, thick * (0.4 + cloud_cover * 0.6));
	// Silver lining on clouds near the sun.
	cc += sun * pow(max(mu, 0.0), 10.0) * 0.6 * (1.0 - thick);
	return mix(col, cc, cover);
}
