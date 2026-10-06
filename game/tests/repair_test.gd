extends Node
## Plays the two opening story repairs through the real UI: diagnosis by key presses, fixing by screen-space tool clicks.
var main
var f := 0
var out := ProjectSettings.globalize_path("user://test_rep")
var busy := false
var job := 0

func _ready() -> void:
	if OS.get_cmdline_user_args().size() > 0 and not OS.get_cmdline_user_args()[0] in ["first", "noshots", "keep", "low"]: out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)

func L(s: String) -> void: printerr(s)
func shot(name: String) -> void: get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
func wait(n: int) -> void:
	for i in n: await get_tree().process_frame

func key_inf(i: int) -> Dictionary:
	var p: Vector2 = main.ws.screen_of_key(i)
	var inf: Dictionary = main.ws.ray_at(p); inf.spd = 0.0
	return inf

func _process(_d: float) -> void:
	f += 1
	if f < 30 or busy: return
	busy = true
	await run()
	get_tree().quit()

func run() -> void:
	if main.modal_open(): main.close_modal(true)
	Game.S.seenIntro = true; Game.S.settings.gfx = "low"; main.ws.apply_quality()
	L("unlocked at start: %s, orders: %s" % [Game.builds_unlocked(), Game.S.orders.map(func(o): return o.kind)])
	main.open_tab("workshop", false); await wait(20); shot("00_locked")
	main.open_tab("orders", false); await wait(20); shot("01_orders")
	for j in 2:
		var o = Game.S.orders.filter(func(x): return x.kind == "repair" and int(x.get("story", -1)) == j)[0]
		L("job %d: %s faults=%s" % [j, o.name, str(o.faults)])
		if not Game.start_repair(o.id): L("start failed"); return
		main.open_tab("workshop", false); await wait(30)
		var b: Dictionary = Game.S.build
		L("steps " + str(b.steps) + " step=" + main.ws.asm.step())
		# diagnosis: press every key
		for i in b.ks.size():
			main._key(i, true); main._key(i, false)
			if i % 8 == 0: await wait(1)
		await wait(10); shot("%d2_diag" % j)
		var found = b.ks.filter(func(k): return int(k.get("seen", 0)) == 1).size()
		L("  diag done=%s found=%d" % [main.ws.asm.done(), found])
		main.ws.asm.next_step(false); await wait(40)
		L("  step=" + main.ws.asm.step())
		shot("%d3_fix" % j)
		# one deliberate mistake on job 0
		var faulty := []
		for i in b.ks.size(): if str(b.ks[i].get("f", "")) != "": faulty.append(i)
		if j == 0:
			main.ws.asm.set_tool("sw_new"); main.ws.asm.down(key_inf(faulty[0]))
		for i in faulty:
			var seq: Array = Asm.FAULTS[b.ks[i].f].seq
			for t in seq:
				main.ws.asm.set_tool(t)
				var inf := key_inf(i)
				if int(inf.i) != i: L("  pick miss: wanted %d got %d" % [i, int(inf.i)])
				main.ws.asm.down(inf); main.ws.asm.up(inf)
				await wait(3)
				if t == "cap_pull" and i == faulty[0]: shot("%d4_cap_off" % j)
		await wait(10); shot("%d5_fixed" % j)
		L("  fix done=%s mist=%d" % [main.ws.asm.done(), int(b.get("mist", 0))])
		main.ws.asm.next_step(false); await wait(30)
		L("  step=" + main.ws.asm.step()); shot("%d6_test" % j)
		main.screen._finish_repair(); await wait(30); shot("%d7_done" % j)
		main.close_modal(true); await wait(5)
		L("  money=%d rep=%.2f repairs=%d" % [int(Game.S.money), float(Game.S.rep), int(Game.S.stats.repairs)])
	L("unlocked after: %s, orders: %s, tut=%d" % [Game.builds_unlocked(), Game.S.orders.map(func(o): return o.kind), int(Game.S.tut)])
	main.open_tab("workshop", false); await wait(30); shot("09_unlocked")
	main.open_tab("orders", false); await wait(20); shot("10_orders_after")
	# random repairs generate
	for i in 5:
		var r := Game.gen_repair()
		L("gen: %s %s %s budget=%d" % [r.name, r.board.layout, str(r.faults), int(r.budget)])
