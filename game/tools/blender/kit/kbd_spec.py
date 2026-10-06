# Real dimensions of keyboard parts (docs/keyboard_spec.md) as data for the Blender keyboard kit.
# Everything in millimetres here; the exporters convert to key units (U = 19.05 mm), the frame Keyboard3D uses:
# Y up, Z towards the typist, origin of a key = centre of its 1u cell on the plate top.
import json, os

U = 19.05                                   # key pitch, mm
GAME = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))

def ku(mm): return mm / U                   # mm -> key units

# ---- keycaps ---------------------------------------------------------------------------------------------------------
CAP_BOTTOM = 18.1                           # 1u skirt (square); wider caps: w*U - 0.95
CAP_WALL = 1.4
STEM_POST_D = 5.5
STEM_SLOT = (4.1, 1.3)                      # cross slot arm length, arm width
WIDTHS = [1.0, 1.25, 1.5, 1.75, 2.0, 2.25, 2.75, 6.25]

# height (mm, tallest point) per sculpt row R1..R4, row tilt (deg, + = top faces the typist), top surface of 1u (w, d),
# dish kind ("cyl" along X / "sph"), dish depth, corner radii (bottom, top), how far the top is shifted back (mm)
PROFILES = {
	"cherry": {"h": [9.4, 7.9, 6.6, 6.3],   "tilt": [8, 4, 0, -6],  "top": (12.7, 14.2), "dish": "cyl", "depth": 0.55, "rb": 1.0, "rt": 1.4, "back": 0.6},
	"oem":    {"h": [11.9, 10.6, 9.5, 9.3], "tilt": [10, 5, 0, -7], "top": (12.5, 14.0), "dish": "cyl", "depth": 0.5,  "rb": 1.0, "rt": 1.3, "back": 0.6},
	"sa":     {"h": [16.5, 14.9, 13.5, 13.5],"tilt": [13, 7, 0, -8], "top": (12.9, 12.9), "dish": "sph", "depth": 1.1,  "rb": 1.6, "rt": 3.2, "back": 0.0},
	"mt3":    {"h": [14.6, 13.6, 13.0, 13.6],"tilt": [12, 6, 0, -7], "top": (13.2, 13.0), "dish": "sph", "depth": 1.5,  "rb": 1.5, "rt": 2.9, "back": 0.0},
	"kat":    {"h": [13.5, 12.0, 11.0, 11.6],"tilt": [10, 5, 0, -6], "top": (13.6, 13.6), "dish": "sph", "depth": 0.85, "rb": 1.4, "rt": 2.4, "back": 0.0},
	"xda":    {"h": [9.1, 9.1, 9.1, 9.1],   "tilt": [0, 0, 0, 0],   "top": (15.4, 15.4), "dish": "sph", "depth": 0.6,  "rb": 1.6, "rt": 2.6, "back": 0.0},
}

# ---- switch (MX) ---------------------------------------------------------------------------------------------------------
PLATE_T = 1.5
PLATE_TO_PCB = 5.0
PCB_T = 1.6
CUTOUT = 14.0                               # switch plate cut-out, corner r <= 0.3
SWITCH = {
	"top_base": 15.6, "top_top": (11.4, 11.8), "top_h": 6.3,            # top housing above the plate
	"bottom": 14.0, "bottom_h": 5.0,                                    # bottom housing below the plate top
	"stem_top": 11.6, "stem_cross": (4.0, 1.17), "stem_cross_h": 3.6,   # above the plate at rest
	"travel": 4.0, "pretravel": 2.0,
	"pin_d": 1.5, "pin_len": 3.3, "post_d": 4.0,
}

# ---- stabilizers -----------------------------------------------------------------------------------------------------------
STAB_SPACING = {2.0: 23.8, 2.25: 23.8, 2.75: 23.8, 6.25: 100.0, 7.0: 114.3}   # between stems, mm
STAB_CUTOUT = (6.75, 12.3)                  # plate cut-out per stab housing (w, d)
STAB_WIRE_D = 1.6

# ---- layouts (key positions from the game's catalog) -----------------------------------------------------------------------
def layouts():
	c = json.load(open(os.path.join(GAME, "data", "catalog.json"), encoding="utf-8"))
	return c["LAYOUTS"]

def cases():
	c = json.load(open(os.path.join(GAME, "data", "catalog.json"), encoding="utf-8"))
	return {cs["id"]: cs for cs in c["CASES"]}
