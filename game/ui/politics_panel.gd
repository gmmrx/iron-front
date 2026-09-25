class_name PoliticsPanel
extends PanelContainer
## Siyaset ekranı: siyasi güç ve yasalar (askerlik, ekonomi, ticaret).

var _pp: Label
var _groups_box: VBoxContainer
var _extra: VBoxContainer

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(12, 120)
	custom_minimum_size = Vector2(520, 0)
	visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	var title := UiTheme.make_label(tr("POLITICS_TITLE"), 24, UiTheme.ACCENT)
	title.add_theme_font_override("font", UiTheme.title_font())
	v.add_child(title)
	_pp = UiTheme.make_label("", 17, UiTheme.TEXT)
	v.add_child(_pp)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(520, 680)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)
	v.add_child(scroll)
	content.add_child(HSeparator.new())
	_extra = VBoxContainer.new()
	_extra.add_theme_constant_override("separation", 8)
	content.add_child(_extra)
	content.add_child(HSeparator.new())
	_groups_box = VBoxContainer.new()
	_groups_box.add_theme_constant_override("separation", 10)
	content.add_child(_groups_box)
	Politics.politics_changed.connect(func(t: String) -> void:
		if visible and t == World.player_tag: refresh())
	World.daily_update.connect(func() -> void:
		if visible: refresh())
	Economy.laws_changed.connect(func(_t: String) -> void:
		if visible: refresh())

func open() -> void:
	visible = true
	refresh()

func close() -> void:
	visible = false

func refresh() -> void:
	var c := World.player()
	if c == null:
		return
	_pp.text = tr("POLITICS_PP") % [int(c.political_power), c.daily_political_power_gain(), int(Economy.law_change_cost)]
	_refresh_extra(c)
	for ch in _groups_box.get_children():
		ch.queue_free()
	for g: String in Economy.law_groups:
		_groups_box.add_child(UiTheme.make_label(Economy.group_name(g).to_upper(), 16, UiTheme.TEXT_DIM))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 6)
		for law: String in Economy.law_groups[g]["laws"]:
			var b := Button.new()
			b.text = Economy.law_name(g, law)
			b.icon = UiTheme.law_icon(law)
			b.expand_icon = true
			b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.add_theme_constant_override("icon_max_width", 58)
			b.custom_minimum_size = Vector2(238, 72)
			b.focus_mode = Control.FOCUS_NONE
			b.toggle_mode = true
			var current: bool = c.laws.get(g) == law
			b.set_pressed_no_signal(current)
			b.disabled = not current and not Economy.can_change_law(c, g, law)
			b.tooltip_text = _effects(Economy.law_def(g, law))
			b.add_theme_font_size_override("font_size", 15)
			b.pressed.connect(func() -> void:
				if not current:
					Economy.change_law(c, g, law)
				refresh())
			flow.add_child(b)
		_groups_box.add_child(flow)

func _effects(d: Dictionary) -> String:
	var lines := []
	for k: String in ["manpower", "consumer_goods", "factory_output", "construction_speed", "export"]:
		if d.has(k):
			var v := float(d[k]) * 100.0
			var sign := "+" if v > 0 and k in ["factory_output", "construction_speed"] else ""
			lines.append("%s: %s%s%%" % [tr("EFFECT_" + k), sign, str(snappedf(v, 0.1))])
	return "\n".join(lines)

func _refresh_extra(c: Country) -> void:
	for ch in _extra.get_children():
		ch.queue_free()
	# ideoloji popülerliği
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 0)
	var cols := {"democratic": Color("4a78c8"), "communism": Color("b83a2e"), "fascism": Color("6b5a3a"), "neutrality": Color("8a8a7a")}
	for ideo: String in ["democratic", "communism", "fascism", "neutrality"]:
		var r := ColorRect.new()
		r.color = cols[ideo]
		r.custom_minimum_size = Vector2(maxf(float(c.popularity.get(ideo, 0.0)) * 440.0, 1.0), 14)
		r.tooltip_text = "%s: %%%d" % [tr("IDEOLOGY_" + ideo), roundi(float(c.popularity.get(ideo, 0.0)) * 100)]
		bar.add_child(r)
	_extra.add_child(UiTheme.make_label(tr("POL_POPULARITY"), 15, UiTheme.TEXT_DIM))
	_extra.add_child(bar)
	_extra.add_child(UiTheme.make_label(tr("POL_STATS") % [roundi(Politics.stability(c) * 100), roundi(Politics.war_support(c) * 100), roundi(World.world_tension)], 16))
	# milli ruhlar
	_extra.add_child(UiTheme.make_label(tr("POL_SPIRITS"), 15, UiTheme.TEXT_DIM))
	var sf := HFlowContainer.new()
	sf.add_theme_constant_override("h_separation", 6)
	for sp in c.spirits:
		var def: Dictionary = Politics.spirits.get(sp, Politics.decisions.get(sp, {}))
		if def.is_empty():
			continue
		var l := Button.new()
		l.text = Politics.loc(def["name"])
		l.icon = UiTheme.spirit_icon(sp)
		l.expand_icon = true
		l.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.add_theme_constant_override("icon_max_width", 58)
		l.custom_minimum_size = Vector2(238, 72)
		l.focus_mode = Control.FOCUS_NONE
		l.tooltip_text = Politics.loc(def["name"]) + "\n" + Politics.describe_mods(def.get("mods", {}))
		l.add_theme_font_size_override("font_size", 14)
		sf.add_child(l)
	_extra.add_child(sf)
	# danışmanlar
	_extra.add_child(UiTheme.make_label(tr("POL_ADVISORS") % [c.advisors.size(), Politics.max_advisors, int(Politics.advisor_cost)], 15, UiTheme.TEXT_DIM))
	var af := HFlowContainer.new()
	af.add_theme_constant_override("h_separation", 6)
	af.add_theme_constant_override("v_separation", 6)
	for id: String in Politics.advisor_defs:
		var def: Dictionary = Politics.advisor_defs[id]
		var b := Button.new()
		b.text = Politics.loc(def["name"])
		b.icon = UiTheme.advisor_icon(id)
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_constant_override("icon_max_width", 58)
		b.custom_minimum_size = Vector2(238, 72)
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 14)
		var hired := id in c.advisors
		b.set_pressed_no_signal(hired)
		b.disabled = not hired and not Politics.can_hire(c, id)
		b.tooltip_text = Politics.loc(def["name"]) + "\n" + Politics.describe_mods(def["mods"]) + "\n\n" + (tr("TIP_ADVISOR_DISMISS") if hired else tr("TIP_ADVISOR_HIRE") % int(Politics.advisor_cost))
		b.pressed.connect(func() -> void:
			if hired: Politics.dismiss(c, id)
			else: Politics.hire(c, id)
			refresh())
		af.add_child(b)
	_extra.add_child(af)
	# kararlar
	_extra.add_child(UiTheme.make_label(tr("POL_DECISIONS"), 15, UiTheme.TEXT_DIM))
	var df := HFlowContainer.new()
	df.add_theme_constant_override("h_separation", 6)
	for id: String in Politics.decisions:
		var def: Dictionary = Politics.decisions[id]
		var b := Button.new()
		var active := c.decisions_active.has(id)
		b.text = "%s (%d)" % [Politics.loc(def["name"]), int(def["cost"])] if not active else "%s ✓" % Politics.loc(def["name"])
		b.icon = UiTheme.decision_icon(id)
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_constant_override("icon_max_width", 58)
		b.custom_minimum_size = Vector2(238, 72)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 14)
		b.disabled = not Politics.can_take_decision(c, id)
		b.tooltip_text = "%s\n%s\n%s" % [Politics.loc(def["name"]), Politics.describe_mods(def["mods"]), tr("TIP_DECISION") % [int(def["cost"]), int(def["days"])]]
		b.pressed.connect(func() -> void:
			Politics.take_decision(c, id)
			refresh())
		df.add_child(b)
	_extra.add_child(df)
