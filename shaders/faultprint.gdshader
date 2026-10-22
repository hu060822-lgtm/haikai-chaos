// FAULTPRINT surface: a 3D object printed like a cheap multi-plate print.
// Light is split into three flat tones (lit / mid / shadow) instead of a smooth gradient,
// the darker tones are laid down as halftone ink dots (or hatching), a second colour plate
// is printed slightly off register in the shadows, and big surfaces lose a little ink.
// Colour uniforms are linear (Faultprint converts the palette's sRGB hex values).
// The colour is worked out here in light(), so ALBEDO stays white and the environment's
// ambient light must be zero (Faultprint.environment() sets that up).
shader_type spatial;
render_mode cull_back, specular_disabled;

uniform vec4 paint = vec4(0.402, 0.381, 0.334, 1.0);
uniform vec4 ink = vec4(0.015, 0.016, 0.018, 1.0);
uniform vec4 plate = vec4(0.038, 0.381, 0.352, 1.0);
uniform vec4 paper = vec4(0.799, 0.745, 0.644, 1.0);
uniform vec3 glow = vec3(0.0);
// Halftone cells per metre, in object space (held guns: no swimming) or world space.
uniform float dot_density = 8.0;
// Target size of a halftone cell on screen, in pixels.
uniform float dot_px = 11.0;
uniform bool object_space = false;
// 0 = dots, 1 = hatching lines, 2 = flat tones only.
uniform int pattern = 0;
// Tone of the unlit side and the mid band, before any ink.
uniform float shadow_tone = 0.58;
uniform float mid_tone = 0.84;
// Ink coverage of the shadow and mid bands (0..1).
uniform float shadow_ink = 0.5;
uniform float mid_ink = 0.22;
// The off-register second plate: how far it is shifted (in cells) and how strong.
uniform float plate_shift = 0.22;
uniform float plate_amount = 0.22;
// Ink loss: big pale blotches where the ink didn't take (0..1), and paper grain.
uniform float wear = 0.25;
uniform float wear_scale = 0.6;
uniform float grain = 0.035;
// Far away everything fades back into the paper (aerial perspective, and no tiny dots).
uniform float fade_start = 45.0;
uniform float fade_end = 140.0;
// The "soft" look (settings, 0..1): paler, sparser, finer ink tinted by the surface colour
// instead of near-black, no dots right in your face, a darker paper and no glaring whites.
global uniform float fp_soft;
// The dark print (settings): dark paper, the colours printed dim on it, and the light laid
// down as pale dots on the lit side instead of black dots on the dark side.
global uniform float fp_dark;
const vec3 DARK_PAPER = vec3(0.0194, 0.0203, 0.0242); // #26272B, linear
const vec3 PALE_INK = vec3(0.799, 0.745, 0.644);      // #E7E0D2, linear
const vec3 SOFT_PAPER = vec3(0.539, 0.497, 0.418); // #C2BBAD, linear

varying vec3 v_pos;
varying vec3 v_nrm;
varying vec3 v_world;
varying float v_d;
varying float v_d2;
varying float v_db;
varying float v_mix;
varying float v_aa;
varying float v_far;
varying vec3 v_paint;
varying float v_near;
varying float v_fade;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

vec2 planar(vec3 p, vec3 n) {
	vec3 a = abs(n);
	if (a.y >= a.x && a.y >= a.z) return p.xz;
	if (a.x >= a.z) return vec2(p.z, p.y);
	return vec2(p.x, p.y);
}

vec2 rot(vec2 v, float deg) {
	float r = radians(deg);
	return mat2(vec2(cos(r), sin(r)), vec2(-sin(r), cos(r))) * v;
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (object_space) {
		v_pos = VERTEX;
		v_nrm = NORMAL;
	} else {
		v_pos = v_world;
		v_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	}
}

// Distance to the nearest dot centre (or line) in one halftone octave.
float cell_d(vec2 uv) {
	vec2 a = rot(uv, 45.0);
	if (pattern == 1) return abs(fract(a.x) - 0.5) * 1.2;
	return length(fract(a) - 0.5);
}

void fragment() {
	// The screen is anchored in the surface (no swimming), but its scale follows distance
	// in octaves, so dots stay roughly DOT_PX on screen like a real print: no giant dots on
	// a wall you're running along, no shimmer far away. Two octaves blend across a step.
	vec2 uv = planar(v_pos, v_nrm) * dot_density;
	float px = 1.0 / max(length(fwidth(uv)), 1e-4);
	float level = clamp(log2(px / (dot_px * mix(1.0, 0.72, fp_soft))), -1.0, 6.0);
	float l0 = floor(level);
	v_mix = smoothstep(0.25, 0.75, fract(level));
	vec2 u0 = uv * exp2(l0);
	v_d = cell_d(u0);
	v_db = cell_d(u0 * 2.0);
	vec2 b = rot(u0, 15.0) + vec2(plate_shift);
	v_d2 = (pattern == 1) ? abs(fract(b.x) - 0.5) * 1.2 : length(fract(b) - 0.5);
	float w = length(fwidth(rot(u0, 45.0)));
	v_aa = clamp(w * 0.7, 0.01, 0.5);
	v_far = smoothstep(0.3, 0.6, w);
	vec3 col = paint.rgb;
	if (wear > 0.0) {
		vec2 wp = planar(v_world, v_nrm) * wear_scale;
		float blot = smoothstep(0.62, 0.8, vnoise(wp) * 0.7 + vnoise(wp * 3.7) * 0.3);
		col = mix(col, mix(col, paper.rgb, 0.45), blot * wear);
	}
	if (grain > 0.0) {
		col *= 1.0 - grain + grain * 2.0 * hash(floor(planar(v_world, v_nrm) * 90.0));
	}
	v_paint = col;
	v_fade = smoothstep(fade_start, fade_end, length(VERTEX)) * 0.85;
	// Close up (running along a wall) the dots give way to the flat tone.
	v_near = object_space ? 1.0 : mix(1.0, mix(0.25, 1.0, smoothstep(1.2, 6.0, length(VERTEX))), max(fp_soft, fp_dark));
	ALBEDO = vec3(1.0);
	EMISSION = glow;
}

float halftone_aa(float d, float cover, float aa, float far) {
	if (pattern == 2) return 0.0;
	float r = (pattern == 1) ? cover * 0.6 : sqrt(cover) * 0.6;
	float m = 1.0 - smoothstep(r - aa, r + aa, d);
	return mix(m, cover, far);
}

float halftone(float d, float cover) {
	float aa = v_aa;
	float far = v_far;
	return halftone_aa(d, cover, aa, far);
}

// Both octaves of the key plate, blended.
float halftone2(float cover) {
	float aa = v_aa;
	float far = v_far;
	float db = v_db;
	float da = v_d;
	float b = halftone_aa(db, cover, min(aa * 2.0, 0.5), max(far, smoothstep(0.15, 0.3, aa)));
	return mix(halftone_aa(da, cover, aa, far), b, v_mix);
}

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	if (LIGHT_IS_DIRECTIONAL && fp_dark > 0.5) {
		float lit = smoothstep(0.42, 0.46, ndl);
		float mid = smoothstep(0.08, 0.12, ndl);
		// Saturated inks (routes, wayfinding) stay bright; greys sink into the paper.
		float hi = max(v_paint.r, max(v_paint.g, v_paint.b));
		float sat = (hi - min(v_paint.r, min(v_paint.g, v_paint.b))) / max(hi, 1e-3);
		vec3 base = v_paint * mix(0.17, 0.62, clamp((sat - 0.35) * 2.5, 0.0, 1.0));
		float tone = mix(0.5, mix(0.78, 1.0, lit), mid);
		vec3 c = base * tone;
		float d2 = v_d2;
		c = mix(c, plate.rgb * 0.45, halftone(d2, (1.0 - mid) * 0.3) * plate_amount * 0.5 * v_near);
		float cover = (lit * 0.16 + mid * (1.0 - lit) * 0.06) * v_near * (object_space ? 0.6 : 1.0);
		vec3 pale = mix(v_paint, PALE_INK, 0.5) * 0.5;
		c = mix(c, pale, halftone2(cover));
		c = mix(c, DARK_PAPER, v_fade);
		DIFFUSE_LIGHT += c * LIGHT_COLOR / PI;
	} else if (LIGHT_IS_DIRECTIONAL) {
		float lit = smoothstep(0.42, 0.46, ndl);
		float mid = smoothstep(0.08, 0.12, ndl);
		float tone = mix(shadow_tone, mix(mid_tone, 1.0, lit), mid);
		// Ink grows smoothly toward the dark side inside the flat tones (a real halftone ramp).
		float ramp = 1.0 - smoothstep(0.0, 0.46, ndl);
		float cover = mix(mid_ink * ramp * 1.6, shadow_ink, 1.0 - mid) * (1.0 - lit);
		float soft = fp_soft;
		cover *= v_near * mix(1.0, 0.55, soft);
		tone *= mix(1.0, 0.86, soft * lit);
		vec3 c = v_paint * tone;
		float d2 = v_d2;
		c = mix(c, plate.rgb * 0.85, halftone(d2, cover * 0.55) * plate_amount * mix(1.0, 0.45, soft) * (1.0 - lit));
		vec3 ink_c = mix(ink.rgb, v_paint * shadow_tone * 0.5, 0.72 * soft);
		c = mix(c, ink_c, halftone2(cover));
		c = mix(c, mix(paper.rgb, SOFT_PAPER, soft), v_fade);
		DIFFUSE_LIGHT += c * LIGHT_COLOR / PI;
	} else {
		// Local lights (muzzle flashes, zone lights) add two flat steps of their colour: a
		// wide faint pool and a brighter core, like two passes of a translucent ink.
		float a = step(0.1, clamp(dot(NORMAL, LIGHT), 0.0, 1.0)) * ATTENUATION;
		DIFFUSE_LIGHT += v_paint * LIGHT_COLOR * (step(0.03, a) * 0.07 + step(0.3, a) * 0.09) / PI;
	}
}
