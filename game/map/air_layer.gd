class_name AirLayer
extends Node3D
## Hava kanatlarının görünümü: üslerde park etmiş uçaklar, görev bölgesi üstünde tur atan V düzenleri,
## it dalaşı (iz mermileri, düşen uçak), yakın destek bombaları.

const VISIBLE_DIST := 420.0           ## uçaklar ve kanat sayaçları yakın ve orta görüşte (askerlerden daha uzaktan)
## Her kanat aynı uçak modeliyle (PlaneModel: gövde, dönen pervane, ülkenin bayrağı); iğnelerin yanında küçük durur
const PIN_SCALE := 1.0                ## uçak modelinin boyu (eskiden 0,8: haritada küçük kalıyordu)
const PROP_SPEED := 22.0            ## pervane dönüşü (rad/sn); yerdeki uçağın pervanesi durur
const ZS := 2.6                     ## sabit ölçek: zoom'la uçaklar büyüyüp yer değiştirmez
const ORBIT_R := 13.0               ## tur yarıçapı (× ölçek)
const ALT := 14.0                   ## avcı irtifası (× ölçek); yakın destek alçakta, dalışta yere iner
## V düzeni (yan, geri)
const V_SLOTS := [Vector2(0, 0), Vector2(-5.0, -4.6), Vector2(5.0, -4.6), Vector2(-10.0, -9.2)]

var map: MapView3D
var camera: MapCamera3D
var models: UnitModels
var combat_effects: CombatEffects

var _mmi := {}                      ## "body", "prop", "shadow", "flag:TAG" -> MultiMeshInstance3D
var sun_dir := Vector3(0.35, -0.8, 0.45).normalized()   ## güneş ışığının yönü (main verir): uçak gölgesi buna göre düşer
var _zs := ZS
var _crash_timer := 0.0
var _visual_time := 0.0
var _freeze_flights := false
var _fire_at := {}                  ## representative aircraft -> next burst, real seconds (not per-frame odds)
var _port_target_cache := {}
var _rng := RandomNumberGenerator.new() # Cosmetic variation must not consume the simulation's global RNG.
var _crash_nodes: Array[Dictionary] = []
const MAX_CRASHES := 3

func _ready() -> void:
	_rng.randomize()
	var owners := {}
	for w in Air.wings:
		owners[w.owner] = true
	UnitLayer.prewarm_glyphs(["plane"], owners.keys())
	_multi("body", PlaneModel.body(), PlaneModel.material())
	_multi("prop", PlaneModel.prop(), PlaneModel.material())
	_multi("shadow", _shadow_quad(), _shadow_material(), true)

func _multi(key: String, mesh: Mesh, mat: Material, colors := false) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors
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
		_clear_transients()
		if not World.in_game: _flights.clear()
		return
	# These batches have map-wide bounds: automatic renderer LOD cannot estimate
	# their individual plane distances. Use shared imported LODs by projected size.
	var viewport_height := get_viewport().get_visible_rect().size.y
	for part: String in ["body", "prop"]:
		var mesh := PlaneModel.batch_mesh(part, camera.distance, viewport_height)
		var mm: MultiMesh = _mmi[part].multimesh
		if mm.mesh != mesh:
			mm.mesh = mesh
	var dt := 0.0 if GameClock.paused else minf(delta, 0.1)
	_visual_time += dt
	_freeze_flights = GameClock.paused
	_update_planes(dt) # Counts/fog/parked planes remain current while physical sorties are frozen.
	_freeze_flights = false
	_update_crashes(GameClock.paused)
	if GameClock.paused:
		_update_projectiles(0.0) # Recheck physical bomb visibility without advancing clocks or motion.
		return
	_update_projectiles(dt)
	_queue_losses()
	_crash_timer -= dt
	if _crash_timer <= 0.0 and not _crashes.is_empty() and _crash_nodes.size() < MAX_CRASHES:
		_crash_timer = _rng.randf_range(0.7, 1.4)        # düşüşler gerçek zamanda arka arkaya, üst üste binmez
		var c: Array = _crashes.pop_front()
		_maybe_crash(int(c[0]), String(c[1]))

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
	var sh := _shadow_xf(xf)
	(lists["shadow"] as Array).append(sh[0])
	_shadow_alpha.append(sh[1])
	var fk := "flag:" + owner
	if not _mmi.has(fk):
		_multi(fk, PlaneModel.decal(), PlaneModel.flag_material(World.countries[owner]))
	if not lists.has(fk):
		lists[fk] = []
	(lists[fk] as Array).append(m)

## Uçağın gölgesi: altında yumuşak kenarlı koyu bir leke (güneş gölgesi kapalı; yalnız uçaklar gölge düşürür). Siluet
## yere yassıltılınca ikinci bir uçak gibi okunuyordu. Leke gövde yönünde, kanat açıklığı kadar; uçak yükseldikçe büyür ve
## söner, güneşin tersine yalnız hafifçe kayar. xf: uçağın (model düzeltmesinden önceki) dönüşümü; [dönüşüm, saydamlık]
var _shadow_alpha: Array[float] = []
func _shadow_xf(xf: Transform3D) -> Array:
	var o := xf.origin
	# çizilen arazi (gölgelendiricide örneklenen yükseklik) height_at'ten biraz yukarıda kalabiliyor: leke altında
	# kaybolmasın diye 2,5 birim üstte (tepeden bakışta fark edilmez)
	var g := maxf(map.height_at(Vector2(o.x, o.z)), 0.0) + 2.5
	var span := xf.basis.get_scale().x
	var alt := maxf(o.y - g, 0.0)
	var grow := 1.0 + alt / maxf(span * 5.0, 0.01)
	var along := Vector2(xf.basis.z.x, xf.basis.z.z)
	var yaw := atan2(along.x, along.y) if along.length_squared() > 1e-8 else 0.0
	var off := Vector2(sun_dir.x, sun_dir.z) / maxf(-sun_dir.y, 0.2) * alt * 0.2
	var b := Basis(Vector3.UP, yaw).scaled(Vector3(span * 0.95 * grow, 1.0, span * 0.8 * grow))
	return [Transform3D(b, Vector3(o.x + off.x, g, o.z + off.y)), clampf(0.5 / grow, 0.1, 0.5)]

static func _shadow_quad() -> PlaneMesh:
	var q := PlaneMesh.new()
	q.size = Vector2.ONE
	return q

static func _shadow_material() -> StandardMaterial3D:
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 1.0))
	g.set_color(1, Color(0, 0, 0, 0.0))
	g.add_point(0.45, Color(0, 0, 0, 0.75))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 64
	gt.height = 64
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = gt
	mat.vertex_color_use_as_albedo = true             # örnek rengi: siyah, saydamlığı yüksekliğe göre
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

## Parktaki uçak: pistin yönünde, yere oturmuş, pervane durur
func _parked(lists: Dictionary, owner: String, p: Vector2, yaw: float, i: int) -> void:
	var s := _scale() * 0.65
	var b := Basis(Vector3.UP, -yaw + PI * 0.5 + PI).scaled(Vector3.ONE * s)
	_put(lists, owner, Transform3D(b, Vector3(p.x, maxf(map.height_at(p), 0.0) + PlaneModel.GROUND * s, p.y)), 0.4 + i)

func _update_planes(dt: float = 1.0 / 60.0) -> void:
	var view := _view_rect()
	_shadow_alpha.clear()
	var lists := {}
	for n: String in _mmi:
		lists[n] = []
	var t := _visual_time
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
			# görev bitti ama havada uçak var: anında yok olmaz, üssüne döner ve iner
			var homing := false
			for k in 3:
				var hf: Dictionary = _flights.get("%d:%d" % [w.id, k], {})
				if hf.is_empty() or not bool(hf["flying"]):
					continue
				if not bool(hf.get("homing", false)):
					hf["homing"] = true
					if not bool(hf.get("landing", false)):
						hf["route"] = [[map.airbase_sites[w.base][0], float((hf["pos"] as Vector3).y), "land"]]
						hf["wp"] = 0
				var hp := _fly(w, k, map.airbase_sites[w.base][0], hf["center"], 0.0, String(hf["kind"]), dt)
				if hp.is_empty():
					_flights.erase("%d:%d" % [w.id, k])
					continue
				homing = true
				_draw_flight(lists, w, hp, k, t, view)
			if homing:
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
			if dog and bool(sp[3]):
				var p0: Vector3 = sp[0]
				sp[0] = p0 + Vector3(sin(t * 1.3 + k), sin(t * 1.8 + k) * 0.3, cos(t * 1.0 + k * 2.0)) * 4.0 * _zs
			_draw_flight(lists, w, sp, k, t, view, kind, dog)
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
			if n == "shadow":
				mm.set_instance_color(i, Color(0, 0, 0, _shadow_alpha[i]))

## Uçuştaki bir uçağın çizimi ve olayları (bomba, ateş). sp: _fly'ın dönüşü. Görüş dışındaysa çizilmez (uçuş yine ilerler)
func _draw_flight(lists: Dictionary, w: AirWing, sp: Array, k: int, t: float, view: Rect2, kind := "", dog := false) -> void:
	var p3: Vector3 = sp[0]
	if not view.grow(_scale() * 4.0).has_point(Vector2(p3.x, p3.z)):
		return
	var fwd3: Vector3 = sp[1]
	var bank: float = sp[2]
	var on_run: bool = sp[3]
	var events: Array = sp[4]
	var yaw := atan2(fwd3.x, fwd3.z)
	var pitch := -asin(clampf(fwd3.y, -1.0, 1.0))
	var b := Basis(Vector3.UP, yaw + PI) * Basis(Vector3.RIGHT, -pitch) * Basis(Vector3.FORWARD, bank)
	b = b.scaled(Vector3.ONE * _scale() * float(sp[5]))
	_put(lists, w.owner, Transform3D(b, p3), t * PROP_SPEED + float(k) * 1.3 + float(w.id))
	if GameClock.paused: return
	var key := "%d:%d" % [w.id, k]
	if "drop" in events:
		_drop_bomb(p3, fwd3, w, key)
	var strafing := kind == "dive" and on_run and fwd3.y < -0.05
	if (strafing or (dog and on_run)) and t >= float(_fire_at.get(key, -1.0)):
		_fire_at[key] = t + _rng.randf_range(0.14, 0.24) if strafing else t + _rng.randf_range(0.20, 0.34)
		var aircraft := Transform3D(b, p3) * PlaneModel.fix()
		# Wing-mounted WWII guns: flames stay on the aircraft, not floating beyond the propeller.
		for side: float in [-1.0, 1.0]:
			_fire_burst(aircraft * Vector3(0.24, -0.035, side * 0.18), fwd3, strafing)

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
	if w.mission == AirWing.Mission.PORT_STRIKE:
		# Visual only: the daily damage remains exclusively in Air._port_strikes().
		var cache_key := "%s:%d" % [w.owner, w.zone]
		var cached: Dictionary = _port_target_cache.get(cache_key, {})
		if not cached.is_empty() and _visual_time < float(cached["until"]): return cached["target"]
		var port_target := Vector2.INF
		var port_distance := INF
		for fleet: Fleet in Navy.fleets:
			if not fleet.in_port() or not Diplomacy.are_enemies(fleet.owner, w.owner): continue
			var province := World.province(fleet.location)
			if province == null or Air.distance_km(province.center, zc) > Air.ZONE_KM: continue
			var point := province.center
			if map.harbors.has(fleet.location):
				var harbor: Array = map.harbors[fleet.location]
				point = (harbor[0] as Vector2) + (harbor[1] as Vector2) * 2.0
			else:
				var sea := Navy.sea_for(fleet.location)
				if sea > 0: point = FleetLayer.nearest_water(province.center, _is_water)
			var distance := point.distance_squared_to(zc)
			if distance < port_distance:
				port_distance = distance
				port_target = point
		var result: Array = [port_target, true] if port_target != Vector2.INF else [zc, false]
		_port_target_cache[cache_key] = {"until": _visual_time + 1.0, "target": result}
		return result
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
## Hareketler gerçek zamanda (oyun hızından bağımsız): savaşın canlandırması ağır ve okunur akar; oyun hızlanınca hareket
## hızlanmaz, olaylar (kayıp, düşen uçak) sıklaşır.
const FLY_SPEED := 9.0              ## uçuş hızı (harita birimi / gerçek sn, × ölçek)
const TURN_RATE := 0.75             ## en hızlı dönüş (rad / sn)
const CLIMB_RATE := 3.0             ## irtifa değişimi (birim / sn, × ölçek)
const REST_TIME := 20.0             ## üste yeniden silahlanma (sn)
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
	if _freeze_flights:
		if f.is_empty() or not bool(f.get("flying", false)): return []
		var cached: Array = f.get("render_sp", [])
		if not cached.is_empty(): return [cached[0], cached[1], cached[2], cached[3], [], cached[5]]
		var yaw0 := float(f.get("yaw", 0.0))
		return [f["pos"], Vector3(sin(yaw0), 0.0, cos(yaw0)), 0.0, bool(f.get("run", false)), [], 1.0]
	var changed: bool = not f.is_empty() and ((f["center"] as Vector2).distance_to(center) > 1.0 or f["kind"] != kind)
	if changed and bool(f["flying"]):
		# görev değişti, uçak havada: anında yok olmaz; önce üssüne döner, indikten sonra yeni göreve çıkar
		if not bool(f.get("homing", false)) and not bool(f.get("landing", false)):
			f["homing"] = true
			f["route"] = [[base_p, float((f["pos"] as Vector3).y), "land"]]
			f["wp"] = 0
		changed = false
	if f.is_empty() or changed:
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
	if bool(f.get("landing", false)):
		return _land(f, key, dt)
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
	# havada zeminin altına hiç inmez (kalkışta ve dalışta da gövde yerin üstünde)
	pos.y = maxf(pos.y, maxf(map.height_at(Vector2(pos.x, pos.z)), 0.0) + _clearance())
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
		elif tag == "land":
			# üsse vardı: park yerine süzülür (_land), birden kaybolmaz
			f["landing"] = true
			f["pos"] = pos
			f["yaw"] = yaw
			f["spot"] = base_p + Vector2(-5.0, 9.0)
			f["park_yaw"] = -float(map.airbase_sites[w.base][1]) + PI * 0.5 if map.airbase_sites.has(w.base) else yaw
			f["land_d0"] = maxf((f["spot"] as Vector2).distance_to(Vector2(pos.x, pos.z)), 1.0)
			f["land_y0"] = pos.y
			return _land(f, key, dt)
		wp += 1
		if wp >= route.size():
			f["flying"] = false
			f["rest"] = REST_TIME
			return []
	f["wp"] = wp
	f["pos"] = pos
	f["yaw"] = yaw
	var vy := (pos.y - old_y) / maxf(speed * dt, 0.001)
	var fwd := Vector3(sin(yaw), vy, cos(yaw)).normalized()
	var bank := clampf(-turn / maxf(TURN_RATE * dt, 1e-5) * 0.7, -0.7, 0.7)
	var result: Array = [pos, fwd, bank, bool(f["run"]), events, 1.0]
	f["render_sp"] = result.duplicate() # Dogfight wobble may modify the returned presentation pose.
	return result

## Uçuşta gövdenin yerden en az yüksekliği (modelin en alt noktası yerin üstünde)
func _clearance() -> float:
	return PlaneModel.GROUND * _scale() + 0.4

## İniş: park yerine düz süzülür, yavaşlar, alçalır ve park boyuna küçülür (parktaki uçak 0,65 boyunda); varınca yerde
## bekler. Dönüş: _fly ile aynı biçim, son öğe boy katı
func _land(f: Dictionary, key: String, dt: float) -> Array:
	var spot: Vector2 = f["spot"]
	var pos: Vector3 = f["pos"]
	var yaw: float = f["yaw"]
	var p2 := Vector2(pos.x, pos.z)
	var d := p2.distance_to(spot)
	var prog := 1.0 - clampf(d / float(f["land_d0"]), 0.0, 1.0)
	var speed := FLY_SPEED * _zs * lerpf(0.6, 0.15, prog)
	var want := atan2(spot.x - p2.x, spot.y - p2.y) if d > 1.5 else float(f["park_yaw"])
	yaw = rotate_toward(yaw, want, TURN_RATE * dt * 0.95)
	p2 = p2.move_toward(spot, speed * dt)
	var park_y := maxf(map.height_at(spot), 0.0) + PlaneModel.GROUND * _scale() * 0.65
	var old_y := pos.y
	pos = Vector3(p2.x, lerpf(float(f["land_y0"]), park_y, prog), p2.y)
	f["pos"] = pos
	f["yaw"] = yaw
	if d < 0.3:
		f["flying"] = false
		f["landing"] = false
		f["homing"] = false
		f["rest"] = REST_TIME
		return []
	var vy := (pos.y - old_y) / maxf(speed * dt, 0.001)
	var fwd := Vector3(sin(yaw), clampf(vy, -0.4, 0.4), cos(yaw)).normalized()
	var result: Array = [pos, fwd, 0.0, false, [], lerpf(1.0, 0.65, prog)]
	f["render_sp"] = result.duplicate()
	return result

func _in_dogfight(center: Vector2) -> bool:
	for zone: int in Air.fights:
		if (Air.fights[zone]["pos"] as Vector2).distance_to(center) < ORBIT_R * _zs * 4.0:
			return true
	return false

# ------------------------------------------------------------------ bombalar, atışlar, patlamalar
const MAX_BOMBS := 96
const BOMB_INTERVAL := 0.16          ## measured real seconds between bombs in one representative load
const BOMB_IMPACT_SCALE := 2.1       ## 1.68× former aircraft bomb silhouette; shared budget unchanged
const CRASH_IMPACT_SCALE := 2.65     ## 1.66× former aircraft crash silhouette, below shared scale clamp 3
var _bombs: Array = []              ## [position, velocity, owner, mission province]
var _pending_bombs: Array[Dictionary] = []
var _bomb_clock := 0.0
var _bomb_mmi: MultiMeshInstance3D

func _ensure_fx_meshes() -> void:
	if _bomb_mmi != null:
		return
	var bm := MultiMesh.new()
	bm.transform_format = MultiMesh.TRANSFORM_3D
	var cap := CapsuleMesh.new()
	cap.radius = 0.14
	cap.height = 0.95
	cap.radial_segments = 8
	cap.rings = 3
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.16, 0.18, 0.13)
	cm.roughness = 0.72
	var fin := BoxMesh.new()
	fin.size = Vector3(0.44, 0.23, 0.035)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.append_from(cap, 0, Transform3D.IDENTITY)
	surface.append_from(fin, 0, Transform3D(Basis.IDENTITY, Vector3(0, 0.38, 0)))
	surface.append_from(fin, 0, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 0.38, 0)))
	surface.set_material(cm)
	bm.mesh = surface.commit() # One shared low-poly WWII body plus crossed tail fins.
	_bomb_mmi = MultiMeshInstance3D.new()
	_bomb_mmi.multimesh = bm
	_bomb_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bomb_mmi.custom_aabb = AABB(Vector3(-1e5, -100, -1e5), Vector3(2e5, 1e4, 2e5))
	add_child(_bomb_mmi)

func _drop_bomb(from: Vector3, fwd: Vector3, w: AirWing, aircraft_key := "") -> void:
	if GameClock.paused or _fogged(w): return
	# One payload per sortie event, with actual elapsed release intervals rather than 12 simultaneous bombs.
	var n := 4 if w.type == "bomber" else 2
	for i in n:
		if _bombs.size() + _pending_bombs.size() >= MAX_BOMBS: break
		_pending_bombs.append({"release": _bomb_clock + i * BOMB_INTERVAL, "from": from, "forward": fwd,
			"owner": w.owner, "zone": w.zone, "aircraft": aircraft_key, "delay": i * BOMB_INTERVAL})

func _fire_burst(nose: Vector3, fwd: Vector3, strafing := false) -> void:
	if combat_effects == null or GameClock.paused: return
	combat_effects.muzzle(nose, fwd, "rifle", 0.65)
	for i in 2:
		var dir := (fwd + Vector3(_rng.randf_range(-0.04, 0.04), _rng.randf_range(-0.03, 0.03), _rng.randf_range(-0.04, 0.04))).normalized()
		if strafing:
			var travel := nose.y / maxf(-dir.y, 0.05)
			var aim := nose + dir * minf(travel, 110.0)
			if travel <= 110.0:
				aim.y = maxf(map.height_at(Vector2(aim.x, aim.z)), 0.0) + 0.04
				combat_effects.projectile(nose, aim, "rifle", 0.6)
			else:
				combat_effects.tracer(nose, aim, 180.0, 0.6)
		else:
			# Dogfight rounds never invent a ground hit; gameplay casualties are Air's responsibility.
			combat_effects.tracer(nose, nose + dir * 30.0, 180.0, 0.6)

func _update_projectiles(dt: float) -> void:
	if GameClock.paused:
		_prune_hidden_bombs()
		_draw_bombs()
		return
	_ensure_fx_meshes()
	_bomb_clock += dt
	for i in range(_pending_bombs.size() - 1, -1, -1):
		var drop: Dictionary = _pending_bombs[i]
		if float(drop["release"]) > _bomb_clock: continue
		_pending_bombs.remove_at(i)
		if Military.hidden_at(drop["owner"], int(drop["zone"])): continue
		var fwd: Vector3 = drop["forward"]
		var origin: Vector3 = drop["from"] + fwd * FLY_SPEED * _zs * float(drop["delay"])
		var flight: Dictionary = _flights.get(drop["aircraft"], {})
		if not flight.is_empty() and bool(flight.get("flying", false)): origin = flight["pos"]
		if _fx_hidden(String(drop["owner"]), int(drop["zone"]), origin): continue
		_bombs.append([origin + Vector3(_rng.randf_range(-0.25, 0.25), -0.8, _rng.randf_range(-0.25, 0.25)) * _zs,
			fwd * FLY_SPEED * _zs, drop["owner"], drop["zone"]])
	for i in range(_bombs.size() - 1, -1, -1):
		var b: Array = _bombs[i]
		if _fx_hidden(String(b[2]), int(b[3]), b[0]):
			_bombs.remove_at(i)
			continue
		var v: Vector3 = b[1]
		v.y -= 55.0 * dt
		b[1] = v
		var p: Vector3 = b[0] + v * dt
		b[0] = p
		if _fx_hidden(String(b[2]), int(b[3]), p):
			_bombs.remove_at(i)
			continue # Never draw a round in the newly-entered unknown province, even for one frame.
		var g := maxf(map.height_at(Vector2(p.x, p.z)), 0.0)
		if p.y <= g:
			_blast(Vector3(p.x, g, p.z), String(b[2]), int(b[3]))
			_bombs.remove_at(i)
	_draw_bombs()

func _prune_hidden_bombs() -> void:
	# Observer/player visibility can change while paused. Culling is not simulation advancement.
	for i in range(_bombs.size() - 1, -1, -1):
		var bomb: Array = _bombs[i]
		if _fx_hidden(String(bomb[2]), int(bomb[3]), bomb[0]): _bombs.remove_at(i)
	for i in range(_pending_bombs.size() - 1, -1, -1):
		var drop: Dictionary = _pending_bombs[i]
		var point: Vector3 = drop["from"]
		var flight: Dictionary = _flights.get(drop["aircraft"], {})
		if not flight.is_empty() and bool(flight.get("flying", false)): point = flight["pos"]
		if _fx_hidden(String(drop["owner"]), int(drop["zone"]), point): _pending_bombs.remove_at(i)

func _draw_bombs() -> void:
	if _bomb_mmi == null: return
	var bm := _bomb_mmi.multimesh
	if bm.instance_count < _bombs.size():
		bm.instance_count = mini(MAX_BOMBS, _bombs.size() + 8)
	bm.visible_instance_count = _bombs.size()
	for i in _bombs.size():
		var v2: Vector3 = (_bombs[i][1] as Vector3).normalized()
		var basis := Basis.looking_at(v2, Vector3.UP if absf(v2.y) < 0.99 else Vector3.FORWARD) * Basis(Vector3.RIGHT, PI * 0.5)
		bm.set_instance_transform(i, Transform3D(basis.scaled(Vector3.ONE * _zs * 0.6), _bombs[i][0]))

func _is_water(point: Vector2) -> bool:
	var province := World.province(map.province_at(point))
	return province != null and not province.is_land()

func _blast(pos: Vector3, owner := "", zone := 0) -> void:
	if GameClock.paused or combat_effects == null or (owner != "" and _fx_hidden(owner, zone, pos)): return
	combat_effects.impact(pos, "water" if _is_water(Vector2(pos.x, pos.z)) else "bomb", BOMB_IMPACT_SCALE)

func _crash_impact(pos: Vector3, owner: String, zone: int) -> void:
	if GameClock.paused or combat_effects == null or _fx_hidden(owner, zone, pos): return
	combat_effects.impact(pos, "water" if _is_water(Vector2(pos.x, pos.z)) else "crash", CRASH_IMPACT_SCALE)

func _fx_hidden(owner: String, zone: int, point: Vector3) -> bool:
	if Military.hidden_at(owner, zone): return true
	var pid := map.province_at(Vector2(point.x, point.z))
	return pid > 0 and Military.hidden_at(owner, pid)

func _clear_transients() -> void:
	_bombs.clear()
	_pending_bombs.clear()
	_crashes.clear()
	_planes_seen.clear() # Do not replay losses accumulated while zoomed out.
	_fire_at.clear()
	_port_target_cache.clear()
	_crash_timer = 0.0
	if _bomb_mmi != null: _bomb_mmi.multimesh.visible_instance_count = 0
	for record: Dictionary in _crash_nodes:
		var node: Node3D = record["root"]
		var tween: Tween = record["tween"]
		if tween.is_valid(): tween.kill()
		if is_instance_valid(node): node.queue_free()
	_crash_nodes.clear()

func _update_crashes(paused: bool) -> void:
	for i in range(_crash_nodes.size() - 1, -1, -1):
		var record: Dictionary = _crash_nodes[i]
		var node: Node3D = record["root"]
		if not is_instance_valid(node):
			_crash_nodes.remove_at(i)
			continue
		if _fx_hidden(String(record["owner"]), int(record["zone"]), node.global_position):
			var hidden_tween: Tween = record["tween"]
			if hidden_tween.is_valid(): hidden_tween.kill()
			node.queue_free()
			_crash_nodes.remove_at(i)
			continue
		var tween: Tween = record["tween"]
		if tween.is_valid():
			if paused and tween.is_running(): tween.pause()
			elif not paused and not tween.is_running(): tween.play()

## İt dalaşında ara ara düşen uçak: dumanla yere çakılır, yerde patlama
## Düşen uçaklar gerçek kayıplardan: görevdeki bir kanat uçak kaybettikçe (Air'in saatlik hava savaşı) o bölgede
## sıraya düşüş girer (her ~8 kayıp bir düşüş, bir seferde en çok 3; sıra en çok 6). Oyun hızlanınca kayıp sıklaşır,
## düşüşün kendisi aynı hızda kalır.
var _crashes: Array = []                 ## [bölge, sahip]
var _planes_seen := {}                   ## wing id -> last planes/owner/zone/mission; includes just-destroyed wings
const CRASH_PER := 8
const CRASH_QUEUE := 6

func _queue_losses() -> void:
	var alive := {}
	for w in Air.wings:
		alive[w.id] = true
		var previous: Dictionary = _planes_seen.get(w.id, {})
		var prev := int(previous.get("planes", w.planes))
		_planes_seen[w.id] = {"planes": w.planes, "owner": w.owner, "zone": w.zone, "mission": w.on_mission(), "wing": w}
		if w.planes >= prev or not w.on_mission() or _fogged(w):
			continue
		_queue_crashes(prev - w.planes, w.zone, w.owner)
	# Array removal also happens for disband/country cleanup. The retained wing must really be depleted;
	# disband returns its surviving planes to stock and must never invent a crash.
	for id: int in _planes_seen.keys():
		if alive.has(id): continue
		var previous: Dictionary = _planes_seen[id]
		var removed: AirWing = previous.get("wing")
		if removed != null and removed.planes <= 0 and bool(previous["mission"]) and not Military.hidden_at(previous["owner"], int(previous["zone"])):
			_queue_crashes(int(previous["planes"]), int(previous["zone"]), String(previous["owner"]))
		_planes_seen.erase(id)

func _queue_crashes(lost: int, zone: int, owner: String) -> void:
	var n := clampi(ceili(float(lost) / CRASH_PER), 1, 3)
	for i in n:
		if _crashes.size() < CRASH_QUEUE: _crashes.append([zone, owner])

func _maybe_crash(zone: int, owner: String) -> void:
	var zp := World.province(zone)
	if GameClock.paused or zp == null or not World.countries.has(owner) or Military.hidden_at(owner, zone):
		return
	if _crash_nodes.size() >= MAX_CRASHES:
		return
	var center: Vector2 = Air.fights[zone]["pos"] if Air.fights.has(zone) else zp.center
	if not _view_rect().has_point(center):
		return
	var pos: Vector2 = center + Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * ORBIT_R * _zs
	# düşen uçak: burnu kökün +Z'sine (gittiği yöne), pervane durmuş
	var mi := PlaneModel.make(World.countries[owner])
	mi.transform = Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE * _scale()), Vector3.ZERO)
	var root := Node3D.new()
	var ground := maxf(map.height_at(pos), 0.0)
	root.position = Vector3(pos.x, ground + ALT * _zs, pos.y)
	root.rotation.y = _rng.randf() * TAU
	add_child(root)
	root.add_child(mi)
	if combat_effects != null: combat_effects.trail(root, 0.7, 5.0, true)
	var fwd := Vector3(sin(root.rotation.y), 0, cos(root.rotation.y)) * 25.0 * _zs
	var tw := root.create_tween().set_parallel(true)
	_crash_nodes.append({"root": root, "tween": tw, "owner": owner, "zone": zone})
	tw.tween_property(root, "position", root.position + fwd + Vector3(0, -(ALT * _zs), 0), 5.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(root, "rotation:z", _rng.randf_range(2.0, 5.0), 5.0)
	tw.tween_property(root, "rotation:x", 0.7, 5.0)
	tw.chain().tween_callback(func() -> void:
		mi.visible = false
		_crash_impact(root.global_position, owner, zone))
	tw.chain().tween_interval(3.0)
	tw.chain().tween_callback(root.queue_free)
