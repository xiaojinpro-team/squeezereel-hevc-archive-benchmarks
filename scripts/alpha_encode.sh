#!/usr/bin/env bash
# HEVC with Alpha on macOS via VideoToolbox (ffmpeg). The alpha layer is stored in the same hvc1 stream; Apple apps decode it.
# usage: alpha_encode.sh <src_with_alpha.mov> <out.mov> [alpha_quality=1.0] [q=65]
# alpha_quality 1.0 was bit-exact on the test clips (~12x); 0.9 gave max alpha diff 6-7 (~14x).
# Known issue: ffmpeg writes colr matrix GBR for this path; check/repair the tag before using it in an editor.
set -euo pipefail
src=${1:?src}; out=${2:?out}; aq=${3:-1.0}; q=${4:-65}
ffmpeg -hide_banner -v error -y -i "$src" \
  -vf "setparams=colorspace=bt709:color_primaries=bt709:color_trc=bt709:range=tv,format=bgra" -fps_mode passthrough \
  -c:v hevc_videotoolbox -alpha_quality "$aq" -pix_fmt bgra -tag:v hvc1 -q:v "$q" \
  -colorspace bt709 -color_primaries bt709 -color_trc bt709 -color_range tv -movflags +faststart "$out"
# Apple's own preset path (what SqueezeReel's archive-alpha uses):  avconvert --preset PresetHEVCHighestQualityWithAlpha --source <src> --output <out>
