// Shared by Godot and the Three.js client. Small soft billows, no texture/noise
// lookup, ray-march loop or discovery mask. p is a patch's local -1..1 plane.
float ambient_lobe(vec2 p, vec2 center, vec2 radius) {
	vec2 q = (p - center) / radius;
	float d = max(1.0 - dot(q, q), 0.0);
	return d * d;
}

float ambient_body(vec2 p, float seed) {
	float s = seed * 2.0 - 1.0;
	return ambient_lobe(p, vec2(-0.37, 0.06 + s * 0.12), vec2(0.51, 0.40)) * 0.74
		+ ambient_lobe(p, vec2(-0.03 + s * 0.08, -0.12), vec2(0.54, 0.54))
		+ ambient_lobe(p, vec2(0.38, 0.04 - s * 0.13), vec2(0.47, 0.38 + seed * 0.12)) * 0.75
		+ ambient_lobe(p, vec2(0.08, 0.32), vec2(0.50 - seed * 0.08, 0.34)) * 0.52
		+ ambient_lobe(p, vec2(-0.15 - s * 0.11, -0.43), vec2(0.33, 0.27)) * 0.37;
}

vec4 ambient_cloud(vec2 p, float seed) {
	float density = ambient_body(p, seed);
	float edge = smoothstep(0.004, 0.16, density);
	float alpha = (1.0 - exp(-density * 1.45)) * edge;
	float slope_light = ambient_body(p + vec2(-0.075, -0.055), seed) - density;
	float light = clamp(0.66 + slope_light * 1.8 + density * 0.18, 0.0, 1.0);
	return vec4(mix(vec3(0.66, 0.73, 0.76), vec3(0.96, 0.965, 0.95), light), alpha);
}
