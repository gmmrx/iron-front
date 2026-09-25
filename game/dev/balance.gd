extends SceneTree
## Otomatik denge testi: N simülasyonu 1936'dan HEDEF tarihe kadar koşturur, kritik tarih olaylarını kaydeder
## ve tarihî aralıklarla karşılaştırır.
##   godot --headless --path . -s game/dev/balance.gd -- --runs=6 [--until=19420601] [--player=TUR]
## Çıktı: koşu başına olay tablosu + kontrol başına geçme oranı. Çıkış kodu: tüm kontroller %80+ ise 0.

const WATCH := ["POL", "FRA", "ENG", "GER", "SOV", "ITA", "CZE", "HOL", "BEL", "NOR", "YUG", "GRE", "JAP", "CHI", "USA"]

## [ad, açıklama, kontrol(olaylar: Dictionary) -> bool]
var checks: Array = [
	["poland", "Polonya 1940 sonuna kadar düşer", func(e: Dictionary) -> bool: return _before(e, "cap:POL", 19410101)],
	["france", "Fransa 1940–1941 arasında düşer", func(e: Dictionary) -> bool: return _before(e, "cap:FRA", 19420101) and not _before(e, "cap:FRA", 19400101)],
	["uk_holds", "İngiltere ayakta kalır", func(e: Dictionary) -> bool: return not e.has("cap:ENG")],
	["germany_holds", "Almanya 1941 ortasına kadar ayakta", func(e: Dictionary) -> bool: return not _before(e, "cap:GER", 19410701)],
	["soviet_holds", "SSCB ayakta kalır", func(e: Dictionary) -> bool: return not e.has("cap:SOV")],
	["italy_holds", "İtalya 1941 ortasına kadar ayakta", func(e: Dictionary) -> bool: return not _before(e, "cap:ITA", 19410701)],
	["germany_1942", "Almanya 1942 ortasına kadar ayakta", func(e: Dictionary) -> bool: return not _before(e, "cap:GER", 19420601)],
	["barbarossa", "Almanya SSCB'ye savaş açar", func(e: Dictionary) -> bool: return e.has("war:GER>SOV")],
	["japan_china", "Japonya–Çin savaşı 1937–1938", func(e: Dictionary) -> bool: return _before(e, "war:JAP>CHI", 19390101) and not _before(e, "war:JAP>CHI", 19370101)],
	["pacific_war", "Japonya–ABD savaşı 1941–1942", func(e: Dictionary) -> bool: return _before(e, "war:JAP>USA", 19420601) and not _before(e, "war:JAP>USA", 19410101)],
	["china_holds", "Çin 1942 ortasına kadar ayakta", func(e: Dictionary) -> bool: return not e.has("cap:CHI")],
	["poland_war", "Almanya–Polonya savaşı 1938–1940", func(e: Dictionary) -> bool: return _before(e, "war:GER>POL", 19410101) and not _before(e, "war:GER>POL", 19380101)],
]

var _events := {}
var _W: Node
var _C: Node
var _D: Node

func _before(e: Dictionary, key: String, date: int) -> bool:
	return e.has(key) and int(e[key]) < date

func _init() -> void:
	await process_frame
	var runs := 6
	var until := 19420601
	var player := "TUR"
	var seed_base := 1000
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--runs="): runs = int(a.substr(7))
		if a.begins_with("--until="): until = int(a.substr(8))
		if a.begins_with("--player="): player = a.substr(9)
		if a.begins_with("--seed="): seed_base = int(a.substr(7))
	_W = root.get_node("World")
	_C = root.get_node("GameClock")
	_D = root.get_node("Diplomacy")
	var G: Node = root.get_node("Game")
	_D.connect("wars_changed", _on_wars)
	_D.connect("country_capitulated", func(tag: String) -> void:
		if not _events.has("cap:" + tag):
			_events["cap:" + tag] = _W.date_value())
	var results: Array = []
	var t_all := Time.get_ticks_msec()
	for r in runs:
		seed(seed_base + r * 7919)
		var t0 := Time.get_ticks_msec()
		G.new_game()
		_W.start_game(player)
		_events = {}
		var dbg := OS.get_environment("BALDBG") == "1"
		var last_m := -1
		while _W.date_value() < until:
			_C.advance_hours(24 * 5)
			if dbg and _W.date_value() >= 19390801 and _W.date_value() / 100 != last_m:
				last_m = _W.date_value() / 100
				_front_debug()
			for tag: String in WATCH:
				var c = _W.countries.get(tag)
				if c and (c.capitulated or not c.exists()) and not _events.has("cap:" + tag):
					_events["cap:" + tag] = _W.date_value()
		results.append(_events.duplicate())
		if OS.get_environment("BALDBG") == "1":
			var pr: Dictionary = _C.prof
			var ks := pr.keys()
			ks.sort_custom(func(x: String, y: String) -> bool: return pr[x] > pr[y])
			var parts: Array = []
			for k: String in ks.slice(0, 10):
				parts.append("%s=%.1fs" % [k, pr[k] / 1e6])
			print("PROF ", " ".join(parts))
		print("koşu %d (%.0f sn): %s" % [r + 1, (Time.get_ticks_msec() - t0) / 1000.0, _summary(_events)])
	print("\n== DENGE SONUCU (%d koşu, %.0f dk) ==" % [runs, (Time.get_ticks_msec() - t_all) / 60000.0])
	var all_ok := true
	for ch: Array in checks:
		var n := 0
		for e: Dictionary in results:
			if (ch[2] as Callable).call(e):
				n += 1
		var rate := float(n) / maxf(runs, 1)
		if rate < 0.8:
			all_ok = false
		print("  %s [%s] %-38s %d/%d" % ["OK  " if rate >= 0.8 else "FAIL", ch[0], ch[1], n, runs])
	quit(0 if all_ok else 1)

## Batı cephesi: Almanya'nın batı/doğu tümen dağılımı, Müttefik tümenleri, denizdekiler, kaybedilen Alman eyaletleri
func _front_debug() -> void:
	var M: Node = root.get_node("Military")
	var gw := 0
	var ge := 0
	var al_w := 0
	var al_sea := 0
	var ger_x: float = _W.capital_position("GER").x
	for d in M.divisions:
		var p = _W.province(d.province)
		if d.owner == "GER":
			if p.center.x < ger_x - 120.0: gw += 1
			else: ge += 1
		elif d.owner in ["FRA", "ENG"]:
			if not p.is_land(): al_sea += 1
			elif p.center.x > 7700.0 and p.center.x < ger_x and p.center.y < 2900.0: al_w += 1
	var lost: Array = []
	var gained := 0
	for st in _W.states.values():
		if st.owner == "GER" and _W.controller_tag(st.provinces[0]) != "GER":
			lost.append("%s:%s" % [st.display_name(), _W.controller_tag(st.provinces[0])])
		elif st.owner == "FRA" and _W.controller_tag(st.provinces[0]) == "GER":
			gained += 1
	if _W.date_value() % 10000 < 200:
		var AI: Node = root.get_node("AI")
		var E: Node = root.get_node("Economy")
		for t in ["GER", "FRA", "ENG", "ITA", "SOV", "POL", "USA", "JAP"]:
			var c = _W.countries[t]
			print("DIVS %s %s n=%d target=%d milf=%d mpop=%.1fM" % [_W.date_value(), t, M.country_divisions(t).size(), AI._target_divisions(c), E.count(c, "military_factory"), c.manpower_pop / 1e6])
	var ll: Dictionary = M.loss_log
	var ls: Array = []
	for k: String in ll:
		if k.begins_with("GER") or k.begins_with("FRA") or k.begins_with("ENG") or k.begins_with("ITA"):
			ls.append("%s=%d" % [k, ll[k]])
	var unsup := 0
	var lowstr := 0
	for d in M.country_divisions("GER"):
		if not d.supplied: unsup += 1
		if d.strength < 0.5: lowstr += 1
	print("LOSS %d %s GERn=%d unsup=%d weak=%d mp=%d" % [_W.date_value(), " ".join(ls), M.country_divisions("GER").size(), unsup, lowstr, _W.countries["GER"].recruitable_manpower() if _W.countries["GER"].has_method("recruitable_manpower") else -1])
	var fl: Array = []
	for t in ["GER", "ITA", "JAP", "SOV", "ENG", "FRA", "USA"]:
		var cc = _W.countries[t]
		fl.append("%s=%d/%d" % [t, cc.fuel, cc.fuel_cap])
	print("FUEL %d %s" % [_W.date_value(), " ".join(fl)])
	var al: Array = []
	for a in M.armies:
		if a.owner in ["GER", "FRA", "ENG"]:
			var dv: Array = M.army_divisions(a)
			var fp: Array = M.front_provinces(a)
			al.append("%s>%s:%s n=%d front=%d" % [a.owner, a.enemy, "ATK" if a.mode == 1 else "HOLD", dv.size(), fp.size()])
	print("ARMIES %d %s" % [_W.date_value(), " | ".join(al)])
	print("FRONT %d GER west=%d east=%d | FRA+ENG front=%d sea=%d | GER lost=%s | FRA states held by GER=%d" % [_W.date_value(), gw, ge, al_w, al_sea, str(lost.slice(0, 8)), gained])

func _on_wars() -> void:
	for w: Dictionary in _D.wars:
		for a: String in w["attackers"]:
			for d: String in w["defenders"]:
				var k := "war:%s>%s" % [a, d]
				if not _events.has(k):
					_events[k] = _W.date_value()

func _summary(e: Dictionary) -> String:
	var parts: Array[String] = []
	for tag: String in WATCH:
		if e.has("cap:" + tag):
			parts.append("%s↓%s" % [tag, _fmt(int(e["cap:" + tag]))])
	for k: String in ["war:GER>POL", "war:GER>SOV", "war:JAP>CHI", "war:JAP>USA"]:
		if e.has(k):
			parts.append("%s %s" % [k.substr(4), _fmt(int(e[k]))])
	return ", ".join(parts)

func _fmt(d: int) -> String:
	return "%d-%02d" % [d / 10000, (d / 100) % 100]
