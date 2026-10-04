extends Node
## Static game catalog: parts, layouts, characters, progression tables.
## Plain data comes from res://data/catalog.json (shared with the web build);
## tables that need logic live here.

var C: Dictionary = {}          # raw catalog
var LAYOUTS: Dictionary = {}
var CASES: Array = []
var PLATES: Array = []
var PCBS: Array = []
var STABS: Array = []
var SWITCHES: Array = []
var KEYCAPS: Array = []
var CONS: Array = []
var ARTISANS: Array = []
var PROF: Dictionary = {}
var KMAT: Dictionary = {}
var RARITY: Dictionary = {}
var VIPS: Array = []
var CONTESTS: Array = []
var CITIES: Array = []
var SND_SETS: Dictionary = {}
var _idx: Dictionary = {}

const DAY_SEC := 150.0
const SALE_TICK := 10.0
const ART_BASE := 2500.0

# ---- premises you can buy on the city map -------------------------------
const PROPERTIES := [
	{"id":"garage",   "name":"Гараж на окраине",       "price":0,       "lvl":1,  "storage":0,  "shelf":0, "sale":0.0,  "budget":0.0,  "style":"garage",   "desc":"Бетон, верстак и лампа. С чего-то надо начинать."},
	{"id":"loft",     "name":"Лофт в промзоне",        "price":150000,  "lvl":6,  "storage":6,  "shelf":1, "sale":0.10, "budget":0.04, "style":"loft",     "desc":"Кирпич, большие окна, место под витрину."},
	{"id":"studio",   "name":"Студия у метро",         "price":600000,  "lvl":12, "storage":10, "shelf":2, "sale":0.25, "budget":0.08, "style":"studio",   "desc":"Поток покупателей и клиенты посолиднее."},
	{"id":"boutique", "name":"Бутик в центре",         "price":2500000, "lvl":20, "storage":16, "shelf":3, "sale":0.45, "budget":0.15, "style":"boutique", "desc":"Витрина на главной улице. Сюда заходят коллекционеры."},
	{"id":"flagship", "name":"Флагман на набережной",  "price":9000000, "lvl":30, "storage":24, "shelf":4, "sale":0.70, "budget":0.25, "style":"flagship", "desc":"Легендарный адрес. О вас пишут в журналах."},
]

# ---- suppliers on the city map ----------------------------------------
const SUPPLIERS := [
	{"id":"radio",  "name":"Радиорынок «Митино»",  "cats":["sw","cons","stab"], "mod":-0.10, "lvl":1,  "pos":Vector2(0.22,0.30), "desc":"Свитчи и расходники дешевле на 10%."},
	{"id":"metal",  "name":"Завод «Металлист»",     "cats":["case","plate","pcb"], "mod":-0.10, "lvl":1, "pos":Vector2(0.78,0.24), "desc":"Корпуса, пластины и платы дешевле на 10%."},
	{"id":"caps",   "name":"Склад «Кейкап-Сити»",   "cats":["kc"], "mod":-0.12, "lvl":3,  "pos":Vector2(0.68,0.72), "desc":"Наборы кейкапов дешевле на 12%."},
	{"id":"import", "name":"Импорт-хаб",            "cats":["case","plate","pcb","stab","sw","kc","cons"], "mod":0.0, "lvl":1, "pos":Vector2(0.30,0.76), "desc":"Всё в одном месте по обычной цене."},
]

# ---- mystery boxes (in-game currency only, odds shown to the player) ---
const BOXES := [
	{"id":"box_sw",   "name":"Коробка свитчей",   "price":18000,  "lvl":1,  "pool":"sw",   "col":Color("4cb8ab"), "desc":"Пачка свитчей на целую сборку. Шанс на эксклюзив."},
	{"id":"box_kc",   "name":"Коробка кейкапов",  "price":32000,  "lvl":4,  "pool":"kc",   "col":Color("ff8160"), "desc":"Набор кейкапов. Шанс на голографическую серию."},
	{"id":"box_art",  "name":"Коробка артизанов", "price":45000,  "lvl":6,  "pool":"art",  "col":Color("a98bf0"), "desc":"Артизан-кейкап ручной работы."},
	{"id":"box_pro",  "name":"Сундук мастера",    "price":140000, "lvl":14, "pool":"mix",  "col":Color("ebc66c"), "desc":"Что угодно, но с повышенным шансом на редкость."},
]
const BOX_ODDS := {"common":0.70, "rare":0.22, "epic":0.065, "legendary":0.015}
const BOX_ODDS_PRO := {"common":0.40, "rare":0.38, "epic":0.17, "legendary":0.05}

# Case-exclusive items (only from boxes or trading)
const EXCLUSIVE_SWITCHES := [
	{"id":"sw_holo","snd":"cream","name":"Голограмма","type":"linear","force":55,"price":190,"lvl":1,"pitch":-0.2,"loud":0.64,"scratch":0.02,"ping":0.03,"click":0,"tact":0,"lube":0.8,"stem":"#d8b4ff","hous":"#e6f7ff","desc":"Эксклюзив из коробок: мраморный тон, переливающийся корпус","box":"epic"},
	{"id":"sw_obsid","snd":"holypanda","name":"Вулканическое стекло","type":"tactile","force":68,"price":210,"lvl":1,"pitch":-0.38,"loud":0.78,"scratch":0.03,"ping":0.03,"click":0,"tact":0.95,"lube":0.6,"stem":"#151515","hous":"#2a1a2e","desc":"Эксклюзив из коробок: глубокий резкий тактиль","box":"legendary"},
	{"id":"sw_mint","snd":"alpaca","name":"Мятный ветер","type":"linear","force":48,"price":120,"lvl":1,"pitch":-0.08,"loud":0.6,"scratch":0.05,"ping":0.06,"click":0,"tact":0,"lube":0.65,"stem":"#8ff0c8","hous":"#f2fffa","desc":"Эксклюзив из коробок: лёгкий и гладкий","box":"rare"},
]
const EXCLUSIVE_KEYCAPS := [
	{"id":"k_holo","name":"Голографическая серия","prof":"sa","mat":"ABS","price":38000,"lvl":1,"tags":["cyber","bright","elegant"],"c":{"a":"#e9e3ff","al":"#6b4cff","m":"#b8f2ff","ml":"#3a2a8f","x":"#ff9de2","xl":"#ffffff","sp":"m"},"box":"epic"},
	{"id":"k_gold","name":"Золотой век","prof":"mt3","mat":"ABS","price":52000,"lvl":1,"tags":["elegant","retro","dark"],"c":{"a":"#1c1a17","al":"#e8c26a","m":"#2b2620","ml":"#e8c26a","x":"#e8c26a","xl":"#1c1a17","sp":"a"},"box":"legendary"},
	{"id":"k_frost","name":"Иней","prof":"cherry","mat":"PBT","price":21000,"lvl":1,"tags":["light","minimal","pastel"],"c":{"a":"#f4f8fb","al":"#7a96ad","m":"#d6e4ee","ml":"#3d5466","x":"#9ad0f5","xl":"#18324a","sp":"a"},"box":"rare"},
]

func _ready() -> void:
	load_catalog()

func load_catalog() -> void:
	var txt = FileAccess.get_file_as_string("res://data/catalog.json")
	C = JSON.parse_string(txt)
	LAYOUTS = C.LAYOUTS
	CASES = C.CASES; PLATES = C.PLATES; PCBS = C.PCBS; STABS = C.STABS
	SWITCHES = C.SWITCHES; KEYCAPS = C.KEYCAPS; CONS = C.CONS; ARTISANS = C.ARTISANS
	PROF = C.PROF; KMAT = C.KMAT; RARITY = C.RARITY; VIPS = C.VIPS; CONTESTS = C.CONTESTS
	CITIES = C.CITIES; SND_SETS = C.SND_SETS
	for s in EXCLUSIVE_SWITCHES: SWITCHES.append(s.duplicate(true))
	for k in EXCLUSIVE_KEYCAPS: KEYCAPS.append(k.duplicate(true))
	_idx.clear()
	for list_name in ["CASES","PLATES","PCBS","STABS","SWITCHES","KEYCAPS","CONS","ARTISANS","VIPS","CONTESTS"]:
		var arr: Array = get(list_name)
		for it in arr: _idx[list_name + ":" + str(it.id)] = it
	for k in LAYOUTS: _prep_layout(k)

func _prep_layout(id: String) -> void:
	var L: Dictionary = LAYOUTS[id]
	var rows = 0
	for k in L.keys:
		k.row = int(k.row)
		rows = max(rows, k.row + 1)
	L.rows = rows
	L.count = L.keys.size()

func by_id(list_name: String, id) -> Dictionary:
	return _idx.get(list_name + ":" + str(id), {})
func sw(id) -> Dictionary: return by_id("SWITCHES", id)
func kc(id) -> Dictionary: return by_id("KEYCAPS", id)
func case_(id) -> Dictionary: return by_id("CASES", id)
func plate(id) -> Dictionary: return by_id("PLATES", id)
func pcb(id) -> Dictionary: return by_id("PCBS", id)
func stab(id) -> Dictionary: return by_id("STABS", id)
func art(id) -> Dictionary: return by_id("ARTISANS", id)
func cons(id) -> Dictionary: return by_id("CONS", id)
func cat_list(cat: String) -> Array:
	match cat:
		"case": return CASES
		"plate": return PLATES
		"pcb": return PCBS
		"stab": return STABS
		"kc": return KEYCAPS
		"sw": return SWITCHES
		"cons": return CONS
	return []
func item(cat: String, id) -> Dictionary:
	match cat:
		"case": return case_(id)
		"plate": return plate(id)
		"pcb": return pcb(id)
		"stab": return stab(id)
		"kc": return kc(id)
		"sw": return sw(id)
		"cons": return cons(id)
		"art": return art(id)
	return {}
func prop(id) -> Dictionary:
	for p in PROPERTIES:
		if p.id == id: return p
	return PROPERTIES[0]
func supplier(id) -> Dictionary:
	for s in SUPPLIERS:
		if s.id == id: return s
	return SUPPLIERS[3]
func box(id) -> Dictionary:
	for b in BOXES:
		if b.id == id: return b
	return {}

const CAT_NAMES := {"case":"Корпуса","plate":"Пластины","pcb":"Платы","stab":"Стабилизаторы","sw":"Свитчи","kc":"Кейкапы","cons":"Расходники"}
const STYPE := {"linear":"линейные","tactile":"тактильные","clicky":"кликающие","silent":"тихие"}
const TAGS := {"pastel":"пастель","dark":"тёмная гамма","light":"светлая гамма","retro":"ретро","bright":"яркие цвета","nature":"природа","cyber":"киберпанк","minimal":"минимализм","elegant":"элегантность"}
const TRENDS := {"thock":"Thock","clack":"Clack","silent":"Тишина","clicky":"Клики","pastel":"Пастель","retro":"Ретро","cyber":"Киберпанк","rgb":"RGB-подсветка","wireless":"Беспроводные","nature":"Природа","elegant":"Элегантность"}
const RAR_ORDER := ["common","rare","epic","legendary"]
const RAR_NAME := {"common":"Обычный","rare":"Редкий","epic":"Эпический","legendary":"Легендарный"}
const RAR_COL := {"common":Color("a7b3bd"),"rare":Color("5fa8ff"),"epic":Color("c07bff"),"legendary":Color("ffb340")}

# ---- upgrades / skills / perks ----------------------------------------
const UPGRADES := [
	{"id":"bench",   "name":"Верстак",                    "max":4, "base":9000,  "k":2.7},
	{"id":"lubest",  "name":"Станция смазки",             "max":5, "base":6000,  "k":2.4},
	{"id":"solder",  "name":"Паяльная станция",           "max":3, "base":8000,  "k":2.4},
	{"id":"driver",  "name":"Динамометрическая отвёртка", "max":3, "base":7000,  "k":2.3},
	{"id":"storage", "name":"Стеллажи на складе",         "max":8, "base":5000,  "k":1.9},
	{"id":"shelf",   "name":"Витрина",                    "max":6, "base":8000,  "k":2.1},
	{"id":"orders",  "name":"Доска заказов",              "max":5, "base":7000,  "k":2.2},
	{"id":"ads",     "name":"Реклама",                    "max":6, "base":10000, "k":2.0},
	{"id":"studio",  "name":"Звуковая студия",            "max":3, "base":15000, "k":3.0},
	{"id":"repair",  "name":"Ремонтная стойка",           "max":8, "base":12000, "k":1.85},
	{"id":"supply",  "name":"Связи с поставщиками",       "max":6, "base":14000, "k":2.1},
	{"id":"manager", "name":"Офлайн-менеджер",            "max":4, "base":20000, "k":2.3},
]
func upgrade_desc(id: String, l: int) -> String:
	match id:
		"bench": return ["Голый стол: ножки свитчей гнутся, если вести руку быстро","Магнитный коврик: руку можно вести на 35% быстрее","Упор и подсветка: на 70% быстрее, случайных изгибов вдвое меньше","Кнопка «Авто» на этапах сборки (точность чуть ниже ручной)","Профессиональный верстак: +4 к качеству каждой сборки"][min(l,4)]
		"lubest": return "Кисть шире на %d%%: проще попасть в направляющие" % (l*12) if l > 0 else "Обычная кисточка"
		"solder": return "Пайка одного контакта: %.2f с" % (0.22/(1.0+0.5*l))
		"driver": return ("Зелёная зона усилия: %d%% шкалы, стрелка медленнее" % int(round((0.2+0.05*l)*100))) if l > 0 else "Обычная отвёртка: зелёная зона 20% шкалы"
		"storage": return "Вместимость склада: %d мест" % Game.storage_cap(l)
		"shelf": return "Слотов на витрине: %d" % (2 + l + Game.prop_bonus("shelf"))
		"orders": return "Одновременно заказов: %d" % (3 + l)
		"ads": return "Покупатели на витрине: +%d%%" % (l*18)
		"studio": return ["Без анализатора","Анализатор звука с цифрами","+5% к оценке звука на конкурсах","+10% к оценке звука на конкурсах"][l]
		"repair": return "Пассивный доход: %s ₽/час (и офлайн)" % Game.fmt(Game.repair_rate(l))
		"supply": return "Скидка на детали: %d%%" % (l*3)
		"manager": return "Витрина работает без вас до %d ч" % (4 + l*2)
	return ""

const SKILLS := [
	{"id":"lube",   "name":"Мастер смазки", "desc":"+4% к ширине кисти и +2% к качеству смазки за ранг"},
	{"id":"acoust", "name":"Акустик",       "desc":"+1.5 к качеству каждой сборки за ранг"},
	{"id":"trade",  "name":"Торговец",      "desc":"+3% к цене продажи за ранг"},
	{"id":"haggle", "name":"Снабженец",     "desc":"−2% к ценам деталей за ранг"},
	{"id":"charm",  "name":"Обаяние",       "desc":"+10% к росту репутации и +5% к чаевым за ранг"},
	{"id":"luck",   "name":"Коллекционер",  "desc":"+15% к шансу выпадения артизанов и редких вещей за ранг"},
]
const PERKS := [
	{"id":"cash",  "name":"Стартовый капитал", "max":10, "desc":"+15 000 ₽ на старте филиала за ранг"},
	{"id":"price", "name":"Имя бренда",        "max":20, "desc":"+4% ко всем доходам за ранг"},
	{"id":"xp",    "name":"Опыт мастера",      "max":10, "desc":"+10% опыта за ранг"},
	{"id":"drop",  "name":"Удача",             "max":10, "desc":"+10% к шансу артизанов за ранг"},
	{"id":"head",  "name":"Фора",              "max":5,  "desc":"Начинать филиал с +2 уровнями за ранг"},
]
func perk_cost(id: String, l: int) -> int:
	match id:
		"cash": return 1 + l
		"price": return 1 + l / 2
		"xp": return 1 + l
		"drop": return 2 + l
		"head": return 2 + l * 2
	return 99

# ---- achievements: id, name, desc, reward, check key, threshold --------
const ACH := [
	["b1","Первая сборка","Соберите клавиатуру",2000,"built",1],
	["b10","Руки помнят","Соберите 10 клавиатур",10000,"built",10],
	["b50","Конвейер","Соберите 50 клавиатур",50000,"built",50],
	["b200","Легенда верстака","Соберите 200 клавиатур",200000,"built",200],
	["o1","Первый клиент","Выполните заказ",2000,"orders",1],
	["o25","Сарафанное радио","Выполните 25 заказов",25000,"orders",25],
	["o100","Очередь до угла","Выполните 100 заказов",100000,"orders",100],
	["st1","Пять звёзд","Получите отзыв 5★",5000,"five",1],
	["st20","Любимец публики","Получите 20 отзывов 5★",40000,"five",20],
	["s1","Открыто!","Продайте клавиатуру с витрины",3000,"sold",1],
	["s30","Бойкая лавка","Продайте 30 клавиатур с витрины",40000,"sold",30],
	["m100","Первые сто тысяч","Заработайте 100 000 ₽",5000,"earnedAll",100000],
	["m1m","Миллионер","Заработайте 1 000 000 ₽",50000,"earnedAll",1000000],
	["m10m","Клавиатурный магнат","Заработайте 10 000 000 ₽",300000,"earnedAll",10000000],
	["big","Дорогая штучка","Продайте клавиатуру дороже 150 000 ₽",30000,"maxSale",150000],
	["thk","Thock-гуру","Соберите клавиатуру с thock от 88",15000,"maxThock",88],
	["q90","Перфекционист","Качество сборки 90+",20000,"maxQ",90],
	["q98","Безупречно","Качество сборки 98+",80000,"maxQ",98],
	["lp","Рука не дрогнула","Смажьте свитчи на 100%",8000,"perfectLube",1],
	["full","С цифровым блоком","Соберите полноразмерную клавиатуру",15000,"fullBuilt",1],
	["box1","Сюрприз","Откройте первую коробку",3000,"boxes",1],
	["box50","Азарт коллекционера","Откройте 50 коробок",60000,"boxes",50],
	["trade1","Честный обмен","Совершите обмен с другим мастером",5000,"trades",1],
	["prop1","Новый адрес","Купите новое помещение",20000,"props",1],
	["cw","Чемпион","Займите 1 место в недельном конкурсе",50000,"contestWins",1],
	["l10","Подмастерье","Достигните 10 уровня",10000,"level",10],
	["l25","Мастер","Достигните 25 уровня",50000,"level",25],
	["pr1","Сеть мастерских","Откройте филиал в новом городе",0,"prestige",1],
]
