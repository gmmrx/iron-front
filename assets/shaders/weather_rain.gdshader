shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 wind_velocity = vec3(26.0, -8.0, 7.0);
uniform vec3 field_size = vec3(150.0, 56.0, 150.0);
uniform float rain_time = 0.0;
uniform float streak_width = 0.055;
uniform float rain_opacity = 0.30;
uniform bool srgb_out = false;
varying float drop_opacity;

void vertex() {
	// One fixed instanced pool; seed phases wrap inside the camera-local volume.
	// The CPU clock freezes during pause and is never multiplied by strategy speed.
	vec4 seed = INSTANCE_CUSTOM;
	float speed = mix(0.78, 1.18, seed.a);
	vec3 cell = fract(seed.rgb + wind_velocity * rain_time * speed / field_size);
	vec3 local = (cell - 0.5) * field_size;
	vec3 center = MODEL_MATRIX[3].xyz + local;
	vec3 along = normalize(wind_velocity);
	vec3 side = cross(along, CAMERA_POSITION_WORLD - center);
	if (dot(side, side) < 0.001) { side = INV_VIEW_MATRIX[0].xyz; }
	side = normalize(side);
	float length = mix(0.85, 1.85, seed.a);
	vec3 world = center + side * VERTEX.x * streak_width + along * VERTEX.y * length;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
	vec3 edge = smoothstep(vec3(0.0), vec3(0.07), min(cell, 1.0 - cell));
	drop_opacity = min(edge.x, min(edge.y, edge.z)) * mix(0.62, 1.0, seed.a);
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float thin = 1.0 - smoothstep(0.18, 1.0, abs(q.x));
	float tip = 1.0 - smoothstep(0.52, 1.0, abs(q.y));
	float alpha = thin * tip * drop_opacity * rain_opacity;
	if (alpha < 0.004) { discard; }
	vec3 col = vec3(0.67, 0.77, 0.86);
	ALBEDO = srgb_out ? col : pow(col, vec3(2.2));
	ALPHA = alpha;
}
