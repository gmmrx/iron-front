// Binalar: içe aktarılan doku/normal + dipte ortam gölgesi (binanın zeminle birleştiği yer kararır).
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_texture = false;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_normal = false;
uniform float roughness = 0.8;
uniform float metallic = 0.0;

varying float local_y;

void vertex() {
	local_y = VERTEX.y;
}

void fragment() {
	vec3 c = albedo_color.rgb;
	if (has_texture) {
		c *= texture(albedo_tex, UV).rgb;
	}
	float ao = mix(0.58, 1.0, smoothstep(-0.02, 0.10, local_y));
	// Zemine gömülen temeli doğal biçimde koyulaştır; renkleri plastik gibi
	// ezmemek için geri kalan gölgeyi motorun AO kanalına bırak.
	ALBEDO = c * mix(0.82, 1.0, ao);
	AO = ao;
	AO_LIGHT_AFFECT = 0.72;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	SPECULAR = 0.28;
	if (has_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
		NORMAL_MAP_DEPTH = 0.72;
	}
}
