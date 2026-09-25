shader_type spatial;
// Rota şeridi: genişlik ekranda sabit kalsın diye tepe noktasında açılır (UV2 = yan yön, UV.x = ±genişlik katsayısı,
// UV.y = yay uzunluğu). Akış: ithalatçıya doğru ilerleyen parlak dalgalar; kesikli: planlanan hareket.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform float width = 2.0;          // dünya birimi (kamera uzaklığıyla güncellenir)
uniform float flow_speed = 0.0;     // piksel / saniye; 0 = akış yok
uniform float flow_period = 40.0;
uniform float dash = 0.0;           // >0: kesik boyu (piksel)
uniform float opacity = 0.8;

varying float across;
varying float arc;
varying vec4 col;

void vertex() {
	float w = abs(UV.x);
	across = sign(UV.x);
	arc = UV.y;
	col = COLOR;
	VERTEX.xz += UV2 * UV.x * width;
	VERTEX.y += 0.4;
}

void fragment() {
	float edge = 1.0 - smoothstep(0.55, 1.0, abs(across));
	float core = 1.0 - smoothstep(0.0, 0.35, abs(across));
	vec3 c = pow(col.rgb, vec3(2.2));
	float a = edge * opacity * col.a;
	if (flow_speed > 0.0) {
		float ph = fract((arc - TIME * flow_speed) / flow_period);
		float pulse = smoothstep(0.0, 0.25, ph) * (1.0 - smoothstep(0.25, 0.55, ph));
		c = mix(c, vec3(1.0), pulse * 0.45 * core);
		a = max(a, pulse * edge * 0.95 * col.a);
	}
	if (dash > 0.0) {
		float d = fract((arc - TIME * 6.0) / dash);
		a *= step(d, 0.6);
	}
	ALBEDO = c;
	ALPHA = a;
}
