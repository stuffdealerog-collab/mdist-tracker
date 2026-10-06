"""Calibrates scanned albedos to the colours of the real room (art/room/photo*.jpg) -> assets/tex/room/<slot>_albedo.jpg.
Each slot: source scan, target mean colour (sRGB, measured from the photos and corrected for their exposure), and how
much of the scan's own colour variation to keep. Normal/roughness/AO stay the scan's own maps.
  python tools/calibrate_scans.py"""
import os
import numpy as np
from PIL import Image

GAME = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
SCAN = os.path.join(GAME, "assets", "tex", "scan"); OUT = os.path.join(GAME, "assets", "tex", "room")
SLOTS = {
	# slot: (scan, target mean sRGB, keep chroma 0..1, contrast)
	"floor_laminate": ("laminate_floor_02", (158, 152, 143), 0.25, 1.15),
	"wood_cream":     ("washed_grey_oak_veneer", (214, 203, 182), 0.6, 1.0),
	"wood_cream_b":   ("grey_oak_veneer_02", (205, 195, 176), 0.5, 1.0),
	"wood_maple":     ("white_maple_veneer", (226, 216, 196), 0.8, 1.0),
	"wood_dark":      ("walnut_veneer", (52, 34, 26), 0.8, 1.25),
	"wood_window":    ("walnut_veneer", (92, 58, 38), 0.9, 1.1),
	"door_neighbour": ("walnut_veneer", (88, 56, 38), 0.9, 1.1),
	"fabric_curtain": ("cotton_jersey", (146, 128, 108), 0.25, 1.1),
	"fabric_plaid":   ("fabric_pattern_05", (178, 192, 210), 0.0, 1.05),
	"fabric_linen":   ("rough_linen", (222, 222, 218), 0.0, 1.0),
	"leather_black":  ("fabric_leather_01", (28, 26, 26), 0.2, 1.1),
	"leather_red":    ("leather_red_02", (140, 22, 24), 1.0, 1.0),
	"plaster_white":  ("white_plaster_02", (232, 230, 225), 0.1, 0.35),
	"plaster_hall":   ("painted_plaster_wall", (170, 182, 172), 0.6, 1.0),
	"plywood":        ("plywood", (196, 168, 128), 0.9, 1.0),
	"wool_grey":      ("wool_boucle", (120, 118, 116), 0.3, 1.0),
}
TINT_PLAID = (0.55, 0.68, 0.86)          # the plaid's lines become blue like the real bedding

def to_lin(c): return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
def to_srgb(c): return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(np.clip(c, 0, None), 1 / 2.4) - 0.055)

os.makedirs(OUT, exist_ok=True)
for slot, (scan, target, chroma, contrast) in SLOTS.items():
	src = os.path.join(SCAN, scan, "albedo.jpg")
	if not os.path.exists(src): print("missing", src); continue
	x = to_lin(np.asarray(Image.open(src).convert("RGB")).astype(np.float32) / 255.0)
	lum = (x @ np.array([0.2126, 0.7152, 0.0722], np.float32))[..., None]
	mean_l = float(lum.mean())
	rel = (lum / max(mean_l, 1e-4)) ** contrast                         # luminance pattern around 1
	col = x / np.maximum(lum, 1e-4)                                      # chroma
	col = col * chroma + (1 - chroma)
	if slot == "fabric_plaid":                                           # lighter lines -> blue-white, field -> pale blue
		col = np.ones_like(col) * np.array(TINT_PLAID, np.float32) + (rel - 1) * 0.15
	t = to_lin(np.array(target, np.float32) / 255.0)
	tl = float(t @ np.array([0.2126, 0.7152, 0.0722], np.float32))
	tc = t / max(tl, 1e-4)
	col = col / np.maximum(col.mean(axis=(0, 1), keepdims=True), 1e-4)        # keep the scan's chroma VARIATION only
	y = rel * tl * col * tc
	y = np.clip(y, to_lin(np.float32(24 / 255)), to_lin(np.float32(240 / 255)))
	Image.fromarray((to_srgb(y) * 255).astype(np.uint8)).save(os.path.join(OUT, slot + "_albedo.jpg"), quality=93)
	print("%-16s <- %-24s mean %s" % (slot, scan, [round(v) for v in (to_srgb(y.mean(axis=(0, 1))) * 255)]))
