extends "res://tests/test_case.gd"
## Kara kuvvetleri: konuşlandırma ve eğitim.

## Askerlik yasasının eğitim süresi etkisi (training_time) yeni tümene uygulanır
func test_training_time_follows_conscription_law() -> void:
	var c := player()
	c.laws["conscription"] = "professional_army"
	eq(Military.training_days(c), Military.TRAINING_DAYS, "profesyonel orduda eğitim süresi")
	c.laws["conscription"] = "two_year_service"            # training_time −%5 (eğitimli ihtiyat)
	eq(Military.training_days(c), roundi(Military.TRAINING_DAYS * 0.95), "iki yıllık mükellefiyette eğitim süresi")
	c.laws["conscription"] = "levee_en_masse"              # +%40
	eq(Military.training_days(c), roundi(Military.TRAINING_DAYS * 1.4), "kitlesel celpte eğitim süresi")
	c.political_power = 0.0
	for e: String in Military.stats(c, 0)["equipment"]:
		c.stockpile[e] = 100000.0
	c.manpower_used = 0
	var d: Division = Military.deploy(c, 0)
	if check(d != null, "tümen konuşlanmalı"):
		eq(d.training, roundi(Military.TRAINING_DAYS * 1.4), "yeni tümenin eğitim günü")

## Tahmini varış (seçili tümenle bölge kartında): gerçek yürüyüşle uyuşur; kendi bölgesine 0
func test_eta_matches_march() -> void:
	var tag := World.player_tag
	var d: Division = null
	var target := 0
	for cand: Division in Military.country_divisions(tag):
		if cand.training > 0 or not World.province(cand.province).is_land():
			continue
		# kendi toprağında 3 adım ötedeki bir bölge
		var seen := {cand.province: true}
		var frontier: Array[int] = [cand.province]
		for i in 3:
			var nxt: Array[int] = []
			for cur in frontier:
				for n in World.land_neighbors(cur):
					if not seen.has(n) and World.controller_tag(n) == tag:
						seen[n] = true
						nxt.append(n)
			frontier = nxt
		if not frontier.is_empty():
			d = cand
			target = frontier[0]
			break
	if not check(d != null, "3 bölge ötesine yürüyebilecek tümen"):
		return
	eq(Military.eta_hours(d, d.province), 0.0, "kendi bölgesine varış 0")
	var eta := Military.eta_hours(d, target)
	gt(eta, 0.0, "tahmini varış")
	check(Military.order_move(d, target), "yürüme emri")
	var steps := d.path.size()
	var hours := 0
	while d.province != target and hours < 24 * 60:
		GameClock.advance_hours(1)
		hours += 1
	eq(d.province, target, "tümen hedefe vardı")
	check(float(hours) >= eta - 1.0 and float(hours) <= eta + steps + 2.0,
		"gerçek yürüyüş %d saat, tahmin %.1f saat (%d adım)" % [hours, eta, steps])

## Yol bulunamayınca oyuncuya neden söylenir: izin olmayan ülke adıyla; kendi toprağında yol var
func test_no_path_reason_names_country() -> void:
	var tag := World.player_tag
	var from := World.capital_province(tag)
	var gre: Country = World.countries["GRE"]
	var to := World.capital_province("GRE")
	check(Military.find_path(tag, from, to).is_empty(), "izinsiz Yunan toprağına yol olmamalı")
	var why := Military.no_path_reason(tag, from, to)
	check(why.contains(gre.display_name()), "neden Yunanistan'ı anmalı: %s" % why)
	# Bulgaristan'ın ötesindeki ülke: hedefin kendisi izinsiz, adı o ülke
	var bul: Country = World.countries["BUL"]
	why = Military.no_path_reason(tag, from, World.capital_province("BUL"))
	check(why.contains(bul.display_name()), "neden Bulgaristan'ı anmalı: %s" % why)


## Birlik adları ülkenin kendi dilinde (arayüz dilinden bağımsız): Türkiye Türkçe, Almanya Almanca, İngiltere İngilizce
## sıra sayısıyla, Fransa Fransızca; adı tanımlı olmayan kültür İngilizceye düşer
func test_unit_names_in_own_language() -> void:
	eq(UnitNames.name_of("TUR", "infantry", 1), "1. Piyade Tümeni", "Türk tümeni")
	eq(UnitNames.name_of("GER", "armored", 3), "3. Panzer-Division", "Alman zırhlı tümeni")
	eq(UnitNames.name_of("ENG", "infantry", 2), "2nd Infantry Division", "İngiliz tümeni")
	eq(UnitNames.name_of("ENG", "army", 11), "11th Army", "İngiliz ordusu (11th)")
	eq(UnitNames.name_of("FRA", "army", 1), "1re Armée", "Fransız ordusu")
	eq(UnitNames.name_of("SOV", "army_group", 2), "2-y Front", "Sovyet ordular grubu")
	eq(UnitNames.name_of("ETH", "fleet", 1), "1st Fleet", "adı tanımsız kültür İngilizce")
	var ger: Country = World.countries["GER"]
	var d := Military.deploy(ger, 0, 0, true)
	if d == null:
		for e: String in Military.stats(ger, 0)["equipment"]:
			ger.stockpile[e] = 100000.0
		ger.manpower_used = 0
		d = Military.deploy(ger, 0, 0, true)
	if check(d != null, "Alman tümeni konuşlandı"):
		check(d.name.ends_with("Infanterie-Division"), "Alman tümeninin adı Almanca: %s" % d.name)
	for f in Navy.fleets_of("JAP"):
		check(f.name.begins_with("Dai ") or f.name.begins_with("Yobi"), "Japon filosunun adı Japonca: %s" % f.name)
		break

## Gerçekçi yürüyüş: piyade günde ~33 km (eskiden 96), zırhlı piyadeden hızlı; yürürken bütünlük düşer (en çok %60'a),
## durunca toparlanır. Yürüme menzili (Ctrl ile gösterilen): yakın bölge kısa, uzak bölge uzun sürer
func test_realistic_march() -> void:
	var c := player()
	var inf: Division = null
	for d in Military.country_divisions(c.tag):
		if d.training == 0 and World.province(d.province).is_land() and float(Military.div_stats(d)["speed"]) <= 4.01:
			inf = d
			break
	if not check(inf != null, "piyade tümeni"):
		return
	var n := 0
	for q in World.land_neighbors(inf.province):
		if World.controller_tag(q) == c.tag:
			n = q
			break
	if not check(n != 0, "kendi komşu bölgesi"):
		return
	var kmh := Military._speed(inf, n)
	# 29 Eylül 2026: yürüyüş kullanıcının isteğiyle hızlandı (MARCH_FACTOR 1,0: takviye savaşa yetişsin, kısa
	# senaryolarda cephe değiştirmek oyunu durdurmasın); piyade günde ~80–95 km
	lt(kmh * 24.0, 110.0, "piyade günde 110 km'den az yürür: %.1f" % (kmh * 24.0))
	gt(kmh * 24.0, 15.0, "ama 15 km'den çok: %.1f" % (kmh * 24.0))
	var full: float = Military.div_stats(inf)["org"]
	inf.org = full
	check(Military.order_move(inf, n), "yürüme emri")
	for i in 5:
		Military._move_all()
	lt(inf.org, full, "yürürken bütünlük düşer")
	inf.org = full * 0.61
	for i in 20:
		Military._move_all()
	gt(inf.org, full * Military.MARCH_ORG_FLOOR - 0.001, "en çok %60'a kadar düşer")
	var reach := Military.reach_hours(inf, 5000.0)
	if check(reach.has(n), "komşu bölge menzilde"):
		near(float(reach[n]), World.distance_km(inf.province, n) / Military._speed(inf, n), 0.5, "komşuya varış = uzaklık / hız")
	eq(float(reach[inf.province]), 0.0, "bulunduğu yer 0 saat")
	var short := Military.reach_hours(inf, 24.0)
	for pid: int in short:
		check(float(short[pid]) <= 24.0, "1 günlük menzilde yalnız 1 günde varılanlar")

## Yürüyen tümene yeni emir: geri ışınlanmaz — yürümekte olduğu bacağı bitirir (ilerleme korunur), yeni yola oradan döner
func test_reroute_keeps_current_leg() -> void:
	var c := player()
	var d: Division = null
	var a := 0
	var b := 0
	for x in Military.country_divisions(c.tag):
		if x.training > 0 or not World.province(x.province).is_land():
			continue
		var ns: Array = []
		for q in World.land_neighbors(x.province):
			if World.controller_tag(q) == c.tag:
				ns.append(q)
		if ns.size() >= 2:
			d = x
			a = ns[0]
			b = ns[1]
			break
	if not check(d != null, "iki kendi komşusu olan tümen"):
		return
	check(Military.order_move(d, a), "ilk emir")
	d.progress = World.distance_km(d.province, a) * 0.5          # yolun yarısında
	check(Military.order_move(d, b), "yeni emir")
	eq(d.path[0], a, "önce yürümekte olduğu bacağı bitirir")
	gt(d.progress, 0.0, "ilerleme korunur (başa ışınlanmaz)")
	eq(d.path[d.path.size() - 1], b, "sonra yeni hedefe")
