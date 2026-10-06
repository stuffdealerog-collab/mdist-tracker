class_name Phone
extends Control
## Smartphone in the player's hand (Tab): quick access to orders, deliveries, storage and KeyMarket
## from anywhere in the flat, plus a feed of recent events.

const APPS := [["orders", "Заказы", "clipboard", Color("ff8160")], ["deliveries", "Доставки", "truck", Color("ebc66c")],
	["market", "KeyMarket", "cart", Color("4cb8ab")], ["storage", "Склад", "box", Color("8fa3b8")], ["events", "События", "calendar", Color("ffd166")]]

var main
var frame: PanelContainer
var body: Control
var home_v: VBoxContainer
var app = ""
var _time: Label
var opened = false

func _init(m) -> void:
	main = m

func _ready() -> void:
	theme = UIK.theme
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame = PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UIK.sb(Color(0.04, 0.05, 0.06, 0.98), 34, Color(0.25, 0.27, 0.3), 14, 3))
	frame.anchor_left = 1; frame.anchor_right = 1; frame.anchor_top = 1; frame.anchor_bottom = 1
	frame.offset_left = -470; frame.offset_right = -40; frame.offset_top = -820; frame.offset_bottom = -30
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(frame)
	var v = UIK.vbox(8); frame.add_child(v)
	_time = UIK.label("", "Num"); _time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(UIK.hbox(8, [UIK.button("", "BtnGhost", func(): show_home(), "home"), UIK.expand(_time), UIK.button("", "BtnGhost", func(): main.toggle_phone(), "x")]))
	body = Control.new(); body.size_flags_vertical = Control.SIZE_EXPAND_FILL; body.mouse_filter = Control.MOUSE_FILTER_IGNORE; body.clip_contents = true
	v.add_child(body)
	visible = false
	show_home()

func _process(_d: float) -> void:
	if visible and not Game.S.is_empty(): _time.text = "%s · %s" % [Game.clock_str(), Game.rub(Game.S.money)]

func show_home() -> void:
	_clear()
	app = ""
	home_v = UIK.vbox(12); home_v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); body.add_child(home_v)
	var g = GridContainer.new(); g.columns = 3; g.add_theme_constant_override("h_separation", 12); g.add_theme_constant_override("v_separation", 12)
	for a in APPS:
		var b = UIK.button(a[1], "Button", func(): open_app(a[0]), a[2]); b.custom_minimum_size = Vector2(118, 70)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER; b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.add_theme_stylebox_override("normal", UIK.sb(a[3].darkened(0.6), 16, a[3].darkened(0.2), 6))
		g.add_child(b)
	home_v.add_child(g)
	home_v.add_child(UIK.label("ЛЕНТА", "Eyebrow"))
	var feed = UIK.vbox(6)
	for e in Game.S.log.slice(0, 8): feed.add_child(UIK.label("день %d · %s" % [int(e.d), e.t], "SmallMuted", true))
	if Game.S.log.is_empty(): feed.add_child(UIK.label("Пока тихо.", "SmallMuted"))
	home_v.add_child(UIK.scroll(feed)); (home_v.get_child(home_v.get_child_count() - 1) as Control).size_flags_vertical = Control.SIZE_EXPAND_FILL

func open_app(id: String) -> void:
	if not main.SCREENS.has(id): return
	_clear()
	app = id
	var sc: Control = main.SCREENS[id].new(); sc.main = main
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); body.add_child(sc)
	sc.build_screen(true)
	main.screen = sc
	Audio.ui("tick")

func _clear() -> void:
	for c in body.get_children():
		if main.screen == c: main.screen = null
		c.queue_free()

func open() -> void:
	opened = true; visible = true
	if app == "": show_home()
	frame.position.y += 60; frame.modulate.a = 0.0
	var tw = frame.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(frame, "position:y", frame.position.y - 60, 0.25); tw.tween_property(frame, "modulate:a", 1.0, 0.2)
	Audio.sfx("phone_vib", null, -10.0)

func close() -> void:
	opened = false; visible = false
	if main.screen and body.is_ancestor_of(main.screen): main.screen = null
