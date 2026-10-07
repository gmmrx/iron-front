class_name PinLayer
extends Node3D
## İğne haritası (haritanın tasarımı): şehir, sanayi, asker ve gemi modelleri yerine haritaya saplanmış iğneler; uçaklar
## tek küçük modelle (AirLayer).
## Şehir: sabit dünya ölçüsünde küçük yerleşim modeli ve bağımsız, normal harita yazısı. Tümen, filo ve hava kanadı:
## sayacı bayrak gibi taşıyan iğne. Yapılar (fabrika, tersane, rafineri, uçaksavar, demiryolu deposu, deniz ve hava üssü):
## ucunda yapının resmi ve seviyesi olan iğne, eyalet ve tür başına bir tane; süren inşaat turuncu çerçeve ve "+n". Ekranda sabit boy: iğneler kamera uzaklığıyla ölçeklenir (shader), uzakta kaybolmaz,
## yakında devleşmez. Yalnız görünüm değişir; oyun mantığı, seçim ve paneller aynıdır.

const SHADER := preload("res://assets/shaders/pin.gdshader")
const MINI_CITY_MODELS := preload("res://game/map/mini_city_models.gd")
const CITY_GROUND := preload("res://game/map/city_ground.gd")
const NEEDLE_R := 0.0033                                               ## gövde yarıçapı (kamera uzaklığı katı)
const CITY_LEN: Array[float] = [0.098, 0.082, 0.071, 0.062, 0.055]     ## şehir önem kademesi 0..4 (CityLayer.tier_of)
const CITY_HEAD: Array[float] = [0.010, 0.0135, 0.0115, 0.01, 0.0088]
const UNIT_LIFT := 0.058                                               ## tümen sayacının yerden yüksekliği
const AIR_LIFT := 0.072
const SEA_LIFT := 0.05

static func active() -> bool:
	return World.in_game

## Sayaç yüksekliği (iğnenin boyu): kamera uzaklığının katı → ekranda sabit. Uzakta (sayaç yerine yalnız bayrak,
## UnitLayer.FLAG_MODE) iğne yok: bayrak haritanın hemen üstünde durur.
static func lift(cam_d: float, k: float = UNIT_LIFT) -> float:
	return cam_d * (FLAG_LIFT if flags_only(cam_d) else k)

const FLAG_LIFT := 0.006
static func flags_only(cam_d: float) -> bool:
	return cam_d > UnitLayer.FLAG_MODE

var map: MapView3D
var camera: MapCamera3D
var cities: CityLayer3D
var units: UnitLayer
var fleets: FleetLayer
var air: AirLayer

var _city_needles: MultiMeshInstance3D
var _heads: MultiMeshInstance3D
var _counter_needles: MultiMeshInstance3D
var _build_needles: MultiMeshInstance3D
var _bpins: Array = []               ## yapı iğneleri: [kök Node3D, konum Vector2, zemin, rozetler [tür, yazı, inşaat mı], rozet düğümleri]
var _build_sig := -1
var _bstate := {}                    ## anahtar ("sid" / "air:sid") -> [imza, iğne kaydı] — yalnız değişen eyalet yenilenir
var _build_timer := 0.0
var _hover_key := ""                 ## fare altındaki rozet: "anahtar#sıra"
var _badge_k := 1.0                  ## uzaklığa göre rozet boyu (FAR_BADGE..1)
var _plates := {}
var _needle_mat: ShaderMaterial
var _head_mat: ShaderMaterial
var _ground: PackedFloat32Array = []
var _on := false
var _colors_dirty := true
var _last_label_d := -1.0
var _recheck := 0.0

const BUILD_LIFT := 0.045                                             ## yapı iğnesinin boyu
const BUILD_RANGE := 260.0                                            ## yapı rozetleri bu uzaklığın içinde (önce ikon)
const BUILD_PIN_RANGE := 170.0                                        ## iğne bu kadar yakında yerden yükselir
## Yapı iğnelerinin boyu eyaletten eyalete farklı (BUILD_LIFT'in bu katları): komşu eyaletlerin rozetleri üst üste
## binmez, hepsi görülür
const BUILD_LIFT_STEPS: Array[float] = [0.7, 1.0, 1.35, 1.7]
const HOVER_SCALE := 1.3                                              ## fare altındaki rozet büyür
const FAR_BADGE := 0.72                                               ## rozetin en uzaktaki boyu (iğne çıkınca tam boy)
## iğnesi olan yapılar (altyapı her eyalette olduğundan iğnesi yok: haritayı doldururdu; bölge panelinde görünür)
const BUILDINGS := ["civilian_factory", "military_factory", "anti_air", "air_base"]
const PLATE_GOLD := Color("b8995a")
const PLATE_BUILD := Color("d0692f")
const GLYPH_GOLD := Color("e0c27a")                                   ## rozet piktogramı ve sayısı (koyu zeminde altın)
const TOWN_HEAD := Color("efe6cf")                                    ## kasaba iğnesinin başı (fildişi)
const MEDAL_PX := 46.0                                                ## başkent madalyonu ekran boyu
const TOWN_LABEL_UP := 36.0                                           ## kasaba adı iğne başının üstünde (etiket pikseli)
var _tops := {}                      ## iğne sırası -> iğnenin tepesindeki şehir ikonu (ya da başkent madalyonu)

## Şehir başına küçük yerleşim minyatürü: mimari stil ve şehir kimliğine göre ortak
## mesh seçilir; tüm yüzeylerin kendi dokuları korunur. Boy dünya biriminde sabit;
## zoom, odak, hover ve görünürlük değişimi geometriyi ölçeklemez.
## Yeni asset bulunamazsa önceki belediye binası, o da yoksa eski iğne/ikon kullanılır.
const CITY_MODEL := "res://assets/models/city-hall.glb"
const CITY_WORLD_WIDTH: Array[float] = [4.0, 3.5, 3.0, 2.6, 2.2] ## modelin sabit dünya eni, kademe 0..4
var _city_models = MINI_CITY_MODELS.new()
var _halls := {}                     ## iğne sırası -> şehir modeli
var _city_ground = CITY_GROUND.new()
var _city_sites := {}                ## same visibility as miniature, not enlarged by zoom
## Şehir ikonu iğnenin ucunda (assets/ui/city_pins/city_<stil>_<kademe>.png; docs/art/CITY_PIN_PROMPTS.md): stil
## west/east/orient/nordic, kademe şehrin önemine göre (CityLayer.tier_of). Stilin dosyası yoksa west, o da yoksa
## başkentte madalyon, öbürlerinde fildişi toplu iğne başı.
const TOP_TIERS := ["capital", "major", "city", "town", "village"]
const TOP_PX: Array[float] = [60.0, 52.0, 45.0, 38.0, 32.0]           ## ikonun ekran boyu (kademe)
const TOP_DIR := "res://assets/ui/city_pins/"
const CITY_ART_DIR := "res://assets/ui/city_pins/by_city/" ## şehir başına hazırlanmış görsel varsa tür/kademe ikonunu geçersiz kılar
static var _top_cache := {}
const FAR_Z := 60000.0                ## shader'ın uzaklıkla büyütmesi kapalı (boy işlemcide; web'de yarım duyarlılık sınırı altında)
var _anim_s := PackedFloat32Array()   ## şehir sırası -> görünürlük (0/1); geometri ölçeği değildir
var _packed := PackedFloat32Array()   ## iğne sırası -> paketli baş rengi
var _live := {}                       ## yakın görüşte görünen şehirler
var hovered_city := -1                ## farenin altındaki şehir iğnesi (sıra)
var _shadows: MultiMeshInstance3D     ## iğnenin haritaya battığı yerde yumuşak gölge noktası
var _medal_tex: Texture2D
var _glyphs := {}                    ## yapı -> altına çevrilmiş piktogram

## İğneler: [konum (Vector2), boy katı, baş katı, görünme uzaklığı, şehir (ya da null), sabit renk]
var _pins: Array = []

func _ready() -> void:
	_needle_mat = _material(false)
	_head_mat = _material(true)
	var needle := CylinderMesh.new()
	needle.top_radius = 1.0
	needle.bottom_radius = 1.0
	needle.height = 1.0
	needle.radial_segments = 12
	needle.rings = 1
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	ball.radial_segments = 14
	ball.rings = 8
	_city_needles = _mmi(needle, _needle_mat)
	_heads = _mmi(ball, _head_mat)
	_city_models.fallback_path = CITY_MODEL
	var dot := QuadMesh.new()
	dot.size = Vector2(1.0, 1.0)
	dot.orientation = PlaneMesh.FACE_Y
	var sm := ShaderMaterial.new()
	sm.shader = preload("res://assets/shaders/pin_shadow.gdshader")
	UnitModels.compat_material(sm)
	_shadows = _mmi(dot, sm)
	_shadows.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_counter_needles = _mmi(needle, _needle_mat)
	_rebuild()
	World.ownership_changed.connect(func() -> void: _colors_dirty = true)
	_build_needles = _mmi(needle, _needle_mat)
	visible = false

## Uzakta harita ikonu gösterilen şehir yakında iğne olur. İğneler geç gelir (harita uzun süre sade kalsın): başkent 820,
## 10+ puan 560, 3+ puan 420; ikonu olmayan kasaba 300 (ya da adının göründüğü uzaklık). Harita ikonlarının söndüğü
## uzaklık buna uydurulur (_sync_icon_ranges): ikon ile iğne arasında boşluk kalmaz.
const CITY_SWITCH := {1300: 285.0, 900: 195.0, 640: 145.0}     ## şehir iğneleri de yakın diorama görüşünde yükselir

## Her şehir yakında küçük minyatürle temsil edilir; uzak stratejik harita sade kalır.
static func has_pin(c: City) -> bool:
	return c != null

static func city_model_width(c: City) -> float:
	return CITY_WORLD_WIDTH[CityLayer.tier_of(c)]

static func city_range(c: City) -> float:
	if c.is_capital:
		return CITY_SWITCH[1300]
	if c.victory_points >= 10:
		return CITY_SWITCH[900]
	if c.victory_points >= 3:
		return CITY_SWITCH[640]
	return minf(CityLayer3D.LABEL_RANGE[CityLayer.tier_of(c)], 210.0)

## Harita ikonları (MapIconLayer) iğne gelene kadar kalsın: şehir ikonlarının sönme uzaklığı iğnenin geliş uzaklığına iner
func _sync_icon_ranges() -> void:
	if cities == null:
		return
	for layer: Node in cities.get_children():
		if not layer is MapIconLayer:
			continue
		for root: Node in layer.get_children():
			for g: Node in root.get_children():
				if not g is GeometryInstance3D:
					continue
				var gi := g as GeometryInstance3D
				var old := roundi(gi.visibility_range_begin)
				if CITY_SWITCH.has(old):
					gi.visibility_range_begin = CITY_SWITCH[old]
					gi.visibility_range_begin_margin = CITY_SWITCH[old] * 0.25

func _rebuild() -> void:
	_pins.clear()
	for c: City in World.cities:
		if not has_pin(c):
			continue
		var tier := CityLayer.tier_of(c)
		# Kıyıda model denize taşmasın. Oyun mantığındaki City.position değişmez;
		# model, yakın etiketi ve fare seçimi aynı kara tarafındaki merkezi kullanır.
		var p: Vector2 = cities._visual_positions.get(c.id, c.position) if cities else c.position
		_pins.append([p, CITY_LEN[tier], CITY_HEAD[tier], city_range(c), c, Color.WHITE])
	_ground.resize(_pins.size())
	_anim_s.resize(_pins.size())
	_packed.resize(_pins.size())
	_anim_s.fill(0.0)
	_live.clear()
	hovered_city = -1
	var cmm := _city_needles.multimesh
	var hmm := _heads.multimesh
	var smm := _shadows.multimesh
	cmm.instance_count = _pins.size()
	hmm.instance_count = _pins.size()
	smm.instance_count = _pins.size()
	for i in _pins.size():
		var pin: Array = _pins[i]
		var p: Vector2 = pin[0]
		var g := maxf(map.height_at(p), 0.0)
		_ground[i] = g
		var xf := Transform3D(Basis(), Vector3(p.x, g, p.y))
		cmm.set_instance_transform(i, xf)
		cmm.set_instance_custom_data(i, Color(0.0, NEEDLE_R, FAR_Z, 0.0))
		cmm.set_instance_color(i, Color.WHITE)
		hmm.set_instance_transform(i, xf)
		smm.set_instance_transform(i, Transform3D(Basis(), Vector3(p.x, g + 0.05, p.y)))
		smm.set_instance_custom_data(i, Color(0.0, 0.0, FAR_Z, 0.0))
		smm.set_instance_color(i, Color.WHITE)
	for m: Sprite3D in _tops.values():
		m.queue_free()
	_tops.clear()
	for h: MeshInstance3D in _halls.values():
		h.queue_free()
	_halls.clear()
	for site: MeshInstance3D in _city_sites.values():
		site.queue_free()
	_city_sites.clear()
	_colors_dirty = true
	_last_label_d = -1.0

func _material(is_head: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("head", is_head)
	UnitModels.compat_material(m)
	return m

func _mmi(mesh: Mesh, mat: ShaderMaterial) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = mesh
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mi.custom_aabb = AABB(Vector3(-1e5, -100, -1e5), Vector3(2e5, 1e4, 2e5))
	add_child(mi)
	return mi

func _process(delta: float) -> void:
	var on := active()
	if on != _on:
		_on = on
		visible = on
		_set_models_hidden(on)
		if on:
			_sync_icon_ranges()
		_last_label_d = -1.0
		if not on:
			_restore_labels()
	if not on:
		return
	# sonradan eklenen modeller (yeni hava üssü) de gizli kalsın
	_recheck -= delta
	if _recheck <= 0.0:
		_recheck = 1.0
		_set_models_hidden(true)
	var d := camera.distance
	_needle_mat.set_shader_parameter("cam_dist", d)
	(_shadows.material_override as ShaderMaterial).set_shader_parameter("cam_dist", d)
	_head_mat.set_shader_parameter("cam_dist", d)
	if _colors_dirty:
		_colors_dirty = false
		_update_colors()
	# yapı iğneleri: en çok saniyede bir, yalnız görünürken (uzakta gizliler; yakına gelince güncellenir).
	# Yapay zekâ ülkeleri durmadan inşaat başlattığından her karede yenilemek 5× hızda kareyi yiyordu.
	var ind := cities.industry() if cities else null
	_build_timer -= delta
	var sig := (ind.version if ind else 0) * 4096 + map.airbase_sites.size() + Military.fog_version * 7919   # sis: bulutun altındaki yapılar
	if _build_sig < 0:
		_build_sig = sig                  # ilk kurulum tek seferde
		_rebuild_buildings(ind)
		_last_label_d = -1.0
	elif _rb_list.is_empty() and sig != _build_sig and _build_timer <= 0.0 and d < BUILD_RANGE * 1.1:
		# sonraki kurulumlar karelere yayılır: kare başına RB_CHUNK eyalet, değişiklikler sonda bir kez
		_build_sig = sig
		_build_timer = 1.0
		_rb_queued = _collect_queued()
		_rb_want = {}
		_rb_list = World.states.keys()
		_rb_i = 0
	if not _rb_list.is_empty():
		var __b := Time.get_ticks_usec()
		var end := mini(_rb_i + RB_CHUNK, _rb_list.size())
		for i in range(_rb_i, end):
			_want_state(int(_rb_list[i]), _rb_queued, ind, _rb_want)
		_rb_i = end
		if _rb_i >= _rb_list.size():
			_rb_list = []
			_apply_want(_rb_want)
			_last_label_d = -1.0
		GameClock.timed("pins_build", __b)
	if _last_label_d < 0.0 or absf(d - _last_label_d) > _last_label_d * 0.02:
		_last_label_d = d
		var __h := Time.get_ticks_usec()
		_update_building_heights(d)
		GameClock.timed("pins_heights", __h)
	var __a := Time.get_ticks_usec()
	_update_cities(d)
	GameClock.timed("pins_anim", __a)
	_update_counter_needles(d)

## Eski şehir/sanayi/hava üssü modelleri gizlenir; adlar, köprüler, fiziksel
## liman katmanı ve uzak şehir/hava ikonları kalır.
func _set_models_hidden(hidden: bool) -> void:
	if cities == null:
		return
	for ch: Node in cities.get_children():
		if ch is Label3D or ch is StraitLayer or ch is MapIconLayer or bool(ch.get_meta("map_landmark_layer", false)):
			continue
		if ch is Node3D:
			(ch as Node3D).visible = not hidden

## Baş rengi: şehri elinde tutan ülkenin rengi; liman ve hava üssü sabit renk (örnek verisinde paketli + örnek rengi)
func _update_colors() -> void:
	var hmm := _heads.multimesh
	for i in _pins.size():
		var pin: Array = _pins[i]
		var col: Color = pin[5]
		var c: City = pin[4]
		if c != null:
			col = TOWN_HEAD
		_packed[i] = float(col.r8 * 65536 + col.g8 * 256 + col.b8)
		hmm.set_instance_color(i, col)        # web (Compatibility) yolu
		_write_pin(i)

## Sabit şehir modelinin görünürlüğünü yaz; asset yoksa eski iğne/ikon yedeği.
## Şehir etiketlerinin stil/ölçek/konumuna bu katman dokunmaz.
func _write_pin(i: int) -> void:
	var pin: Array = _pins[i]
	var c: City = pin[4]
	var s := _anim_s[i]
	if c != null:
		var model: Dictionary = _city_models.model_for(c)
		if not model.is_empty():
			_write_hall(i, c, s, model)
			return
	var ln := float(pin[1]) * s
	var top_tex := _top_tex(c)
	var head := 0.0 if top_tex != null else float(pin[2]) * s        # ikonlu iğnede küre yok
	_city_needles.multimesh.set_instance_custom_data(i, Color(ln, NEEDLE_R * minf(s, 1.0), FAR_Z, 0.0))
	_heads.multimesh.set_instance_custom_data(i, Color(ln, head, FAR_Z, _packed[i]))
	_shadows.multimesh.set_instance_custom_data(i, Color(0.0, 0.009 * minf(s, 1.2), FAR_Z, 0.0))
	var d := camera.distance
	if top_tex == null:
		return
	var m: Sprite3D = _tops.get(i)
	if m == null:
		if s <= 0.001:
			return
		m = _sprite(top_tex, _top_px(c, top_tex), 6)
		# ikon iğnenin ucuna ortalı (toplu iğne başı gibi): iğne yuvarlağın ortasına girer, kamera açısıyla kaymaz
		m.offset = Vector2.ZERO
		var p2: Vector2 = pin[0]
		m.position = Vector3(p2.x, _ground[i], p2.y)
		add_child(m)
		_tops[i] = m
	m.visible = s > 0.001
	m.position.y = _ground[i] + d * s * float(pin[1])
	m.scale = Vector3.ONE * clampf(s, 0.001, 2.0)

## Şehir modeli: iğne, baş ve gölge noktası sıfır boyda; model sabit dünya ölçüsüyle zemine oturur.
func _write_hall(i: int, c: City, s: float, model: Dictionary) -> void:
	_city_needles.multimesh.set_instance_custom_data(i, Color(0.0, 0.0, FAR_Z, 0.0))
	_heads.multimesh.set_instance_custom_data(i, Color(0.0, 0.0, FAR_Z, _packed[i]))
	_shadows.multimesh.set_instance_custom_data(i, Color(0.0, 0.0, FAR_Z, 0.0))
	var size := city_model_width(c)
	var h: MeshInstance3D = _halls.get(i)
	if h == null:
		if s <= 0.001:
			return
		h = MeshInstance3D.new()
		h.mesh = model["mesh"] as Mesh
		if int(model.get("glass", -1)) >= 0:
			# yalnız cam yüzeyi bu örnekte değişir (ortak mesh'in malzemeleri olduğu gibi): gece pencereler yanar
			h.set_surface_override_material(int(model["glass"]), DayNight.window_material())
		# Yeni kentte çok yüzeyli cephe/çatı/zemin malzemeleri kendi üzerinde kalır.
		add_child(h)
		_halls[i] = h
	h.visible = s > 0.001
	var p: Vector2 = _pins[i][0]
	var angle := -PI * 0.5 if bool(model["legacy"]) else c.grid_angle
	var transform := Transform3D(Basis(Vector3.UP, angle).scaled(Vector3.ONE * maxf(size * float(model["scale"]), 0.001)),
			Vector3(p.x, _ground[i] + float(model["bottom"]) * size, p.y))
	h.transform = transform * (model["transform"] as Transform3D)
	var site: MeshInstance3D = _city_sites.get(i)
	if site == null and not bool(model["legacy"]):
		site = _city_ground.build(map, p, size, angle, c.id)
		add_child(site)
		_city_sites[i] = site
	if site != null:
		site.visible = h.visible

## Şehrin tepe ikonu: stilinin kademe dosyası, yoksa west'inki; başkentte o da yoksa madalyon; yoksa null
func _top_tex(c: City) -> Texture2D:
	if c == null:
		return null
	var tier: String = TOP_TIERS[CityLayer.tier_of(c)]
	var key := "city:%d" % c.id
	if not _top_cache.has(key):
		var tex: Texture2D = null
		var city_path := CITY_ART_DIR + "city_%05d.png" % c.id
		if ResourceLoader.exists(city_path):
			tex = UiTheme.trimmed(load(city_path))
		else:
			for st: String in [c.style, "west"]:
				var path := TOP_DIR + "city_%s_%s.png" % [st, tier]
				if ResourceLoader.exists(path):
					tex = UiTheme.trimmed(load(path))
					break
		_top_cache[key] = tex
	var t: Texture2D = _top_cache[key]
	if t == null and c.is_capital:
		return _medal()
	return t

func _top_px(c: City, tex: Texture2D) -> float:
	return MEDAL_PX if tex == _medal_tex else TOP_PX[CityLayer.tier_of(c)]

## Yakın görüşte sabit ölçülü şehirler: yalnız görünürlük değişir, pop/focus/hover ölçeği yok.
func _update_cities(d: float) -> void:
	var vp := get_viewport()
	var vs := vp.get_visible_rect().size
	var mouse := vp.get_mouse_position()
	var t := Vector2(camera.target.x, camera.target.z)
	var r := d * 1.8
	var view := Rect2(t - Vector2(r, r), Vector2(r, r) * 2.0)
	for i in _pins.size():
		var pin: Array = _pins[i]
		var p: Vector2 = pin[0]
		var base := Vector3(p.x, _ground[i], p.y)
		if pin[4] != null and d < float(pin[3]) and view.has_point(p) and not camera.is_position_behind(base):
			_anim_s[i] = 1.0
			_live[i] = true
			_write_pin(i)
		elif _live.has(i):
			_live.erase(i)
			_anim_s[i] = 0.0
			_write_pin(i)
	if _live.is_empty():
		hovered_city = -1
		return
	# Dünya ölçüsünden ekran yarıçapı: yakında büyük, uzakta küçük görünür;
	# seçimin merkezi modelin gerçek yüksekliğinde, modelin kendisi ölçeklenmez.
	var px_per := vs.y / (2.0 * tan(deg_to_rad(camera.fov) * 0.5))
	var best := -1
	var best_d := INF
	for i: int in _live.keys():
		var pin: Array = _pins[i]
		var p: Vector2 = pin[0]
		var base := Vector3(p.x, _ground[i], p.y)
		if camera.is_position_behind(base):
			continue
		var s := _anim_s[i]
		if s > 0.3:
			var hy := d * s * (float(pin[1]) + float(pin[2]) * 0.55)
			var hr := float(pin[2]) * s * px_per + 5.0
			if pin[4] != null:
				var model: Dictionary = _city_models.model_for(pin[4])
				if not model.is_empty():
					var width := city_model_width(pin[4])
					hy = width * float(model["height"]) * 0.5
					hr = width * float(model["footprint"]) * px_per / maxf(d, 1.0) + 5.0
			var hp := camera.unproject_position(base + Vector3(0.0, hy, 0.0))
			var md := hp.distance_to(mouse)
			if md < hr and md < best_d:
				best_d = md
				best = i
	hovered_city = best

func _restore_labels() -> void:
	# Şehir yazıları CityLayer3D'nin tek, sabit etiketidir; bu katman artık değiştirmez.
	pass

## Sayaçların (tümen, filo, hava kanadı) altına yere inen iğne gövdesi
func _update_counter_needles(d: float) -> void:
	var items: Array = []        # [Vector3 sayaç konumu, boy katı]
	if flags_only(d):
		_counter_needles.multimesh.visible_instance_count = 0    # bayrak kipinde iğne yok
		return
	# tümen kartı iğnenin ucunda (UnitLayer.pin_roots: yalnız kart kipinde; rozet kipinde iğne yok)
	if units:
		for root: Node3D in units.pin_roots():
			items.append([root.position, UNIT_LIFT])
	if fleets:
		for root: Node3D in fleets.pin_roots():
			items.append([root.position, SEA_LIFT])
	# hava kanatlarında iğne yok: levha üssün üstünde durur, uçaklar modelleriyle uçar
	var mm := _counter_needles.multimesh
	if mm.instance_count < items.size():
		mm.instance_count = items.size() + 64
		for i in mm.instance_count:
			mm.set_instance_color(i, Color.WHITE)
	mm.visible_instance_count = items.size()
	for i in items.size():
		var p: Vector3 = items[i][0]
		var k: float = items[i][1]
		var g := maxf(map.height_at(Vector2(p.x, p.z)), 0.0)
		# gövde yerden sayaca: boy katı, sayacın gerçek yüksekliğine göre
		var len_k := maxf(p.y - g, 0.0) / maxf(d, 1.0)
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(p.x, g, p.z)))
		mm.set_instance_custom_data(i, Color(len_k if len_k > 0.0 else k, NEEDLE_R * 0.9, 60000.0, 0.0))

# ------------------------------------------------------------------ yapı iğneleri
## Eyalet başına bir sanayi iğnesi (şehrin güneyindeki sanayi parselinde: şerit ekranda şehir adının altında kalır):
## ucunda eyaletin yapıları yan yana — her biri resmi ve köşesinde seviyesi; kuyruktaki inşaat turuncu çerçeve ve "+n".
## Hava üssü kendi yerinde ayrı iğne (hava kanadı sayacının altında kalmasın diye biraz yana).
## Orta uzaklıkta rozetler yalnız ikon olarak haritanın üstünde durur; iğne ancak çok yaklaşınca (BUILD_PIN_RANGE) çıkar.
## Fare bir rozetin üstüne gelince rozet büyür, yapının sesi çalar ve ipucu kartı o yapıyı anlatır (pick_building).
const BADGE_PX := 54.0               ## rozet (plaka) ekran boyu
const BADGE_GAP := 58.0              ## rozetler arası
const PX := 1766.0                   ## sabit boy sprite: doku pikseli * pixel_size * PX = ekran pikseli (34° görüş açısı, 1080p)

const RB_CHUNK := 250                 ## karelere yayılan kurulumda kare başına eyalet
var _rb_list: Array = []
var _rb_i := 0
var _rb_want := {}
var _rb_queued := {}

func _rebuild_buildings(ind: IndustryLayer) -> void:
	var queued := _collect_queued()
	var want := {}
	for sid: int in World.states:
		_want_state(sid, queued, ind, want)
	_apply_want(want)

## Kuyruktaki inşaatlar eyalete göre (metin anahtarı biçimlendirmek her saniye binlerce kez pahalıydı)
func _collect_queued() -> Dictionary:
	var queued := {}                # eyalet -> {tür: adet}
	for c: Country in World.countries.values():
		for pr: ConstructionProject in c.construction_queue:
			if not queued.has(pr.state_id):
				queued[pr.state_id] = {}
			var qd: Dictionary = queued[pr.state_id]
			qd[pr.building] = int(qd.get(pr.building, 0)) + 1
	return queued

const _NONE := {}

## Eyaletin istenen iğneleri: want[anahtar] = [konum, rozetler, rozetlerin özeti]
func _want_state(sid: int, queued: Dictionary, ind: IndustryLayer, want: Dictionary) -> void:
	if not Economy.SHOW_BUILDINGS:
		return                                   # yapılar haritada gösterilmez
	var st: StateRegion = World.states.get(sid)
	if st == null or Military.state_fogged(st):
		return                                   # savaş sisi: bulutun altındaki eyaletin yapıları gösterilmez
	var q: Dictionary = queued.get(sid, _NONE)
	var items: Array = []           # [tür, sayı, inşaat mı] — yazı rozet kurulurken
	for t: String in BUILDINGS:
		var lv := int(st.buildings.get(t, 0))
		var n := int(q.get(t, 0)) if not q.is_empty() else 0
		if lv == 0 and n == 0:
			continue
		if t == "air_base":
			if lv > 0 and map.airbase_sites.has(sid):
				var air: Array = [[t, lv, false]]
				want[_key(sid, true)] = [map.airbase_sites[sid][0] + Vector2(7.0, 5.0), air, hash(air)]
			if n > 0:
				items.append([t, n, true])
			continue
		if lv > 0:
			items.append([t, lv, false])
		if n > 0:
			items.append([t, n, true])
	if items.is_empty():
		return
	var key := _key(sid, false)
	var ih := hash(items)
	# rozetler aynıysa yer de aynı (sanayi parseli yalnız rozet değişince yeniden aranır)
	if _bstate.has(key) and int(_bstate[key][2]) == ih:
		want[key] = [_bstate[key][1][1], items, ih]
		return
	var pos := Vector2.INF
	if ind:
		for sp: Vector2 in ind.state_slots(sid):
			if pos == Vector2.INF or sp.y > pos.y:
				pos = sp
	if pos == Vector2.INF:
		var city := st.largest_city()
		pos = (city.position if city else st.center) + Vector2(6.0, 6.0)
	want[key] = [pos, items, ih]

## İstenen iğnelerle var olanları eşle: değişmeyenler kalır, değişen ya da kalkanlar yenilenir
func _apply_want(want: Dictionary) -> void:
	# değişmeyenler kalır; değişen ya da kalkanlar yenilenir. Hiçbir şey değişmediyse liste ve iğne gövdeleri yeniden
	# yazılmaz; yalnız rozet içeriği değiştiyse (seviye, inşaat) gövdeler aynı kalır.
	var changed := false
	var moved := false
	for key: String in _bstate.keys():
		if not want.has(key):
			(_bstate[key][1][0] as Node3D).queue_free()
			_bstate.erase(key)
			changed = true
			moved = true
	for key: String in want:
		var w: Array = want[key]
		var sig := hash([w[0], w[2]])
		if _bstate.has(key):
			if _bstate[key][0] == sig:
				continue
			if _bstate[key][1][1] != w[0]:
				moved = true
			(_bstate[key][1][0] as Node3D).queue_free()
		else:
			moved = true
		_bstate[key] = [sig, _add_pin(w[0], w[1]), w[2]]
		changed = true
	if not changed:
		return
	_bpins.clear()
	for key: String in _bstate:
		_bpins.append(_bstate[key][1])
	if moved:
		_write_needles()
	# yenilenen iğnede fare altındaki rozet yine büyük dursun
	var hk := _hover_key
	_hover_key = ""
	if hk != "" and _apply_hover(hk, true):
		_hover_key = hk

## Yapı iğnelerinin gövdeleri (her iğnenin yerinde bir örnek)
func _write_needles() -> void:
	var mm := _build_needles.multimesh
	mm.instance_count = _bpins.size()
	for i in _bpins.size():
		var p: Vector2 = _bpins[i][1]
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(p.x, float(_bpins[i][2]), p.y)))
		mm.set_instance_custom_data(i, Color(BUILD_LIFT * float(_bpins[i][5]), NEEDLE_R * 0.9, BUILD_PIN_RANGE, 0.0))
		mm.set_instance_color(i, Color.WHITE)

## Eyalet iğnesinin anahtarı (eyalet ya da hava üssü); metin her seferinde kurulmasın diye saklanır
var _keys := {}

func _key(sid: int, air: bool) -> String:
	var k := -sid if air else sid
	if not _keys.has(k):
		_keys[k] = ("air:%d" % sid) if air else str(sid)
	return _keys[k]

## Bir iğne ve ucunda yan yana rozetler: [tür, sayı, inşaat mı]
func _add_pin(p: Vector2, items: Array) -> Array:
	var root := Node3D.new()
	add_child(root)
	var n := items.size()
	var badges: Array = []          # [plaka, resim (ya da null), seviye yazısı, x]
	for k in n:
		var it: Array = items[k]
		var building: bool = it[2]
		var x := _badge_x(k, n)
		var plate := _sprite(_plate(building), BADGE_PX, 9)
		root.add_child(plate)
		var tex := _glyph(it[0])
		var icon: Sprite3D = null
		if tex:
			icon = _sprite(tex, BADGE_PX - 4.0, 10)
			root.add_child(icon)
		var l := Label3D.new()
		l.text = ("+%d" if building else "%d") % int(it[1])
		l.font = UiTheme.bold_font()
		l.font_size = 30
		l.outline_size = 8
		l.outline_modulate = Color(0.04, 0.05, 0.06, 1)
		l.modulate = PLATE_BUILD.lightened(0.2) if building else GLYPH_GOLD
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.fixed_size = true
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		l.no_depth_test = true
		root.add_child(l)
		var b := [plate, icon, l, x]
		_layout_badge(b, 1.0)
		badges.append(b)
	root.scale = Vector3.ONE * _badge_k
	# boy katı: konumdan belirlenimci (aynı eyaletin iğnesi hep aynı boyda); komşular farklı katlarda
	var hk := BUILD_LIFT_STEPS[posmod(floori(p.x / 23.0) * 3 + floori(p.y / 23.0) * 5, BUILD_LIFT_STEPS.size())]
	return [root, p, maxf(map.height_at(p), 0.0), items, badges, hk]

## Rozetin iğneye göre yatay yeri (ekran pikseli): rozetler iğnenin iki yanına dizilir
static func _badge_x(k: int, n: int) -> float:
	return (float(k) - float(n - 1) * 0.5) * BADGE_GAP

## Rozeti k katı boyda yerleştir (alt kenarı iğnenin ucunda kalır); büyütülen (fare altındaki) rozet komşularının önüne
## geçer. Uzaklıkla küçülme kökün ölçeğiyle (_badge_k): etiket boyunu değiştirmek her Label3D'nin metnini yeniden
## kurduruyordu (yakınlaştırırken 150+ ms takılma).
func _layout_badge(b: Array, k: float) -> void:
	var x: float = b[3]
	var top := 6 if k > 1.0 else 0
	var size := BADGE_PX * k
	var plate: Sprite3D = b[0]
	plate.pixel_size = size / (maxf(float(plate.texture.get_height()), 1.0) * PX)
	plate.offset = Vector2(x, size * 0.5) / (plate.pixel_size * PX)
	plate.render_priority = 9 + top
	var icon: Sprite3D = b[1]
	if icon:
		icon.pixel_size = (size * 0.7) / (maxf(float(icon.texture.get_height()), 1.0) * PX)
		icon.offset = Vector2(x, size * 0.5) / (icon.pixel_size * PX)
		icon.render_priority = 10 + top
	var l: Label3D = b[2]
	l.pixel_size = 0.00034 * k
	# sayı rozetin sağ alt köşesinde (menü kısayol harfi gibi)
	l.offset = Vector2(x + size * 0.5 - 1.0, 2.0) / (l.pixel_size * PX)
	l.render_priority = 12 + top
	l.outline_render_priority = 11 + top

## Ekran konumundaki yapı rozeti: {sid, building, construction, pid, hk} (yoksa boş). Rozetler sabit ekran boyunda
## olduğundan kutu ekranda hesaplanır: iğne ucunun izdüşümü + rozetin piksel yeri.
func pick_building(screen: Vector2) -> Dictionary:
	if not visible:
		return {}
	var s := camera.get_viewport().get_visible_rect().size.y / 1080.0
	var best := {}
	var bd := INF
	for key: String in _bstate:
		var rec: Array = _bstate[key][1]
		var root: Node3D = rec[0]
		if not root.visible or camera.is_position_behind(root.global_position):
			continue
		var tip := camera.unproject_position(root.global_position)
		var items: Array = rec[3]
		var n := items.size()
		if absf(screen.x - tip.x) > (float(n) * BADGE_GAP * 0.5 + BADGE_PX) * _badge_k * s or screen.y > tip.y + 4.0 \
				or screen.y < tip.y - BADGE_PX * HOVER_SCALE * _badge_k * s - 4.0:
			continue
		for k in n:
			var hk := "%s#%d" % [key, k]
			var size := BADGE_PX * (HOVER_SCALE if hk == _hover_key else 1.0) * _badge_k * s
			var c := tip + Vector2(_badge_x(k, n) * _badge_k * s, -size * 0.5)
			var dx := absf(screen.x - c.x)
			var dy := absf(screen.y - c.y)
			if dx > size * 0.5 or dy > size * 0.5:
				continue
			var dist := dx + dy
			if dist < bd:
				bd = dist
				var it: Array = items[k]
				var p: Vector2 = rec[1]
				var sid := int(key.substr(4)) if key.begins_with("air:") else int(key)
				best = {"sid": sid, "building": String(it[0]), "construction": bool(it[2]), "hk": hk,
					"pid": map.province_at(p)}
	if not best.is_empty():
		return best
	# Physical naval facilities use their real projected footprint, not an invisible
	# fixed-screen badge. Keep the existing tooltip / state selection contract.
	if cities != null:
		for layer: Node in cities.get_children():
			if bool(layer.get_meta("map_landmark_layer", false)) and layer.has_method("pick_building"):
				var hit: Dictionary = layer.call("pick_building", screen, camera)
				if not hit.is_empty(): return hit
	return {}

## Fare altındaki rozet: büyüt, öncekini küçült; yeni rozete gelince yapının sesi çalar
func set_hovered_building(hit: Dictionary) -> void:
	var hk: String = hit.get("hk", "")
	if hk == _hover_key:
		return
	_apply_hover(_hover_key, false)
	_hover_key = hk
	if hk != "":
		_apply_hover(hk, true)
		Audio.hover_building(String(hit["building"]))

func hovered_building() -> String:
	return _hover_key

func _apply_hover(hk: String, on: bool) -> bool:
	var cut := hk.rfind("#")
	if cut < 0:
		return false
	var key := hk.substr(0, cut)
	var k := int(hk.substr(cut + 1))
	if not _bstate.has(key):
		return false
	var badges: Array = _bstate[key][1][4]
	if k >= badges.size():
		return false
	_layout_badge(badges[k], HOVER_SCALE if on else 1.0)
	return true

func _sprite(tex: Texture2D, px: float, prio: int) -> Sprite3D:
	var sp := Sprite3D.new()
	sp.texture = tex
	sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sp.fixed_size = true
	sp.pixel_size = px / (maxf(float(tex.get_height()), 1.0) * PX)
	sp.no_depth_test = true
	sp.render_priority = prio
	sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return sp

## Yapı iğnesinin ucu (boyalı harita tasarımı): koyu kare karo, altın (yapı) ya da turuncu (inşaat) ince çerçeve
func _plate(building: bool) -> Texture2D:
	if _plates.has(building):
		return _plates[building]
	var n := 72
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var border: Color = PLATE_BUILD if building else PLATE_GOLD
	var half := n * 0.5
	var r := 7.0
	for y in n:
		for x in n:
			# yuvarlatılmış karenin işaretli uzaklığı (içeride negatif)
			var qx := absf(float(x) + 0.5 - half) - (half - r)
			var qy := absf(float(y) + 0.5 - half) - (half - r)
			var sd := Vector2(maxf(qx, 0.0), maxf(qy, 0.0)).length() + minf(maxf(qx, qy), 0.0) - r
			if sd > 0.5:
				continue
			var col: Color = Color(0.07, 0.08, 0.09, 0.94)
			if sd > -1.2:
				col = Color("0b0d0e")
			elif sd > -4.0:
				col = border
			col.a *= clampf(0.5 - sd, 0.0, 1.0)
			img.set_pixel(x, y, col)
	var tex := ImageTexture.create_from_image(img)
	_plates[building] = tex
	return tex

## Yapı piktogramı koyu karoda altın: SVG piktogramın koyu mürekkebi altın olur, açık "kâğıt" pencereler saydam (karonun
## koyu zemini görünür). Piktogram yoksa oyunun yapı ikonu olduğu gibi.
func _glyph(building: String) -> Texture2D:
	if _glyphs.has(building):
		return _glyphs[building]
	var path := "res://assets/ui/icons/map_building_%s.svg" % building
	var src: Texture2D = load(path) if ResourceLoader.exists(path) else null
	var tex: Texture2D = null
	if src:
		var img := src.get_image()
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a <= 0.0:
					continue
				var lum := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
				var a := c.a * (1.0 - smoothstep(0.55, 0.8, lum))
				img.set_pixel(x, y, Color(GLYPH_GOLD.r, GLYPH_GOLD.g, GLYPH_GOLD.b, a))
		tex = UiTheme.trimmed(ImageTexture.create_from_image(img))
	else:
		tex = UiTheme.trimmed(UiTheme.building_pin_icon(building))
	_glyphs[building] = tex
	return tex

## Başkent madalyonu: koyu disk, altın halka, iç ince halka ve altın yıldız
func _medal() -> Texture2D:
	if _medal_tex:
		return _medal_tex
	var n := 96
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := Vector2(n, n) * 0.5
	var gold := Color("d7b565")
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if d > 46.5:
				continue
			var col := Color(0.08, 0.10, 0.12, 1.0)
			if d > 44.0:
				col = Color("0b0d0e")
			elif d > 38.5:
				col = gold.darkened(0.15 * (d - 38.5) / 5.5)
			elif d > 36.5:
				col = Color(0.05, 0.06, 0.07, 1.0)
			elif d > 34.5 and d < 35.7:
				col = gold.darkened(0.35)
			col.a *= clampf(46.5 - d, 0.0, 1.0)
			img.set_pixel(x, y, col)
	FlagFactory._fill_poly(img, FlagFactory._star(c, 26.0, 10.5), gold)
	_medal_tex = ImageTexture.create_from_image(img)
	return _medal_tex

## Rozetler BUILD_RANGE içinde önce ikon olarak haritanın üstünde durur; BUILD_PIN_RANGE içinde iğneyle yükselir
func _update_building_heights(d: float) -> void:
	var show := 1.0 - smoothstep(BUILD_RANGE * 0.8, BUILD_RANGE, d)
	var grow := 1.0 - smoothstep(BUILD_PIN_RANGE * 0.8, BUILD_PIN_RANGE, d)
	# uzakta rozetler küçük (harita dolmasın), iğne çıkarken tam boy
	var k := lerpf(1.0, FAR_BADGE, smoothstep(BUILD_PIN_RANGE, BUILD_RANGE * 0.8, d))
	if absf(k - _badge_k) > 0.01:
		_badge_k = k
	var sc := Vector3.ONE * _badge_k
	for b: Array in _bpins:
		var root: Node3D = b[0]
		root.visible = show > 0.45
		if root.visible:
			var p: Vector2 = b[1]
			root.position = Vector3(p.x, float(b[2]) + d * (0.004 + BUILD_LIFT * float(b[5]) * grow), p.y)
			if root.scale != sc:
				root.scale = sc
