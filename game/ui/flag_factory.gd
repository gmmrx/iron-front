class_name FlagFactory
extends RefCounted
## countries.json'daki bayrak tanımından doku üretir (şerit + amblem).
## Faz 1'de gerçek SVG bayraklarla değiştirilecek.

const W := 90
const H := 60
const SS := 3  ## süper örnekleme (kenar yumuşatma)

static var _cache: Dictionary = {}

static func get_flag(c: Country) -> Texture2D:
	if c == null:
		return null
	if not _cache.has(c.tag):
		var svg := "res://assets/flags/%s.svg" % c.tag
		if ResourceLoader.exists(svg):
			_cache[c.tag] = load(svg)          # tarihi bayrak (Wikimedia Commons)
		else:
			_cache[c.tag] = ImageTexture.create_from_image(_render(c))
	return _cache[c.tag]

static func _render(c: Country) -> Image:
	var w := W * SS
	var h := H * SS
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var def: Dictionary = c.flag_def
	var cols: Array = def.get("colors", [c.color.to_html()])
	var n := cols.size()
	for i in n:
		var col := Color(cols[i])
		if def.get("dir", "h") == "h":
			img.fill_rect(Rect2i(0, i * h / n, w, (i + 1) * h / n - i * h / n), col)
		else:
			img.fill_rect(Rect2i(i * w / n, 0, (i + 1) * w / n - i * w / n, h), col)
	var em: Dictionary = def.get("emblem", {})
	if not em.is_empty():
		_emblem(img, em)
	img.resize(W, H, Image.INTERPOLATE_LANCZOS)
	return img

static func _star(center: Vector2, r_out: float, r_in: float, rot: float = -PI / 2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var r := r_out if i % 2 == 0 else r_in
		var a := rot + i * PI / 5.0
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts

static func _fill_poly(img: Image, poly: PackedVector2Array, col: Color) -> void:
	var box := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		box = box.expand(p)
	for y in range(int(box.position.y), int(box.end.y) + 1):
		for x in range(int(box.position.x), int(box.end.x) + 1):
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
				if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), poly):
					img.set_pixel(x, y, col)

static func _emblem(img: Image, em: Dictionary) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var col := Color(em.get("color", "#ffffff"))
	match em.get("type", ""):
		"nordic":
			var t := h / 5
			img.fill_rect(Rect2i(int(w * 0.30), 0, t, h), col)
			img.fill_rect(Rect2i(0, h / 2 - t / 2, w, t), col)
			if em.has("inner"):
				var t2 := t / 2
				var ic := Color(em["inner"])
				img.fill_rect(Rect2i(int(w * 0.30) + t / 4, 0, t2, h), ic)
				img.fill_rect(Rect2i(0, h / 2 - t2 / 2, w, t2), ic)
		"swiss":
			var s := h / 5
			img.fill_rect(Rect2i(w / 2 - s / 2, h / 2 - int(s * 1.6), s, int(s * 3.2)), col)
			img.fill_rect(Rect2i(w / 2 - int(s * 1.6), h / 2 - s / 2, int(s * 3.2), s), col)
		"crescent":
			var c1 := Vector2(w * 0.36, h * 0.5)
			var c2 := Vector2(w * 0.40, h * 0.5)
			var r1 := h * 0.25
			var r2 := h * 0.20
			for y in h:
				for x in w:
					var p := Vector2(x + 0.5, y + 0.5)
					if p.distance_to(c1) < r1 and p.distance_to(c2) >= r2:
						img.set_pixel(x, y, col)
			_fill_poly(img, _star(Vector2(w * 0.515, h * 0.5), h * 0.125, h * 0.05, PI), col)
		"canton_star":
			if em.has("bg"):
				img.fill_rect(Rect2i(0, 0, int(w * 0.33), h / 2), Color(em["bg"]))
				_fill_poly(img, _star(Vector2(w * 0.165, h * 0.25), h * 0.13, h * 0.05), col)
			else:
				_fill_poly(img, _star(Vector2(w * 0.17, h * 0.2), h * 0.09, h * 0.037), col)
		"canton_stars":
			# ABD: şeritlerin üstünde lacivert kanton, yıldız ızgarası
			var cw := int(w * 0.4)
			var ch := int(h * 7 / 13)
			img.fill_rect(Rect2i(0, 0, cw, ch), Color(em.get("bg", "#3c3b6e")))
			for row in 5:
				for k in 6:
					var cx := (k + 0.5 + (0.5 if row % 2 else 0.0)) * cw / 6.5
					var cy := (row + 0.5) * ch / 5.0
					_fill_poly(img, _star(Vector2(cx, cy), ch * 0.075, ch * 0.03), col)
		"canton_union":
			# dominyon bayrağı: sol üst çeyrekte Union Jack; stars: sağda Güney Haçı
			var sub := Image.create(w / 2, h / 2, false, Image.FORMAT_RGBA8)
			sub.fill(Color("#012169"))
			_emblem(sub, {"type": "union"})
			img.blit_rect(sub, Rect2i(0, 0, w / 2, h / 2), Vector2i.ZERO)
			if em.get("stars", false):
				var sc := Color(em.get("color", "#ffffff"))
				for pt: Vector2 in [Vector2(0.75, 0.2), Vector2(0.62, 0.48), Vector2(0.88, 0.42), Vector2(0.75, 0.78), Vector2(0.25, 0.75)]:
					_fill_poly(img, _star(Vector2(w * pt.x, h * pt.y), h * 0.07, h * 0.03), sc)
		"triangle":
			var tri := PackedVector2Array([Vector2(0, 0), Vector2(w * 0.45, h * 0.5), Vector2(0, h)])
			_fill_poly(img, tri, col)
			if em.has("star"):
				_fill_poly(img, _star(Vector2(w * 0.15, h * 0.5), h * 0.1, h * 0.04), Color(em["star"]))
		"canton_sun":
			# Çin Cumhuriyeti: lacivert kanton, beyaz güneş (ışınlı disk)
			var cw2 := w / 2
			var ch2 := h / 2
			img.fill_rect(Rect2i(0, 0, cw2, ch2), Color(em.get("bg", "#000095")))
			var c := Vector2(cw2 * 0.5, ch2 * 0.5)
			var rays := PackedVector2Array()
			for i in 24:
				var a := i * PI / 12.0
				rays.append(c + Vector2(cos(a), sin(a)) * (ch2 * (0.42 if i % 2 == 0 else 0.26)))
			_fill_poly(img, rays, col)
			for y in ch2:
				for x in cw2:
					var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
					if d < ch2 * 0.2:
						img.set_pixel(x, y, Color(em.get("bg", "#000095")) if d > ch2 * 0.17 else col)
		"canton_bars":
			# Mançukuo: sol üstte dört renkli yatay şerit
			var cols2: Array = em.get("colors", [])
			var cw3 := int(w * 0.33)
			var ch3 := h / 3
			for i in cols2.size():
				img.fill_rect(Rect2i(0, i * ch3 / cols2.size(), cw3, ch3 / cols2.size() + 1), Color(cols2[i]))
		"canton_cross":
			var cw := int(w * 0.37)
			var ch := h * 5 / 9
			img.fill_rect(Rect2i(0, 0, cw, ch), Color(em.get("bg", "#0d5eaf")))
			var t := ch / 5
			img.fill_rect(Rect2i(cw / 2 - t / 2, 0, t, ch), col)
			img.fill_rect(Rect2i(0, ch / 2 - t / 2, cw, t), col)
		"center_disc":
			var c := Vector2(w * 0.5, h * 0.5)
			for y in h:
				for x in w:
					if Vector2(x + 0.5, y + 0.5).distance_to(c) < h * 0.26:
						img.set_pixel(x, y, col)
		"bar":
			img.fill_rect(Rect2i(int(w * 0.2), int(h * 0.62), int(w * 0.6), h / 14), col)
		"union":
			var white := Color("#ffffff")
			var red := Color("#c8102e")
			var d := Vector2(w, h).normalized()
			for y in h:
				for x in w:
					var p := Vector2(x + 0.5, y + 0.5)
					var d1 := absf(p.x * d.y - p.y * d.x)
					var d2 := absf((w - p.x) * d.y - p.y * d.x)
					var dm := minf(d1, d2)
					if dm < h * 0.1:
						img.set_pixel(x, y, white)
					if dm < h * 0.035:
						img.set_pixel(x, y, red)
			img.fill_rect(Rect2i(w / 2 - h / 6, 0, h / 3, h), white)
			img.fill_rect(Rect2i(0, h / 2 - h / 6, w, h / 3), white)
			img.fill_rect(Rect2i(w / 2 - h / 10, 0, h / 5, h), red)
			img.fill_rect(Rect2i(0, h / 2 - h / 10, w, h / 5), red)
