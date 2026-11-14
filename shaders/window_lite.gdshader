// Low quality: the same look lit per vertex (flat faces under the sun light
// the same either way), much less work per pixel on phones.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, vertex_lighting;
#include "res://shaders/window.gdshaderinc"
