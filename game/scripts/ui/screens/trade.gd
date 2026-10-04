extends Screen
## Барахолка: trades with live players (server) and NPC traders of the city.

const KIND_N := {"art": "артизан", "sw": "пачка свитчей", "kc": "набор кейкапов"}

func _ready() -> void:
	Online.market_updated.connect(func(): if is_inside_tree(): build_screen(false))
	if Online.online: Online.fetch_market()

func content(first: bool) -> Control:
	var S = g()
	Game.ensure_traders()
	var v = UIK.vbox(16)
	var st = UIK.chip("Сервер подключён" if Online.online else "Нет связи с сервером", UIK.GOOD if Online.online else UIK.BAD)
	v.add_child(UIK.head("Обмен деталями", "Барахолка", [st, UIK.button("Обновить", "BtnGhost", func(): Online.connect_server(), "rotate")]))
	v.add_child(subtabs("trade", [["players", "Мастера онлайн (%d)" % Online.offers.size()], ["npc", "Торговцы города (%d)" % S.traders.offers.size()], ["mine", "Мои предложения (%d)" % Online.my_offers.size()]], "players"))
	match cur_sub("trade", "players"):
		"players": _players(v)
		"npc": _npc(v)
		"mine": _mine(v)
	return v

func _offer_card(who: String, give: Dictionary, want: Dictionary, btn: Button) -> Control:
	var c = UIK.vbox(10)
	c.add_child(UIK.hbox(8, [UIK.icon_rect("user", 18, UIK.MUTE), UIK.expand(UIK.label(who, "H3")), btn]))
	var arrow = UIK.icon_rect("swap", 26, UIK.TEAL); arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var wcol: Color = Data.RAR_COL[want.rarity]
	var wantbox = PanelContainer.new(); wantbox.custom_minimum_size = Vector2(150, 150)
	wantbox.add_theme_stylebox_override("panel", UIK.sb(Color(wcol, 0.06), 12, Color(wcol, 0.4), 10, 2))
	var wv = UIK.vbox(6, [UIK.label("ХОЧЕТ", "Eyebrow"), UIK.label(KIND_N[want.kind], "H3", true), UIK.colored(Data.RAR_NAME[want.rarity] + " или лучше", wcol, "Small")])
	wv.alignment = BoxContainer.ALIGNMENT_CENTER; wantbox.add_child(wv)
	var gv = UIK.vbox(4, [UIK.label("ОТДАЁТ", "Eyebrow"), ItemTile.make(give, 150)])
	var wv2 = UIK.vbox(4, [UIK.label(" ", "Eyebrow"), wantbox])
	c.add_child(UIK.hbox(14, [gv, arrow, wv2]))
	return UIK.card("Card", c)

func _players(v: VBoxContainer) -> void:
	if not Online.online:
		v.add_child(UIK.note("Обмен с живыми игроками работает через сервер игры. Адрес сервера задаётся в «Настройках». Сейчас подключения нет: попробуйте позже или поменяйтесь с торговцами города.", UIK.WARN))
		v.add_child(UIK.hbox(8, [UIK.button("Настройки сервера", "BtnTeal", func(): Settings.open(main), "gear"), UIK.button("Торговцы города", "BtnGhost", func(): main.sub["trade"] = "npc"; build_screen(true))]))
		return
	var mine = Online.my_online_items()
	v.add_child(UIK.hbox(8, [UIK.label("Онлайн-предметов для обмена: %d. Их дают коробки, открытые при подключении к серверу." % mine.size(), "SmallMuted", true), UIK.spacer(), UIK.button("Выставить предложение", "BtnPri", _create_modal, "swap")]))
	if Online.offers.is_empty():
		v.add_child(empty_state("Пока никто ничего не выставил. Будьте первым!", "swap")); return
	var gr = UIK.grid(max(1, grid_cols() - 1))
	for o in Online.offers:
		var b = UIK.button("Обменять", "BtnTeal", func(): _pick_give(o.want, func(t): Online.accept_offer(o, t)))
		gr.add_child(_offer_card(str(o.get("seller", "Мастер")), o.give, o.want, b))
	v.add_child(gr)

func _npc(v: VBoxContainer) -> void:
	v.add_child(UIK.label("Торговцы обновляют предложения каждый игровой день. Они меняются только своими вещами — без сервера.", "SmallMuted", true))
	var offers: Array = g().traders.offers
	if offers.is_empty(): v.add_child(empty_state("Сегодня торговцев нет. Загляните завтра.", "swap")); return
	var gr = UIK.grid(max(1, grid_cols() - 1))
	for o in offers:
		var b = UIK.button("Обменять", "BtnTeal", func(): _pick_give(o.want, func(t): Game.accept_npc_trade(o.id, t)))
		gr.add_child(_offer_card(o.who, o.give, o.want, b))
	v.add_child(gr)

func _mine(v: VBoxContainer) -> void:
	if Online.my_offers.is_empty(): v.add_child(empty_state("У вас нет активных предложений.", "swap")); return
	var gr = UIK.grid(max(1, grid_cols() - 1))
	for o in Online.my_offers:
		var b = UIK.button("Снять", "BtnGhost", func(): Online.cancel_offer(str(o.id)))
		gr.add_child(_offer_card("Ваше предложение", o.give, o.want, b))
	v.add_child(gr)

## Choose which of your items to give (filtered by kind and minimum rarity).
func _pick_give(want: Dictionary, cb: Callable, online_only := false) -> void:
	var items = Game.tradeable_items().filter(func(t): return t.kind == want.kind and Data.RAR_ORDER.find(t.rarity) >= Data.RAR_ORDER.find(want.rarity))
	if online_only: items = items.filter(func(t): return Online.online_uid_of(t) != "")
	var v = UIK.vbox(12, [main.modal_head("Что отдать?", "Нужно: %s, %s или лучше" % [KIND_N[want.kind], Data.RAR_NAME[want.rarity].to_lower()])])
	if items.is_empty():
		v.add_child(UIK.label("У вас нет подходящих вещей.", "Muted"))
	else:
		var f = UIK.flow(10)
		for t in items:
			var tile = ItemTile.make(t, 140)
			var b = UIK.button("Отдать", "BtnTeal", func(): main.close_modal(); cb.call(t))
			var col = UIK.vbox(6, [tile, b])
			if Online.online_uid_of(t) != "": col.add_child(UIK.chip("онлайн", UIK.GOOD))
			f.add_child(col)
		v.add_child(f)
	main.open_modal(v, 720)

func _create_modal() -> void:
	var mine = Online.my_online_items()
	var v = UIK.vbox(12, [main.modal_head("Новое предложение", "Барахолка")])
	if mine.is_empty():
		v.add_child(UIK.label("Нет онлайн-предметов. Откройте коробку, пока игра подключена к серверу.", "Muted", true))
		main.open_modal(v, 560); return
	var sel = {"give": mine[0], "kind": "art", "rar": "rare"}
	var f = UIK.flow(8)
	var tiles = []
	for t in mine:
		var b = Button.new(); b.toggle_mode = true; b.focus_mode = Control.FOCUS_NONE
		b.add_theme_stylebox_override("normal", StyleBoxEmpty.new()); b.add_theme_stylebox_override("pressed", UIK.sb(Color(0, 0, 0, 0), 14, UIK.TEAL, 0, 2))
		b.add_theme_stylebox_override("hover", UIK.sb(Color(1, 1, 1, 0.04), 14, Color(0, 0, 0, 0), 0))
		var tile = ItemTile.make(t, 120, true); b.add_child(tile); b.custom_minimum_size = tile.custom_minimum_size
		b.pressed.connect(func():
			sel.give = t
			for x in tiles: x.button_pressed = x == b)
		tiles.append(b); f.add_child(b)
	tiles[0].button_pressed = true
	v.add_child(UIK.label("ОТДАЮ", "Eyebrow")); v.add_child(f)
	v.add_child(UIK.label("ХОЧУ ВЗАМЕН", "Eyebrow"))
	var kinds = OptionButton.new()
	for k in ["art", "sw", "kc"]: kinds.add_item(KIND_N[k])
	var rars = OptionButton.new()
	for r in Data.RAR_ORDER: rars.add_item(Data.RAR_NAME[r])
	rars.select(1)
	kinds.item_selected.connect(func(i): sel.kind = ["art", "sw", "kc"][i])
	rars.item_selected.connect(func(i): sel.rar = Data.RAR_ORDER[i])
	v.add_child(UIK.hbox(8, [kinds, rars]))
	v.add_child(UIK.hbox(8, [UIK.spacer(), UIK.button("Выставить", "BtnPri", func():
		main.close_modal(); Online.create_offer(sel.give, {"kind": sel.kind, "rarity": sel.rar}), "swap")]))
	main.open_modal(v, 640)
