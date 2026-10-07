extends Node
## Araştırma: teknoloji ağacı, slotlar, yıl cezası, odak bonusları; tamamlanan teknolojiler
## Country.tech_mods'a eklenir ve ekipman kilitlerini açar.
## Araştırma bitmez: bir dalın bütün teknolojileri bitince dal iyileştirme seviyeleriyle sürer (rep_<dal>_<n>; maliyet
## her seviyede artar, kazanç azalır — formül ve gerekçesi data/common/technologies.json "repeatable"). Seviyelerin
## tanımı gerektikçe kurulur (ensure).

signal research_changed(tag: String)
## Semantic action events: accepted user/AI commands only; reset/save restoration is silent.
signal research_started(tag: String, tech: String)
signal research_cancelled(tag: String, tech: String)
signal tech_completed(tag: String, tech: String)

const PATH := "res://data/common/technologies.json"
const AHEAD_PENALTY := 1.5         ## her erken yıl için +%150 süre
const START_TECHS := ["infantry_weapons_1", "artillery_1", "industry_1", "radio"]

var techs: Dictionary = {}
var categories: Dictionary = {}
var repeatable: Dictionary = {}
var rep_first_year := 1943          ## ilk iyileştirme seviyesinin yılı (son tarihî teknolojiden bir yıl sonra)
const REP_PREFIX := "rep_"
const GOVERNMENT_SPIRIT := "research_government_transition_disruption"
const IDEOLOGIES := ["democratic", "fascism", "communism", "neutrality"]
var government_projects: Dictionary = {}

func _ready() -> void:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	techs = d["techs"]
	categories = d["categories"]
	repeatable = d.get("repeatable", {})
	government_projects = d.get("government_projects", {})
	if not government_projects.is_empty():
		Politics.spirits[GOVERNMENT_SPIRIT] = government_projects["temporary_spirit"]
	var last := 0
	for t: Dictionary in techs.values():
		last = maxi(last, int(t["year"]))
	rep_first_year = last + 1
	GameClock.hour_late.connect(_staged_day)       # günlük iş günün kendi saatinde (GameClock.DAY_STAGE)
	reset()

func reset() -> void:
	# önceki oyunun kurduğu iyileştirme seviyeleri silinir: her yeni oyun aynı tanımlarla başlar
	for id: String in techs.keys():
		if techs[id].get("repeat", false):
			techs.erase(id)
	for cat: String in categories:
		if (repeatable.get("effects", {}) as Dictionary).has(cat):
			ensure(repeat_id(cat, 1))
	for c: Country in World.countries.values():
		c.research_done.clear()
		c.research_current.clear()
		c.tech_mods.clear()
		c.spirits.erase(GOVERNMENT_SPIRIT)
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
	if pr.is_empty() or not categories.has(pr[0]) or int(pr[1]) < 1 or repeatable.is_empty() \
			or not (repeatable.get("effects", {}) as Dictionary).has(pr[0]):
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
	if not (repeatable.get("effects", {}) as Dictionary).has(cat):
		return ""
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
	if c == null or not ensure(id):
		return false
	if id in c.research_done and not is_government_project(id):
		return false
	for r: Dictionary in c.research_current:
		if r["tech"] == id:
			return false
	for req: String in techs[id]["req"]:
		if not req in c.research_done:
			return false
	return _government_reason(c, id) == "" if is_government_project(id) else true

func is_government_project(id: String) -> bool:
	return techs.has(id) and str(techs[id].get("kind", "")) == "government_project"

func _text(en: String, turkish: String) -> String:
	return Politics.loc({"en": en, "tr": turkish})

func _government_reason(c: Country, id: String) -> String:
	var target := str(techs[id].get("target_ideology", ""))
	if not target in IDEOLOGIES:
		return _text("Invalid government target.", "Geçersiz yönetim hedefi.")
	if c.ideology == target:
		return _text("This is already your current government.", "Mevcut yönetiminiz zaten bu ideolojide.")
	for r: Dictionary in c.research_current:
		if is_government_project(str(r.get("tech", ""))):
			return _text("Only one government transition can run at a time.", "Aynı anda yalnız bir yönetim geçişi yürütülebilir.")
	if not c.exists() or c.capitulated:
		return _text("An existing, non-capitulated country is required.", "Ülkenin mevcut ve teslim olmamış olması gerekir.")
	if bool(government_projects.get("requires_peace", true)) and Diplomacy.at_war(c.tag):
		return _text("Government transitions can only begin at peace.", "Yönetim geçişi yalnız barışta başlatılabilir.")
	var minimum := float(government_projects.get("minimum_stability", 0.35))
	if Politics.stability(c) < minimum:
		return _text("Effective stability must be at least %d%%.", "Etkin istikrar en az %d%% olmalıdır.") % roundi(minimum * 100.0)
	var cost := float(government_projects.get("political_power_cost", 100.0))
	if c.political_power < cost:
		return _text("Requires %d influence paid upfront.", "Peşin ödenecek %d nüfuz gerekir.") % roundi(cost)
	return ""

## Human-readable start rejection for all technology/project cards; empty means start() can accept it.
func can_start_reason(c: Country, id: String) -> String:
	if c == null or not ensure(id):
		return _text("Unknown research project.", "Bilinmeyen araştırma projesi.")
	if id in c.research_done and not is_government_project(id):
		return _text("Already researched.", "Zaten araştırıldı.")
	for r: Dictionary in c.research_current:
		if str(r.get("tech", "")) == id:
			return _text("This research is already running.", "Bu araştırma zaten sürüyor.")
	for req: String in techs[id].get("req", []):
		if not req in c.research_done:
			return _text("Prerequisite research: %s.", "Önce araştırılması gereken: %s.") % tech_name(req)
	if is_government_project(id):
		var reason := _government_reason(c, id)
		if reason != "": return reason
	if c.research_current.size() >= c.research_slots:
		return _text("No free research slot.", "Boş araştırma yuvası yok.")
	return ""

func _active_record(c: Country, id: String) -> Dictionary:
	for r: Dictionary in c.research_current:
		if str(r.get("tech", "")) == id: return r
	return {}

func _work_needed(c: Country, id: String, record: Dictionary = {}) -> float:
	if is_government_project(id):
		return float(record.get("project_duration", government_projects.get("duration_days", 180.0)))
	var t: Dictionary = techs[id]
	return float(t["cost"]) * (1.0 + AHEAD_PENALTY * maxi(int(t["year"]) - GameClock.year, 0))

func project_progress(c: Country, id: String) -> float:
	if c == null or not ensure(id): return 0.0
	var r := _active_record(c, id)
	if not r.is_empty():
		return clampf(float(r.get("progress", 0.0)) / maxf(_work_needed(c, id, r), 1.0), 0.0, 1.0)
	if is_government_project(id): return 1.0 if c.ideology == str(techs[id]["target_ideology"]) else 0.0
	return 1.0 if id in c.research_done else 0.0

func remaining_days(c: Country, id: String) -> float:
	if c == null or not ensure(id): return 0.0
	var r := _active_record(c, id)
	if r.is_empty():
		return 0.0 if project_progress(c, id) >= 1.0 else days_needed(c, id)
	var left := maxf(_work_needed(c, id, r) - float(r.get("progress", 0.0)), 0.0)
	return left if is_government_project(id) else left / maxf(speed(c) * (1.0 + float(r.get("bonus", 0.0))), 0.01)

func project_costs_text(c: Country, id: String) -> String:
	if not is_government_project(id): return ""
	var days := int(government_projects.get("duration_days", 180))
	var pp := roundi(float(government_projects.get("political_power_cost", 100.0)))
	var minimum := roundi(float(government_projects.get("minimum_stability", 0.35)) * 100.0)
	var mods: Dictionary = government_projects["temporary_spirit"]["mods"]
	return _text("%d calendar days; 1 research slot. %d influence paid upfront; no refund on cancellation.\nWhile running: stability %d points, home-front support %d points, influence income modifier %d%%.\nRequirements: peace, effective stability at least %d%%, a different government, no other active transition. Technology speed, year penalties, research bonuses and stored days do not accelerate this project.",
		"%d takvim günü; 1 araştırma yuvası. %d nüfuz peşin ödenir; iptalde iade edilmez.\nSürerken: istikrar %d puan, iç cephe desteği %d puan, nüfuz kazancı değiştiricisi %d%%.\nKoşullar: barış, en az %d%% etkin istikrar, farklı yönetim, başka etkin yönetim geçişi olmaması. Teknoloji hızı, yıl cezası, araştırma bonusları ve birikmiş günler bu projeyi hızlandırmaz.") \
		% [days, pp, roundi(float(mods["stability"]) * 100), roundi(float(mods["war_support"]) * 100), roundi(float(mods["political_power_gain"]) * 100), minimum]

func project_summary(c: Country, id: String) -> Dictionary:
	if c == null or not is_government_project(id): return {}
	var r := _active_record(c, id)
	var target := str(techs[id]["target_ideology"])
	return {"id": id, "name": tech_name(id), "description": Politics.loc(techs[id]["desc"]), "target_ideology": target,
		"duration_days": _work_needed(c, id, r), "remaining_days": remaining_days(c, id), "progress": project_progress(c, id),
		"political_power_cost": float(government_projects["political_power_cost"]), "refund_on_cancel": false,
		"temporary_mods": (government_projects["temporary_spirit"]["mods"] as Dictionary).duplicate(),
		"requires_peace": bool(government_projects["requires_peace"]), "minimum_stability": float(government_projects["minimum_stability"]),
		"active": not r.is_empty(), "current_government": c.ideology == target, "can_start": can_start_reason(c, id) == "",
		"reason": can_start_reason(c, id), "effect_text": project_costs_text(c, id)}

func _sync_project_spirit(c: Country) -> void:
	var active := false
	for r: Dictionary in c.research_current:
		if is_government_project(str(r.get("tech", ""))): active = true; break
	var present := GOVERNMENT_SPIRIT in c.spirits
	if active and not present: c.spirits.append(GOVERNMENT_SPIRIT)
	elif not active and present: c.spirits.erase(GOVERNMENT_SPIRIT)
	if active != present: Politics.politics_changed.emit(c.tag)

## Save migration: current records already contain paid PP/progress; never charge or restart them here.
func restore_projects(c: Country) -> void:
	var found := false
	for r: Dictionary in c.research_current.duplicate():
		var id := str(r.get("tech", ""))
		if not is_government_project(id): continue
		if found or str(techs[id]["target_ideology"]) == c.ideology:
			c.research_current.erase(r)
			continue
		found = true
		r["from_ideology"] = str(r.get("from_ideology", c.ideology))
		r["project_duration"] = float(r.get("project_duration", government_projects.get("duration_days", 180.0)))
		r["project_paid_pp"] = float(r.get("project_paid_pp", 0.0))
	_sync_project_spirit(c)

## Araştırma hızı; senaryoda senaryonun katı (research_speed: kısa oyunda birkaç dakikada bir yeni araştırma)
func speed(c: Country) -> float:
	var scen := float(Game.scenario.get("research_speed", 1.0))
	return maxf(1.0 + c.mod("research_speed"), 0.2) * scen

## Kalan gün tahmini
func days_needed(c: Country, id: String) -> float:
	if not ensure(id): return 0.0
	if is_government_project(id): return _work_needed(c, id, _active_record(c, id))
	var t: Dictionary = techs[id]
	var ahead := maxi(int(t["year"]) - GameClock.year, 0)
	var cost := float(t["cost"]) * (1.0 + AHEAD_PENALTY * ahead)
	for b: Dictionary in c.research_bonus:
		if b["category"] == t["cat"]:
			cost /= (1.0 + float(b["value"]))
			break
	return cost / speed(c)

func start(c: Country, id: String) -> bool:
	if can_start_reason(c, id) != "":
		return false
	if is_government_project(id):
		var cost := float(government_projects["political_power_cost"])
		c.political_power -= cost
		c.research_current.append({"tech": id, "progress": 0.0, "bonus": 0.0, "from_ideology": c.ideology,
			"project_duration": float(government_projects["duration_days"]), "project_paid_pp": cost})
		_sync_project_spirit(c)
		research_changed.emit(c.tag)
		research_started.emit(c.tag, id)
		return true
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
	research_started.emit(c.tag, id)
	return true

func cancel(c: Country, id: String) -> void:
	if c == null: return
	var removed := false
	for i in c.research_current.size():
		if c.research_current[i]["tech"] == id:
			c.research_current.remove_at(i)
			removed = true
			break
	if not removed: return
	_sync_project_spirit(c)
	research_changed.emit(c.tag)
	research_cancelled.emit(c.tag, id)

func _complete(c: Country, id: String, notify := true) -> void:
	if is_government_project(id):
		# Save reconstruction calls with notify=false: never repeat a political transition while loading.
		if notify and str(techs[id]["target_ideology"]) != c.ideology:
			if Politics.change_ideology(c, str(techs[id]["target_ideology"])):
				tech_completed.emit(c.tag, id)
		return # Governments are repeatable choices after changing away, not permanent technology unlocks.
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

func _staged_day() -> void:
	if GameClock.hour == int(GameClock.DAY_STAGE["research"]):
		_on_day()

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
			var id := str(r["tech"])
			if is_government_project(id) and c.ideology != str(r.get("from_ideology", c.ideology)):
				done.append(r)
				r["project_invalidated"] = true # Another legitimate regime change invalidates the old transition.
				continue
			var cost := _work_needed(c, id, r)
			r["progress"] = float(r["progress"]) + (1.0 if is_government_project(id) else speed(c) * (1.0 + float(r.get("bonus", 0.0))))
			if float(r["progress"]) >= cost:
				done.append(r)
		for r: Dictionary in done:
			c.research_current.erase(r)
		_sync_project_spirit(c)
		for r: Dictionary in done:
			if not bool(r.get("project_invalidated", false)):
				_complete(c, r["tech"])
		if not done.is_empty():
			research_changed.emit(c.tag)
