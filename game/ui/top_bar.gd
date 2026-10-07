class_name TopBar
extends Control
## Üst bar: oyuncu ülkesi, temel göstergeler, tarih ve hız kontrolü.

var _flag: TextureRect
var _mini_flag: TextureRect
var _name: Label
var _leader: Label
var _pp: Label
var _stability: Label
var _war_support: Label
var _manpower: Label
var _factories: Label
var _fuel: Label
var _tension: Label
var _war: Label
var _date: Label
var _scen: Label                    ## senaryoda: kalan gün ve anahtar şehir puanı (serbest oyunda gizli)
var globe: WorldGlobe               ## dünya saati (tarih kutusunun solunda; main dokusunu bağlar)
var _pause_btn: TextureButton
var _convoys: Label
var _supply: Label
var _command: Label
var _pp_gain: Label                 ## günlük artış: değerin yanında küçük, yeşil
var _sp_gain: Label

## Düzen (arayüz sayfasındaki örnek, assets/ui/ui-sprite.png): sol üstte çerçeveli portre; sağında kaynak çubuğu ve
## aynı boyda uyarı kutusu; portrenin altında menü düğmeleri (HUD `task_row`a ekler); sağ üstte tarih kutusu (dünya
## saati, tarih, hız çubuğu, duraklat / oynat / hızlandır).
var task_row: VBoxContainer      ## sol kenardaki dikey menü (HUD düğmeleri ekler)
var alert_row: HBoxContainer     ## üst satırdaki uyarı kutucukları
var alert_strip: PanelContainer  ## uyarıların metal şeridi (uyarı yokken gizli)
const EDGE := 12.0               ## portre ve menü tepsisinin ekranın sol kenarından, portrenin üst kenardan payı
const MENU_TOP := 127.0          ## menü tepsisinin üst kenarı: portrenin altı + MENU_GAP (portre boyu değişirse _fit_portrait)
const MENU_GAP := 10.0           ## portre ile menü tepsisi arası
const MENU_ICON := 70.0          ## menü düğmesinin eni (HUD); tepsi portreyle aynı enle, düğmeler ortada
const MENU_W := 110.0            ## menü tepsisinin yaklaşık genişliği (portre eninde; yan paneller sağından: PanelLayout.SIDE_LEFT)
const FLAG_W := 100
const FLAG_H := 66

static func _metal(bg: Color, border: Color, radius: int = 3, bw: int = 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 3
	sb.shadow_offset = Vector2(0, 2)
	return sb

## Metal doku kutusu (arayüzün geri kalanıyla aynı set): margin doku kenarı, h/v iç boşluk
static func _tex(name: String, margin: int, h: int, v: int) -> StyleBox:
	var sb := UiTheme.skin(name, margin, v)
	sb.content_margin_left = h
	sb.content_margin_right = h
	return sb

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	custom_minimum_size.y = 120
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# --- portre: menü tepsisiyle aynı çerçeve (köşeleri aynı yuvarlaklıkta), içinde köşeleri yuvarlatılmış lider portresi
	# (yoksa bayrak), sağ altta küçük bayrak. Boyu kaynak çubuğunun boyuna eşit (üst ve alt kenarlar aynı hizada): _fit_portrait
	_portrait = Control.new()
	_portrait.position = Vector2(EDGE, EDGE)
	_portrait.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_portrait)
	var pbg := Panel.new()
	pbg.add_theme_stylebox_override("panel", _frame_box("mil_frame", 26, 0, 0))
	pbg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.add_child(pbg)
	_portrait_mask = Panel.new()
	var ms := StyleBoxFlat.new()
	ms.bg_color = Color.WHITE
	ms.set_corner_radius_all(PORTRAIT_RADIUS)
	ms.anti_aliasing = true
	ms.anti_aliasing_size = 1.2
	_portrait_mask.add_theme_stylebox_override("panel", ms)
	_portrait_mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	_portrait_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.add_child(_portrait_mask)
	_flag = TextureRect.new()
	_flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_flag.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_mask.add_child(_flag)
	_mini_flag = TextureRect.new()
	_mini_flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mini_flag.stretch_mode = TextureRect.STRETCH_SCALE
	_mini_flag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mini_flag.visible = false
	_portrait.add_child(_mini_flag)
	_name = UiTheme.make_label("", 12)      # yalnız ipucu metni için tutulur
	_leader = UiTheme.make_label("", 12)

	# --- portrenin sağı: kaynak çubuğu (ikon + değer, ayraçlı) ve uyarı kutusu
	var stats_line := HBoxContainer.new()
	_stats_line = stats_line
	stats_line.add_theme_constant_override("separation", 14)
	stats_line.position = Vector2(EDGE, EDGE)                     # üst kenarı portreyle aynı hizada (x: _fit_portrait)
	stats_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stats_line)
	var strip := PanelContainer.new()
	strip.add_theme_stylebox_override("panel", _frame_box("bar_frame", 26, 14, 22))   # yanlarda yalnız çerçeve payı
	strip.custom_minimum_size.y = BAR_H
	strip.mouse_filter = Control.MOUSE_FILTER_STOP
	stats_line.add_child(strip)
	strip.resized.connect(func() -> void: _fit_portrait(strip.size.y))
	_fit_portrait(BAR_H)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	strip.add_child(row)
	_pp = _stat(row, ResourceIcon.Kind.POLITICAL_POWER, "UI_POLITICAL_POWER_TIP", true)
	_pp_gain = _gain(_pp)
	_stability = _stat(row, ResourceIcon.Kind.STABILITY, "UI_STABILITY_TIP", true)
	_war_support = _stat(row, ResourceIcon.Kind.WAR_SUPPORT, "UI_WAR_SUPPORT_TIP", true)
	_manpower = _stat(row, ResourceIcon.Kind.MANPOWER, "UI_MANPOWER_TIP", true)
	_factories = _stat(row, ResourceIcon.Kind.FACTORY, "UI_FACTORIES_TIP", true)
	_sp_gain = _gain(_factories)
	# yakıt ve ikmal gösterilmez: sade oyunda savaşı etkilemiyorlar (Military.FUEL / SUPPLY)
	_fuel = UiTheme.make_label("", 12)
	_supply = UiTheme.make_label("", 12)
	_convoys = _stat(row, ResourceIcon.Kind.CONVOY, "UI_CONVOY_TIP", true)
	_tension = _stat(row, ResourceIcon.Kind.TENSION, "TIP_TENSION", true)
	_war = _stat(row, ResourceIcon.Kind.WAR, "TIP_AT_WAR_SHORT", true)
	_war.add_theme_color_override("font_color", UiTheme.BAD)
	_show_cell(_war, false)
	_command = UiTheme.make_label("", 12)   # komuta gücü artık gösterilmez (ordu/komutan arayüzden çıktı)

	# uyarılar: kaynak çubuğunun sağında, aynı boyda kutu (uyarı yokken gizli). Eskiden burada kara / deniz / hava
	# birikimi vardı; hiçbir şeye harcanmadığı için kaldırıldı
	alert_strip = PanelContainer.new()
	alert_strip.add_theme_stylebox_override("panel", _frame_box("mil_frame", 26, 20, 12))
	alert_strip.custom_minimum_size.y = BAR_H
	alert_strip.mouse_filter = Control.MOUSE_FILTER_STOP
	alert_strip.visible = false
	stats_line.add_child(alert_strip)
	alert_row = HBoxContainer.new()
	alert_row.alignment = BoxContainer.ALIGNMENT_CENTER
	alert_row.add_theme_constant_override("separation", 6)
	alert_strip.add_child(alert_row)

	# menü: ekranın sol kenarında, portrenin altında alt alta düğmeler; arkalarında üstteki kutuların çerçevesinden
	# dikey tepsi (köşeler olduğu gibi, kenarlar ve orta uzamaz, döşenir)
	var tray := PanelContainer.new()
	var tsb := _frame_box("mil_frame", 26, 14, 18)
	if not SELECT_SKIN:                    # panel zemininin resmi döşenince dikiş görünür: uzar
		tsb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	tray.add_theme_stylebox_override("panel", tsb)
	tray.mouse_filter = Control.MOUSE_FILTER_STOP
	tray.position = Vector2(EDGE, MENU_TOP)
	_tray = tray
	add_child(tray)
	task_row = VBoxContainer.new()
	task_row.add_theme_constant_override("separation", 8)
	tray.add_child(task_row)
	_portrait.resized.connect(_sync_tray)
	_sync_tray()

	# --- tarih & hız: sağ üst köşe; sayfanın tarih kutusu (dünya dairesi, çubuk ve üç düğme yuvası hazır)
	var dt: Texture2D = sheet("date_frame")
	var dsize := dt.get_size() * K
	var date_panel: Control
	if SELECT_SKIN:
		# öbür kutularla aynı zemin; sayfanın kutusundan yalnız dünya dairesi ve hız çubuğunun oyuğu kesilip konur
		# (düğmelerin kendi çerçevesi var)
		var dp := Panel.new()
		dp.add_theme_stylebox_override("panel", _frame_box("date_frame", 26, 0, 0))
		date_panel = dp
		for part: Array in [[DATE_GLOBE_CUT, true], [DATE_TRACK_CUT, false]]:
			var r: Rect2i = part[0]
			var cut := TextureRect.new()
			cut.texture = _date_cut(r, part[1])
			cut.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			cut.stretch_mode = TextureRect.STRETCH_SCALE
			cut.position = Vector2(r.position) * K
			cut.size = Vector2(r.size) * K
			cut.mouse_filter = Control.MOUSE_FILTER_IGNORE
			date_panel.add_child(cut)
	else:
		var tr_bg := TextureRect.new()
		tr_bg.texture = dt
		tr_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr_bg.stretch_mode = TextureRect.STRETCH_SCALE
		date_panel = tr_bg
	date_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	date_panel.anchor_left = 1.0
	date_panel.anchor_right = 1.0
	date_panel.offset_left = -8 - dsize.x
	date_panel.offset_right = -8
	date_panel.offset_top = EDGE
	date_panel.offset_bottom = EDGE + dsize.y
	add_child(date_panel)
	globe = WorldGlobe.new()
	globe.position = DATE_GLOBE * K - Vector2(WorldGlobe.SIZE, WorldGlobe.SIZE) * 0.5
	date_panel.add_child(globe)
	_date = UiTheme.make_label("", 15)
	_date.add_theme_font_override("font", UiTheme.bold_font())
	_date.position = DATE_TEXT.position * K
	_date.size = DATE_TEXT.size * K
	_date.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	date_panel.add_child(_date)
	# hız: çubuğun yuvasında altın dolgu (kademe / en yüksek)
	_speed_bar = TextureProgressBar.new()
	_speed_bar.texture_progress = sheet("bar_fill")
	_speed_bar.nine_patch_stretch = true
	_speed_bar.stretch_margin_left = 8
	_speed_bar.stretch_margin_right = 8
	_speed_bar.min_value = 0
	_speed_bar.max_value = GameClock.MAX_SPEED
	_speed_bar.position = DATE_TRACK.position * K
	_speed_bar.size = DATE_TRACK.size * K
	_speed_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	date_panel.add_child(_speed_bar)
	_scen = UiTheme.make_label("", 13, UiTheme.TEXT_DIM)
	_scen.visible = false
	# düğmeler: duraklat, oynat (akarken yavaşlatır), hızlandır
	_pause_btn = _sheet_button("btn_pause", tr("UI_PAUSE_TIP"), func() -> void:
		if not GameClock.paused:
			GameClock.toggle_pause())
	_play_btn = _sheet_button("btn_play", tr("TIP_PLAY"), func() -> void:
		if GameClock.paused:
			GameClock.toggle_pause()
		else:
			GameClock.change_speed(-1))
	_fast_btn = _sheet_button("btn_fast", tr("TIP_SPEED_UP"), func() -> void:
		if GameClock.paused:
			GameClock.toggle_pause()
		GameClock.change_speed(1))
	for bi in 3:
		var b: TextureButton = [_pause_btn, _play_btn, _fast_btn][bi]
		var bs := b.texture_normal.get_size() * K
		b.size = bs
		b.position = DATE_BUTTONS[bi] * K - bs * 0.5
		date_panel.add_child(b)

	GameClock.hour_passed.connect(_update_date)
	World.game_started.connect(_update_date)       # oyun başkentte sabah başlar (saat başlangıçta ayarlanır)
	GameClock.time_state_changed.connect(func(_s: int, _p: bool) -> void: _update_time_state())
	World.daily_update.connect(_update_country)
	Military.sp_changed.connect(_update_country)
	Economy.building_completed.connect(func(_t: String, _s: int, _b: String) -> void: _update_country())
	World.player_changed.connect(func(_t: String) -> void: _update_country())
	_update_country()
	_update_date()
	_update_time_state()

var _bars := {}   ## kind -> [arka, dolgu] (eski görünüm; sayfanın çubuğunda doluluk çubuğu yok)

const BAR_H := 86.0              ## kaynak çubuğu ve kutuların boyu (sayfadaki 98 px × K)
const CELL_W := 92.0             ## kaynak çubuğunda her hücrenin genişliği (en uzun değer "416.6K", "300 +7" sığar)
const GAIN_LIFT := 1             ## artış yazısının yukarı kayması (px): büyük yazının alt payına göre ortalama

## Arayüz sayfası (assets/ui/ui-sprite2.png, tools/slice_ui_sprite.py ile assets/ui/sheet/ altına ayrılır)
const SHEET := "res://assets/ui/sheet/"
const K := 0.88                  ## sayfa parçalarının ölçeği: sayfanın üst satırı (2106 px) 1920'ye sığar
var _portrait: Control
var _portrait_mask: Panel             ## portreyi yuvarlak köşeyle kırpar (çerçevenin iç köşesine uyar)
var _stats_line: Control
var _tray: Control
const PORTRAIT_INSET := 7.0          ## portrenin çerçeve kenarından içeri payı (menü çerçevesinin pirinç kenarı ~3 px)
const PORTRAIT_RADIUS := 7           ## portre köşe yuvarlaklığı: çerçevenin (köşe ~11 px) iç köşesi
const PORTRAIT_HOLE := Rect2(13, 11, 156, 148)       ## portre çerçevesinin içi (çerçeve resminde)
## tarih kutusunun yuvaları (çerçeve resminde, ölçülü): dünya dairesinin ortası, tarih yazısı, hız çubuğu, düğmeler
const DATE_GLOBE := Vector2(54, 50)
const DATE_TEXT := Rect2(100, 12, 190, 36)
const DATE_TRACK := Rect2(100, 53, 158, 13)
const DATE_BUTTONS: Array[Vector2] = [Vector2(303, 50), Vector2(375, 50), Vector2(446, 50)]
const ICONS := {ResourceIcon.Kind.POLITICAL_POWER: "icon_political_power", ResourceIcon.Kind.STABILITY: "icon_stability",
	ResourceIcon.Kind.WAR_SUPPORT: "icon_war_support", ResourceIcon.Kind.MANPOWER: "icon_manpower",
	ResourceIcon.Kind.FACTORY: "icon_factory", ResourceIcon.Kind.FUEL: "icon_fuel", ResourceIcon.Kind.SUPPLY: "icon_supply",
	ResourceIcon.Kind.CONVOY: "icon_convoy", ResourceIcon.Kind.TENSION: "icon_tension", ResourceIcon.Kind.XP_ARMY: "icon_army",
	ResourceIcon.Kind.XP_NAVY: "icon_navy", ResourceIcon.Kind.XP_AIR: "icon_air"}

var _speed_bar: TextureProgressBar
var _play_btn: TextureButton
var _fast_btn: TextureButton

static func sheet(name: String) -> Texture2D:
	return load(SHEET + name + ".png")

## Deneme: üst çubuk, uyarı kutusu, portre ve menü tepsisi ülke seçimindeki panelin zeminiyle (CountrySelect,
## panel_right: ince pirinç kenar, süslü köşeler). false: sayfanın kendi çerçeveleri
const SELECT_SKIN := true
const SELECT_SCALE := 0.6              ## panel dokusu bu kata küçültülür: süslü köşe (~48 px) 86 px'lik çubuğa sığsın
const SELECT_SLICE := 30
static var _select_tex: Texture2D

static func _select_texture() -> Texture2D:
	if _select_tex == null:
		var img: Image = CountrySelect.tex("panel_right").get_image()
		img.resize(int(img.get_width() * SELECT_SCALE), int(img.get_height() * SELECT_SCALE), Image.INTERPOLATE_LANCZOS)
		_plain_inside(img)
		_select_tex = ImageTexture.create_from_image(img)
	return _select_tex

## Tarih kutusundan kesilen parçalar (date_frame pikseli): dünya dairesinin pirinç halkası, hız çubuğunun oyuğu
const DATE_GLOBE_CUT := Rect2i(16, 14, 76, 76)
const DATE_TRACK_CUT := Rect2i(96, 49, 166, 22)

## Kesilen parçanın dışı saydam: daire ya da yuvarlak uçlu çubuk (kenarı 1,5 px yumuşak)
static func _date_cut(r: Rect2i, round_shape: bool) -> Texture2D:
	var img: Image = sheet("date_frame").get_image().get_region(r)
	img.convert(Image.FORMAT_RGBA8)
	var w := float(r.size.x)
	var h := float(r.size.y)
	var rad := minf(w, h) * 0.5
	for y in r.size.y:
		for x in r.size.x:
			var q := Vector2(x + 0.5, y + 0.5)
			var d: float
			if round_shape:
				d = q.distance_to(Vector2(w, h) * 0.5) - rad
			else:
				var cx := clampf(q.x, rad, w - rad)
				d = q.distance_to(Vector2(cx, h * 0.5)) - rad
			var c := img.get_pixel(x, y)
			c.a *= clampf(0.5 - d / 1.5, 0.0, 1.0)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)

## Panelin içindeki resim (uçak, tank, bulut) silinir: çerçevenin içi panelin üstündeki sade koyu dokuyla dolar (yansıtarak
## döşenir: dikiş yok). Pirinç kenar ve süslü köşeler korunur (sıcak, doygun pikseller; iç resim gri tonlu).
const PLAIN_BORDER := 0.045            ## kenar kalınlığı (panel eninin katı, ~16 px / 361)
const PLAIN_PATCH := Rect2(0.11, 0.026, 0.78, 0.105)   ## sade doku alanı (panelin üstü; enin/boyun katı)

static func _plain_inside(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var b := int(w * PLAIN_BORDER)
	var px := int(w * PLAIN_PATCH.position.x)
	var py := int(h * PLAIN_PATCH.position.y)
	var pw := maxi(int(w * PLAIN_PATCH.size.x), 1)
	var ph := maxi(int(h * PLAIN_PATCH.size.y), 1)
	var src := img.duplicate() as Image
	# sade alanın kendi üstten alta / yandan yana koyulaşması döşemede bant olurdu: satır ve sütun ortalamasıyla düzlenir
	var row := PackedFloat32Array()
	var col := PackedFloat32Array()
	row.resize(ph)
	col.resize(pw)
	for y in ph:
		for x in pw:
			var l := src.get_pixel(px + x, py + y).get_luminance() + 0.0001
			row[y] += l / pw
			col[x] += l / ph
	var gm := 0.0
	for v in row:
		gm += v / ph
	for y in range(b, h - b):
		var ty := (y - b) % (ph * 2)
		ty = ty if ty < ph else ph * 2 - 1 - ty
		for x in range(b, w - b):
			var c := img.get_pixel(x, y)
			if c.r > 0.2 and c.r > c.b * 1.8 and c.r > c.g * 1.15:
				continue                                  # pirinç süs
			var tx := (x - b) % (pw * 2)
			tx = tx if tx < pw else pw * 2 - 1 - tx
			var s := src.get_pixel(px + tx, py + ty) * (gm * gm / (row[ty] * col[tx]))
			img.set_pixel(x, y, Color(minf(s.r, 1.0), minf(s.g, 1.0), minf(s.b, 1.0), c.a))

## Üst çubuk ve menünün zemini (SELECT_SKIN) yan paneller için: h/v iç boşluk
static func skin_box(h: int, v: int) -> StyleBoxTexture:
	return _frame_box("mil_frame", 26, h, v)

## Sayfanın çerçevesi kutu olarak: köşeler (slice px) olduğu gibi, orta uzar; h/v iç boşluk
static func _frame_box(name: String, slice: int, h: int, v: int) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = sheet(name)
	if SELECT_SKIN:
		sb.texture = _select_texture()
		slice = SELECT_SLICE
	sb.texture_margin_left = slice
	sb.texture_margin_right = slice
	sb.texture_margin_top = slice
	sb.texture_margin_bottom = slice
	sb.content_margin_left = h
	sb.content_margin_right = h
	sb.content_margin_top = v
	sb.content_margin_bottom = v
	return sb

## Sayfanın düğmesi: resim kendi çerçevesiyle; üstüne gelince aydınlanır
func _sheet_button(name: String, tip: String, fn: Callable) -> TextureButton:
	var b := TextureButton.new()
	b.texture_normal = sheet(name)
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(fn)
	b.mouse_entered.connect(func() -> void: b.self_modulate = Color(1.3, 1.25, 1.15))
	b.mouse_exited.connect(func() -> void: b.self_modulate = Color.WHITE)
	return b

## Portre kaynak çubuğuyla aynı boyda: çerçeve, içindeki resim (eski çerçevedeki oranda) ve küçük bayrak; çubuk sağında
func _fit_portrait(h: float) -> void:
	var inner_h := h - PORTRAIT_INSET * 2.0
	var inner := Vector2(inner_h * PORTRAIT_HOLE.size.x / PORTRAIT_HOLE.size.y, inner_h)
	var psize := inner + Vector2.ONE * PORTRAIT_INSET * 2.0
	_portrait.size = psize
	_portrait.custom_minimum_size = psize
	_portrait_mask.position = Vector2.ONE * PORTRAIT_INSET
	_portrait_mask.size = inner
	_mini_flag.size = Vector2(inner.x * 0.27, inner.x * 0.18)
	_mini_flag.position = _portrait_mask.position + inner - _mini_flag.size - Vector2(2, 2)
	_stats_line.position.x = EDGE + psize.x + 6.0
	_sync_tray()

## Menü tepsisi portrenin hemen altında ve onunla aynı enle (düğmeler ortada, yan paylar kalan yerden). Kaynak çubuğu
## yazılar yerleşince büyür (86 → ~105 px), portre de onunla: tepsi portrenin o anki boyunu izler
func _sync_tray() -> void:
	if _tray == null or _portrait == null:
		return
	var psize := _portrait.size
	_tray.position.y = EDGE + psize.y + MENU_GAP
	var sb := _tray.get_theme_stylebox("panel") as StyleBoxTexture
	if sb:
		var side := maxf((psize.x - MENU_ICON) * 0.5, 4.0)
		sb.content_margin_left = side
		sb.content_margin_right = side
	_tray.custom_minimum_size.x = psize.x
	_tray.size.x = psize.x

## Gösterge hücresi, hücreler arası ayraç: vertical ikon üstte, değer altında (kaynak çubuğu ve kutu); değilse ikon solda,
## değer sağda
func _stat(parent: Container, kind: ResourceIcon.Kind, tip_key: String, vertical: bool = false) -> Label:
	var div: TextureRect = null
	if parent.get_child_count() > 0:
		div = TextureRect.new()
		div.texture = sheet("divider")
		div.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		div.stretch_mode = TextureRect.STRETCH_SCALE
		div.custom_minimum_size = Vector2(4, BAR_H - 34.0)
		div.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		div.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(div)
	# hücreler eşit genişlikte: ayraçlar eşit aralıkla dizilir, hücre içeriği ortada (değerin uzunluğu aralığı bozmaz)
	var cell := MarginContainer.new()
	cell.tooltip_text = tr(tip_key)
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	cell.custom_minimum_size.x = CELL_W
	cell.add_theme_constant_override("margin_left", 4)
	cell.add_theme_constant_override("margin_right", 4)
	var box: BoxContainer = VBoxContainer.new() if vertical else HBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0 if vertical else 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(box)
	var tex: Texture2D = sheet(ICONS[kind]) if ICONS.has(kind) else UiTheme.icon(ResourceIcon.FILES.get(kind, ""))
	if tex:
		var icon := TextureRect.new()
		icon.texture = UiTheme.trimmed(tex)
		icon.custom_minimum_size = Vector2(38, 34) if vertical else Vector2(38, 38)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		box.add_child(icon)
	else:
		var ri := ResourceIcon.new(kind)
		ri.custom_minimum_size = Vector2(34, 34)
		ri.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		box.add_child(ri)
	var l := UiTheme.make_label("", 19)
	l.add_theme_font_override("font", UiTheme.bold_font())
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(l)
	parent.add_child(cell)
	if div:
		cell.set_meta("div", div)          # hücre gizlenince önündeki ayraç da (sonda boş ayraç kalmasın)
	return l

## Değerin sağına günlük artış etiketi (küçük, yeşil): değer ile aynı satırda, ikisi birlikte ortalı
func _gain(value: Label) -> Label:
	var box := value.get_parent()
	var line := HBoxContainer.new()
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_theme_constant_override("separation", 3)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.remove_child(value)
	box.add_child(line)
	# solda artışın görünmez eşi: sayı ikonun tam altında ortalı kalır, artış sağında durur
	var ghost := UiTheme.make_label("", 13)
	ghost.add_theme_font_override("font", UiTheme.bold_font())
	ghost.self_modulate = Color(1, 1, 1, 0)
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(ghost)
	line.add_child(value)
	var g := UiTheme.make_label("", 13)
	g.add_theme_font_override("font", UiTheme.bold_font())
	g.add_theme_color_override("font_color", UiTheme.GOOD)
	g.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# büyük rakamların ortasına hizalı: büyük yazının alt payı (inen harf boşluğu) küçüğü aşağıda gösteriyordu
	var lift := MarginContainer.new()
	lift.add_theme_constant_override("margin_bottom", GAIN_LIFT * 2)
	lift.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lift.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lift.add_child(g)
	line.add_child(lift)
	g.set_meta("ghost", ghost)
	return g

## Hücreyi önündeki ayraçla birlikte göster / gizle
func _show_cell(l: Label, on: bool) -> void:
	var cell := _cell_of(l)
	cell.visible = on
	var div: Control = cell.get_meta("div", null)
	if div:
		div.visible = on

func _set_bar(kind: ResourceIcon.Kind, ratio: float) -> void:
	if not _bars.has(kind):
		return
	var fill: ColorRect = _bars[kind][1]
	fill.size.x = 56.0 * clampf(ratio, 0.0, 1.0)

func _cell_of(l: Label) -> Control:
	var n := l.get_parent()
	while not n is MarginContainer:
		n = n.get_parent()
	return n

## Günlük artış: artıyorsa yeşil "+n", azalıyorsa kırmızı, sıfırsa boş
func _set_gain(g: Label, v: float) -> void:
	var n := roundi(v)
	g.text = "" if n == 0 else ("+%d" % n if n > 0 else "%d" % n)
	(g.get_meta("ghost") as Label).text = g.text
	g.add_theme_color_override("font_color", UiTheme.GOOD if n > 0 else UiTheme.BAD)

func _update_country() -> void:
	var c := World.player()
	if c == null:
		return
	var por := UiTheme.portrait(c)
	if por:
		_flag.texture = _portrait_crop(por)
		_flag.stretch_mode = TextureRect.STRETCH_SCALE
		_mini_flag.texture = FlagFactory.get_flag(c)
		_mini_flag.visible = true
	else:
		_flag.texture = FlagFactory.get_flag(c)
		_flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_mini_flag.visible = false
	_name.text = c.display_name()
	_portrait.tooltip_text = tr("TIP_COUNTRY") % [c.display_name(), c.leader_name(), tr("IDEOLOGY_" + c.ideology), UiTheme.format_number(c.population), c.states.size()]
	_leader.text = "%s — %s" % [c.leader_name(), tr("IDEOLOGY_" + c.ideology)]
	_pp.text = "%d" % int(c.political_power)
	_set_gain(_pp_gain, c.daily_political_power_gain())
	_cell_of(_pp).tooltip_text = tr("TIP_POLITICAL_POWER") % [c.daily_political_power_gain()]
	var stab := Politics.stability(c)
	var ws := Politics.war_support(c)
	_stability.text = "%d%%" % roundi(stab * 100)
	_war_support.text = "%d%%" % roundi(ws * 100)
	_stability.add_theme_color_override("font_color", UiTheme.BAD if stab < 0.3 else UiTheme.TEXT)
	var sg := func(v: float) -> String: return ("+" if v >= 0 else "") + "%d%%" % roundi(v * 100)
	_cell_of(_stability).tooltip_text = tr("POL_STAB_BREAKDOWN") % [roundi(c.stability * 100), sg.call(c.mod("stability")), sg.call(Politics.party_stability_bonus(c)),
		roundi(stab * 100), sg.call(Politics.stability_factory_mod(c)), sg.call(Politics.stability_pp_mod(c))]
	_cell_of(_war_support).tooltip_text = tr("POL_WS_BREAKDOWN") % [roundi(c.war_support * 100), sg.call(c.mod("war_support")), sg.call(Politics.tension_war_support()),
		sg.call(Politics.war_state_support(c)), roundi(ws * 100), roundi(Diplomacy.capitulation_threshold(c) * 100)]
	_cell_of(_manpower).tooltip_text = tr("TIP_MANPOWER") % [UiTheme.format_number(c.recruitable_manpower()), Economy.law_name("conscription", c.laws["conscription"])]
	_manpower.text = UiTheme.format_number(c.recruitable_manpower())
	# sanayi puanı (SP): asker alma ve keşif parası; fabrikalar sabit, sayıları değil SP gösterilir
	var inc := Military.sp_income(c)
	_factories.text = "%d" % int(c.sp)
	_set_gain(_sp_gain, inc)
	var tip := tr("TIP_SP") % [int(c.sp), roundi(inc), Economy.count(c, "military_factory"), Economy.count(c, "civilian_factory")]
	for r: String in Economy.resource_names:
		var n := Economy.resource_total(c, r)
		if n > 0:
			tip += "\n%s: %d" % [tr("RES_" + r), n]
	_cell_of(_factories).tooltip_text = tip
	# depo sığası günlük hesaplanır; henüz hesaplanmadıysa (eski kayıt, ilk gün) eldeki yakıt dolu sayılır
	var fcap := c.fuel_cap if c.fuel_cap > 0.0 else maxf(c.fuel, 1.0)
	_fuel.text = "%d%%" % roundi(maxf(c.fuel, 0.0) / fcap * 100.0)
	_set_bar(ResourceIcon.Kind.FUEL, maxf(c.fuel, 0.0) / fcap)
	_fuel.add_theme_color_override("font_color", Color(0.95, 0.4, 0.3) if c.fuel <= fcap * 0.1 and c.fuel >= 0.0 else UiTheme.TEXT)
	if _fuel.get_parent() != null:           # yakıt hücresi üst çubukta yok (gösterilmiyor)
		_cell_of(_fuel).tooltip_text = tr("UI_FUEL_TIP") + "\n" + tr("UI_FUEL_DETAIL") % [UiTheme.format_number(roundi(maxf(c.fuel, 0.0))), UiTheme.format_number(roundi(fcap))]
	# ikmal doluluğu: ikmalli tümen oranı
	var divs := Military.country_divisions(c.tag)
	var sup := 0
	for d in divs:
		if d.supplied:
			sup += 1
	var sup_pct := 100 if divs.is_empty() else roundi(100.0 * sup / divs.size())
	_supply.text = "%d%%" % sup_pct
	_set_bar(ResourceIcon.Kind.SUPPLY, sup_pct / 100.0)
	_supply.add_theme_color_override("font_color", UiTheme.BAD if sup_pct < 80 else UiTheme.TEXT)
	if _supply.get_parent() != null:         # ikmal hücresi üst çubukta yok (ikmalsiz tümen uyarısı var)
		_cell_of(_supply).tooltip_text = tr("UI_SUPPLY_TIP") + "\n" + tr("UI_SUPPLY_DETAIL") % [sup, divs.size()]
	# konvoylar: stok / ithalat ihtiyacı
	var conv := int(c.stockpile.get("convoy", 0.0))
	var need := 0.0
	for i: Dictionary in c.imports:
		need += float(i["amount"]) * 0.5
	_convoys.text = "%d" % conv
	_convoys.add_theme_color_override("font_color", UiTheme.BAD if float(conv) < need else UiTheme.TEXT)
	_cell_of(_convoys).tooltip_text = tr("UI_CONVOY_TIP") + "\n" + tr("UI_CONVOY_DETAIL") % [conv, ceili(need)]
	_command.text = "%d" % int(c.command_power)
	_tension.text = "%d%%" % roundi(World.world_tension)
	if Diplomacy.at_war(c.tag):
		var foes := Diplomacy.enemies_of(c.tag)
		_show_cell(_war, true)
		_war.text = "%d · %d%%" % [foes.size(), roundi(c.surrender_progress * 100)]
		_cell_of(_war).tooltip_text = tr("TIP_AT_WAR") % [", ".join(foes.map(func(t: String) -> String: return World.countries[t].display_name())), roundi(Diplomacy.capitulation_threshold(c) * 100)]
	else:
		_show_cell(_war, false)

## Portre (dikey, 400 × 500) çerçevenin içinin oranında kırpılır, üstten hizalı (ortadan kırpınca başın üstü
## çerçeveye kesiliyordu): baştan %3 pay, fazlası alttan gider
var _crop_cache := {}
func _portrait_crop(tex: Texture2D) -> Texture2D:
	if _crop_cache.has(tex):
		return _crop_cache[tex]
	var ts := tex.get_size()
	var want := PORTRAIT_HOLE.size.x / PORTRAIT_HOLE.size.y
	var region := Rect2(Vector2.ZERO, ts)
	if ts.x / ts.y < want:
		var h := ts.x / want
		region = Rect2(0.0, minf(ts.y * 0.03, ts.y - h), ts.x, h)
	else:
		var w := ts.y * want
		region = Rect2((ts.x - w) * 0.5, 0.0, w, ts.y)
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = region
	_crop_cache[tex] = at
	return at

func _update_date() -> void:
	_date.text = GameClock.date_string()
	_update_scenario()

## Senaryo satırı: senaryolarda süre olmadığı için şimdilik gösterilmez (yeri hazır)
func _update_scenario() -> void:
	_scen.visible = false

## Hız çubuğu kademeyi gösterir; duraklatılınca duraklat düğmesi altın parlar (çubuk o an sönük)
func _update_time_state() -> void:
	_speed_bar.value = GameClock.speed
	_speed_bar.modulate = Color(1, 1, 1, 0.4) if GameClock.paused else Color.WHITE
	_pause_btn.modulate = Color(1.35, 1.15, 0.7) if GameClock.paused else Color.WHITE
