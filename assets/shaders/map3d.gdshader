// Düz harita yüzeyi: yükseklik verisi yalnız boyalı arazi detayı + siyasi katman için.
// Renk hesapları sRGB uzayında yapılır, sonda lineere çevrilir.
// terrain_tex  : terrain.png (RGB=sRGB ham, A=1 doğal / 0 temiz şehir parseli, mipmap)
// height_tex   : yükseklik (metre, RF)
// province_tex : province id (R + G*256), nearest
// border_tex   : mesafe alanları (R=province, G=state, B=kıyı, A=nehir+2), 1/8 texel birimi
// data_tex     : province başına veri (R=sahip, G=kontrol eden, B/A=eyalet id), 256 genişlik
// palette_tex  : ülke renkleri (x = ülke indeksi)
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D terrain_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D height_tex : filter_linear, repeat_enable;
uniform sampler2D province_tex : filter_nearest, repeat_disable;
uniform sampler2D border_tex : filter_linear, repeat_enable;
uniform sampler2D data_tex : filter_nearest, repeat_disable;
uniform sampler2D recon_tex : filter_nearest, repeat_disable;
uniform bool recon_enabled = false;
uniform sampler2D palette_tex : filter_nearest, repeat_disable;
uniform sampler2D water_tex : filter_linear_mipmap, repeat_enable;   // L = derinlik tonu, A = taban gölgesi
uniform float cloud_amount = 0.0;   // uzak zoom'da bulut gölgeleri (0..1)
// yakın zoom detayı: 7 katmanlı doku dizisi (farmland, grass, forest, rock, sand, snow, steppe)
uniform sampler2DArray detail_albedo : filter_linear_mipmap_anisotropic, repeat_enable;
#if CURRENT_RENDERER != RENDERER_COMPATIBILITY
uniform sampler2DArray detail_normal : filter_linear_mipmap_anisotropic, repeat_enable;
#endif
uniform sampler2D biome_tex : filter_linear, repeat_enable;   // RGBA = orman, tarla, çöl, bozkır
uniform float detail_tile = 14.0;       // bir doku tekrarının dünya birimi
uniform vec3 detail_avg[7];             // katmanların ortalama renkleri (renk oranı için)
uniform vec2 map_size = vec2(5120.0, 4348.0);
uniform bool proj_miller = false;       // dünya haritası: enlem Miller tersinden
uniform float proj_y_top = 0.0;
uniform float proj_px_per_rad = 1.0;
uniform float proj_lon_min = 0.0;        // haritanın sol kenarının boylamı (derece)
// gece ve gündüz (DayNight): güneşin tepede olduğu nokta, gecenin gücü, 3D ışığın kısılma katı (zeminde geri alınır)
uniform vec2 sun_lonlat = vec2(0.0, 0.0);
uniform float night_strength = 0.0;
uniform float light_comp = 1.0;
uniform vec3 night_tint = vec3(0.42, 0.48, 0.66);

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
uniform float relief_scale = 0.012; // yalnız 2D gölge/eğim: mesh ve model yüksekliği değil
uniform float winter_north = 0.0;   // 0..1 kış şiddeti (kuzey yarıküre)
uniform float winter_south = 0.0;
uniform int map_mode = 0; // 0 siyasi, 1 arazi, 2 eyaletler, 3 yollar (soluk siyasi)
uniform int hovered_province = 0;
uniform int selected_province = 0;
uniform int selected_state = 0;
uniform int player_country = 0;
uniform int highlight_country = 0;
uniform float highlight_fade = 1.0;     // seçili ülkenin ışığı (0..1): sınırı neon yanar, karartmadan muaf
uniform int highlight_prev = 0;         // ülke değişirken önceki seçim: ışığı söner (karartma hiç kalkmaz: flaş yok)
uniform float prev_fade = 0.0;
uniform float dim_amount = 1.0;         // seçili olmayan her yerin kararması (0..1)
uniform vec3 neon_color = vec3(1.0, 0.58, 0.14);
uniform sampler2D mark_tex : filter_nearest, repeat_disable;   // province başına işaret (R: 0 yok, 0.5 uygun değil, 1 uygun)
uniform bool marks_enabled = false;   // ülke seçim ekranında vurgulanan ülke (0 = yok)

uniform bool wrap_x = false;           // dünya haritası doğu-batı sarmalanır
uniform bool srgb_out = false;   // Compatibility (web) renderer: çıkış sRGB, koddan açılır
uniform float land_brightness = 0.70;   // kara parlaklığı (ülke rengi MapView3D.map_tone ile açık-canlı aralıkta gelir)
uniform float water_brightness = 0.9;
uniform float political_saturation = 0.92;
uniform sampler2D rim_tex : filter_linear, repeat_enable;   // ülke sınırına yakınlık (CountryRim): 1 sınırda, içeride 0
uniform float fill_inner = 0.28;       // siyasi kipte ülke renginin ülke içindeki örtücülüğü (altından zemin görünür)
uniform float fill_edge = 0.97;        // sınırdaki örtücülük (renk sınıra doğru koyulaşır)
uniform sampler2D fog_mask : filter_linear, repeat_enable;   // savaş sisi: R = keşfedilmemiş payı (CloudFog maskesi)
uniform bool fog_enabled = false;
uniform float fog_fade = 1.0;          // savaş sisi renginin girişi (bulutla birlikte yavaşça); 1 = olağan

varying vec2 g_uv;   // tüm harita UV'si (mesh parçalı olduğundan dünya konumundan)

void vertex() {
	vec2 wxz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	vec2 guv = wxz / map_size;
	g_uv = guv;
	VERTEX.y = 0.0;
	NORMAL = vec3(0.0, 1.0, 0.0);
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

// siyasi kipteki sahip: bölgeyi elinde tutan (land_color ile aynı)
int pol_owner(int id) {
	vec4 d = pdata(id);
	int held = int(round(d.g * 255.0));
	return ((map_mode == 0 || map_mode == 3) && held > 0) ? held : int(round(d.r * 255.0));
}

int state_of(int id) {
	vec4 d = pdata(id);
	return int(round(d.b * 255.0)) + int(round(d.a * 255.0)) * 256;
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

float h21(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453); }

// Dağlarda ince sırtlar ve dereler (gravür gibi): düşük çözünürlüklü yükseklik haritası yumuşak tümsek verir, tasarımdaki
// kırış kırış dağ dokusu bükülmüş, 3 katmanlı kırışık gürültünün eğiminden gelir. Tam sayı hash: büyük koordinatta
// (dünya haritası ~70 bin) sin tabanlı hash GPU'da bozulur.
float uhash(vec2 p) {
	uvec2 q = uvec2(ivec2(p) + ivec2(262144));
	uint h = (q.x * 1597334677u) ^ (q.y * 3812015801u);
	h = (h ^ (h >> 16u)) * 2246822519u;
	h ^= h >> 13u;
	return float(h & 16777215u) / 16777215.0;
}
float unoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(uhash(i), uhash(i + vec2(1.0, 0.0)), u.x), mix(uhash(i + vec2(0.0, 1.0)), uhash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float mtn_h(vec2 p) {
	vec2 w = vec2(unoise(p * 0.31 + 3.3), unoise(p * 0.31 + 8.1)) - 0.5;
	p += w * 1.9;                                            // bükülme: sırtlar düz çizgi değil, kollara ayrılır
	float h = 0.0;
	float a = 0.55;
	float f = 1.0;
	for (int i = 0; i < 3; i++) {
		float r = 1.0 - abs(unoise(p * f + float(i) * 17.0) * 2.0 - 1.0);
		h += r * r * a;
		f *= 2.2;
		a *= 0.48;
	}
	return h;
}
// Yamaçta eğim yönünde uzanan sırt ve dereler (eski haritalardaki tarama gibi): üç sabit yönde uzatılmış kırışık
// gürültü, yamacın baktığı yöne göre karışır. Yönler sabit olduğundan uzakta kayma/girdap olmaz.
float streak(vec2 p, vec2 dir) {
	vec2 q = vec2(dot(p, dir), dot(p, vec2(-dir.y, dir.x)));
	float n = unoise(vec2(q.x * 0.33, q.y * 1.3)) * 0.65 + unoise(vec2(q.x * 0.75, q.y * 2.9) + 7.0) * 0.35;
	return 1.0 - abs(n * 2.0 - 1.0);
}
float slope_streaks(vec2 wp, vec2 down) {
	vec2 p = wp * 0.9;
	vec2 d0 = vec2(1.0, 0.0);
	vec2 d1 = vec2(0.5, 0.866);
	vec2 d2 = vec2(-0.5, 0.866);
	float w0 = pow(abs(dot(down, d0)), 4.0) + 1e-3;
	float w1 = pow(abs(dot(down, d1)), 4.0) + 1e-3;
	float w2 = pow(abs(dot(down, d2)), 4.0) + 1e-3;
	return (streak(p, d0) * w0 + streak(p, d1) * w1 + streak(p, d2) * w2) / (w0 + w1 + w2);
}

// Ekranda sabit boylu sırt/dere dokusu (her zoom'da ~9 piksel aralık): iki komşu ikili ölçek karışır, zoom'da sıçramaz
float adaptive_streaks(vec2 wp, vec2 down, float tpp) {
	float lv = log2(max(tpp, 1e-3) * 9.0);
	float l0 = floor(lv);
	float f = lv - l0;
	float a = slope_streaks(wp / exp2(l0) * 1.1, down);
	float b = slope_streaks(wp / exp2(l0 + 1.0) * 1.1 + 13.0, down);
	return mix(a, b, f);
}
// ekranda sabit boylu yama dokusu (orman kümesi, bozkır, yakında tarla yaması yerine uzakta renk yamaları)
float adaptive_patch(vec2 wp, float tpp, float px) {
	float lv = log2(max(tpp, 1e-3) * px);
	float l0 = floor(lv);
	float f = lv - l0;
	float a = unoise(wp / exp2(l0)) * 0.6 + unoise(wp / exp2(l0 - 1.0) + 5.0) * 0.4;
	float b = unoise(wp / exp2(l0 + 1.0) + 9.0) * 0.6 + unoise(wp / exp2(l0) + 14.0) * 0.4;
	return mix(a, b, f);
}

vec2 ridge_grad(vec2 wp) {
	vec2 p = wp * 0.48;
	float e = 0.04;
	float c = mtn_h(p);
	return vec2(mtn_h(p + vec2(e, 0.0)) - c, mtn_h(p + vec2(0.0, e)) - c) / e;
}

// Tarla parselleri (boyalı harita): bölgeye göre hafif dönük ızgara, her kare 1-3 şeride bölünür; parsel rengi
// yeşil / zeytin / hardal / buğday / toprak paletinden. edge_px: en yakın parsel sınırına ekran pikseli.
const float FIELD_CELL = 2.4;           // parsel karesi (harita pikseli, ~4-5 km)
vec3 field_color(vec2 wp, float tpp, out float edge_px) {
	// tarla bölgesi (~14 harita pikseli): kendi yönü ve kayması; dönme bölgenin içinde yerel (uzakta kayma yok)
	vec2 dist = floor(wp / 14.0);
	float ang = (h21(dist + 3.7) - 0.5) * 0.9;
	mat2 rot = mat2(vec2(cos(ang), sin(ang)), vec2(-sin(ang), cos(ang)));
	vec2 q = (rot * (wp - (dist + 0.5) * 14.0)) / FIELD_CELL + vec2(h21(dist), h21(dist + 9.1)) * 7.0;
	vec2 cell = floor(q);
	vec2 f = fract(q);
	float r = h21(cell);
	float strips = r < 0.55 ? 1.0 : 2.0;                   // tek parsel ya da iki şerit
	bool vertical = h21(cell + 17.3) > 0.5;
	float along = vertical ? f.x : f.y;
	float si = floor(along * strips);
	float fs = fract(along * strips);
	float d = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
	d = min(d, min(fs, 1.0 - fs) / strips);
	edge_px = d * FIELD_CELL / max(tpp, 1e-4);
	float k = h21(cell * 1.7 + vec2(si * 3.1, si * 5.7));
	vec3 c;
	if (k < 0.24) { c = vec3(0.27, 0.37, 0.14); }          // koyu yeşil
	else if (k < 0.48) { c = vec3(0.38, 0.48, 0.18); }     // yeşil
	else if (k < 0.62) { c = vec3(0.50, 0.55, 0.22); }     // açık yeşil
	else if (k < 0.76) { c = vec3(0.47, 0.45, 0.19); }     // zeytin
	else if (k < 0.88) { c = vec3(0.64, 0.55, 0.23); }     // hardal
	else if (k < 0.95) { c = vec3(0.70, 0.62, 0.34); }     // buğday
	else { c = vec3(0.52, 0.40, 0.23); }                   // sürülmüş toprak
	return c * (0.92 + 0.16 * h21(cell + si + 5.1));
}

#include "res://assets/shaders/clouds.gdshaderinc"
#include "res://assets/shaders/occupation_ink.gdshaderinc"

// Boyalı kabartmanın sanal normali: silüet, derinlik ve model konumu değişmez.
vec3 height_normal(vec2 uv) {
	vec2 hs = vec2(textureSize(height_tex, 0));
	vec2 t = 1.0 / hs;
	float step_world = map_size.x / hs.x * 2.0;
	float hl = texture(height_tex, uv - vec2(t.x, 0.0)).r * relief_scale;
	float hr = texture(height_tex, uv + vec2(t.x, 0.0)).r * relief_scale;
	float hu = texture(height_tex, uv - vec2(0.0, t.y)).r * relief_scale;
	float hd = texture(height_tex, uv + vec2(0.0, t.y)).r * relief_scale;
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
#if CURRENT_RENDERER != RENDERER_COMPATIBILITY
			dn += (texture(detail_normal, vec3(duv, float(i))).rg * 2.0 - 1.0) * w[i];
#endif
		}
	}
	// ikinci ölçek: tekrar desenini kırmak için daha büyük ölçekte hafif çarpan
	vec2 duv2 = uv * map_size / (detail_tile * 5.3) + vec2(0.37, 0.61);
	float macro = texture(detail_albedo, vec3(duv2, 1.0)).g / max(detail_avg[1].g, 1e-3);
	ratio = (c / max(avg, vec3(1e-3))) * mix(1.0, macro, 0.35);
	ratio = mix(vec3(1.0), ratio, 0.6);   // detay makro rengi bozmasın, yalnız işlesin
}

// Siyasi kipte arazi (kabartma gölgesi, orman/dağ tonu, ışık) yalnız yakında: uzakta düz ülke rengi, harita okunur.
// tpp = ekran pikseli başına harita pikseli; dünya haritasında ≈ kamera uzaklığı / 1770 (300'de 0,17, 600'de 0,34).
float political_relief(float tpp) {
	return 1.0 - smoothstep(0.17, 0.34, tpp);
}

// kıyı işaretli mesafesi (texel; kara +, su -)
float coast_sd(vec2 uv) {
	return (texture(border_tex, uv).b * 255.0 - 128.0) / 8.0;
}

// kara rengi: siyasi/arazi/eyalet modu + nehir + sınırlar + seçim
vec3 land_color(vec2 uv, int pid, vec3 terr, vec4 bt, float tpp, float t, vec3 dratio, float close, vec3 nrm, float site) {
	vec4 d = pdata(pid);
	int owner = int(round(d.r * 255.0));
	// siyasi kiplerde bölge onu elinde tutanın renginde (ele geçen yer doğrudan alınır; çizgili işgal gösterimi yok)
	int held = int(round(d.g * 255.0));
	if ((map_mode == 0 || map_mode == 3) && held > 0) { owner = held; }
	int sid = int(round(d.b * 255.0)) + int(round(d.a * 255.0)) * 256;
	vec3 bd = bt.rgb * (255.0 / 8.0);
	float river_tx = bt.a * (255.0 / 8.0) - 2.0;
	float prov_px = bd.r / tpp;
	float state_px = bd.g / tpp;
	vec3 cc = texelFetch(palette_tex, ivec2(owner, 0), 0).rgb;
	// Siyasi kipte yakın zoom'da da boyalı parsel/orman/sırt detayları; uzakta eski sade ülke rengi korunur.
	float soft = map_mode == 0 ? 1.0 - close * 0.75 : 0.0;
	vec4 bio = texture(biome_tex, uv);
	float h_m = texture(height_tex, uv).r;
	float slope = 1.0 - nrm.y;
	float natural = 1.0 - site;
	float farm = bio.g * (1.0 - smoothstep(650.0, 1150.0, h_m)) * (1.0 - smoothstep(0.10, 0.25, slope)) * natural;
	// yakın zoom: makro arazi rengi detay dokusuyla işlenir (orman, kaya...); tarlada parseller aşağıda
	terr = mix(terr, clamp(terr * dratio, 0.0, 1.0), close * (1.0 - farm * 0.8) * (1.0 - soft));
	// koyu, doygun, kontrastlı arazi
	float tl = dot(terr, vec3(0.299, 0.587, 0.114));
	terr = mix(vec3(tl), terr, 1.35);
	terr = pow(clamp(terr, 0.0, 1.0), vec3(1.45)) * 0.82;
	// boyalı harita: tarla parselleri koyu çizgilerle; renk bölgenin tonuyla karışır (kurak yer sarımsı kalır)
	// parselin ekrandaki boyu: ~8 pikselden küçükse renk söner, ~16 pikselden küçükse kenar çizgisi (sık ızgara olmasın)
	float cell_px = FIELD_CELL / max(tpp, 1e-4);
	float fvis = farm * smoothstep(3.0, 8.0, cell_px) * (1.0 - soft);
	if (fvis > 0.01) {
		float edge_px;
		vec3 fc = field_color(uv * map_size, tpp, edge_px);
		float tlum = dot(terr, vec3(0.299, 0.587, 0.114));
		fc = mix(fc, fc * (0.55 + tlum * 2.2), 0.35);
		vec3 fld = mix(terr, fc, 0.7);
		fld *= mix(1.0, 0.6, (1.0 - smoothstep(0.25, 1.05, edge_px)) * smoothstep(9.0, 18.0, cell_px) * (1.0 - soft * 0.75));
		terr = mix(terr, fld, fvis);
	}
	// orta/uzak zoom (Arazi kipi): parsel seçilmeyecek kadar küçükken tarla bölgeleri renk yamaları olarak kalır
	float pvis = farm * (1.0 - smoothstep(3.0, 8.0, cell_px)) * (1.0 - soft) * (1.0 - smoothstep(2.0, 4.0, tpp));
	if (pvis > 0.01) {
		float pt = adaptive_patch(uv * map_size, tpp, 7.0);
		vec3 pc = mix(vec3(0.40, 0.48, 0.18), vec3(0.66, 0.58, 0.26), smoothstep(0.35, 0.75, pt));
		pc = mix(pc, vec3(0.26, 0.36, 0.14), smoothstep(0.62, 0.9, 1.0 - pt) * 0.6);
		terr = mix(terr, pc * (0.7 + dot(terr, vec3(0.33)) * 1.0), pvis * 0.55);
	}
	// arazi örtüsü (boyalı harita): orman koyu yeşil, yakında tepe kümeleri; bozkır haki toprak ve kuru ot; çöl kum
	vec2 wp = uv * map_size;
	float forest = bio.r * (1.0 - smoothstep(1700.0, 2400.0, h_m)) * natural;
	float steppe = bio.a * (1.0 - farm) * natural;
	float desert = bio.b * (1.0 - farm) * natural;
	if (forest > 0.02) {
		float canopy = 1.0;
		if (soft < 0.5) {
			// taç kümeleri ekranda sabit boyda (~6 piksel): her zoom'da ormanın dokusu seçilir
			float b = adaptive_patch(wp, tpp, 6.0);
			canopy = 0.62 + b * 0.75;
		}
		vec3 fcol = vec3(0.17, 0.28, 0.13) * canopy * (0.8 + dot(terr, vec3(0.33)) * 0.9);
		terr = mix(terr, fcol, clamp(forest * 1.2, 0.0, 0.85));
	}
	if (steppe > 0.02) {
		float dry = 0.93 + (unoise(wp * 1.1) * 0.6 + unoise(wp * 2.7 + 3.0) * 0.4) * 0.14;
		terr = mix(terr, vec3(0.60, 0.55, 0.34) * dry, steppe * 0.45);
	}
	if (desert > 0.02) {
		terr = mix(terr, vec3(0.80, 0.70, 0.48), desert * 0.5);
	}
	// dağlar: yaylada toprak-haki, dik yamaçta ve yüksekte gri-kahve kaya
	float mount = clamp(smoothstep(0.08, 0.40, slope) * 0.75 + smoothstep(700.0, 2000.0, h_m) * 0.45, 0.0, 0.85) * natural;
	float rock = clamp(smoothstep(0.28, 0.6, slope) * 0.8 + smoothstep(1800.0, 2600.0, h_m) * 0.6, 0.0, 1.0);
	vec3 mcol = mix(vec3(0.50, 0.44, 0.30), vec3(0.53, 0.49, 0.43), rock) * (0.85 + 0.3 * dot(terr, vec3(0.33)));
	terr = mix(terr, mcol, mount * mix(0.5, 0.8, rock) * (1.0 - forest * 0.6));
	// kar: enleme göre kar çizgisi, kışın iner; çok dik kayada tutunmaz
	float alat = abs(latitude(uv));
	float snow_line = mix(4800.0, 500.0, smoothstep(10.0, 70.0, alat));
	snow_line -= (latitude(uv) > 0.0 ? winter_north : winter_south) * 900.0;
	float snow = smoothstep(snow_line - 150.0, snow_line + 300.0, h_m) * (1.0 - smoothstep(0.55, 0.95, slope) * 0.55);
	terr = mix(terr, vec3(0.93, 0.94, 0.96), snow * 0.92);
	// Yerel, doğal tonlu temiz zemin; altında tepe/orman/tarla çizgileri okunmaz.
	// Kurak ve karlı bölgenin rengi kalır, açıklık suya/siyasi sınırlara dokunmaz.
	vec3 site_ground = mix(vec3(0.46, 0.48, 0.36), vec3(0.59, 0.54, 0.38), clamp(bio.b + bio.a * 0.6, 0.0, 1.0));
	site_ground = mix(site_ground, vec3(0.85, 0.87, 0.89), snow * 0.88);
	terr = mix(terr, site_ground, site);
	// kabartma gölgesi (gravür gibi): kuzeybatıdan sabit ışık, düzlükte 1; yamaçta eğim yönünde sırt ve dereler
	vec3 L = normalize(vec3(-1.0, 1.25, -1.0));
	float hills = smoothstep(0.03, 0.12, slope) * (1.0 - farm) * 0.35;
	// Arazi kipinde sırt ve dereler her zoom'da (ekranda sabit boy), kabartma daha güçlü; Siyasi kipte yok
	float rvis = max(mount, hills) * (1.0 - smoothstep(3.0, 6.0, tpp)) * (1.0 - soft);
	float macro = clamp(mix(1.0, clamp(dot(nrm, L), 0.0, 1.0) / dot(vec3(0.0, 1.0, 0.0), L), 1.15 - soft * 0.65), 0.55, 1.35);
	float micro = 1.0;
	if (rvis > 0.01) {
		vec2 down = length(nrm.xz) > 1e-4 ? normalize(nrm.xz) : vec2(1.0, 0.0);
		float st = adaptive_streaks(wp, down, tpp);
		// sırt açık, dere koyu; dik yamaçta daha belirgin
		micro = 1.0 + (st - 0.55) * mix(0.45, 0.9, smoothstep(0.1, 0.45, slope)) * rvis;
	}
	// siyasi kipte kabartma gölgesi yalnız yakında (uzakta düz zemin)
	terr *= mix(1.0, macro, map_mode == 0 ? political_relief(tpp) : 1.0) * micro;
	float lum = dot(terr, vec3(0.299, 0.587, 0.114));
	vec3 col;
	if (map_mode == 0 || map_mode == 3) {
		// siyasi: ülke rengi, arazi kabartmasıyla modüle edilir; yakınlaştıkça arazi belirginleşir
		float far = smoothstep(2.0, 5.0, tpp);
		// ülke rengi boyalı bir örtü: arazinin parlaklığıyla çarpılır (parseller, sırtlar ve gölgeler alttan görünür);
		// yakında yarı saydam, uzaklaştıkça ülke rengi baskın. Arazi kipinde örtü yok.
		vec3 pol;
		float wash;
		if (map_mode == 0) {
			// siyasi: yarı saydam ülke rengi — içeride altından zemin (orman, çöl tonu; yakında kabartma) görünür, sınıra
			// yaklaştıkça renk örtücüleşir (rim_tex); yakında zemin biraz daha belirgin
			float relief = political_relief(tpp);
			float edge = smoothstep(0.0, 1.0, texture(rim_tex, uv).r);
			pol = cc;
			wash = mix(fill_inner, fill_edge, edge) * mix(1.0, 0.9, relief);
			// alttaki zemin yarı gri: ülkenin rengi (tonu) kaymasın, zemin yalnız açık-koyu farkıyla görünsün
			terr = mix(vec3(lum), terr, 0.6);
		} else {
			pol = cc * 0.74 * mix(0.45 + lum * 1.9, 1.0, far * 0.6);
			wash = (mix(0.46, 0.9, smoothstep(0.35, 1.8, tpp)) + far * 0.06) * (1.0 - mount * 0.45 * (1.0 - far));
		}
		col = mix(terr, pol, wash);
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
	// siyasi kiplerde uzakta söner (kıta görünümünde yalnız ülkeler)
	float rfar = (map_mode == 0 || map_mode == 3) ? 1.0 - smoothstep(0.7, 1.2, tpp) : 1.0 - smoothstep(1.6, 3.2, tpp);
	float rv = (1.0 - smoothstep(-0.15, 0.55, river_tx / tpp)) * rfar;
		col = mix(col, vec3(0.27, 0.45, 0.58), rv * 0.85);

		// Existing occupied-state semantics: original owner is the fill, controller supplies sparse ink.
		// Draw borders afterward, so fine country/state lines are never painted over by the hatch.
		int ctl = int(round(d.g * 255.0));
		float hatch_footprint = max(fwidth(dot(uv * map_size, vec2(0.70710678))), 0.0001);
		if (ctl > 0 && ctl != owner && map_mode == 2) {
			vec3 occupier = texelFetch(palette_tex, ivec2(ctl, 0), 0).rgb;
			vec3 ink = mix(occupier, vec3(0.13, 0.115, 0.09), 0.35) * mix(0.70, 0.92, clamp(lum * 1.5, 0.0, 1.0));
			float shore_inset = smoothstep(0.05, 0.45, (bt.b * 255.0 - 128.0) / 8.0);
			col = mix(col, ink, occupation_ink(uv * map_size, hatch_footprint) * 0.58 * shore_inset);
		}

	// province ve eyalet sınırları: çevredeki pikseller başka bölgedeyse çizgi — her zoom'da kesintisiz, ekran pikseli
	// genişliğinde (mesafe alanı ince çizgide kesik kesik kalıyordu). Province (fare vurgusunun birimi): ince, açık ton;
	// eyalet: kalın, koyu. Komşu sorgusu yalnız sınırların yakınında (mesafe alanı kaba ama eleme için yeter).
	// Siyasi kiplerde bölge çizgileri ~500 kamera uzaklığına dek, eyalet çizgileri ~1250'ye dek; daha uzakta yalnız ülke
	// sınırı (kıta görünümünde yüzlerce ince çizgi haritayı buruşuk gösteriyordu). Arazi ve Eyaletler kipinde her zoom'da.
	bool pol_mode = map_mode == 0 || map_mode == 3;
	float sfade = pol_mode ? 1.0 - smoothstep(0.7, 1.3, tpp) : 1.0 - smoothstep(6.0, 10.0, tpp);
	float pfade = pol_mode ? 1.0 - smoothstep(0.28, 0.5, tpp) : 1.0 - smoothstep(3.0, 5.0, tpp);
	bool near_s = sfade > 0.0 && (bd.g < 5.0 || state_px < 8.0);
	bool near_p = pfade > 0.0 && (bd.r < 5.0 || prov_px < 8.0);
	if (near_s || near_p) {
		// yarı genişlik (ekran pikseli): yakında kalın, uzakta ince; iç halka kalın çizgiyi dolu tutar
		vec2 upx = vec2(length(dFdx(uv)), length(dFdy(uv))) * mix(2.4, 1.25, smoothstep(0.25, 3.0, tpp));
		float sedge = 0.0;
		float pedge = 0.0;
		for (int i = 0; i < 8; i++) {
			float a = float(i) * 0.785398;
			vec2 dir = vec2(cos(a), sin(a));
			int p2 = province_at(uv + dir * upx);
			int s2 = state_of(p2);
			if (s2 != sid && s2 != 0) { sedge += 0.09; }
			// iç halka: eyalet çizgisini doldurur; aynı eyaletin başka bölgesiyse province sınırı (eyaletinkinin yarı
			// kalınlığında)
			int p3 = province_at(uv + dir * upx * 0.6);
			int s3 = state_of(p3);
			if (s3 != sid && s3 != 0) {
				if (i % 2 == 0) { sedge += 0.07; }
			} else if (p3 != pid && s3 != 0) {
				pedge += 0.125;
			}
		}
		col = mix(col, col * 0.36, clamp(pedge * 2.0, 0.0, 1.0) * 0.72 * pfade);
		col = mix(col, col * 0.16, clamp(sedge * 2.4, 0.0, 1.0) * 0.82 * sfade);
	}

	// ülke sınırı: eyalet sınırına yakınken karşı tarafın sahibine bak
	if (state_px < 4.0) {
		float r = bd.g + 1.5;
		bool other = false;
		for (int i = 0; i < 8; i++) {
			float a = float(i) * 0.785398;
			int p2 = province_at(uv + vec2(cos(a), sin(a)) * r / map_size);
			int o2 = owner_of(p2);
			int h2 = int(round(pdata(p2).g * 255.0));
			if ((map_mode == 0 || map_mode == 3) && h2 > 0) { o2 = h2; }
			if (o2 != owner && o2 != 0) { other = true; }
		}
		if (other) {
			col = mix(col, cc * 0.22, line(state_px, 1.6) * 0.9);
		}
	}

	if (owner == player_country && map_mode == 0) { col *= 1.04; }
	if (marks_enabled) {
		float mk = texelFetch(mark_tex, ivec2(pid % 256, pid / 256), 0).r;
		if (mk > 0.75) {
			// değer büyüdükçe parlak yeşil (yürüme menzilinde: yakın gün parlak, uzak soluk; inşaatta hep en parlak)
			col = mix(col, vec3(0.45, 0.85, 0.35), 0.1 + (mk - 0.75) * 1.3 + 0.06 * sin(t * 3.0));
		} else {
			col *= 0.6;
		}
	}
	// seçili ülke hafif aydınlanır (öbür yerler fragment'te kararır); ülke değişirken eskisi söner, yenisi yanar
	col *= 1.0 + 0.1 * ((owner == highlight_country ? highlight_fade : 0.0) + (owner == highlight_prev ? prev_fade : 0.0));
	if (pid == hovered_province) { col = mix(col, vec3(1.0), 0.14); }
	if (sid == selected_state && selected_state > 0) {
		float pulse = 0.5 + 0.5 * sin(t * 3.0);
		col = mix(col, vec3(1.0, 0.95, 0.75), 0.1 + 0.06 * pulse);
		col = mix(col, vec3(1.0, 0.86, 0.45), line(state_px, 1.4));
	}
	if (pid == selected_province && selected_province > 0) {
		col = mix(col, vec3(1.0, 0.95, 0.8), line(prov_px, 0.9) * 0.9);
	}
	// yakın zoom'da arazi ışıkla fazla parlamasın (siyasi kipte değil: ülke rengi zoom'la değişmesin)
	if (map_mode != 0) { col *= mix(0.84, 1.0, smoothstep(0.2, 1.2, tpp)); }
	return col;
}

// su rengi: derinlik tonu + hafif dalga + deniz bölgesi sınırları
vec3 water_color(vec2 uv, int pid, vec3 terr, vec4 bt, float tpp, float t, vec4 dd) {
	vec2 p = uv * map_size;
	vec4 wt = textureGrad(water_tex, uv, dd.xy, dd.zw);
	float depth = wt.r;
	// açık tonlar (eski derin su neredeyse siyahtı): orta mavi okyanus, açıkta biraz koyulaşan, kıyıda turkuaz
	vec3 shallow = vec3(0.40, 0.62, 0.68);
	vec3 mid = vec3(0.27, 0.46, 0.58);
	vec3 deep = vec3(0.19, 0.34, 0.47);
	vec3 col = depth < 0.5 ? mix(shallow, mid, depth / 0.5) : mix(mid, deep, (depth - 0.5) / 0.5);
	col *= wt.a * 1.6;
	float shore_d = max(-(texture(border_tex, uv).b * 255.0 - 128.0) / 8.0, 0.0);
	// kıyıda turkuaz sığ su ışıması (boyalı harita), açığa doğru söner
	float close = 1.0 - smoothstep(0.3, 1.2, tpp);
	col = mix(col, vec3(0.18, 0.58, 0.64), exp(-shore_d / 1.3) * 0.7);
	col += exp(-shore_d / 0.6) * vec3(0.04, 0.10, 0.09);
	// kıyı çizgisinde ince, hafif dalgalanan köpük (ekranda ~2 piksel)
	float band = sin(shore_d * 2.2 - t * 1.4 + sin(p.x * 0.15) * 1.5) * 0.5 + 0.5;
	float foam = (1.0 - smoothstep(1.2, 3.2, shore_d / max(tpp, 1e-4))) * (0.75 + 0.25 * band);
	col = mix(col, vec3(0.88, 0.95, 0.94), foam * mix(0.35, 0.8, close));
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
	// siyasi kipte uzakta zemin bulanık örneklenir: yarı saydam ülke renginin altında benek değil geniş ton farkı
	vec4 tdd = map_mode == 0 ? dd * mix(5.0, 1.0, political_relief(tpp)) : dd;
	vec4 terrain_sample = textureGrad(terrain_tex, uv, tdd.xy, tdd.zw);
	vec3 terr = terrain_sample.rgb;
	float site = clamp(1.0 - terrain_sample.a, 0.0, 1.0);
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
	float close = 1.0 - smoothstep(0.12, 0.45, tpp);
	float detail_close = close * (1.0 - site);
	vec3 n_land = normalize(mix(height_normal(uv), vec3(0.0, 1.0, 0.0), site));
	vec3 dratio = vec3(1.0);
	vec2 dn = vec2(0.0);
	if (detail_close > 0.001 && land_a > 0.0) {
		float w[7];
		detail_weights(uv, n_land, w);
		sample_detail(uv, w, dratio, dn);
	}
	n_land = normalize(n_land + vec3(dn.x, 0.0, -dn.y) * 0.45 * detail_close * (map_mode == 0 ? 0.0 : 1.0));

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
	if (land_a > 0.0) { col = mix(col, land_color(uv, land_pid, terr, bt, tpp, TIME, dratio, detail_close, n_land, site) * land_brightness, land_a); }
	// siyasi kipte uzakta ışık da düz zemine vurur: dağların gölgesi ancak yaklaşınca belirir
	vec3 n_lit = map_mode == 0 ? normalize(mix(vec3(0.0, 1.0, 0.0), n_land, political_relief(tpp))) : n_land;
	vec3 n_final = normalize(mix(n_water, n_lit, land_a));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_final, 0.0)).xyz);
	// kıyı çizgisi
	col = mix(col, col * 0.45, line(abs(sd) / tpp, 0.7) * 0.6);

	// ülke seçimi: öbür her yer (deniz dahil) kararır; seçili ülkenin kara sınırı ve kıyısı neon gibi yanar — içte ince
	// parlak çekirdek, iki yana taşan hale (EMISSION: ortamın glow'u parlatır). Komşu sorgusu yalnız eyalet sınırı ya da
	// kıyı yakınında (ülke sınırı eyalet sınırlarının alt kümesi)
	if ((highlight_country > 0 || highlight_prev > 0) && dim_amount > 0.001) {
		int po = pol_owner(pid);
		bool mine_a = po == highlight_country;
		bool mine_b = po == highlight_prev;
		float lit = max(mine_a ? highlight_fade : 0.0, mine_b ? prev_fade : 0.0);
		col *= mix(1.0, mix(0.42, 1.0, lit), dim_amount);
		float gpx = mix(5.0, 3.5, smoothstep(1.0, 4.0, tpp));      // hale yarı genişliği (ekran pikseli)
		float near_b = min(bt.g * (255.0 / 8.0) / tpp, abs(sd) / tpp);
		if (near_b < gpx + 2.0) {
			vec2 upx = vec2(length(dFdx(uv)), length(dFdy(uv)));
			vec2 core = vec2(0.0);                                  // x: seçili ülke, y: önceki (geçişte)
			vec2 halo = vec2(0.0);
			for (int i = 0; i < 8; i++) {
				float a = float(i) * 0.785398;
				vec2 dir8 = vec2(cos(a), sin(a));
				int o1 = pol_owner(province_at(uv + dir8 * upx * 1.4));
				int o2 = pol_owner(province_at(uv + dir8 * upx * gpx));
				if ((o1 == highlight_country) != mine_a) { core.x += 0.25; }
				if ((o2 == highlight_country) != mine_a) { halo.x += 0.125; }
				if (highlight_prev > 0) {
					if ((o1 == highlight_prev) != mine_b) { core.y += 0.25; }
					if ((o2 == highlight_prev) != mine_b) { halo.y += 0.125; }
				}
			}
			core = clamp(core, 0.0, 1.0) * vec2(mine_a ? 1.0 : 0.55, mine_b ? 1.0 : 0.55);
			halo = clamp(halo * 1.6, 0.0, 1.0) * vec2(mine_a ? 0.7 : 0.45, mine_b ? 0.7 : 0.45);
			vec2 k = vec2(highlight_fade, prev_fade) * dim_amount * (0.9 + 0.1 * sin(T * 2.2));
			float c = dot(core, k);
			float h = dot(halo, k);
			col = mix(col, neon_color, clamp(c * 0.75 + h * 0.3, 0.0, 1.0));
			EMISSION = neon_color * neon_color * (c * 2.2 + h * 0.8);     // doygun turuncu-altın ışık
		}
	}

	// cephe: bizim taraf ile düşmanın elindeki bölgelerin sınırı yerin altından yanan bir damar gibi — ince parlak çekirdek,
	// iki yana taşan kızıl hale, boyunca akan ışık (EMISSION: ortamın glow'u parlatır). Komşu sorgusu yalnız eyalet
	// sınırının yakınında (cephe eyalet sınırlarının alt kümesi)
	// bulut gölgeleri (bulut katmanıyla aynı gürültü)
	if (cloud_amount > 0.001) {
		float cl = weather_cloud(uv * map_size + vec2(-40.0, -25.0), TIME);
		col *= 1.0 - cl * 0.35 * cloud_amount;
	}

	// Only a subtle unexplored tint. Terrain stays visible; Military hides units separately.
	if (fog_enabled) {
		float fu = texture(fog_mask, uv).r;
		vec3 mist = vec3(0.53, 0.59, 0.64);
		col = mix(col, mist, smoothstep(0.05, 0.85, fu) * 0.08 * fog_fade);
	}

	// ülke adları (SubViewport'ta çizilir, araziye boyanır)


	// gece ve gündüz: güneşin bu noktadaki yüksekliği; gece koyu mavimsi, terminatörde ince sıcak alacakaranlık
	if (proj_miller && night_strength > 0.001) {
		float la = radians(latitude(uv));
		float lo = radians(proj_lon_min + uv.x * 360.0);
		vec2 s = radians(sun_lonlat);
		float h = sin(la) * sin(s.y) + cos(la) * cos(s.y) * cos(lo - s.x);
		float night = (1.0 - smoothstep(-0.10, 0.06, h)) * night_strength;
		float dusk = (1.0 - smoothstep(0.0, 0.08, abs(h + 0.02))) * night_strength;
		col *= mix(vec3(1.0), night_tint, night);
		col *= mix(vec3(1.0), vec3(1.08, 0.94, 0.82), dusk * 0.6);
	}
	// 3D ışık yakında gece kısıldı: zemin kendi saatinin parlaklığında kalır (renk burada sRGB, ışık doğrusal)
	col /= srgb_out ? max(light_comp, 0.05) : pow(max(light_comp, 0.05), 1.0 / 2.2);

	// harita kenarı
	vec2 e = min(uv, 1.0 - uv);
	if (wrap_x) { e.x = 1.0; }   // sarmalanan haritada doğu-batı kenarı yok
	col *= mix(0.45, 1.0, smoothstep(0.0, 0.02, min(e.x, e.y)));
	if (recon_enabled && texelFetch(recon_tex, ivec2(pid % 256, pid / 256), 0).r > 0.5) {
		col = mix(col, vec3(0.20, 0.95, 0.32), 0.42 + 0.10 * sin(TIME * 3.0));
	}
	ALBEDO = srgb_out ? clamp(col, 0.0, 1.0) : pow(clamp(col, 0.0, 1.0), vec3(2.2));
	ROUGHNESS = mix(0.12, 0.95, land_a);
	SPECULAR = mix(0.6, 0.12, land_a);
}
