extends "res://tests/test_case.gd"
## Öğretici (data/common/tutorial.json, game/ui/tutorial.gd): veri ve koşullar; oyuncu adına eylem yok

func player_tag() -> String:
	return "ITA"

func test_steps_have_texts_and_known_conditions() -> void:
	var d := Tutorial.data()
	var csv := FileAccess.get_file_as_string("res://game/localization/strings.csv")
	var src := FileAccess.get_file_as_string("res://game/ui/tutorial.gd")
	gt(float((d["steps"] as Array).size()), 5.0, "adımlar")
	for s: Dictionary in d["steps"]:
		for key: String in ["TUT_" + String(s["id"]), "TUT_CH_" + String(s["chapter"])]:
			check(csv.contains("\n" + key + ","), "metin var: " + key)
		check(src.contains('"%s":' % String(s["done"])), "koşul motorda tanımlı: " + String(s["done"]))
		if s.has("target"):
			check(String(s["target"]) in ["front", "enemy", "city"], "hedef türü: " + String(s["target"]))

func test_begin_war_and_state_conditions() -> void:
	Tutorial.begin_war()
	check(Diplomacy.are_enemies("ITA", "ETH"), "öğretici Etiyopya savaşıyla başlar")
	var t := Tutorial.new()
	t._data = Tutorial.data()
	# sınırda tümenimiz ve karşısında Etiyopya bölgesi var
	var front := t._target_pos("front")
	var enemy := t._target_pos("enemy")
	check(front != World.capital_position("ITA") and enemy != front, "sınır ve düşman bölgesi bulunur")
	check(not t._done({"done": "attack_ordered"}), "emir verilmeden saldırı yok (öğretici kendisi emir vermez)")
	check(not t._done({"done": "recruited"}), "asker alınmadan geçilmez")
	# oyuncunun eylemleri (testte elle): saldırı emri ve asker alma
	var d: Division = null
	var target := 0
	for x: Division in Military.country_divisions("ITA"):
		for n in World.land_neighbors(x.province):
			if World.controller_tag(n) == "ETH":
				d = x
				target = n
				break
		if d:
			break
	check(Military.order_attack(d, target), "saldırı emri verilebilir")
	check(t._done({"done": "attack_ordered"}), "emir sonrası adım geçer")
	t._baseline = t._training_count()
	var city := t._target_pos("city")
	var cp := 0
	for c: City in World.cities:
		if c.position == city:
			cp = c.province_id
	eq(Military.recruit(World.countries["ITA"], "infantry", cp), "", "Doğu Afrika şehrinde asker alınır")
	check(t._done({"done": "recruited"}), "asker alınınca adım geçer")
	t.free()

func test_tutorial_step_is_saved() -> void:
	Game.tutorial = 7
	check(Game.save_game("tut_test"), "kayıt")
	Game.tutorial = -1
	check(Game.load_game("tut_test"), "yükleme")
	eq(Game.tutorial, 7, "öğretici adımı kayıtta")
	Game.tutorial = -1
	DirAccess.remove_absolute(Game.SAVE_DIR + "tut_test.json")     # "Devam et" bu deneme kaydını açmasın
