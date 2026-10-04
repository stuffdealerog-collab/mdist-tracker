extends Node
## Client <-> server integration. Expects a server on 127.0.0.1:8899. Player B is driven by server/peer.mjs.
func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	Game.boot()
	Game.S.settings.server = "http://127.0.0.1:8899"
	Game.S.online.device = "godot-client-%d" % randi()
	await Online.connect_server()
	print("ONLINE ", Online.online, " pid ", Game.S.online.pid)
	Game.S.money = 1000000; Game.S.level = 20
	Game.buy_box("box_art")
	var e: Dictionary = await Online.open_box("box_art")
	print("BOX ", e.get("name"), " uid ", e.get("uid", ""))
	var mine := Online.my_online_items()
	print("ONLINE ITEMS ", mine.size())
	var ok: bool = await Online.create_offer(mine[0], {"kind": "art", "rarity": "common"})
	print("OFFER ", ok, " mine ", Online.my_offers.size())
	var f := FileAccess.open("/tmp/kss_client_ready", FileAccess.WRITE); f.store_string(Game.S.online.pid); f.close()
	# wait for peer to accept
	for i in 40:
		await get_tree().create_timer(0.5).timeout
		if FileAccess.file_exists("/tmp/kss_peer_done"): break
	var before: int = Game.S.inv.art.size()
	await Online.fetch_inbox()
	print("INBOX art before ", before, " after ", Game.S.inv.art.size(), " trades ", Game.S.stats.trades)
	await Online.push_score()
	await Online.fetch_leaderboard()
	print("LEADERBOARD ", Online.leaderboard.size())
	print("CLIENT_DONE")
	get_tree().quit()
