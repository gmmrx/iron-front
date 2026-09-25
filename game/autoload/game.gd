extends Node
## Oyun yaşam döngüsü: yeni oyun, kaydet/yükle (JSON), oyun sonu kontrolü.

signal game_over(victory: bool, reason: String)

const SAVE_DIR := "user://saves/"
const END_DATE := 19480101

var loaded := false            ## sahne yeniden yüklendiğinde doğrudan oyuna gir
var over := false

func _ready() -> void:
	Research.grant_start_equipment()
	Military.reset()
	Navy.reset()
	Air.reset()
	World.daily_update.connect(_check_end)
	World.country_removed.connect(func(tag: String) -> void:
		if World.in_game and tag == World.player_tag:
			_end(false, "GAMEOVER_DEFEAT"))

func new_game() -> void:
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

func _check_end() -> void:
	if not World.in_game or over:
		return
	var p := World.player()
	if p and p.capitulated:
		_end(false, "GAMEOVER_CAPITULATED")
	elif World.date_value() >= END_DATE:
		_end(true, "GAMEOVER_TIME")

func _end(victory: bool, reason: String) -> void:
	over = true
	GameClock.set_paused(true)
	game_over.emit(victory, reason)

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
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var data := {
		"version": 1, "player": World.player_tag,
		"date": [GameClock.year, GameClock.month, GameClock.day, GameClock.hour],
		"day_count": World.day_count, "tension": World.world_tension,
		"controller": Array(World.controller),
		"states": {}, "countries": {}, "divisions": [], "wars": Diplomacy.wars, "war_id": Diplomacy._next_id, "waiting_to_join": Diplomacy.waiting_to_join,
		"factions": Politics.factions, "fired_events": Politics.fired_events, "div_id": Military._next_id, "start_vp": Diplomacy._start_vp,
		"fleets": Navy.to_save(), "fleet_id": Navy._next_id, "wings": Air.to_save(), "wing_id": Air._next_id,
	}
	for st: StateRegion in World.states.values():
		data["states"][str(st.id)] = {"owner": st.owner, "buildings": st.buildings, "resources": st.resources}
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
			"leader": c.leader, "next_election": c.next_election, "cp": c.command_power, "axp": c.army_xp, "nxp": c.navy_xp, "airxp": c.air_xp,
			"research_slots": c.research_slots, "fuel": c.fuel, "rstore": c.research_stored, "research_current": c.research_current, "research_done": Array(c.research_done),
			"research_bonus": c.research_bonus, "decisions": c.decisions_active, "manpower_used": c.manpower_used,
			"templates": c.templates, "faction": c.faction, "war_goals": c.war_goals, "justify": c.justify_progress,
			"guarantees": Array(c.guarantees), "access": Array(c.access), "capitulated": c.capitulated,
			"auto_trade": c.auto_trade, "trade_orders": c.trade_orders,
			"popularity": c.popularity, "stockpile": c.stockpile, "lines": lines, "queue": queue,
		}
	for d in Military.divisions:
		data["divisions"].append({"id": d.id, "o": d.owner, "t": d.template, "n": d.name, "p": d.province,
			"path": Array(d.path), "pr": d.progress, "s": d.strength, "org": d.org, "a": d.attacking, "tr": d.training, "xp": d.xp, "pl": d.planning, "ar": d.army, "h": d.hold})
	data["armies"] = []
	for a in Military.armies:
		data["armies"].append({"id": a.id, "o": a.owner, "n": a.name, "e": a.enemy, "m": int(a.mode), "c": a.color.to_html()})
	data["army_id"] = Military._next_army
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
func load_game(slot: String) -> bool:
	var txt := FileAccess.get_file_as_string(SAVE_DIR + slot + ".json")
	if txt == "":
		return false
	var data: Dictionary = JSON.parse_string(txt)
	new_game()
	var dt: Array = data["date"]
	GameClock.year = int(dt[0]); GameClock.month = int(dt[1]); GameClock.day = int(dt[2]); GameClock.hour = int(dt[3])
	World.day_count = int(data["day_count"])
	World.world_tension = float(data["tension"])
	# eyaletler: önce sahiplik
	for key: String in data["states"]:
		var sd: Dictionary = data["states"][key]
		var st: StateRegion = World.states.get(int(key))
		if st == null:
			continue
		if st.owner != sd["owner"]:
			World.transfer_state(st.id, sd["owner"])
		st.buildings = sd["buildings"]
		st.resources = sd["resources"]
	var ctl: Array = data["controller"]
	for i in mini(ctl.size(), World.controller.size()):
		World.controller[i] = int(ctl[i])
	for tag: String in data["countries"]:
		var c: Country = World.countries.get(tag)
		if c == null:
			continue
		var cd: Dictionary = data["countries"][tag]
		c.political_power = float(cd["pp"]); c.stability = float(cd["stability"]); c.war_support = float(cd["war_support"])
		c.ideology = cd["ideology"]; c.capital_state = int(cd["capital"]); c.laws = cd["laws"]
		c.spirits.assign(cd["spirits"]); c.advisors.assign(cd["advisors"]); c.focus_done.assign(cd["focus_done"])
		c.focus_current = cd["focus_current"]; c.focus_progress = float(cd["focus_progress"])
		c.leader = str(cd.get("leader", c.leader)); c.next_election = int(cd.get("next_election", c.next_election))
		c.auto_trade = bool(cd.get("auto_trade", true)); c.trade_orders = cd.get("trade_orders", [])
		c.command_power = float(cd.get("cp", 0.0)); c.army_xp = float(cd.get("axp", 0.0)); c.navy_xp = float(cd.get("nxp", 0.0)); c.air_xp = float(cd.get("airxp", 0.0))
		c.research_slots = int(cd["research_slots"]); c.fuel = float(cd.get("fuel", -1.0)); c.research_stored = float(cd.get("rstore", 0.0)); c.research_current = cd["research_current"]
		c.research_done.clear()
		c.tech_mods.clear()
		for t: String in cd["research_done"]:
			Research._complete(c, t, false)
		c.research_bonus = cd["research_bonus"]; c.decisions_active = cd["decisions"]
		c.manpower_used = int(cd["manpower_used"]); c.templates = cd["templates"]; c.faction = cd["faction"]
		c.war_goals = cd["war_goals"]; c.justify_progress = cd["justify"]
		c.guarantees.assign(cd["guarantees"]); c.access.assign(cd["access"]); c.capitulated = cd["capitulated"]
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
			c.construction_queue.append(cp)
	Diplomacy.wars = data["wars"]
	Diplomacy.waiting_to_join = data.get("waiting_to_join", {})
	Diplomacy._next_id = int(data["war_id"])
	Diplomacy._start_vp = data.get("start_vp", {})
	Politics.factions = data["factions"]
	Politics.fired_events = data.get("fired_events", [])
	Military.divisions.clear()
	Military._stats_cache.clear()
	for dd: Dictionary in data["divisions"]:
		var d := Division.new()
		d.id = int(dd["id"]); d.owner = dd["o"]; d.template = int(dd["t"]); d.name = dd["n"]; d.province = int(dd["p"])
		d.path = PackedInt32Array(dd["path"]); d.progress = float(dd["pr"]); d.strength = float(dd["s"])
		d.org = float(dd["org"]); d.attacking = int(dd["a"]); d.training = int(dd["tr"])
		d.xp = float(dd.get("xp", 0.15)); d.planning = float(dd.get("pl", 0.0)); d.army = int(dd.get("ar", 0)); d.hold = bool(dd.get("h", false))
		Military.divisions.append(d)
	Military._next_id = int(data["div_id"])
	if data.has("wings"):
		Air.from_save(data["wings"], int(data.get("wing_id", 1)))
	Military.armies.clear()
	for ad: Dictionary in data.get("armies", []):
		var a := Army.new()
		a.id = int(ad["id"]); a.owner = ad["o"]; a.name = ad["n"]; a.enemy = ad["e"]
		a.mode = int(ad["m"]) as Army.Mode; a.color = Color(ad["c"])
		Military.armies.append(a)
	Military._next_army = int(data.get("army_id", Military.armies.size() + 1))
	if data.has("fleets"):
		Navy.from_save(data["fleets"], int(data.get("fleet_id", 1)))
	Military._rebuild_index()
	World.flush_ownership()
	World.player_tag = data["player"]
	loaded = true
	return true
