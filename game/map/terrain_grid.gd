extends RefCounted
## Same LOD across all chunks (including wrapped copies): no mismatched edge vertices.
## Share the four grids per chunk size, not a separate dense mesh per map tile.
const SPACING := [4.0, 8.0, 16.0, 32.0]
const DISTANCES := [1200.0, 2400.0, 4000.0]
var _cache := {}
var _flat_cache := {}

## Painted terrain needs no elevation tessellation; keep chunk culling and world-wrap footprints.
func flat_mesh(size: Vector2) -> PlaneMesh:
	if not _flat_cache.has(size):
		var plane := PlaneMesh.new()
		plane.size = size
		plane.custom_aabb = AABB(Vector3(-size.x / 2, -0.1, -size.y / 2), Vector3(size.x, 0.2, size.y))
		_flat_cache[size] = plane
	return _flat_cache[size]

static func level_for(distance: float, current: int = 0) -> int:
	var level := clampi(current, 0, SPACING.size() - 1)
	while level < DISTANCES.size() and distance >= DISTANCES[level]:
		level += 1
	# Hysteresis avoids switching repeatedly when zoom stops on a boundary.
	while level > 0 and distance < DISTANCES[level - 1] * 0.9:
		level -= 1
	return level

func meshes(size: Vector2) -> Array:
	if not _cache.has(size):
		var levels: Array[PlaneMesh] = []
		for spacing: float in SPACING:
			var plane := PlaneMesh.new()
			plane.size = size
			plane.subdivide_width = maxi(ceili(size.x / spacing) - 1, 0)
			plane.subdivide_depth = maxi(ceili(size.y / spacing) - 1, 0)
			plane.custom_aabb = AABB(Vector3(-size.x / 2, -10, -size.y / 2), Vector3(size.x, 130, size.y))
			levels.append(plane)
		_cache[size] = levels
	return _cache[size]
