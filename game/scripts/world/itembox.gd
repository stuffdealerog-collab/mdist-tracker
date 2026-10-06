class_name ItemBox
extends Node3D
## A part in its retail packaging, as it sits in the wardrobe or on the bench. Origin = bottom centre, front = +Z.
## The construction comes from Blender (tools/blender/kit/packaging.py -> assets/models/pack/<kind>.glb); the print is
## the brand template of the product's parody brand (data/packaging.json, art by GPT Image in assets/tex/pack/), the
## product name is printed on the template's label area.

const SIZE := {"case": Vector3(0.36, 0.09, 0.15), "plate": Vector3(0.33, 0.022, 0.13), "pcb": Vector3(0.31, 0.014, 0.13),
	"stab": Vector3(0.12, 0.02, 0.08), "kc": Vector3(0.32, 0.065, 0.14)}
## Printed face of each construction: size in metres (for aspect fit) and where the product name goes
## (label centre on the face in -0.5..0.5 face coords, width fraction, on top or front).
const FACE := {
	"case_box":     {"size": Vector2(0.397, 0.167), "top": true,  "label": Vector2(-0.24, 0.32), "w": 0.4},
	"keycap_box":   {"size": Vector2(0.357, 0.147), "top": true,  "label": Vector2(-0.24, 0.32), "w": 0.42},
	"kraft_box":    {"size": Vector2(0.17, 0.09),   "top": true,  "label": Vector2(0.0, 0.28), "w": 0.8},
	"plate_sleeve": {"size": Vector2(0.204, 0.083), "top": true,  "label": Vector2(0.0, 0.25), "w": 0.8},
	"esd_pcb":      {"size": Vector2(0.192, 0.083), "top": true,  "label": Vector2(0.0, 0.25), "w": 0.8},
	"switch_box":   {"size": Vector2(0.128, 0.078), "top": false, "label": Vector2(0.0, 0.0), "w": 0.9, "on_top": Vector2(0.128, 0.045)},
	"switch_bag":   {"size": Vector2(0.07, 0.07),   "top": true,  "label": Vector2(0.0, 0.85), "w": 0.62},
	"stab_pack":    {"size": Vector2(0.116, 0.086), "top": true,  "label": Vector2(0.0, 0.3), "w": 0.8},
	"jar":          {"size": Vector2(0.161, 0.016), "top": false, "label": Vector2(0.0, 0.0), "w": 0.0},
	"poly_bag":     {"size": Vector2(0.136, 0.046), "top": true,  "label": Vector2(0.0, 0.0), "w": 0.9},
}
## Side colour and text colour per brand template.
const BRAND := {
	"keychorn": [Color("151517"), Color("f0eee8")], "kdbfans": [Color("8a6a48"), Color("1b1b1b")], "novelkays": [Color("f3f2ee"), Color("1d2a4f")],
	"modsonet": [Color("2a2a2d"), Color("d9c48a")], "ramma": [Color("e9e6df"), Color("55575b")], "kelovna": [Color("8a6a48"), Color("1f3b2a")],
	"acrylic": [Color("f3f2ee"), Color("1b1b1b")], "gnk": [Color("ecebe6"), Color("1b1b1b")], "eptb": [Color("f3f2ee"), Color("13233f")],
	"sp": [Color("f3f2ee"), Color("b3171a")], "kat": [Color("17181a"), Color("f0eee8")], "cherri": [Color("f3f2ee"), Color("1b1b1b")],
	"gateran": [Color("e2b420"), Color("141414")], "akco": [Color("cdbbe6"), Color("3a2d55")], "boutique": [Color("f3f2ee"), Color("1b1b1b")],
	"stab": [Color("17181a"), Color("f0eee8")], "kritoks": [Color("f3f2ee"), Color("1b1b1b")], "pcb_label": [Color("f3f2ee"), Color("1b1b1b")],
	"plate_label": [Color("f3f2ee"), Color("1b1b1b")],
}

## Templates with their own blank label: where the product name goes on the printed face (centre, -0.5..0.5, width).
const ART_LABEL := {"gateran": {"pos": Vector2(0.0, -0.39), "w": 0.55, "col": Color("1b1b1b")},
	"akco": {"pos": Vector2(-0.22, -0.375), "w": 0.44, "col": Color("3a2d55")},
	"novelkays": {"pos": Vector2(-0.36, 0.395), "w": 0.18, "col": Color("1d2a4f")}}
## Templates that already print the model name (one product per template): no extra label.
const ART_NAMED := ["keychorn", "ramma"]
static var _spec := {}
static var _print_cache := {}
static var _mats := {}

static func make(it: Dictionary) -> ItemBox:
	var n = ItemBox.new(); n._build(it); return n

static func pack_of(id: String) -> Dictionary:
	if _spec.is_empty():
		_spec = JSON.parse_string(FileAccess.get_file_as_string("res://data/packaging.json"))
	var items: Dictionary = _spec.items
	if items.has(id): return items[id]
	for k in items.keys():
		var ks := String(k)
		if ks.ends_with("*") and id.begins_with(ks.trim_suffix("*")): return items[k]
	return items["*"]

static func _shared(name: String, col: Color, rough := 0.6, extra := {}) -> StandardMaterial3D:
	var key = name + col.to_html()
	if _mats.has(key): return _mats[key]
	var m = StandardMaterial3D.new(); m.albedo_color = col; m.roughness = rough
	if extra.get("clear", false):
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS; m.metallic_specular = 0.8; m.roughness = 0.12
		m.albedo_color = Color(col.r, col.g, col.b, 0.28); m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if extra.has("tex"): m.albedo_texture = extra.tex
	_mats[key] = m
	return m

## The artwork on a face of the given aspect: fitted without stretching, the border pixels extend the margins.
const BAND := {"cherri": Vector2(0.80, 0.985)}
const BAND_SHADER := """
shader_type spatial;
uniform sampler2D tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 band_color : source_color = vec4(0.8, 0.2, 0.2, 1.0);
uniform vec2 band = vec2(0.8, 0.98);
uniform vec2 scale = vec2(1.0);
uniform vec2 offset = vec2(0.0);
void fragment() {
	vec2 uv = UV * scale + offset;
	vec3 c = texture(tex, uv).rgb;
	float in_band = step(band.x, uv.y) * step(uv.y, band.y);
	float grey = 1.0 - smoothstep(0.04, 0.12, max(max(c.r, c.g), c.b) - min(min(c.r, c.g), c.b));
	float txt = smoothstep(0.75, 0.9, dot(c, vec3(0.333)));          // keep the white text white
	ALBEDO = mix(c, band_color.rgb * (0.85 + 0.3 * c.r), in_band * grey * (1.0 - txt));
	ROUGHNESS = 0.55;
}
"""
static var _band_shader: Shader

## Print with a band recoloured to `col` (switch stem colour).
static func band_mat(art: String, kind: String, col: Color) -> Material:
	var base := print_mat(art, kind)
	if not BAND.has(art): return base
	if _band_shader == null: _band_shader = Shader.new(); _band_shader.code = BAND_SHADER
	var m = ShaderMaterial.new(); m.shader = _band_shader
	m.set_shader_parameter("tex", base.albedo_texture); m.set_shader_parameter("band_color", col); m.set_shader_parameter("band", BAND[art])
	m.set_shader_parameter("scale", Vector2(base.uv1_scale.x, base.uv1_scale.y)); m.set_shader_parameter("offset", Vector2(base.uv1_offset.x, base.uv1_offset.y))
	return m

static func print_mat(art: String, kind: String) -> StandardMaterial3D:
	var key = art + "|" + kind
	if _print_cache.has(key): return _print_cache[key]
	var path = "res://assets/tex/pack/%s.jpg" % art
	var m = StandardMaterial3D.new(); m.roughness = 0.55
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		m.albedo_texture = tex; m.texture_repeat = false
		var fa: Vector2 = FACE.get(kind, {"size": Vector2.ONE}).size
		var face_aspect = fa.x / max(fa.y, 0.001); var img_aspect = float(tex.get_width()) / float(tex.get_height())
		if kind == "jar": face_aspect = img_aspect
		if face_aspect > img_aspect:      # face wider than the art: show the art at full height, centred
			var sx = face_aspect / img_aspect
			m.uv1_scale = Vector3(sx, 1, 1); m.uv1_offset = Vector3(-(sx - 1.0) / 2.0, 0, 0)
		else:
			var sy = img_aspect / face_aspect
			m.uv1_scale = Vector3(1, sy, 1); m.uv1_offset = Vector3(0, -(sy - 1.0) / 2.0, 0)
	else:
		m.albedo_color = BRAND.get(art, [Color("ecebe6")])[0]
	_print_cache[key] = m
	return m

func _build(it: Dictionary) -> void:
	var cat: String = it.cat
	var id: String = str(it.id)
	var pk: Dictionary = pack_of(id)
	var kind: String = pk.kind; var art: String = pk.art
	var path = "res://assets/models/pack/%s.glb" % kind
	if not ResourceLoader.exists(path): return
	var body: Node3D = (load(path) as PackedScene).instantiate(); add_child(body)
	# boards and cases scale with the layout (a 100% case comes in a longer box)
	if it.has("layout") and cat in ["case", "plate", "pcb"]:
		body.scale.x = clamp(float(Data.LAYOUTS[it.layout].W) / 15.0, 0.9, 1.5)
	var brand: Array = BRAND.get(art, [Color("ecebe6"), Color("1b1b1b")])
	var stem := Color("c43a32")
	if cat == "sw": stem = _switch_colour(id)
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var sm = m.mesh.surface_get_material(i)
			var key = sm.resource_name if sm else ""
			var mat: Material = null
			match key:
				"pack_print": mat = band_mat(art, kind, stem) if cat == "sw" else print_mat(art, kind)
				"pack_side": mat = _shared("side", brand[0], 0.55)
				"pack_inner": mat = _shared("inner", Color("1d1e21"), 0.7)
				"kraft": mat = HMats.cardboard()
				"kraft_dark": mat = _shared("kraft_dark", Color("7d5d3d"), 0.85)
				"sticker": mat = _shared("sticker", Color("f2f1ec"), 0.6)
				"poly_clear", "zip": mat = _shared("poly", Color(0.92, 0.95, 1.0), 0.1, {"clear": true})
				"switch_house": mat = _shared("house", Color("1c1d22"), 0.35)
				"switch_stem": mat = _shared("stem", stem, 0.4)
				"jar_white": mat = _shared("jar", Color("f1f0ec"), 0.35)
				_:
					if RoomMats.has(key): mat = RoomMats.get_mat(key)
			if mat: m.set_surface_override_material(i, mat)
	if not art in ART_NAMED: _label(str(Data.item(cat, id).get("name", id)), kind, brand[1], body.scale.x, art)

func _label(text: String, kind: String, col: Color, sx: float, art := "") -> void:
	var f: Dictionary = FACE.get(kind, {}).duplicate()
	if ART_LABEL.has(art):
		f.label = ART_LABEL[art].pos; f.w = ART_LABEL[art].w; f.erase("on_top"); col = ART_LABEL[art].col
	if f.is_empty() or float(f.w) <= 0.0: return
	var l = Label3D.new(); l.text = text; l.font_size = 64; l.outline_size = 0; l.shaded = true; l.double_sided = false
	l.font = _label_font()
	l.modulate = col; l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var fs: Vector2 = f.size
	l.pixel_size = 0.00018 * clamp(fs.y / 0.1, 0.45, 1.3)
	l.width = fs.x * float(f.w) / l.pixel_size
	var lp: Vector2 = f.label
	var aabb := _aabb()
	if f.has("on_top"):
		var ts: Vector2 = f.on_top
		l.pixel_size = 0.00012; l.width = ts.x * 0.9 / l.pixel_size
		l.rotation_degrees = Vector3(-90, 0, 0); l.position = Vector3(0, aabb.end.y + 0.0012, 0.0)
	elif f.top:
		l.rotation_degrees = Vector3(-90, 0, 0)
		l.position = Vector3(lp.x * fs.x * sx, aabb.end.y + 0.0012, lp.y * fs.y)
	else:
		l.position = Vector3(lp.x * fs.x, aabb.size.y * 0.5 + lp.y * fs.y, aabb.end.z + 0.0012)
	add_child(l)

func _aabb() -> AABB:
	var a := AABB(); var first = true
	for mi in find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (mi as MeshInstance3D).get_aabb()
		b = (mi as MeshInstance3D).transform * b
		if first: a = b; first = false
		else: a = a.merge(b)
	return a

static var _font: Font
static func _label_font() -> Font:
	if _font == null:
		var sf = SystemFont.new(); sf.font_names = PackedStringArray(["Inter", "Segoe UI", "Arial"]); sf.font_weight = 700
		_font = sf
	return _font

static func _switch_colour(id: String) -> Color:
	for k in ["red", "black", "brown", "blue", "yellow", "milky", "silent", "panda", "box", "oil", "ink", "cream", "alpaca", "boba", "laven", "polar", "tang"]:
		if id.contains(k):
			return {"red": Color("c8302a"), "black": Color("1b1b1b"), "brown": Color("7a4a2a"), "blue": Color("2f5fc4"), "yellow": Color("e2b420"),
				"milky": Color("ece6d4"), "silent": Color("c8302a"), "panda": Color("e8c03a"), "box": Color("3aa56a"), "oil": Color("1d3f7a"),
				"ink": Color("1b1b1b"), "cream": Color("e8dcc0"), "alpaca": Color("e7a3c6"), "boba": Color("e8b75a"), "laven": Color("a98be0"),
				"polar": Color("dfe8f2"), "tang": Color("f08a24")}[k]
	return Color("c43a32")
