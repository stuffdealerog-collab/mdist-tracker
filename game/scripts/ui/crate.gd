class_name Crate
extends Control
## Animated gift crate drawing (idle bob + shine).

var col = Color.WHITE
var _t = 0.0

static func make(c: Color, s := 120.0) -> Crate:
	var k = Crate.new(); k.col = c; k.custom_minimum_size = Vector2(s, s); k.mouse_filter = Control.MOUSE_FILTER_IGNORE
	k._t = randf() * 6.0
	return k

func _process(d: float) -> void: _t += d; queue_redraw()

func _draw() -> void:
	var s = size.x; var bob = sin(_t * 2.0) * 3.0
	draw_set_transform(Vector2(0, bob))
	# shadow
	draw_set_transform(Vector2(s / 2, s * 0.9), 0.0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, s * 0.32 - bob, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2(0, bob))
	var front = PackedVector2Array([Vector2(s * .18, s * .42), Vector2(s * .5, s * .52), Vector2(s * .5, s * .88), Vector2(s * .18, s * .76)])
	var side = PackedVector2Array([Vector2(s * .5, s * .52), Vector2(s * .82, s * .42), Vector2(s * .82, s * .76), Vector2(s * .5, s * .88)])
	var top = PackedVector2Array([Vector2(s * .18, s * .42), Vector2(s * .5, s * .3), Vector2(s * .82, s * .42), Vector2(s * .5, s * .52)])
	draw_colored_polygon(front, col.darkened(0.15)); draw_colored_polygon(side, col.darkened(0.38)); draw_colored_polygon(top, col.lightened(0.15))
	var rib = Color("f4efe6")
	draw_line(Vector2(s * .34, s * .47), Vector2(s * .34, s * .82), rib, s * 0.05)
	draw_line(Vector2(s * .66, s * .47), Vector2(s * .66, s * .82), rib.darkened(0.2), s * 0.05)
	draw_line(Vector2(s * .34, s * .36), Vector2(s * .66, s * .47), rib, s * 0.045)
	draw_line(Vector2(s * .66, s * .36), Vector2(s * .34, s * .47), rib, s * 0.045)
	draw_circle(Vector2(s * .5, s * .38), s * 0.06, rib)
	var sh = fposmod(_t * 0.35, 1.6) - 0.3
	if sh > 0.0 and sh < 1.0:
		var x = s * (0.18 + sh * 0.64)
		draw_line(Vector2(x, s * 0.35), Vector2(x - s * 0.1, s * 0.85), Color(1, 1, 1, 0.18), s * 0.05)
