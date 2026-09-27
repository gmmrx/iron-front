class_name DragScroll
extends Node
## Kaydırma çubuğu olmadan kaydırma: panelin boş bir yerinde sol tuşu basılı tutup sürükleyince içerik kayar
## (tekerlek de çalışır). Düğmelerin üstünde basınca sürükleme başlamaz, düğme normal çalışır. Sürükleme sırasındaki
## fare hareketleri tüketilir: harita kıpırdamaz. ScrollContainer'ın çocuğu olarak eklenir: DragScroll.attach(scroll).

const THRESHOLD := 6.0

var scroll: ScrollContainer
var _armed := false
var _dragging := false
var _start := Vector2.ZERO

static func attach(sc: ScrollContainer, horizontal := false) -> DragScroll:
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	if horizontal:
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	var d := DragScroll.new()
	d.scroll = sc
	sc.add_child(d)
	return d

func _input(event: InputEvent) -> void:
	if scroll == null or not scroll.is_visible_in_tree():
		_armed = false
		_dragging = false
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if scroll.get_global_rect().has_point(mb.position) and not _over_button():
				_armed = true
				_dragging = false
				_start = mb.position
		else:
			if _dragging:
				scroll.get_viewport().set_input_as_handled()
				Input.set_default_cursor_shape(Input.CURSOR_ARROW)
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
			scroll.scroll_horizontal -= int(round(mm.relative.x))
			scroll.scroll_vertical -= int(round(mm.relative.y))
			Input.set_default_cursor_shape(Input.CURSOR_DRAG)
			scroll.get_viewport().set_input_as_handled()

func _over_button() -> bool:
	var c := scroll.get_viewport().gui_get_hovered_control()
	while c != null and c != scroll:
		if c is BaseButton or c is Slider or c is LineEdit:
			return true
		c = c.get_parent() as Control
	return false
