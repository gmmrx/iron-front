extends SceneTree
## Actual map, discovery mask and sparse atmosphere. Legacy filename; no discovery volume.
var _catcher: Logger
var _errors: Array[String] = []

func _init() -> void:
	_catcher = preload("res://game/dev/error_catcher.gd").new()
	OS.add_logger(_catcher)
	await process_frame
	DisplayServer.window_set_size(Vector2i(1440, 900))
	root.content_scale_size = Vector2i(1440, 900)
	root.get_node("Game").new_game()
	root.get_node("World").start_game("TUR")
	var map_script: Script = load("res://game/map/map_view_3d.gd")
	var map: Node3D = map_script.new()
	root.add_child(map)
	if not map.is_built:
		await map.built
	var camera_script: Script = load("res://game/map/map_camera_3d.gd")
	var camera: Camera3D = camera_script.new()
	camera.map_size = map.map_size
	camera.map = map
	camera.edge_pan_enabled = false
	camera.input_locked = true
	root.add_child(camera)
	camera.make_current()
	# Use the game's actual environment/sun, without starting its UI scene.
	var lighting: Node = load("res://game/main.gd").new()
	var lighting_children: Array[Node] = []
	lighting._setup_environment()
	for child: Node in lighting.get_children():
		lighting.remove_child(child)
		root.add_child(child)
		lighting_children.append(child)
	lighting.free()
	var military: Node = root.get_node("Military")
	military.fog_enabled = true
	map.set_fog(military.fog_levels(), military.fog_version)
	var world: Node = root.get_node("World")
	var home: Vector2 = world.capital_position("TUR")
	var hidden: Vector2 = world.capital_position("POL")
	var explored_before: PackedByteArray = military.fog_levels().duplicate()
	if not map._fog_volume.find_children("*", "MeshInstance3D", true, false).is_empty():
		_errors.append("Discovery helper allocated a 3D cloud volume")
	if map._cloud_mesh.patches.is_empty():
		_errors.append("Sparse atmosphere did not generate any cloud patches")
	if not military.is_visible(world.capital_province("TUR")) or military.is_visible(world.capital_province("POL")):
		_errors.append("Preview has no distinct explored/unknown provinces")
	var bank := home
	var bank_distance := INF
	for patch: Dictionary in map._cloud_mesh.patches:
		var center: Vector2 = patch["position"]
		var province: Object = world.province(map.province_at(center))
		if province != null and province.is_land() and center.distance_squared_to(home) < bank_distance:
			bank = center
			bank_distance = center.distance_squared_to(home)
	var method := RenderingServer.get_current_rendering_method()
	var folder := "res://art/previews/atmosphere/" + method
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		_errors.append("Could not create preview output directory")
	for shot in [["strategic", home, 5200.0], ["region", home, 1600.0], ["cloud_bank", bank, 800.0],
			["close", hidden, 420.0], ["near", hidden, 160.0], ["below", hidden, 55.0]]:
		camera.focus_on(shot[1], shot[2])
		map.set_camera_distance(camera.distance)
		for f in 12:
			await process_frame
		if camera.distance <= 260.0 and map._cloud_mesh.visible:
			_errors.append("Atmospheric cloud cards visible in near/below view")
		if military.fog_levels() != explored_before:
			_errors.append("Atmosphere/zoom changed persistent discovery")
		_capture(folder + "/" + shot[0] + ".png")
		print("ATMOSPHERE_PREVIEW ", shot[0], " camera=", camera.position, " distance=", camera.distance,
			" patches=", map._cloud_mesh.patches.size(), " batches=", map._cloud_mesh.batches.size(),
			" atmosphere_visible=", map._cloud_mesh.visible)
	# Same regional camera/mask, without cards: clouds must not be the exploration cue.
	camera.focus_on(home, 1600.0)
	map.set_camera_distance(camera.distance)
	map._cloud_mesh.hide()
	for frame in 12:
		await process_frame
	_capture(folder + "/region_without_atmosphere.png")
	if military.fog_levels() != explored_before:
		_errors.append("Hiding atmospheric geometry changed persistent discovery")
	for error: String in _catcher.take():
		_errors.append("Engine/shader: " + error)
	OS.remove_logger(_catcher)
	print("ATMOSPHERE_PREVIEW checks=", "PASS" if _errors.is_empty() else "FAIL", " errors=", _errors)
	map.free()
	camera.free()
	for child: Node in lighting_children:
		child.free()
	await process_frame
	quit(0 if _errors.is_empty() else 1)

func _capture(path: String) -> void:
	# Background macOS windows may never emit frame_post_draw; explicitly flush both viewport draws.
	RenderingServer.viewport_set_update_mode(root.get_viewport_rid(), RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	RenderingServer.force_draw(false)
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		_errors.append("Capture has no rendered pixels: " + path)
	elif image.save_png(path) != OK:
		_errors.append("Capture failed: " + path)
