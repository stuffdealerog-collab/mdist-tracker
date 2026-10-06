extends Node
## Quick visual check of the flat: a few fixed camera spots. Run: godot --path . res://tests/look.tscn -- <outdir> [hour]
var main
var out = ""

func _ready() -> void:
	var a = OS.get_cmdline_user_args()
	out = a[0] if a.size() > 0 else ProjectSettings.globalize_path("user://look")
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	run.call_deferred(float(a[1]) if a.size() > 1 else 10.0)

func wait(n: int) -> void:
	for i in n: await get_tree().process_frame

func shot(name: String, pos: Vector3, at: Vector3) -> void:
	main.player.global_position = pos; main.player.velocity = Vector3.ZERO; main.player.look_at_point(at)
	await wait(40)
	var vp = get_viewport().get_viewport_rid(); RenderingServer.viewport_set_measure_render_time(vp, true)
	var gpu = 0.0
	for i in 30:
		await get_tree().process_frame; gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("shot %-12s gpu=%.2fms draw_calls=%d  tris=%dk  objects=%d  fps=%d" % [name, gpu / 30.0, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000, Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Engine.get_frames_per_second()])

func run(hour: float) -> void:
	await wait(5)
	Game.S.seenIntro = true
	while main.mode == "intro": await wait(5)
	await wait(60)
	if main.modal_open(): main.close_modal(true)
	Game.S.dayT = hour * 60.0 - Game.DAY_START_MIN
	await wait(10)
	if OS.has_environment("KSS_TOGGLE"):    # live graphics switch: High (SDFGI) -> Mid (lightmap) -> High
		for q in ["high", "mid", "high"]:
			Game.S.settings.gfx = q; main.ws.apply_quality()
			await shot("t_%s_%d" % [q, int(main.home.baked)], Vector3(0.0, Home.F, 1.0), Vector3(2.8, 0.1, 1.5))
		get_tree().quit(); return
	await shot("a_bench", Vector3(0.25, Home.F, 1.7), Vector3(0, -0.05, -0.3))
	await shot("b_pc", Vector3(0.4, Home.F, 1.3), Vector3(-1.5, 0.1, -0.3))
	await shot("c_bed", Vector3(1.0, Home.F, 0.5), Vector3(-1.1, -0.3, 2.3))
	await shot("d_wardrobe", Vector3(0.0, Home.F, 1.0), Vector3(2.8, 0.1, 1.5))
	await shot("e_window", Vector3(1.8, Home.F, 1.2), Vector3(-2.4, 0.5, 0.75))
	await shot("f_door", Vector3(0.9, Home.F, 1.7), Vector3(2.4, 0.2, -0.6))
	await shot("g_ceiling", Vector3(1.6, Home.F, 2.1), Vector3(0.4, 2.0, 0.6))
	await shot("h_chest", Vector3(0.7, Home.F, 1.3), Vector3(0.9, -0.3, 2.6))
	main.home.set_wardrobe(true); await wait(60)
	await shot("w_wardrobe_open", Vector3(1.2, Home.F, 1.95), Vector3(2.8, -0.1, 1.95))
	main.home.set_wardrobe(false); await wait(50)
	await shot("i_aquarium", Vector3(1.14, Home.F, 1.95), Vector3(1.14, 0.2, 2.56))
	# close-up, eye level with the tank (a crouching view)
	var cam = Camera3D.new(); cam.fov = 50.0; main.add_child(cam)
	cam.global_position = Vector3(1.0, 0.25, 1.95); cam.look_at(Vector3(1.14, 0.22, 2.56)); cam.make_current()
	await wait(40); get_viewport().get_texture().get_image().save_png("%s/j_aquarium_close.png" % out)
	if OS.get_environment("KSS_AQDBG") != "":
		var aq = main.home.aquarium
		var tank = aq.get_child(0)
		for mi in tank.find_children("*", "MeshInstance3D", true, false):
			for i in mi.mesh.get_surface_count():
				var m0 = mi.get_surface_override_material(i)
				var nm = mi.mesh.surface_get_material(i).resource_name if mi.mesh.surface_get_material(i) else "?"
				var hide = StandardMaterial3D.new(); hide.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; hide.albedo_color = Color(0,0,0,0)
				mi.set_surface_override_material(i, hide)
				await wait(4); get_viewport().get_texture().get_image().save_png("%s/m_%s_%s.png" % [out, mi.name, nm])
				mi.set_surface_override_material(i, m0)
		for c in aq.get_children():
			var was = c.visible; c.visible = false
			await wait(4); get_viewport().get_texture().get_image().save_png("%s/dbg_%s.png" % [out, c.name])
			c.visible = was
		get_tree().quit(); return
	main.home.aquarium.feed()
	await wait(100); get_viewport().get_texture().get_image().save_png("%s/k_aquarium_feed.png" % out)
	await wait(200); get_viewport().get_texture().get_image().save_png("%s/l_aquarium_later.png" % out)
	get_tree().quit()
