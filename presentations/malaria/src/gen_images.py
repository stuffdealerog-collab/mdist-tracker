"""Generate the deck's photographic assets with GPT-image through OpenRouter.

Usage:  OPENROUTER_API_KEY=... python3 src/gen_images.py [key ...]
Existing files in assets/images are skipped, so re-running only fills gaps.
Pass keys to (re)generate just those images.
"""
import base64
import concurrent.futures as cf
import json
import os
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "images"
MODELS = ["openai/gpt-5.4-image-2", "openai/gpt-5-image"]

STYLE = (
    "Cinematic, ultra-premium editorial photograph, like a luxury campaign shot. "
    "Very dark, moody scene graded in deep crimson, blood red and black: one dramatic red key light, "
    "soft red rim light, deep shadows, subtle haze, fine film grain, shallow depth of field, photorealistic, "
    "high detail. Wide 16:9 landscape composition. {space} "
    "Absolutely no text, letters, numbers, captions, logos or watermarks anywhere in the image."
)
RIGHT = "Keep the left 45% of the frame almost black and empty (space for a title); the main subject sits in the right half."
LEFT = "Keep the right 45% of the frame almost black and empty (space for text); the main subject sits in the left half."
CENTER = "Main subject in the centre, edges falling off into darkness."

PROMPTS = {
    "hero_mosquito": (RIGHT, "Extreme macro photograph of a female Anopheles mosquito resting on human skin in its typical tilted, head-down posture, its slender abdomen glowing translucent red with fresh blood, tiny dew droplets on its legs. Behind it a huge, softly blurred crimson disc of light, like a blood-red moon."),
    "blood_cells": (RIGHT, "A sea of glossy red blood cells drifting through dark space, as seen through a powerful microscope; a few cells contain tiny pale ring-shaped parasites; strong depth of field with glowing crimson bokeh."),
    "night_mosquito": (RIGHT, "A female Anopheles mosquito in flight, sharply backlit and silhouetted against a dim red bedside lamp in a dark bedroom at night, an open window with a curtain moving behind it."),
    "hourglass": (RIGHT, "A vintage hourglass with blood-red sand running through it, standing on a dark laboratory bench beside glass blood-sample tubes and a microscope slide, red rim light on the glass."),
    "ancient_scroll": (RIGHT, "Ancient artefacts on dark stone: a partly unrolled bamboo scroll from ancient China and a torn fragment of Egyptian papyrus with faded, illegible painted symbols, lit by the warm red flame of a small clay oil lamp, dust floating in the light."),
    "microscope": (RIGHT, "A 19th-century brass monocular microscope on a dark wooden desk, glass slides with tiny drops of blood, an old leather notebook and a fountain pen, lit by a single red lamp; Victorian laboratory atmosphere."),
    "world_map": (RIGHT, "An antique world globe in darkness, turned to show Africa, the Arabian Peninsula and South Asia, those regions faintly glowing with red hotspots like embers, thin smoke drifting across it."),
    "africa_dusk": (RIGHT, "A rural village in sub-Saharan Africa at dusk: the silhouette of a mother carrying a small child on her back, walking past round thatched huts and an acacia tree, a huge low red sun, warm dust in the air; quiet, dignified mood."),
    "smoke": (CENTER, "Abstract background: slow swirling crimson smoke and fine glowing particles on pure black, very subtle and elegant, mostly dark space."),
    "samarkand": (RIGHT, "The Registan ensemble in Samarkand, Uzbekistan, at twilight: three majestic madrasas with turquoise domes and intricate tilework, under a deep crimson-red sky; cinematic wide shot, calm and hopeful."),
    "vaccine": (RIGHT, "Premium product macro photograph: a small clear glass vaccine vial with a dark red cap next to a fine syringe on a glossy black surface, a single drop on the needle tip, crimson rim lighting and reflections."),
    "bed_net": (LEFT, "A small child sleeping peacefully under a white mosquito bed net in a dark room at night; the net glows softly in warm red light, a mosquito silhouette waiting outside the net; protective, tender mood."),
    "artemisia": (RIGHT, "Apothecary still life on dark slate: fresh sprigs of sweet wormwood (Artemisia annua) with feathery leaves, curled pieces of reddish cinchona tree bark, a small stone mortar and pestle and a few white tablets; dramatic red rim light."),
    "dawn": (RIGHT, "A wide African savanna at dawn with a single acacia tree silhouette, the sky shifting from deep crimson to warm gold on the horizon as the sun rises; hopeful and peaceful, soft mist over the grass."),
}


def call(model, prompt, key):
    body = {
        "model": model,
        "messages": [{"role": "user", "content": prompt}],
        "modalities": ["image", "text"],
        "image_config": {"aspect_ratio": "16:9"},
        "usage": {"include": True},
    }
    req = urllib.request.Request(
        "https://openrouter.ai/api/v1/chat/completions",
        data=json.dumps(body).encode(),
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json",
                 "HTTP-Referer": "https://mdist.uz", "X-Title": "Malaria group presentation"},
    )
    with urllib.request.urlopen(req, timeout=600) as r:
        data = json.load(r)
    msg = data["choices"][0]["message"]
    url = msg["images"][0]["image_url"]["url"]
    cost = (data.get("usage") or {}).get("cost")
    return base64.b64decode(url.split(",", 1)[1]), cost


def generate(name, key):
    space, subject = PROMPTS[name]
    prompt = subject + " " + STYLE.format(space=space)
    last = None
    for model in MODELS:
        try:
            raw, cost = call(model, prompt, key)
            path = OUT / f"{name}.png"
            path.write_bytes(raw)
            return f"{name}: ok via {model}, cost={cost}"
        except Exception as e:  # try the next model
            last = f"{model}: {e}"
    return f"{name}: FAILED ({last})"


def main():
    key = os.environ.get("OPENROUTER_API_KEY")
    if not key:
        sys.exit("OPENROUTER_API_KEY is not set")
    OUT.mkdir(parents=True, exist_ok=True)
    names = sys.argv[1:] or [n for n in PROMPTS if not (OUT / f"{n}.png").exists()]
    with cf.ThreadPoolExecutor(max_workers=4) as ex:
        for line in ex.map(lambda n: generate(n, key), names):
            print(line, flush=True)


if __name__ == "__main__":
    main()
