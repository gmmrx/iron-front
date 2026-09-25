class_name RouteLayer
extends Node3D
## "Yollar" harita modu: deniz yolu ağı, ticaret yolları (kaynak rengi, ithalatçıya akış), oyuncunun filo
## rotaları (kesikli) ve hava görev hatları. Üzerine gelince bilgi kartı, tıklayınca seçili rota vurgulanır.
## Kara yolları ve demiryolları (Bölüm B) aynı katmana eklenecek.

const RES_COLORS := {
	"oil": Color("ff7a1a"), "steel": Color("3d8bff"), "aluminium": Color("b9c6d6"),
	"tungsten": Color("a970ff"), "chromium": Color("2fd07a"), "rubber": Color("ffcf2e"),
}
const LANE_COLOR := Color(0.55, 0.72, 0.9, 0.09)
const FLEET_COLOR := Color(0.55, 0.95, 1.0, 0.95)
const AIR_COLOR := Color(1.0, 0.95, 0.75, 0.9)
const SCREEN_W := 0.0021                ## şerit genişliği / kamera uzaklığı (ekranda sabit kalınlık)

var map: MapView3D
var camera: MapCamera3D
var fleets: FleetLayer
var active := false:
	set(v):
		active = v
		visible = v
		if v:
			_trade_dirty = true
			_build_lanes()
		else:
			selected = {}

## Seçilebilir rotalar: {kind, pts: PackedVector2Array, info...}
var routes: Array = []
var selected := {}

var _lanes_mi: MeshInstance3D
var _trade_mi: MeshInstance3D
var _fleet_mi: MeshInstance3D
var _air_mi: MeshInstance3D
var _sel_mi: MeshInstance3D
var _mats: Array[ShaderMaterial] = []
var _trade_routes: Array = []
var _dyn_routes: Array = []
var _trade_dirty := true
var _timer := 0.0

func _ready() -> void:
	visible = false
	_lanes_mi = _mi(0.35, 0.0, 0.0, 1.0)
	_trade_mi = _mi(1.0, 26.0, 60.0, 0.85)
	_fleet_mi = _mi(1.1, 0.0, 0.0, 0.95, 10.0)
	_air_mi = _mi(0.9, 40.0, 70.0, 0.85)
	_sel_mi = _mi(1.8, 30.0, 50.0, 1.0)
	Economy.trade_changed.connect(func() -> void: _trade_dirty = true)
	World.player_changed.connect(func(_t: String) -> void: _trade_dirty = true)

func _mi(wk: float, flow: float, period: float, opacity: float, dash := 0.0) -> MeshInstance3D:
	var m := ShaderMaterial.new()
	m.shader = preload("res://assets/shaders/route.gdshader")
	m.set_shader_parameter("flow_speed", flow)
	m.set_shader_parameter("flow_period", period)
	m.set_shader_parameter("opacity", opacity)
	m.set_shader_parameter("dash", dash)
	m.set_meta("wk", wk)
	m.render_priority = 2
	_mats.append(m)
	var mi := MeshInstance3D.new()
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-1e5, -100, -1e5), Vector3(2e5, 1e4, 2e5))
	add_child(mi)
	return mi

func _process(delta: float) -> void:
	if not active or not World.in_game:
		return
	var w := camera.distance * SCREEN_W
	for m in _mats:
		m.set_shader_parameter("width", w * float(m.get_meta("wk")))
	if _trade_dirty:
		_trade_dirty = false
		_build_trade()
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.4
		_build_dynamic()
		_build_selected()

# ------------------------------------------------------------------ şerit ağı
## lines: [{pts: PackedVector2Array, color: Color, w: float, h: PackedFloat32Array (boşsa deniz)}]
func _ribbon(lines: Array) -> ArrayMesh:
	var verts := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for ln: Dictionary in lines:
		var pts: PackedVector2Array = ln["pts"]
		var n := pts.size()
		if n < 2:
			continue
		var hs: PackedFloat32Array = ln.get("h", PackedFloat32Array())
		var col: Color = ln["color"]
		var wf: float = ln["w"]
		var arc := 0.0
		var base := verts.size()
		for i in n:
			if i > 0:
				arc += pts[i].distance_to(pts[i - 1])
			var t0 := (pts[i] - pts[maxi(i - 1, 0)]).normalized()
			var t1 := (pts[mini(i + 1, n - 1)] - pts[i]).normalized()
			var tg := (t0 + t1).normalized() if (t0 + t1).length_squared() > 1e-6 else (t1 if t1 != Vector2.ZERO else t0)
			var nrm := Vector2(-tg.y, tg.x)
			# köşede şerit incelmesin (miter, sınırlı)
			var segn := Vector2(-t1.y, t1.x) if t1 != Vector2.ZERO else nrm
			nrm /= maxf(absf(nrm.dot(segn)), 0.5)
			var y := hs[i] if i < hs.size() else 0.0
			var p3 := Vector3(pts[i].x, y, pts[i].y)
			verts.append(p3); verts.append(p3)
			uv.append(Vector2(wf, arc)); uv.append(Vector2(-wf, arc))
			uv2.append(nrm); uv2.append(nrm)
			cols.append(col); cols.append(col)
		for i in n - 1:
			var a := base + i * 2
			idx.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
	var mesh := ArrayMesh.new()
	if verts.is_empty():
		return mesh
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh

## Kara üstündeki noktalar için arazi yüksekliği
func _heights(pts: PackedVector2Array) -> PackedFloat32Array:
	var h := PackedFloat32Array()
	for p in pts:
		h.append(maxf(map.height_at(p), 0.0) + 0.6)
	return h

## İki nokta arası (kara) yay: yükseklikli ara noktalar
func _land_line(a: Vector2, b: Vector2, steps := 24, lift := 0.0) -> Array:
	var pts := PackedVector2Array()
	b = World.unwrap_near(a, b)
	for i in steps + 1:
		pts.append(a.lerp(b, float(i) / steps))
	var h := _heights(pts)
	if lift > 0.0:
		for i in h.size():
			h[i] += sin(PI * float(i) / steps) * lift
	return [pts, h]

# ------------------------------------------------------------------ katmanlar
func _build_lanes() -> void:
	if _lanes_mi.mesh != null:
		return
	var lines: Array = []
	var seen := {}
	for p: Province in World.provinces:
		if p == null or p.type != Province.Type.SEA:
			continue
		for n in p.adjacent:
			var q := World.province(n)
			if q == null or q.type != Province.Type.SEA or n < p.id or seen.has(n * 100000 + p.id):
				continue
			seen[n * 100000 + p.id] = true
			var l := SeaLanes.lane(p.id, n)
			if not l.is_empty():
				lines.append({"pts": l[0], "color": LANE_COLOR, "w": 1.0})
	_lanes_mi.mesh = _ribbon(lines)

## Ülkeler arası ticaret: ihracatçı ana limanından ithalatçıya deniz yolu, deniz yolu yoksa kara hattı
func _build_trade() -> void:
	_trade_routes.clear()
	_port_cache.clear()
	_link_cache.clear()
	var me := World.player_tag
	var agg := {}
	for c: Country in World.countries.values():
		for i: Dictionary in c.imports:
			var key := "%s>%s" % [i["from"], c.tag]
			if not agg.has(key):
				agg[key] = {"from": i["from"], "to": c.tag, "res": {}}
			var r: Dictionary = agg[key]["res"]
			r[i["res"]] = float(r.get(i["res"], 0.0)) + float(i["amount"])
	var lines: Array = []
	for key: String in agg:
		var tr_: Dictionary = agg[key]
		var mine: bool = tr_["from"] == me or tr_["to"] == me
		var geo := _trade_geometry(tr_["from"], tr_["to"])
		if geo.is_empty():
			continue
		var top := ""
		var tot := 0.0
		for r: String in tr_["res"]:
			tot += float(tr_["res"][r])
			if top == "" or float(tr_["res"][r]) > float(tr_["res"][top]):
				top = r
		var col: Color = RES_COLORS.get(top, Color.WHITE)
		col.a = 1.0 if mine else 0.3
		var wf := clampf(0.7 + tot * 0.04, 0.7, 1.6) * (1.0 if mine else 0.45)
		var info := {"kind": "trade", "pts": geo[0], "from": tr_["from"], "to": tr_["to"], "res": tr_["res"],
			"km": geo[2], "sea": geo[3], "risk": geo[4], "mine": mine}
		_trade_routes.append(info)
		lines.append({"pts": geo[0], "h": geo[1], "color": col, "w": wf})
	_trade_mi.mesh = _ribbon(lines)
	_rebuild_pick_list()

## [noktalar, yükseklikler, km, deniz mi, tehlikeli deniz bölgesi sayısı] ya da []
## Sınır komşuları karadan; diğerleri: başkent -> (kara) liman -> deniz yolu -> liman -> (kara) başkent
func _trade_geometry(from: String, to: String) -> Array:
	var ca: Country = World.countries[from]
	var cb: Country = World.countries[to]
	if not World.states.has(ca.capital_state) or not World.states.has(cb.capital_state):
		return []
	var a := World.capital_position(from)
	var b := World.capital_position(to)
	var pp := _port_pair(from, to)
	var ep: int = pp[0]
	var ip: int = pp[1]
	var path := PackedInt32Array()
	if not _land_linked(from, to) and ep > 0 and ip > 0 and ep != ip:
		path = Navy.find_path(ep, ip)
	if path.is_empty():
		var ll := _land_line(a, b, 24, 6.0)
		return [ll[0], ll[1], World.geo_km(a, b), false, 0]
	var sea := SeaLanes.polyline(ep, path)
	var pts := PackedVector2Array()
	var hs := PackedFloat32Array()
	var km := 0.0
	# ihracatçı başkentinden limana kara ayağı
	var start := sea[0]
	if a.distance_to(start) > 12.0:
		var l1 := _land_line(a, start, maxi(4, int(a.distance_to(start) / 40.0)))
		pts.append_array(l1[0]); hs.append_array(l1[1])
		km += World.geo_km(a, start)
	for p in sea:
		pts.append(World.unwrap_near(pts[pts.size() - 1], p) if not pts.is_empty() else p)
		hs.append(0.0)
	var prev := ep
	var risk := 0
	for pid in path:
		km += World.distance_km(prev, pid)
		prev = pid
		if World.province(pid).type == Province.Type.SEA and Navy.hostile_sea(pid, to):
			risk += 1
	var end := pts[pts.size() - 1]
	var bb := World.unwrap_near(end, b)
	if bb.distance_to(end) > 12.0:
		var l2 := _land_line(end, bb, maxi(4, int(end.distance_to(bb) / 40.0)))
		var lp: PackedVector2Array = l2[0]
		var lh: PackedFloat32Array = l2[1]
		pts.append_array(lp.slice(1)); hs.append_array(lh.slice(1))
		km += World.geo_km(end, bb)
	return [pts, hs, km, true, risk]

var _port_cache := {}
var _link_cache := {}

## Ülkenin aday ticaret limanları (denize bağlı): kendi limanları, yoksa başkentine en yakın yabancı limanlar
func _trade_ports(tag: String) -> Array[int]:
	if _port_cache.has(tag):
		return _port_cache[tag]
	var cap := World.capital_position(tag)
	var own := Navy.ports_of(tag)
	var cands: Array = []
	for city in World.cities:
		if not city.is_port or not Navy._sea_adj.has(city.province_id):
			continue
		if not own.is_empty() and not city.province_id in own:
			continue
		cands.append([city.position.distance_squared_to(cap), city.province_id])
	cands.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
	var out: Array[int] = []
	for c: Array in cands.slice(0, 5):
		out.append(int(c[1]))
	_port_cache[tag] = out
	return out

## En ucuz liman çifti: kara ayakları deniz yolundan 3 kat pahalı (düz çizgi tahmini)
func _port_pair(from: String, to: String) -> Array:
	var a := World.capital_position(from)
	var b := World.capital_position(to)
	var best := [0, 0]
	var bc := INF
	for ep in _trade_ports(from):
		for ip in _trade_ports(to):
			if ep == ip:
				continue
			var pe := World.province(ep).center
			var pi := World.province(ip).center
			var c := World.geo_km(a, pe) * 3.0 + World.geo_km(pe, pi) + World.geo_km(pi, b) * 3.0
			if c < bc:
				bc = c
				best = [ep, ip]
	return best

## İki ülke karadan sınır komşusu mu
func _land_linked(a: String, b: String) -> bool:
	if _link_cache.is_empty():
		for p: Province in World.provinces:
			if p == null or not p.is_land():
				continue
			var o := World.controller_tag(p.id)
			for n in World.land_neighbors(p.id):
				var o2 := World.controller_tag(n)
				if o2 != o and o2 != "" and o != "":
					_link_cache[o + ">" + o2] = true
	return _link_cache.has(a + ">" + b)

## Oyuncunun hareket eden filoları ve görevdeki hava kanatları (sık yenilenir)
func _build_dynamic() -> void:
	_dyn_routes.clear()
	var fl: Array = []
	for f in Navy.fleets_of(World.player_tag):
		if f.path.is_empty():
			continue
		var pos := fleets.fleet_position(f) if fleets else World.province(f.location).center
		var full := SeaLanes.polyline(f.location, f.path)
		var pts := _trim_from(full, pos)
		var km := 0.0
		var prev := f.location
		for pid in f.path:
			km += Navy.leg_km(prev, pid)
			prev = pid
		km = maxf(km - f.progress, 0.0)
		var info := {"kind": "fleet", "pts": pts, "fleet": f, "km": km, "eta": km / maxf(Navy.speed(f), 1.0) / 24.0}
		_dyn_routes.append(info)
		fl.append({"pts": pts, "color": FLEET_COLOR, "w": 1.0})
	_fleet_mi.mesh = _ribbon(fl)
	var al: Array = []
	for w in Air.wings_of(World.player_tag):
		if not w.on_mission() or not map.airbase_sites.has(w.base):
			continue
		var a: Vector2 = map.airbase_sites[w.base][0]
		var b := World.province(w.zone).center
		var ll := _land_line(a, b, 20, clampf(a.distance_to(b) * 0.08, 4.0, 30.0))
		_dyn_routes.append({"kind": "air", "pts": ll[0], "wing": w})
		al.append({"pts": ll[0], "h": ll[1], "color": AIR_COLOR, "w": 0.8})
	_air_mi.mesh = _ribbon(al)
	_rebuild_pick_list()

## Rotayı filonun bulunduğu noktadan başlat (geçilmiş kısım çizilmez)
func _trim_from(pts: PackedVector2Array, pos: Vector2) -> PackedVector2Array:
	if pts.size() < 2:
		return pts
	var best := 0
	var bd := INF
	for i in mini(pts.size() - 1, 40):
		var d := Geometry2D.get_closest_point_to_segment(pos, pts[i], pts[i + 1]).distance_squared_to(pos)
		if d < bd:
			bd = d
			best = i
	var out := PackedVector2Array([pos])
	out.append_array(pts.slice(best + 1))
	return out

func _build_selected() -> void:
	if selected.is_empty():
		_sel_mi.mesh = null
		return
	var col := Color(1, 1, 1, 0.9)
	if selected["kind"] == "trade":
		col = Color(1.0, 0.95, 0.7, 0.9)
	var pts: PackedVector2Array = selected["pts"]
	var h := PackedFloat32Array()
	if selected["kind"] != "fleet" and not bool(selected.get("sea", true)):
		h = _heights(pts)
	_sel_mi.mesh = _ribbon([{"pts": pts, "h": h, "color": col, "w": 1.0}])

func _rebuild_pick_list() -> void:
	routes = _dyn_routes + _trade_routes

# ------------------------------------------------------------------ seçim
## Dünya noktasına en yakın rota (eşik: kamera uzaklığıyla orantılı); yoksa {}
func pick(world: Vector2) -> Dictionary:
	var thr := camera.distance * 0.012
	var best := {}
	var bd := thr * thr
	for r: Dictionary in routes:
		var pts: PackedVector2Array = r["pts"]
		for i in pts.size() - 1:
			var a := pts[i]
			var b := pts[i + 1]
			if minf(a.x, b.x) - thr > world.x or maxf(a.x, b.x) + thr < world.x:
				continue
			if minf(a.y, b.y) - thr > world.y or maxf(a.y, b.y) + thr < world.y:
				continue
			var d := Geometry2D.get_closest_point_to_segment(world, a, b).distance_squared_to(world)
			# oyuncunun rotaları öncelikli
			if not bool(r.get("mine", true)):
				d *= 1.6
			if d < bd:
				bd = d
				best = r
	return best

func select(r: Dictionary) -> void:
	selected = r
	_build_selected()
