extends SceneTree

func _init() -> void:
	await process_frame
	DisplayServer.window_set_size(Vector2i(1100, 700))
	root.content_scale_size = Vector2i(1100, 700)
	var surface: Node3D = load("res://tools/arrow_relief_surface.gd").new()
	root.add_child(surface)
	var camera := Camera3D.new()
	camera.position = Vector3(250, 220, 380)
	surface.add_child(camera)
	camera.look_at(Vector3(250, 15, 95))
	var relief := ImmediateMesh.new()
	relief.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(0, 500, 4):
		for z in range(0, 220, 4):
			for p: Vector2 in [Vector2(x,z),Vector2(x+4,z),Vector2(x+4,z+4),Vector2(x,z),Vector2(x+4,z+4),Vector2(x,z+4)]:
				var height: float = surface.height_at(p)
				relief.surface_set_color(Color("354b36").lerp(Color("a09172"), height / 80.0))
				relief.surface_add_vertex(Vector3(p.x,height,p.y))
	relief.surface_end()
	var ground := MeshInstance3D.new()
	ground.mesh = relief
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	ground.material_override = material
	surface.add_child(ground)
	var layer: Node3D = load("res://game/map/unit_layer.gd").new()
	layer.map = surface
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var route: Array[Vector2] = []
	for i in 40:
		var t := float(i) / 39.0
		route.append(Vector2(45 + 410 * t, 110 + 30 * sin(t * PI)))
	layer._ribbon(mesh,route,Color("8b281c"),18)
	mesh.surface_end()
	var arrow := MeshInstance3D.new()
	arrow.mesh = mesh
	var ink := ShaderMaterial.new()
	ink.shader = load("res://assets/shaders/arrow.gdshader")
	ink.render_priority = 8
	arrow.material_override = ink
	surface.add_child(arrow)
	for frame in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://art/previews/arrow_tooltip")
	root.get_texture().get_image().save_png("res://art/previews/arrow_tooltip/relief.png")
	print("ARROW_RELIEF vertices: ", mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size())
	layer.free()
	surface.queue_free()
	await process_frame
	quit()
