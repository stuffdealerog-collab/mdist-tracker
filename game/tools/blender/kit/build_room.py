# Builds the whole flat from the kit and exports assets/room/room.glb (+ room.blend for inspection).
#   blender -b -P tools/blender/kit/build_room.py -- [only=arch,furniture,...]
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib, core, arch
for m in (core, arch): importlib.reload(m)
from core import *

GAME = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
reset()
arch.walls(); arch.floor(); arch.skirting(); arch.ceiling(); arch.window(); arch.door(); arch.landing(); arch.fittings()
import furn_storage; importlib.reload(furn_storage); furn_storage.build()
import furn_living; importlib.reload(furn_living); furn_living.build()
import furn_tech; importlib.reload(furn_tech); furn_tech.build()
import furn_props; importlib.reload(furn_props); furn_props.build()
import foliage; importlib.reload(foliage); foliage.build()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(GAME, "art", "room", "room.blend"))
export(os.path.join(GAME, "assets", "room", "room.glb"))
for o in sorted(bpy.context.scene.objects, key=lambda o: -o.get("tris", 0)):
	if o.type == "MESH" and o.get("tris"): print("  %-26s %7d tris" % (o.name, o["tris"]))
