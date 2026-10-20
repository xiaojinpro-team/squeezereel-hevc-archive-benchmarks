#!/usr/bin/env python3
"""Chroma-key matte fidelity: key the source and each encode with the same chromakey settings and compare the alpha mattes.

usage: matte_compare.py --ref SRC.mov --test A.mov B.mov ... --key 0x45877b [--similarity 0.05] [--blend 0.03] [--step 10] [--width 3840 --height 2160]
Reports per test file: matte PSNR, whole-frame mismatch % (|d|>25/255), edge-band mismatch % (8 px around the
source matte boundary), soft-alpha mismatch % (source alpha strictly between 5 and 250).
Pick --similarity by eye first (0.03-0.06 works for flat teal/green/red backdrops; too high keys neutral dark pixels).
Needs numpy and scipy. The source is read with colour tags forced to bt709 (ffmpeg 9 mislabels ProRes 4444 as GBR).
"""
import argparse, json, subprocess
import numpy as np
from scipy.ndimage import maximum_filter, minimum_filter

ap = argparse.ArgumentParser()
ap.add_argument("--ref", required=True); ap.add_argument("--test", nargs="+", required=True)
ap.add_argument("--key", required=True); ap.add_argument("--similarity", default="0.05"); ap.add_argument("--blend", default="0.03")
ap.add_argument("--step", type=int, default=10); ap.add_argument("--width", type=int, default=3840); ap.add_argument("--height", type=int, default=2160)
ap.add_argument("--json", help="write results here")
a = ap.parse_args()
W, H = a.width, a.height
FIX = "setparams=colorspace=bt709:color_primaries=bt709:color_trc=bt709:range=tv,"

def decode(path, ref):
    vf = (FIX if ref else "setpts=PTS-STARTPTS,") + (f"select='not(mod(n\\,{a.step}))',format=yuva444p,"
         f"chromakey=color={a.key}:similarity={a.similarity}:blend={a.blend},alphaextract,format=gray")
    return subprocess.Popen(["ffmpeg", "-v", "error", "-threads", "3", "-i", path, "-vf", vf, "-fps_mode", "passthrough",
                             "-f", "rawvideo", "-pix_fmt", "gray", "-"], stdout=subprocess.PIPE)

pr = decode(a.ref, True); pt = [decode(t, False) for t in a.test]
acc = [{"mse": [], "mis": [], "band": [], "soft": []} for _ in a.test]
FS = W * H; n = 0
while True:
    b = pr.stdout.read(FS)
    if len(b) < FS: break
    r = np.frombuffer(b, np.uint8).reshape(H, W)
    bu = (r > 127).view(np.uint8)
    edge = maximum_filter(bu, size=3) != minimum_filter(bu, size=3)
    band = maximum_filter(edge.view(np.uint8), size=17).astype(bool)
    soft = (r > 5) & (r < 250)
    for i, p in enumerate(pt):
        t = np.frombuffer(p.stdout.read(FS), np.uint8).reshape(H, W)
        d = np.abs(t.astype(np.int16) - r.astype(np.int16)); bad = d > 25
        acc[i]["mse"].append(float((d.astype(np.float64) ** 2).mean()))
        acc[i]["mis"].append(float(bad.mean()))
        acc[i]["band"].append(float((bad & band).sum() / max(band.sum(), 1)))
        if soft.sum(): acc[i]["soft"].append(float((bad & soft).sum() / soft.sum()))
    n += 1
out = {"frames": n, "key": a.key, "similarity": a.similarity, "tests": {}}
for t, s in zip(a.test, acc):
    m = np.mean(s["mse"])
    out["tests"][t] = {"matte_psnr": float(10 * np.log10(255 ** 2 / m)) if m > 0 else None,
                       "mismatch_pct": 100 * float(np.mean(s["mis"])),
                       "edge_band_mismatch_pct": 100 * float(np.mean(s["band"])),
                       "soft_alpha_mismatch_pct": 100 * float(np.mean(s["soft"])) if s["soft"] else None}
print(json.dumps(out, indent=1))
if a.json: json.dump(out, open(a.json, "w"), indent=1)
