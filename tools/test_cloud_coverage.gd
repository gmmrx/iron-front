extends SceneTree
## GPU regression: even a completely empty noise field must veil unexplored ground, never explored ground.
func _init() -> void:
	await process_frame
	DisplayServer.window_set_size(Vector2i(256, 256))
	root.content_scale_size = Vector2i(256, 256)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.15, 0.15, 0.15)
	root.add_child(environment)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(256, 600, 256)
	camera.look_at(Vector3(256, 0, 256), Vector3.FORWARD)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 400
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/fog_volume.gdshader")
	mat.set_shader_parameter("map_size", Vector2(512, 512))
	mat.set_shader_parameter("srgb_out", RenderingServer.get_current_rendering_method() == "gl_compatibility")
	var blank := Image.create(4, 4, false, Image.FORMAT_R8)
	blank.fill(Color.BLACK)
	var noise := ImageTexture3D.new()
	var slices: Array[Image] = [blank, blank, blank, blank]
	noise.create(Image.FORMAT_R8, 4, 4, 4, false, slices)
	mat.set_shader_parameter("noise_tex", noise)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(512, 170, 512)
	mesh.mesh = box
	mesh.position = Vector3(256, 155, 256)
	mesh.material_override = mat
	root.add_child(mesh)
	var samples: Array[float] = []
	# Hidden volume baseline, explored, unexplored — exact same zero-noise field.
	for state in [-1, 0, 1]:
		mesh.visible = state >= 0
		var mask := Image.create(4, 4, false, Image.FORMAT_R8)
		mask.fill(Color.WHITE if state == 1 else Color.BLACK)
		mat.set_shader_parameter("mask_tex", ImageTexture.create_from_image(mask))
		for frame in 5:
			await process_frame
		await RenderingServer.frame_post_draw
		samples.append(root.get_texture().get_image().get_pixel(128, 128).r)
	var clear_ok := absf(samples[1] - samples[0]) < 0.01
	var veil_ok := samples[2] - samples[0] > 0.025
	print("CLOUD_COVERAGE ", RenderingServer.get_current_rendering_method(), " baseline/explored/unexplored=", samples,
		" explored_clear=", clear_ok, " empty_noise_still_veiled=", veil_ok)
	mesh.queue_free()
	camera.queue_free()
	environment.queue_free()
	await process_frame
	quit(0 if clear_ok and veil_ok else 1)
