// Inverted-hull silhouette in carbon ink, for things that must read at speed.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;

uniform vec4 color = vec4(0.015, 0.016, 0.018, 1.0); // linear
uniform float width = 0.03;

void vertex() {
	VERTEX += NORMAL * width;
}

void fragment() {
	ALBEDO = color.rgb;
}
