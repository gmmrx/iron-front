class_name PoliticsPanel
extends PanelContainer
## Hükümet ekranı (Q) — türün klasiği düzeni: lider ve iktidar partisi, ideoloji pastası, siyasi güç / istikrar /
## savaş desteği (dökümlü ipuçları), milli ruhlar, üç yasa yuvası + seçili grubun yasaları, danışmanlar, kararlar.

signal focus_requested

const IDEO_COLORS := {"democratic": Color("4a78c8"), "communism": Color("b83a2e"), "fascism": Color("8a6a3a"), "neutrality": Color("8a8a7a")}
const IDEO_ORDER := ["democratic", "communism", "fascism", "neutrality"]
const EFFECT_KEYS := ["manpower", "consumer_goods", "factory_output", "construction_speed", "mil_construction_speed",
	"research_speed", "export", "training_time", "recruitable_population"]

var _body: VBoxContainer
var _law_group := "conscription"

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	visible = false
	_body = PanelLayout.frame(self, tr("POLITICS_TITLE"), "politics", 520.0)
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
	for ch in _body.get_children():
		ch.queue_free()
	_leader_block(c)
	_gauges(c)
	_spirits(c)
	_laws(c)
	_advisors(c)
	_decisions(c)
	var fb := Button.new()
	fb.text = tr("POL_OPEN_FOCUS")
	fb.icon = UiTheme.icon("politics")
	fb.expand_icon = true
	fb.add_theme_constant_override("icon_max_width", 22)
	fb.custom_minimum_size.y = 40
	fb.focus_mode = Control.FOCUS_NONE
	fb.pressed.connect(func() -> void: focus_requested.emit())
	_body.add_child(fb)

# ------------------------------------------------------------------ lider, parti, ideoloji
func _leader_block(c: Country) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_body.add_child(row)
	var flag := PanelContainer.new()
	flag.theme_type_variation = "SlotGold"
	var por := UiTheme.portrait(c)
	flag.custom_minimum_size = Vector2(96, 120) if por else Vector2(132, 90)
	var ft := TextureRect.new()
	ft.texture = por if por else FlagFactory.get_flag(c)
	ft.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ft.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if por else TextureRect.STRETCH_SCALE
	ft.clip_contents = true
	flag.add_child(ft)
	if por:
		var mf := TextureRect.new()
		mf.texture = FlagFactory.get_flag(c)
		mf.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mf.stretch_mode = TextureRect.STRETCH_SCALE
		mf.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		mf.offset_left = -36
		mf.offset_top = -24
		ft.add_child(mf)
	row.add_child(flag)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var name := UiTheme.make_label(c.leader, 20, UiTheme.ACCENT)
	name.add_theme_font_override("font", UiTheme.title_font())
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(name)
	info.add_child(UiTheme.make_label(c.party_name() if c.party_name() != "" else tr("POL_NO_PARTY"), 16, UiTheme.TEXT))
	var ideo := UiTheme.make_label(tr("IDEOLOGY_" + c.ideology), 16, IDEO_COLORS[c.ideology].lightened(0.35))
	ideo.add_theme_font_override("font", UiTheme.bold_font())
	info.add_child(ideo)
	var el := tr("POL_NO_ELECTIONS")
	if c.election_months > 0 and c.next_election > 0:
		el = tr("POL_NEXT_ELECTION") % [_fmt_date(c.next_election), c.election_months / 12]
	info.add_child(UiTheme.make_label(el, 15, UiTheme.TEXT_DIM))
	# pasta + açıklama
	var pie := PanelLayout.Pie.new(88.0)
	var parts := []
	var tip := tr("POL_POPULARITY") + "\n"
	for i in IDEO_ORDER:
		var v := float(c.popularity.get(i, 0.0))
		parts.append([v, IDEO_COLORS[i]])
		tip += "%s: %d%%\n" % [tr("IDEOLOGY_" + i), roundi(v * 100)]
	tip += "\n" + tr("POL_POP_TIP") % roundi(Politics.party_stability_bonus(c) * 100)
	pie.set_parts(parts)
	pie.tooltip_text = tip
	row.add_child(pie)
	var legend := VBoxContainer.new()
	legend.add_theme_constant_override("separation", 0)
	legend.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for i in IDEO_ORDER:
		var lr := HBoxContainer.new()
		var sw := ColorRect.new()
		sw.color = IDEO_COLORS[i]
		sw.custom_minimum_size = Vector2(10, 10)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		lr.add_child(sw)
		var lab := UiTheme.make_label("%d%%" % roundi(float(c.popularity.get(i, 0.0)) * 100), 15, UiTheme.ACCENT if i == c.ideology else UiTheme.TEXT)
		lab.add_theme_font_override("font", UiTheme.bold_font())
		lr.add_child(lab)
		legend.add_child(lr)
	legend.tooltip_text = tip
	legend.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(legend)

# ------------------------------------------------------------------ göstergeler
func _gauges(c: Country) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_body.add_child(row)
	var s := Politics.stability(c)
	var w := Politics.war_support(c)
	_gauge(row, "political_power", tr("POL_PP_SHORT"), "%d" % int(c.political_power), "+%.2f/%s" % [c.daily_political_power_gain(), tr("DAY_SHORT")],
		tr("TIP_POLITICAL_POWER") % [c.daily_political_power_gain()], -1.0)
	var st_tip := tr("POL_STAB_BREAKDOWN") % [roundi(c.stability * 100), _signed(c.mod("stability")), _signed(Politics.party_stability_bonus(c)),
		roundi(s * 100), _signed(Politics.stability_factory_mod(c)), _signed(Politics.stability_pp_mod(c))]
	_gauge(row, "stability", tr("POL_STAB_SHORT"), "%d%%" % roundi(s * 100), "", st_tip, s)
	var ws_tip := tr("POL_WS_BREAKDOWN") % [roundi(c.war_support * 100), _signed(c.mod("war_support")), _signed(Politics.tension_war_support()),
		_signed(Politics.war_state_support(c)), roundi(w * 100), roundi(Diplomacy.capitulation_threshold(c) * 100)]
	_gauge(row, "war_support", tr("POL_WS_SHORT"), "%d%%" % roundi(w * 100), "", ws_tip, w)

func _fmt_date(d: int) -> String:
	return "%d %s %d" % [d % 100, tr("MONTH_%d" % (d / 100 % 100)), d / 10000]

func _signed(v: float) -> String:
	return ("+" if v >= 0 else "") + "%d%%" % roundi(v * 100)

func _gauge(parent: Container, icon: String, title: String, value: String, sub: String, tip: String, ratio: float) -> void:
	var cell := PanelContainer.new()
	cell.theme_type_variation = "Slot"
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.tooltip_text = tip
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(cell)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(hb)
	var tex := UiTheme.icon(icon)
	if tex:
		hb.add_child(UiTheme.icon_texture(tex, 34))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(col)
	col.add_child(UiTheme.make_label(title, 13, UiTheme.TEXT_DIM))
	var v := UiTheme.make_label(value + ("  " + sub if sub != "" else ""), 19, UiTheme.TEXT)
	v.add_theme_font_override("font", UiTheme.bold_font())
	col.add_child(v)
	if ratio >= 0.0:
		col.add_child(PanelLayout.bar(ratio, UiTheme.GOOD if ratio >= 0.5 else (Color(0.9, 0.75, 0.3) if ratio >= 0.25 else UiTheme.BAD), 90.0, 4.0))

# ------------------------------------------------------------------ milli ruhlar
func _spirits(c: Country) -> void:
	PanelLayout.section(_body, tr("POL_SPIRITS"))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	_body.add_child(flow)
	for sp in c.spirits:
		var def: Dictionary = Politics.spirits.get(sp, Politics.decisions.get(sp, {}))
		if def.is_empty():
			continue
		var tip := Politics.loc(def["name"]) + "\n" + Politics.describe_mods(def.get("mods", {}))
		if def.has("expires"):
			tip += "\n" + tr("POL_SPIRIT_EXPIRES") % def["expires"]
		var negative := false
		for k: String in def.get("mods", {}):
			if float(def["mods"][k]) < 0.0 and k != "consumer_goods_mod":
				negative = true
		var tex := UiTheme.spirit_icon(sp)
		if tex == null:
			tex = UiTheme.icon("stability" if not negative else "war_support")
		var s := PanelLayout.slot(tex, 58, tip, "SlotBad" if negative else "Slot")
		flow.add_child(s)
	if c.spirits.is_empty():
		_body.add_child(UiTheme.make_label(tr("POL_NO_SPIRITS"), 15, UiTheme.TEXT_DIM))

# ------------------------------------------------------------------ yasalar
func _law_effects(d: Dictionary) -> String:
	var parts := []
	for k: String in EFFECT_KEYS:
		if d.has(k):
			var v := float(d[k]) * 100.0
			var signed := k in ["factory_output", "construction_speed", "mil_construction_speed", "research_speed", "training_time", "recruitable_population"]
			parts.append("%s %s%s%%" % [tr("EFFECT_" + k), "+" if signed and v > 0 else "", str(snappedf(v, 0.1))])
	return ", ".join(parts)

func _law_reqs(d: Dictionary) -> String:
	var req: Dictionary = d.get("requires", {})
	var parts := []
	if req.has("war_support"):
		parts.append(tr("LAW_NEED_WS") % roundi(float(req["war_support"]) * 100))
	if req.get("at_war", false):
		parts.append(tr("LAW_REQ_AT_WAR"))
	if req.get("authoritarian_or_at_war", false):
		parts.append(tr("LAW_REQ_AUTHORITARIAN"))
	return ", ".join(parts)

func _laws(c: Country) -> void:
	PanelLayout.section(_body, tr("POL_LAWS") % int(Economy.law_change_cost))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_body.add_child(row)
	for g: String in Economy.law_groups:
		var law: String = c.laws.get(g, "")
		var b := Button.new()
		b.theme_type_variation = "Card"
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.set_pressed_no_signal(g == _law_group)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 84)
		b.icon = UiTheme.law_icon(law)
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.add_theme_constant_override("icon_max_width", 44)
		b.text = Economy.law_name(g, law)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 14)
		b.tooltip_text = "%s\n%s\n%s" % [Economy.group_name(g), Economy.law_name(g, law), _law_effects(Economy.law_def(g, law))]
		b.pressed.connect(func() -> void:
			_law_group = g
			refresh())
		row.add_child(b)
	# seçili grubun yasaları
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 3)
	_body.add_child(list)
	var g := _law_group
	for law: String in Economy.law_groups[g]["laws"]:
		var d := Economy.law_def(g, law)
		var current: bool = c.laws.get(g) == law
		var block := Economy.law_block_reason(c, g, law)
		var b := Button.new()
		b.theme_type_variation = "Card"
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		b.set_pressed_no_signal(current)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.icon = UiTheme.law_icon(law)
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 34)
		b.custom_minimum_size = Vector2(0, 46)
		var reqs := _law_reqs(d)
		b.text = "%s%s\n%s" % [Economy.law_name(g, law), "  ✓" if current else "", _law_effects(d)]
		b.add_theme_font_size_override("font_size", 14)
		b.disabled = not current and not Economy.can_change_law(c, g, law)
		var tip := Economy.law_name(g, law) + "\n" + _law_effects(d)
		if reqs != "":
			tip += "\n" + tr("LAW_REQUIRES") % reqs
		if block != "" and not current:
			tip += "\n⚠ " + tr(block)
		elif not current:
			tip += "\n" + tr("LAW_CHANGE_COST") % int(Economy.law_change_cost)
		b.tooltip_text = tip
		b.pressed.connect(func() -> void:
			if not current:
				Economy.change_law(c, g, law)
			refresh())
		list.add_child(b)

# ------------------------------------------------------------------ danışmanlar
func _advisors(c: Country) -> void:
	PanelLayout.section(_body, tr("POL_ADVISORS") % [c.advisors.size(), Politics.max_advisors, int(Politics.advisor_cost)])
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 6)
	_body.add_child(slots)
	for i in Politics.max_advisors:
		if i < c.advisors.size():
			var id: String = c.advisors[i]
			var def: Dictionary = Politics.advisor_defs[id]
			slots.add_child(PanelLayout.slot(UiTheme.advisor_icon(id), 64, Politics.loc(def["name"]) + "\n" + Politics.describe_mods(def["mods"]), "SlotGold"))
		else:
			slots.add_child(PanelLayout.slot(null, 64, tr("POL_EMPTY_ADVISOR")))
	for id: String in Politics.advisor_defs:
		if id in c.advisors:
			continue
		var def: Dictionary = Politics.advisor_defs[id]
		_row_button(UiTheme.advisor_icon(id), Politics.loc(def["name"]), Politics.describe_mods(def["mods"]).replace("\n", "  "),
			tr("POL_HIRE") % int(Politics.advisor_cost), Politics.can_hire(c, id), func() -> void:
				Politics.hire(c, id)
				refresh())
	for id: String in c.advisors:
		var def: Dictionary = Politics.advisor_defs[id]
		_row_button(UiTheme.advisor_icon(id), Politics.loc(def["name"]), Politics.describe_mods(def["mods"]).replace("\n", "  "),
			tr("POL_DISMISS"), true, func() -> void:
				Politics.dismiss(c, id)
				refresh())

func _row_button(icon: Texture2D, title: String, desc: String, action: String, enabled: bool, cb: Callable) -> void:
	var row := PanelContainer.new()
	row.theme_type_variation = "PanelFlat"
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	row.add_child(hb)
	if icon:
		hb.add_child(UiTheme.icon_texture(icon, 36))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(col)
	var t := UiTheme.make_label(title, 16, UiTheme.TEXT)
	t.add_theme_font_override("font", UiTheme.bold_font())
	col.add_child(t)
	var d := UiTheme.make_label(desc, 14, UiTheme.TEXT_DIM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(d)
	var b := Button.new()
	b.text = action
	b.disabled = not enabled
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 15)
	b.pressed.connect(cb)
	hb.add_child(b)
	_body.add_child(row)

# ------------------------------------------------------------------ kararlar
func _decisions(c: Country) -> void:
	PanelLayout.section(_body, tr("POL_DECISIONS"))
	for id: String in Politics.decisions:
		var def: Dictionary = Politics.decisions[id]
		var active := c.decisions_active.has(id)
		var desc := Politics.describe_mods(def["mods"]).replace("\n", "  ") + "  ·  " + tr("TIP_DECISION") % [int(def["cost"]), int(def["days"])]
		if def.get("requires_war", false):
			desc += "  ·  " + tr("LAW_REQ_AT_WAR")
		_row_button(UiTheme.decision_icon(id), Politics.loc(def["name"]) + ("  ✓" if active else ""), desc,
			tr("POL_TAKE") % int(def["cost"]), Politics.can_take_decision(c, id), func() -> void:
				Politics.take_decision(c, id)
				refresh())
