class_name UnitLayer
extends Node3D
## Tümen sayaçları (bölge + ülke + ordu başına bir sayaç: aynı bölgedeki ayrı ordular yan yana ayrı iğnelerde), seçim,
## hareket okları ve muharebe işaretleri. Oyuncunun ordularının sayacı altında ordunun adı yazar.

const PIXEL := 0.00042
const FLAG_MODE := 1250.0          ## bu mesafeden uzakta sayı yerine küçük ülke bayrağı (her ülke için)
const HIDE_ALL := 2100.0           ## bu mesafeden uzakta hiç işaret yok: kıta görünümü sade, kare hızı korunur
const LIFT := 5.0
const NAME_DIST := 520.0           ## ordu/tümen adı bu mesafenin içinde yazar
const PORTRAIT_PX := 40.0          ## ordu komutanının portresi (ekran pikseli, 1080p), ordunun ana sayacının üstünde
const PX := 1766.0                 ## sabit boy sprite: doku pikseli * pixel_size * PX = ekran pikseli (34° görüş, 1080p)
const COUNTER_W := 216.0          ## birlik levhası dokusu (piksel, ekranın ~2 katı): bayrak şeridi, resim, işaret
const COUNTER_H := 100.0
const CARD_PX := 0.00028           ## levhanın piksel boyu (216 px doku ≈ 107 ekran pikseli, 1080p)
const CARD_LIFT := 0.012           ## kart haritanın hemen üstünde (iğne yok), kamera uzaklığının katı
const CARD_DIST := 230.0           ## bu uzaklığın dışında kart yerine "bayrak | sayı" rozeti (iğnesiz); içinde 3D figür
								   ## (ya da iğneli kart): 3D yalnız çok yakın zoom'da
const CHIP_STACK := Vector2(0.011, -0.008)  ## aynı noktadaki rozetler üst üste: her biri bir öncekinin sağ üstüne biner
										   ## (kamera uzaklığının katı, ekranda ~14 × 10 px), yan yana yayılmaz
const COMPOSE_DIST := 105.0        ## çok yakında kart dağılır: içindeki tabur türleri aynı boy kartlarla (ızgara)
const COMPOSE_COLS := 2
const CHIP_W := 64.0               ## "bayrak | sayı" rozeti dokusu (piksel)
const CHIP_H := 30.0
const CHIP_PX := 0.00042
## filo ve hava rozeti ("gemi | sayı", "uçak | sayı"): tümen rozetiyle aynı boy; yalnız biraz daha geniş (resmin iki
## yanında ve 2-3 haneli sayıda boşluk)
const CHIP_GW := 78.0
const CHIP_GFW := 40                ## resim bölmesinin genişliği (piksel)
const CHIP_GPX := CHIP_PX
## filo ve hava levhası (yakın zoom): tümen levhasıyla aynı boy
const GLYPH_PLATE_K := 1.0
## Birlik türleri (tabur): kart resmi assets/ui/unit_cards/card_<tür>.png (docs/art/UNIT_CARD_PROMPTS.md); yoksa
## teçhizat ikonundan fildişi siluet
const CARD_TYPES := ["infantry", "motorized", "light_armor", "medium_armor", "artillery", "anti_tank"]
const CARD_FALLBACK := {"infantry": "equipment_infantry_equipment", "motorized": "equipment_motorized_equipment",
	"light_armor": "equipment_light_tank_equipment", "medium_armor": "equipment_medium_tank_equipment",
	"artillery": "equipment_artillery_equipment", "anti_tank": "equipment_anti_tank_equipment",
	"ship": "equipment_destroyer", "submarine": "equipment_submarine", "plane": "equipment_fighter_equipment"}
const CARD_IVORY := Color(0.93, 0.89, 0.78)
const NAME_COLOR := Color("c8ad72")          ## birlik adı (levhanın altındaki kutuda): sönük pirinç, orta kalınlık
static var _glyph_img := {}
## Yakında tümen levhası yerine kaideli asker / tank figürü (UnitFigures; tarayıcıda da: figürün dokusu artık ekran
## kartından geri okunmuyor). false: levha.
static var FIGURES: bool = true
const FIG_SIZE := 10.0             ## figürün haritadaki boyu (dünya birimi; ~12 km): gerçek minyatür gibi sabit, zoom'la yeri de
								   ## boyu da değişmez (yakında büyük, uzaklaştıkça küçük görünür)
const FIG_GAP := 1.06              ## çarpışma: iki figürün kaideleri arasında en az bu kat (değmesinler)
const FIG_AHEAD := 2.6             ## yürüyen figür önündekine kaide boyunun bu katı kala yana açılmaya başlar (yavaş yürüyüşte
								   ## de karşılaşmadan önce açılmış olur)
const FIG_TILT := 0.3              ## yamaçta kaidenin en çok eğimi (tanjant, ~17°): dik yamaçta figür devrilmez, üstünde durur
const FIG_DEPTH := 1.15            ## kuzey-güney komşuda gereken aralık figür boyunun bu katı (kamera güneyden eğik bakar: arkadaki
								   ## figürün kaidesi öndekinin başının ardında kalmasın); dizilişte arka sıranın derinliği de bu
const FIG_CELL_GAP := 12.0         ## dizilişte kaideler arasındaki boşluk (sanal piksel; FIG_FS ile harita birimine): değmesinler
const FIG_TURN := 4.0              ## askerin dönme hızı (radyan / gerçek saniye): yürüdüğü ya da ateş ettiği yöne döner, sıçramaz
const FIG_STEP := 2.0              ## dizilme adımı (dünya birimi / gerçek saniye): duran figür yeni yerine yürür, kaymaz
const FIG_YIELD := 1.0             ## yol verme adımı en az bu (yürüyen için yürüme hızının 2 katı): yan kayma yürüyüşü bastırmasın
const FIG_LAYOUT_R := 700.0        ## yığın düzeni kamera hedefinin bu kadar çevresinde kurulur (en uzak yakın görüşten geniş)
const FIG_FS := 100.0 / FIG_SIZE   ## yığın düzeninde harita biriminin sanal pikseli (figür boyu 100 sanal piksel)
const GLIDE_SPEED := 18.0          ## sayacın yeni yerine kayma hızı (harita birimi / gerçek saniye, en az)
const HOP_SPEED := 16.0            ## figürün bir bölgeden komşusuna yürüyüşü (harita birimi / gerçek sn: ~2-3 sn)
const GLIDE_SNAP := 90.0
const MOVE_GAP := 1.1                 ## aynı bölgeden aynı sıradaki bölgeye yürüyenler tek figür (bacakta ilerleme farkı ne olursa olsun)
const GLOW_M := 10                 ## muharebe parlamasının levhanın dışına taşması (doku pikseli; ekranda ~5 px)
const GLOW_GOOD := Color(0.42, 0.9, 0.36)
const GLOW_BAD := Color(0.95, 0.3, 0.22)
const DIE_TIME := 2.6              ## yok olan sayaç siyah-beyaz durur, son saniyede yavaşça söner
const COMMANDER_BODY_SHIFT := 24.0 ## portre takılıyken plakayı sağa al; tüm işaret iğneye göre ortalı kalır

var map: MapView3D
var camera: Camera3D
var models: UnitModels                 ## akıcı görsel konumlar (sayaçlar ve oklar)
var combat_effects: CombatEffects       ## kara/hava için ortak, bütçeli savaş efektleri
var selected: Array[Division] = []

var _counters := {}                ## "pid:tag" -> {root, label, org, str, divs}
var _counter_tex := {}             ## tag -> Texture2D
static var _flag_tex := {}         ## "tag:seçili" -> çerçeveli küçük bayrak
var _battle_nodes := {}            ## pid -> Node3D
var _arrows: MeshInstance3D
var _arrow_mat: ShaderMaterial
var _white: Texture2D
var _dirty := true
var _timer := 0.0
var _was_far := -1
var _pulse := 0.0
var _sel_keys: Array[String] = []
var _vis_dirty := true
var _cluster_timer := 0.0
var _names_close := true
var _compose := false                  ## kartların altında içindeki birlik türleri (COMPOSE_DIST içinde)
var _portrait_map := {}            ## "TAG|Ad" -> resim yolu (data/common/commander_portraits.json)
var _portrait_loaded := false
var _pframe: Texture2D
var _ptex := {}                    ## komutan id -> küçük kare portre (ya da null: resmi yok)
var _div_key := {}                 ## tümen id -> sayacının anahtarı (_rebuild)
var obstacles: Array = []          ## iğneli levhası olan öbür katmanlar (filo, hava): pin_roots() — tümenler bunlara binmez
var _combat := {}                  ## muharebedeki tümen id -> 1 üstün geliyor / -1 geriliyor
var _combat_dir := {}              ## muharebedeki tümen id -> düşmana doğru (harita düzleminde; ateş çakmaları o yanda)
static var _flash_tex: Texture2D
var _glowing: Array[String] = []   ## çevresi yanan sayaçlar (muharebede)
var _anim_t := 0.0
var _epoch_seen := -1              ## UnitModels.static_epoch'un son görülen değeri
var _dying: Array = []             ## [kök, yaş]: yok olan tümenin sayacı önce renksizleşir, iki kez yanıp söner, silinir
static var _glow_tex: Texture2D

func _ready() -> void:
	_combat_rng.randomize()                  # kozmetik atışlar oyun simülasyonunun rastgele akışını tüketmez
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_white = ImageTexture.create_from_image(img)
	_arrows = MeshInstance3D.new()
	_arrow_mat = ShaderMaterial.new()
	_arrow_mat.shader = preload("res://assets/shaders/arrow.gdshader")
	UnitModels.compat_material(_arrow_mat)
	_arrow_mat.render_priority = 8
	_arrows.material_override = _arrow_mat
	_arrows.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_arrows)
	Military.divisions_changed.connect(func() -> void: _dirty = true)
	GameClock.hour_passed.connect(func() -> void:
		_dirty = true                          # yürüme/saldırı başladı ya da bitti (sayaç anahtarı)
		_reseat())                             # muharebe ve sınırda karşılaşmalar saat saat değişir: duranlar sınıra yürür
	Military.armies_changed.connect(func() -> void:                     # ordu kuruldu / katıldı / ayrıldı
		_dirty = true
		_full_refresh = true)
	Military.battles_changed.connect(func() -> void:
		_update_battles()
		_reseat())
	World.player_changed.connect(func(_t: String) -> void: clear_selection())

func _process(delta: float) -> void:
	_timer += delta
	# yeniden kurulum aralığı oyun hızıyla uzar (5×'te ~1 sn): savaşta her 0,35 sn'de bütün sayaçları kurmak pahalı
	if _dirty and _timer > 0.35 * maxf(1.0, float(GameClock.speed) - 2.0):
		_timer = 0.0
		_dirty = false
		var __r := Time.get_ticks_usec()
		_rebuild()
		GameClock.timed("units_rebuild_core", __r)
		var __c2 := Time.get_ticks_usec()
		_cluster()
		GameClock.timed("units_rebuild_cluster", __c2)
		__c2 = Time.get_ticks_usec()
		_refresh_combat()
		GameClock.timed("units_rebuild_combat", __c2)
		GameClock.timed("units_rebuild", __r)
		_vis_dirty = true
		if _build_more:
			_dirty = true                      # kurulmayan sayaçlar bir sonraki karede (aralık beklenmez)
			_timer = 99.0
	var hide_all: bool = camera != null and camera.distance > HIDE_ALL
	var __tm := Time.get_ticks_usec()
	_tile_merge()
	GameClock.timed("units_tilemerge", __tm)
	if not hide_all:
		var __f := Time.get_ticks_usec()
		_follow_anchors(delta)
		GameClock.timed("units_follow", __f)
	_draw_arrows()
	var __cf := Time.get_ticks_usec()
	_animate_combat(delta)
	_combat_fx(delta)
	_animate_dying(delta)
	GameClock.timed("units_fx", __cf)
	_show_decks()
	_pulse += delta
	var k := 1.0 + 0.07 * sin(_pulse * 5.0)
	for d in selected.slice(0, 1):
		pass
	for key: String in _sel_keys:
		if _counters.has(key):
			_counters[key]["root"].scale = Vector3.ONE * k
	# 0 yakın: iğneli birlik kartı (çok yakında dağılmış); 1 orta/uzak: "bayrak | sayı" rozeti (iğnesiz, seçilebilir)
	var far := 0
	if camera:
		far = 2 if hide_all else (1 if camera.distance > CARD_DIST else 0)
	# ordu/tümen adları yalnız yakında (orta zoom'da haritayı doldurmasın)
	var names_close: bool = camera == null or (camera as MapCamera3D).distance < NAME_DIST
	if names_close != _names_close:
		_names_close = names_close
		_vis_dirty = true
	var compose: bool = camera != null and (camera as MapCamera3D).distance < COMPOSE_DIST
	if compose != _compose:
		_compose = compose
		_vis_dirty = true
	if far != _was_far or _vis_dirty:
		if FIGURES and (far == 0) != (_was_far == 0):
			# figür kipinde paylar dünya birimi, kartta/rozette kamera uzaklığının katı: kip değişince baştan
			for key: String in _counters:
				var cr: Dictionary = _counters[key]
				for f: String in ["dk", "dk_t", "hold", "hold_pid", "av", "fxz", "settled", "pos0"]:
					cr.erase(f)
		_was_far = far
		_vis_dirty = false
		for key: String in _counters:
			var c: Dictionary = _counters[key]
			c["base_vis"] = far < 2
			var subs: Array = c.get("subs", [])
			var show_comp: bool = far == 0 and _compose and not subs.is_empty() and not FIGURES
			var figure: bool = FIGURES and far == 0 and c.get("fig") != null
			c["bg"].visible = far == 0 and not show_comp and not figure
			c["label"].visible = far == 0 and not show_comp and not figure
			if c.get("fig") != null:
				(c["fig"] as Node3D).visible = figure
			c["flag"].visible = far == 1
			c["clabel"].visible = far == 1
			c["army"].visible = false
			_place_stars(c)
			for sub: Array in subs:
				(sub[0] as Node3D).visible = show_comp
				(sub[1] as Node3D).visible = show_comp
			# ad: kartın (dağılmışsa ızgaranın) altında
			var rows := (subs.size() + COMPOSE_COLS - 1) / COMPOSE_COLS if show_comp else 1
			var an_y := -_card_half().y - 10.0 - float(rows - 1) * (_card_half().y * 2.0 + 4.0)
			var an_x := float(c.get("cmd_shift", 0.0))
			if show_comp:
				an_x += float(mini(subs.size(), COMPOSE_COLS) - 1) * (_card_half().x * 2.0 + 4.0) * 0.5
			var anl: Label3D = c["army"]
			var ao := Vector2(an_x, an_y - 8.0) / (PIXEL * 0.8 * PX)
			if anl.offset != ao:
				anl.offset = ao
				var ap: Sprite3D = anl.get_node_or_null("plate")
				if ap:
					ap.offset = anl.offset
			if c.has("pnode"):
				c["pnode"].visible = far == 0 and _names_close and int(c.get("pcm", 0)) != 0
			c["root"].visible = c["base_vis"] and not c.get("merged", false) and not c.get("deck_hidden", false) \
				and not c.get("tile_merged", false)
	_cluster_timer -= delta
	if _cluster_timer <= 0.0 and not hide_all:
		_cluster_timer = 0.25
		var __c := Time.get_ticks_usec()
		_cluster()
		_declutter()
		GameClock.timed("units_cluster", __c)

## Sayaçlar tümenlerin akıcı görsel konumunu izler (bölgede zıplamaz)
## Yalnız görüş alanındaki sayaçlar güncellenir (dışarıdakiler ekranda değil); yeri ve zoom'u değişmeyen sayaca
## dokunulmaz. Bütün sayaçları her karede yerleştirmek 5× hızda kare başına ~3 ms tutuyordu.
func _follow_anchors(delta := 1.0) -> void:
	if models == null:
		return
	var cam_d: float = (camera as MapCamera3D).distance if camera is MapCamera3D else 300.0
	var view := Rect2()
	var culled := camera is MapCamera3D
	if culled:
		var r := cam_d * 1.6
		var t: Vector3 = (camera as MapCamera3D).target
		view = Rect2(Vector2(t.x, t.z) - Vector2(r, r), Vector2(r * 2.0, r * 1.8))
	var pins := PinLayer.active()
	var fig_mode := FIGURES and cam_d <= CARD_DIST
	var figs: Array[String] = []
	var epoch := models.static_epoch
	var frame := Engine.get_process_frames()
	if epoch != _epoch_seen:
		# yeniden kurulumu beklemeden: yürümeye başlayan tümenin sayacı her karede izlenir
		_epoch_seen = epoch
		for d: Division in models._moving:
			var mk: String = _div_key.get(d.id, "")
			if mk != "" and _counters.has(mk):
				_counters[mk]["dyn"] = true
	for key: String in _counters:
		var c: Dictionary = _counters[key]
		var root: Node3D = c["root"]
		var divs: Array = c["divs"]
		if culled and root.position != Vector3.ZERO:
			# duran sayaç: yerinden (ucuz); yürüyen: tümenin şimdiki yerinden (dışarıdan yürüyüp gelen sayaç eski yerinde
			# takılı kalıyordu)
			# (yeri yeniden dizilip görüşe giren duran sayaç da: yeri ya da çapası görüşteyse güncellenir)
			var a0: Array = models.anchors.get((divs[0] as Division).id, []) if not divs.is_empty() else []
			var at: Vector2 = a0[0] if not a0.is_empty() else Vector2(root.position.x, root.position.z)
			if not view.has_point(at) and (c.get("dyn", true) or not view.has_point(Vector2(root.position.x, root.position.z))):
				continue
		# oturmuş duran sayaç (tümenleri yürümüyor, yerine varmış, payı hedefinde; duranların yerleri de değişmedi):
		# hesaplanacak bir şey yok. Uzak görüşte ~900 sayacın çoğu böyle; her karede yeniden hesaplamak ~2 ms tutuyordu.
		var settled_static: bool = c.get("settled", false) and not c.get("dyn", true) and int(c.get("ep", -1)) == epoch
		if settled_static and c.get("dk", Vector3.ZERO) == c.get("dk_t", Vector3.ZERO) \
				and (c.has("pos0") if fig_mode else float(c.get("ld", -1.0)) == cam_d):
			c["seen_f"] = frame
			if fig_mode:
				figs.append(key)
			continue
		var goal: Vector2
		var base: Vector2
		if settled_static:
			# yeri değişmedi: yalnız zoom'a bağlı yükseklik ve aralık ya da yığın payı güncellenir (zoom sırasında yüzlerce
			# sayacın tümenlerini her karede yeniden toplamak zoom'u takıltıyordu)
			base = c["base"]
			goal = base
			c["seen_f"] = frame
		else:
			var gb := _goal_base(c, key, divs, delta, frame)
			if gb.is_empty():
				continue
			goal = gb[0]
			base = gb[1]
			c["ep"] = epoch
		# aynı bölgedeki sayaçlar yan yana: ~56 px aralık, her zoom'da (sabit boy sayaçlar üst üste binmesin)
		# yan yana kartlar (aynı bölgede ayrı ordular/ülkeler): kart + komutan portresi kadar aralık; dağılmış ızgara
		# ya da rozet için kendi genişliği
		# uzakta rozetler yan yana; yakında aynı noktadakiler yan yana dizilmez, tek noktada üst üste yığılır (_declutter)
		var p := base + (CHIP_STACK * float(c.get("off", 0.0)) * cam_d if cam_d > CARD_DIST else Vector2.ZERO)
		# üst üste binme payı (_declutter): hedefe yumuşakça gelir (kat atlarken sayaç sıçramaz)
		# figür kipinde pay dünya birimidir (zoom'la yer değişmez); kartlarda kamera uzaklığının katı (ekranda sabit aralık)
		var dk: Vector3 = c.get("dk", Vector3.ZERO)
		var dk_t: Vector3 = c.get("dk_t", Vector3.ZERO)
		if fig_mode and c.has("post_pid"):
			if not c.has("post_offset"): c["post_offset"] = dk
			dk = c["post_offset"]
			dk_t = dk
			c["dk"] = dk
		var moved_dk := dk != dk_t
		if moved_dk:
			if fig_mode:
				# figür payına adım adım yürür (yürüyen tümen hızından yavaş değil): kaymaz, sıçramaz
				dk = dk.move_toward(dk_t, maxf(FIG_STEP, 2.0 * float(c.get("vmax", 0.0))) * delta)
			else:
				dk = dk.lerp(dk_t, clampf(delta * 10.0, 0.0, 1.0))
				if dk.distance_to(dk_t) < 0.0004:
					dk = dk_t
			c["dk"] = dk
		c["settled"] = base == goal and dk == dk_t
		if not moved_dk and not fig_mode and c.get("lp", Vector2.INF) == p and is_equal_approx(float(c.get("ld", -1.0)), cam_d):
			continue
		c["lp"] = p
		c["ld"] = cam_d
		if fig_mode:
			c["pos0"] = p + Vector2(dk.x, dk.z)             # çarpışma ve arazi _place_figures'ta
			figs.append(key)
			continue
		var hg: float                                       # arazi yüksekliği (aynı noktada yeniden örneklenmez)
		if c.get("hp", Vector2.INF) == p:
			hg = c["hg"]
		else:
			hg = maxf(map.height_at(p), 0.0)
			c["hp"] = p
			c["hg"] = hg
		var h := hg + LIFT + clampf(cam_d * 0.09, 0.0, 14.0)
		if pins:
			# kart iğnenin ucunda; rozet (uzak) haritanın hemen üstünde, iğnesiz
			h = hg + (PinLayer.lift(cam_d) if cam_d <= CARD_DIST else cam_d * CARD_LIFT)
		c["h0"] = h
		c.erase("fxz")
		root.position = Vector3(p.x, h, p.y) + dk * cam_d   # doğrudan: sayaç kaymaz
	if fig_mode:
		var __pf := Time.get_ticks_usec()
		_place_figures(figs, delta)
		GameClock.timed("units_place", __pf)

## Sayacın hedefi (tümenlerinin görsel yerlerinin ortası) ve oraya kayan yeri: [hedef, yer]; tümeni yoksa boş
func _goal_base(c: Dictionary, key: String, divs: Array, delta: float, frame: int) -> Array:
	# sayacın yeri: duranınki bölgenin olağan noktası; yürüyeninki hedefe giden düz çizgide (tümenlerinin ortası)
	if divs.is_empty():
		return []
	# bölgesinde tümeni kaldıkça orada durur; hepsi başka bölgeye geçtiyse (vardı, geri çekildi) çoğunun bulunduğu
	# bölgeye (sayaçlar yeniden kurulana dek eski bölgesine geri yürümez; biri ayrılınca bütün figür onunla gitmez)
	var pid := int(key.get_slice(":", 0))
	var here_n := 0
	var where := {}
	for d: Division in divs:
		if d.province == pid:
			here_n += 1
		else:
			where[d.province] = int(where.get(d.province, 0)) + 1
	if here_n == 0:
		var most := 0
		for q: int in where:
			if int(where[q]) > most:
				most = int(where[q])
				pid = q
	var goal: Vector2 = _tile_spot(pid)
	var all_walk := true
	for d: Division in divs:
		if not _walking(d):
			all_walk = false
			break
	c["walking"] = all_walk
	if all_walk or int(c.get("post_pid", pid)) != pid:
		for field: String in ["post_pid", "post_goal", "post_offset", "post_av", "post_aim"]:
			c.erase(field)
	if all_walk:
		var sum := Vector2.ZERO
		for d: Division in divs:
			sum += _walk_pos(d)
		goal = sum / divs.size()
		c["mdir"] = _walk_dir(divs[0])                # yolun o noktadaki yönü (rota kıvrılınca figür de döner)
	elif not World.province(pid).is_land():
		var a0: Array = models.anchors.get((divs[0] as Division).id, [])
		if not a0.is_empty():
			goal = a0[0]                              # denizde (çıkarma): konvoyun yeri
	else:
		# savaş sınırda olur: muharebedeki (saldıran ya da savunan) ve düşmanla yüz yüze duran figür kendi tarafında sınıra
		# yürür, karşısındakiyle sınırın iki yanında durur; savunan çözülünce saldıran sınırı geçip bölgeye girer
		var foe := _combat_foe(pid, divs)
		if c.has("post_goal"):
			goal = c["post_goal"]
		elif foe > 0:
			goal = _border_spot(pid, foe)
			c["post_pid"] = pid
			c["post_goal"] = goal
	# sıçramaz: yeni bölgeye giren, geri çekilen figür oraya yürür (HOP_SPEED). Uzun sıçrama (çıkarma, konuşlanma) ve
	# bir süredir görüş dışında kalan sayaç doğrudan yerine geçer.
	var base: Vector2 = c.get("base", goal)
	var vmax := 0.0                                   # tümenlerinin yürüme hızı (dünya birimi / gerçek sn)
	for d: Division in divs:
		var a: Array = models.anchors.get(d.id, [])
		if a.size() > 3:
			vmax = maxf(vmax, float(a[3]))
	c["vmax"] = vmax
	if base != goal:
		if base.distance_to(goal) > GLIDE_SNAP or frame - int(c.get("seen_f", frame)) > 10:
			base = goal
		else:
			base = base.move_toward(goal, HOP_SPEED * delta)
	# ne zamandır yerinde duruyor (yığında çapa seçimi için): tümenlerin yeri değişince sıfırlanır
	var now_s := Time.get_ticks_msec() / 1000.0
	if not c.has("still_since") or (c.get("still_at", goal) as Vector2).distance_to(goal) > 0.5:
		c["still_since"] = now_s
		c["still_at"] = goal
		if not c.has("hold_pid"):
			c.erase("hold")                         # duranın payı: tümenleri yürüyünce bırakılır
	c["base"] = base
	c["seen_f"] = frame
	return [goal, base]

## Oturmuş duran sayaçların yeri yeniden hesaplanır (muharebe başladı ya da bitti: sınıra yürür, sınırdan döner)
func _reseat() -> void:
	for c: Dictionary in _counters.values():
		c["ep"] = -1

## Figürün çarpıştığı düşman bölgesi (0: yok): saldırdığı bölge; savunuyorsa saldıranların çoğunun geldiği bölge;
## yoksa sınırda karşısında duran düşman (Military.skirmishes)
func _combat_foe(pid: int, divs: Array) -> int:
	var votes := {}
	for d: Division in divs:
		if d.attacking > 0:
			votes[d.attacking] = int(votes.get(d.attacking, 0)) + 1
	if votes.is_empty() and Military.battles.has(pid):
		for a: Division in Military.battles[pid]["attackers"]:
			if a.province != pid:
				votes[a.province] = int(votes.get(a.province, 0)) + 1
	if votes.is_empty():
		for pair: Array in Military.skirmishes:
			if int(pair[0]) == pid:
				votes[int(pair[1])] = int(votes.get(int(pair[1]), 0)) + 1
			elif int(pair[1]) == pid:
				votes[int(pair[0])] = int(votes.get(int(pair[0]), 0)) + 1
	var best := 0
	var most := 0
	for q: int in votes:
		if int(votes[q]) > most or (int(votes[q]) == most and (best == 0 or q < best)):
			most = int(votes[q])
			best = q
	return best

## Sınırdaki duruş yeri: kendi bölgesinin noktasından düşman bölgesininkine yürürken sınırın kesildiği yer, kendi tarafına
## BORDER_GAP geri çekilmiş (iki taraf arasında ~2 × BORDER_GAP: menzilden ateş, dip dibe değil). Sınırlar değişmez:
## önbellekli.
const BORDER_GAP := 10.0
var _border := {}
func _border_spot(own: int, foe: int) -> Vector2:
	var k := own * 1000003 + foe
	if _border.has(k):
		return _border[k]
	var a := _tile_spot(own)
	var b := World.unwrap_near(a, _tile_spot(foe))
	var dir := (b - a).normalized()
	var len := a.distance_to(b)
	var cut := a.lerp(b, 0.5)
	var t := 0.0
	while t < len:
		var p := a + dir * t
		var q := map.province_at(p)
		if q != own and q != 0:
			cut = p
			break
		t += 1.0
	var spot := cut - dir * minf(BORDER_GAP, cut.distance_to(a))
	_border[k] = spot
	return spot

## Figürler (yakında) birbirinin içinden geçmez, araziye oturur, gittikleri yöne dönerler:
## - yürüyen figür önündekinin çevresinden dolanır: yoluna dik yana açılır, geçince yoluna döner; karşılaşan ya da yan
##   yana yürüyen iki figür ikisi de yarı yarıya açılır; duran iki figür değiyorsa ikisi de yarı yarıya aralanır. Aynı
##   yığındakiler (diziliş zaten aralıklı), çıktığı ya da varacağı bölgede duran dostlar (sıradan çıkar, sıraya girer)
##   birbirini itmez. Pay adım adım uygulanır (FIG_STEP; yürüyen hızından yavaş değil): figür yeni yerine yürür, kaymaz.
## - aralık kuzey-güneyde daha geniş (FIG_DEPTH): kamera güneyden eğik baktığı için arkadaki figür öndekinin ardında
##   kalıyordu; mesafeler kuzey-güneyi sıkıştırılmış bir uzayda ölçülür (orada daire, haritada elips)
## - asker (ve diski) gittiği yöne döner: muharebede düşmana, yürürken gerçek yer değişiminin yönüne (yol verirken de),
##   dururken düşman komşuya, yoksa varsayılan duruşa (kameraya). Kaide, bayrak ve sayı dönmez. Dönüş FIG_TURN hızında.
## - kaide altındaki arazinin birkaç noktasından en yükseğine oturur (dağın, tepenin içine gömülmez), yamaçta yamaç
##   boyunca biraz yatar (en çok FIG_TILT)
const SEAT := [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(-1.0, 0.0), Vector2(0.0, 1.0), Vector2(0.0, -1.0),
	Vector2(0.7071, 0.7071), Vector2(-0.7071, 0.7071), Vector2(0.7071, -0.7071), Vector2(-0.7071, -0.7071),
	Vector2(0.5, 0.0), Vector2(-0.5, 0.0), Vector2(0.0, 0.5), Vector2(0.0, -0.5)]
func _place_figures(figs: Array[String], delta: float) -> void:
	var r := FIG_SIZE * UnitFigures.BASE_R
	var dmin := 2.0 * r * FIG_GAP
	var kz := dmin / (FIG_SIZE * FIG_DEPTH)           # ölçülü uzay: z bu katla sıkışır (derinlikte gereken aralık FIG_DEPTH)
	var ahead := dmin * FIG_AHEAD
	var cs := ahead / kz * 1.05
	# anahtar -> [yer (ölçülü, itilmemiş), yürüyor, yön (ölçülü, birim), takım, varış, yığın, bulunduğu bölge, düşman
	#             yönü, hız, yön, hücresinden çıktığı bölge, gerçek yer (ölçülü, payıyla)]
	var info := {}
	var buckets := {}
	for key: String in figs:
		var c: Dictionary = _counters[key]
		if not (c["root"] as Node3D).visible or c.get("fig") == null:
			continue
		var moving: bool = c.get("walking", false)
		var dir := Vector2.ZERO
		var dest := int(key.get_slice(":", 0))
		var cur := dest
		var speed := 0.0
		var pos: Vector2 = c["pos0"]
		# çatışmada: kilitlendiği en yakın düşman bölgesine (_refresh_combat); saat saat hedef değiştirip dönmez
		var foe := Vector2.ZERO
		if c.has("ctarget") and int(c.get("cstate", 0)) != 0:
			var tv: Vector2 = World.unwrap_near(pos, c["ctarget"]) - pos
			if tv.length() > 0.01:
				foe = tv.normalized()
				if c.has("post_pid") and not moving: c["post_aim"] = foe
		elif c.has("post_pid"):
			foe = c.get("post_aim", Vector2.ZERO)
		var dm := Vector2(dir.x, dir.y * kz)
		var av0: Vector2 = c.get("av", Vector2.ZERO)
		info[key] = [Vector2(pos.x, pos.y * kz), moving, dm.normalized() if dm.length() > 0.001 else Vector2.RIGHT,
			_team(str(c["tag"])), dest, str(c.get("stack_of", "")), cur, foe, speed,
			dir.normalized() if dir.length() > 0.001 else Vector2.ZERO, int(c.get("hold_pid", -1)),
			Vector2(pos.x + av0.x, (pos.y + av0.y) * kz)]
		var cell := Vector2i((Vector2(pos.x, pos.y * kz) / cs).floor())
		if not buckets.has(cell):
			buckets[cell] = []
		(buckets[cell] as Array).append(key)
	for key: String in info:
		var me: Array = info[key]
		var pos: Vector2 = me[0]
		var push := Vector2.ZERO
		var cell := Vector2i((pos / cs).floor())
		# yürüyen figür bölgeden bölgeye yolunda düz yürür (yana kaçmaz; aynı bölgedeki kendi ülkesinin figürüne varınca
		# ona katılır); yalnız duran iki figür değiyorsa ikisi de yarı yarıya aralanır (aynı yığındakiler hariç)
		if not me[1] and not _counters[key].has("post_pid"):
			for gy in range(cell.y - 1, cell.y + 2):
				for gx in range(cell.x - 1, cell.x + 2):
					for other: String in buckets.get(Vector2i(gx, gy), []):
						if other == key:
							continue
						var ot: Array = info[other]
						if ot[1] or (me[5] != "" and me[5] == ot[5]):
							continue
						var dv: Vector2 = pos - (ot[0] as Vector2)
						var dist := dv.length()
						if dist < dmin:
							var away := dv / dist if dist > 0.001 else (Vector2.RIGHT if key < other else Vector2.LEFT)
							push += away * (dmin - dist) * 0.5
		var c: Dictionary = _counters[key]
		push = push.limit_length(dmin * 1.5)
		push = Vector2(push.x, push.y / kz)             # ölçülü uzaydan haritaya
		var av: Vector2 = c.get("av", Vector2.ZERO)
		if c.has("post_pid"):
			if not c.has("post_av"): c["post_av"] = av
			push = c["post_av"]
		if av != push:
			# yürüyen yol verirken yürüme hızının en çok 2 katı yana kayar (yolundan çapraz sapar, "başını alıp gitmez");
			# duran figürler FIG_STEP ile aralanır
			var rate: float = maxf(FIG_YIELD, 2.0 * float(me[8])) if me[1] else FIG_STEP
			av = av.move_toward(push, rate * delta)
			c["av"] = av
		var fig: Node3D = c["fig"]
		var fl: Label3D = fig.get_node_or_null("h/n")
		var ft := count_text(_shown_count(c))
		if fl and fl.text != ft:
			fl.text = ft
		var xz: Vector2 = (c["pos0"] as Vector2) + av
		# askerin yönü: yer değişiminin yönü (gerçek sn başına dünya birimi, yumuşatılmış); muharebede düşmana
		var vel: Vector2 = c.get("vel", Vector2.ZERO)
		if c.has("fxz") and delta > 0.0:
			vel = vel.lerp((xz - (c["fxz"] as Vector2)) / delta, clampf(delta * 6.0, 0.0, 1.0))
		else:
			vel = Vector2.ZERO
		c["vel"] = vel
		var want: Vector2 = Vector2.ZERO if me[1] else me[7]
		var aim := want != Vector2.ZERO                # düşmana: tüfeği ona çevrilir (gövde tüfek açısı kadar döner)
		if want == Vector2.ZERO and bool(me[1]) and c.has("mdir") and (c["mdir"] as Vector2).length() > 0.01:
			want = (c["mdir"] as Vector2).normalized()   # yürüyen hep hedefine bakar (yolda sağa sola dönmez)
		if want == Vector2.ZERO:
			if me[1] and vel.length() > 0.15:
				want = vel.normalized()
			elif me[1]:
				want = me[9]                          # cephede bekleyen ya da çok yavaş yürüyen: yolunun yönü
			else:
				want = _face_of(c, key)               # duran: düşman komşuya
				aim = want != Vector2.ZERO
			if want == Vector2.ZERO:
				want = UnitFigures.FACE_DIR
		var yaw: float = c.get("yaw", deg_to_rad(UnitFigures.FACE_YAW))
		var yaw_t := UnitFigures.yaw_for(want) - (UnitFigures.aim_yaw(UnitFigures.kind_of(c.get("fig"))) if aim else 0.0)
		c["aim_ready"] = not me[1] and aim and absf(wrapf(yaw_t - yaw, -PI, PI)) < deg_to_rad(15.0)
		if yaw != yaw_t:
			yaw = rotate_toward(yaw, yaw_t, FIG_TURN * delta)
			c["yaw"] = yaw
		UnitFigures.set_yaw(fig, yaw)
		if (c.get("fxz", Vector2.INF) as Vector2).distance_squared_to(xz) < 0.0001:
			continue
		c["fxz"] = xz
		# kaidenin altı: merkez, kenarda 8, yarı yarıçapta 4 nokta; eğim kenar noktalarından, yükseklik hiçbir noktanın
		# kaideye girmeyeceği kadar
		var hs: Array[float] = []
		for o: Vector2 in SEAT:
			hs.append(maxf(map.height_at(xz + o * r), 0.0))
		var g := (Vector2(hs[1] - hs[2], hs[3] - hs[4]) / (2.0 * r)).limit_length(FIG_TILT)
		var h0 := -INF
		for i in SEAT.size():
			h0 = maxf(h0, hs[i] - g.dot((SEAT[i] as Vector2) * r))
		c["h0"] = h0 + 0.05
		(c["root"] as Node3D).position = Vector3(xz.x, h0 + 0.05, xz.y)
		var up := Vector3(-g.x, 1.0, -g.y).normalized()
		fig.transform = Transform3D(Basis(Quaternion(Vector3.UP, up)).scaled(Vector3.ONE * FIG_SIZE), Vector3.ZERO)

## Kameranın bir düğüme uzaklığı (sahnede değilse yakınlık)
func _cam_dist(n: Node3D) -> float:
	if camera and camera.is_inside_tree() and n.is_inside_tree():
		return camera.global_position.distance_to(n.global_position)
	return (camera as MapCamera3D).distance if camera is MapCamera3D else 300.0

## İğne haritası: görünen sayaçların kökleri (altlarına iğne gövdesi çizilir)
func pin_roots() -> Array[Node3D]:
	var out: Array[Node3D] = []
	if camera is MapCamera3D and (camera as MapCamera3D).distance > CARD_DIST:
		return out                          # rozetler iğnesiz
	if FIGURES:
		return out                          # figürler kaideleriyle yerde durur
	for key: String in _counters:
		var c: Dictionary = _counters[key]
		var root: Node3D = c["root"]
		# ızgarada ve kapalı destede yalnız çapa kartının iğnesi var (gerçek yerde); öbürleri çevresinde iğnesiz
		if root.visible and c.get("pin", true):
			out.append(root)

	for e: Array in _dying:
		if is_instance_valid(e[0]) and (e[0] as Node3D).visible:
			out.append(e[0])
	return out

# ------------------------------------------------------------------ sayaçlar
## Tümenin kart resmi: zırhlı (orta tank varsa orta), motorlu, piyade — şablonun taburlarından
## Figür türü: yığının baskın türü zırhlıysa tank, değilse asker
static func _fig_kind_for(kind: String) -> String:
	return "tank" if kind == "light_armor" or kind == "medium_armor" else "soldier"

## Sayacın figürü istenen türde değilse yeniden kurulur (yer, ölçek, görünürlük, yön ve sayı korunur)
func _swap_fig(c: Dictionary, tag: String, fk: String) -> void:
	var old: Node3D = c.get("fig")
	if old == null or UnitFigures.kind_of(old) == fk or not World.countries.has(tag):
		return
	var fig := UnitFigures.make(World.countries[tag], fk)
	fig.scale = old.scale
	fig.position = old.position
	fig.visible = old.visible
	UnitFigures.set_count(fig, int(c.get("count", (c["divs"] as Array).size())))
	UnitFigures.set_yaw(fig, float(c.get("yaw", deg_to_rad(UnitFigures.FACE_YAW))))
	old.get_parent().add_child(fig)
	old.queue_free()
	c["fig"] = fig
	c.erase("base_xf")

static func division_type(d: Division) -> String:
	var bats := _battalions(d)
	if int(bats.get("medium_armor", 0)) > 0:
		return "medium_armor"
	if int(bats.get("light_armor", 0)) > 0:
		return "light_armor"
	if int(bats.get("motorized", 0)) > 0:
		return "motorized"
	return "infantry"

static func _battalions(d: Division) -> Dictionary:
	var c: Country = World.countries.get(d.owner)
	if c == null or c.templates.is_empty():
		return {}
	return c.templates[clampi(d.template, 0, c.templates.size() - 1)]["battalions"]

## Kart resmi (fildişi siluet, kırpılmış): kullanıcının çizdiği assets/ui/unit_cards/card_<tür>.png; yoksa teçhizat
## ikonunun şekli fildişine boyanır (tasarımdaki gibi tek renk, hafif gölgeli)
static func card_glyph(type: String, allow_own := true) -> Image:
	var key := type + (":own" if allow_own else ":icon")
	if _glyph_img.has(key):
		return _glyph_img[key]
	var img: Image = null
	var own := "res://assets/ui/unit_cards/card_%s.png" % type
	if not allow_own:
		own = ""
	var tex: Texture2D = load(own) if own != "" and ResourceLoader.exists(own) else UiTheme.icon(CARD_FALLBACK.get(type, "equipment_infantry_equipment"))
	if tex:
		img = tex.get_image()
		if img.is_compressed():
			img.decompress()
		img = img.duplicate()
		img.convert(Image.FORMAT_RGBA8)
		if own == "" or not ResourceLoader.exists(own):
			for y in img.get_height():
				for x in img.get_width():
					var px := img.get_pixel(x, y)
					if px.a <= 0.0:
						continue
					var lum := px.r * 0.299 + px.g * 0.587 + px.b * 0.114
					var k := clampf(0.62 + lum * 0.75, 0.0, 1.08)
					img.set_pixel(x, y, Color(CARD_IVORY.r * k, CARD_IVORY.g * k, CARD_IVORY.b * k, px.a))
		var used := img.get_used_rect()
		if used.size.x > 0 and used.size.y > 0:
			img = img.get_region(used)
	_glyph_img[key] = img
	return img

## Birlik resmi kutuya sığdırılmış ve gölgesi (önbellekli: büyük resim her levhada yeniden ölçeklenmesin)
static var _fit_cache := {}
## Levha resmi: referanstaki açık altın baskı. Kaynak PNG değişmez; küçük boydaki orta tonları
## kaldırıp koyu oyma çizgilerini korur. Sadece ana resme uygulanır, bayrak/çerçeve/simgeye değil.
static func _engraving_ink(px: Color) -> Color:
	var lum := px.r * 0.299 + px.g * 0.587 + px.b * 0.114
	var tone := pow(clampf((lum - 0.055) / 0.72, 0.0, 1.0), 0.68)
	var dark := Color("302a1c")
	var gold := Color("cbb078")
	var light := Color("f6e6b9")
	var ink := dark.lerp(gold, tone / 0.48) if tone < 0.48 else gold.lerp(light, (tone - 0.48) / 0.52)
	ink.a = px.a
	return ink

static func _glyph_fit(type: String, box: Vector2) -> Array:
	var key := "%s:%d:%d" % [type, int(box.x), int(box.y)]
	if _fit_cache.has(key):
		return _fit_cache[key]
	var src := card_glyph(type)
	if src == null:
		_fit_cache[key] = []
		return []
	var sc := minf(box.x / float(src.get_width()), box.y / float(src.get_height()))
	var g := src.duplicate()
	g.resize(maxi(int(src.get_width() * sc), 1), maxi(int(src.get_height() * sc), 1), Image.INTERPOLATE_LANCZOS)
	# Renk eşleme küçültmeden sonra: çok sayıda kartta megapiksel başına işlem yapılmaz.
	if ResourceLoader.exists("res://assets/ui/unit_cards/card_%s.png" % type):
		for yy in g.get_height():
			for xx in g.get_width():
				g.set_pixel(xx, yy, _engraving_ink(g.get_pixel(xx, yy)))
	var sh := g.duplicate()
	for yy in sh.get_height():
		for xx in sh.get_width():
			var a2: float = sh.get_pixel(xx, yy).a
			sh.set_pixel(xx, yy, Color(0.02, 0.02, 0.02, a2 * 0.55))
	_fit_cache[key] = [g, sh]
	return _fit_cache[key]

## Resmi kutuya sığdırıp karta bindir (en-boy korunur)
static func _blit_glyph(card: Image, glyph: Image, center: Vector2, box: Vector2) -> void:
	if glyph == null:
		return
	var sc := minf(box.x / float(glyph.get_width()), box.y / float(glyph.get_height()))
	var gw := maxi(int(glyph.get_width() * sc), 1)
	var gh := maxi(int(glyph.get_height() * sc), 1)
	# küçültülmüş resim önbellekte: büyük resmi her rozette yeniden küçültmek ülke başına ~100 ms takılmaydı
	var ck := "%d:%d:%d" % [glyph.get_instance_id(), gw, gh]
	var g: Image = _blit_cache.get(ck)
	if g == null:
		g = glyph.duplicate()
		g.resize(gw, gh, Image.INTERPOLATE_LANCZOS)
		_blit_cache[ck] = g
	card.blend_rect(g, Rect2i(0, 0, gw, gh), Vector2i(int(center.x - gw * 0.5), int(center.y - gh * 0.5)))
static var _blit_cache := {}

## Birlik levhası (art/soldier-pins.png; tümen, filo, hava kanadı; yakın zoom): dikdörtgen koyu levha, bronz degrade
## çerçeve (üstte açık, altta koyu; seçiliyse altın), solda levhanın tam boyunda dar bayrak şeridi (dikey asılmış gibi
## çevrilir: kesilmez, esnemez; haritanın tonuna uydurulmuş renkler), ortada bayrağa taşabilen birlik resmi, sağ üstte bronz çerçeveli küçük harita işareti. Sayı (sağ alt, büyük) ve ad (levhanın
## altında kutuda) Label3D.
static var _plate_cache := {}
## Birim resmini (1536×1024) yükleyip rozet ve levha boylarına küçültmek tür başına ~100 ms, bir ülkenin levhası ~3 ms:
## oyun kurulurken verilen ülkeler için bir kez yapılır (oyunun ortasında ilk filo göründüğünde ya da ilk yakınlaşmada
## otuz ülkenin levhası aynı karede kuruluyor, kare takılıyordu)
static func prewarm_glyphs(glyphs: Array, tags: Array = []) -> void:
	if World.countries.is_empty():
		return
	if tags.is_empty():
		tags = [World.player_tag if World.countries.has(World.player_tag) else String(World.countries.keys()[0])]
	for tag: String in tags:
		if not World.countries.has(tag):
			continue
		for g: String in glyphs:
			flag_marker(tag, false, true, g)
			plate_tex(tag, false, g)

## Levhanın ülkeden bağımsız tabanı (çerçeve, gölge, dokulu koyu zemin): seçili ve seçili değil için bir kez çizilir.
## Piksel piksel çizim levha başına ~20 ms tutuyordu; ilk kez yaklaşınca birçok ülkenin levhası aynı karede kuruluyordu.
static var _plate_bases := {}
static func _plate_base(selected: bool) -> Image:
	if _plate_bases.has(selected):
		return _plate_bases[selected]
	var w := int(COUNTER_W)
	var h := int(COUNTER_H)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var pad := 3.0
	var r := 7.0
	var hw := w * 0.5 - pad
	var hh := h * 0.5 - pad
	var b_hi := Color("c9a869") if not selected else Color("ffe08a")
	var b_lo := Color("5e4a2c") if not selected else Color("b8862a")
	var bw := 3.2 if not selected else 4.2
	var in0 := 1.4 + bw + 1.2                          # iç alanın kenardan uzaklığı
	for y in h:
		var g := float(y) / float(h)
		for x in w:
			var qx := absf(float(x) + 0.5 - w * 0.5) - (hw - r)
			var qy := absf(float(y) + 0.5 - h * 0.5) - (hh - r)
			var sd := Vector2(maxf(qx, 0.0), maxf(qy, 0.0)).length() + minf(maxf(qx, qy), 0.0) - r
			var col: Color
			if sd > 0.0:
				var sd2 := sd - 1.5 * (float(y) / float(h))
				var a := (1.0 - clampf(sd2 / pad, 0.0, 1.0)) * 0.6
				if a <= 0.0:
					continue
				col = Color(0.02, 0.02, 0.02, a)
			elif sd > -1.4:
				col = Color(0.03, 0.03, 0.03)
			elif sd > -1.4 - bw:
				var t := (-sd - 1.4) / bw
				var ridge := clampf(1.0 - absf(t - 0.4) * 1.8, 0.0, 1.0)
				var bc := b_hi.lerp(b_lo, g)
				col = bc.darkened(0.3).lerp(bc.lightened(0.12), ridge)
			elif sd > -in0:
				col = Color(0.03, 0.03, 0.03)
			else:
				# koyu levha: hafif dokulu, kenarlara doğru koyulaşır
				var v := 1.0 - 0.25 * clampf(-sd / 30.0, 0.0, 1.0)
				var nz := (fposmod(sin(float(x) * 12.9898 + float(y) * 78.233) * 43758.5453, 1.0) - 0.5) * 0.02
				var base := 0.085 / v + nz
				col = Color(base, base, base * 0.95)
			img.set_pixel(x, y, col)
	_plate_bases[selected] = img
	return img

static func plate_tex(tag: String, selected: bool, glyph: String) -> Texture2D:
	var ck := "%s:%s:%s" % [tag, selected, glyph]
	if _plate_cache.has(ck):
		return _plate_cache[ck]
	var c: Country = World.countries[tag]
	var w := int(COUNTER_W)
	var h := int(COUNTER_H)
	var img: Image = _plate_base(selected).duplicate()
	var pad := 3.0
	var b_hi := Color("c9a869") if not selected else Color("ffe08a")
	var bw := 3.2 if not selected else 4.2
	var in0 := 1.4 + bw + 1.2                          # iç alanın kenardan uzaklığı
	var x0 := int(pad + in0)
	var y0 := int(pad + in0)
	var y1 := int(h - pad - in0)
	# bayrak: levhanın tam boyunda, dar bir şerit — dikey asılmış bayrak gibi çevrilir (gönder tarafı üstte), böylece
	# kesilmez, esnemez; kare bayrak kare kalır
	var fimg: Image = FlagFactory.map_flag(c).duplicate()
	if fimg.get_width() > fimg.get_height():
		fimg.rotate_90(CLOCKWISE)
		fimg.flip_x()
	var asp := float(fimg.get_width()) / float(maxi(fimg.get_height(), 1))
	var ph := y1 - y0
	var pw := int(float(ph) * asp)
	var max_w := int(w * 0.4)
	if pw > max_w:
		pw = max_w
		ph = int(float(pw) / asp)
	fimg.resize(pw, ph, Image.INTERPOLATE_LANCZOS)
	var px0 := x0
	var py0 := y0 + (y1 - y0 - ph) / 2
	# birlik resmi: ortada, büyük
	# bayrak şeridi: sağında yumuşak gölge ve ince koyu hat, üstten alta hafif koyulaşan bayrak
	for y in range(py0, py0 + ph):
		for k in range(1, 5):
			var e := img.get_pixel(px0 + pw + k, y)
			img.set_pixel(px0 + pw + k, y, e.darkened(0.5 * (1.0 - float(k - 1) / 4.0)))
		img.set_pixel(px0 + pw, y, Color(0.04, 0.04, 0.04))
	for y in ph:
		var shade := lerpf(0.0, 0.2, float(y) / float(maxi(ph - 1, 1)))
		for x in pw:
			var fc := fimg.get_pixel(x, y)
			img.set_pixel(px0 + x, py0 + y, fc.darkened(shade))
	# birlik resmi: büyük, bayrağın üstüne taşabilir (bayrak şeridinin sonundan başlar); sağda 2-3 haneli sayıya yer kalır.
	# Altında yumuşak koyu gölge: bayrağın açık renkleri üstünde de seçilir.
	var wide := glyph in ["ship", "submarine", "plane", "motorized", "light_armor", "medium_armor", "artillery", "anti_tank"]
	var gc := Vector2(px0 + pw + 40.0, h * 0.54)
	var gbox := Vector2(w * 0.5, h * 0.68) if wide else Vector2(w * 0.50, h * 0.8)
	var fit := _glyph_fit(glyph, gbox)
	if not fit.is_empty():
		var gl: Image = fit[0]
		var sh: Image = fit[1]
		var at := Vector2i(int(gc.x - gl.get_width() * 0.5), int(gc.y - gl.get_height() * 0.5))
		var rect := Rect2i(0, 0, gl.get_width(), gl.get_height())
		for o: Vector2i in [Vector2i(-2, 1), Vector2i(2, 2), Vector2i(0, 3), Vector2i(-1, -1)]:
			img.blend_rect(sh, rect, at + o)
		img.blend_rect(gl, rect, at)
	# sağ üstte harita işareti
	var sw := 28
	var shh := 22
	var sx := int(w - pad - in0 - sw - 4)
	var sy := y0 + 4
	img.fill_rect(Rect2i(sx - 1, sy - 1, sw + 2, shh + 2), Color(0.03, 0.03, 0.03))
	img.fill_rect(Rect2i(sx, sy, sw, shh), b_hi.darkened(0.25))
	img.fill_rect(Rect2i(sx + 2, sy + 2, sw - 4, shh - 4), Color(0.06, 0.06, 0.06))
	_map_symbol(img, glyph, Rect2i(sx + 5, sy + 5, sw - 10, shh - 10), Color("e8dcc0"))
	var tex := ImageTexture.create_from_image(img)
	_plate_cache[ck] = tex
	return tex

## Levhadaki küçük harita işareti: piyade çarpı, motorlu çarpı + tekerlek, zırhlı oval, topçu nokta, tanksavar ters V,
## uçak siluet, gemi çapa
static func _map_symbol(img: Image, type: String, r: Rect2i, ink: Color) -> void:
	var x0 := r.position.x
	var y0 := r.position.y
	var w := r.size.x
	var h := r.size.y
	var cx := x0 + w / 2
	var cy := y0 + h / 2
	match type:
		"light_armor", "medium_armor":
			for y in range(y0, y0 + h):
				for x in range(x0, x0 + w):
					var e := Vector2((x - cx + 0.5) / (w * 0.5), (y - cy + 0.5) / (h * 0.5))
					var qx := absf(e.x) - 0.45
					var d := Vector2(maxf(qx, 0.0) / 0.55, e.y).length()
					if d > 0.7 and d < 1.05:
						img.set_pixel(x, y, ink)
		"artillery":
			for y in range(cy - 2, cy + 2):
				for x in range(cx - 2, cx + 2):
					img.set_pixel(x, y, ink)
		"anti_tank":
			for i in h:
				var t := float(i) / float(maxi(h - 1, 1))
				img.set_pixel(int(lerpf(x0, cx, t)), y0 + h - 1 - i, ink)
				img.set_pixel(int(lerpf(x0 + w - 1, cx, t)), y0 + h - 1 - i, ink)
		"plane":
			_blit_glyph(img, card_glyph("plane", false), Vector2(cx, cy), Vector2(w + 2, h + 2))
		"ship", "submarine":
			# çapa: halka, gövde, kol, alt kavis
			for y in range(y0 + 3, y0 + h):
				img.set_pixel(cx, y, ink)
			for x in range(cx - 3, cx + 4):
				img.set_pixel(x, y0 + 4, ink)
			for x in range(cx - 1, cx + 2):
				img.set_pixel(x, y0, ink)
				img.set_pixel(x, y0 + 2, ink)
			img.set_pixel(cx - 1, y0 + 1, ink)
			img.set_pixel(cx + 1, y0 + 1, ink)
			for i in range(-w / 2, w / 2 + 1):
				var yy := y0 + h - 1 - int(sqrt(maxf(float(w * w) * 0.25 - float(i * i), 0.0)) * float(h) / float(w) * 0.8)
				img.set_pixel(clampi(cx + i, x0, x0 + w - 1), clampi(yy, y0, y0 + h - 1), ink)
		_:
			for i in w:
				var yy := int(float(i) / float(w - 1) * float(h - 1))
				img.set_pixel(x0 + i, y0 + yy, ink)
				img.set_pixel(x0 + i, y0 + h - 1 - yy, ink)
			for x in range(x0, x0 + w):
				img.set_pixel(x, y0, ink)
				img.set_pixel(x, y0 + h - 1, ink)
			for y in range(y0, y0 + h):
				img.set_pixel(x0, y, ink)
				img.set_pixel(x0 + w - 1, y, ink)
			if type == "motorized":
				img.set_pixel(x0 + 3, y0 + h + 1, ink)
				img.set_pixel(x0 + w - 4, y0 + h + 1, ink)

## Bayrağın baskın rengi (zemin): en çok kullanılan koyu/orta renk; bayrak çoğunlukla açık renkliyse (beyaz zemin)
## ülkenin rengi. Fildişi resim açık zeminde seçilmez.
static func _flag_base_color(img: Image, fallback: Color) -> Color:
	var counts := {}
	var sums := {}
	var step := maxi(img.get_width() / 24, 1)
	for y in range(0, img.get_height(), step):
		for x in range(0, img.get_width(), step):
			var p := img.get_pixel(x, y)
			var k := Vector3i(int(p.r * 7.99), int(p.g * 7.99), int(p.b * 7.99))
			counts[k] = int(counts.get(k, 0)) + 1
			sums[k] = (sums.get(k, Color(0, 0, 0, 0)) as Color) + p
	var best := Vector3i(-1, -1, -1)
	for k: Vector3i in counts:
		var avg: Color = (sums[k] as Color) / float(counts[k])
		if avg.get_luminance() > 0.72:
			continue
		if best.x < 0 or int(counts[k]) > int(counts[best]):
			best = k
	if best.x < 0:
		return fallback.darkened(0.25)
	var col: Color = (sums[best] as Color) / float(counts[best])
	col.a = 1.0
	return col

## Tümenin levhası: yığında en çok olan türün resmi
func _tex_for(tag: String, _ob: int = 10, _sb: int = 10, selected := false, type := "infantry", _hq := false) -> Texture2D:
	return plate_tex(tag, selected, type)

## Levhadaki sayının yeri (Label3D ofseti, PIXEL * 0.8 piksel boyunda; sağa ve alta yaslı): sağ alt köşe
static func plate_label_off(shift: float = 0.0, k := 1.0) -> Vector2:
	var hh := _card_half() * k
	return Vector2(shift + hh.x - 9.0 * k, -hh.y + 6.0 * k) / (PIXEL * 0.8 * PX)

## Rozetteki sayının yeri (Label3D ofseti, PIXEL * 0.8 piksel boyunda): rozetin sağ yarısının ortası
static func chip_label_off(glyph := false) -> Vector2:
	var px := CHIP_GPX if glyph else CHIP_PX
	var cw := (CHIP_GW if glyph else CHIP_W) * px * PX
	var fwp := (float(CHIP_GFW) + 3.0 if glyph else CHIP_H * 1.45 - 3.0) * px * PX
	return Vector2(-cw * 0.5 + fwp + (cw - fwp) * 0.5, 0.0) / (PIXEL * 0.8 * PX)

## Orta/uzak zoom rozeti "bayrak | sayı" (filoda "gemi | sayı", havada "uçak | sayı"): solda bayrak, sağda ülke renginin koyusu sayı alanı (sayı Label3D),
## ülke renginde degrade ince çerçeve (seçiliyse altın). Filolar da solundaki bayrak kısmını kullanır.
static func flag_marker(tag: String, selected := false, chip := true, glyph := "") -> Texture2D:
	var ck := "%s:%s:%s:%s" % [tag, selected, chip, glyph]
	if _flag_tex.has(ck):
		return _flag_tex[ck]
	var c: Country = World.countries[tag]
	var h := int(CHIP_H)
	var w := int(CHIP_W) if chip else int(h * 1.45)
	if chip and glyph != "":
		w = int(CHIP_GW)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var top := c.color.lightened(0.45) if not selected else Color("ffe08a")
	var bot := c.color.darkened(0.45) if not selected else Color("9a7626")
	var bw := 2 if selected else 1
	for y in h:
		var g := float(y) / float(h - 1)
		for x in w:
			var edge := x < bw + 1 or y < bw + 1 or x >= w - bw - 1 or y >= h - bw - 1
			var col: Color
			if x == 0 or y == 0 or x == w - 1 or y == h - 1:
				col = Color(0.04, 0.04, 0.04)
			elif edge:
				col = top.lerp(bot, g)
			else:
				col = c.color.darkened(0.66).lerp(c.color.darkened(0.76), g)
			img.set_pixel(x, y, col)
	var fi: Image = FlagFactory.map_flag(c).duplicate() if glyph == "" else null
	var fw := int(h * 1.45) - 6
	if glyph != "":
		fw = CHIP_GFW
		# filo / hava: bayrak yerine fildişi gemi ya da uçak (zemin ülke renginin koyusu)
		_blit_glyph(img, card_glyph(glyph), Vector2(3 + fw * 0.5, h * 0.5), Vector2(fw - 10, h - 10))
	elif fi:
		# bayrak bölmesinde kendi en-boyunda (esnemez), bölmeye ortalı; kalan yer bölmenin koyu zemini
		var bh := h - 6
		var asp := float(fi.get_width()) / float(maxi(fi.get_height(), 1))
		var bw2 := mini(int(float(bh) * asp), fw)
		var bh2 := mini(int(float(bw2) / asp), bh)
		fi.resize(bw2, bh2, Image.INTERPOLATE_LANCZOS)
		img.fill_rect(Rect2i(3, 3, fw, bh), Color(0.05, 0.05, 0.05))
		img.blit_rect(fi, Rect2i(0, 0, bw2, bh2), Vector2i(3 + (fw - bw2) / 2, 3 + (bh - bh2) / 2))
	if chip:
		for y in range(3, h - 3):
			img.set_pixel(fw + 3, y, Color(0.04, 0.04, 0.04))
	var tex := ImageTexture.create_from_image(img)
	_flag_tex[ck] = tex
	return tex

func _group_pos(pid: int, tag: String, index: int, count: int) -> Vector3:
	var p := World.province(pid).center
	var off := Vector2((index - (count - 1) * 0.5) * 14.0, 0.0)
	var h := maxf(map.height_at(p), 0.0) + LIFT
	return Vector3(p.x + off.x, h, p.y + off.y)

var _rebuild_n := 0
## Tek seferlik hazırlık: ilk sayacın kurulumu (figür örgülerinin ayrılması, malzemeler, levha dokuları) ~0,5 sn ve
## figürlerin ilk çizimi (gölgelendirici hatlarının derlenmesi) ~0,13 sn tutuyordu; oyun başında donmasın diye açılışta
## yapılır (main). Örnek sayaç ve iki figür türü birkaç kare zeminin altında çizilir: görünmez ama hatlar derlenir.
var _warm := false
func prewarm(tag: String) -> void:
	if _warm or not World.countries.has(tag):
		return
	_warm = true
	var c := _make_counter(tag)
	_tex_for(tag)
	_tex_for(tag, 10, 10, true)
	flag_marker(tag)
	flag_marker(tag, true)
	var root: Node3D = c["root"]
	root.reparent(get_parent())                # birlik katmanı gizliyken de çizilsin
	var tank := UnitFigures.make(World.countries[tag], "tank")
	root.add_child(tank)
	for f: Node3D in [c["fig"], tank]:
		if f:
			f.visible = true
			f.scale = Vector3.ONE * FIG_SIZE
	for key: String in ["glow", "flag", "clabel"]:
		var n: Node3D = c[key]
		n.visible = true
		if n is SpriteBase3D:
			(n as SpriteBase3D).modulate.a = 0.0
		elif n is Label3D:
			(n as Label3D).modulate.a = 0.0
			(n as Label3D).outline_modulate.a = 0.0
	for i in 6:
		# kameranın baktığı yerin altında (menü kamerayı sonradan yerleştirir: görüş alanında kalsın)
		var at: Vector3 = (camera as MapCamera3D).target if camera is MapCamera3D else Vector3.ZERO
		root.position = Vector3(at.x, -60.0, at.z)
		await get_tree().process_frame
	_free_parked(c)
	root.queue_free()

## Yeni sayaç kurma bütçesi (µs, 0 = sınırsız): açıkken bir yeniden kurulumda bu süre dolunca kalan sayaçlar sonraki
## karelere kalır (oyun başında ilk kurulum ~0,5 sn tek kare donmaydı; geçiş animasyonu sırasında karelere yayılır)
var build_budget_usec := 0
var _build_more := false

func _rebuild() -> void:
	var __t0 := Time.get_ticks_usec()
	var t_start := __t0
	_build_more = false
	_rebuild_n += 1
	_div_key.clear()
	var groups := {}
	var live := {}
	for d in Military.divisions:
		if Military.hidden(d):
			continue                             # savaş sisi: oyuncunun göremediği düşman tümeni çizilmez
		# anahtar "bölge:ülke:ordu:". Bir bölgede bir ülkenin duran ve saldıran tümenleri TEK figürdür (ordu fark etmez;
		# hepsi aynı ordudaysa anahtarda o ordu, aşağıda). Yürüyenler ">hedef": aynı bölgeden aynı hedefe gidenler tek
		# figür, hedefe düz yürür (_walk_pos), yol üstündeki dost figürlerin içine girip çıkmaz; hedefteki kendi figürüne
		# değdiği an ona katılır (_tile_merge).
		# yürüyenler sıradaki adımlarına göre: aynı bölgeden aynı komşuya yürüyenler (son hedefleri farklı olsa da) tek figür;
		# vardıkları bölgede yine aynı yöne gidenler birlikte devam eder
		var wdest := d.path[0] if _walking(d) else -1
		var kc: Array = _dkey.get(d.id, [])
		var key: String
		if not kc.is_empty() and int(kc[0]) == d.province and int(kc[1]) == wdest:
			key = kc[2]
		else:
			key = "%d:%s:0:" % [d.province, d.owner]
			if wdest >= 0:
				key += ">%d" % wdest                  # aynı bölgeden aynı komşuya yürüyenler tek figür
			_dkey[d.id] = [d.province, wdest, key]
		if wdest >= 0:
			live[d.id] = true
		if not groups.has(key):
			groups[key] = []
		groups[key].append(d)
	for id: int in _walk.keys():
		if not live.has(id):
			_walk.erase(id)
			_walk_last.erase(id)
	# sayacın tümenleri tek ordudaysa anahtarda o ordu (ordunun ana sayacı: komutan portresi, rütbe yıldızları)
	var keyed := {}
	for key: String in groups:
		var divs: Array = groups[key]
		var aid: int = (divs[0] as Division).army
		for d: Division in divs:
			if d.army != aid:
				aid = 0
				break
		keyed["%s:%s:%d:%s" % [key.get_slice(":", 0), key.get_slice(":", 1), aid, key.get_slice(":", 3)]] = divs
	groups = keyed
	GameClock.timed("ur_group", __t0); __t0 = Time.get_ticks_usec()
	_tile_key.clear()
	for key: String in groups:
		_tile_key["%s:%s" % [key.get_slice(":", 0), key.get_slice(":", 1)]] = key
	_sel_keys.clear()
	# sayaçlar tümenleri izler, anahtarı değil: her yığın tümenlerinin çoğunu taşıyan eski sayacı devralır (yürümeye
	# başladı, bölge değiştirdi, vardı, küme sırası değişti). Silinip yeniden kurulunca sayaç sönüp başka yerde
	# beliriyordu; anahtar adı başka yığına geçince de sayaç o yığının yerine geri sıçrıyordu.
	# artımlı: tümenleri aynı kalan sayaç olduğu gibi sürer (eşleştirme ve güncelleme yok); tam kurulum yalnız seçim,
	# ordu ya da oyuncu değişince. Her saatte 600 sayacı baştan kurmak ~25 ms takılmaydı.
	var full := _full_refresh or _counters.is_empty()
	_full_refresh = false
	var same := {}
	for key: String in groups:
		if _counters.has(key) and _same_divs(_counters[key]["divs"], groups[key]):
			same[key] = true
	var was_in := {}                                  # tümen id -> eski sayacın anahtarı
	for ok: String in _counters:
		if same.has(ok):
			continue
		for d: Division in _counters[ok]["divs"]:
			was_in[d.id] = ok
	var pairs: Array = []                             # [puan, yeni anahtar, eski anahtar]
	var kept := {}
	var used := {}
	for key: String in same:
		kept[key] = _counters[key]
		used[key] = true
	for key: String in groups:
		if same.has(key):
			continue
		var votes := {}
		for d: Division in groups[key]:
			var ok: String = was_in.get(d.id, "")
			if ok != "":
				votes[ok] = int(votes.get(ok, 0)) + 1
		for ok: String in votes:
			if str(_counters[ok]["tag"]) == key.get_slice(":", 1):
				pairs.append([int(votes[ok]) * 2 + (1 if ok == key else 0), key, ok])
	pairs.sort_custom(func(a: Array, b: Array) -> bool:
		if a[0] != b[0]:
			return a[0] > b[0]
		return a[1] < b[1] if a[1] != b[1] else a[2] < b[2])
	var born_from := {}                               # yeni yığın -> tümenlerinin çoğunun eski sayacı (orada doğar)
	for pr: Array in pairs:
		if not born_from.has(pr[1]):
			born_from[pr[1]] = _counters[pr[2]]
		if kept.has(pr[1]) or used.has(pr[2]):
			continue
		kept[pr[1]] = _counters[pr[2]]
		used[pr[2]] = true
	var alive := {}
	for key: String in groups:
		if same.has(key):
			continue
		for d: Division in groups[key]:
			alive[d.id] = true
	for ok: String in _counters:
		if same.has(ok):
			continue
		var old: Dictionary = _counters[ok]
		var dead := 0
		var any_alive := false
		for d: Division in old["divs"]:
			if alive.has(d.id):
				any_alive = true
			else:
				dead += 1
		# figürün bir kısmı öldü (figür sürüyor): yanında o kadar piyon yere devrilir (en çok 2)
		if FIGURES and dead > 0 and (used.has(ok) or any_alive) and (old["root"] as Node3D).visible \
				and old.get("fig") != null and (old["fig"] as Node3D).visible:
			for k in mini(dead, 2):
				_fallen_pawn(old, k)
		if used.has(ok):
			continue
		if any_alive:
			old["root"].queue_free()                  # tümenleri başka sayaca katıldı
			_free_parked(old)
		else:
			_begin_death(old)                         # tümenleri yok oldu: devrilir (figür) ya da söner (levha)
	_counters = kept
	GameClock.timed("ur_vote", __t0); __t0 = Time.get_ticks_usec()
	for key: String in _counters:
		_counters[key]["members"] = [key]            # birleşik rozet listesi eski anahtarları tutmasın (_cluster yeniler)
	# Her ordunun ana sayacı (en çok tümen): komuta yıldızı ve varsa komutan portresi yalnız orada.
	var hq := {}
	for key: String in groups:
		var aid := int(key.get_slice(":", 2))
		if aid == 0:
			continue
		var best: String = hq.get(aid, "")
		if best == "" or (groups[key] as Array).size() > (groups[best] as Array).size() \
				or ((groups[key] as Array).size() == (groups[best] as Array).size() and key < best):
			hq[aid] = key
	# bir bölgenin aynı noktasındaki farklı ülkeler / ordular yan yana
	var per_pid := {}
	for key: String in groups:
		var spot_key := key.get_slice(":", 0) + ":" + key.get_slice(":", 3)
		if not per_pid.has(spot_key):
			per_pid[spot_key] = []
		per_pid[spot_key].append(key)
	for spot_key: String in per_pid:
		var pid := int(spot_key.get_slice(":", 0))
		var keys: Array = per_pid[spot_key]
		keys.sort()
		for i in keys.size():
			var key: String = keys[i]
			var divs: Array = groups[key]
			var tag: String = key.get_slice(":", 1)
			if not _counters.has(key):
				if build_budget_usec > 0 and Time.get_ticks_usec() - t_start > build_budget_usec:
					_build_more = true                 # bütçe doldu: bu yığının sayacı sonraki karede
					continue
				var __mk := Time.get_ticks_usec()
				_counters[key] = _make_counter(tag)
				GameClock.timed("ur_make", __mk)
				var src: Dictionary = born_from.get(key, {})
				if not src.is_empty() and src.has("base"):
					# ayrılan yığın eski sayacın tam yerinde doğar, oradan kendi yerine yürür (başka yerde belirmez)
					var nc: Dictionary = _counters[key]
					for f: String in ["base", "lp", "ld", "h0", "dk", "seen_f", "yaw"]:
						if src.has(f):
							nc[f] = src[f]
					(nc["root"] as Node3D).position = (src["root"] as Node3D).position
					var d0: Division = divs[0]
					if FIGURES and key.get_slice(":", 3).begins_with(">") and not d0.path.is_empty():
						# yürümeye başlayıp kaynağından ayrılan figür kaynağın dizilişteki hücresinden yola çıkar (müttefik
						# yığınında); kendi ülkesinin figüründen ayrılan onun yerinden, yoluna düz çıkar
						if src.has("dk") and str(src.get("stack_of", "")) != "":
							nc["hold"] = src["dk"]
							nc["hold_pid"] = d0.province
			var c: Dictionary = _counters[key]
			var dyn := false                                        # yürüyen ya da saldıran tümeni var: her karede izlenir
			for d: Division in divs:
				if not d.path.is_empty() or d.attacking > 0:
					dyn = true
					break
			if same.has(key) and not full:
				if c.get("dyn", false) != dyn:
					c["dyn"] = dyn
					c["ep"] = -1
				for d: Division in divs:
					_div_key[d.id] = key
				if c.get("selected", false):
					_sel_keys.append(key)
				continue
			c["divs"] = divs
			c["ep"] = -1                                            # tümenleri değişmiş olabilir: bir kez yeniden hesapla
			c["dyn"] = dyn
			c.erase("face_sig")
			c["off"] = float(i) - float(keys.size() - 1) * 0.5     # destedeki sıra (ekran payı _follow_anchors'ta)
			_stack_priority(c, i)
			var army_id := int(key.get_slice(":", 2))
			var an: Label3D = c["army"]
			var army := Military.army_by_id(army_id) if army_id != 0 and tag == World.player_tag else null
			var is_hq: bool = army_id != 0 and str(hq.get(army_id, "")) == key
			# oyuncunun sayacının altında ad: ordudaysa ordunun adı (altın), tek tümense tümenin adı (açık)
			# ad her levhada: orduysa ordunun adı (oyuncununkiler; yapay zekâ ordularında da), tek tümense tümenin adı, birden
			# çok ordusuz tümende ilkinin adı ve kalanların sayısı
			var name_txt := ""
			var any_army: Army = Military.army_by_id(army_id) if army_id != 0 else null
			if any_army:
				name_txt = any_army.name
			elif divs.size() == 1:
				name_txt = (divs[0] as Division).name
			else:
				name_txt = "%s +%d" % [(divs[0] as Division).name, divs.size() - 1]
			# haritada ad yazılmaz (savaşta kalabalığı karıştırıyordu): ad ipucunda ve seçim panelinde; ordunun sayacında
			# rütbe yıldızları (sol üst köşenin dışında)
			name_txt = ""
			if an.text != name_txt:
				an.text = name_txt
				_name_plate(an)
			an.visible = false
			_set_stars(c, _star_count(any_army))
			var cm: Commander = null
			if army and is_hq:
				cm = Military.commander_by_id(army.commander)
			_set_portrait(c, cm)
			if models == null or c["root"].position == Vector3.ZERO:
				c["root"].position = _group_pos(pid, tag, i, keys.size())
			var org := 0.0
			var strn := 0.0
			var sel := false
			for d: Division in divs:
				org += d.org / maxf(Military.div_stats(d)["org"], 1.0)
				strn += d.strength
				if d in selected:
					sel = true
			# kartın resmi: yığında en çok olan tümen türü; yakın zoom'da içindeki tabur türleri küçük kartlarla
			var types := {}
			var comp := {}
			for d: Division in divs:
				var ty := division_type(d)
				types[ty] = int(types.get(ty, 0)) + 1
				if FIGURES:
					continue                              # bileşim kartları yalnız levha kipinde (_set_comp)
				var bats := _battalions(d)
				for bt: String in bats:
					comp[bt] = int(comp.get(bt, 0)) + int(bats[bt])
			var kind := "infantry"
			for ty: String in types:
				if int(types[ty]) > int(types.get(kind, 0)):
					kind = ty
			_set_comp(c, comp, sel)
			if FIGURES:
				_swap_fig(c, tag, _fig_kind_for(kind))      # zırhlı ağırlıklı yığın tank, öbürleri asker
			var ob := clampi(roundi(org / divs.size() * 10.0), 0, 10)
			var sb := clampi(roundi(strn / divs.size() * 10.0), 0, 10)
			# görünüşü değişmeyen sayaca dokunma (doku/yazı atamaları pahalı)
			var look := Vector4i(divs.size(), ob * 16 + sb, CARD_TYPES.find(kind), 1 if sel else 0)
			if c.get("look", Vector4i(-1, -1, -1, -1)) != look or c.get("hq", false) != is_hq:
				c["look"] = look
				c["hq"] = is_hq
				if not FIGURES:
					set_count(c["label"], divs.size(), 42)       # figür kipinde levha yazısı hiç görünmez
				set_count(c["clabel"], divs.size(), 30)
				c["bg"].texture = _tex_for(tag, ob, sb, sel, kind, is_hq)
				c["flag"].texture = flag_marker(tag, sel)
			c["selected"] = sel
			for d: Division in divs:
				_div_key[d.id] = key
			if sel:
				_sel_keys.append(key)
			else:
				c["root"].scale = Vector3.ONE

func _sprite(tex: Texture2D, px: float, prio: int) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = tex
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.fixed_size = true
	s.pixel_size = px
	s.no_depth_test = true
	s.render_priority = prio
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return s

## Destede sonraki rozet öncekinin üstünde çizilir (bayrağı ve sayısı birlikte): sayılar alttaki rozetin üstüne taşmaz
func _stack_priority(c: Dictionary, i: int) -> void:
	var m := mini(i, 30) * 3
	(c["flag"] as Sprite3D).render_priority = 10 + m
	var cl: Label3D = c["clabel"]
	cl.outline_render_priority = 11 + m
	cl.render_priority = 12 + m

func _make_counter(tag: String) -> Dictionary:
	var root := Node3D.new()
	add_child(root)
	var glow := _sprite(glow_texture(), CARD_PX, 8)   # muharebede çevresi yeşil / kırmızı yanar (levhanın arkasında)
	glow.visible = false
	root.add_child(glow)
	var bg := _sprite(_tex_for(tag), CARD_PX, 10)
	root.add_child(bg)
	var fig: Node3D = null
	if FIGURES:
		fig = UnitFigures.make(World.countries[tag])
		fig.scale = Vector3.ONE * FIG_SIZE
		fig.visible = false
		root.add_child(fig)
	var lbl := Label3D.new()
	lbl.font = UiTheme.bold_font()
	lbl.font_size = 42
	lbl.outline_size = 2
	lbl.outline_modulate = Color(0.03, 0.03, 0.03, 0.95)
	lbl.modulate = Color("f3ead0")
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.fixed_size = true
	lbl.pixel_size = PIXEL * 0.8
	lbl.no_depth_test = true
	lbl.render_priority = 12
	lbl.outline_render_priority = 11
	lbl.offset = _label_off(0.0)
	root.add_child(lbl)
	var flag := _sprite(flag_marker(tag), CHIP_PX, 10)
	flag.visible = false
	root.add_child(flag)
	var clbl := Label3D.new()                # rozetin sağ yarısındaki sayı
	clbl.font = UiTheme.bold_font()
	clbl.font_size = 30
	clbl.outline_size = 3
	clbl.outline_modulate = Color(0.04, 0.04, 0.04, 0.9)
	clbl.modulate = Color("ece3c6")
	clbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	clbl.fixed_size = true
	clbl.pixel_size = PIXEL * 0.8
	clbl.no_depth_test = true
	clbl.render_priority = 12
	clbl.outline_render_priority = 11
	clbl.offset = chip_label_off()
	clbl.visible = false
	root.add_child(clbl)
	# Oyuncunun ordu adı birleşik portre + sayaç işaretinin altında kalır.
	var an := Label3D.new()
	an.font = load("res://assets/fonts/BarlowCondensed-Medium.ttf")
	an.font_size = 28
	an.outline_size = 0
	an.modulate = NAME_COLOR
	an.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	an.fixed_size = true
	an.pixel_size = PIXEL * 0.8
	an.no_depth_test = true
	an.render_priority = 12
	an.outline_render_priority = 11
	an.offset = Vector2(0, -_card_half().y - 10.0) / (PIXEL * 0.8 * PX)
	an.visible = false
	root.add_child(an)
	_vis_dirty = true
	var c := {"root": root, "label": lbl, "clabel": clbl, "bg": bg, "flag": flag, "army": an, "tag": tag, "divs": [],
		"selected": false, "subs": [], "glow": glow, "fig": fig}
	_attach(c, "army", false)
	if FIGURES:
		_attach(c, "bg", false)
		_attach(c, "label", false)
	return c

## Sayacın hiç görünmeyen parçaları (figür kipinde levha ve sayı yazısı; haritada ad yazılmadığı için ad) kurulurken sayaç
## kökünden ayrılıp yerinden oynamayan gizli bir düğümde bekler: kök her yer değiştirdiğinde motor bütün alt düğümlerin
## dönüşümünü yeniler (görünmeyenlerinki de). Zoom eşiğinde parça taşımak ise yüzlerce sayaçta kareyi takıltır: yalnız hiç
## görünmeyenler.
const PARKABLE := ["bg", "label", "army"]
var _parking: Node3D

func _attach(c: Dictionary, key: String, on: bool) -> void:
	var n: Node = c.get(key)
	if n == null or not is_instance_valid(n):
		return
	var want: Node = c["root"] if on else _park()
	var cur := n.get_parent()
	if cur == want:
		return
	if cur:
		n.reparent(want, false)
	else:
		want.add_child(n)

func _park() -> Node3D:
	if _parking == null:
		_parking = Node3D.new()
		_parking.name = "parking"
		_parking.visible = false
		add_child(_parking)
	return _parking

## Silinen sayacın beklemedeki parçaları da silinir
func _free_parked(c: Dictionary) -> void:
	for key: String in PARKABLE:
		var n: Node = c.get(key)
		if n != null and is_instance_valid(n) and n.get_parent() == _parking:
			n.queue_free()

## Levha/rozet sayısı: 1000 ve üstü kısaltılır (1.1K), uzun sayı küçük yazılır (uçak sayısı binleri bulabilir; büyük
## rakamlar levhadan taşıp alttakine biniyordu). base: olağan yazı boyu
static func count_text(n: int) -> String:
	return str(n) if n < 1000 else UiTheme.format_number(n).replace(".0K", "K")

static func set_count(l: Label3D, n: int, base: int) -> void:
	var t := count_text(n)
	if l.text != t:
		l.text = t
	var fs := base if t.length() <= 2 else (int(base * 0.84) if t.length() == 3 else int(base * 0.72))
	if l.font_size != fs:
		l.font_size = fs

## Rütbe yıldızı: ordunun sayaçlarında sol üst köşenin dışında — komutansız ordu ★, generalli ★★, mareşalli ★★★;
## ordusuz tümende yok
const STAR_PX := 15.0              ## bir yıldızın ekran boyu (1080p)
static var _star_tex := {}

static func _star_count(army: Army) -> int:
	if army == null:
		return 0
	var cm := Military.commander_by_id(army.commander) if army.commander != 0 else null
	if cm == null:
		return 1
	return 3 if cm.is_marshal() else 2

## n yan yana altın yıldız: koyu kenarlı beş köşe (doku 2 kat çözünürlükte)
static func star_texture(n: int) -> Texture2D:
	if _star_tex.has(n):
		return _star_tex[n]
	var s := 32
	var gap := 4
	var img := Image.create(n * s + (n - 1) * gap, s, false, Image.FORMAT_RGBA8)
	var fill := Color("e8c35a")
	var edge := Color(0.08, 0.06, 0.03)
	for i in n:
		var cx := float(i * (s + gap)) + s * 0.5
		var cy := s * 0.52
		var pts := PackedVector2Array()
		for k in 10:
			var a := -PI * 0.5 + PI * float(k) / 5.0
			var rr := (s * 0.48) if k % 2 == 0 else (s * 0.2)
			pts.append(Vector2(cx + cos(a) * rr, cy + sin(a) * rr))
		for y in s:
			for x in range(i * (s + gap), i * (s + gap) + s):
				var p := Vector2(x + 0.5, y + 0.5)
				if Geometry2D.is_point_in_polygon(p, pts):
					# kenar: çokgenin kenarına 1,6 pikselden yakınsa koyu
					var near_edge := false
					for e in 10:
						var q := Geometry2D.get_closest_point_to_segment(p, pts[e], pts[(e + 1) % 10])
						if q.distance_to(p) < 1.6:
							near_edge = true
							break
					img.set_pixel(x, y, edge if near_edge else fill.lerp(Color("b8923a"), float(y) / s))
	var tex := ImageTexture.create_from_image(img)
	_star_tex[n] = tex
	return tex

func _set_stars(c: Dictionary, n: int) -> void:
	var st: Sprite3D = c.get("stars")
	if n <= 0:
		if st:
			st.visible = false
		c["star_n"] = 0
		return
	if st == null:
		st = _sprite(star_texture(n), 1.0, 11)
		(c["root"] as Node3D).add_child(st)
		c["stars"] = st
	if int(c.get("star_n", -1)) != n:
		st.texture = star_texture(n)
		st.pixel_size = STAR_PX / (32.0 * PX)
	c["star_n"] = n
	_place_stars(c)

## Yıldızlar kartın sol üst köşesinin dışında (portre takılıysa kart kaydığı için onunla)
func _place_stars(c: Dictionary) -> void:
	var st: Sprite3D = c.get("stars")
	if st == null:
		return
	var half := _card_half()
	var w := float(st.texture.get_width()) * st.pixel_size * PX
	var h := float(st.texture.get_height()) * st.pixel_size * PX
	var shift := float(c.get("cmd_shift", 0.0))
	var so := Vector2(-half.x + shift + w * 0.5, half.y + h * 0.5 + 2.0) / (st.pixel_size * PX)
	if st.offset != so:
		st.offset = so
	var subs: Array = c.get("subs", [])
	st.visible = int(c.get("star_n", 0)) > 0 and _was_far == 0 and not (_compose and not subs.is_empty())

## Kapalı destenin çapa kartının arkasında iki kartın kenarı (sağ üste kaymış, koyu): burada birden çok birlik var
func _show_decks() -> void:
	for key: String in _counters:
		var c: Dictionary = _counters[key]
		var want: bool = int(c.get("deck_n", 0)) > 0 and _was_far == 0 and (c["root"] as Node3D).visible
		var edges: Array = c.get("edges", [])
		if not want:
			for e: Sprite3D in edges:
				e.visible = false
			continue
		var bg: Sprite3D = c["bg"]
		if edges.is_empty():
			for i in 2:
				var e := _sprite(bg.texture, CARD_PX, 9)
				e.modulate = Color(0.5, 0.5, 0.5) if i == 0 else Color(0.36, 0.36, 0.36)
				(c["root"] as Node3D).add_child(e)
				edges.append(e)
			c["edges"] = edges
		for i in 2:
			var e: Sprite3D = edges[i]
			e.texture = bg.texture
			e.offset = bg.offset + Vector2(7.0, 7.0) * float(i + 1) / (CARD_PX * PX)
			e.visible = int(c["deck_n"]) > i

## Yok olan tümenin sayacı: resmi ve bayrağı siyah-beyaz olur, yazılar soluklaşır; _animate_dying yavaşça söndürür
func _begin_death(c: Dictionary) -> void:
	var root: Node3D = c["root"]
	for key: String in ["bg", "flag"]:
		var sp: Sprite3D = c[key]
		if sp.texture:
			sp.texture = _grayscale(sp.texture)
	(c["glow"] as Sprite3D).visible = false
	for key: String in ["label", "clabel", "army"]:
		var l: Label3D = c[key]
		l.modulate = Color(0.62, 0.62, 0.62, l.modulate.a)
	for sub: Array in c.get("subs", []):
		(sub[0] as Sprite3D).modulate = Color(0.5, 0.5, 0.5)
	# yakında figür görünüyorsa devrilir (_topple); uzakta levha/rozet siyah-beyaz söner
	c["topple"] = FIGURES and c.get("fig") != null and (c["fig"] as Node3D).visible and root.visible
	_dying.append([root, 0.0, c])

## Ölen tümenin piyonu: figürün yanında (k: sıra) kendi ülkesinin piyonu belirir ve yere devrilir (_animate_dying)
func _fallen_pawn(c: Dictionary, k: int) -> void:
	var tag: String = c["tag"]
	if not World.countries.has(tag):
		return
	var root := Node3D.new()
	add_child(root)
	var rp: Node3D = c["root"]
	var yaw := float(c.get("yaw", deg_to_rad(UnitFigures.FACE_YAW)))
	var side := Vector2(cos(yaw + PI * 0.5 + k * PI), -sin(yaw + PI * 0.5 + k * PI))
	var at := Vector2(rp.position.x, rp.position.z) + side * FIG_SIZE * UnitFigures.BASE_R * 2.1
	root.position = Vector3(at.x, maxf(map.height_at(at), 0.0) + 0.05, at.y)
	var fig := UnitFigures.make(World.countries[tag], UnitFigures.kind_of(c.get("fig")))
	fig.scale = Vector3.ONE * FIG_SIZE
	UnitFigures.set_yaw(fig, yaw)
	var nl: Label3D = fig.get_node_or_null("h/n")
	if nl:
		nl.text = "1"
	root.add_child(fig)
	_dying.append([root, 0.0, {"fig": fig, "yaw": yaw, "ghost": true, "root": root}])

## Dokunun renksiz (gri tonlu, biraz karartılmış) kopyası
static func _grayscale(tex: Texture2D) -> Texture2D:
	var img: Image = tex.get_image()
	if img == null:
		return tex
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	for y in img.get_height():
		for x in img.get_width():
			var p := img.get_pixel(x, y)
			var v := p.get_luminance() * 0.8
			img.set_pixel(x, y, Color(v, v, v, p.a))
	return ImageTexture.create_from_image(img)

## Sönen sayaçlar: siyah-beyaz durur, son saniyede yavaşça saydamlaşıp silinir (yanıp sönmez)
func _animate_dying(delta: float) -> void:
	var i := 0
	while i < _dying.size():
		var e: Array = _dying[i]
		if not is_instance_valid(e[0]):
			_dying.remove_at(i)
			continue
		var root: Node3D = e[0]
		var age: float = float(e[1]) + delta
		e[1] = age
		if age >= DIE_TIME:
			root.queue_free()
			if not (e[2] as Dictionary).get("ghost", false):
				_free_parked(e[2])
			_dying.remove_at(i)
			continue
		var cd: Dictionary = e[2]
		if cd.get("topple", false) or cd.get("ghost", false):
			_topple(cd, age)
			i += 1
			continue
		var a := clampf((DIE_TIME - age) / 1.0, 0.0, 1.0)            # son 1 sn söner
		for ch in root.get_children():
			if ch is SpriteBase3D:
				(ch as SpriteBase3D).modulate.a = a
			elif ch is Label3D:
				(ch as Label3D).modulate.a = a
				(ch as Label3D).outline_modulate.a = a
		i += 1

## Piyon devrilir: tüfeğin tersine, kaidenin kenarı üstünde döner (0,55 sn; yere değince hafif sekme), yatık durur,
## son 0,7 sn'de toprağa gömülerek kaybolur
const TOPPLE_TIME := 0.55
func _topple(cd: Dictionary, age: float) -> void:
	var fig: Node3D = cd["fig"]
	if not cd.has("base_xf"):
		cd["base_xf"] = fig.transform
		var t: Node3D = fig.get_node_or_null("t")
		if t:
			t.transform = Transform3D(Basis(Vector3.UP, float(cd.get("yaw", 0.0))), Vector3(0.0, 0.5, 0.0))
	var yaw := float(cd.get("yaw", 0.0)) + UnitFigures.aim_yaw(UnitFigures.kind_of(fig))
	var back := Vector3(-cos(yaw), 0.0, sin(yaw))              # tüfeğin tersi (geriye düşer)
	var axis := Vector3.UP.cross(back).normalized()
	var k := clampf(age / TOPPLE_TIME, 0.0, 1.0)
	var ang := PI * 0.5 * k * k                                 # hızlanarak düşer
	if age > TOPPLE_TIME:
		ang = PI * 0.5 - absf(sin((age - TOPPLE_TIME) * 14.0)) * 0.12 * exp(-(age - TOPPLE_TIME) * 6.0)   # sekme
	var r := UnitFigures.BASE_R * FIG_SIZE
	var pivot := back * r                                       # kaidenin geri kenarı
	var rot := Basis(axis, ang)
	var bx: Transform3D = cd["base_xf"]
	var xf := Transform3D(rot, pivot - rot * pivot) * bx
	var sink := clampf((age - (DIE_TIME - 0.7)) / 0.7, 0.0, 1.0)
	xf.origin.y -= sink * r * 1.2
	fig.transform = xf
	fig.visible = true

## Muharebe parlaması: levha dikdörtgeninin çevresinde dışa doğru sönen yumuşak hale (beyaz; renk modulate ile)
static func glow_texture() -> Texture2D:
	if _glow_tex:
		return _glow_tex
	var w := int(COUNTER_W) + GLOW_M * 2
	var h := int(COUNTER_H) + GLOW_M * 2
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var dx := maxf(absf(float(x) + 0.5 - w * 0.5) - COUNTER_W * 0.5, 0.0)
			var dy := maxf(absf(float(y) + 0.5 - h * 0.5) - COUNTER_H * 0.5, 0.0)
			var a := pow(1.0 - clampf(sqrt(dx * dx + dy * dy) / float(GLOW_M), 0.0, 1.0), 1.8)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_glow_tex = ImageTexture.create_from_image(img)
	return _glow_tex

## Muharebe durumu: saldıran taraf payı %50'den çoksa saldıranlar üstün (yeşil), savunanlar geriliyor (kırmızı); tersi
## de öyle. Sayaç, içindeki tümenlerin çoğunun durumunu alır. Muharebe değişince ve sayaçlar yeniden kurulunca.
func _refresh_combat() -> void:
	var previous_targets := _combat_target.duplicate()
	_combat.clear()
	_combat_dir.clear()
	_combat_target.clear()
	# yan yana ateş (Military._skirmish): iki taraf da birbirine döner, bütünlüğü yüksek olan üstün görünür
	_fresh_caches()
	for pr: Array in Military.skirmishes:
		var pa := World.province(int(pr[0])).center
		var pb := World.unwrap_near(pa, World.province(int(pr[1])).center)
		var ta := World.controller_tag(int(pr[0]))
		var tb := World.controller_tag(int(pr[1]))
		var sa := _side_org(int(pr[0]), tb)
		var sb := _side_org(int(pr[1]), ta)
		var spa := _tile_spot(int(pr[0]))
		var spb := _tile_spot(int(pr[1]))
		for d: Division in Military.divisions_in(int(pr[0])):
			if d.path.is_empty() and _enemies(d.owner, tb):
				_combat[d.id] = 1 if sa >= sb else -1
				_combat_dir[d.id] = (pb - pa).normalized()
				_choose_combat_target(d.id, _border_spot(int(pr[1]), int(pr[0])), previous_targets)
		for d: Division in Military.divisions_in(int(pr[1])):
			if d.path.is_empty() and _enemies(d.owner, ta):
				_combat[d.id] = 1 if sb > sa else -1
				_combat_dir[d.id] = (pa - pb).normalized()
				_choose_combat_target(d.id, _border_spot(int(pr[0]), int(pr[1])), previous_targets)
	for pid: int in Military.battles:
		var b: Dictionary = Military.battles[pid]
		var ar := float(b.get("att_ratio", 0.5))
		var dr := float(b.get("def_ratio", 0.5))
		var att_good := ar >= dr
		var to := World.province(pid).center
		var from := World.unwrap_near(to, World.province(int(b.get("from", pid))).center)
		for d: Division in b.get("attackers", []):
			_combat[d.id] = 1 if att_good else -1
			_combat_dir[d.id] = (to - from).normalized()
			_choose_combat_target(d.id, _border_spot(pid, d.province) if d.province != pid else _tile_spot(pid), previous_targets)
		for d: Division in b.get("defenders", []):
			_combat[d.id] = -1 if att_good else 1
			_combat_dir[d.id] = (from - to).normalized()
			_choose_combat_target(d.id, _border_spot(int(b.get("from", pid)), pid) if int(b.get("from", pid)) != pid else _tile_spot(pid), previous_targets)
	_glowing.clear()
	for key: String in _counters:
		var c: Dictionary = _counters[key]
		var s := 0
		# nişan: tümenlerinin ateş ettiği düşman bölgelerinden en yakını; önceki hedef hâlâ aralarındaysa o kalır
		var here := _tile_spot(int(key.get_slice(":", 0)))
		var keep := false
		var best := Vector2.INF
		var best_d := INF
		for d: Division in c["divs"]:
			s += int(_combat.get(d.id, 0))
			if _combat_target.has(d.id):
				var tv: Vector2 = _combat_target[d.id]
				if c.has("ctarget") and (c["ctarget"] as Vector2).distance_to(tv) < 0.5:
					keep = true
				var dd := here.distance_squared_to(World.unwrap_near(here, tv))
				if dd < best_d:
					best_d = dd
					best = tv
		if not keep:
			if best != Vector2.INF:
				c["ctarget"] = best
			else:
				c.erase("ctarget")
		c["cstate"] = signi(s) if s != 0 else (1 if c.has("ctarget") else 0)
		if int(c["cstate"]) != 0:
			_glowing.append(key)
		elif (c["glow"] as Sprite3D).visible:
			(c["glow"] as Sprite3D).visible = false

## Keep a still-valid aim point regardless of skirmish/dictionary iteration order.
## If it disappeared, choose the nearest remaining candidate, with a stable tie break.
func _choose_combat_target(id: int, candidate: Vector2, previous: Dictionary) -> void:
	if not _combat_target.has(id):
		_combat_target[id] = candidate
		return
	var current: Vector2 = _combat_target[id]
	if previous.has(id):
		var origin: Vector2 = previous[id]
		var old_distance := origin.distance_squared_to(World.unwrap_near(origin, current))
		var new_distance := origin.distance_squared_to(World.unwrap_near(origin, candidate))
		if not is_equal_approx(old_distance, new_distance):
			if new_distance < old_distance: _combat_target[id] = candidate
			return
	if candidate.x < current.x or (candidate.x == current.x and candidate.y < current.y):
		_combat_target[id] = candidate

# ------------------------------------------------------------------ bölgede tek figür (her karede)
var _tile_key := {}                  ## "bölge:ülke" -> o bölgenin figürünün anahtarı (son kurulumdan)

## Sayaçlar aralıklı yeniden kurulur (tam kurulum 30-60 ms); arada tümeni başka bölgeye geçen (vardı, geri çekildi)
## figür, geçtiği bölgede kendi ülkesinin figürü varsa AYNI KAREDE ona katılır: gizlenir, sayısı oradakine eklenir.
## Aynı bölgede aynı ülkenin iki figürü hiç görünmez; bir sonraki kurulumda tümenler o figürün sayacına geçer.
var _merge_sig := Vector3i(-1, -1, -1)
var _merge_wait := false
var _merge_stay := {}
func _tile_merge() -> void:
	# tümenler yalnız oyun saatinde yer değiştirir: tam hesap saat/emir/kurulum değişince; arada her karede yalnız yürüyen
	# figürlerin hedef sınırını geçmesine bakılır
	# tam hesap yalnız bir tümen yer değiştirince, emir ya da kurulum değişince; o da bir sonraki karede (oyun saatinin
	# işlendiği kareye binmesin)
	var sig := Vector3i(Military.move_version, Military.order_version, _rebuild_n)
	if sig != _merge_sig and not _merge_wait:
		_merge_wait = true
		_merge_walkers()
		return
	if sig == _merge_sig:
		_merge_walkers()
		return
	_merge_wait = false
	_merge_sig = sig
	var stay := {}                                   # anahtar -> kendi bölgesinde kalan tümen sayısı
	for key: String in _counters:
		var c: Dictionary = _counters[key]
		c["extra"] = 0
		c["gone"] = 0
		var kp := int(key.get_slice(":", 0))
		var n := 0
		for d: Division in c["divs"]:
			if d.province == kp:
				n += 1
		stay[key] = n
	for key: String in _counters:
		var c: Dictionary = _counters[key]
		var kp := int(key.get_slice(":", 0))
		var moved := {}                              # başka bölgeye geçen tümenler: bölge -> sayı
		for d: Division in c["divs"]:
			if d.province != kp and not (_walking(d) and d.province != d.path[d.path.size() - 1]):
				moved[d.province] = int(moved.get(d.province, 0)) + 1     # yol üstünden geçen sayılmaz
		var into := ""
		for pid: int in moved:
			var hk: String = _tile_key.get("%d:%s" % [pid, c["tag"]], "")
			if hk == "" or hk == key or not _counters.has(hk) or int(stay.get(hk, 0)) == 0:
				continue                             # orada kendi figürü yok: bu figürle gider (ya da kurulumda ayrılır)
			_counters[hk]["extra"] = int(_counters[hk]["extra"]) + int(moved[pid])
			c["gone"] = int(c["gone"]) + int(moved[pid])
			if int(stay[key]) == 0 and moved.size() == 1:
				into = hk                            # hepsi oraya geçti: bu figür gizlenir
		c["walk_into"] = ""
		var was: bool = c.get("tile_merged", false)
		c["tile_merged"] = into != ""
		if was != (into != ""):
			(c["root"] as Node3D).visible = c.get("base_vis", true) and not c.get("merged", false) \
				and not c.get("deck_hidden", false) and into == ""
	_merge_stay = stay
	_merge_walkers()
	_refresh_counts()

## Yürüyen figür hedef bölgesinin sınırını geçtiği an oradaki kendi figürüne katılır (sayısı ona eklenir); hedefte kendi
## askeri yoksa hedefin noktasına yürür. Yol üstündeki bölgelerde (izinle geçilen başka ülkeler dahil) katılmaz.
func _merge_walkers() -> void:
	var changed := false
	for key: String in _counters:
		var c: Dictionary = _counters[key]
		if not c.get("walking", false) or c.get("tile_merged", false) and str(c.get("walk_into", "")) == "":
			continue
		var divs: Array = c["divs"]
		if divs.is_empty() or (divs[0] as Division).path.is_empty():
			continue
		var d0: Division = divs[0]
		var dest: int = d0.path[d0.path.size() - 1]
		var hk2: String = _tile_key.get("%d:%s" % [dest, c["tag"]], "")
		var into := ""
		if hk2 != "" and hk2 != key and _counters.has(hk2) and int(_merge_stay.get(hk2, 0)) > 0:
			var ra: Node3D = c["root"]
			if map.province_at(Vector2(ra.position.x, ra.position.z)) == dest:
				into = hk2
		var prev: String = c.get("walk_into", "")
		if into == prev:
			continue
		changed = true
		var n := divs.size() - int(c.get("gone", 0))
		if prev != "" and _counters.has(prev):
			_counters[prev]["extra"] = maxi(0, int(_counters[prev].get("extra", 0)) - n)
		if into != "":
			_counters[into]["extra"] = int(_counters[into].get("extra", 0)) + n
		c["walk_into"] = into
		c["tile_merged"] = into != ""
		(c["root"] as Node3D).visible = c.get("base_vis", true) and not c.get("merged", false) \
			and not c.get("deck_hidden", false) and into == ""
	if changed:
		_refresh_counts()

## Figür sayıları (yakında figürde, uzakta rozette): değişince yazılır
func _refresh_counts() -> void:
	for key: String in _counters:
		var c: Dictionary = _counters[key]
		var n := _shown_count(c)
		if int(c.get("shown_n", -1)) != n:
			c["shown_n"] = n
			set_count(c["clabel"], n, 30)

## Figürde yazan sayı: kendi tümenleri, başka bölgedeki figüre katılanlar düşülür, bu bölgeye katılanlar eklenir
func _shown_count(c: Dictionary) -> int:
	return maxi(int(c.get("count", (c["divs"] as Array).size())) - int(c.get("gone", 0)) + int(c.get("extra", 0)), 0)

# ------------------------------------------------------------------ yürüyüş (figürler)
var _walk := {}                      ## tümen id -> [çıkış noktası, hedef noktası, toplam km, hedef, önbellek anahtarı, kalan bacakların km'si]
var _walk_last := {}                 ## last sampled route point; reorders start here, never on a straight chord

## Yürüyor mu (figürü hedefe yürür): yolda, taarruzda değil, eğitimde değil; sıradaki bölgede düşman yoksa (taarruz için
## yola çıkan bölgesinin figüründe durup ateş eder)
func _walking(d: Division) -> bool:
	if d.path.is_empty() or d.attacking != 0 or d.training != 0:
		return false
	_fresh_caches()
	var w: Variant = _walk_ok.get(d.id)
	if w == null:
		w = not _enemy_in(d.path[0], d.owner)
		_walk_ok[d.id] = w
	return w

var _full_refresh := true            ## bir sonraki kurulum bütün sayaçları günceller (seçim, ordu, oyuncu değişti)
var _dkey := {}                      ## tümen id -> [bölge, yürüdüğü hedef, sayaç anahtarı] (anahtar metni yeniden kurulmaz)

func _same_divs(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if a[i] != b[i]:
			return false
	return true

## Figürün bakışı (duran): askeri olan en yakın düşman komşusuna, yoksa en yakın düşman bölgesine; çatışmadaki nişanla
## aynı yer. Yalnız görünen figürler için, saat ya da emir değişince bir kez hesaplanır.
func _face_of(c: Dictionary, key: String) -> Vector2:
	_fresh_caches()
	if c.get("face_sig") == _cache_sig:
		return c.get("face", Vector2.ZERO)
	c["face_sig"] = _cache_sig
	var pid := int(key.get_slice(":", 0))
	var tag: String = c["tag"]
	var face := Vector2.ZERO
	var here := _tile_spot(pid)
	var best := INF
	for n in World.land_neighbors(pid):
		if not _enemies(World.controller_tag(n), tag):
			continue
		var q := World.unwrap_near(here, _tile_spot(n))
		var dd := here.distance_squared_to(q) * (1.0 if _enemy_in(n, tag) else 16.0)
		if dd < best:
			best = dd
			face = (q - here).normalized()
	c["face"] = face
	return face

# ------------------------------------------------------------------ önbellekler (oyun saati ya da emir değişince)
## "Bölgede şu ülkenin düşmanı var mı", "iki ülke düşman mı", "tümen yürüyor mu" soruları kare başına yüzlerce kez
## sorulur (figür yerleşimi, birleştirme, bakış). Her biri bölgedeki tümenleri ve bütün savaşları tarıyordu: kurulum
## ~30 ms, kare başına birkaç ms tutuyordu. Saat ya da emir değişene dek geçerli.
var _cache_sig := Vector3i(-1, -1, -1)
var _occ := {}                       ## bölge -> {ülke: true} (o bölgede tümeni olan ülkeler)
var _foe := {}                       ## "a:b" -> düşman mı
var _walk_ok := {}                   ## tümen id -> yürüyor mu (sıradaki bölgede düşman yok)

func _fresh_caches() -> void:
	var sig := Vector3i(World.day_count * 24 + GameClock.hour, Military.order_version, Military.divisions.size())
	if sig == _cache_sig:
		return
	_cache_sig = sig
	_occ.clear()
	_walk_ok.clear()
	_foe.clear()
	for d: Division in Military.divisions:
		if not _occ.has(d.province):
			_occ[d.province] = {}
		(_occ[d.province] as Dictionary)[d.owner] = true

func _enemies(a: String, b: String) -> bool:
	if a == "" or b == "" or a == b:
		return false
	var k := a + ":" + b
	var v: Variant = _foe.get(k)
	if v == null:
		v = Diplomacy.are_enemies(a, b)
		_foe[k] = v
	return v

## Bölgede tag'in düşmanının tümeni var mı
func _enemy_in(pid: int, tag: String) -> bool:
	_fresh_caches()
	for o: String in _occ.get(pid, {}):
		if _enemies(o, tag):
			return true
	return false

## Yürüyenin yeri: emir anındaki gerçek rotası (_route_line: bölgelerden geçen yol, okla aynı çizgi) boyunca, rotada
## aldığı yolla orantılı. Emir değişince o anki yerinden yeni rotaya. Kayıt: [çıkış, hedef noktası, toplam km, hedef
## bölge, saat anahtarı, sonraki bacakların km'si, rota çizgisi, çizgi boyunca birikimli uzunluk]
func _walk_pos(d: Division) -> Vector2:
	var e := _walk_entry(d)
	var p := _poly_at(e, _walk_frac(d, e))
	_walk_last[d.id] = p
	return p

## Yürüyenin şimdiki yönü (rotanın o noktadaki teğeti)
func _walk_dir(d: Division) -> Vector2:
	var e := _walk_entry(d)
	var f := _walk_frac(d, e)
	return _poly_at(e, minf(f + 0.02, 1.0)) - _poly_at(e, maxf(f - 0.02, 0.0))

## Yürüyenin kalan rotası (ok bunu çizer): şimdiki yerinden hedefe
func walk_line(d: Division) -> Array[Vector2]:
	var e := _walk_entry(d)
	var f := _walk_frac(d, e)
	var poly: Array[Vector2] = e[6]
	var cum: PackedFloat32Array = e[7]
	var at := f * cum[cum.size() - 1]
	var out: Array[Vector2] = [_poly_at(e, f)]
	for i in poly.size():
		if cum[i] > at:
			out.append(poly[i])
	return out

func _poly_at(e: Array, f: float) -> Vector2:
	var poly: Array[Vector2] = e[6]
	var cum: PackedFloat32Array = e[7]
	if poly.size() < 2:
		return poly[0] if not poly.is_empty() else e[0]
	var at := clampf(f, 0.0, 1.0) * cum[cum.size() - 1]
	var i := cum.bsearch(at)
	i = clampi(i, 1, poly.size() - 1)
	var seg := maxf(cum[i] - cum[i - 1], 1e-5)
	return poly[i - 1].lerp(poly[i], clampf((at - cum[i - 1]) / seg, 0.0, 1.0))

func _walk_entry(d: Division) -> Array:
	var dest: int = d.path[d.path.size() - 1]
	var e: Array = _walk.get(d.id, [])
	var hr := World.day_count * 24 + GameClock.hour
	var ck := Vector3i(hr, d.province, d.path.size())
	if e.is_empty() or int(e[3]) != dest:
		var start: Vector2 = _tile_spot(d.province)
		if not e.is_empty():
			start = _walk_last.get(d.id, _poly_at(e, _walk_frac(d, e)))
		# Depart from the visible emplacement, not back through the province centre.
		var key: String = _div_key.get(d.id, "")
		if _counters.has(key):
			var counter: Dictionary = _counters[key]
			start = counter.get("fxz", counter.get("base", start))
		var to := World.unwrap_near(start, _tile_spot(dest))
		var poly := _route_line(d, start)
		poly[poly.size() - 1] = to                    # rota hedefin duruş noktasında biter
		var cum := PackedFloat32Array([0.0])
		for i in range(1, poly.size()):
			cum.append(cum[i - 1] + poly[i - 1].distance_to(poly[i]))
		e = [start, to, 1.0, dest, Vector3i(-1, 0, 0), 0.0, poly, cum]
		e[5] = _rest_km(d)
		e[4] = ck
		e[2] = maxf(_leg_left_km(d) + float(e[5]), 1.0)
		_walk[d.id] = e
	elif e[4] != ck:
		e[5] = _rest_km(d)
		e[4] = ck
	return e

func _walk_frac(d: Division, e: Array) -> float:
	return clampf(1.0 - (_leg_left_km(d) + float(e[5])) / float(e[2]), 0.0, 1.0)

## Sıradaki bacakta kalan km (saat içi ara değerle)
func _leg_left_km(d: Division) -> float:
	var km := World.distance_km(d.province, d.path[0])
	var kmh := Military._speed(d, d.path[0]) if World.province(d.path[0]) else 0.0
	return maxf(km - d.progress - kmh * GameClock.hour_fraction(), 0.0)

## Sıradakinden sonraki bacakların km'si
func _rest_km(d: Division) -> float:
	var km := 0.0
	for i in range(0, d.path.size() - 1):
		km += World.distance_km(d.path[i], d.path[i + 1])
	return km

# ------------------------------------------------------------------ çatışma canlandırması (figürler)
## UnitFigures'ın gerçek namlu yuvası kullanılır. Atış/tetik ve geri tepme burada;
## alev, uçuş, isabet, toprak ve duman ortak CombatEffects katmanında toplu çizilir.
## Tank topu tüfekle aynı hızda ateş etmez; yığındaki tümen sayısı görsel ateşi çoğaltmaz.
const RIFLE_GAP := Vector2(0.35, 0.85)
const CANNON_GAP := Vector2(1.8, 3.0)
const SHELL_GAP := Vector2(3.2, 6.5)                 ## arada gelen topçu isabeti (gerçek sn)
const HAZE_GAP := Vector2(4.5, 7.5)                  ## seyrek barut dumanı; harita sisle kaplanmaz
var _combat_target := {}                             ## tümen id -> ateş ettiği düşman figürünün bölge noktası
var _posed := {}                                     ## geri tepme/sarsılma pozu uygulanan sayaçlar
var _combat_rng := RandomNumberGenerator.new()       ## yalnız görsel atış/dağılım; Military RNG'sinden ayrı

func _tile_spot(pid: int) -> Vector2:
	var pc := World.province(pid).center
	return models.cities.unit_spot(pid, pc) if models and models.cities and World.province(pid).is_land() else pc

func _combat_fx(delta: float) -> void:
	# Ortak efektlerin zamanı da duraklatılır; yeni atış ve gövde geri tepmesi ilerlemez.
	if GameClock.paused:
		return
	var fig_mode := FIGURES and _was_far == 0 and combat_effects != null
	var view := Rect2()
	if camera is MapCamera3D:
		var mc := camera as MapCamera3D
		var r := mc.distance * 1.6
		view = Rect2(Vector2(mc.target.x, mc.target.z) - Vector2(r, r), Vector2(r * 2.0, r * 1.8))
	var active := {}
	if fig_mode:
		for key: String in _glowing:
			if not _counters.has(key):
				continue
			var c: Dictionary = _counters[key]
			var fig: Node3D = c.get("fig")
			if c.get("walking", false) or not c.get("aim_ready", true):
				continue
			if fig == null or not fig.visible or not (c["root"] as Node3D).visible:
				continue
			# visible=true ekran içinde demek değildir: dünya dışındaki muharebeler
			# ortak efekt bütçesini tüketmeden önce ucuz görüş elemesinden geçer.
			if not _combat_in_view((c["root"] as Node3D).global_position, view):
				continue
			if not c.has("ctarget"):
				continue
			var tgt: Vector2 = World.unwrap_near(Vector2((c["root"] as Node3D).position.x, (c["root"] as Node3D).position.z), c["ctarget"])
			active[key] = true
			var weapon := _combat_weapon(fig)
			var gap := CANNON_GAP if weapon == "cannon" else RIFLE_GAP
			if c.get("shot_weapon", "") != weapon:
				c["shot_weapon"] = weapon
				c["shot_t"] = _combat_rng.randf_range(gap.x, gap.y)
			c["shot_t"] = float(c["shot_t"]) - delta
			if float(c["shot_t"]) <= 0.0:
				c["shot_t"] = _combat_rng.randf_range(gap.x, gap.y)
				_fire(c, fig, tgt)
			if not c.has("shell_t"):
				c["shell_t"] = _combat_rng.randf_range(SHELL_GAP.x, SHELL_GAP.y)
			c["shell_t"] = float(c["shell_t"]) - delta
			if float(c["shell_t"]) <= 0.0:
				c["shell_t"] = _combat_rng.randf_range(SHELL_GAP.x, SHELL_GAP.y)
				_shell(tgt)
			if not c.has("haze_t"):
				c["haze_t"] = _combat_rng.randf_range(HAZE_GAP.x, HAZE_GAP.y)
			c["haze_t"] = float(c["haze_t"]) - delta
			if float(c["haze_t"]) <= 0.0:
				c["haze_t"] = _combat_rng.randf_range(HAZE_GAP.x, HAZE_GAP.y)
				_haze(Vector2((c["root"] as Node3D).position.x, (c["root"] as Node3D).position.z), tgt)
			_pose(c, fig, delta)
	# çatışmadan çıkanlar dik durur
	for key: String in _posed:
		if not active.has(key) and _counters.has(key):
			var c: Dictionary = _counters[key]
			var fig: Node3D = c.get("fig")
			if fig:
				var t: Node3D = fig.get_node_or_null("t")
				if t:
					t.transform = Transform3D(Basis(Vector3.UP, float(c.get("yaw", 0.0))), Vector3(0.0, 0.5, 0.0))
			c.erase("recoil")
			c.erase("shake")
			c.erase("duck")
	_posed = active

func _combat_in_view(at: Vector3, view: Rect2) -> bool:
	if camera == null:
		return true
	var point := at
	if camera is MapCamera3D:
		var mc := camera as MapCamera3D
		if mc.distance > CARD_DIST:
			return false
		# Counter transforms are already placed in their visible wrapped copy.
		# Do not reinterpret a stale offscreen model as a visible copy here.
		var xz := Vector2(at.x, at.z)
		if not view.has_point(xz):
			return false
		point = Vector3(xz.x, at.y, xz.y)
	if not camera.is_inside_tree():
		return true
	if camera.is_position_behind(point):
		return false
	var screen := Rect2(Vector2.ZERO, camera.get_viewport().get_visible_rect().size).grow(64.0)
	return screen.has_point(camera.unproject_position(point))

static func _combat_weapon(fig: Node3D) -> String:
	return "cannon" if UnitFigures.kind_of(fig) == "tank" else "rifle"

## Geri tepme (tüfeğin tersine kısa itiş, üst gövde hafif geri yatar) ve vurulunca sarsılma
func _pose(c: Dictionary, fig: Node3D, delta: float) -> void:
	var t: Node3D = fig.get_node_or_null("t")
	if t == null:
		return
	var rc := maxf(float(c.get("recoil", 0.0)) - delta * 10.0, 0.0)
	var sh := maxf(float(c.get("shake", 0.0)) - delta * 3.5, 0.0)
	var dk := maxf(float(c.get("duck", 0.0)) - delta * 1.1, 0.0)
	c["recoil"] = rc
	c["shake"] = sh
	c["duck"] = dk
	var yaw := float(c.get("yaw", 0.0))
	var ay := UnitFigures.aim_yaw(UnitFigures.kind_of(fig))
	var fwd := Vector3(cos(yaw + ay), 0.0, -sin(yaw + ay))
	var side := fwd.cross(Vector3.UP)
	var kick := rc * rc
	# A short damped kick, not continuous sideways vibration or squash/stretch.
	var b := Basis(side, kick * 0.045 + sh * 0.015) * Basis(Vector3.UP, yaw)
	var down := sin(clampf(dk, 0.0, 1.0) * PI * 0.5) * 0.04
	t.transform = Transform3D(b, Vector3(0.0, 0.5 - down, 0.0) - fwd * (0.018 * kick + 0.008 * sh))

func _fire(c: Dictionary, fig: Node3D, tgt: Vector2) -> void:
	var t: Node3D = fig.get_node_or_null("t")
	if t == null or combat_effects == null or map == null or GameClock.paused:
		return
	c["recoil"] = 1.0
	var kind := UnitFigures.kind_of(fig)
	var socket := fig.global_transform * t.transform
	var muzzle: Vector3 = socket * UnitFigures.muzzle(kind)
	var yaw := UnitFigures.aim_yaw(kind)
	var direction := (socket.basis * Vector3(cos(yaw), 0.0, -sin(yaw))).normalized()
	var weapon := _combat_weapon(fig)
	var off := Vector2.from_angle(_combat_rng.randf() * TAU) * FIG_SIZE * _combat_rng.randf_range(0.1, 0.75)
	var at := tgt + off
	var aim := Vector3(at.x, maxf(map.height_at(at), 0.0) + 0.15, at.y)
	var scale := FIG_SIZE / 10.0
	combat_effects.muzzle(muzzle, direction, weapon, scale)
	# CombatEffects schedules the impact when the round arrives, not at shot time.
	combat_effects.projectile(muzzle, aim, weapon, scale)

## Top mermisi: düşman figürünün yakınına (üstüne değil) düşer — alev, toprak sıçraması, koyu duman
func _shell(tgt: Vector2) -> void:
	if combat_effects == null or map == null or GameClock.paused:
		return
	var at := tgt + Vector2.from_angle(_combat_rng.randf() * TAU) * FIG_SIZE * _combat_rng.randf_range(0.7, 1.6)
	var g := Vector3(at.x, maxf(map.height_at(at), 0.0) + 0.15, at.y)
	combat_effects.impact(g, "shell", FIG_SIZE / 10.0)

## Seyrek, küçük barut dumanı; arazinin ve figürlerin üstünde sürekli bir perde olmaz.
func _haze(from: Vector2, to: Vector2) -> void:
	if combat_effects == null or map == null or GameClock.paused:
		return
	var at := from.lerp(to, _combat_rng.randf_range(0.35, 0.65)) + Vector2.from_angle(_combat_rng.randf() * TAU) * FIG_SIZE * 0.4
	var g := Vector3(at.x, maxf(map.height_at(at), 0.0) + FIG_SIZE * 0.06, at.y)
	combat_effects.smoke(g, FIG_SIZE / 10.0 * 0.55, false,
		Vector3(_combat_rng.randf_range(-0.2, 0.2), 0.55, _combat_rng.randf_range(-0.2, 0.2)))

## Mermi ya da top mermisi yakınındaki figürü sarsar; top mermisinde asker bir an çömelir (siper alır)
func _shake_near(p: Vector3, r: float, duck := false) -> void:
	for key: String in _glowing:
		if not _counters.has(key):
			continue
		var c: Dictionary = _counters[key]
		var rt: Node3D = c["root"]
		if Vector2(rt.position.x - p.x, rt.position.z - p.z).length() < r:
			c["shake"] = 1.0
			if duck:
				c["duck"] = 1.0

## Bölgedeki, komşudaki düşmana (foe: komşuyu elinde tutan) ateş eden tümenlerin ortalama bütünlük oranı
func _side_org(pid: int, foe: String) -> float:
	var o := 0.0
	var n := 0
	for d: Division in Military.divisions_in(pid):
		if _enemies(d.owner, foe):
			o += d.org / maxf(Military.div_stats(d)["org"], 1.0)
			n += 1
	return o / maxf(n, 1)

## Muharebedeki sayaçların çevresi nabız gibi yanıp söner (yeşil üstün, kırmızı geriliyor); muharebe işareti hafifçe
## büyüyüp küçülür. Yakında kartın, uzakta rozetin çevresinde; dağılmış ızgarada ve gizliyken yok.
func _animate_combat(delta: float) -> void:
	_anim_t += delta
	for key: String in _glowing:
		if not _counters.has(key):
			continue
		var c: Dictionary = _counters[key]
		var g: Sprite3D = c["glow"]
		var subs: Array = c.get("subs", [])
		var on: bool = (c["root"] as Node3D).visible and _was_far < 2 and not (_was_far == 0 and _compose and not subs.is_empty())
		var figure: bool = FIGURES and _was_far == 0 and c.get("fig") != null
		g.visible = on and not figure                    # levha biçimli parıltı figürün kaidesine biner: figürde yalnız çakmalar
		if not on:
			continue
		var pulse := 0.38 + 0.2 * sin(_anim_t * 4.0 + float(key.hash() % 7))
		g.modulate = Color(GLOW_GOOD if int(c.get("cstate", 0)) > 0 else GLOW_BAD, pulse)
		if _was_far == 0:
			_muzzle_flashes(c, delta)
		if _was_far == 1:
			var k := (CHIP_W * CHIP_PX) / (COUNTER_W * CARD_PX)
			g.pixel_size = CARD_PX * k
			g.offset = (c["flag"] as Sprite3D).offset * (CHIP_PX / g.pixel_size)
		else:
			g.pixel_size = CARD_PX
			g.offset = (c["bg"] as Sprite3D).offset
	for pid: int in _battle_nodes:
		var bn: Node3D = _battle_nodes[pid]
		bn.scale = Vector3.ONE * (1.0 + 0.1 * sin(_anim_t * 6.0 + float(pid % 11)))
		# işaret iki tarafın kartlarının tam ortasında (kartların üstüne binmesin); kart yoksa bölgeler arasında kalır
		var b: Dictionary = Military.battles.get(pid, {})
		if b.is_empty() or (b.get("attackers", []) as Array).is_empty() or (b.get("defenders", []) as Array).is_empty():
			continue
		var ka: String = _div_key.get((b["attackers"][0] as Division).id, "")
		var kd: String = _div_key.get((b["defenders"][0] as Division).id, "")
		if ka != "" and kd != "" and _counters.has(ka) and _counters.has(kd) and ka != kd:
			var ra: Node3D = _counters[ka]["root"]
			var rd: Node3D = _counters[kd]["root"]
			if ra.visible and rd.visible:
				bn.position = (ra.position + rd.position) * 0.5
	# muharebeden çıkan sayaçların ateşi söner
	for key: String in _counters:
		var c: Dictionary = _counters[key]
		if c.has("flashes") and (int(c.get("cstate", 0)) == 0 or _was_far != 0 or not (c["root"] as Node3D).visible):
			for f: Array in c["flashes"]:
				(f[0] as Sprite3D).visible = false

## Ateş: muharebedeki kartın düşmana bakan kenarında küçük turuncu namlu çakmaları rastgele aralıklarla çakıp söner
## (o an ateş eden birim). Kart başına 3 çakma; her biri 0,08-0,13 sn yanar, 0,2-0,7 sn söner, kenarda başka yerde
## yeniden çakar.
const FLASH_PX := 13.0             ## çakmanın ekran boyu (1080p)
func _muzzle_flashes(c: Dictionary, delta: float) -> void:
	if FIGURES and c.get("fig") != null:
		return                                        # figürde çatışma canlandırması (_combat_fx)
	var flashes: Array = c.get("flashes", [])
	if flashes.is_empty():
		for i in 3:
			var s := _sprite(flash_texture(), FLASH_PX / (32.0 * PX), 12)
			s.modulate = Color(1.0, 0.62, 0.18)
			s.visible = false
			(c["root"] as Node3D).add_child(s)
			flashes.append([s, randf_range(0.0, 0.6)])     # [çakma, bir sonraki değişime kalan süre]
		c["flashes"] = flashes
	var dir := Vector2.RIGHT
	for d: Division in c["divs"]:
		if _combat_dir.has(d.id):
			dir = _combat_dir[d.id]
			break
	var side := 1.0 if dir.x >= 0.0 else -1.0          # kamera kuzeye bakar: harita x'i ekranın yatayı
	var half := _card_half()
	var shift := float(c.get("cmd_shift", 0.0))
	for f: Array in flashes:
		var s: Sprite3D = f[0]
		f[1] = float(f[1]) - delta
		if float(f[1]) > 0.0:
			continue
		if s.visible:
			s.visible = false
			f[1] = randf_range(0.2, 0.7)
		elif FIGURES and c.get("fig") != null:
			# figür: kaidenin düşmana bakan yanında, tüfek boyunda
			var fr := FIG_SIZE * UnitFigures.BASE_R
			var at := dir.rotated(randf_range(-0.6, 0.6)) * fr * randf_range(0.8, 1.1)
			s.offset = Vector2.ZERO
			s.position = Vector3(at.x, FIG_SIZE * randf_range(0.4, 0.65), at.y)
			s.scale = Vector3.ONE * randf_range(0.7, 1.25)
			s.visible = true
			f[1] = randf_range(0.08, 0.13)
		else:
			var px := Vector2(shift + side * (half.x + 5.0), randf_range(-half.y * 0.75, half.y * 0.75))
			s.position = Vector3.ZERO
			s.offset = px / (s.pixel_size * PX)
			s.scale = Vector3.ONE * randf_range(0.7, 1.25)
			s.visible = true
			f[1] = randf_range(0.08, 0.13)

## Namlu çakması: parlak merkezli, dört uzun iki kısa ışınlı küçük patlama (beyaz; renk modulate ile)
static func flash_texture() -> Texture2D:
	if _flash_tex:
		return _flash_tex
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5) / (n * 0.5)
			var r := p.length()
			var ang := atan2(p.y, p.x)
			var rays := pow(absf(cos(ang * 2.0)), 6.0) * 0.9 + pow(absf(cos(ang * 3.0 + 0.5)), 10.0) * 0.5
			var a := clampf(pow(maxf(1.0 - r / (0.35 + 0.6 * rays), 0.0), 1.6) * 1.2, 0.0, 1.0)
			var core := clampf(1.0 - r * 3.2, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 0.85 + 0.15 * core, a))
	_flash_tex = ImageTexture.create_from_image(img)
	return _flash_tex

## Muharebedeki tümenlerin görünen sayaç kökleri (en çok n; durum okları yanlarında çıkar ve sayaçla birlikte gider)
func battle_roots(divs: Array, n := 2) -> Array:
	var out: Array = []
	for d: Division in divs:
		var k: String = _div_key.get(d.id, "")
		if k == "" or not _counters.has(k):
			continue
		var root: Node3D = _counters[k]["root"]
		if root.visible and not root in out:
			out.append(root)
			if out.size() >= n:
				break
	return out

## Sayaç merkezinden işaretin sağ kenarına ekran pikseli (1080p): kart ya da rozet (ok yanına konur)
func side_px(root: Node3D) -> float:
	for key: String in _counters:
		if _counters[key]["root"] == root:
			var c: Dictionary = _counters[key]
			if _was_far == 1:
				return CHIP_W * CHIP_PX * PX * 0.5 + 8.0
			if FIGURES and c.get("fig") != null:
				return FIG_SIZE * UnitFigures.BASE_R * PX / maxf(_cam_dist(root), 1.0) + 10.0
			return _card_half().x + float(c.get("cmd_shift", 0.0)) + 10.0
	return 30.0

## Adın arkasındaki koyu, ince çerçeveli kutu (şehir adlarıyla aynı): yazının genişliğinde, etiketin çocuğu
static func _name_plate(an: Label3D) -> void:
	var plate: Sprite3D = an.get_node_or_null("plate")
	if an.text == "":
		if plate:
			plate.visible = false
		return
	if plate == null:
		plate = Sprite3D.new()
		plate.name = "plate"
		plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		plate.fixed_size = true
		plate.no_depth_test = true
		plate.render_priority = 10
		plate.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		an.add_child(plate)
	var tw := an.font.get_string_size(an.text, HORIZONTAL_ALIGNMENT_LEFT, -1, an.font_size).x
	plate.texture = CityLayer3D.label_plate(tw + 20.0, float(an.font_size) * 1.55)
	plate.pixel_size = an.pixel_size
	plate.offset = an.offset
	plate.visible = true

## İğne başının ekrandaki yarı boyu (piksel, 1080p)
static func _card_half() -> Vector2:
	return Vector2(COUNTER_W, COUNTER_H) * CARD_PX * PX * 0.5

## Sayının yeri: kartın sağ alt köşesi (bütünlük çizgilerinin üstü); shift = portre takılıyken sağa kayma
static func _label_off(shift: float) -> Vector2:
	return plate_label_off(shift)

## Çok yakında kart dağılır: içindeki tabur türleri ana kartla aynı boy kartlarla (bayrak, resim, sayı), en çok
## COMPOSE_COLS yan yana, satır satır; ızgaranın sol üst kartı ana kartın yerinde
func _set_comp(c: Dictionary, comp: Dictionary, sel := false) -> void:
	if FIGURES:
		return                                        # yakında figür: bileşim kartları hiç görünmez, kurulmaz
	var items: Array = []
	for ty: String in CARD_TYPES:
		if int(comp.get(ty, 0)) > 0:
			items.append([ty, int(comp[ty])])
	var key := str(items) + str(sel)
	if c.get("comp_key", "") == key:
		return
	c["comp_key"] = key
	for sub: Array in c["subs"]:
		(sub[0] as Node).queue_free()
		(sub[1] as Node).queue_free()
	c["subs"] = []
	var n := items.size()
	var ch := _card_half()
	for k in n:
		var row := k / COMPOSE_COLS
		var in_row := mini(n - row * COMPOSE_COLS, COMPOSE_COLS)
		var col := k % COMPOSE_COLS
		# ızgara ana kartın yerinden sağa açılır (solundaki komutan portresine binmez)
		var x := float(col) * (ch.x * 2.0 + 4.0) + float(c.get("cmd_shift", 0.0))
		var y := -float(row) * (ch.y * 2.0 + 4.0)
		var sp := _sprite(_tex_for(c["tag"], 10, 10, sel, items[k][0]), CARD_PX, 10)
		sp.offset = Vector2(x, y) / (CARD_PX * PX)
		c["root"].add_child(sp)
		var l := Label3D.new()
		l.text = str(items[k][1])
		l.font = UiTheme.bold_font()
		l.font_size = 42
		l.outline_size = 2
		l.outline_modulate = Color(0.03, 0.03, 0.03, 0.95)
		l.modulate = Color("f3ead0")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.fixed_size = true
		l.pixel_size = PIXEL * 0.8
		l.no_depth_test = true
		l.render_priority = 12
		l.outline_render_priority = 11
		l.offset = plate_label_off(x) + Vector2(0.0, y) / (PIXEL * 0.8 * PX)
		c["root"].add_child(l)
		sp.visible = false
		l.visible = false
		c["subs"].append([sp, l, x - float(c.get("cmd_shift", 0.0)), y])
	_vis_dirty = true

## Ordu komutanının portresi sayacın üstünde (yan yana sayaçlara binmesin), altın çerçevede (resmi yoksa adının baş harfleri). Yakın zoom'da görünür:
## oyuncu ordusunu haritada komutanının yüzünden tanır.
func _set_portrait(c: Dictionary, cm: Commander) -> void:
	var id := cm.id if cm else 0
	_set_commander_layout(c, id != 0)
	if int(c.get("pcm", 0)) == id:
		return
	c["pcm"] = id
	if cm == null:
		if c.has("pnode"):
			(c["pnode"] as Node3D).visible = false
		return
	if not c.has("pnode"):
		var node := Node3D.new()
		(c["root"] as Node3D).add_child(node)
		var frame := _sprite(_portrait_frame(), 0.0, 13)
		frame.pixel_size = (PORTRAIT_PX + 6.0) / (float(frame.texture.get_height()) * PX)
		frame.offset = _portrait_at() / (frame.pixel_size * PX)
		node.add_child(frame)
		var img := _sprite(null, 0.0, 14)
		node.add_child(img)
		var ini := Label3D.new()
		ini.font = UiTheme.bold_font()
		ini.font_size = 30
		ini.outline_size = 6
		ini.outline_modulate = Color(0, 0, 0, 0.9)
		ini.modulate = UiTheme.ACCENT
		ini.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		ini.fixed_size = true
		ini.pixel_size = PIXEL * 0.8
		ini.offset = _portrait_at() / (ini.pixel_size * PX)
		ini.no_depth_test = true
		ini.render_priority = 15
		ini.outline_render_priority = 14
		node.add_child(ini)
		c["pnode"] = node
		c["pimg"] = img
		c["pini"] = ini
	var tex := _commander_texture(cm)
	var sp: Sprite3D = c["pimg"]
	var ini2: Label3D = c["pini"]
	sp.visible = tex != null
	ini2.visible = tex == null
	if tex:
		sp.texture = tex
		sp.pixel_size = PORTRAIT_PX / (float(tex.get_height()) * PX)
		sp.offset = _portrait_at() / (sp.pixel_size * PX)
	else:
		var parts := cm.name.split(" ", false)
		ini2.text = (parts[0].left(1) + (parts[parts.size() - 1].left(1) if parts.size() > 1 else "")).to_upper()
	(c["pnode"] as Node3D).visible = _was_far == 0 and _names_close

## Portre sayaca bağlı komuta plakasıdır: solunda, dikeyde merkezlenmiş, dar pirinç bağlantı aralığıyla.
static func _portrait_at() -> Vector2:
	var cw := COUNTER_W * CARD_PX * PX
	return Vector2(COMMANDER_BODY_SHIFT - cw * 0.5 - 2.0 - (PORTRAIT_PX + 6.0) * 0.5, 0.0)

## Portre geldiğinde plakayı sağa kaydırıp iki parçayı tek, dengeli işaret gibi birleştir.
func _set_commander_layout(c: Dictionary, attached: bool) -> void:
	var shift := COMMANDER_BODY_SHIFT if attached else 0.0
	if float(c.get("cmd_shift", -1.0)) == shift:
		return                                         # değişmedi (yazı/levha kaydırması ağı yeniden kurar)
	var bg: Sprite3D = c["bg"]
	bg.offset = Vector2(shift, 0.0) / (bg.pixel_size * PX)
	var label: Label3D = c["label"]
	label.offset = _label_off(shift)
	c["cmd_shift"] = shift
	_place_stars(c)
	for sub: Array in c.get("subs", []):
		var x: float = float(sub[2]) + shift
		var y: float = sub[3]
		(sub[0] as Sprite3D).offset = Vector2(x, y) / (CARD_PX * PX)
		(sub[1] as Label3D).offset = plate_label_off(x) + Vector2(0.0, y) / (PIXEL * 0.8 * PX)

func _commander_texture(cm: Commander) -> Texture2D:
	if _ptex.has(cm.id):
		return _ptex[cm.id]
	if not _portrait_loaded:
		_portrait_loaded = true
		var path := "res://data/common/commander_portraits.json"
		if FileAccess.file_exists(path):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary:
				_portrait_map = parsed
	var out: Texture2D = null
	var image_path := str(_portrait_map.get("%s|%s" % [cm.owner, cm.name], ""))
	var src: Texture2D = load(image_path) as Texture2D if image_path != "" and ResourceLoader.exists(image_path) else null
	var img: Image = src.get_image() if src else null
	if img and img.is_compressed():
		img.decompress()
		if img.is_compressed():
			img = null                  # açılamayan sıkıştırma (web): baş harfler gösterilir
	if img:
		# yüz üst tarafta: dikey resmin üstünden kare kırpılır, harita boyuna küçültülür (büyük resim küçük çizilince kumlanır)
		var side := mini(img.get_width(), img.get_height())
		var sq := img.get_region(Rect2i((img.get_width() - side) / 2, int((img.get_height() - side) * 0.2), side, side))
		sq.resize(96, 96, Image.INTERPOLATE_LANCZOS)
		out = ImageTexture.create_from_image(sq)
	_ptex[cm.id] = out
	return out

## Portre çerçevesi: saha plakasıyla eşleşen koyu zemin, pirinç kenar ve kesik köşeler.
func _portrait_frame() -> Texture2D:
	if _pframe:
		return _pframe
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var half := n * 0.5
	var r := 4.0
	for y in n:
		for x in n:
			var qx := absf(float(x) + 0.5 - half) - (half - r)
			var qy := absf(float(y) + 0.5 - half) - (half - r)
			var sd := Vector2(maxf(qx, 0.0), maxf(qy, 0.0)).length() + minf(maxf(qx, qy), 0.0) - r
			if sd > 0.5:
				continue
			var col := Color(0.06, 0.06, 0.05, 0.95)
			if sd > -1.0:
				col = Color(0, 0, 0, 1)
			elif sd > -3.5:
				col = UiTheme.ACCENT
			col.a *= clampf(0.5 - sd, 0.0, 1.0)
			img.set_pixel(x, y, col)
	_pframe = ImageTexture.create_from_image(img)
	return _pframe

# ------------------------------------------------------------------ muharebe işaretleri
func _update_battles() -> void:
	var tex := UiTheme.icon("battle")
	for pid: int in _battle_nodes.keys():
		if not Military.battles.has(pid):
			_battle_nodes[pid].queue_free()
			_battle_nodes.erase(pid)
	for pid: int in Military.battles:
		var b: Dictionary = Military.battles[pid]
		if not _battle_nodes.has(pid):
			var root := Node3D.new()
			add_child(root)
			var s := _sprite(tex, PIXEL * 0.35 * UiTheme.px_scale(tex, 102.0), 13)
			root.add_child(s)
			var l := Label3D.new()
			l.font = UiTheme.bold_font()
			l.font_size = 26
			l.outline_size = 8
			l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			l.fixed_size = true
			l.pixel_size = PIXEL * 0.6
			l.no_depth_test = true
			l.render_priority = 14
			l.outline_render_priority = 13
			l.offset = Vector2(0, -34)
			root.add_child(l)
			_battle_nodes[pid] = root
		var node: Node3D = _battle_nodes[pid]
		var a := World.province(int(b["from"])).center
		var t := World.province(pid).center
		var m := a.lerp(t, 0.6)
		node.position = Vector3(m.x, maxf(map.height_at(m), 0.0) + LIFT + 2.0, m.y)
		var lbl: Label3D = node.get_child(1)
		var att := float(b["att_ratio"])
		var dfn := float(b["def_ratio"])
		lbl.text = "%d%%" % roundi(att / maxf(att + dfn, 0.01) * 100.0)
		var player_att := false
		for d: Division in b["attackers"]:
			if d.owner == World.player_tag or Diplomacy.are_allies(d.owner, World.player_tag):
				player_att = true
		var winning := att > dfn
		lbl.modulate = Color(0.55, 0.95, 0.45) if winning == player_att else Color(1.0, 0.45, 0.35)
	_refresh_combat()

# ------------------------------------------------------------------ seçim
func clear_selection() -> void:
	selected.clear()
	_dirty = true
	_full_refresh = true

## Ekrandaki noktaya en yakın oyuncu sayacı (30 px içinde)
## Uzak zoom: aynı ülkenin yakın sayaçları tek sayaçta birleşir. Harita üstünde sabit ızgara (kaydırınca değişmez),
## yalnız 3 zoom eşiğinde değişir; birleşik sayaç en büyük yığının kendi yerinde durur (kayma / ortalama yok)
const CLUSTER_TIERS := [[800.0, 75.0], [1500.0, 130.0], [2400.0, 210.0]]

func _cluster() -> void:
	var cam := camera as MapCamera3D
	var tier := -1
	if cam:
		for i in CLUSTER_TIERS.size():
			if cam.distance > float(CLUSTER_TIERS[i][0]):
				tier = i
	# gruplar: ızgara hücresi + ülke; lider = en çok tümenli yığın
	var cells := {}
	for key: String in _counters:
		var c: Dictionary = _counters[key]
		c["members"] = [key]
		if tier < 0:
			continue
		var s: float = CLUSTER_TIERS[tier][1]
		# hücre sayacın zoom'dan bağımsız yerinden (kökün yeri yan yana aralığı içerir, zoom'la kayar: kümeler zoom boyunca
		# dağılıp birleşiyor, sayılar yeniden yazılıp kare takılıyordu)
		var rp: Vector3 = (c["root"] as Node3D).position
		var p: Vector2 = c.get("base", Vector2(rp.x, rp.z))
		var ck := "%s:%d:%d" % [c["tag"], floori(p.x / s), floori(p.y / s)]
		if not cells.has(ck):
			cells[ck] = []
		cells[ck].append(key)
	for key: String in _counters:
		var c: Dictionary = _counters[key]
		c["merged"] = false
	for ck: String in cells:
		var keys: Array = cells[ck]
		if keys.size() < 2:
			continue
		keys.sort_custom(func(x: String, y: String) -> bool:
			var nx := (_counters[x]["divs"] as Array).size()
			var ny := (_counters[y]["divs"] as Array).size()
			return nx > ny or (nx == ny and x < y))
		var lead: Dictionary = _counters[keys[0]]
		lead["members"] = keys
		var total := 0
		for k: String in keys:
			total += (_counters[k]["divs"] as Array).size()
			if k != keys[0]:
				_counters[k]["merged"] = true
		lead["cluster_total"] = total
	for key: String in _counters:
		var c: Dictionary = _counters[key]
		c["root"].visible = c.get("base_vis", true) and not c["merged"] and not c.get("deck_hidden", false) \
			and not c.get("tile_merged", false)
	_apply_counts()

## Sayaç yazısı: kendi tümen sayısı; uzakta kümenin lideri kümenin, yakında kapalı destenin çapası destenin toplamı.
## Tek yerde, son değeriyle yazılır: yazı her değişişinde Label3D baştan dizilir (0,25 sn'de bir önce kendi sayısına
## sonra toplama dönen yüzlerce yazı kareyi ~20 ms takıyordu)
func _apply_counts() -> void:
	for key: String in _counters:
		var c: Dictionary = _counters[key]
		var n: int = (c["divs"] as Array).size()
		if _was_far == 0 and int(c.get("deck_n", 0)) > 0:
			n = int(c.get("deck_total", n))
		elif (c.get("members", []) as Array).size() > 1 and not c.get("merged", false):
			n = int(c.get("cluster_total", n))
		c["count"] = n
		if not FIGURES:
			set_count(c["label"], n, 42)                      # figür kipinde levha yazısı hiç görünmez: dizilmez
		elif c.get("fig") != null and int(c.get("fig_n", -1)) != n:
			c["fig_n"] = n
			UnitFigures.set_count(c["fig"], n)                # kaidede ve başın üstünde
		set_count(c["clabel"], n, 30)

## Sayacın temsil ettiği bütün tümenler (birleşik sayaçta grubun tamamı)
func _counter_divs(c: Dictionary) -> Array:
	var mem: Array = c.get("members", [])
	if mem.size() < 2:
		return c["divs"]
	var out: Array = []
	for mk: String in mem:
		out.append_array(_counters[mk]["divs"])
	return out

func pick(screen: Vector2) -> Array:
	var best: Array = []
	var best_d := INF
	for key: String in _counters:
		var c: Dictionary = _counters[key]
		if not c["root"].visible or camera.is_position_behind(c["root"].global_position):
			continue
		var dd := _hit(c, screen)
		if dd < best_d:
			best_d = dd
			best = _counter_divs(c)
	return best

## İmlecin sayaca uzaklığı (ekran pikseli): kartın, rozetin ya da dağılmış ızgaranın dikdörtgeninin içindeyse
## merkezine uzaklık (öne çıkar), dışındaysa INF
func _hit(c: Dictionary, screen: Vector2) -> float:
	var k := get_viewport().get_visible_rect().size.y / 1080.0
	var r := _box(c, camera.unproject_position(c["root"].global_position), k).grow(3.0 * k)
	if not r.has_point(screen):
		return INF
	return screen.distance_to(r.get_center())

## Sayacın ekrandaki dikdörtgeni (sp: kökün ekran konumu, k: ekran yüksekliği / 1080): rozet, kart ya da dağılmış ızgara
func _box(c: Dictionary, sp: Vector2, k: float) -> Rect2:
	var half: Vector2
	var center := sp
	if FIGURES and _was_far == 0 and c.get("fig") != null:
		# figür: kaidenin ortası kökte; ekrandaki boyu haritadaki boyundan (uzaklığa göre)
		var fs := FIG_SIZE * PX / maxf(_cam_dist(c["root"]), 1.0) * k
		return Rect2(sp.x - fs * 0.45, sp.y - fs * 0.8, fs * 0.9, fs * 1.15)
	if _was_far == 1:
		half = Vector2(CHIP_W, CHIP_H) * CHIP_PX * PX * 0.5
	else:
		half = _card_half()
		center.x += float(c.get("cmd_shift", 0.0)) * k
		var subs: Array = c.get("subs", [])
		if _compose and not subs.is_empty():
			var cols := mini(subs.size(), COMPOSE_COLS)
			var rows := (subs.size() + COMPOSE_COLS - 1) / COMPOSE_COLS
			var step := half * 2.0 + Vector2(4.0, 4.0)
			center += Vector2(float(cols - 1) * step.x * 0.5, float(rows - 1) * step.y * 0.5) * k
			half += Vector2(float(cols - 1) * step.x * 0.5, float(rows - 1) * step.y * 0.5)
	return Rect2(center - half * k, half * 2.0 * k)

## Üst üste binme (0,25 sn'de bir, ekran uzayında; yalnız yakında, iğneli kartlarda):
## - ekranda üst üste ya da yan yana gelen dost sayaçlar tek noktada, kart destesi gibi üst üste dizilir: en alttaki
##   (yığının çapası) kendi iğnesinde durur, öbürleri onun üstünde, iğnesiz; yığının sırası korunur, yeni gelen üste biner.
##   Yığına girmek için değmek, çıkmak için belirgin ayrılmak gerekir (titremesin); yürüyen sayaçlar yığına girmez.
## - düşman sayacına binen saldıran sayaç saldırı yönünün tersine geri çekilir (düşmanın içine girmez, berisinde durur).
## Pay kamera uzaklığına bölünerek tutulur (dk_t): zoom'da ekrandaki aralık aynı kalır; _follow_anchors yumuşakça uygular.
const DECLUTTER_CELL := 96.0
const DECLUTTER_DIST := CARD_DIST
const STACK_JOIN := 4.0            ## piksel: bu kadar yaklaşan dost kartlar yığılır
const STACK_KEEP := 30.0           ## piksel: yığındakiler bu kadar ayrılana dek yığında kalır
const GRID_MAX := 9                ## bir noktada en çok bu kadar kart ızgarada; fazlası kapalı deste (üstüne gelince açılır)
## Izgara hücresi i (sütun, sıra yukarı): çapa ortada altta, sonra sağı, solu, bir üst sıranın ortası, sağı, solu...
static func _cell(i: int) -> Vector2i:
	return Vector2i([0, 1, -1][i % 3], i / 3)

## Figür dizilişi: üçer kişilik sıralar, arka sıralar yarım hücre şaşırtmalı (arkadaki öndekilerin arasından görünür,
## ekranda örtüşmez): sıra 0: orta, sağ, sol; sıra 1: sağ yarım, sol yarım, sağ bir buçuk; sıra 2 yine düz...
static func _fig_cell(i: int) -> Vector2:
	var row := i / 3
	var col: float = [0.0, 1.0, -1.0][i % 3] if row % 2 == 0 else [0.5, -0.5, 1.5][i % 3]
	return Vector2(col, float(row))


var _open_decks := {}              ## imleç üstündeyken açık duran destelerin çapa anahtarları
var _stack_seq := 0                ## yığın kimliği sayacı (kartlar yığınlarını ve hücrelerini bununla tanır)


func _team(tag: String) -> String:
	var c: Country = World.countries.get(tag)
	return c.faction if c and c.faction != "" else tag

func _declutter() -> void:
	var cam := camera as MapCamera3D
	if cam == null:
		return
	var cam_d := cam.distance
	var vp := get_viewport().get_visible_rect()
	var kr := vp.size.y / 1080.0
	var screen := vp.grow(200.0 * kr)
	# figür kipinde düzen haritada kurulur (zoom'la değişmez): "ekran" noktası haritanın kuzeyi yukarı sanal düzlemi
	# (FIG_FS harita birimi başına sanal piksel), pay dünya birimi; kartta gerçek ekran, pay kamera uzaklığının katı
	var fig_mode := FIGURES and cam_d <= DECLUTTER_DIST
	var unit := 1.0 if fig_mode else cam_d
	var k := 1.0 if fig_mode else kr
	var fig_fr := UnitFigures.BASE_R * FIG_SIZE * FIG_FS        # kaidenin sanal yarıçapı
	var fig_row := FIG_DEPTH * FIG_SIZE * FIG_FS                 # arka sıra bu kadar geride (öndekinin ardında kalmasın)
	var cell_gap := FIG_CELL_GAP if fig_mode else 8.0            # hücreler arası boşluk (figürde kaideler değmesin)
	var items := {}                                   # anahtar -> [taban, ekran noktası, dikdörtgen, takım, hedef]
	var tgt_xz := Vector2(cam.target.x, cam.target.z)
	for key: String in _counters:
		var c: Dictionary = _counters[key]
		if cam_d > DECLUTTER_DIST:
			c["dk_t"] = Vector3.ZERO
			c["stack_of"] = ""                        # uzakta rozetler yerinde
			continue
		# kapalı destede gizlenen kart da düzene girer (yoksa deste her düzenlemede üyelerini yitirir; desteden çıkan kart
		# gizli kalırdı)
		if not ((c["root"] as Node3D).visible or c.get("deck_hidden", false)) or not c.has("lp") or not c.has("h0"):
			c["dk_t"] = Vector3.ZERO
			continue
		var lp: Vector2 = c["lp"]
		var base := Vector3(lp.x, float(c["h0"]), lp.y)
		var sp := Vector2.ZERO
		if fig_mode:
			# figür düzeni ekrana değil haritaya bağlı: kamera hedefinin çevresinde sabit bir alan (zoom'la ekrandan
			# çıkan figürün yığını dağılmaz); alanın dışındakiler olduğu gibi kalır
			if lp.distance_to(tgt_xz) > FIG_LAYOUT_R:
				continue
		else:
			if cam.is_position_behind(base):
				c["dk_t"] = Vector3.ZERO
				continue
			sp = cam.unproject_position(base)
			if not screen.has_point(sp):
				c["dk_t"] = Vector3.ZERO
				continue
		c["dk_t"] = Vector3.ZERO
		var r: Rect2
		if fig_mode:
			sp = Vector2(base.x, base.z) * FIG_FS
			r = Rect2(sp.x - fig_fr, sp.y + fig_fr - fig_row, fig_fr * 2.0, fig_row)
		else:
			r = _box(c, sp, k)
		if _was_far == 0 and not fig_mode:
			var an: Label3D = c["army"]
			if an.visible and an.text != "":
				# altındaki ad kutusu: kartın altında, yazının genişliğinde (çoğu kez karttan geniş)
				var tw := an.font.get_string_size(an.text, HORIZONTAL_ALIGNMENT_LEFT, -1, an.font_size).x + 20.0
				var nw := tw * an.pixel_size * PX * k
				r = r.merge(Rect2(r.get_center().x - nw * 0.5, r.end.y, nw, 34.0 * k))
			var sh := float(c.get("cmd_shift", 0.0))
			if sh > 0.0:
				r = r.grow_individual(2.0 * sh * k, 0.0, 0.0, 0.0)       # soldaki komutan portresi
			if int(c.get("star_n", 0)) > 0:
				r = r.grow_individual(0.0, (STAR_PX + 3.0) * k, 0.0, 0.0)  # sol üstteki rütbe yıldızları
		var tgt := Vector2.INF
		for d: Division in c["divs"]:
			if d.attacking > 0 and World.province(d.attacking) != null:
				tgt = World.province(d.attacking).center
				break
		items[key] = [base, sp, r, _team(str(c["tag"])), tgt]
	if cam_d > DECLUTTER_DIST:
		return
	# yığınlar: dost ve duran (yürümeyen) kartlar, ekranda değen ya da binenler birleşir (birleşim-bul)
	# yürüyenler yığına girmez: anahtarı yürüyen olan da, sayaçlar yenilenmeden tümenleri yürümeye başlayan da
	var keys: Array = items.keys()
	keys.sort()
	var parent := {}
	for x: String in keys:
		parent[x] = x
	var find := func(x: String) -> String:
		var r0 := x
		while parent[r0] != r0:
			r0 = parent[r0]
		return r0
	var cell := DECLUTTER_CELL * k
	var grid := {}
	for x: String in keys:
		var rx: Rect2 = items[x][2]
		var near_keys := {}
		for g: Vector2i in _grid_cells(rx.grow(STACK_KEEP * k), cell):
			for y: String in grid.get(g, []):
				near_keys[y] = true
		for y: String in near_keys:
			if items[y][3] != items[x][3]:
				continue
			var sx := str(_counters[x].get("stack_of", ""))
			var was: bool = sx != "" and sx == str(_counters[y].get("stack_of", ""))
			var ry: Rect2 = items[y][2]
			# yığına girmek için gerçekten binmek gerekir (küçüğün alanının dörtte biri); yığındakiler belirgin
			# ayrılana dek birlikte kalır
			var joins := rx.grow(STACK_KEEP * k).intersects(ry) if was else rx.intersection(ry).get_area() > 0.25 * minf(rx.get_area(), ry.get_area())
			if joins:
				var a: String = find.call(x)
				var b: String = find.call(y)
				if a != b:
					parent[b] = a
		for g: Vector2i in _grid_cells(rx, cell):
			if not grid.has(g):
				grid[g] = []
			(grid[g] as Array).append(x)
	var order := func(members: Array) -> void:
		# çapa: en uzun süredir yerinde duran (yeni gelen onun yanına geçer, yerleşik kart itilmez); sonra önceki yığın
		# sırası; sonra anahtar
		members.sort_custom(func(a: String, b: String) -> bool:
			var sa := float(_counters[a].get("still_since", 0.0))
			var sb := float(_counters[b].get("still_since", 0.0))
			if absf(sa - sb) > 0.5:
				return sa < sb
			var ia := int(_counters[a].get("stack_i", 999)) if str(_counters[a].get("stack_prev", "")) != "" else 999
			var ib := int(_counters[b].get("stack_i", 999)) if str(_counters[b].get("stack_prev", "")) != "" else 999
			return ia < ib if ia != ib else a < b)
	# yığının ekrandaki alanı: dolu hücrelerin kapladığı dikdörtgen (kalabalıksa kapalı deste: çapa kartı)
	var area := func(members: Array) -> Rect2:
		var ar: Rect2 = items[members[0]][2]
		if members.size() == 1 or members.size() > GRID_MAX:
			return ar
		var w := 0.0
		var h := 0.0
		for x: String in members:
			w = maxf(w, (items[x][2] as Rect2).size.x)
			h = maxf(h, (items[x][2] as Rect2).size.y)
		w += cell_gap * k
		h += cell_gap * k
		var box := ar
		for ci in members.size():
			var gc := _fig_cell(ci) if fig_mode else Vector2(_cell(ci))
			box = box.merge(Rect2(ar.position + Vector2(gc.x * w, -gc.y * h), ar.size))
		return box
	var stacks := {}
	for pass_i in 3:
		stacks = {}
		for x: String in keys:
			var root_key: String = find.call(x)
			if not stacks.has(root_key):
				stacks[root_key] = []
			(stacks[root_key] as Array).append(x)
		# açılan ızgara komşu dost yığına değiyorsa ikisi tek yığın olur (yeniden dizilir)
		var rects := {}
		for rk: String in stacks:
			order.call(stacks[rk])
			rects[rk] = area.call(stacks[rk])
		var joined := false
		var rks: Array = stacks.keys()
		for ai in rks.size():
			for bi in range(ai + 1, rks.size()):
				var ka: String = rks[ai]
				var kb: String = rks[bi]
				if items[ka][3] == items[kb][3] and (rects[ka] as Rect2).grow(2.0 * k).intersects(rects[kb]):
					var fa: String = find.call(ka)
					var fb: String = find.call(kb)
					if fa != fb:
						parent[fb] = fa
						joined = true
		if not joined:
			break
	var placed := {}                                  # yerleşmiş dikdörtgenler (saldıranın geri çekilmesi için)
	for x: String in items:
		_counters[x]["stack_of"] = ""
	# filo ve hava kanadı levhaları yerinde kalır: tümen yığını birine denk gelirse onun hemen üstünden başlar
	var obst: Array[Rect2] = []
	var ph := _card_half() * k
	for layer: Object in obstacles:
		if layer == null or not layer.has_method("pin_roots"):
			continue
		for rn: Node3D in layer.pin_roots():
			if cam.is_position_behind(rn.global_position):
				continue
			var osp := cam.unproject_position(rn.global_position)
			if not screen.has_point(osp):
				continue
			if fig_mode:
				osp = Vector2(rn.global_position.x, rn.global_position.z) * FIG_FS
			obst.append(Rect2(osp - ph, ph * 2.0).grow_individual(0.0, 0.0, 0.0, 26.0 * k))
	var mouse := get_viewport().get_mouse_position()
	# figür kipinde imlecin haritadaki yeri (verilen yükseklikteki düzlemde) sanal düzlemde
	var mouse_at := func(y: float) -> Vector2:
		if not fig_mode:
			return mouse
		var ro := cam.project_ray_origin(mouse)
		var rd := cam.project_ray_normal(mouse)
		if absf(rd.y) < 0.001:
			return Vector2.INF
		var w := ro + rd * ((y - ro.y) / rd.y)
		return Vector2(w.x, w.z) * FIG_FS
	var still_open := {}
	for x: String in items:
		var cx: Dictionary = _counters[x]
		cx["pin"] = true
		cx["deck_hidden"] = false
		cx["deck_n"] = 0
	for root_key: String in stacks:
		var members: Array = stacks[root_key]
		order.call(members)
		var n := members.size()
		var anchor: String = members[0]
		var abase: Vector3 = items[anchor][0]
		var asp: Vector2 = items[anchor][1]
		var ar0: Rect2 = items[anchor][2]
		# üst sıra yönü: iğneli kartta yukarı; yerde duran figürde haritada kuzey (arkadaki sıra)
		var up_dir := Vector3(0.0, 0.0, -1.0) if FIGURES else Vector3.UP
		var ppu := asp.y - cam.unproject_position(abase + up_dir).y           # bir dünya birimi o yönde kaç piksel
		var ppx := cam.unproject_position(abase + Vector3.RIGHT).x - asp.x     # bir dünya birimi sağa kaç piksel
		if fig_mode:
			ppu = FIG_FS
			ppx = FIG_FS
		var lift0 := 0.0
		for o: Rect2 in obst:
			if o.intersects(ar0):
				lift0 = maxf(lift0, ar0.end.y - o.position.y + 3.0 * k)         # filo/kanat levhasının üstünden başla
		for x: String in members:
			_counters[x]["stack_of"] = anchor if n > 1 else ""
		if n == 1:
			var single: Dictionary = _counters[anchor]
			single["stack_i"] = 0
			# yığından yeni çıktıysa ya da yığını dağıldıysa olduğu yerde kalır (geri kaymaz); tümenleri gerçekten
			# yürüyünce bu pay bırakılır (_follow_anchors)
			if str(single.get("stack_prev", "")) != "":
				single["hold"] = single.get("dk", Vector3.ZERO)
			single["dk_t"] = single.get("hold", Vector3.ZERO)
			if lift0 > 0.0 and ppu > 0.01:
				single["dk_t"] = (single["dk_t"] as Vector3) + up_dir * (lift0 / ppu) / unit
			placed[anchor] = Rect2(ar0.position - Vector2(0.0, lift0), ar0.size)
			continue
		var cols := 2 if n <= 4 else 3
		var cw := 0.0                                  # hücre: yığındaki en geniş kart+ad, en yüksek kart+ad
		var ch := 0.0
		for x: String in members:
			cw = maxf(cw, (items[x][2] as Rect2).size.x)
			ch = maxf(ch, (items[x][2] as Rect2).size.y)
		cw += cell_gap * k
		ch += cell_gap * k
		var rows := (n + cols - 1) / cols
		var grid_r := Rect2(asp.x - float(mini(n, cols)) * cw * 0.5, ar0.position.y - lift0 - float(rows - 1) * ch,
			float(mini(n, cols)) * cw, float(rows) * ch)
		# kalabalık yığın kapalı deste olur; imleç üstüne gelince açılır (açıkken ızgaranın üstünde kaldıkça açık kalır)
		var closed := n > GRID_MAX
		if closed:
			var hover := (grid_r if _open_decks.has(anchor) else ar0.grow(16.0 * k)).grow(10.0 * k)
			if hover.has_point(mouse_at.call(abase.y)):
				closed = false
				still_open[anchor] = true
		if closed:
			var lead: Dictionary = _counters[anchor]
			if lift0 > 0.0 and ppu > 0.01:
				lead["dk_t"] = up_dir * (lift0 / ppu) / unit
			lead["deck_n"] = n - 1
			lead["members"] = members.duplicate()                     # tıklayınca destenin hepsi seçilir
			var total := 0
			for x: String in members:
				total += (_counters[x]["divs"] as Array).size()
				if x != anchor:
					_counters[x]["deck_hidden"] = true
					_counters[x]["pin"] = false
			lead["deck_total"] = total
			placed[anchor] = Rect2(ar0.position - Vector2(0.0, lift0), ar0.size).grow_individual(0.0, 16.0 * k, 16.0 * k, 0.0)
			continue
		# ızgara: yığın kurulduğu noktada kalır (yeni yığında çapa kartının gerçek yeri); kartlar çevresinde sabit bir
		# düzende (orta, sağ, sol, üst sıra...). Her kart yığında kaldıkça hücresini korur: biri katılınca ya da ayrılınca,
		# çapa kart gitse bile, öbürleri kaymaz (boşluk kalır). Yığının kimliği ve noktası kartlarda saklanır.
		var sid := 0
		var origin := Vector2(abase.x, abase.z)
		for x: String in members:
			var cx3: Dictionary = _counters[x]
			if int(cx3.get("stack_id", 0)) != 0 and str(cx3.get("stack_prev", "")) != "":
				sid = int(cx3["stack_id"])
				origin = cx3.get("stack_origin", origin)
				break
		if sid == 0:
			_stack_seq += 1
			sid = _stack_seq
		var taken := {}
		var cell_of := {}
		for x: String in members:
			var cx4: Dictionary = _counters[x]
			var pc := int(cx4.get("stack_i", -1))
			if int(cx4.get("stack_id", 0)) == sid and str(cx4.get("stack_prev", "")) != "" and pc >= 0 and not taken.has(pc):
				taken[pc] = x
				cell_of[x] = pc
		if not taken.has(0) and not cell_of.has(anchor) and sid == _stack_seq:
			taken[0] = anchor                       # yeni yığın: çapa ortada, gerçek yerinde
			cell_of[anchor] = 0
		for x: String in members:
			if cell_of.has(x):
				continue
			for ci in range(0, n + 16):
				if not taken.has(ci):
					taken[ci] = x
					cell_of[x] = ci
					break
		var lowest := n + 16
		for x: String in members:
			lowest = mini(lowest, int(cell_of.get(x, 0)))
		var osp := origin * FIG_FS if fig_mode else cam.unproject_position(Vector3(origin.x, abase.y, origin.y))
		for x: String in members:
			var c: Dictionary = _counters[x]
			var base: Vector3 = items[x][0]
			var r: Rect2 = items[x][2]
			var ci: int = cell_of.get(x, 0)
			c["stack_i"] = ci
			c["stack_id"] = sid
			c["stack_origin"] = origin
			var gc := _fig_cell(ci) if fig_mode else Vector2(_cell(ci))
			var sx := gc.x * cw
			var sy := gc.y * ch + lift0
			var off := Vector3(origin.x - base.x, 0.0, origin.y - base.z)
			if absf(ppx) > 0.01:
				off.x += sx / ppx
			if ppu > 0.01:
				off += up_dir * (sy / ppu)
			c["dk_t"] = off / unit
			c["pin"] = ci == lowest                  # iğne en alttaki (ortadaki) kartta
			placed[x] = Rect2(osp + Vector2(sx, -sy) + (r.position - items[x][1]), r.size)
	_open_decks = still_open
	_apply_counts()
	# kapalı destenin öbür kartları gizli (sayıları çapada); _cluster'dan sonra uygulanır
	for x: String in items:
		var cv: Dictionary = _counters[x]
		if cv.get("deck_hidden", false):
			(cv["root"] as Node3D).visible = false
	for x: String in items:
		var cx2: Dictionary = _counters[x]
		var free: bool = str(cx2.get("stack_of", "")) == "" and not stacks.has(x)
		var lead_d: Division = (cx2["divs"] as Array)[0] if not (cx2["divs"] as Array).is_empty() else null
		if free and str(cx2.get("stack_prev", "")) != "" and lead_d and not lead_d.path.is_empty():
			# yürüyen, yığından çıktı: hücresinden yola çıkar, yürüdükçe payı azalır (bacağın sonunda tam yolunda)
			cx2["hold"] = cx2.get("dk", Vector3.ZERO)
			cx2["hold_pid"] = lead_d.province
		if free and cx2.has("hold_pid"):
			if lead_d == null or lead_d.province != int(cx2["hold_pid"]) or lead_d.path.is_empty():
				cx2.erase("hold")
				cx2.erase("hold_pid")
			else:
				var leg := lead_d.progress / maxf(World.distance_km(lead_d.province, lead_d.path[0]), 1.0)
				cx2["dk_t"] = (cx2.get("hold", Vector3.ZERO) as Vector3) * (1.0 - clampf(leg, 0.0, 1.0))
		elif free and str(cx2.get("stack_prev", "")) != "" and cx2.has("hold"):
			cx2["dk_t"] = cx2["hold"]
		cx2["stack_prev"] = cx2.get("stack_of", "")

static func _grid_cells(r: Rect2, cell: float) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for gx in range(floori(r.position.x / cell), floori(r.end.x / cell) + 1):
		for gy in range(floori(r.position.y / cell), floori(r.end.y / cell) + 1):
			out.append(Vector2i(gx, gy))
	return out

static func _grid_hits(grid: Dictionary, r: Rect2, cell: float) -> bool:
	for g: Vector2i in _grid_cells(r, cell):
		for q: Rect2 in grid.get(g, []):
			if q.intersects(r):
				return true
	return false

static func _grid_add(grid: Dictionary, r: Rect2, cell: float) -> void:
	for g: Vector2i in _grid_cells(r, cell):
		if not grid.has(g):
			grid[g] = []
		(grid[g] as Array).append(r)

## Emir hedefi olarak imlecin altındaki sayacın bölgesi (0 = sayaç yok). Sayaçlar haritanın üstünde, şehrin yanında
## durduğu için imlecin altındaki zemin çoğu kez komşu bölgedir: yığına katılmak için sayaca sağ tıklayan oyuncunun
## tümenleri o bölgeye gider. Yalnız seçili tümenlerden oluşan sayaç sayılmaz (kendi yığınına tık zemine gider).
func pick_province(screen: Vector2) -> int:
	var best := 0
	var best_d := INF
	for key: String in _counters:
		var c: Dictionary = _counters[key]
		if not c["root"].visible or camera.is_position_behind(c["root"].global_position):
			continue
		var divs: Array = c["divs"]
		if divs.is_empty() or divs.all(func(d: Division) -> bool: return d in selected):
			continue
		var dd := _hit(c, screen)
		if dd < best_d:
			best_d = dd
			best = (divs[0] as Division).province
	return best

func select_in_rect(rect: Rect2, additive: bool) -> void:
	var previous := selected.duplicate()
	if not additive:
		selected.clear()
	for key: String in _counters:
		var c: Dictionary = _counters[key]
		if c["tag"] != World.player_tag or camera.is_position_behind(c["root"].global_position):
			continue
		if c.get("merged", false):
			continue
		if rect.has_point(camera.unproject_position(c["root"].global_position)):
			for d: Division in _counter_divs(c):
				if not d in selected:
					selected.append(d)
	_selection_audio(previous)
	_dirty = true
	_full_refresh = true

func select_divisions(divs: Array, additive: bool) -> void:
	var previous := selected.duplicate()
	if not additive:
		selected.clear()
	for d: Division in divs:
		if d.owner == World.player_tag and not d in selected:
			selected.append(d)
	_selection_audio(previous)
	_dirty = true
	_full_refresh = true

## Only an actual user selection change has a cue. Programmatic clear/prune stays
## silent so selecting a fleet does not also play a land-unit deselection sound.
func _selection_audio(previous: Array) -> void:
	var added := selected.filter(func(d: Division) -> bool: return not d in previous)
	if not added.is_empty():
		Audio.unit_selection(added)
	elif previous.size() > selected.size():
		Audio.play("unit_deselect", 100)

func prune_selection() -> void:
	selected = selected.filter(func(d: Division) -> bool: return d in Military.divisions)

# ------------------------------------------------------------------ oklar
## Oklar haritaya mürekkeple çizilmiş gibi koyu kızıl (menü arka planındaki harekât okları): hareket biraz açık, taarruz koyu
const ARROW_MOVE := Color(0.52, 0.13, 0.09)
const ARROW_ATTACK := Color(0.45, 0.05, 0.03)

## Hareket okunun rengi (bütün ülkelerde aynı mürekkep kızılı)
static func move_color(_tag: String) -> Color:
	return ARROW_MOVE

## Seçili tümenlerin okları (her karede): tümenin bulunduğu yerden başlar, eğri boyunca sivrilir.
## Seçim, rotalar, başlangıç noktaları, zoom ve savaş/kontrol durumu aynıysa geçen karenin örgüsü kalır
## (duran seçimde her kare eğri + şerit kurmak boşa giderdi; yürürken başlangıç kaydığı için yine her kare kurulur).
var _arrow_sig := 0
var _arrow_div_ver := -1

func _draw_arrows() -> void:
	var cam_d: float = (camera as MapCamera3D).distance if camera is MapCamera3D else 300.0
	_arrows.visible = cam_d < 1250.0
	if _arrow_mat:                                   # (testte katman ağaca eklenmeden çizilir)
		_arrow_mat.set_shader_parameter("zoom_opacity", 1.0 - smoothstep(900.0, 1250.0, cam_d))
	if not _arrows.visible:
		return
	if selected.is_empty():
		if _arrows.mesh != null:
			_arrows.mesh = null
		_arrow_sig = 0
		return
	if Military._div_version != _arrow_div_ver:
		_arrow_div_ver = Military._div_version
		prune_selection()
	var width := clampf(cam_d * 0.015, 1.6, 44.0)
	var sig: Array = [width, World.control_version, Diplomacy.wars.size(), _arrow_div_ver]
	var starts := {}
	for d in selected:
		if d.path.is_empty():
			continue
		var start: Vector2 = World.province(d.province).center
		if models and models.anchors.has(d.id):
			start = models.anchors[d.id][0]
		starts[d.id] = start
		sig.append_array([d.id, d.province, d.path, start])
	var h := sig.hash()
	if h == _arrow_sig:
		return
	_arrow_sig = h
	var im := ImmediateMesh.new()
	var drawn := {}
	var arrows: Array = []
	for d in selected:
		if d.path.is_empty():
			continue
		var key := "%d>%d" % [d.province, d.path[d.path.size() - 1]]
		if drawn.has(key):
			continue
		drawn[key] = true
		var start: Vector2 = starts[d.id]
		# rota tümenin gerçekten yürüdüğü noktalardan geçer: şehir modellerinin yanındaki duruş yeri (sayacın
		# oturduğu yer); bölge merkezinde biten ok, sağ tıklanan sayaca varmıyormuş gibi görünüyordu
		var hostile := false
		for pid in d.path:
			if Diplomacy.are_enemies(World.controller_tag(pid), d.owner):
				hostile = true
		# hareket ülkenin renginde, düşman toprağına taarruz kırmızı
		var cc := ARROW_ATTACK if hostile else move_color(d.owner)
		var cv := walk_line(d) if _walking(d) else _route_line(d, start)   # figürün yürüdüğü yolun kalanı
		var total := 0.0
		for i in cv.size() - 1:
			total += cv[i].distance_to(cv[i + 1])
		if total >= 0.5:                  # varmak üzere olanın şeridi yok (boş yüzey motor hatası verir)
			arrows.append([cv, cc, d.path[d.path.size() - 1]])
	if arrows.is_empty():
		_arrows.mesh = null
		return
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	# önce gölgeler, sonra oklar
	for a: Array in arrows:
		_ribbon(im, a[0], a[1], width, true)            # ok başı: gittiği yön belli olsun
	im.surface_end()
	_arrows.mesh = im

## Tümenin rotası, figürün gerçekten yürüyeceği çizgi (PathMotion.division ile aynı hesap): karada bölge merkezlerinden
## Catmull-Rom (önceki nokta yansıtılır) + çıkış/varış duruş noktası kayması, denizde deniz yolu. İlk bacak tümenin şu
## anki yerinden başlar; ok ile yürüyüş birebir aynı yoldan gider.
func _route_line(d: Division, start: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = [start]
	var chain: Array[int] = [d.province]
	for pid in d.path:
		chain.append(pid)
	var t_now: float = PathMotion.division(d)[4] if d.attacking == 0 else 0.0
	var spots: CityLayer3D = models.cities if models else null
	for i in chain.size() - 1:
		var a: int = chain[i]
		var b: int = chain[i + 1]
		var prev: int = chain[i - 1] if i > 0 else -1
		var nxt: int = chain[i + 2] if i + 2 < chain.size() else -1
		var pa := World.province(a)
		var pb := World.province(b)
		var land := pa.is_land() and pb.is_land()
		var rp := PathMotion.route_points(a, PackedInt32Array([b] if nxt < 0 else [b, nxt]))
		var oa := Vector2.ZERO
		var ob := Vector2.ZERO
		if land and spots:
			oa = spots.unit_spot(a, pa.center) - pa.center
			ob = spots.unit_spot(b, pb.center) - pb.center
		var t0 := t_now if i == 0 else 0.0
		for k in range(1, 11):
			var t := lerpf(t0, 1.0, float(k) / 10.0)
			var p: Vector2
			var sp: Array = [] if land else PathMotion.sea_pose(prev, a, b, nxt, t, out[out.size() - 1])
			if not sp.is_empty():
				p = sp[0]
			else:
				p = PathMotion.sample(rp, t)[0] + oa.lerp(ob, t)
			out.append(p)
	return out

## Catmull-Rom ile yumuşatılmış rota (kesim başına 8 örnek)
func _curve(pts: Array[Vector2]) -> Array[Vector2]:
	if pts.size() < 2:
		return pts
	var out: Array[Vector2] = []
	for i in pts.size() - 1:
		var p0 := pts[i - 1] if i > 0 else pts[i] - (pts[i + 1] - pts[i])
		var p3 := pts[i + 2] if i + 2 < pts.size() else pts[i + 1] + (pts[i + 1] - pts[i])
		for k in 8:
			out.append(PathMotion.catmull(p0, pts[i], pts[i + 1], p3, k / 8.0))
	out.append(pts[pts.size() - 1])
	return out

## Filled cartographic arrow, with a real outline around shaft AND head.
func _ribbon(im: ImmediateMesh, pts: Array[Vector2], col: Color, width: float, _head := true) -> void:
	var shape := preload("res://game/map/order_arrow_shape.gd").contour(pts, width)
	if shape.size() < 3:
		return
	var outline := Geometry2D.offset_polygon(shape, width * 0.055, Geometry2D.JOIN_ROUND)
	for border: PackedVector2Array in outline:
		_arrow_polygon(im, border, Color("21100b"), 0.65, pts)
	_arrow_polygon(im, shape, col, 0.7, pts)

func _arrow_polygon(im: ImmediateMesh, polygon: PackedVector2Array, col: Color, lift: float, route: Array[Vector2]) -> void:
	var indices := Geometry2D.triangulate_polygon(polygon)
	var lengths: Array[float] = [0.0]
	for i in range(1, route.size()):
		lengths.append(lengths.back() + route[i - 1].distance_to(route[i]))
	var progress := PackedFloat32Array()
	for p in polygon:
		var nearest := INF
		var along := 0.0
		for i in range(1, route.size()):
			var delta := route[i] - route[i - 1]
			var t := clampf((p - route[i - 1]).dot(delta) / maxf(delta.length_squared(), 0.001), 0.0, 1.0)
			var distance_squared := p.distance_squared_to(route[i - 1] + delta * t)
			if distance_squared < nearest:
				nearest = distance_squared
				along = lerpf(lengths[i - 1], lengths[i], t)
		progress.append(along / maxf(lengths.back(), 0.001))
	for i in range(0, indices.size(), 3):
		var a := indices[i]
		var b := indices[i + 1]
		var c := indices[i + 2]
		_arrow_terrain_triangle(im, polygon[a], polygon[b], polygon[c], progress[a], progress[b], progress[c], col, lift)

## Split the longest edge until the whole face follows relief, not just its outline.
func _arrow_terrain_triangle(im: ImmediateMesh, a: Vector2, b: Vector2, c: Vector2,
		ua: float, ub: float, uc: float, col: Color, lift: float, depth: int = 0) -> void:
	var ab := a.distance_squared_to(b)
	var bc := b.distance_squared_to(c)
	var ca := c.distance_squared_to(a)
	if maxf(ab, maxf(bc, ca)) > 36.0 and depth < 14:
		if ab >= bc and ab >= ca:
			var m := (a + b) * 0.5
			var um := (ua + ub) * 0.5
			_arrow_terrain_triangle(im, a, m, c, ua, um, uc, col, lift, depth + 1)
			_arrow_terrain_triangle(im, m, b, c, um, ub, uc, col, lift, depth + 1)
		elif bc >= ca:
			var m := (b + c) * 0.5
			var um := (ub + uc) * 0.5
			_arrow_terrain_triangle(im, a, b, m, ua, ub, um, col, lift, depth + 1)
			_arrow_terrain_triangle(im, a, m, c, ua, um, uc, col, lift, depth + 1)
		else:
			var m := (c + a) * 0.5
			var um := (uc + ua) * 0.5
			_arrow_terrain_triangle(im, a, b, m, ua, ub, um, col, lift, depth + 1)
			_arrow_terrain_triangle(im, m, b, c, um, ub, uc, col, lift, depth + 1)
		return
	for vertex: Array in [[a, ua], [b, ub], [c, uc]]:
		var p: Vector2 = vertex[0]
		im.surface_set_color(col)
		im.surface_set_uv(Vector2(vertex[1], 0.0))
		im.surface_add_vertex(Vector3(p.x, maxf(map.height_at(p), 0.0) + lift, p.y))
