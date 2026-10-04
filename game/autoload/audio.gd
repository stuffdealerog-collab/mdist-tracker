extends Node
## Switch sounds: real recordings (kbsim, MIT) shaped per build on a dedicated bus,
## plus synthesized layers (spring ping, stab rattle, case hollowness) and UI sounds.

const RATE := 44100
const NAMES_PRESS := ["GENERIC_R0","GENERIC_R1","GENERIC_R2","GENERIC_R3","GENERIC_R4","SPACE","ENTER","BACKSPACE"]
const NAMES_REL := ["GENERIC","SPACE","ENTER","BACKSPACE"]

var sets = {}                 # set -> {press:{name:stream}, release:{...}}
var key_players: Array[AudioStreamPlayer] = []
var ui_players: Array[AudioStreamPlayer] = []
var _kp = 0
var _up = 0
var keys_bus = -1
var eq: AudioEffectEQ6
var syn = {}                  # synthesized streams
var ambient: AudioStreamPlayer
var current_P = {}

func _ready() -> void:
	_setup_buses()
	for i in 28:
		var p = AudioStreamPlayer.new(); p.bus = "Keys"; add_child(p); key_players.append(p)
	for i in 10:
		var p = AudioStreamPlayer.new(); p.bus = "UI"; add_child(p); ui_players.append(p)
	_make_synth()
	ambient = AudioStreamPlayer.new(); ambient.bus = "Ambient"; ambient.stream = syn.room; ambient.volume_db = -26; add_child(ambient)
	ambient.play()

func _setup_buses() -> void:
	for n in ["Keys", "UI", "Ambient"]:
		if AudioServer.get_bus_index(n) == -1:
			AudioServer.add_bus(); var i = AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, n); AudioServer.set_bus_send(i, "Master")
	keys_bus = AudioServer.get_bus_index("Keys")
	eq = AudioEffectEQ6.new()
	AudioServer.add_bus_effect(keys_bus, eq)
	var rev = AudioEffectReverb.new(); rev.room_size = 0.18; rev.damping = 0.6; rev.wet = 0.10; rev.dry = 1.0; rev.spread = 0.6
	AudioServer.add_bus_effect(keys_bus, rev)
	var lim = AudioEffectLimiter.new(); lim.ceiling_db = -0.5; lim.threshold_db = -6
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Master"), lim)

func apply_settings() -> void:
	if Game.S.is_empty(): return
	var st: Dictionary = Game.S.settings
	AudioServer.set_bus_mute(0, not st.sound)
	AudioServer.set_bus_volume_db(0, linear_to_db(max(0.0001, float(st.vol))))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Ambient"), linear_to_db(max(0.0001, float(st.get("music", 0.4)))))

func load_set(s: String) -> Dictionary:
	if s == "" : return {}
	if sets.has(s): return sets[s]
	var out = {"press": {}, "release": {}}
	for n in NAMES_PRESS:
		var path = "res://assets/snd/%s/press/%s.mp3" % [s, n]
		if ResourceLoader.exists(path): out.press[n] = load(path)
	for n in NAMES_REL:
		var path = "res://assets/snd/%s/release/%s.mp3" % [s, n]
		if ResourceLoader.exists(path): out.release[n] = load(path)
	sets[s] = out
	return out

## Shape the Keys bus to the current build (called when a keyboard becomes active).
func set_profile(P: Dictionary) -> void:
	current_P = P
	if P.is_empty(): return
	var sh = float(P.shift)
	var hollow = float(P.hollow)
	# bands: 32, 100, 320, 1000, 3200, 10000 Hz
	eq.set_band_gain_db(0, clamp(-sh * 5.0, -6, 6))
	eq.set_band_gain_db(1, clamp(-sh * 9.0, -9, 10))
	eq.set_band_gain_db(2, clamp((hollow - 0.15) * 14.0 - sh * 3.0, -6, 10))
	eq.set_band_gain_db(3, 0.0)
	eq.set_band_gain_db(4, clamp(sh * 8.0 - (14.0 if P.silent else 0.0), -18, 9))
	eq.set_band_gain_db(5, clamp(sh * 6.0 - (16.0 if P.silent else 0.0), -20, 8))

func _player() -> AudioStreamPlayer:
	_kp = (_kp + 1) % key_players.size(); return key_players[_kp]

## k: layout key dictionary {w,row,codes}; fgap: layout has an F-row
func key(P: Dictionary, k: Dictionary, up: bool, fgap := false) -> void:
	if Game.S.is_empty() or not Game.S.settings.sound: return
	if P != current_P: set_profile(P)
	var s = load_set(P.get("snd", ""))
	var w = float(k.get("w", 1.0)); var code: String = k.get("codes", [""])[0]
	var row: int = clamp(int(k.get("row", 2)) - (1 if fgap else 0), 0, 4)
	var nm: String
	if code == "Space" or w >= 5: nm = "SPACE"
	elif code == "Enter" or code == "NumpadEnter": nm = "ENTER"
	elif code == "Backspace": nm = "BACKSPACE"
	elif up: nm = "GENERIC"
	else: nm = "GENERIC_R%d" % row
	var bank: Dictionary = s.get("release" if up else "press", {})
	var stream = bank.get(nm, bank.get("GENERIC" if up else "GENERIC_R%d" % row, bank.get("GENERIC_R2", null)))
	var L = 0.3 + float(P.loud) * 0.7
	if stream:
		var p = _player(); p.stream = stream
		p.pitch_scale = clamp(pow(2.0, float(P.shift) * 0.5), 0.78, 1.28) * (1.0 + (randf() - 0.5) * 0.035)
		p.volume_db = linear_to_db((0.35 + float(P.loud) * 0.9) * (0.4 if P.silent else 1.0) * (0.9 if up else 1.0) * randf_range(0.92, 1.08))
		p.play()
	var xping: float = max(0.0, float(P.ping) - 0.12)
	if xping > 0.03: _layer(syn.ping, 0.06 * xping * L, randf_range(0.95, 1.12))
	if not up and float(P.hollow) > 0.3: _layer(syn.hollow, 0.35 * (float(P.hollow) - 0.25) * L, 1.0 + float(P.pitch) * 0.15)
	if w >= 1.75 and float(P.rattle) > 0.3: _layer(syn.rattle, 0.5 * (float(P.rattle) - 0.2) * L, randf_range(0.9, 1.1))

func _layer(stream: AudioStream, gain: float, pitch := 1.0) -> void:
	if gain <= 0.0005: return
	var p = _player(); p.stream = stream; p.pitch_scale = pitch; p.volume_db = linear_to_db(gain); p.play()

func ui(name: String) -> void:
	if Game.S.is_empty() or not Game.S.settings.sound: return
	if not syn.has(name): return
	_up = (_up + 1) % ui_players.size()
	var p = ui_players[_up]; p.stream = syn[name]; p.pitch_scale = 1.0; p.volume_db = {"tick": -10.0, "hover": -22.0, "click": -12.0, "spin": -10.0}.get(name, -6.0)
	if name == "rtick": p.pitch_scale = randf_range(0.95, 1.08); p.volume_db = -12.0
	p.play()

func socket(cap: bool) -> void:
	ui("cap" if cap else "socket")

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
