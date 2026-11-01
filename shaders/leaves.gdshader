// Tree canopies: lumpy spheres that sway in the wind. Lumps and shading use the
// mesh's own coordinates, so a falling canopy keeps its look.
shader_type spatial;

global uniform float wind;

uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform vec3 leaf_color : source_color = vec3(0.22, 0.48, 0.2);

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
	float lump = texture(noise, VERTEX.xz * 0.35 + VERTEX.y * 0.27).r;
	VERTEX += NORMAL * (lump - 0.45) * 0.55;
	vec3 wp = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float t = TIME * 1.7 + wp.x * 0.3 + wp.z * 0.2;
	VERTEX.xz += vec2(sin(t), cos(t * 0.8)) * (0.06 + wind * 0.12) * max(VERTEX.y + 0.5, 0.0);
}

void fragment() {
	float n = texture(noise, local_pos.xz * 1.6 + local_pos.y * 1.3).r;
	float clump = smoothstep(0.35, 0.7, n);
	// Undersides and the inner shade read darker, like light lost inside the foliage.
	float under = smoothstep(-0.8, 0.6, local_pos.y);
	ALBEDO = leaf_color * mix(0.55, 1.2, clump) * mix(0.55, 1.0, under);
	ROUGHNESS = 0.8;
	SPECULAR = 0.25;
}
