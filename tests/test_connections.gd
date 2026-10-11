extends "res://tests/test_case.gd"
## Arayüzde görünen eylemler söylediklerini yapar ve oyunu gerçekten değiştirir: fabrika çıktısı (araştırma, danışman,
## yasa, istikrar) SP gelirini çarpar; birliği açan araştırma bitmeden o birlik alınmaz; askerlik yasası eğitim süresini
## değiştirir; orta tank araştırılınca yeni zırhlı tümen orta tankla kurulur; hava kanadının eksiği SP ile tamamlanır;
## asker alma uyarısı yalnız gerçekten alınabilecek bir birlik varken çıkar; araştırma ölü etki taşımaz. Oyuncu İtalya.

func player_tag() -> String:
	return "ITA"

## Motorun okuduğu araştırma etkileri (Country.mod çağrıları; tabur kategorisi + "_" + soft/hard/defense/breakthrough/speed:
## Military.stats). Burada olmayan bir etki araştırma ipucunda yazar ama oyunda hiçbir şeyi değiştirmez.
const LIVE_TECH_EFFECTS := ["infantry_soft", "infantry_hard", "infantry_defense", "infantry_breakthrough", "infantry_speed",
	"artillery_soft", "artillery_hard", "artillery_defense", "artillery_breakthrough", "armor_soft", "armor_hard",
	"armor_defense", "armor_breakthrough", "armor_speed", "air_power", "naval_power", "org", "defense", "breakthrough", "speed",
	"entrenchment", "attack", "factory_output", "construction_speed", "research_speed", "stability", "war_support",
	"political_power_gain"]

func _newest(tag: String) -> Division:
	var best: Division = null
	for d in Military.country_divisions(tag):
		if best == null or d.id > best.id:
			best = d
	return best

func _port_city(c: Country) -> int:
	for city: City in World.cities:
		if World.controller_tag(city.province_id) != c.tag:
			continue
		var st := World.state_of_province(city.province_id)
		if st and Navy.port_in_state(c.tag, st.id) != 0:
			return city.province_id
	return 0

func _has_alert(list: Array, id: String) -> bool:
	for a: Array in list:
		if a[0] == id:
			return true
	return false

## Gölge Fabrikalar (+%10 fabrika çıktısı) SP gelirini %10 büyütür; günlük gelir aynı katla eklenir
func test_factory_output_research_raises_sp() -> void:
	var c := player()
	var base := Military.sp_income(c)
	gt(base, 1.0, "İtalya'nın günlük SP geliri")
	var mod0 := Military.sp_output_mod(c)
	c.research_done.erase("industry_2")
	Research._complete(c, "industry_2", false)
	near(Military.sp_output_mod(c), mod0 + 0.1, 0.0001, "Gölge Fabrikalar fabrika çıktısını +%10 artırır")
	near(Military.sp_income(c), base / mod0 * (mod0 + 0.1), 0.01, "SP geliri fabrika çıktısıyla çarpılır")
	var sp0 := c.sp
	var inc := Military.sp_income(c)
	Military._sp_income()
	near(c.sp - sp0, inc, 0.01, "günlük gelir aynı katla eklenir")

## Silahlanma Bakanı (fabrika çıktısı +%7) SP'yi artırır; istikrar düşünce SP düşer (siyaset ekranındaki "fabrika çıktısı")
func test_advisor_and_stability_move_sp() -> void:
	var c := player()
	c.political_power = 500.0
	var base := Military.sp_income(c)
	Politics.hire(c, "armaments_minister")
	check("armaments_minister" in c.advisors, "danışman atanır")
	gt(Military.sp_income(c), base, "Silahlanma Bakanı SP gelirini artırır")
	var before := Military.sp_income(c)
	c.stability = clampf(c.stability - 0.4, 0.0, 1.0)
	lt(Military.sp_income(c), before, "istikrar düşünce SP geliri düşer")

## Araştırmadaki hiçbir etki ölü değil: her etkiyi motor okur (eski "üretim verimlilik tavanı" ve "sentetik rafineri" gibi)
func test_research_effects_are_live() -> void:
	var dead := []
	for id: String in Research.techs:
		for k: String in (Research.techs[id].get("effects", {}) as Dictionary):
			if not k in LIVE_TECH_EFFECTS:
				dead.append("%s: %s" % [id, k])
	for cat: String in (Research.repeatable.get("effects", {}) as Dictionary):
		for k: String in (Research.repeatable["effects"][cat] as Dictionary):
			if not k in LIVE_TECH_EFFECTS:
				dead.append("rep_%s: %s" % [cat, k])
	none(dead, "oyunda karşılığı olmayan araştırma etkisi")

## Yakın destek uçağı, onu açan araştırma bitmeden alınmaz; bitince alınır
func test_unlock_research_gates_air_recruit() -> void:
	var c := player()
	c.sp = 5000.0
	var cap := World.capital_province(c.tag)
	eq(Military.recruit_tech("cas"), "cas_1", "yakın destek uçağını açan teknoloji")
	eq(Military.recruit_tech("infantry"), "", "piyade serbest")
	c.research_done.erase("cas_1")
	eq(Military.recruit_error(c, "cas", cap), "RECRUIT_ERR_TECH", "araştırmadan yakın destek kanadı alınmaz")
	Research._complete(c, "cas_1", false)
	eq(Military.recruit_error(c, "cas", cap), "", "araştırınca alınır")
	var n0 := Air.wings_of(c.tag).size()
	eq(Military.recruit(c, "cas", cap), "", "yakın destek kanadı alınır")
	eq(Air.wings_of(c.tag).size(), n0 + 1, "yeni kanat kurulur")

## Zırhlı gemi, Zırhlılar araştırılmadan limanda alınmaz
func test_unlock_research_gates_ships() -> void:
	var c := player()
	c.sp = 5000.0
	var pid := _port_city(c)
	gt(pid, 0, "İtalya'nın deniz üslü bir limanı")
	eq(Military.recruit_tech("battleship"), "battleship_1", "zırhlıyı açan teknoloji")
	c.research_done.erase("battleship_1")
	eq(Military.recruit_error(c, "battleship", pid), "RECRUIT_ERR_TECH", "araştırmadan zırhlı alınmaz")
	Research._complete(c, "battleship_1", false)
	eq(Military.recruit_error(c, "battleship", pid), "", "araştırınca alınır")

## Askerlik yasası eğitim süresini değiştirir (genel seferberlik +%40) ve yeni tümen bu süreyi alır
func test_conscription_law_changes_training_days() -> void:
	var c := player()
	c.laws["conscription"] = "one_year_service"
	eq(Military.recruit_days(c, "infantry"), 7, "bir yıllık mükellefiyette piyade 7 günde hazır")
	c.laws["conscription"] = "levee_en_masse"
	var long := Military.recruit_days(c, "infantry")
	eq(long, roundi(7 * 1.4), "genel seferberlikte eğitim +%40")
	c.sp = 5000.0
	eq(Military.recruit(c, "infantry", World.capital_province(c.tag)), "", "piyade alınır")
	eq(_newest(c.tag).training, long, "yeni tümen yasanın eğitim süresini alır")

## Orta tank araştırılınca yeni zırhlı tümenler orta tankla kurulur (şablon bir kez eklenir) ve daha güçlüdür
func test_medium_tank_research_upgrades_new_armor() -> void:
	var c := player()
	c.sp = 5000.0
	c.research_done.erase("medium_tank_1")
	eq(Military.recruit_template(c, "armor"), 1, "orta tank yokken hafif tanklı zırhlı tümen")
	Research._complete(c, "medium_tank_1", false)
	var ti := Military.recruit_template(c, "armor")
	check((c.templates[ti]["battalions"] as Dictionary).has("medium_armor"), "orta tank araştırılınca orta tanklı şablon")
	eq(Military.recruit_template(c, "armor"), ti, "şablon bir kez eklenir")
	gt(float(Military.stats(c, ti)["hard"]), float(Military.stats(c, 1)["hard"]), "orta tanklı tümenin tanksavar ateşi daha yüksek")
	eq(Military.recruit(c, "armor", World.capital_province(c.tag)), "", "zırhlı tümen alınır")
	eq(_newest(c.tag).template, ti, "yeni tümen orta tanklı şablonla kurulur")

## Hava kanadının eksiği önce stoktan, kalanı SP ile tamamlanır; SP ve stok yoksa bir şey olmaz
func test_air_reinforce_buys_missing_planes_with_sp() -> void:
	var c := player()
	var own := Air.wings_of(c.tag)
	if own.is_empty():
		c.stockpile["fighter_equipment"] = float(Air.WING_SIZE)
		Air.deploy(c, "fighter", Air._home_base(c.tag))
		own = Air.wings_of(c.tag)
	check(not own.is_empty(), "İtalya'nın hava kanadı")
	var w: AirWing = own[0]
	var eq_name: String = Air.TYPES[w.type]["eq"]
	w.planes = 60
	c.stockpile[eq_name] = 10.0
	c.sp = 1000.0
	var plan := Air.reinforce_plan(w)
	eq(int(plan[0]), 10, "önce stoktaki 10 uçak")
	eq(int(plan[1]), 30, "kalan 30 uçak SP ile")
	near(float(plan[2]), 30.0 * Air.plane_sp(w.type), 0.001, "uçak başına bedel kanadın şehirdeki fiyatının yüzde biri")
	Air.reinforce(w)
	eq(w.planes, Air.WING_SIZE, "kanat dolar")
	near(c.sp, 1000.0 - float(plan[2]), 0.001, "SP harcanır")
	near(float(c.stockpile[eq_name]), 0.0, 0.001, "stok kullanılır")
	w.planes = 50
	c.sp = 0.0
	Air.reinforce(w)
	eq(w.planes, 50, "SP ve stok yokken kanat değişmez")

## Asker alma uyarısı yalnız başkentte gerçekten alınabilecek bir birlik varken çıkar
func test_recruit_alert_only_when_something_can_be_bought() -> void:
	var c := player()
	var alerts := AlertBar.new()
	var hud := Hud.new()
	alerts.hud = hud
	c.sp = 0.0
	check(not _has_alert(alerts._collect(c), "recruit"), "SP yokken asker alma uyarısı çıkmaz")
	c.sp = 130.0
	check(_has_alert(alerts._collect(c), "recruit"), "piyadeye yetince uyarı çıkar")
	alerts.free()
	hud.free()
