# MX-style switch at hero quality (docs/keyboard_spec.md): top housing (tapered walls, LED window, side latches, the
# stem opening), bottom housing below the plate with the centre post, gold pins (separate material), and the stem
# (cross, slider body, guide rails). Exported in key units to assets/kb/switch_mx.glb:
#   node "housing": origin = switch centre on the PLATE TOP; surfaces 0 "housing" (switch colour), 1 "pins" (metal)
#   node "stem":    origin = the top of the top housing (where the game's stem node sits); one surface "stem"
#   blender -b -P tools/blender/kit/kbd_switch.py
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh
from mathutils import Vector, Matrix
import kbd_spec as S
from kbd_caps import rrect, gv

W = S.SWITCH

def loft(bm, outlines, mat_index=0, cap_top=True, cap_bottom=True):
	"""outlines: [(points[(x,z)], y)] bottom -> top, all with the same point count (rrect)."""
	rings = [[bm.verts.new(gv(x, y, z)) for (x, z) in pts] for pts, y in outlines]
	n = len(rings[0]); faces = []
	for a, b in zip(rings, rings[1:]):
		for i in range(n):
			j = (i + 1) % n
			faces.append(bm.faces.new([a[i], a[j], b[j], b[i]]))
	if cap_top: faces.append(bm.faces.new(rings[-1]))
	if cap_bottom: faces.append(bm.faces.new(list(reversed(rings[0]))))
	for f in faces: f.material_index = mat_index
	return faces

def block(bm, size, center, mat_index=0):
	"""Axis-aligned box in switch mm (x, y up, z towards the typist)."""
	r = bmesh.ops.create_cube(bm, size=1.0)
	vs = r["verts"]
	for v in vs:
		v.co = gv(center[0] + v.co.x * size[0], center[1] + v.co.z * size[1], center[2] - v.co.y * size[2])
	faces = list({f for v in vs for f in v.link_faces})
	for f in faces: f.material_index = mat_index
	return faces

def cylinder(bm, r, y0, y1, x, z, mat_index=0, seg=16):
	pts = [(x + r * math.cos(2 * math.pi * k / seg), z + r * math.sin(2 * math.pi * k / seg)) for k in range(seg)]
	rings = [[bm.verts.new(gv(px, y, pz)) for (px, pz) in pts] for y in (y0, y1)]
	faces = []
	for i in range(seg):
		j = (i + 1) % seg
		faces.append(bm.faces.new([rings[0][i], rings[0][j], rings[1][j], rings[1][i]]))
	faces.append(bm.faces.new(rings[1])); faces.append(bm.faces.new(list(reversed(rings[0]))))
	for f in faces: f.material_index = mat_index
	return faces

def obj(bm, name, mats):
	bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
	me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
	o = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(o)
	for mn in mats:
		o.data.materials.append(bpy.data.materials.get(mn) or bpy.data.materials.new(mn))
	# smooth with sharp creases above 40 degrees
	for p in o.data.polygons: p.use_smooth = True
	bpy.context.view_layer.objects.active = o
	for s in bpy.context.scene.objects: s.select_set(s == o)
	bpy.ops.object.shade_smooth_by_angle(angle=math.radians(40))
	return o

def housing():
	bm = bmesh.new()
	tb = W["top_base"]; tt = W["top_top"]; th = W["top_h"]
	# top housing: base flange, tapered body, a rounded top rim
	loft(bm, [(rrect(tb, tb, 1.0), 0.0), (rrect(tb, tb, 1.0), 0.9), (rrect(tb - 0.8, tb - 0.8, 1.2), 1.3),
		(rrect(tt[0] + 0.6, tt[1] + 0.6, 1.6), th - 0.5), (rrect(tt[0], tt[1], 1.4), th)])
	# stem opening: a raised ring around the cross channel and the channel itself (dark recess approximated by a boss)
	cylinder(bm, 3.0, th - 0.01, th + 0.25, 0, 0.0, seg=24)
	# LED window on the north side (towards the back = -z) and the moulded "MX" boss
	block(bm, (5.4, 0.35, 3.2), (0, th + 0.12, -3.9))
	# side latches (the clips that hold the housing halves together)
	for sx in (-1, 1):
		block(bm, (0.9, 2.2, 4.6), (sx * (tb / 2 + 0.2), 0.9, 0))
		block(bm, (0.7, 1.4, 3.0), (sx * (tb / 2 + 0.05), -1.1, 0))
	# bottom housing below the plate (14 x 14) with a rim under the plate
	loft(bm, [(rrect(S.CUTOUT - 0.1, S.CUTOUT - 0.1, 0.8), -W["bottom_h"]), (rrect(S.CUTOUT - 0.1, S.CUTOUT - 0.1, 0.8), -0.2)])
	# centre post and two plastic guide pegs (5-pin)
	cylinder(bm, W["post_d"] / 2, -W["bottom_h"] - 3.0, -W["bottom_h"], 0, 0)
	for sx in (-1, 1): cylinder(bm, 0.85, -W["bottom_h"] - 2.6, -W["bottom_h"], sx * 5.08, 0, seg=10)
	# metal pins (material 1): switch pin + LED/diode pin positions of the MX footprint
	for (px, pz) in [(-3.81, -2.54), (2.54, -5.08)]:
		cylinder(bm, W["pin_d"] / 2, -W["bottom_h"] - W["pin_len"], -W["bottom_h"], px, pz, mat_index=1, seg=10)
	o = obj(bm, "housing", ["housing", "pins"])
	return o

def stem():
	"""Origin at the top of the top housing; the cross rises 1.8 mm above it, the slider hangs inside the housing."""
	bm = bmesh.new()
	arm, thick = W["stem_cross"]
	ch = 1.8
	# the cross as ONE prism (two crossed blocks z-fight in the middle)
	a, t = arm / 2, thick / 2
	outline = [(a, -t), (a, t), (t, t), (t, a), (-t, a), (-t, t), (-a, t), (-a, -t), (-t, -t), (-t, -a), (t, -a), (t, -t)]
	lo = [bm.verts.new(gv(x, -0.6, z)) for (x, z) in outline]
	hi = [bm.verts.new(gv(x, ch, z)) for (x, z) in outline]
	for i in range(len(outline)):
		j = (i + 1) % len(outline)
		bm.faces.new([lo[i], lo[j], hi[j], hi[i]])
	bm.faces.new(hi); bm.faces.new(list(reversed(lo)))
	block(bm, (5.6, 0.9, 5.6), (0, -0.75, 0))                 # collar under the cross
	block(bm, (7.2, 3.6, 4.6), (0, -3.0, 0))                  # slider body (seen through clear tops)
	for sx in (-1, 1): block(bm, (0.9, 4.0, 2.2), (sx * 3.9, -3.2, 0))   # guide rails
	block(bm, (1.4, 2.6, 1.4), (0, -5.4, 2.0))                # leaf actuator
	return obj(bm, "stem", ["stem"])

if __name__ == "__main__":
	bpy.ops.wm.read_factory_settings(use_empty=True)
	objs = [housing(), stem()]
	out = os.path.join(S.GAME, "assets", "kb", "switch_mx.glb")
	for s in bpy.context.scene.objects: s.select_set(s in objs)
	bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, export_yup=True, export_apply=True,
		export_materials="EXPORT", export_normals=True, export_image_format="NONE")
	for o in objs: print("KBD switch %s: %d tris" % (o.name, sum(len(p.vertices) - 2 for p in o.data.polygons)), flush=True)
