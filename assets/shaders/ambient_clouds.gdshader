shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
#include "res://assets/shaders/ambient_clouds.gdshaderinc"
uniform bool srgb_out = false;
uniform float cloud_amount = 0.0;
// gece (DayNight; map3d ile aynı hesap): dünya x/z = harita pikseli, Miller enlemi
uniform vec2 sun_lonlat = vec2(0.0, 0.0);
uniform float night_strength = 0.0;
uniform vec3 night_tint = vec3(0.42, 0.48, 0.66);
uniform vec2 map_size = vec2(1.0, 1.0);
uniform float proj_lon_min = 0.0;
uniform float proj_y_top = 0.0;
uniform float proj_px_per_rad = 1.0;
varying vec4 patch;
varying vec3 cloud_position;

void vertex() {
	patch = INSTANCE_CUSTOM;
	// Slow, bounded wind: layout is generated once, not rebuilt or moved on CPU.
	cloud_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	cloud_position.x += sin(TIME * 0.015 + patch.y * 6.28) * 10.0;
	cloud_position.z += cos(TIME * 0.011 + patch.x * 6.28) * 5.0;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(cloud_position, 1.0);
}

void fragment() {
	// Fly below/through the cloud without opaque cards near the camera.
	float height_fade = smoothstep(5.0, 90.0, CAMERA_POSITION_WORLD.y - cloud_position.y);
	if (height_fade < 0.003 || cloud_amount < 0.003) { discard; }
	vec4 cloud = ambient_cloud(UV * 2.0 - 1.0, patch.x);
	float alpha = cloud.a * (0.20 + patch.z * 0.10) * cloud_amount * height_fade;
	if (alpha < 0.003) { discard; }
	vec3 c = cloud.rgb;
	if (night_strength > 0.001) {
		float la = 2.5 * atan(exp(0.8 * (proj_y_top - cloud_position.z / proj_px_per_rad))) - 0.625 * PI;
		float lo = radians(proj_lon_min + cloud_position.x / map_size.x * 360.0);
		vec2 s = radians(sun_lonlat);
		float h = sin(la) * sin(s.y) + cos(la) * cos(s.y) * cos(lo - s.x);
		c *= mix(vec3(1.0), night_tint * 0.85, (1.0 - smoothstep(-0.10, 0.06, h)) * night_strength);
	}
	ALBEDO = srgb_out ? c : pow(c, vec3(2.2));
	ALPHA = alpha;
}
