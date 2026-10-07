extends Node
## Hava kuvvetleri: hava kanatları hava üslerine konuşlanır; görev bölgesinde (menzil içinde) hava üstünlüğü,
## yakın hava desteği, liman baskını ya da bombardıman yapar. Günlük hava muharebesi (it dalaşı, uçaksavar), bölgesel hava
## üstünlüğü kara muharebesine etki eder. Oyuncunun kanatları isterse yapay zekâya bırakılabilir.

signal wings_changed
signal air_fights_changed

const ZONE_KM := 350.0
## Yapay zekâ ülkesinin en çok hava kanadı: askerî fabrika sayısının üçte biri, 12 ile 40 arasında (kanatları besleyen
## sanayi kadar; tavandan sonra yeni uçaklar stokta kalır, kayıpları doldurur). Tarihî akıştan sonra (AI.follows_history
## bitince) geçerli: uzun oyunda kanat sayısı onlarca yılda sınırsız artıyordu.
const MIN_WINGS := 12
const MAX_WINGS := 40

static func wing_cap(c: Country) -> int:
	return clampi(Economy.count(c, "military_factory") / 3, MIN_WINGS, MAX_WINGS)
const WING_SIZE := 100
## air: hava saldırısı, def: hava savunması, ground: kara desteği, bomb: fabrikaya bombardıman, range: km
## bomb: taktik bombardıman uçağı işin asıl sahibi (1); yakın destek uçağı küçük yük taşır (0,3); avcı bomba taşımaz
const TYPES := {
	"fighter": {"eq": "fighter_equipment", "air": 3.0, "def": 1.2, "ground": 0.15, "bomb": 0.0, "range": 900.0},
	"cas": {"eq": "cas_equipment", "air": 0.6, "def": 0.8, "ground": 1.0, "bomb": 0.3, "range": 500.0},
	"bomber": {"eq": "tactical_bomber_equipment", "air": 0.8, "def": 1.4, "ground": 0.8, "bomb": 1.0, "range": 900.0},
}

## Bombardıman: BOMBING görevindeki kanat, görev bölgesinin eyaletindeki (düşman toprağı) fabrikaları vurur. Günlük
## hasar = uçak × bomba gücü × BOMB_DMG × hava üstünlüğü payı × (1 − 0,1 × uçaksavar seviyesi); eyalet hasarı en çok
## BOMB_MAX. Hedef ülkenin savaş desteği uçak × bomba gücü × BOMB_MORALE × üstünlük kadar düşer. Hasar her gün
## BOMB_REPAIR onarılır. Neden bu sayılar: karşı koymasız 100 uçaklık tam kanat günde %3 hasar verir, onarım %1 → bir
## ayda eyalet sanayisinin yarıdan fazlası durur; akın bitince iki ayda onarılır. Savaş desteği tam kanatla ayda ~%3
## düşer: halkı yıldırmak için birkaç kanat ve aylar gerekir.
const BOMB_DMG := 0.0003
const BOMB_MAX := 0.8
const BOMB_REPAIR := 0.01
const BOMB_MORALE := 0.00001

var wings: Array[AirWing] = []
var fights: Dictionary = {}            ## bölge merkezi pid -> {"pos": Vector2, "intensity": float, "tags": [..]}
var _next_id := 1
var _bonus_cache: Dictionary = {}
var _zone_wings: Dictionary = {}       ## görev bölgesi -> orada görevdeki kanatlar (bonus için; kanat/görev değişince kurulur)
var _covering: Dictionary = {}         ## kara bölgesi -> onu kaplayan görev bölgeleri
var _zones_ready := false
var _dirty := false

func _ready() -> void:
	GameClock.hour_late.connect(_staged_day)       # günlük iş günün kendi saatinde (GameClock.DAY_STAGE)

# ------------------------------------------------------------------ kurulum
func reset() -> void:
	wings.clear()
	fights.clear()
	_clear_bonus()
	_next_id = 1
	for st: StateRegion in World.states.values():
		st.damage = 0.0
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

## Oyuncu: stoktaki uçakları seçtiği hava üssüne kanat olarak konuşlandırır
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
	w.auto = not (World.in_game and c.tag == World.player_tag)   # oyuncunun kanadını yapay zekâ yönetmez
	var k := 1
	for o in wings:
		if o.owner == c.tag and o.type == type:
			k += 1
	w.name = UnitNames.name_of(c.tag, "wing_" + type, k)
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
	_zones_ready = false
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
	if World.in_game and c.tag == World.player_tag and not Game.observer:
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
		var count := 0
		for w in wings:
			if w.owner == c.tag:
				count += 1
			if n <= 0:
				continue
			if w.owner == c.tag and w.type == t and w.planes < WING_SIZE:
				var add := mini(n, WING_SIZE - w.planes)
				w.planes += add
				n -= add
		# kanat tavanı: fazla uçak stokta kalır, kayıpları doldurur (kanat sayısı onlarca yılda sınırsız artıyordu)
		var cap := wing_cap(c)
		if AI.follows_history():
			cap = 1 << 30                  # tarihî akış ayarlandığı gibi kalır; tavan uzun oyun için
		while n > 0:
			if count >= cap:
				c.stockpile[eq] = float(c.stockpile.get(eq, 0.0)) + n
				break
			count += 1
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
			w.name = UnitNames.name_of(c.tag, "wing_" + t, k)
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
	_zones_ready = false
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
		if m == AirWing.Mission.BOMBING and zone > 0 and bomb_target_error(w, zone) != "":
			return false
		w.zone = zone
	w.mission = m
	if m == AirWing.Mission.IDLE:
		w.zone = 0
	_dirty = true
	_clear_bonus()
	return true

func rebase(w: AirWing, sid: int) -> bool:
	if not sid in bases_of(w.owner):
		return false
	w.base = sid
	if w.zone > 0 and not in_range(w, w.zone):
		w.mission = AirWing.Mission.IDLE
		w.zone = 0
		_zones_ready = false
	_dirty = true
	return true

## Bombardıman hedefi uygun mu: "" ya da hata anahtarı (bomba taşımayan tür / düşman kara eyaleti değil)
func bomb_target_error(w: AirWing, pid: int) -> String:
	if float(TYPES[w.type]["bomb"]) <= 0.0:
		return "AIR_ERR_NO_BOMBS"
	var st := World.state_of_province(pid)
	if st == null or not World.province(pid).is_land() or not Diplomacy.are_enemies(st.owner, w.owner):
		return "AIR_ERR_BOMB_TARGET"
	return ""

## Oyuncunun seçtiği bölgeye görev (hava panelinde önce bölge, sonra görev): kanadın üssü menzildeyse orada kalır,
## değilse bölgeye en yakın, menzili yeten kendi hava üssüne geçer; hiçbiri yetmiyorsa hata anahtarı döner
func assign(w: AirWing, pid: int, m: AirWing.Mission) -> String:
	if m == AirWing.Mission.BOMBING:
		var err := bomb_target_error(w, pid)
		if err != "":
			return err
	var c: Country = World.countries.get(w.owner)
	if m == AirWing.Mission.RECON and c and c.sp < recon_cost():
		return "RECON_ERR_SP"
	if not in_range(w, pid):
		var best := base_for(w, pid)
		if best == 0:
			return "AIR_ERR_RANGE"
		w.base = best
	w.auto = false
	set_mission(w, m, pid)
	if m == AirWing.Mission.RECON and c:
		# keşif uçuşu: bedeli öder, recon_days gün sonra kanat boşa döner (keşfedilen yer kalıcı)
		c.sp -= recon_cost()
		w.recon_until = World.day_count + int(Military.recruit_def()["recon_days"])
		Military.sp_changed.emit()
	return ""

## Bir noktaya en yakın kendi hava üssü (0: yok)
func base_for_point(tag: String, at: Vector2) -> int:
	var best := 0
	var bd := INF
	for sid in bases_of(tag):
		var d := distance_km(base_pos(sid), at)
		if d < bd:
			bd = d
			best = sid
	return best

## Keşif uçuşunun SP bedeli ve süresi (data/common/recruit.json)
func recon_cost() -> float:
	return float(Military.recruit_def()["recon_sp"])

## Read-only target preview, using the same eligible wings and bases as assign.
## Union base ranges once, instead of searching every wing for every province.
func recon_targets(tag: String) -> Dictionary:
	var c: Country = World.countries.get(tag)
	var targets := {}
	if c == null or c.sp < recon_cost(): return targets
	var ranges := {}
	var bases := bases_of(tag)
	for wing: AirWing in wings_of(tag):
		if wing.planes <= 0 or (wing.on_mission() and wing.mission != AirWing.Mission.RECON): continue
		var reach := float(TYPES[wing.type]["range"])
		for base: int in bases:
			ranges[base] = maxf(float(ranges.get(base, 0.0)), reach)
		if wing.base > 0: ranges[wing.base] = maxf(float(ranges.get(wing.base, 0.0)), reach)
	for p: Province in World.provinces:
		if p == null: continue
		for base: int in ranges:
			if distance_km(base_pos(base), p.center) <= float(ranges[base]):
				targets[p.id] = 255
				break
	return targets

## Kanadın bu bölgeye uçabileceği, bölgeye en yakın kendi hava üssü (0: yok)
func base_for(w: AirWing, pid: int) -> int:
	var at := World.province(pid).center
	var rng := float(TYPES[w.type]["range"])
	var best := 0
	var bd := INF
	for sid in bases_of(w.owner):
		var d := distance_km(base_pos(sid), at)
		if d <= rng and d < bd:
			bd = d
			best = sid
	return best

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
	if m == AirWing.Mission.BOMBING:
		var err := bomb_target_error(w, pid)
		if err != "":
			return err
	w.auto = false
	set_mission(w, m, pid)
	return ""

# ------------------------------------------------------------------ kara muharebesine etki
## Bölgede tag için saldırı/savunma çarpanı eki: hava üstünlüğü payı + yakın hava desteği (günlük önbellek)
func bonus(pid: int, tag: String) -> float:
	var key := Vector2i(pid, tag.hash())      # metin biçimlemek her çağrıda pahalıydı (savaşta tümen başına sorulur)
	if _bonus_cache.has(key):
		return _bonus_cache[key]
	var own_f := 0.0
	var foe_f := 0.0
	var own_g := 0.0
	# yalnız bölgeyi kaplayan görev bölgelerindeki kanatlar (her soruda bütün kanatları ölçmek, önbellek silinince
	# cephedeki her bölge için saniyelerce mesafe hesabı ediyordu: savaşta ~10 ms'lik kare)
	for z: int in _zones_covering(pid):
		for w: AirWing in _zone_wings[z]:
			if not w.on_mission():
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

func _clear_bonus() -> void:
	_bonus_cache.clear()
	_zones_ready = false

## pid'i kaplayan (merkezi ZONE_KM içinde olan) görev bölgeleri; covers() ile aynı ölçü
func _zones_covering(pid: int) -> Array:
	if not _zones_ready:
		_zones_ready = true
		_zone_wings.clear()
		_covering.clear()
		for w in wings:
			if w.on_mission():
				if not _zone_wings.has(w.zone):
					_zone_wings[w.zone] = []
				(_zone_wings[w.zone] as Array).append(w)
	if _covering.has(pid):
		return _covering[pid]
	var out: Array = []
	var c := World.province(pid).center
	for z: int in _zone_wings:
		if distance_km(World.province(z).center, c) <= ZONE_KM:
			out.append(z)
	_covering[pid] = out
	return out

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
func _staged_day() -> void:
	if GameClock.hour == int(GameClock.DAY_STAGE["air"]):
		_on_day()

func _on_day() -> void:
	if wings.is_empty() and not World.in_game:
		return
	var t0 := Time.get_ticks_usec()
	_clear_bonus()
	for c: Country in World.countries.values():
		if c.exists():
			_absorb(c)
	_air_combat()
	_port_strikes()
	_bombing()
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
	# bölge toplamları: kanatlar görev bölgesine göre toplanır, yakın bölge çiftleri bir kez ölçülür (her kanadı her
	# kanatla karşılaştırmak kanatlar çoğaldıkça karesel büyüyordu). Sonuç aynı: kanat kendisi sayılmaz.
	var by_zone := {}                        # bölge -> {sahip: [hava gücü, kalkan (avcı savunması)]}
	for o in active:
		if not by_zone.has(o.zone):
			by_zone[o.zone] = {}
		var z: Dictionary = by_zone[o.zone]
		if not z.has(o.owner):
			z[o.owner] = [0.0, 0.0]
		var agg: Array = z[o.owner]
		agg[0] = float(agg[0]) + o.planes * float(TYPES[o.type]["air"]) * (1.0 if o.mission == AirWing.Mission.SUPERIORITY else 0.3)
		if o.type == "fighter":
			agg[1] = float(agg[1]) + o.planes * float(TYPES[o.type]["def"])
	var zones: Array = by_zone.keys()
	var near := {}                           # bölge -> {sahip: [hava gücü, kalkan]} (menzildeki bütün bölgeler)
	for za: int in zones:
		var ca := World.province(za).center
		var sum := {}
		for zb: int in zones:
			if za != zb and distance_km(World.province(zb).center, ca) > ZONE_KM * 1.6:
				continue
			for t: String in by_zone[zb]:
				if not sum.has(t):
					sum[t] = [0.0, 0.0]
				sum[t][0] = float(sum[t][0]) + float(by_zone[zb][t][0])
				sum[t][1] = float(sum[t][1]) + float(by_zone[zb][t][1])
		near[za] = sum
	for w in active:
		var wz := World.province(w.zone).center
		var enemy_air := 0.0
		var own_cover := 0.0
		var sum: Dictionary = near[w.zone]
		for t: String in sum:
			if Diplomacy.are_enemies(t, w.owner):
				enemy_air += float(sum[t][0])
			elif t == w.owner or Diplomacy.are_allies(t, w.owner):
				own_cover += float(sum[t][1])
		if w.type == "fighter":
			own_cover -= w.planes * float(TYPES[w.type]["def"])      # kendisi sayılmaz
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
			_zones_ready = false
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

## Keşif: RECON görevindeki kanatların (tag ya da müttefiklerinin) bölgeleri — görev merkezinden ZONE_KM içindeki
## bütün bölgeler. Savaş sisini açar (Military._ensure_fog).
func recon_provinces(tag: String) -> Array[int]:
	var out: Array[int] = []
	for w in wings:
		if w.mission != AirWing.Mission.RECON or not w.on_mission():
			continue
		if w.owner != tag and not Diplomacy.are_allies(w.owner, tag):
			continue
		var center := World.province(w.zone).center
		# gece menzil düşer (recruit.json night_recon_range; alacakaranlıkta geçişli)
		var reach := ZONE_KM * lerpf(1.0, float(Military.recruit_def().get("night_recon_range", 1.0)), GameClock.night_at(center))
		var seen := {w.zone: true}
		var frontier: Array[int] = [w.zone]
		while not frontier.is_empty():
			var cur: int = frontier.pop_back()
			out.append(cur)
			for q in World.province(cur).adjacent:
				if seen.has(q) or World.province(q) == null:
					continue
				seen[q] = true
				if distance_km(World.province(q).center, center) <= reach:
					frontier.append(q)
	return out

## Günlük bombardıman ve onarım (sabitlerin gerekçesi TYPES'ın altında)
var bombed_today: Dictionary = {}       ## eyalet id -> bugünkü hasar artışı (görünüm / rapor)
func _bombing() -> void:
	bombed_today.clear()
	for w in wings:
		if w.mission == AirWing.Mission.RECON and w.recon_until > 0 and World.day_count >= w.recon_until:
			w.recon_until = 0
			set_mission(w, AirWing.Mission.IDLE)       # keşif uçuşu bitti: kanat üssüne döner
	for st: StateRegion in World.states.values():
		if st.damage > 0.0:
			st.damage = maxf(st.damage - BOMB_REPAIR, 0.0)
	var morale := {}
	for w in wings:
		if w.mission != AirWing.Mission.BOMBING or not w.on_mission():
			continue
		var st := World.state_of_province(w.zone)
		if st == null or not Diplomacy.are_enemies(st.owner, w.owner):
			continue
		# üstünlük payı: düşman avcısı yoksa 1 (kanadın kendisi sayılır), eşitlikte 0,5, düşman hâkimse sıfıra iner
		var power := w.planes * float(TYPES[w.type]["bomb"]) * superiority(w.zone, w.owner)
		if power <= 0.0:
			continue
		var aa := clampf(1.0 - 0.1 * st.building_level("anti_air"), 0.2, 1.0)
		var add := minf(power * BOMB_DMG * aa, BOMB_MAX - st.damage)
		if add > 0.0:
			st.damage += add
			bombed_today[st.id] = float(bombed_today.get(st.id, 0.0)) + add
		morale[st.owner] = float(morale.get(st.owner, 0.0)) + power * BOMB_MORALE
	for tag: String in morale:
		var c: Country = World.countries.get(tag)
		if c:
			c.war_support = clampf(c.war_support - float(morale[tag]), 0.0, 1.0)
	if not bombed_today.is_empty():
		_dirty = true
		if World.day_count % 7 == 0:
			_report_bombing()

## Haftalık: oyuncunun bombalanan eyaletleri
func _report_bombing() -> void:
	for sid: int in bombed_today:
		var st: StateRegion = World.states[sid]
		if st.owner == World.player_tag:
			World.notify(tr("NOTE_BOMBED") % [st.display_name(), roundi(st.damage * 100.0)], "bad")

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
			"m": int(w.mission), "z": w.zone, "a": w.auto, "ru": w.recon_until})
	return out

func from_save(arr: Array, next_id: int) -> void:
	wings.clear()
	for wd: Dictionary in arr:
		var w := AirWing.new()
		w.id = int(wd["id"]); w.owner = wd["o"]; w.name = wd["n"]; w.type = wd["t"]; w.planes = int(wd["p"])
		w.base = int(wd["b"]); w.mission = int(wd["m"]) as AirWing.Mission; w.zone = int(wd["z"]); w.auto = bool(wd["a"])
		w.recon_until = int(wd.get("ru", 0))
		wings.append(w)
	_next_id = next_id
	_clear_bonus()
	wings_changed.emit()
