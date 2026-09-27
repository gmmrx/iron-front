class_name NotificationFeed
extends VBoxContainer
## Haberler: sağ üstte tarih kutusunun altında (sol paneller ve odak ağacıyla çakışmaz). Savaş/teslim gibi önemli
## haberler büyük manşet olarak çıkar.

const MAX := 3
const LIFE := 7.0
const BIG_LIFE := 9.0

const WIDTH := 372.0          ## tarih kutusuyla aynı hizada ve yakın genişlikte

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	offset_right = -8
	offset_top = 64
	custom_minimum_size.x = WIDTH
	alignment = BoxContainer.ALIGNMENT_BEGIN
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 3)
	World.notification.connect(_add)

## Haber satırı: solda tür rengi çubuğu, küçük tarih, en çok iki satır metin; en yeni üstte, en çok MAX satır
func _add(text: String, kind: String) -> void:
	if not World.in_game:
		return
	var big := kind == "war"
	var col: Color = {"war": Color("e0674f"), "good": UiTheme.GOOD, "bad": Color("e8a45a")}.get(kind, UiTheme.ACCENT)
	var p := PanelContainer.new()
	var sb := UiTheme.skin("strip", 12, 5)
	sb.content_margin_left = 8
	sb.content_margin_right = 10
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.tooltip_text = text
	p.custom_minimum_size.x = WIDTH
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	var bar := ColorRect.new()
	bar.color = col
	bar.custom_minimum_size = Vector2(4, 0)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(bar)
	var date := UiTheme.make_label(GameClock.date_string().get_slice(",", 0), 12, UiTheme.TEXT_DIM)
	date.custom_minimum_size.x = 70
	date.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	date.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	date.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(date)
	var l := UiTheme.make_label(text, 16 if big else 15, col.lightened(0.25) if big else UiTheme.TEXT)
	l.add_theme_font_override("font", UiTheme.bold_font())
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.max_lines_visible = 2
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(l)
	add_child(p)
	move_child(p, 0)          # en yeni en üstte
	while get_child_count() > MAX:
		get_child(get_child_count() - 1).free()
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.25)
	tw.tween_interval(BIG_LIFE if big else LIFE)
	tw.tween_property(p, "modulate:a", 0.0, 1.0)
	tw.tween_callback(p.queue_free)
