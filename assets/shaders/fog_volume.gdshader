// Back-face volume: works above, inside and below, including WebGL2 Compatibility.
shader_type spatial;
render_mode unshaded, blend_mix, cull_front, depth_draw_never, depth_test_disabled, shadows_disabled;

uniform sampler3D noise_tex : filter_linear, repeat_enable;
#include "res://assets/shaders/fog_density.gdshaderinc"

uniform sampler2D mask_tex : filter_linear, repeat_disable;
uniform vec2 map_size = vec2(5120.0, 4348.0);
uniform bool wrap_x = false;
uniform float y0 = 70.0;
uniform float y1 = 240.0;
uniform int steps = 28;
uniform bool srgb_out = false;
uniform float fade = 1.0;          // bulutun girişi (oyun başında yavaşça belirir); 1 = olağan görünüm
varying vec3 wpos;

void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

float mask_at(vec2 xz) {
    vec2 uv = xz / map_size;
    if (wrap_x) { uv.x = fract(uv.x); }
    if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) { return 0.0; }
    return texture(mask_tex, uv).r;
}

void fragment() {
    vec3 ro = CAMERA_POSITION_WORLD;
    vec3 rd = normalize(wpos - ro);
    float ry = abs(rd.y) < 0.0001 ? (rd.y < 0.0 ? -0.0001 : 0.0001) : rd.y;
    float ta = (y0 - ro.y) / ry;
    float tb = (y1 - ro.y) / ry;
    float tn = max(min(ta, tb), 0.0);
    float tf = min(max(ta, tb), distance(wpos, ro));
    if (tf <= tn) { discard; }
    float len = min(tf - tn, 1600.0);
    // Keep close/interior quality; distant, steep rays need fewer samples.
    // Long grazing rays retain the original budget to avoid visible slices.
    int samples = int(ceil(mix(float(steps), 12.0, smoothstep(700.0, 2800.0, tn))));
    samples = min(steps, max(samples, int(ceil(len / 24.0))));
    float dt = len / float(samples);
    float detail = 1.0 - smoothstep(2500.0, 14000.0, tn);
    float t = tn + dt * 0.5;
    float tr = 1.0;
    vec3 col = vec3(0.0);
    for (int i = 0; i < steps; i++) {
        if (i >= samples) { break; }
        vec3 p = ro + rd * t;
        float m = mask_at(p.xz);
        if (m > 0.01) {
            float d = fog_density(p, m, TIME, detail, y0, y1);
            if (d > 0.0001) {
                float shadow = fog_density(p + vec3(-22.0, 38.0, 16.0), m, TIME, detail, y0, y1);
                vec3 c = fog_light(shadow, clamp((p.y - y0) / (y1 - y0), 0.0, 1.0));
                float a = 1.0 - exp(-d * dt * smoothstep(0.5, 12.0, t));
                col += tr * a * c;
                tr *= 1.0 - a;
                if (tr < 0.015) { break; }
            }
        }
        t += dt;
    }
    float alpha = 1.0 - tr;
    if (alpha < 0.003) { discard; }
    vec3 o = col / max(alpha, 0.001);
    ALBEDO = srgb_out ? o : pow(o, vec3(2.2));
    ALPHA = min(alpha, 0.62) * fade;
}
