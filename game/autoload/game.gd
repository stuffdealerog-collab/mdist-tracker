extends Node
## Game state + all rules. State lives in one Dictionary (S) so it saves as JSON.

signal changed                       # anything visible changed
signal money_changed(delta: float)
signal notify(text: String, kind: String)
signal level_up(level: int, unlocked: Array)
signal item_won(entry: Dictionary)   # box/trade reward (for big reveal)
signal day_passed(day: int)
signal board_built(board: Dictionary)

const SAVE_PATH := "user://save.json"
const VERSION := 1

var S: Dictionary = {}
var dirty = false
var _save_timer = 0.0
var _sale_acc = 0.0
var _daily_acc = 0.0
var paused = false

# ------------------------------------------------------------------ helpers
func fmt(n) -> String:
	var v = int(round(float(n)))
	var neg = v < 0
	var s = str(abs(v))
	var out = ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if neg else "") + s + out
func rub(n) -> String: return fmt(n) + " ₽"
func now() -> float: return Time.get_unix_time_from_system()
func today_str(offset_days := 0) -> String:
	var t = int(now()) + Time.get_time_zone_from_system().bias * 60 + offset_days * 86400
	return Time.get_date_string_from_unix_time(t)
func week_no(t := -1.0) -> int:
	if t < 0: t = now()
	return int(floor((t + Time.get_time_zone_from_system().bias * 60.0 + 3.0 * 86400.0) / (7.0 * 86400.0)))
func week_ends_in() -> float:
	var w = week_no(); var t = now(); var n = 0
	while week_no(t) == w and n < 200: t += 3600.0; n += 1
	return t - now()
func dur(sec: float) -> String:
	sec = max(0.0, sec)
	var m = int(sec / 60.0); var h = m / 60; var d = h / 24
	if d > 0: return "%d д %d ч" % [d, h % 24]
	if h > 0: return "%d ч %d мин" % [h, m % 60]
	if m > 0: return "%d мин" % m
	return "%d с" % int(ceil(sec))
func seeded(seed_str: String) -> RandomNumberGenerator:
	var r = RandomNumberGenerator.new(); r.seed = hash(seed_str); return r
func uid() -> int:
	S.uid = int(S.uid) + 1
	return S.uid
func toast(t: String, kind := "") -> void: notify.emit(t, kind)
func mark() -> void:
	dirty = true
	changed.emit()

# ------------------------------------------------------------------ state
func new_state(prev: Dictionary = {}) -> Dictionary:
	var st = {
		"v": VERSION, "created": now(), "savedAt": 0.0,
		"shop": prev.get("shop", "Мастерская «Тёплый клик»"),
		"money": 25000.0, "xp": 0.0, "level": 1, "rep": 2.5, "day": 1, "dayT": 0.0, "lastTick": now(), "lastRepair": now(),
		"inv": {"items": [], "sw": {}, "cons": {"lube": 1, "stablube": 1}, "art": [], "boxes": {}},
		"boards": [], "listings": [], "orders": [], "log": [],
		"up": {}, "sk": {}, "sp": 0,
		"stats": {"built":0,"orders":0,"five":0,"sold":0,"earned":0.0,"earnedAll":0.0,"maxSale":0.0,"maxThock":0,"minLoud":100,"maxQ":0,"perfectLube":0,"fullBuilt":0,"gb":0,"contestWins":0,"keys":0,"bought":0,"listed":0,"loginClaims":0,"boxes":0,"trades":0,"props":0,"repairs":0},
		"col": {"sw": {}, "kc": {}, "art": {}}, "ach": {},
		"daily": {"date":"", "tasks":[], "bonus":false, "prog":{}},
		"weekly": {"week":0, "task":null, "prog":0.0, "claimed":false, "contest":null, "result":null, "npcLvl":1},
		"login": {"last":"", "streak":0, "best":0, "claimed":""},
		"gb": {"week":0, "pending":[], "boughtArt":0},
		"vip": {},
		"prestige": {"count":0, "legend":0, "perks":{}, "city":0},
		"market": {"mult":{}, "trend":"thock", "trendDay":1, "event":null, "supplier":"import"},
		"property": "garage", "owned_props": ["garage"],
		"traders": {"day":-1, "offers":[]},
		"online": {"token":"", "pid":"", "name":""},
		"build": null, "tut": 0, "tutv": 2, "uid": 100, "seenIntro": false, "hints": {},
		"settings": {"vol":0.8, "music":0.4, "sound":true, "gfx":"high", "server":"http://localhost:8787"},
	}
	if not prev.is_empty():
		for k in ["col","ach","login","settings","vip","prestige","online","hints"]: st[k] = prev[k]
		st.tut = 99; st.seenIntro = true
		for k in ["earnedAll","maxSale","maxThock","minLoud","maxQ","perfectLube","fullBuilt","gb","contestWins","five","built","orders","sold","loginClaims","boxes","trades","props","repairs"]:
			st.stats[k] = prev.stats.get(k, 0)
		st.stats.bought = 1; st.stats.listed = 1
		st.money += perk("cash") * 15000
		st.level = 1 + perk("head") * 2; st.sp = st.level - 1
		st.daily = prev.daily; st.weekly = prev.weekly; st.gb = prev.gb
		st.uid = prev.uid
	return st

func starter_kit(st: Dictionary) -> void:
	var add = func(cat: String, id: String, extra: Dictionary):
		st.uid = int(st.uid) + 1
		var it = {"uid": st.uid, "cat": cat, "id": id, "cost": price_base(cat, id, extra.get("layout", ""))}
		it.merge(extra)
		st.inv.items.append(it)
	add.call("case", "c_abs", {"layout":"l60", "color":0})
	add.call("plate", "p_fr4", {"layout":"l60"})
	add.call("pcb", "b_hs", {"layout":"l60"})
	add.call("stab", "s_basic", {})
	add.call("kc", "k_stock", {})
	st.inv.sw["sw_red"] = 70; st.col.sw["sw_red"] = 1; st.col.kc["k_stock"] = 1
	for j in REPAIR_STORY.size():
		st.uid += 1
		st.orders.append(repair_order(REPAIR_STORY[j], "o%d" % st.uid, j))

func dima_build_order() -> Dictionary:
	return {"id":"o%d" % uid(), "kind":"tut", "name":"Сосед Дима", "col":"#8fd3c7",
		"text":"Старую ты оживил — теперь хочу свою! Собери мне простую 60% для учёбы: главное, чтобы работала и щёлкала приятнее офисной.",
		"req":{"layout":"l60"}, "budget":16000.0, "expires":999, "created":S.day, "district": Vector2(0.5,0.45)}

# ------------------------------------------------------------------ repairs
## Story repairs that open the game; after them random repairs keep coming between builds.
const REPAIR_STORY := [
	{"name":"Сосед Дима", "col":"#8fd3c7", "budget":3500.0, "district":Vector2(0.5,0.45),
		"text":"Привет! Говорят, ты разбираешься в механике. Моя клавиатура совсем сдала: одна буква не печатает, другая залипает после чая, и треснул колпачок. Глянешь?",
		"board":{"layout":"l60","case":"c_abs","color":1,"plate":"p_fr4","pcb":"b_hs","stab":"s_basic","kc":"k_stock","sw":"sw_red","mods":{}},
		"faults":[["dead",""],["sticky",""],["cap",""]]},
	{"name":"Лена, стримерша", "col":"#f2a7c3", "budget":5500.0, "district":Vector2(0.32,0.6),
		"text":"Пробел дребезжит прямо в микрофон, а одна клавиша печатает дважды — зрители смеются. Спасёшь эфир?",
		"board":{"layout":"l65","case":"c_pc","color":0,"plate":"p_alu","pcb":"b_hs","stab":"s_basic","kc":"k_bow","sw":"sw_brown","mods":{}},
		"faults":[["stab","space"],["chatter",""],["sticky",""]]},
]
const REPAIR_TEXT := {
	"dead": ["Пара клавиш вообще перестала печатать.", "Одна клавиша умерла после падения со стола."],
	"chatter": ["Некоторые буквы печатаются по два раза.", "Клавиша иногда «дребезжит» и ставит двойные символы."],
	"sticky": ["Пролил кофе — теперь кнопки залипают.", "Клавиши тугие и липкие, будто в сиропе."],
	"stab": ["Пробел гремит, как погремушка.", "Длинные клавиши дребезжат и звенят."],
	"cap": ["Колпачок треснул и слетает.", "Кот уронил клаву — сломался кейкап."],
	"joint": ["Клавиша срабатывает через раз.", "Буква печатается, только если сильно нажать."],
}

## Custom builds open after the first story repairs (old saves keep them).
func builds_unlocked() -> bool:
	return int(S.stats.get("repairs", 0)) >= REPAIR_STORY.size() or int(S.stats.built) > 0 or int(S.level) >= 3

func repair_order(r: Dictionary, id: String, story := -1) -> Dictionary:
	return {"id":id, "kind":"repair", "story":story, "name":r.name, "col":r.col, "text":r.text, "req":{}, "board":r.board, "faults":r.faults,
		"budget":r.budget, "expires":999 if story >= 0 else int(S.day if not S.is_empty() else 1) + randi_range(2, 4), "created":1, "district":r.district}

func gen_repair() -> Dictionary:
	var lays = Data.LAYOUTS.keys().filter(func(k): return int(Data.LAYOUTS[k].lvl) <= int(S.level))
	var layout: String = lays.pick_random()
	var u := func(arr: Array) -> Dictionary: return unlocked(arr).pick_random()
	var pc: Dictionary = u.call(Data.PCBS); var sw: Dictionary = u.call(Data.SWITCHES)
	var board = {"layout":layout, "case":u.call(Data.CASES).id, "color":randi() % 3, "plate":u.call(Data.PLATES).id, "pcb":pc.id,
		"stab":u.call(Data.STABS).id, "kc":u.call(Data.KEYCAPS).id, "sw":sw.id, "mods":{}}
	var pool = ["dead","dead","chatter","sticky","sticky","stab","cap"]
	if not Data.pcb(pc.id).hs: pool.append_array(["joint","joint"])
	var n: int = clamp(2 + int(S.level) / 4 + randi() % 2, 2, 6)
	var faults = []
	for j in n:
		var f: String = pool.pick_random()
		if f == "stab" and faults.any(func(x): return x[0] == "stab"): f = "dead"
		faults.append([f, ""])
	var kinds = []
	for f in faults: if not (f[0] in kinds): kinds.append(f[0])
	var text = " ".join(kinds.map(func(k): return REPAIR_TEXT[k].pick_random()))
	var budget = round((1800.0 + 650.0 * n + float(Data.LAYOUTS[layout].count) * 12.0) * (1.0 + float(S.rep) * 0.05) * city_k() * (1.0 + 0.04 * int(S.level)) / 100.0) * 100.0
	var r = {"name": Data.C.FIRST.pick_random() + " " + Data.C.LAST.pick_random(), "col": Data.C.AVA_COL.pick_random(), "budget": budget,
		"district": Vector2(randf_range(0.1,0.9), randf_range(0.12,0.88)), "text": text, "board": board, "faults": faults}
	return repair_order(r, "o%d" % uid())

func _fault_keys(L: Dictionary, faults: Array, seed_s: String) -> Dictionary:
	var rng := seeded(seed_s); var out := {}
	var big := []; var alpha := []
	for i in L.keys.size():
		var k: Dictionary = L.keys[i]
		if float(k.w) >= 2.0: big.append(i)
		elif k.get("kind", "") == "a": alpha.append(i)
	for f in faults:
		var kind: String = f[0]; var pick := -1
		if kind == "stab":
			var sp: Array = big.filter(func(i): return float(L.keys[i].w) >= 6.0 and not out.has(i))
			if f[1] == "" or sp.is_empty(): sp = big.filter(func(i): return not out.has(i))
			if not sp.is_empty(): pick = sp[rng.randi() % sp.size()]
		else:
			var free: Array = alpha.filter(func(i): return not out.has(i))
			if not free.is_empty(): pick = free[rng.randi() % free.size()]
		if pick >= 0: out[pick] = kind
	return out

func start_repair(oid: String) -> bool:
	if S.build != null:
		toast("Сначала закончите текущую работу в мастерской", "bad"); return false
	var o = null
	for x in S.orders: if x.id == oid: o = x
	if o == null or o.kind != "repair": return false
	var bd: Dictionary = o.board; var L: Dictionary = Data.LAYOUTS[bd.layout]
	var fk := _fault_keys(L, o.faults, o.id)
	var ks = []
	for i in L.keys.size():
		var f: String = fk.get(i, "")
		if f == "joint" and Data.pcb(bd.pcb).hs: f = "dead"
		ks.append({"s":1,"b":0,"so":1.0,"c":1,"w":0,"t":0,"d":0,"f":f,"fs":0,"seen":0,"fx":0})
	var parts = {}
	for k in ["case","plate","pcb","stab","kc"]: parts[k] = {"id": bd[k], "cost": 0.0}
	parts.case.color = bd.get("color", 0)
	var stabs = {}
	for i in stab_targets(bd.layout): stabs[str(i)] = 1
	o.taken = true
	S.build = {"kind":"repair", "oid":o.id, "client":o.name, "layout": bd.layout, "parts": parts, "sw": bd.sw, "mods": bd.mods.duplicate(), "art": null, "cost": 0.0,
		"steps": ["diag","fix","test"], "step": 0, "lubeQ": null, "precision": 1.0, "keys": 0, "ks": ks, "pieces": {"pcb":1,"plate":1}, "prot": {}, "stabs": stabs,
		"screws": [0.8,0.8,0.8,0.8,0.8,0.8], "screwSeq": [], "sc": {"align": [], "screw": 0.9}, "bentEver": 0, "wrongEver": 0, "fixes": 0, "mist": 0, "lubeR": 0, "lubeS": []}
	Audio.ui("box_open"); mark(); return true

func finish_repair() -> Dictionary:
	var b: Dictionary = S.build
	var o = null
	for x in S.orders: if x.id == b.oid: o = x
	var left: int = b.ks.filter(func(k): return str(k.get("f", "")) != "").size()
	var total: int = b.ks.filter(func(k): return int(k.get("fx", 0)) == 1).size() + left
	var mist := int(b.get("mist", 0))
	var stars: int = clamp(5 - int(ceil(mist / 3.0)) - left * 2, 1, 5)
	var budget: float = float(o.budget) if o else 3000.0
	var pay: float = round(budget * (1.0 if stars >= 4 else (0.8 if stars == 3 else 0.5)) * income_k())
	var tip: float = round(budget * (0.12 + 0.05 * skl("charm"))) if stars == 5 else 0.0
	S.build = null
	if o: S.orders.erase(o)
	earn(pay + tip, "ремонт: " + str(b.client)); add_rep((stars - 3) * 0.05)
	S.stats.repairs = int(S.stats.get("repairs", 0)) + 1; track("repair", 1)
	add_xp(22 + stars * 8 + total * 3)
	Audio.ui("coin")
	var lines = ["%s%s — %s забрал(а) клавиатуру и заплатил(а) %s%s" % ["★".repeat(stars), "☆".repeat(5 - stars), b.client, rub(pay), (" + чаевые " + rub(tip)) if tip > 0 else ""]]
	if int(S.stats.repairs) == REPAIR_STORY.size() and int(S.stats.built) == 0:
		S.orders.append(dima_build_order())
		lines.append("Открыта сборка на заказ! Дима ждёт свою первую клавиатуру.")
	toast("\n".join(lines), "gold" if stars >= 4 else ("bad" if stars <= 2 else ""))
	mark()
	return {"stars": stars, "pay": pay, "tip": tip, "client": b.client, "fixed": total - left, "total": total, "mist": mist, "unlocked": int(S.stats.repairs) == REPAIR_STORY.size() and int(S.stats.built) == 0}

func merge_defaults(def: Dictionary, obj: Dictionary) -> Dictionary:
	for k in def:
		if not obj.has(k): obj[k] = def[k]
		elif def[k] is Dictionary and obj[k] is Dictionary: merge_defaults(def[k], obj[k])
	return obj

# ------------------------------------------------------------------ derived
func upl(id: String) -> int: return int(S.up.get(id, 0)) if not S.is_empty() else 0
func skl(id: String) -> int: return int(S.sk.get(id, 0)) if not S.is_empty() else 0
func perk(id: String) -> int: return int(S.prestige.perks.get(id, 0)) if not S.is_empty() else 0
func prop_bonus(key: String) -> float:
	if S.is_empty(): return 0.0
	return float(Data.prop(S.property).get(key, 0))
func city_k() -> float: return 1.0 + 0.18 * (float(S.prestige.city) if not S.is_empty() else 0.0)
func part_city_k() -> float: return 1.0 + 0.08 * (float(S.prestige.city) if not S.is_empty() else 0.0)
func income_k() -> float: return 1.0 + 0.04 * perk("price")
func storage_cap(l := -1) -> int:
	if l < 0: l = upl("storage")
	return 14 + l * 6 + int(prop_bonus("storage"))
func repair_rate(l := -1) -> float:
	if l < 0: l = upl("repair")
	return 0.0 if l <= 0 else round(900.0 * pow(l, 1.45) * city_k())
func shelf_slots() -> int: return 2 + upl("shelf") + int(prop_bonus("shelf"))
func order_slots() -> int: return 3 + upl("orders")
func offline_cap_h() -> float: return 4.0 + upl("manager") * 2.0
func used_storage() -> int: return S.inv.items.size() + S.boards.size()
func xp_need(l := -1) -> float:
	if l < 0: l = int(S.level)
	return round(100.0 * pow(l, 1.35))
func price_base(cat: String, id: String, layout := "") -> float:
	var it = Data.item(cat, id)
	if it.is_empty(): return 0.0
	var p = float(it.price)
	if layout != "" and cat in ["case","plate","pcb"]: p *= float(Data.LAYOUTS[layout].mult)
	return round(p)
func supplier_k(cat: String) -> float:
	var sup = Data.supplier(S.market.supplier)
	return 1.0 + float(sup.mod) if cat in sup.cats else 1.0
func buy_k(cat: String, id: String) -> float:
	var k = (1.0 - 0.03 * upl("supply") - 0.02 * skl("haggle")) * part_city_k() * float(S.market.mult.get(id, 1.0)) * supplier_k(cat)
	var ev = S.market.event
	if ev is Dictionary and int(ev.until) >= int(S.day):
		if ev.id == "shortage" and cat == "sw": k *= 1.35
		if ev.id == "sale" and cat == "kc": k *= 0.75
	return k
func price_of(cat: String, id: String, layout := "") -> float: return round(price_base(cat, id, layout) * buy_k(cat, id))
func sw_price(id: String) -> float: return float(Data.sw(id).price) * buy_k("sw", id)
func cons_price(id: String) -> float: return round(float(Data.cons(id).price) * part_city_k() * (1.0 - 0.02 * skl("haggle")) * supplier_k("cons"))
func available_here(cat: String) -> bool: return cat in Data.supplier(S.market.supplier).cats

# ------------------------------------------------------------------ board physics
func calc_pitch(sw: Dictionary, pr: Dictionary, km: Dictionary, pl: Dictionary, cs: Dictionary, m: Dictionary, lq: float) -> float:
	return clamp(float(sw.pitch)*0.45 + float(pr.pitch) + float(km.pitch) + float(pl.pitch)*0.55 - (float(cs.deep)-0.5)*0.6 + (0.16 if m.get("pefoam") else 0.0) - (0.18 if m.get("tape") else 0.0) + (0.03 if m.get("films") else 0.0) - (lq-0.3)*0.08, -1.0, 1.0)

func board_stats(b: Dictionary) -> Dictionary:
	var cs = Data.case_(b.case); var pl = Data.plate(b.plate); var pc = Data.pcb(b.pcb); var st = Data.stab(b.stab)
	var kc = Data.kc(b.kc); var sw = Data.sw(b.sw)
	var m: Dictionary = b.get("mods", {})
	var pr: Dictionary = Data.PROF[kc.prof]; var km: Dictionary = Data.KMAT[kc.mat]
	var lq: float = float(b.lubeQ) if b.get("lubeQ") != null else float(sw.lube)
	var scratch = float(sw.scratch) * (1.0 - lq*0.85) * (0.82 if m.get("films") else 1.0)
	var ping = float(sw.ping) * (1.0 - lq*0.9)
	var rattle = float(st.rattle) * (0.38 if m.get("stablube") else 1.0)
	var hollow = float(cs.hollow) * (0.35 if m.get("foam") else 1.0) * (0.8 if m.get("pefoam") else 1.0) * (0.75 if m.get("tape") else 1.0)
	var silent: bool = sw.type == "silent"
	var pitch = calc_pitch(sw, pr, km, pl, cs, m, lq)
	var ref_pitch = calc_pitch(sw, Data.PROF.cherry, Data.KMAT.PBT, Data.plate("p_alu"), Data.case_("c_alu"), {}, float(sw.lube))
	var snd_set: Dictionary = Data.SND_SETS.get(sw.get("snd", ""), {"p": 0.0})
	var shift = (pitch - ref_pitch) + (float(sw.pitch) - float(snd_set.p)) * 0.8
	var loud: int = clamp(int(round(float(sw.loud)*72 + float(pr.loud)*60 + hollow*18 + float(cs.ring)*6 - (4 if m.get("foam") else 0) + (3 if m.get("pefoam") else 0) + (6 if float(sw.click) > 0 else 0))), 3, 100)
	var thock: int = clamp(int(round(50 - pitch*58 - hollow*8 - (8 if silent else 0))), 0, 100)
	var smooth: int = clamp(int(round((1.0-scratch)*80 + (14 if (sw.type == "linear" or silent) else (5 if sw.type == "tactile" else 0)) + (3 if m.get("films") else 0) + lq*4)), 0, 100)
	var swq: float = clamp(28 + float(sw.price)*0.5, 0, 100)
	var kcq: float = clamp(30 + float(kc.price)/360.0 + float(km.q), 0, 100)
	var prec = b.get("precision")
	var q = 18 + float(cs.q)*0.24 + float(pl.q)*0.08 + float(pc.q)*0.08 + float(st.q)*0.08 + swq*0.2 + kcq*0.2 \
		+ lq*10 + (3 if m.get("stablube") else 0) + (2 if m.get("films") else 0) + (2 if m.get("foam") else 0) \
		- ping*8 - rattle*8 - hollow*6 - scratch*6 \
		+ ((float(prec)-0.6)*16 if prec != null else 0.0) + skl("acoust")*1.5 + (4 if upl("bench") >= 4 else 0) \
		- int(b.get("dead", 0))*7 - int(b.get("wrongLeft", 0))*2
	var quality: int = clamp(int(round(q)), 1, 100)
	var a: Dictionary = Data.art(b.art) if b.get("art") else {}
	var aesthetic: int = clamp(int(round(kcq*0.5 + float(cs.q)*0.32 + (float(Data.RARITY[a.r].val)*5 if not a.is_empty() else 0.0) + (4 if pc.rgb else 0) + 8 - int(b.get("wrongLeft",0))*4)), 0, 100)
	var ring: float = clamp(float(cs.ring)*0.5 + max(0.0, float(pl.pitch))*0.6, 0, 1)
	return {"pitch":pitch,"thock":thock,"clack":100-thock,"loud":loud,"smooth":smooth,"quality":quality,"aesthetic":aesthetic,"type":sw.type,
		"ping":int(round(ping*100)),"rattle":int(round(rattle*100)),"hollow":int(round(hollow*100)),"scratch":int(round(scratch*100)),
		"rgb":pc.rgb,"wl":pc.wl,"hs":pc.hs,"tags":kc.tags,"dead":int(b.get("dead",0)),"wrong":int(b.get("wrongLeft",0)),
		"P":{"pitch":pitch,"loud":loud/100.0,"scratch":scratch,"ping":ping,"click":float(sw.click),"tact":float(sw.tact),"rattle":rattle,"hollow":hollow,"ring":ring,"silent":silent,"snd":sw.get("snd",""),"shift":shift,
			"prof":kc.prof,"kmat":kc.mat,"look":cs.look,"plate":pl.id,"tape":m.get("tape",false)}}

func sound_label(st: Dictionary) -> String:
	if st.type == "clicky": return "Кликающая"
	if st.loud <= 32: return "Тихая"
	if st.thock >= 64: return "Thock"
	if st.thock <= 40: return "Clack"
	return "Сбалансированная"

func trend_match(b: Dictionary) -> bool:
	var t: String = S.market.trend; var st: Dictionary = b.st
	return (t=="thock" and st.thock>=64) or (t=="clack" and st.thock<=40) or (t=="silent" and st.loud<=34) or (t=="clicky" and st.type=="clicky") \
		or (t=="rgb" and st.rgb) or (t=="wireless" and st.wl) or (Data.TAGS.has(t) and t in st.tags)

func board_value(b: Dictionary) -> float:
	var art_v = 0.0
	if b.get("art"): art_v = Data.ART_BASE * float(Data.RARITY[Data.art(b.art).r].val) * city_k()
	var v = float(b.cost) * (1.08 + float(b.st.quality)/100.0*0.95) + art_v
	if trend_match(b): v *= 1.2
	if int(b.get("dead",0)) > 0: v *= 0.45
	if int(b.get("wrongLeft",0)) > 0: v *= 1.0 - min(0.3, int(b.wrongLeft)*0.03)
	return round(v / 100.0) * 100.0

func sw_profile_solo(id: String) -> Dictionary:
	return board_stats({"layout":"l60","case":"c_alu","plate":"p_alu","pcb":"b_hs","stab":"s_screw","kc":"k_wob","sw":id,"mods":{"foam":true}}).P

# ------------------------------------------------------------------ money / xp / rep
func earn(n: float, why := "") -> void:
	n = round(n); S.money += n; S.stats.earned += n; S.stats.earnedAll += n
	track("earn", n); weekly_track("earn", n)
	if why != "": log_msg("+%s · %s" % [rub(n), why])
	money_changed.emit(n); mark()
func spend(n: float) -> bool:
	n = round(n)
	if S.money < n:
		toast("Не хватает денег", "bad"); Audio.ui("bad"); return false
	S.money -= n; money_changed.emit(-n); mark(); return true
func add_xp(n: float) -> void:
	n = round(n * (1.0 + 0.1 * perk("xp"))); S.xp += n
	while S.xp >= xp_need():
		S.xp -= xp_need(); S.level += 1; S.sp += 1
		var un = []
		for k in Data.LAYOUTS:
			if int(Data.LAYOUTS[k].lvl) == int(S.level): un.append("раскладка " + Data.LAYOUTS[k].name)
		for lst in [Data.CASES, Data.PLATES, Data.PCBS, Data.STABS, Data.SWITCHES, Data.KEYCAPS]:
			for it in lst:
				if not it.get("gb", false) and not it.has("box") and int(it.lvl) == int(S.level): un.append(it.name)
		for p in Data.PROPERTIES:
			if int(p.lvl) == int(S.level) and p.price > 0: un.append("помещение «%s»" % p.name)
		level_up.emit(int(S.level), un)
	mark()
func add_rep(d: float) -> void:
	if d > 0: d *= 1.0 + 0.1 * skl("charm")
	S.rep = clamp(float(S.rep) + d, 0.0, 5.0)
func log_msg(t: String) -> void:
	S.log.push_front({"t": t, "d": S.day})
	if S.log.size() > 40: S.log.resize(40)

func roll_rarity(table: Dictionary, luck_bonus := 0.0) -> String:
	var luck = 1.0 + 0.15 * skl("luck") + 0.1 * perk("drop") + luck_bonus
	var r = randf()
	var leg: float = table.legendary * luck; var ep: float = leg + table.epic * luck; var ra: float = ep + table.rare * luck
	if r < leg: return "legendary"
	if r < ep: return "epic"
	if r < ra: return "rare"
	return "common"
func roll_artisan(min_r := "") -> String:
	var rar = roll_rarity({"legendary":0.02,"epic":0.07,"rare":0.23,"common":0.68})
	if min_r != "" and Data.RAR_ORDER.find(rar) < Data.RAR_ORDER.find(min_r): rar = min_r
	var pool = Data.ARTISANS.filter(func(a): return a.r == rar)
	return pool.pick_random().id
func give_artisan(id: String, quiet := false, online_uid := "") -> void:
	S.inv.art.append(id if online_uid == "" else id + "#" + online_uid)
	var a = Data.art(id)
	var is_new: bool = not S.col.art.has(id)
	S.col.art[id] = int(S.col.art.get(id, 0)) + 1
	if not quiet:
		Audio.ui("rare" if a.r in ["epic","legendary"] else "good")
		toast("Артизан: [color=%s]%s[/color] (%s)%s" % [Data.RAR_COL[a.r].to_html(false), a.name, Data.RAR_NAME[a.r], " — новый в коллекции!" if is_new else ""], "vio")
	mark()
func art_base_id(s: String) -> String: return s.split("#")[0]
func give_switches(id: String, n: int) -> void:
	S.inv.sw[id] = int(S.inv.sw.get(id, 0)) + n; S.col.sw[id] = 1; mark()
func give_item(cat: String, id: String, extra := {}) -> Dictionary:
	var it = {"uid": uid(), "cat": cat, "id": id, "cost": price_base(cat, id, extra.get("layout","")) * part_city_k()}
	it.merge(extra)
	S.inv.items.append(it)
	if cat == "kc": S.col.kc[id] = 1
	mark(); return it

# ------------------------------------------------------------------ purchase
func buy_part(cat: String, id: String, layout := "", color := 0) -> bool:
	if used_storage() >= storage_cap():
		toast("Склад заполнен: расширьте стеллажи или продайте клавиатуры", "bad"); Audio.ui("bad"); return false
	var p = price_of(cat, id, layout)
	if not spend(p): return false
	var it = {"uid": uid(), "cat": cat, "id": id, "cost": p}
	if layout != "": it.layout = layout
	if cat == "case": it.color = color
	S.inv.items.append(it)
	if cat == "kc": S.col.kc[id] = 1
	S.stats.bought += 1; track("buy", 1); Audio.ui("buy")
	toast("Куплено: %s%s · −%s" % [Data.item(cat,id).name, (" (" + Data.LAYOUTS[layout].name + ")") if layout != "" else "", rub(p)])
	mark(); return true
func buy_switch(id: String, n: int) -> bool:
	var p = round(sw_price(id) * n)
	if not spend(p): return false
	var is_new: bool = not S.col.sw.has(id)
	give_switches(id, n)
	S.stats.bought += 1; track("buy", 1); Audio.ui("buy")
	toast("Куплено %d шт. «%s» · −%s%s" % [n, Data.sw(id).name, rub(p), " · новый свитч в коллекции" if is_new else ""])
	return true
func buy_cons(id: String, n := 1) -> bool:
	var p = cons_price(id) * n
	if not spend(p): return false
	S.inv.cons[id] = int(S.inv.cons.get(id, 0)) + n; S.stats.bought += 1; Audio.ui("buy")
	toast("Куплено: %s ×%d" % [Data.cons(id).name, n]); mark(); return true

# ------------------------------------------------------------------ build
func item_by_uid(u) -> Dictionary:
	for it in S.inv.items:
		if int(it.uid) == int(u): return it
	return {}
func take_item(u) -> Dictionary:
	for i in S.inv.items.size():
		if int(S.inv.items[i].uid) == int(u):
			var it = S.inv.items[i]; S.inv.items.remove_at(i); return it
	return {}
func stab_targets(layout: String) -> Array:
	var out = []
	var keys: Array = Data.LAYOUTS[layout].keys
	for i in keys.size():
		if float(keys[i].w) >= 2.0: out.append(i)
	return out

func start_build(d: Dictionary) -> bool:
	var L: Dictionary = Data.LAYOUTS[d.layout]; var need: int = L.count
	if int(S.inv.sw.get(d.sw, 0)) < need:
		toast("Не хватает свитчей", "bad"); return false
	var m = {}
	for k in ["lube","stablube","films","foam","pefoam","tape"]:
		if d.mods.get(k, false):
			if int(S.inv.cons.get(k, 0)) < 1:
				toast("Нет расходника: " + Data.cons(k).name, "bad"); return false
			m[k] = true
	var parts = {"case": take_item(d.case), "plate": take_item(d.plate), "pcb": take_item(d.pcb), "stab": take_item(d.stab), "kc": take_item(d.kc)}
	for k in m: S.inv.cons[k] = int(S.inv.cons[k]) - 1
	S.inv.sw[d.sw] = int(S.inv.sw[d.sw]) - need
	var art = null
	if d.get("art"):
		var i: int = S.inv.art.find(d.art)
		if i >= 0: art = S.inv.art[i]; S.inv.art.remove_at(i)
	var sw_cost = round(sw_price(d.sw) * need)
	var cons_cost = 0.0
	for k in m: cons_cost += float(Data.cons(k).price)
	var cost: float = float(parts.case.cost)+float(parts.plate.cost)+float(parts.pcb.cost)+float(parts.stab.cost)+float(parts.kc.cost)+sw_cost+cons_cost
	var first: bool = int(S.stats.built) == 0
	var steps = ["case","sw","kc","test"] if first else ["case","stab"]
	if not first:
		if m.get("lube"): steps.append("lube")
		steps.append("sw")
		if not Data.pcb(parts.pcb.id).hs: steps.append("solder")
		steps.append_array(["screw","kc","keytest","test"])
	var ks = []
	for _k in L.keys: ks.append({"s":0,"b":0,"so":0.0,"c":0,"w":0,"t":0,"d":0})
	S.build = {"layout": d.layout, "parts": parts, "sw": d.sw, "mods": m, "art": art, "cost": cost, "steps": steps, "step": 0,
		"lubeQ": null, "precision": null, "keys": 0, "ks": ks, "pieces": {}, "prot": {}, "stabs": {}, "screws": [null,null,null,null,null,null],
		"screwSeq": [], "sc": {"align": []}, "bentEver": 0, "wrongEver": 0, "fixes": 0, "lubeR": 0, "lubeS": []}
	if first:
		for i in stab_targets(d.layout): S.build.stabs[str(i)] = 1
		S.build.screws = [0.8,0.8,0.8,0.8,0.8,0.8]; S.build.sc.screw = 0.9
	if int(S.stats.built) == 1:
		toast("Теперь сборка полная: добавились стабилизаторы, винты и тест клавиш.", "gold")
	mark(); return true

func cancel_build() -> void:
	var b = S.build
	if b == null: return
	if b.get("kind", "") == "repair":
		for o in S.orders: if o.id == b.oid: o.erase("taken")
		S.build = null; toast("Ремонт отложен: клавиатура ждёт на доске заказов"); mark(); return
	for k in b.parts: S.inv.items.append(b.parts[k])
	S.inv.sw[b.sw] = int(S.inv.sw.get(b.sw,0)) + int(Data.LAYOUTS[b.layout].count)
	for k in b.mods:
		if not (k == "lube" and (b.lubeQ != null or int(b.lubeR) > 0)): S.inv.cons[k] = int(S.inv.cons.get(k,0)) + 1
	if b.art: S.inv.art.append(b.art)
	S.build = null; toast("Сборка отменена, детали вернулись на склад"); mark()

func build_spec(b: Dictionary) -> Dictionary:
	return {"layout":b.layout,"case":b.parts.case.id,"color":b.parts.case.get("color",0),"plate":b.parts.plate.id,"pcb":b.parts.pcb.id,"stab":b.parts.stab.id,
		"kc":b.parts.kc.id,"sw":b.sw,"mods":b.mods,"lubeQ":b.lubeQ,"art":(art_base_id(b.art) if b.art else null),"art_full":b.art,"precision":b.precision,"dead":int(b.get("dead",0)),"wrongLeft":int(b.get("wrongLeft",0))}

func auto_name(sp: Dictionary) -> String:
	var st = board_stats(sp)
	var mood: String = {"Thock":"Глубокий","Clack":"Звонкий","Тихая":"Тихий","Кликающая":"Щёлкающий","Сбалансированная":"Ровный"}[sound_label(st)]
	return "%s %s %s" % [mood, Data.kc(sp.kc).name, Data.LAYOUTS[sp.layout].name]

func finish_build(bname: String) -> Dictionary:
	var b: Dictionary = S.build
	var spec = build_spec(b)
	var board = {"uid": uid(), "name": bname if bname != "" else auto_name(spec), "cost": b.cost, "made": S.day, "parts": b.parts}
	board.merge(spec)
	board.st = board_stats(board)
	S.boards.append(board); S.build = null
	S.stats.built += 1
	if board.layout == "full": S.stats.fullBuilt += 1
	S.stats.maxThock = max(S.stats.maxThock, board.st.thock); S.stats.minLoud = min(S.stats.minLoud, board.st.loud); S.stats.maxQ = max(S.stats.maxQ, board.st.quality)
	track("build", 1); track("build_" + board.st.type, 1); weekly_track("build", 1)
	add_xp(40 + board.st.quality * 0.6)
	Audio.ui("good")
	toast("Готово: «%s» — качество %d, оценка %s" % [board.name, board.st.quality, rub(board_value(board))], "gold")
	board_built.emit(board); mark()
	return board

func disassemble(u) -> void:
	for i in S.boards.size():
		var b = S.boards[i]
		if int(b.uid) != int(u): continue
		for l in S.listings:
			if int(l.uid) == int(u):
				toast("Сначала снимите с витрины", "bad"); return
		S.boards.remove_at(i)
		for k in b.parts:
			var p: Dictionary = b.parts[k].duplicate(); p.uid = uid(); S.inv.items.append(p)
		give_switches(b.sw, int(Data.LAYOUTS[b.layout].count))
		if b.get("art_full"): S.inv.art.append(b.art_full)
		toast("Разобрано: детали и свитчи вернулись на склад (расходники израсходованы)"); mark(); return

# ------------------------------------------------------------------ orders
func unlocked(arr: Array) -> Array:
	return arr.filter(func(x): return not x.get("gb", false) and not x.has("box") and int(x.lvl) <= int(S.level))
func gen_order() -> Dictionary:
	var lays = Data.LAYOUTS.keys().filter(func(k): return int(Data.LAYOUTS[k].lvl) <= int(S.level))
	var tier_pick = func(arr: Array) -> Dictionary:
		var u = unlocked(arr)
		var i: int = clamp(int(u.size() * (0.35 + randf() * 0.75)), 0, u.size() - 1)
		return u[i] if randf() < 0.5 else u.pick_random()
	var layout: String = lays.pick_random(); var L: Dictionary = Data.LAYOUTS[layout]
	var cs: Dictionary = tier_pick.call(Data.CASES); var pl: Dictionary = tier_pick.call(Data.PLATES); var pc: Dictionary = tier_pick.call(Data.PCBS)
	var st: Dictionary = tier_pick.call(Data.STABS); var sw: Dictionary = tier_pick.call(Data.SWITCHES); var kc: Dictionary = tier_pick.call(Data.KEYCAPS)
	var cost: float = (float(cs.price)+float(pl.price)+float(pc.price))*float(L.mult) + float(st.price) + float(sw.price)*L.count + float(kc.price) + 1200.0
	var persona: Dictionary = Data.C.PERSONA.pick_random()
	var req = {}; var trend: String = S.market.trend
	if randf() < 0.55: req.layout = layout
	var snd = persona.get("pref", null)
	if snd == null and randf() < 0.55: snd = ["thock","thock","clack","silent","clicky"].pick_random()
	if not persona.has("pref") and randf() < 0.35 and trend in ["thock","clack","silent","clicky"]: snd = trend
	if snd == "silent" and int(S.level) < 3: snd = "thock"
	if snd != null: req.sound = snd
	if persona.has("stype") and not req.has("sound"): req.stype = persona.stype
	elif not req.has("sound") and randf() < 0.3: req.stype = ["linear","tactile","linear"].pick_random()
	if randf() < 0.42 or (Data.TAGS.has(trend) and randf() < 0.5):
		req.tag = trend if (Data.TAGS.has(trend) and randf() < 0.5) else kc.tags.pick_random()
	if int(S.level) >= 5 and randf() < 0.4: req.qMin = clamp(int(round(28 + int(S.level)*1.5 + randf_range(-6, 8))), 25, 92)
	if int(S.level) >= 4 and (randf() < 0.14 or (trend == "rgb" and randf() < 0.4)): req.rgb = true
	if int(S.level) >= 9 and (randf() < 0.12 or (trend == "wireless" and randf() < 0.4)): req.wl = true
	if not req.has("wl") and randf() < 0.12: req.hs = true
	var budget = round(cost * randf_range(1.32, 1.78) * (1.0 + float(S.rep)*0.07) * city_k() * (1.0 + prop_bonus("budget")) / 500.0) * 500.0
	var name: String = Data.C.FIRST.pick_random() + " " + Data.C.LAST.pick_random()
	var parts = [persona.t]
	if req.has("sound"): parts.append(Data.C.SOUND_ASK[req.sound])
	if req.has("stype"): parts.append("Свитчи — только %s." % Data.STYPE[req.stype])
	if req.has("layout"): parts.append("Формат — %s." % L.name)
	if req.has("tag"): parts.append("Хочу клавиатуру %s." % Data.C.TAG_ASK[req.tag])
	if req.has("wl"): parts.append("Обязательно беспроводная.")
	if req.has("rgb"): parts.append("С подсветкой RGB.")
	if req.has("hs"): parts.append("Чтобы свитчи можно было менять (hotswap).")
	if req.has("qMin"): parts.append("Качество не ниже %d." % req.qMin)
	return {"id":"o%d" % uid(), "kind":"normal", "name":name, "col":Data.C.AVA_COL.pick_random(), "text":" ".join(parts), "req":req,
		"budget":budget, "expires":int(S.day) + randi_range(3, 6), "created":S.day, "district":Vector2(randf_range(0.1,0.9), randf_range(0.12,0.88))}

func vip_order(v: Dictionary) -> Dictionary:
	var stg = int(S.vip.get(v.id, 0)); var s: Dictionary = v.stages[stg]
	var L: Dictionary = Data.LAYOUTS.get(s.req.get("layout", "l65"), Data.LAYOUTS.l65)
	var base: float = 9000.0*float(L.mult) + 2500 + 70*L.count + 9000 + int(S.level)*1400
	return {"id":"o%d" % uid(), "kind":"vip", "vip":v.id, "stage":stg, "name":v.name, "role":v.role, "col":v.col, "text":s.text, "req":s.req,
		"budget":round(base*float(s.pay)*city_k()/500.0)*500.0, "expires":9999, "created":S.day, "district":Vector2(randf_range(0.2,0.8), randf_range(0.2,0.8))}

func refill_orders(n: int) -> void:
	for i in n:
		if S.orders.size() >= order_slots(): break
		S.orders.append(gen_order() if builds_unlocked() and randf() > 0.3 else gen_repair())
	for v in Data.VIPS:
		var stg = int(S.vip.get(v.id, 0))
		var has = S.orders.any(func(o): return o.get("vip") == v.id)
		if stg < v.stages.size() and int(S.level) >= int(v.lvl) + stg*4 and not has and randf() < 0.5:
			S.orders.append(vip_order(v)); toast("VIP-клиент: [b]%s[/b] ждёт вас на доске заказов" % v.name, "gold"); break

func req_checks(req: Dictionary, b: Dictionary) -> Array:
	var st: Dictionary = b.st; var out = []
	var add = func(label: String, ok: bool, w: int, hard: bool): out.append({"label":label,"ok":ok,"w":w,"hard":hard})
	if req.has("layout"): add.call("Формат " + Data.LAYOUTS[req.layout].name, b.layout == req.layout, 3, true)
	if req.get("sound") == "thock": add.call("Thock" + (" ≥ %d" % req.thockMin if req.has("thockMin") else ""), st.thock >= int(req.get("thockMin", 60)), 2, false)
	if req.get("sound") == "clack": add.call("Звонкий clack", st.thock <= 42, 2, false)
	if req.get("sound") == "silent": add.call("Тихая" + (" (громк. ≤ %d)" % req.loudMax if req.has("loudMax") else ""), st.loud <= int(req.get("loudMax", 36)), 2, false)
	if req.get("sound") == "clicky": add.call("Кликающие свитчи", st.type == "clicky", 2, false)
	if req.has("stype"): add.call("Свитчи: " + Data.STYPE[req.stype], st.type == req.stype, 2, false)
	if req.has("switch"): add.call("Свитчи «%s»" % Data.sw(req.switch).name, b.sw == req.switch, 3, true)
	if req.has("tag"): add.call("Стиль: " + Data.TAGS[req.tag], req.tag in st.tags, 1, false)
	if req.has("qMin"): add.call("Качество ≥ %d" % req.qMin, st.quality >= int(req.qMin), 2, false)
	if req.has("smoothMin"): add.call("Гладкость ≥ %d" % req.smoothMin, st.smooth >= int(req.smoothMin), 2, false)
	if req.get("rgb"): add.call("RGB-подсветка", st.rgb, 1, false)
	if req.get("wl"): add.call("Беспроводная", st.wl, 2, true)
	if req.get("hs"): add.call("Hotswap", st.hs, 1, false)
	if req.get("artisan"): add.call("Артизан на Esc", b.get("art") != null, 2, true)
	add.call("Все клавиши работают", int(b.get("dead",0)) == 0, 3, true)
	if int(b.get("wrongLeft",0)) > 0: add.call("Колпачки стоят ровно", false, 1, false)
	return out

func eval_order(o: Dictionary, b: Dictionary) -> Dictionary:
	var ch = req_checks(o.req, b)
	var tot = 0.0; var got = 0.0
	for c in ch:
		tot += c.w
		if c.ok: got += c.w
	var stars = 1.0 + 4.0 * (got / max(tot, 1.0))
	var exp_q: float = float(o.req.get("qMin", clamp(22 + int(S.level)*1.3, 20, 85)))
	stars += clamp((float(b.st.quality) - exp_q) / 30.0, -1.0, 0.8)
	if ch.any(func(c): return c.hard and not c.ok): stars = min(stars, 2.0)
	var s: int = clamp(int(round(stars)), 1, 5)
	var pay_k = 1.0 if s >= 3 else (0.7 if s == 2 else 0.45)
	var pay = round(float(o.budget) * pay_k * income_k())
	var tip = round(float(o.budget) * (0.1 + 0.05*skl("charm"))) if s == 5 else (round(float(o.budget)*0.04) if s == 4 else 0.0)
	return {"ch":ch, "stars":s, "pay":pay, "tip":tip, "rep":(s-3)*0.06}

func deliver_order(oid: String, buid, mult := 1.0) -> Dictionary:
	var o = null
	for x in S.orders:
		if x.id == oid: o = x
	var bi = -1
	for i in S.boards.size():
		if int(S.boards[i].uid) == int(buid): bi = i
	if o == null or bi < 0: return {}
	S.listings = S.listings.filter(func(l): return int(l.uid) != int(buid))
	var b: Dictionary = S.boards[bi]; var r = eval_order(o, b); r.pay *= mult
	consume_board(b)
	S.boards.remove_at(bi); S.orders.erase(o)
	earn(r.pay + r.tip, "заказ: " + o.name); add_rep(r.rep)
	S.stats.orders += 1; track("order", 1); weekly_track("order", 1)
	if r.stars == 5: S.stats.five += 1; track("five", 1)
	add_xp(30 + r.stars*14 + (80 if o.kind == "vip" else 0))
	S.stats.maxSale = max(S.stats.maxSale, r.pay + r.tip)
	Audio.ui("coin")
	var lines = ["%s%s — %s заплатил %s%s" % ["★".repeat(r.stars), "☆".repeat(5 - r.stars), o.name, rub(r.pay), (" + чаевые " + rub(r.tip)) if r.tip > 0 else ""]]
	if o.kind == "vip":
		if r.stars >= 3:
			var v = Data.by_id("VIPS", o.vip); var stg: Dictionary = v.stages[int(o.stage)]
			S.vip[o.vip] = int(S.vip.get(o.vip, 0)) + 1
			if stg.reward.has("art"): give_artisan(roll_artisan(stg.reward.art))
			if stg.reward.has("money"): earn(float(stg.reward.money)*city_k(), "бонус VIP")
			lines.append("Сюжет «%s» завершён!" % v.name if int(S.vip[o.vip]) >= v.stages.size() else "Глава сюжета пройдена — клиент вернётся.")
		else: lines.append("VIP недоволен. Он даст ещё один шанс позже.")
	elif r.stars == 5 and randf() < 0.07 * (1.0 + 0.15*skl("luck") + 0.1*perk("drop")):
		lines.append("Клиент в восторге и дарит вам артизан!"); give_artisan(roll_artisan())
	if o.kind == "tut": lines.append("Первый клиент доволен. Деньги можно вложить в детали.")
	toast("\n".join(lines), "gold" if r.stars >= 4 else ("bad" if r.stars <= 2 else ""))
	mark(); return r

func decline_order(oid: String) -> void:
	for o in S.orders:
		if o.id == oid:
			S.orders.erase(o)
			if o.kind != "tut": add_rep(-0.02)
			toast("Заказ отклонён: " + o.name); mark(); return

# ------------------------------------------------------------------ storefront
func list_board(u, price := 0.0) -> bool:
	if S.listings.size() >= shelf_slots():
		toast("Все места на витрине заняты", "bad"); return false
	for b in S.boards:
		if int(b.uid) == int(u):
			S.listings.append({"uid": u, "price": max(100.0, round(price if price > 0 else board_value(b)*1.05)), "at": now()})
			S.stats.listed += 1; track("list", 1); Audio.ui("tick"); mark(); return true
	return false
func unlist(u) -> void:
	S.listings = S.listings.filter(func(l): return int(l.uid) != int(u)); mark()
func find_board(u) -> Dictionary:
	for b in S.boards:
		if int(b.uid) == int(u): return b
	return {}
func sale_chance(l: Dictionary) -> float:
	var b = find_board(l.uid)
	if b.is_empty(): return 0.0
	var V = board_value(b) * (1.0 + 0.03*skl("trade")) * income_k()
	var r = float(l.price) / V
	var pf = pow(clamp((1.65 - r) / 0.65, 0.0, 1.6), 2.0)
	var c = 0.05 * pf * (0.45 + float(S.rep)/4.5) * (1.0 + 0.18*upl("ads")) * (1.0 + prop_bonus("sale"))
	var ev = S.market.event
	if ev is Dictionary and ev.id == "viral" and int(ev.until) >= int(S.day): c *= 2.0
	if trend_match(b): c *= 1.25
	return clamp(c, 0.0, 0.6)
## Online items inside a board leave the game economy when the board is sold.
func consume_board(b: Dictionary) -> void:
	if b.get("art_full") and "#" in str(b.art_full): Online.consume_item(str(b.art_full).split("#")[1])
	var kc = b.get("parts", {}).get("kc", {})
	if kc is Dictionary and str(kc.get("ouid", "")) != "": Online.consume_item(str(kc.ouid))

func sell_listing(l: Dictionary, offline := false) -> float:
	var b = find_board(l.uid)
	if b.is_empty(): return 0.0
	S.boards.erase(b); S.listings.erase(l)
	earn(float(l.price), "продажа с витрины: " + b.name)
	S.stats.sold += 1; S.stats.maxSale = max(S.stats.maxSale, float(l.price)); track("sell", 1); weekly_track("sell", 1)
	add_xp(22 + b.st.quality*0.25); add_rep(0.015)
	consume_board(b)
	if not offline:
		Audio.ui("coin"); toast("Продано с витрины: «%s» за %s" % [b.name, rub(l.price)], "gold")
	return float(l.price)
func sale_tick() -> void:
	for l in S.listings.duplicate():
		if randf() < sale_chance(l): sell_listing(l)

# ------------------------------------------------------------------ time
func new_day() -> void:
	S.day += 1; S.dayT = 0.0
	for lst in [Data.CASES, Data.PLATES, Data.PCBS, Data.STABS, Data.SWITCHES, Data.KEYCAPS]:
		for it in lst:
			var m = float(S.market.mult.get(it.id, 1.0))
			S.market.mult[it.id] = snappedf(clamp(m * (1.0 + (randf() - 0.5) * 0.12), 0.86, 1.2), 0.001)
	if int(S.day) - int(S.market.trendDay) >= 7:
		var opts = Data.TRENDS.keys().filter(func(t): return t != S.market.trend)
		S.market.trend = opts.pick_random(); S.market.trendDay = S.day
		toast("Новый тренд недели: [b]%s[/b]. Такие сборки продаются на 20%% дороже" % Data.TRENDS[S.market.trend], "gold")
	var ev = S.market.event
	if ev is Dictionary and int(ev.until) < int(S.day): S.market.event = null
	if S.market.event == null and randf() < 0.16:
		var e: Dictionary = [
			{"id":"viral","n":"Ваше видео стало вирусным: покупателей на витрине ×2","len":2},
			{"id":"shortage","n":"Дефицит свитчей у поставщиков: +35% к цене","len":2},
			{"id":"sale","n":"Распродажа кейкапов: −25%","len":1},
			{"id":"press","n":"О вас написал техноблог: +0.1 к репутации","len":0}].pick_random()
		if e.id == "press": add_rep(0.1)
		S.market.event = {"id":e.id, "n":e.n, "until":int(S.day) + int(e.len)}
		toast("Событие: " + e.n, "vio")
	var expired = S.orders.filter(func(o): return int(o.expires) < int(S.day) and not o.get("taken", false))
	if expired.size() > 0:
		S.orders = S.orders.filter(func(o): return int(o.expires) >= int(S.day) or o.get("taken", false))
		add_rep(-0.03 * expired.size())
		toast("%d клиент(а) не дождались и ушли к конкурентам" % expired.size(), "bad")
	refill_orders(randi_range(1, 2))
	day_passed.emit(int(S.day)); mark()

func process_offline() -> Dictionary:
	var t = now(); var away: float = t - float(S.lastTick)
	var res = {"away": away, "sold": [], "repair": 0.0, "gb": []}
	if away > 60.0:
		var eff: float = min(away, offline_cap_h() * 3600.0)
		var n = eff / Data.SALE_TICK * 0.15
		for l in S.listings.duplicate():
			var p = sale_chance(l)
			if randf() < 1.0 - pow(1.0 - p, n):
				var b = find_board(l.uid); var amt = sell_listing(l, true)
				if amt > 0: res.sold.append({"name": b.name, "amt": amt})
	res.repair = repair_payout(min(t - float(S.lastRepair), 24.0 * 3600.0))
	S.lastRepair = t
	res.gb = deliver_gb()
	S.lastTick = t
	return res
func repair_payout(sec: float) -> float:
	var r = repair_rate()
	if r <= 0 or sec <= 0: return 0.0
	var amt = round(r * sec / 3600.0 * income_k())
	if amt > 0:
		S.money += amt; S.stats.earned += amt; S.stats.earnedAll += amt; track("earn", amt); weekly_track("earn", amt); money_changed.emit(amt)
	return amt

func _process(delta: float) -> void:
	if S.is_empty() or paused: return
	S.dayT += delta
	if S.dayT >= Data.DAY_SEC: new_day()
	_sale_acc += delta
	if _sale_acc >= Data.SALE_TICK:
		_sale_acc = 0.0; sale_tick()
	if now() - float(S.lastRepair) > 60.0:
		repair_payout(now() - float(S.lastRepair)); S.lastRepair = now()
	if S.gb.pending.size() > 0: deliver_gb()
	_daily_acc += delta
	if _daily_acc > 20.0:
		_daily_acc = 0.0
		var d0: String = S.daily.date; var w0 = int(S.weekly.week); var l0: String = S.login.last
		ensure_daily(); ensure_week(); login_tick()
		if d0 != S.daily.date or w0 != int(S.weekly.week) or l0 != S.login.last: mark()
		tut_tick(); ach_tick()
	S.lastTick = now()
	_save_timer += delta
	if dirty and _save_timer > 2.0:
		_save_timer = 0.0; save_game()

# ------------------------------------------------------------------ dailies / login / weekly
const TASK_POOL := [
	{"k":"build","n":[1,2,3],"t":"Соберите %d клав."}, {"k":"order","n":[1,2,3],"t":"Выполните %d заказ(а)"},
	{"k":"sell","n":[1,2],"t":"Продайте %d клав. с витрины"}, {"k":"earn","n":[1,2,3],"t":"Заработайте %s","scale":true},
	{"k":"five","n":[1],"t":"Получите отзыв 5★"}, {"k":"lube","n":[1,2],"t":"Смажьте свитчи на 80%%+ (%d раз)"},
	{"k":"keys","n":[300,600],"t":"Нажмите %d клавиш на тесте звука"}, {"k":"build_linear","n":[1],"t":"Соберите клавиатуру на линейных"},
	{"k":"build_tactile","n":[1],"t":"Соберите клавиатуру на тактильных"}, {"k":"build_clicky","n":[1],"t":"Соберите клавиатуру на кликающих"},
	{"k":"list","n":[1,2],"t":"Выставьте %d клав. на витрину"}, {"k":"buy","n":[3,5],"t":"Сделайте %d покупок"},
	{"k":"box","n":[1,2],"t":"Откройте %d коробк(и)"},
]
func task_text(t: Dictionary) -> String:
	for p in TASK_POOL:
		if p.k == t.k:
			if "%s" in p.t: return p.t % rub(t.n)
			if "%d" in p.t: return p.t % int(t.n)
			return p.t.replace("%%", "%")
	return t.k
func ensure_daily() -> void:
	var d = today_str()
	if S.daily.date == d: return
	var r = seeded(d + "kss"); var pool = TASK_POOL.duplicate(); var tasks = []
	while tasks.size() < 3:
		var p: Dictionary = pool.pop_at(r.randi() % pool.size())
		var n: float = float(p.n[r.randi() % p.n.size()])
		if p.get("scale", false): n = round(n * 15000.0 * (1.0 + int(S.level)*0.25) * city_k() / 1000.0) * 1000.0
		tasks.append({"k":p.k, "n":n, "claimed":false})
	S.daily = {"date":d, "tasks":tasks, "bonus":false, "prog":{}, "freeBox":false}
func track(k: String, n := 1.0) -> void: S.daily.prog[k] = float(S.daily.prog.get(k, 0.0)) + n
func task_prog(t: Dictionary) -> float: return min(float(t.n), float(S.daily.prog.get(t.k, 0.0)))
func task_reward() -> float: return round((2500 + int(S.level)*700) * city_k() / 100.0) * 100.0
func claim_task(i: int) -> void:
	var t: Dictionary = S.daily.tasks[i]
	if t.claimed or task_prog(t) < float(t.n): return
	t.claimed = true; earn(task_reward(), "ежедневное задание"); add_xp(40 + int(S.level)*4); Audio.ui("coin")
	toast("Задание выполнено: +" + rub(task_reward()), "gold"); mark()
func claim_daily_bonus() -> void:
	if S.daily.bonus or not S.daily.tasks.all(func(t): return t.claimed): return
	S.daily.bonus = true; add_box("box_pro" if randf() < 0.15 else ["box_sw","box_kc","box_art"].pick_random(), 1)
	earn(round((4000 + int(S.level)*900) * city_k()), "сундук дня"); mark()
const LOGIN_REW := [{"t":"Деньги","m":3000},{"t":"Расходники","cons":true},{"t":"Деньги","m":7000},{"t":"Коробка свитчей","box":"box_sw"},{"t":"Деньги","m":12000},{"t":"Коробка кейкапов","box":"box_kc"},{"t":"Сундук мастера","m":20000,"box":"box_pro"}]
func login_tick() -> void:
	var d = today_str()
	if S.login.last == d: return
	S.login.streak = int(S.login.streak) + 1 if S.login.last == today_str(-1) else 1
	S.login.best = max(int(S.login.best), int(S.login.streak)); S.login.last = d
func login_idx() -> int: return (max(1, int(S.login.streak)) - 1) % 7
func login_k() -> float: return (1.0 + (int(S.level)-1)*0.12) * city_k() * (1.0 + min(1.0, floor((int(S.login.streak)-1)/7.0)*0.1))
func claim_login() -> void:
	var d = today_str()
	if S.login.claimed == d: return
	S.login.claimed = d; S.stats.loginClaims += 1
	var rw: Dictionary = LOGIN_REW[login_idx()]; var msgs = []
	if rw.has("m"):
		var m = round(float(rw.m) * login_k() / 100.0) * 100.0; earn(m, "ежедневная награда"); msgs.append(rub(m))
	if rw.get("cons", false):
		for c in ["lube","stablube","foam","tape","films"]: S.inv.cons[c] = int(S.inv.cons.get(c,0)) + 2
		msgs.append("расходники ×2")
	if rw.has("box"): add_box(rw.box, 1); msgs.append(Data.box(rw.box).name)
	Audio.ui("coin"); toast("День %d подряд: %s" % [S.login.streak, ", ".join(msgs)], "gold"); mark()

const WEEK_TASKS := [{"k":"order","n":15,"t":"Выполните 15 заказов"},{"k":"build","n":12,"t":"Соберите 12 клавиатур"},{"k":"sell","n":10,"t":"Продайте 10 клавиатур с витрины"},{"k":"earn","n":1,"t":"Заработайте","scale":true}]
func ensure_week() -> void:
	var w = week_no()
	if int(S.weekly.week) == w: return
	if S.weekly.contest is Dictionary and S.weekly.contest.get("entry") != null and S.weekly.result == null:
		var c: Dictionary = S.weekly.contest; var npcs = contest_npc(int(S.weekly.week), int(S.weekly.npcLvl))
		var rank = 1 + npcs.filter(func(n): return n.score > float(c.entry.score)).size()
		S.weekly.result = {"rank":rank, "id":c.id, "score":c.entry.score, "claimed":false}
	var prev_res = S.weekly.result if (S.weekly.result is Dictionary and not S.weekly.result.claimed) else null
	var r = seeded(str(w * 7919)); var t: Dictionary = WEEK_TASKS[r.randi() % WEEK_TASKS.size()]
	var n: float = t.n
	if t.get("scale", false): n = round(150000.0 * (1.0 + int(S.level)*0.3) * city_k() / 10000.0) * 10000.0
	S.weekly = {"week":w, "task":{"k":t.k, "n":n, "t":t.t}, "prog":0.0, "claimed":false,
		"contest":{"id":Data.CONTESTS[w % Data.CONTESTS.size()].id, "entry":null}, "result":prev_res, "npcLvl":S.level}
func weekly_track(k: String, n: float) -> void:
	if S.weekly.task is Dictionary and S.weekly.task.k == k: S.weekly.prog = float(S.weekly.prog) + n
func claim_weekly() -> void:
	var t = S.weekly.task
	if t == null or S.weekly.claimed or float(S.weekly.prog) < float(t.n): return
	S.weekly.claimed = true; add_box("box_pro", 1); earn(round(30000.0 * (1.0 + int(S.level)*0.2) * city_k()), "недельное задание"); add_xp(300 + int(S.level)*20); mark()
func contest_score(id: String, st: Dictionary) -> float:
	var s: float
	match id:
		"thock": s = st.thock*0.55 + st.quality*0.35 + (100-st.ping)*0.1
		"silent": s = (100-st.loud)*0.55 + st.quality*0.35 + st.smooth*0.1
		"smooth": s = st.smooth*0.55 + st.quality*0.45
		"aesthetic": s = st.aesthetic*0.65 + st.quality*0.35
		_: s = st.clack*0.5 + st.quality*0.35 + (100-st.hollow)*0.15
	if upl("studio") >= 2: s *= 1.0 + 0.05*(upl("studio")-1)
	return snappedf(s, 0.1)
const NPC_NAMES := ["ThockLab","Клавишник","MechaNika","Свитчер","КейкапКлуб","Lubed&Loved","Пружина","GasketGang","Щелчок"]
func contest_npc(w: int, lvl: int) -> Array:
	var r = seeded(str(w * 104729 + 11)); var top: float = clamp(62 + lvl*0.9, 60, 97); var out = []
	for i in NPC_NAMES.size(): out.append({"name":NPC_NAMES[i], "score":snappedf(top - i * r.randf_range(2.2, 4.5), 0.1)})
	out.sort_custom(func(a, b): return a.score > b.score)
	return out
func submit_contest(u) -> void:
	var b = find_board(u); var c = S.weekly.contest
	if b.is_empty() or c == null: return
	var sc = contest_score(c.id, b.st)
	if c.entry != null and float(c.entry.score) >= sc:
		toast("Ваша текущая заявка сильнее (%s)" % str(c.entry.score), "bad"); return
	c.entry = {"name":b.name, "score":sc}
	toast("Заявка принята: %s очков" % str(sc), "gold"); Audio.ui("good"); Online.push_contest(sc); mark()
func claim_contest() -> void:
	var r = S.weekly.result
	if r == null or r.claimed: return
	r.claimed = true; var k = city_k() * (1.0 + int(S.level)*0.15)
	if int(r.rank) == 1: S.stats.contestWins += 1; give_artisan(roll_artisan("epic")); earn(60000*k, "1 место в конкурсе")
	elif int(r.rank) <= 3: give_artisan(roll_artisan("rare")); earn(30000*k, "%d место в конкурсе" % r.rank)
	elif int(r.rank) <= 6: earn(12000*k, "%d место в конкурсе" % r.rank)
	else: earn(4000*k, "участие в конкурсе")
	add_xp(200); mark()

# ---- weekly limited drops (pre-order, arrive in real time) -------------
func gb_offer() -> Dictionary:
	var w = week_no(); var r = seeded(str(w * 31337))
	var sws = Data.SWITCHES.filter(func(s): return s.get("gb", false))
	var kcs = Data.KEYCAPS.filter(func(k): return k.get("gb", false))
	var arts = Data.ARTISANS.filter(func(a): return a.r in ["epic","legendary"])
	return {"sw":sws[r.randi() % sws.size()], "kc":kcs[r.randi() % kcs.size()], "art":arts[r.randi() % arts.size()], "w":w}
func gb_art_price(a: Dictionary) -> float: return round(Data.ART_BASE * float(Data.RARITY[a.r].val) * 2.6 * city_k() / 1000.0) * 1000.0
func buy_gb(kind: String) -> void:
	var o = gb_offer(); var price: float; var it: Dictionary; var name: String
	var n: int = Data.LAYOUTS.tkl.count
	if kind == "sw": price = round(float(o.sw.price)*n*part_city_k()); it = {"kind":kind,"id":o.sw.id,"n":n}; name = "%d × «%s»" % [n, o.sw.name]
	elif kind == "kc": price = round(float(o.kc.price)*part_city_k()); it = {"kind":kind,"id":o.kc.id}; name = "кейкапы «%s»" % o.kc.name
	else:
		if int(S.gb.boughtArt) == int(o.w): toast("Артизан недели уже заказан", "bad"); return
		price = gb_art_price(o.art); it = {"kind":kind,"id":o.art.id}; name = "артизан «%s»" % o.art.name
	if not spend(price): return
	if kind == "art": S.gb.boughtArt = o.w
	var mins = 45 if kind == "art" else randi_range(20, 40)
	it.w = o.w; it.arrive = now() + mins*60; it.name = name
	S.gb.pending.append(it); Audio.ui("buy")
	toast("Предзаказ оформлен: %s. Доставка через %d мин" % [name, mins], "gold"); mark()
func deliver_gb() -> Array:
	var t = now(); var got = []; var keep = []
	for p in S.gb.pending:
		if float(p.arrive) > t: keep.append(p); continue
		if p.kind == "sw": give_switches(p.id, int(p.n))
		elif p.kind == "kc": S.inv.items.append({"uid":uid(),"cat":"kc","id":p.id,"cost":float(Data.kc(p.id).price)*part_city_k()}); S.col.kc[p.id] = 1
		else: give_artisan(p.id)
		S.stats.gb += 1; got.append(p.name)
	if got.size() > 0:
		S.gb.pending = keep; Audio.ui("rare"); toast("Посылка прибыла: " + ", ".join(got), "vio"); mark()
	return got

# ------------------------------------------------------------------ boxes
func add_box(id: String, n: int) -> void:
	S.inv.boxes[id] = int(S.inv.boxes.get(id, 0)) + n; mark()
func buy_box(id: String) -> bool:
	var b = Data.box(id)
	if not spend(round(float(b.price) * city_k())): return false
	add_box(id, 1); Audio.ui("buy"); return true
func box_odds(id: String) -> Dictionary: return Data.BOX_ODDS_PRO if id == "box_pro" else Data.BOX_ODDS
## Rolls a box locally. Returns {kind, id, n, rarity, name}. Online version goes through Online.open_box.
func roll_box(id: String) -> Dictionary:
	var b = Data.box(id); var rar = roll_rarity(box_odds(id))
	var pool: String = b.pool
	if pool == "mix": pool = ["sw","kc","art","art"].pick_random()
	return box_entry(pool, rar)
func box_entry(pool: String, rar: String) -> Dictionary:
	if pool == "art":
		var a: Dictionary = Data.ARTISANS.filter(func(x): return x.r == rar).pick_random()
		return {"kind":"art","id":a.id,"n":1,"rarity":rar,"name":a.name}
	if pool == "sw":
		var cand: Array
		if rar == "common": cand = Data.SWITCHES.filter(func(s): return not s.get("gb",false) and not s.has("box") and float(s.price) < 60)
		elif rar == "rare": cand = Data.SWITCHES.filter(func(s): return (not s.has("box") and float(s.price) >= 60) or s.get("box","") == "rare")
		elif rar == "epic": cand = Data.SWITCHES.filter(func(s): return s.get("gb",false) or s.get("box","") == "epic")
		else: cand = Data.SWITCHES.filter(func(s): return s.get("box","") == "legendary")
		var s: Dictionary = cand.pick_random()
		var n: int = Data.LAYOUTS.tkl.count if rar != "common" else Data.LAYOUTS.l65.count
		return {"kind":"sw","id":s.id,"n":n,"rarity":rar,"name":"%d × %s" % [n, s.name]}
	var kcand: Array
	if rar == "common": kcand = Data.KEYCAPS.filter(func(k): return not k.get("gb",false) and not k.has("box") and float(k.price) < 9000)
	elif rar == "rare": kcand = Data.KEYCAPS.filter(func(k): return (not k.get("gb",false) and not k.has("box") and float(k.price) >= 9000) or k.get("box","") == "rare")
	elif rar == "epic": kcand = Data.KEYCAPS.filter(func(k): return k.get("gb",false) or k.get("box","") == "epic")
	else: kcand = Data.KEYCAPS.filter(func(k): return k.get("box","") == "legendary")
	var k: Dictionary = kcand.pick_random()
	return {"kind":"kc","id":k.id,"n":1,"rarity":rar,"name":"кейкапы «%s»" % k.name}
func grant_entry(e: Dictionary, online_uid := "") -> void:
	match e.kind:
		"art": give_artisan(e.id, true, online_uid)
		"sw": give_switches(e.id, int(e.n))
		"kc": S.inv.items.append({"uid":uid(),"cat":"kc","id":e.id,"cost":float(Data.kc(e.id).price)*part_city_k(),"ouid":online_uid}); S.col.kc[e.id] = 1
	mark()
## Consumes one box and returns the won entry (local roll). The UI animates the reveal.
func open_box_local(id: String) -> Dictionary:
	if int(S.inv.boxes.get(id, 0)) < 1: return {}
	S.inv.boxes[id] = int(S.inv.boxes[id]) - 1
	var e = roll_box(id)
	grant_entry(e)
	S.stats.boxes += 1; track("box", 1)
	mark(); return e

# ------------------------------------------------------------------ properties
func buy_property(id: String) -> bool:
	var p = Data.prop(id)
	if id in S.owned_props: S.property = id; mark(); return true
	if int(S.level) < int(p.lvl): toast("Помещение откроется на %d уровне" % p.lvl, "bad"); return false
	if not spend(round(float(p.price) * city_k())): return false
	S.owned_props.append(id); S.property = id; S.stats.props += 1
	Audio.ui("level"); toast("Новое помещение: [b]%s[/b]! Склад, витрина и поток покупателей выросли." % p.name, "gold"); mark()
	return true

# ------------------------------------------------------------------ NPC traders (offline trading)
func ensure_traders() -> void:
	if int(S.traders.day) == int(S.day): return
	var r = seeded("tr" + str(S.day) + str(S.created))
	var offers = []
	var names = ["Коллекционер Лёша","Мастерская «Щелчок»","Барахольщик Миша","Студия ThockLab","Ксюша-кейкапница","Дед с радиорынка"]
	for i in 5:
		var give_r: String = ["common","rare","rare","epic","legendary"][min(4, int(r.randf()*r.randf()*5.0))]
		var want_r: String = Data.RAR_ORDER[clamp(Data.RAR_ORDER.find(give_r) + (r.randi() % 3) - 1, 0, 3)]
		var give = box_entry(["art","sw","kc"][r.randi() % 3], give_r)
		var want_kind: String = ["art","sw","kc"][r.randi() % 3]
		offers.append({"id":"t%d_%d" % [S.day, i], "who":names[r.randi() % names.size()], "give":give, "want":{"kind":want_kind, "rarity":want_r}, "npc":true})
	S.traders = {"day": S.day, "offers": offers}
func tradeable_items() -> Array:
	## Items the player can give in a trade: artisans, keycap sets in stock, switch lots (>= 65 pcs).
	var out = []
	for a in S.inv.art:
		var ad = Data.art(art_base_id(a))
		out.append({"kind":"art","id":ad.id,"n":1,"rarity":ad.r,"name":ad.name,"ref":a})
	for it in S.inv.items:
		if it.cat == "kc":
			var k = Data.kc(it.id); out.append({"kind":"kc","id":it.id,"n":1,"rarity":kc_rarity(k),"name":"кейкапы «%s»" % k.name,"ref":it.uid})
	for id in S.inv.sw:
		if int(S.inv.sw[id]) >= int(Data.LAYOUTS.l65.count):
			var s = Data.sw(id); out.append({"kind":"sw","id":id,"n":int(Data.LAYOUTS.l65.count),"rarity":sw_rarity(s),"name":"%d × %s" % [int(Data.LAYOUTS.l65.count), s.name],"ref":id})
	return out
func kc_rarity(k: Dictionary) -> String:
	if k.has("box"): return k.box
	if k.get("gb", false): return "epic"
	return "rare" if float(k.price) >= 9000 else "common"
func sw_rarity(s: Dictionary) -> String:
	if s.has("box"): return s.box
	if s.get("gb", false): return "epic"
	return "rare" if float(s.price) >= 60 else "common"
func remove_trade_item(t: Dictionary) -> bool:
	match t.kind:
		"art":
			var i: int = S.inv.art.find(t.ref)
			if i < 0: return false
			S.inv.art.remove_at(i); return true
		"kc":
			return not take_item(t.ref).is_empty()
		"sw":
			if int(S.inv.sw.get(t.ref, 0)) < int(t.n): return false
			S.inv.sw[t.ref] = int(S.inv.sw[t.ref]) - int(t.n); return true
	return false
func accept_npc_trade(offer_id: String, give: Dictionary) -> bool:
	for o in S.traders.offers:
		if o.id != offer_id: continue
		if give.kind != o.want.kind or Data.RAR_ORDER.find(give.rarity) < Data.RAR_ORDER.find(o.want.rarity):
			toast("Торговец хочет другое", "bad"); return false
		if not remove_trade_item(give): return false
		grant_entry(o.give); S.traders.offers.erase(o); S.stats.trades += 1
		Audio.ui("rare"); toast("Обмен состоялся: вы получили %s" % o.give.name, "gold"); item_won.emit(o.give); mark(); return true
	return false

# ------------------------------------------------------------------ tutorial / achievements
const TUT := [
	{"t":"Почините клавиатуру Димы: «Заказы» → «Взять в ремонт»", "k":"repairs", "r":1500},
	{"t":"Почините клавиатуру Лены — после этого откроется сборка на заказ", "k":"repairs", "n":2, "r":2000},
	{"t":"Соберите первую клавиатуру в мастерской из стартового набора", "k":"built", "r":2000},
	{"t":"Отдайте её Диме: вкладка «Заказы»", "k":"orders", "r":3000},
	{"t":"Купите детали для следующей сборки на «Рынке»", "k":"bought", "r":2000},
	{"t":"Соберите ещё одну и выставьте её на «Витрину»", "k":"listed", "r":4000},
	{"t":"Загляните в «События» и заберите ежедневную награду", "k":"loginClaims", "r":5000},
]
func tut_tick() -> void:
	while int(S.tut) < TUT.size() and float(S.stats.get(TUT[int(S.tut)].k, 0)) >= float(TUT[int(S.tut)].get("n", 1)):
		var t: Dictionary = TUT[int(S.tut)]
		earn(t.r, "обучение"); toast("Шаг обучения выполнен: +" + rub(t.r), "gold"); S.tut = int(S.tut) + 1
func ach_value(key: String) -> float:
	match key:
		"level": return float(S.level)
		"prestige": return float(S.prestige.count)
	return float(S.stats.get(key, 0))
func ach_tick() -> void:
	for a in Data.ACH:
		if S.ach.has(a[0]): continue
		if ach_value(a[4]) >= float(a[5]):
			S.ach[a[0]] = now()
			if a[3] > 0: earn(float(a[3]) * city_k(), "достижение")
			Audio.ui("rare"); toast("Достижение: [b]%s[/b]%s" % [a[1], (" · +" + rub(float(a[3])*city_k())) if a[3] > 0 else ""], "vio")
			SteamBridge.unlock(a[0])

# ------------------------------------------------------------------ upgrades / skills / prestige
func up_cost(u: Dictionary) -> float: return round(float(u.base) * pow(float(u.k), upl(u.id)) * part_city_k() / 100.0) * 100.0
func buy_upgrade(id: String) -> void:
	for u in Data.UPGRADES:
		if u.id != id: continue
		if upl(id) >= int(u.max): return
		if not spend(up_cost(u)): return
		if id == "repair": repair_payout(now() - float(S.lastRepair)); S.lastRepair = now()
		S.up[id] = upl(id) + 1; Audio.ui("good"); toast("%s: уровень %d" % [u.name, S.up[id]], "gold"); mark(); return
func buy_skill(id: String) -> void:
	if int(S.sp) < 1 or skl(id) >= 10: return
	S.sp = int(S.sp) - 1; S.sk[id] = skl(id) + 1; Audio.ui("good"); mark()
func legend_gain() -> int: return int(floor(pow(max(0.0, float(S.stats.earned)) / 150000.0, 0.55)))
func can_prestige() -> bool: return int(S.level) >= 25 and legend_gain() >= 1
func do_prestige() -> void:
	if not can_prestige(): return
	var gain = legend_gain(); var prev = S
	prev.prestige.count = int(prev.prestige.count) + 1; prev.prestige.legend = int(prev.prestige.legend) + gain
	prev.prestige.city = min(Data.CITIES.size() - 1, int(prev.prestige.city) + 1)
	S = new_state(prev); starter_kit(S); S.orders = []; refill_orders(3); ensure_daily(); ensure_week()
	Audio.ui("level"); toast("Новый филиал в городе %s! +%d очков легенды" % [Data.CITIES[int(S.prestige.city)], gain], "gold"); mark()
func buy_perk(id: String) -> void:
	for p in Data.PERKS:
		if p.id != id: continue
		var l = perk(id)
		if l >= int(p.max): return
		var c = Data.perk_cost(id, l)
		if int(S.prestige.legend) < c: toast("Не хватает очков легенды", "bad"); return
		S.prestige.legend = int(S.prestige.legend) - c; S.prestige.perks[id] = l + 1; Audio.ui("good"); mark(); return

# ------------------------------------------------------------------ save / load
func save_game() -> void:
	if S.is_empty(): return
	S.savedAt = now(); S.lastTick = now()
	var f = FileAccess.open(SAVE_PATH + ".tmp", FileAccess.WRITE)
	if f == null: return
	f.store_string(JSON.stringify(S)); f.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(SAVE_PATH + ".tmp"), ProjectSettings.globalize_path(SAVE_PATH))
	dirty = false
func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH): return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not d is Dictionary: return false
	var old_tut: bool = not d.has("tutv")
	S = merge_defaults(new_state(), d)
	if old_tut:
		if int(S.tut) < 90: S.tut = int(S.tut) + 2
		S.stats.repairs = max(int(S.stats.repairs), 2)
	for b in S.boards:
		if not b.has("st"): b.st = board_stats(b)
	return true
func hydrate_vectors() -> void:
	# JSON turns Vector2 into strings; restore order map positions
	for o in S.orders:
		if o.get("district") is String:
			var s: String = o.district.replace("(", "").replace(")", "")
			var p = s.split(",")
			o.district = Vector2(float(p[0]), float(p[1])) if p.size() == 2 else Vector2(0.5, 0.5)
		elif not o.has("district"): o.district = Vector2(randf_range(0.1,0.9), randf_range(0.1,0.9))
func boot() -> Dictionary:
	var loaded = load_game()
	if not loaded:
		S = new_state(); starter_kit(S)
	hydrate_vectors()
	ensure_daily(); ensure_week(); login_tick()
	var off = process_offline() if loaded else {}
	if S.orders.size() < 2: refill_orders(2)
	save_game()
	return off
func reset_game() -> void:
	S = new_state(); starter_kit(S); ensure_daily(); ensure_week(); login_tick(); refill_orders(2); save_game(); mark()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_game()
