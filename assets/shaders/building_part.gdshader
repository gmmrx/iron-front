// Tesislerin hareketli parçaları (vinç kolu, uçaksavar topu, meşale alevi): bina shader'ı + GPU'da "rig".
// Parçanın mesh orijini pivottur; dönüş/titreşim model uzayında uygulanır, örnek (instance) dönüşümü sonra gelir.
// Her örneğin evresi dünyadaki konumundan türetilir: aynı türden tesisler birlikte değil, kendi ritmiyle oynar.
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_texture = false;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_normal = false;
uniform float roughness = 0.8;
uniform float metallic = 0.0;
uniform vec3 emission = vec3(0.0);
uniform int mode = 0;          // 0 durağan, 1 sallanma (yaw), 2 dönme (yaw), 3 alev titremesi
uniform float speed = 0.3;
uniform float amp = 0.9;

varying float local_y;

mat2 rot2(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat2(vec2(c, -s), vec2(s, c));
}

void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	float ph = fract(sin(dot(o.xz, vec2(12.9898, 78.233))) * 43758.5453) * 6.2831853;
	if (mode == 1 || mode == 2) {
		// sallanma: iki frekansın toplamı (vinç yük alıp bırakıyor gibi düzensiz), dönme: sabit hız
		float a = mode == 1 ? (sin(TIME * speed + ph) * 0.75 + sin(TIME * speed * 0.37 + ph * 1.7) * 0.25) * amp
			: TIME * speed + ph;
		mat2 r = rot2(a);
		VERTEX.xz = r * VERTEX.xz;
		NORMAL.xz = r * NORMAL.xz;
	} else if (mode == 3) {
		float f = 1.0 + 0.22 * sin(TIME * 9.0 + ph) + 0.12 * sin(TIME * 23.0 + ph * 2.0);
		VERTEX.y *= f;
		VERTEX.xz *= 1.0 + 0.1 * sin(TIME * 13.0 + ph);
	}
	local_y = VERTEX.y;
}

void fragment() {
	vec3 c = albedo_color.rgb;
	if (has_texture) {
		c *= texture(albedo_tex, UV).rgb;
	}
	ALBEDO = c;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	SPECULAR = 0.28;
	EMISSION = emission;
	if (has_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
		NORMAL_MAP_DEPTH = 0.72;
	}
}
