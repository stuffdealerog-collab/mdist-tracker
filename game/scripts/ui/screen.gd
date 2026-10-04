class_name Screen
extends Control
## Base for all tabs. Subclasses implement content() and may override layout().

var main
var root_panel: PanelContainer
var scroll: ScrollContainer
var lock_refresh = false

func layout() -> String: return "full"      # "full" | "side"
func cam_view() -> String: return "persp"
func side_width() -> float: return 480.0

func can_refresh() -> bool:
	if lock_refresh or not is_inside_tree(): return false
	var f = get_viewport().gui_get_focus_owner()
	if f is LineEdit and is_ancestor_of(f): return false
	return true

## Override: return the content node (header + body). first = opened just now.
func content(_first: bool) -> Control: return Control.new()

func build_screen(first: bool) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sv = scroll.scroll_vertical if is_instance_valid(scroll) else 0
	if is_instance_valid(root_panel): root_panel.queue_free()
	root_panel = UIK.glass(18)
	if layout() == "side":
		root_panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE); root_panel.offset_left = -side_width(); root_panel.offset_right = 0
		root_panel.offset_top = 0; root_panel.offset_bottom = 0
	else:
		root_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root_panel)
	var c = content(first)
	scroll = UIK.scroll(c)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_panel.add_child(scroll)
	if not first:
		scroll.set_deferred("scroll_vertical", sv)
		(func(): if is_instance_valid(scroll): scroll.scroll_vertical = sv).call_deferred()
	else:
		_animate_in.call_deferred(c)

func _animate_in(c: Control) -> void:
	for n in c.get_children():
		if n is GridContainer or n is HFlowContainer: UIK.stagger(n, 0.12, 0.035)
		elif n is CanvasItem: UIK.appear(n, 0.05)

# ------------------------------------------------------------ helpers
func g() -> Dictionary: return Game.S
func subtabs(key: String, opts: Array, def: String) -> HFlowContainer:
	var cur: String = main.sub.get(key, def)
	var f = UIK.flow(6)
	for o in opts:
		var b = UIK.button(o[1], "Sub", func(): main.sub[key] = o[0]; Audio.ui("tick"); build_screen(true))
		b.toggle_mode = true; b.button_pressed = cur == o[0]
		if o.size() > 2 and o[2]: b.disabled = true
		f.add_child(b)
	return f
func cur_sub(key: String, def: String) -> String: return main.sub.get(key, def)
func grid_cols() -> int:
	var w: float = size.x if size.x > 10 else 1300.0
	return clampi(int(w / 380.0), 1, 4)
func trend_chip() -> PanelContainer: return UIK.chip("Тренд: " + str(Data.TRENDS.get(g().market.trend, "")), UIK.CORAL)
func empty_state(text: String, ico := "box") -> Control:
	var v = UIK.vbox(10, [UIK.icon_rect(ico, 42, UIK.MUTE), UIK.label(text, "Muted", true)])
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	(v.get_child(1) as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var c = UIK.card("Card", UIK.margin(v, 20, 30, 20, 30)); return c
