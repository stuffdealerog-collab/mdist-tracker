class_name Scope
extends Control
## Live "oscilloscope" driven by the Keys bus peak meter.

var hist = PackedFloat32Array()
var _ph = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(300, 70)
	hist.resize(120); hist.fill(0.0)

func _process(d: float) -> void:
	var bi = AudioServer.get_bus_index("Keys")
	var db = AudioServer.get_bus_peak_volume_left_db(bi, 0) if bi >= 0 else -80.0
	var v: float = clamp(db_to_linear(db) * 2.2, 0.0, 1.0)
	hist.remove_at(0); hist.append(v)
	_ph += d * 40.0
	queue_redraw()

func _draw() -> void:
	draw_style_box(UIK.sb(Color("0c1013"), 8, UIK.LINE, 0), Rect2(Vector2.ZERO, size))
	var mid = size.y / 2.0
	draw_line(Vector2(0, mid), Vector2(size.x, mid), Color(0.3, 0.72, 0.67, 0.25), 1.0)
	var pts = PackedVector2Array()
	for i in hist.size():
		var x = i / float(hist.size() - 1) * size.x
		var a = hist[i] * size.y * 0.45
		pts.append(Vector2(x, mid + sin(i * 1.7 + _ph) * a * (0.6 + 0.4 * sin(i * 0.31))))
	draw_polyline(pts, UIK.TEAL, 2.0, true)
