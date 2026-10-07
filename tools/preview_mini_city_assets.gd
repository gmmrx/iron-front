extends SceneTree
## Honest Godot renders of the runtime geometry and imported materials.

const MODELS := preload("res://game/map/mini_city_models.gd")

func _init() -> void:
	await process_frame
	DisplayServer.window_set_size(Vector2i(1280, 900))
	root.content_scale_size = Vector2i(1280, 900)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("343b3b")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("e2e4de")
	env.environment.ambient_light_energy = 0.75
	root.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -28, 0)
	light.light_color = Color("ffeed9")
	light.light_energy = 0.85
	light.shadow_enabled = RenderingServer.get_current_rendering_method() != "gl_compatibility"
	root.add_child(light)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	ground.mesh = plane
	ground.position.y = -0.004
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("46504a")
	mat.roughness = 1.0
	ground.material_override = mat
	root.add_child(ground)
	var camera := Camera3D.new()
	camera.position = Vector3(1.05, 1.4, 1.65)
	camera.fov = 30
	root.add_child(camera)
	camera.look_at(Vector3(0, 0.08, 0), Vector3.UP)
	camera.make_current()
	var display := MeshInstance3D.new()
	root.add_child(display)
	var library := MODELS.new()
	var only_style := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--style="): only_style = argument.substr(8)
	var folder := "res://art/previews/mini_city/runtime_" + RenderingServer.get_current_rendering_method()
	DirAccess.make_dir_recursive_absolute(folder)
	for style: String in MODELS.STYLES:
		if not only_style.is_empty() and style != only_style: continue
		for variant in 2:
			var city := City.new()
			city.style = style
			city.id = variant
			var model: Dictionary = library.model_for(city)
			if model.is_empty() or bool(model["legacy"]):
				push_error("New district asset missing: %s_%d" % [style, variant])
				quit(1)
				return
			display.mesh = model["mesh"]
			for frame in 60: await process_frame
			RenderingServer.viewport_set_update_mode(root.get_viewport_rid(), RenderingServer.VIEWPORT_UPDATE_ALWAYS)
			RenderingServer.force_draw(false)
			var path := folder + "/city_%s_%d.png" % [style, variant]
			root.get_texture().get_image().save_png(path)
			print("MINI_CITY_ASSET ", path)
	display.free()
	ground.free()
	camera.free()
	light.free()
	env.free()
	await process_frame
	quit()
