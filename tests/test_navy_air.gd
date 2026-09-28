extends "res://tests/test_case.gd"
## Deniz ve hava: filo görevi ve dönüş, deniz muharebesi, konvoy baskını; kanat konuşlandırma, oyuncu kanadının
## otomatik kapalı başlaması, hava üstünlüğünün kara muharebesine etkisi. Oyuncu Almanya.

func player_tag() -> String:
	return "GER"

func _war(a: String, b: String) -> void:
	country(a).war_goals[b] = true
	Diplomacy.declare_war(a, b)

func _surface_fleet(tag: String) -> Fleet:
	for f in Navy.fleets_of(tag):
		if not f.is_sub_fleet() and not f.reserve and f.total() > 0:
			return f
	return null

func _sub_fleet(tag: String) -> Fleet:
	for f in Navy.fleets_of(tag):
		if f.is_sub_fleet():
			return f
	return null

# ------------------------------------------------------------------ donanma
func test_fleet_mission_and_return() -> void:
	var f := _surface_fleet("GER")
	if not check(f != null, "Almanya'nın su üstü filosu"):
		return
	check(f.in_port(), "filo limanda başlar")
	var home := f.home
	var zc := Navy.sea_for(home)
	Navy.set_mission(f, Fleet.Mission.SUPERIORITY, zc)
	check(f.is_moving() or Navy.in_zone(zc, f.location), "görev emriyle filo yola çıkar")
	for h in 24 * 10:
		GameClock.advance_hours(1)
		if Navy.in_zone(zc, f.location):
			break
	check(Navy.in_zone(zc, f.location), "filo görev bölgesine varır")
	check(not f.in_port(), "görevdeki filo denizde")
	Navy.set_mission(f, Fleet.Mission.PORT)
	for h in 24 * 10:
		GameClock.advance_hours(1)
		if f.location == home and not f.is_moving():
			break
	eq(f.location, home, "limana dönüş emriyle üsse döner")
	check(f.in_port(), "filo yeniden limanda")

func test_naval_battle_damages_both_sides() -> void:
	_war("GER", "ENG")
	var g := _surface_fleet("GER")
	var e := _surface_fleet("ENG")
	if not check(g != null and e != null, "iki tarafın filosu"):
		return
	var sea := Navy.sea_for(g.home)
	for f in [g, e]:
		f.location = sea
		f.path = PackedInt32Array()
		f.mission = Fleet.Mission.SUPERIORITY
		f.zone_center = sea
		f.org = 1.0
	var g_ships := g.total()
	var e_ships := e.total()
	seed(3)
	for h in 6:
		Navy._combat()
	check(Navy.battles.has(sea), "deniz muharebesi kaydı")
	lt(g.org, 1.0, "Alman filosu organizasyon kaybeder")
	lt(e.org, 1.0, "İngiliz filosu organizasyon kaybeder")
	var g_dmg := 0.0
	for t: String in g.damage:
		g_dmg += float(g.damage[t])
	check(g_dmg > 0.0 or g.total() < g_ships, "Alman filosu hasar alır")
	# güçlü taraf daha az organizasyon kaybeder
	var weaker := g if Navy.fleet_power(g) < Navy.fleet_power(e) else e
	var stronger := e if weaker == g else g
	check(weaker.org <= stronger.org, "zayıf filo daha çok organizasyon kaybeder (%.2f / %.2f)" % [weaker.org, stronger.org])
	# organizasyonu biten filo üsse çekilir
	weaker.org = 0.0
	Navy._combat()
	check(weaker.returning, "organizasyonu biten filo geri çekilir")
	check(weaker.is_moving() or weaker.location == weaker.home, "üssüne yönelir")
	check(g.total() <= g_ships and e.total() <= e_ships, "muharebede gemi sayısı artmaz")

func test_submarines_raid_convoys() -> void:
	_war("GER", "ENG")
	var subs := _sub_fleet("GER")
	if not check(subs != null, "Almanya'nın denizaltı filosu"):
		return
	# İngiliz limanı önünde baskın bölgesi
	var port := 0
	for pid in Navy.ports_of("ENG"):
		if World.province(pid).lonlat.x > -6.0 and World.province(pid).lonlat.y > 49.0 and World.province(pid).lonlat.y < 56.0:
			port = pid
			break
	if not check(port > 0, "Britanya limanı"):
		return
	var zc := Navy.sea_for(port)
	subs.location = zc
	subs.path = PackedInt32Array()
	subs.mission = Fleet.Mission.RAID
	subs.zone_center = zc
	subs.returning = false
	var eng := country("ENG")
	eng.stockpile["convoy"] = 500.0
	seed(11)
	for i in 10:
		Navy._raid_convoys()
	lt(float(eng.stockpile["convoy"]), 500.0, "denizaltılar düşman konvoyu batırır")
	gt(float(Navy.convoy_losses.get("ENG", 0.0)), 0.0, "konvoy kaybı kaydı")
	# barışta baskın yok
	var fra := country("FRA")
	var before := float(fra.stockpile.get("convoy", 0.0))
	Navy._raid_convoys()
	if not Diplomacy.are_enemies("GER", "FRA"):
		eq(float(fra.stockpile.get("convoy", 0.0)), before, "savaşta olunmayan ülkenin konvoyu batmaz")

# ------------------------------------------------------------------ hava
func test_player_wings_manual_ai_wings_auto() -> void:
	var bad: Array = []
	for w in Air.wings:
		if w.owner == "GER" and w.auto:
			bad.append(w.name)
		if w.owner != "GER" and not w.auto:
			bad.append("%s %s" % [w.owner, w.name])
	none(bad, "oyuncu kanadı otomatik kapalı, AI kanadı açık başlamalı")
	# oyuncunun ürettiği uçaklar stokta bekler (kendiliğinden kanada dönüşmez)
	var ger := country("GER")
	var eq_name: String = Air.TYPES["fighter"]["eq"]
	var wings0 := Air.wings_of("GER").size()
	ger.stockpile[eq_name] = float(ger.stockpile.get(eq_name, 0.0)) + 300.0
	var stock := float(ger.stockpile[eq_name])
	Air._absorb(ger)
	eq(Air.wings_of("GER").size(), wings0, "oyuncu için kanat kendiliğinden kurulmaz")
	eq(float(ger.stockpile[eq_name]), stock, "uçaklar stokta kalır")

func test_wing_deploy() -> void:
	var ger := country("GER")
	var eq_name: String = Air.TYPES["fighter"]["eq"]
	ger.stockpile[eq_name] = 250.0
	var bases := Air.bases_of("GER")
	if not check(not bases.is_empty(), "Almanya'nın hava üssü"):
		return
	var w: AirWing = Air.deploy(ger, "fighter", bases[0])
	if not check(w != null, "kanat konuşlanır"):
		return
	eq(w.planes, Air.WING_SIZE, "kanat 100 uçak")
	eq(float(ger.stockpile[eq_name]), 150.0, "uçaklar stoktan düşer")
	check(not w.auto, "oyuncunun yeni kanadı otomatik değil")
	eq(w.base, bases[0], "seçilen üste")
	check(Air.deploy(ger, "fighter", country("POL").capital_state) == null, "başka ülkenin eyaletine konuşlanmaz")
	Air.disband(w)
	eq(float(ger.stockpile[eq_name]), 250.0, "dağıtılan kanadın uçakları stoğa döner")

func test_air_superiority_affects_land_combat() -> void:
	_war("GER", "POL")
	GameClock.month = 5
	for w in Air.wings.duplicate():
		Air.wings.erase(w)                     # yalnız testin kanatları
	Air._bonus_cache.clear()
	var ger := country("GER")
	var pol := country("POL")
	# sınır: Alman bölgesinden Polonya bölgesine
	var src := 0
	var dst := 0
	for pid in range(1, World.provinces.size()):
		var p := World.province(pid)
		if p and p.is_land() and World.controller_tag(pid) == "GER":
			for n in World.land_neighbors(pid):
				if World.controller_tag(n) == "POL":
					src = pid
					dst = n
		if src > 0:
			break
	if not check(src > 0, "sınır bölgesi"):
		return
	var d: Division = Military._create(ger, 0, src, 1.0, 0)
	var base_mod := Military.attack_mod(d, dst)
	ger.stockpile[Air.TYPES["fighter"]["eq"]] = 500.0
	pol.stockpile[Air.TYPES["fighter"]["eq"]] = 500.0
	var gw: AirWing = Air.deploy(ger, "fighter", Air._home_base("GER"))
	if not check(gw != null and Air.set_mission(gw, AirWing.Mission.SUPERIORITY, dst), "Alman avcıları hedef bölgede"):
		return
	near(Air.bonus(dst, "GER"), 0.25, 0.0001, "tam hava üstünlüğü +%25")
	near(Military.attack_mod(d, dst) - base_mod, 0.25, 0.0001, "hava üstünlüğü saldırı çarpanına eklenir")
	near(Air.bonus(dst, "POL"), -0.25, 0.0001, "düşman hava üstünlüğü −%25")
	var pw: AirWing = Air.deploy(pol, "fighter", Air._home_base("POL"))
	if check(pw != null and Air.set_mission(pw, AirWing.Mission.SUPERIORITY, dst), "Polonya avcıları da bölgede"):
		near(Air.bonus(dst, "GER"), 0.0, 0.0001, "eşit hava gücünde bonus yok")

## Seçili filonun tahmini varışı (bölge kartında): gerçek seyirle uyuşur
func test_fleet_eta_matches_voyage() -> void:
	var f := _surface_fleet("GER")
	if not check(f != null, "Alman su üstü filosu"):
		return
	var target := 0
	var near := Navy.sea_for(f.home)
	for n: int in World.province(near).adjacent:
		var q := World.province(n)
		if q and q.type == Province.Type.SEA and n != near:
			target = n
			break
	if not check(target > 0, "limanın denizine komşu ikinci deniz bölgesi"):
		return
	var eta := Navy.eta_hours(f, target)
	gt(eta, 0.0, "tahmini varış")
	check(Navy.order(f, target), "görev emri")
	var hours := 0
	while f.location != target and hours < 24 * 30:
		GameClock.advance_hours(1)
		hours += 1
	eq(f.location, target, "filo hedef bölgeye vardı")
	check(float(hours) >= eta - 1.0 and float(hours) <= eta * 1.25 + 3.0, "gerçek seyir %d saat, tahmin %.1f saat" % [hours, eta])
	eq(Navy.eta_hours(f, 0), -1.0, "geçersiz hedef: -1")
