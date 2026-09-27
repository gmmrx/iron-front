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
