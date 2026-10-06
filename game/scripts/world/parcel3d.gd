class_name Parcel3D
extends StaticBody3D
## A shipping box standing somewhere in the flat. Origin = bottom centre.
## Kraft boxes come from shops and clients; "out" boxes are our own branded mailers.

var data: Dictionary = {}
var size = Vector3(0.4, 0.12, 0.2)
var body: Node3D

func setup(p: Dictionary) -> Parcel3D:
	data = p
	var s = p.get("size", Vector3(0.4, 0.12, 0.2))
	size = s if s is Vector3 else _vec(s)
	collision_layer = 2; collision_mask = 0
	set_meta("ia", "parcel:" + str(p.id))
	var cs = CollisionShape3D.new(); var bs = BoxShape3D.new(); bs.size = size + Vector3(0.02, 0.02, 0.02); cs.shape = bs; cs.position.y = size.y / 2.0
	add_child(cs)
	body = Node3D.new(); add_child(body)
	if p.kind == "out": _brand_box()
	else: _kraft_box(hash(str(p.id)))
	return self

static func _vec(s) -> Vector3:
	if s is String:
		var a: PackedStringArray = s.replace("(", "").replace(")", "").split(",")
		if a.size() == 3: return Vector3(float(a[0]), float(a[1]), float(a[2]))
	if s is Array and s.size() == 3: return Vector3(float(s[0]), float(s[1]), float(s[2]))
	return Vector3(0.4, 0.12, 0.2)

func _mesh(m: Mesh, mat: Material, pos := Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var mi = MeshInstance3D.new(); mi.mesh = m; mi.material_override = mat; mi.position = pos
	(parent if parent else body).add_child(mi); return mi

func _kraft_box(seed_v: int) -> void:
	var box = MeshGen.rounded_box(size.x, size.y, size.z, 0.004, 2)
	_mesh(box, HMats.cardboard())
	# centre seam tape along the length, wrapping down both ends
	var tw: float = min(0.05, size.z * 0.3)
	var top = BoxMesh.new(); top.size = Vector3(size.x + 0.002, 0.0012, tw)
	_mesh(top, HMats.tape(), Vector3(0, size.y + 0.0006, 0))
	for sx in [-1, 1]:
		var end = BoxMesh.new(); end.size = Vector3(0.0012, size.y * 0.55, tw)
		_mesh(end, HMats.tape(), Vector3(sx * (size.x / 2.0 + 0.0006), size.y * 0.72, 0))
	# shipping label on the lid
	var lw: float = min(0.12, size.x * 0.35); var lh: float = lw * 0.62
	if size.z > lh + tw + 0.01:
		var lb = BoxMesh.new(); lb.size = Vector3(lw, 0.0008, lh)
		var l = _mesh(lb, HMats.label(seed_v), Vector3(-size.x * 0.22, size.y + 0.0005, size.z / 2.0 - lh / 2.0 - 0.012))
		l.rotation.y = PI
	# printed "this side up" arrows on one side
	var arr = Label3D.new(); arr.text = "↑↑"; arr.font_size = 64; arr.pixel_size = 0.0012; arr.modulate = Color(0.15, 0.1, 0.06, 0.8)
	arr.outline_size = 0; arr.position = Vector3(size.x * 0.3, size.y * 0.55, size.z / 2.0 + 0.001); arr.shaded = true
	body.add_child(arr)

func _brand_box() -> void:
	var col = Color("16181b")
	_mesh(MeshGen.rounded_box(size.x, size.y, size.z, 0.006, 2), HMats.brand_box(col))
	var name_l = Label3D.new(); name_l.text = str(Game.S.get("shop", "KSS")).replace("Мастерская ", "").replace("«", "").replace("»", "")
	name_l.font = load("res://assets/fonts/Tektur.ttf"); name_l.font_size = 96; name_l.pixel_size = 0.00045 * clamp(size.x / 0.5, 0.7, 1.4)
	name_l.modulate = Color("e9e4da"); name_l.outline_size = 0; name_l.shaded = true
	name_l.rotation_degrees = Vector3(-90, 0, 0); name_l.position = Vector3(0, size.y + 0.0012, 0.0)
	body.add_child(name_l)
	var strip = BoxMesh.new(); strip.size = Vector3(size.x * 0.7, 0.0008, 0.004)
	_mesh(strip, Mats.emissive(Color("4cb8ab"), 0.4), Vector3(0, size.y + 0.0008, 0.035))
	if Game.ship_by_id(str(data.get("ship", ""))).get("kind", "") != "":
		var tw: float = 0.045
		var top = BoxMesh.new(); top.size = Vector3(0.0012, 0.0012, size.z + 0.002)
		for sx in [-1, 1]:
			_mesh(top, HMats.tape(true), Vector3(sx * (size.x / 2.0 - 0.03), size.y + 0.0006, 0))
		var lb = BoxMesh.new(); lb.size = Vector3(0.1, 0.0008, 0.062)
		_mesh(lb, HMats.label(hash(str(data.id))), Vector3(size.x * 0.28, size.y + 0.0009, -size.z * 0.18))

## Short squash on landing so boxes feel heavy.
func land() -> void:
	body.scale = Vector3(1.03, 0.94, 1.03)
	create_tween().tween_property(body, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
