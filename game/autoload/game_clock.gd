extends Node
## Oyun saati. Simülasyon saatlik tick'lerle ilerler.

signal hour_passed
signal day_passed
signal month_passed
signal time_state_changed(speed: int, paused: bool)

const MAX_SPEED := 5
const HOURS_PER_SECOND: Array[float] = [0.0, 5.0, 12.0, 30.0, 80.0, 240.0]
const MAX_TICKS_PER_FRAME := 48
const FRAME_BUDGET_USEC := 8000         ## kare başına saat işleme bütçesi (µs): ağır savaşta oyun yavaşlar, kare hızı korunur
const MAX_BACKLOG_HOURS := 24.0
const DAYS_IN_MONTH: Array[int] = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

var year := 1936
var month := 1
var day := 1
var hour := 0
var speed := 1
var paused := true

var _accum := 0.0
var _tick_avg := 1000.0             ## bir oyun saatinin ortalama işlem süresi (µs)
var prof := {}        ## sistem -> mikrosaniye (profil)

func timed(key: String, t0: int) -> void:
	prof[key] = int(prof.get(key, 0)) + Time.get_ticks_usec() - t0

func reset() -> void:
	year = 1936
	month = 1
	day = 1
	hour = 0
	speed = 1
	paused = true
	_accum = 0.0

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

func _process(delta: float) -> void:
	if paused:
		return
	var t0 := Time.get_ticks_usec()
	_accum += delta * HOURS_PER_SECOND[speed]
	var ticks := 0
	# kare bütçesi: saatler bu süre dolana kadar işlenir, kalanı sonraki karelere kalır (biriken en çok 24 saat).
	# Makine yetişemezse oyun gerçek hızından biraz yavaş akar ama kare hızı düşmez (5× hızda kareler donuyordu).
	while _accum >= 1.0 and ticks < MAX_TICKS_PER_FRAME:
		# bir sonraki saat bütçeyi aşacaksa (son saatlerin ortalamasına göre) sonraki kareye kalır; her karede en az bir saat
		var el := Time.get_ticks_usec() - t0
		if ticks > 0 and el + int(_tick_avg) > FRAME_BUDGET_USEC:
			break
		_accum -= 1.0
		ticks += 1
		var ts := Time.get_ticks_usec()
		_advance_hour()
		_tick_avg = lerpf(_tick_avg, float(Time.get_ticks_usec() - ts), 0.1)
	_accum = minf(_accum, MAX_BACKLOG_HOURS)
	timed("clock_total", t0)

func _advance_hour() -> void:
	hour += 1
	var new_day := false
	var new_month := false
	if hour >= 24:
		hour = 0
		day += 1
		new_day = true
		if day > days_in_month(year, month):
			day = 1
			month += 1
			new_month = true
			if month > 12:
				month = 1
				year += 1
	hour_passed.emit()
	if new_day:
		day_passed.emit()
	if new_month:
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
	paused = p
	time_state_changed.emit(speed, paused)

func toggle_pause() -> void:
	set_paused(not paused)

func date_string() -> String:
	return "%d %s %d, %02d:00" % [day, tr("MONTH_%d" % month), year, hour]
