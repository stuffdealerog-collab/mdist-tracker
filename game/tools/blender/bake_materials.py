# Blender (4.5) batch script: bakes seamless PBR material sets for the flat with Cycles.
#   blender -b -P bake_materials.py -- <out_dir> [size=2048] [names...]
# Every material is a node graph on a 1x1 plane; colour, roughness and the tangent-space normal are baked
# into <name>_albedo.png, <name>_rough.png, <name>_normal.png. Tiling is exact: all noise is sampled on a 4D torus
# (cos/sin of u and v), plank and weave patterns use whole periods per tile.
import bpy, sys, os, math

a = sys.argv[sys.argv.index("--") + 1:]
OUT = a[0]
SIZE = int(a[1]) if len(a) > 1 else 2048
ONLY = a[2:]
os.makedirs(OUT, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.engine = "CYCLES"
sc.cycles.samples = 16
try:
	prefs = bpy.context.preferences.addons["cycles"].preferences
	prefs.compute_device_type = "OPTIX"
	prefs.get_devices()
	for d in prefs.devices: d.use = True
	sc.cycles.device = "GPU"
except Exception as e:
	print("GPU setup failed, CPU bake:", e)
bpy.ops.mesh.primitive_plane_add(size=1.0)
plane = bpy.context.active_object

# ------------------------------------------------------------------ node helpers
class G:
	def __init__(self, name):
		self.mat = bpy.data.materials.new(name); self.mat.use_nodes = True
		self.nt = self.mat.node_tree; self.n = self.nt.nodes; self.l = self.nt.links
		for x in list(self.n): self.n.remove(x)
		self.out = self.n.new("ShaderNodeOutputMaterial")
		self.bsdf = self.n.new("ShaderNodeBsdfPrincipled")
		self.l.new(self.bsdf.outputs[0], self.out.inputs[0])
		tc = self.n.new("ShaderNodeTexCoord")
		sep = self.n.new("ShaderNodeSeparateXYZ"); self.l.new(tc.outputs["UV"], sep.inputs[0])
		self.u = sep.outputs[0]; self.v = sep.outputs[1]
	def node(self, t, **kw):
		x = self.n.new(t)
		for k, v in kw.items(): setattr(x, k, v)
		return x
	def link(self, a, b): self.l.new(a, b)
	def val(self, v):
		x = self.n.new("ShaderNodeValue"); x.outputs[0].default_value = v; return x.outputs[0]
	def math(self, op, a, b=None, c=None):
		m = self.n.new("ShaderNodeMath"); m.operation = op
		for i, s in enumerate([a, b, c]):
			if s is None: continue
			if isinstance(s, (int, float)): m.inputs[i].default_value = s
			else: self.link(s, m.inputs[i])
		return m.outputs[0]
	def torus(self, ru, rv, ofs=0.0):
		"""4D point on a torus for seamless noise: (ru*cos 2πu, ru*sin 2πu, rv*cos 2πv) + W = rv*sin 2πv."""
		tu = self.math("MULTIPLY", self.u, 2 * math.pi); tv = self.math("MULTIPLY", self.v, 2 * math.pi)
		cx = self.math("MULTIPLY", self.math("COSINE", tu), ru); sx = self.math("MULTIPLY", self.math("SINE", tu), ru)
		cy = self.math("MULTIPLY", self.math("COSINE", tv), rv); sy = self.math("MULTIPLY", self.math("SINE", tv), rv)
		cmb = self.n.new("ShaderNodeCombineXYZ"); self.link(cx, cmb.inputs[0]); self.link(sx, cmb.inputs[1]); self.link(self.math("ADD", cy, ofs), cmb.inputs[2])
		return cmb.outputs[0], sy
	def noise(self, ru, rv, detail=6.0, rough=0.55, scale=1.0, ofs=0.0, dist=0.0):
		vec, w = self.torus(ru, rv, ofs)
		nz = self.n.new("ShaderNodeTexNoise"); nz.noise_dimensions = "4D"
		self.link(vec, nz.inputs["Vector"]); self.link(w, nz.inputs["W"])
		nz.inputs["Scale"].default_value = scale; nz.inputs["Detail"].default_value = detail; nz.inputs["Roughness"].default_value = rough
		nz.inputs["Distortion"].default_value = dist
		return nz.outputs["Fac"]
	def voronoi(self, ru, rv, scale=1.0, ofs=0.0, feature="F1"):
		vec, w = self.torus(ru, rv, ofs)
		vz = self.n.new("ShaderNodeTexVoronoi"); vz.voronoi_dimensions = "4D"; vz.feature = feature
		self.link(vec, vz.inputs["Vector"]); self.link(w, vz.inputs["W"]); vz.inputs["Scale"].default_value = scale
		return vz.outputs["Distance"]
	def ramp(self, fac, stops):
		r = self.n.new("ShaderNodeValToRGB"); self.link(fac, r.inputs[0])
		el = r.color_ramp.elements
		while len(el) < len(stops): el.new(0.5)
		for e, (p, c) in zip(el, stops): e.position = p; e.color = (*c, 1.0) if len(c) == 3 else c
		return r.outputs[0]
	def mix(self, a, b, fac, blend="MIX"):
		m = self.n.new("ShaderNodeMix"); m.data_type = "RGBA"; m.blend_type = blend
		for s, i in ((fac, 0), (a, 6), (b, 7)):
			if isinstance(s, (int, float)): m.inputs[i].default_value = s
			elif isinstance(s, tuple): m.inputs[i].default_value = (*s, 1.0)
			else: self.link(s, m.inputs[i])
		return m.outputs[2]
	def bump(self, h, strength=0.4, dist=0.02):
		b = self.n.new("ShaderNodeBump"); b.inputs["Strength"].default_value = strength; b.inputs["Distance"].default_value = dist
		self.link(h, b.inputs["Height"]); self.link(b.outputs[0], self.bsdf.inputs["Normal"])
	def color(self, c): self.link(c, self.bsdf.inputs["Base Color"])
	def rough(self, r):
		if isinstance(r, (int, float)): self.bsdf.inputs["Roughness"].default_value = r
		else: self.link(r, self.bsdf.inputs["Roughness"])
	def metal(self, m): self.bsdf.inputs["Metallic"].default_value = m

def hex3(h):
	h = h.lstrip("#"); c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
	return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)

# ------------------------------------------------------------------ materials
def wood_grain(g, light, dark, ru=3.0, rv=0.6, rings=26.0, ofs=0.0):
	"""Plain-sawn grain: noise-warped growth rings stretched along V, pores and medullary flecks."""
	warp = g.noise(ru * 0.35, rv * 0.35, 3, 0.5, 1.0, ofs)
	base = g.noise(ru, rv * 0.25, 2, 0.5, 1.0, ofs + 3.0)
	r = g.math("FRACT", g.math("MULTIPLY", g.math("ADD", base, g.math("MULTIPLY", warp, 0.6)), rings))
	ring = g.math("POWER", r, 2.2)
	pores = g.noise(ru * 6.0, rv * 1.2, 2, 0.6, 12.0, ofs + 7.0)
	fine = g.math("MULTIPLY", g.math("GREATER_THAN", pores, 0.62), 0.25)
	h = g.math("ADD", g.math("MULTIPLY", ring, 0.75), fine)
	col = g.mix(g.ramp(h, [(0.0, light), (1.0, dark)]), g.ramp(g.noise(ru * 0.5, rv * 0.5, 4, 0.6, 1.0, ofs + 11.0), [(0.0, (0.85, 0.85, 0.85)), (1.0, (1.1, 1.1, 1.1))]), 0.5, "MULTIPLY")
	return col, h

def m_planks(g, light, dark, n_cols=5, rows=2, gap="#3a2a1c", rough=0.42):
	"""Floor boards: n_cols boards across, each column split into `rows` lengths with a staggered joint."""
	u = g.math("MULTIPLY", g.u, n_cols)
	col_i = g.math("FLOOR", u)
	fu = g.math("FRACT", u)
	# per-column joint offset (deterministic pseudo random from the column index)
	off = g.math("FRACT", g.math("MULTIPLY", g.math("SINE", g.math("MULTIPLY", col_i, 12.9898)), 43758.5453))
	vv = g.math("MULTIPLY", g.math("ADD", g.v, off), rows)
	row_i = g.math("FLOOR", vv); fv = g.math("FRACT", vv)
	board_id = g.math("ADD", col_i, g.math("MULTIPLY", g.math("MODULO", row_i, rows), 7.0))
	rnd = g.math("FRACT", g.math("MULTIPLY", g.math("SINE", g.math("MULTIPLY", board_id, 78.233)), 12345.6789))
	col, h = wood_grain(g, light, dark, 5.0, 0.7, 28.0)
	tint = g.ramp(rnd, [(0.0, (0.82, 0.8, 0.78)), (0.5, (1.0, 1.0, 1.0)), (1.0, (1.12, 1.08, 1.02))])
	col = g.mix(col, tint, 1.0, "MULTIPLY")
	# bevelled seams
	eu = g.math("MINIMUM", fu, g.math("SUBTRACT", 1.0, fu)); ev = g.math("MINIMUM", fv, g.math("SUBTRACT", 1.0, fv))
	seam_u = g.math("SMOOTH_MIN", g.math("MULTIPLY", eu, 160.0), 1.0, 0.3); seam_v = g.math("SMOOTH_MIN", g.math("MULTIPLY", ev, 160.0 * n_cols / rows), 1.0, 0.3)
	seam = g.math("MINIMUM", seam_u, seam_v)
	col = g.mix(hex3(gap), col, seam)
	g.color(col); g.rough(g.math("ADD", g.math("MULTIPLY", h, 0.12), rough))
	g.bump(g.math("ADD", g.math("MULTIPLY", h, 0.15), g.math("MULTIPLY", seam, 0.85)), 0.5, 0.01)

def m_wood(g, light, dark, rough=0.48, rings=24.0):
	col, h = wood_grain(g, light, dark, 3.0, 0.6, rings)
	g.color(col); g.rough(g.math("ADD", g.math("MULTIPLY", h, 0.1), rough)); g.bump(h, 0.18, 0.005)

def m_plywood(g):
	col, h = wood_grain(g, hex3("dcc39b"), hex3("b9955f"), 2.0, 0.8, 9.0, 21.0)
	g.color(col); g.rough(0.74); g.bump(h, 0.08, 0.004)

def m_plaster(g, base="#e9e5dc"):
	big = g.noise(4.0, 4.0, 4, 0.55, 1.0, 1.0)
	fine = g.noise(40.0, 40.0, 3, 0.6, 1.0, 9.0)
	col = g.mix(hex3(base), g.ramp(big, [(0.0, (0.94, 0.94, 0.93)), (1.0, (1.03, 1.03, 1.02))]), 1.0, "MULTIPLY")
	g.color(col); g.rough(0.9); g.bump(g.math("ADD", g.math("MULTIPLY", big, 0.3), g.math("MULTIPLY", fine, 0.7)), 0.12, 0.004)

def m_fabric(g, base, n=96, rough=0.95):
	"""Plain weave: over/under threads, n threads per tile (whole periods -> seamless) + slub noise."""
	su = g.math("SINE", g.math("MULTIPLY", g.u, 2 * math.pi * n)); sv = g.math("SINE", g.math("MULTIPLY", g.v, 2 * math.pi * n))
	cu = g.math("SINE", g.math("MULTIPLY", g.u, math.pi * n)); cv = g.math("SINE", g.math("MULTIPLY", g.v, math.pi * n))
	over = g.math("GREATER_THAN", g.math("MULTIPLY", cu, cv), 0.0)
	warp = g.math("ABSOLUTE", sv); weft = g.math("ABSOLUTE", su)
	h = g.math("ADD", g.math("MULTIPLY", over, warp), g.math("MULTIPLY", g.math("SUBTRACT", 1.0, over), weft))
	slub = g.noise(18.0, 3.0, 3, 0.6, 1.0, 5.0)
	col = g.mix(hex3(base), g.ramp(g.math("ADD", g.math("MULTIPLY", h, 0.6), g.math("MULTIPLY", slub, 0.4)), [(0.0, (0.78, 0.78, 0.78)), (1.0, (1.12, 1.12, 1.12))]), 1.0, "MULTIPLY")
	g.color(col); g.rough(rough); g.bump(h, 0.6, 0.003)

def m_brushed(g, base="#b9bcc0", rough=0.32):
	st = g.noise(60.0, 1.0, 4, 0.7, 1.0, 3.0)
	col = g.mix(hex3(base), g.ramp(st, [(0.0, (0.9, 0.9, 0.9)), (1.0, (1.06, 1.06, 1.06))]), 1.0, "MULTIPLY")
	g.color(col); g.metal(1.0); g.rough(g.math("ADD", g.math("MULTIPLY", st, 0.12), rough)); g.bump(st, 0.05, 0.002)

def m_concrete(g, base="#8a8782"):
	n1 = g.noise(3.0, 3.0, 6, 0.6, 1.0, 1.0); pits = g.voronoi(14.0, 14.0, 1.0, 4.0)
	pit = g.math("LESS_THAN", pits, 0.05)
	col = g.mix(g.mix(hex3(base), g.ramp(n1, [(0.0, (0.82, 0.82, 0.82)), (1.0, (1.1, 1.1, 1.1))]), 1.0, "MULTIPLY"), (0.25, 0.25, 0.25), g.math("MULTIPLY", pit, 0.5))
	g.color(col); g.rough(g.math("ADD", g.math("MULTIPLY", n1, 0.15), 0.78)); g.bump(g.math("SUBTRACT", n1, g.math("MULTIPLY", pit, 0.6)), 0.3, 0.01)

def m_cardboard(g):
	flute = g.math("ABSOLUTE", g.math("SINE", g.math("MULTIPLY", g.u, math.pi * 140)))
	fib = g.noise(30.0, 4.0, 4, 0.6, 1.0, 2.0); blot = g.noise(3.0, 3.0, 4, 0.5, 1.0, 6.0)
	col = g.mix(hex3("b98b59"), g.ramp(g.math("ADD", g.math("MULTIPLY", fib, 0.6), g.math("MULTIPLY", blot, 0.4)), [(0.0, (0.86, 0.86, 0.86)), (1.0, (1.08, 1.06, 1.04))]), 1.0, "MULTIPLY")
	g.color(col); g.rough(0.9); g.bump(g.math("ADD", g.math("MULTIPLY", flute, 0.35), g.math("MULTIPLY", fib, 0.65)), 0.25, 0.004)

def m_mottle(g, light="#c9c8c3", dark="#8d8f8d"):
	"""Mottled vinyl wallpaper: soft grey cloud pattern with fine speckle and a light emboss."""
	big = g.noise(5.0, 5.0, 6, 0.62, 1.0, 2.0, 0.4)
	mid = g.noise(14.0, 14.0, 5, 0.6, 1.0, 5.0)
	spk = g.noise(60.0, 60.0, 2, 0.5, 1.0, 8.0)
	f = g.math("ADD", g.math("MULTIPLY", big, 0.55), g.math("ADD", g.math("MULTIPLY", mid, 0.3), g.math("MULTIPLY", spk, 0.15)))
	f = g.math("ADD", f, g.math("MULTIPLY", g.noise(30.0, 30.0, 4, 0.7, 1.0, 11.0), 0.35))
	col = g.ramp(f, [(0.45, hex3(dark)), (0.58, hex3("#a9aaa6")), (0.66, hex3(light)), (0.78, hex3("#dcdbd6"))])
	g.color(col); g.rough(0.78); g.bump(g.math("ADD", g.math("MULTIPLY", mid, 0.6), g.math("MULTIPLY", spk, 0.4)), 0.25, 0.004)

def m_venetian(g):
	"""Venetian plaster ceiling: blue-grey marbled trowel strokes, satin sheen."""
	w1 = g.noise(2.5, 2.5, 8, 0.65, 1.0, 1.0, 1.5)
	w2 = g.noise(7.0, 7.0, 6, 0.6, 1.0, 4.0, 0.8)
	f = g.math("ADD", g.math("MULTIPLY", w1, 0.7), g.math("MULTIPLY", w2, 0.3))
	col = g.ramp(f, [(0.3, hex3("#7f8b92")), (0.5, hex3("#a9b4b8")), (0.7, hex3("#d3d9da"))])
	g.color(col); g.rough(g.math("ADD", g.math("MULTIPLY", w2, 0.2), 0.32)); g.bump(w2, 0.08, 0.003)

MATS = {
	"wood_cream": lambda g: m_wood(g, hex3("ece6da"), hex3("cfc6b4"), 0.5, 30.0),
	"wood_dark": lambda g: m_wood(g, hex3("5a3a28"), hex3("2c1a10"), 0.38, 22.0),
	"floor_greyoak": lambda g: m_planks(g, hex3("cfcdc8"), hex3("7c7a76"), 7, 1, "#5e5c58", 0.5),
	"wallpaper_mottle": lambda g: m_mottle(g),
	"venetian": m_venetian,
	"floor_oak": lambda g: m_planks(g, hex3("d2a877"), hex3("9a6b3f")),
	"oak": lambda g: m_wood(g, hex3("c99d6a"), hex3("8d6038"), 0.45),
	"walnut": lambda g: m_wood(g, hex3("7a5236"), hex3("3d2516"), 0.42, 20.0),
	"plywood": m_plywood,
	"plaster": lambda g: m_plaster(g),
	"plaster_hall": lambda g: m_plaster(g, "#a9b7ae"),
	"fabric_grey": lambda g: m_fabric(g, "#8a8e93"),
	"fabric_blue": lambda g: m_fabric(g, "#7f93a8", 120),
	"fabric_linen": lambda g: m_fabric(g, "#e6e2da", 140),
	"rug": lambda g: m_fabric(g, "#7d6a58", 48, 1.0),
	"steel_brushed": lambda g: m_brushed(g),
	"concrete": lambda g: m_concrete(g),
	"cardboard": m_cardboard,
}

def bake(name, fn):
	g = G(name); fn(g)
	plane.data.materials.clear(); plane.data.materials.append(g.mat)
	img_nodes = []
	for kind in ("albedo", "rough", "normal"):
		img = bpy.data.images.new("%s_%s" % (name, kind), SIZE, SIZE, alpha=False, float_buffer=(kind == "normal"))
		img.colorspace_settings.name = "sRGB" if kind == "albedo" else "Non-Color"
		tn = g.n.new("ShaderNodeTexImage"); tn.image = img
		for x in g.n: x.select = False
		tn.select = True; g.n.active = tn
		if kind == "normal":
			sc.cycles.bake_type = "NORMAL"; sc.render.bake.normal_space = "TANGENT"
			bpy.ops.object.bake(type="NORMAL", margin=0)
		else:
			# temporarily route the wanted channel through an emission shader
			em = g.n.new("ShaderNodeEmission")
			src = g.bsdf.inputs["Base Color" if kind == "albedo" else "Roughness"]
			if src.is_linked: g.link(src.links[0].from_socket, em.inputs[0])
			else:
				v = src.default_value
				em.inputs[0].default_value = (v, v, v, 1.0) if isinstance(v, float) else v
			old = g.out.inputs[0].links[0].from_socket
			g.link(em.outputs[0], g.out.inputs[0])
			sc.cycles.bake_type = "EMIT"
			bpy.ops.object.bake(type="EMIT", margin=0)
			g.link(old, g.out.inputs[0]); g.n.remove(em)
		path = os.path.join(OUT, "%s_%s.png" % (name, kind))
		img.filepath_raw = path; img.file_format = "PNG"
		if kind == "normal": img.save_render(path)
		else: img.save()
		g.n.remove(tn)
		print("BAKED", path, flush=True)

for nm, fn in MATS.items():
	if ONLY and nm not in ONLY: continue
	bake(nm, fn)
