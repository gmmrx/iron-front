extends "res://tests/test_case.gd"
## Diplomasi: savaş gerekçesi, gerginlik eşikleri, savaşa katılım, teslim alma, barış.

func _war(a: String, b: String) -> bool:
	country(a).war_goals[b] = true
	return Diplomacy.declare_war(a, b)

func _bare(tag: String) -> Country:
	var c := country(tag)
	c.spirits.clear()
	c.advisors.clear()
	return c

func test_justification_time_and_cost() -> void:
	var tur := player()
	var irq := country("IRQ")
	World.world_tension = 60.0
	tur.political_power = 100.0
	check(Diplomacy.justify(tur, irq), "gerekçe başlar")
	near(tur.political_power, 100.0 - Diplomacy.JUSTIFY_COST, 0.001, "gerekçe SG bedeli")
	eq(int(tur.justify_progress["IRQ"]), Diplomacy.JUSTIFY_DAYS, "gerekçe süresi")
	check(not Diplomacy.justify(tur, irq), "süren gerekçe yeniden başlamaz")
	for i in Diplomacy.JUSTIFY_DAYS - 1:
		Diplomacy._on_day_impl()
	check(not tur.war_goals.has("IRQ"), "süre dolmadan gerekçe hazır değil")
	var t0 := World.world_tension
	Diplomacy._on_day_impl()
	check(tur.war_goals.has("IRQ"), "%d günde gerekçe hazır" % Diplomacy.JUSTIFY_DAYS)
	check(not tur.justify_progress.has("IRQ"), "gerekçe sayacı kalkar")
	near(World.world_tension - t0, 3.0 + 0.0, 0.001, "hazır gerekçe gerginliği +3 artırır")
	tur.political_power = 10.0
	eq(Diplomacy.can_justify(tur, country("SYR") if World.countries.has("SYR") else country("PER")), "DIPLO_ERR_PP", "SG yetmezse gerekçe yok")

func test_tension_thresholds_by_ideology() -> void:
	var eng := country("ENG")
	var tur := player()
	var ger := country("GER")
	for c in [eng, tur, ger]:
		c.political_power = 1000.0
	World.world_tension = 99.0
	eq(Diplomacy.can_justify(eng, ger), "DIPLO_ERR_TENSION", "demokrasi %100 gerginlik ister")
	World.world_tension = 100.0
	eq(Diplomacy.can_justify(eng, ger), "", "demokrasi %100 gerginlikte gerekçe hazırlar")
	eq(Diplomacy.can_justify(eng, country("USA")), "DIPLO_ERR_TENSION", "demokrasi başka demokrasiye asla")
	World.world_tension = 49.0
	eq(Diplomacy.can_justify(tur, country("IRQ")), "DIPLO_ERR_TENSION", "bağlantısız %50 gerginlik ister")
	World.world_tension = 50.0
	eq(Diplomacy.can_justify(tur, country("IRQ")), "", "bağlantısız %50'de hazırlar")
	World.world_tension = 0.0
	eq(Diplomacy.can_justify(ger, country("POL")), "", "faşist için eşik yok")
	eq(Diplomacy.can_justify(eng, country("FRA")), "DIPLO_ERR_ALLY", "müttefike gerekçe yok")

func test_declare_war_requires_goal() -> void:
	var ger := country("GER")
	eq(Diplomacy.can_declare(ger, country("POL")), "DIPLO_ERR_NO_GOAL", "gerekçesiz savaş ilanı yok")
	check(not Diplomacy.declare_war("GER", "POL"), "gerekçesiz ilan reddedilir")
	check(_war("GER", "POL"), "gerekçeyle ilan")
	check(not ger.war_goals.has("POL"), "kullanılan gerekçe düşer")
	eq(Diplomacy.can_declare(ger, country("POL")), "DIPLO_ERR_ALREADY", "zaten savaşta")

func test_allies_and_guarantors_join_defender() -> void:
	check(_war("GER", "FRA"), "Almanya → Fransa")
	check(Diplomacy.are_enemies("ENG", "GER"), "Fransa'nın ittifakındaki İngiltere savunmaya katılır")
	Diplomacy.guarantee("SOV", "ROM")
	check(_war("HUN", "ROM"), "Macaristan → Romanya")
	check(Diplomacy.are_enemies("SOV", "HUN"), "garantör savunmaya katılır")
	check(not Diplomacy.are_enemies("SOV", "GER"), "garantör başka savaşa girmez")

## Serbest dönemde (tarih çizelgesi bittikten sonra) aynı ideolojili ittifak üyesi saldırı çağrısına uyar; tarih
## sürerken uymaz, katılım çizelgeden gelir (test_history)
func test_attacker_faction_answers_call() -> void:
	var keep := AI.free_from
	AI.free_from = 0
	Diplomacy.create_faction("GER")
	Diplomacy.join_faction("ITA", "GER")
	check(_war("GER", "POL"), "Almanya → Polonya")
	AI.free_from = keep
	check(Diplomacy.are_enemies("ITA", "POL"), "aynı ideolojili ittifak üyesi çağrıya uyar")
	check(Diplomacy.are_allies("ITA", "GER"), "İtalya saldıran tarafta")

## Teslim ilerlemesi: işgal edilen zafer puanı payı; sömürge şehirleri ¼; başkent +%10
func test_capitulation_progress_weights() -> void:
	var fra := country("FRA")
	check(_war("GER", "FRA"), "Almanya → Fransa")
	var home: String = World.states[fra.capital_state].adm0
	var total := 0.0
	var home_city: City = null
	var colony_city: City = null
	var cap_pid := World.capital_province("FRA")
	for sid in fra.states:
		var colonial: bool = World.states[sid].adm0 != home
		for city: City in World.states[sid].cities:
			total += float(maxi(city.victory_points, 1)) * (0.25 if colonial else 1.0)
			if city.province_id == cap_pid:
				continue
			if not colonial and home_city == null and city.victory_points >= 3:
				home_city = city
			if colonial and colony_city == null and city.victory_points >= 3:
				colony_city = city
	if not check(home_city != null and colony_city != null, "Fransa'da anavatan ve sömürge şehri"):
		return
	near(Diplomacy._surrender_progress(fra), 0.0, 0.0001, "işgal yokken")
	World.set_controller(home_city.province_id, "GER")
	var p1 := Diplomacy._surrender_progress(fra)
	near(p1, home_city.victory_points / total, 0.0001, "anavatan şehri tam puan")
	World.set_controller(colony_city.province_id, "GER")
	var p2 := Diplomacy._surrender_progress(fra)
	near(p2 - p1, colony_city.victory_points * 0.25 / total, 0.0001, "sömürge şehri ¼ puan")
	var cap_vp := 0.0               # başkent bölgesindeki tüm şehirler (ör. Paris ve banliyöleri)
	for city: City in World.cities:
		if city.province_id == cap_pid:
			cap_vp += maxi(city.victory_points, 1)
	World.set_controller(cap_pid, "GER")
	var p3 := Diplomacy._surrender_progress(fra)
	near(p3 - p2, cap_vp / total + 0.1, 0.0001, "başkent kendi puanı + %10")
	World.set_controller(home_city.province_id, "ITA")      # düşman olmayan ülke kontrolü sayılmaz
	near(Diplomacy._surrender_progress(fra), p3 - home_city.victory_points / total, 0.0001, "düşman olmayanın tuttuğu şehir sayılmaz")

func test_capitulation_threshold_formula() -> void:
	var c := _bare("POL")
	c.war_support = 0.6
	World.world_tension = 0.0
	near(Diplomacy.capitulation_threshold(c), Diplomacy.CAPITULATION_BASE, 0.0001, "savaş desteği %50 üstünde sınır %80")
	c.war_support = 0.2
	near(Diplomacy.capitulation_threshold(c), 0.8 - 0.3 * 0.6, 0.0001, "savaş desteği %20 → sınır %62")
	c.war_support = 0.0
	near(Diplomacy.capitulation_threshold(c), 0.8 - 0.5 * 0.6, 0.0001, "savaş desteği %0 → sınır %50")
	# teslim sınırı modifier'ı olan ilk ruh
	var sp := ""
	for id: String in Politics.spirits:
		if Politics.spirit_mods(id).has("surrender_limit"):
			sp = id
			break
	if check(sp != "", "surrender_limit veren ruh"):
		c.spirits.append(sp)
		var lim := float(Politics.spirit_mods(sp)["surrender_limit"])
		near(Diplomacy.capitulation_threshold(c), clampf(0.5 + lim, 0.2, 0.95), 0.0001, "ruhun teslim sınırı modifier'ı (%s) eklenir" % sp)
	c.spirits.clear()
	c.war_support = 0.0
	for i in 5:
		c.spirits.append("x")
	near(maxf(Diplomacy.capitulation_threshold(c), 0.2), Diplomacy.capitulation_threshold(c), 0.0001, "sınır en az %20")

## Teslimde işgal edilen eyaletler işgalciye geçer; çok az şey kaldıysa ülke ilhak edilir
func test_capitulation_transfers_occupied_states() -> void:
	var pol := country("POL")
	check(_war("GER", "POL"), "Almanya → Polonya")
	var sids: Array = pol.states.duplicate()
	sids.erase(pol.capital_state)
	var small: int = sids[0]
	var partial: int = -1
	for sid: int in sids:
		if sid != small and World.states[sid].provinces.size() >= 3:
			partial = sid
			break
	for pid in World.states[small].provinces:
		World.set_controller(pid, "GER")
	if partial > 0:
		World.set_controller(World.states[partial].provinces[0], "GER")     # yarıdan az bölge
	var vp := 0.0
	for sid in pol.states:
		vp += World.states[sid].victory_points()
	Diplomacy._start_vp["POL"] = vp
	Diplomacy.capitulate(pol)
	eq(World.states[small].owner, "GER", "tamamen işgal edilen eyalet işgalciye geçer")
	if partial > 0:
		eq(World.states[partial].owner, "POL", "yarıdan azı işgal edilen eyalet kalır")
	check(pol.exists(), "çoğu duran ülke ilhak edilmez")
	check(not Diplomacy.are_enemies("GER", "POL"), "teslim olan ülke savaştan çıkar")
	eq(Military.country_divisions("POL").size(), 0, "teslim olan ülkenin tümenleri dağılır")

func test_capitulation_annexes_when_little_left() -> void:
	var pol := country("POL")
	check(_war("GER", "POL"), "Almanya → Polonya")
	var vp := 0.0
	for sid in pol.states:
		vp += World.states[sid].victory_points()
	Diplomacy._start_vp["POL"] = vp
	# en değerli eyaletlerden başlayarak zafer puanının %70'ini işgal et
	var sids: Array = pol.states.duplicate()
	sids.sort_custom(func(a: int, b: int) -> bool: return World.states[a].victory_points() > World.states[b].victory_points())
	var taken := 0.0
	for sid: int in sids:
		if taken >= vp * 0.7:
			break
		for pid in World.states[sid].provinces:
			World.set_controller(pid, "GER")
		taken += World.states[sid].victory_points()
	Diplomacy.capitulate(pol)
	check(not pol.exists(), "geriye %35'ten az kalınca ülke ilhak edilir")
	eq(pol.states.size(), 0, "tüm eyaletler devredildi")

func test_white_peace_restores_control() -> void:
	var pol := country("POL")
	check(_war("GER", "POL"), "Almanya → Polonya")
	var pid: int = World.states[pol.states[0]].provinces[0]
	World.set_controller(pid, "GER")
	Diplomacy.white_peace("GER", "POL")
	check(not Diplomacy.are_enemies("GER", "POL"), "beyaz barışla savaş biter")
	eq(Diplomacy.wars.size(), 0, "savaş listesi boş")
	eq(World.controller_tag(pid), "POL", "işgal edilen bölge sahibine döner")
	eq(World.states[pol.states[0]].owner, "POL", "toprak el değiştirmez")

## Savaş liderinin olmayan bir katılımcısı beyaz barış yaparsa yalnız o çıkar
func test_white_peace_member_leaves() -> void:
	check(_war("GER", "FRA"), "Almanya → Fransa (İngiltere katılır)")
	Diplomacy.white_peace("ENG", "GER")
	check(not Diplomacy.are_enemies("ENG", "GER"), "İngiltere savaştan çıkar")
	check(Diplomacy.are_enemies("FRA", "GER"), "Fransa savaşta kalır")

## Lider bir üye ile barış yapınca savaş lider ile diğerleri arasında sürer
func test_white_peace_leader_with_member() -> void:
	Diplomacy.guarantee("FRA", "POL")
	check(_war("GER", "POL"), "Almanya → Polonya (garantör Fransa katılır)")
	check(Diplomacy.are_enemies("GER", "FRA"), "Fransa savaşta")
	Diplomacy.white_peace("GER", "ITA")       # savaşta olmayanla barış: etkisiz
	check(Diplomacy.are_enemies("GER", "POL"), "ilgisiz barış savaşı bitirmez")
	Diplomacy.white_peace("GER", "FRA")
	check(not Diplomacy.are_enemies("GER", "FRA"), "Almanya–Fransa barışı")
	check(Diplomacy.are_enemies("GER", "POL"), "Almanya–Polonya savaşı sürer")
	Diplomacy.white_peace("POL", "GER")
	eq(Diplomacy.wars.size(), 0, "iki lider barışınca savaş biter")

## İlhak edilen ülkenin ordusu haritada kalmaz (Çekoslovakya 1939: tümenler, filolar, hava kanatları kalkar)
func test_annexed_country_units_removed() -> void:
	check(Military.country_divisions("CZE").size() > 0, "Çekoslovakya'nın başlangıçta tümeni olmalı")
	World.annex("CZE", "GER")
	check(not country("CZE").exists(), "Çekoslovakya ilhak sonrası var")
	eq(Military.country_divisions("CZE").size(), 0, "ilhak edilen ülkenin tümenleri")
	check(Navy.fleets.filter(func(f: Fleet) -> bool: return f.owner == "CZE").is_empty(), "ilhak edilen ülkenin filosu kaldı")
	check(Air.wings.filter(func(w: AirWing) -> bool: return w.owner == "CZE").is_empty(), "ilhak edilen ülkenin hava kanadı kaldı")

## Teslim olan ülke savaş dışı kalır: ittifaktan çıkar, garantileri düşer, mütareke boyunca savaş ilan edemez
func test_surrendered_country_truce() -> void:
	var hun: Country = World.countries["HUN"]
	var rom: Country = World.countries["ROM"]
	Diplomacy.join_faction("HUN", "GER")
	check(Diplomacy.are_allies("HUN", "GER"), "Macaristan Almanya'nın müttefiki")
	hun.guarantees.append("AUS")
	Diplomacy.capitulate(hun)
	check(hun.exists(), "toprağı kalan teslim")
	check(not Diplomacy.are_allies("HUN", "GER"), "teslim olan ittifaktan çıkar")
	eq(hun.guarantees.size(), 0, "teslim olanın garantileri düşer")
	hun.war_goals["ROM"] = true
	eq(Diplomacy.can_declare(hun, rom), "DIPLO_ERR_TRUCE", "mütarekede savaş ilanı yok")
	check(not Diplomacy.declare_war("HUN", "ROM"), "savaş açılamaz")
	World.day_count += Diplomacy.TRUCE_DAYS + 1
	eq(Diplomacy.can_declare(hun, rom), "", "mütareke bitince savaş ilan edilebilir")
