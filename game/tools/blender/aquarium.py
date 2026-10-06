# Blender (4.5) batch script: the desktop aquarium from the owner's photo, as three game assets:
#   aquarium_tank   — glass box, black base rim, white lid with LED strip, water, colourful gravel, stones, internal filter, air stone
#   aquarium_plants — vallisneria ribbons and broad-leaf plants (swayed by a vertex shader in the game)
#   fish_shark      — a black shark (Labeo), forward = glTF -Z (Godot forward), origin at its centre (wiggled by a shader)
#   blender -b -P aquarium.py -- <out_dir>
import bpy, bmesh, sys, os, math, random
from mathutils import Vector, Matrix

a = sys.argv[sys.argv.index("--") + 1:]
OUT = a[0]; os.makedirs(OUT, exist_ok=True)
W, D, H = 0.42, 0.27, 0.3          # tank outer size (m): width X, depth (Blender Y), height Z
G = 0.006                           # glass thickness
WATER = H - 0.045                   # water level
COL = {"glass_tank": (0.75, 0.85, 0.85), "water": (0.55, 0.75, 0.75), "black": (0.02, 0.02, 0.02), "white_plastic": (0.95, 0.95, 0.94),
	"glow_white": (1, 1, 1), "stone": (0.35, 0.34, 0.32), "plant_green": (0.15, 0.45, 0.12), "plant_dark": (0.08, 0.3, 0.1), "fish_black": (0.01, 0.01, 0.012),
	"fish_fin": (0.04, 0.03, 0.03), "fish_eye": (0.8, 0.7, 0.3), "tube": (0.6, 0.75, 0.7), "gravel_bed": (0.62, 0.6, 0.56)}
GRAVEL = ["gravel_red", "gravel_yellow", "gravel_blue", "gravel_white", "gravel_green", "gravel_orange"]
for gname, c in zip(GRAVEL, [(0.8, 0.15, 0.1), (0.9, 0.75, 0.15), (0.15, 0.35, 0.8), (0.9, 0.9, 0.88), (0.2, 0.65, 0.3), (0.95, 0.45, 0.1)]): COL[gname] = c

def reset(): bpy.ops.wm.read_factory_settings(use_empty=True)
def mat(name):
	m = bpy.data.materials.get(name)
	if m: return m
	m = bpy.data.materials.new(name); m.use_nodes = True
	m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*COL.get(name, (0.8, 0.8, 0.8)), 1); return m
def bevel(o, w, s=2):
	m = o.modifiers.new("b", "BEVEL"); m.width = w; m.segments = s; m.limit_method = "ANGLE"; m.harden_normals = True
def cube(size, loc, material, bw=0.0):
	bpy.ops.mesh.primitive_cube_add(size=1, location=loc); o = bpy.context.active_object; o.scale = size
	bpy.ops.object.transform_apply(scale=True)
	if bw: bevel(o, bw)
	o.data.materials.append(mat(material)); return o

def finish(name, smooth=True):
	objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
	for o in objs:
		bpy.context.view_layer.objects.active = o
		for m in list(o.modifiers): bpy.ops.object.modifier_apply(modifier=m.name)
	for o in bpy.context.scene.objects: o.select_set(o.type == "MESH")
	bpy.context.view_layer.objects.active = objs[0]
	if len(objs) > 1: bpy.ops.object.join()
	o = bpy.context.active_object; o.name = name
	if smooth:
		bpy.ops.object.shade_smooth()
		wn = o.modifiers.new("wn", "WEIGHTED_NORMAL"); wn.keep_sharp = True; bpy.ops.object.modifier_apply(modifier="wn")
	bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT"); bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.003)
	bpy.ops.object.mode_set(mode="OBJECT")
	bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format="GLB", export_yup=True, export_apply=True, export_materials="EXPORT")
	print("AQUA %s tris=%d" % (name, sum(len(p.vertices) - 2 for p in o.data.polygons)), flush=True)

def tank():
	rng = random.Random(4)
	# glass walls (open top) on a black rim
	cube((W, D, 0.018), (0, 0, 0.009), "black", 0.003)
	cube((W - 2 * G, D - 2 * G, G), (0, 0, 0.018 + G / 2), "glass_tank")
	for sx in (-1, 1): cube((G, D, H - 0.018), (sx * (W / 2 - G / 2), 0, 0.018 + (H - 0.018) / 2), "glass_tank")
	for sy in (-1, 1): cube((W - 2 * G, G, H - 0.018), (0, sy * (D / 2 - G / 2), 0.018 + (H - 0.018) / 2), "glass_tank")
	cube((W + 0.004, D + 0.004, 0.012), (0, 0, H - 0.006), "black", 0.002)          # top rim
	# white lid with a feeding hatch and the LED strip under it
	cube((W + 0.01, D + 0.01, 0.035), (0, 0, H + 0.0175), "white_plastic", 0.01)
	cube((0.12, 0.08, 0.004), (0.08, 0.02, H + 0.037), "white_plastic", 0.002)
	cube((W - 0.06, 0.02, 0.004), (0, 0.0, H - 0.002), "glow_white")
	# water volume (inside the glass)
	cube((W - 2 * G - 0.002, D - 2 * G - 0.002, WATER - 0.03), (0, 0, 0.024 + (WATER - 0.03) / 2), "water")
	# gravel: a sloped bed (higher at the back) + scattered colourful pebbles
	bm = bmesh.new()
	nx, ny = 24, 14
	verts = [[None] * (ny + 1) for _ in range(nx + 1)]
	for i in range(nx + 1):
		for j in range(ny + 1):
			x = -W / 2 + G + 0.002 + (W - 2 * G - 0.004) * i / nx; y = -D / 2 + G + 0.002 + (D - 2 * G - 0.004) * j / ny
			z = 0.024 + 0.018 + 0.02 * (j / ny) + rng.uniform(-0.003, 0.003)
			verts[i][j] = bm.verts.new((x, y, z))
	for i in range(nx):
		for j in range(ny): bm.faces.new([verts[i][j], verts[i + 1][j], verts[i + 1][j + 1], verts[i][j + 1]])
	# close the bed down to the bottom glass (front, back and sides), so the glass shows a solid layer, not a sheet
	z0 = 0.024
	ring = [verts[i][0] for i in range(nx + 1)] + [verts[nx][j] for j in range(1, ny + 1)] + [verts[i][ny] for i in range(nx - 1, -1, -1)] + [verts[0][j] for j in range(ny - 1, 0, -1)]
	low = [bm.verts.new((v.co.x, v.co.y, z0)) for v in ring]
	for k in range(len(ring)):
		k2 = (k + 1) % len(ring)
		bm.faces.new([ring[k2], ring[k], low[k], low[k2]])
	me = bpy.data.meshes.new("bed"); bm.to_mesh(me); bm.free()
	bed = bpy.data.objects.new("bed", me); bpy.context.scene.collection.objects.link(bed); bed.data.materials.append(mat("gravel_bed"))
	def pebble(x, y, z, r):
		bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=r, location=(x, y, z))
		p = bpy.context.active_object; p.scale = (1, rng.uniform(0.75, 1.0), rng.uniform(0.6, 0.85)); p.rotation_euler = (rng.uniform(0, 3), rng.uniform(0, 3), rng.uniform(0, 3))
		p.data.materials.append(mat(rng.choice(GRAVEL)))
	top = lambda y: 0.024 + 0.018 + 0.02 * ((y + D / 2) / D)
	for k in range(950):        # the surface layer
		x = rng.uniform(-W / 2 + G + 0.004, W / 2 - G - 0.004); y = rng.uniform(-D / 2 + G + 0.004, D / 2 - G - 0.004)
		pebble(x, y, top(y) + 0.0005, rng.uniform(0.0028, 0.0052))
	for k in range(420):        # pressed against the front and side glass: the layered cut you see through the glass
		r = rng.uniform(0.0028, 0.005)
		side = rng.random()
		if side < 0.7: x = rng.uniform(-W / 2 + G + 0.004, W / 2 - G - 0.004); y = -D / 2 + G + r * 0.8
		else: x = (-1 if side < 0.85 else 1) * (W / 2 - G - r * 0.8); y = rng.uniform(-D / 2 + G + 0.004, D / 2 - G - 0.004)
		pebble(x, y, rng.uniform(z0 + r, top(y)), r)
	# two stones
	for (x, y, r) in ((-0.11, 0.05, 0.045), (0.12, 0.07, 0.032)):
		bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=r, location=(x, y, 0.05))
		s = bpy.context.active_object; s.scale = (1.3, 0.9, 0.7)
		tex = bpy.data.textures.new("st", "VORONOI"); dm = s.modifiers.new("d", "DISPLACE"); dm.texture = tex; dm.strength = 0.012
		s.data.materials.append(mat("stone"))
	# internal filter (back right corner) and the air stone with its tube (back left)
	cube((0.05, 0.035, 0.16), (W / 2 - 0.04, D / 2 - 0.03, 0.06 + 0.08), "black", 0.006)
	for i in range(5): cube((0.04, 0.002, 0.004), (W / 2 - 0.04, D / 2 - 0.048, 0.08 + i * 0.02), "stone")
	bpy.ops.mesh.primitive_cylinder_add(radius=0.012, depth=0.02, location=(-W / 2 + 0.06, D / 2 - 0.05, 0.052)); bpy.context.active_object.data.materials.append(mat("stone"))
	bpy.ops.mesh.primitive_cylinder_add(radius=0.0025, depth=H - 0.05, location=(-W / 2 + 0.06, D / 2 - 0.02, 0.05 + (H - 0.05) / 2)); bpy.context.active_object.data.materials.append(mat("tube"))
	finish("aquarium_tank")

def plants():
	rng = random.Random(11)
	base = 0.024 + 0.018 + 0.016
	# vallisneria: long thin twisted ribbons at the back
	for k in range(26):
		x = rng.uniform(-W / 2 + 0.03, W / 2 - 0.09); y = rng.uniform(0.02, D / 2 - 0.025)
		h = rng.uniform(0.14, WATER - 0.06); w = rng.uniform(0.004, 0.007); bend = rng.uniform(-0.05, 0.05); tw = rng.uniform(-1.2, 1.2)
		bm = bmesh.new(); prev = None; segs = 8
		for i in range(segs + 1):
			t = i / segs; cx = x + bend * t * t; cz = base + h * t; ang = tw * t
			dx, dy = math.cos(ang) * w / 2, math.sin(ang) * w / 2
			a1 = bm.verts.new((cx - dx, y - dy, cz)); a2 = bm.verts.new((cx + dx, y + dy, cz))
			if prev: bm.faces.new([prev[0], prev[1], a2, a1])
			prev = (a1, a2)
		me = bpy.data.meshes.new("leaf"); bm.to_mesh(me); bm.free()
		o = bpy.data.objects.new("leaf", me); bpy.context.scene.collection.objects.link(o); o.data.materials.append(mat(rng.choice(["plant_green", "plant_dark"])))
		so = o.modifiers.new("s", "SOLIDIFY"); so.thickness = 0.0008
	# broad-leaf rosettes (amazon sword style) at the front corners
	for (cx, cy) in ((-0.15, -0.04), (0.16, -0.02), (0.02, 0.06)):
		for k in range(9):
			ang = k / 9 * 2 * math.pi + rng.uniform(-0.2, 0.2); L = rng.uniform(0.06, 0.1); tilt = rng.uniform(0.6, 1.1)
			bm = bmesh.new(); pts = []
			for i in range(7):
				t = i / 6; wdt = math.sin(t * math.pi) * L * 0.18
				r = L * t; z = base + math.sin(tilt) * r - (t * t) * 0.02
				px = cx + math.cos(ang) * math.cos(tilt) * r; py = cy + math.sin(ang) * math.cos(tilt) * r
				nx, ny = -math.sin(ang) * wdt, math.cos(ang) * wdt
				pts.append((bm.verts.new((px - nx, py - ny, z)), bm.verts.new((px + nx, py + ny, z))))
			for i in range(6): bm.faces.new([pts[i][0], pts[i][1], pts[i + 1][1], pts[i + 1][0]])
			me = bpy.data.meshes.new("broad"); bm.to_mesh(me); bm.free()
			o = bpy.data.objects.new("broad", me); bpy.context.scene.collection.objects.link(o); o.data.materials.append(mat("plant_green"))
			so = o.modifiers.new("s", "SOLIDIFY"); so.thickness = 0.0008
	finish("aquarium_plants")

def fish():
	"""Black shark (Labeo): torpedo body, tall triangular dorsal fin, deeply forked tail, pectoral/anal fins, small eye.
	Built along Blender +Y (= glTF/Godot -Z = forward), ~7.5 cm long."""
	L = 0.075
	bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=14, radius=0.5)
	b = bpy.context.active_object; b.scale = (0.17 * L * 2, L, 0.24 * L * 2)
	bpy.ops.object.transform_apply(scale=True)
	for v in b.data.vertices:
		t = (v.co.y / L + 0.5)            # 0 tail .. 1 nose
		k = 0.35 + 0.65 * math.sin(min(1.0, t * 1.15) * math.pi * 0.62 + 0.25)
		v.co.x *= k; v.co.z *= k
		v.co.z -= 0.004 * (1 - t) ** 2      # slightly downturned underside (bottom grazer)
	b.data.materials.append(mat("fish_black"))
	def fin(name, pts, material="fish_fin"):
		bm = bmesh.new(); vs = [bm.verts.new(p) for p in pts]; bm.faces.new(vs)
		me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
		o = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(o); o.data.materials.append(mat(material))
		so = o.modifiers.new("s", "SOLIDIFY"); so.thickness = 0.0007
	y0 = -L / 2
	fin("dorsal", [(0, 0.004, 0.012), (0, -0.016, 0.012), (0, -0.01, 0.036)])
	fin("tail_up", [(0, y0 + 0.006, 0.0), (0, y0 - 0.02, 0.016), (0, y0 - 0.012, 0.0)])
	fin("tail_dn", [(0, y0 + 0.006, 0.0), (0, y0 - 0.012, 0.0), (0, y0 - 0.02, -0.014)])
	fin("anal", [(0, -0.015, -0.009), (0, -0.026, -0.009), (0, -0.024, -0.019)])
	for sx in (-1, 1):
		fin("pect", [(sx * 0.006, 0.014, -0.006), (sx * 0.006, 0.006, -0.006), (sx * 0.02, 0.0, -0.013)])
		fin("pelv", [(sx * 0.004, -0.004, -0.009), (sx * 0.004, -0.011, -0.009), (sx * 0.012, -0.014, -0.016)])
		bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=0.0028, location=(sx * 0.0068, L / 2 - 0.012, 0.003))
		bpy.context.active_object.data.materials.append(mat("fish_eye"))
	finish("fish_shark")

for fn in (tank, plants, fish):
	reset(); fn()
