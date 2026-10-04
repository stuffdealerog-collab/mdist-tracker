class_name ItemTile
extends PanelContainer
## Tile for a box/trade entry {kind, id, n, rarity, name}.

static func make(e: Dictionary, w := 132.0, compact := false) -> ItemTile:
	var t = ItemTile.new()
	var col: Color = Data.RAR_COL.get(e.get("rarity", "common"), UIK.MUTE)
	var s = UIK.sb(Color(col.r, col.g, col.b, 0.1), 12, Color(col, 0.55), 10, 2)
	t.add_theme_stylebox_override("panel", s)
	t.custom_minimum_size = Vector2(w, w * (0.95 if compact else 1.15))
	var v = UIK.vbox(6); v.alignment = BoxContainer.ALIGNMENT_CENTER
	var ic: Control
	match e.get("kind", ""):
		"sw":
			ic = SwitchIcon.make(e.id, w * 0.42); ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		"kc":
			ic = CapsRow.make(e.id, w * 0.15)
			ic.custom_minimum_size = Vector2(w * 0.15 * 7.4, w * 0.15)
		_:
			var A = Data.art(str(e.id))
			var p = PanelContainer.new(); p.custom_minimum_size = Vector2(w * 0.42, w * 0.42)
			p.add_theme_stylebox_override("panel", UIK.sb(Keyboard3D.art_color(A), int(w * 0.21), Color(1, 1, 1, 0.35), 0))
			var gl = UIK.label(str(A.get("g", "✦")), "H2"); gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; gl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			p.add_child(gl); ic = p
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var nl = UIK.label(str(e.get("name", "")), "Small", true); nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.custom_minimum_size.x = w - 20
	if compact: nl.add_theme_font_size_override("font_size", 11)
	v.add_child(nl)
	if not compact:
		var rl = UIK.colored(Data.RAR_NAME.get(e.get("rarity", "common"), ""), col, "SmallMuted"); rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(rl)
	t.add_child(v)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t
