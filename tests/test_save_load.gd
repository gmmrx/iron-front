extends "res://tests/test_case.gd"
## Kayıt/yükleme: 200 gün oyna → kaydet → yükle (oyunun kendi akışıyla) → tüm ülke, tümen, ordu, filo, kanat,
## eyalet ve diplomasi alanları aynı. Fark varsa hangi alan olduğu yazılır.

const SLOT := "_test_kayit"
var _snap := preload("res://tests/snapshot.gd").new()

## Oyuncunun (TUR) tipik eylemleri: savaş, ticaret, yasa, odak, araştırma, danışman, inşaat, tümen/kanat tercihleri
func _play() -> void:
	var c := player()
	c.political_power = 800.0
	World.world_tension = 60.0
	c.war_goals["IRQ"] = true
	Diplomacy.declare_war("TUR", "IRQ")
	Economy.change_law(c, "conscription", "two_year_service")
	Politics.hire(c, "cabinet_secretary")
	for id: String in Politics.tree_of(c):
		if Politics.start_focus(c, id):
			break
	for id: String in Research.techs:
		if Research.can_research(c, id):
			Research.start(c, id)
	Economy.queue_building(c, World.states[c.capital_state], "infrastructure")
	for r: String in ["oil", "rubber", "steel"]:
		var sellers: Array = Economy.trade_sellers(c, r)
		if not sellers.is_empty():
			Economy.add_trade(c, r, sellers[0][0], 8.0)
			break
	var divs := Military.country_divisions("TUR")
	for i in divs.size():
		if i % 3 == 0:
			divs[i].hold = false            # oyuncu "son askere kadar"ı bazı tümenlerde kapatır
	var army: Army = Military.create_army("TUR", divs.slice(0, 10))
	army.enemy = "IRQ"
	army.mode = Army.Mode.ATTACK
	# komuta zinciri: ordular grubu, mareşal, general, terfi, yeni general, doğrudan emirdeki tümen
	var grp := Military.create_group("TUR")
	var marshal: Commander = Military.commanders_of("TUR").filter(func(x: Commander) -> bool: return x.is_marshal())[0]
	Military.assign_group_commander(grp, marshal.id)
	Military.set_army_group(army, grp.id)
	Military.assign_army_commander(army, Military.free_commanders("TUR")[0].id)
	c.command_power = 100.0
	Military.promote(Military.free_commanders("TUR")[0])
	Military.recruit_commander("TUR")
	divs[1].manual = true
	for w in Air.wings_of("TUR"):
		w.auto = true                       # oyuncu bir kanadı yapay zekâya bırakır
		break

func test_save_load_roundtrip() -> void:
	_play()
	days(200)
	player().auto_trade = true              # oyuncu otomatik ticareti açtı
	Economy._run_trade()
	var before: Dictionary = _snap.take()
	if not check(Game.save_game(SLOT), "kaydet"):
		return
	if not check(Game.load_game(SLOT), "yükle"):
		return
	World.resume_game(World.player_tag)     # main.gd kayıttan devam ederken bunu çağırır
	var after: Dictionary = _snap.take()
	none(_snap.diff_fields(before, after), "kayıt/yükleme farkı")
	DirAccess.remove_absolute(Game.SAVE_DIR + SLOT + ".json")

## Yükledikten sonra oyun aynı şekilde sürer: bir gün daha oynanınca hata yok ve tarih ilerler
func test_loaded_game_continues() -> void:
	_play()
	days(30)
	check(Game.save_game(SLOT), "kaydet")
	check(Game.load_game(SLOT), "yükle")
	World.resume_game(World.player_tag)
	var d0 := World.date_value()
	days(5)
	gt(World.date_value(), d0, "yüklenen oyun ilerler")
	DirAccess.remove_absolute(Game.SAVE_DIR + SLOT + ".json")

## Eski kayıt (yeniden adlandırılmadan önceki yasa, danışman ve ulusal durum kimlikleri): yüklenir, bilinmeyen yasa
## başlangıç yasasına döner, bilinmeyen danışman/durum atlanır, Hükümet ekranının okuduğu tanımlar eksiksiz
func test_old_save_ids_are_sanitized() -> void:
	var c := player()
	check(Game.save_game(SLOT), "kaydet")
	var path := Game.SAVE_DIR + SLOT + ".json"
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var cd: Dictionary = data["countries"][c.tag]
	cd["laws"] = {"conscription": "volunteer_only", "economy": "civilian_economy", "trade": "export_focus"}
	cd["advisors"] = ["silent_workhorse", "cabinet_secretary"]
	(cd["spirits"] as Array).append("sectarian_woes")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	if not check(Game.load_game(SLOT), "eski kayıt yüklenir"):
		return
	World.resume_game(World.player_tag)
	c = player()                            # yükleme ülke nesnelerini yeniden kurar
	for g: String in Economy.law_groups:
		check(Economy.law_groups[g]["laws"].has(c.laws[g]), "%s yasası tanımlı (%s)" % [g, c.laws[g]])
	eq(c.laws["conscription"], "one_year_service", "bilinmeyen askerlik yasası başlangıç yasasına döner")
	eq(Array(c.advisors), ["cabinet_secretary"], "bilinmeyen danışman atlanır")
	check(not "sectarian_woes" in c.spirits, "bilinmeyen ulusal durum atlanır")
	for id: String in c.advisors:
		check(Politics.advisor_defs.has(id), "danışman tanımı var: " + id)
	days(2)
	DirAccess.remove_absolute(path)
