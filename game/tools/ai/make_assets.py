"""Asset pipeline for the flat: prompt -> FLUX Kontext product photo -> TRELLIS.2 textured mesh -> Blender fit -> game .glb.
Every stage is cached in game/art/<name>/; delete a file there to redo that stage.

  python make_assets.py [stage=all|concept|model|fit] [names...]
"""
import json, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.abspath(os.path.join(HERE, "..", ".."))
ART = os.path.join(GAME, "art")
OUT = os.path.join(GAME, "assets", "models")
PY = sys.executable
BLENDER = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Programs", "Blender", "blender.exe")
SPEC = os.environ.get("ASSETS", "assets.json")   # room_assets.json: objects cut out of the room photos
spec = json.load(open(os.path.join(HERE, SPEC), encoding="utf-8"))
PY_IMG = r"E:\AI\ComfyUI_windows_portable\python_embeded\python.exe"   # has Pillow
PHOTOS = os.path.join(ART, "room")

def crop_photo(s, dst):
	"""Cuts the object out of a room photo (normalised box), pads it to a square on neutral grey."""
	src = os.path.join(PHOTOS, "photo%d.jpg" % s["photo"])
	code = ("import sys;from PIL import Image;im=Image.open(sys.argv[1]).convert('RGB');W,H=im.size;b=[float(x) for x in sys.argv[3].split(',')];"
		"c=im.crop((int(b[0]*W),int(b[1]*H),int(b[2]*W),int(b[3]*H)));m=max(c.size);o=Image.new('RGB',(m,m),(222,222,224));"
		"o.paste(c,((m-c.size[0])//2,(m-c.size[1])//2));o=o.resize((1024,1024));o.save(sys.argv[2])")
	subprocess.run([PY_IMG, "-c", code, src, dst, ",".join(str(x) for x in s["crop"])])
style = spec.pop("_style")

stage = sys.argv[1] if len(sys.argv) > 1 else "all"
names = sys.argv[2:] or list(spec.keys())

def run(cmd):
	r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
	tail = [l for l in (r.stdout + r.stderr).splitlines() if l.startswith(("CONCEPT", "MODEL", "FIT", "PREVIEW", "NO GLB", "Traceback", "RuntimeError", "Error"))]
	print("   ", "\n    ".join(tail[-6:]) or (r.stdout + r.stderr)[-800:], flush=True)
	return r.returncode == 0

for n in names:
	s = spec[n]; d = os.path.join(ART, n); os.makedirs(d, exist_ok=True)
	concept = os.path.join(d, "concept.png"); raw = os.path.join(d, "raw.glb")
	print("==", n, flush=True)
	if stage in ("all", "concept") and not os.path.exists(concept):
		args = [PY, os.path.join(HERE, "concept.py"), concept, style.format(what=s["what"]), str(s.get("seed", 7))]
		if "photo" in s:
			src = os.path.join(d, "photo_crop.png"); crop_photo(s, src); args.append(src)
		run(args)
	if stage in ("all", "model") and os.path.exists(concept) and not os.path.exists(raw):
		run([PY, os.path.join(HERE, "trellis.py"), concept, raw, str(s.get("seed", 42)), str(s.get("faces", 150000)), str(s.get("tex", 2048))])
	if stage in ("all", "fit") and os.path.exists(raw):
		os.makedirs(OUT, exist_ok=True)
		run([BLENDER, "-b", "-P", os.path.join(GAME, "tools", "blender", "fit_asset.py"), "--", raw, os.path.join(OUT, n + ".glb"),
			str(s["size"]), s.get("axis", "h"), str(s.get("rot", 0)), "0", os.path.join(d, "preview.png")])
