// The full-screen pass over the 3D view (a quad stuck to the camera, see Faultprint.post):
//   ink lines   every edge and crease gets a dark ink line (MYCOPUNK-style outlines), found
//               from the depth buffer: a jump or a kink in 1/depth is an edge, a flat
//               plane is not (1/depth is linear across a plane on screen)
//   pixels      optional chunky pixels (ULTRAKILL-style low resolution), no smoothing
//   saturation  a little more colour
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, blend_mix, fog_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec4 line_color = vec4(0.013, 0.014, 0.017, 1.0); // linear
uniform float line_strength = 0.85;
uniform float line_threshold = 0.035;
uniform float line_far = 70.0;        // m: lines fade out toward this distance
uniform float pixel_size = 1.0;       // screen pixels per pixel (1 = off)
uniform float line_px = 2.0;          // line width in screen pixels (at 1080p; scales with height)
uniform float saturation = 1.0;
uniform float near_skip = 0.7;        // m: the held gun is closer than this; no lines on it

void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 0.0, 1.0);
}

// (The depth texture is sampled in fragment(): the compatibility renderer only declares it
// there.)
float inv_depth(vec2 uv, float d, mat4 inv_proj) {
	vec3 ndc = vec3(uv, d) * 2.0 - 1.0;
	vec4 v = inv_proj * vec4(ndc, 1.0);
	return -v.w / v.z; // 1 / distance along the view axis
}

void fragment() {
	vec2 px = vec2(pixel_size) / VIEWPORT_SIZE;
	vec2 uv = pixel_size > 1.0 ? (floor(SCREEN_UV / px) + 0.5) * px : SCREEN_UV;
	vec3 col = texture(screen_tex, uv).rgb;
	float g = dot(col, vec3(0.2126, 0.7152, 0.0722));
	col = max(mix(vec3(g), col, saturation), 0.0);
	vec2 o = max(px, vec2(line_px * max(VIEWPORT_SIZE.y / 1080.0, 0.5)) / VIEWPORT_SIZE);
	vec2 uv_c = uv;
	float c = inv_depth(uv_c, texture(depth_tex, uv_c).r, INV_PROJECTION_MATRIX);
	vec2 uv_l = uv - vec2(o.x, 0.0);
	float l = inv_depth(uv_l, texture(depth_tex, uv_l).r, INV_PROJECTION_MATRIX);
	vec2 uv_r = uv + vec2(o.x, 0.0);
	float r = inv_depth(uv_r, texture(depth_tex, uv_r).r, INV_PROJECTION_MATRIX);
	vec2 uv_u = uv - vec2(0.0, o.y);
	float u = inv_depth(uv_u, texture(depth_tex, uv_u).r, INV_PROJECTION_MATRIX);
	vec2 uv_dn = uv + vec2(0.0, o.y);
	float dn = inv_depth(uv_dn, texture(depth_tex, uv_dn).r, INV_PROJECTION_MATRIX);
	float dist = 1.0 / max(c, 1e-5);
	// A kink (crease) or a step (silhouette), relative to the depth here.
	float kink = (abs(l + r - 2.0 * c) + abs(u + dn - 2.0 * c)) / max(c, 1e-5);
	// Only the far side of a silhouette draws, so lines sit on the object's own outline.
	float step_out = max(max(c - l, c - r), max(c - u, c - dn)) / max(c, 1e-5);
	float e = smoothstep(line_threshold, line_threshold * 2.0, max(kink * 0.5, step_out));
	e *= 1.0 - smoothstep(line_far * 0.5, line_far, dist);
	e *= step(near_skip, dist) * step(near_skip, 1.0 / max(max(max(l, r), max(u, dn)), 1e-5));
	if (c < 1e-4) e *= step(1e-4, max(max(l, r), max(u, dn))) * 0.0; // sky
	ALBEDO = mix(col, line_color.rgb, e * line_strength);
}
