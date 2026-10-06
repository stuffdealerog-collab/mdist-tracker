# Switch plates with real cut-outs, one per layout of the catalog (docs/keyboard_spec.md): 14 x 14 mm switch holes at
# every key, 6.75 x 12.3 mm stabilizer holes at the real spacing, rounded outline. Matches the game's plate slab
# (Keyboard3D: (W + 0.12) x (H + 0.12) key units, PLATE_TH thick, bottom at y = 0, UV 0..1 over the top).
# Exported in key units to assets/kb/plate_<layout>.glb (node "plate").
#   blender -b -P tools/blender/kit/kbd_plates.py
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh
import kbd_spec as S

PLATE_TH = 0.03                    # Keyboard3D.PLATE_TH (key units)

def rounded_plate(W, H, r, th):
	bpy.ops.mesh.primitive_cube_add(size=1.0)
	o = bpy.context.active_object; o.scale = (W, H, th); o.location = (0, 0, th / 2)
	bpy.ops.object.transform_apply(location=True, scale=True)
	b = o.modifiers.new("b", "BEVEL"); b.width = r; b.segments = 6; b.affect = "EDGES"
	# bevel only the 4 vertical corner edges
	bm = bmesh.new(); bm.from_mesh(o.data)
	for e in bm.edges: e.select = abs(e.verts[0].co.z - e.verts[1].co.z) > th * 0.5
	bm.to_mesh(o.data); bm.free()
	b.limit_method = "ANGLE"; b.angle_limit = math.radians(60)
	bpy.ops.object.modifier_apply(modifier="b")
	return o

def cutters(lay, th):
	W, H = float(lay["W"]), float(lay["H"])
	cut = S.CUTOUT / S.U; sw, sd = S.STAB_CUTOUT[0] / S.U, S.STAB_CUTOUT[1] / S.U
	bm = bmesh.new()
	def hole(cx, cz, w, d):
		r = bmesh.ops.create_cube(bm, size=1.0)
		for v in r["verts"]:
			v.co.x = cx + v.co.x * w; v.co.y = -cz - v.co.y * d; v.co.z = th / 2 + v.co.z * th * 3
	for k in lay["keys"]:
		x = float(k["x"]) + float(k["w"]) / 2 - W / 2; z = float(k["y"]) + 0.5 - H / 2
		hole(x, z, cut, cut)
		w = float(k["w"])
		if w >= 2.0:
			dx = (S.STAB_SPACING[6.25] if w >= 6.0 else S.STAB_SPACING[2.0]) / 2 / S.U
			for sx in (-1, 1): hole(x + sx * dx, z, sw, sd)
	me = bpy.data.meshes.new("cut"); bm.to_mesh(me); bm.free()
	c = bpy.data.objects.new("cut", me); bpy.context.scene.collection.objects.link(c)
	return c

def plate(name, lay):
	W, H = float(lay["W"]) + 0.12, float(lay["H"]) + 0.12
	o = rounded_plate(W, H, 0.06, PLATE_TH)
	c = cutters(lay, PLATE_TH)
	m = o.modifiers.new("cut", "BOOLEAN"); m.operation = "DIFFERENCE"; m.object = c; m.solver = "EXACT"
	bpy.context.view_layer.objects.active = o
	bpy.ops.object.modifier_apply(modifier="cut")
	bpy.data.objects.remove(c)
	# UV: planar over the top, 0..1 like the game's slab (u along X, v along Z towards the typist)
	me = o.data
	uvl = me.uv_layers.new(name="UVMap")
	for li, l in enumerate(me.loops):
		co = me.vertices[l.vertex_index].co
		uvl.data[li].uv = (co.x / W + 0.5, 1.0 - (-co.y / H + 0.5))
	for p in me.polygons: p.use_smooth = False
	o.name = name; o.data.name = name
	o.data.materials.append(bpy.data.materials.get("plate") or bpy.data.materials.new("plate"))
	return o

if __name__ == "__main__":
	for lid, lay in S.layouts().items():
		bpy.ops.wm.read_factory_settings(use_empty=True)
		o = plate("plate", lay)
		# the exporter's +Y up: Blender Z up -> glTF Y up, Blender -Y (towards the typist) -> glTF +Z
		out = os.path.join(S.GAME, "assets", "kb", "plate_%s.glb" % lid)
		for s in bpy.context.scene.objects: s.select_set(s == o)
		bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, export_yup=True, export_apply=True,
			export_materials="EXPORT", export_normals=True, export_image_format="NONE")
		print("KBD plate %s: %d tris" % (lid, sum(len(p.vertices) - 2 for p in o.data.polygons)), flush=True)
