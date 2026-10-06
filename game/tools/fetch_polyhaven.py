"""CC0 photo-scanned PBR textures from Poly Haven -> game/assets/tex/scan/<id>/{albedo,normal,rough,ao}.jpg
Usage: python tools/fetch_polyhaven.py [res=2k]   (list below = the material library of the flat)
All Poly Haven assets are CC0 (public domain); the ids are recorded in assets/tex/scan/CREDITS.txt."""
import json, os, sys, subprocess

RES = sys.argv[1] if len(sys.argv) > 1 else "2k"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "tex", "scan")
IDS = {
	"laminate_floor_02": "floor laminate (tinted grey-beige)",
	"washed_grey_oak_veneer": "cream furniture: wardrobe, bed, chest, door",
	"grey_oak_veneer_02": "cream furniture variation",
	"white_maple_veneer": "bookshelf, light boards",
	"walnut_veneer": "dark desk / bench",
	"cotton_jersey": "curtains, clothes",
	"rough_linen": "pillows, sheets",
	"fabric_pattern_05": "bed plaid (recoloured blue)",
	"fabric_leather_01": "chair leather (darkened)",
	"leather_red_02": "chair red inserts",
	"white_plaster_02": "ceiling plaster",
	"painted_plaster_wall": "landing walls",
	"plywood": "shelves, boxes inner",
	"wool_boucle": "valet stand sweater",
}
MAPS = {"albedo": ["Diffuse", "diff", "col_01", "coll1"], "normal": ["nor_gl"], "rough": ["Rough", "rough"], "ao": ["AO", "ao"]}

def get(url, path):
	subprocess.run(["curl", "-sS", "-L", "-m", "120", "-o", path, url], check=True)

credits = []
for pid, use in IDS.items():
	d = os.path.join(OUT, pid); os.makedirs(d, exist_ok=True)
	info = json.loads(subprocess.run(["curl", "-sS", "-m", "60", "https://api.polyhaven.com/files/" + pid], capture_output=True, text=True).stdout)
	got = []
	for key, names in MAPS.items():
		node = next((info[n] for n in names if n in info), None)
		if not node or RES not in node: continue
		fmt = node[RES].get("jpg") or node[RES].get("png")
		ext = "jpg" if "jpg" in node[RES] else "png"
		dst = os.path.join(d, "%s.%s" % (key, ext))
		if not os.path.exists(dst): get(fmt["url"], dst)
		got.append(key)
	print(pid, got, flush=True)
	credits.append("%s  (%s)  https://polyhaven.com/a/%s  CC0" % (pid, use, pid))
open(os.path.join(OUT, "CREDITS.txt"), "w", encoding="utf-8").write("Poly Haven, CC0 1.0 (public domain)\n" + "\n".join(credits) + "\n")
