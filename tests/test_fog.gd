extends "res://tests/test_case.gd"
## Savaş sisi: müttefik olmayan her ülkenin tümeni yalnız görünür bölgelerde (bizim/müttefik kontrolü, tümenlerimiz,
## bunların komşuları, keşif bölgeleri) görünür; bulutun altında gizli; keşif sisi açar; izleyici kipinde sis yok;
## düzeyler (0 bulut, 1 sınır şeridi, 2 açık). Oyuncu Almanya.

func player_tag() -> String:
	return "GER"

func _war() -> void:
	Military.fog_enabled = true
	country("GER").war_goals["POL"] = true
	Diplomacy.declare_war("GER", "POL")
	Military.invalidate_fog()

## Polonya'nın, Alman tarafına iki adımdan uzak bir kara bölgesi ve Almanya'ya komşu bir Polonya bölgesi
func _deep_and_border() -> Array:
	var deep := 0
	var border := 0
	for pid in range(1, World.provinces.size()):
		var p := World.province(pid)
		if p == null or not p.is_land() or World.controller_tag(pid) != "POL":
			continue
		var near := false
		for q in World.land_neighbors(pid):
			if World.controller_tag(q) == "GER":
				near = true
		if near and border == 0:
			border = pid
		if not near and deep == 0 and Military.is_visible(pid) == false:
			deep = pid
	return [deep, border]

func test_enemy_hidden_beyond_sight() -> void:
	GameClock.hour = 12                         # Avrupa'da gündüz: gece görüşü test_day_night'ta
	_war()
	var db := _deep_and_border()
	if not check(db[0] > 0 and db[1] > 0, "derin ve sınır Polonya bölgesi"):
		return
	var deep: Division = Military._create(country("POL"), 0, db[0], 1.0, 0)
	var edge: Division = Military._create(country("POL"), 0, db[1], 1.0, 0)
	check(Military.hidden(deep), "görüş dışındaki düşman tümeni gizli")
	check(not Military.hidden(edge), "sınırdaki düşman tümeni görünür")
	for d in Military.country_divisions("GER"):
		check(not Military.hidden(d), "kendi tümenimiz hiç gizlenmez")
		break
	# tarafsız ülke de bulutun altında gizli; müttefik (İtalya) her yerde görünür
	var swe: Division = Military._create(country("SWE"), 0, World.capital_province("SWE"), 1.0, 0)
	check(Military.hidden(swe), "bulutun altındaki tarafsız tümen gizli")
	# düzeyler: kendi toprağımız açık, sınır komşusu şerit, derin bölge bulut
	var lv := Military.fog_levels()
	eq(int(lv[World.capital_province("GER")]), 2, "kendi toprağımız açık")
	eq(int(lv[db[1]]), 2, "sınır komşusu keşfedilmiş (bir bölge derin görülür)")
	eq(int(lv[db[0]]), 0, "derin bölge bulut")
	# bölgeyi alınca komşusu görünür olur
	World.set_controller(db[1], "GER")
	Military.invalidate_fog()
	var n_ok := false
	for q in World.land_neighbors(db[1]):
		if World.controller_tag(q) == "POL" and Military.is_visible(q):
			n_ok = true
	check(n_ok, "ele geçen bölgenin komşuları görünür")
	# izleyici kipinde sis yok
	Game.observer = true
	check(not Military.hidden(deep), "izleyici kipinde sis yok")
	Game.observer = false

func test_recon_reveals_zone() -> void:
	_war()
	var db := _deep_and_border()
	if not check(db[0] > 0, "derin Polonya bölgesi"):
		return
	var deep: Division = Military._create(country("POL"), 0, db[0], 1.0, 0)
	check(Military.hidden(deep), "keşif yokken gizli")
	var ger := country("GER")
	ger.stockpile[Air.TYPES["fighter"]["eq"]] = 500.0
	var w: AirWing = Air.deploy(ger, "fighter", Air._home_base("GER"))
	if not check(w != null, "kanat"):
		return
	eq(Air.assign(w, db[0], AirWing.Mission.RECON), "", "keşif görevi")
	check(db[0] in Air.recon_provinces("GER"), "keşif bölgesi hedefi kapsar")
	Military.invalidate_fog()
	check(not Military.hidden(deep), "keşif bölgesindeki düşman görünür")
	Air.set_mission(w, AirWing.Mission.IDLE)
	Military.invalidate_fog()
	check(not Military.hidden(deep), "keşfedilen yer kalıcı: keşif bitince de görünür")

func test_marching_explores() -> void:
	GameClock.hour = 12                         # Avrupa'da gündüz: gece görüşü test_day_night'ta
	_war()
	var db := _deep_and_border()
	if not check(db[0] > 0, "derin Polonya bölgesi"):
		return
	check(not Military.is_visible(db[0]), "başta bulutta")
	# Alman tümeni derin bölgeye girince orası ve komşuları keşfedilir
	var d: Division = Military._create(country("GER"), 0, World.capital_province("GER"), 1.0, 0)
	Military.is_visible(1)                      # sis kurulsun
	Military._move_to(d, db[0])
	check(Military.is_visible(db[0]), "asker gittiği yeri keşfeder")
	for q in World.province(db[0]).adjacent:
		check(Military.is_visible(q), "bir bölge ötesi de")
		break
