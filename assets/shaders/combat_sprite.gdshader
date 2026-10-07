shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D explosion_atlas : filter_linear_mipmap, repeat_disable;
uniform sampler2D smoke_atlas : filter_linear_mipmap, repeat_disable;
uniform sampler2D water_atlas : filter_linear_mipmap, repeat_disable;
uniform bool srgb_out = false;
varying vec4 effect;
varying float world_height;

void vertex() {
	effect = INSTANCE_CUSTOM;
	world_height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

vec4 frame_sample(sampler2D atlas, float frame, float grid, vec2 uv) {
	vec2 cell = vec2(mod(frame, grid), floor(frame / grid));
	// Transparent gutters stay inside this frame, including mip/linear filtering.
	return texture(atlas, (cell + mix(vec2(0.012), vec2(0.988), uv)) / grid);
}

void fragment() {
	vec4 tex;
	if (effect.z < 0.5) {
		float frame = clamp(effect.x, 0.0, 15.0);
		tex = mix(frame_sample(explosion_atlas, floor(frame), 4.0, UV),
			frame_sample(explosion_atlas, min(floor(frame) + 1.0, 15.0), 4.0, UV), fract(frame));
	} else if (effect.z > 2.5) {
		float frame = clamp(effect.x, 0.0, 15.0);
		tex = mix(frame_sample(water_atlas, floor(frame), 4.0, UV),
			frame_sample(water_atlas, min(floor(frame) + 1.0, 15.0), 4.0, UV), fract(frame));
		// Neutral foam; the renderer supplies the gentle cool tint, not a baked sea colour.
		tex.rgb = vec3(dot(tex.rgb, vec3(0.2126, 0.7152, 0.0722)));
	} else {
		tex = frame_sample(smoke_atlas, floor(effect.x), 2.0, UV);
	}
	float alpha = tex.a * COLOR.a * smoothstep(-0.03, 0.45, world_height - effect.w);
	if (alpha < 0.004) { discard; }
	vec3 rgb = tex.rgb * COLOR.rgb;
	ALBEDO = srgb_out ? rgb : pow(max(rgb, vec3(0.0)), vec3(2.2));
	ALPHA = alpha;
}
