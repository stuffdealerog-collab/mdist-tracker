extends Node
## The assembled keyboard with the keycaps hidden: switches, stabilizers and the plate in view (parts review).
##   bash tools/safe_test.sh res://tests/kb_bare.tscn -- <layout> <stab> <sw> <out.png>
var f := 0
var ws
var out := ""
func _ready():
	var a := OS.get_cmdline_user_args()
	var lay: String = a[0] if a.size() > 0 else "l65"
	var stab: String = a[1] if a.size() > 1 else "s_screw"
	var sw: String = a[2] if a.size() > 2 else "sw_red"
	out = a[3] if a.size() > 3 else "user://kb_bare.png"
	Game.S = Game.new_state()
	var at := LegendAtlas.new(); add_child(at); at.build()
	ws = Workshop.new(); add_child(ws)
	ws.kb.show_spec({"layout": lay, "case": "c_alu", "color": 1, "plate": "p_alu", "pcb": "b_hs", "stab": stab, "kc": "k_miami", "sw": sw, "mods": {}})
	ws.fit_keyboard(); ws.set_view("persp"); ws.idle_spin = false; ws.orb = ws.orb_goal.duplicate()
func _process(_d):
	f += 1
	if f == 3:
		for o in ws.kb.keys: o.cap.visible = false
	if f == 60:
		get_viewport().get_texture().get_image().save_png(out); get_tree().quit()
