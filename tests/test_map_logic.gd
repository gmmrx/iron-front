extends "res://tests/test_case.gd"
## Harita katmanlarının mantığı (görüntüye bakmadan, sayıyla): tümen yolu (PathMotion) sürekli ve varışta hedefte;
## hareket okları (UnitLayer._curve/_ribbon) renk, uç, üçgen ve UV; hava durumu (WeatherLayer.weather_at)
## belirlenimci ve mevsime/enleme uygun; zoom kiplerinde sayaç/bayrak/gizli görünürlüğü (UnitLayer, FleetLayer).

const Probe := preload("res://tests/map_probe.gd")

## Yalnız bölge görüntüsüyle çalışan harita (ağır dokular yüklenmez, sahneye eklenmez): yükseklik düz
class ProbeMap extends MapView3D:
	func province_at(world_xz: Vector2) -> int:
		return Probe.province_at(world_xz)
	func height_at(_world_xz: Vector2) -> float:
		return 0.0

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
	# kendi toprağında hareket: yeşil
	ul._draw_arrows()
	var arr := _arrow_arrays(ul)
	if check(not arr.is_empty(), "ok çizildi"):
		_check_arrow(arr, UnitLayer.ARROW_MOVE, pts[pts.size() - 1], target, "hareket")
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
	# ok ucu: son üçgenin ortadaki köşesi rota sonunda, hedef bölgede
	var end := verts[verts.size() - 2]
	near(Vector2(end.x, end.z).distance_to(tip), 0.0, 0.01, ctx + ": ok ucu rota sonunda")
	eq(Probe.province_at(Vector2(end.x, end.z)), target, ctx + ": ok ucu hedef bölgede")

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
	var modes := [[500.0, "sayı"], [UnitLayer.FLAG_MODE + 100.0, "bayrak"], [UnitLayer.HIDE_ALL + 100.0, "gizli"]]
	for mode: Array in modes:
		cam.distance = mode[0]
		ul._vis_dirty = true
		ul._process(0.01)
		var wrong := 0
		for key: String in ul._counters:
			var c: Dictionary = ul._counters[key]
			match mode[1]:
				"sayı":
					if not c["bg"].visible or not c["label"].visible or c["flag"].visible: wrong += 1
				"bayrak":
					if c["bg"].visible or c["label"].visible or not c["flag"].visible: wrong += 1
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
	var modes := [[500.0, "sayı"], [UnitLayer.FLAG_MODE + 100.0, "bayrak"], [UnitLayer.HIDE_ALL + 100.0, "gizli"]]
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
				"sayı":
					if not c["root"].visible or not c["bg"].visible or not c["label"].visible or c["flag"].visible: wrong += 1
				"bayrak":
					if not c["root"].visible or c["bg"].visible or c["label"].visible or not c["flag"].visible: wrong += 1
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
