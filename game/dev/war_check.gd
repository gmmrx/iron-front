extends SceneTree
## Oyuncu savaşı: oyuncu (--player) hedefe (--target) savaş açar, bütün tümenlerini hedef şehre (--goal) yollar,
## boşta kalanlara emri yeniler; her 5 günde ele geçen bölge, takılan tümen, muharebe ve gün süresi yazılır.
##   godot --headless --path . -s game/dev/war_check.gd -- --player=GER --target=POL --goal=Warsaw --days=60
func _init() -> void:
	await process_frame
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	var W = root.get_node("World")
	var clock = root.get_node("GameClock")
	var mil = root.get_node("Military")
	var dip = root.get_node("Diplomacy")
	var me: String = args.get("player", "GER")
	var tgt: String = args.get("target", "POL")
	var goal_name: String = args.get("goal", "")
	var days := int(args.get("days", "60"))
	# --start=YYYYMMDD: o güne kadar herkes yapay zekâ (tarih çizelgesi dahil), sonra oyuncu devralır
	if args.has("start"):
		var t0 := Time.get_ticks_msec()
		while W.date_value() < int(args["start"]):
			clock.advance_hours(24)
		print("başlangıç %s (%d sn)" % [clock.date_string(), (Time.get_ticks_msec() - t0) / 1000])
	if args.has("load"):
		root.get_node("Game").load_game(args["load"])
		print("yüklendi ", clock.date_string())
	if args.has("observe"):
		# yalnız izle: herkes yapay zekâ; her 10 günde hedefin teslim ilerlemesi ve işgal edilen bölge
		var tco = W.countries[tgt]
		W.player_tag = ""
		for d in mil.divisions:
			d.hold = false          # kayıt oyuncu devraldıktan sonra alındıysa: yapay zekâ tümenleri geri çekilebilir
		for day in days:
			clock.advance_hours(24)
			if day % 10 == 9:
				var taken := 0
				var total := 0
				var home: String = W.states[tco.capital_state].adm0 if tco.exists() else ""
				for sid in tco.states:
					if W.states[sid].adm0 != home:
						continue
					for pid in W.states[sid].provinces:
						total += 1
						if dip.are_enemies(W.controller_tag(pid), tgt):
							taken += 1
				var ll: Array = []
				for k in mil.loss_log:
					if String(k).begins_with("GER") or String(k).begins_with(tgt):
						ll.append("%s=%d" % [k, mil.loss_log[k]])
				var unsup := 0
				var fuel_out := 0
				for d in mil.country_divisions("GER"):
					if not d.supplied: unsup += 1
					if mil.fuel_malus(d) > 0.0: fuel_out += 1
				print("   kayıp %s | GER ikmalsiz %d, yakıtsız %d, yakıt %.0f" % [" ".join(ll), unsup, fuel_out, W.countries["GER"].fuel])
				print("%s: %s anavatan işgal %d/%d, teslim %.2f/%.2f, savaş %s, %s tümen %d, GER tümen %d" % [clock.date_string(), tgt, taken, total, tco.surrender_progress, dip.capitulation_threshold(tco), str(dip.enemies_of(tgt)), tgt, mil.country_divisions(tgt).size(), mil.country_divisions("GER").size()])
			if not tco.exists() or tco.capitulated:
				print("%s TESLİM (%s)" % [tgt, clock.date_string()])
				break
		quit()
		return
	W.start_game(me)
	clock.prof.clear()
	if args.has("save"):
		root.get_node("Game").save_game(args["save"])
	var declare_on: Array = [tgt]
	if args.has("also"):
		for t in args["also"].split(","):
			declare_on.append(t)
	for t in declare_on:
		if not dip.are_enemies(me, t):
			W.countries[me].war_goals[t] = true
			print("savaş ilanı %s: %s" % [t, dip.declare_war(me, t)])
	print("savaşlar: ", dip.enemies_of(me), "  %s tümen %d, %s tümen %d" % [me, mil.country_divisions(me).size(), tgt, mil.country_divisions(tgt).size()])
	var goal := 0
	for city in W.cities:
		if city.name == goal_name or city.names.values().has(goal_name):
			goal = city.province_id
	if goal == 0:
		goal = W.capital_province(tgt)
	print("hedef bölge ", goal, " ", W.province(goal).center, " sahibi ", W.controller_tag(goal))
	var tc = W.countries[tgt]
	var total_prov := 0
	for sid in tc.states:
		total_prov += W.states[sid].provinces.size()
	var stuck := {}
	# --army: oyuncunun olağan kullanımı — bütün tümenler tek orduda, cephe = hedef ülke, taarruz
	var army = null
	if args.has("army"):
		army = mil.create_army(me, mil.country_divisions(me))
		army.enemy = tgt
		army.mode = 1
		print("ordu: %d tümen, cephe %s, taarruz; cephe bölgesi %d" % [mil.army_divisions(army).size(), tgt, mil.front_provinces(army).size()])
	for day in days:
		var t0 := Time.get_ticks_msec()
		if army == null:
			for d in mil.country_divisions(me):
				if d.path.is_empty() and d.training == 0 and d.province != goal:
					if not mil.order_move(d, goal):
						stuck[d.id] = d.province
		clock.advance_hours(24)
		var ms := Time.get_ticks_msec() - t0
		if day % 5 == 4 or day == days - 1:
			var taken := 0
			for sid in tc.states:
				for pid in W.states[sid].provinces:
					if W.controller_tag(pid) == me:
						taken += 1
			var idle := 0
			var attacking := 0
			var moving := 0
			for d in mil.country_divisions(me):
				if d.attacking > 0: attacking += 1
				elif not d.path.is_empty(): moving += 1
				else: idle += 1
			if army != null:
				var fr = mil.front_provinces(army)
				var at := {}
				for d in mil.army_divisions(army):
					at[d.province] = int(at.get(d.province, 0)) + 1
				var top: Array = at.keys()
				top.sort_custom(func(x, y) -> bool: return at[x] > at[y])
				var tops: Array = []
				for pid in top.slice(0, 4):
					tops.append("%d:%d%s" % [pid, at[pid], "*" if pid in fr else ""])
				print("   ordu cephesi %d bölge %s, orduda %d tümen, yoğun: %s" % [fr.size(), str(fr.slice(0, 6)), mil.army_divisions(army).size(), " ".join(tops)])
			print("   savaşta mı: %s, %s eyaleti %d, kontrol ettiği (GER'den alınmış) %s" % [dip.are_enemies(me, tgt), tgt, tc.states.size(), str(mil.front_provinces(army).map(func(p): return W.controller_tag(p))) if army != null else ""])
			print("%s gün %d: %s bölgesi %d/%d, hedef %s, tümen yürüyen %d saldıran %d boşta %d, yolsuz %d, muharebe %d, teslim %.2f, %d ms/gün" % [
				clock.date_string(), day + 1, tgt, taken, total_prov, W.controller_tag(goal), moving, attacking, idle,
				stuck.size(), mil.battles.size(), tc.surrender_progress, ms])
			if not stuck.is_empty():
				var ex: Array = []
				for id in stuck.keys().slice(0, 4):
					var pid: int = stuck[id]
					ex.append("%d@%d(%s)" % [id, pid, W.controller_tag(pid)])
				print("   yol bulunamayan örnek: ", ex)
			stuck.clear()
		if not tc.exists():
			print("%s TESLİM / YOK OLDU (%s)" % [tgt, clock.date_string()])
			break
	if OS.has_environment("PATHDBG"):
		var ks: Array = mil.path_stats.keys()
		ks.sort_custom(func(a, b) -> bool: return mil.path_stats[a].y > mil.path_stats[b].y)
		for k in ks.slice(0, 15):
			print("  path %-22s çağrı %5d  adım %8d  ort %d" % [k, mil.path_stats[k].x, mil.path_stats[k].y, mil.path_stats[k].y / maxi(mil.path_stats[k].x, 1)])
	if args.has("prof"):
		var keys: Array = clock.prof.keys()
		keys.sort_custom(func(a, b) -> bool: return clock.prof[a] > clock.prof[b])
		for k in keys:
			print("  prof %-22s %7.2f sn" % [k, clock.prof[k] / 1e6])
	quit()
