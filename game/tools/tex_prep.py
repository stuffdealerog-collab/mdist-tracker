"""Turns a generated / photographed texture into a game set: <out>_albedo.jpg, <out>_normal.png, <out>_rough.jpg.
  python tools/tex_prep.py <src> <out_prefix> [--size 2048] [--seam 0.08] [--normal 2.0] [--rough 0.85,0.08]
           [--sat 1.0] [--gain 1.0] [--hue 0]
--seam: width (fraction) of the wrap-around cross-fade that makes edges tile (0 = keep as is)
--normal: strength of the normal map derived from luminance detail (embossed paper, weave); 0 = none
--rough: base roughness, variation driven by luminance detail
--sat/--gain/--hue: colour calibration (albedo stays within sRGB 30..235, like a real surface)"""
import argparse, os
import numpy as np
from PIL import Image, ImageFilter

ap = argparse.ArgumentParser()
ap.add_argument("src"); ap.add_argument("out")
ap.add_argument("--size", type=int, default=2048); ap.add_argument("--seam", type=float, default=0.0)
ap.add_argument("--normal", type=float, default=2.0); ap.add_argument("--rough", default="0.85,0.08")
ap.add_argument("--sat", type=float, default=1.0); ap.add_argument("--gain", type=float, default=1.0); ap.add_argument("--hue", type=float, default=0.0)
a = ap.parse_args()

im = Image.open(a.src).convert("RGB")
w, h = im.size; s = min(w, h)
im = im.crop(((w - s) // 2, (h - s) // 2, (w - s) // 2 + s, (h - s) // 2 + s)).resize((a.size, a.size), Image.LANCZOS)
x = np.asarray(im).astype(np.float32) / 255.0

if a.seam > 0:   # blend each edge band with the opposite side (wrap-around) so the tile repeats without a seam
	n = a.size; b = max(2, int(n * a.seam))
	r = np.roll(np.roll(x, n // 2, 0), n // 2, 1)
	wv = np.ones(n, np.float32)
	ramp = np.linspace(0, 1, b, dtype=np.float32)
	wv[:b] = ramp; wv[-b:] = ramp[::-1]
	W = np.minimum.outer(wv, wv)[..., None]
	x = x * W + r * (1 - W)

# colour calibration in HSV-ish space
if a.hue or a.sat != 1.0 or a.gain != 1.0:
	img = Image.fromarray((np.clip(x, 0, 1) * 255).astype(np.uint8)).convert("HSV")
	hsv = np.asarray(img).astype(np.float32)
	hsv[..., 0] = (hsv[..., 0] + a.hue * 255.0 / 360.0) % 255.0
	hsv[..., 1] = np.clip(hsv[..., 1] * a.sat, 0, 255); hsv[..., 2] = np.clip(hsv[..., 2] * a.gain, 0, 255)
	x = np.asarray(Image.fromarray(hsv.astype(np.uint8), "HSV").convert("RGB")).astype(np.float32) / 255.0
x = 30 / 255 + x * (205 / 255)             # physically plausible albedo range
alb = Image.fromarray((np.clip(x, 0, 1) * 255).astype(np.uint8))
os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
alb.save(a.out + "_albedo.jpg", quality=93)

lum = x @ np.array([0.299, 0.587, 0.114], np.float32)
blur = np.asarray(Image.fromarray((lum * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(6))).astype(np.float32) / 255
detail = lum - blur                        # high-pass: print/emboss detail
if a.normal > 0:
	hgt = detail * a.normal
	dx = (np.roll(hgt, -1, 1) - np.roll(hgt, 1, 1)) * 0.5 * a.size / 256
	dy = (np.roll(hgt, -1, 0) - np.roll(hgt, 1, 0)) * 0.5 * a.size / 256
	nrm = np.dstack([-dx, dy, np.ones_like(dx)])        # OpenGL (Godot) convention
	nrm /= np.linalg.norm(nrm, axis=2, keepdims=True)
	Image.fromarray(((nrm * 0.5 + 0.5) * 255).astype(np.uint8)).save(a.out + "_normal.png")
r0, rv = [float(v) for v in a.rough.split(",")]
rough = np.clip(r0 - detail * rv * 4.0, 0.05, 1.0)
Image.fromarray((rough * 255).astype(np.uint8)).save(a.out + "_rough.jpg", quality=92)
print("tex", a.out, a.size)
