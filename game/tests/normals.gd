extends SceneTree
func _initialize():
	var chk = func(name, m: Mesh, surf: int, test: Callable):
		var a = m.surface_get_arrays(surf); var v = a[Mesh.ARRAY_VERTEX]; var n = a[Mesh.ARRAY_NORMAL]
		var good = 0
		for i in v.size():
			if test.call(v[i], n[i]): good += 1
		print(name, " ok ", good, "/", v.size())
	var cap = MeshGen.keycap_final(1.0, "cherry", 2)
	chk.call("cap side outward", cap, 0, func(p, n): return Vector2(n.x,n.z).dot(Vector2(p.x,p.z)) > -0.01 or n.y > 0.5)
	chk.call("cap top up", cap, 1, func(p, n): return n.y > 0.3)
	var rb = MeshGen.rounded_box(0.56, 0.24, 0.56, 0.05)
	chk.call("rbox top-up/side-out", rb, 0, func(p, n): return (p.y > 0.235 and n.y > 0.3) or (p.y < 0.005 and n.y < -0.3) or (p.y >= 0.005 and p.y <= 0.235 and Vector2(n.x,n.z).dot(Vector2(p.x,p.z)) > -0.01))
	var ct = MeshGen.case_tray(15.0, 5.0)
	chk.call("case", ct, 0, func(p, n): return true)
	var a = ct.surface_get_arrays(0); var v = a[Mesh.ARRAY_VERTEX]; var nn = a[Mesh.ARRAY_NORMAL]
	var up_top = 0; var up_n = 0; var out_side = 0; var side_n = 0; var floor_up = 0; var floor_n = 0
	for i in v.size():
		var p = v[i]
		if abs(p.y - 1.0) < 0.001 and abs(nn[i].y) > 0.9: up_n += 1; up_top += int(nn[i].y > 0)
		if abs(p.y - 0.28) < 0.001 and abs(nn[i].y) > 0.9: floor_n += 1; floor_up += int(nn[i].y > 0)
		if p.y > 0.2 and p.y < 0.8 and abs(p.x) > 7.8: side_n += 1; out_side += int(sign(nn[i].x) == sign(p.x))
	print("case rim up ", up_top, "/", up_n, " floor up ", floor_up, "/", floor_n, " outer side out ", out_side, "/", side_n)
	quit()
