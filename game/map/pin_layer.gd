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
var _bpins: Array = []               ## yapı iğneleri: [kök Node3D, konum Vector2, zemin, rozetler [tür, yazı, inşaat mı], rozet düğümleri]
var _build_sig := -1
var _bstate := {}                    ## anahtar ("sid" / "air:sid") -> [imza, iğne kaydı] — yalnız değişen eyalet yenilenir
var _build_timer := 0.0
var _hover_key := ""                 ## fare altındaki rozet: "anahtar#sıra"
var _plates := {}
var _needle_mat: ShaderMaterial
var _head_mat: ShaderMaterial
var _ground: PackedFloat32Array = []
var _on := false
var _colors_dirty := true
var _last_label_d := -1.0
var _recheck := 0.0

const BUILD_LIFT := 0.045                                             ## yapı iğnesinin boyu
const BUILD_RANGE := 560.0                                            ## yapı rozetleri bu uzaklığın içinde (önce ikon)
const BUILD_PIN_RANGE := 280.0                                        ## iğne yalnız bu kadar yakında yerden yükselir
const HOVER_SCALE := 1.3                                              ## fare altındaki rozet büyür
## iğnesi olan yapılar (altyapı her eyalette olduğundan iğnesi yok: haritayı doldururdu; bölge panelinde görünür)
const BUILDINGS := ["civilian_factory", "military_factory", "synthetic_refinery", "anti_air", "dockyard", "naval_base",
	"air_base"]
const PLATE_GOLD := Color("a98743")
const PLATE_BUILD := Color("bd5429")

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
	# yapı iğneleri: en çok saniyede bir, yalnız görünürken (uzakta gizliler; yakına gelince güncellenir).
	# Yapay zekâ ülkeleri durmadan inşaat başlattığından her karede yenilemek 5× hızda kareyi yiyordu.
	var ind := cities.industry() if cities else null
	_build_timer -= delta
	var sig := (ind.version if ind else 0) * 4096 + map.airbase_sites.size()
	if sig != _build_sig and (_build_timer <= 0.0 or _build_sig < 0) and (d < BUILD_RANGE * 1.1 or _build_sig < 0):
		_build_sig = sig
		_build_timer = 1.0
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
	if cities == null:
		return
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
## Orta uzaklıkta rozetler yalnız ikon olarak haritanın üstünde durur; iğne ancak çok yaklaşınca (BUILD_PIN_RANGE) çıkar.
## Fare bir rozetin üstüne gelince rozet büyür, yapının sesi çalar ve ipucu kartı o yapıyı anlatır (pick_building).
const BADGE_PX := 54.0               ## rozet (plaka) ekran boyu
const BADGE_GAP := 58.0              ## rozetler arası
const PX := 1766.0                   ## sabit boy sprite: doku pikseli * pixel_size * PX = ekran pikseli (34° görüş açısı, 1080p)

func _rebuild_buildings(ind: IndustryLayer) -> void:
	var queued := {}
	for c: Country in World.countries.values():
		for pr: ConstructionProject in c.construction_queue:
			var key := "%d:%s" % [pr.state_id, pr.building]
			queued[key] = int(queued.get(key, 0)) + 1
	var want := {}                  # anahtar -> [konum, rozetler]
	for sid: int in World.states:
		var st: StateRegion = World.states[sid]
		var items: Array = []           # [tür, yazı, inşaat mı]
		for t: String in BUILDINGS:
			var lv := st.building_level(t)
			var q := int(queued.get("%d:%s" % [sid, t], 0))
			if t == "air_base":
				if lv > 0 and map.airbase_sites.has(sid):
					want["air:%d" % sid] = [map.airbase_sites[sid][0] + Vector2(7.0, 5.0), [[t, str(lv), false]]]
				if q > 0:
					items.append([t, "+%d" % q, true])
				continue
			if lv > 0:
				items.append([t, str(lv), false])
			if q > 0:
				items.append([t, "+%d" % q, true])
		if items.is_empty():
			continue
		var pos := Vector2.INF
		if ind:
			for sp: Vector2 in ind.state_slots(sid):
				if pos == Vector2.INF or sp.y > pos.y:
					pos = sp
		if pos == Vector2.INF:
			var city := st.largest_city()
			pos = (city.position if city else st.center) + Vector2(6.0, 6.0)
		want[str(sid)] = [pos, items]
	# değişmeyenler kalır; değişen ya da kalkanlar yenilenir
	for key: String in _bstate.keys():
		if not want.has(key):
			(_bstate[key][1][0] as Node3D).queue_free()
			_bstate.erase(key)
	for key: String in want:
		var w: Array = want[key]
		var sig := "%s|%s" % [str(w[0]), str(w[1])]
		if _bstate.has(key):
			if _bstate[key][0] == sig:
				continue
			(_bstate[key][1][0] as Node3D).queue_free()
		_bstate[key] = [sig, _add_pin(w[0], w[1])]
	_bpins.clear()
	for key: String in _bstate:
		_bpins.append(_bstate[key][1])
	var mm := _build_needles.multimesh
	mm.instance_count = _bpins.size()
	for i in _bpins.size():
		var p: Vector2 = _bpins[i][1]
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(p.x, float(_bpins[i][2]), p.y)))
		mm.set_instance_custom_data(i, Color(BUILD_LIFT, NEEDLE_R * 0.9, BUILD_PIN_RANGE, 0.0))
		mm.set_instance_color(i, Color.WHITE)
	# yenilenen iğnede fare altındaki rozet yine büyük dursun
	var hk := _hover_key
	_hover_key = ""
	if hk != "" and _apply_hover(hk, true):
		_hover_key = hk

## Bir iğne ve ucunda yan yana rozetler: [tür, yazı, inşaat mı]
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
		var tex := UiTheme.trimmed(UiTheme.building_pin_icon(it[0]))
		var icon: Sprite3D = null
		if tex:
			icon = _sprite(tex, BADGE_PX - 4.0, 10)
			root.add_child(icon)
		var l := Label3D.new()
		l.text = it[1]
		l.font = UiTheme.bold_font()
		l.font_size = 30
		l.outline_size = 10
		l.outline_modulate = Color(0, 0, 0, 1)
		l.modulate = Color("28302e") if building else Color("a74632")
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.fixed_size = true
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		l.no_depth_test = true
		root.add_child(l)
		var b := [plate, icon, l, x]
		_layout_badge(b, 1.0)
		badges.append(b)
	return [root, p, maxf(map.height_at(p), 0.0), items, badges]

## Rozetin iğneye göre yatay yeri (ekran pikseli): rozetler iğnenin iki yanına dizilir
static func _badge_x(k: int, n: int) -> float:
	return (float(k) - float(n - 1) * 0.5) * BADGE_GAP

## Rozeti k katı boyda yerleştir (alt kenarı iğnenin ucunda kalır); büyütülen rozet komşularının önüne geçer
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
		icon.pixel_size = (size - 4.0 * k) / (maxf(float(icon.texture.get_height()), 1.0) * PX)
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
	if not visible or _bstate.is_empty():
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
		if absf(screen.x - tip.x) > (float(n) * BADGE_GAP * 0.5 + BADGE_PX) * s or screen.y > tip.y + 4.0 \
				or screen.y < tip.y - BADGE_PX * HOVER_SCALE * s - 4.0:
			continue
		for k in n:
			var hk := "%s#%d" % [key, k]
			var size := BADGE_PX * (HOVER_SCALE if hk == _hover_key else 1.0) * s
			var c := tip + Vector2(_badge_x(k, n) * s, -size * 0.5)
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
	return best

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
			var col: Color = Color("eee3c3")
			if sd > -1.0:
				col = Color("28302e")
			elif sd > -4.5:
				col = border
			col.a *= clampf(0.5 - sd, 0.0, 1.0)
			img.set_pixel(x, y, col)
	var tex := ImageTexture.create_from_image(img)
	_plates[building] = tex
	return tex

## Rozetler BUILD_RANGE içinde önce ikon olarak haritanın üstünde durur; BUILD_PIN_RANGE içinde iğneyle yükselir
func _update_building_heights(d: float) -> void:
	var show := 1.0 - smoothstep(BUILD_RANGE * 0.8, BUILD_RANGE, d)
	var grow := 1.0 - smoothstep(BUILD_PIN_RANGE * 0.8, BUILD_PIN_RANGE, d)
	for b: Array in _bpins:
		var root: Node3D = b[0]
		root.visible = show > 0.45
		if root.visible:
			var p: Vector2 = b[1]
			root.position = Vector3(p.x, float(b[2]) + d * (0.004 + BUILD_LIFT * grow), p.y)
