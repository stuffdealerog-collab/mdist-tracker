class_name Keyboard3D
extends Node3D
## A fully modelled keyboard built from a spec. Works in key units; the node
## is scaled to metres by the owner (1u = 19.05 mm).
## build(spec) -> sync(build_state|null) -> press / insert / pick.

const SCREW_ORDER := [0, 5, 2, 3, 1, 4]
const PLATE_Y := 0.75
const PLATE_TH := 0.03
const CAP_Y := 1.05
const TRAVEL := 0.2
const HOME := {"foam": 0.30, "pcb": 0.45, "pefoam": 0.51, "plate": PLATE_Y}

var spec: Dictionary = {}
var board: Node3D            # tilted by the case typing angle; everything lives here
var tilt_deg := 6.0
var L: Dictionary = {}
var W := 15.0
var H := 5.0
var keys: Array = []          # per key: {k, i, x, z, w, sw, stem, cap, stab, mark, pv, down, drop, cdrop, glow}
var parts := {}
var screws: Array = []
var piece: Node3D = null
var piece_name := ""
var ghost: Node3D = null
var ghost_kind := ""
var ghost_i := -1
var rgb := false
var rgb_lights: Array = []
var _t := 0.0
var _key := ""
var _bent_mat: StandardMaterial3D
var _strip_mat: StandardMaterial3D
var _screw_mat: StandardMaterial3D
var _pin_mat := Mats.std(Color("c9a45c"), 0.3, 1.0)
var _lit := {}               # key -> glow color (keytest)

static func screw_positions(lay: Dictionary) -> Array:
	var Wl: float = lay.W; var Hl: float = lay.H
	var xs := []
	for f in [0.17, 0.5, 0.83]: xs.append(round(Wl * f) - Wl / 2.0)
	var z0: float = (2.25 if lay.get("fgap", false) else 1.0) - Hl / 2.0
	var z1: float = (Hl - 1.0) - Hl / 2.0
	return [Vector2(xs[0], z0), Vector2(xs[1], z0), Vector2(xs[2], z0), Vector2(xs[0], z1), Vector2(xs[1], z1), Vector2(xs[2], z1)]

static func spec_key(sp: Dictionary) -> String:
	return "|".join([sp.get("layout"), sp.get("case"), sp.get("color", 0), sp.get("plate"), sp.get("pcb"), sp.get("stab"), sp.get("kc"), sp.get("sw"), sp.get("art", ""), JSON.stringify(sp.get("mods", {}))])

static func cap_colors(kc_id: String, kind: String) -> Array:
	var c: Dictionary = Data.kc(kc_id).c
	var t: String = str(c.sp) if kind == "sp" else kind
	return [Color(c.get(t, "#cccccc")), Color(c.get(t + "l", "#222222"))]

static func srow_of(lay: Dictionary, row: int) -> int:
	var r := row - (1 if lay.get("fgap", false) else 0)
	if r < 0: return 0
	return [0, 1, 2, 3, 3, 3][min(r, 5)]

static func art_color(a: Dictionary) -> Color:
	var rx := RegEx.new(); rx.compile("#[0-9a-fA-F]{6}")
	var m := rx.search(str(a.get("art", "")))
	return Color(m.get_string()) if m else Color("e0b040")

func _init() -> void:
	_bent_mat = StandardMaterial3D.new(); _bent_mat.albedo_color = Color("e04848"); _bent_mat.emission_enabled = true; _bent_mat.emission = Color("ff2020"); _bent_mat.emission_energy_multiplier = 1.4
	_strip_mat = Mats.std(Color("c04040"), 0.4, 0.6)
	_screw_mat = Mats.std(Color("d0d3d6"), 0.22, 0.95)

# ---------------------------------------------------------------- build
func show_spec(sp: Dictionary, st = null) -> void:
	var k := spec_key(sp)
	if k != _key:
		_key = k; build(sp)
	sync(st)

func build(sp: Dictionary) -> void:
	for c in get_children(): c.queue_free()
	keys.clear(); parts.clear(); screws.clear(); rgb_lights.clear(); piece = null; ghost = null; ghost_kind = ""; _lit.clear()
	spec = sp; L = Data.LAYOUTS[sp.layout]; W = float(L.W); H = float(L.H)
	var cs := Data.case_(sp.case)
	var shape: Dictionary = cs.get("shape", {}).duplicate()
	tilt_deg = float(shape.get("angle", 6.0))
	var bez: float = shape.get("bezel", 0.45)
	var od := H + 2.0 * bez
	var ta := tan(deg_to_rad(tilt_deg))
	shape.base = -(od * 0.5) * ta - 0.04
	shape.floor_y = 0.22
	board = Node3D.new(); board.name = "Board"; add_child(board)
	board.rotation.x = deg_to_rad(tilt_deg)
	var feet_h := 0.06
	board.position.y = -float(shape.base) * cos(deg_to_rad(tilt_deg)) + feet_h
	var holder := Node3D.new(); holder.name = "Body"; board.add_child(holder)
	# case shell
	var cmat := Mats.case_mat(sp.case, int(sp.get("color", 0)))
	var shell := _mi(MeshGen.case_shell(W, H, shape), cmat); holder.add_child(shell)
	if shape.get("two_tone"):
		# split case: contrasting bottom half (Mode / Rama style), slightly proud of the top half
		var bt := shape.duplicate(); bt.wall_h = 0.14; bt.bezel = bez + 0.008; bt.chamfer = 0.02
		holder.add_child(_mi(MeshGen.case_shell(W, H, bt), Mats.std(Color(shape.two_tone), 0.28, 0.95)))
	if shape.get("layers", false):
		for y in [0.0, 0.33, 0.66]:
			var ln := _mi(MeshGen.slab(W + 2.0 * bez + 0.01, od + 0.01, 0.012, float(shape.get("radius", 0.35))), Mats.std(Color(1, 1, 1, 0.1), 0.1)); ln.position.y = y; holder.add_child(ln)
	if shape.get("knob", false):
		var kn := _mi(MeshGen.knob(0.3, 0.42), Mats.std(Color(cs.colors[int(sp.get("color", 0))][1]).lightened(0.06), 0.42, 1.0))
		kn.position = Vector3(W / 2.0 + bez * 0.5, float(shape.wall_h) - 0.02, -H / 2.0 - bez * 0.5 + 0.02)
		holder.add_child(kn)
	# rubber feet on the (level) desk side of the wedge
	for f in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var fz: float = f.y * (od / 2.0 - 0.5)
		var ft := _mi(MeshGen.rounded_box(1.0, feet_h, 0.4, 0.1), Mats.std(Color("101112"), 0.95))
		ft.position = Vector3(f.x * (W / 2.0 + bez - 0.9), float(shape.base) + fz * ta - feet_h, fz)
		ft.rotation.x = -deg_to_rad(tilt_deg)
		holder.add_child(ft)
	# badge on the back wall
	var badge := _mi(MeshGen.rounded_box(1.2, 0.02, 0.32, 0.08), Mats.std(Color("d8d8d8"), 0.2, 1.0))
	badge.position = Vector3(0, float(shape.base) * 0.5 + 0.2, -(od / 2.0) - 0.002); badge.rotation_degrees.x = -90; holder.add_child(badge)
	# internals
	parts.foam = _mi(MeshGen.slab(W + 0.02, H + 0.02, 0.12, 0.1), Mats.std(Color("34383d"), 1.0))
	var pc := Data.pcb(sp.pcb); rgb = bool(pc.rgb)
	var pcb_node := Node3D.new()
	var pcb_m := StandardMaterial3D.new(); pcb_m.albedo_texture = _pcb_tex(bool(pc.rgb), bool(pc.hs)); pcb_m.roughness = 0.45; pcb_m.metallic = 0.2
	pcb_node.add_child(_mi(MeshGen.slab(W + 0.08, H + 0.08, 0.05, 0.05), pcb_m))
	var usb := _mi(MeshGen.rounded_box(0.46, 0.17, 0.4, 0.06), Mats.std(Color("c9ccd0"), 0.2, 0.95)); usb.position = Vector3(0, 0.05, -H / 2.0 + 0.16); pcb_node.add_child(usb)
	var mcu := _mi(MeshGen.rounded_box(0.5, 0.04, 0.5, 0.02), Mats.std(Color("0c0d0f"), 0.35)); mcu.position = Vector3(0.9, 0.05, -H / 2.0 + 0.55); pcb_node.add_child(mcu)
	parts.pcb = pcb_node
	parts.pefoam = _mi(MeshGen.slab(W, H, 0.02, 0.05), Mats.std(Color("f1f1ec"), 0.95))
	var real_plate: Mesh = KbParts.plate(str(sp.layout))
	if real_plate:                                 # Blender plate: real switch and stab cut-outs, no holes texture
		var pm := Mats.plate_mat(sp.plate, null); pm.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED if sp.plate != "p_pc" else BaseMaterial3D.TRANSPARENCY_ALPHA
		parts.plate = _mi(real_plate, pm)
	else:
		parts.plate = _mi(MeshGen.slab(W + 0.12, H + 0.12, PLATE_TH, 0.06), Mats.plate_mat(sp.plate, _plate_tex()))
	for n in parts:
		var o: Node3D = parts[n]; o.position.y = HOME[n]; o.set_meta("home", HOME[n]); o.name = n; board.add_child(o)
	if rgb:
		var glow := _mi(MeshGen.slab(W + 0.7, H + 0.7, 0.01, 0.4), Mats.emissive(Color("7a5cff"), 1.5)); glow.position.y = 0.25; holder.add_child(glow)
		for i in 4:
			var ol := OmniLight3D.new(); ol.omni_range = 3.2; ol.light_energy = 0.0; ol.shadow_enabled = false; ol.omni_attenuation = 2.0
			ol.light_specular = 0.0
			ol.position = Vector3(-W / 2.0 + W * (i + 0.5) / 4.0, 0.45, 0); board.add_child(ol); rgb_lights.append(ol)
	# keys
	var sw := Data.sw(sp.sw); var kc := Data.kc(sp.kc)
	var centered: bool = not (kc.prof in ["cherry", "oem"])
	var rough: float = 0.74 if kc.mat == "PBT" else 0.47
	var hm := _housing_mat(sw); var smt := Mats.std(Color(sw.stem), 0.35)
	var art_id: String = Game.art_base_id(str(sp.get("art", ""))) if sp.get("art") else ""
	for i in L.keys.size():
		var k: Dictionary = L.keys[i]
		var x: float = float(k.x) + float(k.w) / 2.0 - W / 2.0
		var z: float = float(k.y) + 0.5 - H / 2.0
		var o := {"k": k, "i": i, "x": x, "z": z, "w": float(k.w), "pv": 0.0, "down": false, "drop": 1.0, "cdrop": 1.0, "glow": Color(0, 0, 0, 0)}
		# switch
		var swn := Node3D.new(); swn.position = Vector3(x, 0, z)
		# housing and stem are one mesh each (KbParts: Blender hero parts, or merged MeshGen fallbacks)
		var hous := MeshInstance3D.new(); hous.mesh = KbParts.housing(PLATE_Y, PLATE_TH); swn.add_child(hous)
		hous.set_surface_override_material(0, hm)
		if hous.mesh.get_surface_count() > 1: hous.set_surface_override_material(1, _pin_mat)
		var stem := _mi(KbParts.stem(), smt); stem.position.y = PLATE_Y + PLATE_TH + 0.34
		swn.add_child(stem)
		board.add_child(swn)
		o.sw = swn; o.stem = stem; o.hous = [hous]
		# keycap
		var cap := Node3D.new(); cap.position = Vector3(x, CAP_Y, z)
		var srow := srow_of(L, int(k.row))
		var cmi := MeshInstance3D.new(); cmi.mesh = KbParts.cap(float(k.w), kc.prof, srow)
		cmi.set_surface_override_material(0, Mats.cap_side()); cmi.set_surface_override_material(1, Mats.cap_top())
		var cc := cap_colors(sp.kc, str(k.kind))
		cmi.set_instance_shader_parameter("base_color", cc[0])
		cmi.set_instance_shader_parameter("legend_color", cc[1])
		cmi.set_instance_shader_parameter("rough", rough)
		cmi.set_instance_shader_parameter("key_w", float(k.w))
		var is_art: bool = art_id != "" and ("Escape" in k.codes or str(k.label) == "Esc")
		var lab := str(k.label)
		var cen := centered or float(k.w) >= 2.0 and lab.length() <= 1
		cmi.set_instance_shader_parameter("legend_index", -1.0 if is_art else LegendAtlas.idx(lab, cen))
		cmi.set_instance_shader_parameter("centered", 0.0)
		cap.add_child(cmi)
		if is_art: _add_artisan(cap, art_id, float(MeshGen.PROFILES[kc.prof].h[srow]))
		board.add_child(cap)
		o.cap = cap; o.cmi = cmi
		# stabilizer
		if float(k.w) >= 2.0:
			o.stab = _stab_obj(float(k.w)); o.stab.position = Vector3(x, PLATE_Y + PLATE_TH, z); board.add_child(o.stab)
		# mark
		var mk := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(float(k.w) - 0.12, 0.86); mk.mesh = pm
		mk.position = Vector3(x, PLATE_Y + PLATE_TH + 0.01, z); mk.visible = false; mk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; board.add_child(mk)
		o.mark = mk
		keys.append(o)
	# screws
	var sp_pos := screw_positions(L)
	for j in 6:
		var s := _screw_obj(j); s.position = Vector3(sp_pos[j].x, PLATE_Y + PLATE_TH, sp_pos[j].y); board.add_child(s); screws.append(s)

func _mi(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new(); m.mesh = mesh; m.material_override = mat; return m

func _housing_mat(sw: Dictionary) -> Material:
	var c := Color(sw.hous)
	var key := "hous" + str(sw.id)
	if Mats._c.has(key): return Mats._c[key]
	var m := StandardMaterial3D.new()
	if sw.get("clear", c.get_luminance() > 0.7):
		m.albedo_color = Color(c.r, c.g, c.b, 0.5); m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS; m.roughness = 0.12
		m.metallic_specular = 0.7
	else:
		m.albedo_color = c; m.roughness = 0.42
	if str(sw.id) == "sw_holo":
		m.rim_enabled = true; m.rim = 1.0; m.rim_tint = 0.0; m.emission_enabled = true; m.emission = Color("b48cff"); m.emission_energy_multiplier = 0.3
	Mats._c[key] = m
	return m

func _stab_obj(w: float) -> Node3D:
	var g := Node3D.new()
	var kind := str(spec.get("stab", "s_basic"))
	var m: Mesh = KbParts.stab(w, kind != "s_basic")
	if m:                                          # Blender stabs: real spacing, housings, stems and the bent wire
		var mi := MeshInstance3D.new(); mi.mesh = m; g.add_child(mi)
		var hc := {"s_basic": Color("f1f1ee"), "s_screw": Color(0.9, 0.93, 0.95, 0.55), "s_prem": Color("17181a")}.get(kind, Color("f1f1ee"))
		var hm := Mats.std(hc, 0.4)
		if hc.a < 1.0: hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS; hm.roughness = 0.12
		mi.set_surface_override_material(0, hm); mi.set_surface_override_material(1, Mats.std(Color("c4c8cc"), 0.22, 0.95))
		return g
	var hm2 := Mats.std(Color("f1f1ee"), 0.5); var wm := Mats.std(Color("c4c8cc"), 0.25, 0.9)
	var dx := w / 2.0 - 0.62
	for sx in [-1.0, 1.0]:
		var hb := _mi(MeshGen.rounded_box(0.22, 0.2, 0.42, 0.04), hm2); hb.position = Vector3(sx * dx, 0, 0.02); g.add_child(hb)
		var st := _mi(MeshGen.rounded_box(0.1, 0.18, 0.1, 0.02), hm2); st.position = Vector3(sx * dx, 0.2, 0.02); g.add_child(st)
	var wire := MeshInstance3D.new(); var cy := CylinderMesh.new(); cy.top_radius = 0.018; cy.bottom_radius = 0.018; cy.height = 2.0 * dx; cy.radial_segments = 8
	wire.mesh = cy; wire.material_override = wm; wire.rotation_degrees.z = 90; wire.position = Vector3(0, 0.05, -0.22); g.add_child(wire)
	return g

func _screw_obj(j: int) -> Node3D:
	var g := Node3D.new()
	var hd := Node3D.new(); hd.name = "hd"
	var head := MeshInstance3D.new(); var cy := CylinderMesh.new(); cy.top_radius = 0.15; cy.bottom_radius = 0.17; cy.height = 0.07; cy.radial_segments = 24
	head.mesh = cy; head.material_override = _screw_mat; head.position.y = 0.035; hd.add_child(head)
	var slot1 := _mi(MeshGen.rounded_box(0.22, 0.03, 0.04, 0.01), Mats.std(Color("30343a"), 0.6)); slot1.position.y = 0.05; hd.add_child(slot1)
	var slot2 := _mi(MeshGen.rounded_box(0.04, 0.03, 0.22, 0.01), Mats.std(Color("30343a"), 0.6)); slot2.position.y = 0.05; hd.add_child(slot2)
	g.add_child(hd)
	var ring := MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = 0.24; tm.outer_radius = 0.3; ring.mesh = tm
	ring.material_override = Mats.emissive(Color("ffd166"), 2.5); ring.position.y = 0.02; ring.name = "ring"; g.add_child(ring)
	var lbl := Label3D.new(); lbl.text = str(SCREW_ORDER.find(j) + 1); lbl.font_size = 96; lbl.pixel_size = 0.004; lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true; lbl.modulate = Color("ffb08a"); lbl.outline_size = 18; lbl.outline_modulate = Color(0.1, 0.05, 0.03); lbl.position.y = 0.9; lbl.name = "num"
	lbl.font = load("res://assets/fonts/Tektur.ttf"); g.add_child(lbl)
	g.set_meta("hd", hd); g.set_meta("ring", ring); g.set_meta("num", lbl); g.set_meta("head", head)
	return g

func _add_artisan(cap: Node3D, art_id: String, h: float) -> void:
	var A := Data.art(art_id)
	var col := art_color(A)
	var mat := Mats.resin(col)
	var base := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.3; sm.height = 0.42; sm.radial_segments = 32; sm.rings = 16
	base.mesh = sm; base.material_override = mat; base.position = Vector3(0, h + 0.06, 0.02); cap.add_child(base)
	var tor := MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = 0.2; tm.outer_radius = 0.3; tm.rings = 24
	tor.mesh = tm; tor.material_override = Mats.resin(col.lightened(0.3)); tor.position = Vector3(0, h + 0.02, 0.02); cap.add_child(tor)
	var g := Label3D.new(); g.text = str(A.get("g", "✦")); g.font_size = 64; g.pixel_size = 0.005; g.position = Vector3(0, h + 0.28, 0.02)
	g.rotation_degrees.x = -90; g.modulate = Color(1, 1, 1, 0.9); cap.add_child(g)

# ------------------------------------------------------------ textures
func _plate_tex() -> Texture2D:
	var key := "plate|" + str(spec.layout)
	if Mats._c.has(key): return Mats._c[key]
	var px := 64
	var Wp := W + 0.12; var Hp := H + 0.12
	var img := Image.create(int(Wp * px), int(Hp * px), false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	var hole := int(0.735 * px)
	for k in L.keys:
		var cx := (float(k.x) + float(k.w) / 2.0 + 0.06) * px
		var cz := (float(k.y) + 0.5 + 0.06) * px
		img.fill_rect(Rect2i(int(cx - hole / 2.0), int(cz - hole / 2.0), hole, hole), Color(0, 0, 0, 0))
		if float(k.w) >= 2.0:
			var dx := (float(k.w) / 2.0 - 0.62) * px
			for sx in [-1.0, 1.0]:
				img.fill_rect(Rect2i(int(cx + sx * dx - 0.13 * px), int(cz - 0.26 * px), int(0.26 * px), int(0.6 * px)), Color(0, 0, 0, 0))
	# screw holes
	for p in screw_positions(L):
		var c := Vector2((p.x + Wp / 2.0) * px, (p.y + Hp / 2.0) * px)
		for yy in range(-6, 7):
			for xx in range(-6, 7):
				if xx * xx + yy * yy <= 36: img.set_pixel(int(c.x) + xx, int(c.y) + yy, Color(0, 0, 0, 0))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	Mats._c[key] = t
	return t

func _pcb_tex(black: bool, hs: bool) -> Texture2D:
	var key := "pcb|%s|%s|%s" % [spec.layout, black, hs]
	if Mats._c.has(key): return Mats._c[key]
	var px := 48
	var Wp := W + 0.08; var Hp := H + 0.08
	var w := int(Wp * px); var h := int(Hp * px)
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var base := Color("14171b") if black else Color("1b5a39")
	var trace := base.lightened(0.12)
	img.fill(base)
	var rng := RandomNumberGenerator.new(); rng.seed = 42
	for i in 160:
		var y := rng.randi_range(0, h - 1); var x0 := rng.randi_range(0, w - 1); var len := rng.randi_range(20, 200)
		img.fill_rect(Rect2i(x0, y, len, 2), trace)
		var x1: int = min(w - 2, x0 + len); img.fill_rect(Rect2i(x1, y, 2, rng.randi_range(10, 80)), trace)
	var gold := Color("d4b36a")
	var silver := Color("c9ccd0")
	for k in L.keys:
		var cx := int((float(k.x) + float(k.w) / 2.0 + 0.04) * px)
		var cz := int((float(k.y) + 0.5 + 0.04) * px)
		img.fill_rect(Rect2i(cx - 4, cz - 4, 8, 8), gold * 0.8)
		img.fill_rect(Rect2i(cx - 12, cz - 14, 5, 5), gold); img.fill_rect(Rect2i(cx + 8, cz - 10, 5, 5), gold)
		if hs: img.fill_rect(Rect2i(cx - 16, cz + 4, 30, 9), Color("15161a"))
		img.fill_rect(Rect2i(cx + 10, cz + 6, 4, 4), silver)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	Mats._c[key] = t
	return t

# ---------------------------------------------------------------- sync
## st = Game.S.build during assembly, null when showing a finished board.
func sync(st = null) -> void:
	if keys.is_empty(): return
	var step: String = str(st.steps[int(st.step)]) if st else ""
	var pcs: Dictionary = st.pieces if st else {}
	var m: Dictionary = st.mods if st else spec.get("mods", {})
	for n in ["foam", "pcb", "pefoam", "plate"]:
		var o: Node3D = parts[n]
		if o == piece:
			if st == null or pcs.has(n): piece = null
			else: continue
		var need: bool = n == "pcb" or n == "plate" or m.get(n, false)
		o.visible = need and (st == null or pcs.has(n))
		if not o.has_meta("dropping"):
			o.position = Vector3(0, o.get_meta("home"), 0); o.rotation.y = 0; o.scale = Vector3.ONE
	var plate_in: bool = st == null or pcs.has("plate")
	var s_tgt: Array = Game.stab_targets(st.layout) if st else []
	var tz := Asm.torque_zone()
	for i in keys.size():
		var o: Dictionary = keys[i]
		var ks: Dictionary = st.ks[i] if st else {"s": 1, "c": 1}
		o.sw.visible = int(ks.get("s", 0)) == 1
		var bent: bool = st != null and int(ks.get("b", 0)) == 1
		o.sw.rotation.z = 0.32 if bent else 0.0
		for hmi in o.hous: hmi.material_overlay = _bent_mat if bent else null
		o.cap.visible = int(ks.get("c", 0)) == 1
		o.cap.rotation.z = 0.14 if st and int(ks.get("w", 0)) == 1 else 0.0
		if o.has("stab"): o.stab.visible = st == null or st.stabs.has(str(i))
		var mk := ""
		if step == "stab" and i in s_tgt and not st.stabs.has(str(i)): mk = "ffd166"
		if step == "solder" and int(ks.get("s", 0)) == 1:
			mk = "cfd6dc" if float(ks.get("so", 0)) >= 1.0 else ("f2b84b" if float(ks.get("so", 0)) > 0 else "")
		o.mark.visible = mk != ""
		if mk != "": o.mark.material_override = _mark_mat(Color(mk))
		var g := Color(0, 0, 0, 0)
		if step == "keytest" and int(ks.get("c", 0)) == 1:
			if int(ks.get("d", 0)) == 1: g = Color(1, 0.15, 0.15, 1.6)
			elif int(ks.get("t", 0)) == 1: g = Color(0.2, 0.9, 0.4, 0.9)
		elif st and int(ks.get("c", 0)) == 1 and int(ks.get("w", 0)) == 1: g = Color(1, 0.15, 0.15, 1.2)
		if st and Asm.is_repair(st):
			var f := str(ks.get("f", ""))
			var fc := Color(Asm.FAULTS[f].col) if f != "" else Color.WHITE
			if step == "diag":
				if f != "" and int(ks.get("seen", 0)) == 1: g = Color(fc, 1.5)
				elif int(ks.get("t", 0)) == 1: g = Color(0.2, 0.9, 0.4, 0.7)
			elif step == "fix":
				if f != "":
					g = Color(fc, 1.4)
					if int(ks.get("c", 0)) == 0: o.mark.visible = true; o.mark.material_override = _mark_mat(fc)
				elif int(ks.get("fx", 0)) == 1: g = Color(0.2, 0.9, 0.4, 0.6)
			if f == "cap" and int(ks.get("fs", 0)) == 0: o.cap.rotation.z = 0.09
		o.glow = g
		o.cmi.set_instance_shader_parameter("glow", g)
	for j in 6:
		var s: Node3D = screws[j]
		var v = st.screws[j] if st else 0.8
		s.visible = plate_in and (st == null or step == "screw" or v != null)
		var need_more: bool = v == null or float(v) < tz.lo
		var active: bool = step == "screw" and need_more
		s.get_meta("num").visible = active
		s.get_meta("ring").visible = active and next_screw(st) == j
		var hd: Node3D = s.get_meta("hd")
		hd.position.y = 0.0 if not need_more else 0.14
		s.get_meta("head").material_override = _strip_mat if v != null and float(v) > tz.strip else _screw_mat
	if st == null or step in ["kc", "keytest", "test"]:
		for s in screws: s.get_meta("num").visible = false; s.get_meta("ring").visible = false

func next_screw(st) -> int:
	if st == null: return -1
	var tz := Asm.torque_zone()
	for j in SCREW_ORDER:
		var v = st.screws[j]
		if v == null or float(v) < tz.lo: return j
	return -1

func _mark_mat(c: Color) -> StandardMaterial3D:
	var key := "mark" + c.to_html()
	if Mats._c.has(key): return Mats._c[key]
	var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(c.r, c.g, c.b, 0.55); m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.no_depth_test = false
	Mats._c[key] = m
	return m

# -------------------------------------------------------------- actions
func insert(i: int, kind: String) -> void:
	if i < 0 or i >= keys.size(): return
	if kind == "sw": keys[i].drop = 0.0
	else: keys[i].cdrop = 0.0

func press(i: int, down: bool) -> void:
	if i >= 0 and i < keys.size(): keys[i].down = down

func screw_turn(j: int, v: float) -> void:
	if j < 0 or j >= screws.size(): return
	var hd: Node3D = screws[j].get_meta("hd")
	hd.rotation.y = v * PI * 6.0
	hd.position.y = 0.14 - min(1.0, v) * 0.14

## Motion: caps rain down row by row (used when a finished board is shown).
func reveal() -> void:
	for o in keys:
		o.cdrop = -(float(o.k.y) * 0.18 + float(o.k.x) * 0.025)
		o.drop = 1.0

func light_key(i: int, c: Color) -> void:
	if i < 0 or i >= keys.size(): return
	keys[i].cmi.set_instance_shader_parameter("glow", c)

# --------------------------------------------------------------- pieces
func float_piece(name: String, rot: int, keep := false) -> void:
	piece = parts.get(name); piece_name = name
	if piece == null: return
	piece.visible = true; piece.scale = Vector3.ONE * 0.62
	piece.set_meta("ry", rot * PI * 0.5)
	if not keep:
		piece.position = Vector3(W * 0.22, 2.2, -H * 0.35); piece.rotation.y = rot * PI * 0.5
func move_piece_to(x: float, z: float) -> void:
	if piece == null: return
	var p := Vector2(x, z)
	if p.length() < 1.6: p = p.lerp(Vector2.ZERO, 0.55)   # magnetic snap toward the case
	piece.position.x = p.x; piece.position.z = p.y
func piece_pos() -> Vector2:
	return Vector2(piece.position.x, piece.position.z) if piece else Vector2(99, 99)
func drop_piece() -> void:
	if piece == null: return
	piece.set_meta("dropping", true); piece.scale = Vector3.ONE; piece = null
func shake_piece() -> void:
	if piece: piece.set_meta("shake", 1.0)

# ---------------------------------------------------------------- ghost
func set_ghost(kind: String) -> void:
	if ghost: ghost.queue_free(); ghost = null
	ghost_kind = kind; ghost_i = -1
	if kind == "": return
	var gm := StandardMaterial3D.new(); gm.albedo_color = Color(0.3, 0.72, 0.67, 0.45); gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.emission_enabled = true; gm.emission = Color("4cb8ab"); gm.emission_energy_multiplier = 0.6
	ghost = Node3D.new()
	match kind:
		"sw":
			var b := _mi(MeshGen.tapered_box(0.82, 0.82, 0.6, 0.64, 0.4, 0.06, 0.08), gm); b.position.y = 1.1; ghost.add_child(b)
		"cap":
			var b := _mi(MeshGen.tapered_box(0.94, 0.94, 0.68, 0.68, 0.42, 0.06, 0.1), gm); b.position.y = 1.5; ghost.add_child(b)
		"stab":
			var b := _mi(MeshGen.rounded_box(1.4, 0.16, 0.38, 0.05), gm); b.position.y = 0.95; ghost.add_child(b)
		"iron":
			var tip := MeshInstance3D.new(); var cn := CylinderMesh.new(); cn.top_radius = 0.1; cn.bottom_radius = 0.01; cn.height = 0.5
			tip.mesh = cn; tip.material_override = Mats.emissive(Color("ff8a3d"), 3.0); tip.position.y = 1.15; tip.name = "tip"; ghost.add_child(tip)
			var hdl := MeshInstance3D.new(); var cy := CylinderMesh.new(); cy.top_radius = 0.14; cy.bottom_radius = 0.12; cy.height = 1.4
			hdl.mesh = cy; hdl.material_override = Mats.std(Color("2b2f35"), 0.6); hdl.position.y = 2.1; ghost.add_child(hdl)
			var grip := MeshInstance3D.new(); var cy2 := CylinderMesh.new(); cy2.top_radius = 0.16; cy2.bottom_radius = 0.16; cy2.height = 0.6
			grip.mesh = cy2; grip.material_override = Mats.std(Color("d9423b"), 0.7); grip.position.y = 2.5; ghost.add_child(grip)
			var smoke := GPUParticles3D.new(); smoke.amount = 24; smoke.lifetime = 1.4; smoke.position.y = 1.0; smoke.emitting = false; smoke.name = "smoke"
			var pm := ParticleProcessMaterial.new(); pm.direction = Vector3(0, 1, 0); pm.spread = 15; pm.initial_velocity_min = 0.3; pm.initial_velocity_max = 0.6
			pm.gravity = Vector3(0, 0.25, 0); pm.scale_min = 0.6; pm.scale_max = 1.4
			var grad := Gradient.new(); grad.set_color(0, Color(1, 1, 1, 0.35)); grad.set_color(1, Color(1, 1, 1, 0))
			var gt := GradientTexture1D.new(); gt.gradient = grad; pm.color_ramp = gt
			smoke.process_material = pm
			var qm := QuadMesh.new(); qm.size = Vector2(0.18, 0.18)
			var sm := StandardMaterial3D.new(); sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES; sm.vertex_color_use_as_albedo = true; sm.albedo_texture = _soft_dot()
			qm.material = sm; smoke.draw_pass_1 = qm
			ghost.add_child(smoke)
		"pull":
			var pm2 := Mats.std(Color("c9ccd0"), 0.25, 0.9)
			for sx in [-0.34, 0.34]:
				var a := _mi(MeshGen.rounded_box(0.05, 0.9, 0.08, 0.02), pm2); a.position = Vector3(sx, 1.55, 0); ghost.add_child(a)
			var hdl2 := _mi(MeshGen.rounded_box(0.3, 0.6, 0.3, 0.12), Mats.std(Color("2b2f35"), 0.7)); hdl2.position.y = 2.3; ghost.add_child(hdl2)
	ghost.visible = false
	board.add_child(ghost)

func ghost_at(i: int) -> void:
	ghost_i = i
	if ghost == null: return
	if i < 0 or i >= keys.size(): ghost.visible = false; return
	var o: Dictionary = keys[i]
	ghost.visible = true
	ghost.position = Vector3(o.x, 0, o.z)
	if ghost_kind == "cap": ghost.get_child(0).scale.x = (o.w - 0.06) / 0.94
	elif ghost_kind == "stab": ghost.get_child(0).scale.x = (o.w - 0.4) / 1.4

func set_smoke(on: bool) -> void:
	if ghost and ghost.has_node("smoke"): ghost.get_node("smoke").emitting = on

static func _soft_dot() -> Texture2D:
	if Mats._c.has("dot"): return Mats._c.dot
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x - 15.5, y - 15.5).length() / 16.0
			img.set_pixel(x, y, Color(1, 1, 1, clamp(1.0 - d, 0.0, 1.0) ** 2))
	Mats._c.dot = ImageTexture.create_from_image(img)
	return Mats._c.dot

# ---------------------------------------------------------------- picking
## Returns {i, scr, p} for a world-space ray. p = local hit on the key plane.
func pick(from: Vector3, dir: Vector3) -> Dictionary:
	var inv := board.global_transform.affine_inverse()
	var o := inv * from
	var d := (inv.basis * dir).normalized()
	var res := {"i": -1, "scr": -1, "p": Vector3.ZERO}
	if abs(d.y) < 1e-5: return res
	var t := (1.25 - o.y) / d.y
	var p := o + d * t
	res.p = p
	for k in keys:
		if abs(p.x - k.x) <= k.w * 0.5 and abs(p.z - k.z) <= 0.5:
			res.i = k.i; break
	var t2 := (PLATE_Y + 0.15 - o.y) / d.y
	var p2 := o + d * t2
	var best := 0.45
	for j in screws.size():
		var s: Node3D = screws[j]
		if not s.visible: continue
		var dd := Vector2(p2.x - s.position.x, p2.z - s.position.z).length()
		if dd < best: best = dd; res.scr = j
	return res

func plane_point(from: Vector3, dir: Vector3, y: float) -> Vector3:
	var inv := board.global_transform.affine_inverse()
	var o := inv * from; var d := (inv.basis * dir).normalized()
	if abs(d.y) < 1e-5: return Vector3(99, y, 99)
	return o + d * ((y - o.y) / d.y)

func key_world(i: int) -> Vector3:
	if i < 0 or i >= keys.size(): return board.global_position
	return board.global_transform * Vector3(keys[i].x, 1.4, keys[i].z)
func screw_world(j: int) -> Vector3:
	return board.global_transform * (screws[j].position + Vector3(0, 0.2, 0))

# ------------------------------------------------------------------ loop
func _process(delta: float) -> void:
	_t += delta
	var dt: float = min(delta, 0.05)
	for o in keys:
		o.pv = lerp(float(o.pv), 1.0 if o.down else 0.0, 1.0 - exp(-dt * 38.0))
		if o.drop < 1.0: o.drop = min(1.0, o.drop + dt * 5.5)
		if o.cdrop < 1.0: o.cdrop = min(1.0, o.cdrop + dt * 4.5)
		var e1 = _ease_out_back(clamp(o.drop, 0.0, 1.0))
		var e2 = _ease_out_back(clamp(o.cdrop, 0.0, 1.0))
		o.sw.position.y = (1.0 - e1) * 1.4
		var pressed: float = o.pv * TRAVEL if o.cap.visible else o.pv * 0.12
		o.stem.position.y = PLATE_Y + PLATE_TH + 0.34 - pressed
		o.cap.position.y = CAP_Y + (1.0 - e2) * 1.8 - pressed + (0.08 if o.cap.rotation.z != 0.0 else 0.0)
	if piece:
		piece.rotation.y = lerp_angle(piece.rotation.y, float(piece.get_meta("ry", 0.0)), 1.0 - exp(-dt * 14.0))
		piece.position.y = 2.2 + sin(_t * 3.3) * 0.06
		if piece.has_meta("shake"):
			var sh: float = piece.get_meta("shake") - dt * 3.0
			piece.position.x += sin(_t * 50.0) * 0.06 * max(0.0, sh)
			if sh <= 0: piece.remove_meta("shake")
			else: piece.set_meta("shake", sh)
	for n in parts:
		var p: Node3D = parts[n]
		if p.has_meta("dropping"):
			var k := 1.0 - exp(-dt * 12.0)
			p.position = p.position.lerp(Vector3(0, p.get_meta("home"), 0), k)
			p.rotation.y = lerp_angle(p.rotation.y, 0.0, k)
			if p.position.distance_to(Vector3(0, p.get_meta("home"), 0)) < 0.004:
				p.position = Vector3(0, p.get_meta("home"), 0); p.rotation.y = 0; p.remove_meta("dropping")
	if ghost and ghost_kind == "iron" and ghost.visible:
		var tip: MeshInstance3D = ghost.get_node("tip")
		(tip.material_override as StandardMaterial3D).emission_energy_multiplier = 2.4 + sin(_t * 11.0) * 0.8
	if rgb:
		for i in rgb_lights.size():
			var ol: OmniLight3D = rgb_lights[i]
			ol.light_color = Color.from_hsv(fposmod(_t * 0.08 + i * 0.18, 1.0), 0.75, 1.0)
			ol.light_energy = 0.07

static func _ease_out_back(x: float) -> float:
	var c1 := 1.4; var c3 := c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3) + c1 * pow(x - 1.0, 2)
