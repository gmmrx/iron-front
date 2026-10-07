shader_type canvas_item;
render_mode unshaded;

// The source is always the country's real flag. Only static material lighting
// is added: no emblem replacement, waving geometry or time-dependent work.
uniform sampler2D cloth : source_color, filter_linear_mipmap, repeat_disable;

void fragment() {
	vec4 flag = texture(TEXTURE, UV);
	float light = texture(cloth, UV).r;
	float luminance = dot(flag.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 dyed = mix(vec3(luminance), flag.rgb, 0.94);
	vec3 fabric = dyed * mix(0.67, 1.05, light);
	COLOR *= vec4(fabric, flag.a);
}
