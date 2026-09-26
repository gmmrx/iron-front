extends "res://tests/test_case.gd"
## Deniz yolları (data/map/sea_lanes.json, tools/build_sea_lanes.py): her rota yalnız deniz bölgelerinden geçer,
## her liman–deniz ve deniz–deniz komşuluğunun rotası var, düğüm ve rıhtımlar denizde.

const Probe := preload("res://tests/map_probe.gd")

func test_lanes_never_touch_land() -> void:
	Probe.ensure()
	SeaLanes._ensure()
	var bad: Array = []
	var n := 0
	for key: String in SeaLanes._raw:
		var ab := key.split("-")
		var l := SeaLanes.lane(int(ab[0]), int(ab[1]))
		if l.is_empty():
			bad.append("%s: rota boş" % key)
			continue
		n += 1
		var pts: PackedVector2Array = l[0]
		for i in pts.size() - 1:
			var hit := Probe.first_land(pts[i], pts[i + 1])
			if hit != Vector2.INF:
				bad.append("%s: (%d, %d) karada (bölge %d)" % [key, hit.x, hit.y, Probe.province_at(hit)])
				break
	gt(n, 7000, "denetlenen rota sayısı")
	if not bad.is_empty():
		fail("%d rota karaya değiyor" % bad.size())
	none(bad.slice(0, 15), "kara teması")

## Donanmanın yol grafiğindeki her komşuluğun (deniz–deniz, liman–deniz) bir rotası var: yoksa filo düz çizgiyle karadan geçer
func test_every_naval_link_has_lane() -> void:
	var missing: Array = []
	for a: int in Navy._sea_adj:
		for b: int in Navy._sea_adj[a]:
			if SeaLanes.lane(a, b).is_empty():
				missing.append("%d-%d" % [a, b])
	none(missing.slice(0, 20), "rotası olmayan komşuluk")
	eq(missing.size(), 0, "rotası olmayan komşuluk sayısı")

func test_nodes_and_docks_at_sea() -> void:
	Probe.ensure()
	SeaLanes._ensure()
	var bad: Array = []
	for pid: int in SeaLanes._nodes:
		var p: Vector2 = SeaLanes._nodes[pid]
		if Probe.province_at(p) != pid:
			bad.append("düğüm %d kendi deniz bölgesinde değil (%d)" % [pid, Probe.province_at(p)])
	for key: String in SeaLanes._docks:
		var d: Vector2 = SeaLanes._docks[key]
		if not Probe.is_sea(d):
			bad.append("rıhtım %s karada" % key)
	none(bad.slice(0, 20), "düğüm/rıhtım")
	# her liman şehrinin her komşu denize rıhtımı var
	var no_dock: Array = []
	for city: City in World.cities:
		if not city.is_port or not Navy._sea_adj.has(city.province_id):
			continue
		for s: int in Navy._sea_adj[city.province_id]:
			if SeaLanes.dock(city.province_id, s) == Vector2.INF:
				no_dock.append("%s %d-%d" % [city.name, city.province_id, s])
	none(no_dock.slice(0, 20), "rıhtımı olmayan liman–deniz")
