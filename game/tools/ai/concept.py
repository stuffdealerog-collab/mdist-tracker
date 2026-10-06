"""Product photo of a prop from a text prompt (FLUX.1 Kontext in the local ComfyUI).
Kontext edits an image, so it starts from a neutral studio backdrop canvas.
  python concept.py <out.png> "<prompt>" [seed] [canvas.png]
"""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
import comfy

out, prompt = sys.argv[1], sys.argv[2]
seed = int(sys.argv[3]) if len(sys.argv) > 3 else 1
canvas = sys.argv[4] if len(sys.argv) > 4 else os.path.join(os.path.dirname(__file__), "canvas.png")
name = comfy.upload_image(canvas)
g = {
	"1": {"class_type": "UNETLoader", "inputs": {"unet_name": "flux1-dev-kontext_fp8_scaled.safetensors", "weight_dtype": "default"}},
	"2": {"class_type": "DualCLIPLoader", "inputs": {"clip_name1": "clip_l.safetensors", "clip_name2": "t5xxl_fp8_e4m3fn_scaled.safetensors", "type": "flux"}},
	"3": {"class_type": "VAELoader", "inputs": {"vae_name": "ae.safetensors"}},
	"4": {"class_type": "LoadImage", "inputs": {"image": name}},
	"5": {"class_type": "FluxKontextImageScale", "inputs": {"image": ["4", 0]}},
	"6": {"class_type": "VAEEncode", "inputs": {"pixels": ["5", 0], "vae": ["3", 0]}},
	"7": {"class_type": "CLIPTextEncode", "inputs": {"text": prompt, "clip": ["2", 0]}},
	"8": {"class_type": "ReferenceLatent", "inputs": {"conditioning": ["7", 0], "latent": ["6", 0]}},
	"9": {"class_type": "FluxGuidance", "inputs": {"conditioning": ["8", 0], "guidance": 3.0}},
	"10": {"class_type": "ConditioningZeroOut", "inputs": {"conditioning": ["7", 0]}},
	"11": {"class_type": "KSampler", "inputs": {"model": ["1", 0], "seed": seed, "steps": 26, "cfg": 1.0, "sampler_name": "euler", "scheduler": "simple",
		"positive": ["9", 0], "negative": ["10", 0], "latent_image": ["6", 0], "denoise": 1.0}},
	"12": {"class_type": "VAEDecode", "inputs": {"samples": ["11", 0], "vae": ["3", 0]}},
	"13": {"class_type": "SaveImage", "inputs": {"images": ["12", 0], "filename_prefix": "kss_concept"}},
}
h = comfy.run(g)
f = comfy.outputs(h)[0]
p = comfy.fetch(f, os.path.dirname(os.path.abspath(out)))
os.replace(p, out)
print("CONCEPT", out, h["_seconds"], "s")
