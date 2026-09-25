class_name CityLayer3D
extends Node3D
## Şehir, başkent ve liman modelleri + şehir adları.
## Modeller mimari stile (west/east/orient/nordic) ve büyüklüğe göre seçilir.
## MultiMesh'ler bölgesel parçalara (CHUNK) ayrılır: görünürlük mesafesi her parça için
## ayrı hesaplanır (tek dev MultiMesh'te tüm modeller birlikte açılıp kapanıyordu).

const MODEL_SCALE := 5.0            ## liman
const AIRBASE_SCALE := 3.4          ## şehirlerle aynı stratejik ölçekte kompakt tesis
const CITY_SCALE := {"town": 4.4, "medium": 4.2, "large": 4.0, "capital": 3.8}
const CITY_RADIUS := {"town": 5.2, "medium": 7.2, "large": 9.8, "capital": 12.5}
const CELL := 3.0                   ## işgal ızgarası (dünya birimi)
const CHUNK := 384.0
const BUILDINGS_PATH := "res://assets/models/buildings.glb"
## kamera mesafesi (dünya birimi) üst sınırları
const MODEL_RANGE := {"capital": 1450.0, "large": 1000.0, "medium": 700.0, "town": 480.0, "port": 700.0}
const AIRBASE_RANGE := 900.0
const LABEL_RANGE: Array[float] = [2600.0, 1100.0, 700.0, 450.0, 280.0]  ## tier 0..4

var map: MapView3D
var _font: Font
var _bold: Font
var _mesh_cache := {}
var _lib := {}                      ## düğüm adı -> Mesh (buildings.glb)
var _occupied := {}                 ## Vector2i hücre -> true (şehirler/limanlar çakışmasın)
var _visual_positions := {}         ## city id -> kıyıyı taşırmayan model merkezi
const CONFORM_SHADER := preload("res://assets/shaders/conform.gdshader")
const BUILDING_SHADER := preload("res://assets/shaders/building.gdshader")

func _ready() -> void:
	_font = load("res://assets/fonts/BarlowCondensed-SemiBold.ttf")
	_bold = UiTheme.bold_font()
	_load_library()
	_build_models()
	_build_labels()
	_build_straits_and_airbases()
	_build_industry()
	Economy.building_completed.connect(_on_building_completed)
	Economy.building_completed.connect(func(_t: String, _s: int, _b: String) -> void: _industry_dirty = true)
	Economy.construction_changed.connect(func(_t: String) -> void: _industry_dirty = true)
	World.ownership_changed.connect(func() -> void: _industry_dirty = true)

func _process(_delta: float) -> void:
	if _industry_dirty:
		_industry_dirty = false
		_refresh_industry()

## Şehrin zemindeki yaklaşık yarıçapı (dünya birimi): düzleştirme ve liman uzaklığı için
static func footprint_radius(c: City) -> float:
	return CITY_RADIUS[size_of(c)]

static func size_of(c: City) -> String:
	if c.is_capital: return "capital"
	if c.victory_points >= 10: return "large"
	if c.victory_points >= 3: return "medium"
	return "town"

func _load_library() -> void:
	var scene: Node = (load(BUILDINGS_PATH) as PackedScene).instantiate()
	var stack: Array[Node] = [scene]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			_lib[String(n.name)] = (n as MeshInstance3D).mesh
		stack.append_array(n.get_children())
	scene.free()

## Eski tek parça modeller (hava üssü) için: araziye uyan shader
func _mesh(path: String) -> Mesh:
	if _mesh_cache.has(path):
		return _mesh_cache[path]
	var mesh: Mesh = null
	var res := load(path)
	if res is PackedScene:
		var scene: Node = (res as PackedScene).instantiate()
		var stack: Array[Node] = [scene]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			if n is MeshInstance3D:
				mesh = (n as MeshInstance3D).mesh
				break
			stack.append_array(n.get_children())
		scene.free()
		if mesh:
			mesh = _conform(mesh, path.contains("/city_"))
	_mesh_cache[path] = mesh
	return mesh

func _conform(src: Mesh, clip_water := false) -> Mesh:
	var mesh: Mesh = src.duplicate()
	for i in mesh.get_surface_count():
		var sm := ShaderMaterial.new()
		sm.shader = CONFORM_SHADER
		var m := mesh.surface_get_material(i)
		if m is BaseMaterial3D:
			var bm := m as BaseMaterial3D
			sm.set_shader_parameter("albedo_color", bm.albedo_color)
			sm.set_shader_parameter("roughness", bm.roughness)
			sm.set_shader_parameter("metallic", bm.metallic)
			if bm.albedo_texture:
				sm.set_shader_parameter("albedo_tex", bm.albedo_texture)
				sm.set_shader_parameter("has_texture", true)
			if bm.normal_enabled and bm.normal_texture:
				sm.set_shader_parameter("normal_tex", bm.normal_texture)
				sm.set_shader_parameter("has_normal", true)
		sm.set_shader_parameter("height_tex", map.height_texture)
		sm.set_shader_parameter("map_size", map.map_size)
		sm.set_shader_parameter("height_scale", MapView3D.HEIGHT_SCALE)
		sm.set_shader_parameter("coast_tex", map.border_texture)
		sm.set_shader_parameter("clip_water", clip_water)
		mesh.surface_set_material(i, sm)
	return mesh

static func _hash(n: int) -> int:
	var x := n * 747796405 + 2891336453
	x = ((x >> 13) ^ x) * 1274126177
	return absi(x ^ (x >> 16))

func _cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.y / CELL))

func _is_land(p: Vector2) -> bool:
	var pr := World.province(map.province_at(p))
	return pr != null and pr.is_land()

func _build_models() -> void:
	var groups := {}
	var ranges := {}
	var ordered: Array[City] = World.cities.duplicate()
	ordered.sort_custom(func(a: City, b: City) -> bool: return a.victory_points > b.victory_points)
	for c in ordered:
		var size := size_of(c)
		var h := _hash(c.id)
		var angle := float(h % 628) / 100.0
		c.grid_angle = angle
		var city_path := "res://assets/models/city_%s_%s.glb" % [c.style, size]
		var scale: float = CITY_SCALE[size]
		var radius: float = CITY_RADIUS[size]
		var visual_pos := _best_city_position(c, radius)
		_visual_positions[c.id] = visual_pos
		var city_t := Transform3D(Basis(Vector3.UP, -angle).scaled(Vector3.ONE * scale),
				Vector3(visual_pos.x, _ground(visual_pos), visual_pos.y))
		_add(groups, city_path, city_t.origin, city_t)
		ranges[city_path] = MODEL_RANGE[size]
		for oy in range(-ceili(radius / CELL), ceili(radius / CELL) + 1):
			for ox in range(-ceili(radius / CELL), ceili(radius / CELL) + 1):
				var p := visual_pos + Vector2(ox, oy) * CELL
				if p.distance_squared_to(visual_pos) <= radius * radius:
					_occupied[_cell_of(p)] = true
		if c.is_port:
			var pt = _port_transform(c)
			if pt != null:
				_add(groups, "port_0", pt.origin, pt)
				ranges["port_0"] = MODEL_RANGE["port"]
	var count := 0
	for key: Array in groups:
		var name: String = key[0]
		var mesh := _mesh(name) if name.begins_with("res://") else _building_mesh(name)
		if mesh == null:
			continue
		var list: Array = groups[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.visibility_range_end = ranges[key[0]]
		mmi.visibility_range_end_margin = ranges[key[0]] * 0.12
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		add_child(mmi)
		count += list.size()
	print("[cities] %d stratejik şehir/liman modeli" % count)

## Kıyı şehirlerinin diorama tabanı denizin üstüne taşmasın. Küçük bir aday kümesinden,
## ayak izinin en fazla karada kaldığı ve gerçek şehir noktasına en yakın merkezi seçer.
func _best_city_position(c: City, radius: float) -> Vector2:
	var best := c.position
	var best_score := -INF
	var phase := float(_hash(c.id + 31) % 628) / 100.0
	var offsets: Array[Vector2] = [Vector2.ZERO]
	for ring: float in [0.55, 0.95, 1.35, 1.75]:
		for i in 16:
			var a: float = phase + TAU * float(i) / 16.0
			offsets.append(Vector2(cos(a), sin(a)) * radius * ring)
	for off: Vector2 in offsets:
		var candidate: Vector2 = c.position + off
		if not _is_land(candidate):
			continue
		var land_score := 0.0
		for sample_ring: float in [0.42, 0.78]:
			for j in 12:
				var a: float = TAU * float(j) / 12.0
				var p: Vector2 = candidate + Vector2(cos(a), sin(a)) * radius * sample_ring
				land_score += 1.0 if _is_land(p) else -3.5
		var score: float = land_score - off.length() / maxf(radius, 1.0) * 1.8
		if score > best_score:
			best_score = score
			best = candidate
	return best

func _ground(p: Vector2) -> float:
	return maxf(map.height_at(p), 0.0) - 0.05

## Kütüphane mesh'i + bina shader'ı (dokular korunur, dipte ortam gölgesi)
func _building_mesh(name: String) -> Mesh:
	var key := "bld:" + name
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var src: Mesh = _lib.get(name)
	if src == null:
		return null
	var mesh: Mesh = src.duplicate()
	for i in mesh.get_surface_count():
		var m := mesh.surface_get_material(i)
		var sm := ShaderMaterial.new()
		sm.shader = BUILDING_SHADER
		if m is BaseMaterial3D:
			var bm := m as BaseMaterial3D
			sm.set_shader_parameter("albedo_color", bm.albedo_color)
			sm.set_shader_parameter("roughness", bm.roughness)
			sm.set_shader_parameter("metallic", bm.metallic)
			if bm.albedo_texture:
				sm.set_shader_parameter("albedo_tex", bm.albedo_texture)
				sm.set_shader_parameter("has_texture", true)
			if bm.normal_enabled and bm.normal_texture:
				sm.set_shader_parameter("normal_tex", bm.normal_texture)
				sm.set_shader_parameter("has_normal", true)
		mesh.surface_set_material(i, sm)
	_mesh_cache[key] = mesh
	return mesh

func _add(groups: Dictionary, name: String, pos: Vector3, t: Transform3D) -> void:
	var key := [name, Vector2i(int(pos.x / CHUNK), int(pos.z / CHUNK))]
	if not groups.has(key):
		groups[key] = []
	groups[key].append(t)

func _build_straits_and_airbases() -> void:
	var straits := StraitLayer.new()
	straits.map = map
	straits.building_mesh = _building_mesh
	add_child(straits)
	var icons := MapIconLayer.new()
	icons.map = map
	add_child(icons)
	var trees := TreeLayer.new()
	trees.map = map
	add_child(trees)
	for sid: int in map.airbase_sites:
		_add_airbase(sid)

func _add_airbase(sid: int) -> void:
	var site: Array = map.airbase_sites[sid]
	var pos: Vector2 = site[0]
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh("res://assets/models/airbase.glb")
	mi.transform = Transform3D(Basis(Vector3.UP, site[1]).scaled(Vector3.ONE * AIRBASE_SCALE), Vector3(pos.x, map.height_at(pos), pos.y))
	mi.visibility_range_end = AIRBASE_RANGE
	mi.visibility_range_end_margin = AIRBASE_RANGE * 0.12
	mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(mi)

func _on_building_completed(_tag: String, sid: int, building: String) -> void:
	if building == "air_base" and map.add_airbase_site(World.states[sid]):
		_add_airbase(sid)

## Limanı şehirden en yakın deniz bölgesine doğru, gemi denize bakacak şekilde yerleştir.
func _port_transform(c: City) -> Variant:
	var p := World.province(c.province_id)
	if p == null:
		return null
	# limanın açıldığı deniz: donanma ile aynı (Navy.sea_for) ve deniz yolunun rıhtım noktası yönü
	var sea := Navy.sea_for(c.province_id)
	if sea <= 0:
		return null
	var best := SeaLanes.dock(c.province_id, sea)
	if best == Vector2.INF:
		best = SeaLanes.node(sea)
	var city_pos: Vector2 = _visual_positions.get(c.id, c.position)
	var dir := (best - c.position).normalized()
	# şehir modelinin dışında kalsın: kıyı boyunca iki yana kaydırılmış adaylardan denize en yakın olanı
	var tangent := Vector2(-dir.y, dir.x)
	var off := footprint_radius(c) + 4.0
	var best_pos := Vector2.INF
	var best_steps := 999
	var min_d := footprint_radius(c) + 3.0
	var cands: Array[Vector2] = []
	for k in [1.0, 1.4, 1.9, 2.5]:
		cands.append(city_pos + tangent * off * k)
		cands.append(city_pos - tangent * off * k)
	for cand in cands:
		var r = _walk_to_coast(cand, dir)
		if r != null and (r[0] as Vector2).distance_to(city_pos) >= min_d and r[1] < best_steps:
			best_steps = r[1]
			best_pos = r[0]
	if best_pos == Vector2.INF:
		return null
	var yaw := atan2(dir.x, dir.y)
	_occupied[_cell_of(best_pos)] = true
	map.harbors[c.province_id] = [best_pos, dir]
	return Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * MODEL_SCALE), Vector3(best_pos.x, maxf(map.height_at(best_pos), 0.0) + 0.05, best_pos.y))

## Noktadan dir yönünde kıyıya yürü; karadaysa ileri, denizdeyse geri. [kıyı noktası, adım] ya da null
func _walk_to_coast(start: Vector2, dir: Vector2) -> Variant:
	var sp := World.province(map.province_at(start))
	if sp == null:
		return null
	var step := dir if sp.is_land() else -dir
	var pos := start
	for i in 40:
		var nxt := pos + step
		var np := World.province(map.province_at(nxt))
		if np == null:
			return null
		if np.is_land() != sp.is_land():
			return [pos if sp.is_land() else nxt, i]
		pos = nxt
	return null

func _build_labels() -> void:
	for c in World.cities:
		var tier := CityLayer.tier_of(c)
		var l := Label3D.new()
		l.text = c.display_name()
		l.font = _bold if c.is_capital else _font
		l.font_size = 30 if c.is_capital else 26
		l.outline_size = 9
		l.outline_modulate = Color(0.03, 0.03, 0.02, 0.9)
		l.modulate = CityLayer.CAPITAL_COLOR if c.is_capital else CityLayer.TEXT_COLOR
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.fixed_size = true
		l.pixel_size = 0.0005
		l.no_depth_test = true
		l.render_priority = 5
		l.outline_render_priority = 4
		l.position = Vector3(c.position.x, map.height_at(c.position) + (12.0 if c.is_capital else 7.0), c.position.y)
		l.offset = Vector2(0, 16)
		l.visibility_range_end = LABEL_RANGE[tier]
		l.visibility_range_end_margin = LABEL_RANGE[tier] * 0.1
		l.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		add_child(l)


# ------------------------------------------------------------------ sanayi ve inşaat görünürlüğü
## Eyaletin fabrikaları (sivil + askerî + tersane) ana şehrin çevresinde küçük fabrika modelleri olarak görünür
## (2 fabrika ≈ 1 model, en çok 8); kuyruktaki inşaat için turuncu iskele işareti. Oyuncu "ne inşa ettim,
## nerede?" sorusunun cevabını haritada görür; sanayi bölgeleri uzaktan da okunur.
## MultiMesh'ler şehirler gibi CHUNK parçalarına bölünür (görünürlük mesafesi parça başına hesaplanır).
const INDUSTRY_SCALE := 2.8
const INDUSTRY_RANGE := 620.0
const INDUSTRY_MAX := 8
var _industry_dirty := false
var _industry_slots := {}          ## sid -> [[Vector2, yaw], ...]
var _industry_style := {}          ## sid -> "west" | "east" | ...
var _industry_nodes := {}          ## [stil|"scaffold", Vector2i chunk] -> MultiMeshInstance3D
var _scaffold_mesh: BoxMesh

func _build_industry() -> void:
	for st: StateRegion in World.states.values():
		if st.cities.is_empty():
			continue
		var main: City = st.cities[0]
		for c: City in st.cities:
			if c.victory_points > main.victory_points:
				main = c
		var center: Vector2 = _visual_positions.get(main.id, main.position)
		var r := footprint_radius(main) * 1.12 + 3.2
		var phase := float(_hash(main.id + 77) % 628) / 100.0
		var slots: Array = []
		for ring: float in [1.0, 1.3]:
			for i in 12:
				if slots.size() >= INDUSTRY_MAX + 3:
					break
				var a: float = phase + TAU * float(i) / 12.0 + (0.26 if ring > 1.2 else 0.0)
				var p: Vector2 = center + Vector2(cos(a), sin(a)) * r * ring
				var cell := _cell_of(p)
				if _occupied.has(cell) or not _is_land(p):
					continue
				if map.province_at(p) <= 0 or World.province(map.province_at(p)).state_id != st.id:
					continue
				_occupied[cell] = true
				slots.append([p, -a + PI * 0.5])
		if slots.is_empty():
			continue
		_industry_slots[st.id] = slots
		_industry_style[st.id] = main.style
	_scaffold_mesh = BoxMesh.new()
	_scaffold_mesh.size = Vector3(0.6, 0.9, 0.6)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.62, 0.15)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.55, 0.1)
	mat.emission_energy_multiplier = 0.9
	mat.roughness = 0.7
	_scaffold_mesh.material = mat
	_refresh_industry()

func _industry_count(st: StateRegion) -> int:
	var n := st.building_level("civilian_factory") + st.building_level("military_factory") + st.building_level("dockyard")
	return clampi(ceili(n / 2.0), 0, INDUSTRY_MAX)

func _industry_node(key: Array) -> MultiMeshInstance3D:
	if _industry_nodes.has(key):
		return _industry_nodes[key]
	var mesh: Mesh = _scaffold_mesh if key[0] == "scaffold" else _building_mesh("%s_factory_0" % key[0])
	if mesh == null:
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.visibility_range_end = INDUSTRY_RANGE
	mmi.visibility_range_end_margin = INDUSTRY_RANGE * 0.12
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(mmi)
	_industry_nodes[key] = mmi
	return mmi

func _refresh_industry() -> void:
	var lists := {}                    # key -> [Transform3D]
	var building_now := {}
	for c: Country in World.countries.values():
		for pr: ConstructionProject in c.construction_queue:
			if pr.building in ["civilian_factory", "military_factory", "dockyard", "synthetic_refinery", "anti_air"]:
				building_now[pr.state_id] = int(building_now.get(pr.state_id, 0)) + 1
	for sid: int in _industry_slots:
		var st: StateRegion = World.states[sid]
		var slots: Array = _industry_slots[sid]
		var n := mini(_industry_count(st), slots.size())
		var style: String = _industry_style[sid]
		for i in n:
			var p: Vector2 = slots[i][0]
			var key := [style, Vector2i(int(p.x / CHUNK), int(p.y / CHUNK))]
			if not lists.has(key):
				lists[key] = []
			lists[key].append(Transform3D(Basis(Vector3.UP, float(slots[i][1])).scaled(Vector3.ONE * INDUSTRY_SCALE), Vector3(p.x, _ground(p), p.y)))
		if building_now.has(sid) and n < slots.size():
			var p: Vector2 = slots[n][0]
			var key := ["scaffold", Vector2i(int(p.x / CHUNK), int(p.y / CHUNK))]
			if not lists.has(key):
				lists[key] = []
			lists[key].append(Transform3D(Basis(Vector3.UP, float(slots[n][1])).scaled(Vector3.ONE * INDUSTRY_SCALE), Vector3(p.x, _ground(p) + 0.45 * INDUSTRY_SCALE, p.y)))
	for key: Array in _industry_nodes:
		if not lists.has(key):
			(_industry_nodes[key] as MultiMeshInstance3D).multimesh.instance_count = 0
	for key: Array in lists:
		var node := _industry_node(key)
		if node == null:
			continue
		var arr: Array = lists[key]
		var mm := node.multimesh
		mm.instance_count = arr.size()
		for i in arr.size():
			mm.set_instance_transform(i, arr[i])
	if OS.has_environment("INDDBG"):
		print("INDDBG nodes=%d states=%d" % [_industry_nodes.size(), _industry_slots.size()])
