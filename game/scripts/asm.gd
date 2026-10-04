class_name Asm
extends Node
## Hands-on assembly: per-step input handlers on top of Keyboard3D.
## Input comes from the workshop view as {i, scr, p, spd, x, y}.

signal status_changed
signal warn(text: String)
signal step_changed
signal torque(v: float)

const STEP_INFO := {
	"case": {"n": "Корпус", "t": "Корпус, плата и пластина",
		"help": "Перетащите парящую деталь в корпус и отпустите над ним. Разъём USB должен смотреть назад: если деталь не встаёт, поверните её клавишей R.",
		"ctl": ["ЛКМ: тащить деталь", "R: повернуть", "ПКМ: вращать камеру"]},
	"stab": {"n": "Стабы", "t": "Стабилизаторы",
		"help": "Стабилизаторы ставятся только под длинные клавиши: пробел, Shift, Enter, Backspace. Кликните по каждому месту, подсвеченному жёлтым.",
		"ctl": ["ЛКМ: поставить стаб", "ПКМ: камера"]},
	"lube": {"n": "Смазка", "t": "Смазка свитчей",
		"help": "Ведите кисточкой точно по направляющим. Слой должен быть тонким: мазок мимо пачкает, а если долго водить по одному месту, будет перелив. В конце встряхните пакет с пружинами.",
		"ctl": ["Зажмите и ведите кисточку", "Последний этап: водите влево-вправо"]},
	"sw": {"n": "Свитчи", "t": "Установка свитчей",
		"help": "Зажмите кнопку мыши и ведите над сокетами: свитчи встают по одному. Не спешите, иначе ножка гнётся и свитч краснеет. Погнутый выньте съёмником (ПКМ) и поставьте заново.",
		"ctl": ["Зажать и вести: вставлять", "ПКМ / съёмник: вынуть", "Колесо: зум"]},
	"solder": {"n": "Пайка", "t": "Пайка свитчей",
		"help": "Плата под пайку: держите паяльник над каждым свитчем, пока контакт не станет серебристым. Непропаянная клавиша не будет работать.",
		"ctl": ["Зажать над свитчем: паять", "ПКМ: камера"]},
	"screw": {"n": "Винты", "t": "Сборка корпуса",
		"help": "Затягивайте винты крест-накрест, по номерам. Зажмите винт и отпустите, когда стрелка дойдёт до зелёной зоны. Перетянете — сорвёте резьбу.",
		"ctl": ["Зажать винт: затягивать", "Отпустить в зелёной зоне"]},
	"kc": {"n": "Кейкапы", "t": "Кейкапы",
		"help": "У скульптурного профиля у каждого ряда свой наклон. Выберите ряд в лотке и надевайте кейкапы только на этот ряд. Колпачок из чужого ряда встанет криво: снимите его съёмником.",
		"ctl": ["Зажать и вести: надевать", "ПКМ / съёмник: снять"]},
	"keytest": {"n": "Тест клавиш", "t": "Проверка клавиш",
		"help": "Нажмите каждую клавишу на своей клавиатуре или кликом, либо запустите автотест. Зелёная клавиша работает, красная мёртвая: кликните по ней ещё раз, чтобы починить.",
		"ctl": ["Клавиатура / клик: проверить", "Клик по красной: починить"]},
	"diag": {"n": "Диагностика", "t": "Диагностика неисправностей",
		"help": "Нажмите каждую клавишу на своей клавиатуре или кликом. Слушайте: мёртвая молчит, изношенная печатает дважды, липкая отпускается с задержкой, сухой стаб гремит. Найденные дефекты подсвечиваются.",
		"ctl": ["Клавиатура / клик: проверить", "Автотест: прогнать всё"]},
	"fix": {"n": "Ремонт", "t": "Устранение дефектов",
		"help": "Выберите инструмент и кликните по подсвеченной клавише. Порядок как в жизни: снять кейкап, затем лечить свитч или стаб, потом надеть кейкап обратно. Неверный инструмент считается ошибкой и снижает оценку клиента.",
		"ctl": ["ЛКМ: применить инструмент", "ПКМ: камера", "Колесо: зум"]},
	"test": {"n": "Звук", "t": "Тест звука",
		"help": "Печатайте на своей клавиатуре: играют настоящие записи свитчей, обработанные под вашу сборку. Затем назовите клавиатуру и завершите сборку.",
		"ctl": ["Печать / клик: играть", "Перетаскивание: камера"]},
}
## Repair faults: name, cause, tool sequence, highlight colour.
const FAULTS := {
	"dead": {"n": "Не печатает", "why": "свитч вышел из строя", "seq": ["cap_pull", "sw_pull", "sw_new", "cap_put"], "col": "ff4a3d"},
	"chatter": {"n": "Двойное нажатие", "why": "изношен контакт свитча", "seq": ["cap_pull", "sw_pull", "sw_new", "cap_put"], "col": "ff8a3d"},
	"sticky": {"n": "Залипает", "why": "свитч залит сладким", "seq": ["cap_pull", "clean", "cap_put"], "col": "f2b84b"},
	"stab": {"n": "Гремит стаб", "why": "высохла смазка стабилизатора", "seq": ["cap_pull", "stablube", "cap_put"], "col": "ffd166"},
	"cap": {"n": "Треснул кейкап", "why": "сломана крестовина", "seq": ["cap_pull", "cap_new"], "col": "b48cff"},
	"joint": {"n": "Срабатывает через раз", "why": "холодная пайка", "seq": ["iron"], "col": "cfd6dc"},
}
const TOOLS := [["cap_pull", "Съёмник кейкапов", "x"], ["sw_pull", "Съёмник свитчей", "x"], ["sw_new", "Новый свитч", "plus"], ["cap_put", "Надеть кейкап", "hand"],
	["cap_new", "Новый кейкап", "plus"], ["clean", "Спирт и кисть", "drop"], ["stablube", "Смазка стаба", "drop"], ["iron", "Паяльник", "zap"]]
const TOOL_HINT := {"cap_pull": "Сначала снимите кейкап съёмником", "sw_pull": "Теперь вытащите старый свитч съёмником свитчей", "sw_new": "Вставьте новый свитч",
	"cap_put": "Наденьте кейкап обратно", "cap_new": "Наденьте новый кейкап", "clean": "Промойте свитч спиртом и пройдитесь кистью",
	"stablube": "Смажьте стабилизатор", "iron": "Пропаяйте контакт паяльником"}
const PIECE_N := {"foam": "Пенка в корпус", "pcb": "Плата (PCB)", "pefoam": "PE-фоам", "plate": "Пластина"}

var kb: Keyboard3D
var tool := "main"
var kit := 0
var held := false
var tq_msg := ""
# per-stage transient state
var _cur := -1
var _hold := false
var _snd := 0.0
var _scr := -1
var _tq := 0.0
var _tq_base := 0.0
var _tq_t := 0.0

static func torque_zone() -> Dictionary:
	var l := Game.upl("driver")
	return {"lo": 0.6 - 0.03 * l, "plo": 0.7 - 0.03 * l, "phi": 0.9 + 0.02 * l, "strip": 0.95 + 0.025 * l, "rate": 1.6 * (1.0 + 0.12 * l)}

static func piece_queue(b: Dictionary) -> Array:
	var q := []
	if b.mods.get("foam", false): q.append("foam")
	q.append("pcb")
	if b.mods.get("pefoam", false): q.append("pefoam")
	q.append("plate")
	return q
static func need_solder(b: Dictionary) -> bool: return not Data.pcb(b.parts.pcb.id).hs
static func kc_sculpted(b: Dictionary) -> bool: return Data.kc(b.parts.kc.id).prof != "xda"
static func row_names(layout: String) -> Array:
	return ["F-ряд", "Цифры", "Верхний", "Средний", "Нижний", "Пробел"] if Data.LAYOUTS[layout].get("fgap", false) else ["Цифры", "Верхний", "Средний", "Нижний", "Пробел"]
static func is_repair(b: Dictionary) -> bool: return b.get("kind", "") == "repair"
static func fault_stage(k: Dictionary) -> String:
	var f := str(k.get("f", ""))
	if f == "": return ""
	var seq: Array = FAULTS[f].seq
	return seq[min(int(k.get("fs", 0)), seq.size() - 1)]
static func is_dead(b: Dictionary, k: Dictionary) -> bool:
	return int(k.get("b", 0)) == 1 or (need_solder(b) and float(k.get("so", 0)) < 1.0)

static func b_step(bb: Dictionary) -> String: return str(bb.steps[int(bb.step)]) if not bb.is_empty() else ""
func b() -> Dictionary: return Game.S.build if Game.S.build else {}
func step() -> String:
	var bb := b()
	return str(bb.steps[int(bb.step)]) if not bb.is_empty() else ""

func enter() -> void:
	var bb := b(); if bb.is_empty(): return
	tool = "cap_pull" if step() == "fix" else "main"; tq_msg = ""; held = false; _cur = -1; _hold = false; _scr = -1
	kb.show_spec(Game.build_spec(bb), bb)
	var st := step()
	match st:
		"sw": kb.set_ghost("sw")
		"kc": kb.set_ghost("cap"); _fix_kit()
		"stab": kb.set_ghost("stab")
		"solder": kb.set_ghost("iron")
		_: kb.set_ghost("")
	if st == "case": _setup_piece()
	status_changed.emit()

func resync() -> void:
	kb.sync(b()); status_changed.emit(); Game.mark()

func set_tool(t: String) -> void:
	tool = t
	var st := step()
	if st == "fix": kb.set_ghost(""); status_changed.emit(); return
	kb.set_ghost("pull" if t == "pull" else ("sw" if st == "sw" else ("cap" if st == "kc" else "")))
	status_changed.emit()

func done() -> bool:
	var bb := b(); if bb.is_empty(): return false
	match step():
		"case":
			for n in piece_queue(bb):
				if not bb.pieces.has(n): return false
			return true
		"stab":
			for i in Game.stab_targets(bb.layout):
				if not bb.stabs.has(str(i)): return false
			return true
		"lube": return bb.lubeQ != null
		"sw": return bb.ks.all(func(k): return int(k.s) == 1)
		"solder": return bb.ks.all(func(k): return float(k.so) >= 1.0)
		"screw":
			var z := torque_zone()
			return bb.screws.all(func(v): return v != null and float(v) >= z.lo)
		"kc": return bb.ks.all(func(k): return int(k.c) == 1)
		"keytest", "diag": return bb.ks.all(func(k): return int(k.t) == 1)
		"fix": return bb.ks.all(func(k): return str(k.get("f", "")) == "")
	return true

func next_step(force := false) -> bool:
	var bb := b(); var st := step()
	if bb.is_empty() or int(bb.step) >= bb.steps.size() - 1 or not done(): return false
	if st == "sw":
		var bent: int = bb.ks.filter(func(k): return int(k.b) == 1).size()
		if bent > 0 and not force: warn.emit("Погнутых свитчей: %d. Эти клавиши не будут работать. Всё равно продолжить?" % bent); return false
	if st == "kc":
		var w: int = bb.ks.filter(func(k): return int(k.w) == 1).size()
		if w > 0 and not force: warn.emit("Колпачков не в своём ряду: %d. Сборка будет выглядеть криво и потеряет в качестве. Продолжить?" % w); return false
	if st == "keytest":
		var d: int = bb.ks.filter(func(k): return int(k.d) == 1 or is_dead(bb, k)).size()
		if d > 0 and not force: warn.emit("Не работают клавиши: %d. Клиент это заметит. Продолжить с дефектом?" % d); return false
		finalize()
	if st == "screw": score_screws()
	if bb.steps[int(bb.step) + 1] == "test" and bb.precision == null: finalize()
	bb.step = int(bb.step) + 1
	Audio.ui("whoosh"); Game.mark()
	step_changed.emit()
	enter()
	return true

func score_screws() -> void:
	var bb := b(); var z := torque_zone()
	var q := 0.0
	for v in bb.screws:
		var f := float(v)
		q += 0.3 if f > z.strip else (1.0 if f >= z.plo and f <= z.phi else 0.8)
	var seen := []; var match_n := 0
	for j in bb.screwSeq:
		if not (j in seen): seen.append(j)
	for ix in min(6, seen.size()):
		if Keyboard3D.SCREW_ORDER[ix] == int(seen[ix]): match_n += 1
	bb.sc.screw = (q / 6.0) * (0.8 + 0.2 * match_n / 6.0)

func finalize() -> void:
	var bb := b(); var dead := 0
	for k in bb.ks:
		if is_dead(bb, k): dead += 1
	var al: Array = bb.sc.align
	var align := 0.8
	if al.size() > 0:
		align = 0.0
		for x in al: align += float(x)
		align /= al.size()
	var sw: float = clamp(1.0 - float(bb.bentEver) * 0.025, 0.0, 1.0)
	var wrong_left: int = bb.ks.filter(func(k): return int(k.w) == 1).size()
	var kc: float = clamp(1.0 - float(bb.wrongEver) * 0.02 - wrong_left * 0.05, 0.0, 1.0)
	var fix: float = clamp(1.0 - float(bb.fixes) * 0.02, 0.0, 1.0)
	var screw: float = float(bb.sc.get("screw", 0.8))
	bb.precision = snappedf(align * 0.15 + sw * 0.25 + screw * 0.2 + kc * 0.25 + fix * 0.15, 0.001)
	bb.dead = dead; bb.wrongLeft = wrong_left

func auto() -> void:
	var bb := b(); var st := step()
	match st:
		"case":
			for n in piece_queue(bb):
				if not bb.pieces.has(n): bb.pieces[n] = 1; bb.sc.align.append(0.8)
			kb.piece = null
		"stab":
			for i in Game.stab_targets(bb.layout): bb.stabs[str(i)] = 1
		"sw":
			for i in bb.ks.size():
				var k: Dictionary = bb.ks[i]
				if int(k.s) == 0 or int(k.b) == 1: k.s = 1; k.b = 0; kb.insert(i, "sw")
		"solder":
			for k in bb.ks: k.so = 1.0
		"screw":
			bb.screws = [0.8, 0.8, 0.8, 0.8, 0.8, 0.8]; bb.screwSeq = Keyboard3D.SCREW_ORDER.duplicate()
		"kc":
			for i in bb.ks.size():
				var k: Dictionary = bb.ks[i]
				if int(k.c) == 0 or int(k.w) == 1: k.c = 1; k.w = 0; kb.insert(i, "cap")
		"keytest":
			for k in bb.ks:
				if is_dead(bb, k): k.b = 0; k.so = 1.0; bb.fixes = int(bb.fixes) + 1
				k.d = 0; k.t = 1
		"diag":
			for k in bb.ks:
				k.t = 1
				if str(k.get("f", "")) != "": k.seen = 1
		"fix":
			for k in bb.ks:
				if str(k.get("f", "")) != "": k.f = ""; k.fx = 1; k.s = 1; k.c = 1; bb.fixes = int(bb.fixes) + 1
	Audio.ui("tick"); resync()

# ------------------------------------------------------------------ input
func hover(inf: Dictionary) -> void:
	var bb := b(); if bb.is_empty(): return
	var i: int = inf.i
	match step():
		"stab": kb.ghost_at(i if _stab_ok(i) else -1)
		"sw":
			var ok := i >= 0 and (int(bb.ks[i].s) == 1 if tool == "pull" else int(bb.ks[i].s) == 0)
			kb.ghost_at(i if ok else -1)
		"kc":
			var ok2 := i >= 0 and (int(bb.ks[i].c) == 1 if tool == "pull" else int(bb.ks[i].c) == 0)
			kb.ghost_at(i if ok2 else -1)
		"solder": kb.ghost_at(i)
		"fix": kb.ghost_at(-1)

func down(inf: Dictionary) -> bool:
	var bb := b(); if bb.is_empty(): return false
	match step():
		"case":
			if _cur_piece() == "": return false
			held = true; _move_piece(inf); return true
		"stab": hover(inf); return true
		"sw":
			if tool == "pull": _pull_sw(inf.i)
			else: _ins_sw(inf)
			return true
		"solder":
			_hold = true; _cur = inf.i; kb.ghost_at(inf.i); kb.set_smoke(true); return true
		"screw":
			if inf.scr < 0: return true
			var z := torque_zone(); var v = bb.screws[inf.scr]
			if v != null and float(v) >= z.lo: return true
			_scr = inf.scr; _tq_base = float(v) if v != null and float(v) < z.lo else 0.0; _tq = _tq_base; _tq_t = 0.0
			Audio.ui("ratchet"); return true
		"kc":
			if tool == "pull": _pull_cap(inf.i)
			else: _put_cap(inf.i)
			return true
		"fix": apply_tool(inf.i); return true
	return false

func move(inf: Dictionary) -> void:
	match step():
		"case":
			if held: _move_piece(inf)
		"stab": hover(inf)
		"sw":
			hover(inf)
			if tool == "pull": _pull_sw(inf.i)
			else: _ins_sw(inf)
		"solder": _cur = inf.i; kb.ghost_at(inf.i)
		"kc":
			hover(inf)
			if tool == "pull": _pull_cap(inf.i)
			else: _put_cap(inf.i)

func up(inf: Dictionary) -> void:
	var bb := b(); if bb.is_empty(): return
	match step():
		"case":
			if not held: return
			held = false
			var n := _cur_piece(); if n == "": return
			var p := kb.piece_pos(); var d := p.length()
			if d < 1.2:
				if int(bb.prot.get(n, 0)) % 4 != 0:
					Audio.ui("bad"); kb.shake_piece(); Game.toast("Не встаёт: деталь развёрнута. Нажмите R, чтобы повернуть", "bad"); return
				bb.pieces[n] = 1; bb.sc.align.append(clamp(1.0 - d / 1.2, 0.0, 1.0)); kb.drop_piece()
				Audio.ui("thud"); Game.mark()
				get_tree().create_timer(0.4).timeout.connect(func(): _setup_piece(); kb.sync(b()); status_changed.emit())
				status_changed.emit()
		"stab":
			var i: int = inf.get("i", -1)
			if _stab_ok(i):
				bb.stabs[str(i)] = 1; kb.ghost_at(-1); Audio.socket(true); resync()
			elif i >= 0 and not (i in Game.stab_targets(bb.layout)):
				Game.toast("Сюда стаб не нужен: только под подсвеченные длинные клавиши")
		"solder":
			_hold = false; _cur = -1; kb.set_smoke(false)
		"screw": _fin_screw()

func alt(inf: Dictionary) -> void:
	match step():
		"sw": _pull_sw(inf.i)
		"kc": _pull_cap(inf.i)

func rotate_piece() -> void:
	var bb := b(); var n := _cur_piece(); if n == "": return
	bb.prot[n] = (int(bb.prot.get(n, 0)) + 1) % 4
	kb.float_piece(n, int(bb.prot[n]), true); Audio.ui("tick"); status_changed.emit()

func _process(delta: float) -> void:
	var bb := b(); if bb.is_empty() or kb == null: return
	match step():
		"solder":
			if not _hold or _cur < 0: return
			var k: Dictionary = bb.ks[_cur]
			if int(k.s) == 0 or float(k.so) >= 1.0: return
			k.so = min(1.0, float(k.so) + delta / (0.22 / (1.0 + 0.5 * Game.upl("solder"))))
			_snd -= delta
			if _snd <= 0: _snd = 0.14; Audio.ui("sizzle")
			if float(k.so) >= 1.0: resync()
		"screw":
			if _scr < 0: return
			_tq_t += delta
			_tq = _tq_base + _tq_t / torque_zone().rate
			kb.screw_turn(_scr, _tq); torque.emit(_tq)
			if _tq >= 1.09: _fin_screw()

# ------------------------------------------------------------ stage parts
func _cur_piece() -> String:
	var bb := b()
	for n in piece_queue(bb):
		if not bb.pieces.has(n): return n
	return ""
func _setup_piece() -> void:
	var bb := b(); var n := _cur_piece()
	if n == "": return
	if not bb.prot.has(n): bb.prot[n] = [1, 2, 3][randi() % 3]
	kb.float_piece(n, int(bb.prot[n]))
func _move_piece(inf: Dictionary) -> void:
	var p: Vector3 = kb.plane_point(inf.from, inf.dir, 2.2)
	kb.move_piece_to(p.x, p.z)

func _stab_ok(i: int) -> bool:
	var bb := b()
	return i >= 0 and i in Game.stab_targets(bb.layout) and not bb.stabs.has(str(i))

func _ins_sw(inf: Dictionary) -> void:
	var bb := b(); var i: int = inf.i
	if i < 0: return
	var k: Dictionary = bb.ks[i]
	if int(k.s) == 1: return
	var bl = Game.upl("bench"); var thr: float = 0.8 * (1.0 + 0.35 * min(bl, 2))
	k.s = 1
	var bent: bool = float(inf.get("spd", 0.0)) > thr or randf() < (0.005 if bl >= 2 else 0.01)
	if bent: k.b = 1; bb.bentEver = int(bb.bentEver) + 1; Audio.ui("bad")
	else: Audio.socket(false)
	kb.insert(i, "sw"); resync()
func _pull_sw(i: int) -> void:
	var bb := b(); if i < 0: return
	var k: Dictionary = bb.ks[i]
	if int(k.s) == 0: return
	k.s = 0; k.b = 0; Audio.socket(true); resync()

func _first_row() -> int:
	var bb := b(); var Lk: Array = Data.LAYOUTS[bb.layout].keys
	for r in int(Data.LAYOUTS[bb.layout].rows):
		for i in bb.ks.size():
			if int(bb.ks[i].c) == 0 and int(Lk[i].row) == r: return r
	return 0
func _fix_kit() -> void:
	var bb := b(); var Lk: Array = Data.LAYOUTS[bb.layout].keys
	for i in bb.ks.size():
		if int(bb.ks[i].c) == 0 and int(Lk[i].row) == kit: return
	kit = _first_row()
func _put_cap(i: int) -> void:
	var bb := b(); if i < 0: return
	var k: Dictionary = bb.ks[i]
	if int(k.s) == 0 or int(k.c) == 1: return
	k.c = 1
	var Lk: Array = Data.LAYOUTS[bb.layout].keys
	if kc_sculpted(bb) and int(Lk[i].row) != kit:
		k.w = 1; bb.wrongEver = int(bb.wrongEver) + 1; Audio.ui("bad")
	else: Audio.socket(true)
	kb.insert(i, "cap"); _fix_kit(); resync()
func _pull_cap(i: int) -> void:
	var bb := b(); if i < 0: return
	var k: Dictionary = bb.ks[i]
	if int(k.c) == 0: return
	k.c = 0; k.w = 0; Audio.socket(true); resync()

func _fin_screw() -> void:
	if _scr < 0: return
	var bb := b(); var v := _tq; var z := torque_zone()
	bb.screws[_scr] = v
	if v > z.strip: Audio.ui("bad"); tq_msg = "[color=#ff7a6b]Сорвали резьбу! Винт держит, но качество ниже.[/color]"
	elif v < z.lo: Audio.ui("tick"); tq_msg = "[color=#ffc46e]Недотянули: зажмите этот винт ещё раз.[/color]"
	else:
		Audio.ui("thud")
		tq_msg = "[color=#6be3a0]Идеально![/color]" if v >= z.plo and v <= z.phi else "[color=#6be3a0]Затянуто, но не идеально.[/color]"
	bb.screwSeq.append(_scr); _scr = -1; _tq = 0.0; torque.emit(0.0)
	resync()

# -------------------------------------------------------------- repair
## Applies the selected repair tool to key i; returns true when the action matched the next fix step.
func apply_tool(i: int) -> bool:
	var bb := b(); if bb.is_empty() or i < 0 or i >= bb.ks.size(): return false
	var k: Dictionary = bb.ks[i]
	var f := str(k.get("f", ""))
	if f == "":
		if int(k.get("fx", 0)) == 1: Game.toast("Эта клавиша уже исправлена")
		else: Game.toast("Клавиша в порядке: лишний разбор ни к чему"); bb.mist = int(bb.get("mist", 0)) + 1; Audio.ui("bad")
		status_changed.emit(); return false
	var need := fault_stage(k)
	if tool != need:
		bb.mist = int(bb.get("mist", 0)) + 1; Audio.ui("bad")
		Game.toast("%s. Неверный инструмент: ошибка %d" % [TOOL_HINT[need], int(bb.mist)], "bad")
		status_changed.emit(); return false
	match tool:
		"cap_pull": k.c = 0; Audio.socket(true)
		"sw_pull": k.s = 0; Audio.socket(true)
		"sw_new": k.s = 1; Audio.socket(false); kb.insert(i, "sw")
		"cap_put", "cap_new": k.c = 1; Audio.socket(true); kb.insert(i, "cap")
		"clean", "stablube": Audio.ui("lube")
		"iron": Audio.ui("sizzle")
	k.fs = int(k.get("fs", 0)) + 1
	if int(k.fs) >= (FAULTS[f].seq as Array).size():
		k.f = ""; k.fx = 1; bb.fixes = int(bb.fixes) + 1
		Audio.ui("good"); Game.toast("Исправлено: %s" % FAULTS[f].n.to_lower(), "good")
	resync()
	return true

## Diagnosis press: marks the key tested, reveals its fault. Returns the fault id ("" when healthy).
func diag(i: int) -> String:
	var bb := b(); if bb.is_empty() or i < 0 or i >= bb.ks.size(): return ""
	var k: Dictionary = bb.ks[i]
	k.t = 1
	var f := str(k.get("f", ""))
	if f != "" and int(k.get("seen", 0)) == 0:
		k.seen = 1
		Game.toast("Найдено: %s (%s)" % [FAULTS[f].n, FAULTS[f].why], "bad")
	kb.sync(bb); status_changed.emit()
	return f

# -------------------------------------------------------------- keytest
## Returns true when the key should sound.
func keytest(i: int) -> bool:
	var bb := b(); if bb.is_empty() or i < 0 or i >= bb.ks.size(): return false
	var k: Dictionary = bb.ks[i]
	if int(k.d) == 1:
		k.d = 0; k.b = 0; k.so = 1.0; bb.fixes = int(bb.fixes) + 1; k.t = 1
		Audio.ui("good"); Game.toast("Починено: свитч переставлен, контакт пропаян"); resync(); return false
	k.t = 1
	if is_dead(bb, k):
		k.d = 1; resync(); Audio.ui("bad"); return false
	kb.sync(bb); status_changed.emit()
	return true

func autotest() -> void:
	var bb := b()
	for i in bb.ks.size():
		get_tree().create_timer(i * 0.018).timeout.connect(func():
			if Game.S.build == null or not (step() in ["keytest", "diag"]): return
			var k: Dictionary = bb.ks[i]
			if step() == "diag":
				k.t = 1
				if str(k.get("f", "")) != "": k.seen = 1
			elif int(k.t) == 0:
				k.t = 1
				if is_dead(bb, k): k.d = 1
			kb.press(i, true)
			get_tree().create_timer(0.07).timeout.connect(func(): kb.press(i, false))
			if i % 3 == 0: Audio.ui("tick")
			kb.sync(bb)
			if i == bb.ks.size() - 1: status_changed.emit(); Game.mark())
