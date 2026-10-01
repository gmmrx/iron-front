// Ülke sınırı hücreleri (CountryRim, 1. geçiş): harita CELL pikselik hücrelere bölünür; hücrenin biraz dışına taşan
// 5×5 noktada iki farklı sahipli kara varsa hücre sınırdadır (R = 1). Su ve göl sayılmaz (kıyı sınır değil).
shader_type canvas_item;
render_mode blend_disabled, unshaded;

uniform sampler2D province_tex : filter_nearest, repeat_disable;
uniform sampler2D data_tex : filter_nearest, repeat_disable;
uniform vec2 map_size = vec2(5120.0, 4348.0);
uniform vec2 grid = vec2(320.0, 272.0);
uniform float cell = 16.0;
uniform bool wrap_x = false;

int province_at(vec2 p) {
	if (wrap_x) { p.x = mod(p.x, map_size.x); }
	ivec2 q = ivec2(clamp(p, vec2(0.0), map_size - 1.0));
	vec4 c = texelFetch(province_tex, q, 0);
	return int(round(c.r * 255.0)) + int(round(c.a * 255.0)) * 256;
}

// bölgeyi elinde tutan (siyasi haritada gösterilen; yoksa sahibi)
int owner_of(int id) {
	vec4 d = texelFetch(data_tex, ivec2(id % 256, id / 256), 0);
	int held = int(round(d.g * 255.0));
	return held > 0 ? held : int(round(d.r * 255.0));
}

void fragment() {
	vec2 cid = floor(UV * grid);
	vec2 base = (cid + 0.5) * cell;
	int first = 0;
	float edge = 0.0;
	for (int y = 0; y < 5; y++) {
		for (int x = 0; x < 5; x++) {
			// hücrenin %25 dışına taşar: iki hücrenin tam arasındaki sınır ikisinde de görülür
			vec2 p = base + (vec2(float(x), float(y)) / 4.0 - 0.5) * cell * 1.25;
			int o = owner_of(province_at(p));
			if (o == 0) { continue; }
			if (first == 0) { first = o; }
			else if (o != first) { edge = 1.0; }
		}
	}
	COLOR = vec4(edge, 0.0, 0.0, 1.0);
}
