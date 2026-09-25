extends Node
## Donanma: gerçek filolar (liman / deniz bölgesi), deniz rotası (A*), görevler (liman, deniz üstünlüğü,
## konvoy baskını, konvoy koruma), saatlik deniz muharebesi, batan gemiler, konvoy kayıpları ve AI.

signal fleets_changed                  ## sayı / bileşim değişti
signal ship_sunk(pos: Vector2, type: String, owner: String)
signal naval_battles_changed

const SHIP_TYPES := ["battleship", "cruiser", "destroyer", "submarine"]
## atk: saatlik ateş gücü, hp: bir geminin dayanımı, speed: km/saat, asw: denizaltı avlama
const SHIPS := {
	"battleship": {"atk": 18.0, "hp": 7.0, "speed": 13.0, "asw": 0.0},
	"cruiser": {"atk": 6.0, "hp": 2.5, "speed": 15.0, "asw": 0.3},
	"destroyer": {"atk": 2.0, "hp": 1.0, "speed": 16.0, "asw": 1.5},
	"submarine": {"atk": 3.0, "hp": 0.7, "speed": 9.0, "asw": 0.0},
}
const DMG_RATE := 0.0032               ## ateş gücü -> saatlik hasar (hp)
const ZONE_KM := 420.0                 ## görev bölgesinin yarıçapı
const RETREAT_ORG := 0.3
const MAX_SURFACE := 40                ## başlangıçta bir filodaki en fazla su üstü gemisi
const SUB_PACK := 16

var fleets: Array[Fleet] = []
var battles: Dictionary = {}           ## deniz pid -> {"sides": [[Fleet...],[Fleet...]], "pos": Vector2}
var convoy_losses: Dictionary = {}     ## tag -> bu hafta kaybedilen konvoy
var _next_id := 1
var _sea_adj: Dictionary = {}          ## pid -> PackedInt32Array (deniz komşuları; liman -> deniz)
var _port_links: Dictionary = {}       ## deniz pid -> [liman pid...]
var _zones: Dictionary = {}            ## merkez pid -> Array[int]
var _zone_sets: Dictionary = {}        ## merkez pid -> {pid: true}
var _power_cache: Dictionary = {}
var _dirty := false

func _ready() -> void:
	GameClock.hour_passed.connect(_on_hour)
	World.daily_update.connect(_on_day)

# ------------------------------------------------------------------ kurulum
func reset() -> void:
	fleets.clear()
	battles.clear()
	convoy_losses.clear()
	_zones.clear()
	_zone_sets.clear()
	_next_id = 1
	_build_graph()
	for c: Country in World.countries.values():
		if c.exists():
			_spawn_start_fleets(c)
	_power_cache.clear()
	fleets_changed.emit()

func _build_graph() -> void:
	_sea_adj.clear()
	_port_links.clear()
	for p: Province in World.provinces:
		if p == null or p.type != Province.Type.SEA:
			continue
		var arr := PackedInt32Array()
		for n in p.adjacent:
			var q := World.province(n)
			if q and q.type == Province.Type.SEA:
				arr.append(n)
		_sea_adj[p.id] = arr
	for city in World.cities:
		if not city.is_port:
			continue
		var pid := city.province_id
		if _sea_adj.has(pid):
			continue
		var arr := PackedInt32Array()
		for n in World.province(pid).adjacent:
			var q := World.province(n)
			if q and q.type == Province.Type.SEA:
				arr.append(n)
				if not _port_links.has(n):
					_port_links[n] = []
				_port_links[n].append(pid)
		if not arr.is_empty():
			_sea_adj[pid] = arr

## Ülkenin kontrol ettiği limanlar (bölge id)
func ports_of(tag: String) -> Array[int]:
	var out: Array[int] = []
	var c: Country = World.countries.get(tag)
	if c == null:
		return out
	for city in World.cities:
		if city.is_port and _sea_adj.has(city.province_id) and World.controller[city.province_id] == c.index:
			if not out.has(city.province_id):
				out.append(city.province_id)
	return out

## Dost (kendi / müttefik) liman mı
func is_friendly_port(tag: String, pid: int) -> bool:
	var p := World.province(pid)
	if p == null or not p.is_land() or not _sea_adj.has(pid):
		return false
	var ctl := World.controller_tag(pid)
	return ctl == tag or Diplomacy.are_allies(ctl, tag)

func _main_port(tag: String) -> int:
	var ports := ports_of(tag)
	if ports.is_empty():
		return 0
	var cap := World.capital_position(tag)
	var best := ports[0]
	var bd := INF
	for pid in ports:
		# büyük deniz üssü olan limanlar öncelikli
		var st := World.state_of_province(pid)
		var nb := st.building_level("naval_base") if st else 0
		var d := World.province(pid).center.distance_to(cap) / (1.0 + nb * 0.15)
		if d < bd:
			bd = d
			best = pid
	return best

func _spawn_start_fleets(c: Country) -> void:
	var have := {}
	for t: String in SHIP_TYPES:
		var n := int(c.stockpile.get(t, 0.0))
		if n > 0:
			have[t] = n
		c.stockpile[t] = 0.0
	if have.is_empty():
		return
	var main := _main_port(c.tag)
	if main == 0:
		return
	# tarihî üsler (veri): ör. İngiltere Portsmouth + İskenderiye (Akdeniz Filosu)
	var bases: Array[int] = []
	var hint: Dictionary = Economy._fleets.get("_bases", {})
	for cname: String in hint.get(c.tag, []):
		for city in World.cities:
			if city.name == cname and city.is_port and _sea_adj.has(city.province_id) and World.controller[city.province_id] == c.index:
				bases.append(city.province_id)
				break
	if bases.is_empty():
		bases.append(main)
	main = bases[0]
	var total_surface := 0
	for t: String in ["battleship", "cruiser", "destroyer"]:
		total_surface += int(have.get(t, 0))
	var nfleets := clampi(ceili(total_surface / float(MAX_SURFACE)), 1, 3) if total_surface > 0 else 0
	for i in nfleets:
		var ships := {}
		for t: String in ["battleship", "cruiser", "destroyer"]:
			var n := int(have.get(t, 0))
			var share := n / nfleets + (1 if i < n % nfleets else 0)
			if share > 0:
				ships[t] = share
		if not ships.is_empty():
			_create(c.tag, ships, bases[i % bases.size()], tr("FLEET_NAME") % (i + 1))
	var subs := int(have.get("submarine", 0))
	var k := 1
	while subs > 0:
		var n := mini(subs, SUB_PACK)
		_create(c.tag, {"submarine": n}, main, tr("SUB_FLEET_NAME") % k)
		subs -= n
		k += 1

func _create(tag: String, ships: Dictionary, port: int, fname: String) -> Fleet:
	var f := Fleet.new()
	f.id = _next_id
	_next_id += 1
	f.owner = tag
	f.name = fname
	f.ships = ships
	f.location = port
	f.home = port
	fleets.append(f)
	_dirty = true
	return f

func fleets_of(tag: String) -> Array[Fleet]:
	var out: Array[Fleet] = []
	for f in fleets:
		if f.owner == tag:
			out.append(f)
	return out

func fleet_by_id(id: int) -> Fleet:
	for f in fleets:
		if f.id == id:
			return f
	return null

func remove_all(tag: String) -> void:
	for f in fleets.duplicate():
		if f.owner == tag:
			fleets.erase(f)
	_dirty = true

# ------------------------------------------------------------------ güç
func fleet_power(f: Fleet) -> float:
	var p := 0.0
	for t: String in f.ships:
		p += float(f.ships[t]) * float(SHIPS[t]["atk"])
	var c: Country = World.countries.get(f.owner)
	return p * (1.0 + (c.mod("naval_power") if c else 0.0)) * (0.5 + 0.5 * f.org)

## Ülkenin toplam deniz gücü (günlük önbellek)
func power(tag: String) -> float:
	if _power_cache.has(tag):
		return _power_cache[tag]
	var p := 0.0
	for f in fleets:
		if f.owner == tag:
			p += fleet_power(f)
	_power_cache[tag] = p
	return p

func ship_count(tag: String, type: String) -> int:
	var n := 0
	for f in fleets:
		if f.owner == tag:
			n += int(f.ships.get(type, 0))
	return n

# ------------------------------------------------------------------ bölgeler
## Görev bölgesi: merkezden ZONE_KM içindeki deniz bölgeleri
func zone(center: int) -> Array:
	if center == 0:
		return []
	if _zones.has(center):
		return _zones[center]
	var c := World.province(center).lonlat
	var seen := {center: true}
	var out: Array = [center]
	var queue: Array[int] = [center]
	while not queue.is_empty():
		var cur: int = queue.pop_back()
		for n in _sea_adj.get(cur, PackedInt32Array()):
			if seen.has(n) or World.province(n).type != Province.Type.SEA:
				continue
			seen[n] = true
			if World.haversine(World.province(n).lonlat, c) <= ZONE_KM:
				out.append(n)
				queue.append(n)
	_zones[center] = out
	var set := {}
	for pid: int in out:
		set[pid] = true
	_zone_sets[center] = set
	return out

func in_zone(center: int, pid: int) -> bool:
	if center == 0:
		return false
	if not _zone_sets.has(center):
		zone(center)
	return _zone_sets[center].has(pid)

## Bölgenin okunur adı: en yakın liman şehri ("Kiel açıkları")
func zone_name(center: int) -> String:
	if center == 0:
		return "—"
	var c := World.province(center).center
	var best: City = null
	var bd := INF
	for city in World.cities:
		if not city.is_port:
			continue
		var d := city.position.distance_to(c) / pow(maxf(float(city.population), 1000.0), 0.2)
		if d < bd:
			bd = d
			best = city
	return tr("SEA_ZONE_NEAR") % best.display_name() if best else tr("SEA_ZONE")

## Tıklanan bölgeden görev merkezi: denizse kendisi, kıyıysa bitişik deniz bölgesi
func sea_for(pid: int) -> int:
	var p := World.province(pid)
	if p == null:
		return 0
	if p.type == Province.Type.SEA:
		return pid
	for n in p.adjacent:
		var q := World.province(n)
		if q and q.type == Province.Type.SEA:
			return n
	return 0

# ------------------------------------------------------------------ yol bulma
func find_path(from: int, to: int) -> PackedInt32Array:
	if from == to or not _sea_adj.has(from) or not _sea_adj.has(to):
		return PackedInt32Array()
	var goal := World.province(to).lonlat
	var open_heap: Array = [[0.0, from]]
	var came := {from: -1}
	var g := {from: 0.0}
	var closed := {}
	var it := 0
	while not open_heap.is_empty() and it < 40000:
		it += 1
		var cur: int = Military._heap_pop(open_heap)[1]
		if cur == to:
			break
		if closed.has(cur):
			continue
		closed[cur] = true
		# limanlar yalnız başlangıç/varış noktası olabilir
		if cur != from and World.province(cur).is_land():
			continue
		var nbrs: Array = Array(_sea_adj.get(cur, PackedInt32Array()))
		nbrs.append_array(_port_links.get(cur, []))
		for n: int in nbrs:
			if World.province(n).is_land() and n != to:
				continue
			var ng: float = g[cur] + leg_km(cur, n)
			if not g.has(n) or ng < g[n]:
				g[n] = ng
				came[n] = cur
				Military._heap_push(open_heap, [ng + World.haversine(World.province(n).lonlat, goal), n])
	if not came.has(to):
		return PackedInt32Array()
	var path := PackedInt32Array()
	var c: int = to
	while c != from:
		path.insert(0, c)
		c = came[c]
	return path

func _go(f: Fleet, to: int) -> bool:
	if f.location == to:
		f.path = PackedInt32Array()
		return true
	var p := find_path(f.location, to)
	if p.is_empty():
		return false
	f.path = p
	f.progress = 0.0
	f.patrol = false
	return true

## İki komşu (deniz / liman) arası seyir mesafesi: deniz yolunun gerçek uzunluğu (km); yoksa kuş uçuşu.
## Yol bulma, hareket ve görünüm aynı mesafeyi kullanır (gemi rotada sabit hızla ilerler).
var _leg_cache := {}
func leg_km(a: int, b: int) -> float:
	var key := a * 100000 + b
	if _leg_cache.has(key):
		return _leg_cache[key]
	var km := World.distance_km(a, b)
	var l := SeaLanes.lane(a, b)
	if not l.is_empty():
		var pts: PackedVector2Array = l[0]
		km = 0.0
		for i in range(1, pts.size()):
			km += World.geo_km(pts[i - 1], pts[i])
	_leg_cache[key] = km
	return km

func speed(f: Fleet) -> float:
	var s := 99.0
	for t: String in f.ships:
		if int(f.ships[t]) > 0:
			s = minf(s, float(SHIPS[t]["speed"]))
	s = s if s < 90.0 else 13.0
	return s * 0.5 if f.patrol else s   # devriye: ağır seyir

# ------------------------------------------------------------------ emirler (oyuncu + AI)
func set_mission(f: Fleet, m: Fleet.Mission, center: int = -1) -> void:
	f.mission = m
	if center >= 0:
		f.zone_center = center
	if m == Fleet.Mission.PORT:
		_go(f, f.home)
	elif f.zone_center == 0:
		f.zone_center = sea_for(f.home)
	f.wander = 0
	if not f.returning and m != Fleet.Mission.PORT and f.zone_center > 0:
		_go(f, f.zone_center)
	_dirty = true

## Yeni ana üs (dost liman)
func rebase(f: Fleet, port: int) -> bool:
	if not is_friendly_port(f.owner, port):
		return false
	f.home = port
	f.mission = Fleet.Mission.PORT
	_go(f, port)
	_dirty = true
	return true

## Oyuncunun sağ tık emri: kendi limanı -> üs değiştir; deniz/kıyı -> görev bölgesi
func order(f: Fleet, pid: int) -> bool:
	if is_friendly_port(f.owner, pid):
		return rebase(f, pid)
	var sea := sea_for(pid)
	if sea == 0:
		return false
	var m := f.mission
	if m == Fleet.Mission.PORT:
		m = Fleet.Mission.RAID if f.is_sub_fleet() else Fleet.Mission.SUPERIORITY
	f.returning = false
	set_mission(f, m, sea)
	return true

# ------------------------------------------------------------------ saatlik
func _on_hour() -> void:
	if fleets.is_empty():
		return
	var t0 := Time.get_ticks_usec()
	_move_all()
	GameClock.timed("navy_move", t0); t0 = Time.get_ticks_usec()
	_missions()
	GameClock.timed("navy_missions", t0); t0 = Time.get_ticks_usec()
	_combat()
	GameClock.timed("navy_combat", t0); t0 = Time.get_ticks_usec()
	_transports()
	_repair()
	GameClock.timed("navy_rest", t0)
	if _dirty:
		_dirty = false
		_power_cache.clear()
		fleets_changed.emit()

func _move_all() -> void:
	for f in fleets:
		if f.path.is_empty():
			continue
		var next: int = f.path[0]
		var dist := leg_km(f.location, next)
		f.progress += speed(f)
		while f.progress >= dist and not f.path.is_empty():
			f.progress -= dist
			f.location = next
			f.path.remove_at(0)
			if f.path.is_empty():
				f.progress = 0.0
				break
			next = f.path[0]
			dist = leg_km(f.location, next)

func _missions() -> void:
	for f in fleets:
		# hızlı yol: üste bekleyen filo
		if f.path.is_empty() and f.location == f.home and (f.mission == Fleet.Mission.PORT or f.reserve) and not f.returning:
			continue
		# organizasyon düştü: üsse dön, toparlanınca göreve geri
		if f.returning:
			if f.location == f.home and f.path.is_empty() and f.org >= 0.8:
				f.returning = false
				if f.mission != Fleet.Mission.PORT and f.zone_center > 0:
					_go(f, f.zone_center)
			elif f.path.is_empty() and f.location != f.home:
				if not _go(f, f.home):
					_rehome(f)
			continue
		if f.mission == Fleet.Mission.PORT or f.zone_center == 0:
			if f.path.is_empty() and f.location != f.home and not _go(f, f.home):
				_rehome(f)
			continue
		var z := zone(f.zone_center)
		var inside := in_zone(f.zone_center, f.location)
		f.submerged = f.is_sub_fleet() and inside
		if not f.path.is_empty():
			continue
		if not inside:
			if not _go(f, f.zone_center):
				f.zone_center = 0
			continue
		# bölgede: düşman filo varsa ona yönel (denizaltılar yalnız savunur), yoksa devriye
		if f.mission != Fleet.Mission.RAID:
			var tgt := _enemy_in_zone(f)
			if tgt > 0 and tgt != f.location:
				_go(f, tgt)
				continue
		# devriye: filo bölgede mevzi tutar; birkaç günde bir komşu deniz bölgesine kısa, ağır bir kayma
		f.wander -= 1
		if f.wander <= 0:
			f.wander = randi_range(96, 192)
			var opts: Array[int] = []
			for n: int in World.province(f.location).adjacent:
				var np := World.province(n)
				if np and np.type == Province.Type.SEA and in_zone(f.zone_center, n):
					opts.append(n)
			if not opts.is_empty() and _go(f, opts[randi() % opts.size()]):
				f.patrol = true

## Üssü düşmana geçtiyse en yakın dost limana
func _rehome(f: Fleet) -> void:
	var best := 0
	var bd := INF
	var here := World.province(f.location).center
	for city in World.cities:
		if city.is_port and is_friendly_port(f.owner, city.province_id):
			var d := city.position.distance_squared_to(here)
			if d < bd and not find_path(f.location, city.province_id).is_empty():
				bd = d
				best = city.province_id
	if best > 0:
		f.home = best
		_go(f, best)

func _enemy_in_zone(f: Fleet) -> int:
	var here := World.province(f.location).center
	var best := 0
	var bd := INF
	for o in fleets:
		if o.submerged or not Diplomacy.are_enemies(o.owner, f.owner):
			continue
		if in_zone(f.zone_center, o.location):
			var d := World.province(o.location).center.distance_squared_to(here)
			if d < bd:
				bd = d
				best = o.location
	return best

# ------------------------------------------------------------------ deniz muharebesi
func _combat() -> void:
	var had := not battles.is_empty()
	battles.clear()
	var at := {}
	for f in fleets:
		f.in_combat = false
		var p := World.province(f.location)
		if p == null or p.type != Province.Type.SEA:
			continue
		if not at.has(f.location):
			at[f.location] = []
		at[f.location].append(f)
	for pid: int in at:
		var here: Array = at[pid]
		if here.size() < 2:
			continue
		var a: Fleet = here[0]
		var side_a: Array = []
		var side_b: Array = []
		for f: Fleet in here:
			if f.owner == a.owner or Diplomacy.are_allies(f.owner, a.owner):
				side_a.append(f)
			elif Diplomacy.are_enemies(f.owner, a.owner):
				side_b.append(f)
		if side_b.is_empty():
			continue
		# dalıştaki denizaltılar: muhrip varsa tespit edilebilir
		side_a = _detected(side_a, side_b)
		side_b = _detected(side_b, side_a)
		if side_a.is_empty() or side_b.is_empty():
			continue
		_fight(side_a, side_b)
		_fight(side_b, side_a)
		for f: Fleet in side_a + side_b:
			f.in_combat = true
		battles[pid] = {"sides": [side_a, side_b], "pos": World.province(pid).center}
		for s: Array in [side_a, side_b]:
			for f: Fleet in s:
				if f.org < RETREAT_ORG and not f.returning:
					f.returning = true
					f.submerged = false
					_go(f, f.home)
					_notify_retreat(f)
	_cleanup()
	if had or not battles.is_empty():
		naval_battles_changed.emit()

func _detected(side: Array, foes: Array) -> Array:
	var asw := 0.0
	for f: Fleet in foes:
		asw += float(f.ships.get("destroyer", 0)) * 1.0 + float(f.ships.get("cruiser", 0)) * 0.2
	var out: Array = []
	for f: Fleet in side:
		if f.is_sub_fleet() and f.submerged and randf() > minf(0.05 + asw * 0.02, 0.6):
			continue
		out.append(f)
	return out

func _fight(shooters: Array, targets: Array) -> void:
	var fire := 0.0
	var asw := 0.0
	for f: Fleet in shooters:
		fire += fleet_power(f)
		for t: String in f.ships:
			asw += float(f.ships[t]) * float(SHIPS[t]["asw"])
	var total_hp := 0.0
	var sub_hp := 0.0
	for f: Fleet in targets:
		for t: String in f.ships:
			var h := float(f.ships[t]) * float(SHIPS[t]["hp"])
			total_hp += h
			if t == "submarine":
				sub_hp += h
	if total_hp <= 0.0:
		return
	var dmg := fire * DMG_RATE * randf_range(0.6, 1.4)
	var sub_dmg := asw * DMG_RATE * 3.0 * randf_range(0.6, 1.4)
	for f: Fleet in targets:
		var recv := 0.0
		for t: String in f.ships.keys():
			var n := int(f.ships[t])
			if n <= 0:
				continue
			var h := n * float(SHIPS[t]["hp"])
			var d := dmg * h / total_hp
			if t == "submarine" and sub_hp > 0.0:
				d += sub_dmg * h / sub_hp
			recv += d
			f.damage[t] = float(f.damage.get(t, 0.0)) + d
			var hp: float = SHIPS[t]["hp"]
			while float(f.damage[t]) >= hp and int(f.ships[t]) > 0:
				f.damage[t] = float(f.damage[t]) - hp
				f.ships[t] = int(f.ships[t]) - 1
				_sunk(f, t)
		var fh := 0.0
		for t: String in f.ships:
			fh += float(f.ships[t]) * float(SHIPS[t]["hp"])
		f.org = maxf(f.org - recv / maxf(fh + recv, 1.0) * 1.6 - 0.015, 0.0)

## Hava saldırısı (liman baskını): hasar büyük gemilere ağırlıklı dağılır
func air_damage(f: Fleet, dmg: float) -> void:
	var total := 0.0
	for t: String in f.ships:
		total += float(f.ships[t]) * float(SHIPS[t]["hp"])
	if total <= 0.0:
		return
	for t: String in f.ships.keys():
		var n := int(f.ships[t])
		if n <= 0:
			continue
		var hp: float = SHIPS[t]["hp"]
		f.damage[t] = float(f.damage.get(t, 0.0)) + dmg * n * hp / total
		while float(f.damage[t]) >= hp and int(f.ships[t]) > 0:
			f.damage[t] = float(f.damage[t]) - hp
			f.ships[t] = int(f.ships[t]) - 1
			_sunk(f, t)
	f.org = maxf(f.org - dmg / total, 0.0)
	_cleanup()

func _sunk(f: Fleet, t: String) -> void:
	_dirty = true
	var pos := World.province(f.location).center
	ship_sunk.emit(pos, t, f.owner)
	var p := World.player_tag
	if t != "destroyer" and t != "submarine" and (f.owner == p or Diplomacy.are_enemies(f.owner, p)):
		World.notify(tr("NOTE_SHIP_SUNK") % [World.countries[f.owner].display_name(), tr("SHIP_" + t)], "good" if f.owner != p else "bad")

func _notify_retreat(f: Fleet) -> void:
	if f.owner == World.player_tag:
		World.notify(tr("NOTE_FLEET_RETREAT") % f.name, "bad")

func _cleanup() -> void:
	for f in fleets.duplicate():
		if f.total() <= 0:
			fleets.erase(f)
			_dirty = true
			if f.owner == World.player_tag or Diplomacy.are_enemies(f.owner, World.player_tag):
				World.notify(tr("NOTE_FLEET_DESTROYED") % [f.name, World.countries[f.owner].display_name()], "bad" if f.owner == World.player_tag else "good")

## Deniz hâkimiyeti: bölgeyi görev alanı olarak tutan (üstünlük / koruma) filoların gücü, taraf başına
var _control_cache := {}
var _control_hour := -1

func _control_map() -> Dictionary:
	var h := World.day_count * 24 + GameClock.hour
	if _control_hour == h:
		return _control_cache
	_control_hour = h
	_control_cache.clear()
	for f in fleets:
		if f.returning or f.in_port() or f.mission == Fleet.Mission.PORT or f.mission == Fleet.Mission.RAID or f.zone_center == 0:
			continue
		var pw := fleet_power(f)
		for pid: int in zone(f.zone_center):
			if not _control_cache.has(pid):
				_control_cache[pid] = {}
			_control_cache[pid][f.owner] = float(_control_cache[pid].get(f.owner, 0.0)) + pw
	return _control_cache

## pid'de tag için (dost güç, düşman güç)
func sea_control(pid: int, tag: String) -> Vector2:
	var m: Dictionary = _control_map().get(pid, {})
	var own := 0.0
	var foe := 0.0
	for t: String in m:
		if t == tag or Diplomacy.are_allies(t, tag):
			own += float(m[t])
		elif Diplomacy.are_enemies(t, tag):
			foe += float(m[t])
	return Vector2(own, foe)

## Nakliye için tehlikeli deniz: düşman hâkimiyeti dostunkinden fazla
func hostile_sea(pid: int, tag: String) -> bool:
	if not _control_map().has(pid):
		return false
	var c := sea_control(pid, tag)
	return c.y > c.x

## Boğaz geçişi (a <-> b) düşman deniz hâkimiyetinde mi (üstün düşman donanması boğazı keser)
var _strait_sea := {}

func strait_blocked(a: int, b: int, tag: String) -> bool:
	var key := mini(a, b) * 100000 + maxi(a, b)
	if not _strait_sea.has(key):
		var sea := 0
		for n in World.province(a).adjacent:
			if n in World.province(b).adjacent and World.province(n).type == Province.Type.SEA:
				sea = n
				break
		if sea == 0:
			sea = sea_for(a)
		_strait_sea[key] = sea
	var s: int = _strait_sea[key]
	return s > 0 and hostile_sea(s, tag)

## Denizdeki nakliye (tümen): düşman deniz hâkimiyetindeki bölgede ya da düşman filosuyla karşılaşınca ağır kayıp
func _transports() -> void:
	if Military.at_sea.is_empty():
		return
	var at := {}
	for f in fleets:
		if not f.submerged and World.province(f.location).type == Province.Type.SEA:
			if not at.has(f.location):
				at[f.location] = []
			at[f.location].append(f.owner)
	for d: Division in Military.at_sea.keys():
		var enemy := false
		var cover := false
		for t: String in at.get(d.province, []):
			if Diplomacy.are_enemies(t, d.owner):
				enemy = true
			elif t == d.owner or Diplomacy.are_allies(t, d.owner):
				cover = true
		var ctl := sea_control(d.province, d.owner)
		var loss := 0.0
		if enemy and not cover:
			loss = 0.07
		elif ctl.y > ctl.x * 1.2:
			loss = 0.035 * clampf(ctl.y / maxf(ctl.x + ctl.y, 1.0) * 1.5, 0.3, 1.0)
		if loss <= 0.0:
			continue
		d.strength -= loss
		d.org = maxf(d.org - 1.0, 0.0)
		if d.strength <= 0.05:
			if d.owner == World.player_tag or Diplomacy.are_enemies(d.owner, World.player_tag):
				World.notify(tr("NOTE_TRANSPORT_SUNK") % [d.name, World.countries[d.owner].display_name()], "bad" if d.owner == World.player_tag else "good")
			Military.disband(d)

func _repair() -> void:
	if GameClock.hour % 6 != 0:
		return
	for f in fleets:
		if f.in_combat or (f.org >= 1.0 and f.damage.is_empty()):
			continue
		if f.in_port():
			var st := World.state_of_province(f.location)
			var nb := st.building_level("naval_base") if st else 0
			f.org = minf(f.org + 0.06 + nb * 0.012, 1.0)
			for t: String in f.damage.keys():
				f.damage[t] = maxf(float(f.damage[t]) - 0.12 * (1.0 + nb * 0.2), 0.0)
				if float(f.damage[t]) <= 0.0:
					f.damage.erase(t)
		else:
			f.org = minf(f.org + 0.012, 1.0)

# ------------------------------------------------------------------ günlük
func _on_day() -> void:
	if not World.in_game and fleets.is_empty():
		return
	var t0 := Time.get_ticks_usec()
	_power_cache.clear()
	_absorb_new_ships()
	_raid_convoys()
	if World.day_count % 7 == 0:
		_weekly_report()
	for c: Country in World.countries.values():
		if c.exists() and c.tag != World.player_tag and (World.day_count + c.index) % 5 == 0:
			_ai(c)
	GameClock.timed("navy_day", t0)

## Tersanelerden çıkan gemiler stoktan ana üsteki yedek filoya katılır
func _absorb_new_ships() -> void:
	for c: Country in World.countries.values():
		if not c.exists():
			continue
		for t: String in SHIP_TYPES:
			var n := int(c.stockpile.get(t, 0.0))
			if n <= 0:
				continue
			var sub := t == "submarine"
			var target: Fleet = null
			for f in fleets:
				if f.owner == c.tag and f.reserve and f.is_sub_fleet() == sub:
					target = f
					break
			if target == null:
				var port := _main_port(c.tag)
				if port == 0:
					continue
				target = _create(c.tag, {}, port, tr("RESERVE_SUB_FLEET" if sub else "RESERVE_FLEET"))
				target.reserve = true
			c.stockpile[t] = float(c.stockpile.get(t, 0.0)) - n
			target.ships[t] = int(target.ships.get(t, 0)) + n
			_dirty = true

## Yedek filo yeterince büyüyünce: filo sayısı azsa yeni filo olur, yoksa en zayıf filoya katılır
func _promote_reserves(c: Country) -> void:
	for r in fleets_of(c.tag):
		if not r.reserve or r.total() < (8 if r.is_sub_fleet() else 6) or not r.in_port():
			continue
		var same: Array[Fleet] = []
		for f in fleets_of(c.tag):
			if not f.reserve and f.is_sub_fleet() == r.is_sub_fleet():
				same.append(f)
		# büyük güçler 6 filoya kadar; 12+ gemilik yedek beklemeden filo olur (limanda çürümesin)
		var cap := (6 if c.is_major() else 3) + (1 if r.is_sub_fleet() else 0)
		if same.size() < cap or r.total() >= 12:
			r.reserve = false
			r.name = tr("SUB_FLEET_NAME" if r.is_sub_fleet() else "FLEET_NAME") % (same.size() + 1)
			_dirty = true
			continue
		var weakest: Fleet = same[0]
		for f in same:
			if fleet_power(f) < fleet_power(weakest):
				weakest = f
		if weakest.in_port() or weakest.location == r.location:
			for t: String in r.ships:
				weakest.ships[t] = int(weakest.ships.get(t, 0)) + int(r.ships[t])
			r.ships.clear()
			_dirty = true
		elif r.mission != Fleet.Mission.PORT or r.home != weakest.home:
			rebase(r, weakest.home)
	_cleanup()

## Konvoy baskını: bölgedeki denizaltılar düşman konvoylarını batırır; muhripler denizaltı avlar
func _raid_convoys() -> void:
	for f in fleets:
		if f.mission != Fleet.Mission.RAID or f.returning or f.zone_center == 0:
			continue
		var z := zone(f.zone_center)
		if not in_zone(f.zone_center, f.location):
			continue
		var subs := int(f.ships.get("submarine", 0))
		if subs <= 0:
			continue
		for e: String in Diplomacy.enemies_of(f.owner):
			var ec: Country = World.countries[e]
			var convoys := float(ec.stockpile.get("convoy", 0.0))
			if convoys < 1.0:
				continue
			var exposure := 0.35
			for pid: int in z:
				for port: int in _port_links.get(pid, []):
					if World.controller_tag(port) == e:
						exposure = 1.0
			# koruma: bölgedeki düşman muhrip / kruvazörleri
			var escort := 0.0
			for o in fleets:
				if o.owner == e and in_zone(f.zone_center, o.location) and o.mission != Fleet.Mission.PORT:
					escort += float(o.ships.get("destroyer", 0)) * (2.0 if o.mission == Fleet.Mission.ESCORT else 1.0)
			var sunk := subs * 0.025 * exposure * randf_range(0.5, 1.5) / (1.0 + escort / maxf(subs * 2.0, 1.0))
			sunk = minf(sunk, convoys)
			ec.stockpile["convoy"] = convoys - sunk
			convoy_losses[e] = float(convoy_losses.get(e, 0.0)) + sunk
			# eskort denizaltı batırabilir
			if escort > 0.0 and randf() < minf(escort * 0.01, 0.35):
				f.ships["submarine"] = subs - 1
				_sunk(f, "submarine")
	_cleanup()

func _weekly_report() -> void:
	var p := World.player_tag
	var lost := float(convoy_losses.get(p, 0.0))
	if lost >= 1.0:
		World.notify(tr("NOTE_CONVOYS_LOST") % roundi(lost), "bad")
	var sunk := 0.0
	for e in Diplomacy.enemies_of(p):
		sunk += float(convoy_losses.get(e, 0.0))
	if sunk >= 1.0:
		World.notify(tr("NOTE_CONVOYS_SUNK") % roundi(sunk), "good")
	convoy_losses.clear()

# ------------------------------------------------------------------ yapay zekâ
func _ai(c: Country) -> void:
	_promote_reserves(c)
	_ai_convoys(c)
	var own: Array[Fleet] = []
	for f in fleets_of(c.tag):
		if not f.reserve:
			own.append(f)
	if own.is_empty():
		return
	var home := _main_port(c.tag)
	var enemies := Diplomacy.enemies_of(c.tag)
	if enemies.is_empty():
		# barış: büyük donanmaların ilk filosu kendi sularında devriye gezer
		for i in own.size():
			var f: Fleet = own[i]
			if f.returning:
				continue
			var want := Fleet.Mission.SUPERIORITY if i == 0 and c.is_major() and not f.is_sub_fleet() else Fleet.Mission.PORT
			if f.mission != want:
				set_mission(f, want, sea_for(f.home))
		return
	# savaş: en yakın düşman limanının önü hedef bölge
	var target := 0
	var from := World.province(home).center if home > 0 else World.capital_position(c.tag)
	var foe_power := 0.0
	var cands: Array = []
	for e in enemies:
		foe_power += power(e)
		for pid in ports_of(e):
			cands.append([World.province(pid).center.distance_squared_to(from), pid])
	cands.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for i in mini(cands.size(), 4):
		if not find_path(home, int(cands[i][1])).is_empty():
			target = int(cands[i][1])
			break
	var own_power := power(c.tag)
	var strike := sea_for(target) if target > 0 else 0
	var defend := sea_for(home)
	for f in own:
		if f.returning:
			continue
		if f.is_sub_fleet():
			if strike > 0 and (f.mission != Fleet.Mission.RAID or f.zone_center != strike):
				set_mission(f, Fleet.Mission.RAID, strike)
		else:
			# eşikte gidip gelmesin: saldırı bölgesindeyse ancak belirgin zayıflayınca geri çekilir
			var need := 0.55 if f.zone_center == strike else 0.8
			var zc := strike if own_power >= foe_power * need and strike > 0 else defend
			if f.mission != Fleet.Mission.SUPERIORITY or f.zone_center != zc:
				set_mission(f, Fleet.Mission.SUPERIORITY, zc)

## Konvoy açığı varsa tersanelerin bir kısmı konvoy üretir
func _ai_convoys(c: Country) -> void:
	if Economy.convoy_factor(c) >= 0.95:
		return
	for l in c.production_lines:
		if l.equipment == "convoy":
			return
	var yards := Economy.free_military(c, true)
	if yards > 0:
		var line := Economy.add_line(c, "convoy")
		line.factories = mini(yards, 5)

# ------------------------------------------------------------------ kayıt
func to_save() -> Array:
	var out := []
	for f in fleets:
		out.append({"id": f.id, "o": f.owner, "n": f.name, "s": f.ships, "d": f.damage, "l": f.location, "h": f.home,
			"p": Array(f.path), "pr": f.progress, "m": int(f.mission), "z": f.zone_center, "org": f.org, "r": f.returning, "res": f.reserve})
	return out

func from_save(arr: Array, next_id: int) -> void:
	fleets.clear()
	_build_graph()
	_zones.clear()
	_zone_sets.clear()
	for fd: Dictionary in arr:
		var f := Fleet.new()
		f.id = int(fd["id"]); f.owner = fd["o"]; f.name = fd["n"]
		for t: String in fd["s"]:
			f.ships[t] = int(fd["s"][t])
		f.damage = fd["d"]
		f.location = int(fd["l"]); f.home = int(fd["h"]); f.path = PackedInt32Array(fd["p"]); f.progress = float(fd["pr"])
		f.mission = int(fd["m"]) as Fleet.Mission
		f.zone_center = int(fd["z"]); f.org = float(fd["org"]); f.returning = bool(fd["r"]); f.reserve = bool(fd.get("res", false))
		fleets.append(f)
	_next_id = next_id
	_power_cache.clear()
	fleets_changed.emit()
