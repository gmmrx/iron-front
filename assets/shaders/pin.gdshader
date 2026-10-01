// İğne haritası: haritaya saplanmış iğneler (gövde + baş). Ekranda sabit boy: boyutlar kamera uzaklığının katı.
// Örnek dönüşümü yalnız konum (iğnenin yere değdiği nokta). INSTANCE_CUSTOM: x = boy katı, y = yarıçap katı (gövde ya da
// baş), z = bu uzaklıktan sonra gizli (içeri doğru yerden yükselir; uzakta harita ikonu görünür), w = baş rengi (sRGB, r*65536 + g*256 + b; tam sayı olarak paketli). Web'de baş
// rengi örnek renginden (COLOR) okunur.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx, shadows_disabled;   // kendi gölgesini almaz (ince gövdede gölge tırtığı olmasın); gölge düşürür

uniform float cam_dist = 300.0;
uniform bool head = false;        // false: gövde (iğne), true: baş (küre)
uniform bool srgb_out = false;    // Compatibility (web) renderer: çıkış sRGB, koddan açılır

varying vec3 tint;
varying float along;              // gövdede yerden uca 0..1
void vertex() {
	float d = cam_dist;
	float len = INSTANCE_CUSTOM.x * d;
	float packed = INSTANCE_CUSTOM.w;
	float cr = floor(packed / 65536.0);
	float cg = floor((packed - cr * 65536.0) / 256.0);
	float cb = packed - cr * 65536.0 - cg * 256.0;
	tint = pow(vec3(cr, cg, cb) / 255.0, vec3(2.2));      // sRGB -> lineer
	// uzakta harita ikonu, yaklaşınca iğne: ikonun söndüğü uzaklıktan içeri iğne yerden yükselir
	float grow = 1.0 - smoothstep(INSTANCE_CUSTOM.z * 0.8, INSTANCE_CUSTOM.z, d);
	len *= grow;
	if (grow <= 0.001) {
		VERTEX = vec3(0.0);
	} else if (head) {
		float r = INSTANCE_CUSTOM.y * d * grow;
		VERTEX = VERTEX * r + vec3(0.0, len + r * 0.55, 0.0);
	} else {
		float r = INSTANCE_CUSTOM.y * d;
		// gövde: alt uç sivri (yere batan), üst kalın
		float t = VERTEX.y + 0.5;
		along = t;
		VERTEX.xz *= r * mix(0.25, 1.0, t);
		VERTEX.y = t * len;
	}
}

void fragment() {
	// Compatibility (web): örnek verisi yarım duyarlıkta taşındığından paketli renk bozulur; orada örnek rengi (COLOR,
	// sRGB) kullanılır. Forward+ (masaüstü) paketli rengi kullanır.
	vec3 c;
	if (head) {
		// iğne başı: mat, eskimiş (parlaklık yok)
		c = srgb_out ? pow(COLOR.rgb, vec3(2.2)) : tint;
		c *= 0.82;
	} else {
		// dövme demir gövde: koyu kurşuni, mat; boyunca hafif pas ve dövme izi (uca doğru daha koyu)
		float n = fract(sin(dot(vec2(floor(along * 40.0), floor(atan(NORMAL.z, NORMAL.x) * 3.0)), vec2(12.9898, 78.233))) * 43758.5453);
		vec3 iron = vec3(0.085, 0.082, 0.078);
		vec3 rust = vec3(0.16, 0.085, 0.045);
		c = mix(iron, rust, smoothstep(0.55, 0.95, n) * 0.55);
		c *= mix(0.65, 1.0, smoothstep(0.0, 0.5, along));
	}
	ALBEDO = c;
	if (srgb_out) { ALBEDO = pow(max(ALBEDO, vec3(0.0)), vec3(1.0 / 2.2)); }
	// mat demir: ekran uzayı yansıması yok (METALLIC 0), geniş ve sönük parlama
	METALLIC = 0.0;
	ROUGHNESS = head ? 0.78 : 0.72;
	SPECULAR = head ? 0.25 : 0.35;
}
