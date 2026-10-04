extends Node
## Boots the real game and screenshots every tab. Args: -- <outdir> [tabs...]
var f := 0
var main
var tabs := []
var out := ""
var idx := -1
var wait := 0

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0] if a.size() > 0 else "/tmp/claude-0/-home-user-mdist-tracker/28c0084d-b286-5cd8-9401-8ae7cf7cb680/scratchpad/shots"
	DirAccess.make_dir_recursive_absolute(out)
	tabs = a.slice(1) if a.size() > 1 else ["workshop", "orders", "market", "storage", "shop", "map", "boxes", "trade", "growth", "events", "collection"]
	if not "keep" in a: DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	tabs.erase("keep"); tabs.erase("low"); tabs.erase("modal")
	main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)

func _process(_d: float) -> void:
	f += 1
	if f < 40: return
	if idx == -1:
		if main.modal_open(): main.close_modal(true)
		Game.S.seenIntro = true
		if "low" in OS.get_cmdline_user_args(): Game.S.settings.gfx = "low"; main.ws.apply_quality()
		idx = 0; main.open_tab(tabs[0], false); wait = 0; return
	wait += 1
	if wait == 8 and tabs[idx] == "boxes" and "modal" in OS.get_cmdline_user_args():
		Game.add_box("box_sw", 1); main.screen._open(Data.box("box_sw"))
	if wait == 25:
		get_viewport().get_texture().get_image().save_png("%s/%02d_%s.png" % [out, idx, tabs[idx]])
		print("shot ", tabs[idx])
		idx += 1
		if idx >= tabs.size(): get_tree().quit(); return
		main.open_tab(tabs[idx], false); wait = 0
