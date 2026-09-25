class_name PanelLayout
extends RefCounted
## Yan panel şablonu ve ortak parçalar (türün klasiği düzeni): başlık bandı (ikon + başlık + kapat), tam boy kaydırmalı
## gövde, oyulmuş bölüm çubukları, gömük ikon yuvaları, istatistik satırları, sekmeler, pasta grafik.

const SIDE_TOP := 128.0       ## yan panellerin üst kenarı (üst blok + menü tepsisi altı)
const SIDE_BOTTOM := 14.0

## Paneli çerçevele: başlık + kaydırmalı gövde. Gövde VBox'ı döner. Panelde meta "scroll" ve "body" saklanır.
static func frame(panel: PanelContainer, title: String, icon_name: String = "", width: float = 480.0) -> VBoxContainer:
	panel.custom_minimum_size.x = width
	panel.set_meta("framed", true)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	panel.add_child(root)
	var head := PanelContainer.new()
	head.theme_type_variation = "Header"
	root.add_child(head)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	head.add_child(hb)
	if icon_name != "":
		var tex := UiTheme.icon(icon_name)
		if tex:
			hb.add_child(UiTheme.icon_texture(tex, 26))
	var t := UiTheme.make_label(title.to_upper(), 19, UiTheme.ACCENT)
	t.add_theme_font_override("font", UiTheme.title_font())
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.name = "Title"
	hb.add_child(t)
	var close := UiTheme.icon_button("close", TranslationServer.translate("TIP_CLOSE"), func() -> void:
		if panel.has_method("close"):
			panel.call("close")
		else:
			panel.visible = false, 26)
	hb.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(width - 30.0, 200.0)
	root.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	scroll.add_child(body)
	panel.set_meta("scroll", scroll)
	panel.set_meta("body", body)
	panel.visibility_changed.connect(func() -> void:
		if panel.visible: fit_full.call_deferred(panel))
	panel.get_viewport().size_changed.connect(func() -> void:
		if panel.visible: fit_full(panel))
	return body

static func set_title(panel: Control, title: String) -> void:
	var l := panel.find_child("Title", true, false) as Label
	if l:
		l.text = title.to_upper()

## Panel ekranın altına kadar uzanır (türün klasiğindeki gibi tam boy yan panel)
static func fit_full(panel: Control) -> void:
	if not panel.has_meta("scroll") or not panel.is_inside_tree():
		return
	var scroll: ScrollContainer = panel.get_meta("scroll")
	var vp := panel.get_viewport_rect().size
	var avail := vp.y - SIDE_TOP - SIDE_BOTTOM
	var fixed := panel.get_combined_minimum_size().y - scroll.custom_minimum_size.y
	scroll.custom_minimum_size.y = maxf(avail - fixed, 120.0)
	panel.size = Vector2(panel.size.x, avail)

## Oyulmuş bölüm çubuğu (ortada başlık)
static func section(parent: Container, text: String) -> PanelContainer:
	var bar := PanelContainer.new()
	bar.theme_type_variation = "Section"
	var l := UiTheme.make_label(text.to_upper(), 14, Color("d9c38c"))
	l.add_theme_font_override("font", UiTheme.bold_font())
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
static func slot(tex: Texture2D, side: int = 48, tip: String = "", variant: String = "Slot") -> PanelContainer:
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
	row.add_theme_constant_override("separation", 2)
	var group := ButtonGroup.new()
	for i in names.size():
		var b := Button.new()
		b.theme_type_variation = "Tab"
		b.toggle_mode = true
		b.button_group = group
		b.text = str(names[i])
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 16)
		b.button_pressed = i == selected
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
	button.add_theme_font_size_override("font_size", 16)
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
	return box

## Özet hücreleri: [[ikon, başlık, ipucu], ...] -> değer etiketleri (sonradan .text ile güncellenir)
static func info_cells(parent: Container, items: Array) -> Array[Label]:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	var out: Array[Label] = []
	for it: Array in items:
		var cell := PanelContainer.new()
		cell.theme_type_variation = "Slot"
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.tooltip_text = str(it[2]) if it.size() > 2 else ""
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		row.add_child(cell)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 5)
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(hb)
		var tex: Texture2D = it[0] if it[0] is Texture2D else UiTheme.icon(str(it[0]))
		if tex:
			var ic := UiTheme.icon_texture(tex, 28)
			ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hb.add_child(ic)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", -3)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(col)
		var t := UiTheme.make_label(str(it[1]), 12, UiTheme.TEXT_DIM)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(t)
		var v := UiTheme.make_label("", 17, UiTheme.TEXT)
		v.add_theme_font_override("font", UiTheme.bold_font())
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(v)
		out.append(v)
	return out

## Liste satırı: solda ikon yuvası, ortada başlık + alt satır(lar), sağda eylem düğmeleri. İç VBox'ı döner.
static func row(parent: Container, tex: Texture2D, title: String, sub: String = "", tip: String = "", variant: String = "Row") -> VBoxContainer:
	var pc := PanelContainer.new()
	pc.theme_type_variation = variant
	pc.tooltip_text = tip
	pc.mouse_filter = Control.MOUSE_FILTER_STOP if tip != "" else Control.MOUSE_FILTER_PASS
	parent.add_child(pc)
	var hb := HBoxContainer.new()
	hb.name = "H"
	hb.add_theme_constant_override("separation", 8)
	pc.add_child(hb)
	if tex:
		var s := slot(tex, 44)
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
	b.add_theme_font_size_override("font_size", 15)
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

## Kare seçim karosu: ikon üstte, ad ve alt metin altta (bina, ekipman, tümen şablonu seçimi)
static func tile(tex: Texture2D, title: String, sub: String = "", tip: String = "", w: int = 110, h: int = 104) -> Button:
	var b := Button.new()
	b.theme_type_variation = "Card"
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(w, h)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.icon = tex
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.add_theme_constant_override("icon_max_width", 52)
	b.text = title + ("\n" + sub if sub != "" else "")
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", 13)
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
static func icon_label(tex: Texture2D, text: String, side: int = 24, size: int = 15) -> HBoxContainer:
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
