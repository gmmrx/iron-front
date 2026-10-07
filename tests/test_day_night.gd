extends "res://tests/test_case.gd"
## Gece ve gündüz: güneşin yeri tarihten ve saatten (UTC), gece payı güneş yüksekliğinden (DayNight)

func test_subsolar_point_follows_hour_and_season() -> void:
	near(DayNight.subsolar(80.0, 12.0).x, 0.0, 0.01, "12:00 UTC'de güneş Greenwich'in tepesinde")
	near(DayNight.subsolar(80.0, 0.0).x, 180.0 if DayNight.subsolar(80.0, 0.0).x > 0.0 else -180.0, 0.01, "00:00'da tarih çizgisinde")
	near(DayNight.subsolar(80.0, 18.0).x, -90.0, 0.01, "18:00'de 90° batıda")
	near(DayNight.subsolar(81.0, 12.0).y, 0.0, 1.5, "ilkbahar ekinoksunda ekvatorda")
	near(DayNight.subsolar(172.0, 12.0).y, 23.44, 0.5, "yaz gündönümünde Yengeç dönencesinde")
	near(DayNight.subsolar(355.0, 12.0).y, -23.44, 0.5, "kış gündönümünde Oğlak dönencesinde")

func test_night_share_at_ankara() -> void:
	var ankara := Vector2(32.85, 39.93)
	var jan := 1.0
	check(DayNight.night_of(DayNight.sun_height(ankara, DayNight.subsolar(jan, 0.0))) > 0.99, "ocakta 00:00 UTC Ankara'da gece")
	check(DayNight.night_of(DayNight.sun_height(ankara, DayNight.subsolar(jan, 10.0))) < 0.01, "ocakta 10:00 UTC Ankara'da gündüz")
	var dusk := DayNight.night_of(DayNight.sun_height(ankara, DayNight.subsolar(jan, 14.25)))
	check(dusk > 0.05 and dusk < 0.95, "akşam alacakaranlığı geçişli (%.2f)" % dusk)

func test_game_starts_in_the_morning_at_player_capital() -> void:
	# koşucu her testten önce World.start_game(oyuncu) çağırır
	var cap: StateRegion = World.states[player().capital_state]
	var lon := World.lonlat(World.province(cap.provinces[0]).center).x
	eq(GameClock.utc_offset, roundi(lon / 15.0), "saat farkı başkentin boylamından")
	check(GameClock.date_string().ends_with("07:00"), "saat yerel 07:00 gösterir: %s" % GameClock.date_string())
	lt(GameClock.night_at(World.province(cap.provinces[0]).center), 0.5, "başkentte gün ağarmış")

func test_night_attack_penalty_and_short_sight() -> void:
	var pid: int = World.states[player().capital_state].provinces[0]
	var p := World.province(pid)
	var lon := World.lonlat(p.center).x
	GameClock.month = 6
	GameClock.day = 21
	GameClock.hour = posmod(roundi(12.0 - lon / 15.0), 24)          # yerel öğle
	near(Military.night_attack_malus(pid), 0.0, 0.001, "gündüz gece cezası yok")
	GameClock.hour = posmod(roundi(0.0 - lon / 15.0), 24)           # yerel gece yarısı
	near(Military.night_attack_malus(pid), -Military.night_attack, 0.001, "gece yarısı tam ceza (units.json night.attack)")
	lt(Military.night_attack, 0.0, "night.attack negatif: saldırıyı düşürür")

func test_night_sight_is_one_province() -> void:
	var pid: int = World.states[player().capital_state].provinces[0]
	var lon := World.lonlat(World.province(pid).center).x
	Military._fog = PackedByteArray()
	Military._fog.resize(World.provinces.size())
	GameClock.hour = posmod(roundi(0.0 - lon / 15.0), 24)           # yerel gece yarısı
	Military._explore(pid, true)
	eq(Military._fog[pid], 2, "gece bulunduğu bölge görülür")
	var q: int = World.province(pid).adjacent[0]
	eq(Military._fog[q], 0, "gece komşu bölge görülmez")
	GameClock.hour = posmod(roundi(12.0 - lon / 15.0), 24)          # yerel öğle
	Military._explore(pid, true)
	eq(Military._fog[q], 2, "gün doğunca komşu da görülür")
