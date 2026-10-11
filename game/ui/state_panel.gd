class_name StatePanel
extends PanelContainer
## Seçili eyalet: sahibi, nüfus/insan gücü/zafer puanı, bina yuvaları (ortak yuvalar
## simgelerle, bölge binaları seviye çubuğuyla), kaynaklar; oyuncunun eyaletinde doğrudan inşa düğmeleri.

signal diplomacy_requested(tag: String)

const SHARED := ["civilian_factory", "military_factory"]
const PROVINCIAL := ["infrastructure", "air_base", "naval_base", "anti_air"]

var _body: VBoxContainer
var _play_btn: Button
var _diplo_btn: Button
var _state_id := 0
var _province_id := 0
var _country_box: VBoxContainer
var _quick_actions: Dictionary = {}
var _war_confirmation: ConfirmationDialog
var _pending_war: Dictionary = {}
var _refresh_pending := false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(PanelLayout.SIDE_LEFT, PanelLayout.SIDE_TOP)
	visible = false
	_body = PanelLayout.frame(self, "", "construction", 400.0)
	_country_box = PanelLayout.fixed(self)
	_play_btn = Button.new()
	_play_btn.focus_mode = Control.FOCUS_NONE
	_play_btn.custom_minimum_size.y = 40
	_play_btn.pressed.connect(_on_play_pressed)
	_diplo_btn = Button.new()
	_diplo_btn.text = tr("QUICK_DETAILS")
	_diplo_btn.icon = UiTheme.trimmed(UiTheme.icon("diplomacy"))
	_diplo_btn.add_theme_constant_override("icon_max_width", 22)
	_diplo_btn.focus_mode = Control.FOCUS_NONE
	_diplo_btn.custom_minimum_size.y = 40
	_diplo_btn.pressed.connect(func() -> void:
		var state: StateRegion = World.states.get(_state_id)
		if state and World.in_game and state.owner != World.player_tag:
			diplomacy_requested.emit(state.owner))
	var bottom := VBoxContainer.new()
	bottom.add_child(_play_btn)
	bottom.add_child(_diplo_btn)
	get_child(0).add_child(bottom)
	World.selection_changed.connect(_on_selection)
	World.daily_update.connect(_queue_refresh)
	Economy.building_completed.connect(func(_t: String, _s: int, _b: String) -> void: _queue_refresh())
	Economy.construction_changed.connect(func(_t: String) -> void: _queue_refresh())
	World.player_changed.connect(func(_t: String) -> void:
		_cancel_war()
		_queue_refresh())
	World.ownership_changed.connect(_queue_refresh)
	World.control_changed.connect(_queue_refresh)
	World.country_removed.connect(func(_t: String) -> void: _queue_refresh())
	Diplomacy.diplomacy_changed.connect(func(_t: String) -> void: _queue_refresh())
	Diplomacy.wars_changed.connect(_queue_refresh)
	visibility_changed.connect(func() -> void:
		if not visible: _cancel_war())
	_war_confirmation = ConfirmationDialog.new()
	_war_confirmation.title = tr("QUICK_WAR_TITLE")
	_war_confirmation.dialog_autowrap = true
	_war_confirmation.theme = CommandPanelSkin.get_theme().duplicate()
	_war_confirmation.theme.set_stylebox("panel", "AcceptDialog", CommandPanelSkin.box("panel", 18))
	var border := ThemeDB.get_default_theme().get_stylebox("embedded_border", "Window").duplicate()
	if border is StyleBoxFlat:
		border.bg_color = Color("101719")
		border.border_color = Color("887045")
	_war_confirmation.theme.set_stylebox("embedded_border", "Window", border)
	_war_confirmation.theme.set_stylebox("embedded_unfocused_border", "Window", border)
	_war_confirmation.theme.set_color("title_color", "Window", UiTheme.ACCENT)
	_war_confirmation.ok_button_text = tr("DIPLO_DECLARE")
	_war_confirmation.cancel_button_text = tr("RES_CONFIRM_CANCEL")
	_war_confirmation.confirmed.connect(_confirm_war)
	_war_confirmation.canceled.connect(_cancel_war)
	add_child(_war_confirmation)

func close() -> void:
	World.select_province(0)

func _on_selection(pid: int) -> void:
	_cancel_war()
	var p := World.province(pid)
	_province_id = pid
	_state_id = p.state_id if p else 0
	visible = _state_id > 0
	if visible:
		for p2 in get_parent().get_children():
			if p2 != self and (p2 is ConstructionPanel or p2 is ProductionPanel or p2 is PoliticsPanel or p2 is TradePanel or p2 is ArmyPanel \
					or p2 is ResearchPanel or p2 is DiplomacyPanel or p2 is NavyPanel or p2 is AirPanel or p2 is LogisticsPanel) and p2.visible:
				p2.close()
		_refresh()
	else:
		_quick_actions.clear()

func _queue_refresh() -> void:
	if _refresh_pending or not visible: return
	_refresh_pending = true
	_refresh.call_deferred()

func _refresh() -> void:
	_refresh_pending = false
	if _state_id == 0 or not visible:
		return
	var st: StateRegion = World.states.get(_state_id)
	var c: Country = World.countries.get(st.owner) if st else null
	var p := World.province(_province_id)
	if st == null or c == null or p == null:
		_quick_actions.clear()
		visible = false
		return
	if not _pending_war.is_empty():
		var target: Country = World.countries.get(_pending_war.get("target", ""))
		if not _war_context_valid(_pending_war) or CountryDiplomacyActions.blocked(World.player(), target, "declare") != "":
			_cancel_war()
	PanelLayout.set_title(self, st.display_name())
	for box: VBoxContainer in [_body, _country_box]:
		for ch in box.get_children():
			box.remove_child(ch)
			ch.queue_free()
	_build_country_card(st, c)
	# Public diplomacy stays accessible even when the state's buildings are hidden.
	_play_btn.text = tr("UI_PLAY_AS") % c.display_name()
	_play_btn.visible = st.owner != World.player_tag and not World.in_game and World.is_active(c.tag)
	_diplo_btn.visible = st.owner != World.player_tag and World.in_game and World.is_active(c.tag) and c.exists()
	PanelLayout.queue_fit(self)
	# temel bilgiler
	var cells := PanelLayout.info_cells(_body, [["manpower", tr("UI_POPULATION"), ""], ["army", tr("UI_MANPOWER"), ""], ["political_power", tr("UI_VICTORY_POINTS"), ""]])
	cells[0].text = UiTheme.format_number(st.population)
	cells[1].text = UiTheme.format_number(int(st.population * 0.015))
	cells[2].text = str(st.victory_points())
	var big := st.largest_city()
	PanelLayout.stat(_body, tr("UI_LARGEST_CITY"), big.display_name() if big else "—")
	PanelLayout.stat(_body, tr("UI_AREA"), "%s km²  ·  %d %s" % [UiTheme.format_number(st.area_km2), st.provinces.size(), tr("UI_PROVINCES")])
	PanelLayout.stat(_body, tr("UI_TERRAIN"), "%s%s" % [tr("TERRAIN_" + p.terrain), ("  ·  " + tr("UI_COASTAL")) if p.coastal else ""])
	if p.city:
		PanelLayout.stat(_body, tr("UI_CITY"), p.city.display_name() + (" (%s)" % tr("UI_PORT") if p.city.is_port else ""))
	_recruit_section(st, p)
	if not Economy.SHOW_BUILDINGS or Military.state_fogged(st):
		return                                   # sisin altındaki yabancı eyaletin yapıları keşfedilene kadar bilinmez
	# ortak bina yuvaları
	var mine := st.owner == World.player_tag and World.in_game
	var player := World.player()
	var queued := {}
	if player:
		for q in player.construction_queue:
			if q.state_id == st.id:
				queued[q.building] = int(queued.get(q.building, 0)) + 1
	PanelLayout.section(_body, tr("ST_SLOTS") % [st.used_slots(), st.building_slots])
	# yuvalar eşit genişlikte sütunlara bölünür (en çok 6), yüksek hücreler
	var slots := GridContainer.new()
	slots.columns = clampi(st.building_slots, 1, 6)
	slots.add_theme_constant_override("h_separation", 4)
	slots.add_theme_constant_override("v_separation", 4)
	_body.add_child(slots)
	var used := 0
	for b: String in SHARED:
		for k in st.building_level(b):
			slots.add_child(_slot_cell(UiTheme.building_icon(b), Economy.building_name(b), "SlotGold"))
			used += 1
	for b: String in SHARED:
		for k in int(queued.get(b, 0)):
			var s := _slot_cell(UiTheme.building_icon(b), Economy.building_name(b) + " — " + tr("ST_QUEUED"), "Slot")
			s.modulate = Color(1, 1, 1, 0.55)
			slots.add_child(s)
			used += 1
	for k in maxi(st.building_slots - used, 0):
		slots.add_child(_slot_cell(null, tr("ST_FREE_SLOT"), "Slot"))
	# bölge binaları (seviye çubukları)
	PanelLayout.section(_body, tr("ST_PROVINCIAL"))
	for b: String in PROVINCIAL:
		var lv := st.building_level(b)
		var mx := int(Economy.defs[b]["max"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.tooltip_text = "%s: %d / %d" % [Economy.building_name(b), lv, mx]
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		var ic := UiTheme.icon_texture(UiTheme.building_icon(b), 36)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(ic)
		var nl := UiTheme.make_label(Economy.building_name(b), 15)
		nl.custom_minimum_size.x = 150
		nl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(nl)
		var pips := HBoxContainer.new()
		pips.add_theme_constant_override("separation", 2)
		pips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for k in mini(mx, 10):
			var pip := ColorRect.new()
			pip.custom_minimum_size = Vector2(18, 14)
			pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			pip.color = UiTheme.ACCENT if k < lv else (Color(0.55, 0.45, 0.25, 0.6) if k < lv + int(queued.get(b, 0)) else Color(0, 0, 0, 0.55))
			pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pips.add_child(pip)
		row.add_child(pips)
		var lvl := UiTheme.make_label("%d" % lv, 15, UiTheme.ACCENT)
		lvl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(lvl)
		_body.add_child(row)
	# kaynaklar
	if not st.resources.is_empty():
		PanelLayout.section(_body, tr("ST_RESOURCES"))
		var rr := HFlowContainer.new()
		rr.add_theme_constant_override("h_separation", 6)
		_body.add_child(rr)
		for r: String in st.resources:
			var cell := PanelContainer.new()
			cell.theme_type_variation = "Slot"
			cell.tooltip_text = "%s: %d" % [tr("RES_" + r), st.resources[r]]
			cell.add_child(PanelLayout.icon_label(UiTheme.resource_icon(r), "%s %d" % [tr("RES_" + r), st.resources[r]], 32, 14))
			rr.add_child(cell)
	# doğrudan inşa (yalnız oyuncunun eyaleti; inşaat kapalıysa yok)
	if mine and Economy.CONSTRUCTION:
		PanelLayout.section(_body, tr("ST_BUILD_HERE"))
		var g := PanelLayout.grid(4)
		_body.add_child(g)
		for b: String in SHARED + PROVINCIAL:
			var err := Economy.can_build(player, st, b)
			var t := PanelLayout.tile(UiTheme.building_icon(b), Economy.building_name(b), UiTheme.format_number(Economy.defs[b]["cost"]),
				"%s\n%s\n\n%s" % [Economy.building_name(b), tr("BDESC_" + b), tr("TIP_BUILD_COST") % UiTheme.format_number(Economy.defs[b]["cost"])] + ("" if err == "" else "\n\n⚠ " + tr(err)), 80, 128)
			t.disabled = err != ""
			t.pressed.connect(func() -> void:
				if Economy.queue_building(player, st, b):
					World.notify(tr("ST_QUEUED_NOTE") % [Economy.building_name(b), st.display_name()], "good")
				_refresh())
			g.add_child(t)

func _build_country_card(st: StateRegion, c: Country) -> void:
	_quick_actions.clear()
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", CommandPanelSkin.box("inset", 10))
	_country_box.add_child(card)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	card.add_child(content)
	var identity := HBoxContainer.new()
	identity.add_theme_constant_override("separation", 12)
	content.add_child(identity)
	var flag := UiTheme.icon_texture(FlagFactory.get_flag(c), 48)
	flag.custom_minimum_size = Vector2(72, 48)
	identity.add_child(flag)
	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	labels.add_theme_constant_override("separation", 1)
	identity.add_child(labels)
	var country_name := UiTheme.make_label(c.display_name(), 20, UiTheme.ACCENT)
	country_name.add_theme_font_override("font", UiTheme.bold_font())
	country_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	labels.add_child(country_name)
	var relation := "DIPLO_REL_NEUTRAL"
	if Diplomacy.are_enemies(World.player_tag, c.tag): relation = "DIPLO_REL_WAR"
	elif Diplomacy.are_allies(World.player_tag, c.tag): relation = "DIPLO_REL_ALLY"
	var caption := tr("IDEOLOGY_" + c.ideology)
	if World.in_game and c.tag != World.player_tag: caption += " · " + tr(relation)
	var subtitle := UiTheme.make_label(caption, 13, UiTheme.BAD if relation == "DIPLO_REL_WAR" else UiTheme.TEXT_DIM)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	labels.add_child(subtitle)
	var controller := World.controller_of(_province_id)
	if controller and controller.tag != st.owner:
		var occupation := UiTheme.make_label(tr("UI_OCCUPIED") % controller.display_name(), 13, UiTheme.BAD)
		occupation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(occupation)
	var player := World.player()
	if not World.in_game or player == null or c.tag == player.tag or not c.exists() or not World.is_active(c.tag): return
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	content.add_child(grid)
	for entry: Dictionary in CountryDiplomacyActions.entries(player, c):
		var button := Button.new()
		button.text = entry.title
		button.icon = UiTheme.trimmed(CommandPanelSkin.icon(entry.icon))
		button.add_theme_constant_override("icon_max_width", 22)
		button.add_theme_font_size_override("font_size", 17)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 48)
		button.disabled = entry.error != ""
		button.tooltip_text = entry.tip + ("\n\n" + tr(entry.error) if entry.error != "" else "")
		button.set_meta("diplomatic_action_id", entry.key)
		button.set_meta("target_tag", c.tag)
		var action: String = entry.key
		var target_tag := c.tag
		var province_id := _province_id
		var actor_tag := player.tag
		button.pressed.connect(func() -> void:
			if actor_tag == World.player_tag: _request_quick_action(action, target_tag, province_id))
		if (entry.cost as Array).is_empty():
			grid.add_child(button)
		else:
			# bedeli olan eylem (savaş gerekçesi): bedel düğmenin yanında simgeyle
			var cell := HBoxContainer.new()
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cell.add_child(button)
			cell.add_child(PanelLayout.cost_chip(entry.cost, button.disabled))
			grid.add_child(cell)
		_quick_actions[action] = button
	if player.justify_progress.has(c.tag):
		content.add_child(UiTheme.make_label(tr("DIPLO_JUSTIFYING") % int(player.justify_progress[c.tag]), 13, UiTheme.ACCENT))
	elif player.war_goals.has(c.tag):
		content.add_child(UiTheme.make_label(tr("DIPLO_HAS_GOAL"), 13, UiTheme.BAD))

func _request_quick_action(action: String, target_tag: String, province_id: int) -> void:
	var context := {"player": World.player_tag, "target": target_tag, "province": province_id, "state": _state_id}
	if not _war_context_valid(context): return
	var target: Country = World.countries.get(target_tag)
	if CountryDiplomacyActions.blocked(World.player(), target, action) != "": return
	if action == "declare":
		_pending_war = context
		_war_confirmation.dialog_text = tr("QUICK_WAR_CONFIRM") % target.display_name()
		_war_confirmation.popup_centered(Vector2i(mini(540, int(get_viewport_rect().size.x) - 64), 260))
		_war_confirmation.get_cancel_button().grab_focus()
		return
	CountryDiplomacyActions.execute(World.player_tag, target_tag, action)
	_queue_refresh()

func _war_context_valid(context: Dictionary) -> bool:
	if not visible or not World.in_game or context.get("player") != World.player_tag or context.get("province") != _province_id or context.get("state") != _state_id: return false
	var st: StateRegion = World.states.get(_state_id)
	var p := World.province(_province_id)
	return st != null and p != null and p.state_id == _state_id and st.owner == context.get("target") and st.owner != World.player_tag

func _confirm_war() -> void:
	var context := _pending_war.duplicate()
	_cancel_war()
	if context.is_empty() or not _war_context_valid(context): return
	CountryDiplomacyActions.execute(context.player, context.target, "declare")
	_queue_refresh()

func _cancel_war() -> void:
	_pending_war.clear()
	if is_instance_valid(_war_confirmation): _war_confirmation.hide()

## Bina yuvası hücresi: sütun genişliğini doldurur, yüksek; içinde büyük bina ikonu
## Asker al: oyuncunun elindeki şehirde (tıklanan bölge şehir değilse eyaletin en büyük şehri) birlik türleri, bedelleri ve
## "Al" düğmesi; alınamıyorsa düğme kapalı, ipucu nedenini söyler (Military.recruit, data/common/recruit.json)
func _recruit_section(st: StateRegion, p: Province) -> void:
	var player := World.player()
	if player == null or not World.in_game:
		return
	var city: City = p.city if p.city else st.largest_city()
	if city == null or World.controller_tag(city.province_id) != player.tag:
		return
	PanelLayout.section(_body, tr("RECRUIT_HEAD") % city.display_name())
	# bina kutucukları gibi yan yana kutucuklar: resim, ad, hazır olma, altta simgeli bedel; tıklayınca alınır
	var grid := PanelLayout.grid(3)
	_body.add_child(grid)
	var units: Dictionary = Military.recruit_def()["units"]
	var port := Navy.port_in_state(player.tag, st.id)
	for kind: String in units:
		var u: Dictionary = units[kind]
		var sub := ""
		var costs: Array = [["sp", float(u["sp"]), player.sp]]
		if u.has("template"):
			var mp := int(Military.stats(player, Military.recruit_template(player, kind))["manpower"])
			costs.append(["manpower", float(mp), float(player.available_manpower())])
			sub = tr("RECRUIT_COST_DIV") % Military.recruit_days(player, kind)
		elif u.has("ship"):
			if port == 0:
				continue                  # gemi yalnız deniz üssü olan eyaletin limanında alınır
			sub = tr("RECRUIT_COST_SHIP")
		else:
			sub = tr("RECRUIT_COST_WING")
		var err := Military.recruit_error(player, kind, city.province_id)
		var why: String = tr(err) % Research.tech_name(Military.recruit_tech(kind)) if err == "RECRUIT_ERR_TECH" else tr(err)
		var pid := city.province_id
		var cname := city.display_name()
		var uname := tr("RECRUIT_UNIT_" + kind)
		grid.add_child(_recruit_tile(UiTheme.icon_or(String(u.get("icon", "army")), "army"), uname, sub, costs, err != "",
			"%s\n%s\n\n%s" % [uname, sub, why if err != "" else tr("TIP_RECRUIT")], func() -> void:
				var e := Military.recruit(player, kind, pid)
				if e == "":
					World.notify(tr("RECRUIT_OK") % [uname, cname], "good")
					Audio.play("order_move", 150)
				else:
					World.notify(tr(e), "bad")
				_refresh()))

## Asker alma kutucuğu (bina kutucuğuyla aynı "Card" düğmesi): üstte resim, ad, hazır olma süresi, altta bedel (her
## bedel bir satırda, simgeli; yetmiyorsa kırmızı); alınamıyorsa soluk, nedeni ipucunda
func _recruit_tile(icon: Texture2D, title: String, sub: String, costs: Array, off: bool, tip: String, buy: Callable) -> Button:
	var b := Button.new()
	b.theme_type_variation = "Card"
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(96, 168)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.tooltip_text = tip
	b.disabled = off
	b.pressed.connect(buy)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 6
	v.offset_right = -6
	v.offset_top = 8
	v.offset_bottom = -8
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var ic := TextureRect.new()
	ic.texture = UiTheme.trimmed(icon)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.custom_minimum_size = Vector2(0, 52)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(ic)
	for line: Array in [[title, 13, UiTheme.TEXT], [sub, 11, UiTheme.TEXT_DIM]]:
		var l := UiTheme.make_label(String(line[0]), int(line[1]), line[2])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(l)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(fill)
	for cost: Array in costs:
		var chip := PanelLayout.cost_chip([cost], off)
		chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(chip)
	return b

func _slot_cell(tex: Texture2D, tip: String, variant: String) -> PanelContainer:
	var pc := PanelLayout.slot(tex, 64, tip, variant)
	pc.custom_minimum_size = Vector2(0, 64)
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return pc

func _on_play_pressed() -> void:
	if _state_id > 0:
		World.set_player(World.states[_state_id].owner)
