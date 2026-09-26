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
