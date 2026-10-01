class_name ScenarioSelect
extends Control
## Senaryo seçimi (ana menü → Senaryolar): her senaryo bir kart — adı, başlangıç tarihi ve süresi, anlatımı, anahtar
## şehirler ve saldıranın kazanmak için tutması gereken puan; altta her taraf için "… ile oyna" düğmesi (bayraklı).
## Tanımlar data/scenarios/scenarios.json'dan (Game.scenarios).

signal start_pressed(id: String, tag: String)
signal back_pressed

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(820, 0)
	var sb := UiTheme.panel_style(Color(0.05, 0.06, 0.06, 0.94), UiTheme.BORDER)
	sb.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	var head := UiTheme.make_label(tr("SCEN_TITLE"), 30, UiTheme.ACCENT)
	head.add_theme_font_override("font", UiTheme.title_font())
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	var list: Array = Game.scenarios()
	if list.is_empty():
		PanelLayout.empty(v, tr("SCEN_NONE"))
	for sc: Dictionary in list:
		v.add_child(_card(sc))
	var back := PanelLayout.small_button(tr("SCEN_BACK"), func() -> void: back_pressed.emit())
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.custom_minimum_size = Vector2(160, 40)
	v.add_child(back)

func _card(sc: Dictionary) -> Control:
	var pc := PanelContainer.new()
	pc.theme_type_variation = "Row"
	UiTheme.pad(pc, 18, 14)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	pc.add_child(v)
	var title := UiTheme.make_label(Politics.loc(sc["name"]), 24, UiTheme.ACCENT)
	title.add_theme_font_override("font", UiTheme.title_font())
	v.add_child(title)
	# anahtar şehirlerin toplam puanı
	var total := 0
	var names: PackedStringArray = []
	for cid in sc["key_cities"]:
		var city := World.city_by_id(int(cid))
		if city:
			total += city.victory_points
			names.append("%s %d" % [city.display_name(), city.victory_points])
	var desc := UiTheme.make_label(Politics.loc(sc["desc"]), 16, UiTheme.TEXT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.x = 760
	v.add_child(desc)
	var info := UiTheme.make_label(tr("SCEN_INFO"), 15, UiTheme.TEXT_DIM)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size.x = 760
	v.add_child(info)
	var keys := UiTheme.make_label(tr("SCEN_KEY_CITIES") % ", ".join(names), 14, UiTheme.TEXT_DIM)
	keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	keys.custom_minimum_size.x = 760
	v.add_child(keys)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var sides: Array = sc["sides"]
	for i in sides.size():
		var tag := str(sides[i]["tag"])
		var c: Country = World.countries.get(tag)
		if c == null:
			continue
		var b := PanelLayout.small_button(tr("SCEN_PLAY_AS") % c.display_name(), func() -> void: start_pressed.emit(str(sc["id"]), tag),
			true, tr("SCEN_ATTACKER_TIP") % total if i == 0 else tr("SCEN_DEFENDER_TIP") % total)
		b.icon = FlagFactory.get_flag(c)
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 36)
		b.custom_minimum_size = Vector2(240, 46)
		row.add_child(b)
	return pc
