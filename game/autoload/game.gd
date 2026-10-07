extends Node
## Oyun yaşam döngüsü: yeni oyun, senaryo, kaydet/yükle (JSON), oyun sonu kontrolü.
## Serbest oyunun bitiş tarihi yok: oyuncu dünyayı alınca (oyuncunun tarafı dışında ayakta ülke kalmayınca) kazanır, ülkesi
## yok olunca (son eyaletini kaybedince ya da ilhak edilince) kaybeder. Teslim olup elinde toprak kalan ülke oynamayı sürdürür.
## Senaryo (data/scenarios/scenarios.json): hazır bir başlangıç kaydı, taraflar ve anahtar şehirler. Süre yok: savaş iki
## taraftan biri teslim olana ya da yok olana kadar sürer; anahtar şehirler yapay zekânın öncelikli hedefidir.

signal game_over(victory: bool, reason: String)

const SAVE_DIR := "user://saves/"
const SCENARIOS_PATH := "res://data/scenarios/scenarios.json"

var loaded := false            ## sahne yeniden yüklendiğinde doğrudan oyuna gir
## Geliştirici izleyici modu (ana menü "Geliştirici: Savaş izle"): oyuncunun ülkesini de yapay zekâ yönetir, oyuncuya
## gelen olaylar pencere açmadan seçilir, zaman akar. Kayda yazılmaz; yeni oyunda kapanır.
var observer := false
var observe_tag := ""               ## izleyici kipinde izlenen savaşın saldıranı: cephe çizgisi onun tarafına göre çizilir

## Cephe çizgisinin ve cephe panelinin baktığı ülke: oyuncu; izleyici kipinde (geliştirici savaş izle) izlenen savaşın
## saldıranı (oradaki "oyuncu" savaşta olmayabilir)
func front_tag() -> String:
	return observe_tag if observer and observe_tag != "" else World.player_tag
## Dil değişince sahne yeniden kurulur: Ayarlar yeniden açılır, oyun içindeysek kamera ve duraklatma durumu korunur
var reopen_settings := false
var resume_view := Vector3.ZERO   ## x, z, uzaklık (0 = başkente odaklan)
var resume_was_paused := false
var over := false
var won := false               ## dünya alındı ve oyuncu "oynamaya devam et" dedi: zafer ekranı yeniden gelmez
var scenario: Dictionary = {}  ## süren senaryonun tanımı (boş: serbest oyun)
var tutorial := -1             ## öğreticinin sıradaki adımı (data/common/tutorial.json; -1: öğretici yok)
var scenario_end := 0          ## senaryonun bittiği gün (World.day_count)
var fresh_start := false       ## sahne yeniden kurulunca oyuncuya yeni oyun varsayılanları kurulsun (senaryo başlangıcı)
var _scenario_defs: Array = []

func _ready() -> void:
	Research.grant_start_equipment()
	Military.reset()
	Navy.reset()
	Air.reset()
	World.daily_update.connect(_check_end)
	World.daily_update.connect(_scenario_tick)
	World.country_removed.connect(func(tag: String) -> void:
		if World.in_game and tag == World.player_tag:
			_end(false, "GAMEOVER_DEFEAT"))

func new_game() -> void:
	observer = false
	observe_tag = ""
	GameClock.reset()
	World.reset()
	Politics.reset()
	Research.reset()
	Economy.reset()
	Research.grant_start_equipment()
	Diplomacy.reset()
	Military.reset()
	Navy.reset()
	Air.reset()
	AI.reset()
	loaded = false
	over = false
	won = false
	scenario = {}
	scenario_end = 0
	tutorial = -1

func _check_end() -> void:
	if not World.in_game or over:
		return
	var p := World.player()
	if p == null or not p.exists():
		_end(false, "GAMEOVER_DEFEAT")
	elif not won and world_conquered(World.player_tag):
		won = true
		_end(true, "GAMEOVER_WORLD")

## Dünya alındı mı: oyuncu ve müttefikleri dışında ayakta ülke kalmadı
func world_conquered(tag: String) -> bool:
	for c: Country in World.countries.values():
		if c.tag == tag or not c.exists():
			continue
		if not Diplomacy.are_allies(c.tag, tag):
			return false
	return true

func _end(victory: bool, reason: String) -> void:
	over = true
	GameClock.set_paused(true)
	game_over.emit(victory, reason)

# ------------------------------------------------------------------ senaryolar
func scenarios() -> Array:
	if _scenario_defs.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(SCENARIOS_PATH))
		_scenario_defs = (d as Dictionary).get("scenarios", []) if d is Dictionary else []
	return _scenario_defs

func scenario_def(id: String) -> Dictionary:
	for sc: Dictionary in scenarios():
		if str(sc["id"]) == id:
			return sc
	return {}

## Senaryoyu başlat: başlangıç kaydı yüklenir, oyuncu seçtiği taraf olur (yeni oyun varsayılanlarıyla). Çağıran sahneyi
## yeniden yüklemeli (load_game gibi).
func start_scenario(id: String, tag: String) -> bool:
	var sc := scenario_def(id)
	if sc.is_empty() or not load_file("res://data/scenarios/%s.json" % str(sc["start"])):
		return false
	scenario = sc
	scenario_end = 0                       # süre yok (eski kayıtlarla uyum için alan duruyor)
	World.player_tag = tag
	fresh_start = true
	return true

## Senaryonun saldıran tarafı (sides[0])
func scenario_attacker() -> String:
	return str((scenario["sides"] as Array)[0]["tag"]) if not scenario.is_empty() else ""

## Anahtar şehir puanları: {"att": saldıranın tuttuğu, "total": toplam, "need": kazanmak için gereken, "days": kalan gün}
func scenario_score() -> Dictionary:
	if scenario.is_empty():
		return {}
	var att := scenario_attacker()
	var held := 0
	var total := 0
	for cid in scenario["key_cities"]:
		var city := World.city_by_id(int(cid))
		if city == null:
			continue
		total += city.victory_points
		var ctl := World.controller_tag(city.province_id)
		if ctl == att or (Diplomacy.are_allies(ctl, att) and ctl != ""):
			held += city.victory_points
	return {"att": held, "total": total, "need": ceili(total * float(scenario.get("win_share", 0.5))),
		"days": maxi(scenario_end - World.day_count, 0)}

## Bu şehir senaryonun anahtar şehri mi (kart ve harita için)
func is_key_city(city_id: int) -> bool:
	return not scenario.is_empty() and float(city_id) in (scenario["key_cities"] as Array)

## Günlük: iki taraf arasındaki savaş bitince (teslim, barış, bir tarafın yok olması) senaryo biter: yok olan taraf
## kaybeder; barışta anahtar şehirlerin daha çoğunu tutan taraf kazanmış sayılır
func _scenario_tick() -> void:
	if scenario.is_empty() or not World.in_game or over:
		return
	var att := scenario_attacker()
	var dfn := str((scenario["sides"] as Array)[1]["tag"])
	var ac: Country = World.countries.get(att)
	var dc: Country = World.countries.get(dfn)
	var gone_att := ac == null or not ac.exists()
	var gone_def := dc == null or not dc.exists()
	var war_over := gone_att or gone_def or not Diplomacy.are_enemies(att, dfn)
	if not war_over:
		return
	var sc := scenario_score()
	var att_wins := int(sc["att"]) >= int(sc["need"])
	if gone_def:
		att_wins = true
	elif gone_att:
		att_wins = false
	var me := World.player_tag
	var mine := me == att or Diplomacy.are_allies(me, att)
	_end(att_wins == mine, "GAMEOVER_SCENARIO_WIN" if att_wins == mine else "GAMEOVER_SCENARIO_LOSS")

## Skor: zafer puanı toplamı (şehirlerin mevcut sahibine göre)
func score(tag: String) -> int:
	var c: Country = World.countries.get(tag)
	if c == null:
		return 0
	var s := 0
	for sid in c.states:
		s += World.states[sid].victory_points()
	return s

# ------------------------------------------------------------------ kaydet
func save_game(slot: String) -> bool:
	GameClock.flush_hour()               # yarım kalan saatin ikinci yarısı (AI, günlük iş) kayıttan önce işlenir
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var data := {
		"version": 1, "player": World.player_tag,
		"date": [GameClock.year, GameClock.month, GameClock.day, GameClock.hour, GameClock.utc_offset],
		"day_count": World.day_count, "tension": World.world_tension, "won": won, "world_log": World.world_log,
		"scenario": {"id": str(scenario.get("id", "")), "end": scenario_end} if not scenario.is_empty() else {},
		"tutorial": tutorial,
		"explored": Military.explored_b64(),
		"controller": Array(World.controller),
		"states": {}, "countries": {}, "divisions": [], "wars": Diplomacy.wars, "war_id": Diplomacy._next_id, "waiting_to_join": Diplomacy.waiting_to_join,
		"factions": Politics.factions, "fired_events": Politics.fired_events, "pending_events": Politics.pending_events, "div_id": Military._next_id, "start_vp": Diplomacy._start_vp,
		"fleets": Navy.to_save(), "fleet_id": Navy._next_id, "wings": Air.to_save(), "wing_id": Air._next_id,
	}
	for st: StateRegion in World.states.values():
		data["states"][str(st.id)] = {"owner": st.owner, "buildings": st.buildings, "resources": st.resources}
		if st.damage > 0.0:
			data["states"][str(st.id)]["damage"] = st.damage
	for c: Country in World.countries.values():
		var lines := []
		for l in c.production_lines:
			lines.append({"eq": l.equipment, "f": l.factories, "eff": l.efficiency, "ic": l.progress_ic})
		var queue := []
		for q in c.construction_queue:
			queue.append({"b": q.building, "s": q.state_id, "p": q.progress, "c": q.cost})
		data["countries"][c.tag] = {
			"pp": c.political_power, "stability": c.stability, "war_support": c.war_support, "ideology": c.ideology,
			"capital": c.capital_state, "laws": c.laws, "spirits": Array(c.spirits), "advisors": Array(c.advisors),
			"focus_done": Array(c.focus_done), "focus_current": c.focus_current, "focus_progress": c.focus_progress,
			"leader": c.leader, "next_election": c.next_election, "election_months": c.election_months,
			"cp": c.command_power, "axp": c.army_xp, "nxp": c.navy_xp, "airxp": c.air_xp,
			"research_slots": c.research_slots, "fuel": c.fuel, "fuel_cap": c.fuel_cap, "rstore": c.research_stored, "research_current": c.research_current, "research_done": Array(c.research_done),
			"research_bonus": c.research_bonus, "decisions": c.decisions_active, "manpower_used": c.manpower_used, "sp": c.sp,
			"templates": c.templates, "faction": c.faction, "war_goals": c.war_goals, "justify": c.justify_progress,
			"guarantees": Array(c.guarantees), "access": Array(c.access), "capitulated": c.capitulated, "truce": c.truce_until,
			"auto_trade": c.auto_trade, "trade_orders": c.trade_orders,
			"popularity": c.popularity, "stockpile": c.stockpile, "lines": lines, "queue": queue,
		}
	for d in Military.divisions:
		data["divisions"].append({"id": d.id, "o": d.owner, "t": d.template, "n": d.name, "p": d.province,
			"path": Array(d.path), "pr": d.progress, "s": d.strength, "org": d.org, "a": d.attacking, "tr": d.training, "xp": d.xp, "pl": d.planning, "ar": d.army, "h": d.hold, "mn": d.manual, "ih": d.idle_hours, "sp": d.supplied, "mu": d.motivated_until})
	data["armies"] = []
	for a in Military.armies:
		data["armies"].append({"id": a.id, "o": a.owner, "n": a.name, "e": a.enemy, "m": int(a.mode), "c": a.color.to_html(),
			"cm": a.commander, "g": a.group})
	data["army_id"] = Military._next_army
	data["commanders"] = []
	for cm in Military.commanders:
		data["commanders"].append({"id": cm.id, "o": cm.owner, "n": cm.name, "r": int(cm.rank), "s": cm.skill, "x": cm.xp})
	data["commander_id"] = Military._next_commander
	data["groups"] = []
	for g in Military.groups:
		data["groups"].append({"id": g.id, "o": g.owner, "n": g.name, "cm": g.commander})
	data["group_id"] = Military._next_group
	var f := FileAccess.open(SAVE_DIR + slot + ".json", FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	World.notify(tr("NOTE_SAVED") % slot, "good")
	return true

func list_saves() -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".json"):
			out.append(f.trim_suffix(".json"))
	out.sort_custom(func(a: String, b: String) -> bool:
		return FileAccess.get_modified_time(SAVE_DIR + a + ".json") > FileAccess.get_modified_time(SAVE_DIR + b + ".json"))
	return out

## Yükle: dünyayı sıfırla, kaydı uygula. Çağıran sahneyi yeniden yüklemeli.
## (Eski kayıtlardaki tümen "spots" alanı — bölge içi duruş noktası — artık yok sayılır: hareket bölgeden bölgeye.)

func load_game(slot: String) -> bool:
	return load_file(SAVE_DIR + slot + ".json")

## Kayıt dosyasını yükle (oyuncu kaydı ya da senaryonun başlangıç kaydı)
func load_file(path: String) -> bool:
	var txt := FileAccess.get_file_as_string(path)
	if txt == "":
		return false
	var data: Dictionary = JSON.parse_string(txt)
	new_game()
	tutorial = int(data.get("tutorial", -1))
	var scd: Dictionary = data.get("scenario", {})
	if not scd.is_empty():
		scenario = scenario_def(str(scd["id"]))
		scenario_end = int(scd["end"])
	var dt: Array = data["date"]
	GameClock.year = int(dt[0]); GameClock.month = int(dt[1]); GameClock.day = int(dt[2]); GameClock.hour = int(dt[3])
	GameClock.utc_offset = int(dt[4]) if dt.size() > 4 else 0
	World.day_count = int(data["day_count"])
	World.world_tension = float(data["tension"])
	won = bool(data.get("won", false))
	# eyaletler: önce sahiplik
	for key: String in data["states"]:
		var sd: Dictionary = data["states"][key]
		var st: StateRegion = World.states.get(int(key))
		if st == null:
			continue
		if st.owner != sd["owner"]:
			World.transfer_state(st.id, sd["owner"])
		st.buildings = sd["buildings"]
		for b: String in st.buildings.keys():
			if not Economy.defs.has(b):
				st.buildings.erase(b)        # kaldırılan yapı (tersane, sentetik rafineri) eski kayıtta kalmasın
		st.resources = sd["resources"]
		st.damage = float(sd.get("damage", 0.0))
	var ctl: Array = data["controller"]
	for i in mini(ctl.size(), World.controller.size()):
		World.controller[i] = int(ctl[i])
	World.control_version += 1
	for tag: String in data["countries"]:
		var c: Country = World.countries.get(tag)
		if c == null:
			continue
		var cd: Dictionary = data["countries"][tag]
		c.political_power = float(cd["pp"]); c.stability = float(cd["stability"]); c.war_support = float(cd["war_support"])
		c.ideology = cd["ideology"]; c.capital_state = int(cd["capital"]); c.laws = cd["laws"]
		Economy.sanitize_laws(c)
		# eski kayıtlardaki artık olmayan ulusal durum / danışman kimlikleri atlanır
		c.spirits.clear()
		for sp: String in cd["spirits"]:
			if Politics.spirits.has(sp) or Politics.decisions.has(sp):
				c.spirits.append(sp)
		c.advisors.clear()
		for ad: String in cd["advisors"]:
			if Politics.advisor_defs.has(ad):
				c.advisors.append(ad)
		c.focus_done.assign(cd.get("focus_done", [])) # Legacy history remains round-trippable, never a live feature.
		c.focus_current = str(cd.get("focus_current", "")); c.focus_progress = float(cd.get("focus_progress", 0.0))
		Politics.sanitize_focus(c)
		c.leader = str(cd.get("leader", c.leader)); c.next_election = int(cd.get("next_election", c.next_election))
		c.election_months = int(cd.get("election_months", c.election_months))
		c.auto_trade = bool(cd.get("auto_trade", true)); c.trade_orders = cd.get("trade_orders", [])
		c.command_power = float(cd.get("cp", 0.0)); c.army_xp = float(cd.get("axp", 0.0)); c.navy_xp = float(cd.get("nxp", 0.0)); c.air_xp = float(cd.get("airxp", 0.0))
		c.research_slots = int(cd["research_slots"]); c.fuel = float(cd.get("fuel", -1.0)); c.fuel_cap = float(cd.get("fuel_cap", 0.0)); c.research_stored = float(cd.get("rstore", 0.0)); c.research_current = cd["research_current"]
		c.research_done.clear()
		c.tech_mods.clear()
		for t: String in cd["research_done"]:
			Research._complete(c, t, false)
		for r: Dictionary in c.research_current:
			Research.ensure(String(r["tech"]))          # sürmekte olan iyileştirme seviyesinin tanımı
		c.research_bonus = cd["research_bonus"]; c.decisions_active = cd["decisions"]
		Research.restore_projects(c) # Reconstruct project metadata/spirit only; never charge PP during load.
		c.manpower_used = int(cd["manpower_used"]); c.templates = cd["templates"]; c.faction = cd["faction"]
		c.sp = float(cd.get("sp", Military.recruit_def()["start_sp"]))
		c.war_goals = cd["war_goals"]; c.justify_progress = cd["justify"]
		c.guarantees.assign(cd["guarantees"]); c.access.assign(cd["access"]); c.capitulated = cd["capitulated"]; c.truce_until = int(cd.get("truce", 0))
		c.popularity = cd["popularity"]; c.stockpile = cd["stockpile"]
		c.production_lines.clear()
		for l: Dictionary in cd["lines"]:
			var pl := ProductionLine.new()
			pl.equipment = l["eq"]; pl.factories = int(l["f"]); pl.efficiency = float(l["eff"]); pl.progress_ic = float(l["ic"])
			c.production_lines.append(pl)
		c.construction_queue.clear()
		for q: Dictionary in cd["queue"]:
			var cp := ConstructionProject.new()
			cp.building = q["b"]; cp.state_id = int(q["s"]); cp.progress = float(q["p"]); cp.cost = float(q["c"])
			if Economy.defs.has(cp.building):
				c.construction_queue.append(cp)
	Diplomacy.wars = data["wars"]
	Diplomacy.waiting_to_join = data.get("waiting_to_join", {})
	Diplomacy._next_id = int(data["war_id"])
	Diplomacy._start_vp = data.get("start_vp", {})
	Politics.factions = data["factions"]
	Politics.fired_events = data.get("fired_events", [])
	Politics.pending_events = data.get("pending_events", [])      # oyuncunun cevaplamadığı olaylar
	Military.divisions.clear()
	Military._stats_cache.clear()
	for dd: Dictionary in data["divisions"]:
		var d := Division.new()
		d.id = int(dd["id"]); d.owner = dd["o"]; d.template = int(dd["t"]); d.name = dd["n"]; d.province = int(dd["p"])
		d.path = PackedInt32Array(dd["path"]); d.progress = float(dd["pr"]); d.strength = float(dd["s"])
		d.org = float(dd["org"]); d.attacking = int(dd["a"]); d.training = int(dd["tr"])
		d.xp = float(dd.get("xp", 0.15)); d.planning = float(dd.get("pl", 0.0)); d.army = int(dd.get("ar", 0)); d.hold = bool(dd.get("h", false)); d.manual = bool(dd.get("mn", false))
		d.idle_hours = int(dd.get("ih", 0)); d.supplied = bool(dd.get("sp", true)); d.motivated_until = int(dd.get("mu", 0))
		Military.divisions.append(d)
	Military._next_id = int(data["div_id"])
	if data.has("wings"):
		Air.from_save(data["wings"], int(data.get("wing_id", 1)))
	Military.armies.clear()
	Military._army_map.clear()
	for ad: Dictionary in data.get("armies", []):
		var a := Army.new()
		a.id = int(ad["id"]); a.owner = ad["o"]; a.name = ad["n"]; a.enemy = ad["e"]
		a.mode = int(ad["m"]) as Army.Mode; a.color = Color(ad["c"])
		a.commander = int(ad.get("cm", 0)); a.group = int(ad.get("g", 0))
		Military.armies.append(a)
	Military._next_army = int(data.get("army_id", Military.armies.size() + 1))
	if data.has("commanders"):
		Military.commanders.clear()
		for cd: Dictionary in data["commanders"]:
			var cm := Commander.new()
			cm.id = int(cd["id"]); cm.owner = cd["o"]; cm.name = cd["n"]; cm.rank = int(cd["r"]) as Commander.Rank
			cm.skill = int(cd["s"]); cm.xp = float(cd["x"])
			Military.commanders.append(cm)
		Military._next_commander = int(data.get("commander_id", Military.commanders.size() + 1))
	else:
		Military.init_commanders()       # komutanlardan önceki kayıt: kadro baştan kurulur
	Military.groups.clear()
	for gd: Dictionary in data.get("groups", []):
		var g := ArmyGroup.new()
		g.id = int(gd["id"]); g.owner = gd["o"]; g.name = gd["n"]; g.commander = int(gd["cm"])
		Military.groups.append(g)
	Military._next_group = int(data.get("group_id", Military.groups.size() + 1))
	Military._bonus_cache.clear()
	if data.has("fleets"):
		Navy.from_save(data["fleets"], int(data.get("fleet_id", 1)))
	Military._rebuild_index()
	World.flush_ownership()
	World.player_tag = data["player"]
	Military.set_explored(str(data.get("explored", "")))     # keşif kalıcı: kayıttaki keşfedilmiş bölgeler
	# kayıttan türeyen durum hemen yeniden hesaplanır (yoksa bir sonraki ay başına kadar 1936 ticareti kalır)
	Economy._run_trade()
	Military._compute_supply()
	# dünya olayları en sonda: yükleme sırasındaki eyalet aktarımlarının yazdığı kayıtlar sayılmaz
	World.world_log = data.get("world_log", [])
	loaded = true
	return true
