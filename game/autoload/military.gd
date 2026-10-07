extends Node
## Kara savaşı: tümen şablonları, konuşlandırma, A* yol bulma, saatlik hareket ve muharebe,
## geri çekilme/kuşatma, ikmal, takviye. Hava desteği Air kanatlarından, deniz gücü Navy filolarından gelir.

signal divisions_changed               ## konum/sayı değişti (harita katmanı yeniden çizer)
signal battles_changed
signal division_destroyed(tag: String)

const UNITS_PATH := "res://data/common/units.json"
const COMMANDERS_PATH := "res://data/common/commanders.json"
const GENERAL_BONUS := 0.04            ## ordu komutanının beceri başına saldırı/savunma katkısı
const MARSHAL_BONUS := 0.02            ## ordular grubu mareşalinin beceri başına katkısı (gruptaki bütün ordulara)
const ARMY_CAP := 24                   ## generalin tam etkiyle yönettiği tümen sayısı (fazlası katkıyı böler)
const PROMOTE_COST := 30.0             ## generali mareşalliğe terfi (komuta gücü)
const RECRUIT_COST := 15.0             ## subaylar arasından yeni general yetiştir (komuta gücü)
const ORG_DMG := 0.0367                ## isabet başına bütünlük hasarı (piyade bütünlüğü 100)
const STR_DMG := 0.022                 ## isabet başına dayanıklılık (hp) hasarı
const HIT_DEF := 0.1                   ## savunmayla karşılanan saldırının isabet oranı
const HIT_OPEN := 0.4                  ## savunmayı aşan saldırının isabet oranı
const RETREAT_ORG := 0.12
const SEA_SPEED := 20.0                ## km/saat (konvoy)
const EMBARK_COST := 250.0             ## km eşdeğeri
const TRAINING_DAYS := 14              ## yeni tümenin eğitim süresi (gün)

var battalions: Dictionary = {}
var default_templates: Array = []
var terrain: Dictionary = {}
var river_attack := -0.3
var amphibious_attack := -0.5
var night_attack := 0.0                ## gece saldırı cezası (units.json night.attack; gece payıyla ölçeklenir)
var start_divisions: Dictionary = {}
var divisions: Array[Division] = []
var armies: Array[Army] = []
var _next_army := 1
var commanders: Array[Commander] = []
var groups: Array[ArmyGroup] = []
var _next_commander := 1
var _next_group := 1
var _cmd_data: Dictionary = {}
var _bonus_cache := {}                 ## ordu id -> komuta katkısı (değişince temizlenir)
const ARMY_COLORS := [Color(0.95, 0.8, 0.3), Color(0.45, 0.8, 1.0), Color(1.0, 0.5, 0.4), Color(0.6, 0.95, 0.5),
		Color(0.85, 0.6, 1.0), Color(1.0, 0.65, 0.2)]
signal armies_changed
var by_province: Dictionary = {}       ## pid -> Array[Division]
var at_sea: Dictionary = {}            ## denizdeki (nakliyedeki) tümenler: Division -> true
var battles: Dictionary = {}           ## pid -> {attackers, defenders, att_org, def_org}
var skirmishes: Array = []             ## [bölge a, bölge b]: komşu bölgelerde duran düşmanların karşılıklı ateşi (bu saat)
var naval_power: Dictionary = {}       ## tag -> güç
var _stats_cache: Dictionary = {}      ## "TAG:i" -> istatistik
var _supplied: Dictionary = {}         ## tag -> {pid: true}
var _next_id := 1
var _dirty := false

func _ready() -> void:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(UNITS_PATH))
	battalions = d["battalions"]
	default_templates = d["templates"]
	terrain = d["terrain"]
	river_attack = float(d["river_attack"])
	amphibious_attack = float(d["amphibious_attack"])
	night_attack = float((d.get("night", {}) as Dictionary).get("attack", 0.0))
	start_divisions = d["start_divisions"]
	_division_equipment = d["division_equipment"]
	_cmd_data = JSON.parse_string(FileAccess.get_file_as_string(COMMANDERS_PATH))
	armies_changed.connect(func() -> void: _bonus_cache.clear())
	GameClock.hour_passed.connect(_on_hour)
	GameClock.hour_late.connect(_day_stage)       # genel günlük işler saatin ikinci yarısında (ayrı kare)
	Diplomacy.wars_changed.connect(invalidate_masks)
	Diplomacy.diplomacy_changed.connect(func(_t: String) -> void: invalidate_masks())
	World.daily_update.connect(_on_day_sliced)
	Research.tech_completed.connect(func(tag: String, _t: String) -> void: invalidate_stats(tag))

var _division_equipment: Dictionary = {}

func reset() -> void:
	armies.clear()
	_army_map.clear()
	_next_army = 1
	groups.clear()
	_next_group = 1
	divisions.clear()
	_div_version += 1
	by_province.clear()
	battles.clear()
	_stats_cache.clear()
	_supplied.clear()
	# günlük önbellekler: yeni oyun da 0. günde başladığı için eski oyunun kayıtları kullanılmasın
	_front_cache.clear()
	_front_day = -1
	_target_cache.clear()
	_target_day = -1
	invalidate_masks()
	_fmasks.clear()
	_fmask_day = -1
	reset_explored()
	_next_id = 1
	for c: Country in World.countries.values():
		c.templates = []
		for t: Dictionary in default_templates:
			c.templates.append({"name": Politics.loc(t["name"]), "battalions": t["battalions"].duplicate()})
		c.manpower_used = 0
		c.sp = float(recruit_def()["start_sp"])
		if c.exists():
			_spawn_start_army(c)
	init_commanders()
	_rebuild_index()

# ------------------------------------------------------------------ şablon istatistikleri
func invalidate_stats(tag: String) -> void:
	for k: String in _stats_cache.keys():
		if k.begins_with(tag + ":"):
			_stats_cache.erase(k)
	for d in divisions:
		if d.owner == tag:
			d.s = {}

func stats(c: Country, ti: int) -> Dictionary:
	var key := "%s:%d" % [c.tag, ti]
	if _stats_cache.has(key):
		return _stats_cache[key]
	var t: Dictionary = c.templates[clampi(ti, 0, c.templates.size() - 1)]
	var s := {"soft": 0.0, "hard": 0.0, "defense": 0.0, "breakthrough": 0.0, "hp": 0.0, "org": 0.0, "width": 0.0,
			"speed": 99.0, "hardness": 0.0, "armor": 0.0, "piercing": 0.0, "manpower": 0.0, "equipment": {}, "fuel_use": 0.0,
			"art_soft": 0.0}
	var n := 0.0
	var org_sum := 0.0
	var org_n := 0.0
	for b: String in t["battalions"]:
		var cnt := float(t["battalions"][b])
		if cnt <= 0.0 or not battalions.has(b):
			continue
		var bd: Dictionary = battalions[b]
		var cat: String = bd["category"]
		for k in ["soft", "hard", "defense", "breakthrough"]:
			s[k] += float(bd[k]) * cnt * (1.0 + c.mod(cat + "_" + k))
		if cat == "artillery":
			s["art_soft"] += float(bd["soft"]) * cnt * (1.0 + c.mod(cat + "_soft"))
		s["hp"] += float(bd["hp"]) * cnt
		s["width"] += float(bd["width"]) * cnt
		s["speed"] = minf(s["speed"], float(bd["speed"]) * (1.0 + c.mod(cat + "_speed")))
		s["hardness"] += float(bd["hardness"]) * cnt
		s["armor"] = maxf(s["armor"], float(bd["armor"]))
		s["piercing"] = maxf(s["piercing"], float(bd["piercing"]))
		s["manpower"] += float(bd["manpower"]) * cnt
		# yakıt (saatlik, hareket/muharebede): zırhlı tabur ağır, motorlu hafif tüketir
		if cat == "armor":
			s["fuel_use"] += (0.25 if b == "medium_armor" else 0.15) * cnt
		elif b == "motorized":
			s["fuel_use"] += 0.08 * cnt
		if float(bd["org"]) > 0.0:
			org_sum += float(bd["org"]) * cnt
			org_n += cnt
		n += cnt
		for e: String in bd["equipment"]:
			s["equipment"][e] = float(s["equipment"].get(e, 0.0)) + float(bd["equipment"][e]) * cnt
	for e: String in _division_equipment:
		s["equipment"][e] = float(s["equipment"].get(e, 0.0)) + float(_division_equipment[e])
	s["hardness"] = s["hardness"] / maxf(n, 1.0)
	s["org"] = (org_sum / maxf(org_n, 1.0)) * (1.0 + c.mod("org"))
	s["defense"] *= 1.0 + c.mod("defense")
	s["soft"] *= 1.0 + c.mod("attack")
	s["hard"] *= 1.0 + c.mod("attack")
	s["art_soft"] *= 1.0 + c.mod("attack")
	s["breakthrough"] *= 1.0 + c.mod("breakthrough")
	s["speed"] = (4.0 if s["speed"] > 90.0 else s["speed"]) * (1.0 + c.mod("speed"))
	s["hp"] = maxf(s["hp"], 1.0)
	_stats_cache[key] = s
	return s

func div_stats(d: Division) -> Dictionary:
	if d.s.is_empty():
		d.s = stats(World.countries[d.owner], d.template)
	return d.s

func template_name(c: Country, ti: int) -> String:
	return c.templates[ti]["name"]

# ------------------------------------------------------------------ konuşlandırma
## Eksik olan (ekipman: adet, insan gücü) — boşsa konuşlandırılabilir
func deploy_shortfall(c: Country, ti: int) -> Dictionary:
	var s := stats(c, ti)
	var out := {}
	for e: String in s["equipment"]:
		var need := float(s["equipment"][e])
		if not Research.is_unlocked(c, e):
			out[e] = need
		elif float(c.stockpile.get(e, 0.0)) < need * 0.5:
			out[e] = need * 0.5 - float(c.stockpile.get(e, 0.0))
	if c.available_manpower() < int(s["manpower"]):
		out["manpower"] = s["manpower"] - c.available_manpower()
	return out

func deploy(c: Country, ti: int, pid: int = 0, instant := false) -> Division:
	if not deploy_shortfall(c, ti).is_empty():
		return null
	var s := stats(c, ti)
	var fill := 1.0
	for e: String in s["equipment"]:
		var need := float(s["equipment"][e])
		var have := float(c.stockpile.get(e, 0.0))
		var take := minf(need, have)
		c.stockpile[e] = have - take
		fill = minf(fill, take / maxf(need, 1.0))
	c.manpower_used += int(s["manpower"])
	return _create(c, ti, pid if pid > 0 else World.capital_province(c.tag), fill, 0 if instant else training_days(c))

## Yeni tümenin eğitim süresi (gün): askerlik yasası uzatır (training_time)
func training_days(c: Country) -> int:
	return maxi(roundi(TRAINING_DAYS * (1.0 + c.mod("training_time"))), 1)

func _create(c: Country, ti: int, pid: int, strength: float, training: int) -> Division:
	var d := Division.new()
	d.id = _next_id
	_next_id += 1
	d.owner = c.tag
	d.hold = World.in_game and c.tag == World.player_tag   # oyuncunun askeri kendiliğinden geri dönmez
	d.template = ti
	d.province = pid
	d.strength = clampf(strength, 0.05, 1.0)
	d.org = stats(c, ti)["org"] * (0.3 if training > 0 else 1.0)
	d.training = training
	var count := 0
	for x in divisions:
		if x.owner == c.tag:
			count += 1
	d.name = UnitNames.name_of(c.tag, UnitNames.division_kind(c.templates[clampi(ti, 0, c.templates.size() - 1)]["battalions"]), count + 1)
	divisions.append(d)
	_div_version += 1
	_add_index(d)
	_dirty = true
	return d

## Olay/odak ödülü: ekipmansız bedava tümen
func spawn_free_divisions(c: Country, n: int) -> void:
	var pids := _border_or_capital_provinces(c)
	for i in n:
		var d := _create(c, 0, pids[i % pids.size()] if not pids.is_empty() else World.capital_province(c.tag), 1.0, 0)
		c.manpower_used += int(stats(c, 0)["manpower"])

func disband(d: Division) -> void:
	var c: Country = World.countries.get(d.owner)
	if c:
		c.manpower_used = maxi(c.manpower_used - int(div_stats(d)["manpower"] * d.strength), 0)
	_remove(d)

func remove_all(tag: String) -> void:
	for d in divisions.duplicate():
		if d.owner == tag:
			_remove(d)
	armies = armies.filter(func(a: Army) -> bool: return a.owner != tag)
	_army_map.clear()
	groups = groups.filter(func(g: ArmyGroup) -> bool: return g.owner != tag)
	commanders = commanders.filter(func(cm: Commander) -> bool: return cm.owner != tag)
	armies_changed.emit()

var loss_log := {}                    ## hata ayıklama: "TAG:neden" -> yok olan tümen

# ------------------------------------------------------------------ ordular ve cepheler
func create_army(tag: String, divs: Array) -> Army:
	var a := Army.new()
	a.id = _next_army
	_next_army += 1
	a.owner = tag
	var n := 1
	for o in armies:
		if o.owner == tag:
			n += 1
	a.name = UnitNames.name_of(tag, "army", n)
	a.color = ARMY_COLORS[(n - 1) % ARMY_COLORS.size()]
	armies.append(a)
	for d: Division in divs:
		d.army = a.id
		d.manual = false
	armies_changed.emit()
	return a

## Kimlikten ordu: savaşta tümen başına sorulur (komuta katkısı); listeyi her seferinde taramak yerine sözlük. Ordular
## listesi değişince (_army_map.clear()) ya da bulunamayan kimlikte yeniden kurulur
var _army_map := {}
func army_by_id(id: int) -> Army:
	if id == 0:
		return null
	var a: Army = _army_map.get(id)
	if a == null:
		_army_map.clear()
		for x in armies:
			_army_map[x.id] = x
		a = _army_map.get(id)
	return a

func army_divisions(a: Army) -> Array[Division]:
	var out: Array[Division] = []
	for d in divisions:
		if d.army == a.id:
			out.append(d)
	return out

func disband_army(a: Army) -> void:
	for d in divisions:
		if d.army == a.id:
			d.army = 0
	armies.erase(a)
	_army_map.clear()
	armies_changed.emit()

# ------------------------------------------------------------------ komuta zinciri: komutanlar, ordular grupları
## Her ülkeye komutan kadrosu: dönemin komutanları (data/common/commanders.json), liste kısaysa yöresel isimlerle
## ordu büyüklüğüne göre tamamlanır.
func init_commanders() -> void:
	commanders.clear()
	_next_commander = 1
	_bonus_cache.clear()
	var roster: Dictionary = _cmd_data.get("roster", {})
	for c: Country in World.countries.values():
		if not c.exists():
			continue
		for e: Array in roster.get(c.tag, []):
			_add_commander(c.tag, str(e[0]), int(e[1]), int(e[2]))
		var want := clampi(2 + country_divisions(c.tag).size() / 8, 2, 6)
		while commanders_of(c.tag).size() < want:
			_add_commander(c.tag, generate_name(c.tag), 1 + int(commanders_of(c.tag).size() == 0), 0)

func _add_commander(tag: String, cname: String, skill: int, rank: int) -> Commander:
	var cm := Commander.new()
	cm.id = _next_commander
	_next_commander += 1
	cm.owner = tag
	cm.name = cname
	cm.skill = clampi(skill, 1, Commander.MAX_SKILL)
	cm.rank = rank as Commander.Rank
	commanders.append(cm)
	return cm

## Ülkenin yöresine uygun, kadroda olmayan bir isim (belirlenimci: aynı tohumla aynı isimler)
func generate_name(tag: String) -> String:
	var pools: Dictionary = _cmd_data.get("pools", {})
	var pool: Dictionary = pools.get(str(_cmd_data.get("pool", {}).get(tag, "english")), pools.get("english", {}))
	var given: Array = pool.get("given", ["John"])
	var family: Array = pool.get("family", ["Smith"])
	var used := {}
	for cm in commanders_of(tag):
		used[cm.name] = true
	var h := absi(hash(tag))
	for i in 200:
		var g: String = given[(h / 7 + i * 5) % given.size()]
		var f: String = family[(h + i * 3 + i / family.size()) % family.size()]
		var n := (f + " " + g) if pool.get("family_first", false) else (g + " " + f)
		if not used.has(n):
			return n
	return "%s %d" % [family[0], commanders.size()]

func commanders_of(tag: String) -> Array[Commander]:
	var out: Array[Commander] = []
	for cm in commanders:
		if cm.owner == tag:
			out.append(cm)
	return out

func commander_by_id(id: int) -> Commander:
	if id <= 0:
		return null
	for cm in commanders:
		if cm.id == id:
			return cm
	return null

func group_by_id(id: int) -> ArmyGroup:
	if id <= 0:
		return null
	for g in groups:
		if g.id == id:
			return g
	return null

func groups_of(tag: String) -> Array[ArmyGroup]:
	var out: Array[ArmyGroup] = []
	for g in groups:
		if g.owner == tag:
			out.append(g)
	return out

func armies_of(tag: String) -> Array[Army]:
	var out: Array[Army] = []
	for a in armies:
		if a.owner == tag:
			out.append(a)
	return out

func group_armies(g: ArmyGroup) -> Array[Army]:
	var out: Array[Army] = []
	for a in armies:
		if a.group == g.id:
			out.append(a)
	return out

## Komutanın görevi: yönettiği ordu ya da ordular grubu (yoksa null → boşta)
func post_of(cm: Commander) -> RefCounted:
	for a in armies:
		if a.commander == cm.id:
			return a
	for g in groups:
		if g.commander == cm.id:
			return g
	return null

func free_commanders(tag: String, marshals_only := false) -> Array[Commander]:
	var out: Array[Commander] = []
	for cm in commanders_of(tag):
		if post_of(cm) == null and (not marshals_only or cm.is_marshal()):
			out.append(cm)
	return out

func _release(cm_id: int) -> void:
	for a in armies:
		if a.commander == cm_id:
			a.commander = 0
	for g in groups:
		if g.commander == cm_id:
			g.commander = 0

## Orduya komutan ata (0 = komutansız); komutan başka görevdeyse oradan alınır
func assign_army_commander(a: Army, cm_id: int) -> void:
	var cm := commander_by_id(cm_id)
	if cm_id != 0 and (cm == null or cm.owner != a.owner):
		return
	_release(cm_id)
	a.commander = cm_id
	armies_changed.emit()

## Ordular grubuna mareşal ata (yalnız mareşal rütbesi)
func assign_group_commander(g: ArmyGroup, cm_id: int) -> void:
	var cm := commander_by_id(cm_id)
	if cm_id != 0 and (cm == null or cm.owner != g.owner or not cm.is_marshal()):
		return
	_release(cm_id)
	g.commander = cm_id
	armies_changed.emit()

func can_promote(cm: Commander) -> bool:
	var c: Country = World.countries.get(cm.owner)
	return c != null and not cm.is_marshal() and c.command_power >= PROMOTE_COST

func promote(cm: Commander) -> bool:
	if not can_promote(cm):
		return false
	World.countries[cm.owner].command_power -= PROMOTE_COST
	cm.rank = Commander.Rank.MARSHAL
	armies_changed.emit()
	return true

func can_recruit(tag: String) -> bool:
	var c: Country = World.countries.get(tag)
	return c != null and c.command_power >= RECRUIT_COST

## Subaylar arasından yeni general (beceri 1)
func recruit_commander(tag: String) -> Commander:
	if not can_recruit(tag):
		return null
	World.countries[tag].command_power -= RECRUIT_COST
	var cm := _add_commander(tag, generate_name(tag), 1, 0)
	armies_changed.emit()
	return cm

func create_group(tag: String) -> ArmyGroup:
	var g := ArmyGroup.new()
	g.id = _next_group
	_next_group += 1
	g.owner = tag
	g.name = UnitNames.name_of(tag, "army_group", groups_of(tag).size() + 1)
	groups.append(g)
	armies_changed.emit()
	return g

func disband_group(g: ArmyGroup) -> void:
	for a in armies:
		if a.group == g.id:
			a.group = 0
	groups.erase(g)
	armies_changed.emit()

func set_army_group(a: Army, gid: int) -> void:
	var g := group_by_id(gid)
	if gid != 0 and (g == null or g.owner != a.owner):
		return
	a.group = gid
	armies_changed.emit()

## Tümeni orduya kat (0 = ordudan çıkar)
func set_division_army(d: Division, army_id: int) -> void:
	var a := army_by_id(army_id)
	if army_id != 0 and (a == null or a.owner != d.owner):
		return
	d.army = army_id
	d.manual = false
	armies_changed.emit()

## Yapay zekâ ordusuna en becerikli boştaki komutanı verir (oyuncunun ordularına kendiliğinden atama yapılmaz)
func ai_assign_commander(a: Army) -> void:
	if a.commander != 0 or a.owner == World.player_tag:
		return
	var best: Commander = null
	for cm in free_commanders(a.owner):
		if best == null or cm.skill > best.skill:
			best = cm
	if best:
		a.commander = best.id
		_bonus_cache.clear()

## Ordunun komuta katkısı: general becerisi (ordu çok büyükse bölünür) + ordular grubu mareşali
func army_bonus(a: Army) -> float:
	if _bonus_cache.has(a.id):
		return _bonus_cache[a.id]
	var b := 0.0
	var cm := commander_by_id(a.commander)
	if cm:
		var n := army_divisions(a).size()
		b += GENERAL_BONUS * cm.skill * minf(1.0, float(ARMY_CAP) / maxf(n, 1.0))
	var g := group_by_id(a.group)
	if g:
		var m := commander_by_id(g.commander)
		if m:
			b += MARSHAL_BONUS * m.skill
	_bonus_cache[a.id] = b
	return b

func command_bonus(d: Division) -> float:
	if d.army == 0:
		return 0.0
	var a := army_by_id(d.army)
	return army_bonus(a) if a else 0.0

## Muharebedeki tümenlerin komutanları tecrübe kazanır (mareşal gruptaki ordulardan yarı hızla)
func _commander_xp(in_battle: Dictionary) -> void:
	for a in armies:
		var n := int(in_battle.get(a.id, 0))
		if n <= 0:
			continue
		var gain := 0.012 * minf(n, 8.0)
		var cm := commander_by_id(a.commander)
		if cm and cm.gain(gain):
			_on_skill_up(cm)
		var g := group_by_id(a.group)
		if g:
			var m := commander_by_id(g.commander)
			if m and m.gain(gain * 0.5):
				_on_skill_up(m)

func _on_skill_up(cm: Commander) -> void:
	_bonus_cache.clear()
	if cm.owner == World.player_tag:
		World.notify(tr("NOTE_CMD_SKILL") % [cm.name, cm.skill], "good")

## Ordunun hedef ülke indeksleri (günlük önbellek): seçilen ülke + savaştaysak onun bize düşman müttefikleri
var _target_cache := {}
var _target_day := -1
func _targets(a: Army) -> Dictionary:
	if _target_day != World.day_count:
		_target_cache.clear()
		_target_day = World.day_count
	var key := "%s>%s" % [a.owner, a.enemy]
	if _target_cache.has(key):
		return _target_cache[key]
	var out := {}
	if a.enemy != "" and World.countries.has(a.enemy):
		out[World.countries[a.enemy].index] = true
		# Oyuncu ordusu: düşmanın müttefikleri de hedef (tek cephe emriyle koalisyona karşı savunma).
		# AI ordusu: yalnız o ülke — müttefikler de sayılınca "GER>POL" ordusu Fransa sınırına da yayılıyor,
		# tek ordu doğu+batı toplamına bakıp hep savunmada kalıyordu (1939–41 akışını kilitleyen hata).
		if a.owner == World.player_tag:
			for o: Country in World.countries.values():
				if o.tag != a.enemy and o.tag != a.owner and Diplomacy.are_enemies(o.tag, a.owner) and Diplomacy.are_allies(o.tag, a.enemy):
					out[o.index] = true
	_target_cache[key] = out
	return out

## Bölge hedef ülkenin (ya da bize düşman müttefikinin) kontrolünde mi — tamsayı karşılaştırması
func _is_target_pid(a: Army, pid: int) -> bool:
	return _targets(a).has(World.controller[pid])

## Cephe hedefi: seçilen ülke; savaştaysak onun müttefikleri de (barışta: savaş öncesi sınıra konuşlanma)
func _is_target(a: Army, ctl: String) -> bool:
	if a.enemy == "" or ctl == "" or ctl == a.owner:
		return false
	if ctl == a.enemy:
		return true
	return Diplomacy.are_enemies(ctl, a.owner) and Diplomacy.are_allies(ctl, a.enemy)

## Cephe: ordunun sahibinin (ya da müttefikinin) kontrolündeki, hedef ülkenin kontrolündeki bölgeye komşu kara bölgeleri
## (günlük önbellek; yalnız sahip + müttefiklerin bölgeleri taranır)
var _front_cache := {}
var _front_day := -1
func front_provinces(a: Army) -> Array[int]:
	if _front_day != World.day_count:
		_front_cache.clear()
		_front_day = World.day_count
	var key := "%s>%s" % [a.owner, a.enemy]
	if _front_cache.has(key):
		return _front_cache[key]
	var out: Array[int] = []
	if a.enemy == "" or not World.countries.has(a.enemy) or not World.countries[a.enemy].exists():
		_front_cache[key] = out
		return out
	var own_index: int = World.countries[a.owner].index
	var sides: Array = [own_index]
	# Müttefik toprağı yalnız oyuncu ordusu için cephe sayılır; AI kendi toprağını savunur/kendi sınırından
	# saldırır (aksi hâlde Almanya İtalya'nın Arnavutluk/Libya sınırına tümen yığıyordu). Oyuncuda da yalnız o
	# düşmanla savaşan müttefik ve yalnız anavatana karadan bağlı toprağı: 1940'ta "cephe: Fransa" ordusu savaşta
	# olmayan İtalya'nın Alpler, Libya ve Doğu Afrika sınırlarına dağılıyor, Fransa'ya hiç yığılmıyordu.
	var comp := {}
	var home_comp := -1
	if a.owner == World.player_tag:
		for o: Country in World.countries.values():
			if o.tag != a.owner and o.exists() and Diplomacy.are_allies(o.tag, a.owner) and Diplomacy.are_enemies(o.tag, a.enemy):
				sides.append(o.index)
		if sides.size() > 1:
			comp = AI._components(a.owner)
			home_comp = int(comp.get(World.capital_province(a.owner), -1))
	for ci: int in sides:
		for pid in AI._controlled(ci):
			var p := World.province(pid)
			if p == null or not p.is_land():
				continue
			if ci != own_index and home_comp >= 0 and int(comp.get(pid, -2)) != home_comp:
				continue
			for n in World.land_neighbors(pid):
				if _is_target_pid(a, n):
					out.append(pid)
					break
	_front_cache[key] = out
	return out

## Günlük: ordular cephelerine dağılır (düşman yoğunluğuna göre), taarruzdaysa hattı bozmadan ilerler
## Komuta gücü ve tecrübe (günlük): komuta gücü barışta +0,3, savaşta +0,5 (tavan 200);
## kara tecrübesi aktif kara muharebesi başına, deniz/hava kendi çatışmalarından (tavan 500)
func _experience_tick() -> void:
	var land := {}
	var in_battle := {}
	for pid: int in battles:
		var b: Dictionary = battles[pid]
		for d: Division in b["attackers"] + b["defenders"]:
			land[d.owner] = int(land.get(d.owner, 0)) + 1
			if d.army != 0:
				in_battle[d.army] = int(in_battle.get(d.army, 0)) + 1
	_commander_xp(in_battle)
	var naval := {}
	for pid: int in Navy.battles:
		for side: Array in Navy.battles[pid]["sides"]:
			for f in side:
				naval[f.owner] = int(naval.get(f.owner, 0)) + 1
	var air := {}
	for key: int in Air.fights:
		for t: String in Air.fights[key]["tags"]:
			air[t] = int(air.get(t, 0)) + 1
	for c: Country in World.countries.values():
		if not c.exists():
			continue
		c.command_power = minf(c.command_power + (0.5 if Diplomacy.at_war(c.tag) else 0.3), 200.0)
		c.army_xp = minf(c.army_xp + minf(float(land.get(c.tag, 0)) * 0.08, 2.0), 500.0)
		c.navy_xp = minf(c.navy_xp + minf(float(naval.get(c.tag, 0)) * 0.15, 1.5), 500.0)
		c.air_xp = minf(c.air_xp + minf(float(air.get(c.tag, 0)) * 0.12, 1.5), 500.0)

func _armies_tick() -> void:
	for a in armies.duplicate():
		var divs := army_divisions(a)
		if divs.is_empty():
			if a.owner != World.player_tag:      # oyuncunun boş ordusu kalır (tümen katmayı o seçer)
				armies.erase(a)
				_army_map.clear()
				armies_changed.emit()
			continue
		var front := front_provinces(a)
		if front.is_empty():
			continue
		# doğrudan emirdeki tümenler (oyuncu haritadan yönetiyor) ordu planının dışında kalır
		var planned: Array[Division] = []
		for d in divs:
			if not d.manual:
				planned.append(d)
		_army_spread(a, planned, front)
		if a.mode == Army.Mode.ATTACK and Diplomacy.are_enemies(a.enemy, a.owner):
			_army_attack(a, planned, front)

func _army_spread(a: Army, divs: Array[Division], front: Array[int]) -> void:
	var fset := {}
	var threat := {}
	var tsum := 0.0
	for pid in front:
		fset[pid] = true
		var t := 1.0
		for n in World.land_neighbors(pid):
			if _is_target_pid(a, n):
				t += enemies_in(n, a.owner).size()
		threat[pid] = t
		tsum += t
	var count := {}
	for d in divs:
		var at := d.province if d.path.is_empty() else d.path[d.path.size() - 1]
		if fset.has(at):
			count[at] = int(count.get(at, 0)) + 1
	# taarruzda yığınak (Schwerpunkt): karşısındaki savunması en zayıf 2 cephe bölgesine 3 kat tümen
	if a.mode == Army.Mode.ATTACK and front.size() > 3:
		var weak: Array = []
		for pid in front:
			var foe := INF
			for n in World.land_neighbors(pid):
				if _is_target_pid(a, n):
					var f := 0.0
					for e in enemies_in(n, a.owner):
						f += div_stats(e)["defense"] * e.strength
					foe = minf(foe, f)
			weak.append([foe, pid])
		weak.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
		for i in 2:
			var sp: int = weak[i][1]
			tsum += float(threat[sp]) * 2.0
			threat[sp] = float(threat[sp]) * 3.0
	# her cephe bölgesinde en az 1 tümen (yeterse): boş bölgeye bedava yürüyüş yok (Hollanda Ruhr'u almıştı)
	var floor_want := 1.0 if divs.size() >= front.size() else 0.5
	var want := {}
	for pid in front:
		want[pid] = maxf(float(divs.size()) * float(threat[pid]) / tsum, floor_want)
	var orders := 0
	var fails := 0
	var max_orders := 40 if a.owner == World.player_tag else 12
	var comp := AI._components(a.owner)      # karadan (dost topraktan) ulaşılabilen cepheler
	for d in divs:
		if d.training > 0 or d.in_combat or d.attacking > 0 or d.is_moving():
			continue
		# cephede ve bulunduğu bölge fazla kalabalık değilse yerinde kalır (gereksiz yer değiştirme yok)
		if fset.has(d.province) and float(count.get(d.province, 0)) <= float(want[d.province]) + 1.0:
			continue
		var here := World.province(d.province).center
		var my_comp: int = comp.get(d.province, -1)
		var best := 0
		var bs := INF
		for pid in front:
			if my_comp >= 0 and int(comp.get(pid, -2)) != my_comp:
				continue
			var sc := (float(count.get(pid, 0)) + 1.0) / float(want[pid]) + here.distance_to(World.province(pid).center) / 2500.0
			if sc < bs:
				bs = sc
				best = pid
		if orders >= max_orders or fails >= 2:
			break
		# karadan ulaşılamıyorsa (ada, deniz aşırı): en yakın cepheye deniz yoluyla
		if best == 0:
			var bd := INF
			for pid in front:
				var dd := here.distance_squared_to(World.province(pid).center)
				if dd < bd:
					bd = dd
					best = pid
			if best > 0 and order_move(d, best, false):
				orders += 1
				count[best] = int(count.get(best, 0)) + 1
			else:
				fails += 1
			continue
		if best > 0 and best != d.province and not order_move(d, best, true):
			fails += 1
		elif best > 0 and best != d.province:
			orders += 1
			count[best] = int(count.get(best, 0)) + 1
			if fset.has(d.province):
				count[d.province] = int(count.get(d.province, 1)) - 1

func _army_attack(a: Army, divs: Array[Division], front: Array[int]) -> void:
	var fset := {}
	for pid in front:
		fset[pid] = true
	for d in divs:
		if d.training > 0 or d.is_moving() or d.in_combat or not fset.has(d.province):
			continue
		if d.org < div_stats(d)["org"] * 0.6:
			continue
		var best := 0
		var best_ratio := 0.0
		var mine := divisions_in(d.province).filter(func(x: Division) -> bool: return x.owner == a.owner and x.army == a.id and not x.is_moving())
		var power := 0.0
		for x: Division in mine:
			var st := div_stats(x)
			power += (st["soft"] + st["defense"] * 0.5) * x.strength
		for n in World.land_neighbors(d.province):
			if not _is_target_pid(a, n):
				continue
			var foe := 0.0
			for e in enemies_in(n, a.owner):
				var se := div_stats(e)
				foe += (se["soft"] + se["defense"] * 0.5) * e.strength
			var ratio := power / maxf(foe, 1.0) if foe > 0.0 else 99.0
			if not AI._flank_safe(a.owner, n, d.province, ratio):
				continue
			if ratio > best_ratio:
				best_ratio = ratio
				best = n
		if best > 0 and best_ratio >= 1.0:
			d.path = PackedInt32Array([best])
			d.progress = 0.0

func _remove(d: Division) -> void:
	divisions.erase(d)
	_div_version += 1
	_remove_index(d)
	_dirty = true

func _spawn_start_army(c: Country) -> void:
	var n: int = int(start_divisions.get(c.tag, start_divisions["_default"]))
	n = mini(n, maxi(2, int(c.population / 400_000)))
	var pids := _border_or_capital_provinces(c)
	var armor := 4 if c.tag in ["GER", "SOV", "FRA", "ENG"] else 0
	for i in n:
		var ti := 1 if i < armor else 0
		_create(c, ti, pids[i % pids.size()] if not pids.is_empty() else World.capital_province(c.tag), 1.0, 0)
		c.manpower_used += int(stats(c, ti)["manpower"])

## Komşu ülkelere sınırı olan kendi bölgeleri (yoksa başkent)
func _border_or_capital_provinces(c: Country) -> Array[int]:
	var out: Array[int] = []
	for sid in c.states:
		for pid in World.states[sid].provinces:
			for n in World.land_neighbors(pid):
				var o := World.owner_of_province(n)
				if o and o.tag != c.tag:
					out.append(pid)
					break
	if out.is_empty():
		out.append(World.capital_province(c.tag))
	# başkent de korunsun
	out.push_front(World.capital_province(c.tag))
	return out

# ------------------------------------------------------------------ indeks
func _rebuild_index() -> void:
	_div_version += 1
	by_province.clear()
	at_sea.clear()
	for d in divisions:
		_add_index(d)

func _add_index(d: Division) -> void:
	var p := World.province(d.province)
	if p and p.type == Province.Type.SEA:
		at_sea[d] = true
	if not by_province.has(d.province):
		by_province[d.province] = []
	by_province[d.province].append(d)

func _remove_index(d: Division) -> void:
	at_sea.erase(d)
	var arr: Array = by_province.get(d.province, [])
	arr.erase(d)
	if arr.is_empty():
		by_province.erase(d.province)

var move_version := 0                 ## bir tümen bölge değiştirince artar (görsel katmanlar yalnız o zaman yeniden hesaplar)
func _move_to(d: Division, pid: int) -> void:
	_remove_index(d)
	d.province = pid
	_add_index(d)
	_dirty = true
	move_version += 1
	_explore_move(d, pid)

func divisions_in(pid: int) -> Array:
	return by_province.get(pid, [])

func enemies_in(pid: int, tag: String) -> Array:
	var out := []
	for d: Division in by_province.get(pid, []):
		if Diplomacy.are_enemies(d.owner, tag):
			out.append(d)
	return out

## Ülkenin tümenleri. Sahibe göre önbellek (tümen sahibi değişmez; tümen eklenince/silinince yenilenir): her çağrıda
## bütün tümen listesini taramak 5× hızda yapay zekânın günlük işini şişiriyordu. Çağıran değiştirebilir: kopya döner.
var _owner_cache := {}
var _owner_version := -1
var _div_version := 0
## Emir sayacı (yürü / dur): haritanın saat içinde önbelleğe aldığı yürüyüş ve duruş bilgisi emir gelince yenilenir
## (yalnız görsel; kaydedilmez)
var order_version := 0

func country_divisions(tag: String) -> Array[Division]:
	if _owner_version != _div_version or _owner_cache.size() == 0 and not divisions.is_empty():
		_owner_cache.clear()
		for d in divisions:
			if not _owner_cache.has(d.owner):
				var arr: Array[Division] = []
				_owner_cache[d.owner] = arr
			(_owner_cache[d.owner] as Array[Division]).append(d)
		_owner_version = _div_version
	if not _owner_cache.has(tag):
		var none: Array[Division] = []
		return none
	return (_owner_cache[tag] as Array[Division]).duplicate()

# ------------------------------------------------------------------ yol bulma (A*)
func can_use_sea(tag: String) -> bool:
	var enemies := Diplomacy.enemies_of(tag)
	if enemies.is_empty():
		return true
	var own := 0.0
	for t: String in World.countries:
		if Diplomacy.are_allies(t, tag):
			own += float(naval_power.get(t, 0.0))
	var foe := 0.0
	for t in enemies:
		foe += float(naval_power.get(t, 0.0))
	return own >= foe * 1.1

## Ülke başına geçiş maskesi: kontrol eden ülke indeksi -> 1 (girilebilir). Günlük / savaş değişince yenilenir.
var _masks := {}
var _mask_day := -1

func invalidate_masks() -> void:
	_masks.clear()
	_foe_day = -1                    # savaş değişti: düşman kümeleri yenilensin
	_foe_pair.clear()

func pass_mask(tag: String) -> PackedByteArray:
	if _mask_day != World.day_count:
		_masks.clear()
		_mask_day = World.day_count
	if _masks.has(tag):
		return _masks[tag]
	var m := PackedByteArray()
	m.resize(World.country_by_index.size())
	m[0] = 1
	var c: Country = World.countries[tag]
	for i in range(1, World.country_by_index.size()):
		var o: Country = World.country_by_index[i]
		if o == c or Diplomacy.are_allies(tag, o.tag) or Diplomacy.are_enemies(tag, o.tag) or o.tag in c.access:
			m[i] = 1
	_masks[tag] = m
	return m

## Dost geçiş maskesi: kendi, müttefik, geçiş izni (düşman hariç) — konuşlanma rotaları için
var _fmasks := {}
var _fmask_day := -1

func friendly_mask(tag: String) -> PackedByteArray:
	if _fmask_day != World.day_count:
		_fmasks.clear()
		_fmask_day = World.day_count
	if _fmasks.has(tag):
		return _fmasks[tag]
	var m := PackedByteArray()
	m.resize(World.country_by_index.size())
	var c: Country = World.countries[tag]
	for i in range(1, World.country_by_index.size()):
		var o: Country = World.country_by_index[i]
		if o == c or Diplomacy.are_allies(tag, o.tag) or o.tag in c.access:
			m[i] = 1
	_fmasks[tag] = m
	return m

## Yol bulunamayınca oyuncuya nedeni (çevrilmiş metin): hedef ya da aradaki kara yolu geçiş izni olmayan bir ülkede /
## hedefe yalnız denizden gidilir ve deniz kapalı / genel
func no_path_reason(tag: String, from: int, to: int) -> String:
	var p := World.province(to)
	if p == null or p.type == Province.Type.LAKE or from == to:
		return tr("NOTE_NO_PATH")
	var pm := pass_mask(tag)
	if p.is_land() and pm[World.controller[to]] != 1:
		return _no_access_text(World.controller[to])
	if not _pf_ready:
		_pf_build()
	# geçiş izinlerini saymadan kara yolu (boğazlar dahil): varsa yolu kesen ilk izinsiz ülke
	var came := {from: -1}
	var queue: Array = [from]
	var qi := 0
	while qi < queue.size():
		var cur: int = queue[qi]
		qi += 1
		if cur == to:
			break
		for nbs in [_pf_adj[cur], _pf_str[cur]]:
			for nb in nbs:
				if _pf_kind[nb] == 1 and not came.has(nb):
					came[nb] = cur
					queue.append(nb)
	if came.has(to):
		var block := 0
		var c: int = to
		while c != from:
			if pm[World.controller[c]] != 1:
				block = World.controller[c]
			c = came[c]
		if block != 0:
			return _no_access_text(block)
	return tr("NOTE_NO_PATH_SEA")

func _no_access_text(ci: int) -> String:
	var c: Country = World.country_by_index[ci] if ci > 0 else null
	return tr("NOTE_NO_ACCESS") % (c.display_name() if c else "?")

func _passable(tag: String, pid: int) -> bool:
	var p := World.province(pid)
	if p == null or p.type == Province.Type.LAKE:
		return false
	if not p.is_land():
		return true
	return pass_mask(tag)[World.controller[pid]] == 1

func _neighbors(tag: String, pid: int, sea_ok: bool, safe_to: int = 0) -> Array:
	var p := World.province(pid)
	var out := []
	var fm := friendly_mask(tag) if safe_to > 0 else PackedByteArray()
	for n in p.adjacent:
		var q := World.province(n)
		if q == null or q.type == Province.Type.LAKE:
			continue
		if q.is_land():
			if safe_to > 0 and n != safe_to and fm[World.controller[n]] == 0:
				continue
			if _passable(tag, n):
				out.append(n)
		elif sea_ok and (not p.is_land() or p.coastal) and not Navy.hostile_sea(n, tag):
			out.append(n)
	if p.is_land():
		for n in p.strait_adjacent:
			if safe_to > 0 and n != safe_to and fm[World.controller[n]] == 0:
				continue
			if Navy.strait_blocked(pid, n, tag):
				continue
			if _passable(tag, n):
				out.append(n)
	return out

## safe: yalnız dost topraktan geçen rota (hedef hariç) — AI konuşlanması, ikmal hattı
var path_stats := {}                  ## hata ayıklama (PATHDBG): "tag:sonuç:tür" -> (çağrı, toplam adım)
var path_iterations := 0              ## toplam A* adımı (yapay zekânın çağrı başına arama bütçesi için; deterministik)

## land_only: yalnız kara (aynı kara parçasında olduğu bilinen hedef — yapay zekâ konuşlanması); deniz kapalıyken
## tahmin tam kuş uçuşu uzaklık olur (kara maliyeti ≥ uzaklık: arama hedefe doğru dar kalır, sonuç yine en kısa yol).
## Durağan harita verisi (komşular, mesafeler, arazi katsayısı, birim küre vektörü) bir kez hazırlanır; kuş uçuşu tahmini
## trigonometrisiz kiriş uzunluğudur (kiriş ≤ yay: tahmin yine alt sınır). Adım başına maliyet ~20 µs'den birkaç µs'ye.
var _pf_ready := false
var _pf_kind := PackedByteArray()       ## pid -> 0 yok, 1 kara, 2 deniz, 3 göl
var _pf_coastal := PackedByteArray()
var _pf_move := PackedFloat32Array()    ## kara bölgesinin arazi hareket katsayısı
var _pf_unit := PackedVector3Array()    ## birim küre vektörü
var _pf_adj: Array = []                 ## pid -> PackedInt32Array (göl hariç komşular)
var _pf_adj_d: Array = []               ## pid -> PackedFloat32Array (km)
var _pf_str: Array = []                 ## pid -> PackedInt32Array (boğaz komşuları)
var _pf_str_d: Array = []

func _pf_build() -> void:
	var n := World.provinces.size()
	_pf_kind.resize(n)
	_pf_coastal.resize(n)
	_pf_move.resize(n)
	_pf_unit.resize(n)
	_pf_adj.resize(n)
	_pf_adj_d.resize(n)
	_pf_str.resize(n)
	_pf_str_d.resize(n)
	for pid in n:
		var p := World.province(pid)
		_pf_adj[pid] = PackedInt32Array()
		_pf_adj_d[pid] = PackedFloat32Array()
		_pf_str[pid] = PackedInt32Array()
		_pf_str_d[pid] = PackedFloat32Array()
		if p == null:
			_pf_kind[pid] = 0
			continue
		_pf_kind[pid] = 3 if p.type == Province.Type.LAKE else (1 if p.is_land() else 2)
		_pf_coastal[pid] = 1 if p.coastal else 0
		_pf_move[pid] = float(terrain.get(p.terrain, {"move": 1.0})["move"])
		var lo := deg_to_rad(p.lonlat.x)
		var la := deg_to_rad(p.lonlat.y)
		_pf_unit[pid] = Vector3(cos(la) * cos(lo), cos(la) * sin(lo), sin(la))
	for pid in n:
		var p := World.province(pid)
		if p == null:
			continue
		var adj := PackedInt32Array()
		var adj_d := PackedFloat32Array()
		for q in p.adjacent:
			if q <= 0 or q >= n or _pf_kind[q] == 0 or _pf_kind[q] == 3:
				continue
			adj.append(q)
			adj_d.append(World.distance_km(pid, q))
		_pf_adj[pid] = adj
		_pf_adj_d[pid] = adj_d
		var st := PackedInt32Array()
		var st_d := PackedFloat32Array()
		for q in p.strait_adjacent:
			if q <= 0 or q >= n or _pf_kind[q] != 1:
				continue
			st.append(q)
			st_d.append(World.distance_km(pid, q))
		_pf_str[pid] = st
		_pf_str_d[pid] = st_d
	_pf_ready = true

func find_path(tag: String, from: int, to: int, safe := false, land_only := false) -> PackedInt32Array:
	if from == to or World.province(to) == null or not _passable(tag, to):
		return PackedInt32Array()
	if not _pf_ready:
		_pf_build()
	# oyuncu her zaman çıkarma deneyebilir (düşman hâkimiyetindeki denizlerden geçemez);
	# AI yalnız toplam deniz üstünlüğünde denizi kullanır (yoksa ordular gereksiz yere denize açılır)
	var sea_ok := (can_use_sea(tag) or tag == World.player_tag) and not land_only
	var hw := (0.95 if not sea_ok else 1.0 / 3.0) * 6371.0     # deniz maliyeti uzaklık/3: denizde tahmin de /3
	var gu: Vector3 = _pf_unit[to]
	var ctl := World.controller
	var pm := pass_mask(tag)
	var fm := friendly_mask(tag) if safe else PackedByteArray()
	var hostile := {}                   # deniz bölgesi -> düşman hâkimiyetinde mi (bu aramada)
	var open_heap: Array = [[0.0, from]]
	var came := {from: -1}
	var g := {from: 0.0}
	var closed := {}
	var iterations := 0
	# yapay zekâ için üst sınır: başarılı yolların çoğu ~1500 adımda bulunur; oyuncunun emri tam aranır
	var limit := 60000 if tag == World.player_tag else 12000
	while not open_heap.is_empty() and iterations < limit:
		iterations += 1
		var cur: int = _heap_pop(open_heap)[1]
		if cur == to:
			break
		if closed.has(cur):
			continue
		closed[cur] = true
		var cur_land := _pf_kind[cur] == 1
		var gc: float = g[cur]
		var adj: PackedInt32Array = _pf_adj[cur]
		var adj_d: PackedFloat32Array = _pf_adj_d[cur]
		for k in adj.size():
			var nb := adj[k]
			var cost := 0.0
			if _pf_kind[nb] == 1:
				var ci := ctl[nb]
				if safe and nb != to and fm[ci] == 0:
					continue
				if pm[ci] != 1:
					continue
				cost = adj_d[k] / _pf_move[nb] + (0.0 if cur_land else EMBARK_COST)
			else:
				if not sea_ok or (cur_land and _pf_coastal[cur] == 0):
					continue
				var hs: Variant = hostile.get(nb)
				if hs == null:
					hs = Navy.hostile_sea(nb, tag)
					hostile[nb] = hs
				if hs:
					continue
				cost = adj_d[k] / 3.0 + (EMBARK_COST if cur_land else 0.0)
			var ng := gc + cost
			if not g.has(nb) or ng < float(g[nb]):
				g[nb] = ng
				came[nb] = cur
				_heap_push(open_heap, [ng + (_pf_unit[nb] - gu).length() * hw, nb])
		if cur_land:
			var st: PackedInt32Array = _pf_str[cur]
			var st_d: PackedFloat32Array = _pf_str_d[cur]
			for k in st.size():
				var nb := st[k]
				var ci := ctl[nb]
				if safe and nb != to and fm[ci] == 0:
					continue
				if Navy.strait_blocked(cur, nb, tag) or pm[ci] != 1:
					continue
				var ng := gc + st_d[k] / _pf_move[nb]
				if not g.has(nb) or ng < float(g[nb]):
					g[nb] = ng
					came[nb] = cur
					_heap_push(open_heap, [ng + (_pf_unit[nb] - gu).length() * hw, nb])
	path_iterations += iterations
	if OS.has_environment("PATHDBG"):
		var kdbg := "%s:%s:%s" % [tag, "ok" if came.has(to) else "FAIL", "safe" if safe else "free"]
		path_stats[kdbg] = path_stats.get(kdbg, Vector2i.ZERO) + Vector2i(1, iterations)
	if not came.has(to):
		return PackedInt32Array()
	var path := PackedInt32Array()
	var c: int = to
	while c != from:
		path.insert(0, c)
		c = came[c]
	return path

func _heap_push(h: Array, item: Array) -> void:
	h.append(item)
	var i := h.size() - 1
	while i > 0:
		var parent := (i - 1) >> 1
		if h[parent][0] <= h[i][0]:
			break
		var tmp: Array = h[parent]
		h[parent] = h[i]
		h[i] = tmp
		i = parent

func _heap_pop(h: Array) -> Array:
	var top: Array = h[0]
	var last: Array = h.pop_back()
	if not h.is_empty():
		h[0] = last
		var i := 0
		while true:
			var l := i * 2 + 1
			var r := l + 1
			var m := i
			if l < h.size() and h[l][0] < h[m][0]: m = l
			if r < h.size() and h[r][0] < h[m][0]: m = r
			if m == i:
				break
			var tmp: Array = h[m]
			h[m] = h[i]
			h[i] = tmp
			i = m
	return top

## Hareket emri; yol bulunamazsa false
func order_move(d: Division, to: int, safe := false, land_only := false) -> bool:
	if d.training > 0:
		return false
	order_version += 1
	var path := find_path(d.owner, d.province, to, safe, land_only)
	# yoldaki tümen yön değiştirince geri ışınlanmaz: yürümekte olduğu bacağı bitirir, yeni yola oradan döner (ilerleme
	# korunur). Eskiden yeni yol 2 adımdan uzunsa ilerleme sıfırlanıp tümen çıktığı bölgeye sıçrıyordu (yapay zekâ emri
	# değiştikçe sayaç yürürken geri atlıyordu). Yalnız gittiği bölge artık düşman doluysa ya da oradan yol yoksa baştan.
	var old_next := d.path[0] if not d.path.is_empty() and d.attacking == 0 else -1
	if old_next > 0 and d.progress > 0.0 and enemies_in(old_next, d.owner).is_empty():
		if not path.is_empty() and path[0] == old_next:
			d.path = path
			return true
		var via := PackedInt32Array() if old_next == to else find_path(d.owner, old_next, to, safe, land_only)
		if old_next == to or not via.is_empty():
			var full := PackedInt32Array([old_next])
			full.append_array(via)
			d.path = full
			return true
	if path.is_empty():
		return false
	d.path = path
	d.progress = 0.0
	d.attacking = 0
	return true

## Düşman bölgesine emir (oyuncu: Ctrl/sağ tık): tümen, hedefe sınırı olan en yakın dost bölgeye (kendi ya da müttefik)
## dost topraktan yürür ve oradan hedefe saldırır; zaten sınırdaysa doğrudan saldırır. Başka düşman bölgesinin
## içinden geçip önce ona saldırmaz. Dost sınır bölgesine yol yoksa olağan yol.
func order_attack(d: Division, target: int) -> bool:
	if d.training > 0:
		return false
	if target in World.land_neighbors(d.province):
		order_version += 1
		d.path = PackedInt32Array([target])
		d.progress = 0.0
		d.attacking = 0
		return true
	var here := World.province(d.province).center
	var cands: Array = []
	for n in World.land_neighbors(target):
		var ctl := World.controller_tag(n)
		if (ctl == d.owner or Diplomacy.are_allies(ctl, d.owner)) and _passable(d.owner, n) and enemies_in(n, d.owner).is_empty():
			cands.append(n)
	cands.sort_custom(func(a: int, b: int) -> bool:
		return here.distance_squared_to(World.province(a).center) < here.distance_squared_to(World.province(b).center))
	for n: int in cands.slice(0, 3):
		if n == d.province or order_move(d, n, true, true):
			if n == d.province:
				order_version += 1
				d.path = PackedInt32Array()
				d.progress = 0.0
				d.attacking = 0
			d.path.append(target)
			return true
	return order_move(d, target)

## Aynı bölgedeki öncünün yolunu izle (yapay zekâ konuşlanması: bir kez aranan yol aynı yığının öbür tümenlerine;
## birlikte yürürler). Yalnız duran tümen; öncü yola yeni çıkmış olmalı (ilerlemesi yok).
func order_follow(d: Division, leader: Division) -> bool:
	if d.training > 0 or d.province != leader.province or leader.path.is_empty() or leader.progress > 0.0:
		return false
	order_version += 1
	d.path = leader.path.duplicate()
	d.progress = 0.0
	d.attacking = 0
	return true

## Tümenin bölgeye tahmini varış süresi (saat; yol yoksa -1): yol boyunca her adımın uzaklığı / o adımdaki hız
## (arazi, altyapı, mevsim, yakıt, ikmal, organizasyon — hareketle aynı _speed). Muharebe süresi sayılmaz.
func eta_hours(d: Division, to: int) -> float:
	return float(eta(d, to)["hours"])

## Tahmini varış ve yol: {"hours": saat (yol yoksa -1), "path": PackedInt32Array}
func eta(d: Division, to: int) -> Dictionary:
	if d.training > 0:
		return {"hours": -1.0, "path": PackedInt32Array()}
	if to == d.province:
		return {"hours": 0.0, "path": PackedInt32Array()}
	var path := find_path(d.owner, d.province, to)
	if path.is_empty():
		return {"hours": -1.0, "path": path}
	var h := 0.0
	var at := d.province
	for i in path.size():
		var nxt: int = path[i]
		var km := World.distance_km(at, nxt)
		if i == 0 and not d.path.is_empty() and d.path[0] == nxt:
			km = maxf(km - d.progress, 0.0)          # yoldaki tümen ilerlemesini korur
		h += km / maxf(_speed(d, nxt), 0.01)
		at = nxt
	return {"hours": h, "path": path}

func stop(d: Division) -> void:
	order_version += 1
	d.path = PackedInt32Array()
	d.attacking = 0
	d.progress = 0.0

## Geri çekil (oyuncu emri): tümen cephenin gerisindeki en yakın güvenli dost bölgeye yürür. Saldırıyorsa saldırıyı
## keser (bedelsiz). Kendi bölgesinde saldırı altındaysa hemen kopar ve bir adım geri geçer, ama kopmanın bedeli olarak
## bütünlüğünün WITHDRAW_ORG_COST'u gider. Bu bedel, bütünlüğü tükenip kendiliğinden çekilen tümenin durumundan iyidir:
## erken çekilen tümen bir sonraki muharebeye hazır kalır. Güvenli bölge yoksa (kuşatılmış) emir verilmez: false.
const WITHDRAW_ORG_COST := 0.25
func withdraw(d: Division) -> bool:
	if d.training > 0 or not World.province(d.province).is_land():
		return false
	var dest := _rear_province(d)
	if dest == 0:
		return false
	var path := find_path(d.owner, d.province, dest, true, true)
	if path.is_empty():
		return false
	var under_fire := battles.has(d.province) and d in (battles[d.province]["defenders"] as Array)
	stop(d)
	if under_fire:
		d.org = maxf(d.org * (1.0 - WITHDRAW_ORG_COST), 0.0)
		_move_to(d, path[0])
		path.remove_at(0)
	d.path = path
	return true

## Çekilme hedefi: dost toprakta, içinde ve komşularında düşman askeri olmayan en yakın bölge (en çok 8 adım); yoksa
## içinde düşman olmayan en yakın dost bölge (_safe_province); o da yoksa 0
func _rear_province(d: Division) -> int:
	var seen := {d.province: true}
	var frontier: Array[int] = [d.province]
	for depth in 8:
		var next: Array[int] = []
		for cur in frontier:
			for n in World.land_neighbors(cur):
				if seen.has(n):
					continue
				seen[n] = true
				var ctl := World.controller_tag(n)
				if ctl != d.owner and not Diplomacy.are_allies(ctl, d.owner):
					continue
				if not _passable(d.owner, n) or not enemies_in(n, d.owner).is_empty():
					continue
				var quiet := true
				for m in World.land_neighbors(n):
					if not enemies_in(m, d.owner).is_empty():
						quiet = false
						break
				if quiet:
					return n
				next.append(n)
		frontier = next
		if frontier.is_empty():
			break
	return _safe_province(d)

# ------------------------------------------------------------------ saatlik simülasyon
## Gerçekçi yürüyüş: taburların hızı yol üstündeki yürüyüş hızıdır (piyade 4 km/s), ama tümen günde 24 saat yürümez —
## mola, gece, ikmal kolu, yol tıkanıklığı. Günlük ortalama bu katla: piyade ~33 km/gün, zırhlı ~84, motorlu ~100
## (1939-45'te piyade 25-30 km/gün yürür; zırhlı yarma 40-80 km/gün, iyi yolda 100'e çıkar). Eskiden 24 saat tam hızla
## gidiyorlardı: piyade 96, zırhlı 240 km/gün — cephe değiştirmek bedavaydı.
const MARCH_FACTOR := 1.0            ## şablon hızının yürüyüşteki katı (piyade ~4 km/sa ≈ günde ~95 km: takviye savaşa yetişir)
const TERRAIN_MOVE_WEIGHT := 0.35    ## arazi ve mevsimin yürüyüş süresine etkisi bu kadar (yol süresi fazla belirleyici olmasın)
## Yürüyüş yorgunluğu: yürüyen tümenin bütünlüğü saatte en çok %0,6 düşer (en fazla %60'a kadar); durunca toparlanır
## (_recover). Uzun yoldan gelip hemen saldıran tümen zayıftır; cepheden cepheye kaydırmanın bedeli olur.
const MARCH_FATIGUE := 0.006
const MARCH_ORG_FLOOR := 0.6

## Tümenin yürüme menzili: bölge -> kaç saatte varır (en çok max_hours). Geçilebilen (kendi, müttefik, geçiş izni)
## toprakta ilerler; düşman bölgesine girilir ama ötesine geçilmez (orada muharebe var), izinsiz tarafsıza girilmez.
## Hız eta ile aynı (_speed: arazi, altyapı, mevsim, yakıt, ikmal, gerçekçi yürüyüş). Ctrl basılıyken haritada gösterilir.
func reach_hours(d: Division, max_hours: float) -> Dictionary:
	var best := {d.province: 0.0}
	var open: Array = [[0.0, d.province]]
	var mask := pass_mask(d.owner)
	while not open.is_empty():
		var bi := 0
		for i in open.size():
			if float(open[i][0]) < float(open[bi][0]):
				bi = i
		var cur: Array = open[bi]
		open.remove_at(bi)
		var h: float = cur[0]
		var pid: int = cur[1]
		if h > float(best.get(pid, INF)):
			continue
		if pid != d.province and Diplomacy.are_enemies(World.controller_tag(pid), d.owner):
			continue                                   # düşman bölgesi: buraya kadar (orada muharebe var)
		for n in World.land_neighbors(pid):
			var np := World.province(n)
			if np == null or np.type == Province.Type.LAKE:
				continue
			if mask[World.controller[n]] != 1:
				continue                               # izinsiz tarafsız (maske kendi, müttefik, düşman ve izinlileri geçer)
			var sp := _speed(d, n)
			if sp <= 0.001:
				continue
			var nh := h + World.distance_km(pid, n) / sp
			if nh <= max_hours and nh < float(best.get(n, INF)):
				best[n] = nh
				open.append([nh, n])
	return best

func _speed(d: Division, next_pid: int) -> float:
	var np := World.province(next_pid)
	var s: float = div_stats(d)["speed"] * MARCH_FACTOR
	if np and not np.is_land():
		return SEA_SPEED
	var t: Dictionary = terrain.get(np.terrain if np else "plains", {"move": 1.0})
	var st := World.state_of_province(next_pid)
	var infra := 1.0 + (st.building_level("infrastructure") * 0.05 if st else 0.0)
	var season := 1.0 - mud_level(next_pid) * 0.45 - winter_level(next_pid) * 0.25
	var ground := lerpf(1.0, float(t["move"]) * infra * season, TERRAIN_MOVE_WEIGHT)
	var fuel := 0.5 if fuel_malus(d) > 0.0 else 1.0
	return s * ground * fuel * (1.0 if d.supplied else 0.7) * (0.5 if d.org < div_stats(d)["org"] * 0.3 else 1.0)

func _on_hour() -> void:
	var t0 := Time.get_ticks_usec()
	if GameClock.hour % 2 == 0:
		_fog_dirty = true                    # gece görmediği komşuları birlik gün doğunca keşfeder (sessiz: sorulunca)
	_move_all()
	GameClock.timed("move", t0); t0 = Time.get_ticks_usec()
	_combat()
	GameClock.timed("combat", t0); t0 = Time.get_ticks_usec()
	_skirmish_hours += 1                 # yan yana ateş bir sonraki karede (_process): saatin karesine binmesin
	_recover()
	GameClock.timed("recover", t0); t0 = Time.get_ticks_usec()
	_hour_divs()
	GameClock.timed("mil_divloop", t0)
	if _dirty:
		_dirty = false
		divisions_changed.emit()

func _move_all() -> void:
	for d in divisions.duplicate():
		if d.path.is_empty() or d.training > 0:
			d.idle_hours += 1
			continue
		d.idle_hours = 0
		var next: int = d.path[0]
		var dist := World.distance_km(d.province, next)
		if d.attacking == 0:
			d.progress += _speed(d, next)
			if World.province(next).is_land():
				var full: float = div_stats(d)["org"]
				if d.org > full * MARCH_ORG_FLOOR:
					d.org = maxf(d.org - full * MARCH_FATIGUE, full * MARCH_ORG_FLOOR)
		if d.progress < dist:
			continue
		d.progress = dist
		var np := World.province(next)
		if np.is_land() and not enemies_in(next, d.owner).is_empty():
			d.attacking = next           # düşman var: saldırı (muharebe _combat'ta)
			continue
		if np.is_land() and not _passable(d.owner, next):
			stop(d)
			continue
		d.attacking = 0
		_enter(d, next)

func _enter(d: Division, pid: int) -> void:
	_move_to(d, pid)
	d.path.remove_at(0)
	d.progress = 0.0
	var p := World.province(pid)
	if p.is_land():
		var st := World.state_of_province(pid)
		var ctl := World.controller_tag(pid)
		if ctl != d.owner and st:
			if Diplomacy.are_enemies(ctl, d.owner) or ctl == "":
				# kurtarılan bölge sahibine, düşman bölgesi işgalciye
				var new_ctl := st.owner if Diplomacy.are_allies(st.owner, d.owner) else d.owner
				World.set_controller(pid, new_ctl)

func _combat() -> void:
	var targets := {}
	for d in divisions:
		if d.attacking > 0:
			if not targets.has(d.attacking):
				targets[d.attacking] = []
			targets[d.attacking].append(d)
		d.in_combat = false
	var had := not battles.is_empty()
	battles.clear()
	supporting.clear()
	_foe_pair.clear()
	# muharebedeki bütün tümenler (saldıran ve savunan): bunlar başka muharebeye topçu desteği veremez
	_engaged.clear()
	for pid: int in targets:
		for a: Division in targets[pid]:
			_engaged[a] = true
		for e: Division in enemies_in(pid, (targets[pid][0] as Division).owner):
			_engaged[e] = true
	for pid: int in targets:
		var attackers: Array = targets[pid]
		var defenders := enemies_in(pid, attackers[0].owner)
		if defenders.is_empty():
			for a: Division in attackers:
				a.attacking = 0
			continue
		_resolve_battle(pid, attackers, defenders)
	if had or not battles.is_empty():
		battles_changed.emit()

func _frontline(divs: Array, width: float) -> Array:
	var sorted := divs.duplicate()
	sorted.sort_custom(func(a: Division, b: Division) -> bool: return a.org > b.org)
	var out := []
	var used := 0.0
	for d: Division in sorted:
		var w: float = div_stats(d)["width"]
		if used + w > width * 1.34 and not out.is_empty():
			break
		out.append(d)
		used += w
	return out

## "Garip savaş": demokrasiler savaşın ilk ~9 ayında isteksiz saldırır (savunma etkilenmez)
const PHONEY_DAYS := 270
func _phoney_war_malus(tag: String) -> float:
	var c: Country = World.countries.get(tag)
	if c == null or c.ideology != "democratic":
		return 0.0
	var longest := -1
	for w: Dictionary in Diplomacy.wars:
		if tag in w["attackers"] or tag in w["defenders"]:
			longest = maxi(longest, World.day_count - int(w.get("start", 0)))
	return 0.25 if longest >= 0 and longest < PHONEY_DAYS else 0.0

# ------------------------------------------------------------------ mevsim ve yakıt
## Kış: Aralık–Şubat, kuzey yarıkürede 45° üstü (güneyde Haziran–Ağustos, 45° altı); 55° üstünde sert kış
func winter_level(pid: int) -> float:
	var p := World.province(pid)
	if p == null:
		return 0.0
	var lat: float = p.lonlat.y
	var m := GameClock.month
	var north_winter := m == 12 or m <= 2
	var south_winter := m >= 6 and m <= 8
	if lat > 45.0 and north_winter:
		return 1.0 if lat > 55.0 else 0.6
	if lat < -45.0 and south_winter:
		return 0.6
	return 0.0

## Çamur: sonbahar (Eki–Kas) ve bahar (Mart) yağmurları, Doğu Avrupa ve Rusya (45–62°K, 15–60°D)
func mud_level(pid: int) -> float:
	var p := World.province(pid)
	if p == null or not p.is_land():
		return 0.0
	var ll: Vector2 = p.lonlat
	var m := GameClock.month
	if (m == 10 or m == 11 or m == 3) and ll.y > 45.0 and ll.y < 62.0 and ll.x > 15.0 and ll.x < 60.0:
		return 1.0
	return 0.0

## Gece saldırı cezası (0..): bölgede gecenin payıyla (alacakaranlıkta yarısı); savunan cezasız
func night_attack_malus(pid: int) -> float:
	var p := World.province(pid)
	return -night_attack * GameClock.night_at(p.center) if p else 0.0

func season_attack_malus(pid: int) -> float:
	return winter_level(pid) * 0.15 + mud_level(pid) * 0.08

## Sade oyun (docs/DESIGN.md): yakıt ve ekipman stoğu savaşı etkilemez (oyuncu yönetmiyor): yakıt cezası yok, kayıplar
## yalnız insan gücüyle yerine konur. İkmal açık kalır: kendiliğinden işler (yönetilecek bir şey yok), kuşatılan ya da
## denizden çıkıp kopan birlik zayıflar. Denge testi (1 Ekim 2026, 3'er koşu): ikmal kapalıyken İngiltere 1/3, Almanya
## 1942'ye 0/3 ayakta (ikmalsiz çıkarma ve derin taarruz cezasız), ikmal açıkken 12 kontrolün hepsi 3/3; yakıt sonucu
## değiştirmedi.
## (geliştirici: if_supply=0 kapatır, if_fuel=1 / if_equipment=1 açar: denge karşılaştırması için)
static var SUPPLY: bool = OS.get_environment("if_supply") != "0"
static var FUEL: bool = OS.get_environment("if_fuel") == "1"
static var EQUIPMENT: bool = OS.get_environment("if_equipment") == "1"

## Motorlu / zırhlı birlik yakıtsızsa güç kaybeder ("petrol yoksa eğlence de yok")
func fuel_malus(d: Division) -> float:
	if not FUEL:
		return 0.0
	var c: Country = World.countries.get(d.owner)
	if c == null or c.fuel > 0.0 or c.fuel < -0.5:
		return 0.0
	return 0.35 if float(div_stats(d).get("fuel_use", 0.0)) > 0.0 else 0.0

const UNSUPPLIED_MALUS := 0.35         ## ikmalsiz tümenin muharebe cezası
const EXHAUSTED_MALUS := 0.5           ## organizasyonu bitmiş savunanın cezası
const MIN_COMBAT_MOD := 0.15

## Saldıranın muharebe çarpanı: arazi, hava desteği, çıkarma/nehir, ikmal, garip savaş, planlama, mevsim, yakıt
func attack_mod(d: Division, pid: int, from_pid: int = 0) -> float:
	var p := World.province(pid)
	var tinfo: Dictionary = terrain.get(p.terrain, terrain["plains"])
	var m := 1.0 + float(tinfo["attack"]) + Air.bonus(pid, d.owner)
	var from := World.province(from_pid if from_pid > 0 else d.province)
	if from and not from.is_land():
		m += amphibious_attack
	elif from and pid in from.river_adjacent:
		m += river_attack
	if not d.supplied:
		m -= UNSUPPLIED_MALUS
	m -= _phoney_war_malus(d.owner)
	m += d.planning * 0.2 - season_attack_malus(pid) - night_attack_malus(pid) - fuel_malus(d) + command_bonus(d) + motivation(d)
	return maxf(m, MIN_COMBAT_MOD)

## Savunanın karşı saldırı çarpanı: hava desteği, ikmal, yakıt; organizasyonu bitmiş (bitkin) tümen yarı güçle direnir
func defend_mod(d: Division, pid: int) -> float:
	var m := 1.0 + Air.bonus(pid, d.owner) - (0.0 if d.supplied else UNSUPPLIED_MALUS) - fuel_malus(d) + command_bonus(d) + motivation(d)
	if d.org < div_stats(d)["org"] * RETREAT_ORG:
		m -= EXHAUSTED_MALUS
	return maxf(m, MIN_COMBAT_MOD)

## Siper: bekleyen tümenin savunması 10 günde (240 saat) +%15 (+ siper modifier'ları) artar
func entrenchment(d: Division) -> float:
	return 1.0 + minf(d.idle_hours / 240.0, 1.0) * (0.15 + World.countries[d.owner].mod("entrenchment"))

## Saldırı tahmini (oyuncu emir vermeden önce, harita kartında): seçili tümenler bu bölgeye şimdi saldırsa muharebe
## formülüyle, rastlantısız, iki taraf saatte ne kadar bütünlük kaybeder ve hangisi önce çözülür. Topçu desteği
## komşuda yerinde duran tümenlerden gelir (seçili olanlar saldıracağı için destek vermez).
## Dönen: {} (saldıracak tümen yok) · {"empty": true} (bölgede düşman askeri yok) · {"ratio": saldıranın dayanma
## süresi / savunanın çözülme süresi (1'den büyük: saldıran kazanır), "hours": önce çözülen tarafın süresi,
## "att": saldıran tümen, "def": savunan tümen, "factors": [[anahtar, etki (bizim için, + iyi)], ...]}
## Tahmin etkenlerinin anahtarları (kartta tr("ODDS_F_" + anahtar))
const ESTIMATE_FACTORS: Array[String] = ["terrain", "river", "amphibious", "entrench", "air", "enemy_air", "supply",
	"season", "night", "planning", "phoney", "fuel", "command", "support", "enemy_support", "motivated", "enemy_motivated"]

func attack_estimate(attackers: Array, pid: int) -> Dictionary:
	var mine: Array = attackers.filter(func(d: Division) -> bool: return d.training == 0)
	if mine.is_empty():
		return {}
	var tag: String = (mine[0] as Division).owner
	var defenders := enemies_in(pid, tag)
	if defenders.is_empty():
		return {"empty": true}
	var foe: String = (defenders[0] as Division).owner
	var p := World.province(pid)
	var tinfo: Dictionary = terrain.get(p.terrain, terrain["plains"])
	var width: float = float(tinfo["width"])
	var att := _frontline(mine, width)
	var dfn := _frontline(defenders, width)
	var att_hard := 0.0
	var def_hard := 0.0
	for d: Division in att: att_hard += div_stats(d)["hardness"]
	for d: Division in dfn: def_hard += div_stats(d)["hardness"]
	att_hard /= maxf(att.size(), 1)
	def_hard /= maxf(dfn.size(), 1)
	var river := 0
	var sea := 0
	var unsup := 0
	var plan := 0.0
	var fuel := 0.0
	var att_attack := 0.0
	for d: Division in att:
		var from := _attack_from(d, pid)
		var fp := World.province(from)
		if fp and not fp.is_land():
			sea += 1
		elif fp and pid in fp.river_adjacent:
			river += 1
		unsup += int(not d.supplied)
		plan += d.planning * 0.2
		fuel += fuel_malus(d)
		var s := div_stats(d)
		att_attack += (s["soft"] * (1.0 - def_hard) + s["hard"] * def_hard) * d.strength * attack_mod(d, pid, from) * d.xp_mult()
	var def_attack := 0.0
	var dug := 0.0
	for d: Division in dfn:
		var s := div_stats(d)
		def_attack += (s["soft"] * (1.0 - att_hard) + s["hard"] * att_hard) * d.strength * defend_mod(d, pid) * d.xp_mult()
		dug += entrenchment(d) - 1.0
	var engaged := {}
	for d: Division in mine: engaged[d] = true
	for d: Division in defenders: engaged[d] = true
	_foe_pair.clear()
	var sa := float(_support_fire(pid, foe, def_hard, engaged, false)["fire"])
	var sd := float(_support_fire(pid, tag, att_hard, engaged, false)["fire"])
	var base_att := att_attack
	var base_def := def_attack
	att_attack += sa
	def_attack += sd
	# saatlik bütünlük kaybı → dayanma süresi (bütünlük geri çekilme eşiğine inene kadar)
	var def_loss := _expected_org_loss(dfn, att_attack, "defense")
	var att_loss := _expected_org_loss(att, def_attack, "breakthrough")
	var def_pool := 0.0
	for d: Division in defenders:
		def_pool += maxf(d.org - div_stats(d)["org"] * RETREAT_ORG, 0.0)
	var att_pool := 0.0
	for d: Division in mine:
		att_pool += maxf(d.org - div_stats(d)["org"] * RETREAT_ORG, 0.0)
	var t_def := def_pool / maxf(def_loss, 0.001)
	var t_att := att_pool / maxf(att_loss, 0.001)
	var n := float(att.size())
	var factors: Array = []
	factors.append(["terrain", float(tinfo["attack"])])
	if river > 0: factors.append(["river", river_attack * river / n])
	if sea > 0: factors.append(["amphibious", amphibious_attack * sea / n])
	factors.append(["entrench", -dug / maxf(dfn.size(), 1)])
	# hava: bizim saldırı katkımız ile düşmanın ateş katkısının farkı; artıysa üstünlük bizde
	var air := Air.bonus(pid, tag) - Air.bonus(pid, foe)
	factors.append(["air" if air >= 0.0 else "enemy_air", air])
	if unsup > 0: factors.append(["supply", -UNSUPPLIED_MALUS * unsup / n])
	factors.append(["season", -season_attack_malus(pid)])
	factors.append(["night", -night_attack_malus(pid)])
	factors.append(["planning", plan / n])
	factors.append(["phoney", -_phoney_war_malus(tag)])
	factors.append(["fuel", -fuel / n])
	var cmd := 0.0
	for d: Division in att: cmd += command_bonus(d)
	factors.append(["command", cmd / n])
	var mot := 0.0
	for d: Division in att: mot += motivation(d)
	factors.append(["motivated", mot / n])
	var emot := 0.0
	for d: Division in dfn: emot += motivation(d)
	factors.append(["enemy_motivated", -emot / maxf(dfn.size(), 1)])
	factors.append(["support", sa / maxf(base_att, 1.0)])
	factors.append(["enemy_support", -sd / maxf(base_def, 1.0)])
	factors = factors.filter(func(f: Array) -> bool: return absf(float(f[1])) >= 0.01)
	factors.sort_custom(func(x: Array, y: Array) -> bool: return absf(float(x[1])) > absf(float(y[1])))
	return {"ratio": t_att / maxf(t_def, 0.001), "hours": minf(t_att, t_def), "att": mine.size(),
		"def": defenders.size(), "factors": factors, "terrain_id": p.terrain}

## Tümenin bu bölgeye saldırısının geleceği bölge: komşuysa kendi bölgesi, değilse order_attack'ın seçeceği en yakın dost
## sınır bölgesi (yoksa kendi bölgesi)
func _attack_from(d: Division, target: int) -> int:
	if target in World.land_neighbors(d.province):
		return d.province
	if not d.path.is_empty() and d.path[d.path.size() - 1] == target and d.path.size() >= 2:
		return d.path[d.path.size() - 2]
	var here := World.province(d.province).center
	var best := d.province
	var bd := INF
	for n in World.land_neighbors(target):
		var ctl := World.controller_tag(n)
		if (ctl == d.owner or Diplomacy.are_allies(ctl, d.owner)) and enemies_in(n, d.owner).is_empty():
			var dd := here.distance_squared_to(World.province(n).center)
			if dd < bd:
				bd = dd
				best = n
	return best

## _apply_hits'in rastlantısız, değiştirmeyen karşılığı: hedeflerin saatte toplam bütünlük kaybı
func _expected_org_loss(targets: Array, attack: float, def_key: String) -> float:
	if targets.is_empty():
		return 0.0
	var per := attack / targets.size()
	var loss := 0.0
	for d: Division in targets:
		var s := div_stats(d)
		var defense: float = s[def_key] * d.strength
		if def_key == "defense":
			defense *= entrenchment(d)
		loss += (HIT_DEF * minf(per, defense) + HIT_OPEN * maxf(per - defense, 0.0)) * ORG_DMG
	return loss

## Yan yana savaş: savaştaki iki ülkenin komşu bölgelerde duran (yürümeyen, taarruzda olmayan) tümenleri her saat
## birbirine ateş eder — taarruzsuz karşılıklı ateş, muharebenin SKIRMISH_MULT katı. İki taraf da yıpranır (toparlanamaz);
## bütünlüğü düşen geri çekilir, boşalan bölgeye karşı taraf girer. Demokrasiler savaşın ilk aylarında ("garip savaş")
## ateş açmaz.
const SKIRMISH_MULT := 0.3
var _border_cache := {}               ## Vector2i(bölge, ülke indeksi) -> komşularından biri başkasının mı (sınır)
var _border_ver := -1                 ## önbelleğin geçerli olduğu World.control_version
var _skirmish_hours := 0             ## işlenmeyi bekleyen oyun saatleri (ateş zararı bu kadar katlanır)

func _process(_delta: float) -> void:
	# saat işi yapılan kareye binmez (GameClock ağaçta önce işlenir); saatler hiç boşluk bırakmazsa iki saat birikince işlenir
	if _skirmish_hours > 0 and (GameClock.tick_frame != Engine.get_process_frames() or _skirmish_hours >= 2):
		var t0 := Time.get_ticks_usec()
		var h := _skirmish_hours
		_skirmish_hours = 0
		_skirmish(float(h))
		GameClock.timed("skirmish", t0)

## Hızlı simülasyon (testler, advance_hours): bekleyen yan yana ateşi hemen işle
func flush_skirmish() -> void:
	if _skirmish_hours > 0:
		var h := _skirmish_hours
		_skirmish_hours = 0
		_skirmish(float(h))

func _skirmish(hours := 1.0) -> void:
	skirmishes.clear()
	var busy := {}
	for pid: int in battles:
		for d: Division in battles[pid]["attackers"]:
			busy[d] = true
		for d: Division in battles[pid]["defenders"]:
			busy[d] = true
	for d: Division in supporting:
		busy[d] = true
	var seen := {}
	var breaking := {}
	var foe := {}                          # "a:b" -> düşman mı (bu saatlik önbellek; savaş listesini her komşuda taramasın)
	var enemy_of := func(a: String, b: String) -> bool:
		if a == b:
			return false
		var k := a + ":" + b
		if not foe.has(k):
			foe[k] = Diplomacy.are_enemies(a, b)
		return foe[k]
	# yalnız cephe: komşusunda düşman tümeni olan kara bölgeleri (bütün dolu bölgeleri süzmek saatte ~3 ms tutuyordu)
	var __sk := Time.get_ticks_usec()
	if World.control_version != _border_ver:
		_border_cache.clear()
		_border_ver = World.control_version
	var holding := {}                      # bölge -> yerini tutan tümenler (bir kez süzülür)
	var ctl := World.controller
	var idx_of := {}                       # ülke -> indeks (bu saatlik)
	for pid: int in by_province:
		var here0: Array = by_province[pid]
		if here0.is_empty() or not World.province(pid).is_land():
			continue
		var t0: String = (here0[0] as Division).owner
		# iç bölge (bütün komşularını kendi ülkesi tutuyor) cephe olamaz: yerinde duran düşman tümeni ancak kendi
		# tarafının tuttuğu bölgede durur (boş bölgeye giren onu alır). Ucuz ön eleme; dünyadaki dolu bölgelerin çoğu iç
		if not idx_of.has(t0):
			var tc: Country = World.countries.get(t0)
			idx_of[t0] = tc.index if tc else -1
		var my_idx: int = idx_of[t0]
		var bk := Vector2i(pid, my_idx)
		var border: bool
		if _border_cache.has(bk):
			border = _border_cache[bk]
		else:
			border = false
			for n in World.land_neighbors(pid):
				if ctl[n] != my_idx:
					border = true
					break
			_border_cache[bk] = border
		if not border:
			continue
		var front := false
		for n in World.land_neighbors(pid):
			var there: Array = by_province.get(n, [])
			for d2: Division in there:
				if enemy_of.call(d2.owner, t0):
					front = true
					break
			if front:
				break
		if not front:
			continue
		var h: Array = _holding(here0, busy)
		if not h.is_empty():
			holding[pid] = h
	GameClock.timed("sk_scan", __sk); __sk = Time.get_ticks_usec()
	for pid: int in holding:
		var here: Array = holding[pid]
		var tag: String = (here[0] as Division).owner
		for n in World.land_neighbors(pid):
			if not holding.has(n):
				continue
			var pk := Vector2i(mini(pid, n), maxi(pid, n))
			if seen.has(pk):
				continue
			var foes: Array = (holding[n] as Array).filter(func(d: Division) -> bool: return enemy_of.call(d.owner, tag))
			if foes.is_empty():
				continue
			seen[pk] = true
			if _phoney_war_malus(tag) > 0.0 or _phoney_war_malus((foes[0] as Division).owner) > 0.0:
				continue
			var width: float = float(terrain.get(World.province(n).terrain, terrain["plains"])["width"])
			var a := _frontline(here, width)
			var b := _frontline(foes, width)
			var fa := _fire(a, b, n)
			var fb := _fire(b, a, pid)
			_apply_hits(b, fa * SKIRMISH_MULT * hours, "defense", 1.0)
			_apply_hits(a, fb * SKIRMISH_MULT * hours, "defense", 1.0)
			skirmishes.append([pid, n])
			for d: Division in a + b:
				breaking[d] = true
	GameClock.timed("sk_pairs", __sk); __sk = Time.get_ticks_usec()
	for d: Division in breaking:
		if not d.path.is_empty() or d.hold or not (d in by_province.get(d.province, [])):
			continue
		var s := div_stats(d)
		if d.org < s["org"] * RETREAT_ORG or d.strength < 0.1:
			_retreat(d)
	GameClock.timed("sk_break", __sk)

## Bölgede yerini tutan (yürümeyen, eğitimde olmayan, başka muharebede olmayan) ve ateş edecek kadar düzenli
## (bütünlüğü SKIRMISH_MIN_ORG üstünde) tümenler. Yıpranan ateşi keser, mevzisinde toparlanır (hedef de olmaz; eskiden
## çekildiği bölgede yine vurulup her saat bir daha çekiliyordu); cepheyi asıl taarruz kırar.
const SKIRMISH_MIN_ORG := 0.3
func _holding(divs: Array, busy: Dictionary) -> Array:
	return divs.filter(func(d: Division) -> bool:
		return d.path.is_empty() and d.training == 0 and not busy.has(d) and d.org >= div_stats(d)["org"] * SKIRMISH_MIN_ORG)

## Bir tarafın öbürüne ateş gücü (muharebedeki gibi yumuşak/sert hedef; savunma tavrında)
func _fire(shooters: Array, targets: Array, at_pid: int) -> float:
	var hard := 0.0
	for d: Division in targets:
		hard += div_stats(d)["hardness"]
	hard /= maxf(targets.size(), 1)
	var f := 0.0
	for d: Division in shooters:
		var s := div_stats(d)
		f += (s["soft"] * (1.0 - hard) + s["hard"] * hard) * d.strength * defend_mod(d, at_pid) * d.xp_mult()
	return f

## Topçu desteği: muharebe bölgesine komşu bölgede yerinde duran (yürümeyen, saldırmayan, muharebede ve eğitimde
## olmayan) ve muharebedeki karşı tarafla savaşta olan tümenlerin topçu taburları muharebeye uzaktan ateşle katılır:
## topçunun yumuşak saldırısının ART_SUPPORT katı (sert hedefe karşı onda biri). Destek veren vurulmaz; bir tümen saatte
## tek muharebeye destek verir ve o saat yan yana ateşe (_skirmish) katılmaz. İsteksiz savaştaki ülke ateş etmez.
## Neden 0,25: piyade tümeninin 2 topçu taburu 250 yumuşak saldırı eder (tümenin yumuşak saldırısının yarısından
## fazlası). Tam katılım komşudaki her tümeni ikinci bir saldıran yapardı. Dörtte biri piyade tümeni başına ~60 eder:
## iki destekçi saldırana ~%25 katar, fark edilir ama muharebeyi tek başına çevirmez.
const ART_SUPPORT := 0.25
var supporting: Dictionary = {}        ## bu saat destek ateşi veren tümenler: Division -> muharebe bölgesi
var _engaged: Dictionary = {}          ## bu saat muharebedeki tümenler (destek veremez)
var _foe_pair: Dictionary = {}         ## "a:b" -> savaşta mı (saatlik önbellek)

## commit: gerçek muharebe (destek verenler bu saat için işaretlenir); false: tahmin (hiçbir şey değişmez)
func _support_fire(pid: int, foe_tag: String, target_hard: float, engaged: Dictionary, commit: bool) -> Dictionary:
	var fire := 0.0
	var n_sup := 0
	for n in World.land_neighbors(pid):
		for d: Division in by_province.get(n, []):
			if engaged.has(d) or (commit and supporting.has(d)) or d.training > 0 or not d.path.is_empty() or d.attacking > 0:
				continue
			var art: float = float(div_stats(d).get("art_soft", 0.0))
			if art <= 0.0 or not _at_war(d.owner, foe_tag) or _phoney_war_malus(d.owner) > 0.0:
				continue
			fire += art * (1.0 - 0.9 * target_hard) * d.strength * d.xp_mult() * ART_SUPPORT
			n_sup += 1
			if commit:
				supporting[d] = pid
	return {"fire": fire, "n": n_sup}

func _at_war(a: String, b: String) -> bool:
	var k := a + ":" + b
	if not _foe_pair.has(k):
		_foe_pair[k] = Diplomacy.are_enemies(a, b)
	return _foe_pair[k]

func _resolve_battle(pid: int, attackers: Array, defenders: Array) -> void:
	var p := World.province(pid)
	var tinfo: Dictionary = terrain.get(p.terrain, terrain["plains"])
	var width: float = float(tinfo["width"])
	var att := _frontline(attackers, width)
	var dfn := _frontline(defenders, width)
	var att_hard := 0.0
	var def_hard := 0.0
	for d: Division in att: att_hard += div_stats(d)["hardness"]
	for d: Division in dfn: def_hard += div_stats(d)["hardness"]
	att_hard /= maxf(att.size(), 1)
	def_hard /= maxf(dfn.size(), 1)
	# saldırı gücü
	var att_attack := 0.0
	for d: Division in att:
		var s := div_stats(d)
		att_attack += (s["soft"] * (1.0 - def_hard) + s["hard"] * def_hard) * d.strength * attack_mod(d, pid) * d.xp_mult()
		# saldırdıkça planlama erir, tecrübe artar
		d.planning = maxf(d.planning - 0.02, 0.0)
		d.xp = minf(d.xp + 0.0008, 1.0)
	var def_attack := 0.0
	for d: Division in dfn:
		var s := div_stats(d)
		def_attack += (s["soft"] * (1.0 - att_hard) + s["hard"] * att_hard) * d.strength * defend_mod(d, pid) * d.xp_mult()
		d.xp = minf(d.xp + 0.0006, 1.0)
	# topçu desteği: komşu bölgelerde yerinde duran dost tümenlerin topçusu iki tarafa da ateşle katılır
	var sup_att := _support_fire(pid, (defenders[0] as Division).owner, def_hard, _engaged, true)
	var sup_def := _support_fire(pid, (attackers[0] as Division).owner, att_hard, _engaged, true)
	att_attack += float(sup_att["fire"])
	def_attack += float(sup_def["fire"])
	_apply_hits(dfn, att_attack, "defense", 1.0)
	_apply_hits(att, def_attack, "breakthrough", 1.0)
	var att_org := 0.0
	var att_max := 0.0
	for d: Division in attackers:
		att_org += d.org
		att_max += div_stats(d)["org"]
	var def_org := 0.0
	var def_max := 0.0
	for d: Division in defenders:
		def_org += d.org
		def_max += div_stats(d)["org"]
	battles[pid] = {"attackers": attackers, "defenders": defenders,
			"att_ratio": att_org / maxf(att_max, 1.0), "def_ratio": def_org / maxf(def_max, 1.0),
			"from": attackers[0].province, "att_support": int(sup_att["n"]), "def_support": int(sup_def["n"])}
	# geri çekilme / yok olma — "son askere kadar" duruşundaki tümen geri çekilmez, gücü bitince yok olur
	for d: Division in defenders:
		var s := div_stats(d)
		if d.hold:
			if d.strength < 0.04:
				_notify_loss(d)
				_remove(d)
				division_destroyed.emit(d.owner)
			continue
		if d.org < s["org"] * RETREAT_ORG or d.strength < 0.1:
			_retreat(d)
	for d: Division in attackers:
		var s := div_stats(d)
		d.in_combat = true
		if d.org < s["org"] * RETREAT_ORG or d.strength < 0.1:
			stop(d)

func _apply_hits(targets: Array, attack: float, def_key: String, _m: float) -> void:
	if targets.is_empty():
		return
	var per := attack / targets.size()
	for d: Division in targets:
		var s := div_stats(d)
		var defense: float = s[def_key] * d.strength
		if def_key == "defense":
			defense *= entrenchment(d)
		var hits := HIT_DEF * minf(per, defense) + HIT_OPEN * maxf(per - defense, 0.0)
		hits *= randf_range(0.8, 1.2)
		d.org = maxf(d.org - hits * ORG_DMG, 0.0)
		var hp_loss := hits * STR_DMG
		d.strength = maxf(d.strength - hp_loss / s["hp"], 0.0)
		d.in_combat = true

func _retreat(d: Division) -> void:
	stop(d)
	var dest := _safe_province(d)
	if dest == 0:
		_notify_loss(d)
		loss_log[d.owner + ":encircled"] = int(loss_log.get(d.owner + ":encircled", 0)) + 1
		if OS.get_environment("BALDBG") == "1" and d.owner in ["GER", "ITA"] and int(loss_log[d.owner + ":encircled"]) % 7 == 1:
			var nb: Array = []
			for n in World.land_neighbors(d.province):
				nb.append("%d:%s:e%d" % [n, World.controller_tag(n), enemies_in(n, d.owner).size()])
			print("ENC %s %d prov=%d ctl=%s attacking=%d moving=%s nb=%s" % [d.owner, World.date_value(), d.province, World.controller_tag(d.province), d.attacking, str(not d.path.is_empty()), str(nb)])
		_remove(d)
		division_destroyed.emit(d.owner)
		return
	_move_to(d, dest)

## Dost toprakta düşmansız en yakın bölge (en fazla 8 adım); yoksa 0 = kuşatılmış
func _safe_province(d: Division) -> int:
	var seen := {d.province: true}
	var frontier: Array[int] = [d.province]
	for depth in 8:
		var next: Array[int] = []
		for cur in frontier:
			for n in World.land_neighbors(cur):
				if seen.has(n):
					continue
				seen[n] = true
				var ctl := World.controller_tag(n)
				if ctl != d.owner and not Diplomacy.are_allies(ctl, d.owner):
					continue
				if enemies_in(n, d.owner).is_empty():
					return n
				next.append(n)
		frontier = next
		if frontier.is_empty():
			break
	return 0

func _nearest_friendly_coast(d: Division) -> int:
	var seen := {d.province: true}
	var frontier: Array[int] = [d.province]
	for depth in 30:
		var next: Array[int] = []
		for cur in frontier:
			for n in World.province(cur).adjacent:
				if seen.has(n):
					continue
				seen[n] = true
				var p := World.province(n)
				if p == null:
					continue
				if p.is_land():
					var ctl := World.controller_tag(n)
					if ctl == d.owner or Diplomacy.are_allies(ctl, d.owner):
						return n
				elif p.type == Province.Type.SEA:
					next.append(n)
		frontier = next
	return 0

func _notify_loss(d: Division) -> void:
	var p := World.player_tag
	if d.owner == p or Diplomacy.are_enemies(d.owner, p):
		World.notify(tr("NOTE_DIV_DESTROYED") % [d.name, World.countries[d.owner].display_name()], "bad")

## Bütünlük toparlanması: iki saatte bir, iki saatlik oranla (hız aynı; her saat bütün tümenleri gezmek 5× hızda pahalı)
func _recover() -> void:
	if GameClock.hour % 2 != 0:
		return
	for d in divisions:
		if d.in_combat:
			continue
		var s := div_stats(d)
		if d.org >= s["org"] and d.supplied:
			continue
		# duran toparlanır; yürüyen toparlanmaz (yorgunluk); cephede saldırıyı bekleyen yavaş toparlanır
		var rate := 0.0 if not d.supplied else (0.04 if d.path.is_empty() else (0.016 if d.attacking > 0 else 0.0))
		d.org = minf(d.org + s["org"] * rate, s["org"] * (1.0 if d.supplied else 0.4))

# ------------------------------------------------------------------ günlük: ikmal, takviye, eğitim, hava/deniz
## Günlük askeriye. Oyunda: genel işler (ikmal, yakıt, ordular, takviye) gün başında, tümen başına günlük iş (eğitim,
## ikmal durumu, hazırlık, yıpranma, yakıt tüketimi) günün saatlerine yayılır (id % 24 == saat); her tümen yine günde
## bir kez. _on_day() her şeyi bir kerede yapar (testler, hızlı simülasyon).
var _fuel_acc := {}                  ## gün içinde saat dilimlerinde biriken yakıt tüketimi (ülke -> miktar)

func _on_day() -> void:
	var __t := Time.get_ticks_usec()
	_on_day_impl(true)
	GameClock.timed("mil_day", __t)

func _on_day_sliced() -> void:
	var __t := Time.get_ticks_usec()
	_on_day_impl(false)
	GameClock.timed("mil_day", __t)

func _hour_divs() -> void:
	var h := GameClock.hour
	for d in divisions:
		if d.id % 24 == h:
			_div_daily(d, _fuel_acc)

func _div_daily(d: Division, fuel_use: Dictionary) -> void:
	var fu: float = div_stats(d).get("fuel_use", 0.0) if FUEL else 0.0
	if fu > 0.0:
		fuel_use[d.owner] = float(fuel_use.get(d.owner, 0.0)) + fu * (24.0 if (d.is_moving() or d.in_combat) else 1.0)
	if d.training > 0:
		d.training -= 1
	d.supplied = not SUPPLY or not _supplied.has(d.owner) or _supplied[d.owner].has(d.province) or not World.province(d.province).is_land()
	if not d.supplied:
		d.strength = maxf(d.strength - 0.01, 0.05)
	# planlama: düşmana komşu, bekleyen tümen 15 günde tam plana ulaşır; cephe dışında dağılır
	if d.training == 0 and d.path.is_empty() and not d.in_combat and _is_front(d):
		d.planning = minf(d.planning + 1.0 / 15.0, 1.0)
	elif not d.in_combat:
		d.planning = maxf(d.planning - 0.1, 0.0)
	# mevsim yıpranması: sert soğuk ve çöl sıcağı
	var w := winter_level(d.province)
	if w > 0.0:
		d.strength = maxf(d.strength - 0.0025 * w, 0.2)
	elif GameClock.month >= 6 and GameClock.month <= 8 and World.province(d.province).terrain == "desert":
		d.strength = maxf(d.strength - 0.0015, 0.3)

## full (testler, hızlı simülasyon): günün bütün işi bir kerede. Oyunda (sliced): gün başında yalnız SP geliri; tümen
## başına iş günün saatlerine (_hour_divs), genel işler kendi saatlerine (_day_stage, GameClock.DAY_STAGE) yayılır
func _on_day_impl(full: bool = true) -> void:
	_sp_income()
	_bonus_cache.clear()          # ordu büyüklükleri değişmiş olabilir
	if not full:
		return
	var tl := Time.get_ticks_usec()
	if World.day_count % 2 == 0:
		_compute_supply()                 # önce ikmal: tümenlerin günlük işi yeni ikmal durumunu kullanır
	GameClock.timed("supply", tl); tl = Time.get_ticks_usec()
	for d in divisions:
		_div_daily(d, _fuel_acc)
	GameClock.timed("mil_divloop", tl)
	if FUEL:
		_fuel(_fuel_acc)
	_fuel_acc = {}
	for stage: String in ["mil_armies", "mil_reinforce", "mil_airnaval"]:
		_run_stage(stage)

## Saat başı: bu saatin genel günlük işi varsa
func _day_stage() -> void:
	for stage: String in ["mil_supply", "mil_armies", "mil_reinforce", "mil_airnaval"]:
		if GameClock.hour == int(GameClock.DAY_STAGE[stage]):
			_run_stage(stage)
	if GameClock.hour == int(GameClock.DAY_STAGE["mil_supply"]) + 1:
		var tl := Time.get_ticks_usec()
		_compute_supply(_supply_slice(1), SUPPLY_SLICES)
		GameClock.timed("supply", tl)

## Oyunda ikmal ağı dört dilimde hesaplanır (iki gün × iki saat; ülke indeksine göre): her ülke yine iki günde bir
## yenilenir, ama bütün dünyanın taraması tek karede (~15 ms) değil
const SUPPLY_SLICES := 4
func _supply_slice(hour_part: int) -> int:
	return (World.day_count % 2) * 2 + hour_part

func _run_stage(stage: String) -> void:
	var tl := Time.get_ticks_usec()
	match stage:
		"mil_supply":
			_compute_supply(_supply_slice(0), SUPPLY_SLICES)
			GameClock.timed("supply", tl); tl = Time.get_ticks_usec()
			if FUEL:
				_fuel(_fuel_acc)
			_fuel_acc = {}
			GameClock.timed("mil_fuel", tl)
		"mil_armies":
			_experience_tick()
			GameClock.timed("mil_xp", tl); tl = Time.get_ticks_usec()
			_armies_tick()
			GameClock.timed("armies", tl)
		"mil_reinforce":
			_reinforce()
			GameClock.timed("mil_reinforce", tl)
		"mil_airnaval":
			_air_and_naval()
			GameClock.timed("mil_airnaval", tl)
			_strand_check()

## Denizde kalıp kıyıya dönemeyen tümen kaybolur
func _strand_check() -> void:
	for d in divisions.duplicate():
		if d.path.is_empty() and not World.province(d.province).is_land():
			var port := _nearest_friendly_coast(d)
			if port == 0 or not order_move(d, port):
				loss_log[d.owner + ":stranded"] = int(loss_log.get(d.owner + ":stranded", 0)) + 1
				_remove(d)

## Düşmana komşu mu. Düşman ülke indeksleri ülke başına günde bir kez kümelenir (her komşu için savaş listesini
## taramak günlük tümen döngüsünün çoğunu tutuyordu)
var _foe_idx := {}
var _foe_day := -1

func _is_front(d: Division) -> bool:
	if _foe_day != World.day_count:
		_foe_idx.clear()
		_foe_day = World.day_count
	if not _foe_idx.has(d.owner):
		var set := {}
		for t: String in Diplomacy.enemies_of(d.owner):
			var ec: Country = World.countries.get(t)
			if ec:
				set[ec.index] = true
		_foe_idx[d.owner] = set
	var foes: Dictionary = _foe_idx[d.owner]
	if foes.is_empty():
		return false
	var ctl := World.controller
	for n in World.land_neighbors(d.province):
		if foes.has(ctl[n]):
			return true
	return false

## Yakıt ekonomisi (günlük): petrol (kendi üretim + ithalat) yakıta dönüşür; zırhlı/motorlu birlikler hareket ve
## muharebede, uçaklar görevde, gemiler denizde yakar. Depo sınırlı; boşsa fuel_malus devreye girer.
const FUEL_PER_OIL := 12.0
func _fuel(use: Dictionary) -> void:
	for w in Air.wings:
		if w.on_mission():
			use[w.owner] = float(use.get(w.owner, 0.0)) + w.planes * 0.02
	for f in Navy.fleets:
		if not f.in_port():
			use[f.owner] = float(use.get(f.owner, 0.0)) + f.total() * 0.06
	for c: Country in World.countries.values():
		if not c.exists():
			continue
		var oil := float(Economy.resource_production(c).get("oil", 0.0))
		for i: Dictionary in c.imports:
			if i["res"] == "oil":
				oil += float(i["amount"])
		# taban gelir (sanayi: depolar, kömürden sınırlı üretim) + petrol; depo sanayi ve petrolle büyür
		var mil := float(Economy.count(c, "military_factory"))
		c.fuel_cap = 4000.0 + oil * 800.0 + mil * 120.0
		if c.fuel < 0.0:
			c.fuel = c.fuel_cap * 0.9
		var gain := 20.0 + mil * 1.5 + oil * FUEL_PER_OIL
		c.fuel = clampf(c.fuel + gain - float(use.get(c.tag, 0.0)), 0.0, c.fuel_cap)

## İkmal menzili: kaynak = kendi/müttefik sahipliğindeki ve kontrolündeki topraklar + limanlar;
## işgal edilen topraklarda kaynaktan en fazla SUPPLY_RANGE bölge içeri ikmal ulaşır, ötesi ikmalsiz.
const SUPPLY_RANGE := 9

## slices > 1: yalnız indeksi bu dilime düşen ülkeler (savaşta olmayanın eski ağı silinir)
func _compute_supply(slice := 0, slices := 1) -> void:
	if slices == 1:
		_supplied.clear()
	var ctl := World.controller
	for c: Country in World.countries.values():
		if not c.exists() or not Diplomacy.at_war(c.tag):
			_supplied.erase(c.tag)
			continue
		if c.index % slices != slice:
			continue
		var friend := PackedByteArray()
		friend.resize(World.country_by_index.size())
		for i in range(1, World.country_by_index.size()):
			var o: Country = World.country_by_index[i]
			if o == c or Diplomacy.are_allies(o.tag, c.tag):
				friend[i] = 1
		var depth := {}
		var queue: Array[int] = []
		# kaynaklar: sahibi dost olup dostun kontrolündeki bölgeler (anavatan / müttefik toprağı)
		for sid in c.states:
			for pid in World.states[sid].provinces:
				if friend[ctl[pid]] == 1:
					depth[pid] = 0
					queue.append(pid)
		for city in World.cities:
			if city.is_port and friend[ctl[city.province_id]] == 1 and not depth.has(city.province_id):
				var st := World.state_of_province(city.province_id)
				if st and (st.owner == c.tag or Diplomacy.are_allies(st.owner, c.tag)):
					depth[city.province_id] = 0
					queue.append(city.province_id)
		var head := 0
		while head < queue.size():
			var cur: int = queue[head]
			head += 1
			var dcur: int = depth[cur]
			if dcur >= SUPPLY_RANGE:
				continue
			for n in World.land_neighbors(cur):
				if not depth.has(n) and friend[ctl[n]] == 1:
					depth[n] = dcur + 1
					queue.append(n)
		_supplied[c.tag] = depth

func _reinforce() -> void:
	for d in divisions:
		if d.strength >= 0.999 or d.in_combat or not d.supplied:
			continue
		var c: Country = World.countries[d.owner]
		var s := div_stats(d)
		var want := minf(1.0 - d.strength, 0.08)
		var frac := want
		for e: String in (s["equipment"] if EQUIPMENT else {}):
			var need: float = s["equipment"][e] * want
			frac = minf(frac, float(c.stockpile.get(e, 0.0)) / maxf(need, 0.001) * want)
		var mp_need: float = s["manpower"] * want
		frac = minf(frac, float(c.available_manpower()) / maxf(mp_need, 1.0) * want)
		if frac <= 0.0:
			continue
		for e: String in (s["equipment"] if EQUIPMENT else {}):
			c.stockpile[e] = maxf(float(c.stockpile.get(e, 0.0)) - s["equipment"][e] * frac, 0.0)
		c.manpower_used += int(s["manpower"] * frac)
		# yeni askerler tecrübeyi sulandırır (eğitimli seviyede gelirler)
		d.xp = (d.xp * d.strength + 0.12 * frac) / maxf(d.strength + frac, 0.001)
		d.strength += frac

func air_power(c: Country) -> float:
	return Air.power(c.tag) * (1.0 + c.mod("air_power"))

func compute_naval_power(c: Country) -> float:
	return Navy.power(c.tag)

func _air_and_naval() -> void:
	naval_power.clear()
	for c: Country in World.countries.values():
		if c.exists():
			naval_power[c.tag] = compute_naval_power(c)

# ------------------------------------------------------------------ asker alma ve sanayi puanı (SP)
## Kurallar ve sayıların gerekçesi data/common/recruit.json'da. Oyuncu kendi şehrinden doğrudan asker alır: SP + insan gücü,
## birlik o şehirde eğitim günleri sonra yürür. Kanat alınırsa en yakın hava üssünde kurulur.
const RECRUIT_PATH := "res://data/common/recruit.json"
signal sp_changed                       ## SP harcandı (asker, keşif): üst çubuk hemen güncellenir
var recruit_data: Dictionary = {}

func recruit_def() -> Dictionary:
	if recruit_data.is_empty():
		recruit_data = JSON.parse_string(FileAccess.get_file_as_string(RECRUIT_PATH))
	return recruit_data

## Eyaletin fabrikalarını kim işletir: eyaletin en büyük şehrini (yoksa ilk bölgesini) elinde tutan

# ------------------------------------------------------------------ teşvik (nüfuz harcayıp askerleri motive etmek)
## Teşvikin verisi (recruit.json "motivate"): tümen başına nüfuz, bütünlük dönüşü, saldırı/savunma katkısı, süre
var _motivate_def: Dictionary = {}
func motivate_def() -> Dictionary:
	# savaşta tümen başına sorulur: varsayılan sözlük her çağrıda kurulmasın
	if _motivate_def.is_empty():
		_motivate_def = recruit_def().get("motivate", {"pp_per_division": 10, "org": 0.3, "bonus": 0.15, "hours": 48})
	return _motivate_def

func _now_hour() -> int:
	return World.day_count * 24 + GameClock.hour

## Tümen teşvikli mi (süresi sürüyor)
func motivated(d: Division) -> bool:
	return d.motivated_until > _now_hour()

## Teşvikin saldırı / savunma katkısı
func motivation(d: Division) -> float:
	return float(motivate_def()["bonus"]) if motivated(d) else 0.0

## Seçilenlerden teşvik edilebilenler (oyuncunun, eğitimde olmayan, teşviki sürmeyen)
func motivatable(c: Country, divs: Array) -> Array[Division]:
	var out: Array[Division] = []
	for d: Division in divs:
		if d.owner == c.tag and d.training == 0 and not motivated(d):
			out.append(d)
	return out

## Teşvikin bedeli (nüfuz)
func motivate_cost(c: Country, divs: Array) -> float:
	return float(motivate_def()["pp_per_division"]) * motivatable(c, divs).size()

## Neden teşvik edilemez ("" = edilebilir)
func motivate_error(c: Country, divs: Array) -> String:
	if motivatable(c, divs).is_empty():
		return "MOTIVATE_ERR_NONE"
	if c.political_power < motivate_cost(c, divs):
		return "MOTIVATE_ERR_PP"
	return ""

## Teşvik: nüfuz harcanır, bütünlüğün bir kısmı hemen döner, süre boyunca saldırı ve savunma artar
func motivate(c: Country, divs: Array) -> String:
	var err := motivate_error(c, divs)
	if err != "":
		return err
	var md := motivate_def()
	var list := motivatable(c, divs)
	c.political_power -= motivate_cost(c, divs)
	var until := _now_hour() + int(md["hours"])
	for d in list:
		var mx: float = div_stats(d)["org"]
		d.org = minf(d.org + mx * float(md["org"]), mx)
		d.motivated_until = until
	return ""
func _state_holder(st: StateRegion) -> String:
	var city := st.largest_city()
	return World.controller_tag(city.province_id if city else (st.provinces[0] if not st.provinces.is_empty() else 0))

## Eyaletin günlük SP değeri (bombalanmış pay düşülür)
func _state_sp(st: StateRegion, inc: Dictionary) -> float:
	var v := 0.0
	for b: String in inc:
		v += st.building_level(b) * float(inc[b])
	return v * (1.0 - st.damage)

## Günlük SP geliri: elinde tuttuğun eyaletlerin fabrikaları (şehri alan fabrikaları da alır)
func sp_income(c: Country) -> float:
	var inc: Dictionary = recruit_def()["income"]
	var total := 0.0
	for st: StateRegion in World.states.values():
		if _state_holder(st) == c.tag:
			total += _state_sp(st, inc)
	return total

func _sp_income() -> void:
	var inc: Dictionary = recruit_def()["income"]
	var by := {}
	for st: StateRegion in World.states.values():
		var t := _state_holder(st)
		if t != "":
			by[t] = float(by.get(t, 0.0)) + _state_sp(st, inc)
	for t: String in by:
		var c: Country = World.countries.get(t)
		if c and c.exists():
			c.sp += float(by[t])

## Bu birlik bu bölgede alınabilir mi: "" ya da hata anahtarı
func recruit_error(c: Country, kind: String, pid: int) -> String:
	var u: Dictionary = recruit_def()["units"].get(kind, {})
	if u.is_empty():
		return "RECRUIT_ERR_KIND"
	var p := World.province(pid)
	if p == null or not p.is_land() or p.city == null or World.controller_tag(pid) != c.tag:
		return "RECRUIT_ERR_CITY"
	if c.sp < float(u["sp"]):
		return "RECRUIT_ERR_SP"
	if u.has("template"):
		var mp := int(stats(c, int(u["template"]))["manpower"])
		if c.available_manpower() < mp:
			return "RECRUIT_ERR_MANPOWER"
	elif u.has("ship"):
		var st := World.state_of_province(pid)
		if st == null or Navy.port_in_state(c.tag, st.id) == 0:
			return "RECRUIT_ERR_PORT"
	elif Air.bases_of(c.tag).is_empty():
		return "RECRUIT_ERR_AIRBASE"
	return ""

## Asker al: "" ya da hata anahtarı
func recruit(c: Country, kind: String, pid: int) -> String:
	var err := recruit_error(c, kind, pid)
	if err != "":
		return err
	var u: Dictionary = recruit_def()["units"][kind]
	c.sp -= float(u["sp"])
	if u.has("template"):
		var ti := int(u["template"])
		_create(c, ti, pid, 1.0, int(u["days"]))
		c.manpower_used += int(stats(c, ti)["manpower"])
	elif u.has("ship"):
		# gemi eyaletin limanındaki yedek filoya katılır (Navy.deploy_ships)
		var t: String = u["ship"]
		c.stockpile[t] = float(c.stockpile.get(t, 0.0)) + 1.0
		Navy.deploy_ships(c, Navy.port_in_state(c.tag, World.state_of_province(pid).id))
	else:
		var t: String = u["wing"]
		var eq: String = Air.TYPES[t]["eq"]
		c.stockpile[eq] = float(c.stockpile.get(eq, 0.0)) + Air.WING_SIZE
		var base := Air.base_for_point(c.tag, World.province(pid).center)
		Air.deploy(c, t, base if base > 0 else Air._home_base(c.tag))
	sp_changed.emit()
	return ""

# ------------------------------------------------------------------ savaş sisi
## Oyuncu için savaş sisi (haritanın üstünde 3B bulut, FogCloudLayer). Keşif kalıcıdır: bir kez keşfedilen bölge bir daha
## kapanmaz (kayda yazılır). Keşfedilen bölgeler (_fog: 0 bulut, 2 açık):
## - oyuncunun ya da müttefikinin kontrolündeki bölgeler ve bir bölge ötesi (ortak sınırda 1 bölge derin görülür);
## - bu tarafın tümenlerinin girdiği her bölge ve bir bölge ötesi (asker gittikçe keşfeder);
## - keşif kanatlarının bölgeleri (Air.recon_provinces).
## Bulutun altında müttefik olmayan her ülkenin tümeni, filosu, kanadı ve yapısı gizlidir. Yapay zekâ sisten etkilenmez;
## izleyici kipinde sis yok. fog_enabled: testler kapatır.
var fog_enabled := true
var fog_version := 0                   ## keşif değiştikçe artar (bulut katmanı dokusu yalnız o zaman güncellenir)
var _fog := PackedByteArray()          ## bölge başına 0 bulut / 2 keşfedilmiş (kalıcı)
var _fog_dirty := true
var _fog_hooked := false
var _fog_side := {}                    ## oyuncu ve müttefikleri (tümen hareketinde hızlı kontrol)

func fog_active() -> bool:
	return fog_enabled and World.in_game and not Game.observer and World.player_tag != ""

## Keşfi sıfırla (yeni oyun, senaryo başı); kayıttan yüklerken set_explored
func reset_explored() -> void:
	_fog = PackedByteArray()
	_fog_side.clear()
	_fog_dirty = true

## Kayıt için keşif (base64) ve geri yükleme
func explored_b64() -> String:
	return Marshalls.raw_to_base64(_fog) if not _fog.is_empty() else ""

func set_explored(b64: String) -> void:
	reset_explored()
	if b64 != "":
		_fog = Marshalls.base64_to_raw(b64)

## Bölge başına sis düzeyleri (0 bulut, 2 keşfedilmiş); bulut dokusu için
func fog_levels() -> PackedByteArray:
	_ensure_fog()
	return _fog

func invalidate_fog() -> void:
	_fog_dirty = true
	_announce_fog()

var _fog_emit_pending := false
func _announce_fog() -> void:
	if not _fog_emit_pending and fog_active():
		_fog_emit_pending = true
		_emit_fog_change.call_deferred()        # haritalar yeniden çizsin (duraklatılmışken verilen keşif emri de hemen)

func _emit_fog_change() -> void:
	_fog_emit_pending = false
	divisions_changed.emit()

func is_visible(pid: int) -> bool:
	if not fog_active():
		return true
	_ensure_fog()
	return pid > 0 and pid < _fog.size() and _fog[pid] > 0

## Oyuncunun göremediği (bulutun altındaki) yabancı tümen mi; kendi ve müttefik tümenleri hiç gizlenmez
func hidden(d: Division) -> bool:
	if not fog_active():
		return false
	_ensure_fog()
	return not _fog_side.has(d.owner) and d.province < _fog.size() and _fog[d.province] == 0

## Bu bölgedeki bu ülkenin birliği (filo, kanat) bulutun altında mı: sis açık, ülke biz ya da müttefik değil, bölge bulutta
func hidden_at(owner: String, pid: int) -> bool:
	if not fog_active():
		return false
	_ensure_fog()
	return not _fog_side.has(owner) and pid > 0 and pid < _fog.size() and _fog[pid] == 0

## Eyalet bulutun altında mı (yapı iğneleri ve ikonları için): yabancı (bizim ya da müttefik değil) ve hiçbir bölgesi
## keşfedilmemiş
func state_fogged(st: StateRegion) -> bool:
	if st == null or not fog_active():
		return false
	_ensure_fog()
	if _fog_side.has(st.owner):
		return false
	for pid in st.provinces:
		if pid < _fog.size() and _fog[pid] > 0:
			return false
	return true

## Bölgeyi ve (around ise) bir bölge ötesini keşfet; yeni keşif olduysa true
func _explore(pid: int, around: bool) -> bool:
	if pid <= 0 or pid >= _fog.size():
		return false
	var changed := false
	if _fog[pid] == 0:
		_fog[pid] = 2
		changed = true
	# gece birlik yalnız durduğu bölgeyi görür: komşular gün doğunca (Military._on_hour sisi yeniler)
	if around and GameClock.night_at(World.province(pid).center) < 0.5:
		for q in World.province(pid).adjacent:
			if q < _fog.size() and _fog[q] == 0:
				_fog[q] = 2
				changed = true
	return changed

## Tümen bölge değiştirdi (_move_to): oyuncunun tarafındaysa girdiği bölge ve çevresi keşfedilir
func _explore_move(d: Division, pid: int) -> void:
	if _fog.is_empty() or not _fog_side.has(d.owner) or not fog_active():
		return
	if _explore(pid, true):
		fog_version += 1
		_announce_fog()

func _ensure_fog() -> void:
	if not _fog_hooked:
		_fog_hooked = true
		World.control_changed.connect(invalidate_fog)
		World.ownership_changed.connect(invalidate_fog)
		World.player_changed.connect(func(_t: String) -> void: invalidate_fog())
		Air.wings_changed.connect(invalidate_fog)
		Diplomacy.wars_changed.connect(invalidate_fog)
		World.daily_update.connect(invalidate_fog)     # keşif kanatları gün boyu uçar; denizdeki birlikler
	var n := World.provinces.size()
	if not _fog_dirty and _fog.size() == n:
		return
	_fog_dirty = false
	if _fog.size() != n:
		var old := _fog
		_fog = PackedByteArray()
		_fog.resize(n)
		for i in mini(old.size(), n):
			_fog[i] = old[i]
	var me := World.player_tag
	# tarafımızın ülke indeksleri: kontrol dizisi tamsayı karşılaştırmasıyla taranır (bölge başına ülke araması yok)
	var side := {}
	_fog_side.clear()
	for c: Country in World.countries.values():
		if c.tag == me or Diplomacy.are_allies(c.tag, me):
			side[c.index] = true
			_fog_side[c.tag] = true
	var changed := false
	var ctl := World.controller
	for pid in range(1, mini(n, ctl.size())):
		if side.has(ctl[pid]):
			changed = _explore(pid, true) or changed
	for d in divisions:
		if _fog_side.has(d.owner):
			changed = _explore(d.province, true) or changed
	for pid: int in Air.recon_provinces(me):
		changed = _explore(pid, false) or changed
	if changed or fog_version == 0:
		fog_version += 1
