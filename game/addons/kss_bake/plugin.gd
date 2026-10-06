@tool
extends EditorPlugin
## Step 2 of the lightmap bake (step 1: tests/bake_export.tscn). Does nothing unless the editor is started with
## KSS_BAKE=1: then it opens res://bake/room_day.scn and room_night.scn, bakes their LightmapGI, saves and quits.

func _enter_tree() -> void:
	if OS.has_environment("KSS_BAKE"): _run.call_deferred()

func _frames(n: int) -> void:
	for i in n: await get_tree().process_frame

func _run() -> void:
	await get_tree().create_timer(4.0).timeout
	for v in ["day", "night"]:
		var path = "res://bake/room_%s.scn" % v
		EditorInterface.open_scene_from_path(path)
		await _frames(30)
		var root = EditorInterface.get_edited_scene_root()
		var lm: LightmapGI = root.get_node_or_null("LightmapGI") if root else null
		if lm == null:
			print("[kss_bake] no LightmapGI in ", path); break
		EditorInterface.set_main_screen_editor("3D")
		EditorInterface.get_selection().clear(); EditorInterface.get_selection().add_node(lm); EditorInterface.edit_node(lm)
		await _frames(15)
		var btn = _find(EditorInterface.get_base_control())
		if btn == null:
			print("[kss_bake] bake button not found"); break
		var t0 = Time.get_ticks_msec()
		btn.pressed.emit()
		await _frames(10)
		# first press asks where to put the .lmbake: answer the file dialog with the scene's own name
		var fd = _file_dialog(EditorInterface.get_base_control())
		if fd:
			var out = path.get_basename() + ".lmbake"
			fd.hide(); fd.file_selected.emit(out)
			await _frames(10)
		print("[kss_bake] %s: %.1f s, data=%s" % [v, (Time.get_ticks_msec() - t0) / 1000.0, lm.light_data.resource_path if lm.light_data else "NONE"])
		EditorInterface.save_scene()
		await _frames(20)
	get_tree().quit()

func _find(n: Node) -> Button:
	if n is Button:
		var t = (n as Button).text.to_lower()
		if "lightmap" in t or "освещ" in t: return n
	for c in n.get_children():
		var r = _find(c)
		if r: return r
	return null

func _file_dialog(n: Node) -> Node:
	if (n is EditorFileDialog or n is FileDialog) and n.visible: return n
	for c in n.get_children():
		var r = _file_dialog(c)
		if r: return r
	return null
