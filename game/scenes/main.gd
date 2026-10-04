extends Node
## Game root: 3D workshop + UI shell (top bar, nav rail, screens, modals, toasts, FX).

const TABS := [
	["workshop", "Мастерская", "wrench"], ["orders", "Заказы", "clipboard"], ["shop", "Витрина", "store"],
	["storage", "Склад", "box"], ["market", "Рынок", "cart"], ["map", "Карта города", "map"],
	["boxes", "Коробки", "gift"], ["trade", "Барахолка", "swap"], ["growth", "Развитие", "trend"],
	["events", "События", "calendar"], ["collection", "Коллекция", "trophy"],
]
const SCREENS := {
	"workshop": preload("res://scripts/ui/screens/workshop_panel.gd"),
	"orders": preload("res://scripts/ui/screens/orders.gd"),
	"shop": preload("res://scripts/ui/screens/shop.gd"),
	"storage": preload("res://scripts/ui/screens/storage.gd"),
	"market": preload("res://scripts/ui/screens/market.gd"),
	"map": preload("res://scripts/ui/screens/city_map.gd"),
	"boxes": preload("res://scripts/ui/screens/boxes.gd"),
	"trade": preload("res://scripts/ui/screens/trade.gd"),
	"growth": preload("res://scripts/ui/screens/growth.gd"),
	"events": preload("res://scripts/ui/screens/events.gd"),
	"collection": preload("res://scripts/ui/screens/collection.gd"),
}

var ws: Workshop
var atlas: LegendAtlas
var ui: Control
var top: Control
var nav: Control
var host: Control
var toasts: VBoxContainer
var modal_layer: Control
var fx_layer: Control
var screen: Control = null
var tab = "workshop"
var sub = {}                 # per-screen sub tab memory
var draft = {"mods": {}}     # workshop draft selection
var _ui_dirty = false
var _ui_t = 0.0
var _nav_btns = {}
var _nav_ind: Panel
var _money_l: Label
var _money_shown = 0.0
var _lvl_l: Label
var _xp_bar: ProgressBar
var _rep_l: Label
var _day_l: Label
var _day_bar: ProgressBar
var _online_dot: Panel
var _snd_btn: Button
var _modal: Control = null
# keyboard sound context
var kb_ctx = {}              # {P, L, map, fgap}
var _phys_down = {}

func _ready() -> void:
	get_window().title = "Keyboard Seller Simulator"
	get_window().min_size = Vector2i(1280, 720)
	UIK.build_theme()
	atlas = LegendAtlas.new(); add_child(atlas); atlas.build()
	var off: Dictionary = Game.boot()
	_auto_quality()
	ws = Workshop.new(); add_child(ws)
	ws.key_down.connect(func(i): _key(i, true))
	ws.key_up.connect(func(i): _key(i, false))
	ws.asm.step_changed.connect(func(): mark_ui(true))
	_build_ui()
	Game.changed.connect(func(): _ui_dirty = true)
	Game.notify.connect(toast)
	Game.level_up.connect(_on_level_up)
	Game.money_changed.connect(_on_money)
	Game.item_won.connect(func(e): pass)
	Online.status_changed.connect(func(_v): _refresh_top())
	_money_shown = float(Game.S.money)
	_refresh_top()
	Online.start()
	Audio.apply_settings()
	if not OS.has_environment("KSS_NOTITLE"):
		await _title()
	open_tab("workshop", false)
	_show_shell()
	if not Game.S.seenIntro:
		await get_tree().create_timer(0.6).timeout
		Intro.open(self)
	elif not off.is_empty() and (off.sold.size() > 0 or float(off.repair) > 0 or off.gb.size() > 0):
		await get_tree().create_timer(0.8).timeout
		_offline_modal(off)

## First launch: pick graphics quality from the GPU (integrated GPUs get "mid").
func _auto_quality() -> void:
	if Game.S.settings.get("gfx_auto", false): return
	Game.S.settings.gfx_auto = true
	var gpu = RenderingServer.get_video_adapter_name().to_lower()
	var weak = ["intel", "uhd", "iris", "vega", "radeon(tm) graphics", "llvmpipe", "swiftshader", "adreno", "mali"]
	for w in weak:
		if w in gpu: Game.S.settings.gfx = "low" if w in ["llvmpipe", "swiftshader"] else "mid"
	Game.mark()

# ------------------------------------------------------------------ title
func _title() -> void:
	top.visible = false; nav.visible = false
	ws.frame_offset = -0.5; ws.idle_spin = true; ws.mode = "view"
	var fs = {"layout": "l65", "case": "c_gasket", "color": 0, "plate": "p_brass", "pcb": "b_rgb", "stab": "s_screw", "kc": "k_holo", "sw": "sw_holo", "art": "a_moon", "mods": {}}
	if Game.S.boards.size() > 0: fs = Game.S.boards[-1]
	ws.kb.show_spec(fs, null); ws.kb.reveal(); ws.fit_keyboard(); ws.set_view("hero")
	ws.orb_goal.theta = -0.9
	var t = TitleScreen.new(); t.main = self
	ui.add_child(t); ui.move_child(t, modal_layer.get_index())
	await t.play

func _show_shell() -> void:
	for c in [top, nav]:
		c.visible = true; c.modulate.a = 0.0
		c.create_tween().tween_property(c, "modulate:a", 1.0, 0.4)
	nav.position.x -= 40; nav.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).tween_property(nav, "position:x", nav.position.x + 40, 0.5)

# ------------------------------------------------------------------ shell
func _build_ui() -> void:
	var layer = CanvasLayer.new(); layer.layer = 5; add_child(layer)
	ui = Control.new(); ui.theme = UIK.theme; ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	# vignette
	var vg = ColorRect.new(); vg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); vg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vsh = Shader.new(); vsh.code = "shader_type canvas_item; void fragment(){ vec2 p = UV - 0.5; float v = smoothstep(0.35, 0.95, length(p * vec2(1.0, 0.8))); COLOR = vec4(0.0, 0.0, 0.0, v * 0.55); }"
	var vm = ShaderMaterial.new(); vm.shader = vsh; vg.material = vm; ui.add_child(vg)
	host = Control.new(); host.mouse_filter = Control.MOUSE_FILTER_IGNORE; ui.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); host.offset_left = 236; host.offset_top = 84; host.offset_right = -16; host.offset_bottom = -16
	_build_top(); _build_nav()
	toasts = VBoxContainer.new(); toasts.add_theme_constant_override("separation", 8); toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toasts.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT); toasts.offset_left = -420; toasts.offset_right = -20; toasts.offset_top = 92; toasts.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	ui.add_child(toasts)
	modal_layer = Control.new(); modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE; ui.add_child(modal_layer)
	fx_layer = Control.new(); fx_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE; ui.add_child(fx_layer)

func _build_top() -> void:
	top = UIK.glass(16); top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE); top.offset_left = 16; top.offset_right = -16; top.offset_top = 14; top.offset_bottom = 72
	(top.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_top = 8; (top.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_bottom = 8
	var h = UIK.hbox(22); top.add_child(h)
	# brand
	var logo = UIK.icon_rect("keyboard", 26, UIK.TEAL)
	var name_l = UIK.label(str(Game.S.shop), "H3"); name_l.name = "shop"
	_day_l = UIK.label("", "SmallMuted")
	_day_bar = UIK.bar(0, UIK.TEAL, 3); _day_bar.custom_minimum_size.x = 150
	h.add_child(UIK.hbox(10, [logo, UIK.vbox(1, [name_l, _day_l, _day_bar])]))
	h.add_child(UIK.spacer())
	# money
	_money_l = UIK.label("", "Price"); _money_l.add_theme_font_size_override("font_size", 22)
	h.add_child(UIK.hbox(8, [UIK.icon_rect("coin", 22, UIK.GOLD), _money_l]))
	# level
	_lvl_l = UIK.label("", "Small"); _xp_bar = UIK.bar(0, UIK.VIOLET, 5); _xp_bar.custom_minimum_size.x = 150
	h.add_child(UIK.vbox(3, [_lvl_l, _xp_bar]))
	# reputation
	_rep_l = UIK.label("", "H3"); _rep_l.add_theme_color_override("font_color", UIK.GOLD)
	h.add_child(UIK.hbox(6, [UIK.icon_rect("star", 18, UIK.GOLD), _rep_l]))
	# online
	_online_dot = UIK.swatch(UIK.MUTE, 10); _online_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ol = UIK.label("офлайн", "SmallMuted"); ol.name = "onl"
	var onl = UIK.hbox(6, [_online_dot, ol]); onl.tooltip_text = "Онлайн-сервер: барахолка, коробки и рейтинг"; onl.mouse_filter = Control.MOUSE_FILTER_PASS
	h.add_child(onl)
	var b_help = _icon_btn("help", "Как играть", func(): Intro.open(self))
	_snd_btn = _icon_btn("sound", "Звук", func():
		Game.S.settings.sound = not Game.S.settings.sound; Audio.apply_settings(); Game.mark(); _refresh_top())
	var b_set = _icon_btn("gear", "Настройки", func(): Settings.open(self))
	h.add_child(UIK.hbox(6, [b_help, _snd_btn, b_set]))
	ui.add_child(top)
	top.set_meta("name_l", name_l); top.set_meta("onl_l", ol)

func _icon_btn(ico: String, tip: String, cb: Callable) -> Button:
	var b = UIK.button("", "BtnGhost", cb, ico); b.tooltip_text = tip; b.custom_minimum_size = Vector2(40, 40)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return b

func _build_nav() -> void:
	nav = UIK.glass(16); nav.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE); nav.offset_left = 16; nav.offset_right = 220; nav.offset_top = 84; nav.offset_bottom = -16
	var v = UIK.vbox(3); nav.add_child(v)
	var ind_host = Control.new(); ind_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nav_ind = Panel.new(); _nav_ind.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nav_ind.add_theme_stylebox_override("panel", UIK.sb(Color(0.3, 0.72, 0.67, 0.16), 10, Color(0.3, 0.72, 0.67, 0.35), 0))
	nav.add_child(ind_host); ind_host.add_child(_nav_ind); nav.move_child(ind_host, 1)
	for t in TABS:
		var b = UIK.button("  " + t[1], "Tab", func(): open_tab(t[0]), t[2])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT; b.toggle_mode = true; b.custom_minimum_size.y = 42
		var badge = UIK.chip("", UIK.CORAL); badge.name = "badge"; badge.visible = false
		badge.anchor_left = 1; badge.anchor_right = 1; badge.anchor_top = 0.5; badge.anchor_bottom = 0.5
		badge.offset_left = -38; badge.offset_right = -8; badge.offset_top = -11; badge.offset_bottom = 11
		badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		b.add_child(badge)
		v.add_child(b); _nav_btns[t[0]] = b
	v.add_child(UIK.spacer(false)); UIK.expand(v.get_child(v.get_child_count() - 1), false, true)
	var hint = UIK.label("F11 — полный экран", "SmallMuted"); hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	ui.add_child(nav)

func _move_indicator(anim := true) -> void:
	var b: Button = _nav_btns.get(tab)
	if b == null or _nav_ind == null: return
	await get_tree().process_frame
	var r = Rect2(b.global_position - _nav_ind.get_parent().global_position, b.size)
	if anim:
		var tw = _nav_ind.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_nav_ind, "position", r.position, 0.35); tw.tween_property(_nav_ind, "size", r.size, 0.35)
	else:
		_nav_ind.position = r.position; _nav_ind.size = r.size

func _refresh_top() -> void:
	if top == null: return
	var S: Dictionary = Game.S
	(top.get_meta("name_l") as Label).text = str(S.shop)
	_day_l.text = "%s · день %d" % [Data.CITIES[int(S.prestige.city)], int(S.day)]
	var need = Game.xp_need()
	_lvl_l.text = "Уровень %d · %s / %s XP" % [int(S.level), Game.fmt(S.xp), Game.fmt(need)]
	_xp_bar.value = float(S.xp) / need
	_rep_l.text = "%.1f" % float(S.rep)
	_online_dot.add_theme_stylebox_override("panel", UIK.sb(UIK.GOOD if Online.online else UIK.MUTE, 5, Color(0, 0, 0, 0), 0))
	(top.get_meta("onl_l") as Label).text = "онлайн" if Online.online else "офлайн"
	_snd_btn.icon = UIK.icon("sound" if S.settings.sound else "mute", 36, Color.WHITE)
	var badges = {"orders": S.orders.size(), "events": _events_badge(), "growth": int(S.sp), "boxes": _box_count(), "workshop": "…" if S.build else 0, "trade": Online.offers.size() if Online.online else 0}
	for k in _nav_btns:
		var bd: PanelContainer = _nav_btns[k].get_node("badge")
		var v = badges.get(k, 0)
		bd.visible = (v is String) or int(v) > 0
		(bd.get_child(0) as Label).text = str(v)
		_nav_btns[k].button_pressed = k == tab
	if not _money_l.has_meta("tick_tw") or not (_money_l.get_meta("tick_tw") as Tween).is_running():
		_money_l.text = Game.rub(S.money)

func _events_badge() -> int:
	var S: Dictionary = Game.S; var n = 0
	if S.login.claimed != Game.today_str(): n += 1
	for t in S.daily.tasks:
		if not t.get("claimed", false) and Game.task_prog(t) >= float(t.n): n += 1
	if S.weekly.result and not S.weekly.result.get("claimed", false): n += 1
	return n
func _box_count() -> int:
	var n = 0
	for k in Game.S.inv.boxes: n += int(Game.S.inv.boxes[k])
	return n

func _on_money(_delta: float) -> void:
	var v = float(Game.S.money)
	var from = _money_shown; _money_shown = v
	UIK.ticker(_money_l, from, v, func(x): return Game.rub(round(x)), 0.9)
	UIK.pop(_money_l, 1.08 if v >= from else 0.96)
	if v > from + 1.0: _coin_burst(v - from)

# ---------------------------------------------------------------- screens
func open_tab(id: String, anim := true) -> void:
	if _modal: close_modal()
	var same = id == tab and screen != null
	tab = id
	var old = screen
	screen = SCREENS[id].new()
	screen.main = self
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(screen)
	screen.build_screen(true)
	# camera choreography
	var lay: String = screen.layout()
	ws.mode = "view"
	if lay == "side":
		ws.frame_offset = 0.62
		ws.set_view(screen.cam_view())
	else:
		ws.frame_offset = 0.0; ws.set_view("room")
	if old:
		var tw = old.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_property(old, "modulate:a", 0.0, 0.16); tw.tween_property(old, "position:x", old.position.x - 30, 0.16)
		tw.chain().tween_callback(old.queue_free)
	if anim and not same:
		screen.modulate.a = 0.0; screen.position.x = 40
		var tw2 = screen.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw2.tween_property(screen, "modulate:a", 1.0, 0.32).set_delay(0.08); tw2.tween_property(screen, "position:x", 0.0, 0.42).set_delay(0.08)
		Audio.ui("whoosh")
	_refresh_top(); _move_indicator(anim)

func mark_ui(force := false) -> void:
	_ui_dirty = true
	if force: _ui_t = 1.0

func _process(delta: float) -> void:
	_ui_t += delta
	if _day_bar: _day_bar.value = float(Game.S.dayT) / Data.DAY_SEC
	if _ui_dirty and _ui_t > 0.3:
		_ui_t = 0.0; _ui_dirty = false
		_refresh_top()
		if screen and screen.can_refresh(): screen.build_screen(false)
		if _modal and _modal.has_method("refresh"): _modal.refresh()

# ----------------------------------------------------------------- input
func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey:
		var k = ev as InputEventKey
		if k.pressed and not k.echo and k.keycode == KEY_F11:
			var w = get_window()
			w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN or w.mode == Window.MODE_EXCLUSIVE_FULLSCREEN else Window.MODE_FULLSCREEN
			return
		if k.pressed and not k.echo and k.keycode == KEY_ESCAPE and _modal:
			close_modal(); return
		if k.pressed and not k.echo and k.keycode == KEY_R and tab == "workshop" and Game.S.build and ws.asm.step() == "case":
			ws.asm.rotate_piece(); return
		_phys_key(k)
		return
	if _modal: return
	if ev is InputEventMouse and screen == null:
		if ws.handle_input(ev): get_viewport().set_input_as_handled()
	elif ev is InputEventMouse and screen and screen.layout() == "side":
		if ws.handle_input(ev): get_viewport().set_input_as_handled()
	elif ev is InputEventMouse and screen and screen.has_method("handle_3d"):
		screen.handle_3d(ev)

func _phys_key(k: InputEventKey) -> void:
	if kb_ctx.is_empty() or k.echo: return
	var focus = get_viewport().gui_get_focus_owner()
	var typing = focus is LineEdit
	if typing and not (focus as LineEdit).has_meta("typebox"): return
	var code = KeyCodes.code_of(k)
	var i: int = kb_ctx.map.get(code, -1)
	if i < 0: return
	var tgt = kb_ctx.get("kb")
	if k.pressed:
		if _phys_down.has(i): return
		_phys_down[i] = true
		if tgt == null: ws.press_key(i, true)
		else: tgt.press(i, true); _key(i, true)
	else:
		_phys_down.erase(i)
		if tgt == null: ws.press_key(i, false)
		else: tgt.press(i, false); _key(i, false)
	if not typing: get_viewport().set_input_as_handled()

## Sets the board whose sound is played when keys are pressed.
func set_kb_sound(spec: Dictionary, target: Keyboard3D = null) -> void:
	if spec.is_empty(): kb_ctx = {}; return
	var P: Dictionary = Game.board_stats(spec).P
	var L: Dictionary = Data.LAYOUTS[spec.layout]
	var map = {}
	for i in L.keys.size():
		for c in L.keys[i].codes:
			if not map.has(c): map[c] = i
	kb_ctx = {"P": P, "L": L, "map": map, "kb": target}
	Audio.load_set(str(P.get("snd", "")))
	Audio.set_profile(P)

func _key(i: int, down: bool) -> void:
	if kb_ctx.is_empty(): return
	var k: Dictionary = kb_ctx.L.keys[i]
	var play = true
	var P: Dictionary = kb_ctx.P
	var fg := bool(kb_ctx.L.get("fgap", false))
	if down and Game.S.build and tab == "workshop" and ws.asm.step() == "keytest":
		play = ws.asm.keytest(i)
	elif Game.S.build and tab == "workshop" and ws.asm.step() == "diag":
		# each fault sounds like the real thing: silence, double hit, late release, rattle
		var f: String = ws.asm.diag(i) if down else str(Game.S.build.ks[i].get("f", ""))
		match f:
			"dead": play = false; if down: Audio.ui("tick")
			"joint": play = randf() < 0.4
			"chatter":
				if down: get_tree().create_timer(0.045).timeout.connect(func(): Audio.key(P, k, false, fg))
			"sticky":
				if not down:
					play = false
					get_tree().create_timer(0.38).timeout.connect(func(): Audio.key(P, k, true, fg))
			"stab": P = P.duplicate(); P.rattle = 0.95
	if play: Audio.key(P, k, not down, fg)
	if down:
		Game.S.stats.keys = int(Game.S.stats.keys) + 1; Game.track("keys", 1)
		if Game.S.build: Game.S.build.keys = int(Game.S.build.keys) + 1
		if screen and screen.has_method("on_key"): screen.on_key(i)

# ----------------------------------------------------------------- toasts
func toast(text: String, kind := "") -> void:
	var col: Color = {"bad": UIK.BAD, "gold": UIK.GOLD, "vio": UIK.VIOLET, "good": UIK.GOOD}.get(kind, UIK.TEAL)
	var p = UIK.glass(12, Color(0.06, 0.08, 0.1, 0.9))
	var h = UIK.hbox(10)
	var acc = Panel.new(); acc.custom_minimum_size = Vector2(4, 0); acc.add_theme_stylebox_override("panel", UIK.sb(col, 2, Color(0, 0, 0, 0), 0))
	var l = UIK.rich(text, 14); l.custom_minimum_size.x = 320; UIK.expand(l)
	h.add_child(acc); h.add_child(l); p.add_child(h)
	(p.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_top = 10; (p.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_bottom = 10
	toasts.add_child(p)
	while toasts.get_child_count() > 5:
		var old = toasts.get_child(0); toasts.remove_child(old); old.queue_free()
	p.modulate.a = 0.0; p.pivot_offset = Vector2(400, 0); p.scale = Vector2(0.9, 0.9)
	var tw = p.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(p, "modulate:a", 1.0, 0.25); tw.tween_property(p, "scale", Vector2.ONE, 0.35)
	tw.chain().tween_interval(3.6 if kind != "gold" else 5.0)
	tw.chain().tween_property(p, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(p.queue_free)

# ----------------------------------------------------------------- modals
func open_modal(content: Control, width := 640.0) -> PanelContainer:
	close_modal(true)
	var dim = ColorRect.new(); dim.color = Color(0, 0, 0, 0.0); dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); dim.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_layer.add_child(dim)
	dim.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT: close_modal())
	var p = UIK.glass(20, Color(0.07, 0.09, 0.11, 0.94))
	p.custom_minimum_size.x = width
	var sc = ScrollContainer.new(); sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(content); p.add_child(sc)
	var center = CenterContainer.new(); center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_layer.add_child(center); center.add_child(p)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal = p; p.set_meta("dim", dim); p.set_meta("center", center); p.set_meta("scroll", sc)
	# size the scroll area to content up to 82% of the screen
	await get_tree().process_frame
	if not is_instance_valid(sc): return p
	var maxh = get_viewport().get_visible_rect().size.y * 0.84
	sc.custom_minimum_size.y = min(maxh, content.get_combined_minimum_size().y + 4)
	p.pivot_offset = p.size / 2.0; p.scale = Vector2(0.92, 0.92); p.modulate.a = 0.0
	var tw = p.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(p, "scale", Vector2.ONE, 0.32); tw.tween_property(p, "modulate:a", 1.0, 0.2)
	dim.create_tween().tween_property(dim, "color:a", 0.5, 0.25)
	Audio.ui("open")
	return p

func refit_modal() -> void:
	if _modal == null: return
	var sc: ScrollContainer = _modal.get_meta("scroll")
	await get_tree().process_frame
	if is_instance_valid(sc) and sc.get_child_count() > 0:
		sc.custom_minimum_size.y = min(get_viewport().get_visible_rect().size.y * 0.84, (sc.get_child(0) as Control).get_combined_minimum_size().y + 4)

func close_modal(instant := false) -> void:
	if _modal == null: return
	var p = _modal; _modal = null
	var dim: ColorRect = p.get_meta("dim"); var center: Control = p.get_meta("center")
	if p.has_meta("on_close"): (p.get_meta("on_close") as Callable).call()
	if instant:
		dim.queue_free(); center.queue_free(); return
	var tw = p.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(p, "scale", Vector2(0.95, 0.95), 0.15); tw.tween_property(p, "modulate:a", 0.0, 0.15)
	dim.create_tween().tween_property(dim, "color:a", 0.0, 0.18)
	tw.chain().tween_callback(func(): dim.queue_free(); center.queue_free())

func modal_open() -> bool: return _modal != null

## Standard modal header with title and close button.
func modal_head(title: String, eyebrow := "") -> HBoxContainer:
	var v = UIK.vbox(2)
	if eyebrow != "": v.add_child(UIK.label(eyebrow.to_upper(), "Eyebrow"))
	v.add_child(UIK.label(title, "H2"))
	var x = UIK.button("", "BtnGhost", close_modal, "x"); x.custom_minimum_size = Vector2(38, 38)
	return UIK.hbox(10, [UIK.expand(v), x])

func confirm(title: String, text: String, yes: String, cb: Callable) -> void:
	var v = UIK.vbox(14, [modal_head(title), UIK.rich(text)])
	var row = UIK.hbox(10, [UIK.spacer(), UIK.button("Отмена", "BtnGhost", close_modal), UIK.button(yes, "BtnPri", func(): close_modal(); cb.call())])
	v.add_child(row)
	open_modal(v, 520)

func _offline_modal(off: Dictionary) -> void:
	var total = float(off.repair)
	for s in off.sold: total += float(s.amt)
	var v = UIK.vbox(12, [modal_head("Пока вас не было", "Офлайн-доход"),
		UIK.rich("Прошло [b]%s[/b]. Витрина и ремонтная стойка работали без вас." % Game.dur(float(off.away))),
		UIK.label(Game.rub(total), "Big")])
	for s in off.sold: v.add_child(UIK.label("Продано: %s — %s" % [s.name, Game.rub(s.amt)], "Muted"))
	if float(off.repair) > 0: v.add_child(UIK.label("Ремонтная стойка: " + Game.rub(off.repair), "Muted"))
	for g in off.gb: v.add_child(UIK.label("Пришла посылка group buy: " + str(g), "Muted"))
	v.add_child(UIK.hbox(10, [UIK.spacer(), UIK.button("Отлично", "BtnPri", close_modal)]))
	open_modal(v, 460)
	(v.get_child(2) as Label).add_theme_color_override("font_color", UIK.GOLD)

# --------------------------------------------------------------------- FX
func _on_level_up(level: int, unlocked: Array) -> void:
	Audio.ui("level")
	var c = Control.new(); c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.add_child(c)
	var glow = ColorRect.new(); glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gs = Shader.new(); gs.code = "shader_type canvas_item; uniform float t = 0.0; void fragment(){ vec2 p = UV - 0.5; p.x *= 1.7; float r = length(p); float ring = smoothstep(0.02, 0.0, abs(r - t * 0.9)) * (1.0 - t); float g = smoothstep(0.6, 0.0, r) * 0.35 * (1.0 - t); COLOR = vec4(vec3(0.66, 0.55, 0.94) * (ring * 2.0 + g), ring + g); }"
	var gm = ShaderMaterial.new(); gm.shader = gs; glow.material = gm; c.add_child(glow)
	var v = UIK.vbox(4); v.alignment = BoxContainer.ALIGNMENT_CENTER
	var a = UIK.label("НОВЫЙ УРОВЕНЬ", "Eyebrow"); a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; a.add_theme_font_size_override("font_size", 16)
	var n = UIK.label(str(level), "Big"); n.add_theme_font_size_override("font_size", 120); n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.add_theme_color_override("font_color", UIK.VIOLET.lightened(0.3))
	v.add_child(a); v.add_child(n)
	if unlocked.size() > 0:
		var u = UIK.label("Открыто: " + ", ".join(unlocked.slice(0, 4)), "Muted"); u.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(u)
	var cc = CenterContainer.new(); cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); cc.mouse_filter = Control.MOUSE_FILTER_IGNORE; cc.add_child(v); c.add_child(cc)
	var parts = CPUParticles2D.new(); parts.amount = 120; parts.one_shot = true; parts.explosiveness = 0.95; parts.lifetime = 1.6
	parts.position = get_viewport().get_visible_rect().size / 2.0; parts.spread = 180; parts.initial_velocity_min = 200; parts.initial_velocity_max = 620
	parts.gravity = Vector2(0, 500); parts.scale_amount_min = 3; parts.scale_amount_max = 7
	var grad = Gradient.new(); grad.set_color(0, UIK.GOLD); grad.add_point(0.5, UIK.VIOLET); grad.set_color(grad.get_point_count() - 1, Color(UIK.TEAL, 0)); parts.color_ramp = grad
	c.add_child(parts); parts.emitting = true
	v.pivot_offset = get_viewport().get_visible_rect().size / 2.0
	v.scale = Vector2(0.4, 0.4); v.modulate.a = 0.0
	var tw = c.create_tween().set_parallel(true)
	tw.tween_property(v, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(v, "modulate:a", 1.0, 0.25)
	tw.tween_method(func(x): gm.set_shader_parameter("t", x), 0.0, 1.0, 1.4)
	tw.chain().tween_interval(1.4)
	tw.chain().tween_property(c, "modulate:a", 0.0, 0.5)
	tw.chain().tween_callback(c.queue_free)
	_refresh_top()

func _coin_burst(amount: float) -> void:
	var n = clampi(int(log(amount + 1.0) * 1.5), 3, 14)
	var target = _money_l.global_position + Vector2(10, 12)
	var src = get_viewport().get_visible_rect().size * Vector2(0.55, 0.55)
	for i in n:
		var coin = TextureRect.new(); coin.texture = UIK.icon("coin", 40, UIK.GOLD); coin.size = Vector2(22, 22); coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fx_layer.add_child(coin)
		var start = src + Vector2(randf_range(-120, 120), randf_range(-60, 60))
		coin.position = start; coin.modulate.a = 0.0
		var mid = start.lerp(target, 0.5) + Vector2(randf_range(-80, 80), -160)
		var tw = coin.create_tween()
		tw.tween_interval(i * 0.04)
		tw.tween_property(coin, "modulate:a", 1.0, 0.1)
		tw.tween_method(func(t: float): coin.position = start.lerp(mid, t).lerp(mid.lerp(target, t), t), 0.0, 1.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_callback(func(): Audio.ui("rtick"); coin.queue_free())

func flash(col := Color(1, 1, 1, 0.25)) -> void:
	var r = ColorRect.new(); r.color = col; r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.add_child(r)
	var tw = r.create_tween(); tw.tween_property(r, "color:a", 0.0, 0.5); tw.tween_callback(r.queue_free)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Game.save_game()
