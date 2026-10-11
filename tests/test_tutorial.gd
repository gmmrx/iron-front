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
			check(String(s["target"]) in ["front", "enemy", "city", "home"], "hedef türü: " + String(s["target"]))
	var chapters := []
	for s: Dictionary in d["steps"]:
		if not String(s["chapter"]) in chapters:
			chapters.append(String(s["chapter"]))
	for ch: String in ["map", "country", "research", "build", "units", "war", "air", "recon", "recruit", "politics", "diplomacy", "end"]:
		check(ch in chapters, "öğretici bu bölümü de öğretir: " + ch)

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

## Yeni bölümlerin koşulları gerçek oyun durumundan geçer: araştırma ekranı ve başlatılan araştırma, kapanan ekran,
## başkentin paneli ve inşaat, hava paneli ve cepheye hava görevi (Asmara üssünden menzilde), keşif, cephedeki şehir,
## siyaset ve diplomasi ekranları; vurgulanan her arayüz öğesi bulunur. Öğretici bunların hiçbirini kendisi yapmaz.
func test_new_chapters_follow_real_game_state() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	Tutorial.begin_war()
	var hud := Hud.new()
	tree.root.add_child(hud)
	var t := Tutorial.new()
	t._data = Tutorial.data()
	t.hud = hud
	var c := player()
	var step := func(done: String) -> bool: return t._done({"done": done})
	for s: Dictionary in t._data["steps"]:
		if s.has("highlight") and String(s["highlight"]) != "clock" and String(s["highlight"]) != "motivate":
			check(t._highlight_node(String(s["highlight"])) != null, "vurgulanan öğe bulunur: " + String(s["highlight"]))
	check(not step.call("research_open"), "araştırma ekranı açılmadan geçmez")
	hud.toggle_research()
	check(step.call("research_open"), "araştırma ekranı açılınca geçer")
	check(not step.call("research_started"), "araştırma başlamadan geçmez")
	var tech := ""
	for id: String in Research.techs:
		if not Research.is_government_project(id) and Research.can_start_reason(c, id) == "":
			tech = id
			break
	check(Research.start(c, tech), "oyuncu bir araştırma başlatır")
	check(step.call("research_started"), "araştırma başlayınca geçer")
	check(not step.call("panels_closed"), "tam ekran açıkken geçmez")
	hud.close_panels()
	check(step.call("panels_closed"), "ekran kapanınca geçer")
	World.select_province(World.capital_province("ITA"))
	check(step.call("home_state_open"), "başkentin paneli açılınca geçer")
	check(not step.call("front_city_open"), "Roma cephedeki şehir sayılmaz")
	check(not step.call("construction_queued"), "inşaat yokken geçmez")
	check(Economy.queue_building(c, World.states[c.capital_state], "infrastructure"), "oyuncu inşaat başlatır")
	check(step.call("construction_queued"), "inşaat kuyruğa girince geçer")
	var front_city := 0
	var foe_at := World.province(World.capital_province("ETH")).center
	for city: City in World.cities:
		if World.controller_tag(city.province_id) == "ITA" and city.position.distance_to(foe_at) < Tutorial.FRONT_CITY:
			front_city = city.province_id
			break
	gt(front_city, 0, "Doğu Afrika'da cepheye yakın şehrimiz var")
	World.select_province(front_city)
	check(step.call("front_city_open"), "cephedeki şehrin paneli açılınca geçer")
	hud.toggle_air()
	check(step.call("air_open"), "hava paneli açılınca geçer")
	var enemy := 0
	for d: Division in Military.country_divisions("ITA"):
		for n in World.land_neighbors(d.province):
			if World.controller_tag(n) == "ETH":
				enemy = n
	gt(enemy, 0, "cepheye komşu Etiyopya bölgesi")
	check(not step.call("air_mission"), "görev verilmeden geçmez")
	var wings := Air.wings_of("ITA")
	gt(float(wings.size()), 1.0, "İtalya'nın en az iki kanadı")
	eq(Air.assign(wings[0], enemy, AirWing.Mission.SUPERIORITY), "", "Asmara üssü sayesinde cephe menzilde: hava üstünlüğü görevi")
	check(step.call("air_mission"), "cepheye hava görevi verilince geçer")
	check(not step.call("recon"), "keşif yokken geçmez")
	c.sp = maxf(c.sp, 100.0)
	eq(Air.assign(wings[1], enemy, AirWing.Mission.RECON), "", "cepheye keşif uçuşu")
	check(step.call("recon"), "keşif uçuşu başlayınca geçer")
	hud.toggle_politics()
	check(step.call("politics_open"), "siyaset ekranı açılınca geçer")
	hud.toggle_diplomacy()
	check(step.call("diplomacy_open"), "diplomasi ekranı açılınca geçer")
	t.free()
	tree.root.remove_child(hud)
	hud.free()

func test_tutorial_step_is_saved() -> void:
	Game.tutorial = 7
	check(Game.save_game("tut_test"), "kayıt")
	Game.tutorial = -1
	check(Game.load_game("tut_test"), "yükleme")
	eq(Game.tutorial, 7, "öğretici adımı kayıtta")
	Game.tutorial = -1
	DirAccess.remove_absolute(Game.SAVE_DIR + "tut_test.json")     # "Devam et" bu deneme kaydını açmasın
