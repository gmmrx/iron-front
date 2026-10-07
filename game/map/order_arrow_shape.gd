extends RefCounted
## One continuous silhouette: tapered tail, broad shaft and solid shouldered head.
static func contour(points: Array[Vector2], width: float) -> PackedVector2Array:
	var pts: Array[Vector2] = []
	for p in points:
		if pts.is_empty() or pts.back().distance_to(p) > 0.001:
			pts.append(p)
	if pts.size() < 2:
		return PackedVector2Array()
	var lengths: Array[float] = [0.0]
	for i in range(1, pts.size()):
		lengths.append(lengths.back() + pts[i - 1].distance_to(pts[i]))
	var total: float = lengths.back()
	var w := minf(width, total * 0.22)
	var head_length := minf(w * 2.1, total * 0.32)
	var end := total - head_length
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var neck := pts[0]
	for i in pts.size():
		var along := minf(lengths[i], end)
		var p := pts[i]
		if lengths[i] > end:
			p = pts[i - 1].lerp(p, (end - lengths[i - 1]) / (lengths[i] - lengths[i - 1]))
		var direction := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(0, i - 1)]).normalized()
		var normal := Vector2(-direction.y, direction.x)
		var half := w * 0.5 * lerpf(0.62, 1.0, pow(along / maxf(end, 0.001), 0.65))
		left.append(p + normal * half)
		right.append(p - normal * half)
		neck = p
		if lengths[i] >= end:
			break
	var tip: Vector2 = pts.back()
	var direction := (tip - neck).normalized()
	var normal := Vector2(-direction.y, direction.x)
	left.append(neck - direction * head_length * 0.12 + normal * w)
	left.append(tip)
	left.append(neck - direction * head_length * 0.12 - normal * w)
	right.reverse()
	left.append_array(right)
	return left
