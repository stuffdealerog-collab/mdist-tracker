# Builds the game's sound library from real CC0 recordings (freesound) + the kbsim (MIT) sets.
# Output: game/assets/snd2/<set>/{press_g_XX, release_g_XX, press_big_XX, release_big_XX, hollow_XX}.ogg
#         game/assets/snd2/_layers/{ping,rattle,scratch,ring}_XX.ogg, game/assets/snd2/_fx/*.ogg
import os, glob, json, subprocess
import numpy as np, scipy.signal as ss
from snd import load, SR, env, onsets, centroid, fade, trim_tail, norm, save_ogg

GAME = "/home/user/mdist-tracker/game"
OUT = GAME + "/assets/snd2"
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)
report = {}

def hp(x, f=70, order=2):
    b, a = ss.butter(order, f / (SR / 2), "high"); return ss.lfilter(b, a, x)
def lp(x, f=8000, order=2):
    b, a = ss.butter(order, f / (SR / 2), "low"); return ss.lfilter(b, a, x)
def bp(x, lo, hi, order=2):
    b, a = ss.butter(order, [lo / (SR / 2), hi / (SR / 2)], "band"); return ss.lfilter(b, a, x)
def rms(x): return float(np.sqrt(np.mean(x ** 2)) + 1e-12)

def denoise(seg, noise_mag, k=1.6):
    # simple spectral gate with a stationary noise profile
    f, t, Z = ss.stft(seg, SR, nperseg=512, noverlap=384)
    mag = np.abs(Z); ph = np.angle(Z)
    gate = np.maximum(mag - k * noise_mag[:, None], 0.12 * mag)
    _, y = ss.istft(gate * np.exp(1j * ph), SR, nperseg=512, noverlap=384)
    return y[: len(seg)]

def noise_profile(x):
    # quietest 0.25 s window
    w = int(0.25 * SR); best = None; bi = 0
    for i in range(0, max(1, len(x) - w), w // 2):
        r = rms(x[i:i + w])
        if best is None or r < best: best, bi = r, i
    f, t, Z = ss.stft(x[bi:bi + w], SR, nperseg=512, noverlap=384)
    return np.median(np.abs(Z), axis=1)

def resample(x, factor):
    # factor > 1 = higher pitch / shorter
    n = int(len(x) / factor)
    return ss.resample(x, n)

# ------------------------------------------------------------------ real typing recordings -> sets
def extract_pairs(name, hp_f=80, den=True, min_gap=0.11):
    x = hp(load(name), hp_f)
    nm = noise_profile(x) if den else None
    on = onsets(x, 0.03, 6.0)
    pk = [float(np.abs(x[i:i + int(0.02 * SR)]).max()) for i in on]
    pairs = []
    used = set()
    for j in range(len(on) - 1):
        if j in used or j + 1 in used: continue
        d = (on[j + 1] - on[j]) / SR
        prev_gap = (on[j] - on[j - 1]) / SR if j > 0 else 1.0
        nxt_gap = (on[j + 2] - on[j + 1]) / SR if j + 2 < len(on) else 1.0
        if 0.045 < d < 0.2 and prev_gap > 0.08 and nxt_gap > 0.08 and pk[j] >= pk[j + 1] * 0.9:
            pairs.append((on[j], on[j + 1])); used |= {j, j + 1}
    singles = [on[j] for j in range(len(on)) if j not in used and (j == 0 or (on[j] - on[j - 1]) / SR > min_gap) and (j + 1 >= len(on) or (on[j + 1] - on[j]) / SR > min_gap)]
    def cut(i, dur):
        a = int(i - 0.003 * SR); b = int(i + dur * SR)
        if a < 0 or b > len(x): return None
        s = x[a:b].copy()
        if den: s = denoise(s, nm)
        return fade(trim_tail(s, -50), 0.0015, 0.02)
    presses, releases = [], []
    for p, r in pairs:
        dp = min(0.15, (r - p) / SR - 0.008)
        if dp < 0.045: continue
        a = cut(p, dp); b = cut(r, 0.09)
        if a is not None and b is not None and single(a) and single(b): presses.append(a); releases.append(b)
    return x, presses, releases, [cut(i, 0.2) for i in singles if cut(i, 0.2) is not None]

def single(seg, after=0.022, ratio=0.17):
    # reject windows that contain a second keystroke
    e = np.abs(seg); i0 = int(after * SR)
    if len(e) <= i0: return True
    return e[i0:].max() < ratio * e[:i0].max()

def pick(segs, n, key=lambda s: rms(s)):
    if not segs: return []
    segs = [s for s in segs if np.abs(s).max() < 0.99]
    vals = np.array([key(s) for s in segs])
    med = np.median(vals); mad = np.median(np.abs(vals - med)) + 1e-9
    ok = [s for s, v in zip(segs, vals) if abs(v - med) < 2.5 * mad]
    rng.shuffle(ok)
    return ok[:n]

def level(segs, target=0.11):
    return [np.clip(s * (target / rms(s[: int(0.04 * SR)])), -0.97, 0.97) for s in segs]

REAL = {
    "mxblue_r": ["kb_mxblue_simeon", "kb_mxblue_james"],
    "topre_r": ["kb_topre_hhkb"],
    "whitefox_r": ["kb_whitefox"],
    "mxbrown_r": ["kb_mxbrown_seth", "kb_mxbrown_nick", "kb_mxbrown_majod"],

}
sets_out = {}
for setname, srcs in REAL.items():
    P, R, S = [], [], []
    for src in srcs:
        try:
            _, p, r, s = extract_pairs(src, den=src not in ("kb_mxblue_simeon",))
            P += p; R += r; S += s
        except Exception as e:
            print("skip", src, e)
    press = level(pick(P, 12)); rel = level(pick(R, 8), 0.06)
    # big keys: lowest spectral centroid singles/presses with longer body
    cand = [s for s in (P + S) if len(s) > int(0.06 * SR)]
    cand.sort(key=lambda s: centroid(s[: int(0.03 * SR)]))
    big = level(cand[:4], 0.13)
    sets_out[setname] = {"press": press, "release": rel, "big": big, "big_rel": rel[:2]}
    report[setname] = {"pairs": len(P), "press": len(press), "release": len(rel), "big": len(big)}

# ------------------------------------------------------------------ kbsim (MIT) sets -> same structure
def load_mp3(path):
    tmp = "/tmp/_kb.wav"
    subprocess.run(["ffmpeg", "-nostdin", "-loglevel", "error", "-y", "-i", path, "-ac", "1", "-ar", str(SR), tmp])
    import soundfile as sf
    x, _ = sf.read(tmp, dtype="float32"); return x
for d in sorted(glob.glob(GAME + "/tools/kbsim/snd/*")):
    name = os.path.basename(d)
    pr = [load_mp3(d + "/press/GENERIC_R%d.mp3" % i) for i in range(5) if os.path.exists(d + "/press/GENERIC_R%d.mp3" % i)]
    big = [load_mp3(d + "/press/%s.mp3" % k) for k in ("SPACE", "ENTER", "BACKSPACE") if os.path.exists(d + "/press/%s.mp3" % k)]
    rel = [load_mp3(d + "/release/%s.mp3" % k) for k in ("GENERIC",) if os.path.exists(d + "/release/%s.mp3" % k)]
    brel = [load_mp3(d + "/release/%s.mp3" % k) for k in ("SPACE", "ENTER", "BACKSPACE") if os.path.exists(d + "/release/%s.mp3" % k)]
    sets_out[name] = {"press": [fade(trim_tail(s, -55)) for s in pr], "release": [fade(trim_tail(s, -55)) for s in rel],
                      "big": [fade(trim_tail(s, -55)) for s in big], "big_rel": [fade(trim_tail(s, -55)) for s in brel]}
    report[name] = {k: len(v) for k, v in sets_out[name].items()}

# ------------------------------------------------------------------ case hollowness IR from real bucket knocks
def knock_irs():
    irs = []
    for n in ("hol_bucket_c", "hol_bucket_d", "hol_bucket_b", "hol_bucket_a"):
        x = load(n)
        for i in onsets(x, 0.05, 5.0):
            seg = x[i: i + int(0.12 * SR)]
            if len(seg) < int(0.08 * SR): continue
            irs.append(seg)
    return irs
IRS = knock_irs()
def make_ir(k):
    base = IRS[k % len(IRS)]
    ir = resample(base, 2.3)                # smaller cavity -> modes move up into the 250-700 Hz range
    ir = ir[int(0.002 * SR):]               # drop the stick transient, keep the body ring
    ir = lp(ir, 1800) * np.exp(-np.arange(len(ir)) / (0.035 * SR))
    return ir / (np.sqrt(np.sum(ir ** 2)) + 1e-9)
IR_BANK = [make_ir(k) for k in range(6)]

def hollow_layer(press, k):
    wet = ss.fftconvolve(press, IR_BANK[k % len(IR_BANK)])[: int(0.24 * SR)]
    wet = hp(wet, 120)
    wet = fade(wet, 0.001, 0.08)
    return np.clip(wet * (rms(press[: int(0.05 * SR)]) * 0.9 / (rms(wet[: int(0.08 * SR)]) + 1e-9)), -0.97, 0.97)

# ------------------------------------------------------------------ write sets
manifest = {}
for name, d in sets_out.items():
    od = OUT + "/" + name; os.makedirs(od, exist_ok=True)
    for f in glob.glob(od + "/*.ogg"): os.remove(f)
    m = {}
    for kind, key in (("press_g", "press"), ("release_g", "release"), ("press_big", "big"), ("release_big", "big_rel")):
        lst = d[key]
        for i, s in enumerate(lst): save_ogg("%s/%s_%02d.ogg" % (od, kind, i), norm(s, min(0.95, np.abs(s).max())))
        m[kind] = len(lst)
    for i, s in enumerate(d["press"]):
        save_ogg("%s/hollow_%02d.ogg" % (od, i), hollow_layer(s, i))
    m["hollow"] = len(d["press"])
    manifest[name] = m

# ------------------------------------------------------------------ global layers
LD = OUT + "/_layers"; os.makedirs(LD, exist_ok=True)
for f in glob.glob(LD + "/*.ogg"): os.remove(f)
# spring ping: real battery-compartment spring ring, transient removed
pings = []
for n in ("spr_batt2", "spr_batt1"):
    x = load(n); i = int(np.argmax(np.abs(x[: int(0.05 * SR)])))
    tail = hp(x[i + int(0.012 * SR): i + int(0.45 * SR)], 2500, 4)
    tail = fade(tail, 0.004, 0.15)
    for fct in (1.0, 1.12):
        pings.append(norm(resample(tail, fct), 0.6))
for i, s in enumerate(pings): save_ogg(LD + "/ping_%02d.ogg" % i, s)
# stabilizer rattle: real rattly spacebar hits (presses = loudest events)
rat = []
for n in ("sp_bt_cabled", "sp_zavadil", "sp_tap_green", "sp_mash"):
    x = hp(load(n), 90); on = onsets(x, 0.06, 6.0)
    ev = [(float(np.abs(x[i:i + int(0.02 * SR)]).max()), i) for i in on]
    ev.sort(reverse=True)
    for pk, i in ev[:4]:
        seg = x[max(0, i - int(0.003 * SR)): i + int(0.22 * SR)]
        if len(seg) > int(0.1 * SR) and pk < 0.99: rat.append(fade(trim_tail(seg, -50), 0.0015, 0.04))
rat = level(rat[:10], 0.12)
for i, s in enumerate(rat): save_ogg(LD + "/rattle_%02d.ogg" % i, s)
# switch scratch: real bristle friction (brush) -> plastic-on-plastic grit
x = hp(load("fx_brush"), 1500, 3); e = env(x, 20.0)
scr = []
for i in np.argsort(e)[::-1]:
    if len(scr) >= 6: break
    if any(abs(i - j) < int(0.3 * SR) for j in [k for k, _ in scr]): continue
    seg = x[max(0, i - int(0.03 * SR)): i + int(0.03 * SR)]
    if len(seg) == int(0.06 * SR): scr.append((i, norm(fade(seg, 0.012, 0.03), 0.5)))
scr = [s for _, s in scr]
for i, s in enumerate(scr[:6]): save_ogg(LD + "/scratch_%02d.ogg" % i, s)
# metal case ring (aluminium / brass weights): tiny metal ping, body only
for i, n in enumerate(("ping_tiny", "spr_flick")):
    x = load(n); a = int(np.argmax(np.abs(x)))
    s = hp(x[a + int(0.004 * SR): a + int(0.35 * SR)], 900, 3)
    save_ogg(LD + "/ring_%02d.ogg" % i, norm(fade(s, 0.003, 0.12), 0.5))
manifest["_layers"] = {"ping": len(pings), "rattle": len(rat), "scratch": min(6, len(scr)), "ring": 2}

# ------------------------------------------------------------------ foley / UI
FD = OUT + "/_fx"; os.makedirs(FD, exist_ok=True)
for f in glob.glob(FD + "/*.ogg"): os.remove(f)
def first_event(n, dur, k=0, hp_f=60, gain=0.8, thr=5.0, start=0.0, fo=0.03):
    x = hp(load(n), hp_f); x = x[int(start * SR):]
    on = onsets(x, 0.05, thr)
    if len(on) == 0: on = [int(np.argmax(np.abs(x)))]
    i = on[min(k, len(on) - 1)]
    seg = x[max(0, i - int(0.002 * SR)): i + int(dur * SR)]
    return norm(fade(trim_tail(seg, -55), 0.001, fo), gain)
def whole(n, a=0.0, b=None, hp_f=40, gain=0.8, fo=0.05):
    x = hp(load(n), hp_f); seg = x[int(a * SR): int(b * SR) if b else len(x)]
    return norm(fade(seg, 0.003, fo), gain)
FX = {
    "socket": lambda: first_event("fx_clipin", 0.12, gain=0.75),
    "cap": lambda: first_event("fx_pmouse", 0.1, gain=0.6),
    "pull": lambda: first_event("fx_zip", 0.12, k=2, gain=0.6),
    "ratchet": lambda: first_event("fx_zip", 0.05, k=5, hp_f=900, gain=0.45),
    "thud": lambda: lp(first_event("hol_bucket_b", 0.18, gain=0.8), 1400),
    "sizzle": lambda: whole("fx_sizzle_s", 0.05, 0.75, hp_f=900, gain=0.5),
    "lube": lambda: first_event("fx_brush1", 0.3, hp_f=400, gain=0.5, thr=3.0, fo=0.1),
    "coin": lambda: first_event("fx_coin010", 0.35, gain=0.6, fo=0.1),
    "coins": lambda: whole("fx_coins2", gain=0.6),
    "sale": lambda: whole("fx_register", gain=0.7),
    "buy": lambda: whole("fx_drawer_receipt", 0.0, 1.6, gain=0.6),
    "box_open": lambda: whole("fx_box_open", 0.0, 2.2, gain=0.7, fo=0.3),
    "tape": lambda: whole("fx_tape", gain=0.6),
    "whoosh": lambda: whole("fx_whoosh_little", gain=0.45, fo=0.2),
    "click": lambda: first_event("fx_flash_btn", 0.08, gain=0.45),
    "hover": lambda: norm(hp(first_event("fx_click1", 0.04, gain=0.3), 2500), 0.18),
    "open": lambda: first_event("fx_lamp", 0.15, gain=0.45),
    "good": lambda: lp(whole("fx_bell", 0.0, 0.9, gain=0.35, fo=0.4), 6000),
    "level": lambda: whole("fx_bell", gain=0.55, fo=0.6),
    "bad": lambda: lp(first_event("hol_bucket_a", 0.15, gain=0.7), 900),
    "tick": lambda: first_event("fx_click2", 0.04, gain=0.4),
    "rtick": lambda: first_event("fx_click1", 0.04, gain=0.35),
    "spin": lambda: norm(hp(first_event("fx_click2", 0.03, gain=0.4), 1200), 0.35),
    "drawer": lambda: whole("fx_drawer", gain=0.5),
}
for k, f in FX.items():
    try:
        save_ogg(FD + "/%s.ogg" % k, np.asarray(f(), dtype=np.float32))
    except Exception as e:
        print("fx fail", k, e)
# rare = bell + coins
b = whole("fx_bell", gain=0.5, fo=0.6); c = whole("fx_coins2", gain=0.5)
mix = np.zeros(max(len(b), len(c) + int(0.12 * SR))); mix[: len(b)] += b; mix[int(0.12 * SR): int(0.12 * SR) + len(c)] += c * 0.8
save_ogg(FD + "/rare.ogg", norm(mix, 0.7))
manifest["_fx"] = sorted([os.path.basename(f)[:-4] for f in glob.glob(FD + "/*.ogg")])
json.dump(manifest, open(OUT + "/manifest.json", "w"), indent=1)
print(json.dumps(report, indent=0))
print("fx:", manifest["_fx"])
print("layers:", manifest["_layers"])
