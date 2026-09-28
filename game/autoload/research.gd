extends Node
## Araştırma: teknoloji ağacı, slotlar, yıl cezası, odak bonusları; tamamlanan teknolojiler
## Country.tech_mods'a eklenir ve ekipman kilitlerini açar.
## Araştırma bitmez: bir dalın bütün teknolojileri bitince dal iyileştirme seviyeleriyle sürer (rep_<dal>_<n>; maliyet
## her seviyede artar, kazanç azalır — formül ve gerekçesi data/common/technologies.json "repeatable"). Seviyelerin
## tanımı gerektikçe kurulur (ensure).

signal research_changed(tag: String)
signal tech_completed(tag: String, tech: String)

const PATH := "res://data/common/technologies.json"
const AHEAD_PENALTY := 1.5         ## her erken yıl için +%150 süre
const START_TECHS := ["infantry_weapons_1", "artillery_1", "industry_1", "radio"]

var techs: Dictionary = {}
var categories: Dictionary = {}
var repeatable: Dictionary = {}
var rep_first_year := 1943          ## ilk iyileştirme seviyesinin yılı (son tarihî teknolojiden bir yıl sonra)
const REP_PREFIX := "rep_"

func _ready() -> void:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	techs = d["techs"]
	categories = d["categories"]
	repeatable = d.get("repeatable", {})
	var last := 0
	for t: Dictionary in techs.values():
		last = maxi(last, int(t["year"]))
	rep_first_year = last + 1
	World.daily_update.connect(_on_day)
	reset()

func reset() -> void:
	# önceki oyunun kurduğu iyileştirme seviyeleri silinir: her yeni oyun aynı tanımlarla başlar
	for id: String in techs.keys():
		if techs[id].get("repeat", false):
			techs.erase(id)
	for cat: String in categories:
		ensure(repeat_id(cat, 1))
	for c: Country in World.countries.values():
		c.research_done.clear()
		c.research_current.clear()
		c.tech_mods.clear()
		if c.is_major() or c.population > 15_000_000:
			for t in START_TECHS:
				_complete(c, t, false)

## Ekipmanı açan teknoloji ("" = serbest)
func unlocking_tech(equipment: String) -> String:
	for t: String in techs:
		if equipment in techs[t].get("unlock", []):
			return t
	return ""

## Başlangıçta elinde bulunan (ya da üretimde olan) tiplerin teknolojileri araştırılmış sayılır
func grant_start_equipment() -> void:
	for c: Country in World.countries.values():
		var have: Array[String] = []
		for e: String in c.stockpile:
			if float(c.stockpile[e]) >= 1.0:
				have.append(e)
		for l in c.production_lines:
			have.append(l.equipment)
		for e in have:
			var t := unlocking_tech(e)
			if t != "":
				_complete_with_reqs(c, t)

func _complete_with_reqs(c: Country, id: String) -> void:
	for r: String in techs[id].get("req", []):
		_complete_with_reqs(c, r)
	_complete(c, id, false)

func tech_name(id: String) -> String:
	var t: Dictionary = techs[id]
	if t.get("repeat", false):
		return Politics.loc(repeatable["name"]) % [category_name(t["cat"]), roman(int(t["level"]))]
	return Politics.loc(t["name"])

static func roman(n: int) -> String:
	var out := ""
	var vals := [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1]
	var syms := ["M", "CM", "D", "CD", "C", "XC", "L", "XL", "X", "IX", "V", "IV", "I"]
	for i in vals.size():
		while n >= vals[i]:
			out += syms[i]
			n -= vals[i]
	return out

# ------------------------------------------------------------------ bitmeyen araştırma
static func repeat_id(cat: String, n: int) -> String:
	return "%s%s_%d" % [REP_PREFIX, cat, n]

static func is_repeat(id: String) -> bool:
	return id.begins_with(REP_PREFIX)

## rep_<dal>_<n> -> [dal, n] (iyileştirme değilse boş)
static func parse_repeat(id: String) -> Array:
	if not is_repeat(id):
		return []
	var rest := id.substr(REP_PREFIX.length())
	var cut := rest.rfind("_")
	if cut <= 0 or not rest.substr(cut + 1).is_valid_int():
		return []
	return [rest.substr(0, cut), int(rest.substr(cut + 1))]

## İyileştirme seviyesinin tanımını kur (yoksa). 1. seviye dalın bütün tarihî teknolojilerini, sonrakiler bir öncekini
## ister. Tarihî teknoloji ya da kurulamayan kimlik için false.
func ensure(id: String) -> bool:
	if techs.has(id):
		return true
	var pr := parse_repeat(id)
	if pr.is_empty() or not categories.has(pr[0]) or int(pr[1]) < 1 or repeatable.is_empty():
		return false
	var cat: String = pr[0]
	var n: int = pr[1]
	var req: Array = []
	if n == 1:
		for t: String in techs:
			if not techs[t].get("repeat", false) and techs[t]["cat"] == cat:
				req.append(t)
	else:
		ensure(repeat_id(cat, n - 1))
		req = [repeat_id(cat, n - 1)]
	var eff := {}
	var base: Dictionary = (repeatable["effects"] as Dictionary).get(cat, {})
	var k := pow(float(repeatable["gain_decay"]), n - 1)
	for m: String in base:
		eff[m] = snappedf(float(base[m]) * k, 0.0001)
	techs[id] = {"cat": cat, "year": rep_first_year + n - 1, "req": req, "effects": eff, "repeat": true, "level": n,
		"cost": roundi(float(repeatable["cost"]) * pow(1.0 + float(repeatable["cost_growth"]), n - 1))}
	return true

## Dalın sıradaki (henüz bitmemiş) iyileştirme seviyesi
func next_repeat(c: Country, cat: String) -> String:
	var n := 1
	while repeat_id(cat, n) in c.research_done:
		n += 1
	var id := repeat_id(cat, n)
	ensure(id)
	return id

## Ülkenin dalda bitirdiği iyileştirme seviyesi sayısı
func repeat_level(c: Country, cat: String) -> int:
	var n := 0
	while repeat_id(cat, n + 1) in c.research_done:
		n += 1
	return n

func category_name(cat: String) -> String:
	return Politics.loc(categories[cat])

func is_unlocked(c: Country, equipment: String) -> bool:
	for t: String in techs:
		if equipment in techs[t].get("unlock", []):
			return t in c.research_done
	return true

func can_research(c: Country, id: String) -> bool:
	if id in c.research_done:
		return false
	for r: Dictionary in c.research_current:
		if r["tech"] == id:
			return false
	for req: String in techs[id]["req"]:
		if not req in c.research_done:
			return false
	return true

func speed(c: Country) -> float:
	return maxf(1.0 + c.mod("research_speed"), 0.2)

## Kalan gün tahmini
func days_needed(c: Country, id: String) -> float:
	var t: Dictionary = techs[id]
	var ahead := maxi(int(t["year"]) - GameClock.year, 0)
	var cost := float(t["cost"]) * (1.0 + AHEAD_PENALTY * ahead)
	for b: Dictionary in c.research_bonus:
		if b["category"] == t["cat"]:
			cost /= (1.0 + float(b["value"]))
			break
	return cost / speed(c)

func start(c: Country, id: String) -> bool:
	if not can_research(c, id) or c.research_current.size() >= c.research_slots:
		return false
	var t: Dictionary = techs[id]
	var bonus := 0.0
	for i in c.research_bonus.size():
		var b: Dictionary = c.research_bonus[i]
		if b["category"] == t["cat"]:
			bonus = float(b["value"])
			b["uses"] = int(b["uses"]) - 1
			if int(b["uses"]) <= 0:
				c.research_bonus.remove_at(i)
			break
	# biriken araştırma günleri yeni araştırmaya aktarılır (en çok 30 gün)
	var carry := minf(c.research_stored, 30.0)
	c.research_stored -= carry
	c.research_current.append({"tech": id, "progress": carry * speed(c), "bonus": bonus})
	research_changed.emit(c.tag)
	return true

func cancel(c: Country, id: String) -> void:
	for i in c.research_current.size():
		if c.research_current[i]["tech"] == id:
			c.research_current.remove_at(i)
			break
	research_changed.emit(c.tag)

func _complete(c: Country, id: String, notify := true) -> void:
	if id in c.research_done or not ensure(id):
		return
	c.research_done.append(id)
	if techs[id].get("repeat", false):
		ensure(repeat_id(techs[id]["cat"], int(techs[id]["level"]) + 1))     # dal sürer: sıradaki seviye
	var eff: Dictionary = techs[id].get("effects", {})
	for k: String in eff:
		c.tech_mods[k] = float(c.tech_mods.get(k, 0.0)) + float(eff[k])
	if notify:
		tech_completed.emit(c.tag, id)

func _on_day() -> void:
	var __t := Time.get_ticks_usec()
	_on_day_impl()
	GameClock.timed("research", __t)

func _on_day_impl() -> void:
	for c: Country in World.countries.values():
		if not c.exists():
			continue
		# boş yuva araştırma biriktirir (yuva başına en çok 30 gün; fazlası boşa gider)
		var idle := c.research_slots - c.research_current.size()
		if idle > 0:
			c.research_stored = minf(c.research_stored + idle, 30.0 * c.research_slots)
		if c.research_current.is_empty():
			continue
		var done := []
		for r: Dictionary in c.research_current:
			var t: Dictionary = techs[r["tech"]]
			var ahead := maxi(int(t["year"]) - GameClock.year, 0)
			var cost := float(t["cost"]) * (1.0 + AHEAD_PENALTY * ahead)
			r["progress"] = float(r["progress"]) + speed(c) * (1.0 + float(r.get("bonus", 0.0)))
			if float(r["progress"]) >= cost:
				done.append(r)
		for r: Dictionary in done:
			c.research_current.erase(r)
			_complete(c, r["tech"])
		if not done.is_empty():
			research_changed.emit(c.tag)
