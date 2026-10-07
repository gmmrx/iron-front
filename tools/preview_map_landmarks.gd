extends SceneTree
## Actual map/lighting captures and zoom-invariance checks, without game UI.

var _errors: Array[String] = []
var _city_transforms := {}
var _city_signatures := {}
var _ground_transforms := {}
var _port_transforms := {}
var _catcher: Logger
var _strait_transforms := {}
var _strait_labels := {}

func _init() -> void:
	_catcher = preload("res://game/dev/error_catcher.gd").new()
	OS.add_logger(_catcher)
	await process_frame
	DisplayServer.window_set_size(Vector2i(1440, 900))
	root.content_scale_size = Vector2i(1440, 900)
	root.get_node("Game").new_game()
	var world: Node = root.get_node("World")
	world.start_game("TUR")
	var map: Node3D = load("res://game/map/map_view_3d.gd").new()
	root.add_child(map)
	if not map.is_built: await map.built
	var cities: Node3D = load("res://game/map/city_layer_3d.gd").new()
	cities.map = map
	root.add_child(cities)
	if not cities.is_built: await cities.built
	var camera: Camera3D = load("res://game/map/map_camera_3d.gd").new()
	camera.map = map
	camera.map_size = map.map_size
	camera.edge_pan_enabled = false
	camera.input_locked = true
	root.add_child(camera)
	camera.make_current()
	var pins: Node3D = load("res://game/map/pin_layer.gd").new()
	pins.map = map
	pins.camera = camera
	pins.cities = cities
	root.add_child(pins)
	# The real environment/sun, without adding Main or running its UI _ready().
	var lighting: Node = load("res://game/main.gd").new()
	lighting._setup_environment()
	var lighting_children: Array[Node] = []
	for child: Node in lighting.get_children():
		lighting.remove_child(child)
		root.add_child(child)
		lighting_children.append(child)
	lighting.free()
	var settlements_only := "--settlements-only" in OS.get_cmdline_user_args()
	var city_only := "--city-only" in OS.get_cmdline_user_args() or settlements_only
	var folder := "res://art/previews/landmarks/" + RenderingServer.get_current_rendering_method()
	DirAccess.make_dir_recursive_absolute(folder)
	var country: Object = world.countries["TUR"]
	var state: Object = world.states[country.capital_state]
	var capital: Object = state.largest_city()
	var city_pos: Vector2 = cities._visual_positions.get(capital.id, capital.position)
	var city_distances: Array[float] = [350.0, 150.0, 90.0, 55.0]
	if "--bridges-only" in OS.get_cmdline_user_args(): city_distances.clear()
	for distance: float in city_distances:
		camera.focus_on(city_pos, distance)
		map.set_camera_distance(camera.distance)
		for frame in 90: await process_frame
		_check_city(pins, cities, capital.id, distance)
		_capture(folder + "/ankara_%d.png" % int(distance))
	if settlements_only:
		for name: String in ["Istanbul", "London", "Tokyo", "Zurich"]:
			for city: Object in world.cities:
				if city.name != name: continue
				var center: Vector2 = cities._visual_positions.get(city.id, city.position)
				for distance: float in [100.0, 55.0]:
					camera.focus_on(center, distance)
					map.set_camera_distance(camera.distance)
					for frame in 90: await process_frame
					_check_city(pins, cities, city.id, distance)
					_check_ports(cities, pins, camera)
					_capture(folder + "/settlement_%s_%d.png" % [name.to_snake_case(), int(distance)])
				break
	var strait_layer: Node3D
	for child: Node in cities.get_children():
		if child.get_script() == load("res://game/map/strait_layer.gd"):
			strait_layer = child
			break
	if strait_layer == null and not city_only:
		_errors.append("Actual CityLayer3D has no StraitLayer")
	elif not city_only:
		var placements: Array = strait_layer.get("placements")
		var bridges: Dictionary = strait_layer.get("bridge_endpoints")
		if bridges.size() != world.straits.size():
			_errors.append("Every strait must have a bridge crossing, not a port/ferry")
		for record: Dictionary in placements:
			if not str(record.get("path", "")).begins_with("res://assets/models/strait/"):
				_errors.append("Strait scenery uses an old model fallback")
			if record.get("kind", "") in ["shore_terminal", "steam_ferry"]:
				_errors.append("Rejected civilian terminal/ferry is still placed on the map")
		for name: String in ["Bosporus", "Dardanelles", "Strait of Gibraltar", "Little Belt", "Strait of Dover"]:
			var found := false
			for strait: Dictionary in world.straits:
				var names: Dictionary = strait.get("name", {})
				if names.get("en", "") != name: continue
				found = true
				var a: Array = strait["from"]
				var b: Array = strait["to"]
				var center := (Vector2(a[0], a[1]) + Vector2(b[0], b[1])) * 0.5
				for distance: float in [100.0, 55.0]:
					camera.focus_on(center, distance)
					map.set_camera_distance(camera.distance)
					for frame in 90: await process_frame
					_check_straits(strait_layer)
					_capture(folder + "/%s_%d.png" % [name.to_snake_case(), int(distance)])
					print("LANDMARK_MAP ", name, " camera=", camera.distance)
			if not found: _errors.append("Preview crossing not found: " + name)
	# Existing distant gate remains, even though the world size is now constant.
	camera.focus_on(city_pos, 650.0)
	map.set_camera_distance(camera.distance)
	for frame in 90: await process_frame
	var visible_city_models := 0
	for model: MeshInstance3D in pins._halls.values():
		if model.visible: visible_city_models += 1
	if visible_city_models != 0:
		_errors.append("Miniatures visible outside their existing near-zoom range")
	_capture(folder + "/region_650.png")
	var engine_errors: Array = _catcher.take()
	for i in mini(engine_errors.size(), 12):
		_errors.append("Engine/script: " + str(engine_errors[i]))
	OS.remove_logger(_catcher)
	print("LANDMARK_MAP zoom checks=", "PASS" if _errors.is_empty() else "FAIL", " errors=", _errors)
	pins.free()
	cities.free()
	map.free()
	camera.free()
	for child: Node in lighting_children: child.free()
	await process_frame
	quit(0 if _errors.is_empty() else 1)

func _check_city(pins: Node3D, cities: Node3D, id: int, distance: float) -> void:
	var pin_index := -1
	for i in pins._pins.size():
		var city: Object = pins._pins[i][4]
		if city != null and city.id == id:
			pin_index = i
			break
	var model: MeshInstance3D = pins._halls.get(pin_index)
	var label: Label3D = cities.labels.get(id)
	if model == null or label == null:
		_errors.append("Capital model or its normal label missing at %s" % distance)
		return
	if not _city_signatures.has(id):
		_city_transforms[id] = model.transform
		_city_signatures[id] = _label_signature(label)
	else:
		if not model.transform.is_equal_approx(_city_transforms[id]):
			_errors.append("City world transform changes with zoom at %s" % distance)
		if _label_signature(label) != _city_signatures[id]:
			_errors.append("City text/typography/anchor changes with zoom at %s" % distance)
	var ground: MeshInstance3D = pins._city_sites.get(pin_index)
	if ground == null or ground.visible != model.visible:
		_errors.append("City ground/exit roads missing or not matching model visibility")
	elif _ground_transforms.has(id) and not ground.transform.is_equal_approx(_ground_transforms[id]):
		_errors.append("City ground/roads world transform changes with zoom")
	elif ground != null:
		_ground_transforms[id] = ground.transform
	print("LANDMARK_MAP ", label.text, " camera=", distance, " world width=", model.get_aabb().size.x * model.scale.x,
		" label=", label.text, " font=", label.font_size, " scale=", label.scale)

func _check_ports(cities: Node3D, pins: Node3D, camera: Camera3D) -> void:
	for layer: Node in cities.get_children():
		if layer.get_script() == load("res://game/map/map_icon_layer.gd"):
			if not layer._port_nodes.is_empty(): _errors.append("Port billboard still exists")
		if not bool(layer.get_meta("map_landmark_layer", false)): continue
		for sid: int in layer.ports:
			var model: MeshInstance3D = layer.ports[sid]
			if _port_transforms.has(sid) and not model.transform.is_equal_approx(_port_transforms[sid]):
				_errors.append("Physical port world transform changes with zoom")
			_port_transforms[sid] = model.transform
			var center: Vector3 = (model.global_transform * model.mesh.get_aabb()).get_center()
			if not model.visible or center.distance_to(camera.global_position) > 500.0 or not camera.is_position_in_frustum(center): continue
			var screen := camera.unproject_position(center)
			var hit: Dictionary = pins.pick_building(screen)
			if int(hit.get("sid", -1)) != sid or hit.get("building", "") != "naval_base":
				_errors.append("Physical port does not retain building tooltip/selection hit: %d" % sid)

func _check_straits(layer: Node3D) -> void:
	for child: Node in layer.find_children("*", "MeshInstance3D", true, false):
		var key: String = str(layer.get_path_to(child))
		if _strait_transforms.has(key):
			if not child.transform.is_equal_approx(_strait_transforms[key]):
				_errors.append("Strait world transform changes with zoom: " + key)
		else:
			_strait_transforms[key] = child.transform
	for label: Label3D in layer.find_children("*", "Label3D", true, false):
		var key: String = str(layer.get_path_to(label))
		var signature := _label_signature(label)
		if _strait_labels.has(key) and _strait_labels[key] != signature:
			_errors.append("Strait typography/anchor changes with zoom: " + key)
		_strait_labels[key] = signature

func _label_signature(label: Label3D) -> Dictionary:
	return {"text": label.text, "font": label.font, "font_size": label.font_size,
		"outline_size": label.outline_size, "color": label.modulate, "scale": label.scale,
		"position": label.position, "offset": label.offset, "fixed_size": label.fixed_size,
		"pixel_size": label.pixel_size}

func _capture(path: String) -> void:
	# Background macOS diagnostic windows may not emit frame_post_draw.
	RenderingServer.viewport_set_update_mode(root.get_viewport_rid(), RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	RenderingServer.force_draw(false)
	var err := root.get_texture().get_image().save_png(path)
	if err != OK: _errors.append("Capture failed: " + path)
