extends Node3D
## Packaging review stand: one ItemBox per construction / brand, lit like a product shot.
##   godot --path . res://tests/pack_look.tscn -- <out.png>
const IDS := [["c_heavy", "case"], ["c_alu", "case"], ["c_pc", "case"], ["c_gasket", "case"], ["c_ti", "case"], ["c_wood", "case"],
	["k_miami", "kc"], ["k_wob", "kc"], ["k_laser", "kc"], ["k_mono", "kc"], ["p_alu", "plate"], ["b_hs", "pcb"],
	["sw_red", "sw"], ["sw_yellow", "sw"], ["sw_laven", "sw"], ["sw_cream", "sw"], ["s_screw", "stab"], ["lube", "cons"], ["films", "cons"]]

func _ready() -> void:
	var env = WorldEnvironment.new(); var e = Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color("2a2c30")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color("c8ccd4"); e.ambient_light_energy = 0.5
	e.tonemap_mode = Environment.TONE_MAPPER_AGX; e.ssao_enabled = true; env.environment = e; add_child(env)
	var sun = DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-55, -35, 0); sun.light_energy = 2.2; sun.shadow_enabled = true; add_child(sun)
	var fl = MeshInstance3D.new(); var pm = PlaneMesh.new(); pm.size = Vector2(4, 4); fl.mesh = pm; fl.material_override = RoomMats.get_mat("wood_cream_b"); add_child(fl)
	var cols = 5
	for i in IDS.size():
		var it = {"uid": i, "cat": IDS[i][1], "id": IDS[i][0]}
		if it.cat in ["case", "plate", "pcb"]: it["layout"] = "l65"
		var b = ItemBox.make(it)
		b.position = Vector3(-0.9 + (i % cols) * 0.45, 0, -0.55 + (i / cols) * 0.3)
		add_child(b)
	var cam = Camera3D.new(); cam.fov = 40; add_child(cam); cam.position = Vector3(0.0, 1.35, 0.95); cam.look_at(Vector3(0, 0, -0.05)); cam.make_current()
	for k in 40: await get_tree().process_frame
	var a = OS.get_cmdline_user_args()
	get_viewport().get_texture().get_image().save_png(a[0] if a.size() > 0 else "user://pack.png")
	get_tree().quit()
