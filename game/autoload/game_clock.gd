extends Node
## Oyun saati. Simülasyon saatlik tick'lerle ilerler.

signal hour_passed
## Saatin ikinci yarısı: AI kararları ve günün aşamalı işleri (DAY_STAGE). Sıra her zaman hour_passed → hour_late →
## day_passed → month_passed; oyunda ikinci yarı ayrı bir karede işlenir (bir saatin bütün işi tek karede 30–45 ms
## tutuyordu: hareket + muharebe + AI + günlük iş). Testler ve advance_hours iki yarıyı art arda işler.
signal hour_late
signal day_passed
signal month_passed
signal time_state_changed(speed: int, paused: bool)

const MAX_SPEED := 5
## Hız kademeleri (deneme): 1× = saniyede 5 oyun saati; kademeler 0,1× · 0,2× · 0,3× · 0,5× · 1× — savaş izlenerek
## oynanır. Eski kademeler 1× · 2,4× · 6× · 16× · 48× idi (saniyede 240 saate kadar); gerçekçi yürüyüşle birlikte çok
## hızlı bulundu. Kademeyi değiştirmek için yalnız SPEED_X.
const BASE_HOURS_PER_SECOND := 5.0
const SPEED_X: Array[float] = [0.0, 0.1, 0.2, 0.3, 0.5, 1.0]
const HOURS_PER_SECOND: Array[float] = [0.0, 1.5, 3.0, 4.5, 7.5, 12.0]
const MAX_TICKS_PER_FRAME := 48
## Günlük işler gece yarısı tek karede değil, günün kendi saatinde: bütün sistemlerin günlük işi aynı karede 70–150 ms
## takılma yapıyordu (1 Ekim 2026 ölçümü, Doğu Cephesi 1941, hız 5). Saatler ayrı karelerde işlenir; her 24 saatte her iş
## yine bir kez çalışır (testler ve hızlı simülasyon aynı sonucu alır). Askeriyenin genel işleri de ayrı saatlerde
## (Military._day_stage).
const DAY_STAGE := {"economy": 2, "research": 4, "politics": 6, "diplomacy": 8, "air": 10, "navy": 12,
	"mil_supply": 14, "mil_armies": 16, "mil_reinforce": 18, "mil_airnaval": 20}
const FRAME_BUDGET_USEC := 8000         ## kare başına saat işleme bütçesi (µs): ağır savaşta oyun yavaşlar, kare hızı korunur
const MAX_BACKLOG_HOURS := 24.0
const DAYS_IN_MONTH: Array[int] = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

var year := 1936
var month := 1
var day := 1
var hour := 0
var speed := 1
var paused := true
var utc_offset := 0                 ## oyuncunun başkentinin saat farkı (saat; güneşe göre): saat yerel gösterilir

var _accum := 0.0
var _tick_avg := 1000.0             ## bir oyun saatinin ilk yarısının ortalama işlem süresi (µs)
var _late_avg := 1000.0             ## ikinci yarının ortalama işlem süresi (µs)
var _late_pending := false          ## ilk yarısı işlenmiş, ikinci yarısı bekleyen saat var
var _new_day := false
var _new_month := false
var tick_frame := -1                ## saat işi yapılan son kare (Engine.get_process_frames): yan yana ateş o kareye binmez
var prof := {}        ## sistem -> mikrosaniye (profil)

func timed(key: String, t0: int) -> void:
	prof[key] = int(prof.get(key, 0)) + Time.get_ticks_usec() - t0

func reset() -> void:
	year = 1936
	month = 1
	day = 1
	hour = 0
	utc_offset = 0
	speed = 1
	paused = true
	_accum = 0.0
	_late_pending = false
	_new_day = false
	_new_month = false

## Görsel ara değer: bir sonraki saatlik tick'e ne kadar kaldı (0..1); duraklatılmışken sabit
func hour_fraction() -> float:
	return clampf(_accum, 0.0, 0.999)

## Oyun saati / gerçek saniye (duraklatılmışken 0)
func hours_per_second() -> float:
	return 0.0 if paused else HOURS_PER_SECOND[speed]

## Hızlı simülasyon (test / geliştirici): n saat ilerlet
func advance_hours(n: int) -> void:
	for i in n:
		_advance_hour()
		Military.flush_skirmish()        # kare akmıyor: yan yana ateş her saat hemen (oyunda bir sonraki karede)

func _process(delta: float) -> void:
	if paused:
		return
	var t0 := Time.get_ticks_usec()
	_accum += delta * HOURS_PER_SECOND[speed]
	var ticks := 0
	# saat birikmiyorsa karede tek adım (saatin bir yarısı): iş karelere yayılır (5× hızda saat başına ~8 kare var).
	# Geride kalınca kare bütçesi: adımlar bu süre dolana kadar işlenir, kalanı sonraki karelere kalır (biriken en çok
	# 24 saat). Makine yetişemezse oyun gerçek hızından biraz yavaş akar ama kare hızı düşmez.
	var keep_up := _accum < 2.0
	while ticks < MAX_TICKS_PER_FRAME:
		if ticks > 0 and keep_up:
			break
		# bir sonraki adım bütçeyi aşacaksa (son adımların ortalamasına göre) sonraki kareye kalır; her karede en az bir adım
		var el := Time.get_ticks_usec() - t0
		var ts := Time.get_ticks_usec()
		if _late_pending:
			if ticks > 0 and el + int(_late_avg) > FRAME_BUDGET_USEC:
				break
			ticks += 1
			_finish_hour()
			_late_avg = lerpf(_late_avg, float(Time.get_ticks_usec() - ts), 0.1)
			continue
		if _accum < 1.0 or (ticks > 0 and el + int(_tick_avg) > FRAME_BUDGET_USEC):
			break
		_accum -= 1.0
		ticks += 1
		_begin_hour()
		_tick_avg = lerpf(_tick_avg, float(Time.get_ticks_usec() - ts), 0.1)
	if ticks > 0:
		tick_frame = Engine.get_process_frames()
	_accum = minf(_accum, MAX_BACKLOG_HOURS)
	timed("clock_total", t0)

## Bütün saat (iki yarı art arda): testler ve hızlı simülasyon
func _advance_hour() -> void:
	if _late_pending:
		_finish_hour()
	_begin_hour()
	_finish_hour()

## Oyunda yarım kalmış saat varsa bitir (duraklatma, kayıt: bekleyen AI/günlük iş atlanmasın)
func flush_hour() -> void:
	if _late_pending:
		_finish_hour()

func _begin_hour() -> void:
	hour += 1
	if hour >= 24:
		hour = 0
		day += 1
		_new_day = true
		if day > days_in_month(year, month):
			day = 1
			month += 1
			_new_month = true
			if month > 12:
				month = 1
				year += 1
	_late_pending = true
	hour_passed.emit()

func _finish_hour() -> void:
	_late_pending = false
	var nd := _new_day
	var nm := _new_month
	_new_day = false
	_new_month = false
	hour_late.emit()
	if nd:
		day_passed.emit()
	if nm:
		month_passed.emit()

static func days_in_month(y: int, m: int) -> int:
	if m == 2 and (y % 4 == 0 and (y % 100 != 0 or y % 400 == 0)):
		return 29
	return DAYS_IN_MONTH[m - 1]

func set_speed(s: int) -> void:
	speed = clampi(s, 1, MAX_SPEED)
	time_state_changed.emit(speed, paused)

func change_speed(delta_speed: int) -> void:
	set_speed(speed + delta_speed)

func set_paused(p: bool) -> void:
	if p:
		flush_hour()
	paused = p
	time_state_changed.emit(speed, paused)

func toggle_pause() -> void:
	set_paused(not paused)

## Tarih ve saat oyuncunun yerel saatinde (saat içeride UTC; gün dönümü yerel saate göre kayar)
func date_string() -> String:
	var lh := hour + utc_offset
	var d := day
	var m := month
	var y := year
	if lh >= 24:
		lh -= 24
		d += 1
		if d > days_in_month(y, m):
			d = 1
			m += 1
			if m > 12:
				m = 1
				y += 1
	elif lh < 0:
		lh += 24
		d -= 1
		if d < 1:
			m -= 1
			if m < 1:
				m = 12
				y -= 1
			d = days_in_month(y, m)
	return "%d %s %d, %02d:00" % [d, tr("MONTH_%d" % m), y, lh]

## Yeni oyun: saat farkı oyuncunun başkentinin boylamından (15° = 1 saat); oyun orada START_HOUR'da başlar
const START_HOUR := 7
func start_at_local_morning(lon: float) -> void:
	utc_offset = roundi(lon / 15.0)
	hour = posmod(START_HOUR - utc_offset, 24)

# ------------------------------------------------------------------ gece ve gündüz
## Güneşin tam tepede olduğu nokta (boylam, enlem; derece). doy: yılın günü (kesirli), utc: saat (kesirli). Saat UTC:
## Greenwich 12:00'de öğle. Eğim: yıllık kosinüs (23,44°), zaman denklemi yok (en çok ~16 dk fark)
static func subsolar(doy: float, utc: float) -> Vector2:
	var dec := -23.44 * cos(TAU / 365.0 * (doy + 10.0))
	var lon := fposmod(180.0 - utc * 15.0 + 180.0, 360.0) - 180.0
	return Vector2(lon, dec)

## Güneş yüksekliğinin sinüsü (−1..1) bir noktada (boylam, enlem; derece)
static func sun_height(ll: Vector2, sub: Vector2) -> float:
	var la := deg_to_rad(ll.y)
	var de := deg_to_rad(sub.y)
	return sin(la) * sin(de) + cos(la) * cos(de) * cos(deg_to_rad(ll.x - sub.x))

## Gecenin payı (0 gündüz, 1 tam gece): güneş ufkun ~6° altından ~3° üstüne kadar geçiş (alacakaranlık)
static func night_of(h: float) -> float:
	return 1.0 - smoothstep(-0.10, 0.06, h)

func day_of_year() -> float:
	var d := float(day)
	for i in month - 1:
		d += DAYS_IN_MONTH[i]
	return d

## Şu anki saatin güneşi (oyun kuralları için: tam saat, kare hızından bağımsız)
func sun_now() -> Vector2:
	return subsolar(day_of_year() + hour / 24.0, float(hour))

## Harita noktasında gecenin payı (0..1); bölge ölçekli harita olmayan (Miller değil) haritada hep gündüz
func night_at(map_pos: Vector2) -> float:
	if not World._miller:
		return 0.0
	return night_of(sun_height(World.lonlat(map_pos), sun_now()))
