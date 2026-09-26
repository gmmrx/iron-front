extends "res://tests/test_case.gd"
## Siyaset: olaylar ve odak şartları.

## Hatay meselesi: Fransa kabul ederse İskenderun Sancağı Türkiye'ye geçer; odak şartı artık sağlanmaz
func test_hatay_question_cedes_iskenderun() -> void:
	var tur := country("TUR")
	var fra := country("FRA")
	var city: City = null
	for c: City in World.cities:
		if c.name == "İskenderun":
			city = c
	if not check(city != null, "İskenderun şehri haritada yok"):
		return
	var st: StateRegion = World.states[city.state_id]
	eq(st.owner, "FRA", "1936'da Hatay Fransa'nın")
	check(Politics.check(tur, {"owns_city_not": "İskenderun"}), "Türkiye Hatay'a sahip değilken odak şartı sağlanmalı")
	Politics.choose_option(fra, "hatay_question", 0, "TUR")
	eq(st.owner, "TUR", "kabulden sonra Hatay")
	check(city.state_id in tur.states, "Hatay Türkiye'nin eyaletlerinde")
	check(not Politics.check(tur, {"owns_city_not": "İskenderun"}), "Hatay alındıktan sonra odak şartı sağlanmamalı")

## Oyuncuya gelen olay kendiliğinden seçilmez: pending_events'te bekler, etkisi uygulanmaz
func test_player_event_waits_for_choice() -> void:
	var tur := player()
	var st: StateRegion = null
	for c: City in World.cities:
		if c.name == "İskenderun":
			st = World.states[c.state_id]
	Politics.pending_events.clear()
	Politics.fire_event(country("FRA"), "hatay_question", "TUR")    # AI: hemen seçer
	Politics.fire_event(tur, "soviet_straits_demand", "SOV")        # oyuncu: bekler
	eq(Politics.pending_events.size(), 1, "oyuncu olayı bekliyor")
	if not Politics.pending_events.is_empty():
		eq(Politics.pending_events[0]["id"], "soviet_straits_demand", "bekleyen olay")
	days(3)
	eq(Politics.pending_events.size(), 1, "3 gün sonra olay hâlâ bekliyor")
	check(st != null and st.owner in ["TUR", "FRA"], "Hatay geçerli bir sahipte")

# ------------------------------------------------------------------ istikrar / savaş desteği
## Ruh ve danışmanları temizlenmiş ülke: modifier'lar yalnız test ettiğimiz kaynaktan gelsin
func _bare(tag: String) -> Country:
	var c := country(tag)
	c.spirits.clear()
	c.advisors.clear()
	c.decisions_active.clear()
	return c

func test_stability_formula_party_bonus() -> void:
	var c := _bare("TUR")
	c.stability = 0.4
	c.popularity = {"neutrality": 0.6, "democratic": 0.4, "fascism": 0.0, "communism": 0.0}
	eq(c.mod("stability"), 0.0, "ruhsuz ülkede istikrar modifier'ı")
	near(Politics.stability(c), 0.4 + Politics.PARTY_STABILITY * 0.6, 0.0001, "istikrar = taban + parti popülerliği × 0,15")
	c.spirits.append("kemalist_reforms")          # +%5 istikrar
	near(Politics.stability(c), 0.45 + Politics.PARTY_STABILITY * 0.6, 0.0001, "ruh istikrarı artırır")
	c.stability = 1.0
	eq(Politics.stability(c), 1.0, "istikrar en çok %100")

func test_war_support_tension_and_war_state() -> void:
	var c := _bare("TUR")
	c.war_support = 0.2
	World.world_tension = 0.0
	near(Politics.war_support(c), 0.2, 0.0001, "gerginliksiz savaş desteği")
	World.world_tension = 50.0
	near(Politics.war_support(c), 0.4, 0.0001, "gerginlik %50 → +%20")
	World.world_tension = 100.0
	near(Politics.tension_war_support(), 0.4, 0.0001, "gerginlik katkısı en çok %40")
	var gre := _bare("GRE")
	gre.war_support = 0.5
	gre.war_goals["TUR"] = true
	Diplomacy.declare_war("GRE", "TUR")
	World.world_tension = 0.0              # ilan gerginliği artırır; burada yalnız savaş durumu ölçülür
	near(Politics.war_support(c), 0.4, 0.0001, "savunma savaşında +%20")
	near(Politics.war_support(gre), 0.3, 0.0001, "saldırı savaşında −%20")

func test_law_requirements() -> void:
	var c := _bare("TUR")
	c.political_power = 1000.0
	c.war_support = 0.0
	World.world_tension = 0.0
	eq(Economy.law_block_reason(c, "conscription", "reserve_callup"), "LAW_REQ_WAR_SUPPORT", "iç cephe yetmez")
	c.war_support = 0.6
	eq(Economy.law_block_reason(c, "conscription", "reserve_callup"), "", "iç cephe yetince açılır")
	eq(Economy.law_block_reason(c, "conscription", "levee_en_masse"), "LAW_REQ_AUTHORITARIAN", "bağlantısız barışta kitlesel celp kapalı")
	c.war_support = 1.0
	eq(Economy.law_block_reason(c, "economy", "total_war"), "LAW_REQ_AT_WAR", "topyekûn savaş, savaş ister")
	var pp := c.political_power
	check(Economy.change_law(c, "conscription", "two_year_service"), "yasa değişir")
	near(c.political_power, pp - Economy.law_change_cost, 0.001, "yasa nüfuz bedeli")
	c.political_power = 10.0
	check(not Economy.change_law(c, "conscription", "one_year_service"), "nüfuz yetmezse yasa değişmez")
	eq(c.laws["conscription"], "two_year_service", "yasa aynı kaldı")

func test_advisor_effect_and_limit() -> void:
	var c := _bare("TUR")
	c.political_power = 1000.0
	var gain0 := c.daily_political_power_gain()
	Politics.hire(c, "cabinet_secretary")              # +%12 nüfuz kazancı
	near(c.political_power, 1000.0 - Politics.advisor_cost, 0.001, "danışman bedeli")
	near(c.daily_political_power_gain() - gain0, 2.0 * float(Politics.advisor_mods("cabinet_secretary")["political_power_gain"]), 0.0001, "danışman nüfuz kazancını artırır")
	var ids: Array = Politics.advisor_defs.keys()
	for id: String in ids:
		Politics.hire(c, id)
	eq(c.advisors.size(), Politics.max_advisors, "en çok danışman sayısı")
	Politics.dismiss(c, "cabinet_secretary")
	check(not "cabinet_secretary" in c.advisors, "danışman görevden alınır")

func test_decision_effect_and_expiry() -> void:
	var c := _bare("TUR")
	c.political_power = 500.0
	c.stability = 0.5
	check(not Politics.can_take_decision(c, "war_bonds"), "savaş tahvili barışta alınmaz")
	var s0 := Politics.stability(c)
	Politics.take_decision(c, "propaganda_campaign")
	near(c.political_power, 500.0 - float(Politics.decisions["propaganda_campaign"]["cost"]), 0.001, "karar bedeli")
	near(Politics.stability(c) - s0, 0.08, 0.0001, "propaganda istikrarı artırır")
	check(not Politics.can_take_decision(c, "propaganda_campaign"), "süren karar yeniden alınmaz")
	eq(int(c.decisions_active["propaganda_campaign"]), World.day_count + int(Politics.decisions["propaganda_campaign"]["days"]), "karar bitiş günü")
	c.decisions_active["propaganda_campaign"] = World.day_count      # süresi doldu
	Politics._on_day_impl()
	check(not c.decisions_active.has("propaganda_campaign"), "süresi dolan karar kalkar")
	near(Politics.stability(c), s0, 0.0001, "karar etkisi biter")

func test_timed_spirit_expires() -> void:
	var c := country("TUR")
	check("first_five_year_plan" in c.spirits, "TUR 1936'da Birinci Beş Yıllık Plan ile başlar")
	GameClock.year = 1938; GameClock.month = 4; GameClock.day = 16
	World.day_count = 14
	Politics._expire_spirits()
	check("first_five_year_plan" in c.spirits, "tarihten önce ruh sürer")
	GameClock.day = 17
	Politics._expire_spirits()
	check(not "first_five_year_plan" in c.spirits, "tarih gelince ruh kalkar")

# ------------------------------------------------------------------ seçimler
func test_election_changes_ruling_party() -> void:
	var c := country("SPR")
	c.popularity = {"democratic": 0.3, "communism": 0.05, "fascism": 0.6, "neutrality": 0.05}
	c.next_election = World.date_value()
	Politics._elections()
	eq(c.ideology, "fascism", "popülerliği %50'yi aşan ideoloji iktidara gelir")
	eq(c.next_election, (World.date_value() / 10000 + 4) * 10000 + World.date_value() % 10000, "sonraki seçim 48 ay sonra")
	var usa := country("USA")
	usa.popularity = {"democratic": 0.45, "communism": 0.2, "fascism": 0.2, "neutrality": 0.15}
	usa.next_election = World.date_value()
	Politics._elections()
	eq(usa.ideology, "democratic", "kimse %50'yi aşmazsa iktidar kalır")

func test_election_postponed_in_war() -> void:
	var c := country("FRA")
	c.popularity = {"democratic": 0.2, "communism": 0.7, "fascism": 0.05, "neutrality": 0.05}
	country("GER").war_goals["FRA"] = true
	Diplomacy.declare_war("GER", "FRA")
	c.next_election = World.date_value()
	Politics._elections()
	eq(c.ideology, "democratic", "savaşta seçim ertelenir")
	gt(c.next_election, World.date_value(), "seçim tarihi ileri alınır")

# ------------------------------------------------------------------ tarihli olaylar
## Şartsız tarihli olaylar tarihinden bir gün önce gelmez, tarihinde gelir
func test_dated_events_fire_on_date() -> void:
	var dated: Array = []
	for id: String in Politics.events:
		var t: Variant = Politics.events[id].get("trigger")
		if t != null and t.get("require", []).is_empty():
			dated.append([Politics.date_int(str(t["date"])), id])
	dated.sort()
	gt(dated.size(), 5, "şartsız tarihli olay sayısı")
	for d: Array in dated:
		var day := int(d[0])
		_set_date(_prev_day(day))
		Politics._scheduled_events()
		check(not d[1] in Politics.fired_events, "%s tarihinden önce geldi" % d[1])
		_set_date(day)
		Politics._scheduled_events()
		check(d[1] in Politics.fired_events, "%s tarihinde gelmedi" % d[1])

## Şartlı tarihli olay şartı sağlanmadıkça gelmez (Atatürk'ün ölümü: lider Atatürk olmalı)
func test_conditional_dated_event() -> void:
	var tur := country("TUR")
	tur.leader = "İsmet İnönü"
	_set_date(19381110)
	Politics._scheduled_events()
	check(not "ataturk_death" in Politics.fired_events, "lider başkayken olay gelmez")
	tur.leader = "Mustafa Kemal Atatürk"
	Politics._scheduled_events()
	check("ataturk_death" in Politics.fired_events, "şart sağlanınca gelir")
	check(Politics.pending_events.any(func(e: Dictionary) -> bool: return e["id"] == "ataturk_death"), "oyuncuya pencere olarak gelir")

## Şartlı seçenek: şart sağlanmazsa kilitli, AI seçmez; zorla seçilirse açık bir seçenek uygulanır
func test_locked_option() -> void:
	var tur := country("TUR")
	var sov := country("SOV")
	tur.leader = "İsmet İnönü"
	check(not Politics.option_available(tur, "soviet_straits_demand", 0), "Atatürk yokken nazik ret kilitli")
	check(Politics.option_available(tur, "soviet_straits_demand", 1), "şartsız seçenek açık")
	for i in 200:
		if Politics._ai_option("soviet_straits_demand", tur) == 0:
			fail("AI kilitli seçeneği seçti")
			break
	var pp := tur.political_power
	Politics.choose_option(tur, "soviet_straits_demand", 0, "SOV")
	check(not is_equal_approx(tur.political_power, pp - 25.0), "kilitli seçeneğin etkisi uygulanmaz")
	check("TUR" in sov.access or sov.war_goals.has("TUR"), "yerine açık seçeneklerden biri uygulanır")

func _set_date(d: int) -> void:
	GameClock.year = d / 10000
	GameClock.month = (d / 100) % 100
	GameClock.day = d % 100

func _prev_day(d: int) -> int:
	var y := d / 10000
	var m := (d / 100) % 100
	var day := d % 100 - 1
	if day < 1:
		m -= 1
		if m < 1:
			m = 12
			y -= 1
		day = GameClock.days_in_month(y, m)
	return y * 10000 + m * 100 + day
