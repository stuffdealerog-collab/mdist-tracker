import numpy as np, soundfile as sf, scipy.signal as ss
SR = 44100
def load(n):
    x, sr = sf.read('wav/%s.wav' % n, dtype='float32')
    if x.ndim > 1: x = x.mean(1)
    return x
def env(x, ms=2.0):
    w = max(1, int(SR * ms / 1000))
    return np.convolve(np.abs(x), np.ones(w) / w, mode='same')
def onsets(x, min_gap=0.035, k=6.0, floor_db=-50):
    e = env(x, 1.0)
    # rising energy detector
    d = np.maximum(0, np.diff(e, prepend=e[0]))
    med = ss.medfilt(e, 4411) + 10 ** (floor_db / 20)
    cand = np.where((e > med * k) & (d > 0))[0]
    out = []; last = -10**9
    for i in cand:
        if i - last > min_gap * SR:
            out.append(i); last = i
        else:
            last = i if False else last
    return np.array(out)
def centroid(seg):
    f, P = ss.periodogram(seg, SR)
    return float((f * P).sum() / (P.sum() + 1e-12))
def events(x, pre=0.004, post=0.14, min_gap=0.035, k=6.0):
    on = onsets(x, min_gap, k)
    evs = []
    for j, i in enumerate(on):
        a = int(i - pre * SR); b = int(i + post * SR)
        if a < 0 or b > len(x): continue
        nxt = on[j + 1] if j + 1 < len(on) else 10**12
        clean_len = (nxt - i) / SR
        seg = x[a:b].copy()
        pk = float(np.abs(seg).max())
        evs.append({'i': int(i), 'seg': seg, 'peak': pk, 'cent': centroid(seg[: int(0.03 * SR)]), 'gap': clean_len, 'clip': pk > 0.98})
    return evs
def fade(seg, fin=0.001, fout=0.03):
    n = len(seg); a = min(int(fin * SR), n // 4); b = min(int(fout * SR), n // 2)
    seg = seg.copy()
    if a > 0: seg[:a] *= np.linspace(0, 1, a)
    if b > 0: seg[-b:] *= np.linspace(1, 0, b) ** 2
    return seg
def trim_tail(seg, thr_db=-55):
    e = env(seg, 3.0); pk = e.max(); t = np.where(e > pk * 10 ** (thr_db / 20))[0]
    end = min(len(seg), (t[-1] if len(t) else len(seg)) + int(0.005 * SR))
    return seg[:end]
def norm(seg, peak=0.8):
    return seg * (peak / (np.abs(seg).max() + 1e-9))
def save_ogg(path, seg, q=6):
    import subprocess, tempfile, os
    tmp = path + '.tmp.wav'; sf.write(tmp, seg.astype('float32'), SR, subtype='PCM_16')
    subprocess.run(['ffmpeg', '-nostdin', '-loglevel', 'error', '-y', '-i', tmp, '-c:a', 'libvorbis', '-q:a', str(q), path]); os.remove(tmp)
