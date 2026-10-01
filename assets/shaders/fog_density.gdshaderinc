// Also imported by Three.js. Coordinates are original map pixels, not web's 1/8 scale.

float fog_field(vec3 p, float seconds, float detail) {
    vec3 q = p * 0.00072 + vec3(seconds * 0.00012, 0.0, seconds * 0.00005);
    // Domain warp + non-aligned frequencies: the small periodic volume never stamps a grid onto the map.
    // A much larger weather envelope groups small billows into unequal banks with quieter gaps.
    vec3 macro_q = vec3(q.x * 0.173 + q.z * 0.097, q.y * 0.23 + 0.31, q.z * 0.173 - q.x * 0.097);
    float macro = texture(noise_tex, macro_q).r;
    float warp = texture(noise_tex, macro_q * 1.731 + vec3(0.43, 0.13, 0.71)).r;
    vec3 warped = q + vec3(macro - 0.5, 0.0, warp - 0.5) * 0.65;
    float broad = texture(noise_tex, warped).r;
    vec3 rotated = vec3(warped.x * 0.8 + warped.z * 0.6, warped.y, warped.z * 0.8 - warped.x * 0.6);
    float billow = texture(noise_tex, rotated * 2.713 + vec3(0.17, 0.37, 0.53)).r;
    return macro * 0.30 + broad * 0.50 + mix(0.5, billow, detail) * 0.20;
}

float fog_density(vec3 p, float mask, float seconds, float detail, float bottom, float top) {
    float h = (p.y - bottom) / (top - bottom);
    float field = fog_field(p, seconds, detail);
    float crown = 0.20 + field * 1.05;
    float body = smoothstep(-0.10, 0.16, crown - h);
    float foot = smoothstep(0.0, 0.18, h);
    float edge = smoothstep(0.06, 0.8, mask + (field - 0.5) * 0.22);
    // A faint continuous veil marks ALL unexplored areas, even where the random field has no bank.
    // This uses only discovery + height, so sparse noise can never erase the discovery cue.
    float veil = smoothstep(0.0, 0.15, h) * (1.0 - smoothstep(0.65, 1.0, h));
    float veil_mask = smoothstep(0.03, 0.85, mask);
    // Stronger, irregular banks sit on the veil. Terrain stays readable; units are hidden separately.
    float pockets = smoothstep(0.49, 0.68, field);
    return veil * veil_mask * 0.0018 + body * foot * edge * pockets * 0.032;
}

vec3 fog_light(float shadow, float height) {
    float sun = exp(-shadow * 32.0);
    return mix(vec3(0.43, 0.51, 0.59), vec3(0.94, 0.955, 0.95),
        clamp(sun * 0.74 + height * 0.20, 0.0, 1.0));
}
