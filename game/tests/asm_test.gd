extends Node
## Drives a full hands-on build through every stage using real screen-space picking.
var main
var f := 0
var out := "/tmp/claude-0/-home-user-mdist-tracker/28c0084d-b286-5cd8-9401-8ae7cf7cb680/scratchpad/asm"
var phase := 0
var wait := 0
var shots := true
var log_lines := []
var busy := false

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	shots = not ("noshots" in OS.get_cmdline_user_args())
	main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)

func L(s: String) -> void: printerr(s); log_lines.append(s)

func shot(name: String) -> void:
	if shots: get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])

func ws() -> Workshop: return main.ws
func asm() -> Asm: return main.ws.asm

func key_inf(i: int) -> Dictionary:
	var p: Vector2 = ws().screen_of_key(i)
	var inf: Dictionary = ws().ray_at(p); inf.spd = 0.0
	return inf

func _process(_d: float) -> void:
	f += 1
	if f < 30 or busy: return
	wait -= 1
	if wait > 0: return
	L("phase %d f=%d mem=%dMB" % [phase, f, OS.get_static_memory_usage() / 1048576])
	match phase:
		0:
			if main.modal_open(): main.close_modal(true)
			Game.S.seenIntro = true; Game.S.settings.gfx = "low"; ws().apply_quality()
			if "first" in OS.get_cmdline_user_args():
				main.open_tab("workshop", false); main.screen.build_screen(false)
				phase = 1; wait = 10; return
			# make this a full (second) build: bump built, give parts
			Game.S.stats.built = 1; Game.S.money = 500000; L("a")
			Game.buy_part("case", "c_alu", "l60", 1); Game.buy_part("plate", "p_alu", "l60"); Game.buy_part("pcb", "b_solder", "l60")
			Game.buy_part("stab", "s_screw"); Game.buy_part("kc", "k_miami"); Game.buy_switch("sw_yellow", 70)
			L("b"); Game.buy_cons("lube", 1); Game.buy_cons("foam", 1); L("c")
			main.open_tab("workshop", false); L("d")
			var items: Array = Game.S.inv.items
			var pick := func(cat, id): for it in items: if it.cat == cat and it.id == id: return it.uid
			main.draft = {"case": pick.call("case", "c_alu"), "plate": pick.call("plate", "p_alu"), "pcb": pick.call("pcb", "b_solder"), "stab": pick.call("stab", "s_screw"), "kc": pick.call("kc", "k_miami"), "sw": "sw_yellow", "mods": {"lube": true, "foam": true}}
			L("e"); main.screen.build_screen(false); L("f")
			phase = 1; wait = 20
		1:
			shot("00_draft")
			main.screen._start()
			L("steps " + str(Game.S.build.steps))
			phase = 2; wait = 30
		2:
			var st := asm().step(); L("step " + st)
			shot("%02d_%s" % [int(Game.S.build.step) + 1, st])
			busy = true
			await _do_step(st)
			busy = false
			phase = 3; wait = 30
		3:
			var st2 := asm().step()
			shot("%02d_%s_done" % [int(Game.S.build.step) + 1, st2])
			L("  done=" + str(asm().done()))
			if st2 == "test":
				main.screen._finish("Тестовая")
				L("finished: boards=%d q=%d" % [Game.S.boards.size(), int(Game.S.boards[-1].st.quality)])
				phase = 4; wait = 60; return
			if not asm().next_step(true): L("  next failed!"); get_tree().quit(); return
			phase = 2; wait = 30
		4:
			shot("99_finished")
			main.close_modal(true)
			# deliver to an order
			var o = Game.S.orders[0]; var b = Game.S.boards[-1]
			var r := Game.deliver_order(o.id, b.uid)
			L("delivered stars=%d pay=%d" % [int(r.get("stars", 0)), int(r.get("pay", 0))])
			# sound path: type on a finished board and hear switches
			var bb = Game.S.boards[-1] if Game.S.boards.size() > 0 else b
			main.set_kb_sound(bb)
			for i in 40: main._key(i % 60, true); main._key(i % 60, false)
			for s in Data.SWITCHES: SwitchIcon.hear(s.id, false); SwitchIcon.hear(s.id, true)
			L("sound ok, keys=%d sets=%d" % [int(Game.S.stats.keys), Audio.sets.size()])
			var fa := FileAccess.open(out + "/log.txt", FileAccess.WRITE); fa.store_string("\n".join(log_lines)); fa.close()
			get_tree().quit()

func _do_step(st: String) -> void:
	var b: Dictionary = Game.S.build
	match st:
		"case":
			var center: Vector2 = ws().cam.unproject_position(ws().kb.to_global(Vector3(0, 2.2, 0)))
			for n in Asm.piece_queue(b):
				await get_tree().create_timer(0.5).timeout
				while int(b.prot.get(n, 0)) % 4 != 0: asm().rotate_piece()
				var inf: Dictionary = ws().ray_at(center + Vector2(300, -100))
				asm().down(inf)
				inf = ws().ray_at(center); asm().move(inf)
				asm().up(inf)
				L("  piece %s placed=%s" % [n, b.pieces.has(n)])
				await get_tree().create_timer(0.45).timeout
		"stab":
			var ok := 0
			for i in Game.stab_targets(b.layout):
				var inf := key_inf(i)
				if inf.i == i: ok += 1
				asm().down(inf); asm().up(inf)
			L("  stab picks ok %d/%d" % [ok, Game.stab_targets(b.layout).size()])
		"lube":
			var lg = main.screen.lube
			L("   lube node rect=%s vis=%s intree=%s parent=%s mod=%s" % [lg.get_global_rect(), lg.visible, lg.is_visible_in_tree(), lg.get_parent().name, lg.modulate])
			for r in 3:
				if r < 2:
					if lg.round_i != r: continue
					for sg in lg.segs.duplicate():
						if lg.round_i != r: break
						var a: Vector2 = sg[0]; var e: Vector2 = sg[1]
						for k in 20: lg._stroke(a.lerp(e, k / 20.0), a.lerp(e, (k + 1) / 20.0))
					L("   lube r%d cov=%.2f mess=%.2f round_i=%d segs=%d" % [r, lg.cov(), lg.mess, lg.round_i, lg.segs.size()])
					if lg.round_i == r: lg.finish_round()
				else:
					lg.t0 = Time.get_ticks_msec()
					for k in 18: lg._stroke(Vector2(0.3 if k % 2 == 0 else 0.7, 0.5), Vector2(0.7 if k % 2 == 0 else 0.3, 0.5))
			L("  lubeQ=" + str(b.lubeQ))
		"sw":
			var ok := 0
			for i in b.ks.size():
				var inf := key_inf(i)
				if inf.i == i: ok += 1
				asm().down(inf); asm().up(inf)
			var bent := 0
			for i in b.ks.size():
				if int(b.ks[i].b) == 1:
					asm().set_tool("pull"); asm().down(key_inf(i)); asm().set_tool("main"); asm().down(key_inf(i)); bent += 1
			L("  sw picks ok %d/%d, re-seated bent %d" % [ok, b.ks.size(), bent])
		"solder":
			for i in b.ks.size():
				asm()._hold = true; asm()._cur = i
				for k in 3: asm()._process(0.12)
			asm()._hold = false
		"screw":
			var z := Asm.torque_zone()
			for j in Keyboard3D.SCREW_ORDER:
				var p: Vector2 = ws().screen_of_screw(j)
				var inf: Dictionary = ws().ray_at(p)
				if inf.scr != j: L("  screw pick mismatch %d -> %d" % [j, inf.scr])
				inf.scr = j
				asm().down(inf)
				var guard := 0
				while asm()._tq < (z.plo + z.phi) / 2.0 and guard < 200: asm()._process(0.05); guard += 1
				if guard >= 200: L("  screw %d did not engage" % j)
				asm().up(inf)
			L("  screws " + str(b.screws))
		"kc":
			var Lk: Array = Data.LAYOUTS[b.layout].keys
			for r in int(Data.LAYOUTS[b.layout].rows):
				asm().kit = r
				for i in b.ks.size():
					if int(Lk[i].row) == r: asm().down(key_inf(i))
			var w := 0
			for k in b.ks: if int(k.w) == 1: w += 1
			L("  wrong caps %d" % w)
		"keytest":
			asm().autotest()
			await get_tree().create_timer(2.0).timeout
