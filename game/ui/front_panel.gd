class_name FrontPanel
extends PanelContainer
## Cephe paneli (ekranın altında): oyuncu cephe çizgisine (bizim tarafın ve düşmanın elindeki komşu bölgelerin sınırı,
## haritada yerin altından yanan damar) tıklayınca açılır. İki bölge, oradaki birlikler, süren muharebe ve hava
## üstünlüğü; buradan hava desteği ya da hava üstünlüğü görevi verilir: menzildeki boştaki kanat gider (üssü yetmiyorsa
## menzili yeten kendi üssüne geçer: Air.assign). Açıkken saniyede bir yenilenir; cephe kalkarsa kapanır.

const WIDTH := 640.0

var ours := 0                        ## cephenin bizim taraftaki bölgesi
var theirs := 0                      ## düşmanın elindeki komşu bölge
var _title: Label
var _cells: Array[Label] = []
var _battle: VBoxContainer
var _cas: Button
var _sup: Button
var _timer := 0.0

func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	custom_minimum_size.x = WIDTH
	offset_left = -WIDTH * 0.5
	offset_right = WIDTH * 0.5
	offset_top = 0
	offset_bottom = -16
	mouse_filter = Control.MOUSE_FILTER_STOP
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)
	# başlık: yan panellerinkiyle aynı şerit, ikon ve kapat
	var head := PanelContainer.new()
	head.theme_type_variation = "Header"
	root.add_child(head)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	head.add_child(hb)
	hb.add_child(UiTheme.icon_texture(UiTheme.icon("battle"), 30))
	_title = UiTheme.make_label("", 20, UiTheme.ACCENT)
	_title.add_theme_font_override("font", UiTheme.title_font())
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.clip_text = true
	hb.add_child(_title)
	hb.add_child(UiTheme.icon_button("close", tr("TIP_CLOSE"), close, 28))
	_cells = PanelLayout.info_cells(root, [["army", tr("FRONT_OURS"), tr("TIP_FRONT_OURS")],
		["army", tr("FRONT_THEIRS"), tr("TIP_FRONT_THEIRS")], ["air", tr("FRONT_AIR"), tr("TIP_FRONT_AIR")]])
	PanelLayout.section(root, tr("FRONT_BATTLE"))
	_battle = VBoxContainer.new()
	_battle.add_theme_constant_override("separation", 4)
	root.add_child(_battle)
	var acts := HBoxContainer.new()
	acts.alignment = BoxContainer.ALIGNMENT_CENTER
	acts.add_theme_constant_override("separation", 10)
	root.add_child(acts)
	_cas = PanelLayout.small_button(tr("FRONT_CAS"), func() -> void: _send(AirWing.Mission.CAS))
	_sup = PanelLayout.small_button(tr("FRONT_SUPERIORITY"), func() -> void: _send(AirWing.Mission.SUPERIORITY))
	acts.add_child(_cas)
	acts.add_child(_sup)

## Oyuncuya göre ülkenin tarafı: 1 oyuncu ya da müttefiki, 2 oyuncuyla savaşta, 0 öbürleri (haritadaki cephe çizgisiyle
## aynı; izleyici kipinde oyuncu yerine izlenen savaşın saldıranı: Game.front_tag)
static func side(tag: String) -> int:
	var me := Game.front_tag()
	if tag == "" or me == "":
		return 0
	if tag == me or Diplomacy.are_allies(me, tag):
		return 1
	if Diplomacy.are_enemies(me, tag):
		return 2
	return 0

func show_front(a: int, b: int) -> void:
	ours = a
	theirs = b
	_timer = 0.0
	refresh()
	if not visible:
		visible = true
		Audio.panel(true)

func close() -> void:
	if visible:
		visible = false
		Audio.panel(false)

func _process(delta: float) -> void:
	if not visible:
		return
	_timer += delta
	if _timer >= 1.0:
		_timer = 0.0
		refresh()

## Hava görevinin hedefi: muharebe varsa muharebenin bölgesi, yoksa düşmanın bölgesi
func target() -> int:
	if Military.battles.has(theirs):
		return theirs
	if Military.battles.has(ours):
		return ours
	return theirs

func refresh() -> void:
	# bölgelerden biri el değiştirdiyse burası artık cephe değil
	if side(World.controller_tag(ours)) != 1 or side(World.controller_tag(theirs)) != 2:
		close()
		return
	var me := World.player_tag
	_title.text = tr("FRONT_TITLE") % [Air.zone_name(ours), Air.zone_name(theirs)]
	_cells[0].text = _force(ours, 1)
	_cells[1].text = _force(theirs, 2) if Military.is_visible(theirs) else "?"
	_cells[2].text = "%d%%" % roundi(Air.superiority(theirs, me) * 100.0)
	for ch in _battle.get_children():
		ch.queue_free()
	var bp := target()
	if Military.battles.has(bp):
		var b: Dictionary = Military.battles[bp]
		var att: Division = (b["attackers"] as Array)[0]
		var dfn: Division = (b["defenders"] as Array)[0]
		var ac: Country = World.countries.get(att.owner)
		var dc: Country = World.countries.get(dfn.owner)
		var ar := float(b["att_ratio"])
		var dr := float(b["def_ratio"])
		PanelLayout.bar_row(_battle, tr("FRONT_ATTACKER") % (ac.display_name() if ac else att.owner), ar, "%d%%" % roundi(ar * 100.0),
			UiTheme.GOOD if side(att.owner) == 1 else UiTheme.BAD, tr("TIP_FRONT_RATIO"))
		PanelLayout.bar_row(_battle, tr("FRONT_DEFENDER") % (dc.display_name() if dc else dfn.owner), dr, "%d%%" % roundi(dr * 100.0),
			UiTheme.GOOD if side(dfn.owner) == 1 else UiTheme.BAD, tr("TIP_FRONT_RATIO"))
	else:
		PanelLayout.empty(_battle, tr("FRONT_NO_BATTLE"))
	for pair: Array in [[_cas, AirWing.Mission.CAS], [_sup, AirWing.Mission.SUPERIORITY]]:
		var btn: Button = pair[0]
		var w := pick_wing(me, bp, pair[1])
		btn.disabled = w == null
		btn.tooltip_text = (tr("TIP_FRONT_SEND") % [w.name, tr("AIR_MISSION_%d" % int(pair[1]))]) if w else tr("FRONT_NO_WING")

## Bölgedeki tarafın tümenleri: "sayı · ortalama güç"
func _force(pid: int, want_side: int) -> String:
	var n := 0
	var strength := 0.0
	for d: Division in Military.by_province.get(pid, []):
		if side(d.owner) == want_side and not Military.hidden(d):
			n += 1
			strength += d.strength
	return "—" if n == 0 else "%d · %d%%" % [n, roundi(strength / n * 100.0)]

## Göreve gidecek kanat: boştaki (ya da aynı görevle başka yerdeki) kanatlardan, menzili yeten üssü en yakın olan; yakın
## destekte yakın destek uçağı, sonra bombardıman; üstünlükte avcı önce. Başka görevdeki kanat alınmaz, buradaki görevi zaten
## yapan kanat yeniden gönderilmez.
static func pick_wing(tag: String, pid: int, m: AirWing.Mission) -> AirWing:
	var p := World.province(pid)
	if p == null:
		return null
	var best: AirWing = null
	var best_score := INF
	for w in Air.wings_of(tag):
		if w.planes <= 0 or (w.on_mission() and w.mission != m):
			continue
		if w.on_mission() and Air.covers(w, pid):
			continue
		var base := w.base if Air.in_range(w, pid) else Air.base_for(w, pid)
		if base == 0:
			continue
		var pref := 0.0
		if m == AirWing.Mission.CAS:
			pref = 0.0 if w.type == "cas" else (300.0 if w.type == "bomber" else 900.0)
		else:
			pref = 0.0 if w.type == "fighter" else 900.0
		var score := Air.distance_km(Air.base_pos(base), p.center) + pref + (3000.0 if w.on_mission() else 0.0)
		if score < best_score:
			best_score = score
			best = w
	return best

func _send(m: AirWing.Mission) -> void:
	var tgt := target()
	var w := pick_wing(World.player_tag, tgt, m)
	if w == null:
		World.notify(tr("FRONT_NO_WING"), "bad")
		return
	var err := Air.assign(w, tgt, m)
	if err != "":
		World.notify(tr(err), "bad")
		return
	Audio.play("select_air", 150)
	World.notify(tr("AIR_ORDER_OK") % [w.name, tr("AIR_MISSION_%d" % int(w.mission)), Air.zone_name(w.zone)], "info")
	refresh()
