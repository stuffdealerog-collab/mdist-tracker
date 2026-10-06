class_name Pack
extends Node3D
## Packing a keyboard for the courier on the packing table: fold the box (our branded mailer for
## sales and orders, plain kraft for repairs), foam insert, keyboard, cable and puller, close the lid,
## run the tape gun along the seam, print the label and stick it on. Same drag/click rules as Unbox.

signal hint_changed(text: String, progress: float)
signal finished(parcel: Dictionary)

var ship: Dictionary
var cam: Camera3D
var spec: Dictionary = {}
var brand = true
var W = 0.48
var D = 0.2
var H = 0.075
var box: Node3D
var lid: Node3D
var kb: Keyboard3D
var tape_strip: MeshInstance3D
var label_n: MeshInstance3D
const PRINTER := Home.PACK_SPOT + Vector3(0.22, 0.07, 0.16)   # label printer on the table (world)
var stages = []
var si = 0
var prog = 0.0
var _drag = false
var _snd_mark = 0.0
var _done = false

func setup(s: Dictionary, camera: Camera3D) -> Pack:
	ship = s; cam = camera; brand = bool(s.get("brand", true))
	if s.has("buid"):
		var b = Game.find_board(s.buid)
		if not b.is_empty(): spec = b
	if spec.is_empty(): spec = s.get("spec", {"layout": "l65", "case": "c_abs", "color": 0, "plate": "p_fr4", "pcb": "b_hs", "stab": "s_basic", "kc": "k_stock", "sw": "sw_red", "mods": {}})
	var L: Dictionary = Data.LAYOUTS[spec.layout]
	W = float(L.W) * 0.01905 + 0.07; D = float(L.H) * 0.01905 + 0.07
	return self

func _mi(mesh: Mesh, mat: Material, pos: Vector3, parent: Node3D) -> MeshInstance3D:
	var m = MeshInstance3D.new(); m.mesh = mesh; m.material_override = mat; m.position = pos; parent.add_child(m); return m
func _bm(s: Vector3) -> BoxMesh:
	var b = BoxMesh.new(); b.size = s; return b

func _ready() -> void:
	var mat: Material = HMats.brand_box(Color("16181b")) if brand else HMats.cardboard()
	box = Node3D.new(); add_child(box)
	var t = 0.004
	_mi(_bm(Vector3(W, t, D)), mat, Vector3(0, t / 2.0, 0), box)
	_mi(_bm(Vector3(W, H, t)), mat, Vector3(0, H / 2.0, D / 2.0), box)
	_mi(_bm(Vector3(W, H, t)), mat, Vector3(0, H / 2.0, -D / 2.0), box)
	_mi(_bm(Vector3(t, H, D)), mat, Vector3(W / 2.0, H / 2.0, 0), box)
	_mi(_bm(Vector3(t, H, D)), mat, Vector3(-W / 2.0, H / 2.0, 0), box)
	box.scale = Vector3(1.0, 0.04, 1.0)
	lid = Node3D.new(); lid.position = Vector3(0, H, -D / 2.0); box.add_child(lid)
	_mi(_bm(Vector3(W + 0.004, t, D + 0.004)), mat, Vector3(0, t / 2.0, D / 2.0), lid)
	if brand:
		var nm = Label3D.new(); nm.text = _brand_name(); nm.font = load("res://assets/fonts/Tektur.ttf"); nm.font_size = 96; nm.pixel_size = 0.0005
		nm.modulate = Color("e9e4da"); nm.rotation_degrees = Vector3(-90, 0, 0); nm.position = Vector3(0, t + 0.0008, D / 2.0); nm.outline_size = 0; lid.add_child(nm)
		_mi(_bm(Vector3(W * 0.6, 0.0006, 0.004)), Mats.emissive(Color("4cb8ab"), 0.4), Vector3(0, t + 0.0008, D / 2.0 + 0.03), lid)
	lid.rotation.x = deg_to_rad(-110)
	_plan(); _emit()

func _brand_name() -> String:
	var b: String = str(Game.S.home.get("brand", ""))
	if b == "": b = str(Game.S.shop).replace("Мастерская ", "").replace("«", "").replace("»", "")
	return b

func _plan() -> void:
	stages = [
		{"kind": "click", "text": "Соберите коробку" + (" с вашим брендом" if brand else ""), "at": Vector3(0, 0.01, 0), "on": func(): _fold_up()},
		{"kind": "click", "text": "Положите вкладыш из пены", "at": Vector3(0, H * 0.5, 0), "on": func(): _foam()},
		{"kind": "click", "text": "Уложите клавиатуру в коробку", "at": Vector3(0, H * 0.5, 0), "on": func(): _keyboard()},
		{"kind": "click", "text": "Добавьте кабель и съёмник кейкапов", "at": Vector3(0, H * 0.6, 0), "on": func(): _extras()},
		{"kind": "click", "text": "Закройте крышку", "at": Vector3(0, H, 0), "on": func(): _close()},
		{"kind": "drag", "text": "Заклейте шов скотчем: ведите пистолет вдоль коробки", "a": Vector3(-W / 2.0, H, D / 2.0), "b": Vector3(W / 2.0, H, D / 2.0),
			"snd": "tape_seal", "every": 0.34, "prog": func(t): _tape(t)},
		{"kind": "click", "text": "Напечатайте этикетку на принтере", "at": PRINTER, "abs": true, "on": func(): _print()},
		{"kind": "click", "text": "Наклейте этикетку на коробку", "at": Vector3(0, H, 0), "on": func(): _stick()},
	]

# ------------------------------------------------------------------ steps
func _fold_up() -> void:
	create_tween().tween_property(box, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Audio.sfx("flaps", global_position); get_tree().create_timer(0.25).timeout.connect(func(): Audio.sfx("flaps", global_position, -4.0))

func _foam() -> void:
	var f = _mi(_bm(Vector3(W - 0.012, 0.022, D - 0.012)), HMats.foam(Color("1d1f22") if brand else Color("f2f2ee")), Vector3(0, 0.25, 0), box)
	var well = _mi(_bm(Vector3(W - 0.05, 0.002, D - 0.05)), Mats.std(Color("0c0d0f") if brand else Color("d8d8d2"), 0.9), Vector3(0, 0.25, 0), box)
	var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(f, "position:y", 0.015, 0.4); tw.tween_property(well, "position:y", 0.0265, 0.4)
	Audio.sfx("foam", global_position)

func _keyboard() -> void:
	kb = Keyboard3D.new(); kb.scale = Vector3.ONE * 0.01905; box.add_child(kb)
	kb.show_spec(spec, null)
	kb.position = Vector3(0, 0.3, 0)
	create_tween().tween_property(kb, "position:y", 0.022, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	get_tree().create_timer(0.55).timeout.connect(func(): Audio.sfx("box_down", global_position, -3.0))

func _extras() -> void:
	var cable = _mi(TorusMesh.new(), Mats.std(Color("e9e4da") if brand else Color("1d1f22"), 0.5), Vector3(W / 2.0 - 0.04, 0.3, -D / 2.0 + 0.035), box)
	cable.scale = Vector3(0.05, 0.08, 0.05)
	var puller = _mi(_bm(Vector3(0.05, 0.008, 0.02)), Mats.std(Color("d9423b"), 0.5), Vector3(-W / 2.0 + 0.04, 0.3, -D / 2.0 + 0.03), box)
	var tw = create_tween().set_parallel(true)
	tw.tween_property(cable, "position:y", 0.045, 0.4); tw.tween_property(puller, "position:y", 0.045, 0.45)
	Audio.sfx("bag", global_position)

func _close() -> void:
	create_tween().tween_property(lid, "rotation:x", 0.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	get_tree().create_timer(0.35).timeout.connect(func(): Audio.sfx("flaps", global_position))

func _tape(t: float) -> void:
	if tape_strip == null:
		tape_strip = _mi(_bm(Vector3(0.001, H * 0.5, 0.0012)), HMats.tape(brand), Vector3(-W / 2.0, H * 0.75, D / 2.0 + 0.0026), box)
	tape_strip.scale.x = max(0.001, t * W / 0.001)
	tape_strip.position.x = -W / 2.0 + t * W / 2.0

func _print() -> void:
	Audio.sfx("label_print", PRINTER)
	label_n = _mi(_bm(Vector3(0.1, 0.0008, 0.062)), HMats.label(hash(str(ship.id))), to_local(PRINTER + Vector3(0, 0.015, 0)), self)
	label_n.scale = Vector3(1, 1, 0.01)
	create_tween().tween_property(label_n, "scale", Vector3.ONE, 1.4)

func _stick() -> void:
	if label_n == null: return
	var tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(label_n, "position", box.position + Vector3(W * 0.22, H + 0.0055, -D * 0.12), 0.45)
	tw.parallel().tween_property(label_n, "rotation:y", 0.04, 0.45)
	Audio.sfx("tape_pull", global_position, -4.0)
	get_tree().create_timer(0.6).timeout.connect(_finish)

func _finish() -> void:
	if _done: return
	_done = true
	var p = Game.pack_shipment(str(ship.id))
	Audio.ui("good")
	finished.emit(p)

# ------------------------------------------------------------------ input (same rules as Unbox)
func _emit() -> void:
	if si >= stages.size(): return
	var st: Dictionary = stages[si]
	hint_changed.emit(st.text, prog if st.kind == "drag" else -1.0)

func _next() -> void:
	si += 1; prog = 0.0; _drag = false; _snd_mark = 0.0
	if si < stages.size(): get_tree().create_timer(0.15).timeout.connect(_emit)

func _w(p: Vector3) -> Vector3: return global_transform * p

func _proj(st: Dictionary, mouse: Vector2) -> float:
	var a = cam.unproject_position(_w(st.a)); var b = cam.unproject_position(_w(st.b))
	var ab = b - a
	if ab.length_squared() < 4.0: return 0.0
	return (mouse - a).dot(ab) / ab.length_squared()

func handle_input(ev: InputEvent) -> bool:
	if si >= stages.size() or _done: return false
	var st: Dictionary = stages[si]
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb = ev as InputEventMouseButton
		if st.kind == "click" and mb.pressed:
			var at: Vector3 = st.at if st.get("abs", false) else _w(st.at)
			if cam.unproject_position(at).distance_to(mb.position) > 280.0: return true
			(st.on as Callable).call(); _next(); return true
		if st.kind == "drag":
			if mb.pressed:
				if _proj(st, mb.position) <= prog + 0.3:
					_drag = true
					if prog == 0.0: Audio.sfx(str(st.snd), global_position)
			else: _drag = false
			return true
	if ev is InputEventMouseMotion and st.kind == "drag" and _drag:
		var t: float = clamp(_proj(st, (ev as InputEventMouseMotion).position), 0.0, 1.0)
		if t > prog:
			prog = min(t, prog + 0.12); (st.prog as Callable).call(prog)
			if prog - _snd_mark >= float(st.every):
				_snd_mark = prog; Audio.sfx(str(st.snd), global_position, -1.0)
			hint_changed.emit(st.text, prog)
			if prog >= 0.97:
				(st.prog as Callable).call(1.0); _drag = false; _next()
		return true
	return false

func auto_step() -> void:
	if si >= stages.size() or _done: return
	var st: Dictionary = stages[si]
	if st.kind == "click": (st.on as Callable).call()
	else: (st.prog as Callable).call(1.0)
	_next()
