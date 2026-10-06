# Room / unboxing / delivery foley from real CC0 recordings (freesound).
# Downloads previews to tools/raw_room/, cuts them into one-shots and loops,
# writes game/assets/snd2/_room/<name>_XX.ogg and _room/manifest.json.
#   python build_room_snd.py            (download + build)
import os, re, json, subprocess, sys
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw_room")
OUT = os.path.join(HERE, "..", "assets", "snd2", "_room")
SR = 44100
os.makedirs(RAW, exist_ok=True); os.makedirs(OUT, exist_ok=True)

# name: (freesound id, mode, options)
#   events  — cut separate hits by onset (n clips, max length)
#   whole   — the whole recording, silence trimmed
#   loudest — the loudest continuous window of `dur` seconds (textures)
#   loop    — a seamless loop of `dur` seconds (crossfaded)
SRC = {
	# packing tape
	"tape_rip":    [(466211, "whole", {}), (273450, "whole", {}), (618541, "windows", {"n": 2, "dur": 1.2})],
	"tape_pull":   [(332225, "whole", {}), (151446, "loudest", {"dur": 2.4})],
	"tape_seal":   [(739437, "events", {"n": 6, "max": 2.6, "min": 0.7})],
	"knife_cut":   [(795827, "events", {"n": 8, "max": 1.6, "min": 0.25})],
	# box
	"flaps":       [(452567, "windows", {"n": 3, "dur": 1.1}), (459428, "windows", {"n": 3, "dur": 1.1}), (459443, "windows", {"n": 2, "dur": 1.2})],
	"card_tear":   [(764891, "whole", {}), (364739, "whole", {}), (764893, "whole", {})],
	"box_down":    [(491094, "events", {"n": 6, "max": 1.0}), (452569, "events", {"n": 6, "max": 1.0})],
	# inner packaging
	"film_peel":   [(555695, "windows", {"n": 6, "dur": 2.4})],
	"bag":         [(389548, "windows", {"n": 3, "dur": 1.2}), (679998, "windows", {"n": 3, "dur": 1.2}), (142592, "whole", {})],
	"zip":         [(326466, "events", {"n": 3, "max": 1.2})],
	"esd_bag":     [(573824, "windows", {"n": 5, "dur": 1.3})],
	"plastic_pkg": [(434674, "windows", {"n": 5, "dur": 1.2})],
	"foam":        [(868249, "windows", {"n": 4, "dur": 0.9}), (774262, "whole", {})],
	"bubble":      [(214675, "events", {"n": 8, "max": 0.5}), (683100, "whole", {})],
	"tray":        [(444780, "windows", {"n": 3, "dur": 1.0}), (713350, "windows", {"n": 3, "dur": 1.0})],
	# house
	"doorbell":    [(123350, "whole", {})],
	"knock":       [(193873, "whole", {}), (621234, "whole", {})],
	"door":        [(237403, "windows", {"n": 2, "dur": 1.8})],
	"step":        [(426620, "events", {"n": 8, "max": 0.38}), (505832, "events", {"n": 8, "max": 0.38}), (543685, "events", {"n": 8, "max": 0.38})],
	"bed":         [(573730, "whole", {}), (644490, "whole", {})],
	"pc_hum":      [(211994, "loop", {"dur": 8.0})],
	"mouse":       [(687108, "events", {"n": 2, "max": 0.3}), (534104, "events", {"n": 2, "max": 0.3})],
	"phone_vib":   [(529979, "whole", {}), (677649, "windows", {"n": 1, "dur": 1.2})],
	"alarm":       [(709944, "loudest", {"dur": 3.0})],
	"label_print": [(546605, "whole", {})],
	"aquarium":    [(418198, "loop", {"dur": 10.0})],
}

def fetch(sid):
	out = os.path.join(RAW, "%d.mp3" % sid)
	if os.path.exists(out) and os.path.getsize(out) > 1000: return out, True
	h = subprocess.run(["curl", "-sSL", "-m", "25", "https://freesound.org/s/%d/" % sid], capture_output=True, text=True, encoding="utf-8", errors="replace").stdout
	cc0 = "Creative Commons 0" in h or "publicdomain/zero" in h
	m = re.search(r'https://cdn\.freesound\.org/previews/[0-9]+/%d_[0-9]+-hq\.mp3' % sid, h) or re.search(r'https://cdn\.freesound\.org/previews/[0-9]+/%d_[0-9]+-lq\.mp3' % sid, h)
	if not m or not cc0:
		print("SKIP", sid, "url" if not m else "license"); return None, False
	subprocess.run(["curl", "-sSL", "-m", "90", "-o", out, m.group(0).replace("-lq.mp3", "-hq.mp3")])
	t = re.search(r'<title>([^<]+)</title>', h)
	print("got %7d  %s" % (sid, (t.group(1) if t else "")[:70]))
	return out, True

def load(path):
	raw = subprocess.run(["ffmpeg", "-nostdin", "-loglevel", "error", "-i", path, "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"], capture_output=True).stdout
	x = np.frombuffer(raw, dtype=np.float32).astype(np.float64)
	# gentle high-pass against rumble: subtract a 10 ms moving average
	return x - np.convolve(x, np.ones(441) / 441.0, mode="same")

def env(x, hop=220):
	n = len(x) // hop
	return np.sqrt(np.mean(x[: n * hop].reshape(n, hop) ** 2, axis=1) + 1e-12), hop

def rms(x): return float(np.sqrt(np.mean(x ** 2)) + 1e-12)

def fade(x, fi=0.003, fo=0.03):
	x = x.copy(); a = int(fi * SR); b = int(fo * SR)
	if a > 0 and len(x) > a: x[:a] *= np.linspace(0, 1, a)
	if b > 0 and len(x) > b: x[-b:] *= np.linspace(1, 0, b) ** 2
	return x

def trim(x, rel=0.04):
	e, hop = env(x)
	thr = max(e.max() * rel, np.percentile(e, 20) * 2.5)
	idx = np.where(e > thr)[0]
	if len(idx) == 0: return x
	a = max(0, idx[0] * hop - int(0.01 * SR)); b = min(len(x), (idx[-1] + 1) * hop + int(0.06 * SR))
	return x[a:b]

def events(x, n, mx, mn=0.06):
	e, hop = env(x)
	floor = np.percentile(e, 25)
	thr = max(floor * 4.0, e.max() * 0.12)
	on = []; i = 0; L = len(e)
	while i < L:
		if e[i] > thr and (i == 0 or e[i - 1] <= thr):
			j = i
			while j < L and e[j] > floor * 2.2 and (j - i) * hop < mx * SR: j += 1
			if (j - i) * hop >= mn * SR:
				a = max(0, i * hop - int(0.012 * SR)); b = min(len(x), j * hop + int(0.04 * SR))
				on.append((rms(x[a:b]) * min(1.0, (b - a) / SR / 0.3), a, b))
			i = max(j, i + 1)
		else: i += 1
	on.sort(reverse=True)
	segs = [x[a:b] for _, a, b in on[:n]]
	return segs

def loudest(x, dur):
	w = int(dur * SR)
	if len(x) <= w: return [x]
	e, hop = env(x)
	k = max(1, w // hop)
	c = np.convolve(e, np.ones(k), mode="valid")
	i = int(np.argmax(c)) * hop
	return [x[i:i + w]]

def windows(x, n, dur, gap=0.15):
	# n loudest non-overlapping windows of `dur` seconds, each trimmed to its own content
	e, hop = env(x); k = max(1, int(dur * SR) // hop)
	c = np.convolve(e, np.ones(k), mode="valid").copy()
	out = []
	for _ in range(n):
		if c.size == 0 or c.max() <= 0: break
		i = int(np.argmax(c))
		if c[i] < c.max() * 0.0 + 1e-9: break
		a = i * hop; seg = x[a:a + int(dur * SR)]
		out.append((a, trim(seg, 0.06)))
		lo = max(0, i - k - int(gap * SR) // hop); hi = min(c.size, i + k + int(gap * SR) // hop)
		c[lo:hi] = 0
	out.sort()
	return [s for _, s in out]

def make_loop(x, dur):
	w = int(dur * SR); xf = int(0.5 * SR)
	seg = loudest(x, dur + 0.5)[0]
	if len(seg) < w + xf: return [seg]
	body = seg[:w].copy(); tail = seg[w:w + xf]
	ramp = np.linspace(0, 1, xf)
	body[:xf] = body[:xf] * ramp + tail * (1 - ramp)
	return [body]

def save(x, path, target=0.12):
	x = x / max(rms(x), 1e-6) * target
	pk = np.max(np.abs(x))
	if pk > 0.97: x *= 0.97 / pk
	pcm = (x.astype(np.float32)).tobytes()
	subprocess.run(["ffmpeg", "-nostdin", "-loglevel", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", "-", "-c:a", "libvorbis", "-q:a", "5", path], input=pcm)

TARGET = {"pc_hum": 0.05, "step": 0.1, "doorbell": 0.14, "knock": 0.14, "alarm": 0.1, "bubble": 0.1, "mouse": 0.09}

def main():
	man = {}; credits = []
	for name, srcs in SRC.items():
		for f in os.listdir(OUT):
			if f.startswith(name + "_") and f.endswith(".ogg"): os.remove(os.path.join(OUT, f))
		clips = []
		for sid, mode, o in srcs:
			p, ok = fetch(sid)
			if not ok: continue
			x = load(p)
			if mode == "events": got = events(x, o["n"], o["max"], o.get("min", 0.06))
			elif mode == "loudest": got = loudest(x, o["dur"])
			elif mode == "windows": got = windows(x, o["n"], o["dur"])
			elif mode == "loop": got = make_loop(x, o["dur"])
			else: got = [trim(x)]
			clips += [(g, mode) for g in got]
			credits.append((name, sid))
		k = 0
		for g, mode in clips:
			if len(g) < int(0.03 * SR): continue
			g = g if mode == "loop" else fade(g, 0.002, min(0.06, len(g) / SR * 0.2))
			save(g, os.path.join(OUT, "%s_%02d.ogg" % (name, k)), TARGET.get(name, 0.12)); k += 1
		man[name] = k
		print("%-12s %2d clips" % (name, k))
	json.dump(man, open(os.path.join(OUT, "manifest.json"), "w"), indent=1)
	with open(os.path.join(HERE, "room_credits.txt"), "w", encoding="utf-8") as f:
		for name, sid in credits: f.write("%s: https://freesound.org/s/%d/\n" % (name, sid))

if __name__ == "__main__":
	main()
