extends Screen

const MCATS := [["case", "Корпуса"], ["plate", "Пластины"], ["pcb", "Платы"], ["stab", "Стабы"], ["sw", "Свитчи"], ["kc", "Кейкапы"], ["cons", "Расходники"], ["gb", "Group buy"]]

func content(first: bool) -> Control:
	var S = g()
	var v = UIK.vbox(14)
	var sup = Data.supplier(S.market.supplier)
	v.add_child(UIK.head("Поставщик: %s · склад %d/%d" % [sup.name, Game.used_storage(), Game.storage_cap()], "Рынок деталей", [UIK.chip("Деньги: " + Game.rub(S.money), UIK.GOLD)]))
	# suppliers strip
	var sf = UIK.flow(6)
	for s in Data.SUPPLIERS:
		var lock: bool = int(s.lvl) > int(S.level)
		var b = UIK.button(s.name + (" · %d ур." % int(s.lvl) if lock else ""), "Sub", func(): S.market.supplier = s.id; Game.mark(); Audio.ui("whoosh"); build_screen(true), "truck")
		b.toggle_mode = true; b.button_pressed = s.id == S.market.supplier; b.disabled = lock; b.tooltip_text = s.desc
		sf.add_child(b)
	v.add_child(sf)
	v.add_child(UIK.label(sup.desc + " Поставщика можно сменить и на карте города.", "SmallMuted", true))
	v.add_child(subtabs("market", MCATS, "case"))
	var cat = cur_sub("market", "case")
	if cat != "gb" and not Game.available_here(cat):
		v.add_child(UIK.note("У поставщика «%s» нет категории «%s». Выберите другого поставщика выше." % [sup.name, Data.CAT_NAMES.get(cat, cat)], UIK.WARN))
		return v
	match cat:
		"case", "plate", "pcb": _layout_parts(v, cat)
		"stab": _simple(v, "stab")
		"sw": _switches(v)
		"kc": _keycaps(v)
		"cons": _cons(v)
		"gb": _gb(v)
	return v

func _trend(id: String) -> Control:
	var m = float(g().market.mult.get(id, 1.0))
	if m > 1.04: return UIK.chip("▲%d%%" % int(round((m - 1) * 100)), UIK.BAD)
	if m < 0.96: return UIK.chip("▼%d%%" % int(round((1 - m) * 100)), UIK.GOOD)
	return UIK.spacer(false)

func _lock(it: Dictionary) -> bool: return int(it.lvl) > int(g().level)

func _head(it: Dictionary) -> HBoxContainer:
	return UIK.hbox(8, [UIK.expand(UIK.label(it.name, "H3", true)), UIK.chip("с %d уровня" % int(it.lvl)) if _lock(it) else _trend(it.id)])

func _layout_parts(v: VBoxContainer, cat: String) -> void:
	var S = g()
	var lay: String = main.sub.get("mlay", "l60")
	if int(Data.LAYOUTS[lay].lvl) > int(S.level): lay = "l60"
	var lf = UIK.flow(6, [UIK.label("Раскладка:", "SmallMuted")])
	for l in Data.LAYOUTS:
		var lk: bool = int(Data.LAYOUTS[l].lvl) > int(S.level)
		var b = UIK.button(Data.LAYOUTS[l].name + (" · %d ур." % int(Data.LAYOUTS[l].lvl) if lk else ""), "Sub", func(): main.sub["mlay"] = l; build_screen(false))
		b.toggle_mode = true; b.button_pressed = l == lay; b.disabled = lk; lf.add_child(b)
	v.add_child(lf)
	var gr = UIK.grid(grid_cols())
	for it in Data.cat_list(cat):
		var lock = _lock(it); var p = Game.price_of(cat, it.id, lay)
		var c = UIK.vbox(8, [_head(it)])
		var col_i: int = int(main.sub.get("col_" + it.id, 0))
		if cat == "case":
			c.add_child(UIK.label(it.mat, "SmallMuted"))
			c.add_child(UIK.flow(5, [UIK.chip("глубина %d" % int(float(it.deep) * 100)), UIK.chip("гулкость %d" % int(float(it.hollow) * 100)), UIK.chip("качество %d" % int(it.q))]))
			var cf = UIK.flow(5)
			for ci in it.colors.size():
				var cb = UIK.button(it.colors[ci][0], "Sub", func(): main.sub["col_" + it.id] = ci; build_screen(false))
				cb.toggle_mode = true; cb.button_pressed = ci == col_i
				cb.icon = _swatch_tex(Color(it.colors[ci][1]))
				cf.add_child(cb)
			c.add_child(cf)
			var th = KbThumb.make({"layout": lay, "case": it.id, "color": col_i, "kc": ""}, 70); c.add_child(th)
		elif cat == "plate":
			c.add_child(UIK.label(it.desc, "SmallMuted", true))
			c.add_child(UIK.flow(5, [UIK.chip("глубже" if float(it.pitch) < 0 else ("звонче" if float(it.pitch) > 0 else "нейтрально")), UIK.chip("флекс %d" % int(float(it.flex) * 100))]))
		else:
			c.add_child(UIK.label(it.desc, "SmallMuted", true))
			var f = UIK.flow(5)
			if it.hs: f.add_child(UIK.chip("hotswap", UIK.TEAL))
			if it.rgb: f.add_child(UIK.chip("RGB", UIK.VIOLET))
			if it.wl: f.add_child(UIK.chip("беспроводная", UIK.CORAL))
			c.add_child(f)
		c.add_child(UIK.vspace(2))
		var buy = UIK.button("Купить · " + Data.LAYOUTS[lay].name, "BtnTeal", func(): Game.buy_part(cat, it.id, lay, col_i), "cart"); buy.disabled = lock
		c.add_child(UIK.hbox(8, [UIK.label(Game.rub(p), "Price"), UIK.spacer(), buy]))
		var card = UIK.card("Card", c)
		if lock: card.modulate = Color(1, 1, 1, 0.55)
		gr.add_child(card)
	v.add_child(gr)

func _swatch_tex(c: Color) -> Texture2D:
	var img = Image.create(14, 14, false, Image.FORMAT_RGBA8)
	for y in 14:
		for x in 14:
			var d = Vector2(x - 6.5, y - 6.5).length()
			img.set_pixel(x, y, Color(c, clamp(7.0 - d, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)

func _simple(v: VBoxContainer, cat: String) -> void:
	var gr = UIK.grid(grid_cols())
	for it in Data.STABS:
		var lock = _lock(it)
		var buy = UIK.button("Купить", "BtnTeal", func(): Game.buy_part("stab", it.id), "cart"); buy.disabled = lock
		var c = UIK.vbox(8, [_head(it), UIK.flow(5, [UIK.chip("дребезг %d" % int(float(it.rattle) * 100)), UIK.chip("качество %d" % int(it.q))]), UIK.label("Подходят к любой раскладке", "SmallMuted"), UIK.hbox(8, [UIK.label(Game.rub(Game.price_of("stab", it.id)), "Price"), UIK.spacer(), buy])])
		gr.add_child(UIK.card("Card", c))
	v.add_child(gr)

func _switches(v: VBoxContainer) -> void:
	var L: Dictionary = Data.LAYOUTS
	v.add_child(UIK.label("Свитчи продаются поштучно: 60%% — %d, 65%% — %d, 75%% — %d, TKL — %d, полноразмерная — %d. Зажмите иконку свитча, чтобы послушать настоящую запись." % [L.l60.count, L.l65.count, L.l75.count, L.tkl.count, L.full.count], "SmallMuted", true))
	var gr = UIK.grid(grid_cols())
	for s in Data.SWITCHES:
		if s.get("gb", false) or s.has("box"): continue
		var lock = _lock(s); var p = Game.sw_price(s.id); var own = int(g().inv.sw.get(s.id, 0))
		var c = UIK.vbox(8)
		var ic = SwitchIcon.make(s.id)
		c.add_child(UIK.hbox(10, [ic, UIK.expand(UIK.vbox(1, [UIK.label(s.name, "H3"), UIK.label("%s · %d г" % [Data.STYPE[s.type], int(s.force)], "SmallMuted")])), UIK.chip("с %d уровня" % int(s.lvl)) if lock else _trend(s.id)]))
		c.add_child(UIK.label(s.desc, "SmallMuted", true))
		var tags = UIK.flow(5, [UIK.chip("глубокий" if float(s.pitch) < -0.15 else ("звонкий" if float(s.pitch) > 0.15 else "средний"))])
		if float(s.lube) > 0.5: tags.add_child(UIK.chip("смазан с завода", UIK.TEAL))
		if float(s.scratch) > 0.45: tags.add_child(UIK.chip("царапает", UIK.WARN))
		if float(s.tact) > 0.6: tags.add_child(UIK.chip("сильный бугорок"))
		c.add_child(tags)
		c.add_child(UIK.hbox(8, [UIK.label("%s ₽/шт" % Game.fmt(p), "Price"), UIK.spacer(), UIK.label("на складе %d" % own, "SmallMuted")]))
		var row = UIK.flow(5)
		for n in [10, L.l60.count, L.l75.count, L.tkl.count]:
			var b = UIK.button("+%d" % n, "BtnTeal", func(): Game.buy_switch(s.id, n)); b.disabled = lock; b.tooltip_text = Game.rub(round(p * n))
			row.add_child(b)
		c.add_child(row)
		var card = UIK.card("Card", c)
		if lock: card.modulate = Color(1, 1, 1, 0.55)
		gr.add_child(card)
	v.add_child(gr)

func _keycaps(v: VBoxContainer) -> void:
	var gr = UIK.grid(grid_cols())
	for k in Data.KEYCAPS:
		if k.get("gb", false) or k.has("box"): continue
		var lock = _lock(k)
		var own = 0
		for it in g().inv.items: if it.cat == "kc" and it.id == k.id: own += 1
		var tags = UIK.flow(5, [UIK.chip(Data.PROF[k.prof].name), UIK.chip(k.mat)])
		for t in k.tags: tags.add_child(UIK.chip(Data.TAGS[t], UIK.VIOLET))
		var buy = UIK.button("Купить", "BtnTeal", func(): Game.buy_part("kc", k.id), "cart"); buy.disabled = lock
		var c = UIK.vbox(8, [_head(k), CapsRow.make(k.id, 30), tags, UIK.hbox(8, [UIK.label(Game.rub(Game.price_of("kc", k.id)), "Price"), UIK.label("есть %d" % own if own else "", "SmallMuted"), UIK.spacer(), buy])])
		var card = UIK.card("Card", c)
		if lock: card.modulate = Color(1, 1, 1, 0.55)
		gr.add_child(card)
	v.add_child(gr)

func _cons(v: VBoxContainer) -> void:
	var gr = UIK.grid(grid_cols())
	for c in Data.CONS:
		var lock = _lock(c)
		var b1 = UIK.button("+1", "BtnTeal", func(): Game.buy_cons(c.id, 1)); b1.disabled = lock
		var b5 = UIK.button("+5", "BtnTeal", func(): Game.buy_cons(c.id, 5)); b5.disabled = lock
		var cv = UIK.vbox(8, [UIK.hbox(8, [UIK.expand(UIK.label(c.name, "H3", true)), UIK.chip("с %d уровня" % int(c.lvl)) if lock else UIK.label("есть %d" % int(g().inv.cons.get(c.id, 0)), "SmallMuted")]),
			UIK.label(c.desc, "SmallMuted", true), UIK.hbox(6, [UIK.label(Game.rub(Game.cons_price(c.id)), "Price"), UIK.spacer(), b1, b5])])
		gr.add_child(UIK.card("Card", cv))
	v.add_child(gr)

func _gb(v: VBoxContainer) -> void:
	var o = Game.gb_offer(); var n: int = Data.LAYOUTS.tkl.count
	v.add_child(UIK.note("Group buy — лимитированные детали этой недели. Их нет в обычном каталоге, в понедельник предложение сменится. Посылки идут в реальном времени. До смены: [b]%s[/b]" % Game.dur(Game.week_ends_in())))
	var gr = UIK.grid(min(3, grid_cols()))
	var s: Dictionary = o.sw
	gr.add_child(UIK.card("Card", UIK.vbox(8, [UIK.label("СВИТЧИ НЕДЕЛИ", "Eyebrow"), UIK.hbox(10, [SwitchIcon.make(s.id), UIK.vbox(1, [UIK.label(s.name, "H3"), UIK.label("%s · %d г" % [Data.STYPE[s.type], int(s.force)], "SmallMuted")])]),
		UIK.label(s.desc, "SmallMuted", true), UIK.hbox(8, [UIK.label(Game.rub(float(s.price) * n * Game.part_city_k()), "Price"), UIK.spacer(), UIK.button("Заказать %d шт" % n, "BtnPri", func(): Game.buy_gb("sw"))])])))
	var k: Dictionary = o.kc
	gr.add_child(UIK.card("Card", UIK.vbox(8, [UIK.label("КЕЙКАПЫ НЕДЕЛИ", "Eyebrow"), UIK.label(k.name, "H3"), CapsRow.make(k.id, 28), UIK.flow(5, [UIK.chip(Data.PROF[k.prof].name), UIK.chip(k.mat)]),
		UIK.hbox(8, [UIK.label(Game.rub(float(k.price) * Game.part_city_k()), "Price"), UIK.spacer(), UIK.button("Заказать", "BtnPri", func(): Game.buy_gb("kc"))])])))
	var a: Dictionary = o.art; var bought: bool = int(g().gb.boughtArt) == int(o.w)
	var ab = UIK.button("Заказан" if bought else "Заказать", "BtnPri", func(): Game.buy_gb("art")); ab.disabled = bought
	gr.add_child(UIK.card("CardVip", UIK.vbox(8, [UIK.label("АРТИЗАН НЕДЕЛИ · 1 ШТ", "Eyebrow"), UIK.colored(a.name, Data.RAR_COL[a.r], "H3"), UIK.label(Data.RAR_NAME[a.r], "SmallMuted"),
		UIK.label("Добавляет к цене клавиатуры %s и нравится коллекционерам." % Game.rub(Data.ART_BASE * float(Data.RARITY[a.r].val) * Game.city_k()), "SmallMuted", true),
		UIK.hbox(8, [UIK.label(Game.rub(Game.gb_art_price(a)), "Price"), UIK.spacer(), ab])])))
	v.add_child(gr)
	var pend = UIK.vbox(6, [UIK.label("В пути", "H3")])
	for p in g().gb.pending: pend.add_child(UIK.hbox(8, [UIK.icon_rect("truck", 18, UIK.TEAL), UIK.expand(UIK.label(p.name, "Small")), UIK.label(Game.dur(float(p.arrive) - Game.now()), "Price")]))
	if g().gb.pending.is_empty(): pend.add_child(UIK.label("Посылок нет.", "SmallMuted"))
	v.add_child(UIK.card("Card", pend))
