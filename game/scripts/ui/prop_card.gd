class_name PropCard
extends RefCounted

static func make(main, p: Dictionary) -> PanelContainer:
	var S: Dictionary = Game.S
	var owned: bool = p.id in S.owned_props; var cur: bool = S.property == p.id
	var lock: bool = int(p.lvl) > int(S.level)
	var price = round(float(p.price) * Game.city_k())
	var pic = RoomPic.make(p.style, 120)
	var c = UIK.vbox(8, [pic, UIK.hbox(8, [UIK.expand(UIK.label(p.name, "H3")), UIK.chip("Здесь вы" if cur else ("Куплено" if owned else ("с %d уровня" % int(p.lvl) if lock else Game.rub(price))), UIK.CORAL if cur else (UIK.GOOD if owned else UIK.GOLD))]),
		UIK.label(p.desc, "SmallMuted", true)])
	var bon = UIK.flow(5)
	if int(p.storage) > 0: bon.add_child(UIK.chip("+%d склад" % int(p.storage)))
	if int(p.shelf) > 0: bon.add_child(UIK.chip("+%d витрина" % int(p.shelf)))
	if float(p.sale) > 0: bon.add_child(UIK.chip("+%d%% покупатели" % int(float(p.sale) * 100)))
	if float(p.budget) > 0: bon.add_child(UIK.chip("+%d%% бюджеты" % int(float(p.budget) * 100)))
	c.add_child(bon)
	if not cur:
		var b = UIK.button("Переехать" if owned else "Купить", "BtnPri" if not owned else "BtnTeal", func():
			if Game.buy_property(p.id):
				main.ws.set_style(p.id); main.flash(Color(1, 1, 1, 0.3)); main.ws.set_view("room"), "home")
		b.disabled = lock or (not owned and float(S.money) < price)
		c.add_child(b)
	return UIK.card("CardHi" if cur else "Card", c)
