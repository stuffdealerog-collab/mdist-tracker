extends Node
## Renders the workshop with an assembled keyboard. Args: -- <style> <layout> <kc> <case> <out>
var f := 0
var ws
var out := ""
func _ready():
	var a := OS.get_cmdline_user_args()
	var style: String = a[0] if a.size() > 0 else "garage"
	var lay: String = a[1] if a.size() > 1 else "l65"
	var kc: String = a[2] if a.size() > 2 else "k_miami"
	var cs: String = a[3] if a.size() > 3 else "c_alu"
	out = a[4] if a.size() > 4 else "/tmp/claude-0/-home-user-mdist-tracker/28c0084d-b286-5cd8-9401-8ae7cf7cb680/scratchpad/kb3d.png"
	var view: String = a[5] if a.size() > 5 else "persp"
	var game = Game
	game.S = game.new_state()
	game.S.property = style
	var at := LegendAtlas.new(); add_child(at); at.build()
	ws = Workshop.new(); add_child(ws)
	ws.kb.show_spec({"layout": lay, "case": cs, "color": 1, "plate": "p_alu", "pcb": "b_rgb" if style == "flagship" else "b_hs", "stab": "s_basic", "kc": kc, "sw": "sw_red", "art": "a_moon", "mods": {}})
	ws.fit_keyboard(); ws.set_view(view); ws.idle_spin = false
	ws.orb = ws.orb_goal.duplicate()
func _process(_d):
	f += 1
	if f == 5: print("cam ", get_viewport().get_camera_3d(), " pos ", ws.cam.global_position, " kb children ", ws.kb.get_child_count(), " room ", ws.room.get_child_count())
	if f == 59 and Mats.legend_atlas: Mats.legend_atlas.get_image().save_png(out.replace(".png","_atlas.png"))
	if f == 60:
		get_viewport().get_texture().get_image().save_png(out); get_tree().quit()

