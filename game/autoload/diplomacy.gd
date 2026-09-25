extends Node
## Diplomasi: savaşlar, ittifaklar (faksiyonlar), garantiler, askeri geçiş, savaş gerekçesi,
## teslim alma (işgal edilen zafer puanına göre) ve barış.

signal wars_changed
signal diplomacy_changed(tag: String)

const JUSTIFY_DAYS := 30
const JUSTIFY_COST := 30.0
const CAPITULATION_BASE := 0.8

var wars: Array = []         ## [{id, attackers: [tag], defenders: [tag]}]
var _next_id := 1
## Çağrıya hemen uymayıp fırsat kollayan AI ülkeleri: tag -> müttefik (İtalya Haziran 1940'ı bekler)
var waiting_to_join := {}
const OPPORTUNE_SURRENDER := 0.4

func _ready() -> void:
	World.daily_update.connect(_on_day)

func reset() -> void:
	wars.clear()
	_next_id = 1
	waiting_to_join.clear()

# ------------------------------------------------------------------ sorgular
func any_war() -> bool:
	return not wars.is_empty()

func at_war(tag: String) -> bool:
	for w: Dictionary in wars:
		if tag in w["attackers"] or tag in w["defenders"]:
			return true
	return false

func are_enemies(a: String, b: String) -> bool:
	if a == b:
		return false
	for w: Dictionary in wars:
		if (a in w["attackers"] and b in w["defenders"]) or (a in w["defenders"] and b in w["attackers"]):
			return true
	return false

func are_allies(a: String, b: String) -> bool:
	if a == b:
		return true
	var ca: Country = World.countries.get(a)
	var cb: Country = World.countries.get(b)
	if ca and cb and ca.faction != "" and ca.faction == cb.faction:
		return true
	for w: Dictionary in wars:
		if (a in w["attackers"] and b in w["attackers"]) or (a in w["defenders"] and b in w["defenders"]):
			return true
	return false

func enemies_of(tag: String) -> Array[String]:
	var out: Array[String] = []
	for w: Dictionary in wars:
		var side := ""
		if tag in w["attackers"]: side = "defenders"
		elif tag in w["defenders"]: side = "attackers"
		if side != "":
			for t: String in w[side]:
				if not t in out:
					out.append(t)
	return out

## Birlik bu ülkenin bölgesine girebilir mi (kendi, müttefik, düşman, geçiş hakkı)
func can_enter(unit_tag: String, province_controller: String, province_owner: String) -> bool:
	if province_controller == "" or province_controller == unit_tag:
		return true
	if are_allies(unit_tag, province_controller) or are_enemies(unit_tag, province_controller):
		return true
	var c: Country = World.countries.get(unit_tag)
	return c != null and province_owner in c.access

func has_war_goal(a: String, t: String) -> bool:
	var c: Country = World.countries.get(a)
	return c != null and c.war_goals.has(t)

# ------------------------------------------------------------------ savaş gerekçesi
func can_justify(a: Country, t: Country) -> String:
	if t == null or not t.exists() or a == t:
		return "DIPLO_ERR_INVALID"
	if are_enemies(a.tag, t.tag) or a.war_goals.has(t.tag) or a.justify_progress.has(t.tag):
		return "DIPLO_ERR_ALREADY"
	if are_allies(a.tag, t.tag):
		return "DIPLO_ERR_ALLY"
	if a.political_power < JUSTIFY_COST:
		return "DIPLO_ERR_PP"
	# gerginlik eşikleri (türün klasiği): demokrasi %100 ve başka demokrasiye asla, bağlantısız %50
	if a.ideology == "democratic" and (World.world_tension < 100.0 or t.ideology == "democratic"):
		return "DIPLO_ERR_TENSION"
	if a.ideology == "neutrality" and World.world_tension < 50.0:
		return "DIPLO_ERR_TENSION"
	return ""

func justify(a: Country, t: Country) -> bool:
	if can_justify(a, t) != "":
		return false
	a.political_power -= JUSTIFY_COST
	a.justify_progress[t.tag] = JUSTIFY_DAYS
	diplomacy_changed.emit(a.tag)
	return true

func add_war_goal(a: Country, t: String) -> void:
	if a == null or t == "" or t == a.tag:
		return
	a.war_goals[t] = true
	a.justify_progress.erase(t)
	diplomacy_changed.emit(a.tag)

# ------------------------------------------------------------------ savaş ilanı
func can_declare(a: Country, t: Country) -> String:
	if t == null or not t.exists() or not a.exists():
		return "DIPLO_ERR_INVALID"
	if are_enemies(a.tag, t.tag):
		return "DIPLO_ERR_ALREADY"
	if are_allies(a.tag, t.tag):
		return "DIPLO_ERR_ALLY"
	if not a.war_goals.has(t.tag):
		return "DIPLO_ERR_NO_GOAL"
	return ""

func declare_war(a_tag: String, t_tag: String) -> bool:
	var a: Country = World.countries.get(a_tag)
	var t: Country = World.countries.get(t_tag)
	if a == null or can_declare(a, t) != "":
		return false
	var w := {"id": _next_id, "attackers": [a_tag], "defenders": [t_tag], "start": World.day_count}
	_next_id += 1
	wars.append(w)
	a.war_goals.erase(t_tag)
	World.world_tension = clampf(World.world_tension + (5.0 if a.ideology == "democratic" else 12.0), 0.0, 100.0)
	World.notify(tr("NOTE_WAR_DECLARED") % [a.display_name(), t.display_name()], "war")
	# savunmacının müttefikleri ve garantörleri
	if t.faction != "":
		for m: String in Politics.factions.get(t.faction, []):
			_add_to_side(w, "defenders", m)
	for g: Country in World.countries.values():
		if t_tag in g.guarantees and g.exists() and not are_allies(g.tag, a_tag):
			_add_to_side(w, "defenders", g.tag)
	# saldırganın ittifak üyelerine çağrı
	if a.faction != "":
		for m: String in Politics.factions.get(a.faction, []):
			if m != a_tag and not are_enemies(m, a_tag):
				Politics.fire_event(World.countries[m], "call_to_arms", a_tag)
	wars_changed.emit()
	return true

func _add_to_side(w: Dictionary, side: String, tag: String) -> void:
	var other := "attackers" if side == "defenders" else "defenders"
	var c: Country = World.countries.get(tag)
	if c == null or not c.exists() or tag in w[side] or tag in w[other]:
		return
	w[side].append(tag)
	World.notify(tr("NOTE_JOINS_WAR") % [c.display_name(), World.countries[w[side][0]].display_name()], "bad")

## c, müttefikinin (ally) tüm savaşlarına onun tarafında katılır
func join_wars_of(c_tag: String, ally: String) -> void:
	for w: Dictionary in wars:
		if ally in w["attackers"]:
			_add_to_side(w, "attackers", c_tag)
		elif ally in w["defenders"]:
			_add_to_side(w, "defenders", c_tag)
	wars_changed.emit()

# ------------------------------------------------------------------ ittifak, garanti, geçiş
func create_faction(leader: String) -> void:
	var c: Country = World.countries.get(leader)
	if c == null or c.faction != "":
		return
	Politics.factions[leader] = [leader]
	c.faction = leader
	diplomacy_changed.emit(leader)

func join_faction(tag: String, leader: String) -> void:
	var c: Country = World.countries.get(tag)
	var l: Country = World.countries.get(leader)
	if c == null or l == null or are_enemies(tag, leader):
		return
	if l.faction == "":
		create_faction(leader)
	if c.faction != "":
		leave_faction(tag)
	Politics.factions[l.faction].append(tag)
	c.faction = l.faction
	World.notify(tr("NOTE_JOINS_FACTION") % [c.display_name(), Politics.faction_display(l.faction)], "info")
	join_wars_of(tag, leader)
	diplomacy_changed.emit(tag)

func leave_faction(tag: String) -> void:
	var c: Country = World.countries.get(tag)
	if c == null or c.faction == "":
		return
	Politics.factions[c.faction].erase(tag)
	c.faction = ""

## Garanti ve ittifaka katılma için gerginlik eşikleri (türün klasiği): demokrasi %25 / %80 (savunma savaşında %50),
## bağlantısız %40 / %40; faşist ve komünist için eşik yok
func guarantee_block(c: Country) -> String:
	if c.ideology == "democratic" and World.world_tension < 25.0: return "DIPLO_ERR_TENSION"
	if c.ideology == "neutrality" and World.world_tension < 40.0: return "DIPLO_ERR_TENSION"
	return ""

func join_faction_block(c: Country) -> String:
	if c.ideology == "democratic" and World.world_tension < (50.0 if at_war(c.tag) else 80.0): return "DIPLO_ERR_TENSION"
	if c.ideology == "neutrality" and World.world_tension < 40.0: return "DIPLO_ERR_TENSION"
	return ""

func guarantee(g: String, t: String) -> void:
	var c: Country = World.countries.get(g)
	if c and not t in c.guarantees and t != g:
		c.guarantees.append(t)
		World.notify(tr("NOTE_GUARANTEE") % [c.display_name(), World.countries[t].display_name()], "info")
		diplomacy_changed.emit(g)

func grant_access(giver: String, receiver: String) -> void:
	var r: Country = World.countries.get(receiver)
	if r and not giver in r.access:
		r.access.append(giver)
		diplomacy_changed.emit(receiver)

## AI kabulü: aynı ideoloji ya da ortak düşman
func ai_accepts_invite(invitee: Country, leader: Country) -> bool:
	if invitee.ideology == leader.ideology:
		return true
	if invitee.ideology == "neutrality" and leader.ideology != "communism":
		return randf() < 0.5
	return false

## AI silah başına çağrıya uyar mı: aynı ideoloji (ya da %30 şans) ve karşı tarafta henüz sarsılmamış
## büyük güç yoksa hemen; varsa bekler, düşman büyük güç çökmeye başlayınca katılır
func ai_answers_call(c: Country, ally: String) -> bool:
	if c.ideology != World.countries[ally].ideology and randf() >= 0.3:
		return false
	if _strong_enemy_major(c, ally):
		waiting_to_join[c.tag] = ally
		return false
	return true

func _strong_enemy_major(c: Country, ally: String) -> bool:
	for e: String in enemies_of(ally):
		var ec: Country = World.countries[e]
		if ec.is_major() and ec.exists() and not are_enemies(e, c.tag) and ec.surrender_progress < OPPORTUNE_SURRENDER:
			return true
	return false

func _check_waiting() -> void:
	for tag: String in waiting_to_join.keys():
		var c: Country = World.countries.get(tag)
		var ally: String = waiting_to_join[tag]
		var a: Country = World.countries.get(ally)
		if c == null or a == null or not c.exists() or not a.exists() or not at_war(ally) \
				or (c.faction == "" or c.faction != a.faction):
			waiting_to_join.erase(tag)
			continue
		if not _strong_enemy_major(c, ally):
			waiting_to_join.erase(tag)
			join_wars_of(tag, ally)

# ------------------------------------------------------------------ teslim alma / barış
func _surrender_progress(c: Country) -> float:
	var total := 0.0
	var lost := 0.0
	var home: String = World.states[c.capital_state].adm0 if World.states.has(c.capital_state) else ""
	for sid in c.states:
		var colonial: bool = World.states[sid].adm0 != home
		for city in World.states[sid].cities:
			var vp := float(maxi(city.victory_points, 1)) * (0.25 if colonial else 1.0)
			total += vp
			var ctrl := World.controller_tag(city.province_id)
			if ctrl != c.tag and are_enemies(ctrl, c.tag):
				lost += vp
	var p := lost / maxf(total, 1.0)
	var cap := World.capital_province(c.tag)
	if cap > 0 and are_enemies(World.controller_tag(cap), c.tag):
		p += 0.1
	return clampf(p, 0.0, 1.0)

## Teslim sınırı (türün klasiği): %80; savaş desteği %50'nin altında −%30'a kadar düşer; ruhlar (surrender_limit); en az %20
func capitulation_threshold(c: Country) -> float:
	return clampf(CAPITULATION_BASE - maxf(0.5 - Politics.war_support(c), 0.0) * 0.6 + c.mod("surrender_limit"), 0.2, 0.95)

signal country_capitulated(tag: String)

func capitulate(c: Country) -> void:
	World.notify(tr("NOTE_CAPITULATED") % c.display_name(), "war")
	country_capitulated.emit(c.tag)
	if OS.has_environment("CAPDBG") and c.is_major():
		var lost: Array[String] = []
		for sid in c.states:
			for city in World.states[sid].cities:
				var ctl := World.controller_tag(city.province_id)
				if ctl != c.tag and are_enemies(ctl, c.tag) and city.victory_points >= 5:
					lost.append("%s:%s" % [city.name, ctl])
		print("CAPDBG %s %d surr=%.2f thr=%.2f states=%d enemies=%s lost=%s" % [c.tag, World.date_value(), c.surrender_progress, capitulation_threshold(c), c.states.size(), enemies_of(c.tag), lost.slice(0, 14)])
	var enemies := enemies_of(c.tag)
	# işgal edilen eyaletler işgalciye (bölgelerin çoğunu kim tutuyorsa)
	var gains := {}
	for sid in c.states.duplicate():
		var st: StateRegion = World.states[sid]
		var counts := {}
		for pid in st.provinces:
			var ctl := World.controller_tag(pid)
			if ctl != c.tag and ctl in enemies:
				counts[ctl] = int(counts.get(ctl, 0)) + 1
		var best := ""
		var n := 0
		for t: String in counts:
			if counts[t] > n:
				n = counts[t]
				best = t
		if best != "" and n * 2 >= st.provinces.size():
			World.transfer_state(sid, best)
			gains[best] = int(gains.get(best, 0)) + 1
	# geriye az şey kaldıysa tamamen ilhak
	if c.exists() and _remaining_vp_share(c) < 0.35 and not gains.is_empty():
		var winner := ""
		var m := 0
		for t: String in gains:
			if gains[t] > m:
				m = gains[t]
				winner = t
		World.annex(c.tag, winner)
	_leave_all_wars(c.tag)
	Military.remove_all(c.tag)
	Navy.remove_all(c.tag)
	Air.remove_all(c.tag)
	World.flush_ownership()
	_revert_control()
	wars_changed.emit()

var _start_vp := {}

func _remaining_vp_share(c: Country) -> float:
	var now := 0.0
	for sid in c.states:
		now += float(World.states[sid].victory_points())
	var start: float = _start_vp.get(c.tag, now)
	return now / maxf(start, 1.0)

## Ülkenin en eski süren savaşından bu yana geçen gün (savaşta değilse 99999)
func days_at_war(tag: String) -> int:
	var best := 99999
	for w: Dictionary in wars:
		if tag in w["attackers"] or tag in w["defenders"]:
			best = mini(best, World.day_count - int(w.get("start", World.day_count - 99999)))
	return best

func _leave_all_wars(tag: String) -> void:
	for w: Dictionary in wars:
		w["attackers"].erase(tag)
		w["defenders"].erase(tag)
	_cleanup_wars()

func _cleanup_wars() -> void:
	var ended := []
	for w: Dictionary in wars:
		if w["attackers"].is_empty() or w["defenders"].is_empty():
			ended.append(w)
	for w in ended:
		wars.erase(w)
		World.notify(tr("NOTE_WAR_ENDED"), "good")
	if not ended.is_empty():
		_revert_control()

## Artık düşman olmayan işgalcilerin kontrolündeki bölgeler sahibine döner
func _revert_control() -> void:
	for st: StateRegion in World.states.values():
		for pid in st.provinces:
			var ctl := World.controller_tag(pid)
			if ctl != st.owner and ctl != "" and not are_enemies(ctl, st.owner):
				World.set_controller(pid, st.owner)
			elif ctl != st.owner and are_allies(ctl, st.owner):
				World.set_controller(pid, st.owner)

func white_peace(a: String, b: String) -> void:
	for w: Dictionary in wars:
		var sa := "attackers" if a in w["attackers"] else ("defenders" if a in w["defenders"] else "")
		var sb := "attackers" if b in w["attackers"] else ("defenders" if b in w["defenders"] else "")
		if sa == "" or sb == "" or sa == sb:
			continue
		if w[sa][0] == a or w[sb][0] == b:
			w["attackers"].clear()
			w["defenders"].clear()
		else:
			w[sa].erase(a)
	_cleanup_wars()
	World.notify(tr("NOTE_WHITE_PEACE") % [World.countries[a].display_name(), World.countries[b].display_name()], "good")
	wars_changed.emit()

## Barış teklifi: AI, kaybediyorsa kabul eder
func offer_white_peace(a: String, b: String) -> bool:
	var cb: Country = World.countries.get(b)
	var ca: Country = World.countries.get(a)
	if cb == null or ca == null or not are_enemies(a, b):
		return false
	if b == World.player_tag:
		Politics.fire_event(cb, "white_peace", a)
		return true
	var accept := cb.surrender_progress > ca.surrender_progress + 0.15 or (cb.surrender_progress < 0.05 and ca.surrender_progress < 0.05 and randf() < 0.3)
	if accept:
		white_peace(a, b)
	return accept

# ------------------------------------------------------------------ günlük
func _on_day() -> void:
	var __t := Time.get_ticks_usec()
	_on_day_impl()
	GameClock.timed("diplomacy", __t)

func _on_day_impl() -> void:
	if not waiting_to_join.is_empty():
		_check_waiting()
	if _start_vp.is_empty():
		for c: Country in World.countries.values():
			var v := 0.0
			for sid in c.states:
				v += float(World.states[sid].victory_points())
			_start_vp[c.tag] = v
	for c: Country in World.countries.values():
		for t: String in c.justify_progress.keys():
			c.justify_progress[t] = int(c.justify_progress[t]) - 1
			if int(c.justify_progress[t]) <= 0:
				add_war_goal(c, t)
				World.world_tension = clampf(World.world_tension + 3.0, 0.0, 100.0)
				if c.tag == World.player_tag:
					World.notify(tr("NOTE_GOAL_READY") % World.countries[t].display_name(), "good")
	var caps := []
	for c: Country in World.countries.values():
		if not c.exists() or not at_war(c.tag):
			c.surrender_progress = 0.0
			continue
		c.surrender_progress = _surrender_progress(c)
		if c.surrender_progress >= capitulation_threshold(c):
			caps.append(c)
	for c: Country in caps:
		capitulate(c)
	if any_war():
		World.world_tension = clampf(World.world_tension + 0.05, 0.0, 100.0)
