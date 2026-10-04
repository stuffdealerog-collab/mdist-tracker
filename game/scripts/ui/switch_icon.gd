class_name SwitchIcon
extends Control
## Clickable MX-style switch drawing (top view): press to hear the real recording.

var sw_id = ""
var down = false

static func make(id: String, s := 46.0) -> SwitchIcon:
	var c = SwitchIcon.new(); c.sw_id = id; c.custom_minimum_size = Vector2(s, s); c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	c.tooltip_text = "Зажмите, чтобы послушать"
	return c

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		down = e.pressed; queue_redraw()
		SwitchIcon.hear(sw_id, not e.pressed)
		accept_event()

static func hear(id: String, up: bool) -> void:
	var P = Game.sw_profile_solo(id)
	Audio.load_set(str(P.get("snd", ""))); Audio.set_profile(P)
	Audio.key(P, {"w": 1.0, "row": 2, "codes": ["KeyF"]}, up, false)

func _draw() -> void:
	var s = Data.sw(sw_id); var w = size.x
	var hous = Color(s.hous); var stem = Color(s.stem)
	var o = 2.0 if down else 0.0
	draw_style_box(UIK.sb(hous.darkened(0.3), int(w * 0.16), Color(0, 0, 0, 0), 0), Rect2(0, w * 0.06, w, w * 0.94))
	draw_style_box(UIK.sb(hous, int(w * 0.14), Color(1, 1, 1, 0.15), 0), Rect2(w * 0.06, o, w * 0.88, w * 0.86))
	draw_rect(Rect2(w * 0.42, w * 0.2 + o, w * 0.16, w * 0.46), stem)
	draw_rect(Rect2(w * 0.27, w * 0.35 + o, w * 0.46, w * 0.16), stem)
