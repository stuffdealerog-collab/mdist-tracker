extends Node
## Step 1 of the lightmap bake: builds the flat, copies every static mesh (Home.bake_nodes) with a lightmap UV2 into
## res://bake/room_day.scn and room_night.scn (+ the lights and a LightmapGI), meshes saved once in res://bake/meshes.
## Step 2 bakes them in the editor: addons/kss_bake (KSS_BAKE=1 godot --editor). Run with KSS_NOBAKE=1:
##   KSS_NOBAKE=1 godot --path . res://tests/bake_export.tscn
const TEXEL := 0.04
var main

func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	run.call_deferred()

func wait(n: int) -> void:
	for i in n: await get_tree().process_frame

func run() -> void:
	await wait(5)
	Game.S.seenIntro = true
	while main.mode == "intro": await wait(5)
	await wait(20)
	var home: Home = main.home
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://bake/meshes"))
	for f in DirAccess.get_files_at("res://bake/meshes"): DirAccess.remove_absolute("res://bake/meshes/" + f)
	var inv = home.global_transform.affine_inverse()
	var nodes = home.bake_nodes()
	for mi in home.find_children("*", "MeshInstance3D", true, false):
		if not (mi in nodes) and mi.is_visible_in_tree() and mi.mesh: print("[bake] not baked: ", home.get_path_to(mi), " ", mi.mesh.get_class())
	var root = Node3D.new(); root.name = "RoomBake"; root.set_meta("count", nodes.size())
	var meshes = Node3D.new(); meshes.name = "Meshes"; root.add_child(meshes)
	var cache = {}; var saved = 0; var skipped = 0
	for i in nodes.size():
		var o: MeshInstance3D = nodes[i]
		var m: Mesh = cache.get(o.mesh)
		if m == null:
			m = _uv2(o)
			if m == null: skipped += 1; continue
			if m.resource_path == "":
				var path = "res://bake/meshes/m%04d.res" % saved; saved += 1
				ResourceSaver.save(m, path, ResourceSaver.FLAG_COMPRESS); m.take_over_path(path)
			cache[o.mesh] = m
		var b = MeshInstance3D.new(); b.name = "M%04d" % i; b.mesh = m; b.set_meta("src", i)
		b.transform = inv * o.global_transform
		b.material_override = o.material_override
		for s in o.mesh.get_surface_count():
			var sm = o.get_surface_override_material(s)
			if sm: b.set_surface_override_material(s, sm)
		b.gi_mode = GeometryInstance3D.GI_MODE_STATIC; b.cast_shadow = o.cast_shadow
		meshes.add_child(b)
	print("[bake] %d static meshes, %d unique saved, %d skipped (no UV2)" % [nodes.size(), saved, skipped])
	var lm = LightmapGI.new(); lm.name = "LightmapGI"; root.add_child(lm)
	lm.quality = LightmapGI.BAKE_QUALITY_HIGH; lm.bounces = 4; lm.bounce_indirect_energy = 1.0; lm.directional = true; lm.use_denoiser = true
	lm.texel_scale = 2.0; lm.generate_probes_subdiv = LightmapGI.GENERATE_PROBES_SUBDIV_8; lm.interior = true
	lm.environment_mode = LightmapGI.ENVIRONMENT_MODE_CUSTOM_COLOR
	var lights = Node3D.new(); lights.name = "BakeLights"; root.add_child(lights)
	# day: 13:00 sun through the window + bright overcast sky; night: chandelier, city glow only
	for variant in ["day", "night"]:
		home.set_time(13 * 60.0 if variant == "day" else 22 * 60.0)
		for c in lights.get_children(): lights.remove_child(c); c.free()
		var lamps = home.bake_lights()
		for l in home.find_children("*", "Light3D", true, false):
			var light := l as Light3D
			if not (light in lamps) and light != home.sun: continue
			if not light.visible or light.light_energy <= 0.0 or not light.is_visible_in_tree(): continue
			var d: Light3D = light.duplicate(0); d.transform = inv * light.global_transform
			# bounce only: direct light and shadows stay real-time, so moving things (keyboards, parcels, the chair)
			# are lit exactly like the lightmapped room (baking the lamps' direct light left them probe-lit and flat)
			d.light_bake_mode = Light3D.BAKE_DYNAMIC
			d.shadow_enabled = true
			lights.add_child(d)
		lm.environment_custom_color = Color(0.72, 0.82, 1.0) if variant == "day" else Color(0.12, 0.14, 0.24)
		lm.environment_custom_energy = 1.2 if variant == "day" else 0.25
		_own(root, root)
		var ps = PackedScene.new(); ps.pack(root)
		var err = ResourceSaver.save(ps, "res://bake/room_%s.scn" % variant, ResourceSaver.FLAG_COMPRESS)
		print("[bake] saved room_%s.scn (%d lights) err=%d" % [variant, lights.get_child_count(), err])
	get_tree().quit()

func _own(n: Node, owner_node: Node) -> void:
	for c in n.get_children():
		c.owner = owner_node; _own(c, owner_node)

## A copy of the mesh with a lightmap UV2 (imported glb meshes already have one).
func _uv2(o: MeshInstance3D) -> Mesh:
	var src: Mesh = o.mesh
	var am: ArrayMesh
	if src is PrimitiveMesh:
		am = ArrayMesh.new(); am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, (src as PrimitiveMesh).get_mesh_arrays())
		am.surface_set_material(0, (src as PrimitiveMesh).material)
	elif src is ArrayMesh:
		var has = true
		for s in src.get_surface_count(): has = has and ((src as ArrayMesh).surface_get_format(s) & Mesh.ARRAY_FORMAT_TEX_UV2) != 0
		if has:
			# UV2 authored in Blender: keep it, but give the mesh a lightmap size from its world area (else Godot uses 64x64)
			if src.lightmap_size_hint != Vector2i.ZERO: return src
			var dup: ArrayMesh = src.duplicate()
			var area := 0.0
			var faces: PackedVector3Array = src.get_faces()
			var basis := o.global_transform.basis
			for i in range(0, faces.size(), 3):
				area += ((basis * faces[i + 1] - basis * faces[i]).cross(basis * faces[i + 2] - basis * faces[i])).length() * 0.5
			var side = int(clamp(sqrt(area) / TEXEL * 1.15, 16, 2048))
			dup.lightmap_size_hint = Vector2i(side, side)
			return dup
		am = ArrayMesh.new()
		for s in src.get_surface_count():
			var arr = (src as ArrayMesh).surface_get_arrays(s)
			am.add_surface_from_arrays((src as ArrayMesh).surface_get_primitive_type(s), arr)
			am.surface_set_material(s, src.surface_get_material(s))
	else:
		return null
	var err = am.lightmap_unwrap(o.global_transform, TEXEL)
	if err != OK:
		print("[bake] unwrap failed for ", o.get_path(), " err=", err); return null
	return am
