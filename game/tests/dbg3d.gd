extends SceneTree
func _initialize():
	var m = MeshGen.keycap_final(1.0, "cherry", 2)
	print("surfaces ", m.get_surface_count(), " aabb ", m.get_aabb())
	for s in m.get_surface_count():
		var a = m.surface_get_arrays(s)
		print(" surf ", s, " verts ", a[Mesh.ARRAY_VERTEX].size(), " idx ", (a[Mesh.ARRAY_INDEX].size() if a[Mesh.ARRAY_INDEX] != null else -1), " uv ", a[Mesh.ARRAY_TEX_UV] != null)
	quit()
