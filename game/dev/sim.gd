extends SceneTree
## Headless simülasyon testi: godot --headless --path . -s game/dev/sim.gd -- --days=1200 [--player=TUR]
## Sorun bulursa 1 ile çıkar: motor/betik hatası, gün sayacı kayması, tümen/ülke değerlerinde NaN/sonsuz ya da aralık dışı değer.
func _init() -> void:
	var catcher: Logger = preload("res://game/dev/error_catcher.gd").new()
	OS.add_logger(catcher)
	await process_frame
	var days := 1200
	var player := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--days="): days = int(a.substr(7))
		if a.begins_with("--player="): player = a.substr(9)
	var W = root.get_node("World")
	var clock = root.get_node("GameClock")
	var mil = root.get_node("Military")
	var dip = root.get_node("Diplomacy")
	if player != "":
		W.start_game(player)
	W.notification.connect(func(t: String, k: String) -> void:
		if k == "war" or t.contains("ilhak") or t.contains("teslim"):
			print("  [%04d-%02d-%02d] %s" % [clock.year, clock.month, clock.day, t]))
	var watch: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--watch="): watch = a.substr(8).split(",")
	var t0 := Time.get_ticks_msec()
	var day0: int = W.day_count
	for day in days:
		clock.advance_hours(24)
		W.flush_ownership()
		if not watch.is_empty() and dip.wars.size() > 0 and day % 5 == 0:
			var line := "  %d-%02d-%02d" % [clock.year, clock.month, clock.day]
			for t in watch:
				var c = W.countries.get(t)
				if c == null: continue
				var ds = mil.country_divisions(t)
				var st := 0.0
				var og := 0.0
				var sup := 0
				var fights := 0
				for d in ds:
					st += d.strength
					og += d.org / max(mil.div_stats(d)["org"], 1.0)
					if d.supplied: sup += 1
					if d.in_combat: fights += 1
				var prov := 0
				for pid in range(1, W.controller.size()):
					if W.controller[pid] == c.index: prov += 1
				line += " | %s d=%d s=%.2f o=%.2f sup=%d cmb=%d prov=%d sur=%.2f" % [t, ds.size(), st / max(ds.size(), 1), og / max(ds.size(), 1), sup, fights, prov, c.surrender_progress]
			print(line)
		if day % 180 == 0:
			var n: int = mil.divisions.size()
			print("[%d-%02d] tümen=%d savaş=%d gerginlik=%.0f  (%.1f sn)" % [clock.year, clock.month, n, dip.wars.size(), W.world_tension, (Time.get_ticks_msec() - t0) / 1000.0])
	print("--- sonuç ---")
	var rows := []
	for c in W.countries.values():
		if c.exists():
			rows.append([c.tag, c.states.size(), mil.country_divisions(c.tag).size(), c.focus_done.size(), c.research_done.size()])
	rows.sort_custom(func(a, b): return a[1] > b[1])
	for r in rows.slice(0, 16):
		print("%s eyalet=%d tümen=%d odak=%d tekno=%d" % r)
	print("yok olanlar: ", W.countries.values().filter(func(c): return not c.exists()).map(func(c): return c.tag))
	var prof: Dictionary = clock.prof
	for k in prof: print("  profil %s: %.1f sn" % [k, prof[k] / 1e6])
	print("toplam süre %.1f sn" % ((Time.get_ticks_msec() - t0) / 1000.0))
	# --- denetimler
	var problems: Array[String] = []
	if W.day_count - day0 != days:
		problems.append("gün sayacı %d ilerledi, beklenen %d" % [W.day_count - day0, days])
	var bad_divs := 0
	for d in mil.divisions:
		if not (is_finite(d.strength) and is_finite(d.org) and d.strength >= 0.0 and d.strength <= 1.0 and d.org >= 0.0):
			bad_divs += 1
	if bad_divs > 0:
		problems.append("%d tümende geçersiz güç/organizasyon" % bad_divs)
	for c in W.countries.values():
		if not c.exists():
			continue
		if not is_finite(c.political_power) or not is_finite(c.stability) or not is_finite(c.war_support):
			problems.append("%s: siyasi güç/istikrar/savaş desteği sayı değil" % c.tag)
		for e: String in c.stockpile:
			if not is_finite(float(c.stockpile[e])):
				problems.append("%s: %s stoğu sayı değil" % [c.tag, e])
	if not is_finite(W.world_tension) or W.world_tension < 0.0 or W.world_tension > 100.0:
		problems.append("dünya gerginliği aralık dışı: %s" % W.world_tension)
	for e in catcher.take():
		problems.append("motor/betik hatası: " + e)
	print("== sim: %d sorun ==" % problems.size())
	for p in problems:
		print("  SORUN " + p)
	OS.remove_logger(catcher)
	catcher = null
	quit(1 if not problems.is_empty() else 0)
