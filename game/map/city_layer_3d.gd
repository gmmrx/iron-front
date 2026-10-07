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
## şehir modelinin taban elipsi (model birimi; tools/blender/build_cities.py SIZES ile aynı)
const CITY_EXTENT := {"town": Vector2(0.95, 0.8), "medium": Vector2(1.45, 1.25), "large": Vector2(2.1, 1.8), "capital": Vector2(2.7, 2.3)}
## kenarı dağıtılan zemin malzemeleri
const GROUND_MATERIALS := ["garden", "city_paving", "city_paving_warm", "asphalt", "ground_dirt", "ground_cobble", "concrete"]
const CELL := 3.0                   ## işgal ızgarası (dünya birimi)
const CHUNK := 384.0
const BUILDINGS_PATH := "res://assets/models/buildings.glb"
## kamera mesafesi (dünya birimi) üst sınırları
const MODEL_RANGE := {"capital": 700.0, "large": 500.0, "medium": 350.0, "town": 240.0, "port": 350.0}
const AIRBASE_RANGE := 450.0
const LABEL_RANGE: Array[float] = [1300.0, 650.0, 420.0, 240.0, 140.0]  ## tier 0..4: uzakta yalnız başkent ve büyük şehirler

var map: MapView3D
var _font: Font
var _bold: Font
var _mesh_cache := {}
var _lib := {}                      ## düğüm adı -> Mesh (buildings.glb)
var _occupied := {}                 ## Vector2i hücre -> true (şehirler/limanlar çakışmasın)
## İğne tasarımı: şehir, liman ve hava üssü modelleri kurulmaz (konum, doluluk ve ad hesapları sürer).
## Modelleri geri açmak için true.
const SHOW_MODELS := false
var _visual_positions := {}         ## city id -> kıyıyı taşırmayan model merkezi
var labels := {}                    ## city id -> her zoom'da aynı sade ad etiketi
var label_plates := {}              ## eski API uyumu; şehirlerde kutu oluşturulmaz
var far_labels := {}                ## aynı tek ad etiketi (eski API uyumu; ikinci düğüm yok)
const LABEL_PX := 0.0005            ## normal harita yazısının değişmeyen piksel boyu
const PLATE_PAD := 12.0             ## kutunun yazıdan taşması (etiket pikseli)
static var _plate_cache := {}
const CONFORM_SHADER := preload("res://assets/shaders/conform.gdshader")
const BUILDING_SHADER := preload("res://assets/shaders/building.gdshader")
const PORT_LAYER := preload("res://game/map/port_layer.gd")

## Açılış yükleme ekranı (main): kurulum adımları arasında bir kare çizilir; kapalıyken tek seferde. Bitince built.
signal built
var yield_frames := false
var on_progress: Callable
var is_built := false

func _boot_step(f: float) -> void:
	if on_progress.is_valid():
		on_progress.call(f)
	if yield_frames:
		await get_tree().process_frame

func _ready() -> void:
	_font = load("res://assets/fonts/BarlowCondensed-SemiBold.ttf")
	_bold = UiTheme.bold_font()
	_load_library()
	await _boot_step(0.15)
	_build_models()
	await _boot_step(0.6)
	_build_labels()
	for sid: int in map.airbase_sites:
		_mark_airbase(sid)
	await _boot_step(0.75)
	_build_industry()
	await _boot_step(0.9)
	_build_straits_and_airbases()
	Economy.building_completed.connect(_on_building_completed)
	is_built = true
	built.emit()

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
			var extent := Vector2.ZERO
			for size: String in CITY_EXTENT:
				if path.ends_with("_%s.gltf" % size):
					extent = CITY_EXTENT[size] * 1.04
			mesh = _conform(mesh, path.contains("/city_"), extent)
	_mesh_cache[path] = mesh
	return mesh

func _conform(src: Mesh, clip_water := false, fade_extent := Vector2.ZERO) -> Mesh:
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
			if fade_extent != Vector2.ZERO and String(bm.resource_name) in GROUND_MATERIALS:
				sm.set_shader_parameter("fade_edge", true)
				sm.set_shader_parameter("fade_extent", fade_extent)
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
		var city_path := "res://assets/models/city_%s_%s.gltf" % [c.style, size]
		var scale: float = CITY_SCALE[size]
		var radius: float = CITY_RADIUS[size]
		var visual_radius := radius if SHOW_MODELS else PinLayer.city_model_width(c) * 0.72
		var visual_pos := _best_city_position(c, visual_radius)
		_visual_positions[c.id] = visual_pos
		map.register_city_site(c.id, visual_pos, visual_radius)
		if SHOW_MODELS:
			var city_t := Transform3D(Basis(Vector3.UP, -angle).scaled(Vector3.ONE * scale),
					Vector3(visual_pos.x, _ground(visual_pos), visual_pos.y))
			_add(groups, city_path, city_t.origin, city_t)
			ranges[city_path] = MODEL_RANGE[size]
		for oy in range(-ceili(radius / CELL), ceili(radius / CELL) + 1):
			for ox in range(-ceili(radius / CELL), ceili(radius / CELL) + 1):
				var p := visual_pos + Vector2(ox, oy) * CELL
				if p.distance_squared_to(visual_pos) <= radius * radius:
					_occupied[_cell_of(p)] = true
	map.commit_city_sites()
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
	# A ring alone misses the southeast corner of a yawed rectangular miniature.
	# On the normal flat-map path check the entire compact building footprint.
	if not SHOW_MODELS and _city_rectangle_land(c, c.position) == 63:
		return c.position
	var best := c.position
	var best_score := -INF
	var phase := float(_hash(c.id + 31) % 628) / 100.0
	var offsets: Array[Vector2] = [Vector2.ZERO]
	var rings := [0.55, 0.95, 1.35, 1.75] if SHOW_MODELS else [0.55, 0.95, 1.35, 1.75, 2.4, 3.2, 4.4]
	for ring: float in rings:
		for i in 16:
			var a: float = phase + TAU * float(i) / 16.0
			offsets.append(Vector2(cos(a), sin(a)) * radius * ring)
	for off: Vector2 in offsets:
		var candidate: Vector2 = c.position + off
		if not _is_land(candidate):
			continue
		var land_score := 0.0
		if not SHOW_MODELS:
			var dry := _city_rectangle_land(c, candidate)
			# Rings are nearest-first, so the first completely dry fit is also the
			# nearest sampled full rectangle. Narrow peninsulas can use outer rings.
			if dry == 63: return candidate
			land_score = float(dry) * 4.5
		else:
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

## Native mini-city bounds are one unit wide and at most .94 deep. PinLayer's
## uniform width and yaw are static, so this uses the same transform as the mesh.
func _city_rectangle_land(c: City, center: Vector2) -> int:
	var width := PinLayer.city_model_width(c)
	var dry := 0
	for x in 9:
		for z in 7:
			var local := Vector2(-0.5 + float(x) / 8.0, -0.47 + float(z) * 0.94 / 6.0) * width
			if _is_land(center + local.rotated(-c.grid_angle)):
				dry += 1
	# Refine only apparently valid candidates: a tiny concave pixel corner can
	# sit between coarse samples and clip a roof despite all 63 points being dry.
	if dry == 63:
		for x in 17:
			for z in 13:
				var local := Vector2(-0.5 + float(x) / 16.0, -0.47 + float(z) * 0.94 / 12.0) * width
				if not _is_land(center + local.rotated(-c.grid_angle)): return 62
	return dry

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
	var ports: Node3D = PORT_LAYER.new()
	ports.set("map", map)
	ports.set("cities", self)
	add_child(ports)
	var icons := MapIconLayer.new()
	icons.map = map
	add_child(icons)
	for sid: int in map.airbase_sites:
		_add_airbase(sid)

func _add_airbase(sid: int) -> void:
	if not SHOW_MODELS:
		return
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
		_mark_airbase(sid)
		_add_airbase(sid)

## Hava üssünün alanı dolu sayılır: sanayi parselleri ve birimler üstüne gelmez
func _mark_airbase(sid: int) -> void:
	var pos: Vector2 = map.airbase_sites[sid][0]
	var r := MapView3D.AIRBASE_RADIUS * 1.1
	for oy in range(-ceili(r / CELL), ceili(r / CELL) + 1):
		for ox in range(-ceili(r / CELL), ceili(r / CELL) + 1):
			var p := pos + Vector2(ox, oy) * CELL
			if p.distance_squared_to(pos) <= r * r:
				_occupied[_cell_of(p)] = true
	_unit_spots.clear()

## Tümen modelinin durduğu yer: şehir modelinin, hava üssünün, limanın ve dolu sanayi parsellerinin dışında,
## bölge merkezine en yakın boş nokta, bölgenin kendi içinde (komşu bölgeye taşarsa figür sınırın ötesinde düşmanın
## dibinde duruyordu; hiç yer yoksa merkez). Önbellekli; sanayi değişince yenilenir.
var _unit_spots := {}
var _unit_spots_version := -1
func unit_spot(pid: int, p: Vector2) -> Vector2:
	if _industry and _industry.version != _unit_spots_version:
		_unit_spots.clear()
		_unit_spots_version = _industry.version
	if _unit_spots.has(pid):
		return _unit_spots[pid]
	var best := p
	if _blocked(p):
		var found := false
		for ring in range(1, 9):
			for k in 12:
				var a := TAU * float(k) / 12.0 + float(ring) * 0.37
				var q := p + Vector2(cos(a), sin(a)) * float(ring) * 3.5
				if map.province_at(q) == pid and not _blocked(q):
					best = q
					found = true
					break
			if found:
				break
	_unit_spots[pid] = best
	return best

const UNIT_CLEARANCE := 4.5         ## figürün kendi yarıçapı (tank boyu) kadar pay

func _blocked(q: Vector2) -> bool:
	for off: Vector2 in [Vector2.ZERO, Vector2(UNIT_CLEARANCE, 0), Vector2(-UNIT_CLEARANCE, 0), Vector2(0, UNIT_CLEARANCE),
			Vector2(0, -UNIT_CLEARANCE)]:
		if _occupied.has(_cell_of(q + off)):
			return true
	if _industry:
		var r := IndustryLayer.SCALE * 0.7 + UNIT_CLEARANCE
		for pl: Vector2 in _industry.active_plots:
			if pl.distance_squared_to(q) < r * r:
				return true
	return false

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

## Kalabalığa karşı: bir şehrin adı ve noktası, yanındaki daha önemli şehirden ekranda yeterince ayrılınca belirir.
## Önem: başkent, sonra zafer puanı. Ekran aralığı ≈ dünya uzaklığı / kamera uzaklığı × UnitLayer.PX; SPACING_PX'ten
## azsa gizli → görünür olduğu en büyük kamera uzaklığı = komşu uzaklığı × PX / SPACING_PX. Uzakta her yörede yalnız
## en önemli şehir kalır, yaklaştıkça öbürleri açılır. Sabit hesap (açılışta bir kez, ızgarayla).
const SPACING_PX := 220.0
static var _spacing := {}            ## city id -> en büyük görünür kamera uzaklığı (yoksa sınırsız)

static func spacing_range(c: City) -> float:
	if _spacing.is_empty():
		_build_spacing()
	return float(_spacing.get(c.id, INF))

static func _build_spacing() -> void:
	var order: Array = World.cities.duplicate()
	order.sort_custom(func(a: City, b: City) -> bool:
		if a.is_capital != b.is_capital:
			return a.is_capital
		if a.victory_points != b.victory_points:
			return a.victory_points > b.victory_points
		return a.id < b.id)
	var k := UnitLayer.PX / SPACING_PX
	var reach := LABEL_RANGE[0] / k                  # bundan uzaktaki komşu hiçbir zoom'da sınır koymaz
	var grid := {}
	for c: City in order:
		var cell := Vector2i(floori(c.position.x / reach), floori(c.position.y / reach))
		var best := INF
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				for o: City in grid.get(cell + Vector2i(dx, dy), []):
					best = minf(best, c.position.distance_to(o.position))
		_spacing[c.id] = best * k if best < reach else INF
		if not grid.has(cell):
			grid[cell] = []
		grid[cell].append(c)

## Her şehir için tek normal harita yazısı: yakın/uzak geçişi, serif/kutu ve boy animasyonu yok.
func _build_labels() -> void:
	for c in World.cities:
		var tier := CityLayer.tier_of(c)
		var fl := Label3D.new()
		fl.text = c.display_name()
		fl.font = _bold if c.is_capital else _font
		fl.font_size = 24 if c.is_capital else 20
		fl.outline_size = 8
		fl.outline_modulate = Color(0.03, 0.03, 0.02, 0.9)
		fl.modulate = CityLayer.CAPITAL_COLOR if c.is_capital else CityLayer.TEXT_COLOR
		fl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		fl.fixed_size = true
		fl.pixel_size = LABEL_PX
		fl.no_depth_test = true
		fl.render_priority = 5
		fl.outline_render_priority = 4
		# Minyatürün önündeki sabit dünya anchor'ı: zoom/focus/hover yazıyı taşımaz.
		var p: Vector2 = _visual_positions.get(c.id, c.position)
		var anchor := p + Vector2(0.0, PinLayer.city_model_width(c) * 0.7)
		fl.position = Vector3(anchor.x, maxf(map.height_at(anchor), 0.0) + 0.05, anchor.y)
		fl.offset = Vector2(0, -10)
		fl.scale = Vector3.ONE
		var end := minf(LABEL_RANGE[tier], spacing_range(c))   # yanındaki önemli şehirden ayrılınca
		fl.visibility_range_end = end
		fl.visibility_range_end_margin = end * 0.1
		fl.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		add_child(fl)
		labels[c.id] = fl
		far_labels[c.id] = fl

## Ordu ad kartları için ortak doku yardımcısı (UnitLayer). Şehir yazıları bu kutuyu kullanmaz.
static func label_plate(w: float, h: float) -> Texture2D:
	var wi := int(ceil(w / 8.0)) * 8
	var hi := int(ceil(h))
	var key := wi * 1000 + hi
	if _plate_cache.has(key):
		return _plate_cache[key]
	var img := Image.create(wi, hi, false, Image.FORMAT_RGBA8)
	var r := 5.0
	var fill := Color(0.055, 0.065, 0.075, 0.9)
	var edge := Color(0.62, 0.58, 0.48, 0.95)
	for y in hi:
		for x in wi:
			var qx := absf(float(x) + 0.5 - wi * 0.5) - (wi * 0.5 - r)
			var qy := absf(float(y) + 0.5 - hi * 0.5) - (hi * 0.5 - r)
			var sd := Vector2(maxf(qx, 0.0), maxf(qy, 0.0)).length() + minf(maxf(qx, qy), 0.0) - r
			if sd > 0.5:
				continue
			var col := edge if sd > -1.8 else fill
			col.a *= clampf(0.5 - sd, 0.0, 1.0)
			img.set_pixel(x, y, col)
	var tex := ImageTexture.create_from_image(img)
	_plate_cache[key] = tex
	return tex

## İnşaat binaları (fabrika, rafineri, tersane, deniz üssü, uçaksavar, demiryolu, şantiye): IndustryLayer
var _industry: IndustryLayer

func industry() -> IndustryLayer:
	return _industry

func _build_industry() -> void:
	var ind := IndustryLayer.new()
	_industry = ind
	ind.map = map
	ind.occupied = _occupied
	ind.city_positions = _visual_positions
	ind.cell_size = CELL
	add_child(ind)
