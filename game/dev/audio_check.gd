extends SceneTree
func _init() -> void:
	await process_frame
	var A = root.get_node("Audio")
	var bad := 0
	for n in A.SOUNDS:
		var arr: Array = A._streams[n]
		if arr.size() != int(A.SOUNDS[n][1]):
			print("EKSİK EFEKT ", n, " ", arr.size(), "/", A.SOUNDS[n][1]); bad += 1
	var names := {}
	for st in A.MUSIC: for t in A.MUSIC[st]: names[t] = true
	for t in ["stinger_war_player", "stinger_war_world", "stinger_victory", "stinger_defeat", "stinger_peace"]: names[t] = true
	for t in names:
		var s: AudioStream = A._music_stream(t)
		if s == null:
			print("EKSİK MÜZİK ", t); bad += 1
		else:
			print("müzik ", t, " ", snappedf(s.get_length(), 0.1), " sn, loop=", s.get("loop"))
	# bildirim kuyruğu: aynı ses tekrar girmez, sırayla çalar
	for n in ["research_done", "focus_done", "notify_good", "research_done"]:
		A.play(n, 0)
	print("kuyruk ", A._queue.map(func(q): return q[0]))
	if A._queue.size() != 3: print("HATA kuyruk"); bad += 1
	var started := []
	for i in 80:
		await create_timer(0.05).timeout
		for p in A._pool:
			if p.playing and p.stream and not started.has(p.stream.resource_path):
				started.append(p.stream.resource_path)
	print("çalma sırası ", started.map(func(x): return x.get_file()))
	# savaş müzikleri: dünyada savaş -> uzak savaş müziği; oyuncunun savaşı -> kendi müziği
	root.get_node("Game").new_game()
	var W = root.get_node("World"); var D = root.get_node("Diplomacy")
	W.start_game("TUR")
	await process_frame
	W.countries["GER"].war_goals["POL"] = "ready"
	D.declare_war("GER", "POL")
	await process_frame
	print("GER>POL olay müziği: ", A._stinger.stream.resource_path.get_file() if A._stinger.stream else "-", " durum=", A._state)
	if not A._stinger.stream or not A._stinger.stream.resource_path.ends_with("stinger_war_world.ogg"): bad += 1
	W.countries["TUR"].war_goals["IRQ"] = "ready"
	D.declare_war("TUR", "IRQ")
	await process_frame
	print("TUR>IRQ olay müziği: ", (A._stinger.stream.resource_path.get_file() if A._stinger.stream else "-"), " durum=", A._state, " bekleyen=", A._pending_state)
	if not A._stinger.stream or not A._stinger.stream.resource_path.ends_with("stinger_war_player.ogg") or A._pending_state != "war_player": bad += 1
	print("SONUÇ eksik/hata=", bad)
	quit(1 if bad > 0 else 0)
