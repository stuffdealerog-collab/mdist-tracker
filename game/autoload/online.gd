extends Node
## Online client for the KSS server (server/ in the repo).
## Player-to-player trading works with "online items": items minted by the server
## when a box is opened online. The server is the authority for who owns them.

signal status_changed(online: bool)
signal market_updated
signal inbox_received(items: Array)
signal leaderboard_updated

var online = false
var busy = false
var offers: Array = []
var my_offers: Array = []
var leaderboard: Array = []
var _poll = 0.0
var _last_score = -1.0

func base() -> String: return str(Game.S.settings.get("server", "")).trim_suffix("/")

## A "server.txt" next to the executable (or in the project) sets the server for players
## who never changed it in the settings. Lets you switch servers without rebuilding.
func default_server() -> String:
	for p in [OS.get_executable_path().get_base_dir().path_join("server.txt"), "res://server.txt"]:
		if FileAccess.file_exists(p):
			var t := FileAccess.get_file_as_string(p).strip_edges()
			if t != "": return t
	return ""

func start() -> void:
	var d := default_server()
	var cur := str(Game.S.settings.get("server", ""))
	if d != "" and (cur == "" or cur == "http://localhost:8787"): Game.S.settings.server = d
	if Game.S.online.get("device", "") == "":
		var id = OS.get_unique_id()
		Game.S.online.device = id if id != "" else str(randi()) + str(Time.get_ticks_usec())
	await connect_server()

func connect_server() -> void:
	if base() == "": _set_online(false); return
	var name = SteamBridge.player_name()
	if name == "": name = str(Game.S.shop)
	var r = await req("POST", "/auth", {"device": Game.S.online.device, "token": Game.S.online.get("token", ""), "name": name})
	if r.ok:
		Game.S.online.token = r.data.token; Game.S.online.pid = r.data.pid; Game.mark()
		_set_online(true)
		await refresh_all()
	else:
		_set_online(false)

func _set_online(v: bool) -> void:
	if v != online:
		online = v; status_changed.emit(v)

func _process(delta: float) -> void:
	if Game.S.is_empty(): return
	_poll += delta
	if _poll > 25.0:
		_poll = 0.0
		if online: refresh_all()
		else: connect_server()

func req(method: String, path: String, body = null) -> Dictionary:
	var h = HTTPRequest.new(); h.timeout = 8.0; add_child(h)
	var headers = PackedStringArray(["Content-Type: application/json"])
	if Game.S.online.get("token", "") != "": headers.append("Authorization: Bearer " + str(Game.S.online.token))
	var m = HTTPClient.METHOD_GET
	match method:
		"POST": m = HTTPClient.METHOD_POST
		"DELETE": m = HTTPClient.METHOD_DELETE
	var err = h.request(base() + path, headers, m, JSON.stringify(body) if body != null else "")
	if err != OK:
		h.queue_free(); return {"ok": false, "code": 0, "data": {}}
	var res = await h.request_completed
	h.queue_free()
	var code: int = res[1]
	var data = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8()) if (res[3] as PackedByteArray).size() > 0 else {}
	if data == null: data = {}
	if res[0] != HTTPRequest.RESULT_SUCCESS:
		_set_online(false); return {"ok": false, "code": 0, "data": {}}
	return {"ok": code >= 200 and code < 300, "code": code, "data": data}

func refresh_all() -> void:
	await fetch_inbox()
	await fetch_market()
	await push_score()

# ---- boxes ---------------------------------------------------------------
## Opens a box on the server (server-side roll, item gets an online uid).
## Falls back to a local roll when offline. Returns the won entry.
func open_box(id: String) -> Dictionary:
	if int(Game.S.inv.boxes.get(id, 0)) < 1: return {}
	if online:
		var r = await req("POST", "/boxes/open", {"box": id, "luck": Game.skl("luck") * 0.15 + Game.perk("drop") * 0.1})
		if r.ok and r.data.has("item"):
			Game.S.inv.boxes[id] = int(Game.S.inv.boxes[id]) - 1
			var e: Dictionary = r.data.item
			Game.grant_entry(e, str(e.get("uid", "")))
			Game.S.stats.boxes += 1; Game.track("box", 1); Game.mark()
			return e
	return Game.open_box_local(id)

# ---- market ----------------------------------------------------------------
func fetch_market() -> void:
	var r = await req("GET", "/market")
	if r.ok:
		offers = r.data.get("offers", []); my_offers = r.data.get("mine", [])
		market_updated.emit()

## Online items the player can put on the market.
func my_online_items() -> Array:
	return Game.tradeable_items().filter(func(t): return online_uid_of(t) != "")
func online_uid_of(t: Dictionary) -> String:
	if t.kind == "art" and "#" in str(t.ref): return str(t.ref).split("#")[1]
	if t.kind == "kc":
		var it = Game.item_by_uid(t.ref)
		return str(it.get("ouid", ""))
	return ""

func create_offer(give: Dictionary, want: Dictionary) -> bool:
	var ou = online_uid_of(give)
	if ou == "": Game.toast("С игроками можно меняться только онлайн-предметами из коробок", "bad"); return false
	var r = await req("POST", "/market", {"give_uid": ou, "want": want})
	if r.ok:
		Game.remove_trade_item(give); Game.mark(); Audio.ui("good")
		Game.toast("Предложение выставлено на барахолку", "gold"); await fetch_market(); return true
	Game.toast(str(r.data.get("error", "Сервер не принял предложение")), "bad"); return false

func accept_offer(offer: Dictionary, give: Dictionary) -> bool:
	var ou = online_uid_of(give)
	if ou == "": Game.toast("Для обмена с игроком нужен онлайн-предмет", "bad"); return false
	var r = await req("POST", "/market/%s/accept" % offer.id, {"give_uid": ou})
	if r.ok:
		Game.remove_trade_item(give)
		var e: Dictionary = r.data.item
		Game.grant_entry(e, str(e.uid)); Game.S.stats.trades += 1; Game.mark()
		Audio.ui("rare"); Game.toast("Обмен состоялся: вы получили %s" % e.name, "gold"); Game.item_won.emit(e)
		await fetch_market(); return true
	Game.toast(str(r.data.get("error", "Обмен не удался")), "bad"); return false

func cancel_offer(offer_id: String) -> void:
	var r = await req("DELETE", "/market/%s" % offer_id)
	if r.ok: Game.toast("Предложение снято, предмет вернётся в инвентарь"); await fetch_inbox(); await fetch_market()

func fetch_inbox() -> void:
	var r = await req("GET", "/inbox")
	if r.ok and r.data.get("items", []).size() > 0:
		var got: Array = r.data.items
		for e in got: Game.grant_entry(e, str(e.uid))
		if got.size() > 0:
			Game.S.stats.trades += got.filter(func(e): return e.get("via", "") == "trade").size()
			Audio.ui("rare"); Game.toast("Пришли предметы: " + ", ".join(got.map(func(e): return e.name)), "vio")
			inbox_received.emit(got); Game.mark()

func consume_item(ouid: String) -> void:
	if online and ouid != "": req("POST", "/items/%s/consume" % ouid, {})

# ---- leaderboard -----------------------------------------------------------
func push_score() -> void:
	if not online: return
	var s = float(Game.S.stats.earnedAll)
	if s == _last_score: return
	_last_score = s
	await req("POST", "/score", {"name": str(Game.S.shop), "earned": s, "level": int(Game.S.level), "built": int(Game.S.stats.built), "city": Data.CITIES[int(Game.S.prestige.city)]})
func push_contest(score: float) -> void:
	if online: req("POST", "/contest", {"week": Game.week_no(), "score": score, "name": str(Game.S.shop)})
func fetch_leaderboard() -> void:
	var r = await req("GET", "/leaderboard")
	if r.ok:
		leaderboard = r.data.get("top", []); leaderboard_updated.emit()
