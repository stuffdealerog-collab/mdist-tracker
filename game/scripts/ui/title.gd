class_name TitleScreen
extends Control
## Animated title: logo, continue / new game / settings / quit over the 3D workshop.

signal play

var main

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade = ColorRect.new(); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh = Shader.new(); sh.code = "shader_type canvas_item; void fragment(){ float x = UV.x; COLOR = vec4(0.03, 0.04, 0.05, mix(0.88, 0.0, smoothstep(0.25, 0.75, x))); }"
	var m = ShaderMaterial.new(); m.shader = sh; shade.material = m; add_child(shade)
	var v = UIK.vbox(14); v.position = Vector2(110, 0); v.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE); v.offset_left = 110; v.offset_right = 700
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(v)
	var eyebrow = UIK.label("СИМУЛЯТОР МАСТЕРСКОЙ КАСТОМНЫХ КЛАВИАТУР", "Eyebrow"); eyebrow.add_theme_font_size_override("font_size", 13); eyebrow.add_theme_color_override("font_color", UIK.TEAL)
	v.add_child(eyebrow)
	var words = ["KEYBOARD", "SELLER", "SIMULATOR"]
	var cols = [UIK.INK, UIK.CORAL, UIK.INK]
	var logo = UIK.vbox(-14)
	for i in 3:
		var l = UIK.label(words[i], "Big"); l.add_theme_font_size_override("font_size", 86); l.add_theme_color_override("font_color", cols[i])
		logo.add_child(l)
	v.add_child(logo)
	v.add_child(UIK.label("Собирайте клавиатуры руками, слушайте настоящие свитчи,\nпродавайте клиентам и меняйтесь деталями с другими мастерами.", "Muted"))
	v.add_child(UIK.vspace(18))
	var has_save: bool = int(Game.S.stats.built) > 0 or float(Game.S.money) != 25000.0
	var cont = UIK.button("Продолжить" if has_save else "Начать игру", "BtnPri", _play, "play"); cont.custom_minimum_size = Vector2(320, 54); cont.add_theme_font_size_override("font_size", 18)
	var btns = UIK.vbox(10, [cont])
	if has_save: btns.add_child(_wide(UIK.button("Новая игра", "Button", func(): main.confirm("Начать заново?", "Текущий прогресс будет удалён.", "Новая игра", func(): Game.reset_game(); get_tree().reload_current_scene()))))
	btns.add_child(_wide(UIK.button("Настройки", "Button", func(): Settings.open(main), "gear")))
	btns.add_child(_wide(UIK.button("Как играть", "Button", func(): Intro.open(main), "help")))
	btns.add_child(_wide(UIK.button("Выход", "BtnGhost", func(): Game.save_game(); get_tree().quit())))
	for b in btns.get_children(): b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(btns)
	var ver = UIK.label("v1.0 · Godot 4 · %s" % ("Steam" if SteamBridge.available else "standalone"), "SmallMuted")
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT); ver.position = Vector2(110, -40); ver.offset_top = -40; ver.offset_left = 110
	add_child(ver)
	# motion: stagger in
	var i = 0
	for c in [eyebrow] + logo.get_children() + [v.get_child(2)] + btns.get_children():
		c.modulate.a = 0.0
		var tw = c.create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.15 + i * 0.08); tw.tween_property(c, "modulate:a", 1.0, 0.6)
		i += 1
	for l in logo.get_children():
		l.position.x = -60
		(l as Control).create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).tween_property(l, "position:x", 0.0, 0.9).set_delay(0.2 + l.get_index() * 0.1)

func _wide(b: Button) -> Button:
	b.custom_minimum_size = Vector2(320, 44); return b

func _play() -> void:
	Audio.ui("whoosh")
	var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "modulate:a", 0.0, 0.45)
	tw.chain().tween_callback(func(): play.emit(); queue_free())
