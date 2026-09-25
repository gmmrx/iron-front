// Gemi seyir izi: kıçtan açılan V köpük + ortada çalkantı; UV.y = 0 kıç, 1 iz sonu. Akan gürültü.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

varying float inten;

void vertex() {
	inten = INSTANCE_CUSTOM.a;
}

void fragment() {
	float y = UV.y;
	float x = abs(UV.x - 0.5) * 2.0;
	float fade = pow(1.0 - y, 1.6) * smoothstep(0.0, 0.06, y);
	// V kolları: kıçtan uzaklaştıkça açılır
	float arm = 0.12 + y * 0.85;
	float v = smoothstep(0.16, 0.0, abs(x - arm)) ;
	// pervane çalkantısı
	float c = smoothstep(0.22, 0.0, x) * (0.6 + 0.4 * noise(vec2(UV.x * 12.0, y * 20.0 - TIME * 3.0)));
	float n = 0.55 + 0.45 * noise(vec2(UV.x * 30.0, y * 40.0 - TIME * 2.0));
	float a = max(v * 0.8, c) * fade * n;
	ALBEDO = vec3(0.92, 0.96, 1.0);
	ALPHA = clamp(a * inten, 0.0, 0.85);
}
