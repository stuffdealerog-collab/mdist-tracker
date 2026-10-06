# Architecture of the flat (from art/room/photo1-6): walls with real thickness, the window recess down to the floor
# with a radiator, a three-tier tray ceiling with profiled crown mouldings, skirting, the ornate door with casing
# and pediment, the stairwell landing. Wallpaper: damask on the desk/door wall (Z0), plain mottled elsewhere.
import math
from core import *
from core import _new

# ---- profiles (u = out from the wall into the room, v = up; metres) ----------------------------------------------
def crown_profile(drop=0.13, proj=0.11):
	"""Classical crown (cyma recta + fillets) touching the wall at v=-drop and the ceiling at u=proj."""
	pts = [(0.0, -drop), (0.012, -drop), (0.014, -drop + 0.012), (0.02, -drop + 0.016)]
	for i in range(1, 13):                                   # S-curve (ogee) from the lower fillet to the upper one
		t = i / 12.0
		u = 0.02 + (proj - 0.035) * (t - math.sin(2 * math.pi * t) / (2 * math.pi) * 0.9)
		v = -drop + 0.016 + (drop - 0.03) * t
		pts.append((u, v))
	pts += [(proj - 0.012, -0.012), (proj - 0.004, -0.008), (proj, -0.004), (proj, 0.0)]
	return pts

def step_bead(w=0.035, h=0.03):
	"""Small moulding on a ceiling step edge (hangs below the soffit edge)."""
	pts = [(0.0, 0.0), (0.0, -h * 0.35)]
	for i in range(9):
		a = math.pi * i / 8
		pts.append((w * 0.5 - math.cos(a) * w * 0.5, -h * 0.35 - math.sin(a) * h * 0.65))
	pts += [(w, 0.0)]
	return pts

def skirting_profile(h=0.09, t=0.016):
	pts = [(0.0, 0.0), (t, 0.0), (t, h - 0.03)]
	for i in range(1, 7):
		a = (math.pi / 2) * i / 6
		pts.append((t - 0.006 * (1 - math.cos(a)) - 0.004 * math.sin(a), h - 0.03 + 0.024 * math.sin(a)))
	pts += [(0.004, h), (0.0, h)]
	return pts

def casing_profile(w=0.085, t=0.022):
	"""Door casing: flat face with a raised outer bead and an inner step (u = across the casing, v = thickness)."""
	return [(0, 0), (0, t * 0.6), (0.008, t * 0.75), (0.014, t), (0.026, t), (0.03, t * 0.8), (w - 0.02, t * 0.7),
		(w - 0.012, t * 0.95), (w - 0.004, t * 0.9), (w, t * 0.5), (w, 0)]

def rect(xa, za, xb, zb, y):
	"""Closed path around a rectangle with the profile's u pointing INTO the rectangle."""
	return [(xb, y, za), (xa, y, za), (xa, y, zb), (xb, y, zb)]

# ---- walls ----------------------------------------------------------------------------------------------------------
def walls():
	dx0, dx1 = DOOR_X - DOOR_W / 2, DOOR_X + DOOR_W / 2
	nz0, nz1, nd = NICHE["z0"], NICHE["z1"], NICHE["d"]
	top = CEIL + 0.02
	# Z0: desk + door wall (damask), with the door opening
	span(X0 - nd - T, dx0, F, top, Z0 - T, Z0, "wall_damask", name="w_z0a")
	span(dx1, X1 + T, F, top, Z0 - T, Z0, "wall_damask", name="w_z0b")
	span(dx0, dx1, F + DOOR_H + 0.02, top, Z0 - T, Z0, "wall_damask", name="w_z0c")
	# Z1: bed wall, X1: wardrobe wall (plain)
	span(X0 - nd - T, X1 + T, F, top, Z1, Z1 + T, "wall_mottle", name="w_z1")
	span(X1, X1 + T, F, top, Z0, Z1, "wall_mottle", name="w_x1")
	# X0: window wall with the recess (floor to the window head)
	head = WIN["y1"] + 0.12
	span(X0 - T, X0, F, top, Z0, nz0, "wall_mottle", name="w_x0a")
	span(X0 - T, X0, F, top, nz1, Z1, "wall_mottle", name="w_x0b")
	span(X0 - nd, X0, head, top, nz0, nz1, "wall_mottle", name="w_x0c")         # lintel above the recess
	# back of the recess, with the window opening (frame plane sits in it)
	bx0, bx1 = X0 - nd - T, X0 - nd
	wz0, wz1, wy0, wy1 = WIN["z0"], WIN["z1"], WIN["y0"], WIN["y1"]
	span(bx0, bx1, F, wy0, nz0 - 0.02, nz1 + 0.02, "wall_mottle", name="w_back_lo")
	span(bx0, bx1, wy1, top, nz0 - 0.02, nz1 + 0.02, "wall_mottle", name="w_back_hi")
	span(bx0, bx1, wy0, wy1, nz0 - 0.02, wz0, "wall_mottle", name="w_back_l")
	span(bx0, bx1, wy0, wy1, wz1, nz1 + 0.02, "wall_mottle", name="w_back_r")
	span(X0 - nd, X0, F, head, nz0 - T, nz0, "wall_mottle", name="w_rev0")     # reveals
	span(X0 - nd, X0, F, head, nz1, nz1 + T, "wall_mottle", name="w_rev1")
	take("arch_walls")
	for n, sz, c in [("col_wz0", (X1 - X0 + 1, 3.4, 0.2), ((X0 + X1) / 2, F + 1.6, Z0 - 0.1)), ("col_wz1", (X1 - X0 + 1, 3.4, 0.2), ((X0 + X1) / 2, F + 1.6, Z1 + 0.1)),
			("col_wx1", (0.2, 3.4, Z1 - Z0 + 1), (X1 + 0.1, F + 1.6, (Z0 + Z1) / 2)), ("col_wx0", (0.2, 3.4, Z1 - Z0 + 1), (X0 - nd - 0.1, F + 1.6, (Z0 + Z1) / 2))]:
		collider(n, sz, c)

def floor():
	nz0, nz1, nd = NICHE["z0"], NICHE["z1"], NICHE["d"]
	span(X0, X1, F - 0.02, F, Z0, Z1, "floor_laminate", grain="x", name="floor")
	span(X0 - nd, X0, F - 0.02, F, nz0, nz1, "floor_laminate", grain="x", name="floor_niche")
	take("arch_floor")
	collider("col_floor", (X1 - X0 + 2, 0.2, Z1 - Z0 + 3), ((X0 + X1) / 2, F - 0.1, (Z0 + Z1) / 2 - 0.8))

def skirting():
	dx0, dx1 = DOOR_X - DOOR_W / 2 - 0.09, DOOR_X + DOOR_W / 2 + 0.09
	nz0, nz1, nd = NICHE["z0"], NICHE["z1"], NICHE["d"]
	prof = skirting_profile()
	# around the room, interrupted by the door casing; the recess gets its own run
	sweep(prof, [(dx0, F, Z0), (X0, F, Z0), (X0, F, nz0)], "trim_white", name="sk_a")
	sweep(prof, [(X0, F, nz1), (X0, F, Z1), (X1, F, Z1), (X1, F, Z0), (dx1, F, Z0)], "trim_white", name="sk_b")
	sweep(prof, [(X0, F, nz0), (X0 - nd, F, nz0), (X0 - nd, F, nz1), (X0, F, nz1)], "trim_white", name="sk_n")
	take("arch_skirting")

# ---- ceiling --------------------------------------------------------------------------------------------------------
def ceiling():
	"""Three tiers like the photos: a low perimeter soffit, a middle step, the recessed field with a silvery damask."""
	h1 = CEIL - 0.3; h2 = CEIL - 0.15; b1 = 0.46; b2 = 0.2
	xa, xb, za, zb = X0, X1, Z0, Z1
	# tier 1 soffit (ring) and its vertical riser
	span(xa, xb, h1, h1 + 0.02, za, za + b1, "plaster_white", name="t1a"); span(xa, xb, h1, h1 + 0.02, zb - b1, zb, "plaster_white", name="t1b")
	span(xa, xa + b1, h1, h1 + 0.02, za + b1, zb - b1, "plaster_white", name="t1c"); span(xb - b1, xb, h1, h1 + 0.02, za + b1, zb - b1, "plaster_white", name="t1d")
	ia, ib, ja, jb = xa + b1, xb - b1, za + b1, zb - b1
	for (p, q, r, s) in [(ia, ib, ja - 0.02, ja), (ia, ib, jb, jb + 0.02), (ia - 0.02, ia, ja, jb), (ib, ib + 0.02, ja, jb)]:
		span(p, q, h1, h2, r, s, "plaster_white", name="r1")
	# tier 2 ring
	span(ia, ib, h2, h2 + 0.02, ja, ja + b2, "plaster_white", name="t2a"); span(ia, ib, h2, h2 + 0.02, jb - b2, jb, "plaster_white", name="t2b")
	span(ia, ia + b2, h2, h2 + 0.02, ja + b2, jb - b2, "plaster_white", name="t2c"); span(ib - b2, ib, h2, h2 + 0.02, ja + b2, jb - b2, "plaster_white", name="t2d")
	ka, kb, la, lb = ia + b2, ib - b2, ja + b2, jb - b2
	for (p, q, r, s) in [(ka, kb, la - 0.02, la), (ka, kb, lb, lb + 0.02), (ka - 0.02, ka, la, lb), (kb, kb + 0.02, la, lb)]:
		span(p, q, h2, CEIL, r, s, "plaster_white", name="r2")
	# mouldings: big crown at the walls, beads at both steps, a small crown in the field
	sweep(crown_profile(0.14, 0.12), rect(xa, za, xb, zb, h1), "trim_white", closed=True, name="crown")
	sweep(step_bead(), [(x, h1, z) for (x, _, z) in rect(ia, ja, ib, jb, 0)], "trim_white", closed=True, name="bead1")
	sweep(step_bead(0.03, 0.025), [(x, h2, z) for (x, _, z) in rect(ka, la, kb, lb, 0)], "trim_white", closed=True, name="bead2")
	sweep(crown_profile(0.07, 0.06), rect(ka, la, kb, lb, CEIL), "trim_white", closed=True, name="crown_field")
	take("arch_ceiling")
	span(ka, kb, CEIL, CEIL + 0.02, la, lb, "ceiling_field", name="field")
	take("arch_ceiling_field")

# ---- window recess --------------------------------------------------------------------------------------------------
def window():
	"""Brown wooden window (fixed + opening sash, transom), a deep sill, the radiator under a slotted cover."""
	nz0, nz1, nd = NICHE["z0"], NICHE["z1"], NICHE["d"]
	x = X0 - nd - 0.045                        # frame plane, set into the opening of the recess back wall
	wz0, wz1, y0, y1, ty = WIN["z0"], WIN["z1"], WIN["y0"], WIN["y1"], WIN["transom"]
	fw, fd = 0.07, 0.07                        # frame width / depth
	wood = "wood_window"
	# outer frame
	span(x - fd / 2, x + fd / 2, y0, y1, wz0, wz0 + fw, wood, 0.004, grain="y")
	span(x - fd / 2, x + fd / 2, y0, y1, wz1 - fw, wz1, wood, 0.004, grain="y")
	span(x - fd / 2, x + fd / 2, y1 - fw, y1, wz0, wz1, wood, 0.004, grain="z")
	span(x - fd / 2, x + fd / 2, y0, y0 + fw, wz0, wz1, wood, 0.004, grain="z")
	span(x - fd / 2, x + fd / 2, ty - 0.03, ty + 0.03, wz0, wz1, wood, 0.004, grain="z")            # transom
	zm = (wz0 + wz1) / 2
	span(x - fd / 2, x + fd / 2, y0, ty, zm - 0.03, zm + 0.03, wood, 0.004, grain="y")              # mullion
	# sashes (slightly proud of the frame) with glazing beads
	for (za_, zb_) in [(wz0 + fw, zm - 0.03), (zm + 0.03, wz1 - fw)]:
		sx = x + fd / 2 + 0.012
		span(sx - 0.03, sx, y0 + fw, ty - 0.03, za_, za_ + 0.055, wood, 0.004, grain="y")
		span(sx - 0.03, sx, y0 + fw, ty - 0.03, zb_ - 0.055, zb_, wood, 0.004, grain="y")
		span(sx - 0.03, sx, ty - 0.085, ty - 0.03, za_, zb_, wood, 0.004, grain="z")
		span(sx - 0.03, sx, y0 + fw, y0 + fw + 0.07, za_, zb_, wood, 0.004, grain="z")
	# handle (white lever) on the right sash
	box((0.03, 0.012, 0.012), (x + fd / 2 + 0.03, (y0 + ty) / 2, zm + 0.08), "white_plastic", 0.003)
	box((0.012, 0.11, 0.016), (x + fd / 2 + 0.045, (y0 + ty) / 2 - 0.045, zm + 0.08), "white_plastic", 0.004)
	# sill board (white, deep) and the radiator cover
	span(x - 0.02, X0 + 0.04, y0 - 0.035, y0, nz0 - 0.02, nz1 + 0.02, "trim_white", 0.004, grain="z")
	cx0, cx1 = X0 - nd + 0.03, X0 - 0.02
	span(cx0, cx1, F + 0.08, y0 - 0.06, nz0 + 0.06, nz1 - 0.06, "trim_white", 0.006, grain="y", name="rad_cover")
	take("arch_window")
	# glass (separate: transparent material, not lightmapped)
	span(x - 0.004, x + 0.004, y0 + fw, y1 - fw, wz0 + fw, wz1 - fw, "glass", name="glass")
	take("arch_window_glass", lightmap=False)
	# slots of the radiator cover: dark gaps
	for i in range(9):
		zz = nz0 + 0.12 + i * (nz1 - nz0 - 0.24) / 8
		span(cx1 - 0.002, cx1 + 0.0005, F + 0.18, y0 - 0.16, zz - 0.012, zz + 0.012, "black_plastic", name="slot")
	take("arch_radiator_slots")

# ---- door -----------------------------------------------------------------------------------------------------------
def door():
	"""Cream panelled door with gold inlay lines and a rosette, lever handle; profiled casing with a carved pediment.
	The leaf is a separate object with its origin at the hinge (left jamb, room side)."""
	dx0, dx1 = DOOR_X - DOOR_W / 2, DOOR_X + DOOR_W / 2
	# jambs (lining of the opening)
	span(dx0 - 0.02, dx0, F, F + DOOR_H, Z0 - T, Z0, "wood_cream", 0.002, grain="y")
	span(dx1, dx1 + 0.02, F, F + DOOR_H, Z0 - T, Z0, "wood_cream", 0.002, grain="y")
	span(dx0 - 0.02, dx1 + 0.02, F + DOOR_H, F + DOOR_H + 0.02, Z0 - T, Z0, "wood_cream", 0.002, grain="x")
	# casing: profile swept up-across-down on the wall face
	cp = casing_profile()
	path = [(dx0 - 0.02, F, Z0), (dx0 - 0.02, F + DOOR_H + 0.02, Z0), (dx1 + 0.02, F + DOOR_H + 0.02, Z0), (dx1 + 0.02, F, Z0)]
	_casing(cp, path)
	# pediment: frieze board, cornice, and a carved crest with scrolls
	py = F + DOOR_H + 0.11
	span(dx0 - 0.1, dx1 + 0.1, py, py + 0.12, Z0, Z0 + 0.03, "wood_cream", 0.004, grain="x")
	sweep(crown_profile(0.07, 0.06), [(dx1 + 0.17, py + 0.19, Z0), (dx0 - 0.17, py + 0.19, Z0)], "wood_cream", name="cornice")
	span(dx0 - 0.17, dx1 + 0.17, py + 0.19, py + 0.21, Z0, Z0 + 0.075, "wood_cream", 0.004, grain="x")
	# carved crest: a central cartouche with acanthus scrolls (lathe medallion + two volutes)
	cx = DOOR_X
	for s in (-1, 1):
		for k in range(14):
			a = k / 13 * 2.6
			r = 0.055 * (1 - k / 18)
			box((0.018, 0.018, 0.016), (cx + s * (0.05 + r * math.cos(a) + k * 0.006), py + 0.27 + r * math.sin(a), Z0 + 0.03), "wood_cream", 0.006)
	box((0.11, 0.1, 0.03), (cx, py + 0.27, Z0 + 0.025), "wood_cream", 0.02)
	box((0.05, 0.05, 0.012), (cx, py + 0.27, Z0 + 0.046), "gold", 0.012)
	take("arch_door_frame")
	collider("col_door_frame_l", (0.12, DOOR_H, T + 0.05), (dx0 - 0.06, F + DOOR_H / 2, Z0 - T / 2))
	collider("col_door_frame_r", (0.12, DOOR_H, T + 0.05), (dx1 + 0.06, F + DOOR_H / 2, Z0 - T / 2))
	# ---- leaf (pivot at the hinge)
	lw = DOOR_W - 0.01; lt = 0.04; lx0 = dx0 + 0.005; lz = Z0 - 0.02
	span(lx0, lx0 + lw, F + 0.008, F + DOOR_H - 0.004, lz - lt / 2, lz + lt / 2, "wood_cream", 0.003, grain="y")
	# raised panels: two tall + one top, with gold inlay frames
	for (py0, py1) in [(F + 0.12, F + 1.0), (F + 1.12, F + 1.98)]:
		px0, px1 = lx0 + 0.11, lx0 + lw - 0.11
		span(px0, px1, py0, py1, lz + lt / 2, lz + lt / 2 + 0.008, "wood_cream", 0.006, grain="y")
		for (a0, a1, b0, b1) in [(px0 + 0.03, px1 - 0.03, py0 + 0.03, py0 + 0.036), (px0 + 0.03, px1 - 0.03, py1 - 0.036, py1 - 0.03),
				(px0 + 0.03, px0 + 0.036, py0 + 0.03, py1 - 0.03), (px1 - 0.036, px1 - 0.03, py0 + 0.03, py1 - 0.03)]:
			span(a0, a1, b0, b1, lz + lt / 2 + 0.008, lz + lt / 2 + 0.0105, "gold")
		# corner fleurons
		for (cx_, cy_) in [(px0 + 0.07, py0 + 0.07), (px1 - 0.07, py0 + 0.07), (px0 + 0.07, py1 - 0.07), (px1 - 0.07, py1 - 0.07)]:
			span(cx_ - 0.012, cx_ + 0.012, cy_ - 0.012, cy_ + 0.012, lz + lt / 2 + 0.008, lz + lt / 2 + 0.011, "gold")
	# rosette in the lower panel (lathe ring) like the photo
	lathe([(0.0, 0.0), (0.075, 0.0), (0.075, 0.004), (0.065, 0.006), (0.05, 0.004), (0.035, 0.008), (0.0, 0.008)],
		(0, 0, 0), "gold", 48, name="ros")
	ros = bpy.context.scene.objects["ros"]
	ros.rotation_euler = (math.pi / 2, 0, 0); ros.location = g(lx0 + lw / 2, F + 0.62, lz + lt / 2 + 0.008)
	bpy.context.view_layer.objects.active = ros
	for s in bpy.context.scene.objects: s.select_set(s == ros)
	bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
	# lever handles both sides + escutcheon plates
	hy = F + 1.02; hx = lx0 + lw - 0.07
	for sgn in (1, -1):
		zf = lz + sgn * (lt / 2 + 0.004)
		box((0.04, 0.16, 0.008), (hx, hy - 0.04, zf), "gold", 0.003)
		cyl(0.009, 0.05, (hx, hy, zf + sgn * 0.025), "gold", axis="z")
		box((0.12, 0.018, 0.018), (hx - 0.06, hy, zf + sgn * 0.05), "gold", 0.007)
	take("door_leaf", pivot=(lx0, F, lz))
	# hinge knuckles on the frame
	for hy2 in (F + 0.25, F + 1.85):
		cyl(0.008, 0.1, (dx0 + 0.004, hy2, Z0 - 0.003), "gold", verts=16)
	take("arch_door_hinges", lightmap=False)

def _casing(cp, path):
	"""The casing profile lies flat on the wall: u runs across the casing (away from the opening), v off the wall."""
	import bmesh
	bm = bmesh.new()
	rings = []
	for i, p in enumerate(path):
		a = Vector(path[max(i - 1, 0)]); b = Vector(path[min(i + 1, len(path) - 1)]); P = Vector(p)
		t_in = (P - a).normalized() if (P - a).length > 1e-9 else (b - P).normalized()
		t_out = (b - P).normalized() if (b - P).length > 1e-9 else t_in
		tan = (t_in + t_out).normalized()
		nrm = Vector((0, 0, 1))                       # off the wall (into the room, +Z for the Z0 wall)
		side = tan.cross(nrm).normalized()            # away from the opening
		if side.dot(Vector((DOOR_X, F + DOOR_H / 2, Z0)) - P) > 0: side = -side
		cosh = max(0.3, t_in.dot(tan))
		rings.append([bm.verts.new(g(*(P + side * (u / cosh) + nrm * v))) for (u, v) in cp])
	for i in range(len(rings) - 1):
		for k in range(len(cp) - 1):
			bm.faces.new([rings[i][k], rings[i][k + 1], rings[i + 1][k + 1], rings[i + 1][k]])
	for r in (rings[0], rings[-1]):
		try: bm.faces.new(r)
		except ValueError: pass
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	me = bpy.data.meshes.new("casing"); bm.to_mesh(me); bm.free()
	o = bpy.data.objects.new("casing", me); bpy.context.scene.collection.objects.link(o)
	return _new(o, "wood_cream", 0.0, grain="y")

# ---- landing (outside the door) ---------------------------------------------------------------------------------------
def landing():
	lz0 = Z0 - 1.8
	span(DOOR_X - 1.4, DOOR_X + 1.4, F - 0.04, F, lz0, Z0 - T, "concrete", name="lf")
	span(DOOR_X - 1.4, DOOR_X + 1.4, F, CEIL, lz0 - T, lz0, "plaster_hall", name="lw0")
	span(DOOR_X - 1.4 - T, DOOR_X - 1.4, F, CEIL, lz0, Z0 - T, "plaster_hall", name="lw1")
	span(DOOR_X + 1.4, DOOR_X + 1.4 + T, F, CEIL, lz0, Z0 - T, "plaster_hall", name="lw2")
	span(DOOR_X - 1.4, DOOR_X + 1.4, CEIL - 0.3, CEIL - 0.26, lz0, Z0 - T, "plaster_white", name="lc")
	span(DOOR_X - 0.4, DOOR_X + 0.4, F, F + 0.012, Z0 - 0.67, Z0 - 0.17, "doormat", 0.004, name="mat")
	box((0.9, 2.0, 0.05), (DOOR_X - 0.2, F + 1.0, lz0 + 0.025), "door_neighbour", 0.008, grain="y")
	box((0.12, 0.02, 0.06), (DOOR_X - 0.55, F + 1.0, lz0 + 0.06), "gold", 0.004)
	take("arch_landing")
	collider("col_landing", (2.8, 0.2, 1.8), (DOOR_X, F - 0.1, Z0 - 0.9))

# ---- wall fittings ------------------------------------------------------------------------------------------------------
def fittings():
	dx0 = DOOR_X - DOOR_W / 2
	for (x, y, z, rz) in [(dx0 - 0.25, F + 1.05, Z0, 0), (-0.3, F + 0.3, Z0, 0), (-1.0, F + 0.3, Z1, 180)]:
		sgn = 1 if z == Z0 else -1
		box((0.086, 0.086, 0.012), (x, y, z + sgn * 0.006), "white_plastic", 0.004)
		box((0.05, 0.05, 0.004), (x, y, z + sgn * 0.014), "white_plastic", 0.0015)
	take("arch_fittings")
