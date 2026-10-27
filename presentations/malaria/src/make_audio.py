"""Assemble rehearsal audio from the ElevenLabs blocks in build/audio_raw/.

Outputs (output/audio/):
  00_Full_run-through_all_speakers.mp3   whole talk, a soft click = "next slide"
  0N_<Name>_1_my_part.mp3                your part, each entry preceded by the
                                         previous speaker's handover line as a cue
  0N_<Name>_2_shadowing.mp3              every phrase followed by a pause of the
                                         same length: repeat it aloud
"""
import json
import re
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "build" / "audio_raw"
OUT = ROOT / "output" / "audio"
TMP = Path(tempfile.mkdtemp(prefix="malaria_audio_"))
content = json.loads((ROOT / "src" / "content.json").read_text())
blocks = json.loads((ROOT / "build" / "tts_blocks.json").read_text())
SP = content["speakers"]
ORDER = ["J", "M", "R", "A"]
SR = 44100


def run(*args):
    subprocess.run(args, check=True, capture_output=True)


def dur(f):
    out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(f)],
                         check=True, capture_output=True, text=True).stdout
    return float(out)


def wav(name):
    return TMP / f"{name}.wav"


def silence(sec):
    f = wav(f"sil_{sec:.2f}")
    if not f.exists():
        run("ffmpeg", "-y", "-f", "lavfi", "-i", f"anullsrc=r={SR}:cl=mono", "-t", f"{sec:.3f}", str(f))
    return f


def click():
    f = wav("click")
    if not f.exists():
        run("ffmpeg", "-y", "-f", "lavfi", "-i", f"sine=f=1320:r={SR}:d=0.09", "-f", "lavfi", "-i", f"sine=f=1980:r={SR}:d=0.09",
            "-filter_complex", "[0][1]amix=inputs=2,afade=t=out:st=0:d=0.09,volume=0.5", "-ac", "1", str(f))
    return f


def norm(bid):
    """Loudness-normalised mono wav of one block, trailing silence trimmed."""
    f = wav(bid)
    if not f.exists():
        run("ffmpeg", "-y", "-i", str(RAW / f"{bid}.mp3"), "-af",
            "silenceremove=start_periods=1:start_threshold=-50dB,areverse,silenceremove=start_periods=1:start_threshold=-50dB,areverse,loudnorm=I=-16:TP=-1.5:LRA=7",
            "-ar", str(SR), "-ac", "1", str(f))
    return f


def pauses(f, min_len=0.32):
    """(start, end) of internal pauses, from ffmpeg silencedetect."""
    err = subprocess.run(["ffmpeg", "-i", str(f), "-af", f"silencedetect=noise=-38dB:d={min_len}", "-f", "null", "-"],
                         capture_output=True, text=True).stderr
    starts = [float(x) for x in re.findall(r"silence_start: ([\d.]+)", err)]
    ends = [float(x) for x in re.findall(r"silence_end: ([\d.]+)", err)]
    return list(zip(starts, ends))


def cut(f, a, b, name):
    o = wav(name)
    run("ffmpeg", "-y", "-i", str(f), "-ss", f"{a:.3f}", "-to", f"{b:.3f}", "-c", "copy", str(o))
    return o


def phrases(f, name):
    total = dur(f)
    edges, pos = [], 0.0
    for s, e in pauses(f):
        mid = (s + e) / 2
        if mid - pos > 0.8:
            edges.append((pos, mid))
            pos = mid
    edges.append((pos, total))
    return [cut(f, a, b, f"{name}_p{i}") for i, (a, b) in enumerate(edges)]


def last_sentence(f, name):
    total = dur(f)
    ps = [p for p in pauses(f, 0.38) if p[1] < total - 1.0]
    start = (ps[-1][0] + ps[-1][1]) / 2 if ps else max(0, total - 4)
    return cut(f, start, total, f"{name}_tail")


def concat(parts, out, title):
    lst = TMP / "list.txt"
    lst.write_text("".join(f"file '{p}'\n" for p in parts))
    OUT.mkdir(parents=True, exist_ok=True)
    run("ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", str(lst), "-ac", "1", "-ar", str(SR), "-b:a", "128k",
        "-metadata", f"title={title}", "-metadata", "artist=Malaria · Group Oral Presentation",
        "-metadata", "album=Malaria rehearsal audio", str(out))
    print(f"{out.name}: {dur(out) / 60:.1f} min")


def name_of(k):
    return SP[k]["short"].replace(" ", "_")


# 1. full run-through
parts, prev_slide = [], None
for b in blocks:
    if prev_slide is not None:
        parts += [silence(0.5), click(), silence(0.9)] if b["slide"] != prev_slide else [silence(0.7)]
    parts.append(norm(b["id"]))
    prev_slide = b["slide"]
concat(parts, OUT / "00_Full_run-through_all_speakers.mp3", "Full run-through, all four speakers")

# 2. my part (with the cue line before each entry) and 3. shadowing
for i, k in enumerate(ORDER, 1):
    mine = [j for j, b in enumerate(blocks) if b["who"] == k]
    parts, shadow = [], []
    for j in mine:
        b = blocks[j]
        prev = blocks[j - 1] if j > 0 else None
        if prev and prev["who"] != k:
            parts += [last_sentence(norm(prev["id"]), prev["id"]), silence(0.4)]
            if prev["slide"] != b["slide"]:
                parts += [click(), silence(0.7)]
        elif parts:
            parts += [silence(0.5), click(), silence(0.9)]
        parts.append(norm(b["id"]))
        for p in phrases(norm(b["id"]), b["id"]):
            shadow += [p, silence(dur(p) + 0.8)]
        shadow += [click(), silence(1.0)]
    concat(parts, OUT / f"0{i}_{name_of(k)}_1_my_part.mp3", f"{SP[k]['short']}: my part")
    concat(shadow, OUT / f"0{i}_{name_of(k)}_2_shadowing.mp3", f"{SP[k]['short']}: shadowing (listen, then repeat)")
