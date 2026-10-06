class_name Player
extends CharacterBody3D
## First-person body: WASD + mouse look, footsteps, interaction ray and a hold point for carried things.
## It does not know game rules: it asks `prompt_fn(target)` what a target means and emits `interact(target)`.

signal interact(target: Dictionary)
signal alt_interact(target: Dictionary)
signal prompt_changed(text: String)

const EYE := 1.62
const WALK := 2.0
const RUN := 3.4
const REACH := 2.1

var head: Node3D
var cam: Camera3D
var hold: Node3D                 # carried objects are parented here
var active = false              # true while the player controls the body
var prompt_fn: Callable
var target = {}
var _prompt = ""
var _yaw = 0.0
var _pitch = 0.0
var _step_acc = 0.0
var _bob = 0.0
var _sens = 0.0022

func _ready() -> void:
	collision_layer = 0; collision_mask = 1
	var cs = CollisionShape3D.new(); var cap = CapsuleShape3D.new(); cap.radius = 0.26; cap.height = 1.7; cs.shape = cap; cs.position.y = 0.85
	add_child(cs)
	head = Node3D.new(); head.position.y = EYE; add_child(head)
	cam = Camera3D.new(); cam.fov = 70; cam.near = 0.03; cam.far = 60; head.add_child(cam)
	hold = Node3D.new(); hold.position = Vector3(0.0, -0.36, -0.5); cam.add_child(hold)
	floor_snap_length = 0.3

func look_at_point(p: Vector3) -> void:
	var d = p - (global_position + Vector3(0, EYE, 0))
	_yaw = atan2(-d.x, -d.z); _pitch = atan2(d.y, Vector2(d.x, d.z).length())
	_apply_look()

func set_look(yaw: float, pitch: float) -> void:
	_yaw = yaw; _pitch = pitch; _apply_look()

func _apply_look() -> void:
	rotation.y = _yaw
	head.rotation.x = clamp(_pitch, -1.45, 1.45)

func _unhandled_input(ev: InputEvent) -> void:
	if not active: return
	if ev is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var m = ev as InputEventMouseMotion
		_yaw -= m.relative.x * _sens; _pitch = clamp(_pitch - m.relative.y * _sens, -1.45, 1.45)
		_apply_look(); get_viewport().set_input_as_handled()
	elif ev is InputEventKey and (ev as InputEventKey).pressed and not (ev as InputEventKey).echo:
		var k = ev as InputEventKey
		if k.keycode == KEY_E: interact.emit(target); get_viewport().set_input_as_handled()
		elif k.keycode == KEY_R: alt_interact.emit(target); get_viewport().set_input_as_handled()
	elif ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
		var b = ev as InputEventMouseButton
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED; get_viewport().set_input_as_handled(); return
		if b.button_index == MOUSE_BUTTON_LEFT: interact.emit(target); get_viewport().set_input_as_handled()
		elif b.button_index == MOUSE_BUTTON_RIGHT: alt_interact.emit(target); get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	var dir = Vector3.ZERO
	if active:
		var f = Input.get_axis(&"ui_up", &"ui_down")
		var s = Input.get_axis(&"ui_left", &"ui_right")
		if Input.is_physical_key_pressed(KEY_W): f -= 1.0
		if Input.is_physical_key_pressed(KEY_S): f += 1.0
		if Input.is_physical_key_pressed(KEY_A): s -= 1.0
		if Input.is_physical_key_pressed(KEY_D): s += 1.0
		dir = (transform.basis * Vector3(clamp(s, -1, 1), 0, clamp(f, -1, 1)))
		dir.y = 0
		if dir.length() > 1.0: dir = dir.normalized()
	var spd = RUN if Input.is_physical_key_pressed(KEY_SHIFT) else WALK
	var k = 1.0 - exp(-delta * (12.0 if dir.length() > 0.01 else 9.0))
	velocity.x = lerp(velocity.x, dir.x * spd, k); velocity.z = lerp(velocity.z, dir.z * spd, k)
	if not is_on_floor(): velocity.y -= 9.8 * delta
	else: velocity.y = 0.0
	move_and_slide()
	var hv = Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and hv > 0.3:
		_step_acc += hv * delta; _bob += hv * delta * 5.2
		if _step_acc > (0.72 if spd == RUN else 0.62):
			_step_acc = 0.0
			Audio.sfx("step", global_position + Vector3(0, 0.05, 0), 2.0 if spd == RUN else 0.0, 0.08)
	else:
		_bob = lerp(_bob, round(_bob / PI) * PI, 1.0 - exp(-delta * 6.0))
	head.position.y = EYE + sin(_bob * 2.0) * 0.014 * min(1.0, hv / WALK)
	head.position.x = cos(_bob) * 0.01 * min(1.0, hv / WALK)
	_update_target()

func _update_target() -> void:
	var t = {}
	if active:
		var from = cam.global_position; var to = from - cam.global_transform.basis.z * REACH
		var q = PhysicsRayQueryParameters3D.create(from, to, 1 | 2, [get_rid()])
		var hit = get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			var c: Object = hit.collider
			t = {"id": str(c.get_meta("ia", "")) if c.has_meta("ia") else "", "pos": hit.position, "normal": hit.normal, "node": c}
	target = t
	var p = ""
	if active and prompt_fn.is_valid(): p = str(prompt_fn.call(t))
	if p != _prompt:
		_prompt = p; prompt_changed.emit(p)

func carry(n: Node3D) -> void:
	if n.get_parent(): n.get_parent().remove_child(n)
	hold.add_child(n); n.position = Vector3.ZERO; n.rotation = Vector3(0.08, 0, 0)
	n.scale = Vector3.ONE * 0.9
	var tw = n.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(n, "scale", Vector3.ONE, 0.25)

func drop_held() -> Node3D:
	if hold.get_child_count() == 0: return null
	var n: Node3D = hold.get_child(0)
	hold.remove_child(n)
	return n

func holding() -> bool: return hold.get_child_count() > 0
