class_name BoardUI
extends RefCounted
## Shared widgets for finished boards: cards, meters, parts list, listen modal.

static func meters(st: Dictionary, full := false) -> VBoxContainer:
	var m = UIK.vbox(5, [UIK.meter("Thock", st.thock, UIK.CORAL), UIK.meter("Громкость", st.loud, UIK.WARN), UIK.meter("Гладкость", st.smooth, UIK.TEAL), UIK.meter("Качество", st.quality, UIK.GOLD)])
	if full:
		for x in [["Эстетика", st.aesthetic, UIK.VIOLET], ["Звон пружин", st.ping, Color("d97a7a")], ["Дребезг стабов", st.rattle, Color("d97a7a")], ["Гулкость", st.hollow, Color("d97a7a")], ["Царапание", st.scratch, Color("d97a7a")]]:
			m.add_child(UIK.meter(x[0], x[1], x[2]))
	return m

static func kv(k: String, v: String, col := UIK.INK) -> HBoxContainer:
	var l = UIK.label(v, "Small"); l.add_theme_color_override("font_color", col); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return UIK.hbox(8, [UIK.label(k, "SmallMuted"), UIK.spacer(), l])

static func parts(b: Dictionary) -> VBoxContainer:
	var kc = Data.kc(b.kc)
	var v = UIK.vbox(4, [kv("Корпус", Data.case_(b.case).name), kv("Пластина", Data.plate(b.plate).name), kv("Плата", Data.pcb(b.pcb).name),
		kv("Стабы", Data.stab(b.stab).name), kv("Свитчи", Data.sw(b.sw).name), kv("Кейкапы", "%s · %s %s" % [kc.name, Data.PROF[kc.prof].name, kc.mat])])
	var mods = []
	for k in b.get("mods", {}):
		if b.mods[k]: mods.append({"lube": "смазка", "stablube": "стабы смазаны", "films": "плёнки", "foam": "пенка", "pefoam": "PE-фоам", "tape": "tape-mod"}.get(k, k))
	if mods.size() > 0: v.add_child(kv("Моды", ", ".join(mods)))
	if b.get("art") != null:
		var A = Data.art(str(b.art)); v.add_child(kv("Артизан", A.name, Data.RAR_COL[A.r]))
	return v

static func card(main, b: Dictionary, actions := true) -> PanelContainer:
	var S: Dictionary = Game.S
	var listed: bool = S.listings.any(func(l): return int(l.uid) == int(b.uid))
	var v = UIK.vbox(10)
	v.add_child(UIK.hbox(8, [UIK.expand(UIK.vbox(1, [UIK.label(b.name, "H3"), UIK.label("%s · день %d" % [Data.LAYOUTS[b.layout].name, int(b.made)], "SmallMuted")])), UIK.chip(Game.sound_label(b.st), UIK.TEAL)]))
	var th = KbThumb.make(b, 110); v.add_child(th)
	v.add_child(meters(b.st))
	v.add_child(kv("Себестоимость", Game.rub(b.cost)))
	v.add_child(kv("Рыночная цена", Game.rub(Game.board_value(b)) + (" · в тренде" if Game.trend_match(b) else ""), UIK.GOLD))
	if int(b.get("dead", 0)) > 0: v.add_child(kv("Дефект", "мёртвых клавиш: %d" % int(b.dead), UIK.BAD))
	if actions:
		var row = UIK.flow(6)
		row.add_child(UIK.button("Слушать", "Button", func(): listen(main, b), "sound"))
		if listed: row.add_child(UIK.chip("На витрине", UIK.CORAL))
		else: row.add_child(UIK.button("На витрину", "BtnTeal", func(): list_modal(main, b), "store"))
		row.add_child(UIK.button("Разобрать", "BtnGhost", func(): main.confirm("Разобрать «%s»?" % b.name, "Детали вернутся на склад, расходники и смазка пропадут.", "Разобрать", func(): Game.disassemble(b.uid))))
		v.add_child(row)
	return UIK.card("Card", v)

static func listen(main, b: Dictionary) -> void:
	var v = UIK.vbox(12, [main.modal_head(b.name, "%s · %s" % [Data.LAYOUTS[b.layout].name, Game.sound_label(b.st)])])
	var pv = Preview3D.make(b, Vector2(820, 360)); v.add_child(pv)
	v.add_child(UIK.label("Печатайте на своей клавиатуре или кликайте по клавишам. Тяните, чтобы вращать, колесо — зум." + (" Дефект: %d мёртв. клавиш." % int(b.dead) if int(b.get("dead", 0)) > 0 else ""), "SmallMuted", true))
	var g = UIK.grid(2, 24); g.add_child(UIK.expand(meters(b.st, true))); g.add_child(UIK.expand(parts(b)))
	v.add_child(g)
	var p = await main.open_modal(v, 880)
	await main.get_tree().process_frame
	main.set_kb_sound(b, pv.kb)
	pv.key_pressed.connect(func(i, down): main._key(i, down))
	if p: p.set_meta("on_close", func(): main.set_kb_sound({}); if main.screen: main.screen.build_screen(false))

static func list_modal(main, b: Dictionary) -> void:
	var S: Dictionary = Game.S
	if S.listings.size() >= Game.shelf_slots():
		Game.toast("Все слоты витрины заняты. Расширьте витрину в «Развитии»", "bad"); return
	var val = Game.board_value(b)
	var v = UIK.vbox(12, [main.modal_head("На витрину"), UIK.rich("[b]%s[/b] · рыночная цена [color=#ebc66c]%s[/color]. Чем выше цена относительно рыночной, тем дольше ждать покупателя. Дороже 160%% не купят вовсе." % [b.name, Game.rub(val)])])
	var sp = SpinBox.new(); sp.min_value = 100; sp.max_value = 99999999; sp.step = 100; sp.value = round(val * 1.05 / 100.0) * 100.0; sp.suffix = "₽"
	sp.custom_minimum_size.x = 180
	var row = UIK.hbox(6, [sp])
	for k in [0.9, 1.0, 1.15, 1.3]:
		row.add_child(UIK.button("%d%%" % int(k * 100), "Sub", func(): sp.value = round(val * k / 100.0) * 100.0))
	v.add_child(row)
	v.add_child(UIK.hbox(8, [UIK.spacer(), UIK.button("Выставить", "BtnPri", func():
		if Game.list_board(b.uid, sp.value): main.close_modal(); Audio.ui("buy")
		, "store")]))
	main.open_modal(v, 560)
