// Shared by the opaque sea and the see-through flood water. Two scrolling noise
// layers bend the normal; a fresnel term blends toward the sky color at grazing angles.

uniform vec3 deep_color : source_color = vec3(0.02, 0.12, 0.2);
uniform vec3 shallow_color : source_color = vec3(0.06, 0.32, 0.42);
uniform vec3 sky_color : source_color = vec3(0.62, 0.75, 0.88);
uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform float wave_scale = 0.045;
uniform float wave_strength = 0.6;
uniform float flow_speed = 1.0;
uniform vec2 flow = vec2(0.0);
uniform float alpha = 0.8;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float height(vec2 p) {
	float t = TIME * flow_speed;
	vec2 q = p - flow * TIME;
	float a = texture(noise, q * wave_scale + vec2(t * 0.012, t * 0.007)).r;
	float b = texture(noise, q * wave_scale * 2.3 - vec2(t * 0.009, -t * 0.014)).r;
	return a * 0.6 + b * 0.4;
}

void fragment() {
	float e = 0.35;
	vec2 p = world_pos.xz;
	float h = height(p);
	vec3 n = normalize(vec3((h - height(p + vec2(e, 0.0))) * wave_strength / e * 4.0, 1.0,
			(h - height(p + vec2(0.0, e))) * wave_strength / e * 4.0));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	vec3 col = mix(deep_color, shallow_color, smoothstep(0.35, 0.75, h));
	ALBEDO = mix(col, sky_color, fresnel * 0.5);
	ROUGHNESS = 0.06;
	SPECULAR = 0.6;
#ifdef CLEAR
	ALPHA = mix(alpha, 1.0, fresnel);
#endif
}
