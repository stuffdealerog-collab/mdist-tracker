"""Game-ready import settings for generated art (run after `godot --headless --import`, then import again).
  - textures in assets/tex/hq and textures extracted from models: VRAM compression (BC7/ASTC) + mipmaps,
    normal maps flagged as normal maps
  - models (.glb): automatic LODs, shadow meshes, lightmap UV2 for LightmapGI baking
Usage: python tools/import_fix.py
"""
import glob, os, re

GAME = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

def patch(path, pairs):
	s = open(path, encoding="utf-8").read(); o = s
	for k, v in pairs.items():
		if re.search(r"^%s=" % re.escape(k), s, re.M): s = re.sub(r"^%s=.*$" % re.escape(k), "%s=%s" % (k, v), s, flags=re.M)
		else: s = s.replace("[params]\n", "[params]\n\n%s=%s\n" % (k, v), 1)
	if s != o: open(path, "w", encoding="utf-8").write(s); return 1
	return 0

n = 0
for f in glob.glob(os.path.join(GAME, "assets", "tex", "hq", "*.png.import")) + glob.glob(os.path.join(GAME, "assets", "models", "*.png.import")):
	p = {"compress/mode": "2", "mipmaps/generate": "true"}
	low = f.lower()
	if low.endswith("_normal.png.import"): p["compress/normal_map"] = "1"
	n += patch(f, p)
for f in glob.glob(os.path.join(GAME, "assets", "models", "*.glb.import")):
	n += patch(f, {"meshes/generate_lods": "true", "meshes/create_shadow_meshes": "true", "meshes/light_baking": "2", "meshes/lightmap_texel_size": "0.05"})
# the room scene: keep the lightmap UV2 authored in Blender (light_baking 1 = static, no re-unwrap), no auto-LOD
# (auto-LOD creases flat panels, see the hybrid3d lessons), shadow meshes on
for f in glob.glob(os.path.join(GAME, "assets", "room", "*.glb.import")):
	n += patch(f, {"meshes/generate_lods": "false", "meshes/create_shadow_meshes": "true", "meshes/light_baking": "1"})
for f in glob.glob(os.path.join(GAME, "assets", "tex", "room", "*.png.import")) + glob.glob(os.path.join(GAME, "assets", "tex", "room", "*.jpg.import")) + glob.glob(os.path.join(GAME, "assets", "tex", "scan", "*", "*.import")):
	p = {"compress/mode": "2", "mipmaps/generate": "true"}
	if "normal" in os.path.basename(f): p["compress/normal_map"] = "1"
	n += patch(f, p)
print("patched", n, "import files")
