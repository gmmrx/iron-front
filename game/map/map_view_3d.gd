class_name MapView3D
extends Node3D
## Düz harita zemini + ayrıntılı boyalı arazi; modeller ve yapılar ayrı 3D katmanlarda kalır.
## Ham yükseklik yalnız yüzeydeki dağ gölgesi, biyom ve kar için; model yerleşimi daima y=0.

enum MapMode { POLITICAL, TERRAIN, STATES, ROUTES }

const TERRAIN_PATH := "res://data/map/terrain.png"
const PROVINCES_PATH := "res://data/map/provinces.png"
const BORDERS_PATH := "res://data/map/borders.png"
const HEIGHT_PATH := "res://data/map/heightmap.r32"
const WATER_PATH := "res://data/map/water.png"
const BIOME_PATH := "res://data/map/biome.png"
const DETAIL_DIR := "res://assets/terrain/"
const AMBIENT_CLOUDS := preload("res://game/map/ambient_clouds.gd")
const SHADER := preload("res://assets/shaders/map3d.gdshader")
const HEIGHT_SCALE := 0.0          ## gerçek zemin: CPU, yol ve yapı shader'larında düz
const RELIEF_SCALE := 0.012        ## yalnız boyalı dağ/eğim gölgesi; geometriyi etkilemez
const CHUNK := 1024.0               ## harita ağı parça boyu (piksel)
const TERRAIN_GRID := preload("res://game/map/terrain_grid.gd")
const VERTEX_SPACING := CHUNK        ## düz zeminde yoğun yükseklik ızgarası yok
const WRAP_COLUMNS := 9              ## sarmalama için öbür kenara kopyalanan parça sütunu (en uzak zoom'un yarım genişliği)
const LABEL_SCALE := 0.5

var map_mode: MapMode = MapMode.POLITICAL
var harbors := {}                     ## liman bölge id -> [liman modeli kıyı noktası, denize bakan yön] (şehir katmanı doldurur)
var hovered_province := 0
var map_size := Vector2.ZERO

var _province_image: Image
var _height_image: Image
var _material: ShaderMaterial
var height_texture: ImageTexture
var _height_dirty := false
var border_texture: ImageTexture
var airbase_sites: Dictionary = {}     ## eyalet id -> [konum (Vector2), yön (float)]

const AIRBASE_RADIUS := 12.5           ## büyütülmüş pist için tamamen düzleştirilen yarıçap
var _data_texture: ImageTexture
var _province_texture: ImageTexture
var rim: CountryRim                    ## ülke sınırına yakınlık alanı (siyasi haritada renk sınıra doğru koyulaşır)
var _palette_texture: ImageTexture
var _province_la := false            ## bölge kimliği L + A*256 olarak kodlu (RGBA8'e çevrilse de)
var labels: CountryLabels3D
var terrain_texture: Texture2D           ## arazi rengi (dünya saati küresi de kullanır)
var _terrain_grid := TERRAIN_GRID.new()
## Şehir açıklıkları terrain_tex'in kullanılmayan alfasında: 1 doğal arazi, 0 temiz parsel.
## Ek harita sampler'ı yok; ham RF yükseklik ve arazi RGB'si hiç değiştirilmez.
var _city_sites: Dictionary = {}          ## city id -> [görsel merkez, dünya biriminde çekirdek yarıçapı]
var _city_site_pixels: Dictionary = {}    ## önceki commit'te değiştirilen alfa texelleri
var _city_sites_dirty := false
var _city_terrain_image: Image           ## ilk toplu commit'e kadar; sonra CPU kopyası bırakılır
const CITY_SITE_FEATHER := 1.4

## Açılış yükleme ekranı (main): kurulum adımları arasında bir kare çizilir (yükleme çubuğu ilerler); on_progress 0..1.
## Kapalıyken (testler, araçlar) kurulum tek seferde biter. Bitince built.
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
	var terrain := Image.load_from_file(TERRAIN_PATH)
	await _boot_step(0.2)
	terrain.convert(Image.FORMAT_RGBA8)       # mevcut RGB korunur, başlangıç alfası 1
	_city_terrain_image = terrain
	terrain.generate_mipmaps()
	await _boot_step(0.3)
	_province_image = Image.load_from_file(PROVINCES_PATH)
	_province_la = _province_image.get_format() == Image.FORMAT_LA8
	if _province_la and UnitModels.COMPAT:
		_province_image.convert(Image.FORMAT_RGBA8)   # GLES3/WebGL2'de LA8 yok; R=L, A=A korunur, çözümleme (R + A*256) aynı kalır
	var borders := Image.load_from_file(BORDERS_PATH)
	map_size = Vector2(_province_image.get_size())
	await _boot_step(0.45)
	_height_image = _load_heightmap()
	await _boot_step(0.55)
	for st: StateRegion in World.states.values():
		if st.building_level("air_base") > 0:
			_place_airbase(st)

	_material = ShaderMaterial.new()
	_material.shader = SHADER
	UnitModels.compat_material(_material)
	terrain_texture = ImageTexture.create_from_image(terrain)
	_material.set_shader_parameter("terrain_tex", terrain_texture)
	height_texture = ImageTexture.create_from_image(_height_image)
	_material.set_shader_parameter("height_tex", height_texture)
	_province_texture = ImageTexture.create_from_image(_province_image)
	_material.set_shader_parameter("province_tex", _province_texture)
	border_texture = ImageTexture.create_from_image(borders)
	_material.set_shader_parameter("border_tex", border_texture)
	await _boot_step(0.7)
	var water := Image.load_from_file(WATER_PATH)
	water.generate_mipmaps()
	_material.set_shader_parameter("water_tex", ImageTexture.create_from_image(water))
	_setup_detail_textures()
	await _boot_step(0.8)
	_material.set_shader_parameter("map_size", map_size)
	_material.set_shader_parameter("proj_miller", World._miller)
	_material.set_shader_parameter("wrap_x", World.wraps)
	_material.set_shader_parameter("proj_y_top", World._y_top)
	_material.set_shader_parameter("proj_px_per_rad", World._px_per_rad)
	_material.set_shader_parameter("proj_lon_min", World._lon_min)
	_material.set_shader_parameter("relief_scale", RELIEF_SCALE)

	# harita ağı parçalara bölünür: kameranın görmediği parçalar çizilmez (dünya haritası çok büyük)
	var nx := ceili(map_size.x / CHUNK)
	var ny := ceili(map_size.y / CHUNK)
	for cy in ny:
		for cx in nx:
			var w := minf(CHUNK, map_size.x - cx * CHUNK)
			var h := minf(CHUNK, map_size.y - cy * CHUNK)
			var plane: PlaneMesh = _terrain_grid.flat_mesh(Vector2(w, h))
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

	await _boot_step(0.9)
	_setup_clouds()
	labels = CountryLabels3D.new()
	labels.map = self
	rebuild_palette()
	rebuild_province_data()
	rim = CountryRim.new()
	add_child(rim)
	rim.setup(_province_texture, _data_texture, map_size, World.wraps)
	_material.set_shader_parameter("rim_tex", rim.texture)
	World.ownership_changed.connect(rebuild_province_data)
	World.control_changed.connect(rebuild_province_data)
	World.ownership_changed.connect(func() -> void: rim.refresh())   # veri dokusu yenilendikten sonra (bağlantı sırası)
	World.control_changed.connect(func(_a: Variant = null, _b: Variant = null) -> void: rim.refresh())  # sınır cepheyle kayar
	World.selection_changed.connect(_on_selection_changed)
	World.player_changed.connect(func(_t: String) -> void: _update_player())
	_update_player()
	is_built = true
	built.emit()

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
	return true

func _place_airbase(st: StateRegion) -> bool:
	var city := st.largest_city()
	var base := city.position if city else st.center
	var r0 := (CityLayer3D.footprint_radius(city) if city else 0.0) + 16.0
	# yakındaki şehirler: pist bunların modeline taşmasın
	_near_cities.clear()
	for c: City in World.cities:
		if c.position.distance_squared_to(base) < 200.0 * 200.0:
			_near_cities.append(c)
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
	return true

var _near_cities: Array[City] = []

## Uygun değilse null; aksi halde yükseklik farkı (düz = küçük)
func _site_score(p: Vector2, sid: int) -> Variant:
	for c: City in _near_cities:
		var gap := CityLayer3D.footprint_radius(c) + AIRBASE_RADIUS + 3.0
		if c.position.distance_squared_to(p) < gap * gap:
			return null
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

## Düz zeminde parsel düzleştirme gerekmez; ham yükselti boyalı araziyi besler.
func _flatten_disc(_center: Vector2, _r: float, _outer: float, _strength: float) -> void:
	pass

## Yapı katmanlarının mevcut sözleşmesi korunur; dağ/orman dokusunu silmez.
func flatten_site(_p: Vector2, _radius: float) -> void:
	pass

func commit_height() -> void:
	pass

## Modelin sabit dünya ölçeğindeki parseli. Oyun verisi değil, görsel merkez kullanılır.
## radius tamamen temiz çekirdek; kenar 0.4× radius (en az bir arazi texeli) boyunca yumuşar.
func register_city_site(city_id: int, center: Vector2, radius: float) -> void:
	if not center.is_finite() or not is_finite(radius) or radius <= 0.0:
		return
	var site: Array = [center, radius]
	if _city_sites.get(city_id) == site:
		return
	_city_sites[city_id] = site
	_city_sites_dirty = true

func unregister_city_site(city_id: int) -> void:
	if _city_sites.erase(city_id):
		_city_sites_dirty = true

## Şehir kurulumunun sonunda bir defa çağrılır; her şehir için büyük doku yüklemesi yapılmaz.
func commit_city_sites() -> void:
	if not _city_sites_dirty or terrain_texture == null or map_size.x <= 0.0 or map_size.y <= 0.0:
		return
	var tex := terrain_texture as ImageTexture
	if tex == null:
		return
	var image := _city_terrain_image if _city_terrain_image != null else tex.get_image()
	image.clear_mipmaps()
	image.convert(Image.FORMAT_RGBA8)
	# Taşınan/silinen parselin eski açıklığını kaldır, sonra bütün siteleri üst üste damgala.
	for p: Vector2i in _city_site_pixels:
		var c := image.get_pixelv(p)
		c.a = 1.0
		image.set_pixelv(p, c)
	_city_site_pixels.clear()
	for site: Array in _city_sites.values():
		_stamp_city_site(image, site[0], site[1])
	image.generate_mipmaps()
	_upload_city_site_image(image)
	_city_terrain_image = null              # tam haritanın kalıcı CPU kopyasına gerek yok
	_city_sites_dirty = false

func _upload_city_site_image(image: Image) -> void:
	var tex := terrain_texture as ImageTexture
	if tex.get_format() == Image.FORMAT_RGBA8:
		tex.update(image)
	else:
		tex.set_image(image)

func _city_site_is_land(p: Vector2) -> bool:
	var pr := World.province(province_at(p))
	return pr != null and pr.is_land()

func _stamp_city_site(image: Image, center: Vector2, radius: float) -> void:
	var size := image.get_size()
	var texels := Vector2(size) / map_size
	# Arazi resmi province resminden küçük olabilir; halka en az bir texel kadar yumuşasın.
	var outer := radius + maxf(radius * (CITY_SITE_FEATHER - 1.0), 1.0 / minf(texels.x, texels.y))
	var lo := Vector2i(((center - Vector2.ONE * outer) * texels - Vector2.ONE * 0.5).floor())
	var hi := Vector2i(((center + Vector2.ONE * outer) * texels - Vector2.ONE * 0.5).ceil())
	for y in range(maxi(0, lo.y), mini(size.y - 1, hi.y) + 1):
		for x in range(lo.x, hi.x + 1):
			if not World.wraps and (x < 0 or x >= size.x):
				continue
			var wp := (Vector2(x, y) + Vector2.ONE * 0.5) / texels
			var distance := wp.distance_to(center)
			if distance >= outer or not _city_site_is_land(wp):
				continue
			var p := Vector2i(posmod(x, size.x) if World.wraps else x, y)
			var c := image.get_pixelv(p)
			c.a = minf(c.a, smoothstep(radius, outer, distance))
			image.set_pixelv(p, c)
			_city_site_pixels[p] = true

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
		if not UnitModels.COMPAT:
			var n := Image.load_from_file(DETAIL_DIR + name + "_normal.png")
			n.generate_mipmaps()
			normal.append(n)
		var c: Array = info["avg"][i]
		avg.append(Vector3(c[0], c[1], c[2]))
	var ta := Texture2DArray.new()
	ta.create_from_images(albedo)
	_material.set_shader_parameter("detail_albedo", ta)
	if not UnitModels.COMPAT:
		var tn := Texture2DArray.new()
		tn.create_from_images(normal)
		_material.set_shader_parameter("detail_normal", tn)
	_material.set_shader_parameter("detail_avg", avg)
	_material.set_shader_parameter("biome_tex", ImageTexture.create_from_image(Image.load_from_file(BIOME_PATH)))

var _cloud_material: ShaderMaterial
var _cloud_mesh: Node3D

func _setup_clouds() -> void:
	_cloud_mesh = AMBIENT_CLOUDS.new()
	_cloud_mesh.setup(map_size, World.wraps)
	_cloud_material = _cloud_mesh.material
	add_child(_cloud_mesh)

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

## Gece ve gündüz (DayNight): güneşin tepede olduğu nokta (boylam, enlem; derece), gecenin gücü (0 kapalı) ve 3D
## ışığın o anki kısılma katı (harita bunu geri alır: zemin her noktada kendi saatinde)
func set_day_night(subsolar: Vector2, strength: float, light: float) -> void:
	_material.set_shader_parameter("sun_lonlat", subsolar)
	_material.set_shader_parameter("night_strength", strength)
	_material.set_shader_parameter("light_comp", light)
	if _cloud_material and World._miller:
		_cloud_material.set_shader_parameter("sun_lonlat", subsolar)
		_cloud_material.set_shader_parameter("night_strength", strength)
		if not _cloud_material.has_meta("proj"):
			_cloud_material.set_meta("proj", true)
			_cloud_material.set_shader_parameter("map_size", map_size)
			_cloud_material.set_shader_parameter("proj_lon_min", World._lon_min)
			_cloud_material.set_shader_parameter("proj_y_top", World._y_top)
			_cloud_material.set_shader_parameter("proj_px_per_rad", World._px_per_rad)

func terrain_spacing() -> float:
	return CHUNK

func set_camera_distance(d: float) -> void:
	_cloud_mesh.set_camera_distance(d)
	# Sparse cards already carry light/shade. No full-map procedural shadow field.
	_material.set_shader_parameter("cloud_amount", 0.0)

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
	if _province_la:
		return c.r8 + c.a8 * 256
	return c.r8 + c.g8 * 256 + c.b8 * 65536

## Görsel kabartmadan bağımsız ortak zemin: modeller, oklar ve tıklama aynı düzlemi kullanır.
func height_at(_world_xz: Vector2) -> float:
	return 0.0

func set_hovered(id: int) -> void:
	if id != hovered_province:
		hovered_province = id
		_material.set_shader_parameter("hovered_province", id)

var _mark_texture: ImageTexture
var _recon_texture: ImageTexture

func set_recon_targets(targets: Dictionary) -> void:
	_material.set_shader_parameter("recon_enabled", not targets.is_empty())
	if targets.is_empty(): return
	var rows := ceili(World.provinces.size() / 256.0)
	var bytes := PackedByteArray()
	bytes.resize(256 * rows)
	for pid: int in targets:
		if pid > 0 and pid < bytes.size(): bytes[pid] = 255
	var img := Image.create_from_data(256, rows, false, Image.FORMAT_R8, bytes)
	if _recon_texture == null:
		_recon_texture = ImageTexture.create_from_image(img)
		_material.set_shader_parameter("recon_tex", _recon_texture)
	else:
		_recon_texture.update(img)
var _fog_texture: ImageTexture
var _fog_version := -1

## Savaş sisi: keşfedilmemiş yerde hacimli bulut ve nötr sis tabanı (CloudFog). Bölge başına sis
## düzeyi (Military.fog_levels: 0 bulut, 2 keşfedilmiş) dokuya yazılır, CloudFog ondan bulut maskesini çizer.
var _fog_volume: CloudFog

func _ensure_fog_volume() -> void:
	if _fog_volume == null:
		_fog_volume = CloudFog.new()
		add_child(_fog_volume)
		_fog_volume.setup(_province_texture, map_size, World.wraps)

## Bulutun tek seferlik kurulumu (maske, 3B gürültü) ve ilk çizimi yükleme ekranında (oyun başında takılmasın)
func prewarm_fog() -> void:
	_ensure_fog_volume()
	_fog_volume.prewarm(3)

## Bulut ve sis rengi sıfırdan yavaşça belirir (oyun başında, geçiş animasyonları bittikten sonra)
var _fog_tween: Tween
func fade_fog_in(secs: float) -> void:
	_ensure_fog_volume()
	if _fog_tween:
		_fog_tween.kill()
	_fog_volume.set_fade(0.0)                   # hemen: bulut görünür olduğu ilk karede tam yoğun belirmesin
	_material.set_shader_parameter("fog_fade", 0.0)
	_fog_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_fog_tween.tween_method(func(f: float) -> void:
		_fog_volume.set_fade(f)
		_material.set_shader_parameter("fog_fade", f), 0.0, 1.0, secs)

func set_fog(levels: PackedByteArray, version: int) -> void:
	_ensure_fog_volume()
	if levels.is_empty():
		_fog_volume.clear()
		_material.set_shader_parameter("fog_enabled", false)
		_fog_version = -1
		return
	if version == _fog_version:
		return
	_fog_version = version
	var rows := int(ceil(levels.size() / 256.0))
	var bytes := PackedByteArray()
	bytes.resize(256 * rows)
	for i in levels.size():
		bytes[i] = 255 if levels[i] > 0 else 0
	var img := Image.create_from_data(256, rows, false, Image.FORMAT_R8, bytes)
	if _fog_texture == null or _fog_texture.get_height() != rows:
		_fog_texture = ImageTexture.create_from_image(img)
	else:
		_fog_texture.update(img)
	_fog_volume.set_fog(_fog_texture)
	_material.set_shader_parameter("fog_mask", _fog_volume.mask_texture())
	_material.set_shader_parameter("fog_enabled", true)

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

## Bölge işaretleri (yürüme menzili gibi): pid -> 0..255 (200-255 yeşil, değer büyüdükçe parlak); rest > 0: öbür
## bölgeler bu değerde (128 = karart). Boş sözlük kapatır.
func set_marked_provinces(vals: Dictionary, rest: int = 128) -> void:
	if vals.is_empty():
		_material.set_shader_parameter("marks_enabled", false)
		return
	var count := World.provinces.size()
	var rows := int(ceil(count / 256.0))
	var bytes := PackedByteArray()
	bytes.resize(256 * rows)
	bytes.fill(rest)
	for pid: int in vals:
		if pid >= 0 and pid < bytes.size():
			bytes[pid] = clampi(int(vals[pid]), 0, 255)
	var img := Image.create_from_data(256, rows, false, Image.FORMAT_R8, bytes)
	if _mark_texture == null:
		_mark_texture = ImageTexture.create_from_image(img)
		_material.set_shader_parameter("mark_tex", _mark_texture)
	else:
		_mark_texture.update(img)
	_material.set_shader_parameter("marks_enabled", true)

## Ülke seçimi vurgusu: öbür yerler kararır, sınırı neon yanar. animate: yumuşak geçiş — ilk seçimde karartma girer;
## ülke değişince karartma olduğu gibi kalır, eski ülkenin ışığı söner, yenisininki yanar (vurgu sıfırdan başlayınca
## bütün harita bir an aydınlanıp yeniden kararıyordu: flaş)
var _hl_tween: Tween
var _hl_idx := 0                       ## seçili ülkenin indeksi
var _hl := Vector3(1.0, 0.0, 1.0)      ## seçilinin ışığı, öncekinin ışığı, karartma (gölgelendiriciye giden değerler)
func set_highlight_country(tag: String, animate := false) -> void:
	var c: Country = World.countries.get(tag)
	var idx := c.index if c else 0
	if _hl_tween:
		_hl_tween.kill()
	if not animate or idx == 0:
		_hl_idx = idx
		_material.set_shader_parameter("highlight_country", idx)
		_material.set_shader_parameter("highlight_prev", 0)
		_set_hl(Vector3(1.0, 0.0, 1.0 if idx > 0 else 0.0))
		return
	var from := _hl
	var prev := 0
	var prev_lit := 0.0
	if _hl_idx > 0 and _hl_idx != idx:
		prev = _hl_idx
		prev_lit = from.x
	elif _hl_idx == 0:
		from = Vector3(0.0, 0.0, 0.0)          # ilk seçim: karartma da yumuşakça girer
	_hl_idx = idx
	_material.set_shader_parameter("highlight_country", idx)
	_material.set_shader_parameter("highlight_prev", prev)
	var d0 := from.z
	_hl_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_hl_tween.tween_method(func(t: float) -> void: _set_hl(Vector3(t, prev_lit * (1.0 - t), lerpf(d0, 1.0, t))), 0.0, 1.0, 0.6)
	_hl_tween.tween_callback(func() -> void: _material.set_shader_parameter("highlight_prev", 0))

func _set_hl(v: Vector3) -> void:
	_hl = v
	_material.set_shader_parameter("highlight_fade", v.x)
	_material.set_shader_parameter("prev_fade", v.y)
	_material.set_shader_parameter("dim_amount", v.z)

## Vurgunun sönmesi (oyun başlarken): karartma ve neon yavaşça kalkar, sonra vurgu silinir
func fade_highlight(secs: float) -> void:
	if _hl_tween:
		_hl_tween.kill()
	var from := _hl
	_hl_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_hl_tween.tween_method(func(t: float) -> void: _set_hl(from * t), 1.0, 0.0, secs)
	_hl_tween.tween_callback(func() -> void:
		_hl_idx = 0
		_material.set_shader_parameter("highlight_country", 0)
		_material.set_shader_parameter("highlight_prev", 0))

func set_map_mode(mode: MapMode) -> void:
	map_mode = mode
	_material.set_shader_parameter("map_mode", int(mode))

# ------------------------------------------------------------------ veri dokuları
## Ülke renginin siyasi haritadaki tonu (algısal OKHSL uzayında): açıklık 0,55..0,78 aralığına sıkıştırılır — koyu ülke
## kararıp sınırı ve adı yutmasın, çok açık ülke kâğıt beyazına kaçmasın; sıra korunur (koyu ülke yine komşusundan
## koyu). Doygunluk 0,25..0,62 aralığına çekilir: soluk ülke canlanır, çok doygun ülke (kırmızı, yeşil) büyük alanda göz
## yormasın; gri ülke gri kalır (doygunluğu 0,12'nin altındakine dokunulmaz). Ton (renk açısı) hiç değişmez.
const TONE_L := Vector2(0.55, 0.78)        ## haritadaki açıklık aralığı
const TONE_L_IN := Vector2(0.3, 0.9)       ## veri renklerinin açıklık aralığı (bunun dışı uçlara sıkışır)
const TONE_S := Vector2(0.25, 0.62)        ## haritadaki doygunluk aralığı
static func map_tone(c: Color) -> Color:
	var t := clampf((c.ok_hsl_l - TONE_L_IN.x) / (TONE_L_IN.y - TONE_L_IN.x), 0.0, 1.0)
	var l := lerpf(TONE_L.x, TONE_L.y, t)
	var sat := c.ok_hsl_s
	if sat >= 0.12:
		sat = clampf(sat, TONE_S.x, TONE_S.y)
	return Color.from_ok_hsl(c.ok_hsl_h, sat, l, c.a)

func rebuild_palette() -> void:
	var img := Image.create(256, 1, false, Image.FORMAT_RGBA8)
	for i in range(1, World.country_by_index.size()):
		img.set_pixel(i, 0, map_tone(World.country_by_index[i].color))
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
		if rim:
			rim.set_data_texture(_data_texture)
	else:
		_data_texture.update(img)

func _on_selection_changed(id: int) -> void:
	var p := World.province(id)
	_material.set_shader_parameter("selected_province", id)
	_material.set_shader_parameter("selected_state", p.state_id if p else 0)

func _update_player() -> void:
	var c := World.player()
	_material.set_shader_parameter("player_country", c.index if c else 0)
