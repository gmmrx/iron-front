extends "res://tests/test_case.gd"
## Oyun modları (docs/modlar/README.md): kayıt defteri, manifest doğrulaması, WWII değerlerinin kilidi, patch birleştirme,
## her modun motor sözleşmesi, mod geçişinin temizliği ve kayıt/yükleme uyumu.

const SLOT := "_test_mod"
const ENGINE_EVENTS := ["call_to_arms", "white_peace", "election", "faction_invite"]   ## motorun kendisinin açtığı olaylar

var _snap := preload("res://tests/snapshot.gd").new()

func _save_path() -> String:
	return Game.SAVE_DIR + SLOT + ".json"

# ------------------------------------------------------------------ kayıt defteri ve manifest
func test_registry() -> void:
	var all := GameModes.ids(true)
	check(GameModes.BASE_MODE in all, "ww2 kayıtlı")
	eq(GameModes.default_id(), GameModes.BASE_MODE, "varsayılan mod")
	eq(GameModes.ids()[0], GameModes.default_id(), "menüde ilk mod varsayılan")
	var seen := {}
	for mid: String in all:
		check(not seen.has(mid), "mod kimliği tekrar etmiyor: " + mid)
		seen[mid] = true
		check(GameModes.exists(mid), "%s: data/modes/%s/mode.json var" % [mid, mid])
	# kayıtsız mod klasörü kalmasın (eklenip modes.json'a yazılmamış)
	for d: String in DirAccess.get_directories_at(GameModes.MODES_DIR):
		check(d in all, "data/modes/%s klasörü modes.json'da kayıtlı (tools/new_mode.py yazar)" % d)
	check("_template" in all and not "_template" in GameModes.ids(), "_template gizli ama kayıtlı")

## Her modun manifesti ve dosyaları: sorunlar insan dilinde (GameModes.validate)
func test_manifests_valid() -> void:
	var p: Array = []
	for mid: String in GameModes.ids(true):
		p.append_array(GameModes.validate(mid))
	none(p, "mod doğrulaması")

## WWII modu bugünkü sabitlerle aynı: bu test kırmızıysa WWII davranışı değişmiş demektir
func test_ww2_locked() -> void:
	eq(GameModes.id, GameModes.BASE_MODE, "etkin mod")
	eq(GameModes.start_date(), [1936, 1, 1], "başlangıç tarihi")
	eq(GameModes.end_date_int(), Game.END_DATE, "bitiş tarihi")
	eq(Game.end_date(), 19480101, "Game.end_date")
	eq(float(GameModes.get_value("start_tension")), 0.0, "başlangıç kriz endeksi")
	eq(GameModes.default_player(), "TUR", "varsayılan oyuncu")
	eq(Array(GameModes.featured()), Array(CountrySelect.FEATURED), "öne çıkan ülkeler")
	eq(str(GameModes.get_value("menu_focus")), "GER", "menü kamerası")
	eq(Array(GameModes.start_techs()), Array(Research.START_TECHS), "başlangıç teknolojileri")
	eq(GameModes.start_techs_min_population(), 15000000, "başlangıç teknolojisi nüfus eşiği")
	for t: String in ["GER", "ENG", "FRA", "ITA", "SOV"]:
		check(country(t).is_major(), t + " büyük güç")
	check(not country("TUR").is_major(), "TUR büyük güç değil")
	eq(int(GameModes.sub("ai", "rearm_year")), 1939, "AI yeniden silahlanma yılı")
	eq(AI._cautious_until, 19420101, "AI temkin tarihi")
	eq(AI._phoney_days, AI.PHONEY_WAR_DAYS, "AI garip savaş günleri")
	eq(AI._hold_fire_days, 240, "büyük güç ateşkes günleri")
	eq(Military._phoney_days, Military.PHONEY_DAYS, "muharebe garip savaş günleri")
	check(Game.rules == null, "WWII'de kural betiği yok")
	eq(GameModes.save_prefix(), "", "WWII kayıt adları değişmez")
	for p: String in [World.COUNTRIES_PATH, Politics.EVENTS_PATH, Economy.LAWS_PATH, Economy.HISTORY_PATH]:
		eq(GameModes.path(p), p, "WWII veri yolu değişmez: " + p)
		check(not FileAccess.file_exists(GameModes.patch_path(p)), "WWII'de patch yok: " + p)
	eq(DirAccess.get_files_at(GameModes.MODES_DIR + "ww2/"), PackedStringArray(["mode.json"]), "ww2 klasöründe yalnız manifest")

# ------------------------------------------------------------------ patch birleştirme
func test_patch_merge() -> void:
	var base := {"a": 1, "b": {"x": 1, "y": 2}, "c": [1, 2], "d": 4,
		"list": [{"id": "p", "v": 1}, {"id": "q", "v": 2}, {"id": "r", "v": 3}]}
	var patch := {"b": {"y": 20, "z": 30}, "c": [9], "d": null, "e": 5,
		"list": [{"id": "q", "v": 22}, {"id": "r", "_delete": true}, {"id": "s", "v": 4}]}
	var m: Dictionary = GameModes.merge(base, patch)
	eq(m["a"], 1, "dokunulmayan anahtar kalır")
	eq(m["b"], {"x": 1, "y": 20, "z": 30}, "sözlük özyinelemeli birleşir")
	eq(m["c"], [9], "kimliksiz dizi olduğu gibi değişir")
	check(not m.has("d"), "null anahtarı siler")
	eq(m["e"], 5, "yeni anahtar eklenir")
	eq(m.keys(), ["a", "b", "c", "list", "e"], "temel anahtar sırası korunur, yeniler sona")
	eq(m["list"], [{"id": "p", "v": 1}, {"id": "q", "v": 22}, {"id": "s", "v": 4}], "kimlikli dizi: güncelle, sil, ekle")
	eq(base["b"], {"x": 1, "y": 2}, "temel sözlük değişmez")

# ------------------------------------------------------------------ her modun motor sözleşmesi
## Her mod motorun ön şartlarını karşılar (eksikse oyun ilk günde çöker ya da sessizce yanlış çalışır)
func test_mode_contract() -> void:
	for mid: String in GameModes.ids(true):
		if not check(Game.switch_mode(mid), mid + ": moda geçilir"):
			continue
		World.start_game(GameModes.default_player())
		var p: Array = []
		for e: String in ENGINE_EVENTS:
			if not Politics.events.has(e):
				p.append("%s: '%s' olayı yok — motor bu olayı kendisi açar; silme (patch'ten çıkar)" % [mid, e])
		if not Politics.trees.has("_generic"):
			p.append("%s: focuses.json '_generic' ağacı yok — kendi ağacı olmayan ülkeler bunu kullanır" % mid)
		for g: String in ["conscription", "economy", "trade"]:
			if not Economy.law_groups.has(g):
				p.append("%s: laws.json '%s' yasa grubu yok — AI ve arayüz bu grubu kullanır" % [mid, g])
		for eq_id: String in ["infantry_equipment", "convoy"]:
			if not Economy.equipment.has(eq_id):
				p.append("%s: equipment.json '%s' yok — motor bu ekipmanı doğrudan kullanır" % [mid, eq_id])
		for t: Variant in GameModes.start_techs():
			if not Research.techs.has(str(t)):
				p.append("%s: mode.json start_techs '%s' teknolojisi yok" % [mid, t])
		for key: String in ["default_player", "menu_focus"]:
			if not World.countries.has(str(GameModes.get_value(key))):
				p.append("%s: mode.json %s '%s' ülkesi yok" % [mid, key, GameModes.get_value(key)])
		for key: String in ["featured", "majors"]:
			for t: Variant in GameModes.get_value(key):
				if not World.countries.has(str(t)):
					p.append("%s: mode.json %s içinde '%s' ülkesi yok" % [mid, key, t])
		var pl: Variant = GameModes.get_value("playable")
		if pl is Array:
			for t: Variant in pl:
				if not World.countries.has(str(t)):
					p.append("%s: mode.json playable içinde '%s' ülkesi yok" % [mid, t])
		if not World.is_playable(GameModes.default_player()):
			p.append("%s: varsayılan oyuncu '%s' oynanabilir değil" % [mid, GameModes.default_player()])
		days(3)
		none(p, "mod sözleşmesi")
	Game.switch_mode(GameModes.BASE_MODE)

# ------------------------------------------------------------------ mod geçişi temiz
## WWII → başka mod → WWII: aynı tohumla WWII bit düzeyinde aynı (önbellek/veri kalıntısı yok)
func test_switch_is_clean() -> void:
	var a := _ww2_run()
	for mid: String in GameModes.ids(true):
		if mid != GameModes.BASE_MODE:
			Game.switch_mode(mid)
			World.start_game(GameModes.default_player())
			days(10)
	var b := _ww2_run()
	none(_snap.diff_fields(a, b), "WWII'ye dönünce fark")

func _ww2_run() -> Dictionary:
	Game.switch_mode(GameModes.BASE_MODE, true)
	seed(4242)
	Game.new_game()
	World.start_game("TUR")
	days(30)
	return _snap.take(true)

# ------------------------------------------------------------------ kayıt ve yükleme
## Başka bir modun kaydı: WWII'de iken yüklenince mod, veri ve mod durumu (rules.to_save) geri gelir
func test_mode_save_roundtrip() -> void:
	Game.switch_mode("_template")
	World.start_game("TUR")
	days(5)
	var before := _snap.take()
	var rules_state: Dictionary = Game.rules.to_save()
	if not check(Game.save_game(SLOT), "kaydet"):
		return
	Game.switch_mode(GameModes.BASE_MODE)
	eq(GameModes.id, GameModes.BASE_MODE, "WWII'ye dönüldü")
	if not check(Game.load_game(SLOT), "yükle"):
		return
	World.resume_game(World.player_tag)
	eq(GameModes.id, "_template", "kayıt kendi modunu kurar")
	check(Game.rules != null, "kural betiği kuruldu")
	if Game.rules:
		eq(Game.rules.to_save(), rules_state, "mod durumu geri geldi")
	none(_snap.diff_fields(before, _snap.take()), "kayıt/yükleme farkı")
	DirAccess.remove_absolute(_save_path())
	Game.switch_mode(GameModes.BASE_MODE)

## "mode" alanı olmayan (eski) kayıt WWII olarak açılır
func test_old_save_is_ww2() -> void:
	days(3)
	check(Game.save_game(SLOT), "kaydet")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_save_path()))
	data.erase("mode")
	data.erase("mode_state")
	data["version"] = 1
	_write(data)
	check(Game.load_game(SLOT), "eski kayıt yüklenir")
	eq(GameModes.id, GameModes.BASE_MODE, "eski kayıt WWII")
	DirAccess.remove_absolute(_save_path())

## Bilinmeyen modun ve bozuk kaydın yüklenmesi reddedilir; oyun durumu bozulmaz
func test_bad_saves_rejected() -> void:
	days(3)
	check(Game.save_game(SLOT), "kaydet")
	var before := _snap.take()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_save_path()))
	data["mode"] = "boyle_bir_mod_yok"
	_write(data)
	check(not Game.load_game(SLOT), "bilinmeyen modun kaydı açılmaz")
	var f := FileAccess.open(_save_path(), FileAccess.WRITE)
	f.store_string("{bozuk")
	f.close()
	check(not Game.load_game(SLOT), "bozuk kayıt açılmaz")
	eq(GameModes.id, GameModes.BASE_MODE, "mod değişmedi")
	none(_snap.diff_fields(before, _snap.take()), "reddedilen yükleme durumu değiştirdi")
	DirAccess.remove_absolute(_save_path())

func _write(data: Dictionary) -> void:
	var f := FileAccess.open(_save_path(), FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()

## Kayıt yuvası öneki: WWII adları değişmez; başka modda "<id>_" öneki ve slot_mode geri çözer
func test_slot_names() -> void:
	eq(GameModes.slot_mode("TUR_1936_01_05"), GameModes.BASE_MODE, "ülke etiketiyle başlayan yuva WWII")
	eq(GameModes.slot_mode("hizli_kayit"), GameModes.BASE_MODE, "hızlı kayıt WWII")
	eq(GameModes.slot_mode("_template_TUR_1936_01_05"), GameModes.BASE_MODE, "alt çizgiyle başlayan ad mod sayılmaz")
	Game.switch_mode("_template")
	eq(GameModes.save_prefix(), "_template_", "başka modda önek")
	Game.switch_mode(GameModes.BASE_MODE)

# ------------------------------------------------------------------ oynanabilir ülkeler
func test_playable_filter() -> void:
	var saved: Variant = GameModes.manifest.get("playable")
	GameModes.manifest["playable"] = ["TUR", "IRQ"]
	check(World.is_playable("TUR"), "listedeki ülke oynanabilir")
	check(not World.is_playable("GER"), "listede olmayan ülke oynanamaz")
	if saved == null:
		GameModes.manifest.erase("playable")
	else:
		GameModes.manifest["playable"] = saved
	check(World.is_playable("GER"), "\"all\" iken her ülke")

# ------------------------------------------------------------------ ana menü
## Tek görünür modda "Yeni Oyun" bugünkü gibi doğrudan ülke seçimine gider; birden çok modda mod listesi açılır
func test_menu_mode_picker() -> void:
	var menu := MainMenu.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(menu)
	var got := {"new": 0, "mode": ""}
	menu.new_game_pressed.connect(func() -> void: got["new"] += 1)
	menu.mode_chosen.connect(func(m: String) -> void: got["mode"] = m)
	eq(GameModes.ids().size(), 1, "bu sürümde görünür tek mod")
	(menu._col.get_child(menu._buttons_from) as Button).pressed.emit()
	eq(got["new"], 1, "tek modda Yeni Oyun doğrudan ülke seçimine")
	var tmpl: Dictionary = GameModes.info("_template")
	tmpl["hidden"] = false
	(menu._col.get_child(menu._buttons_from) as Button).pressed.emit()
	var buttons: Array[Button] = []
	for i in range(menu._buttons_from, menu._col.get_child_count()):
		if menu._col.get_child(i) is Button:
			buttons.append(menu._col.get_child(i))
	eq(buttons.size(), 3, "iki mod + geri düğmesi")
	eq(got["new"], 1, "birden çok modda önce mod listesi")
	if buttons.size() == 3:
		buttons[1].pressed.emit()
		eq(got["mode"], "_template", "ikinci mod seçildi")
		buttons[2].pressed.emit()
		eq(menu._col.get_child_count() - menu._buttons_from, 4, "geri: ana düğmeler")
	tmpl["hidden"] = true
	menu.queue_free()
