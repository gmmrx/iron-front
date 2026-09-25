extends Node
## Yapay zekâ (oyuncu dışındaki tüm ülkeler).
## Stratejik katman (7 günde bir, ülkeler kademeli): inşaat, üretim, araştırma, odak, yasa, danışman.
## Operasyonel katman (her gün): tümen üretimi, cephe dağılımı, taarruz, savaş ilanı.

const RESEARCH_PRIORITY := {
	"major": ["industry", "infantry", "electronics", "artillery", "doctrine", "air", "armor", "naval"],
	"minor": ["industry", "infantry", "artillery", "electronics", "doctrine", "air", "armor", "naval"],
}
const MAX_ORDERS_PER_DAY := 16

var enabled := true

func _ready() -> void:
	World.daily_update.connect(_on_day)

func reset() -> void:
	pass

func _is_ai(c: Country) -> bool:
	return enabled and c.exists() and not (World.in_game and c.tag == World.player_tag)

func _on_day() -> void:
	var day := World.day_count
	for c: Country in World.countries.values():
		if not _is_ai(c):
			continue
		var t0 := Time.get_ticks_usec()
		if (day + c.index) % 7 == 0:
			_strategic(c)
		GameClock.timed("ai_strategic", t0); t0 = Time.get_ticks_usec()
		_military(c)
		GameClock.timed("ai_military", t0)

# ------------------------------------------------------------------ stratejik
func _strategic(c: Country) -> void:
	_construction(c)
	_production(c)
	_research(c)
	_focus(c)
	_laws(c)
	_advisors(c)

func _construction(c: Country) -> void:
	if c.construction_queue.size() >= 3 or Economy.available_civilian(c) <= 0:
		return
	var war_soon := Diplomacy.at_war(c.tag) or World.world_tension > 50.0 or GameClock.year >= 1939
	var want := "military_factory" if war_soon and randf() < 0.6 else "civilian_factory"
	if randf() < 0.15:
		want = "infrastructure"
	if c.is_major() and randf() < 0.08:
		want = "dockyard"
	var sids: Array = c.states.duplicate()
	sids.sort_custom(func(a: int, b: int) -> bool:
		return World.states[a].building_level("infrastructure") * 10 + World.states[a].free_slots() > World.states[b].building_level("infrastructure") * 10 + World.states[b].free_slots())
	for sid in sids:
		var st: StateRegion = World.states[sid]
		if Economy.can_build(c, st, want) == "":
			Economy.queue_building(c, st, want)
			return

func _production(c: Country) -> void:
	var free := Economy.free_military(c)
	if free > 0:
		var shares := {"infantry_equipment": 0.4, "artillery_equipment": 0.15, "support_equipment": 0.08, "fighter_equipment": 0.16,
				"cas_equipment": 0.06, "tactical_bomber_equipment": 0.04}
		if c.is_major():
			var tank := "medium_tank_equipment" if Research.is_unlocked(c, "medium_tank_equipment") else "light_tank_equipment"
			shares[tank] = 0.12
			shares["motorized_equipment"] = 0.05
		# stoğu çok yüksek olanları atla
		for eq: String in shares.keys():
			if not Research.is_unlocked(c, eq):
				shares.erase(eq)
		while free > 0:
			var best := ""
			var worst := INF
			for eq: String in shares:
				var have := 0
				for l in c.production_lines:
					if l.equipment == eq:
						have += l.factories
				var ratio := have / maxf(shares[eq] * Economy.count(c, "military_factory"), 0.01)
				if ratio < worst:
					worst = ratio
					best = eq
			if best == "":
				break
			var line: ProductionLine = null
			for l in c.production_lines:
				if l.equipment == best and l.factories < 15:
					line = l
			if line == null:
				line = Economy.add_line(c, best)
				line.factories = 0
			line.factories += 1
			free -= 1
	var yards := Economy.free_military(c, true)
	if yards > 0:
		# yalnız araştırılmış gemi tipleri
		var opts: Array[String] = []
		for eq: String in ["destroyer", "destroyer", "cruiser", "submarine" if c.tag in ["GER", "ITA", "SOV"] else "cruiser", "battleship"]:
			if Economy.can_produce(c, eq) and (eq != "battleship" or yards >= 10):
				opts.append(eq)
		if not opts.is_empty():
			var line := Economy.add_line(c, opts[randi() % opts.size()])
			line.factories = mini(yards, 15)
	Economy.mark_trade_dirty()

func _research(c: Country) -> void:
	var prio: Array = RESEARCH_PRIORITY["major" if c.is_major() else "minor"]
	var guard := 0
	while c.research_current.size() < c.research_slots and guard < 10:
		guard += 1
		var best := ""
		var best_score := INF
		for id: String in Research.techs:
			if not Research.can_research(c, id):
				continue
			var cat: String = Research.techs[id]["cat"]
			var score := Research.days_needed(c, id) * (1.0 + prio.find(cat) * 0.12)
			if score < best_score:
				best_score = score
				best = id
		if best == "" or not Research.start(c, best):
			break

func _focus(c: Country) -> void:
	var tree := Politics.tree_of(c)
	if c.focus_current != "":
		var cur_ai := float(tree.get(c.focus_current, {}).get("ai", 0))
		if cur_ai >= 40.0:
			return
		var urgent := ""
		for id: String in Politics.tree_order.get(c.tag, []):
			if float(tree[id]["ai"]) >= 40.0 and not id in c.focus_done:
				var cur := c.focus_current
				c.focus_current = ""
				if Politics.can_start_focus(c, id):
					urgent = id
				c.focus_current = cur
				if urgent != "":
					break
		if urgent == "":
			return
		Politics.cancel_focus(c)
	var best := ""
	var best_w := -1.0
	for id: String in Politics.tree_order.get(c.tag, Politics.tree_order["_generic"]):
		if Politics.can_start_focus(c, id):
			var w := float(tree[id]["ai"]) * randf_range(0.8, 1.2)
			if w > best_w:
				best_w = w
				best = id
	if best != "":
		Politics.start_focus(c, best)

func _laws(c: Country) -> void:
	if c.political_power < Economy.law_change_cost + 30.0:
		return
	var war := Diplomacy.at_war(c.tag) or World.world_tension > 60.0
	if not war:
		return
	var order := {"economy": ["civilian_economy", "early_mobilization", "partial_mobilization", "war_economy", "total_mobilization"],
			"conscription": ["disarmed_nation", "volunteer_only", "limited_conscription", "extensive_conscription", "service_by_requirement"]}
	var g := "economy" if randf() < 0.5 else "conscription"
	var cur: int = order[g].find(c.laws[g])
	var limit := 3 if not Diplomacy.at_war(c.tag) else 4
	if cur >= 0 and cur < mini(limit, order[g].size() - 1):
		Economy.change_law(c, g, order[g][cur + 1])

func _advisors(c: Country) -> void:
	if c.political_power < 250.0 or c.advisors.size() >= Politics.max_advisors:
		return
	for id: String in ["silent_workhorse", "armaments_organizer", "research_director", "army_chief", "captain_of_industry"]:
		if Politics.can_hire(c, id):
			Politics.hire(c, id)
			return

# ------------------------------------------------------------------ askeri
func _military(c: Country) -> void:
	_recruit(c)
	_declare(c)
	var at_war := Diplomacy.at_war(c.tag)
	if not at_war and (World.day_count + c.index) % 5 != 0:
		return
	var fronts := _fronts(c)
	if fronts.is_empty():
		if at_war:
			_invade(c)
		return
	# büyük güçler savaşta cephe orduları kullanır (oyuncuyla aynı sistem): konuşlanma + taarruz ordu işi;
	# orduya girmeyen tümenler sınır/anavatan garnizonu olarak dağılır
	if at_war and c.is_major() and USE_AI_ARMIES:
		_ai_armies(c)
		if (World.day_count + c.index) % 2 == 0:
			_assign(c, fronts)
		return
	_release_armies(c)
	if (World.day_count + c.index) % 2 == 0:
		_assign(c, fronts)
	if at_war:
		_attack(c)

# ------------------------------------------------------------------ cephe orduları (AI)
const ARMY_PLAN_DAYS := 7
const USE_AI_ARMIES := false       ## deney: AI büyük güçler cephe ordusu yerine eski konuşlanma+taarruz yolunu kullanır
const PHONEY_ARMY_DAYS := 270      ## demokrasi orduları savaşın ilk 9 ayında savunmada
const ARMY_ATTACK_RATIO := 1.0

## Haftalık plan: düşman başına bir ordu; tümenler cephe uzunluğu + düşman gücüne göre paylaştırılır,
## fazlası olan ordudan eksiği olana en yakın tümenler geçer; güçlüysek taarruz, değilsek savun
func _ai_armies(c: Country) -> void:
	var mine: Array[Army] = []
	for a in Military.armies:
		if a.owner == c.tag:
			mine.append(a)
	if not mine.is_empty() and (World.day_count + c.index) % ARMY_PLAN_DAYS != 0:
		return
	var plans := {}                 # düşman -> {front, foe, w}
	var wsum := 0.0
	# aynı cephe tek ordu: müttefik düşmanların cepheleri çakışır (İngiltere cephesi = Fransa sınırı); en geniş cepheden
	# başlayıp büyük ölçüde (%50+) önceki bir cepheyle örtüşen düşman ayrı ordu almaz
	var cands: Array = []
	for e in Diplomacy.enemies_of(c.tag):
		var t0 := Army.new()
		t0.owner = c.tag
		t0.enemy = e
		var fp0 := Military.front_provinces(t0)
		if not fp0.is_empty():
			cands.append([fp0.size(), e, fp0])
	cands.sort_custom(func(x: Array, y: Array) -> bool: return x[0] > y[0])
	var covered := {}
	for cand: Array in cands:
		var e: String = cand[1]
		var fp: Array = cand[2]
		var overlap := 0
		for pid: int in fp:
			if covered.has(pid):
				overlap += 1
		if overlap * 2 > fp.size():
			continue
		for pid: int in fp:
			covered[pid] = true
		var t := Army.new()
		t.owner = c.tag
		t.enemy = e
		var foe := 0.0
		var foe_n := 0
		var seen := {}
		for pid in fp:
			for n in World.land_neighbors(pid):
				if seen.has(n) or not Military._is_target_pid(t, n):
					continue
				seen[n] = true
				var ed := Military.enemies_in(n, c.tag)
				foe_n += ed.size()
				foe += _local_power(ed)
		var w := fp.size() * 0.6 + foe_n
		plans[e] = {"front": fp, "foe": foe, "w": w}
		wsum += w
	# geçersiz orduları kapat
	for a in mine.duplicate():
		if not plans.has(a.enemy):
			Military.disband_army(a)
			mine.erase(a)
	if plans.is_empty():
		return
	var by_enemy := {}
	for a in mine:
		by_enemy[a.enemy] = a
	for e: String in plans:
		if not by_enemy.has(e):
			var na := Military.create_army(c.tag, [])
			na.enemy = e
			by_enemy[e] = na
	# havuz: eğitimde / denizde olmayan tümenler; başkentte bir garnizon kalır
	var cap := World.capital_province(c.tag)
	var kept_cap := false
	var pool: Array[Division] = []
	for d in Military.country_divisions(c.tag):
		if d.training > 0 or not World.province(d.province).is_land():
			continue
		if not kept_cap and d.province == cap and d.army == 0:
			kept_cap = true
			continue
		pool.append(d)
	var n := pool.size()
	var budget := {}
	for e: String in plans:
		var share := maxi(1, roundi(float(n) * float(plans[e]["w"]) / maxf(wsum, 0.001)))
		# tavan: küçük cepheye koca ordu yok (1 bölgelik Arnavutluk cephesine 138 tümen gitmişti);
		# cephe uzunluğunun 1,5 katı ya da karşıdaki tümenlerin 2 katı + 4
		var fp_n: int = (plans[e]["front"] as Array).size()
		var foe_n := 0
		var seen_n := {}
		for pid: int in plans[e]["front"]:
			for nb in World.land_neighbors(pid):
				if not seen_n.has(nb) and Diplomacy.are_enemies(World.controller_tag(nb), c.tag):
					seen_n[nb] = true
					foe_n += Military.enemies_in(nb, c.tag).size()
		budget[e] = mini(share, maxi(4, maxi(ceili(fp_n * 1.5), foe_n * 2)))
	var members := {}
	for e: String in by_enemy:
		members[e] = []
	var free: Array[Division] = []
	for d in pool:
		var a: Army = Military.army_by_id(d.army) if d.army > 0 else null
		if a and a.owner == c.tag and members.has(a.enemy):
			members[a.enemy].append(d)
		else:
			free.append(d)
	# fazlalık: cepheye en uzak olanlar serbest kalır
	for e: String in members:
		var arr: Array = members[e]
		var centroid := _centroid(plans[e]["front"])
		arr.sort_custom(func(x: Division, y: Division) -> bool:
			return World.province(x.province).center.distance_squared_to(centroid) < World.province(y.province).center.distance_squared_to(centroid))
		while arr.size() > int(budget[e]):
			var d: Division = arr.pop_back()
			if d.in_combat or d.attacking > 0:
				arr.push_front(d)
				break
			d.army = 0
			free.append(d)
	# eksik: en yakın serbest tümenler katılır
	for e: String in members:
		var arr: Array = members[e]
		var a: Army = by_enemy[e]
		var centroid := _centroid(plans[e]["front"])
		free.sort_custom(func(x: Division, y: Division) -> bool:
			return World.province(x.province).center.distance_squared_to(centroid) < World.province(y.province).center.distance_squared_to(centroid))
		while arr.size() < int(budget[e]) and not free.is_empty():
			var d: Division = free.pop_front()
			d.army = a.id
			arr.append(d)
		# duruş: cephedeki düşmandan belirgin güçlüysek taarruz; "garip savaş": demokrasiler savaşın ilk 9 ayında
		# taarruza kalkmaz (1939'da Fransa boş Ruhr'a yürüyüp Almanya'yı Ekim'de teslim ettiriyordu)
		var power := _local_power(arr)
		var phoney := c.ideology == "democratic" and Diplomacy.days_at_war(c.tag) < PHONEY_ARMY_DAYS
		# demokrasiler temkinli: ancak belirgin üstünlükte (1,5×) taarruz eder (Fransa 1940'ta Almanya'ya saldırmasın)
		var ratio := ARMY_ATTACK_RATIO * (1.5 if c.ideology == "democratic" else 1.0)
		a.mode = Army.Mode.ATTACK if power >= float(plans[e]["foe"]) * ratio and not phoney else Army.Mode.HOLD

func _centroid(pids: Array) -> Vector2:
	var sum := Vector2.ZERO
	for pid: int in pids:
		sum += World.province(pid).center
	return sum / maxf(pids.size(), 1)

## Barışa dönen AI ülkesinin orduları kapanır (eski konuşlanma mantığı devralır)
func _release_armies(c: Country) -> void:
	if c.tag == World.player_tag:
		return
	for a in Military.armies.duplicate():
		if a.owner == c.tag:
			Military.disband_army(a)

## Kara cephesi yoksa: düşmanın en yakın kıyı bölgesine denizden çıkarma
func _invade(c: Country) -> void:
	if (World.day_count + c.index) % 10 != 0 or not Military.can_use_sea(c.tag):
		return
	var home := World.province(World.capital_province(c.tag)).center
	var best := 0
	var best_d := INF
	var cands := PackedInt32Array()
	for t: String in Diplomacy.enemies_of(c.tag):
		cands.append_array(_controlled(World.countries[t].index))
	for pid in cands:
		var p := World.province(pid)
		if not p.coastal:
			continue
		var dd := home.distance_to(p.center) + Military.enemies_in(pid, c.tag).size() * 400.0
		if dd < best_d:
			best_d = dd
			best = pid
	if best == 0:
		return
	var sent := 0
	var divs := Military.country_divisions(c.tag)
	for d in divs:
		if sent >= maxi(divs.size() / 2, 1):
			break
		if d.is_moving() or d.training > 0 or d.in_combat:
			continue
		if Military.order_move(d, best):
			sent += 1

const ARMY_FOCUS := {"ENG": 0.5, "USA": 0.6}

func _target_divisions(c: Country) -> int:
	var t := 6 + Economy.count(c, "military_factory") * 2 + int(c.manpower_pop / 3_000_000)
	if Diplomacy.at_war(c.tag) or World.world_tension > 60.0:
		t = int(t * 1.3)
	# deniz gücü ağırlıklı ülkeler küçük kara ordusu tutar (İngiltere 1939'da ~30 tümen)
	t = int(t * float(ARMY_FOCUS.get(c.tag, 1.0)))
	t = mini(t, 160)
	return t

func _recruit(c: Country) -> void:
	var divs := Military.country_divisions(c.tag)
	var have := divs.size()
	var target := _target_divisions(c)
	# mevcut tümenler dolmadan yenisi kurulmaz: sanayinin donatamayacağı kadar tümen hepsini yarı güçte
	# bırakıyordu (1940 Mayıs: Almanya 151 tümen, 72'si <%50 güç → taarruz edemedi)
	if have >= 12:
		var str_sum := 0.0
		for d in divs:
			str_sum += d.strength
		if str_sum / float(have) < 0.8:
			return
	var n := 0
	while have < target and n < 2:
		var ti := 0
		if c.is_major() and have % 6 == 5 and Military.deploy_shortfall(c, 1).is_empty():
			ti = 1
		if Military.deploy(c, ti) == null:
			break
		have += 1
		n += 1

func _declare(c: Country) -> void:
	if c.ideology == "democratic" and not Diplomacy.at_war(c.tag):
		return
	for t: String in c.war_goals.keys():
		var tc: Country = World.countries.get(t)
		if tc == null or not tc.exists():
			c.war_goals.erase(t)
			continue
		if c.ideology == "neutrality" and (tc.is_major() or _army_power(c.tag) < _army_power(t) * 1.5):
			continue
		if _army_power(c.tag) >= _army_power(t) * 0.7:
			Diplomacy.declare_war(c.tag, t)

func _army_power(tag: String) -> float:
	var p := 0.0
	for d in Military.country_divisions(tag):
		p += d.strength * (1.0 + Military.div_stats(d)["soft"] / 100.0)
	return p

var _owned_day := -1
var _owned := {}      ## ülke indeksi -> PackedInt32Array (kontrol edilen kara bölgeleri)

func _controlled(ci: int) -> PackedInt32Array:
	if _owned_day != World.day_count:
		_owned.clear()
		_owned_day = World.day_count
		var ctl := World.controller
		for pid in range(1, ctl.size()):
			var k := ctl[pid]
			if k > 0:
				if not _owned.has(k):
					_owned[k] = PackedInt32Array()
				_owned[k].append(pid)
	return _owned.get(ci, PackedInt32Array())

## Cephe: kendimizin/müttefiklerin kontrolündeki, düşman (ya da gerekçe hedefi) bölgesine komşu kara bölgeleri
func _fronts(c: Country) -> Dictionary:
	var hostile := Diplomacy.enemies_of(c.tag)
	var planned := false
	if hostile.is_empty():
		for t: String in c.war_goals:
			hostile.append(t)
			planned = true
	if hostile.is_empty():
		return {}
	var hostile_idx := {}
	for t: String in hostile:
		hostile_idx[World.countries[t].index] = true
	var fronts := {}        # pid -> tehdit
	var sources: Array[int] = [c.index]
	if not planned:
		for o: Country in World.countries.values():
			if o != c and o.exists() and Diplomacy.are_allies(o.tag, c.tag):
				sources.append(o.index)
	var ctl := World.controller
	# ana taarruz noktası (Schwerpunkt): düşman başına, arkası değerli ama savunması zayıf 2 kendi cephe bölgemiz
	var spear := {}          # düşman indeksi -> [[puan, pid], ...]
	for ci in sources:
		for pid in _controlled(ci):
			var threat := 0.0
			for n in World.land_neighbors(pid):
				if hostile_idx.has(ctl[n]):
					var foes := Military.enemies_in(n, c.tag).size()
					threat += 1.0 + foes * 2.0
					if ci == c.index and not planned:
						var city := World.province(n).city
						var value := 1.0 + (city.victory_points if city else 0) * 0.5
						var sc := value / (1.0 + foes * 1.5)
						var k: int = ctl[n]
						if not spear.has(k):
							spear[k] = []
						spear[k].append([sc, pid])
			if threat > 0.0:
				fronts[pid] = threat
	for k: int in spear:
		var arr: Array = spear[k]
		arr.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
		for i in mini(2, arr.size()):
			var pid: int = arr[i][1]
			fronts[pid] = float(fronts.get(pid, 1.0)) * 6.0
	return fronts

## Dost toprak (kendi/müttefik/geçiş izni) bağlı bileşen etiketleri: pid -> bileşen no (günlük önbellek)
var _comp_cache := {}
var _comp_day := -1

func _components(tag: String) -> Dictionary:
	if _comp_day != World.day_count:
		_comp_cache.clear()
		_comp_day = World.day_count
	if _comp_cache.has(tag):
		return _comp_cache[tag]
	var fm := Military.friendly_mask(tag)
	var ctl := World.controller
	var comp := {}
	var next_id := 0
	for pid in range(1, ctl.size()):
		if comp.has(pid) or ctl[pid] == 0 or fm[ctl[pid]] == 0:
			continue
		var p := World.province(pid)
		if p == null or not p.is_land():
			continue
		next_id += 1
		comp[pid] = next_id
		var stack: Array[int] = [pid]
		while not stack.is_empty():
			var cur: int = stack.pop_back()
			var nb: Array = Array(World.land_neighbors(cur))
			nb.append_array(Array(World.province(cur).strait_adjacent))
			for n: int in nb:
				if comp.has(n) or fm[ctl[n]] == 0:
					continue
				comp[n] = next_id
				stack.append(n)
	_comp_cache[tag] = comp
	return comp

func _assign(c: Country, fronts: Dictionary) -> void:
	var own := {}
	for pid: int in fronts:
		own[pid] = 0
	var idle: Array[Division] = []
	for d in Military.country_divisions(c.tag):
		if d.training > 0 or d.attacking > 0 or d.in_combat or d.army > 0:
			continue
		if fronts.has(d.province):
			own[d.province] = int(own[d.province]) + 1
			if int(own[d.province]) <= 3:
				continue
		if d.is_moving():
			if fronts.has(d.path[d.path.size() - 1]):
				own[d.path[d.path.size() - 1]] = int(own.get(d.path[d.path.size() - 1], 0)) + 1
			continue
		idle.append(d)
	# başkent garnizonu
	var cap := World.capital_province(c.tag)
	if not idle.is_empty() and Military.divisions_in(cap).filter(func(x: Division) -> bool: return x.owner == c.tag).is_empty():
		idle.pop_back()
	var orders := 0
	var comp := _components(c.tag)
	var fails := 0
	for d in idle:
		if orders >= MAX_ORDERS_PER_DAY or fails >= 3:
			break
		var best := 0
		var best_score := INF
		var here := World.province(d.province).center
		var my_comp: int = comp.get(d.province, -1)
		for pass_i in 2:
			for pid: int in fronts:
				# önce yalnız dost topraktan ulaşılabilen cepheler (aynı bileşen); yoksa deniz yolu
				if pass_i == 0 and my_comp >= 0 and int(comp.get(pid, -2)) != my_comp:
					continue
				var score := (float(own[pid]) + 1.0) / float(fronts[pid]) + here.distance_to(World.province(pid).center) / 4000.0
				# boş cephe bölgesi önce: her sınır bölgesinde en az bir tümen (garnizon)
				if int(own[pid]) == 0:
					score -= 10.0
				if score < best_score:
					best_score = score
					best = pid
			if best > 0:
				break
		# konuşlanma rotası düşman toprağından geçmez
		if best > 0 and best != d.province and Military.order_move(d, best, true):
			own[best] = int(own[best]) + 1
			orders += 1
		elif best > 0:
			fronts.erase(best)
			fails += 1

func _local_power(divs: Array) -> float:
	var p := 0.0
	for d: Division in divs:
		var s := Military.div_stats(d)
		p += (s["soft"] + s["defense"] * 0.5) * d.strength * (d.org / maxf(s["org"], 1.0))
	return p

## "Garip Savaş": demokrasiler savaşın ilk 8 ayında düşman anavatanına taarruz etmez,
## yalnız kendi / müttefik toprağını geri alır (türün klasiklerinde 1939-40 müttefik AI'ı gibi)
const PHONEY_WAR_DAYS := 270          ## demokrasiler ilk 9 ay yalnız kendi/müttefik toprağını geri alır

## Demokrasiler sağlam bir büyük gücün anavatanına taarruz etmez (tarihte Müttefikler ancak Almanya çökerken
## saldırdı); düşman teslim ilerlemesi ≥ 0,4 olunca ya da 1942'den sonra serbest
func _cautious_vs_major(c: Country, enemy_tag: String) -> bool:
	if c.ideology != "democratic" or World.date_value() >= 19420101:
		return false
	var e: Country = World.countries.get(enemy_tag)
	return e != null and e.is_major() and e.surrender_progress < 0.4

func _flank_safe(tag: String, target: int, from: int) -> bool:
	var city := World.province(target).city
	if city and city.is_capital:
		return true
	for m in World.land_neighbors(target):
		if m == from:
			continue
		var ctl := World.controller_tag(m)
		if ctl == tag or Diplomacy.are_allies(ctl, tag):
			return true
	return false

func _attack(c: Country) -> void:
	var orders := 0
	var seen := {}
	var phoney := c.ideology == "democratic" and Diplomacy.days_at_war(c.tag) < PHONEY_WAR_DAYS
	for d in Military.country_divisions(c.tag):
		if orders >= MAX_ORDERS_PER_DAY:
			return
		if d.is_moving() or d.training > 0 or seen.has(d.province):
			continue
		seen[d.province] = true
		var here: Array = Military.divisions_in(d.province).filter(func(x: Division) -> bool:
			return x.owner == c.tag and not x.is_moving() and x.training == 0 and x.org > Military.div_stats(x)["org"] * 0.6)
		if here.is_empty():
			continue
		var best := 0
		var best_ratio := 0.0
		for n in World.land_neighbors(d.province):
			var ctl := World.controller_tag(n)
			if not Diplomacy.are_enemies(ctl, c.tag):
				continue
			if phoney or _cautious_vs_major(c, ctl):
				var st := World.state_of_province(n)
				if st == null or not (st.owner == c.tag or Diplomacy.are_allies(st.owner, c.tag)):
					continue
			var foes := Military.enemies_in(n, c.tag)
			# cephe bütünlüğü: hedef bölge, geldiğimiz dışında en az bir dost bölgeye de değmeli (tek başına
			# derine sızan, arkası kesilip yok edilen "parmak" oluşmasın); başkentler istisna
			if not _flank_safe(c.tag, n, d.province):
				continue
			var ratio := _local_power(here) / maxf(_local_power(foes), 1.0)
			if foes.is_empty():
				ratio = 99.0
			var city := World.province(n).city
			if city:
				ratio *= 1.0 + city.victory_points * 0.02
			if ratio > best_ratio:
				best_ratio = ratio
				best = n
		if best == 0 or best_ratio < 1.25:
			continue
		# en az bir tümen savunmada kalsın (tek başına değilse)
		var go := here.size() - (1 if here.size() > 2 else 0)
		if Military.enemies_in(best, c.tag).is_empty():
			go = mini(go, 1)
		for i in go:
			var a: Division = here[i]
			a.path = PackedInt32Array([best])
			a.progress = 0.0
			orders += 1
