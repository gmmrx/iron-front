extends Node
## Ekonomi: bina tanımları, fabrika sayımları, inşaat kuyruğu (günlük tick).
## türün klasikleri modeli: her sivil fabrika günde 5 inşaat puanı üretir; bir projeye en fazla 15 fabrika çalışır;
## tüketim malları için sivil fabrikaların bir kısmı ayrılır.

signal construction_changed(tag: String)
signal building_completed(tag: String, state_id: int, building: String)
signal _unused_sig
signal production_changed(tag: String)
signal laws_changed(tag: String)
signal trade_changed

const BUILDINGS_PATH := "res://data/common/buildings.json"
const HISTORY_PATH := "res://data/history/states_1936.json"
const EQUIPMENT_PATH := "res://data/common/equipment.json"
const LAWS_PATH := "res://data/common/laws.json"

var defs: Dictionary = {}          ## bina -> tanım
var params: Dictionary = {}
var resource_names: Array = []
var equipment: Dictionary = {}     ## ekipman -> tanım
var prod: Dictionary = {}          ## üretim parametreleri
var law_groups: Dictionary = {}
var law_change_cost := 150.0

func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BUILDINGS_PATH))
	defs = data["buildings"]
	params = data["economy"]
	resource_names = data["resources"]
	var eq: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EQUIPMENT_PATH))
	equipment = eq["equipment"]
	prod = eq["production"]
	_fleets = eq.get("start_fleets", {})
	var lw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LAWS_PATH))
	law_groups = lw["groups"]
	law_change_cost = float(lw["change_cost"])
	_law_start = lw["start"]
	World.daily_update.connect(_on_day)
	building_completed.connect(func(_t: String, _s: int, _b: String) -> void: invalidate_counts())
	World.ownership_changed.connect(invalidate_counts)
	reset()

var _law_start: Dictionary = {}
var _fleets: Dictionary = {}

## Yeni oyun: 1936 binaları, yasalar, başlangıç üretimi (World.reset() sonrası çağrılır)
func reset() -> void:
	var lw := {"start": _law_start}
	load_history()
	for c: Country in World.countries.values():
		var start: Dictionary = lw["start"].get(c.tag, lw["start"]["_default"])
		for g: String in law_groups:
			c.laws[g] = start.get(g, lw["start"]["_default"][g])
		c.production_lines.clear()
		c.construction_queue.clear()
		_setup_start_production(c)
	_run_trade()

## World haritayı yükledikten sonra çağrılır: 1936 binaları ve kaynakları
func load_history() -> void:
	var hist: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(HISTORY_PATH))["states"]
	for key: String in hist:
		var st: StateRegion = World.states.get(int(key))
		if st == null:
			continue
		var h: Dictionary = hist[key]
		st.category = h["category"]
		st.building_slots = int(h["slots"])
		for b: String in h["buildings"]:
			st.buildings[b] = int(h["buildings"][b])
		for r: String in h["resources"]:
			st.resources[r] = int(h["resources"][r])
	for st: StateRegion in World.states.values():
		for pid in st.provinces:
			var p := World.province(pid)
			if p and p.coastal:
				st.coastal = true
				break

func is_shared_slot(b: String) -> bool:
	return defs.has(b) and defs[b].get("shared_slots", false)

func building_name(b: String) -> String:
	var n: Dictionary = defs[b]["name"]
	return n.get(TranslationServer.get_locale().substr(0, 2), n["en"])

# ------------------------------------------------------------------ sayımlar
var _count_cache := {}
var _count_day := -1

func count(c: Country, building: String) -> int:
	if _count_day != World.day_count:
		_count_cache.clear()
		_count_day = World.day_count
	var key := c.tag + building
	if _count_cache.has(key):
		return _count_cache[key]
	var n := 0
	for sid in c.states:
		n += World.states[sid].building_level(building)
	_count_cache[key] = n
	return n

func invalidate_counts() -> void:
	_count_cache.clear()

func resource_total(c: Country, res: String) -> int:
	if _count_day != World.day_count:
		_count_cache.clear()
		_count_day = World.day_count
	var key := c.tag + "res:" + res
	if _count_cache.has(key):
		return _count_cache[key]
	var n := 0
	for sid in c.states:
		n += int(World.states[sid].resources.get(res, 0))
	_count_cache[key] = n
	return n

## Tüketim malına giden sivil fabrika sayısı (toplam fabrikanın oranı, yukarı yuvarlanır)
func consumer_goods_factories(c: Country) -> int:
	var total := count(c, "civilian_factory") + count(c, "military_factory")
	return mini(int(round(total * maxf(law_value(c, "consumer_goods", 0.35) + c.mod("consumer_goods_mod"), 0.05))), count(c, "civilian_factory"))

func available_civilian(c: Country) -> int:
	return maxi(count(c, "civilian_factory") - consumer_goods_factories(c) - c.trade_factories_paid + c.trade_factories_earned, 0)

# ------------------------------------------------------------------ inşaat
## Bu binanın bu eyalete kuyruğa eklenip eklenemeyeceği; "" = uygun, aksi halde çeviri anahtarı
func can_build(c: Country, st: StateRegion, building: String) -> String:
	if st.owner != c.tag or st.controller != c.tag:
		return "BUILD_ERR_OWNER"
	var d: Dictionary = defs[building]
	if d.get("coastal", false) and not st.coastal:
		return "BUILD_ERR_COASTAL"
	var queued := 0
	for p in c.construction_queue:
		if p.state_id == st.id and p.building == building:
			queued += 1
	if st.building_level(building) + queued >= int(d["max"]):
		return "BUILD_ERR_MAX"
	if d.get("shared_slots", false):
		var queued_shared := 0
		for p in c.construction_queue:
			if p.state_id == st.id and is_shared_slot(p.building):
				queued_shared += 1
		if st.free_slots() - queued_shared <= 0:
			return "BUILD_ERR_SLOTS"
	return ""

func queue_building(c: Country, st: StateRegion, building: String) -> bool:
	if can_build(c, st, building) != "":
		return false
	var p := ConstructionProject.new()
	p.building = building
	p.state_id = st.id
	p.cost = float(defs[building]["cost"])
	c.construction_queue.append(p)
	_assign(c)
	construction_changed.emit(c.tag)
	return true

func remove_project(c: Country, index: int) -> void:
	if index >= 0 and index < c.construction_queue.size():
		c.construction_queue.remove_at(index)
		_assign(c)
		construction_changed.emit(c.tag)

func move_project(c: Country, index: int, delta: int) -> void:
	var j := index + delta
	if index < 0 or j < 0 or index >= c.construction_queue.size() or j >= c.construction_queue.size():
		return
	var tmp := c.construction_queue[index]
	c.construction_queue[index] = c.construction_queue[j]
	c.construction_queue[j] = tmp
	_assign(c)
	construction_changed.emit(c.tag)

## Kullanılabilir sivil fabrikaları kuyruk sırasına göre projelere dağıt (proje başına en fazla 15)
func _assign(c: Country) -> void:
	var free := available_civilian(c)
	var cap := int(params["max_factories_per_project"])
	for p in c.construction_queue:
		p.assigned_factories = mini(free, cap)
		free -= p.assigned_factories

func _on_day() -> void:
	var __t := Time.get_ticks_usec()
	_on_day_impl()
	GameClock.timed("economy", __t)

func _on_day_impl() -> void:
	if GameClock.day == 1 or (_trade_dirty and World.day_count % 7 == 0):
		_run_trade()
	for c: Country in World.countries.values():
		_produce(c)
		if c.construction_queue.is_empty():
			continue
		_assign(c)
		var done: Array[ConstructionProject] = []
		for p in c.construction_queue:
			var st: StateRegion = World.states[p.state_id]
			var infra_bonus := 1.0 + st.building_level("infrastructure") * float(params["infrastructure_speed_bonus"])
			var speed := maxf(1.0 + c.mod("construction_speed") + Politics.stability_output_penalty(c), 0.1)
			p.last_daily = p.assigned_factories * float(params["civ_factory_output"]) * infra_bonus * speed
			p.progress += p.last_daily
			if p.progress >= p.cost:
				done.append(p)
		for p in done:
			c.construction_queue.erase(p)
			var st: StateRegion = World.states[p.state_id]
			st.buildings[p.building] = st.building_level(p.building) + 1
			building_completed.emit(c.tag, p.state_id, p.building)
		if not done.is_empty():
			_assign(c)
		construction_changed.emit(c.tag)

# ------------------------------------------------------------------ yasalar
func law_def(group: String, law: String) -> Dictionary:
	return law_groups[group]["laws"][law]

func law_name(group: String, law: String) -> String:
	var n: Dictionary = law_def(group, law)["name"]
	return n.get(TranslationServer.get_locale().substr(0, 2), n["en"])

func group_name(group: String) -> String:
	var n: Dictionary = law_groups[group]["name"]
	return n.get(TranslationServer.get_locale().substr(0, 2), n["en"])

## Yürürlükteki yasalardan bir değer (ilk bulunan) — ör. "manpower", "consumer_goods"
func law_value(c: Country, key: String, fallback: float) -> float:
	for g: String in c.laws:
		var d := law_def(g, c.laws[g])
		if d.has(key):
			return float(d[key])
	return fallback

## Yürürlükteki yasaların toplam etkisi — ör. "factory_output"
func law_sum(c: Country, key: String) -> float:
	var total := 0.0
	for g: String in c.laws:
		total += float(law_def(g, c.laws[g]).get(key, 0.0))
	return total

func can_change_law(c: Country, group: String, law: String) -> bool:
	return c.laws.get(group) != law and c.political_power >= law_change_cost

func change_law(c: Country, group: String, law: String) -> bool:
	if not can_change_law(c, group, law):
		return false
	c.political_power -= law_change_cost
	c.laws[group] = law
	_assign(c)
	mark_trade_dirty()
	laws_changed.emit(c.tag)
	return true

# ------------------------------------------------------------------ üretim
func equipment_name(e: String) -> String:
	var n: Dictionary = equipment[e]["name"]
	return n.get(TranslationServer.get_locale().substr(0, 2), n["en"])

func is_naval(eq: String) -> bool:
	return equipment.get(eq, {}).get("yard", false)

func assigned_military(c: Country, naval := false) -> int:
	var n := 0
	for l in c.production_lines:
		if is_naval(l.equipment) == naval:
			n += l.factories
	return n

func free_military(c: Country, naval := false) -> int:
	return count(c, "dockyard" if naval else "military_factory") - assigned_military(c, naval)

## Üretilebilir mi (tip araştırılmış olmalı)
func can_produce(c: Country, eq: String) -> bool:
	return Research.is_unlocked(c, eq)

func add_line(c: Country, eq: String) -> ProductionLine:
	var l := ProductionLine.new()
	l.equipment = eq
	l.factories = 1 if free_military(c, is_naval(eq)) > 0 else 0
	l.efficiency = float(prod["efficiency_start"])
	c.production_lines.append(l)
	mark_trade_dirty()
	production_changed.emit(c.tag)
	return l

func remove_line(c: Country, index: int) -> void:
	if index >= 0 and index < c.production_lines.size():
		c.production_lines.remove_at(index)
		mark_trade_dirty()
		production_changed.emit(c.tag)

func set_line_factories(c: Country, index: int, n: int) -> void:
	var l: ProductionLine = c.production_lines[index]
	var cap := mini(int(prod["max_factories_per_line"]), l.factories + free_military(c, is_naval(l.equipment)))
	l.factories = clampi(n, 0, cap)
	mark_trade_dirty()
	production_changed.emit(c.tag)

## Kaynak üretimi: eyaletler + sentetik rafineri (kauçuk)
func resource_production(c: Country) -> Dictionary:
	var out := {}
	for r: String in resource_names:
		out[r] = resource_total(c, r)
	out["rubber"] = int(out.get("rubber", 0)) + count(c, "synthetic_refinery") * int(SYNTHETIC_RUBBER * (1.0 + c.mod("synthetic_output")))
	return out

## Üretimde kullanılabilir kaynak = üretim - ihracat + ithalat
func resource_available(c: Country) -> Dictionary:
	var out := resource_production(c)
	for e: Dictionary in c.exports:
		out[e["res"]] = float(out.get(e["res"], 0)) - float(e["amount"])
	var cf := convoy_factor(c)
	for i: Dictionary in c.imports:
		out[i["res"]] = float(out.get(i["res"], 0)) + float(i["amount"]) * cf
	return out

## İthalatın ne kadarını konvoylar taşıyabiliyor (2 kaynak başına 1 konvoy); denizaltılar konvoy batırınca düşer
func convoy_factor(c: Country) -> float:
	var need := 0.0
	for i: Dictionary in c.imports:
		need += float(i["amount"])
	need *= 0.5
	if need <= 0.0:
		return 1.0
	return clampf(float(c.stockpile.get("convoy", 0.0)) / need, 0.25, 1.0)

func resource_need(c: Country) -> Dictionary:
	var need := {}
	for l in c.production_lines:
		var n := line_resource_need(l)
		for r: String in n:
			need[r] = float(need.get(r, 0.0)) + n[r]
	return need

# ------------------------------------------------------------------ ticaret (otomatik, klasik kural)
const RESOURCES_PER_TRADE_FACTORY := 8.0
const SYNTHETIC_RUBBER := 3
var _trade_dirty := true

func mark_trade_dirty() -> void:
	_trade_dirty = true

## Her ay başı (ve hat/yasa değişince) yeniden hesaplanır: açığı olan ülkeler piyasadan alır.
## İhracatçının piyasaya açtığı pay ticaret yasasına bağlıdır; alıcı 8 kaynak başına 1 sivil fabrika öder.
func _run_trade() -> void:
	_trade_dirty = false
	var offered := {}   # tag -> {res: miktar}
	for c: Country in World.countries.values():
		c.imports = []
		c.exports = []
		c.trade_factories_paid = 0
		c.trade_factories_earned = 0
		var prod_ := resource_production(c)
		var share := law_value(c, "export", 0.5)
		var o := {}
		for r: String in prod_:
			o[r] = floorf(float(prod_[r]) * share)
		offered[c.tag] = o
	# büyük sanayiler önce alır (türün klasiklerinde de pazar gücü sanayiye bağlı)
	var buyers: Array = World.countries.values()
	buyers.sort_custom(func(a: Country, b: Country) -> bool: return count(a, "civilian_factory") > count(b, "civilian_factory"))
	for c: Country in buyers:
		var need := resource_need(c)
		var own := resource_production(c)
		var bought := 0.0
		for r: String in need:
			# kendi üretiminin piyasaya açılmayan kısmı önce kullanılır
			var home := float(own.get(r, 0)) - float(offered[c.tag].get(r, 0))
			var deficit := ceilf(float(need[r]) - maxf(home, 0.0))
			if deficit <= 0.0:
				continue
			# ihracatçılar: en çok arzı olan önce
			var sellers: Array = World.countries.values().filter(func(x: Country) -> bool: return x != c and float(offered[x.tag].get(r, 0)) > 0.0)
			sellers.sort_custom(func(a: Country, b: Country) -> bool: return offered[a.tag][r] > offered[b.tag][r])
			for s: Country in sellers:
				if deficit <= 0.0:
					break
				var amt := minf(deficit, float(offered[s.tag][r]))
				offered[s.tag][r] -= amt
				deficit -= amt
				bought += amt
				c.imports.append({"from": s.tag, "res": r, "amount": amt})
				s.exports.append({"to": c.tag, "res": r, "amount": amt})
		c.trade_factories_paid = int(ceil(bought / RESOURCES_PER_TRADE_FACTORY))
	for c: Country in World.countries.values():
		var sold := 0.0
		for e: Dictionary in c.exports:
			sold += float(e["amount"])
		c.trade_factories_earned = int(floor(sold / RESOURCES_PER_TRADE_FACTORY))
		_assign(c)
	trade_changed.emit()

## Hat başına günlük kaynak ihtiyacı (fabrika x ekipman ihtiyacı)
func line_resource_need(l: ProductionLine) -> Dictionary:
	var need := {}
	var per: Dictionary = equipment[l.equipment]["resources"]
	for r: String in per:
		need[r] = float(per[r]) * l.factories
	return need

func _produce(c: Country) -> void:
	var available := resource_available(c)
	c.resource_use = {}
	var output_mod := maxf(1.0 + c.mod("factory_output") + Politics.stability_output_penalty(c), 0.1)
	var cap := float(prod["efficiency_cap"]) + c.mod("production_efficiency_cap")
	for l in c.production_lines:
		if l.factories <= 0:
			l.last_output = 0.0
			continue
		# kaynak: sırayla tahsis; en kıt kaynak oranı üretimi sınırlar
		var need := line_resource_need(l)
		var frac := 1.0
		for r: String in need:
			if need[r] > 0.0:
				frac = minf(frac, float(available.get(r, 0)) / need[r])
		frac = clampf(frac, 0.0, 1.0)
		for r: String in need:
			var used: float = need[r] * frac
			available[r] = float(available.get(r, 0)) - used
			c.resource_use[r] = float(c.resource_use.get(r, 0.0)) + used
		l.resource_fraction = frac
		var floor_ := float(prod["resource_shortage_floor"])
		var per: float = float(prod["dockyard_output"]) if is_naval(l.equipment) else float(prod["mil_factory_output"])
		var ic: float = l.factories * per * l.efficiency * output_mod * (floor_ + (1.0 - floor_) * frac)
		var unit_cost := float(equipment[l.equipment]["cost"])
		l.progress_ic += ic
		var units := floorf(l.progress_ic / unit_cost)
		l.progress_ic -= units * unit_cost
		l.last_output = ic / unit_cost
		c.stockpile[l.equipment] = float(c.stockpile.get(l.equipment, 0.0)) + units
		# verimlilik tavana doğru büyür (tavana yaklaştıkça yavaşlar)
		l.efficiency = minf(cap, l.efficiency + float(prod["efficiency_gain_per_day"]) * (cap - l.efficiency) / cap)

## 1936 başlangıç hatları ve stok (askeri fabrikalar ekipmanlara dağıtılır)
func _setup_start_production(c: Country) -> void:
	var mil := count(c, "military_factory")
	var plan := {"infantry_equipment": 0.5, "artillery_equipment": 0.15, "support_equipment": 0.1}
	if mil >= 5:
		plan["fighter_equipment"] = 0.15
	if mil >= 8:
		plan["light_tank_equipment"] = 0.1
	var left := mil
	for eq: String in plan:
		var n := int(floor(mil * plan[eq]))
		if n <= 0:
			continue
		var l := ProductionLine.new()
		l.equipment = eq
		l.factories = mini(n, left)
		l.efficiency = 0.3
		left -= l.factories
		c.production_lines.append(l)
	if left > 0:
		if c.production_lines.is_empty():
			var l := ProductionLine.new()
			l.equipment = "infantry_equipment"
			l.efficiency = 0.3
			c.production_lines.append(l)
		c.production_lines[0].factories += left
	var k := c.population / 1_000_000.0
	c.stockpile = {"infantry_equipment": 1500.0 * k + 500.0 * mil, "support_equipment": 20.0 * k + 40.0,
		"artillery_equipment": 40.0 * k + 30.0 * mil, "motorized_equipment": 10.0 * k,
		"fighter_equipment": 25.0 * mil, "light_tank_equipment": 40.0 * mil if mil >= 8 else 0.0}
	var fleets: Dictionary = _fleets.get(c.tag, {})
	if fleets.is_empty() and count(c, "dockyard") > 0:
		fleets = _fleets["_default_coastal"]
	for e: String in fleets:
		c.stockpile[e] = float(fleets[e])
	var yards := count(c, "dockyard")
	if yards > 0:
		var nl := ProductionLine.new()
		nl.equipment = "destroyer" if yards < 6 else "cruiser"
		nl.factories = yards
		nl.efficiency = 0.3
		c.production_lines.append(nl)
