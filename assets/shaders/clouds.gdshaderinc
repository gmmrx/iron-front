// Ortak bulut gürültüsü (bulut katmanı ve harita üzerindeki bulut gölgeleri)
float cl_hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float cl_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(cl_hash(i), cl_hash(i + vec2(1.0, 0.0)), u.x),
	           mix(cl_hash(i + vec2(0.0, 1.0)), cl_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// savaş sisinin bulut örtüsü: ham fbm (yaklaşık 0..1), yoğun ve kesintisiz örtü için; yavaş sürüklenir
float cloud_fbm(vec2 xz, float t) {
	vec2 p = xz * 0.006 + vec2(t * 0.004, t * 0.0018);
	float v = 0.0;
	float a = 0.55;
	for (int i = 0; i < 5; i++) {
		v += a * cl_noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

// hava cephesi 0..1: çok düşük frekanslı, yavaş sürüklenen gürültü — haritanın bir kısmında bulut olur, cephe geçip
// gidince dağılır (hava durumu gibi ara ara)
float weather_front(vec2 xz, float t) {
	float f = cl_noise(xz * 0.00022 + vec2(t * 0.0012, t * 0.0005)) * 0.7
		+ cl_noise(xz * 0.0006 + vec2(-t * 0.002, t * 0.001)) * 0.3;
	return smoothstep(0.5, 0.78, f);
}

// hava bulutu: cephe içinde küme bulutları (cephe güçlendikçe daha sık)
float weather_cloud(vec2 xz, float t) {
	vec2 p = xz * 0.0022 + vec2(t * 0.006, t * 0.0025);
	float v = 0.0;
	float a = 0.55;
	for (int i = 0; i < 5; i++) {
		v += a * cl_noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	float fr = weather_front(xz, t);
	return smoothstep(0.66 - 0.16 * fr, 0.88, v) * fr;
}

// dünya koordinatında (x, z) bulut yoğunluğu 0..1
float cloud_density(vec2 xz, float t) {
	vec2 p = xz * 0.0022 + vec2(t * 0.006, t * 0.0025);
	float v = 0.0;
	float a = 0.55;
	for (int i = 0; i < 5; i++) {
		v += a * cl_noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return smoothstep(0.6, 0.86, v);
}
