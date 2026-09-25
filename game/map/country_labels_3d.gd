class_name CountryLabels3D
extends Node3D
## klasik strateji tarzı ülke adları: her harf araziye yatırılmış ayrı bir Label3D (her zoom'da keskin).
## Yerleşim hesabı CountryLabels'tan gelir; yakın zoom'da söner, küçük ülkeler daha yakında belirir.

const GLYPH_FONT_SIZE := 160          ## tek önbellek boyutu; dünya boyutu pixel_size ile ayarlanır
const TEXT_COLOR := Color(0.98, 0.95, 0.86, 0.88)
const OUTLINE_COLOR := Color(0.08, 0.06, 0.04, 0.55)
const LIFT := 3.0

var map: MapView3D
var _calc := CountryLabels.new()
var _font: Font

func _ready() -> void:
	_font = CountryLabels.label_font()
	rebuild()
	World.ownership_changed.connect(rebuild)

func rebuild() -> void:
	for ch in get_children():
		ch.queue_free()
	_calc.rebuild()
	for lbl: CountryLabels.Label2D in _calc.labels():
		var world_size := float(lbl.font_size)          # harf yüksekliği (dünya birimi)
		var px := world_size / GLYPH_FONT_SIZE
		# boyuta göre görünürlük: büyük adlar uzaktan, küçükler yakından okunur; çok yakında söner
		var begin := world_size * 10.0
		var end := world_size * 70.0
		for i in lbl.glyphs.size():
			var p: Vector2 = lbl.positions[i]
			var l := Label3D.new()
			l.text = lbl.glyphs[i]
			l.font = _font
			l.font_size = GLYPH_FONT_SIZE
			l.outline_size = 22
			l.pixel_size = px
			l.modulate = TEXT_COLOR
			l.outline_modulate = OUTLINE_COLOR
			l.double_sided = true
			l.no_depth_test = true
			l.shaded = false
			l.alpha_cut = Label3D.ALPHA_CUT_DISABLED
			l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			l.render_priority = 1
			l.outline_render_priority = 0
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			var h := maxf(map.height_at(p), 0.0) + LIFT
			l.transform = Transform3D(Basis(Vector3.UP, -lbl.angles[i]) * Basis(Vector3.RIGHT, -PI / 2), Vector3(p.x, h, p.y))
			l.visibility_range_begin = begin
			l.visibility_range_begin_margin = begin * 0.35
			l.visibility_range_end = end
			l.visibility_range_end_margin = end * 0.2
			l.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			add_child(l)
