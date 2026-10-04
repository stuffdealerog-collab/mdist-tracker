extends SceneTree
var frames := 0
func _init():
	var root3 := Node3D.new(); get_root().add_child(root3)
	var env := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_SKY; var sky := Sky.new(); sky.sky_material = ProceduralSkyMaterial.new(); e.sky = sky
	e.tonemap_mode = Environment.TONE_MAPPER_ACES; e.ssao_enabled = true; e.sdfgi_enabled = true; e.glow_enabled = true
	env.environment = e; root3.add_child(env)
	var box := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(2,0.4,1); box.mesh = bm
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(0.9,0.5,0.4); mat.metallic = 0.6; mat.roughness = 0.3; box.material_override = mat; root3.add_child(box)
	var fl := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(10,10); fl.mesh = pm; fl.position.y = -0.2; root3.add_child(fl)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-50,30,0); l.shadow_enabled = true; root3.add_child(l)
	var cam := Camera3D.new(); cam.position = Vector3(0,1.6,3); root3.add_child(cam); cam.look_at(Vector3.ZERO)
func _process(_d):
	frames += 1
	if frames == 30:
		var img := get_root().get_texture().get_image()
		img.save_png("/tmp/claude-0/-home-user-mdist-tracker/28c0084d-b286-5cd8-9401-8ae7cf7cb680/scratchpad/smoke.png")
		print("SHOT ", img.get_size())
		quit()
	return false
