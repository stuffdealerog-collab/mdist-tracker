extends Node
## Keyboard audio built from real recordings:
##  - switch sets (kbsim MIT + live CC0 recordings) with many press/release variations
##  - keycap cavity resonance (profile + material) and tone shaping per build (EQ21)
##  - case "hollowness" layers made by convolving each press with a real hollow knock
##  - real stabilizer rattle (rattly spacebars), spring ping (battery spring), grit (bristle friction)
##  - foley / UI from CC0 recordings (assets/snd2/_fx), synth only as a fallback

const RATE := 44100
const SND := "res://assets/snd2/"

var sets = {}                 # set -> {press_g:[...], release_g:[...], press_big:[...], release_big:[...], hollow:[...]}
var layers = {}               # ping / rattle / scratch / ring -> [streams]
var fx = {}                   # name -> stream
var manifest = {}
var key_players: Array[AudioStreamPlayer] = []
var ui_players: Array[AudioStreamPlayer] = []
var _kp = 0
var _up = 0
var keys_bus = -1
var eq: AudioEffectEQ21
var cav: AudioEffectBandPassFilter
var body_eq: AudioEffectEQ10
var room_rev: AudioEffectReverb
var syn = {}                  # synthesized fallbacks
var ambient: AudioStreamPlayer
var current_P = {}
var _last := {}               # avoid repeating the same variation twice in a row

func _ready() -> void:
	_setup_buses()
	for i in 40:
		var p = AudioStreamPlayer.new(); p.bus = "Keys"; add_child(p); key_players.append(p)
	for i in 12:
		var p = AudioStreamPlayer.new(); p.bus = "UI"; add_child(p); ui_players.append(p)
	_make_synth()
	_load_manifest()
	ambient = AudioStreamPlayer.new(); ambient.bus = "Ambient"; ambient.stream = syn.room; ambient.volume_db = -30; add_child(ambient)
	ambient.play()

func _bus(name: String, send := "Master") -> int:
	var i := AudioServer.get_bus_index(name)
	if i == -1:
		AudioServer.add_bus(); i = AudioServer.bus_count - 1; AudioServer.set_bus_name(i, name)
	AudioServer.set_bus_send(i, send)
	return i

func _setup_buses() -> void:
	keys_bus = _bus("Keys")
	var cav_bus := _bus("Cavity", "Keys")
	var body_bus := _bus("Body", "Keys")
	_bus("UI"); _bus("Ambient")
	eq = AudioEffectEQ21.new(); AudioServer.add_bus_effect(keys_bus, eq)
	var comp := AudioEffectCompressor.new(); comp.threshold = -14.0; comp.ratio = 2.5; comp.attack_us = 800.0; comp.release_ms = 80.0
	AudioServer.add_bus_effect(keys_bus, comp)
	room_rev = AudioEffectReverb.new(); room_rev.room_size = 0.22; room_rev.damping = 0.65; room_rev.wet = 0.08; room_rev.dry = 1.0; room_rev.spread = 0.7; room_rev.predelay_msec = 8.0
	AudioServer.add_bus_effect(keys_bus, room_rev)
	cav = AudioEffectBandPassFilter.new(); cav.cutoff_hz = 1800.0; cav.resonance = 0.75; cav.db = AudioEffectFilter.FILTER_24DB
	AudioServer.add_bus_effect(cav_bus, cav)
	body_eq = AudioEffectEQ10.new(); AudioServer.add_bus_effect(body_bus, body_eq)
	var lim := AudioEffectLimiter.new(); lim.ceiling_db = -0.5; lim.threshold_db = -6
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Master"), lim)

func apply_settings() -> void:
	if Game.S.is_empty(): return
	var st: Dictionary = Game.S.settings
	AudioServer.set_bus_mute(0, not st.sound)
	AudioServer.set_bus_volume_db(0, linear_to_db(max(0.0001, float(st.vol))))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Ambient"), linear_to_db(max(0.0001, float(st.get("music", 0.4)))))

func _load_manifest() -> void:
	var path := SND + "manifest.json"
	if FileAccess.file_exists(path): manifest = JSON.parse_string(FileAccess.get_file_as_string(path))
	if manifest == null: manifest = {}
	var lm: Dictionary = manifest.get("_layers", {})
	for k in lm:
		layers[k] = []
		for i in int(lm[k]):
			var f := SND + "_layers/%s_%02d.ogg" % [k, i]
			if ResourceLoader.exists(f): layers[k].append(load(f))
	for n in manifest.get("_fx", []):
		var f := SND + "_fx/%s.ogg" % n
		if ResourceLoader.exists(f): fx[n] = load(f)

func load_set(s: String) -> Dictionary:
	if s == "": return {}
	if sets.has(s): return sets[s]
	var m: Dictionary = manifest.get(s, {})
	var out := {}
	for kind in ["press_g", "release_g", "press_big", "release_big", "hollow"]:
		out[kind] = []
		for i in int(m.get(kind, 0)):
			var f := SND + "%s/%s_%02d.ogg" % [s, kind, i]
			if ResourceLoader.exists(f): out[kind].append(load(f))
	sets[s] = out
	return out

# keycap cavity: profile -> (centre Hz, level); material shifts the resonance
const CAVITY := {"cherry": [2400.0, 0.22], "oem": [2000.0, 0.3], "kat": [1850.0, 0.34], "xda": [2600.0, 0.2], "sa": [1300.0, 0.5], "mt3": [1200.0, 0.48]}
# EQ21 centres: 22 32 44 63 90 125 175 250 350 500 700 1k 1.4k 2k 2.8k 4k 5.6k 8k 11k 16k 22k
const BANDS := [22, 32, 44, 63, 90, 125, 175, 250, 350, 500, 700, 1000, 1400, 2000, 2800, 4000, 5600, 8000, 11000, 16000, 22000]

## Shape the buses to the current build (called when a keyboard becomes active).
func set_profile(P: Dictionary) -> void:
	current_P = P
	if P.is_empty(): return
	var sh := float(P.get("shift", 0.0))
	var hollow := float(P.get("hollow", 0.0))
	var prof: String = P.get("prof", "cherry"); var mat: String = P.get("kmat", "PBT")
	var look: String = P.get("look", "metal"); var plate: String = P.get("plate", "p_alu")
	var silent: bool = P.get("silent", false)
	var g := []; g.resize(21); g.fill(0.0)
	for i in 21:
		var f: float = BANDS[i]
		var lo := clampf(1.0 - log(f / 90.0) / log(8.0), 0.0, 1.0)          # weight toward lows
		var hi := clampf(log(f / 1400.0) / log(6.0), 0.0, 1.0)               # weight toward highs
		g[i] += -sh * 7.0 * lo + sh * 7.0 * hi                              # deeper / brighter build
		if mat == "PBT": g[i] += (1.5 if f >= 250 and f <= 700 else 0.0) - (2.5 * hi)
		else: g[i] += 2.0 * hi * (1.0 if f < 9000 else 0.5)
		if prof in ["sa", "mt3"] and f >= 500 and f <= 1400: g[i] += 2.5
		if plate in ["p_brass", "p_alu"] and f >= 2800 and f <= 5600: g[i] += 1.5
		if plate in ["p_pc", "p_pom"]:
			g[i] += (1.2 if f >= 175 and f <= 350 else 0.0) - (2.0 if f >= 2800 and f <= 8000 else 0.0)
		if P.get("tape", false): g[i] += (2.0 if f >= 175 and f <= 350 else 0.0) - (1.5 if f >= 5600 else 0.0)
		if silent: g[i] -= 14.0 * hi
		if f < 40: g[i] -= 6.0
	for i in 21: eq.set_band_gain_db(i, clampf(g[i], -18.0, 9.0))
	var c: Array = CAVITY.get(prof, CAVITY.cherry)
	cav.cutoff_hz = float(c[0]) * (1.15 if mat == "ABS" else 0.88)
	cav.resonance = 0.82 if mat == "ABS" else 0.65
	# case body colour for the hollowness layer (EQ10: 31 62 125 250 500 1k 2k 4k 8k 16k)
	var b := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	match look:
		"plastic": b = [-6.0, 0.0, 3.0, 5.0, 3.0, 0.0, -4.0, -8.0, -12.0, -15.0]
		"acrylic": b = [-8.0, -3.0, 0.0, 2.0, 5.0, 3.0, -2.0, -6.0, -10.0, -14.0]
		"wood": b = [-6.0, 0.0, 4.0, 4.0, 1.0, -2.0, -6.0, -10.0, -14.0, -16.0]
		_: b = [-10.0, -6.0, -2.0, 1.0, 3.0, 4.0, 2.0, -3.0, -8.0, -12.0]   # metal: tighter, higher
	for i in 10: body_eq.set_band_gain_db(i, b[i])

## Room acoustics follow the property (concrete garage is lively, the boutique is damped).
func set_room(style: String) -> void:
	var r: Array = {"garage": [0.42, 0.45, 0.13], "loft": [0.5, 0.5, 0.11], "studio": [0.28, 0.7, 0.07], "boutique": [0.3, 0.8, 0.06], "flagship": [0.36, 0.6, 0.08]}.get(style, [0.25, 0.65, 0.08])
	room_rev.room_size = r[0]; room_rev.damping = r[1]; room_rev.wet = r[2]

func _player(bus := "Keys") -> AudioStreamPlayer:
	_kp = (_kp + 1) % key_players.size()
	var p := key_players[_kp]; p.bus = bus
	return p

func _pick(arr: Array, tag: String) -> int:
	if arr.is_empty(): return -1
	if arr.size() == 1: return 0
	var i := randi() % arr.size()
	if i == int(_last.get(tag, -1)): i = (i + 1 + randi() % (arr.size() - 1)) % arr.size()
	_last[tag] = i
	return i

func _play(stream: AudioStream, gain: float, pitch: float, bus := "Keys") -> void:
	if stream == null or gain <= 0.0004: return
	var p := _player(bus); p.stream = stream; p.pitch_scale = clampf(pitch, 0.5, 2.0); p.volume_db = linear_to_db(gain); p.play()

## k: layout key dictionary {w,row,codes}; fgap: layout has an F-row
func key(P: Dictionary, k: Dictionary, up: bool, fgap := false) -> void:
	if Game.S.is_empty() or not Game.S.settings.sound: return
	if P != current_P: set_profile(P)
	var s: Dictionary = load_set(P.get("snd", ""))
	if s.is_empty(): return
	var w := float(k.get("w", 1.0)); var code: String = k.get("codes", [""])[0]
	var big: bool = w >= 2.0 or code in ["Space", "Enter", "NumpadEnter", "Backspace"]
	var row: int = clampi(int(k.get("row", 2)) - (1 if fgap else 0), 0, 4)
	var silent: bool = P.get("silent", false)
	var loud := 0.35 + float(P.get("loud", 0.6)) * 0.8
	var base_pitch := clampf(pow(2.0, float(P.get("shift", 0.0)) * 0.5), 0.78, 1.3)
	# alphas: top rows are slightly higher, like on a real board
	var row_pitch: float = 1.0 + (2 - row) * 0.012 if not big else 0.97
	var pitch := base_pitch * row_pitch * (1.0 + (randf() - 0.5) * 0.03)
	var rattle := float(P.get("rattle", 0.0))
	var bank: Array
	if up: bank = s.release_big if big and not s.release_big.is_empty() else s.release_g
	else: bank = s.press_big if big and not s.press_big.is_empty() else s.press_g
	var idx := _pick(bank, ("u" if up else "d") + ("b" if big else "g"))
	if idx < 0: return
	var main_gain := loud * (0.4 if silent else 1.0) * (0.85 if up else 1.0) * randf_range(0.93, 1.07)
	if big and rattle > 0.25: main_gain *= 1.0 - clampf(rattle, 0.0, 1.0) * 0.4
	_play(bank[idx], main_gain, pitch)
	# keycap cavity colour (louder on tall profiles, ABS rings more than PBT)
	var c: Array = CAVITY.get(P.get("prof", "cherry"), CAVITY.cherry)
	var cav_gain := float(c[1]) * (1.2 if P.get("kmat", "PBT") == "ABS" else 0.8) * (0.5 if up else 1.0)
	_play(bank[idx], main_gain * cav_gain, pitch, "Cavity")
	if not up:
		# case hollowness: real resonance layer for this exact press
		var hol := float(P.get("hollow", 0.0))
		if hol > 0.08 and not s.hollow.is_empty():
			var hi: int = idx if not big else randi() % s.hollow.size()
			_play(s.hollow[hi % s.hollow.size()], loud * hol * 1.1 * (0.5 if silent else 1.0), pitch * (0.92 if big else 1.0), "Body")
		# scratchy stem rails
		var scr := float(P.get("scratch", 0.0))
		if scr > 0.15 and layers.has("scratch") and not layers.scratch.is_empty():
			_play(layers.scratch[_pick(layers.scratch, "scr")], loud * scr * 0.22, randf_range(0.9, 1.15))
		# metal case ring on bottom-out
		var ring := float(P.get("ring", 0.0))
		if ring > 0.25 and P.get("look", "") == "metal" and layers.has("ring"):
			_play(layers.ring[randi() % layers.ring.size()], loud * (ring - 0.2) * 0.07, randf_range(0.95, 1.05), "Body")
	# spring ping (both directions; an unlubed spring rings on release too)
	var ping := float(P.get("ping", 0.0))
	if ping > 0.1 and layers.has("ping") and not layers.ping.is_empty():
		_play(layers.ping[_pick(layers.ping, "ping")], loud * (ping - 0.08) * 0.13 * (0.7 if up else 1.0), randf_range(0.92, 1.12))
	# stabilizer rattle: real rattly spacebar hits on long keys
	if big and rattle > 0.25 and layers.has("rattle") and not layers.rattle.is_empty():
		_play(layers.rattle[_pick(layers.rattle, "rat")], loud * (rattle - 0.15) * (0.55 if up else 0.85), pitch * randf_range(0.97, 1.03))

const UI_GAIN := {"tick": -12.0, "rtick": -14.0, "hover": -24.0, "click": -10.0, "spin": -9.0, "socket": -5.0, "cap": -6.0, "pull": -7.0,
	"ratchet": -8.0, "thud": -5.0, "sizzle": -10.0, "lube": -9.0, "coin": -6.0, "coins": -7.0, "sale": -6.0, "buy": -8.0, "box_open": -6.0,
	"tape": -8.0, "whoosh": -12.0, "open": -10.0, "good": -9.0, "level": -5.0, "bad": -6.0, "rare": -4.0, "drawer": -9.0, "reveal": -6.0}
const UI_ALIAS := {"reveal": "good"}

func ui(name: String) -> void:
	if Game.S.is_empty() or not Game.S.settings.sound: return
	var n: String = name if fx.has(name) else UI_ALIAS.get(name, name)
	var stream = fx.get(n, syn.get(name, null))
	if stream == null: return
	_up = (_up + 1) % ui_players.size()
	var p = ui_players[_up]; p.stream = stream
	p.pitch_scale = randf_range(0.96, 1.05) if name in ["tick", "rtick", "socket", "cap", "ratchet", "spin", "coin", "hover", "click"] else 1.0
	p.volume_db = float(UI_GAIN.get(name, -6.0))
	p.play()

func socket(cap: bool) -> void:
	ui("cap" if cap else "socket")

# ------------------------------------------------------------------ room foley
## Real CC0 room / unboxing / delivery recordings from assets/snd2/_room (see tools/build_room_snd.py).
const ROOM := SND + "_room/"
const ROOM_GAIN := {"step": -14.0, "pc_hum": -20.0, "doorbell": -4.0, "knock": -3.0, "bubble": -8.0, "mouse": -12.0, "box_down": -6.0,
	"alarm": -10.0, "bed": -8.0, "label_print": -8.0, "tape_seal": -5.0, "film_peel": -4.0, "knife_cut": -4.0, "phone_vib": -8.0, "aquarium": -19.0}
var room_snd := {}            # name -> [streams]
var _room_players: Array[AudioStreamPlayer3D] = []
var _room_flat: Array[AudioStreamPlayer] = []
var _rp := 0
var _rf := 0
var _loops := {}

func _room_load() -> void:
	if not room_snd.is_empty(): return
	var path := ROOM + "manifest.json"
	if not FileAccess.file_exists(path): return
	var m = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not m is Dictionary: return
	for k in m:
		room_snd[k] = []
		for i in int(m[k]):
			var f := ROOM + "%s_%02d.ogg" % [k, i]
			if ResourceLoader.exists(f): room_snd[k].append(load(f))
	for i in 16:
		var p := AudioStreamPlayer3D.new(); p.bus = "UI"; p.unit_size = 2.5; p.max_distance = 18.0; p.attenuation_filter_cutoff_hz = 9000.0
		p.attenuation_filter_db = -12.0; add_child(p); _room_players.append(p)
	for i in 8:
		var q := AudioStreamPlayer.new(); q.bus = "UI"; add_child(q); _room_flat.append(q)

func room_has(name: String) -> bool:
	_room_load(); return room_snd.has(name) and not (room_snd[name] as Array).is_empty()

## Plays a room sound. With a position it is spatial (3D), otherwise it plays "in the head" (player's own hands).
func sfx(name: String, pos = null, gain_db := 0.0, pitch_var := 0.06) -> void:
	if Game.S.is_empty() or not Game.S.settings.sound: return
	_room_load()
	var arr: Array = room_snd.get(name, [])
	if arr.is_empty(): ui(name); return
	var s: AudioStream = arr[_pick(arr, "r_" + name)]
	var db: float = float(ROOM_GAIN.get(name, -6.0)) + gain_db
	var pitch: float = randf_range(1.0 - pitch_var, 1.0 + pitch_var)
	if pos is Vector3:
		_rp = (_rp + 1) % _room_players.size()
		var p := _room_players[_rp]; p.stop(); p.global_position = pos; p.stream = s; p.volume_db = db + 4.0; p.pitch_scale = pitch; p.play()
	else:
		_rf = (_rf + 1) % _room_flat.size()
		var q := _room_flat[_rf]; q.stream = s; q.volume_db = db; q.pitch_scale = pitch; q.play()

## Starts (or moves) a looping spatial sound, e.g. the PC fan hum.
func loop3d(id: String, name: String, pos: Vector3, gain_db := 0.0) -> void:
	_room_load()
	var arr: Array = room_snd.get(name, [])
	if arr.is_empty(): return
	var p: AudioStreamPlayer3D = _loops.get(id)
	if p == null:
		p = AudioStreamPlayer3D.new(); p.bus = "Ambient"; p.unit_size = 1.2; p.max_distance = 10.0; add_child(p); _loops[id] = p
		var st: AudioStream = (arr[0] as AudioStream).duplicate()
		if st is AudioStreamOggVorbis: (st as AudioStreamOggVorbis).loop = true
		p.stream = st
	p.global_position = pos; p.volume_db = float(ROOM_GAIN.get(name, -12.0)) + gain_db
	if not p.playing: p.play()

func stop_loop(id: String) -> void:
	var p: AudioStreamPlayer3D = _loops.get(id)
	if p: p.queue_free(); _loops.erase(id)

# ------------------------------------------------------------------ synthesis
func _wav(data: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var bytes = PackedByteArray(); bytes.resize(data.size() * 2)
	for i in data.size():
		bytes.encode_s16(i * 2, int(clamp(data[i], -1.0, 1.0) * 32000.0))
	var w = AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = RATE; w.stereo = false; w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD; w.loop_begin = 0; w.loop_end = data.size()
	return w
func _tone(freq: float, dur: float, decay: float, type := "sine", gain := 0.6, f2 := -1.0) -> PackedFloat32Array:
	var n = int(dur * RATE); var out = PackedFloat32Array(); out.resize(n); var ph = 0.0
	for i in n:
		var t = float(i) / RATE
		var f = freq if f2 < 0 else lerp(freq, f2, t / dur)
		ph += TAU * f / RATE
		var v: float
		match type:
			"tri": v = 2.0 / PI * asin(sin(ph))
			"sq": v = sign(sin(ph)) * 0.6
			_: v = sin(ph)
		var env: float = min(1.0, t / 0.002) * exp(-t / decay)
		out[i] = v * env * gain
	return out
func _noise(dur: float, decay: float, lp := 0.5, gain := 0.6, attack := 0.001) -> PackedFloat32Array:
	var n = int(dur * RATE); var out = PackedFloat32Array(); out.resize(n); var y = 0.0
	for i in n:
		var t = float(i) / RATE
		y = lerp(y, randf() * 2.0 - 1.0, lp)
		out[i] = y * min(1.0, t / attack) * exp(-t / decay) * gain
	return out
func _mix(a: PackedFloat32Array, b: PackedFloat32Array, offset := 0) -> PackedFloat32Array:
	var n: int = max(a.size(), b.size() + offset); var out = PackedFloat32Array(); out.resize(n)
	for i in n:
		var v = 0.0
		if i < a.size(): v += a[i]
		if i - offset >= 0 and i - offset < b.size(): v += b[i - offset]
		out[i] = v
	return out
func _make_synth() -> void:
	syn.ping = _wav(_tone(5600, 0.3, 0.09, "sine", 0.5))
	syn.hollow = _wav(_tone(160, 0.25, 0.07, "tri", 0.8))
	syn.rattle = _wav(_mix(_noise(0.04, 0.008, 0.35, 0.7), _noise(0.03, 0.006, 0.5, 0.5), int(0.013 * RATE)))
	syn.coin = _wav(_mix(_tone(1318, 0.12, 0.05, "tri", 0.5), _tone(1976, 0.35, 0.12, "tri", 0.5), int(0.07 * RATE)))
	var lv = _tone(523, 0.3, 0.12, "tri", 0.4)
	for i in [[659, 0.09], [784, 0.18], [1046, 0.27]]: lv = _mix(lv, _tone(i[0], 0.4, 0.14, "tri", 0.4), int(i[1] * RATE))
	syn.level = _wav(lv)
	syn.good = _wav(_mix(_tone(880, 0.15, 0.06, "sine", 0.4), _tone(1320, 0.22, 0.08, "sine", 0.4), int(0.06 * RATE)))
	syn.bad = _wav(_tone(220, 0.25, 0.1, "sq", 0.35, 150))
	syn.tick = _wav(_noise(0.02, 0.004, 0.8, 0.5))
	syn.rtick = _wav(_mix(_noise(0.015, 0.003, 0.9, 0.5), _tone(2400, 0.02, 0.006, "sine", 0.2)))
	syn.buy = _wav(_mix(_mix(_noise(0.05, 0.01, 0.7, 0.4), _tone(1568, 0.25, 0.08, "tri", 0.35), int(0.03 * RATE)), _tone(2093, 0.3, 0.1, "tri", 0.3), int(0.09 * RATE)))
	var rr = _tone(784, 0.5, 0.18, "sine", 0.3)
	for i in [[988, 0.07], [1175, 0.14], [1568, 0.21], [1976, 0.28]]: rr = _mix(rr, _tone(i[0], 0.5, 0.18, "sine", 0.3), int(i[1] * RATE))
	syn.rare = _wav(rr)
	syn.whoosh = _wav(_noise(0.35, 0.12, 0.15, 0.35, 0.08))
	syn.socket = _wav(_mix(_noise(0.025, 0.005, 0.85, 0.6), _noise(0.015, 0.003, 0.95, 0.3), int(0.012 * RATE)))
	syn.cap = _wav(_mix(_noise(0.03, 0.008, 0.45, 0.6), _tone(900, 0.03, 0.01, "sine", 0.15)))
	syn.lube = _wav(_noise(0.2, 0.06, 0.08, 0.35, 0.02))
	syn.sizzle = _wav(_noise(0.15, 0.06, 0.95, 0.12, 0.01))
	syn.ratchet = _wav(_mix(_noise(0.012, 0.003, 0.9, 0.5), _tone(3200, 0.01, 0.003, "sine", 0.15)))
	syn.thud = _wav(_mix(_tone(110, 0.2, 0.06, "sine", 0.7), _noise(0.05, 0.015, 0.3, 0.4)))
	syn.open = _wav(_mix(_noise(0.4, 0.15, 0.2, 0.4, 0.05), _tone(392, 0.6, 0.25, "tri", 0.25, 784), int(0.1 * RATE)))
	syn.hover = _wav(_mix(_noise(0.008, 0.002, 0.95, 0.12), _tone(3800, 0.012, 0.004, "sine", 0.05)))
	syn.click = _wav(_mix(_noise(0.02, 0.004, 0.75, 0.4), _tone(1400, 0.03, 0.008, "sine", 0.18)))
	syn.spin = _wav(_mix(_noise(0.01, 0.002, 0.9, 0.35), _tone(2600, 0.015, 0.005, "tri", 0.2)))
	syn.reveal = _wav(_mix(_tone(523, 0.5, 0.2, "tri", 0.3, 1046), _noise(0.6, 0.25, 0.4, 0.2, 0.1), int(0.02 * RATE)))
	# room tone: brown noise loop, very quiet
	var n = RATE * 4; var rt = PackedFloat32Array(); rt.resize(n); var y = 0.0
	for i in n:
		y = clamp(y + (randf() * 2.0 - 1.0) * 0.02, -1.0, 1.0); rt[i] = y * 0.5
	for i in 2000:
		var k = float(i) / 2000.0; rt[i] *= k; rt[n - 1 - i] = lerp(rt[n - 1 - i], rt[i], 1.0 - k)
	syn.room = _wav(rt, true)
