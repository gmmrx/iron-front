// Cephe hattı: sınır boyunca kalın bir sırt ve sırttan düşmana uzanan dişler (tarak), haritaya basılmış mürekkep.
// Dişler resimden değil burada çizilir: sabit dünya boyunda, sırt boyunca eşit aralıkla. Kıvrımda şerit yerel eğrilik
// yarıçapına göre daralır (FrontLayer.bend_width_scale; UV2'nin boyu), dişler onunla kısalır: iç kıvrımda üst üste
// binmez, dış kıvrımda yelpaze gibi açılmaz. Sırt yakında harita ölçeğinde kalınlaşır, uzakta en az spine_px piksel
// kalır (kıta görünümünde de seçilir); dişler ekranda sıklaşınca söner, uzakta yalnız sırt.
// UV.x: sınır boyunca uzunluk (dünya birimi), UV.y: 0 bizim yanın dış kenarı, 1 düşman yanının dış kenarı (sınır 0,5'te).
// UV2: düşmana doğru yön (xz), boyu kıvrım daralması (0..1).
// CUSTOM0.xy: bu noktadaki bölge çifti (bizim, düşmanın): fare vurgusu.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform float band = 8.0;       // dişlerin uzandığı şerit (dünya birimi, düz sınırda; sırt ortada)
uniform float spine_w = 1.0;    // sırtın kalınlığı yakında (dünya birimi)
uniform float spine_px = 4.5;   // sırtın ekrandaki en az kalınlığı (piksel)
uniform float period = 4.0;     // diş aralığı (dünya birimi)
uniform float tooth = 0.34;      // dişin dipteki genişliği / aralık (uçta biraz incelir)
uniform vec3 ink = vec3(0.58, 0.1, 0.08);
uniform float opacity = 0.9;
uniform int hover_a = 0;        // fare bu kesitin üstünde (bölge çifti): koyu ve kalın
uniform int hover_b = 0;
uniform bool srgb_out = false;  // Compatibility (web) renderer: çıkış sRGB
uniform sampler2D province_tex : filter_nearest, repeat_disable;
uniform sampler2D data_tex : filter_nearest, repeat_disable;
uniform bool province_mask_enabled = false;
uniform bool wrap_x = false;
uniform vec2 map_size = vec2(16384.0, 8106.0);

varying float emph;
varying vec2 world_position;
varying flat vec2 side_controls;
varying float half_w;           // şeridin bu noktadaki yarı genişliği (dünya birimi)
varying float wpp;              // bir ekran pikselinin dünya boyu
varying float bend;

int held_by(int id) {
	vec4 data = texelFetch(data_tex, ivec2(id % 256, id / 256), 0);
	int held = int(round(data.g * 255.0));
	return held > 0 ? held : int(round(data.r * 255.0));
}

void vertex() {
	int a = int(round(CUSTOM0.x));
	int b = int(round(CUSTOM0.y));
	emph = (hover_a > 0 && a == hover_a && b == hover_b) ? 1.0 : 0.0;
	side_controls = vec2(0.0);
	if (province_mask_enabled) { side_controls = vec2(float(held_by(a)), float(held_by(b))); }
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wpp = 2.0 * length(w - CAMERA_POSITION_WORLD) / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);
	bend = length(UV2);
	// uzakta şerit en az sırtın piksel kalınlığı kadar (artı kenar yumuşatma payı)
	half_w = max(band * 0.5 * bend, (spine_px * 0.5 + 1.5) * wpp);
	VERTEX.xz += UV2 / max(bend, 0.0001) * (UV.y - 0.5) * 2.0 * half_w;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float y = UV.y;
	float d = abs(y - 0.5) * 2.0 * half_w;              // sırttan uzaklık (dünya birimi)
	float aa = max(fwidth(d), 0.0001);
	float sw = max(spine_w, spine_px * wpp) * 0.5 * mix(1.0, 1.35, emph);
	float spine = 1.0 - smoothstep(sw - aa * 0.5, sw + aa * 0.5, d);
	// dişler: düşman yanında, sırtın kenarından kıvrımla kısalan boyda; dibi geniş, ucu biraz ince
	float reach = max(band * 0.5 * bend - sw, 0.0);
	float t = clamp((d - sw) / max(reach, 0.0001), 0.0, 1.0);
	float u = UV.x / period;
	float du = max(fwidth(u), 0.0001);
	float half_tooth = tooth * 0.5 * mix(1.0, 0.7, t);
	float across = 1.0 - smoothstep(half_tooth - du * 0.5, half_tooth + du * 0.5, abs(fract(u) - 0.5));
	float along = 1.0 - smoothstep(sw + reach - aa * 0.5, sw + reach + aa * 0.5, d);
	float teeth = across * along * step(0.5, y);
	teeth *= smoothstep(5.0, 9.0, period / max(wpp, 0.0001));   // diş aralığı ekranda 5-9 pikselden sıksa söner
	float a = max(spine, teeth * 0.92) * opacity;
	if (a < 0.003) { discard; }
	if (province_mask_enabled) {
		vec2 point = world_position;
		if (wrap_x) { point.x = mod(point.x, map_size.x); }
		if (point.x < 0.0 || point.y < 0.0 || point.x >= map_size.x || point.y >= map_size.y) { discard; }
		vec4 pixel = texelFetch(province_tex, ivec2(point), 0);
		int pid = int(round(pixel.r * 255.0)) + int(round(pixel.a * 255.0)) * 256;
		int held = held_by(pid);
		// Keep the smoothed spine continuous across the raster border staircase.
		if (held <= 0 || (float(held) != side_controls.x && float(held) != side_controls.y)) { discard; }
	}
	vec3 c = ink * mix(1.0, 0.8, emph);
	ALBEDO = srgb_out ? c : pow(c, vec3(2.2));
	ALPHA = clamp(a, 0.0, 1.0);
}
