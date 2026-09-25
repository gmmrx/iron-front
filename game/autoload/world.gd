extends Node
## Dünya durumu: ülkeler, eyaletler, bölgeler. Tüm içerik data/ altından yüklenir.

signal player_changed(tag: String)
signal selection_changed(province_id: int)
signal ownership_changed
signal daily_update
signal game_started
signal control_changed                  ## bölge kontrolü (işgal) değişti
signal country_removed(tag: String)
signal notification(text: String, kind: String)   ## kind: info | war | good | bad

const COUNTRIES_PATH := "res://data/common/countries.json"
const PROVINCES_PATH := "res://data/map/provinces.json"
const STATES_PATH := "res://data/map/states.json"
const CITIES_PATH := "res://data/map/cities.json"
const STRAITS_PATH := "res://data/map/straits.json"

var countries: Dictionary = {}          ## tag -> Country
var country_by_index: Array = [null]    ## indeks -> Country
var states: Dictionary = {}             ## id -> StateRegion
var provinces: Array = []               ## id -> Province (boşluklar null)
var cities: Array[City] = []            ## nüfusa göre azalan
var straits: Array = []                 ## {name, provinces[2], from[2], to[2]}
var map_width := 0
var map_height := 0
var _km_per_px := 1.0
var heightmap_size: Array = [0, 0]
var player_tag := "TUR"
var selected_province := 0
var in_game := false          ## ana menü / ülke seçimi sırasında false
var controller := PackedInt32Array()    ## province id -> kontrol eden ülke indeksi (0 = yok)
var world_tension := 0.0                ## 0..100
var day_count := 0                      ## oyun başından beri geçen gün

func _ready() -> void:
	TranslationServer.set_locale("tr")
	reset()
	GameClock.day_passed.connect(_on_day_passed)

## Başlangıç durumunu (1936) diskten yeniden kur
func reset() -> void:
	countries.clear()
	country_by_index = [null]
	states.clear()
	provinces.clear()
	cities.clear()
	straits.clear()
	world_tension = 0.0
	day_count = 0
	_ln_cache.clear()
	in_game = false
	selected_province = 0
	_load_countries()
	_load_map()
	_init_controller()

func _init_controller() -> void:
	controller.resize(provinces.size())
	controller.fill(0)
	for st: StateRegion in states.values():
		var ci: int = countries[st.owner].index
		for pid in st.provinces:
			controller[pid] = ci

# ------------------------------------------------------------------ yükleme
func _read_json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Dosya açılamadı: %s" % path)
		return null
	return JSON.parse_string(f.get_as_text())

func _load_countries() -> void:
	var data: Dictionary = _read_json(COUNTRIES_PATH)["countries"]
	for tag: String in data:
		var d: Dictionary = data[tag]
		var c := Country.new()
		c.tag = tag
		c.index = country_by_index.size()
		c.names = d["name"]
		c.map_names = d.get("map_name", {})
		c.color = Color(d["color"])
		c.ideology = d["ideology"]
		c.leader = d["leader"]
		c.start_leader = c.leader
		c.stability = d["stability"]
		c.war_support = d["war_support"]
		c.flag_def = d.get("flag", {})
		c.party = d.get("party", {})
		var el: Dictionary = d.get("elections", {})
		c.election_months = int(el.get("months", 0))
		c.next_election = Politics.date_int(el["next"]) if el.has("next") else 0
		countries[tag] = c
		country_by_index.append(c)

func _load_map() -> void:
	var pdata: Dictionary = _read_json(PROVINCES_PATH)
	map_width = int(pdata["width"])
	map_height = int(pdata["height"])
	_km_per_px = float(pdata["km_per_px"])
	var proj: Dictionary = pdata.get("projection", {})
	_miller = proj.get("type", "") == "miller"
	if _miller:
		_lon_min = float(proj["lon_min"])
		_y_top = float(proj["y_top"])
		_px_per_rad = float(proj["px_per_rad"])
		wraps = bool(proj.get("wrap", false))
	heightmap_size = pdata.get("heightmap_size", [map_width / 2, map_height / 2])
	var list: Array = pdata["provinces"]
	var max_id := 0
	for p: Dictionary in list:
		max_id = maxi(max_id, int(p["id"]))
	provinces.resize(max_id + 1)
	for p: Dictionary in list:
		var pr := Province.new()
		pr.id = int(p["id"])
		pr.type = {"land": Province.Type.LAND, "sea": Province.Type.SEA, "lake": Province.Type.LAKE}[p["type"]]
		pr.terrain = p["terrain"]
		pr.state_id = int(p["state"])
		pr.coastal = p["coastal"]
		pr.center = Vector2(p["center"][0], p["center"][1])
		pr.area_km2 = int(p["area_km2"])
		pr.adjacent = PackedInt32Array(p["adj"])
		pr.river_adjacent = PackedInt32Array(p.get("river_adj", []))
		pr.strait_adjacent = PackedInt32Array(p.get("strait_adj", []))
		if p.has("ll"):
			pr.lonlat = Vector2(p["ll"][0], p["ll"][1])
		else:
			pr.lonlat = lonlat(pr.center)
		provinces[pr.id] = pr

	var sdata: Dictionary = _read_json(STATES_PATH)
	for s: Dictionary in sdata["states"]:
		var st := StateRegion.new()
		st.id = int(s["id"])
		st.name = s["name"]
		st.names = s.get("names", {})
		st.adm0 = s.get("adm0", "")
		st.owner = s["owner"]
		st.controller = st.owner
		st.provinces = PackedInt32Array(s["provinces"])
		st.population = int(s["population"])
		st.area_km2 = int(s["area_km2"])
		st.center = Vector2(s["center"][0], s["center"][1])
		states[st.id] = st
		var c: Country = countries.get(st.owner)
		if c:
			c.states.append(st.id)
			c.population += st.population
	for c: Dictionary in _read_json(CITIES_PATH)["cities"]:
		var city := City.new()
		city.id = int(c["id"])
		city.name = c["name"]
		city.names = c.get("names", {})
		city.province_id = int(c["province"])
		city.state_id = int(c["state"])
		city.position = Vector2(c["pos"][0], c["pos"][1])
		city.population = int(c["pop"])
		city.victory_points = int(c["vp"])
		city.is_capital = c["capital"]
		city.is_port = c["port"]
		city.style = c.get("style", "west")
		cities.append(city)
		if states.has(city.state_id):
			states[city.state_id].cities.append(city)
		var pr := province(city.province_id)
		if pr and pr.city == null:
			pr.city = city
	straits = _read_json(STRAITS_PATH)["straits"]
	var caps: Dictionary = sdata["capitals"]
	for tag: String in caps:
		if countries.has(tag):
			countries[tag].capital_state = int(caps[tag])
	for c: Country in countries.values():
		if states.has(c.capital_state):
			c.core_adm0 = states[c.capital_state].adm0
		recompute_manpower_pop(c)

# ------------------------------------------------------------------ sorgular
## Ekvatordaki nominal km/piksel (Miller'da ölçek enleme göre değişir: km_per_px_at kullanın)
func km_per_px() -> float:
	return _km_per_px

var _miller := false
var _lon_min := 0.0
var _y_top := 0.0
var _px_per_rad := 1.0
var wraps := false                      ## harita doğu-batı yönünde sarmalanır (dünya)
var _dist_cache := {}

## Harita pikseli -> (boylam, enlem) derece
func lonlat(p: Vector2) -> Vector2:
	if not _miller:
		return p
	var lon := fposmod(_lon_min + (p.x / map_width) * 360.0 + 180.0, 360.0) - 180.0
	var y := _y_top - p.y / _px_per_rad
	var lat := rad_to_deg(2.5 * atan(exp(0.8 * y)) - 0.625 * PI)
	return Vector2(lon, lat)

## Noktada piksel başına km (Miller: yaklaşık ekvator * cos(enlem))
func km_per_px_at(p: Vector2) -> float:
	if not _miller:
		return _km_per_px
	return _km_per_px * cos(deg_to_rad(lonlat(p).y))

## İki harita noktası arasındaki büyük daire mesafesi (km)
func geo_km(a: Vector2, b: Vector2) -> float:
	if not _miller:
		return a.distance_to(b) * _km_per_px
	return haversine(lonlat(a), lonlat(b))

func haversine(a: Vector2, b: Vector2) -> float:
	var la1 := deg_to_rad(a.y)
	var la2 := deg_to_rad(b.y)
	var dla := la2 - la1
	var dlo := deg_to_rad(b.x - a.x)
	var h := sin(dla * 0.5) ** 2 + cos(la1) * cos(la2) * sin(dlo * 0.5) ** 2
	return 2.0 * 6371.0 * asin(minf(sqrt(h), 1.0))

## Dikişten sarmalanan harita: b'yi a'ya en yakın kopyasına taşır (Pasifik geçişleri için)
func unwrap_near(a: Vector2, b: Vector2) -> Vector2:
	if wraps:
		var dx := b.x - a.x
		if dx > map_width * 0.5:
			b.x -= map_width
		elif dx < -map_width * 0.5:
			b.x += map_width
	return b

func player() -> Country:
	return countries.get(player_tag)

func province(id: int) -> Province:
	if id <= 0 or id >= provinces.size():
		return null
	return provinces[id]

func state_of_province(id: int) -> StateRegion:
	var p := province(id)
	if p == null or p.state_id == 0:
		return null
	return states.get(p.state_id)

func owner_of_province(id: int) -> Country:
	var s := state_of_province(id)
	return countries.get(s.owner) if s else null

func controller_of(pid: int) -> Country:
	if pid <= 0 or pid >= controller.size():
		return null
	return country_by_index[controller[pid]] if controller[pid] > 0 else null

func controller_tag(pid: int) -> String:
	var c := controller_of(pid)
	return c.tag if c else ""

func set_controller(pid: int, tag: String) -> void:
	var c: Country = countries.get(tag)
	if c == null or controller[pid] == c.index:
		return
	controller[pid] = c.index
	_control_dirty = true

var _control_dirty := false

func _process(_d: float) -> void:
	if _control_dirty:
		_control_dirty = false
		control_changed.emit()

## Eyaleti başka ülkeye devret (barış, olay, ilhak)
func transfer_state(sid: int, tag: String) -> void:
	var st: StateRegion = states.get(sid)
	var to: Country = countries.get(tag)
	if st == null or to == null or st.owner == tag:
		return
	var from: Country = countries.get(st.owner)
	if from:
		from.states.erase(sid)
		from.population -= st.population
	st.owner = tag
	st.controller = tag
	to.states.append(sid)
	to.population += st.population
	recompute_manpower_pop(to)
	if from:
		recompute_manpower_pop(from)
	for pid in st.provinces:
		controller[pid] = to.index
	if from and from.capital_state == sid and not from.states.is_empty():
		var best := from.states[0]
		for s2 in from.states:
			if states[s2].victory_points() > states[best].victory_points():
				best = s2
		from.capital_state = best
	_control_dirty = true
	_ownership_dirty = true
	if from and from.states.is_empty():
		_remove_country(from)

var _ownership_dirty := false

func flush_ownership() -> void:
	if _ownership_dirty:
		_ownership_dirty = false
		ownership_changed.emit()

func annex(target: String, by: String) -> void:
	var t: Country = countries.get(target)
	if t == null:
		return
	for sid in t.states.duplicate():
		transfer_state(sid, by)
	flush_ownership()

func _remove_country(c: Country) -> void:
	c.capitulated = true
	country_removed.emit(c.tag)
	notify(tr("NOTE_COUNTRY_GONE") % c.display_name(), "war")

func notify(text: String, kind: String = "info") -> void:
	notification.emit(text, kind)

## Kara bölgesi komşuları (boğaz geçişleri dahil)
var _ln_cache := {}

func land_neighbors(pid: int) -> PackedInt32Array:
	if _ln_cache.has(pid):
		return _ln_cache[pid]
	var r := _land_neighbors(pid)
	_ln_cache[pid] = r
	return r

func _land_neighbors(pid: int) -> PackedInt32Array:
	var p := province(pid)
	var out := PackedInt32Array()
	if p == null:
		return out
	for n in p.adjacent:
		var q := province(n)
		if q and q.is_land():
			out.append(n)
	for n in p.strait_adjacent:
		out.append(n)
	return out

## Sömürge ve işgal edilen topraklar insan gücüne az katkı verir
const NONCORE_MANPOWER := 0.15

func recompute_manpower_pop(c: Country) -> void:
	var n := 0.0
	for sid in c.states:
		var st: StateRegion = states[sid]
		n += st.population * (1.0 if st.adm0 == c.core_adm0 or c.core_adm0 == "" else NONCORE_MANPOWER)
	c.manpower_pop = int(n)

func distance_km(a: int, b: int) -> float:
	var key := mini(a, b) * 100000 + maxi(a, b)
	if _dist_cache.has(key):
		return _dist_cache[key]
	var d: float
	if _miller:
		d = haversine(province(a).lonlat, province(b).lonlat)
	else:
		d = province(a).center.distance_to(province(b).center) * _km_per_px
	_dist_cache[key] = d
	return d

func date_value() -> int:
	return GameClock.year * 10000 + GameClock.month * 100 + GameClock.day

func capital_province(tag: String) -> int:
	var c: Country = countries.get(tag)
	if c == null or not states.has(c.capital_state):
		return 0
	var st: StateRegion = states[c.capital_state]
	var big := st.largest_city()
	return big.province_id if big else st.provinces[0]

func capital_position(tag: String) -> Vector2:
	var c: Country = countries.get(tag)
	if c and states.has(c.capital_state):
		return states[c.capital_state].center
	return Vector2(map_width, map_height) * 0.5

# ------------------------------------------------------------------ eylemler
func set_player(tag: String) -> void:
	if countries.has(tag) and tag != player_tag:
		player_tag = tag
		player_changed.emit(tag)

func start_game(tag: String) -> void:
	player_tag = tag
	if countries.has(tag):
		Economy.set_auto_trade(countries[tag], false)     # oyuncunun ticaretini kimse onun yerine yapmaz
		for w in Air.wings:
			if w.owner == tag:
				w.auto = false                # hava kanatları da oyuncunun emrini bekler
		for d in Military.divisions:
			if d.owner == tag:
				d.hold = true                 # tümenler emir olmadan geri çekilmez
	in_game = true
	player_changed.emit(tag)
	game_started.emit()

## Oynanabilir ülkeler (haritada eyaleti olanlar), nüfusa göre
func playable_countries() -> Array[Country]:
	var out: Array[Country] = []
	for c: Country in countries.values():
		if not c.states.is_empty():
			out.append(c)
	out.sort_custom(func(a: Country, b: Country) -> bool: return a.population > b.population)
	return out

func select_province(id: int) -> void:
	selected_province = id
	selection_changed.emit(id)

func _on_day_passed() -> void:
	day_count += 1
	for c: Country in countries.values():
		if c.exists():
			c.political_power = minf(c.political_power + c.daily_political_power_gain(), 2000.0)
	daily_update.emit()
