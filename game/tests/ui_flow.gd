extends Node
## Headless smoke test of UI interactions (catches script errors in rarely used paths).
var main
var f := 0
var errors := 0

func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)

func ok(c: bool, msg: String) -> void:
	if not c: errors += 1
	print(("ok   " if c else "FAIL ") + msg)

func pump(n := 3) -> void:
	for i in n: await get_tree().process_frame

func _process(_d: float) -> void:
	f += 1
	if f != 10: return
	run()

func run() -> void:
	if main.modal_open(): main.close_modal(true)
	var S: Dictionary = Game.S
	S.seenIntro = true; S.money = 5000000; S.level = 20; S.sp = 5
	# market: every category
	main.open_tab("market"); await pump()
	for cat in ["case", "plate", "pcb", "stab", "sw", "kc", "cons", "gb"]:
		main.sub["market"] = cat; main.screen.build_screen(true); await pump(2)
	ok(Game.buy_part("case", "c_alu", "l65", 2), "buy case")
	ok(Game.buy_part("plate", "p_pc", "l65"), "buy plate")
	ok(Game.buy_part("pcb", "b_rgb", "l65"), "buy pcb")
	ok(Game.buy_part("stab", "s_screw"), "buy stab")
	ok(Game.buy_part("kc", "k_bow"), "buy kc")
	ok(Game.buy_switch("sw_brown", 70), "buy switches")
	Game.buy_gb("sw"); Game.buy_gb("kc"); Game.buy_gb("art")
	ok(S.gb.pending.size() == 3, "group buy pending")
	Game.debug_receive_all()
	# quick-build a board through the API (first build is short)
	var it := func(cat, id): for x in S.inv.items: if x.cat == cat and x.id == id: return x.uid
	var started := Game.start_build({"layout": "l65", "case": it.call("case", "c_alu"), "plate": it.call("plate", "p_pc"), "pcb": it.call("pcb", "b_rgb"), "stab": it.call("stab", "s_screw"), "kc": it.call("kc", "k_bow"), "sw": "sw_brown", "mods": {}, "art": null})
	ok(started, "start build")
	main.open_tab("workshop"); await pump(5)
	main.ws.asm.auto(); await pump()
	while main.ws.asm.step() != "test":
		main.ws.asm.auto(); main.ws.asm.next_step(true); await pump(2)
	main.screen._finish("Флоу-тест"); await pump(5)
	main.close_modal(true)
	ok(S.boards.size() == 1, "board finished")
	var b: Dictionary = S.boards[0]
	# storage / listen / list
	main.open_tab("storage"); await pump(3)
	for sub in ["boards", "parts", "art", "boxes"]:
		main.sub["storage"] = sub; main.screen.build_screen(true); await pump(2)
	BoardUI.listen(main, b); await pump(10); main.close_modal(true)
	BoardUI.list_modal(main, b); await pump(3); main.close_modal(true)
	ok(Game.list_board(b.uid, 50000), "list board")
	main.open_tab("shop"); await pump(3)
	Game.unlist(b.uid); ok(S.listings.is_empty(), "unlist")
	# orders
	main.open_tab("orders"); await pump(3)
	main.screen._deliver_modal(S.orders[0]); await pump(3); main.close_modal(true)
	# map
	main.open_tab("map"); await pump(3)
	main.screen.select({"type": "supplier", "s": Data.SUPPLIERS[0]}); await pump()
	main.screen.select({"type": "prop", "p": Data.PROPERTIES[1]}); await pump()
	main.screen.select({"type": "order", "o": S.orders[0]}); await pump()
	main.screen.map.courier(Vector2(0.7, 0.3)); await pump(5)
	# boxes (local)
	main.open_tab("boxes"); await pump(3)
	ok(Game.buy_box("box_sw"), "buy box")
	var e := Game.open_box_local("box_sw"); ok(not e.is_empty(), "open box: " + str(e.get("name")))
	main.screen._roulette(Data.box("box_sw"), Game.roll_box("box_sw")); await pump(10); main.close_modal(true)
	# trade with NPC
	main.open_tab("trade"); await pump(3)
	main.sub["trade"] = "npc"; main.screen.build_screen(true); await pump(3)
	Game.ensure_traders()
	var traded := false
	for o in S.traders.offers.duplicate():
		for t in Game.tradeable_items():
			if t.kind == o.want.kind and Data.RAR_ORDER.find(t.rarity) >= Data.RAR_ORDER.find(o.want.rarity):
				traded = Game.accept_npc_trade(o.id, t); break
		if traded: break
	print("     npc trade possible: ", traded)
	main.screen._pick_give({"kind": "sw", "rarity": "common"}, func(t): pass); await pump(3); main.close_modal(true)
	# growth
	main.open_tab("growth"); await pump(3)
	for sub in ["up", "sk", "prop", "pr"]:
		main.sub["growth"] = sub; main.screen.build_screen(true); await pump(2)
	Game.buy_upgrade("bench"); Game.buy_skill("luck")
	ok(Game.upl("bench") == 1 and Game.skl("luck") == 1, "upgrade + skill")
	ok(Game.buy_property("loft"), "buy loft"); main.ws.set_style("loft"); await pump(3)
	ok(S.property == "loft", "moved to loft")
	# events
	main.open_tab("events"); await pump(3)
	Game.claim_login(); ok(S.login.claimed == Game.today_str(), "claim login")
	main.screen._contest_pick(); await pump(3); main.close_modal(true)
	# collection
	main.open_tab("collection"); await pump(3)
	for sub in ["sw", "kc", "art", "ach", "stats"]:
		main.sub["collection"] = sub; main.screen.build_screen(true); await pump(2)
	# modals
	Settings.open(main); await pump(3); main.close_modal(true)
	Intro.open(main, 0); await pump(2); Intro.open(main, 5); await pump(2); main.close_modal(true)
	main._on_level_up(21, ["Корпус X"]); await pump(5)
	Game.earn(12345, "тест"); await pump(5)
	# save/load roundtrip
	Game.save_game(); ok(Game.load_game(), "save/load roundtrip")
	print("UI_FLOW_DONE errors=", errors)
	get_tree().quit()
