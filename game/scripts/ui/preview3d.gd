class_name Preview3D
extends SubViewportContainer
## Self-contained 3D turntable of a board (own world): drag to rotate, click keys to hear.

signal key_pressed(i: int, down: bool)

var vp: SubViewport
var kb: Keyboard3D
var cam: Camera3D
var spec: Dictionary = {}
var theta = -0.3
var phi = 0.95
var dist = 0.55
var auto_spin = true
var _drag = false
var _key = -1

static func make(sp: Dictionary, min_size := Vector2(560, 300)) -> Preview3D:
	var p = Preview3D.new(); p.spec = sp; p.custom_minimum_size = min_size; p.stretch = true
	return p

func _ready() -> void:
	vp = SubViewport.new(); vp.own_world_3d = true; vp.transparent_bg = true; vp.msaa_3d = Viewport.MSAA_4X
	vp.size = Vector2i(custom_minimum_size); add_child(vp)
	var we = WorldEnvironment.new(); var e = Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color("9aa8b8"); e.ambient_light_energy = 0.35
	e.tonemap_mode = Environment.TONE_MAPPER_ACES; e.ssao_enabled = true; e.ssao_radius = 0.05; e.glow_enabled = true; e.glow_hdr_threshold = 1.2
	e.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	var sky = Sky.new(); var sm = ProceduralSkyMaterial.new(); sm.sky_top_color = Color("2b3540"); sm.sky_horizon_color = Color("8090a0"); sm.ground_bottom_color = Color("1a1410"); sm.ground_horizon_color = Color("5a5048")
	sky.sky_material = sm; e.sky = sky; e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	we.environment = e; vp.add_child(we)
	var key = DirectionalLight3D.new(); key.rotation_degrees = Vector3(-50, -30, 0); key.light_energy = 1.4; key.shadow_enabled = true; key.light_color = Color("ffe8cc"); vp.add_child(key)
	var rim = DirectionalLight3D.new(); rim.rotation_degrees = Vector3(-25, 150, 0); rim.light_energy = 0.6; rim.light_color = Color("9fc8ff"); vp.add_child(rim)
	var floor = MeshInstance3D.new(); var pm = PlaneMesh.new(); pm.size = Vector2(3, 3); floor.mesh = pm
	var fm = StandardMaterial3D.new(); fm.albedo_color = Color(0.08, 0.09, 0.1); fm.roughness = 0.6; floor.material_override = fm; floor.position.y = -0.003
	vp.add_child(floor)
	kb = Keyboard3D.new(); kb.scale = Vector3.ONE * Workshop.U; kb.rotation.x = 0.06; vp.add_child(kb)
	cam = Camera3D.new(); cam.fov = 34; cam.near = 0.02; vp.add_child(cam)
	if not spec.is_empty(): set_spec(spec)

func set_spec(sp: Dictionary) -> void:
	spec = sp
	if kb == null: return
	kb.show_spec(sp, null); kb.reveal()
	var L: Dictionary = Data.LAYOUTS[sp.layout]
	var w: float = (float(L.W) + 2.0) * Workshop.U
	var asp: float = max(0.5, size.x / max(1.0, size.y)) if size.x > 0 else 1.8
	dist = w / (2.0 * tan(deg_to_rad(17.0)) * asp) * 1.05

func _process(d: float) -> void:
	if cam == null: return
	if auto_spin and not _drag: theta += d * 0.18
	var p = Vector3(dist * sin(phi) * sin(theta), dist * cos(phi), dist * sin(phi) * cos(theta))
	cam.look_at_from_position(p, Vector3(0, 0.01, 0))

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP: dist *= 0.92; accept_event(); return
		if e.button_index == MOUSE_BUTTON_WHEEL_DOWN: dist *= 1.08; accept_event(); return
		if e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				var from = cam.project_ray_origin(e.position * Vector2(vp.size) / size); var dir = cam.project_ray_normal(e.position * Vector2(vp.size) / size)
				var r = kb.pick(from, dir)
				if r.i >= 0: _key = r.i; kb.press(r.i, true); key_pressed.emit(r.i, true)
				else: _drag = true; auto_spin = false
			else:
				if _key >= 0: kb.press(_key, false); key_pressed.emit(_key, false); _key = -1
				_drag = false
			accept_event()
	elif e is InputEventMouseMotion and _drag:
		theta -= e.relative.x * 0.008; phi = clamp(phi - e.relative.y * 0.006, 0.1, 1.45); accept_event()
