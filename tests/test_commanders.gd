extends "res://tests/test_case.gd"
## Komuta zinciri: komutan kadroları, atama/terfi/yeni general, muharebe katkısı, tecrübe, oyuncu kararları
## (kendiliğinden atama yok, boş ordu kalır, doğrudan emirdeki tümen ordu planının dışında).

func _army(tag: String, n: int) -> Army:
	var divs := Military.country_divisions(tag).slice(0, n)
	return Military.create_army(tag, divs)

func test_every_country_has_a_roster() -> void:
	var p: Array[String] = []
	for c: Country in World.countries.values():
		if not c.exists() or not World.is_active(c.tag):
			continue                          # savaşa katılmayan tarafsızların ordusu yok
		var list := Military.commanders_of(c.tag)
		if list.size() < 2:
			p.append("%s: %d komutan" % [c.tag, list.size()])
		var names := {}
		for cm in list:
			if names.has(cm.name):
				p.append("%s: iki kez %s" % [c.tag, cm.name])
			names[cm.name] = true
			if cm.skill < 1 or cm.skill > Commander.MAX_SKILL:
				p.append("%s: %s beceri %d" % [c.tag, cm.name, cm.skill])
	none(p, "komutan kadrosu")
	var tur := Military.commanders_of("TUR")
	check(tur.any(func(x: Commander) -> bool: return x.name == "Fevzi Çakmak" and x.is_marshal()), "Fevzi Çakmak mareşal olarak kadroda")
	check(Military.commanders_of("GER").size() >= 10, "büyük güçlerin kadrosu geniş")

func test_player_armies_get_no_automatic_commander() -> void:
	var a := _army("TUR", 4)
	eq(a.commander, 0, "oyuncunun yeni ordusu komutansız başlar")
	Military.ai_assign_commander(a)
	eq(a.commander, 0, "yapay zekâ ataması oyuncu ordusuna dokunmaz")
	var g := _army("GRE", 3)
	Military.ai_assign_commander(g)
	check(g.commander != 0, "yapay zekâ ordusu komutan alır")

func test_empty_player_army_persists() -> void:
	var a := Military.create_army("TUR", [])
	Military._armies_tick()
	check(Military.army_by_id(a.id) != null, "oyuncunun boş ordusu silinmez")
	var ai := Military.create_army("GRE", [])
	Military._armies_tick()
	check(Military.army_by_id(ai.id) == null, "yapay zekânın boş ordusu kalkar")

func test_assign_moves_commander_between_posts() -> void:
	var a := _army("TUR", 3)
	var b := _army("TUR", 3)
	var cm: Commander = Military.free_commanders("TUR")[0]
	Military.assign_army_commander(a, cm.id)
	eq(a.commander, cm.id, "ordu A'ya atandı")
	Military.assign_army_commander(b, cm.id)
	eq(b.commander, cm.id, "ordu B'ye atandı")
	eq(a.commander, 0, "A'daki görevi boşaldı")
	check(not Military.free_commanders("TUR").has(cm), "görevdeki komutan boşta sayılmaz")
	var g := Military.create_group("TUR")
	var gen: Commander = Military.free_commanders("TUR").filter(func(x: Commander) -> bool: return not x.is_marshal())[0]
	Military.assign_group_commander(g, gen.id)
	eq(g.commander, 0, "general ordular grubunu yönetemez")
	Military.disband_army(b)
	check(Military.post_of(cm) == null, "ordu dağılınca komutan boşa çıkar")

func test_promote_and_recruit_cost_command_power() -> void:
	var c := player()
	var gen: Commander = Military.free_commanders("TUR").filter(func(x: Commander) -> bool: return not x.is_marshal())[0]
	c.command_power = Military.PROMOTE_COST - 1.0
	check(not Military.promote(gen), "komuta gücü yetmezse terfi yok")
	c.command_power = Military.PROMOTE_COST + 5.0
	check(Military.promote(gen), "terfi")
	check(gen.is_marshal(), "general mareşal oldu")
	near(c.command_power, 5.0, 0.001, "terfi bedeli düşüldü")
	check(Military.recruit_commander("TUR") == null, "komuta gücü yetmezse yeni general yok")
	c.command_power = 50.0
	var n := Military.commanders_of("TUR").size()
	var cm := Military.recruit_commander("TUR")
	check(cm != null and cm.skill == 1 and not cm.is_marshal(), "yeni general beceri 1")
	eq(Military.commanders_of("TUR").size(), n + 1, "kadro büyüdü")
	near(c.command_power, 50.0 - Military.RECRUIT_COST, 0.001, "yeni general bedeli")

func test_command_bonus_in_combat() -> void:
	var a := _army("TUR", 6)
	var d: Division = Military.army_divisions(a)[0]
	var pid := 0
	for n in World.land_neighbors(d.province):
		pid = n
		break
	var m0 := Military.attack_mod(d, pid)
	var cm: Commander = Military.free_commanders("TUR").filter(func(x: Commander) -> bool: return not x.is_marshal())[0]
	cm.skill = 3
	Military.assign_army_commander(a, cm.id)
	near(Military.attack_mod(d, pid) - m0, Military.GENERAL_BONUS * 3, 0.0001, "general becerisi saldırıya eklenir")
	near(Military.command_bonus(d), Military.GENERAL_BONUS * 3, 0.0001, "savunmaya da aynı katkı")
	var g := Military.create_group("TUR")
	var m: Commander = Military.free_commanders("TUR", true)[0]
	m.skill = 4
	Military.assign_group_commander(g, m.id)
	Military.set_army_group(a, g.id)
	near(Military.command_bonus(d), Military.GENERAL_BONUS * 3 + Military.MARSHAL_BONUS * 4, 0.0001, "mareşal gruptaki orduya eklenir")
	eq(Military.command_bonus(Military.country_divisions("TUR").filter(func(x: Division) -> bool: return x.army == 0)[0]), 0.0, "ordusuz tümene katkı yok")

func test_commander_gains_skill_in_battle() -> void:
	var a := _army("TUR", 8)
	var cm: Commander = Military.free_commanders("TUR").filter(func(x: Commander) -> bool: return x.skill <= 2)[0]
	var s0 := cm.skill
	Military.assign_army_commander(a, cm.id)
	for i in 60:
		Military._commander_xp({a.id: 8})
	gt(cm.skill, s0, "60 gün muharebede beceri yükselir")
	var top := Commander.new()
	top.skill = Commander.MAX_SKILL
	check(not top.gain(5.0), "en yüksek beceri aşılmaz")

func test_manual_division_left_alone_by_army() -> void:
	var divs := Military.country_divisions("TUR")
	var a := Military.create_army("TUR", divs)
	a.enemy = "GRE"
	var front := Military.front_provinces(a)
	if not check(not front.is_empty(), "Yunanistan cephesi var"):
		return
	var off: Division = null
	for d in divs:
		if not d.province in front:
			off = d
			break
	if not check(off != null, "cephe dışında tümen var"):
		return
	off.manual = true
	Military._armies_tick()
	check(off.path.is_empty(), "doğrudan emirdeki tümeni ordu cepheye çekmez")
	off.manual = false
	var moved := 0
	for i in 3:
		Military._armies_tick()
	for d in divs:
		if d.is_moving():
			moved += 1
	gt(moved, 0, "plandaki tümenler cepheye yürür")
	Military.set_division_army(off, 0)
	eq(off.army, 0, "ordudan çıkar")
