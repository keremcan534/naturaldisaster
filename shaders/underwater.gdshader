// Under water: murky tint that thickens with depth, slanted light shafts from
// the surface drifting slowly, and specks floating by.
shader_type canvas_item;

// Meters between the camera and the surface above it.
uniform float depth = 0.0;
uniform vec3 water : source_color = vec3(0.05, 0.25, 0.32);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float deep = clamp(depth / 6.0, 0.0, 1.0);
	vec3 col = water * mix(1.25, 0.45, deep) * (1.0 - uv.y * 0.35);
	float alpha = mix(0.42, 0.86, deep) + uv.y * 0.1;
	// Light shafts: slanted bands from the top of the screen.
	float x = uv.x + uv.y * 0.3;
	float rays = (sin(x * 23.0 + TIME * 0.7) * sin(x * 37.0 - TIME * 0.45 + 1.3)) * 0.5 + 0.5;
	rays = pow(rays, 5.0) * (1.0 - uv.y) * (1.0 - deep * 0.75);
	col += vec3(0.4, 0.65, 0.6) * rays * 0.7;
	alpha -= rays * 0.25;
	// Specks of silt drifting up.
	vec2 g = uv * vec2(42.0, 24.0) + vec2(sin(TIME * 0.3) * 0.5, TIME * 0.35);
	vec2 cell = floor(g);
	float speck = step(0.982, hash(cell)) * smoothstep(0.25, 0.0, length(fract(g) - 0.5));
	col += vec3(speck * 0.35);
	COLOR = vec4(col, clamp(alpha, 0.0, 0.92));
}
