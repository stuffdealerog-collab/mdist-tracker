# Keycaps at hero quality (docs/keyboard_spec.md): every profile x sculpt row x width, to real dimensions.
# A cap = outer skirt (draft, rounded corners, a soft fillet into the top) + the top with its dish (cylindrical or
# spherical) + the hollow interior (1.4 mm wall, ceiling) + the stem post with the cross slot (and the extra stab posts
# on wide keys). Material slots: 0 "cap_side" (skirt + interior), 1 "cap_top" (top, UV 0..1 for the legend atlas) — the
# order Keyboard3D's cap shader expects. Exported in key units (1 = 19.05 mm), Y up, Z towards the typist,
# origin = centre of the cap's bottom. One GLB per profile: assets/kb/caps_<profile>.glb, nodes cap_r<row>_<w>.
#   blender -b -P tools/blender/kit/kbd_caps.py -- [profile ...]
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh
from mathutils import Vector
import kbd_spec as S

N = 64                                       # outline samples (same count on every ring so they loft cleanly)

def rrect(w, d, r, n=N, shift_z=0.0):
	"""n points around a rounded rectangle (w along X, d along Z), sampled evenly by arc length, starting at +X middle."""
	r = min(r, w / 2 - 0.01, d / 2 - 0.01)
	hw, hd = w / 2 - r, d / 2 - r
	segs = [("l", (hw + r, -hd), (hw + r, hd)), ("a", (hw, hd), 0.0), ("l", (hw, hd + r), (-hw, hd + r)), ("a", (-hw, hd), 0.5 * math.pi),
		("l", (-hw - r, hd), (-hw - r, -hd)), ("a", (-hw, -hd), math.pi), ("l", (-hw, -hd - r), (hw, -hd - r)), ("a", (hw, -hd), 1.5 * math.pi)]
	lens = [(2 * hd if i % 4 == 0 else 2 * hw) if s[0] == "l" else 0.5 * math.pi * r for i, s in enumerate(segs)]
	total = sum(lens); pts = []
	start = lens[0] / 2                                          # start at the middle of the +X side
	for k in range(n):
		t = (start + total * k / n) % total
		for s, L in zip(segs, lens):
			if t <= L or s is segs[-1]:
				if s[0] == "l":
					f = t / max(L, 1e-9); a, b = s[1], s[2]
					pts.append((a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f + shift_z))
				else:
					ang = s[2] + (t / max(L, 1e-9)) * 0.5 * math.pi
					pts.append((s[1][0] + r * math.cos(ang), s[1][1] + r * math.sin(ang) + shift_z))
				break
			t -= L
	return pts

def gv(x, y, z):                             # cap mm (X, Y up, Z to typist) -> Blender, in key units
	return Vector((x / S.U, -z / S.U, y / S.U))

def cap(prof, row, w):
	P = S.PROFILES[prof]
	bw = w * S.U - 0.95; bd = S.CAP_BOTTOM
	tw = P["top"][0] + (w - 1.0) * S.U; td = P["top"][1]
	tilt = math.radians(P["tilt"][row]); back = -P["back"] * (1 if P["tilt"][row] >= 0 else -1)
	h = P["h"][row]
	# rim height: tallest point at the back for typist-facing rows; plane through the top outline
	def rim_y(z): return h - math.tan(tilt) * (z + td / 2) if tilt > 0 else h + math.tan(tilt) * (td / 2 - z) if tilt < 0 else h
	bm = bmesh.new(); uv = bm.loops.layers.uv.new("UVMap")
	bot = rrect(bw, bd, P["rb"]); topo = rrect(tw, td, P["rt"], shift_z=back)
	# ---- outer skirt: rings with a slight belly and a fillet into the top
	ts = [0.0, 0.18, 0.4, 0.62, 0.8, 0.9, 0.95, 0.98, 1.0]
	rings = []
	for t in ts:
		e = 1 - (1 - t) ** 1.5
		ring = []
		for (bx, bz), (tx, tz) in zip(bot, topo):
			x = bx + (tx - bx) * e; z = bz + (tz - bz) * e
			belly = math.sin(t * math.pi) * 0.25
			ln = math.hypot(x, z) or 1.0
			x += x / ln * belly; z += z / ln * belly
			y = rim_y(z) * t
			if t > 0.9:                                           # fillet: approach the rim rounded, not as a crease
				k = (t - 0.9) / 0.1
				y = rim_y(tz) - 0.55 * (1 - k) ** 2
			ring.append(bm.verts.new(gv(x, y, z)))
		rings.append(ring)
	side = []
	for a, b in zip(rings, rings[1:]):
		for i in range(N):
			j = (i + 1) % N
			side.append(bm.faces.new([a[i], a[j], b[j], b[i]]))
	# ---- top with the dish: rings shrinking to the centre
	hw, hd = tw / 2, td / 2
	M = 10; top_rings = [rings[-1]]
	for m in range(1, M + 1):
		s = 1 - m / M
		ring = []
		for (tx, tz) in topo:
			x = tx * s; z = (tz - back) * s + back
			if P["dish"] == "cyl":
				u = x / hw if w < 1.75 else (z - back) / hd
				dd = P["depth"] * max(0.0, 1 - u * u)
			else:
				ex = max(abs(x) - max(hw - hd, 0), 0)
				dd = P["depth"] * max(0.0, 1 - (ex / hd) ** 2 - ((z - back) / hd) ** 2)
			y = rim_y(z) - dd * (1 - s ** 6)
			ring.append(bm.verts.new(gv(x, y, z)) if m < M else None)
		if m == M:
			cy = rim_y(back) - P["depth"]
			c = bm.verts.new(gv(0, cy, back)); ring = [c] * N
		top_rings.append(ring)
	topf = []
	for a, b in zip(top_rings, top_rings[1:]):
		for i in range(N):
			j = (i + 1) % N
			if b[i] is b[j]: topf.append(bm.faces.new([a[i], a[j], b[i]]))
			else: topf.append(bm.faces.new([a[i], a[j], b[j], b[i]]))
	for f in topf:
		f.material_index = 1
		for l in f.loops:
			co = l.vert.co; l[uv].uv = (co.x * S.U / tw + 0.5, 0.5 - ((-co.y) * S.U - back) / td)
	# ---- interior: inner skirt (wall thickness), a ceiling, the bottom lip
	wall = S.CAP_WALL
	ibot = rrect(bw - 2 * wall, bd - 2 * wall, max(P["rb"] - wall * 0.5, 0.3))
	itop = rrect(tw - 2 * wall, td - 2 * wall, max(P["rt"] - wall * 0.5, 0.3), shift_z=back)
	ceil_y = lambda z: rim_y(z) - P["depth"] - 1.3
	inner = []
	for t in (0.0, 0.5, 1.0):
		ring = []
		for (bx, bz), (tx, tz) in zip(ibot, itop):
			x = bx + (tx - bx) * t; z = bz + (tz - bz) * t
			ring.append(bm.verts.new(gv(x, ceil_y(z) * t, z)))
		inner.append(ring)
	for a, b in zip(inner, inner[1:]):
		for i in range(N):
			j = (i + 1) % N
			bm.faces.new([a[j], a[i], b[i], b[j]])               # facing inwards
	cc = bm.verts.new(gv(0, ceil_y(back), back))
	for i in range(N):
		j = (i + 1) % N
		bm.faces.new([inner[-1][j], inner[-1][i], cc])
	for i in range(N):                                          # lip between outer and inner skirt bottoms
		j = (i + 1) % N
		bm.faces.new([rings[0][j], rings[0][i], inner[0][i], inner[0][j]])
	# ---- stem post(s) with the cross slot: four quarter blocks around the cross
	posts = [0.0]
	if w >= 2.0:
		sp = S.STAB_SPACING.get(w, 23.8) / 2
		posts += [-sp, sp]
	R = S.STEM_POST_D / 2; arm, slot = S.STEM_SLOT[0] / 2, S.STEM_SLOT[1] / 2
	for px in posts:
		y_top = ceil_y(0.0); y_bot = max(0.6, y_top - 4.6)
		for q in range(4):
			a0 = q * 0.5 * math.pi
			pts2 = [(slot, slot)] + [(R * math.cos(a0 + (0.5 * math.pi) * (s / 8 * 0.7 + 0.15)), R * math.sin(a0 + (0.5 * math.pi) * (s / 8 * 0.7 + 0.15))) for s in range(9)]
			# rotate the inner corner into this quadrant
			c, s_ = math.cos(a0), math.sin(a0)
			pts2[0] = (slot * (c - s_), slot * (s_ + c))
			lo = [bm.verts.new(gv(px + x, y_bot, z)) for (x, z) in pts2]
			hi = [bm.verts.new(gv(px + x, y_top, z)) for (x, z) in pts2]
			n2 = len(pts2)
			for i in range(n2):
				j = (i + 1) % n2
				bm.faces.new([lo[i], lo[j], hi[j], hi[i]])
			bm.faces.new(list(reversed(lo)))
	bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))     # closed shell: inner walls face into the hollow
	me = bpy.data.meshes.new("cap"); bm.to_mesh(me); bm.free()
	name = "cap_r%d_%s" % (row, ("%.2f" % w).rstrip("0").rstrip("."))
	o = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(o)
	for mn in ("cap_side", "cap_top"):
		m = bpy.data.materials.get(mn) or bpy.data.materials.new(mn); o.data.materials.append(m)
	o.data.polygons.foreach_set("use_smooth", [True] * len(o.data.polygons))
	wn = o.modifiers.new("wn", "WEIGHTED_NORMAL"); wn.keep_sharp = True
	bpy.context.view_layer.objects.active = o
	for s2 in bpy.context.scene.objects: s2.select_set(s2 == o)
	bpy.ops.object.modifier_apply(modifier="wn")
	return o

def build(profile):
	bpy.ops.wm.read_factory_settings(use_empty=True)
	rows = [0] if profile == "xda" else [0, 1, 2, 3]
	objs = []
	for r in rows:
		for w in S.WIDTHS:
			if w >= 2.0 and r < 2 and profile != "xda": continue      # wide keys only live on the lower rows
			objs.append(cap(profile, r, w))
	out = os.path.join(S.GAME, "assets", "kb", "caps_%s.glb" % profile)
	os.makedirs(os.path.dirname(out), exist_ok=True)
	for s2 in bpy.context.scene.objects: s2.select_set(s2 in objs)
	bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, export_yup=True, export_apply=True,
		export_materials="EXPORT", export_normals=True, export_texcoords=True, export_image_format="NONE")
	tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs)
	print("KBD caps %s: %d meshes, %d tris (%.0f per cap)" % (profile, len(objs), tris, tris / max(len(objs), 1)), flush=True)

if __name__ == "__main__":
	a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
	for p in (a or list(S.PROFILES)):
		build(p)
