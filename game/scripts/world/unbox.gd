class_name Unbox
extends Node3D
## Hands-on unboxing on the workbench (the ASMR part). Every parcel is opened like in real life:
## slit the tape with a knife, open the flaps, pull out the filler, then each item in its own packaging:
##  case  → retail box, foam top, case in a poly sleeve      plate → white box, peel the protective film
##  pcb   → anti-static bag: tear the notch, slide the board  keycaps → box lid, lift the tray
##  switches / stabs → zip bag                                 client keyboard → bubble wrap
## Stages are "drag" (move the mouse along a path) or "click" (press on the object).

signal hint_changed(text: String, progress: float)
signal finished(got: Array)

var parcel: Dictionary
var cam: Camera3D
var size = Vector3(0.4, 0.12, 0.2)
var box: Node3D
var flaps = []                  # pivots: front, back, right, left
var slit: MeshInstance3D
var knife: Node3D
var stages = []
var si = 0
var prog = 0.0
var _drag = false
var _snd_mark = 0.0
var _clicks = 0
var _cur_pkg: Node3D = null
var _done = false
var _lift_y = 0.0
static var _holes: Texture2D

func setup(p: Dictionary, camera: Camera3D) -> Unbox:
	parcel = p; cam = camera
	var s = p.get("size", Vector3(0.4, 0.12, 0.2))
	size = s if s is Vector3 else Parcel3D._vec(s)
	return self

var pkgs := []                   # packages pre-built inside the box, lifted one by one

func _ready() -> void:
	_build_box()
	# goods lie in the box under the filler from the start
	var y = 0.006
	for it in parcel.items:
		var d = _package(it)
		(d.node as Node3D).position = Vector3(0, y, 0)
		(d.node as Node3D).set_meta("d", d)
		y += float(d.get("h", 0.03)) * 0.85
		pkgs.append(d.node)
	_plan()
	_emit()

# ------------------------------------------------------------------ geometry
func _mi(mesh: Mesh, mat: Material, pos: Vector3, parent: Node3D) -> MeshInstance3D:
	var m = MeshInstance3D.new(); m.mesh = mesh; m.material_override = mat; m.position = pos; parent.add_child(m); return m
func _bm(s: Vector3) -> BoxMesh:
	var b = BoxMesh.new(); b.size = s; return b

func _build_box() -> void:
	box = Node3D.new(); add_child(box)
	var t = 0.004; var cm = HMats.cardboard()
	var sx = size.x; var sy = size.y; var sz = size.z
	_mi(_bm(Vector3(sx, t, sz)), cm, Vector3(0, t / 2.0, 0), box)
	_mi(_bm(Vector3(sx, sy, t)), cm, Vector3(0, sy / 2.0, sz / 2.0 - t / 2.0), box)
	_mi(_bm(Vector3(sx, sy, t)), cm, Vector3(0, sy / 2.0, -sz / 2.0 + t / 2.0), box)
	_mi(_bm(Vector3(t, sy, sz)), cm, Vector3(sx / 2.0 - t / 2.0, sy / 2.0, 0), box)
	_mi(_bm(Vector3(t, sy, sz)), cm, Vector3(-sx / 2.0 + t / 2.0, sy / 2.0, 0), box)
	# inside is a little darker (unprinted side)
	_mi(_bm(Vector3(sx - 2 * t, 0.001, sz - 2 * t)), HMats.cardboard(Color(0.85, 0.82, 0.78)), Vector3(0, t + 0.0005, 0), box)
	# flaps: majors on top (front/back), minors below (left/right)
	var tw: float = min(0.05, sz * 0.3)
	for i in 4:
		var pv = Node3D.new(); box.add_child(pv)
		var major = i < 2
		var sgn = 1.0 if i % 2 == 0 else -1.0
		if major:
			pv.position = Vector3(0, sy, sgn * sz / 2.0)
			_mi(_bm(Vector3(sx, t, sz / 2.0)), cm, Vector3(0, t / 2.0 + 0.0015, -sgn * sz / 4.0), pv)
			# half of the seam tape rides on each major flap
			_mi(_bm(Vector3(sx + 0.002, 0.0012, tw / 2.0)), HMats.tape(), Vector3(0, t + 0.0022, -sgn * (sz / 2.0 - tw / 4.0)), pv)
		else:
			pv.position = Vector3(sgn * sx / 2.0, sy, 0)
			_mi(_bm(Vector3(min(sz / 2.0, sx / 2.0), t, sz - 0.01)), cm, Vector3(-sgn * min(sz / 4.0, sx / 4.0), t / 2.0 - 0.0005, 0), pv)
		flaps.append(pv)
	# tape tabs down both ends
	for sxs in [-1, 1]:
		_mi(_bm(Vector3(0.0012, sy * 0.55, tw)), HMats.tape(), Vector3(sxs * (sx / 2.0 + 0.0006), sy * 0.72, 0), box).name = "tab%d" % sxs
	var lw: float = min(0.12, sx * 0.35)
	var lab = _mi(_bm(Vector3(lw, 0.0008, lw * 0.62)), HMats.label(hash(str(parcel.id))), Vector3(-sx * 0.22, t + 0.0026, -(sz / 4.0) + 0.01), flaps[1])
	lab.rotation.y = PI
	slit = _mi(_bm(Vector3(0.001, 0.0016, 0.0016)), Mats.std(Color("2a1a0c"), 0.8), Vector3(-sx / 2.0, sy + t + 0.0024, 0), box)
	slit.visible = false
	# filler on top of the goods
	var fill = Node3D.new(); fill.name = "filler"; box.add_child(fill)
	var bubble: bool = parcel.kind == "client" or hash(str(parcel.id)) % 2 == 0
	if bubble:
		_mi(_bm(Vector3(sx * 0.9, 0.012, sz * 0.85)), HMats.bubble_wrap(), Vector3(0, sy - 0.012, 0), fill)
	else:
		var km = HMats.cardboard(Color(1.15, 1.1, 1.05))
		for i in 5:
			var sp = SphereMesh.new(); sp.radius = sz * 0.22; sp.height = sz * 0.22
			var m = _mi(sp, km, Vector3(-sx * 0.36 + i * sx * 0.18, sy - sz * 0.1, randf_range(-sz * 0.15, sz * 0.15)), fill)
			m.rotation = Vector3(randf(), randf() * 3.0, randf()); m.scale = Vector3(1.0, 0.6, 0.8)
	fill.set_meta("bubble", bubble)
	knife = Node3D.new(); add_child(knife); knife.visible = false
	_mi(_bm(Vector3(0.012, 0.012, 0.09)), Mats.std(Color("e7c33e"), 0.45), Vector3(0, 0.02, 0.05), knife)
	_mi(_bm(Vector3(0.002, 0.018, 0.03)), Mats.std(Color("c9ccd0"), 0.2, 0.95), Vector3(0, 0.006, -0.01), knife)
	knife.rotation_degrees = Vector3(-25, 0, 0)

static func holes_tex() -> Texture2D:
	if _holes: return _holes
	var w = 300; var h = 100
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8); img.fill(Color.WHITE)
	for r in 5:
		for c in 15:
			img.fill_rect(Rect2i(4 + c * 19 + (r % 2) * 3, 4 + r * 19, 13, 13), Color(1, 1, 1, 0))
	img.generate_mipmaps()
	_holes = ImageTexture.create_from_image(img); return _holes

# ------------------------------------------------------------------ packages
## Builds the retail packaging for one item; returns {node, parts...}.
## The brand artwork (data/packaging.json + assets/tex/pack) on a face of an unboxing package: a quad facing up.
func _print_quad(parent: Node3D, w: float, d: float, y: float, it: Dictionary, kind: String) -> void:
	var pk = ItemBox.pack_of(str(it.id))
	var q = MeshInstance3D.new(); var qm = QuadMesh.new(); qm.size = Vector2(w, d); q.mesh = qm
	q.rotation_degrees = Vector3(-90, 0, 0); q.position = Vector3(0, y, 0)
	q.material_override = ItemBox.print_mat(pk.art, kind); parent.add_child(q)

func _package(it: Dictionary) -> Dictionary:
	var root = Node3D.new(); box.add_child(root)
	var cat: String = it.cat
	var d = {"node": root, "cat": cat, "it": it}
	match cat:
		"case", "kb":
			var lay: String = it.get("layout", "l65")
			var W = float(Data.LAYOUTS[lay].W) * 0.01905 + 0.03; var D = float(Data.LAYOUTS[lay].H) * 0.01905 + 0.03
			W = min(W, size.x - 0.03); D = min(D, size.z - 0.03)
			var bx = _mi(MeshGen.rounded_box(W, 0.055, D, 0.003, 1), HMats.brand_box(Color("1c1e22")), Vector3.ZERO, root)
			var lid = Node3D.new(); root.add_child(lid); lid.position.y = 0.055
			var art: String = ItemBox.pack_of(str(it.id)).art
			var side_c: Color = ItemBox.BRAND.get(art, [Color("26292e")])[0]
			_mi(MeshGen.rounded_box(W + 0.006, 0.03, D + 0.006, 0.003, 1), Mats.std(side_c, 0.55), Vector3(0, -0.027, 0), lid)
			_print_quad(lid, W + 0.002, D + 0.002, 0.0032, it, "case_box")
			var foam = _mi(_bm(Vector3(W - 0.01, 0.012, D - 0.01)), HMats.foam(), Vector3(0, 0.046, 0), root)
			var cs = Data.case_(it.id)
			var bag = _mi(MeshGen.rounded_box(W - 0.014, 0.034, D - 0.014, 0.006, 1), HMats.poly_bag(), Vector3(0, 0.006, 0), root)
			var case_m = _mi(MeshGen.rounded_box(W - 0.024, 0.026, D - 0.024, 0.004, 2), Mats.case_mat(it.id, int(it.get("color", 0))), Vector3(0, 0.008, 0), root)
			var well = _mi(_bm(Vector3(W - 0.05, 0.002, D - 0.05)), Mats.std(Color("0d0e10"), 0.8), Vector3(0, 0.0345, 0), root)
			d.merge({"lid": lid, "foam": foam, "bag": bag, "h": 0.085})
		"plate":
			var W2: float = min(size.x - 0.04, 0.32); var D2: float = min(size.z - 0.03, 0.12)
			_mi(MeshGen.rounded_box(W2, 0.016, D2, 0.002, 1), Mats.std(Color("f2f1ec"), 0.6), Vector3.ZERO, root)
			var lid2 = Node3D.new(); lid2.position.y = 0.016; root.add_child(lid2)
			_mi(_bm(Vector3(W2 + 0.004, 0.004, D2 + 0.004)), Mats.std(Color("f7f6f2"), 0.55), Vector3(0, 0.002, 0), lid2)
			_print_quad(lid2, W2 * 0.6, D2 * 0.64, 0.0042, it, "plate_sleeve")
			var pm = Mats.plate_mat(str(it.id), holes_tex())
			var plate = _mi(_bm(Vector3(W2 - 0.02, 0.0016, D2 - 0.02)), pm, Vector3(0, 0.012, 0), root)
			var film = Node3D.new(); film.position = Vector3((W2 - 0.02) / 2.0, 0.0138, 0); root.add_child(film)
			_mi(_bm(Vector3(W2 - 0.018, 0.0006, D2 - 0.018)), HMats.peel_film(), Vector3(-(W2 - 0.018) / 2.0, 0, 0), film)
			d.merge({"lid": lid2, "film": film, "w": W2, "h": 0.02})
		"pcb":
			var W3: float = min(size.x - 0.04, 0.3); var D3: float = min(size.z - 0.03, 0.12)
			var bag3 = _mi(MeshGen.rounded_box(W3, 0.01, D3, 0.004, 1), HMats.esd_bag(), Vector3.ZERO, root)
			var strip = _mi(_bm(Vector3(W3, 0.011, 0.014)), HMats.esd_bag(), Vector3(0, 0.0, D3 / 2.0 - 0.007), root)
			var pcb = _mi(_bm(Vector3(W3 - 0.03, 0.0016, D3 - 0.03)), Mats.std(Color("1f4a2c") if not Data.pcb(it.id).get("rgb", false) else Color("15171a"), 0.45), Vector3(0, 0.005, 0), root)
			d.merge({"bag": bag3, "strip": strip, "pcb": pcb, "d": D3, "h": 0.012})
		"kc":
			var W4: float = min(size.x - 0.03, 0.32); var D4: float = min(size.z - 0.03, 0.14)
			_mi(MeshGen.rounded_box(W4, 0.05, D4, 0.003, 1), Mats.std(Color("f4f2ec"), 0.55), Vector3.ZERO, root)
			var lid4 = Node3D.new(); lid4.position.y = 0.05; root.add_child(lid4)
			var art4: String = ItemBox.pack_of(str(it.id)).art
			_mi(MeshGen.rounded_box(W4 + 0.006, 0.022, D4 + 0.006, 0.003, 1), Mats.std(ItemBox.BRAND.get(art4, [Color("f4f2ec")])[0], 0.5), Vector3(0, -0.02, 0), lid4)
			_print_quad(lid4, W4 + 0.002, D4 + 0.002, 0.0012, it, "keycap_box")
			var tray = Node3D.new(); tray.position.y = 0.03; root.add_child(tray)
			_mi(_bm(Vector3(W4 - 0.008, 0.004, D4 - 0.008)), Mats.std(Color("1d1f22"), 0.5), Vector3.ZERO, tray)
			var k: Dictionary = Data.kc(it.id); var prof: String = k.prof
			var cap = KbParts.cap(1.0, prof, 2)
			var cols = ["a", "a", "a", "m", "a", "a", "x", "a", "a", "m"]
			for r in 3:
				for c in 10:
					var m = MeshInstance3D.new(); m.mesh = cap; m.scale = Vector3.ONE * 0.01905 * 0.8
					m.set_surface_override_material(0, Mats.cap_side()); m.set_surface_override_material(1, Mats.cap_top())
					var cc: Array = Keyboard3D.cap_colors(it.id, cols[(c + r * 3) % cols.size()])
					m.set_instance_shader_parameter("base_color", cc[0]); m.set_instance_shader_parameter("rough", 0.45)
					m.position = Vector3(-W4 / 2.0 + 0.022 + c * (W4 - 0.04) / 9.0, 0.002, -D4 / 2.0 + 0.025 + r * (D4 - 0.05) / 2.0)
					tray.add_child(m)
			d.merge({"lid": lid4, "tray": tray, "h": 0.07})
		"sw", "stab", "cons", "art":
			var W5 = 0.14 if cat != "sw" else 0.17; var D5 = 0.1
			var bag5 = _mi(MeshGen.rounded_box(W5, 0.022, D5, 0.008, 1), HMats.poly_bag(), Vector3.ZERO, root)
			var zip = _mi(_bm(Vector3(W5, 0.024, 0.006)), Mats.std(Color(0.9, 0.3, 0.3, 0.6) if cat == "sw" else Color(0.9, 0.9, 0.95, 0.6), 0.3), Vector3(0, 0.0, D5 / 2.0 - 0.012), root)
			if cat == "sw":
				var s = Data.sw(it.id)
				var st = Node3D.new(); root.add_child(st); st.position = Vector3(0.035, 0.0, -0.01)
				_print_quad(st, 0.06, 0.06, 0.0115, it, "switch_bag")
				for i in 14:
					var b = _mi(_bm(Vector3(0.015, 0.012, 0.015)), Mats.std(Color(s.hous), 0.4), Vector3(randf_range(-0.06, 0.06), 0.007, randf_range(-0.035, 0.03)), root)
					b.rotation.y = randf() * PI
					_mi(_bm(Vector3(0.005, 0.004, 0.005)), Mats.std(Color(s.stem), 0.5), b.position + Vector3(0, 0.007, 0), root)
			elif cat == "art":
				var a = Data.art(it.id)
				_mi(SphereMesh.new(), Mats.resin(Keyboard3D.art_color(a)), Vector3(0, 0.01, 0), root).scale = Vector3.ONE * 0.02
			else:
				_mi(_bm(Vector3(0.04, 0.012, 0.03)), Mats.std(Color("1d1f22"), 0.5), Vector3(0, 0.007, 0), root)
			d.merge({"bag": bag5, "zip": zip, "h": 0.03})
		"client":
			var o = {}
			for x in Game.S.orders: if x.id == str(it.get("oid", "")): o = x
			var spec: Dictionary = o.get("board", {"layout": "l60", "case": "c_abs", "color": 0, "plate": "p_fr4", "pcb": "b_hs", "stab": "s_basic", "kc": "k_stock", "sw": "sw_red", "mods": {}})
			var kb = Keyboard3D.new(); kb.scale = Vector3.ONE * 0.01905; root.add_child(kb); kb.show_spec(spec, null)
			var L: Dictionary = Data.LAYOUTS[spec.layout]
			var W6: float = float(L.W) * 0.01905 + 0.04; var D6: float = float(L.H) * 0.01905 + 0.04
			var wraps = []
			for i in 3:
				var w = _mi(MeshGen.rounded_box(W6 + i * 0.008, 0.045 + i * 0.006, D6 + i * 0.008, 0.012, 1), HMats.bubble_wrap(), Vector3(0, -0.004 - i * 0.003, 0), root)
				wraps.append(w)
			d.merge({"wraps": wraps, "h": 0.06})
	return d

# ------------------------------------------------------------------ stage plan
func _plan() -> void:
	var sx = size.x; var sy = size.y
	var top = global_position + Vector3(0, sy + 0.01, 0)
	stages.append({"kind": "drag", "text": "Проведите ножом по скотчу от края до края", "a": Vector3(-sx / 2.0, sy, 0), "b": Vector3(sx / 2.0, sy, 0),
		"snd": "knife_cut", "every": 0.22, "tool": "knife", "prog": func(t): _slit(t), "done": func(): _tape_done()})
	stages.append({"kind": "click", "text": "Откройте клапаны коробки (4)", "n": 4, "at": Vector3(0, sy, 0), "on": func(i): _open_flap(i)})
	var bubble: bool = box.get_node("filler").get_meta("bubble")
	stages.append({"kind": "click", "text": "Достаньте пупырчатую плёнку" if bubble else "Вытащите бумажный наполнитель", "n": 1, "at": Vector3(0, sy - 0.01, 0),
		"on": func(_i): _remove_filler(bubble)})
	for it in parcel.items:
		var cat: String = it.cat
		stages.append({"kind": "click", "text": _lift_text(it), "n": 1, "at": Vector3(0, sy * 0.5, 0), "on": func(_i): _lift(it), "pkg": it})
		match cat:
			"case":
				stages.append({"kind": "click", "text": "Снимите крышку коробки", "n": 1, "lift": true, "on": func(_i): _lid_off("tray")})
				stages.append({"kind": "click", "text": "Уберите верхний вкладыш из пены", "n": 1, "lift": true, "on": func(_i): _foam_off()})
				stages.append({"kind": "drag", "text": "Стяните пакет с корпуса (ведите мышь к себе)", "a": Vector3(0, 0, -0.06), "b": Vector3(0, 0, 0.12), "lift": true,
					"snd": "bag", "every": 0.34, "prog": func(t): _bag_slide(t), "done": func(): _reveal()})
			"plate":
				stages.append({"kind": "click", "text": "Откройте коробку", "n": 1, "lift": true, "on": func(_i): _lid_off("flaps")})
				stages.append({"kind": "drag", "text": "Снимите защитную плёнку: тяните за уголок через всю пластину", "a": Vector3(0.15, 0, 0), "b": Vector3(-0.15, 0, 0), "lift": true,
					"snd": "film_peel", "every": 0.45, "prog": func(t): _peel(t), "done": func(): _reveal()})
			"pcb":
				stages.append({"kind": "drag", "text": "Надорвите антистатический пакет по насечке", "a": Vector3(-0.14, 0, 0.05), "b": Vector3(0.14, 0, 0.05), "lift": true,
					"snd": "esd_bag", "every": 0.5, "prog": func(t): _tear(t), "done": func(): pass})
				stages.append({"kind": "drag", "text": "Выньте плату из пакета (ведите мышь к себе)", "a": Vector3(0, 0, -0.02), "b": Vector3(0, 0, 0.14), "lift": true,
					"snd": "esd_bag", "every": 0.6, "prog": func(t): _pcb_slide(t), "done": func(): _reveal()})
			"kc":
				stages.append({"kind": "click", "text": "Снимите крышку набора кейкапов", "n": 1, "lift": true, "on": func(_i): _lid_off("tray")})
				stages.append({"kind": "click", "text": "Приподнимите лоток с кейкапами", "n": 1, "lift": true, "on": func(_i): _tray_up()})
			"sw", "stab", "cons", "art":
				stages.append({"kind": "drag", "text": "Откройте зип-пакет", "a": Vector3(-0.07, 0, 0.04), "b": Vector3(0.07, 0, 0.04), "lift": true,
					"snd": "zip", "every": 0.9, "prog": func(t): _zip(t), "done": func(): pass})
				stages.append({"kind": "click", "text": "Встряхните пакет и проверьте содержимое" if cat == "sw" else "Достаньте содержимое", "n": 1, "lift": true, "on": func(_i): _shake()})
			"client":
				stages.append({"kind": "click", "text": "Снимите пупырчатую плёнку (3 слоя)", "n": 3, "lift": true, "on": func(i): _unwrap(i)})
		stages.append({"kind": "auto", "on": func(): _stow()})
	stages.append({"kind": "click", "text": "Сложите пустую коробку", "n": 1, "at": Vector3(0, sy * 0.5, 0), "on": func(_i): _fold()})

func _lift_text(it: Dictionary) -> String:
	match str(it.cat):
		"client": return "Достаньте клавиатуру клиента"
		"case": return "Достаньте коробку с корпусом"
		"plate": return "Достаньте коробку с пластиной"
		"pcb": return "Достаньте плату в антистатическом пакете"
		"kc": return "Достаньте набор кейкапов"
		"sw": return "Достаньте пакет со свитчами"
		"stab": return "Достаньте пакетик со стабилизаторами"
		"art": return "Достаньте артизан"
	return "Достаньте покупку"

# ------------------------------------------------------------------ stage visuals
func _slit(t: float) -> void:
	slit.visible = t > 0.0
	slit.scale.x = max(0.001, t * size.x / 0.001)
	slit.position.x = -size.x / 2.0 + t * size.x / 2.0
	var knife_p = Vector3(-size.x / 2.0 + t * size.x, size.y + 0.006, 0.0)
	knife.position = knife_p

func _tape_done() -> void:
	knife.visible = false
	for sxs in [-1, 1]:
		var tab = box.get_node_or_null("tab%d" % sxs)
		if tab: tab.scale.z = 0.5
	Audio.sfx("tape_rip", global_position)

func _open_flap(i: int) -> void:
	slit.visible = false
	var pv: Node3D = flaps[i]
	var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	match i:
		0: tw.tween_property(pv, "rotation:x", deg_to_rad(205), 0.45)
		1: tw.tween_property(pv, "rotation:x", deg_to_rad(-205), 0.45)
		2: tw.tween_property(pv, "rotation:z", deg_to_rad(-200), 0.45)
		3: tw.tween_property(pv, "rotation:z", deg_to_rad(200), 0.45)
	Audio.sfx("flaps", global_position)

func _remove_filler(bubble: bool) -> void:
	var f: Node3D = box.get_node("filler")
	var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(f, "position", Vector3(0.25, 0.22, 0.1), 0.5)
	tw.tween_property(f, "rotation", Vector3(0.4, 0.6, 0.2), 0.5)
	tw.chain().tween_callback(f.queue_free)
	Audio.sfx("bubble" if bubble else "bag", global_position)
	if bubble: get_tree().create_timer(0.25).timeout.connect(func(): Audio.sfx("bubble", global_position, -3.0))
	for it in parcel.items: pass

func _lift(it: Dictionary) -> void:
	_cur_pkg = null
	for n in pkgs:
		if (n.get_meta("d") as Dictionary).it == it: _cur_pkg = n
	if _cur_pkg == null:
		var d = _package(it); _cur_pkg = d.node; _cur_pkg.set_meta("d", d)
	pkgs.erase(_cur_pkg)
	_lift_y = size.y + 0.08
	var tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_cur_pkg, "position", Vector3(0, _lift_y, 0.02), 0.55)
	Audio.sfx("tray" if it.cat != "client" else "bubble", global_position)

func _pkg() -> Dictionary: return _cur_pkg.get_meta("d") if _cur_pkg else {}

func _lid_off(snd: String) -> void:
	var lid: Node3D = _pkg().get("lid")
	if lid == null: return
	var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(lid, "position", lid.position + Vector3(-0.05, 0.12, -0.12), 0.6)
	tw.tween_property(lid, "rotation", Vector3(-0.5, 0.2, 0.1), 0.6)
	tw.chain().tween_property(lid, "scale", Vector3.ONE * 0.001, 0.25)
	Audio.sfx(snd, global_position)

func _foam_off() -> void:
	var f: Node3D = _pkg().get("foam")
	var tw = create_tween().set_parallel(true)
	tw.tween_property(f, "position", f.position + Vector3(0.0, 0.1, -0.15), 0.5).set_trans(Tween.TRANS_CUBIC)
	tw.chain().tween_property(f, "scale", Vector3.ONE * 0.001, 0.2)
	Audio.sfx("foam", global_position)

func _bag_slide(t: float) -> void:
	var b: Node3D = _pkg().get("bag")
	if b: b.position.z = t * 0.2; b.scale = Vector3(1.0, 1.0 + t * 0.2, 1.0 - t * 0.3)

func _peel(t: float) -> void:
	var f: Node3D = _pkg().get("film")
	if f: f.scale.x = max(0.001, 1.0 - t); f.position.y = 0.0138 + t * 0.02; f.rotation.z = -t * 0.6

func _tear(t: float) -> void:
	var s: Node3D = _pkg().get("strip")
	if s: s.scale.x = max(0.001, 1.0 - t); s.position.x = t * 0.15

func _pcb_slide(t: float) -> void:
	var d = _pkg()
	(d.pcb as Node3D).position.z = t * (float(d.d) + 0.02)
	(d.pcb as Node3D).position.y = 0.005 + t * 0.012
	(d.bag as Node3D).position.z = -t * 0.04

func _zip(t: float) -> void:
	var z: Node3D = _pkg().get("zip")
	if z: z.scale.x = max(0.001, 1.0 - t * 0.9)

func _shake() -> void:
	var n = _cur_pkg
	var tw = create_tween()
	for i in 4:
		tw.tween_property(n, "rotation:z", 0.18 if i % 2 == 0 else -0.18, 0.07)
	tw.tween_property(n, "rotation:z", 0.0, 0.08)
	Audio.sfx("bag", global_position)
	if _pkg().cat == "sw": get_tree().create_timer(0.12).timeout.connect(func(): Audio.ui("socket"))
	get_tree().create_timer(0.35).timeout.connect(_reveal)

func _tray_up() -> void:
	var t: Node3D = _pkg().get("tray")
	create_tween().tween_property(t, "position:y", t.position.y + 0.04, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Audio.sfx("plastic_pkg", global_position)
	get_tree().create_timer(0.45).timeout.connect(_reveal)

func _unwrap(i: int) -> void:
	var w: Array = _pkg().get("wraps", [])
	var layer: Node3D = w[w.size() - 1 - i] if i < w.size() else null
	if layer:
		var tw = create_tween().set_parallel(true)
		tw.tween_property(layer, "scale", Vector3(1.2, 0.2, 1.3), 0.35); tw.tween_property(layer, "position", layer.position + Vector3(0.1, 0.1, 0.12), 0.35)
		tw.chain().tween_callback(layer.queue_free)
	Audio.sfx("tape_rip" if i == 0 else "bubble", global_position)
	if i == 2: get_tree().create_timer(0.3).timeout.connect(_reveal)

func _reveal() -> void:
	Audio.ui("good")
	var d = _pkg()
	if d.is_empty(): return
	var nm = "клавиатура клиента"
	if d.cat != "client":
		nm = str(Data.item(d.cat, d.it.id).get("name", d.it.id))
		if d.it.has("n"): nm += " ×%d" % int(d.it.n)
	hint_changed.emit("Распаковано: " + nm, -1.0)

## The unpacked item goes onto the bench next to the box.
func _stow() -> void:
	if _cur_pkg == null: return
	var n = _cur_pkg; _cur_pkg = null
	var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(n, "position", Vector3(-0.35, 0.02, 0.18), 0.5)
	tw.tween_property(n, "scale", Vector3.ONE * 0.6, 0.5)
	tw.chain().tween_property(n, "scale", Vector3.ONE * 0.001, 0.2)
	tw.chain().tween_callback(n.queue_free)
	Audio.sfx("box_down", global_position, -6.0)

func _fold() -> void:
	var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(box, "scale", Vector3(1.1, 0.06, 1.15), 0.35)
	tw.chain().tween_property(box, "position", Vector3(0.6, -0.1, 0.3), 0.35)
	Audio.sfx("card_tear", global_position)
	get_tree().create_timer(0.75).timeout.connect(_finish)

func _finish() -> void:
	if _done: return
	_done = true
	var got = Game.unbox_parcel(str(parcel.id))
	finished.emit(got)

# ------------------------------------------------------------------ input
func _emit() -> void:
	if si >= stages.size(): return
	var st: Dictionary = stages[si]
	if st.kind == "auto":
		(st.on as Callable).call(); _next(); return
	var t: String = st.text
	if st.kind == "click" and int(st.get("n", 1)) > 1: t += "  · %d/%d" % [_clicks, int(st.n)]
	hint_changed.emit(t, prog if st.kind == "drag" else -1.0)
	knife.visible = st.get("tool", "") == "knife"
	if knife.visible: _slit(prog)

func _next() -> void:
	si += 1; prog = 0.0; _clicks = 0; _drag = false; _snd_mark = 0.0
	if si < stages.size(): get_tree().create_timer(0.12).timeout.connect(_emit)

func _world(p: Vector3, st: Dictionary) -> Vector3:
	var base = global_position
	if st.get("lift", false) and _cur_pkg: base = _cur_pkg.global_position + Vector3(0, float(_pkg().get("h", 0.03)), 0)
	return base + p

func _proj(st: Dictionary, mouse: Vector2) -> float:
	var a = cam.unproject_position(_world(st.a, st)); var b = cam.unproject_position(_world(st.b, st))
	var ab = b - a
	if ab.length_squared() < 4.0: return 0.0
	return (mouse - a).dot(ab) / ab.length_squared()

func handle_input(ev: InputEvent) -> bool:
	if si >= stages.size() or _done: return false
	var st: Dictionary = stages[si]
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb = ev as InputEventMouseButton
		if st.kind == "click" and mb.pressed:
			var at: Vector3 = _world(st.get("at", Vector3.ZERO), st)
			if cam.unproject_position(at).distance_to(mb.position) > 260.0: return true
			var i = _clicks; _clicks += 1
			(st.on as Callable).call(i)
			if _clicks >= int(st.get("n", 1)): _next()
			else: _emit()
			return true
		if st.kind == "drag":
			if mb.pressed:
				var p0 = _proj(st, mb.position)
				if p0 <= prog + 0.3 and p0 > -0.6:
					_drag = true
					if prog == 0.0: Audio.sfx(str(st.snd), global_position)
			else: _drag = false
			return true
	if ev is InputEventMouseMotion and st.kind == "drag":
		var mm = ev as InputEventMouseMotion
		if st.get("tool", "") == "knife" and not _drag:
			var pr = _proj(st, mm.position)
			if pr > -0.3 and pr < 1.2: knife.position = Vector3(-size.x / 2.0 + clamp(pr, 0.0, 1.0) * size.x, size.y + 0.02, 0.0)
		if _drag:
			var t: float = clamp(_proj(st, mm.position), 0.0, 1.0)
			if t > prog:
				prog = min(t, prog + 0.12)
				(st.prog as Callable).call(prog)
				if prog - _snd_mark >= float(st.get("every", 0.3)):
					_snd_mark = prog; Audio.sfx(str(st.snd), global_position, -2.0)
				hint_changed.emit(st.text, prog)
				if prog >= 0.97:
					(st.prog as Callable).call(1.0); _drag = false
					(st.done as Callable).call(); _next()
		return true
	return false

## Skips the current stage (used by tests and the "auto" button).
func auto_step() -> void:
	if si >= stages.size() or _done: return
	var st: Dictionary = stages[si]
	match st.kind:
		"click":
			for i in range(_clicks, int(st.get("n", 1))): (st.on as Callable).call(i)
			_next()
		"drag":
			(st.prog as Callable).call(1.0); (st.done as Callable).call(); _next()
		"auto":
			(st.on as Callable).call(); _next()

func stage_count() -> int: return stages.size()
