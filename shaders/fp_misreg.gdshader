// The slipped plate: the mesh drawn again a few pixels off, in a flat second ink, pushed
// just behind itself so it only shows where it spills past the object's silhouette.
// That spill is the "套色偏移" of a misregistered print. Used on world geometry only,
// never on players, bots or the crosshair.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix;

uniform vec4 color = vec4(0.038, 0.381, 0.352, 1.0); // linear
uniform float alpha = 0.55;
uniform vec2 offset_px = vec2(3.0, -2.0);
uniform float push = 0.01; // how far behind (fraction of the distance to the camera)

void vertex() {
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	view.xyz *= 1.0 + push; // slide back along the view ray: same spot on screen, just behind
	vec4 clip = PROJECTION_MATRIX * view;
	clip.xy += offset_px * 2.0 / VIEWPORT_SIZE * clip.w;
	POSITION = clip;
}

void fragment() {
	ALBEDO = color.rgb;
	// Only faces turned toward the camera slip: a grazing face's ghost would land on itself.
	ALPHA = alpha * smoothstep(0.6, 0.85, dot(NORMAL, VIEW));
}
