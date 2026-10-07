shader_type spatial;
// Yol ağı, UV.y yay uzunluğuna göre döşenen saydam dokuları bükülen şerit ağına uygular.
// UV.x şeridin kenarını, UV2 harita düzlemindeki teğeti taşır; ekran sabit genişlik eğik kamerada okunurluğu korur.
// Derinlik denetimi açık: dağın arkasında kalan yol görünmez. Zemine gömülmesin diye nokta bakış doğrultusunda kameraya
// biraz çekilir (ekrandaki yeri değişmez).
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform bool srgb_out = false;       // Compatibility (web) renderer: çıkış sRGB, koddan açılır
uniform float px_world = 0.1;        // bir ekran pikselinin haritadaki karşılığı
uniform float half_px = 1.6;         // yarım genişlik (ekran pikseli)
uniform int kind = 0;                // 0 ana yol, 1 tali yol, 2 demiryolu
uniform float fade = 1.0;            // uzaklaşınca söner
uniform float path_repeat = 0.02;    // yakınlık değiştikçe harita kodundan ekran boyu korunacak şekilde ayarlanır
uniform sampler2D path_tex : source_color, filter_linear_mipmap, repeat_enable;
// yükseklik haritanın kendi yükseklik dokusundan (MapView3D ile aynı): ağ kurulurken işlemci yükseklik hesaplamaz
uniform sampler2D height_tex : filter_linear, repeat_enable;
uniform vec2 map_size = vec2(16384.0, 8106.0);
uniform float height_scale = 0.0;
uniform float lift = 0.25;
uniform float mesh_step = 4.0;       // arazi ağının köşe aralığı (MapView3D.VERTEX_SPACING)

// Arazi ağı gibi yükseklik: bulunduğu ağ hücresinin dört köşesinden ara değer (ağ yüzeyi yolu vadide örtmesin),
// köşelerin en yükseğine doğru küçük pay
float mesh_height(vec2 xz) {
	if (height_scale == 0.0) { return 0.0; }
	vec2 c = floor(xz / mesh_step) * mesh_step;
	vec2 f = (xz - c) / mesh_step;
	float h00 = textureLod(height_tex, c / map_size, 0.0).r;
	float h10 = textureLod(height_tex, (c + vec2(mesh_step, 0.0)) / map_size, 0.0).r;
	float h01 = textureLod(height_tex, (c + vec2(0.0, mesh_step)) / map_size, 0.0).r;
	float h11 = textureLod(height_tex, (c + vec2(mesh_step)) / map_size, 0.0).r;
	float bil = mix(mix(h00, h10, f.x), mix(h01, h11, f.x), f.y);
	float top = max(max(h00, h10), max(h01, h11));
	return mix(bil, top, 0.25) * height_scale;
}

varying float across;
varying float arc;

void vertex() {
	across = UV.x;
	arc = UV.y;
	VERTEX.y = max(mesh_height(VERTEX.xz), 0.0) + lift;
	float miter = max(length(UV2), 1.0);
	vec3 t3 = vec3(UV2.x, 0.0, UV2.y) / miter;
	vec4 v0 = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec4 v1 = MODELVIEW_MATRIX * vec4(VERTEX + t3, 1.0);
	float pull = length(v0.xyz) * 0.006;
	v0.xyz -= normalize(v0.xyz) * pull;
	v1.xyz -= normalize(v1.xyz) * pull;
	vec4 c0 = PROJECTION_MATRIX * v0;
	vec4 c1 = PROJECTION_MATRIX * v1;
	vec2 half_vp = VIEWPORT_SIZE * 0.5;
	vec2 s0 = c0.xy / c0.w * half_vp;
	vec2 s1 = c1.xy / c1.w * half_vp;
	vec2 dir = s1 - s0;
	dir = length(dir) > 1e-5 ? normalize(dir) : vec2(1.0, 0.0);
	vec2 nrm = vec2(-dir.y, dir.x);
	c0.xy += nrm * UV.x * half_px * miter / half_vp * c0.w;
	POSITION = c0;
}

void fragment() {
	vec3 color;
	float alpha;
	if (kind == 2) {
		// Demiryolunda travers aralığı ekranda sabit kalsın; ray çifti ve travers yakınlaşınca da seçilsin.
		float core = clamp((1.45 - abs(across) * half_px) * 1.8, 0.0, 1.0);
		float ph = fract(arc / max(7.0 * px_world, 0.001));
		float tie = 1.0 - smoothstep(0.10, 0.18, min(ph, 1.0 - ph));
		color = mix(vec3(0.33, 0.29, 0.22), vec3(0.14, 0.14, 0.13), core);
		alpha = max(core, tie * 0.92);
	} else {
		vec2 road_uv = vec2(across * 0.5 + 0.5, arc * path_repeat);
		vec4 texel = texture(path_tex, road_uv);
		color = texel.rgb;
		alpha = texel.a;
	}
	ALBEDO = color;
	if (srgb_out) { ALBEDO = pow(max(ALBEDO, vec3(0.0)), vec3(1.0 / 2.2)); }
	ALPHA = alpha * fade;
}
