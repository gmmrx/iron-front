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
