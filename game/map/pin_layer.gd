class_name PinLayer
extends Node3D
## İğne haritası (haritanın tasarımı): şehir, sanayi, asker ve gemi modelleri yerine haritaya saplanmış iğneler; uçaklar
## tek küçük modelle (AirLayer).
## Şehir: ülke renginde başlı iğne (önemine göre boy; başkent en büyük), adı başın üstünde. Tümen, filo ve hava kanadı:
## sayacı bayrak gibi taşıyan iğne. Yapılar (fabrika, tersane, rafineri, uçaksavar, demiryolu deposu, deniz ve hava üssü):
## ucunda yapının resmi ve seviyesi olan iğne, eyalet ve tür başına bir tane; süren inşaat turuncu çerçeve ve "+n". Ekranda sabit boy: iğneler kamera uzaklığıyla ölçeklenir (shader), uzakta kaybolmaz,
## yakında devleşmez. Yalnız görünüm değişir; oyun mantığı, seçim ve paneller aynıdır.

const SHADER := preload("res://assets/shaders/pin.gdshader")
const NEEDLE_R := 0.0017                                               ## gövde yarıçapı (kamera uzaklığı katı)
const CITY_LEN: Array[float] = [0.075, 0.062, 0.054, 0.047, 0.042]     ## şehir önem kademesi 0..4 (CityLayer.tier_of)
const CITY_HEAD: Array[float] = [0.0135, 0.0108, 0.0092, 0.008, 0.007]
const UNIT_LIFT := 0.058                                               ## tümen sayacının yerden yüksekliği
const AIR_LIFT := 0.072
const SEA_LIFT := 0.05

static func active() -> bool:
	return World.in_game

## Sayaç yüksekliği (iğnenin boyu): kamera uzaklığının katı → ekranda sabit
static func lift(cam_d: float, k: float = UNIT_LIFT) -> float:
	return cam_d * k

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
var _bpins: Array = []               ## yapı iğneleri: [kök Node3D, konum Vector2, zemin yüksekliği, rozetler [tür, yazı, inşaat mı]]
var _build_sig := -1
var _plates := {}
var _needle_mat: ShaderMaterial
var _head_mat: ShaderMaterial
var _ground: PackedFloat32Array = []
var _on := false
var _colors_dirty := true
var _last_label_d := -1.0
var _recheck := 0.0

const BUILD_LIFT := 0.045                                             ## yapı iğnesinin boyu
const BUILD_RANGE := 560.0                                            ## yapı iğneleri bu uzaklığın içinde
## iğnesi olan yapılar (altyapı her eyalette olduğundan iğnesi yok: haritayı doldururdu; bölge panelinde görünür)
const BUILDINGS := ["civilian_factory", "military_factory", "synthetic_refinery", "anti_air", "dockyard", "naval_base",
	"air_base"]
const PLATE_GOLD := Color(0.78, 0.64, 0.36)
const PLATE_BUILD := Color(0.98, 0.56, 0.16)

## İğneler: [konum (Vector2), boy katı, baş katı, görünme uzaklığı, şehir (ya da null), sabit renk]
var _pins: Array = []

func _ready() -> void:
	_needle_mat = _material(false)
	_head_mat = _material(true)
	var needle := CylinderMesh.new()
	needle.top_radius = 1.0
	needle.bottom_radius = 1.0
	needle.height = 1.0
	needle.radial_segments = 8
	needle.rings = 1
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	ball.radial_segments = 14
	ball.rings = 8
	_city_needles = _mmi(needle, _needle_mat)
	_heads = _mmi(ball, _head_mat)
	_counter_needles = _mmi(needle, _needle_mat)
	_rebuild()
	World.ownership_changed.connect(func() -> void: _colors_dirty = true)
	_build_needles = _mmi(needle, _needle_mat)
	visible = false

## Uzakta harita ikonu gösterilen şehir yakında iğne olur. İğneler geç gelir (harita uzun süre sade kalsın): başkent 820,
## 10+ puan 560, 3+ puan 420; ikonu olmayan kasaba 300 (ya da adının göründüğü uzaklık). Harita ikonlarının söndüğü
## uzaklık buna uydurulur (_sync_icon_ranges): ikon ile iğne arasında boşluk kalmaz.
const CITY_SWITCH := {1300: 820.0, 900: 560.0, 640: 420.0}     ## ikon katmanının eski geçişi -> iğnenin gelişi

static func _city_range(c: City) -> float:
	if c.is_capital:
		return CITY_SWITCH[1300]
	if c.victory_points >= 10:
		return CITY_SWITCH[900]
	if c.victory_points >= 3:
		return CITY_SWITCH[640]
	return minf(CityLayer3D.LABEL_RANGE[CityLayer.tier_of(c)], 300.0)

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
		var tier := CityLayer.tier_of(c)
		_pins.append([c.position, CITY_LEN[tier], CITY_HEAD[tier], _city_range(c), c, Color.WHITE])
	_ground.resize(_pins.size())
	var cmm := _city_needles.multimesh
	var hmm := _heads.multimesh
	cmm.instance_count = _pins.size()
	hmm.instance_count = _pins.size()
	for i in _pins.size():
		var pin: Array = _pins[i]
		var p: Vector2 = pin[0]
		var g := maxf(map.height_at(p), 0.0)
		_ground[i] = g
		var xf := Transform3D(Basis(), Vector3(p.x, g, p.y))
		cmm.set_instance_transform(i, xf)
		cmm.set_instance_custom_data(i, Color(pin[1], NEEDLE_R, pin[3], 0.0))
		cmm.set_instance_color(i, Color.WHITE)
		hmm.set_instance_transform(i, xf)
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
	_head_mat.set_shader_parameter("cam_dist", d)
	if _colors_dirty:
		_colors_dirty = false
		_update_colors()
	var ind := cities.industry() if cities else null
	var sig := (ind.version if ind else 0) * 4096 + map.airbase_sites.size()
	if sig != _build_sig:
		_build_sig = sig
		_rebuild_buildings(ind)
		_last_label_d = -1.0
	if _last_label_d < 0.0 or absf(d - _last_label_d) > _last_label_d * 0.02:
		_last_label_d = d
		_update_labels(d)
		_update_building_heights(d)
	_update_counter_needles(d)

## Şehir, sanayi, liman ve hava üssü modelleri gizlenir; adlar, ağaçlar, boğazlar ve uzak zoom harita ikonları kalır
func _set_models_hidden(hidden: bool) -> void:
	if cities == null:
		return
	for ch: Node in cities.get_children():
		if ch is Label3D or ch is TreeLayer or ch is StraitLayer or ch is MapIconLayer:
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
			var owner := World.controller_tag(c.province_id)
			col = World.countries[owner].color if World.countries.has(owner) else Color(0.6, 0.6, 0.6)
			col = col.lightened(0.1)
		var packed := float(col.r8 * 65536 + col.g8 * 256 + col.b8)
		hmm.set_instance_custom_data(i, Color(pin[1], pin[2], pin[3], packed))
		hmm.set_instance_color(i, col)        # web (Compatibility) yolu

## Şehir adları: iğne görünürken başın üstünde (kamera uzaklığıyla yükselir), uzakta her zamanki yerinde
func _update_labels(d: float) -> void:
	for i in _pins.size():
		var pin: Array = _pins[i]
		var c: City = pin[4]
		if c == null:
			continue
		var l: Label3D = cities.labels.get(c.id)
		if l == null or d > CityLayer3D.LABEL_RANGE[CityLayer.tier_of(c)]:
			continue
		var grow := 1.0 - smoothstep(float(pin[3]) * 0.8, float(pin[3]), d)
		var normal := _ground[i] + (12.0 if c.is_capital else 7.0)
		l.position.y = lerpf(normal, _ground[i] + d * (float(pin[1]) + float(pin[2]) * 1.4), grow)

func _restore_labels() -> void:
	for i in _pins.size():
		var c: City = _pins[i][4]
		if c == null:
			continue
		var l: Label3D = cities.labels.get(c.id)
		if l:
			l.position.y = _ground[i] + (12.0 if c.is_capital else 7.0)

## Sayaçların (tümen, filo, hava kanadı) altına yere inen iğne gövdesi
func _update_counter_needles(d: float) -> void:
	var items: Array = []        # [Vector3 sayaç konumu, boy katı]
	if units:
		for root: Node3D in units.pin_roots():
			items.append([root.position, UNIT_LIFT])
	if fleets:
		for root: Node3D in fleets.pin_roots():
			items.append([root.position, SEA_LIFT])
	if air and air.visible:
		for root: Node3D in air.pin_roots():
			items.append([root.position, AIR_LIFT])
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
const BADGE_PX := 46.0               ## rozet (plaka) ekran boyu
const BADGE_GAP := 50.0              ## rozetler arası
const PX := 1766.0                   ## sabit boy sprite: doku pikseli * pixel_size * PX = ekran pikseli (34° görüş açısı, 1080p)

func _rebuild_buildings(ind: IndustryLayer) -> void:
	for b: Array in _bpins:
		(b[0] as Node3D).queue_free()
	_bpins.clear()
	var queued := {}
	for c: Country in World.countries.values():
		for pr: ConstructionProject in c.construction_queue:
			var key := "%d:%s" % [pr.state_id, pr.building]
			queued[key] = int(queued.get(key, 0)) + 1
	for sid: int in World.states:
		var st: StateRegion = World.states[sid]
		var items: Array = []           # [tür, yazı, inşaat mı]
		var pos := Vector2.INF
		for t: String in BUILDINGS:
			var lv := st.building_level(t)
			var q := int(queued.get("%d:%s" % [sid, t], 0))
			if t == "air_base":
				if lv > 0 and map.airbase_sites.has(sid):
					_add_pin(map.airbase_sites[sid][0] + Vector2(7.0, 5.0), [[t, str(lv), false]])
				if q > 0:
					items.append([t, "+%d" % q, true])
				continue
			if lv > 0:
				items.append([t, str(lv), false])
			if q > 0:
				items.append([t, "+%d" % q, true])
		if not items.is_empty() and ind:
			for sp: Vector2 in ind.state_slots(sid):
				if pos == Vector2.INF or sp.y > pos.y:
					pos = sp
		if not items.is_empty():
			if pos == Vector2.INF:
				var city := st.largest_city()
				pos = (city.position if city else st.center) + Vector2(6.0, 6.0)
			_add_pin(pos, items)
	var mm := _build_needles.multimesh
	mm.instance_count = _bpins.size()
	for i in _bpins.size():
		var p: Vector2 = _bpins[i][1]
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(p.x, float(_bpins[i][2]), p.y)))
		mm.set_instance_custom_data(i, Color(BUILD_LIFT, NEEDLE_R * 0.9, BUILD_RANGE, 0.0))
		mm.set_instance_color(i, Color.WHITE)

## Bir iğne ve ucunda yan yana rozetler: [tür, yazı, inşaat mı]
func _add_pin(p: Vector2, items: Array) -> void:
	var root := Node3D.new()
	add_child(root)
	var n := items.size()
	for k in n:
		var it: Array = items[k]
		var building: bool = it[2]
		var x := (float(k) - float(n - 1) * 0.5) * BADGE_GAP     # ekran pikseli, iğnenin iki yanına
		var plate := _sprite(_plate(building), BADGE_PX, 9)
		plate.offset = Vector2(x, BADGE_PX * 0.5) / (plate.pixel_size * PX)
		root.add_child(plate)
		var tex := UiTheme.trimmed(UiTheme.building_icon(it[0]))
		if tex:
			var icon := _sprite(tex, BADGE_PX - 8.0, 10)
			icon.offset = Vector2(x, BADGE_PX * 0.5) / (icon.pixel_size * PX)
			root.add_child(icon)
		var l := Label3D.new()
		l.text = it[1]
		l.font = UiTheme.bold_font()
		l.font_size = 30
		l.outline_size = 10
		l.outline_modulate = Color(0, 0, 0, 1)
		l.modulate = PLATE_BUILD.lightened(0.25) if building else Color(1, 0.96, 0.85)
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.fixed_size = true
		l.pixel_size = 0.00034
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		# sayı rozetin sağ alt köşesinde (menü kısayol harfi gibi)
		l.offset = Vector2(x + BADGE_PX * 0.5 - 1.0, 2.0) / (l.pixel_size * PX)
		l.no_depth_test = true
		l.render_priority = 12
		l.outline_render_priority = 11
		root.add_child(l)
	_bpins.append([root, p, maxf(map.height_at(p), 0.0), items])

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

## Yapı iğnesinin ucu: koyu zemin, altın (yapı) ya da turuncu (inşaat) çerçeve
func _plate(building: bool) -> Texture2D:
	if _plates.has(building):
		return _plates[building]
	var n := 72
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var border: Color = PLATE_BUILD if building else PLATE_GOLD
	var half := n * 0.5
	var r := 12.0
	for y in n:
		for x in n:
			# yuvarlatılmış karenin işaretli uzaklığı (içeride negatif)
			var qx := absf(float(x) + 0.5 - half) - (half - r)
			var qy := absf(float(y) + 0.5 - half) - (half - r)
			var sd := Vector2(maxf(qx, 0.0), maxf(qy, 0.0)).length() + minf(maxf(qx, qy), 0.0) - r
			if sd > 0.5:
				continue
			var col: Color = Color(0.07, 0.08, 0.075, 0.93) if sd < -4.0 else border
			col.a *= clampf(0.5 - sd, 0.0, 1.0)
			img.set_pixel(x, y, col)
	var tex := ImageTexture.create_from_image(img)
	_plates[building] = tex
	return tex

## Ekran noktasının altındaki yapı rozetinin türü ("civilian_factory"...) ya da "": rozet üstüne gelme sesi (main.gd →
## Audio.play_building). Rozet ölçüleri 1080p ekran pikseli (PX): başka çözünürlükte yükseklik oranıyla ölçeklenir.
func badge_at(screen: Vector2) -> String:
	if not _on or camera == null:
		return ""
	var k := get_viewport().get_visible_rect().size.y / 1080.0
	var half := BADGE_PX * 0.55 * k
	for b: Array in _bpins:
		var root: Node3D = b[0]
		if not root.visible or camera.is_position_behind(root.global_position):
			continue
		var sp := camera.unproject_position(root.global_position)
		if absf(screen.y - (sp.y - BADGE_PX * 0.5 * k)) > half:
			continue
		var items: Array = b[3]
		var n := items.size()
		for i in n:
			var cx := sp.x + (float(i) - float(n - 1) * 0.5) * BADGE_GAP * k
			if absf(screen.x - cx) <= half:
				return str(items[i][0])
	return ""

## Resimli uçların yüksekliği iğne boyuyla birlikte (kamera uzaklığı katı); menzil dışındakiler gizli
func _update_building_heights(d: float) -> void:
	var grow := 1.0 - smoothstep(BUILD_RANGE * 0.8, BUILD_RANGE, d)
	for b: Array in _bpins:
		var root: Node3D = b[0]
		root.visible = grow > 0.45
		if root.visible:
			var p: Vector2 = b[1]
			root.position = Vector3(p.x, float(b[2]) + d * BUILD_LIFT * grow, p.y)
