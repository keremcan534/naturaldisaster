// Walls and floor slabs: each face of the box gets its own color. Wall pieces are
// built with local +Z facing outward, so the outside can be the building's color
// and the inside painted; slabs show a plank floor on top and a ceiling below.
shader_type spatial;

uniform sampler2D panel : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 outside_color : source_color = vec3(0.8);
uniform vec3 inside_color : source_color = vec3(0.9);
uniform vec3 top_color : source_color = vec3(0.8);
uniform vec3 bottom_color : source_color = vec3(0.8);
uniform vec3 edge_color : source_color = vec3(0.8);
// Draws floorboards on the top face.
uniform bool planks = false;

varying vec3 local_pos;
varying vec3 local_normal;

float hash(float n) {
	return fract(sin(n * 91.345) * 47453.5453);
}

void vertex() {
	// Batched pieces are a unit cube scaled by the instance transform.
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	local_normal = NORMAL;
	// Per-piece offset so floorboards don't line up across tiles.
	local_pos = VERTEX * scale + MODEL_MATRIX[3].xyz;
}

void fragment() {
	vec3 n = local_normal;
	vec3 col = edge_color;
	if (n.z > 0.5) {
		col = outside_color;
	} else if (n.z < -0.5) {
		col = inside_color;
	} else if (n.y > 0.5) {
		col = top_color;
		if (planks) {
			float board = floor(local_pos.x * 5.0);
			float seam = smoothstep(0.0, 0.06, fract(local_pos.x * 5.0)) * smoothstep(1.0, 0.94, fract(local_pos.x * 5.0));
			float joint = step(0.03, fract(local_pos.z * 0.5 + hash(board)));
			col *= mix(0.82, 1.12, hash(board + 7.0)) * mix(0.7, 1.0, seam * joint);
		}
	} else if (n.y < -0.5) {
		col = bottom_color;
	}
	float detail = texture(panel, UV * vec2(3.0, 2.0)).r;
	// Indoors is smooth paint; the weathered look is for outside.
	if (n.z < -0.5 || n.y < -0.5) {
		detail = mix(1.0, detail, 0.3);
	}
	ALBEDO = col * detail;
	ROUGHNESS = planks && n.y > 0.5 ? 0.55 : 0.85;
}
