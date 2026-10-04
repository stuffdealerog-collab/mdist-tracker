class_name LubeGame
extends Control
## Lube mini-game: paint stem rails, housing walls, then shake the spring bag.

signal changed

var main
var round_i = 0
var pts: Array = []
var segs: Array = []
var strokes: Array = []      # [a, b] in normalized coords
var drawing = false
var last = Vector2.ZERO
var mess = 0.0
var shake_n = 0
var dir = 0.0
var last_x = 0.0
var t0 = 0
var scores: Array = []
var _t = 0.0

func start() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var b: Dictionary = Game.S.build
	round_i = int(b.get("lubeR", 0)); scores = b.get("lubeS", []).duplicate()
	_setup()

func box() -> Rect2:
	var s: float = min(size.x, size.y) * 0.86
	return Rect2((size.x - s) / 2.0, (size.y - s) / 2.0, s, s)
func norm(p: Vector2) -> Vector2:
	var bx = box(); return (p - bx.position) / bx.size.x
func rad() -> float: return 0.03 * (1.0 + 0.12 * Game.upl("lubest") + 0.04 * Game.skl("lube"))

func _setup() -> void:
	strokes.clear(); mess = 0.0; shake_n = 0; dir = 0.0; t0 = 0
	match round_i:
		0: segs = [[Vector2(.37, .2), Vector2(.37, .8)], [Vector2(.43, .2), Vector2(.43, .8)], [Vector2(.57, .2), Vector2(.57, .8)], [Vector2(.63, .2), Vector2(.63, .8)]]
		1: segs = [[Vector2(.27, .27), Vector2(.73, .27)], [Vector2(.73, .27), Vector2(.73, .73)], [Vector2(.73, .73), Vector2(.27, .73)], [Vector2(.27, .73), Vector2(.27, .27)]]
		_: segs = []
	pts.clear()
	for s in segs:
		for i in 23: pts.append({"p": s[0].lerp(s[1], i / 22.0), "c": 0})
	changed.emit()

func dist_seg(p: Vector2) -> float:
	var m = 9.0
	for s in segs:
		var a: Vector2 = s[0]; var b: Vector2 = s[1]
		var d = b - a
		var t: float = clamp((p - a).dot(d) / d.length_squared(), 0.0, 1.0)
		m = min(m, (p - a - d * t).length())
	return m

func _gui_input(e: InputEvent) -> void:
	if round_i > 2: return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		drawing = e.pressed
		if e.pressed:
			last = norm(e.position); last_x = last.x
			if t0 == 0: t0 = Time.get_ticks_msec()
		accept_event()
	elif e is InputEventMouseMotion and drawing:
		var p = norm(e.position); _stroke(last, p); last = p
		accept_event()

func _stroke(a: Vector2, b: Vector2) -> void:
	if round_i == 2:
		var dx = b.x - last_x; var d = signf(b.x - a.x)
		if d != 0 and d != dir and abs(dx) > 0.06:
			shake_n += 1; last_x = b.x; dir = d; Audio.ui("lube"); changed.emit()
			if shake_n >= 14: finish_round()
		elif dir == 0: dir = d
		return
	var r = rad(); var len = a.distance_to(b); var n = maxi(1, int(ceil(len / (r * 0.5))))
	for s in range(1, n + 1):
		var p = a.lerp(b, float(s) / n)
		if dist_seg(p) > r * 1.8: mess += len / n
		for q in pts:
			if q.p.distance_to(p) < r: q.c += 1
	strokes.append([a, b])
	if randf() < 0.25: Audio.ui("lube")
	changed.emit()
	if cov() >= 0.97: finish_round()

func cov() -> float:
	if pts.is_empty(): return 0.0
	return pts.filter(func(q): return q.c > 0).size() / float(pts.size())
func score() -> float:
	if round_i == 2: return 1.0 if Time.get_ticks_msec() - t0 < 9000 else 0.85
	var over = pts.filter(func(q): return q.c > 16).size() / float(pts.size())
	return clamp(cov() - over * 0.5 - mess * 1.2, 0.0, 1.0)

func can_finish() -> bool: return cov() >= 0.5 if round_i < 2 else shake_n >= 14

func finish_round() -> void:
	if round_i > 2 or not can_finish(): return
	var sc = score(); scores.append(sc); Audio.ui("good" if sc > 0.85 else "tick")
	Game.toast("%s: %d%%" % [["Направляющие стема", "Стенки корпуса", "Пружины"][round_i], int(round(sc * 100))])
	round_i += 1
	var b: Dictionary = Game.S.build; b.lubeR = round_i; b.lubeS = scores
	if round_i >= 3:
		var sw = Data.sw(b.sw); var base: float = (scores[0] + scores[1]) / 2.0 * 0.8 + scores[2] * 0.2
		b.lubeQ = snappedf(clamp(max(base * (0.92 + 0.02 * Game.skl("lube")), float(sw.lube) * 0.8), 0.0, 1.0), 0.001)
		if scores.all(func(x): return x >= 0.97): Game.S.stats.perfectLube = int(Game.S.stats.perfectLube) + 1
		if base >= 0.8: Game.track("lube", 1)
		Game.toast("Смазка готова: %d%% качества" % int(round(float(b.lubeQ) * 100)), "gold" if base >= 0.8 else "")
		Game.mark(); main.ws.asm.status_changed.emit(); changed.emit(); return
	Game.mark(); _setup()

func status_ui() -> Control:
	var v = UIK.vbox(6)
	var val = ("%d/14" % shake_n) if round_i == 2 else ("покрытие %d%% · грязь %d" % [int(cov() * 100), int(mess * 100)])
	v.add_child(UIK.hbox(8, [UIK.label("Этап %d из 3" % min(3, round_i + 1), "Small"), UIK.spacer(), UIK.label(val, "Num")]))
	v.add_child(UIK.bar(shake_n / 14.0 if round_i == 2 else cov(), UIK.WARN if mess > 0.25 else UIK.TEAL))
	if round_i >= 3: v.add_child(UIK.colored("Смазка: %d%%" % int(round(float(Game.S.build.lubeQ) * 100)), UIK.GOLD, "H3"))
	return v

func _process(d: float) -> void:
	_t += d; queue_redraw()
	var scr = main.screen
	if scr:
		var ld: Button = scr.find_child("lubeDone", true, false)
		if ld: ld.disabled = not can_finish() or round_i > 2

func _draw() -> void:
	if size.x < 50 or size.y < 50: return
	var bx = box(); var s = bx.size.x
	var X = func(v: Vector2) -> Vector2: return bx.position + v * s
	var b: Dictionary = Game.S.build
	if b == null: return
	var sw = Data.sw(b.sw)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.065, 0.08, 0.92))
	draw_circle(Vector2(size.x / 2, size.y * 0.15), max(size.x, size.y) * 0.5, Color(1, 0.84, 0.6, 0.03))
	var f: Font = UIK.f_bold
	if round_i == 0:
		var stem = Color(sw.stem)
		draw_style_box(UIK.sb(stem, int(s * 0.03), Color(0, 0, 0, 0.4), 0, 3), Rect2(X.call(Vector2(.32, .15)), Vector2(s * .36, s * .7)))
		for x in [.37, .43, .57, .63]: draw_rect(Rect2(X.call(Vector2(x, .2)) - Vector2(s * .012, 0), Vector2(s * .024, s * .6)), Color(0, 0, 0, 0.25))
		draw_rect(Rect2(X.call(Vector2(.47, .06)), Vector2(s * .06, s * .12)), stem.darkened(0.2)); draw_rect(Rect2(X.call(Vector2(.44, .09)), Vector2(s * .12, s * .06)), stem.darkened(0.2))
	elif round_i == 1:
		var h = Color(sw.hous)
		draw_style_box(UIK.sb(h, 12, Color(0, 0, 0, 0.45), 0, 4), Rect2(X.call(Vector2(.18, .18)), Vector2(s * .64, s * .64)))
		draw_rect(Rect2(X.call(Vector2(.25, .25)), Vector2(s * .5, s * .5)), Color(0, 0, 0, 0.35))
		draw_circle(X.call(Vector2(.5, .5)), s * .08, Color(1, 1, 1, 0.08))
	elif round_i == 2:
		var bxx = 0.5 + (sin(_t * 16.0) * 0.02 if drawing else 0.0)
		draw_style_box(UIK.sb(Color(0.86, 0.92, 0.96, 0.18), 8, Color(0.86, 0.92, 0.96, 0.5), 0, 3), Rect2(X.call(Vector2(bxx - .22, .28)), Vector2(s * .44, s * .44)))
		for k in 6:
			var c: Vector2 = X.call(Vector2(bxx - .15 + (k % 3) * .15, .4 + (k / 3) * .16))
			var prev = Vector2.ZERO
			for i in 21:
				var t = i / 20.0; var p = c + Vector2(sin(t * 20.0) * s * .02, -s * .06 + t * s * .12)
				if i > 0: draw_line(prev, p, Color("c9ced3"), 2.0, true)
				prev = p
		draw_string(f, Vector2(0, bx.position.y + s * 0.86), "Встряхивайте: водите влево-вправо" if round_i <= 2 else "Готово!", HORIZONTAL_ALIGNMENT_CENTER, size.x, int(s * 0.04), UIK.INK)
	if round_i < 2:
		for sg in segs:
			var a: Vector2 = X.call(sg[0]); var e: Vector2 = X.call(sg[1])
			var n = int(a.distance_to(e) / (s * 0.024))
			for i in n:
				if i % 2 == 0: draw_line(a.lerp(e, float(i) / n), a.lerp(e, float(i + 1) / n), Color(0.3, 0.72, 0.67, 0.75), 2.0)
		var w = rad() * 2.0 * s
		for st in strokes: draw_line(X.call(st[0]), X.call(st[1]), Color(1, 0.77, 0.43, 0.28), w, true)
		for q in pts:
			var col = Color("ff6b5b") if q.c > 16 else (Color("ffc46e") if q.c > 0 else Color(0.3, 0.72, 0.67, 0.5))
			draw_circle(X.call(q.p), s * 0.006, col)
		draw_string(f, Vector2(0, bx.position.y + s * 0.95), "Смажьте 4 направляющие стема" if round_i == 0 else "Смажьте стенки нижнего корпуса", HORIZONTAL_ALIGNMENT_CENTER, size.x, int(s * 0.034), UIK.INK)
	if round_i > 2:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.09, 0.11, 0.7))
		draw_string(UIK.f_disp, Vector2(0, size.y / 2), "Смазка: %d%%" % int(round(float(b.lubeQ) * 100)), HORIZONTAL_ALIGNMENT_CENTER, size.x, int(s * 0.07), UIK.GOLD)
	# brush cursor
	if round_i < 2:
		var mp = get_local_mouse_position()
		draw_arc(mp, rad() * s, 0, TAU, 32, Color(1, 0.77, 0.43, 0.6), 1.5, true)
