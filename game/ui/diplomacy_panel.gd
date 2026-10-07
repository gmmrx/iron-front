class_name DiplomacyPanel
extends PanelContainer
## Diplomasi (O): hedef ülke başlığı (bayrak, lider, ideoloji, ittifak), durum hücreleri,
## eylem satırları (ne yapar, neden kapalı ipucunda). Hedef yoksa dünya gerginliği, savaşlar ve ittifaklar.

const IDEO_COLORS := {"democratic": Color("4a78c8"), "communism": Color("b83a2e"), "fascism": Color("8a6a3a"), "neutrality": Color("8a8a7a")}

var target := ""
var _v: VBoxContainer          ## bölümlerin eklendiği sütun (refresh sırasında değişir)
var _root: VBoxContainer
var _search: LineEdit          ## ülke arama (sabit alanda: yenilemede kaybolmaz, yazarken odak kalır)
var _list: Array = []          ## [düğme, aranan metin, ülke kodu]
var _scroll_positions: Dictionary = {}
var _reset_scroll_on_refresh := false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	visible = false
	_root = PanelLayout.frame(self, tr("DIPLO_TITLE"), "diplomacy", -1.0)     # tam ekran: ülkeler · seçili ülke · dünya
	_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	(get_meta("scroll") as ScrollContainer).vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_search = LineEdit.new()
	_search.placeholder_text = tr("DIP_SEARCH")
	_search.tooltip_text = tr("TIP_DIP_SEARCH")
	_search.clear_button_enabled = true
	_search.custom_minimum_size = Vector2(0, 48)
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.add_theme_font_size_override("font_size", UiTheme.fs(17))
	_search.text_changed.connect(func(_t: String) -> void: _filter())
	_search.text_submitted.connect(func(_t: String) -> void:
		# Enter: listede görünen ilk ülke seçilir
		for e: Array in _list:
			if (e[0] as Button).visible:
				target = e[2]
				refresh()
				return)
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
	_search.text = ""
	_scroll_positions.clear()
	_reset_scroll_on_refresh = true

## Aramada Türkçe harfler ve büyük/küçük harf fark etmez ("isvec" İsveç'i bulur)
static func _fold(s: String) -> String:
	var t := s.to_lower().replace("\u0307", "")
	for pair: Array in [["ç", "c"], ["ğ", "g"], ["ı", "i"], ["ö", "o"], ["ş", "s"], ["ü", "u"], ["â", "a"], ["î", "i"], ["û", "u"]]:
		t = t.replace(pair[0], pair[1])
	return t

## Ülke listesini arama kutusuna göre süz (ad ya da ülke kodu)
func _filter() -> void:
	var q := _fold(_search.text.strip_edges())
	for e: Array in _list:
		(e[0] as Button).visible = q == "" or String(e[1]).contains(q)

func refresh() -> void:
	if _reset_scroll_on_refresh:
		_scroll_positions.clear()
		_reset_scroll_on_refresh = false
	else:
		_capture_scroll_positions()
	var restore_search_focus := _search.has_focus()
	if _search.get_parent() != null:
		_search.get_parent().remove_child(_search) # Keep text, caret and signal connections across country selection.
	for ch in _root.get_children():
		_root.remove_child(ch)
		ch.queue_free()
	var me := World.player()
	if me == null: return
	var cols := _scroll_columns([0.85, 1.35, 1.0])
	_v = cols[0]
	_country_list(me)
	if restore_search_focus: _search.grab_focus.call_deferred()
	_restore_scroll_positions()
	var t: Country = World.countries.get(target)
	_v = cols[2]
	_overview(me, t if t != null and t.exists() else me)
	_v = cols[1]
	if t == null or t == me or not t.exists():
		PanelLayout.set_title(self, tr("DIPLO_TITLE"))
		var empty := CommandPanelSkin.section(_v, tr("DIP_SELECT"), "diplomacy")
		PanelLayout.detail(empty, tr("DIP_SELECT_HINT"), 19)
		PanelLayout.queue_fit(self)
		return
	PanelLayout.set_title(self, tr("DIPLO_TITLE") + " — " + t.display_name())
	var center := _v
	# One compact identity inset; the panel title already identifies the country.
	var identity := PanelContainer.new()
	identity.add_theme_stylebox_override("panel", CommandPanelSkin.box("inset", 12))
	center.add_child(identity)
	_v = VBoxContainer.new()
	_v.add_theme_constant_override("separation", 10)
	identity.add_child(_v)
	# başlık bloğu
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	_v.add_child(head)
	# The flag and leader form one compact dossier vignette. The portrait overlaps
	# only the lower fly side; the canton/emblem and flag proportions stay intact.
	var emblems := Control.new()
	emblems.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var wide := get_viewport_rect().size.x >= 1700.0
	emblems.custom_minimum_size = Vector2(202, 140) if wide else Vector2(166, 126)
	head.add_child(emblems)
	var plaque := PanelContainer.new()
	plaque.name = "DiplomacyFlagPlaque"
	plaque.add_theme_stylebox_override("panel", CommandPanelSkin.box("selected", 5))
	emblems.add_child(plaque)
	var country_flag := TextureRect.new()
	country_flag.name = "DiplomacyCountryFlag"
	country_flag.texture = FlagFactory.uniform(t, 540)
	var flag_width := 180.0 if wide else 148.0
	country_flag.custom_minimum_size = Vector2(flag_width, flag_width * 2.0 / 3.0)
	emblems.custom_minimum_size.y = maxf(emblems.custom_minimum_size.y, country_flag.custom_minimum_size.y + 10)
	country_flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	country_flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var fabric := ShaderMaterial.new()
	fabric.shader = preload("res://assets/shaders/dossier_flag.gdshader")
	fabric.set_shader_parameter("cloth", load("res://assets/ui/command_panels/flag_cloth_v1.png"))
	country_flag.material = fabric
	plaque.add_child(country_flag)
	var flag := PanelContainer.new()
	flag.theme_type_variation = "SlotGold"
	var por := UiTheme.portrait(t)
	flag.custom_minimum_size = Vector2(68, 86) if por else Vector2(0, 0)
	flag.position = Vector2(124, 48) if wide else Vector2(94, 38)
	var ft := TextureRect.new()
	ft.texture = por if por else FlagFactory.get_flag(t)
	ft.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ft.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if por else TextureRect.STRETCH_SCALE
	ft.clip_contents = true
	flag.add_child(ft)
	if por:
		emblems.add_child(flag)
	else:
		flag.queue_free()
	var nb := VBoxContainer.new()
	nb.add_theme_constant_override("separation", 3)
	nb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nb)
	var n := UiTheme.make_label(t.leader_name(), 24, UiTheme.ACCENT)
	n.add_theme_font_override("font", UiTheme.bold_font())
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nb.add_child(n)
	var party := UiTheme.make_label(t.party_name() if t.party_name() != "" else tr("POL_NO_PARTY"), 17, UiTheme.TEXT)
	party.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nb.add_child(party)
	var il := UiTheme.make_label(tr("IDEOLOGY_" + t.ideology), 15, IDEO_COLORS[t.ideology].lightened(0.35))
	il.add_theme_font_override("font", UiTheme.bold_font())
	il.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	nb.add_child(badge)
	# durum hücreleri
	var cells := _info_grid(_v, [
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
	_v = CommandPanelSkin.section(center, tr("DIP_ACTIONS"), "diplomacy")
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
	PanelLayout.queue_fit(self)

func _capture_scroll_positions() -> void:
	for child: Node in _root.find_children("Diplomacy*", "ScrollContainer", true, false):
		var scroll := child as ScrollContainer
		_scroll_positions[String(scroll.name)] = int(scroll.get_meta("scroll_restore_value")) if scroll.has_meta("scroll_restore_value") else scroll.scroll_vertical

func _restore_scroll_positions() -> void:
	for child: Node in _root.find_children("Diplomacy*", "ScrollContainer", true, false):
		var name := String(child.name)
		if _scroll_positions.has(name):
			child.set_meta("scroll_restore_value", int(_scroll_positions[name]))
			DiplomacyPanel._restore_column_scroll.call_deferred(weakref(child), int(_scroll_positions[name]))

static func _restore_column_scroll(reference: WeakRef, value: int, after_layout := false) -> void:
	var scroll: ScrollContainer = reference.get_ref() as ScrollContainer
	if not is_instance_valid(scroll) or scroll.is_queued_for_deletion(): return
	if not after_layout:
		DiplomacyPanel._restore_column_scroll.call_deferred(reference, value, true)
		return
	scroll.scroll_vertical = value
	scroll.remove_meta("scroll_restore_value")

func _scroll_columns(ratios: Array) -> Array[VBoxContainer]:
	var row := HBoxContainer.new()
	row.name = "DiplomacyColumns"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 14)
	_root.add_child(row)
	var result: Array[VBoxContainer] = []
	for i in ratios.size():
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 14)
		if i == 0:
			# The country list owns its scroll below the persistent search field.
			col.size_flags_vertical = Control.SIZE_EXPAND_FILL
			col.size_flags_stretch_ratio = float(ratios[i])
			row.add_child(col)
		else:
			var scroll := ScrollContainer.new()
			scroll.name = "DiplomacyColumn%d" % i
			scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
			scroll.size_flags_stretch_ratio = float(ratios[i])
			row.add_child(scroll)
			DragScroll.attach(scroll)
			scroll.add_child(col)
		result.append(col)
	return result

func _info_grid(parent: Container, items: Array) -> Array[Label]:
	var grid := GridContainer.new()
	grid.columns = 4 if get_viewport_rect().size.x >= 1700.0 else 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	parent.add_child(grid)
	var values: Array[Label] = []
	for item: Array in items:
		var cell := PanelContainer.new()
		cell.theme_type_variation = "Slot"
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.custom_minimum_size.y = 68
		grid.add_child(cell)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 9)
		cell.add_child(row)
		row.add_child(UiTheme.icon_texture(CommandPanelSkin.icon(item[0]), 38))
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		var caption := UiTheme.make_label(item[1], 15, UiTheme.TEXT_DIM)
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(caption)
		var value := UiTheme.make_label("", 23, UiTheme.TEXT)
		value.add_theme_font_override("font", UiTheme.bold_font())
		value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(value)
		values.append(value)
	return values

## Ülke listesi: büyük güçler üstte (sanayiye göre), sonra ada göre; ideoloji rengi, ilişki; tıklayınca seçilir
func _country_list(me: Country) -> void:
	var card := PanelContainer.new()
	card.theme_type_variation = "PanelFlat"
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_v.add_child(card)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	card.add_child(content)
	var heading := UiTheme.make_label(tr("DIP_COUNTRIES").to_upper(), 19, UiTheme.ACCENT)
	heading.add_theme_font_override("font", UiTheme.bold_font())
	content.add_child(heading)
	content.add_child(_search)
	var scroll := ScrollContainer.new()
	scroll.name = "DiplomacyCountryScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	DragScroll.attach(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 7)
	scroll.add_child(list)
	_list.clear()
	var all: Array = World.countries.values().filter(func(c: Country) -> bool: return c.exists() and c != me and World.is_active(c.tag))
	all.sort_custom(func(a: Country, b: Country) -> bool:
		if a.is_major() != b.is_major():
			return a.is_major()
		if a.is_major():
			return Economy.count(a, "civilian_factory") + Economy.count(a, "military_factory") > Economy.count(b, "civilian_factory") + Economy.count(b, "military_factory")
		return a.display_name() < b.display_name())
	for c: Country in all:
		var b := Button.new()
		b.theme_type_variation = "Card"
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		b.set_pressed_no_signal(c.tag == target)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.icon = FlagFactory.uniform(c)                  # her bayrak aynı boyda
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 54)
		b.add_theme_constant_override("h_separation", 10)
		b.custom_minimum_size = Vector2(0, 58)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", UiTheme.fs(18))
		var rel := ""
		if Diplomacy.are_enemies(me.tag, c.tag):
			rel = "  ⚔"
			b.add_theme_color_override("font_color", UiTheme.BAD)
		elif Diplomacy.are_allies(me.tag, c.tag):
			rel = "  ✦"
			b.add_theme_color_override("font_color", UiTheme.GOOD)
		b.text = c.display_name() + rel
		b.tooltip_text = "%s\n%s · %s" % [c.display_name(), c.leader_name(), tr("IDEOLOGY_" + c.ideology)]
		var ideo := ColorRect.new()
		ideo.color = IDEO_COLORS[c.ideology]
		ideo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ideo.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
		ideo.offset_left = -8
		ideo.offset_right = -4
		ideo.offset_top = 6
		ideo.offset_bottom = -6
		b.add_child(ideo)
		b.pressed.connect(func() -> void:
			target = c.tag
			refresh())
		list.add_child(b)
		_list.append([b, _fold(c.display_name()) + " " + c.tag.to_lower(), c.tag])
	_filter()

func _action(icon: String, text: String, tip: String, err: String, fn: Callable) -> void:
	# Compact, legible action: detailed explanation and the exact blocking reason
	# stay in both tooltips rather than consuming a second row plus a CTA footer.
	var full_tip := text + "\n" + tip + ("" if err == "" else "\n\n" + tr(err))
	var col := PanelLayout.row(_v, CommandPanelSkin.icon(icon), text, "", full_tip)
	(col.get_child(0) as Label).add_theme_font_size_override("font_size", UiTheme.fs(18))
	if err != "":
		(col.get_child(0) as Label).add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	var button := PanelLayout.small_button(tr("DIP_DO"), func() -> void:
		fn.call()
		refresh(), err == "", full_tip)
	button.custom_minimum_size = Vector2(104, 44)
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	button.add_theme_font_size_override("font_size", UiTheme.fs(17))
	button.set_meta("diplomatic_action", text)
	PanelLayout.row_action(col, button)

func _flags(tags: Array, side := 26, surrender := true) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 3)
	f.add_theme_constant_override("v_separation", 3)
	for tg: String in tags:
		var c: Country = World.countries.get(tg)
		if c == null:
			continue
		var tr_ := TextureRect.new()
		tr_.texture = FlagFactory.uniform(c)
		tr_.custom_minimum_size = Vector2(side * 1.5, side)
		tr_.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr_.stretch_mode = TextureRect.STRETCH_SCALE
		tr_.tooltip_text = c.display_name()
		if surrender:
			tr_.tooltip_text += "  ·  %s %d%%" % [tr("DIP_SURRENDER"), roundi(c.surrender_progress * 100)]
		f.add_child(tr_)
	return f

func _overview(me: Country, selected: Country) -> void:
	var column := _v
	var world := CommandPanelSkin.section(column, tr("DIP_WORLD"), "war_support")
	var tension := World.world_tension / 100.0
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 8)
	trow.add_child(UiTheme.icon_texture(CommandPanelSkin.icon("war_support"), 38))
	var tl := UiTheme.make_label(tr("DIPLO_TENSION") % roundi(World.world_tension), 17, UiTheme.BAD if tension >= 0.5 else UiTheme.TEXT)
	tl.add_theme_font_override("font", UiTheme.bold_font())
	trow.add_child(tl)
	var bar := PanelLayout.progress(tension, UiTheme.BAD if tension >= 0.5 else Color(0.9, 0.75, 0.3), 8.0)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	trow.add_child(bar)
	trow.tooltip_text = tr("DIP_TENSION_TIP")
	trow.mouse_filter = Control.MOUSE_FILTER_STOP
	world.add_child(trow)
	if target == "": PanelLayout.detail(world, tr("DIPLO_HINT"), 16)
	var agreements := CommandPanelSkin.section(column, tr("DIP_AGREEMENTS"), "diplomacy")
	for item: Array in [["DIP_GUARANTEES", selected.guarantees], ["DIP_ACCESS_RIGHTS", selected.access]]:
		var caption := UiTheme.make_label(tr(item[0]), 17, UiTheme.TEXT_DIM)
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		agreements.add_child(caption)
		if not (item[1] as Array).is_empty(): agreements.add_child(_flags(item[1], 30, false))
	if selected.guarantees.is_empty() and selected.access.is_empty():
		PanelLayout.detail(agreements, tr("DIP_NO_AGREEMENTS"), 16)
	var wars := CommandPanelSkin.section(column, tr("DIPLO_WARS"), "battle")
	if Diplomacy.wars.is_empty():
		PanelLayout.empty(wars, tr("DIPLO_NO_WARS"))
	for w: Dictionary in Diplomacy.wars:
		var pc := PanelContainer.new()
		pc.theme_type_variation = "Row"
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		pc.add_child(hb)
		var a := _flags(w["attackers"], 30)
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(a)
		hb.add_child(UiTheme.icon_texture(UiTheme.icon("battle"), 24))
		var d := _flags(w["defenders"], 30)
		d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		d.alignment = FlowContainer.ALIGNMENT_END
		hb.add_child(d)
		wars.add_child(pc)
	var factions := CommandPanelSkin.section(column, tr("DIPLO_FACTIONS"), "diplomacy")
	for leader: String in Politics.factions:
		var members: Array = Politics.factions[leader]
		if members.is_empty():
			continue
		var col := PanelLayout.row(factions, null, Politics.faction_display(leader), "")
		col.add_child(_flags(members, 28, false))
	if me.faction == "":
		var b := PanelLayout.small_button(tr("DIPLO_CREATE_FACTION"), func() -> void:
			Diplomacy.create_faction(me.tag)
			refresh(), true, tr("TIP_CREATE_FACTION"))
		b.custom_minimum_size.y = 48
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		factions.add_child(b)
