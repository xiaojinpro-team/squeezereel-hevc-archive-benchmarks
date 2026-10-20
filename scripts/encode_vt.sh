#!/usr/bin/env bash
# VideoToolbox HEVC 4:2:2 10-bit archive encode (the "fast lane"). macOS only.
# usage: encode_vt.sh <src> <out.mov> [quality=65]
set -euo pipefail
src=${1:?src}; out=${2:?out}; q=${3:-65}
ffmpeg -hide_banner -v error -y -i "$src" -map 0:v:0 \
  -vf "setparams=colorspace=bt709:color_primaries=bt709:color_trc=bt709:range=tv,scale=in_color_matrix=bt709:out_color_matrix=bt709:in_primaries=bt709:out_primaries=bt709:in_transfer=bt709:out_transfer=bt709,format=yuv422p10le,setparams=color_primaries=bt709:color_trc=bt709:colorspace=bt709:range=tv" \
  -fps_mode passthrough -pix_fmt p210le -c:v hevc_videotoolbox -profile:v main42210 -q:v "$q" -g 50 -tag:v hvc1 \
  -color_primaries bt709 -color_trc bt709 -colorspace bt709 -color_range tv -movflags +faststart -f mov "$out"
