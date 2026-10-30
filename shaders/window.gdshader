// Window pieces (see Structure: walls are built so local +Z faces outward): a
// frame and see-through glass that reflects the sky, more at grazing angles.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform vec3 frame_color : source_color = vec3(0.86, 0.85, 0.82);
uniform vec3 glass_tint : source_color = vec3(0.05, 0.08, 0.09);

#include "res://shaders/sky_common.gdshaderinc"

varying vec3 local_pos;
varying vec3 local_normal;
// Every vertex of a box sits at +-half its size, so this is constant per piece.
varying vec3 half_size;

void vertex() {
	// Batched pieces are a unit cube scaled by the instance transform.
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	local_pos = VERTEX * scale;
	local_normal = NORMAL;
	half_size = abs(VERTEX) * scale;
}

void fragment() {
	vec2 q = local_pos.xy;
	vec2 hs = half_size.xy;
	bool face = abs(local_normal.z) > 0.5;
	float fw = 0.09;
	bool frame = hs.x - abs(q.x) < fw || hs.y - abs(q.y) < fw
			|| abs(q.x) < 0.025 || abs(q.y - hs.y * 0.3) < 0.025;
	if (face && !frame) {
		vec3 view_world = normalize((INV_VIEW_MATRIX * vec4(-VIEW, 0.0)).xyz);
		vec3 n_world = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
		float fresnel = 0.04 + 0.96 * pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 5.0);
		vec3 reflected = sky_color(reflect(view_world, n_world), TIME, false);
		// Seen from outside the glass mirrors more (rooms are darker than the sky).
		float mirror = local_normal.z > 0.0 ? mix(0.25, 1.0, fresnel) : fresnel * 0.4;
		ALBEDO = glass_tint;
		EMISSION = reflected * mirror * 0.75;
		ALPHA = mix(0.12, 0.9, mirror);
		ROUGHNESS = 0.04;
		SPECULAR = 0.9;
	} else {
		ALBEDO = frame_color;
		ALPHA = 1.0;
		ROUGHNESS = 0.6;
	}
}
