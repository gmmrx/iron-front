// Savaş sisi bulutları: haritanın üstünde yatay katmanlar (FogCloudLayer, MapView3D kurar). Yalnız keşfedilmemiş
// bölgelerin üstünde durur (fog_tex: bölge başına 0 bulut, 1 keşfedilmiş), kenarları komşu örneklerle yumuşar. Kabarık
// dokulu, yavaş sürüklenir; kamera bulutun içine yaklaşınca solar (içinden geçilir, ekranı kaplamaz).
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

#include "res://assets/shaders/clouds.gdshaderinc"

uniform sampler2D province_tex : filter_nearest, repeat_disable;
uniform sampler2D fog_tex : filter_nearest, repeat_disable;
uniform vec2 map_size = vec2(5120.0, 4348.0);
uniform bool wrap_x = false;
uniform float layer_seed = 0.0;       // katmanlar farklı bulut desenleri taşısın
uniform float opacity = 0.8;
uniform bool srgb_out = false;         // Compatibility (web) renderer

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// haritanın bu noktası keşfedilmemiş mi (1) — keşfedilmiş ya da harita dışı 0
float unexplored(vec2 px) {
	if (wrap_x) { px.x = mod(px.x, map_size.x); }
	if (px.x < 0.0 || px.y < 0.0 || px.x >= map_size.x || px.y >= map_size.y) { return 0.0; }
	vec4 c = texelFetch(province_tex, ivec2(px), 0);
	int p = int(round(c.r * 255.0)) + int(round(c.a * 255.0)) * 256;
	if (p == 0) { return 0.0; }
	return 1.0 - texelFetch(fog_tex, ivec2(p % 256, p / 256), 0).r;
}

void fragment() {
	vec2 px = world_pos.xz;
	// keşif bilgisi bakış doğrultusunda bulutun altındaki zemin noktasından: bulut ekranda tam keşfedilmemiş toprağın
	// üstünde durur (yükseklikten gelen kayma yok); dokusu ise yükseklikte kalır, kamera dönünce derinlik verir
	vec3 dir = normalize(world_pos - CAMERA_POSITION_WORLD);
	vec2 gpx = dir.y < -0.05 ? (world_pos + dir * (world_pos.y / -dir.y)).xz : px;
	// yumuşak kenar: merkez + sekiz komşu örnek
	float r = 48.0;
	float u = unexplored(gpx) * 0.2;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.7854;
		u += unexplored(gpx + vec2(cos(a), sin(a)) * r) * 0.1;
	}
	if (u < 0.01) { discard; }
	vec2 q = px + vec2(layer_seed * 311.0, layer_seed * 173.0);
	float d = cloud_fbm(q, TIME);
	float e = cloud_fbm(q + vec2(9.0, 6.0), TIME);
	// aralıklı bulut: kümeler belirgin, aralar neredeyse açık
	float cover = smoothstep(0.42, 0.8, d);
	float lit = smoothstep(0.25, 0.9, d + (d - e) * 1.6);
	vec3 col = mix(vec3(0.62, 0.66, 0.72), vec3(0.97, 0.97, 0.98), lit);
	// kamera bulutun içine girince solar
	float near_fade = smoothstep(12.0, 70.0, distance(world_pos, CAMERA_POSITION_WORLD));
	ALBEDO = srgb_out ? col : pow(col, vec3(2.2));
	ALPHA = smoothstep(0.0, 1.0, u) * (0.08 + 0.82 * cover) * opacity * near_fade;
}
