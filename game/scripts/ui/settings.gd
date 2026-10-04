class_name Settings
extends RefCounted

static func open(main) -> void:
	var S: Dictionary = Game.S; var st: Dictionary = S.settings
	var v = UIK.vbox(14, [main.modal_head("Настройки")])
	var slider = func(label: String, key: String, def: float) -> Control:
		var s = HSlider.new(); s.min_value = 0; s.max_value = 1; s.step = 0.01; s.value = float(st.get(key, def)); s.custom_minimum_size.x = 260
		s.value_changed.connect(func(x): st[key] = x; Audio.apply_settings(); Game.mark())
		return UIK.hbox(10, [UIK.expand(UIK.label(label, "Small")), s])
	v.add_child(UIK.label("ЗВУК", "Eyebrow"))
	v.add_child(slider.call("Общая громкость", "vol", 0.8))
	v.add_child(slider.call("Фон мастерской", "music", 0.4))
	v.add_child(UIK.label("ГРАФИКА", "Eyebrow"))
	var q = OptionButton.new()
	for x in [["low", "Низкая — для слабых ПК"], ["mid", "Средняя"], ["high", "Высокая — GI, отражения, туман"]]: q.add_item(x[1])
	q.select(["low", "mid", "high"].find(str(st.get("gfx", "high"))))
	q.item_selected.connect(func(i): st.gfx = ["low", "mid", "high"][i]; main.ws.apply_quality(); Game.mark())
	v.add_child(UIK.hbox(10, [UIK.expand(UIK.label("Качество", "Small")), q]))
	var fs = CheckBox.new(); fs.text = "Полный экран (F11)"; fs.button_pressed = main.get_window().mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]
	fs.toggled.connect(func(on): main.get_window().mode = Window.MODE_FULLSCREEN if on else Window.MODE_WINDOWED)
	v.add_child(fs)
	var vs = CheckBox.new(); vs.text = "Вертикальная синхронизация"; vs.button_pressed = DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
	vs.toggled.connect(func(on): DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if on else DisplayServer.VSYNC_DISABLED))
	v.add_child(vs)
	v.add_child(UIK.label("МАСТЕРСКАЯ", "Eyebrow"))
	var nm = LineEdit.new(); nm.text = str(S.shop); nm.max_length = 40; UIK.expand(nm)
	v.add_child(UIK.hbox(10, [UIK.label("Название", "Small"), nm, UIK.button("Сохранить", "BtnTeal", func(): S.shop = nm.text.strip_edges() if nm.text.strip_edges() != "" else S.shop; Game.mark(); Game.toast("Название сохранено"))]))
	v.add_child(UIK.label("ОНЛАЙН", "Eyebrow"))
	var sv = LineEdit.new(); sv.text = str(st.get("server", "")); sv.placeholder_text = "https://ваш-сервер:8787"; UIK.expand(sv)
	var stl = UIK.label("Подключено" if Online.online else "Нет подключения", "Good" if Online.online else "Bad")
	v.add_child(UIK.hbox(10, [UIK.label("Сервер", "Small"), sv, UIK.button("Подключиться", "BtnTeal", func():
		st.server = sv.text.strip_edges(); Game.mark(); await Online.connect_server()
		stl.text = "Подключено" if Online.online else "Нет подключения"; stl.theme_type_variation = "Good" if Online.online else "Bad")]))
	v.add_child(UIK.hbox(10, [UIK.label("Статус:", "SmallMuted"), stl, UIK.spacer(), UIK.label("ID игрока: " + str(S.online.get("pid", "—")), "SmallMuted")]))
	v.add_child(UIK.sep())
	v.add_child(UIK.hbox(10, [UIK.button("Как играть", "BtnGhost", func(): Intro.open(main), "help"), UIK.spacer(), UIK.button("Сбросить прогресс", "BtnGhost", func():
		main.confirm("Сбросить прогресс?", "Все деньги, детали, клавиатуры и достижения будут удалены. Это нельзя отменить.", "Сбросить", func(): Game.reset_game(); main.get_tree().reload_current_scene()))]))
	main.open_modal(v, 620)
