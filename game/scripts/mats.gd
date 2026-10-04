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
## Plain-sawn hardwood: cathedral growth rings, latewood bands, pores and medullary flecks.
static func tex(name: String) -> Texture2D:
	var key := "tex:" + name
	if _c.has(key): return _c[key]
	var path := "res://assets/tex/%s.png" % name
	_c[key] = load(path) if ResourceLoader.exists(path) else null
	return _c[key]

## Wood species picked from the case/desk colour (baked textures, see tools/bake_tex.py).
static func wood_tex(base: Color, _size := 512) -> Array:
	var map := {"6b4528": "wood_walnut", "a8814f": "wood_oak", "8a6a3e": "wood_zebrano", "c9a77c": "wood_light", "d6b48a": "wood_light", "7a5434": "wood_desk"}
	var n: String = map.get(base.to_html(false), "wood_oak" if base.v > 0.6 else "wood_walnut")
	return [tex(n), tex(n + "_n")]

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
	return [tex("fabric"), tex("fabric_n")]
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
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	match cs.look:
		"metal":
			# bead-blasted anodized aluminium / titanium: satin, never mirror-like
			m.albedo_color = col.darkened(0.06) if col.get_luminance() > 0.5 else col
			m.metallic = 1.0
			m.roughness = 0.38 if case_id == "c_ti" else 0.46
			m.normal_enabled = true; m.normal_texture = bead_normal(); m.normal_scale = 0.25
			m.uv1_triplanar = true; m.uv1_scale = Vector3(1.6, 1.6, 1.6)
			m.roughness_texture = noise_tex(0.12, 21); m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
			m.anisotropy_enabled = case_id == "c_ti"; m.anisotropy = 0.35
		"wood":
			var t := wood_tex(col)
			m.albedo_texture = t[0]; m.normal_enabled = true; m.normal_texture = t[1]; m.normal_scale = 0.35
			m.roughness = 0.62; m.uv1_triplanar = true; m.uv1_scale = Vector3(0.22, 0.22, 0.22)
			m.clearcoat_enabled = true; m.clearcoat = 0.18; m.clearcoat_roughness = 0.45
		"acrylic":
			if case_id == "c_pc":
				# frosted polycarbonate
				m.albedo_color = Color(col.r, col.g, col.b, 0.72); m.roughness = 0.42
			else:
				m.albedo_color = Color(col.r, col.g, col.b, 0.42); m.roughness = 0.08
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
			m.metallic_specular = 0.5; m.refraction_enabled = true; m.refraction_scale = 0.015
			m.backlight_enabled = true; m.backlight = Color(col.r, col.g, col.b) * 0.25
		_:
			# injection-moulded ABS with a fine spark-eroded texture
			m.albedo_color = col; m.roughness = 0.62
			m.normal_enabled = true; m.normal_texture = noise_tex(0.35, 3, true, 0.6); m.normal_scale = 0.18; m.uv1_triplanar = true; m.uv1_scale = Vector3(2, 2, 2)
	_c[key] = m; return m

static func bead_normal() -> Texture2D: return tex("bead_n")
## Interior HDR panorama used as sky for ambient light and reflections.
static func room_panorama(style: String) -> Texture2D:
	var key := "pano" + style
	if _c.has(key): return _c[key]
	var w := 1024; var h := 512
	var img := Image.create(w, h, false, Image.FORMAT_RGBH)
	var pal: Dictionary = {
		"garage": {"wall": Color(0.42, 0.41, 0.39), "floor": Color(0.25, 0.24, 0.23), "ceil": Color(0.3, 0.3, 0.3), "win": Color(0.6, 0.7, 0.85) * 1.5, "lamp": Color(1.0, 0.82, 0.6) * 9.0},
		"loft": {"wall": Color(0.52, 0.3, 0.22), "floor": Color(0.35, 0.24, 0.16), "ceil": Color(0.32, 0.32, 0.32), "win": Color(0.85, 0.92, 1.0) * 7.0, "lamp": Color(1.0, 0.9, 0.78) * 5.0},
		"studio": {"wall": Color(0.85, 0.84, 0.82), "floor": Color(0.62, 0.5, 0.38), "ceil": Color(0.92, 0.92, 0.9), "win": Color(0.9, 0.95, 1.0) * 6.0, "lamp": Color(1.0, 0.95, 0.88) * 5.0},
		"boutique": {"wall": Color(0.16, 0.24, 0.2), "floor": Color(0.22, 0.14, 0.09), "ceil": Color(0.12, 0.1, 0.08), "win": Color(1.0, 0.85, 0.65) * 3.0, "lamp": Color(1.0, 0.82, 0.6) * 8.0},
		"flagship": {"wall": Color(0.09, 0.09, 0.12), "floor": Color(0.06, 0.06, 0.07), "ceil": Color(0.05, 0.05, 0.06), "win": Color(0.45, 0.4, 0.75) * 2.5, "lamp": Color(0.9, 0.92, 1.0) * 6.0},
	}.get(style, {})
	if pal.is_empty(): pal = {"wall": Color(0.4, 0.4, 0.4), "floor": Color(0.2, 0.2, 0.2), "ceil": Color(0.3, 0.3, 0.3), "win": Color.WHITE * 4.0, "lamp": Color.WHITE * 6.0}
	var n := FastNoiseLite.new(); n.frequency = 0.02
	for y in h:
		var v := float(y) / h          # 0 = up, 1 = down
		for x in w:
			var u := float(x) / w
			var c: Color
			if v < 0.3: c = (pal.ceil as Color).lerp(pal.wall, smoothstep(0.15, 0.3, v))
			elif v < 0.55: c = pal.wall
			else: c = (pal.wall as Color).lerp(pal.floor, smoothstep(0.55, 0.65, v))
			c *= 0.9 + n.get_noise_2d(x, y) * 0.1
			# window band (behind the desk) and a softbox above
			var dx: float = abs(u - 0.5); var wy: float = abs(v - 0.38)
			if dx < 0.13 and wy < 0.1: c = (pal.win as Color) * (1.0 - smoothstep(0.1, 0.13, dx) * 0.6)
			var lx: float = abs(u - 0.25); var ly: float = abs(v - 0.12)
			if lx < 0.04 and ly < 0.025: c = pal.lamp
			var l2: float = abs(u - 0.75)
			if l2 < 0.06 and abs(v - 0.08) < 0.02: c = (pal.lamp as Color) * 0.6
			img.set_pixel(x, y, c)
	_c[key] = ImageTexture.create_from_image(img)
	return _c[key]

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
static func brick_tex() -> Array: return [tex("brick"), tex("brick_n")]
static func concrete_tex(base := Color("8d8c88")) -> Array:
	var n := "concrete_floor" if base.v < 0.4 else "concrete_wall"
	return [tex(n), tex(n + "_n")]
static func planks_tex(base: Color) -> Array:
	var n := "planks_light" if base.v > 0.55 else ("planks_boutique" if base.v < 0.25 else "planks_dark")
	return [tex(n), tex(n + "_n")]
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
