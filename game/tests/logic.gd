extends SceneTree
var f := 0
func _process(_d):
	f += 1
	if f != 2: return false
	var G = root.get_node("Game")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	G.boot()
	print("money ", G.S.money, " orders ", G.S.orders.size(), " items ", G.S.inv.items.size())
	var items = G.S.inv.items
	for it in items: it.loc = "bench"   # parts are brought from the shelf to the bench first
	var d = {"layout":"l60","case":items[0].uid,"plate":items[1].uid,"pcb":items[2].uid,"stab":items[3].uid,"kc":items[4].uid,"sw":"sw_red","mods":{},"art":null}
	print("start ", G.start_build(d), " steps ", G.S.build.steps)
	for k in G.S.build.ks: k.s=1; k.c=1; k.t=1; k.so=1
	G.S.build.pieces = {"pcb":1,"plate":1}; G.S.build.precision = 0.9
	var b = G.finish_build("")
	print("built ", b.name, " q=", b.st.quality, " val=", G.board_value(b))
	var o = G.S.orders[0]
	var r = G.deliver_order(o.id, b.uid)
	print("delivered stars ", r.stars, " pay ", r.pay, " money ", G.S.money)
	print("buy case ", G.buy_part("case","c_abs","l60",1), " buy sw ", G.buy_switch("sw_yellow", 70))
	for i in 3: G.new_day()
	print("day ", G.S.day, " orders ", G.S.orders.size())
	G.add_box("box_sw", 2); G.add_box("box_art", 1)
	print("box ", G.open_box_local("box_sw"), "\n art box ", G.open_box_local("box_art"))
	G.S.money = 1e7; G.S.level = 30
	print("prop ", G.buy_property("loft"), " cap ", G.storage_cap(), " shelf ", G.shelf_slots())
	G.ensure_traders(); print("traders ", G.S.traders.offers.size())
	print("tradeable ", G.tradeable_items().size())
	G.add_xp(5000); print("level ", G.S.level)
	G.ach_tick(); print("ach ", G.S.ach.keys())
	G.save_game(); var m = G.S.money; G.S = {}; print("load ", G.load_game(), " money eq ", G.S.money == m)
	print("upgrade desc ", root.get_node("Data").upgrade_desc("driver", 2))
	print("LOGIC_OK")
	quit()
	return false
