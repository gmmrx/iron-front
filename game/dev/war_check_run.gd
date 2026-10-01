extends RefCounted
## war_check.gd'nin gövdesi

func run(_tree: SceneTree, args: Dictionary) -> int:
	var slot := str(args.get("load", "war_demo_watch"))
	if not Game.load_game(slot):
		print("kayıt yok: ", slot)
		return 1
	Game.loaded = false
	Game.observer = true
	World.resume_game(World.player_tag)
	var pair: Array = ["GER", "SOV"]
	if args.has("pair"):
		pair = Array(str(args["pair"]).split(","))
	var days := int(args.get("days", "14"))
	if args.has("until"):
		# kayıttan bu tarihe dek ileri sar (ör. 1940 kaydından Barbarossa'nın ertesine: yığınak ölçülür)
		var tu := Time.get_ticks_msec()
		var until := int(args["until"])
		while World.date_value() < until:
			GameClock.advance_hours(24)
		print("ileri sarıldı: %d (%.0f sn)" % [World.date_value(), (Time.get_ticks_msec() - tu) / 1000.0])
	AI.debug_assign = args.has("assign_dbg")
	if args.has("front"):
		_front_report(pair)
		for t: String in pair:
			var c: Country = World.countries[t]
			var fr: Dictionary = AI._fronts(c)
			var idle := 0
			var in_army := 0
			for d: Division in Military.country_divisions(t):
				if d.army > 0:
					in_army += 1
				elif d.training == 0 and not d.is_moving() and d.attacking == 0:
					idle += 1
			print("     %s: yaklaşan savaş %s, cephe bölgesi (AI) %d, orduda %d, boşta %d, AI mi %s, yapay zekâ açık %s" % [t,
				AI._upcoming_wars(t), fr.size(), in_army, idle, AI._is_ai(c), AI.enabled])
			if args.has("assign_dbg"):
				var ov := Military.order_version
				var it := Military.path_iterations
				AI._no_route.clear()
				AI._assign(c, fr)
				var moving := 0
				for d: Division in Military.country_divisions(t):
					if d.is_moving():
						moving += 1
				print("     %s _assign: emir sürümü +%d, yol adımı %d, yolda %d" % [t, Military.order_version - ov, Military.path_iterations - it, moving])
	var st := {}
	for t: String in pair:
		st[t] = {"orders": 0, "attack_orders": 0, "redeploy": 0, "redeploy_km": 0.0, "long_redeploy": 0, "moves": 0,
			"bounce": 0, "retreat_jump": 0, "front_hours": 0, "front_standing": 0, "moving_hours": 0, "hours": 0,
			"prov0": 0, "prov1": 0, "battles": 0, "won": 0}
	var prev := {}                      # id -> [il, hedef, yolda mı, saldırıyor mu]
	var hist := {}                      # id -> [[saat, il], ...]
	for t: String in pair:
		st[t]["prov0"] = _count_ctl(t)
	var h0 := World.day_count * 24 + GameClock.hour
	var t0 := Time.get_ticks_msec()
	for hour in days * 24:
		GameClock.advance_hours(1)
		var now := World.day_count * 24 + GameClock.hour - h0
		var alive := {}
		for d: Division in Military.divisions:
			if not st.has(d.owner) or d.training > 0 or not World.province(d.province).is_land():
				continue
			alive[d.id] = true
			var s: Dictionary = st[d.owner]
			var dest := d.path[d.path.size() - 1] if not d.path.is_empty() else -1
			var p: Array = prev.get(d.id, [d.province, -1, false, 0])
			if dest != -1 and dest != int(p[1]):
				s["orders"] += 1
				if Diplomacy.are_enemies(World.controller_tag(dest), d.owner) or d.attacking > 0:
					s["attack_orders"] += 1
				else:
					s["redeploy"] += 1
					var km := World.distance_km(d.province, dest) if World.province(dest).is_land() else 0.0
					s["redeploy_km"] += km
					if km > 250.0 and _is_front(d.province, d.owner):
						s["long_redeploy"] += 1        # cepheden kalkıp cephe boyunca uzağa
			if d.province != int(p[0]):
				s["moves"] += 1
				if not bool(p[2]):
					s["retreat_jump"] += 1              # yolu yokken il değişti: geri çekilme (ışınlama)
				var hh: Array = hist.get(d.id, [])
				for e: Array in hh:
					if int(e[1]) == d.province and now - int(e[0]) <= 72:
						s["bounce"] += 1
						break
				hh.append([now, int(p[0])])
				if hh.size() > 6:
					hh.pop_front()
				hist[d.id] = hh
			s["hours"] += 1
			if d.is_moving() and d.attacking == 0:
				s["moving_hours"] += 1
			if _is_front(d.province, d.owner):
				s["front_hours"] += 1
				if not d.is_moving() or d.attacking > 0:
					s["front_standing"] += 1
				elif Diplomacy.are_enemies(World.controller_tag(d.path[0]), d.owner):
					s["front_advance"] = int(s.get("front_advance", 0)) + 1     # düşman bölgesine yürüyor (taarruz/ilerleme)
				elif _is_front(d.path[0], d.owner):
					s["front_shift"] = int(s.get("front_shift", 0)) + 1         # cephe boyunca kayıyor
				else:
					s["front_back"] = int(s.get("front_back", 0)) + 1          # cepheden geriye/içeri
			prev[d.id] = [d.province, dest, d.is_moving(), d.attacking]
		for bp: int in Military.battles:
			var b: Dictionary = Military.battles[bp]
			var ao: String = (b["attackers"][0] as Division).owner
			if st.has(ao):
				st[ao]["battles"] += 1
	for t: String in pair:
		st[t]["prov1"] = _count_ctl(t)
	if args.has("front"):
		_front_report(pair)
	print("WARCHECK %s gün=%d sn=%.1f" % [slot, days, (Time.get_ticks_msec() - t0) / 1000.0])
	for t: String in pair:
		var s: Dictionary = st[t]
		var dd := float(days)
		var n := float(s["hours"]) / (dd * 24.0)
		print("  %s tümen~%d  emir/tümen/gün=%.3f (taarruz %d, konuşlanma %d, ort %.0f km, cepheden uzağa %d)  gidip-dönme=%d  geri çekilme sıçraması=%d  yolda=%.0f%%  cephede duran=%.0f%%  il %d→%d  muharebe-saat=%d" % [
			t, int(n), float(s["orders"]) / maxf(n * dd, 1.0), s["attack_orders"], s["redeploy"],
			float(s["redeploy_km"]) / maxf(float(s["redeploy"]), 1.0), s["long_redeploy"], s["bounce"], s["retreat_jump"],
			100.0 * float(s["moving_hours"]) / maxf(float(s["hours"]), 1.0),
			100.0 * float(s["front_standing"]) / maxf(float(s["front_hours"]), 1.0), s["prov0"], s["prov1"], s["battles"]])
		var fh := maxf(float(s["front_hours"]), 1.0)
		print("     cephede yürüyen: düşmana %.0f%%  cephe boyunca %.0f%%  geriye %.0f%%" % [100.0 * float(s.get("front_advance", 0)) / fh,
			100.0 * float(s.get("front_shift", 0)) / fh, 100.0 * float(s.get("front_back", 0)) / fh])
	return 0

func _is_front(pid: int, tag: String) -> bool:
	for n in World.land_neighbors(pid):
		if Diplomacy.are_enemies(World.controller_tag(n), tag):
			return true
	return false

func _count_ctl(tag: String) -> int:
	var n := 0
	var ci: int = (World.countries[tag] as Country).index
	for c in World.controller:
		if c == ci:
			n += 1
	return n

## Cephe dökümü: iki ülkenin karşılıklı cephe bölgeleri (komşusu öbürünün elinde), tümenlerin cephede / cepheye 1-3
## adım / uzakta / yolda dağılımı, cephe bölgesi başına tümen
func _front_report(pair: Array) -> void:
	for side in 2:
		var me: String = pair[side]
		var foe: String = pair[1 - side]
		var front := {}
		for pid in range(1, World.provinces.size()):
			var p := World.province(pid)
			if p == null or not p.is_land() or World.controller_tag(pid) != me:
				continue
			for n in World.land_neighbors(pid):
				if World.controller_tag(n) == foe:
					front[pid] = true
					break
		# cepheye adım uzaklığı (dost topraktan BFS)
		var depth := {}
		var fr: Array = front.keys()
		for pid: int in fr:
			depth[pid] = 0
		for step in range(1, 4):
			var nxt: Array = []
			for cur: int in fr:
				for n in World.land_neighbors(cur):
					if depth.has(n) or World.controller_tag(n) != me:
						continue
					depth[n] = step
					nxt.append(n)
			fr = nxt
		var at_front := 0
		var near := 0
		var far := 0
		var moving := 0
		var attacking := 0
		var empty_front := 0
		var far_other := 0
		var far_x := 0.0
		var far_y := 0.0
		var occ := {}
		for d: Division in Military.divisions:
			if d.owner != me or d.training > 0 or not World.province(d.province).is_land():
				continue
			if d.attacking > 0:
				attacking += 1
			elif d.is_moving():
				moving += 1
			elif depth.get(d.province, -1) == 0:
				at_front += 1
				occ[d.province] = true
			elif depth.has(d.province):
				near += 1
			else:
				far += 1
				var other := false
				for n in World.land_neighbors(d.province):
					if Diplomacy.are_enemies(World.controller_tag(n), me):
						other = true
						break
				if other:
					far_other += 1
				far_x += World.province(d.province).center.x
				far_y += World.province(d.province).center.y
		for pid: int in front:
			if not occ.has(pid):
				empty_front += 1
		var fc := Vector2.ZERO
		for pid: int in front:
			fc += World.province(pid).center
		fc /= maxf(front.size(), 1)
		print("  CEPHE %s→%s: cephe bölgesi %d (boş %d, orta %s)  tümen: cephede duran %d, 1-3 adım geride %d, uzakta duran %d (başka cephede %d, ortası %s), yolda %d, saldıran %d" % [
			me, foe, front.size(), empty_front, fc.round(), at_front, near, far, far_other, (Vector2(far_x, far_y) / maxf(far, 1)).round(), moving, attacking])
		var goals: Array = (World.countries[me] as Country).war_goals.keys()
		print("     %s düşmanları: %s  savaş hedefleri: %s  savaş günü: %d" % [me, Diplomacy.enemies_of(me), goals, Diplomacy.days_at_war(me)])
