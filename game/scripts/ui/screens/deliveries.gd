extends Screen
## Deliveries: parcels on the way, boxes waiting at the door, keyboards to pack and hand to the courier.

func content(_first: bool) -> Control:
	var S = g()
	var v = UIK.vbox(14)
	v.add_child(UIK.head("Сейчас %s · курьеры работают с 09:00 до 21:00" % Game.clock_str(), "Доставки"))
	# incoming
	var inc = UIK.vbox(8, [UIK.label("ЕДУТ К ВАМ", "Eyebrow")])
	if S.deliveries.is_empty(): inc.add_child(UIK.label("Ничего не едет. Детали заказываются в приложении KeyMarket.", "SmallMuted", true))
	for d in S.deliveries:
		inc.add_child(UIK.hbox(10, [UIK.icon_rect("truck", 20, UIK.TEAL), UIK.expand(UIK.label(_names(d.items), "Small", true)), UIK.label(Game.eta_str(float(d.eta)), "Price")]))
	v.add_child(UIK.card("Card", inc))
	# at the door / in the flat
	var door = UIK.vbox(8, [UIK.label("ПОСЫЛКИ ДОМА", "Eyebrow")])
	var home_p = S.parcels.filter(func(p): return p.kind != "out")
	if home_p.is_empty(): door.add_child(UIK.label("Нераспакованных посылок нет.", "SmallMuted"))
	for p in home_p:
		var where: String = {"door": "у двери снаружи", "bench": "на верстаке", "floor": "в комнате", "carry": "в руках"}.get(str(p.place), "в комнате")
		door.add_child(UIK.hbox(10, [UIK.icon_rect("box", 20, UIK.GOLD), UIK.expand(UIK.label(_names(p.items), "Small", true)), UIK.chip(where)]))
	if not home_p.is_empty(): door.add_child(UIK.label("Возьмите коробку (E), поставьте на верстак и распакуйте.", "SmallMuted", true))
	v.add_child(UIK.card("Card", door))
	# outgoing
	var out = UIK.vbox(8, [UIK.label("ОТПРАВКИ", "Eyebrow")])
	if S.ship.is_empty(): out.add_child(UIK.label("Отправлять пока нечего. Готовые клавиатуры для заказов выбираются в приложении «Заказы».", "SmallMuted", true))
	for s in S.ship:
		var what = ""
		match str(s.kind):
			"order": what = "Заказ: " + str(s.name)
			"repair": what = "Возврат после ремонта: " + str(s.name)
			"sale": what = "Покупка в магазине: " + str(s.name)
		var st = {"ready": "упакуйте на столе", "packed": "отнесите к двери", "door": "курьер приедет " + Game.eta_str(float(s.get("pickup", 0)))}.get(str(s.status), "")
		var pay = float(s.get("pay", 0)) + float(s.get("tip", 0)) + float(s.get("price", 0))
		out.add_child(UIK.hbox(10, [UIK.icon_rect("gift", 20, UIK.CORAL), UIK.expand(UIK.vbox(0, [UIK.label(what, "Small"), UIK.label(st, "SmallMuted")])), UIK.label(Game.rub(pay) if pay > 0 else "", "Price")]))
	v.add_child(UIK.card("Card", out))
	return v

func _names(items: Array) -> String:
	var names = []
	for it in items:
		var nm: String = "клавиатура клиента" if it.cat == "client" else str(Data.item(it.cat, it.id).get("name", it.id))
		if it.has("n"): nm += " ×%d" % int(it.n)
		names.append(nm)
	return ", ".join(names)
