extends Screen

func content(first: bool) -> Control:
	var S = g()
	var v = UIK.vbox(16)
	var nsw: int = S.col.sw.size(); var nkc: int = S.col.kc.size(); var nart: int = S.col.art.size(); var nach: int = S.ach.size()
	v.add_child(UIK.head("Всё, что вы собрали", "Коллекция"))
	v.add_child(subtabs("collection", [["sw", "Свитч-тестер %d/%d" % [nsw, Data.SWITCHES.size()]], ["kc", "Кейкапы %d/%d" % [nkc, Data.KEYCAPS.size()]], ["art", "Артизаны %d/%d" % [nart, Data.ARTISANS.size()]], ["ach", "Достижения %d/%d" % [nach, Data.ACH.size()]], ["stats", "Статистика"]], "sw"))
	match cur_sub("collection", "sw"):
		"sw":
			v.add_child(UIK.label("Зажмите свитч, чтобы услышать настоящую запись. Новые свитчи открываются покупкой или из коробок.", "SmallMuted", true))
			var gr = UIK.grid(grid_cols() + 2, 10)
			for s in Data.SWITCHES:
				var have: bool = S.col.sw.has(s.id)
				var ic: Control = SwitchIcon.make(s.id, 54) if have else UIK.icon_rect("lock", 30, UIK.MUTE)
				ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				var c = UIK.vbox(4, [ic, UIK.label(s.name if have else "???", "Small"), UIK.label(Data.STYPE[s.type] if have else "не открыт", "SmallMuted")])
				for x in c.get_children(): x.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				var card = UIK.card("Card", c)
				if s.has("box"): card.theme_type_variation = "CardVip"
				gr.add_child(card)
			v.add_child(gr)
		"kc":
			var gr = UIK.grid(grid_cols())
			for k in Data.KEYCAPS:
				var have: bool = S.col.kc.has(k.id)
				var c = UIK.vbox(8, [UIK.label(k.name if have else "???", "H3"), CapsRow.make(k.id, 28) if have else UIK.icon_rect("lock", 28, UIK.MUTE), UIK.label("%s · %s" % [Data.PROF[k.prof].name, k.mat] if have else "не открыт", "SmallMuted")])
				gr.add_child(UIK.card("CardVip" if k.has("box") else "Card", c))
			v.add_child(gr)
		"art":
			var gr = UIK.grid(grid_cols() + 2, 10)
			for a in Data.ARTISANS:
				var have: bool = S.col.art.has(a.id)
				var col: Color = Data.RAR_COL[a.r]
				var ic = PanelContainer.new(); ic.custom_minimum_size = Vector2(54, 54)
				ic.add_theme_stylebox_override("panel", UIK.sb(Keyboard3D.art_color(a) if have else Color(1, 1, 1, 0.05), 12, Color(col, 0.6), 0, 2))
				var gl = UIK.label(str(a.g) if have else "?", "H2"); gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; gl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; ic.add_child(gl)
				var c = UIK.vbox(4, [ic, UIK.colored(a.name if have else "???", col, "Small"), UIK.label(Data.RAR_NAME[a.r], "SmallMuted")])
				for x in c.get_children(): x.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				gr.add_child(UIK.card("Card", c))
			v.add_child(gr)
		"ach":
			var gr = UIK.grid(grid_cols())
			for a in Data.ACH:
				var have: bool = S.ach.has(a[0])
				var val = Game.ach_value(a[4]); var p: float = clamp(val / float(a[5]), 0.0, 1.0)
				var c = UIK.vbox(6, [UIK.hbox(8, [UIK.icon_rect("trophy", 22, UIK.GOLD if have else UIK.MUTE), UIK.expand(UIK.label(a[1], "H3")), UIK.chip("✓" if have else "%d%%" % int(p * 100), UIK.GOOD if have else Color(0, 0, 0, 0))]),
					UIK.label(a[2], "SmallMuted", true), UIK.bar(p, UIK.GOLD if have else UIK.TEAL, 5)])
				if int(a[3]) > 0: c.add_child(UIK.label("Награда: " + Game.rub(a[3]), "SmallMuted"))
				var card = UIK.card("CardVip" if have else "Card", c)
				gr.add_child(card)
			v.add_child(gr)
		"stats":
			var st: Dictionary = S.stats
			var rows = [["Собрано клавиатур", st.built], ["Выполнено заказов", st.orders], ["Отзывов 5★", st.five], ["Продано с витрины", st.sold], ["Заработано всего", Game.rub(st.earnedAll)],
				["Самая дорогая продажа", Game.rub(st.maxSale)], ["Максимальный thock", st.maxThock], ["Лучшее качество", st.maxQ], ["Идеальная смазка", st.perfectLube], ["Нажато клавиш", st.keys],
				["Открыто коробок", st.boxes], ["Обменов", st.trades], ["Побед в конкурсах", st.contestWins], ["Филиалов", S.prestige.count], ["Очки легенды", S.prestige.legend]]
			var gr = UIK.grid(2 if size.x > 900 else 1, 8)
			for r in rows: gr.add_child(UIK.card("Card", BoardUI.kv(r[0], str(r[1]))))
			v.add_child(gr)
	return v
