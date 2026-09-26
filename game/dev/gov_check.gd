extends SceneTree
## Hükümet kurulumu doğrulaması: 1936 etkin istikrar/savaş desteği, tarihli olaylar, seçimler.
##   godot --headless --path . -s game/dev/gov_check.gd -- [--player=TUR] [--days=1200]
## Sorun bulursa 1 ile çıkar: şartsız tarihli olay tarihinde gelmedi / erken geldi, oyuncuya gelen olay kendiliğinden
## seçildi, seçim tarihi ilerlemedi, istikrar/savaş desteği aralık dışı, motor/betik hatası.
func _init() -> void:
	var catcher: Logger = preload("res://game/dev/error_catcher.gd").new()
	OS.add_logger(catcher)
	await process_frame
	var W: Node = root.get_node("World")
	var P: Node = root.get_node("Politics")
	var C: Node = root.get_node("GameClock")
	var D: Node = root.get_node("Diplomacy")
	var player := "TUR"
	var days := 1200
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--player="): player = a.substr(9)
		if a.begins_with("--days="): days = int(a.substr(7))
	root.get_node("Game").new_game()
	W.start_game(player)
	var problems: Array[String] = []
	print("== 1936 başlangıç (etkin) ==")
	for t in ["TUR", "GER", "ENG", "FRA", "ITA", "SOV", "USA", "JAP", "POL", "CHI", "SPR", "CZE", "YUG"]:
		var c = W.countries[t]
		print("%s %-10s lider=%-22s parti=%-28s istikrar=%3d%% SD=%3d%% PP/gün=%.2f fabrika=%+d%% teslim=%d%% seçim=%s" % [t, c.ideology, c.leader, c.party_name(),
			roundi(P.stability(c) * 100), roundi(P.war_support(c) * 100), c.daily_political_power_gain(), roundi(P.stability_factory_mod(c) * 100),
			roundi(D.capitulation_threshold(c) * 100), str(c.next_election)])
	for c in W.countries.values():
		var s: float = P.stability(c)
		var ws: float = P.war_support(c)
		if s < 0.0 or s > 1.0 or ws < 0.0 or ws > 1.0 or c.daily_political_power_gain() <= 0.0:
			problems.append("%s: istikrar %.2f / savaş desteği %.2f / PP %.2f aralık dışı" % [c.tag, s, ws, c.daily_political_power_gain()])
	var fired_on := {}
	var player_events := [0]
	P.event_fired.connect(func(tag: String, id: String, from: String) -> void:
		player_events[0] += 1
		print("OLAY(oyuncu) %s %s from=%s" % [W.date_value(), id, from]))
	for d in days:
		C.advance_hours(24)
		for id in P.fired_events:
			if not fired_on.has(id):
				fired_on[id] = W.date_value()
				print("TETİKLENDİ %s %s" % [W.date_value(), id])
		if W.date_value() % 10000 == 101:
			var c = W.countries[player]
			print("%s %s istikrar=%d%% SD=%d%% gerginlik=%d lider=%s ruhlar=%s" % [W.date_value(), player, roundi(P.stability(c) * 100), roundi(P.war_support(c) * 100), roundi(W.world_tension), c.leader, c.spirits])
	for t in ["USA", "ENG", "FRA", "CZE"]:
		print("seçim sonrası %s ideoloji=%s sonraki=%d" % [t, W.countries[t].ideology, W.countries[t].next_election])
	# --- denetimler
	var today: int = W.date_value()
	for id: String in P.events:
		var trig: Variant = P.events[id].get("trigger")
		if trig == null:
			continue
		var due: int = P.date_int(str(trig.get("date", "1936-01-01")))
		var target = W.countries.get(str(trig.get("tag", "")))
		if fired_on.has(id) and int(fired_on[id]) < due:
			problems.append("olay %s tarihinden önce geldi (%d < %d)" % [id, fired_on[id], due])
		if due > today or target == null or not trig.get("require", []).is_empty():
			continue
		if not fired_on.has(id):
			problems.append("şartsız olay %s (%d) hiç gelmedi" % [id, due])
		elif int(fired_on[id]) != due:
			problems.append("şartsız olay %s tarihinde gelmedi (%d, beklenen %d)" % [id, fired_on[id], due])
	if P.pending_events.size() != player_events[0]:
		problems.append("oyuncuya %d olay geldi ama %d tanesi bekliyor (kendiliğinden seçilen var)" % [player_events[0], P.pending_events.size()])
	for c in W.countries.values():
		if c.exists() and c.election_months > 0 and c.next_election > 0 and c.next_election <= today:
			problems.append("%s: seçim tarihi ilerlemedi (%d)" % [c.tag, c.next_election])
	for e in catcher.take():
		problems.append("motor/betik hatası: " + e)
	print("== gov_check: %d sorun ==" % problems.size())
	for p in problems:
		print("  SORUN " + p)
	OS.remove_logger(catcher)
	catcher = null
	quit(1 if not problems.is_empty() else 0)
