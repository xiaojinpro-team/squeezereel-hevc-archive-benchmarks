#!/usr/bin/env python3
"""Alpha-plane fidelity of encodes against an alpha source.
usage: alpha_stats.py --ref SRC.mov --test A.mov B.mov ... [--step 5] [--width 3840 --height 2160]
Per test file: alpha PSNR, % of pixels with |diff|>2/255 (whole frame, non-empty area, soft-edge area), max abs diff.
Decoding is by ffmpeg software decode (hardware decode via -hwaccel videotoolbox drops alpha). Needs numpy."""
import argparse, json, subprocess
import numpy as np
ap = argparse.ArgumentParser()
ap.add_argument("--ref", required=True); ap.add_argument("--test", nargs="+", required=True)
ap.add_argument("--step", type=int, default=5); ap.add_argument("--width", type=int, default=3840); ap.add_argument("--height", type=int, default=2160)
a = ap.parse_args(); W, H = a.width, a.height
FIX = "setpts=PTS-STARTPTS,setparams=colorspace=bt709:color_primaries=bt709:color_trc=bt709:range=tv,"
def dec(path, ref):
    vf = (FIX if ref else "setpts=PTS-STARTPTS,") + f"select='not(mod(n\\,{a.step}))',format=rgba,alphaextract,format=gray"
    return subprocess.Popen(["ffmpeg", "-v", "error", "-threads", "4", "-i", path, "-vf", vf, "-fps_mode", "passthrough", "-f", "rawvideo", "-pix_fmt", "gray", "-"], stdout=subprocess.PIPE)
pr = dec(a.ref, True); pt = [dec(t, False) for t in a.test]
acc = [dict(mse=[], whole=[], ne=[], soft=[], mx=0) for _ in a.test]; FS = W * H
while True:
    b = pr.stdout.read(FS)
    if len(b) < FS: break
    r = np.frombuffer(b, np.uint8).reshape(H, W); soft = (r >= 3) & (r <= 252)
    for i, p in enumerate(pt):
        t = np.frombuffer(p.stdout.read(FS), np.uint8).reshape(H, W)
        d = np.abs(t.astype(np.int16) - r.astype(np.int16)); bad = d > 2; un = (r > 2) | (t > 2)
        s = acc[i]; s["mse"].append(float((d.astype(np.float64) ** 2).mean())); s["whole"].append(float(bad.mean()))
        s["ne"].append(float((bad & un).sum() / max(un.sum(), 1)))
        if soft.sum(): s["soft"].append(float((bad & soft).sum() / soft.sum()))
        s["mx"] = max(s["mx"], int(d.max()))
res = {}
for t, s in zip(a.test, acc):
    m = np.mean(s["mse"])
    res[t] = {"alpha_psnr": float(10 * np.log10(255 ** 2 / m)) if m > 0 else "lossless",
              "mismatch_gt2_pct_whole": 100 * float(np.mean(s["whole"])), "mismatch_gt2_pct_nonempty": 100 * float(np.mean(s["ne"])),
              "mismatch_gt2_pct_soft": 100 * float(np.mean(s["soft"])) if s["soft"] else None, "max_abs_diff": s["mx"]}
print(json.dumps(res, indent=1))
