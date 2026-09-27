extends "res://tests/test_data.gd"
## Şablon mod (data/modes/_template, game/modes/_template/rules.gd): test_data.gd'nin BÜTÜN veri bütünlüğü denetimleri bu
## modun birleşik verisiyle koşar; ardından moda özgü davranış testleri. Yeni mod: tools/new_mode.py bu dosyanın bir
## kopyasını tests/test_mode_<id>.gd olarak üretir.

func mode() -> String:
	return "_template"

func test_template_manifest() -> void:
	eq(GameModes.id, "_template", "etkin mod")
	eq([GameClock.year, GameClock.month, GameClock.day], [1936, 1, 1], "başlangıç tarihi")
	eq(Game.end_date(), 19370101, "bitiş tarihi")
	check(Game.rules is ModeRules, "kural betiği kuruldu")
	eq(GameModes.save_prefix(), "_template_", "kayıt öneki")

## scenario.json: Hatay (eyalet 346) TUR'un; sahiplik, kontrol ve nüfus tutarlı
func test_template_scenario() -> void:
	var st: StateRegion = World.states[346]
	eq(st.owner, "TUR", "eyalet sahibi")
	eq(st.controller, "TUR", "eyalet kontrolü")
	check(346 in country("TUR").states, "TUR eyalet listesinde")
	check(not 346 in country("FRA").states, "FRA eyalet listesinde değil")
	eq(World.controller_tag(st.provinces[0]), "TUR", "bölge kontrolü")
	var pop := 0
	for sid in country("TUR").states:
		pop += World.states[sid].population
	eq(country("TUR").population, pop, "nüfus yeniden hesaplandı")

## events.patch.json: yeni olay eklendi, iki WWII olayı silindi, motor olayları duruyor, temel sıra korundu
func test_template_patch() -> void:
	check(Politics.events.has("template_hello"), "yeni olay eklendi")
	check(not Politics.events.has("jap_february_26"), "null ile silinen olay yok")
	check(not Politics.events.has("ita_league_sanctions"), "null ile silinen olay yok")
	check(Politics.events.has("call_to_arms"), "motor olayı duruyor")
	var keys: Array = Politics.events.keys()
	eq(keys[keys.size() - 1], "template_hello", "yeni olay sona eklendi")
	eq(keys[0], "anschluss", "temel sıra korundu")

## Kural betiği: gün sayacı, tarihli olay oyuncuya gelir, modun etkisi uygulanır ve açıklanır
func test_template_rules_run() -> void:
	days(12)
	eq(Game.rules.get("days"), 12, "on_day her gün çağrılır")
	var waiting := false
	for pe: Dictionary in Politics.pending_events:
		if pe["id"] == "template_hello":
			waiting = true
	check(waiting, "tarihli olay oyuncuyu bekliyor (oyuncu adına seçilmez)")
	var pp := player().political_power
	Politics.choose_option(player(), "template_hello", 0, "TUR")
	near(player().political_power, pp + 25.0, 0.001, "template_bonus etkisi")
	var text := Politics.describe_effects([{"template_bonus": 25}])
	check(text.contains("25"), "etki açıklaması: " + text)

## Bitiş tarihi gelince oyun biter (zafer, manifestteki metin)
func test_template_end_date() -> void:
	var got := []
	var cb := func(v: bool, r: String) -> void: got.append([v, r])
	Game.game_over.connect(cb)
	GameClock.year = 1936
	GameClock.month = 12
	GameClock.day = 30
	days(3)
	Game.game_over.disconnect(cb)
	check(Game.over, "oyun bitti")
	if not got.is_empty():
		eq(got[0][0], true, "süre dolunca zafer")
		eq(got[0][1], GameModes.text("end_text"), "manifestteki bitiş metni")
