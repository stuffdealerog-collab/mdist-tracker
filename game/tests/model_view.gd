extends Node
## Model inspection: neutral studio, several cameras. Args: -- <out.png> <layout> <kc> <case> <color> <view> [w h]
var f := 0
var out := ""
var cam: Camera3D
func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0]
	var lay: String = a[1] if a.size() > 1 else "l65"
	var kc: String = a[2] if a.size() > 2 else "k_bow"
	var cs: String = a[3] if a.size() > 3 else "c_alu"
	var col: int = int(a[4]) if a.size() > 4 else 0
	var view: String = a[5] if a.size() > 5 else "persp"
	Game.S = Game.new_state()
	var at := LegendAtlas.new(); add_child(at); at.build()
	var we := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.55, 0.57, 0.6)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.8, 0.82, 0.86); e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC; e.ssao_enabled = true; e.ssao_radius = 0.04
	we.environment = e; add_child(we)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-50, -35, 0); l.shadow_enabled = true; l.light_energy = 1.2; add_child(l)
	var l2 := DirectionalLight3D.new(); l2.rotation_degrees = Vector3(-20, 140, 0); l2.light_energy = 0.4; add_child(l2)
	var kb := Keyboard3D.new(); add_child(kb)
	kb.show_spec({"layout": lay, "case": cs, "color": col, "plate": "p_alu", "pcb": "b_hs", "stab": "s_screw", "kc": kc, "sw": "sw_red", "art": null, "mods": {}})
	var W: float = kb.W
	var T: Vector3 = kb.board.global_transform * Vector3(0, 0.6, 0)
	cam = Camera3D.new(); add_child(cam)
	match view:
		"side":
			cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = kb.H + 2.5
			cam.look_at_from_position(T + Vector3(-W / 2.0 - 6.0, 0, 0), T)
		"side_close":
			cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = 2.2
			cam.look_at_from_position(T + Vector3(-W / 2.0 - 6.0, 0.5, 0.4), T + Vector3(0, 0.5, 0.4))
		"top":
			cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = W * 0.62
			cam.look_at_from_position(T + Vector3(0, 12, 0.001), T)
		"close":
			cam.fov = 35; cam.look_at_from_position(T + Vector3(-W * 0.32, 2.2, 4.4), T + Vector3(-W * 0.3, 0.4, 0.6))
		"front":
			cam.fov = 30; cam.look_at_from_position(T + Vector3(0, 1.0, W * 1.2), T)
		_:
			cam.fov = 32; cam.look_at_from_position(T + Vector3(-W * 0.38, W * 0.62, W * 0.95), T + Vector3(0, -0.2, 0.2))
func _process(_d):
	f += 1
	if f == 25: get_viewport().get_texture().get_image().save_png(out); get_tree().quit()
