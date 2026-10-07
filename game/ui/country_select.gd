class_name CountrySelect
extends Control
## Ülke seçim ekranı (parçalar: assets/ui/first-selection.png → tools/slice_selection_sheet.py → assets/ui/selection/).
## Üstte öne çıkan ülkelerin kutuları, sağda eylem paneli (bayrak, ad, Başla / Geri). Açılışta ülke seçili gelmez:
## oyuncu kutulardan ya da haritadan seçer (main.gd yönlendirir); seçilene kadar Başla kapalı.
## Akış sıra sıra (her şey aynı karede kurulunca seçim takılıyordu): seçim → harita öbür yerleri karartır, sınır neon
## yanar, kamera ülkeye süzülür (main.gd) ve soldan bilgi paneli gelir → kamera varınca (reveal) ülke bilgileri belirir.
## Başla: paneller yavaşça yukarı çekilir (leave); main kamerayı başkente indirip oyun panellerini yukarıdan indirir.
## Haritadan seçince üstteki kutu paneli yukarı kayıp kapanır (harita görünsün), altındaki düğmeyle yeniden açılır.

signal start_pressed(tag: String)
signal back_pressed
signal selection_changed(tag: String)

const FEATURED := ["GER", "ENG", "FRA", "ITA", "SOV", "TUR", "POL", "JAP"]
const DIR := "res://assets/ui/selection/"
const EDGE := 18.0                   ## panellerin ekran kenarından payı
const SLOT := 110.0                  ## üst paneldeki yuvanın boyu (sayfadaki gibi)
const SLOT_X := 6.5                  ## yuvanın birimin sol kenarından uzaklığı
const SLOT_Y := 88.0                 ## yuvanın panelin üst kenarından uzaklığı
const TOP_UNITS := 7                 ## sayfadaki yuva birimi sayısı
const SIDE_TOP := 272.0              ## yan panellerin üst kenarı (üst panelin altı)
const INFO_FADE := 0.35              ## bilgilerin belirme süresi (sn)
const LEFT_TEXT_W := 280.0           ## sol panelde yazı genişliği (panel 332, iç pay 26 + 26)

var selected := ""
var _cards := {}
var _flag: TextureRect
var _name: Label
var _leader: Label
var _ideology: Label
var _portrait: TextureRect
var _rows := {}
var _top_box: Control                ## kutu paneli + aç/kapa düğmesi (kapanınca yukarı kayar, düğme görünür kalır)
var _top: Control
var _toggle: Button
var _top_open := true
var _start: Button
var _none: Label                     ## seçim yokken yönerge
var _none_title: Label
var _detail: Array[Control] = []     ## seçim yokken gizlenen detay parçaları (sağ panel)
var _left: Control                   ## bilgi paneli (seçimle soldan gelir)
var _right: Control
var _info: Array[Control] = []       ## kamera varınca belirenler (bilgi paneli içi, sağdaki bayrak ve ad)
var _left_in := false
var _revealed := ""                  ## bilgileri gösterilen ülke
var _reveal_timer: SceneTreeTimer
var _info_tween: Tween

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_top()
	_build_right()
	_build_left()
	_show_detail(false)
	_start.disabled = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.5)

static func tex(name: String) -> Texture2D:
	return load(DIR + name + ".png")

## Başlık yazısı: kalın dar yazı, harf aralıklı (Cinzel küçük harfleri küçük büyük harf çizdiğinden Türkçe İ'ler
## noktalı ve karışık görünüyordu)
static var _heading: FontVariation
static func heading_font() -> Font:
	if _heading == null:
		_heading = FontVariation.new()
		_heading.base_font = UiTheme.bold_font()
		_heading.spacing_glyph = 2
	return _heading

## Büyük harf (ölçmek için; ekranda Label.uppercase dile göre çevirir): Türkçede i → İ (to_upper i'yi noktasız I yapar)
static func upper(text: String) -> String:
	if TranslationServer.get_locale().begins_with("tr"):
		text = text.replace("i", "İ")
	return text.to_upper()

static func heading(text: String, size: int, color: Color) -> Label:
	var l := UiTheme.make_label(text, size, color)
	l.uppercase = true
	l.add_theme_font_override("font", heading_font())
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

## Parça dokusundan kutu: köşeler olduğu gibi, kenarlar uzar; expand: gölge/parıltı payı (düğme alanının dışına taşar)
static func box_style(name: String, margin: int, expand: Vector4 = Vector4.ZERO, tint := Color.WHITE) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex(name)
	sb.set_texture_margin_all(margin)
	sb.expand_margin_left = expand.x
	sb.expand_margin_top = expand.y
	sb.expand_margin_right = expand.z
	sb.expand_margin_bottom = expand.w
	sb.modulate_color = tint
	return sb

## Resim çerçevesi: kutunun pirinç kenarı tam düğüm sınırında (gölge payı dışarıda: içerik ortada), resimle kenar
## arasında az pay; resim köşeleri yumuşak (yuvarlatılmış, kenarı yumuşatılmış maske)
static func framed(inner: Control, pad: int, radius: int) -> PanelContainer:
	var pf := PanelContainer.new()
	var st := box_style("box", 16, Vector4(6, 5, 8, 7))     # box.png: pirinç kenar (6, 5)–(166, 158), sağ-alt gölge
	st.set_content_margin_all(pad)
	pf.add_theme_stylebox_override("panel", st)
	var mask := Panel.new()
	var ms := StyleBoxFlat.new()
	ms.bg_color = Color.WHITE
	ms.set_corner_radius_all(radius)
	ms.anti_aliasing = true
	ms.anti_aliasing_size = 1.5
	mask.add_theme_stylebox_override("panel", ms)
	mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	mask.custom_minimum_size = inner.custom_minimum_size
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mask.add_child(inner)
	pf.add_child(mask)
	return pf

## Uzun düğme (bar / bar_active): üstüne gelince ve basınca parlar
static func bar_button(text: String, active: bool, height: float, font_size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, height)
	b.add_theme_font_size_override("font_size", UiTheme.fs(font_size))
	b.add_theme_font_override("font", UiTheme.bold_font())
	var name := "bar_active" if active else "bar"
	var ex := Vector4(6, 4, 9, 7)
	b.add_theme_stylebox_override("normal", box_style(name, 22, ex))
	b.add_theme_stylebox_override("hover", box_style(name, 22, ex, Color(1.2, 1.15, 1.0)))
	b.add_theme_stylebox_override("pressed", box_style(name, 22, ex, Color(1.35, 1.2, 0.95)))
	b.add_theme_stylebox_override("hover_pressed", box_style(name, 22, ex, Color(1.35, 1.2, 0.95)))
	b.add_theme_stylebox_override("disabled", box_style("bar", 22, ex, Color(0.55, 0.55, 0.52)))
	# açık yazı, koyu kontur: altın dolguda da koyu zeminde de okunur (koyu yazı altın dolguda kayboluyordu)
	b.add_theme_color_override("font_color", Color("fff3d6") if active else Color("f0e2c0"))
	b.add_theme_color_override("font_hover_color", Color("ffffff"))
	b.add_theme_color_override("font_pressed_color", Color("ffe7b0"))
	b.add_theme_color_override("font_hover_pressed_color", Color("ffe7b0"))
	b.add_theme_color_override("font_disabled_color", Color("a39a84"))
	b.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.02, 0.95))
	b.add_theme_constant_override("outline_size", 6 if active else 5)
	return b

## Panel resmi + içerik payı: resim kendi oranında, içerik üstünde
func _panel(name: String, psize: Vector2, pad: Vector4) -> Array:
	var holder := Control.new()
	holder.size = psize
	holder.custom_minimum_size = psize
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := TextureRect.new()
	bg.texture = tex(name)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(bg)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", int(pad.x))
	m.add_theme_constant_override("margin_top", int(pad.y))
	m.add_theme_constant_override("margin_right", int(pad.z))
	m.add_theme_constant_override("margin_bottom", int(pad.w))
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(m)
	return [holder, m]

# ------------------------------------------------------------------ üst: öne çıkan ülkeler
func _build_top() -> void:
	_top_box = VBoxContainer.new()
	_top_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_top_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_top_box.offset_top = EDGE
	_top_box.add_theme_constant_override("separation", 6)
	_top_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_top_box)
	# panel: sol uç + yuva birimleri + sağ uç (ardışık birimler sayfadaki gibi kesintisiz; fazla yuva ortada tekrarlanır)
	var tags: Array = FEATURED.filter(func(t: String) -> bool: return World.countries.has(t))
	var n := tags.size()
	var order: Array[int] = []
	var a := ceili(n / 2.0)
	for i in a:
		order.append(mini(i, TOP_UNITS - 1))
	for i in n - a:
		order.append(clampi(TOP_UNITS - (n - a) + i, 0, TOP_UNITS - 1))
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 0)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var parts: Array[Texture2D] = [tex("top_left")]
	for u in order:
		parts.append(tex("top_unit_%d" % u))
	parts.append(tex("top_right"))
	var xs: Array[float] = []
	var x := 0.0
	for i in parts.size():
		var t := TextureRect.new()
		t.texture = parts[i]
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strip.add_child(t)
		if i > 0 and i < parts.size() - 1:
			xs.append(x)
		x += parts[i].get_width()
	var top := Control.new()
	_top = top
	top.custom_minimum_size = Vector2(x, parts[0].get_height())
	top.mouse_filter = Control.MOUSE_FILTER_STOP
	top.add_child(strip)
	_top_box.add_child(top)
	var head := heading(tr("SELECT_TITLE"), 30, UiTheme.ACCENT)
	head.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.position = Vector2(0, 14)
	head.size = Vector2(x, SLOT_Y - 20)
	top.add_child(head)
	for i in n:
		var c: Country = World.countries[tags[i]]
		var card := _card(c)
		card.position = Vector2(xs[i] + SLOT_X, SLOT_Y)
		card.size = Vector2(SLOT, SLOT)
		top.add_child(card)
	var hint := UiTheme.make_label(tr("SELECT_HINT"), 14, UiTheme.TEXT_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(0, SLOT_Y + SLOT + 4)
	hint.size = Vector2(x, 22)
	top.add_child(hint)
	_toggle = bar_button(tr("SELECT_HIDE_FEATURED"), false, 40, 15)
	Audio.ui_bind(_toggle, "menu_tab", "menu_hover")
	_toggle.custom_minimum_size.x = 230
	_toggle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_toggle.pressed.connect(func() -> void: set_featured_open(not _top_open))
	_top_box.add_child(_toggle)

func _card(c: Country) -> Button:
	var b := Button.new()
	Audio.ui_bind(b, "country_select", "menu_hover")
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.icon = FlagFactory.get_flag(c)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.text = c.map_name()
	# uzun ad iki satıra kayar (bayrak biraz küçülür): "Sovyetler Birliği" tek satıra sığmıyordu
	var long_name := c.map_name().length() > 11
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if long_name else TextServer.AUTOWRAP_OFF
	b.clip_text = not long_name
	b.add_theme_constant_override("icon_max_width", 66 if long_name else 84)
	b.add_theme_constant_override("line_spacing", -3)
	b.add_theme_font_size_override("font_size", UiTheme.fs(13 if long_name else 15))
	b.add_theme_font_override("font", UiTheme.bold_font())
	b.add_theme_color_override("font_color", Color("e5d5b3"))
	b.add_theme_color_override("font_hover_color", Color("fff0ce"))
	b.add_theme_color_override("font_pressed_color", Color("ffe1a0"))
	b.add_theme_color_override("font_hover_pressed_color", Color("ffe1a0"))
	var box_ex := Vector4(6, 5, 8, 8)
	var sel_ex := Vector4(8, 8, 10, 8)
	for st: Array in [["normal", box_style("box", 24, box_ex)], ["hover", box_style("box", 24, box_ex, Color(1.25, 1.18, 1.02))],
			["pressed", box_style("box_selected", 28, sel_ex)], ["hover_pressed", box_style("box_selected", 28, sel_ex, Color(1.1, 1.06, 1.0))]]:
		var sb: StyleBoxTexture = st[1]
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 14
		sb.content_margin_bottom = 8
		b.add_theme_stylebox_override(st[0], sb)
	b.pressed.connect(func() -> void: select(c.tag))
	_cards[c.tag] = b
	return b

# ------------------------------------------------------------------ sağ: eylem paneli
func _build_right() -> void:
	var psize := Vector2(361, 764)
	var pr := _panel("panel_right", psize, Vector4(28, 30, 28, 30))
	_right = pr[0]
	_right.anchor_left = 1.0
	_right.anchor_right = 1.0
	_right.offset_left = -EDGE - psize.x
	_right.offset_right = -EDGE
	_right.offset_top = SIDE_TOP
	_right.offset_bottom = SIDE_TOP + psize.y
	add_child(_right)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	(pr[1] as Control).add_child(v)
	_none_title = heading(tr("SELECT_PROMPT_TITLE"), 28, UiTheme.ACCENT)
	_none_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_none_title)
	_none = UiTheme.make_label(tr("SELECT_NONE"), 19, UiTheme.TEXT_DIM)
	_none.add_theme_color_override("font_shadow_color", Color.BLACK)
	_none.add_theme_constant_override("shadow_offset_y", 1)
	_none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_none)
	_flag = TextureRect.new()
	_flag.custom_minimum_size = Vector2(240, 160)
	_flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_flag.stretch_mode = TextureRect.STRETCH_SCALE
	var frame := framed(_flag, 8, 4)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(frame)
	_name = heading("", 32, UiTheme.ACCENT)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_name)
	_detail = [frame, _name]                     # bayrak ve ad seçilince hemen değişir (sönüp yeniden gelmez)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(fill)
	_start = bar_button(tr("SELECT_START").to_upper(), true, 64, 26)
	Audio.ui_bind(_start, "game_start", "menu_hover")
	_start.pressed.connect(func() -> void: start_pressed.emit(selected))
	v.add_child(_start)
	var back := bar_button(tr("SELECT_BACK"), false, 48, 20)
	Audio.ui_bind(back, "menu_close", "menu_hover")
	back.pressed.connect(func() -> void: back_pressed.emit())
	v.add_child(back)

# ------------------------------------------------------------------ sol: bilgi paneli (seçimle gelir)
func _build_left() -> void:
	var psize := Vector2(332, 472)
	var pl := _panel("panel_left", psize, Vector4(26, 12, 26, 30))
	_left = pl[0]
	_left.position = Vector2(-psize.x - 40.0, SIDE_TOP)     # ekran dışında bekler
	add_child(_left)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	(pl[1] as Control).add_child(v)
	_leader = heading("", 26, UiTheme.ACCENT)
	_leader.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_leader.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART      # uzun ad alt satıra kayar (_fit_leader)
	_leader.custom_minimum_size = Vector2(LEFT_TEXT_W, 56)      # paneldeki süslü ayracın üstü
	v.add_child(_leader)
	var gap := Control.new()                                    # ayraç ile lider bölümü arasında pay
	gap.custom_minimum_size.y = 4
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(gap)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	v.add_child(head)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(64, 80)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var pf := framed(_portrait, 7, 6)
	pf.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(pf)
	_ideology = UiTheme.make_label("", 17, UiTheme.TEXT)
	_ideology.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ideology.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ideology.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(_ideology)
	v.add_child(SelectionSkin.divider())
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 8)
	for key in ["UI_POPULATION", "UI_MANPOWER", "SELECT_STATES", "UI_VICTORY_POINTS", "UI_STABILITY_TIP", "UI_WAR_SUPPORT_TIP"]:
		grid.add_child(UiTheme.make_label(tr(key), 16, UiTheme.TEXT_DIM))
		var val := UiTheme.make_label("", 16)
		val.add_theme_font_override("font", UiTheme.bold_font())
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(val)
		_rows[key] = val
	v.add_child(grid)
	_info.append(v)

## Seçim yokken detay yerine yönerge, Başla kapalı
func _show_detail(on: bool) -> void:
	for n: Control in _detail:
		n.visible = on
	_none.visible = not on
	_none_title.visible = not on

## Kutu paneli: açık ya da yukarı kaymış (yalnız aç/kapa düğmesi görünür)
func set_featured_open(open: bool) -> void:
	_top_open = open
	_toggle.text = tr("SELECT_HIDE_FEATURED") if open else tr("SELECT_SHOW_FEATURED")
	var target := EDGE if open else -_top.custom_minimum_size.y - 6.0
	create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).tween_property(_top_box, "offset_top", target, 0.3)

## Haritadan seçim: kutu paneli kapanır (harita görünsün)
func select_from_map(tag: String) -> void:
	var before := selected
	select(tag)
	if selected == tag and selected != before: Audio.play("country_select")
	if selected == tag and _top_open:
		set_featured_open(false)

## Seçim: sağdaki bayrak ve ad hemen değişir; sol paneldeki eski bilgiler söner, yenileri hemen yazılıp belirir (önce
## yazılınca yeni bilgi bir görünüp kayboluyordu). Ülke değişirken Başla kapalı: kamera varınca (reveal) açılır.
func select(tag: String) -> void:
	var c: Country = World.countries.get(tag)
	if c == null or c.states.is_empty():
		return
	selected = tag
	_show_detail(true)
	_start.disabled = true
	for t: String in _cards:
		_cards[t].set_pressed_no_signal(t == tag)
	_flag.texture = FlagFactory.get_flag(c)
	_name.text = c.display_name()
	_revealed = ""
	# soldaki lider bilgisi: eskisi söner, yenisi hemen belirir (kamera uçuşunu beklemez)
	if _info_tween:
		_info_tween.kill()
	_info_tween = create_tween()
	for n: Control in _info:
		_info_tween.parallel().tween_property(n, "modulate:a", 0.0, 0.15)
	_info_tween.tween_callback(func() -> void:
		if selected == tag:
			_fill_left(c))
	for n: Control in _info:
		_info_tween.parallel().tween_property(n, "modulate:a", 1.0, INFO_FADE)
	if not _left_in:
		_left_in = true
		create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).tween_property(_left, "position:x", EDGE, 0.45)
	# kamera uçuşu bitmezse (kısa yol, test) bilgiler yine gelir
	if is_inside_tree():
		_reveal_timer = get_tree().create_timer(1.6)
		_reveal_timer.timeout.connect(func() -> void:
			if selected == tag:
				reveal())
	selection_changed.emit(tag)

## Sol paneldeki bilgiler (lider, ideoloji, sayılar)
func _fill_left(c: Country) -> void:
	_fit_leader(c.leader_name())
	_ideology.text = ("%s\n%s" % [tr("IDEOLOGY_" + c.ideology), c.party_name()]) if c.party_name() != "" else tr("IDEOLOGY_" + c.ideology)
	var vp := 0
	for sid in c.states:
		vp += World.states[sid].victory_points()
	_rows["UI_POPULATION"].text = UiTheme.format_number(c.population)
	_rows["UI_MANPOWER"].text = UiTheme.format_number(c.recruitable_manpower())
	_rows["SELECT_STATES"].text = str(c.states.size())
	_rows["UI_VICTORY_POINTS"].text = str(vp)
	_rows["UI_STABILITY_TIP"].text = "%d%%" % roundi(Politics.stability(c) * 100)
	_rows["UI_WAR_SUPPORT_TIP"].text = "%d%%" % roundi(Politics.war_support(c) * 100)
	var por := UiTheme.portrait(c)
	_portrait.texture = por if por else FlagFactory.get_flag(c)

## Lider adı: tek satıra sığıyorsa büyük, sığmıyorsa küçülüp iki satıra kayar (ayracın üstündeki alana)
func _fit_leader(name: String) -> void:
	var size := 26
	if heading_font().get_string_size(upper(name), HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.fs(size)).x > LEFT_TEXT_W:
		size = 20
	_leader.add_theme_font_size_override("font_size", UiTheme.fs(size))
	_leader.text = name

## Kamera seçilen ülkeye vardı (main çağırır): Başla açılır
func reveal() -> void:
	if selected == "" or _revealed == selected:
		return
	_revealed = selected
	_fill_left(World.countries[selected])          # (bilgi zaten geldiyse aynısı; testlerde tween yok)
	_start.disabled = false

## Başla'dan sonra: paneller kenarlarına çekilir (sağdaki sağa, soldaki sola, üstteki yukarı); bitince ekran kendini
## kaldırmaz (main kaldırır)
func leave(secs: float) -> Tween:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for n: Control in [_top_box, _left, _right]:
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_top_box, "offset_top", -_top_box.size.y - 40.0, secs)     # aç/kapa düğmesi de çıksın
	tw.tween_property(_left, "position:x", -_left.size.x - 60.0, secs)
	var out := _right.size.x + EDGE + 60.0
	tw.tween_property(_right, "offset_left", _right.offset_left + out, secs)
	tw.tween_property(_right, "offset_right", _right.offset_right + out, secs)
	return tw
