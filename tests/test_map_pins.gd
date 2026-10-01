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
	cam.focus_on(at, 200.0)
	pl._process(0.1)
	gt(pl._bpins.size(), 20, "yapı iğnesi sayısı")
	eq(pl._build_needles.multimesh.instance_count, pl._bpins.size(), "her yapı iğnesinin gövdesi")
	lt(PinLayer.BUILD_PIN_RANGE, PinLayer.BUILD_RANGE * 0.75, "iğne rozetlerden sonra (en yakında) çıkar")
	# [uzaklık, görünür mü, yerden yükseklik katı]: yakında ikon (yere yakın), en yakında iğnenin ucunda (iğnenin kendi
	# boy katıyla)
	var cases := [[200.0, true, 0.0], [100.0, true, 1.0], [PinLayer.BUILD_RANGE + 60.0, false, 0.0]]
	var kinds := {}
	for b: Array in pl._bpins:
		kinds[float(b[5])] = true
	gt(kinds.size(), 2, "yapı iğneleri farklı boylarda")
	for cs: Array in cases:
		var d: float = cs[0]
		cam.focus_on(at, d)
		pl._process(0.1)
		var wrong := 0
		for b: Array in pl._bpins:
			var root: Node3D = b[0]
			if root.visible != bool(cs[1]):
				wrong += 1
			elif root.visible and absf(root.position.y - float(b[2]) - d * (0.004 + PinLayer.BUILD_LIFT * float(b[5]) * float(cs[2]))) > 0.01:
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
				if (b[0] as Node3D).visible and absf((b[0] as Node3D).scale.x - pl._badge_k) > 0.001:
					stale += 1
			eq(stale, 0, "görünen rozetler şimdiki boyda, uzaklık %d" % int(d))
	_free_all([pl, cam, pm])

func test_building_pick_hover_and_card() -> void:
	var pm := ProbeMap.new()
	var cam := _camera()
	var pl := _pins(pm, cam)
	cam.focus_on(World.states.values()[0].center, 100.0)
	pl._process(0.1)
	var pin := _player_pin(pl)
	if not Economy.SHOW_BUILDINGS:
		check(pin.is_empty(), "yapılar gösterilmezken yapı iğnesi çizilmez")
		_free_all([pl, cam, pm])
		return
	if not check(not pin.is_empty(), "oyuncunun yapı iğnesi"):
		_free_all([pl, cam, pm])
		return
	var key: String = pin[0]
	var rec: Array = pin[1]
	cam.focus_on(rec[1], 100.0)
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

## Şehir iğnesi canlandırması: menzile girince yaylanarak tam boya çıkar, ekranın kenarındaki küçük durur, menzilden
## çıkınca küçülüp kaybolur (canlandırma listesinden düşer)
func test_city_pin_pops_and_fades() -> void:
	var pm := ProbeMap.new()
	var cam := _camera()
	var pl := _pins(pm, cam)
	var cap := -1
	for i in pl._pins.size():
		var c: City = pl._pins[i][4]
		if c != null and c.is_capital and c.state_id == World.countries[World.player_tag].capital_state:
			cap = i
	if not check(cap >= 0, "başkent iğnesi"):
		_free_all([pl, cam, pm])
		return
	var at: Vector2 = pl._pins[cap][0]
	cam.focus_on(at, 300.0)
	for k in 90:
		pl._process(1.0 / 60.0)
	near(pl._anim_s[cap], 1.0, 0.05, "ekranın ortasındaki iğne tam boy")
	var peak := 0.0
	cam.focus_on(at, 300.0)
	pl._anim_s[cap] = 0.0
	pl._anim_v[cap] = 0.0
	for k in 40:
		pl._process(1.0 / 60.0)
		peak = maxf(peak, pl._anim_s[cap])
	gt(peak, 1.02, "belirirken yaylanır (hafif aşar)")
	# oturduktan sonra görünen bütün iğneler tam boy (kaydırırken küçülüp büyümez, yerinde durur)
	for k in 90:
		pl._process(1.0 / 60.0)
	var off := 0
	for i: int in pl._live.keys():
		if absf(pl._anim_s[i] - 1.0) > 0.05:
			off += 1
	eq(off, 0, "tam boyda olmayan iğne")
	cam.focus_on(at, 3000.0)
	for k in 90:
		pl._process(1.0 / 60.0)
	eq(pl._anim_s[cap], 0.0, "menzil dışında iğne kaybolur")
	check(not pl._live.has(cap), "kaybolan iğne canlandırmadan düşer")
	_free_all([pl, cam, pm])

## İğnenin ucundaki şehir ikonu: dosyası olmayan kademede başkent madalyonla, öbürleri toplu iğne başıyla; ikonlu
## iğnede küre çizilmez
func test_city_pin_top_fallbacks() -> void:
	var pm := ProbeMap.new()
	var cam := _camera()
	var pl := _pins(pm, cam)
	var cap: City = null
	var town: City = null
	for c: City in World.cities:
		# şehre özel görseli olan şehir (city_pins/by_city) bu denetimin dışında
		if ResourceLoader.exists(PinLayer.CITY_ART_DIR + "city_%05d.png" % c.id):
			continue
		if c.is_capital and cap == null:
			cap = c
		elif not c.is_capital and c.victory_points == 0 and town == null:
			town = c
	# şehre özel görseli olmayan başkent kalmadıysa (city_pins/by_city) madalyon denetimi atlanır
	if cap != null:
		var cap_tex := pl._top_tex(cap)
		var path := PinLayer.TOP_DIR + "city_%s_capital.png" % cap.style
		if not ResourceLoader.exists(path) and not ResourceLoader.exists(PinLayer.TOP_DIR + "city_west_capital.png"):
			check(cap_tex == pl._medal(), "ikonu olmayan başkentte madalyon")
	if town != null and not ResourceLoader.exists(PinLayer.TOP_DIR + "city_west_village.png"):
		check(pl._top_tex(town) == null, "ikonu olmayan köyde toplu iğne başı")
	_free_all([pl, cam, pm])

## Yalnız büyük şehirlerin (başkent, 10+ zafer puanı) iğnesi var; küçük şehirler yalnız adla
func test_only_big_cities_have_pins() -> void:
	var pm := ProbeMap.new()
	var cam := _camera()
	var pl := _pins(pm, cam)
	var small := 0
	for pin: Array in pl._pins:
		var c: City = pin[4]
		if c != null and not (c.is_capital or c.victory_points >= 10):
			small += 1
	eq(small, 0, "küçük şehirde iğne")
	var big := 0
	for c: City in World.cities:
		if PinLayer.has_pin(c):
			big += 1
	eq(pl._pins.size(), big, "her büyük şehrin iğnesi")
	lt(float(big), World.cities.size() * 0.2, "iğneli şehirler azınlık")
	_free_all([pl, cam, pm])

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
	# bir bölgedeki bir ülkenin tümenleri tek figür: portre, hepsi aynı ordudaysa (ordunun ana sayacı). Ordunun üç tümeni
	# aynı bölgeye, dördüncüsü yerinde
	for d: Division in mine.slice(1, 3):
		d.province = mine[0].province
		d.path.clear()
	for d: Division in Military.divisions:
		if d.province == mine[0].province and not d in mine.slice(0, 3):
			d.province = mine[3].province if d.owner == tag else d.province
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
	# oklar söner
	GameClock.paused = true
	bt._process(BattleTicker.LIFE + 0.1)
	eq(bt._live.size(), 0, "oklar söndü")
	Military.battles.erase(pid)
	GameClock.paused = false
	bt._process(0.1)
	check(not bt._last.has(pid), "biten muharebe unutulur")
	GameClock.paused = was_paused
	_free_all([bt, cam, pm])

## Muharebede durum okları tümenin sayacının yanında çıkar ve sayacın çocuğudur (tümen yürürse ok da gider); sayacın
## çevresi üstün gelen tarafta yeşil, gerileyen tarafta kırmızı yanar
func test_battle_arrows_follow_counter_and_glow() -> void:
	var pm := ProbeMap.new()
	var cam := _camera()
	var ul := UnitLayer.new()
	ul.map = pm
	ul.camera = cam
	_tree().root.add_child(ul)
	var mine := Military.country_divisions(World.player_tag)
	if not check(mine.size() >= 2, "oyuncunun tümenleri"):
		_tree().root.remove_child(ul)
		_free_all([ul, cam, pm])
		return
	var att: Division = mine[0]
	var dfn: Division = mine[mine.size() - 1]
	ul._rebuild()
	var pid := dfn.province
	cam.focus_on(World.province(pid).center, 300.0)
	Military.battles[pid] = {"attackers": [att], "defenders": [dfn], "att_ratio": 0.7, "def_ratio": 0.3, "from": att.province}
	ul._refresh_combat()
	var ca: Dictionary = ul._counters[ul._div_key[att.id]]
	var cd: Dictionary = ul._counters[ul._div_key[dfn.id]]
	eq(int(ca.get("cstate", 0)), 1, "üstün gelen saldıran")
	eq(int(cd.get("cstate", 0)), -1, "gerileyen savunan")
	ul._was_far = 0
	ul._animate_combat(0.1)
	# yakında figürse levha biçimli parıltı gizli (kaideye binerdi): renk yine ayarlıdır, ateş çakmaları görünür
	var glow_on := not UnitLayer.FIGURES
	check((ca["glow"] as Sprite3D).visible == glow_on and (ca["glow"] as Sprite3D).modulate.g > 0.8 and (ca["glow"] as Sprite3D).modulate.r < 0.6, "saldıranın çevresi yeşil yanar")
	# ateş: muharebedeki kartın düşmana bakan kenarında turuncu çakmalar belirir
	var lit := 0
	for i in 60:
		ul._animate_combat(0.05)
		for f: Array in ca.get("flashes", []):
			if (f[0] as Sprite3D).visible:
				lit += 1
	if UnitLayer.FIGURES and ca.get("fig") != null:
		# figürde kart çakmaları yok: çatışmayı figür canlandırır (_combat_fx: nişan, namlu alevi, mermi izi)
		check(ul._glowing.has(ul._div_key[att.id]), "saldıran figür çatışma canlandırmasında")
	else:
		gt(lit, 0, "saldıranda ateş çakmaları")
	check((cd["glow"] as Sprite3D).visible == glow_on and (cd["glow"] as Sprite3D).modulate.r > 0.8 and (cd["glow"] as Sprite3D).modulate.g < 0.5, "savunanın çevresi kırmızı yanar")
	var bt := BattleTicker.new()
	bt.map = pm
	bt.camera = cam
	bt.units = ul
	_tree().root.add_child(bt)
	var was_paused := GameClock.paused
	GameClock.paused = false
	Military.battles[pid]["att_ratio"] = 0.5
	bt._process(0.1)
	Military.battles[pid]["att_ratio"] = 0.8
	bt._process(BattleTicker.SAMPLE + 0.1)
	var on_counter: Array = bt._live.filter(func(e: Array) -> bool: return (e[0] as Node).get_parent() == ca["root"])
	if check(not on_counter.is_empty(), "ok saldıranın sayacına bağlı"):
		var s: Sprite3D = on_counter[0][0]
		var before := s.global_position
		(ca["root"] as Node3D).position += Vector3(25, 0, 0)          # tümen yürüdü
		near(s.global_position.x - before.x, 25.0, 0.01, "ok sayaçla birlikte gider")
		gt(s.offset.x, 0.0, "ok sayacın sağında")
	Military.battles.erase(pid)
	GameClock.paused = was_paused
	_tree().root.remove_child(bt)
	_tree().root.remove_child(ul)
	for k: String in ul._counters:
		ul._counters[k]["root"].free()
	_free_all([bt, ul, cam, pm])

## Yok olan tümenin sayacı hemen silinmez: siyah-beyaz olur, yanıp sönmeden yavaşça söner, sonra silinir
func test_dead_division_counter_fades() -> void:
	var pm := ProbeMap.new()
	var cam := _camera()
	var ul := UnitLayer.new()
	ul.map = pm
	ul.camera = cam
	_tree().root.add_child(ul)
	ul._rebuild()
	var victim: Division = null
	for d in Military.country_divisions(World.player_tag):
		var cc: Dictionary = ul._counters[ul._div_key[d.id]]
		if (cc["divs"] as Array).size() == 1:
			victim = d
			break
	if not check(victim != null, "tek tümenli sayaç"):
		_tree().root.remove_child(ul)
		_free_all([ul, cam, pm])
		return
	var c: Dictionary = ul._counters[ul._div_key[victim.id]]
	var root: Node3D = c["root"]
	Military._remove(victim)
	ul._rebuild()
	check(is_instance_valid(root) and not root.is_queued_for_deletion(), "sayaç hemen silinmez")
	eq(ul._dying.size(), 1, "sönmeye başladı")
	var px := (c["bg"] as Sprite3D).texture.get_image().get_pixel(60, 50)
	near(px.r, px.g, 0.01, "resmi renksiz (gri)")
	var hidden := 0
	var last_a := 1.0
	var monotone := true
	for i in 50:
		ul._animate_dying(UnitLayer.DIE_TIME / 40.0)
		if not is_instance_valid(root) or root.is_queued_for_deletion():
			break
		if not root.visible:
			hidden += 1
		var a := (c["bg"] as Sprite3D).modulate.a
		if a > last_a + 0.001:
			monotone = false
		last_a = a
	eq(hidden, 0, "yanıp sönmez")
	check(monotone, "yavaşça söner (saydamlık hep azalır)")
	check(not is_instance_valid(root) or root.is_queued_for_deletion(), "sonunda silinir")
	eq(ul._dying.size(), 0, "sönenler listesi boşaldı")
	_tree().root.remove_child(ul)
	for k: String in ul._counters:
		ul._counters[k]["root"].free()
	_free_all([ul, cam, pm])

## Haritada birlik adı yazmaz; ordunun sayaçlarında sol üst köşenin dışında rütbe yıldızları: komutansız ordu ★,
## generalli ★★, mareşalli ★★★; ordusuz tümende yıldız yok
func test_army_rank_stars_instead_of_names() -> void:
	var tag := World.player_tag
	var mine := Military.country_divisions(tag)
	if not check(mine.size() >= 3, "oyuncunun tümenleri"):
		return
	var army := Military.create_army(tag, [mine[0]])
	var ul := UnitLayer.new()
	var pm := ProbeMap.new()
	var cam := MapCamera3D.new()
	ul.map = pm
	ul.camera = cam
	_tree().root.add_child(ul)
	cam.distance = 300.0
	ul._process(0.5)
	var ca: Dictionary = ul._counters[ul._div_key[mine[0].id]]
	var loose: Dictionary = {}
	for d: Division in mine:
		var c: Dictionary = ul._counters[ul._div_key[d.id]]
		if int(c["key"] if c.has("key") else 0) == 0 and d.army == 0:
			loose = c
			break
	eq(int(ca.get("star_n", 0)), 1, "komutansız ordu: tek yıldız")
	check(ca.has("stars") and (ca["stars"] as Sprite3D).visible, "yıldız görünür")
	var st: Sprite3D = ca["stars"]
	check(st.offset.x < 0.0 and st.offset.y > 0.0, "sol üst köşenin dışında")
	var cms := Military.commanders_of(tag)
	var general: Commander = null
	for cm in cms:
		if not cm.is_marshal():
			general = cm
	if general:
		Military.assign_army_commander(army, general.id)
		ul._rebuild()
		eq(int(ca.get("star_n", 0)), 2, "generalli ordu: iki yıldız")
	if not loose.is_empty():
		eq(int(loose.get("star_n", 0)), 0, "ordusuz tümende yıldız yok")
	var named := 0
	for key: String in ul._counters:
		if (ul._counters[key]["army"] as Label3D).visible:
			named += 1
	eq(named, 0, "haritada ad yazmaz")
	_tree().root.remove_child(ul)
	for k: String in ul._counters:
		ul._counters[k]["root"].free()
	_free_all([ul, cam, pm])
