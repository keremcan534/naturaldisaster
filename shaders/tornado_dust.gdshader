// Dust whirled up around a tornado's foot: a MultiMesh of quads that never
// change on the CPU. Each instance's custom data (start angle, phase, reach,
// height) sets its own spiral; the vertex shader moves it up and out along it
// over its life and turns it to face the camera.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D puff : filter_linear_mipmap;
uniform vec3 color : source_color = vec3(0.42, 0.37, 0.31);
uniform float radius = 11.0;
uniform float height = 12.0;
uniform float opacity = 0.55;

varying float fade;

void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	float life = fract(TIME * 0.2 + c.y);
	float r = mix(1.5, radius * c.z, sqrt(life));
	float angle = c.x + TIME * 6.0 / (r * 0.35 + 0.6);
	vec3 center = vec3(cos(angle) * r, 0.3 + life * life * height * c.w, sin(angle) * r);
	float size = mix(1.6, 6.0, life) * (0.6 + c.z * 0.5);
	vec3 right = (inverse(MODEL_MATRIX) * vec4(INV_VIEW_MATRIX[0].xyz, 0.0)).xyz;
	vec3 up = (inverse(MODEL_MATRIX) * vec4(INV_VIEW_MATRIX[1].xyz, 0.0)).xyz;
	VERTEX = center + (right * VERTEX.x + up * VERTEX.y) * size;
	NORMAL = (inverse(MODEL_MATRIX) * vec4(INV_VIEW_MATRIX[2].xyz, 0.0)).xyz;
	fade = smoothstep(0.0, 0.15, life) * (1.0 - smoothstep(0.55, 1.0, life));
}

void fragment() {
	float a = texture(puff, UV).a;
	ALBEDO = color;
	ALPHA = a * fade * opacity;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
