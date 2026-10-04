extends Screen
## Workshop: draft composer (pick parts) and the hands-on build panel.

const PHRASES := ["Съешь же ещё этих мягких французских булок, да выпей чаю", "the quick brown fox jumps over the lazy dog",
	"В чащах юга жил бы цитрус? Да, но фальшивый экземпляр!", "pack my box with five dozen liquor jugs",
	"Широкая электрификация южных губерний даст мощный толчок"]

var status_box: VBoxContainer
var tools_box: HFlowContainer
var next_btn: Button
var warn_box: VBoxContainer
var torque_ui: Control
var lube: Control
var typing = {}
var _last_spec_key = ""

func layout() -> String: return "side"
func side_width() -> float: return 500.0
func cam_view() -> String: return "persp"

func can_refresh() -> bool:
	if g().build != null: return false
	return super.can_refresh()

func _ready() -> void:
	main.ws.asm.status_changed.connect(_update_status)
	main.ws.asm.warn.connect(_on_warn)
	main.ws.asm.torque.connect(_on_torque)
	main.ws.asm.step_changed.connect(func(): if is_inside_tree(): build_screen(true))
	tree_exiting.connect(func(): if lube: lube.queue_free(); main.ws.kb.set_ghost(""))

func content(first: bool) -> Control:
	if g().build != null: return _build_view(first)
	return _draft_view(first)

# ================================================================== draft
func _group(cat: String, filter = null) -> Array:
	var gr = {}; var order = []
	for it in g().inv.items:
		if it.cat != cat: continue
		if filter is Callable and not filter.call(it): continue
		var k = "%s|%s|%s" % [it.id, it.get("layout", ""), it.get("color", "")]
		if not gr.has(k): gr[k] = {"item": it, "uids": []}; order.append(k)
		gr[k].uids.append(it.uid)
	return order.map(func(k): return gr[k])

func _auto_draft() -> void:
	var d: Dictionary = main.draft
	if not d.has("mods"): d.mods = {}
	var valid = func(u): return u != null and not Game.item_by_uid(u).is_empty()
	if not valid.call(d.get("case")):
		var gc = _group("case"); d.case = gc[0].uids[0] if gc.size() > 0 else null
	var cs = Game.item_by_uid(d.case) if d.get("case") != null else {}
	var lay: String = str(cs.get("layout", "")) if not cs.is_empty() else ""
	for key in ["plate", "pcb", "stab", "kc"]:
		var cur = Game.item_by_uid(d[key]) if d.get(key) != null else {}
		if not cur.is_empty() and (lay == "" or not cur.has("layout") or cur.layout == lay): continue
		var gr = _group(key, func(i): return not i.has("layout") or i.layout == lay)
		d[key] = gr[0].uids[0] if gr.size() > 0 else null
	var need: int = Data.LAYOUTS[lay].count if lay != "" else 0
	if d.get("sw") == null or int(g().inv.sw.get(d.sw, 0)) < need:
		var ok = []
		for id in g().inv.sw:
			if int(g().inv.sw[id]) >= need: ok.append(id)
		ok.sort_custom(func(a, b): return float(Data.sw(a).price) > float(Data.sw(b).price))
		d.sw = ok[0] if ok.size() > 0 else null
	for k in d.mods.keys():
		if d.mods[k] and int(g().inv.cons.get(k, 0)) < 1: d.mods[k] = false
	if d.get("art") != null and not (d.art in g().inv.art): d.art = null

func _draft_spec() -> Dictionary:
	var d: Dictionary = main.draft
	var it = func(u): return Game.item_by_uid(u) if u != null else {}
	var cs: Dictionary = it.call(d.get("case"))
	if cs.is_empty(): return {}
	var pl: Dictionary = it.call(d.get("plate")); var pc: Dictionary = it.call(d.get("pcb")); var st: Dictionary = it.call(d.get("stab")); var kc: Dictionary = it.call(d.get("kc"))
	return {"layout": cs.layout, "case": cs.id, "color": cs.get("color", 0), "plate": pl.get("id"), "pcb": pc.get("id"), "stab": st.get("id"),
		"kc": kc.get("id"), "sw": d.get("sw"), "mods": d.mods.duplicate(), "art": Game.art_base_id(str(d.art)) if d.get("art") else null, "lubeQ": 0.8 if d.mods.get("lube", false) else null}

static func full_spec(sp: Dictionary) -> Dictionary:
	var f = sp.duplicate()
	if f.get("plate") == null: f.plate = "p_fr4"
	if f.get("pcb") == null: f.pcb = "b_hs"
	if f.get("stab") == null: f.stab = "s_basic"
	if f.get("sw") == null: f.sw = "sw_red"
	if f.get("kc") == null: f.kc = "k_stock"
	return f

func _draft_view(first: bool) -> Control:
	_auto_draft()
	var d: Dictionary = main.draft
	var sp = _draft_spec()
	var lay: String = sp.get("layout", "")
	var need: int = Data.LAYOUTS[lay].count if lay != "" else 0
	var v = UIK.vbox(14)
	v.add_child(UIK.head("Верстак", "Новая сборка", [trend_chip()]))
	var ready: bool = not sp.is_empty() and sp.plate != null and sp.pcb != null and sp.stab != null and sp.kc != null and sp.sw != null and int(g().inv.sw.get(sp.sw, 0)) >= need
	# 3D preview
	if not sp.is_empty():
		var fs = full_spec(sp)
		var key = Keyboard3D.spec_key(fs)
		main.ws.kb.show_spec(fs, null)
		if key != _last_spec_key:
			if _last_spec_key != "" or first: main.ws.kb.reveal()
			_last_spec_key = key
			main.ws.fit_keyboard()
		main.set_kb_sound(fs)
		main.ws.kb.visible = true
	else:
		main.ws.kb.visible = false; main.set_kb_sound({})
	# start + forecast
	var top = UIK.vbox(10)
	var start = UIK.button("Начать сборку", "BtnPri", _start, "play"); start.custom_minimum_size.y = 50; start.disabled = not ready
	start.add_theme_font_size_override("font_size", 17)
	top.add_child(start)
	if ready:
		var st: Dictionary = Game.board_stats(sp)
		var cost = 0.0
		for k in ["case", "plate", "pcb", "stab", "kc"]: cost += float(Game.item_by_uid(d[k]).cost)
		cost += Game.sw_price(sp.sw) * need
		var b2 = sp.duplicate(); b2.st = st; b2.cost = cost
		var val = Game.board_value(b2)
		top.add_child(UIK.hbox(8, [UIK.label("Прогноз звука", "H3"), UIK.spacer(), UIK.chip(Game.sound_label(st), UIK.TEAL)]))
		top.add_child(_meters(st, Game.upl("studio") >= 1))
		top.add_child(UIK.hbox(8, [UIK.label("Себестоимость", "Muted"), UIK.spacer(), UIK.label(Game.rub(cost), "Num")]))
		top.add_child(UIK.hbox(8, [UIK.label("Оценочная цена", "Muted"), UIK.spacer(), UIK.label(Game.rub(val), "Price")]))
		top.add_child(UIK.label("Печатайте на своей клавиатуре или кликайте по 3D-модели: звучат настоящие записи свитчей. ПКМ — вращать, колесо — зум.", "SmallMuted", true))
	else:
		top.add_child(UIK.label("Соберите полный комплект деталей, чтобы увидеть прогноз звука и цены.", "SmallMuted", true))
	v.add_child(UIK.card("Card", top))
	if int(g().tut) < Game.TUT.size(): v.add_child(_guide())
	# slots
	var slots = UIK.vbox(12)
	slots.add_child(UIK.label("Детали со склада", "H3"))
	var cases = _group("case")
	slots.add_child(_slot("Корпус", cases.map(func(gr):
		var c = Data.case_(gr.item.id)
		return _opt("case", gr, c.name, "%s · %s" % [Data.LAYOUTS[gr.item.layout].name, c.colors[int(gr.item.get("color", 0))][0]], Color(c.colors[int(gr.item.get("color", 0))][1]))), "Нет корпусов."))
	if lay != "":
		var f = func(i): return not i.has("layout") or i.layout == lay
		slots.add_child(_slot("Пластина", _group("plate", f).map(func(gr): return _opt("plate", gr, Data.plate(gr.item.id).name, Data.LAYOUTS[gr.item.layout].name)), "Нет пластины под %s." % Data.LAYOUTS[lay].name))
		slots.add_child(_slot("Плата", _group("pcb", f).map(func(gr):
			var p = Data.pcb(gr.item.id)
			return _opt("pcb", gr, p.name, Data.LAYOUTS[gr.item.layout].name + (" · hotswap" if p.hs else "") + (" · RGB" if p.rgb else "") + (" · BT" if p.wl else ""))), "Нет платы под %s." % Data.LAYOUTS[lay].name))
		slots.add_child(_slot("Стабилизаторы", _group("stab").map(func(gr): return _opt("stab", gr, Data.stab(gr.item.id).name, "набор")), "Нет стабилизаторов."))
		var sws = []
		for id in g().inv.sw:
			if int(g().inv.sw[id]) <= 0: continue
			var s = Data.sw(id); var n = int(g().inv.sw[id])
			var b = _opt_btn(d.get("sw") == id, s.name, "%s · %d г · есть %d%s" % [Data.STYPE[s.type], int(s.force), n, " — мало" if n < need else ""], Color(s.stem))
			b.disabled = n < need
			b.pressed.connect(func(): d.sw = id; Audio.ui("socket"); build_screen(false))
			sws.append(b)
		slots.add_child(_slot("Свитчи · нужно %d" % need, sws, "Нет свитчей."))
		slots.add_child(_slot("Кейкапы", _group("kc").map(func(gr):
			var k = Data.kc(gr.item.id)
			return _opt("kc", gr, k.name, "%s · %s" % [Data.PROF[k.prof].name, k.mat], Color(k.c.a))), "Нет кейкапов."))
	v.add_child(UIK.card("Card", slots))
	# mods
	var mods = UIK.vbox(6, [UIK.label("Моды и расходники", "H3")])
	for c in Data.CONS:
		var n = int(g().inv.cons.get(c.id, 0))
		var cb = CheckBox.new(); cb.text = "%s  ·  есть %d" % [c.name, n]; cb.button_pressed = bool(d.mods.get(c.id, false)); cb.disabled = n < 1
		cb.tooltip_text = c.desc; cb.focus_mode = Control.FOCUS_NONE
		cb.toggled.connect(func(on): d.mods[c.id] = on; Audio.ui("tick"); build_screen(false))
		mods.add_child(cb)
		var dl = UIK.label(c.desc, "SmallMuted", true); dl.custom_minimum_size.x = 380
		mods.add_child(UIK.margin(dl, 32, -6, 0, 2))
	v.add_child(UIK.card("Card", mods))
	# artisan
	var arts = UIK.vbox(8, [UIK.label("Артизан на Esc", "H3")])
	var uniq = []
	for a in g().inv.art:
		if not (a in uniq): uniq.append(a)
	if uniq.is_empty():
		arts.add_child(UIK.label("Артизаны выпадают из коробок, конкурсов и VIP-заказов.", "SmallMuted", true))
	else:
		var fl = UIK.flow(6)
		var none = _opt_btn(d.get("art") == null, "Без артизана", "")
		none.pressed.connect(func(): d.art = null; build_screen(false)); fl.add_child(none)
		for a in uniq:
			var A = Data.art(Game.art_base_id(a))
			var ob = _opt_btn(d.get("art") == a, A.name, Data.RAR_NAME[A.r], Data.RAR_COL[A.r])
			ob.pressed.connect(func(): d.art = a; Audio.ui("cap"); build_screen(false)); fl.add_child(ob)
		arts.add_child(fl)
	v.add_child(UIK.card("Card", arts))
	return v

func _meters(st: Dictionary, full: bool) -> VBoxContainer:
	var m = UIK.vbox(5, [UIK.meter("Thock", st.thock, UIK.CORAL), UIK.meter("Громкость", st.loud, UIK.WARN), UIK.meter("Гладкость", st.smooth, UIK.TEAL), UIK.meter("Качество", st.quality, UIK.GOLD)])
	if full:
		for x in [["Эстетика", st.aesthetic, UIK.VIOLET], ["Звон пружин", st.ping, Color("d97a7a")], ["Дребезг стабов", st.rattle, Color("d97a7a")], ["Гулкость", st.hollow, Color("d97a7a")], ["Царапание", st.scratch, Color("d97a7a")]]:
			m.add_child(UIK.meter(x[0], x[1], x[2]))
	return m

func _guide() -> Control:
	var t: Dictionary = Game.TUT[int(g().tut)]
	var n = UIK.label("%d/%d" % [int(g().tut) + 1, Game.TUT.size()], "H3"); n.add_theme_color_override("font_color", UIK.GOLD)
	var h = UIK.hbox(12, [n, UIK.expand(UIK.vbox(2, [UIK.label("ПЕРВЫЕ ШАГИ", "Eyebrow"), UIK.label(t.t, "Small", true)])), UIK.label("+" + Game.rub(t.r), "Price")])
	var c = UIK.card("CardVip", h); return c

func _slot(title: String, opts: Array, none_text: String) -> Control:
	var v = UIK.vbox(6, [UIK.label(title.to_upper(), "Eyebrow")])
	if opts.is_empty():
		var go = UIK.button("На рынок", "BtnTeal", func(): main.open_tab("market"))
		v.add_child(UIK.hbox(10, [UIK.label(none_text, "SmallMuted"), UIK.spacer(), go]))
	else:
		var f = UIK.flow(6)
		for o in opts: f.add_child(o)
		v.add_child(f)
	return v

func _opt(key: String, gr: Dictionary, title: String, subt: String, col := Color(0, 0, 0, 0)) -> Button:
	var d: Dictionary = main.draft
	var on: bool = d.get(key) in gr.uids
	var b = _opt_btn(on, title, subt + (" · ×%d" % gr.uids.size() if gr.uids.size() > 1 else ""), col)
	b.pressed.connect(func(): d[key] = gr.uids[0]; Audio.ui("socket"); build_screen(false))
	return b

func _opt_btn(on: bool, title: String, subt: String, col := Color(0, 0, 0, 0)) -> Button:
	var b = Button.new(); b.toggle_mode = true; b.button_pressed = on; b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var n = UIK.mg(UIK.sb(Color(1, 1, 1, 0.035), 10, Color(1, 1, 1, 0.08), 0), 12, 8)
	var p = UIK.mg(UIK.sb(Color(0.3, 0.72, 0.67, 0.14), 10, UIK.TEAL, 0), 12, 8)
	b.add_theme_stylebox_override("normal", n); b.add_theme_stylebox_override("hover", UIK.mg(UIK.sb(Color(1, 1, 1, 0.07), 10, Color(1, 1, 1, 0.16), 0), 12, 8))
	b.add_theme_stylebox_override("pressed", p); b.add_theme_stylebox_override("hover_pressed", p)
	b.add_theme_stylebox_override("disabled", UIK.mg(UIK.sb(Color(1, 1, 1, 0.015), 10, Color(1, 1, 1, 0.04), 0), 12, 8))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var inner = UIK.vbox(1)
	var tl = UIK.label(title, "Small"); tl.add_theme_font_override("font", UIK.f_bold)
	var row = UIK.hbox(6)
	if col.a > 0: row.add_child(UIK.swatch(col, 12))
	row.add_child(tl)
	inner.add_child(row)
	if subt != "": inner.add_child(UIK.label(subt, "SmallMuted"))
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mc = UIK.margin(inner, 12, 8, 12, 8); mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(mc)
	b.custom_minimum_size = Vector2(max(130, inner.get_combined_minimum_size().x + 26), inner.get_combined_minimum_size().y + 16)
	mc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UIK.juice(b)
	return b

func _start() -> void:
	var d: Dictionary = main.draft
	var sp = _draft_spec()
	var ok = Game.start_build({"layout": sp.layout, "case": d.case, "plate": d.plate, "pcb": d.pcb, "stab": d.stab, "kc": d.kc, "sw": d.sw, "mods": d.mods.duplicate(), "art": d.get("art")})
	if not ok: return
	main.draft = {"mods": {}}
	_last_spec_key = ""
	Audio.ui("whoosh"); main.flash(Color(0.3, 0.72, 0.67, 0.12))
	main.ws.set_view("persp")
	build_screen(true)

# ================================================================== build
func _build_view(first: bool) -> Control:
	var b: Dictionary = g().build
	var asm: Asm = main.ws.asm
	var st = asm.step()
	var info: Dictionary = Asm.STEP_INFO[st]
	var L: Dictionary = Data.LAYOUTS[b.layout]
	main.ws.kb.visible = true
	if first:
		asm.enter()
		main.ws.fit_keyboard()
		main.ws.mode = "asm" if not (st in ["keytest", "test"]) else "view"
		if st in ["sw", "kc", "solder", "stab"]: main.ws.set_view("close" if L.W <= 16 else "persp")
		elif st == "screw": main.ws.set_view("persp")
		elif st == "test": main.ws.set_view("hero")
		else: main.ws.set_view("persp")
		if st in ["keytest", "test"]: main.set_kb_sound(Game.build_spec(b))
		else: main.set_kb_sound({})
	_setup_lube(st == "lube")
	var v = UIK.vbox(14)
	# header with steps
	var steps = UIK.flow(4)
	for i in b.steps.size():
		var s: String = b.steps[i]
		var col = UIK.TEAL if i == int(b.step) else (UIK.GOOD if i < int(b.step) else UIK.MUTE)
		var c = UIK.chip(("✓ " if i < int(b.step) else "%d. " % (i + 1)) + Asm.STEP_INFO[s].n, col)
		steps.add_child(c)
	var cancel = UIK.button("Отменить", "BtnGhost", func(): main.confirm("Отменить сборку?", "Детали вернутся на склад, расходники пропадут.", "Отменить сборку", func(): Game.cancel_build(); main.ws.kb.set_ghost(""); build_screen(true)))
	v.add_child(UIK.head("Сборка · %s · себестоимость %s" % [L.name, Game.rub(b.cost)], info.t, [] if st == "test" else [cancel]))
	v.add_child(steps)
	if st == "test": return _test_view(v, b)
	# status
	var card = UIK.vbox(10)
	status_box = UIK.vbox(8); card.add_child(status_box)
	tools_box = UIK.flow(6); card.add_child(tools_box)
	warn_box = UIK.vbox(6); card.add_child(warn_box)
	var row = UIK.hbox(8)
	if st == "lube":
		var ld = UIK.button("Готово с этим этапом", "BtnTeal", func(): if lube: lube.finish_round())
		ld.name = "lubeDone"; row.add_child(ld)
	row.add_child(UIK.spacer())
	next_btn = UIK.button("Дальше", "BtnPri", func(): asm.next_step(false)); next_btn.icon = UIK.icon("play", 32, Color("1a0d08"))
	next_btn.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT; next_btn.custom_minimum_size = Vector2(150, 44)
	row.add_child(next_btn)
	card.add_child(row)
	v.add_child(UIK.card("CardHi", card))
	# help
	var help = UIK.vbox(8, [UIK.label("ЭТАП %d ИЗ %d" % [int(b.step) + 1, b.steps.size()], "Eyebrow"), UIK.label(info.help, "Small", true)])
	var ctl = UIK.flow(6)
	for c in info.ctl: ctl.add_child(UIK.chip(c))
	help.add_child(ctl)
	v.add_child(UIK.card("Card", help))
	_update_status()
	return v

func _update_status() -> void:
	if not is_instance_valid(status_box) or g().build == null: return
	var b: Dictionary = g().build; var asm: Asm = main.ws.asm; var st = asm.step(); var n: int = b.ks.size()
	for c in status_box.get_children(): c.queue_free()
	for c in tools_box.get_children(): c.queue_free()
	var line = func(t: String, val: String, col := UIK.INK):
		var l = UIK.label(val, "Num"); l.add_theme_color_override("font_color", col)
		return UIK.hbox(8, [UIK.label(t, "Small"), UIK.spacer(), l])
	match st:
		"case":
			var q = Asm.piece_queue(b); var cur = ""
			for p in q:
				if not b.pieces.has(p): cur = p; break
			for p in q:
				var state = "✓ на месте" if b.pieces.has(p) else ("развёрнута — R" if p == cur and int(b.prot.get(p, 0)) % 4 != 0 else ("готова" if p == cur else "ждёт"))
				var col = UIK.GOOD if b.pieces.has(p) else (UIK.CORAL if p == cur else UIK.MUTE)
				status_box.add_child(UIK.hbox(8, [UIK.label(Asm.PIECE_N[p] + (" · tape-mod наклеен" if p == "pcb" and b.mods.get("tape", false) else ""), "Small"), UIK.spacer(), UIK.chip(state, col)]))
			tools_box.add_child(UIK.button("Повернуть (R)", "Button", asm.rotate_piece, "rotate"))
		"stab":
			var t = Game.stab_targets(b.layout); var dn = 0
			for i in t: if b.stabs.has(str(i)): dn += 1
			status_box.add_child(line.call("Стабилизаторы", "%d/%d" % [dn, t.size()]))
			status_box.add_child(UIK.bar(float(dn) / max(1, t.size())))
			status_box.add_child(UIK.label("Стабы смазаны диэлектрической смазкой." if b.mods.get("stablube", false) else "Без смазки стабы будут дребезжать.", "SmallMuted", true))
		"lube":
			if lube: status_box.add_child(lube.status_ui())
		"sw":
			var dn = 0; var bent = 0
			for k in b.ks:
				if int(k.s) == 1: dn += 1
				if int(k.b) == 1: bent += 1
			status_box.add_child(line.call("Вставлено", "%d/%d" % [dn, n]))
			status_box.add_child(UIK.bar(float(dn) / n))
			status_box.add_child(UIK.hbox(8, [UIK.label("Погнуто сейчас", "Small"), UIK.colored(str(bent), UIK.BAD if bent else UIK.GOOD, "Num"), UIK.spacer(), UIK.label("за сборку: %d" % int(b.bentEver), "SmallMuted")]))
			var spd = UIK.bar(0, UIK.GOOD, 9); spd.name = "spd"
			status_box.add_child(UIK.vbox(3, [UIK.label("Скорость руки", "SmallMuted"), spd]))
			_tools_hand(asm, "Рука")
		"solder":
			var dn = 0
			for k in b.ks: if float(k.so) >= 1.0: dn += 1
			status_box.add_child(line.call("Пропаяно", "%d/%d" % [dn, n]))
			status_box.add_child(UIK.bar(float(dn) / n, Color("cfd6dc")))
		"screw":
			var z = Asm.torque_zone(); var dn = 0
			for x in b.screws: if x != null and float(x) >= z.lo: dn += 1
			status_box.add_child(line.call("Винты", "%d/6" % dn))
			torque_ui = _torque_gauge(z); status_box.add_child(UIK.vbox(4, [UIK.label("Усилие", "SmallMuted"), torque_ui]))
			status_box.add_child(UIK.rich(asm.tq_msg if asm.tq_msg != "" else "[color=#8a97a3]Начните с винта №1.[/color]", 13))
		"kc":
			var dn = 0; var w = 0
			for k in b.ks:
				if int(k.c) == 1: dn += 1
				if int(k.w) == 1: w += 1
			status_box.add_child(line.call("Кейкапы", "%d/%d" % [dn, n]))
			status_box.add_child(UIK.bar(float(dn) / n))
			if Asm.kc_sculpted(b):
				status_box.add_child(UIK.label("ЛОТОК: ВЫБЕРИТЕ РЯД", "Eyebrow"))
				var names = Asm.row_names(b.layout); var fl = UIK.flow(5)
				var Lk: Array = Data.LAYOUTS[b.layout].keys
				for r in int(Data.LAYOUTS[b.layout].rows):
					var left = 0
					for i in b.ks.size(): if int(b.ks[i].c) == 0 and int(Lk[i].row) == r: left += 1
					var rb = UIK.button("%s · %d" % [names[r] if r < names.size() else "Ряд %d" % (r + 1), left], "Sub", func(): asm.kit = r; _update_status())
					rb.toggle_mode = true; rb.button_pressed = asm.kit == r; rb.disabled = left == 0
					fl.add_child(rb)
				status_box.add_child(fl)
			else:
				status_box.add_child(UIK.label("Профиль XDA одинаков во всех рядах — ставьте в любом порядке.", "SmallMuted", true))
			status_box.add_child(UIK.hbox(8, [UIK.label("Не в своём ряду", "Small"), UIK.colored(str(w), UIK.BAD if w else UIK.GOOD, "Num")]))
			_tools_hand(asm, "Колпачки")
		"keytest":
			var t = 0; var dd = 0
			for k in b.ks:
				if int(k.t) == 1: t += 1
				if int(k.d) == 1: dd += 1
			status_box.add_child(line.call("Проверено", "%d/%d" % [t, n]))
			status_box.add_child(UIK.bar(float(t) / n, UIK.GOOD))
			status_box.add_child(UIK.hbox(8, [UIK.label("Не работают", "Small"), UIK.colored(str(dd), UIK.BAD if dd else UIK.GOOD, "Num"), UIK.spacer(), UIK.label("починено: %d" % int(b.fixes), "SmallMuted")]))
			tools_box.add_child(UIK.button("Автотест", "BtnTeal", asm.autotest, "zap"))
	if Game.upl("bench") >= 3 and not (st in ["test", "lube"]):
		var ab = UIK.button("Авто", "BtnGhost", asm.auto, "zap"); ab.tooltip_text = "Верстак 3 уровня: выполнить этап автоматически"; tools_box.add_child(ab)
	if is_instance_valid(next_btn): next_btn.disabled = not asm.done()
	if is_instance_valid(next_btn) and asm.done() and not next_btn.has_meta("pulsed"):
		next_btn.set_meta("pulsed", true); UIK.pop(next_btn, 1.1)

func _tools_hand(asm: Asm, main_name: String) -> void:
	var a = UIK.button(main_name, "BtnTeal" if asm.tool == "main" else "BtnGhost", func(): asm.set_tool("main"), "hand")
	var p = UIK.button("Съёмник", "BtnTeal" if asm.tool == "pull" else "BtnGhost", func(): asm.set_tool("pull"), "x")
	tools_box.add_child(a); tools_box.add_child(p)

func _process(_d: float) -> void:
	if g().build == null or not is_instance_valid(status_box): return
	if main.ws.asm.step() == "sw":
		var spd: ProgressBar = status_box.find_child("spd", true, false)
		if spd and not main.ws._drag.is_empty():
			var thr: float = 0.8 * (1.0 + 0.35 * min(Game.upl("bench"), 2))
			var sv: float = float(main.ws._drag.get("spd", 0.0))
			spd.value = clamp(sv / thr * 0.7, 0.0, 1.0)
			spd.add_theme_stylebox_override("fill", UIK.sb(UIK.BAD if sv > thr else (UIK.WARN if sv > thr * 0.75 else UIK.GOOD), 99, Color(0, 0, 0, 0), 0))
		elif spd: spd.value = lerp(spd.value, 0.0, 0.2)

func _on_warn(text: String) -> void:
	if not is_instance_valid(warn_box): return
	for c in warn_box.get_children(): c.queue_free()
	var go = UIK.button("Продолжить", "BtnPri", func(): main.ws.asm.next_step(true))
	warn_box.add_child(UIK.note("[color=#ffc46e]%s[/color]" % text, UIK.WARN)); warn_box.add_child(UIK.hbox(8, [UIK.spacer(), go]))
	UIK.appear(warn_box); Audio.ui("bad")

func _torque_gauge(z: Dictionary) -> Control:
	var c = Control.new(); c.custom_minimum_size = Vector2(300, 22)
	c.draw.connect(func():
		var w = c.size.x; var h = c.size.y
		c.draw_style_box(UIK.sb(Color(1, 1, 1, 0.07), 6, Color(0, 0, 0, 0), 0), Rect2(0, 4, w, h - 8))
		c.draw_rect(Rect2(w * z.plo / 1.1, 4, w * (z.phi - z.plo) / 1.1, h - 8), Color(UIK.GOOD, 0.55))
		c.draw_rect(Rect2(w * z.lo / 1.1, 4, w * (z.plo - z.lo) / 1.1, h - 8), Color(UIK.GOOD, 0.2))
		c.draw_rect(Rect2(w * z.strip / 1.1, 4, w - w * z.strip / 1.1, h - 8), Color(UIK.BAD, 0.55))
		var tq: float = c.get_meta("tq", 0.0)
		var x: float = clamp(tq / 1.1, 0.0, 1.0) * w
		c.draw_rect(Rect2(x - 2, 0, 4, h), Color.WHITE)
		c.draw_circle(Vector2(x, 0), 4, Color.WHITE))
	return c

func _on_torque(v: float) -> void:
	if is_instance_valid(torque_ui): torque_ui.set_meta("tq", v); torque_ui.queue_redraw()

# ---------------------------------------------------------------- lube
func _setup_lube(on: bool) -> void:
	if on and lube == null:
		lube = LubeGame.new(); lube.main = main
		main.host.add_child(lube); main.host.move_child(lube, 0)
		lube.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); lube.offset_right = -side_width() - 16
		lube.changed.connect(_update_status)
		lube.start()
		main.ws.kb.visible = false
	elif not on and lube:
		lube.queue_free(); lube = null; main.ws.kb.visible = true

# ---------------------------------------------------------------- test
func _test_view(v: VBoxContainer, b: Dictionary) -> Control:
	var spec = Game.build_spec(b)
	var st: Dictionary = Game.board_stats(spec)
	var sw = Data.sw(b.sw)
	var an = UIK.vbox(8, [UIK.hbox(8, [UIK.label("Анализатор", "H3"), UIK.spacer(), UIK.chip(Game.sound_label(st), UIK.TEAL)]), _meters(st, Game.upl("studio") >= 1)])
	an.add_child(UIK.hbox(8, [UIK.label("Точность сборки", "Muted"), UIK.spacer(), UIK.label("%d%%" % int(round(float(b.precision if b.precision != null else 0) * 100)), "Num")]))
	if int(b.get("dead", 0)) > 0: an.add_child(UIK.hbox(8, [UIK.label("Мёртвые клавиши", "Muted"), UIK.spacer(), UIK.colored(str(b.dead), UIK.BAD, "Num")]))
	if int(b.get("wrongLeft", 0)) > 0: an.add_child(UIK.hbox(8, [UIK.label("Кривые колпачки", "Muted"), UIK.spacer(), UIK.colored(str(b.wrongLeft), UIK.BAD, "Num")]))
	an.add_child(UIK.hbox(8, [UIK.label("Запись свитча", "Muted"), UIK.spacer(), UIK.label(str(Data.SND_SETS.get(sw.snd, {}).get("n", "синтез")), "Small")]))
	if Game.upl("studio") >= 1: an.add_child(Scope.new())
	v.add_child(UIK.card("Card", an))
	if typing.is_empty() or typing.get("done", false) == null: typing = {"p": PHRASES[randi() % PHRASES.size()], "start": 0, "done": false}
	var td = UIK.vbox(10, [UIK.label("Тест-драйв", "H3"), UIK.label("Печатайте на своей клавиатуре: звучат настоящие записи, обработанные под корпус, пластину, кейкапы и моды.", "SmallMuted", true)])
	var phrase = UIK.card("Note", UIK.label(typing.p, "Num", true)); td.add_child(phrase)
	var box = LineEdit.new(); box.placeholder_text = "Начните печатать…"; box.set_meta("typebox", true)
	var stat = UIK.label("Скорость появится после фразы", "SmallMuted")
	box.text_changed.connect(func(t): _typing(t, stat))
	td.add_child(box); td.add_child(stat)
	td.add_child(UIK.sep())
	td.add_child(UIK.label("НАЗВАНИЕ СБОРКИ", "Eyebrow"))
	var nm = LineEdit.new(); nm.text = Game.auto_name(spec); nm.max_length = 40; td.add_child(nm)
	var b2 = spec.duplicate(); b2.st = st; b2.cost = b.cost
	var fin = UIK.button("Завершить сборку", "BtnPri", func(): _finish(nm.text), "check"); fin.custom_minimum_size.y = 48
	td.add_child(UIK.hbox(10, [UIK.label("Качество %d · оценка %s" % [int(st.quality), Game.rub(Game.board_value(b2))], "Small"), UIK.spacer()]))
	td.add_child(fin)
	v.add_child(UIK.card("CardHi", td))
	return v

func _typing(t: String, stat: Label) -> void:
	if typing.get("done", false): return
	if int(typing.start) == 0 and t.length() > 0: typing.start = Time.get_ticks_msec()
	if t.length() >= str(typing.p).length():
		typing.done = true
		var mins: float = max(0.05, (Time.get_ticks_msec() - int(typing.start)) / 60000.0)
		var ok = 0
		for i in str(typing.p).length(): if i < t.length() and t[i] == str(typing.p)[i]: ok += 1
		var acc = int(round(ok * 100.0 / str(typing.p).length())); var wpm = int(round(str(typing.p).length() / 5.0 / mins))
		stat.text = "%d WPM · точность %d%%" % [wpm, acc]; stat.add_theme_color_override("font_color", UIK.GOOD)
		if g().build and not g().build.get("typed", false):
			g().build.typed = true; Game.add_xp(25 + acc / 4)
			Game.toast("Тест-драйв: %d слов/мин, точность %d%% · +опыт" % [wpm, acc])

func _finish(n: String) -> void:
	var board = Game.finish_build(n)
	typing = {}
	main.set_kb_sound({})
	main.ws.mode = "view"; main.ws.kb.set_ghost("")
	main.ws.kb.show_spec(board, null); main.ws.kb.reveal(); main.ws.set_view("hero")
	main.flash(Color(1, 0.85, 0.5, 0.25))
	_celebrate(board)
	build_screen(true)

func _celebrate(board: Dictionary) -> void:
	var v = UIK.vbox(12, [main.modal_head(board.name, "Сборка готова"), UIK.hbox(10, [UIK.chip(Data.LAYOUTS[board.layout].name), UIK.chip(Game.sound_label(board.st), UIK.TEAL)])])
	v.add_child(_meters(board.st, true))
	v.add_child(UIK.hbox(8, [UIK.label("Рыночная цена", "Muted"), UIK.spacer(), UIK.label(Game.rub(Game.board_value(board)), "Price")]))
	var row = UIK.hbox(8, [UIK.button("К заказам", "BtnTeal", func(): main.close_modal(); main.open_tab("orders")), UIK.button("На витрину", "BtnGhost", func(): main.close_modal(); main.open_tab("shop")), UIK.spacer(), UIK.button("Отлично", "BtnPri", main.close_modal)])
	v.add_child(row)
	main.open_modal(v, 540)
