class_name DiplomacyPanel
extends PanelContainer
## Diplomasi (O) — türün klasiği düzeni: hedef ülke başlığı (bayrak, lider, ideoloji, ittifak), durum hücreleri,
## eylem satırları (ne yapar, neden kapalı ipucunda). Hedef yoksa dünya gerginliği, savaşlar ve ittifaklar.

const IDEO_COLORS := {"democratic": Color("4a78c8"), "communism": Color("b83a2e"), "fascism": Color("8a6a3a"), "neutrality": Color("8a8a7a")}

var target := ""
var _v: VBoxContainer

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	visible = false
	_v = PanelLayout.frame(self, tr("DIPLO_TITLE"), "diplomacy", 500.0)
	Diplomacy.wars_changed.connect(func() -> void:
		if visible: refresh())
	Diplomacy.diplomacy_changed.connect(func(_t: String) -> void:
		if visible: refresh())
	World.daily_update.connect(func() -> void:
		if visible and World.day_count % 3 == 0: refresh())

func open() -> void:
	visible = true
	refresh()

func open_for(tag: String) -> void:
	target = tag
	open()

func close() -> void:
	visible = false
	target = ""

func refresh() -> void:
	for ch in _v.get_children():
		ch.queue_free()
	var me := World.player()
	var t: Country = World.countries.get(target)
	if t == null or t == me or not t.exists():
		PanelLayout.set_title(self, tr("DIPLO_TITLE"))
		_overview(me)
		return
	PanelLayout.set_title(self, tr("DIPLO_TITLE") + " — " + t.display_name())
	# başlık bloğu
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	_v.add_child(head)
	var flag := PanelContainer.new()
	flag.theme_type_variation = "SlotGold"
	var por := UiTheme.portrait(t)
	flag.custom_minimum_size = Vector2(72, 90) if por else Vector2(108, 72)
	var ft := TextureRect.new()
	ft.texture = por if por else FlagFactory.get_flag(t)
	ft.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ft.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if por else TextureRect.STRETCH_SCALE
	ft.clip_contents = true
	flag.add_child(ft)
	if por:
		var mf := TextureRect.new()
		mf.texture = FlagFactory.get_flag(t)
		mf.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mf.stretch_mode = TextureRect.STRETCH_SCALE
		mf.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		mf.offset_left = -30
		mf.offset_top = -20
		ft.add_child(mf)
	head.add_child(flag)
	var nb := VBoxContainer.new()
	nb.add_theme_constant_override("separation", 0)
	nb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nb)
	var n := UiTheme.make_label(t.display_name(), 22, UiTheme.ACCENT)
	n.add_theme_font_override("font", UiTheme.title_font())
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nb.add_child(n)
	nb.add_child(UiTheme.make_label(t.leader + (("  ·  " + t.party_name()) if t.party_name() != "" else ""), 15, UiTheme.TEXT))
	var il := UiTheme.make_label(tr("IDEOLOGY_" + t.ideology), 15, IDEO_COLORS[t.ideology].lightened(0.35))
	il.add_theme_font_override("font", UiTheme.bold_font())
	nb.add_child(il)
	var rel := tr("DIPLO_REL_NEUTRAL")
	var rel_col := UiTheme.TEXT_DIM
	if Diplomacy.are_enemies(me.tag, t.tag):
		rel = tr("DIPLO_REL_WAR")
		rel_col = UiTheme.BAD
	elif Diplomacy.are_allies(me.tag, t.tag):
		rel = tr("DIPLO_REL_ALLY")
		rel_col = UiTheme.GOOD
	var badge := PanelContainer.new()
	badge.theme_type_variation = "SlotBad" if rel_col == UiTheme.BAD else ("SlotGood" if rel_col == UiTheme.GOOD else "Slot")
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bl := UiTheme.make_label(rel.to_upper(), 14, rel_col)
	bl.add_theme_font_override("font", UiTheme.bold_font())
	badge.add_child(bl)
	head.add_child(badge)
	# durum hücreleri
	var cells := PanelLayout.info_cells(_v, [
		["army", tr("ARM_CELL_DIVS"), ""], ["construction", tr("DIP_CELL_STATES"), ""],
		["diplomacy", tr("DIP_CELL_FACTION"), ""], ["war_support", tr("POL_WS_SHORT"), ""]])
	cells[0].text = str(Military.country_divisions(t.tag).size())
	cells[1].text = str(t.states.size())
	cells[2].text = Politics.faction_display(t.faction) if t.faction != "" else "—"
	cells[2].text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	cells[2].custom_minimum_size.x = 70
	cells[3].text = "%d%%" % roundi(Politics.war_support(t) * 100)
	if Diplomacy.at_war(t.tag):
		PanelLayout.stat(_v, tr("DIP_SURRENDER"), "%d%% / %d%%" % [roundi(t.surrender_progress * 100), roundi(Diplomacy.capitulation_threshold(t) * 100)],
			tr("DIPLO_SURRENDER") % [roundi(t.surrender_progress * 100), roundi(Diplomacy.capitulation_threshold(t) * 100)], UiTheme.BAD)
		_v.add_child(PanelLayout.progress(t.surrender_progress / maxf(Diplomacy.capitulation_threshold(t), 0.01), UiTheme.BAD, 6.0))
	if me.justify_progress.has(t.tag):
		PanelLayout.stat(_v, tr("DIP_JUSTIFYING"), tr("DIP_DAYS_LEFT") % int(me.justify_progress[t.tag]), tr("DIPLO_JUSTIFYING") % int(me.justify_progress[t.tag]), UiTheme.ACCENT)
	if me.war_goals.has(t.tag):
		PanelLayout.stat(_v, tr("DIP_WAR_GOAL"), "✓", tr("DIPLO_HAS_GOAL"), UiTheme.BAD)
	# eylemler
	PanelLayout.section(_v, tr("DIP_ACTIONS"))
	_action("war_support", tr("DIPLO_JUSTIFY") % int(Diplomacy.JUSTIFY_COST), tr("TIP_JUSTIFY") % Diplomacy.JUSTIFY_DAYS, Diplomacy.can_justify(me, t), func() -> void: Diplomacy.justify(me, t))
	_action("battle", tr("DIPLO_DECLARE"), tr("TIP_DECLARE"), Diplomacy.can_declare(me, t), func() -> void: Diplomacy.declare_war(me.tag, t.tag))
	var g_err := "" if not t.tag in me.guarantees and not Diplomacy.are_enemies(me.tag, t.tag) else "DIPLO_ERR_ALREADY"
	if g_err == "":
		g_err = Diplomacy.guarantee_block(me)
	_action("stability", tr("DIPLO_GUARANTEE"), tr("TIP_GUARANTEE"), g_err, func() -> void: Diplomacy.guarantee(me.tag, t.tag))
	var a_err := "" if not t.tag in me.access and not Diplomacy.are_enemies(me.tag, t.tag) else "DIPLO_ERR_ALREADY"
	_action("army", tr("DIPLO_ACCESS"), tr("TIP_ACCESS"), a_err, func() -> void:
		if t.ideology == me.ideology or Diplomacy.are_allies(me.tag, t.tag) or randf() < 0.3:
			Diplomacy.grant_access(t.tag, me.tag)
			World.notify(tr("NOTE_ACCESS_OK") % t.display_name(), "good")
		else:
			World.notify(tr("NOTE_ACCESS_NO") % t.display_name(), "bad"))
	var inv_err := "" if me.faction == me.tag and t.faction == "" and not Diplomacy.are_enemies(me.tag, t.tag) else ("DIPLO_ERR_NO_FACTION" if me.faction != me.tag else "DIPLO_ERR_ALREADY")
	_action("diplomacy", tr("DIPLO_INVITE"), tr("TIP_INVITE"), inv_err, func() -> void:
		if Diplomacy.ai_accepts_invite(t, me):
			Diplomacy.join_faction(t.tag, me.tag)
		else:
			World.notify(tr("NOTE_INVITE_NO") % t.display_name(), "bad"))
	var p_err := "" if Diplomacy.are_enemies(me.tag, t.tag) else "DIPLO_ERR_INVALID"
	_action("political_power", tr("DIPLO_PEACE"), tr("TIP_PEACE"), p_err, func() -> void:
		if not Diplomacy.offer_white_peace(me.tag, t.tag):
			World.notify(tr("NOTE_PEACE_NO") % t.display_name(), "bad"))

func _action(icon: String, text: String, tip: String, err: String, fn: Callable) -> void:
	var col := PanelLayout.row(_v, UiTheme.icon(icon), text, tip if err == "" else "⚠ " + tr(err), tip + ("" if err == "" else "\n\n" + tr(err)))
	if err != "":
		(col.get_child(col.get_child_count() - 1) as Label).add_theme_color_override("font_color", Color(0.85, 0.55, 0.45))
	PanelLayout.row_action(col, PanelLayout.small_button(tr("DIP_DO"), func() -> void:
		fn.call()
		refresh(), err == "", tip))

func _flags(tags: Array, side := 26) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 3)
	f.add_theme_constant_override("v_separation", 3)
	for tg: String in tags:
		var c: Country = World.countries.get(tg)
		if c == null:
			continue
		var tr_ := TextureRect.new()
		tr_.texture = FlagFactory.get_flag(c)
		tr_.custom_minimum_size = Vector2(side * 1.5, side)
		tr_.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr_.stretch_mode = TextureRect.STRETCH_SCALE
		tr_.tooltip_text = "%s  ·  %s %d%%" % [c.display_name(), tr("DIP_SURRENDER"), roundi(c.surrender_progress * 100)]
		f.add_child(tr_)
	return f

func _overview(me: Country) -> void:
	PanelLayout.section(_v, tr("DIP_WORLD"))
	var tension := World.world_tension / 100.0
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 8)
	trow.add_child(UiTheme.icon_texture(UiTheme.icon("war_support"), 30))
	var tl := UiTheme.make_label(tr("DIPLO_TENSION") % roundi(World.world_tension), 17, UiTheme.BAD if tension >= 0.5 else UiTheme.TEXT)
	tl.add_theme_font_override("font", UiTheme.bold_font())
	trow.add_child(tl)
	var bar := PanelLayout.progress(tension, UiTheme.BAD if tension >= 0.5 else Color(0.9, 0.75, 0.3), 8.0)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	trow.add_child(bar)
	trow.tooltip_text = tr("DIP_TENSION_TIP")
	trow.mouse_filter = Control.MOUSE_FILTER_STOP
	_v.add_child(trow)
	PanelLayout.empty(_v, tr("DIPLO_HINT"))
	PanelLayout.section(_v, tr("DIPLO_WARS"))
	if Diplomacy.wars.is_empty():
		PanelLayout.empty(_v, tr("DIPLO_NO_WARS"))
	for w: Dictionary in Diplomacy.wars:
		var pc := PanelContainer.new()
		pc.theme_type_variation = "Row"
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		pc.add_child(hb)
		var a := _flags(w["attackers"])
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(a)
		hb.add_child(UiTheme.icon_texture(UiTheme.icon("battle"), 24))
		var d := _flags(w["defenders"])
		d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		d.alignment = FlowContainer.ALIGNMENT_END
		hb.add_child(d)
		_v.add_child(pc)
	PanelLayout.section(_v, tr("DIPLO_FACTIONS"))
	for leader: String in Politics.factions:
		var members: Array = Politics.factions[leader]
		if members.is_empty():
			continue
		var col := PanelLayout.row(_v, null, Politics.faction_display(leader), "")
		col.add_child(_flags(members, 22))
	if me.faction == "":
		var b := PanelLayout.small_button(tr("DIPLO_CREATE_FACTION"), func() -> void:
			Diplomacy.create_faction(me.tag)
			refresh(), true, tr("TIP_CREATE_FACTION"))
		b.custom_minimum_size.y = 36
		_v.add_child(b)
