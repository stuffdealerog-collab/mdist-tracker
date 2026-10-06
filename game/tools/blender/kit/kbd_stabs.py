# Stabilizers at hero quality (docs/keyboard_spec.md): a plate-mount housing (Cherry style, clips into the plate) and a
# screw-in housing (PCB mount, with screw heads), the stab stem with its cross, and the bent wire for both spacings
# (23.8 mm for 2-2.75u, 100 mm for 6.25u). Key units, exported to assets/kb/stabs.glb:
#   "housing_plate", "housing_screw": origin = stab stem centre on the plate top; surfaces housing / metal
#   "stem": origin = plate top (as the housing); "wire_short", "wire_long": origin = midpoint between the two stems
#   blender -b -P tools/blender/kit/kbd_stabs.py
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh
from mathutils import Vector
import kbd_spec as S
from kbd_caps import rrect, gv
from kbd_switch import loft, block, cylinder, obj

def housing(name, screw):
	bm = bmesh.new()
	# body above the plate: a tapered block with a channel for the stem
	loft(bm, [(rrect(6.4, 11.6, 0.8), 0.0), (rrect(6.2, 11.2, 0.9), 3.6), (rrect(5.6, 10.0, 1.0), 5.2)])
	block(bm, (6.6, 1.2, 12.3), (0, -0.6, 0))                   # flange in the plate cut-out
	loft(bm, [(rrect(6.0, 10.6, 0.8), -3.4), (rrect(6.0, 10.6, 0.8), -1.2)])   # below the plate
	block(bm, (2.2, 2.0, 3.0), (0, 1.0, -6.6))                  # wire clip (back)
	if screw:
		block(bm, (6.8, 1.2, 14.6), (0, -3.6, 0))               # PCB foot
		for sz in (-5.6, 5.6): cylinder(bm, 1.25, -4.6, -4.2, 0, sz, mat_index=1, seg=16)   # screw heads under the PCB
	return obj(bm, name, ["housing", "metal"])

def stem():
	bm = bmesh.new()
	block(bm, (3.4, 6.0, 4.4), (0, 3.4, 0.6))                   # slider
	a, t = 2.0, 0.6
	outline = [(a, -t), (a, t), (t, t), (t, a), (-t, a), (-t, t), (-a, t), (-a, -t), (-t, -t), (-t, -a), (t, -a), (t, -t)]
	lo = [bm.verts.new(gv(x, 6.2, z + 0.6)) for (x, z) in outline]
	hi = [bm.verts.new(gv(x, 8.2, z + 0.6)) for (x, z) in outline]
	for i in range(len(outline)):
		j = (i + 1) % len(outline)
		bm.faces.new([lo[i], lo[j], hi[j], hi[i]])
	bm.faces.new(hi); bm.faces.new(list(reversed(lo)))
	return obj(bm, "stem", ["stem"])

def wire(name, spacing):
	"""U-shaped wire behind the stems: legs go back from each stem, a straight bar joins them. A swept circle."""
	h, r, back = 1.6, S.STAB_WIRE_D / 2, -6.6
	s = spacing / 2
	path = [(-s, h, 1.0), (-s, h, back + 1.2), (-s + 0.9, h, back), (s - 0.9, h, back), (s, h, back + 1.2), (s, h, 1.0)]
	bm = bmesh.new(); seg = 10
	rings = []
	for i, p in enumerate(path):
		a = Vector(path[max(i - 1, 0)]); b = Vector(path[min(i + 1, len(path) - 1)]); P = Vector(p)
		tdir = (b - a).normalized()
		up = Vector((0, 1, 0)); side = tdir.cross(up).normalized()
		rings.append([bm.verts.new(gv(*(P + side * (r * math.cos(2 * math.pi * k / seg)) + up * (r * math.sin(2 * math.pi * k / seg))))) for k in range(seg)])
	for ra, rb in zip(rings, rings[1:]):
		for k in range(seg):
			m = (k + 1) % seg
			bm.faces.new([ra[k], ra[m], rb[m], rb[k]])
	bm.faces.new(rings[0]); bm.faces.new(list(reversed(rings[-1])))
	for f in bm.faces: f.material_index = 0
	return obj(bm, name, ["metal"])

if __name__ == "__main__":
	bpy.ops.wm.read_factory_settings(use_empty=True)
	objs = [housing("housing_plate", False), housing("housing_screw", True), stem(), wire("wire_short", S.STAB_SPACING[2.0]), wire("wire_long", S.STAB_SPACING[6.25])]
	out = os.path.join(S.GAME, "assets", "kb", "stabs.glb")
	for o in bpy.context.scene.objects: o.select_set(o in objs)
	bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, export_yup=True, export_apply=True,
		export_materials="EXPORT", export_normals=True, export_image_format="NONE")
	for o in objs: print("KBD stab %s: %d tris" % (o.name, sum(len(p.vertices) - 2 for p in o.data.polygons)), flush=True)
