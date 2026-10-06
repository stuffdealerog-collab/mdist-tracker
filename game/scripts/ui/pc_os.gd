class_name PcOS
extends Control
## "KeyOS": the desktop of the in-game computer. Lives inside the monitor's SubViewport (so the screen
## in the room shows the real desktop) and is moved to full screen while the player sits at the PC.
## Each app window hosts one of the game screens (orders, KeyMarket, deliveries, storage, upgrades…).

const APPS := [
	["orders", "Заказы", "clipboard", Color("ff8160")], ["market", "KeyMarket", "cart", Color("4cb8ab")],
	["deliveries", "Доставки", "truck", Color("ebc66c")], ["storage", "Склад", "box", Color("8fa3b8")],
	["shop", "Мой магазин", "store", Color("a98bf0")], ["growth", "Улучшения", "trend", Color("6be3a0")],
	["map", "Недвижимость", "home", Color("f2a7c3")], ["boxes", "Коробки", "gift", Color("ff9de2")],
	["trade", "Барахолка", "swap", Color("9ad0f5")], ["events", "События", "calendar", Color("ffd166")],
	["collection", "Коллекция", "trophy", Color("e8c26a")],
]

var main
var desk: Control
var win: PanelContainer = null
var win_host: Control
var app = ""
var _clock: Label
var _task_app: Label
var _note_dot: Panel

func _init(m) -> void:
	main = m

func _ready() -> void:
	theme = UIK.theme
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# wallpaper: deep teal gradient with the brand
	var wp = ColorRect.new(); wp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); wp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh = Shader.new(); sh.code = "shader_type canvas_item; void fragment(){ vec2 p = UV; vec3 a = vec3(0.04,0.07,0.09); vec3 b = vec3(0.09,0.2,0.22); float g = smoothstep(1.2, 0.0, length(p - vec2(0.75, 0.25)) * 1.4); vec3 c = mix(a, b, g); c += 0.03 * sin(p.x * 40.0 + p.y * 12.0) * g; COLOR = vec4(c, 1.0); }"
	var sm = ShaderMaterial.new(); sm.shader = sh; wp.material = sm; add_child(wp)
	var logo = UIK.label("KeyOS", "Big"); logo.add_theme_font_size_override("font_size", 96); logo.modulate = Color(1, 1, 1, 0.06)
	logo.set_anchors_and_offsets_preset(Control.PRESET_CENTER); logo.grow_horizontal = Control.GROW_DIRECTION_BOTH; logo.grow_vertical = Control.GROW_DIRECTION_BOTH
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(logo)
	# desktop icons
	desk = Control.new(); desk.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); desk.offset_bottom = -52; desk.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(desk)
	var grid = GridContainer.new(); grid.columns = 2; grid.add_theme_constant_override("h_separation", 10); grid.add_theme_constant_override("v_separation", 8)
	grid.position = Vector2(22, 22); desk.add_child(grid)
	for a in APPS: grid.add_child(_icon(a))
	# window host
	win_host = Control.new(); win_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); win_host.offset_left = 230; win_host.offset_top = 16
	win_host.offset_right = -16; win_host.offset_bottom = -64; win_host.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(win_host)
	_taskbar()

func _icon(a: Array) -> Control:
	var b = Button.new(); b.flat = true; b.custom_minimum_size = Vector2(92, 84); b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("hover", UIK.sb(Color(1, 1, 1, 0.08), 10, Color(1, 1, 1, 0.12), 0))
	b.add_theme_stylebox_override("pressed", UIK.sb(Color(1, 1, 1, 0.14), 10, Color(1, 1, 1, 0.2), 0))
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new()); b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var v = UIK.vbox(4); v.alignment = BoxContainer.ALIGNMENT_CENTER; v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tile = PanelContainer.new(); tile.custom_minimum_size = Vector2(46, 46); tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tile.add_theme_stylebox_override("panel", UIK.sb(a[3].darkened(0.35), 12, a[3], 0)); tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic = UIK.icon_rect(a[2], 26, Color.WHITE); ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tile.add_child(ic)
	var l = UIK.label(a[1], "Small"); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(tile); v.add_child(l); b.add_child(v); v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.pressed.connect(func(): Audio.sfx("mouse"); open_app(a[0]))
	return b

func _taskbar() -> void:
	var tb = PanelContainer.new(); tb.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE); tb.offset_top = -48
	tb.add_theme_stylebox_override("panel", UIK.sb(Color(0.03, 0.04, 0.05, 0.92), 0, Color(1, 1, 1, 0.06), 8))
	add_child(tb)
	var h = UIK.hbox(14); tb.add_child(h)
	var start = UIK.button(" KeyOS", "BtnGhost", func(): close_app(), "keyboard"); h.add_child(start)
	_task_app = UIK.label("", "Small"); h.add_child(_task_app)
	h.add_child(UIK.spacer())
	_note_dot = UIK.swatch(UIK.CORAL, 8); _note_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER; h.add_child(_note_dot)
	var money = UIK.label("", "Num"); money.name = "money"; h.add_child(money)
	_clock = UIK.label("", "Num"); h.add_child(_clock)
	var off = UIK.button("Встать из-за компьютера", "BtnGhost", func(): main.leave_pc(), "x"); off.name = "exit"; h.add_child(off)

func _process(_d: float) -> void:
	if not is_visible_in_tree() or Game.S.is_empty(): return
	_clock.text = "%s · день %d" % [Game.clock_str(), int(Game.S.day)]
	(_clock.get_parent().get_node("money") as Label).text = Game.rub(Game.S.money)
	_note_dot.visible = Game.S.orders.size() > 0 or Game.S.ship.size() > 0
	var exit_b = _clock.get_parent().get_node("exit")
	exit_b.visible = main.mode == "pc"

func open_app(id: String) -> void:
	if not main.SCREENS.has(id): return
	close_app(true)
	app = id
	win = UIK.glass(14, Color(0.06, 0.08, 0.1, 0.96)); win.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	win_host.add_child(win)
	var v = UIK.vbox(8); win.add_child(v)
	var title = ""; var ico = "box"
	for a in APPS:
		if a[0] == id: title = a[1]; ico = a[2]
	var bar = UIK.hbox(10, [UIK.icon_rect(ico, 18, UIK.TEAL), UIK.label(title, "H3"), UIK.spacer(), UIK.button("", "BtnGhost", func(): Audio.sfx("mouse"); close_app(), "x")])
	v.add_child(bar)
	var body = Control.new(); body.size_flags_vertical = Control.SIZE_EXPAND_FILL; body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE; v.add_child(body)
	var sc: Control = main.SCREENS[id].new(); sc.main = main
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); body.add_child(sc)
	sc.build_screen(true)
	main.screen = sc
	_task_app.text = "▸ " + title
	win.modulate.a = 0.0; win.scale = Vector2(0.97, 0.97); win.pivot_offset = win_host.size / 2.0
	var tw = win.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(win, "modulate:a", 1.0, 0.18); tw.tween_property(win, "scale", Vector2.ONE, 0.22)

func close_app(instant := false) -> void:
	if win and is_instance_valid(win):
		if main.screen and win.is_ancestor_of(main.screen): main.screen = null
		win.queue_free()
	win = null; app = ""
	if _task_app: _task_app.text = ""
