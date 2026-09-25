extends Node
## Siyaset: milli odak ağaçları, olaylar (etki dili), milli ruhlar, danışmanlar, kararlar.
## Etkiler ve koşullar data/common/*.json içinde tanımlanır; bu dosya onları yorumlar.

signal focus_completed(tag: String, focus_id: String)
signal event_fired(tag: String, event_id: String, from_tag: String)   ## oyuncu için açılır pencere
signal politics_changed(tag: String)

const FOCUS_PATH := "res://data/common/focuses.json"
const EVENTS_PATH := "res://data/common/events.json"
const SPIRITS_PATH := "res://data/common/spirits.json"

var trees: Dictionary = {}          ## tag -> {id: focus}
var tree_order: Dictionary = {}     ## tag -> [ids]
var events: Dictionary = {}
var spirits: Dictionary = {}
var advisor_defs: Dictionary = {}
var decisions: Dictionary = {}
var advisor_cost := 150.0
var max_advisors := 3
var faction_names: Dictionary = {}
var factions: Dictionary = {}       ## ad (lider tag) -> [üye tag]
var pending_events: Array = []      ## oyuncuya gösterilecek [{id, from}]
var _data: Dictionary = {}

func _ready() -> void:
	var f: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FOCUS_PATH))["trees"]
	for tag: String in f:
		trees[tag] = {}
		tree_order[tag] = []
		for fo: Dictionary in f[tag]:
			trees[tag][fo["id"]] = fo
			tree_order[tag].append(fo["id"])
	events = JSON.parse_string(FileAccess.get_file_as_string(EVENTS_PATH))["events"]
	_data = JSON.parse_string(FileAccess.get_file_as_string(SPIRITS_PATH))
	spirits = _data["spirits"]
	advisor_defs = _data["advisors"]
	decisions = _data["decisions"]
	advisor_cost = float(_data["advisor_cost"])
	max_advisors = int(_data["max_advisors"])
	faction_names = _data["factions"]
	World.daily_update.connect(_on_day)
	reset()

func reset() -> void:
	factions.clear()
	pending_events.clear()
	for c: Country in World.countries.values():
		c.spirits.clear()
		for sp: String in _data["start"].get(c.tag, []):
			c.spirits.append(sp)
		var pop: Dictionary = _data["popularity"].get(c.tag, _data["popularity"]["_" + c.ideology])
		c.popularity = pop.duplicate()
		c.research_slots = 3 if c.is_major() else 2
	for leader: String in _data["start_factions"]:
		factions[leader] = []
		for t: String in _data["start_factions"][leader]:
			factions[leader].append(t)
			World.countries[t].faction = leader

# ------------------------------------------------------------------ sorgular
func loc(d: Dictionary) -> String:
	return d.get(TranslationServer.get_locale().substr(0, 2), d.get("en", ""))

func spirit_mods(id: String) -> Dictionary:
	return spirits.get(id, {}).get("mods", {}) if spirits.has(id) else _decision_mods(id)

func _decision_mods(id: String) -> Dictionary:
	return decisions.get(id, {}).get("mods", {})

func advisor_mods(id: String) -> Dictionary:
	return advisor_defs.get(id, {}).get("mods", {})

func tree_of(c: Country) -> Dictionary:
	return trees.get(c.tag, trees["_generic"])

func focus_def(c: Country, id: String) -> Dictionary:
	return tree_of(c).get(id, {})

func faction_display(leader: String) -> String:
	return loc(faction_names.get(leader, {"en": leader, "tr": leader}))

## Etkin istikrar/savaş desteği (taban + modifier), 0..1
func stability(c: Country) -> float:
	return clampf(c.stability + c.mod("stability"), 0.0, 1.0)

func war_support(c: Country) -> float:
	return clampf(c.war_support + c.mod("war_support"), 0.0, 1.0)

## İstikrar %50'nin altındaysa fabrika çıktısı cezası
func stability_output_penalty(c: Country) -> float:
	return minf(0.0, (stability(c) - 0.5) * 0.5)

func can_start_focus(c: Country, id: String) -> bool:
	var fo := focus_def(c, id)
	if fo.is_empty() or id in c.focus_done or c.focus_current != "":
		return false
	for p: String in fo["prereq"]:
		if not p in c.focus_done:
			return false
	if not fo["any_prereq"].is_empty():
		var any := false
		for p: String in fo["any_prereq"]:
			if p in c.focus_done:
				any = true
		if not any:
			return false
	for x: String in fo["exclusive"]:
		if x in c.focus_done or x == c.focus_current:
			return false
	return check_all(c, fo["available"])

func start_focus(c: Country, id: String) -> bool:
	if not can_start_focus(c, id):
		return false
	c.focus_current = id
	c.focus_progress = 0.0
	politics_changed.emit(c.tag)
	return true

func cancel_focus(c: Country) -> void:
	c.focus_current = ""
	c.focus_progress = 0.0
	politics_changed.emit(c.tag)

# ------------------------------------------------------------------ koşullar
func check_all(c: Country, conds: Array) -> bool:
	for cond: Dictionary in conds:
		if not check(c, cond):
			return false
	return true

func _date(s: String) -> int:
	var p := s.split("-")
	return int(p[0]) * 10000 + int(p[1]) * 100 + int(p[2])

func check(c: Country, cond: Dictionary) -> bool:
	for k: String in cond:
		var v = cond[k]
		match k:
			"date":
				if World.date_value() < _date(v): return false
			"has_focus":
				if not v in c.focus_done: return false
			"exists":
				var t: Country = World.countries.get(v)
				if t == null or not t.exists(): return false
			"tension":
				if World.world_tension < float(v): return false
			"ideology":
				if c.ideology != v: return false
			"has_flag":
				if not c.decisions_active.has("flag_" + str(v)): return false
			"at_war":
				if Diplomacy.at_war(c.tag) != bool(v): return false
			"enemies_at_war":
				if not Diplomacy.are_enemies(v[0], v[1]): return false
			"owns_city_not":
				for city: City in World.cities:
					if city.name == v or city.names.values().has(v):
						var st: StateRegion = World.states.get(city.state_id)
						if st and st.owner == c.tag: return false
			"not":
				if check(c, v): return false
	return true

# ------------------------------------------------------------------ etkiler
func apply_effects(c: Country, effects: Array, from_tag: String = "") -> void:
	for e: Dictionary in effects:
		_apply(c, e, from_tag)
	politics_changed.emit(c.tag)

func _resolve(tag: String, from_tag: String, c: Country) -> String:
	if tag == "FROM":
		return from_tag
	if tag == "self":
		return c.tag
	return tag

func _apply(c: Country, e: Dictionary, from_tag: String) -> void:
	if e.get("ai_only", false) and c.tag == World.player_tag and World.in_game:
		return
	for k: String in e:
		var v = e[k]
		match k:
			"pp": c.political_power += float(v)
			"stability": c.stability = clampf(c.stability + float(v), 0.0, 1.0)
			"war_support": c.war_support = clampf(c.war_support + float(v), 0.0, 1.0)
			"tension": World.world_tension = clampf(World.world_tension + float(v), 0.0, 100.0)
			"spirit":
				if not v in c.spirits: c.spirits.append(v)
			"remove_spirit": c.spirits.erase(v)
			"research_slot": c.research_slots += int(v)
			"research_bonus": c.research_bonus.append({"category": v, "value": float(e.get("value", 0.5)), "uses": int(e.get("uses", 1))})
			"building": _add_buildings(c, v, int(e.get("count", 1)), e.get("where", "best"))
			"resource":
				var st: StateRegion = World.states.get(c.capital_state)
				if st: st.resources[v] = int(st.resources.get(v, 0)) + int(e.get("amount", 0))
			"equipment":
				for eq: String in v:
					c.stockpile[eq] = float(c.stockpile.get(eq, 0.0)) + float(v[eq])
			"add_divisions": Military.spawn_free_divisions(c, int(v))
			"popularity":
				for ideo: String in v:
					c.popularity[ideo] = clampf(float(c.popularity.get(ideo, 0.0)) + float(v[ideo]), 0.0, 1.0)
			"war_goal": Diplomacy.add_war_goal(c, _resolve(v, from_tag, c))
			"give_war_goal": Diplomacy.add_war_goal(World.countries[_resolve(v, from_tag, c)], c.tag)
			"declare_war": Diplomacy.declare_war(c.tag, _resolve(v, from_tag, c))
			"join_war_of": Diplomacy.join_wars_of(c.tag, _resolve(v, from_tag, c))
			"guarantee": Diplomacy.guarantee(c.tag, _resolve(v, from_tag, c))
			"grant_access": Diplomacy.grant_access(c.tag, _resolve(v, from_tag, c))
			"white_peace_with": Diplomacy.white_peace(c.tag, _resolve(v, from_tag, c))
			"annex": World.annex(_resolve(v, from_tag, c), c.tag); _news("NEWS_ANNEX", [World.countries[_resolve(v, from_tag, c)].display_name(), c.display_name()])
			"annexed_by": World.annex(c.tag, _resolve(v, from_tag, c)); _news("NEWS_ANNEX", [c.display_name(), World.countries[_resolve(v, from_tag, c)].display_name()])
			"cede_border_to": _cede_border(c, _resolve(v, from_tag, c))
			"cede_city_to":
				var to := _resolve(v["to"], from_tag, c)
				for city: City in World.cities:
					if city.name == v["city"] or city.names.values().has(v["city"]):
						World.transfer_state(city.state_id, to)
				World.flush_ownership()
				_news("NEWS_CEDE", [c.display_name(), World.countries[to].display_name()])
			"create_faction": Diplomacy.create_faction(c.tag)
			"join_faction": Diplomacy.join_faction(c.tag, _resolve(v, from_tag, c))
			"invite": fire_event(World.countries[_resolve(v, from_tag, c)], "faction_invite", c.tag)
			"event": fire_event(World.countries[_resolve(e.get("target", "self"), from_tag, c)], v, c.tag)
			"flag_target":
				var t: Country = World.countries.get(e.get("target", c.tag))
				if t: t.decisions_active["flag_" + str(v)] = 1 << 30
			"news": _news(v, [c.display_name()])

func _news(key: String, args: Array) -> void:
	var text := tr(key)
	if text.count("%s") == args.size():
		text = text % args
	elif text.count("%s") > 0:
		text = text % [args[0]]
	World.notify(text, "info")

func _add_buildings(c: Country, b: String, count: int, where: String) -> void:
	var sids: Array = c.states.duplicate()
	if where == "capital" or where == "capital_region":
		sids.sort_custom(func(a: int, b2: int) -> bool: return a == c.capital_state)
	else:
		sids.sort_custom(func(a: int, b2: int) -> bool: return World.states[a].free_slots() > World.states[b2].free_slots())
	for sid in sids:
		if count <= 0:
			break
		var st: StateRegion = World.states[sid]
		var d: Dictionary = Economy.defs[b]
		if d.get("coastal", false) and not st.coastal:
			continue
		while count > 0 and st.building_level(b) < int(d["max"]) and (not d.get("shared_slots", false) or st.free_slots() > 0):
			st.buildings[b] = st.building_level(b) + 1
			count -= 1
			Economy.building_completed.emit(c.tag, sid, b)

## Hedef ülkenin, alıcıya komşu eyaletlerini devret (Südet tipi)
func _cede_border(c: Country, to: String) -> void:
	var moved := []
	for sid in c.states.duplicate():
		var st: StateRegion = World.states[sid]
		var border := false
		for pid in st.provinces:
			for n in World.land_neighbors(pid):
				var o := World.owner_of_province(n)
				if o and o.tag == to:
					border = true
		if border and sid != c.capital_state:
			moved.append(sid)
	for sid in moved:
		World.transfer_state(sid, to)
	World.flush_ownership()
	_news("NEWS_CEDE", [c.display_name(), World.countries[to].display_name()])

# ------------------------------------------------------------------ olaylar
func fire_event(target: Country, id: String, from_tag: String) -> void:
	if target == null or not target.exists() or not events.has(id):
		return
	if target.tag == World.player_tag and World.in_game:
		pending_events.append({"id": id, "from": from_tag})
		event_fired.emit(target.tag, id, from_tag)
	else:
		var opt := _ai_option(id)
		if id == "faction_invite":
			opt = 0 if Diplomacy.ai_accepts_invite(target, World.countries[from_tag]) else 1
		elif id == "call_to_arms":
			opt = 0 if target.ideology == World.countries[from_tag].ideology or randf() < 0.3 else 1
		choose_option(target, id, opt, from_tag)

func _ai_option(id: String) -> int:
	var opts: Array = events[id]["options"]
	var r := randf()
	var acc := 0.0
	for i in opts.size():
		acc += float(opts[i]["ai"])
		if r <= acc:
			return i
	return 0

func choose_option(c: Country, id: String, option: int, from_tag: String) -> void:
	var opts: Array = events[id]["options"]
	apply_effects(c, opts[clampi(option, 0, opts.size() - 1)]["effects"], from_tag)

# ------------------------------------------------------------------ danışman / karar
func can_hire(c: Country, id: String) -> bool:
	return not id in c.advisors and c.advisors.size() < max_advisors and c.political_power >= advisor_cost

func hire(c: Country, id: String) -> void:
	if can_hire(c, id):
		c.political_power -= advisor_cost
		c.advisors.append(id)
		politics_changed.emit(c.tag)

func dismiss(c: Country, id: String) -> void:
	c.advisors.erase(id)
	politics_changed.emit(c.tag)

func can_take_decision(c: Country, id: String) -> bool:
	var d: Dictionary = decisions[id]
	if c.decisions_active.has(id) or c.political_power < float(d["cost"]):
		return false
	return not d.get("requires_war", false) or Diplomacy.at_war(c.tag)

func take_decision(c: Country, id: String) -> void:
	if not can_take_decision(c, id):
		return
	c.political_power -= float(decisions[id]["cost"])
	c.decisions_active[id] = World.day_count + int(decisions[id]["days"])
	c.spirits.append(id)
	politics_changed.emit(c.tag)

# ------------------------------------------------------------------ günlük
func _on_day() -> void:
	var __t := Time.get_ticks_usec()
	_on_day_impl()
	GameClock.timed("politics", __t)

func _on_day_impl() -> void:
	for c: Country in World.countries.values():
		if not c.exists():
			continue
		if c.focus_current != "":
			c.focus_progress += 1.0
			var fo := focus_def(c, c.focus_current)
			if fo.is_empty():
				c.focus_current = ""
			elif c.focus_progress >= float(fo["days"]):
				var id := c.focus_current
				c.focus_done.append(id)
				c.focus_current = ""
				c.focus_progress = 0.0
				apply_effects(c, fo["effects"])
				focus_completed.emit(c.tag, id)
		for d: String in c.decisions_active.keys():
			if not d.begins_with("flag_") and World.day_count >= int(c.decisions_active[d]):
				c.decisions_active.erase(d)
				c.spirits.erase(d)
	# gerginlik yavaşça düşer (savaş yoksa)
	if not Diplomacy.any_war():
		World.world_tension = maxf(World.world_tension - 0.02, 0.0)

# ------------------------------------------------------------------ açıklama metni
func _cname(tag: String) -> String:
	var c: Country = World.countries.get(tag)
	return c.display_name() if c else tag

func describe_effects(effects: Array, from_tag := "") -> String:
	var lines := []
	for e: Dictionary in effects:
		for k: String in e:
			var v = e[k]
			var t := ""
			match k:
				"pp": t = tr("EFF_PP") % int(v)
				"stability": t = tr("EFF_STABILITY") % roundi(float(v) * 100)
				"war_support": t = tr("EFF_WAR_SUPPORT") % roundi(float(v) * 100)
				"tension": t = tr("EFF_TENSION") % int(v)
				"spirit": t = tr("EFF_SPIRIT") % loc(spirits.get(v, decisions.get(v, {"name": {"en": v}}))["name"])
				"remove_spirit": t = tr("EFF_REMOVE_SPIRIT") % loc(spirits.get(v, {"name": {"en": v}})["name"])
				"research_slot": t = tr("EFF_RESEARCH_SLOT") % int(v)
				"research_bonus": t = tr("EFF_RESEARCH_BONUS") % [roundi(float(e.get("value", 0.5)) * 100), Research.category_name(v)]
				"building": t = tr("EFF_BUILDING") % [int(e.get("count", 1)), Economy.building_name(v)]
				"resource": t = tr("EFF_RESOURCE") % [int(e.get("amount", 0)), tr("RES_" + str(v))]
				"equipment":
					var parts := []
					for eq: String in v:
						parts.append("%d %s" % [int(v[eq]), Economy.equipment_name(eq)])
					t = tr("EFF_EQUIPMENT") % ", ".join(parts)
				"add_divisions": t = tr("EFF_DIVISIONS") % int(v)
				"war_goal": t = tr("EFF_WAR_GOAL") % _cname(_resolve(v, from_tag, World.player()))
				"declare_war":
					if not e.get("ai_only", false):
						t = tr("EFF_DECLARE_WAR") % _cname(v)
				"guarantee": t = tr("EFF_GUARANTEE") % _cname(v)
				"annex": t = tr("EFF_ANNEX") % _cname(v)
				"annexed_by": t = tr("EFF_ANNEXED_BY") % _cname(_resolve(v, from_tag, World.player()))
				"cede_border_to": t = tr("EFF_CEDE_BORDER") % _cname(_resolve(v, from_tag, World.player()))
				"cede_city_to": t = tr("EFF_CEDE_CITY") % [v["city"], _cname(_resolve(v["to"], from_tag, World.player()))]
				"give_war_goal": t = tr("EFF_GIVE_WAR_GOAL") % _cname(_resolve(v, from_tag, World.player()))
				"create_faction": t = tr("EFF_CREATE_FACTION")
				"join_faction": t = tr("EFF_JOIN_FACTION") % _cname(_resolve(v, from_tag, World.player()))
				"invite": t = tr("EFF_INVITE") % _cname(v)
				"join_war_of": t = tr("EFF_JOIN_WAR") % _cname(_resolve(v, from_tag, World.player()))
				"event": t = tr("EFF_EVENT") % _cname(e.get("target", ""))
				"popularity":
					for ideo: String in v:
						t = tr("EFF_POPULARITY") % [roundi(float(v[ideo]) * 100), tr("IDEOLOGY_" + ideo)]
				"white_peace_with": t = tr("EFF_WHITE_PEACE") % _cname(_resolve(v, from_tag, World.player()))
				"grant_access": t = tr("EFF_ACCESS") % _cname(_resolve(v, from_tag, World.player()))
			if t != "":
				lines.append("• " + t)
	return "\n".join(lines)

func describe_mods(mods: Dictionary) -> String:
	var lines := []
	for k: String in mods:
		var v := float(mods[k])
		lines.append("• %s: %s%d%%" % [tr("MOD_" + k), "+" if v > 0 else "", roundi(v * 100)])
	return "\n".join(lines)
