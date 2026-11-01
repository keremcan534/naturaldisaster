// Heat haze over the whole screen: the picture wobbles, more toward the bottom
// (the hot ground), with a faint warm tint. Medium quality and up only.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec2 uv = SCREEN_UV;
	float ground = smoothstep(0.35, 1.0, uv.y);
	vec2 wobble = vec2(sin(uv.y * 90.0 + TIME * 4.0), cos(uv.x * 70.0 + TIME * 3.1)) * 0.0022 * (0.3 + ground);
	vec3 col = textureLod(screen, uv + wobble, 0.0).rgb;
	COLOR = vec4(col * vec3(1.04, 1.0, 0.94), 1.0);
}
