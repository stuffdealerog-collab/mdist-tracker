# Living part of the flat (photo4-6): the cream wooden bed with curved head/foot boards, a mattress, a pillow and a
# plaid duvet DRAPED BY CLOTH SIMULATION; the long beige curtain; the faded vintage rug with fringes; the projector
# sheet on the bed wall; the split air conditioner; the LED chandelier of crossed bars.
import random
from core import *
from core import _new, _PARTS

# ---- soft shapes ------------------------------------------------------------------------------------------------------
def softbox(size, center, material, radius=0.04, wrinkle=0.0, seed=1, name="soft"):
	"""Rounded box (bevel with many segments) with optional noise wrinkles, smooth shaded."""
	o = box(size, center, material, bevel=radius, segs=6, name=name)
	o["smooth"] = 1
	if wrinkle > 0:
		bpy.context.view_layer.objects.active = o
		for s in bpy.context.scene.objects: s.select_set(s == o)
		bpy.ops.object.modifier_apply(modifier="bevel")
		sub = o.modifiers.new("sub", "SUBSURF"); sub.levels = 1; bpy.ops.object.modifier_apply(modifier="sub")
		tex = bpy.data.textures.new("wr%d" % seed, "CLOUDS"); tex.noise_scale = 0.08; tex.noise_depth = 2
		d = o.modifiers.new("d", "DISPLACE"); d.texture = tex; d.strength = wrinkle; d.mid_level = 0.5
		bpy.ops.object.modifier_apply(modifier="d")
	return o

def drape(name, size_x, size_z, center, colliders, material, frames=45, res=48, pins=None, thickness=0.012, stiff=15.0, subdiv=0):
	"""Cloth: a grid of size (game x, z) released at `center` (game coords) and simulated onto the colliders.
	UVs stay the flat grid (in metres) so plaid lines follow the folds."""
	bpy.ops.mesh.primitive_grid_add(x_subdivisions=res, y_subdivisions=int(res * size_z / size_x), size=1.0)
	o = bpy.context.active_object; o.name = name
	o.scale = (size_x, size_z, 1); o.location = g(*center)
	bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
	uvl = o.data.uv_layers[0]
	for li, l in enumerate(o.data.loops):
		co = o.data.vertices[l.vertex_index].co
		uvl.data[li].uv = (co.x, co.y)
	if pins:
		vg = o.vertex_groups.new(name="pin")
		vg.add([v.index for v in o.data.vertices if pins(o.matrix_world @ v.co)], 1.0, "REPLACE")
	for c in colliders:
		cm = c.modifiers.new("collision", "COLLISION"); c.collision.thickness_outer = 0.006; c.collision.cloth_friction = 8.0
	cl = o.modifiers.new("cloth", "CLOTH"); st = cl.settings
	st.quality = 8; st.mass = 0.4; st.tension_stiffness = stiff; st.compression_stiffness = stiff; st.shear_stiffness = 5; st.bending_stiffness = 0.6
	st.air_damping = 2.0
	if pins: st.vertex_group_mass = "pin"
	cl.collision_settings.distance_min = 0.006; cl.collision_settings.use_self_collision = False
	sc = bpy.context.scene; sc.frame_start = 1; sc.frame_end = frames
	cl.point_cache.frame_start = 1; cl.point_cache.frame_end = frames
	for f in range(1, frames + 1): sc.frame_set(f)
	bpy.context.view_layer.objects.active = o
	for s in sc.objects: s.select_set(s == o)
	bpy.ops.object.modifier_apply(modifier="cloth")
	for c in colliders:
		if "collision" in c.modifiers: c.modifiers.remove(c.modifiers["collision"])
	sc.frame_set(1)
	if thickness > 0:
		so = o.modifiers.new("solid", "SOLIDIFY"); so.thickness = thickness; so.offset = 1.0
	if subdiv: o.modifiers.new("sub", "SUBSURF").levels = subdiv
	o["keep_uv"] = 1; o["smooth"] = 1
	return _new(o, material)

# ---- bed -----------------------------------------------------------------------------------------------------------
def _arched_board(fr, x0, x1, y0, ytop, rise, z0, z1, material, n=20):
	for k in range(n):
		a = k / n; b = (k + 1) / n
		ya = ytop + rise * math.sin(math.pi * a); yb = ytop + rise * math.sin(math.pi * b)
		fr.span(x0 + (x1 - x0) * a, x0 + (x1 - x0) * b + 0.0005, y0, (ya + yb) / 2, z0, z1, material, 0.0, grain="x")

def bed():
	L = BED_L = 2.05; Wb = 0.95
	cx = -2.08 + L / 2; cz = 1.83 + Wb / 2
	fr = Frame((cx, F, cz), "+x")                                   # local z runs from the head (-L/2) to the foot (+L/2)
	hw = Wb / 2; post = 0.055
	wood = "wood_cream"
	parts_before = len(_PARTS)
	# posts with rounded caps
	for (pz, h) in [(-L / 2 + post / 2, 0.98), (L / 2 - post / 2, 0.66)]:
		for px in (-hw + post / 2, hw - post / 2):
			fr.box((post, h, post), (px, h / 2, pz), wood, 0.006, grain="y")
			fr.box((post + 0.012, 0.03, post + 0.012), (px, h + 0.012, pz), wood, 0.012)
	# head and foot boards: framed panel with an arched top rail
	for (pz, top, rise) in [(-L / 2 + post / 2, 0.88, 0.07), (L / 2 - post / 2, 0.56, 0.05)]:
		_arched_board(fr, -hw + post, hw - post, top - 0.07, top, rise, pz - 0.016, pz + 0.016, wood)
		fr.span(-hw + post, hw - post, 0.25, top - 0.07, pz - 0.009, pz + 0.009, "wood_cream_b", 0.002, grain="y")
		fr.span(-hw + post, hw - post, 0.2, 0.27, pz - 0.018, pz + 0.018, wood, 0.004, grain="x")
	# side rails with a moulded lip, under-bed drawer front at the foot side (like photo5)
	for px in (-hw + 0.012, hw - 0.012):
		fr.span(px - 0.012, px + 0.012, 0.16, 0.33, -L / 2 + post, L / 2 - post, wood, 0.004, grain="z")
		fr.span(px - 0.016, px + 0.016, 0.31, 0.335, -L / 2 + post, L / 2 - post, wood, 0.006, grain="z")
	# slats + mattress (linen), slightly domed
	for k in range(14):
		zz = -L / 2 + 0.12 + k * (L - 0.24) / 13
		fr.span(-hw + 0.03, hw - 0.03, 0.27, 0.29, zz - 0.03, zz + 0.03, "plywood", 0.002)
	mat_o = softbox(fr.s(Wb - 0.05, 0.2, L - 0.12), fr.p(0, 0.39, 0.0), "fabric_linen", 0.04, name="mattress")
	pil = softbox(fr.s(0.62, 0.13, 0.4), fr.p(0, 0.55, -L / 2 + 0.32), "fabric_pillow", 0.05, wrinkle=0.01, seed=3, name="pillow")
	frame_parts = list(_PARTS[parts_before:])
	# duvet: draped from above over the mattress, folded back near the pillow
	duv = drape("duvet", 1.36, 1.62, fr.p(0, 0.62, 0.14), [mat_o, pil] + frame_parts, "fabric_plaid", frames=50, res=58, thickness=0.018)
	take("bed")
	collider("col_bed", fr.s(Wb, 0.62, L), fr.p(0, 0.31, 0))

# ---- curtain ------------------------------------------------------------------------------------------------------------
def curtain():
	"""One long panel left of the window (towards the bed), ceiling-high, gathered into soft pleats with a little
	puddle on the floor; a slim dark rod under the soffit."""
	import bmesh
	top = CEIL - 0.31; bot = F + 0.005
	z0, z1 = 1.12, 2.18; xw = X0 + 0.075
	bm = bmesh.new(); uv = bm.loops.layers.uv.new("UVMap")
	nz, ny = 84, 34; folds = 9
	rng = random.Random(5); amp = [rng.uniform(0.028, 0.05) for _ in range(folds + 2)]
	grid = []
	for j in range(ny + 1):
		v = j / ny; y = bot + (top - bot) * v
		row = []
		for i in range(nz + 1):
			u = i / nz
			k = u * folds; a = amp[int(k)] * (1 - (k - int(k))) + amp[int(k) + 1] * (k - int(k))
			fl = 1.0 + 0.35 * (1 - v) ** 2                              # pleats open towards the floor
			x = xw + math.sin(u * folds * 2 * math.pi) * a * fl + a * fl
			z = z0 + (z1 - z0) * u
			if v < 0.03: x += (0.03 - v) * 1.2                       # touches and slightly puddles on the floor
			row.append(bm.verts.new(g(x, y, z)))
		grid.append(row)
	for j in range(ny):
		for i in range(nz):
			f = bm.faces.new([grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]])
			for l in f.loops:
				co = l.vert.co
				l[uv].uv = ((-co.y - z0) * 1.6, co.z)                 # fabric is gathered: 1.6x the flat width
	me = bpy.data.meshes.new("curtain"); bm.to_mesh(me); bm.free()
	o = bpy.data.objects.new("curtain", me); bpy.context.scene.collection.objects.link(o)
	o["keep_uv"] = 1; o["smooth"] = 1
	_new(o, "fabric_curtain")
	cyl(0.01, 1.6, (X0 + 0.07, top + 0.012, 1.55), "black_plastic", axis="z", verts=16)
	for zz in (0.8, 2.3):
		box((0.06, 0.02, 0.02), (X0 + 0.04, top + 0.012, zz), "black_plastic", 0.004)
	take("curtain", smooth_angle=80.0)

# ---- rug --------------------------------------------------------------------------------------------------------------------
def rug():
	cx, cz, w, d = 0.55, 1.02, 3.1, 2.05
	o = box((w, 0.008, d), (cx, F + 0.004, cz), "rug", 0.002, name="rug")
	o["rug_uv"] = (cx - w / 2, cz - d / 2, w, d)
	rng = random.Random(3)
	for sx in (-1, 1):                                                # fringes on the short ends
		x = cx + sx * (w / 2 + 0.02)
		zz = cz - d / 2 + 0.01
		while zz < cz + d / 2 - 0.01:
			box((0.05 + rng.uniform(-0.01, 0.01), 0.003, 0.006), (x + sx * rng.uniform(-0.004, 0.004), F + 0.0025, zz), "rug_fringe", 0.0)
			zz += 0.012
	take("rug")

# ---- wall pieces -----------------------------------------------------------------------------------------------------------
def projector_sheet():
	"""White projection sheet hung on the bed wall: a top batten, the fabric with soft ripples."""
	import bmesh
	x0, x1, yt, yb, zw = -2.0, -0.55, F + 2.2, F + 1.05, Z1 - 0.012
	bm = bmesh.new(); uv = bm.loops.layers.uv.new("UVMap"); nx, ny = 60, 30
	grid = []
	for j in range(ny + 1):
		v = j / ny; y = yb + (yt - yb) * v
		row = []
		for i in range(nx + 1):
			u = i / nx; x = x0 + (x1 - x0) * u
			z = zw - 0.004 - 0.006 * math.sin(u * 7.3 + 1.1) * (1 - v) - 0.003 * math.sin(u * 23 + v * 9)
			row.append(bm.verts.new(g(x, y, z)))
		grid.append(row)
	for j in range(ny):
		for i in range(nx):
			f = bm.faces.new([grid[j][i], grid[j + 1][i], grid[j + 1][i + 1], grid[j][i + 1]])
			for l in f.loops: l[uv].uv = (l.vert.co.x, l.vert.co.z)
	me = bpy.data.meshes.new("sheet"); bm.to_mesh(me); bm.free()
	o = bpy.data.objects.new("sheet", me); bpy.context.scene.collection.objects.link(o)
	o["keep_uv"] = 1; o["smooth"] = 1; _new(o, "fabric_white")
	span(x0 - 0.02, x1 + 0.02, yt - 0.01, yt + 0.025, zw - 0.02, zw, "white_plastic", 0.004)
	take("projector_sheet", smooth_angle=80.0)

def ac_unit():
	"""Split air conditioner high on the bed wall (photo4/5): rounded white body, louvre, display, brand strip."""
	fr = Frame((-1.92, F + 2.36, Z1 - 0.11), "-z")
	W, H, D = 0.86, 0.29, 0.2
	fr.box((W, H, D), (0, 0, 0), "white_plastic", 0.03, segs=5)
	fr.span(-W / 2 + 0.03, W / 2 - 0.03, -H / 2 + 0.005, -H / 2 + 0.06, D / 2 - 0.03, D / 2 + 0.002, "white_plastic", 0.006)     # louvre
	fr.span(-W / 2 + 0.05, W / 2 - 0.05, -H / 2 + 0.065, -H / 2 + 0.07, D / 2 - 0.001, D / 2 + 0.002, "black_plastic")             # gap
	fr.span(0.22, 0.3, 0.02, 0.045, D / 2, D / 2 + 0.002, "screen_black", 0.002)                                                    # display
	fr.span(0.24, 0.27, 0.028, 0.038, D / 2 + 0.002, D / 2 + 0.0025, "glow_white")
	fr.span(-0.36, -0.28, 0.07, 0.085, D / 2, D / 2 + 0.002, "red_plastic", 0.002)                                                   # brand mark
	take("ac_unit")

def chandelier():
	"""LED chandelier like the photo: two sets of three long aluminium bars crossing at ~60 degrees at slightly
	different heights, glowing diffusers underneath, a round canopy and thin rods."""
	c = ((X0 + X1) / 2, CEIL - 0.13, (Z0 + Z1) / 2)
	cyl(0.07, 0.025, (c[0], CEIL - 0.012, c[2]), "steel_brushed", verts=40)
	sets = [(25.0, [-0.2, 0.0, 0.19], [1.15, 1.3, 1.0], 0.0), (-35.0, [-0.15, 0.05, 0.24], [1.05, 1.2, 0.95], -0.035)]
	k = 0
	for (ang, offs, lens, dy) in sets:
		a = math.radians(ang)
		side = (math.sin(a), 0, math.cos(a))
		for q in range(3):
			p = (c[0] + side[0] * offs[q], c[1] + dy - k * 0.006, c[2] + side[2] * offs[q])
			box((lens[q], 0.022, 0.034), p, "steel_brushed", 0.004, rot=(0, ang, 0))
			box((lens[q] - 0.02, 0.004, 0.026), (p[0], p[1] - 0.012, p[2]), "glow_white", 0.0015, rot=(0, ang, 0))
			cyl(0.002, CEIL - p[1] - 0.02, (p[0], (CEIL + p[1]) / 2, p[2]), "steel_brushed", verts=8)
			k += 1
	take("chandelier", lightmap=False)

def build():
	rug(); curtain(); projector_sheet(); ac_unit(); chandelier(); bed()
