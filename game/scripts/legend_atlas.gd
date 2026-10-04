class_name LegendAtlas
extends SubViewport
## Renders every keycap legend once into a 16x16 grid texture.
## Index = label slot * 2 (+1 for the centered variant).

static var index := {}
const CELL := 128
const GRID := 16

func build() -> void:
	size = Vector2i(CELL * GRID, CELL * GRID)
	transparent_bg = true
	render_target_update_mode = SubViewport.UPDATE_ONCE
	disable_3d = true
	var labels := {}
	for lid in Data.LAYOUTS:
		for k in Data.LAYOUTS[lid].keys: labels[str(k.label)] = true
	var font := FontVariation.new()
	font.base_font = load("res://assets/fonts/JetBrainsMono.ttf")
	font.variation_opentype = {"wght": 760}
	var slot := 0
	index.clear()
	for lab in labels:
		if slot >= GRID * GRID / 2: break
		index[lab] = slot * 2
		for variant in 2:
			var cell := slot * 2 + variant
			var cx := cell % GRID; var cy := cell / GRID
			var L := Label.new()
			L.text = lab
			L.add_theme_font_override("font", font)
			var fs := 54 if lab.length() <= 1 else (40 if lab.length() <= 2 else (30 if lab.length() <= 4 else 24))
			L.add_theme_font_size_override("font_size", fs)
			L.add_theme_color_override("font_color", Color.WHITE)
			L.position = Vector2(cx * CELL, cy * CELL)
			L.size = Vector2(CELL, CELL)
			if variant == 0:
				L.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT; L.vertical_alignment = VERTICAL_ALIGNMENT_TOP
				L.position += Vector2(22, 16); L.size -= Vector2(22, 16)
			else:
				L.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; L.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			add_child(L)
		slot += 1
	Mats.set_atlas(get_texture())

static func idx(label: String, centered: bool) -> float:
	if not index.has(label): return -1.0
	return float(index[label] + (1 if centered else 0))
