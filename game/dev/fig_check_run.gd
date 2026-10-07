extends RefCounted
## fig_check.gd'nin gövdesi (autoload'lar yüklendikten sonra yüklenir; UnitLayer'ı başsız sürer, örtüşme ve kayma sayar)
const Probe := preload("res://tests/map_probe.gd")
class ProbeMap extends MapView3D:
	func province_at(world_xz: Vector2) -> int:
		return Probe.province_at(world_xz)
	func height_at(_p: Vector2) -> float:
		return 0.0
class SpotCities extends CityLayer3D:
	func unit_spot(_pid: int, p: Vector2) -> Vector2:
		return p + Vector2(10.0, 0.0)

static func ul_team(tag: String) -> String:
	var c: Country = World.countries.get(tag)
	return c.faction if c and c.faction != "" else tag

func run(tree: SceneTree, args: Dictionary) -> int:
	var root := tree.root
	var days := int(args.get("days", "3"))
	var speed := int(args.get("speed", "3"))
	var verbose := args.has("verbose")
	var trace := str(args.get("trace", ""))          # bu alt dizgeyi içeren anahtarların durumu her 15 karede yazılır
	var pair: Array = []                              # --load: izlenen iki ülke (kayıt --pair=GER,SOV; yoksa kaydın .meta'sı)
	if args.has("load"):
		# kayıttan (ör. savaş demosu war_demo_watch): oyun kaldığı yerden, gözlemci
		if not Game.load_game(str(args["load"])):
			print("kayıt yok: ", args["load"])
			return 1
		Game.loaded = false
		Game.observer = true
		World.resume_game(World.player_tag)
		var mp := Game.SAVE_DIR + str(args["load"]) + ".meta.json"
		if args.has("pair"):
			pair = Array(str(args["pair"]).split(","))
		elif FileAccess.file_exists(mp):
			var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(mp))
			if meta is Dictionary:
				pair = [str(meta.get("a", "")), str(meta.get("b", ""))]
	else:
		Game.new_game()
		World.start_game(args.get("play", "DEN"))
		Game.observer = args.has("observer")
		var wt: PackedStringArray = str(args.get("war", "GER,DEN")).split(",")
		(World.countries[wt[0]] as Country).war_goals[wt[1]] = "ready"
		Diplomacy.declare_war(wt[0], wt[1])
	Probe.ensure()
	var ul := UnitLayer.new()
	var pm := ProbeMap.new()
	var cam := MapCamera3D.new()
	var um := UnitModels.new()
	var sc := SpotCities.new()
	um.cities = sc
	um.camera = cam
	ul.map = pm
	ul.camera = cam
	ul.models = um
	root.add_child(cam)
	root.add_child(ul)
	cam.current = true
	var m := Vector2.ZERO
	var pid := 0
	if pair.size() == 2 and args.has("stack"):
		# izlenen ülkenin en çok ayrı sayaçlı (ordu) bölgesi: diziliş görüntüsü için (--focus yazılır)
		var best_n := 0
		var team: String = ul_team(pair[0])
		for p0: int in Military.by_province:
			var armies := {}
			for d: Division in Military.by_province[p0]:
				if ul_team(d.owner) == team and d.path.is_empty():
					armies["%s:%d" % [d.owner, d.army]] = true
			if armies.size() > best_n and armies.size() <= UnitLayer.GRID_MAX:
				best_n = armies.size()
				pid = p0
		if pid == 0:
			print("yığın yok")
			return 1
		m = World.province(pid).center
		print("yığın: bölge %d (%d sayaç)  --focus=%d,%d" % [pid, best_n, int(m.x), int(m.y)])
	elif pair.size() == 2 and args.has("battle"):
		# izlenen iki ülkenin en kalabalık süren muharebesi (en çok 10 gün beklenir): kamera saldıran ile savunan
		# bölgenin ortasında
		var best_n := 0
		for i in 24 * 10:
			var any := false
			for bp: int in Military.battles:
				var b: Dictionary = Military.battles[bp]
				if (b.get("attackers", []) as Array).any(func(d: Division) -> bool: return d.owner == pair[0]) \
						and (b.get("defenders", []) as Array).any(func(d: Division) -> bool: return d.owner == pair[1]):
					any = true
					break
			if any:
				break
			GameClock.advance_hours(1)
		for bp: int in Military.battles:
			var b: Dictionary = Military.battles[bp]
			var n := 0
			for d: Division in b.get("attackers", []):
				if d.owner == pair[0]:
					n += 1
			for d: Division in b.get("defenders", []):
				if d.owner == pair[1]:
					n += 1
			if n > best_n:
				best_n = n
				pid = bp
		if pid == 0:
			print("muharebe yok: ", pair)
			return 1
		var b0: Dictionary = Military.battles[pid]
		m = World.province(int(b0["from"])).center.lerp(World.province(pid).center, 0.5)
		print("muharebe: %d -> %d (%d tümen) %s  --focus=%d,%d" % [int(b0["from"]), pid, best_n, GameClock.date_string(), int(m.x), int(m.y)])
		if args.has("dump"):
			# katılımcıların görsel yerleri: merkezlere göre nerede duruyorlar (menzil)
			var um0 := UnitModels.new()
			var sc0 := SpotCities.new()
			um0.cities = sc0
			um0._update_anchors()
			var ca := World.province(int(b0["from"])).center
			var cd := World.province(pid).center
			print("  merkezler: saldıran %s savunan %s uzaklık %.1f" % [ca, cd, ca.distance_to(cd)])
			for side in ["attackers", "defenders"]:
				for d: Division in b0.get(side, []):
					var a: Array = um0.anchors.get(d.id, [])
					if a.is_empty():
						continue
					var pa: Vector2 = a[0]
					print("  %s %s bölge %d yol %s saldırı %d ilerleme %.0f  yer %s  saldırana %.1f savunana %.1f  t=%.2f" % [side, d.owner, d.province,
						d.path, d.attacking, d.progress, pa, pa.distance_to(ca), pa.distance_to(cd), PathMotion.division(d)[4]])
			um0.free()
			sc0.free()
	elif pair.size() == 2:
		# en kalabalık cephe noktası (main.gd _dev_war_demo ile aynı ölçüt): a'nın tümeni olan, komşusunda b olan bölge;
		# puan = çevresindeki 200 birimde iki tarafın tümen sayısı
		var best_n := 0
		for p0: int in Military.by_province:
			var here: Array = Military.by_province[p0]
			if (here[0] as Division).owner != pair[0] or not World.province(p0).is_land():
				continue
			var front := false
			for q in World.land_neighbors(p0):
				if World.controller_tag(q) == pair[1] or not Military.enemies_in(q, pair[0]).is_empty():
					front = true
					break
			if not front:
				continue
			var c0 := World.province(p0).center
			var n := 0
			for q: int in Military.by_province:
				if World.province(q).center.distance_to(c0) < 200.0:
					for d: Division in Military.by_province[q]:
						if d.owner == pair[0] or d.owner == pair[1]:
							n += 1
			if n > best_n:
				best_n = n
				pid = p0
		if pid == 0:
			print("cephe yok: ", pair)
			return 1
		m = World.province(pid).center
		print("cephe: bölge %d (çevrede %d tümen)  --focus=%d,%d" % [pid, best_n, int(m.x), int(m.y)])
	else:
		for i in 24 * 90:
			if not Military.battles.is_empty():
				break
			GameClock.advance_hours(1)
		if Military.battles.is_empty():
			print("muharebe yok")
			return 1
		pid = Military.battles.keys()[0]
		var b: Dictionary = Military.battles[pid]
		m = World.province(int(b["from"])).center.lerp(World.province(pid).center, 0.5)
	cam.map_size = Vector2(Probe.image.get_width(), Probe.image.get_height())   # focus_on hedefi harita sınırına kıstırır
	cam.edge_pan_enabled = false                       # başsızda fare (0,0)'da: kenar kaydırması kamerayı savaştan uzaklaştırıyordu
	cam.focus_on(m, float(args.get("dist", "140")))   # hedef ve mesafe kalıcı (kamera her karede hedefine yumuşar)
	cam.distance = float(args.get("dist", "140"))
	cam._apply()
	GameClock.speed = speed
	GameClock.paused = false
	if args.has("rebuild_cost"):
		var t0r := Time.get_ticks_usec()
		ul._rebuild()
		print("REBUILD ilk %.2f ms" % [(Time.get_ticks_usec() - t0r) / 1000.0])
		t0r = Time.get_ticks_usec()
		for i in 10:
			ul._rebuild()
		print("REBUILD sonraki ort %.2f ms (%d sayaç, %d tümen)" % [(Time.get_ticks_usec() - t0r) / 10000.0, ul._counters.size(), Military.divisions.size()])
		GameClock.prof.clear()
		for h in 5:
			GameClock.advance_hours(1)
			ul._rebuild()
		print("REBUILD 5 saat, bölümler:")
		for k in GameClock.prof:
			if str(k).begins_with("ur_"):
				print("  %s %.2f ms/kurulum" % [k, GameClock.prof[k] / 5000.0])
		return 0
	var dt := 1.0 / 30.0
	var r := UnitLayer.FIG_SIZE * UnitFigures.BASE_R
	var dmin := 2.0 * r * UnitLayer.FIG_GAP
	var kz := dmin / (UnitLayer.FIG_SIZE * UnitLayer.FIG_DEPTH)
	var prev := {}                 # anahtar -> xz
	var overlap := {}              # "a|b" -> [kare sayısı, en kısa uzaklık, en uzun ardışık, şimdiki ardışık, tür]
	var slide := {}                # anahtar -> [kayma karesi, hareket karesi]
	var jumps := []
	var foes := {}                 # "a|b" -> [kare, en yakın, tür]: düşman figürler birbirine çok yakın (menzil yok)
	var frames := 0
	var day0: int = World.day_count
	var t0 := Time.get_ticks_msec()
	print("başlıyor: muharebe %d, gün %d, sayaç %d" % [pid, day0, ul._counters.size()])
	while World.day_count - day0 < days:
		GameClock._process(dt)
		um._update_anchors(false)
		ul._process(dt)
		frames += 1
		if frames % 30 == 0:
			await tree.process_frame
		if frames % 300 == 0:
			var nf := 0
			var nm := 0
			var nv := 0
			for key: String in ul._counters:
				var c: Dictionary = ul._counters[key]
				if (c["root"] as Node3D).visible:
					nv += 1
				if c.get("fig") != null and (c["fig"] as Node3D).visible and (c["root"] as Node3D).visible:
					nf += 1
					if key.get_slice(":", 3).begins_with(">"):
						nm += 1
			var walking := 0
			for d: Division in Military.divisions:
				if not d.path.is_empty() and d.attacking == 0 and d.training == 0:
					walking += 1
			print("  kare %d gün %d saat %d  sn %.1f  sayaç %d görünür %d figür %d yürüyen %d (oyunda yürüyen %d) far=%d" % [frames,
				World.day_count - day0, GameClock.hour, (Time.get_ticks_msec() - t0) / 1000.0, ul._counters.size(), nv, nf, nm, walking, ul._was_far])
		var figs := {}
		for key: String in ul._counters:
			var c: Dictionary = ul._counters[key]
			var fig: Node3D = c.get("fig")
			var rt: Node3D = c["root"]
			if fig == null or not rt.visible or not fig.visible or not c.has("fxz"):
				continue
			var xz := Vector2(rt.position.x, rt.position.z)
			var moving: bool = key.get_slice(":", 3).begins_with(">")
			for d: Division in c["divs"]:
				if not d.path.is_empty() and d.attacking == 0:
					moving = true
			# kimlik sayacın kökü: anahtar yeniden kurulumda başka sayaca geçebilir (görselde sıçrama yokken sıçrama sayılırdı)
			figs["%d %s" % [rt.get_instance_id(), key]] = [xz, moving, str(c.get("stack_of", "")), float(c.get("yaw", 0.0)), int(c.get("cstate", 0)) != 0,
				ul._team(str(c["tag"]))]
		var keys: Array = figs.keys()
		if trace != "" and frames % 15 == 0:
			for key: String in ul._counters:
				if not key.contains(trace):
					continue
				var c: Dictionary = ul._counters[key]
				var rt: Node3D = c["root"]
				print("İZ kare %d %s vis=%s pos0=%s av=%s dk=%s dkt=%s side=%s yaw=%.2f vel=%s fxz=%s root=%s stack=%s" % [frames, key, rt.visible,
					c.get("pos0"), c.get("av"), c.get("dk"), c.get("dk_t"), c.get("side"), float(c.get("yaw", 0.0)), c.get("vel"), c.get("fxz"),
					Vector2(rt.position.x, rt.position.z), c.get("stack_of")])
		if frames % 300 == 0:
			var nmv := 0
			for k2: String in figs:
				if figs[k2][1]:
					nmv += 1
			print("    ölçülen figür %d (yürüyen %d)  ilk: %s" % [figs.size(), nmv, keys.slice(0, 3)])
		for i in keys.size():
			var a: Array = figs[keys[i]]
			# kayma: yer değişimi ile bakış arasındaki açı; sıçrama: karede 1 birimden uzun
			if prev.has(keys[i]):
				var dxz: Vector2 = (a[0] as Vector2) - (prev[keys[i]] as Vector2)
				var e: Array = slide.get(keys[i], [0, 0])
				if dxz.length() > 0.02:
					e[1] += 1
					var face := Vector2(cos(float(a[3])), -sin(float(a[3])))
					if absf(face.angle_to(dxz)) > deg_to_rad(60.0):
						e[0] += 1
				if dxz.length() > 1.0:
					jumps.append([keys[i], frames, dxz.length()])
				slide[keys[i]] = e
			for j in range(i + 1, keys.size()):
				var o: Array = figs[keys[j]]
				if a[2] != "" and a[2] == o[2]:
					continue
				var dv: Vector2 = (a[0] as Vector2) - (o[0] as Vector2)
				var md := Vector2(dv.x, dv.y * kz).length()
				var pk := "%s|%s" % [keys[i], keys[j]]
				if a[5] != o[5] and dv.length() < 2.0 * dmin:
					# düşmanlar iki kaide boyundan yakın: menzilde değil, dip dibe
					var fe: Array = foes.get(pk, [0, INF, ""])
					fe[0] += 1
					fe[1] = minf(fe[1], dv.length())
					fe[2] = "%s-%s%s" % ["Y" if a[1] else "D", "Y" if o[1] else "D", " muh" if (a[4] or o[4]) else ""]
					if verbose and fe[0] == 1:
						print("DÜŞMAN YAKIN kare %d gün %d: %s (%.1f) tür=%s" % [frames, World.day_count - day0, pk, dv.length(), fe[2]])
					foes[pk] = fe
				var e2: Array = overlap.get(pk, [0, INF, 0, 0, ""])
				if md < dmin * 0.9:
					e2[0] += 1
					e2[1] = minf(e2[1], md)
					e2[3] += 1
					e2[2] = maxi(e2[2], e2[3])
					e2[4] = "%s-%s%s" % ["Y" if a[1] else "D", "Y" if o[1] else "D", " muh" if (a[4] or o[4]) else ""]
					if verbose and (e2[0] == 1 or e2[0] % 150 == 0):
						var ca: Dictionary = ul._counters.get(str(keys[i]).get_slice(" ", 1), {})
						var cb: Dictionary = ul._counters.get(str(keys[j]).get_slice(" ", 1), {})
						print("ÖRTÜŞME kare %d gün %d: %s (%.1f) tür=%s  A pos0=%s av=%s dk=%s side=%s  B pos0=%s av=%s dk=%s side=%s" % [frames,
							World.day_count - day0, pk, md, e2[4], ca.get("pos0"), ca.get("av"), ca.get("dk"), ca.get("side"),
							cb.get("pos0"), cb.get("av"), cb.get("dk"), cb.get("side")])
				else:
					e2[3] = 0
				overlap[pk] = e2
		prev = {}
		for k: String in figs:
			prev[k] = figs[k][0]
	var pairs := 0
	var frames_ov := 0
	var worst: Array = []
	for pk: String in overlap:
		var e: Array = overlap[pk]
		if e[0] > 0:
			pairs += 1
			frames_ov += e[0]
			worst.append([e[2], pk, e[0], e[1], e[4]])
	worst.sort_custom(func(x: Array, y: Array) -> bool: return x[0] > y[0])
	var sl := 0
	var mv := 0
	for k: String in slide:
		sl += int(slide[k][0])
		mv += int(slide[k][1])
	print("FIGCHECK gün=%d kare=%d sn=%.1f  örtüşen çift=%d örtüşme karesi=%d  kayma=%d/%d hareket karesi  sıçrama=%d" % [days, frames,
		(Time.get_ticks_msec() - t0) / 1000.0, pairs, frames_ov, sl, mv, jumps.size()])
	for w: Array in worst.slice(0, 12):
		print("  en uzun %4d kare  toplam %4d  en yakın %5.1f  %s  %s" % [w[0], w[2], w[3], w[4], w[1]])
	for j: Array in jumps.slice(0, 8):
		print("  sıçrama kare %d: %s %.1f birim" % [j[1], j[0], j[2]])
	var fl: Array = []
	for pk: String in foes:
		fl.append([foes[pk][0], pk, foes[pk][1], foes[pk][2]])
	fl.sort_custom(func(x: Array, y: Array) -> bool: return x[0] > y[0])
	print("  düşman dip dibe (< %.0f birim): %d çift" % [2.0 * dmin, fl.size()])
	for w: Array in fl.slice(0, 8):
		print("  %4d kare  en yakın %5.1f  %s  %s" % [w[0], w[2], w[3], w[1]])
	return 0
