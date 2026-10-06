# Quick look renders of art/room/room.blend from game camera spots (Eevee): model review before Godot.
#   blender -b art/room/room.blend -P tools/blender/kit/preview.py -- <out_dir> [shot ...]
import bpy, sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from core import g, F, CEIL, X0, X1, Z0, Z1, DOOR_X
from mathutils import Vector

a = sys.argv[sys.argv.index("--") + 1:]
OUT = a[0]; ONLY = a[1:]
os.makedirs(OUT, exist_ok=True)
EYE = F + 1.62
SHOTS = {
	"window": ((2.6, EYE, 1.2), (-2.4, F + 1.3, 0.75)),
	"door":   ((0.0, EYE, 2.2), (2.4, F + 1.3, -0.6)),
	"ceiling":((0.4, F + 1.4, 1.1), (1.5, CEIL, 0.0)),
	"wardrobe":((-0.5, EYE, 0.6), (3.0, F + 1.2, 2.0)),
	"door_close":((1.6, EYE, 0.9), (2.4, F + 1.4, -0.62)),
	"window_close":((-0.8, F + 1.4, 0.75), (-2.45, F + 1.2, 0.75)),
}
sc = bpy.context.scene
sc.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE"
sc.render.resolution_x, sc.render.resolution_y = 1280, 720
sc.view_settings.view_transform = "AgX"
for o in list(sc.objects):
	if o.name.endswith("-colonly"): o.hide_render = True
w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True; w.node_tree.nodes["Background"].inputs[1].default_value = 0.6
w.node_tree.nodes["Background"].inputs[0].default_value = (0.75, 0.82, 0.95, 1)
# lights: sun through the window, chandelier area, fill
sun = bpy.data.lights.new("sun", "SUN"); sun.energy = 4.0; so = bpy.data.objects.new("sun", sun); sc.collection.objects.link(so)
so.rotation_euler = (math.radians(55), 0, math.radians(-75))
ar = bpy.data.lights.new("ch", "AREA"); ar.energy = 450; ar.size = 1.0; ao = bpy.data.objects.new("ch", ar); sc.collection.objects.link(ao)
ao.location = g((X0 + X1) / 2, CEIL - 0.35, (Z0 + Z1) / 2)
cam = bpy.data.cameras.new("cam"); cam.lens = 18; co = bpy.data.objects.new("cam", cam); sc.collection.objects.link(co); sc.camera = co
for name, (p, t) in SHOTS.items():
	if ONLY and name not in ONLY: continue
	co.location = g(*p)
	d = g(*t) - g(*p)
	co.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
	sc.render.filepath = os.path.join(OUT, name + ".png")
	bpy.ops.render.render(write_still=True)
	print("PREVIEW", name, flush=True)
