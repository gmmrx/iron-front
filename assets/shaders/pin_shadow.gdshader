shader_type spatial;
// İğnenin haritaya battığı yerde yumuşak gölge noktası (yere yatık kare, ortası koyu). Ekranda sabit boy:
// INSTANCE_CUSTOM.y = yarıçap / kamera uzaklığı (canlandırmayla büyür, 0 = yok).
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform float cam_dist = 300.0;
uniform bool srgb_out = false;       // Compatibility (web) renderer: çıkış sRGB, koddan açılır

void vertex() {
	float r = INSTANCE_CUSTOM.y * cam_dist;
	VERTEX.xz *= r * 2.0;
	VERTEX.y += 0.02 * cam_dist * 0.01;
}

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float a = (1.0 - smoothstep(0.1, 1.0, d)) * 0.55;
	ALBEDO = vec3(0.02, 0.03, 0.02);
	ALPHA = a;
}
