class_name KbParts
extends RefCounted
## Keyboard part meshes for Keyboard3D, in key units (1 = 19.05 mm), Y up, Z towards the typist.
## Prefers the hero meshes modelled in Blender (tools/blender/kit/kbd_*.py -> assets/kb/*.glb, docs/keyboard_spec.md)
## and falls back to the procedural MeshGen versions while an asset is missing, so the game always builds.
## Merged meshes keep the node count per key at 3 (housing, stem, cap) instead of 7.

const KB := "res://assets/kb/"
static var _cache := {}
static var _scenes := {}

## Mesh by node name from a Blender GLB (cached), or null.
static func _glb_mesh(file: String, node: String) -> Mesh:
	var path = KB + file
	if not _scenes.has(path):
		_scenes[path] = {}
		if ResourceLoader.exists(path):
			var root: Node = (load(path) as PackedScene).instantiate()
			for mi in root.find_children("*", "MeshInstance3D", true, false):
				_scenes[path][String(mi.name)] = (mi as MeshInstance3D).mesh
			root.free()
	return _scenes[path].get(node)

## Keycap: surface 0 = sides (+ interior), surface 1 = top (UV 0..1 for the legend atlas).
static func cap(w: float, prof: String, srow: int) -> Mesh:
	var key = "cap|%s|%.2f|%d" % [prof, w, srow]
	if _cache.has(key): return _cache[key]
	var row := 0 if prof == "xda" else clampi(srow, 0, 3)
	if w >= 2.0 and prof != "xda": row = max(row, 2)          # wide keys exist only on the lower sculpt rows
	var wn := ("%.2f" % w).rstrip("0").rstrip(".")
	var m: Mesh = _glb_mesh("caps_%s.glb" % prof, "cap_r%d_%s" % [row, wn])
	if m == null: m = MeshGen.keycap_final(w, prof, srow)
	_cache[key] = m
	return m

## Switch housing (bottom below the plate + top above it) as ONE mesh in board space (plate top at plate_y + plate_th).
## Surface 0 = housing plastic; the Blender part adds surface 1 = metal pins.
static func housing(plate_y: float, plate_th: float) -> Mesh:
	var key = "housing|%.3f|%.3f" % [plate_y, plate_th]
	if _cache.has(key): return _cache[key]
	var g: Mesh = _glb_mesh("switch_mx.glb", "housing")
	var m: Mesh = null
	if g != null:                                   # Blender part: origin on the plate top -> shift to the board's plate
		var am := ArrayMesh.new()
		for i in g.get_surface_count():
			var st0 := SurfaceTool.new(); st0.begin(Mesh.PRIMITIVE_TRIANGLES)
			st0.append_from(g, i, Transform3D(Basis(), Vector3(0, plate_y + plate_th, 0)))
			st0.commit(am)
		m = am
	if m == null:
		var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.append_from(MeshGen.rounded_box(0.735, 0.27, 0.735, 0.05), 0, Transform3D(Basis(), Vector3(0, plate_y - 0.26, 0)))
		st.append_from(MeshGen.tapered_box(0.82, 0.82, 0.6, 0.64, 0.34, 0.06, 0.08), 0, Transform3D(Basis(), Vector3(0, plate_y + plate_th, 0)))
		m = st.commit()
	_cache[key] = m
	return m

## Switch stem (cross + slider) as ONE mesh; origin = where the old 3-part stem node sat.
static func stem() -> Mesh:
	if _cache.has("stem"): return _cache["stem"]
	var m: Mesh = _glb_mesh("switch_mx.glb", "stem")
	if m == null:
		var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.append_from(MeshGen.rounded_box(0.21, 0.19, 0.065, 0.01), 0, Transform3D())
		st.append_from(MeshGen.rounded_box(0.065, 0.19, 0.21, 0.01), 0, Transform3D())
		st.append_from(MeshGen.rounded_box(0.3, 0.06, 0.3, 0.04), 0, Transform3D(Basis(), Vector3(0, -0.05, 0)))
		m = st.commit()
	_cache["stem"] = m
	return m

## Stabilizer for a key of width w (key units): two housings at the real stem spacing (23.8 mm, 100 mm for 6.25u),
## two stems and the bent wire, as ONE mesh with origin at the key centre on the plate top.
## Surface 0 = plastic (housings + stems), 1 = metal (wire, screws). screw = PCB screw-in housings.
static func stab(w: float, screw: bool) -> Mesh:
	var key = "stab|%.2f|%d" % [w, int(screw)]
	if _cache.has(key): return _cache[key]
	var hous: Mesh = _glb_mesh("stabs.glb", "housing_screw" if screw else "housing_plate")
	var st_m: Mesh = _glb_mesh("stabs.glb", "stem")
	var wire: Mesh = _glb_mesh("stabs.glb", "wire_long" if w >= 6.0 else "wire_short")
	if hous == null or st_m == null or wire == null: return null
	var dx: float = (100.0 if w >= 6.0 else 23.8) / 2.0 / 19.05
	var plastic := SurfaceTool.new(); plastic.begin(Mesh.PRIMITIVE_TRIANGLES)
	var metal := SurfaceTool.new(); metal.begin(Mesh.PRIMITIVE_TRIANGLES)
	for sx in [-1.0, 1.0]:
		var t := Transform3D(Basis(), Vector3(sx * dx, 0, 0))
		plastic.append_from(hous, 0, t); plastic.append_from(st_m, 0, t)
		if hous.get_surface_count() > 1: metal.append_from(hous, 1, t)
	metal.append_from(wire, 0, Transform3D())
	var am := ArrayMesh.new(); plastic.commit(am); metal.commit(am)
	_cache[key] = am
	return am

## Switch plate with real cut-outs for a layout (assets/kb/plate_<layout>.glb), or null (game falls back to the slab).
static func plate(layout_id: String) -> Mesh:
	return _glb_mesh("plate_%s.glb" % layout_id, "plate")
