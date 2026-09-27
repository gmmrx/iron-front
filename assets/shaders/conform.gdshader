// Harita üzerindeki modeller (şehir, liman...): her vertex kendi altındaki arazi yüksekliğine göre kaydırılır.
// Yapılar dik kalır, tabanları yamacı takip eder; gölge geçişi de aynı vertex kodunu kullanır.
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_texture = false;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_normal = false;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float roughness = 0.8;
uniform float metallic = 0.0;
uniform sampler2D height_tex : filter_linear, repeat_disable;
uniform vec2 map_size = vec2(5120.0, 4348.0);
uniform float height_scale = 0.012;
uniform float lift = 0.3;
uniform sampler2D coast_tex : filter_linear, repeat_disable;   // borders.png (B = işaretli kıyı mesafesi)
uniform bool clip_water = false;   // şehirler: su üstüne taşan kısımları kırp (limanlar hariç)
// şehir zemini (bahçe, kaldırım, sokak): taban elipsinin kenarı gürültüyle dağılır, şehir araziye kaynaşır
uniform bool fade_edge = false;
uniform vec2 fade_extent = vec2(1.0);

varying vec3 world_pos;   // arazi mesh'i yükseklik haritasından seyrek; tabanın gömülmemesi için pay
varying vec2 local_xz;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

float ground(vec2 xz) {
	return textureLod(height_tex, xz / map_size, 0.0).r * height_scale;
}

void vertex() {
	local_xz = VERTEX.xz;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 origin = MODEL_MATRIX[3].xyz;
	float s = max(length(MODEL_MATRIX[1].xyz), 1e-4);
	// hedef: bu noktanın altındaki zemin (deniz seviyesinin altına asla inmez) + modelin yerel yüksekliği.
	// Kaydırma, örneğin gerçek yerleşim yüksekliğine (origin.y) göre yapılır: kıyıdaki limanda
	// denize uzanan rıhtım/gemi su seviyesinde kalır, karadaki ambarlar zemine oturur.
	float target = max(ground(wp.xz), 0.0) + lift;
	VERTEX.y += (target - origin.y) / s;
	world_pos = wp;
}

void fragment() {
	if (clip_water) {
		float sd = (texture(coast_tex, world_pos.xz / map_size).b * 255.0 - 128.0) / 8.0;
		if (sd < -0.4) {
			discard;
		}
	}
	vec3 c = albedo_color.rgb;
	if (has_texture) {
		c *= texture(albedo_tex, UV).rgb;
	}
	if (fade_edge) {
		float d = length(local_xz / fade_extent);
		float n = vnoise(world_pos.xz * 0.55) * 0.65 + vnoise(world_pos.xz * 2.1) * 0.35;
		if (d > 0.72 && n < smoothstep(0.72, 1.02, d)) {
			discard;
		}
		c *= mix(1.0, 0.86, smoothstep(0.6, 0.95, d));
	}
	ALBEDO = c;
	if (has_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
		NORMAL_MAP_DEPTH = 1.2;
	}
	ROUGHNESS = roughness;
	METALLIC = metallic;
}
