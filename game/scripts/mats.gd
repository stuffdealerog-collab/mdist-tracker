class_name Mats
extends RefCounted
## Materials and procedural textures. Everything cached.

static var _c := {}
static var legend_atlas: Texture2D = null
const ATLAS_CELLS := 16.0

const CAP_TOP_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
uniform sampler2D legend_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D grain : filter_linear_mipmap, repeat_enable;
uniform float atlas_cells = 16.0;
instance uniform vec4 base_color : source_color = vec4(0.9, 0.9, 0.9, 1.0);
instance uniform vec4 legend_color : source_color = vec4(0.1, 0.1, 0.1, 1.0);
instance uniform float legend_index = -1.0;
instance uniform float key_w = 1.0;
instance uniform float centered = 0.0;
instance uniform float rough = 0.7;
instance uniform vec4 glow : source_color = vec4(0.0);
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	vec3 col = base_color.rgb;
	float a = 0.0;
	if (legend_index >= 0.0) {
		vec2 k = vec2(UV.x * key_w, UV.y);
		k.x = k.x * 1.04 - 0.02;
		if (centered > 0.5) k.x -= (key_w - 1.0) * 0.5;
		if (k.x >= 0.0 && k.x <= 1.0 && k.y >= 0.0 && k.y <= 1.0) {
			float cx = mod(legend_index, atlas_cells);
			float cy = floor(legend_index / atlas_cells);
			a = texture(legend_atlas, (vec2(cx, cy) + k) / atlas_cells).a;
		}
	}
	col = mix(col, legend_color.rgb, a);
	float g = texture(grain, lp.xz * 1.7).r;
	ALBEDO = col * (0.97 + g * 0.06);
	ROUGHNESS = clamp(rough + (g - 0.5) * 0.18 - a * 0.1, 0.05, 1.0);
	SPECULAR = 0.42;
	EMISSION = glow.rgb * glow.a;
}
"""
const CAP_SIDE_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
uniform sampler2D grain : filter_linear_mipmap, repeat_enable;
instance uniform vec4 base_color : source_color = vec4(0.9, 0.9, 0.9, 1.0);
instance uniform vec4 legend_color : source_color = vec4(0.1, 0.1, 0.1, 1.0);
instance uniform float legend_index = -1.0;
instance uniform float key_w = 1.0;
instance uniform float centered = 0.0;
instance uniform float rough = 0.7;
instance uniform vec4 glow : source_color = vec4(0.0);
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	float unused = legend_color.r * 0.0 + legend_index * 0.0 + key_w * 0.0 + centered * 0.0;
	float g = texture(grain, lp.xy * 2.1 + lp.zz * 1.3).r + unused;
	ALBEDO = base_color.rgb * 0.93 * (0.97 + g * 0.06);
	ROUGHNESS = clamp(rough + (g - 0.5) * 0.16, 0.05, 1.0);
	SPECULAR = 0.42;
	EMISSION = glow.rgb * glow.a;
}
"""

static func lin(c: String) -> Color: return Color(c)

static func grain_tex() -> Texture2D:
	if _c.has("grain"): return _c.grain
	var img := Image.create(256, 256, false, Image.FORMAT_L8)
	var n := FastNoiseLite.new(); n.frequency = 0.08; n.fractal_octaves = 3
	for y in 256:
		for x in 256:
			var v := (n.get_noise_2d(x, y) * 0.5 + 0.5) * 0.6 + randf() * 0.4
			img.set_pixel(x, y, Color(v, v, v))
	img.generate_mipmaps()
	_c.grain = ImageTexture.create_from_image(img)
	return _c.grain

static func cap_top() -> ShaderMaterial:
	if _c.has("cap_top"): return _c.cap_top
	var sh := Shader.new(); sh.code = CAP_TOP_SHADER
	var m := ShaderMaterial.new(); m.shader = sh
	m.set_shader_parameter("grain", grain_tex()); m.set_shader_parameter("atlas_cells", ATLAS_CELLS)
	if legend_atlas: m.set_shader_parameter("legend_atlas", legend_atlas)
	_c.cap_top = m; return m
static func cap_side() -> ShaderMaterial:
	if _c.has("cap_side"): return _c.cap_side
	var sh := Shader.new(); sh.code = CAP_SIDE_SHADER
	var m := ShaderMaterial.new(); m.shader = sh; m.set_shader_parameter("grain", grain_tex())
	_c.cap_side = m; return m
static func set_atlas(t: Texture2D) -> void:
	legend_atlas = t
	if _c.has("cap_top"): _c.cap_top.set_shader_parameter("legend_atlas", t)

# --- procedural textures ----------------------------------------------------
static func wood_tex(base: Color, size := 512) -> Array:
	var key := "wood" + base.to_html()
	if _c.has(key): return _c[key]
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var bump := Image.create(size, size, false, Image.FORMAT_RGB8)
	var n := FastNoiseLite.new(); n.frequency = 0.006; n.fractal_octaves = 4
	var n2 := FastNoiseLite.new(); n2.frequency = 0.05; n2.seed = 7
	for y in size:
		for x in size:
			var w := n.get_noise_2d(x * 0.15, y * 2.2) * 9.0
			var ring := fposmod(w + y * 0.02, 1.0)
			var r2 := smoothstep(0.0, 0.5, ring) * smoothstep(1.0, 0.55, ring)
			var fine := n2.get_noise_2d(x * 0.3, y * 6.0) * 0.5 + 0.5
			var k := 0.78 + r2 * 0.18 + fine * 0.08
			img.set_pixel(x, y, base * k)
			var b := r2 * 0.6 + fine * 0.4
			bump.set_pixel(x, y, Color(b, b, b))
	img.generate_mipmaps()
	bump.bump_map_to_normal_map(3.0); bump.generate_mipmaps()
	_c[key] = [ImageTexture.create_from_image(img), ImageTexture.create_from_image(bump)]
	return _c[key]

static func brushed_normal() -> Texture2D:
	if _c.has("brushed"): return _c.brushed
	var s := 512
	var bump := Image.create(s, s, false, Image.FORMAT_RGB8)
	var rows := PackedFloat32Array(); rows.resize(s)
	for y in s: rows[y] = randf()
	for y in s:
		for x in s:
			var v := rows[y] * 0.7 + randf() * 0.15 + rows[(y + int(x / 37.0)) % s] * 0.15
			bump.set_pixel(x, y, Color(v, v, v))
	bump.bump_map_to_normal_map(0.6); bump.generate_mipmaps()
	_c.brushed = ImageTexture.create_from_image(bump)
	return _c.brushed

static func fabric_tex(base: Color) -> Array:
	var key := "fabric" + base.to_html()
	if _c.has(key): return _c[key]
	var s := 256
	var img := Image.create(s, s, false, Image.FORMAT_RGB8); var bump := Image.create(s, s, false, Image.FORMAT_RGB8)
	for y in s:
		for x in s:
			var weave := (sin(x * 1.6) * 0.5 + 0.5) * (sin(y * 1.6 + 1.0) * 0.5 + 0.5)
			var k := 0.86 + weave * 0.1 + randf() * 0.06
			img.set_pixel(x, y, base * k); bump.set_pixel(x, y, Color(weave, weave, weave))
	img.generate_mipmaps(); bump.bump_map_to_normal_map(1.2); bump.generate_mipmaps()
	_c[key] = [ImageTexture.create_from_image(img), ImageTexture.create_from_image(bump)]
	return _c[key]

static func noise_tex(freq := 0.02, seed := 1, normal := false, strength := 1.0) -> Texture2D:
	var key := "noise%f%d%s" % [freq, seed, normal]
	if _c.has(key): return _c[key]
	var s := 512
	var img := Image.create(s, s, false, Image.FORMAT_RGB8)
	var n := FastNoiseLite.new(); n.frequency = freq; n.seed = seed; n.fractal_octaves = 5
	for y in s:
		for x in s:
			var v := n.get_noise_2d(x, y) * 0.5 + 0.5
			img.set_pixel(x, y, Color(v, v, v))
	if normal: img.bump_map_to_normal_map(strength)
	img.generate_mipmaps()
	_c[key] = ImageTexture.create_from_image(img)
	return _c[key]

# --- part materials ------------------------------------------------------
static func case_mat(case_id: String, color_idx: int) -> Material:
	var cs := Data.case_(case_id)
	var col = Color(cs.colors[clamp(color_idx, 0, cs.colors.size() - 1)][1])
	var key := "case%s%d" % [case_id, color_idx]
	if _c.has(key): return _c[key]
	var m := StandardMaterial3D.new()
	match cs.look:
		"metal":
			m.albedo_color = col; m.metallic = 0.9; m.roughness = 0.34
			m.normal_enabled = true; m.normal_texture = brushed_normal(); m.normal_scale = 0.35
			m.uv1_triplanar = true; m.uv1_scale = Vector3(0.6, 0.6, 0.6)
			m.clearcoat_enabled = true; m.clearcoat = 0.25; m.clearcoat_roughness = 0.4
		"wood":
			var t := wood_tex(col)
			m.albedo_texture = t[0]; m.normal_enabled = true; m.normal_texture = t[1]; m.normal_scale = 0.5
			m.roughness = 0.55; m.uv1_triplanar = true; m.uv1_scale = Vector3(0.18, 0.18, 0.18)
			m.clearcoat_enabled = true; m.clearcoat = 0.5; m.clearcoat_roughness = 0.3
		"acrylic":
			m.albedo_color = Color(col.r, col.g, col.b, 0.55); m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
			m.roughness = 0.06; m.metallic_specular = 0.7; m.refraction_enabled = true; m.refraction_scale = 0.02
			m.rim_enabled = true; m.rim = 0.3
		_:
			m.albedo_color = col; m.roughness = 0.55
			m.normal_enabled = true; m.normal_texture = noise_tex(0.08, 3, true, 0.4); m.normal_scale = 0.2; m.uv1_triplanar = true
	_c[key] = m; return m

static func plate_mat(id: String, holes: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = holes; m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR; m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	match id:
		"p_fr4": m.albedo_color = Color("2a3a2a"); m.roughness = 0.55
		"p_alu": m.albedo_color = Color("b4bac0"); m.metallic = 0.9; m.roughness = 0.3; m.normal_enabled = true; m.normal_texture = brushed_normal(); m.normal_scale = 0.3
		"p_pc": m.albedo_color = Color(0.86, 0.92, 0.95, 0.7); m.roughness = 0.12; m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		"p_brass": m.albedo_color = Color("caa24a"); m.metallic = 0.95; m.roughness = 0.25
		"p_pom": m.albedo_color = Color("ece8dd"); m.roughness = 0.5
		"p_cf": m.albedo_color = Color("1c1e21"); m.roughness = 0.3; m.metallic = 0.3; m.normal_enabled = true; m.normal_texture = noise_tex(0.3, 9, true, 0.6)
	return m

static func std(col: Color, rough := 0.5, metal := 0.0) -> StandardMaterial3D:
	var key := "std%s%.2f%.2f" % [col.to_html(), rough, metal]
	if _c.has(key): return _c[key]
	var m := StandardMaterial3D.new(); m.albedo_color = col; m.roughness = rough; m.metallic = metal
	if col.a < 0.999: m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_c[key] = m; return m

static func emissive(col: Color, energy := 2.0) -> StandardMaterial3D:
	var key := "em%s%.2f" % [col.to_html(), energy]
	if _c.has(key): return _c[key]
	var m := StandardMaterial3D.new(); m.albedo_color = col; m.emission_enabled = true; m.emission = col; m.emission_energy_multiplier = energy
	_c[key] = m; return m

static func resin(col: Color) -> StandardMaterial3D:
	var key := "resin" + col.to_html()
	if _c.has(key): return _c[key]
	var m := StandardMaterial3D.new(); m.albedo_color = col; m.roughness = 0.08; m.metallic_specular = 0.8
	m.clearcoat_enabled = true; m.clearcoat = 1.0; m.clearcoat_roughness = 0.05
	m.emission_enabled = true; m.emission = col; m.emission_energy_multiplier = 0.25
	m.subsurf_scatter_enabled = true; m.subsurf_scatter_strength = 0.4
	_c[key] = m; return m

# --- room textures -----------------------------------------------------------
static func brick_tex() -> Array:
	if _c.has("brick"): return _c.brick
	var s := 512
	var img := Image.create(s, s, false, Image.FORMAT_RGB8); var bump := Image.create(s, s, false, Image.FORMAT_RGB8)
	var n := FastNoiseLite.new(); n.frequency = 0.05
	var rng := RandomNumberGenerator.new(); rng.seed = 5
	var bh := 32; var bw := 96
	var tints := []
	for i in 200: tints.append(Color("8a4532").lerp(Color("a65a3e"), rng.randf()).darkened(rng.randf() * 0.25))
	for y in s:
		var row := y / bh
		var off := (bw / 2) if row % 2 == 1 else 0
		for x in s:
			var bx := (x + off) % s
			var col_i := (row * 7 + (x + off) / bw) % 200
			var mortar := (y % bh) < 3 or (bx % bw) < 3
			var nv := n.get_noise_2d(x, y) * 0.5 + 0.5
			if mortar:
				img.set_pixel(x, y, Color("b9b1a3") * (0.8 + nv * 0.2)); bump.set_pixel(x, y, Color(0.1, 0.1, 0.1))
			else:
				var c: Color = tints[col_i]
				img.set_pixel(x, y, c * (0.85 + nv * 0.3)); var bv := 0.6 + nv * 0.4; bump.set_pixel(x, y, Color(bv, bv, bv))
	img.generate_mipmaps(); bump.bump_map_to_normal_map(4.0); bump.generate_mipmaps()
	_c.brick = [ImageTexture.create_from_image(img), ImageTexture.create_from_image(bump)]
	return _c.brick

static func concrete_tex(base := Color("8d8c88")) -> Array:
	var key := "concrete" + base.to_html()
	if _c.has(key): return _c[key]
	var s := 512
	var img := Image.create(s, s, false, Image.FORMAT_RGB8); var bump := Image.create(s, s, false, Image.FORMAT_RGB8)
	var n := FastNoiseLite.new(); n.frequency = 0.01; n.fractal_octaves = 5
	var n2 := FastNoiseLite.new(); n2.frequency = 0.2; n2.seed = 3
	for y in s:
		for x in s:
			var v := n.get_noise_2d(x, y) * 0.5 + 0.5; var f := n2.get_noise_2d(x, y) * 0.5 + 0.5
			var k := 0.8 + v * 0.25 + f * 0.06
			if randf() < 0.004: k *= 0.7
			img.set_pixel(x, y, base * k); bump.set_pixel(x, y, Color(f, f, f))
	img.generate_mipmaps(); bump.bump_map_to_normal_map(1.5); bump.generate_mipmaps()
	_c[key] = [ImageTexture.create_from_image(img), ImageTexture.create_from_image(bump)]
	return _c[key]

static func planks_tex(base: Color) -> Array:
	var key := "planks" + base.to_html()
	if _c.has(key): return _c[key]
	var s := 512
	var img := Image.create(s, s, false, Image.FORMAT_RGB8); var bump := Image.create(s, s, false, Image.FORMAT_RGB8)
	var n := FastNoiseLite.new(); n.frequency = 0.004; n.fractal_octaves = 4
	var rng := RandomNumberGenerator.new(); rng.seed = 11
	var pw := 64
	var tints := []
	for i in 16: tints.append(0.82 + rng.randf() * 0.3)
	for y in s:
		for x in s:
			var plank := x / pw
			var seam := (x % pw) < 2 or ((y + plank * 137) % 384) < 2
			var g := n.get_noise_2d(x * 4.0, y * 0.25 + plank * 300) * 0.5 + 0.5
			var k: float = tints[plank % 16] * (0.82 + g * 0.3)
			if seam: k *= 0.45
			img.set_pixel(x, y, base * k); var bv := 0.15 if seam else 0.6 + g * 0.3; bump.set_pixel(x, y, Color(bv, bv, bv))
	img.generate_mipmaps(); bump.bump_map_to_normal_map(2.0); bump.generate_mipmaps()
	_c[key] = [ImageTexture.create_from_image(img), ImageTexture.create_from_image(bump)]
	return _c[key]

static func pegboard_tex() -> Array:
	if _c.has("peg"): return _c.peg
	var s := 256
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color("c9a77c"))
	for y in range(8, s, 16):
		for x in range(8, s, 16):
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					if dx * dx + dy * dy <= 5: img.set_pixel(x + dx, y + dy, Color("2a2018"))
	img.generate_mipmaps()
	_c.peg = [ImageTexture.create_from_image(img)]
	return _c.peg

static func textured(arr: Array, uv := Vector3(1, 1, 1), rough := 0.8, triplanar := true, tint := Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = arr[0]; m.albedo_color = tint; m.roughness = rough
	if arr.size() > 1: m.normal_enabled = true; m.normal_texture = arr[1]; m.normal_scale = 0.7
	m.uv1_triplanar = triplanar; m.uv1_scale = uv
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

static func city_night_tex() -> Texture2D:
	if _c.has("city"): return _c.city
	var w := 1024; var h := 384
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		var t := float(y) / h
		var sky = Color("0b1530").lerp(Color("3b2a4a"), t * t)
		for x in w: img.set_pixel(x, y, sky)
	var rng := RandomNumberGenerator.new(); rng.seed = 9
	for layer in 3:
		var x := 0
		while x < w:
			var bw := rng.randi_range(30, 90); var bh := rng.randi_range(80, 300 - layer * 60)
			var shade = Color("0a0d16").lerp(Color("1a1f30"), layer * 0.4)
			img.fill_rect(Rect2i(x, h - bh, bw, bh), shade)
			for wy in range(h - bh + 6, h - 4, 9):
				for wx in range(x + 4, x + bw - 4, 7):
					if rng.randf() < 0.35:
						img.fill_rect(Rect2i(wx, wy, 3, 4), Color("ffd89a") if rng.randf() < 0.8 else Color("9ad0ff"))
			x += bw + rng.randi_range(0, 10)
	img.generate_mipmaps()
	_c.city = ImageTexture.create_from_image(img)
	return _c.city

static func day_sky_tex() -> Texture2D:
	if _c.has("daysky"): return _c.daysky
	var w := 512; var h := 256
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var n := FastNoiseLite.new(); n.frequency = 0.01; n.fractal_octaves = 4
	for y in h:
		var t := float(y) / h
		var sky = Color("7fb3e6").lerp(Color("dbe9f5"), t)
		for x in w:
			var c := n.get_noise_2d(x, y * 2.0) * 0.5 + 0.5
			img.set_pixel(x, y, sky.lerp(Color.WHITE, smoothstep(0.55, 0.8, c) * (1.0 - t)))
	# distant rooftops
	var rng := RandomNumberGenerator.new(); rng.seed = 2
	var x := 0
	while x < w:
		var bw := rng.randi_range(20, 60); var bh := rng.randi_range(30, 110)
		img.fill_rect(Rect2i(x, h - bh, bw, bh), Color("8f99a6").lerp(Color("5d6672"), rng.randf()))
		x += bw
	img.generate_mipmaps()
	_c.daysky = ImageTexture.create_from_image(img)
	return _c.daysky
