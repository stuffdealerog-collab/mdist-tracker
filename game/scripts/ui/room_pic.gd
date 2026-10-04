class_name RoomPic
extends Control
## Small illustrated vignette of a property style.

var style = "garage"

static func make(s: String, h := 110.0) -> RoomPic:
	var r = RoomPic.new(); r.style = s; r.custom_minimum_size = Vector2(0, h); r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

func _draw() -> void:
	var w = size.x; var h = size.y
	var pal = {
		"garage": [Color("4a4947"), Color("5f5e5b"), Color("ffcf8f")], "loft": [Color("8a4532"), Color("6e4b2f"), Color("dbe9f5")],
		"studio": [Color("e8e6e1"), Color("b08a62"), Color("fff1dc")], "boutique": [Color("23382e"), Color("3a2416"), Color("ffd59a")],
		"flagship": [Color("15161c"), Color("101114"), Color("ff5ad1")]}.get(style, [Color.GRAY, Color.DIM_GRAY, Color.WHITE])
	draw_style_box(UIK.sb(pal[0], 10, Color(0, 0, 0, 0), 0), Rect2(0, 0, w, h))
	draw_rect(Rect2(0, h * 0.72, w, h * 0.28), pal[1])
	match style:
		"garage":
			draw_circle(Vector2(w * 0.5, h * 0.14), 6, pal[2]); draw_circle(Vector2(w * 0.5, h * 0.14), 22, Color(pal[2], 0.15))
			for i in 6: draw_rect(Rect2(w * 0.1 + i * 10, h * 0.25, 4, h * 0.25), Color("b9bec4"))
		"loft":
			for y in range(0, int(h * 0.72), 8):
				for x in range(-(y / 8 % 2) * 10, int(w), 20): draw_rect(Rect2(x, y, 18, 6), Color("a65a3e").darkened(randf() * 0.0 + 0.1 * ((x + y) % 3)))
			draw_rect(Rect2(w * 0.55, h * 0.1, w * 0.35, h * 0.5), pal[2]); draw_rect(Rect2(w * 0.72, h * 0.1, 3, h * 0.5), Color("1b1c1e"))
		"studio":
			draw_rect(Rect2(w * 0.08, h * 0.12, w * 0.25, h * 0.4), Color("dbe9f5"))
			draw_rect(Rect2(w * 0.45, h * 0.35, w * 0.45, 4), Color("d6b48a")); draw_rect(Rect2(w * 0.45, h * 0.55, w * 0.45, 4), Color("d6b48a"))
			draw_string(UIK.f_disp, Vector2(w * 0.55, h * 0.25), "KSS", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UIK.TEAL)
		"boutique":
			draw_rect(Rect2(0, h * 0.42, w, h * 0.3), Color("4a2e1c"))
			for x in [0.2, 0.5, 0.8]:
				var c = Vector2(w * x, 0)
				draw_colored_polygon(PackedVector2Array([c + Vector2(-4, 0), c + Vector2(4, 0), c + Vector2(30, h * 0.7), c + Vector2(-30, h * 0.7)]), Color(pal[2], 0.12))
		"flagship":
			var y0 = h * 0.6
			for i in 14: draw_rect(Rect2(i * w / 14.0, y0 - (20 + (i * 37) % 40), w / 14.0 - 2, 20 + (i * 37) % 40), Color("1a1f30"))
			draw_string(UIK.f_disp, Vector2(w * 0.1, h * 0.2), "KEYBOARD SELLER", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, pal[2])
	# desk
	draw_rect(Rect2(w * 0.25, h * 0.66, w * 0.5, 6), Color("7a5434"))
	draw_rect(Rect2(w * 0.38, h * 0.62, w * 0.24, 6), Color("2a2f36"))
