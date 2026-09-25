// Hareket oku: haritaya boyanmış gibi, ülke renginde yarı saydam; kenarda ince koyu çizgi.
// UV.x: gövde boyunca 0..1 (1 = uç), UV.y: 0..1 genişlik. Renk: ülke rengi (sRGB).
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_test_disabled, shadows_disabled;

uniform float opacity = 0.55;

void fragment() {
	float e = abs(UV.y - 0.5) * 2.0;
	vec3 base = pow(COLOR.rgb, vec3(2.2));
	vec3 body = base * mix(0.95, 0.7, smoothstep(0.2, 0.85, e));
	float outline = smoothstep(0.78, 0.9, e);
	ALBEDO = mix(body, base * 0.25, outline);
	// kuyruk tarafı daha soluk: uca doğru belirginleşir
	float fade = mix(0.55, 1.0, smoothstep(0.0, 0.35, UV.x));
	ALPHA = opacity * fade * (1.0 - smoothstep(0.95, 1.0, e));
}
