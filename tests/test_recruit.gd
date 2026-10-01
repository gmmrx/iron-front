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
