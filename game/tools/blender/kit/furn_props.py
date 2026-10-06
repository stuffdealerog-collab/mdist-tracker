# Packing station props and the valet stand (photo1/2): tape gun, thermal label printer, a bubble-wrap roll, flat
# brand mailers leaning by the chest; the wooden valet stand with a white shirt on the hanger and a black hoodie
# over the bar (cloth simulation); ceramic pots for the plants (foliage: Hybrid3D).
import random
from core import *
from core import _new
from furn_living import softbox, drape

TOP = F + 0.855                     # chest top = Home.PACK_SPOT.y

def tape_gun():
	fr = Frame((0.43, TOP, 2.68), "-z")
	fr.box((0.03, 0.11, 0.022), (-0.03, 0.055, 0), "red_plastic", 0.008)                      # pistol grip
	fr.box((0.16, 0.022, 0.03), (0.02, 0.1, 0), "red_plastic", 0.006)
	fr.cyl(0.05, 0.05, (0.0, 0.095, 0), "tape_roll", axis="z", verts=40)
	fr.cyl(0.038, 0.052, (0.0, 0.095, 0), "cardboard_box", axis="z", verts=32)
	fr.box((0.012, 0.03, 0.055), (0.095, 0.075, 0), "steel_brushed", 0.002)                   # serrated blade guard
	take("tape_gun", lightmap=False)

def label_printer():
	fr = Frame((0.86, TOP, 2.63), "-z")
	softbox(fr.s(0.12, 0.085, 0.15), fr.p(0, 0.043, 0), "white_plastic", 0.012, name="lp")
	fr.box((0.08, 0.004, 0.006), (0, 0.06, 0.074), "black_plastic", 0.0)                      # label slot
	fr.box((0.07, 0.002, 0.03), (0, 0.062, 0.09), "sticker_label", 0.0)                       # a label sticking out
	fr.cyl(0.006, 0.004, (0.04, 0.086, -0.04), "glow_white", verts=12)
	take("label_printer", lightmap=False)

def bubble_roll():
	cyl(0.12, 0.6, (0.18, F + 0.3, 2.6), "bubble_wrap", verts=48, bevel=0.006)
	cyl(0.04, 0.602, (0.18, F + 0.3, 2.6), "cardboard_box", verts=24, bevel=0.0)
	box((0.004, 0.55, 0.2), (0.18 + 0.12, F + 0.3, 2.6 - 0.1), "bubble_wrap", 0.0)            # loose tail
	take("bubble_roll", lightmap=False)

def flat_boxes():
	for i in range(4):
		box((0.006, 0.36, 0.5), (1.42 + i * 0.009, F + 0.18, 2.5), "brand_box", 0.0015, rot=(0, 0, -5 - i))
	take("flat_boxes")

def pots():
	# peace lily on the window sill (white ceramic, slightly tapered), lucky bamboo on the chest (glass-like)
	sx, sy, sz = X0 - NICHE["d"] / 2 + 0.03, WIN["y0"], 0.97
	lathe([(0.0, 0.0), (0.06, 0.0), (0.072, 0.01), (0.085, 0.13), (0.088, 0.135), (0.08, 0.135), (0.078, 0.12), (0.0, 0.12)], (sx, sy, sz), "ceramic_white", 48, name="pot1")
	lathe([(0.0, 0.0), (0.042, 0.0), (0.05, 0.012), (0.05, 0.11), (0.046, 0.112), (0.0, 0.1)], (1.27, TOP, 2.33), "ceramic_white", 40, name="pot2")
	for (x, y, z, r) in [(sx, sy + 0.12, sz, 0.078), (1.27, TOP + 0.098, 2.33, 0.045)]:
		cyl(r, 0.006, (x, y, z), "soil", verts=32, bevel=0.0)
	take("plant_pots", lightmap=False)

def valet_stand():
	"""Wooden valet: two feet, a post, a shaped hanger, a trouser bar; clothes draped by cloth simulation."""
	fr = Frame((X1 - 0.26, F, 0.28), "-x")
	wood = "wood_maple"
	parts = []
	for sx in (-1, 1):
		parts.append(fr.box((0.05, 0.03, 0.38), (sx * 0.12, 0.015, 0), wood, 0.006))
	parts.append(fr.box((0.3, 0.04, 0.04), (0, 0.04, 0), wood, 0.006))
	parts.append(fr.box((0.035, 1.05, 0.035), (0, 0.55, -0.02), wood, 0.006, grain="y"))
	hanger = []
	for k in range(9):                                                     # shoulder hanger: curved bar
		t = (k - 4) / 4.0
		hanger.append(fr.box((0.06, 0.026, 0.05), (t * 0.21, 1.1 - 0.06 * t * t, -0.02), wood, 0.008))
	bar = fr.cyl(0.012, 0.36, (0, 0.62, 0.0), "steel_brushed", axis="x", verts=16)
	parts += hanger + [bar]
	# white shirt on the hanger, black hoodie over the bar
	drape("shirt", 0.55, 0.7, fr.p(0, 1.16, -0.02), hanger, "fabric_white", frames=40, res=40, thickness=0.004, stiff=8.0)
	drape("hoodie", 0.42, 0.55, fr.p(0, 0.68, 0.0), [bar], "fabric_black", frames=40, res=36, thickness=0.006, stiff=6.0)
	take("valet_stand", smooth_angle=60.0)
	collider("col_valet", (0.4, 1.2, 0.45), (X1 - 0.26, F + 0.6, 0.28))

def build():
	tape_gun(); label_printer(); bubble_roll(); flat_boxes(); pots(); valet_stand()
