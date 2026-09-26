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
	Economy.change_law(c, "conscription", "limited_conscription")
	Politics.hire(c, "silent_workhorse")
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
