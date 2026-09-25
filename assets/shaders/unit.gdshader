// Birim figürleri (MultiMesh). Modeller: Muster (MIT) + Blender gemileri/uçakları.
// COLOR.rgb = malzeme rengi (gölgeli), COLOR.a = ülke rengi maskesi (üniforma kumaşı / gövde boyası).
// UV.x = parça kimliği: 0 gövde, 1 sol bacak, 2 sağ bacak, 3 kollar/silah, 4 pervane, 5 namlu.
// INSTANCE_CUSTOM.rgb = ülke rengi (sRGB). INSTANCE_CUSTOM.a = 1000*ülkeye_özgü + durum:
//   0 bekleme · 100..199 yürüyüş (100 + adım fazı*99, CPU gerçek hıza göre ilerletir) · 200 ateş
shader_type spatial;
render_mode cull_back, diffuse_lambert;

const float HIP = 0.86;   // kalça yüksekliği (model metre)

varying vec3 tint;
varying float mask;

void vertex() {
	float a = INSTANCE_CUSTOM.a;
	float native = step(999.0, a);
	a -= native * 1000.0;
	float walk = step(99.5, a) * (1.0 - step(199.5, a));
	float fire = step(199.5, a);
	float ph = clamp((a - 100.0) / 99.0, 0.0, 1.0) * 6.2831853;
	tint = pow(INSTANCE_CUSTOM.rgb, vec3(2.2));   // sRGB -> lineer
	mask = COLOR.a * (1.0 - native);
	float part = floor(UV.x);
	float seed = MODEL_MATRIX[3].x * 0.37 + MODEL_MATRIX[3].z * 0.23;
	// bacaklar kalçadan X ekseni etrafında salınır (ileri = +Z); adım fazı hızla eşli
	if (part == 1.0 || part == 2.0) {
		float s = sin(ph + (part == 1.0 ? 0.0 : 3.14159));
		float sw = s * 0.42 * walk;
		float dy = VERTEX.y - HIP;
		float dz = VERTEX.z;
		// arka bacak dizden hafif bükülür (yerden kalkma)
		float lift = max(-s, 0.0) * 0.06 * walk * smoothstep(HIP, 0.0, VERTEX.y);
		VERTEX.y = HIP + dy * cos(sw) - dz * sin(sw) + lift;
		VERTEX.z = dy * sin(sw) + dz * cos(sw);
	}
	if (part == 3.0) {
		VERTEX.z -= pow(1.0 - fract(TIME * 1.3 + seed), 8.0) * 0.05 * fire;
	}
	if (part == 4.0) {
		float r = TIME * 40.0;
		vec2 xy = VERTEX.xy;
		VERTEX.x = xy.x * cos(r) - xy.y * sin(r);
		VERTEX.y = xy.x * sin(r) + xy.y * cos(r);
	}
	if (part == 5.0) {
		VERTEX.z -= pow(1.0 - fract(TIME * 0.6 + seed), 6.0) * 0.25 * fire;
	}
	// yürüyüş: her adımda gövde sekmesi ve yana hafif salınım
	float up_h = smoothstep(0.3, 1.2, VERTEX.y);
	VERTEX.y += abs(cos(ph)) * 0.035 * walk;
	VERTEX.x += sin(ph) * 0.018 * walk * up_h;
	// ateşte: diz çökmüş gibi hafif alçalma ve öne eğilme
	VERTEX.z += up_h * 0.05 * fire;
}

void fragment() {
	vec3 base = COLOR.rgb;
	float l = dot(base, vec3(0.299, 0.587, 0.114));
	vec3 painted = tint * clamp(l / 0.16, 0.35, 1.6);
	ALBEDO = mix(base, painted, mask);
	ROUGHNESS = mix(0.72, 0.9, mask);
	SPECULAR = 0.25;
}
