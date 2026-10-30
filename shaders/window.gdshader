// Window pieces (see Structure: walls are built so local +Z faces outward).
// Outside: a frame, and behind the glass a fake room drawn with interior mapping
// (the view ray is traced through a box), plus the sky reflected at grazing angles.
// Inside: the bright outdoors. Rooms vary by the piece's position.
shader_type spatial;

global uniform vec4 sky_top;
global uniform vec4 sky_horizon;
// 0..1: how many rooms glow and how warmly (dark weather turns lights on).
global uniform float room_light;

uniform vec3 frame_color : source_color = vec3(0.86, 0.85, 0.82);
uniform float room_depth = 2.6;

varying vec3 local_pos;
varying vec3 local_normal;
// Every vertex of a box sits at +-half its size, so this is constant per piece.
varying vec3 half_size;
varying vec3 cam_local;
// Flat: interpolating it could round differently across the face and speckle.
varying flat vec3 room_seed;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void vertex() {
	local_pos = VERTEX;
	local_normal = NORMAL;
	half_size = abs(VERTEX);
	cam_local = (inverse(MODEL_MATRIX) * vec4(INV_VIEW_MATRIX[3].xyz, 1.0)).xyz;
	room_seed = floor(MODEL_MATRIX[3].xyz * 0.5);
}

vec3 sky_color(vec3 dir) {
	if (dir.y > 0.0) {
		return mix(sky_horizon.rgb, sky_top.rgb, sqrt(dir.y));
	}
	return mix(sky_horizon.rgb, vec3(0.32, 0.36, 0.3), smoothstep(0.0, 0.25, -dir.y));
}

vec3 room(vec2 q, vec2 hs) {
	vec3 dir = local_pos - cam_local;
	vec3 rd = vec3(dir.x / hs.x, dir.y / hs.y, dir.z / (room_depth * 0.5));
	vec3 ro = vec3(q / hs, 1.0);
	vec3 id = 1.0 / rd;
	vec3 k = abs(id) - ro * id;
	float t = min(min(k.x, k.y), k.z);
	vec3 hit = ro + rd * t;

	float r1 = hash(room_seed);
	float r2 = hash(room_seed + 1.7);
	float r3 = hash(room_seed + 3.1);
	vec3 wall = mix(vec3(0.85, 0.74, 0.6), vec3(0.62, 0.72, 0.74), r1);
	vec3 col;
	if (t == k.z) {
		col = wall * 0.9;
		// A picture or a doorway on the back wall.
		vec2 b = hit.xy;
		if (r2 > 0.5 && abs(b.x - 0.3) < 0.25 && abs(b.y - 0.15) < 0.2) {
			col = mix(vec3(0.6, 0.3, 0.2), vec3(0.2, 0.4, 0.6), r3);
		} else if (r2 < 0.3 && abs(b.x + 0.4) < 0.28 && b.y < 0.35) {
			col = wall * 0.45;
		}
	} else if (t == k.y) {
		col = hit.y > 0.0 ? vec3(0.88) : mix(vec3(0.4, 0.27, 0.17), vec3(0.52, 0.5, 0.47), r2);
		// A ceiling lamp.
		if (hit.y > 0.0) {
			col += vec3(1.0, 0.9, 0.7) * smoothstep(0.25, 0.0, length(hit.xz)) * 2.0;
		}
	} else {
		col = wall;
	}
	// Further in is darker; corners pick up a little shadow.
	col *= mix(1.0, 0.5, (1.0 - hit.z) * 0.5);
	col *= 1.0 - 0.2 * smoothstep(0.75, 1.0, max(abs(hit.x), abs(hit.y)));

	float lit = step(0.5, r3) * room_light;
	col *= mix(vec3(0.6), vec3(1.4, 1.15, 0.8), lit);

	// Curtains drawn at the sides, or blinds partly down.
	if (r1 > 0.55) {
		float open = mix(0.45, 0.8, r2);
		if (abs(ro.x) > open) {
			float folds = 0.75 + 0.25 * sin(ro.x * 60.0);
			col = mix(vec3(0.7, 0.62, 0.5), vec3(0.45, 0.2, 0.18), r3) * folds * mix(0.45, 1.0, lit);
		}
	} else if (r1 < 0.2 && ro.y > 1.0 - r2 * 1.4) {
		col = vec3(0.85, 0.83, 0.78) * (0.8 + 0.2 * step(0.5, fract(ro.y * 12.0))) * mix(0.5, 1.0, lit);
	}
	return col;
}

void fragment() {
	vec2 q = local_pos.xy;
	vec2 hs = half_size.xy;
	bool outside = local_normal.z > 0.5;
	bool inside = local_normal.z < -0.5;
	float fw = 0.1;
	bool frame = hs.x - abs(q.x) < fw || hs.y - abs(q.y) < fw
			|| abs(q.x) < 0.03 || abs(q.y - hs.y * 0.3) < 0.03;

	if ((outside || inside) && !frame) {
		vec3 view_world = normalize((INV_VIEW_MATRIX * vec4(-VIEW, 0.0)).xyz);
		vec3 n_world = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
		float fresnel = 0.06 + 0.9 * pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
		vec3 behind = outside ? room(q, hs) : sky_color(view_world);
		vec3 reflected = sky_color(reflect(view_world, n_world));
		ALBEDO = vec3(0.02);
		EMISSION = mix(behind, reflected, outside ? fresnel : fresnel * 0.3);
		ROUGHNESS = 0.06;
		SPECULAR = 0.8;
	} else {
		ALBEDO = frame_color;
		ROUGHNESS = 0.6;
	}
}
