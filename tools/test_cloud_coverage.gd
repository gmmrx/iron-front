extends SceneTree
## GPU regression: discovery mask + the actual map tint, without any 3D cloud volume.
## Run using Forward+ and --rendering-method gl_compatibility (not headless Dummy).
func _init() -> void:
	await process_frame
	DisplayServer.window_set_size(Vector2i(256, 256))
	root.content_scale_size = Vector2i(256, 256)
	var source := FileAccess.get_file_as_string("res://assets/shaders/map3d.gdshader")
	var pattern := RegEx.new()
	pattern.compile("(?s)// Only a subtle unexplored tint[^\\n]*\\n\\s*if \\(fog_enabled\\) \\{.*?\\n\\s*\\}")
	var tint := pattern.search(source)
	if tint == null:
		push_error("Actual map discovery tint block was not found")
		quit(1)
		return
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.15, 0.15, 0.15)
	root.add_child(environment)
	var camera := Camera3D.new()
	camera.far = 10000.0
	root.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 400
	var provinces := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	provinces.fill(Color(1.0 / 255.0, 0.0, 0.0, 0.0)) # province id 1, native LA8-compatible encoding
	var fog := CloudFog.new()
	root.add_child(fog)
	fog.setup(ImageTexture.create_from_image(provinces), Vector2(512, 512), false)
	var volume_absent := fog.find_children("*", "MeshInstance3D", true, false).is_empty()
	var shader := Shader.new()
	# Extract the live discovery branch, so a stale test-only tint cannot hide a regression.
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D fog_mask : filter_linear, repeat_disable;
uniform bool fog_enabled = true;
uniform float fog_fade = 1.0;
uniform bool srgb_out = false;
varying vec2 world_uv;
void vertex() { world_uv = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz / vec2(512.0); }
void fragment() {
	vec2 uv = world_uv;
	vec3 col = vec3(0.15);
	%s
	ALBEDO = srgb_out ? col : pow(col, vec3(2.2));
}
""" % tint.get_string()
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("fog_mask", fog.mask_texture())
	mat.set_shader_parameter("srgb_out", RenderingServer.get_current_rendering_method() == "gl_compatibility")
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(512, 512)
	mesh.mesh = plane
	mesh.position = Vector3(256, 0, 256)
	mesh.material_override = mat
	root.add_child(mesh)
	var passed := volume_absent
	# Near/below former cloud altitude and far views: only the flat map carries the cue.
	for height: float in [600.0, 4400.0, 160.0, 55.0]:
		camera.position = Vector3(256, height, 256)
		camera.look_at(Vector3(256, 0, 256), Vector3.FORWARD)
		var samples: Array[float] = []
		# Disabled baseline, explored, unexplored, unknown with fade=0.
		for state in [-1, 0, 1, 2]:
			var levels := Image.create(256, 1, false, Image.FORMAT_R8)
			levels.fill(Color.WHITE if state == 0 else Color.BLACK)
			fog.set_fog(ImageTexture.create_from_image(levels))
			mat.set_shader_parameter("fog_enabled", state >= 0)
			mat.set_shader_parameter("fog_fade", 0.0 if state == 2 else 1.0)
			for frame in 5:
				await process_frame
			await RenderingServer.frame_post_draw
			samples.append(root.get_texture().get_image().get_pixel(128, 128).r)
		var clear_ok := absf(samples[1] - samples[0]) < 0.01
		var cue_ok := samples[2] - samples[0] > 0.02
		var fade_ok := absf(samples[3] - samples[0]) < 0.01
		passed = passed and clear_ok and cue_ok and fade_ok
		print("FOG_MASK_COVERAGE ", RenderingServer.get_current_rendering_method(), " height=", height,
			" baseline/explored/unexplored/faded=", samples, " explored_clear=", clear_ok,
			" unexplored_tinted=", cue_ok, " fade_zero_clear=", fade_ok, " volume_absent=", volume_absent)
	mesh.queue_free()
	fog.queue_free()
	camera.queue_free()
	environment.queue_free()
	await process_frame
	quit(0 if passed else 1)
