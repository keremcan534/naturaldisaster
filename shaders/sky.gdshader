// Sky with a sun disk and a drifting cloud layer (see sky_common.gdshaderinc).
// Nothing samples the sky for lighting, so animating it is cheap.
shader_type sky;

uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
// Lightning brightens the whole sky.
uniform float flash = 0.0;

#include "res://shaders/sky_common.gdshaderinc"

void sky() {
	COLOR = sky_color(EYEDIR, TIME, true) * (1.0 + flash);
}
