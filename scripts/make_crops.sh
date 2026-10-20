#!/usr/bin/env bash
# Side-by-side crops (100% and 200%) of one frame from the source and several encodes, for visual review.
# usage: make_crops.sh <outprefix> <frame> <x> <y> <src.mov> <enc1.mov> [enc2.mov ...]
# Crop is 400x300 at (x,y). Do not publish crops of footage you do not own.
set -euo pipefail
pre=${1:?outprefix}; n=${2:?frame}; x=${3:?x}; y=${4:?y}; src=${5:?src}; shift 5
fix="setparams=colorspace=bt709:color_primaries=bt709:color_trc=bt709:range=tv,"
tmp=$(mktemp -d); i=0; ins=()
for f in "$src" "$@"; do
  p=""; [ $i -eq 0 ] && p="$fix"
  ffmpeg -v error -y -i "$f" -vf "${p}select='eq(n\,$n)',format=rgb24,crop=400:300:$x:$y" -frames:v 1 -update 1 -fps_mode passthrough "$tmp/$i.png"
  ins+=(-i "$tmp/$i.png"); i=$((i+1))
done
ffmpeg -v error -y "${ins[@]}" -filter_complex "hstack=inputs=$i" "${pre}_100pct.png"
ffmpeg -v error -y -i "${pre}_100pct.png" -vf "scale=iw*2:ih*2:flags=neighbor" "${pre}_200pct.png"
rm -rf "$tmp"
