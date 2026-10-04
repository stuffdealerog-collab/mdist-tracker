# Bakes the game's material textures (albedo + normal) to game/assets/tex.
import numpy as np, os
from PIL import Image
OUT = "/home/user/mdist-tracker/game/assets/tex"
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(3)

def vnoise(h, w, cell, seed=0, oct=4, pers=0.5):
    r = np.random.default_rng(seed); out = np.zeros((h, w)); amp = 1.0; tot = 0
    for o in range(oct):
        c = max(1, int(cell / (2 ** o)))
        gh, gw = h // c + 2, w // c + 2
        g = r.random((gh, gw))
        yy = np.arange(h) / c; xx = np.arange(w) / c
        y0 = yy.astype(int); x0 = xx.astype(int); fy = yy - y0; fx = xx - x0
        fy = fy * fy * (3 - 2 * fy); fx = fx * fx * (3 - 2 * fx)
        a = g[y0][:, x0]; b = g[y0][:, x0 + 1]; c2 = g[y0 + 1][:, x0]; d = g[y0 + 1][:, x0 + 1]
        v = (a * (1 - fx) + b * fx) * (1 - fy)[:, None] + (c2 * (1 - fx) + d * fx) * fy[:, None]
        out += v * amp; tot += amp; amp *= pers
    return out / tot

def tileable(img):
    # blend edges for seamless tiling
    h, w = img.shape[:2]; m = 32
    out = img.copy()
    for i in range(m):
        t = i / m
        out[:, i] = img[:, i] * t + img[:, w - m + i] * (1 - t)
        out[i, :] = out[i, :] * t + out[h - m + i, :] * (1 - t)
    return out

def normal_from_height(hgt, strength=2.0):
    gy, gx = np.gradient(hgt)
    nx = -gx * strength; ny = -gy * strength; nz = np.ones_like(hgt)
    l = np.sqrt(nx ** 2 + ny ** 2 + nz ** 2)
    n = np.stack([nx / l, ny / l, nz / l], -1)
    return ((n * 0.5 + 0.5) * 255).astype(np.uint8)

def save(name, rgb, hgt=None, strength=2.0):
    Image.fromarray(np.clip(rgb * 255, 0, 255).astype(np.uint8)).save(f"{OUT}/{name}.png")
    if hgt is not None: Image.fromarray(normal_from_height(hgt, strength)).save(f"{OUT}/{name}_n.png")

def hexc(s): s = s.lstrip("#"); return np.array([int(s[i:i + 2], 16) / 255 for i in (0, 2, 4)])

def streaks(h, w, seed, stretch=24, cell=3):
    small = vnoise(h, max(4, w // stretch), cell, seed, 3)
    return np.array(Image.fromarray((small * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)) / 255.0

def wood_arr(light, base, dark, w=1024, h=512, ring_f=0.028, seed=1, arch=0.11):
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    warp = vnoise(h, w, 160, seed, 3) - 0.5
    var = vnoise(h, w, 300, seed + 3, 2) - 0.5
    cx = w * (0.3 + 0.4 * np.random.default_rng(seed).random())
    d = np.sqrt((yy - h * 0.55 + warp * 34) ** 2 + ((xx - cx) * arch) ** 2)
    ring = np.mod(d * ring_f * (1.0 + var * 0.5) + warp * 0.45, 1.0)
    late = np.clip((ring - 0.78) / 0.1, 0, 1) * np.clip((1.0 - ring) / 0.12, 0, 1)
    early = np.clip(ring / 0.75, 0, 1) ** 1.3
    L, B, D = hexc(light), hexc(base), hexc(dark)
    col = L[None, None] * (1 - early[..., None]) + B[None, None] * early[..., None]
    col = col * (1 - late[..., None] * 0.45) + D[None, None] * late[..., None] * 0.45
    fib = streaks(h, w, seed + 7)
    col *= (0.88 + fib[..., None] * 0.2)
    tone = vnoise(h, w, 260, seed + 9, 2)
    col *= (0.92 + tone[..., None] * 0.14)
    pores = np.zeros((h, w)); r = np.random.default_rng(seed + 1)
    n = int(w * h * 0.0025)
    py = r.integers(0, h, n); px = r.integers(0, w, n); ln = r.integers(5, 22, n)
    for y, x, l in zip(py, px, ln): pores[y, x:x + l] = r.uniform(0.3, 0.9)
    col = col * (1 - pores[..., None] * 0.28)
    hgt = 0.6 - late * 0.2 - pores * 0.2 + (fib - 0.5) * 0.12
    return col, hgt

def wood(name, light, base, dark, **kw):
    col, hgt = wood_arr(light, base, dark, **kw)
    save(name, tileable(col), tileable(hgt), 2.5)

wood("wood_walnut", "#7a5233", "#5c3b22", "#2e1b0e", seed=1)
wood("wood_oak", "#c9a26b", "#a77d4a", "#6e4c26", seed=2, ring_f=0.034)
wood("wood_zebrano", "#c7a46a", "#9b7a46", "#3d2a14", seed=3, ring_f=0.06, arch=0.02)
wood("wood_desk", "#9a6a40", "#7a5232", "#3e2614", seed=4)
wood("wood_light", "#d8b889", "#c39b6a", "#8a6440", seed=5)

def concrete(name, base, seed):
    h = w = 512
    n1 = vnoise(h, w, 128, seed, 5); n2 = vnoise(h, w, 8, seed + 1, 2)
    pits = (rng.random((h, w)) < 0.004).astype(float)
    B = hexc(base)
    col = B[None, None] * (0.8 + n1[..., None] * 0.28 + n2[..., None] * 0.06) * (1 - pits[..., None] * 0.35)
    save(name, tileable(col), tileable(n2 * 0.6 - pits * 0.5), 1.5)
concrete("concrete_wall", "#7d7b77", 11); concrete("concrete_floor", "#5f5e5b", 12)

def brick():
    h = w = 512; bh, bw = 32, 96
    yy, xx = np.mgrid[0:h, 0:w]
    row = yy // bh; off = np.where(row % 2 == 1, bw // 2, 0); bx = (xx + off) % w
    mortar = ((yy % bh) < 3) | ((bx % bw) < 3)
    idx = (row * 7 + (xx + off) // bw) % 200
    tints = np.array([hexc("#8a4532") * (1 - t) + hexc("#a65a3e") * t for t in rng.random(200)]) * (1 - rng.random((200, 1)) * 0.25)
    n = vnoise(h, w, 16, 21, 3)
    col = np.where(mortar[..., None], hexc("#b9b1a3")[None, None] * (0.8 + n[..., None] * 0.2), tints[idx] * (0.85 + n[..., None] * 0.3))
    hgt = np.where(mortar, 0.1, 0.6 + n * 0.4)
    save("brick", col, hgt, 4.0)
brick()

def planks(name, light, base, dark, seed):
    h = w = 512; pw = 64
    col = np.zeros((h, w, 3)); hgt = np.zeros((h, w))
    r = np.random.default_rng(seed)
    for p in range(w // pw):
        c, g = wood_arr(light, base, dark, w=384, h=pw * 2, ring_f=0.05, seed=seed * 10 + p)
        c = np.transpose(c, (1, 0, 2)); g = g.T          # grain runs along the plank (vertical)
        off = r.integers(0, 384 - 1)
        cc = np.roll(c, off, 0)[:h, :pw]; gg = np.roll(g, off, 0)[:h, :pw]
        if cc.shape[0] < h: cc = np.concatenate([cc, cc], 0)[:h]; gg = np.concatenate([gg, gg], 0)[:h]
        cc *= 0.85 + r.random() * 0.3
        col[:, p * pw:(p + 1) * pw] = cc; hgt[:, p * pw:(p + 1) * pw] = gg
        joint = r.integers(0, h)
        col[joint:joint + 2, p * pw:(p + 1) * pw] *= 0.45; hgt[joint:joint + 2, p * pw:(p + 1) * pw] = 0.1
    col[:, ::pw] *= 0.45; col[:, 1::pw] *= 0.6; hgt[:, ::pw] = 0.1
    save(name, col, hgt, 2.0)
planks("planks_dark", "#8a6040", "#6e4b2f", "#3a2516", 31); planks("planks_light", "#c9a477", "#b08a62", "#7a5a3a", 32); planks("planks_boutique", "#4e3220", "#3a2416", "#1c110a", 33)

def fabric():
    h = w = 256
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    weave = (np.sin(xx * 1.6) * 0.5 + 0.5) * (np.sin(yy * 1.6 + 1.0) * 0.5 + 0.5)
    k = 0.86 + weave * 0.1 + rng.random((h, w)) * 0.06
    save("fabric", np.repeat(k[..., None], 3, -1), weave, 1.2)
fabric()

def bead():
    h = w = 256
    hgt = rng.random((h, w)) * 0.5 + vnoise(h, w, 4, 41, 2) * 0.5
    Image.fromarray(normal_from_height(hgt, 0.8)).save(f"{OUT}/bead_n.png")
    r = vnoise(h, w, 32, 42, 3)
    Image.fromarray((np.clip(0.7 + (r - 0.5) * 0.6, 0, 1) * 255).astype(np.uint8)).save(f"{OUT}/rough_var.png")
bead()

def plastic_tex():
    h = w = 256
    hgt = vnoise(h, w, 3, 51, 2)
    Image.fromarray(normal_from_height(hgt, 0.6)).save(f"{OUT}/plastic_n.png")
plastic_tex()
print(sorted(os.listdir(OUT)))
