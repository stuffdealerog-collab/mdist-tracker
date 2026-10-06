# Retail packaging constructions (data/packaging.json "kinds"), one GLB each in assets/models/pack/<kind>.glb.
# Origin = bottom centre, the front looks to +Z (game), like ItemBox. Material slots:
#   pack_print  - the brand artwork (UV 0..1 over the printed face; the game picks the texture per product)
#   pack_side   - the brand's side colour (tinted per brand in the game)
#   kraft, pack_inner, poly_clear, sticker, zip, foam ... - shared looks
#   blender -b -P tools/blender/kit/packaging.py
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bmesh
from core import *
from core import _new

GAME = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
OUTD = os.path.join(GAME, "assets", "models", "pack")
for n, c in [("pack_print", (0.95, 0.95, 0.95)), ("pack_side", (0.9, 0.9, 0.9)), ("kraft", (0.6, 0.45, 0.3)), ("pack_inner", (0.15, 0.15, 0.16)),
		("poly_clear", (0.9, 0.95, 1.0)), ("sticker", (0.97, 0.97, 0.96)), ("zip", (0.85, 0.9, 0.95)), ("foam_black", (0.05, 0.05, 0.05)),
		("switch_house", (0.1, 0.1, 0.12)), ("switch_stem", (0.8, 0.2, 0.2)), ("jar_white", (0.95, 0.95, 0.94))]:
	MATS[n] = dict(c=c, r=0.5, m=0.0, tile=1.0)

def printed_quad(x0, x1, z0, z1, y, name="print", up=True, flip=False):
	"""A face carrying the artwork with UV 0..1 (u along +X, v along -Z = image top towards the back)."""
	bm = bmesh.new(); uv = bm.loops.layers.uv.new("UVMap")
	pts = [(x0, z1), (x1, z1), (x1, z0), (x0, z0)]
	vs = [bm.verts.new(g(x, y, z)) for (x, z) in pts]
	f = bm.faces.new(vs if up else list(reversed(vs)))
	for l in f.loops:
		co = l.vert.co; x = co.x; z = -co.y
		u = (x - x0) / (x1 - x0); v = 1.0 - (z - z0) / (z1 - z0)      # glTF flips V: image top ends at the back edge
		l[uv].uv = (1 - u if flip else u, v)
	me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
	o = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(o)
	o["keep_uv"] = 1
	return _new(o, "pack_print")

def front_quad(x0, x1, y0, y1, z, name="print"):
	"""Artwork on the front face (+Z), UV 0..1."""
	bm = bmesh.new(); uv = bm.loops.layers.uv.new("UVMap")
	vs = [bm.verts.new(g(x, y, z)) for (x, y) in [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]]
	f = bm.faces.new(vs)
	for l in f.loops:
		co = l.vert.co; l[uv].uv = ((co.x - x0) / (x1 - x0), (co.z - y0) / (y1 - y0))
	me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
	o = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(o)
	o["keep_uv"] = 1
	return _new(o, "pack_print")

def out(name):
	o = take(name, lightmap=False)
	for s in bpy.context.scene.objects: s.select_set(s == o)
	export(os.path.join(OUTD, name + ".glb"), [o])
	bpy.data.objects.remove(o)

def lid_box(name, W, H, D, lid_h, side="pack_side", base="pack_inner"):
	"""Rigid two-piece box: base slightly smaller, the lid over it, the artwork on the lid top."""
	box((W - 0.004, H - 0.003, D - 0.004), (0, (H - 0.003) / 2, 0), base, 0.0015)
	t = 0.0018
	box((W, t, D), (0, H - t / 2, 0), side, 0.0012)
	for sx in (-1, 1): box((t, lid_h, D), (sx * (W / 2 - t / 2), H - lid_h / 2, 0), side, 0.0008)
	for sz in (-1, 1): box((W, lid_h, t), (0, H - lid_h / 2, sz * (D / 2 - t / 2)), side, 0.0008)
	printed_quad(-W / 2 + 0.0015, W / 2 - 0.0015, -D / 2 + 0.0015, D / 2 - 0.0015, H + 0.0004)
	out(name)

def case_box():   lid_box("case_box", 0.40, 0.10, 0.17, 0.06)
def keycap_box(): lid_box("keycap_box", 0.36, 0.05, 0.15, 0.035)

def kraft_box():
	"""Corrugated mailer: body, the lid with a rolled front edge and dust-flap seams, a sticker label on top."""
	W, H, D = 0.40, 0.09, 0.17
	box((W, H - 0.004, D), (0, (H - 0.004) / 2, 0), "kraft", 0.003)
	box((W + 0.004, 0.005, D + 0.006), (0, H - 0.0025, 0.002), "kraft", 0.0022)
	box((W - 0.01, 0.012, 0.004), (0, H - 0.008, D / 2 + 0.004), "kraft", 0.0015)          # rolled front of the lid
	for sx in (-1, 1): box((0.002, H * 0.6, D * 0.9), (sx * (W / 2 + 0.0005), H * 0.55, 0), "kraft_dark", 0.0)
	printed_quad(-0.085, 0.085, -0.045, 0.045, H + 0.0006)
	out("kraft_box")

def thin_box(name, W, H, D):
	box((W, H, D), (0, H / 2, 0), "sticker", 0.0015)
	printed_quad(-W * 0.3, W * 0.3, -D * 0.32, D * 0.32, H + 0.0004)
	out(name)

def plate_sleeve(): thin_box("plate_sleeve", 0.34, 0.022, 0.13)
def esd_pcb():      thin_box("esd_pcb", 0.32, 0.018, 0.13)

def switch_box():
	"""Tuck-end carton standing on its side: the artwork on the big front face, tuck seam on top."""
	W, H, D = 0.13, 0.08, 0.045
	box((W, H, D), (0, H / 2, 0), "pack_side", 0.0015)
	front_quad(-W / 2 + 0.001, W / 2 - 0.001, 0.001, H - 0.001, D / 2 + 0.0004)
	box((W - 0.006, 0.0008, 0.004), (0, H + 0.0002, D / 2 - 0.006), "pack_inner", 0.0)
	out("switch_box")

def switch_bag():
	"""Zip bag lying flat: a pillowy clear bag with switches inside, a zip ridge, a round sticker."""
	W, D = 0.12, 0.17
	o = box((W, 0.018, D), (0, 0.009, 0), "poly_clear", 0.008, segs=5)
	box((W - 0.004, 0.004, 0.006), (0, 0.016, -D / 2 + 0.014), "zip", 0.0015)
	for i in range(12):
		cx = -0.04 + (i % 4) * 0.027; cz = -0.03 + (i // 4) * 0.035
		box((0.0155, 0.009, 0.0155), (cx, 0.006, cz), "switch_house", 0.0015)
		box((0.004, 0.003, 0.004), (cx, 0.012, cz), "switch_stem", 0.0)
	bm = bmesh.new(); uv = bm.loops.layers.uv.new("UVMap")
	n = 32; r = 0.035; cy = 0.0185; cz = 0.045
	c = bm.verts.new(g(0, cy, cz)); ring = [bm.verts.new(g(r * math.cos(2 * math.pi * k / n), cy, cz + r * math.sin(2 * math.pi * k / n))) for k in range(n)]
	for k in range(n):
		f = bm.faces.new([c, ring[(k + 1) % n], ring[k]])
		for l in f.loops:
			co = l.vert.co; l[uv].uv = (0.5 + co.x / (2 * r), 0.5 - (-co.y - cz) / (2 * r))
	me = bpy.data.meshes.new("sticker"); bm.to_mesh(me); bm.free()
	so = bpy.data.objects.new("sticker", me); bpy.context.scene.collection.objects.link(so); so["keep_uv"] = 1; _new(so, "pack_print")
	out("switch_bag")

def stab_pack():
	W, H, D = 0.12, 0.025, 0.09
	box((W, 0.004, D), (0, 0.002, 0), "pack_side", 0.001)
	printed_quad(-W / 2 + 0.002, W / 2 - 0.002, -D / 2 + 0.002, D / 2 - 0.002, 0.0042)
	box((W - 0.01, H - 0.004, D - 0.01), (0, 0.004 + (H - 0.004) / 2, 0), "poly_clear", 0.004)
	for i in range(4):
		box((0.022, 0.012, 0.014), (-0.04 + i * 0.027, 0.011, -0.01), "switch_house", 0.002)
		box((0.05, 0.002, 0.002), (-0.03 + (i % 2) * 0.06, 0.006, 0.025 + (i // 2) * 0.008), "steel_brushed", 0.0)
	out("stab_pack")

def jar():
	lathe([(0, 0), (0.024, 0), (0.025, 0.002), (0.025, 0.026), (0.022, 0.028), (0.0, 0.028)], (0, 0, 0), "jar_white", 40, name="jar")
	lathe([(0, 0.027), (0.026, 0.027), (0.026, 0.036), (0.024, 0.0375), (0.0, 0.0375)], (0, 0, 0), "red_plastic", 40, name="cap")
	bm = bmesh.new(); uv = bm.loops.layers.uv.new("UVMap"); n = 40; r = 0.0256
	bot = [bm.verts.new(g(r * math.cos(2 * math.pi * k / n), 0.006, r * math.sin(2 * math.pi * k / n))) for k in range(n + 1)]
	top = [bm.verts.new(g(r * math.cos(2 * math.pi * k / n), 0.022, r * math.sin(2 * math.pi * k / n))) for k in range(n + 1)]
	for k in range(n):
		f = bm.faces.new([bot[k], top[k], top[k + 1], bot[k + 1]])
		for l, (u, v) in zip(f.loops, [(k / n, 0), (k / n, 1), ((k + 1) / n, 1), ((k + 1) / n, 0)]): l[uv].uv = (u, v)
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	me = bpy.data.meshes.new("label"); bm.to_mesh(me); bm.free()
	lo = bpy.data.objects.new("label", me); bpy.context.scene.collection.objects.link(lo); lo["keep_uv"] = 1; _new(lo, "pack_print")
	out("jar")

def poly_bag():
	W, D = 0.14, 0.2
	box((W, 0.012, D - 0.04), (0, 0.006, 0.02), "poly_clear", 0.005, segs=4)
	box((W, 0.003, 0.05), (0, 0.0015, -D / 2 + 0.025), "sticker", 0.0008)
	printed_quad(-W / 2 + 0.002, W / 2 - 0.002, -D / 2 + 0.002, -D / 2 + 0.048, 0.0034)
	out("poly_bag")

reset()
MATS["kraft_dark"] = dict(c=(0.45, 0.33, 0.22), r=0.8, m=0.0, tile=1.0)
for fn in (case_box, keycap_box, kraft_box, plate_sleeve, esd_pcb, switch_box, switch_bag, stab_pack, jar, poly_bag):
	fn()
