// Blocky characters (bots, the menu preview, the player's shadow) in one draw
// call each: the mesh is a set of boxes whose UV.x says which limb a vertex
// belongs to and UV.y which color slot it takes. Legs and arms swing around their
// hip and shoulder here, so walking costs no extra nodes.
shader_type spatial;
render_mode cull_back;

uniform vec3 shirt : source_color = vec3(0.2, 0.5, 0.95);
uniform vec3 pants : source_color = vec3(0.16, 0.18, 0.26);
uniform vec3 skin : source_color = vec3(0.93, 0.74, 0.6);
uniform vec3 hat : source_color = vec3(1.0, 0.8, 0.15);
// Leg swing in radians (arms swing the other way).
uniform float swing = 0.0;
// 0..1: both arms up over the head (climbing, panicking, cheering).
uniform float arms_up = 0.0;
uniform float hat_on = 0.0;
// Cosmetic extras and their color (backpack, cap), and a scared face.
uniform vec3 extra : source_color = vec3(0.85, 0.3, 0.2);
uniform float glasses_on = 0.0;
uniform float pack_on = 0.0;
uniform float cap_on = 0.0;
uniform float scared = 0.0;

const float HIP = 0.82;
const float SHOULDER = 1.38;

mat3 rot_x(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, c, s), vec3(0.0, -s, c));
}

void vertex() {
	float part = UV.x;
	float angle = 0.0;
	float pivot = 0.0;
	if (part > 0.5 && part < 2.5) {
		pivot = HIP;
		angle = part < 1.5 ? swing : -swing;
	} else if (part > 2.5 && part < 4.5) {
		pivot = SHOULDER;
		float walk = part < 3.5 ? -swing * 0.8 : swing * 0.8;
		float wave = 2.8 + sin(TIME * 10.0 + part * 2.0) * 0.3;
		angle = mix(walk, wave, arms_up);
	} else if (part > 4.5 && part < 5.5) {
		VERTEX = mix(vec3(0.0, 1.5, 0.0), VERTEX, hat_on);
	} else if (part > 5.5 && part < 6.5) {
		// The mouth: a line, or a small open "O" when scared.
		vec3 c = vec3(0.0, 1.505, VERTEX.z);
		VERTEX = c + (VERTEX - c) * vec3(mix(1.0, 0.7, scared), mix(1.0, 3.2, scared), 1.0);
	} else if (part > 6.5) {
		float on = part < 7.5 ? glasses_on : part < 8.5 ? pack_on : cap_on;
		VERTEX = mix(vec3(0.0, 1.2, 0.0), VERTEX, on);
	}
	if (angle != 0.0) {
		mat3 r = rot_x(angle);
		vec3 p = VERTEX - vec3(0.0, pivot, 0.0);
		VERTEX = r * p + vec3(0.0, pivot, 0.0);
		NORMAL = r * NORMAL;
	}
}

void fragment() {
	float slot = UV.y;
	vec3 c = slot < 0.5 ? shirt : slot < 1.5 ? pants : slot < 2.5 ? skin : slot < 3.5 ? vec3(0.07, 0.06, 0.06) : slot < 4.5 ? hat : extra;
	ALBEDO = c;
	ROUGHNESS = slot > 3.5 && slot < 4.5 ? 0.35 : 0.85;
}
