#!/usr/bin/env bash
# libx265 4:4:4 archive encode (the "slow lane"), same arguments SqueezeReel/smartenc plans for ProRes 4444 sources.
# usage: encode_x265.sh <src> <out.mov> [preset=medium] [bits=10|12] [crf=16] [threads=6]
# Notes: no -avoid_negative_ts make_zero (it adds a 2-frame empty edit with B-frames).
set -euo pipefail
src=${1:?src}; out=${2:?out}; preset=${3:-medium}; bits=${4:-10}; crf=${5:-16}; thr=${6:-6}
case "$bits" in 10) prof=main444-10; fmt=yuv444p10le;; 12) prof=main444-12; fmt=yuv444p12le;; *) echo "bits must be 10 or 12" >&2; exit 1;; esac
vf="scale=in_color_matrix=bt709:out_color_matrix=bt709:in_primaries=bt709:out_primaries=bt709:in_transfer=bt709:out_transfer=bt709,format=${fmt},setparams=color_primaries=bt709:color_trc=bt709:colorspace=bt709:range=tv"
# setparams first: ffmpeg 9 mislabels ProRes 4444 frames as GBR, which makes swscale refuse the conversion.
ffmpeg -hide_banner -v error -y -threads "$thr" -i "$src" -map 0:v:0 \
  -vf "setparams=colorspace=bt709:color_primaries=bt709:color_trc=bt709:range=tv,${vf}" -fps_mode passthrough \
  -c:v libx265 -preset "$preset" -crf "$crf" -profile:v "$prof" \
  -x265-params "keyint=50:min-keyint=1:no-open-gop=1:log-level=error:info=0:aq-mode=3:pools=${thr}" \
  -tag:v hvc1 -color_primaries bt709 -color_trc bt709 -colorspace bt709 -color_range tv \
  -movflags +faststart -f mov "$out"
