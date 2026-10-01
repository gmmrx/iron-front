extends "res://tests/test_case.gd"
## 1 Ocak 1936 sınırları: tests/data/borders_1936.json'daki her kasabanın haritadaki sahibi beklenenle aynı
## (sınırın iki yanından ~270 nokta: Yukarı Silezya, Danzig, Riga sınırı, Budjak, Karelya, Karafuto, Kwantung,
## Jehol, Fiume, Onikiadalar, İspanyol Fas'ı, Cebelitarık...). Harita düzeltmesi: tools/fix_borders_1936.py.

const Probe := preload("res://tests/map_probe.gd")

func _points() -> Array:
	var f := FileAccess.open("res://tests/data/borders_1936.json", FileAccess.READ)
	var data: Variant = JSON.parse_string(f.get_as_text())
	return (data as Dictionary)["points"]

## (boylam, enlem) -> harita pikseli (Miller; World.lonlat'ın tersi)
func _to_map(lon: float, lat: float) -> Vector2:
	var x := fposmod(lon - World._lon_min, 360.0) / 360.0 * World.map_width
	var y := (World._y_top - 1.25 * log(tan(PI / 4.0 + 0.4 * deg_to_rad(lat)))) * World._px_per_rad
	return Vector2(x, y)

## Noktadaki kara bölgesi; kıyı kasabası denize düşerse 5 piksel içindeki en yakın kara (2 km piksel)
func _land_at(p: Vector2) -> int:
	var pid := Probe.province_at(p)
	var pr := World.province(pid)
	if pr != null and pr.is_land():
		return pid
	var best := 0
	var bd := 1e9
	for dy in range(-5, 6):
		for dx in range(-5, 6):
			var q := Probe.province_at(p + Vector2(dx, dy))
			var qp := World.province(q)
			if qp != null and qp.is_land() and dx * dx + dy * dy < bd:
				bd = dx * dx + dy * dy
				best = q
	return best

func test_points_have_1936_owner() -> void:
	var wrong: Array = []
	for pt: Array in _points():
		var pid := _land_at(_to_map(float(pt[1]), float(pt[2])))
		var owner := World.owner_of_province(pid) if pid > 0 else null
		var tag := owner.tag if owner else "-"
		if tag != str(pt[3]):
			wrong.append("%s: beklenen %s, haritada %s (bölge %d)" % [pt[0], pt[3], tag, pid])
	none(wrong, "1936 sınırı")

## Ayrı yönetimli küçük topraklar kendi ülkesi ve başkentiyle başlar; şehirleri kendi eyaletinde
func test_small_territories() -> void:
	for tag: String in ["DNZ", "TNG"]:
		var c: Country = World.countries.get(tag)
		if check(c != null and c.exists(), "%s var" % tag):
			gt(World.capital_province(tag), 0, "%s başkenti" % tag)
	for pair: Array in [["Gibraltar", "ENG"], ["Gdańsk", "DNZ"], ["Tangier", "TNG"], ["Macau", "POR"], ["Dalian", "JAP"],
			["Rijeka", "ITA"], ["Zadar", "ITA"], ["Vyborg", "FIN"], ["Chengde", "MAN"], ["Panama City", "PAN"]]:
		var found := false
		for city: City in World.cities:
			if city.name == pair[0]:
				found = true
				eq(World.states[city.state_id].owner, pair[1], "%s şehrinin sahibi" % pair[0])
		check(found, "%s şehri var" % pair[0])

## Tarihî adımlar yeni topraklara ulaşır: Danzig Bunalımı odağı Danzig'e katılma olayını gönderir
func test_danzig_joins_reich_by_event() -> void:
	var ger: Country = World.countries["GER"]
	Politics.fire_event(World.countries["DNZ"], "danzig_reunion", "GER")
	check(not World.countries["DNZ"].exists(), "Danzig Reich'a katıldı")
	for city: City in World.cities:
		if city.name == "Gdańsk":
			eq(World.states[city.state_id].owner, ger.tag, "Gdańsk Almanya'nın")
