class_name RoomMats
## Shared material library of the flat. Blender (tools/blender/kit/core.py, MATS) names every material slot; here each
## name becomes ONE StandardMaterial3D used by every mesh that carries the slot, so the whole room needs only a few
## dozen materials. Meshes carry world-space UVs in metres, so `tile` (metres per texture repeat) sets the scale.
## Textures: assets/tex/room/<slot>_albedo.jpg (calibrated to the photos: tools/calibrate_scans.py, tools/tex_prep.py)
## + the CC0 scan's own normal / roughness / AO maps (assets/tex/scan/<scan>/, Poly Haven).

const ROOM := "res://assets/tex/room/"
const SCAN := "res://assets/tex/scan/"

## name: albedo slot (room/<x>_albedo.jpg) or "", scan folder for normal/rough/ao or "", tile metres,
## colour (tint or flat colour), roughness, metallic, normal strength, extra flags
const SPEC := {
	"wall_damask":    {"alb": "wall_damask", "own": "wall_damask", "tile": 1.06, "r": 0.85, "n": 0.6},
	"wall_mottle":    {"alb": "wall_mottle", "own": "wall_mottle", "tile": 1.0, "r": 0.86, "n": 0.5},
	"ceiling_field":  {"alb": "ceiling_field", "own": "ceiling_field", "tile": 1.4, "r": 0.5, "m": 0.25, "n": 0.4},
	"plaster_white":  {"alb": "plaster_white", "scan": "white_plaster_02", "tile": 1.6, "r": 0.8, "n": 0.35},
	"trim_white":     {"c": Color("e9e6df"), "r": 0.45, "scan": "white_plaster_02", "tile": 2.5, "n": 0.15},
	"floor_laminate": {"alb": "floor_laminate", "scan": "laminate_floor_02", "tile": 2.0, "r": 0.42, "n": 0.8, "rot": true},
	"wood_cream":     {"alb": "wood_cream", "scan": "washed_grey_oak_veneer", "tile": 1.2, "r": 0.48, "n": 0.6},
	"wood_cream_b":   {"alb": "wood_cream_b", "scan": "grey_oak_veneer_02", "tile": 1.2, "r": 0.48, "n": 0.6},
	"wood_maple":     {"alb": "wood_maple", "scan": "white_maple_veneer", "tile": 1.0, "r": 0.5, "n": 0.5},
	"wood_dark":      {"alb": "wood_dark", "scan": "walnut_veneer", "tile": 1.2, "r": 0.38, "n": 0.6},
	"wood_window":    {"alb": "wood_window", "scan": "walnut_veneer", "tile": 0.8, "r": 0.45, "n": 0.5},
	"door_neighbour": {"alb": "door_neighbour", "scan": "walnut_veneer", "tile": 1.0, "r": 0.45, "n": 0.5},
	"plywood":        {"alb": "plywood", "scan": "plywood", "tile": 1.0, "r": 0.7, "n": 0.6},
	"board_edge":     {"c": Color("dcd6ca"), "r": 0.45},
	"fabric_curtain": {"alb": "fabric_curtain", "scan": "cotton_jersey", "tile": 0.6, "r": 0.95, "n": 0.8, "two_sided": true},
	"fabric_plaid":   {"alb": "fabric_plaid", "scan": "fabric_pattern_05", "tile": 0.45, "r": 0.95, "n": 0.8},
	"fabric_linen":   {"alb": "fabric_linen", "scan": "rough_linen", "tile": 0.5, "r": 0.95, "n": 0.7},
	"leather_black":  {"alb": "leather_black", "scan": "fabric_leather_01", "tile": 0.5, "r": 0.5, "n": 0.8},
	"leather_red":    {"alb": "leather_red", "scan": "leather_red_02", "tile": 0.5, "r": 0.5, "n": 0.8},
	"wool_grey":      {"alb": "wool_grey", "scan": "wool_boucle", "tile": 0.4, "r": 0.95, "n": 1.0},
	"plaster_hall":   {"alb": "plaster_hall", "scan": "painted_plaster_wall", "tile": 1.5, "r": 0.8, "n": 0.6},
	"concrete":       {"c": Color("6c6862"), "r": 0.85, "scan": "painted_plaster_wall", "tile": 1.5, "n": 0.8},
	"gold":           {"c": Color("c9a45c"), "r": 0.3, "m": 1.0},
	"chrome":         {"c": Color("d2d4d8"), "r": 0.12, "m": 1.0},
	"steel_brushed":  {"c": Color("b4b7ba"), "r": 0.32, "m": 1.0},
	"black_plastic":  {"c": Color("121315"), "r": 0.42},
	"white_plastic":  {"c": Color("e8e7e3"), "r": 0.35},
	"rubber":         {"c": Color("0c0c0c"), "r": 0.85},
	"screen_black":   {"c": Color("050506"), "r": 0.08, "m": 0.3},
	"doormat":        {"c": Color("4a3b2c"), "r": 0.95, "scan": "wool_boucle", "tile": 0.3, "n": 1.0},
	"glow_white":     {"c": Color("fff4e4"), "emit": 3.5},
	"glass":          {"c": Color(0.85, 0.9, 0.92, 0.12), "r": 0.03, "glass": true},
	"fabric_pillow":  {"alb_path": "res://assets/tex/room/fabric_pillow_albedo.jpg", "c": Color("e4e4e2"), "scan": "rough_linen", "tile": 0.35, "r": 0.95, "n": 0.7},
	"fabric_white":   {"c": Color("eeeeec"), "scan": "rough_linen", "tile": 0.6, "r": 0.95, "n": 0.4, "two_sided": true},
	"rug_fringe":     {"c": Color("d6d0c2"), "r": 0.95},
	"glass_jar":      {"c": Color(0.9, 0.95, 1.0, 0.22), "r": 0.05, "glass": true},
	"glass_dark":     {"c": Color(0.08, 0.08, 0.09, 0.55), "r": 0.04, "glass": true},
	"jar_yellow":     {"c": Color("e7c33e"), "r": 0.5},
	"jar_blue":       {"c": Color("2f6fd6"), "r": 0.5},
	"fabric_mat":     {"c": Color("1e2124"), "r": 0.92, "scan": "rough_linen", "tile": 0.3, "n": 0.6},
	"cardboard_box":  {"c": Color("a57d52"), "r": 0.8},
	"key_white":      {"c": Color("eeece6"), "r": 0.45},
	"key_mint":       {"c": Color("a9e6d2"), "r": 0.45},
	"key_pink":       {"c": Color("f2b6c8"), "r": 0.45},
	"tape_roll":      {"c": Color(0.78, 0.62, 0.4, 0.75), "r": 0.25, "glass": true},
	"sticker_label":  {"c": Color("f4f3ef"), "r": 0.6},
	"bubble_wrap":    {"special": "bubble_wrap"},
	"brand_box":      {"special": "brand_box"},
	"ceramic_white":  {"c": Color("eeece6"), "r": 0.18},
	"soil":           {"c": Color("2a1f17"), "r": 0.95, "scan": "wool_boucle", "tile": 0.2, "n": 1.0},
	"fabric_black":   {"c": Color("161618"), "r": 0.9, "scan": "cotton_jersey", "tile": 0.5, "n": 0.9, "two_sided": true},
	"leaf_green":     {"special": "leaf", "c": Color("2f5a22")},
	"petal_white":    {"c": Color("eeeee6"), "r": 0.5, "two_sided": true},
	"spadix":         {"c": Color("e3d79a"), "r": 0.7},
	"bamboo":         {"c": Color("5d8a2c"), "r": 0.32},
	"bamboo_node":    {"c": Color("7f9a45"), "r": 0.4},
	"paper":          {"c": Color("e6e0d0"), "r": 0.8},
	"mesh_black":     {"c": Color("0b0b0c"), "r": 0.6},
	"red_plastic":    {"c": Color("b01818"), "r": 0.4},
	"glow_red":       {"c": Color("ff2a1e"), "emit": 2.5},
	"glow_rgb":       {"c": Color("b48cff"), "emit": 2.5},
	"book_red":       {"c": Color("7c1c17"), "r": 0.6},
	"book_navy":      {"c": Color("1d2a4f"), "r": 0.6},
	"book_green":     {"c": Color("1f4a2e"), "r": 0.6},
	"book_cream":     {"c": Color("dcd3bf"), "r": 0.65},
	"book_black":     {"c": Color("141416"), "r": 0.55},
	"book_orange":    {"c": Color("b45a1c"), "r": 0.6},
	"book_teal":      {"c": Color("1c5a5b"), "r": 0.6},
	"book_grey":      {"c": Color("6f7277"), "r": 0.6},
	"rug":            {"alb_path": "res://assets/tex/room/rug_albedo.jpg", "scan": "wool_boucle", "tile": 0.0, "r": 0.97, "n": 0.5},
}

static var _cache := {}

static func has(name: String) -> bool: return SPEC.has(name)

static func get_mat(name: String) -> Material:
	if _cache.has(name): return _cache[name]
	var s: Dictionary = SPEC.get(name, {})
	if s.get("special", "") == "bubble_wrap": _cache[name] = HMats.bubble_wrap(); return _cache[name]
	if s.get("special", "") == "brand_box": _cache[name] = HMats.brand_box(Color("16181b")); return _cache[name]
	if s.get("special", "") == "leaf":                   # glossy leaf, two-sided, light passing through (back-lighting)
		var lm = StandardMaterial3D.new(); lm.albedo_color = s.c; lm.roughness = 0.38; lm.cull_mode = BaseMaterial3D.CULL_DISABLED
		lm.backlight_enabled = true; lm.backlight = Color(0.25, 0.4, 0.1); lm.metallic_specular = 0.6
		_cache[name] = lm; return lm
	var m = StandardMaterial3D.new(); m.resource_name = name
	m.albedo_color = s.get("c", Color.WHITE)
	m.roughness = float(s.get("r", 0.5)); m.metallic = float(s.get("m", 0.0))
	var alb: String = ""
	if s.has("alb"): alb = ROOM + str(s.alb) + "_albedo.jpg"
	if s.has("alb_path"): alb = str(s.alb_path)
	if alb != "" and ResourceLoader.exists(alb): m.albedo_texture = load(alb)
	var nrm := ""; var rgh := ""; var ao := ""
	if s.has("own"):
		nrm = ROOM + str(s.own) + "_normal.png"; rgh = ROOM + str(s.own) + "_rough.jpg"
	elif s.has("scan"):
		nrm = SCAN + str(s.scan) + "/normal.png"; rgh = SCAN + str(s.scan) + "/rough.jpg"; ao = SCAN + str(s.scan) + "/ao.jpg"
		if not ResourceLoader.exists(nrm): nrm = SCAN + str(s.scan) + "/normal.jpg"
	if nrm != "" and ResourceLoader.exists(nrm):
		m.normal_enabled = true; m.normal_texture = load(nrm); m.normal_scale = float(s.get("n", 1.0))
	if rgh != "" and ResourceLoader.exists(rgh):
		m.roughness_texture = load(rgh); m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		m.roughness = clamp(float(s.get("r", 0.5)) * 1.6, 0.0, 1.0)     # texture ~0.6 average -> scale back to the slot's roughness
	if ao != "" and ResourceLoader.exists(ao):
		m.ao_enabled = true; m.ao_texture = load(ao); m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED; m.ao_light_affect = 0.3
	var tile: float = float(s.get("tile", 1.0))
	if tile > 0.0: m.uv1_scale = Vector3(1.0 / tile, 1.0 / tile, 1.0)
	if s.get("emit", 0.0) > 0.0:
		m.emission_enabled = true; m.emission = s.get("c", Color.WHITE); m.emission_energy_multiplier = float(s.emit)
	if s.get("glass", false):
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.metallic_specular = 0.9; m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if s.get("two_sided", false): m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_cache[name] = m
	return m

## Replaces every surface whose imported material is named like a library slot.
static func apply(root: Node) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null: continue
		for i in m.mesh.get_surface_count():
			var sm = m.mesh.surface_get_material(i)
			var key = sm.resource_name if sm else ""
			if SPEC.has(key): m.set_surface_override_material(i, get_mat(key))
