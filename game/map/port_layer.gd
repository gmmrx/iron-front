class_name PortLayer
extends Node3D
## One grounded native 3D naval facility per coastal state. No icon or civilian ship.
## All sizes are map-world units; camera distance only gates visibility.

const MODELS := preload("res://game/map/port_models.gd")
const WORLD_WIDTH := 2.6
const VISIBILITY_END := 380.0
const COAST_STEP := 0.5
const COAST_REACH := 180.0
var map: MapView3D
var cities: Node3D
var ports := {}                    ## state id -> MeshInstance3D
var placements := {}               ## state id -> actual fitted native footprint metadata
var _models := MODELS.new()
var _coast_cache := {}
var _land_cache := {}
var _fog_seen := -1

func _ready() -> void:
	set_meta("map_landmark_layer", true)
	if Economy.SHOW_BUILDINGS:
		var seen := {}
		for c: City in World.cities:
			if c.is_port and not seen.has(c.state_id):
				seen[c.state_id] = true
				_add_state(c.state_id)
	if not Economy.building_completed.is_connected(_on_building_completed):
		Economy.building_completed.connect(_on_building_completed)
	_process(0.0)

func _process(_delta: float) -> void:
	if _fog_seen == Military.fog_version:
		return
	_fog_seen = Military.fog_version
	for sid: int in ports:
		(ports[sid] as Node3D).visible = Economy.SHOW_BUILDINGS and not Military.state_fogged(World.states.get(sid))

func _on_building_completed(_tag: String, sid: int, building: String) -> void:
	if building == "naval_base" and Economy.SHOW_BUILDINGS:
		_add_state(sid)

## Physical facility hit area for the existing building tooltip / click workflow.
## This follows projected world geometry, never a fixed-size badge or zoom-scaled mesh.
func pick_building(screen: Vector2, camera: MapCamera3D) -> Dictionary:
	if not visible or not Economy.SHOW_BUILDINGS or camera == null:
		return {}
	var best := {}
	var nearest := INF
	for sid: int in placements:
		var site: Dictionary = placements[sid]
		var node: MeshInstance3D = site["node"]
		if not node.visible or Military.state_fogged(World.states.get(sid)):
			continue
		var bounds: AABB = node.global_transform * node.mesh.get_aabb()
		var center := bounds.get_center()
		var distance := camera.global_position.distance_squared_to(center)
		if distance > VISIBILITY_END * VISIBILITY_END or camera.is_position_behind(center):
			continue
		var rect := Rect2(camera.unproject_position(bounds.get_endpoint(0)), Vector2.ZERO)
		for endpoint in range(1, 8):
			rect = rect.expand(camera.unproject_position(bounds.get_endpoint(endpoint)))
		if rect.grow(3.0).has_point(screen) and distance < nearest:
			nearest = distance
			best = {"sid": sid, "building": "naval_base", "construction": false,
					"pid": site["province_id"], "hk": "port:%d" % sid, "pos": site["position"]}
	return best

func _port_city(sid: int) -> City:
	for c: City in World.cities:
		if c.state_id == sid and c.is_port:
			return c
	return null

func _add_state(sid: int) -> void:
	var state: StateRegion = World.states.get(sid)
	if state == null or state.building_level("naval_base") <= 0:
		return
	if ports.has(sid):
		(ports[sid] as Node3D).set_meta("naval_base_level", state.building_level("naval_base"))
		return
	var city := _port_city(sid)
	if city == null:
		return
	var model := _models.model()
	if model.is_empty():
		return
	var site := coastal_site(city)
	if site.is_empty():
		push_warning("[ports] no dry quay / wet pier fit for %s" % city.name)
		return
	var node := MeshInstance3D.new()
	node.name = "Port_%d" % sid
	node.mesh = model["mesh"]
	node.transform = (site["placement"] as Transform3D) * (model["transform"] as Transform3D)
	node.visibility_range_end = VISIBILITY_END
	node.visibility_range_end_margin = VISIBILITY_END * 0.12
	node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	node.set_meta("naval_base_level", state.building_level("naval_base"))
	node.set_meta("map_landmark", "port")
	node.visible = not Military.state_fogged(state)
	add_child(node)
	ports[sid] = node
	site["node"] = node
	site["path"] = model["path"]
	site["city_id"] = city.id
	site["province_id"] = city.province_id
	site["state_id"] = sid
	placements[sid] = site
	# FleetLayer consumes this exact API and walks from here into the sea.
	map.harbors[city.province_id] = [site["position"], site["direction"]]

func _is_land(p: Vector2) -> bool:
	var key := Vector2i(floori(p.x), floori(p.y))
	if not _land_cache.has(key):
		var province := World.province(map.province_at(p))
		_land_cache[key] = province != null and province.is_land()
	return _land_cache[key]

func _is_sea(p: Vector2) -> bool:
	var province := World.province(map.province_at(p))
	return province != null and province.type == Province.Type.SEA

func coastal_site(city: City) -> Dictionary:
	if _coast_cache.has(city.id):
		return _coast_cache[city.id]
	var model := _models.model()
	if model.is_empty():
		return {}
	var sea := Navy.sea_for(city.province_id)
	var dock := SeaLanes.dock(city.province_id, sea) if sea > 0 else Vector2.INF
	var heading := (dock - city.position).normalized() if dock != Vector2.INF else Vector2.RIGHT
	if dock == Vector2.INF and sea > 0:
		heading = (SeaLanes.node(sea) - city.position).normalized()
	if heading.length_squared() < 0.1: heading = Vector2.RIGHT
	var seed := city.position
	# Most dock records are already close to the actual coast; try that area first.
	var best := {}
	var score := INF
	var seeds: Array[Vector2] = [seed]
	if dock != Vector2.INF and dock.distance_to(seed) < COAST_REACH:
		seeds.push_front(dock)
	for start: Vector2 in seeds:
		for ray in 24:
			var direction := heading.rotated(TAU * float(ray) / 24.0)
			var coast := _coast_on_ray(start, direction)
			if coast == Vector2.INF: continue
			var outward := direction if _is_land(start) else -direction
			var site := _fit_coast(coast, outward, city)
			if site.is_empty(): continue
			var distance: float = (site["position"] as Vector2).distance_squared_to(city.position)
			# Keep the facility clear of its tiny city, without the old 12.5-unit exclusion.
			if cities != null:
				var center: Vector2 = cities._visual_positions.get(city.id, city.position)
				var clearance := 2.2 + WORLD_WIDTH * 0.45
				if (site["position"] as Vector2).distance_to(center) < clearance:
					distance += 64.0
			if distance < score:
				best = site
				score = distance
		# A valid close dock fit needs no long sweep from the city inland.
		if not best.is_empty() and score < 64.0: break
	_coast_cache[city.id] = best
	return best

func _coast_on_ray(start: Vector2, direction: Vector2) -> Vector2:
	var began_land := _is_land(start)
	var previous := start
	for step in range(1, int(COAST_REACH / COAST_STEP) + 1):
		var current := start + direction * COAST_STEP * float(step)
		if _is_land(current) != began_land:
			# Subpixel boundary refinement matters for a one-pixel coastline.
			for refinement in 8:
				var middle := (previous + current) * 0.5
				if _is_land(middle) == began_land: previous = middle
				else: current = middle
			return (previous + current) * 0.5
		previous = current
	return Vector2.INF

func _fit_coast(coast: Vector2, outward: Vector2, city: City) -> Dictionary:
	var model := _models.model()
	var bounds: AABB = model["bounds"]
	var dry: PackedVector2Array = model["land_samples"]
	var wet: PackedVector2Array = model["water_samples"]
	for rotation: float in [0.0, -15.0, 15.0, -30.0, 30.0, -45.0, 45.0, -60.0, 60.0, -90.0, 90.0]:
		var direction := outward.rotated(deg_to_rad(rotation))
		var tangent := Vector2(direction.y, -direction.x)
		for shift: float in [0.0, -1.0, 1.0, -2.0, 2.0, -4.0, 4.0]:
			for inland: float in [0.08, 0.25, 0.5, 0.8, 1.1]:
				var position := coast + tangent * shift - direction * inland
				# Some source port cities are upstream or one-pixel micro-states.
				# Fit the real neighboring coastline, never fabricate sea or flatten land.
				if not _is_land(position - direction * 0.8): continue
				var fits := true
				for p: Vector2 in dry:
					if not _is_land(position + (tangent * p.x + direction * p.y) * WORLD_WIDTH):
						fits = false
						break
				if not fits: continue
				for p: Vector2 in wet:
					if not _is_sea(position + (tangent * p.x + direction * p.y) * WORLD_WIDTH):
						fits = false
						break
				if not fits: continue
				var basis := Basis(Vector3.UP, atan2(direction.x, direction.y)).scaled(Vector3.ONE * WORLD_WIDTH)
				var y := map.height_at(position) - bounds.position.y * WORLD_WIDTH
				return {"position": position, "direction": direction,
						"placement": Transform3D(basis, Vector3(position.x, y, position.y)),
						"width_world": WORLD_WIDTH, "coast_seed": coast,
						"source_city_distance": position.distance_to(city.position)}
	return {}
