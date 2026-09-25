class_name CountryLabels
extends Node2D
## klasik strateji tarzı ülke adları: her ülkenin (bağlı) toprağı boyunca kavisli, ölçeğe göre büyüyen yazı.
## Sahiplik değişince yeniden hesaplanır; ekranda çok küçük/çok büyük kalan etiketler söner.

const MIN_AREA_KM2 := 2500.0
const MAX_ANGLE := deg_to_rad(80.0)
const MAX_FONT := 420.0
const LETTER_SPACING := 0.22       ## yazı boyutuna oranla harf aralığı
const FADE_MIN_PX := 8.0          ## ekranda bundan küçük harfler görünmez
const FADE_MAX_PX := 90.0          ## bundan büyük harfler söner (yakın zoom)
const TEXT_COLOR := Color(0.98, 0.96, 0.9, 0.92)
const OUTLINE_COLOR := Color(0.06, 0.05, 0.04, 0.6)

## Tek bir etiket: harf başına konum ve açı
class Label2D:
	var glyphs: PackedStringArray
	var positions: PackedVector2Array
	var angles: PackedFloat32Array
	var widths: PackedFloat32Array
	var font_size: int

signal redrawn

var _labels: Array[Label2D] = []
var _zoom_override := -1.0
var _font: Font
var _last_zoom := -1.0

func _ready() -> void:
	_ensure_font()
	rebuild()
	World.ownership_changed.connect(rebuild)

func _process(_delta: float) -> void:
	if _zoom_override > 0.0:
		return
	var z := get_viewport().get_canvas_transform().x.x
	if not is_equal_approx(z, _last_zoom):
		_last_zoom = z
		queue_redraw()

## 3D'de: ekran pikseli / dünya birimi dışarıdan verilir; %4'ten büyük değişimde yeniden çizilir.
func set_view_zoom(px_per_unit: float) -> void:
	_zoom_override = px_per_unit
	if _last_zoom <= 0.0 or absf(px_per_unit / _last_zoom - 1.0) > 0.04:
		_last_zoom = px_per_unit
		queue_redraw()

# ------------------------------------------------------------------ hesaplama
static func label_font() -> Font:
	var v := FontVariation.new()
	v.base_font = load("res://assets/fonts/CinzelVariable.ttf")
	v.variation_opentype = {"wght": 800}
	return v

func _ensure_font() -> void:
	if _font == null:
		_font = label_font()

## Etiketlerin hesaplanmış hâli (3D katman kullanır)
func labels() -> Array[Label2D]:
	return _labels

func rebuild() -> void:
	_ensure_font()
	_labels.clear()
	var owner_of := {}  # province id -> tag
	for st: StateRegion in World.states.values():
		for pid in st.provinces:
			owner_of[pid] = st.owner
	var seen := {}
	for pid: int in owner_of:
		if seen.has(pid):
			continue
		var tag: String = owner_of[pid]
		# aynı ülkeye ait bağlı kara bölgeleri (BFS)
		var comp: Array[Province] = []
		var queue: Array[int] = [pid]
		seen[pid] = true
		while not queue.is_empty():
			var cur: Province = World.province(queue.pop_back())
			comp.append(cur)
			for n in cur.adjacent:
				if not seen.has(n) and owner_of.get(n, "") == tag:
					seen[n] = true
					queue.append(n)
		var lbl := _make_label(World.countries[tag], comp)
		if lbl:
			_labels.append(lbl)
	queue_redraw()

func _make_label(c: Country, comp: Array[Province]) -> Label2D:
	var total := 0.0
	var mean := Vector2.ZERO
	for p in comp:
		total += p.area_km2
		mean += p.center * p.area_km2
	if total < MIN_AREA_KM2:
		return null
	mean /= total
	# ağırlıklı kovaryans -> ana eksen
	var sxx := 0.0
	var syy := 0.0
	var sxy := 0.0
	for p in comp:
		var d := p.center - mean
		sxx += d.x * d.x * p.area_km2
		syy += d.y * d.y * p.area_km2
		sxy += d.x * d.y * p.area_km2
	sxx /= total
	syy /= total
	sxy /= total
	var ang := 0.5 * atan2(2.0 * sxy, sxx - syy)
	# özdeğer oranı: şekil ne kadar uzunsa eksen o kadar güvenilir; yuvarlak şekiller yatay yazılır
	var tr_ := sxx + syy
	var disc := sqrt(maxf(pow((sxx - syy) * 0.5, 2) + sxy * sxy, 0.0))
	var l1 := tr_ * 0.5 + disc
	var l2 := maxf(tr_ * 0.5 - disc, 1e-6)
	var elong := clampf((sqrt(l1 / l2) - 1.3) / 1.5, 0.0, 1.0)
	ang = clampf(wrapf(ang, -PI / 2, PI / 2) * elong, -MAX_ANGLE, MAX_ANGLE)
	var axis := Vector2(cos(ang), sin(ang))
	var normal := Vector2(-axis.y, axis.x)

	# eksen boyunca yayılım (uç değerlere dayanıklı) ve kalınlık
	var ts: Array = []
	var s_var := 0.0
	for p in comp:
		var d := p.center - mean
		ts.append([d.dot(axis), p.area_km2])
		s_var += pow(d.dot(normal), 2) * p.area_km2
	var kpp := World.km_per_px_at(mean)
	var thickness := 2.0 * sqrt(s_var / total) + sqrt(total / comp.size()) / kpp
	ts.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var t_lo := _weighted_quantile(ts, total, 0.04)
	var t_hi := _weighted_quantile(ts, total, 0.96)
	# tek bölgeli ülkeler için minimum uzunluk: bölge çapı
	var min_len := sqrt(total) / kpp
	if t_hi - t_lo < min_len:
		var mid := (t_hi + t_lo) * 0.5
		t_lo = mid - min_len * 0.5
		t_hi = mid + min_len * 0.5

	# eğri: s = a t² + b t + c (ağırlıklı en küçük kareler)
	var coef := _fit_quadratic(comp, mean, axis, normal, total)

	var text := _upper(c.map_name())
	var n := text.length()
	var length := (t_hi - t_lo) * 0.78
	var size_by_len := length / (n * (0.72 + LETTER_SPACING))
	var size := minf(minf(size_by_len, thickness * 0.48), MAX_FONT)
	if size < 6.0:
		return null
	var lbl := Label2D.new()
	lbl.font_size = int(size)

	var widths := PackedFloat32Array()
	var total_w := 0.0
	for i in n:
		var w := _font.get_char_size(text.unicode_at(i), lbl.font_size).x
		widths.append(w)
		total_w += w + (size * LETTER_SPACING if i < n - 1 else 0.0)
	var t := (t_lo + t_hi) * 0.5 - total_w * 0.5
	for i in n:
		var tc := t + widths[i] * 0.5
		var s := coef.x * tc * tc + coef.y * tc + coef.z
		var slope := 2.0 * coef.x * tc + coef.y
		lbl.glyphs.append(text[i])
		lbl.positions.append(mean + axis * tc + normal * s)
		lbl.angles.append(ang + atan(slope))
		lbl.widths.append(widths[i])
		t += widths[i] + size * LETTER_SPACING
	return lbl

func _weighted_quantile(sorted_ts: Array, total: float, q: float) -> float:
	var acc := 0.0
	for e: Array in sorted_ts:
		acc += e[1]
		if acc >= total * q:
			return e[0]
	return sorted_ts[-1][0]

func _fit_quadratic(comp: Array[Province], mean: Vector2, axis: Vector2, normal: Vector2, total: float) -> Vector3:
	# normal denklemler (3x3)
	var m := [[0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0]]
	var r := [0.0, 0.0, 0.0]
	for p in comp:
		var d := p.center - mean
		var t := d.dot(axis)
		var s := d.dot(normal)
		var w := p.area_km2 / total
		var basis := [t * t, t, 1.0]
		for i in 3:
			r[i] += w * basis[i] * s
			for j in 3:
				m[i][j] += w * basis[i] * basis[j]
	var sol := _solve3(m, r)
	if sol == Vector3.INF:
		return Vector3.ZERO
	# aşırı kavisi sınırla (yazı okunur kalsın)
	var span := sqrt(maxf(m[1][1], 1.0)) * 2.0
	var max_a := 0.35 / maxf(span, 1.0)
	sol.x = clampf(sol.x, -max_a, max_a)
	sol.y = clampf(sol.y, -0.4, 0.4)
	return sol

func _solve3(m: Array, r: Array) -> Vector3:
	var a := Basis(Vector3(m[0][0], m[1][0], m[2][0]), Vector3(m[0][1], m[1][1], m[2][1]), Vector3(m[0][2], m[1][2], m[2][2]))
	if absf(a.determinant()) < 1e-9:
		return Vector3.INF
	return a.inverse() * Vector3(r[0], r[1], r[2])

static func _upper(s: String) -> String:
	# Türkçe büyük harf: i -> İ, ı -> I
	if TranslationServer.get_locale().begins_with("tr"):
		s = s.replace("i", "İ").replace("ı", "I")
	return s.to_upper()

# ------------------------------------------------------------------ çizim
func _draw() -> void:
	var zoom := maxf(_last_zoom, 1e-4)
	for lbl in _labels:
		var screen_px := lbl.font_size * zoom
		var a := smoothstep(FADE_MIN_PX, FADE_MIN_PX * 1.6, screen_px) * (1.0 - smoothstep(FADE_MAX_PX * 0.6, FADE_MAX_PX, screen_px))
		if a <= 0.01:
			continue
		var fill := Color(TEXT_COLOR, TEXT_COLOR.a * a)
		var outline := Color(OUTLINE_COLOR, OUTLINE_COLOR.a * a)
		var outline_size := maxi(3, int(lbl.font_size * 0.12))
		var baseline := _font.get_ascent(lbl.font_size) * 0.35
		for i in lbl.glyphs.size():
			draw_set_transform(lbl.positions[i], lbl.angles[i], Vector2.ONE)
			var off := Vector2(-lbl.widths[i] * 0.5, baseline)
			draw_char_outline(_font, off, lbl.glyphs[i], lbl.font_size, outline_size, outline)
			draw_char(_font, off, lbl.glyphs[i], lbl.font_size, fill)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	redrawn.emit()
