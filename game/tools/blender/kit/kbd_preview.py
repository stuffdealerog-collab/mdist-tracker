# Review render of the keycap GLBs: a grid (profiles x [R1, R2, R3, R4, 2.25u R4]) seen from the typist, and a close-up
# of one cap from below (hollow, wall, stem post with the cross).
#   blender -b -P tools/blender/kit/kbd_preview.py -- <out_dir>
import bpy, sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kbd_spec as S
from mathutils import Vector
out = sys.argv[sys.argv.index("--") + 1]
os.makedirs(out, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.engine = "BLENDER_EEVEE_NEXT"; sc.render.resolution_x, sc.render.resolution_y = 1600, 1100
sc.view_settings.view_transform = "AgX"
w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.2, 0.21, 0.23, 1); w.node_tree.nodes["Background"].inputs[1].default_value = 0.5
def mat(name, c, r):
	m = bpy.data.materials.new(name); m.use_nodes = True; b = m.node_tree.nodes["Principled BSDF"]
	b.inputs["Base Color"].default_value = (*c, 1); b.inputs["Roughness"].default_value = r; return m
side = mat("side", (0.78, 0.76, 0.7), 0.5); top = mat("top", (0.86, 0.84, 0.78), 0.45)
cols = ["cap_r0_1", "cap_r1_1", "cap_r2_1", "cap_r3_1", "cap_r3_2.25"]
for pi, prof in enumerate(S.PROFILES):
	bpy.ops.import_scene.gltf(filepath=os.path.join(S.GAME, "assets", "kb", "caps_%s.glb" % prof))
	for o in list(bpy.context.selected_objects):
		base = o.name.split(".")[0]
		want = cols if prof != "xda" else ["cap_r0_1", "cap_r0_1", "cap_r0_1", "cap_r0_1", "cap_r0_2.25"]
		if o.type != "MESH" or base not in want: bpy.data.objects.remove(o); continue
		o.data.materials[0] = side
		if len(o.data.materials) > 1: o.data.materials[1] = top
		ci = want.index(base)
		o.location = (ci * 1.25 + (0.7 if "2.25" in base else 0), pi * 1.35, 0)
gl = bpy.data.lights.new("key", "AREA"); gl.energy = 900; gl.size = 5
lo = bpy.data.objects.new("key", gl); sc.collection.objects.link(lo); lo.location = (2, -4, 9); lo.rotation_euler = (math.radians(25), 0, 0)
fl = bpy.data.lights.new("fill", "AREA"); fl.energy = 250; fl.size = 8
fo = bpy.data.objects.new("fill", fl); sc.collection.objects.link(fo); fo.location = (10, 4, 4); fo.rotation_euler = (math.radians(60), 0, math.radians(110))
cam = bpy.data.cameras.new("c"); cam.lens = 38; co = bpy.data.objects.new("c", cam); sc.collection.objects.link(co); sc.camera = co
def look(cam_pos, target):
	co.location = cam_pos
	co.rotation_euler = (Vector(target) - Vector(cam_pos)).to_track_quat("-Z", "Y").to_euler()
look((3.2, -7.5, 6.0), (3.2, 3.2, 0.2))
sc.render.filepath = os.path.join(out, "caps_grid.png"); bpy.ops.render.render(write_still=True)
# underside close-up of the SA R3 1u and the 2.25u
for o in sc.objects:
	if o.type == "MESH": o.hide_render = not (abs(o.location.y - 1.35 * 2) < 0.01 and o.name.split(".")[0] in ("cap_r2_1", "cap_r3_2.25"))
up = bpy.data.lights.new("under", "AREA"); up.energy = 300; up.size = 4
uo = bpy.data.objects.new("under", up); sc.collection.objects.link(uo); uo.location = (3, 2.7, -4); uo.rotation_euler = (math.radians(180), 0, 0)
look((3.0, 0.4, -3.2), (3.0, 2.7, 0.2))
sc.render.filepath = os.path.join(out, "caps_under.png"); bpy.ops.render.render(write_still=True)
print("KBD preview done", flush=True)
