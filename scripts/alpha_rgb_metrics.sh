#!/usr/bin/env bash
# RGB fidelity of an alpha encode, composited over mid-grey (raw RGBA compare is meaningless under alpha=0).
# usage: alpha_rgb_metrics.sh <test.mov> <ref.mov> [W=3840] [H=2160]   -> prints PSNR r/g/b and SSIM R/G/B (8-bit scale)
set -euo pipefail
test=${1:?test}; ref=${2:?ref}; W=${3:-3840}; H=${4:-2160}
fix="setpts=PTS-STARTPTS,setparams=colorspace=bt709:color_primaries=bt709:color_trc=bt709:range=tv"
g="color=c=0x808080:s=${W}x${H}:r=30[b1];color=c=0x808080:s=${W}x${H}:r=30[b2];[0:v]setpts=PTS-STARTPTS,format=rgba[t];[1:v]${fix},format=rgba[r];[b1][t]overlay=shortest=1,format=rgb24[tc];[b2][r]overlay=shortest=1,format=rgb24[rc];[tc][rc]"
ffmpeg -hide_banner -threads 8 -i "$test" -i "$ref" -filter_complex "${g}psnr" -f null - 2>&1 | grep -o "PSNR r.*"
ffmpeg -hide_banner -threads 8 -i "$test" -i "$ref" -filter_complex "${g}ssim" -f null - 2>&1 | grep -o "SSIM R.*"
