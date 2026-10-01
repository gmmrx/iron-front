extends "res://tests/test_case.gd"
## Deniz ve hava: filo görevi ve dönüş, deniz muharebesi, konvoy baskını; kanat konuşlandırma, oyuncu kanadının
## otomatik kapalı başlaması, hava üstünlüğünün kara muharebesine etkisi, bombardıman, bölgeden görev. Oyuncu Almanya.

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

## Üssü düşen filo en yakın gidilebilen dost limana döner; mahsur filo bekleme süresinde yeniden yol aramaz
func test_fleet_rehome_and_wait() -> void:
	var f := _surface_fleet("GER")
	if not check(f != null, "Alman su üstü filosu"):
		return
	var sea := Navy.sea_for(f.home)
	f.location = sea
	f.path = PackedInt32Array()
	# eski üs artık gidilemez (deniz ağında olmayan bir kara bölgesi)
	var inland := World.capital_province("GER")
	f.home = inland
	var now := World.day_count * 24 + GameClock.hour
	Navy._rehome_wait[f.id] = now + 24
	Navy._return_home(f)
	eq(f.home, inland, "bekleme süresinde yol aranmaz")
	check(f.path.is_empty(), "bekleme süresinde yola çıkmaz")
	Navy._rehome_wait.erase(f.id)
	Navy._return_home(f)
	check(Navy.is_friendly_port("GER", f.home), "yeni üs dost liman")
	check(not f.path.is_empty() or f.location == f.home, "yeni üsse yola çıkar")
	check(not Navy._rehome_wait.has(f.id), "gidilebilen liman bulununca bekleme yok")

## Hava çatışması: görev bölgeleri örtüşen düşman kanatları uçak kaybeder; uzaktaki, düşmansız kanat kaybetmez
func test_air_combat_overlapping_zones() -> void:
	_war("GER", "POL")
	var ger := country("GER")
	var pol := country("POL")
	for c: Country in [ger, pol]:
		c.stockpile[Air.TYPES["fighter"]["eq"]] = 1000.0
	var gb := Air.bases_of("GER")
	var pb := Air.bases_of("POL")
	if not check(not gb.is_empty() and not pb.is_empty(), "iki tarafın hava üssü"):
		return
	var front := World.capital_province("POL")
	var wg: AirWing = Air.deploy(ger, "fighter", gb[0])
	var wp: AirWing = Air.deploy(pol, "fighter", pb[0])
	# Almanya'nın en uzak üssünden kendi batısına: düşman yok
	var far_base := gb[gb.size() - 1]
	var wf: AirWing = Air.deploy(ger, "fighter", far_base)
	var ok := Air.set_mission(wg, AirWing.Mission.SUPERIORITY, front) and Air.set_mission(wp, AirWing.Mission.SUPERIORITY, front)
	if not check(ok, "iki kanat da cepheye görev alır"):
		return
	Air.set_mission(wf, AirWing.Mission.SUPERIORITY, World.province(World.capital_province("GER")).id)
	var far_from_front := Air.distance_km(World.province(wf.zone).center, World.province(front).center) > Air.ZONE_KM * 1.6
	var g0 := wg.planes
	var p0 := wp.planes
	var f0 := wf.planes
	for i in 10:
		Air._air_combat()
	lt(float(wg.planes), float(g0), "Alman kanadı uçak kaybeder")
	lt(float(wp.planes), float(p0), "Polonya kanadı uçak kaybeder")
	if far_from_front:
		eq(wf.planes, f0, "uzaktaki düşmansız kanat kaybetmez")
	check(Air.fights.has(front), "cephede hava çatışması işareti")

## Uzun oyunda yapay zekânın filo ve kanat sayısı sınırlı: tavandan sonra gemiler en zayıf filoya katılır, uçaklar
## stokta kalır
func test_ai_fleet_and_wing_caps() -> void:
	GameClock.year = 1946                     # tavanlar tarihî akıştan sonra geçerli
	var eng := country("ENG")
	var port: int = Navy._main_port("ENG")
	if not check(port > 0, "İngiltere'nin ana limanı"):
		return
	var surface := 0
	for f in Navy.fleets_of("ENG"):
		if not f.reserve and not f.is_sub_fleet():
			surface += 1
	while surface < Navy.fleet_cap(eng, false):
		Navy._create("ENG", {"destroyer": 4}, port, "t%d" % surface)
		surface += 1
	var r: Fleet = Navy._create("ENG", {"destroyer": 14}, port, "yedek")
	r.reserve = true
	var before := Navy.fleets.size()
	var ships_before := 0
	for f in Navy.fleets_of("ENG"):
		ships_before += f.total()
	Navy._promote_reserves(eng)
	eq(Navy.fleets.size(), before - 1, "tavanda yedek yeni filo olmaz, en zayıf filoya katılır")
	var ships_after := 0
	for f in Navy.fleets_of("ENG"):
		ships_after += f.total()
	eq(ships_after, ships_before, "gemiler kaybolmaz")
	# kanatlar
	var eq_name: String = Air.TYPES["fighter"]["eq"]
	var have := Air.wings_of("ENG").size()
	var cap := Air.wing_cap(eng)
	eng.stockpile[eq_name] = float((cap - have + 3) * Air.WING_SIZE)
	Air._absorb(eng)
	eq(Air.wings_of("ENG").size(), maxi(cap, have), "kanat sayısı tavanda durur")
	# tavan sanayiye bağlı: sanayisi büyük ülkenin tavanı küçük ülkeninkinden yüksek (ya da eşit)
	check(Navy.fleet_cap(country("USA"), false) >= Navy.fleet_cap(country("LUX"), false), "ABD'nin filo tavanı Lüksemburg'unkinden düşük değil")
	check(Air.wing_cap(country("USA")) >= Air.MIN_WINGS and Air.wing_cap(country("USA")) <= Air.MAX_WINGS, "kanat tavanı 12–40")
	gt(float(eng.stockpile.get(eq_name, 0.0)), float(Air.WING_SIZE * 2), "fazla uçak stokta kalır")

## Oyuncunun yeni gemileri stokta bekler (liman kendiliğinden seçilmez); oyuncu limanı seçince oradaki yedek filoya katılır
func test_player_new_ships_wait_for_port() -> void:
	var c := player()
	var before := Navy.fleets_of(c.tag).size()
	c.stockpile["destroyer"] = 3.0
	c.stockpile["submarine"] = 2.0
	Navy._absorb_new_ships()
	eq(int(c.stockpile["destroyer"]), 3, "oyuncunun muhripleri stokta bekler")
	eq(Navy.fleets_of(c.tag).size(), before, "kendiliğinden yeni filo yok")
	eq(Navy.new_ships(c), {"destroyer": 3, "submarine": 2}, "bekleyen gemiler")
	var ports := Navy.ports_of(c.tag)
	if not check(not ports.is_empty(), "oyuncunun limanı"):
		return
	check(Navy.deploy_ships(c, 0) == null, "liman olmayan yere konuşlanmaz")
	var port: int = ports[ports.size() - 1]
	var f := Navy.deploy_ships(c, port)
	if check(f != null, "limana konuşlandı"):
		eq(f.location, port, "yedek filo seçilen limanda")
		eq(int(f.ships.get("destroyer", 0)), 3, "muhripler yedek filoda")
		check(f.reserve, "yedek filo")
	eq(Navy.new_ships(c), {}, "stokta gemi kalmadı")
	var subs := 0
	for g in Navy.fleets_of(c.tag):
		if g.is_sub_fleet() and g.location == port:
			subs += int(g.ships.get("submarine", 0))
	eq(subs, 2, "denizaltılar aynı limanda ayrı yedek filoda")

# ------------------------------------------------------------------ bombardıman ve bölgeden görev
## Polonya'nın fabrikalı, Alman ana üssünden bombardıman menzilindeki bir eyaleti (yoksa 0)
func _bomb_target(w: AirWing) -> int:
	var best := 0
	var bl := 0
	for sid: int in country("POL").states:
		var st: StateRegion = World.states[sid]
		var lv := st.building_level("civilian_factory") + st.building_level("military_factory")
		var pid: int = st.provinces[0]
		if lv > bl and Air.in_range(w, pid):
			bl = lv
			best = pid
	return best

func test_bombing_stops_factories_and_wears_morale() -> void:
	_war("GER", "POL")
	for w in Air.wings.duplicate():
		Air.wings.erase(w)
	var ger := country("GER")
	var pol := country("POL")
	ger.stockpile[Air.TYPES["bomber"]["eq"]] = 500.0
	ger.stockpile[Air.TYPES["fighter"]["eq"]] = 500.0
	var bw: AirWing = Air.deploy(ger, "bomber", Air._home_base("GER"))
	if not check(bw != null, "bombardıman kanadı"):
		return
	var target := _bomb_target(bw)
	if not check(target > 0, "menzilde fabrikalı Polonya eyaleti"):
		return
	var st := World.state_of_province(target)
	# kurallar: avcı bomba taşımaz, kendi eyaletimiz bombalanmaz
	var fw: AirWing = Air.deploy(ger, "fighter", Air._home_base("GER"))
	eq(Air.bomb_target_error(fw, target), "AIR_ERR_NO_BOMBS", "avcı bomba taşımaz")
	eq(Air.bomb_target_error(bw, World.capital_province("GER")), "AIR_ERR_BOMB_TARGET", "kendi eyaletimiz hedef olmaz")
	check(not Air.set_mission(bw, AirWing.Mission.BOMBING, World.capital_province("GER")), "geçersiz hedefe görev verilmez")
	eq(Air.assign(bw, target, AirWing.Mission.BOMBING), "", "bölgeden görev: bombardıman")
	eq(int(bw.mission), int(AirWing.Mission.BOMBING), "görev bombardıman")
	check(not bw.auto, "oyuncunun emri kanadı elle yönetime alır")
	var civ0 := Economy.available_civilian(pol)
	var ws0 := pol.war_support
	for day in 30:
		Air._bombing()
	gt(st.damage, 0.3, "bir ay karşı koymasız bombardıman sanayinin çoğunu durdurur: %.2f" % st.damage)
	lt(st.damage, Air.BOMB_MAX + 0.0001, "hasar tavanı")
	lt(pol.war_support, ws0, "halkın savaş desteği düşer")
	gt(Economy.damaged_share(pol, "civilian_factory") + Economy.damaged_share(pol, "military_factory"), 0.0, "hasarlı fabrika payı")
	check(Economy.available_civilian(pol) <= civ0, "bombalanmış sivil fabrika inşaata çalışmaz")
	# akın bitince onarılır
	Air.set_mission(bw, AirWing.Mission.IDLE)
	var d0 := st.damage
	for day in 10:
		Air._bombing()
	near(st.damage, maxf(d0 - Air.BOMB_REPAIR * 10.0, 0.0), 0.0001, "günde %1 onarım")

func test_assign_moves_wing_to_a_base_in_range() -> void:
	_war("GER", "POL")
	for w in Air.wings.duplicate():
		Air.wings.erase(w)
	var ger := country("GER")
	ger.stockpile[Air.TYPES["cas"]["eq"]] = 500.0
	var bases := Air.bases_of("GER")
	if not check(bases.size() >= 2, "Almanya'nın birden çok hava üssü"):
		return
	# hedef: Polonya sınırı; kanat hedefe en uzak üste kurulur (yakın destek menzili kısa: 500 km)
	var target := World.capital_province("POL")
	var far := bases[0]
	for sid in bases:
		if Air.distance_km(Air.base_pos(sid), World.province(target).center) > Air.distance_km(Air.base_pos(far), World.province(target).center):
			far = sid
	var w: AirWing = Air.deploy(ger, "cas", far)
	if not check(w != null and not Air.in_range(w, target), "kanat uzak üste, hedef menzil dışında"):
		return
	var near_base := Air.base_for(w, target)
	if near_base == 0:
		eq(Air.assign(w, target, AirWing.Mission.CAS), "AIR_ERR_RANGE", "menzili yeten üs yoksa emir verilmez")
		return
	eq(Air.assign(w, target, AirWing.Mission.CAS), "", "görev verildi")
	eq(w.base, near_base, "kanat menzili yeten üsse geçti")
	check(Air.in_range(w, target), "artık menzilde")
