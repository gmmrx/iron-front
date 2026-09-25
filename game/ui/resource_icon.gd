class_name ResourceIcon
extends Control
## Vektörel küçük ikonlar (ikon atlası gelene kadar).

enum Kind { POLITICAL_POWER, STABILITY, WAR_SUPPORT, MANPOWER, FACTORY, FUEL }

var kind: Kind

func _init(k: Kind = Kind.POLITICAL_POWER) -> void:
	kind = k
	custom_minimum_size = Vector2(34, 34)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

const FILES := {Kind.POLITICAL_POWER: "political_power", Kind.STABILITY: "stability",
	Kind.WAR_SUPPORT: "war_support", Kind.MANPOWER: "manpower", Kind.FACTORY: "factory"}

func _draw() -> void:
	var tex := UiTheme.icon(FILES.get(kind, ""))
	if tex:
		draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)
		return
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.46
	draw_circle(c, r, Color(0, 0, 0, 0.5))
	draw_arc(c, r, 0, TAU, 32, UiTheme.BORDER, 1.5, true)
	match kind:
		Kind.POLITICAL_POWER:
			draw_colored_polygon(FlagFactory._star(c, r * 0.72, r * 0.3), UiTheme.ACCENT)
		Kind.STABILITY:
			draw_arc(c, r * 0.55, PI, TAU, 16, Color("7fb0d9"), 2.5, true)
			draw_line(c + Vector2(0, -r * 0.1), c + Vector2(0, r * 0.55), Color("7fb0d9"), 2.5, true)
			draw_circle(c + Vector2(0, -r * 0.1), r * 0.16, Color("7fb0d9"))
		Kind.WAR_SUPPORT:
			var col := Color("e07a5f")
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.55, r * 0.1), c + Vector2(0, -r * 0.5), c + Vector2(r * 0.55, r * 0.1), c + Vector2(r * 0.55, r * 0.35), c + Vector2(0, -r * 0.2), c + Vector2(-r * 0.55, r * 0.35)]), col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.55, r * 0.45), c + Vector2(0, -r * 0.05), c + Vector2(r * 0.55, r * 0.45), c + Vector2(r * 0.55, r * 0.7), c + Vector2(0, r * 0.25), c + Vector2(-r * 0.55, r * 0.7)]), col)
		Kind.FACTORY:
			var col := Color("d8c9a0")
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.6, r * 0.55), c + Vector2(-r * 0.6, -r * 0.05), c + Vector2(-r * 0.25, -r * 0.3), c + Vector2(-r * 0.25, -r * 0.05), c + Vector2(r * 0.1, -r * 0.3), c + Vector2(r * 0.1, -r * 0.05), c + Vector2(r * 0.3, -r * 0.05), c + Vector2(r * 0.3, -r * 0.62), c + Vector2(r * 0.5, -r * 0.62), c + Vector2(r * 0.5, -r * 0.05), c + Vector2(r * 0.6, -r * 0.05), c + Vector2(r * 0.6, r * 0.55)]), col)
		Kind.FUEL:
			# yakıt damlası
			var col := Color("e0a040")
			var pts := PackedVector2Array()
			for i in 20:
				var a := PI * 0.5 + (float(i) / 19.0 - 0.5) * PI * 1.6
				pts.append(c + Vector2(cos(a), sin(a)) * r * 0.42 + Vector2(0, r * 0.12))
			pts.append(c + Vector2(0, -r * 0.62))
			draw_colored_polygon(pts, col)
		Kind.MANPOWER:
			var col := Color("9ccf85")
			draw_circle(c + Vector2(0, -r * 0.3), r * 0.24, col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.5, r * 0.6), c + Vector2(-r * 0.35, r * 0.05), c + Vector2(r * 0.35, r * 0.05), c + Vector2(r * 0.5, r * 0.6)]), col)
