class_name DragScroll
extends Node
## Kaydırma çubuğu olmadan kaydırma: panelin boş bir yerinde sol tuşu basılı tutup sürükleyince içerik kayar
## (tekerlek de çalışır). Düğmelerin üstünde basınca sürükleme başlamaz, düğme normal çalışır. Sürükleme sırasındaki
## fare hareketleri tüketilir: harita kıpırdamaz. ScrollContainer'ın çocuğu olarak eklenir: DragScroll.attach(scroll).
## smooth: tekerlek / dokunmatik yüzey kaydırması yavaşlayarak hedefe süzülür, bırakılan sürükleme bir süre kayıp
## yavaşça durur; scroll_to(nokta) aynı yumuşaklıkla oraya götürür (araştırma zaman çizelgesi).

const THRESHOLD := 6.0
const WHEEL_STEP := 120.0           ## tekerleğin bir çentiği (piksel)
const EASE := 12.0                  ## süzülme sertliği: her saniye kalan yolun ~%99'u (1 − e^−12) kapanır
const GLIDE_DECAY := 4.5            ## bırakılan sürüklemenin hızı saniyede e^−4.5 katına düşer
const PAN_SCALE := 24.0             ## dokunmatik yüzey kaydırma hareketi → piksel

var scroll: ScrollContainer
var smooth := false
var _armed := false
var _dragging := false
var _start := Vector2.ZERO
var _pos := Vector2.ZERO            ## yumuşak kipte gerçek (kesirli) konum
var _target := Vector2.ZERO
var _velocity := Vector2.ZERO       ## bırakılan sürüklemenin süzülme hızı (piksel/sn)
var _last_motion := 0

static func attach(sc: ScrollContainer, horizontal := false, smooth_scroll := false) -> DragScroll:
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	if horizontal:
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	var d := DragScroll.new()
	d.scroll = sc
	d.smooth = smooth_scroll
	d.set_process(smooth_scroll)
	sc.add_child(d)
	return d

## Yumuşak kipte hedefe süzül (dışarıdan: kartı görünür yap, en başa dön...). Kip kapalıysa hemen gider
func scroll_to(point: Vector2) -> void:
	if not smooth:
		scroll.scroll_horizontal = int(point.x)
		scroll.scroll_vertical = int(point.y)
		return
	_sync_from_scroll()
	_velocity = Vector2.ZERO
	_target = _clamp(point)

## Hedef ve konum anında ayarlanır (yeniden kurulan içerikte eski konumu korumak için)
func jump_to(point: Vector2) -> void:
	_velocity = Vector2.ZERO
	_target = _clamp(point)
	_pos = _target
	scroll.scroll_horizontal = int(round(_pos.x))
	scroll.scroll_vertical = int(round(_pos.y))

func target() -> Vector2:
	return _target if smooth else Vector2(scroll.scroll_horizontal, scroll.scroll_vertical)

func _max_scroll() -> Vector2:
	var child: Control = null
	for c in scroll.get_children():
		if c is Control and not c is ScrollBar:
			child = c
			break
	if child == null:
		return Vector2.ZERO
	return (child.get_combined_minimum_size().max(child.size) - scroll.size).max(Vector2.ZERO)

func _clamp(p: Vector2) -> Vector2:
	return p.clamp(Vector2.ZERO, _max_scroll())

## Biri (ScrollContainer kendisi, odak takibi) konumu değiştirdiyse yumuşak durum oradan sürer
func _sync_from_scroll() -> void:
	var now := Vector2(scroll.scroll_horizontal, scroll.scroll_vertical)
	if now.distance_to(_pos) > 1.5:
		_pos = now
		_target = now

func _process(delta: float) -> void:
	if scroll == null or not scroll.is_visible_in_tree():
		return
	_sync_from_scroll()
	if not _dragging and _velocity.length_squared() > 1.0:
		_target = _clamp(_target + _velocity * delta)
		_velocity *= exp(-GLIDE_DECAY * delta)
	if _pos.distance_squared_to(_target) < 0.25:
		_pos = _target
	else:
		_pos = _pos.lerp(_target, 1.0 - exp(-EASE * delta))
	scroll.scroll_horizontal = int(round(_pos.x))
	scroll.scroll_vertical = int(round(_pos.y))

func _input(event: InputEvent) -> void:
	if scroll == null or not scroll.is_visible_in_tree():
		_armed = false
		_dragging = false
		return
	if smooth and _wheel(event):
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if scroll.get_global_rect().has_point(mb.position) and not _over_button():
				_armed = true
				_dragging = false
				_start = mb.position
				_velocity = Vector2.ZERO
		else:
			if _dragging:
				scroll.get_viewport().set_input_as_handled()
				Input.set_default_cursor_shape(Input.CURSOR_ARROW)
				if smooth and Time.get_ticks_msec() - _last_motion > 80:
					_velocity = Vector2.ZERO          # durup bıraktıysa süzülmez
			_armed = false
			_dragging = false
	elif event is InputEventMouseMotion and _armed:
		var mm := event as InputEventMouseMotion
		if not (mm.button_mask & MOUSE_BUTTON_MASK_LEFT):
			_armed = false
			_dragging = false
			return
		if not _dragging and mm.position.distance_to(_start) > THRESHOLD:
			_dragging = true
		if _dragging:
			if smooth:
				_sync_from_scroll()
				_target = _clamp(_target - mm.relative)
				_pos = _target                   # sürüklerken içerik parmağın altında kalır
				_velocity = _velocity.lerp(-mm.velocity, 0.5)
				_last_motion = Time.get_ticks_msec()
				scroll.scroll_horizontal = int(round(_pos.x))
				scroll.scroll_vertical = int(round(_pos.y))
			else:
				scroll.scroll_horizontal -= int(round(mm.relative.x))
				scroll.scroll_vertical -= int(round(mm.relative.y))
			Input.set_default_cursor_shape(Input.CURSOR_DRAG)
			scroll.get_viewport().set_input_as_handled()

## Yumuşak kipte tekerlek (Shift ile yana) ve dokunmatik yüzey: hedef ilerler, konum ona süzülür
func _wheel(event: InputEvent) -> bool:
	var at := Vector2.ZERO
	var step := Vector2.ZERO
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb := event as InputEventMouseButton
		at = mb.position
		var f := mb.factor if mb.factor > 0.0 else 1.0
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP: step = Vector2(0, -WHEEL_STEP * f)
			MOUSE_BUTTON_WHEEL_DOWN: step = Vector2(0, WHEEL_STEP * f)
			MOUSE_BUTTON_WHEEL_LEFT: step = Vector2(-WHEEL_STEP * f, 0)
			MOUSE_BUTTON_WHEEL_RIGHT: step = Vector2(WHEEL_STEP * f, 0)
			_: return false
		if mb.shift_pressed:
			step = Vector2(step.y, step.x)
	elif event is InputEventPanGesture:
		var pg := event as InputEventPanGesture
		at = pg.position
		step = pg.delta * PAN_SCALE
	else:
		return false
	if not scroll.get_global_rect().has_point(at):
		return false
	_sync_from_scroll()
	_velocity = Vector2.ZERO
	_target = _clamp(_target + step)
	scroll.get_viewport().set_input_as_handled()
	return true

func _over_button() -> bool:
	var c := scroll.get_viewport().gui_get_hovered_control()
	while c != null and c != scroll:
		if c is BaseButton or c is Slider or c is LineEdit:
			return true
		c = c.get_parent() as Control
	return false
