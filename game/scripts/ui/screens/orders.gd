extends Screen

func content(first: bool) -> Control:
	var S = g()
	var v = UIK.vbox(16)
	var next = Data.DAY_SEC - float(S.dayT)
	v.add_child(UIK.head("Доска заказов · %d/%d" % [S.orders.size(), Game.order_slots()], "Клиенты ждут", [trend_chip(), UIK.chip("Новые заказы через " + Game.dur(next))]))
	if int(S.tut) < Game.TUT.size(): v.add_child(UIK.note("[b]Первые шаги %d/%d:[/b] %s  [color=#ebc66c]+%s[/color]" % [int(S.tut) + 1, Game.TUT.size(), Game.TUT[int(S.tut)].t, Game.rub(Game.TUT[int(S.tut)].r)], UIK.GOLD))
	if S.orders.is_empty():
		v.add_child(empty_state("Сейчас заказов нет. Новые клиенты приходят каждый игровой день.", "clipboard"))
	else:
		var gr = UIK.grid(grid_cols())
		for o in S.orders: gr.add_child(_card(o))
		v.add_child(gr)
	if S.boards.is_empty() and S.orders.any(func(o): return o.kind != "repair"):
		v.add_child(UIK.note("На складе нет готовых клавиатур. Соберите клавиатуру в «Мастерской» под требования клиента.", UIK.WARN))
	v.add_child(UIK.label("Звёзды зависят от того, сколько требований выполнено, и от качества сборки. За 5★ — чаевые и шанс получить артизан. Просроченные заказы бьют по репутации.", "SmallMuted", true))
	return v

func _ava(name: String, col: Color) -> Control:
	var ini = ""
	for w in name.replace("«", "").replace("»", "").split(" ", false): ini += w.left(1)
	var p = PanelContainer.new(); p.custom_minimum_size = Vector2(42, 42)
	p.add_theme_stylebox_override("panel", UIK.sb(col, 21, Color(1, 1, 1, 0.2), 0))
	var l = UIK.label(ini.left(2), "H3"); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Color("0d1114")); p.add_child(l)
	return p

func _card(o: Dictionary) -> Control:
	var S = g()
	var vip: bool = o.kind == "vip"
	var left: int = int(o.expires) - int(S.day)
	var rp: bool = o.kind == "repair"
	var story: bool = rp and int(o.get("story", -1)) >= 0
	var sub_t: String = ("VIP · %s · глава %d/3" % [o.role, int(o.stage) + 1]) if vip else ("первый клиент" if o.kind == "tut" else ("ремонт · без срока" if story else ((("ремонт · " if rp else "") + ("последний день" if left <= 0 else "ждёт ещё %d дн." % left)))))
	var v = UIK.vbox(10)
	var st = UIK.label(sub_t, "SmallMuted")
	if left <= 0 and not vip and o.kind != "tut" and not story: st.add_theme_color_override("font_color", UIK.BAD)
	v.add_child(UIK.hbox(10, [_ava(o.name, Color(o.col)), UIK.expand(UIK.vbox(0, [UIK.label(o.name, "H3"), st])), UIK.label(Game.rub(o.budget), "Price")]))
	var q = UIK.card("Note", UIK.label("«%s»" % o.text, "Small", true)); v.add_child(q)
	var chips = UIK.flow(5)
	if rp:
		var bd: Dictionary = o.board
		chips.add_child(UIK.chip("Ремонт", UIK.CORAL)); chips.add_child(UIK.chip(Data.LAYOUTS[bd.layout].name))
		chips.add_child(UIK.chip(Data.kc(bd.kc).name)); chips.add_child(UIK.chip(Data.sw(bd.sw).name))
		chips.add_child(UIK.chip("Дефектов: %d" % (o.faults as Array).size(), UIK.GOLD))
		v.add_child(chips)
		var row0 = UIK.hbox(6)
		var busy: bool = S.build != null and not o.get("taken", false)
		var take = UIK.button("Продолжить ремонт" if o.get("taken", false) else "Взять в ремонт", "BtnPri", func():
			if o.get("taken", false) or Game.start_repair(o.id): main.open_tab("workshop"), "wrench")
		take.disabled = busy
		if busy: take.tooltip_text = "Верстак занят текущей работой"
		row0.add_child(take)
		if not story and not o.get("taken", false): row0.add_child(UIK.button("Отклонить", "BtnGhost", func(): Game.decline_order(o.id)))
		row0.add_child(UIK.spacer())
		row0.add_child(UIK.button("", "BtnGhost", func(): main.sub["map_focus"] = o.id; main.open_tab("map"), "map"))
		v.add_child(row0)
		return UIK.card("Card", v)
	var req: Dictionary = o.req
	if req.has("layout"): chips.add_child(UIK.chip("Формат " + Data.LAYOUTS[req.layout].name))
	if req.has("sound"): chips.add_child(UIK.chip({"thock": "Thock", "clack": "Clack", "silent": "Тихая", "clicky": "Клики"}[req.sound], UIK.CORAL))
	if req.has("stype"): chips.add_child(UIK.chip("Свитчи: " + Data.STYPE[req.stype]))
	if req.has("switch"): chips.add_child(UIK.chip("«%s»" % Data.sw(req.switch).name))
	if req.has("tag"): chips.add_child(UIK.chip(Data.TAGS[req.tag], UIK.VIOLET))
	if req.has("qMin"): chips.add_child(UIK.chip("Качество ≥%d" % int(req.qMin), UIK.GOLD))
	if req.has("smoothMin"): chips.add_child(UIK.chip("Гладкость ≥%d" % int(req.smoothMin)))
	for k in [["rgb", "RGB"], ["wl", "Беспроводная"], ["hs", "Hotswap"], ["artisan", "Артизан"]]:
		if req.get(k[0], false): chips.add_child(UIK.chip(k[1]))
	if chips.get_child_count() == 0: chips.add_child(UIK.chip("Без особых требований"))
	v.add_child(chips)
	var row = UIK.hbox(6)
	var give = UIK.button("Отдать клавиатуру", "BtnPri", func(): _deliver_modal(o), "truck"); give.disabled = S.boards.is_empty()
	row.add_child(give)
	if not vip: row.add_child(UIK.button("Отклонить", "BtnGhost", func(): Game.decline_order(o.id)))
	row.add_child(UIK.spacer())
	row.add_child(UIK.button("", "BtnGhost", func(): main.sub["map_focus"] = o.id; main.open_tab("map"), "map"))
	v.add_child(row)
	return UIK.card("CardVip" if vip else "Card", v)

func _deliver_modal(o: Dictionary) -> void:
	var rows = []
	for b in g().boards: rows.append({"b": b, "r": Game.eval_order(o, b)})
	rows.sort_custom(func(a, c): return a.r.stars > c.r.stars or (a.r.stars == c.r.stars and a.r.pay > c.r.pay))
	var v = UIK.vbox(12, [main.modal_head("Заказ: " + o.name), UIK.card("Note", UIK.label("«%s»" % o.text, "Small", true)), UIK.label("Бюджет %s. Выберите клавиатуру со склада:" % Game.rub(o.budget), "Muted")])
	for x in rows:
		var b: Dictionary = x.b; var r: Dictionary = x.r
		var c = UIK.vbox(8)
		c.add_child(UIK.hbox(10, [KbThumb.make(b, 54), UIK.expand(UIK.vbox(1, [UIK.label(b.name, "H3"), UIK.label("%s · %s · качество %d · себест. %s" % [Data.LAYOUTS[b.layout].name, Game.sound_label(b.st), int(b.st.quality), Game.rub(b.cost)], "SmallMuted")])), UIK.stars(r.stars)]))
		(c.get_child(0).get_child(0) as Control).custom_minimum_size.x = 120
		var chips = UIK.flow(5)
		for ch in r.ch: chips.add_child(UIK.chip(("✓ " if ch.ok else "✕ ") + ch.label, UIK.GOOD if ch.ok else UIK.BAD))
		c.add_child(chips)
		var pay = "Оплата [color=#ebc66c]%s[/color]" % Game.rub(r.pay) + (" + чаевые [color=#ebc66c]%s[/color]" % Game.rub(r.tip) if r.tip > 0 else "") + " · рыночная цена " + Game.rub(Game.board_value(b))
		c.add_child(UIK.hbox(8, [UIK.expand(UIK.rich(pay, 13)), UIK.button("Отдать", "BtnPri", func(): _deliver(o, b), "check")]))
		v.add_child(UIK.card("Card", c))
	main.open_modal(v, 760)

func _deliver(o: Dictionary, b: Dictionary) -> void:
	main.close_modal()
	var r = Game.deliver_order(o.id, b.uid)
	if r.is_empty(): return
	main.sub["courier"] = o.get("district", Vector2(0.5, 0.5))
	if int(r.stars) >= 5: main.flash(Color(1, 0.85, 0.4, 0.2))
