// İğne haritası: haritaya saplanmış iğneler (gövde + baş). Ekranda sabit boy: boyutlar kamera uzaklığının katı.
// Örnek dönüşümü yalnız konum (iğnenin yere değdiği nokta). INSTANCE_CUSTOM: x = boy katı, y = yarıçap katı (gövde ya da
// baş), z = bu uzaklıktan sonra gizli (içeri doğru yerden yükselir; uzakta harita ikonu görünür), w = baş rengi (sRGB, r*65536 + g*256 + b; tam sayı olarak paketli). Web'de baş
// rengi örnek renginden (COLOR) okunur.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform float cam_dist = 300.0;
uniform bool head = false;        // false: gövde (iğne), true: baş (küre)
uniform bool srgb_out = false;    // Compatibility (web) renderer: çıkış sRGB, koddan açılır

varying vec3 tint;

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
		VERTEX.xz *= r * mix(0.25, 1.0, t);
		VERTEX.y = t * len;
	}
}

void fragment() {
	// Compatibility (web): örnek verisi yarım duyarlıkta taşındığından paketli renk bozulur; orada örnek rengi (COLOR,
	// sRGB) kullanılır. Forward+ (masaüstü) paketli rengi kullanır.
	vec3 c = head ? (srgb_out ? pow(COLOR.rgb, vec3(2.2)) : tint) : vec3(0.78, 0.8, 0.82);
	ALBEDO = c;
	if (srgb_out) { ALBEDO = pow(max(ALBEDO, vec3(0.0)), vec3(1.0 / 2.2)); }
	METALLIC = head ? 0.0 : 0.85;
	ROUGHNESS = head ? 0.32 : 0.28;
	SPECULAR = 0.6;
}
