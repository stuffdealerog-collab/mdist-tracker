class_name UIK
extends RefCounted
## UI kit: theme, builders, icons and motion helpers. Everything is static.

const BG := Color("0b0f12")
const PANEL := Color(0.075, 0.095, 0.115, 0.88)
const PANEL2 := Color("161d23")
const LINE := Color(1, 1, 1, 0.075)
const INK := Color("e9edf1")
const MUTE := Color("8a97a3")
const TEAL := Color("4cb8ab")
const CORAL := Color("ff8160")
const GOLD := Color("ebc66c")
const VIOLET := Color("a98bf0")
const GOOD := Color("6be3a0")
const BAD := Color("ff6b5b")
const WARN := Color("ffc46e")

static var theme: Theme
static var f_body: Font
static var f_bold: Font
static var f_disp: Font
static var f_num: Font
static var _icons = {}

const GLASS_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(0.06, 0.08, 0.1, 0.78);
uniform float blur = 3.2;
uniform vec2 size = vec2(100.0);
uniform float radius = 14.0;
uniform vec4 border : source_color = vec4(1.0, 1.0, 1.0, 0.08);
float sd_round(vec2 p, vec2 b, float r) { vec2 q = abs(p) - b + r; return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r; }
varying vec2 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	vec2 p = lp - size * 0.5;
	float d = sd_round(p, size * 0.5, radius);
	float a = 1.0 - smoothstep(-1.0, 0.5, d);
	vec3 bg = textureLod(screen_tex, SCREEN_UV, blur).rgb;
	vec3 col = mix(bg, tint.rgb, tint.a);
	float edge = 1.0 - smoothstep(0.0, 1.2, abs(d + 0.8));
	float top = smoothstep(size.y * 0.5, -size.y * 0.5, p.y) * 0.035;
	col += vec3(top);
	col = mix(col, border.rgb, edge * border.a);
	COLOR = vec4(col, a);
}
"""

# ------------------------------------------------------------------ theme
static func build_theme() -> Theme:
	if theme: return theme
	f_body = _font("res://assets/fonts/Onest.ttf", 440)
	f_bold = _font("res://assets/fonts/Onest.ttf", 650)
	f_disp = _font("res://assets/fonts/Tektur.ttf", 600)
	f_num = _font("res://assets/fonts/JetBrainsMono.ttf", 560)
	var t = Theme.new()
	t.default_font = f_body; t.default_font_size = 15
	t.set_color("font_color", "Label", INK)
	# panels
	t.set_stylebox("panel", "PanelContainer", sb(PANEL, 14, LINE, 16))
	t.set_stylebox("panel", "Panel", sb(PANEL, 14, LINE, 0))
	_variation(t, "Card", "PanelContainer"); t.set_stylebox("panel", "Card", sb(Color(1, 1, 1, 0.035), 12, LINE, 14))
	_variation(t, "CardHi", "PanelContainer"); t.set_stylebox("panel", "CardHi", sb(Color(0.3, 0.72, 0.67, 0.08), 12, Color(0.3, 0.72, 0.67, 0.45), 14))
	_variation(t, "CardVip", "PanelContainer"); t.set_stylebox("panel", "CardVip", sb(Color(0.92, 0.78, 0.42, 0.06), 12, Color(0.92, 0.78, 0.42, 0.4), 14))
	_variation(t, "Note", "PanelContainer"); t.set_stylebox("panel", "Note", sb(Color(1, 1, 1, 0.04), 10, Color(1, 1, 1, 0.0), 10, 0, Color(0, 0, 0, 0), TEAL))
	_variation(t, "Bare", "PanelContainer"); t.set_stylebox("panel", "Bare", StyleBoxEmpty.new())
	_variation(t, "Chip", "PanelContainer"); t.set_stylebox("panel", "Chip", mg(sb(Color(1, 1, 1, 0.05), 99, Color(1, 1, 1, 0.09), 0, 0), 9, 3))
	# labels
	_label_var(t, "H1", f_disp, 30, INK); _label_var(t, "H2", f_disp, 22, INK); _label_var(t, "H3", f_bold, 16, INK)
	_label_var(t, "Eyebrow", f_bold, 11, MUTE); _label_var(t, "Muted", f_body, 14, MUTE); _label_var(t, "Small", f_body, 13, INK)
	_label_var(t, "SmallMuted", f_body, 13, MUTE); _label_var(t, "Price", f_num, 16, GOLD); _label_var(t, "Num", f_num, 15, INK)
	_label_var(t, "Big", f_disp, 44, INK); _label_var(t, "Good", f_bold, 14, GOOD); _label_var(t, "Bad", f_bold, 14, BAD)
	# buttons
	_button(t, "Button", Color(1, 1, 1, 0.06), INK, Color(1, 1, 1, 0.1))
	_variation(t, "BtnPri", "Button"); _button(t, "BtnPri", CORAL, Color("1a0d08"), CORAL.lightened(0.2))
	_variation(t, "BtnTeal", "Button"); _button(t, "BtnTeal", Color(0.3, 0.72, 0.67, 0.18), Color("bff3ea"), Color(0.3, 0.72, 0.67, 0.6))
	_variation(t, "BtnGold", "Button"); _button(t, "BtnGold", GOLD, Color("1d1606"), GOLD.lightened(0.2))
	_variation(t, "BtnGhost", "Button"); _button(t, "BtnGhost", Color(1, 1, 1, 0.0), MUTE, Color(1, 1, 1, 0.12))
	_variation(t, "Tab", "Button"); _button(t, "Tab", Color(1, 1, 1, 0.0), MUTE, Color(0, 0, 0, 0))
	t.set_stylebox("normal", "Tab", mg(sb(Color(0, 0, 0, 0), 10, Color(0, 0, 0, 0), 0), 12, 9))
	t.set_stylebox("hover", "Tab", mg(sb(Color(1, 1, 1, 0.05), 10, Color(0, 0, 0, 0), 0), 12, 9))
	t.set_stylebox("pressed", "Tab", mg(sb(Color(0.3, 0.72, 0.67, 0.14), 10, Color(0, 0, 0, 0), 0), 12, 9))
	t.set_color("font_pressed_color", "Tab", INK); t.set_color("font_hover_color", "Tab", INK)
	t.set_font("font", "Tab", f_bold); t.set_font_size("font_size", "Tab", 14)
	_variation(t, "Sub", "Button"); _button(t, "Sub", Color(1, 1, 1, 0.04), MUTE, Color(1, 1, 1, 0.06))
	t.set_stylebox("pressed", "Sub", mg(sb(Color(0.3, 0.72, 0.67, 0.2), 99, TEAL, 0), 14, 6))
	t.set_stylebox("normal", "Sub", mg(sb(Color(1, 1, 1, 0.04), 99, Color(1, 1, 1, 0.07), 0), 14, 6))
	t.set_stylebox("hover", "Sub", mg(sb(Color(1, 1, 1, 0.08), 99, Color(1, 1, 1, 0.12), 0), 14, 6))
	t.set_color("font_pressed_color", "Sub", Color("bff3ea"))
	# inputs
	var le = mg(sb(Color(0, 0, 0, 0.3), 10, Color(1, 1, 1, 0.1), 0), 12, 8)
	t.set_stylebox("normal", "LineEdit", le); t.set_stylebox("focus", "LineEdit", mg(sb(Color(0, 0, 0, 0.3), 10, TEAL, 0), 12, 8))
	t.set_color("font_color", "LineEdit", INK); t.set_color("caret_color", "LineEdit", TEAL); t.set_color("font_placeholder_color", "LineEdit", MUTE)
	t.set_stylebox("normal", "SpinBox", le)
	# progress
	t.set_stylebox("background", "ProgressBar", sb(Color(1, 1, 1, 0.07), 99, Color(0, 0, 0, 0), 0))
	t.set_stylebox("fill", "ProgressBar", sb(TEAL, 99, Color(0, 0, 0, 0), 0))
	t.set_constant("outline_size", "ProgressBar", 0)
	# scroll
	var grab = sb(Color(1, 1, 1, 0.14), 99, Color(0, 0, 0, 0), 0)
	for sbn in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", sbn, sb(Color(0, 0, 0, 0), 99, Color(0, 0, 0, 0), 0))
		t.set_stylebox("grabber", sbn, grab); t.set_stylebox("grabber_highlight", sbn, sb(Color(1, 1, 1, 0.25), 99, Color(0, 0, 0, 0), 0))
		t.set_stylebox("grabber_pressed", sbn, sb(TEAL, 99, Color(0, 0, 0, 0), 0))
	# checkbox
	t.set_color("font_color", "CheckBox", INK); t.set_color("font_hover_color", "CheckBox", INK); t.set_color("font_pressed_color", "CheckBox", INK)
	t.set_icon("checked", "CheckBox", _check_icon(true)); t.set_icon("unchecked", "CheckBox", _check_icon(false))
	t.set_icon("checked_disabled", "CheckBox", _check_icon(true, 0.4)); t.set_icon("unchecked_disabled", "CheckBox", _check_icon(false, 0.4))
	t.set_stylebox("normal", "CheckBox", StyleBoxEmpty.new()); t.set_stylebox("hover", "CheckBox", StyleBoxEmpty.new()); t.set_stylebox("pressed", "CheckBox", StyleBoxEmpty.new())
	t.set_stylebox("hover_pressed", "CheckBox", StyleBoxEmpty.new()); t.set_stylebox("focus", "CheckBox", StyleBoxEmpty.new())
	t.set_constant("h_separation", "CheckBox", 10)
	# tooltip
	t.set_stylebox("panel", "TooltipPanel", sb(Color("1b232a"), 8, LINE, 8))
	t.set_color("font_color", "TooltipLabel", INK)
	# slider
	t.set_stylebox("slider", "HSlider", mg(sb(Color(1, 1, 1, 0.1), 99, Color(0, 0, 0, 0), 0), 0, 3))
	t.set_stylebox("grabber_area", "HSlider", mg(sb(TEAL, 99, Color(0, 0, 0, 0), 0), 0, 3))
	t.set_stylebox("grabber_area_highlight", "HSlider", mg(sb(TEAL.lightened(0.2), 99, Color(0, 0, 0, 0), 0), 0, 3))
	t.set_icon("grabber", "HSlider", _dot_icon(16, INK)); t.set_icon("grabber_highlight", "HSlider", _dot_icon(18, Color.WHITE))
	# option button / popup
	t.set_stylebox("normal", "OptionButton", mg(sb(Color(1, 1, 1, 0.06), 10, LINE, 0), 12, 7))
	t.set_stylebox("hover", "OptionButton", mg(sb(Color(1, 1, 1, 0.1), 10, LINE, 0), 12, 7))
	t.set_stylebox("panel", "PopupMenu", sb(Color("1b232a"), 10, LINE, 6))
	t.set_color("font_color", "PopupMenu", INK); t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	t.set_stylebox("hover", "PopupMenu", sb(Color(0.3, 0.72, 0.67, 0.2), 6, Color(0, 0, 0, 0), 0))
	theme = t
	return t

static func _font(path: String, wght: int) -> Font:
	var fv = FontVariation.new()
	var base: FontFile = load(path)
	fv.base_font = base
	fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): wght}
	return fv

static func _variation(t: Theme, name: String, base: String) -> void: t.set_type_variation(name, base)
static func _label_var(t: Theme, name: String, f: Font, size: int, col: Color) -> void:
	t.set_type_variation(name, "Label"); t.set_font("font", name, f); t.set_font_size("font_size", name, size); t.set_color("font_color", name, col)

static func mg(s: StyleBoxFlat, h: int, v: int) -> StyleBoxFlat:
	s.content_margin_left = h; s.content_margin_right = h; s.content_margin_top = v; s.content_margin_bottom = v
	return s

static func sb(bg: Color, r: int, border: Color, pad := 12, bw := 1, shadow := Color(0, 0, 0, 0), left_accent := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg; s.set_corner_radius_all(r); s.corner_detail = 8; s.anti_aliasing = true
	if border.a > 0.0: s.border_color = border; s.set_border_width_all(bw)
	if left_accent.a > 0.0: s.border_color = left_accent; s.border_width_left = 3; s.border_width_top = 0; s.border_width_right = 0; s.border_width_bottom = 0
	s.content_margin_left = pad; s.content_margin_right = pad; s.content_margin_top = pad; s.content_margin_bottom = pad
	if shadow.a > 0.0: s.shadow_color = shadow; s.shadow_size = 18; s.shadow_offset = Vector2(0, 8)
	return s

static func _button(t: Theme, name: String, bg: Color, fg: Color, hover: Color) -> void:
	var pad_h = 16; var pad_v = 9
	var n = mg(sb(bg, 10, Color(1, 1, 1, 0.06) if bg.a < 0.5 else Color(0, 0, 0, 0), 0), pad_h, pad_v)
	var h = mg(sb(hover if hover.a > 0.0 else bg, 10, Color(1, 1, 1, 0.1) if bg.a < 0.5 else Color(0, 0, 0, 0), 0), pad_h, pad_v)
	var p = mg(sb(bg.darkened(0.15) if bg.a > 0.5 else Color(1, 1, 1, 0.14), 10, Color(0, 0, 0, 0), 0), pad_h, pad_v)
	var d = mg(sb(Color(1, 1, 1, 0.03), 10, Color(1, 1, 1, 0.04), 0), pad_h, pad_v)
	t.set_stylebox("normal", name, n); t.set_stylebox("hover", name, h); t.set_stylebox("pressed", name, p); t.set_stylebox("disabled", name, d)
	t.set_stylebox("focus", name, StyleBoxEmpty.new()); t.set_stylebox("hover_pressed", name, p)
	t.set_color("font_color", name, fg); t.set_color("font_hover_color", name, fg if bg.a > 0.5 else INK); t.set_color("font_pressed_color", name, fg)
	t.set_color("font_disabled_color", name, Color(MUTE, 0.55)); t.set_color("font_focus_color", name, fg); t.set_color("font_hover_pressed_color", name, fg)
	t.set_color("icon_normal_color", name, fg); t.set_color("icon_hover_color", name, fg if bg.a > 0.5 else INK)
	t.set_font("font", name, f_bold); t.set_font_size("font_size", name, 14)
	t.set_constant("h_separation", name, 8)

static func _check_icon(on: bool, alpha := 1.0) -> Texture2D:
	var img = Image.create(22, 22, false, Image.FORMAT_RGBA8)
	for y in 22:
		for x in 22:
			var d = Vector2(x - 10.5, y - 10.5)
			var box: float = max(abs(d.x), abs(d.y))
			var c = Color(0, 0, 0, 0)
			if box < 10.0:
				c = Color(TEAL, alpha) if on else Color(1, 1, 1, 0.08 * alpha)
				if box > 8.6 and not on: c = Color(1, 1, 1, 0.3 * alpha)
			img.set_pixel(x, y, c)
	if on:
		for i in 6: img.set_pixel(5 + i, 10 + i / 2, Color("0b2a26")); img.set_pixel(5 + i, 11 + i / 2, Color("0b2a26"))
		for i in 8: img.set_pixel(10 + i, 13 - i, Color("0b2a26")); img.set_pixel(10 + i, 14 - i, Color("0b2a26"))
	return ImageTexture.create_from_image(img)

static func _dot_icon(s: int, col: Color) -> Texture2D:
	var img = Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var d = Vector2(x - s / 2.0 + 0.5, y - s / 2.0 + 0.5).length()
			img.set_pixel(x, y, Color(col, clamp(s / 2.0 - d, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)

# ------------------------------------------------------------------ icons
const ICONS := {
	"wrench": "<path d='M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z'/>",
	"clipboard": "<rect x='8' y='2' width='8' height='4' rx='1'/><path d='M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2'/><path d='M9 12h6M9 16h6'/>",
	"store": "<path d='M3 9l1.5-5h15L21 9'/><path d='M4 9v11h16V9'/><path d='M3 9a3 3 0 0 0 6 0a3 3 0 0 0 6 0a3 3 0 0 0 6 0'/><path d='M10 20v-6h4v6'/>",
	"box": "<path d='M21 8l-9-5-9 5v8l9 5 9-5z'/><path d='M3 8l9 5 9-5M12 13v8'/>",
	"cart": "<circle cx='9' cy='21' r='1'/><circle cx='20' cy='21' r='1'/><path d='M1 1h4l2.7 13.4a2 2 0 0 0 2 1.6h9.7a2 2 0 0 0 2-1.6L23 6H6'/>",
	"map": "<path d='M1 6v16l7-4 8 4 7-4V2l-7 4-8-4z'/><path d='M8 2v16M16 6v16'/>",
	"gift": "<rect x='3' y='8' width='18' height='4'/><path d='M12 8v13M5 12v9h14v-9'/><path d='M7.5 8a2.5 2.5 0 0 1 0-5C11 3 12 8 12 8s1-5 4.5-5a2.5 2.5 0 0 1 0 5'/>",
	"swap": "<path d='M17 1l4 4-4 4'/><path d='M3 11V9a4 4 0 0 1 4-4h14'/><path d='M7 23l-4-4 4-4'/><path d='M21 13v2a4 4 0 0 1-4 4H3'/>",
	"trend": "<path d='M23 6l-9.5 9.5-5-5L1 18'/><path d='M17 6h6v6'/>",
	"calendar": "<rect x='3' y='4' width='18' height='18' rx='2'/><path d='M16 2v4M8 2v4M3 10h18'/>",
	"trophy": "<path d='M8 21h8M12 17v4M7 4h10v5a5 5 0 0 1-10 0z'/><path d='M17 5h3v2a3 3 0 0 1-3 3M7 5H4v2a3 3 0 0 0 3 3'/>",
	"gear": "<circle cx='12' cy='12' r='3'/><path d='M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z'/>",
	"help": "<circle cx='12' cy='12' r='10'/><path d='M9.1 9a3 3 0 0 1 5.8 1c0 2-3 3-3 3M12 17h.01'/>",
	"sound": "<path d='M11 5L6 9H2v6h4l5 4z'/><path d='M15.5 8.5a5 5 0 0 1 0 7M19 5a10 10 0 0 1 0 14'/>",
	"mute": "<path d='M11 5L6 9H2v6h4l5 4z'/><path d='M23 9l-6 6M17 9l6 6'/>",
	"coin": "<circle cx='12' cy='12' r='9'/><path d='M14.5 9a2.5 2.5 0 0 0-2.5-1.5c-1.5 0-2.5.8-2.5 2s1 1.7 2.5 2 2.5.8 2.5 2-1 2-2.5 2A2.5 2.5 0 0 1 9.5 15M12 6v1.5M12 16.5V18'/>",
	"star": "<path d='M12 2l3.1 6.3 6.9 1-5 4.9 1.2 6.8L12 17.8 5.8 21l1.2-6.8-5-4.9 6.9-1z'/>",
	"globe": "<circle cx='12' cy='12' r='10'/><path d='M2 12h20M12 2a15 15 0 0 1 0 20M12 2a15 15 0 0 0 0 20'/>",
	"lock": "<rect x='4' y='11' width='16' height='10' rx='2'/><path d='M8 11V7a4 4 0 0 1 8 0v4'/>",
	"keyboard": "<rect x='2' y='6' width='20' height='12' rx='2'/><path d='M6 10h.01M10 10h.01M14 10h.01M18 10h.01M8 14h8'/>",
	"truck": "<path d='M1 3h15v13H1zM16 8h4l3 3v5h-7z'/><circle cx='5.5' cy='18.5' r='2.5'/><circle cx='18.5' cy='18.5' r='2.5'/>",
	"home": "<path d='M3 10l9-7 9 7v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z'/><path d='M9 22V12h6v10'/>",
	"user": "<circle cx='12' cy='8' r='4'/><path d='M4 21a8 8 0 0 1 16 0'/>",
	"x": "<path d='M18 6L6 18M6 6l12 12'/>",
	"check": "<path d='M20 6L9 17l-5-5'/>",
	"play": "<path d='M6 3l14 9-14 9z'/>",
	"rotate": "<path d='M1 4v6h6'/><path d='M3.5 15a9 9 0 1 0 2.1-9.4L1 10'/>",
	"zap": "<path d='M13 2L3 14h9l-1 8 10-12h-9z'/>",
	"eye": "<path d='M1 12s4-8 11-8 11 8 11 8-4 8-11 8S1 12 1 12z'/><circle cx='12' cy='12' r='3'/>",
	"hand": "<path d='M18 11V6a2 2 0 0 0-4 0v5M14 10V4a2 2 0 0 0-4 0v6M10 10.5V6a2 2 0 0 0-4 0v8'/><path d='M18 8a2 2 0 1 1 4 0v6a8 8 0 0 1-8 8h-2c-2.8 0-4.5-.9-6-2.4l-3.6-3.6a2 2 0 0 1 2.8-2.8L7 15'/>",
	"cloud": "<path d='M18 10h-1.3A8 8 0 1 0 9 20h9a5 5 0 0 0 0-10z'/>",
}

static func icon(name: String, size := 20, col := Color.WHITE) -> Texture2D:
	var key = "%s|%d|%s" % [name, size, col.to_html()]
	if _icons.has(key): return _icons[key]
	var svg = "<svg xmlns='http://www.w3.org/2000/svg' width='%d' height='%d' viewBox='0 0 24 24' fill='none' stroke='#%s' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'>%s</svg>" % [size, size, col.to_html(false), ICONS.get(name, "")]
	var img = Image.new()
	if img.load_svg_from_string(svg, 1.0) != OK: img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var t = ImageTexture.create_from_image(img)
	_icons[key] = t
	return t

static func icon_rect(name: String, size := 20, col := INK) -> TextureRect:
	var tr = TextureRect.new(); tr.texture = icon(name, size * 2, col); tr.custom_minimum_size = Vector2(size, size)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

# ---------------------------------------------------------------- builders
static func vbox(sep := 10, children := []) -> VBoxContainer:
	var b = VBoxContainer.new(); b.add_theme_constant_override("separation", sep)
	for c in children: if c: b.add_child(c)
	return b
static func hbox(sep := 10, children := []) -> HBoxContainer:
	var b = HBoxContainer.new(); b.add_theme_constant_override("separation", sep)
	for c in children: if c: b.add_child(c)
	return b
static func flow(sep := 6, children := []) -> HFlowContainer:
	var b = HFlowContainer.new(); b.add_theme_constant_override("h_separation", sep); b.add_theme_constant_override("v_separation", sep)
	for c in children: if c: b.add_child(c)
	return b
static func grid(cols: int, sep := 12) -> GridContainer:
	var g = GridContainer.new(); g.columns = cols; g.add_theme_constant_override("h_separation", sep); g.add_theme_constant_override("v_separation", sep)
	g.child_entered_tree.connect(func(c): if c is Control: (c as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL)
	return g
static func label(text: String, variation := "", wrap := false) -> Label:
	var l = Label.new(); l.text = text
	if variation != "": l.theme_type_variation = variation
	if wrap: l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; l.custom_minimum_size.x = 40
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
static func colored(text: String, col: Color, variation := "") -> Label:
	var l = label(text, variation); l.add_theme_color_override("font_color", col); return l
static func rich(bb: String, size := 15) -> RichTextLabel:
	var r = RichTextLabel.new(); r.bbcode_enabled = true; r.fit_content = true; r.scroll_active = false; r.text = bb
	r.add_theme_font_override("normal_font", f_body); r.add_theme_font_override("bold_font", f_bold); r.add_theme_font_override("mono_font", f_num)
	r.add_theme_font_size_override("normal_font_size", size); r.add_theme_font_size_override("bold_font_size", size); r.add_theme_font_size_override("mono_font_size", size)
	r.add_theme_color_override("default_color", INK); r.mouse_filter = Control.MOUSE_FILTER_PASS; r.custom_minimum_size.x = 40
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return r
static func button(text: String, variation := "", cb = null, ico := "") -> Button:
	var b = Button.new(); b.text = text
	if variation != "": b.theme_type_variation = variation
	if ico != "": b.icon = icon(ico, 36, Color.WHITE); b.expand_icon = false; b.add_theme_constant_override("icon_max_width", 18)
	if cb is Callable: b.pressed.connect(cb)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.focus_mode = Control.FOCUS_NONE
	juice(b)
	return b
static func card(variation := "Card", child: Control = null) -> PanelContainer:
	var p = PanelContainer.new(); p.theme_type_variation = variation
	if child: p.add_child(child)
	return p
static func chip(text: String, col := Color(0, 0, 0, 0)) -> PanelContainer:
	var p = PanelContainer.new(); p.theme_type_variation = "Chip"
	var l = label(text, "Small")
	if col.a > 0.0:
		l.add_theme_color_override("font_color", col)
		var s = mg(sb(Color(col, 0.12), 99, Color(col, 0.35), 0), 9, 3); p.add_theme_stylebox_override("panel", s)
	p.add_child(l); p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p
static func note(text: String, accent := TEAL) -> PanelContainer:
	var p = card("Note"); var s: StyleBoxFlat = sb(Color(1, 1, 1, 0.04), 10, Color(0, 0, 0, 0), 12, 1, Color(0, 0, 0, 0), accent)
	p.add_theme_stylebox_override("panel", s); p.add_child(rich(text, 14)); return p
static func meter(text: String, val: float, col: Color, w := 0.0) -> HBoxContainer:
	var l = label(text, "SmallMuted"); l.custom_minimum_size.x = 112
	var pb = bar(val / 100.0, col); pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var n = label(str(int(round(val))), "Num"); n.custom_minimum_size.x = 32; n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var h = hbox(10, [l, pb, n]); h.alignment = BoxContainer.ALIGNMENT_CENTER
	return h
static func bar(v: float, col := TEAL, h := 7.0) -> ProgressBar:
	var pb = ProgressBar.new(); pb.min_value = 0; pb.max_value = 1; pb.step = 0.0001; pb.show_percentage = false
	pb.custom_minimum_size = Vector2(40, h)
	pb.add_theme_stylebox_override("fill", sb(col, 99, Color(0, 0, 0, 0), 0))
	pb.value = 0.0
	pb.create_tween().tween_property(pb, "value", clamp(v, 0.0, 1.0), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pb
static func swatch(col: Color, s := 14) -> Panel:
	var p = Panel.new(); p.custom_minimum_size = Vector2(s, s)
	p.add_theme_stylebox_override("panel", sb(col, s / 2, Color(1, 1, 1, 0.25), 0)); p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p
static func spacer(expand := true, h := 0) -> Control:
	var c = Control.new(); c.custom_minimum_size.y = h
	if expand: c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c
static func vspace(h: int) -> Control:
	var c = Control.new(); c.custom_minimum_size.y = h; c.mouse_filter = Control.MOUSE_FILTER_IGNORE; return c
static func sep() -> HSeparator:
	var s = HSeparator.new(); s.add_theme_stylebox_override("separator", mg(sb(LINE, 0, Color(0, 0, 0, 0), 0), 0, 0)); s.add_theme_constant_override("separation", 10); return s
static func scroll(child: Control) -> ScrollContainer:
	var s = ScrollContainer.new(); s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(child); return s
static func expand(c: Control, h := true, v := false) -> Control:
	if h: c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if v: c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c
static func margin(c: Control, l: int, t: int, r: int, b: int) -> MarginContainer:
	var m = MarginContainer.new()
	m.add_theme_constant_override("margin_left", l); m.add_theme_constant_override("margin_top", t)
	m.add_theme_constant_override("margin_right", r); m.add_theme_constant_override("margin_bottom", b)
	m.add_child(c); return m
static func head(eyebrow: String, title: String, right: Array = []) -> HBoxContainer:
	var v = vbox(2, [label(eyebrow.to_upper(), "Eyebrow"), label(title, "H2")])
	var h = hbox(10, [v, spacer()])
	for r in right: h.add_child(r)
	h.alignment = BoxContainer.ALIGNMENT_END
	return h
static func stars(n: int) -> Label:
	var l = label("★".repeat(n) + "☆".repeat(5 - n), "H3"); l.add_theme_color_override("font_color", GOLD); return l
static func glass(radius := 16.0, tint := Color(0.06, 0.08, 0.1, 0.78)) -> PanelContainer:
	var p = PanelContainer.new()
	var box := StyleBoxFlat.new(); box.bg_color = Color.WHITE
	box.content_margin_left = 18; box.content_margin_right = 18; box.content_margin_top = 18; box.content_margin_bottom = 18
	p.add_theme_stylebox_override("panel", box)
	var m = ShaderMaterial.new(); m.shader = _glass_shader(); m.set_shader_parameter("radius", radius); m.set_shader_parameter("tint", tint)
	p.material = m
	p.resized.connect(func(): m.set_shader_parameter("size", p.size))
	return p

static var _gs: Shader
static func _glass_shader() -> Shader:
	if _gs == null: _gs = Shader.new(); _gs.code = GLASS_SHADER
	return _gs

# ------------------------------------------------------------------ motion
static func juice(c: Control) -> void:
	c.resized.connect(func(): c.pivot_offset = c.size / 2.0)
	c.mouse_entered.connect(func():
		if c is BaseButton and (c as BaseButton).disabled: return
		_tw(c, "scale", Vector2.ONE * 1.035, 0.14)
		if c is Button: Audio.ui("hover"))
	c.mouse_exited.connect(func(): _tw(c, "scale", Vector2.ONE, 0.18))
	if c is BaseButton:
		(c as BaseButton).button_down.connect(func(): _tw(c, "scale", Vector2.ONE * 0.95, 0.06))
		(c as BaseButton).button_up.connect(func(): _tw(c, "scale", Vector2.ONE * 1.035, 0.16, Tween.TRANS_BACK))
		(c as BaseButton).pressed.connect(func(): Audio.ui("click"))

static func _tw(c: Object, prop: String, v, t: float, trans := Tween.TRANS_CUBIC) -> Tween:
	if not is_instance_valid(c): return null
	var key = "_tw_" + prop
	if c.has_meta(key):
		var old = c.get_meta(key)
		if old is Tween and (old as Tween).is_valid(): (old as Tween).kill()
	var tw = (c as Node).create_tween().set_trans(trans).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, prop, v, t)
	c.set_meta(key, tw)
	return tw

## Fade + rise in (works inside containers: animates scale/modulate only).
static func appear(c: CanvasItem, delay := 0.0, dur := 0.38) -> void:
	c.modulate.a = 0.0
	if c is Control:
		var cc = c as Control
		cc.pivot_offset = Vector2(cc.size.x / 2.0, cc.size.y)
		cc.scale = Vector2(0.97, 0.97)
	var tw = c.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, dur).set_delay(delay)
	if c is Control: tw.tween_property(c, "scale", Vector2.ONE, dur + 0.1).set_delay(delay).set_trans(Tween.TRANS_BACK)

static func stagger(parent: Node, start := 0.0, step := 0.035, max_n := 24) -> void:
	var i = 0
	for ch in parent.get_children():
		if ch is CanvasItem and (ch as CanvasItem).visible:
			appear(ch, start + min(i, max_n) * step); i += 1

static func pop(c: Control, amount := 1.12) -> void:
	c.pivot_offset = c.size / 2.0
	var tw = c.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2.ONE * amount, 0.08); tw.tween_property(c, "scale", Vector2.ONE, 0.32)

static func shake(c: Control, px := 8.0) -> void:
	var x0 = c.position.x
	var tw = c.create_tween()
	for i in 6: tw.tween_property(c, "position:x", x0 + (px if i % 2 == 0 else -px) * (1.0 - i / 6.0), 0.04)
	tw.tween_property(c, "position:x", x0, 0.04)

static func ticker(l: Label, from: float, to: float, fmt_fn: Callable, dur := 0.7) -> void:
	if l.has_meta("tick_tw"):
		var o = l.get_meta("tick_tw")
		if o is Tween and o.is_valid(): o.kill()
	var tw = l.create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float): l.text = fmt_fn.call(v), from, to, dur)
	l.set_meta("tick_tw", tw)
