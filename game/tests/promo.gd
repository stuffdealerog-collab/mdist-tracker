extends Node
## Renders store screenshots and clean hero frames. Args: -- <outdir>
var main
var f := 0
var step := 0
var wait := 0
var out := ""

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0] if a.size() > 0 else "/tmp/claude-0/-home-user-mdist-tracker/28c0084d-b286-5cd8-9401-8ae7cf7cb680/scratchpad/promo"
	DirAccess.make_dir_recursive_absolute(out)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)

func shot(n: String) -> void:
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, n]); print("shot ", n)

func board(layout, cs, col, kc, sw, art, pcb := "b_hs") -> Dictionary:
	var b := {"uid": Game.uid(), "name": "Сборка", "cost": 40000.0, "made": 3, "layout": layout, "case": cs, "color": col, "plate": "p_brass", "pcb": pcb, "stab": "s_screw", "kc": kc, "sw": sw, "mods": {"foam": true, "lube": true}, "art": art, "lubeQ": 0.95, "precision": 0.95}
	b.st = Game.board_stats(b); b.name = Game.auto_name(b)
	return b

func _process(_d: float) -> void:
	f += 1
	if f < 30: return
	wait -= 1
	if wait > 0: return
	match step:
		0:
			if main.modal_open(): main.close_modal(true)
			var S: Dictionary = Game.S
			S.seenIntro = true; S.level = 16; S.money = 2847500; S.xp = 1200; S.rep = 4.6; S.day = 42
			S.owned_props = ["garage", "loft", "studio", "boutique"]; S.property = "boutique"; S.shop = "Мастерская «Тёплый клик»"
			S.boards.append(board("l75", "c_heavy", 1, "k_gold", "sw_obsid", "a_moon"))
			S.boards.append(board("l65", "c_gasket", 0, "k_holo", "sw_holo", null, "b_rgb"))
			S.boards.append(board("tkl", "c_wood", 0, "k_matcha", "sw_red", null))
			S.listings.append({"uid": S.boards[2].uid, "price": 61000.0})
			for i in 3: Game.refill_orders(1)
			Game.add_box("box_art", 2); Game.add_box("box_pro", 1)
			main.ws.set_style("boutique")
			main.ui.visible = false
			if main.screen: main.screen.queue_free(); main.screen = null
			S.settings.gfx = "high"; main.ws.apply_quality()
			main.ws.kb.show_spec(S.boards[0], null); main.ws.fit_keyboard(); main.ws.frame_offset = 0.0
			main.ws.idle_spin = false; main.ws.set_view("hero"); main.ws.orb_goal.theta = -0.6; main.ws.orb_goal.phi = 1.0; main.ws.orb_goal.dist = main.ws.fit_dist * 0.62
			main.ws.orb = main.ws.orb_goal.duplicate()
			step = 1; wait = 50
		1:
			shot("hero_clean")
			main.ws.orb_goal.theta = 0.0; main.ws.orb_goal.phi = 0.55; main.ws.orb_goal.dist = main.ws.fit_dist * 0.75; main.ws.orb = main.ws.orb_goal.duplicate()
			step = 2; wait = 40
		2:
			shot("hero_top_clean")
			main.ws.kb.show_spec(Game.S.boards[1], null)
			main.ws.orb_goal.theta = 0.5; main.ws.orb_goal.phi = 1.1; main.ws.orb_goal.dist = main.ws.fit_dist * 0.5; main.ws.orb = main.ws.orb_goal.duplicate()
			step = 3; wait = 40
		3:
			shot("hero_rgb_clean")
			main.ws.orb_goal.phi = 1.15; main.ws.orb_goal.theta = -0.35; main.ws.orb_goal.dist = 2.2; main.ws.orb = main.ws.orb_goal.duplicate()
			main.ws.kb.show_spec(Game.S.boards[0], null)
			step = 4; wait = 40
		4:
			shot("room_clean")
			main.ui.visible = true
			main.open_tab("workshop", false)
			step = 5; wait = 40
		5:
			main.ws.orb = main.ws.orb_goal.duplicate()
			step = 6; wait = 20
		6:
			shot("s1_workshop")
			main.open_tab("orders", false); step = 7; wait = 30
		7:
			shot("s2_orders"); main.open_tab("map", false); step = 8; wait = 30
		8:
			shot("s3_map"); main.open_tab("storage", false); step = 9; wait = 30
		9:
			shot("s4_storage"); main.open_tab("boxes", false); step = 10; wait = 30
		10:
			main.screen._open(Data.box("box_art")); step = 11; wait = 45
		11:
			shot("s5_box"); main.close_modal(true); main.open_tab("market", false); main.sub["market"] = "kc"; main.screen.build_screen(true); step = 12; wait = 30
		12:
			shot("s6_market"); main.open_tab("growth", false); main.sub["growth"] = "prop"; main.screen.build_screen(true); step = 13; wait = 30
		13:
			shot("s7_props"); get_tree().quit()
