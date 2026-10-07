extends "res://tests/test_case.gd"
## Asker alma ve sanayi puanı (SP, data/common/recruit.json): günlük gelir şehri tutana gider, kendi şehrinde asker alınır
## (SP + insan gücü, eğitim), yanlış yerde ya da yetersiz SP'de alınmaz, keşif uçuşu SP tutar ve bir gün sonra biter.
## Oyuncu Almanya.

func player_tag() -> String:
	return "GER"

func test_income_follows_city_holder() -> void:
	var ger := country("GER")
	var inc := Military.sp_income(ger)
	gt(inc, 10.0, "Almanya'nın 1936'daki günlük SP geliri: %.0f" % inc)
	var sp0 := ger.sp
	Military._sp_income()
	near(ger.sp - sp0, inc, 0.01, "gelir SP'ye eklenir")
	# Polonya'nın en büyük şehrini alan, o eyaletin fabrikalarını da alır
	var pol := country("POL")
	var st: StateRegion = World.states[pol.capital_state]
	var before := Military.sp_income(ger)
	World.set_controller(st.largest_city().province_id, "GER")
	gt(Military.sp_income(ger), before, "şehri alınca o eyaletin fabrikaları bizim için çalışır")

func _own_city() -> City:
	for c in World.cities:
		if World.controller_tag(c.province_id) == "GER":
			return c
	return null

func test_recruit_in_own_city() -> void:
	var ger := country("GER")
	var city := _own_city()
	if not check(city != null, "Alman şehri"):
		return
	ger.sp = 1000.0
	var n0 := Military.country_divisions("GER").size()
	var mp0 := ger.manpower_used
	eq(Military.recruit(ger, "infantry", city.province_id), "", "piyade alınır")
	eq(Military.country_divisions("GER").size(), n0 + 1, "yeni tümen")
	near(ger.sp, 1000.0 - 120.0, 0.01, "bedel: 120 SP")
	gt(float(ger.manpower_used - mp0), 1000.0, "insan gücü harcanır")
	var d: Division = Military.divisions_in(city.province_id).filter(func(x: Division) -> bool: return x.owner == "GER").back()
	eq(d.training, 7, "7 gün eğitim")
	var w0 := Air.wings_of("GER").size()
	eq(Military.recruit(ger, "fighter", city.province_id), "", "avcı kanadı alınır")
	eq(Air.wings_of("GER").size(), w0 + 1, "yeni kanat")
	# hatalar
	ger.sp = 10.0
	eq(Military.recruit(ger, "infantry", city.province_id), "RECRUIT_ERR_SP", "SP yetmezse alınmaz")
	ger.sp = 1000.0
	eq(Military.recruit(ger, "infantry", World.capital_province("POL")), "RECRUIT_ERR_CITY", "başkasının şehrinde alınmaz")
	eq(Military.recruit(ger, "tank_ordusu", city.province_id), "RECRUIT_ERR_KIND", "bilinmeyen birlik")

func test_recon_costs_and_ends() -> void:
	var ger := country("GER")
	ger.stockpile[Air.TYPES["fighter"]["eq"]] = 500.0
	var w: AirWing = Air.deploy(ger, "fighter", Air._home_base("GER"))
	if not check(w != null, "kanat"):
		return
	var target := World.capital_province("GER")
	ger.sp = 5.0
	eq(Air.assign(w, target, AirWing.Mission.RECON), "RECON_ERR_SP", "SP yetmezse keşif yok")
	ger.sp = 100.0
	eq(Air.assign(w, target, AirWing.Mission.RECON), "", "keşif uçuşu")
	near(ger.sp, 100.0 - Air.recon_cost(), 0.01, "keşif bedeli")
	World.day_count += 1
	Air._bombing()
	eq(int(w.mission), int(AirWing.Mission.IDLE), "bir gün sonra kanat üssüne döner")

## Gemi (tersane yok): deniz üssü olan eyaletin limanında SP ile alınır, o limandaki yedek filoya katılır; deniz üssü
## ya da limanı olmayan eyalette alınmaz
func test_ships_at_naval_base() -> void:
	var ger := country("GER")
	var port := 0
	var inland := 0
	for sid in ger.states:
		var st: StateRegion = World.states[sid]
		var city := st.largest_city()
		if city == null:
			continue
		if port == 0 and Navy.port_in_state("GER", sid) != 0:
			port = city.province_id
		elif inland == 0 and Navy.port_in_state("GER", sid) == 0:
			inland = city.province_id
	if not check(port != 0 and inland != 0, "Alman limanı ve iç şehir"):
		return
	ger.sp = 1000.0
	eq(Military.recruit_error(ger, "destroyer", inland), "RECRUIT_ERR_PORT", "deniz üssü olmayan yerde gemi yok")
	var sid := World.state_of_province(port).id
	var harbour := Navy.port_in_state("GER", sid)
	var before := 0
	for f in Navy.fleets_of("GER"):
		if f.location == harbour:
			before += int(f.ships.get("destroyer", 0))
	eq(Military.recruit(ger, "destroyer", port), "", "muhrip alınır")
	near(ger.sp, 1000.0 - float(Military.recruit_def()["units"]["destroyer"]["sp"]), 0.01, "bedel SP")
	var after := 0
	for f in Navy.fleets_of("GER"):
		if f.location == harbour:
			after += int(f.ships.get("destroyer", 0))
	eq(after, before + 1, "limandaki filoya katılır")
	eq(int(ger.stockpile.get("destroyer", 0.0)), 0, "stokta beklemez")

## Yapay zekâ donanmasını hedefe (1936 donanması, yılda %8 büyür) kadar SP ile tamamlar; hedefe varınca durur
func test_ai_buys_ships_to_target() -> void:
	var eng := country("ENG")
	# kayıplar: muhriplerin yarısı batmış
	for f in Navy.fleets_of("ENG"):
		f.ships["destroyer"] = int(f.ships.get("destroyer", 0)) / 2
	eng.sp = 100000.0
	var count := func() -> int:
		var n := int(eng.stockpile.get("destroyer", 0.0))
		for f in Navy.fleets_of("ENG"):
			n += int(f.ships.get("destroyer", 0))
		return n
	var n0: int = count.call()
	for i in 40:
		AI._ships(eng)
	var n1: int = count.call()
	gt(n1, n0, "eksik muhripler alınır")
	var start: int = int(Economy._fleets["ENG"]["destroyer"])
	check(n1 <= ceili(start * (1.0 + AI.SHIP_GROWTH * maxf(GameClock.year - 1936, 0)) * maxf(1.0, float(Economy.count(eng, "naval_base")) / 142.0)) + 1, "hedefte durur (%d)" % n1)
	var sp_mid := eng.sp
	for i in 10:
		AI._ships(eng)
	near(eng.sp, sp_mid, 0.01, "hedefe varınca SP harcanmaz")
