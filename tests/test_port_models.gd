extends "res://tests/test_case.gd"

const MODELS := preload("res://game/map/port_models.gd")
const LAYER := preload("res://game/map/port_layer.gd")
const PROBE := preload("res://tests/map_probe.gd")
const CITY_MODELS := preload("res://game/map/mini_city_models.gd")

class CoastMap extends MapView3D:
	func province_at(p: Vector2) -> int:
		return PROBE.province_at(p)

func _layer() -> PortLayer:
	var layer: PortLayer = LAYER.new()
	layer.map = CoastMap.new()
	return layer

func _release(layer: PortLayer) -> void:
	var map := layer.map
	layer.free()
	map.free()

func test_existing_facility_keeps_native_pbr_uv_and_no_civilian_vessel() -> void:
	var models := MODELS.new()
	var model := models.model()
	if not check(not model.is_empty(), "native port_0 facility loads"): return
	var mesh: Mesh = model["mesh"]
	var original: Mesh = model["source_mesh"]
	eq(model["source_node"], "port_0", "existing Blender facility source")
	eq(model["path"], "res://assets/models/buildings.glb", "no civilian ferry/terminal asset")
	check(model.has("imported_transform") and model.has("imported_bounds"), "original scene transform and bounds preserved")
	eq(model["surface_names"], ["concrete", "brick_red", "roof_slate", "crane"], "only actual architecture and dock equipment")
	eq(mesh.get_surface_count(), 4, "bounded native material draw calls")
	check(mesh == models.model()["mesh"], "shared cached facility geometry")
	var bounds: AABB = model["bounds"]
	near(bounds.size.x, 1.0, 0.002, "quay normalized to one fixed-width unit")
	check(bounds.position.y > -0.06, "large buried foundation removed")
	var textured := 0
	var triangles := 0
	for surface in mesh.get_surface_count():
		var material := mesh.surface_get_material(surface) as StandardMaterial3D
		if not check(material != null, "native PBR retained"): continue
		var shared := false
		for source_surface in original.get_surface_count():
			if material == original.surface_get_material(source_surface): shared = true
		check(shared, "no replacement shader or recreated material")
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		triangles += (indices.size() if not indices.is_empty() else vertices.size()) / 3
		eq(arrays[Mesh.ARRAY_NORMAL].size(), vertices.size(), "every native vertex keeps its normal")
		if material.albedo_texture != null:
			textured += 1
			eq(arrays[Mesh.ARRAY_TEX_UV].size(), vertices.size(), "native texture UV layout retained")
			check(material.normal_enabled and material.normal_texture != null, "native normal texture remains enabled")
	gt(textured, 0, "textured miniature, not flat icon colors")
	gt(triangles, 40, "actual warehouse/quay/crane geometry")
	check(triangles <= 3000, "small facility triangle budget")

func test_every_active_naval_base_has_one_grounded_real_coastal_facility() -> void:
	PROBE.ensure()
	var layer := _layer()
	var original_straits := World.straits.duplicate(true)
	var expected := {}
	for city: City in World.cities:
		var state: StateRegion = World.states.get(city.state_id)
		if city.is_port and state != null and state.building_level("naval_base") > 0:
			expected[city.state_id] = true
	layer._ready()
	eq(layer.ports.size(), expected.size(), "exactly one actual facility for every eligible state")
	var model := layer._models.model()
	for sid: int in expected:
		if not check(layer.placements.has(sid), "state %d has a coast fit" % sid): continue
		var site: Dictionary = layer.placements[sid]
		var node: MeshInstance3D = site["node"]
		var position: Vector2 = site["position"]
		var direction: Vector2 = site["direction"]
		var tangent := Vector2(direction.y, -direction.x)
		var placement: Transform3D = site["placement"]
		near(placement.basis.x.length(), PortLayer.WORLD_WIDTH, 0.00001, "constant world width, no zoom scale")
		near(placement.basis.y.length(), PortLayer.WORLD_WIDTH, 0.00001, "native uniform height scale")
		near(placement.basis.z.length(), PortLayer.WORLD_WIDTH, 0.00001, "native uniform pier length scale")
		eq(node.visibility_range_end, 380.0, "near-map LOD matches physical bridges")
		check(node.material_override == null, "native materials render in both backends")
		near((node.transform * node.mesh.get_aabb()).position.y, 0.0, 0.002, "native foundation bottom touches flat map")
		for p: Vector2 in model["land_samples"]:
			check(layer._is_land(position + (tangent * p.x + direction * p.y) * PortLayer.WORLD_WIDTH), "state %d quay/warehouse is on real land" % sid)
		for p: Vector2 in model["water_samples"]:
			check(PROBE.is_sea(position + (tangent * p.x + direction * p.y) * PortLayer.WORLD_WIDTH), "state %d narrow pier points into actual sea" % sid)
		check(layer.map.harbors.has(site["province_id"]), "fleet harbor API populated")
		eq(layer.map.harbors[site["province_id"]], [position, direction], "fleet uses actual visual coast and water heading")
	check(layer.get_meta("map_landmark_layer", false), "pin mode preserves the real port layer")
	eq(World.straits, original_straits, "unrelated crossing gameplay remains unchanged")
	print("PORT_COAST_QA ", layer.ports.size(), " active states / ", expected.size(), " expected; cached pixels=", layer._land_cache.size())
	_release(layer)

func test_construction_refresh_and_fog_visibility_keep_existing_rules() -> void:
	PROBE.ensure()
	var layer := _layer()
	var city: City = null
	for c: City in World.cities:
		if c.is_port and Navy.sea_for(c.province_id) > 0:
			city = c
			break
	if not check(city != null, "test has a coastal city"): return
	var state: StateRegion = World.states[city.state_id]
	state.buildings["naval_base"] = 0
	layer._add_state(city.state_id)
	eq(layer.ports.size(), 0, "no level-zero facility")
	state.buildings["naval_base"] = 1
	layer._on_building_completed(state.owner, city.state_id, "naval_base")
	if not check(layer.ports.has(city.state_id), "completed naval base creates real 3D facility"):
		_release(layer)
		return
	var node: MeshInstance3D = layer.ports[city.state_id]
	var transform := node.transform
	state.buildings["naval_base"] = 3
	layer._on_building_completed(state.owner, city.state_id, "naval_base")
	eq(layer.ports.size(), 1, "level upgrades do not duplicate the port")
	eq(node.get_meta("naval_base_level"), 3, "level metadata refreshes")
	Military.fog_enabled = true
	Military.fog_version += 1
	layer._process(0.0)
	eq(node.visible, not Military.state_fogged(state), "normal building discovery gate")
	Military.fog_enabled = false
	Military.fog_version += 1
	layer._process(0.0)
	check(node.visible, "discovered/observer port is visible")
	eq(node.transform, transform, "construction and discovery do not resize or move the facility")
	_release(layer)

func test_map_icon_layer_never_creates_port_sprite() -> void:
	var map := CoastMap.new()
	var icons := MapIconLayer.new()
	icons.map = map
	icons._ready()
	eq(icons._port_nodes.size(), 0, "port billboard API remains empty")
	var sprites := icons.find_children("*", "Sprite3D", true, false)
	gt(sprites.size(), 0, "city icon behavior remains intact")
	for sprite: Sprite3D in sprites:
		check(not sprite.texture.resource_path.ends_with("/port.svg"), "no strategic port icon created")
	icons.free()
	map.free()

func test_major_coastal_city_rectangles_fit_real_land_with_native_yaw() -> void:
	PROBE.ensure()
	var map := CoastMap.new()
	var cities := CityLayer3D.new()
	cities.map = map
	var models := CITY_MODELS.new()
	var checked := 0
	for c: City in World.cities:
		if not c.is_port or c.victory_points < 10: continue
		c.grid_angle = float(CityLayer3D._hash(c.id) % 628) / 100.0
		var position := cities._best_city_position(c, PinLayer.city_model_width(c) * 0.72)
		eq(cities._city_rectangle_land(c, position), 63, c.name + " actual yawed miniature rectangle fully dry")
		var model := models.model_for(c)
		if not check(not model.is_empty(), c.name + " native city mesh exists"): continue
		var width := PinLayer.city_model_width(c)
		var placement := Transform3D(Basis(Vector3.UP, c.grid_angle).scaled(Vector3.ONE * width * float(model["scale"])),
				Vector3(position.x, 0.0, position.y)) * (model["transform"] as Transform3D)
		var wet := 0
		var mesh: Mesh = model["mesh"]
		for surface in mesh.get_surface_count():
			for vertex: Vector3 in mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var world := placement * vertex
				if PROBE.is_water(Vector2(world.x, world.z)): wet += 1
		eq(wet, 0, c.name + " all native building/roof vertices are on actual land")
		checked += 1
	gt(checked, 20, "representative actual major coastal cities checked")
	print("CITY_NATIVE_COAST_QA ", checked, " major coastal miniatures fully dry")
	cities.free()
	map.free()

func test_physical_port_pick_retains_building_tooltip_contract_without_resizing() -> void:
	PROBE.ensure()
	var layer := _layer()
	var city: City = null
	for c: City in World.cities:
		var state: StateRegion = World.states.get(c.state_id)
		if c.is_port and state != null and state.building_level("naval_base") > 0:
			city = c
			break
	if not check(city != null, "active coastal facility for picking"): return
	layer._add_state(city.state_id)
	if not check(layer.ports.has(city.state_id), "physical pick target exists"):
		_release(layer)
		return
	var node: MeshInstance3D = layer.ports[city.state_id]
	var transform := node.transform
	var holder := Node3D.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(holder)
	layer.remove_child(node)
	holder.add_child(node)
	var camera := MapCamera3D.new()
	camera.map_size = Vector2(16384, 8106)
	holder.add_child(camera)
	camera.set_process(false)
	var site: Dictionary = layer.placements[city.state_id]
	for distance: float in [55.0, 150.0, 250.0]:
		camera.focus_on(site["position"], distance)
		var center := (node.global_transform * node.mesh.get_aabb()).get_center()
		var hit := layer.pick_building(camera.unproject_position(center), camera)
		eq(hit.get("building", ""), "naval_base", "native geometry keeps the building tooltip kind")
		eq(hit.get("sid", -1), city.state_id, "physical hit keeps the gameplay state")
		eq(hit.get("pid", -1), city.province_id, "physical hit keeps the fleet source province")
		eq(hit.get("hk", ""), "port:%d" % city.state_id, "stable hover identity")
		eq(hit.get("construction", true), false, "completed facility click contract")
		eq(node.transform, transform, "picking and zoom never resize physical geometry")
	camera.focus_on(site["position"], 900.0)
	eq(layer.pick_building(Vector2.ZERO, camera), {}, "invisible far-away port cannot be clicked")
	camera.focus_on(site["position"], 55.0)
	node.visible = false
	eq(layer.pick_building(Vector2.ZERO, camera), {}, "fog-hidden port cannot be clicked")
	holder.remove_child(node)
	layer.add_child(node)
	tree.root.remove_child(holder)
	holder.free()
	_release(layer)
