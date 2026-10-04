extends Screen
## Mystery boxes: bought with in-game money only; odds are always shown.

var opening = false

func content(first: bool) -> Control:
	var S = g()
	var v = UIK.vbox(16)
	v.add_child(UIK.head("Коробки с деталями · за игровые деньги", "Коробки", [UIK.chip("Онлайн-предметы можно обменять" if Online.online else "Офлайн: предметы не идут на обмен с игроками", UIK.GOOD if Online.online else UIK.MUTE)]))
	v.add_child(UIK.note("Коробки покупаются только за игровые деньги. Шансы выпадения указаны на каждой коробке. Если игра подключена к серверу, выпавший предмет получает онлайн-номер, и его можно обменять с другими игроками на «Барахолке»."))
	var gr = UIK.grid(min(4, grid_cols() + 1))
	for b in Data.BOXES:
		var lock: bool = int(b.lvl) > int(S.level)
		var own = int(S.inv.boxes.get(b.id, 0))
		var price = round(float(b.price) * Game.city_k())
		var c = UIK.vbox(10)
		var crate = Crate.make(b.col, 120); crate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		c.add_child(crate)
		c.add_child(UIK.hbox(8, [UIK.expand(UIK.label(b.name, "H3")), UIK.chip("×%d" % own, UIK.TEAL) if own > 0 else UIK.spacer(false)]))
		c.add_child(UIK.label(b.desc, "SmallMuted", true))
		var odds = Game.box_odds(b.id)
		var ot = UIK.vbox(2)
		for r in Data.RAR_ORDER:
			ot.add_child(UIK.hbox(6, [UIK.swatch(Data.RAR_COL[r], 9), UIK.label(Data.RAR_NAME[r], "SmallMuted"), UIK.spacer(), UIK.colored("%s%%" % _pct(float(odds[r])), Data.RAR_COL[r], "Num")]))
		c.add_child(UIK.card("Card", ot))
		var buy = UIK.button(Game.rub(price), "BtnTeal", func(): if Game.buy_box(b.id): Audio.ui("buy"), "cart"); buy.disabled = lock
		var open = UIK.button("Открыть", "BtnPri", func(): _open(b), "gift"); open.disabled = own < 1 or lock
		if lock: c.add_child(UIK.chip("с %d уровня" % int(b.lvl)))
		c.add_child(UIK.hbox(6, [UIK.expand(buy), UIK.expand(open)]))
		var card = UIK.card("Card", c)
		if lock: card.modulate = Color(1, 1, 1, 0.5)
		crate.set_meta("card", card)
		gr.add_child(card)
	v.add_child(gr)
	var hist = UIK.vbox(6, [UIK.label("Что может выпасть", "H3")])
	hist.add_child(UIK.label("Свитчи: пачка на целую клавиатуру (65% или TKL). Эксклюзивы «Голограмма», «Мятный ветер» и «Вулканическое стекло» есть только в коробках. Кейкапы: от стоковых до «Золотого века». Артизаны: от обычных до легендарных.", "SmallMuted", true))
	v.add_child(UIK.card("Card", hist))
	return v

func _pct(x: float) -> String:
	var p = x * 100.0
	return ("%.1f" % p) if p < 10.0 and fmod(p, 1.0) > 0.01 else str(int(round(p)))

func _open(b: Dictionary) -> void:
	if opening: return
	opening = true
	var e: Dictionary = await Online.open_box(b.id)
	if e.is_empty(): opening = false; return
	_roulette(b, e)

func _roulette(b: Dictionary, win: Dictionary) -> void:
	var n = 46; var win_i = 40; var tile_w = 140.0; var gap = 10.0
	var strip = HBoxContainer.new(); strip.add_theme_constant_override("separation", int(gap))
	for i in n:
		var e = win if i == win_i else Game.roll_box(b.id)
		strip.add_child(ItemTile.make(e, tile_w, true))
	var clip = Control.new(); clip.clip_contents = true; clip.custom_minimum_size = Vector2(760, tile_w * 0.95 + 16)
	clip.add_child(strip); strip.position = Vector2(0, 8)
	var marker = Panel.new(); marker.add_theme_stylebox_override("panel", UIK.sb(UIK.GOLD, 2, Color(0, 0, 0, 0), 0))
	marker.size = Vector2(3, clip.custom_minimum_size.y); marker.position = Vector2(380 - 1.5, 0); clip.add_child(marker)
	var fade = ColorRect.new(); fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fsh = Shader.new(); fsh.code = "shader_type canvas_item; void fragment(){ float e = smoothstep(0.0, 0.18, UV.x) * smoothstep(1.0, 0.82, UV.x); COLOR = vec4(0.07, 0.09, 0.11, 1.0 - e); }"
	var fm = ShaderMaterial.new(); fm.shader = fsh; fade.material = fm; fade.size = clip.custom_minimum_size; clip.add_child(fade)
	var title = UIK.label("Открываем: " + b.name, "H2")
	var reveal = UIK.vbox(10); reveal.modulate.a = 0.0
	var v = UIK.vbox(16, [title, clip, reveal])
	var p = await main.open_modal(v, 800)
	if p: p.set_meta("on_close", func(): opening = false)
	var start_x = 0.0
	var target = -(win_i * (tile_w + gap)) + 380 - tile_w / 2.0 + randf_range(-tile_w * 0.35, tile_w * 0.35)
	var last_idx = [0]
	var tw = strip.create_tween()
	tw.tween_method(func(x: float):
		strip.position.x = x
		var idx = int((-x + 380) / (tile_w + gap))
		if idx != last_idx[0]: last_idx[0] = idx; Audio.ui("spin"), start_x, target, 5.2).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): _reveal(strip.get_child(win_i), reveal, win, b))

func _reveal(tile: Control, reveal: VBoxContainer, e: Dictionary, b: Dictionary) -> void:
	var col: Color = Data.RAR_COL[e.rarity]
	tile.pivot_offset = tile.size / 2.0
	var tw = tile.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(tile, "scale", Vector2(1.12, 1.12), 0.3)
	Audio.ui("rare" if e.rarity in ["epic", "legendary"] else "reveal")
	if e.rarity in ["epic", "legendary"]: main.flash(Color(col, 0.3))
	var parts = CPUParticles2D.new(); parts.amount = 60 if e.rarity != "common" else 20; parts.one_shot = true; parts.explosiveness = 0.9; parts.lifetime = 1.2
	parts.position = tile.size / 2.0; parts.spread = 180; parts.initial_velocity_min = 120; parts.initial_velocity_max = 360; parts.gravity = Vector2(0, 300)
	parts.scale_amount_min = 2; parts.scale_amount_max = 5; parts.color = col
	tile.add_child(parts); parts.emitting = true
	for c in reveal.get_children(): c.queue_free()
	var nm = UIK.colored(str(e.name), col, "H2")
	reveal.add_child(UIK.hbox(10, [UIK.chip(Data.RAR_NAME[e.rarity], col), nm]))
	var info = {"sw": "Свитчи уже на складе.", "kc": "Набор кейкапов на складе.", "art": "Артизан добавлен в коллекцию."}.get(e.kind, "")
	if str(e.get("uid", "")) != "": info += " Онлайн-номер #%s — можно обменять на «Барахолке»." % str(e.uid).left(8)
	reveal.add_child(UIK.label(info, "Muted", true))
	var own = int(g().inv.boxes.get(b.id, 0))
	var again = UIK.button("Открыть ещё (%d)" % own, "BtnTeal", func(): main.close_modal(); opening = false; await get_tree().create_timer(0.25).timeout; _open(b), "gift")
	again.disabled = own < 1
	reveal.add_child(UIK.hbox(8, [UIK.spacer(), again, UIK.button("Забрать", "BtnPri", func(): main.close_modal(), "check")]))
	reveal.create_tween().tween_property(reveal, "modulate:a", 1.0, 0.3)
	main.refit_modal()
