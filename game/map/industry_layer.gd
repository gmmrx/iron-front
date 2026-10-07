class_name IndustryLayer
extends Node3D
## İnşaat binaları haritada: her tamamlanan inşaat seviyesi yapıldığı eyalette bir tesis olarak dikilir
## (sivil/askerî fabrika, rafineri, uçaksavar bataryası, demiryolu deposu; kıyıda tersane ve deniz üssü).
## Sürmekte olan inşaat, tesisin dikileceği parselde şantiye olarak görünür. Modeller: assets/models/industry.gltf
## (tools/blender/build_industry.py). Hareketli parçalar (vinç kolu, uçaksavar topu, meşale alevi) ayrı mesh'lerdir;
## building_part.gdshader onları GPU'da oynatır, böylece binlerce tesis MultiMesh ile çizilir.
##
## Parseller: her eyalette ana şehrin çevresinde halkalar (kara) ve kıyıda (tersane, deniz üssü) oyun başında bir kez
## seçilir ve türlere sabit sırayla dağıtılır; yeni bir tesis eklenince eskiler yer değiştirmez.

const LIB_PATH := "res://assets/models/industry.gltf"
const PART_SHADER := preload("res://assets/shaders/building_part.gdshader")
const BUILDING_SHADER := preload("res://assets/shaders/building.gdshader")
const SCALE := 5.2                 ## model birimi → dünya birimi (tesis ≈ 5 dünya birimi: dört-beş şehir evi)
const RANGE := 350.0               ## tesis modelleri yalnız yakın diorama görüşünde
const CHUNK := 384.0
const MIN_GAP := 5.6               ## iki tesis arası en az uzaklık
## bina türü -> [model adları (çeşit), en çok tesis, kıyı mı]
const TYPES := {
	"civilian_factory": [["ind_civilian_factory_0", "ind_civilian_factory_1"], 8, false],
	"military_factory": [["ind_military_factory"], 8, false],
	"synthetic_refinery": [["ind_refinery"], 3, false],
	"anti_air": [["ind_anti_air"], 4, false],
	"infrastructure": [["ind_rail"], 1, false],
	"dockyard": [["ind_dockyard"], 4, true],
	"naval_base": [["ind_naval_base"], 3, true],
}
## kara parsellerinin türlere dağıtım sırası (bir eyalette ilk parseller en sık yapılan türlere)
const LAND_ORDER := ["civilian_factory", "military_factory", "infrastructure", "civilian_factory", "military_factory",
	"anti_air", "civilian_factory", "synthetic_refinery", "military_factory", "civilian_factory", "anti_air",
	"military_factory", "civilian_factory", "synthetic_refinery", "military_factory", "civilian_factory", "anti_air",
	"civilian_factory", "military_factory", "synthetic_refinery", "civilian_factory", "military_factory", "anti_air",
	"civilian_factory", "military_factory"]
const COAST_ORDER := ["dockyard", "naval_base", "dockyard", "naval_base", "dockyard", "dockyard", "naval_base"]
## parça -> [shader modu, hız, genlik]; mod 0 = durağan (demiryolu vagonları seviyeye göre eklenir; tesislerin
## demiryolu kolu "__rail" yalnız bölgede tren istasyonu (altyapı depo seviyesi) varsa gösterilir)
const PART_MODES := {
	"ind_dockyard__jib": [1, 0.22, 1.1],
	"ind_site__jib": [2, 0.16, 0.0],
	"ind_anti_air__gun": [1, 0.45, 1.3],
	"ind_refinery__flame": [3, 1.0, 0.0],
	"ind_rail__wagons": [0, 0.0, 0.0],
	"ind_civilian_factory_0__rail": [0, 0.0, 0.0],
	"ind_civilian_factory_1__rail": [0, 0.0, 0.0],
	"ind_dockyard__rail": [0, 0.0, 0.0],
	"ind_naval_base__rail": [0, 0.0, 0.0],
}

var map: MapView3D
var occupied: Dictionary            ## CityLayer'ın işgal ızgarası (şehirlerle çakışmasın)
var city_positions: Dictionary      ## city id -> model merkezi
var cell_size := 3.0

var _meshes := {}                   ## model adı -> Mesh
var _parts := {}                    ## model adı -> [[parça adı, Mesh, [Transform3D pivot...]]]
var _slots := {}                    ## sid -> {tür: [[Vector2, yaw], ...]}
var _nodes := {}                    ## [mesh adı, chunk] -> MultiMeshInstance3D
var _dirty := false
var _flat := {}                     ## düzleştirilmiş parseller ("sid:tür:i")
var active_plots: Array[Vector2] = []  ## şu an bina ya da şantiye olan parseller (birimler bunlara oturmaz)
var version := 0                    ## her yenilemede artar (birim yerleri önbelleği için)
var _refresh_timer := 0.0
const FLAT_RADIUS := SCALE * 0.68   ## avlunun köşelerine kadar düz
## İğne tasarımı: tesis modelleri ve parsel düzleştirmesi yok; parseller, dolu parseller ve sürüm (iğneler, birim yerleri)
## hesaplanmaya devam eder. Modelleri geri açmak için true.
const SHOW_MODELS := false

func _ready() -> void:
	if SHOW_MODELS:
		_load_library()
	_build_slots()
	refresh()
	Economy.building_completed.connect(func(_t: String, _s: int, _b: String) -> void: _dirty = true)
	Economy.construction_changed.connect(func(_t: String) -> void: _dirty = true)
	World.ownership_changed.connect(func() -> void: _dirty = true)

func _process(_delta: float) -> void:
	_refresh_timer -= _delta
	if _dirty and _refresh_timer <= 0.0:
		_dirty = false
		_refresh_timer = 1.0            # en çok saniyede bir (yapay zekâ inşaatları 5× hızda her karede değiştiriyordu)
		refresh()

# ------------------------------------------------------------------ kütüphane
func _load_library() -> void:
	var scene: Node = (load(LIB_PATH) as PackedScene).instantiate()
	var nodes := {}
	var stack: Array[Node] = [scene]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Node3D:
			nodes[String(n.name)] = n
		stack.append_array(n.get_children())
	for name: String in nodes:
		var parts := name.split("__")
		if parts.size() == 1 and nodes[name] is MeshInstance3D:
			_meshes[name] = _convert((nodes[name] as MeshInstance3D).mesh, "")
	for name: String in nodes:
		var parts := name.split("__")
		if parts.size() != 2 or not nodes[name] is MeshInstance3D or not nodes.has(parts[0]):
			continue
		var base: Node3D = nodes[parts[0]]
		var pivots: Array[Transform3D] = [Transform3D(Basis(), (nodes[name] as Node3D).position - base.position)]
		var k := 1
		while nodes.has("%s__p%d" % [name, k]):
			pivots.append(Transform3D(Basis(), (nodes["%s__p%d" % [name, k]] as Node3D).position - base.position))
			k += 1
		if not _parts.has(parts[0]):
			_parts[parts[0]] = []
		_parts[parts[0]].append([name, _convert((nodes[name] as MeshInstance3D).mesh, name), pivots])
	scene.free()

## İçe aktarılan malzemeyi bina shader'ına (ya da parça shader'ına) çevirir: doku, normal, pürüzlülük, alev ışıması
func _convert(src: Mesh, part_name: String) -> Mesh:
	var mesh: Mesh = src.duplicate()
	for i in mesh.get_surface_count():
		var m := mesh.surface_get_material(i)
		var sm := ShaderMaterial.new()
		sm.shader = PART_SHADER if part_name != "" else BUILDING_SHADER
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
			if part_name != "" and bm.emission_enabled:
				sm.set_shader_parameter("emission", Vector3(bm.emission.r, bm.emission.g, bm.emission.b) * bm.emission_energy_multiplier * 1.5)
		if part_name != "":
			var pm: Array = PART_MODES.get(part_name, [0, 0.0, 0.0])
			sm.set_shader_parameter("mode", int(pm[0]))
			sm.set_shader_parameter("speed", float(pm[1]))
			sm.set_shader_parameter("amp", float(pm[2]))
		mesh.surface_set_material(i, sm)
	return mesh

# ------------------------------------------------------------------ parseller
static func _hash(n: int) -> int:
	var x := n * 747796405 + 2891336453
	x = ((x >> 13) ^ x) * 1274126177
	return absi(x ^ (x >> 16))

func _cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / cell_size), floori(p.y / cell_size))

func _land_in_state(p: Vector2, sid: int) -> bool:
	var pid := map.province_at(p)
	if pid <= 0:
		return false
	var pr := World.province(pid)
	return pr != null and pr.is_land() and pr.state_id == sid

## Tesisin kapladığı hücreler (ayak izi ≈ SCALE)
func _footprint(p: Vector2) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var r := SCALE * 0.5
	var c0 := _cell(p - Vector2(r, r))
	var c1 := _cell(p + Vector2(r, r))
	for y in range(c0.y, c1.y + 1):
		for x in range(c0.x, c1.x + 1):
			out.append(Vector2i(x, y))
	return out

func _free(p: Vector2, taken: Array) -> bool:
	for c in _footprint(p):
		if occupied.has(c):
			return false
	for q: Array in taken:
		if (q[0] as Vector2).distance_to(p) < MIN_GAP:
			return false
	return true

func _take(p: Vector2) -> void:
	for c in _footprint(p):
		occupied[c] = true

func _build_slots() -> void:
	var ordered: Array = World.states.values()
	ordered.sort_custom(func(a: StateRegion, b: StateRegion) -> bool: return a.id < b.id)
	for st: StateRegion in ordered:
		var center := st.center
		var radius := 3.0
		var main: City = st.largest_city()
		if main:
			center = city_positions.get(main.id, main.position)
			radius = CityLayer3D.footprint_radius(main)
		var taken: Array = []
		var slots := {}
		# kıyı parselleri: şehirden denize doğru yürüyüp kıyıda dur (tesisin su tarafı denize bakar)
		if st.coastal:
			var coast: Array = []
			var phase := float(_hash(st.id + 5) % 628) / 100.0
			for i in 24:
				if coast.size() >= COAST_ORDER.size():
					break
				var a := phase + TAU * float(i) / 24.0
				var dir := Vector2(cos(a), sin(a))
				var hit = _walk_to_water(center + dir * radius * 0.6, dir, radius * 3.0 + SCALE * 3.0)
				if hit == null:
					continue
				var p: Vector2 = hit
				if not _land_in_state(p, st.id) or not _free(p, taken):
					continue
				var yaw := atan2(dir.x, dir.y)
				coast.append([p, yaw])
				taken.append([p, yaw])
				_take(p)
			for i in coast.size():
				var t: String = COAST_ORDER[i]
				if not slots.has(t):
					slots[t] = []
				slots[t].append(coast[i])
		# kara parselleri: şehrin çevresinde halkalar
		var land: Array = []
		var phase2 := float(_hash(st.id + 77) % 628) / 100.0
		for ring in 5:
			var r := radius * 1.02 + SCALE * 0.62 + ring * SCALE * 1.18
			var n := 8 + ring * 3
			for i in n:
				if land.size() >= LAND_ORDER.size():
					break
				var a := phase2 + TAU * float(i) / float(n) + ring * 0.37
				var p := center + Vector2(cos(a), sin(a)) * r
				if not _land_in_state(p, st.id) or not _free(p, taken):
					continue
				var yaw := -a + PI * 0.5 + float(_hash(st.id * 31 + i) % 3 - 1) * 0.35
				land.append([p, yaw])
				taken.append([p, yaw])
				_take(p)
		for i in land.size():
			var t: String = LAND_ORDER[i]
			if not slots.has(t):
				slots[t] = []
			slots[t].append(land[i])
		if not slots.is_empty():
			_slots[st.id] = slots

func _walk_to_water(start: Vector2, dir: Vector2, max_len: float) -> Variant:
	var step := 1.2
	var pos := start
	var prev := start
	var s := 0.0
	while s < max_len:
		var pr := World.province(map.province_at(pos))
		if pr == null:
			return null
		if not pr.is_land():
			return prev - dir * SCALE * 0.12 if s > 0.0 else null     # kıyıdan biraz içeri: tesisin kara tarafı karada kalsın
		prev = pos
		pos += dir * step
		s += step
	return null

# ------------------------------------------------------------------ tesisleri diz
## Kaç tesis: seviye başına bir tane (türün tavanına kadar); demiryolu deposu altyapı 2'den itibaren tek, vagonları seviyeyle artar
func _count(st: StateRegion, t: String) -> int:
	var lv := st.building_level(t)
	if t == "infrastructure":
		return 1 if lv >= 2 else 0
	return mini(lv, int(TYPES[t][1]))

func refresh() -> void:
	var lists := {}                       # [mesh adı, chunk] -> [Transform3D]
	var queued := {}                      # sid -> {tür: sayı}
	for c: Country in World.countries.values():
		for pr: ConstructionProject in c.construction_queue:
			if not TYPES.has(pr.building):
				continue
			if not queued.has(pr.state_id):
				queued[pr.state_id] = {}
			queued[pr.state_id][pr.building] = int(queued[pr.state_id].get(pr.building, 0)) + 1
	var old_plots := active_plots.duplicate()
	active_plots.clear()
	for sid: int in _slots:
		var st: StateRegion = World.states[sid]
		var slots: Dictionary = _slots[sid]
		var station := _count(st, "infrastructure") > 0
		for t: String in slots:
			var list: Array = slots[t]
			var n := mini(_count(st, t), list.size())
			var variants: Array = TYPES[t][0]
			for i in n:
				active_plots.append(list[i][0])
				if not SHOW_MODELS:
					continue
				var model: String = variants[(i + sid) % variants.size()]
				_flatten(sid, t, i, list[i])
				var xf := _xf(list[i])
				_push(lists, model, xf)
				for part: Array in _parts.get(model, []):
					var pivots: Array = part[2]
					var shown := pivots.size()
					if t == "infrastructure":
						shown = clampi(st.building_level(t) - 1, 0, pivots.size())
					elif String(part[0]).ends_with("__rail"):
						shown = 1 if station else 0
					for k in shown:
						_push(lists, part[0], xf * (pivots[k] as Transform3D))
			# sürmekte olan inşaat: sıradaki boş parselde şantiye (demiryolunda depo yoksa)
			var q := int(queued.get(sid, {}).get(t, 0))
			if q > 0 and n < list.size() and not (t == "infrastructure" and n > 0):
				active_plots.append(list[n][0])
				if not SHOW_MODELS:
					continue
				_flatten(sid, t, n, list[n])
				var sxf := _xf(list[n])
				_push(lists, "ind_site", sxf)
				for part: Array in _parts.get("ind_site", []):
					for pv: Transform3D in part[2]:
						_push(lists, part[0], sxf * pv)
	# birim yerleri önbelleği (CityLayer3D.unit_spot) yalnız dolu parseller değişince yenilenir: yapay zekâ inşaat
	# kuyruğunu sık değiştirir, her yenilemede bütün tümenlerin yeri baştan aranıyordu (~20 ms)
	if active_plots != old_plots:
		version += 1
	if OS.has_environment("INDDBG"):          # hata ayıklama: INDDBG=1 → örnek ve şantiye sayısı
		var sites := 0
		var total := 0
		for key: Array in lists:
			total += (lists[key] as Array).size()
			if key[0] == "ind_site":
				sites += (lists[key] as Array).size()
		print("INDDBG refresh: %d örnek, %d şantiye, %d kuyruk eyaleti" % [total, sites, queued.size()])
	if not SHOW_MODELS:
		return
	map.commit_height()
	for key: Array in _nodes:
		if not lists.has(key):
			(_nodes[key] as MultiMeshInstance3D).multimesh.instance_count = 0
	for key: Array in lists:
		var node := _node(key)
		if node == null:
			continue
		var arr: Array = lists[key]
		node.multimesh.instance_count = arr.size()
		for i in arr.size():
			node.multimesh.set_instance_transform(i, arr[i])

## İnşaat yapılan parsel düz olur (bir kez); tesisin yüksekliği düzleşmiş araziden okunur
func _flatten(sid: int, t: String, i: int, slot: Array) -> void:
	var key := "%d:%s:%d" % [sid, t, i]
	if _flat.has(key):
		return
	_flat[key] = true
	var dbg := OS.has_environment("INDDBG")
	var before := _relief(slot[0]) if dbg else 0.0
	map.flatten_site(slot[0], FLAT_RADIUS)
	if dbg and before > 0.05:
		print("INDDBG düzleşme %s: %.3f → %.3f" % [key, before, _relief(slot[0])])

## Parsel içindeki yükseklik farkı (en yüksek − en alçak, dünya birimi)
func _relief(p: Vector2) -> float:
	var lo := INF
	var hi := -INF
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var h := map.height_at(p + Vector2(dx, dy) * SCALE * 0.22)
			lo = minf(lo, h)
			hi = maxf(hi, h)
	return hi - lo

## İğne haritası: eyaletin bu türdeki i. parselinin yeri (parsel yoksa Vector2.INF; fazlası son parsele düşer)
func slot_position(sid: int, t: String, i: int) -> Vector2:
	var list: Array = _slots.get(sid, {}).get(t, [])
	if list.is_empty():
		return Vector2.INF
	return list[clampi(i, 0, list.size() - 1)][0]

## İğne haritası: eyaletin bütün sanayi parsellerinin yerleri
func state_slots(sid: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for t: String in _slots.get(sid, {}):
		for s: Array in _slots[sid][t]:
			out.append(s[0])
	return out

## Haritada model olarak gösterilen seviye sayısı (şantiye bundan sonraki parselde)
func shown_count(st: StateRegion, t: String) -> int:
	return _count(st, t)

## Bütün parseller (ağaç katmanı bu alanları boş bırakır)
func plot_positions() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for sid: int in _slots:
		for t: String in _slots[sid]:
			for s: Array in _slots[sid][t]:
				out.append(s[0])
	return out

func _xf(slot: Array) -> Transform3D:
	var p: Vector2 = slot[0]
	return Transform3D(Basis(Vector3.UP, float(slot[1])).scaled(Vector3.ONE * SCALE), Vector3(p.x, maxf(map.height_at(p), 0.0) + 0.03, p.y))

func _push(lists: Dictionary, name: String, xf: Transform3D) -> void:
	var key := [name, Vector2i(floori(xf.origin.x / CHUNK), floori(xf.origin.z / CHUNK))]
	if not lists.has(key):
		lists[key] = []
	lists[key].append(xf)

func _mesh(name: String) -> Mesh:
	if _meshes.has(name):
		return _meshes[name]
	var parts := name.split("__")
	for part: Array in _parts.get(parts[0], []):
		if part[0] == name:
			return part[1]
	return null

func _node(key: Array) -> MultiMeshInstance3D:
	if _nodes.has(key):
		return _nodes[key]
	var mesh := _mesh(key[0])
	if mesh == null:
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.visibility_range_end = RANGE
	mmi.visibility_range_end_margin = RANGE * 0.12
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(mmi)
	_nodes[key] = mmi
	return mmi

## Test/kontrol: eyaletteki tesis sayıları (tür -> [dikilen, parsel])
func state_summary(sid: int) -> Dictionary:
	var out := {}
	var st: StateRegion = World.states[sid]
	for t: String in _slots.get(sid, {}):
		out[t] = [mini(_count(st, t), (_slots[sid][t] as Array).size()), (_slots[sid][t] as Array).size()]
	return out
