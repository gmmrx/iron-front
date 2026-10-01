// Dünya saati (WorldGlobe): üst çubukta küçük küre. Haritanın arazi dokusu (Miller izdüşümü) küreye sarılır; küre oyuncunun
// başkentinin üstüne bakar. Güneşin altındaki nokta oyun saatiyle döner (öğlen başkentin üstünde), mevsimle kuzey-güney
// kayar: gece tarafı koyu, gece-gündüz sınırı yumuşak. Kenarda ince atmosfer ışıltısı.
shader_type canvas_item;

uniform sampler2D map_tex : filter_linear_mipmap, repeat_enable;
uniform float view_lon = 0.6;      // küre ortasının boylamı (radyan)
uniform float view_lat = 0.45;     // küre ortasının enlemi (radyan; kuzey biraz görünsün)
uniform float sun_lon = 0.0;       // güneşin altındaki boylam (radyan)
uniform float sun_lat = 0.0;       // güneşin sapması (radyan)
uniform float lon_min = -2.941;    // haritanın sol kenarının boylamı (radyan)
uniform float y_top = 1.988;       // Miller: haritanın üst kenarı
uniform float px_per_rad = 2607.6;
uniform float map_h = 8106.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.y = -p.y;
	float r = length(p);
	float edge = 1.0 - smoothstep(0.94, 1.0, r);
	if (r > 1.0) {
		// atmosfer halesi
		float halo = 1.0 - smoothstep(1.0, 1.08, r);
		COLOR = vec4(0.45, 0.7, 1.0, halo * 0.35);
	} else {
		vec3 n = vec3(p.x, p.y, sqrt(max(1.0 - r * r, 0.0)));
		float ca = cos(view_lat);
		float sa = sin(view_lat);
		vec3 w = vec3(n.x, n.y * ca + n.z * sa, -n.y * sa + n.z * ca);
		float lat = asin(clamp(w.y, -1.0, 1.0));
		float lon = atan(w.x, w.z) + view_lon;
		float u = fract((lon - lon_min) / 6.2831853);
		float my = 1.25 * log(tan(0.7853982 + 0.4 * clamp(lat, -1.45, 1.45)));
		float v = (y_top - my) * px_per_rad / map_h;
		vec3 col = (v < 0.0 || v > 1.0) ? vec3(0.86, 0.9, 0.95) : texture(map_tex, vec2(u, v)).rgb;
		vec3 wn = vec3(cos(lat) * sin(lon), sin(lat), cos(lat) * cos(lon));
		vec3 sd = vec3(cos(sun_lat) * sin(sun_lon), sin(sun_lat), cos(sun_lat) * cos(sun_lon));
		float day = smoothstep(-0.10, 0.14, dot(wn, sd));
		col = mix(col * vec3(0.16, 0.19, 0.30), col, day);
		col *= 0.7 + 0.3 * n.z;                                   // kenara doğru kararır (küre hissi)
		col += vec3(0.35, 0.55, 0.9) * pow(1.0 - n.z, 3.0) * 0.35 * (0.3 + 0.7 * day);
		COLOR = vec4(col, edge);
	}
}
