# Procedural foliage for the two pots (the procedural half of the hybrid approach; a Hybrid3D "potted plant" family
# can replace it with generated leaves later): a peace lily (arching lanceolate leaves with a midrib, white spathes)
# on the window sill and a lucky bamboo (segmented stalks with nodes and a few leaves) on the chest.
import random
import bmesh
from core import *
from core import _new

def leaf(bm, uv, base, direction, length, width, droop, twist, rng, segs=10, rows=4):
	"""One lanceolate leaf as a curved strip with a folded midrib. base: game point, direction: (dx, dz) unit, angle up."""
	dx, dz = direction
	pts = []
	for i in range(segs + 1):
		t = i / segs
		# arc: rises then droops
		h = length * (math.sin(t * math.pi * 0.62) * 0.9 - droop * t * t)
		r = length * t
		pts.append((base[0] + dx * r, base[1] + h, base[2] + dz * r))
	rows_v = []
	for i, p in enumerate(pts):
		t = i / segs
		w = width * math.sin(math.pi * min(1.0, t * 1.05)) ** 0.8 * (1.0 if t < 0.97 else 0.3)
		side = (-dz, 0, dx)
		row = []
		for k in range(rows + 1):
			s = (k / rows - 0.5) * 2                                    # -1..1 across the leaf
			fold = abs(s) * w * 0.25                                    # V-shaped midrib fold
			ang = twist * t * s
			x = p[0] + side[0] * s * w + dx * ang * 0.02
			y = p[1] + fold + rng.uniform(-0.001, 0.001)
			z = p[2] + side[2] * s * w + dz * ang * 0.02
			row.append(bm.verts.new(g(x, y, z)))
		rows_v.append(row)
	for i in range(segs):
		for k in range(rows):
			f = bm.faces.new([rows_v[i][k], rows_v[i][k + 1], rows_v[i + 1][k + 1], rows_v[i + 1][k]])
			for l, (a, b) in zip(f.loops, [(k / rows, i / segs), ((k + 1) / rows, i / segs), ((k + 1) / rows, (i + 1) / segs), (k / rows, (i + 1) / segs)]):
				l[uv].uv = (a, b)

def _obj(bm, name, material):
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
	o = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(o)
	o["keep_uv"] = 1; o["smooth"] = 1
	return _new(o, material)

def peace_lily():
	rng = random.Random(12)
	cx, cy, cz = X0 - NICHE["d"] / 2 + 0.03, WIN["y0"] + 0.125, 0.97
	bm = bmesh.new(); uv = bm.loops.layers.uv.new("UVMap")
	for k in range(16):
		a = k * 2.399 + rng.uniform(-0.2, 0.2)
		d = (math.cos(a), math.sin(a))
		base = (cx + d[0] * 0.012, cy, cz + d[1] * 0.012)
		leaf(bm, uv, base, d, rng.uniform(0.2, 0.32), rng.uniform(0.028, 0.04), rng.uniform(0.5, 0.9), rng.uniform(-1, 1), rng)
	_obj(bm, "lily_leaves", "leaf_green")
	# petioles
	for k in range(10):
		a = k * 2.399
		cyl(0.003, 0.12, (cx + math.cos(a) * 0.02, cy + 0.05, cz + math.sin(a) * 0.02), "leaf_green", verts=6, bevel=0.0)
	# two white spathes on long stems
	for (a, h) in [(0.6, 0.36), (2.4, 0.33)]:
		x, z = cx + math.cos(a) * 0.04, cz + math.sin(a) * 0.04
		cyl(0.0025, h, (x, cy + h / 2, z), "leaf_green", verts=6, bevel=0.0)
		bm2 = bmesh.new(); uv2 = bm2.loops.layers.uv.new("UVMap")
		leaf(bm2, uv2, (x, cy + h - 0.02, z), (math.cos(a + 1.2), math.sin(a + 1.2)), 0.07, 0.03, -2.0, 0.0, rng, 6, 4)
		_obj(bm2, "spathe", "petal_white")
		cyl(0.004, 0.035, (x, cy + h + 0.01, z), "spadix", verts=8, bevel=0.0)
	take("plant_lily", lightmap=False, smooth_angle=89.0)

def lucky_bamboo():
	rng = random.Random(4)
	cx, cy, cz = 1.27, F + 0.855 + 0.1, 2.33
	for k, (ox, oz, h) in enumerate([(0.0, 0.0, 0.42), (0.018, 0.012, 0.36), (-0.016, 0.01, 0.3), (0.006, -0.018, 0.25)]):
		x, z = cx + ox, cz + oz
		y = cy; seg = 0.07 + rng.uniform(-0.01, 0.01)
		while y < cy + h:
			sl = min(seg, cy + h - y)
			cyl(0.0065, sl - 0.004, (x, y + sl / 2, z), "bamboo", verts=12, bevel=0.0)
			cyl(0.0075, 0.005, (x, y + sl, z), "bamboo_node", verts=12, bevel=0.0)
			y += sl
		bm = bmesh.new(); uv = bm.loops.layers.uv.new("UVMap")
		for j in range(3 + k % 2):
			a = rng.uniform(0, 2 * math.pi)
			leaf(bm, uv, (x, cy + h - 0.01 - j * 0.02, z), (math.cos(a), math.sin(a)), rng.uniform(0.09, 0.14), 0.016, 0.9, 0.5, rng, 8, 3)
		_obj(bm, "bamboo_leaves", "leaf_green")
	take("plant_bamboo", lightmap=False, smooth_angle=89.0)

def build():
	peace_lily(); lucky_bamboo()
