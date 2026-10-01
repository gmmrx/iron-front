extends "res://tests/test_case.gd"
## Senaryolar (data/scenarios/scenarios.json): tanımlar ve başlangıç kayıtları geçerli, senaryo başlar (oyuncu seçtiği
## taraf, yeni oyun varsayılanları), anahtar şehir puanı, süre yok (savaş bitince sonuç), kayıt/yükleme.

const ID := "east_1941"
const SLOT := "_test_senaryo"

func test_scenario_definitions() -> void:
	var list: Array = Game.scenarios()
	if not check(not list.is_empty(), "en az bir senaryo"):
		return
	for sc: Dictionary in list:
		var id := str(sc["id"])
		check(FileAccess.file_exists("res://data/scenarios/%s.json" % str(sc["start"])), "%s: başlangıç kaydı var" % id)
		check((sc["sides"] as Array).size() == 2, "%s: iki taraf" % id)
		for s: Dictionary in sc["sides"]:
			check(World.countries.has(str(s["tag"])), "%s: taraf %s" % [id, s["tag"]])
		for cid in sc["key_cities"]:
			check(World.city_by_id(int(cid)) != null, "%s: anahtar şehir %d" % [id, int(cid)])
		for k in ["en", "tr"]:
			check(str(sc["name"].get(k, "")) != "" and str(sc["desc"].get(k, "")) != "", "%s: %s ad ve anlatım" % [id, k])

func _start(tag: String) -> bool:
	if not check(Game.start_scenario(ID, tag), "senaryo başlar"):
		return false
	Game.fresh_start = false
	World.start_game(tag)                  # main.gd sahne yeniden kurulunca bunu çağırır (yeni oyun varsayılanları)
	return true

func test_scenario_start_and_score() -> void:
	if not _start("SOV"):
		return
	eq(World.player_tag, "SOV", "oyuncu seçtiği taraf")
	eq(World.date_value(), 19410622, "başlangıç günü")
	check(Diplomacy.are_enemies("GER", "SOV"), "iki taraf savaşta")
	var sc := Game.scenario_score()
	eq(int(sc["total"]), 120, "anahtar şehirler toplam 120 puan")
	eq(int(sc["need"]), 60, "saldıran 60 puan tutmalı")
	eq(int(sc["att"]), 0, "başlangıçta Almanya hiçbirini tutmuyor")
	check(Game.is_key_city(8), "Moskova anahtar şehir")
	check(not Game.is_key_city(1), "Tokyo değil")
	for d in Military.country_divisions("SOV"):
		if not d.hold:
			fail("oyuncunun tümenleri son askere kadar başlar")
			break
	check(not World.player().auto_trade, "oyuncunun ticareti elle")

func test_no_time_limit() -> void:
	if not _start("SOV"):
		return
	World.day_count += 2000                # yıllar geçse de savaş sürdükçe senaryo bitmez
	Game._scenario_tick()
	check(not Game.over, "süre yok: savaş sürdükçe oyun sürer")

func test_attacker_wins_holding_key_cities() -> void:
	if not _start("GER"):
		return
	# Almanya Moskova ve Leningrad'ı (50 + 15) tutuyor; savaş barışla biterse şehirleri çok tutan kazanmış sayılır
	for cid in [8, 29]:
		World.set_controller(World.city_by_id(cid).province_id, "GER")
	eq(int(Game.scenario_score()["att"]), 65, "Almanya 65 puan tutuyor")
	var result := []
	Game.game_over.connect(func(v: bool, r: String) -> void: result.append([v, r]))
	for w: Dictionary in Diplomacy.wars.duplicate():
		if "GER" in w["attackers"] and "SOV" in w["defenders"]:
			Diplomacy.wars.erase(w)
	Game._scenario_tick()
	if check(result.size() == 1, "oyun sonu"):
		check(bool(result[0][0]), "saldıran (oyuncu) kazandı")
		eq(str(result[0][1]), "GAMEOVER_SCENARIO_WIN", "neden")

func test_war_end_finishes_scenario() -> void:
	if not _start("GER"):
		return
	var result := []
	Game.game_over.connect(func(v: bool, r: String) -> void: result.append([v, r]))
	for w: Dictionary in Diplomacy.wars.duplicate():
		if "GER" in w["attackers"] and "SOV" in w["defenders"]:
			Diplomacy.wars.erase(w)
	check(not Diplomacy.are_enemies("GER", "SOV"), "savaş bitti")
	Game._scenario_tick()
	check(Game.over, "savaş bitince senaryo da biter")
	if check(result.size() == 1, "oyun sonu"):
		check(not bool(result[0][0]), "Almanya şehir tutmadan barış yaptı: kaybetti")

func test_scenario_saved_and_loaded() -> void:
	if not _start("GER"):
		return
	check(Game.save_game(SLOT), "kaydet")
	Game.new_game()
	check(Game.scenario.is_empty(), "yeni oyunda senaryo yok")
	if not check(Game.load_game(SLOT), "yükle"):
		return
	eq(str(Game.scenario.get("id", "")), ID, "senaryo kayıttan döner")
	DirAccess.remove_absolute(Game.SAVE_DIR + SLOT + ".json")
