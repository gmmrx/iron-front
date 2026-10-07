extends SceneTree
## Actual draw counts, including AirLayer's world-sized MultiMesh bounds.
func _init() -> void:
	await process_frame
	var plane_model: Script = load("res://game/map/plane_model.gd")
	var vp := SubViewport.new()
	vp.size = Vector2i(512, 512)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var camera := Camera3D.new()
	vp.add_child(camera)
	camera.current = true
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = plane_model.body()
	mm.instance_count = 1
	mm.set_instance_transform(0, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 6.0), Vector3.ZERO))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = plane_model.material()
	mi.custom_aabb = AABB(Vector3(-1e5, -100, -1e5), Vector3(2e5, 1e4, 2e5))
	vp.add_child(mi)
	var counts: Array[int] = []
	for distance: float in [12.0, 600.0]:
		mm.mesh = plane_model.batch_mesh("body", distance, vp.size.y)
		camera.position = Vector3(0, distance, distance * 0.5)
		camera.look_at(Vector3.ZERO)
		for f in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		counts.append(vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME))
	print("PLANE_MULTIMESH_LOD near/far primitives=", counts)
	var passed := counts[0] > 0 and counts[1] > 0 and counts[1] < counts[0]
	vp.queue_free()
	await process_frame
	quit(0 if passed else 1)
