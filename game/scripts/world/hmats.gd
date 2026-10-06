class_name HMats
extends RefCounted
## Materials for the flat and for packaging (cardboard, tape, foam, bags). Procedural textures, cached.

static var _c := {}

static func _cached(key: String, make: Callable):
	if not _c.has(key): _c[key] = make.call()
	return _c[key]

# ------------------------------------------------------------------ textures
## Kraft corrugated board: warm brown, long paper fibres, faint flute ridges.
static func cardboard_tex() -> Array:
	return _cached("cardboard", func():
		var s := 512
		var img := Image.create(s, s, true, Image.FORMAT_RGB8)
		var bump := Image.create(s, s, false, Image.FORMAT_RGB8)
		var n := FastNoiseLite.new(); n.frequency = 0.012; n.fractal_octaves = 4; n.seed = 5
		var f := FastNoiseLite.new(); f.frequency = 0.25; f.seed = 9
		var base := Color("b88a58")
		for y in s:
			for x in s:
				var v := n.get_noise_2d(x, y) * 0.5 + 0.5
				var fib := f.get_noise_2d(x * 0.12, y * 2.2) * 0.5 + 0.5
				var flute := 0.5 + 0.5 * sin(x * TAU / 9.0)
				var c := base.darkened(0.08 * v).lightened(0.05 * fib)
				img.set_pixel(x, y, c)
				var b := 0.55 + 0.25 * flute + 0.2 * fib
				bump.set_pixel(x, y, Color(b, b, b))
		img.generate_mipmaps(); bump.bump_map_to_normal_map(1.2); bump.generate_mipmaps()
		return [ImageTexture.create_from_image(img), ImageTexture.create_from_image(bump)])

## Plaster wall: off-white with a soft roller texture.
static func plaster_n() -> Texture2D:
	return _cached("plaster_n", func():
		var s := 512
		var img := Image.create(s, s, false, Image.FORMAT_RGB8)
		var n := FastNoiseLite.new(); n.frequency = 0.06; n.fractal_octaves = 5; n.seed = 12
		for y in s:
			for x in s:
				var v := n.get_noise_2d(x, y) * 0.5 + 0.5
				img.set_pixel(x, y, Color(v, v, v))
		img.bump_map_to_normal_map(0.8); img.generate_mipmaps()
		return ImageTexture.create_from_image(img))

## Shipping label: white sticker with barcode, address lines and a tracking box.
static func label_tex(seed_v: int) -> Texture2D:
	return _cached("label%d" % (seed_v % 16), func():
		var w := 256; var h := 160
		var img := Image.create(w, h, true, Image.FORMAT_RGB8)
		img.fill(Color("f4f3ef"))
		var rng := RandomNumberGenerator.new(); rng.seed = seed_v % 16 + 3
		img.fill_rect(Rect2i(0, 0, w, 22), Color("1d1f22"))
		for i in 4: img.fill_rect(Rect2i(10, 32 + i * 12, rng.randi_range(80, 200), 5), Color("4a4d52"))
		var x := 14
		while x < w - 14:
			var bw := rng.randi_range(1, 4)
			img.fill_rect(Rect2i(x, 92, bw, 46), Color("111111"))
			x += bw + rng.randi_range(1, 3)
		img.fill_rect(Rect2i(14, 142, 120, 6), Color("4a4d52"))
		img.generate_mipmaps()
		return ImageTexture.create_from_image(img))

## Bubble wrap: clear sheet with a hex grid of air cells (normal map).
static func bubble_n() -> Texture2D:
	return _cached("bubble_n", func():
		var s := 256
		var img := Image.create(s, s, false, Image.FORMAT_RGB8)
		for y in s:
			for x in s:
				var cy := int(y / 16.0); var ox := 8.0 if cy % 2 == 1 else 0.0
				var dx := fposmod(x + ox, 16.0) - 8.0; var dy := fposmod(y, 16.0) - 8.0
				var r := sqrt(dx * dx + dy * dy)
				var v := clamp(1.0 - r / 6.5, 0.0, 1.0)
				v = sqrt(v)
				img.set_pixel(x, y, Color(v, v, v))
		img.bump_map_to_normal_map(3.0); img.generate_mipmaps()
		return ImageTexture.create_from_image(img))

# ------------------------------------------------------------------ geometry
## Soft rounded box (duvets, pillows, cushions, bags): every edge and corner rounded with radius r.
## Half of the vertex rows go to the flat middle, half to the rounded rim, so curves stay smooth. Origin = centre.
static func soft_box(s: Vector3, r: float, seg := 12) -> ArrayMesh:
	var key := "soft%s%.3f%d" % [s, r, seg]
	if _c.has(key): return _c[key]
	var h := s / 2.0
	r = min(r, min(h.x, min(h.y, h.z)) * 0.98)
	var inner := h - Vector3(r, r, r)
	var bm := BoxMesh.new(); bm.size = Vector3(2, 2, 2); bm.subdivide_width = seg; bm.subdivide_height = seg; bm.subdivide_depth = seg
	var arr := bm.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nrm := PackedVector3Array(); nrm.resize(v.size())
	var k := 0.5
	for i in v.size():
		var u: Vector3 = v[i]
		var p := Vector3.ZERO
		for ax in 3:
			var a: float = abs(u[ax]); var sg: float = sign(u[ax])
			p[ax] = sg * (a / k * inner[ax] if a <= k else inner[ax] + (a - k) / (1.0 - k) * r)
		var c := p.clamp(-inner, inner); var d := p - c
		if d.length() > 0.000001:
			v[i] = c + d.normalized() * r; nrm[i] = d.normalized()
		else:
			v[i] = p; nrm[i] = Vector3.UP
	arr[Mesh.ARRAY_VERTEX] = v; arr[Mesh.ARRAY_NORMAL] = nrm; arr[Mesh.ARRAY_TANGENT] = null
	var m := ArrayMesh.new(); m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var st := SurfaceTool.new(); st.create_from(m, 0); st.generate_tangents()
	_c[key] = st.commit()
	return _c[key]

## Plywood / chipboard: pale, almost grainless, matte.
static func plywood(col := Color("d2b68c")) -> StandardMaterial3D:
	if not hq("plywood").is_empty(): return pbr("plywood", 1.2, _tint(col, Color("d2b68c")))
	return _cached("m_ply" + col.to_html(), func():
		var m := StandardMaterial3D.new(); m.albedo_color = col; m.roughness = 0.78
		m.albedo_texture = Mats.noise_tex(0.08, 77); m.uv1_triplanar = true; m.uv1_scale = Vector3(1.5, 1.5, 1.5)
		m.normal_enabled = true; m.normal_texture = Mats.noise_tex(0.3, 78, true, 0.6); m.normal_scale = 0.2
		return m)

# ------------------------------------------------------------------ baked PBR sets (tools/blender/bake_materials.py)
const HQ := "res://assets/tex/hq/"
## [albedo, normal, roughness] baked in Blender, or [] when the set is missing.
static func hq(name: String) -> Array:
	return _cached("hq_" + name, func():
		var a := HQ + name + "_albedo.png"
		if not ResourceLoader.exists(a): return []
		return [load(a), load(HQ + name + "_normal.png"), load(HQ + name + "_rough.png")])

## Full PBR material from a baked set. `per_m` = tile repeats per metre (triplanar), `tint` multiplies the albedo.
static func pbr(name: String, per_m: float, tint := Color.WHITE, metal := 0.0, normal_k := 1.0) -> StandardMaterial3D:
	return _cached("pbr%s%.3f%s%.2f%.2f" % [name, per_m, tint.to_html(), metal, normal_k], func():
		var t: Array = hq(name)
		var m := StandardMaterial3D.new()
		m.albedo_texture = t[0]; m.albedo_color = tint
		m.normal_enabled = true; m.normal_texture = t[1]; m.normal_scale = normal_k
		m.roughness_texture = t[2]; m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED; m.roughness = 1.0
		m.metallic = metal
		m.uv1_triplanar = true; m.uv1_scale = Vector3(per_m, per_m, per_m); m.uv1_triplanar_sharpness = 4.0
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		return m)

## Tint so that a baked set whose own base colour is `base` comes out as `want`.
static func _tint(want: Color, base: Color) -> Color:
	return Color(clamp(want.r / base.r, 0.0, 1.6), clamp(want.g / base.g, 0.0, 1.6), clamp(want.b / base.b, 0.0, 1.6))

# ------------------------------------------------------------------ materials
static func cardboard(tint := Color.WHITE) -> StandardMaterial3D:
	if not hq("cardboard").is_empty(): return pbr("cardboard", 3.0, tint, 0.0, 0.8)
	return _cached("m_card" + tint.to_html(), func():
		var t: Array = cardboard_tex()
		var m := StandardMaterial3D.new(); m.albedo_texture = t[0]; m.albedo_color = tint; m.normal_enabled = true; m.normal_texture = t[1]; m.normal_scale = 0.35
		m.roughness = 0.88; m.uv1_triplanar = true; m.uv1_scale = Vector3(3.2, 3.2, 3.2)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		return m)

## Brushed steel / powder-coated metal from the baked set.
static func steel(col := Color("2a2c2f"), rough := 0.45) -> StandardMaterial3D:
	if hq("steel_brushed").is_empty(): return Mats.std(col, rough, 0.85)
	return pbr("steel_brushed", 4.0, _tint(col, Color("b9bcc0")), 0.9, 0.5)

## Brown packing tape: semi-glossy, slightly see-through.
static func tape(clear := false) -> StandardMaterial3D:
	return _cached("m_tape%s" % clear, func():
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.92, 0.9, 0.85, 0.35) if clear else Color(0.62, 0.42, 0.2, 0.88)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.roughness = 0.18; m.metallic_specular = 0.7
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		return m)

static func label(seed_v: int) -> StandardMaterial3D:
	return _cached("m_label%d" % (seed_v % 16), func():
		var m := StandardMaterial3D.new(); m.albedo_texture = label_tex(seed_v); m.roughness = 0.7
		return m)

## Branded mailer box: soft-touch matte print over the board.
static func brand_box(col: Color) -> StandardMaterial3D:
	return _cached("m_brand" + col.to_html(), func():
		var t: Array = cardboard_tex()
		var m := StandardMaterial3D.new(); m.albedo_color = col; m.roughness = 0.72; m.normal_enabled = true; m.normal_texture = t[1]; m.normal_scale = 0.12
		m.uv1_triplanar = true; m.uv1_scale = Vector3(3, 3, 3)
		return m)

## White EPE / polyethylene foam insert.
static func foam(col := Color("f2f2ee")) -> StandardMaterial3D:
	return _cached("m_foam" + col.to_html(), func():
		var m := StandardMaterial3D.new(); m.albedo_color = col; m.roughness = 0.95
		m.normal_enabled = true; m.normal_texture = Mats.noise_tex(0.4, 31, true, 1.5); m.normal_scale = 0.5; m.uv1_triplanar = true; m.uv1_scale = Vector3(6, 6, 6)
		m.subsurf_scatter_enabled = true; m.subsurf_scatter_strength = 0.35
		return m)

static func bubble_wrap() -> StandardMaterial3D:
	return _cached("m_bubble", func():
		var m := StandardMaterial3D.new(); m.albedo_color = Color(0.92, 0.96, 1.0, 0.32); m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.12; m.metallic_specular = 0.8; m.normal_enabled = true; m.normal_texture = bubble_n(); m.normal_scale = 1.0
		m.uv1_triplanar = true; m.uv1_scale = Vector3(5, 5, 5); m.cull_mode = BaseMaterial3D.CULL_DISABLED
		return m)

## Anti-static (ESD) shielding bag: grey metallised film you can half see through.
static func esd_bag() -> StandardMaterial3D:
	return _cached("m_esd", func():
		var m := StandardMaterial3D.new(); m.albedo_color = Color(0.55, 0.57, 0.6, 0.62); m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.metallic = 0.75; m.roughness = 0.28; m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.normal_enabled = true; m.normal_texture = Mats.noise_tex(0.05, 41, true, 2.0); m.normal_scale = 0.6; m.uv1_triplanar = true
		return m)

## Clear polyethylene bag (zip bags, case sleeve).
static func poly_bag() -> StandardMaterial3D:
	return _cached("m_poly", func():
		var m := StandardMaterial3D.new(); m.albedo_color = Color(0.95, 0.97, 1.0, 0.22); m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.2; m.metallic_specular = 0.9; m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.normal_enabled = true; m.normal_texture = Mats.noise_tex(0.04, 43, true, 2.5); m.normal_scale = 0.8; m.uv1_triplanar = true
		return m)

## Protective peel film on plates: faint blue, slightly cloudy.
static func peel_film() -> StandardMaterial3D:
	return _cached("m_film", func():
		var m := StandardMaterial3D.new(); m.albedo_color = Color(0.62, 0.78, 0.95, 0.45); m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.35; m.cull_mode = BaseMaterial3D.CULL_DISABLED
		return m)

static func plaster(col := Color("e8e4dc")) -> StandardMaterial3D:
	if not hq("plaster").is_empty(): return pbr("plaster", 0.6, _tint(col, Color("e9e5dc")), 0.0, 0.6)
	return _cached("m_plaster" + col.to_html(), func():
		var m := StandardMaterial3D.new(); m.albedo_color = col; m.roughness = 0.92
		m.normal_enabled = true; m.normal_texture = plaster_n(); m.normal_scale = 0.25; m.uv1_triplanar = true; m.uv1_scale = Vector3(0.7, 0.7, 0.7)
		return m)

static func glass() -> StandardMaterial3D:
	return _cached("m_glass", func():
		var m := StandardMaterial3D.new(); m.albedo_color = Color(0.85, 0.92, 0.98, 0.08); m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.02; m.metallic_specular = 1.0
		return m)

static func wood(name: String, uv := 0.5, rough := 0.55) -> StandardMaterial3D:
	var baked: String = {"planks_light": "floor_oak", "wood_oak": "oak", "wood_walnut": "walnut", "wood_light": "plywood", "planks_dark": "concrete"}.get(name, "")
	if baked != "" and not hq(baked).is_empty():
		# floor: 5 boards (~0.16 m) per tile; furniture woods ~0.8 m of grain per tile
		return pbr(baked, {"floor_oak": 1.25, "concrete": 0.6}.get(baked, 1.2))
	return _cached("m_wood%s%.2f%.2f" % [name, uv, rough], func():
		var m := StandardMaterial3D.new(); m.albedo_texture = Mats.tex(name); m.normal_enabled = true; m.normal_texture = Mats.tex(name + "_n"); m.normal_scale = 0.45
		m.roughness = rough; m.uv1_triplanar = true; m.uv1_scale = Vector3(uv, uv, uv)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		return m)

static func fabric(col: Color, uv := 4.0) -> StandardMaterial3D:
	if not hq("fabric_linen").is_empty(): return pbr("fabric_linen", 2.5, _tint(col, Color("e6e2da")), 0.0, 0.8)
	return _cached("m_fab%s%.1f" % [col.to_html(), uv], func():
		var m := StandardMaterial3D.new(); m.albedo_texture = Mats.tex("fabric"); m.albedo_color = col; m.normal_enabled = true; m.normal_texture = Mats.tex("fabric_n")
		m.normal_scale = 0.6; m.roughness = 0.96; m.uv1_triplanar = true; m.uv1_scale = Vector3(uv, uv, uv)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		return m)
