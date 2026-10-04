extends Screen
## Stylised city map: suppliers, clients (orders), properties for sale, courier.

const PROP_POS := {"garage": Vector2(0.14, 0.82), "loft": Vector2(0.36, 0.6), "studio": Vector2(0.52, 0.44), "boutique": Vector2(0.64, 0.3), "flagship": Vector2(0.86, 0.16)}

var map: MapView
var info: VBoxContainer
var selected = {}

func content(first: bool) -> Control:
	var v = UIK.vbox(12)
	v.add_child(UIK.head("Город " + Data.CITIES[int(g().prestige.city)], "Карта города", [UIK.chip("Заказов: %d" % g().orders.size(), UIK.CORAL), UIK.chip("Поставщик: " + Data.supplier(g().market.supplier).name, UIK.TEAL)]))
	var row = UIK.hbox(14)
	map = MapView.new(); map.scr = self
	map.custom_minimum_size = Vector2(600, 560); UIK.expand(map, true, true)
	var mp = UIK.card("Card", map); UIK.expand(mp, true, true)
	(mp.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_left = 0
	mp.add_theme_stylebox_override("panel", UIK.sb(Color("0d1216"), 14, UIK.LINE, 0))
	mp.clip_contents = true
	row.add_child(mp)
	info = UIK.vbox(10); info.custom_minimum_size.x = 360
	row.add_child(UIK.card("Card", info))
	v.add_child(row)
	var leg = UIK.flow(14, [_leg(UIK.CORAL, "Ваша мастерская"), _leg(UIK.TEAL, "Поставщики"), _leg(UIK.GOLD, "Помещения на продажу"), _leg(UIK.GOOD, "Ваши помещения"), _leg(UIK.VIOLET, "Клиенты с заказами")])
	v.add_child(leg)
	if main.sub.has("map_focus"):
		for o in g().orders:
			if o.id == main.sub.map_focus: selected = {"type": "order", "o": o}
		main.sub.erase("map_focus")
	_fill_info()
	if main.sub.has("courier"):
		var dest: Vector2 = main.sub.courier; main.sub.erase("courier")
		(func(): map.courier(dest)).call_deferred()
	return v

func _leg(c: Color, t: String) -> Control: return UIK.hbox(6, [UIK.swatch(c, 10), UIK.label(t, "SmallMuted")])

func can_refresh() -> bool: return false

func select(s: Dictionary) -> void:
	selected = s; Audio.ui("tick"); _fill_info()

func _fill_info() -> void:
	if not is_instance_valid(info): return
	for c in info.get_children(): c.queue_free()
	var S = g()
	if selected.is_empty():
		info.add_child(UIK.label("Выберите точку на карте", "H3"))
		info.add_child(UIK.label("Поставщики продают разные категории деталей со скидкой. Клиенты ждут заказы в своих районах — курьер отвезёт клавиатуру. Помещения ближе к центру приводят больше покупателей.", "SmallMuted", true))
		info.add_child(UIK.sep())
		info.add_child(UIK.label("ВАШЕ ПОМЕЩЕНИЕ", "Eyebrow"))
		info.add_child(PropCard.make(main, Data.prop(S.property)))
		UIK.stagger(info); return
	match selected.type:
		"supplier":
			var s: Dictionary = selected.s
			var cur: bool = S.market.supplier == s.id; var lock: bool = int(s.lvl) > int(S.level)
			info.add_child(UIK.hbox(8, [UIK.icon_rect("truck", 26, UIK.TEAL), UIK.expand(UIK.label(s.name, "H3", true))]))
			info.add_child(UIK.label(s.desc, "Small", true))
			var cats = UIK.flow(5)
			for c in s.cats: cats.add_child(UIK.chip(Data.CAT_NAMES[c]))
			info.add_child(cats)
			if float(s.mod) != 0: info.add_child(UIK.chip("Скидка %d%%" % int(-float(s.mod) * 100), UIK.GOOD))
			if lock: info.add_child(UIK.chip("Откроется на %d уровне" % int(s.lvl), UIK.BAD))
			var b = UIK.button("Вы закупаетесь здесь" if cur else "Закупаться здесь", "BtnTeal", func(): S.market.supplier = s.id; Game.mark(); Audio.ui("whoosh"); map.queue_redraw(); _fill_info(), "truck")
			b.disabled = cur or lock; info.add_child(b)
			info.add_child(UIK.button("Открыть каталог", "BtnPri", func(): S.market.supplier = s.id; Game.mark(); main.open_tab("market"), "cart"))
		"prop":
			info.add_child(PropCard.make(main, selected.p))
		"order":
			var o: Dictionary = selected.o
			info.add_child(UIK.hbox(8, [UIK.icon_rect("user", 24, Color(o.col)), UIK.expand(UIK.label(o.name, "H3")), UIK.label(Game.rub(o.budget), "Price")]))
			info.add_child(UIK.card("Note", UIK.label("«%s»" % o.text, "Small", true)))
			info.add_child(UIK.label("VIP-клиент" if o.kind == "vip" else "Ждёт ещё %d дн." % max(0, int(o.expires) - int(S.day)), "SmallMuted"))
			var b = UIK.button("Отдать клавиатуру", "BtnPri", func(): main.open_tab("orders"); main.screen._deliver_modal(o), "truck"); b.disabled = S.boards.is_empty()
			info.add_child(b)
	UIK.stagger(info, 0.0, 0.03)

# ======================================================================
class MapView extends Control:
	var scr
	var zoom = 1.0
	var pan = Vector2.ZERO
	var _drag = false
	var _t = 0.0
	var hover = {}
	var pois: Array = []
	var van = {}
	var blocks: Array = []
	var roads_h: Array = []
	var roads_v: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		clip_contents = true
		var rng = RandomNumberGenerator.new(); rng.seed = 77
		var y = 0.0
		while y < 1.0:
			roads_h.append(y); y += rng.randf_range(0.08, 0.14)
		var x = 0.0
		while x < 1.0:
			roads_v.append(x); x += rng.randf_range(0.07, 0.12)
		for i in roads_h.size() - 1:
			for j in roads_v.size() - 1:
				var r = Rect2(roads_v[j], roads_h[i], roads_v[j + 1] - roads_v[j], roads_h[i + 1] - roads_h[i]).grow(-0.008)
				var park = rng.randf() < 0.1
				blocks.append({"r": r, "park": park, "h": rng.randf()})

	func to_px(p: Vector2) -> Vector2: return (p - Vector2(0.5, 0.5)) * size * zoom + size / 2.0 + pan
	func from_px(p: Vector2) -> Vector2: return (p - size / 2.0 - pan) / (size * zoom) + Vector2(0.5, 0.5)

	func river_y(x: float) -> float: return 0.52 + sin(x * 5.0) * 0.08 + sin(x * 11.0 + 1.0) * 0.025

	func _process(d: float) -> void:
		_t += d
		if not van.is_empty():
			van.t += d / van.dur
			if van.t >= 1.0:
				Audio.ui("coin"); van = {}
		queue_redraw()

	func courier(dest: Vector2) -> void:
		var home: Vector2 = scr.PROP_POS.get(Game.S.property, Vector2(0.14, 0.82))
		var path = [home, Vector2(dest.x, home.y), dest]
		van = {"path": path, "t": 0.0, "dur": 2.4}
		Audio.ui("whoosh")

	func _van_pos() -> Vector2:
		var p: Array = van.path
		var l1: float = p[0].distance_to(p[1]); var l2: float = p[1].distance_to(p[2])
		var t: float = ease(van.t, -1.8) * (l1 + l2)
		if t < l1: return p[0].lerp(p[1], t / max(l1, 0.0001))
		return p[1].lerp(p[2], (t - l1) / max(l2, 0.0001))

	func _build_pois() -> void:
		pois.clear()
		var S: Dictionary = Game.S
		for s in Data.SUPPLIERS: pois.append({"type": "supplier", "s": s, "pos": s.pos, "col": UIK.TEAL, "ico": "truck", "cur": S.market.supplier == s.id})
		for p in Data.PROPERTIES:
			var owned: bool = p.id in S.owned_props; var cur: bool = S.property == p.id
			var col = UIK.CORAL if cur else (UIK.GOOD if owned else (UIK.GOLD if int(p.lvl) <= int(S.level) else UIK.MUTE))
			pois.append({"type": "prop", "p": p, "pos": scr.PROP_POS[p.id], "col": col, "ico": "home", "cur": cur})
		for o in S.orders:
			var dpos = o.get("district", Vector2(0.5, 0.5))
			if dpos is String: dpos = str_to_var(dpos) if str(dpos).begins_with("Vector2") else Vector2(0.5, 0.5)
			pois.append({"type": "order", "o": o, "pos": dpos, "col": UIK.GOLD if o.kind == "vip" else UIK.VIOLET, "ico": "user", "cur": false})

	func _draw() -> void:
		_build_pois()
		draw_rect(Rect2(Vector2.ZERO, size), Color("0f151a"))
		# blocks
		for b in blocks:
			var r: Rect2 = b.r
			var a = to_px(r.position); var e = to_px(r.end)
			var rr = Rect2(a, e - a)
			if b.park: draw_style_box(UIK.sb(Color("1d3a2a"), 6, Color(0, 0, 0, 0), 0), rr)
			else:
				draw_style_box(UIK.sb(Color("1a2229").lerp(Color("212b33"), b.h), 4, Color(0, 0, 0, 0), 0), rr)
				# buildings
				var n = 2 + int(b.h * 3)
				for k in n:
					var bw = rr.size.x / n
					var hh: float = rr.size.y * (0.35 + fmod(b.h * (k + 3) * 7.13, 0.5))
					draw_rect(Rect2(rr.position + Vector2(k * bw + 2, rr.size.y - hh - 2), Vector2(bw - 4, hh)), Color("27323b").lerp(Color("2e3a44"), fmod(b.h * (k + 1) * 3.7, 1.0)))
		# roads
		for y in roads_h: draw_line(to_px(Vector2(0, y)), to_px(Vector2(1, y)), Color("2c363f"), 3.0 * zoom)
		for x in roads_v: draw_line(to_px(Vector2(x, 0)), to_px(Vector2(x, 1)), Color("2c363f"), 3.0 * zoom)
		# avenues
		draw_line(to_px(Vector2(0, 0.9)), to_px(Vector2(1, 0.1)), Color("3a4650"), 6.0 * zoom)
		# river
		var pts = PackedVector2Array(); var pts2 = PackedVector2Array()
		for i in 61:
			var x = i / 60.0
			pts.append(to_px(Vector2(x, river_y(x) - 0.03))); pts2.append(to_px(Vector2(x, river_y(x) + 0.03)))
		var poly = pts.duplicate(); var rev = pts2.duplicate(); rev.reverse(); poly.append_array(rev)
		draw_colored_polygon(poly, Color("173447"))
		draw_polyline(pts, Color("23506b"), 1.5, true); draw_polyline(pts2, Color("23506b"), 1.5, true)
		# bridges
		for x in [0.25, 0.55, 0.8]:
			draw_line(to_px(Vector2(x, river_y(x) - 0.045)), to_px(Vector2(x, river_y(x) + 0.045)), Color("4a5864"), 5.0 * zoom)
		# delivery route to selected order
		var home: Vector2 = scr.PROP_POS.get(Game.S.property, Vector2(0.14, 0.82))
		if scr.selected.get("type", "") == "order":
			var d = scr.selected.o.get("district", Vector2(0.5, 0.5))
			_dash(to_px(home), to_px(Vector2(d.x, home.y)), UIK.VIOLET); _dash(to_px(Vector2(d.x, home.y)), to_px(d), UIK.VIOLET)
		# POIs
		for p in pois:
			var c = to_px(p.pos)
			var hov: bool = hover == p or (scr.selected.get("type") == p.type and _same(scr.selected, p))
			var pulse = 0.5 + 0.5 * sin(_t * 3.0 + c.x * 0.01)
			var col: Color = p.col
			draw_circle(c, (16.0 + pulse * 8.0) * (1.25 if hov else 1.0), Color(col, 0.12 * (1.0 - pulse * 0.5)))
			draw_circle(c, 13.0 * (1.2 if hov else 1.0), Color("0d1216"))
			draw_arc(c, 13.0 * (1.2 if hov else 1.0), 0, TAU, 32, col, 2.5, true)
			var tex = UIK.icon(p.ico, 32, col)
			draw_texture_rect(tex, Rect2(c - Vector2(8, 8), Vector2(16, 16)), false)
			if p.cur: draw_circle(c + Vector2(10, -10), 4, UIK.CORAL)
			if hov or zoom > 1.4:
				var name: String = p.s.name if p.type == "supplier" else (p.p.name if p.type == "prop" else p.o.name)
				var f: Font = UIK.f_bold
				var tw = f.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
				draw_style_box(UIK.sb(Color(0.05, 0.07, 0.09, 0.92), 6, Color(col, 0.5), 0), Rect2(c + Vector2(-tw / 2 - 8, 18), Vector2(tw + 16, 22)))
				draw_string(f, c + Vector2(-tw / 2, 34), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIK.INK)
		# courier van
		if not van.is_empty():
			var vp = to_px(_van_pos())
			draw_circle(vp, 14, Color(UIK.CORAL, 0.25))
			draw_texture_rect(UIK.icon("truck", 40, UIK.CORAL), Rect2(vp - Vector2(11, 11), Vector2(22, 22)), false)
		# compass + scale
		draw_string(UIK.f_disp, Vector2(16, 28), "N ↑", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UIK.MUTE)
		draw_string(UIK.f_body, Vector2(16, size.y - 14), "Колесо — масштаб, перетаскивание — сдвиг", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UIK.MUTE)

	func _same(sel: Dictionary, p: Dictionary) -> bool:
		match p.type:
			"supplier": return sel.has("s") and sel.s.id == p.s.id
			"prop": return sel.has("p") and sel.p.id == p.p.id
			"order": return sel.has("o") and sel.o.id == p.o.id
		return false

	func _dash(a: Vector2, b: Vector2, col: Color) -> void:
		var n = int(a.distance_to(b) / 10.0)
		var off = fmod(_t * 2.0, 1.0)
		for i in n:
			if i % 2 == 0: draw_line(a.lerp(b, (i + off) / n), a.lerp(b, min(1.0, (i + 1 + off) / n)), Color(col, 0.8), 2.5)

	func _poi_at(pos: Vector2) -> Dictionary:
		for p in pois:
			if to_px(p.pos).distance_to(pos) < 16: return p
		return {}

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton:
			if e.button_index == MOUSE_BUTTON_WHEEL_UP and e.pressed:
				var before = from_px(e.position); zoom = min(3.0, zoom * 1.12); pan += e.position - to_px(before); accept_event()
			elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN and e.pressed:
				var before2 = from_px(e.position); zoom = max(1.0, zoom / 1.12); pan += e.position - to_px(before2)
				if zoom <= 1.0: pan = Vector2.ZERO
				accept_event()
			elif e.button_index == MOUSE_BUTTON_LEFT:
				if e.pressed:
					var p = _poi_at(e.position)
					if not p.is_empty():
						var sel = {"type": p.type}
						for k in ["s", "p", "o"]: if p.has(k): sel[k] = p[k]
						scr.select(sel)
					else: _drag = true
				else: _drag = false
				accept_event()
		elif e is InputEventMouseMotion:
			if _drag and zoom > 1.0: pan += e.relative
			var h = _poi_at(e.position)
			if h != hover:
				hover = h
				if not h.is_empty(): Audio.ui("hover")
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not h.is_empty() else Control.CURSOR_ARROW
