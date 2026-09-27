extends "res://tests/test_case.gd"
## Filo hareketinin görsel mantığı: PathMotion.sea_pose / fleet ile örneklenen her konum denizde (düğüm köşeleri,
## limandan çıkış, rıhtım); FleetLayer düzeni (fit_formation) kıyıda karaya taşmaz, karadaki grup suya alınır.

const Probe := preload("res://tests/map_probe.gd")
const SHOWN: Array[String] = ["battleship", "cruiser", "destroyer"]

func _water(p: Vector2) -> bool:
	return Probe.is_water(p)

## Düğüm köşeleri: bir komşudan gelip başka komşuya dönerken yuvarlatılan kavis (varış ve çıkış yarıları) denizde
func test_lane_corners_at_sea() -> void:
	Probe.ensure()
	var bad: Array = []
	var n := 0
	for to: int in Navy._sea_adj:
		if World.province(to).is_land():
			continue
		var nbrs: Array = Array(Navy._sea_adj[to])
		nbrs.append_array(Navy._port_links.get(to, []))
		for from: int in nbrs:
			var l := SeaLanes.lane(from, to)
			if l.is_empty():
				continue
			var L := SeaLanes.length(l)
			for nxt: int in nbrs:
				if nxt == from or SeaLanes.lane(to, nxt).is_empty():
					continue
				for k in 5:
					var s := L - PathMotion.CORNER * float(k) / 4.0          # varış yarısı
					var a := PathMotion.sea_pose(-1, from, to, nxt, clampf(s / L, 0.0, 1.0), Vector2.INF)
					n += 1
					if not a.is_empty() and not Probe.is_sea(a[0]):
						bad.append("%d→%d→%d varış t=%.2f (%d, %d)" % [from, to, nxt, s / L, a[0].x, a[0].y])
						break
				var L2 := SeaLanes.length(SeaLanes.lane(to, nxt))
				for k in 5:
					var s := PathMotion.CORNER * float(k) / 4.0                # çıkış yarısı
					var b := PathMotion.sea_pose(from, to, nxt, -1, clampf(s / L2, 0.0, 1.0), Vector2.INF)
					n += 1
					if not b.is_empty() and not Probe.is_sea(b[0]):
						bad.append("%d→%d→%d çıkış t=%.2f (%d, %d)" % [from, to, nxt, s / L2, b[0].x, b[0].y])
						break
	gt(n, 100000, "örneklenen köşe noktası")
	if not bad.is_empty():
		fail("%d köşe karaya değiyor" % bad.size())
	none(bad.slice(0, 15), "köşe")

## Gerçek filolar: limandan uzak bir bölgeye gönderilir; her saat ve saat içi ara değerlerde görsel konum denizde
func test_fleets_move_at_sea() -> void:
	Probe.ensure()
	var fleets: Array = []
	for tag in ["ENG", "GER", "ITA", "JAP", "USA", "FRA", "SOV", "TUR"]:
		for f in Navy.fleets_of(tag):
			if not f.reserve:
				fleets.append(f)
	gt(fleets.size(), 10, "hareket eden filo")
	# her filo en uzak ikinci komşu bölgelerden birine (limandan çıkış + birkaç rota + köşeler)
	for f: Fleet in fleets:
		var start := Navy.sea_for(f.home)
		var far := start
		for i in 6:
			var nb: PackedInt32Array = Navy._sea_adj.get(far, PackedInt32Array())
			if nb.is_empty():
				break
			far = nb[(f.id + i) % nb.size()]
		Navy.set_mission(f, Fleet.Mission.SUPERIORITY, far)
	var bad: Array = []
	var samples := 0
	for h in 24 * 4:
		GameClock.advance_hours(1)
		for frac in [0.0, 0.33, 0.66, 0.99]:
			GameClock._accum = frac
			for f: Fleet in fleets:
				if not f in Navy.fleets:
					continue
				var here := World.province(f.location)
				var base := SeaLanes.node(f.location) if not here.is_land() else SeaLanes.dock(f.location, Navy.sea_for(f.location))
				if base == Vector2.INF:
					bad.append("%s %s: limanın rıhtımı yok (%d)" % [f.owner, f.name, f.location])
					continue
				var m := PathMotion.fleet(f, base)
				samples += 1
				if not Probe.is_sea(m[0]):
					bad.append("%s %s: %d→%s (%d, %d) karada" % [f.owner, f.name, f.location, str(f.path.slice(0, 2)), m[0].x, m[0].y])
	GameClock._accum = 0.0
	gt(samples, 1000, "örnek")
	none(bad.slice(0, 15), "filo konumu")

## Rıhtımda (limanda, yan yana) ve rota boyunca (seyirde, üçgen) düzen: tüm gemiler baş-orta-kıç suda
func test_formation_fits_in_water() -> void:
	Probe.ensure()
	SeaLanes._ensure()
	var water := Callable(self, "_water")
	var bad: Array = []
	var tight := 0
	var n := 0
	for key: String in SeaLanes._docks:
		var dock: Vector2 = SeaLanes._docks[key]
		var sea := int(key.get_slice("-", 1))
		var fwd := (SeaLanes.node(sea) - dock).normalized()
		n += 1
		var fit: Array = FleetLayer.fit_formation(dock, fwd, SHOWN, true, FleetLayer.ZS, water)
		if float(fit[1]) <= 0.0:
			tight += 1
		_check_ships(fit, fwd, true, "rıhtım " + key, water, bad)
	var k := 0
	for key: String in SeaLanes._raw:
		k += 1
		if k % 7 != 0:
			continue
		var ab := key.split("-")
		var l := SeaLanes.lane(int(ab[0]), int(ab[1]))
		var L := SeaLanes.length(l)
		var s := 0.0
		while s < L:
			var at: Array = SeaLanes.at(l, s)
			n += 1
			var fit: Array = FleetLayer.fit_formation(at[0], at[1], SHOWN, false, FleetLayer.ZS, water)
			if float(fit[1]) <= 0.0:
				tight += 1
			_check_ships(fit, at[1], false, "rota %s s=%d" % [key, s], water, bad)
			s += 40.0
	gt(n, 1000, "denenen düzen")
	none(bad.slice(0, 15), "karaya taşan gemi")
	if tight > 0:
		warn("%d/%d konumda düzen tam sıkıştı (gemiler grup noktasında)" % [tight, n])

## Karaya düşen grup konumu en yakın suya alınır
func test_group_on_land_clamped_to_water() -> void:
	Probe.ensure()
	SeaLanes._ensure()
	var water := Callable(self, "_water")
	var bad: Array = []
	var n := 0
	for key: String in SeaLanes._docks:
		var dock: Vector2 = SeaLanes._docks[key]
		var sea := int(key.get_slice("-", 1))
		var fwd := (SeaLanes.node(sea) - dock).normalized()
		var land := dock - fwd * 6.0                  # rıhtımın kara tarafı
		if Probe.is_water(land):
			continue
		n += 1
		var fit: Array = FleetLayer.fit_formation(land, fwd, SHOWN, true, FleetLayer.ZS, water)
		var p: Vector2 = fit[0]
		if not Probe.is_water(p) or p.distance_to(land) > 48.0:
			bad.append("%s: (%d, %d) → (%d, %d)" % [key, land.x, land.y, p.x, p.y])
	gt(n, 50, "karadan başlayan grup")
	none(bad.slice(0, 15), "suya alınamayan grup")

func _check_ships(fit: Array, fwd: Vector2, port: bool, ctx: String, water: Callable, bad: Array) -> void:
	var pos: Vector2 = fit[0]
	var sp: float = fit[1]
	if not Probe.is_water(pos):
		bad.append("%s: grup konumu karada" % ctx)
		return
	if sp <= 0.0:
		return                                          # tam sıkışık: gemiler grup noktasında (suda)
	var right := Vector2(fwd.y, -fwd.x)
	for i in SHOWN.size():
		var q := FleetLayer.ship_pos(pos, fwd, right, SHOWN[i], i, port, sp, FleetLayer.ZS)
		if not FleetLayer.ship_in_water(q, fwd, SHOWN[i], FleetLayer.ZS, water):
			bad.append("%s: %s karaya taşıyor (açılım %.2f)" % [ctx, SHOWN[i], sp])
			return
