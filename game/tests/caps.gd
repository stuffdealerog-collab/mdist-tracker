extends SceneTree
var f := 0
func _init():
	var r := Node3D.new(); root.add_child(r)
	var env := WorldEnvironment.new(); var e := Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.08,0.09,0.1)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.5,0.55,0.6); e.ambient_light_energy = 0.6; e.tonemap_mode = Environment.TONE_MAPPER_FILMIC; e.ssao_enabled = true
	env.environment = e; r.add_child(env)
	var profs := ["cherry","oem","sa","mt3","kat","xda"]
	var x := 0.0
	for pi in profs.size():
		for row in 4:
			var mi := MeshInstance3D.new(); mi.mesh = MeshGen.keycap_final(1.0, profs[pi], row)
			var m := StandardMaterial3D.new(); m.albedo_color = Color.from_hsv(pi/6.0, 0.35, 0.9); m.roughness = 0.6
			mi.material_override = m
			mi.position = Vector3(row * 1.05 - 1.6, 0, pi * 1.05 - 2.6); r.add_child(mi)
	var sp := MeshInstance3D.new(); sp.mesh = MeshGen.keycap_final(2.25, "cherry", 2); sp.material_override = StandardMaterial3D.new(); sp.position = Vector3(3.2, 0, -2.6); r.add_child(sp)
	var sp2 := MeshInstance3D.new(); sp2.mesh = MeshGen.keycap_final(2.25, "sa", 2); sp2.material_override = StandardMaterial3D.new(); sp2.position = Vector3(3.2, 0, -0.5); r.add_child(sp2)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-55, -35, 0); l.shadow_enabled = true; r.add_child(l)
	var cam := Camera3D.new(); cam.fov = 42; r.add_child(cam); cam.look_at_from_position(Vector3(1.5, 5.2, 4.8), Vector3(0.8, 0, -0.6))
	var norm_ok = MeshGen.keycap_final(1.0,"cherry",2).surface_get_arrays(0)[Mesh.ARRAY_NORMAL][0]
	var v0 = MeshGen.keycap_final(1.0,"cherry",2).surface_get_arrays(0)[Mesh.ARRAY_VERTEX][0]
	print("side normal ", norm_ok, " at ", v0, " outward? ", Vector2(norm_ok.x,norm_ok.z).dot(Vector2(v0.x,v0.z)) > 0)
	var tn = MeshGen.keycap_final(1.0,"cherry",2).surface_get_arrays(1)[Mesh.ARRAY_NORMAL][0]
	print("top normal ", tn, " up? ", tn.y > 0)
func _process(_d):
	f += 1
	if f == 30:
		root.get_texture().get_image().save_png("/tmp/claude-0/-home-user-mdist-tracker/28c0084d-b286-5cd8-9401-8ae7cf7cb680/scratchpad/caps.png"); quit()
	return false
