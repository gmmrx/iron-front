extends "res://tests/test_case.gd"
## Kara savaşı: muharebe çözümü, çarpanlar (nehir, çıkarma, ikmal, yakıt, siper), son askere kadar, kuşatma,
## ikmal hesabı, ordu → cephe dağılımı, topçu desteği, geri çekil ve saldırı tahmini. Oyuncu Almanya; Polonya ile savaşta.

const INFANTRY := 0
const ARMOR := 1

func player_tag() -> String:
	return "GER"

func _begin_war() -> void:
	GameClock.month = 5                       # mevsim cezası yok (kış/çamur)
	country("GER").war_goals["POL"] = true
	Diplomacy.declare_war("GER", "POL")
	for d in Military.divisions.duplicate():
		Military._remove(d)                   # boş cephe: yalnız testin tümenleri
	Military._rebuild_index()

## Almanya kontrolündeki bir kara bölgesi ile ona komşu Polonya bölgesi: [ger_pid, pol_pid]
func _border() -> Array:
	for pid in range(1, World.provinces.size()):
		var p := World.province(pid)
		if p == null or not p.is_land() or World.controller_tag(pid) != "GER":
			continue
		for n in World.land_neighbors(pid):
			if World.controller_tag(n) == "POL" and World.province(n).terrain == "plains" and not n in p.river_adjacent:
				return [pid, n]
	return []

func _div(tag: String, pid: int, ti: int = INFANTRY) -> Division:
	var d: Division = Military._create(country(tag), ti, pid, 1.0, 0)
	d.hold = false
	return d

# ------------------------------------------------------------------ çarpanlar
func test_attack_modifiers() -> void:
	_begin_war()
	GameClock.hour = 12                         # Avrupa'da gündüz: gece cezası bu testin konusu değil
	var b := _border()
	if not check(not b.is_empty(), "Almanya–Polonya ova sınırı"):
		return
	var d := _div("GER", b[0])
	near(Military.attack_mod(d, b[1]), 1.0, 0.0001, "ovada ikmalli, yakıtlı, planlamasız saldırı çarpanı")
	d.supplied = false
	near(Military.attack_mod(d, b[1]), 1.0 - Military.UNSUPPLIED_MALUS, 0.0001, "ikmalsiz saldırı −%35")
	d.supplied = true
	d.planning = 1.0
	near(Military.attack_mod(d, b[1]), 1.2, 0.0001, "tam planlama +%20")
	d.planning = 0.0
	# yakıt: zırhlı tümen yakıtsızken −%35, piyade etkilenmez (sade oyunda yakıt kapalı: ceza yok)
	var tank := _div("GER", b[0], ARMOR)
	country("GER").fuel = 0.0
	near(Military.attack_mod(tank, b[1]), 1.0 - (0.35 if Military.FUEL else 0.0), 0.0001, "yakıtsız zırhlı (yakıt açıksa −%35)")
	near(Military.attack_mod(d, b[1]), 1.0, 0.0001, "yakıtsızlık piyadeyi etkilemez")
	country("GER").fuel = 1000.0
	near(Military.attack_mod(tank, b[1]), 1.0, 0.0001, "yakıt varken ceza yok")
	# mevsim: kışın kuzeyde saldırı cezası
	GameClock.month = 1
	lt(Military.attack_mod(d, b[1]), 1.0, "kışın saldırı cezası")
	GameClock.month = 5

func test_river_and_amphibious_penalty() -> void:
	_begin_war()
	GameClock.hour = 12                         # Avrupa'da gündüz: gece cezası bu testin konusu değil
	# nehir: bir kara bölgesinden nehir komşusuna saldırı
	var src := 0
	var dst := 0
	for pid in range(1, World.provinces.size()):
		var p := World.province(pid)
		if p and p.is_land() and not p.river_adjacent.is_empty():
			src = pid
			dst = p.river_adjacent[0]
			break
	if check(src > 0, "nehir komşuluğu olan bölge"):
		var d := _div("GER", src)
		var t: float = Military.terrain[World.province(dst).terrain]["attack"]
		near(Military.attack_mod(d, dst), maxf(1.0 + t + Military.river_attack, 0.15), 0.0001, "nehir aşarak saldırı cezası (%.2f)" % Military.river_attack)
	# çıkarma: denizdeki tümenin kıyıya saldırısı
	var sea := 0
	var coast := 0
	for pid in range(1, World.provinces.size()):
		var p := World.province(pid)
		if p and p.is_land() and p.coastal:
			for n in p.adjacent:
				if World.province(n) and World.province(n).type == Province.Type.SEA:
					sea = n
					coast = pid
					break
		if sea > 0:
			break
	if check(sea > 0, "kıyı ve deniz bölgesi"):
		var d := _div("GER", sea)
		var t: float = Military.terrain[World.province(coast).terrain]["attack"]
		near(Military.attack_mod(d, coast), maxf(1.0 + t + Military.amphibious_attack, 0.15), 0.0001, "çıkarma cezası (%.2f)" % Military.amphibious_attack)

func test_defense_modifiers_and_entrenchment() -> void:
	_begin_war()
	var b := _border()
	if not check(not b.is_empty(), "sınır"):
		return
	var d := _div("POL", b[1])
	near(Military.defend_mod(d, b[1]), 1.0, 0.0001, "savunma çarpanı")
	d.supplied = false
	near(Military.defend_mod(d, b[1]), 1.0 - Military.UNSUPPLIED_MALUS, 0.0001, "ikmalsiz savunma −%35")
	d.supplied = true
	d.org = 0.0
	near(Military.defend_mod(d, b[1]), 1.0 - Military.EXHAUSTED_MALUS, 0.0001, "bitkin savunan −%50")
	var ent := country("POL").mod("entrenchment")
	d.idle_hours = 0
	near(Military.entrenchment(d), 1.0, 0.0001, "yeni gelen tümende siper yok")
	d.idle_hours = 120
	near(Military.entrenchment(d), 1.0 + 0.5 * (0.15 + ent), 0.0001, "5 günde siperin yarısı")
	d.idle_hours = 1000
	near(Military.entrenchment(d), 1.0 + 0.15 + ent, 0.0001, "siper en çok +%15 (+modifier)")

# ------------------------------------------------------------------ muharebe çözümü
## Tek tümene karşı tek tümen: savunanın organizasyon kaybı formülle aynı (rastgele çarpan 0,8–1,2 içinde)
func test_battle_damage_formula() -> void:
	_begin_war()
	var b := _border()
	if not check(not b.is_empty(), "sınır"):
		return
	var a := _div("GER", b[0])
	var d := _div("POL", b[1])
	a.xp = 0.15
	d.xp = 0.15
	d.idle_hours = 0
	var sa := Military.div_stats(a)
	var sd := Military.div_stats(d)
	var att: float = (sa["soft"] * (1.0 - sd["hardness"]) + sa["hard"] * sd["hardness"]) * Military.attack_mod(a, b[1]) * a.xp_mult()
	var dfn: float = sd["defense"]
	var hits: float = Military.HIT_DEF * minf(att, dfn) + Military.HIT_OPEN * maxf(att - dfn, 0.0)
	var org0 := d.org
	var str0 := d.strength
	var aorg0 := a.org
	a.path = PackedInt32Array([b[1]])
	a.attacking = b[1]
	seed(7)
	Military._resolve_battle(b[1], [a], [d])
	var lost := org0 - d.org
	check(lost >= hits * Military.ORG_DMG * 0.8 - 0.0001 and lost <= hits * Military.ORG_DMG * 1.2 + 0.0001,
		"savunanın organizasyon kaybı %.3f, beklenen %.3f ×(0,8–1,2)" % [lost, hits * Military.ORG_DMG])
	near((str0 - d.strength) * sd["hp"], lost / Military.ORG_DMG * Military.STR_DMG, 0.0001, "can kaybı isabetle orantılı")
	lt(a.org, aorg0, "saldıran da organizasyon kaybeder")
	check(Military.battles.has(b[1]), "muharebe kaydı")
	check(a.in_combat and d.in_combat, "iki taraf muharebede")

## Güçlü saldırı zayıf savunanı geri çekilmeye zorlar; bölgeye girilir ve kontrol değişir
func test_attack_wins_province() -> void:
	_begin_war()
	var b := _border()
	if not check(not b.is_empty(), "sınır"):
		return
	var attackers: Array = []
	for i in 6:
		var a := _div("GER", b[0])
		Military.order_move(a, b[1])
		attackers.append(a)
	var d := _div("POL", b[1])
	for h in 24 * 10:
		GameClock.advance_hours(1)
		if World.controller_tag(b[1]) == "GER":
			break
	check(d.province != b[1] or not d in Military.divisions, "savunan geri çekildi ya da yok oldu")
	eq(World.controller_tag(b[1]), "GER", "bölge ele geçirildi")

# ------------------------------------------------------------------ son askere kadar / geri çekilme / kuşatma
func test_hold_division_does_not_retreat() -> void:
	_begin_war()
	var b := _border()
	if not check(not b.is_empty(), "sınır"):
		return
	var a := _div("GER", b[0])
	a.attacking = b[1]
	var d := _div("POL", b[1])
	d.hold = true
	d.org = 0.0
	Military._resolve_battle(b[1], [a], [d])
	eq(d.province, b[1], "son askere kadar: organizasyonu bitse de yerinde")
	check(d in Military.divisions, "henüz yok olmadı")
	d.strength = 0.01
	d.org = 0.0
	Military._resolve_battle(b[1], [a], [d])
	check(not d in Military.divisions, "gücü bitince yok olur")

func test_division_retreats_without_hold() -> void:
	_begin_war()
	var b := _border()
	if not check(not b.is_empty(), "sınır"):
		return
	var a := _div("GER", b[0])
	a.attacking = b[1]
	var d := _div("POL", b[1])
	d.org = 0.0
	Military._resolve_battle(b[1], [a], [d])
	check(d in Military.divisions, "geri çekilen tümen yaşar")
	check(d.province != b[1], "organizasyonu biten tümen geri çekilir")
	eq(World.controller_tag(d.province), "POL", "dost bölgeye çekilir")

func test_encircled_division_destroyed() -> void:
	_begin_war()
	var b := _border()
	if not check(not b.is_empty(), "sınır"):
		return
	# savunanın çevresi tamamen düşman: 8 adım içinde dost ve boş bölge yok
	var ring: Array[int] = [b[1]]
	var seen := {b[1]: true}
	for depth in 9:
		var nxt: Array[int] = []
		for cur in ring:
			for n in World.land_neighbors(cur):
				if not seen.has(n):
					seen[n] = true
					nxt.append(n)
					World.set_controller(n, "GER")
		ring = nxt
	var a := _div("GER", b[0])
	a.attacking = b[1]
	var d := _div("POL", b[1])
	d.org = 0.0
	Military._resolve_battle(b[1], [a], [d])
	check(not d in Military.divisions, "kuşatılmış tümen yok olur")

func test_player_divisions_start_on_hold() -> void:
	var bad: Array = []
	for d in Military.divisions:
		if d.owner == "GER" and not d.hold:
			bad.append(d.id)
		if d.owner != "GER" and d.hold:
			bad.append("%s:%d" % [d.owner, d.id])
	none(bad, "oyuncunun tümenleri 'son askere kadar' açık, AI'nınkiler kapalı başlamalı")
	var nd: Division = Military._create(country("GER"), 0, World.capital_province("GER"), 1.0, 0)
	check(nd.hold, "oyuncunun yeni tümeni de 'son askere kadar' açık")

# ------------------------------------------------------------------ ikmal
func test_supply_in_enemy_territory() -> void:
	_begin_war()
	var b := _border()
	if not check(not b.is_empty(), "sınır"):
		return
	var home := _div("GER", b[0])
	var deep := _div("GER", b[1])               # hâlâ Polonya'nın kontrolündeki bölgede
	Military._compute_supply()
	World.day_count = 1                           # ikmal çift günlerde hesaplanır; bu gün yalnız uygular
	Military._on_day()
	check(home.supplied, "kendi toprağında ikmal var")
	if Military.SUPPLY:
		check(not deep.supplied, "düşman kontrolündeki bölgede ikmal yok")
		lt(deep.strength, 1.0, "ikmalsiz tümen günde güç kaybeder")
	else:
		# sade oyun: ikmal savaşı etkilemez; düşman toprağındaki tümen de ikmalli sayılır, güç kaybetmez
		check(deep.supplied, "ikmal kapalı: düşman toprağında da ikmalli")
		eq(deep.strength, 1.0, "ikmal kapalı: güç kaybı yok")

## Teşvik: nüfuz harcanır (tümen başına), bütünlük döner, süre boyunca saldırı ve savunma artar; süre bitince ya da
## teşvikliyken yeniden teşvik edilmez; nüfuz yetmezse olmaz
func test_motivate() -> void:
	_begin_war()
	var b := _border()
	if not check(not b.is_empty(), "sınır"):
		return
	var ger := country("GER")
	var d1 := _div("GER", b[0])
	var d2 := _div("GER", b[0])
	var md := Military.motivate_def()
	var base := Military.attack_mod(d1, b[1])
	d1.org = 0.0
	ger.political_power = 15.0
	eq(Military.motivate(ger, [d1, d2]), "MOTIVATE_ERR_PP", "nüfuz yetmezse olmaz")
	ger.political_power = 100.0
	eq(Military.motivate(ger, [d1, d2]), "", "teşvik edilir")
	near(ger.political_power, 100.0 - 2.0 * float(md["pp_per_division"]), 0.001, "tümen başına nüfuz")
	near(d1.org, Military.div_stats(d1)["org"] * float(md["org"]), 0.001, "bütünlüğün bir kısmı hemen döner")
	near(Military.attack_mod(d1, b[1]), base + float(md["bonus"]), 0.0001, "saldırı artar")
	eq(Military.motivate(ger, [d1]), "MOTIVATE_ERR_NONE", "teşviki süren yeniden teşvik edilmez")
	World.day_count += int(md["hours"]) / 24 + 1
	check(not Military.motivated(d1), "süre biter")
	near(Military.attack_mod(d1, b[1]), base, 0.0001, "süre bitince katkı yok")

# ------------------------------------------------------------------ ordu → cephe
func test_army_spreads_to_front() -> void:
	_begin_war()
	var divs: Array = []
	for i in 40:
		divs.append(_div("GER", World.capital_province("GER")))
	var army: Army = Military.create_army("GER", divs)
	army.enemy = "POL"
	var front := Military.front_provinces(army)
	gt(front.size(), 3, "Polonya cephesi bölgeleri")
	for i in 3:
		Military._armies_tick()
	var dest := {}
	var off := 0
	for d: Division in divs:
		var at: int = d.path[d.path.size() - 1] if d.is_moving() else d.province
		if at in front:
			dest[at] = int(dest.get(at, 0)) + 1
		else:
			off += 1
	eq(off, 0, "tüm tümenler cepheye yönelir")
	# karadan ulaşılabilen cephe (Doğu Prusya ayrı parça: oraya kendiliğinden deniz aşırı gidilmez)
	var comp: Dictionary = AI._components("GER")
	var mine: int = comp.get(World.capital_province("GER"), -1)
	var reach: Array = front.filter(func(pid: int) -> bool: return int(comp.get(pid, -2)) == mine)
	gt(reach.size(), 3, "karadan ulaşılan cephe")
	var empty: Array = reach.filter(func(pid: int) -> bool: return not dest.has(pid))
	if divs.size() >= reach.size():
		none(empty, "karadan ulaşılan boş cephe bölgesi kalmamalı")
	# yoğunluk: tümenler cephe bölgelerine dengeli dağılır (en kalabalık bölge ortalamanın 3 katını aşmaz; taarruz yığınağı yok)
	var most := 0
	for pid in dest:
		most = maxi(most, int(dest[pid]))
	check(most <= ceili(float(divs.size()) / reach.size() * 3.0), "en kalabalık cephe bölgesinde %d tümen" % most)

# ------------------------------------------------------------------ komutlar: topçu desteği, geri çekil, saldırı tahmini
const GARRISON := 2

func test_artillery_support_joins_battle() -> void:
	_begin_war()
	var b := _border()
	if not check(not b.is_empty(), "sınır"):
		return
	var a := _div("GER", b[0])
	a.attacking = b[1]
	var d := _div("POL", b[1])
	gt(float(Military.div_stats(a)["art_soft"]), 0.0, "piyade tümeninin topçusu var")
	eq(float(Military.stats(country("GER"), GARRISON)["art_soft"]), 0.0, "garnizon tümeninin topçusu yok")
	# destek yokken savunanın kaybı
	Military._engaged = {a: true, d: true}
	Military.supporting.clear()
	seed(7)
	Military._resolve_battle(b[1], [a], [d])
	var loss_alone: float = Military.div_stats(d)["org"] - d.org
	eq(int(Military.battles[b[1]]["att_support"]), 0, "komşuda destekçi yok")
	# aynı bölgede yerinde duran ikinci tümen topçusuyla katılır; garnizon katılmaz
	d.org = Military.div_stats(d)["org"]
	a.org = Military.div_stats(a)["org"]
	var s := _div("GER", b[0])
	var g := _div("GER", b[0], GARRISON)
	Military._engaged = {a: true, d: true}
	Military.supporting.clear()
	seed(7)
	Military._resolve_battle(b[1], [a], [d])
	var loss_sup: float = Military.div_stats(d)["org"] - d.org
	check(Military.supporting.has(s), "yerinde duran tümen destek verdi")
	check(not Military.supporting.has(g), "topçusuz garnizon destek vermez")
	eq(int(Military.battles[b[1]]["att_support"]), 1, "bir destekçi")
	gt(loss_sup, loss_alone * 1.05, "topçu desteği savunanın kaybını artırır")
	lt(loss_sup, loss_alone * 1.6, "destek muharebeyi tek başına çevirmez")
	# yürüyen tümen destek veremez
	d.org = Military.div_stats(d)["org"]
	s.path = PackedInt32Array([b[1]])
	Military._engaged = {a: true, d: true}
	Military.supporting.clear()
	Military._resolve_battle(b[1], [a], [d])
	check(not Military.supporting.has(s), "yürüyen tümen destek vermez")

func test_withdraw_breaks_off_with_cost() -> void:
	_begin_war()
	var b := _border()
	if not check(not b.is_empty(), "sınır"):
		return
	var a := _div("GER", b[0])
	a.path = PackedInt32Array([b[1]])
	a.attacking = b[1]
	var d := _div("POL", b[1])
	Military._combat()
	check(Military.battles.has(b[1]), "muharebe başladı")
	# saldırı altındaki tümen hemen kopar, bütünlüğünün dörtte biri gider
	var org0 := d.org
	check(Military.withdraw(d), "savunan geri çekilebilir")
	check(d.province != b[1], "muharebe bölgesinden çıktı")
	near(d.org, org0 * (1.0 - Military.WITHDRAW_ORG_COST), 0.001, "kopmanın bedeli")
	eq(World.controller_tag(d.province), "POL", "dost bölgeye çekildi")
	# saldıran geri çekilince saldırıyı bedelsiz keser
	var aorg := a.org
	check(Military.withdraw(a), "saldıran geri çekilebilir")
	eq(a.attacking, 0, "saldırı kesildi")
	near(a.org, aorg, 0.001, "saldırıyı kesmek bedelsiz")
	# kuşatılmış tümenin gidecek yeri yok
	var e := _div("POL", b[1])
	for n in World.land_neighbors(b[1]):
		World.set_controller(n, "GER")
	check(not Military.withdraw(e), "kuşatılmış tümen çekilemez")
	eq(e.province, b[1], "yerinde kaldı")

func test_attack_estimate() -> void:
	_begin_war()
	var b := _border()
	if not check(not b.is_empty(), "sınır"):
		return
	var d := _div("POL", b[1])
	var three := [_div("GER", b[0]), _div("GER", b[0]), _div("GER", b[0])]
	var strong := Military.attack_estimate(three, b[1])
	gt(float(strong["ratio"]), 1.0, "üçe bir: saldıran üstün")
	eq(int(strong["att"]), 3, "saldıran sayısı")
	eq(int(strong["def"]), 1, "savunan sayısı")
	var weak := Military.attack_estimate([three[0]], b[1])
	lt(float(weak["ratio"]), float(strong["ratio"]), "tek tümenle tahmin daha kötü (komşular destek verse de)")
	# siper: savunanın kazdığı siper tahmini düşürür ve etkenlerde görünür
	d.idle_hours = 240
	var dug := Military.attack_estimate(three, b[1])
	lt(float(dug["ratio"]), float(strong["ratio"]), "siper tahmini düşürür")
	var keys: Array = (dug["factors"] as Array).map(func(f: Array) -> String: return f[0])
	check("entrench" in keys, "siper etkenlerde")
	# boş düşman bölgesi: giren alır
	Military._remove(d)
	check(Military.attack_estimate(three, b[1]).has("empty"), "düşmansız bölge")
	# eğitimdeki tümen saldıramaz: tahmin yok
	var rookie := _div("GER", b[0])
	rookie.training = 5
	check(Military.attack_estimate([rookie], b[1]).is_empty(), "eğitimdeki tümenle tahmin yok")
