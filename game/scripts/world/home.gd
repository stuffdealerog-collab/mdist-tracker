class_name Home
extends Node3D
## The player's flat, modelled from the owner's photos (art/room/photo*.jpg). ALL geometry is one Blender scene
## (tools/blender/kit/build_room.py -> assets/room/room.glb) with a shared material library (RoomMats): walls with the
## real wallpapers, the three-tier ceiling, the window recess, the ornate door, every piece of furniture and prop.
## This script only binds behaviour by node names (door/wardrobe hinges, drawers, the monitor screen), adds colliders
## for interaction, lights, the time of day and the dynamic content (parcels, parts in the wardrobe / on the bench).
##
## World origin is the workbench top (the brown desk) where the keyboard sits; the floor is at F. Metres.
##   X0 window wall ........ X1 wardrobe wall          (room length along X)
##   Z0 desks + door wall ... Z1 bed + chest wall        (room width along Z)
## The door is in the Z0 wall; outside it (z < Z0) is the stairwell landing where couriers leave parcels.
## Layout constants MUST match tools/blender/kit/core.py.

const F := -0.76                 # floor height
const CEIL := F + 3.2
const X0 := -2.15
const X1 := 3.05
const Z0 := -0.62
const Z1 := 2.78
const DOOR_X := 2.4              # door centre along the Z0 wall
const DOOR_W := 0.9
const DOOR_H := 2.15
const NICHE := {"z0": 0.22, "z1": 1.28, "d": 0.34}           # window recess in the X0 wall (down to the floor)
const WIN := {"z0": 0.36, "z1": 1.14, "y0": F + 0.92, "y1": F + 2.72, "transom": F + 2.26}
const BENCH := {"x0": -1.0, "x1": 1.0, "zc": -0.24, "d": 0.76}
const UNBOX_SPOT := Vector3(0.64, 0.0, -0.2)
const PC_SPOT := Vector3(-1.545, -0.01, -0.36)
const PACK_SPOT := Vector3(0.64, F + 0.855, 2.47)                # top of the chest of drawers
const PACK_ROT := PI                                          # packing box faces the player standing at -Z
const WARD := {"x0": X1 - 0.6, "x1": X1, "z0": 1.2, "z1": 2.75, "h": 2.2}
const SHELF := {"x": X1 - 0.3, "z0": 1.24, "z1": 2.71, "levels": [F + 0.1, F + 0.56, F + 1.02, F + 1.48], "cols": 4}
const BED := {"x0": -2.08, "x1": -0.03, "z0": 1.83, "z1": 2.78}
const BED_EYE := Vector3(-1.78, F + 0.74, 2.3)
const WAKE_LOOK_A := Vector3(0.7, 1.0, -0.25)                # lying: up at the ceiling, towards the room
const WAKE_LOOK_B := Vector3(1.0, -0.12, -0.75)              # sitting up: across the room
const WAKE_SIT := Vector3(0.45, 0.3, -0.5)
const WAKE_POS := Vector3(-0.15, F, 1.35)
const ALARM_POS := Vector3(-1.9, F + 0.6, 2.7)

var sun: DirectionalLight3D
var chandelier: OmniLight3D
var desk_lamp: SpotLight3D       # kept for Workshop (quality settings); here: the ring light
var outside: MeshInstance3D
var landing_lamp: OmniLight3D
var env: Environment
var door_hinge: Node3D
var door_open := false
var ward_doors: Array = []
var ward_open := false
var monitor_screen: MeshInstance3D
var aquarium: Aquarium
var sky_light: SpotLight3D
var lightmap: LightmapGI          # baked indirect light (tools: tests/bake_export.tscn + addons/kss_bake), null when not baked
var _lm_day: LightmapGIData
var _lm_night: LightmapGIData
var _bake_root: Node3D
var _bake_pairs: Array = []         # [original MeshInstance3D, its mesh, lightmapped twin]
var baked := false                 # lightmap in use right now (Medium/Low graphics)
var monitor_vp: SubViewport
var parcels := {}                # id -> Parcel3D
var shelf_root: Node3D
var bench_root: Node3D
var _items_key := ""
var _par_key := ""

func _init(environment: Environment) -> void:
	env = environment

static func is_outside(pos: Vector3) -> bool: return pos.z < Z0 - 0.08

func _ready() -> void:
	name = "Home"
	_load_room()
	_window_outside()
	_landing_extras()
	_bench()
	_pc_desk()
	_stand_and_door_side()
	_far_wall()
	_wardrobe()
	_bed_wall()
	_chest()
	_lights()
	shelf_root = Node3D.new(); add_child(shelf_root)
	bench_root = Node3D.new(); add_child(bench_root)
	# reflection probes per zone (window/bed, middle/bench, wardrobe/door): box projected, captured once
	for zx in [[X0 - NICHE.d, -0.6], [-0.6, 1.4], [1.4, X1]]:
		var probe = ReflectionProbe.new(); probe.size = Vector3(zx[1] - zx[0], CEIL - F, Z1 - Z0)
		probe.position = Vector3((zx[0] + zx[1]) / 2.0, (F + CEIL) / 2.0, (Z0 + Z1) / 2.0); probe.origin_offset = Vector3(0, F + 1.3 - (F + CEIL) / 2.0, 0)
		probe.box_projection = true; probe.interior = true; probe.update_mode = ReflectionProbe.UPDATE_ONCE; probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
		probe.blend_distance = 0.4; add_child(probe)
	_apply_bake()
	Game.changed.connect(func(): sync())
	Game.parcel_arrived.connect(func(p): _on_arrived(p))
	Game.courier_came.connect(func(p): _on_pickup(p))
	sync()
	set_time(Game.clock_min())

# ------------------------------------------------------------------ baked lighting
const BAKE_SCENE := "res://bake/room_day.scn"
const BAKE_NIGHT := "res://bake/room_night.lmbake"

## Meshes that (almost) never move: the set that gets lightmap UV2 and baked indirect light. Parcels,
## shelf/bench items, the aquarium, the monitor, the sky quad and see-through or shader-driven surfaces stay real-time.
func bake_nodes() -> Array:
	var skip = [shelf_root, bench_root, aquarium]      # doors are closed most of the time: baked too, their lightmap moves with them
	var out = []
	_bake_collect(self, skip, out)
	return out

func _bake_collect(n: Node, skip: Array, out: Array) -> void:
	for c in n.get_children():
		if c in skip or c is Parcel3D or c.has_meta("keep") or c.is_queued_for_deletion(): continue
		if c is Node3D and not (c as Node3D).visible: continue
		if c is MeshInstance3D and (c as MeshInstance3D).mesh != null and _bakeable(c): out.append(c)
		_bake_collect(c, skip, out)

## Lights that bounce in the bake (all but the aquarium lid light). Only their bounce is baked: direct light and
## shadows stay real-time, so moving things (keyboards, parcels, doors) are lit exactly like the lightmapped room.
func bake_lights() -> Array:
	var out = []
	for l in find_children("*", "Light3D", true, false):
		if l != sun and not aquarium.is_ancestor_of(l): out.append(l)
	return out

func _bakeable(mi: MeshInstance3D) -> bool:
	# dense AI scans (chair, valet stand, plants) shatter into thousands of UV2 islands: they use the light probes
	var tris = 0
	if mi.mesh is ArrayMesh:
		for i in mi.mesh.get_surface_count(): tris += (mi.mesh as ArrayMesh).surface_get_array_index_len(i) / 3
	if tris > 40000: return false
	for i in mi.mesh.get_surface_count():
		var m = mi.get_active_material(i)
		if m is ShaderMaterial: return false
		if m is BaseMaterial3D and ((m as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or (m as BaseMaterial3D).shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED): return false
	return true

## Swaps the static meshes for their lightmapped twins from the baked scene (same transforms, UV2 meshes) and keeps
## the live materials, so time-of-day changes on materials still apply. Day and night bakes swap with the clock.
## Loads the bake (static meshes with UV2 + LightmapGI, live materials copied over). Used on Medium/Low graphics:
## the same warm bounce light at no cost. High keeps real-time SDFGI, which follows the time of day (the bake is fixed
## at 13:00 / 22:00). KSS_BAKE_ALWAYS forces it on High too, KSS_NOBAKE disables it.
func _apply_bake() -> void:
	if OS.has_environment("KSS_NOBAKE") or not ResourceLoader.exists(BAKE_SCENE): return
	var root: Node3D = (load(BAKE_SCENE) as PackedScene).instantiate()
	var lm: LightmapGI = root.get_node_or_null("LightmapGI")
	if lm == null or lm.light_data == null: root.free(); return
	var nodes = bake_nodes()
	if int(root.get_meta("count", -1)) != nodes.size():
		push_warning("[home] baked lighting is stale (%d vs %d meshes) - rebake: bash tools/bake_lighting.sh" % [root.get_meta("count", -1), nodes.size()])
		root.free(); return
	for b in root.get_node("Meshes").get_children():
		var o: MeshInstance3D = nodes[int(b.get_meta("src"))]
		b.material_override = o.material_override
		for i in o.mesh.get_surface_count():
			var sm = o.get_surface_override_material(i)
			b.set_surface_override_material(i, sm if sm else o.mesh.surface_get_material(i))
		b.cast_shadow = o.cast_shadow
		_bake_pairs.append([o, o.mesh, b])
	var bl = root.get_node_or_null("BakeLights")
	if bl: bl.free()
	root.visible = false; add_child(root)
	_bake_root = root; lightmap = lm; _lm_day = lm.light_data
	if ResourceLoader.exists(BAKE_NIGHT): _lm_night = load(BAKE_NIGHT)
	var q: String = str(Game.S.settings.get("gfx", "high")) if not Game.S.is_empty() else "high"
	if OS.has_environment("KSS_GFX"): q = OS.get_environment("KSS_GFX")
	set_baked(q != "high" or OS.has_environment("KSS_BAKE_ALWAYS"))

## Switches between the lightmapped twins and the original real-time meshes (graphics settings, live).
func set_baked(on: bool) -> void:
	if _bake_root == null: on = false
	if on == baked: return
	baked = on
	for p in _bake_pairs:
		(p[0] as MeshInstance3D).mesh = null if on else p[1]
	if _bake_root: _bake_root.visible = on
	print("[home] baked lighting %s (%d meshes)" % ["on" if on else "off", _bake_pairs.size()])

# ------------------------------------------------------------------ helpers
func _solid(size: Vector3, center: Vector3, id := "", rot_y := 0.0, parent: Node3D = null) -> StaticBody3D:
	var sb = StaticBody3D.new(); sb.position = center; sb.rotation.y = rot_y
	sb.collision_layer = 1 | (2 if id != "" else 0); sb.collision_mask = 0
	if id != "": sb.set_meta("ia", id)
	var cs = CollisionShape3D.new(); var bs = BoxShape3D.new(); bs.size = size; cs.shape = bs; sb.add_child(cs)
	(parent if parent else self).add_child(sb); return sb

func _target(size: Vector3, center: Vector3, id: String, parent: Node3D = null) -> StaticBody3D:
	var sb = _solid(size, center, id, 0.0, parent); sb.collision_layer = 2; return sb



# ------------------------------------------------------------------ the room (one Blender scene)
const ROOM_GLB := "res://assets/room/room.glb"
var room: Node3D

## The flat is ONE Blender scene (tools/blender/kit/build_room.py -> assets/room/room.glb), modelled to the photos.
## Meshes carry library material names (RoomMats), world-space UVs in metres and lightmap UV2; "-colonly" objects
## arrive as StaticBody3D colliders; moving parts (door leaf, wardrobe doors, drawers) have their origin at the hinge.
func _load_room() -> void:
	room = (load(ROOM_GLB) as PackedScene).instantiate(); room.name = "Room"; add_child(room)
	RoomMats.apply(room)
	for sb in room.find_children("*", "StaticBody3D", true, false):
		(sb as StaticBody3D).collision_layer = 1; (sb as StaticBody3D).collision_mask = 0
	for mi in room.find_children("*", "MeshInstance3D", true, false):
		if String(mi.name).contains("glass"): (mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# window glass: almost clear with a faint reflection, so the courtyard (and the night) reads through it
	var wg: MeshInstance3D = room.get_node_or_null("arch_window_glass")
	if wg:
		var gm = StandardMaterial3D.new(); gm.albedo_color = Color(0.9, 0.95, 1.0, 0.05); gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		gm.roughness = 0.12; gm.metallic_specular = 0.15; gm.cull_mode = BaseMaterial3D.CULL_DISABLED
		wg.material_override = gm
	door_hinge = room.get_node_or_null("door_leaf")
	if door_hinge:
		_solid(Vector3(DOOR_W - 0.01, DOOR_H, 0.05), Vector3((DOOR_W - 0.01) / 2.0, DOOR_H / 2.0, 0.0), "door", 0.0, door_hinge)

## What is seen through the window (sky / city by day, lights by night) and the curtain.
func _window_outside() -> void:
	var bx = X0 - NICHE.d
	var y0: float = WIN.y0; var y1: float = WIN.y1; var zc = (float(WIN.z0) + float(WIN.z1)) / 2.0
	var om = StandardMaterial3D.new(); om.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; om.albedo_texture = _view_tex(true)
	outside = MeshInstance3D.new(); var qm = QuadMesh.new(); qm.size = Vector2(6.3, 4.2); outside.mesh = qm     # 3:2 photo, faces +X
	outside.rotation_degrees = Vector3(0, 90, 0); outside.position = Vector3(bx - 3.0, (y0 + y1) / 2.0 + 0.3, zc); outside.material_override = om
	outside.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; outside.set_meta("keep", true); add_child(outside)

## The courtyard seen from the window (GPT Image, from the photo's view): day and night versions.
func _view_tex(day: bool) -> Texture2D:
	var p = "res://assets/tex/room/view_%s.jpg" % ("day" if day else "night")
	if ResourceLoader.exists(p): return load(p)
	return Mats.day_sky_tex() if day else Mats.city_night_tex()

func _landing_extras() -> void:
	var num = Label3D.new(); num.text = "47"; num.font_size = 64; num.pixel_size = 0.0018; num.modulate = Color("c9a45c"); num.position = Vector3(DOOR_X, F + 1.75, Z0 - 0.17)
	num.rotation.y = PI; add_child(num)
	landing_lamp = OmniLight3D.new(); landing_lamp.light_color = Color("ffe3b8"); landing_lamp.light_energy = 0.7; landing_lamp.omni_range = 3.0
	landing_lamp.position = Vector3(DOOR_X, CEIL - 0.6, Z0 - 0.9); landing_lamp.shadow_enabled = false; add_child(landing_lamp)

func toggle_door() -> void:
	set_door(not door_open)

func set_door(open: bool) -> void:
	if open == door_open or door_hinge == null: return
	door_open = open
	Audio.sfx("door", Vector3(DOOR_X, F + 1.0, Z0))
	var tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(door_hinge, "rotation:y", deg_to_rad(-100.0) if open else 0.0, 0.8)

## Spots on the landing where parcels are left (first on the doormat, then around it).
func door_slot_pos(i: int) -> Vector3:
	var xs = [0.0, -0.5, 0.5, -0.95, 0.95]
	var col = i % xs.size(); var row = i / xs.size()
	return Vector3(DOOR_X + xs[col], F, Z0 - 0.45 - row * 0.55)

# ------------------------------------------------------------------ desks
## The long brown desk = the workbench: walnut top with a black edge, a drawer pedestal on the left.
func _bench() -> void:
	var x0: float = BENCH.x0; var x1: float = BENCH.x1; var zc: float = BENCH.zc; var d: float = BENCH.d
	_solid(Vector3(x1 - x0, 0.78, d), Vector3((x0 + x1) / 2.0, F + 0.38, zc), "bench")
	var rgb = OmniLight3D.new(); rgb.light_color = Color("a07cff"); rgb.light_energy = 0.12; rgb.omni_range = 0.6; rgb.position = Vector3(-0.83, 0.25, -0.62); add_child(rgb)
	Audio.loop3d("pc_hum", "pc_hum", Vector3(-0.83, 0.2, -0.38), -2.0)
	# task light over the bench (warm spot from above the pegboard line)
	desk_lamp = SpotLight3D.new(); desk_lamp.light_color = Color("fff1dc"); desk_lamp.light_energy = 1.2; desk_lamp.spot_range = 2.6; desk_lamp.spot_angle = 40
	desk_lamp.shadow_enabled = true; desk_lamp.shadow_blur = 1.2; desk_lamp.light_size = 0.05
	add_child(desk_lamp); desk_lamp.look_at_from_position(Vector3(0.1, 0.95, -0.45), Vector3(0.1, 0, 0.02))

## White gaming desk with the monitor (KeyOS), keyboard, mouse and headphones; the red-black gaming chair.
func _pc_desk() -> void:
	var x = PC_SPOT.x; var w = 0.95; var d = 0.6; var zc = Z0 + d / 2.0
	_solid(Vector3(w, 0.76, d), Vector3(x, F + 0.38, zc), "pc")
	# the monitor's screen quad comes from room.glb; the game renders KeyOS into it
	monitor_vp = SubViewport.new(); monitor_vp.size = Vector2i(1280, 768); monitor_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	monitor_vp.transparent_bg = false; add_child(monitor_vp)
	var sm = StandardMaterial3D.new(); sm.albedo_color = Color.BLACK; sm.emission_enabled = true; sm.emission_energy_multiplier = 0.85
	sm.emission_texture = monitor_vp.get_texture(); sm.roughness = 0.15; sm.metallic_specular = 0.6
	monitor_screen = room.get_node_or_null("monitor_screen")
	if monitor_screen: monitor_screen.material_override = sm
	_target(Vector3(0.64, 0.4, 0.06), Vector3(x, PC_SPOT.y + 0.52, PC_SPOT.z - 0.04), "pc")
	_solid(Vector3(0.6, 1.2, 0.6), Vector3(x + 0.05, F + 0.6, 0.25))

## Cream stand with the 3D printer, ring light on its tripod.
func _stand_and_door_side() -> void:
	_solid(Vector3(0.45, 0.64, 0.45), Vector3(1.3, F + 0.32, Z0 + 0.23))
	_solid(Vector3(0.3, 1.8, 0.3), Vector3(1.66, F + 0.9, -0.32))

# ------------------------------------------------------------------ far wall
func _far_wall() -> void:
	_solid(Vector3(0.4, 1.2, 0.45), Vector3(X1 - 0.26, F + 0.6, 0.28))

## Three-door wardrobe: our storage. Doors swing open when you come for parts.
func _wardrobe() -> void:
	ward_doors.clear()
	for n in room.get_children():
		var nm := String(n.name)
		if nm.begins_with("ward_door_"):
			n.set_meta("dir", 1.0 if nm.ends_with("_L") else -1.0); ward_doors.append(n)
	ward_led = room.get_node_or_null("ward_led")
	ward_light = SpotLight3D.new(); ward_light.light_color = Color("fff1e0"); ward_light.light_energy = 0.0; ward_light.spot_range = 2.4
	ward_light.spot_angle = 70.0; ward_light.shadow_enabled = false; add_child(ward_light)
	ward_light.look_at_from_position(Vector3(WARD.x0 + 0.12, F + WARD.h - 0.06, (WARD.z0 + WARD.z1) / 2.0), Vector3(WARD.x0 + 0.35, F + 0.4, (WARD.z0 + WARD.z1) / 2.0))
	if ward_led: (ward_led as MeshInstance3D).set_surface_override_material(0, _ward_led_mat())
	_solid(Vector3(WARD.x1 - WARD.x0, WARD.h, WARD.z1 - WARD.z0), Vector3((WARD.x0 + WARD.x1) / 2.0, F + WARD.h / 2.0, (WARD.z0 + WARD.z1) / 2.0), "shelf")

var ward_led: Node3D
var ward_light: SpotLight3D
var _ward_led_m: StandardMaterial3D
func _ward_led_mat() -> StandardMaterial3D:
	_ward_led_m = RoomMats.get_mat("glow_white").duplicate(); _ward_led_m.emission_energy_multiplier = 0.0
	return _ward_led_m

func set_wardrobe(open: bool) -> void:
	if open == ward_open: return
	ward_open = open
	Audio.sfx("door", Vector3(WARD.x0, F + 1.0, (WARD.z0 + WARD.z1) / 2.0), -6.0)
	var k = 0
	for hinge in ward_doors:
		var dir: float = hinge.get_meta("dir")
		var tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_interval(0.08 * k); k += 1
		tw.tween_property(hinge, "rotation:y", (-dir * deg_to_rad(100.0)) if open else 0.0, 0.7)
	# the strip inside lights up as the doors open (like a real wardrobe LED with a door switch)
	var tl = create_tween().set_parallel(true)
	tl.tween_property(ward_light, "light_energy", 1.4 if open else 0.0, 0.35 if open else 0.2).set_delay(0.15 if open else 0.4)
	if _ward_led_m: tl.tween_property(_ward_led_m, "emission_energy_multiplier", 4.0 if open else 0.0, 0.3).set_delay(0.15 if open else 0.4)

## Chest drawers (room.glb "chest_drawer_<k>", k = 0 bottom .. 3 top, origin on the front face) slide out to -Z.
func set_drawer(k: int, open: bool) -> void:
	var d: Node3D = room.get_node_or_null("chest_drawer_%d" % k) if room else null
	if d == null: return
	if not d.has_meta("z0"): d.set_meta("z0", d.position.z)
	var tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(d, "position:z", float(d.get_meta("z0")) - (0.28 if open else 0.0), 0.45)
	Audio.sfx("tray", d.global_position, -8.0)

func shelf_slot_pos(i: int) -> Vector3:
	var cols: int = SHELF.cols; var order = [2, 1, 3, 0]; var lv: int = order[(i / cols) % order.size()]; var c = i % cols
	var dz: float = (float(SHELF.z1) - float(SHELF.z0)) / cols
	return Vector3(SHELF.x, float(SHELF.levels[lv]), float(SHELF.z0) + dz * (c + 0.5))

# ------------------------------------------------------------------ bed wall
func _bed_wall() -> void:
	var bx = (BED.x0 + BED.x1) / 2.0
	_solid(Vector3(BED.x1 - BED.x0, 0.62, 1.15), Vector3(bx, F + 0.31, Z1 - 0.6), "bed")

## Chest of drawers = the packing station; aquarium and lucky bamboo on top, the loudspeaker beside it.
func _chest() -> void:
	var cx = 0.85; var cz = Z1 - 0.3
	_solid(Vector3(1.0, 0.88, 0.58), Vector3(cx, F + 0.44, cz), "pack")
	aquarium = Aquarium.new(); aquarium.position = Vector3(1.14, PACK_SPOT.y, 2.56); aquarium.rotation.y = PI; aquarium.set_meta("keep", true); add_child(aquarium)
	# tape gun, label printer, bubble roll, flat mailers, pots: room.glb (tools/blender/kit/furn_props.py)
	_solid(Vector3(0.34, 0.64, 0.34), Vector3(2.15, F + 0.32, 2.52))

# ------------------------------------------------------------------ light
func _lights() -> void:
	sun = DirectionalLight3D.new(); sun.shadow_enabled = true; sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 10.0; sun.shadow_blur = 1.6; sun.light_angular_distance = 0.8; sun.light_volumetric_fog_energy = 2.0
	add_child(sun)
	# the LED chandelier itself is part of room.glb (tools/blender/kit/furn_living.py); its diffusers use "glow_white"
	var c = Vector3((X0 + X1) / 2.0, CEIL - 0.12, (Z0 + Z1) / 2.0)
	chandelier = OmniLight3D.new(); chandelier.light_color = Color("ffe9cc"); chandelier.omni_range = 7.5; chandelier.shadow_enabled = true; chandelier.light_size = 0.4
	chandelier.position = c + Vector3(0, -0.15, 0); add_child(chandelier)
	# skylight through the window: the key light of a daytime interior (soft, cool, wide, with soft shadows)
	sky_light = SpotLight3D.new(); sky_light.light_color = Color("dfe9ff"); sky_light.spot_range = 7.0; sky_light.spot_angle = 72.0
	sky_light.spot_angle_attenuation = 0.6; sky_light.spot_attenuation = 0.9; sky_light.shadow_enabled = true; sky_light.shadow_blur = 3.0
	sky_light.light_size = 0.6; sky_light.light_specular = 0.3; add_child(sky_light)
	var wz = (float(WIN.z0) + float(WIN.z1)) / 2.0
	sky_light.look_at_from_position(Vector3(X0 - NICHE.d + 0.12, WIN.y1 - 0.2, wz), Vector3(X0 + 2.2, F + 0.2, wz + 0.25))
	var fill = OmniLight3D.new(); fill.light_color = Color("dfe8f5"); fill.light_energy = 0.25; fill.omni_range = 8.0; fill.shadow_enabled = false; fill.light_specular = 0.05
	fill.position = Vector3(0.4, F + 1.6, 1.2); add_child(fill)

## Sun through the window (X0 wall), sky outside and the chandelier for the game time (minutes since midnight).
func set_time(m: float) -> void:
	var h = fposmod(m, 1440.0) / 60.0
	var day = clamp(smoothstep(6.5, 8.5, h) * (1.0 - smoothstep(19.0, 21.0, h)), 0.0, 1.0)
	var dusk = clamp(1.0 - abs(h - 19.5) / 1.8, 0.0, 1.0) + clamp(1.0 - abs(h - 7.2) / 1.2, 0.0, 1.0) * 0.6
	var el: float = lerp(10.0, 48.0, sin(clamp((h - 7.0) / 13.0, 0.0, 1.0) * PI))
	var az: float = lerp(-40.0, 40.0, clamp((h - 7.0) / 13.0, 0.0, 1.0))
	sun.rotation_degrees = Vector3(-el, -90.0 + az, 0)
	sun.light_color = Color("fff3e2").lerp(Color("ffb070"), clamp(dusk, 0.0, 1.0))
	sun.light_energy = 3.0 * day
	sun.visible = day > 0.02
	if sky_light:
		sky_light.light_energy = 2.2 * day * (1.0 - 0.5 * clamp(dusk, 0.0, 1.0))
		sky_light.light_color = Color("dfe9ff").lerp(Color("ffc9a0"), clamp(dusk, 0.0, 1.0))
		sky_light.visible = day > 0.02
	var om = outside.material_override as StandardMaterial3D
	om.albedo_color = Color(0.55, 0.6, 0.75).lerp(Color(1.25, 1.22, 1.18), day).lerp(Color(1.3, 0.9, 0.7), clamp(dusk, 0.0, 1.0) * day)
	om.albedo_texture = _view_tex(day > 0.04)
	var night = 1.0 - day
	if baked and _lm_night:
		var want = _lm_night if day < 0.35 else _lm_day
		if lightmap.light_data != want: lightmap.light_data = want
	chandelier.light_energy = lerp(1.25, 2.0, night)
	(RoomMats.get_mat("glow_white") as StandardMaterial3D).emission_energy_multiplier = lerp(3.5, 4.5, night)
	if env:
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color("9aa6b8").lerp(Color("c8d4e6"), day)
		env.ambient_light_energy = lerp(0.2, 0.36, day)

# ------------------------------------------------------------------ dynamic content
func parcel_pos(p: Dictionary) -> Vector3:
	match str(p.place):
		"door": return door_slot_pos(int(p.get("slot", 0)))
		"bench": return UNBOX_SPOT
		"pack": return PACK_SPOT + Vector3(0, 0, -0.05)
	var pos = p.get("pos")
	if pos is Array and pos.size() == 3: return Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	if pos is String: return Parcel3D._vec(pos)
	return Vector3(DOOR_X - 0.2, F, Z0 + 0.6)

## Rebuilds parcels, wardrobe boxes and bench items from the save (cheap: only when something changed).
func sync() -> void:
	var pk = ""
	for p in Game.S.parcels: pk += "%s:%s:%s:%s|" % [p.id, p.place, str(p.get("pos")), int(p.get("slot", 0))]
	if pk != _par_key:
		_par_key = pk
		var seen = {}
		for p in Game.S.parcels:
			seen[p.id] = true
			if p.place == "carry":
				if parcels.has(p.id) and parcels[p.id].get_parent() == self: parcels[p.id].queue_free(); parcels.erase(p.id)
				continue
			var n: Parcel3D = parcels.get(p.id)
			if n == null or not is_instance_valid(n):
				n = Parcel3D.new().setup(p); add_child(n); parcels[p.id] = n
			elif n.get_parent() != self: continue
			n.position = parcel_pos(p); n.rotation.y = float(p.get("rot", 0.0)) + (PACK_ROT if p.place == "pack" else 0.0)
		for id in parcels.keys():
			if not seen.has(id):
				var n = parcels[id]
				if is_instance_valid(n) and n.get_parent() == self: n.queue_free()
				parcels.erase(id)
	var ik = ""
	for it in Game.S.inv.items: ik += "%s:%s|" % [it.uid, Game.item_loc(it)]
	if ik != _items_key:
		_items_key = ik
		_build_items()

## Product boxes in the wardrobe (one per item) and parts lying on the bench between the PC and the keyboard.
func _build_items() -> void:
	for c in shelf_root.get_children(): c.queue_free()
	for c in bench_root.get_children(): c.queue_free()
	var si = 0; var bi = 0
	for it in Game.S.inv.items:
		var loc = Game.item_loc(it)
		var node = ItemBox.make(it)
		if loc == "shelf":
			var p = shelf_slot_pos(si); si += 1
			var stack = si > SHELF.cols * SHELF.levels.size()
			node.position = p + Vector3(randf_range(-0.03, 0.03), 0.0 if not stack else 0.12, 0); node.rotation.y = -PI / 2.0 + randf_range(-0.08, 0.08)
			node.scale = Vector3.ONE * 0.85
			shelf_root.add_child(node)
		elif loc == "bench":
			node.position = Vector3(-0.56 + (bi % 2) * 0.17, (bi / 6) * 0.06, -0.48 + ((bi / 2) % 3) * 0.17)
			node.rotation.y = randf_range(-0.2, 0.2); node.scale = Vector3.ONE * 0.75; bi += 1
			bench_root.add_child(node)

func _on_arrived(p: Dictionary) -> void:
	sync()
	var pos = door_slot_pos(int(p.get("slot", 0)))
	Audio.sfx("doorbell", Vector3(DOOR_X, F + 1.6, Z0 + 0.1))
	get_tree().create_timer(1.8).timeout.connect(func(): Audio.sfx("box_down", pos))
	var n: Parcel3D = parcels.get(p.id)
	if n: n.land()

func _on_pickup(p: Dictionary) -> void:
	Audio.sfx("knock", Vector3(DOOR_X, F + 1.3, Z0 - 0.05))
	sync()
