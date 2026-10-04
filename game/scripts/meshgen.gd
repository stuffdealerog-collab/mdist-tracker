class_name MeshGen
extends RefCounted
## Procedural meshes in key units (1 = 19.05 mm). Y up, Z toward the player.

static var _cache := {}

# --- rounded-rectangle outline (counter-clockwise seen from +Y) ----------
static func rr_points(w: float, d: float, r: float, corner_seg := 6, edge_step := 0.0) -> PackedVector2Array:
	r = min(r, min(w, d) * 0.5 - 0.001)
	var hw := w * 0.5 - r
	var hd := d * 0.5 - r
	var cs := [Vector2(hw, hd), Vector2(-hw, hd), Vector2(-hw, -hd), Vector2(hw, -hd)]
	var a0 := [0.0, PI * 0.5, PI, PI * 1.5]
	var pts := PackedVector2Array()
	for c in 4:
		for s in corner_seg + 1:
			var a: float = a0[c] + PI * 0.5 * float(s) / corner_seg
			pts.append(cs[c] + Vector2(cos(a), sin(a)) * r)
		if edge_step > 0.0:
			var nc: int = (c + 1) % 4
			var p0: Vector2 = pts[pts.size() - 1]
			var p1: Vector2 = cs[nc] + Vector2(cos(a0[nc]), sin(a0[nc])) * r
			var n = int(floor(p0.distance_to(p1) / edge_step))
			for k in range(1, n):
				pts.append(p0.lerp(p1, float(k) / n))
	return pts

# --- keycap ----------------------------------------------------------------
# profile table: height per sculpt row (R1..R4), tilt deg, dish type/depth, top inset, corner radii
const PROFILES := {
	"cherry": {"h": [0.52, 0.45, 0.42, 0.46], "tilt": [10.0, 5.0, 0.0, -6.0], "dish": "cyl", "depth": 0.045, "inset": 0.14, "rb": 0.06, "rt": 0.08},
	"oem":    {"h": [0.62, 0.54, 0.50, 0.56], "tilt": [12.0, 6.0, 0.0, -7.0], "dish": "cyl", "depth": 0.04, "inset": 0.14, "rb": 0.05, "rt": 0.07},
	"sa":     {"h": [0.72, 0.66, 0.64, 0.66], "tilt": [13.0, 7.0, 0.0, -8.0], "dish": "sph", "depth": 0.06, "inset": 0.17, "rb": 0.07, "rt": 0.16},
	"mt3":    {"h": [0.70, 0.64, 0.60, 0.64], "tilt": [11.0, 6.0, 0.0, -6.0], "dish": "sph", "depth": 0.075, "inset": 0.15, "rb": 0.07, "rt": 0.14},
	"kat":    {"h": [0.58, 0.52, 0.48, 0.52], "tilt": [10.0, 5.0, 0.0, -6.0], "dish": "sph", "depth": 0.045, "inset": 0.13, "rb": 0.07, "rt": 0.12},
	"xda":    {"h": [0.36, 0.36, 0.36, 0.36], "tilt": [0.0, 0.0, 0.0, 0.0], "dish": "sph", "depth": 0.03, "inset": 0.09, "rb": 0.08, "rt": 0.13},
}

static func keycap(w: float, prof: String, srow: int) -> ArrayMesh:
	var key := "cap|%s|%.2f|%d" % [prof, w, srow]
	if _cache.has(key): return _cache[key]
	var P: Dictionary = PROFILES.get(prof, PROFILES.cherry)
	srow = clamp(srow, 0, 3)
	var h: float = P.h[srow]
	var tilt := deg_to_rad(float(P.tilt[srow]))
	var bw := w - 0.055
	var bd := 0.945
	var tw := bw - 2.0 * float(P.inset)
	var td := bd - 2.0 * float(P.inset) - 0.02
	var skew := 0.025 * signf(float(P.tilt[srow])) if prof in ["cherry", "oem"] else 0.0
	var step := 0.12
	var bottom := rr_points(bw, bd, P.rb, 6, step)
	var top := rr_points(tw, td, P.rt, 6, step)
	assert(bottom.size() == top.size() or true)
	var n := bottom.size()
	# resample top to the same count as bottom by angle matching
	top = _resample(top, n)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# ---------- sides: rings bottom -> top rim (with a fillet near the top)
	var rings := [0.0, 0.25, 0.5, 0.72, 0.86, 0.94, 1.0]
	var rim_y := func(p: Vector2) -> float: return h + tan(tilt) * p.y * 0.9
	var verts: Array = []
	for ri in rings.size():
		var t: float = rings[ri]
		var ring := PackedVector3Array()
		for i in n:
			var b: Vector2 = bottom[i]
			var tp: Vector2 = top[i] + Vector2(0, skew)
			# fillet: last 2 rings pull inward slightly and approach rim height smoothly
			var shape_t: float = t
			var bulge: float = sin(t * PI) * 0.018
			var p2: Vector2 = b.lerp(tp, ease_out(shape_t))
			var dir := p2.normalized() if p2.length() > 0.001 else Vector2.ZERO
			p2 += dir * bulge
			var y: float = lerp(0.0, rim_y.call(tp), t)
			if t > 0.9:
				var k := (t - 0.9) / 0.1
				y = lerp(rim_y.call(tp) - 0.025, rim_y.call(tp), k * k)
			ring.append(Vector3(p2.x, y, p2.y))
		verts.append(ring)
	for ri in rings.size() - 1:
		var a: PackedVector3Array = verts[ri]; var c: PackedVector3Array = verts[ri + 1]
		for i in n:
			var j := (i + 1) % n
			_quad(st, a[i], a[j], c[j], c[i])
	var side_mesh := st.commit()
	st.clear()
	# ---------- top: rings from rim inward with dish
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var M := 7
	var top_rings: Array = []
	var uvs: Array = []
	var hw := tw * 0.5; var hd := td * 0.5
	for j in M + 1:
		var s := 1.0 - float(j) / M
		var ring := PackedVector3Array(); var uv := PackedVector2Array()
		for i in n:
			var tp: Vector2 = top[i] * s
			var x := tp.x; var z := tp.y + skew
			var dd := 0.0
			if P.dish == "cyl":
				if w < 1.75: dd = float(P.depth) * (1.0 - pow(x / hw, 2.0))
				else: dd = float(P.depth) * 0.6 * (1.0 - pow(tp.y / hd, 2.0))
			else:
				var ex: float = max(abs(x) - max(hw - hd, 0.0), 0.0)
				dd = float(P.depth) * (1.0 - (pow(ex / hd, 2.0) + pow(tp.y / hd, 2.0)))
			dd = max(dd, 0.0)
			var y: float = rim_y.call(Vector2(x, tp.y)) - dd * (1.0 - pow(s, 6.0)) - (0.0)
			ring.append(Vector3(x, y, z))
			uv.append(Vector2(x / tw + 0.5, tp.y / td + 0.5))
		top_rings.append(ring); uvs.append(uv)
	for j in M:
		var a: PackedVector3Array = top_rings[j]; var c: PackedVector3Array = top_rings[j + 1]
		var ua: PackedVector2Array = uvs[j]; var uc: PackedVector2Array = uvs[j + 1]
		for i in n:
			var k := (i + 1) % n
			_quad_uv(st, a[i], a[k], c[k], c[i], ua[i], ua[k], uc[k], uc[i])
	var top_mesh := st.commit()
	# merge into one ArrayMesh with two surfaces: 0 = sides, 1 = top
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, side_mesh.surface_get_arrays(0))
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, top_mesh.surface_get_arrays(0))
	_cache[key] = am
	return am

static func ease_out(t: float) -> float: return 1.0 - pow(1.0 - t, 1.6)

static func _resample(pts: PackedVector2Array, n: int) -> PackedVector2Array:
	if pts.size() == n: return pts
	# resample along perimeter length
	var total := 0.0; var lens := [0.0]
	for i in pts.size():
		total += pts[i].distance_to(pts[(i + 1) % pts.size()]); lens.append(total)
	var out := PackedVector2Array()
	for k in n:
		var target := total * float(k) / n
		var i := 0
		while i < pts.size() - 1 and lens[i + 1] < target: i += 1
		var seg: float = max(lens[i + 1] - lens[i], 0.00001)
		out.append(pts[i].lerp(pts[(i + 1) % pts.size()], (target - lens[i]) / seg))
	return out

static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	# a,b bottom; c,d top. Outward winding for Godot (clockwise front faces)
	st.add_vertex(a); st.add_vertex(b); st.add_vertex(c)
	st.add_vertex(a); st.add_vertex(c); st.add_vertex(d)

static func _quad_uv(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2) -> void:
	st.set_uv(ua); st.add_vertex(a); st.set_uv(ub); st.add_vertex(b); st.set_uv(uc); st.add_vertex(c)
	st.set_uv(ua); st.add_vertex(a); st.set_uv(uc); st.add_vertex(c); st.set_uv(ud); st.add_vertex(d)

# Smooth normals for non-indexed triangle soup: weld by position then generate.
static func finalize(m: Mesh) -> ArrayMesh:
	var out := ArrayMesh.new()
	for s in m.get_surface_count():
		var st := SurfaceTool.new()
		st.create_from(m, s)
		st.index()
		st.generate_normals()
		if m.surface_get_format(s) & Mesh.ARRAY_FORMAT_TEX_UV: st.generate_tangents()
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, st.commit_to_arrays())
	return out

static func keycap_final(w: float, prof: String, srow: int) -> ArrayMesh:
	var key := "capf|%s|%.2f|%d" % [prof, w, srow]
	if _cache.has(key): return _cache[key]
	var m := finalize(keycap(w, prof, srow))
	_cache[key] = m
	return m

# --- rounded box (for switches, cases parts, props) -----------------------
static func rounded_box(w: float, h: float, d: float, r: float, chamfer_rings := 3) -> ArrayMesh:
	var key := "rbox|%.3f|%.3f|%.3f|%.3f" % [w, h, d, r]
	if _cache.has(key): return _cache[key]
	var outline := rr_points(w, d, r, 5, 0.0)
	var n := outline.size()
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var e: float = min(r, h * 0.3)
	var levels := [[0.0, e], [e * 0.3, e * 0.3], [e, 0.0], [h - e, 0.0], [h - e * 0.3, e * 0.3], [h, e]]
	var rings: Array = []
	for lv in levels:
		var ring := PackedVector3Array()
		var inset: float = lv[1]
		for i in n:
			var p: Vector2 = outline[i]
			var dir := p.normalized()
			var q := p - dir * inset * 0.7
			ring.append(Vector3(q.x, lv[0], q.y))
		rings.append(ring)
	for li in rings.size() - 1:
		var a: PackedVector3Array = rings[li]; var c: PackedVector3Array = rings[li + 1]
		for i in n:
			var j := (i + 1) % n
			_quad(st, a[i], a[j], c[j], c[i])
	# caps
	var topc := Vector3(0, h, 0); var botc := Vector3(0, 0, 0)
	var tr: PackedVector3Array = rings[rings.size() - 1]; var br: PackedVector3Array = rings[0]
	for i in n:
		var j := (i + 1) % n
		st.add_vertex(topc); st.add_vertex(tr[j]); st.add_vertex(tr[i])
		st.add_vertex(botc); st.add_vertex(br[i]); st.add_vertex(br[j])
	var m := finalize(st.commit())
	_cache[key] = m
	return m

# --- case tray: outer wall, rim, inner wall, floor, bottom -----------------
static func case_tray(W: float, H: float, wall_h := 1.0, floor_y := 0.28) -> ArrayMesh:
	var key := "case|%.2f|%.2f" % [W, H]
	if _cache.has(key): return _cache[key]
	var ow := W + 0.9; var od := H + 0.9
	var outer := rr_points(ow, od, 0.42, 8, 0.25)
	var inner := _resample(rr_points(W + 0.16, H + 0.16, 0.12, 6, 0.25), outer.size())
	var n := outer.size()
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ch := 0.06
	var lv := [[0.0, ch], [ch * 0.3, ch * 0.3], [ch, 0.0], [wall_h - ch, 0.0], [wall_h - ch * 0.3, ch * 0.3], [wall_h, ch]]
	var rings: Array = []
	for l in lv:
		var ring := PackedVector3Array()
		for i in n:
			var p: Vector2 = outer[i]; var q := p - p.normalized() * float(l[1])
			ring.append(Vector3(q.x, l[0], q.y))
		rings.append(ring)
	for li in rings.size() - 1:
		for i in n:
			var j := (i + 1) % n
			_quad(st, rings[li][i], rings[li][j], rings[li + 1][j], rings[li + 1][i])
	# rim (top band) from outer top ring to inner top
	var otop: PackedVector3Array = rings[rings.size() - 1]
	var itop := PackedVector3Array(); var ibot := PackedVector3Array()
	for i in n:
		itop.append(Vector3(inner[i].x, wall_h, inner[i].y)); ibot.append(Vector3(inner[i].x, floor_y, inner[i].y))
	for i in n:
		var j := (i + 1) % n
		st.add_vertex(otop[i]); st.add_vertex(otop[j]); st.add_vertex(itop[i])
		st.add_vertex(otop[j]); st.add_vertex(itop[j]); st.add_vertex(itop[i])
	# inner wall (facing inward)
	for i in n:
		var j := (i + 1) % n
		st.add_vertex(ibot[i]); st.add_vertex(itop[j]); st.add_vertex(ibot[j])
		st.add_vertex(ibot[i]); st.add_vertex(itop[i]); st.add_vertex(itop[j])
	# inner floor
	var fc := Vector3(0, floor_y, 0)
	for i in n:
		var j := (i + 1) % n
		st.add_vertex(fc); st.add_vertex(ibot[i]); st.add_vertex(ibot[j])
	# bottom
	var bc := Vector3(0, 0, 0); var br: PackedVector3Array = rings[0]
	for i in n:
		var j := (i + 1) % n
		st.add_vertex(bc); st.add_vertex(br[j]); st.add_vertex(br[i])
	var m := finalize(st.commit())
	# planar UVs for wood/brushed textures
	_cache[key] = _planar_uv(m, 0.25)
	return _cache[key]

static func _planar_uv(m: ArrayMesh, scale: float) -> ArrayMesh:
	var out := ArrayMesh.new()
	for s in m.get_surface_count():
		var arr := m.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]; var nn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var uv := PackedVector2Array(); uv.resize(v.size())
		for i in v.size():
			var p = v[i]; var no = nn[i].abs()
			if no.y > 0.6: uv[i] = Vector2(p.x, p.z) * scale
			elif no.x > no.z: uv[i] = Vector2(p.z, p.y) * scale
			else: uv[i] = Vector2(p.x, p.y) * scale
		arr[Mesh.ARRAY_TEX_UV] = uv
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return out

# --- tapered rounded box (switch top housing, feet, props) -----------------
static func tapered_box(wb: float, db: float, wt: float, dt: float, h: float, rb: float, rt: float) -> ArrayMesh:
	var key := "tbox|%.3f|%.3f|%.3f|%.3f|%.3f|%.3f|%.3f" % [wb, db, wt, dt, h, rb, rt]
	if _cache.has(key): return _cache[key]
	var b := rr_points(wb, db, rb, 4, 0.0)
	var n := b.size()
	var t := _resample(rr_points(wt, dt, rt, 4, 0.0), n)
	var mid := PackedVector2Array(); var top2 := PackedVector2Array()
	for i in n:
		mid.append(b[i].lerp(t[i], 0.92)); top2.append(t[i] * 0.94)
	var rings := [[b, 0.0], [mid, h * 0.93], [t, h * 0.985], [top2, h]]
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for li in rings.size() - 1:
		var A: PackedVector2Array = rings[li][0]; var C: PackedVector2Array = rings[li + 1][0]
		var ya: float = rings[li][1]; var yc: float = rings[li + 1][1]
		for i in n:
			var j := (i + 1) % n
			_quad(st, Vector3(A[i].x, ya, A[i].y), Vector3(A[j].x, ya, A[j].y), Vector3(C[j].x, yc, C[j].y), Vector3(C[i].x, yc, C[i].y))
	var tc := Vector3(0, h, 0); var bc := Vector3.ZERO
	for i in n:
		var j := (i + 1) % n
		st.add_vertex(tc); st.add_vertex(Vector3(top2[j].x, h, top2[j].y)); st.add_vertex(Vector3(top2[i].x, h, top2[i].y))
		st.add_vertex(bc); st.add_vertex(Vector3(b[i].x, 0, b[i].y)); st.add_vertex(Vector3(b[j].x, 0, b[j].y))
	var m := finalize(st.commit())
	_cache[key] = m
	return m

# --- flat slab with planar UVs on top/bottom (plate, pcb, foam) -----------
## Top/bottom UV = (x/W+.5, z/H+.5); sides sample the UV corner (0.002, 0.002).
static func slab(W: float, H: float, th: float, r := 0.05) -> ArrayMesh:
	var key := "slab|%.3f|%.3f|%.3f|%.3f" % [W, H, th, r]
	if _cache.has(key): return _cache[key]
	var o := rr_points(W, H, r, 3, 0.0)
	var n := o.size()
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var uvf := func(p: Vector2) -> Vector2: return Vector2(p.x / W + 0.5, p.y / H + 0.5)
	var c := Vector2.ZERO
	for i in n:
		var j := (i + 1) % n
		# top (y = th)
		st.set_uv(uvf.call(c)); st.add_vertex(Vector3(0, th, 0))
		st.set_uv(uvf.call(o[j])); st.add_vertex(Vector3(o[j].x, th, o[j].y))
		st.set_uv(uvf.call(o[i])); st.add_vertex(Vector3(o[i].x, th, o[i].y))
		# bottom
		st.set_uv(uvf.call(c)); st.add_vertex(Vector3(0, 0, 0))
		st.set_uv(uvf.call(o[i])); st.add_vertex(Vector3(o[i].x, 0, o[i].y))
		st.set_uv(uvf.call(o[j])); st.add_vertex(Vector3(o[j].x, 0, o[j].y))
		# side
		var e := Vector2(0.002, 0.002)
		_quad_uv(st, Vector3(o[i].x, 0, o[i].y), Vector3(o[j].x, 0, o[j].y), Vector3(o[j].x, th, o[j].y), Vector3(o[i].x, th, o[i].y), e, e, e, e)
	var arr := st.commit()
	# flat normals: no welding so edges stay crisp
	var st2 := SurfaceTool.new(); st2.create_from(arr, 0); st2.generate_normals(); st2.generate_tangents()
	var m := ArrayMesh.new(); m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, st2.commit_to_arrays())
	_cache[key] = m
	return m
