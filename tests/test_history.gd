extends "res://tests/test_case.gd"
## Tarih çizelgesi (data/common/history.json, AI.gd): yapay zekâ tarihî adımları atar, oyuncunun ülkesi atmaz; koşulu
## tutmayan adım atlanır; serbest tarihten önce yapay zekâ kendi başına savaş açmaz ve saldırı çağrılarına katılmaz.

func _entry(tag: String, extra: Dictionary) -> Dictionary:
	var e := {"date": "1936-01-02", "day": 19360102, "tag": tag}
	e.merge(extra)
	return e

func test_player_country_never_acts() -> void:
	var pp := player().political_power
	var e := _entry(World.player_tag, {"effects": [{"pp": 50}]})
	check(not AI.apply_history(e), "oyuncunun ülkesinin tarihî adımı uygulandı")
	eq(player().political_power, pp, "oyuncunun siyasi gücü değişti")

func test_ai_historical_focus_is_inert() -> void:
	var ger := country("GER")
	check(not "ger_rhineland" in ger.focus_done, "başlangıçta Rheinland yapılmış olmamalı")
	check(AI.apply_history(_entry("GER", {"focus": "ger_rhineland"})), "yapay zekâ tarihî adımı atmadı")
	check(not "ger_rhineland" in ger.focus_done, "kapalı Focus sistemi tarih çizelgesinden tamamlanmamalı")

func test_mark_focus_without_effects() -> void:
	var ger := country("GER")
	var factions_before := Politics.factions.size()
	check(AI.apply_history(_entry("GER", {"mark_focus": ["ger_pact_steel"]})), "adım uygulanmadı")
	check(not "ger_pact_steel" in ger.focus_done, "kapalı Focus sistemi tarih çizelgesinden işaretlenmemeli")
	eq(Politics.factions.size(), factions_before, "etkisiz sayılan odak ittifak kurdu")

func test_failed_requirement_skips_step() -> void:
	# tarih değişmiş: Almanya Polonya ile savaşta değil → İngiltere'nin savaş ilanı atlanır
	var e := _entry("ENG", {"effects": [{"declare_war": "GER"}], "require": [{"enemies_at_war": ["GER", "POL"]}]})
	check(not AI.apply_history(e), "koşulu tutmayan adım uygulandı")
	check(not Diplomacy.are_enemies("ENG", "GER"), "İngiltere savaşa girdi")

func test_no_own_war_before_free_date() -> void:
	var ger := country("GER")
	ger.war_goals["LUX"] = true
	for i in 3:
		AI._declare(ger)
	check(not Diplomacy.are_enemies("GER", "LUX"), "yapay zekâ tarih sürerken kendi başına savaş açtı")
	var keep := AI.free_from
	AI.free_from = 0
	ger.war_goals["LUX"] = true
	AI._declare(ger)
	AI.free_from = keep
	check(Diplomacy.are_enemies("GER", "LUX"), "serbest tarihten sonra yapay zekâ savaş hedefini kullanmadı")

func test_offensive_call_declined_while_history_runs() -> void:
	Politics.apply_effects(country("GER"), [{"create_faction": true}])
	Politics.apply_effects(country("ITA"), [{"join_faction": "GER"}])
	check(Diplomacy.are_allies("GER", "ITA"), "İtalya ittifaka girmedi")
	Diplomacy.add_war_goal(country("GER"), "POL")
	Diplomacy.declare_war("GER", "POL")
	check(Diplomacy.are_enemies("GER", "POL"), "Almanya savaş açamadı")
	check(not Diplomacy.are_enemies("ITA", "POL"), "İtalya saldırı çağrısıyla 1939'da savaşa girdi (tarihte 1940)")

func test_ai_does_not_pick_timeline_focuses() -> void:
	var ger := country("GER")
	for i in 40:
		ger.focus_current = ""
		AI._focus(ger)
		check(ger.focus_current == "" or not AI.history_focus("GER", ger.focus_current),
			"yapay zekâ çizelgenin odağını kendisi seçti: %s" % ger.focus_current)
		if ger.focus_current != "":
			ger.focus_done.append(ger.focus_current)
