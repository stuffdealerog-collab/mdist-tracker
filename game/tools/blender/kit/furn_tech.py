# Work and tech corner (photo4-6): the dark walnut workbench with a black-drawer pedestal, the white gaming desk
# with the monitor (its screen is a separate quad: the game renders KeyOS on it), the white glass PC case with RGB
# ring fans, keyboard + mouse, the small projector, the black/red gaming chair, the enclosed 3D printer on the
# cabinet, the ring light on a tripod and the party speaker.
import random
from core import *
from core import _new
from furn_living import softbox

PCX, PCY, PCZ = -1.545, -0.01, -0.36       # Home.PC_SPOT (desk top surface)

# ---- workbench --------------------------------------------------------------------------------------------------------
def bench():
	x0, x1, zc, d = BENCH["x0"], BENCH["x1"], BENCH["zc"], BENCH["d"]
	fr = Frame(((x0 + x1) / 2, F, zc), "+z")
	W = x1 - x0; hw = W / 2; hd = d / 2; top = -F                     # top surface at game y=0
	fr.span(-hw, hw, top - 0.036, top, -hd, hd, "wood_dark", 0.003, grain="x")
	fr.span(-hw, hw, top - 0.036, top - 0.002, hd - 0.001, hd + 0.002, "black_plastic", 0.001)                 # ABS edge
	# pedestal with 3 black drawers (chrome bar handles) on the left, panel leg on the right, modesty panel
	pw = 0.45; px0 = -hw + 0.02; px1 = px0 + pw
	fr.span(px0, px1, 0.0, top - 0.036, -hd + 0.02, hd - 0.03, "wood_dark", 0.002, grain="y")
	for i in range(3):
		yb = 0.03 + i * 0.225
		fr.span(px0 + 0.006, px1 - 0.006, yb, yb + 0.215, hd - 0.03, hd - 0.012, "black_plastic", 0.002)
		fr.box((0.16, 0.012, 0.012), ((px0 + px1) / 2, yb + 0.16, hd + 0.0), "chrome", 0.004)
		for sx in (-0.07, 0.07): fr.cyl(0.005, 0.014, ((px0 + px1) / 2 + sx, yb + 0.16, hd - 0.005), "chrome", axis="z", verts=10)
	fr.span(hw - 0.05, hw - 0.025, 0.0, top - 0.036, -hd + 0.02, hd - 0.02, "wood_dark", 0.002, grain="y")
	fr.span(px1, hw - 0.05, top - 0.25, top - 0.04, -hd + 0.02, -hd + 0.04, "wood_dark", 0.002, grain="x")
	# work mat, switch jars, tweezers on the top
	fr.span(-0.43, 0.52, top, top + 0.003, -0.24, 0.2, "fabric_mat", 0.002)
	for i, col in enumerate(["red_plastic", "jar_yellow", "jar_blue"]):
		fr.cyl(0.026, 0.04, (-0.18 + i * 0.07 + 0.3, top + 0.02, -0.29), col, verts=24)
		fr.cyl(0.028, 0.072, (-0.18 + i * 0.07 + 0.3, top + 0.036, -0.29), "glass_jar", verts=24, bevel=0.002)
		fr.cyl(0.029, 0.012, (-0.18 + i * 0.07 + 0.3, top + 0.078, -0.29), "black_plastic", verts=24)
	take("bench")
	collider("col_bench", fr.s(W, top, d), fr.p(0, top / 2, 0))

# ---- PC desk, monitor, PC, peripherals --------------------------------------------------------------------------------
def pc_desk():
	w, d = 0.95, 0.6
	fr = Frame((PCX, F, Z0 + d / 2), "+z")
	top = PCY - F
	fr.span(-w / 2, w / 2, top - 0.025, top, -d / 2, d / 2, "white_plastic", 0.003, grain="x")
	fr.span(-w / 2 + 0.03, w / 2 - 0.03, top, top + 0.003, -d / 2 + 0.05, d / 2 - 0.04, "fabric_mat", 0.002)     # desk mat
	fr.span(-w / 2, -w / 2 + 0.025, 0, top - 0.025, -d / 2 + 0.02, d / 2 - 0.02, "white_plastic", 0.002)
	# right: open shelf unit (three cubbies)
	sx0 = w / 2 - 0.32
	for xx in (sx0, w / 2 - 0.02):
		fr.span(xx, xx + 0.02, 0, top - 0.025, -d / 2 + 0.02, d / 2 - 0.02, "white_plastic", 0.002)
	for yy in (0.0, 0.24, 0.48):
		fr.span(sx0 + 0.02, w / 2 - 0.02, yy, yy + 0.02, -d / 2 + 0.02, d / 2 - 0.02, "white_plastic", 0.002)
	fr.span(-w / 2 + 0.025, sx0, top - 0.12, top - 0.025, -d / 2 + 0.02, -d / 2 + 0.035, "white_plastic", 0.002)
	# a few things in the cubbies
	fr.span(sx0 + 0.04, sx0 + 0.27, 0.02, 0.2, -0.15, 0.2, "cardboard_box", 0.004)
	fr.span(sx0 + 0.05, sx0 + 0.25, 0.26, 0.3, -0.2, 0.15, "book_black", 0.002)
	take("pc_desk")
	collider("col_pc_desk", fr.s(w, top, d), fr.p(0, top / 2, 0))
	# monitor: thin black panel on a stand; the screen surface is its own object for the game
	mz = PCZ - 0.05
	mfr = Frame((PCX, PCY, mz), "+z")
	mfr.box((0.62, 0.37, 0.022), (0, 0.33, 0), "black_plastic", 0.004)
	mfr.box((0.6, 0.36, 0.02), (0, 0.33, -0.018), "black_plastic", 0.01)
	mfr.box((0.05, 0.2, 0.025), (0, 0.13, -0.035), "steel_brushed", 0.006)
	mfr.box((0.26, 0.01, 0.17), (0, 0.005, -0.02), "steel_brushed", 0.004)
	mfr.span(-0.03, 0.03, 0.155, 0.16, 0.011, 0.0115, "glow_white")
	# keyboard (white TKL with pastel caps) and mouse
	kfr = Frame((PCX - 0.04, PCY, PCZ + 0.19), "+z")
	kfr.box((0.36, 0.022, 0.13), (0, 0.011, 0), "white_plastic", 0.006)
	cols = ["key_white", "key_white", "key_white", "key_mint", "key_pink"]
	rng = random.Random(4)
	for r in range(5):
		for c in range(16):
			kx = -0.165 + c * 0.0205; kz = -0.048 + r * 0.021
			kfr.box((0.0175, 0.008, 0.0175), (kx, 0.026, kz), "key_white" if rng.random() > 0.12 else rng.choice(cols[3:]), 0.0025)
	mfr2 = Frame((PCX + 0.32, PCY, PCZ + 0.19), "+z")
	softbox(mfr2.s(0.062, 0.035, 0.11), mfr2.p(0, 0.016, 0), "white_plastic", 0.015, name="mouse")
	# small white projector
	pfr = Frame((PCX + 0.33, PCY, PCZ - 0.12), "+z")
	softbox(pfr.s(0.24, 0.085, 0.19), pfr.p(0, 0.043, 0), "white_plastic", 0.012, name="proj")
	pfr.cyl(0.03, 0.02, (-0.06, 0.045, 0.1), "black_plastic", axis="z", verts=24)
	pfr.cyl(0.022, 0.006, (-0.06, 0.045, 0.111), "glass", axis="z", verts=24)
	take("pc_setup")
	# the screen quad (UV 0..1, faces +Z)
	import bmesh
	bm = bmesh.new(); uv = bm.loops.layers.uv.new("UVMap")
	sw, sh = 0.596, 0.336; cy = PCY + 0.33; sz = mz + 0.0115
	vs = [bm.verts.new(g(PCX + a * sw / 2, cy + b * sh / 2, sz)) for a, b in [(-1, -1), (1, -1), (1, 1), (-1, 1)]]
	f = bm.faces.new(vs)
	for l, (a, b) in zip(f.loops, [(0, 1), (1, 1), (1, 0), (0, 0)]): l[uv].uv = (a, b)
	me = bpy.data.meshes.new("monitor_screen"); bm.to_mesh(me); bm.free()
	o = bpy.data.objects.new("monitor_screen", me); bpy.context.scene.collection.objects.link(o)
	o["keep_uv"] = 1; _new(o, "screen_black")
	take("monitor_screen", lightmap=False)

def pc_case():
	"""White panoramic case (photo4): solid top, bottom, back and left side; glass front and right side; three
	ARGB ring fans stacked behind the front glass, a dark interior with the GPU and cooler."""
	fr = Frame((-0.83, 0.0, -0.38), "+z")                          # stands on the workbench top (game y=0)
	W, H, D = 0.24, 0.46, 0.44
	fr.box((W, 0.016, D), (0, 0.008, 0), "white_plastic", 0.004)
	fr.box((W, 0.016, D), (0, H - 0.008, 0), "white_plastic", 0.004)
	fr.box((0.012, H, D), (-W / 2 + 0.006, H / 2, 0), "white_plastic", 0.004)                   # left side (solid)
	fr.box((W, H, 0.012), (0, H / 2, -D / 2 + 0.006), "white_plastic", 0.004)                   # back
	for sx in (-1, 1):                                                                       # corner pillars of the glass
		fr.box((0.014, H, 0.014), (sx * (W / 2 - 0.007), H / 2, D / 2 - 0.007), "white_plastic", 0.003)
	fr.box((0.014, H, 0.014), (W / 2 - 0.007, H / 2, -D / 2 + 0.007), "white_plastic", 0.003)
	for sx in (-1, 1): fr.box((0.03, 0.016, 0.03), (sx * (W / 2 - 0.02), -0.004, sx * 0.0 + (D / 2 - 0.05)), "rubber", 0.004)
	for i in range(3):                                                                       # fans behind the front glass
		yy = 0.09 + i * 0.13
		fr.cyl(0.06, 0.025, (0.0, yy, D / 2 - 0.03), "white_plastic", axis="z", verts=40)
		fr.cyl(0.056, 0.004, (0.0, yy, D / 2 - 0.016), "glow_rgb", axis="z", verts=40, r2=0.046)
		fr.cyl(0.022, 0.008, (0.0, yy, D / 2 - 0.015), "white_plastic", axis="z", verts=20)
	fr.box((0.004, 0.3, 0.3), (-W / 2 + 0.025, 0.27, -0.04), "black_plastic", 0.002)             # motherboard
	fr.box((0.13, 0.05, 0.28), (-0.02, 0.15, -0.06), "black_plastic", 0.006)                    # GPU
	fr.box((0.13, 0.004, 0.26), (-0.02, 0.177, -0.06), "glow_rgb", 0.0)
	fr.cyl(0.035, 0.05, (-0.06, 0.33, -0.08), "steel_brushed", axis="x", verts=24)
	fr.box((W - 0.03, 0.06, D - 0.05), (0, 0.04, -0.01), "white_plastic", 0.004)               # PSU shroud
	take("pc_case")
	fr.box((W - 0.02, H - 0.03, 0.004), (0, H / 2, D / 2 - 0.002), "glass", 0.0)
	fr.box((0.004, H - 0.03, D - 0.02), (W / 2 - 0.002, H / 2, 0), "glass", 0.0)
	take("pc_case_glass", lightmap=False)

# ---- gaming chair -------------------------------------------------------------------------------------------------------
def chair():
	"""Black leatherette racing chair with red side inserts and stitching, faces the PC desk."""
	cx, cz = PCX + 0.05, 0.25
	yaw = math.pi - 0.2
	parts = []
	def P(x, y, z):
		c, s = math.cos(yaw), math.sin(yaw)
		return (cx + x * c + z * s, F + y, cz - x * s + z * c)
	def soft(size, pos, mat, r, rx=0.0):
		"""Rounded cushion built at the origin in chair axes, tilted by rx, turned by the chair yaw, then placed."""
		o = softbox(size, (0, 0, 0), mat, r)
		bpy.context.view_layer.objects.active = o
		for s in bpy.context.scene.objects: s.select_set(s == o)
		bpy.ops.object.modifier_apply(modifier="bevel")
		o.rotation_euler = (math.radians(-rx), 0, yaw); o.location = g(*P(*pos))
		bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
		return o
	# base: 5-star aluminium-ish legs, casters, gas lift
	for k in range(5):
		a = yaw + k * 2 * math.pi / 5
		x = 0.16 * math.cos(a); z = 0.16 * math.sin(a)
		box((0.32, 0.03, 0.045), (cx + x, F + 0.09, cz + z), "black_plastic", 0.01, rot=(0, -math.degrees(a), 0))
		cyl(0.025, 0.04, (cx + 0.31 * math.cos(a), F + 0.03, cz + 0.31 * math.sin(a)), "black_plastic", axis="x", verts=16)
		cyl(0.012, 0.03, (cx + 0.31 * math.cos(a), F + 0.06, cz + 0.31 * math.sin(a)), "red_plastic", verts=12)
	cyl(0.03, 0.06, (cx, F + 0.12, cz), "black_plastic", verts=20)
	cyl(0.025, 0.22, (cx, F + 0.24, cz), "chrome", verts=20)
	box((0.24, 0.04, 0.3), (cx, F + 0.37, cz), "black_plastic", 0.01)
	# seat: base cushion + side bolsters (red inserts)
	soft((0.36, 0.09, 0.48), (0, 0.44, 0), "leather_black", 0.035)
	for sx in (-1, 1):
		soft((0.08, 0.1, 0.46), (sx * 0.22, 0.47, 0), "leather_black", 0.035)
		soft((0.03, 0.06, 0.4), (sx * 0.175, 0.48, 0.0), "leather_red", 0.012)
	# backrest: tall, slightly reclined, wings, red side panels, headrest pillow, lumbar pillow
	soft((0.4, 0.78, 0.09), (0, 0.98, -0.26), "leather_black", 0.04, rx=-8)
	for sx in (-1, 1):
		soft((0.07, 0.62, 0.12), (sx * 0.22, 0.9, -0.24), "leather_black", 0.03, rx=-8)
		soft((0.025, 0.55, 0.05), (sx * 0.188, 0.92, -0.2), "leather_red", 0.01, rx=-8)
	soft((0.24, 0.12, 0.07), (0, 1.25, -0.2), "leather_black", 0.04, rx=-8)
	soft((0.26, 0.13, 0.07), (0, 0.66, -0.2), "leather_black", 0.045)
	# armrests
	for sx in (-1, 1):
		soft((0.03, 0.2, 0.05), (sx * 0.27, 0.55, 0.0), "black_plastic", 0.008)
		soft((0.08, 0.03, 0.24), (sx * 0.27, 0.66, 0.02), "black_plastic", 0.012)
	take("chair")
	collider("col_chair", (0.6, 1.2, 0.6), (cx, F + 0.6, cz))

# ---- 3D printer, ring light, speaker -------------------------------------------------------------------------------------
def printer():
	fr = Frame((1.3, F + 0.645, Z0 + 0.23), "+z")
	W, H, D = 0.39, 0.46, 0.4
	for sx in (-1, 1): fr.box((0.02, H, D), (sx * (W / 2 - 0.01), H / 2, 0), "black_plastic", 0.006)
	fr.box((W, 0.03, D), (0, 0.015, 0), "black_plastic", 0.006)
	fr.box((W, 0.02, D), (0, H - 0.01, 0), "black_plastic", 0.006)
	fr.box((W, H, 0.02), (0, H / 2, -D / 2 + 0.01), "black_plastic", 0.006)
	fr.box((W - 0.04, 0.012, D - 0.04), (0, 0.11, 0), "steel_brushed", 0.002)                   # bed
	fr.box((W - 0.06, 0.004, D - 0.06), (0, 0.118, 0), "fabric_mat", 0.001)
	fr.box((0.07, 0.06, 0.05), (0.03, 0.33, 0.02), "black_plastic", 0.008)                     # toolhead
	fr.box((W - 0.04, 0.012, 0.012), (0, 0.33, 0.02), "steel_brushed", 0.002)
	fr.box((0.07, 0.045, 0.006), (W / 2 - 0.06, 0.08, D / 2 + 0.003), "screen_black", 0.002)
	fr.span(W / 2 - 0.09, W / 2 - 0.03, 0.065, 0.095, D / 2 + 0.006, D / 2 + 0.0065, "glow_white")
	fr.cyl(0.1, 0.07, (0, 0.2, -D / 2 - 0.04), "red_plastic", axis="z", verts=32)                 # spool on the back
	take("printer")
	fr.box((W - 0.02, H - 0.04, 0.004), (0, H / 2, D / 2), "glass_dark", 0.0)
	fr.box((W - 0.02, 0.004, D - 0.02), (0, H + 0.002, 0), "glass_dark", 0.0)
	take("printer_glass", lightmap=False)

def ring_light():
	x, z = 1.66, -0.32
	for k in range(3):
		a = k * 2 * math.pi / 3 + 0.4
		box((0.4, 0.012, 0.016), (x + 0.17 * math.cos(a), F + 0.1, z + 0.17 * math.sin(a)), "black_plastic", 0.003, rot=(0, -math.degrees(a), 22))
	cyl(0.014, 1.0, (x, F + 0.58, z), "black_plastic", verts=16)
	cyl(0.011, 0.6, (x, F + 1.35, z), "steel_brushed", verts=16)
	ring_y = F + 1.78
	bpy.ops.mesh.primitive_torus_add(major_radius=0.23, minor_radius=0.022, major_segments=64, minor_segments=12)
	o = bpy.context.active_object; o.name = "ring"; o.rotation_euler = (math.pi / 2, 0, 0); o.location = g(x, ring_y, z + 0.02)
	bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
	_new(o, "black_plastic")
	bpy.ops.mesh.primitive_torus_add(major_radius=0.23, minor_radius=0.014, major_segments=64, minor_segments=8)
	o = bpy.context.active_object; o.name = "ring_led"; o.rotation_euler = (math.pi / 2, 0, 0); o.location = g(x, ring_y, z + 0.035)
	bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
	_new(o, "glow_white")
	box((0.07, 0.13, 0.012), (x, ring_y, z + 0.03), "black_plastic", 0.004)                   # phone holder
	take("ring_light", lightmap=False)

def speaker():
	"""Party speaker: tall black cabinet, two woofers with red light rings, top handle, wheels."""
	x, z, yaw = 2.15, 2.52, math.pi + 0.35
	fr = Frame((x, F, z), "-z")
	W, H, D = 0.32, 0.66, 0.32
	fr.box((W, H, D), (0, H / 2 + 0.03, 0), "black_plastic", 0.03, segs=4)
	fr.span(-W / 2 + 0.02, W / 2 - 0.02, 0.05, H - 0.02, D / 2 - 0.002, D / 2 + 0.003, "mesh_black", 0.004)
	for yy in (0.2, 0.45):
		fr.cyl(0.11, 0.012, (0, yy, D / 2 + 0.004), "rubber", axis="z", verts=40)
		fr.cyl(0.115, 0.004, (0, yy, D / 2 + 0.01), "glow_red", axis="z", verts=40, r2=0.104)
		fr.cyl(0.035, 0.02, (0, yy, D / 2 + 0.012), "black_plastic", axis="z", verts=24)
	fr.box((0.2, 0.03, 0.05), (0, H + 0.045, -0.02), "black_plastic", 0.012)
	fr.span(-0.08, 0.08, H + 0.0, H + 0.004, 0.06, 0.12, "red_plastic", 0.002)
	for sx in (-1, 1): fr.cyl(0.03, 0.03, (sx * 0.12, 0.03, -D / 2 + 0.04), "rubber", axis="x", verts=20)
	sp = take("speaker", pivot=(x, F, z))
	if sp:
		sp.rotation_euler = (0, 0, -0.35)                    # slightly turned like the photo
	collider("col_speaker", (0.34, 0.66, 0.34), (x, F + 0.33, z))

def build():
	bench(); pc_desk(); pc_case(); chair(); printer(); ring_light(); speaker()
