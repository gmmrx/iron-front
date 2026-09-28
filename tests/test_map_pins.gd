extends "res://tests/test_case.gd"
## İğne haritasının etkileşimi (görüntüye bakmadan, sayıyla): yapı rozetleri orta uzaklıkta iğnesiz ikon, çok yakında
## iğneli; fare altındaki rozetin seçimi (PinLayer.pick_building), büyümesi ve sesi; yapı kartı (MapTooltip.show_building);
## ordu sayacında komutan portresi (UnitLayer); muharebe durum okları (BattleTicker).

const Probe := preload("res://tests/map_probe.gd")

class ProbeMap extends MapView3D:
	func province_at(world_xz: Vector2) -> int:
		return Probe.province_at(world_xz)
	func height_at(_world_xz: Vector2) -> float:
		return 0.0

func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree

## Ağaca eklenmiş kamera (izdüşüm için görüntü alanı gerekir)
func _camera() -> MapCamera3D:
	Probe.ensure()
	var cam := MapCamera3D.new()
	cam.map_size = Vector2(Probe.image.get_width(), Probe.image.get_height())
	_tree().root.add_child(cam)
	return cam

func _pins(pm: ProbeMap, cam: MapCamera3D) -> PinLayer:
	var pl := PinLayer.new()
	pl.map = pm
	pl.camera = cam
	_tree().root.add_child(pl)
	return pl

func _free_all(nodes: Array) -> void:
	for n: Node in nodes:
		if n.is_inside_tree():
			n.get_parent().remove_child(n)
		n.free()

## Oyuncunun (TUR) en çok rozetli yapı iğnesi: [anahtar, kayıt]
func _player_pin(pl: PinLayer) -> Array:
	var best: Array = []
	for key: String in pl._bstate:
		if key.begins_with("air:"):
			continue
		if World.states[int(key)].owner != World.player_tag:
			continue
		var rec: Array = pl._bstate[key][1]
		if best.is_empty() or (rec[3] as Array).size() > (best[1][3] as Array).size():
			best = [key, rec]
	return best

# ------------------------------------------------------------------ yapı rozetleri
func test_building_pins_icon_then_needle() -> void:
	var pm := ProbeMap.new()
	var cam := _camera()
	var pl := _pins(pm, cam)
	var at: Vector2 = World.states[World.countries[World.player_tag].capital_state].center
	cam.focus_on(at, 400.0)
	pl._process(0.1)
	gt(pl._bpins.size(), 20, "yapı iğnesi sayısı")
	eq(pl._build_needles.multimesh.instance_count, pl._bpins.size(), "her yapı iğnesinin gövdesi")
	lt(PinLayer.BUILD_PIN_RANGE, PinLayer.BUILD_RANGE * 0.6, "iğne rozetlerden çok sonra (yakında) çıkar")
	# [uzaklık, görünür mü, yerden yükseklik katı]: orta uzaklıkta ikon (yere yakın), çok yakında iğnenin ucunda
	var cases := [[650.0, true, 0.004], [150.0, true, 0.004 + PinLayer.BUILD_LIFT], [PinLayer.BUILD_RANGE + 60.0, false, 0.0]]
	for cs: Array in cases:
		var d: float = cs[0]
		cam.focus_on(at, d)
		pl._process(0.1)
		var wrong := 0
		for b: Array in pl._bpins:
			var root: Node3D = b[0]
			if root.visible != bool(cs[1]):
				wrong += 1
			elif root.visible and absf(root.position.y - float(b[2]) - d * float(cs[2])) > 0.01:
				wrong += 1
		eq(wrong, 0, "yapı rozetleri, uzaklık %d" % int(d))
		if bool(cs[1]):
			# uzakta rozet küçük, iğnede tam boy; görünen rozetler şimdiki boyda
			if d <= PinLayer.BUILD_PIN_RANGE:
				near(pl._badge_k, 1.0, 0.001, "iğnede rozet tam boy (%d)" % int(d))
			else:
				check(pl._badge_k < 0.85 and pl._badge_k >= PinLayer.FAR_BADGE - 0.001, "uzakta rozet küçük (%d): %.2f" % [int(d), pl._badge_k])
			var stale := 0
			for b: Array in pl._bpins:
				if (b[0] as Node3D).visible and absf(float(b[5]) - pl._badge_k) > 0.001:
					stale += 1
			eq(stale, 0, "görünen rozetler şimdiki boyda, uzaklık %d" % int(d))
	_free_all([pl, cam, pm])

func test_building_pick_hover_and_card() -> void:
	var pm := ProbeMap.new()
	var cam := _camera()
	var pl := _pins(pm, cam)
	cam.focus_on(World.states.values()[0].center, 150.0)
	pl._process(0.1)
	var pin := _player_pin(pl)
	if not check(not pin.is_empty(), "oyuncunun yapı iğnesi"):
		_free_all([pl, cam, pm])
		return
	var key: String = pin[0]
	var rec: Array = pin[1]
	cam.focus_on(rec[1], 150.0)
	pl._last_label_d = -1.0
	pl._process(0.1)
	var root: Node3D = rec[0]
	check(root.visible, "yakında rozet görünür")
	var tip := cam.unproject_position(root.global_position)
	var s := cam.get_viewport().get_visible_rect().size.y / 1080.0
	var items: Array = rec[3]
	var n := items.size()
	for k in n:
		var c := tip + Vector2(PinLayer._badge_x(k, n) * s, -PinLayer.BADGE_PX * 0.5 * s)
		var hit := pl.pick_building(c)
		eq(hit.get("building", ""), String(items[k][0]), "rozet %d seçimi" % k)
		eq(int(hit.get("sid", -1)), int(key), "rozet %d eyaleti" % k)
	eq(pl.pick_building(tip + Vector2(0.0, 300.0 * s)), {}, "iğnenin çok altında rozet yok")
	# fare altındaki rozet büyür, çıkınca eski boyuna döner
	var c0 := tip + Vector2(PinLayer._badge_x(0, n) * s, -PinLayer.BADGE_PX * 0.5 * s)
	var hit0 := pl.pick_building(c0)
	var plate: Sprite3D = rec[4][0][0]
	var before := plate.pixel_size
	pl.set_hovered_building(hit0)
	near(plate.pixel_size / before, PinLayer.HOVER_SCALE, 0.001, "fare altındaki rozet büyür")
	eq(pl.hovered_building(), String(hit0.get("hk", "")), "fare altındaki rozet")
	pl.set_hovered_building({})
	near(plate.pixel_size, before, 1e-9, "fare çıkınca rozet eski boyunda")
	eq(pl.hovered_building(), "", "fare altında rozet yok")
	# yapı kartı: adı, seviyesi, süren inşaatı
	var sid := int(key)
	var st: StateRegion = World.states[sid]
	var building: String = items[0][0]
	var me: Country = World.countries[World.player_tag]
	Economy.queue_building(me, st, building)
	var tip_card := MapTooltip.new()
	_tree().root.add_child(tip_card)
	tip_card.show_building(sid, building, Vector2(100, 100))
	eq(tip_card._title.text, Economy.building_name(building), "kart başlığı yapının adı")
	var mx := int(Economy.defs[building]["max"])
	check(tip_card._facts.get_parsed_text().contains("%d / %d" % [st.building_level(building), mx]), "kartta seviye: " + tip_card._facts.get_parsed_text())
	var queued := 0
	for pr: ConstructionProject in me.construction_queue:
		if pr.state_id == sid and pr.building == building:
			queued += 1
	if queued > 0:
		check(tip_card._economy.visible and tip_card._economy.get_parsed_text().contains(str(queued)), "kartta süren inşaat: " + tip_card._economy.get_parsed_text())
	check(tip_card._hint.visible, "oyuncunun yapısında tıklama ipucu")
	_free_all([tip_card, pl, cam, pm])

func test_building_hover_sounds_defined() -> void:
	for b: String in PinLayer.BUILDINGS:
		check(Audio.SOUNDS.has("map_" + b), "yapı sesi tanımlı: map_" + b)
		var fb: String = Audio.MAP_FALLBACK.get(b, "")
		check(Audio.SOUNDS.has(fb), "yapı sesi yedeği tanımlı: %s -> %s" % [b, fb])

# ------------------------------------------------------------------ komutan portresi
func test_army_commander_portrait_on_counter() -> void:
	var tag := World.player_tag
	var mine := Military.country_divisions(tag).slice(0, 4)
	if not check(mine.size() == 4, "oyuncunun 4 tümeni"):
		return
	for d: Division in mine.slice(1):
		d.province = mine[0].province
		d.path.clear()
	var army := Military.create_army(tag, mine.slice(0, 3))
	var cms := Military.commanders_of(tag)
	if not check(not cms.is_empty(), "oyuncunun komutanı"):
		return
	Military.assign_army_commander(army, cms[0].id)
	var ul := UnitLayer.new()
	var pm := ProbeMap.new()
	var cam := MapCamera3D.new()
	ul.map = pm
	ul.camera = cam
	_tree().root.add_child(ul)
	cam.distance = 300.0
	ul._process(0.5)
	var with_portrait := 0
	var shown := 0
	for key: String in ul._counters:
		var c: Dictionary = ul._counters[key]
		if int(c.get("pcm", 0)) != 0:
			with_portrait += 1
			eq(int(key.get_slice(":", 2)), army.id, "portre ordunun sayacında")
			if c.has("pnode") and (c["pnode"] as Node3D).visible:
				shown += 1
	eq(with_portrait, 1, "ordu başına tek portre")
	eq(shown, 1, "yakında portre görünür")
	cam.distance = UnitLayer.NAME_DIST + 100.0
	ul._process(0.01)
	for key: String in ul._counters:
		var c: Dictionary = ul._counters[key]
		if c.has("pnode"):
			check(not (c["pnode"] as Node3D).visible, "uzakta portre gizli")
	_free_all([ul, pm, cam])

# ------------------------------------------------------------------ muharebe durum okları
func test_battle_ticker_arrows() -> void:
	var pm := ProbeMap.new()
	var cam := _camera()
	var bt := BattleTicker.new()
	bt.map = pm
	bt.camera = cam
	_tree().root.add_child(bt)
	var pid := 0
	var from := 0
	for cand in World.provinces.size():
		var pr := World.province(cand)
		if pr and pr.is_land() and World.controller_tag(cand) == World.player_tag and not World.land_neighbors(cand).is_empty():
			pid = cand
			from = World.land_neighbors(cand)[0]
			break
	if not check(pid > 0, "oyuncunun kara bölgesi"):
		_free_all([bt, cam, pm])
		return
	var to := World.province(pid).center
	cam.focus_on(to, 300.0)
	var was_paused := GameClock.paused
	GameClock.paused = false
	Military.battles[pid] = {"attackers": [], "defenders": [], "att_ratio": 0.5, "def_ratio": 0.5, "from": from}
	bt._process(0.1)
	eq(bt._live.size(), 0, "ilk bakışta ok yok")
	Military.battles[pid]["att_ratio"] = 0.502           # %1'den az değişim: ok yok
	bt._process(BattleTicker.SAMPLE + 0.1)
	eq(bt._live.size(), 0, "küçük değişimde ok yok")
	Military.battles[pid]["att_ratio"] = 0.8             # saldıran üstün geliyor
	bt._process(BattleTicker.SAMPLE + 0.1)
	if eq(bt._live.size(), 2, "iki tarafta birer ok"):
		var a: Sprite3D = bt._live[0][0]
		var d: Sprite3D = bt._live[1][0]
		check(a.texture == bt._up, "saldıranda yeşil ▲")
		check(d.texture == bt._down, "savunanda kırmızı ▼")
		var fp := World.unwrap_near(to, World.province(from).center)
		lt(Vector2(a.position.x, a.position.z).distance_to(fp), Vector2(a.position.x, a.position.z).distance_to(to) + 0.001,
			"saldıranın oku saldırının geldiği yanda")
	Military.battles[pid]["att_ratio"] = 0.3             # durum döndü: bu kez saldıranda kırmızı ▼
	bt._process(BattleTicker.SAMPLE + 0.1)
	var fresh: Array = bt._live.filter(func(e: Array) -> bool: return float(e[1]) == 0.0)
	if eq(fresh.size(), 2, "dönüşte iki yeni ok"):
		check((fresh[0][0] as Sprite3D).texture == bt._down, "saldıranda kırmızı ▼")
		check((fresh[1][0] as Sprite3D).texture == bt._up, "savunanda yeşil ▲")
	# oklar söner, yeniden kullanılır
	GameClock.paused = true
	bt._process(BattleTicker.LIFE + 0.1)
	eq(bt._live.size(), 0, "oklar söndü")
	eq(bt._free.size(), 4, "sönen oklar yeniden kullanılacak")
	Military.battles.erase(pid)
	GameClock.paused = false
	bt._process(0.1)
	check(not bt._last.has(pid), "biten muharebe unutulur")
	GameClock.paused = was_paused
	_free_all([bt, cam, pm])

# ------------------------------------------------------------------ yol önizlemesi
func test_path_preview_arrow() -> void:
	var ul := UnitLayer.new()
	var pm := ProbeMap.new()
	var cam := MapCamera3D.new()
	ul.map = pm
	ul.camera = cam
	_tree().root.add_child(ul)
	cam.distance = 300.0
	ul._process(0.5)
	var d: Division = null
	var target := 0
	for cand: Division in Military.country_divisions(World.player_tag):
		if cand.training > 0:
			continue
		for n: int in World.land_neighbors(cand.province):
			if World.controller_tag(n) == World.player_tag:
				d = cand
				target = n
				break
		if d:
			break
	if not check(d != null, "komşu bölgeye yürüyebilecek tümen"):
		_free_all([ul, pm, cam])
		return
	var e := Military.eta(d, target)
	eq((e["path"] as PackedInt32Array).size(), 1, "komşu bölgeye tek adımlık yol")
	near(float(e["hours"]), Military.eta_hours(d, target), 0.001, "eta ve eta_hours aynı")
	ul.selected = [d]
	ul.preview_paths = [[d, e["path"]]]
	ul._draw_preview()
	check(ul._preview.mesh != null, "seçili tümenin yolu soluk okla önizlenir")
	check(d.path.is_empty(), "önizleme emir vermez")
	ul.preview_paths = []
	ul._draw_preview()
	check(ul._preview.mesh == null, "önizleme kalkınca ok yok")
	_free_all([ul, pm, cam])
