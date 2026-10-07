extends RefCounted
## A real quay/warehouse/crane from the existing Blender library, not a billboard.
## The source study also contained a civilian ship and a broad buried foundation:
## neither belongs to the live coastal facility. Retained arrays and PBR are native.

const PATH := "res://assets/models/buildings.glb"
const NODE := "port_0"
const MATERIALS := ["concrete", "brick_red", "roof_slate", "crane"]
var _cache := {}

func model() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	var packed := load(PATH) as PackedScene
	if packed == null:
		return {}
	var scene := packed.instantiate()
	var source := scene.find_child(NODE, true, false) as MeshInstance3D
	if source == null or source.mesh == null:
		scene.free()
		return {}
	var original: Mesh = source.mesh
	var imported := _scene_transform(source)
	var mesh := ArrayMesh.new()
	var names: Array[String] = []
	var quay := AABB()
	var shoreline := -INF
	var has_quay := false
	for surface in original.get_surface_count():
		var material := original.surface_get_material(surface)
		if material == null or String(material.resource_name) not in MATERIALS:
			continue
		var arrays := original.surface_get_arrays(surface)
		var concrete := String(material.resource_name) == "concrete"
		if concrete:
			arrays = _without_foundation(arrays)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)
		names.append(String(material.resource_name))
		if concrete:
			for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
				var p := imported * vertex
				# The original quay deck is y=.02; the narrow pier deck is y=.01.
				if absf(vertex.y - 0.02) < 0.00001:
					if not has_quay:
						quay = AABB(p, Vector3.ZERO)
						has_quay = true
					else:
						quay = quay.expand(p)
					shoreline = maxf(shoreline, p.z)
	if not has_quay or mesh.get_surface_count() == 0:
		scene.free()
		return {}
	var width := maxf(quay.size.x, 0.001)
	var center_x := quay.get_center().x
	var normalization := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE / width),
			Vector3(-center_x / width, 0.0, -shoreline / width))
	var transform := normalization * imported
	var dry := PackedVector2Array()
	var wet := PackedVector2Array()
	for surface in mesh.get_surface_count():
		for vertex: Vector3 in mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
			var p := transform * vertex
			if names[surface] in ["brick_red", "roof_slate"] or (names[surface] == "concrete" and p.z <= 0.00001):
				dry.append(Vector2(p.x, p.z))
			elif names[surface] == "concrete" and p.z >= 0.3:
				wet.append(Vector2(p.x, p.z))
	# A dense quay footprint rejects a platform spanning the edge of a bay.
	for x in 7:
		for z in 5:
			dry.append(Vector2(-0.5 + float(x) / 6.0, -0.54 + float(z) * 0.13))
	_cache = {"mesh": mesh, "source_mesh": original, "path": PATH, "source_node": NODE,
			"imported_transform": imported, "imported_bounds": imported * original.get_aabb(),
			"transform": transform, "bounds": transform * mesh.get_aabb(), "surface_names": names,
			"land_samples": dry, "water_samples": wet, "native_width": width, "shoreline": shoreline}
	scene.free()
	return _cache

func _scene_transform(node: Node) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current := node
	while current != null:
		if current is Node3D:
			result = (current as Node3D).transform * result
		current = current.get_parent()
	return result

func _without_foundation(arrays: Array) -> Array:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var source_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if source_indices.is_empty():
		for i in vertices.size(): source_indices.append(i)
	var indices := PackedInt32Array()
	var remap := {}
	var used := PackedInt32Array()
	for i in range(0, source_indices.size(), 3):
		var a := vertices[source_indices[i]]
		var b := vertices[source_indices[i + 1]]
		var c := vertices[source_indices[i + 2]]
		# finish() buried box is [-.16,.004], distinct from quay [-.04,.02].
		if minf(a.y, minf(b.y, c.y)) < -0.09:
			continue
		if absf(a.y - 0.004) < 0.00001 and absf(b.y - 0.004) < 0.00001 and absf(c.y - 0.004) < 0.00001:
			continue
		for j in 3:
			var old := source_indices[i + j]
			if not remap.has(old):
				remap[old] = used.size()
				used.append(old)
			indices.append(remap[old])
	var compact := arrays.duplicate()
	for slot in Mesh.ARRAY_MAX:
		if slot == Mesh.ARRAY_INDEX or arrays[slot] == null:
			continue
		var values: Variant = arrays[slot]
		if values.size() == 0:
			continue
		var stride := 4 if slot in [Mesh.ARRAY_TANGENT, Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS] else 1
		var retained: Variant = values.duplicate()
		retained.resize(0)
		for old in used:
			for component in stride: retained.append(values[old * stride + component])
		compact[slot] = retained
	compact[Mesh.ARRAY_INDEX] = indices
	return compact
