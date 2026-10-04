class_name KbThumb
extends Control
## Flat top-down keyboard thumbnail drawn from a spec (cheap, used in cards).

var spec: Dictionary = {}

static func make(sp: Dictionary, h := 96.0) -> KbThumb:
	var t = KbThumb.new(); t.spec = sp; t.custom_minimum_size = Vector2(0, h); t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

func _draw() -> void:
	if spec.is_empty(): return
	var L: Dictionary = Data.LAYOUTS[spec.layout]
	var W: float = float(L.W) + 0.9; var H: float = float(L.H) + 0.9
	var u: float = min(size.x / W, size.y / H)
	var off = (size - Vector2(W, H) * u) / 2.0
	var cs = Data.case_(spec.case)
	var col = Color(cs.colors[int(spec.get("color", 0))][1])
	if cs.look == "acrylic": col.a = 0.75
	var r = Rect2(off, Vector2(W, H) * u)
	draw_style_box(UIK.sb(Color(0, 0, 0, 0.35), int(u * 0.45), Color(0, 0, 0, 0), 0), Rect2(r.position + Vector2(0, u * 0.18), r.size))
	draw_style_box(UIK.sb(col, int(u * 0.4), col.lightened(0.18), 0), r)
	if Data.pcb(spec.get("pcb", "b_hs")).get("rgb", false):
		draw_style_box(UIK.sb(Color(0, 0, 0, 0), int(u * 0.4), Color(0.48, 0.36, 1.0, 0.7), 0, 2), r.grow(1.5))
	var kc_id: String = str(spec.get("kc", ""))
	var gap: float = max(1.0, u * 0.08)
	for k in L.keys:
		var kr = Rect2(off + Vector2(float(k.x) + 0.45, float(k.y) + 0.45) * u + Vector2(gap, gap) / 2.0, Vector2(float(k.w) * u - gap, u - gap))
		if kc_id == "":
			draw_rect(kr, Color(0, 0, 0, 0.3)); continue
		var cc = Keyboard3D.cap_colors(kc_id, str(k.kind))
		var is_art: bool = spec.get("art") != null and ("Escape" in k.codes or str(k.label) == "Esc")
		var base: Color = cc[0]
		if is_art: base = Keyboard3D.art_color(Data.art(str(spec.art)))
		draw_rect(kr, base.darkened(0.25))
		var top = Rect2(kr.position + Vector2(u * 0.08, u * 0.04), kr.size - Vector2(u * 0.16, u * 0.16))
		draw_rect(top, base)
		if u >= 16 and not is_art:
			draw_string(UIK.f_num, top.position + Vector2(2, u * 0.32), str(k.label).left(4), HORIZONTAL_ALIGNMENT_LEFT, top.size.x, int(u * 0.24), Color(cc[1], 0.9))
