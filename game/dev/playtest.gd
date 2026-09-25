extends SceneTree
## Oyuncu akışı testi: TUR -> IRQ savaşı, tümen emirleri, teslim alma, kaydet/yükle.
func _init() -> void:
	await process_frame
	var W = root.get_node("World")
	var clock = root.get_node("GameClock")
	var mil = root.get_node("Military")
	var dip = root.get_node("Diplomacy")
	var game = root.get_node("Game")
	var ai = root.get_node("AI")
	W.start_game("TUR")
	var tur = W.countries["TUR"]
	var irq = W.countries["IRQ"]
	W.world_tension = 40.0
	W.notification.connect(func(t: String, _k: String) -> void: print("    [%d-%02d-%02d] %s" % [clock.year, clock.month, clock.day, t]))
	tur.political_power = 200.0
	var ok := [0, 0]
	var check := func(name: String, cond: bool) -> void:
		print(("  OK   " if cond else "  FAIL ") + name)
		ok[0 if cond else 1] += 1
	check.call("gerekçe başlatılır", dip.justify(tur, irq))
	clock.advance_hours(24 * 31)
	check.call("gerekçe hazır", tur.war_goals.has("IRQ"))
	check.call("savaş ilanı", dip.declare_war("TUR", "IRQ"))
	check.call("savaşta", dip.are_enemies("TUR", "IRQ"))
	# Irak sınırındaki bölgeye tüm Türk tümenlerini gönder
	var target := 0
	for city in W.cities:
		if city.names.values().has("Musul") or city.name == "Mosul":
			target = city.province_id
	check.call("Musul bulundu", target > 0)
	var sent := 0
	for d in mil.country_divisions("TUR"):
		if mil.order_move(d, target):
			sent += 1
	check.call("hareket emri (%d tümen)" % sent, sent > 5)
	for i in 200:
		clock.advance_hours(24)
		W.flush_ownership()
		# ilerlemeye devam: ele geçirilen her yerden bir sonraki Irak bölgesine
		if i % 5 == 0:
			for d in mil.country_divisions("TUR"):
				if d.path.is_empty() and d.attacking == 0:
					var best: int = W.capital_province("IRQ")
					if W.controller_tag(best) != "IRQ":
						best = 0
						var bd := INF
						for pid in range(1, W.controller.size()):
							if W.controller_tag(pid) == "IRQ" and W.province(pid).city:
								var dd: float = W.province(pid).center.distance_to(W.province(d.province).center)
								if dd < bd:
									bd = dd
									best = pid
					if best > 0:
						mil.order_move(d, best)
		if i % 10 == 0:
			var n := 0
			for pid in range(1, W.controller.size()):
				if W.controller_tag(pid) == "TUR" and W.owner_of_province(pid) and W.owner_of_province(pid).tag == "IRQ": n += 1
			print("    gün %d: işgal edilen Irak bölgesi=%d teslim=%.2f IRQ tümen=%d" % [i, n, irq.surrender_progress, mil.country_divisions("IRQ").size()])
		if not irq.exists() or not dip.are_enemies("TUR", "IRQ"):
			print("  gün %d: savaş bitti" % i)
			break
	check.call("Irak teslim oldu / ilhak", not dip.are_enemies("TUR", "IRQ"))
	check.call("Türkiye toprak kazandı", tur.states.size() > 42)
	check.call("kaydet", game.save_game("test_kayit"))
	var date_before: String = clock.date_string()
	var states_before: int = tur.states.size()
	var divs_before: int = mil.country_divisions("TUR").size()
	check.call("yükle", game.load_game("test_kayit"))
	check.call("tarih korunur (%s)" % clock.date_string(), clock.date_string() == date_before)
	check.call("eyaletler korunur", W.countries["TUR"].states.size() == states_before)
	check.call("tümenler korunur", mil.country_divisions("TUR").size() == divs_before)
	print("SONUÇ: %d başarılı, %d başarısız" % [ok[0], ok[1]])
	quit()
