extends "res://tests/test_case.gd"
## Dünya olayları menüsü (PART EV): savaş, ilhak, program, seçim kayıtları; bildirim akışı yalnız oyuncuyu (ya da müttefikini,
## ya da büyük güçlerin savaşını) ilgilendirenleri gösterir; oyuncunun taraf olmadığı savaş ilanı ve ilhaklara süresi içinde
## seçenekle cevap (bedel, şart, etki); oyuncunun saldırısına demokrasiler kınamayla cevap verir; menü süzgeçleri.

var _feed: Array[String] = []

func _listen() -> void:
	_feed.clear()
	if not World.notification.is_connected(_on_note):
		World.notification.connect(_on_note)

func _on_note(text: String, _kind: String) -> void:
	_feed.append(text)

func _stop() -> void:
	if World.notification.is_connected(_on_note):
		World.notification.disconnect(_on_note)

func _declare(a: String, t: String) -> bool:
	(World.countries[a] as Country).war_goals[t] = true
	return Diplomacy.declare_war(a, t)

func _last(key: String) -> Dictionary:
	for i in range(World.world_log.size() - 1, -1, -1):
		if String(World.world_log[i]["key"]) == key:
			return World.world_log[i]
	return {}

# ------------------------------------------------------------------ kayıt ve bildirim akışı
func test_world_wars_logged_feed_only_when_relevant() -> void:
	_listen()
	check(_declare("LIT", "LAT"), "Litvanya Letonya'ya savaş açar")
	var e := _last("NOTE_WAR_DECLARED")
	if check(not e.is_empty(), "savaş ilanı kayıtta"):
		eq(e["tags"], ["LIT", "LAT"], "kaydın ülkeleri")
		eq(String(e["kind"]), "war", "kaydın türü")
		check(World.world_text(e).contains(World.countries["LIT"].display_name()), "metin ülke adını taşır: " + World.world_text(e))
	eq(_feed.size(), 0, "küçük ülkelerin savaşı bildirim akışına düşmez")
	check(_declare("GER", "POL"), "Almanya Polonya'ya savaş açar")
	check(_feed.any(func(t: String) -> bool: return t.contains(World.countries["GER"].display_name())), "büyük gücün savaşı akışta")
	_stop()

func test_program_and_election_entries() -> void:
	var ger: Country = World.countries["GER"]
	var id := ""
	for f: String in Politics.tree_of(ger):
		if not f in ger.focus_done:
			id = f
			break
	Politics.complete_focus_now(ger, id, false)
	var e := _last("NEWS_PROGRAM_DONE")
	check(e.is_empty(), "kapalı Devlet Programı dünya kaydı/bildirimi üretmez")
	var me := player()
	var mine := ""
	for f: String in Politics.tree_of(me):
		if not f in me.focus_done:
			mine = f
			break
	var before := World.world_log.size()
	Politics.complete_focus_now(me, mine, false)
	eq(World.world_log.size(), before, "oyuncunun programı dünya menüsüne yazılmaz (kendi bildirimi var)")
	# dil değişse de metin yeniden kurulur: ideoloji anahtarla saklanır
	var el := World.world_event("politics", "NEWS_ELECTION_CHANGE", ["@GER", "#IDEOLOGY_democratic"], ["GER"])
	check(World.world_text(el).contains(tr("IDEOLOGY_democratic")), "ideoloji çevrilir: " + World.world_text(el))

# ------------------------------------------------------------------ tepkiler
func test_react_to_foreign_war() -> void:
	var me := player()
	_declare("LIT", "LAT")
	var e := _last("NOTE_WAR_DECLARED")
	check(WorldReact.is_open(e), "oyuncu taraf değil: tepki verilebilir")
	eq(WorldReact.options(e).size(), 3, "üç seçenek")
	# tüfek göndermek stok ister
	me.stockpile["infantry_equipment"] = 100.0
	var arms := WorldReact.option(e, "arms")
	check(WorldReact.block(me, e, arms) != "", "stok yetmezse tüfek gönderilemez")
	check(not WorldReact.choose(e, "arms"), "şart tutmazsa seçim olmaz")
	me.stockpile["infantry_equipment"] = 1000.0
	var par: Country = World.countries["LAT"]
	var par_before := float(par.stockpile.get("infantry_equipment", 0.0))
	var pp := me.political_power
	check(WorldReact.choose(e, "arms"), "tüfek gönderilir")
	near(float(me.stockpile["infantry_equipment"]), 500.0, 0.01, "oyuncunun stoğundan 500 tüfek çıkar")
	near(float(par.stockpile.get("infantry_equipment", 0.0)) - par_before, 500.0, 0.01, "saldırıya uğrayana 500 tüfek")
	near(me.political_power, pp - 5.0, 0.01, "bedel: 5 nüfuz")
	eq(String(e.get("choice", "")), "arms", "kayıt seçimi taşır")
	check(not WorldReact.is_open(e), "bir kez cevap verilir")
	check(not WorldReact.choose(e, "condemn"), "ikinci cevap yok")
	var news := _last("REACT_NEWS_ARMS")
	check(not news.is_empty() and news["tags"][0] == me.tag, "oyuncunun cevabı da kayıt olur")
	# başka bir savaş: kınamak
	check(_declare("EST", "ALB"), "Estonya Arnavutluk'a savaş açar")
	var e2 := _last("NOTE_WAR_DECLARED")
	var ws := me.war_support
	pp = me.political_power
	check(WorldReact.choose(e2, "condemn"), "kınanır")
	near(me.political_power, pp - 10.0, 0.01, "kınama 10 nüfuz")
	near(me.war_support, minf(ws + 0.02, 1.0), 0.0001, "kınama savaş desteği +%2")

func test_react_window_expires() -> void:
	_declare("LIT", "LAT")
	var e := _last("NOTE_WAR_DECLARED")
	check(WorldReact.is_open(e), "yeni kayıt açık")
	World.day_count += 31
	check(not WorldReact.is_open(e), "30 gün geçince cevap süresi doldu")

func test_no_react_when_player_involved() -> void:
	var me := player()
	var target := ""
	for t: String in ["IRQ", "PER", "SAU"]:
		if World.countries.has(t) and World.countries[t].exists():
			target = t
			break
	_declare(me.tag, target)
	var e := _last("NOTE_WAR_DECLARED")
	check(not e.is_empty() and not e.has("react"), "oyuncunun kendi savaşına tepki seçeneği yok")

func test_react_to_annexation() -> void:
	var me := player()
	check(World.countries["ETH"].exists(), "Habeşistan var")
	Politics.apply_effects(World.countries["ITA"], [{"annex": "ETH"}])
	var e := _last("NEWS_ANNEX")
	if not check(not e.is_empty() and WorldReact.is_open(e), "ilhak kaydı ve tepki"):
		return
	eq(String(e["actor"]), "ITA", "ilhak eden")
	var pp := me.political_power
	check(WorldReact.choose(e, "protest"), "ilhak tanınmaz")
	check(me.war_goals.has("ITA"), "tanımamak savaş gerekçesi verir")
	near(me.political_power, pp - 25.0, 0.01, "bedel 25 nüfuz")

func test_democracies_condemn_player_aggression() -> void:
	var me := player()
	me.ideology = "fascism"
	var eng: Country = World.countries["ENG"]
	var pp := eng.political_power
	var target := ""
	for t: String in ["IRQ", "PER", "SAU"]:
		if World.countries.has(t) and World.countries[t].exists() and not Diplomacy.are_allies(t, "ENG"):
			target = t
			break
	check(_declare(me.tag, target), "oyuncu savaş açar")
	var condemned: Array = []
	for e: Dictionary in World.world_log:
		if String(e["key"]) == "REACT_NEWS_CONDEMN":
			condemned.append(String(e["tags"][0]))
	check("ENG" in condemned, "İngiltere kınar: " + str(condemned))
	check(not "GER" in condemned and not "ITA" in condemned, "demokrasi olmayanlar kınamaz")
	if "ENG" in condemned and not Diplomacy.are_enemies("ENG", me.tag):
		near(eng.political_power, pp - 10.0, 0.01, "kınamanın bedeli yapay zekâya da")

# ------------------------------------------------------------------ menü
func test_world_panel_filters() -> void:
	var wp := WorldPanel.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(wp)
	var me := World.player_tag
	var near: Dictionary = wp.neighbours()
	check(near.has("SYR") or near.has("IRQ") or near.has("GRE") or near.has("BUL") or near.has("SOV") or near.has("PER"),
		"Türkiye'nin komşuları: " + str(near.keys()))
	var far := World.world_event("war", "NOTE_WAR_DECLARED", ["@LIT", "@LAT"], ["LIT", "LAT"])
	var mine := World.world_event("war", "NOTE_WAR_DECLARED", ["@" + me, "@IRQ"], [me, "IRQ"])
	var neighbour := World.world_event("politics", "NEWS_NEW_LEADER", ["@" + str(near.keys()[0]), "X"], [str(near.keys()[0])])
	wp.filter = WorldPanel.FILTER_ALL
	check(wp.passes(far) and wp.passes(mine) and wp.passes(neighbour), "bütün dünya: hepsi")
	wp.filter = WorldPanel.FILTER_NEAR
	check(not wp.passes(far), "komşularım: uzak savaş yok")
	check(wp.passes(mine) and wp.passes(neighbour), "komşularım: oyuncu ve komşusu")
	wp.filter = WorldPanel.FILTER_ALLY
	check(not wp.passes(neighbour) or Diplomacy.are_allies(str(near.keys()[0]), me), "ittifakım: müttefik olmayan komşu yok")
	check(wp.passes(mine), "ittifakım: oyuncunun kendisi")
	wp.filter = WorldPanel.FILTER_ALL
	wp.refresh()                            # görünür yapmadan (açılış ertelenmiş yerleşim çağırır)
	gt(wp._list.get_child_count(), 2, "menüde satırlar")
	eq(WorldPanel.place(far), World.capital_position("LIT"), "yeri olmayan kayıt: ilk ülkenin başkenti")
	wp.get_parent().remove_child(wp)
	wp.free()
