# Blender (4.5) batch script: clean, game-ready hard-surface furniture built from real measurements.
#   blender -b -P furniture.py -- <out_dir> [names...]
# Studio approach: flat planar panels, small bevels on every edge (weighted normals keep faces flat),
# real proportions, material slots by name (cream_wood, beige_top, handle_white, dark_wood, black, fabric_*…)
# that the game maps onto its baked PBR materials. One .glb per piece + a preview render.
import bpy, bmesh, sys, os, math
from mathutils import Vector

a = sys.argv[sys.argv.index("--") + 1:]
OUT = a[0]; ONLY = a[1:]
os.makedirs(OUT, exist_ok=True)

PREVIEW_COL = {"cream_wood": (0.86, 0.82, 0.74), "beige_top": (0.84, 0.78, 0.68), "handle_white": (0.95, 0.94, 0.91), "dark_wood": (0.25, 0.15, 0.09),
	"black": (0.03, 0.03, 0.035), "chrome": (0.8, 0.8, 0.82), "fabric_blue": (0.62, 0.72, 0.84), "fabric_white": (0.92, 0.92, 0.9),
	"fabric_grey": (0.7, 0.7, 0.72), "white_plastic": (0.93, 0.93, 0.92), "glass": (0.6, 0.65, 0.7), "gold": (0.78, 0.62, 0.3),
	"book_red": (0.55, 0.08, 0.07), "book_blue": (0.1, 0.2, 0.45), "book_green": (0.1, 0.35, 0.18), "book_white": (0.88, 0.86, 0.8), "book_black": (0.05, 0.05, 0.05),
	"book_orange": (0.85, 0.4, 0.08), "book_teal": (0.1, 0.45, 0.45), "glow_purple": (0.7, 0.4, 1.0), "glow_white": (1, 1, 1), "red_accent": (0.75, 0.05, 0.05),
	"spool_0": (0.9, 0.9, 0.9), "spool_1": (0.1, 0.1, 0.1), "spool_2": (0.8, 0.1, 0.1), "spool_3": (0.1, 0.4, 0.8)}

def reset():
	bpy.ops.wm.read_factory_settings(use_empty=True)

def mat(name):
	m = bpy.data.materials.get(name)
	if m: return m
	m = bpy.data.materials.new(name); m.use_nodes = True
	b = m.node_tree.nodes["Principled BSDF"]; b.inputs["Base Color"].default_value = (*PREVIEW_COL.get(name, (0.8, 0.8, 0.8)), 1)
	b.inputs["Roughness"].default_value = 0.2 if name in ("chrome", "glass") else 0.55
	if name == "chrome": b.inputs["Metallic"].default_value = 1.0
	return m

def box(name, size, loc, material, bevel=0.004, segs=3, parent=None):
	"""Axis-aligned box (Blender Z up; size = (x, y, z) in metres, loc = centre) with bevelled edges."""
	bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
	o = bpy.context.active_object; o.name = name; o.scale = size
	bpy.ops.object.transform_apply(scale=True)
	if bevel > 0:
		m = o.modifiers.new("bevel", "BEVEL"); m.width = bevel; m.segments = segs; m.limit_method = "ANGLE"; m.harden_normals = True
	o.data.materials.append(mat(material))
	return o

def cyl(name, r, depth, loc, material, rot=(0, 0, 0), verts=24, bevel=0.002):
	bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=depth, vertices=verts, location=loc, rotation=rot)
	o = bpy.context.active_object; o.name = name
	if bevel > 0:
		m = o.modifiers.new("bevel", "BEVEL"); m.width = bevel; m.segments = 2; m.limit_method = "ANGLE"; m.harden_normals = True
	o.data.materials.append(mat(material)); return o

def arch_panel(name, width, thick, depth, rise, loc, material, segs=32):
	"""Flat board whose top edge is a gentle arc (bed headboard rail, bookshelf crown). Width along X, thickness along Y."""
	bm = bmesh.new()
	pts = []
	for i in range(segs + 1):
		t = i / segs; x = -width / 2 + t * width
		pts.append((x, math.sin(t * math.pi) * rise))
	top = [bm.verts.new((x, -thick / 2, depth + z)) for x, z in pts]
	topb = [bm.verts.new((x, thick / 2, depth + z)) for x, z in pts]
	bl = bm.verts.new((-width / 2, -thick / 2, 0)); br = bm.verts.new((width / 2, -thick / 2, 0))
	blb = bm.verts.new((-width / 2, thick / 2, 0)); brb = bm.verts.new((width / 2, thick / 2, 0))
	bm.faces.new([bl] + top + [br])
	bm.faces.new([brb] + list(reversed(topb)) + [blb])
	for i in range(segs): bm.faces.new([top[i], topb[i], topb[i + 1], top[i + 1]])
	bm.faces.new([bl, blb, topb[0], top[0]]); bm.faces.new([br, top[-1], topb[-1], brb]); bm.faces.new([bl, br, brb, blb])
	me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
	o = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(o); o.location = loc
	bpy.context.view_layer.objects.active = o; o.select_set(True)
	bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT"); bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.object.mode_set(mode="OBJECT")
	m = o.modifiers.new("bevel", "BEVEL"); m.width = 0.004; m.segments = 3; m.limit_method = "ANGLE"; m.harden_normals = True
	o.data.materials.append(mat(material)); return o

def soft(name, size, loc, material, r=0.04, noise=0.0, seed=1):
	"""Soft cushion / mattress / blanket: rounded box via subdivision, optional gentle wrinkles."""
	o = box(name, size, loc, material, bevel=r, segs=4)
	m = o.modifiers.new("sub", "SUBSURF"); m.levels = 1; m.render_levels = 1
	if noise > 0:
		tex = bpy.data.textures.new(name + "_n", "CLOUDS"); tex.noise_scale = 0.18; tex.noise_depth = 2
		d = o.modifiers.new("wrinkle", "DISPLACE"); d.texture = tex; d.strength = noise; d.texture_coords = "GLOBAL"
	return o

def finish(name, front="-Y"):
	"""Apply modifiers, join everything, weighted normals, smart UV, origin at bottom centre, export + preview."""
	objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
	for o in objs:
		bpy.context.view_layer.objects.active = o
		for m in list(o.modifiers): bpy.ops.object.modifier_apply(modifier=m.name)
	for o in bpy.context.scene.objects: o.select_set(o.type == "MESH")
	bpy.context.view_layer.objects.active = objs[0]
	bpy.ops.object.join(); o = bpy.context.active_object; o.name = name
	bpy.ops.object.shade_smooth()
	wn = o.modifiers.new("wn", "WEIGHTED_NORMAL"); wn.keep_sharp = True; wn.weight = 100
	bpy.ops.object.modifier_apply(modifier="wn")
	bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
	bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.003, scale_to_bounds=False)
	bpy.ops.object.mode_set(mode="OBJECT")
	bb = [o.matrix_world @ v.co for v in o.data.vertices]
	mn = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb))); mx = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
	c = Vector(((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, mn.z))
	from mathutils import Matrix
	o.data.transform(Matrix.Translation(-c)); o.location = (0, 0, 0)
	tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
	path = os.path.join(OUT, name + ".glb")
	bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_yup=True, export_apply=True, export_materials="EXPORT", export_normals=True)
	print("CLEAN %s tris=%d size=%.2f x %.2f x %.2f" % (name, tris, mx.x - mn.x, mx.y - mn.y, mx.z - mn.z), flush=True)
	preview(o, os.path.join(OUT, "_preview_" + name + ".png"))

def preview(o, path):
	sc = bpy.context.scene; sc.render.engine = "BLENDER_EEVEE_NEXT"; sc.render.resolution_x = 900; sc.render.resolution_y = 900
	w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
	w.node_tree.nodes["Background"].inputs[0].default_value = (0.8, 0.81, 0.83, 1); w.node_tree.nodes["Background"].inputs[1].default_value = 0.8
	d = max(o.dimensions); tgt = Vector((0, 0, o.dimensions.z * 0.45))
	cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam; cam.data.lens = 50
	cam.location = tgt + Vector((d * 0.85, -d * 1.25, d * 0.62)); cam.rotation_euler = (tgt - cam.location).to_track_quat("-Z", "Y").to_euler()
	sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); sc.collection.objects.link(sun); sun.data.energy = 3.0
	sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(30))
	sc.render.filepath = path; bpy.ops.render.render(write_still=True)

# ------------------------------------------------------------------ pieces (Blender: X width, Y depth (front = -Y), Z up)
def chest_drawers():
	"""Cream chest of four drawers with long white bar handles on stand-offs and a glossy beige top (photo 2)."""
	W, D, H = 1.0, 0.5, 0.82
	box("carcass", (W, D - 0.02, H - 0.06), (0, 0.01, 0.06 + (H - 0.06) / 2), "cream_wood", 0.006)
	box("plinth", (W - 0.04, D - 0.06, 0.06), (0, 0.02, 0.03), "cream_wood", 0.004)
	box("top", (W + 0.03, D + 0.02, 0.03), (0, 0.0, H + 0.015), "beige_top", 0.008, 4)
	gap = 0.006; dh = (H - 0.08 - 3 * gap) / 4
	for i in range(4):
		z = 0.07 + i * (dh + gap) + dh / 2
		box("front%d" % i, (W - 0.03, 0.02, dh), (0, -D / 2 + 0.002, z), "cream_wood", 0.004)
		# grooves on the front panel (as on the real piece)
		for gy in (-1, 1):
			box("groove%d%d" % (i, gy), (W - 0.12, 0.003, 0.004), (0, -D / 2 - 0.009, z + gy * (dh / 2 - 0.022)), "beige_top", 0.0)
		box("handle%d" % i, (0.24, 0.022, 0.028), (0, -D / 2 - 0.036, z + 0.012), "handle_white", 0.008, 4)
		for sx in (-0.1, 0.1): cyl("post%d" % i, 0.006, 0.026, (sx, -D / 2 - 0.018, z + 0.012), "handle_white", rot=(math.pi / 2, 0, 0), verts=12, bevel=0)
	finish("clean_chest_drawers")

def bed_single():
	"""Single bed: cream frame with arched head/foot rails, side rails, trundle drawer, mattress, light blue blanket, pillow (photos 4-6)."""
	L, Wd = 2.0, 0.95
	# head (at -X) and foot boards: posts + arched top rail + panel
	for sx, h in ((-1, 0.86), (1, 0.62)):
		x = sx * (L / 2 - 0.025)
		for sy in (-1, 1):
			box("post", (0.055, 0.055, h), (x, sy * (Wd / 2 - 0.0275), h / 2), "cream_wood", 0.006)
		panel = arch_panel("rail", Wd - 0.04, 0.045, h - 0.1, 0.05, (x, 0, 0), "cream_wood")
		panel.rotation_euler = (0, 0, math.pi / 2); bpy.context.view_layer.objects.active = panel; bpy.ops.object.transform_apply(rotation=True)
		box("panel_low", (0.025, Wd - 0.08, h * 0.35), (x, 0, 0.22 + h * 0.175), "cream_wood", 0.004)
	# side rails and the trundle drawer front
	for sy in (-1, 1):
		box("side", (L - 0.1, 0.03, 0.17), (0, sy * (Wd / 2 - 0.015), 0.33), "cream_wood", 0.005)
	box("trundle", (L - 0.2, 0.025, 0.16), (0.02, -Wd / 2 + 0.05, 0.11), "cream_wood", 0.005)
	cyl("knob", 0.012, 0.02, (0.6, -Wd / 2 + 0.03, 0.12), "cream_wood", rot=(math.pi / 2, 0, 0), verts=16)
	box("base", (L - 0.12, Wd - 0.06, 0.04), (0, 0, 0.27), "cream_wood", 0.003)
	# bedding
	soft("mattress", (L - 0.12, Wd - 0.07, 0.18), (0, 0, 0.38), "fabric_white", 0.05)
	blanket = soft("blanket", (L - 0.32, Wd + 0.04, 0.05), (0.09, 0, 0.485), "fabric_blue", 0.025, noise=0.012)
	soft("blanket_fold", (0.28, Wd + 0.03, 0.07), (-0.62, 0, 0.5), "fabric_blue", 0.03, noise=0.008)
	soft("pillow", (0.38, 0.62, 0.13), (-L / 2 + 0.3, 0, 0.53), "fabric_grey", 0.055, noise=0.006)
	finish("clean_bed_single")

def bookshelf():
	"""Tall narrow cream bookshelf with an arched crown, five shelves, books and a few objects (photos 1, 3)."""
	W, D, H = 0.55, 0.3, 1.82
	for sx in (-1, 1): box("side", (0.022, D, H), (sx * (W / 2 - 0.011), 0, H / 2), "cream_wood", 0.004)
	box("back", (W - 0.02, 0.008, H - 0.04), (0, D / 2 - 0.004, H / 2), "cream_wood", 0.0)
	box("plinth", (W - 0.03, 0.02, 0.07), (0, -D / 2 + 0.02, 0.035), "cream_wood", 0.003)
	crown = arch_panel("crown", W + 0.02, 0.025, 0.06, 0.07, (0, -D / 2 + 0.012, H - 0.06), "cream_wood")
	box("crown_top", (W + 0.02, D, 0.02), (0, 0, H - 0.01), "cream_wood", 0.003)
	levels = [0.07, 0.42, 0.77, 1.12, 1.45]
	for z in levels: box("shelf", (W - 0.044, D - 0.02, 0.02), (0, 0.005, z), "cream_wood", 0.003)
	import random
	rng = random.Random(7)
	pal = ["book_red", "book_blue", "book_green", "book_white", "book_black", "book_orange", "book_teal"]
	for li, z in enumerate(levels[:-1] + [levels[-1]]):
		x = -W / 2 + 0.035
		lim = W / 2 - 0.03 - (0.12 if li in (0, 4) else 0.0)
		while x < lim:
			bw = rng.uniform(0.018, 0.04); bh = rng.uniform(0.18, 0.28) if li != 4 else rng.uniform(0.14, 0.2); bd = rng.uniform(0.16, 0.22)
			if x + bw > lim: break
			tilt = 0.0
			b = box("book", (bw, bd, bh), (x + bw / 2, 0.02, z + 0.01 + bh / 2), rng.choice(pal), 0.002, 2)
			b.rotation_euler = (0, tilt, 0)
			x += bw + 0.002
		if li == 0:
			cyl("jar", 0.07, 0.2, (W / 2 - 0.1, 0.0, z + 0.11), "black", verts=24)
	finish("clean_bookshelf")

def gaming_desk():
	"""Compact white computer desk: top with a black mat, left panel leg, small open shelf unit on the right (photo 4)."""
	W, D, H = 0.95, 0.6, 0.75
	box("top", (W, D, 0.025), (0, 0, H - 0.0125), "white_plastic", 0.004)
	box("mat", (W - 0.06, D - 0.12, 0.003), (0, 0.02, H + 0.0015), "black", 0.001)
	box("leg_l", (0.025, D - 0.04, H - 0.025), (-W / 2 + 0.015, 0, (H - 0.025) / 2), "white_plastic", 0.003)
	sx = W / 2 - 0.16
	for x in (sx - 0.15, W / 2 - 0.0125): box("unit_side", (0.022, D - 0.04, H - 0.025), (x, 0, (H - 0.025) / 2), "white_plastic", 0.003)
	for i in range(4): box("unit_shelf", (0.3, D - 0.06, 0.018), (sx, 0.0, 0.03 + i * 0.22), "white_plastic", 0.003)
	box("back_bar", (W - 0.36, 0.018, 0.12), (-0.17, D / 2 - 0.03, H - 0.09), "white_plastic", 0.003)
	finish("clean_gaming_desk")

def pc_white():
	"""White mid-tower: glass side panel, three front fans with lit rings (glow material), feet (photo 4)."""
	W, D, H = 0.23, 0.44, 0.46
	box("body", (W, D, H), (0, 0, H / 2 + 0.015), "white_plastic", 0.008, 4)
	box("glass", (0.004, D - 0.04, H - 0.05), (-W / 2 - 0.001, 0, H / 2 + 0.015), "glass", 0.0)
	box("mesh_front", (W - 0.03, 0.006, H - 0.04), (0, -D / 2 - 0.002, H / 2 + 0.015), "white_plastic", 0.002)
	for i in range(3):
		z = 0.09 + i * 0.13
		ring = cyl("fan_ring", 0.055, 0.006, (0, -D / 2 - 0.006, z + 0.015), "glow_purple", rot=(math.pi / 2, 0, 0), verts=32, bevel=0)
		cyl("fan_hub", 0.045, 0.008, (0, -D / 2 - 0.007, z + 0.015), "white_plastic", rot=(math.pi / 2, 0, 0), verts=32, bevel=0)
		cyl("fan_in", 0.052, 0.004, (-W / 2 + 0.01, 0, z + 0.015), "glow_purple", rot=(0, math.pi / 2, 0), verts=32, bevel=0)
	for sx in (-1, 1):
		for sy in (-1, 1): box("foot", (0.03, 0.04, 0.015), (sx * 0.08, sy * 0.17, 0.0075), "black", 0.003)
	finish("clean_pc_white")

def ac_unit():
	"""Wall split air conditioner indoor unit with a curved front and louvre."""
	W, D, H = 0.85, 0.2, 0.28
	box("body", (W, D, H), (0, 0, H / 2), "white_plastic", 0.03, 5)
	box("louvre", (W - 0.08, 0.02, 0.03), (0, -D / 2 + 0.02, 0.04), "white_plastic", 0.008)
	box("panel_line", (W - 0.06, 0.004, 0.004), (0, -D / 2 - 0.001, H - 0.06), "black", 0.0)
	box("display", (0.06, 0.004, 0.02), (W / 2 - 0.12, -D / 2 - 0.001, H - 0.12), "black", 0.002)
	finish("clean_ac_unit")

def projector():
	"""Small white home projector with a lens on the front."""
	box("body", (0.26, 0.2, 0.085), (0, 0, 0.0425 + 0.008), "white_plastic", 0.015, 4)
	cyl("lens_ring", 0.032, 0.02, (0.06, -0.105, 0.05), "black", rot=(math.pi / 2, 0, 0), verts=32)
	cyl("lens", 0.024, 0.006, (0.06, -0.116, 0.05), "glass", rot=(math.pi / 2, 0, 0), verts=32, bevel=0)
	for sx in (-1, 1): box("foot", (0.02, 0.02, 0.008), (sx * 0.1, 0.0, 0.004), "black", 0.002)
	finish("clean_projector")

def speaker():
	"""Tall black party speaker: rounded body, two woofer rings, red accent strips, handle on top (photo 2)."""
	W, D, H = 0.3, 0.27, 0.62
	box("body", (W, D, H), (0, 0, H / 2 + 0.02), "black", 0.025, 5)
	for z, r in ((0.17, 0.11), (0.42, 0.09)):
		cyl("woofer_ring", r, 0.012, (0, -D / 2 - 0.004, z), "red_accent", rot=(math.pi / 2, 0, 0), verts=40)
		cyl("woofer", r - 0.012, 0.014, (0, -D / 2 - 0.006, z), "black", rot=(math.pi / 2, 0, 0), verts=40)
		cyl("cap", 0.03, 0.02, (0, -D / 2 - 0.012, z), "black", rot=(math.pi / 2, 0, 0), verts=24)
	box("tweeter", (0.12, 0.01, 0.03), (0, -D / 2 - 0.003, H - 0.05), "red_accent", 0.004)
	box("handle", (0.16, 0.04, 0.03), (0, 0, H + 0.035), "black", 0.012)
	for sx in (-1, 1): box("wheel", (0.03, 0.06, 0.06), (sx * (W / 2 - 0.02), D / 2 - 0.04, 0.03), "black", 0.01)
	finish("clean_speaker")

def printer3d():
	"""Enclosed desktop 3D printer with a glass door and a filament box (AMS) on top (photos 1, 4, 6)."""
	W, D, H = 0.39, 0.4, 0.46
	box("frame", (W, D, H), (0, 0, H / 2), "black", 0.012, 4)
	box("door", (W - 0.05, 0.006, H - 0.09), (0, -D / 2 - 0.002, H / 2 + 0.01), "glass", 0.0)
	box("door_frame", (W - 0.03, 0.004, 0.025), (0, -D / 2 - 0.003, H - 0.035), "black", 0.002)
	box("bed_plate", (W - 0.08, D - 0.12, 0.008), (0, 0.0, 0.08), "chrome", 0.002)
	box("screen", (0.08, 0.004, 0.05), (W / 2 - 0.07, -D / 2 - 0.004, H - 0.03), "glow_white", 0.002)
	box("ams", (W - 0.02, D - 0.08, 0.15), (0, 0.02, H + 0.075), "black", 0.02, 4)
	box("ams_lid", (W - 0.04, D - 0.12, 0.01), (0, 0.0, H + 0.152), "glass", 0.004)
	for i in range(4): cyl("spool", 0.05, 0.065, (-0.12 + i * 0.08, 0.02, H + 0.09), "spool_%d" % i, rot=(0, math.pi / 2, 0), verts=24)
	finish("clean_printer3d")

def ring_light():
	"""LED ring light on a black tripod stand."""
	H = 1.85
	for k in range(3):
		ang = k * 2 * math.pi / 3
		leg = cyl("leg", 0.009, 0.62, (math.cos(ang) * 0.17, math.sin(ang) * 0.17, 0.27), "black", verts=10, bevel=0)
		leg.rotation_euler = (math.sin(ang) * 0.55, -math.cos(ang) * 0.55, 0)
	cyl("pole", 0.014, H - 0.5, (0, 0, 0.5 + (H - 0.5) / 2), "black", verts=12, bevel=0)
	cyl("pole_lo", 0.018, 0.55, (0, 0, 0.3), "black", verts=12, bevel=0)
	bpy.ops.mesh.primitive_torus_add(major_radius=0.2, minor_radius=0.022, major_segments=64, minor_segments=12, location=(0, -0.03, H - 0.22), rotation=(math.pi / 2, 0, 0))
	t = bpy.context.active_object; t.data.materials.append(mat("glow_white"))
	bpy.ops.mesh.primitive_torus_add(major_radius=0.2, minor_radius=0.026, major_segments=64, minor_segments=12, location=(0, -0.025, H - 0.22), rotation=(math.pi / 2, 0, 0))
	t2 = bpy.context.active_object; t2.scale = (1, 1, 0.6); t2.data.materials.append(mat("black"))
	box("phone_clamp", (0.05, 0.02, 0.07), (0, -0.03, H - 0.42), "black", 0.006)
	finish("clean_ring_light")

def cream_stand():
	"""Small cream stand / side table the printer sits on (photo 6)."""
	W, D, H = 0.45, 0.45, 0.62
	box("body", (W, D, H - 0.02), (0, 0, (H - 0.02) / 2), "cream_wood", 0.006)
	box("top", (W + 0.02, D + 0.02, 0.022), (0, 0, H - 0.011), "beige_top", 0.006)
	box("drawer", (W - 0.04, 0.015, 0.14), (0, -D / 2 - 0.004, H - 0.12), "cream_wood", 0.004)
	box("handle", (0.12, 0.02, 0.02), (0, -D / 2 - 0.02, H - 0.12), "handle_white", 0.006)
	finish("clean_cream_stand")

PIECES = {"chest_drawers": chest_drawers, "bed_single": bed_single, "bookshelf": bookshelf, "gaming_desk": gaming_desk, "pc_white": pc_white,
	"ac_unit": ac_unit, "projector": projector, "speaker": speaker, "printer3d": printer3d, "ring_light": ring_light, "cream_stand": cream_stand}
for n, fn in PIECES.items():
	if ONLY and n not in ONLY: continue
	reset(); fn()
