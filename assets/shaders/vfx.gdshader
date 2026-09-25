shader_type spatial;
// Prosedürel savaş efektleri (parçacık dörtgenleri, kameraya dönük). Yaş: COLOR.a (renk rampası 1 -> 0).
// kind: 0 patlama ateş topu · 1 duman · 2 namlu alevi · 3 toprak/moloz · 4 kıvılcım
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform int kind = 0;
uniform vec4 tint : source_color = vec4(1.0);
uniform float intensity = 1.0;

varying float seed;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	// parçacık billboard (ölçek korunur, CUSTOM.x dönüşü)
	mat4 mv = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	float ang = INSTANCE_CUSTOM.x;
	mat4 rot = mat4(vec4(cos(ang), -sin(ang), 0.0, 0.0), vec4(sin(ang), cos(ang), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = mv * rot * mat4(vec4(sx, 0.0, 0.0, 0.0), vec4(0.0, sy, 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	seed = hash(vec2(float(INSTANCE_ID) * 0.137, 3.1));
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float age = clamp(1.0 - COLOR.a, 0.0, 1.0);
	vec3 col = vec3(0.0);
	float a = 0.0;
	if (kind == 0) {
		// ateş topu: kenarı gürültülü, beyaz-sarı çekirdekten turuncu-koyu kırmızıya, sonra is
		float n = fbm(q * 2.4 + seed * 17.0 + vec2(0.0, -age * 1.5));
		float edge = 0.55 + 0.35 * n;
		float body = 1.0 - smoothstep(edge - 0.18, edge, r);
		float heat = clamp((1.0 - r / max(edge, 0.01)) * (1.0 - age * 1.3) + n * 0.25, 0.0, 1.0);
		vec3 fire = mix(vec3(0.35, 0.05, 0.01), vec3(1.0, 0.45, 0.08), smoothstep(0.1, 0.5, heat));
		fire = mix(fire, vec3(1.0, 0.92, 0.6), smoothstep(0.6, 0.95, heat));
		vec3 soot = vec3(0.09, 0.08, 0.075);
		col = mix(fire * (1.5 + heat * 2.5), soot, smoothstep(0.35, 0.85, age));
		a = body * (1.0 - smoothstep(0.7, 1.0, age));
	} else if (kind == 1) {
		// duman: kabaran gri bulut, alt tarafı koyu, kenarı yumuşak ve düzensiz
		float n = fbm(q * 1.8 + seed * 11.0 + vec2(age * 0.6, -age * 0.9));
		float edge = 0.6 + 0.3 * n;
		float body = 1.0 - smoothstep(edge - 0.35, edge, r);
		float shade = 0.55 + 0.45 * clamp(-q.y * 0.6 + n, 0.0, 1.0);
		col = tint.rgb * shade;
		a = body * tint.a * smoothstep(0.0, 0.12, age) * (1.0 - smoothstep(0.55, 1.0, age));
	} else if (kind == 2) {
		// namlu alevi: iki yana açılan kısa alev dili + parlak çekirdek (yıldız değil)
		float ang = atan(q.y, q.x) + seed * 3.14;
		float lobe = pow(abs(cos(ang)), 10.0);
		float core = 1.0 - smoothstep(0.0, 0.28, r);
		float tongue = (1.0 - smoothstep(0.0, 0.25 + lobe * 0.7, r)) * (0.35 + lobe);
		float body = max(core, tongue);
		col = mix(vec3(1.0, 0.42, 0.08), vec3(1.0, 0.86, 0.45), core) * 2.2;
		a = clamp(body, 0.0, 1.0) * (1.0 - age);
	} else if (kind == 3) {
		// toprak / moloz: koyu kahve topaklar
		float n = fbm(q * 3.0 + seed * 23.0);
		float body = 1.0 - smoothstep(0.45 + n * 0.3, 0.8 + n * 0.2, r);
		col = mix(vec3(0.16, 0.12, 0.08), vec3(0.32, 0.26, 0.18), n) * tint.rgb;
		a = body * (1.0 - smoothstep(0.6, 1.0, age));
	} else {
		// kıvılcım
		float body = 1.0 - smoothstep(0.0, 0.6, r);
		col = vec3(1.0, 0.7, 0.3) * 5.0;
		a = body * (1.0 - age);
	}
	ALBEDO = col * intensity;
	ALPHA = clamp(a, 0.0, 1.0);
}
