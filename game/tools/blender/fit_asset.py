# Blender (4.5) batch script: fit a generated model for the game.
#   blender -b -P fit_asset.py -- <in.glb> <out.glb> <size_m> [axis=h|max] [rot_y_deg=0] [faces=0] [preview.png]
# - joins all meshes, applies transforms
# - rotates around Y (Godot up) so the front faces +Z, scales so height (h) or the longest side (max) = size_m
# - origin at the bottom centre, optional extra decimation, smooth shading with sharp edges kept
# - exports a .glb with embedded PBR textures and renders a 3/4 preview (Eevee) for checking
import bpy, sys, math, os
from mathutils import Vector, Matrix

a = sys.argv[sys.argv.index("--") + 1:]
src, dst, size = a[0], a[1], float(a[2])
axis = a[3] if len(a) > 3 else "h"
rot_y = float(a[4]) if len(a) > 4 else 0.0
faces = int(a[5]) if len(a) > 5 else 0
preview = a[6] if len(a) > 6 else ""

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
for o in bpy.context.scene.objects: o.select_set(False)
for o in meshes: o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1: bpy.ops.object.join()
obj = bpy.context.view_layer.objects.active
# drop empties / parents so the mesh owns its transform
bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
for o in list(bpy.context.scene.objects):
	if o != obj: bpy.data.objects.remove(o, do_unlink=True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# Blender is Z-up; glTF/Godot Y-up maps to Blender Z, glTF +Z (front) maps to Blender -Y
if rot_y: obj.rotation_euler = (0, 0, math.radians(rot_y)); bpy.ops.object.transform_apply(rotation=True)
bpy.context.view_layer.update()
bb = [obj.matrix_world @ v.co for v in obj.data.vertices]   # exact, not the lazily updated bound_box
mn = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
mx = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
dim = mx - mn
k = size / (dim.z if axis == "h" else max(dim))
centre = Vector(((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, mn.z))
obj.data.transform(Matrix.Translation(-centre))
obj.data.transform(Matrix.Scale(k, 4))
obj.location = (0, 0, 0)

if faces and len(obj.data.polygons) > faces:
	m = obj.modifiers.new("dec", "DECIMATE"); m.ratio = faces / len(obj.data.polygons)
	bpy.ops.object.modifier_apply(modifier=m.name)
# keep the generator's smooth custom normals: no angle-based auto smooth (it cut noisy surfaces into sharp facets)
if faces: bpy.ops.object.shade_smooth()
bpy.context.view_layer.update()
dim = obj.dimensions
print("FIT %s tris=%d size=%.3f x %.3f x %.3f m" % (os.path.basename(dst), sum(len(p.vertices) - 2 for p in obj.data.polygons), dim.x, dim.y, dim.z))

os.makedirs(os.path.dirname(os.path.abspath(dst)), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", use_selection=False, export_yup=True, export_apply=True,
	export_image_format="AUTO", export_texcoords=True, export_normals=True, export_materials="EXPORT")

if preview:
	sc = bpy.context.scene
	sc.render.engine = "BLENDER_EEVEE_NEXT"
	sc.render.resolution_x = 900; sc.render.resolution_y = 900
	sc.render.film_transparent = False
	w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
	w.node_tree.nodes["Background"].inputs[0].default_value = (0.82, 0.83, 0.85, 1); w.node_tree.nodes["Background"].inputs[1].default_value = 0.9
	d = max(obj.dimensions)
	cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
	cam.data.lens = 50
	tgt = Vector((0, 0, obj.dimensions.z * 0.45))
	cam.location = tgt + Vector((d * 0.85, -d * 1.25, d * 0.62))
	cam.rotation_euler = (tgt - cam.location).to_track_quat("-Z", "Y").to_euler()
	sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); sc.collection.objects.link(sun)
	sun.data.energy = 3.0; sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(30))
	key = bpy.data.objects.new("key", bpy.data.lights.new("key", "AREA")); sc.collection.objects.link(key)
	key.data.energy = 300 * d * d; key.data.size = d; key.location = tgt + Vector((-d, -d * 1.5, d * 1.5))
	key.rotation_euler = (tgt - key.location).to_track_quat("-Z", "Y").to_euler()
	sc.render.filepath = preview
	bpy.ops.render.render(write_still=True)
	print("PREVIEW", preview)
