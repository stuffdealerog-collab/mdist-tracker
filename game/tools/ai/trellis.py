"""Image -> textured 3D model with Microsoft TRELLIS.2 (MIT) in the local ComfyUI.
Mirrors the official template (Comfy-Org workflow_templates/3d_pixal3d_trellis2_image_to_model), TRELLIS.2 branch:
background removal, structure -> shape (1536) -> PBR texture voxels, remesh, decimate, UV unwrap,
bake base colour / metallic / roughness from voxels + normal map and AO from the dense mesh.

  python trellis.py <image.png> <out.glb> [seed] [faces] [texture_size]
"""
import os, sys, json
sys.path.insert(0, os.path.dirname(__file__))
import comfy

img, out = sys.argv[1], sys.argv[2]
seed = int(sys.argv[3]) if len(sys.argv) > 3 else 42
faces = int(sys.argv[4]) if len(sys.argv) > 4 else 60000
tex = int(sys.argv[5]) if len(sys.argv) > 5 else 2048
prefix = "3d/kss_" + os.path.splitext(os.path.basename(out))[0]
RES = os.environ.get("TRELLIS_RES", "1536")        # 1024 when VRAM is tight
REMESH = int(os.environ.get("TRELLIS_REMESH", "768"))
# free VRAM left by other graphs (Flux etc.) before the heavy stages
try: comfy._req("/free", json.dumps({"unload_models": True, "free_memory": True}).encode(), {"Content-Type": "application/json"})
except Exception: pass
name = comfy.upload_image(img)

def ks(model, pos, lat, s, steps, cfg, sched="normal"):
	return {"class_type": "KSampler", "inputs": {"model": model, "positive": [pos, 0], "negative": [pos, 1], "latent_image": lat,
		"seed": s, "steps": steps, "cfg": cfg, "sampler_name": "euler", "scheduler": sched, "denoise": 1.0}}

g = {
	"img": {"class_type": "LoadImage", "inputs": {"image": name}},
	"bgm": {"class_type": "LoadBackgroundRemovalModel", "inputs": {"bg_removal_name": "birefnet.safetensors"}},
	"rb": {"class_type": "RemoveBackground", "inputs": {"bg_removal_model": ["bgm", 0], "image": ["img", 0]}},
	"crop": {"class_type": "ImageCropToMask", "inputs": {"images": ["img", 0], "masks": ["rb", 0], "width": 1024, "height": 1024,
		"pad_factor": 1.0, "grow_mask": 0, "background": "#000000"}},
	"cv": {"class_type": "CLIPVisionLoader", "inputs": {"clip_name": "dino_v3_L_naf_fp32.safetensors"}},
	"cond": {"class_type": "Trellis2Conditioning", "inputs": {"clip_vision_model": ["cv", 0], "image": ["crop", 0]}},
	"unet": {"class_type": "UNETLoader", "inputs": {"unet_name": "trellis_2_int8_convrot.safetensors", "weight_dtype": "default"}},
	"cfo1": {"class_type": "CFGOverride", "inputs": {"model": ["unet", 0], "cfg": 1.0, "start_percent": 0.667, "end_percent": 1.0}},
	"rs1": {"class_type": "RescaleCFG", "inputs": {"model": ["cfo1", 0], "multiplier": 0.7}},
	"msd": {"class_type": "ModelSamplingSD3", "inputs": {"model": ["rs1", 0], "shift": 5.0}},
	"empty": {"class_type": "EmptyTrellis2LatentStructure", "inputs": {"batch_size": 1}},
	"ks_struct": ks(["msd", 0], "cond", ["empty", 0], seed + 14, 12, 7.5),
	"svae": {"class_type": "VAELoader", "inputs": {"vae_name": "trellis_2_shape_vae_bf16.safetensors"}},
	"vstruct": {"class_type": "VaeDecodeStructureTrellis2", "inputs": {"samples": ["ks_struct", 0], "vae": ["svae", 0], "resolution": "32"}},
	"shape": {"class_type": "Trellis2ShapeStage", "inputs": {"positive": ["cond", 0], "negative": ["cond", 1], "voxel": ["vstruct", 0]}},
	"cfo2": {"class_type": "CFGOverride", "inputs": {"model": ["unet", 0], "cfg": 1.0, "start_percent": 0.769, "end_percent": 1.0}},
	"rs2": {"class_type": "RescaleCFG", "inputs": {"model": ["cfo2", 0], "multiplier": 0.5}},
	"ks_shape": ks(["rs2", 0], "shape", ["shape", 2], seed, 20, 7.5),
	"up": {"class_type": "Trellis2UpsampleStage", "inputs": {"positive": ["shape", 0], "negative": ["shape", 1], "shape_latent": ["ks_shape", 0],
		"vae": ["svae", 0], "target_resolution": RES}},
	"ks_up": ks(["rs2", 0], "up", ["up", 2], seed, 12, 7.5, "simple"),
	"vshape": {"class_type": "VaeDecodeShapeTrellis", "inputs": {"samples": ["ks_up", 0], "vae": ["svae", 0]}},
	"tstage": {"class_type": "Trellis2TextureStage", "inputs": {"positive": ["up", 0], "negative": ["up", 1], "shape_latent": ["ks_up", 0]}},
	"ks_tex": ks(["unet", 0], "tstage", ["tstage", 2], seed + 1, 12, 1.0),
	"tvae": {"class_type": "VAELoader", "inputs": {"vae_name": "trellis_2_texture_vae_bf16.safetensors"}},
	"vtex": {"class_type": "VaeDecodeTextureTrellis", "inputs": {"samples": ["ks_tex", 0], "vae": ["tvae", 0], "shape_subdivides": ["vshape", 1]}},
	"minfo": {"class_type": "GetMeshInfo", "inputs": {"mesh": ["vshape", 0]}},
	"remesh": {"class_type": "RemeshMesh", "inputs": {"mesh": ["minfo", 0], "resolution": REMESH, "sign_mode": "udf", "sign_mode.qef": False,
		"sign_mode.drop_inverted_components": True, "sign_mode.drop_enclosed_components": False, "band": 1.0, "project_back": 0.0,
		"fix_poles": False, "smooth_iters": 20, "drop_small_components": 0.01, "precluster_max_verts": 20000000}},
	"decim": {"class_type": "DecimateMesh", "inputs": {"mesh": ["remesh", 0], "target_face_count": faces, "placement_mode": "midpoint"}},
	"smooth": {"class_type": "MeshSmoothNormals", "inputs": {"mesh": ["decim", 0], "crease_angle": 180.0}},
	"unwrap": {"class_type": "UnwrapMesh", "inputs": {"mesh": ["smooth", 0], "segmenter": "pec", "resolution": tex, "padding": 1, "weld_distance": 0.0002}},
	"bake": {"class_type": "BakeTextureFromVoxel", "inputs": {"mesh": ["unwrap", 0], "voxel_colors": ["vtex", 0], "texture_size": tex, "reference_mesh": ["vshape", 0]}},
	"ao": {"class_type": "BakeAmbientOcclusion", "inputs": {"low_poly": ["unwrap", 0], "high_poly": ["remesh", 0], "resolution": 1024, "samples": 64,
		"max_distance": 0.71, "strength": 1.0, "bias": 0.01}},
	"nrm": {"class_type": "BakeNormalMapFromMesh", "inputs": {"low_poly": ["unwrap", 0], "high_poly": ["remesh", 0], "resolution": tex, "cage_distance": 0.05, "ignore_backfaces": True}},
	"apply": {"class_type": "ApplyTextureToMesh", "inputs": {"mesh": ["unwrap", 0], "base_color": ["bake", 0], "metallic": ["bake", 1], "roughness": ["bake", 2],
		"occlusion": ["ao", 0], "normal_map": ["nrm", 0]}},
	"smooth2": {"class_type": "MeshSmoothNormals", "inputs": {"mesh": ["apply", 0], "crease_angle": 180.0}},
	"file": {"class_type": "MeshToFile3D", "inputs": {"mesh": ["smooth2", 0]}},
	"save": {"class_type": "SaveGLB", "inputs": {"mesh": ["file", 0], "filename_prefix": prefix}},
	"prev": {"class_type": "PreviewImage", "inputs": {"images": ["crop", 0]}},
}
h = comfy.run(g, timeout=3600)
files = []
for node_out in h.get("outputs", {}).values():
	for val in node_out.values():
		if isinstance(val, list):
			for f in val:
				if isinstance(f, dict) and str(f.get("filename", "")).lower().endswith((".glb", ".gltf")): files.append(f)
if not files:
	print("NO GLB", json.dumps(h.get("outputs", {}))[:1500]); sys.exit(1)
p = comfy.fetch(files[0], os.path.dirname(os.path.abspath(out)))
os.replace(p, out)
print("MODEL %s %.1f MB (%s s)" % (out, os.path.getsize(out) / 1e6, h["_seconds"]))
