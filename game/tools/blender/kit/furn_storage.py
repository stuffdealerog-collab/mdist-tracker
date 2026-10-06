# Storage furniture of the flat (photo1-3): the three-door cream wardrobe = the parts warehouse (real interior with
# shelves and an LED strip, three doors on hinges), the tall bookshelf with books, the four-drawer chest = packing
# station (drawers slide), the small cream cabinet by the door under the 3D printer.
import random
from core import *

CREAM = "wood_cream"

def _crown_run(fr, x0, x1, y, z, depth_back):
	"""Cornice around the top: front run + both returns (profile u = outwards, v = up)."""
	from arch import crown_profile
	prof = [(u, v + 0.07) for (u, v) in crown_profile(0.07, 0.05)]
	path = [fr.p(x1, y, -depth_back), fr.p(x1, y, z), fr.p(x0, y, z), fr.p(x0, y, -depth_back)]
	return sweep(prof, path, CREAM, name="cornice", grain="x")

# ---- wardrobe -------------------------------------------------------------------------------------------------------
def wardrobe():
	x0g, x1g, z0g, z1g, H = WARD["x0"], WARD["x1"], WARD["z0"], WARD["z1"], WARD["h"]
	W = z1g - z0g; D = x1g - x0g
	fr = Frame(((x0g + x1g) / 2, F, (z0g + z1g) / 2), "-x")
	t = 0.018; hw = W / 2; hd = D / 2; plinth = 0.08
	# carcass
	fr.span(-hw, -hw + t, plinth - 0.02, H, -hd, hd, CREAM, 0.0015, grain="y")
	fr.span(hw - t, hw, plinth - 0.02, H, -hd, hd, CREAM, 0.0015, grain="y")
	fr.span(-hw + t, hw - t, H - t, H, -hd, hd - 0.002, CREAM, 0.0015, grain="x")
	fr.span(-hw + t, hw - t, plinth, plinth + t, -hd + 0.006, hd - 0.002, CREAM, 0.0015, grain="x")
	fr.span(-hw + t, hw - t, plinth, H - t, -hd, -hd + 0.006, "wood_cream_b", 0.0, grain="y")        # back panel
	fr.span(-hw + 0.03, hw - 0.03, 0.0, plinth, hd - 0.05, hd - 0.03, CREAM, 0.0015, grain="x")      # recessed plinth
	# cornice: cap board + crown moulding on front and sides
	fr.span(-hw - 0.03, hw + 0.03, H + 0.07, H + 0.095, -hd, hd + 0.03, CREAM, 0.003, grain="x")
	_crown_run(fr, -hw, hw, H, hd + 0.002, hd)
	# interior: shelves on the game's shelf levels (top surface = level), edge banding, a top shelf for blankets
	for yl in [lv - F for lv in SHELF_LEVELS[1:]] + [1.95]:
		fr.span(-hw + t, hw - t, yl - t, yl, -hd + 0.006, hd - 0.03, "wood_cream_b", 0.001, grain="x")
		fr.span(-hw + t, hw - t, yl - t, yl, hd - 0.032, hd - 0.03, "board_edge", 0.0)
	# shelf pins (tiny brass studs under each shelf end)
	for yl in [lv - F for lv in SHELF_LEVELS[1:]] + [1.95]:
		for sx in (-hw + t + 0.004, hw - t - 0.004):
			for sz in (-hd + 0.08, hd - 0.1):
				fr.box((0.008, 0.006, 0.006), (sx, yl - t - 0.003, sz), "gold", 0.0)
	take("ward_body")
	# LED strip under the top (lit when the doors open)
	fr.span(-hw + 0.05, hw - 0.05, H - t - 0.008, H - t, hd - 0.09, hd - 0.075, "glow_white")
	take("ward_led", lightmap=False)
	collider("col_ward", fr.s(W, H + 0.1, D), fr.p(0, (H + 0.1) / 2, 0))
	# doors: overlay leaves with two shallow grooves, long bar handles at the meeting edges
	gap = 0.003; dw = (W - 4 * gap) / 3; dh = H - plinth - 0.025; dy0 = plinth + 0.012; zt = hd + 0.0095
	for i, side in enumerate(["L", "R", "R"]):
		lx0 = -hw + gap + i * (dw + gap); lx1 = lx0 + dw
		fr.span(lx0, lx1, dy0, dy0 + dh, zt - 0.009, zt + 0.009, CREAM, 0.0025, grain="y")
		for gx in ((lx0 + 0.06, lx0 + 0.066), (lx1 - 0.066, lx1 - 0.06)):
			fr.span(gx[0], gx[1], dy0 + 0.06, dy0 + dh - 0.06, zt + 0.0085, zt + 0.0092, "board_edge")
		hx = lx1 - 0.045 if side == "L" else lx0 + 0.045
		if i == 2: hx = lx0 + 0.045
		for yy in (0.83, 1.33):                                            # standoffs
			fr.cyl(0.006, 0.026, (hx, yy, zt + 0.022), "steel_brushed", axis="z", verts=12)
		fr.cyl(0.0075, 0.56, (hx, 1.08, zt + 0.035), "steel_brushed", axis="y", verts=16)
		hinge_x = lx0 if side == "L" else lx1
		take("ward_door_%d_%s" % (i, side), pivot=fr.p(hinge_x, dy0, zt))

# ---- bookshelf ----------------------------------------------------------------------------------------------------
BOOKS = ["book_red", "book_navy", "book_green", "book_cream", "book_black", "book_orange", "book_teal", "book_grey"]

def bookshelf():
	fr = Frame((X1 - 0.17, F, 0.84), "-x")
	W, D, H, t = 0.6, 0.32, 1.96, 0.018
	hw, hd = W / 2, D / 2
	fr.span(-hw, -hw + t, 0, H, -hd, hd, "wood_maple", 0.0015, grain="y")
	fr.span(hw - t, hw, 0, H, -hd, hd, "wood_maple", 0.0015, grain="y")
	fr.span(-hw + t, hw - t, 0.0, 0.07, hd - 0.03, hd - 0.012, "wood_maple", 0.0015, grain="x")      # plinth
	fr.span(-hw + t, hw - t, 0.06, H, -hd, -hd + 0.005, "wood_maple", 0.0, grain="y")               # back
	levels = [0.07, 0.4, 0.72, 1.03, 1.33, 1.63, H - t]
	for yl in levels:
		fr.span(-hw + t, hw - t, yl, yl + t, -hd + 0.005, hd - 0.012, "wood_maple", 0.0015, grain="x")
	# crest on top: a shallow arched board with a little carved rosette
	import bmesh
	n = 24
	for k in range(n):
		a0 = k / n; a1 = (k + 1) / n
		x_a = -hw + W * a0; x_b = -hw + W * a1
		h_a = 0.03 + 0.07 * math.sin(math.pi * a0); h_b = 0.03 + 0.07 * math.sin(math.pi * a1)
		hh = (h_a + h_b) / 2
		fr.span(x_a, x_b, H, H + hh, hd - 0.03, hd - 0.012, "wood_maple", 0.0, grain="x")
	fr.span(-hw - 0.012, hw + 0.012, H - 0.005, H + 0.012, -hd, hd + 0.01, "wood_maple", 0.003, grain="x")
	take("bookshelf")
	collider("col_bookshelf", fr.s(W, H, D), fr.p(0, H / 2, 0))
	# books: spines out, mixed heights, a lean at the end of each row; top shelves: boxes and a pair of white masks
	rng = random.Random(7)
	for li, yl in enumerate(levels[:-1]):
		y = yl + t
		gap_h = levels[li + 1] - y
		if li >= 5: continue
		x = -hw + t + 0.005
		row_end = hw - t - (0.06 if li % 2 == 0 else 0.12)
		while x < row_end:
			bw = rng.uniform(0.018, 0.045); bh = min(gap_h - 0.02, rng.uniform(0.17, 0.27)); bd = rng.uniform(0.15, 0.21)
			if x + bw > row_end: break
			m = rng.choice(BOOKS)
			fr.span(x, x + bw, y, y + bh, hd - 0.02 - bd, hd - 0.02, m, 0.0012)
			fr.span(x + 0.002, x + bw - 0.002, y + bh - 0.0015, y + bh + 0.0005, hd - 0.018 - bd, hd - 0.024, "paper", 0.0)
			if rng.random() < 0.25:                                     # spine band
				fr.span(x - 0.0003, x + bw + 0.0003, y + bh * 0.78, y + bh * 0.82, hd - 0.021 - bd * 0.02, hd - 0.0195, "gold", 0.0)
			x += bw + rng.uniform(0.0, 0.003)
		# a few books lying flat in the gap
		if li % 2 == 1:
			yy = y
			for k in range(rng.randint(2, 4)):
				bh2 = rng.uniform(0.02, 0.035)
				fr.span(row_end + 0.01, hw - t - 0.01, yy, yy + bh2, hd - 0.22, hd - 0.03, rng.choice(BOOKS), 0.0012)
				yy += bh2
	# top shelves: two white masks (like the real ones), a box, a figure
	yt = levels[5] + t
	for s in (-1, 1):
		lathe([(0, 0), (0.045, 0.0), (0.05, 0.02), (0.045, 0.04), (0.0, 0.05)], (0, 0, 0), "white_plastic", 24, name="mask")
		mo = bpy.context.scene.objects["mask"]; mo.name = "mask_d"
		mo.rotation_euler = (math.pi / 2, 0, 0); mo.scale = (1.3, 1, 0.7); mo.location = g(*fr.p(s * 0.08, yt + 0.08, 0.02))
	fr.span(-hw + 0.03, -hw + 0.2, levels[4] + t, levels[4] + t + 0.12, -0.05, 0.1, "black_plastic", 0.004)
	take("bookshelf_books", lightmap=False)

# ---- chest of drawers (packing station) ---------------------------------------------------------------------------
def chest():
	fr = Frame((0.85, F, Z1 - 0.3), "-z")
	W, D, H, t = 1.0, 0.5, 0.825, 0.018
	hw, hd = W / 2, D / 2
	fr.span(-hw, -hw + t, 0.0, H, -hd, hd, CREAM, 0.0015, grain="y")
	fr.span(hw - t, hw, 0.0, H, -hd, hd, CREAM, 0.0015, grain="y")
	fr.span(-hw + t, hw - t, 0.0, 0.06, hd - 0.04, hd - 0.022, CREAM, 0.0015, grain="x")              # plinth
	fr.span(-hw + t, hw - t, 0.06, 0.06 + t, -hd, hd - 0.02, CREAM, 0.0015, grain="x")
	fr.span(-hw + t, hw - t, 0.06, H, -hd, -hd + 0.005, "wood_cream_b", 0.0, grain="x")
	# top: 30 mm board, 15 mm overhang, rounded front edge
	fr.span(-hw - 0.015, hw + 0.015, H, H + 0.03, -hd - 0.005, hd + 0.015, "wood_cream_b", 0.008, segs=4, grain="x")
	take("chest_body")
	collider("col_chest", fr.s(W + 0.03, H + 0.03, D + 0.02), fr.p(0, (H + 0.03) / 2, 0))
	# four drawers: front with a raised field, wide bar handle; box behind (seen when pulled out)
	n = 4; y0 = 0.08; fh = (H - y0 - 0.01 - (n - 1) * 0.004) / n
	for k in range(n):
		yb = y0 + k * (fh + 0.004)
		fz = hd - 0.0                                                     # front face plane
		fr.span(-hw + 0.004, hw - 0.004, yb, yb + fh, fz - 0.02, fz, CREAM, 0.0025, grain="x")
		fr.span(-hw + 0.045, hw - 0.045, yb + 0.03, yb + fh - 0.03, fz, fz + 0.004, CREAM, 0.004, grain="x")
		fr.cyl(0.006, 0.018, (-0.16, yb + fh / 2, fz + 0.013), "steel_brushed", axis="z", verts=12)
		fr.cyl(0.006, 0.018, (0.16, yb + fh / 2, fz + 0.013), "steel_brushed", axis="z", verts=12)
		fr.box((0.36, 0.012, 0.012), (0, yb + fh / 2, fz + 0.026), "steel_brushed", 0.004)
		# drawer box
		bx = hw - t - 0.012
		fr.span(-bx, -bx + 0.012, yb + 0.015, yb + fh - 0.03, -hd + 0.03, fz - 0.02, "plywood", 0.001, grain="z")
		fr.span(bx - 0.012, bx, yb + 0.015, yb + fh - 0.03, -hd + 0.03, fz - 0.02, "plywood", 0.001, grain="z")
		fr.span(-bx, bx, yb + 0.015, yb + fh - 0.03, -hd + 0.03, -hd + 0.042, "plywood", 0.001, grain="x")
		fr.span(-bx, bx, yb + 0.012, yb + 0.018, -hd + 0.03, fz - 0.02, "plywood", 0.0, grain="x")
		take("chest_drawer_%d" % k, pivot=fr.p(0, yb, fz))

# ---- small cabinet by the door (3D printer stand) ----------------------------------------------------------------------
def cabinet():
	fr = Frame((1.3, F, Z0 + 0.23), "+z")
	W, D, H = 0.46, 0.44, 0.62
	fr.span(-W / 2, W / 2, 0.04, H, -D / 2, D / 2 - 0.02, CREAM, 0.002, grain="y")
	fr.span(-W / 2 + 0.03, W / 2 - 0.03, 0, 0.04, -D / 2 + 0.03, D / 2 - 0.06, CREAM, 0.0015)
	fr.span(-W / 2 - 0.01, W / 2 + 0.01, H, H + 0.025, -D / 2 - 0.005, D / 2 + 0.005, "wood_cream_b", 0.006, grain="x")
	fr.span(-W / 2 + 0.003, W / 2 - 0.003, 0.045, H - 0.004, D / 2 - 0.02, D / 2, CREAM, 0.0025, grain="y")       # door
	fr.span(-W / 2 + 0.04, W / 2 - 0.04, 0.08, H - 0.04, D / 2, D / 2 + 0.004, CREAM, 0.004, grain="y")
	fr.box((0.012, 0.12, 0.012), (W / 2 - 0.05, H - 0.12, D / 2 + 0.018), "steel_brushed", 0.004)
	take("cabinet_door")
	collider("col_cabinet", fr.s(W, H + 0.03, D), fr.p(0, (H + 0.03) / 2, 0))

def build():
	wardrobe(); bookshelf(); chest(); cabinet()
