class_name WorldGlobe
extends Control
## Dünya saati: üst çubukta tarihin yanında küçük, dönen gece-gündüz küresi (assets/shaders/world_globe). Küre oyuncunun
## başkentine bakar; güneşin altındaki boylam oyun saatiyle döner (12:00'de başkentin üstünde), sapması mevsime göre.
## İpucu saati ve gece/gündüzü söyler. Doku haritanınkiyle aynı (yeni resim dosyası yok).

const SIZE := 50.0
var _rect: ColorRect
var _mat: ShaderMaterial
var _tip_timer := 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_STOP
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://assets/shaders/world_globe.gdshader")
	_rect = ColorRect.new()
	_rect.material = _mat
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)

## Haritanın arazi dokusu ve izdüşüm değerleri (main kurar)
func setup(tex: Texture2D, map_h: float) -> void:
	_mat.set_shader_parameter("map_tex", tex)
	_mat.set_shader_parameter("map_h", map_h)
	_mat.set_shader_parameter("lon_min", deg_to_rad(World._lon_min))
	_mat.set_shader_parameter("y_top", World._y_top)
	_mat.set_shader_parameter("px_per_rad", World._px_per_rad)

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	var cap := World.province(World.capital_province(World.player_tag)) if World.player_tag != "" else null
	var ll := cap.lonlat if cap else Vector2(30.0, 40.0)
	var h := float(GameClock.hour) + GameClock.hour_fraction()
	# güneş: öğlen başkentin boylamında; sapma yılın gününe göre (21 Haziran'da +23,4°)
	var doy := float(_day_of_year())
	var decl := deg_to_rad(23.44) * sin(TAU * (doy - 80.0) / 365.0)
	_mat.set_shader_parameter("view_lon", deg_to_rad(ll.x))
	_mat.set_shader_parameter("view_lat", deg_to_rad(clampf(ll.y, -40.0, 50.0)) * 0.8)
	_mat.set_shader_parameter("sun_lon", deg_to_rad(ll.x + (12.0 - h) * 15.0))
	_mat.set_shader_parameter("sun_lat", decl)
	_tip_timer -= delta
	if _tip_timer <= 0.0:
		_tip_timer = 0.5
		var day := h >= 6.0 and h < 20.0
		tooltip_text = tr("GLOBE_TIP") % ["%02d:%02d" % [int(h), int((h - floorf(h)) * 60.0)], tr("GLOBE_DAY") if day else tr("GLOBE_NIGHT")]

func _day_of_year() -> int:
	var n := GameClock.day
	for m in GameClock.month - 1:
		n += GameClock.days_in_month(GameClock.year, m + 1)
	return n
