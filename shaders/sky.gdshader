// Sky with a sun disk and a drifting cloud layer. Colors come from the weather
// mood (global uniforms); nothing samples the sky for lighting, so animating it is cheap.
shader_type sky;

global uniform vec4 sky_top;
global uniform vec4 sky_horizon;
global uniform vec4 sea_haze;

uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform float cloud_cover = 0.45;
uniform vec3 cloud_light : source_color = vec3(1.0, 0.98, 0.95);
uniform vec3 cloud_dark : source_color = vec3(0.55, 0.6, 0.68);
// Lightning brightens the whole sky.
uniform float flash = 0.0;

float clouds(vec2 uv) {
	float n = texture(noise, uv * 0.11).r * 0.55;
	n += texture(noise, uv * 0.33 + vec2(0.31, 0.17)).r * 0.3;
	n += texture(noise, uv * 1.1 + vec2(0.71, 0.53)).r * 0.15;
	return n;
}

void sky() {
	vec3 d = EYEDIR;
	float mu = LIGHT0_ENABLED ? dot(d, LIGHT0_DIRECTION) : 0.0;
	vec3 sun = LIGHT0_ENABLED ? LIGHT0_COLOR * min(LIGHT0_ENERGY, 1.5) : vec3(0.0);
	vec3 col;
	if (d.y > 0.0) {
		float h = d.y;
		col = mix(sky_horizon.rgb, sky_top.rgb, pow(h, 0.45));
		col += sun * (pow(max(mu, 0.0), 5.0) * 0.12 + pow(max(mu, 0.0), 90.0) * 0.4);
		col += sun * smoothstep(0.9993, 0.99965, mu) * 14.0;
		// A flat cloud layer: the projection squeezes clouds toward the horizon.
		vec2 uv = d.xz / (h + 0.1) + vec2(TIME * 0.006, TIME * 0.002);
		float n = clouds(uv);
		float cover = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.28, n) * smoothstep(0.0, 0.12, h);
		float thick = smoothstep(0.45, 0.95, n);
		vec3 cc = mix(cloud_light, cloud_dark, thick * (0.4 + cloud_cover * 0.6));
		// Silver lining on clouds near the sun.
		cc += sun * pow(max(mu, 0.0), 10.0) * 0.6 * (1.0 - thick);
		col = mix(col, cc, cover);
	} else {
		col = mix(sky_horizon.rgb, sea_haze.rgb, smoothstep(0.0, 0.2, -d.y));
	}
	COLOR = col * (1.0 + flash);
}
