extends Screen

func content(first: bool) -> Control:
	var S = g()
	var v = UIK.vbox(16)
	v.add_child(UIK.head("Уровень %d · %s / %s XP" % [int(S.level), Game.fmt(S.xp), Game.fmt(Game.xp_need())], "Развитие"))
	v.add_child(subtabs("growth", [["up", "Улучшения"], ["sk", "Навыки" + (" (%d)" % int(S.sp) if int(S.sp) > 0 else "")], ["prop", "Помещения"], ["pr", "Филиалы"]], "up"))
	match cur_sub("growth", "up"):
		"up": _ups(v)
		"sk": _skills(v)
		"prop": _props(v)
		"pr": _prestige(v)
	return v

func _ups(v: VBoxContainer) -> void:
	var gr = UIK.grid(grid_cols())
	for u in Data.UPGRADES:
		var l = Game.upl(u.id); var mx: bool = l >= int(u.max); var c = Game.up_cost(u)
		var pips = UIK.hbox(3)
		for i in int(u.max):
			var p = Panel.new(); p.custom_minimum_size = Vector2(18, 6); p.add_theme_stylebox_override("panel", UIK.sb(UIK.TEAL if i < l else UIK.LINE, 3, Color(0, 0, 0, 0), 0)); pips.add_child(p)
		var cv = UIK.vbox(8, [UIK.hbox(8, [UIK.expand(UIK.label(u.name, "H3")), UIK.chip("%d/%d" % [l, int(u.max)])]), pips,
			UIK.rich("[color=#8a97a3]Сейчас:[/color] " + Data.upgrade_desc(u.id, l), 13)])
		if not mx: cv.add_child(UIK.rich("[color=#6be3a0]Далее:[/color] " + Data.upgrade_desc(u.id, l + 1), 13))
		cv.add_child(UIK.spacer(false))
		if mx: cv.add_child(UIK.chip("Максимум", UIK.GOOD))
		else:
			var b = UIK.button("Улучшить", "BtnTeal", func(): Game.buy_upgrade(u.id), "trend"); b.disabled = float(S_money()) < c
			cv.add_child(UIK.hbox(8, [UIK.label(Game.rub(c), "Price"), UIK.spacer(), b]))
		gr.add_child(UIK.card("Card", cv))
	v.add_child(gr)

func S_money() -> float: return float(g().money)

func _skills(v: VBoxContainer) -> void:
	v.add_child(UIK.note("Очки навыков: [b][color=#ebc66c]%d[/color][/b]. Одно очко за каждый уровень, максимум 10 рангов в навыке." % int(g().sp)))
	var gr = UIK.grid(grid_cols())
	for s in Data.SKILLS:
		var l = Game.skl(s.id)
		var pips = UIK.hbox(3)
		for i in 10:
			var p = Panel.new(); p.custom_minimum_size = Vector2(16, 6); p.add_theme_stylebox_override("panel", UIK.sb(UIK.VIOLET if i < l else UIK.LINE, 3, Color(0, 0, 0, 0), 0)); pips.add_child(p)
		var b = UIK.button("Вложить очко", "BtnTeal", func(): Game.buy_skill(s.id), "zap"); b.disabled = int(g().sp) < 1 or l >= 10
		gr.add_child(UIK.card("Card", UIK.vbox(8, [UIK.hbox(8, [UIK.expand(UIK.label(s.name, "H3")), UIK.chip("%d/10" % l)]), UIK.label(s.desc, "SmallMuted", true), pips, b])))
	v.add_child(gr)

func _props(v: VBoxContainer) -> void:
	v.add_child(UIK.note("Помещение меняет вашу мастерскую в 3D, расширяет склад и витрину, приводит больше покупателей и клиентов с бюджетом побольше. Купить можно и на карте города."))
	var gr = UIK.grid(grid_cols())
	for p in Data.PROPERTIES:
		gr.add_child(PropCard.make(main, p))
	v.add_child(gr)

func _prestige(v: VBoxContainer) -> void:
	var S = g(); var gain = Game.legend_gain()
	var next_city: String = Data.CITIES[min(Data.CITIES.size() - 1, int(S.prestige.city) + 1)]
	var cities = UIK.flow(6)
	for i in Data.CITIES.size():
		cities.add_child(UIK.chip(Data.CITIES[i], UIK.CORAL if i == int(S.prestige.city) else (UIK.GOOD if i < int(S.prestige.city) else Color(0, 0, 0, 0))))
	var b = UIK.button("Открыть филиал: " + next_city, "BtnPri", func(): main.confirm("Открыть филиал?", "Деньги, уровень, склад, улучшения, навыки и помещения начнутся заново. Коллекция, достижения и очки легенды останутся. Вы получите +%d очков легенды." % gain, "Переехать", func(): Game.do_prestige(); main.ws.set_style(Game.S.property); build_screen(true)), "globe")
	b.disabled = not Game.can_prestige()
	var c = UIK.vbox(10, [UIK.label("СЕТЬ МАСТЕРСКИХ", "Eyebrow"), cities,
		UIK.label("Откройте филиал в новом городе: прогресс начнётся заново, но коллекция, достижения, серия входов и сюжеты VIP останутся. В каждом следующем городе клиенты платят на 18% больше, а очки легенды дают постоянные бонусы.", "Small", true),
		BoardUI.kv("Требование", "25 уровень (сейчас %d)" % int(S.level), UIK.GOOD if int(S.level) >= 25 else UIK.BAD),
		BoardUI.kv("Заработано в этом городе", Game.rub(S.stats.earned)), BoardUI.kv("Очки легенды за переезд", "+%d" % gain, UIK.GOLD), BoardUI.kv("Очки легенды сейчас", str(int(S.prestige.legend)), UIK.GOLD), b])
	v.add_child(UIK.card("CardVip", c))
	var gr = UIK.grid(grid_cols())
	for p in Data.PERKS:
		var l = Game.perk(p.id); var cost = Data.perk_cost(p.id, l)
		var pb = UIK.button("Купить", "BtnTeal", func(): Game.buy_perk(p.id)); pb.disabled = l >= int(p.max) or int(S.prestige.legend) < cost
		gr.add_child(UIK.card("Card", UIK.vbox(8, [UIK.hbox(8, [UIK.expand(UIK.label(p.name, "H3")), UIK.chip("%d/%d" % [l, int(p.max)])]), UIK.label(p.desc, "SmallMuted", true),
			UIK.hbox(8, [UIK.colored("Максимум" if l >= int(p.max) else "%d оч. легенды" % cost, UIK.GOLD, "Small"), UIK.spacer(), pb])])))
	v.add_child(gr)
