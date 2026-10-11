class_name ResearchPanel
extends PanelContainer
## Araştırma (I) — komuta paneli tasarımında zaman çizelgesi. Üstte süren araştırmalar (İncele kartı gösterir), altında
## sekmeler (Yönetim, Tümü, Kara, Deniz, Hava, Sanayi, Doktrin). Solda zaman çizelgesi: sütunlar yıllar (1936 … son tarihî
## yıl, en sonda iyileştirme seviyeleri "1943+"), satırlar dallar; her proje resimli bir kart (resim üstte, ad ve durum
## altta, sürerken ilerleme çubuğu), önkoşullar çizgiyle bağlı, bugünün tarihi kesik altın çizgi, geçmiş hafif gölgeli.
## Yıl başlığı ve dal adları kaydırırken yerinde kalır; çizelge tekerlek (Shift ile yana), dokunmatik yüzey ve sürüklemeyle
## yumuşak kayar, bırakılınca süzülerek durur (DragScroll smooth). Sekme değişince çizelge hafifçe belirir; seçilen kart
## görünmüyorsa çizelge ona süzülür. Kart yalnız seçer: sağdaki dosya etkileri, koşulları ve bedeli yazar; araştırma yalnız
## dosyadaki düğmeyle başlar / iptal edilir (ulusal proje önce onay ister). Yönetim sekmesi yıl dışı ulusal projeler.

const NODE := Vector2(156, 214)            ## Yönetim sekmesindeki büyük kart
const TL_CARD_W := 168.0                   ## çizelge kartı: genişlik, resim bandı ve yazı payı
const TL_THUMB := 84.0
const TL_CAPTION := 80.0
const COL_PAD := 14.0                      ## kartın sütun içindeki yan payı
const LANE_GAP := 14.0                     ## kartlar arası dikey boşluk
const LABEL_W := 150.0                     ## yerinde kalan dal adı sütunu
const HEAD_H := 40.0                       ## yerinde kalan yıl başlığı
const FADE := 0.18                         ## sekme ve dosya değişiminin yumuşak belirmesi (sn)

## Original artwork stays uncropped in a full-width top band. Its capped height
## keeps cards compact while reserving readable name/status space underneath.
class ProjectCard extends Button:
	const FRAME := 4.0
	const CAPTION_HEIGHT := 98.0
	const THUMBNAIL_HEIGHT := 108.0
	var thumbnail: TextureRect
	var thumb_cap := THUMBNAIL_HEIGHT       ## çizelge kartında daha kısa resim bandı ve yazı payı
	var caption := CAPTION_HEIGHT
	func _ready() -> void:
		resized.connect(_fit_thumbnail)
		_fit_thumbnail()
	func _fit_thumbnail() -> void:
		if thumbnail == null: return
		var side := minf(thumb_cap, maxf(size.x, custom_minimum_size.x) - FRAME * 2.0)
		thumbnail.custom_minimum_size.y = side
		custom_minimum_size.y = side + caption + FRAME * 2.0

## Çizelgenin içi: satır bantları, yıl sütunları, geçmiş gölgesi, bugün çizgisi, önkoşul çizgileri (kartlar üstünde)
class Timeline extends Control:
	var panel: ResearchPanel
	func _draw() -> void:
		panel._draw_timeline(self)

## Yerinde kalan yıl başlığı (yatay kaydırmayla birlikte kayar)
class TimelineHeader extends Control:
	var panel: ResearchPanel
	func _draw() -> void:
		panel._draw_header(self)

## Yerinde kalan dal adları sütunu (dikey kaydırmayla birlikte kayar)
class TimelineLabels extends Control:
	var panel: ResearchPanel
	func _draw() -> void:
		panel._draw_label_bands(self)

const CAT_ICON := {"governance": "politics", "infantry": "equipment_infantry_equipment",
	"artillery": "equipment_artillery_equipment", "armor": "equipment_medium_tank_equipment",
	"air": "air", "naval": "navy", "industry": "building_civilian_factory",
	"electronics": "research", "doctrine": "army"}
const BRANCHES := {"all": [], "governance": ["governance"], "army": ["infantry", "artillery", "armor"],
	"navy": ["naval"], "air": ["air"], "industry": ["industry", "electronics"], "doctrine": ["doctrine"]}

var _slots: GridContainer
var _speed: Label
var _nodes := {} # real technology ID -> selectable card Button
var _branch := "all"
var _tabs: Array[Button] = []
var _detail: VBoxContainer
var _detail_actions: VBoxContainer
var _catalog_scroll: ScrollContainer
var _detail_scroll: ScrollContainer
var _selected := ""
var _resize_pending := false
var _confirmation: ConfirmationDialog
var _pending_project := ""
var _start_button: Button
var _pending_project_focus := ""
var _canvas: Timeline
var _header: TimelineHeader
var _header_row: Control
var _labels: TimelineLabels
var _drag: DragScroll
var _rows: Array = []                      ## [dal, y, yükseklik] (çizelge içi)
var _col_w := TL_CARD_W + COL_PAD * 2.0
var _y0 := 1936
var _y1 := 1942
var _built_branch := ""                    ## son kurulan sekme: değişince çizelge başa döner ve hafifçe belirir
var _detail_shown := ""                    ## dosyada gösterilen proje: değişince dosya hafifçe belirir
var _focus_after_build := ""               ## yeniden kurulumdan sonra çizelgenin süzüleceği kart (İncele)

static func _gap(h: float) -> Control:
	var g := Control.new()
	g.custom_minimum_size.y = h
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	visible = false
	var body := PanelLayout.frame(self, tr("RESEARCH_TITLE"), "research", -1.0)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	(get_meta("scroll") as ScrollContainer).vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var top := PanelLayout.fixed(self)
	top.add_child(_gap(6))                    # süren araştırmalar üstünde ve altında boşluklu
	var rack := HBoxContainer.new()
	rack.add_theme_constant_override("separation", 12)
	top.add_child(rack)
	top.add_child(_gap(8))
	var head := VBoxContainer.new()
	head.custom_minimum_size.x = 144
	head.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rack.add_child(head)
	var sec := UiTheme.make_label(tr("RES_ACTIVE_PROJECTS"), 16, UiTheme.ACCENT)
	sec.add_theme_font_override("font", UiTheme.bold_font())
	head.add_child(sec)
	_speed = UiTheme.make_label("", 13, UiTheme.TEXT_DIM)
	_speed.tooltip_text = tr("RES_SPEED_TIP")
	head.add_child(_speed)
	_slots = PanelLayout.grid(4)
	_slots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rack.add_child(_slots)
	var filters := HBoxContainer.new()
	filters.name = "ResearchTabs"
	filters.add_theme_constant_override("separation", 6)
	top.add_child(filters)
	var tab_group := ButtonGroup.new()
	tab_group.allow_unpress = false
	var names := ["RES_ALL_PROJECTS", "RES_GOVERNANCE", "RES_ARMY", "RES_NAVY", "RES_AIR", "RES_INDUSTRY", "RES_DOCTRINE"]
	var icons := ["research", "politics", "army", "navy", "air", "building_civilian_factory", "equipment_support_equipment"]
	# seçili sekme çerçevesiz (dolgu ve alt çizgi); tıklayınca odak çerçevesi de çıkmaz
	var tab_on := CommandPanelSkin.tab_box("pressed", false)
	var tab_on_hover := CommandPanelSkin.tab_box("hover_pressed", false)
	var no_focus := StyleBoxEmpty.new()
	var index := 0
	for branch: String in BRANCHES:
		var tab := Button.new()
		tab.name = "ResearchTab_" + branch
		tab.theme_type_variation = "Tab"
		tab.toggle_mode = true
		tab.button_group = tab_group
		tab.focus_mode = Control.FOCUS_ALL
		tab.text = tr(names[index])
		tab.tooltip_text = tab.text
		tab.icon = CommandPanelSkin.icon(icons[index])
		tab.expand_icon = true
		tab.add_theme_constant_override("icon_max_width", 28)
		tab.add_theme_font_size_override("font_size", UiTheme.fs(18))
		tab.custom_minimum_size.y = 56
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.add_theme_stylebox_override("pressed", tab_on)
		tab.add_theme_stylebox_override("hover_pressed", tab_on_hover)
		tab.add_theme_stylebox_override("focus", no_focus)
		tab.pressed.connect(func() -> void: _set_branch(branch))
		filters.add_child(tab)
		_tabs.append(tab)
		index += 1
	top.add_child(_gap(10))                   # sekmelerden sonra çizelgeye boşluk
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(columns)
	_build_timeline_frame(columns)
	var dossier_column := VBoxContainer.new()
	dossier_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dossier_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dossier_column.add_theme_constant_override("separation", 10)
	columns.add_child(dossier_column)
	_detail_scroll = _scroll_column(dossier_column, "ResearchDossier", 1.0)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 12)
	_detail_scroll.add_child(_detail)
	_detail_actions = VBoxContainer.new()
	_detail_actions.name = "ResearchActions"
	_detail_actions.add_theme_constant_override("separation", 5)
	dossier_column.add_child(_detail_actions)
	_confirmation = ConfirmationDialog.new()
	_confirmation.title = tr("RES_CONFIRM_TITLE")
	_confirmation.dialog_autowrap = true
	_confirmation.theme = CommandPanelSkin.get_theme().duplicate()
	_confirmation.theme.set_stylebox("panel", "AcceptDialog", CommandPanelSkin.box("panel", 18))
	var window_border := ThemeDB.get_default_theme().get_stylebox("embedded_border", "Window").duplicate()
	if window_border is StyleBoxFlat:
		window_border.bg_color = Color("101719")
		window_border.border_color = Color("887045")
	_confirmation.theme.set_stylebox("embedded_border", "Window", window_border)
	_confirmation.theme.set_stylebox("embedded_unfocused_border", "Window", window_border)
	_confirmation.theme.set_color("title_color", "Window", UiTheme.ACCENT)
	_confirmation.ok_button_text = tr("RES_START_PROJECT")
	_confirmation.cancel_button_text = tr("RES_CONFIRM_CANCEL")
	_confirmation.confirmed.connect(_confirm_project)
	_confirmation.get_ok_button().set_meta("audio_silent", true)
	Audio.ui_bind(_confirmation.get_cancel_button(), "ui_close")
	add_child(_confirmation)
	for id: String in Research.techs:
		if _on_timeline(id):
			_y0 = mini(_y0, int(Research.techs[id]["year"]))
			_y1 = maxi(_y1, int(Research.techs[id]["year"]))
	Research.research_changed.connect(func(tag: String) -> void:
		if visible and tag == World.player_tag: refresh())
	World.daily_update.connect(func() -> void:
		if visible: refresh())
	# Only viewport changes, never our minimum-size/resized signal (rebuild loop).
	get_viewport().size_changed.connect(_queue_layout_refresh)

## Çizelge sütunu: üstte yerinde kalan yıl başlığı, solda yerinde kalan dal adları, ortada iki yöne yumuşak kayan kartlar
func _build_timeline_frame(columns: HBoxContainer) -> void:
	var left := VBoxContainer.new()
	left.name = "ResearchTimelineColumn"
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 2.0
	left.add_theme_constant_override("separation", 0)
	columns.add_child(left)
	_header_row = HBoxContainer.new()
	_header_row.add_theme_constant_override("separation", 0)
	left.add_child(_header_row)
	var corner := Control.new()
	corner.custom_minimum_size = Vector2(LABEL_W, HEAD_H)
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header_row.add_child(corner)
	var header_clip := Control.new()
	header_clip.clip_contents = true
	header_clip.custom_minimum_size.y = HEAD_H
	header_clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header_row.add_child(header_clip)
	_header = TimelineHeader.new()
	_header.panel = self
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_clip.add_child(_header)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(row)
	var labels_clip := Control.new()
	labels_clip.clip_contents = true
	labels_clip.custom_minimum_size.x = LABEL_W
	labels_clip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	labels_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(labels_clip)
	_labels = TimelineLabels.new()
	_labels.panel = self
	_labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	labels_clip.add_child(_labels)
	_catalog_scroll = ScrollContainer.new()
	_catalog_scroll.name = "ResearchCatalog"
	_catalog_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_catalog_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(_catalog_scroll)
	_drag = DragScroll.attach(_catalog_scroll, true, true)
	_canvas = Timeline.new()
	_canvas.name = "ResearchTimeline"
	_canvas.panel = self
	_canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	_catalog_scroll.add_child(_canvas)

func _scroll_column(parent: Container, node_name: String, ratio: float) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = node_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_stretch_ratio = ratio
	parent.add_child(scroll)
	DragScroll.attach(scroll)
	return scroll

## Yıl başlığı ve dal adları kartlarla birlikte kayar (yerinde kalan kenarlar)
func _process(_delta: float) -> void:
	if not visible or _catalog_scroll == null:
		return
	_header.position.x = -_catalog_scroll.scroll_horizontal
	_labels.position.y = -_catalog_scroll.scroll_vertical

func _queue_layout_refresh() -> void:
	if not visible or _resize_pending: return
	_resize_pending = true
	_finish_layout_refresh.call_deferred()

func _finish_layout_refresh() -> void:
	_resize_pending = false
	if visible: refresh()

func _set_branch(branch: String) -> void:
	if not BRANCHES.has(branch): return
	_branch = branch
	refresh()

func open() -> void:
	visible = true
	refresh.call_deferred()

func close() -> void:
	visible = false
	_pending_project = ""
	_pending_project_focus = ""
	_confirmation.hide()

## Çizelgedeki tarihî teknoloji mi (iyileştirme seviyeleri son sütunda, ulusal projeler Yönetim sekmesinde)
static func _on_timeline(id: String) -> bool:
	var t: Dictionary = Research.techs[id]
	return not t.get("repeat", false) and not Research.is_government_project(id) and String(t["cat"]) != "governance"

func refresh() -> void:
	var c := World.player()
	if c == null: return
	var focused := get_viewport().gui_get_focus_owner()
	var focused_project := ""
	if focused != null:
		for id: String in _nodes:
			var old_card: Control = _nodes[id]
			if focused == old_card or old_card.is_ancestor_of(focused):
				focused_project = id
				break
	elif _nodes.has(_pending_project_focus):
		# Two same-frame daily/research refreshes can happen before the first
		# deferred restore. Carry only a promise captured from a real card focus.
		focused_project = _pending_project_focus
	_pending_project_focus = focused_project
	var new_branch := _branch != _built_branch
	var scroll_at: Vector2 = Vector2.ZERO if new_branch else _drag.target()
	var detail_y := int(_detail_scroll.get_meta("scroll_restore_value", _detail_scroll.scroll_vertical))
	_clear(_canvas)
	_clear(_labels)
	_nodes.clear()
	_rows.clear()
	_refresh_slots()
	for i in _tabs.size():
		_tabs[i].set_pressed_no_signal(BRANCHES.keys()[i] == _branch)
	if _branch == "governance":
		_build_projects(c)
	else:
		_build_timeline(c)
	if not _nodes.has(_selected):
		_selected = ""
		for id: String in _nodes:
			if Research.can_research(c, id):
				_selected = id
				break
		if _selected == "" and not _nodes.is_empty(): _selected = _nodes.keys()[0]
	_refresh_detail()
	for id: String in _nodes: _nodes[id].set_pressed_no_signal(id == _selected)
	_detail_scroll.set_meta("scroll_restore_value", detail_y)
	_restore_scroll.call_deferred(weakref(_detail_scroll), detail_y)
	_restore_timeline.call_deferred(scroll_at)
	if new_branch:
		_built_branch = _branch
		for layer: CanvasItem in [_canvas, _labels, _header]:
			layer.modulate.a = 0.0
			create_tween().tween_property(layer, "modulate:a", 1.0, FADE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if focused_project != "" and _nodes.has(focused_project):
		_restore_project_focus.call_deferred(weakref(_nodes[focused_project]), focused_project)
	else:
		_pending_project_focus = ""
	PanelLayout.queue_fit(self)

## Yeniden kurulan çizelgede konum korunur (günlük yenileme kaydırmayı sıfırlamasın); düzen oturduktan sonra
func _restore_timeline(point: Vector2, after_layout := false) -> void:
	if not is_instance_valid(_drag):
		return
	if not after_layout:
		_restore_timeline.call_deferred(point, true)
		return
	_drag.jump_to(point)
	if _focus_after_build != "":
		_ensure_visible(_focus_after_build)
		_focus_after_build = ""

## Çizelge: her dal bir satır, her yıl bir sütun; aynı yıla düşen projeler alt alta (şerit). Son sütun iyileştirme
func _build_timeline(c: Country) -> void:
	var years := _y1 - _y0 + 2
	var card_h := TL_THUMB + TL_CAPTION + ProjectCard.FRAME * 2.0
	var lane_h := card_h + LANE_GAP
	_col_w = TL_CARD_W + COL_PAD * 2.0
	var y := 0.0
	for cat: String in Research.categories:
		if cat == "governance" or (_branch != "all" and cat not in BRANCHES[_branch]):
			continue
		var per_year := {}
		for id: String in Research.techs:
			if String(Research.techs[id]["cat"]) != cat or not _on_timeline(id):
				continue
			var yr := int(Research.techs[id]["year"])
			if not per_year.has(yr):
				per_year[yr] = []
			per_year[yr].append(id)
		var rep := Research.next_repeat(c, cat)
		if per_year.is_empty() and rep == "":
			continue
		var lanes := 1
		for yr: int in per_year:
			lanes = maxi(lanes, (per_year[yr] as Array).size())
		var h := lanes * lane_h + LANE_GAP
		_rows.append([cat, y, h])
		_row_label(cat, y, h)
		for yr: int in per_year:
			var ids: Array = per_year[yr]
			ids.sort()
			for lane in ids.size():
				_place(c, ids[lane], Vector2((yr - _y0) * _col_w + COL_PAD, y + LANE_GAP + lane * lane_h), card_h)
		if rep != "":
			_place(c, rep, Vector2((years - 1) * _col_w + COL_PAD, y + LANE_GAP), card_h)
		y += h
	var width := years * _col_w
	_canvas.custom_minimum_size = Vector2(width, y + LANE_GAP)
	_canvas.size = _canvas.custom_minimum_size
	_header.custom_minimum_size = Vector2(width, HEAD_H)
	_header.size = _header.custom_minimum_size
	_labels.size = Vector2(LABEL_W, y + LANE_GAP)
	_header_row.visible = true
	_canvas.queue_redraw()
	_header.queue_redraw()
	_labels.queue_redraw()

## Yönetim sekmesi: yönetim geçişleri (yılı yok) tek sırada büyük kartlar
func _build_projects(c: Country) -> void:
	var card_h := minf(ProjectCard.THUMBNAIL_HEIGHT, NODE.x - ProjectCard.FRAME * 2.0) + ProjectCard.CAPTION_HEIGHT + ProjectCard.FRAME * 2.0
	var x := COL_PAD
	for id: String in Research.techs:
		if not Research.is_government_project(id):
			continue
		var card := _project_card(c, id)
		card.position = Vector2(x, LANE_GAP)
		card.size = Vector2(NODE.x, card_h)
		_canvas.add_child(card)
		_nodes[id] = card
		x += NODE.x + COL_PAD
	var h := card_h + LANE_GAP * 2.0
	_rows.append(["governance", 0.0, h])
	_row_label("governance", 0.0, h)
	_canvas.custom_minimum_size = Vector2(x, h)
	_canvas.size = _canvas.custom_minimum_size
	_labels.size = Vector2(LABEL_W, h)
	_header_row.visible = false
	_canvas.queue_redraw()
	_labels.queue_redraw()

func _place(c: Country, id: String, pos: Vector2, card_h: float) -> void:
	var card := _project_card(c, id, true)
	card.position = pos
	card.size = Vector2(TL_CARD_W, card_h)
	_canvas.add_child(card)
	_nodes[id] = card

func _row_label(cat: String, y: float, h: float) -> void:
	var box := HBoxContainer.new()
	box.position = Vector2(10, y)
	box.size = Vector2(LABEL_W - 18, h)
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := UiTheme.icon_texture(CommandPanelSkin.icon(CAT_ICON.get(cat, "research")), 27)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(ic)
	var l := UiTheme.make_label(Research.category_name(cat).to_upper(), 16, Color("e7c47e"))
	l.add_theme_font_override("font", UiTheme.bold_font())
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(l)
	_labels.add_child(box)

## Seçilen kart görünmüyorsa çizelge ona yumuşakça süzülür (kart ortalanır)
func _ensure_visible(id: String) -> void:
	var card: Control = _nodes.get(id)
	if card == null or not is_instance_valid(card):
		return
	var view := _catalog_scroll.size
	var at := _drag.target()
	var r := Rect2(card.position, card.size)
	if r.position.x >= at.x and r.end.x <= at.x + view.x and r.position.y >= at.y and r.end.y <= at.y + view.y:
		return
	_drag.scroll_to(r.get_center() - view * 0.5)

func _restore_project_focus(reference: WeakRef, id: String) -> void:
	if _pending_project_focus != id: return
	var card := reference.get_ref() as Control
	if not is_instance_valid(card) or card.is_queued_for_deletion() or _nodes.get(id) != card: return
	_pending_project_focus = ""
	if not card.is_inside_tree() or not card.is_visible_in_tree(): return
	# A user may move into a branch tab/dossier while layout is pending; never
	# steal that newer focus. Restoring focus is inspection, not activation.
	if card.get_viewport().gui_get_focus_owner() == null: card.grab_focus()

static func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

static func _restore_scroll(reference: WeakRef, value: int, after_layout := false) -> void:
	var scroll := reference.get_ref() as ScrollContainer
	if not is_instance_valid(scroll) or scroll.is_queued_for_deletion(): return
	if not after_layout:
		ResearchPanel._restore_scroll.call_deferred(reference, value, true)
		return
	# A branch/selection change may cancel or replace this deferred restoration.
	if int(scroll.get_meta("scroll_restore_value", -1)) != value: return
	scroll.scroll_vertical = value
	scroll.remove_meta("scroll_restore_value")

func _project_card(c: Country, id: String, compact := false) -> Button:
	var card := ProjectCard.new()
	card.set_meta("audio_silent", true)
	card.name = "Project_" + id
	card.custom_minimum_size = Vector2(TL_CARD_W, 0) if compact else NODE
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.focus_mode = Control.FOCUS_ALL
	card.toggle_mode = true
	card.clip_contents = true
	card.set_meta("tech_id", id)
	card.tooltip_text = _project_tip(c, id)
	if compact:
		card.thumb_cap = TL_THUMB
		card.caption = TL_CAPTION
	var running := _active(c, id)
	var done := id in c.research_done and not Research.is_government_project(id)
	# çerçevesiz: seçili kart sıcak dolgulu, süren kartı ilerleme çubuğu ve yazısı belli eder
	var style := "good" if done and not running else "card"
	card.add_theme_stylebox_override("normal", CommandPanelSkin.box(style, 4))
	card.add_theme_stylebox_override("hover", CommandPanelSkin.box("hover", 4))
	card.add_theme_stylebox_override("pressed", CommandPanelSkin.selected_plain(4))
	card.add_theme_stylebox_override("hover_pressed", CommandPanelSkin.selected_plain(4, true))
	card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 4)
	card.add_child(margin)
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 0)
	margin.add_child(stack)
	var art := TextureRect.new()
	art.name = "Thumbnail"
	art.texture = _tech_icon(id)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art.custom_minimum_size.y = card.thumb_cap
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.thumbnail = art
	stack.add_child(art)
	var caption := MarginContainer.new()
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.size_flags_vertical = Control.SIZE_EXPAND_FILL
	caption.add_theme_constant_override("margin_left", 8 if compact else 10)
	caption.add_theme_constant_override("margin_right", 8 if compact else 10)
	caption.add_theme_constant_override("margin_top", 6 if compact else 8)
	caption.add_theme_constant_override("margin_bottom", 6 if compact else 8)
	stack.add_child(caption)
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_constant_override("separation", 3 if compact else 6)
	caption.add_child(text)
	var title := UiTheme.make_label(Research.tech_name(id), 15 if compact else 18, UiTheme.TEXT)
	title.name = "ProjectTitle"
	title.add_theme_font_override("font", UiTheme.bold_font())
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.max_lines_visible = 2
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.custom_minimum_size.y = 38 if compact else 48
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(title)
	var status := tr("RES_DONE") if done else (tr("RES_RUNNING") if running else "%d %s" % [ceili(Research.days_needed(c, id)), tr("UI_DAYS")])
	if _current_government(c, id): status = tr("RES_CURRENT_GOVERNMENT")
	var label := UiTheme.make_label(status, 13 if compact else 14, UiTheme.GOOD if done else (UiTheme.ACCENT if running else UiTheme.TEXT_DIM))
	label.name = "ProjectStatus"
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(label)
	if running: text.add_child(PanelLayout.progress(_progress(c, id), UiTheme.ACCENT, 4))
	card.pressed.connect(func() -> void:
		Audio.research_cue(id, "select")
		_selected = id
		for key: String in _nodes: _nodes[key].set_pressed_no_signal(key == id)
		_detail_scroll.scroll_vertical = 0
		_detail_scroll.remove_meta("scroll_restore_value")
		_refresh_detail()
		_ensure_visible(id))
	return card

func _refresh_detail() -> void:
	_clear(_detail)
	_clear(_detail_actions)
	_start_button = null
	var c := World.player()
	if c == null or not Research.techs.has(_selected): return
	var id := _selected
	if id != _detail_shown:
		# başka bir proje seçildi: dosya hafifçe belirir (aynı projenin günlük yenilemesi titremez)
		_detail_shown = id
		_detail.modulate.a = 0.0
		create_tween().tween_property(_detail, "modulate:a", 1.0, FADE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var t: Dictionary = Research.techs[id]
	var body := CommandPanelSkin.section(_detail, tr("RES_PROJECT_DOSSIER"), CAT_ICON.get(t["cat"], "research"))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	body.add_child(head)
	head.add_child(UiTheme.icon_texture(_tech_icon(id), 96))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(col)
	var title := _paragraph(Research.tech_name(id), 22, UiTheme.ACCENT)
	title.add_theme_font_override("font", UiTheme.bold_font())
	col.add_child(title)
	col.add_child(_paragraph(Research.category_name(t["cat"]), 14, UiTheme.TEXT_DIM))
	if not Research.is_government_project(id): col.add_child(UiTheme.make_label(str(int(t["year"])), 16, UiTheme.TEXT_DIM))
	var running := _active(c, id)
	var done := id in c.research_done
	var days := _remaining(c, id) if running else Research.days_needed(c, id)
	PanelLayout.stat(body, tr("RES_DURATION"), "%d %s" % [ceili(days), tr("UI_DAYS")], "", UiTheme.ACCENT)
	if running: body.add_child(PanelLayout.progress(_progress(c, id), UiTheme.ACCENT, 6))
	if Research.is_government_project(id):
		var summary := Research.project_summary(c, id)
		var target: String = summary["target_ideology"]
		if target != "": body.add_child(_paragraph(tr("RES_GOVERNMENT_RESULT") % tr("IDEOLOGY_" + target), 17, UiTheme.TEXT))
		body.add_child(_paragraph(summary["description"], 16, UiTheme.TEXT_DIM))
		# peşin bedel simgeyle (nüfuz); ayrıntısı ipucunda
		var cost_value := PanelLayout.stat(body, tr("RES_UPFRONT_COST"), "", Research.project_costs_text(c, id), UiTheme.ACCENT)
		var cost_row := cost_value.get_parent()
		cost_row.remove_child(cost_value)
		cost_value.queue_free()
		cost_row.add_child(PanelLayout.cost_chip([["influence", float(summary["political_power_cost"]), c.political_power]]))
		body.add_child(_paragraph(tr("RES_TRANSITION_EFFECTS"), 16, UiTheme.ACCENT))
		var mods: Dictionary = summary["temporary_mods"]
		for key: String in ["stability", "war_support", "political_power_gain"]:
			var value := roundi(float(mods.get(key, 0)) * 100)
			var amount := (tr("RES_CHANGE_POINTS") % value) if key != "political_power_gain" else "%+d%%" % value
			PanelLayout.stat(body, tr("MOD_" + key), amount, "", Color("cfaaa0"))
		body.add_child(_paragraph(tr("RES_REQUIREMENTS"), 16, UiTheme.ACCENT))
		body.add_child(_paragraph(tr("RES_GOVERNMENT_REQUIREMENTS") % roundi(float(summary["minimum_stability"]) * 100), 15, UiTheme.TEXT_DIM))
		body.add_child(_paragraph(tr("RES_CALENDAR_RULE"), 13, UiTheme.TEXT_DIM))
	else:
		body.add_child(_paragraph(tr("RES_EFFECTS"), 16, UiTheme.ACCENT))
		var effects := Politics.describe_mods(t.get("effects", {}))
		for unlock: String in t.get("unlock", []):
			if effects != "": effects += "\n"
			effects += tr("RESEARCH_UNLOCK") % Economy.equipment_name(unlock)
		body.add_child(_paragraph(effects if effects != "" else tr("RES_UNLOCK_NEXT"), 17, UiTheme.TEXT))
		var reqs: Array = t.get("req", [])
		if not reqs.is_empty():
			var names := PackedStringArray()
			for req: String in reqs: names.append(("✓ " if req in c.research_done else "• ") + Research.tech_name(req))
			body.add_child(_paragraph(tr("RES_REQUIREMENTS"), 16, UiTheme.ACCENT))
			body.add_child(_paragraph("\n".join(names), 15, UiTheme.TEXT_DIM))
		var ahead := maxi(int(t["year"]) - GameClock.year, 0)
		if ahead > 0 and not done:
			body.add_child(_paragraph(tr("RESEARCH_AHEAD") % [ahead, roundi(ahead * Research.AHEAD_PENALTY * 100)], 15, UiTheme.ACCENT))
	var reason: String = Research.can_start_reason(c, id) if not running and not done else ""
	if reason != "": body.add_child(_paragraph(reason, 15, UiTheme.TEXT_DIM))
	_start_button = Button.new()
	# Successful start/cancel cues come from the core research signals.
	_start_button.set_meta("audio_silent", true)
	_start_button.name = "ResearchProjectAction"
	_start_button.text = tr("RES_CANCEL_PROJECT") if running else (tr("RES_DONE") if done else tr("RES_START_PROJECT"))
	if _current_government(c, id): _start_button.text = tr("RES_CURRENT_GOVERNMENT")
	_start_button.custom_minimum_size.y = 48
	_start_button.add_theme_font_size_override("font_size", UiTheme.fs(18))
	_start_button.disabled = done or (not running and reason != "")
	_start_button.tooltip_text = reason
	_start_button.pressed.connect(_activate_selected)
	_detail_actions.add_child(_start_button)
	if running and Research.is_government_project(id):
		_detail_actions.add_child(_paragraph(tr("RES_CANCEL_NO_REFUND"), 13, UiTheme.TEXT_DIM))

func _activate_selected() -> void:
	var c := World.player()
	if c == null or not Research.techs.has(_selected): return
	if _active(c, _selected):
		Research.cancel(c, _selected)
		refresh()
	elif Research.can_start_reason(c, _selected) == "":
		if Research.is_government_project(_selected):
			_pending_project = _selected
			_confirmation.dialog_text = Research.tech_name(_selected) + "\n\n" + Research.project_costs_text(c, _selected)
			_confirmation.popup_centered(Vector2i(mini(580, int(get_viewport_rect().size.x) - 80), 380))
			Audio.play("ui_open")
		else:
			Research.start(c, _selected)
			refresh()

func _confirm_project() -> void:
	var c := World.player()
	if c != null and _pending_project != "":
		Research.start(c, _pending_project) # Revalidates costs/conditions at confirmation.
	_pending_project = ""
	refresh()

static func _paragraph(text: String, font_size: int, color: Color) -> Label:
	var label := UiTheme.make_label(text, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _project_tip(c: Country, id: String) -> String:
	var t: Dictionary = Research.techs[id]
	var tip := Research.tech_name(id)
	if Research.is_government_project(id): return tip + "\n" + Research.project_costs_text(c, id)
	tip += "\n" + Politics.describe_mods(t.get("effects", {}))
	for unlock: String in t.get("unlock", []): tip += "\n" + tr("RESEARCH_UNLOCK") % Economy.equipment_name(unlock)
	var names := PackedStringArray()
	for req: String in t.get("req", []): names.append(Research.tech_name(req))
	if not names.is_empty(): tip += "\n" + tr("RESEARCH_REQ") % ", ".join(names)
	return tip

static func _tech_icon(id: String) -> Texture2D:
	if Research.is_government_project(id): return load("res://assets/ui/command_panels/statecraft_v1.png")
	if Research.is_repeat(id): return CommandPanelSkin.illustration(CAT_ICON.get(Research.techs[id]["cat"], "research"))
	if UiTheme.PAINTED_ATLAS.has("tech_" + id): return UiTheme._painted_icon("tech_" + id)
	return UiTheme.technology_icon(id)

static func _active(c: Country, id: String) -> bool:
	for entry: Dictionary in c.research_current:
		if entry["tech"] == id: return true
	return false

static func _current_government(c: Country, id: String) -> bool:
	return Research.is_government_project(id) and str(Research.techs[id]["target_ideology"]) == c.ideology

static func _progress(c: Country, id: String) -> float:
	return Research.project_progress(c, id)

static func _remaining(c: Country, id: String) -> float:
	return Research.remaining_days(c, id)

# ------------------------------------------------------------------ çizim
const BAND := Color(1, 1, 1, 0.035)
const RULE := Color(0.55, 0.47, 0.3, 0.3)
const DUE := Color(0.95, 0.78, 0.35)

## Bugünün çizelgedeki yatay konumu (tarihî yıllardan sonra son sütunun içinde kalır)
func _today_x() -> float:
	var frac := ((GameClock.month - 1) * 30.44 + GameClock.day) / 365.25
	return minf((GameClock.year - _y0 + frac) * _col_w, (_y1 - _y0 + 2) * _col_w - 2.0)

func _draw_timeline(ctrl: Control) -> void:
	var c := World.player()
	var w := ctrl.size.x
	for i in _rows.size():
		var r: Array = _rows[i]
		if i % 2 == 0:
			ctrl.draw_rect(Rect2(0, r[1], w, r[2]), BAND)
		ctrl.draw_line(Vector2(0, r[1]), Vector2(w, r[1]), Color(RULE, 0.25), 1.0)
	if _branch == "governance":
		return
	var years := _y1 - _y0 + 2
	for k in years:
		ctrl.draw_line(Vector2(k * _col_w, 0), Vector2(k * _col_w, ctrl.size.y), RULE, 1.0)
	# geçmiş hafif gölgeli, bugün kesik altın çizgi
	var tx := _today_x()
	ctrl.draw_rect(Rect2(0, 0, tx, ctrl.size.y), Color(0, 0, 0, 0.16))
	ctrl.draw_dashed_line(Vector2(tx, 0), Vector2(tx, ctrl.size.y), Color(DUE, 0.45), 1.5, 6.0)
	# önkoşul çizgileri: önceki kartın sağından sonrakinin soluna (aynı sütundaysa alttan üste)
	for id: String in _nodes:
		var to: Control = _nodes[id]
		var reqs: Array = Research.techs[id].get("req", [])
		if Research.techs[id].get("repeat", false):
			var last := 0
			for r: String in reqs:
				last = maxi(last, int(Research.techs[r]["year"]))
			reqs = reqs.filter(func(r: String) -> bool: return int(Research.techs[r]["year"]) == last)
		for req: String in reqs:
			if not _nodes.has(req):
				continue
			var from: Control = _nodes[req]
			var col := DUE if c and req in c.research_done else Color(0.5, 0.45, 0.35, 0.8)
			var a := from.position + Vector2(from.size.x, from.size.y * 0.5)
			var b := to.position + Vector2(0, to.size.y * 0.5)
			if b.x <= a.x + 4:
				a = from.position + Vector2(from.size.x * 0.5, from.size.y)
				b = to.position + Vector2(to.size.x * 0.5, 0)
				ctrl.draw_polyline(PackedVector2Array([a, Vector2(a.x, (a.y + b.y) * 0.5), Vector2(b.x, (a.y + b.y) * 0.5), b]), col, 2.0, true)
			else:
				var mid := (a.x + b.x) * 0.5
				ctrl.draw_polyline(PackedVector2Array([a, Vector2(mid, a.y), Vector2(mid, b.y), b]), col, 2.0, true)

func _draw_header(ctrl: Control) -> void:
	var years := _y1 - _y0 + 2
	var font := UiTheme.title_font()
	ctrl.draw_rect(Rect2(Vector2.ZERO, ctrl.size), Color(0, 0, 0, 0.22))
	for k in years:
		var x := k * _col_w
		ctrl.draw_line(Vector2(x, HEAD_H - 10), Vector2(x, HEAD_H), RULE, 1.0)
		var label := str(_y0 + k) if k < years - 1 else "%d+" % Research.rep_first_year
		var past := _y0 + k <= GameClock.year
		ctrl.draw_string(font, Vector2(x, 28), label, HORIZONTAL_ALIGNMENT_CENTER, _col_w, 24, UiTheme.ACCENT if past else UiTheme.TEXT_DIM)
	# bugün: başlık çizgisinde aşağı bakan küçük altın üçgen (yazı yok: yıl başlığıyla çakışmasın)
	var tx := _today_x()
	ctrl.draw_colored_polygon(PackedVector2Array([Vector2(tx - 7.0, HEAD_H - 9.0), Vector2(tx + 7.0, HEAD_H - 9.0), Vector2(tx, HEAD_H - 1.0)]), DUE)

func _draw_label_bands(ctrl: Control) -> void:
	for i in _rows.size():
		var r: Array = _rows[i]
		ctrl.draw_rect(Rect2(0, r[1], ctrl.size.x, r[2]), Color(0, 0, 0, 0.18) if i % 2 == 0 else Color(0, 0, 0, 0.1))
		ctrl.draw_line(Vector2(0, r[1]), Vector2(ctrl.size.x, r[1]), Color(RULE, 0.25), 1.0)

## İlerleme zemini: düğmenin/kutunun arkasında koyu zemin ve üstünde soldan dolan altın dolgu (sağ kenarı parlak).
## show_behind_parent: katmanlar düğmenin yazısının ve resminin arkasında kalır.
static func _progress_back(host: Control, bg: StyleBox, progress: float) -> void:
	var base := Panel.new()
	base.show_behind_parent = true
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	base.add_theme_stylebox_override("panel", bg)
	host.add_child(base)
	# dolgu: soldan sağa koyulaşan altın geçiş (ilerlemenin ucu en parlak), ucunda ince parlak çizgi
	var fill := TextureRect.new()
	fill.show_behind_parent = true
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var g := Gradient.new()
	g.set_color(0, Color(UiTheme.ACCENT.darkened(0.45), 0.10))
	g.set_color(1, Color(UiTheme.ACCENT.darkened(0.1), 0.42))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 64
	gt.height = 4
	fill.texture = gt
	fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fill.stretch_mode = TextureRect.STRETCH_SCALE
	if progress < 0.995:
		var edge := ColorRect.new()
		edge.color = Color(UiTheme.ACCENT.lightened(0.2), 0.9)
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		edge.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
		edge.offset_left = -2
		fill.add_child(edge)
	fill.anchor_top = 0.0
	fill.anchor_bottom = 1.0
	fill.anchor_left = 0.0
	fill.anchor_right = clampf(progress, 0.0, 1.0)
	fill.offset_left = 4
	fill.offset_top = 4
	fill.offset_bottom = -4
	fill.offset_right = -4 if progress >= 0.995 else 0
	host.add_child(fill)

func _refresh_slots() -> void:
	var c := World.player()
	if c == null: return
	_speed.text = tr("RES_SPEED") % roundi((Research.speed(c) - 1.0) * 100)
	_clear(_slots)
	var rack_width := maxf(get_viewport_rect().size.x - 340, 580)
	_slots.columns = clampi(int(rack_width / 270), 1, maxi(c.research_slots, 1))
	for i in c.research_slots:
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(0, 76)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.add_theme_stylebox_override("panel", CommandPanelSkin.box("inset", 8))
		_slots.add_child(slot)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		slot.add_child(row)
		var active := i < c.research_current.size()
		var id: String = c.research_current[i]["tech"] if active else ""
		row.add_child(UiTheme.icon_texture(_tech_icon(id) if active else CommandPanelSkin.icon("research"), 48))
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		var title := UiTheme.make_label(Research.tech_name(id) if active else tr("RES_AVAILABLE_SLOT") % (i + 1), 16, UiTheme.ACCENT)
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		col.add_child(title)
		if active:
			col.add_child(UiTheme.make_label("%d %s" % [ceili(_remaining(c, id)), tr("UI_DAYS")], 13, UiTheme.TEXT_DIM))
			col.add_child(PanelLayout.progress(_progress(c, id), UiTheme.ACCENT, 4))
			var inspect := Button.new()
			inspect.set_meta("audio_silent", true)
			inspect.set_meta("tech_id", id)
			inspect.text = tr("RES_INSPECT")
			inspect.custom_minimum_size = Vector2(64, 40)
			inspect.pressed.connect(func() -> void:
				Audio.research_cue(id, "select")
				_selected = id
				# kartın göründüğü sekmeye geç (ulusal proje: Yönetim, teknoloji: bulunduğu dal ya da Tümü)
				if Research.is_government_project(id):
					_branch = "governance"
				elif _branch == "governance" or (_branch != "all" and not String(Research.techs[id]["cat"]) in BRANCHES[_branch]):
					_branch = "all"
				_focus_after_build = id
				refresh())
			row.add_child(inspect)
		else:
			col.add_child(UiTheme.make_label(tr("RES_CHOOSE_PROJECT"), 13, UiTheme.TEXT_DIM))
