// Seagulls circling over the island: one MultiMesh, nothing updated per frame.
// Each instance's custom data (phase, radius, height, speed) sets its circle;
// the vertex shader moves it along, turns it to fly forward, banks it a little
// and flaps the wings (vertices with |x| > 0.1 are wing).
shader_type spatial;
render_mode cull_disabled;

uniform vec3 color : source_color = vec3(0.92, 0.92, 0.9);
uniform vec3 tips : source_color = vec3(0.25, 0.25, 0.27);

varying float wing;

void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	float angle = c.x + TIME * c.w / c.y;
	float flap = sin(TIME * (7.0 + c.x) + c.x * 13.0);
	// Glide for a while, then flap.
	float gliding = smoothstep(0.3, 0.6, sin(TIME * 0.4 + c.x * 5.0));
	wing = abs(VERTEX.x);
	vec3 v = VERTEX;
	v.y += wing * mix(flap * 0.6, 0.15, gliding);
	// Fly along the circle (counter-clockwise when speed > 0): forward is -Z.
	vec3 pos = vec3(cos(angle) * c.y, c.z + sin(TIME * 0.3 + c.x) * 2.0, sin(angle) * c.y);
	vec3 forward = normalize(vec3(-sin(angle), 0.0, cos(angle)) * sign(c.w));
	vec3 right = normalize(cross(forward, vec3(0.0, 1.0, 0.0)));
	vec3 up = cross(right, forward) + right * 0.25;
	VERTEX = pos + right * v.x + normalize(up) * v.y - forward * v.z;
	NORMAL = normalize(up);
}

void fragment() {
	ALBEDO = mix(color, tips, smoothstep(0.6, 0.9, wing));
	ROUGHNESS = 0.9;
}
