extends SceneTree
## Savaş demosu kaydı: dünya 1936'dan denge testindeki gibi ileri sarılır (oyuncu yer tutucu --hold ülkesi; seçilen ülkeyi
## yapay zekâ yönetir); seçilen ülke --enemy ile savaşa girdikten --after gün sonra oyuncu o ülkeye geçer (yeni oyun varsayılanları: el ile ticaret, kanatlar ve "son askere
## kadar") ve oyun kayda yazılır; o tarihe kadar savaş çıkmazsa --until tarihinde yazılır. Devretmeden hemen önce aynı an
## "<slot>_watch" diye de yazılır (oyuncu yer tutucu ülke; savaşı yapay zekâ yürütür): ana menüdeki "Geliştirici: Savaş
## izle" bunu izleyici modunda açar. Sonra pencereli oyun kayıttan açılır.
##   godot --headless --path . -s game/dev/war_demo.gd -- [--player=GER] [--enemy=SOV] [--after=10] [--until=19411101]
##       [--hold=TUR] [--slot=war_demo] [--seed=N]
##   godot --path . -- --load=war_demo

func _init() -> void:
	await process_frame
	var player := "GER"
	var enemy := "SOV"
	var after := 10
	var until := 19411101
	var slot := "war_demo"
	var hold := "TUR"
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"player": player = kv[1]
			"enemy": enemy = kv[1]
			"after": after = int(kv[1])
			"until": until = int(kv[1])
			"slot": slot = kv[1]
			"hold": hold = kv[1]
			"seed": seed(int(kv[1]))
	var W: Node = root.get_node("World")
	var C: Node = root.get_node("GameClock")
	var D: Node = root.get_node("Diplomacy")
	var M: Node = root.get_node("Military")
	var G: Node = root.get_node("Game")
	G.new_game()
	W.start_game(hold)                   # denge testindeki kurulum: seçilen ülke dahil herkesi yapay zekâ yönetir
	var t0 := Time.get_ticks_msec()
	var war_day := -1
	var last_y := 0
	while W.date_value() < until:
		C.advance_hours(24)
		if W.date_value() / 10000 != last_y:
			last_y = W.date_value() / 10000
			var pc: Object = W.countries[player]
			print("%d  (%.0f sn)  %s var=%s, düşmanları: %s" % [last_y, (Time.get_ticks_msec() - t0) / 1000.0, player,
				pc.exists(), ", ".join(D.enemies_of(player))])
		if war_day < 0 and enemy in D.enemies_of(player):
			war_day = W.day_count
			print("savaş: %s > %s  %d" % [player, enemy, W.date_value()])
		if war_day >= 0 and W.day_count - war_day >= after:
			break
	print("izleme kaydı: %s_watch -> %s" % [slot, G.save_game(slot + "_watch")])
	# izlenen iki ülke: "Geliştirici: Savaş izle" kamerayı bunların karşı karşıya durduğu en kalabalık yere indirir
	var mf := FileAccess.open(G.SAVE_DIR + slot + "_watch.meta.json", FileAccess.WRITE)
	mf.store_string(JSON.stringify({"a": player, "b": enemy}))
	mf.close()
	W.start_game(player)
	var n := 0
	for d in M.divisions:
		if d.owner == player:
			n += 1
	print("tarih %d, %s düşmanları: %s, %d tümen, çarpışma %d" % [W.date_value(), player, ", ".join(D.enemies_of(player)), n, M.battles.size()])
	print("kayıt: %s -> %s" % [slot, G.save_game(slot)])
	quit(0)
