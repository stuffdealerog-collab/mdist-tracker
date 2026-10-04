class_name CapsRow
extends Control
## A row of 6 flat keycaps previewing a keycap set.

var kc_id = ""
const SEQ := [["Esc", "x", 1.0], ["Q", "a", 1.0], ["W", "a", 1.0], ["E", "a", 1.0], ["Shift", "m", 1.6], ["Enter", "x", 1.6]]

static func make(id: String, h := 34.0) -> CapsRow:
	var c = CapsRow.new(); c.kc_id = id; c.custom_minimum_size = Vector2(h * 7.4, h); c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

func _draw() -> void:
	var u = size.y; var x = 0.0
	for s in SEQ:
		var cc = Keyboard3D.cap_colors(kc_id, s[1])
		var r = Rect2(x + 1, 0, s[2] * u - 3, u - 2)
		draw_style_box(UIK.sb(cc[0].darkened(0.28), int(u * 0.14), Color(0, 0, 0, 0), 0), r)
		var t = Rect2(r.position + Vector2(u * 0.1, u * 0.05), r.size - Vector2(u * 0.2, u * 0.22))
		draw_style_box(UIK.sb(cc[0], int(u * 0.12), Color(1, 1, 1, 0.12), 0), t)
		draw_string(UIK.f_num, t.position + Vector2(4, u * 0.36), s[0], HORIZONTAL_ALIGNMENT_LEFT, t.size.x - 4, int(u * 0.26), cc[1])
		x += s[2] * u
