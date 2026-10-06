class_name Aquarium
extends Node3D
## A working desktop aquarium (Blender models from tools/blender/aquarium.py): one black shark that roams the
## tank, sometimes grazes the gravel and swims up to eat when you feed it; swaying plants, rising bubbles from the
## air stone, a rippling water surface and the LED lid light. Origin = bottom centre, front = +Z, back (plants) = -Z.

const W := 0.42
const D := 0.27
const WATER := 0.255             # water surface height (local)
const STONE := Vector3(-0.15, 0.052, -0.085)

var fish: Node3D
var fish_mat: ShaderMaterial
var water_mat: StandardMaterial3D
var target := Vector3.ZERO
var vel := Vector3.ZERO
var speed := 0.05
var _wait := 0.0
var _food := []                  # flakes: [{node, y}]
var _t := 0.0

const SWAY := """
shader_type spatial;
render_mode cull_disabled;
uniform vec4 color : source_color = vec4(0.15, 0.45, 0.12, 1.0);
void vertex() {
	float h = clamp((VERTEX.y - 0.055) / 0.2, 0.0, 1.0);
	VERTEX.x += sin(TIME * 1.3 + VERTEX.x * 21.0 + VERTEX.z * 13.0) * 0.007 * h * h;
	VERTEX.z += cos(TIME * 1.05 + VERTEX.x * 17.0) * 0.004 * h * h;
}
void fragment() { ALBEDO = color.rgb; ROUGHNESS = 0.55; SSS_STRENGTH = 0.3; }
"""
const WIGGLE := """
shader_type spatial;
uniform vec4 color : source_color = vec4(0.004, 0.004, 0.005, 1.0);
uniform float rough = 0.3;
uniform float swim = 1.0;
void vertex() {
	float t = clamp((VERTEX.z + 0.012) / 0.05, 0.0, 1.0);      // 0 at the head, 1 at the tail (+Z)
	VERTEX.x += sin(TIME * (6.0 + 6.0 * swim) - VERTEX.z * 70.0) * (0.0015 + 0.0035 * swim) * t * t;
}
void fragment() { ALBEDO = color.rgb; ROUGHNESS = rough; SPECULAR = 0.7; }
"""

func _ready() -> void:
	var tank: Node3D = _load("aquarium_tank")
	if tank: _apply_tank(tank)
	var plants: Node3D = _load("aquarium_plants")
	if plants:
		var sh = Shader.new(); sh.code = SWAY
		for mi in plants.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for i in m.mesh.get_surface_count():
				var nm = m.mesh.surface_get_material(i).resource_name if m.mesh.surface_get_material(i) else ""
				var sm = ShaderMaterial.new(); sm.shader = sh
				sm.set_shader_parameter("color", Color("1f6b22") if nm == "plant_green" else Color("124a1c"))
				m.set_surface_override_material(i, sm)
	fish = _load("fish_shark")
	if fish:
		var sh2 = Shader.new(); sh2.code = WIGGLE
		fish_mat = ShaderMaterial.new(); fish_mat.shader = sh2
		var fin = fish_mat.duplicate(); fin.set_shader_parameter("color", Color(0.02, 0.015, 0.015)); fin.set_shader_parameter("rough", 0.5)
		var eye = fish_mat.duplicate(); eye.set_shader_parameter("color", Color("c9a84a")); eye.set_shader_parameter("rough", 0.1)
		for mi in fish.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			for i in m.mesh.get_surface_count():
				var nm = m.mesh.surface_get_material(i).resource_name if m.mesh.surface_get_material(i) else ""
				m.set_surface_override_material(i, eye if nm == "fish_eye" else (fin if nm == "fish_fin" else fish_mat))
		fish.position = Vector3(0.0, 0.14, 0.02)
		_new_target()
	_bubbles()
	var lamp = OmniLight3D.new(); lamp.light_color = Color("dff4ff"); lamp.light_energy = 0.5; lamp.light_specular = 0.0; lamp.omni_range = 0.45; lamp.position = Vector3(0, WATER - 0.03, 0.02)
	lamp.shadow_enabled = false; add_child(lamp)
	_hum.call_deferred()
	var hit = StaticBody3D.new(); hit.collision_layer = 2; hit.collision_mask = 0; hit.set_meta("ia", "aquarium")
	var cs = CollisionShape3D.new(); var bs = BoxShape3D.new(); bs.size = Vector3(W, 0.34, D); cs.shape = bs; cs.position.y = 0.17; hit.add_child(cs); add_child(hit)

func _hum() -> void:
	Audio.loop3d("aquarium", "aquarium", to_global(Vector3(0, 0.2, 0)))

func _exit_tree() -> void:
	Audio.stop_loop("aquarium")

func _load(name: String) -> Node3D:
	var p = "res://assets/models/%s.glb" % name
	if not ResourceLoader.exists(p): return null
	var n: Node3D = (load(p) as PackedScene).instantiate(); add_child(n); return n

func _apply_tank(tank: Node3D) -> void:
	var glass = StandardMaterial3D.new(); glass.albedo_color = Color(0.85, 0.95, 0.95, 0.1); glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.02; glass.metallic_specular = 1.0
	water_mat = StandardMaterial3D.new(); water_mat.albedo_color = Color(0.3, 0.55, 0.5, 0.1); water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.roughness = 0.2; water_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED; water_mat.normal_enabled = true; water_mat.normal_texture = Mats.noise_tex(0.05, 61, true, 1.5); water_mat.normal_scale = 0.25
	water_mat.uv1_triplanar = true; water_mat.uv1_scale = Vector3(6, 6, 6)
	var map = {"glass_tank": glass, "water": water_mat, "black": Mats.std(Color("0d0d0f"), 0.4), "white_plastic": Mats.std(Color("f2f2ef"), 0.35),
		"glow_white": Mats.emissive(Color("e6f6ff"), 1.2), "stone": Mats.std(Color("5b5853"), 0.85), "tube": Mats.std(Color(0.7, 0.85, 0.8, 0.5), 0.2),
		"gravel_red": Mats.std(Color("c42a1e"), 0.45), "gravel_yellow": Mats.std(Color("e5bd2a"), 0.45), "gravel_blue": Mats.std(Color("2f5cc4"), 0.45),
		"gravel_white": Mats.std(Color("e9e6df"), 0.6), "gravel_bed": Mats.std(Color("9a948a"), 0.9), "gravel_green": Mats.std(Color("3a9c4c"), 0.45), "gravel_orange": Mats.std(Color("ef7a1d"), 0.45)}
	for mi in tank.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for i in m.mesh.get_surface_count():
			var sm = m.mesh.surface_get_material(i)
			var nm = sm.resource_name if sm else ""
			if map.has(nm): m.set_surface_override_material(i, map[nm])

func _bubbles() -> void:
	var p = CPUParticles3D.new(); p.position = STONE; p.amount = 36; p.lifetime = 1.4
	p.direction = Vector3.UP; p.spread = 6.0; p.initial_velocity_min = 0.12; p.initial_velocity_max = 0.18; p.gravity = Vector3.ZERO
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; p.emission_sphere_radius = 0.006
	p.scale_amount_min = 0.5; p.scale_amount_max = 1.4
	var sm = SphereMesh.new(); sm.radius = 0.003; sm.height = 0.006; sm.radial_segments = 8; sm.rings = 4
	var bm = StandardMaterial3D.new(); bm.albedo_color = Color(0.95, 1.0, 1.0, 0.7); bm.emission_enabled = true; bm.emission = Color(0.6, 0.7, 0.7); bm.rim_enabled = true; bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; bm.roughness = 0.0; bm.metallic_specular = 1.0
	sm.material = bm; p.mesh = sm
	add_child(p)

func _new_target() -> void:
	var graze = randf() < 0.3
	target = Vector3(randf_range(-W / 2 + 0.06, W / 2 - 0.07), 0.075 if graze else randf_range(0.08, WATER - 0.035), randf_range(-D / 2 + 0.05, D / 2 - 0.045))
	speed = randf_range(0.03, 0.075)
	_wait = randf_range(0.0, 1.2) if graze else 0.0

## Sprinkle flakes on the water: the shark swims up and eats them.
func feed() -> void:
	for i in 6:
		var f = MeshInstance3D.new(); var bm = BoxMesh.new(); bm.size = Vector3(0.004, 0.0008, 0.004); f.mesh = bm
		f.material_override = Mats.std(Color("d8a24a"), 0.7)
		f.position = Vector3(randf_range(0.0, 0.12), WATER - 0.002, randf_range(-0.03, 0.05)); f.rotation.y = randf() * TAU
		add_child(f); _food.append(f)
	Audio.sfx("bag", global_position + Vector3(0, WATER, 0), -14.0)

func _process(delta: float) -> void:
	_t += delta
	if water_mat: water_mat.uv1_offset = Vector3(_t * 0.01, 0, _t * 0.006)
	# food sinks slowly; the shark chases the nearest flake
	for f in _food.duplicate():
		if not is_instance_valid(f): _food.erase(f); continue
		f.position.y = max(0.07, f.position.y - delta * 0.008); f.rotation.y += delta * 0.6
	if fish == null: return
	var goal = target
	if not _food.is_empty():
		var fl: Node3D = _food[0]; goal = fl.position + Vector3(0, -0.006, 0); speed = 0.09
		if fish.position.distance_to(goal) < 0.012:
			fl.queue_free(); _food.pop_front(); Audio.sfx("bubble", to_global(fish.position), -20.0, 0.25)
	if _wait > 0.0:
		_wait -= delta; vel = vel.lerp(Vector3.ZERO, 1.0 - exp(-delta * 3.0))
	else:
		var to = goal - fish.position
		if to.length() < 0.015 and _food.is_empty():
			_new_target()
		else:
			var want = to.normalized() * speed
			vel = vel.lerp(want, 1.0 - exp(-delta * 1.6))
	fish.position += vel * delta
	fish.position = fish.position.clamp(Vector3(-W / 2 + 0.045, 0.065, -D / 2 + 0.035), Vector3(W / 2 - 0.045, WATER - 0.02, D / 2 - 0.035))
	if vel.length() > 0.004:
		var fwd = vel.normalized()
		var basis_goal = Basis.looking_at(Vector3(fwd.x, fwd.y * 0.4, fwd.z).normalized(), Vector3.UP)
		fish.basis = fish.basis.slerp(basis_goal, 1.0 - exp(-delta * 4.0)).orthonormalized()
	if fish_mat: fish_mat.set_shader_parameter("swim", clamp(vel.length() / 0.08, 0.15, 1.2))
