#!/usr/bin/env bash
# One-shot comparison round on a single source: VideoToolbox 4:2:2 (A), x265 main444-10 (B10), x265 main444-12 (B12), all at one x265 preset,
# then PSNR/SSIM/VMAF and the matte comparison. Prints encode times.
# usage: run_chroma_round.sh <src.mov> <workdir> <key 0xRRGGBB> [similarity=0.05] [preset=medium]
# For non-4K sources set W and H in the environment (default 3840x2160).
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
src=${1:?src}; wd=${2:?workdir}; key=${3:?key}; sim=${4:-0.05}; preset=${5:-medium}
mkdir -p "$wd/out" "$wd/raw"
t() { local s=$(date +%s); "$@"; echo "  took $(( $(date +%s) - s )) s"; }
echo "A  (VideoToolbox 4:2:2 q65)";  t "$here/encode_vt.sh"   "$src" "$wd/out/A.mov" 65
echo "B10 (x265 $preset main444-10)"; t "$here/encode_x265.sh" "$src" "$wd/out/B10.mov" "$preset" 10
echo "B12 (x265 $preset main444-12)"; t "$here/encode_x265.sh" "$src" "$wd/out/B12.mov" "$preset" 12
for l in A B10 B12; do "$here/metrics.sh" "$wd/out/$l.mov" "$src" "$l" "$wd/raw"; ls -l "$wd/out/$l.mov" | awk '{print "  size",$5}'; done
python3 "$here/matte_compare.py" --ref "$src" --test "$wd/out/A.mov" "$wd/out/B10.mov" "$wd/out/B12.mov" --key "$key" --similarity "$sim" --width "${W:-3840}" --height "${H:-2160}" --json "$wd/matte.json"
