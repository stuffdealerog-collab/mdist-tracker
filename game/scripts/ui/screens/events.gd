extends Screen

func _ready() -> void:
	Online.leaderboard_updated.connect(func(): if is_inside_tree(): build_screen(false))
	if Online.online: Online.fetch_leaderboard()

func content(first: bool) -> Control:
	var S = g()
	var v = UIK.vbox(16)
	v.add_child(UIK.head("Возвращайтесь каждый день", "События"))
	var two = UIK.grid(2 if size.x > 1000 else 1, 16)
	# login calendar
	var idx = Game.login_idx(); var claimed: bool = S.login.claimed == Game.today_str(); var k = Game.login_k()
	var cal = UIK.hbox(6)
	for i in Game.LOGIN_REW.size():
		var r: Dictionary = Game.LOGIN_REW[i]
		var got: bool = i < idx or (i == idx and claimed)
		var today = i == idx
		var c = UIK.vbox(2, [UIK.label("День %d" % (i + 1), "SmallMuted"), UIK.label(Game.fmt(round(float(r.m) * k / 100.0) * 100.0), "Num") if r.has("m") else UIK.icon_rect("gift", 18, UIK.GOLD), UIK.label(r.t, "SmallMuted", true)])
		var p = PanelContainer.new(); p.custom_minimum_size = Vector2(72, 92)
		var col = UIK.GOOD if got else (UIK.CORAL if today else UIK.LINE)
		p.add_theme_stylebox_override("panel", UIK.sb(Color(col, 0.1) if got or today else Color(1, 1, 1, 0.03), 10, Color(col, 0.6) if got or today else UIK.LINE, 8, 2 if today else 1))
		p.add_child(c); UIK.expand(p); cal.add_child(p)
	var lb = UIK.button("Награда получена, ждём завтра" if claimed else "Забрать награду дня", "BtnPri", func(): Game.claim_login(); main.flash(Color(1, 0.85, 0.4, 0.15)), "gift"); lb.disabled = claimed
	two.add_child(UIK.expand(UIK.card("Card", UIK.vbox(10, [UIK.hbox(8, [UIK.expand(UIK.label("Ежедневный вход", "H3")), UIK.chip("Серия %d дн. · рекорд %d" % [int(S.login.streak), int(S.login.best)], UIK.CORAL)]), cal, lb,
		UIK.label("Пропуск дня сбрасывает серию. Каждая полная неделя серии увеличивает награды на 10% (до +100%).", "SmallMuted", true)]))))
	# daily tasks
	var tv = UIK.vbox(10, [UIK.hbox(8, [UIK.expand(UIK.label("Задания дня", "H3")), UIK.label("обновятся в полночь", "SmallMuted")])])
	var all_done = S.daily.tasks.size() > 0
	for i in S.daily.tasks.size():
		var t: Dictionary = S.daily.tasks[i]; var p = Game.task_prog(t)
		if not t.get("claimed", false): all_done = false
		var right: Control
		if t.get("claimed", false): right = UIK.chip("Получено", UIK.GOOD)
		else:
			var b = UIK.button(Game.rub(Game.task_reward()), "BtnPri" if p >= float(t.n) else "BtnGhost", func(): Game.claim_task(i)); b.disabled = p < float(t.n); right = b
		tv.add_child(UIK.vbox(4, [UIK.hbox(8, [UIK.expand(UIK.label(Game.task_text(t), "Small", true)), right]), UIK.bar(p / float(t.n))]))
	var bb = UIK.button("Сундук дня открыт" if S.daily.bonus else "Сундук дня (все 3 задания)", "BtnGold" if all_done and not S.daily.bonus else "BtnGhost", Game.claim_daily_bonus, "gift")
	bb.disabled = not all_done or S.daily.bonus
	tv.add_child(bb)
	two.add_child(UIK.expand(UIK.card("Card", tv)))
	# contest
	var c = S.weekly.contest
	var cdef = Data.by_id("CONTESTS", c.id) if c else {}
	var cv = UIK.vbox(10, [UIK.hbox(8, [UIK.expand(UIK.label("Конкурс недели: " + str(cdef.get("name", "")), "H3")), UIK.chip("ещё " + Game.dur(Game.week_ends_in()))]),
		UIK.label(str(cdef.get("desc", "")) + " Подайте свою лучшую сборку (она остаётся у вас). Итоги — в понедельник. 1 место: эпический артизан и деньги, 2–3: редкий артизан.", "SmallMuted", true)])
	var res = S.weekly.result
	if res and not res.get("claimed", false):
		cv.add_child(UIK.hbox(8, [UIK.rich("[b]Итоги прошлой недели:[/b] %d место (%s очков)" % [int(res.rank), str(res.score)], 14), UIK.spacer(), UIK.button("Забрать приз", "BtnPri", Game.claim_contest)]))
	var table = []
	if c:
		for n in Game.contest_npc(int(S.weekly.week), int(S.weekly.npcLvl)): table.append({"name": n.name, "score": n.score, "me": false})
		if c.entry != null: table.append({"name": S.shop, "score": float(c.entry.score), "me": true})
	table.sort_custom(func(a, b2): return a.score > b2.score)
	var tb = UIK.vbox(2)
	for i in table.size():
		var r: Dictionary = table[i]
		var row = UIK.hbox(8, [UIK.label("%d" % (i + 1), "Num"), UIK.expand(UIK.label(r.name, "Small")), UIK.label(str(r.score), "Num")])
		if r.me: row = UIK.hbox(8, [UIK.colored("%d" % (i + 1), UIK.CORAL, "Num"), UIK.expand(UIK.colored(r.name, UIK.CORAL, "Small")), UIK.colored(str(r.score), UIK.CORAL, "Num")])
		tb.add_child(row)
	cv.add_child(UIK.card("Card", tb))
	var sb = UIK.button("Подать сборку получше" if c and c.entry != null else "Подать заявку", "BtnTeal", _contest_pick, "trophy"); sb.disabled = S.boards.is_empty()
	cv.add_child(sb)
	two.add_child(UIK.expand(UIK.card("Card", cv)))
	# weekly task + leaderboard
	var right = UIK.vbox(16)
	var wt = S.weekly.task
	if wt:
		var wp: float = min(float(wt.n), float(S.weekly.prog))
		var wb = UIK.button("Получено" if S.weekly.claimed else "Недельный сундук + бонус", "BtnGold" if wp >= float(wt.n) and not S.weekly.claimed else "BtnGhost", Game.claim_weekly, "gift")
		wb.disabled = wp < float(wt.n) or S.weekly.claimed
		var lbl: String = (Game.rub(wp) + " / " + Game.rub(wt.n)) if wt.k == "earn" else "%d / %d" % [int(wp), int(wt.n)]
		right.add_child(UIK.card("Card", UIK.vbox(8, [UIK.hbox(8, [UIK.expand(UIK.label("Задание недели", "H3")), UIK.label(lbl, "Num")]), UIK.label(str(wt.t) + (" " + Game.rub(wt.n) if wt.k == "earn" else ""), "Small", true), UIK.bar(wp / float(wt.n), UIK.GOLD), wb])))
	var lbv = UIK.vbox(6, [UIK.hbox(8, [UIK.expand(UIK.label("Лидеры среди мастерских", "H3")), UIK.button("Обновить", "BtnGhost", Online.fetch_leaderboard, "rotate")])])
	if not Online.online: lbv.add_child(UIK.label("Таблица лидеров доступна при подключении к серверу.", "SmallMuted", true))
	elif Online.leaderboard.is_empty(): lbv.add_child(UIK.label("Пока никого. Станьте первым!", "SmallMuted"))
	else:
		for i in min(15, Online.leaderboard.size()):
			var r: Dictionary = Online.leaderboard[i]
			var me: bool = str(r.get("pid", "")) == str(S.online.get("pid", ""))
			var nm = UIK.label(str(r.get("name", "")), "Small"); if me: nm.add_theme_color_override("font_color", UIK.CORAL)
			lbv.add_child(UIK.hbox(8, [UIK.label("%d" % (i + 1), "Num"), UIK.expand(nm), UIK.label(str(r.get("city", "")), "SmallMuted"), UIK.label("ур. %d" % int(r.get("level", 0)), "SmallMuted"), UIK.label(Game.rub(float(r.get("earned", 0))), "Price")]))
	right.add_child(UIK.card("Card", lbv))
	two.add_child(UIK.expand(right))
	v.add_child(two)
	return v

func _contest_pick() -> void:
	var c = g().weekly.contest
	if c == null: return
	var rows = []
	for b in g().boards: rows.append({"b": b, "s": Game.contest_score(c.id, b.st)})
	rows.sort_custom(func(a, b2): return a.s > b2.s)
	var v = UIK.vbox(10, [main.modal_head(Data.by_id("CONTESTS", c.id).name, "Конкурс недели")])
	for x in rows:
		v.add_child(UIK.card("Card", UIK.hbox(10, [UIK.expand(UIK.vbox(1, [UIK.label(x.b.name, "H3"), UIK.label("%s · качество %d" % [Game.sound_label(x.b.st), int(x.b.st.quality)], "SmallMuted")])), UIK.label(str(x.s), "Price"), UIK.button("Подать", "BtnPri", func(): Game.submit_contest(x.b.uid); main.close_modal())])))
	main.open_modal(v, 600)
