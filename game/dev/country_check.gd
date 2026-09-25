extends SceneTree
## Her ülkeyle oynanabilirlik: oyunu o ülkeyle başlatır, oyuncunun eylemlerinin oyunu gerçekten değiştirdiğini ölçer.
##   godot --headless --path . -s game/dev/country_check.gd -- [--tags=TUR,GER] [--days=60]
## Sütunlar: yasa (insan gücü değişir), ticaret (anlaşma kaynağı artırır), üretim (stok artar), inşaat (ilerler),
## araştırma (ilerler), odak (ilerler), danışman (SG kazancı değişir), otomatik yok (oyuncu adına ticaret/kanat yok),
## olaylar (oyuncuya sorulur, kendiliğinden seçilmez).
func _init() -> void:
	await process_frame
	var W: Node = root.get_node("World")
	var P: Node = root.get_node("Politics")
	var E: Node = root.get_node("Economy")
	var R: Node = root.get_node("Research")
	var C: Node = root.get_node("GameClock")
	var M: Node = root.get_node("Military")
	var A: Node = root.get_node("Air")
	var G: Node = root.get_node("Game")
	var days := 60
	var only: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--days="): days = int(a.substr(7))
		if a.begins_with("--tags="): only = a.substr(7).split(",")
	var tags: Array = only if not only.is_empty() else W.countries.keys()
	var fails := 0
	var t0 := Time.get_ticks_msec()
	for tag: String in tags:
		G.new_game()
		W.start_game(tag)
		var c = W.countries[tag]
		var res := {}
		c.political_power = 500.0
		# yasa: izin verilen bir üst askerlik yasası -> insan gücü değişmeli
		var mp0: int = c.recruitable_manpower()
		var law_ok := "yok"
		for law: String in E.law_groups["conscription"]["laws"]:
			if law != c.laws["conscription"] and E.can_change_law(c, "conscription", law):
				E.change_law(c, "conscription", law)
				law_ok = "ok" if c.recruitable_manpower() != mp0 else "ETKİSİZ"
				break
		res["yasa"] = law_ok
		# ticaret: satıcısı olan bir kaynaktan 8 al -> kullanılabilir kaynak artmalı
		var trade_ok := "satıcı yok"
		for r: String in ["steel", "oil", "rubber", "aluminium", "tungsten", "chromium"]:
			var sellers: Array = E.trade_sellers(c, r)
			var exporting := false
			for ex: Dictionary in c.exports:
				if ex["res"] == r: exporting = true
			if sellers.is_empty() or exporting:
				continue
			var before := float(E.resource_available(c).get(r, 0.0))
			if not E.trade_affordable(c, 8.0):
				trade_ok = "fabrika yetmez"
				break
			E.add_trade(c, r, sellers[0][0], 8.0)
			var got := 0.0
			for im: Dictionary in c.imports:
				if im["res"] == r and im["from"] == sellers[0][0]: got += float(im["amount"])
			var after := float(E.resource_available(c).get(r, 0.0))
			trade_ok = ("ok" if after > before else "ok(konvoy yok)") if got >= 1.0 else "ETKİSİZ"
			break
		res["ticaret"] = trade_ok
		# üretim: piyade teçhizatı hattına boştaki fabrikalar
		var stock0 := float(c.stockpile.get("infantry_equipment", 0.0))
		var free: int = E.free_military(c)
		var prod_ok := "fabrika yok"
		if free > 0:
			E.add_line(c, "infantry_equipment")
			E.set_line_factories(c, c.production_lines.size() - 1, free)
			prod_ok = "?"
		elif not c.production_lines.is_empty():
			prod_ok = "?"          # tüm fabrikalar zaten hatlarda: mevcut hatların çıktısı ölçülür
		# inşaat: başkentte altyapı
		var cons_ok := "yuva yok"
		var cap = W.states.get(c.capital_state)
		if cap and E.queue_building(c, cap, "infrastructure"):
			cons_ok = "?"
		# araştırma
		var res_ok := "yok"
		for id: String in R.techs:
			if R.can_research(c, id) and R.start(c, id):
				res_ok = "?"
				break
		# odak
		var foc_ok := "yok"
		for id: String in P.tree_of(c):
			if P.can_start_focus(c, id) and P.start_focus(c, id):
				foc_ok = "?"
				break
		# danışman
		var pp0: float = c.daily_political_power_gain()
		var adv_ok := "yok"
		if P.can_hire(c, "silent_workhorse"):
			P.hire(c, "silent_workhorse")
			adv_ok = "ok" if c.daily_political_power_gain() > pp0 else "ETKİSİZ"
		res["danışman"] = adv_ok
		var orders0: int = c.trade_orders.size()
		P.pending_events.clear()
		var fired := [0]
		var cb := func(t: String, _id: String, _f: String) -> void:
			if t == tag: fired[0] += 1
		P.event_fired.connect(cb)
		for d in days:
			C.advance_hours(24)
		P.event_fired.disconnect(cb)
		if prod_ok == "?":
			var gained := float(c.stockpile.get("infantry_equipment", 0.0)) - stock0
			# tümenler de teçhizat çekebilir: hat çıktısı ölçülür
			var out := 0.0
			for l in c.production_lines:
				out += l.last_output
			prod_ok = "ok" if out > 0.0 or gained > 0.0 else "ETKİSİZ"
		res["üretim"] = prod_ok
		if cons_ok == "?":
			var prog := 0.0
			for q in c.construction_queue:
				prog = maxf(prog, q.fraction())
			cons_ok = "ok" if prog > 0.0 or c.construction_queue.is_empty() else ("sivil fabrika yok" if E.available_civilian(c) <= 0 else "ETKİSİZ")
		res["inşaat"] = cons_ok
		if res_ok == "?":
			var rp := 0.0
			for r2: Dictionary in c.research_current:
				rp = maxf(rp, float(r2["progress"]))
			res_ok = "ok" if rp > 0.0 or not c.research_done.is_empty() else "ETKİSİZ"
		res["araştırma"] = res_ok
		if foc_ok == "?":
			foc_ok = "ok" if c.focus_progress > 0.0 or not c.focus_done.is_empty() else "ETKİSİZ"
		res["odak"] = foc_ok
		var auto_bad: bool = c.auto_trade or c.trade_orders.size() != orders0
		for w in A.wings:
			if w.owner == tag and w.auto:
				auto_bad = true
		res["otomatik"] = "YOK(iyi)" if not auto_bad else "VAR!"
		res["olay"] = "%d soruldu/%d bekliyor" % [fired[0], P.pending_events.size()]
		var bad := false
		for k: String in res:
			if str(res[k]).contains("ETKİSİZ") or str(res[k]).contains("VAR!"):
				bad = true
		if bad:
			fails += 1
		var line := "%s %-4s" % ["FAIL" if bad else "ok  ", tag]
		for k: String in res:
			line += "  %s=%s" % [k, res[k]]
		line += "  tümen=%d eyalet=%d" % [M.country_divisions(tag).size(), c.states.size()]
		print(line)
	print("== %d ülke, %d sorunlu, %.0f sn ==" % [tags.size(), fails, (Time.get_ticks_msec() - t0) / 1000.0])
	quit()
