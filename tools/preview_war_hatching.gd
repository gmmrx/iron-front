extends SceneTree
## Actual province/controller rasters and production front/occupation shaders, without UI or simulation.
var _errors: Array[String] = []

func _init() -> void:
	await process_frame
	DisplayServer.window_set_size(Vector2i(1440, 900))
	root.content_scale_size = Vector2i(1440, 900)
	var catcher: Logger = preload("res://game/dev/error_catcher.gd").new()
	OS.add_logger(catcher)
	root.get_node("Game").new_game()
	var world: Node = root.get_node("World")
	world.start_game("GER")
	root.get_node("GameClock").set_process(false)
	root.get_node("Military").fog_enabled = false
	var diplomacy: Node = root.get_node("Diplomacy")
	world.countries["GER"].war_goals["POL"] = true
	if not diplomacy.declare_war("GER", "POL"):
		_errors.append("Cannot establish real GER/POL war fixture")
	var front_script: Script = load("res://game/map/front_layer.gd")
	var picker: Node3D = front_script.new()
	var pairs: Array = picker.front_pairs()
	var desired: Vector2 = (world.capital_position("GER") + world.capital_position("POL")) * 0.5
	var best: Array = []
	var best_distance := INF
	for pair: Array in pairs:
		var center: Vector2 = (world.province(pair[0]).center + world.province(pair[1]).center) * 0.5
		var distance := center.distance_squared_to(desired)
		if distance < best_distance:
			best_distance = distance
			best = pair
	picker.free()
	if best.is_empty():
		_errors.append("War has no real land/land control border")
		OS.remove_logger(catcher)
		quit(1)
		return
	var captured := [int(best[1])]
	for pid: int in world.land_neighbors(best[1]):
		if world.controller_tag(pid) == "POL" and captured.size() < 4: captured.append(pid)
	for pid: int in captured: world.set_controller(pid, "GER")
	var occupation_center: Vector2 = world.province(best[1]).center
	# Keep the fresh controlling frontier in frame, not a historical border already behind the advance.
	var front_center := occupation_center
	for pid: int in captured:
		for other: int in world.land_neighbors(pid):
			if world.controller_tag(other) == "POL":
				front_center = (world.province(pid).center + world.province(other).center) * 0.5
				break
	var map: Node3D = load("res://game/map/map_view_3d.gd").new()
	root.add_child(map)
	if not map.is_built: await map.built
	map._cloud_mesh.hide()
	var camera: Camera3D = load("res://game/map/map_camera_3d.gd").new()
	camera.map = map
	camera.map_size = map.map_size
	camera.edge_pan_enabled = false
	camera.input_locked = true
	root.add_child(camera)
	camera.make_current()
	camera.set_process(false)
	var lighting: Node = load("res://game/main.gd").new()
	lighting._setup_environment()
	var lights: Array[Node] = []
	for child: Node in lighting.get_children():
		lighting.remove_child(child)
		root.add_child(child)
		lights.append(child)
	lighting.free()
	var front: Node3D = front_script.new()
	front.map = map
	front.camera = camera
	root.add_child(front)
	front.set_process(false)
	front._dirty = false
	await front._rebuild()
	# Fixture controller-change notifications may arrive during the async build.
	# The sweep isolates zoom/hover with no outstanding ownership invalidation.
	front._dirty = false
	var stable_mesh: ArrayMesh = front._mi[0].mesh
	if front._mi.size() != 1: _errors.append("Front must have one stable mesh")
	for distance: float in [55.0, 150.0, 450.0, 899.0, 900.0, 901.0, 1100.0, 2600.0, 150.0]:
		camera.distance = distance
		front.set_hover(int(best[0]), int(best[1]))
		front._process(0.016)
		if front._mi[0].mesh != stable_mesh or front._busy: _errors.append("Zoom/hover regenerated geometry")
	front.set_hover(0, 0)
	var center_rows := 0
	for instance: MeshInstance3D in front._mi:
		if instance.mesh == null or instance.mesh.get_surface_count() == 0:
			_errors.append("Production front has no mesh")
			continue
		var arrays := instance.mesh.surface_get_arrays(0)
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in uv.size():
			if is_equal_approx(uv[i].y, 0.5): center_rows += 1
			if not is_equal_approx(vertices[i].y, 0.06): _errors.append("Front is not printed on the flat map")
	if center_rows == 0: _errors.append("Battle extrusion has no exact border-center row")
	var folder := "res://art/previews/war_hatching/" + RenderingServer.get_current_rendering_method()
	DirAccess.make_dir_recursive_absolute(folder)
	var ownership: PackedInt32Array = world.controller.duplicate()
	for spec: Array in [["front_150", 0, 150.0, front_center], ["front_450", 0, 450.0, front_center],
		["front_1100", 0, 1100.0, front_center], ["occupation_150", 2, 150.0, occupation_center],
		["occupation_450", 2, 450.0, occupation_center]]:
		map.set_map_mode(spec[1])
		camera.focus_on(spec[3], spec[2])
		map.set_camera_distance(camera.distance)
		map._cloud_mesh.hide()
		front._process(0.0)
		if not is_equal_approx(front._mat.get_shader_parameter("period"), 4.0): _errors.append("Front phase rescales with zoom")
		if not is_equal_approx(front._mat.get_shader_parameter("band"), 8.0): _errors.append("Front world band rescales with zoom")
		for frame in 100: await process_frame
		RenderingServer.viewport_set_update_mode(root.get_viewport_rid(), RenderingServer.VIEWPORT_UPDATE_ALWAYS)
		RenderingServer.force_draw(false)
		var error := root.get_texture().get_image().save_png(folder + "/" + spec[0] + ".png")
		if error != OK: _errors.append("Screenshot save failed: " + spec[0])
		print("WAR_HATCHING ", spec[0], " camera=", camera.distance, " period=", front._mat.get_shader_parameter("period"),
			" band=", front._mat.get_shader_parameter("band"), " center_rows=", center_rows)
	if ownership != world.controller: _errors.append("Visual fixture altered controller during rendering")
	var engine_errors: Array = catcher.take()
	for i in mini(engine_errors.size(), 10): _errors.append(str(engine_errors[i]))
	OS.remove_logger(catcher)
	print("WAR_HATCHING QA ", "PASS" if _errors.is_empty() else "FAIL", " errors=", _errors)
	front.free()
	map.free()
	camera.free()
	for child: Node in lights: child.free()
	await process_frame
	quit(0 if _errors.is_empty() else 1)
