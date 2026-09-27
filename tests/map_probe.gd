extends RefCounted
## Harita pikseli → bölge kimliği (data/map/provinces.png, LA8: L + A·256; MapView3D.province_at ile aynı çözümleme).
## Görüntü (16384×8106) süreç başına bir kez yüklenir; testler arası paylaşılır.

static var image: Image
static var _data: PackedByteArray
static var _w := 0
static var _h := 0

static func ensure() -> void:
	if _w > 0:
		return
	image = Image.load_from_file("res://data/map/provinces.png")
	if image.get_format() != Image.FORMAT_LA8:
		image.convert(Image.FORMAT_LA8)
	_w = image.get_width()
	_h = image.get_height()
	_data = image.get_data()

static func province_at(p: Vector2) -> int:
	ensure()
	var x := posmod(floori(p.x), _w)
	var y := clampi(floori(p.y), 0, _h - 1)
	var i := (y * _w + x) * 2
	return _data[i] + _data[i + 1] * 256

## Deniz bölgesi pikseli mi (göl ve kara değil)
static func is_sea(p: Vector2) -> bool:
	var q := World.province(province_at(p))
	return q != null and q.type == Province.Type.SEA

## Su (deniz ya da göl) pikseli mi — FleetLayer.is_water ile aynı ölçüt
static func is_water(p: Vector2) -> bool:
	var q := World.province(province_at(p))
	return q != null and not q.is_land()

## a → b doğrusu boyunca yarım pikselden sık örneklerin ilk karadaki noktası (yoksa Vector2.INF)
static func first_land(a: Vector2, b: Vector2) -> Vector2:
	var n := int(maxf(absf(b.x - a.x), absf(b.y - a.y)) * 2.0) + 2
	for k in n:
		var p := a.lerp(b, float(k) / float(n - 1))
		if not is_sea(p):
			return p
	return Vector2.INF
