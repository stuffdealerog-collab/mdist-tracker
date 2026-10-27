"""Turn the speaker notes into text-to-speech blocks (one per speaker turn).

Writes build/tts_blocks.json: [{id, slide, who, text, tts}] where `tts` is the
text sent to ElevenLabs (IDs spelled out, hard words given as IPA).
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
content = json.loads((ROOT / "src" / "content.json").read_text())

IPA = [
    (r"\bmal aria\b", "/mal ˈaːrja/"),
    (r"\bAnopheles\b", "/əˈnɒfɪliːz/"),
    (r"\bfalciparum\b", "/fælˈsɪpərəm/"),
    (r"\bLaveran\b", "/lavˈʁɑ̃/"),
    (r"\bTu Youyou\b", "/tuː joʊˈjoʊ/"),
    (r"\bcinchona\b", "/sɪŋˈkoʊnə/"),
    (r"\bo'g'li\b", "/oʁˈli/"),
]
WORDS = [
    (r"RTS,S", "R.T.S.S."),
    (r"\bR21\b", "R twenty-one"),
    (r"\bACT\b", "A.C.T."),
    (r"\bWHO\b", "W.H.O."),
    (r"\bGSK\b", "G.S.K."),
]


def to_tts(text, who):
    sp = content["speakers"][who]
    t = text.replace(sp["id"], sp["idSpoken"])
    for pat, rep in WORDS + IPA:
        t = re.sub(pat, rep, t)
    return t.replace("\n", " ").replace("..", ".")


blocks = []
for s in content["slides"]:
    for i, b in enumerate(s["notes"]):
        if b.get("silent"):
            continue
        blocks.append({"id": f"s{s['n']:02d}_{i}_{b['who']}", "slide": s["n"], "who": b["who"], "text": b["text"], "tts": to_tts(b["text"], b["who"])})

out = ROOT / "build" / "tts_blocks.json"
out.parent.mkdir(exist_ok=True)
out.write_text(json.dumps(blocks, ensure_ascii=False, indent=1))
print(len(blocks), "blocks,", sum(len(b["tts"]) for b in blocks), "chars")
for b in blocks:
    print(b["id"], len(b["tts"]))
