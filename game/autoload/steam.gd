extends Node
## Steam bridge. Works without Steam: every call is a no-op until the GodotSteam
## extension is installed and the game runs under a real App ID.

var available = false
var steam = null

func _ready() -> void:
	if Engine.has_singleton("Steam"):
		steam = Engine.get_singleton("Steam")
		var r = steam.steamInitEx(false) if steam.has_method("steamInitEx") else steam.steamInit()
		available = r is Dictionary and int(r.get("status", 1)) == 0 or r == true

func _process(_d: float) -> void:
	if available: steam.run_callbacks()

func unlock(ach_id: String) -> void:
	if not available: return
	steam.setAchievement("ACH_" + ach_id.to_upper()); steam.storeStats()

func player_name() -> String:
	return steam.getPersonaName() if available else ""
