extends "res://tests/test_case.gd"
## Harita katmanlarının mantığı (görüntüye bakmadan, sayıyla): tümen yolu (PathMotion) sürekli ve varışta hedefte;
## hareket okları (UnitLayer._curve/_ribbon) renk, son, üçgen ve UV; hava durumu (WeatherLayer.weather_at)
## belirlenimci ve mevsime/enleme uygun; zoom kiplerinde sayaç/bayrak/gizli görünürlüğü (UnitLayer, FleetLayer).

const Probe := preload("res://tests/map_probe.gd")

## Yalnız bölge görüntüsüyle çalışan harita (ağır dokular yüklenmez, sahneye eklenmez): yükseklik düz
class ProbeMap extends MapView3D:
	func province_at(world_xz: Vector2) -> int:
		return Probe.province_at(world_xz)
	func height_at(_world_xz: Vector2) -> float:
		return 0.0

## Düz haritada tek bir koni tepe (araziye oturma sınaması)
class HillMap extends ProbeMap:
	var hill := Vector2.INF
	func height_at(world_xz: Vector2) -> float:
		return 0.0 if hill == Vector2.INF else maxf(0.0, 24.0 - world_xz.distance_to(hill) * 0.8)

func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree

## Kendi toprağında en az `steps` bölge ötedeki bir hedefe yol alan tümen
func _mover(tag: String, steps: int) -> Array:
	for d in Military.country_divisions(tag):
		if d.training > 0 or not World.province(d.province).is_land():
			continue
		var seen := {d.province: true}
		var frontier: Array[int] = [d.province]
		for i in steps:
			var nxt: Array[int] = []
			for cur in frontier:
				for n in World.land_neighbors(cur):
					if not seen.has(n) and World.controller_tag(n) == tag:
						seen[n] = true
						nxt.append(n)
			frontier = nxt
		if frontier.is_empty():
			continue
		if Military.order_move(d, frontier[0]) and d.path.size() >= steps:
			return [d, frontier[0]]
	return []

# ------------------------------------------------------------------ tümen yolu
func test_division_motion_continuous() -> void:
	Probe.ensure()
	var m := _mover("TUR", 4)
	if not check(not m.is_empty(), "4 bölge ötesine yürüyen Türk tümeni"):
		return
	var d: Division = m[0]
	var target: int = m[1]
	var prev: Vector2 = PathMotion.division(d)[0]
	var worst := 0.0
	var bad: Array = []
	for h in 24 * 40:
		GameClock.advance_hours(1)
		for frac in [0.0, 0.25, 0.5, 0.75]:
			GameClock._accum = frac
			var p: Vector2 = PathMotion.division(d)[0]
			var step := prev.distance_to(p)
			# çeyrek saatte en çok ~yürüyüş hızının birkaç katı; bölge merkezleri arası sıçrama onlarca piksel
			if step > 4.0:
				bad.append("saat %d +%.2f: %.1f piksel sıçrama (%s)" % [h, frac, step, str(d.path)])
			worst = maxf(worst, step)
			prev = p
		if d.path.is_empty():
			break
	GameClock._accum = 0.0
	check(d.path.is_empty(), "tümen hedefe vardı")
	eq(d.province, target, "varış bölgesi")
	var fin: Array = PathMotion.division(d)
	eq(Probe.province_at(fin[0]), target, "varışta görsel konum hedef bölgede")
	check(not fin[2], "varınca hareket bitti")
	none(bad.slice(0, 10), "zıplama")

# ------------------------------------------------------------------ hareket okları
func _arrow_arrays(ul: UnitLayer) -> Array:
	var mesh := ul._arrows.mesh as ImmediateMesh
	if mesh == null or mesh.get_surface_count() == 0:
		return []
	return mesh.surface_get_arrays(0)

func test_arrow_geometry_and_color() -> void:
	Probe.ensure()
	var m := _mover("TUR", 3)
	if not check(not m.is_empty(), "yürüyen tümen"):
		return
	var d: Division = m[0]
	var target: int = m[1]
	var ul := UnitLayer.new()
	var pm := ProbeMap.new()
	ul.map = pm
	ul._arrows = MeshInstance3D.new()
	ul.selected = [d]
	# _curve: kesim başına 8 örnek, uçlar korunur
	var pts: Array[Vector2] = [World.province(d.province).center]
	for pid in d.path:
		pts.append(World.province(pid).center)
	var cv := ul._curve(pts)
	eq(cv.size(), (pts.size() - 1) * 8 + 1, "eğri örnek sayısı")
	check(cv[0] == pts[0] and cv[cv.size() - 1] == pts[pts.size() - 1], "eğri uçları rota uçlarında")
	# kendi toprağında hareket: ülkenin renginde
	ul._draw_arrows()
	var arr := _arrow_arrays(ul)
	if check(not arr.is_empty(), "ok çizildi"):
		_check_arrow(arr, UnitLayer.move_color("TUR"), pts[pts.size() - 1], target, "hareket")
	# düşman toprağına: kırmızı
	var foe := ""
	for n in World.land_neighbors(target):
		var ctl := World.controller_tag(n)
		if ctl != "" and ctl != "TUR":
			foe = ctl
			break
	if foe == "":
		foe = "IRQ"
	country("TUR").war_goals[foe] = true
	Diplomacy.declare_war("TUR", foe)
	World.set_controller(target, foe)
	ul._draw_arrows()
	arr = _arrow_arrays(ul)
	if check(not arr.is_empty(), "taarruz oku çizildi"):
		_check_arrow(arr, UnitLayer.ARROW_ATTACK, pts[pts.size() - 1], target, "taarruz")
	ul._arrows.free()
	ul.free()
	pm.free()

func _check_arrow(arr: Array, col: Color, tip: Vector2, target: int, ctx: String) -> void:
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var uv2: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV2]
	gt(verts.size(), 6, ctx + ": köşe sayısı")
	eq(verts.size() % 3, 0, ctx + ": üçgen listesi (köşe sayısı 3'ün katı)")
	var wrong := 0
	for c in cols:                           # köşe rengi 8 bit saklanır (aşağı kırpılır)
		if absf(c.r - col.r) > 0.005 or absf(c.g - col.g) > 0.005 or absf(c.b - col.b) > 0.005:
			wrong += 1
	eq(wrong, 0, ctx + ": yanlış renkli köşe (ör. %s, beklenen %s)" % [str(cols[0]) if cols.size() > 0 else "-", str(col)])
	var uv_bad := 0
	for uv in uvs:
		if uv.x < -0.001 or uv.x > 1.001 or uv.y < -0.001 or uv.y > 1.001:
			uv_bad += 1
	eq(uv_bad, 0, ctx + ": UV [0,1] dışında")
	var s_bad := 0
	for u in uv2:
		if u.x < -0.001 or not is_finite(u.x):
			s_bad += 1
	eq(s_bad, 0, ctx + ": gövde mesafesi (UV2) geçersiz")
	# okun sonu (ok başı yok, akan işaretler): son şeridin iki uç köşesinin ortası rota sonunda, hedef bölgede
	var end := (verts[verts.size() - 2] + verts[verts.size() - 1]) * 0.5
	near(Vector2(end.x, end.z).distance_to(tip), 0.0, 0.01, ctx + ": okun sonu rota sonunda")
	eq(Probe.province_at(Vector2(end.x, end.z)), target, ctx + ": okun sonu hedef bölgede")

# ------------------------------------------------------------------ hava durumu
func _weather() -> WeatherLayer:
	var wl := WeatherLayer.new()
	wl.map = ProbeMap.new()
	return wl

func _free_weather(wl: WeatherLayer) -> void:
	wl.map.free()
	wl.free()

## Kara bölgesi merkezleri; north_only: yalnız kuzey yarıküre (kış/yaz karşılaştırması için)
func _land_points(lat_lo: float, lat_hi: float, limit: int, north_only := false) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for pid in range(1, World.provinces.size(), 3):
		var p := World.province(pid)
		var lat := p.lonlat.y if p else 0.0
		if north_only and lat < 0.0:
			continue
		if p and p.is_land() and absf(lat) > lat_lo and absf(lat) < lat_hi:
			out.append(p.center)
			if out.size() >= limit:
				break
	return out

func test_weather_deterministic() -> void:
	Probe.ensure()
	var a := _weather()
	var b := _weather()
	var pts := _land_points(0.0, 70.0, 400)
	var diff := 0
	for day in [3, 40, 200]:
		World.day_count = day
		for p in pts:
			var w1: Array = a.weather_at(p)
			a._cache.clear()
			var w2: Array = a.weather_at(p)
			var w3: Array = b.weather_at(p)
			if w1 != w2 or w1 != w3:
				diff += 1
	eq(diff, 0, "aynı gün, hücre ve bölgede farklı hava")
	# sorgu sırasından bağımsız: aynı hücrede başka bölgedeki nokta önce sorulsa da sonuç değişmez
	var order_diff := 0
	World.day_count = 77
	for p in pts:
		var fresh := _weather()
		var direct: Array = fresh.weather_at(p)
		fresh._cache.clear()
		var cell := Vector2(floorf(p.x / WeatherLayer.CELL), floorf(p.y / WeatherLayer.CELL)) * WeatherLayer.CELL
		for q in [cell + Vector2(2, 2), cell + Vector2(WeatherLayer.CELL - 2, 2), cell + Vector2(2, WeatherLayer.CELL - 2)]:
			fresh.weather_at(q)
		if fresh.weather_at(p) != direct:
			order_diff += 1
		_free_weather(fresh)
	eq(order_diff, 0, "hücrede önce başka nokta sorulunca farklı hava")
	_free_weather(a)
	_free_weather(b)

func test_weather_seasons_and_latitudes() -> void:
	Probe.ensure()
	var wl := _weather()
	var north := _land_points(50.0, 70.0, 300, true)
	var desert := _land_points(15.0, 32.0, 300)
	var temperate := _land_points(40.0, 55.0, 300, true)
	gt(north.size(), 50, "kuzey noktası")
	gt(desert.size(), 50, "çöl kuşağı noktası")
	# kış: kuzeyde yağış kardır
	GameClock.month = 1
	var falls := 0
	var rain_north := 0
	for day in range(0, 60, 3):
		World.day_count = day
		for p in north:
			var w: Array = wl.weather_at(p)
			if w[0] != WeatherLayer.Kind.CLEAR:
				falls += 1
				if w[0] != WeatherLayer.Kind.SNOW:
					rain_north += 1
	gt(falls, 0, "kışın kuzeyde yağış olur")
	eq(rain_north, 0, "kışın kuzeydeki yağış kar")
	# yaz: 55°'nin altında kar yok
	GameClock.month = 7
	var summer_snow := 0
	for day in range(0, 60, 3):
		World.day_count = day
		for p in temperate:
			if wl.weather_at(p)[0] == WeatherLayer.Kind.SNOW:
				summer_snow += 1
	eq(summer_snow, 0, "yazın ılıman kuşakta kar")
	# çöl kuşağı (15–32°) ılıman kuşaktan çok daha kuru
	GameClock.month = 5
	var dr := 0
	var tr_ := 0
	for day in range(0, 90, 3):
		World.day_count = day
		for p in desert:
			if wl.weather_at(p)[0] != WeatherLayer.Kind.CLEAR:
				dr += 1
		for p in temperate:
			if wl.weather_at(p)[0] != WeatherLayer.Kind.CLEAR:
				tr_ += 1
	var dfrac := float(dr) / float(desert.size() * 30)
	var tfrac := float(tr_) / float(temperate.size() * 30)
	check(dfrac < tfrac * 0.5, "çöl kuşağında yağış oranı %.2f, ılımanda %.2f (yarısından az olmalı)" % [dfrac, tfrac])
	_free_weather(wl)

# ------------------------------------------------------------------ zoom kipleri
func test_unit_layer_zoom_modes() -> void:
	var ul := UnitLayer.new()
	var pm := ProbeMap.new()
	var cam := MapCamera3D.new()
	ul.map = pm
	ul.camera = cam
	_tree().root.add_child(ul)
	cam.distance = 500.0
	ul._process(0.5)                        # sayaçlar kurulur
	gt(ul._counters.size(), 100, "tümen sayacı")
	var modes := [[UnitLayer.COMPOSE_DIST - 20.0, "bileşim"], [UnitLayer.CARD_DIST - 100.0, "sayı"], [UnitLayer.CARD_DIST + 100.0, "bayrak"],
		[UnitLayer.HIDE_ALL + 100.0, "gizli"]]
	for mode: Array in modes:
		cam.distance = mode[0]
		ul._vis_dirty = true
		ul._process(0.01)
		# birlik kartı: çok yakında altında içindeki tabur türleri küçük kartlarla, uzaklaşınca yok (figürlerde hiç
		# kurulmaz: yakında figür durur)
		var comp_wrong := 0
		for key: String in ul._counters:
			var subs: Array = ul._counters[key]["subs"]
			if subs.is_empty() != UnitLayer.FIGURES:
				comp_wrong += 1
			for sub: Array in subs:
				if (sub[0] as Node3D).visible != (mode[1] == "bileşim" and not UnitLayer.FIGURES):
					comp_wrong += 1
		eq(comp_wrong, 0, "kartın altındaki birlik türleri, kip: %s" % mode[1])
		var wrong := 0
		for key: String in ul._counters:
			var c: Dictionary = ul._counters[key]
			var fig: Node3D = c.get("fig")
			if UnitLayer.FIGURES and mode[1] in ["bileşim", "sayı"]:
				# yakında kaideli figür: levha, sayı yazısı ve rozet gizli
				if fig == null or not fig.visible or c["bg"].visible or c["label"].visible or c["flag"].visible: wrong += 1
				if not c.get("merged", false) and not c["root"].visible: wrong += 1
				continue
			if fig != null and fig.visible: wrong += 1
			match mode[1]:
				"bileşim":
					# dağılmış: ana kart yerine içindeki türlerin kartları
					if c["bg"].visible or c["label"].visible or c["flag"].visible: wrong += 1
				"sayı":
					if not c["bg"].visible or not c["label"].visible or c["flag"].visible: wrong += 1
				"bayrak":
					# "bayrak | sayı" rozeti
					if c["bg"].visible or c["label"].visible or not c["flag"].visible or not c["clabel"].visible: wrong += 1
				"gizli":
					if c["root"].visible: wrong += 1
			if mode[1] != "gizli" and not c.get("merged", false) and not c["root"].visible:
				wrong += 1
		eq(wrong, 0, "tümen sayaçları, kip: %s" % mode[1])
	_tree().root.remove_child(ul)
	ul.free()
	pm.free()
	cam.free()

func test_fleet_layer_zoom_modes() -> void:
	Probe.ensure()
	var fl := FleetLayer.new()
	var pm := ProbeMap.new()
	var cam := MapCamera3D.new()
	fl.map = pm
	fl.camera = cam
	_tree().root.add_child(fl)
	# yakında yuvarlak iğne başı, uzakta "gemi | sayı" rozeti (ikisi de sayılı), çok uzakta yok
	var modes := [[UnitLayer.CARD_DIST - 100.0, "baş"], [UnitLayer.CARD_DIST + 200.0, "rozet"], [UnitLayer.HIDE_ALL + 100.0, "gizli"]]
	for mode: Array in modes:
		cam.distance = mode[0]
		fl._process(0.05)
		var wrong := 0
		var shown := 0
		for f in Navy.fleets:
			var c: Dictionary = fl._counters.get(f.id, {})
			if c.is_empty():
				wrong += 1
				continue
			if int(fl._positions[f.id][4]) > 0:
				if c["root"].visible: wrong += 1     # aynı yerdeki ikinci filo: tek sayaç
				continue
			match mode[1]:
				"baş", "rozet":
					if not c["root"].visible or not c["bg"].visible or not c["label"].visible: wrong += 1
					var want := UnitLayer.CARD_PX * UnitLayer.GLYPH_PLATE_K if mode[1] == "baş" else UnitLayer.CHIP_GPX
					if not is_equal_approx((c["bg"] as Sprite3D).pixel_size, want): wrong += 1
				"gizli":
					if c["root"].visible: wrong += 1
			if c["root"].visible:
				shown += 1
		eq(wrong, 0, "filo sayaçları, kip: %s" % mode[1])
		if mode[1] == "gizli":
			eq(shown, 0, "çok uzakta görünen filo sayacı")
		else:
			gt(shown, 10, "görünen filo sayacı (%s)" % mode[1])
	# iğne tasarımı: 3D gemi hiç çizilmez (filo = sayaç iğnesi), yakında da
	for dist: float in [FleetLayer.SHIP_DIST - 100.0, FleetLayer.SHIP_DIST + 100.0]:
		cam.distance = dist
		fl._process(0.05)
		check(not fl._mmi["destroyer"].visible, "iğne tasarımında 3D gemi yok (%d)" % int(dist))
	_tree().root.remove_child(fl)
	fl.free()
	pm.free()
	cam.free()

# ------------------------------------------------------------------ emirde sayaç yerinde kalır
## Her bölgede duruş noktası merkezin 10 birim sağında (şehrin/yapıların yanı gibi)
class SpotCities extends CityLayer3D:
	func unit_spot(_pid: int, p: Vector2) -> Vector2:
		return p + Vector2(10.0, 0.0)

## Sayaçlar bölgenin olağan noktasında durur (UnitLayer._tile_spot): yığın testlerinde seçilen bölgelerin noktası tek yer
class SameSpotCities extends CityLayer3D:
	var spot := Vector2.INF
	var pids := {}
	var at := {}                                  ## bölge -> elle verilen nokta (yürüyüş testleri)
	func unit_spot(pid: int, p: Vector2) -> Vector2:
		if at.has(pid):
			return at[pid]
		return spot if pids.has(pid) and spot != Vector2.INF else p + Vector2(10.0, 0.0)

## Kontrollü yürüyüş: tümen kendi bölgesinden "to" bölgesine yürür (gerçek yol: d.path, ilerleme km); iki bölgenin olağan
## noktası elle (a çıkış, b varış). Figür bu iki nokta arasında düz yürür (UnitLayer._walk_pos). Dönen: yürüyüşün km'si
func _walk_setup(ul: UnitLayer, um: UnitModels, sc: SameSpotCities, d: Division, to: int, a: Vector2, b: Vector2) -> float:
	sc.at[d.province] = a
	sc.at[to] = b
	d.path = [to] as Array[int]
	d.progress = 0.0
	ul._walk.erase(d.id)
	ul._dirty = true
	ul._timer = 1.0
	ul._process(0.05)
	um._update_anchors()
	return World.distance_km(d.province, to)

## Yürüyüşün f'si (0..1) kadarı yürünmüş: bir kare
func _walk_step(ul: UnitLayer, um: UnitModels, ds: Array, km: Array, f: float) -> void:
	for i in ds.size():
		(ds[i] as Division).progress = float(km[i]) * f
	um.static_epoch += 1
	ul._follow_anchors(0.05)

## Yürüyüşün varışı: tümeni olmayan bir Türk kara bölgesi (noktası elle verilince orada duran figür yürümesin)
func _other_land(avoid: Array) -> int:
	var occupied := {}
	for d in Military.divisions:
		occupied[d.province] = true
	for d in Military.country_divisions("TUR"):
		for n in World.land_neighbors(d.province):
			if World.controller_tag(n) == "TUR" and not occupied.has(n) and not n in avoid:
				return n
	return 0

func test_order_keeps_counter_in_place() -> void:
	Probe.ensure()
	var m := _mover("TUR", 1)
	if not check(not m.is_empty(), "yürüyebilecek tümen"):
		return
	var d: Division = m[0]
	var target: int = m[1]
	Military.stop(d)
	var um := UnitModels.new()
	var sc := SpotCities.new()
	um.cities = sc
	um._update_anchors()
	var idle: Vector2 = um.anchors[d.id][0]
	near(idle.distance_to(World.province(d.province).center + Vector2(10.0, 0.0)), 0.0, 0.001, "duran tümen duruş noktasında")
	check(Military.order_move(d, target), "yürüme emri")
	GameClock._accum = 0.0
	um._update_anchors()
	var start: Vector2 = um.anchors[d.id][0]
	lt(start.distance_to(idle), 0.5, "emir verilince sayaç yerinde kalır (merkeze sıçramaz): %.2f birim" % start.distance_to(idle))
	# ok da duruş noktasında biter (sayacın varacağı yer; bölge merkezinde değil)
	var ul := UnitLayer.new()
	var pm := ProbeMap.new()
	ul.map = pm
	ul.models = um
	ul._arrows = MeshInstance3D.new()
	ul.selected = [d]
	ul._draw_arrows()
	var arr := _arrow_arrays(ul)
	if check(not arr.is_empty(), "ok çizildi"):
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var tip := (verts[verts.size() - 2] + verts[verts.size() - 1]) * 0.5
		var last: int = d.path[d.path.size() - 1]
		near(Vector2(tip.x, tip.z).distance_to(World.province(last).center + Vector2(10.0, 0.0)), 0.0, 0.01, "ok varış noktasında biter")
	ul._arrows.free()
	ul.free()
	pm.free()
	# bacağın sonunda varış bölgesinin duruş noktası (varınca sıçramaz)
	d.progress = World.distance_km(d.province, d.path[0]) - 0.001
	um._update_anchors()
	var end_spot := World.province(d.path[0]).center + Vector2(10.0, 0.0)
	lt(um.anchors[d.id][0].distance_to(end_spot), 1.0, "bacak sonunda varış noktasında")
	um.free()
	sc.free()

## Üst üste binmeyen sayaçlar: aynı noktaya düşen dost yığınlar tek noktada küçük bir ızgara olur (ilk kart gerçek
## yerinde, iğne onda; öbürleri yanında, hücrelerini korur); düşman sayaçları hiç kaydırılmaz
func test_counters_do_not_overlap() -> void:
	Probe.ensure()
	var divs: Array[Division] = []
	var seen := {}
	for d in Military.country_divisions("TUR"):
		if not seen.has(d.province) and World.province(d.province).is_land():
			seen[d.province] = true
			divs.append(d)
		if divs.size() == 2:
			break
	if not check(divs.size() == 2, "iki ayrı bölgede tümen"):
		return
	var d1: Division = divs[0]
	var d2: Division = divs[1]
	var ul := UnitLayer.new()
	var pm := ProbeMap.new()
	var cam := MapCamera3D.new()
	var um := UnitModels.new()
	var sc := SameSpotCities.new()
	sc.spot = World.province(d1.province).center + Vector2(10.0, 0.0)
	sc.pids = {d1.province: true, d2.province: true}         # iki yığın (içindeki bütün tümenler) aynı noktada
	um.cities = sc
	ul.map = pm
	ul.camera = cam
	ul.models = um
	_tree().root.add_child(cam)
	_tree().root.add_child(ul)
	cam.current = true
	var p1 := World.province(d1.province).center
	cam.distance = 200.0
	cam.target = Vector3(p1.x, 0.0, p1.y)      # focus_on harita sınırına kıstırır (testte harita boyu yok)
	cam._apply()
	ul._process(0.5)
	var prev_dk := {}
	for mode: String in ["yığın", "saldırı"]:
		um._update_anchors()
		# iki yığın (içindeki bütün tümenler) aynı noktada
		for d in Military.divisions:
			if d.province == d1.province or d.province == d2.province:
				um.anchors[d.id] = (um.anchors[d1.id] as Array).duplicate()
				um.static_epoch += 1                  # yerler elle yazıldı
		d2.attacking = d1.province if mode == "saldırı" else 0
		for key: String in ul._counters:                    # saldırıda öbür yığın düşman sayılır (başka takım)
			if d1 in (ul._counters[key]["divs"] as Array):
				ul._counters[key]["tag"] = "SOV" if mode == "saldırı" else World.player_tag
		for i in 20:
			ul._follow_anchors(1.0)              # sayaçlar yeni yerlerine kayar
		ul._declutter()
		for i in 20:
			ul._follow_anchors(1.0)
		var c1: Dictionary = {}
		var c2: Dictionary = {}
		for key: String in ul._counters:
			var cdivs: Array = ul._counters[key]["divs"]
			if d1 in cdivs:
				c1 = ul._counters[key]
			if d2 in cdivs:
				c2 = ul._counters[key]
		if not check(not c1.is_empty() and not c2.is_empty() and c1 != c2, "iki ayrı sayaç (%s)" % mode):
			break
		var k := ul.get_viewport().get_visible_rect().size.y / 1080.0
		var r1 := ul._box(c1, cam.unproject_position(c1["root"].position), k)
		var r2 := ul._box(c2, cam.unproject_position(c2["root"].position), k)
		if mode == "yığın":
			check(not r1.intersects(r2), "dost sayaçlar ekranda üst üste binmez: %s / %s" % [r1, r2])
		var dk1: Vector3 = c1.get("dk_t", Vector3.ZERO)
		var dk2: Vector3 = c2.get("dk_t", Vector3.ZERO)
		if mode == "yığın":
			var moved: Vector3 = dk2 if dk1 == Vector3.ZERO else dk1
			check((dk1 == Vector3.ZERO or dk2 == Vector3.ZERO) and absf(moved.x) > 0.0 and is_zero_approx(moved.y), "ilk kart yerinde, öbürü yanında: %s %s" % [dk1, dk2])
			if not UnitLayer.FIGURES:
				var roots := ul.pin_roots()
				eq(int(c1["root"] in roots) + int(c2["root"] in roots), 1, "yığında tek iğne (ilk kartta)")
			var order := [int(c1.get("stack_i", -1)), int(c2.get("stack_i", -1))]
			ul._declutter()
			eq([int(c1.get("stack_i", -1)), int(c2.get("stack_i", -1))], order, "yığın sırası korunur (titremez)")
			prev_dk = {"1": c1.get("dk", Vector3.ZERO), "2": c2.get("dk", Vector3.ZERO)}
		else:
			# düşman sayaçları kaydırılmaz: yığın dağılınca ikisi de olduğu yerde kalır (saldıran kendi bölgesinde durur;
			# kayıp geri gelmez)
			eq(dk1, prev_dk["1"], "savunan yerinde")
			eq(dk2, prev_dk["2"], "saldıran yerinde, kaymaz")
	# uzakta (küçük rozetler) düzeltme yok: sayaçlar yerinde
	cam.distance = UnitLayer.DECLUTTER_DIST + 200.0
	cam._apply()
	ul._process(0.5)
	var moved := 0
	for key: String in ul._counters:
		if ul._counters[key].get("dk_t", Vector3.ZERO) != Vector3.ZERO:
			moved += 1
	eq(moved, 0, "uzakta sayaçlar kaydırılmaz")
	d2.attacking = 0
	_tree().root.remove_child(ul)
	_tree().root.remove_child(cam)
	for key: String in ul._counters:
		ul._counters[key]["root"].queue_free()
	ul.free()
	cam.free()
	pm.free()
	um.free()
	sc.free()

## Figürler (yakında) bölgeden bölgeye yolunda düz yürür: yolu duran bir figürün üstünden geçse de yana kaçmaz, duranı
## da itmez. Yakınlaşıp uzaklaşınca figürler yerinden oynamaz (düzen haritada). Kaide araziye oturur: yamaçta altındaki
## hiçbir nokta kaidenin içinde kalmaz.
func test_figures_collide_stay_put_and_sit_on_terrain() -> void:
	if not UnitLayer.FIGURES:
		return
	Probe.ensure()
	var divs: Array[Division] = []
	var seen := {}
	for d in Military.country_divisions("TUR"):
		if d.training == 0 and not seen.has(d.province) and World.province(d.province).is_land():
			seen[d.province] = true
			divs.append(d)
		if divs.size() == 2:
			break
	if not check(divs.size() == 2, "iki ayrı bölgede tümen"):
		return
	var d1: Division = divs[0]
	var d2: Division = divs[1]
	var ul := UnitLayer.new()
	var pm := HillMap.new()
	var cam := MapCamera3D.new()
	var um := UnitModels.new()
	var sc := SameSpotCities.new()
	um.cities = sc
	ul.map = pm
	ul.camera = cam
	ul.models = um
	_tree().root.add_child(cam)
	_tree().root.add_child(ul)
	cam.current = true
	var p1 := World.province(d1.province).center
	cam.distance = 200.0
	cam.target = Vector3(p1.x, 0.0, p1.y)
	cam._apply()
	um._update_anchors()
	ul._process(0.5)
	var key_of := func(x: Division) -> String:
		for k: String in ul._counters:
			if x in (ul._counters[k]["divs"] as Array):
				return k
		return ""
	for i in 30:
		ul._follow_anchors(0.1)
	var c1: Dictionary = ul._counters[key_of.call(d1)]
	var n1: Node3D = c1["root"]
	var at1 := Vector2(n1.position.x, n1.position.z)
	# yürüyen: d1'in batısından doğusundaki başka bir bölgeye, d1'in tam üstünden geçen düz yol (varışı d1'in yeri değil:
	# birleşmez)
	var to := _other_land([d1.province, d2.province])
	var km := _walk_setup(ul, um, sc, d2, to, at1 - Vector2(40.0, 0.0), at1 + Vector2(60.0, 0.0))
	var c2: Dictionary = ul._counters[key_of.call(d2)]
	var n2: Node3D = c2["root"]
	var r := UnitLayer.FIG_SIZE * UnitFigures.BASE_R
	var min_d := INF
	var moved1 := 0.0
	for i in 160:
		_walk_step(ul, um, [d2], [km], float(i) / 200.0)
		if i > 20:
			min_d = minf(min_d, Vector2(n2.position.x, n2.position.z).distance_to(Vector2(n1.position.x, n1.position.z)))
		moved1 = maxf(moved1, Vector2(n1.position.x, n1.position.z).distance_to(at1))
	lt(min_d, 1.0, "yürüyen yolundan sapmaz, duranın üstünden geçer (en yakın %.2f)" % min_d)
	lt(moved1, 0.05, "duran figür itilmez")
	for i in 60:
		_walk_step(ul, um, [d2], [km], 0.8 + 0.15 * float(i) / 60.0)
	lt(absf(n2.position.z - at1.y), 0.3, "geçince yoluna döner")
	# zoom: yakın kipte yer değişmez (önce en geniş yakın görüşte hepsi yerleşir; görüş dışındakilere dokunulmaz)
	cam.distance = UnitLayer.CARD_DIST - 20.0
	cam._apply()
	for i in 6:
		ul._cluster_timer = 0.0
		ul._process(0.1)
	var before := {}
	for k: String in ul._counters:
		var nd: Node3D = ul._counters[k]["root"]
		if nd.visible:
			before[k] = nd.position
	for dist: float in [90.0, 200.0, UnitLayer.CARD_DIST - 20.0]:
		cam.distance = dist
		cam._apply()
		for i in 6:
			ul._cluster_timer = 0.0
			ul._process(0.1)
	var drift := 0.0
	for k: String in before:
		if ul._counters.has(k) and (ul._counters[k]["root"] as Node3D).visible:
			var dd := ((ul._counters[k]["root"] as Node3D).position - (before[k] as Vector3)).length()
			drift = maxf(drift, dd)
	lt(drift, 0.05, "yakınlaşıp uzaklaşınca figürler yerinde")
	# arazi: tepenin yamacında kaide altındaki noktaların hiçbiri kaidenin içinde değil
	pm.hill = at1 + Vector2(12.0, 0.0)
	c1.erase("fxz")
	ul._follow_anchors(0.1)
	var fig: Node3D = c1["fig"]
	var up := fig.basis.y.normalized()
	var worst := INF
	for ri in 5:
		for ai in 16:
			var o := Vector2.from_angle(TAU * ai / 16.0) * r * 0.2 * float(ri + 1)
			var base_y := n1.position.y - (up.x * o.x + up.z * o.y) / up.y
			worst = minf(worst, base_y - pm.height_at(Vector2(n1.position.x, n1.position.z) + o))
	gt(worst, -0.35, "kaide yamaca gömülmez (en derin %.2f)" % worst)
	gt(n1.position.y, 5.0, "tepenin yamacında yükselir")
	lt(up.x, -0.05, "yamaç boyunca hafif yatar (tepe doğuda: kaidenin yüzü batıya bakar)")
	d2.path.clear()
	d2.progress = 0.0
	_tree().root.remove_child(ul)
	_tree().root.remove_child(cam)
	for key: String in ul._counters:
		ul._counters[key]["root"].queue_free()
	ul.free()
	cam.free()
	pm.free()
	um.free()
	sc.free()

## Düşmanlı bölgeye yürüyen tümen cephe hattında durur (simülasyon yürüyüşü bölge merkezine kadar sayar; görsel düşmanın
## içine girmez); saldırı başlayınca yerinden kıpırdamaz (eskiden duruş noktasına geri sıçrıyordu); zaferde ilerlerken
## sayacı geri gitmez, yeni yerine kayar
func test_attack_stops_at_front() -> void:
	var ger: Country = World.countries["GER"]
	var pol: Country = World.countries["POL"]
	var from := 0
	var into := 0
	for st: StateRegion in World.states.values():
		if st.owner != "GER" or into != 0:
			continue
		for pid in st.provinces:
			if not World.province(pid).is_land():
				continue
			for n in World.land_neighbors(pid):
				if World.controller_tag(n) == "POL":
					from = pid
					into = n
					break
			if into != 0:
				break
	if not check(into != 0, "Alman–Polonya sınırı"):
		return
	ger.war_goals["POL"] = "ready"
	Diplomacy.declare_war("GER", "POL")
	var d := Military._create(ger, 0, from, 1.0, 0)
	Military._create(pol, 0, into, 1.0, 0)
	d.path = PackedInt32Array([into])
	d.progress = 0.0                                     # duranken saldırı emri
	var um := UnitModels.new()
	var sc := SpotCities.new()
	um.cities = sc
	um._update_anchors()
	var at_front: Vector2 = um.anchors[d.id][0]
	d.progress = World.distance_km(from, into)          # simülasyon bölge merkezine kadar "yürüdü"
	um._update_anchors()
	var t_walk: float = PathMotion.division(d)[4]
	near(t_walk, PathMotion.FRONT_T, 0.001, "düşmanlı bölgeye emir alan tümen olduğu yerde durur")
	near((um.anchors[d.id][0] as Vector2).distance_to(at_front), 0.0, 0.01, "ilerleme dolsa da kıpırdamaz")
	var c0 := World.province(from).center
	var c1 := World.province(into).center
	lt(at_front.distance_to(c0 + Vector2(10, 0)), at_front.distance_to(c1 + Vector2(10, 0)), "kendi tarafında (düşmanın içinde değil)")
	d.attacking = into                                   # saldırı başladı
	um._update_anchors()
	near((um.anchors[d.id][0] as Vector2).distance_to(at_front), 0.0, 0.01, "saldırıda yerinde kalır, geri sıçramaz")
	eq(float(um.anchors[d.id][2]), 1.0, "ateş ediyor")
	um.free()
	sc.free()

## Yığından ayrılıp yürüyen tümenler kendi sayacında ilerler (yığının sayacı yerinde kalır); varınca aynı sayaç sürer
## (silinip yeniden kurulmaz), yığına katılan/ayrılan sayaç yeni yerine kayar
func test_moving_group_keeps_its_counter() -> void:
	Probe.ensure()
	var m := _mover("TUR", 1)
	if not check(not m.is_empty(), "yürüyebilecek tümen"):
		return
	var d: Division = m[0]
	var target: int = m[1]
	Military.stop(d)
	var stay := Military._create(World.countries["TUR"], d.template, d.province, 1.0, 0)
	stay.army = d.army
	var um := UnitModels.new()
	var sc := SpotCities.new()
	um.cities = sc
	var ul := UnitLayer.new()
	var pm := ProbeMap.new()
	ul.map = pm
	ul.models = um
	um._update_anchors()
	ul._rebuild()
	var key_of := func(x: Division) -> String:
		for k: String in ul._counters:
			if x in (ul._counters[k]["divs"] as Array):
				return k
		return ""
	eq(key_of.call(d), key_of.call(stay), "önce aynı yığında")
	var node: Node3D = ul._counters[key_of.call(d)]["root"]
	check(Military.order_move(d, target), "yürüme emri")
	ul._rebuild()
	check(key_of.call(d) != key_of.call(stay), "yürüyen kendi sayacında")
	var moving_key: String = key_of.call(d)
	var moving_node: Node3D = ul._counters[moving_key]["root"]
	check(ul._counters[key_of.call(stay)]["root"] == node, "duranların sayacı aynı")
	# varış: bölge değişir, yürüyenin sayacı aynı düğümle sürer
	Military._enter(d, target)
	ul._rebuild()
	check(ul._counters[key_of.call(d)]["root"] == moving_node, "varınca aynı sayaç (silinip yeniden kurulmaz)")
	for k: String in ul._counters:
		ul._counters[k]["root"].free()
	ul.free()
	pm.free()
	um.free()
	sc.free()

## Levha sayısı binleri bulabilir (uçak): 1000 ve üstü kısaltılır, uzun sayı küçük yazılır (taşıp alttakine binmesin)
func test_count_labels_compact() -> void:
	var l := Label3D.new()
	UnitLayer.set_count(l, 12, 42)
	eq(l.text, "12", "küçük sayı olduğu gibi")
	eq(l.font_size, 42, "olağan boy")
	UnitLayer.set_count(l, 250, 42)
	lt(l.font_size, 42, "üç basamak biraz küçük")
	UnitLayer.set_count(l, 1050, 42)
	check(l.text.ends_with("K") and l.text.length() <= 4, "binler kısaltılır: %s" % l.text)
	UnitLayer.set_count(l, 12400, 42)
	check(l.text.ends_with("K") and l.text.length() <= 5, "on binler kısaltılır: %s" % l.text)
	lt(l.font_size, 36, "uzun sayı küçük yazılır")
	l.free()

## Kalabalık yığın (GRID_MAX'tan çok kart) kapalı destedir: çapa kartı görünür, sayısı toplam, arkasında deste kenarı;
## öbürleri gizli; tıklayınca hepsi seçilir; imleç üstüne gelince ızgaraya açılır
func test_crowded_stack_is_a_deck() -> void:
	Probe.ensure()
	var ul := UnitLayer.new()
	var pm := ProbeMap.new()
	var cam := MapCamera3D.new()
	var um := UnitModels.new()
	var sc := SameSpotCities.new()
	um.cities = sc
	ul.map = pm
	ul.camera = cam
	ul.models = um
	_tree().root.add_child(cam)
	_tree().root.add_child(ul)
	cam.current = true
	var mine := Military.country_divisions("TUR")
	var p0 := World.province(mine[0].province).center
	sc.spot = p0                                  # bütün Türk yığınları aynı noktada
	for d in mine:
		sc.pids[d.province] = true
	cam.distance = 200.0
	cam.target = Vector3(p0.x, 0.0, p0.y)
	cam._apply()
	ul._process(0.5)
	um._update_anchors()
	for d in Military.divisions:
		if d.owner == "TUR":
			um.anchors[d.id] = [p0, Vector2(0, 1), 0.0, 0.0]         # bütün Türk yığınları aynı noktada
			um.static_epoch += 1                  # yerler elle yazıldı
	var n := 0
	for key: String in ul._counters:
		if ul._counters[key]["tag"] == "TUR":
			n += 1
	if not check(n > UnitLayer.GRID_MAX, "kalabalık yığın (%d sayaç)" % n):
		_tree().root.remove_child(ul)
		_tree().root.remove_child(cam)
		return
	for i in 20:
		ul._follow_anchors(1.0)
	ul._declutter()
	ul._show_decks()
	var shown: Array = []
	var total := 0
	for key: String in ul._counters:
		var c: Dictionary = ul._counters[key]
		if c["tag"] != "TUR":
			continue
		total += (c["divs"] as Array).size()
		if (c["root"] as Node3D).visible:
			shown.append(c)
	if eq(shown.size(), 1, "kapalı destede tek kart görünür"):
		var lead: Dictionary = shown[0]
		# gösterilen sayı: figür kipinde figürün sayısı (sayaçta tutulur), levhada levha yazısı
		var num: String = UnitLayer.count_text(int(lead.get("count", -1))) if UnitLayer.FIGURES else String(lead["label"].text)
		eq(num, str(total) if total < 1000 else num, "sayısı destedeki bütün tümenler")
		eq(ul._counter_divs(lead).size(), total, "tıklayınca destenin hepsi seçilir")
		check((lead["edges"] as Array).any(func(e: Sprite3D) -> bool: return e.visible), "arkasında deste kenarı")
	_tree().root.remove_child(ul)
	_tree().root.remove_child(cam)
	for key: String in ul._counters:
		ul._counters[key]["root"].queue_free()
	ul.free()
	cam.free()
	pm.free()
	um.free()
	sc.free()

## Uçaklar gerçek uçuş gibi hareket eder: sabit hız, en çok TURN_RATE ile döner (keskin köşe yok); sefer yapar — üsten
## kalkar, hedefe varır, sefer başına tek iş (dalışta tek bomba, düz bombardımanda bir dizi, avcıda devriye), üsse iner,
## bir süre yerde bekler. Hedefin üstünde durmadan dönüp bomba atmaz.
func test_air_sorties() -> void:
	var al := AirLayer.new()
	var pm := ProbeMap.new()
	al.map = pm
	var w := AirWing.new()
	w.id = 3
	var base := Vector2(100, 100)
	var tgt := Vector2(220, 100)
	var dt := 1.0 / 30.0
	for kind: String in ["dive", "level", "patrol"]:
		al._flights.clear()
		var sorties := 0
		var drops := 0
		var ground := 0
		var was_flying := false
		var min_base := INF
		var min_tgt := INF
		var max_turn := 0.0
		var prev_yaw := INF
		for i in 30 * 120:                                  # 2 gerçek dakika
			var p := al._fly(w, 0, base, tgt, 0.0, kind, dt)
			if p.is_empty():
				ground += 1
				was_flying = false
				prev_yaw = INF
				continue
			if not was_flying:
				sorties += 1
			was_flying = true
			var pos: Vector3 = p[0]
			var fwd: Vector3 = p[1]
			min_base = minf(min_base, Vector2(pos.x, pos.z).distance_to(base))
			min_tgt = minf(min_tgt, Vector2(pos.x, pos.z).distance_to(tgt))
			var yaw := atan2(fwd.x, fwd.z)
			if prev_yaw != INF:
				max_turn = maxf(max_turn, absf(wrapf(yaw - prev_yaw, -PI, PI)))
			prev_yaw = yaw
			if "drop" in (p[4] as Array):
				drops += 1
		gt(sorties, 0, "%s: sefer yapar" % kind)
		lt(sorties, 8, "%s: hedefte sürekli değil, seferle (%d sefer)" % [kind, sorties])
		if kind == "patrol":
			eq(drops, 0, "avcı bomba atmaz")
		else:
			check(drops >= sorties - 1 and drops <= sorties, "%s: sefer başına bir bombalama (%d sefer, %d)" % [kind, sorties, drops])
		gt(float(ground) * dt, AirLayer.REST_TIME * 0.9, "%s: yerde bekler" % kind)
		lt(min_base, 3.0, "%s: üsten kalkar / üsse iner" % kind)
		lt(min_tgt, AirLayer.RUN_HALF * AirLayer.ZS * 1.6, "%s: hedefe gider" % kind)
		lt(max_turn, AirLayer.TURN_RATE * dt + 0.001, "%s: keskin köşe yok (karede en çok %.3f rad)" % [kind, max_turn])
	al.free()
	pm.free()

## Uçak modeli üç parça: gövde (LOD'larıyla), pervane (burnun önünde, göbeği çevresinde döner) ve dört panelde bayrak
## çıkartması; fix() burnu -Z'ye çevirir
func test_plane_model_parts() -> void:
	var body := PlaneModel.body()
	var prop := PlaneModel.prop()
	var pv: PackedVector3Array = prop.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var pi: PackedInt32Array = prop.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
	var bi: PackedInt32Array = body.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
	gt(pi.size(), 3000, "pervanenin üçgenleri (%d)" % (pi.size() / 3))
	lt(pi.size(), bi.size() / 5, "pervane gövdeden küçük")
	var min_x := INF
	for i in pi:
		min_x = minf(min_x, pv[i].x)
	check(min_x >= PlaneModel.PROP_X, "pervane burnun önünde (en küçük x %.3f)" % min_x)
	check(PlaneModel.spin(1.1) * PlaneModel.HUB == PlaneModel.HUB, "pervane göbeği çevresinde döner")
	var nose := PlaneModel.fix().basis * Vector3(1, 0, 0)
	lt(nose.z, -0.99, "burun -Z'ye bakar")
	var dv: PackedVector3Array = PlaneModel.decal().surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for pnl: Dictionary in PlaneModel.PANELS:
		var near := 0
		for v in dv:
			if v.distance_to(pnl["c"]) < 0.05:
				near += 1
		gt(near, 6, "panelde bayrak çıkartması %s" % pnl["c"])
	var m := PlaneModel.flag_material(World.countries["TUR"])
	eq(m.albedo_texture.get_size(), Vector2(PlaneModel.TEX_W, PlaneModel.TEX_H), "bayrak dokusu 3:2")

## Figür iki parça: kaide ("h": bayrak kuşağı ve sayı, hep kameraya bakar) ve dönen üst ("t": asker + üstünde durduğu
## disk). set_yaw yalnız üstü döndürür; yaw_for harita yönünü model dönüşüne çevirir (doğu 0, kuzey +90°, varsayılan
## duruş FACE_DIR = FACE_YAW)
func test_figure_split_and_yaw() -> void:
	if not UnitLayer.FIGURES:
		return
	var fig := UnitFigures.make(World.countries["TUR"])
	var h: Node3D = fig.get_node_or_null("h")
	var t: Node3D = fig.get_node_or_null("t")
	if not check(h != null and t != null, "kaide ve üst düğümleri"):
		fig.free()
		return
	var base: MeshInstance3D = h.get_child(0)
	var top: MeshInstance3D = t.get_child(0)
	var ab := _used_aabb(base.mesh)
	var at := _used_aabb(top.mesh)
	var split := float(UnitFigures.SPECS["soldier"]["split_y"])
	lt(ab.end.y, split + 0.08, "kaide örgüsü ayrım çizgisinin hemen üstünde biter (üst %.3f)" % ab.end.y)
	gt(at.position.y, split - 0.01, "üst parça (asker + disk) ayrım çizgisinin üstünden başlar (%.3f)" % at.position.y)
	gt(at.end.y, 0.45, "askerin başı üstte")
	gt(ab.size.x, 0.8, "kaide tam genişlikte")
	check(h.get_node_or_null("n") != null, "sayı kaidede")
	near(UnitFigures.yaw_for(Vector2(1, 0)), 0.0, 1e-5, "doğuya bakış = 0")
	near(UnitFigures.yaw_for(Vector2(0, -1)), PI * 0.5, 1e-5, "kuzeye bakış = +90°")
	near(UnitFigures.yaw_for(UnitFigures.FACE_DIR), deg_to_rad(UnitFigures.FACE_YAW), 1e-4, "varsayılan duruş FACE_YAW")
	var h_rot := h.rotation.y
	UnitFigures.set_yaw(fig, 1.0)
	near(t.rotation.y, 1.0, 1e-6, "üst döner")
	near(h.rotation.y, h_rot, 1e-6, "kaide dönmez")
	fig.free()
	# tank: aynı düzen (kaide altı y = -0.5, kaide asker kaidesi boyunda), namlu düz ileri
	var tank := UnitFigures.make(World.countries["TUR"], "tank")
	eq(UnitFigures.kind_of(tank), "tank", "tank figürü")
	var th: MeshInstance3D = (tank.get_node("h") as Node3D).get_child(0)
	var tt: MeshInstance3D = (tank.get_node("t") as Node3D).get_child(0)
	var tab := _used_aabb(th.mesh)
	var tat := _used_aabb(tt.mesh)
	near(tab.position.y, -0.5, 0.01, "tank kaidesinin altı asker kaidesiyle aynı yerde")
	near(tab.size.x * 0.5, UnitFigures.BASE_R, 0.02, "tank kaidesi asker kaidesi boyunda")
	gt(tat.position.y, float(UnitFigures.SPECS["tank"]["split_y"]) - 0.01, "tank üst parçada")
	check(tank.get_node_or_null("h/n") != null, "tankta da sayı kaidede")
	near(UnitFigures.aim_yaw("tank"), 0.0, 1e-6, "tank namlusu düz")
	tank.free()

## Yalnız üçgenlerin kullandığı köşelerin kutusu (bölünmüş örgüde köşe dizisi ortak, kullanılmayanlar kutuya girmesin)
static func _used_aabb(mesh: Mesh) -> AABB:
	var arr := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var box := AABB(verts[idx[0]], Vector3.ZERO)
	for i in idx:
		box = box.expand(verts[i])
	return box

## İki yürüyen ve bir duran figür kurulumu (elle sürülen çapalarla): [ul, um, cam, pm, sc, d1 (duran), d2, d3]
func _figure_rig(n_movers: int) -> Array:
	Probe.ensure()
	var divs: Array[Division] = []
	var seen := {}
	for d in Military.country_divisions("TUR"):
		if d.training == 0 and not seen.has(d.province) and World.province(d.province).is_land():
			seen[d.province] = true
			divs.append(d)
		if divs.size() == 1 + n_movers:
			break
	if divs.size() < 1 + n_movers:
		return []
	var ul := UnitLayer.new()
	var pm := ProbeMap.new()
	var cam := MapCamera3D.new()
	var um := UnitModels.new()
	var sc := SameSpotCities.new()
	um.cities = sc
	ul.map = pm
	ul.camera = cam
	ul.models = um
	_tree().root.add_child(cam)
	_tree().root.add_child(ul)
	cam.current = true
	var p1 := World.province(divs[0].province).center
	cam.distance = 150.0
	cam.target = Vector3(p1.x, 0.0, p1.y)
	cam._apply()
	um._update_anchors()
	ul._process(0.5)
	for i in 30:
		ul._follow_anchors(0.1)
	return [ul, um, cam, pm, sc, divs[0], divs[1], divs[2] if divs.size() > 2 else null]

func _figure_rig_free(r: Array) -> void:
	var ul: UnitLayer = r[0]
	_tree().root.remove_child(ul)
	_tree().root.remove_child(r[2])
	for key: String in ul._counters:
		ul._counters[key]["root"].queue_free()
	ul.free()
	(r[2] as Node).free()
	(r[3] as Node).free()
	(r[1] as Node).free()
	(r[4] as Node).free()

func _key_of(ul: UnitLayer, x: Division) -> String:
	for k: String in ul._counters:
		if x in (ul._counters[k]["divs"] as Array):
			return k
	return ""

## Asker gittiği yöne döner, kaide dönmez; yürüyen yolunda düz ilerler (yana kaçmaz)
func test_figures_turn_and_keep_depth() -> void:
	if not UnitLayer.FIGURES:
		return
	var r := _figure_rig(1)
	if not check(not r.is_empty(), "iki ayrı bölgede tümen"):
		return
	var ul: UnitLayer = r[0]
	var um: UnitModels = r[1]
	var d1: Division = r[5]
	var d2: Division = r[6]
	var c1: Dictionary = ul._counters[_key_of(ul, d1)]
	var n1: Node3D = c1["root"]
	var at1 := Vector2(n1.position.x, n1.position.z)
	var sc: SameSpotCities = r[4]
	var to := _other_land([d1.province, d2.province])
	var km := _walk_setup(ul, um, sc, d2, to, at1 - Vector2(60.0, 0.0), at1 + Vector2(80.0, 0.0))
	var c2: Dictionary = ul._counters[_key_of(ul, d2)]
	var n2: Node3D = c2["root"]
	var fig2: Node3D = c2["fig"]
	var min_d := INF
	var aligned := 0
	var steps := 0
	var prev := Vector2.INF
	for i in 240:
		_walk_step(ul, um, [d2], [km], float(i) / 280.0)
		var now := Vector2(n2.position.x, n2.position.z)
		if i > 20:
			min_d = minf(min_d, now.distance_to(Vector2(n1.position.x, n1.position.z)))
		if prev != Vector2.INF and i > 20 and now.distance_to(prev) > 0.05:
			# bakış yer değişiminin yönünde (60° içinde): yana kayarken de o yana yürür, kaymaz
			var face := Vector2(cos(float(c2["yaw"])), -sin(float(c2["yaw"])))
			steps += 1
			if absf(face.angle_to(now - prev)) < deg_to_rad(60.0):
				aligned += 1
		prev = now
	lt(min_d, 1.0, "yolundan sapmaz (en yakın %.1f)" % min_d)
	gt(float(aligned) / maxf(float(steps), 1.0), 0.85, "yürüyen baktığı yöne yürür (%d/%d adım)" % [aligned, steps])
	near(float(c2["yaw"]), 0.0, 0.3, "geçtikten sonra doğuya bakar (yaw %.2f)" % float(c2["yaw"]))
	near((fig2.get_node("h") as Node3D).rotation.y, deg_to_rad(UnitFigures.FACE_YAW), 1e-5, "kaide (bayrak, sayı) dönmez")
	near((fig2.get_node("t") as Node3D).rotation.y, float(c2["yaw"]), 1e-5, "asker döner")
	near(float(c1.get("yaw", deg_to_rad(UnitFigures.FACE_YAW))), deg_to_rad(UnitFigures.FACE_YAW), 1e-4, "duran varsayılan duruşta")
	d2.path.clear()
	_figure_rig_free(r)

## Karşılaşan ya da art arda yürüyen iki figür yolundan sapmaz (bölgeden bölgeye düz yürüyüş; yol verme yok)
func test_movers_walk_straight() -> void:
	if not UnitLayer.FIGURES:
		return
	var r := _figure_rig(2)
	if not check(not r.is_empty(), "üç ayrı bölgede tümen"):
		return
	var ul: UnitLayer = r[0]
	var um: UnitModels = r[1]
	var d1: Division = r[5]
	var d2: Division = r[6]
	var d3: Division = r[7]
	var sc: SameSpotCities = r[4]
	var base := World.province(d1.province).center + Vector2(0.0, 40.0)
	# karşılaşan iki figür: biri doğuya, öbürü batıya aynı düz çizgide
	var to2 := _other_land([d1.province, d2.province, d3.province])
	var to3 := _other_land([d1.province, d2.province, d3.province, to2])
	var km2 := _walk_setup(ul, um, sc, d2, to2, base, base + Vector2(100.0, 0.0))
	var km3 := _walk_setup(ul, um, sc, d3, to3, base + Vector2(100.0, 0.0), base)
	var n2: Node3D = ul._counters[_key_of(ul, d2)]["root"]
	var n3: Node3D = ul._counters[_key_of(ul, d3)]["root"]
	var off := 0.0
	for i in 200:
		_walk_step(ul, um, [d2, d3], [km2, km3], float(i) / 220.0)
		off = maxf(off, maxf(absf(n2.position.z - base.y), absf(n3.position.z - base.y)))
	lt(off, 0.3, "karşılaşan figürler yollarından sapmaz (%.2f)" % off)
	d2.path.clear()
	d3.path.clear()
	_figure_rig_free(r)

## Diziliş: üçer kişilik sıralar, arka sıra yarım hücre şaşırtmalı (arkadaki öndekilerin arasından görünür); dört
## figürlük yığında arka sıradaki hiçbir ön sıradakinin tam arkasında değildir
func test_figure_ranks_staggered() -> void:
	if not UnitLayer.FIGURES:
		return
	eq(UnitLayer._fig_cell(0), Vector2(0, 0), "çapa ortada")
	eq(UnitLayer._fig_cell(1), Vector2(1, 0), "sağı")
	eq(UnitLayer._fig_cell(2), Vector2(-1, 0), "solu")
	eq(UnitLayer._fig_cell(3), Vector2(0.5, 1), "arka sıra yarım kaymış")
	eq(UnitLayer._fig_cell(4), Vector2(-0.5, 1), "arka sıra sol yarım")
	eq(UnitLayer._fig_cell(6), Vector2(0, 2), "üçüncü sıra düz")
	Probe.ensure()
	var ul := UnitLayer.new()
	var pm := ProbeMap.new()
	var cam := MapCamera3D.new()
	var um := UnitModels.new()
	var sc := SameSpotCities.new()
	um.cities = sc
	ul.map = pm
	ul.camera = cam
	ul.models = um
	_tree().root.add_child(cam)
	_tree().root.add_child(ul)
	cam.current = true
	var picked: Array[Division] = []
	var seen := {}
	for d in Military.country_divisions("TUR"):
		if d.training == 0 and not seen.has(d.province) and World.province(d.province).is_land():
			seen[d.province] = true
			picked.append(d)
		if picked.size() == 5:
			break
	var p0 := World.province(picked[0].province).center + Vector2(300.0, 300.0)   # başka yığınlardan uzak bir nokta
	sc.spot = p0                                  # beşinin bölgesi aynı noktada
	for d in picked:
		sc.pids[d.province] = true
	cam.distance = 150.0
	cam.target = Vector3(p0.x, 0.0, p0.y)
	cam._apply()
	ul._process(0.5)
	um._update_anchors()
	for d in picked:
		um.anchors[d.id] = [p0, Vector2(0, 1), 0.0, 0.0]
		um.static_epoch += 1
	for i in 20:
		ul._follow_anchors(1.0)
	ul._declutter()
	for i in 40:
		ul._follow_anchors(1.0)
	var xs_front: Array[float] = []
	var back: Array = []
	var stack := ""
	for d in picked:
		var c: Dictionary = ul._counters[_key_of(ul, d)]
		if stack == "":
			stack = str(c.get("stack_of", ""))
		eq(str(c.get("stack_of", "")), stack, "hepsi bir yığında")
		var dk: Vector3 = c.get("dk_t", Vector3.ZERO)
		if int(c.get("stack_i", -1)) < 3:
			xs_front.append(dk.x)
			near(dk.z, 0.0, 0.01, "ön sıra yerinde")
		else:
			back.append(dk)
	if check(back.size() == 2 and xs_front.size() == 3, "üçü önde ikisi arkada"):
		for dk: Vector3 in back:
			lt(dk.z, -UnitLayer.FIG_DEPTH * UnitLayer.FIG_SIZE * 0.9, "arka sıra figür boyu kadar geride (%.1f)" % dk.z)
			var gap := INF
			for x: float in xs_front:
				gap = minf(gap, absf(x - dk.x))
			gt(gap, UnitLayer.FIG_SIZE * UnitFigures.BASE_R * 0.8, "öndekilerin arasında (en yakın sütuna %.1f)" % gap)
	_tree().root.remove_child(ul)
	_tree().root.remove_child(cam)
	for key: String in ul._counters:
		ul._counters[key]["root"].queue_free()
	ul.free()
	cam.free()
	pm.free()
	um.free()
	sc.free()

## Varış: aynı ülkenin figürünün durduğu bölgeye yürüyen figür yer ayırmaz, dosdoğru ona yürür; varınca ikisi tek figür
## olur (ayrı ordularda olsalar da) ve figür yerinden sıçramaz
func test_arrival_merges_into_friend() -> void:
	if not UnitLayer.FIGURES:
		return
	Probe.ensure()
	var m := _mover("TUR", 1)
	if not check(not m.is_empty(), "yürüyebilecek tümen"):
		return
	var d2: Division = m[0]
	var target: int = m[1]
	var d1: Division = null
	for d in Military.country_divisions("TUR"):
		if d != d2 and d.training == 0 and World.province(d.province).is_land():
			d1 = d
			break
	if not check(d1 != null, "duracak tümen"):
		return
	Military.stop(d1)
	d1.path = PackedInt32Array([target])
	Military._enter(d1, target)                       # varış bölgesinde duran dost
	Military.create_army("TUR", [d1])                 # başka ordu: yine de tek figür olur
	var ul := UnitLayer.new()
	var pm := ProbeMap.new()
	var cam := MapCamera3D.new()
	var um := UnitModels.new()
	var sc := SpotCities.new()
	um.cities = sc
	ul.map = pm
	ul.camera = cam
	ul.models = um
	_tree().root.add_child(cam)
	_tree().root.add_child(ul)
	cam.current = true
	var tc := World.province(target).center
	cam.distance = 150.0
	cam.target = Vector3(tc.x, 0.0, tc.y)
	cam._apply()
	var dist := World.distance_km(d2.province, target)
	um._update_anchors()
	ul._process(0.5)
	var c2: Dictionary = ul._counters[_key_of(ul, d2)]
	for i in 41:
		d2.progress = dist * float(i) / 40.0
		um._update_anchors()
		ul._declutter()
		for j in 3:
			ul._follow_anchors(0.2)
	check(not c2.has("arrive"), "kendi ülkesine varırken yer ayırmaz")
	var n1: Node3D = ul._counters[_key_of(ul, d1)]["root"]
	var spot1 := Vector2(n1.position.x, n1.position.z)
	Military._enter(d2, target)
	ul._dirty = true
	ul._timer = 1.0
	ul._process(0.05)
	um._update_anchors()
	ul._declutter()
	for j in 30:
		ul._follow_anchors(0.2)
	eq(_key_of(ul, d2), _key_of(ul, d1), "varınca tek figür (ayrı ordularda da)")
	var cm: Dictionary = ul._counters[_key_of(ul, d1)]
	eq((cm["divs"] as Array).size(), 2, "figürde iki tümen")
	var after := Vector2((cm["root"] as Node3D).position.x, (cm["root"] as Node3D).position.z)
	lt(after.distance_to(spot1), 1.5, "birleşen figür yerinde kalır (%.1f)" % after.distance_to(spot1))
	_tree().root.remove_child(ul)
	_tree().root.remove_child(cam)
	for key: String in ul._counters:
		ul._counters[key]["root"].queue_free()
	ul.free()
	cam.free()
	pm.free()
	um.free()
	sc.free()

## Aynı bölgede aynı ülkenin duran ve saldıran tümenleri, farklı ordularda olsalar da tek sayaçtır (hareket bölgeden
## bölgeye; bölge içinde ayrı nokta yok)
func test_same_country_same_province_one_counter() -> void:
	Probe.ensure()
	var mine := Military.country_divisions("TUR").filter(func(x: Division) -> bool: return x.training == 0)
	if not check(mine.size() >= 3, "üç tümen"):
		return
	var pid: int = (mine[0] as Division).province
	for d: Division in mine.slice(1, 3):
		Military._move_to(d, pid)
	Military.create_army("TUR", [mine[1]])
	var um := UnitModels.new()
	var sc := SpotCities.new()
	um.cities = sc
	var ul := UnitLayer.new()
	var pm := ProbeMap.new()
	ul.map = pm
	ul.models = um
	um._update_anchors()
	ul._rebuild()
	eq(_key_of(ul, mine[0]), _key_of(ul, mine[1]), "farklı ordular tek sayaç")
	eq(_key_of(ul, mine[0]), _key_of(ul, mine[2]), "üçü tek sayaç")
	(mine[2] as Division).attacking = World.land_neighbors(pid)[0]    # saldıran da aynı figürde
	(mine[2] as Division).path = PackedInt32Array([(mine[2] as Division).attacking])
	ul._rebuild()
	eq(_key_of(ul, mine[2]), _key_of(ul, mine[0]), "saldıran da tek sayaçta")
	(mine[2] as Division).attacking = 0
	(mine[2] as Division).path = PackedInt32Array()
	for k: String in ul._counters:
		ul._counters[k]["root"].free()
	ul.free()
	pm.free()
	um.free()
	sc.free()

## Cephede duran figür en yakın düşman komşu bölgeye bakar
func test_figure_faces_enemy_neighbour() -> void:
	if not UnitLayer.FIGURES:
		return
	var ger: Country = World.countries["GER"]
	var pol: Country = World.countries["POL"]
	var from := 0
	var into := 0
	for st: StateRegion in World.states.values():
		if st.owner != "GER" or into != 0:
			continue
		for pid in st.provinces:
			if not World.province(pid).is_land():
				continue
			for n in World.land_neighbors(pid):
				if World.controller_tag(n) == "POL":
					from = pid
					into = n
					break
			if into != 0:
				break
	if not check(into != 0, "Alman–Polonya sınırı"):
		return
	ger.war_goals["POL"] = "ready"
	Diplomacy.declare_war("GER", "POL")
	var d := Military._create(ger, 0, from, 1.0, 0)
	Military._create(pol, 0, into, 1.0, 0)
	var um := UnitModels.new()
	var sc := SpotCities.new()
	um.cities = sc
	var ul := UnitLayer.new()
	var pm := ProbeMap.new()
	ul.map = pm
	ul.models = um
	um._update_anchors()
	ul._rebuild()
	var c: Dictionary = ul._counters[_key_of(ul, d)]
	var face: Vector2 = ul._face_of(c, _key_of(ul, d))      # bakış görünen figür için, gerektiğinde hesaplanır
	var here := World.province(from).center
	var want := Vector2.ZERO
	var best := INF
	# askeri olan düşman komşu önce (askersiz komşu 16 kat uzak sayılır)
	for n in World.land_neighbors(from):
		if World.controller_tag(n) != "POL":
			continue
		var manned := Military.divisions.any(func(x: Division) -> bool: return x.province == n and x.owner == "POL")
		var dd := here.distance_squared_to(World.province(n).center) * (1.0 if manned else 16.0)
		if dd < best:
			best = dd
			want = (World.province(n).center - here).normalized()
	gt(face.dot(want), 0.9, "bakış askeri olan en yakın düşman komşuya (%s ~ %s)" % [face, want])
	for k: String in ul._counters:
		ul._counters[k]["root"].free()
	ul.free()
	pm.free()
	um.free()
	sc.free()

## Duruş noktası bölgenin içinde kalır: merkez doluysa (şehir, yapı) aranan boş nokta komşu bölgeye taşmaz (figür
## sınırın ötesinde düşmanın dibinde duruyordu)
class BlockCities extends CityLayer3D:
	var block_r := 12.0
	var center := Vector2.ZERO
	func _blocked(q: Vector2) -> bool:
		return q.distance_to(center) < block_r

func test_unit_spot_stays_in_province() -> void:
	Probe.ensure()
	var bc := BlockCities.new()
	var pm := ProbeMap.new()
	bc.map = pm
	var searched := 0
	var moved := 0
	for pr: Province in World.provinces:
		if pr == null or not pr.is_land() or searched >= 40:
			continue
		# yalnız küçük bölgeler: 28 birimlik arama halkası komşuya taşabilsin
		var foreign := false
		for k in 12:
			var a := TAU * float(k) / 12.0
			if Probe.province_at(pr.center + Vector2(cos(a), sin(a)) * 20.0) != pr.id:
				foreign = true
				break
		if not foreign:
			continue
		searched += 1
		bc.center = pr.center
		bc._unit_spots.clear()
		var spot := bc.unit_spot(pr.id, pr.center)
		if spot != pr.center:
			moved += 1
		eq(Probe.province_at(spot), pr.id, "duruş noktası kendi bölgesinde (bölge %d)" % pr.id)
	gt(moved, 0, "en az bir bölgede nokta merkezden kaydırıldı (%d/%d)" % [moved, searched])
	bc.free()
	pm.free()

## Yürürken cepheyle karşılaşan tümen bacağın yarısından önce durur: iki taraf da yarı yolda dursa arada FRONT_GAP kalır
## (menzilden ateş; dip dibe değil)
func test_walking_into_front_keeps_gap() -> void:
	var ger: Country = World.countries["GER"]
	var pol: Country = World.countries["POL"]
	var from := 0
	var into := 0
	for st: StateRegion in World.states.values():
		if st.owner != "GER" or into != 0:
			continue
		for pid in st.provinces:
			if not World.province(pid).is_land():
				continue
			for n in World.land_neighbors(pid):
				if World.controller_tag(n) == "POL":
					from = pid
					into = n
					break
			if into != 0:
				break
	if not check(into != 0, "Alman–Polonya sınırı"):
		return
	ger.war_goals["POL"] = "ready"
	Diplomacy.declare_war("GER", "POL")
	var d := Military._create(ger, 0, from, 1.0, 0)
	Military._create(pol, 0, into, 1.0, 0)
	d.path = PackedInt32Array([into])
	d.progress = World.distance_km(from, into) * 0.9          # yürürken düşmanla karşılaştı (ilerlemesi çok)
	var m := PathMotion.division(d)
	var t: float = m[4]
	var c0 := World.province(from).center
	var c1 := World.province(into).center
	var leg := World.distance_km(from, into) / World.km_per_px_at(c0)         # bacak boyu, PathMotion'daki gibi
	lt(t, 0.5 - PathMotion.FRONT_GAP / (2.0 * leg) + 0.001, "bacağın yarısından önce durur (t=%.2f, bacak %.0f)" % [t, leg])
	gt((m[0] as Vector2).distance_to(c1), c0.distance_to(c1) * 0.5 + PathMotion.FRONT_GAP * 0.5 - 1.0, "düşman merkezine yarı bacak + yarım aralıktan yakın değil")
	eq(m[2], true, "yürüyen sayılır (cephede bekler)")

## Ülke renginin haritadaki tonu: açıklık ve doygunluk kendi aralığında, renk tonu (açı) aynı, gri ülke gri kalır, koyu
## ülke açık ülkeden yine koyu (sıra korunur)
func test_map_tone_range_and_hue() -> void:
	var prev_l := -1.0
	for t in 11:
		var src := Color.from_ok_hsl(0.03, 0.9, 0.15 + 0.08 * float(t))
		var c := MapView3D.map_tone(src)
		check(c.ok_hsl_l >= MapView3D.TONE_L.x - 0.01 and c.ok_hsl_l <= MapView3D.TONE_L.y + 0.01,
			"açıklık aralıkta (%.2f)" % c.ok_hsl_l)
		check(c.ok_hsl_s <= MapView3D.TONE_S.y + 0.02, "doygunluk en çok %.2f (%.2f)" % [MapView3D.TONE_S.y, c.ok_hsl_s])
		near(c.ok_hsl_h, 0.03, 0.02, "renk tonu değişmez")
		check(c.ok_hsl_l >= prev_l - 0.001, "sıra korunur")
		prev_l = c.ok_hsl_l
	var gray := MapView3D.map_tone(Color("5b5d55"))
	lt(gray.ok_hsl_s, 0.12, "gri ülke gri kalır (%.2f)" % gray.ok_hsl_s)
	var pale := MapView3D.map_tone(Color.from_ok_hsl(0.6, 0.2, 0.5))
	gt(pale.ok_hsl_s, MapView3D.TONE_S.x - 0.02, "soluk ülke canlanır (%.2f)" % pale.ok_hsl_s)
	for tag: String in World.countries:
		var cc: Color = MapView3D.map_tone((World.countries[tag] as Country).color)
		check(cc.ok_hsl_l >= MapView3D.TONE_L.x - 0.01 and cc.ok_hsl_l <= MapView3D.TONE_L.y + 0.01, "%s açıklığı aralıkta" % tag)

## Ülke sınırı alanı iki karede kurulur (önce kenar, sonra uzaklık geçişi); sahiplik değişince yeniden kurulur
func test_country_rim_refresh() -> void:
	var rim := CountryRim.new()
	_tree().root.add_child(rim)
	var pimg := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	var dimg := Image.create(256, 1, false, Image.FORMAT_RGBA8)
	rim.setup(ImageTexture.create_from_image(pimg), ImageTexture.create_from_image(dimg), Vector2(64, 32), false)
	check(rim.texture != null, "alan dokusu")
	eq(rim._edge.size, Vector2i(4, 2), "ızgara harita boyunun 1/16'sı")
	eq(rim._step, 1, "kurulunca hesaplanacak")
	rim._process(0.0)
	eq(rim._edge.render_target_update_mode, SubViewport.UPDATE_ONCE, "önce kenar geçişi")
	eq(rim._step, 2, "sonra uzaklık")
	rim._process(0.0)
	eq(rim._dist.render_target_update_mode, SubViewport.UPDATE_ONCE, "uzaklık geçişi")
	eq(rim._step, 0, "bitti")
	rim.refresh()
	eq(rim._step, 0, "sahiplik değişince hemen değil (en çok REFRESH_GAP saniyede bir)")
	rim._process(CountryRim.REFRESH_GAP)
	eq(rim._step, 2, "sahiplik değişince yeniden: kenar geçişi")
	eq(rim._edge.render_target_update_mode, SubViewport.UPDATE_ONCE, "yeniden kenar geçişi")
	_tree().root.remove_child(rim)
	rim.free()
