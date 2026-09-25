// 3D harita shader'ı: yükseklik haritasıyla kabartılmış arazi + siyasi katman.
// Renk hesapları sRGB uzayında yapılır, sonda lineere çevrilir.
// terrain_tex  : terrain.png (sRGB ham, mipmap)
// height_tex   : yükseklik (metre, RF)
// province_tex : province id (R + G*256), nearest
// border_tex   : mesafe alanları (R=province, G=state, B=kıyı, A=nehir+2), 1/8 texel birimi
// data_tex     : province başına veri (R=sahip, G=kontrol eden, B/A=eyalet id), 256 genişlik
// palette_tex  : ülke renkleri (x = ülke indeksi)
// label_tex    : ülke adı katmanı (önceden çarpılmış alfa)
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D terrain_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D height_tex : filter_linear, repeat_enable;
uniform sampler2D province_tex : filter_nearest, repeat_disable;
uniform sampler2D border_tex : filter_linear, repeat_enable;
uniform sampler2D data_tex : filter_nearest, repeat_disable;
uniform sampler2D palette_tex : filter_nearest, repeat_disable;
uniform sampler2D label_tex : filter_linear, repeat_disable;
uniform sampler2D water_tex : filter_linear_mipmap, repeat_enable;   // L = derinlik tonu, A = taban gölgesi
uniform float cloud_amount = 0.0;   // uzak zoom'da bulut gölgeleri (0..1)
// yakın zoom detayı: 7 katmanlı doku dizisi (farmland, grass, forest, rock, sand, snow, steppe)
uniform sampler2DArray detail_albedo : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray detail_normal : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D biome_tex : filter_linear, repeat_enable;   // RGBA = orman, tarla, çöl, bozkır
uniform float detail_tile = 14.0;       // bir doku tekrarının dünya birimi
uniform vec3 detail_avg[7];             // katmanların ortalama renkleri (renk oranı için)
uniform vec2 map_size = vec2(5120.0, 4348.0);
uniform bool proj_miller = false;       // dünya haritası: enlem Miller tersinden
uniform float proj_y_top = 0.0;
uniform float proj_px_per_rad = 1.0;

// kış örtüsü için yumuşak değer gürültüsü
float whash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float wnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(whash(i), whash(i + vec2(1.0, 0.0)), u.x), mix(whash(i + vec2(0.0, 1.0)), whash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// derece cinsinden enlem (Avrupa haritasında yaklaşık 34..72)
float latitude(vec2 uv) {
	if (!proj_miller) {
		return mix(72.0, 34.0, uv.y);
	}
	float y = proj_y_top - uv.y * map_size.y / proj_px_per_rad;
	return degrees(2.5 * atan(exp(0.8 * y)) - 0.625 * PI);
}
uniform float height_scale = 0.012; // dünya birimi / metre (abartılı)
uniform float winter_north = 0.0;   // 0..1 kış şiddeti (kuzey yarıküre)
uniform float winter_south = 0.0;
uniform int map_mode = 0; // 0 siyasi, 1 arazi, 2 eyaletler, 3 yollar (soluk siyasi)
uniform int hovered_province = 0;
uniform int selected_province = 0;
uniform int selected_state = 0;
uniform int player_country = 0;
uniform int highlight_country = 0;
uniform sampler2D mark_tex : filter_nearest, repeat_disable;   // province başına işaret (R: 0 yok, 0.5 uygun değil, 1 uygun)
uniform bool marks_enabled = false;   // ülke seçim ekranında vurgulanan ülke (0 = yok)

uniform bool wrap_x = false;           // dünya haritası doğu-batı sarmalanır
uniform bool srgb_out = false;   // Compatibility (web) renderer: çıkış sRGB, koddan açılır
uniform float land_brightness = 0.8;   // kara parlaklığı (koyu, doygun ton)
uniform float water_brightness = 0.9;
uniform float political_saturation = 1.18;

float height_at(vec2 uv) {
	if (wrap_x) { uv.x = fract(uv.x); }
	return textureLod(height_tex, uv, 0.0).r * height_scale;
}

varying vec2 g_uv;   // tüm harita UV'si (mesh parçalı olduğundan dünya konumundan)

void vertex() {
	vec2 wxz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	vec2 guv = wxz / map_size;
	g_uv = guv;
	VERTEX.y = height_at(guv);
	vec2 hs = vec2(textureSize(height_tex, 0));
	vec2 t = 1.0 / hs;
	float step_world = map_size.x / hs.x * 2.0; // iki texel arası dünya mesafesi
	float hl = height_at(guv - vec2(t.x, 0.0));
	float hr = height_at(guv + vec2(t.x, 0.0));
	float hu = height_at(guv - vec2(0.0, t.y));
	float hd = height_at(guv + vec2(0.0, t.y));
	NORMAL = normalize(vec3(hl - hr, step_world, hu - hd));
}

int province_at(vec2 uv) {
	if (wrap_x) { uv.x = fract(uv.x); }
	ivec2 p = ivec2(clamp(uv * map_size, vec2(0.0), map_size - 1.0));
	vec4 c = texelFetch(province_tex, p, 0);
	return int(round(c.r * 255.0)) + int(round(c.a * 255.0)) * 256;   // LA8: L düşük, A yüksek bayt
}

vec4 pdata(int id) {
	return texelFetch(data_tex, ivec2(id % 256, id / 256), 0);
}

int owner_of(int id) {
	return int(round(pdata(id).r * 255.0));
}

vec3 hash3(int n) {
	uint x = uint(n) * 747796405u + 2891336453u;
	x = ((x >> ((x >> 28u) + 4u)) ^ x) * 277803737u;
	x = (x >> 22u) ^ x;
	return vec3(float(x & 255u), float((x >> 8u) & 255u), float((x >> 16u) & 255u)) / 255.0;
}

float line(float dist_px, float width) {
	return 1.0 - smoothstep(width - 0.6, width + 0.6, dist_px);
}

#include "res://assets/shaders/clouds.gdshaderinc"

// piksel başına arazi normali (dünya uzayı), yükseklik dokusundan
vec3 height_normal(vec2 uv) {
	vec2 hs = vec2(textureSize(height_tex, 0));
	vec2 t = 1.0 / hs;
	float step_world = map_size.x / hs.x * 2.0;
	float hl = texture(height_tex, uv - vec2(t.x, 0.0)).r * height_scale;
	float hr = texture(height_tex, uv + vec2(t.x, 0.0)).r * height_scale;
	float hu = texture(height_tex, uv - vec2(0.0, t.y)).r * height_scale;
	float hd = texture(height_tex, uv + vec2(0.0, t.y)).r * height_scale;
	return normalize(vec3(hl - hr, step_world, hu - hd));
}

// biyom + eğim + yükseklik -> 7 katman ağırlığı
void detail_weights(vec2 uv, vec3 n, out float w[7]) {
	vec4 b = texture(biome_tex, uv);
	float h_m = texture(height_tex, uv).r;              // metre
	float slope = 1.0 - n.y;
	// kar çizgisi: ekvatorda ~4800 m, 70° enlemde ~500 m
	float alat = abs(latitude(uv));
	float snow_line = mix(4800.0, 500.0, smoothstep(10.0, 70.0, alat));
	// mevsim: kışın kar çizgisi aşağı iner, orta enlemlerde ovalar da karlanır (kuzey/güney yarıküre ayrı)
	float wint = latitude(uv) > 0.0 ? winter_north : winter_south;
	snow_line -= wint * mix(0.0, 5200.0, smoothstep(38.0, 58.0, alat));
	float snow = smoothstep(snow_line - 250.0, snow_line + 150.0, h_m + slope * 900.0);
	float rock = max(smoothstep(0.035, 0.09, slope), smoothstep(1500.0, 2300.0, h_m) * 0.85) * (1.0 - snow);
	float rest = (1.0 - snow) * (1.0 - rock);
	float alpine = smoothstep(650.0, 1150.0, h_m);   // yükseklerde tarla yok: çayır/orman
	float forest = b.r, farm = b.g * (1.0 - alpine), desert = b.b, steppe = b.a;
	float grass = max(1.0 - forest - farm - desert - steppe, 0.0);
	float sum = forest + farm + desert + steppe + grass + 1e-4;
	w[0] = farm / sum * rest;
	w[1] = grass / sum * rest;
	w[2] = forest / sum * rest;
	w[3] = rock;
	w[4] = desert / sum * rest;
	w[5] = snow;
	w[6] = steppe / sum * rest;
}

// detay rengi (ortalamaya bölünmüş oran) ve teğet uzayı normal sapması
void sample_detail(vec2 uv, float w[7], out vec3 ratio, out vec2 dn) {
	vec2 duv = uv * map_size / detail_tile;
	vec3 c = vec3(0.0);
	vec3 avg = vec3(0.0);
	dn = vec2(0.0);
	for (int i = 0; i < 7; i++) {
		if (w[i] > 0.02) {
			c += texture(detail_albedo, vec3(duv, float(i))).rgb * w[i];
			avg += detail_avg[i] * w[i];
			dn += (texture(detail_normal, vec3(duv, float(i))).rg * 2.0 - 1.0) * w[i];
		}
	}
	// ikinci ölçek: tekrar desenini kırmak için daha büyük ölçekte hafif çarpan
	vec2 duv2 = uv * map_size / (detail_tile * 5.3) + vec2(0.37, 0.61);
	float macro = texture(detail_albedo, vec3(duv2, 1.0)).g / max(detail_avg[1].g, 1e-3);
	ratio = (c / max(avg, vec3(1e-3))) * mix(1.0, macro, 0.35);
	ratio = mix(vec3(1.0), ratio, 0.6);   // detay makro rengi bozmasın, yalnız işlesin
}

// kıyı işaretli mesafesi (texel; kara +, su -)
float coast_sd(vec2 uv) {
	return (texture(border_tex, uv).b * 255.0 - 128.0) / 8.0;
}

// kara rengi: siyasi/arazi/eyalet modu + nehir + sınırlar + seçim
vec3 land_color(vec2 uv, int pid, vec3 terr, vec4 bt, float tpp, float t, vec3 dratio, float close) {
	vec4 d = pdata(pid);
	int owner = int(round(d.r * 255.0));
	int sid = int(round(d.b * 255.0)) + int(round(d.a * 255.0)) * 256;
	vec3 bd = bt.rgb * (255.0 / 8.0);
	float river_tx = bt.a * (255.0 / 8.0) - 2.0;
	float prov_px = bd.r / tpp;
	float state_px = bd.g / tpp;
	vec3 cc = texelFetch(palette_tex, ivec2(owner, 0), 0).rgb;
	// yakın zoom: makro arazi rengi detay dokusuyla işlenir (tarla yamaları, orman, kaya...)
	terr = mix(terr, clamp(terr * dratio, 0.0, 1.0), close);
	// koyu, doygun, kontrastlı arazi
	float tl = dot(terr, vec3(0.299, 0.587, 0.114));
	terr = mix(vec3(tl), terr, 1.35);
	terr = pow(clamp(terr, 0.0, 1.0), vec3(1.45)) * 0.82;
	float lum = dot(terr, vec3(0.299, 0.587, 0.114));
	vec3 col;
	if (map_mode == 0 || map_mode == 3) {
		// siyasi: ülke rengi, arazi kabartmasıyla modüle edilir; yakınlaştıkça arazi belirginleşir
		float far = smoothstep(2.0, 5.0, tpp);
		vec3 pol = cc * 0.74 * mix(1.0, 0.5 + lum * 1.6, 0.5 * (1.0 - far * 0.6));
		col = mix(terr, pol, mix(0.66, 0.9, smoothstep(0.12, 1.3, tpp)) + far * 0.06);
		float pg = dot(col, vec3(0.299, 0.587, 0.114));
		col = max(mix(vec3(pg), col, political_saturation), vec3(0.0));
		if (map_mode == 3) {
			// yollar: rotalar öne çıksın diye soluk, koyu zemin
			float g = dot(col, vec3(0.299, 0.587, 0.114));
			col = mix(vec3(g), col, 0.3) * 0.62;
		}
	} else if (map_mode == 2) {
		col = mix(terr, mix(hash3(sid), cc, 0.35) * (0.55 + lum), 0.8);
	} else {
		col = terr;
	}

	// kış örtüsü (her modda): kuzeyde kar ülke renginin üstüne yağar, arazi dokusuyla dalgalanır
	float wlat = latitude(uv);
	float wv = (wlat > 0.0 ? winter_north : winter_south) * smoothstep(47.0, 62.0, abs(wlat));
	// yamalı: arazi parlaklığına ve ince bir desene göre (düz beyaz perde değil)
	float patch = wnoise(uv * vec2(700.0, 350.0)) * 0.6 + wnoise(uv * vec2(2600.0, 1300.0)) * 0.4;
	wv *= clamp(0.35 + lum * 0.8 + patch * 0.35, 0.0, 1.0);
	col = mix(col, vec3(0.9, 0.93, 0.97) * (0.85 + lum * 0.2), wv * 0.38);

	// nehirler: dünya ölçeğinde genişlik, uzakta söner
	float rv = (1.0 - smoothstep(-0.15, 0.55, river_tx / tpp)) * (1.0 - smoothstep(1.6, 3.2, tpp));
	col = mix(col, vec3(0.27, 0.45, 0.58), rv * 0.85);

	// province ve eyalet sınırları
	col = mix(col, col * 0.35, line(prov_px, 0.6) * (1.0 - smoothstep(1.2, 2.2, tpp)) * 0.42);
	col = mix(col, col * 0.3, line(state_px, 0.75) * (1.0 - smoothstep(3.5, 5.5, tpp)) * 0.55);

	// ülke sınırı: eyalet sınırına yakınken karşı tarafın sahibine bak
	if (state_px < 4.0) {
		float r = bd.g + 1.5;
		bool other = false;
		for (int i = 0; i < 8; i++) {
			float a = float(i) * 0.785398;
			int o2 = owner_of(province_at(uv + vec2(cos(a), sin(a)) * r / map_size));
			if (o2 != owner && o2 != 0) { other = true; }
		}
		if (other) {
			col = mix(col, cc * 0.22, line(state_px, 1.6) * 0.9);
		}
	}

	// işgal: kontrol eden ülkenin renginde çapraz çizgiler
	int ctl = int(round(d.g * 255.0));
	if (ctl > 0 && ctl != owner && map_mode == 0) {
		vec3 oc = texelFetch(palette_tex, ivec2(ctl, 0), 0).rgb;
		vec2 wp2 = uv * map_size;
		float stripe = step(0.5, fract((wp2.x + wp2.y) / max(6.0 * tpp, 3.0)));
		col = mix(col, oc * mix(1.0, 0.5 + lum * 1.1, 0.4), stripe * 0.75);
	}
	if (owner == player_country && map_mode == 0) { col *= 1.04; }
	if (marks_enabled) {
		float mk = texelFetch(mark_tex, ivec2(pid % 256, pid / 256), 0).r;
		if (mk > 0.75) {
			col = mix(col, vec3(0.45, 0.85, 0.35), 0.35 + 0.08 * sin(t * 3.0));
		} else {
			col *= 0.6;
		}
	}
	if (highlight_country > 0) {
		if (owner == highlight_country) {
			col = mix(col, vec3(1.0), 0.12 + 0.05 * sin(t * 2.5));
		} else {
			col *= 0.72;
		}
	}
	if (pid == hovered_province) { col = mix(col, vec3(1.0), 0.14); }
	if (sid == selected_state && selected_state > 0) {
		float pulse = 0.5 + 0.5 * sin(t * 3.0);
		col = mix(col, vec3(1.0, 0.95, 0.75), 0.1 + 0.06 * pulse);
		col = mix(col, vec3(1.0, 0.86, 0.45), line(state_px, 1.4));
	}
	if (pid == selected_province && selected_province > 0) {
		col = mix(col, vec3(1.0, 0.95, 0.8), line(prov_px, 0.9) * 0.9);
	}
	// yakın zoom'da arazi ışıkla fazla parlamasın
	col *= mix(0.84, 1.0, smoothstep(0.2, 1.2, tpp));
	return col;
}

// su rengi: derinlik tonu + hafif dalga + deniz bölgesi sınırları
vec3 water_color(vec2 uv, int pid, vec3 terr, vec4 bt, float tpp, float t, vec4 dd) {
	vec2 p = uv * map_size;
	vec4 wt = textureGrad(water_tex, uv, dd.xy, dd.zw);
	float depth = wt.r;
	vec3 shallow = vec3(0.282, 0.478, 0.549);
	vec3 mid = vec3(0.141, 0.282, 0.384);
	vec3 deep = vec3(0.067, 0.133, 0.212);
	vec3 col = depth < 0.5 ? mix(shallow, mid, depth / 0.5) : mix(mid, deep, (depth - 0.5) / 0.5);
	col *= wt.a * 1.6;
	float shore_d = max(-(texture(border_tex, uv).b * 255.0 - 128.0) / 8.0, 0.0);
	col += exp(-shore_d / 2.5) * vec3(0.08, 0.094, 0.07);
	// kıyıda hareketli köpük şeritleri (yakın zoom)
	float close = 1.0 - smoothstep(0.3, 1.2, tpp);
	float band = sin(shore_d * 2.2 - t * 1.4 + sin(p.x * 0.15) * 1.5) * 0.5 + 0.5;
	float foam = exp(-shore_d / 1.6) * (0.35 + 0.65 * band) * close;
	col = mix(col, vec3(0.86, 0.9, 0.9), foam * 0.55);
	float prov_px = bt.r * (255.0 / 8.0) / tpp;
	col = mix(col, vec3(0.75, 0.85, 0.95), line(prov_px, 0.5) * (1.0 - smoothstep(1.5, 3.0, tpp)) * 0.18);
	if (pid == hovered_province) { col = mix(col, vec3(0.8, 0.9, 1.0), 0.1); }
	if (pid == selected_province && selected_province > 0) {
		col = mix(col, vec3(0.9, 0.95, 1.0), line(prov_px, 1.0) * 0.8);
	}
	return col;
}

void fragment() {
	// sarmalanmış haritada g_uv.x kesintisiz (<0 ya da >1): örnekleme için sarılır, türevler kesintisiz UV'den
	vec4 dd = vec4(dFdx(g_uv), dFdy(g_uv));
	float tpp = max(fwidth(g_uv.x) * map_size.x, 1e-4);
	vec2 uv = g_uv;
	if (wrap_x) { uv.x = fract(uv.x); }
	vec3 terr = textureGrad(terrain_tex, uv, dd.xy, dd.zw).rgb;
	vec4 bt = texture(border_tex, uv);

	// kıyı: piksel ızgarası yerine işaretli mesafe alanının sıfır çizgisi (pürüzsüz)
	float sd = coast_sd(uv);
	float land_a = clamp(0.5 + sd / max(tpp, 0.05), 0.0, 1.0);
	int pid = province_at(uv);
	bool nearest_land = owner_of(pid) > 0;
	// en yakın texel yanlış taraftaysa mesafe alanının gradyanı yönünde doğru tarafın bölgesini bul
	vec2 tx = 1.0 / map_size;
	vec2 grad = vec2(coast_sd(uv + vec2(tx.x, 0.0)) - coast_sd(uv - vec2(tx.x, 0.0)),
	                 coast_sd(uv + vec2(0.0, tx.y)) - coast_sd(uv - vec2(0.0, tx.y)));
	vec2 dir = length(grad) > 1e-5 ? normalize(grad) : vec2(0.0);
	int land_pid = pid;
	int water_pid = pid;
	if (!nearest_land) {
		land_pid = province_at(uv + dir * tx * 1.2);
		if (owner_of(land_pid) == 0) { land_pid = province_at(uv + dir * tx * 2.2); }
	} else {
		water_pid = province_at(uv - dir * tx * 1.2);
		if (owner_of(water_pid) != 0) { water_pid = province_at(uv - dir * tx * 2.2); }
	}
	bool has_land = owner_of(land_pid) > 0;
	if (!has_land) { land_a = 0.0; }

	// yakın zoom detay katmanı
	float close = 1.0 - smoothstep(0.25, 0.95, tpp);
	vec3 n_land = height_normal(uv);
	vec3 dratio = vec3(1.0);
	vec2 dn = vec2(0.0);
	if (close > 0.001 && land_a > 0.0) {
		float w[7];
		detail_weights(uv, n_land, w);
		sample_detail(uv, w, dratio, dn);
	}
	n_land = normalize(n_land + vec3(dn.x, 0.0, -dn.y) * 0.45 * close);

	// su normali: analitik dalgalar (yakında)
	vec2 wp = uv * map_size;
	float T = TIME;
	vec2 g = vec2(0.0);
	g += vec2(0.7, 0.3) * cos(dot(wp, vec2(0.7, 0.3)) * 1.3 + T * 1.1) * 0.9;
	g += vec2(-0.4, 0.9) * cos(dot(wp, vec2(-0.4, 0.9)) * 2.1 + T * 1.6) * 0.5;
	g += vec2(0.2, -1.0) * cos(dot(wp, vec2(0.2, -1.0)) * 3.7 + T * 2.3) * 0.3;
	g += vec2(-0.9, -0.5) * cos(dot(wp, vec2(-0.9, -0.5)) * 5.3 + T * 2.9) * 0.2;
	vec3 n_water = normalize(vec3(-g.x * 0.08 * close, 1.0, -g.y * 0.08 * close));

	vec3 col = vec3(0.0);
	if (land_a < 1.0) {
		col = water_color(uv, water_pid, terr, bt, tpp, TIME, dd);
		// fresnel: sığ açıda gökyüzü yansıması
		vec3 nv = normalize((VIEW_MATRIX * vec4(n_water, 0.0)).xyz);
		float fres = pow(1.0 - clamp(dot(nv, VIEW), 0.0, 1.0), 4.0);
		col = mix(col, vec3(0.55, 0.66, 0.76), fres * 0.35);
	}
	col *= water_brightness;
	if (land_a > 0.0) { col = mix(col, land_color(uv, land_pid, terr, bt, tpp, TIME, dratio, close) * land_brightness, land_a); }
	vec3 n_final = normalize(mix(n_water, n_land, land_a));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_final, 0.0)).xyz);
	// kıyı çizgisi
	col = mix(col, col * 0.45, line(abs(sd) / tpp, 0.7) * 0.6);

	// bulut gölgeleri (bulut katmanıyla aynı gürültü)
	if (cloud_amount > 0.001) {
		float cl = cloud_density(uv * map_size + vec2(-40.0, -25.0), TIME);
		col *= 1.0 - cl * 0.35 * cloud_amount;
	}

	// ülke adları (SubViewport'ta çizilir, araziye boyanır)


	// harita kenarı
	vec2 e = min(uv, 1.0 - uv);
	if (wrap_x) { e.x = 1.0; }   // sarmalanan haritada doğu-batı kenarı yok
	col *= mix(0.45, 1.0, smoothstep(0.0, 0.02, min(e.x, e.y)));
	ALBEDO = srgb_out ? clamp(col, 0.0, 1.0) : pow(clamp(col, 0.0, 1.0), vec3(2.2));
	ROUGHNESS = mix(0.12, 0.95, land_a);
	SPECULAR = mix(0.6, 0.12, land_a);
}
