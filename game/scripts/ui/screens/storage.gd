extends Screen

func content(first: bool) -> Control:
	var S = g()
	var v = UIK.vbox(16)
	v.add_child(UIK.head("Склад · занято %d из %d" % [Game.used_storage(), Game.storage_cap()], "Склад", [UIK.button("Карта складов", "BtnGhost", func(): main.open_tab("map"), "map")]))
	var cap = UIK.bar(float(Game.used_storage()) / Game.storage_cap(), UIK.BAD if Game.used_storage() >= Game.storage_cap() else UIK.TEAL, 6); v.add_child(cap)
	var nbox = 0
	for k in S.inv.boxes: nbox += int(S.inv.boxes[k])
	v.add_child(subtabs("storage", [["boards", "Готовые (%d)" % S.boards.size()], ["parts", "Детали"], ["art", "Артизаны (%d)" % S.inv.art.size()], ["boxes", "Коробки (%d)" % nbox]], "boards"))
	match cur_sub("storage", "boards"):
		"boards":
			if S.boards.is_empty(): v.add_child(empty_state("Готовых клавиатур нет. Соберите первую в «Мастерской».", "keyboard"))
			else:
				var gr = UIK.grid(grid_cols())
				for b in S.boards: gr.add_child(BoardUI.card(main, b))
				v.add_child(gr)
		"parts": v.add_child(_parts())
		"art": v.add_child(_arts())
		"boxes":
			v.add_child(UIK.label("Коробки открываются во вкладке «Коробки».", "Muted"))
			v.add_child(UIK.button("Открыть коробки", "BtnPri", func(): main.open_tab("boxes"), "gift"))
	return v

func _row(left: Control, right: String) -> HBoxContainer:
	return UIK.hbox(8, [UIK.expand(left), UIK.label(right, "Num")])

func _parts() -> Control:
	var S = g()
	var grid = UIK.grid(2 if size.x > 900 else 1, 16)
	var col = func(cats: Array) -> Control:
		var v = UIK.vbox(6)
		for cat in cats:
			v.add_child(UIK.label(Data.CAT_NAMES[cat], "H3"))
			var gr = {}; var order = []
			for it in S.inv.items:
				if it.cat != cat: continue
				var k = "%s|%s|%s" % [it.id, it.get("layout", ""), it.get("color", "")]
				if not gr.has(k): gr[k] = {"it": it, "n": 0}; order.append(k)
				gr[k].n += 1
			if order.is_empty(): v.add_child(UIK.label("Пусто", "SmallMuted"))
			for k in order:
				var it: Dictionary = gr[k].it; var d = Data.item(cat, it.id)
				var h = UIK.hbox(6)
				if cat == "case": h.add_child(UIK.swatch(Color(d.colors[int(it.get("color", 0))][1]), 12))
				if cat == "kc": h.add_child(UIK.swatch(Color(d.c.a), 12)); h.add_child(UIK.swatch(Color(d.c.m), 12))
				h.add_child(UIK.label(d.name + (" · " + Data.LAYOUTS[it.layout].name if it.has("layout") else ""), "Small"))
				v.add_child(_row(h, "×%d" % gr[k].n))
			v.add_child(UIK.vspace(6))
		return UIK.card("Card", v)
	grid.add_child(UIK.expand(col.call(["case", "plate", "pcb"])))
	var right = UIK.vbox(6, [UIK.label("Свитчи", "H3")])
	var any = false
	for id in S.inv.sw:
		if int(S.inv.sw[id]) <= 0: continue
		any = true; var s = Data.sw(id)
		right.add_child(_row(UIK.hbox(6, [UIK.swatch(Color(s.stem), 12), UIK.label("%s · %s" % [s.name, Data.STYPE[s.type]], "Small")]), "%d шт" % int(S.inv.sw[id])))
	if not any: right.add_child(UIK.label("Пусто", "SmallMuted"))
	right.add_child(UIK.vspace(6)); right.add_child(UIK.label("Расходники", "H3"))
	for c in Data.CONS: right.add_child(_row(UIK.label(c.name, "Small"), "×%d" % int(S.inv.cons.get(c.id, 0))))
	var rc = UIK.card("Card", right)
	var st = col.call(["stab", "kc"])
	grid.add_child(UIK.expand(UIK.vbox(16, [st, rc])))
	return grid

func _arts() -> Control:
	var S = g()
	var cnt = {}
	for a in S.inv.art:
		var id = Game.art_base_id(a); cnt[id] = int(cnt.get(id, 0)) + 1
	if cnt.is_empty(): return empty_state("Артизанов пока нет. Они выпадают из коробок и за VIP-заказы.", "star")
	var gr = UIK.grid(max(2, grid_cols() + 1))
	for id in cnt:
		var A = Data.art(id); var col = Keyboard3D.art_color(A)
		var ic = PanelContainer.new(); ic.custom_minimum_size = Vector2(64, 64)
		ic.add_theme_stylebox_override("panel", UIK.sb(col, 14, Color(1, 1, 1, 0.3), 0))
		var gl = UIK.label(str(A.g), "H2"); gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; gl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; ic.add_child(gl)
		var v = UIK.vbox(6, [ic, UIK.colored(A.name, Data.RAR_COL[A.r], "H3"), UIK.label("%s · ×%d" % [Data.RAR_NAME[A.r], cnt[id]], "SmallMuted"), UIK.label("+%s к цене сборки" % Game.rub(Data.ART_BASE * float(Data.RARITY[A.r].val) * Game.city_k()), "Small")])
		for c in v.get_children(): c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		gr.add_child(UIK.card("Card", v))
	return gr
