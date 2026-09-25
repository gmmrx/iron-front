extends Node
## Hava kuvvetleri: hava kanatları hava üslerine konuşlanır; görev bölgesinde (menzil içinde) hava üstünlüğü,
## yakın hava desteği ya da liman baskını yapar. Günlük hava muharebesi (it dalaşı, uçaksavar), bölgesel hava
## üstünlüğü kara muharebesine etki eder. Oyuncunun kanatları isterse yapay zekâya bırakılabilir.

signal wings_changed
signal air_fights_changed

const ZONE_KM := 350.0
const WING_SIZE := 100
## air: hava saldırısı, def: hava savunması, ground: kara desteği, range: km
const TYPES := {
	"fighter": {"eq": "fighter_equipment", "air": 3.0, "def": 1.2, "ground": 0.15, "range": 900.0},
	"cas": {"eq": "cas_equipment", "air": 0.6, "def": 0.8, "ground": 1.0, "range": 500.0},
	"bomber": {"eq": "tactical_bomber_equipment", "air": 0.8, "def": 1.4, "ground": 0.8, "range": 900.0},
}

var wings: Array[AirWing] = []
var fights: Dictionary = {}            ## bölge merkezi pid -> {"pos": Vector2, "intensity": float, "tags": [..]}
var _next_id := 1
var _bonus_cache: Dictionary = {}
var _dirty := false

func _ready() -> void:
	World.daily_update.connect(_on_day)

# ------------------------------------------------------------------ kurulum
func reset() -> void:
	wings.clear()
	fights.clear()
	_bonus_cache.clear()
	_next_id = 1
	for c: Country in World.countries.values():
		if c.exists():
			_absorb(c)
	wings_changed.emit()

func type_of(eq: String) -> String:
	for t: String in TYPES:
		if TYPES[t]["eq"] == eq:
			return t
	return ""

## Ülkenin hava üsleri (kendi + kontrol edilen eyalet, seviye > 0)
func bases_of(tag: String) -> Array[int]:
	var out: Array[int] = []
	var c: Country = World.countries.get(tag)
	if c == null:
		return out
	for sid in c.states:
		var st: StateRegion = World.states[sid]
		if st.building_level("air_base") > 0 and _controlled(st, tag):
			out.append(sid)
	return out

func _controlled(st: StateRegion, tag: String) -> bool:
	var city := st.largest_city()
	var pid := city.province_id if city else st.provinces[0]
	return World.controller_tag(pid) == tag

func base_pos(sid: int) -> Vector2:
	var st: StateRegion = World.states[sid]
	var city := st.largest_city()
	return city.position if city else st.center

func _home_base(tag: String) -> int:
	var bases := bases_of(tag)
	if bases.is_empty():
		return 0
	var cap := World.capital_position(tag)
	var best := bases[0]
	var bd := INF
	for sid in bases:
		var st: StateRegion = World.states[sid]
		var d := base_pos(sid).distance_to(cap) / (1.0 + st.building_level("air_base") * 0.1)
		if d < bd:
			bd = d
			best = sid
	return best

## Oyuncu (türün klasiklerindeki gibi): stoktaki uçakları seçtiği hava üssüne kanat olarak konuşlandırır
func deploy(c: Country, type: String, base: int, n: int = WING_SIZE) -> AirWing:
	var eq: String = TYPES[type]["eq"]
	n = mini(n, int(c.stockpile.get(eq, 0.0)))
	if n <= 0 or not base in bases_of(c.tag):
		return null
	c.stockpile[eq] = float(c.stockpile.get(eq, 0.0)) - n
	var w := AirWing.new()
	w.id = _next_id
	_next_id += 1
	w.owner = c.tag
	w.type = type
	w.planes = n
	w.base = base
	var k := 1
	for o in wings:
		if o.owner == c.tag and o.type == type:
			k += 1
	w.name = tr("WING_NAME_" + type) % k
	wings.append(w)
	_dirty = true
	wings_changed.emit()
	return w

## Kanadı dağıt: uçaklar stoğa döner
func disband(w: AirWing) -> void:
	var c: Country = World.countries.get(w.owner)
	if c:
		var eq: String = TYPES[w.type]["eq"]
		c.stockpile[eq] = float(c.stockpile.get(eq, 0.0)) + w.planes
	wings.erase(w)
	wings_changed.emit()

## Kanadı stoktan tamamla (üsteyken)
func reinforce(w: AirWing) -> void:
	var c: Country = World.countries.get(w.owner)
	var eq: String = TYPES[w.type]["eq"]
	var add := mini(WING_SIZE - w.planes, int(c.stockpile.get(eq, 0.0)))
	if add > 0:
		c.stockpile[eq] = float(c.stockpile.get(eq, 0.0)) - add
		w.planes += add
		wings_changed.emit()

## Üretimden (stok) uçaklar kanatlara: dolmayan kanat varsa tamamlanır, yoksa yeni kanat (AI; oyuncu elle konuşlandırır)
func _absorb(c: Country) -> void:
	if World.in_game and c.tag == World.player_tag:
		return
	for t: String in TYPES:
		var eq: String = TYPES[t]["eq"]
		var n := int(c.stockpile.get(eq, 0.0))
		if n <= 0:
			continue
		var base := _home_base(c.tag)
		if base == 0:
			continue
		c.stockpile[eq] = float(c.stockpile.get(eq, 0.0)) - n
		for w in wings:
			if n <= 0:
				break
			if w.owner == c.tag and w.type == t and w.planes < WING_SIZE:
				var add := mini(n, WING_SIZE - w.planes)
				w.planes += add
				n -= add
		while n > 0:
			var w := AirWing.new()
			w.id = _next_id
			_next_id += 1
			w.owner = c.tag
			w.type = t
			w.planes = mini(n, WING_SIZE)
			w.base = base
			var k := 1
			for o in wings:
				if o.owner == c.tag and o.type == t:
					k += 1
			w.name = tr("WING_NAME_" + t) % k
			wings.append(w)
			n -= w.planes
		_dirty = true

func wings_of(tag: String) -> Array[AirWing]:
	var out: Array[AirWing] = []
	for w in wings:
		if w.owner == tag:
			out.append(w)
	return out

func planes(tag: String, type: String = "") -> int:
	var n := 0
	for w in wings:
		if w.owner == tag and (type == "" or w.type == type):
			n += w.planes
	return n

## Soyut hava gücü (AI kararları, ordu paneli)
func power(tag: String) -> float:
	var p := 0.0
	for w in wings:
		if w.owner == tag:
			p += w.planes * (float(TYPES[w.type]["air"]) + float(TYPES[w.type]["ground"]))
	return p

func remove_all(tag: String) -> void:
	for w in wings.duplicate():
		if w.owner == tag:
			wings.erase(w)
	_dirty = true

# ------------------------------------------------------------------ menzil, bölge
func distance_km(a: Vector2, b: Vector2) -> float:
	return World.geo_km(a, b)

func in_range(w: AirWing, pid: int) -> bool:
	return distance_km(base_pos(w.base), World.province(pid).center) <= float(TYPES[w.type]["range"])

func covers(w: AirWing, pid: int) -> bool:
	return w.on_mission() and distance_km(World.province(w.zone).center, World.province(pid).center) <= ZONE_KM

func zone_name(pid: int) -> String:
	if pid == 0:
		return "—"
	var st := World.state_of_province(pid)
	if st:
		return st.display_name()
	return Navy.zone_name(pid)

# ------------------------------------------------------------------ emirler
func set_mission(w: AirWing, m: AirWing.Mission, zone: int = -1) -> bool:
	if zone >= 0:
		if zone > 0 and not in_range(w, zone):
			return false
		w.zone = zone
	w.mission = m
	if m == AirWing.Mission.IDLE:
		w.zone = 0
	_dirty = true
	_bonus_cache.clear()
	return true

func rebase(w: AirWing, sid: int) -> bool:
	if not sid in bases_of(w.owner):
		return false
	w.base = sid
	if w.zone > 0 and not in_range(w, w.zone):
		w.mission = AirWing.Mission.IDLE
		w.zone = 0
	_dirty = true
	return true

## Oyuncunun haritadaki emri: kendi hava üssü olan eyalet -> üs değiştir; başka yer -> görev bölgesi
func order(w: AirWing, pid: int) -> String:
	var st := World.state_of_province(pid)
	if st and st.owner == w.owner and st.id in bases_of(w.owner) and st.id != w.base:
		return "" if rebase(w, st.id) else "AIR_ERR_BASE"
	if not in_range(w, pid):
		return "AIR_ERR_RANGE"
	var m := w.mission
	if m == AirWing.Mission.IDLE:
		m = AirWing.Mission.SUPERIORITY if w.type == "fighter" else AirWing.Mission.CAS
	w.auto = false
	set_mission(w, m, pid)
	return ""

# ------------------------------------------------------------------ kara muharebesine etki
## Bölgede tag için saldırı/savunma çarpanı eki: hava üstünlüğü payı + yakın hava desteği (günlük önbellek)
func bonus(pid: int, tag: String) -> float:
	var key := "%d:%s" % [pid, tag]
	if _bonus_cache.has(key):
		return _bonus_cache[key]
	var own_f := 0.0
	var foe_f := 0.0
	var own_g := 0.0
	for w in wings:
		if not w.on_mission() or not covers(w, pid):
			continue
		var friend := w.owner == tag or Diplomacy.are_allies(w.owner, tag)
		var foe := not friend and Diplomacy.are_enemies(w.owner, tag)
		if not friend and not foe:
			continue
		var t: Dictionary = TYPES[w.type]
		var air := w.planes * (float(t["air"]) if w.mission == AirWing.Mission.SUPERIORITY else float(t["air"]) * 0.3)
		if friend:
			own_f += air
			if w.mission == AirWing.Mission.CAS:
				own_g += w.planes * float(t["ground"])
		else:
			foe_f += air
	var b := 0.0
	if own_f + foe_f > 0.0:
		b = clampf((own_f / (own_f + foe_f) - 0.5) * 0.5, -0.25, 0.25)
	# yakın destek: düşman hava üstünlüğü altında etkisi düşer
	var sup := own_f / maxf(own_f + foe_f, 1.0) if own_f + foe_f > 0.0 else 0.5
	b += minf(own_g * 0.0012 * (0.3 + 0.7 * sup), 0.3)
	_bonus_cache[key] = b
	return b

## Bölgedeki hava üstünlüğü payı (0..1, 0.5 = yok / eşit)
func superiority(pid: int, tag: String) -> float:
	var own := 0.0
	var foe := 0.0
	for w in wings:
		if not w.on_mission() or not covers(w, pid):
			continue
		var a := w.planes * float(TYPES[w.type]["air"]) * (1.0 if w.mission == AirWing.Mission.SUPERIORITY else 0.3)
		if w.owner == tag or Diplomacy.are_allies(w.owner, tag):
			own += a
		elif Diplomacy.are_enemies(w.owner, tag):
			foe += a
	return own / (own + foe) if own + foe > 0.0 else 0.5

# ------------------------------------------------------------------ günlük
func _on_day() -> void:
	if wings.is_empty() and not World.in_game:
		return
	var t0 := Time.get_ticks_usec()
	_bonus_cache.clear()
	for c: Country in World.countries.values():
		if c.exists():
			_absorb(c)
	_air_combat()
	_port_strikes()
	for c: Country in World.countries.values():
		if c.exists() and (World.day_count + c.index) % 3 == 0:
			_ai(c)
	if _dirty:
		_dirty = false
		wings_changed.emit()
	GameClock.timed("air", t0)

## Görev bölgeleri örtüşen düşman kanatları çatışır; bombardıman/destek uçaklarını uçaksavar da vurur
func _air_combat() -> void:
	var had := not fights.is_empty()
	fights.clear()
	var active: Array[AirWing] = []
	for w in wings:
		w.losses_today = 0.0
		w.kills_today = 0.0
		if w.on_mission():
			active.append(w)
	var loss := {}
	for w in active:
		var wz := World.province(w.zone).center
		var enemy_air := 0.0
		var own_cover := 0.0
		for o in active:
			if o == w or distance_km(World.province(o.zone).center, wz) > ZONE_KM * 1.6:
				continue
			var oa := o.planes * float(TYPES[o.type]["air"]) * (1.0 if o.mission == AirWing.Mission.SUPERIORITY else 0.3)
			if Diplomacy.are_enemies(o.owner, w.owner):
				enemy_air += oa
			elif o.owner == w.owner or Diplomacy.are_allies(o.owner, w.owner):
				if o.type == "fighter":
					own_cover += o.planes * float(TYPES[o.type]["def"])
		var d := 0.0
		if enemy_air > 0.0:
			var defense := w.planes * float(TYPES[w.type]["def"]) + (own_cover if w.type != "fighter" else 0.0) * 0.5
			d = 0.007 * enemy_air / maxf(defense + enemy_air, 1.0) * randf_range(0.7, 1.3)
			var key: int = w.zone
			if not fights.has(key):
				fights[key] = {"pos": wz, "intensity": 0.0, "tags": []}
			fights[key]["intensity"] = float(fights[key]["intensity"]) + enemy_air
			if not w.owner in fights[key]["tags"]:
				fights[key]["tags"].append(w.owner)
		# uçaksavar: düşman eyaletlerindeki uçaksavar binaları (destek / bombardıman)
		if w.type != "fighter" and w.mission != AirWing.Mission.SUPERIORITY:
			var st := World.state_of_province(w.zone)
			if st and Diplomacy.are_enemies(st.owner, w.owner):
				d += 0.004 * st.building_level("anti_air")
		loss[w] = minf(d, 0.08)
	for w: AirWing in loss:
		var lost := int(round(w.planes * float(loss[w])))
		if lost > 0:
			w.planes -= lost
			w.losses_today = lost
			_dirty = true
	for w in wings.duplicate():
		if w.planes <= 0:
			wings.erase(w)
			_dirty = true
	_report_losses()
	if had or not fights.is_empty():
		air_fights_changed.emit()

func _report_losses() -> void:
	var p := World.player_tag
	if World.day_count % 7 != 0:
		return
	# haftalık özet notify'ı: basitlik için yalnız günlük kayıp büyükse
	var mine := 0.0
	for w in wings:
		if w.owner == p:
			mine += w.losses_today
	if mine >= 20.0:
		World.notify(tr("NOTE_AIR_LOSSES") % roundi(mine), "bad")

## Liman baskını: bölgedeki düşman limanında demirli filolara hasar
func _port_strikes() -> void:
	for w in wings:
		if w.mission != AirWing.Mission.PORT_STRIKE or not w.on_mission():
			continue
		var wz := World.province(w.zone).center
		for f in Navy.fleets:
			if not f.in_port() or not Diplomacy.are_enemies(f.owner, w.owner):
				continue
			if distance_km(World.province(f.location).center, wz) > ZONE_KM:
				continue
			var sup := superiority(f.location, w.owner)
			var dmg := w.planes * float(TYPES[w.type]["ground"]) * 0.02 * sup * randf_range(0.6, 1.4)
			Navy.air_damage(f, dmg)

# ------------------------------------------------------------------ yapay zekâ
func _ai(c: Country) -> void:
	var mine: Array[AirWing] = []
	for w in wings:
		if w.owner == c.tag and w.auto:
			mine.append(w)
	if mine.is_empty():
		return
	if not Diplomacy.at_war(c.tag):
		for w in mine:
			if w.mission != AirWing.Mission.IDLE:
				set_mission(w, AirWing.Mission.IDLE)
		return
	var focus := _focus_province(c)
	if focus == 0:
		return
	var enemy_port := _enemy_port_with_fleet(c, focus)
	for w in mine:
		if not in_range(w, focus):
			var nb := _nearest_base(c.tag, World.province(focus).center)
			if nb > 0 and nb != w.base:
				rebase(w, nb)
		if not in_range(w, focus):
			continue
		var m := AirWing.Mission.SUPERIORITY if w.type == "fighter" else AirWing.Mission.CAS
		var z := focus
		if w.type == "bomber" and enemy_port > 0 and in_range(w, enemy_port) and w.id % 2 == 0:
			m = AirWing.Mission.PORT_STRIKE
			z = enemy_port
		if w.mission != m or w.zone != z:
			set_mission(w, m, z)

## Ülkenin en sıcak cephesi: en çok muharebe olan bölge, yoksa düşmana en yakın sınır
func _focus_province(c: Country) -> int:
	var best := 0
	var bn := 0
	var count := {}
	for pid: int in Military.battles:
		var b: Dictionary = Military.battles[pid]
		var involved := false
		for d: Division in b["attackers"] + b["defenders"]:
			if d.owner == c.tag:
				involved = true
				break
		if not involved:
			continue
		# yakın muharebeleri 350 km'lik kümelere say
		var here := World.province(pid).center
		var n := 0
		for q: int in Military.battles:
			if distance_km(World.province(q).center, here) <= ZONE_KM:
				n += 1
		if n > bn:
			bn = n
			best = pid
	if best > 0:
		return best
	var cap := World.capital_position(c.tag)
	var bd := INF
	for d in Military.country_divisions(c.tag):
		for n in World.land_neighbors(d.province):
			if Diplomacy.are_enemies(World.controller_tag(n), c.tag):
				var dd := World.province(n).center.distance_squared_to(cap)
				if dd < bd:
					bd = dd
					best = n
	return best

func _enemy_port_with_fleet(c: Country, near: int) -> int:
	var here := World.province(near).center
	var best := 0
	var bd := INF
	for f in Navy.fleets:
		if f.in_port() and Diplomacy.are_enemies(f.owner, c.tag):
			var d := World.province(f.location).center.distance_squared_to(here)
			if d < bd:
				bd = d
				best = f.location
	return best

func _nearest_base(tag: String, pos: Vector2) -> int:
	var best := 0
	var bd := INF
	for sid in bases_of(tag):
		var d := base_pos(sid).distance_squared_to(pos)
		if d < bd:
			bd = d
			best = sid
	return best

# ------------------------------------------------------------------ kayıt
func to_save() -> Array:
	var out := []
	for w in wings:
		out.append({"id": w.id, "o": w.owner, "n": w.name, "t": w.type, "p": w.planes, "b": w.base,
			"m": int(w.mission), "z": w.zone, "a": w.auto})
	return out

func from_save(arr: Array, next_id: int) -> void:
	wings.clear()
	for wd: Dictionary in arr:
		var w := AirWing.new()
		w.id = int(wd["id"]); w.owner = wd["o"]; w.name = wd["n"]; w.type = wd["t"]; w.planes = int(wd["p"])
		w.base = int(wd["b"]); w.mission = int(wd["m"]) as AirWing.Mission; w.zone = int(wd["z"]); w.auto = bool(wd["a"])
		wings.append(w)
	_next_id = next_id
	_bonus_cache.clear()
	wings_changed.emit()
