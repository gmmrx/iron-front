class_name PanelLayout
extends RefCounted
## Yan panel şablonu ve ortak parçalar: başlık bandı (ikon + başlık + kapat), tam boy kaydırmalı
## gövde, oyulmuş bölüm çubukları, gömük ikon yuvaları, istatistik satırları, sekmeler, pasta grafik.

const SIDE_TOP := 127.0       ## yan panellerin üst kenarı (portrenin ve üst satırın altı: TopBar.MENU_TOP)
const SIDE_LEFT := 128.0      ## yan panellerin sol kenarı: kaynak çubuğuyla aynı hizada (TopBar: EDGE + portre eni ~110 + 6)
const SIDE_RIGHT := 12.0
const WIDTH_SCALE := 1.25     ## paneller tasarım genişliğinden bu kadar geniş açılır (okunur yazı boyu için)
const SIDE_BOTTOM := 14.0

## Paneli çerçevele: başlık + kaydırmalı gövde. Gövde VBox'ı döner. Panelde meta "scroll" ve "body" saklanır.
## width: tasarım genişliği (WIDTH_SCALE ile büyütülür); width <= 0 ise panel tam ekran açılır (menünün sağından ekranın
## sağına). Kaydırma çubuğu yok: boş yerde basılı tutup sürükleyerek ya da tekerlekle kaydırılır (DragScroll).
static func frame(panel: PanelContainer, title: String, icon_name: String = "", width: float = 480.0) -> VBoxContainer:
	var fullscreen := width <= 0.0
	width = 1200.0 if fullscreen else width * WIDTH_SCALE
	panel.custom_minimum_size.x = width
	panel.set_meta("framed", true)
	CommandPanelSkin.apply(panel)
	if fullscreen:
		panel.set_meta("fullscreen", true)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)
	var head := PanelContainer.new()
	head.theme_type_variation = "Header"
	root.add_child(head)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	head.add_child(hb)
	if icon_name != "":
		var tex := CommandPanelSkin.icon(icon_name)
		if tex:
			hb.add_child(UiTheme.icon_texture(UiTheme.trimmed(tex), 38))
	var t := UiTheme.make_label(title.to_upper(), 26, UiTheme.ACCENT)
	t.add_theme_font_override("font", UiTheme.bold_font())
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.name = "Title"
	hb.add_child(t)
	var close := UiTheme.icon_button("close", TranslationServer.translate("TIP_CLOSE"), func() -> void:
		if panel.has_method("close"):
			panel.call("close")
		else:
			panel.visible = false, 36)
	hb.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(width - 30.0, 200.0)
	root.add_child(scroll)
	DragScroll.attach(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	scroll.add_child(body)
	panel.set_meta("scroll", scroll)
	panel.set_meta("body", body)
	panel.visibility_changed.connect(func() -> void:
		if panel.visible: queue_fit(panel))
	# kök görünüm sahneden uzun yaşar: sahne yeniden kurulunca (dil değişimi, kayıttan açma) silinen panel atlanır
	var panel_reference: WeakRef = weakref(panel)
	panel.get_viewport().size_changed.connect(func() -> void:
		var alive := panel_reference.get_ref() as Control
		if is_instance_valid(alive) and alive.visible: fit_full(alive))
	return body

## Collapse repeated minimum-size notifications and never defer a freed Control argument.
static func queue_fit(panel: Control) -> void:
	if not is_instance_valid(panel) or bool(panel.get_meta("fit_pending", false)): return
	panel.set_meta("fit_pending", true)
	var ref: WeakRef = weakref(panel)
	var apply := func() -> void:
		var alive: Control = ref.get_ref()
		if is_instance_valid(alive):
			alive.set_meta("fit_pending", false)
			fit_full(alive)
	apply.call_deferred()

static func set_title(panel: Control, title: String) -> void:
	var l := panel.find_child("Title", true, false) as Label
	if l:
		l.text = title.to_upper()

## Panel ekranın altına kadar uzanır (tam boy yan panel)
static func fit_full(panel: Control) -> void:
	if not panel.has_meta("scroll") or not panel.is_inside_tree():
		return
	var scroll: ScrollContainer = panel.get_meta("scroll")
	var vp := panel.get_viewport_rect().size
	var avail := vp.y - SIDE_TOP - SIDE_BOTTOM
	if panel.has_meta("fullscreen"):
		var w := vp.x - SIDE_LEFT - SIDE_RIGHT
		panel.custom_minimum_size.x = w
		scroll.custom_minimum_size.x = w - 30.0
	var fixed := panel.get_combined_minimum_size().y - scroll.custom_minimum_size.y
	scroll.custom_minimum_size.y = maxf(avail - fixed, 120.0)
	panel.size = Vector2(panel.custom_minimum_size.x if panel.has_meta("fullscreen") else panel.size.x, avail)

## Oyulmuş bölüm çubuğu (ortada başlık)
static func section(parent: Container, text: String) -> PanelContainer:
	var bar := PanelContainer.new()
	bar.theme_type_variation = "Section"
	var l := UiTheme.make_label(text.to_upper(), 17, Color("e7c47e"))
	l.add_theme_font_override("font", UiTheme.bold_font())
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bar.add_child(l)
	parent.add_child(bar)
	return bar

## Soldaki ad, sağdaki değer; ipucu satıra
static func stat(parent: Container, label: String, value: String, tip: String = "", value_color: Color = UiTheme.TEXT) -> Label:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_STOP if tip != "" else Control.MOUSE_FILTER_IGNORE
	row.tooltip_text = tip
	var l := UiTheme.make_label(label, 16, UiTheme.TEXT_DIM)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(l)
	var v := UiTheme.make_label(value, 16, value_color)
	v.add_theme_font_override("font", UiTheme.bold_font())
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(v)
	parent.add_child(row)
	return v

## Gömük ikon yuvası (variant: Slot / SlotGold / SlotGood / SlotBad)
static func slot(tex: Texture2D, side: int = 54, tip: String = "", variant: String = "Slot") -> PanelContainer:
	var pc := PanelContainer.new()
	pc.theme_type_variation = variant
	pc.custom_minimum_size = Vector2(side, side)
	pc.tooltip_text = tip
	pc.mouse_filter = Control.MOUSE_FILTER_STOP if tip != "" else Control.MOUSE_FILTER_IGNORE
	if tex:
		pc.add_child(UiTheme.icon_texture(tex, side - 8))
	return pc

## Sekme şeridi: seçilince on_select(index) çağrılır
static func tabs(parent: Container, names: Array, on_select: Callable, selected: int = 0) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var group := ButtonGroup.new()
	group.allow_unpress = false
	for i in names.size():
		var b := Button.new()
		b.theme_type_variation = "Tab"
		b.toggle_mode = true
		b.button_group = group
		b.text = str(names[i])
		b.focus_mode = Control.FOCUS_ALL
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.tooltip_text = str(names[i])
		# oyun menüsü sekmesi: yüksek, kalın yazı
		b.custom_minimum_size.y = 56
		b.add_theme_font_size_override("font_size", UiTheme.fs(19))
		b.add_theme_font_override("font", UiTheme.title_font())
		b.set_pressed_no_signal(i == selected)
		b.pressed.connect(func() -> void: on_select.call(i))
		row.add_child(b)
	parent.add_child(row)
	return row

static func grid(columns: int = 2) -> GridContainer:
	var result := GridContainer.new()
	result.columns = columns
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.add_theme_constant_override("h_separation", 6)
	result.add_theme_constant_override("v_separation", 6)
	return result

## Liste/kart düğmesi (ikon solda, metin sarılı)
static func card(button: Button, width: int = 200, height: int = 60) -> void:
	button.theme_type_variation = "Card"
	button.custom_minimum_size = Vector2(width, height)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", UiTheme.fs(16))
	button.add_theme_constant_override("h_separation", 10)

## Başlığın altında, kaydırılmayan sabit alan (özet hücreleri, sekmeler, bina seçimi gibi)
static func fixed(panel: PanelContainer) -> VBoxContainer:
	if panel.has_meta("fixed"):
		return panel.get_meta("fixed")
	var root := panel.get_child(0) as VBoxContainer
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	root.add_child(box)
	root.move_child(box, 1)
	panel.set_meta("fixed", box)
	# sabit alan açıldıktan sonra dolunca (araştırma yuvaları, hücreler) panel yeniden sığdırılır: yoksa kaydırma alanı
	# eski boyda kalır, panel ekranın altına taşar ve son satırlar görünmez
	box.minimum_size_changed.connect(func() -> void:
		if is_instance_valid(panel) and panel.visible:
			queue_fit(panel))
	return box

## Özet hücreleri: [[ikon, başlık, ipucu], ...] -> değer etiketleri (sonradan .text ile güncellenir)
## Hücreler eşit genişlikte bölünür (yazı uzunluğu genişliği değiştirmez), yüksek ve büyük ikonlu.
static func info_cells(parent: Container, items: Array) -> Array[Label]:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var out: Array[Label] = []
	for it: Array in items:
		var cell := PanelContainer.new()
		cell.theme_type_variation = "Slot"
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.size_flags_stretch_ratio = 1.0
		cell.custom_minimum_size = Vector2(0, 70)
		cell.tooltip_text = str(it[2]) if it.size() > 2 else ""
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		row.add_child(cell)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(hb)
		var tex: Texture2D = it[0] if it[0] is Texture2D else UiTheme.icon(str(it[0]))
		if tex:
			var ic := UiTheme.icon_texture(tex, 38)
			ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			hb.add_child(ic)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", -2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(col)
		var t := UiTheme.make_label(str(it[1]), 14, UiTheme.TEXT_DIM)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		t.custom_minimum_size.x = 1
		col.add_child(t)
		var v := UiTheme.make_label("", 21, UiTheme.TEXT)
		v.add_theme_font_override("font", UiTheme.bold_font())
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.custom_minimum_size.x = 1
		col.add_child(v)
		out.append(v)
	return out

## Liste satırı: solda ikon yuvası, ortada başlık + alt satır(lar), sağda eylem düğmeleri. İç VBox'ı döner.
static func row(parent: Container, tex: Texture2D, title: String, sub: String = "", tip: String = "", variant: String = "Row") -> VBoxContainer:
	var pc := PanelContainer.new()
	pc.theme_type_variation = variant
	pc.tooltip_text = tip
	pc.mouse_filter = Control.MOUSE_FILTER_STOP if tip != "" else Control.MOUSE_FILTER_PASS
	# satır iç boşluğu (yuva dokusu kullanan satırlarda da): içerik kenara yapışmasın
	var base := CommandPanelSkin.get_theme().get_stylebox("panel", variant)
	if base:
		var sbp: StyleBox = base.duplicate()
		sbp.content_margin_left = 12
		sbp.content_margin_right = 12
		sbp.content_margin_top = 8
		sbp.content_margin_bottom = 8
		pc.add_theme_stylebox_override("panel", sbp)
	parent.add_child(pc)
	var hb := HBoxContainer.new()
	hb.name = "H"
	hb.add_theme_constant_override("separation", 10)
	pc.add_child(hb)
	if tex:
		var s := slot(tex, 54)
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(s)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(col)
	var t := UiTheme.make_label(title, 16, UiTheme.TEXT)
	t.add_theme_font_override("font", UiTheme.bold_font())
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(t)
	if sub != "":
		var d := UiTheme.make_label(sub, 14, UiTheme.TEXT_DIM)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(d)
	return col

## row() ile kurulan satırın sağına düğme/denetim ekle
static func row_action(col: VBoxContainer, ctrl: Control) -> Control:
	ctrl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.get_parent().add_child(ctrl)
	return ctrl

## Metinli küçük düğme
static func small_button(text: String, cb: Callable, enabled: bool = true, tip: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", UiTheme.fs(15))
	b.pressed.connect(cb)
	return b

## Geniş ilerleme çubuğu (tema ProgressBar stilini kullanır)
static func progress(value: float, color: Color = UiTheme.ACCENT, height: float = 8.0) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.min_value = 0.0
	pb.max_value = 1.0
	pb.value = clampf(value, 0.0, 1.0)
	pb.show_percentage = false
	pb.custom_minimum_size.y = height
	pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.border_color = color.lightened(0.3)
	fill.border_width_top = 1
	pb.add_theme_stylebox_override("fill", fill)
	return pb

## Seçenek şeridi (filo/kanat görevi gibi): eşit genişlikte kart düğmeler; seçili olan altın çerçeveli, kalın ve
## altın yazılı, öbürleri koyu ve soluk (hangisinin seçili olduğu bir bakışta okunur). items: [[ikon, ad, ipucu], ...]
static func choice_row(parent: Container, items: Array, selected: int, on_pick: Callable, height: int = 42) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	for i in items.size():
		var it: Array = items[i]
		var b := Button.new()
		b.theme_type_variation = "Card"
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.set_pressed_no_signal(i == selected)
		b.icon = UiTheme.trimmed(it[0] if it[0] is Texture2D else UiTheme.icon(str(it[0])))
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 24)
		b.add_theme_constant_override("h_separation", 6)
		b.text = str(it[1])
		b.clip_text = true
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.tooltip_text = str(it[2]) if it.size() > 2 else ""
		b.custom_minimum_size = Vector2(0, height)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", UiTheme.fs(14))
		if i == selected:
			b.add_theme_font_override("font", UiTheme.bold_font())
			for fc: String in ["font_color", "font_pressed_color", "font_hover_pressed_color", "font_hover_color"]:
				b.add_theme_color_override(fc, UiTheme.ACCENT)
		else:
			b.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
			b.add_theme_color_override("icon_normal_color", Color(1, 1, 1, 0.5))
		var idx := i
		b.pressed.connect(func() -> void: on_pick.call(idx))
		row.add_child(b)
	return row

## Birim kartının başlığı (filo, hava kanadı): solda gömük simge yuvası, yanında ad ve altında durum satırı, sağda
## isteğe bağlı denetim. Seçili kartta yuva altın, ad altın rengi; seçili değilse yuva düz, ad açık renk.
static func card_head(parent: Container, tex: Texture2D, title: String, sub: String, selected: bool, sub_color: Color = UiTheme.TEXT_DIM) -> HBoxContainer:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	parent.add_child(head)
	var s := slot(tex, 46, "", "SlotGold" if selected else "Slot")
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(s)
	var nb := VBoxContainer.new()
	nb.add_theme_constant_override("separation", 0)
	nb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(nb)
	var n := UiTheme.make_label(title, 19, UiTheme.ACCENT if selected else UiTheme.TEXT)
	n.add_theme_font_override("font", UiTheme.bold_font())
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	n.custom_minimum_size.x = 1
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nb.add_child(n)
	if sub != "":
		var d := UiTheme.make_label(sub, 14, sub_color)
		d.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		d.custom_minimum_size.x = 1
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nb.add_child(d)
	return head

## Adlı ince çubuk satırı: solda ad, ortada çubuk, sağda değer (bütünlük, uçak sayısı)
static func bar_row(parent: Container, label: String, value: float, text: String, color: Color, tip: String = "") -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 10)
	r.tooltip_text = tip
	r.mouse_filter = Control.MOUSE_FILTER_STOP if tip != "" else Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	var l := UiTheme.make_label(label, 13, UiTheme.TEXT_DIM)
	l.custom_minimum_size.x = 84
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_child(l)
	var b := progress(value, color, 7.0)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_child(b)
	var v := UiTheme.make_label(text, 14, UiTheme.TEXT)
	v.custom_minimum_size.x = 64
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_child(v)
	return r

## Kare seçim karosu: ikon üstte, ad ve alt metin altta (bina, ekipman, tümen şablonu seçimi)
static func tile(tex: Texture2D, title: String, sub: String = "", tip: String = "", w: int = 110, h: int = 140) -> Button:
	var b := Button.new()
	b.theme_type_variation = "Card"
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(w, h)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.icon = UiTheme.trimmed(tex)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.add_theme_constant_override("icon_max_width", 76)
	b.text = title + ("\n" + sub if sub != "" else "")
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", UiTheme.fs(13))
	b.tooltip_text = tip
	return b

## Tablo: başlık şeridi + satırlar. widths: sütun genişlikleri (ilk sütun esner). Tablo VBox'ı döner.
static func table(parent: Container, headers: Array, widths: Array) -> VBoxContainer:
	var t := VBoxContainer.new()
	t.add_theme_constant_override("separation", 1)
	t.set_meta("widths", widths)
	parent.add_child(t)
	var head := PanelContainer.new()
	head.theme_type_variation = "Section"
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	head.add_child(hb)
	for i in headers.size():
		var l := UiTheme.make_label(str(headers[i]).to_upper(), 12, Color("d9c38c"))
		l.add_theme_font_override("font", UiTheme.bold_font())
		_col(l, widths, i)
		hb.add_child(l)
	t.add_child(head)
	return t

static func _col(c: Control, widths: Array, i: int) -> void:
	if i == 0:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.custom_minimum_size.x = float(widths[0])
	else:
		c.custom_minimum_size.x = float(widths[i])
		if c is Label:
			(c as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

## Tablo satırı: cells öğeleri Control ya da [metin, renk] ya da metin
static func table_row(t: VBoxContainer, cells: Array, tip: String = "") -> PanelContainer:
	var widths: Array = t.get_meta("widths")
	var pc := PanelContainer.new()
	pc.theme_type_variation = "CellRow" if t.get_child_count() % 2 == 1 else "CellAlt"
	pc.tooltip_text = tip
	pc.mouse_filter = Control.MOUSE_FILTER_STOP if tip != "" else Control.MOUSE_FILTER_PASS
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(hb)
	for i in cells.size():
		var c: Control
		var v = cells[i]
		if v is Control:
			c = v
		elif v is Array:
			c = UiTheme.make_label(str(v[0]), 15, v[1])
		else:
			c = UiTheme.make_label(str(v), 15)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_col(c, widths, i)
		hb.add_child(c)
	t.add_child(pc)
	return pc

## İkon + metin (tablo ilk sütunu için)
static func icon_label(tex: Texture2D, text: String, side: int = 30, size: int = 15) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tex:
		var ic := UiTheme.icon_texture(tex, side)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(ic)
	var l := UiTheme.make_label(text, size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(l)
	return hb

## Boş liste açıklaması
static func empty(parent: Container, text: String) -> Label:
	var l := UiTheme.make_label(text, 15, UiTheme.TEXT_DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l

## Geniş/tam ekran paneller için sütunlar: ratios oranında genişleyen VBox'lar döner
static func columns(parent: Container, ratios: Array, gap: int = 14) -> Array[VBoxContainer]:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", gap)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	var out: Array[VBoxContainer] = []
	for r in ratios:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.size_flags_stretch_ratio = float(r)
		col.add_theme_constant_override("separation", 8)
		row.add_child(col)
		out.append(col)
	return out

## Renkli (iyi yeşil / kötü kırmızı) ayrıntı kutusu: ipucu metinlerini sayfada da göstermek için
static func detail(parent: Container, text: String, size: int = 15) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_size_override("normal_font_size", UiTheme.fs(size))
	r.add_theme_color_override("default_color", UiTheme.TEXT)
	r.text = UiTheme.colorize(text)
	parent.add_child(r)
	return r

## Eski düzen uyumluluğu
static func fit_scroll(panel: Control, scroll: ScrollContainer, preferred: float) -> void:
	var fixed := panel.get_combined_minimum_size().y - scroll.custom_minimum_size.y
	var available := panel.get_viewport_rect().size.y - panel.position.y - 22.0
	scroll.custom_minimum_size.y = clampf(available - fixed, 100.0, preferred)
	panel.size.y = panel.get_combined_minimum_size().y

## İnce yatay çubuk (0..1)
static func bar(value: float, color: Color, width: float = 120.0, height: float = 6.0) -> Control:
	var back := ColorRect.new()
	back.color = Color(0, 0, 0, 0.65)
	back.custom_minimum_size = Vector2(width, height)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := ColorRect.new()
	fill.color = color
	fill.size = Vector2(width * clampf(value, 0.0, 1.0), height)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(fill)
	return back

## İdeoloji pasta grafiği
class Pie extends Control:
	var parts: Array = []      ## [[oran, Color], ...]
	func _init(side: float = 96.0) -> void:
		custom_minimum_size = Vector2(side, side)
		mouse_filter = Control.MOUSE_FILTER_STOP
	func set_parts(p: Array) -> void:
		parts = p
		queue_redraw()
	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 2.0
		draw_circle(c, r + 2.0, Color(0, 0, 0, 0.85))
		var total := 0.0
		for p: Array in parts:
			total += float(p[0])
		var a0 := -PI * 0.5
		for p: Array in parts:
			var frac := float(p[0]) / maxf(total, 0.0001)
			if frac <= 0.0:
				continue
			var a1 := a0 + frac * TAU
			var pts := PackedVector2Array([c])
			var steps := maxi(int(frac * 48.0), 2)
			for i in steps + 1:
				var a := lerpf(a0, a1, float(i) / steps)
				pts.append(c + Vector2(cos(a), sin(a)) * r)
			draw_colored_polygon(pts, p[1])
			a0 = a1
		draw_arc(c, r, 0, TAU, 64, Color(0.55, 0.47, 0.3), 1.5, true)
