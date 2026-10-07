class_name PoliticsPanel
extends PanelContainer
## Hükümet ekranı (Q): lider ve iktidar partisi, ideoloji pastası, siyasi güç / istikrar /
## savaş desteği (dökümlü ipuçları), milli ruhlar, üç yasa yuvası + seçili grubun yasaları, danışmanlar, kararlar.
## Haritada Ctrl + tık başka bir ülkenin siyasetini salt okunur gösterir (open_country): oyuncu rakibini tanıyıp
## ona göre hareket eder; düğmeler yalnız kendi ülkemizde çalışır.

signal focus_requested
signal diplomacy_requested(tag: String)

const IDEO_COLORS := {"democratic": Color("4a78c8"), "communism": Color("b83a2e"), "fascism": Color("8a6a3a"), "neutrality": Color("8a8a7a")}
const IDEO_ORDER := ["democratic", "communism", "fascism", "neutrality"]
const EFFECT_KEYS := ["manpower", "consumer_goods", "factory_output", "construction_speed", "mil_construction_speed",
	"research_speed", "export", "training_time", "recruitable_population"]

var _body: VBoxContainer          ## bölümlerin eklendiği sütun (refresh sırasında değişir)
var _root: VBoxContainer
var _law_group := "conscription"
var _tag := ""                    ## gösterilen ülke ("" = oyuncu)
var _title: Label
var _scroll_positions: Dictionary = {}
var _scroll_country := ""

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	visible = false
	_root = PanelLayout.frame(self, tr("POLITICS_TITLE"), "politics", -1.0)     # tam ekran, üç sütun
	_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	(get_meta("scroll") as ScrollContainer).vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_title = find_child("Title", true, false) as Label
	Politics.politics_changed.connect(func(t: String) -> void:
		if visible and t == _country_tag(): refresh())
	World.daily_update.connect(func() -> void:
		if visible: refresh())
	Economy.laws_changed.connect(func(_t: String) -> void:
		if visible: refresh())

func open() -> void:
	_tag = ""
	visible = true
	refresh()

## Başka bir ülkenin siyaseti (salt okunur); kendi ülkemizse normal ekran
func open_country(tag: String) -> void:
	_tag = "" if tag == World.player_tag else tag
	visible = true
	refresh()

func _country_tag() -> String:
	return _tag if _tag != "" else World.player_tag

func _foreign() -> bool:
	return _tag != "" and _tag != World.player_tag

func close() -> void:
	visible = false
	_scroll_country = ""
	_scroll_positions.clear()

func refresh() -> void:
	if _foreign() and not World.countries.has(_tag):
		_tag = ""                  # ülke haritadan silindiyse kendi ülkemize dön
	var c: Country = World.countries.get(_country_tag())
	if c == null:
		return
	if _scroll_country == c.tag:
		_capture_scroll_positions()
	else:
		_scroll_positions.clear()
	_scroll_country = c.tag
	for ch in _root.get_children():
		_root.remove_child(ch)
		ch.queue_free()
	if _title:
		_title.text = (tr("POLITICS_TITLE") + ("  —  " + c.display_name() if _foreign() else "")).to_upper()
	if _foreign():
		_foreign_banner(c)
	var cols := _scroll_columns([1.05, 1.1, 1.0])
	_body = cols[0]
	_body.add_theme_constant_override("separation", 10)
	_leader_block(c)
	_gauges(c)
	_effects(c)
	_body = cols[1]
	_body.add_theme_constant_override("separation", 14)     # orta sütun: ulusal durumlar ve yasalar arası nefes
	_spirits(c)
	_laws(c)
	_body = cols[2]
	_advisors(c)
	_decisions(c)
	PanelLayout.queue_fit(self)
	_restore_scroll_positions()

func _capture_scroll_positions() -> void:
	for child: Node in _root.find_children("PoliticsColumn*", "ScrollContainer", true, false):
		var scroll := child as ScrollContainer
		_scroll_positions[String(scroll.name)] = int(scroll.get_meta("scroll_restore_value")) if scroll.has_meta("scroll_restore_value") else scroll.scroll_vertical

func _restore_scroll_positions() -> void:
	for child: Node in _root.find_children("PoliticsColumn*", "ScrollContainer", true, false):
		var name := String(child.name)
		if _scroll_positions.has(name):
			child.set_meta("scroll_restore_value", int(_scroll_positions[name]))
			PoliticsPanel._restore_column_scroll.call_deferred(weakref(child), int(_scroll_positions[name]))

static func _restore_column_scroll(reference: WeakRef, value: int, after_layout := false) -> void:
	var scroll: ScrollContainer = reference.get_ref() as ScrollContainer
	if not is_instance_valid(scroll) or scroll.is_queued_for_deletion(): return
	# Sorting the rebuilt nested cards can queue a second container layout pass.
	if not after_layout:
		PoliticsPanel._restore_column_scroll.call_deferred(reference, value, true)
		return
	scroll.scroll_vertical = value
	scroll.remove_meta("scroll_restore_value")

## Each dossier column scrolls independently; long decisions never push the leader off screen.
func _scroll_columns(ratios: Array) -> Array[VBoxContainer]:
	var row := HBoxContainer.new()
	row.name = "PoliticsColumns"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 14)
	_root.add_child(row)
	var result: Array[VBoxContainer] = []
	for i in ratios.size():
		var scroll := ScrollContainer.new()
		scroll.name = "PoliticsColumn%d" % i
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.size_flags_stretch_ratio = float(ratios[i])
		row.add_child(scroll)
		DragScroll.attach(scroll)
		var col := VBoxContainer.new()
		col.name = "PoliticsColumnBody%d" % i
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 14)
		scroll.add_child(col)
		result.append(col)
	return result

## Başka ülke: kimin ekranına bakıldığı, bizimle ilişkisi ve diplomasiye / kendi ülkemize dönüş
func _foreign_banner(c: Country) -> void:
	var box := PanelContainer.new()
	box.theme_type_variation = "Strip"
	_root.add_child(box)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	box.add_child(hb)
	hb.add_child(UiTheme.icon_texture(FlagFactory.get_flag(c), 30))
	var me := World.player_tag
	var rel := tr("CTRY_ENEMY") if Diplomacy.are_enemies(me, c.tag) else (tr("CTRY_ALLY") if Diplomacy.are_allies(me, c.tag) else tr("CTRY_NEUTRAL"))
	var l := UiTheme.make_label(tr("POL_VIEWING") % [c.display_name(), rel], 16, UiTheme.TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(l)
	var dip := PanelLayout.small_button(tr("POL_VIEW_DIPLOMACY"), func() -> void: diplomacy_requested.emit(c.tag))
	dip.icon = UiTheme.trimmed(UiTheme.icon("diplomacy"))
	dip.expand_icon = true
	dip.add_theme_constant_override("icon_max_width", 20)
	hb.add_child(dip)
	var back := PanelLayout.small_button(tr("POL_VIEW_MINE"), func() -> void:
		_tag = ""
		refresh())
	hb.add_child(back)

# ------------------------------------------------------------------ lider, parti, ideoloji
func _leader_block(c: Country) -> void:
	# lider kartı: iç boşluklu çerçeve içinde portre, ad/parti/ideoloji/seçim, popülerlik pastası
	var content := CommandPanelSkin.section(_body, c.display_name(), "politics")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	content.add_child(row)
	var flag := PanelContainer.new()
	flag.theme_type_variation = "SlotGold"
	var por := UiTheme.portrait(c)
	flag.custom_minimum_size = Vector2(112, 144) if por else Vector2(132, 88)
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
	info.add_theme_constant_override("separation", 3)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(info)
	var name := UiTheme.make_label(c.leader_name(), 24, UiTheme.ACCENT)
	name.add_theme_font_override("font", UiTheme.bold_font())
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(name)
	var party := UiTheme.make_label(c.party_name() if c.party_name() != "" else tr("POL_NO_PARTY"), 17, UiTheme.TEXT)
	party.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(party)
	var ideo := UiTheme.make_label(tr("IDEOLOGY_" + c.ideology), 16, IDEO_COLORS[c.ideology].lightened(0.35))
	ideo.add_theme_font_override("font", UiTheme.bold_font())
	ideo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(ideo)
	var el := tr("POL_NO_ELECTIONS")
	if c.election_months > 0 and c.next_election > 0:
		el = tr("POL_NEXT_ELECTION") % [_fmt_date(c.next_election), c.election_months / 12]
	var election := UiTheme.make_label(el, 16, UiTheme.TEXT_DIM)
	election.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(election)
	# pasta + açıklama
	var heading := UiTheme.make_label(tr("POL_POPULARITY"), 16, UiTheme.ACCENT)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(heading)
	var shares := HBoxContainer.new()
	shares.add_theme_constant_override("separation", 12)
	content.add_child(shares)
	var pie := PanelLayout.Pie.new(100.0)
	pie.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var parts := []
	var tip := tr("POL_POPULARITY") + "\n"
	for i in IDEO_ORDER:
		var v := float(c.popularity.get(i, 0.0))
		parts.append([v, IDEO_COLORS[i]])
		tip += "%s: %d%%\n" % [tr("IDEOLOGY_" + i), roundi(v * 100)]
	tip += "\n" + tr("POL_POP_TIP") % roundi(Politics.party_stability_bonus(c) * 100)
	pie.set_parts(parts)
	pie.tooltip_text = tip
	shares.add_child(pie)
	var legend := VBoxContainer.new()
	legend.add_theme_constant_override("separation", 2)
	legend.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	legend.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for i in IDEO_ORDER:
		var lr := HBoxContainer.new()
		lr.add_theme_constant_override("separation", 6)
		var sw := ColorRect.new()
		sw.color = IDEO_COLORS[i]
		sw.custom_minimum_size = Vector2(10, 10)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		lr.add_child(sw)
		var lab := UiTheme.make_label("%s  %d%%" % [tr("IDEOLOGY_" + i), roundi(float(c.popularity.get(i, 0.0)) * 100)], 16, UiTheme.ACCENT if i == c.ideology else UiTheme.TEXT)
		lab.add_theme_font_override("font", UiTheme.bold_font())
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lr.add_child(lab)
		legend.add_child(lr)
	legend.tooltip_text = tip
	legend.mouse_filter = Control.MOUSE_FILTER_STOP
	shares.add_child(legend)

# ------------------------------------------------------------------ göstergeler
func _gauges(c: Country) -> void:
	var row := GridContainer.new()
	row.columns = 3 if get_viewport_rect().size.x >= 1900.0 else 2
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 8)
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

## Actual combined national modifiers (spirits, advisers, technologies and laws).
func _effects(c: Country) -> void:
	var content := CommandPanelSkin.section(_body, tr("FOCUS_EFFECTS").trim_suffix(":"), "stability")
	for key: String in ["stability", "war_support", "political_power_gain", "factory_output", "construction_speed", "research_speed", "recruitable_population"]:
		var value := c.mod(key)
		PanelLayout.stat(content, tr("MOD_" + key), _signed(value), "", UiTheme.GOOD if value > 0.0 else (UiTheme.BAD if value < 0.0 else UiTheme.TEXT_DIM))

func _fmt_date(d: int) -> String:
	return "%d %s %d" % [d % 100, tr("MONTH_%d" % (d / 100 % 100)), d / 10000]

func _signed(v: float) -> String:
	return ("+" if v >= 0 else "") + "%d%%" % roundi(v * 100)

func _gauge(parent: Container, icon: String, title: String, value: String, sub: String, tip: String, ratio: float) -> void:
	var cell := PanelContainer.new()
	cell.theme_type_variation = "Slot"
	cell.add_theme_stylebox_override("panel", CommandPanelSkin.box("inset", 10))
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.tooltip_text = tip
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(cell)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(hb)
	var tex := CommandPanelSkin.icon(icon)
	if tex:
		var gic := UiTheme.icon_texture(tex, 44 if get_viewport_rect().size.x >= 1900.0 else 34)
		gic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(gic)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(col)
	var caption := UiTheme.make_label(title, 16, UiTheme.TEXT_DIM)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(caption)
	# değer yazısı iyi/kötü renginde (ayrı çubuk yok: yüzde zaten yazıyor)
	var vcol := UiTheme.TEXT
	if ratio >= 0.0:
		vcol = UiTheme.GOOD if ratio >= 0.5 else (Color(0.93, 0.78, 0.4) if ratio >= 0.25 else UiTheme.BAD)
	var v := UiTheme.make_label(value, 24, vcol)
	v.add_theme_font_override("font", UiTheme.bold_font())
	col.add_child(v)
	if sub != "":
		var rate := UiTheme.make_label(sub, 16, UiTheme.TEXT_DIM)
		rate.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(rate)

# ------------------------------------------------------------------ milli ruhlar
func _spirits(c: Country) -> void:
	var content := CommandPanelSkin.section(_body, tr("POL_SPIRITS"), "stability")
	content.name = "NationalConditions"
	var grid := GridContainer.new()
	grid.name = "NationalConditionCards"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	content.add_child(grid)
	var illustrated := 0
	for sp in c.spirits:
		var def: Dictionary = Politics.spirits.get(sp, Politics.decisions.get(sp, {}))
		if def.is_empty():
			continue
		var mods: Dictionary = def.get("mods", {})
		var effects := Politics.describe_mods(mods)
		var tip := Politics.loc(def["name"]) + "\n" + effects
		if def.has("expires"):
			tip += "\n" + tr("POL_SPIRIT_EXPIRES") % def["expires"]
		var state := _spirit_state(mods)
		var tex := _national_illustration(sp)
		# One illustrated inset per condition, not another framed slot inside a box.
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", CommandPanelSkin.box("card", 8))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.set_meta("national_spirit", sp)
		card.set_meta("spirit_state", state)
		card.tooltip_text = tip
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		grid.add_child(card)
		var stack := VBoxContainer.new()
		stack.add_theme_constant_override("separation", 7)
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(stack)
		var art := TextureRect.new()
		art.name = "Illustration"
		art.texture = tex
		var side := 96 if get_viewport_rect().size.x >= 1700.0 else 84
		art.custom_minimum_size = Vector2(side, side)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(art)
		var accent := ColorRect.new()
		accent.custom_minimum_size.y = 2
		accent.color = Color("829365") if state > 0 else (Color("967454") if state < 0 else Color("9a8150"))
		accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(accent)
		var nl := UiTheme.make_label(Politics.loc(def["name"]), 16, UiTheme.TEXT)
		nl.add_theme_font_override("font", UiTheme.bold_font())
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nl.max_lines_visible = 3
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(nl)
		var lines := effects.split("\n", false)
		if not lines.is_empty():
			var summary := UiTheme.make_label(lines[0], 15, UiTheme.TEXT_DIM)
			summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			summary.max_lines_visible = 2
			summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
			stack.add_child(summary)
		illustrated += 1
	if illustrated == 0:
		content.add_child(UiTheme.make_label(tr("POL_NO_SPIRITS"), 17, UiTheme.TEXT_DIM))

## Dossier illustrations must not fall back to glossy HUD status pictograms.
## UiTheme's cached alpha trim only handles padded icons_new images; printed
## painted-atlas frames retain their full region. No bitmap is changed/read back.
static func _national_illustration(id: String) -> Texture2D:
	var texture: Texture2D
	if id == Research.GOVERNMENT_SPIRIT:
		texture = load("res://assets/ui/command_panels/statecraft_v1.png") as Texture2D
	elif id == "army_in_reorganization":
		texture = CommandPanelSkin.illustration("spirit_military_modernization")
	else:
		texture = UiTheme.spirit_icon(id)
	if texture == null:
		texture = CommandPanelSkin.illustration("spirit_national_unity")
	return UiTheme.trimmed(texture)

## Mixed tradeoffs remain neutral; colour never replaces the complete modifier tooltip.
static func _spirit_state(mods: Dictionary) -> int:
	var good := false
	var bad := false
	for key: String in mods:
		if key == "export": continue # More exports are a policy tradeoff, not an unconditional bonus.
		var effect := float(mods[key])
		if key in ["consumer_goods_mod", "training_time"]: effect = -effect
		good = good or effect > 0.0
		bad = bad or effect < 0.0
	return 0 if good == bad else (1 if good else -1)

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
	var content := CommandPanelSkin.section(_body, tr("POL_LAWS") % int(Economy.law_change_cost), "political_power")
	if not Economy.law_groups.has(_law_group):
		_law_group = Economy.law_groups.keys()[0]
	# Current laws remain visible together. Their selectors only change this view,
	# not the country's laws; actual choices and requirements follow below.
	for g: String in Economy.law_groups:
		var current_id: String = c.laws.get(g, "")
		var select := Button.new()
		Audio.ui_bind(select, "ui_tab")
		select.theme_type_variation = "Card"
		select.toggle_mode = true
		select.set_pressed_no_signal(g == _law_group)
		select.focus_mode = Control.FOCUS_NONE
		select.alignment = HORIZONTAL_ALIGNMENT_LEFT
		select.clip_text = true
		select.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		select.text = Economy.group_name(g) + " · " + Economy.law_name(g, current_id)
		select.icon = UiTheme.trimmed(UiTheme.law_icon(current_id))
		select.expand_icon = true
		select.add_theme_constant_override("icon_max_width", 32)
		select.add_theme_font_size_override("font_size", UiTheme.fs(17))
		select.custom_minimum_size.y = 56
		select.tooltip_text = Economy.group_name(g) + "\n" + Economy.law_name(g, current_id) + "\n" + _law_effects(Economy.law_def(g, current_id)).replace(", ", "\n")
		select.set_meta("law_selector", g)
		select.pressed.connect(func() -> void:
			_law_group = g
			refresh())
		content.add_child(select)
	var group := _law_group
	var heading := UiTheme.make_label(Economy.group_name(group), 20, UiTheme.ACCENT)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(heading)
	for law: String in Economy.law_groups[group]["laws"]:
		var d := Economy.law_def(group, law)
		var current: bool = c.laws.get(group) == law
		var block := Economy.law_block_reason(c, group, law)
		var button := Button.new()
		# Only a successful core law change emits its semantic confirmation.
		button.set_meta("audio_silent", true)
		button.theme_type_variation = "Card"
		button.focus_mode = Control.FOCUS_NONE
		button.toggle_mode = true
		button.set_pressed_no_signal(current)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.icon = UiTheme.trimmed(UiTheme.law_icon(law))
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 46)
		button.custom_minimum_size.y = 68
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.text = Economy.law_name(group, law) + ("  ✓" if current else "")
		button.add_theme_font_size_override("font_size", UiTheme.fs(17))
		button.disabled = _foreign() or (not current and not Economy.can_change_law(c, group, law))
		button.set_meta("law_control", true)
		button.set_meta("law_id", law)
		var tip := Economy.law_name(group, law) + "\n" + _law_effects(d).replace(", ", "\n")
		var reqs := _law_reqs(d)
		if reqs != "": tip += "\n" + tr("LAW_REQUIRES") % reqs
		if not _foreign() and not current:
			tip += "\n⚠ " + tr(block) if block != "" else "\n" + tr("LAW_CHANGE_COST") % int(Economy.law_change_cost)
		button.tooltip_text = tip
		button.pressed.connect(func() -> void:
			if not current and not _foreign(): Economy.change_law(c, group, law)
			refresh())
		content.add_child(button)
		if current:
			PanelLayout.detail(content, _law_effects(d).replace(", ", "\n"), 16)

# ------------------------------------------------------------------ danışmanlar
func _advisors(c: Country) -> void:
	var content := CommandPanelSkin.section(_body, tr("POL_ADVISORS") % [c.advisors.size(), Politics.max_advisors, int(Politics.advisor_cost)], "political_power")
	var slots := HFlowContainer.new()
	slots.add_theme_constant_override("h_separation", 10)
	slots.add_theme_constant_override("v_separation", 10)
	content.add_child(slots)
	for i in Politics.max_advisors:
		if i < c.advisors.size():
			var id: String = c.advisors[i]
			var def: Dictionary = Politics.advisor_defs[id]
			slots.add_child(PanelLayout.slot(CommandPanelSkin.illustration("advisor_" + id), 76, Politics.loc(def["name"]) + "\n" + Politics.describe_mods(def["mods"]), "SlotGold"))
		else:
			slots.add_child(PanelLayout.slot(null, 76, tr("POL_EMPTY_ADVISOR")))
	if _foreign():
		for id: String in c.advisors:
			var def: Dictionary = Politics.advisor_defs[id]
			_row_button(CommandPanelSkin.illustration("advisor_" + id), Politics.loc(def["name"]), Politics.describe_mods(def["mods"]).replace("\n", "  "), "", false, Callable(), content)
		return
	for id: String in Politics.advisor_defs:
		if id in c.advisors:
			continue
		var def: Dictionary = Politics.advisor_defs[id]
		_row_button(CommandPanelSkin.illustration("advisor_" + id), Politics.loc(def["name"]), Politics.describe_mods(def["mods"]).replace("\n", "  "),
			tr("POL_HIRE") % int(Politics.advisor_cost), Politics.can_hire(c, id), func() -> void:
				Politics.hire(c, id)
				refresh(), content)
	for id: String in c.advisors:
		var def: Dictionary = Politics.advisor_defs[id]
		_row_button(CommandPanelSkin.illustration("advisor_" + id), Politics.loc(def["name"]), Politics.describe_mods(def["mods"]).replace("\n", "  "),
			tr("POL_DISMISS"), true, func() -> void:
				Politics.dismiss(c, id)
				refresh(), content)

func _row_button(icon: Texture2D, title: String, desc: String, action: String, enabled: bool, cb: Callable, parent: Container = null) -> void:
	var row := PanelContainer.new()
	row.theme_type_variation = "PanelFlat"
	row.tooltip_text = title + "\n" + desc
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	row.add_child(stack)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	stack.add_child(hb)
	if icon:
		hb.add_child(UiTheme.icon_texture(icon, 48))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(col)
	var t := UiTheme.make_label(title, 18, UiTheme.TEXT)
	t.add_theme_font_override("font", UiTheme.bold_font())
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(t)
	var d := UiTheme.make_label(desc, 16, UiTheme.TEXT_DIM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if get_viewport_rect().size.x < 1700.0:
		d.max_lines_visible = 1
		d.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(d)
	(parent if parent != null else _body).add_child(row)
	if action == "":
		return
	var b := Button.new()
	# Advisor/decision success is signalled by Politics, not by refresh or press.
	b.set_meta("audio_silent", true)
	b.text = action
	b.disabled = not enabled
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.y = 44
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	b.add_theme_font_size_override("font_size", UiTheme.fs(17))
	b.tooltip_text = title + "\n" + desc
	b.pressed.connect(cb)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(b)

# ------------------------------------------------------------------ kararlar
func _decisions(c: Country) -> void:
	var content := CommandPanelSkin.section(_body, tr("POL_DECISIONS"), "political_power")
	if _foreign():
		for id: String in c.decisions_active:
			var def: Dictionary = Politics.decisions.get(id, {})
			if not def.is_empty():
				_row_button(UiTheme.decision_icon(id), Politics.loc(def["name"]) + "  ✓", Politics.describe_mods(def["mods"]).replace("\n", "  "), "", false, Callable(), content)
		if c.decisions_active.is_empty():
			content.add_child(UiTheme.make_label(tr("POL_NO_DECISIONS"), 17, UiTheme.TEXT_DIM))
		return
	for id: String in Politics.decisions:
		var def: Dictionary = Politics.decisions[id]
		var active := c.decisions_active.has(id)
		var desc := Politics.describe_mods(def["mods"]).replace("\n", "  ") + "  ·  " + tr("TIP_DECISION") % [int(def["cost"]), int(def["days"])]
		if def.get("requires_war", false):
			desc += "  ·  " + tr("LAW_REQ_AT_WAR")
		_row_button(UiTheme.decision_icon(id), Politics.loc(def["name"]) + ("  ✓" if active else ""), desc,
			tr("POL_TAKE") % int(def["cost"]), Politics.can_take_decision(c, id), func() -> void:
				Politics.take_decision(c, id)
				refresh(), content)
