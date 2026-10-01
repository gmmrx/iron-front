class_name AirLayer
extends Node3D
## Hava kanatlarının görünümü: üslerde park etmiş uçaklar, görev bölgesi üstünde tur atan V düzenleri,
## it dalaşı (iz mermileri, düşen uçak), yakın destek bombaları.

const VISIBLE_DIST := 700.0           ## uçaklar ve kanat sayaçları yalnız yakında (uzakta kare hızı için çizilmez)
## Her kanat aynı uçak modeliyle (PlaneModel: gövde, dönen pervane, ülkenin bayrağı); iğnelerin yanında küçük durur
const PIN_SCALE := 0.8
const PROP_SPEED := 22.0            ## pervane dönüşü (rad/sn); yerdeki uçağın pervanesi durur
const ZS := 2.6                     ## sabit ölçek: zoom'la uçaklar büyüyüp yer değiştirmez
const ORBIT_R := 13.0               ## tur yarıçapı (× ölçek)
const ALT := 14.0                   ## avcı irtifası (× ölçek); yakın destek alçakta, dalışta yere iner
## V düzeni (yan, geri)
const V_SLOTS := [Vector2(0, 0), Vector2(-5.0, -4.6), Vector2(5.0, -4.6), Vector2(-10.0, -9.2)]

var map: MapView3D
var camera: MapCamera3D
var models: UnitModels

var _mmi := {}                      ## "body", "prop", "flag:TAG" -> MultiMeshInstance3D
var _zs := ZS
var _fx := {}                       ## anahtar -> Node3D (it dalaşı / bombardıman)
var _fx_timer := 0.0
var _crash_timer := 0.0

func _ready() -> void:
	var owners := {}
	for w in Air.wings:
		owners[w.owner] = true
	UnitLayer.prewarm_glyphs(["plane"], owners.keys())
	_multi("body", PlaneModel.body(), PlaneModel.material())
	_multi("prop", PlaneModel.prop(), PlaneModel.material())

func _multi(key: String, mesh: Mesh, mat: Material) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-1e5, -100, -1e5), Vector3(2e5, 1e4, 2e5))
	add_child(mi)
	_mmi[key] = mi
	return mi

func _process(delta: float) -> void:
	var close := camera != null and camera.distance < VISIBLE_DIST and World.in_game
	visible = close
	if not close:
		for ck: String in _counters.keys():
			(_counters[ck] as Node3D).queue_free()
		_counters.clear()
		for k in _fx.keys():
			_fx[k].queue_free()
		_fx.clear()
		return
	_update_planes(minf(delta, 0.1))
	_update_projectiles(minf(delta, 0.1))
	_crash_timer -= delta
	if _crash_timer <= 0.0:
		_crash_timer = randf_range(6.0, 12.0)
		_maybe_crash()

func _view_rect() -> Rect2:
	var r := camera.distance * 1.4
	return Rect2(Vector2(camera.target.x, camera.target.z) - Vector2(r, r * 0.9), Vector2(r * 2, r * 1.8))

func _scale() -> float:
	return PlaneModel.SPAN * _zs * PIN_SCALE

## Bir uçak: gövde, pervane (spin açısıyla dönmüş) ve sahibinin bayrak çıkartması. Model fix() ile -Z'ye bakar (yaw'a PI
## eklenir, yunuslama ters işaretli)
func _put(lists: Dictionary, owner: String, xf: Transform3D, spin: float) -> void:
	var m := xf * PlaneModel.fix()
	(lists["body"] as Array).append(m)
	(lists["prop"] as Array).append(m * PlaneModel.spin(spin))
	var fk := "flag:" + owner
	if not _mmi.has(fk):
		_multi(fk, PlaneModel.decal(), PlaneModel.flag_material(World.countries[owner]))
	if not lists.has(fk):
		lists[fk] = []
	(lists[fk] as Array).append(m)

## Parktaki uçak: pistin yönünde, yere oturmuş, pervane durur
func _parked(lists: Dictionary, owner: String, p: Vector2, yaw: float, i: int) -> void:
	var s := _scale() * 0.65
	var b := Basis(Vector3.UP, -yaw + PI * 0.5 + PI).scaled(Vector3.ONE * s)
	_put(lists, owner, Transform3D(b, Vector3(p.x, maxf(map.height_at(p), 0.0) + PlaneModel.GROUND * s, p.y)), 0.4 + i)

func _update_planes(dt: float = 1.0 / 60.0) -> void:
	var view := _view_rect()
	var lists := {}
	for n: String in _mmi:
		lists[n] = []
	var t := Time.get_ticks_msec() / 1000.0
	# gruplama (tümenler gibi): aynı üs / aynı görev bölgesi + sahip + tür -> tek temsilci düzen, sayı sayaçta
	var group_lead := {}
	var group_planes := {}
	for w in Air.wings:
		if w.planes <= 0 or _fogged(w):
			continue
		var gk := "%s:%s:%s:%d" % [w.owner, w.type, "m" if w.on_mission() else "b", w.zone if w.on_mission() else w.base]
		if not group_lead.has(gk):
			group_lead[gk] = w
		group_planes[gk] = int(group_planes.get(gk, 0)) + w.planes
	var counters_seen := {}
	# kanat levhası üssün üstünde (iğnesiz; uçaklar modelleriyle uçar): üsse bağlı bütün kanatların uçak sayısı
	var base_total := {}
	for w in Air.wings:
		if w.planes > 0 and map.airbase_sites.has(w.base) and not _fogged(w):
			var bk := "%s:%s:%d" % [w.owner, w.type, w.base]
			base_total[bk] = int(base_total.get(bk, 0)) + w.planes
	for bk: String in base_total:
		var sid := int(bk.get_slice(":", 2))
		var bpos: Vector2 = map.airbase_sites[sid][0]
		if view.has_point(bpos):
			_counter(bk, bk.get_slice(":", 0), int(base_total[bk]), Vector3(bpos.x, maxf(map.height_at(bpos), 0.0) + 5.0, bpos.y), counters_seen)
	# üslerde bekleyenler: pist boyunca sıra
	var parked := {}
	for w in Air.wings:
		if w.planes <= 0 or _fogged(w):
			continue
		var gk := "%s:%s:%s:%d" % [w.owner, w.type, "m" if w.on_mission() else "b", w.zone if w.on_mission() else w.base]
		if group_lead[gk] != w:
			continue
		var total: int = group_planes[gk]
		if not w.on_mission():
			if not map.airbase_sites.has(w.base):
				continue
			var site: Array = map.airbase_sites[w.base]
			var pos: Vector2 = site[0]
			if not view.has_point(pos):
				continue
			var yaw: float = site[1]
			var along := Vector2(cos(yaw), sin(yaw))
			# parkta: kanat başına tek, küçük uçak (üs başına en çok üç)
			var i := int(parked.get(w.base, 0))
			if i < 3:
				# üssün güneyinde yan yana: ekranda sayaç iğnesinin (yukarıda) altında kalır, onunla örtüşmez
				_parked(lists, w.owner, pos + Vector2(-5.0 + i * 4.5, 9.0), yaw, i)
			parked[w.base] = i + 1
			continue
		# görevde: seferler — üsten kalkar, hedefe uçar, tek saldırı geçişi yapar (ortada bomba) ya da hedefte devriye
		# gezer (avcı), üsse döner, bir süre yerde bekler (yeniden silahlanma); sonra yeni sefer. Hedefin üstünde
		# durmadan dönüp bomba atmıyorlar.
		var tgt := _wing_target(w)
		var center: Vector2 = tgt[0]
		var attack: bool = tgt[1]
		var base_p: Vector2 = map.airbase_sites[w.base][0] if map.airbase_sites.has(w.base) else center
		if not (view.has_point(center) or view.has_point(base_p)):
			continue
		var dog := _in_dogfight(center)
		var n2 := mini(3, maxi(1, total / 34))
		var ground := maxf(map.height_at(center), 0.0)
		var kind := _kind(w, attack)
		for k in n2:
			var sp := _fly(w, k, base_p, center, ground, kind, dt)
			if sp.is_empty():
				# yerde: üste park etmiş (kanat başına tek)
				if k == 0 and map.airbase_sites.has(w.base) and view.has_point(base_p):
					var yaw0: float = map.airbase_sites[w.base][1]
					var pi0 := int(parked.get(w.base, 0))
					parked[w.base] = pi0 + 1
					_parked(lists, w.owner, base_p + Vector2(-5.0 + float(pi0) * 4.5, 9.0), yaw0, pi0)
				continue
			var p3: Vector3 = sp[0]
			var fwd3: Vector3 = sp[1]
			var bank: float = sp[2]
			var on_run: bool = sp[3]
			var events: Array = sp[4]
			if dog and on_run:
				p3 += Vector3(sin(t * 2.3 + k), sin(t * 3.1 + k) * 0.3, cos(t * 1.7 + k * 2.0)) * 4.0 * _zs
			var yaw := atan2(fwd3.x, fwd3.z)
			var pitch := -asin(clampf(fwd3.y, -1.0, 1.0))
			var b := Basis(Vector3.UP, yaw + PI) * Basis(Vector3.RIGHT, -pitch) * Basis(Vector3.FORWARD, bank)
			b = b.scaled(Vector3.ONE * _scale())
			_put(lists, w.owner, Transform3D(b, p3), t * PROP_SPEED + float(k) * 1.3 + float(w.id))
			if "drop" in events:
				if kind == "level":
					for bi in 3:                                    # bomba dizisi: hedefin üstünde, kısa aralıklarla
						_drop_bomb(p3 + fwd3 * float(bi - 1) * 3.0 * _zs, fwd3, w)
				else:
					_drop_bomb(p3, fwd3, w)
			if kind == "dive" and on_run and fwd3.y < -0.05 and randf() < 0.12:
				_fire_burst(p3 + fwd3 * 2.0 * _zs, fwd3)          # dalışta makineli ateşi
			if dog and on_run and randf() < 0.05:
				_fire_burst(p3 + fwd3 * 2.0 * _zs, fwd3)          # it dalaşı
	for ck: String in _counters.keys():
		if not counters_seen.has(ck):
			(_counters[ck] as Node3D).queue_free()
			_counters.erase(ck)
	for n: String in lists:
		var mm: MultiMesh = _mmi[n].multimesh
		var arr: Array = lists[n]
		if mm.instance_count < arr.size():
			mm.instance_count = arr.size() + 8
		mm.visible_instance_count = arr.size()
		for i in arr.size():
			mm.set_instance_transform(i, arr[i])

# ------------------------------------------------------------------ sayaçlar
var _counters := {}                 ## grup anahtarı -> Node3D (plaka + sayı)

## Hava grubu sayacı haritada gösterilmez (uçak modelleri uçar; kanatlar hava panelinden yönetilir): "uçak | sayı"
## iğnesi haritayı dolduruyordu. SHOW_COUNTERS açılırsa eski rozet/levha döner.
const SHOW_COUNTERS := false

## Hava grubu sayacı: ülke renginde küçük plaka, uçak simgesi ve toplam uçak sayısı
func _counter(key: String, owner: String, total: int, pos: Vector3, seen: Dictionary) -> void:
	if not SHOW_COUNTERS:
		return
	seen[key] = true
	var root: Node3D = _counters.get(key)
	if root == null:
		root = Node3D.new()
		add_child(root)
		var plate := Sprite3D.new()
		plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		plate.fixed_size = true
		# "uçak | sayı" rozeti (tümen ve filo rozetleriyle aynı biçim)
		plate.pixel_size = UnitLayer.CHIP_GPX
		plate.no_depth_test = true
		plate.render_priority = 10
		plate.texture = UnitLayer.flag_marker(owner, false, true, "plane")
		plate.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		root.add_child(plate)
		var lbl := Label3D.new()
		lbl.font = UiTheme.bold_font()
		lbl.font_size = 30
		lbl.outline_size = 3
		lbl.outline_modulate = Color(0.04, 0.04, 0.04, 0.9)
		lbl.modulate = Color("ece3c6")
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.fixed_size = true
		lbl.pixel_size = UnitLayer.PIXEL * 0.8
		lbl.no_depth_test = true
		lbl.render_priority = 12
		lbl.outline_render_priority = 11
		lbl.offset = UnitLayer.chip_label_off(true)
		lbl.name = "n"
		root.add_child(lbl)
		_counters[key] = root
	# yakında yuvarlak iğne başı (iğnenin ucunda), uzakta "uçak | sayı" rozeti (iğnesiz)
	var close := camera.distance <= UnitLayer.CARD_DIST
	if PinLayer.active():
		var g := maxf(map.height_at(Vector2(pos.x, pos.z)), 0.0)
		pos.y = g + (PinLayer.lift(camera.distance, PinLayer.AIR_LIFT) if close else camera.distance * UnitLayer.CARD_LIFT)
	if root.get_meta("close", null) != close:
		root.set_meta("close", close)
		var plate: Sprite3D = root.get_child(0)
		plate.texture = UnitLayer.plate_tex(owner, false, "plane") if close else UnitLayer.flag_marker(owner, false, true, "plane")
		plate.pixel_size = UnitLayer.CARD_PX * UnitLayer.GLYPH_PLATE_K if close else UnitLayer.CHIP_GPX
		var nl: Label3D = root.get_node("n")
		nl.offset = UnitLayer.plate_label_off(0.0, UnitLayer.GLYPH_PLATE_K) if close else UnitLayer.chip_label_off(true)
		nl.set_meta("base", 42 if close else 30)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if close else HORIZONTAL_ALIGNMENT_CENTER
		nl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM if close else VERTICAL_ALIGNMENT_CENTER
	root.position = pos
	root.visible = camera.distance < VISIBLE_DIST
	var nlb: Label3D = root.get_node("n")
	UnitLayer.set_count(nlb, total, int(nlb.get_meta("base", 30)))

## İğne haritası: görünen hava kanadı sayaçlarının kökleri
func pin_roots() -> Array[Node3D]:
	var out: Array[Node3D] = []
	if camera.distance > UnitLayer.CARD_DIST:
		return out                          # uzakta rozetler iğnesiz
	for key: String in _counters:
		var root: Node3D = _counters[key]
		if root.visible:
			out.append(root)
	return out


## Savaş sisi: yabancı kanat, görevdeyse görev bölgesi, üsteyse üssü bulutun altındaysa çizilmez
func _fogged(w: AirWing) -> bool:
	if w.on_mission():
		return Military.hidden_at(w.owner, w.zone)
	var st: StateRegion = World.states.get(w.base)
	return st != null and not st.provinces.is_empty() and Military.hidden_at(w.owner, st.provinces[0])

## Kanadın hedefi: [nokta, saldırı mı]. Yakın destek/bombardıman: bölgedeki bir muharebede düşman tümen konumu.
func _wing_target(w: AirWing) -> Array:
	var zc := World.province(w.zone).center
	if w.mission == AirWing.Mission.RECON:
		return [zc, false]                     # keşif: bölgenin üstünde geniş tur
	# bombardıman: hedef eyaletin en büyük şehri (sanayinin durduğu yer) üstünden geçiş
	if w.mission == AirWing.Mission.BOMBING:
		var st := World.state_of_province(w.zone)
		var city: City = st.largest_city() if st else null
		return [World.province(city.province_id).center if city else zc, true]
	if w.mission == AirWing.Mission.CAS or w.type == "bomber":
		var best := Vector2.INF
		var bd := INF
		for pid: int in Military.battles:
			if not Air.covers(w, pid):
				continue
			var b: Dictionary = Military.battles[pid]
			var side: Array = b["defenders"]
			var atk: Array = b["attackers"]
			if not atk.is_empty() and Diplomacy.are_enemies((atk[0] as Division).owner, w.owner):
				side = atk
			for d: Division in side:
				var a: Array = models.anchors.get(d.id, []) if models else []
				var pos: Vector2 = a[0] if not a.is_empty() else World.province(d.province).center
				var dd := pos.distance_squared_to(zc)
				if dd < bd:
					bd = dd
					best = pos
		if best != Vector2.INF:
			return [best, true]
	return [zc, false]

## Uçuş: her uçak (kanat başına en çok üç temsilci) gerçek uçuş gibi hareket eder — sabit hızla ileri gider, bir sonraki
## ara noktaya en çok TURN_RATE ile döner (keskin köşe yapamaz, dönerken yatar), irtifası CLIMB_RATE ile değişir. Sefer:
## üsten kalkış → hedefe uçuş → görev → üsse dönüş → iniş → yerde bekleme (yeniden silahlanma) → yeni sefer. Görevine göre:
## - "dive" (yakın destek, liman baskını): hedefe alçalarak dalış, dibinde bomba, dalışta makineli ateşi; toparlanıp döner;
## - "level" (taktik bombardıman): yüksekte düz geçiş, hedefin üstünde üç bombalık dizi;
## - "patrol" (avcı, hava üstünlüğü): hedefin çevresinde geniş devriye döngüsü (it dalaşı varsa orada manevra).
## Aynı kanadın uçakları arka arkaya kalkar ve aynı yoldan gider. Hedefin üstünde durmadan dönüp bomba atmazlar.
const FLY_SPEED := 16.0             ## uçuş hızı (harita birimi / gerçek sn, × ölçek)
const TURN_RATE := 1.3              ## en hızlı dönüş (rad / sn)
const CLIMB_RATE := 5.0             ## irtifa değişimi (birim / sn, × ölçek)
const REST_TIME := 14.0             ## üste yeniden silahlanma (sn)
const RUN_HALF := 14.0              ## saldırı geçişinin yarı uzunluğu (× ölçek)
const CAPTURE := 6.0                ## ara noktaya bu kadar yaklaşınca sıradakine geçer (× ölçek)
var _flights := {}                  ## "kanat:uçak" -> uçuş durumu

func _kind(w: AirWing, attack: bool) -> String:
	if not attack:
		return "patrol"
	return "level" if w.type == "bomber" else "dive"

## Seferin ara noktaları: [[2B nokta, irtifa, etiket], ...] — etiket "run" (iş başladı), "drop" (bomba), "" (yol)
## Hedef üsse yakınsa saldırıya yandan girilir (üssün hemen önünde geri dönüş olmasın).
func _route(w: AirWing, base_p: Vector2, center: Vector2, ground: float, kind: String) -> Array:
	var dist := base_p.distance_to(center)
	var head := (center - base_p).normalized() if dist > 0.5 else Vector2(1, 0)
	head = head.rotated((float(w.id % 5) - 2.0) * 0.12)
	var side := Vector2(head.y, -head.x) * (1.0 if w.id % 2 == 0 else -1.0)
	var R := RUN_HALF * _zs
	var base_h := maxf(map.height_at(base_p), 0.0) + 1.0
	var cruise := ground + ALT * _zs * (1.35 if kind == "patrol" else (1.2 if kind == "level" else 1.0))
	var low := ground + 3.0 * _zs
	var run_dir := head if dist > R * 1.8 else (head * 0.5 + side * 0.85).normalized()
	var entry := center - run_dir * R * 1.3
	var out: Array = []
	match kind:
		"dive":
			out.append([entry, cruise, "run"])
			out.append([center - run_dir * R * 0.4, lerpf(cruise, low, 0.5), ""])
			out.append([center, low, "drop"])
			out.append([center + run_dir * R * 0.9, lerpf(low, cruise, 0.7), "end"])
		"level":
			out.append([entry, cruise, "run"])
			out.append([center, cruise, "drop"])
			out.append([center + run_dir * R * 1.3, cruise, "end"])
		_:
			var a0 := atan2(entry.y - center.y, entry.x - center.x)
			var dirn := 1.0 if w.id % 2 == 0 else -1.0
			for i in 10:
				var a := a0 + dirn * TAU * 1.5 * float(i) / 9.0
				out.append([center + Vector2(cos(a), sin(a)) * R * 1.5, cruise, "run" if i == 0 else ("end" if i == 9 else "")])
	out.append([base_p, base_h, "land"])
	return out

## Bir uçağın bu kareki uçuşu: [konum, ileri, yatış, görevde mi, olaylar] ya da [] (yerde). Durum _flights'ta.
func _fly(w: AirWing, k: int, base_p: Vector2, center: Vector2, ground: float, kind: String, dt: float) -> Array:
	var key := "%d:%d" % [w.id, k]
	var f: Dictionary = _flights.get(key, {})
	if f.is_empty() or (f["center"] as Vector2).distance_to(center) > 1.0 or f["kind"] != kind:
		# yeni görev: aynı kanadın uçakları arka arkaya, kanatlar birbirinden kaydırılmış kalkar
		f = {"center": center, "kind": kind, "rest": fposmod(float(w.id) * 2.3, REST_TIME) + float(k) * 0.5, "flying": false}
		_flights[key] = f
	if not bool(f["flying"]):
		f["rest"] = float(f["rest"]) - dt
		if float(f["rest"]) > 0.0:
			return []
		var route := _route(w, base_p, center, ground, kind)
		var first: Vector2 = route[0][0]
		f["route"] = route
		f["wp"] = 0
		f["pos"] = Vector3(base_p.x, maxf(map.height_at(base_p), 0.0) + 1.0, base_p.y)
		f["yaw"] = atan2(first.x - base_p.x, first.y - base_p.y)
		f["run"] = false
		f["flying"] = true
	var route: Array = f["route"]
	var wp: int = f["wp"]
	var pos: Vector3 = f["pos"]
	var yaw: float = f["yaw"]
	var tgt: Array = route[wp]
	var tp: Vector2 = tgt[0]
	var to := tp - Vector2(pos.x, pos.z)
	var diff := wrapf(atan2(to.x, to.y) - yaw, -PI, PI)
	var turn := clampf(diff, -TURN_RATE * dt, TURN_RATE * dt)
	yaw += turn
	var speed := FLY_SPEED * _zs
	var step := Vector2(sin(yaw), cos(yaw)) * speed * dt
	var old_y := pos.y
	pos = Vector3(pos.x + step.x, move_toward(pos.y, float(tgt[1]), CLIMB_RATE * _zs * dt), pos.z + step.y)
	var events: Array = []
	# ara noktaya varıldı (ya da ıskalanıp arkada kaldı): sıradakine
	var dnow := tp.distance_to(Vector2(pos.x, pos.z))
	if dnow < CAPTURE * _zs or (dnow < CAPTURE * _zs * 3.0 and absf(diff) > 1.8):
		var tag: String = tgt[2]
		if tag == "run":
			f["run"] = true
		elif tag == "drop":
			events.append("drop")
		elif tag == "end":
			f["run"] = false
		wp += 1
		if wp >= route.size():
			# indi: yerde bekler, sonra yeni sefer
			f["flying"] = false
			f["rest"] = REST_TIME
			return []
	f["wp"] = wp
	f["pos"] = pos
	f["yaw"] = yaw
	var vy := (pos.y - old_y) / maxf(speed * dt, 0.001)
	var fwd := Vector3(sin(yaw), vy, cos(yaw)).normalized()
	var bank := clampf(-turn / maxf(TURN_RATE * dt, 1e-5) * 0.7, -0.7, 0.7)
	return [pos, fwd, bank, bool(f["run"]), events]

func _in_dogfight(center: Vector2) -> bool:
	for zone: int in Air.fights:
		if (Air.fights[zone]["pos"] as Vector2).distance_to(center) < ORBIT_R * _zs * 4.0:
			return true
	return false

# ------------------------------------------------------------------ bombalar, atışlar, patlamalar
var _bombs: Array = []              ## [konum, hız]
var _tracers: Array = []            ## [konum, hız, ömür]
var _blasts := 0
var _bomb_mmi: MultiMeshInstance3D
var _tracer_mmi: MultiMeshInstance3D

func _ensure_fx_meshes() -> void:
	if _bomb_mmi != null:
		return
	var bm := MultiMesh.new()
	bm.transform_format = MultiMesh.TRANSFORM_3D
	var cap := CapsuleMesh.new()
	cap.radius = 0.18
	cap.height = 1.1
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.12, 0.12, 0.12)
	cap.material = cm
	bm.mesh = cap
	_bomb_mmi = MultiMeshInstance3D.new()
	_bomb_mmi.multimesh = bm
	_bomb_mmi.custom_aabb = AABB(Vector3(-1e5, -100, -1e5), Vector3(2e5, 1e4, 2e5))
	add_child(_bomb_mmi)
	var tm := MultiMesh.new()
	tm.transform_format = MultiMesh.TRANSFORM_3D
	var box := BoxMesh.new()
	box.size = Vector3(0.12, 0.12, 2.4)
	var tmat := StandardMaterial3D.new()
	tmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tmat.albedo_color = Color(1.0, 0.8, 0.35)
	tmat.emission_enabled = true
	tmat.emission = Color(1.0, 0.7, 0.3)
	tmat.emission_energy_multiplier = 3.0
	box.material = tmat
	tm.mesh = box
	_tracer_mmi = MultiMeshInstance3D.new()
	_tracer_mmi.multimesh = tm
	_tracer_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tracer_mmi.custom_aabb = AABB(Vector3(-1e5, -100, -1e5), Vector3(2e5, 1e4, 2e5))
	add_child(_tracer_mmi)

func _drop_bomb(from: Vector3, fwd: Vector3, w: AirWing) -> void:
	# yakın destek 2 bomba, bombardıman uçağı 4'lü dizi (arka arkaya düşer)
	var n := 4 if w.type == "bomber" else 2
	for i in n:
		var back := -fwd * float(i) * 1.6 * _zs
		_bombs.append([from + back + Vector3(randf_range(-0.5, 0.5), -0.8, randf_range(-0.5, 0.5)) * _zs, fwd * 9.0 * _zs])

func _fire_burst(nose: Vector3, fwd: Vector3) -> void:
	for i in 3:
		var dir := (fwd + Vector3(randf_range(-0.04, 0.04), randf_range(-0.03, 0.03), randf_range(-0.04, 0.04))).normalized()
		_tracers.append([nose + dir * i * 1.5, dir * 90.0, 0.22])

func _update_projectiles(dt: float) -> void:
	_ensure_fx_meshes()
	for i in range(_bombs.size() - 1, -1, -1):
		var b: Array = _bombs[i]
		var v: Vector3 = b[1]
		v.y -= 55.0 * dt
		b[1] = v
		var p: Vector3 = b[0] + v * dt
		b[0] = p
		var g := maxf(map.height_at(Vector2(p.x, p.z)), 0.0)
		if p.y <= g:
			_blast(Vector3(p.x, g, p.z))
			_bombs.remove_at(i)
	for i in range(_tracers.size() - 1, -1, -1):
		var tr: Array = _tracers[i]
		tr[0] = (tr[0] as Vector3) + (tr[1] as Vector3) * dt
		tr[2] = float(tr[2]) - dt
		if float(tr[2]) <= 0.0:
			_tracers.remove_at(i)
	var bm := _bomb_mmi.multimesh
	if bm.instance_count < _bombs.size():
		bm.instance_count = _bombs.size() + 8
	bm.visible_instance_count = _bombs.size()
	for i in _bombs.size():
		var v2: Vector3 = (_bombs[i][1] as Vector3).normalized()
		var basis := Basis.looking_at(v2, Vector3.UP if absf(v2.y) < 0.99 else Vector3.FORWARD) * Basis(Vector3.RIGHT, PI * 0.5)
		bm.set_instance_transform(i, Transform3D(basis.scaled(Vector3.ONE * _zs * 0.6), _bombs[i][0]))
	var tm := _tracer_mmi.multimesh
	if tm.instance_count < _tracers.size():
		tm.instance_count = _tracers.size() + 16
	tm.visible_instance_count = _tracers.size()
	for i in _tracers.size():
		var d: Vector3 = (_tracers[i][1] as Vector3).normalized()
		var basis2 := Basis.looking_at(d, Vector3.UP if absf(d.y) < 0.99 else Vector3.FORWARD)
		tm.set_instance_transform(i, Transform3D(basis2, _tracers[i][0]))

## Tek seferlik isabet patlaması (ateş topu + toprak + is), sonra kendini siler
func _blast(pos: Vector3) -> void:
	if _blasts >= 20:
		return
	_blasts += 1
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	var ex := models._particles_explosion()
	ex.scale = Vector3.ONE * 0.8
	var st: Array[Node] = [ex]
	while not st.is_empty():
		var n: Node = st.pop_back()
		if n is GPUParticles3D:
			var gp := n as GPUParticles3D
			gp.one_shot = true
			gp.explosiveness = 0.9
			gp.amount = maxi(gp.amount / 2, 3)
		st.append_array(n.get_children())
	# kısa ömürlü ateş topu yerine: emitter'ları dışarıda kapatmadan önce ekle
	root.add_child(ex)
	get_tree().create_timer(4.0).timeout.connect(func() -> void:
		_blasts -= 1
		root.queue_free())

## İt dalaşında ara ara düşen uçak: dumanla yere çakılır, yerde patlama
func _maybe_crash() -> void:
	var view := _view_rect()
	var zones: Array = []
	for zone: int in Air.fights:
		if view.has_point(Air.fights[zone]["pos"]):
			zones.append(zone)
	if zones.is_empty():
		return
	var zone: int = zones[randi() % zones.size()]
	var pos: Vector2 = Air.fights[zone]["pos"] + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * ORBIT_R * _zs
	var tags: Array = Air.fights[zone]["tags"]
	var owner: String = tags[randi() % tags.size()] if not tags.is_empty() else World.player_tag
	if not World.countries.has(owner):
		return
	# düşen uçak: burnu kökün +Z'sine (gittiği yöne), pervane durmuş
	var mi := PlaneModel.make(World.countries[owner])
	mi.transform = Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE * _scale()), Vector3.ZERO)
	var root := Node3D.new()
	var ground := maxf(map.height_at(pos), 0.0)
	root.position = Vector3(pos.x, ground + ALT * _zs, pos.y)
	root.rotation.y = randf() * TAU
	add_child(root)
	root.add_child(mi)
	var smoke := models._particles_smoke()
	smoke.scale = Vector3.ONE * 0.5
	smoke.local_coords = false
	root.add_child(smoke)
	var fire := models._particles_flash()
	fire.scale = Vector3.ONE * 0.3
	root.add_child(fire)
	var fwd := Vector3(sin(root.rotation.y), 0, cos(root.rotation.y)) * 25.0 * _zs
	var tw := root.create_tween().set_parallel(true)
	tw.tween_property(root, "position", root.position + fwd + Vector3(0, -(ALT * _zs), 0), 3.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(root, "rotation:z", randf_range(2.0, 5.0), 3.2)
	tw.tween_property(root, "rotation:x", 0.7, 3.2)
	tw.chain().tween_callback(func() -> void:
		mi.visible = false
		var ex := models._particles_explosion()
		ex.scale = Vector3.ONE * 1.6
		ex.one_shot = true
		ex.emitting = true
		root.add_child(ex))
	tw.chain().tween_interval(3.0)
	tw.chain().tween_callback(root.queue_free)
