extends Node
func _ready() -> void:
	var out := {"switches": Data.SWITCHES, "keycaps": Data.KEYCAPS, "artisans": Data.ARTISANS, "boxes": [], "odds": Data.BOX_ODDS, "odds_pro": Data.BOX_ODDS_PRO, "l65": Data.LAYOUTS.l65.count, "tkl": Data.LAYOUTS.tkl.count}
	for b in Data.BOXES: out.boxes.append({"id": b.id, "pool": b.pool, "name": b.name})
	var f := FileAccess.open("res://server/pools.json", FileAccess.WRITE); f.store_string(JSON.stringify(out, " ")); f.close()
	print("pools ok"); get_tree().quit()
