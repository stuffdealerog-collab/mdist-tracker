# Blender (4.5) batch script: the player's room as clean game assets (architecture + fixtures).
#   blender -b -P room_build.py -- <out_dir> [names...]
# Everything is modelled in GAME coordinates (metres, Godot axes) through g() so the static pieces are
# placed at the origin in Godot. Hinged parts (door leaf, wardrobe doors) are exported with their pivot at the hinge.
# Material slots are named; the game maps them onto its baked PBR materials (scripts/world/home.gd).
# Dimensions MUST match the constants at the top of scripts/world/home.gd.
import bpy, bmesh, sys, os, math, random
from mathutils import Vector, Matrix

a = sys.argv[sys.argv.index("--") + 1:]
OUT = a[0]; ONLY = a[1:]
os.makedirs(OUT, exist_ok=True)

# ---- room layout (sync with home.gd) --------------------------------------------------------------
F = -0.76; CEIL = F + 3.0
X0, X1, Z0, Z1 = -2.15, 3.05, -0.62, 2.78
DOOR_X, DOOR_W, DOOR_H = 2.4, 0.9, 2.15
NICHE = dict(z0=0.25, z1=1.25, d=0.3)
WIN = dict(z0=0.33, z1=1.17, y0=F + 0.95, y1=F + 2.6, transom=F + 2.18)
BENCH = dict(x0=-1.0, x1=1.0, zc=-0.24, d=0.76)
PC = (-1.545, -0.01, -0.36)
WARD = dict(x0=X1 - 0.6, x1=X1, z0=1.2, z1=2.75, h=2.15)
SHELF_LEVELS = [F + 0.1, F + 0.56, F + 1.02, F + 1.48]
T = 0.12   # wall thickness

COL = {"wallpaper_damask": (0.82, 0.8, 0.74), "wallpaper_mottle": (0.7, 0.7, 0.68), "floor_laminate": (0.72, 0.71, 0.69), "venetian": (0.65, 0.7, 0.72),
	"white_trim": (0.95, 0.94, 0.91), "plaster_hall": (0.66, 0.72, 0.68), "concrete": (0.42, 0.41, 0.39), "dark_wood": (0.25, 0.15, 0.09),
	"cream_wood": (0.86, 0.82, 0.74), "gold": (0.78, 0.62, 0.3), "glass": (0.6, 0.65, 0.7), "black": (0.03, 0.03, 0.035), "chrome": (0.8, 0.8, 0.82),
	"glow_white": (1, 1, 1), "fabric_curtain": (0.6, 0.5, 0.38), "fabric_mat": (0.1, 0.1, 0.11), "fabric_doormat": (0.27, 0.2, 0.14),
	"white_plastic": (0.93, 0.93, 0.92), "neighbour_door": (0.3, 0.18, 0.1), "beige_top": (0.84, 0.78, 0.68), "handle_white": (0.95, 0.94, 0.91),
	"jar_red": (0.7, 0.15, 0.12), "jar_yellow": (0.85, 0.7, 0.2), "jar_blue": (0.15, 0.35, 0.75), "key_white": (0.95, 0.95, 0.93), "key_pink": (0.95, 0.7, 0.8),
	"key_mint": (0.65, 0.9, 0.82), "screen_black": (0.01, 0.01, 0.012)}

def g(x, y, z): return Vector((x, -z, y))          # game (Godot) -> Blender coordinates

def reset(): bpy.ops.wm.read_factory_settings(use_empty=True)

def mat(name):
	m = bpy.data.materials.get(name)
	if m: return m
	m = bpy.data.materials.new(name); m.use_nodes = True
	b = m.node_tree.nodes["Principled BSDF"]; b.inputs["Base Color"].default_value = (*COL.get(name, (0.8, 0.8, 0.8)), 1)
	b.inputs["Roughness"].default_value = 0.5
	return m

def _bevel(o, w, segs=3):
	if w > 0:
		m = o.modifiers.new("bevel", "BEVEL"); m.width = w; m.segments = segs; m.limit_method = "ANGLE"; m.harden_normals = True

def box(size_g, center_g, material, bevel=0.003, segs=3, rot_y=0.0, name="box"):
	"""Box in game axes: size (x, y=up, z), centre in game coordinates, optional rotation about game Y."""
	sx, sy, sz = size_g
	bpy.ops.mesh.primitive_cube_add(size=1.0, location=g(*center_g))
	o = bpy.context.active_object; o.name = name; o.scale = (sx, sz, sy)
	if rot_y: o.rotation_euler = (0, 0, rot_y)
	bpy.ops.object.transform_apply(scale=True, rotation=True)
	_bevel(o, bevel, segs); o.data.materials.append(mat(material)); return o

def span(xa, xb, ya, yb, za, zb, material, bevel=0.0, name="span"):
	return box((xb - xa, yb - ya, zb - za), ((xa + xb) / 2, (ya + yb) / 2, (za + zb) / 2), material, bevel, name=name)

def cyl(r, h, center_g, material, axis="y", verts=24, bevel=0.002, r2=None, name="cyl"):
	rot = {"y": (0, 0, 0), "x": (0, math.pi / 2, 0), "z": (math.pi / 2, 0, 0)}[axis]
	if r2 is None: bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=h, vertices=verts, location=g(*center_g), rotation=rot)
	else: bpy.ops.mesh.primitive_cone_add(radius1=r2, radius2=r, depth=h, vertices=verts, location=g(*center_g), rotation=rot)
	o = bpy.context.active_object; o.name = name; _bevel(o, bevel, 2); o.data.materials.append(mat(material)); return o

def cove(xa, xb, za, zb, y, r, material):
	"""Quarter-round cove moulding around a rectangle (wall-to-ceiling crown), facing inwards."""
	for (p0, p1, axis, inward) in [((xa, za), (xb, za), "x", (0, 1)), ((xa, zb), (xb, zb), "x", (0, -1)), ((xa, za), (xa, zb), "z", (1, 0)), ((xb, za), (xb, zb), "z", (-1, 0))]:
		L = abs(p1[0] - p0[0]) + abs(p1[1] - p0[1])
		cx = (p0[0] + p1[0]) / 2 + inward[0] * 0.0; cz = (p0[1] + p1[1]) / 2 + inward[1] * 0.0
		bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=L, vertices=32, location=g(cx, y, cz), rotation=(0, math.pi / 2, 0) if axis == "x" else (math.pi / 2, 0, 0))
		o = bpy.context.active_object; o.name = "cove"; o.data.materials.append(mat(material))

def finish(name, pivot=None):
	"""Apply modifiers, join, weighted normals, smart UV (floor keeps its own UVs), export as GLB."""
	objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
	if not objs: return
	for o in objs:
		bpy.context.view_layer.objects.active = o
		for m in list(o.modifiers): bpy.ops.object.modifier_apply(modifier=m.name)
	keep_uv = [o for o in objs if o.get("keep_uv")]
	for o in objs:
		if o in keep_uv: continue
		bpy.context.view_layer.objects.active = o
		for s in bpy.context.scene.objects: s.select_set(s == o)
		bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
		bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.003)
		bpy.ops.object.mode_set(mode="OBJECT")
	for s in bpy.context.scene.objects: s.select_set(s.type == "MESH")
	bpy.context.view_layer.objects.active = objs[0]
	if len(objs) > 1: bpy.ops.object.join()
	o = bpy.context.active_object; o.name = name
	bpy.ops.object.shade_smooth()
	wn = o.modifiers.new("wn", "WEIGHTED_NORMAL"); wn.keep_sharp = True; wn.weight = 100
	bpy.ops.object.modifier_apply(modifier="wn")
	if pivot is not None:
		o.data.transform(Matrix.Translation(-pivot))
	tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
	bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format="GLB", export_yup=True, export_apply=True, export_materials="EXPORT", export_normals=True, export_texcoords=True)
	print("ROOM %s tris=%d" % (name, tris), flush=True)

# ------------------------------------------------------------------ architecture
def shell():
	"""Floor, walls with the window niche and door opening, skirting, tray ceiling with mouldings, landing, wall fittings."""
	# floor with laminate UVs: planks (texture V) run along the room (game X); 1.3 m per tile
	bm = bmesh.new(); uv = bm.loops.layers.uv.new("UVMap")
	pts = [(X0, Z0), (X1, Z0), (X1, Z1), (X0, Z1)]
	vs = [bm.verts.new(g(x, F, z)) for x, z in pts]
	f = bm.faces.new(vs)
	for l in f.loops:
		x, z = l.vert.co.x, -l.vert.co.y
		l[uv].uv = (z / 1.3, x / 1.3)
	nz0, nz1, nd = NICHE["z0"], NICHE["z1"], NICHE["d"]
	vs2 = [bm.verts.new(g(x, F, z)) for x, z in [(X0 - nd, nz0), (X0, nz0), (X0, nz1), (X0 - nd, nz1)]]
	f2 = bm.faces.new(vs2)
	for l in f2.loops:
		x, z = l.vert.co.x, -l.vert.co.y
		l[uv].uv = (z / 1.3, x / 1.3)
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	for face in bm.faces:
		if face.normal.z < 0: face.normal_flip()
	me = bpy.data.meshes.new("floor"); bm.to_mesh(me); bm.free()
	fl = bpy.data.objects.new("floor", me); bpy.context.scene.collection.objects.link(fl); fl.data.materials.append(mat("floor_laminate")); fl["keep_uv"] = 1
	# walls
	dx0, dx1 = DOOR_X - DOOR_W / 2, DOOR_X + DOOR_W / 2
	span(X0 - T, X1 + T, F, CEIL, Z1, Z1 + T, "wallpaper_damask")
	span(X0 - T, dx0, F, CEIL, Z0 - T, Z0, "wallpaper_damask")
	span(dx1, X1 + T, F, CEIL, Z0 - T, Z0, "wallpaper_damask")
	span(dx0, dx1, F + DOOR_H, CEIL, Z0 - T, Z0, "wallpaper_damask")
	span(X1, X1 + T, F, CEIL, Z0, Z1, "wallpaper_mottle")
	span(X0 - T, X0, F, CEIL, Z0, nz0, "wallpaper_mottle")
	span(X0 - T, X0, F, CEIL, nz1, Z1, "wallpaper_mottle")
	bx = X0 - nd
	span(bx - T, bx, F, WIN["y0"], nz0, nz1, "wallpaper_mottle")
	span(bx - T, bx, WIN["y1"], CEIL, nz0, nz1, "wallpaper_mottle")
	span(bx - T, bx, WIN["y0"], WIN["y1"], nz0, WIN["z0"], "wallpaper_mottle")
	span(bx - T, bx, WIN["y0"], WIN["y1"], WIN["z1"], nz1, "wallpaper_mottle")
	span(bx, X0, F, CEIL, nz0 - 0.002, nz0, "wallpaper_mottle")
	span(bx, X0, F, CEIL, nz1, nz1 + 0.002, "wallpaper_mottle")
	# skirting with a rounded top edge
	for (xa, xb, za, zb) in [(X0, X1, Z1 - 0.016, Z1), (X0, dx0 - 0.07, Z0, Z0 + 0.016), (dx1 + 0.07, X1, Z0, Z0 + 0.016), (X1 - 0.016, X1, Z0, Z1),
			(X0, X0 + 0.016, Z0, nz0), (X0, X0 + 0.016, nz1, Z1)]:
		span(xa, xb, F, F + 0.085, za, zb, "white_trim", 0.006)
	# tray ceiling: venetian field, lowered soffit band, stepped crown + cove mouldings
	band, drop = 0.55, 0.3; ys = CEIL - drop
	span(X0 + band, X1 - band, CEIL, CEIL + 0.03, Z0 + band, Z1 - band, "venetian")
	span(X0, X1, ys - 0.04, ys, Z0, Z0 + band, "white_trim"); span(X0, X1, ys - 0.04, ys, Z1 - band, Z1, "white_trim")
	span(X0, X0 + band, ys - 0.04, ys, Z0 + band, Z1 - band, "white_trim"); span(X1 - band, X1, ys - 0.04, ys, Z0 + band, Z1 - band, "white_trim")
	span(X0 + band - 0.02, X1 - band + 0.02, ys, CEIL + 0.03, Z0 + band - 0.02, Z0 + band, "white_trim")
	span(X0 + band - 0.02, X1 - band + 0.02, ys, CEIL + 0.03, Z1 - band, Z1 - band + 0.02, "white_trim")
	span(X0 + band - 0.02, X0 + band, ys, CEIL + 0.03, Z0 + band, Z1 - band, "white_trim")
	span(X1 - band, X1 - band + 0.02, ys, CEIL + 0.03, Z0 + band, Z1 - band, "white_trim")
	span(X0 - 0.2, X1 + 0.2, CEIL + 0.03, CEIL + 0.06, Z0 - 0.2, Z1 + 0.2, "white_trim")
	for k in range(3):
		s = 0.05 + k * 0.045; hh = 0.05; y = ys - 0.04 - k * hh - hh / 2
		for (xa, xb, za, zb) in [(X0, X1, Z0, Z0 + s), (X0, X1, Z1 - s, Z1), (X0, X0 + s, Z0, Z1), (X1 - s, X1, Z0, Z1)]:
			span(xa, xb, y - hh / 2, y + hh / 2, za, zb, "white_trim", 0.008)
	cove(X0 + 0.19, X1 - 0.19, Z0 + 0.19, Z1 - 0.19, ys - 0.19 - 0.025, 0.03, "white_trim")
	for k in range(2):
		s2 = 0.04 + k * 0.04; y = CEIL - 0.03 - k * 0.04
		xa, xb, za, zb = X0 + band - s2, X1 - band + s2, Z0 + band - s2, Z1 - band + s2
		for (a1, a2, b1, b2) in [(xa, xb, za, za + s2), (xa, xb, zb - s2, zb), (xa, xa + s2, za, zb), (xb - s2, xb, za, zb)]:
			span(a1, a2, y - 0.02, y + 0.02, b1, b2, "white_trim", 0.008)
	# fittings: switch by the door, sockets, low air vent on the far wall
	box((0.085, 0.085, 0.014), (dx0 - 0.2, F + 1.05, Z0 + 0.007), "white_plastic", 0.006)
	box((0.085, 0.085, 0.014), (-0.3, F + 0.3, Z0 + 0.007), "white_plastic", 0.006)
	box((0.085, 0.085, 0.014), (-1.0, F + 0.3, Z1 - 0.007), "white_plastic", 0.006)
	box((0.02, 0.38, 0.52), (X1 - 0.01, F + 0.3, -0.12), "white_trim", 0.006)
	for i in range(6): box((0.008, 0.28, 0.03), (X1 - 0.022, F + 0.3, -0.33 + i * 0.085), "black", 0.003)
	# landing outside the door
	lz0 = Z0 - 1.8
	span(DOOR_X - 1.4, DOOR_X + 1.4, F - 0.04, F, lz0, Z0 - T, "concrete")
	span(DOOR_X - 1.4, DOOR_X + 1.4, F, CEIL, lz0 - T, lz0, "plaster_hall")
	span(DOOR_X - 1.4 - T, DOOR_X - 1.4, F, CEIL, lz0, Z0 - T, "plaster_hall")
	span(DOOR_X + 1.4, DOOR_X + 1.4 + T, F, CEIL, lz0, Z0 - T, "plaster_hall")
	span(DOOR_X - 1.4, DOOR_X + 1.4, CEIL - 0.32, CEIL - 0.28, lz0, Z0 - T, "white_trim")
	span(DOOR_X - 0.4, DOOR_X + 0.4, F, F + 0.012, Z0 - 0.67, Z0 - 0.17, "fabric_doormat", 0.004)
	box((0.9, 2.0, 0.05), (DOOR_X - 0.2, F + 1.0, lz0 + 0.025), "neighbour_door", 0.01)
	box((0.12, 0.02, 0.06), (DOOR_X - 0.55, F + 1.0, lz0 + 0.06), "gold", 0.004)
	finish("room_shell")

def window():
	"""Brown wooden window with transom and a sash split, deep sill, cream radiator cover with slots."""
	bx = X0 - NICHE["d"]; z0, z1, y0, y1 = WIN["z0"], WIN["z1"], WIN["y0"], WIN["y1"]; zc = (z0 + z1) / 2; fw = 0.06
	for (xa, xb, ya, yb, za, zb) in [(bx - 0.03, bx + 0.07, y0, y1, z0, z0 + fw), (bx - 0.03, bx + 0.07, y0, y1, z1 - fw, z1),
			(bx - 0.03, bx + 0.07, y1 - fw, y1, z0, z1), (bx - 0.03, bx + 0.07, y0, y0 + fw, z0, z1),
			(bx - 0.025, bx + 0.065, WIN["transom"] - 0.025, WIN["transom"] + 0.025, z0, z1), (bx - 0.02, bx + 0.06, y0, WIN["transom"], zc - 0.022, zc + 0.022)]:
		span(xa, xb, ya, yb, za, zb, "dark_wood", 0.006)
	# glazing beads and glass
	span(bx + 0.005, bx + 0.011, y0 + fw, y1 - fw, z0 + fw, z1 - fw, "glass")
	box((0.03, 0.14, 0.025), (bx + 0.09, y0 + 0.75, zc + 0.08), "white_plastic", 0.008)
	span(bx - 0.02, X0 + 0.04, y0 - 0.04, y0, NICHE["z0"] - 0.03, NICHE["z1"] + 0.03, "dark_wood", 0.008)
	# radiator cover: frame + vertical slats, beige top
	rz0, rz1, rh = NICHE["z0"] + 0.05, NICHE["z1"] - 0.05, 0.8
	span(bx + 0.01, bx + 0.22, F, F + 0.06, rz0, rz1, "cream_wood", 0.004)
	span(bx + 0.01, bx + 0.22, F + rh - 0.05, F + rh, rz0, rz1, "cream_wood", 0.006)
	span(bx + 0.01, bx + 0.22, F, F + rh, rz0, rz0 + 0.06, "cream_wood", 0.004)
	span(bx + 0.01, bx + 0.22, F, F + rh, rz1 - 0.06, rz1, "cream_wood", 0.004)
	span(bx + 0.02, bx + 0.03, F + 0.06, F + rh - 0.05, rz0, rz1, "black")
	n = 6; w = (rz1 - rz0 - 0.12)
	for i in range(n + 1):
		zz = rz0 + 0.06 + i * w / n
		span(bx + 0.19, bx + 0.22, F + 0.06, F + rh - 0.05, zz - 0.03, zz + 0.03, "cream_wood", 0.004)
	finish("room_window")

def curtain():
	"""Full-height beige curtain gathered left of the window: pleated cloth with soft irregular folds, rod and rings."""
	top = CEIL - 0.32; w = 1.05; h = top - F - 0.015; folds = 11
	nx, ny = folds * 10, 40
	rng = random.Random(9); amp = [0.035 * rng.uniform(0.7, 1.3) for _ in range(folds + 2)]
	bm = bmesh.new(); uv = bm.loops.layers.uv.new("UVMap"); grid = []
	for j in range(ny + 1):
		row = []
		for i in range(nx + 1):
			u = i / nx; v = j / ny
			k = int(u * folds); fr = u * folds - k
			a = amp[k] * (1 - fr) + amp[k + 1] * fr
			off = math.sin(u * folds * 2 * math.pi) * a * (1.0 + 0.35 * (1 - v)) + math.sin(v * 7 + u * 13) * 0.004
			row.append(bm.verts.new(g(X0 + 0.08 + off, F + 0.015 + v * h, 1.22 + u * w)))
		grid.append(row)
	for j in range(ny):
		for i in range(nx):
			f = bm.faces.new([grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]])
			for l, (uu, vv) in zip(f.loops, [(i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)]): l[uv].uv = (uu / nx * w * 2, vv / ny * h * 2)
	me = bpy.data.meshes.new("curtain"); bm.to_mesh(me); bm.free()
	o = bpy.data.objects.new("curtain", me); bpy.context.scene.collection.objects.link(o); o.data.materials.append(mat("fabric_curtain")); o["keep_uv"] = 1
	sol = o.modifiers.new("thick", "SOLIDIFY"); sol.thickness = 0.004
	cyl(0.012, 1.9, (X0 + 0.08, top + 0.03, 1.22), "black", axis="z", verts=16)
	for i in range(12):
		bpy.ops.mesh.primitive_torus_add(major_radius=0.02, minor_radius=0.004, location=g(X0 + 0.08, top + 0.03, 1.24 + i * 0.09), rotation=(0, 0, 0))
		bpy.context.active_object.data.materials.append(mat("black"))
	finish("room_curtain")

def door():
	"""Ornate cream door: casing with pilasters, capitals and carved pediment in gold, and the leaf (pivot at hinge)."""
	dx0 = DOOR_X - DOOR_W / 2
	for sx in (-1, 1):
		px = DOOR_X + sx * (DOOR_W / 2 + 0.07)
		box((0.12, DOOR_H + 0.05, 0.05), (px, F + DOOR_H / 2, Z0 + 0.025), "cream_wood", 0.008)
		box((0.012, DOOR_H - 0.12, 0.008), (px, F + DOOR_H / 2 - 0.02, Z0 + 0.052), "gold", 0.003)
		box((0.15, 0.14, 0.07), (px, F + DOOR_H - 0.06, Z0 + 0.035), "cream_wood", 0.01)
		cyl(0.03, 0.012, (px, F + DOOR_H - 0.07, Z0 + 0.074), "gold", axis="z", verts=24)
		box((0.14, 0.03, 0.08), (px, F + 0.015, Z0 + 0.04), "cream_wood", 0.005)
	box((DOOR_W + 0.42, 0.18, 0.08), (DOOR_X, F + DOOR_H + 0.11, Z0 + 0.04), "cream_wood", 0.01)
	box((DOOR_W + 0.52, 0.04, 0.12), (DOOR_X, F + DOOR_H + 0.22, Z0 + 0.06), "cream_wood", 0.012)
	box((DOOR_W + 0.46, 0.025, 0.1), (DOOR_X, F + DOOR_H + 0.255, Z0 + 0.05), "cream_wood", 0.008)
	# gold scroll ornament on the pediment
	for sx in (-1, 1):
		bpy.ops.mesh.primitive_torus_add(major_radius=0.05, minor_radius=0.008, location=g(DOOR_X + sx * 0.12, F + DOOR_H + 0.11, Z0 + 0.084), rotation=(math.pi / 2, 0, 0))
		bpy.context.active_object.data.materials.append(mat("gold"))
	box((0.16, 0.012, 0.01), (DOOR_X, F + DOOR_H + 0.11, Z0 + 0.084), "gold", 0.003)
	finish("room_door_casing")
	reset_scene()
	# leaf: hinge at local origin; leaf extends +X; panels and gold medallion
	W, H = DOOR_W - 0.02, DOOR_H - 0.01
	def L(x, y, z): return (x, y, z)
	box((W, H, 0.045), (W / 2, H / 2, 0.0), "cream_wood", 0.006)
	for py, ph in ((0.6, 0.9), (1.55, 0.85)):
		box((W - 0.24, ph, 0.012), (W / 2, py, 0.026), "cream_wood", 0.01)
		for side in (-1, 1): box((W - 0.22, 0.008, 0.008), (W / 2, py + side * ph / 2, 0.03), "gold", 0.002)
		for side in (-1, 1): box((0.008, ph, 0.008), (W / 2 + side * (W - 0.22) / 2, py, 0.03), "gold", 0.002)
	cyl(0.11, 0.012, (W / 2, 0.62, 0.034), "gold", axis="z", verts=48)
	cyl(0.08, 0.016, (W / 2, 0.62, 0.037), "cream_wood", axis="z", verts=48)
	cyl(0.025, 0.02, (W / 2, 0.62, 0.042), "gold", axis="z", verts=24)
	for (cx, cy) in ((0.2, 1.93), (W - 0.2, 1.93), (0.2, 0.2), (W - 0.2, 0.2)):
		box((0.05, 0.08, 0.008), (cx, cy, 0.03), "gold", 0.003, rot_y=0.0)
	for zz in (-0.04, 0.04):
		box((0.13, 0.02, 0.02), (W - 0.12, 1.0, zz), "gold", 0.006)
		cyl(0.02, 0.02, (W - 0.07, 1.0, zz), "gold", axis="z", verts=16)
	for hy in (0.25, H - 0.25): cyl(0.008, 0.1, (0.0, hy, 0.0), "gold", verts=12)
	finish("room_door_leaf")

def chandelier():
	"""LED chandelier: two crossing sets of three white bars with glowing undersides on a flat canopy."""
	c = ((X0 + X1) / 2, CEIL - 0.12, (Z0 + Z1) / 2)
	sets = [(0.45, [-0.22, 0.0, 0.2], [1.1, 1.25, 0.95]), (0.45 + math.pi / 2, [-0.16, 0.06, 0.26], [1.0, 1.2, 0.9])]
	k = 0
	for a, offs, lens in sets:
		d = (math.cos(a), -math.sin(a)); sd = (math.sin(a), math.cos(a))
		for q in range(3):
			p = (c[0] + sd[0] * offs[q] + d[0] * (q - 1) * 0.08, c[1] - k * 0.014, c[2] + sd[1] * offs[q] + d[1] * (q - 1) * 0.08)
			box((lens[q], 0.035, 0.045), p, "white_trim", 0.006, rot_y=a)
			box((lens[q] - 0.02, 0.006, 0.03), (p[0], p[1] - 0.02, p[2]), "glow_white", 0.001, rot_y=a)
			k += 1
	cyl(0.06, 0.02, (c[0], CEIL + 0.02, c[2]), "white_trim", verts=32)
	finish("room_chandelier")

def wardrobe():
	"""Three-door cream wardrobe: carcass with shelves and arched cornice; doors exported separately (pivot at hinge)."""
	x0, x1, z0, z1, h = WARD["x0"], WARD["x1"], WARD["z0"], WARD["z1"], WARD["h"]; t = 0.022
	span(x0, x1, F, F + h, z0, z0 + t, "cream_wood", 0.003); span(x0, x1, F, F + h, z1 - t, z1, "cream_wood", 0.003)
	span(x1 - t, x1, F, F + h, z0, z1, "cream_wood", 0.002)
	span(x0, x1, F + h - t, F + h, z0, z1, "cream_wood", 0.003)
	span(x0, x1, F, F + 0.08, z0, z1, "cream_wood", 0.003)
	span(x0 - 0.03, x1, F + h, F + h + 0.04, z0 - 0.03, z1 + 0.03, "cream_wood", 0.008)
	span(x0 - 0.05, x0 + 0.02, F + h + 0.04, F + h + 0.12, z0 - 0.03, z1 + 0.03, "cream_wood", 0.012)
	for y in SHELF_LEVELS:
		if y > F + 0.2: span(x0 + 0.02, x1 - t, y - 0.018, y, z0 + t, z1 - t, "beige_top", 0.003)
	span(x0 + 0.3, x0 + 0.32, F + 1.85, F + 1.87, z0 + t, z1 - t, "chrome", 0.0)   # hanging rail
	finish("room_wardrobe_body")
	dw = (z1 - z0) / 3; H = h - 0.12
	for i in range(3):
		reset_scene()
		right = i == 2; s = -1 if right else 1
		box((0.022, H, dw - 0.006), (0.0, H / 2, s * dw / 2), "cream_wood", 0.004)
		for gi in range(2): box((0.006, H - 0.22, 0.005), (-0.012, H / 2, s * (0.065 + gi * 0.025)), "beige_top", 0.0)
		if i != 1: box((0.028, 0.22, 0.026), (-0.026, 1.05, s * (dw - 0.05)), "handle_white", 0.01)
		finish("room_wardrobe_door%d" % i)

def bench():
	"""The long brown desk (workbench): walnut top with a black edge, three-drawer pedestal, side panel, apron, work mat, switch jars."""
	x0, x1, zc, d = BENCH["x0"], BENCH["x1"], BENCH["zc"], BENCH["d"]
	span(x0, x1, -0.035, 0.0, zc - d / 2, zc + d / 2, "dark_wood", 0.004)
	span(x0, x1, -0.034, -0.002, zc + d / 2, zc + d / 2 + 0.008, "black", 0.002)
	pw = 0.45; px = x0 + pw / 2 + 0.02
	span(px - pw / 2, px + pw / 2, F, -0.035, zc - d / 2 + 0.02, zc + d / 2 - 0.02, "dark_wood", 0.004)
	for i in range(3):
		y = F + 0.12 + i * 0.22
		span(px - pw / 2 + 0.02, px + pw / 2 - 0.02, y, y + 0.2, zc + d / 2 - 0.02, zc + d / 2 - 0.006, "black", 0.004)
		box((0.15, 0.016, 0.022), (px, y + 0.15, zc + d / 2 + 0.006), "chrome", 0.006)
	span(x1 - 0.06, x1 - 0.03, F, -0.035, zc - d / 2 + 0.03, zc + d / 2 - 0.03, "dark_wood", 0.004)
	span(px + pw / 2, x1 - 0.06, -0.22, -0.035, zc - d / 2 + 0.02, zc - d / 2 + 0.04, "dark_wood", 0.003)
	span(-0.425, 0.525, 0.0, 0.003, -0.32, 0.12, "fabric_mat", 0.0015)
	for i, c in enumerate(("jar_red", "jar_yellow", "jar_blue")):
		x = 0.12 + i * 0.07
		cyl(0.028, 0.07, (x, 0.035, -0.53), "glass", verts=32)
		cyl(0.025, 0.04, (x, 0.021, -0.53), c, verts=24)
		cyl(0.03, 0.012, (x, 0.076, -0.53), "black", verts=32)
	box((0.11, 0.004, 0.008), (0.36, 0.004, 0.08), "chrome", 0.0015, rot_y=0.44)
	finish("room_bench")

def pc_setup():
	"""Monitor (bezel, neck, base — the live screen stays in the game), mouse and a white keyboard with pastel caps."""
	x, y, z = PC
	box((0.62, 0.37, 0.025), (x, y + 0.33, z - 0.05), "black", 0.006)
	box((0.6, 0.35, 0.004), (x, y + 0.33 + 0.005, z - 0.036), "screen_black", 0.001)
	box((0.05, 0.18, 0.03), (x, y + 0.09, z - 0.08), "black", 0.006)
	box((0.24, 0.012, 0.16), (x, y + 0.006, z - 0.05), "black", 0.005)
	box((0.064, 0.034, 0.112), (x + 0.32, y + 0.017, z + 0.19), "white_plastic", 0.016)
	# 75% keyboard: case + caps in rows (one mesh instead of ~80 nodes)
	kx, kz = x - 0.04, z + 0.19; u = 0.01905
	box((16.4 * u, 0.022, 6.5 * u), (kx, y + 0.011, kz), "white_plastic", 0.006)
	rows = [[1] * 16, [1] * 13 + [2], [1.5] + [1] * 12 + [1.5], [1.75] + [1] * 11 + [2.25], [2.25] + [1] * 10 + [1.75, 1], [1.25] * 3 + [6.25, 1, 1, 1, 1]]
	rng = random.Random(3)
	for r, row in enumerate(rows):
		xx = kx - 16 * u / 2
		for w in row:
			c = "key_white" if w == 1 and rng.random() > 0.18 else ("key_pink" if rng.random() > 0.4 else "key_mint")
			box((w * u - 0.003, 0.009, u - 0.003), (xx + w * u / 2, y + 0.026, kz - 2.6 * u + r * u), c, 0.0025)
			xx += w * u
	finish("room_pc_setup")

def reset_scene():
	for o in list(bpy.context.scene.objects): bpy.data.objects.remove(o, do_unlink=True)

PIECES = {"shell": shell, "window": window, "curtain": curtain, "door": door, "chandelier": chandelier, "wardrobe": wardrobe, "bench": bench, "pc_setup": pc_setup}
for n, fn in PIECES.items():
	if ONLY and n not in ONLY: continue
	reset(); fn()
