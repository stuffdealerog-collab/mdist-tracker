extends Node
## Game root. The player lives in a first-person flat (Home): wakes up in bed, orders parts on the PC
## or phone, picks up parcels at the door, unboxes them on the workbench, stores parts on the shelf,
## builds and repairs at the bench, packs keyboards on the packing table and leaves them for the courier.
## Modes: walk | bench | pc | unbox | pack | intro. The phone (Tab) overlays walk and bench.

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
	"deliveries": preload("res://scripts/ui/screens/deliveries.gd"),
}

var ws: Workshop
var home: Home
var player: Player
var os: PcOS
var phone: Phone
var atlas: LegendAtlas
var ui: Control
var host: Control
var hud: Control
var toasts: VBoxContainer
var modal_layer: Control
var fx_layer: Control
var screen: Control = null
var _host_screen: Control = null   # the bench panel (screen points at the phone / PC app while they are open)
var mode = "intro"
var tab = "workshop"
var sub = {}                 # per-screen sub tab memory
var draft = {"mods": {}}     # workshop draft selection
var unbox: Unbox = null
var pack: Pack = null
var carry = {}              # {kind: "parcel", id, node} | {kind: "crate", uids, node}
var _ui_dirty = false
var _ui_t = 0.0
var _modal: Control = null
var _money_l: Label
var _money_shown = 0.0
var _clock_l: Label
var _lvl_l: Label
var _xp_bar: ProgressBar
var _rep_l: Label
var _prompt_l: Label
var _cross: Control
var _hint_box: PanelContainer
var _hint_l: Label
var _hint_bar: ProgressBar
var _keys_l: Label
var _stand_btn: Button
var _black: ColorRect
var _intro_cam: Camera3D
# keyboard sound context
var kb_ctx = {}              # {P, L, map, kb}
var _phys_down = {}

func _ready() -> void:
	get_window().title = "Keyboard Seller Simulator"
	get_window().min_size = Vector2i(1280, 720)
	UIK.build_theme()
	atlas = LegendAtlas.new(); add_child(atlas); atlas.build()
	var off: Dictionary = Game.boot()
	_auto_quality()
	ws = Workshop.new(); add_child(ws)
	home = ws.home
	ws.key_down.connect(func(i): _key(i, true))
	ws.key_up.connect(func(i): _key(i, false))
	ws.asm.step_changed.connect(func(): mark_ui(true))
	player = Player.new(); add_child(player)
	player.prompt_fn = prompt_for
	player.interact.connect(_interact)
	player.alt_interact.connect(_alt_interact)
	player.prompt_changed.connect(func(t): _prompt_l.text = t; _prompt_l.visible = t != "")
	player.position = Home.WAKE_POS
	_build_ui()
	os = PcOS.new(self); home.monitor_vp.add_child(os)
	phone = Phone.new(self); ui.add_child(phone); ui.move_child(phone, modal_layer.get_index())
	Game.changed.connect(func(): _ui_dirty = true)
	Game.notify.connect(toast)
	Game.level_up.connect(_on_level_up)
	Game.money_changed.connect(_on_money)
	Game.passed_out.connect(func(): _sleep(true))
	_money_shown = float(Game.S.money)
	_restore_carry()
	Online.start()
	Audio.apply_settings()
	if not OS.has_environment("KSS_NOTITLE"):
		await _title()
	if OS.has_environment("KSS_NOWAKE") or Game.S.home.get("woke", false):
		enter_walk()
		player.look_at_point(Vector3(0, 0, -0.2))
	else:
		await wake_up()
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

# ------------------------------------------------------------------ title / wake / sleep
func _title() -> void:
	hud.visible = false
	ws.cam.current = true
	ws.frame_offset = -0.5; ws.idle_spin = true; ws.mode = "view"
	var fs = {"layout": "l65", "case": "c_gasket", "color": 0, "plate": "p_brass", "pcb": "b_rgb", "stab": "s_screw", "kc": "k_holo", "sw": "sw_holo", "art": "a_moon", "mods": {}}
	if Game.S.boards.size() > 0: fs = Game.S.boards[-1]
	ws.kb.visible = true; ws.kb.show_spec(fs, null); ws.kb.reveal(); ws.fit_keyboard(); ws.set_view("hero")
	ws.orb_goal.theta = -0.9
	var t = TitleScreen.new(); t.main = self
	ui.add_child(t); ui.move_child(t, modal_layer.get_index())
	await t.play
	ws.idle_spin = false; ws.frame_offset = 0.0

## Morning: alarm, blink twice, sit up, stand next to the bed.
func wake_up() -> void:
	mode = "intro"; hud.visible = false; player.active = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_sync_kb_idle()
	_intro_cam = Camera3D.new(); _intro_cam.fov = 70; add_child(_intro_cam)
	_intro_cam.position = Home.BED_EYE
	_intro_cam.look_at(Home.BED_EYE + Home.WAKE_LOOK_A)
	_intro_cam.current = true
	_black.color.a = 1.0
	home.set_time(Game.clock_min())
	Audio.sfx("alarm", Home.ALARM_POS)
	await get_tree().create_timer(0.9).timeout
	for i in 2:
		var tw = _black.create_tween(); tw.tween_property(_black, "color:a", 0.15, 0.5); tw.tween_property(_black, "color:a", 0.9, 0.22)
		await tw.finished
	Audio.sfx("bed", null)
	var tw2 = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw2.tween_property(_black, "color:a", 0.0, 0.8)
	var sit = Home.BED_EYE + Home.WAKE_SIT
	tw2.tween_property(_intro_cam, "position", sit, 2.0)
	var tw3 = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw3.tween_method(func(t: float): _intro_cam.look_at(_intro_cam.position + Home.WAKE_LOOK_A.lerp(Home.WAKE_LOOK_B, t)), 0.0, 1.0, 2.0)
	await tw3.finished
	Audio.sfx("phone_vib", null, -6.0)
	var tw4 = _black.create_tween(); tw4.tween_property(_black, "color:a", 1.0, 0.25)
	await tw4.finished
	player.position = Home.WAKE_POS; player.velocity = Vector3.ZERO
	player.look_at_point(Vector3(0.0, -0.1, -0.2))
	_intro_cam.queue_free(); _intro_cam = null
	Game.S.home.woke = true; Game.mark()
	enter_walk()
	_black.create_tween().tween_property(_black, "color:a", 0.0, 0.5)
	await get_tree().create_timer(0.4).timeout
	var at_door = Game.S.parcels.filter(func(p): return p.place == "door").size()
	toast("Доброе утро! %s%s" % [Game.clock_str(), (" · у двери ждёт посылок: %d" % at_door) if at_door > 0 else ""], "gold")

func _sleep(forced := false) -> void:
	if mode == "intro": return
	if not forced and not Game.sleep(): return
	_leave_current()
	mode = "intro"; player.active = false; hud.visible = false
	var tw = _black.create_tween(); tw.tween_property(_black, "color:a", 1.0, 0.8)
	await tw.finished
	Audio.sfx("bed", null)
	if forced:
		Game.S.home.woke = false
		toast("Вы уснули прямо в одежде. Утро вечера мудренее.")
	home.set_time(Game.clock_min())
	await get_tree().create_timer(1.2).timeout
	await wake_up()

# ------------------------------------------------------------------ UI
func _build_ui() -> void:
	var layer = CanvasLayer.new(); layer.layer = 5; add_child(layer)
	ui = Control.new(); ui.theme = UIK.theme; ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	var vg = ColorRect.new(); vg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); vg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vsh = Shader.new(); vsh.code = "shader_type canvas_item; void fragment(){ vec2 p = UV - 0.5; float v = smoothstep(0.4, 1.0, length(p * vec2(1.0, 0.8))); COLOR = vec4(0.0, 0.0, 0.0, v * 0.45); }"
	var vm = ShaderMaterial.new(); vm.shader = vsh; vg.material = vm; ui.add_child(vg)
	host = Control.new(); host.mouse_filter = Control.MOUSE_FILTER_IGNORE; ui.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); host.offset_left = 16; host.offset_top = 84; host.offset_right = -16; host.offset_bottom = -16
	_build_hud()
	toasts = VBoxContainer.new(); toasts.add_theme_constant_override("separation", 8); toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toasts.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT); toasts.offset_left = -420; toasts.offset_right = -20; toasts.offset_top = 20; toasts.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ui.add_child(toasts)
	modal_layer = Control.new(); modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE; ui.add_child(modal_layer)
	fx_layer = Control.new(); fx_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE; ui.add_child(fx_layer)
	_black = ColorRect.new(); _black.color = Color(0, 0, 0, 0); _black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); _black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_black)

func _build_hud() -> void:
	hud = Control.new(); hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); hud.mouse_filter = Control.MOUSE_FILTER_IGNORE; ui.add_child(hud)
	# status: clock, money, level, reputation
	var st = UIK.glass(14); st.position = Vector2(16, 14); st.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h = UIK.hbox(18); st.add_child(h)
	_clock_l = UIK.label("", "H3")
	_money_l = UIK.label("", "Price"); _money_l.add_theme_font_size_override("font_size", 20)
	_lvl_l = UIK.label("", "SmallMuted"); _xp_bar = UIK.bar(0, UIK.VIOLET, 4); _xp_bar.custom_minimum_size.x = 120
	_rep_l = UIK.label("", "H3"); _rep_l.add_theme_color_override("font_color", UIK.GOLD)
	h.add_child(UIK.hbox(6, [UIK.icon_rect("calendar", 18, UIK.TEAL), _clock_l]))
	h.add_child(UIK.hbox(6, [UIK.icon_rect("coin", 20, UIK.GOLD), _money_l]))
	h.add_child(UIK.vbox(2, [_lvl_l, _xp_bar]))
	h.add_child(UIK.hbox(4, [UIK.icon_rect("star", 16, UIK.GOLD), _rep_l]))
	hud.add_child(st)
	# crosshair and prompt
	_cross = Control.new(); _cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER); _cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cross.draw.connect(func(): _cross.draw_circle(Vector2.ZERO, 3.0, Color(1, 1, 1, 0.85)); _cross.draw_arc(Vector2.ZERO, 6.0, 0, TAU, 24, Color(0, 0, 0, 0.35), 1.5))
	hud.add_child(_cross)
	_prompt_l = UIK.label("", "H3"); _prompt_l.set_anchors_and_offsets_preset(Control.PRESET_CENTER); _prompt_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_l.offset_left = -400; _prompt_l.offset_right = 400; _prompt_l.offset_top = 34; _prompt_l.offset_bottom = 70
	_prompt_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8)); _prompt_l.add_theme_constant_override("outline_size", 6)
	_prompt_l.mouse_filter = Control.MOUSE_FILTER_IGNORE; hud.add_child(_prompt_l)
	# instruction box for unboxing / packing
	_hint_box = UIK.glass(14); _hint_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP); _hint_box.offset_left = -330; _hint_box.offset_right = 330
	_hint_box.offset_top = 18; _hint_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_l = UIK.label("", "H3", true); _hint_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_bar = UIK.bar(0, UIK.TEAL, 5)
	_hint_box.add_child(UIK.vbox(8, [_hint_l, _hint_bar])); _hint_box.visible = false; hud.add_child(_hint_box)
	_keys_l = UIK.label("", "SmallMuted"); _keys_l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT); _keys_l.offset_left = 20; _keys_l.offset_top = -40; _keys_l.offset_bottom = -14
	_keys_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7)); _keys_l.add_theme_constant_override("outline_size", 4)
	hud.add_child(_keys_l)
	_stand_btn = UIK.button("Встать (Esc)", "Button", func(): enter_walk(), "x"); _stand_btn.position = Vector2(16, 84); _stand_btn.visible = false
	hud.add_child(_stand_btn)

func _refresh_hud() -> void:
	if hud == null or Game.S.is_empty(): return
	var S: Dictionary = Game.S
	_clock_l.text = "%s · день %d" % [Game.clock_str(), int(S.day)]
	var need = Game.xp_need()
	_lvl_l.text = "Уровень %d · %s/%s XP" % [int(S.level), Game.fmt(S.xp), Game.fmt(need)]
	_xp_bar.value = float(S.xp) / need
	_rep_l.text = "%.1f" % float(S.rep)
	if not _money_l.has_meta("tick_tw") or not (_money_l.get_meta("tick_tw") as Tween).is_running():
		_money_l.text = Game.rub(S.money)
	var walk = mode == "walk"
	_cross.visible = walk and not phone.opened
	_prompt_l.visible = walk and _prompt_l.text != "" and not phone.opened
	_stand_btn.visible = mode in ["bench", "unbox", "pack"]
	match mode:
		"walk": _keys_l.text = "WASD — ходить · Shift — бег · E / ЛКМ — действие · Tab — телефон · Esc — меню"
		"bench": _keys_l.text = "Esc — встать · Tab — телефон · ПКМ — вращать · колесо — зум"
		"unbox", "pack": _keys_l.text = "ЛКМ — действие · ПКМ — вращать · Esc — отложить"
		_: _keys_l.text = ""

func _on_money(_delta: float) -> void:
	var v = float(Game.S.money)
	var from = _money_shown; _money_shown = v
	UIK.ticker(_money_l, from, v, func(x): return Game.rub(round(x)), 0.9)
	UIK.pop(_money_l, 1.08 if v >= from else 0.96)
	if v > from + 1.0: _coin_burst(v - from)

func _hint(text: String, progress: float) -> void:
	_hint_box.visible = text != ""
	_hint_l.text = text
	_hint_bar.visible = progress >= 0.0
	if progress >= 0.0: _hint_bar.value = progress

# ------------------------------------------------------------------ modes
func _leave_current() -> void:
	match mode:
		"bench": _close_host()
		"pc": _pc_back()
		"unbox":
			if unbox and is_instance_valid(unbox): unbox.queue_free()
			unbox = null; _hint("", -1.0); home.sync(); _show_parcels()
		"pack":
			if pack and is_instance_valid(pack): pack.queue_free()
			pack = null; _hint("", -1.0)
			home.set_drawer(3, false)
	if phone.opened: phone.close()

func enter_walk() -> void:
	_leave_current()
	mode = "walk"
	ws.cam.current = false; player.cam.current = true
	player.active = true; hud.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_sync_kb_idle()
	_refresh_hud()

## The keyboard on the bench shows the current build (or nothing) while walking around.
func _sync_kb_idle() -> void:
	set_kb_sound({})
	ws.mode = "view"; ws.kb.set_ghost("")
	if Game.S.build:
		ws.kb.visible = true; ws.kb.show_spec(Game.build_spec(Game.S.build), Game.S.build)
	else:
		ws.kb.visible = false

func _bench_cam() -> void:
	player.active = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.cam.current = false; ws.cam.current = true
	ws.idle_spin = false

func sit_bench() -> void:
	_leave_current()
	mode = "bench"; tab = "workshop"
	_bench_cam()
	ws.orb_goal.target = Vector3(0, 0.01, 0); ws.orb.target = ws.orb_goal.target
	_open_host("workshop")
	_refresh_hud()

func _open_host(id: String) -> void:
	_close_host()
	screen = SCREENS[id].new(); _host_screen = screen
	screen.main = self
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(screen)
	screen.build_screen(true)
	if screen.layout() == "side":
		ws.frame_offset = 0.62; ws.set_view(screen.cam_view())
	Audio.ui("whoosh")

func _close_host() -> void:
	for c in host.get_children():
		if c == screen: screen = null
		c.queue_free()
	_host_screen = null
	ws.frame_offset = 0.0

func open_pc() -> void:
	_leave_current()
	mode = "pc"
	player.active = false; Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.visible = false
	Audio.sfx("mouse", Home.PC_SPOT)
	home.monitor_vp.remove_child(os)
	ui.add_child(os); ui.move_child(os, modal_layer.get_index())
	os.modulate.a = 0.0; os.create_tween().tween_property(os, "modulate:a", 1.0, 0.25)

func _pc_back() -> void:
	if os.get_parent() == ui:
		ui.remove_child(os); home.monitor_vp.add_child(os)
		os.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if screen and os.is_ancestor_of(screen): pass
	hud.visible = true

func leave_pc() -> void:
	enter_walk()

func toggle_phone() -> void:
	if mode == "intro" or mode == "pc": return
	if phone.opened:
		phone.close()
		if mode == "walk": player.active = true; Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if mode == "bench" and is_instance_valid(_host_screen): screen = _host_screen; screen.build_screen(false)
	else:
		phone.open()
		player.active = false; Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_hud()

## Screens call this to jump to another tab. On the PC it opens an app, at the bench "workshop" is the bench itself,
## everything else opens on the phone.
func open_tab(id: String, _anim := true) -> void:
	if _modal: close_modal()
	tab = id
	if id == "workshop":
		if phone.opened: toggle_phone()
		if mode != "bench": sit_bench()
		elif is_instance_valid(_host_screen): screen = _host_screen; screen.build_screen(true)
		return
	if mode == "pc": os.open_app(id); return
	if not phone.opened: toggle_phone()
	phone.open_app(id)

func mark_ui(force := false) -> void:
	_ui_dirty = true
	if force: _ui_t = 1.0

func _process(delta: float) -> void:
	_ui_t += delta
	if home: home.set_time(Game.clock_min())
	if _ui_dirty and _ui_t > 0.3:
		_ui_t = 0.0; _ui_dirty = false
		_refresh_hud()
		if screen and is_instance_valid(screen) and screen.can_refresh(): screen.build_screen(false)
		if _modal and _modal.has_method("refresh"): _modal.refresh()
	elif _ui_t > 1.0:
		_ui_t = 0.0; _refresh_hud()

# ------------------------------------------------------------------ interaction
func _parcel_of(id: String) -> Dictionary:
	return Game.parcel_by_id(id.trim_prefix("parcel:")) if id.begins_with("parcel:") else {}

func _bench_parcel() -> Dictionary:
	for p in Game.S.parcels:
		if p.place == "bench": return p
	return {}

func _outside(pos: Vector3) -> bool: return Home.is_outside(pos)

func prompt_for(t: Dictionary) -> String:
	if mode != "walk" or _modal: return ""
	var id: String = t.get("id", "")
	if not carry.is_empty():
		var surf: bool = t.has("normal") and (t.normal as Vector3).y > 0.7
		if carry.kind == "parcel":
			var p = Game.parcel_by_id(carry.id)
			if id == "bench" and p.kind != "out": return "E — Поставить на верстак и распаковать" if _bench_parcel().is_empty() else "На верстаке уже стоит коробка"
			if surf and t.has("pos") and _outside(t.pos): return "E — Оставить у двери для курьера" if p.kind == "out" else "E — Поставить у двери"
			if surf or id in ["pack", "shelf", "bed"]: return "E — Поставить"
			return ""
		if carry.kind == "crate":
			var n: int = (carry.uids as Array).size()
			if id == "bench": return "E — Выложить детали на верстак (%d)" % n
			if id == "shelf": return "E — Разложить по полкам (%d)" % n
			return "Несёте ящик с деталями (%d)" % n
	if id.begins_with("parcel:"):
		var p = _parcel_of(id)
		if p.is_empty(): return ""
		if p.place == "bench" and p.kind != "out": return "E — Распаковать   ·   R — снять с верстака"
		return "E — Взять посылку" if p.kind == "out" else "E — Взять коробку"
	match id:
		"bench":
			var s = "E — Работать за верстаком"
			if not Game.items_at("bench").is_empty(): s += "   ·   R — убрать детали на склад"
			return s
		"pc": return "E — Сесть за компьютер"
		"shelf": return "E — Склад: взять детали под заказ (%d)" % Game.items_at("shelf").size()
		"pack":
			var n = Game.S.ship.filter(func(s): return s.status == "ready").size()
			return "E — Упаковочный стол" + ((" · к упаковке: %d" % n) if n > 0 else "")
		"bed": return "E — Лечь спать до утра" if Game.can_sleep() else "Спать рано: кровать доступна после 18:00"
		"door": return "E — Закрыть дверь" if home.door_open else "E — Открыть дверь"
		"aquarium": return "E — Покормить акулу"
	return ""

func _interact(t: Dictionary) -> void:
	if mode != "walk" or _modal or phone.opened: return
	var id: String = t.get("id", "")
	if not carry.is_empty():
		_place_carry(t); return
	if id.begins_with("parcel:"):
		var p = _parcel_of(id)
		if p.is_empty(): return
		if p.place == "bench" and p.kind != "out": start_unbox(p)
		else: _pick_parcel(p)
		return
	match id:
		"bench": sit_bench()
		"pc": open_pc()
		"shelf": home.set_wardrobe(true); _shelf_modal()
		"pack": _pack_modal()
		"bed": _sleep(false)
		"door": home.toggle_door()
		"aquarium": if home.aquarium: home.aquarium.feed()

func _alt_interact(t: Dictionary) -> void:
	if mode != "walk" or _modal or phone.opened or not carry.is_empty(): return
	var id: String = t.get("id", "")
	if id == "bench":
		var uids = Game.items_at("bench").map(func(it): return int(it.uid))
		if uids.is_empty(): return
		_take_crate(uids)
	elif id.begins_with("parcel:"):
		var p = _parcel_of(id)
		if not p.is_empty(): _pick_parcel(p)

func _pick_parcel(p: Dictionary) -> void:
	var n: Parcel3D = home.parcels.get(p.id)
	if n == null: return
	if p.place == "door" and not home.door_open: home.set_door(true)
	player.carry(n)
	Game.set_parcel_place(p.id, "carry")
	carry = {"kind": "parcel", "id": p.id, "node": n}
	Audio.sfx("box_down", null, -8.0, 0.1)

func _place_carry(t: Dictionary) -> void:
	var id: String = t.get("id", "")
	if carry.kind == "parcel":
		var p = Game.parcel_by_id(carry.id)
		var place = ""; var pos = null
		if id == "bench" and p.kind != "out":
			if not _bench_parcel().is_empty(): toast("На верстаке уже стоит коробка", "bad"); return
			place = "bench"
		elif t.has("normal") and (t.normal as Vector3).y > 0.7 and t.has("pos"):
			pos = t.pos
			place = "door" if (_outside(pos) and p.kind == "out") else "floor"
		else: return
		var n: Node3D = player.drop_held()
		if n: home.add_child(n)
		carry = {}
		Game.set_parcel_place(p.id, place, pos, player.rotation.y)
		if n is Parcel3D: (n as Parcel3D).land()
		Audio.sfx("box_down", home.parcel_pos(Game.parcel_by_id(p.id)))
		if place == "bench": start_unbox(Game.parcel_by_id(p.id))
		return
	if carry.kind == "crate":
		var loc = "bench" if id == "bench" else ("shelf" if id == "shelf" else "")
		if loc == "": return
		if loc == "bench" and Game.bench_free() < (carry.uids as Array).size():
			toast("На верстаке нет места: уберите лишнее на склад", "bad"); return
		if loc == "shelf":
			home.set_wardrobe(true); get_tree().create_timer(1.6).timeout.connect(func(): home.set_wardrobe(false))
		Game.move_items(carry.uids, loc)
		var n2 = player.drop_held()
		if n2: n2.queue_free()
		carry = {}; Game.S.carry = null; Game.mark()
		Audio.sfx("box_down", null, -4.0); Audio.ui("cap")

func _take_crate(uids: Array) -> void:
	Game.move_items(uids, "crate")
	Game.S.carry = {"kind": "crate", "uids": uids}
	var crate = _crate_node(uids)
	player.carry(crate)
	carry = {"kind": "crate", "uids": uids, "node": crate}
	Audio.sfx("tray", null, -4.0)

func _crate_node(uids: Array) -> Node3D:
	var n = Node3D.new()
	var m = Mats.std(Color("2f6fd6"), 0.55)
	var t = 0.006; var sx = 0.4; var sy = 0.14; var sz = 0.28
	for s in [[Vector3(sx, t, sz), Vector3(0, 0, 0)], [Vector3(sx, sy, t), Vector3(0, sy / 2.0, sz / 2.0)], [Vector3(sx, sy, t), Vector3(0, sy / 2.0, -sz / 2.0)],
			[Vector3(t, sy, sz), Vector3(sx / 2.0, sy / 2.0, 0)], [Vector3(t, sy, sz), Vector3(-sx / 2.0, sy / 2.0, 0)]]:
		var mi = MeshInstance3D.new(); var bm = BoxMesh.new(); bm.size = s[0]; mi.mesh = bm; mi.material_override = m; mi.position = s[1]; n.add_child(mi)
	var i = 0
	for u in uids:
		var it = Game.item_by_uid(u)
		if it.is_empty(): continue
		var b = ItemBox.make(it); b.scale = Vector3.ONE * 0.55; b.position = Vector3(-0.1 + (i % 2) * 0.2, 0.01 + (i / 2) * 0.03, 0.0); b.rotation.y = randf_range(-0.2, 0.2)
		n.add_child(b); i += 1
	n.position.y = -0.05
	return n

## Saved while carrying: parcels go back on the floor, crates back to the shelf.
func _restore_carry() -> void:
	var c = Game.S.get("carry")
	if c is Dictionary and c.get("kind", "") == "crate":
		Game.move_items(c.uids, "shelf")
	for it in Game.S.inv.items:
		if Game.item_loc(it) == "crate": it.loc = "shelf"
	Game.S.carry = null
	for p in Game.S.parcels:
		if p.place == "carry": p.place = "floor"; p.pos = null
	home.sync()

func _show_parcels() -> void:
	for id in home.parcels:
		var n = home.parcels[id]
		if is_instance_valid(n): n.visible = true

# ------------------------------------------------------------------ shelf (picking parts for an order)
func _shelf_modal() -> void:
	var items = Game.items_at("shelf")
	var v = UIK.vbox(12, [modal_head("Склад: взять детали", "Шкаф")])
	if items.is_empty():
		v.add_child(UIK.label("Шкаф пуст. Детали появляются здесь, когда вы уберёте их с верстака (R у верстака).", "Muted", true))
		v.add_child(UIK.hbox(8, [UIK.spacer(), UIK.button("Понятно", "BtnPri", close_modal)]))
		open_modal(v, 560); return
	v.add_child(UIK.label("Отметьте детали, которые нужны для следующей сборки. Вы понесёте их к верстаку в ящике. На верстаке свободно мест: %d." % Game.bench_free(), "SmallMuted", true))
	var picked = {}
	var cats = ["case", "plate", "pcb", "stab", "kc"]
	var count_l = UIK.label("", "Small")
	var take = UIK.button("Взять в ящик", "BtnPri", func(): pass, "box")
	var upd = func():
		count_l.text = "Выбрано: %d" % picked.size(); take.disabled = picked.is_empty() or picked.size() > Game.bench_free()
	for c in cats:
		var of = items.filter(func(it): return it.cat == c)
		if of.is_empty(): continue
		v.add_child(UIK.label(Data.CAT_NAMES.get(c, c).to_upper(), "Eyebrow"))
		var fl = UIK.flow(6)
		for it in of:
			var nm: String = str(Data.item(c, it.id).get("name", it.id))
			if it.has("layout"): nm += " · " + str(Data.LAYOUTS[it.layout].name)
			var cb = CheckBox.new(); cb.text = nm; cb.focus_mode = Control.FOCUS_NONE
			cb.toggled.connect(func(on):
				if on: picked[int(it.uid)] = true
				else: picked.erase(int(it.uid))
				Audio.ui("tick"); upd.call())
			fl.add_child(cb)
		v.add_child(fl)
	take.pressed.connect(func(): close_modal(); _take_crate(picked.keys()))
	v.add_child(UIK.hbox(10, [count_l, UIK.spacer(), UIK.button("Отмена", "BtnGhost", close_modal), take]))
	upd.call()
	var p = await open_modal(v, 720)
	if p: p.set_meta("on_close", func():
		get_tree().create_timer(0.4).timeout.connect(func(): home.set_wardrobe(false))
		if mode == "walk" and not phone.opened: player.active = true; Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)

# ------------------------------------------------------------------ packing table
func _pack_modal() -> void:
	if Game.S.parcels.any(func(p): return p.place == "pack"):
		toast("На столе уже стоит готовая посылка: отнесите её к двери", "bad"); return
	var v = UIK.vbox(12, [modal_head("Упаковка и отправка", "Упаковочный стол")])
	var ready = Game.S.ship.filter(func(s): return s.status == "ready")
	if not ready.is_empty():
		v.add_child(UIK.label("ГОТОВО К УПАКОВКЕ", "Eyebrow"))
		for s in ready:
			var what = {"order": "Заказ для %s", "repair": "Возврат после ремонта: %s", "sale": "Покупатель интернет-магазина: %s"}.get(str(s.kind), "%s") % str(s.name)
			var b = Game.find_board(s.get("buid", -1))
			var sub_t = str(b.get("name", "")) if not b.is_empty() else "клавиатура клиента"
			v.add_child(UIK.card("Card", UIK.hbox(10, [UIK.expand(UIK.vbox(0, [UIK.label(what, "H3"), UIK.label(sub_t, "SmallMuted")])), UIK.button("Упаковать", "BtnPri", func(): close_modal(); start_pack(s), "gift")])))
	var orders = Game.S.orders.filter(func(o): return o.kind != "repair" and not o.get("shipping", false))
	if not orders.is_empty() and not Game.free_boards().is_empty():
		v.add_child(UIK.label("ОТПРАВИТЬ КЛИЕНТУ", "Eyebrow"))
		for o in orders:
			v.add_child(UIK.card("Card", UIK.hbox(10, [UIK.expand(UIK.vbox(0, [UIK.label(o.name, "H3"), UIK.label("бюджет " + Game.rub(o.budget), "SmallMuted")])),
				UIK.button("Выбрать клавиатуру", "BtnTeal", func(): close_modal(); _choose_board(o), "truck")])))
	if ready.is_empty() and (orders.is_empty() or Game.free_boards().is_empty()):
		v.add_child(UIK.label("Упаковывать нечего. Сюда попадают: клавиатуры для заказов, проданные в интернет-магазине и починенные клавиатуры клиентов.", "Muted", true))
	v.add_child(UIK.hbox(8, [UIK.spacer(), UIK.button("Закрыть", "BtnGhost", close_modal)]))
	open_modal(v, 640)

func _choose_board(o: Dictionary) -> void:
	var rows = []
	for b in Game.free_boards(): rows.append({"b": b, "r": Game.eval_order(o, b)})
	rows.sort_custom(func(a, c): return a.r.stars > c.r.stars)
	var v = UIK.vbox(12, [modal_head("Заказ: " + o.name), UIK.card("Note", UIK.label("«%s»" % o.text, "Small", true))])
	for x in rows:
		var b: Dictionary = x.b; var r: Dictionary = x.r
		var chips = UIK.flow(5)
		for ch in r.ch: chips.add_child(UIK.chip(("✓ " if ch.ok else "✕ ") + ch.label, UIK.GOOD if ch.ok else UIK.BAD))
		v.add_child(UIK.card("Card", UIK.vbox(8, [UIK.hbox(10, [UIK.expand(UIK.label(b.name, "H3")), UIK.stars(r.stars)]), chips,
			UIK.hbox(8, [UIK.label("Оплата " + Game.rub(r.pay + r.tip), "Price"), UIK.spacer(), UIK.button("Упаковать для него", "BtnPri", func():
				close_modal(); var s = Game.ship_order(o.id, b.uid)
				if not s.is_empty(): start_pack(s), "gift")])])))
	open_modal(v, 720)

func start_pack(s: Dictionary) -> void:
	home.set_drawer(3, true)                     # the top drawer slides out: tape, labels, mailers live there
	_leave_current()
	mode = "pack"
	_bench_cam()
	pack = Pack.new().setup(s, ws.cam)
	pack.position = Home.PACK_SPOT; pack.rotation.y = Home.PACK_ROT
	home.add_child(pack)
	pack.hint_changed.connect(_hint)
	pack.finished.connect(func(p):
		await get_tree().create_timer(0.5).timeout
		if pack: pack.queue_free(); pack = null
		_hint("", -1.0); enter_walk()
		toast("Посылка готова и стоит на столе. Отнесите её к двери: курьер заберёт и привезёт деньги.", "gold"))
	ws.orb_goal.target = Home.PACK_SPOT + Vector3(0, 0.04, 0); ws.orb.target = ws.orb_goal.target
	ws.orb_goal.theta = Home.PACK_ROT; ws.orb_goal.phi = 0.78; ws.orb_goal.dist = 0.85
	_refresh_hud()

# ------------------------------------------------------------------ unboxing
func start_unbox(p: Dictionary) -> void:
	if p.kind == "client" and Game.S.build != null:
		toast("Сначала закончите текущую работу на верстаке", "bad"); return
	_leave_current()
	mode = "unbox"
	_bench_cam()
	var n = home.parcels.get(p.id)
	if n: n.visible = false
	unbox = Unbox.new().setup(p, ws.cam)
	unbox.position = Home.UNBOX_SPOT; unbox.rotation.y = float(p.get("rot", 0.0)) * 0.0
	home.add_child(unbox)
	unbox.hint_changed.connect(_hint)
	unbox.finished.connect(_unboxed)
	ws.orb_goal.target = Home.UNBOX_SPOT + Vector3(0, 0.08, 0); ws.orb.target = ws.orb_goal.target
	ws.orb_goal.theta = 0.25; ws.orb_goal.phi = 0.82; ws.orb_goal.dist = 0.72
	_refresh_hud()

func _unboxed(got: Array) -> void:
	await get_tree().create_timer(0.3).timeout
	if unbox: unbox.queue_free(); unbox = null
	_hint("", -1.0)
	var names = []
	var client = false
	for it in got:
		if it.cat == "client": client = true; continue
		var nm: String = str(Data.item(it.cat, it.id).get("name", it.id))
		if it.has("n"): nm += " ×%d" % int(it.n)
		names.append(nm)
	if client:
		toast("Клавиатура клиента на верстаке. Садитесь за верстак (E): диагностика и ремонт.", "gold")
		sit_bench()
		return
	if not names.is_empty(): toast("Распаковано: " + ", ".join(names) + ". Детали лежат на верстаке.", "good")
	enter_walk()

# ----------------------------------------------------------------- input
func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey:
		var k = ev as InputEventKey
		if k.pressed and not k.echo and k.keycode == KEY_F11:
			var w = get_window()
			w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN or w.mode == Window.MODE_EXCLUSIVE_FULLSCREEN else Window.MODE_FULLSCREEN
			return
		if k.pressed and not k.echo and k.keycode == KEY_ESCAPE:
			_escape(); get_viewport().set_input_as_handled(); return
		if k.pressed and not k.echo and k.keycode == KEY_TAB and mode in ["walk", "bench"] and not _modal:
			toggle_phone(); get_viewport().set_input_as_handled(); return
		if k.pressed and not k.echo and k.keycode == KEY_R and mode == "bench" and Game.S.build and ws.asm.step() == "case":
			ws.asm.rotate_piece(); return
		if mode == "bench": _phys_key(k)
		return
	if _modal: return
	if ev is InputEventMouse:
		match mode:
			"bench":
				if ws.handle_input(ev): get_viewport().set_input_as_handled()
			"unbox":
				if unbox and unbox.handle_input(ev): get_viewport().set_input_as_handled()
				elif _orbit_only(ev): get_viewport().set_input_as_handled()
			"pack":
				if pack and pack.handle_input(ev): get_viewport().set_input_as_handled()
				elif _orbit_only(ev): get_viewport().set_input_as_handled()

## Right-drag orbit and wheel zoom around the current target (unboxing / packing).
func _orbit_only(ev: InputEvent) -> bool:
	if ev is InputEventMouseButton:
		var mb = ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed: ws.orb_goal.dist = max(0.35, float(ws.orb_goal.dist) * 0.9); return true
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed: ws.orb_goal.dist = min(1.6, float(ws.orb_goal.dist) * 1.1); return true
		if mb.button_index == MOUSE_BUTTON_RIGHT: ws._drag = {"orb": mb.pressed} if mb.pressed else {}; return true
	if ev is InputEventMouseMotion and ws._drag.get("orb", false):
		var mm = ev as InputEventMouseMotion
		ws.orb_goal.theta = float(ws.orb_goal.theta) - mm.relative.x * 0.006
		ws.orb_goal.phi = clamp(float(ws.orb_goal.phi) - mm.relative.y * 0.005, 0.15, 1.4)
		return true
	return false

func _escape() -> void:
	if _modal: close_modal(); return
	if phone.opened: toggle_phone(); return
	match mode:
		"bench", "pc", "unbox", "pack": enter_walk()
		"walk": _pause_menu()

func _pause_menu() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE; player.active = false
	var v = UIK.vbox(12, [modal_head("Пауза", Game.clock_str() + " · день %d" % int(Game.S.day))])
	for b in [["Продолжить", "BtnPri", func(): close_modal()], ["Настройки", "Button", func(): Settings.open(self)], ["Как играть", "Button", func(): Intro.open(self)],
			["Сохранить и выйти", "BtnGhost", func(): Game.save_game(); get_tree().quit()]]:
		var bt = UIK.button(b[0], b[1], b[2]); bt.custom_minimum_size.y = 44; v.add_child(bt)
	var p = await open_modal(v, 420)
	if p: p.set_meta("on_close", func(): if mode == "walk": player.active = true; Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)

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
	var fg = bool(kb_ctx.L.get("fgap", false))
	if down and Game.S.build and mode == "bench" and ws.asm.step() == "keytest":
		play = ws.asm.keytest(i)
	elif Game.S.build and mode == "bench" and ws.asm.step() == "diag":
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
	if toasts == null: return
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
	tw.chain().tween_interval(4.2 if kind != "gold" else 6.0)
	tw.chain().tween_property(p, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(p.queue_free)

# ----------------------------------------------------------------- modals
func open_modal(content: Control, width := 640.0) -> PanelContainer:
	close_modal(true)
	if mode == "walk":
		player.active = false; Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
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
	elif mode == "walk" and not instant and not phone.opened:
		player.active = true; Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
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
	var v = UIK.vbox(12, [modal_head("Пока вас не было", "Офлайн"),
		UIK.rich("Прошло [b]%s[/b]." % Game.dur(float(off.away)))])
	for s in off.sold: v.add_child(UIK.label("Заказ в интернет-магазине: %s — %s (упакуйте и отправьте)" % [s.name, Game.rub(s.amt)], "Muted"))
	if float(off.repair) > 0: v.add_child(UIK.label("Ремонтная стойка: " + Game.rub(off.repair), "Muted"))
	for g in off.gb: v.add_child(UIK.label("Пришла посылка group buy: " + str(g), "Muted"))
	v.add_child(UIK.hbox(10, [UIK.spacer(), UIK.button("Отлично", "BtnPri", close_modal)]))
	open_modal(v, 460)

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
	_refresh_hud()

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
