extends Screen

func content(first: bool) -> Control:
	var S = g()
	var v = UIK.vbox(16)
	var p = Data.prop(S.property)
	v.add_child(UIK.head("Витрина · %d/%d слотов · %s" % [S.listings.size(), Game.shelf_slots(), p.name], "Ваш магазин", [trend_chip()]))
	var txt = "Покупатели заходят сами, даже когда игра закрыта (до %d ч, это растёт с «Офлайн-менеджером»). Шанс продажи растёт с репутацией, рекламой, трендом недели и адресом магазина." % int(Game.offline_cap_h())
	if Game.repair_rate() > 0: txt += " Ремонтная стойка приносит %s/час." % Game.rub(Game.repair_rate())
	if float(p.sale) > 0: txt += " Ваш адрес даёт +%d%% к покупателям." % int(float(p.sale) * 100)
	v.add_child(UIK.note(txt))
	var gr = UIK.grid(grid_cols())
	for i in Game.shelf_slots():
		var l = S.listings[i] if i < S.listings.size() else null
		if l == null:
			var free = UIK.vbox(10, [UIK.icon_rect("store", 34, UIK.MUTE), UIK.label("Свободный слот", "Muted")])
			free.alignment = BoxContainer.ALIGNMENT_CENTER
			var avail: bool = S.boards.any(func(b): return not S.listings.any(func(x): return int(x.uid) == int(b.uid)))
			var btn = UIK.button("Выставить клавиатуру", "BtnTeal", _pick); btn.disabled = not avail
			free.add_child(btn)
			for c in free.get_children(): if c is Control: c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			var c = UIK.card("Card", free); c.custom_minimum_size.y = 240
			gr.add_child(c); continue
		var b = Game.find_board(l.uid)
		if b.is_empty(): continue
		var ch = Game.sale_chance(l); var per_min = 1.0 - pow(1.0 - ch, 6)
		var lab: Array = ["высокий", UIK.GOOD] if per_min > 0.35 else (["средний", UIK.WARN] if per_min > 0.15 else (["низкий", UIK.WARN] if per_min > 0.03 else ["почти нет", UIK.BAD]))
		var val = Game.board_value(b)
		var cv = UIK.vbox(10, [UIK.hbox(8, [UIK.expand(UIK.label(b.name, "H3")), UIK.chip(Game.sound_label(b.st), UIK.TEAL)]), KbThumb.make(b, 110),
			BoardUI.kv("Рыночная цена", Game.rub(val)), BoardUI.kv("Ваша цена", "%s (%d%%)" % [Game.rub(l.price), int(float(l.price) / val * 100)], UIK.GOLD), BoardUI.kv("Шанс покупки", lab[0], lab[1])])
		var sp = SpinBox.new(); sp.min_value = 100; sp.max_value = 99999999; sp.step = 100; sp.value = float(l.price); sp.suffix = "₽"; sp.custom_minimum_size.x = 150
		cv.add_child(UIK.hbox(6, [sp, UIK.button("Цена", "Button", func(): l.price = sp.value; Game.mark(); Audio.ui("tick")), UIK.spacer(), UIK.button("Снять", "BtnGhost", func(): Game.unlist(b.uid))]))
		gr.add_child(UIK.card("Card", cv))
	v.add_child(gr)
	var log = UIK.vbox(4, [UIK.label("Журнал доходов", "H3")])
	for x in S.log.slice(0, 14): log.add_child(UIK.hbox(8, [UIK.expand(UIK.label(x.t, "Small", true)), UIK.label("день %d" % int(x.d), "SmallMuted")]))
	if S.log.is_empty(): log.add_child(UIK.label("Пока пусто.", "SmallMuted"))
	v.add_child(UIK.card("Card", log))
	return v

func _pick() -> void:
	var S = g()
	var v = UIK.vbox(10, [main.modal_head("Что выставить?")])
	for b in S.boards:
		if S.listings.any(func(x): return int(x.uid) == int(b.uid)): continue
		var th = KbThumb.make(b, 50); th.custom_minimum_size.x = 120
		v.add_child(UIK.card("Card", UIK.hbox(10, [th, UIK.expand(UIK.vbox(1, [UIK.label(b.name, "H3"), UIK.label("рыночная цена " + Game.rub(Game.board_value(b)), "SmallMuted")])), UIK.button("Выбрать", "BtnTeal", func(): main.close_modal(); BoardUI.list_modal(main, b))])))
	main.open_modal(v, 600)
