// Şehir minyatürlerinin camları (glTF "city_glass" yüzeyi): gündüz koyu cam; gece pencerelerin bir kısmı sıcak sarı yanar.
// Gece hesabı map3d ile aynı (DayNight uniform'ları); hangi pencerenin yandığı dünya konumunun ızgarasından sabit
// (her karede değişmez, yanıp sönmez).
shader_type spatial;
render_mode cull_disabled;

uniform vec3 glass_color = vec3(0.105, 0.145, 0.16);
uniform vec2 sun_lonlat = vec2(0.0, 0.0);
uniform float night_strength = 0.0;
uniform vec2 map_size = vec2(1.0, 1.0);
uniform float proj_lon_min = 0.0;
uniform float proj_y_top = 0.0;
uniform float proj_px_per_rad = 1.0;
uniform float lit_share = 0.6;          // gece yanan pencere payı
uniform float cell = 0.09;              // aynı ışığı paylaşan pencere öbeği (dünya birimi; bir oda / bir kat parçası)
uniform bool srgb_out = false;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash3(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

void fragment() {
	vec3 albedo = glass_color;
	ROUGHNESS = 0.37;
	METALLIC = 0.08;
	if (night_strength > 0.001) {
		float la = 2.5 * atan(exp(0.8 * (proj_y_top - wpos.z / proj_px_per_rad))) - 0.625 * PI;
		float lo = radians(proj_lon_min + wpos.x / map_size.x * 360.0);
		vec2 s = radians(sun_lonlat);
		float h = sin(la) * sin(s.y) + cos(la) * cos(s.y) * cos(lo - s.x);
		float night = (1.0 - smoothstep(-0.10, 0.06, h)) * night_strength;
		float r = hash3(floor(wpos / cell));
		float on = step(1.0 - lit_share, r);
		// sıcak ampul ışığı; pencereden pencereye biraz farklı ton
		vec3 lamp = mix(vec3(1.0, 0.72, 0.36), vec3(1.0, 0.86, 0.58), fract(r * 7.13));
		EMISSION = lamp * on * night * 1.6;
		albedo = mix(albedo, lamp * 0.6, on * night * 0.5);
	}
	ALBEDO = srgb_out ? pow(albedo, vec3(1.0 / 2.2)) : albedo;   // glTF cam rengi doğrusal; web yolu sRGB ister
}
