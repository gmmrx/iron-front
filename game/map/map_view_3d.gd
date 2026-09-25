class_name MapView3D
extends Node3D
## 3D harita: yükseklik haritasıyla kabartılmış tek bir ızgara mesh + harita shader'ı.
## Province seçimi CPU'daki id görüntüsünden, yükseklik CPU'daki yükseklik görüntüsünden okunur.

enum MapMode { POLITICAL, TERRAIN, STATES, ROUTES }

const TERRAIN_PATH := "res://data/map/terrain.png"
const PROVINCES_PATH := "res://data/map/provinces.png"
const BORDERS_PATH := "res://data/map/borders.png"
const HEIGHT_PATH := "res://data/map/heightmap.r32"
const WATER_PATH := "res://data/map/water.png"
const BIOME_PATH := "res://data/map/biome.png"
const DETAIL_DIR := "res://assets/terrain/"
const CLOUD_SHADER := preload("res://assets/shaders/clouds.gdshader")
const CLOUD_HEIGHT := 140.0
const CLOUD_FADE := Vector2(2400.0, 4200.0)   ## kamera mesafesi: bulutların belirmeye başladığı / tam olduğu
const SHADER := preload("res://assets/shaders/map3d.gdshader")
const HEIGHT_SCALE := 0.012        ## dünya birimi / metre (~15x abartı; 1 birim = 1.23 km)
const CHUNK := 1024.0               ## harita ağı parça boyu (piksel)
const VERTEX_SPACING := 4.0          ## ağ köşeleri arası (piksel)
const WRAP_COLUMNS := 9              ## sarmalama için öbür kenara kopyalanan parça sütunu (en uzak zoom'un yarım genişliği)
const LABEL_SCALE := 0.5
const FLATTEN_STRENGTH := 1.0      ## şehir altı düzleştirme; kalan eğimi modeller vertex'te takip eder           ## ad katmanı çözünürlüğü (harita boyutuna oranla)

var map_mode: MapMode = MapMode.POLITICAL
var harbors := {}                     ## liman bölge id -> [liman modeli kıyı noktası, denize bakan yön] (şehir katmanı doldurur)
var hovered_province := 0
var map_size := Vector2.ZERO

var _province_image: Image
var _height_image: Image
var _material: ShaderMaterial
var height_texture: ImageTexture
var border_texture: ImageTexture
var airbase_sites: Dictionary = {}     ## eyalet id -> [konum (Vector2), yön (float)]

const AIRBASE_RADIUS := 12.5           ## büyütülmüş pist için tamamen düzleştirilen yarıçap
var _data_texture: ImageTexture
var _palette_texture: ImageTexture
var labels: CountryLabels3D

func _ready() -> void:
	var terrain := Image.load_from_file(TERRAIN_PATH)
	terrain.generate_mipmaps()
	_province_image = Image.load_from_file(PROVINCES_PATH)
	var borders := Image.load_from_file(BORDERS_PATH)
	map_size = Vector2(_province_image.get_size())
	_height_image = _load_heightmap()
	_flatten_under_cities()
	for st: StateRegion in World.states.values():
		if st.building_level("air_base") > 0:
			_place_airbase(st)

	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("terrain_tex", ImageTexture.create_from_image(terrain))
	height_texture = ImageTexture.create_from_image(_height_image)
	_material.set_shader_parameter("height_tex", height_texture)
	_material.set_shader_parameter("province_tex", ImageTexture.create_from_image(_province_image))
	border_texture = ImageTexture.create_from_image(borders)
	_material.set_shader_parameter("border_tex", border_texture)
	var water := Image.load_from_file(WATER_PATH)
	water.generate_mipmaps()
	_material.set_shader_parameter("water_tex", ImageTexture.create_from_image(water))
	_setup_detail_textures()
	_material.set_shader_parameter("map_size", map_size)
	_material.set_shader_parameter("proj_miller", World._miller)
	_material.set_shader_parameter("wrap_x", World.wraps)
	_material.set_shader_parameter("proj_y_top", World._y_top)
	_material.set_shader_parameter("proj_px_per_rad", World._px_per_rad)
	_material.set_shader_parameter("height_scale", HEIGHT_SCALE)

	# harita ağı parçalara bölünür: kameranın görmediği parçalar çizilmez (dünya haritası çok büyük)
	var nx := ceili(map_size.x / CHUNK)
	var ny := ceili(map_size.y / CHUNK)
	for cy in ny:
		for cx in nx:
			var w := minf(CHUNK, map_size.x - cx * CHUNK)
			var h := minf(CHUNK, map_size.y - cy * CHUNK)
			var plane := PlaneMesh.new()
			plane.size = Vector2(w, h)
			plane.subdivide_width = maxi(int(w / VERTEX_SPACING) - 1, 1)
			plane.subdivide_depth = maxi(int(h / VERTEX_SPACING) - 1, 1)
			plane.custom_aabb = AABB(Vector3(-w / 2, -10, -h / 2), Vector3(w, 130, h))
			var mi := MeshInstance3D.new()
			mi.mesh = plane
			mi.material_override = _material
			mi.position = Vector3(cx * CHUNK + w / 2, 0, cy * CHUNK + h / 2)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			# dünya haritası doğu-batı sarmalanır: kenar sütunlarının kopyası öbür tarafta (shader UV'yi sarar)
			if World.wraps:
				var copies: Array[float] = []
				if cx >= nx - WRAP_COLUMNS:
					copies.append(-map_size.x)
				if cx < WRAP_COLUMNS:
					copies.append(map_size.x)
				for off in copies:
					var dup := MeshInstance3D.new()
					dup.mesh = plane
					dup.material_override = _material
					dup.position = mi.position + Vector3(off, 0, 0)
					dup.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					add_child(dup)

	_setup_clouds()
	labels = CountryLabels3D.new()
	labels.map = self
	rebuild_palette()
	rebuild_province_data()
	World.ownership_changed.connect(rebuild_province_data)
	World.control_changed.connect(rebuild_province_data)
	World.selection_changed.connect(_on_selection_changed)
	World.player_changed.connect(func(_t: String) -> void: _update_player())
	_update_player()

func _load_heightmap() -> Image:
	var meta: Array = World.heightmap_size
	var raw_size := int(meta[0]) * int(meta[1]) * 4
	var bytes: PackedByteArray
	if FileAccess.file_exists(HEIGHT_PATH + ".gz"):
		# depo/paket boyutu için gzip'li (133 MB → 40 MB); ham .r32 varsa o da okunur
		var fz := FileAccess.open(HEIGHT_PATH + ".gz", FileAccess.READ)
		bytes = fz.get_buffer(fz.get_length()).decompress(raw_size, FileAccess.COMPRESSION_GZIP)
	else:
		var f := FileAccess.open(HEIGHT_PATH, FileAccess.READ)
		bytes = f.get_buffer(f.get_length())
	return Image.create_from_data(int(meta[0]), int(meta[1]), false, Image.FORMAT_RF, bytes)

## Eyalete hava üssü yeri bul, araziyi düzleştir. Oyun sırasında da çağrılabilir (yeni üs).
func add_airbase_site(st: StateRegion) -> bool:
	if airbase_sites.has(st.id):
		return false
	if not _place_airbase(st):
		return false
	height_texture.update(_height_image)
	return true

func _place_airbase(st: StateRegion) -> bool:
	var city := st.largest_city()
	var base := city.position if city else st.center
	var r0 := (CityLayer3D.footprint_radius(city) if city else 0.0) + 16.0
	var best_pos := Vector2.INF
	var best_yaw := 0.0
	var best_score := INF
	for ring: float in [1.0, 1.5, 2.2, 3.0]:
		for k in 16:
			var a := k * TAU / 16.0
			var p := base + Vector2(cos(a), sin(a)) * r0 * ring
			var score = _site_score(p, st.id)
			if score != null and score + ring * 3.0 < best_score:
				best_score = score + ring * 3.0
				best_pos = p
				best_yaw = a + PI / 2.0
	if best_pos == Vector2.INF:
		return false
	airbase_sites[st.id] = [best_pos, best_yaw]
	var k2 := float(_height_image.get_width()) / map_size.x
	_flatten_disc(best_pos * k2, AIRBASE_RADIUS * k2, AIRBASE_RADIUS * 1.8 * k2, 1.0)
	return true

## Uygun değilse null; aksi halde yükseklik farkı (düz = küçük)
func _site_score(p: Vector2, sid: int) -> Variant:
	var lo := INF
	var hi := -INF
	for dy: float in [-10.0, 0.0, 10.0]:
		for dx: float in [-10.0, 0.0, 10.0]:
			var q := p + Vector2(dx, dy)
			var pr := World.province(province_at(q))
			if pr == null or not pr.is_land() or pr.state_id != sid:
				return null
			var h := height_at(q)
			lo = minf(lo, h)
			hi = maxf(hi, h)
	return hi - lo

func _flatten_disc(center: Vector2, r: float, outer: float, strength: float) -> void:
	var hs := Vector2(_height_image.get_size())
	var ci := Vector2i(center.clamp(Vector2.ZERO, hs - Vector2.ONE))
	var h0 := _height_image.get_pixelv(ci).r
	var R := int(ceil(outer))
	for y in range(maxi(ci.y - R, 0), mini(ci.y + R + 1, int(hs.y))):
		for x in range(maxi(ci.x - R, 0), mini(ci.x + R + 1, int(hs.x))):
			var d := Vector2(x, y).distance_to(center)
			if d > outer:
				continue
			var w := (1.0 - smoothstep(r, outer, d)) * strength
			var h := _height_image.get_pixel(x, y).r
			_height_image.set_pixel(x, y, Color(lerpf(h, h0, w), 0, 0))

## Şehir modellerinin altındaki araziyi merkez yüksekliğine yumuşakça düzleştir
## (engebeli arazide binalar tepelere gömülmesin).
func _flatten_under_cities() -> void:
	var k := float(_height_image.get_width()) / map_size.x
	for c: City in World.cities:
		var r := CityLayer3D.footprint_radius(c) * k * 1.15
		_flatten_disc(c.position * k, r, r * 2.2, FLATTEN_STRENGTH)

## Yakın zoom detay dokuları: 7 katman albedo + normal -> Texture2DArray
func _setup_detail_textures() -> void:
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DETAIL_DIR + "layers.json"))
	var albedo: Array[Image] = []
	var normal: Array[Image] = []
	var avg := PackedVector3Array()
	for i in info["layers"].size():
		var name: String = info["layers"][i]
		var a := Image.load_from_file(DETAIL_DIR + name + "_albedo.png")
		a.generate_mipmaps()
		albedo.append(a)
		var n := Image.load_from_file(DETAIL_DIR + name + "_normal.png")
		n.generate_mipmaps()
		normal.append(n)
		var c: Array = info["avg"][i]
		avg.append(Vector3(c[0], c[1], c[2]))
	var ta := Texture2DArray.new()
	ta.create_from_images(albedo)
	var tn := Texture2DArray.new()
	tn.create_from_images(normal)
	_material.set_shader_parameter("detail_albedo", ta)
	_material.set_shader_parameter("detail_normal", tn)
	_material.set_shader_parameter("detail_avg", avg)
	_material.set_shader_parameter("biome_tex", ImageTexture.create_from_image(Image.load_from_file(BIOME_PATH)))

var _cloud_material: ShaderMaterial

func _setup_clouds() -> void:
	_cloud_material = ShaderMaterial.new()
	_cloud_material.shader = CLOUD_SHADER
	var plane := PlaneMesh.new()
	plane.size = map_size * 1.3
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = _cloud_material
	mi.position = Vector3(map_size.x / 2, CLOUD_HEIGHT, map_size.y / 2)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

## Kamera mesafesine göre bulut miktarı (yakında bulut yok, stratejik zoom'da var)
## Mevsim: kış şiddeti (ay ortası değerleri arasında gün gün geçiş); kuzey ve güney yarıküre ters
const WINTER_BY_MONTH := [1.0, 0.9, 0.45, 0.05, 0.0, 0.0, 0.0, 0.0, 0.0, 0.1, 0.45, 0.85]
func update_season() -> void:
	var m := GameClock.month - 1
	var f := clampf((float(GameClock.day) - 15.0) / 30.0, -0.5, 0.5)
	var a: float = WINTER_BY_MONTH[m]
	var b: float = WINTER_BY_MONTH[(m + (1 if f >= 0.0 else 11)) % 12]
	var north := lerpf(a, b, absf(f))
	var ms := (m + 6) % 12
	var a2: float = WINTER_BY_MONTH[ms]
	var b2: float = WINTER_BY_MONTH[(ms + (1 if f >= 0.0 else 11)) % 12]
	_material.set_shader_parameter("winter_north", north)
	_material.set_shader_parameter("winter_south", lerpf(a2, b2, absf(f)) * 0.7)

func set_camera_distance(d: float) -> void:
	# bulut yok: haritanın okunurluğunu bozuyor
	var a := 0.0
	_cloud_material.set_shader_parameter("cloud_amount", a)
	_material.set_shader_parameter("cloud_amount", a)

## Kamera ölçeği (ekran pikseli / dünya birimi) değişince ad katmanı yeniden çizilir.
func set_view_scale(_px_per_unit: float) -> void:
	pass

# ------------------------------------------------------------------ sorgular
func province_at(world_xz: Vector2) -> int:
	if World.wraps:
		world_xz.x = fposmod(world_xz.x, map_size.x)
	var p := Vector2i(world_xz.floor())
	if p.x < 0 or p.y < 0 or p.x >= _province_image.get_width() or p.y >= _province_image.get_height():
		return 0
	var c := _province_image.get_pixelv(p)
	if _province_image.get_format() == Image.FORMAT_LA8:
		return c.r8 + c.a8 * 256
	return c.r8 + c.g8 * 256 + c.b8 * 65536

## Dünya koordinatında (x, z) arazi yüksekliği (dünya birimi), çift doğrusal
func height_at(world_xz: Vector2) -> float:
	if World.wraps:
		world_xz.x = fposmod(world_xz.x, map_size.x)
	var hs := Vector2(_height_image.get_size())
	var p := (world_xz / map_size * hs - Vector2(0.5, 0.5)).clamp(Vector2.ZERO, hs - Vector2(1.001, 1.001))
	var i := Vector2i(p.floor())
	var f := p - Vector2(i)
	var h00 := _height_image.get_pixel(i.x, i.y).r
	var h10 := _height_image.get_pixel(i.x + 1, i.y).r
	var h01 := _height_image.get_pixel(i.x, i.y + 1).r
	var h11 := _height_image.get_pixel(i.x + 1, i.y + 1).r
	return lerpf(lerpf(h00, h10, f.x), lerpf(h01, h11, f.x), f.y) * HEIGHT_SCALE

func set_hovered(id: int) -> void:
	if id != hovered_province:
		hovered_province = id
		_material.set_shader_parameter("hovered_province", id)

var _mark_texture: ImageTexture

## Eyalet işaretleri (inşaat uygunluğu gibi): sid -> true/false; boş sözlük kapatır
func set_marked_states(marks: Dictionary) -> void:
	if marks.is_empty():
		_material.set_shader_parameter("marks_enabled", false)
		return
	var count := World.provinces.size()
	var rows := int(ceil(count / 256.0))
	var bytes := PackedByteArray()
	bytes.resize(256 * rows)
	for p: Province in World.provinces:
		if p and p.state_id > 0 and marks.has(p.state_id):
			bytes[p.id] = 255 if marks[p.state_id] else 128
	var img := Image.create_from_data(256, rows, false, Image.FORMAT_R8, bytes)
	if _mark_texture == null:
		_mark_texture = ImageTexture.create_from_image(img)
		_material.set_shader_parameter("mark_tex", _mark_texture)
	else:
		_mark_texture.update(img)
	_material.set_shader_parameter("marks_enabled", true)

func set_highlight_country(tag: String) -> void:
	var c: Country = World.countries.get(tag)
	_material.set_shader_parameter("highlight_country", c.index if c else 0)

func set_map_mode(mode: MapMode) -> void:
	map_mode = mode
	_material.set_shader_parameter("map_mode", int(mode))

# ------------------------------------------------------------------ veri dokuları
func rebuild_palette() -> void:
	var img := Image.create(256, 1, false, Image.FORMAT_RGBA8)
	for i in range(1, World.country_by_index.size()):
		img.set_pixel(i, 0, World.country_by_index[i].color)
	if _palette_texture == null:
		_palette_texture = ImageTexture.create_from_image(img)
		_material.set_shader_parameter("palette_tex", _palette_texture)
	else:
		_palette_texture.update(img)

func rebuild_province_data() -> void:
	var count := World.provinces.size()
	var rows := int(ceil(count / 256.0))
	var bytes := PackedByteArray()
	bytes.resize(256 * rows * 4)
	for p: Province in World.provinces:
		if p == null or p.state_id == 0:
			continue
		var st: StateRegion = World.states.get(p.state_id)
		if st == null:
			continue
		var i := p.id * 4
		bytes[i] = World.countries[st.owner].index
		bytes[i + 1] = World.controller[p.id]
		bytes[i + 2] = st.id & 255
		bytes[i + 3] = (st.id >> 8) & 255
	var img := Image.create_from_data(256, rows, false, Image.FORMAT_RGBA8, bytes)
	if _data_texture == null or _data_texture.get_height() != rows:
		_data_texture = ImageTexture.create_from_image(img)
		_material.set_shader_parameter("data_tex", _data_texture)
	else:
		_data_texture.update(img)

func _on_selection_changed(id: int) -> void:
	var p := World.province(id)
	_material.set_shader_parameter("selected_province", id)
	_material.set_shader_parameter("selected_state", p.state_id if p else 0)

func _update_player() -> void:
	var c := World.player()
	_material.set_shader_parameter("player_country", c.index if c else 0)
