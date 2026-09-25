// Hareket oku (türün klasiği): düz renkli kalın gövde — hareket yeşil, taarruz kırmızı —, koyu dış hat, ortada açık
// şerit (hafif kabartma), uca doğru akan köşeli işaretler. UV.x: 0..1 boy (1 = uç), UV.y: 0..1 genişlik,
// UV2.x: gövde boyunca ok genişliği cinsinden mesafe (işaret aralığı zoom'dan bağımsız).
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_test_disabled, shadows_disabled;
uniform bool srgb_out = false;   // Compatibility (web) renderer: çıkış sRGB, koddan açılır

uniform float opacity = 0.9;

void fragment() {
	float e = abs(UV.y - 0.5) * 2.0;
	vec3 base = pow(COLOR.rgb, vec3(2.2));
	// yuvarlak gövde: ortası açık, kenara doğru koyulaşır
	vec3 body = base * mix(1.12, 0.62, smoothstep(0.0, 0.75, e));
	// uca doğru akan köşeli işaretler (>)
	float ch = fract(UV2.x * 0.42 - TIME * 0.9 + e * 0.45);
	float chev = smoothstep(0.0, 0.06, ch) * (1.0 - smoothstep(0.16, 0.24, ch));
	body = mix(body, min(base * 1.7 + vec3(0.03), vec3(1.0)), chev * 0.4 * (1.0 - smoothstep(0.5, 0.72, e)));
	// koyu dış hat
	float outline = smoothstep(0.7, 0.8, e);
	vec3 col = mix(body, base * 0.08, outline * 0.92);
	ALBEDO = col;
	if (srgb_out) { ALBEDO = pow(max(ALBEDO, vec3(0.0)), vec3(1.0 / 2.2)); }   // Compatibility: lineer -> sRGB
	// kuyruk biraz soluk başlar
	float fade = mix(0.45, 1.0, smoothstep(0.0, 0.2, UV.x));
	ALPHA = opacity * fade * (1.0 - smoothstep(0.96, 1.0, e));
}
