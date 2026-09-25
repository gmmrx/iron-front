extends SceneTree
## Hükümet kurulumu doğrulaması: 1936 etkin istikrar/savaş desteği, tarihli olaylar, seçimler.
##   godot --headless --path . -s game/dev/gov_check.gd -- [--player=TUR] [--days=1200]
func _init() -> void:
	await process_frame
	var W: Node = root.get_node("World")
	var P: Node = root.get_node("Politics")
	var C: Node = root.get_node("GameClock")
	var E: Node = root.get_node("Economy")
	var D: Node = root.get_node("Diplomacy")
	var player := "TUR"
	var days := 1200
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--player="): player = a.substr(9)
		if a.begins_with("--days="): days = int(a.substr(7))
	root.get_node("Game").new_game()
	W.start_game(player)
	print("== 1936 başlangıç (etkin) ==")
	for t in ["TUR", "GER", "ENG", "FRA", "ITA", "SOV", "USA", "JAP", "POL", "CHI", "SPR", "CZE", "YUG"]:
		var c = W.countries[t]
		print("%s %-10s lider=%-22s parti=%-28s istikrar=%3d%% SD=%3d%% PP/gün=%.2f fabrika=%+d%% teslim=%d%% seçim=%s" % [t, c.ideology, c.leader, c.party_name(),
			roundi(P.stability(c) * 100), roundi(P.war_support(c) * 100), c.daily_political_power_gain(), roundi(P.stability_factory_mod(c) * 100),
			roundi(D.capitulation_threshold(c) * 100), str(c.next_election)])
	var seen := {}
	P.event_fired.connect(func(tag: String, id: String, from: String) -> void: print("OLAY(oyuncu) %s %s from=%s" % [W.date_value(), id, from]))
	for d in days:
		C.advance_hours(24)
		for id in P.fired_events:
			if not seen.has(id):
				seen[id] = true
				print("TETİKLENDİ %s %s" % [W.date_value(), id])
		if W.date_value() % 10000 == 101:
			var c = W.countries[player]
			print("%s %s istikrar=%d%% SD=%d%% gerginlik=%d lider=%s ruhlar=%s" % [W.date_value(), player, roundi(P.stability(c) * 100), roundi(P.war_support(c) * 100), roundi(W.world_tension), c.leader, c.spirits])
	for t in ["USA", "ENG", "FRA", "CZE"]:
		print("seçim sonrası %s ideoloji=%s sonraki=%d" % [t, W.countries[t].ideology, W.countries[t].next_election])
	quit()
