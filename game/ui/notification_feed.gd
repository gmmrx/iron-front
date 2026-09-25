class_name NotificationFeed
extends VBoxContainer
## Haberler: sağ üstte tarih kutusunun altında (sol paneller ve odak ağacıyla çakışmaz). Savaş/teslim gibi önemli
## haberler büyük manşet olarak çıkar.

const MAX := 4
const LIFE := 7.0
const BIG_LIFE := 9.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	offset_right = -10
	offset_top = 62
	custom_minimum_size.x = 440
	alignment = BoxContainer.ALIGNMENT_BEGIN
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 6)
	World.notification.connect(_add)

func _add(text: String, kind: String) -> void:
	if not World.in_game:
		return
	var big := kind == "war"
	var p := PanelContainer.new()
	var sb := UiTheme.textured("panel" if big else "tooltip", 14 if big else 10, 12 if big else 8)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_horizontal = Control.SIZE_SHRINK_END
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	var col: Color = {"war": Color("f0a090"), "good": UiTheme.GOOD, "bad": Color("e8a45a")}.get(kind, UiTheme.TEXT)
	var date := UiTheme.make_label(GameClock.date_string().get_slice(",", 0).to_upper(), 13 if not big else 14, UiTheme.TEXT_DIM)
	date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(date)
	var l := UiTheme.make_label(text, 20 if big else 16, col)
	l.add_theme_font_override("font", UiTheme.bold_font())
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 400
	v.add_child(l)
	add_child(p)
	move_child(p, 0)          # en yeni en üstte
	while get_child_count() > MAX:
		get_child(get_child_count() - 1).free()
	p.modulate.a = 0.0
	p.pivot_offset = Vector2(440, 0)
	p.scale = Vector2(0.92, 0.92)
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.25)
	tw.parallel().tween_property(p, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(BIG_LIFE if big else LIFE)
	tw.tween_property(p, "modulate:a", 0.0, 1.0)
	tw.tween_callback(p.queue_free)
