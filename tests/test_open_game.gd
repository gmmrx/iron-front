extends "res://tests/test_case.gd"
## Bitmeyen oyun (PART OPEN): bitiş tarihi yok; zafer = oyuncunun tarafı dışında ayakta ülke kalmaması, yenilgi = ülkenin
## yok olması; teslim olup toprağı kalan oyuncu sürer. Araştırma bitmez: dal bitince iyileştirme seviyeleri (artan
## maliyet, azalan kazanç), kayıtta korunur, yapay zekâ da araştırır, yeni oyunda sıfırlanır.

const SLOT := "_test_bitmeyen"

var _ends: Array = []

func _listen() -> void:
	_ends.clear()
	if not Game.game_over.is_connected(_on_end):
		Game.game_over.connect(_on_end)

func _on_end(victory: bool, reason: String) -> void:
	_ends.append([victory, reason])

func _stop() -> void:
	if Game.game_over.is_connected(_on_end):
		Game.game_over.disconnect(_on_end)
	Game.over = false
	Game.won = false

# ------------------------------------------------------------------ oyun sonu
func test_no_end_date() -> void:
	_listen()
	GameClock.year = 1960
	Game._check_end()
	check(not Game.over, "1960'ta oyun sürer")
	eq(_ends.size(), 0, "tarih yüzünden oyun sonu yok")
	_stop()

func test_world_conquest_victory() -> void:
	_listen()
	var me := World.player_tag
	player().faction = me
	var outside: Country = null
	for c: Country in World.countries.values():
		if c.tag != me and c.exists():
			c.faction = me
			if outside == null:
				outside = c
	outside.faction = ""
	Game._check_end()
	eq(_ends.size(), 0, "tarafın dışında bir ülke kaldıkça zafer yok")
	outside.faction = me
	Game._check_end()
	if eq(_ends.size(), 1, "dünya tarafın elinde: zafer"):
		check(bool(_ends[0][0]), "zafer ekranı")
		eq(String(_ends[0][1]), "GAMEOVER_WORLD", "zafer nedeni")
	# oynamaya devam: zafer ekranı yeniden gelmez
	Game.over = false
	Game._check_end()
	eq(_ends.size(), 1, "devam edince zafer tekrar gelmez")
	_stop()

func test_defeat_when_country_gone() -> void:
	_listen()
	var me := World.player_tag
	World.annex(me, "SOV")
	check(not player().exists(), "oyuncunun ülkesi yok oldu")
	if eq(_ends.size(), 1, "ülke yok olunca oyun sonu"):
		check(not bool(_ends[0][0]), "yenilgi")
		eq(String(_ends[0][1]), "GAMEOVER_DEFEAT", "yenilgi nedeni")
	_stop()

func test_capitulated_player_keeps_playing() -> void:
	_listen()
	Diplomacy.capitulate(player())
	check(player().exists(), "teslim olan ülkenin toprağı kaldı")
	Game._check_end()
	eq(_ends.size(), 0, "toprağı kalan oyuncu oynamayı sürdürür")
	_stop()

# ------------------------------------------------------------------ bitmeyen araştırma
## Dalın bütün tarihî teknolojilerini bitir
func _finish_branch(c: Country, cat: String) -> void:
	for id: String in Research.techs.keys():
		var t: Dictionary = Research.techs[id]
		if t["cat"] == cat and not t.get("repeat", false):
			Research._complete_with_reqs(c, id)

func test_research_goes_on_after_branch() -> void:
	var c := player()
	var first := Research.repeat_id("infantry", 1)
	check(Research.techs.has(first), "ilk iyileştirme seviyesi tanımlı")
	check(not Research.can_research(c, first), "dal bitmeden iyileştirme yok")
	_finish_branch(c, "infantry")
	eq(Research.next_repeat(c, "infantry"), first, "sıradaki seviye 1")
	check(Research.can_research(c, first), "dal bitince iyileştirme açılır")
	var before := c.mod("infantry_soft")
	var gains: Array[float] = []
	var costs: Array[float] = []
	for n in range(1, 5):
		var id := Research.repeat_id("infantry", n)
		check(Research.can_research(c, id), "seviye %d araştırılabilir" % n)
		costs.append(float(Research.techs[id]["cost"]))
		var was := c.mod("infantry_soft")
		Research._complete(c, id)
		gains.append(c.mod("infantry_soft") - was)
		check(Research.techs.has(Research.repeat_id("infantry", n + 1)), "seviye %d bitince seviye %d tanımlı" % [n, n + 1])
	eq(Research.repeat_level(c, "infantry"), 4, "biten seviye")
	gt(c.mod("infantry_soft"), before, "iyileştirme etkisi eklenir")
	for i in range(1, gains.size()):
		gt(costs[i], costs[i - 1], "seviye %d daha pahalı" % (i + 1))
		lt(gains[i], gains[i - 1], "seviye %d daha az kazandırır" % (i + 1))
		gt(gains[i], 0.0, "seviye %d yine de kazandırır" % (i + 1))
	# iyileştirme tarihî ağaçtan sonra: son teknolojiden önceki yılda yıl cezası var
	var y1 := int(Research.techs[Research.repeat_id("infantry", 1)]["year"])
	eq(y1, Research.rep_first_year, "ilk seviyenin yılı")
	for t: Dictionary in Research.techs.values():
		if not t.get("repeat", false):
			lt(float(t["year"]), float(y1), "iyileştirme tarihî teknolojilerden sonra")
	check(Research.tech_name(first).contains("I"), "ad seviyeyi taşır: " + Research.tech_name(first))

func test_research_levels_saved_and_reset() -> void:
	var c := player()
	_finish_branch(c, "industry")
	for n in range(1, 4):
		Research._complete(c, Research.repeat_id("industry", n))
	check(Research.start(c, Research.repeat_id("industry", 4)), "4. seviye başlar")
	var mods: float = c.mod("factory_output")
	check(Game.save_game(SLOT), "kaydet")
	check(Game.load_game(SLOT), "yükle")
	DirAccess.remove_absolute(Game.SAVE_DIR + SLOT + ".json")
	var c2 := player()
	eq(Research.repeat_level(c2, "industry"), 3, "kayıttan sonra biten seviye")
	near(c2.mod("factory_output"), mods, 0.0001, "kayıttan sonra iyileştirme etkisi")
	var running := false
	for r: Dictionary in c2.research_current:
		running = running or String(r["tech"]) == Research.repeat_id("industry", 4)
	check(running, "süren iyileştirme kayıtta korunur")
	Research._on_day_impl()                    # süren seviyenin tanımı var: günlük araştırma hatasız ilerler
	# yeni oyun: kurulan seviyeler silinir, her dalın yalnız ilk seviyesi tanımlı
	Game.new_game()
	check(Research.techs.has(Research.repeat_id("industry", 1)), "yeni oyunda ilk seviye tanımlı")
	check(not Research.techs.has(Research.repeat_id("industry", 2)), "yeni oyunda önceki oyunun seviyeleri yok")
	World.start_game(player_tag())

func test_ai_researches_refinements() -> void:
	var ai: Country = null
	for c: Country in World.countries.values():
		if c.tag != World.player_tag and c.exists() and c.is_major():
			ai = c
			break
	if not check(ai != null, "yapay zekâ büyük gücü"):
		return
	for cat: String in Research.categories:
		_finish_branch(ai, cat)
	ai.research_current.clear()
	GameClock.year = Research.rep_first_year + 2
	AI._research(ai)
	gt(ai.research_current.size(), 0, "bütün dalları biten yapay zekâ araştırmayı sürdürür")
	for r: Dictionary in ai.research_current:
		check(Research.is_repeat(String(r["tech"])), "yapay zekâ iyileştirme araştırır: " + String(r["tech"]))

# ------------------------------------------------------------------ tarihî akıştan sonra
## Yinelenen olayı her ülkeye bu hafta gelecek kadar sık yap (mtth 7 gün), testten sonra eski değer
func _force(id: String) -> int:
	var r: Dictionary = Politics.events[id]["recur"]
	var old := int(r["mtth_days"])
	r["mtth_days"] = 7
	return old

func _unforce(id: String, old: int) -> void:
	Politics.events[id]["recur"]["mtth_days"] = old

func _set_date(y: int, m: int, d: int) -> void:
	GameClock.year = y
	GameClock.month = m
	GameClock.day = d

func test_recurring_events_wait_for_history() -> void:
	var old := _force("bank_run")
	var me := player()
	_set_date(1944, 6, 1)
	Politics._recurring_events()
	check(not me.decisions_active.has("cd_bank_run"), "tarihî akış sürerken yinelenen olay yok")
	check(Politics.pending_events.filter(func(p: Dictionary) -> bool: return p["id"] == "bank_run").is_empty(), "1944'te bekleyen olay yok")
	_set_date(1946, 6, 1)
	Politics._recurring_events()
	check(me.decisions_active.has("cd_bank_run"), "1946'da olay gelir, bekleme süresi başlar")
	eq(Politics.pending_events.filter(func(p: Dictionary) -> bool: return p["id"] == "bank_run").size(), 1, "oyuncuya pencere (karar oyuncunun)")
	var ai_got := 0
	for c: Country in World.countries.values():
		if c.tag != me.tag and c.exists() and c.decisions_active.has("cd_bank_run"):
			ai_got += 1
	gt(ai_got, 20, "yapay zekâ ülkelerine de gelir (kendileri seçer)")
	Politics._recurring_events()
	eq(Politics.pending_events.filter(func(p: Dictionary) -> bool: return p["id"] == "bank_run").size(), 1, "bekleme süresinde yeniden gelmez")
	World.day_count += int(Politics.events["bank_run"]["recur"]["cooldown_days"]) + 1
	Politics._on_day_impl()                # süresi dolan bekleme kalkar
	check(not me.decisions_active.has("cd_bank_run"), "bekleme süresi dolar")
	_unforce("bank_run", old)

func test_recurring_event_requirements() -> void:
	var old := _force("officers_plot")
	_set_date(1946, 6, 1)
	var me := player()
	me.stability = 0.8
	Politics._recurring_events()
	check(not me.decisions_active.has("cd_officers_plot"), "istikrar yüksekken subay komplosu yok")
	me.stability = 0.2
	Politics._recurring_events()
	check(me.decisions_active.has("cd_officers_plot"), "istikrar düşükken gelir")
	_unforce("officers_plot", old)

func test_border_incident_gives_casus_belli_and_ai_wars() -> void:
	var me := player()
	var n := Politics.random_neighbour(me)
	check(n != "" and not Diplomacy.are_allies(n, me.tag), "müttefik olmayan komşu: " + n)
	Politics.choose_option(me, "border_incident", 0, n)
	check(me.war_goals.has(n), "tazminat istemek komşuya karşı savaş gerekçesi verir")
	# tarihî akıştan sonra gerekçesi olan yapay zekâ savaşı kendisi açar (yeni savaşlar)
	_set_date(1946, 6, 1)
	check(not AI.follows_history(), "1946: yapay zekâ serbest")
	var ita: Country = World.countries["ITA"]
	ita.war_goals["ALB"] = true
	AI._declare(ita)
	check(Diplomacy.are_enemies("ITA", "ALB"), "gerekçesi olan yapay zekâ savaş açar")
