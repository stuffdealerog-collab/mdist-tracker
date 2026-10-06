# Core of the room kit (Blender 4.5, run in background mode). Every room asset is authored here at hero quality and
# exported into ONE scene, assets/room/room.glb, that the game loads as is (scripts/world/home.gd binds behaviour by
# node names). Conventions:
#   * coordinates: everything is modelled in GAME metres through g(x, y, z) (Godot: Y up, the room spans X0..X1, Z0..Z1)
#   * materials: slots are named after the shared material library (MATS); Godot maps the names onto its materials,
#     so one 2K oak texture serves all cream furniture (few materials, few draw calls)
#   * UV0: world-space box mapping in METRES (consistent texel density); wood grain follows each part's long axis
#   * UV1: lightmap UVs (Blender "lightmap pack" per object) for LightmapGI
#   * every hard edge is bevelled; weighted normals; no razor edges
#   * moving parts are separate objects with the origin at the hinge / rail ("pivot")
#   * "<name>-colonly" objects become collision in Godot; "IA_<id>-colonly" are interaction volumes
import bpy, bmesh, math, os
from mathutils import Vector, Matrix

# ---- room layout: MUST match scripts/world/home.gd ---------------------------------------------------------------
F = -0.76; CEIL = F + 3.2
X0, X1, Z0, Z1 = -2.15, 3.05, -0.62, 2.78
DOOR_X, DOOR_W, DOOR_H = 2.4, 0.9, 2.15
NICHE = dict(z0=0.22, z1=1.28, d=0.34)
WIN = dict(z0=0.36, z1=1.14, y0=F + 0.92, y1=F + 2.72, transom=F + 2.26)
BENCH = dict(x0=-1.0, x1=1.0, zc=-0.24, d=0.76)
WARD = dict(x0=X1 - 0.6, x1=X1, z0=1.2, z1=2.75, h=2.2)
SHELF_LEVELS = [F + 0.1, F + 0.56, F + 1.02, F + 1.48]
T = 0.14                                     # wall thickness

def g(x, y, z): return Vector((x, -z, y))   # game -> Blender
def gs(sx, sy, sz): return Vector((sx, sz, sy))

# ---- material library (name -> preview colour, roughness, metallic, texture metres per tile, scan folder) ----------
# The Godot side (scripts/world/room_mats.gd) defines the real materials under the same names.
MATS = {
	"wall_damask":   dict(c=(0.62, 0.64, 0.62), r=0.85, m=0.0, tile=1.06),
	"wall_mottle":   dict(c=(0.55, 0.58, 0.59), r=0.88, m=0.0, tile=1.0),
	"ceiling_field": dict(c=(0.62, 0.66, 0.68), r=0.6, m=0.15, tile=1.2),
	"plaster_white": dict(c=(0.86, 0.85, 0.82), r=0.75, m=0.0, tile=1.5, scan="white_plaster_02"),
	"trim_white":    dict(c=(0.88, 0.87, 0.84), r=0.42, m=0.0, tile=1.0),
	"floor_laminate":dict(c=(0.62, 0.6, 0.57), r=0.45, m=0.0, tile=2.0, scan="laminate_floor_02"),
	"wood_cream":    dict(c=(0.8, 0.77, 0.7), r=0.5, m=0.0, tile=1.2, scan="washed_grey_oak_veneer"),
	"wood_cream_b":  dict(c=(0.82, 0.79, 0.72), r=0.5, m=0.0, tile=1.2, scan="grey_oak_veneer_02"),
	"wood_maple":    dict(c=(0.85, 0.8, 0.7), r=0.5, m=0.0, tile=1.0, scan="white_maple_veneer"),
	"wood_dark":     dict(c=(0.24, 0.14, 0.09), r=0.4, m=0.0, tile=1.2, scan="walnut_veneer"),
	"wood_window":   dict(c=(0.3, 0.18, 0.1), r=0.45, m=0.0, tile=0.8, scan="walnut_veneer"),
	"plywood":       dict(c=(0.75, 0.66, 0.52), r=0.7, m=0.0, tile=1.0, scan="plywood"),
	"board_edge":    dict(c=(0.86, 0.84, 0.79), r=0.45, m=0.0, tile=1.0),
	"gold":          dict(c=(0.8, 0.62, 0.3), r=0.3, m=1.0, tile=0.3),
	"chrome":        dict(c=(0.82, 0.82, 0.84), r=0.15, m=1.0, tile=0.3),
	"steel_brushed": dict(c=(0.7, 0.71, 0.72), r=0.35, m=1.0, tile=0.3),
	"black_plastic": dict(c=(0.03, 0.03, 0.035), r=0.45, m=0.0, tile=0.5),
	"white_plastic": dict(c=(0.9, 0.9, 0.89), r=0.35, m=0.0, tile=0.5),
	"rubber":        dict(c=(0.02, 0.02, 0.02), r=0.85, m=0.0, tile=0.3),
	"glass":         dict(c=(0.7, 0.75, 0.75), r=0.03, m=0.0, tile=1.0),
	"glow_white":    dict(c=(1.0, 0.97, 0.92), r=0.5, m=0.0, tile=1.0),
	"fabric_curtain":dict(c=(0.55, 0.47, 0.38), r=0.95, m=0.0, tile=0.6, scan="cotton_jersey"),
	"fabric_plaid":  dict(c=(0.62, 0.7, 0.8), r=0.95, m=0.0, tile=0.45, scan="fabric_pattern_05"),
	"fabric_linen":  dict(c=(0.85, 0.85, 0.83), r=0.95, m=0.0, tile=0.5, scan="rough_linen"),
	"rug":           dict(c=(0.6, 0.66, 0.72), r=0.95, m=0.0, tile=0.0),
	"concrete":      dict(c=(0.42, 0.41, 0.39), r=0.85, m=0.0, tile=1.5),
	"plaster_hall":  dict(c=(0.6, 0.66, 0.62), r=0.8, m=0.0, tile=1.5, scan="painted_plaster_wall"),
	"door_neighbour":dict(c=(0.3, 0.18, 0.1), r=0.45, m=0.0, tile=1.0, scan="walnut_veneer"),
	"doormat":       dict(c=(0.27, 0.2, 0.14), r=0.95, m=0.0, tile=0.4),
	"screen_black":  dict(c=(0.01, 0.01, 0.012), r=0.08, m=0.0, tile=1.0),
	"fabric_pillow": dict(c=(0.86, 0.86, 0.85), r=0.95, m=0.0, tile=0.35, scan="rough_linen"),
	"fabric_white":  dict(c=(0.9, 0.9, 0.89), r=0.95, m=0.0, tile=0.6, scan="rough_linen"),
	"rug_fringe":    dict(c=(0.82, 0.8, 0.74), r=0.95, m=0.0, tile=0.2),
	"glass_jar":     dict(c=(0.9, 0.95, 1.0), r=0.05, m=0.0, tile=1.0),
	"glass_dark":    dict(c=(0.1, 0.1, 0.11), r=0.05, m=0.0, tile=1.0),
	"jar_yellow":    dict(c=(0.85, 0.7, 0.2), r=0.5, m=0.0, tile=0.3),
	"jar_blue":      dict(c=(0.15, 0.35, 0.75), r=0.5, m=0.0, tile=0.3),
	"fabric_mat":    dict(c=(0.1, 0.1, 0.11), r=0.9, m=0.0, tile=0.3),
	"cardboard_box": dict(c=(0.62, 0.48, 0.32), r=0.8, m=0.0, tile=0.5),
	"key_white":     dict(c=(0.92, 0.91, 0.88), r=0.45, m=0.0, tile=0.3),
	"key_mint":      dict(c=(0.65, 0.9, 0.82), r=0.45, m=0.0, tile=0.3),
	"key_pink":      dict(c=(0.95, 0.7, 0.8), r=0.45, m=0.0, tile=0.3),
	"tape_roll":     dict(c=(0.75, 0.6, 0.4), r=0.3, m=0.0, tile=0.2),
	"sticker_label": dict(c=(0.96, 0.96, 0.95), r=0.6, m=0.0, tile=0.2),
	"bubble_wrap":   dict(c=(0.9, 0.95, 1.0), r=0.2, m=0.0, tile=0.3),
	"brand_box":     dict(c=(0.1, 0.1, 0.11), r=0.6, m=0.0, tile=0.5),
	"ceramic_white": dict(c=(0.93, 0.92, 0.9), r=0.2, m=0.0, tile=0.5),
	"soil":          dict(c=(0.15, 0.11, 0.08), r=0.95, m=0.0, tile=0.3),
	"fabric_black":  dict(c=(0.05, 0.05, 0.055), r=0.9, m=0.0, tile=0.5, scan="cotton_jersey"),
	"leaf_green":    dict(c=(0.09, 0.3, 0.08), r=0.45, m=0.0, tile=0.2),
	"petal_white":   dict(c=(0.94, 0.94, 0.9), r=0.5, m=0.0, tile=0.2),
	"spadix":        dict(c=(0.9, 0.85, 0.6), r=0.7, m=0.0, tile=0.2),
	"bamboo":        dict(c=(0.35, 0.55, 0.15), r=0.35, m=0.0, tile=0.2),
	"bamboo_node":   dict(c=(0.5, 0.6, 0.25), r=0.4, m=0.0, tile=0.2),
	"paper":         dict(c=(0.9, 0.88, 0.82), r=0.8, m=0.0, tile=0.2),
	"leather_black": dict(c=(0.03, 0.03, 0.03), r=0.5, m=0.0, tile=0.5, scan="fabric_leather_01"),
	"leather_red":   dict(c=(0.5, 0.05, 0.05), r=0.5, m=0.0, tile=0.5, scan="leather_red_02"),
	"wool_grey":     dict(c=(0.45, 0.44, 0.43), r=0.95, m=0.0, tile=0.4, scan="wool_boucle"),
	"mesh_black":    dict(c=(0.02, 0.02, 0.022), r=0.6, m=0.0, tile=0.1),
	"red_plastic":   dict(c=(0.7, 0.05, 0.05), r=0.4, m=0.0, tile=0.5),
	"glow_red":      dict(c=(1.0, 0.1, 0.08), r=0.5, m=0.0, tile=1.0),
	"glow_rgb":      dict(c=(0.7, 0.5, 1.0), r=0.5, m=0.0, tile=1.0),
}
for _i, (_n, _c) in enumerate([("book_red", (0.5, 0.08, 0.07)), ("book_navy", (0.08, 0.12, 0.3)), ("book_green", (0.08, 0.28, 0.15)),
		("book_cream", (0.85, 0.82, 0.74)), ("book_black", (0.04, 0.04, 0.045)), ("book_orange", (0.75, 0.35, 0.08)),
		("book_teal", (0.07, 0.35, 0.36)), ("book_grey", (0.45, 0.46, 0.48))]):
	MATS[_n] = dict(c=_c, r=0.6, m=0.0, tile=0.3)
SCAN = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "assets", "tex", "scan"))

def reset():
	bpy.ops.wm.read_factory_settings(use_empty=True)
	bpy.context.scene.unit_settings.system = "METRIC"

def mat(name):
	m = bpy.data.materials.get(name)
	if m: return m
	spec = MATS[name]
	m = bpy.data.materials.new(name); m.use_nodes = True
	nt = m.node_tree; b = nt.nodes["Principled BSDF"]
	b.inputs["Base Color"].default_value = (*spec["c"], 1); b.inputs["Roughness"].default_value = spec["r"]; b.inputs["Metallic"].default_value = spec["m"]
	# preview only (renders in Blender): the scan albedo at the material's physical tile size
	if spec.get("scan"):
		p = os.path.join(SCAN, spec["scan"], "albedo.jpg")
		if os.path.exists(p):
			tex = nt.nodes.new("ShaderNodeTexImage"); tex.image = bpy.data.images.load(p, check_existing=True)
			uv = nt.nodes.new("ShaderNodeUVMap"); uv.uv_map = "UVMap"
			mp = nt.nodes.new("ShaderNodeMapping"); s = 1.0 / spec["tile"]; mp.inputs["Scale"].default_value = (s, s, 1)
			nt.links.new(uv.outputs[0], mp.inputs[0]); nt.links.new(mp.outputs[0], tex.inputs[0])
			nt.links.new(tex.outputs[0], b.inputs["Base Color"])
	return m

# ---- primitives (all in game coordinates) -----------------------------------------------------------------------
_PARTS = []          # objects created since the last take() — the parts of the asset being built

def _new(o, material, bevel=0.0, segs=3, grain=None):
	o.data.materials.clear(); o.data.materials.append(mat(material))
	if bevel > 0:
		bm = o.modifiers.new("bevel", "BEVEL"); bm.width = bevel; bm.segments = segs; bm.limit_method = "ANGLE"
		bm.angle_limit = math.radians(40); bm.harden_normals = False; bm.miter_outer = "MITER_ARC"
	o["grain"] = grain or ""
	_PARTS.append(o); return o

def box(size, center, material, bevel=0.002, segs=3, rot=(0, 0, 0), grain=None, name="box"):
	"""Box: size (x, y up, z) in metres, centre in game coords, rot in degrees about game axes (x, y, z)."""
	bpy.ops.mesh.primitive_cube_add(size=1.0)
	o = bpy.context.active_object; o.name = name
	o.scale = gs(*size)
	o.rotation_euler = (math.radians(rot[0]), -math.radians(rot[2]), math.radians(rot[1]))
	o.location = g(*center)
	bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
	return _new(o, material, bevel, segs, grain)

def span(xa, xb, ya, yb, za, zb, material, bevel=0.0, grain=None, name="span"):
	return box((xb - xa, yb - ya, zb - za), ((xa + xb) / 2, (ya + yb) / 2, (za + zb) / 2), material, bevel, grain=grain, name=name)

def cyl(r, h, center, material, axis="y", verts=32, bevel=0.0015, r2=None, name="cyl"):
	rot = {"y": (0, 0, 0), "x": (0, math.pi / 2, 0), "z": (math.pi / 2, 0, 0)}[axis]
	if r2 is None: bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=h, vertices=verts, rotation=rot)
	else: bpy.ops.mesh.primitive_cone_add(radius1=r2, radius2=r, depth=h, vertices=verts, rotation=rot)
	o = bpy.context.active_object; o.name = name; o.location = g(*center)
	bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
	return _new(o, material, bevel, 2)

def sweep(profile, path, material, closed=False, name="sweep", grain=None):
	"""Extrude a 2D profile [(u, v)] (u = outward from the wall, v = up, metres) along a polyline path of game points.
	Corners are mitred (the profile is scaled by 1/cos(half angle) along the bisector)."""
	bm = bmesh.new()
	P = [Vector(p) for p in path]; n = len(P)
	rings = []
	for i in range(n):
		if closed: a, b = P[i - 1], P[(i + 1) % n]
		else: a, b = P[max(i - 1, 0)], P[min(i + 1, n - 1)]
		t_in = (P[i] - a).normalized() if (P[i] - a).length > 1e-9 else (b - P[i]).normalized()
		t_out = (b - P[i]).normalized() if (b - P[i]).length > 1e-9 else t_in
		tan = (t_in + t_out).normalized()
		up = Vector((0, 1, 0))
		side = up.cross(tan).normalized()                 # horizontal normal to the path (game coords)
		cosh = max(0.2, t_in.dot(tan))
		ring = []
		for (u, v) in profile:
			q = P[i] + side * (u / cosh) + up * v
			ring.append(bm.verts.new(g(q.x, q.y, q.z)))
		rings.append(ring)
	m = len(profile)
	segs = n if closed else n - 1
	for i in range(segs):
		r0, r1 = rings[i], rings[(i + 1) % n]
		for k in range(m - 1):
			bm.faces.new([r0[k], r0[k + 1], r1[k + 1], r1[k]])
	if not closed:
		for r in (rings[0], rings[-1]):
			try: bm.faces.new(r)
			except ValueError: pass
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
	o = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(o)
	return _new(o, material, 0.0, grain=grain)

def lathe(profile, center, material, verts=48, name="lathe"):
	"""Revolve [(r, y)] around the game Y axis at centre."""
	bm = bmesh.new()
	rings = []
	for i in range(verts):
		a = 2 * math.pi * i / verts
		rings.append([bm.verts.new(g(center[0] + r * math.cos(a), center[1] + y, center[2] + r * math.sin(a))) for (r, y) in profile])
	for i in range(verts):
		r0, r1 = rings[i], rings[(i + 1) % verts]
		for k in range(len(profile) - 1):
			bm.faces.new([r0[k], r1[k], r1[k + 1], r0[k + 1]])
	bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
	o = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(o)
	o.data.polygons.foreach_set("use_smooth", [True] * len(o.data.polygons))
	return _new(o, material, 0.0)

# ---- UVs ---------------------------------------------------------------------------------------------------------
def uv_world(o):
	"""UV0 = box projection in world metres. Wood grain (o['grain'] = 'x'|'y'|'z' game axis, or auto = longest
	dimension) runs along U so planks/boards look cut from real veneer."""
	me = o.data
	if not me.uv_layers: me.uv_layers.new(name="UVMap")
	uvl = me.uv_layers[0]
	if o.get("keep_uv"): return
	if o.get("rug_uv"):                                                 # one image over the whole rug top
		x0, z0, w, d = o["rug_uv"]
		for poly in me.polygons:
			for li in poly.loop_indices:
				wv = o.matrix_world @ me.vertices[me.loops[li].vertex_index].co
				uvl.data[li].uv = ((wv.x - x0) / w, 1.0 - ((-wv.y) - z0) / d)
		return
	gr = o.get("grain", "")
	if gr == "":
		dims = [o.dimensions.x, o.dimensions.z, o.dimensions.y]          # game x, y, z extents
		gr = "xyz"[dims.index(max(dims))]
	for poly in me.polygons:
		nrm = o.matrix_world.to_3x3() @ poly.normal
		gn = (abs(nrm.x), abs(nrm.z), abs(nrm.y))                      # game x, y, z
		ax = gn.index(max(gn))                                          # projection axis (game)
		plane = [i for i in range(3) if i != ax]
		gi = "xyz".index(gr)
		if gi in plane: u_ax = gi; v_ax = [i for i in plane if i != gi][0]
		else: u_ax, v_ax = plane
		for li in poly.loop_indices:
			w = o.matrix_world @ me.vertices[me.loops[li].vertex_index].co
			gp = (w.x, w.z, -w.y)
			uvl.data[li].uv = (gp[u_ax], gp[v_ax])

def uv_lightmap(o, margin=0.02):
	me = o.data
	while len(me.uv_layers) < 2: me.uv_layers.new(name="UV2")
	me.uv_layers.active_index = 1
	for s in bpy.context.scene.objects: s.select_set(s == o)
	bpy.context.view_layer.objects.active = o
	bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
	bpy.ops.uv.lightmap_pack(PREF_CONTEXT="ALL_FACES", PREF_PACK_IN_ONE=True, PREF_BOX_DIV=12, PREF_MARGIN_DIV=margin)
	bpy.ops.object.mode_set(mode="OBJECT")
	me.uv_layers.active_index = 0

# ---- assembling -----------------------------------------------------------------------------------------------------
def take(name, pivot=None, lightmap=True, smooth_angle=35.0, parent=None):
	"""Join the parts built since the last take() into one object: bevels applied, world UVs, weighted normals,
	lightmap UV2, origin at `pivot` (game coords) or at the world origin."""
	parts = list(_PARTS); _PARTS.clear()
	if not parts: return None
	for o in parts:
		bpy.context.view_layer.objects.active = o
		for s in bpy.context.scene.objects: s.select_set(s == o)
		for m in list(o.modifiers): bpy.ops.object.modifier_apply(modifier=m.name)
		uv_world(o)
	for s in bpy.context.scene.objects: s.select_set(s in parts)
	bpy.context.view_layer.objects.active = parts[0]
	if len(parts) > 1: bpy.ops.object.join()
	o = bpy.context.active_object; o.name = name; o.data.name = name
	bm = bmesh.new(); bm.from_mesh(o.data); bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5); bm.to_mesh(o.data); bm.free()
	o.data.polygons.foreach_set("use_smooth", [True] * len(o.data.polygons))
	# sharp edges by angle, then weighted normals keep flat faces flat and bevels round
	bm = bmesh.new(); bm.from_mesh(o.data)
	for e in bm.edges:
		if len(e.link_faces) == 2 and e.calc_face_angle(0) > math.radians(smooth_angle): e.smooth = False
	bm.to_mesh(o.data); bm.free()
	wn = o.modifiers.new("wn", "WEIGHTED_NORMAL"); wn.keep_sharp = True; wn.weight = 50
	bpy.ops.object.modifier_apply(modifier="wn")
	if pivot is not None:
		pv = g(*pivot); o.data.transform(Matrix.Translation(-pv)); o.location = pv
	if lightmap: uv_lightmap(o)
	if parent: o.parent = parent; o.matrix_parent_inverse = parent.matrix_world.inverted()
	o["tris"] = sum(len(p.vertices) - 2 for p in o.data.polygons)
	return o

def collider(name, size, center, rot_y=0.0):
	"""Invisible box collider (Godot: '-colonly' -> StaticBody3D + shape)."""
	bpy.ops.mesh.primitive_cube_add(size=1.0)
	o = bpy.context.active_object; o.name = name + "-colonly"
	o.scale = gs(*size); o.rotation_euler = (0, 0, rot_y); o.location = g(*center)
	bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
	o["collider"] = 1
	return o

def empty(name, pos, parent=None):
	o = bpy.data.objects.new(name, None); o.location = g(*pos); bpy.context.scene.collection.objects.link(o)
	if parent: o.parent = parent
	return o

def export(path, objects=None):
	os.makedirs(os.path.dirname(path), exist_ok=True)
	for s in bpy.context.scene.objects: s.select_set(objects is None or s in objects)
	bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=objects is not None, export_yup=True,
		export_apply=True, export_materials="EXPORT", export_normals=True, export_texcoords=True, export_extras=True,
		export_image_format="NONE")
	tris = sum(o.get("tris", 0) for o in bpy.context.scene.objects if o.type == "MESH")
	print("KIT exported %s objects=%d tris=%d" % (path, len(bpy.context.scene.objects), tris), flush=True)

# ---- local frames: furniture is written in its own axes (x = left->right as seen from the front, y = up,
#      z = towards the viewer), then placed with a facing ('+x', '-x', '+z', '-z' = where the front looks) --------------
class Frame:
	def __init__(self, origin, facing):
		f = {"+x": (1, 0, 0), "-x": (-1, 0, 0), "+z": (0, 0, 1), "-z": (0, 0, -1)}[facing]
		self.o = Vector(origin); self.f = Vector(f); self.r = (-self.f).cross(Vector((0, 1, 0)))
	def p(self, x, y, z):
		q = self.o + self.r * x + Vector((0, y, 0)) + self.f * z
		return (q.x, q.y, q.z)
	def s(self, sx, sy, sz):
		return (abs(self.r.x) * sx + abs(self.f.x) * sz, sy, abs(self.r.z) * sx + abs(self.f.z) * sz)
	def ax(self, a):
		if a in (None, "", "y"): return a
		v = self.r if a == "x" else self.f
		return "x" if abs(v.x) > 0.5 else "z"
	def box(self, size, center, material, bevel=0.002, segs=3, grain=None, name="box"):
		return box(self.s(*size), self.p(*center), material, bevel, segs, grain=self.ax(grain), name=name)
	def span(self, xa, xb, ya, yb, za, zb, material, bevel=0.0, grain=None, name="span", segs=3):
		return self.box((xb - xa, yb - ya, zb - za), ((xa + xb) / 2, (ya + yb) / 2, (za + zb) / 2), material, bevel, segs, grain=grain, name=name)
	def cyl(self, r, h, center, material, axis="y", verts=32, bevel=0.0015, r2=None, name="cyl"):
		a = axis if axis == "y" else self.ax(axis)
		return cyl(r, h, self.p(*center), material, a, verts, bevel, r2, name)
	def yaw(self):
		"""Rotation (radians, about game Y) that turns local +z into the facing."""
		return math.atan2(self.f.x, self.f.z)
