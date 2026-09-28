class_name Hud
extends CanvasLayer
## Tüm oyun arayüzünün kökü: üst bar, görev çubuğu, sol paneller, tümen paneli, olaylar, bildirimler, menüler.

signal construction_toggled(open: bool)

var root: Control
var top_bar: TopBar
var state_panel: StatePanel
var tooltip: MapTooltip
var ui_tooltip: HoverTooltip
var map_modes: MapModeBar
var construction: ConstructionPanel
var production: ProductionPanel
var politics: PoliticsPanel
var trade: TradePanel
var army: ArmyPanel
var research: ResearchPanel
var diplomacy: DiplomacyPanel
var navy: NavyPanel
var air: AirPanel
var logistics: LogisticsPanel
var focus: FocusPanel
var divisions: DivisionPanel
var events: EventPopup
var feed: NotificationFeed
var pause_menu: PauseMenu
var game_over: GameOverScreen
var task_bar: VBoxContainer
var alerts: AlertBar
var select_box: Panel

func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.get_theme()
	add_child(root)

	top_bar = TopBar.new()
	root.add_child(top_bar)
	state_panel = StatePanel.new()
	root.add_child(state_panel)
	map_modes = MapModeBar.new()
	root.add_child(map_modes)
	construction = ConstructionPanel.new()
	production = ProductionPanel.new()
	politics = PoliticsPanel.new()
	trade = TradePanel.new()
	army = ArmyPanel.new()
	research = ResearchPanel.new()
	diplomacy = DiplomacyPanel.new()
	navy = NavyPanel.new()
	air = AirPanel.new()
	logistics = LogisticsPanel.new()
	for p in [construction, production, politics, trade, army, navy, air, research, diplomacy, logistics]:
		root.add_child(p)
		_decorate_side_panel(p)
	focus = FocusPanel.new()
	politics.focus_requested.connect(func() -> void: toggle_focus())
	politics.diplomacy_requested.connect(func(tag: String) -> void:
		_close_all()
		diplomacy.open_for(tag))
	root.add_child(focus)
	divisions = DivisionPanel.new()
	root.add_child(divisions)
	divisions.manage_army.connect(func(id: int) -> void:
		_close_all()
		army.open_army(id))
	feed = NotificationFeed.new()
	feed.hud = self
	root.add_child(feed)
	task_bar = top_bar.task_row
	var tasks := [
		["TASK_POLITICS", "politics", toggle_politics, "menu_politics"], ["TASK_FOCUS", "focus_g_unity", toggle_focus, "menu_focus"],
		["TASK_RESEARCH_KEY", "research", toggle_research, "menu_research"], ["TASK_DIPLOMACY_KEY", "diplomacy", toggle_diplomacy, "menu_diplomacy"],
		["TASK_TRADE", "trade", toggle_trade, "menu_trade"], ["CONSTRUCTION_BUTTON", "construction", toggle_construction, "menu_construction"],
		["TASK_PRODUCTION", "production", toggle_production, "menu_production"], ["TASK_ARMY", "army", toggle_army, "menu_army"],
		["TASK_NAVY", "navy", toggle_navy, "menu_navy"], ["TASK_AIR", "air", toggle_air, "menu_air"],
		["TASK_LOGISTICS_KEY", "equipment_motorized_equipment", toggle_logistics, "menu_logistics"]]
	# kare simge düğmeleri: ad ipucunda, kısayol harfi köşede
	for t: Array in tasks:
		var b := Button.new()
		b.icon = UiTheme.trimmed(UiTheme.icon_or(t[3], t[1]))
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_constant_override("icon_max_width", 40)
		for spec: Array in [["normal", "menu_btn"], ["hover", "menu_btn_hover"], ["pressed", "menu_btn_pressed"], ["hover_pressed", "menu_btn_pressed"]]:
			var sb2 := UiTheme.skin(spec[1], 8, 1)          # resim düğmeyi doldursun (iç boşluk 1 px)
			b.add_theme_stylebox_override(spec[0], sb2)
		b.add_theme_color_override("icon_normal_color", Color(1.25, 1.2, 1.1))
		b.add_theme_color_override("icon_hover_color", Color(1.45, 1.4, 1.3))
		b.add_theme_color_override("icon_pressed_color", UiTheme.ACCENT)
		b.focus_mode = Control.FOCUS_NONE
		var label: String = tr(t[0])
		var tipkey: String = "TIP_" + String(t[0]).replace("_KEY", "")
		b.tooltip_text = "%s\n%s" % [label, tr(tipkey)]
		b.custom_minimum_size = Vector2(58, 52)
		b.pressed.connect(t[2])
		var m := RegEx.create_from_string("\\(([^)]+)\\)").search(label)
		if m:
			# kısayol harfi sağ alt köşede, okunsun diye küçük siyah zemin üstünde
			var kbg := PanelContainer.new()
			var ksb := StyleBoxFlat.new()
			ksb.bg_color = Color(0, 0, 0, 0.82)
			ksb.set_corner_radius_all(3)
			ksb.content_margin_left = 3
			ksb.content_margin_right = 3
			ksb.content_margin_top = 0
			ksb.content_margin_bottom = 0
			kbg.add_theme_stylebox_override("panel", ksb)
			kbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var k := UiTheme.make_label(m.get_string(1), 13, Color(1.0, 0.93, 0.75))
			k.add_theme_font_override("font", UiTheme.bold_font())
			k.mouse_filter = Control.MOUSE_FILTER_IGNORE
			k.add_theme_constant_override("line_spacing", 0)
			kbg.add_child(k)
			kbg.position = Vector2(42, 30)
			b.add_child(kbg)
		task_bar.add_child(b)
	alerts = AlertBar.new()
	alerts.hud = self
	alerts.strip = top_bar.alert_strip
	top_bar.alert_row.add_child(alerts)
	select_box = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.85, 0.4, 0.12)
	sb.border_color = Color(1.0, 0.85, 0.4, 0.9)
	sb.set_border_width_all(1)
	select_box.add_theme_stylebox_override("panel", sb)
	select_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	select_box.visible = false
	root.add_child(select_box)
	tooltip = MapTooltip.new()
	root.add_child(tooltip)
	ui_tooltip = HoverTooltip.new()
	root.add_child(ui_tooltip)
	events = EventPopup.new()
	root.add_child(events)
	game_over = GameOverScreen.new()
	root.add_child(game_over)
	pause_menu = PauseMenu.new()
	root.add_child(pause_menu)
	state_panel.diplomacy_requested.connect(func(tag: String) -> void:
		_close_all()
		diplomacy.open_for(tag))

const SIDE_X := PanelLayout.SIDE_LEFT      ## yan paneller sol menünün sağından açılır
const SIDE_Y := PanelLayout.SIDE_TOP

## Yan paneller: sol kenara sabit, başlıkta kapatma düğmesi, açılırken kayarak gelir
func _decorate_side_panel(p: Control) -> void:
	p.position = Vector2(SIDE_X, SIDE_Y)
	_add_close(p)
	p.visibility_changed.connect(func() -> void:
		Audio.panel(p.visible)
		if p.visible:
			p.position = Vector2(-p.size.x - 20.0, SIDE_Y)
			p.modulate.a = 0.0
			var tw := p.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(p, "position:x", SIDE_X, 0.22)
			tw.parallel().tween_property(p, "modulate:a", 1.0, 0.18))

func _add_close(p: Control) -> void:
	if p is DiplomacyPanel:
		return          # kendi başlığını her yenilemede kurar
	if p.has_meta("framed"):
		return          # PanelLayout.frame başlığı kendi kapatma düğmesini taşır
	var v := p.get_child(0)
	if v == null or v.get_child_count() == 0 or not v.get_child(0) is Label:
		return
	var title: Label = v.get_child(0)
	var head := HBoxContainer.new()
	v.add_child(head)
	v.move_child(head, 0)
	title.reparent(head)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(UiTheme.icon_button("close", tr("TIP_CLOSE"), func() -> void: close_panels()))

func is_mouse_over_ui() -> bool:
	var c := root.get_viewport().gui_get_hovered_control()
	return c != null and c != root

## Tam ekran bir panel (odak ağacı, araştırma) açık mı: açıkken harita hiçbir girdiyle kıpırdamaz
func fullscreen_open() -> bool:
	if focus != null and focus.visible:
		return true
	for p in _left_panels():
		if p != null and p.visible and p.has_meta("fullscreen"):
			return true
	return false

func _left_panels() -> Array:
	return [construction, production, politics, trade, army, navy, air, research, diplomacy, logistics]

func _close_all() -> void:
	for p in _left_panels():
		if p.visible:
			p.close()
	if focus.visible:
		focus.close()
	state_panel.visible = false

## Sol paneller: aynı anda yalnız biri açık
func _open_only(panel: Control) -> void:
	var was_open := panel.visible
	_close_all()
	if not was_open:
		panel.open()
	construction_toggled.emit(construction.visible)

func any_panel_open() -> bool:
	for p in _left_panels():
		if p.visible:
			return true
	return focus.visible

func close_panels() -> void:
	_close_all()
	construction_toggled.emit(false)

func toggle_construction() -> void: _open_only(construction)
func toggle_production() -> void: _open_only(production)
func toggle_politics() -> void: _open_only(politics)
## Haritada Ctrl + tık: o ülkenin siyaset ekranı (başka ülkeyse salt okunur)
func show_politics_of(tag: String) -> void:
	_close_all()
	politics.open_country(tag)
	construction_toggled.emit(false)
func toggle_trade() -> void: _open_only(trade)
func toggle_army() -> void: _open_only(army)
func toggle_navy() -> void: _open_only(navy)
func toggle_air() -> void: _open_only(air)
func toggle_logistics() -> void: _open_only(logistics)
## Donanma panelini açık tut (filo seçilince)
func show_navy() -> void:
	if not navy.visible:
		_open_only(navy)
func toggle_research() -> void: _open_only(research)
func toggle_diplomacy() -> void:
	diplomacy.target = ""
	_open_only(diplomacy)
func toggle_focus() -> void:
	var was := focus.visible
	_close_all()
	if not was:
		focus.open()

## Oyun arayüzü yalnız oyun başlayınca görünür (menü/ülke seçiminde gizli)
func set_game_ui_visible(v: bool) -> void:
	top_bar.visible = v
	map_modes.visible = v
	task_bar.visible = v
	feed.visible = v
	if not v:
		_close_all()
