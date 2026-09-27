class_name BattleTicker
extends Node3D
## Muharebe durum okları: süren bir muharebede taraflardan birinin durumu düzeldikçe onun yanında küçük yeşil ▲,
## kötüleştikçe kırmızı ▼ belirir, yukarı kayarak söner. Saldıranın oku saldırının geldiği yanda, savunanınki muharebe
## bölgesinde durur. Durum: iki tarafın organizasyon payı (Military.battles att_ratio / def_ratio); gerçek zamanda en
## çok saniyede bir bakılır (5× hızda ok yağmasın). Yalnız görüş alanındaki muharebeler; oyun mantığına dokunmaz.

const PIXEL := 0.00042
const ARROW_PX := 22.0              ## okun ekran boyu (1080p)
const LIFE := 1.3                   ## okun ömrü (sn)
const RISE_PX := 22.0               ## ömrü boyunca yukarı kayma (ekran pikseli)
const SAMPLE := 1.0                 ## bir muharebeye en çok bu sıklıkla bakılır (gerçek sn)
const MIN_CHANGE := 0.01            ## pay en az bu kadar değişmeli (yüzde 1)
const MAX_DIST := 2400.0            ## kamera bundan uzaktaysa ok yok (dünya görünümü dolmasın)
const PX := 1766.0                  ## sabit boy sprite: doku pikseli * pixel_size * PX = ekran pikseli

var map: MapView3D
var camera: MapCamera3D
var _up: Texture2D
var _down: Texture2D
var _last := {}                     ## pid -> [saldıranın payı, son bakış (sn)]
var _live: Array = []               ## [Sprite3D, yaş]
var _free: Array[Sprite3D] = []
var _t := 0.0

func _ready() -> void:
	_up = _arrow(true)
	_down = _arrow(false)

func _process(delta: float) -> void:
	_t += delta
	_age(delta)
	if not World.in_game or GameClock.paused or camera == null or camera.distance > MAX_DIST:
		return
	var r := camera.distance * 1.6
	var view := Rect2(Vector2(camera.target.x, camera.target.z) - Vector2(r, r), Vector2(r * 2.0, r * 1.8))
	for pid: int in _last.keys():
		if not Military.battles.has(pid):
			_last.erase(pid)
	for pid: int in Military.battles:
		var b: Dictionary = Military.battles[pid]
		var to := World.province(pid).center
		if not view.has_point(to):
			continue
		var ar: float = b.get("att_ratio", 0.5)
		var dr: float = b.get("def_ratio", 0.5)
		var share := ar / maxf(ar + dr, 0.001)
		var prev: Array = _last.get(pid, [])
		if prev.is_empty():
			_last[pid] = [share, _t]
			continue
		if _t - float(prev[1]) < SAMPLE:
			continue
		var change := share - float(prev[0])
		_last[pid] = [share, _t]
		if absf(change) < MIN_CHANGE:
			continue
		var from := World.unwrap_near(to, World.province(int(b.get("from", pid))).center)
		_spawn(from.lerp(to, 0.25), change > 0.0)       # saldıran
		_spawn(from.lerp(to, 0.85), change < 0.0)       # savunan

## Bir ok: yükselen (yeşil ▲) ya da düşen (kırmızı ▼)
func _spawn(p: Vector2, good: bool) -> void:
	var s: Sprite3D
	if _free.is_empty():
		s = Sprite3D.new()
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s.fixed_size = true
		s.no_depth_test = true
		s.render_priority = 32
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		add_child(s)
	else:
		s = _free.pop_back()
	s.texture = _up if good else _down
	s.pixel_size = ARROW_PX / (float(s.texture.get_height()) * PX)
	s.position = Vector3(p.x, maxf(map.height_at(p), 0.0) + 3.0, p.y)
	s.offset = Vector2.ZERO
	s.modulate = Color(1, 1, 1, 1)
	s.visible = true
	_live.append([s, 0.0])

## Oklar yukarı kayar, son yarısında söner
func _age(delta: float) -> void:
	var i := 0
	while i < _live.size():
		var e: Array = _live[i]
		var s: Sprite3D = e[0]
		var age: float = float(e[1]) + delta
		e[1] = age
		if age >= LIFE:
			s.visible = false
			_free.append(s)
			_live.remove_at(i)
			continue
		var k := age / LIFE
		s.offset = Vector2(0.0, RISE_PX * k) / (s.pixel_size * PX)
		s.modulate.a = 1.0 - smoothstep(0.45, 1.0, k)
		i += 1

## Küçük üçgen ok dokusu: koyu kenarlı yeşil yukarı / kırmızı aşağı
func _arrow(up: bool) -> Texture2D:
	var n := 40
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var fill := Color(0.45, 0.9, 0.35) if up else Color(0.95, 0.3, 0.22)
	var edge := Color(0.04, 0.05, 0.04, 1.0)
	for y in n:
		for x in n:
			# üçgen: tepe (yukarı okta üstte), taban altta; işaretli uzaklık yaklaşık kenar kalınlığı için
			var v := (float(y) + 0.5) / n
			if not up:
				v = 1.0 - v
			var half := v * 0.5                  # tepeden tabana genişlik
			var dx := absf((float(x) + 0.5) / n - 0.5)
			var inside := v > 0.06 and v < 0.94 and dx < half * 0.92
			if not inside:
				continue
			var border := v < 0.14 or v > 0.86 or dx > half * 0.92 - 0.07
			img.set_pixel(x, y, edge if border else fill)
	return ImageTexture.create_from_image(img)
