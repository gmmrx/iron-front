class_name StraitLayer
extends Node3D
## Every gameplay strait is a small fixed-world-scale 3D bridge.
## Shared Blender meshes retain their native PBR; bank placement is visual-only.

const MODELS := preload("res://game/map/strait_models.gd")
const BRIDGE_SPAN_LENGTH := 1.7
const BRIDGE_WIDTH_SCALE := 1.6
const BRIDGE_END_LENGTH := 0.45
const BRIDGE_BANK_HALF_WIDTH := 0.25
const BRIDGE_BANK_STEP := 0.15
const BRIDGE_BANK_SEARCH := 12.0
const MAX_BANK_SEARCH := 64.0
const MIN_DECK_HEIGHT := 0.03
const COLOR := Color(0.98, 0.96, 0.9)
const VISIBLE_RANGE := 380.0

var map: MapView3D
var library: Dictionary        ## CityLayer3D'nin bina kütüphanesi (bridge_span, bridge_end)
var building_mesh: Callable    ## CityLayer3D'nin mevcut API'si korunur; yeni modeller native PBR kullanır.
var placements: Array[Dictionary] = []
var bridge_endpoints := {}
var _models := MODELS.new()
var _land_pixels := {}
var _water_candidates: Array[Vector2] = []

func _ready() -> void:
	for s: Dictionary in World.straits:
		var a := Vector2(s["from"][0], s["from"][1])
		var b := Vector2(s["to"][0], s["to"][1])
		var names: Dictionary = s["name"]
		var title: String = names.get(TranslationServer.get_locale().substr(0, 2), names["en"])
		var actor := str(names.get("en", ""))
		var label_anchor := _bridge(a, b, actor)
		var l := Label3D.new()
		l.text = title
		l.font = load("res://assets/fonts/BarlowCondensed-SemiBold.ttf")
		l.font_size = 20
		l.outline_size = 8
		l.modulate = COLOR
		l.outline_modulate = Color(0.03, 0.03, 0.02, 0.9)
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.fixed_size = true
		l.pixel_size = 0.0005
		l.no_depth_test = true
		# Fixed cartographic offset, not a zoom-specific title: keep the normal
		# name clear of the fixed, cross-channel bridge.
		l.position = Vector3(label_anchor.x, 0.05, label_anchor.y)
		var banks: Dictionary = bridge_endpoints.get(actor, {})
		l.offset = bridge_label_offset(banks.get("direction", Vector2.RIGHT), l.font, title)
		l.scale = Vector3.ONE
		l.visibility_range_end = VISIBLE_RANGE * 0.7
		add_child(l)

## One-time offset perpendicular to the bridge. Text stays in its normal style
## and does not sit on a long diagonal/vertical span; no camera/zoom dependency.
func bridge_label_offset(direction: Vector2, font: Font, title: String) -> Vector2:
	var projected := Vector2(direction.x, direction.y * cos(MapCamera3D.PITCH_NEAR)).normalized()
	var perpendicular := Vector2(-projected.y, projected.x)
	if perpendicular.y < 0.0: perpendicular = -perpendicular
	var text_width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var clearance := absf(perpendicular.x) * (text_width * 0.5 + 8.0) + absf(perpendicular.y) * 18.0 + 12.0
	var screen_offset := perpendicular * clearance
	return Vector2(screen_offset.x, -screen_offset.y)

func _is_land(p: Vector2) -> bool:
	var key := Vector2i(p.floor())
	if not _land_pixels.has(key):
		var province := World.province(map.province_at(p))
		_land_pixels[key] = province != null and province.is_land()
	return _land_pixels[key]

## Small nearest-water lookup; no civilian model loading or hull-fitting dependency.
func nearest_water_point(seed: Vector2) -> Vector2:
	if not _is_land(seed): return seed
	if _water_candidates.is_empty():
		for x in range(-32, 33):
			for y in range(-32, 33): _water_candidates.append(Vector2(x, y) * 0.25)
		_water_candidates.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.length_squared() < b.length_squared())
	for offset: Vector2 in _water_candidates:
		var point := seed + offset
		if not _is_land(point): return point
	return Vector2.INF

func _add_model(kind: String, model: Dictionary, placement: Transform3D, site: Dictionary = {}) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = kind
	node.mesh = model["mesh"]
	node.transform = placement * (model["transform"] as Transform3D)
	node.visibility_range_end = VISIBLE_RANGE
	node.visibility_range_end_margin = VISIBLE_RANGE * 0.12
	node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	# Native imported surface materials and atlas are intentionally not replaced.
	add_child(node)
	var record := site.duplicate()
	record.merge({"kind": kind, "path": model["path"], "placement": placement, "node": node})
	placements.append(record)
	return node

## Gameplay strait endpoints may be water pixels along the channel, not bridge abutments.
## Find the shortest bank-to-bank crossing around the water midpoint, visual-only.
func bridge_banks(a: Vector2, b: Vector2, actor: String) -> Dictionary:
	var original := (b - a).normalized()
	var center := nearest_water_point((a + b) * 0.5)
	if center == Vector2.INF: return {}
	var reach := clampf(a.distance_to(b) * 1.75 + 4.0, BRIDGE_BANK_SEARCH, MAX_BANK_SEARCH)
	var best := {}
	var shortest := INF
	for angle: float in [0.0, PI / 2.0, -PI / 12.0, PI / 12.0, -PI / 6.0, PI / 6.0,
		PI / 2.0 - PI / 12.0, PI / 2.0 + PI / 12.0, PI / 2.0 - PI / 6.0, PI / 2.0 + PI / 6.0]:
		var direction := original.rotated(angle)
		var first := _bridge_bank(center, -direction, reach)
		var second := _bridge_bank(center, direction, reach)
		if first == Vector2.INF or second == Vector2.INF: continue
		var length := first.distance_to(second)
		if length >= shortest or _is_land(first.lerp(second, 0.5)): continue
		# The crossing must pass through the water channel, not connect two points on one land shelf.
		var wet := 0
		for fraction: float in [0.2, 0.35, 0.5, 0.65, 0.8]:
			if not _is_land(first.lerp(second, fraction)): wet += 1
		if wet < 3: continue
		shortest = length
		best = {"actor": actor, "start": first, "end": second, "center": (first + second) * 0.5,
			"direction": (second - first).normalized(), "length_world": length, "water_samples": wet, "search_world": reach}
	return best

func _bridge_bank(center: Vector2, outward: Vector2, reach: float) -> Vector2:
	for step in range(1, ceili(reach / BRIDGE_BANK_STEP) + 1):
		var p := center + outward * (step * BRIDGE_BANK_STEP)
		if _bridge_bank_fits(p, outward): return p
	return Vector2.INF

func _bridge_bank_fits(p: Vector2, outward: Vector2) -> bool:
	var right := Vector2(-outward.y, outward.x)
	# The entire small end abutment extends from the shoreline back onto its bank (+X).
	for depth: float in [0.0, BRIDGE_END_LENGTH * 0.5, BRIDGE_END_LENGTH]:
		for side: float in [-BRIDGE_BANK_HALF_WIDTH, 0.0, BRIDGE_BANK_HALF_WIDTH]:
			if not _is_land(p + outward * depth + right * side): return false
	return true

func _bridge(a: Vector2, b: Vector2, actor: String) -> Vector2:
	var model := _models.model("little_belt_span")
	var end := _models.model("little_belt_end")
	if model.is_empty() or end.is_empty(): return (a + b) * 0.5
	var banks := bridge_banks(a, b, actor)
	if banks.is_empty():
		push_warning("No safe visual bridge banks found for " + actor)
		return (a + b) * 0.5
	bridge_endpoints[actor] = banks
	a = banks["start"]
	b = banks["end"]
	var direction := (b - a).normalized()
	var yaw := -atan2(direction.y, direction.x)
	var length := a.distance_to(b)
	# The abutment's imported bottom determines deck height: its stone base
	# touches the flat ground instead of floating above it at an arbitrary Y.
	var end_bounds: AABB = end["bounds"]
	var deck := maxf(-end_bounds.position.y, MIN_DECK_HEIGHT)
	var count := maxi(1, ceili(length / BRIDGE_SPAN_LENGTH))
	var span := length / count
	for i in count:
		var p := a + direction * (span * i)
		var basis := Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(span, 1.0, BRIDGE_WIDTH_SCALE))
		_add_model("bridge_span", model, Transform3D(basis, Vector3(p.x, deck, p.y)), banks)
	for pair: Array in [[a, yaw + PI], [b, yaw]]:
		var p: Vector2 = pair[0]
		var basis := Basis(Vector3.UP, pair[1]) * Basis.from_scale(Vector3(BRIDGE_END_LENGTH, 1.0, BRIDGE_WIDTH_SCALE))
		var metadata := banks.duplicate()
		metadata["bank_position"] = p
		metadata["outward"] = -direction if p == a else direction
		_add_model("bridge_end", end, Transform3D(basis, Vector3(p.x, deck, p.y)), metadata)
	return banks["center"]
