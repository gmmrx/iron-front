class_name LoadingScreen
extends CanvasLayer
## Açılış yükleme ekranı: arka plan (assets/ui/menu-bg.png, ana menüyle aynı), ortada büyük logo, altında küçük
## yükleme çubuğu (assets/ui/loading-bar.png: üstte dolu, altta boş hali; dolu hali soldan açılır), sağ altta yüklenen /
## toplam MB. main kurulum adımlarında `progress`i ilerletir; bitince logo küçülüp menüdeki yerine gider (to_menu) ya da
## ekran söner (fade_out).

const BG := "res://assets/ui/menu-bg.png"
const LOGO := "res://assets/ui/logo.png"
const BAR := "res://assets/ui/loading-bar.png"
const BAR_FULL := Rect2(45, 249, 2082, 108)    ## sayfadaki dolu çubuk
const BAR_EMPTY := Rect2(45, 428, 2082, 108)   ## sayfadaki boş çubuk
const BAR_W := 460.0
const FILL := Vector2(0.03, 0.97)              ## çubuğun iç kısmı (sivri uçların arası): ilerleme bu aralıkta dolar
const LOGO_W := 900.0                          ## yüklenirken logonun genişliği

var progress := 0.0                            ## hedef ilerleme (0..1)
var _shown := 0.0                              ## çubuğun gösterdiği (hedefe yumuşakça gelir)
var _root: Control
var _logo: TextureRect
var _bar_box: Control
var _fill: Control                             ## dolu çubuğu kırpan alan (genişliği ilerleme)
var _mb: Label
var _total_mb := 0.0

func _ready() -> void:
	layer = 30
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP              # yüklenirken haritaya tıklanmaz
	add_child(_root)
	_root.add_child(MainMenu.background())
	_root.add_child(MainMenu._vignette())                       # menüdekiyle aynı: geçişte ekran birden kararmasın
	var vp := _root.get_viewport_rect().size
	var logo_tex: Texture2D = load(LOGO)
	_logo = TextureRect.new()
	_logo.texture = logo_tex
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lw := minf(LOGO_W, vp.x * 0.7)
	var lsize := Vector2(lw, lw * logo_tex.get_height() / logo_tex.get_width())
	_logo.size = lsize
	_logo.position = Vector2((vp.x - lsize.x) * 0.5, vp.y * 0.45 - lsize.y * 0.5)
	_root.add_child(_logo)
	# çubuk: boş hali tam boy, dolu hali üstünde soldan kırpılarak açılır (doku uzamaz)
	var sheet: Texture2D = load(BAR)
	var bh := BAR_W * BAR_FULL.size.y / BAR_FULL.size.x
	_bar_box = Control.new()
	_bar_box.size = Vector2(BAR_W, bh)
	_bar_box.position = Vector2((vp.x - BAR_W) * 0.5, _logo.position.y + lsize.y + 34.0)
	_bar_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bar_box)
	_bar_box.add_child(_bar_part(sheet, BAR_EMPTY, bh))
	_fill = Control.new()
	_fill.clip_contents = true
	_fill.size = Vector2(0, bh)
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_box.add_child(_fill)
	_fill.add_child(_bar_part(sheet, BAR_FULL, bh))
	_mb = UiTheme.make_label("", 18, Color(1, 1, 1, 0.65))
	_mb.add_theme_font_override("font", UiTheme.bold_font())
	_mb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_mb.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_mb.offset_left = -400
	_mb.offset_top = -48
	_mb.offset_right = -28
	_mb.offset_bottom = -20
	_root.add_child(_mb)
	_total_mb = game_size_mb()
	_update_bar()

func _bar_part(sheet: Texture2D, region: Rect2, h: float) -> TextureRect:
	var at := AtlasTexture.new()
	at.atlas = sheet
	at.region = region
	var t := TextureRect.new()
	t.texture = at
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.size = Vector2(BAR_W, h)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

func _process(delta: float) -> void:
	if not is_equal_approx(_shown, progress):
		# ağır adımların arasında az kare çizilir: çubuk hedefe kısa sürede yetişir, geri gitmez
		_shown = minf(progress, _shown + maxf(progress - _shown, 0.0) * (1.0 - exp(-10.0 * delta)) + delta * 0.05)
		_update_bar()

func _update_bar() -> void:
	_fill.size.x = BAR_W * lerpf(FILL.x, FILL.y, clampf(_shown, 0.0, 1.0)) if _shown > 0.001 else 0.0
	if _total_mb > 0.0:
		_mb.text = "%.1f / %.1f MB" % [_total_mb * clampf(_shown, 0.0, 1.0), _total_mb]

## Yükleme bitti, menüye: çubuk ve yazı söner, logo küçülüp menüdeki yerine gider (menü aynı yerde aynı logoyu çizer)
func to_menu(secs: float) -> Tween:
	progress = 1.0
	_shown = 1.0
	_update_bar()
	var target := MainMenu.logo_rect(_root.get_viewport_rect().size)
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_bar_box, "modulate:a", 0.0, 0.25)
	tw.tween_property(_mb, "modulate:a", 0.0, 0.25)
	tw.tween_property(_logo, "position", target.position, secs).set_delay(0.15)
	tw.tween_property(_logo, "size", target.size, secs).set_delay(0.15)
	return tw

## Menüye gitmeyen açılış (kayıttan devam, geliştirici yolları): ekran söner ve kalkar
func fade_out(secs: float) -> void:
	if secs <= 0.0:
		queue_free()
		return
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, secs)
	tw.tween_callback(queue_free)

## Oyunun toplam boyu (MB): dışa aktarılmış sürümde paket dosyası (web: indirilen paket + motor), kaynaktan çalışırken
## oyunun veri klasörleri
static func game_size_mb() -> float:
	if OS.has_feature("web"):
		var r: Variant = JavaScriptBridge.eval("(function(){try{var s=GODOT_CONFIG.fileSizes,t=0;for(var k in s)t+=s[k];return t;}catch(e){return 0;}})()", true)
		if (r is float or r is int) and float(r) > 0.0:
			return float(r) / 1048576.0
	var exe := OS.get_executable_path()
	var pck := exe.get_basename() + ".pck"
	if not OS.has_feature("editor"):
		if FileAccess.file_exists(pck):
			return FileAccess.get_size(pck) / 1048576.0
		if FileAccess.file_exists(exe):
			return FileAccess.get_size(exe) / 1048576.0          # paket çalıştırılabilir dosyanın içinde
	return (_dir_size("res://assets") + _dir_size("res://data") + _dir_size("res://game")) / 1048576.0

static func _dir_size(path: String) -> float:
	var total := 0.0
	var d := DirAccess.open(path)
	if d == null:
		return 0.0
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		if not name.begins_with("."):
			var full := path.path_join(name)
			if d.current_is_dir():
				total += _dir_size(full)
			elif not name.ends_with(".import") and not name.ends_with(".uid"):
				total += FileAccess.get_size(full)
		name = d.get_next()
	return total
