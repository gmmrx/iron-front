class_name BattleIcons
extends Node3D
## Uzak zoom'da muharebe işaretleri (türün klasiklerindeki gibi): çatışan sınırın ortasında çapraz kılıç plakası ve
## altında iki tarafın organizasyon dengesi çubuğu. Oyuncu saldırıyorsa yeşil, savunuyorsa kırmızı çerçeve.

const PIXEL := 0.00042
const SHOW_FROM := 520.0              ## bu kamera uzaklığından itibaren (figürler seçilemez olunca) görünür
const WORLD_HIDE := 7000.0            ## dünya görünümünde yalnız oyuncunun muharebeleri

var map: MapView3D
var camera: MapCamera3D
var _icons := {}                      ## pid -> {root, plate, bar, key}
var _plates := {}
var _bars := {}
var _swords: Texture2D
var _t := 0.0

func _ready() -> void:
	_swords = UiTheme.icon("battle")

func _process(delta: float) -> void:
	_t += delta
	var show := World.in_game and camera.distance >= SHOW_FROM
	visible = show
	if not show:
		return
	var me := World.player_tag
	var alive := {}
	for pid: int in Military.battles:
		var b: Dictionary = Military.battles[pid]
		var atk: Array = b["attackers"]
		var dfn: Array = b["defenders"]
		if atk.is_empty() or dfn.is_empty():
			continue
		var a_tag: String = (atk[0] as Division).owner
		var d_tag: String = (dfn[0] as Division).owner
		var side := 0                        # 1 oyuncu saldırıyor, -1 savunuyor, 0 başkaları
		if a_tag == me or Diplomacy.are_allies(a_tag, me):
			side = 1
		elif d_tag == me or Diplomacy.are_allies(d_tag, me):
			side = -1
		if camera.distance > WORLD_HIDE and side == 0:
			continue
		alive[pid] = true
		var ic: Dictionary = _icons.get(pid, {})
		if ic.is_empty():
			ic = _make()
			_icons[pid] = ic
		var from := World.province(int(b.get("from", pid))).center
		var to := World.province(pid).center
		var mid := from.lerp(World.unwrap_near(from, to), 0.5)
		var root: Node3D = ic["root"]
		root.position = Vector3(mid.x, maxf(map.height_at(mid), 0.0) + 8.0, mid.y)
		var ar: float = b.get("att_ratio", 0.5)
		var dr: float = b.get("def_ratio", 0.5)
		var share := ar / maxf(ar + dr, 0.001)
		var bucket := roundi(share * 20.0)
		var key := "%d:%d" % [side, bucket]
		if ic["key"] != key:
			ic["key"] = key
			(ic["plate"] as Sprite3D).texture = _plate(side)
			(ic["bar"] as Sprite3D).texture = _bar(bucket, side)
		# oyuncunun muharebeleri hafifçe nabız atar
		var k := 1.0 + (0.08 * sin(_t * 5.0) if side != 0 else 0.0)
		root.scale = Vector3.ONE * k * (1.0 if side != 0 else 0.8)
	for pid: int in _icons.keys():
		if not alive.has(pid):
			(_icons[pid]["root"] as Node3D).queue_free()
			_icons.erase(pid)

func _make() -> Dictionary:
	var root := Node3D.new()
	add_child(root)
	var plate := Sprite3D.new()
	plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	plate.fixed_size = true
	plate.pixel_size = PIXEL * 1.05
	plate.no_depth_test = true
	plate.render_priority = 30
	plate.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	root.add_child(plate)
	var icon := Sprite3D.new()
	icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	icon.fixed_size = true
	icon.pixel_size = PIXEL * 0.7
	icon.no_depth_test = true
	icon.render_priority = 31
	icon.texture = _swords
	icon.modulate = Color(1.0, 0.93, 0.78)
	icon.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	root.add_child(icon)
	var bar := Sprite3D.new()
	bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bar.fixed_size = true
	bar.pixel_size = PIXEL * 0.9
	bar.no_depth_test = true
	bar.render_priority = 31
	bar.offset = Vector2(0, -52)
	root.add_child(bar)
	return {"root": root, "plate": plate, "bar": bar, "key": ""}

## Yuvarlak koyu plaka, tarafa göre renkli halka
func _plate(side: int) -> Texture2D:
	if _plates.has(side):
		return _plates[side]
	var n := 72
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var ring := Color(0.45, 0.9, 0.4) if side == 1 else (Color(0.95, 0.3, 0.25) if side == -1 else Color(0.75, 0.72, 0.65))
	var c := Vector2(n, n) * 0.5
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			var col := Color(0, 0, 0, 0)
			if d < n * 0.5 - 1.0:
				col = Color(0.07, 0.07, 0.08, 0.92)
				if d > n * 0.5 - 7.0:
					col = ring
			elif d < n * 0.5:
				col = Color(ring.r, ring.g, ring.b, n * 0.5 - d)
			img.set_pixel(x, y, col)
	var tex := ImageTexture.create_from_image(img)
	_plates[side] = tex
	return tex

## Denge çubuğu: sol saldıran (oyuncuysa yeşil), sağ savunan
func _bar(bucket: int, side: int) -> Texture2D:
	var key := "%d:%d" % [bucket, side]
	if _bars.has(key):
		return _bars[key]
	var w := 76
	var h := 12
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.05, 0.05, 0.06, 0.95))
	var ca := Color(0.45, 0.85, 0.35) if side == 1 else Color(0.9, 0.3, 0.25) if side == -1 else Color(0.85, 0.8, 0.7)
	var cd := Color(0.9, 0.3, 0.25) if side == 1 else Color(0.45, 0.85, 0.35) if side == -1 else Color(0.5, 0.48, 0.44)
	var split := 2 + int((w - 4) * bucket / 20.0)
	img.fill_rect(Rect2i(2, 2, split - 2, h - 4), ca)
	img.fill_rect(Rect2i(split, 2, w - 2 - split, h - 4), cd)
	var tex := ImageTexture.create_from_image(img)
	_bars[key] = tex
	return tex
