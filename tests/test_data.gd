extends "res://tests/test_case.gd"
## Veri bütünlüğü: data/common/*.json içindeki her başvuru geçerli mi; etki ve koşul anahtarlarını motor tanıyor mu.
## Motorun tanıdığı anahtarlar kaynaktan okunur (politics.gd → _apply / describe_effects / check), liste elle tutulmaz.

## Açıklama metninde gösterilmeyen etkiler (yalnız apply_effects'te bulunur)
const HIDDEN_EFFECTS := ["news", "flag_target"]
## Ülke koduna başvuran etkiler (olaylarda FROM, her yerde self çözülür)
const TAG_EFFECTS := ["war_goal", "give_war_goal", "declare_war", "join_war_of", "guarantee", "grant_access",
	"white_peace_with", "annex", "annexed_by", "cede_border_to", "join_faction", "invite"]
const BUILD_WHERE := ["best", "capital", "capital_region"]
const LAW_REQUIRES := ["war_support", "at_war", "authoritarian_or_at_war"]
## Military.stats: tabur kategorisi + bu ekler teknoloji modifier'ı olur (ör. infantry_soft)
const CATEGORY_STATS := ["soft", "hard", "defense", "breakthrough", "speed"]
const POLITICS_SRC := "res://game/autoload/politics.gd"

var _code := ""
var _cities: Dictionary = {}       ## şehir adı (her dilde) -> City
var _flags_set: Dictionary = {}    ## flag_target ile konan bayraklar

# ------------------------------------------------------------------ olaylar
func test_events() -> void:
	var p: Array = []
	for id: String in Politics.events:
		var ev: Dictionary = Politics.events[id]
		_check_text(ev.get("title", {}), "olay %s başlığı" % id, p)
		var opts: Array = ev.get("options", [])
		if opts.is_empty():
			p.append("olay %s: seçenek yok" % id)
		for i in opts.size():
			var o: Dictionary = opts[i]
			var ctx := "olay %s / seçenek %d" % [id, i + 1]
			_check_text(o.get("name", {}), ctx + " adı", p)
			if float(o.get("ai", -1.0)) < 0.0:
				p.append("%s: ai ağırlığı yok ya da negatif" % ctx)
			_check_effects(o.get("effects", []), ctx, true, p)
			_check_conditions(o.get("require", []), ctx + " şartı", p)
		var trig: Variant = ev.get("trigger")
		if trig != null:
			var t: Dictionary = trig
			if not World.countries.has(str(t.get("tag", ""))):
				p.append("olay %s: tetik ülkesi '%s' yok" % [id, t.get("tag", "")])
			if t.has("from") and not World.countries.has(str(t["from"])):
				p.append("olay %s: tetik kaynağı '%s' yok" % [id, t["from"]])
			if not _valid_date(str(t.get("date", ""))):
				p.append("olay %s: tetik tarihi geçersiz '%s'" % [id, t.get("date", "")])
			_check_conditions(t.get("require", []), "olay %s tetik şartı" % id, p)
	none(p, "olay")

## Koddan ateşlenen olaylar (fire_event / pending_events) events.json'da var mı
func test_events_from_code() -> void:
	var p: Array = []
	# ilk argüman düz bir ifade ya da tek çağrı (World.player(), World.countries[m]); iç içe çağrı atlanır
	var re := RegEx.create_from_string("(?:\\bfire_event\\([^,()]+(?:\\([^()]*\\))?[^,()]*,\\s*|\"id\":\\s*)\"([a-z0-9_]+)\"")
	for m in re.search_all(_all_code()):
		var id := m.get_string(1)
		if not Politics.events.has(id):
			p.append("kod '%s' olayını kullanıyor ama events.json'da yok" % id)
	none(p, "olay")

# ------------------------------------------------------------------ odaklar
func test_focuses() -> void:
	var p: Array = []
	for tag: String in Politics.trees:
		if tag != "_generic" and not World.countries.has(tag):
			p.append("odak ağacı '%s': ülke yok" % tag)
		var tree: Dictionary = Politics.trees[tag]
		var order: Array = Politics.tree_order[tag]
		if order.size() != tree.size():
			p.append("ağaç %s: yinelenen odak kimliği" % tag)
		var cells := {}
		for id: String in order:
			var fo: Dictionary = tree[id]
			var ctx := "odak %s/%s" % [tag, id]
			_check_text(fo.get("name", {}), ctx + " adı", p)
			var cell := Vector2i(int(fo.get("x", -1)), int(fo.get("y", -1)))
			if cells.has(cell):
				p.append("%s: koordinat %s '%s' ile çakışıyor" % [ctx, str(cell), cells[cell]])
			cells[cell] = id
			if float(fo.get("days", 0)) <= 0.0:
				p.append("%s: süre (days) yok" % ctx)
			if float(fo.get("ai", -1)) < 0.0:
				p.append("%s: ai ağırlığı yok ya da negatif" % ctx)
			for key in ["prereq", "any_prereq", "exclusive"]:
				for other: String in fo.get(key, []):
					if not tree.has(other):
						p.append("%s: %s '%s' bu ağaçta yok" % [ctx, key, other])
					elif other == id:
						p.append("%s: %s kendisini gösteriyor" % [ctx, key])
			for other: String in fo.get("exclusive", []):
				if tree.has(other) and not id in tree[other].get("exclusive", []):
					p.append("%s: '%s' ile dışlayıcılık tek yönlü" % [ctx, other])
			_check_conditions(fo.get("available", []), ctx + " şartı", p)
			_check_effects(fo.get("effects", []), ctx, false, p)
		# önkoşul döngüsü
		for id: String in order:
			if _reaches(tree, id, id, {}):
				p.append("ağaç %s: '%s' önkoşul döngüsünde" % [tag, id])
	none(p, "odak")

func _reaches(tree: Dictionary, from: String, target: String, seen: Dictionary) -> bool:
	var fo: Dictionary = tree.get(from, {})
	for other: String in fo.get("prereq", []) + fo.get("any_prereq", []):
		if other == target:
			return true
		if not seen.has(other):
			seen[other] = true
			if _reaches(tree, other, target, seen):
				return true
	return false

# ------------------------------------------------------------------ ruhlar, danışmanlar, kararlar, popülerlik
func test_spirits() -> void:
	var p: Array = []
	var mods := _mod_keys()
	var d: Dictionary = read_json(Politics.SPIRITS_PATH)
	for sec in ["spirits", "advisors", "decisions"]:
		for id: String in d[sec]:
			var def: Dictionary = d[sec][id]
			_check_text(def.get("name", {}), "%s %s adı" % [sec, id], p)
			for k: String in def.get("mods", {}):
				if not k in mods:
					p.append("%s %s: bilinmeyen modifier '%s' (kod c.mod(\"%s\") okumuyor)" % [sec, id, k, k])
			if def.has("expires") and not _valid_date(str(def["expires"])):
				p.append("%s %s: expires tarihi geçersiz" % [sec, id])
	for id: String in d["decisions"]:
		var dec: Dictionary = d["decisions"][id]
		if not dec.has("cost") or not dec.has("days"):
			p.append("karar %s: cost/days yok" % id)
		if d["spirits"].has(id):
			p.append("karar %s: aynı adla ruh da var (spirit_mods karışır)" % id)
	for tag: String in d["start"]:
		if not World.countries.has(tag):
			p.append("başlangıç ruhu: ülke '%s' yok" % tag)
		for sp: String in d["start"][tag]:
			if not d["spirits"].has(sp):
				p.append("başlangıç ruhu %s: '%s' tanımlı değil" % [tag, sp])
	var ideos := _ideologies()
	for key: String in d["popularity"]:
		if not key.begins_with("_") and not World.countries.has(key):
			p.append("popülerlik: ülke '%s' yok" % key)
		var total := 0.0
		for ideo: String in d["popularity"][key]:
			if not ideo in ideos:
				p.append("popülerlik %s: ideoloji '%s' yok" % [key, ideo])
			total += float(d["popularity"][key][ideo])
		if absf(total - 1.0) > 0.011:
			p.append("popülerlik %s: toplam %.2f (1 olmalı)" % [key, total])
	for leader: String in d["start_factions"]:
		if not d["factions"].has(leader):
			p.append("başlangıç ittifakı %s: adı (factions) yok" % leader)
		for t: String in d["start_factions"][leader]:
			if not World.countries.has(t):
				p.append("başlangıç ittifakı %s: üye '%s' yok" % [leader, t])
	for leader: String in d["factions"]:
		if not World.countries.has(leader):
			p.append("ittifak adı: lider '%s' yok" % leader)
		_check_text(d["factions"][leader], "ittifak %s adı" % leader, p)
	none(p, "ruh")

# ------------------------------------------------------------------ teknolojiler
func test_technologies() -> void:
	var p: Array = []
	var mods := _mod_keys()
	for id: String in Research.techs:
		var t: Dictionary = Research.techs[id]
		var ctx := "teknoloji %s" % id
		_check_text(t.get("name", {}), ctx + " adı", p)
		if not Research.categories.has(str(t.get("cat", ""))):
			p.append("%s: kategori '%s' yok" % [ctx, t.get("cat", "")])
		if int(t.get("year", 0)) < 1900 or float(t.get("cost", 0)) <= 0.0:
			p.append("%s: yıl/maliyet geçersiz" % ctx)
		for r: String in t.get("req", []):
			if not Research.techs.has(r):
				p.append("%s: gereklilik '%s' yok" % [ctx, r])
		for e: String in t.get("unlock", []):
			if not Economy.equipment.has(e):
				p.append("%s: açtığı ekipman '%s' yok" % [ctx, e])
		for k: String in t.get("effects", {}):
			if not k in mods:
				p.append("%s: bilinmeyen modifier '%s'" % [ctx, k])
		if _tech_cycle(id, id, {}):
			p.append("%s: gereklilik döngüsü" % ctx)
	for t: String in Research.START_TECHS:
		if not Research.techs.has(t):
			p.append("başlangıç teknolojisi '%s' yok" % t)
	none(p, "teknoloji")

func _tech_cycle(from: String, target: String, seen: Dictionary) -> bool:
	for r: String in Research.techs.get(from, {}).get("req", []):
		if r == target:
			return true
		if not seen.has(r):
			seen[r] = true
			if _tech_cycle(r, target, seen):
				return true
	return false

# ------------------------------------------------------------------ yasalar
func test_laws() -> void:
	var p: Array = []
	var mods := _mod_keys()
	var law_values := _regex_set("law_value\\([a-z]+, \"([a-z_]+)\"")
	for g: String in Economy.law_groups:
		_check_text(Economy.law_groups[g].get("name", {}), "yasa grubu %s adı" % g, p)
		for law: String in Economy.law_groups[g]["laws"]:
			var d: Dictionary = Economy.law_groups[g]["laws"][law]
			_check_text(d.get("name", {}), "yasa %s adı" % law, p)
			for k: String in d:
				if k == "name":
					continue
				if k == "requires":
					for r: String in d[k]:
						if not r in LAW_REQUIRES:
							p.append("yasa %s: bilinmeyen şart '%s'" % [law, r])
				elif not k in mods and not k in law_values:
					p.append("yasa %s: '%s' etkisini kod okumuyor" % [law, k])
	var start: Dictionary = read_json(Economy.LAWS_PATH)["start"]
	if not start.has("_default"):
		p.append("yasalar: start._default yok")
	for tag: String in start:
		if tag != "_default" and not World.countries.has(tag):
			p.append("başlangıç yasası: ülke '%s' yok" % tag)
		for g: String in start[tag]:
			if not Economy.law_groups.has(g):
				p.append("başlangıç yasası %s: grup '%s' yok" % [tag, g])
			elif not Economy.law_groups[g]["laws"].has(start[tag][g]):
				p.append("başlangıç yasası %s: '%s' yasası yok" % [tag, start[tag][g]])
	for g: String in Economy.law_groups:
		if start.has("_default") and not start["_default"].has(g):
			p.append("yasalar: _default '%s' grubunu içermiyor" % g)
	none(p, "yasa")

# ------------------------------------------------------------------ birlikler, ekipman, binalar
func test_units_and_equipment() -> void:
	var p: Array = []
	for b: String in Military.battalions:
		var bd: Dictionary = Military.battalions[b]
		_check_text(bd.get("name", {}), "tabur %s adı" % b, p)
		for e: String in bd.get("equipment", {}):
			if not Economy.equipment.has(e):
				p.append("tabur %s: ekipman '%s' yok" % [b, e])
	for e: String in Military._division_equipment:
		if not Economy.equipment.has(e):
			p.append("tümen ekipmanı '%s' yok" % e)
	for t: Dictionary in Military.default_templates:
		_check_text(t.get("name", {}), "şablon adı", p)
		for b: String in t["battalions"]:
			if not Military.battalions.has(b):
				p.append("şablon %s: tabur '%s' yok" % [Politics.loc(t["name"]), b])
	for tag: String in Military.start_divisions:
		if not tag.begins_with("_") and not World.countries.has(tag):
			p.append("başlangıç tümenleri: ülke '%s' yok" % tag)
	for e: String in Economy.equipment:
		var ed: Dictionary = Economy.equipment[e]
		_check_text(ed.get("name", {}), "ekipman %s adı" % e, p)
		for r: String in ed.get("resources", {}):
			if not r in Economy.resource_names:
				p.append("ekipman %s: kaynak '%s' yok" % [e, r])
	var fleets: Dictionary = read_json(Economy.EQUIPMENT_PATH)["start_fleets"]
	for tag: String in fleets:
		if tag == "_bases" or tag == "_comment":
			continue
		if not tag.begins_with("_") and not World.countries.has(tag):
			p.append("başlangıç filosu: ülke '%s' yok" % tag)
		for s: String in fleets[tag]:
			if not Economy.equipment.has(s):
				p.append("başlangıç filosu %s: gemi '%s' ekipmanda yok" % [tag, s])
	for tag: String in fleets.get("_bases", {}):
		if tag == "_comment":
			continue
		if not World.countries.has(tag):
			p.append("filo üssü: ülke '%s' yok" % tag)
		for cname: String in fleets["_bases"][tag]:
			var ok := false
			for city: City in World.cities:
				if city.name == cname and city.is_port:
					ok = true
			if not ok:
				p.append("filo üssü %s: '%s' adlı liman şehri yok" % [tag, cname])
	for t: String in Air.TYPES:
		if not Economy.equipment.has(str(Air.TYPES[t]["eq"])):
			p.append("hava kanadı %s: ekipman yok" % t)
	for b: String in Economy.defs:
		_check_text(Economy.defs[b].get("name", {}), "bina %s adı" % b, p)
	none(p, "birlik")

func test_history() -> void:
	var p: Array = []
	var hist: Dictionary = read_json(Economy.HISTORY_PATH)["states"]
	for key: String in hist:
		if not World.states.has(int(key)):
			p.append("1936 eyalet %s: harita eyaleti yok" % key)
			continue
		for b: String in hist[key].get("buildings", {}):
			if not Economy.defs.has(b):
				p.append("1936 eyalet %s: bina '%s' yok" % [key, b])
		for r: String in hist[key].get("resources", {}):
			if not r in Economy.resource_names:
				p.append("1936 eyalet %s: kaynak '%s' yok" % [key, r])
	none(p, "tarih")

# ------------------------------------------------------------------ ülkeler
func test_countries() -> void:
	var p: Array = []
	var ideos := _ideologies()
	var data: Dictionary = read_json(World.COUNTRIES_PATH)["countries"]
	for tag: String in World.countries:
		var c: Country = World.countries[tag]
		_check_text(c.names, "ülke %s adı" % tag, p)
		if not c.ideology in ideos:
			p.append("ülke %s: ideoloji '%s' yok" % [tag, c.ideology])
		if not World.states.has(c.capital_state):
			p.append("ülke %s: başkent eyaleti yok" % tag)
		elif World.states[c.capital_state].owner != tag:
			p.append("ülke %s: başkent eyaleti başkasına ait" % tag)
		if c.leader == "":
			p.append("ülke %s: lider yok" % tag)
		var el: Dictionary = data[tag].get("elections", {})
		if el.has("next") and not _valid_date(str(el["next"])):
			p.append("ülke %s: seçim tarihi geçersiz" % tag)
		if int(el.get("months", 0)) > 0 and not el.has("next"):
			p.append("ülke %s: seçim aralığı var, tarihi yok" % tag)
	none(p, "ülke")

# ------------------------------------------------------------------ motor ↔ veri: etki sözlüğü
## Her etki hem apply_effects'te hem describe_effects'te karşılanmalı (CLAUDE.md kural 2)
func test_effect_dictionary_complete() -> void:
	var applied := _match_keys(POLITICS_SRC, "_apply")
	var described := _match_keys(POLITICS_SRC, "describe_effects")
	check(applied.size() > 10 and described.size() > 10, "politics.gd etki listesi okunamadı")
	var p: Array = []
	for k in applied:
		if not k in described and not k in HIDDEN_EFFECTS:
			p.append("'%s' apply_effects'te var, describe_effects'te yok" % k)
	for k in described:
		if not k in applied:
			p.append("'%s' describe_effects'te var, apply_effects'te yok" % k)
	none(p, "etki sözlüğü")

# ------------------------------------------------------------------ çeviri tablosu
func test_strings_rows() -> void:
	var p: Array = []
	var rows := _csv_rows()
	check(rows.size() > 100, "strings.csv okunamadı")
	var seen := {}
	for r: PackedStringArray in rows:
		var key := r[0]
		if seen.has(key):
			p.append("'%s' iki kez tanımlı" % key)
		seen[key] = true
		if r.size() < 3 or r[1].strip_edges() == "" or r[2].strip_edges() == "":
			p.append("'%s': en ya da tr boş" % key)
			continue
		var a := _placeholders(r[1])
		var b := _placeholders(r[2])
		if a.size() != b.size():
			p.append("'%s': yer tutucu sayısı farklı (en %d: %s, tr %d: %s)" % [key, a.size(), " ".join(a), b.size(), " ".join(b)])
	none(p, "strings.csv")

## Kodda kullanılan her anahtar strings.csv'de var mı: tr("ANAHTAR"), büyük harfli anahtar sabitleri
## ve ön ekli aileler (RES_ + kaynak, MOD_ + modifier, IDEOLOGY_ + ideoloji...)
func test_strings_used_in_code() -> void:
	var keys := _csv_keys()
	var p: Array = []
	for k in _regex_set("\\btr\\(\"([A-Za-z0-9_]+)\"\\)"):
		if not keys.has(k):
			p.append("tr(\"%s\") çeviri tablosunda yok" % k)
	for k in _regex_set("\"([A-Z][A-Z0-9]*_[A-Z0-9_]*[A-Z0-9])\""):
		if not keys.has(k):
			p.append("\"%s\" anahtar gibi kullanılıyor ama çeviri tablosunda yok" % k)
	for k in _regex_set("\\btr\\(\"([A-Z][A-Z0-9_]*_)\"\\s*\\+"):
		if not k in _families():
			p.append("ön ekli anahtar ailesi '%s' testte tanımlı değil (tests/test_data.gd _families)" % k)
	var fam := _families()
	for prefix: String in fam:
		for item in fam[prefix]:
			if not keys.has(prefix + str(item)):
				p.append("%s%s çeviri tablosunda yok" % [prefix, item])
	var suffixes := _suffix_families()
	for k in _regex_set("\\btr\\([^()\"]*\\+\\s*\"(_[A-Z0-9_]+)\"\\)"):
		if not suffixes.has(k):
			p.append("son ekli anahtar ailesi '%s' testte tanımlı değil (tests/test_data.gd _suffix_families)" % k)
	for suffix: String in suffixes:
		for item in suffixes[suffix]:
			if not keys.has(str(item) + suffix):
				p.append("%s%s çeviri tablosunda yok" % [item, suffix])
	for k in _regex_in("\"news\":\\s*\"([A-Z0-9_]+)\"", _data_text()):
		if not keys.has(k):
			p.append("veri: news '%s' çeviri tablosunda yok" % k)
	none(p, "çeviri")

## Ön ekli anahtar aileleri: tr("ÖNEK" + x) biçimindeki her kullanımın alabileceği değerler
func _families() -> Dictionary:
	var terrains := {}
	for pr: Province in World.provinces:
		if pr:
			terrains[pr.terrain] = true
	var cats := {}
	for st: StateRegion in World.states.values():
		cats[st.category] = true
	var law_effects: Array = []
	for k: String in _const_array("res://game/ui/politics_panel.gd", "EFFECT_KEYS"):
		law_effects.append(k)
	var mods: Dictionary = {}
	var d: Dictionary = read_json(Politics.SPIRITS_PATH)
	for sec in ["spirits", "advisors", "decisions"]:
		for id: String in d[sec]:
			for k: String in d[sec][id].get("mods", {}):
				mods[k] = true
	for id: String in Research.techs:
		for k: String in Research.techs[id].get("effects", {}):
			mods[k] = true
	var map_modes: Array = []
	for k: String in _const_array("res://game/ui/map_mode_bar.gd", "keys"):
		map_modes.append(k)
	return {
		"RES_": Economy.resource_names,
		"IDEOLOGY_": _ideologies(),
		"TERRAIN_": terrains.keys(),
		"CAT_": cats.keys(),
		"BDESC_": Economy.defs.keys(),
		"SHIP_": Navy.SHIP_TYPES,
		"SHIPS_": Navy.SHIP_TYPES,
		"WING_TYPE_": Air.TYPES.keys(),
		"WING_NAME_": Air.TYPES.keys(),
		"MOD_": mods.keys(),
		"EFFECT_": law_effects,
		"TIP_": map_modes,
	}

## Son ekli anahtar aileleri: tr(x + "SONEK") biçimindeki kullanımların alabileceği değerler
func _suffix_families() -> Dictionary:
	# army_panel: [["ARM_SOFT", değer], ...] → tr(pair[0] + "_TIP")
	return {"_TIP": _regex_in("\\[\"(ARM_[A-Z]+)\",", FileAccess.get_file_as_string("res://game/ui/army_panel.gd"))}

## Arayüzde ya da olay penceresinde gösterilen JSON metinleri iki dilde dolu mu (açıklamalar uyarı)
func test_json_texts() -> void:
	var missing := 0
	for tag: String in Politics.trees:
		for fo: Dictionary in Politics.trees[tag].values():
			var desc: Dictionary = fo.get("desc", {})
			if str(desc.get("tr", "")) != "" and str(desc.get("en", "")) == "":
				missing += 1
	for id: String in Politics.events:
		var desc: Dictionary = Politics.events[id].get("desc", {})
		if str(desc.get("tr", "")) == "" and str(desc.get("en", "")) == "":
			continue
		if str(desc.get("tr", "")) == "" or str(desc.get("en", "")) == "":
			fail("olay %s: açıklama yalnız bir dilde" % id)
	if missing > 0:
		warn("%d odak açıklamasının İngilizcesi boş (arayüz boş açıklamayı göstermez)" % missing)

# ------------------------------------------------------------------ denetim yardımcıları
func _check_text(d: Variant, ctx: String, p: Array) -> void:
	if not d is Dictionary:
		p.append("%s: metin sözlüğü değil" % ctx)
		return
	for lang in ["en", "tr"]:
		if str(d.get(lang, "")).strip_edges() == "":
			p.append("%s: '%s' metni boş" % [ctx, lang])

func _check_effects(effects: Array, ctx: String, allow_from: bool, p: Array) -> void:
	var known := _match_keys(POLITICS_SRC, "_apply")
	var params := _regex_in("e\\.get\\(\"([a-z_]+)\"", _func_body(POLITICS_SRC, "_apply"))
	for e: Dictionary in effects:
		var main := 0
		for k: String in e:
			var v: Variant = e[k]
			if k in params:
				continue
			if not k in known:
				p.append("%s: bilinmeyen etki '%s'" % [ctx, k])
				continue
			main += 1
			match k:
				"spirit", "remove_spirit":
					if not Politics.spirits.has(str(v)) and not Politics.decisions.has(str(v)):
						p.append("%s: ruh '%s' yok" % [ctx, v])
				"event":
					if not Politics.events.has(str(v)):
						p.append("%s: olay '%s' yok" % [ctx, v])
					_check_tag(str(e.get("target", "self")), ctx, allow_from, p)
				"building":
					if not Economy.defs.has(str(v)):
						p.append("%s: bina '%s' yok" % [ctx, v])
					if not str(e.get("where", "best")) in BUILD_WHERE:
						p.append("%s: bina yeri '%s' geçersiz" % [ctx, e["where"]])
				"resource":
					if not str(v) in Economy.resource_names:
						p.append("%s: kaynak '%s' yok" % [ctx, v])
				"equipment":
					for eq: String in v:
						if not Economy.equipment.has(eq):
							p.append("%s: ekipman '%s' yok" % [ctx, eq])
				"research_bonus":
					if not Research.categories.has(str(v)):
						p.append("%s: araştırma kategorisi '%s' yok" % [ctx, v])
				"popularity":
					for ideo: String in v:
						if not ideo in _ideologies():
							p.append("%s: ideoloji '%s' yok" % [ctx, ideo])
				"news":
					if not _csv_keys().has(str(v)):
						p.append("%s: haber anahtarı '%s' çeviri tablosunda yok" % [ctx, v])
				"cede_city_to":
					if not v is Dictionary or not v.has("city") or not v.has("to"):
						p.append("%s: cede_city_to {city, to} olmalı" % ctx)
					else:
						if not _city_names().has(str(v["city"])):
							p.append("%s: şehir '%s' haritada yok" % [ctx, v["city"]])
						_check_tag(str(v["to"]), ctx, allow_from, p)
				"flag_target":
					# hedef çözülmez: gerçek ülke kodu olmalı
					if e.has("target") and not World.countries.has(str(e["target"])):
						p.append("%s: flag_target hedefi '%s' ülke kodu değil" % [ctx, e["target"]])
				"set_leader":
					if v is Dictionary:
						_check_text(v, ctx + " lider adı", p)
					elif str(v) == "":
						p.append("%s: lider adı boş" % ctx)
				_:
					if k in TAG_EFFECTS:
						_check_tag(str(v), ctx, allow_from, p)
		if main == 0:
			p.append("%s: yalnız parametre içeren etki %s" % [ctx, str(e)])

func _check_tag(tag: String, ctx: String, allow_from: bool, p: Array) -> void:
	if tag == "self" or (tag == "FROM" and allow_from):
		return
	if tag == "FROM":
		p.append("%s: FROM burada çözülemez (kaynak ülke yok)" % ctx)
	elif not World.countries.has(tag):
		p.append("%s: ülke '%s' yok" % [ctx, tag])

func _check_conditions(conds: Array, ctx: String, p: Array) -> void:
	for cond: Dictionary in conds:
		_check_condition(cond, ctx, p)

func _check_condition(cond: Dictionary, ctx: String, p: Array) -> void:
	var known := _match_keys(POLITICS_SRC, "check")
	for k: String in cond:
		var v: Variant = cond[k]
		if not k in known:
			p.append("%s: bilinmeyen koşul '%s'" % [ctx, k])
			continue
		match k:
			"date":
				if not _valid_date(str(v)):
					p.append("%s: tarih '%s' geçersiz" % [ctx, v])
			"exists", "allied_with", "at_war_with":
				if not World.countries.has(str(v)):
					p.append("%s: ülke '%s' yok" % [ctx, v])
			"enemies_at_war":
				for t in v:
					if not World.countries.has(str(t)):
						p.append("%s: ülke '%s' yok" % [ctx, t])
			"ideology":
				if not str(v) in _ideologies():
					p.append("%s: ideoloji '%s' yok" % [ctx, v])
			"has_focus":
				var found := false
				for tag: String in Politics.trees:
					if Politics.trees[tag].has(str(v)):
						found = true
				if not found:
					p.append("%s: odak '%s' yok" % [ctx, v])
			"has_flag":
				if not _flags().has(str(v)):
					p.append("%s: bayrak '%s' hiçbir flag_target ile konmuyor" % [ctx, v])
			"owns_city_not":
				if not _city_names().has(str(v)):
					p.append("%s: şehir '%s' haritada yok" % [ctx, v])
			"not":
				if v is Dictionary:
					_check_condition(v, ctx + " (not)", p)
				else:
					p.append("%s: not bir koşul sözlüğü olmalı" % ctx)

func _valid_date(s: String) -> bool:
	var parts := s.split("-")
	if parts.size() != 3 or not parts[0].is_valid_int() or not parts[1].is_valid_int() or not parts[2].is_valid_int():
		return false
	var m := int(parts[1])
	var d := int(parts[2])
	return int(parts[0]) >= 1900 and m >= 1 and m <= 12 and d >= 1 and d <= GameClock.DAYS_IN_MONTH[m - 1]

## Geçerli ideolojiler: spirits.json popülerlik şablonlarından (_democratic, _fascism...)
func _ideologies() -> Array[String]:
	var out: Array[String] = []
	for key: String in read_json(Politics.SPIRITS_PATH)["popularity"]:
		if key.begins_with("_"):
			out.append(key.substr(1))
	return out

## Kodun okuduğu modifier anahtarları: c.mod("x") + tabur kategorisi_istatistik (Military.stats)
func _mod_keys() -> Array[String]:
	var out: Array[String] = []
	for k in _regex_set("\\bmod\\(\"([a-z_]+)\"\\)"):
		out.append(k)
	var cats := {}
	for b: String in Military.battalions:
		cats[str(Military.battalions[b]["category"])] = true
	for cat: String in cats:
		for s in CATEGORY_STATS:
			out.append("%s_%s" % [cat, s])
	return out

func _city_names() -> Dictionary:
	if _cities.is_empty():
		for city: City in World.cities:
			_cities[city.name] = city
			for n: String in city.names.values():
				_cities[n] = city
	return _cities

func _flags() -> Dictionary:
	if _flags_set.is_empty():
		for m in RegEx.create_from_string("\"flag_target\":\\s*\"([a-z0-9_]+)\"").search_all(_data_text()):
			_flags_set[m.get_string(1)] = true
	return _flags_set

# ------------------------------------------------------------------ kaynak / dosya okuma
func _all_code() -> String:
	if _code == "":
		var parts: PackedStringArray = []
		for f in _gd_files("res://game/"):
			parts.append(FileAccess.get_file_as_string(f))
		_code = "\n".join(parts)
	return _code

func _gd_files(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir + f)
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(_gd_files(dir + sub + "/"))
	return out

func _data_text() -> String:
	var parts: PackedStringArray = []
	for f in DirAccess.get_files_at("res://data/common/"):
		if f.ends_with(".json"):
			parts.append(FileAccess.get_file_as_string("res://data/common/" + f))
	return "\n".join(parts)

## Oyun kodunda (game/**/*.gd) desenin ilk grubunun farklı değerleri
func _regex_set(pattern: String) -> Array[String]:
	return _regex_in(pattern, _all_code())

func _regex_in(pattern: String, text: String) -> Array[String]:
	var out: Array[String] = []
	for m in RegEx.create_from_string(pattern).search_all(text):
		var s := m.get_string(1)
		if not s in out:
			out.append(s)
	return out

## Kaynak dosyadaki bir fonksiyonun gövdesi (sonraki üst düzey "func"a kadar)
func _func_body(path: String, fname: String) -> String:
	var src := FileAccess.get_file_as_string(path)
	var start := src.find("\nfunc %s(" % fname)
	if start < 0:
		return ""
	var end := src.find("\nfunc ", start + 1)
	return src.substr(start, end - start if end > 0 else -1)

## Fonksiyondaki match kollarının anahtarları:  <sekmeler>"anahtar":
func _match_keys(path: String, fname: String) -> Array[String]:
	return _regex_in("(?m)^\\t+\"([a-z_]+)\":", _func_body(path, fname))

## Kaynaktaki bir dizi sabitinin/değişkeninin dizgileri:  NAME := ["A", "B"]
func _const_array(path: String, name: String) -> Array[String]:
	var src := FileAccess.get_file_as_string(path)
	var m := RegEx.create_from_string(name + "\\s*:?=\\s*\\[([^\\]]*)\\]").search(src)
	var out: Array[String] = []
	if m:
		for s in RegEx.create_from_string("\"([^\"]+)\"").search_all(m.get_string(1)):
			out.append(s.get_string(1))
	return out

func _csv_rows() -> Array[PackedStringArray]:
	var out: Array[PackedStringArray] = []
	var f := FileAccess.open("res://game/localization/strings.csv", FileAccess.READ)
	if f == null:
		return out
	f.get_csv_line()          # başlık: keys,en,tr
	while not f.eof_reached():
		var r := f.get_csv_line()
		if r.size() == 0 or (r.size() == 1 and r[0] == ""):
			continue
		out.append(r)
	return out

func _csv_keys() -> Dictionary:
	var keys := {}
	for r in _csv_rows():
		keys[r[0]] = true
	return keys

## printf yer tutucuları (%s, %d, %.1f, %+d ...); %% sayılmaz
func _placeholders(s: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for m in RegEx.create_from_string("%(%|[-+ 0-9.]*[sdfcxX])").search_all(s):
		if m.get_string(1) != "%":
			out.append(m.get_string())
	return out
