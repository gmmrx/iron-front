extends "res://tests/test_case.gd"
## Kara kuvvetleri: konuşlandırma ve eğitim.

## Askerlik yasasının eğitim süresi etkisi (training_time) yeni tümene uygulanır
func test_training_time_follows_conscription_law() -> void:
	var c := player()
	c.laws["conscription"] = "volunteer_only"
	eq(Military.training_days(c), Military.TRAINING_DAYS, "gönüllülükte eğitim süresi")
	c.laws["conscription"] = "extensive_conscription"      # training_time +%10
	eq(Military.training_days(c), roundi(Military.TRAINING_DAYS * 1.1), "geniş seferberlikte eğitim süresi")
	c.laws["conscription"] = "scraping_the_barrel"         # +%50
	eq(Military.training_days(c), roundi(Military.TRAINING_DAYS * 1.5), "son kaynakta eğitim süresi")
	c.political_power = 0.0
	for e: String in Military.stats(c, 0)["equipment"]:
		c.stockpile[e] = 100000.0
	c.manpower_used = 0
	var d: Division = Military.deploy(c, 0)
	if check(d != null, "tümen konuşlanmalı"):
		eq(d.training, roundi(Military.TRAINING_DAYS * 1.5), "yeni tümenin eğitim günü")
