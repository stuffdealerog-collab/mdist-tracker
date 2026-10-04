class_name Workshop
extends Node3D
## The 3D room: desk, keyboard, lights, post FX, camera rig and 3D input.
## World units are metres; the keyboard node is scaled to key units.

signal key_down(i: int)
signal key_up(i: int)

const U := 0.01905

var kb: Keyboard3D
var asm: Asm
var cam: Camera3D
var env: Environment
var cam_attr: CameraAttributesPractical
var room: Node3D
var style := ""
var sun: DirectionalLight3D
var lamp: SpotLight3D
var probe: ReflectionProbe

# camera rig (spherical around target)
var orb := {"theta": -0.18, "phi": 0.92, "dist": 0.62, "target": Vector3(0, 0.01, 0.0)}
var orb_goal := {}
var fit_dist := 0.62
var frame_offset := 0.0      # horizontal screen shift (UI panel on the right)
var idle_spin := true
var _last_user := 0.0

# input
var mode := "view"           # view | asm | play
var _drag := {}
var _keys_down := {}
var _ptr_key := -1

func _ready() -> void:
	_build_env()
	room = Node3D.new(); room.name = "Room"; add_child(room)
	kb = Keyboard3D.new(); kb.name = "Keyboard"; kb.scale = Vector3.ONE * U; kb.rotation.x = 0.06
	kb.position = Vector3(0, 0.0045, 0)
	add_child(kb)
	asm = Asm.new(); asm.kb = kb; asm.name = "Asm"; add_child(asm)
	cam = Camera3D.new(); cam.fov = 38; cam.near = 0.02; cam.far = 40; cam.attributes = cam_attr; add_child(cam)
	orb_goal = orb.duplicate()
	set_style(str(Game.S.get("property", "garage")) if not Game.S.is_empty() else "garage")
	apply_quality()

# ------------------------------------------------------------- environment
func _build_env() -> void:
	var we := WorldEnvironment.new(); env = Environment.new()
	env.background_mode = Environment.BG_COLOR; env.background_color = Color("0b0d10")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color("8b97a6"); env.ambient_light_energy = 0.18
	env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	env.tonemap_mode = Environment.TONE_MAPPER_ACES; env.tonemap_exposure = 1.1; env.tonemap_white = 6.0
	env.ssao_enabled = true; env.ssao_radius = 0.06; env.ssao_intensity = 1.6; env.ssao_power = 1.4; env.ssao_detail = 0.6
	env.ssil_enabled = true; env.ssil_radius = 0.6; env.ssil_intensity = 0.8
	env.ssr_enabled = true; env.ssr_max_steps = 48; env.ssr_fade_in = 0.1; env.ssr_fade_out = 2.0
	env.glow_enabled = true; env.glow_intensity = 0.55; env.glow_bloom = 0.04; env.glow_hdr_threshold = 1.6; env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.set_glow_level(0, 0.0); env.set_glow_level(1, 1.0); env.set_glow_level(2, 0.6); env.set_glow_level(3, 0.4); env.set_glow_level(4, 0.2)
	env.volumetric_fog_enabled = true; env.volumetric_fog_density = 0.012; env.volumetric_fog_albedo = Color(1, 0.96, 0.9)
	env.volumetric_fog_length = 6.0; env.volumetric_fog_anisotropy = 0.6; env.volumetric_fog_ambient_inject = 0.05
	env.adjustment_enabled = true; env.adjustment_contrast = 1.06; env.adjustment_saturation = 1.08
	we.environment = env; add_child(we)
	cam_attr = CameraAttributesPractical.new()
	cam_attr.dof_blur_far_enabled = true; cam_attr.dof_blur_far_distance = 1.3; cam_attr.dof_blur_far_transition = 1.2; cam_attr.dof_blur_amount = 0.08
	cam_attr.dof_blur_near_enabled = false

func apply_quality() -> void:
	var q: String = str(Game.S.settings.get("gfx", "high")) if not Game.S.is_empty() else "high"
	if OS.has_environment("KSS_GFX"): q = OS.get_environment("KSS_GFX")
	var hi := q == "high"; var mid := q != "low"
	env.ssao_enabled = mid; env.ssil_enabled = hi; env.ssr_enabled = mid; env.volumetric_fog_enabled = mid
	env.sdfgi_enabled = hi and OS.get_name() != "Web"
	if env.sdfgi_enabled:
		env.sdfgi_use_occlusion = true; env.sdfgi_cascades = 4; env.sdfgi_min_cell_size = 0.02; env.sdfgi_energy = 0.9; env.sdfgi_bounce_feedback = 0.4
	cam_attr.dof_blur_far_enabled = mid
	get_viewport().msaa_3d = Viewport.MSAA_4X if hi else (Viewport.MSAA_2X if mid else Viewport.MSAA_DISABLED)
	get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if not hi else Viewport.SCREEN_SPACE_AA_DISABLED
	get_viewport().use_taa = hi
	RenderingServer.directional_shadow_atlas_set_size(4096 if hi else 2048, true)
	if sun: sun.shadow_enabled = true
	if lamp: lamp.shadow_enabled = mid

# -------------------------------------------------------------------- room
func set_style(st: String) -> void:
	var s: String = str(Data.prop(st).get("style", st))
	if s == style: return
	style = s
	for c in room.get_children(): c.queue_free()
	sun = null; lamp = null
	_build_desk()
	match style:
		"loft": _room_loft()
		"studio": _room_studio()
		"boutique": _room_boutique()
		"flagship": _room_flagship()
		_: _room_garage()
	_fill_lights()
	probe = ReflectionProbe.new(); probe.size = Vector3(4, 2.4, 3); probe.position = Vector3(0, 0.3, 0.2); probe.box_projection = true
	probe.update_mode = ReflectionProbe.UPDATE_ONCE; probe.interior = true; probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	room.add_child(probe)

## Soft fill from the camera side and the ceiling so rooms read clearly, plus a key rim on the desk.
func _fill_lights() -> void:
	var tint: Color = {"garage": Color("ffd9a8"), "loft": Color("e8f0ff"), "studio": Color("fff6ea"), "boutique": Color("ffd9a8"), "flagship": Color("c8b8ff")}.get(style, Color.WHITE)
	var e: float = {"garage": 0.55, "loft": 0.45, "studio": 0.5, "boutique": 0.75, "flagship": 0.6}.get(style, 0.5)
	var fill := OmniLight3D.new(); fill.light_color = tint; fill.light_energy = e; fill.omni_range = 7.0; fill.shadow_enabled = false
	fill.light_specular = 0.15; fill.position = Vector3(0.4, 1.5, 1.6); room.add_child(fill)
	var ceil_l := OmniLight3D.new(); ceil_l.light_color = tint; ceil_l.light_energy = e * 0.8; ceil_l.omni_range = 6.0; ceil_l.shadow_enabled = false
	ceil_l.position = Vector3(0, 1.9, -0.4); room.add_child(ceil_l)
	var rim := DirectionalLight3D.new(); rim.light_color = Color("9fc8ff") if style != "boutique" else Color("ffcf9a"); rim.light_energy = 0.35
	rim.rotation_degrees = Vector3(-25, 155, 0); rim.shadow_enabled = false; rim.light_specular = 0.8; room.add_child(rim)
	env.ambient_light_energy = max(env.ambient_light_energy, 0.25)

func _box(size: Vector3, pos: Vector3, mat: Material, r := 0.004) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if r > 0.0:
		mi.mesh = MeshGen.rounded_box(size.x, size.y, size.z, r); mi.position = pos - Vector3(0, size.y / 2.0, 0)
	else:
		var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; mi.position = pos
	mi.material_override = mat; room.add_child(mi); return mi

func _plane(size: Vector2, pos: Vector3, rot: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = size; mi.mesh = pm
	mi.position = pos; mi.rotation_degrees = rot; mi.material_override = mat; room.add_child(mi); return mi

func _build_desk() -> void:
	var wood := Mats.wood_tex(Color("7a5434") if style != "studio" else Color("c9a77c"))
	var dm := Mats.textured(wood, Vector3(2.5, 2.5, 2.5), 0.5)
	dm.clearcoat_enabled = true; dm.clearcoat = 0.3; dm.clearcoat_roughness = 0.35
	_box(Vector3(2.0, 0.04, 0.95), Vector3(0, -0.0, 0.05), dm, 0.006)
	for sx in [-0.95, 0.95]:
		for sz in [-0.38, 0.45]:
			_box(Vector3(0.05, 0.72, 0.05), Vector3(sx, -0.04, sz), Mats.std(Color("26282b"), 0.5, 0.8), 0.0).position.y = -0.4
	# desk mat
	var mat_col: Color = {"garage": Color("1a1d21"), "loft": Color("3a4048"), "studio": Color("2c3e50"), "boutique": Color("2b1f1a"), "flagship": Color("15131c")}.get(style, Color("1a1d21"))
	var fm := Mats.textured(Mats.fabric_tex(mat_col), Vector3(14, 14, 14), 0.95, false)
	var mat := MeshInstance3D.new(); mat.mesh = MeshGen.slab(0.9, 0.4, 0.003, 0.02); mat.material_override = fm; mat.position = Vector3(0, 0.0, 0.04); room.add_child(mat)
	# stitched edge
	var edge := MeshInstance3D.new(); edge.mesh = MeshGen.slab(0.904, 0.404, 0.0028, 0.022); edge.material_override = Mats.std(mat_col.lightened(0.15), 0.8); edge.position = Vector3(0, -0.0001, 0.04); room.add_child(edge)
	_desk_props()

func _desk_props() -> void:
	# mug
	var mug := MeshInstance3D.new(); var cy := CylinderMesh.new(); cy.top_radius = 0.042; cy.bottom_radius = 0.04; cy.height = 0.095; cy.radial_segments = 32
	mug.mesh = cy; mug.material_override = Mats.std(Color("e9e4da"), 0.25); mug.position = Vector3(0.52, 0.048, -0.12); room.add_child(mug)
	var coffee := MeshInstance3D.new(); var cc := CylinderMesh.new(); cc.top_radius = 0.037; cc.bottom_radius = 0.037; cc.height = 0.002
	coffee.mesh = cc; coffee.material_override = Mats.std(Color("2a160b"), 0.1); coffee.position = Vector3(0.52, 0.088, -0.12); room.add_child(coffee)
	var handle := MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = 0.018; tm.outer_radius = 0.027
	handle.mesh = tm; handle.material_override = mug.material_override; handle.position = Vector3(0.565, 0.05, -0.12); handle.rotation_degrees = Vector3(90, 0, 0); room.add_child(handle)
	# switch jars
	for i in 3:
		var jar := MeshInstance3D.new(); var jc := CylinderMesh.new(); jc.top_radius = 0.028; jc.bottom_radius = 0.028; jc.height = 0.07
		jar.mesh = jc
		var jm := StandardMaterial3D.new(); jm.albedo_color = Color(0.9, 0.95, 1.0, 0.25); jm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS; jm.roughness = 0.05; jm.metallic_specular = 0.9
		jar.material_override = jm; jar.position = Vector3(-0.5 + i * 0.07, 0.035, -0.2); room.add_child(jar)
		var fill := MeshInstance3D.new(); var fc := CylinderMesh.new(); fc.top_radius = 0.025; fc.bottom_radius = 0.025; fc.height = 0.04
		fill.mesh = fc; fill.material_override = Mats.std([Color("d9423b"), Color("e7c33e"), Color("2f6fd6")][i], 0.5); fill.position = Vector3(-0.5 + i * 0.07, 0.021, -0.2); room.add_child(fill)
		var lid := MeshInstance3D.new(); var lc := CylinderMesh.new(); lc.top_radius = 0.029; lc.bottom_radius = 0.029; lc.height = 0.01
		lid.mesh = lc; lid.material_override = Mats.std(Color("1d1f22"), 0.4); lid.position = Vector3(-0.5 + i * 0.07, 0.075, -0.2); room.add_child(lid)
	# tweezers and keycap puller
	var tw := _box(Vector3(0.11, 0.004, 0.008), Vector3(0.38, 0.004, 0.17), Mats.std(Color("c9ccd0"), 0.2, 0.95), 0.002); tw.rotation_degrees.y = 25
	var pl := _box(Vector3(0.07, 0.012, 0.025), Vector3(-0.42, 0.012, 0.15), Mats.std(Color("d9423b"), 0.5), 0.004); pl.rotation_degrees.y = -15
	# small parts tray
	var tray := _box(Vector3(0.16, 0.018, 0.1), Vector3(-0.62, 0.018, 0.02), Mats.std(Color("2a2f36"), 0.6), 0.006)
	tray.rotation_degrees.y = 8
	for i in 8:
		var p := MeshInstance3D.new(); p.mesh = MeshGen.keycap_final(1.0, "sa", 2); p.scale = Vector3.ONE * U
		p.set_surface_override_material(0, Mats.cap_side()); p.set_surface_override_material(1, Mats.cap_top())
		p.set_instance_shader_parameter("base_color", Color.from_hsv(i * 0.12, 0.45, 0.9)); p.set_instance_shader_parameter("rough", 0.4)
		p.position = Vector3(-0.68 + (i % 4) * 0.022, 0.02, -0.005 + (i / 4) * 0.025); p.rotation_degrees.y = randf() * 30
		room.add_child(p)
	# monitor at the back
	var mon := _box(Vector3(0.62, 0.36, 0.02), Vector3(-0.05, 0.42, -0.36), Mats.std(Color("101114"), 0.3, 0.3), 0.008)
	var scr := _plane(Vector2(0.6, 0.34), Vector3(-0.05, 0.42 - 0.18 + 0.0, -0.349), Vector3(90, 0, 0), _screen_mat())
	scr.position.y = 0.24
	var stand := _box(Vector3(0.04, 0.24, 0.03), Vector3(-0.05, 0.24, -0.37), Mats.std(Color("2a2c30"), 0.3, 0.8), 0.006)
	var foot := _box(Vector3(0.22, 0.008, 0.14), Vector3(-0.05, 0.008, -0.34), Mats.std(Color("2a2c30"), 0.3, 0.8), 0.004)

func _screen_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = Color.BLACK; m.emission_enabled = true
	var img := Image.create(320, 180, false, Image.FORMAT_RGB8); img.fill(Color("0f1720"))
	var rng := RandomNumberGenerator.new(); rng.seed = 3
	img.fill_rect(Rect2i(0, 0, 320, 14), Color("1d2a36"))
	for i in 18:
		img.fill_rect(Rect2i(12, 22 + i * 8, rng.randi_range(40, 220), 3), [Color("4cb8ab"), Color("ebc66c"), Color("8fa3b8"), Color("ff8160")][rng.randi() % 4])
	img.fill_rect(Rect2i(240, 24, 70, 70), Color("1d2a36"))
	for i in 6: img.fill_rect(Rect2i(246 + i * 11, 84 - i * 8, 7, 8 + i * 8), Color("4cb8ab"))
	m.emission_texture = ImageTexture.create_from_image(img); m.emission_energy_multiplier = 0.9
	return m

func _sun(dir_deg: Vector3, col: Color, energy: float) -> void:
	sun = DirectionalLight3D.new(); sun.rotation_degrees = dir_deg; sun.light_color = col; sun.light_energy = energy
	sun.shadow_enabled = true; sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS; sun.directional_shadow_max_distance = 6.0
	sun.shadow_blur = 1.5; sun.light_angular_distance = 1.2; sun.light_volumetric_fog_energy = 1.5
	room.add_child(sun)

func _desk_lamp(col: Color, energy: float, pos := Vector3(-0.42, 0.62, 0.08)) -> void:
	# arm + head
	var mm := Mats.std(Color("1d1f22"), 0.35, 0.7)
	_box(Vector3(0.12, 0.012, 0.12), Vector3(-0.62, 0.012, -0.22), mm, 0.004)
	var arm := MeshInstance3D.new(); var cy := CylinderMesh.new(); cy.top_radius = 0.007; cy.bottom_radius = 0.007; cy.height = 0.7
	arm.mesh = cy; arm.material_override = mm; arm.position = Vector3(-0.55, 0.33, -0.08); arm.rotation_degrees = Vector3(20, 0, -14); room.add_child(arm)
	var head := MeshInstance3D.new(); var hc := CylinderMesh.new(); hc.top_radius = 0.025; hc.bottom_radius = 0.065; hc.height = 0.08; hc.radial_segments = 32
	head.mesh = hc; head.material_override = mm; head.position = pos + Vector3(0, 0.03, 0); head.look_at_from_position(head.position, Vector3(0, 0, 0.02)); head.rotate_object_local(Vector3.RIGHT, -PI / 2); room.add_child(head)
	var bulb := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.03; sm.height = 0.04
	bulb.mesh = sm; bulb.material_override = Mats.emissive(col, 6.0); bulb.position = pos; room.add_child(bulb)
	lamp = SpotLight3D.new(); lamp.light_color = col; lamp.light_energy = energy; lamp.spot_range = 2.5; lamp.spot_angle = 42; lamp.spot_angle_attenuation = 0.7
	lamp.shadow_enabled = true; lamp.shadow_blur = 1.2; lamp.light_size = 0.04; lamp.light_volumetric_fog_energy = 2.0
	room.add_child(lamp); lamp.look_at_from_position(pos, Vector3(0.0, 0, 0.05))

func _walls(wall_mat: Material, floor_mat: Material, ceil_col := Color("1a1b1d")) -> void:
	_plane(Vector2(8, 8), Vector3(0, -0.76, 0), Vector3.ZERO, floor_mat)
	_plane(Vector2(8, 4), Vector3(0, 0.5, -1.1), Vector3(90, 0, 0), wall_mat)
	_plane(Vector2(6, 4), Vector3(-2.2, 0.5, 0.5), Vector3(90, 90, 0), wall_mat)
	_plane(Vector2(6, 4), Vector3(2.2, 0.5, 0.5), Vector3(90, -90, 0), wall_mat)
	_plane(Vector2(8, 8), Vector3(0, 2.1, 0), Vector3(180, 0, 0), Mats.std(ceil_col, 0.9))
	_plane(Vector2(8, 4), Vector3(0, 0.5, 3.2), Vector3(-90, 0, 0), wall_mat)

func _shelf(x: float, y: float, w: float, boards := 3, col := Color("6b4a2e")) -> void:
	var sm := Mats.textured(Mats.wood_tex(col), Vector3(2, 2, 2), 0.6)
	_box(Vector3(w, 0.025, 0.22), Vector3(x, y, -0.98), sm, 0.004)
	for b in [-1, 1]:
		_box(Vector3(0.02, 0.06, 0.18), Vector3(x + b * (w / 2.0 - 0.1), y - 0.025, -0.99), Mats.std(Color("26282b"), 0.4, 0.8), 0.0).position.y = y - 0.045
	var rng := RandomNumberGenerator.new(); rng.seed = int(x * 100 + y * 10)
	var px := x - w / 2.0 + 0.08
	for i in boards:
		var bw := rng.randf_range(0.28, 0.44); var bh := rng.randf_range(0.05, 0.08)
		var col2: Color = [Color("e9e4da"), Color("1d1f22"), Color("c9a77c"), Color("2c3e50"), Color("8a2f2f")][rng.randi() % 5]
		if px + bw > x + w / 2.0 - 0.04: break
		var bx := _box(Vector3(bw, bh, 0.16), Vector3(px + bw / 2.0, y + 0.0125 + bh, -0.98), Mats.std(col2, 0.7), 0.003)
		var lab := _box(Vector3(bw * 0.5, 0.002, 0.07), Vector3(px + bw / 2.0, y + 0.0125 + bh + 0.002, -0.98), Mats.std(Color("ff8160") if rng.randf() < 0.5 else Color("4cb8ab"), 0.5), 0.0)
		px += bw + 0.03

func _window(x: float, w: float, h: float, tex: Texture2D, energy: float, wall_z := -1.095) -> void:
	var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.albedo_texture = tex; m.albedo_color = Color(energy, energy, energy)
	_plane(Vector2(w, h), Vector3(x, 0.75, wall_z), Vector3(90, 0, 0), m)
	var fr := Mats.std(Color("1b1c1e"), 0.5, 0.6)
	_box(Vector3(w + 0.08, 0.05, 0.06), Vector3(x, 0.75 + h / 2.0 + 0.025, wall_z + 0.02), fr, 0.0)
	_box(Vector3(w + 0.08, 0.05, 0.12), Vector3(x, 0.75 - h / 2.0 - 0.025, wall_z + 0.04), fr, 0.0)
	_box(Vector3(0.04, h, 0.05), Vector3(x, 0.75, wall_z + 0.02), fr, 0.0)
	_box(Vector3(0.04, h, 0.05), Vector3(x - w / 2.0 - 0.02, 0.75, wall_z + 0.02), fr, 0.0)
	_box(Vector3(0.04, h, 0.05), Vector3(x + w / 2.0 + 0.02, 0.75, wall_z + 0.02), fr, 0.0)
	_box(Vector3(w, 0.03, 0.04), Vector3(x, 0.75, wall_z + 0.02), fr, 0.0)

func _room_garage() -> void:
	var conc := Mats.textured(Mats.concrete_tex(Color("7d7b77")), Vector3(0.6, 0.6, 0.6), 0.9)
	var floor_m := Mats.textured(Mats.concrete_tex(Color("5f5e5b")), Vector3(0.5, 0.5, 0.5), 0.75)
	_walls(conc, floor_m)
	# pegboard with tools
	var peg := Mats.textured(Mats.pegboard_tex(), Vector3(3, 2, 1), 0.85, false)
	var pb := _plane(Vector2(1.6, 0.8), Vector3(0, 0.65, -1.08), Vector3(90, 0, 0), peg)
	(pb.mesh as PlaneMesh).size = Vector2(1.6, 0.8)
	var tm := Mats.std(Color("b9bec4"), 0.3, 0.9)
	for i in 6:
		var t := _box(Vector3(0.02, 0.22 + (i % 3) * 0.05, 0.01), Vector3(-0.6 + i * 0.22, 0.62, -1.07), tm if i % 2 == 0 else Mats.std(Color("d9423b"), 0.5), 0.004)
	_shelf(1.0, 0.25, 0.8, 2, Color("5a5a5a"))
	# bare bulb
	var bulb := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.04; sm.height = 0.1
	bulb.mesh = sm; bulb.material_override = Mats.emissive(Color("ffd9a0"), 8.0); bulb.position = Vector3(0.2, 1.6, -0.2); room.add_child(bulb)
	var cord := _box(Vector3(0.004, 0.5, 0.004), Vector3(0.2, 1.9, -0.2), Mats.std(Color("111111"), 0.8), 0.0)
	var ol := OmniLight3D.new(); ol.light_color = Color("ffcf8f"); ol.light_energy = 1.3; ol.omni_range = 5; ol.shadow_enabled = true; ol.position = Vector3(0.2, 1.55, -0.2); room.add_child(ol)
	_desk_lamp(Color("ffe2bb"), 1.6)
	_sun(Vector3(-40, 60, 0), Color("9fb9d9"), 0.25)
	env.ambient_light_color = Color("8a8f98"); env.ambient_light_energy = 0.12; env.background_color = Color("0b0c0d")

func _room_loft() -> void:
	var brick := Mats.textured(Mats.brick_tex(), Vector3(0.7, 0.7, 0.7), 0.9)
	var floor_m := Mats.textured(Mats.planks_tex(Color("6e4b2f")), Vector3(0.4, 0.4, 0.4), 0.55)
	_walls(brick, floor_m, Color("2a2a2a"))
	_window(-0.7, 1.1, 1.1, Mats.day_sky_tex(), 2.6)
	_window(0.8, 0.9, 1.1, Mats.day_sky_tex(), 2.6)
	_shelf(0.85, 0.3, 1.0, 3)
	_shelf(0.85, 0.65, 1.0, 3)
	_plant(Vector3(-1.3, -0.76, -0.8))
	_desk_lamp(Color("ffe8cc"), 1.0)
	_sun(Vector3(-28, 25, 0), Color("ffeedd"), 1.6)
	env.ambient_light_color = Color("b5c4d6"); env.ambient_light_energy = 0.3; env.background_color = Color("cfdbe6")

func _room_studio() -> void:
	var wm := Mats.std(Color("e8e6e1"), 0.85)
	var floor_m := Mats.textured(Mats.planks_tex(Color("b08a62")), Vector3(0.4, 0.4, 0.4), 0.45)
	_walls(wm, floor_m, Color("f2f2f0"))
	_window(-0.9, 0.9, 1.0, Mats.day_sky_tex(), 2.2)
	_shelf(0.5, 0.35, 1.4, 4, Color("d6b48a"))
	_shelf(0.5, 0.7, 1.4, 4, Color("d6b48a"))
	_neon("KSS", Vector3(0.55, 1.15, -1.08), Color("4cb8ab"))
	var strip := _box(Vector3(1.4, 0.006, 0.01), Vector3(0.5, 0.335, -0.9), Mats.emissive(Color("fff1dc"), 4.0), 0.0)
	_plant(Vector3(-1.4, -0.76, -0.7))
	_desk_lamp(Color("fff4e6"), 0.9)
	_sun(Vector3(-35, 30, 0), Color("fff6ea"), 1.3)
	env.ambient_light_color = Color("dfe6ee"); env.ambient_light_energy = 0.4; env.background_color = Color("e9eef3")

func _room_boutique() -> void:
	var wm := Mats.std(Color("23382e"), 0.8)
	var floor_m := Mats.textured(Mats.planks_tex(Color("3a2416")), Vector3(0.4, 0.4, 0.4), 0.35)
	_walls(wm, floor_m, Color("16120e"))
	# wainscot
	var wn := Mats.textured(Mats.wood_tex(Color("4a2e1c")), Vector3(1, 1, 1), 0.45)
	_box(Vector3(4.4, 0.9, 0.03), Vector3(0, -0.31, -1.085), wn, 0.0)
	_shelf(-0.6, 0.4, 1.0, 3, Color("4a2e1c"))
	_shelf(0.7, 0.4, 1.0, 3, Color("4a2e1c"))
	_glass_case(Vector3(1.35, -0.25, -0.5))
	for x in [-0.6, 0.0, 0.6]:
		var sl := SpotLight3D.new(); sl.light_color = Color("ffd59a"); sl.light_energy = 2.0; sl.spot_range = 3.0; sl.spot_angle = 25
		sl.shadow_enabled = false; room.add_child(sl); sl.look_at_from_position(Vector3(x, 2.0, -0.6), Vector3(x, 0.3, -1.0))
	_neon("кастом", Vector3(-0.1, 1.2, -1.08), Color("ebc66c"))
	_desk_lamp(Color("ffd7a8"), 1.0)
	env.ambient_light_color = Color("806a55"); env.ambient_light_energy = 0.18; env.background_color = Color("0f0c0a")

func _room_flagship() -> void:
	var wm := Mats.std(Color("15161c"), 0.6, 0.1)
	var floor_m := Mats.std(Color("101114"), 0.15, 0.0)
	_walls(wm, floor_m, Color("0b0b0e"))
	_window(0.0, 3.2, 1.3, Mats.city_night_tex(), 1.4)
	_glass_case(Vector3(-1.4, -0.25, -0.4))
	_glass_case(Vector3(1.4, -0.25, -0.4))
	_neon("KEYBOARD SELLER", Vector3(0, 1.62, -1.06), Color("ff5ad1"))
	var strip := _box(Vector3(2.0, 0.006, 0.01), Vector3(0, 0.0, 0.52), Mats.emissive(Color("7a5cff"), 3.0), 0.0)
	_desk_lamp(Color("e6ecff"), 1.0)
	_sun(Vector3(-20, 0, 0), Color("8aa0ff"), 0.15)
	env.ambient_light_color = Color("5a5f80"); env.ambient_light_energy = 0.2; env.background_color = Color("06070a")

func _plant(pos: Vector3) -> void:
	var pot := MeshInstance3D.new(); var cy := CylinderMesh.new(); cy.top_radius = 0.16; cy.bottom_radius = 0.12; cy.height = 0.32
	pot.mesh = cy; pot.material_override = Mats.std(Color("c06b4a"), 0.8); pot.position = pos + Vector3(0, 0.16, 0); room.add_child(pot)
	var leaf := Mats.std(Color("3f7a3a"), 0.6)
	var rng := RandomNumberGenerator.new(); rng.seed = 4
	for i in 14:
		var l := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.12; sm.height = 0.04
		l.mesh = sm; l.material_override = leaf
		var a := i * 0.9; var h := rng.randf_range(0.4, 0.9)
		l.position = pos + Vector3(cos(a) * 0.14, h, sin(a) * 0.14); l.rotation = Vector3(rng.randf_range(-0.8, 0.8), a, rng.randf_range(-0.6, 0.6))
		room.add_child(l)

func _neon(txt: String, pos: Vector3, col: Color) -> void:
	var l := Label3D.new(); l.text = txt; l.font = load("res://assets/fonts/Tektur.ttf"); l.font_size = 160; l.pixel_size = 0.0018
	l.modulate = col * 3.0; l.outline_size = 0; l.position = pos; l.shaded = false; l.double_sided = false
	room.add_child(l)
	var ol := OmniLight3D.new(); ol.light_color = col; ol.light_energy = 0.8; ol.omni_range = 1.6; ol.position = pos + Vector3(0, 0, 0.2); room.add_child(ol)

func _glass_case(pos: Vector3) -> void:
	var base := _box(Vector3(0.5, 0.9, 0.5), pos + Vector3(0, 0.45, 0), Mats.std(Color("1a1b1f"), 0.4, 0.3), 0.01)
	var gm := StandardMaterial3D.new(); gm.albedo_color = Color(0.85, 0.9, 1.0, 0.12); gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; gm.roughness = 0.02; gm.metallic_specular = 1.0
	var glass := _box(Vector3(0.48, 0.3, 0.48), pos + Vector3(0, 0.9 + 0.3, 0), gm, 0.0)
	glass.position.y = pos.y + 0.9 + 0.15
	var ol := OmniLight3D.new(); ol.light_color = Color("fff1dc"); ol.light_energy = 0.4; ol.omni_range = 0.6; ol.position = pos + Vector3(0, 1.15, 0); room.add_child(ol)

# ------------------------------------------------------------------ camera
func set_view(v: String) -> void:
	_last_user = Time.get_ticks_msec()
	match v:
		"top": orb_goal.phi = 0.12; orb_goal.theta = 0.0; orb_goal.dist = fit_dist * 0.95
		"persp": orb_goal.phi = 0.92; orb_goal.theta = -0.18; orb_goal.dist = fit_dist
		"front": orb_goal.phi = 1.25; orb_goal.theta = 0.0; orb_goal.dist = fit_dist * 0.8
		"close": orb_goal.phi = 0.78; orb_goal.theta = -0.35; orb_goal.dist = fit_dist * 0.55
		"left": orb_goal.theta += 0.45
		"right": orb_goal.theta -= 0.45
		"in": orb_goal.dist = max(fit_dist * 0.35, orb_goal.dist * 0.82)
		"out": orb_goal.dist = min(fit_dist * 2.2, orb_goal.dist * 1.2)
		"room": orb_goal.phi = 1.12; orb_goal.theta = -0.4; orb_goal.dist = 2.0
		"hero": orb_goal.phi = 1.05; orb_goal.theta = -0.55; orb_goal.dist = fit_dist * 0.75

func fit_keyboard() -> void:
	if kb.L.is_empty(): return
	var w: float = (kb.W + 2.0) * U
	var vp := get_viewport().get_visible_rect().size
	var asp: float = max(0.5, vp.x / max(1.0, vp.y)) * 0.68
	var t := tan(deg_to_rad(cam.fov / 2.0))
	fit_dist = max(w / (2.0 * t * asp), (kb.H + 3.0) * U / (2.0 * t)) * 1.05
	orb_goal.dist = fit_dist

func _update_cam(dt: float) -> void:
	if idle_spin and mode == "view" and Time.get_ticks_msec() - _last_user > 9000:
		orb_goal.theta += dt * 0.06
	var k := 1.0 - exp(-dt * 7.0)
	orb.theta = lerp(float(orb.theta), float(orb_goal.theta), k)
	orb.phi = lerp(float(orb.phi), float(orb_goal.phi), k)
	orb.dist = lerp(float(orb.dist), float(orb_goal.dist), k)
	orb.target = (orb.target as Vector3).lerp(orb_goal.target, k)
	var sp := sin(float(orb.phi))
	var tgt: Vector3 = orb.target
	var p := tgt + Vector3(float(orb.dist) * sp * sin(float(orb.theta)), float(orb.dist) * cos(float(orb.phi)), float(orb.dist) * sp * cos(float(orb.theta)))
	cam.look_at_from_position(p, tgt)
	cam.h_offset = lerp(cam.h_offset, frame_offset * float(orb.dist) * 0.35, k)
	cam_attr.dof_blur_far_distance = float(orb.dist) + 0.5

func _process(delta: float) -> void:
	_update_cam(delta)

# ------------------------------------------------------------------- input
func ray_at(pos: Vector2) -> Dictionary:
	var from := cam.project_ray_origin(pos); var dir := cam.project_ray_normal(pos)
	var r := kb.pick(from, dir); r.from = from; r.dir = dir; r.x = pos.x; r.y = pos.y
	return r

func screen_of_key(i: int) -> Vector2: return cam.unproject_position(kb.key_world(i))
func screen_of_screw(j: int) -> Vector2: return cam.unproject_position(kb.screw_world(j))

func handle_input(ev: InputEvent) -> bool:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		_last_user = Time.get_ticks_msec()
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed: orb_goal.dist = max(fit_dist * 0.3, float(orb_goal.dist) * 0.9); return true
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed: orb_goal.dist = min(fit_dist * 2.5, float(orb_goal.dist) * 1.1); return true
		if mb.pressed:
			var inf := ray_at(mb.position)
			_drag = {"btn": mb.button_index, "x0": mb.position, "last": mb.position, "t": Time.get_ticks_msec(), "spd": 0.0, "orbit": false, "tool": false, "alt": {}}
			if mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
				_drag.orbit = true; _drag.alt = inf; return true
			if mode == "asm":
				_drag.tool = asm.down(inf)
				if not _drag.tool: _drag.orbit = true
			elif inf.i >= 0:
				_ptr_key = inf.i; _press(inf.i)
			else: _drag.orbit = true
			return true
		else:
			if _drag.is_empty(): return false
			if _ptr_key >= 0: _release(_ptr_key); _ptr_key = -1
			if not (_drag.alt as Dictionary).is_empty() and mode == "asm": asm.alt(_drag.alt)
			if _drag.tool: asm.up(ray_at(mb.position))
			_drag = {}
			return true
	if ev is InputEventMouseMotion:
		var mm := ev as InputEventMouseMotion
		if _drag.is_empty():
			if mode == "asm": asm.hover(ray_at(mm.position))
			return false
		var now := Time.get_ticks_msec()
		var dtm: float = max(4.0, now - float(_drag.t))
		var dv: Vector2 = mm.position - (_drag.last as Vector2)
		var sc = 1600.0 / max(1.0, get_viewport().get_visible_rect().size.x)
		_drag.spd = float(_drag.spd) * 0.45 + dv.length() * sc / dtm * 0.55
		_drag.last = mm.position; _drag.t = now
		var far: bool = (mm.position - (_drag.x0 as Vector2)).length() > 7.0
		if _ptr_key >= 0 and far: _release(_ptr_key); _ptr_key = -1; _drag.orbit = true
		if _drag.orbit:
			if far: _drag.alt = {}
			orb_goal.theta = float(orb_goal.theta) - dv.x * 0.006
			orb_goal.phi = clamp(float(orb_goal.phi) - dv.y * 0.005, 0.08, 1.45)
			_last_user = now
			return true
		if _drag.tool:
			var inf := ray_at(mm.position); inf.spd = _drag.spd
			asm.move(inf)
		return true
	return false

func _press(i: int) -> void:
	if _keys_down.has(i): return
	_keys_down[i] = true; kb.press(i, true); key_down.emit(i)
func _release(i: int) -> void:
	if not _keys_down.has(i): return
	_keys_down.erase(i); kb.press(i, false); key_up.emit(i)
func press_key(i: int, down: bool) -> void:
	if down: _press(i)
	else: _release(i)
