extends Node
## End-to-end life in the flat through the real game: wake up, carry the neighbour's parcel to the bench,
## unbox it, repair the keyboard, pack it, leave it at the door, courier pays; then order parts with delivery,
## unbox them, store them on the shelf, pick them for a build. Screenshots along the way.
## Run: godot --path . res://tests/home_flow.tscn -- <outdir> [fast]
var main
var out = ""
var fails = 0

func _ready() -> void:
	var a = OS.get_cmdline_user_args()
	out = a[0] if a.size() > 0 else ProjectSettings.globalize_path("user://shots_home")
	DirAccess.make_dir_recursive_absolute(out)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	run.call_deferred()

func L(s: String) -> void: print("[home] ", s)
func check(ok: bool, what: String) -> void:
	if not ok: fails += 1; printerr("FAIL: ", what)
	else: L("ok  " + what)
func shot(name: String) -> void:
	await wait(3)
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name]); L("shot " + name)
func wait(n: int) -> void:
	for i in n: await get_tree().process_frame
func secs(t: float) -> void: await get_tree().create_timer(t).timeout

func look(pos: Vector3, at: Vector3) -> void:
	main.player.global_position = pos; main.player.velocity = Vector3.ZERO
	main.player.look_at_point(at)
	await wait(6)

func target_id() -> String:
	var t = main.player.target
	if t.is_empty():
		var cam = main.player.cam; var from = cam.global_position; var to = from - cam.global_transform.basis.z * 2.1
		var hit = main.player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 0xFFFFFFFF, [main.player.get_rid()]))
		return "<none active=%s mode=%s modal=%s phone=%s hit=%s>" % [main.player.active, main.mode, main.modal_open(), main.phone.opened, (str(hit.collider.get_path()) + " L" + str(hit.collider.collision_layer) + " " + str(hit.position)) if not hit.is_empty() else "-"]
	if str(t.get("id", "")) == "": return "<%s at %s>" % [t.node.get_path() if t.node is Node else t.node, t.pos]
	return str(t.id)

func run() -> void:
	await wait(10)
	# wake-up intro runs on a fresh save
	await secs(1.6); await shot("00_wake_bed")
	while main.mode == "intro": await wait(5)
	if main.modal_open(): main.close_modal()
	Game.S.seenIntro = true
	await secs(0.5)
	check(main.mode == "walk", "after waking the player walks")
	check(Game.S.parcels.size() == 1 and Game.S.parcels[0].place == "door", "neighbour's parcel waits at the door")
	await look(Vector3(0.25, Home.F, 1.7), Vector3(0, -0.05, -0.3)); await shot("01_room_bench")
	await look(Vector3(0.4, Home.F, 1.3), Vector3(-1.6, 0.2, -0.2)); await shot("02_room_pc_window")
	await look(Vector3(0.0, Home.F, 1.0), Vector3(2.8, 0.0, 1.8)); await shot("03_room_shelf_pack")
	await look(Vector3(1.0, Home.F, 0.5), Vector3(-1.1, -0.3, 2.3)); await shot("04_room_bed")
	# door: open it and look at the parcel on the landing
	await look(Vector3(Home.DOOR_X, Home.F, 0.55), Vector3(Home.DOOR_X, -0.3, Home.Z0))
	check(target_id() == "door", "aim at the door (got %s)" % target_id())
	main._interact(main.player.target); await secs(0.9)
	await look(Vector3(Home.DOOR_X - 0.1, Home.F, 0.25), Vector3(Home.DOOR_X, Home.F + 0.1, Home.Z0 - 0.45)); await shot("05_door_parcel")
	var p: Dictionary = Game.S.parcels[0]
	main._pick_parcel(p); await wait(5)
	check(main.carry.get("kind", "") == "parcel", "parcel in hands")
	await look(Vector3(0.0, Home.F, 0.9), Vector3(0, -0.1, -0.2)); await shot("06_carry_to_bench")
	check(target_id() == "bench", "aim at the bench while carrying (got %s)" % target_id())
	main._interact(main.player.target); await wait(10)
	check(main.mode == "unbox", "unboxing started on the bench")
	await shot("07_unbox_closed")
	# play the unboxing stage by stage (auto), screenshot the interesting ones
	var n = 0
	while main.unbox and n < 40:
		main.unbox.auto_step(); n += 1
		await secs(0.55)
		if n in [1, 2, 3, 5]: await shot("08_unbox_%02d" % n)
	await secs(1.2)
	check(Game.S.build != null and Game.S.build.get("kind", "") == "repair", "client keyboard went to the bench as a repair")
	check(main.mode == "bench", "sat at the bench for the repair")
	await shot("09_bench_repair")
	# repair through the existing assembly flow
	var asm: Asm = main.ws.asm
	var guard = 0
	while Game.S.build and asm.step() != "test" and guard < 10:
		asm.auto(); await wait(4); asm.next_step(true); await wait(6); guard += 1
	Game.finish_repair(); await wait(6)
	check(Game.S.ship.size() == 1 and Game.S.ship[0].kind == "repair", "repaired keyboard waits to be packed")
	var money0 = float(Game.S.money)
	main.enter_walk(); await wait(4)
	await look(Vector3(0.7, Home.F, 1.6), Vector3(0.75, -0.15, 2.5))
	check(target_id() == "pack", "aim at the packing table (got %s)" % target_id())
	main.start_pack(Game.S.ship[0]); await secs(0.6)
	n = 0
	while main.pack and n < 20:
		main.pack.auto_step(); n += 1; await secs(0.5)
		if n in [3, 5, 6]: await shot("10_pack_%02d" % n)
	await secs(1.5)
	var outp = Game.S.parcels.filter(func(x): return x.kind == "out")
	check(outp.size() == 1 and outp[0].place == "pack", "packed box stands on the packing table")
	await look(Vector3(0.65, Home.F, 1.75), Vector3(0.64, Home.F + 0.85, 2.45)); await shot("11_packed_box")
	main._pick_parcel(outp[0]); await wait(4)
	main._place_carry({"id": "", "pos": Vector3(Home.DOOR_X, Home.F, Home.Z0 - 0.5), "normal": Vector3.UP}); await wait(4)
	var sh: Dictionary = Game.S.ship[0] if Game.S.ship.size() > 0 else {}
	check(sh.get("status", "") == "door", "box left at the door for the courier")
	await look(Vector3(Home.DOOR_X - 0.1, Home.F, 0.25), Vector3(Home.DOOR_X, Home.F, Home.Z0 - 0.5)); await shot("12_box_for_courier")
	# jump to courier time
	Game.S.dayT = max(float(Game.S.dayT), float(sh.get("pickup", 0)) - (int(Game.S.day) - 1) * 1440.0 - Game.DAY_START_MIN + 1.0)
	Game.home_tick(); await wait(5)
	check(float(Game.S.money) > money0, "courier picked the box up and the client paid (%d → %d)" % [money0, Game.S.money])
	# order parts: they arrive as a parcel later
	Game.S.money = 200000.0
	Game.buy_part("plate", "p_alu", "l60"); Game.buy_part("pcb", "b_hs", "l60"); Game.buy_switch("sw_red", 70)
	check(Game.S.deliveries.size() == 1 and (Game.S.deliveries[0].items as Array).size() == 3, "three purchases ride in one delivery")
	var d: Dictionary = Game.S.deliveries[0]
	Game.S.dayT = float(d.eta) - (int(Game.S.day) - 1) * 1440.0 - Game.DAY_START_MIN + 1.0
	Game.home_tick(); await secs(2.5)
	var part_p = Game.S.parcels.filter(func(x): return x.kind == "part")
	check(part_p.size() == 1, "parts parcel arrived at the door")
	if part_p.size() == 1:
		Game.set_parcel_place(part_p[0].id, "bench"); await wait(4)
		main.start_unbox(Game.parcel_by_id(part_p[0].id)); await secs(0.5)
		n = 0
		while main.unbox and n < 40:
			main.unbox.auto_step(); n += 1; await secs(0.45)
			if n in [4, 5, 6, 8, 9]: await shot("13_unbox_parts_%02d" % n)
		await secs(1.2)
		check(Game.items_at("bench").size() >= 2, "plate and PCB lie on the bench")
	await look(Vector3(-0.2, Home.F, 0.8), Vector3(-0.45, -0.05, -0.3)); await shot("14_parts_on_bench")
	# put bench parts away on the shelf and pick them back
	var uids = Game.items_at("bench").map(func(it): return int(it.uid))
	main._take_crate(uids); await wait(4)
	await look(Vector3(1.9, Home.F, 1.95), Vector3(2.6, -0.2, 1.95))
	check(target_id() == "shelf", "aim at the shelf (got %s)" % target_id())
	main._place_carry(main.player.target); await wait(6)
	check(Game.items_at("shelf").size() >= 6, "parts are on the shelf now")
	await shot("15_shelf_full")
	# PC and phone
	main.enter_walk(); main.open_pc(); await secs(0.5); await shot("16_pc_desktop")
	main.os.open_app("market"); await secs(0.6); await shot("17_pc_market")
	main.os.open_app("deliveries"); await secs(0.4); await shot("18_pc_deliveries")
	main.enter_walk(); main.toggle_phone(); await secs(0.5); await shot("19_phone")
	main.toggle_phone()
	# evening light
	Game.S.dayT = (20.5 * 60.0) - Game.DAY_START_MIN
	await look(Vector3(1.6, Home.F, 1.6), Vector3(-1.0, 0.0, 0.5)); await secs(0.4); await shot("20_evening")
	# go to bed in the evening, wake up next morning
	var day0 = int(Game.S.day)
	main._sleep(false)
	await secs(1.0)
	while main.mode == "intro": await wait(5)
	if main.modal_open(): main.close_modal()
	check(int(Game.S.day) == day0 + 1 and Game.clock_min() < 8 * 60, "slept till the next morning (day %d, %s)" % [Game.S.day, Game.clock_str()])
	L("DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)
