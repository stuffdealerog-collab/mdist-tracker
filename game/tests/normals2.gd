extends SceneTree
func _initialize():
	var rb = MeshGen.rounded_box(0.56, 0.24, 0.56, 0.05)
	var a = rb.surface_get_arrays(0); var v = a[Mesh.ARRAY_VERTEX]; var n = a[Mesh.ARRAY_NORMAL]
	var shown = 0
	for i in v.size():
		var p = v[i]
		var radial = Vector2(n[i].x,n[i].z).dot(Vector2(p.x,p.z))
		if p.y >= 0.005 and p.y <= 0.235 and radial <= -0.01 and shown < 6: print("bad ", p, " n ", n[i]); shown += 1
	var ct = MeshGen.case_tray(15.0, 5.0)
	a = ct.surface_get_arrays(0); v = a[Mesh.ARRAY_VERTEX]; n = a[Mesh.ARRAY_NORMAL]
	var o = 0; var c = 0
	for i in v.size():
		var p = v[i]
		if p.y > 0.05 and p.y < 0.95 and abs(p.x) > 7.9: c += 1; o += int(sign(n[i].x) == sign(p.x))
	print("case outer side out ", o, "/", c)
	quit()
