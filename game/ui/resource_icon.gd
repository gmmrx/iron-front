class_name ResourceIcon
extends Control
## Vektörel küçük ikonlar (ikon atlası gelene kadar).

enum Kind { POLITICAL_POWER, STABILITY, WAR_SUPPORT, MANPOWER, FACTORY, FUEL, CONVOY, SUPPLY, COMMAND, XP_ARMY, XP_NAVY, XP_AIR, TENSION, WAR }

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
		Kind.CONVOY:
			# yük gemisi silueti
			var col := Color("b8c4d0")
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.62, r * 0.15), c + Vector2(r * 0.62, r * 0.15), c + Vector2(r * 0.45, r * 0.5), c + Vector2(-r * 0.5, r * 0.5)]), col)
			draw_rect(Rect2(c + Vector2(-r * 0.15, -r * 0.3), Vector2(r * 0.3, r * 0.45)), col)
			draw_rect(Rect2(c + Vector2(-r * 0.05, -r * 0.55), Vector2(r * 0.1, r * 0.25)), col)
		Kind.SUPPLY:
			# sandık + ok (ikmal)
			var col := Color("d0b07a")
			draw_rect(Rect2(c + Vector2(-r * 0.5, -r * 0.1), Vector2(r * 1.0, r * 0.6)), col)
			draw_line(c + Vector2(0, -r * 0.1), c + Vector2(0, r * 0.5), Color(0, 0, 0, 0.6), 2.0)
			draw_line(c + Vector2(-r * 0.5, r * 0.2), c + Vector2(r * 0.5, r * 0.2), Color(0, 0, 0, 0.6), 2.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.25, -r * 0.3), c + Vector2(0, -r * 0.62), c + Vector2(r * 0.25, -r * 0.3)]), col)
		Kind.COMMAND:
			# komuta: general yıldızı üstünde şerit
			var col := Color("e6c15a")
			draw_colored_polygon(FlagFactory._star(c + Vector2(0, -r * 0.1), r * 0.55, r * 0.23), col)
			draw_rect(Rect2(c + Vector2(-r * 0.5, r * 0.4), Vector2(r * 1.0, r * 0.14)), col)
		Kind.XP_ARMY:
			var col := Color("9ccf85")
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.55, r * 0.45), c + Vector2(r * 0.55, r * 0.45), c + Vector2(r * 0.55, r * 0.2), c + Vector2(-r * 0.55, r * 0.2)]), col)
			draw_line(c + Vector2(-r * 0.5, r * 0.2), c + Vector2(r * 0.5, -r * 0.55), col, 2.5, true)   # tüfek
		Kind.XP_NAVY:
			var col := Color("7fb0d9")
			draw_arc(c + Vector2(0, -r * 0.05), r * 0.5, 0.0, PI, 16, col, 2.5, true)
			draw_line(c + Vector2(0, -r * 0.55), c + Vector2(0, r * 0.45), col, 2.5, true)
			draw_line(c + Vector2(-r * 0.3, -r * 0.35), c + Vector2(r * 0.3, -r * 0.35), col, 2.5, true)   # çapa
		Kind.XP_AIR:
			var col := Color("d9d9d9")
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 0.6), c + Vector2(r * 0.14, -r * 0.1), c + Vector2(r * 0.62, r * 0.15), c + Vector2(r * 0.14, r * 0.12), c + Vector2(r * 0.1, r * 0.5), c + Vector2(r * 0.25, r * 0.6), c + Vector2(-r * 0.25, r * 0.6), c + Vector2(-r * 0.1, r * 0.5), c + Vector2(-r * 0.14, r * 0.12), c + Vector2(-r * 0.62, r * 0.15), c + Vector2(-r * 0.14, -r * 0.1)]), col)
		Kind.TENSION:
			# dünya küresi
			var col := Color("c9c2b0")
			draw_arc(c, r * 0.58, 0, TAU, 24, col, 2.0, true)
			draw_arc(c, r * 0.58, 0, TAU, 24, col, 1.0, true)
			draw_line(c + Vector2(-r * 0.58, 0), c + Vector2(r * 0.58, 0), col, 1.5, true)
			draw_line(c + Vector2(0, -r * 0.58), c + Vector2(0, r * 0.58), col, 1.5, true)
			draw_arc(c, r * 0.58, PI * 0.5, PI * 1.5, 16, col, 1.5, true)
			var pts := PackedVector2Array()
			for i in 17:
				var t := float(i) / 16.0
				var y := -r * 0.58 + t * r * 1.16
				pts.append(c + Vector2(cos(asin(clampf(y / (r * 0.58), -1, 1))) * r * 0.28, y))
			draw_polyline(pts, col, 1.2, true)
		Kind.WAR:
			# çapraz kılıçlar
			var col := Color("e0674f")
			draw_line(c + Vector2(-r * 0.55, -r * 0.55), c + Vector2(r * 0.55, r * 0.55), col, 2.5, true)
			draw_line(c + Vector2(r * 0.55, -r * 0.55), c + Vector2(-r * 0.55, r * 0.55), col, 2.5, true)
			draw_line(c + Vector2(-r * 0.3, r * 0.15), c + Vector2(-r * 0.15, r * 0.3), col, 3.0, true)
			draw_line(c + Vector2(r * 0.3, r * 0.15), c + Vector2(r * 0.15, r * 0.3), col, 3.0, true)
		Kind.MANPOWER:
			var col := Color("9ccf85")
			draw_circle(c + Vector2(0, -r * 0.3), r * 0.24, col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.5, r * 0.6), c + Vector2(-r * 0.35, r * 0.05), c + Vector2(r * 0.35, r * 0.05), c + Vector2(r * 0.5, r * 0.6)]), col)
