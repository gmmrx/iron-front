class_name DiplomacyPanel
extends PanelContainer
## Diplomasi (O): hedef ülkeyle eylemler; hedef yoksa savaşlar ve ittifaklar özeti.

var target := ""
var _v: VBoxContainer

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(12, 120)
	custom_minimum_size = Vector2(480, 0)
	visible = false
	_v = VBoxContainer.new()
	_v.add_theme_constant_override("separation", 8)
	add_child(_v)
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
		_overview(me)
		return
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	var flag := TextureRect.new()
	flag.texture = FlagFactory.get_flag(t)
	flag.custom_minimum_size = Vector2(66, 44)
	flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flag.stretch_mode = TextureRect.STRETCH_SCALE
	head.add_child(flag)
	var nb := VBoxContainer.new()
	var n := UiTheme.make_label(t.display_name(), 24, UiTheme.ACCENT)
	n.add_theme_font_override("font", UiTheme.title_font())
	nb.add_child(n)
	nb.add_child(UiTheme.make_label("%s — %s" % [t.leader, tr("IDEOLOGY_" + t.ideology)], 15, UiTheme.TEXT_DIM))
	nb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nb)
	head.add_child(UiTheme.icon_button("close", tr("TIP_CLOSE"), close))
	_v.add_child(head)
	_v.add_child(HSeparator.new())
	var rel := tr("DIPLO_REL_NEUTRAL")
	if Diplomacy.are_enemies(me.tag, t.tag): rel = tr("DIPLO_REL_WAR")
	elif Diplomacy.are_allies(me.tag, t.tag): rel = tr("DIPLO_REL_ALLY")
	var info := tr("DIPLO_INFO") % [rel, Politics.faction_display(t.faction) if t.faction != "" else "—", Military.country_divisions(t.tag).size(), t.states.size()]
	if Diplomacy.at_war(t.tag):
		info += "\n" + tr("DIPLO_SURRENDER") % [roundi(t.surrender_progress * 100), roundi(Diplomacy.capitulation_threshold(t) * 100)]
	if me.justify_progress.has(t.tag):
		info += "\n" + tr("DIPLO_JUSTIFYING") % int(me.justify_progress[t.tag])
	if me.war_goals.has(t.tag):
		info += "\n" + tr("DIPLO_HAS_GOAL")
	_v.add_child(UiTheme.make_label(info, 16))
	_v.add_child(HSeparator.new())
	_action(tr("DIPLO_JUSTIFY") % int(Diplomacy.JUSTIFY_COST), tr("TIP_JUSTIFY") % Diplomacy.JUSTIFY_DAYS, Diplomacy.can_justify(me, t), func() -> void: Diplomacy.justify(me, t))
	_action(tr("DIPLO_DECLARE"), tr("TIP_DECLARE"), Diplomacy.can_declare(me, t), func() -> void: Diplomacy.declare_war(me.tag, t.tag))
	var g_err := "" if not t.tag in me.guarantees and not Diplomacy.are_enemies(me.tag, t.tag) else "DIPLO_ERR_ALREADY"
	_action(tr("DIPLO_GUARANTEE"), tr("TIP_GUARANTEE"), g_err, func() -> void: Diplomacy.guarantee(me.tag, t.tag))
	var a_err := "" if not t.tag in me.access and not Diplomacy.are_enemies(me.tag, t.tag) else "DIPLO_ERR_ALREADY"
	_action(tr("DIPLO_ACCESS"), tr("TIP_ACCESS"), a_err, func() -> void:
		if t.ideology == me.ideology or Diplomacy.are_allies(me.tag, t.tag) or randf() < 0.3:
			Diplomacy.grant_access(t.tag, me.tag)
			World.notify(tr("NOTE_ACCESS_OK") % t.display_name(), "good")
		else:
			World.notify(tr("NOTE_ACCESS_NO") % t.display_name(), "bad"))
	var inv_err := "" if me.faction == me.tag and t.faction == "" and not Diplomacy.are_enemies(me.tag, t.tag) else ("DIPLO_ERR_NO_FACTION" if me.faction != me.tag else "DIPLO_ERR_ALREADY")
	_action(tr("DIPLO_INVITE"), tr("TIP_INVITE"), inv_err, func() -> void:
		if Diplomacy.ai_accepts_invite(t, me):
			Diplomacy.join_faction(t.tag, me.tag)
		else:
			World.notify(tr("NOTE_INVITE_NO") % t.display_name(), "bad"))
	var p_err := "" if Diplomacy.are_enemies(me.tag, t.tag) else "DIPLO_ERR_INVALID"
	_action(tr("DIPLO_PEACE"), tr("TIP_PEACE"), p_err, func() -> void:
		if not Diplomacy.offer_white_peace(me.tag, t.tag):
			World.notify(tr("NOTE_PEACE_NO") % t.display_name(), "bad"))

func _action(text: String, tip: String, err: String, fn: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = err != ""
	b.tooltip_text = tip + ("" if err == "" else "\n\n" + tr(err))
	b.pressed.connect(func() -> void:
		fn.call()
		refresh())
	_v.add_child(b)

func _overview(me: Country) -> void:
	var head := HBoxContainer.new()
	var title := UiTheme.make_label(tr("DIPLO_TITLE"), 24, UiTheme.ACCENT)
	title.add_theme_font_override("font", UiTheme.title_font())
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UiTheme.icon_button("close", tr("TIP_CLOSE"), close))
	_v.add_child(head)
	_v.add_child(UiTheme.make_label(tr("DIPLO_TENSION") % roundi(World.world_tension), 16))
	_v.add_child(UiTheme.make_label(tr("DIPLO_HINT"), 15, UiTheme.TEXT_DIM))
	_v.add_child(HSeparator.new())
	_v.add_child(UiTheme.make_label(tr("DIPLO_WARS"), 17, UiTheme.TEXT_DIM))
	if Diplomacy.wars.is_empty():
		_v.add_child(UiTheme.make_label(tr("DIPLO_NO_WARS"), 15))
	for w: Dictionary in Diplomacy.wars:
		var fmt := func(side: Array) -> String:
			return ", ".join(side.map(func(tg: String) -> String:
				var c: Country = World.countries[tg]
				return "%s (%%%d)" % [c.display_name(), roundi(c.surrender_progress * 100)]))
		var l := UiTheme.make_label("⚔ " + fmt.call(w["attackers"]) + "\n    vs " + fmt.call(w["defenders"]), 15)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 440
		_v.add_child(l)
	_v.add_child(HSeparator.new())
	_v.add_child(UiTheme.make_label(tr("DIPLO_FACTIONS"), 17, UiTheme.TEXT_DIM))
	for leader: String in Politics.factions:
		var members: Array = Politics.factions[leader]
		if members.is_empty():
			continue
		var l := UiTheme.make_label("%s: %s" % [Politics.faction_display(leader), ", ".join(members.map(func(tg: String) -> String: return World.countries[tg].display_name()))], 15)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 440
		_v.add_child(l)
	if me.faction == "":
		var b := Button.new()
		b.text = tr("DIPLO_CREATE_FACTION")
		b.tooltip_text = tr("TIP_CREATE_FACTION")
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func() -> void:
			Diplomacy.create_faction(me.tag)
			refresh())
		_v.add_child(b)
