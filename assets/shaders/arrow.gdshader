// Hareket oku: gövde ve ok başı yok — yol boyunca hedefe doğru akan, arka arkaya küçük köşeli işaretler (›››),
// hareket yeşil, taarruz kırmızı. Kenarları yumuşak, opaklığı düşük: haritanın altından akıyormuş gibi durur; kuyrukta
// belirir, uca yaklaşınca söner. UV.x: 0..1 boy (1 = uç), UV.y: 0..1 genişlik, UV2.x: yol boyunca ok genişliği
// cinsinden mesafe (işaret aralığı zoom'dan bağımsız).
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_test_disabled, shadows_disabled;
uniform bool srgb_out = false;   // Compatibility (web) renderer: çıkış sRGB, koddan açılır

uniform float opacity = 0.55;

void fragment() {
	float e = abs(UV.y - 0.5) * 2.0;
	vec3 base = pow(COLOR.rgb, vec3(2.2));
	// köşeli işaret: ortası öne çıkık bant, zamanla uca doğru akar
	float ph = fract(UV2.x * 0.62 - TIME * 1.1 + e * 0.3);
	float chev = smoothstep(0.0, 0.06, ph) * (1.0 - smoothstep(0.34, 0.42, ph));
	// yumuşak kenar, kuyrukta beliriş, uçta sönüş
	float side = 1.0 - smoothstep(0.78, 1.0, e);
	float tail = smoothstep(0.0, 0.18, UV.x);
	float tip = 1.0 - smoothstep(0.88, 1.0, UV.x);
	ALBEDO = min(base * 1.15 + vec3(0.02), vec3(1.0));
	if (srgb_out) { ALBEDO = pow(max(ALBEDO, vec3(0.0)), vec3(1.0 / 2.2)); }   // Compatibility: lineer -> sRGB
	ALPHA = opacity * chev * side * tail * tip;
}
